"""
Drone Network DAG Generator - Reliability Analysis Case Studies

Based on: "Conceptual design of a medical drone logistics network for Scotland"
by Jones et al. (University of Strathclyde)

================================================================================
JUSTIFICATION FOR DAG REPRESENTATION
================================================================================

This generator creates Directed Acyclic Graphs (DAGs) for reliability analysis
of drone logistics networks. The DAG structure is justified as follows:

RELIABILITY INTERPRETATION:
- We model the drone logistics network as a supply dependency DAG
- Information/supplies flow from central distribution hubs through relay
  stations to endpoint receivers
- A node's ability to deliver medical supplies depends on receiving them
  from upstream nodes in the supply chain
- This DAG structure captures how failures propagate through the network

HIERARCHICAL LEVELS (based on paper's node categorization):
  Level 0 (SOURCES): Major hubs - Central hospitals that originate supplies
                     These are SOURCE-RECEIVER nodes with high infrastructure
  Level 1 (RELAYS):  Airports + Regional hubs - Fixed-wing relay points and
                     secondary distribution centers
  Level 2 (BRIDGES): Intermediate charging stations - Extend VTOL range,
                     bridge gaps in coverage
  Level 3 (SINKS):   Receiver hospitals - Endpoints that receive supplies

EDGE DIRECTION:
  Edges flow FROM higher levels TO lower levels (supply chain direction):
  Hub → Airport → Intermediate → Receiver

  This represents: "If upstream node fails, downstream nodes lose supply access"

PARETO POINTS FROM PAPER (Figure 11):
  Point 1: High Resilience, Slow - Fixed-wing heavy, centralized, many airfields
  Point 2: High Resilience, Fast - Dense VTOL mesh, decentralized
  Point 3: Medium Resilience, Sparse - Fewer drone ports, FW-heavy
  Point 4: Low Resilience, Minimal - Few large hubs, minimal redundancy
  Point 5: Medium Resilience, FW variant - Airport-centric relays
  Point 6: Balanced - Moderate VTOL + fixed-wing mix

RELIABILITY DIFFERENTIATION:
  - High resilience networks: More forks (redundant supply paths)
  - Low resilience networks: Tree-like structure (single supply paths)
  - The fork/join ratio indicates redundancy level

================================================================================
"""

using CSV
using DataFrames
using JSON
using Printf

# File paths
const NODES_FILE = "csvfiles/drone_info/nodes.csv"
const DRONE1_FILE = "csvfiles/drone_info/drone1.csv"  # VTOL distances
const DRONE2_FILE = "csvfiles/drone_info/drone2.csv"  # Fixed-wing distances
const OUTPUT_DIR = "dag_ntwrk_files"

# Drone specifications from paper Table 1
const VTOL_RANGE = 70000.0      # 70 km in meters
const FIXED_WING_RANGE = 700000.0  # 700 km in meters

# ============================================================================
# DATA LOADING
# ============================================================================

function load_drone_network_data()
    """Load all drone network data files"""
    println("Loading drone network data...")

    nodes_df = CSV.read(NODES_FILE, DataFrame)
    println("  Loaded $(nrow(nodes_df)) nodes")

    drone1_df = CSV.read(DRONE1_FILE, DataFrame, header=1)
    drone2_df = CSV.read(DRONE2_FILE, DataFrame, header=1)

    # Convert to numeric matrices
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

    println("  Loaded distance matrices: $(size(drone1_matrix))")
    return nodes_df, drone1_matrix, drone2_matrix
end

# ============================================================================
# HIERARCHICAL NODE CLASSIFICATION
# ============================================================================

"""
Classify nodes into hierarchical levels for DAG construction.

Level 0 (Sources): Major hubs - SOURCE-RECEIVER with DP_type >= 2
Level 1 (Relays):  Airports (city_type == "A") + minor hubs (SOURCE-RECEIVER with DP_type == 1)
Level 2 (Bridges): Intermediate stations (city_type == "new", GENERIC)
Level 3 (Sinks):   Receiver hospitals (RECEIVER type)

Returns: Dict mapping node_id => level
"""
function classify_nodes_hierarchical(nodes_df)
    node_levels = Dict{Int, Int}()

    level_0_nodes = Int[]  # Major hubs (sources)
    level_1_nodes = Int[]  # Airports + minor hubs (relays)
    level_2_nodes = Int[]  # Intermediate stations (bridges)
    level_3_nodes = Int[]  # Receivers (sinks)

    for row in eachrow(nodes_df)
        node_id = row.numberID
        sr_type = row.source_receiver_type
        city_type = row.city_type
        dp_type = row.DP_type

        if sr_type == "SOURCE-RECEIVER"
            if dp_type >= 2
                # Major hub - Level 0 (source)
                node_levels[node_id] = 0
                push!(level_0_nodes, node_id)
            else
                # Minor hub - Level 1 (relay)
                node_levels[node_id] = 1
                push!(level_1_nodes, node_id)
            end
        elseif city_type == "A"
            # Airport - Level 1 (relay)
            node_levels[node_id] = 1
            push!(level_1_nodes, node_id)
        elseif city_type == "new" || (sr_type == "GENERIC" && city_type != "A")
            # Intermediate station - Level 2 (bridge)
            node_levels[node_id] = 2
            push!(level_2_nodes, node_id)
        elseif sr_type == "RECEIVER"
            # Receiver hospital - Level 3 (sink)
            node_levels[node_id] = 3
            push!(level_3_nodes, node_id)
        else
            # Default to level 2
            node_levels[node_id] = 2
            push!(level_2_nodes, node_id)
        end
    end

    println("\nHierarchical node classification:")
    println("  Level 0 (Major Hubs/Sources): $(length(level_0_nodes)) nodes")
    println("  Level 1 (Airports/Relays):    $(length(level_1_nodes)) nodes")
    println("  Level 2 (Intermediate):       $(length(level_2_nodes)) nodes")
    println("  Level 3 (Receivers/Sinks):    $(length(level_3_nodes)) nodes")

    return node_levels, level_0_nodes, level_1_nodes, level_2_nodes, level_3_nodes
