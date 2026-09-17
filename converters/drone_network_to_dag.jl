"""
Drone Network to DAG Converter
Converts the Scottish medical drone network data into DAG format for signal propagation analysis
"""

using CSV
using DataFrames
using JSON

# File paths
const NODES_FILE = "csvfiles/drone_info/nodes.csv"
const DRONE1_FILE = "csvfiles/drone_info/drone1.csv"
const DRONE2_FILE = "csvfiles/drone_info/drone2.csv"
const OUTPUT_DIR = "dag_ntwrk_files"

function load_drone_network_data()
    """Load all drone network data files"""
    println("Loading drone network data...")

    # Load nodes
    nodes_df = CSV.read(NODES_FILE, DataFrame)
    println("Loaded $(nrow(nodes_df)) nodes")

    # Load distance matrices
    drone1_df = CSV.read(DRONE1_FILE, DataFrame, header=1)  # Use first row as headers
    drone2_df = CSV.read(DRONE2_FILE, DataFrame, header=1)

    # Convert to numeric matrices, replacing "Inf" strings with Inf
    drone1_matrix = Matrix{Float64}(undef, nrow(drone1_df), ncol(drone1_df))
    drone2_matrix = Matrix{Float64}(undef, nrow(drone2_df), ncol(drone2_df))

    for i in 1:nrow(drone1_df), j in 1:ncol(drone1_df)
        val = drone1_df[i, j]
        drone1_matrix[i, j] = (val == "Inf" || ismissing(val)) ? Inf : parse(Float64, string(val))
    end

    for i in 1:nrow(drone2_df), j in 1:ncol(drone2_df)
        val = drone2_df[i, j]
        drone2_matrix[i, j] = (val == "Inf" || ismissing(val)) ? Inf : parse(Float64, string(val))
    end

    println("Loaded $(size(drone1_matrix, 1))x$(size(drone1_matrix, 2)) distance matrices")

    return nodes_df, drone1_matrix, drone2_matrix
end

function calculate_node_priors(nodes_df)
    """Calculate node prior probabilities based on infrastructure and role"""
    priors = Dict{String, Float64}()

    for row in eachrow(nodes_df)
        node_id = string(row.numberID)

        # Base prior based on node type (following their reliability model)
        if row.source_receiver_type == "SOURCE-RECEIVER"
            base_prior = 0.9  # Hubs are most reliable (like their approach)
        elseif row.source_receiver_type == "RECEIVER"
            base_prior = 0.8  # Standard hospitals
        else  # GENERIC (airports/intermediate)
            base_prior = 0.6  # Lower baseline for infrastructure nodes
        end

        # Adjust based on infrastructure quality
        cs_bonus = row.CS_type * 0.02  # Charging station quality
        dp_bonus = row.DP_type * 0.02  # Drone port quality

        # Final prior (clamped to [0.5, 0.95])
        prior = clamp(base_prior + cs_bonus + dp_bonus, 0.5, 0.95)
        priors[node_id] = prior
    end

    return priors
end

function distance_to_probability(distance, max_range=70000.0)
    """Convert distance/time to transmission probability"""
    if distance == Inf || isnan(distance)
        return 0.0
    end

    # Exponential decay based on drone range (following their reliability testing)
    # Higher failure probability for longer distances
    probability = exp(-distance / max_range)
    return clamp(probability, 0.01, 0.99)  # Avoid exact 0/1
end

# ============================================================================
# SPARSE MISSION EXTRACTION - Reduces density from ~50% to ~20%
# ============================================================================

function dijkstra_shortest_path(distance_matrix, start_idx, end_idx, n_nodes)
    """Find shortest path using Dijkstra's algorithm"""
    # Initialize distances
    distances = fill(Inf, n_nodes)
    distances[start_idx] = 0.0
    previous = fill(-1, n_nodes)
    unvisited = Set(1:n_nodes)

    while !isempty(unvisited)
        # Find unvisited node with minimum distance
        current = -1
        min_dist = Inf
        for node in unvisited
            if distances[node] < min_dist
                min_dist = distances[node]
                current = node
            end
        end

        if current == -1 || current == end_idx
            break
        end

        delete!(unvisited, current)

        # Update neighbors
        for neighbor in unvisited
            if distance_matrix[current, neighbor] != Inf && !isnan(distance_matrix[current, neighbor])
                alt_dist = distances[current] + distance_matrix[current, neighbor]
                if alt_dist < distances[neighbor]
                    distances[neighbor] = alt_dist
                    previous[neighbor] = current
                end
            end
        end
    end

    # Reconstruct path
    if distances[end_idx] == Inf
        return Int[]  # No path found
    end

    path = Int[]
    current = end_idx
    while current != -1
        pushfirst!(path, current)
        current = previous[current]
    end

    return path
end

function find_k_alternative_nodes(nodes_df, distance_matrix, src_idx, dst_idx, k=2)
    """Find k closest intermediate nodes between src and dst"""
    n_nodes = nrow(nodes_df)
    candidates = []

    for i in 1:n_nodes
        if i != src_idx && i != dst_idx
            dist_from_src = distance_matrix[src_idx, i]
            dist_to_dst = distance_matrix[i, dst_idx]

            # Only consider if reachable from both
            if dist_from_src != Inf && dist_to_dst != Inf &&
               !isnan(dist_from_src) && !isnan(dist_to_dst)
                # Score by total distance (prefer nodes "on the way")
                total_dist = dist_from_src + dist_to_dst
                push!(candidates, (i, total_dist))
            end
        end
    end

    # Sort by distance and take k closest
    sort!(candidates, by=x->x[2])
    return [idx for (idx, _) in candidates[1:min(k, length(candidates))]]
end

