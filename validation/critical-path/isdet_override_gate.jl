# Gate for the is_det_override keyword added to new_identify (2026-08-17).
# 1. Default path (no override) vs an explicit replica of the default predicate passed AS an
#    override must produce identical diamonds and identical belief values, on priors that
#    exercise both is_det branches (a certain source and a dead node).
# 2. Interval zero-width override (the CPM instantiation) must run and must exclude the
#    degenerate fork from every conditioning set.
# Run AFTER this: validation/fresh_20260816/grid_benchmark_check.jl (belief exactness gate).

const REPO = raw"c:\Users\ohian\OneDrive - University of Strathclyde\Documents\Programmming Files\Julia Files\InformationPropagation\Info_Prop_Framework_Project"
using Pkg; Pkg.activate(REPO)
include(joinpath(REPO,"InfoPropFrmwrk","src","Algorithms","InfoPropFramework.jl")); using .InfoPropFramework

function build(edges)
    nodes = sort(collect(union(Set(u for (u,_) in edges), Set(v for (_,v) in edges))))
    sources = Set(n for n in nodes if !any(e->e[2]==n, edges))
    outgoing = Dict{Int64,Set{Int64}}(); incoming = Dict{Int64,Set{Int64}}()
    for (u,v) in edges; push!(get!(outgoing,u,Set{Int64}()), v); push!(get!(incoming,v,Set{Int64}()), u); end
    itersets, anc, desc = find_iteration_sets(edges, outgoing, incoming)
    fk, jn = identify_fork_and_join_nodes(outgoing, incoming)
    (nodes, sources, outgoing, incoming, itersets, anc, desc, fk, jn)
end

diamond_signature(roots, uniq) = (
    sort(collect(keys(uniq))),
    sort([(j, sort(collect(dan.diamond.conditioning_nodes)), sort(dan.diamond.edgelist))
          for (j, vec) in roots for dan in vec])
)

fails = String[]

for (name, edges, certain_src, dead) in (
        ("chapterA", [(1,2),(1,3),(2,8),(3,4),(3,5),(4,6),(5,6),(6,7),(7,8)], 1, 7),
        ("karl-ish", [(1,2),(1,3),(2,4),(3,4),(2,5),(4,6),(5,6),(3,6),(6,7),(5,7)], 1, nothing))
    nodes, sources, outg, incg, its, anc, desc, fk, jn = build(edges)
    np = Dict{Int64,Float64}(n=>0.9 for n in nodes)
    np[certain_src] = 1.0
    dead !== nothing && (np[dead] = 0.0)
    lp = Dict{Tuple{Int64,Int64},Float64}(e=>0.9 for e in edges)

    r1, u1 = new_identify(edges, np, lp, sources, fk, jn, anc, desc, its)
    replica = n -> begin
        v = get(np, n, nothing)
        v === nothing ? false : (v == 0.0 || (v == 1.0 && n in sources))
    end
    r2, u2 = new_identify(edges, np, lp, sources, fk, jn, anc, desc, its; is_det_override=replica)

    sig1, sig2 = diamond_signature(r1, u1), diamond_signature(r2, u2)
    sig1 == sig2 || push!(fails, "$name: default vs replica-override diamond signatures differ")

    b1 = update_beliefs_iterative(edges, its, outg, incg, sources, np, lp, desc, anc, r1, jn, fk, u1, Dict{CacheKey,DiamondCacheEntry{Float64}}())
    b2 = update_beliefs_iterative(edges, its, outg, incg, sources, np, lp, desc, anc, r2, jn, fk, u2, Dict{CacheKey,DiamondCacheEntry{Float64}}())
    all(b1[n] === b2[n] for n in keys(b1)) || push!(fails, "$name: belief values differ default vs replica")
    println("$name: default-vs-replica identical diamonds=$(sig1==sig2) beliefs_identical=$(all(b1[n]===b2[n] for n in keys(b1))) uniq=$(length(u1))")
end

# Interval zero-width override: degenerate inner fork must leave every conditioning set.
let edges = [(1,2),(1,3),(2,8),(3,4),(3,5),(4,6),(5,6),(6,7),(7,8)]
    nodes, sources, outg, incg, its, anc, desc, fk, jn = build(edges)
    np = Dict{Int64,Interval}(n=>Interval(0.85,0.95) for n in nodes)
    np[3] = Interval(0.5,0.5)
    lp = Dict{Tuple{Int64,Int64},Interval}(e=>Interval(0.9,0.9) for e in edges)
    zero_width = n -> begin
        v = get(np, n, nothing)
        v === nothing ? false : v.lower == v.upper
    end
    r3, u3 = new_identify(edges, np, lp, sources, fk, jn, anc, desc, its; is_det_override=zero_width)
    conds = Set{Int64}()
    for (_, cd) in u3; union!(conds, cd.diamond.conditioning_nodes); end
    (3 in conds) && push!(fails, "interval smoke: degenerate fork 3 appeared in a conditioning set")
    println("interval zero-width smoke: uniq=$(length(u3)) conditioning_nodes=$(sort(collect(conds))) fork3_excluded=$(!(3 in conds))")
end

if isempty(fails)
    println("ISDET_OVERRIDE_GATE: ALL PASS")
else
    println("ISDET_OVERRIDE_GATE: FAILURES"); foreach(f->println("  ",f), fails)
    exit(1)
end