end

"""
Get node index in the distance matrix from node ID
"""
function get_node_idx(nodes_df, node_id)
    return findfirst(x -> x == node_id, nodes_df.numberID)
end

"""
Get distance between two nodes using appropriate drone type
"""
function get_distance(nodes_df, vtol_matrix, fw_matrix, src_id, dst_id; use_fw=false)
    src_idx = get_node_idx(nodes_df, src_id)
    dst_idx = get_node_idx(nodes_df, dst_id)

    if src_idx === nothing || dst_idx === nothing
        return Inf
    end

    if use_fw
        return fw_matrix[src_idx, dst_idx]
    else
        return vtol_matrix[src_idx, dst_idx]
    end
end

"""
Check if a node is an airport (can use fixed-wing)
"""
function is_airport(nodes_df, node_id)
    idx = get_node_idx(nodes_df, node_id)
    if idx === nothing
        return false
    end
    return nodes_df[idx, :city_type] == "A"
end

"""
Convert distance to transmission/link probability using exponential decay.
Shorter distances = higher reliability.
"""
function distance_to_probability(distance, max_range; base_prob=0.95, decay_rate=2.0)
    if distance == Inf || isnan(distance) || distance <= 0
        return 0.0
    end

    # Exponential decay: prob = base_prob * exp(-decay_rate * distance/range)
    normalized_dist = distance / max_range
    probability = base_prob * exp(-decay_rate * normalized_dist)

    return clamp(probability, 0.5, 0.95)
end

"""
Calculate node prior probability based on infrastructure quality.
Higher infrastructure = more reliable node.
"""
function calculate_node_prior(row; is_source=false)
    if is_source
        return 1.0  # Sources are always available (by definition in reliability analysis)
    end

    # Base prior based on node type
    sr_type = row.source_receiver_type
    if sr_type == "SOURCE-RECEIVER"
        base_prior = 0.92
    elseif sr_type == "RECEIVER"
        base_prior = 0.85
    else  # GENERIC
        base_prior = 0.80
    end

    # Adjust based on infrastructure (CS_type, DP_type from paper Table 2)
    cs_bonus = row.CS_type * 0.015
    dp_bonus = row.DP_type * 0.015

    prior = clamp(base_prior + cs_bonus + dp_bonus, 0.70, 0.95)
    return prior
end

# ============================================================================
# DAG EDGE CREATION UTILITIES
# ============================================================================

"""
Add a directed edge respecting hierarchical ordering.
Edges flow from lower level numbers to higher level numbers.
(Source → Relay → Bridge → Sink)

For same-level connections, enforce src_id < dst_id to prevent cycles.
"""
function add_hierarchical_edge!(edges, edge_probs, node_levels,
                                src_id, dst_id, distance, max_range)
    src_level = get(node_levels, src_id, -1)
    dst_level = get(node_levels, dst_id, -1)

    if src_level == -1 || dst_level == -1
        return false
    end

    # For DAG property:
    # - Different levels: only allow lower level → higher level
    # - Same level: only allow smaller ID → larger ID (prevents bidirectional edges)
    can_add = false
    if src_level < dst_level
        can_add = true
    elseif src_level == dst_level && src_id < dst_id
        can_add = true
    end

    if can_add
        edge_key = "($src_id,$dst_id)"
        if !haskey(edge_probs, edge_key)
            push!(edges, (src_id, dst_id))
            edge_probs[edge_key] = distance_to_probability(distance, max_range)
            return true
        end
    end

    return false
end

"""
Find k nearest neighbors at a specific level or higher
"""
function find_nearest_at_level(nodes_df, vtol_matrix, fw_matrix,
                               src_id, target_level, node_levels, k;
                               max_range=VTOL_RANGE, use_fw=false)
    candidates = []

    for (node_id, level) in node_levels
        if level == target_level && node_id != src_id
            dist = get_distance(nodes_df, vtol_matrix, fw_matrix, src_id, node_id; use_fw=use_fw)
            if dist != Inf && !isnan(dist) && dist <= max_range
                push!(candidates, (node_id, dist))
            end
        end
    end

    sort!(candidates, by=x->x[2])
    return candidates[1:min(k, length(candidates))]
end

# ============================================================================
# PARETO POINT 1: HIGH RESILIENCE, FIXED-WING HEAVY
# ============================================================================