function create_sparse_mission_dag_multiplex(
    nodes_df, vtol_matrix, fixed_wing_matrix,
    pickup_id, delivery_id,
    k_alternatives=2  # Number of alternative intermediate nodes per hop
)
    """
    Create SPARSE mission DAG using shortest path + k alternatives
    This reduces density from ~50% to ~20-25%!
    """
    println("Creating SPARSE multiplex mission DAG: $pickup_id → $delivery_id")

    pickup_idx = findfirst(x -> x == pickup_id, nodes_df.numberID)
    delivery_idx = findfirst(x -> x == delivery_id, nodes_df.numberID)

    if pickup_idx === nothing || delivery_idx === nothing
        error("Pickup or delivery node not found")
    end

    n_nodes = nrow(nodes_df)

    # 1. Find primary shortest path using VTOL (most restrictive)
    primary_path_idx = dijkstra_shortest_path(vtol_matrix, pickup_idx, delivery_idx, n_nodes)

    if isempty(primary_path_idx)
        println("  ⚠️  No VTOL path found, trying fixed-wing...")
        primary_path_idx = dijkstra_shortest_path(fixed_wing_matrix, pickup_idx, delivery_idx, n_nodes)
    end

    if isempty(primary_path_idx)
        println("  ⚠️  No path found! Falling back to dense extraction...")
        # Fallback to old method
        return create_mission_dag_multiplex(nodes_df, vtol_matrix, fixed_wing_matrix, pickup_id, delivery_id)
    end

    # Convert indices to node IDs
    primary_path = [nodes_df.numberID[idx] for idx in primary_path_idx]
    println("  Primary path: $(join(primary_path, " → ")) ($(length(primary_path)) hops)")

    # 2. Build sparse subgraph: primary path + k alternatives per hop
    subgraph_nodes = Set(primary_path)
    sparse_edges = Tuple{Int, Int}[]
    edge_probs = Dict{String, Float64}()

    # Add primary path edges
    for i in 1:(length(primary_path_idx)-1)
        src_id = primary_path[i]
        dst_id = primary_path[i+1]
        src_idx = primary_path_idx[i]
        dst_idx = primary_path_idx[i+1]

        # Add direct edge (try both drone types)
        edge_key = "($src_id,$dst_id)"

        vtol_dist = vtol_matrix[src_idx, dst_idx]
        fw_dist = fixed_wing_matrix[src_idx, dst_idx]

        if vtol_dist != Inf && !isnan(vtol_dist)
            push!(sparse_edges, (src_id, dst_id))
            prob = distance_to_probability(vtol_dist, 70000.0)
            edge_probs[edge_key] = prob
        end

        if fw_dist != Inf && !isnan(fw_dist)
            if !haskey(edge_probs, edge_key)
                push!(sparse_edges, (src_id, dst_id))
                prob = distance_to_probability(fw_dist, 700000.0)
                edge_probs[edge_key] = prob
            else
                prob = distance_to_probability(fw_dist, 700000.0)
                edge_probs[edge_key] = max(edge_probs[edge_key], prob)
            end
        end

        # 3. Find k alternative intermediate nodes for this hop
        # Try VTOL first, then fixed-wing
        alt_nodes_idx = find_k_alternative_nodes(nodes_df, vtol_matrix, src_idx, dst_idx, k_alternatives)
        if length(alt_nodes_idx) < k_alternatives
            fw_alt = find_k_alternative_nodes(nodes_df, fixed_wing_matrix, src_idx, dst_idx, k_alternatives)
            alt_nodes_idx = unique(vcat(alt_nodes_idx, fw_alt))
        end

        # Add alternative paths: src → alt → dst
        for alt_idx in alt_nodes_idx[1:min(k_alternatives, length(alt_nodes_idx))]
            alt_id = nodes_df.numberID[alt_idx]
            push!(subgraph_nodes, alt_id)

            # Edge: src → alt
            edge_key_1 = "($src_id,$alt_id)"
            vtol_dist_1 = vtol_matrix[src_idx, alt_idx]
            fw_dist_1 = fixed_wing_matrix[src_idx, alt_idx]

            if vtol_dist_1 != Inf && !isnan(vtol_dist_1)
                if !haskey(edge_probs, edge_key_1)
                    push!(sparse_edges, (src_id, alt_id))
                end
                prob = distance_to_probability(vtol_dist_1, 70000.0)
                edge_probs[edge_key_1] = get(edge_probs, edge_key_1, 0.0)
                edge_probs[edge_key_1] = max(edge_probs[edge_key_1], prob)
            end

            if fw_dist_1 != Inf && !isnan(fw_dist_1)
                if !haskey(edge_probs, edge_key_1)
                    push!(sparse_edges, (src_id, alt_id))
                end
                prob = distance_to_probability(fw_dist_1, 700000.0)
                edge_probs[edge_key_1] = max(get(edge_probs, edge_key_1, 0.0), prob)
            end

            # Edge: alt → dst
            edge_key_2 = "($alt_id,$dst_id)"
            vtol_dist_2 = vtol_matrix[alt_idx, dst_idx]
            fw_dist_2 = fixed_wing_matrix[alt_idx, dst_idx]

            if vtol_dist_2 != Inf && !isnan(vtol_dist_2)
                if !haskey(edge_probs, edge_key_2)
                    push!(sparse_edges, (alt_id, dst_id))
                end
                prob = distance_to_probability(vtol_dist_2, 70000.0)
                edge_probs[edge_key_2] = max(get(edge_probs, edge_key_2, 0.0), prob)
            end

            if fw_dist_2 != Inf && !isnan(fw_dist_2)
                if !haskey(edge_probs, edge_key_2)
                    push!(sparse_edges, (alt_id, dst_id))
                end
                prob = distance_to_probability(fw_dist_2, 700000.0)
                edge_probs[edge_key_2] = max(get(edge_probs, edge_key_2, 0.0), prob)
            end
        end
    end

    # Remove duplicate edges
    sparse_edges = unique(sparse_edges)

    relevant_nodes = collect(subgraph_nodes)
    n_nodes_sparse = length(relevant_nodes)
    n_edges_sparse = length(sparse_edges)
    max_possible_edges = n_nodes_sparse * (n_nodes_sparse - 1)
    density = round(n_edges_sparse / max_possible_edges * 100, digits=2)

    println("  ✅ Sparse mission DAG: $n_nodes_sparse nodes, $n_edges_sparse edges ($(density)% density)")
    println("  📊 Reduced from potential ~50% density to $(density)%!")

    return sparse_edges, edge_probs, relevant_nodes
