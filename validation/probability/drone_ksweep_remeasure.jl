# Section 3 item 2 of the probability data-pack requirements: post-is_det-fix remeasurement of
# drone diamond identification stats (maxcond, unique-diamond count) at K=10, K=12, K=16
# (concentrated-minimal family) plus vtol-dense-decentralized and mlgw-gas-network, to compare
# against the pre-fix numbers already on record:
#   g2_ksweep.log (validation/fresh_20260816/):
#     K=8  V=230 E=1146 maxcond=9  uniq=284
#     K=10 V=230 E=1359 maxcond=14 uniq=465
#     K=12 V=230 E=1510 maxcond=15 uniq=691
#   CORPUS_INVENTORY.md (this pack, notes/):
#     concentrated-minimal (K=16, official) V~233 E~1648 maxcond=16-17
#     vtol-dense-decentralized              V=242 E=1753 maxcond=17
#
# NewIdentify.jl's own in-code note (Internal/NewIdentify.jl:81-89) flags EXACTLY this network as
# the one where the is_det bug measurably moved diamond count/maxcond (687/maxcond=10 buggy vs
# 284/maxcond=9 fixed, on K=8, pbox priors) while never changing the actual belief values
# (exactness-preserving by construction). g2_ksweep.log's K=8 line (284/maxcond=9) already matches
# the FIXED-behaviour number, so those logs were already taken post-fix (or on a config the bug
# never triggered on) -- this run exists to confirm that directly for K=10/12/16, not to re-derive
# whether the fix mattered at all (already answered in-code).
#
# NOTE: reimplements drone_network_to_dag_reliability.jl's node-loading + edge-building logic in
# plain Julia (no CSV.jl/DataFrames.jl) rather than `include`ing that file directly: `Pkg.add`ing
# CSV into the InfoPropFrmwrk environment surfaced a PRE-EXISTING, unrelated version conflict
# (InformationPropagationAnalysis pinned to 0.1.0 vs InfoPropFrmwrk requiring 0.2.x) -- a real
# environment issue, but not one to fix blindly mid-task, and not one this script needs to touch.
# Pkg.add was aborted cleanly (confirmed via `git status` on Project.toml/Manifest.toml -- no
# changes were written), so the environment is exactly as it was. The logic below is a direct,
# careful port of build_edges/build_concentrated_minimal/build_vtol_dense_decentralized from
# drone_network_to_dag_reliability.jl -- same distance cutoffs, same K-nearest rule, same interval
# combination -- just over plain Vectors instead of a DataFrame.
const REPO = raw"C:\Development\Info_Prop_Framework_Project\Info_Prop_Framework_Project"
using Pkg; Pkg.activate(joinpath(REPO, "InfoPropFrmwrk"))
include(joinpath(REPO, "InfoPropFrmwrk", "src", "Algorithms", "InfoPropFramework.jl")); using .InfoPropFramework
using Printf, Dates

const NODES_FILE  = joinpath(REPO, "csvfiles", "drone_info", "nodes.csv")
const DRONE1_FILE = joinpath(REPO, "csvfiles", "drone_info", "drone1.csv")   # VTOL, R=70km
const DRONE2_FILE = joinpath(REPO, "csvfiles", "drone_info", "drone2.csv")   # fixed-wing, R=700km
const R_VTOL = 70_000.0
const R_FW   = 700_000.0
const WEATHER_DERATE = 0.9
const HUB_PRIOR = (1.0, 1.0)
const NONHUB_PRIOR = (0.75, 0.85)

function parse_matrix(path)
    lines = readlines(path)
    n = length(lines) - 1
    M = Matrix{Float64}(undef, n, n)
    for i in 1:n
        parts = split(lines[i+1], ',')
        for j in 1:n
            s = parts[j]
            M[i,j] = s == "Inf" ? Inf : parse(Float64, s)
        end
    end
    return M
end

function load_nodes()
    lines = readlines(NODES_FILE)
    header = split(lines[1], ',')
    col = Dict(name => i for (i,name) in enumerate(header))
    n = length(lines) - 1
    numberID = Vector{Int}(undef, n)
    city_type = Vector{String}(undef, n)
    srtype = Vector{String}(undef, n)
    for i in 1:n
        parts = split(lines[i+1], ',')
        numberID[i] = parse(Int, parts[col["numberID"]])
        city_type[i] = String(parts[col["city_type"]])
        srtype[i] = String(parts[col["source_receiver_type"]])
    end
    return numberID, city_type, srtype
end

is_hub(srtype_i) = srtype_i == "SOURCE-RECEIVER"
node_prior_interval(srtype_i) = is_hub(srtype_i) ? HUB_PRIOR : NONHUB_PRIOR

function type_edge_interval(dist, R)
    (dist == Inf || isnan(dist) || dist > R) && return nothing
    dist <= WEATHER_DERATE * R && return (1.0, 1.0)
    return (0.0, 1.0)