"""
PARETO POINT 1: High Resilience (~0.83), High Time Cost

Characteristics from Figure 13 (left):
- Fixed-wing backbone connecting all airports (high redundancy)
- Centralized VTOL clusters around major hubs
- Northern isles connected via fixed-wing only
- Multiple redundant supply paths through airport network

DAG Structure:
- Dense connections between Level 0 and Level 1 (hubs ↔ airports)
- Airport-to-airport connections (Level 1 → Level 1 same level allowed)
- Limited direct hub-to-receiver paths (most go through airports)
"""
function create_pareto_point_1(nodes_df, vtol_matrix, fw_matrix)
    println("\n" * "="^70)
    println("PARETO POINT 1: HIGH RESILIENCE (Fixed-Wing Heavy)")
    println("="^70)

    node_levels, level_0, level_1, level_2, level_3 = classify_nodes_hierarchical(nodes_df)

    edges = Tuple{Int, Int}[]
    edge_probs = Dict{String, Float64}()
    active_nodes = Set{Int}()

    # 1. Create dense fixed-wing backbone between ALL airports
    println("  Creating fixed-wing airport backbone...")
    airports = [n for n in level_1 if is_airport(nodes_df, n)]

    for i in 1:length(airports)
        for j in (i+1):length(airports)
            src_id, dst_id = airports[i], airports[j]
            dist = get_distance(nodes_df, vtol_matrix, fw_matrix, src_id, dst_id; use_fw=true)

            if dist != Inf && !isnan(dist)
                # Add edge in hierarchical direction (or same level for airports)
                add_hierarchical_edge!(edges, edge_probs, node_levels,
                                      src_id, dst_id, dist, FIXED_WING_RANGE)
                push!(active_nodes, src_id, dst_id)
            end
        end
    end

    # 2. Connect major hubs to multiple airports (redundancy)
    println("  Connecting hubs to airports (redundant paths)...")
    for hub_id in level_0
        push!(active_nodes, hub_id)

        # Connect to 3 nearest airports via VTOL
        nearest = find_nearest_at_level(nodes_df, vtol_matrix, fw_matrix,
                                        hub_id, 1, node_levels, 3;
                                        max_range=VTOL_RANGE, use_fw=false)

        for (airport_id, dist) in nearest
            if is_airport(nodes_df, airport_id)
                add_hierarchical_edge!(edges, edge_probs, node_levels,
                                      hub_id, airport_id, dist, VTOL_RANGE)
                push!(active_nodes, airport_id)
            end
        end
    end

    # 3. Connect hubs to nearby receivers (local VTOL clusters)
    println("  Creating local hub-receiver clusters...")
    for hub_id in level_0
        nearest_receivers = find_nearest_at_level(nodes_df, vtol_matrix, fw_matrix,
                                                  hub_id, 3, node_levels, 4;
                                                  max_range=VTOL_RANGE)

        for (recv_id, dist) in nearest_receivers
            add_hierarchical_edge!(edges, edge_probs, node_levels,
                                  hub_id, recv_id, dist, VTOL_RANGE)
            push!(active_nodes, recv_id)
        end
    end

    # 4. Connect airports to receivers (last mile via airports)
    println("  Connecting airports to receivers...")
    for airport_id in airports
        if !(airport_id in active_nodes)
            continue
        end

        nearest_receivers = find_nearest_at_level(nodes_df, vtol_matrix, fw_matrix,
                                                  airport_id, 3, node_levels, 3;
                                                  max_range=VTOL_RANGE)

        for (recv_id, dist) in nearest_receivers
            add_hierarchical_edge!(edges, edge_probs, node_levels,
                                  airport_id, recv_id, dist, VTOL_RANGE)
            push!(active_nodes, recv_id)
        end
    end

    # 5. Add intermediate stations to bridge coverage gaps
    println("  Adding intermediate bridge stations...")
    for int_id in level_2
        # Check if this intermediate connects multiple active nodes
        connections_to_active = 0

        for active_id in active_nodes
            dist = get_distance(nodes_df, vtol_matrix, fw_matrix, int_id, active_id)
            if dist != Inf && !isnan(dist) && dist <= VTOL_RANGE
                connections_to_active += 1
            end
        end

        if connections_to_active >= 2
            push!(active_nodes, int_id)

            # Connect from hubs/airports to this intermediate
            for src_id in union(level_0, airports)
                if src_id in active_nodes
                    dist = get_distance(nodes_df, vtol_matrix, fw_matrix, src_id, int_id)
                    if dist != Inf && !isnan(dist) && dist <= VTOL_RANGE
                        add_hierarchical_edge!(edges, edge_probs, node_levels,
                                              src_id, int_id, dist, VTOL_RANGE)
                    end
                end
            end

            # Connect from this intermediate to receivers
            nearest_receivers = find_nearest_at_level(nodes_df, vtol_matrix, fw_matrix,
                                                      int_id, 3, node_levels, 2;
                                                      max_range=VTOL_RANGE)
            for (recv_id, dist) in nearest_receivers
                add_hierarchical_edge!(edges, edge_probs, node_levels,
                                      int_id, recv_id, dist, VTOL_RANGE)
                push!(active_nodes, recv_id)
            end
        end
    end

    edges = unique(edges)
    println("  Result: $(length(active_nodes)) active nodes, $(length(edges)) edges")

    return edges, edge_probs, active_nodes, node_levels
end

# ============================================================================
# PARETO POINT 2: HIGH RESILIENCE, DENSE VTOL MESH
# ============================================================================

