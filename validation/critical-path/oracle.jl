# Independent CPM oracle: brute-force path enumeration. Shares NO code with the
# CriticalPathV2 kernels — adjacency, traversal, and every quantity are computed
# directly from path sets, so agreement with the kernels is evidence, not tautology.

module CPMOracle

export build_adjacency, count_paths_to_sinks, enumerate_paths, paths_to_target,
       oracle_path_mode, oracle_accumulation

function build_adjacency(edges::Vector{Tuple{Int64,Int64}})
    out = Dict{Int64,Vector{Int64}}()
    nodes = Set{Int64}()
    for (u, v) in edges
        push!(get!(out, u, Int64[]), v)
        push!(nodes, u); push!(nodes, v)
    end
    heads = Set{Int64}(v for (_, v) in edges)
    sources = sort!(collect(setdiff(nodes, heads)))
    sinks = sort!([n for n in nodes if !haskey(out, n)])
    return out, sort!(collect(nodes)), sources, sinks
end

# Total number of source->sink paths (memoised), to decide whether enumeration is affordable.
function count_paths_to_sinks(out, sources)
    memo = Dict{Int64,Float64}()
    function cnt(v)
        haskey(memo, v) && return memo[v]
        succs = get(out, v, Int64[])
        c = isempty(succs) ? 1.0 : sum(cnt(s) for s in succs)
        memo[v] = c
        return c
    end
    return sum(cnt(s) for s in sources)
end

function enumerate_paths(out, sources; cap::Int = 300_000)
    paths = Vector{Vector{Int64}}()
    for s in sources
        stack = [(s, Int64[s])]
        while !isempty(stack)
            (v, path) = pop!(stack)
            succs = get(out, v, Int64[])
            if isempty(succs)
                push!(paths, path)
                length(paths) > cap && return nothing
            else
                for w in succs
                    push!(stack, (w, vcat(path, w)))
                end
            end
        end
    end
    return paths
end

# All source->target paths (target may be interior).
function paths_to_target(out, sources, target; cap::Int = 300_000)
    paths = Vector{Vector{Int64}}()
    for s in sources
        stack = [(s, Int64[s])]
        while !isempty(stack)
            (v, path) = pop!(stack)
            if v == target
                push!(paths, path)
                length(paths) > cap && return nothing
                continue
            end
            for w in get(out, v, Int64[])
                push!(stack, (w, vcat(path, w)))
            end
        end
    end
    return paths
end

pathvalue_add(path, d, w, initial) =
    initial + sum(get(d, v, 0.0) for v in path) +
    (length(path) < 2 ? 0.0 : sum(get(w, (path[i], path[i+1]), 0.0) for i in 1:length(path)-1))

pathvalue_mul(path, d, w, initial) =
    initial * prod(get(d, v, 1.0) for v in path) *
    (length(path) < 2 ? 1.0 : prod(get(w, (path[i], path[i+1]), 1.0) for i in 1:length(path)-1))

"""
Path-mode ground truth. kind: :longest, :shortest, :scaling.
Returns (project_value, through, margin, critical).
"""
function oracle_path_mode(paths, d, w; kind::Symbol, initial::Float64, atol::Float64 = 1e-9)
    mul = kind == :scaling
    vals = [mul ? pathvalue_mul(p, d, w, initial) : pathvalue_add(p, d, w, initial) for p in paths]
    P = kind == :shortest ? minimum(vals) : maximum(vals)

    through = Dict{Int64,Float64}()
    for (p, v) in zip(paths, vals)
        for n in p
            if !haskey(through, n)
                through[n] = v
            else
                through[n] = kind == :shortest ? min(through[n], v) : max(through[n], v)
            end
        end
    end

    margin = Dict{Int64,Float64}()
    for (n, t) in through
        margin[n] = kind == :longest ? P - t :
                    kind == :shortest ? t - P :
                    P / t - 1.0
    end
    critical = sort!([n for (n, m) in margin if isapprox(m, 0.0; atol = atol)])
    return P, through, margin, critical
end

"""
Accumulation ground truth under LOAD-INJECTION semantics: a node's value is injected
once at the node, fans out along every directed route, and contributions merge
additively. The defining identity is
    F[t] = sum_v m(v->t) d_v + sum_(u,v) m(v->t) w_uv
with m(v->t) = number of directed v->t paths, counted here by an independent memoised
DFS (no engine code). Returns (total_at_target, multiplicities_to_target).
This is the recursion semantics of the accumulation engines (old and V2) and of the
published slide-10 numbers; per-path re-emission (counting d_v once per source route
reaching v) is a DIFFERENT quantity and is deliberately not used.
"""
function oracle_accumulation(edges, out, nodes, d, w, target)
    memo = Dict{Int64,Int64}(target => 1)
    function cntto(v)
        haskey(memo, v) && return memo[v]
        c = 0
        for s in get(out, v, Int64[])
            c += cntto(s)
        end
        memo[v] = c
        return c
    end
    mult = Dict{Int64,Int64}(n => cntto(n) for n in nodes)
    total = sum(mult[v] * get(d, v, 0.0) for v in nodes; init = 0.0) +
            sum(get(mult, v, 0) * get(w, (u, v), 0.0) for (u, v) in edges; init = 0.0)
    return total, mult
end

end # module
