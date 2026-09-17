# Rich-diamond DAG generator for the IPA-vs-BDD validation harness.
# Families deliberately stress the diamond machinery:
#   nested   - diamonds inside diamond branches (recursive completeness / exluded_nodes)
#   overlap  - many joins sharing fork ancestors (shared conditioning nodes)
#   asym     - parent-to-parent fork (asymmetric diamonds, Pipeline.jl:106-124)
#   layered  - general layered random DAG (emergent diamonds)
#   grid     - directed grid, classic reliability shape (many overlapping paths -> big BDDs)
# Every graph is self-verified: we run identify_and_group_diamonds and label it by the
# ACTUAL diamond count / conditioning sizes it produces. Nothing enters the corpus on faith.

using Random

struct Graph
    n::Int
    edges::Vector{Tuple{Int,Int}}
    sources::Vector{Int}
    family::String
end

# ------------------------------------------------------------------ generators
# Recursively expand edge (a,b) into a diamond; nesting `depth` gives diamonds-in-diamonds.
function _expand!(edges, a, b, depth, nextid)
    if depth <= 0
        push!(edges, (a, b)); return nextid
    end
    m1 = nextid[]; nextid[] += 1
    m2 = nextid[]; nextid[] += 1
    nextid = nextid
    _expand!(edges, a, m1, depth-1, nextid)
    _expand!(edges, m1, b, 0,        nextid)
    _expand!(edges, a, m2, 0,        nextid)
    _expand!(edges, m2, b, depth-1,  nextid)
    return nextid
end

function gen_nested(depth::Int)
    edges = Tuple{Int,Int}[]
    nextid = Ref(3)                      # 1 = source, 2 = sink
    _expand!(edges, 1, 2, depth, nextid)
    Graph(nextid[]-1, unique(edges), [1], "nested")
end

# One fork feeding many mids; k joins each combine a different pair of mids -> overlapping
# diamonds that all share the same fork ancestor (shared conditioning node).
function gen_overlap(k::Int, nmid::Int)
    @assert nmid >= 2
    edges = Tuple{Int,Int}[]
    fork = 1
    mids = collect(2:(1+nmid))
    for m in mids; push!(edges, (fork, m)); end
    id = 1 + nmid
    joins = Int[]
    for j in 1:k
        id += 1; push!(joins, id)
        a = mids[((j-1) % nmid) + 1]
        b = mids[(j % nmid) + 1]
        push!(edges, (a, id)); push!(edges, (b, id))
    end
    id += 1; sink = id                    # funnel all joins to one sink
    for j in joins; push!(edges, (j, sink)); end
    Graph(id, unique(edges), [fork], "overlap")
end

# Asymmetric diamond: fork f, siblings a,b, plus a->b (a is both sibling and ancestor of b).
function gen_asym(chain::Int)
    edges = Tuple{Int,Int}[]
    id = 0; prev = (id += 1; id)          # source
    src = prev
    for _ in 1:chain
        f = prev
        a = (id += 1; id); b = (id += 1; id); j = (id += 1; id)
        push!(edges, (f,a), (f,b), (a,b), (a,j), (b,j))
        prev = j
    end
    Graph(id, unique(edges), [src], "asym")
end

# k INDEPENDENT forks (separate sources), each splitting into a pair, all pairs reconverging
# at one join -> the join's diamond has |C| = k conditioning nodes (2^k states). This is the
# structure that makes IPA's local cost grow, mirroring power-network's |C|=3 joins.
function gen_multisource(k::Int; depth::Int=1)
    @assert k >= 2
    edges = Tuple{Int,Int}[]
    id = 0
    forks = Int[]; pair_nodes = Int[]
    for _ in 1:k
        f = (id += 1; id); push!(forks, f)
        a = (id += 1; id); b = (id += 1; id)
        push!(edges, (f,a), (f,b)); push!(pair_nodes, a, b)
    end
    join = (id += 1; id)
    for p in pair_nodes; push!(edges, (p, join)); end
    # optionally stack another multisource diamond above, feeding the forks (nesting)
    if depth > 1
        top = (id += 1; id)
        for f in forks; push!(edges, (top, f)); end
        # give `top` a sibling path so `top` itself sits in a diamond
        sib = (id += 1; id); newjoin = (id += 1; id)
        push!(edges, (top, sib), (join, newjoin), (sib, newjoin))
    end
    srcs = Set(n for n in 1:id if all(e -> e[2] != n, edges))
    Graph(id, unique(edges), sort(collect(srcs)), "multisrc")
