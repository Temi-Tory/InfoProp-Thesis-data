# Drone reliability findings fresh verification (watchlist #15, 2026-08-17): re-derives the three
# official networks' interval beliefs from their on-disk interval inputs and checks tab:drone —
# mean band (0.089/0.094/0.093), max band (0.100/0.161/0.161), worst facility ([0.750,0.850] /
# [0.562,0.722] / [0.562,0.722]) — plus per-node diff against the historical belief CSVs.
# One network per run is unnecessary (interval props are seconds and memory-light at these sizes).
# USAGE: julia -t 1 "validation/fresh_20260816/drone_beliefs_check.jl"  (redirect stdout)
const REPO = raw"c:\Users\ohian\OneDrive - University of Strathclyde\Documents\Programmming Files\Julia Files\InformationPropagation\Info_Prop_Framework_Project"
using Pkg; Pkg.activate(REPO)
include(joinpath(REPO,"InfoPropFrmwrk","src","Algorithms","InfoPropFramework.jl")); using .InfoPropFramework
using Printf, Dates

const DATA = joinpath(REPO, "InfoPropFrmwrk", "Publications", "My work", "RESS_response", "data")
nets = ["drone-network-fw-reliant-centralized", "drone-network-vtol-dense-decentralized", "drone-network-concentrated-minimal"]

function run_net(name)
    base = joinpath(REPO, "dag_ntwrk_files", name)
    edges, outgoing, incoming, src_vec = read_graph_to_dict(joinpath(base, "$name.EDGES"))
    np = read_node_priors_from_json(joinpath(base, "interval", "$name-nodepriors.json"))
    lp = read_edge_probabilities_from_json(joinpath(base, "interval", "$name-linkprobabilities.json"))
    sources = Set(src_vec)
    itersets, anc, desc = find_iteration_sets(edges, outgoing, incoming)
    fk, jn = identify_fork_and_join_nodes(outgoing, incoming)
    roots, uniq = new_identify(edges, np, lp, sources, fk, jn, anc, desc, itersets)
    local bel
    t = @elapsed (bel = update_beliefs_iterative(edges, itersets, outgoing, incoming, sources, np, lp, desc, anc, roots, jn, fk, uniq, Dict{CacheKey,DiamondCacheEntry{Interval}}()))
    nonsrc = [n for n in keys(bel) if !(n in sources)]
    bands = Dict(n => bel[n].upper - bel[n].lower for n in nonsrc)
    meanb = sum(values(bands)) / length(bands); maxb = maximum(values(bands))
    worst = argmin(Dict(n => bel[n].lower for n in nonsrc))
    # per-node diff vs historical CSV (name,lower,upper rows — parse defensively)
    hist = Dict{Int,Tuple{Float64,Float64}}()
    csvp = joinpath(DATA, "beliefs_$name.csv")
    maxdiff = -1.0
    if isfile(csvp)
        for l in eachline(csvp)
            p = split(strip(l), ',')
            length(p) >= 3 || continue
            id = tryparse(Int, p[1]); id === nothing && continue
            lo = tryparse(Float64, p[2]); hi = tryparse(Float64, p[3])
            (lo === nothing || hi === nothing) && continue
            hist[id] = (lo, hi)
        end
        common = [n for n in keys(hist) if haskey(bel, n)]
        isempty(common) || (maxdiff = maximum(max(abs(bel[n].lower-hist[n][1]), abs(bel[n].upper-hist[n][2])) for n in common))
    end
    @printf("%s: t=%.1fs nodes=%d mean_band=%.3f max_band=%.3f worst_node=%d [%.3f,%.3f] hist_maxdiff=%s\n",
            name, t, length(bel), meanb, maxb, worst, bel[worst].lower, bel[worst].upper,
            maxdiff < 0 ? "n/a" : @sprintf("%.2e", maxdiff)); flush(stdout)
end

run_net(nets[1])  # doubles as JIT warmup; fw-reliant is the small one — rerun after for clean timing
println("# ^ warmup pass; verified rows follow")
for n in nets; run_net(n); end
println("[$(now())] # drone beliefs check done")
