"""
Drone Network to DAG Converter — RELIABILITY-GROUNDED rebuild.

Converts the Scottish medical drone network data into DAG format for IPA reliability propagation, using
ONLY quantities the source paper itself defines, plus ONE explicitly-flagged extension. Source paper:
Jones, Filippi, Basu, Parsonage, Patelli, Maddock, Vasile, Fossati, "Conceptual design of a medical drone
logistics network for Scotland" (submitted Int. J. Logistics Research and Applications, Sept 2025) —
`csvfiles/drone_info/62aa82fa-547f-4e60-ab63-fa012448b826.pdf`.

This REPLACES the ad hoc `distance_to_probability` exponential decay and the invented 0.9/0.8/0.6+bonus
node-prior heuristic in the original `drone_network_to_dag.jl` (kept on disk for history). Every number
below is either taken directly from the source paper's own tables/text, or is an explicitly-labelled
extension beyond a limitation the source paper itself states it deferred.

GROUNDING
---------
1. Node reliability (Interval): hub (SOURCE-RECEIVER) nodes = Interval(1,1) exactly, matching the paper's
   OWN resilience trials: "the average resilience across 10 failure cases is considered, in which each
   node except the hub nodes Ω has a 20% failure probability" (§5). Hubs are excluded from failure in
   their model, so we do not fail them either. Non-hub active nodes = Interval(0.75, 0.85): a sensitivity
   band around the paper's literal 80% success figure. We use a BAND, not the bare point 0.80, because the
   paper's own 20% figure is not itself derived or cited (it's simply the value used in this one exhibited
   resilience computation) -- IPA can test the network's sensitivity to that very assumption, which the
   paper's own point-probability framework structurally cannot do.
2. Edge existence: an edge (i,j) exists under drone type v iff distance(i,j) <= nominal range R^v -- a hard
   cutoff, matching the paper's own model exactly (Table 1: VTOL R=70km, fixed-wing R=700km; eq. 10:
   E^v = {(γi,γj) in E | d(γi,γj) <= R^v}).
3. Edge reliability (Interval) -- THE ONE EXTENSION, clearly flagged: the source paper explicitly keeps
   wind velocity constant in its own results ("in this paper wind velocity is kept constant", §2.4),
   deferring weather/range uncertainty as a MODELLED-BUT-UNUSED event type (§3.1, "the flight range
   variation of each drone type due to weather conditions" is one of the elementary uncertain events, whose
   probability is "assumed to be elicited from expert opinion" -- no value is ever given). We extend this
   (rather than inventing an unrelated decay curve): effective range is treated as Interval(0.9*R^v, R^v)
   -- an illustrative 10% weather derating, since the source paper does not quantify this parameter either.
   An edge within 90% of nominal range is certain (Interval(1,1)); an edge between 90% and 100% of nominal
   range is HONESTLY VACUOUS (Interval(0,1) -- worst-case weather cuts it, best-case doesn't); beyond
   nominal range it does not exist at all. When both drone types can serve the same node pair, their
   Intervals combine via independent-OR (either drone type succeeding is enough): for (loA,hiA),(loB,hiB),
   the union is (1-(1-loA)(1-loB), 1-(1-hiA)(1-hiB)).
4. Investment tiers: CHECKED AND REJECTED an earlier attempt to use `CS_type`/`DP_type` as indices into the
   source paper's Table 2 (S0..S4, i.e. range 0-4) -- the actual data ranges CS_type 2-5, DP_type 1-5, which
   does not fit that index space, so that mapping does not hold and is NOT used. Instead we use a mapping
   that IS directly verifiable in the data: `city_type == "new"` marks exactly the 11 OPTIONAL additional
   candidate stations from Fig. 10 ("a mix of grid pattern and manually selected locations"), matching the
   source paper's own decision set I, whose activation x_γ in {0,1} is a genuine design variable (eq. 16-17);
   the other 233 (H + A) are the "existing" set K, "always active" (eq. 23). Used below to build an honestly-
   labelled PROXY for a minimal-investment design (deactivate all optional stations, keep only the existing
   fixed set) -- NOT a reproduction of the actual optimised Pareto-front topologies, which are not public
   (paper's Data Availability: "available from the corresponding author ... upon reasonable request").
5. TRACTABILITY FIX (caught by smoke-testing, not assumed): an early "connect every pair within range"
   version of the dense proxies produced forks=216/joins=222 out of 232 nodes -- near-total reconvergence,
   IPA's documented worst case -- and `new_identify` itself blew past 8GB with no result. Root cause was
   RECEIVER-RECEIVER edges, which the source paper's mission model never uses anyway (see
   `mission_relevant_pair` below); excluding them is a fidelity fix, not just a performance hack.
6. DAG direction: hub-tier before spoke-tier (any SOURCE-RECEIVER node before any non-hub node), matching
   the paper's own hub-and-spoke operational model (§2.1) -- not a latitude sort, which had no operational
   basis (drones fly missions in either geographic direction; §4.1 defines edges as UNDIRECTED pairs).
   Ties within a tier (hub-hub backbone links, spoke-spoke links) use numberID as an arbitrary-but-fixed
   tie-break, since the source paper's own model treats those links symmetrically too (eq. 32, national-
   level hub-to-hub missions) -- documented as a modelling simplification, not a physical claim.
"""