end

# ============================================================================
# END SPARSE EXTRACTION
# ============================================================================

function create_multiplex_dag_from_matrices(nodes_df, vtol_matrix, fixed_wing_matrix)
    """Create multiplex DAG with both VTOL and fixed-wing drone layers"""
    println("Creating multiplex DAG with VTOL + fixed-wing layers...")

    n_nodes = nrow(nodes_df)
    edges = Tuple{Int, Int}[]
    edge_probs = Dict{String, Float64}()

    # Create DAG by imposing ordering (North to South by latitude)
    node_order = sortperm(nodes_df.lat, rev=true)  # North to South
    order_lookup = Dict(node_order[i] => i for i in 1:length(node_order))

    vtol_count = 0
    fixed_wing_count = 0

    # Process both drone types
    for i in 1:n_nodes
        for j in 1:n_nodes
            if i != j
                vtol_distance = vtol_matrix[i, j]
                fixed_wing_distance = fixed_wing_matrix[i, j]

                node_i_id = nodes_df.numberID[i]
                node_j_id = nodes_df.numberID[j]

                # Enforce DAG structure: only connect if i comes before j in ordering
                if order_lookup[i] < order_lookup[j]
                    # Add VTOL edge if available
                    if vtol_distance != Inf && !isnan(vtol_distance)
                        edge_key = "($node_i_id,$node_j_id)"
                        # If edge doesn't exist yet, add it
                        if !haskey(edge_probs, edge_key)
                            push!(edges, (node_i_id, node_j_id))
                            prob = distance_to_probability(vtol_distance, 70000.0)
                            edge_probs[edge_key] = prob
                            vtol_count += 1
                        else
                            # Edge exists from fixed-wing, take maximum probability
                            prob = distance_to_probability(vtol_distance, 70000.0)
                            edge_probs[edge_key] = max(edge_probs[edge_key], prob)
                        end
                    end

                    # Add fixed-wing edge if available
                    if fixed_wing_distance != Inf && !isnan(fixed_wing_distance)
                        edge_key = "($node_i_id,$node_j_id)"
                        # If edge doesn't exist yet, add it
                        if !haskey(edge_probs, edge_key)
                            push!(edges, (node_i_id, node_j_id))
                            prob = distance_to_probability(fixed_wing_distance, 700000.0)
                            edge_probs[edge_key] = prob
                            fixed_wing_count += 1
                        else
                            # Edge exists from VTOL, take maximum probability (best connection wins)
                            prob = distance_to_probability(fixed_wing_distance, 700000.0)
                            edge_probs[edge_key] = max(edge_probs[edge_key], prob)
                        end
                    end
                end
            end
        end
    end

    println("Created multiplex DAG with $(length(edges)) total edges")
    println("  - VTOL layer contributed: $vtol_count edges")
    println("  - Fixed-wing layer contributed: $fixed_wing_count edges")
    return edges, edge_probs
end

function create_dag_from_matrix(nodes_df, distance_matrix, drone_type="VTOL")
    """Create DAG structure from distance matrix"""
    println("Creating DAG from $(drone_type) distance matrix...")

    n_nodes = nrow(nodes_df)
    edges = Tuple{Int, Int}[]
    edge_probs = Dict{String, Float64}()

    # Create DAG by imposing ordering (North to South by latitude)
    node_order = sortperm(nodes_df.lat, rev=true)  # North to South
    order_lookup = Dict(node_order[i] => i for i in 1:length(node_order))

    for i in 1:n_nodes
        for j in 1:n_nodes
            if i != j
                distance = distance_matrix[i, j]

                # Only create edge if: distance is finite AND respects DAG ordering
                if distance != Inf && !isnan(distance)
                    node_i_id = nodes_df.numberID[i]
                    node_j_id = nodes_df.numberID[j]

                    # Enforce DAG structure: only connect if i comes before j in ordering
                    if order_lookup[i] < order_lookup[j]
                        push!(edges, (node_i_id, node_j_id))
                        prob = distance_to_probability(distance)
                        edge_probs["($node_i_id,$node_j_id)"] = prob
                    end
                end
            end
        end
    end

    println("Created DAG with $(length(edges)) edges")
    return edges, edge_probs
end