end

_psample(rng, v, k) = shuffle(rng, collect(v))[1:min(k, length(v))]

function gen_layered(rng::AbstractRNG; layers::Int, width::Int)
    edges = Tuple{Int,Int}[]
    node = 1
    layer = [[1]]
    for _ in 1:layers
        w = rand(rng, max(2,width-1):width)
        cur = Int[]
        for _ in 1:w; node += 1; push!(cur, node); end
        prev = layer[end]
        for c in cur
            for p in _psample(rng, prev, rand(rng, 1:min(2,length(prev))))
                push!(edges, (p, c))
            end
        end
        # guarantee at least one fork per layer (a prev node -> 2 cur) to seed diamonds
        if length(cur) >= 2 && !isempty(prev)
            f = rand(rng, prev)
            push!(edges, (f, cur[1])); push!(edges, (f, cur[2]))
        end
        push!(layer, cur)
    end
    node += 1; sink = node
    for p in layer[end]; push!(edges, (p, sink)); end
    Graph(node, unique(edges), [1], "layered")
end

function gen_grid(r::Int, c::Int)
    idx(i,j) = (i-1)*c + j
    edges = Tuple{Int,Int}[]
    for i in 1:r, j in 1:c
        j < c && push!(edges, (idx(i,j), idx(i,j+1)))
        i < r && push!(edges, (idx(i,j), idx(i+1,j)))
    end
    Graph(r*c, unique(edges), [idx(1,1)], "grid")
end

# Random DAG (nodes in topological id order). p tunes extra density -> more forks/joins/diamonds.
# Guarantees a connected DAG: every non-source gets an incoming edge, every non-sink an outgoing.
function gen_random_dag(rng::AbstractRNG; n::Int, p::Float64)
    eset = Set{Tuple{Int,Int}}()
    for i in 1:n-1, j in i+1:n
        rand(rng) < p && push!(eset, (i,j))
    end
    for j in 2:n                                   # ensure incoming
        if !any(e -> e[2] == j, eset); push!(eset, (rand(rng, 1:j-1), j)); end
    end
    for i in 1:n-1                                  # ensure outgoing
        if !any(e -> e[1] == i, eset); push!(eset, (i, rand(rng, i+1:n))); end
    end
    Graph(n, sort(collect(eset)), [1], "random")
end

_kahn(n, edges) = begin
    indeg = Dict(v => 0 for v in 1:n)
    for (_,v) in edges; indeg[v] += 1; end
    q = sort([v for v in 1:n if indeg[v] == 0]); order = Int[]
    outs = Dict(v => Int[] for v in 1:n); for (u,v) in edges; push!(outs[u], v); end
    while !isempty(q)
        u = popfirst!(q); push!(order, u)
        for v in outs[u]; indeg[v] -= 1; indeg[v] == 0 && push!(q, v); end
    end
    order
end

# Randomly mutate a graph: add forward edges (new forks/joins/diamonds) + delete a few, staying acyclic.
function gen_mutate(g::Graph, rng::AbstractRNG; adds::Int, dels::Int)
    order = _kahn(g.n, g.edges)
    pos = Dict(v => k for (k,v) in enumerate(order))
    eset = Set(g.edges)
    for _ in 1:adds
        for _try in 1:20
            u = rand(rng, order); v = rand(rng, order)
            if pos[u] < pos[v] && (u,v) ∉ eset; push!(eset, (u,v)); break; end
        end
    end
    dl = collect(eset)
    for _ in 1:min(dels, length(dl))
        delete!(eset, rand(rng, collect(eset)))
    end
    Graph(g.n, sort(collect(eset)), [order[1]], "mutant")
end