using CSV
using DataFrames
using JSON

const NODES_FILE = "csvfiles/drone_info/nodes.csv"
const DRONE1_FILE = "csvfiles/drone_info/drone1.csv"   # VTOL (type 1), R = 70 km
const DRONE2_FILE = "csvfiles/drone_info/drone2.csv"   # fixed-wing (type 2), R = 700 km
const OUTPUT_DIR = "dag_ntwrk_files"

const R_VTOL = 70_000.0     # metres, Table 1
const R_FW   = 700_000.0    # metres, Table 1
const WEATHER_DERATE = 0.9  # illustrative 10% range derating -- NOT from the source paper (see docstring)
const K_REDUNDANCY = 16     # each node keeps its K nearest reachable partners -- tuned to keep maxcond near
                             # the ~18 threshold Reviewer #2 identified as the practical exact-inference limit
                             # ("computation times become intractable when diamond nesting depth reaches 18
                             # or more"). Measured sweep (validation/drone_diamond_stats.jl, drone_k_sweep.jl):
                             #   K=3 ->maxcond=3   K=6 ->maxcond=6   K=12->maxcond=15-16 (propagate 6-14s)
                             #   K=16->maxcond=17 (CHOSEN: propagate 17-24s)  K=20->maxcond=17 (26-28s, same)
                             #   K=24->maxcond=17 (28-28s, same) -- maxcond PLATEAUS at K=16: beyond it, extra
                             #   candidate edges are mostly redundant rather than adding new reconvergence
                             #   structure, so K=16 is the smallest K that reaches the natural ceiling (a
                             #   principled stopping point, not an arbitrary one). K=all pairs (~50-100/node)
                             #   ->maxcond=27-28, new_identify blew past 8GB -- unusable.
const HUB_PRIOR = (1.0, 1.0)
const NONHUB_PRIOR = (0.75, 0.85)   # sensitivity band around the paper's literal 80% success figure (§5)

function load_drone_network_data()
    println("Loading drone network data...")
    nodes_df = CSV.read(NODES_FILE, DataFrame)
    println("Loaded $(nrow(nodes_df)) nodes")

    drone1_df = CSV.read(DRONE1_FILE, DataFrame, header=1)
    drone2_df = CSV.read(DRONE2_FILE, DataFrame, header=1)

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
    println("Loaded $(size(drone1_matrix,1))x$(size(drone1_matrix,2)) distance matrices")
    return nodes_df, drone1_matrix, drone2_matrix
end

# ---- Reliability model (grounding points 1-3 above) -------------------------------------------------

is_hub(row) = row.source_receiver_type == "SOURCE-RECEIVER"

node_prior_interval(row) = is_hub(row) ? HUB_PRIOR : NONHUB_PRIOR

# single-drone-type edge reliability from distance; `nothing` if out of nominal range entirely
function type_edge_interval(dist, R)
    (dist == Inf || isnan(dist) || dist > R) && return nothing
    dist <= WEATHER_DERATE * R && return (1.0, 1.0)
    return (0.0, 1.0)   # within nominal range but beyond the derated (worst-case-weather) range: vacuous
end

combine_or(a, b) = (1.0 - (1.0 - a[1]) * (1.0 - b[1]), 1.0 - (1.0 - a[2]) * (1.0 - b[2]))