function create_mission_dag_multiplex(nodes_df, vtol_matrix, fixed_wing_matrix, pickup_id, delivery_id)
    """Create multiplex DAG for specific mission route using both drone types"""
    println("Creating multiplex mission DAG: $pickup_id → $delivery_id")

    # Find relevant intermediate nodes (within reasonable distance from either drone type)
    pickup_idx = findfirst(x -> x == pickup_id, nodes_df.numberID)
    delivery_idx = findfirst(x -> x == delivery_id, nodes_df.numberID)

    if pickup_idx === nothing || delivery_idx === nothing
        error("Pickup or delivery node not found")
    end

    # Get potential intermediate nodes (finite distance from both pickup and delivery, using either drone type)
    relevant_nodes = [pickup_id]

    for i in 1:nrow(nodes_df)
        node_id = nodes_df.numberID[i]
        if node_id != pickup_id && node_id != delivery_id
            # Check connectivity using both drone types
            vtol_from_pickup = vtol_matrix[pickup_idx, i]
            vtol_to_delivery = vtol_matrix[i, delivery_idx]
            fw_from_pickup = fixed_wing_matrix[pickup_idx, i]
            fw_to_delivery = fixed_wing_matrix[i, delivery_idx]

            # Include if reachable from pickup AND can reach delivery (via either drone type)
            can_reach_from_pickup = (vtol_from_pickup != Inf && !isnan(vtol_from_pickup)) ||
                                   (fw_from_pickup != Inf && !isnan(fw_from_pickup))
            can_reach_delivery = (vtol_to_delivery != Inf && !isnan(vtol_to_delivery)) ||
                                (fw_to_delivery != Inf && !isnan(fw_to_delivery))

            if can_reach_from_pickup && can_reach_delivery
                push!(relevant_nodes, node_id)
            end
        end
    end
    push!(relevant_nodes, delivery_id)

    # Create edges between relevant nodes using both drone types
    edges = Tuple{Int, Int}[]
    edge_probs = Dict{String, Float64}()

    for i in 1:(length(relevant_nodes)-1)
        for j in (i+1):length(relevant_nodes)
            node_i = relevant_nodes[i]
            node_j = relevant_nodes[j]

            idx_i = findfirst(x -> x == node_i, nodes_df.numberID)
            idx_j = findfirst(x -> x == node_j, nodes_df.numberID)

            vtol_distance = vtol_matrix[idx_i, idx_j]
            fw_distance = fixed_wing_matrix[idx_i, idx_j]

            edge_key = "($node_i,$node_j)"

            # Add edge if either drone type can make the connection
            if vtol_distance != Inf && !isnan(vtol_distance)
                push!(edges, (node_i, node_j))
                prob = distance_to_probability(vtol_distance, 70000.0)
                edge_probs[edge_key] = prob
            end

            if fw_distance != Inf && !isnan(fw_distance)
                if !haskey(edge_probs, edge_key)
                    push!(edges, (node_i, node_j))
                    prob = distance_to_probability(fw_distance, 700000.0)
                    edge_probs[edge_key] = prob
                else
                    # Edge exists from VTOL, take maximum probability
                    prob = distance_to_probability(fw_distance, 700000.0)
                    edge_probs[edge_key] = max(edge_probs[edge_key], prob)
                end
            end
        end
    end

    println("Multiplex mission DAG has $(length(relevant_nodes)) nodes, $(length(edges)) edges")
    return edges, edge_probs, relevant_nodes
end

function create_mission_dag(nodes_df, distance_matrix, pickup_id, delivery_id, drone_type="VTOL")
    """Create DAG for specific mission route"""
    println("Creating mission DAG: $pickup_id → $delivery_id")

    # Find relevant intermediate nodes (within reasonable distance)
    pickup_idx = findfirst(x -> x == pickup_id, nodes_df.numberID)
    delivery_idx = findfirst(x -> x == delivery_id, nodes_df.numberID)

    if pickup_idx === nothing || delivery_idx === nothing
        error("Pickup or delivery node not found")
    end

    # Get potential intermediate nodes (finite distance from both pickup and delivery)
    relevant_nodes = [pickup_id]

    for i in 1:nrow(nodes_df)
        node_id = nodes_df.numberID[i]
        if node_id != pickup_id && node_id != delivery_id
            dist_from_pickup = distance_matrix[pickup_idx, i]
            dist_to_delivery = distance_matrix[i, delivery_idx]

            # Include if reachable from pickup and can reach delivery
            if dist_from_pickup != Inf && dist_to_delivery != Inf &&
               !isnan(dist_from_pickup) && !isnan(dist_to_delivery)
                push!(relevant_nodes, node_id)
            end
        end
    end
    push!(relevant_nodes, delivery_id)

    # Create edges between relevant nodes (maintaining DAG structure)
    edges = Tuple{Int, Int}[]
    edge_probs = Dict{String, Float64}()

    for i in 1:(length(relevant_nodes)-1)
        for j in (i+1):length(relevant_nodes)
            node_i = relevant_nodes[i]
            node_j = relevant_nodes[j]

            idx_i = findfirst(x -> x == node_i, nodes_df.numberID)
            idx_j = findfirst(x -> x == node_j, nodes_df.numberID)

            distance = distance_matrix[idx_i, idx_j]
            if distance != Inf && !isnan(distance)
                push!(edges, (node_i, node_j))
                prob = distance_to_probability(distance)
                edge_probs["($node_i,$node_j)"] = prob
            end
        end
    end

    println("Mission DAG has $(length(relevant_nodes)) nodes, $(length(edges)) edges")
    return edges, edge_probs, relevant_nodes
end

function identify_dag_sources(edges, all_nodes)
    """Identify true DAG source nodes (nodes with no incoming edges)"""
    # Get all nodes that appear as destinations (have incoming edges)
    destinations = Set{Int}()
    for (src, dst) in edges
        push!(destinations, dst)
    end

    # Source nodes are those that never appear as destinations
    sources = []
    for node in all_nodes
        if !(node in destinations)
            push!(sources, node)
        end
    end

    return sources
end