"""
PARETO POINT 2: High Resilience (~0.83), Low Time Cost, High Capital Cost

Characteristics from Figure 13 (right):
- Dense VTOL mesh with many drone ports activated
- Most intermediate stations active
- Multiple redundant VTOL paths
- Minimal fixed-wing reliance (islands only)

DAG Structure:
- Many parallel paths from hubs to receivers
- High fork count (supply redundancy)
- Intermediate stations heavily used as relay points
"""
function create_pareto_point_2(nodes_df, vtol_matrix, fw_matrix)
    println("\n" * "="^70)
    println("PARETO POINT 2: HIGH RESILIENCE (Dense VTOL Mesh)")
    println("="^70)

    node_levels, level_0, level_1, level_2, level_3 = classify_nodes_hierarchical(nodes_df)

    edges = Tuple{Int, Int}[]
    edge_probs = Dict{String, Float64}()
    active_nodes = Set{Int}()

    # Activate all hubs and all intermediates
    union!(active_nodes, level_0)
    union!(active_nodes, level_2)

    # 1. Create dense VTOL mesh between hubs
    println("  Creating dense hub-to-hub mesh...")
    for i in 1:length(level_0)
        for j in (i+1):length(level_0)
            src_id, dst_id = level_0[i], level_0[j]
            dist = get_distance(nodes_df, vtol_matrix, fw_matrix, src_id, dst_id)

            if dist != Inf && !isnan(dist) && dist <= VTOL_RANGE
                add_hierarchical_edge!(edges, edge_probs, node_levels,
                                      src_id, dst_id, dist, VTOL_RANGE)
            end
        end
    end

    # 2. Connect hubs to ALL reachable intermediates
    println("  Connecting hubs to intermediate stations...")
    for hub_id in level_0
        for int_id in level_2
            dist = get_distance(nodes_df, vtol_matrix, fw_matrix, hub_id, int_id)
            if dist != Inf && !isnan(dist) && dist <= VTOL_RANGE
                add_hierarchical_edge!(edges, edge_probs, node_levels,
                                      hub_id, int_id, dist, VTOL_RANGE)
            end
        end
    end

    # 3. Connect hubs directly to many receivers (dense coverage)
    println("  Creating dense hub-to-receiver connections...")
    for hub_id in level_0
        nearest_receivers = find_nearest_at_level(nodes_df, vtol_matrix, fw_matrix,
                                                  hub_id, 3, node_levels, 8;
                                                  max_range=VTOL_RANGE)

        for (recv_id, dist) in nearest_receivers
            add_hierarchical_edge!(edges, edge_probs, node_levels,
                                  hub_id, recv_id, dist, VTOL_RANGE)
            push!(active_nodes, recv_id)
        end
    end

    # 4. Connect intermediates to receivers
    println("  Connecting intermediates to receivers...")
    for int_id in level_2
        nearest_receivers = find_nearest_at_level(nodes_df, vtol_matrix, fw_matrix,
                                                  int_id, 3, node_levels, 5;
                                                  max_range=VTOL_RANGE)

        for (recv_id, dist) in nearest_receivers
            add_hierarchical_edge!(edges, edge_probs, node_levels,
                                  int_id, recv_id, dist, VTOL_RANGE)
            push!(active_nodes, recv_id)
        end
    end

    # 5. Minimal fixed-wing for islands only
    println("  Adding fixed-wing for island connections...")
    airports = [n for n in level_1 if is_airport(nodes_df, n)]

    # Find island airports (Orkney, Shetland, Western Isles - group_2 = 11, 12, 14)
    island_airports = Int[]
    mainland_airports = Int[]

    for airport_id in airports
        idx = get_node_idx(nodes_df, airport_id)
        if idx !== nothing
            group = nodes_df[idx, :group_2]
            if group in [11, 12, 14]
                push!(island_airports, airport_id)
            else
                push!(mainland_airports, airport_id)
            end
        end
    end

    # Connect island airports to nearest mainland airport
    for island_id in island_airports
        push!(active_nodes, island_id)

        best_mainland = nothing
        best_dist = Inf

        for mainland_id in mainland_airports
            dist = get_distance(nodes_df, vtol_matrix, fw_matrix, island_id, mainland_id; use_fw=true)
            if dist != Inf && !isnan(dist) && dist < best_dist
                best_dist = dist
                best_mainland = mainland_id
            end
        end

        if best_mainland !== nothing
            # Connect mainland to island (supply flows to islands)
            push!(active_nodes, best_mainland)
            add_hierarchical_edge!(edges, edge_probs, node_levels,
                                  best_mainland, island_id, best_dist, FIXED_WING_RANGE)

            # Connect island airport to local receivers
            nearest_receivers = find_nearest_at_level(nodes_df, vtol_matrix, fw_matrix,
                                                      island_id, 3, node_levels, 3;
                                                      max_range=VTOL_RANGE)
            for (recv_id, dist) in nearest_receivers
                add_hierarchical_edge!(edges, edge_probs, node_levels,
                                      island_id, recv_id, dist, VTOL_RANGE)
                push!(active_nodes, recv_id)
            end
        end
    end

    edges = unique(edges)
    println("  Result: $(length(active_nodes)) active nodes, $(length(edges)) edges")

    return edges, edge_probs, active_nodes, node_levels
end

# ============================================================================
# PARETO POINT 3: MEDIUM RESILIENCE, SPARSE
# ============================================================================

