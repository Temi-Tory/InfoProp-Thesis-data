# Additional DAG families for broader reliability-comparison coverage. Each returns a Graph
# (n, edges, sources, name) compatible with make_problem. Sources are the no-incoming nodes.
# Requires graph_gen.jl (Graph type) in scope.

_sources(n, edges) = begin
    inc = Set{Int}(); for (_,v) in edges; push!(inc, v); end
    sort([v for v in 1:n if !(v in inc)])
end

# MULTI-SOURCE random DAG: topological order 1..n; the first `nsrc` nodes are sources (never receive an
# edge); every later node gets >=1 incoming; every non-sink gets >=1 outgoing.
function gen_multisource(rng::AbstractRNG; n::Int, p::Float64, nsrc::Int)
    eset = Set{Tuple{Int,Int}}()
    for i in 1:n-1, j in i+1:n
        j > nsrc && rand(rng) < p && push!(eset, (i,j))
    end
    for j in nsrc+1:n                                   # ensure incoming (from any earlier node)
        any(e -> e[2]==j, eset) || push!(eset, (rand(rng, 1:j-1), j))
    end
    for i in 1:n-1                                      # ensure outgoing to some later NON-source
        any(e -> e[1]==i, eset) || push!(eset, (i, rand(rng, max(i+1,nsrc+1):n)))
    end
    edges = sort(collect(eset))
    Graph(n, edges, _sources(n, edges), "multisource")
end

# GRID / lattice r×c, directed left->right with straight + down-diagonal edges (reconvergent).
# Column 1 = sources, so multi-source too. Renumber column-major so ids are 1..r*c in topo order.
function gen_grid(r::Int, c::Int)
    id(row,col) = (col-1)*r + row
    edges = Tuple{Int,Int}[]
    for col in 1:c-1, row in 1:r
        push!(edges, (id(row,col), id(row,col+1)))
        row < r && push!(edges, (id(row,col), id(row+1,col+1)))
    end
    n = r*c
    Graph(n, sort(edges), _sources(n, edges), "grid$(r)x$(c)")
end

# LAYERED / k-partite feed-forward: `layers` layers each of `width` nodes; each node connects to next-layer
# nodes with prob p (guaranteeing >=1 forward edge). Layer-1 = sources.
function gen_layered(rng::AbstractRNG; layers::Int, width::Int, p::Float64)
    id(l,i) = (l-1)*width + i
    edges = Tuple{Int,Int}[]
    for l in 1:layers-1, i in 1:width
        outs = [id(l+1,j) for j in 1:width if rand(rng) < p]
        isempty(outs) && push!(outs, id(l+1, rand(rng, 1:width)))
        for o in outs; push!(edges, (id(l,i), o)); end
    end
    n = layers*width
    Graph(n, sort(edges), _sources(n, edges), "layered$(layers)x$(width)")
end

# BRIDGE ladder: `k` Wheatstone-bridge cells in series (the classic NON-series-parallel benchmark).
# One cell over nodes a,b,c,d: a->b, a->c, b->c (the bridge), b->d, c->d. Cells share the join node.
function gen_bridge(k::Int)
    edges = Tuple{Int,Int}[]
    node = 1                     # start node
    for _ in 1:k
        a=node; b=node+1; c=node+2; d=node+3
        append!(edges, [(a,b),(a,c),(b,c),(b,d),(c,d)])   # bridge cell a..d, bridge edge b->c
        node = d                                          # next cell starts at d
    end
    n = node
    Graph(n, sort(edges), _sources(n, edges), "bridge$k")
end

# SERIES-PARALLEL: `blocks` parallel bundles (each a src -> [k mids] -> snk diamond) composed IN SERIES.
# This is a proper two-terminal series-parallel DAG (single source/sink), forward-numbered (no cycles).
function gen_series_parallel(rng::AbstractRNG; blocks::Int)
    edges = Tuple{Int,Int}[]; node = 1
    for _ in 1:blocks
        src = node; k = rand(rng, 2:3); mids = [src+i for i in 1:k]; snk = src+k+1
        for m in mids; push!(edges, (src, m)); push!(edges, (m, snk)); end
        node = snk                              # series: this block's sink is the next block's source
    end
    n = node
    Graph(n, sort(edges), _sources(n, edges), "seriesparallel")
end

# COMPLETE DAG on n nodes (all i<j edges): maximum density / treewidth stress.
function gen_complete(n::Int)
    edges = [(i,j) for i in 1:n-1 for j in i+1:n]
    Graph(n, edges, _sources(n, edges), "complete$n")
end