# ------------------------------------------------------------------ scaling families (bounded maxC, growing global width)
scaling_grids(Ns)        = [("grid_$(N)x$N", gen_grid(N,N)) for N in Ns]
# BOUNDED-maxC probe: fixed height H (bounded local width) but growing width W.
# Tests whether IPA Σ2^|C| AND BDD nodes both stay ~linear when the graph width is bounded.
function gen_fixed_height(H::Int, W::Int)
    g = gen_grid(H, W); Graph(g.n, g.edges, g.sources, "fixedH$H")
end
scaling_fixedheight(H, Ws) = [("fixedH$(H)_w$W", gen_fixed_height(H,W)) for W in Ws]
scaling_multisrc(Ks)     = [("multisrc_k$K", gen_multisource(K)) for K in Ks]
function scaling_layered(; layers, widths, seeds)
    out = Tuple{String,Graph}[]
    for L in layers, W in widths, s in seeds
        push!(out, ("layered_L$(L)W$(W)_s$s", gen_layered(MersenneTwister(s); layers=L, width=W)))
    end
    out
end
function scaling_random(; ns, ps, seeds)
    out = Tuple{String,Graph}[]
    for n in ns, p in ps, s in seeds
        push!(out, ("random_n$(n)_p$(replace(string(p),"."=>""))_s$s",
                    gen_random_dag(MersenneTwister(s); n=n, p=p)))
    end
    out
end
function scaling_mutants(base_name, base::Graph; seeds, adds, dels)
    [("mutant_$(base_name)_s$s", gen_mutate(base, MersenneTwister(s); adds=adds, dels=dels)) for s in seeds]
end

# ------------------------------------------------------------------ framework adapters + self-verify
function to_framework(g::Graph)
    outgoing = Dict{Int,Set{Int}}(); incoming = Dict{Int,Set{Int}}()
    for (u,v) in g.edges
        push!(get!(outgoing, u, Set{Int}()), v)
        push!(get!(incoming, v, Set{Int}()), u)
    end
    sources = Set(n for n in 1:g.n if !haskey(incoming, n) || isempty(incoming[n]))
    g.edges, outgoing, incoming, sources
end

# Requires `using .InfoPropFramework` in scope. Returns diamond stats for a graph.
function verify_graph(g::Graph)
    edgelist, outgoing, incoming, sources = to_framework(g)
    fork_nodes, join_nodes = identify_fork_and_join_nodes(outgoing, incoming)
    iteration_sets, ancestors, descendants = find_iteration_sets(edgelist, outgoing, incoming)
    npr = Dict(n => 0.9 for n in 1:g.n)          # values irrelevant to structure (all in (0,1))
    roots = identify_and_group_diamonds(join_nodes, incoming, ancestors, descendants,
                                        sources, fork_nodes, edgelist, npr, iteration_sets)
    uniq = build_unique_diamond_storage_depth_first_parallel(roots, npr, ancestors, descendants, iteration_sets)
    cond = sort([length(d.diamond.conditioning_nodes) for (_,d) in roots], rev=true)
    sum2 = sum(2^length(cd.diamond.conditioning_nodes) for (_,cd) in uniq; init=0)
    (; n=g.n, m=length(g.edges), sources=length(sources),
       forks=length(fork_nodes), joins=length(join_nodes),
       root_diamonds=length(roots), unique_diamonds=length(uniq),
       cond_sizes=cond, sum_2C=sum2)
end

# ------------------------------------------------------------------ corpus
function build_corpus(; seeds=1:3)
    corpus = Tuple{String,Graph}[]
    for d in 2:3;            push!(corpus, ("nested_d$d",  gen_nested(d)));        end
    for k in (3,5,8);        push!(corpus, ("overlap_k$k", gen_overlap(k, 4)));    end
    for k in (2,3,4,5);      push!(corpus, ("multisrc_k$k", gen_multisource(k)));  end
    for k in (3,4);          push!(corpus, ("multisrc_k$(k)_nest", gen_multisource(k; depth=2))); end
    for c in (2,3);          push!(corpus, ("asym_c$c",    gen_asym(c)));          end
    for (r,c) in ((3,3),(4,4),(5,5)); push!(corpus, ("grid_$(r)x$c", gen_grid(r,c))); end
    for s in seeds, (L,W) in ((4,3),(6,4))
        push!(corpus, ("layered_L$(L)W$(W)_s$s", gen_layered(MersenneTwister(s); layers=L, width=W)))
    end
    corpus
end