"""
PARETO POINT 3: Medium Resilience (~0.80), Medium Time Cost, Low Capital Cost

Characteristics from Figure 14 (left):
- Fewer drone ports than Points 1-2
- More reliance on fixed-wing
- Sparse VTOL coverage

DAG Structure:
- Fewer parallel paths (reduced redundancy)
- Key hubs and airports only
- Tree-like structure with limited branching
"""
function create_pareto_point_3(nodes_df, vtol_matrix, fw_matrix)
    println("\n" * "="^70)
    println("PARETO POINT 3: MEDIUM RESILIENCE (Sparse)")
    println("="^70)

    node_levels, level_0, level_1, level_2, level_3 = classify_nodes_hierarchical(nodes_df)

    edges = Tuple{Int, Int}[]
    edge_probs = Dict{String, Float64}()
    active_nodes = Set{Int}()

    # Only use major airports (DP_type >= 1)
    major_airports = Int[]
    for airport_id in level_1
        if is_airport(nodes_df, airport_id)
            idx = get_node_idx(nodes_df, airport_id)
            if idx !== nothing && nodes_df[idx, :DP_type] >= 1
                push!(major_airports, airport_id)
            end
        end
    end

    # 1. Sparse fixed-wing backbone between major airports only
    println("  Creating sparse fixed-wing backbone...")
    for i in 1:length(major_airports)
        for j in (i+1):length(major_airports)
            src_id, dst_id = major_airports[i], major_airports[j]
            dist = get_distance(nodes_df, vtol_matrix, fw_matrix, src_id, dst_id; use_fw=true)

            if dist != Inf && !isnan(dist)
                add_hierarchical_edge!(edges, edge_probs, node_levels,
                                      src_id, dst_id, dist, FIXED_WING_RANGE)
                push!(active_nodes, src_id, dst_id)
            end
        end
    end

    # 2. Connect only major hubs (DP_type >= 2) - already in level_0
    println("  Connecting major hubs...")
    for hub_id in level_0
        push!(active_nodes, hub_id)

        # Connect to nearest 1 airport only
        nearest = find_nearest_at_level(nodes_df, vtol_matrix, fw_matrix,
                                        hub_id, 1, node_levels, 1;
                                        max_range=VTOL_RANGE)
        for (airport_id, dist) in nearest
            if is_airport(nodes_df, airport_id)
                add_hierarchical_edge!(edges, edge_probs, node_levels,
                                      hub_id, airport_id, dist, VTOL_RANGE)
                push!(active_nodes, airport_id)
            end
        end

        # Connect to only 2 nearest receivers
        nearest_receivers = find_nearest_at_level(nodes_df, vtol_matrix, fw_matrix,
                                                  hub_id, 3, node_levels, 2;
                                                  max_range=VTOL_RANGE)
        for (recv_id, dist) in nearest_receivers
            add_hierarchical_edge!(edges, edge_probs, node_levels,
                                  hub_id, recv_id, dist, VTOL_RANGE)
            push!(active_nodes, recv_id)
        end
    end

    # 3. Connect airports to limited receivers
    println("  Connecting airports to receivers...")
    for airport_id in major_airports
        if airport_id in active_nodes
            nearest_receivers = find_nearest_at_level(nodes_df, vtol_matrix, fw_matrix,
                                                      airport_id, 3, node_levels, 2;
                                                      max_range=VTOL_RANGE)
            for (recv_id, dist) in nearest_receivers
                add_hierarchical_edge!(edges, edge_probs, node_levels,
                                      airport_id, recv_id, dist, VTOL_RANGE)
                push!(active_nodes, recv_id)
            end
        end
    end

    edges = unique(edges)
    println("  Result: $(length(active_nodes)) active nodes, $(length(edges)) edges")

    return edges, edge_probs, active_nodes, node_levels
end

# ============================================================================
# PARETO POINT 4: LOW RESILIENCE, MINIMAL
# ============================================================================

"""
PARETO POINT 4: Low Resilience (~0.78), Medium Time, Lowest Capital Cost

Characteristics from Figure 15:
- Concentration to few large drone ports
- Minimal infrastructure
- Each hub serves large area (vulnerable to failures)
- Near-tree structure with minimal redundancy

DAG Structure:
- Minimal spanning tree-like connectivity
- Single paths to most receivers
- Very few forks (low redundancy)
"""
function create_pareto_point_4(nodes_df, vtol_matrix, fw_matrix)
    println("\n" * "="^70)
    println("PARETO POINT 4: LOW RESILIENCE (Minimal)")
    println("="^70)

    node_levels, level_0, level_1, level_2, level_3 = classify_nodes_hierarchical(nodes_df)

    edges = Tuple{Int, Int}[]
    edge_probs = Dict{String, Float64}()
    active_nodes = Set{Int}()

    # Select only ONE hub per health board (minimal)
    health_board_hubs = Dict{Int, Int}()
    for hub_id in level_0
        idx = get_node_idx(nodes_df, hub_id)
        if idx !== nothing
            hb = nodes_df[idx, :group_2]
            current = get(health_board_hubs, hb, nothing)
            if current === nothing
                health_board_hubs[hb] = hub_id
            else
                # Keep the one with higher DP_type
                curr_idx = get_node_idx(nodes_df, current)
                if curr_idx !== nothing && nodes_df[idx, :DP_type] > nodes_df[curr_idx, :DP_type]
                    health_board_hubs[hb] = hub_id
                end
            end
        end
    end

    selected_hubs = collect(values(health_board_hubs))
    println("  Selected $(length(selected_hubs)) minimal hubs")

    # 1. Create minimal spanning tree between hubs
    println("  Creating minimal hub connectivity...")
    union!(active_nodes, selected_hubs)

    # Simple greedy MST approach
    connected = Set{Int}([selected_hubs[1]])

    while length(connected) < length(selected_hubs)
        best_edge = nothing
        best_dist = Inf
        best_range = VTOL_RANGE

        for src_id in connected
            for dst_id in selected_hubs
                if dst_id in connected
                    continue
                end

                # Try VTOL first
                dist = get_distance(nodes_df, vtol_matrix, fw_matrix, src_id, dst_id)
                range = VTOL_RANGE

                if dist == Inf || isnan(dist) || dist > VTOL_RANGE
                    # Try fixed-wing
                    dist = get_distance(nodes_df, vtol_matrix, fw_matrix, src_id, dst_id; use_fw=true)
                    range = FIXED_WING_RANGE
                end

                if dist != Inf && !isnan(dist) && dist < best_dist
                    best_dist = dist
                    best_edge = (src_id, dst_id)
                    best_range = range
                end
            end
        end

        if best_edge !== nothing
            src_id, dst_id = best_edge
            add_hierarchical_edge!(edges, edge_probs, node_levels,
                                  src_id, dst_id, best_dist, best_range)
            push!(connected, dst_id)
        else
            break
        end
    end

    # 2. Each hub connects to only 2 nearest receivers (minimal)
    println("  Connecting hubs to minimal receivers...")
    for hub_id in selected_hubs
        nearest_receivers = find_nearest_at_level(nodes_df, vtol_matrix, fw_matrix,
                                                  hub_id, 3, node_levels, 2;
                                                  max_range=VTOL_RANGE)
        for (recv_id, dist) in nearest_receivers
            add_hierarchical_edge!(edges, edge_probs, node_levels,
                                  hub_id, recv_id, dist, VTOL_RANGE)
            push!(active_nodes, recv_id)
        end
    end

    edges = unique(edges)
    println("  Result: $(length(active_nodes)) active nodes, $(length(edges)) edges")

    return edges, edge_probs, active_nodes, node_levels