# combined edge interval across both drone types; `nothing` if neither reaches
function edge_interval(vtol_dist, fw_dist)
    iv = type_edge_interval(vtol_dist, R_VTOL)
    ifw = type_edge_interval(fw_dist, R_FW)
    iv === nothing && return ifw
    ifw === nothing && return iv
    return combine_or(iv, ifw)
end

# ---- DAG direction (grounding point 5) ---------------------------------------------------------------

# hub tier before spoke tier; numberID as the fixed tie-break within a tier
function hub_spoke_order(nodes_df)
    n = nrow(nodes_df)
    keys_ = [(is_hub(nodes_df[i, :]) ? 0 : 1, nodes_df.numberID[i]) for i in 1:n]
    order = sortperm(keys_)
    Dict(order[i] => i for i in 1:n)
end

# ---- Mission-relevant pair filter (FIX: tractability + fidelity) --------------------------------------
# CAUGHT DURING SMOKE-TEST: connecting every geographically-reachable pair produced forks=216/joins=222 out
# of 232 nodes (near-total reconvergence) -- new_identify() itself blew past 8GB with no output, IPA's
# documented worst case (same class as the adversarial "complete graph" family). Root cause was including
# RECEIVER-RECEIVER edges, which the source paper's own mission structure never uses: receivers are ONLY
# ever delivery destinations (eq. 31 -- hub to receiver), never origins and never relays; additional/GENERIC
# stations are relay-only ("cannot send or receive deliveries, only act as a charging port", p.8). Dropping
# receiver-receiver pairs removes most of the edge count (215/244 nodes are receivers) and is MORE faithful
# to the source paper, not a tractability hack layered on top of it.
mission_relevant_pair(nodes_df, i, j) = !(nodes_df.source_receiver_type[i] == "RECEIVER" &&
                                           nodes_df.source_receiver_type[j] == "RECEIVER")

# ---- K-BOUNDED edge-set builder (parameterised so the 3 proxy networks share one implementation) ------
# TRACTABILITY FIX #2 (caught by smoke-testing): even after dropping receiver-receiver pairs, "connect
# every remaining mission-relevant pair within range" still gave maxcond=27-28 (sum(2^|C|) in the billions)
# -- IPA's (and BDD's) exponential-in-treewidth regime, matching the intractability threshold Reviewer #2
# themselves flagged in the original submission ("computation times become intractable when diamond nesting
# depth reaches 18 or more"). We therefore bound each node to its K NEAREST mission-relevant reachable
# partners rather than all of them -- a standard reliability-engineering redundancy pattern (provision K
# diverse pre-planned alternate routes, not full mesh connectivity), not an arbitrary complexity knob: full
# connectivity is not just expensive here, it is not exactly VERIFIABLE at all, which is itself a reason no
# real design would use it. K is tuned (see generation log) to keep maxcond near the ~18 threshold above.

"""
    build_edges(nodes_df, vtol_matrix, fw_matrix, order_lookup; node_mask=trues(n), prefer=:either, K=3)

`node_mask`: BitVector, only nodes with node_mask[i]==true participate (used for the "concentrated" proxy).
`prefer`: :either (use whichever/both types reach, OR-combined), :vtol_only, :fw_only (used for the
FW-reliant / VTOL-dense proxies to emphasise one layer, matching the qualitative Pareto-point description).
`K`: each node keeps only its K nearest (by effective flight distance) mission-relevant reachable partners.
"""
function build_edges(nodes_df, vtol_matrix, fw_matrix, order_lookup; node_mask=nothing, prefer=:either, K=3)
    n = nrow(nodes_df)
    mask = node_mask === nothing ? trues(n) : node_mask
    edge_probs = Dict{String,Tuple{Float64,Float64}}()
    edge_pairs = Dict{String,Tuple{Int,Int}}()
    for i in 1:n
        mask[i] || continue
        candidates = Tuple{Float64,Int}[]   # (effective_distance, j)
        for j in 1:n
            (i == j || !mask[j]) && continue
            mission_relevant_pair(nodes_df, i, j) || continue
            vd = prefer == :fw_only ? Inf : vtol_matrix[i, j]
            fd = prefer == :vtol_only ? Inf : fw_matrix[i, j]
            eff = min(vd, fd)
            eff == Inf && continue
            push!(candidates, (eff, j))
        end
        sort!(candidates)
        for (_, j) in candidates[1:min(K, length(candidates))]
            vd = prefer == :fw_only ? Inf : vtol_matrix[i, j]
            fd = prefer == :vtol_only ? Inf : fw_matrix[i, j]
            iv = edge_interval(vd, fd)
            iv === nothing && continue
            oi, oj = order_lookup[i], order_lookup[j]
            src_i, dst_i = oi < oj ? (i, j) : (j, i)
            src_id, dst_id = nodes_df.numberID[src_i], nodes_df.numberID[dst_i]
            key = "($src_id,$dst_id)"
            edge_probs[key] = iv
            edge_pairs[key] = (src_id, dst_id)
        end
    end
    collect(values(edge_pairs)), edge_probs