end
combine_or(a, b) = (1.0 - (1.0 - a[1]) * (1.0 - b[1]), 1.0 - (1.0 - a[2]) * (1.0 - b[2]))
function edge_interval(vd, fd)
    iv = type_edge_interval(vd, R_VTOL)
    ifw = type_edge_interval(fd, R_FW)
    iv === nothing && return ifw
    ifw === nothing && return iv
    return combine_or(iv, ifw)
end

function hub_spoke_order(numberID, srtype)
    n = length(numberID)
    keys_ = [(is_hub(srtype[i]) ? 0 : 1, numberID[i]) for i in 1:n]
    order = sortperm(keys_)
    Dict(order[i] => i for i in 1:n)
end

mission_relevant_pair(srtype, i, j) = !(srtype[i] == "RECEIVER" && srtype[j] == "RECEIVER")

# direct port of build_edges (prefer=:either always, matching how concentrated-minimal and
# vtol-dense-decentralized are both called in generate_all_reliability_networks)
function build_edges(numberID, srtype, vtol_matrix, fw_matrix, order_lookup; node_mask=nothing, K=3)
    n = length(numberID)
    mask = node_mask === nothing ? trues(n) : node_mask
    edge_probs = Dict{Tuple{Int,Int},Tuple{Float64,Float64}}()
    for i in 1:n
        mask[i] || continue
        candidates = Tuple{Float64,Int}[]
        for j in 1:n
            (i == j || !mask[j]) && continue
            mission_relevant_pair(srtype, i, j) || continue
            eff = min(vtol_matrix[i,j], fw_matrix[i,j])
            eff == Inf && continue
            push!(candidates, (eff, j))
        end
        sort!(candidates)
        for (_, j) in candidates[1:min(K, length(candidates))]
            iv = edge_interval(vtol_matrix[i,j], fw_matrix[i,j])
            iv === nothing && continue
            oi, oj = order_lookup[i], order_lookup[j]
            src_i, dst_i = oi < oj ? (i, j) : (j, i)
            src_id, dst_id = numberID[src_i], numberID[dst_i]
            edge_probs[(src_id, dst_id)] = iv
        end
    end
    collect(keys(edge_probs)), edge_probs
end

function build_concentrated_minimal(numberID, city_type, srtype, vtol_matrix, fw_matrix, order_lookup; K)
    n = length(numberID)
    mask = BitVector(city_type[i] != "new" for i in 1:n)
    println("  concentrated-minimal K=$K: $(count(mask))/$n nodes retained (existing set = H∪A; optional new stations deactivated)")
    build_edges(numberID, srtype, vtol_matrix, fw_matrix, order_lookup; node_mask=mask, K=K)
end

function build_vtol_dense_decentralized(numberID, srtype, vtol_matrix, fw_matrix, order_lookup; K)
    build_edges(numberID, srtype, vtol_matrix, fw_matrix, order_lookup; K=K)
end

function build_indices(edgelist::Vector{Tuple{Int64,Int64}})
    outgoing = Dict{Int64,Set{Int64}}()
    incoming = Dict{Int64,Set{Int64}}()
    nodes = Set{Int64}()
    for (u,v) in edgelist
        push!(nodes, u); push!(nodes, v)
        push!(get!(outgoing, u, Set{Int64}()), v)
        push!(get!(incoming, v, Set{Int64}()), u)
    end
    for n in nodes
        haskey(outgoing, n) || (outgoing[n] = Set{Int64}())
        haskey(incoming, n) || (incoming[n] = Set{Int64}())
    end
    return nodes, outgoing, incoming
end

function measure(name::String, edges::Vector{Tuple{Int,Int}}, edge_probs, numberID, srtype)
    id_row = Dict(numberID[i] => i for i in eachindex(numberID))
    edgelist = [(Int64(u), Int64(v)) for (u,v) in edges]
    nodes, outgoing, incoming = build_indices(edgelist)
    sources = Set(n for n in nodes if isempty(incoming[n]))

    node_priors = Dict{Int64,Float64}()
    for n in nodes
        lo, hi = node_prior_interval(srtype[id_row[n]])
        node_priors[n] = (lo + hi) / 2
    end
    link_probability = Dict{Tuple{Int64,Int64},Float64}()
    for e in edgelist
        lo, hi = edge_probs[e]
        link_probability[e] = (lo + hi) / 2
    end

    fork_nodes, join_nodes = identify_fork_and_join_nodes(outgoing, incoming)
    iteration_sets, ancestors, descendants = find_iteration_sets(edgelist, outgoing, incoming)

    t0 = time()
    root_diamonds, unique_diamonds = new_identify(edgelist, node_priors, link_probability, sources, fork_nodes, join_nodes, ancestors, descendants, iteration_sets)
    t_identify = time() - t0

    t0 = time()
    beliefs = update_beliefs_iterative(edgelist, iteration_sets, outgoing, incoming, sources, node_priors, link_probability, descendants, ancestors, root_diamonds, join_nodes, fork_nodes, unique_diamonds)
    t_propagate = time() - t0

    uniq = length(unique_diamonds)
    maxcond = uniq == 0 ? 0 : maximum(length(dc.diamond.conditioning_nodes) for dc in values(unique_diamonds))

    @printf("%-30s V=%-4d E=%-5d sources=%-2d maxcond=%-3d uniq=%-4d identify_s=%.3f propagate_s=%.3f\n",
            name, length(nodes), length(edgelist), length(sources), maxcond, uniq, t_identify, t_propagate)
    return (name=name, V=length(nodes), E=length(edgelist), maxcond=maxcond, uniq=uniq,
            identify_s=t_identify, propagate_s=t_propagate)