end

# ============================================================================
# PARETO POINT 5: MEDIUM RESILIENCE, FIXED-WING VARIANT
# ============================================================================

"""
PARETO POINT 5: Medium Resilience (~0.805), High Time Cost

Characteristics from Figure 14 (right):
- Similar to Point 3 but more fixed-wing heavy
- Fewer VTOL connections
- More reliance on airports as relay points

DAG Structure:
- Airport-centric supply distribution
- Hubs feed airports, airports feed receivers
- Limited direct hub-to-receiver paths
"""
function create_pareto_point_5(nodes_df, vtol_matrix, fw_matrix)
    println("\n" * "="^70)
    println("PARETO POINT 5: MEDIUM RESILIENCE (Fixed-Wing Variant)")
    println("="^70)

    node_levels, level_0, level_1, level_2, level_3 = classify_nodes_hierarchical(nodes_df)

    edges = Tuple{Int, Int}[]
    edge_probs = Dict{String, Float64}()
    active_nodes = Set{Int}()

    airports = [n for n in level_1 if is_airport(nodes_df, n)]

    # 1. Full airport network via fixed-wing
    println("  Creating full airport network...")
    for i in 1:length(airports)
        for j in (i+1):length(airports)
            src_id, dst_id = airports[i], airports[j]
            dist = get_distance(nodes_df, vtol_matrix, fw_matrix, src_id, dst_id; use_fw=true)

            if dist != Inf && !isnan(dist)
                add_hierarchical_edge!(edges, edge_probs, node_levels,
                                      src_id, dst_id, dist, FIXED_WING_RANGE)
                push!(active_nodes, src_id, dst_id)
            end
        end
    end

    # 2. Hubs connect to nearest airport only (single relay)
    println("  Connecting hubs to airports...")
    for hub_id in level_0
        push!(active_nodes, hub_id)

        nearest = find_nearest_at_level(nodes_df, vtol_matrix, fw_matrix,
                                        hub_id, 1, node_levels, 1;
                                        max_range=VTOL_RANGE)
        for (airport_id, dist) in nearest
            if is_airport(nodes_df, airport_id)
                add_hierarchical_edge!(edges, edge_probs, node_levels,
                                      hub_id, airport_id, dist, VTOL_RANGE)
            end
        end

        # Only 1 direct receiver connection per hub
        nearest_receivers = find_nearest_at_level(nodes_df, vtol_matrix, fw_matrix,
                                                  hub_id, 3, node_levels, 1;
                                                  max_range=VTOL_RANGE)
        for (recv_id, dist) in nearest_receivers
            add_hierarchical_edge!(edges, edge_probs, node_levels,
                                  hub_id, recv_id, dist, VTOL_RANGE)
            push!(active_nodes, recv_id)
        end
    end

    # 3. Airports serve as main distribution to receivers
    println("  Distributing from airports to receivers...")
    for airport_id in airports
        if airport_id in active_nodes
            nearest_receivers = find_nearest_at_level(nodes_df, vtol_matrix, fw_matrix,
                                                      airport_id, 3, node_levels, 3;
                                                      max_range=VTOL_RANGE)
            for (recv_id, dist) in nearest_receivers
                add_hierarchical_edge!(edges, edge_probs, node_levels,
                                      airport_id, recv_id, dist, VTOL_RANGE)
                push!(active_nodes, recv_id)
            end
        end
    end

    edges = unique(edges)
    println("  Result: $(length(active_nodes)) active nodes, $(length(edges)) edges")

    return edges, edge_probs, active_nodes, node_levels
end

# ============================================================================
# PARETO POINT 6: BALANCED
# ============================================================================