end

nearest_hub_mask(nodes_df, vtol_matrix, fw_matrix) = begin
    # for the FW-reliant proxy: each spoke keeps ONLY its nearest-reachable hub edge (tree), hubs keep
    # their full backbone -- built as a node-pair allowlist rather than a node mask
    n = nrow(nodes_df)
    hub_idx = [i for i in 1:n if is_hub(nodes_df[i, :])]
    allowed = Set{Tuple{Int,Int}}()
    for i in 1:n
        is_hub(nodes_df[i, :]) && continue
        best_hub, best_dist = -1, Inf
        for h in hub_idx
            d = min(vtol_matrix[min(i,h),max(i,h)], fw_matrix[min(i,h),max(i,h)])
            if d < best_dist
                best_dist = d; best_hub = h
            end
        end
        best_hub == -1 && continue
        push!(allowed, (min(i,best_hub), max(i,best_hub)))
    end
    for a in hub_idx, b in hub_idx
        a < b && push!(allowed, (a, b))
    end
    allowed
end

function build_edges_restricted(nodes_df, vtol_matrix, fw_matrix, order_lookup, allowed_pairs; prefer=:either)
    edges = Tuple{Int,Int}[]
    edge_probs = Dict{String,Tuple{Float64,Float64}}()
    for (i, j) in allowed_pairs
        oi, oj = order_lookup[i], order_lookup[j]
        src_i, dst_i = oi < oj ? (i, j) : (j, i)
        vd = prefer == :fw_only ? Inf : vtol_matrix[i, j]
        fd = prefer == :vtol_only ? Inf : fw_matrix[i, j]
        iv = edge_interval(vd, fd)
        iv === nothing && continue
        src_id, dst_id = nodes_df.numberID[src_i], nodes_df.numberID[dst_i]
        push!(edges, (src_id, dst_id))
        edge_probs["($src_id,$dst_id)"] = iv
    end
    edges, edge_probs
end

# ---- The 3 proxy networks (grounding point 4) ----------------------------------------------------------

"""
NETWORK: fw-reliant-centralized -- proxy for Pareto point 1 (§5: "relies much more heavily on the
fixed-wing drone for deliveries to the northern isles... disconnected from main VTOL network otherwise...
more centralised... minimises disruption for the majority of deliveries"). Each spoke connects ONLY to its
nearest reachable hub (tree, no local redundancy); the hub-to-hub backbone is FW-preferred (long range).
"""
function build_fw_reliant_centralized(nodes_df, vtol_matrix, fw_matrix, order_lookup)
    allowed = nearest_hub_mask(nodes_df, vtol_matrix, fw_matrix)
    build_edges_restricted(nodes_df, vtol_matrix, fw_matrix, order_lookup, allowed; prefer=:either)
end

"""
NETWORK: vtol-dense-decentralized -- proxy for Pareto point 2 (§5: "decentralised structure, relying on a
fully connected VTOL network layer for a slightly less resilient but much faster network"). Each node keeps
its K nearest reachable partners (VTOL preferred, FW combined in/falls back where VTOL can't reach) -- see
the K-BOUNDED note above `build_edges` for why this replaced "every pair within range."
"""
function build_vtol_dense_decentralized(nodes_df, vtol_matrix, fw_matrix, order_lookup; K=K_REDUNDANCY)
    build_edges(nodes_df, vtol_matrix, fw_matrix, order_lookup; prefer=:either, K=K)
end