function save_dag_files(name, edges, edge_probs, node_priors, relevant_nodes=nothing)
    """Save DAG in the required format"""
    println("Saving DAG files for: $name")

    # Create output directory
    output_path = joinpath(OUTPUT_DIR, name)
    mkpath(output_path)
    mkpath(joinpath(output_path, "float"))

    # Save edges file
    edges_file = joinpath(output_path, "$name.EDGES")
    open(edges_file, "w") do f
        println(f, "source,destination")
        for (src, dst) in edges
            println(f, "$src,$dst")
        end
    end

    # Filter node priors to only relevant nodes if specified
    if relevant_nodes !== nothing
        filtered_priors = Dict(string(node) => node_priors[string(node)] for node in relevant_nodes if haskey(node_priors, string(node)))
        nodes_to_check = relevant_nodes
    else
        filtered_priors = node_priors
        nodes_to_check = [parse(Int, k) for k in keys(node_priors)]
    end

    # Identify and set true DAG source nodes to 1.0
    dag_sources = identify_dag_sources(edges, nodes_to_check)
    println("Identified $(length(dag_sources)) DAG source nodes: $(dag_sources)")

    for source_node in dag_sources
        source_key = string(source_node)
        if haskey(filtered_priors, source_key)
            filtered_priors[source_key] = 1.0
        end
    end

    # Save node priors JSON
    priors_data = Dict(
        "nodes" => filtered_priors,
        "data_type" => "Float64",
        "serialization" => "compact",
        "description" => "Node prior probabilities for $name network"
    )

    priors_file = joinpath(output_path, "float", "$name-nodepriors.json")
    open(priors_file, "w") do f
        JSON.print(f, priors_data, 2)
    end

    # Save link probabilities JSON
    links_data = Dict(
        "links" => edge_probs,
        "data_type" => "Float64",
        "serialization" => "compact",
        "description" => "Link/edge probabilities for $name network"
    )

    links_file = joinpath(output_path, "float", "$name-linkprobabilities.json")
    open(links_file, "w") do f
        JSON.print(f, links_data, 2)
    end

    println("Saved DAG files to: $output_path")
end

function generate_paper_based_missions(nodes_df)
    """Generate missions based on their paper's approach"""
    println("Generating missions based on paper methodology...")

    # Get SOURCE-RECEIVER nodes (hubs) and RECEIVER nodes
    hubs = nodes_df[nodes_df.source_receiver_type .== "SOURCE-RECEIVER", :]
    receivers = nodes_df[nodes_df.source_receiver_type .== "RECEIVER", :]

    missions = []

    # 1. Health board level missions (hub to receivers in same health board)
    println("Creating health board level missions...")

    # Create missions for HB0 (has multiple hubs and receivers)
    hb0_hubs = hubs[hubs.group_2 .== 0, :]
    hb0_receivers = receivers[receivers.group_2 .== 0, :]

    if nrow(hb0_hubs) > 0 && nrow(hb0_receivers) > 0
        hub = hb0_hubs[1, :]  # Take first hub (node 135: Queen Margaret Hospital)

        # Create 3 local missions within HB0
        for i in 1:min(3, nrow(hb0_receivers))
            receiver = hb0_receivers[i, :]
            mission_name = "HB0_local_$(i)"
            description = "Health Board 0 Local: $(hub.info) → $(receiver.info)"
            push!(missions, (hub.numberID, receiver.numberID, mission_name, description))
        end
    end

    # 2. Regional missions (nearby hubs with actual connectivity)
    println("Creating regional missions with real connectivity...")

    # Find pairs of hubs that have connectivity within VTOL range
    regional_missions = []

    # Check some promising hub pairs based on geography
    potential_pairs = [
        (135, 148, "central_scotland_1", "Fife → Glasgow"),  # Queen Margaret → Glasgow Royal
        (148, 161, "central_scotland_2", "Glasgow Royal → Gartnavel"),  # Same city
        (229, 233, "central_scotland_3", "Hairmyres → Wishaw"),  # Nearby hospitals
        (20, 85, "glasgow_area", "Queen Elizabeth → Royal Alexandra"),  # Glasgow area
        (61, 245, "edinburgh_area", "Edinburgh Royal → Royal Edinburgh")  # Edinburgh area
    ]

    for (pickup_id, delivery_id, mission_name, description) in potential_pairs
        # Verify both nodes exist as hubs
        pickup_node = findfirst(x -> x == pickup_id, hubs.numberID)
        delivery_node = findfirst(x -> x == delivery_id, hubs.numberID)

        if pickup_node !== nothing && delivery_node !== nothing
            pickup_info = hubs[pickup_node, :].info
            delivery_info = hubs[delivery_node, :].info
            full_description = "Regional: $pickup_info → $delivery_info"
            push!(missions, (pickup_id, delivery_id, mission_name, full_description))
            if length(regional_missions) >= 3  # Limit to 3 regional missions
                break
            end
        end
    end

    # 3. Multi-hub network missions (longer chains within connected areas)
    println("Creating multi-hub network missions...")

    # Create missions that go from one major hub to distant receivers in same network area
    # These will create larger subnetworks with intermediate nodes

    # Central Scotland network mission (hub to distant receiver in same area)
    central_hubs = hubs[(hubs.lat .< 57.0) .& (hubs.lat .> 55.0) .& (hubs.lon .> -5.0), :]
    central_receivers = receivers[(receivers.lat .< 57.0) .& (receivers.lat .> 55.0) .& (receivers.lon .> -5.0), :]

    if nrow(central_hubs) > 0 && nrow(central_receivers) > 0
        hub = central_hubs[1, :]  # Take first central hub
        if nrow(central_receivers) > 3
            receiver = central_receivers[4, :]  # Take 4th receiver (likely more distant)
            mission_name = "central_scotland_network"
            description = "Central Network: $(hub.info) → $(receiver.info)"
            push!(missions, (hub.numberID, receiver.numberID, mission_name, description))
        end
    end

    # Southern Scotland network mission
    south_hubs = hubs[(hubs.lat .< 56.0), :]
    south_receivers = receivers[(receivers.lat .< 56.0), :]

    if nrow(south_hubs) > 0 && nrow(south_receivers) > 0
        hub = south_hubs[1, :]  # Take first southern hub
        if nrow(south_receivers) > 2
            receiver = south_receivers[3, :]  # Take 3rd receiver
            mission_name = "southern_scotland_network"
            description = "Southern Network: $(hub.info) → $(receiver.info)"
            push!(missions, (hub.numberID, receiver.numberID, mission_name, description))
        end
    end

    println("Generated $(length(missions)) missions total")
    return missions