"""
PARETO POINT 6: Balanced (~0.81 Resilience), Medium Time, Medium Cost

Characteristics from Figure 12:
- Moderate VTOL coverage
- Some intermediate stations active (strategic ones)
- Balanced mix of VTOL and fixed-wing
- Good all-around performance

DAG Structure:
- Moderate branching factor
- Strategic intermediate stations as bridges
- Balance between redundancy and efficiency
"""
function create_pareto_point_6(nodes_df, vtol_matrix, fw_matrix)
    println("\n" * "="^70)
    println("PARETO POINT 6: BALANCED")
    println("="^70)

    node_levels, level_0, level_1, level_2, level_3 = classify_nodes_hierarchical(nodes_df)

    edges = Tuple{Int, Int}[]
    edge_probs = Dict{String, Float64}()
    active_nodes = Set{Int}()

    airports = [n for n in level_1 if is_airport(nodes_df, n)]

    # 1. Select strategic intermediate stations (those connecting 3+ hubs)
    println("  Selecting strategic intermediate stations...")
    strategic_intermediate = Int[]

    for int_id in level_2
        hub_connections = 0
        for hub_id in level_0
            dist = get_distance(nodes_df, vtol_matrix, fw_matrix, int_id, hub_id)
            if dist != Inf && !isnan(dist) && dist <= VTOL_RANGE
                hub_connections += 1
            end
        end

        if hub_connections >= 3
            push!(strategic_intermediate, int_id)
        end
    end

    println("    Found $(length(strategic_intermediate)) strategic intermediate stations")

    # 2. Create moderate hub-to-hub mesh
    println("  Creating moderate hub connectivity...")
    for hub_id in level_0
        push!(active_nodes, hub_id)

        # Connect to other hubs within VTOL range
        for other_hub in level_0
            if other_hub == hub_id
                continue
            end

            dist = get_distance(nodes_df, vtol_matrix, fw_matrix, hub_id, other_hub)
            if dist != Inf && !isnan(dist) && dist <= VTOL_RANGE
                add_hierarchical_edge!(edges, edge_probs, node_levels,
                                      hub_id, other_hub, dist, VTOL_RANGE)
            end
        end

        # Connect to strategic intermediates
        for int_id in strategic_intermediate
            dist = get_distance(nodes_df, vtol_matrix, fw_matrix, hub_id, int_id)
            if dist != Inf && !isnan(dist) && dist <= VTOL_RANGE
                add_hierarchical_edge!(edges, edge_probs, node_levels,
                                      hub_id, int_id, dist, VTOL_RANGE)
                push!(active_nodes, int_id)
            end
        end

        # Connect to 3 nearest receivers
        nearest_receivers = find_nearest_at_level(nodes_df, vtol_matrix, fw_matrix,
                                                  hub_id, 3, node_levels, 3;
                                                  max_range=VTOL_RANGE)
        for (recv_id, dist) in nearest_receivers
            add_hierarchical_edge!(edges, edge_probs, node_levels,
                                  hub_id, recv_id, dist, VTOL_RANGE)
            push!(active_nodes, recv_id)
        end
    end

    # 3. Connect strategic intermediates to receivers
    println("  Connecting intermediates to receivers...")
    for int_id in strategic_intermediate
        if int_id in active_nodes
            nearest_receivers = find_nearest_at_level(nodes_df, vtol_matrix, fw_matrix,
                                                      int_id, 3, node_levels, 3;
                                                      max_range=VTOL_RANGE)
            for (recv_id, dist) in nearest_receivers
                add_hierarchical_edge!(edges, edge_probs, node_levels,
                                      int_id, recv_id, dist, VTOL_RANGE)
                push!(active_nodes, recv_id)
            end
        end
    end

    # 4. Add fixed-wing for distant connections only
    println("  Adding fixed-wing for distant regions...")
    for i in 1:length(airports)
        for j in (i+1):length(airports)
            src_id, dst_id = airports[i], airports[j]

            # Only add fixed-wing if VTOL can't reach
            vtol_dist = get_distance(nodes_df, vtol_matrix, fw_matrix, src_id, dst_id)

            if vtol_dist == Inf || isnan(vtol_dist) || vtol_dist > VTOL_RANGE
                fw_dist = get_distance(nodes_df, vtol_matrix, fw_matrix, src_id, dst_id; use_fw=true)
                if fw_dist != Inf && !isnan(fw_dist)
                    add_hierarchical_edge!(edges, edge_probs, node_levels,
                                          src_id, dst_id, fw_dist, FIXED_WING_RANGE)
                    push!(active_nodes, src_id, dst_id)
                end
            end
        end
    end

    # 5. Connect airports to nearest hub (integrate airport network)
    for airport_id in airports
        if airport_id in active_nodes
            continue
        end

        best_hub = nothing
        best_dist = Inf

        for hub_id in level_0
            dist = get_distance(nodes_df, vtol_matrix, fw_matrix, airport_id, hub_id)
            if dist != Inf && !isnan(dist) && dist < best_dist
                best_dist = dist
                best_hub = hub_id
            end
        end

        if best_hub !== nothing && best_dist <= VTOL_RANGE
            add_hierarchical_edge!(edges, edge_probs, node_levels,
                                  best_hub, airport_id, best_dist, VTOL_RANGE)
            push!(active_nodes, airport_id)
        end
    end

    edges = unique(edges)
    println("  Result: $(length(active_nodes)) active nodes, $(length(edges)) edges")

    return edges, edge_probs, active_nodes, node_levels
end

# ============================================================================
# FILE OUTPUT
# ============================================================================

function identify_sources_sinks(edges, active_nodes)
    """Identify source nodes (no incoming) and sink nodes (no outgoing)"""
    has_incoming = Set{Int}()
    has_outgoing = Set{Int}()

    for (src, dst) in edges
        push!(has_outgoing, src)
        push!(has_incoming, dst)
    end

    sources = [n for n in active_nodes if !(n in has_incoming)]
    sinks = [n for n in active_nodes if !(n in has_outgoing)]

    # Count forks and joins
    in_degree = Dict{Int, Int}()
    out_degree = Dict{Int, Int}()

    for (src, dst) in edges
        out_degree[src] = get(out_degree, src, 0) + 1
        in_degree[dst] = get(in_degree, dst, 0) + 1
    end

    forks = sum(d > 1 ? 1 : 0 for d in values(out_degree))
    joins = sum(d > 1 ? 1 : 0 for d in values(in_degree))

    return sources, sinks, forks, joins
end