end

println("[$(now())] loading drone source data...")
numberID, city_type, srtype = load_nodes()
vtol_matrix = parse_matrix(DRONE1_FILE)
fw_matrix = parse_matrix(DRONE2_FILE)
order_lookup = hub_spoke_order(numberID, srtype)
println("  loaded $(length(numberID)) nodes, $(size(vtol_matrix)) distance matrices")
println()

results = NamedTuple[]

for K in (10, 12, 16)
    println("=== concentrated-minimal, K=$K ===")
    edges, edge_probs = build_concentrated_minimal(numberID, city_type, srtype, vtol_matrix, fw_matrix, order_lookup; K=K)
    push!(results, measure("concentrated-minimal-K$K", edges, edge_probs, numberID, srtype))
    println()
end

println("=== vtol-dense-decentralized (K=16, official) ===")
edges, edge_probs = build_vtol_dense_decentralized(numberID, srtype, vtol_matrix, fw_matrix, order_lookup; K=16)
push!(results, measure("vtol-dense-decentralized", edges, edge_probs, numberID, srtype))
println()

# mlgw-gas-network: real persisted file, not drone-generator output -- Float64 midpoint priors
# (0.9 everywhere, matching this corpus's own convention elsewhere) since it has no interval
# source data of its own in this pack.
mlgw_path = joinpath(REPO, "dag_ntwrk_files", "mlgw-gas-network", "mlgw-gas-network.EDGES")
if isfile(mlgw_path)
    println("=== mlgw-gas-network ===")
    mlgw_edgelist, mlgw_out, mlgw_in, mlgw_srcs = read_graph_to_dict(mlgw_path)
    mlgw_nodes = Set(vcat([e[1] for e in mlgw_edgelist], [e[2] for e in mlgw_edgelist]))
    mlgw_node_priors = Dict(n => 0.9 for n in mlgw_nodes)
    mlgw_link_probs = Dict(e => 0.9 for e in mlgw_edgelist)
    fork_nodes, join_nodes = identify_fork_and_join_nodes(mlgw_out, mlgw_in)
    iteration_sets, ancestors, descendants = find_iteration_sets(mlgw_edgelist, mlgw_out, mlgw_in)
    t0 = time()
    root_diamonds, unique_diamonds = new_identify(mlgw_edgelist, mlgw_node_priors, mlgw_link_probs, mlgw_srcs, fork_nodes, join_nodes, ancestors, descendants, iteration_sets)
    t_identify = time() - t0
    t0 = time()
    beliefs = update_beliefs_iterative(mlgw_edgelist, iteration_sets, mlgw_out, mlgw_in, mlgw_srcs, mlgw_node_priors, mlgw_link_probs, descendants, ancestors, root_diamonds, join_nodes, fork_nodes, unique_diamonds)
    t_propagate = time() - t0
    uniq = length(unique_diamonds)
    maxcond = uniq == 0 ? 0 : maximum(length(dc.diamond.conditioning_nodes) for dc in values(unique_diamonds))
    @printf("%-30s V=%-4d E=%-5d sources=%-2d maxcond=%-3d uniq=%-4d identify_s=%.3f propagate_s=%.3f\n",
            "mlgw-gas-network", length(mlgw_nodes), length(mlgw_edgelist), length(mlgw_srcs), maxcond, uniq, t_identify, t_propagate)
    push!(results, (name="mlgw-gas-network", V=length(mlgw_nodes), E=length(mlgw_edgelist), maxcond=maxcond, uniq=uniq,
                     identify_s=t_identify, propagate_s=t_propagate))
else
    println("=== mlgw-gas-network: SKIPPED, file not found at $mlgw_path ===")
end

println()
out_csv = joinpath(REPO, "validation", "probability", "drone_ksweep_remeasure_results.csv")
open(out_csv, "w") do io
    println(io, "name,V,E,maxcond,uniq,identify_s,propagate_s")
    for r in results
        @printf(io, "%s,%d,%d,%d,%d,%.3f,%.3f\n", r.name, r.V, r.E, r.maxcond, r.uniq, r.identify_s, r.propagate_s)
    end
end
println("[$(now())] wrote ", out_csv)
println("[$(now())] done")