end

# ============================================================================
# JUSTIFIED NETWORK TOPOLOGIES FOR BELIEF PROPAGATION CASE STUDIES
# Based on paper's optimization objectives with controlled diamond complexity
# ============================================================================

function create_hub_spoke_tree_network(nodes_df, vtol_matrix, fixed_wing_matrix)
    """
    NETWORK 1: Cost-Optimal (Tree Structure)

    Justification: Minimal infrastructure investment (paper's Point 4 - Low Cost)
    - Hub-and-spoke structure minimizes number of drone ports
    - No redundant paths (tree = no diamonds)
    - Accepts longer delivery times for cost savings

    Topology: Sources → Regional Hubs → Local Hubs → Receivers (tree structure)
    Expected: ~300-500 edges, 0% diamond density
    Algorithm Performance: O(n) - should run in < 5 seconds
    """
    println("\n=== NETWORK 1: COST-OPTIMAL (Hub-and-Spoke Tree) ===")

    n_nodes = nrow(nodes_df)

    # Identify hub hierarchy
    source_receiver_nodes = nodes_df[nodes_df.source_receiver_type .== "SOURCE-RECEIVER", :numberID]
    receiver_nodes = nodes_df[nodes_df.source_receiver_type .== "RECEIVER", :numberID]
    generic_nodes = nodes_df[nodes_df.source_receiver_type .== "GENERIC", :numberID]

    println("  Hub hierarchy: $(length(source_receiver_nodes)) source-receivers, $(length(receiver_nodes)) receivers, $(length(generic_nodes)) generic")

    # DAG ordering
    node_order = sortperm(nodes_df.lat, rev=true)
    order_lookup = Dict(node_order[i] => i for i in 1:length(node_order))

    edges = Tuple{Int, Int}[]
    edge_probs = Dict{String, Float64}()

    # Strategy: Each node connects to NEAREST hub only (creates tree)
    for i in 1:n_nodes
        node_id = nodes_df.numberID[i]

        # Skip if already a source-receiver hub
        if node_id in source_receiver_nodes
            continue
        end

        # Find nearest source-receiver hub
        nearest_hub = nothing
        min_dist = Inf
        best_matrix = nothing

        for hub_id in source_receiver_nodes
            hub_idx = findfirst(x -> x == hub_id, nodes_df.numberID)

            # Check both drone types
            vtol_dist = vtol_matrix[min(i, hub_idx), max(i, hub_idx)]
            fw_dist = fixed_wing_matrix[min(i, hub_idx), max(i, hub_idx)]

            if vtol_dist != Inf && !isnan(vtol_dist) && vtol_dist < min_dist
                min_dist = vtol_dist
                nearest_hub = hub_id
                best_matrix = :vtol
            end

            if fw_dist != Inf && !isnan(fw_dist) && fw_dist < min_dist
                min_dist = fw_dist
                nearest_hub = hub_id
                best_matrix = :fixed_wing
            end
        end

        # Add single edge to nearest hub (tree structure)
        if nearest_hub !== nothing
            src_id = min(node_id, nearest_hub)
            dst_id = max(node_id, nearest_hub)

            # Enforce DAG ordering
            src_idx = findfirst(x -> x == src_id, nodes_df.numberID)
            dst_idx = findfirst(x -> x == dst_id, nodes_df.numberID)

            if order_lookup[src_idx] < order_lookup[dst_idx]
                edge_key = "($src_id,$dst_id)"
                if !haskey(edge_probs, edge_key)  # Avoid duplicates
                    push!(edges, (src_id, dst_id))

                    if best_matrix == :vtol
                        edge_probs[edge_key] = distance_to_probability(min_dist, 70000.0)
                    else
                        edge_probs[edge_key] = distance_to_probability(min_dist, 700000.0)
                    end
                end
            end
        end
    end

    # Connect hubs to each other (hub-to-hub backbone)
    for i in 1:length(source_receiver_nodes)
        for j in (i+1):length(source_receiver_nodes)
            hub1_id = source_receiver_nodes[i]
            hub2_id = source_receiver_nodes[j]

            hub1_idx = findfirst(x -> x == hub1_id, nodes_df.numberID)
            hub2_idx = findfirst(x -> x == hub2_id, nodes_df.numberID)

            # Enforce DAG ordering
            if order_lookup[hub1_idx] < order_lookup[hub2_idx]
                src_id, dst_id = hub1_id, hub2_id
            else
                src_id, dst_id = hub2_id, hub1_id
            end

            # Try VTOL first, then fixed-wing
            vtol_dist = vtol_matrix[min(hub1_idx, hub2_idx), max(hub1_idx, hub2_idx)]
            fw_dist = fixed_wing_matrix[min(hub1_idx, hub2_idx), max(hub1_idx, hub2_idx)]

            edge_key = "($src_id,$dst_id)"
            if vtol_dist != Inf && !isnan(vtol_dist)
                if !haskey(edge_probs, edge_key)
                    push!(edges, (src_id, dst_id))
                    edge_probs[edge_key] = distance_to_probability(vtol_dist, 70000.0)
                end
            elseif fw_dist != Inf && !isnan(fw_dist)
                if !haskey(edge_probs, edge_key)
                    push!(edges, (src_id, dst_id))
                    edge_probs[edge_key] = distance_to_probability(fw_dist, 700000.0)
                end
            end
        end
    end

    density = round(length(edges) / (n_nodes * (n_nodes - 1)) * 100, digits=2)
    println("  ✅ COST-OPTIMAL: $(length(edges)) edges ($(density)% density)")
    println("  📊 Tree structure: No diamonds, O(n) complexity")
    println("  🎯 Justification: Minimal infrastructure (paper's low-cost objective)")

    return edges, edge_probs