function save_dag_files(name, edges, edge_probs, active_nodes, node_levels, nodes_df)
    """Save DAG in required format"""
    println("\nSaving DAG files for: $name")

    output_path = joinpath(OUTPUT_DIR, name)
    mkpath(output_path)
    mkpath(joinpath(output_path, "float"))

    sources, sinks, forks, joins = identify_sources_sinks(edges, active_nodes)

    # Save edges file
    edges_file = joinpath(output_path, "$name.EDGES")
    open(edges_file, "w") do f
        println(f, "source,destination")
        for (src, dst) in edges
            println(f, "$src,$dst")
        end
    end

    # Calculate node priors
    node_priors = Dict{String, Float64}()
    for node_id in active_nodes
        idx = get_node_idx(nodes_df, node_id)
        if idx !== nothing
            is_src = node_id in sources
            node_priors[string(node_id)] = calculate_node_prior(nodes_df[idx, :]; is_source=is_src)
        end
    end

    # Save node priors JSON
    priors_data = Dict(
        "nodes" => node_priors,
        "data_type" => "Float64",
        "serialization" => "compact",
        "description" => "Node prior probabilities for $name (Pareto point from Jones et al. paper). Sources have prior=1.0."
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
        "description" => "Link/edge probabilities for $name. Probability based on distance (shorter = more reliable)."
    )

    links_file = joinpath(output_path, "float", "$name-linkprobabilities.json")
    open(links_file, "w") do f
        JSON.print(f, links_data, 2)
    end

    println("  Saved to: $output_path")
    println("  Statistics:")
    println("    Nodes: $(length(active_nodes))")
    println("    Edges: $(length(edges))")
    println("    Sources: $(length(sources))")
    println("    Sinks: $(length(sinks))")
    println("    Forks: $forks")
    println("    Joins: $joins")

    return (length(active_nodes), length(edges), length(sources), length(sinks), forks, joins)
end

# ============================================================================
# MAIN GENERATION FUNCTION
# ============================================================================

function generate_all_pareto_points()
    """Generate all 6 Pareto point DAGs with proper hierarchical structure"""

    println("="^80)
    println("DRONE NETWORK DAG GENERATOR - RELIABILITY CASE STUDIES")
    println("Based on: 'Conceptual design of a medical drone logistics network for Scotland'")
    println("          Jones et al., University of Strathclyde")
    println("="^80)

    # Load data
    nodes_df, vtol_matrix, fw_matrix = load_drone_network_data()

    results = []

    # Point 1: High Resilience, Fixed-Wing Heavy
    edges1, probs1, nodes1, levels1 = create_pareto_point_1(nodes_df, vtol_matrix, fw_matrix)
    stats1 = save_dag_files("pareto-point-1-high-resilience-fw", edges1, probs1, nodes1, levels1, nodes_df)
    push!(results, ("Point 1 (High Resilience, FW Heavy)", stats1...))

    # Point 2: High Resilience, Dense VTOL
    edges2, probs2, nodes2, levels2 = create_pareto_point_2(nodes_df, vtol_matrix, fw_matrix)
    stats2 = save_dag_files("pareto-point-2-high-resilience-vtol", edges2, probs2, nodes2, levels2, nodes_df)
    push!(results, ("Point 2 (High Resilience, Dense VTOL)", stats2...))

    # Point 3: Medium Resilience, Sparse
    edges3, probs3, nodes3, levels3 = create_pareto_point_3(nodes_df, vtol_matrix, fw_matrix)
    stats3 = save_dag_files("pareto-point-3-medium-resilience-sparse", edges3, probs3, nodes3, levels3, nodes_df)
    push!(results, ("Point 3 (Medium Resilience, Sparse)", stats3...))

    # Point 4: Low Resilience, Minimal
    edges4, probs4, nodes4, levels4 = create_pareto_point_4(nodes_df, vtol_matrix, fw_matrix)
    stats4 = save_dag_files("pareto-point-4-low-resilience-minimal", edges4, probs4, nodes4, levels4, nodes_df)
    push!(results, ("Point 4 (Low Resilience, Minimal)", stats4...))

    # Point 5: Medium Resilience, FW Variant
    edges5, probs5, nodes5, levels5 = create_pareto_point_5(nodes_df, vtol_matrix, fw_matrix)
    stats5 = save_dag_files("pareto-point-5-medium-resilience-fw", edges5, probs5, nodes5, levels5, nodes_df)
    push!(results, ("Point 5 (Medium Resilience, FW Variant)", stats5...))

    # Point 6: Balanced
    edges6, probs6, nodes6, levels6 = create_pareto_point_6(nodes_df, vtol_matrix, fw_matrix)
    stats6 = save_dag_files("pareto-point-6-balanced", edges6, probs6, nodes6, levels6, nodes_df)
    push!(results, ("Point 6 (Balanced)", stats6...))

    # Summary
    println("\n" * "="^80)
    println("GENERATION COMPLETE - 6 PARETO POINT DAGs CREATED")
    println("="^80)

    println("\nSummary Table:")
    println("-"^90)
    println("Network                              | Nodes | Edges | Sources | Sinks | Forks | Joins")
    println("-"^90)

    for (name, nodes, edges, sources, sinks, forks, joins) in results
        @printf("%-36s | %5d | %5d | %7d | %5d | %5d | %5d\n",
                name, nodes, edges, sources, sinks, forks, joins)
    end
    println("-"^90)

    println("\nExpected characteristics from paper:")
    println("  Point 1: Highest resilience (~0.83), slowest (fixed-wing heavy)")
    println("  Point 2: High resilience (~0.83), fastest (dense VTOL mesh)")
    println("  Point 3: Medium resilience (~0.80), medium cost (sparse)")
    println("  Point 4: Lowest resilience (~0.78), lowest cost (minimal)")
    println("  Point 5: Medium resilience (~0.805), slow (FW variant)")
    println("  Point 6: Balanced trade-off (~0.81 resilience)")

    println("\nDAG Interpretation for Reliability Analysis:")
    println("  - Higher fork count = more redundant supply paths = higher resilience")
    println("  - Sources = Major hubs (supply origins, prior=1.0)")
    println("  - Sinks = Receiver hospitals (supply endpoints)")
    println("  - Edge probabilities based on distance (shorter = more reliable)")
end

# Run if executed directly
if abspath(PROGRAM_FILE) == @__FILE__
    generate_all_pareto_points()
end