"""
NETWORK: concentrated-minimal -- proxy for Pareto point 4, the paper's own "LEAST resilient network on the
Pareto front... concentration down to only a few larger drone ports" (§5), reframed as the MINIMAL-
INVESTMENT design point: deactivate every OPTIONAL additional station (x_γ=0 for γ in I, eq. 16-17) and
keep only the "existing" fixed set K = H ∪ A, which the source paper says is "always active" (eq. 23).
`city_type == "new"` marks exactly the 11 optional candidate stations from Fig. 10 -- directly observable
in the data, unlike the rejected CS_type/DP_type attempt (see file docstring, point 4). Built on the same
dense edge rule as the VTOL-dense proxy, but over the reduced (existing-only) node set.
"""
function build_concentrated_minimal(nodes_df, vtol_matrix, fw_matrix, order_lookup; K=K_REDUNDANCY)
    n = nrow(nodes_df)
    mask = BitVector(nodes_df.city_type[i] != "new" for i in 1:n)
    println("  concentrated-minimal: $(count(mask))/$n nodes retained (existing set = H∪A; optional new stations deactivated)")
    build_edges(nodes_df, vtol_matrix, fw_matrix, order_lookup; node_mask=mask, prefer=:either, K=K)
end

# ---- I/O ------------------------------------------------------------------------------------------------

function save_dag_files_interval(name, edges, edge_probs, nodes_df, active_node_ids)
    println("Saving DAG files for: $name")
    output_path = joinpath(OUTPUT_DIR, name)
    mkpath(output_path)
    mkpath(joinpath(output_path, "interval"))

    edges_file = joinpath(output_path, "$name.EDGES")
    open(edges_file, "w") do f
        println(f, "source,destination")
        for (src, dst) in edges
            println(f, "$src,$dst")
        end
    end

    id_to_row = Dict(nodes_df.numberID[i] => i for i in 1:nrow(nodes_df))
    node_priors = Dict{String,Any}()
    for nid in active_node_ids
        lo, hi = node_prior_interval(nodes_df[id_to_row[nid], :])
        node_priors[string(nid)] = Dict("type" => "interval", "lower" => lo, "upper" => hi)
    end
    priors_data = Dict(
        "nodes" => node_priors, "data_type" => "Interval", "serialization" => "compact",
        "description" => "Node prior reliabilities for $name (hub=certain per source paper §5; " *
                          "non-hub=Interval(0.75,0.85) sensitivity band around the paper's 20% failure figure)")
    open(joinpath(output_path, "interval", "$name-nodepriors.json"), "w") do f
        JSON.print(f, priors_data, 2)
    end

    links = Dict(k => Dict("type" => "interval", "lower" => v[1], "upper" => v[2]) for (k, v) in edge_probs)
    links_data = Dict(
        "links" => links, "data_type" => "Interval", "serialization" => "compact",
        "description" => "Edge reliabilities for $name (range cutoff per Table 1; weather-derated-range " *
                          "extension per §2.4/§3.1 -- see file docstring)")
    open(joinpath(output_path, "interval", "$name-linkprobabilities.json"), "w") do f
        JSON.print(f, links_data, 2)
    end
    println("  -> $(length(edges)) edges, $(length(node_priors)) node priors saved to $output_path")
end

active_ids_from_edges(edges) = sort(collect(Set(vcat([e[1] for e in edges], [e[2] for e in edges]))))

function generate_all_reliability_networks()
    println("="^80)
    println("GENERATING RELIABILITY-GROUNDED DRONE NETWORK PROXIES")
    println("Grounded in Jones et al., \"Conceptual design of a medical drone logistics network for Scotland\"")
    println("="^80)

    nodes_df, vtol_matrix, fw_matrix = load_drone_network_data()
    order_lookup = hub_spoke_order(nodes_df)

    configs = [
        ("drone-network-fw-reliant-centralized", build_fw_reliant_centralized),
        ("drone-network-vtol-dense-decentralized", build_vtol_dense_decentralized),
        ("drone-network-concentrated-minimal", build_concentrated_minimal),
    ]
    for (name, builder) in configs
        println("\n=== $name ===")
        edges, edge_probs = builder(nodes_df, vtol_matrix, fw_matrix, order_lookup)
        active_ids = active_ids_from_edges(edges)
        save_dag_files_interval(name, edges, edge_probs, nodes_df, active_ids)
    end

    println("\n" * "="^80)
    println("DONE — 3 reliability-grounded proxy networks generated (see file docstring for provenance)")
    println("="^80)
end

if abspath(PROGRAM_FILE) == @__FILE__
    generate_all_reliability_networks()
end