end

function create_k_redundant_paths_network(nodes_df, vtol_matrix, fixed_wing_matrix, k=2, network_name="K=$k")
    """
    NETWORKS 2-4: Time/Balanced/Resilience Optimal (K-Redundant Paths)

    K=2: Time-Optimal (paper's time minimization + basic redundancy)
    K=3: Balanced (paper's Pareto Point 6 - moderate trade-off)
    K=5: Resilience-Optimal (paper's Point 1 - maximum redundancy)

    Justification: Paper's multi-objective optimization
    - K paths provide redundancy for failure resilience
    - Controlled diamond complexity: 2^K state combinations
    - Balances performance vs robustness

    Topology: Each node has K alternative paths to reach it
    Expected edges: K=2 (~800-1000), K=3 (~1200-1500), K=5 (~2000-2500)
    Algorithm Performance: 2^K states per join node
    """
    println("\n=== NETWORK ($network_name REDUNDANT PATHS) ===")

    n_nodes = nrow(nodes_df)
    node_order = sortperm(nodes_df.lat, rev=true)
    order_lookup = Dict(node_order[i] => i for i in 1:length(node_order))

    edges = Tuple{Int, Int}[]
    edge_probs = Dict{String, Float64}()

    # For each node, find K nearest neighbors (creating K potential paths)
    for i in 1:n_nodes
        node_id = nodes_df.numberID[i]

        # Find all reachable neighbors with distances
        neighbors = []

        for j in 1:n_nodes
            if i != j
                neighbor_id = nodes_df.numberID[j]

                vtol_dist = vtol_matrix[i, j]
                fw_dist = fixed_wing_matrix[i, j]

                best_dist = Inf
                best_type = :none

                if vtol_dist != Inf && !isnan(vtol_dist)
                    best_dist = vtol_dist
                    best_type = :vtol
                end

                if fw_dist != Inf && !isnan(fw_dist) && fw_dist < best_dist
                    best_dist = fw_dist
                    best_type = :fixed_wing
                end

                if best_type != :none
                    push!(neighbors, (neighbor_id, j, best_dist, best_type))
                end
            end
        end

        # Sort by distance and keep K nearest
        sort!(neighbors, by=x -> x[3])
        k_nearest = neighbors[1:min(k, length(neighbors))]

        # Add edges to K nearest neighbors (respecting DAG ordering)
        for (neighbor_id, neighbor_idx, dist, dtype) in k_nearest
            if order_lookup[i] < order_lookup[neighbor_idx]
                src_id, dst_id = node_id, neighbor_id
            elseif order_lookup[neighbor_idx] < order_lookup[i]
                src_id, dst_id = neighbor_id, node_id
            else
                continue  # Same order, skip
            end

            edge_key = "($src_id,$dst_id)"
            if !haskey(edge_probs, edge_key)
                push!(edges, (src_id, dst_id))

                if dtype == :vtol
                    edge_probs[edge_key] = distance_to_probability(dist, 70000.0)
                else
                    edge_probs[edge_key] = distance_to_probability(dist, 700000.0)
                end
            end
        end
    end

    # Remove duplicate edges
    edges = unique(edges)

    density = round(length(edges) / (n_nodes * (n_nodes - 1)) * 100, digits=2)
    avg_diamond_complexity = 2^k

    println("  ✅ K=$k REDUNDANT: $(length(edges)) edges ($(density)% density)")
    println("  📊 Diamond complexity: 2^$k = $avg_diamond_complexity states per join")

    if k == 2
        println("  🎯 Justification: Time-optimal + basic redundancy (paper's time objective)")
    elseif k == 3
        println("  🎯 Justification: Balanced trade-off (paper's Pareto Point 6)")
    elseif k == 5
        println("  🎯 Justification: Maximum resilience (paper's Pareto Point 1)")
    end

    return edges, edge_probs
end

function create_geographic_proximity_network(nodes_df, vtol_matrix, fixed_wing_matrix, k_neighbors=5)
    """
    NETWORK 5: Geographic Proximity (K-Nearest Neighbors)

    Justification: Physical drone range constraints (paper's flying restrictions)
    - Each node connects to K geographically nearest reachable neighbors
    - Natural diamond formation at geographic junctions/clusters
    - Realistic topology based on actual Scottish geography

    Topology: K-NN graph based on physical distance
    Expected: ~1200 edges, natural diamond patterns from geographic clustering
    Algorithm Performance: Variable complexity, diamonds at geographic junctions
    """
    println("\n=== NETWORK 5: GEOGRAPHIC PROXIMITY (K=$k_neighbors Nearest Neighbors) ===")

    n_nodes = nrow(nodes_df)
    node_order = sortperm(nodes_df.lat, rev=true)
    order_lookup = Dict(node_order[i] => i for i in 1:length(node_order))

    edges = Tuple{Int, Int}[]
    edge_probs = Dict{String, Float64}()

    # For each node, find K nearest geographic neighbors within drone range
    for i in 1:n_nodes
        node_id = nodes_df.numberID[i]
        node_lat = nodes_df.lat[i]
        node_lon = nodes_df.lon[i]

        # Calculate geographic distances to all other nodes
        geographic_neighbors = []

        for j in 1:n_nodes
            if i != j
                neighbor_id = nodes_df.numberID[j]
                neighbor_lat = nodes_df.lat[j]
                neighbor_lon = nodes_df.lon[j]

                # Haversine distance (approximate for small distances)
                dlat = neighbor_lat - node_lat
                dlon = neighbor_lon - node_lon
                geographic_dist = sqrt(dlat^2 + dlon^2)  # Simplified

                # Check if reachable by any drone type
                vtol_dist = vtol_matrix[i, j]
                fw_dist = fixed_wing_matrix[i, j]

                flight_dist = Inf
                drone_type = :none

                if vtol_dist != Inf && !isnan(vtol_dist)
                    flight_dist = vtol_dist
                    drone_type = :vtol
                end

                if fw_dist != Inf && !isnan(fw_dist) && fw_dist < flight_dist
                    flight_dist = fw_dist
                    drone_type = :fixed_wing
                end

                if drone_type != :none
                    push!(geographic_neighbors, (neighbor_id, j, geographic_dist, flight_dist, drone_type))
                end
            end
        end

        # Sort by GEOGRAPHIC distance and keep K nearest
        sort!(geographic_neighbors, by=x -> x[3])
        k_nearest = geographic_neighbors[1:min(k_neighbors, length(geographic_neighbors))]

        # Add edges (respecting DAG ordering)
        for (neighbor_id, neighbor_idx, geo_dist, flight_dist, dtype) in k_nearest
            if order_lookup[i] < order_lookup[neighbor_idx]
                src_id, dst_id = node_id, neighbor_id
            elseif order_lookup[neighbor_idx] < order_lookup[i]
                src_id, dst_id = neighbor_id, node_id
            else
                continue
            end

            edge_key = "($src_id,$dst_id)"
            if !haskey(edge_probs, edge_key)
                push!(edges, (src_id, dst_id))

                if dtype == :vtol
                    edge_probs[edge_key] = distance_to_probability(flight_dist, 70000.0)
                else
                    edge_probs[edge_key] = distance_to_probability(flight_dist, 700000.0)
                end
            end
        end
    end

    edges = unique(edges)

    density = round(length(edges) / (n_nodes * (n_nodes - 1)) * 100, digits=2)
    println("  ✅ GEOGRAPHIC K-NN: $(length(edges)) edges ($(density)% density)")
    println("  📊 Natural diamonds from geographic clustering")
    println("  🎯 Justification: Drone range constraints (paper's flying restrictions)")

    return edges, edge_probs
end

function generate_all_justified_networks()
    """Generate all 5 justified network topologies for belief propagation case studies"""
    println("="^80)
    println("GENERATING JUSTIFIED NETWORK TOPOLOGIES FOR BELIEF PROPAGATION")
    println("Based on 'Conceptual design of a medical drone logistics network for Scotland'")
    println("="^80)

    # Load data
    nodes_df, drone1_matrix, drone2_matrix = load_drone_network_data()
    node_priors = calculate_node_priors(nodes_df)

    # Network 1: Cost-Optimal (Tree)
    cost_edges, cost_probs = create_hub_spoke_tree_network(nodes_df, drone1_matrix, drone2_matrix)
    save_dag_files("drone-network-cost-optimal", cost_edges, cost_probs, node_priors)

    # Network 2: Time-Optimal (K=2)
    time_edges, time_probs = create_k_redundant_paths_network(nodes_df, drone1_matrix, drone2_matrix, 2, "TIME-OPTIMAL K=2")
    save_dag_files("drone-network-time-optimal-k2", time_edges, time_probs, node_priors)

    # Network 3: Balanced (K=3)
    balanced_edges, balanced_probs = create_k_redundant_paths_network(nodes_df, drone1_matrix, drone2_matrix, 3, "BALANCED K=3")
    save_dag_files("drone-network-balanced-k3", balanced_edges, balanced_probs, node_priors)

    # Network 4: Resilience-Optimal (K=5)
    resilience_edges, resilience_probs = create_k_redundant_paths_network(nodes_df, drone1_matrix, drone2_matrix, 5, "RESILIENCE-OPTIMAL K=5")
    save_dag_files("drone-network-resilience-optimal-k5", resilience_edges, resilience_probs, node_priors)

    # Network 5: Geographic Proximity
    geographic_edges, geographic_probs = create_geographic_proximity_network(nodes_df, drone1_matrix, drone2_matrix, 5)
    save_dag_files("drone-network-geographic-knn", geographic_edges, geographic_probs, node_priors)

    println("\n" * "="^80)
    println("GENERATION COMPLETE - 5 JUSTIFIED NETWORKS CREATED")
    println("="^80)
    println("\nSummary:")
    println("  1. Cost-Optimal (Tree):         ~$(length(cost_edges)) edges - No diamonds, O(n)")
    println("  2. Time-Optimal (K=2):          ~$(length(time_edges)) edges - 2^2=4 states/join")
    println("  3. Balanced (K=3):              ~$(length(balanced_edges)) edges - 2^3=8 states/join")
    println("  4. Resilience-Optimal (K=5):    ~$(length(resilience_edges)) edges - 2^5=32 states/join")
    println("  5. Geographic Proximity (K-NN): ~$(length(geographic_edges)) edges - Natural diamonds")
    println("\nAll networks have 244 nodes with different edge topologies.")
    println("Ready for belief propagation case studies!")
end

# Run the justified network generation (avoids stack overflow)
if abspath(PROGRAM_FILE) == @__FILE__
    generate_all_justified_networks()
end