# Was 4 dirnames, landing on __outside_of_scope/ instead of InfoPropFrmwrk/ (this script
# lives 5 directories below InfoPropFrmwrk/, not 4: __outside_of_scope/examples nets/capacity/
# flagship/check_flagship_benchmark.jl). Fixed 2026-08-30 -- confirmed by the include() below
# now resolving; previously threw "No such file" on InputProcessingModule.jl.
project_root = dirname(dirname(dirname(dirname(dirname(@__FILE__)))))

include(joinpath(project_root, "src", "Algorithms", "Shared", "InputProcessingModule.jl"))
using .InputProcessingModule
using JSON

include(joinpath(project_root, "src", "Algorithms", "FlowCapacity", "CapacityAnalysisKit.jl"))
using .CapacityAnalysisKit

# Also stale: "example-networks/capacity" doesn't exist under InfoPropFrmwrk/ -- the actual
# files (network_flagship.edges, flagship/edge_capacities_flagship.json, etc.) live under
# __outside_of_scope/examples nets/capacity/. Fixed 2026-08-30, same pass as project_root above.
network_dir = joinpath(project_root, "__outside_of_scope", "examples nets", "capacity")

config_mode = uppercase(get(ENV, "FLAGSHIP_CONFIG", "BASE"))

function add_edge!(
  edgelist::Vector{Tuple{Int64,Int64}},
  outgoing_index::Dict{Int64,Set{Int64}},
  incoming_index::Dict{Int64,Set{Int64}},
  capacities::Dict{Tuple{Int64,Int64},Float64},
  u::Int64,
  v::Int64,
  c::Float64,
)
  e = (u, v)
  if !(e in Set(edgelist))
    push!(edgelist, e)
    push!(get!(outgoing_index, u, Set{Int64}()), v)
    push!(get!(incoming_index, v, Set{Int64}()), u)
  end
  capacities[e] = c
end

edgelist, outgoing_index, incoming_index, source_nodes_set =
    read_graph_to_dict(joinpath(network_dir, "network_flagship.edges"))

capacities = read_edge_capacities_from_json(joinpath(network_dir, "flagship", "edge_capacities_flagship.json"))
node_capacities = read_node_capacities_from_json(joinpath(network_dir, "flagship", "node_capacities_flagship.json"))

if config_mode == "A" || config_mode == "B"
  # Configuration A/B: add a direct bypass path into sink_4.
  add_edge!(edgelist, outgoing_index, incoming_index, capacities, 132, 140, 3.0)
end

if config_mode == "B"
  # Configuration B: relax gateway feeder constraints.
  boosted = Dict(
    (128, 134) => 5.0, (128, 135) => 2.0,
    (129, 134) => 4.0, (129, 135) => 4.0,
    (130, 134) => 3.0, (130, 135) => 5.0,
    (131, 134) => 5.0, (131, 135) => 3.0,
    (132, 134) => 4.0, (132, 135) => 4.0,
    (133, 134) => 2.0, (133, 135) => 5.0,
  )
  for (e, c) in boosted
    capacities[e] = c
  end
end

source_nodes = sort!(collect(source_nodes_set))
all_nodes = sort!(collect(union(Set(first.(edgelist)), Set(last.(edgelist)))))
sink_nodes = sort!([n for n in all_nodes if !haskey(outgoing_index, n) || isempty(outgoing_index[n])])

metadata = JSON.parsefile(joinpath(network_dir, "flagship", "flagship_node_metadata.json"))
node_labels = Dict(parse(Int, k) => String(v) for (k, v) in metadata["node_labels"])
layer_count = length(keys(metadata["layers"]))

function edge_label(e::Tuple{Int64,Int64})
  u, v = e
  lu = get(node_labels, u, string(u))
  lv = get(node_labels, v, string(v))
  return string("(", u, "->", v, ") ", lu, "->", lv)
end

function sorted_pairs(d::Dict{Int64,Float64})
  return sort(collect(d); by=x -> x[1])
end

function sorted_edge_pairs(d::Dict{Tuple{Int64,Int64},Float64})
  return sort(collect(d); by=x -> x[1])
end

function find_single_node_sink_restore(
  edgelist::Vector{Tuple{Int64,Int64}},
  outgoing_index::Dict{Int64,Set{Int64}},
  incoming_index::Dict{Int64,Set{Int64}},
  capacities::Dict{Tuple{Int64,Int64},Float64},
  source_nodes::Vector{Int64},
  sink_nodes::Vector{Int64},
  node_capacities::Dict{Int64,Float64},
  candidates::Vector{Int64},
  target_sink::Int64,
  required_sink_flow::Float64;
  step::Float64=0.5,
  max_delta::Float64=20.0,
  algorithm::Symbol=:dinic,
  tol::Float64=1e-10,
)
  records = NamedTuple[]
  best = nothing

  for v in candidates
    original_cap = node_capacities[v]
    found = nothing
    delta = 0.0

    while delta <= max_delta + tol
      trial_caps = copy(node_capacities)
      trial_caps[v] = original_cap + delta

      trial = solve_node_capacitated_flow(
        edgelist, outgoing_index, incoming_index,
        capacities, source_nodes, sink_nodes,
        trial_caps;
        algorithm=algorithm,
        tol=tol,
        validate=true,
      )

      sink_flow = get(trial.sink_flow, target_sink, 0.0)
      if sink_flow >= required_sink_flow - tol
        found = (
          node=v,
          restored=true,
          delta=delta,
          new_capacity=trial_caps[v],
          restored_sink_flow=sink_flow,
          restored_total_flow=trial.max_flow,
          sink_flow_profile=sorted_pairs(trial.sink_flow),
        )
        break
      end

      delta += step
    end

    if found === nothing
      rec = (
        node=v,
        restored=false,
        delta=Inf,
        new_capacity=original_cap,
        restored_sink_flow=0.0,
        restored_total_flow=0.0,
        sink_flow_profile=Vector{Pair{Int64,Float64}}(),
      )
      push!(records, rec)
    else
      push!(records, found)
      if best === nothing || found.delta < best.delta
        best = found
      end
    end
  end

  return records, best
end

function average_total_degree(edgelist::Vector{Tuple{Int64,Int64}}, nodes::Vector{Int64})
  n = length(nodes)
  n == 0 && return 0.0
  return (2.0 * length(edgelist)) / n
end

function undirected_diameter(edgelist::Vector{Tuple{Int64,Int64}}, nodes::Vector{Int64})
  if isempty(nodes)
    return 0
  end

  adj = Dict{Int64,Vector{Int64}}(n => Int64[] for n in nodes)
  for (u, v) in edgelist
    push!(adj[u], v)
    push!(adj[v], u)
  end

  diam = 0
  for src in nodes
    dist = Dict(src => 0)
    q = Int64[src]
    head = 1
    while head <= length(q)
      u = q[head]
      head += 1
      du = dist[u]
      for w in get(adj, u, Int64[])
        if !haskey(dist, w)
          dist[w] = du + 1
          push!(q, w)
          diam = max(diam, du + 1)
        end
      end
    end
  end
  return diam
end

degradation_alphas = [1.0, 0.9, 0.8, 0.7, 0.6, 0.5]

result = analyze_all(
    edgelist, outgoing_index, incoming_index,
    capacities, source_nodes, sink_nodes;
    node_capacities=node_capacities,
    k_failure=2,
    cut_limit=1000,
    target_flow=34.0,
    degradation_scenarios=degradation_alphas,
    path_limit=20000,
    combination_limit=5000,
    algorithm=:dinic,
    tol=1e-10,
)


  gateway_edges = [(Int64(134), Int64(136)), (Int64(135), Int64(136))]
  gateway_degradation_thresholds = [
    find_degradation_threshold(
      edgelist, outgoing_index, incoming_index,
      capacities, source_nodes, sink_nodes,
      e, result.baseline_max_flow;
      algorithm=:dinic,
      tol=1e-10,
    ) for e in gateway_edges
  ]

  upgrade_candidates = vcat(gateway_edges, [(Int64(136), Int64(s)) for s in sink_nodes])
  # Include direct bypass upgrade threshold when this edge exists (A/B configs).
  bypass_edge = (Int64(132), Int64(140))
  if haskey(capacities, bypass_edge)
    push!(upgrade_candidates, bypass_edge)
  end
  upgrade_thresholds = [
    find_upgrade_threshold(
      edgelist, outgoing_index, incoming_index,
      capacities, source_nodes, sink_nodes,
      e, result.baseline_max_flow + 1.0;
      algorithm=:dinic,
      tol=1e-10,
    ) for e in upgrade_candidates
  ]

  all_cut_S = [cut.S for cut in result.min_cut_analysis.enumeration.cuts]
  S_star = result.flow.mincut_S
  S_star_star = isempty(all_cut_S) ? copy(S_star) : reduce(union, all_cut_S)
  free_zone_nodes = sort!(collect(setdiff(S_star_star, S_star)))

  some_set = Set(result.min_cut_analysis.edges_in_some_cut)
  every_set = Set(result.min_cut_analysis.edges_in_every_cut)
  some_not_every = sort!(collect(setdiff(some_set, every_set)))

  redundancy_focus_edges = sort!([(u, v) for (u, v) in edgelist if v in Set([134, 135, 136])])

  diam = undirected_diameter(edgelist, all_nodes)
  avg_deg = average_total_degree(edgelist, all_nodes)

  println("=== NETWORK SUMMARY ===")
println("config_mode=", config_mode)
println("nodes=", length(all_nodes))
println("edges=", length(edgelist))
println("sources=", source_nodes)
println("sinks=", sink_nodes)
  println("layers=", layer_count)
  println("diameter_undirected=", diam)
  println("average_total_degree=", avg_deg)

  println("=== BASELINE FLOW ===")
println("baseline_max_flow=", result.baseline_max_flow)
println("mincut_capacity=", result.flow.mincut_capacity)
  println("sink_flow=", sorted_pairs(result.flow.sink_flow))
  println("saturated_edge_count=", length(result.flow.saturated_edges))
  println("saturated_edge_fraction=", length(result.flow.saturated_edges), "/", length(edgelist))

  println("=== MIN-CUT STRUCTURE ===")
  println("mincut_S=", sort!(collect(result.flow.mincut_S)))
  println("mincut_T=", sort!(collect(result.flow.mincut_T)))
  println("mincut_S_star_star=", sort!(collect(S_star_star)))
  println("free_zone_nodes=", free_zone_nodes)
println("paths=", length(result.structure.paths))
println("decomp_components=", length(result.flow_decomposition.components))
println("spof_edges_count=", length(result.structure.spof_edges))
println("spof_nodes=", result.structure.spof_nodes)
println("mincuts_total=", result.min_cut_analysis.enumeration.total_cuts)
println("mincuts_complete=", result.min_cut_analysis.enumeration.is_complete)
println("free_zone_size=", result.min_cut_analysis.enumeration.free_zone_size)
println("edges_in_every_cut_count=", length(result.min_cut_analysis.edges_in_every_cut))
println("edges_in_some_cut_count=", length(result.min_cut_analysis.edges_in_some_cut))
  println("edges_in_some_not_every=", some_not_every)

  for (i, cut) in enumerate(result.min_cut_analysis.enumeration.cuts)
    println("mincut_", i, "_S=", sort!(collect(cut.S)))
    println("mincut_", i, "_T=", sort!(collect(cut.T)))
    println("mincut_", i, "_crossing_edges=", sort!(cut.crossing_edges))
  end

  println("=== NODE-CAPACITATED COMPARISON ===")
println("node_cap_max_flow=", result.node_capacitated.flow_result.max_flow)
  println("node_cap_flow_drop=", result.baseline_max_flow - result.node_capacitated.flow_result.max_flow)
println("saturated_nodes=", result.node_capacitated.flow_result.saturated_nodes)
  println("node_cap_sink_flow=", sorted_pairs(result.node_capacitated.flow_result.sink_flow))

  println("=== NODE-UPGRADE SWEEP (SINK RESTORATION) ===")
  target_sink = Int64(137)
  restore_target = get(result.flow.sink_flow, target_sink, 0.0)
  baseline_node_cap_sink = get(result.node_capacitated.flow_result.sink_flow, target_sink, 0.0)
  node_candidates = Int64[114, 115, 116, 117, 118, 119]
  sweep_records, best_single = find_single_node_sink_restore(
    edgelist, outgoing_index, incoming_index,
    capacities, source_nodes, sink_nodes,
    node_capacities,
    node_candidates,
    target_sink,
    restore_target;
    step=0.5,
    max_delta=20.0,
    algorithm=:dinic,
    tol=1e-10,
  )
  println("node_upgrade_target_sink=", target_sink)
  println("node_upgrade_target_sink_restore_to=", restore_target)
  println("node_upgrade_node_cap_baseline_sink_flow=", baseline_node_cap_sink)
  for rec in sweep_records
    println(
      "node_upgrade_candidate=", rec.node,
      ",restored=", rec.restored,
      ",delta=", rec.delta,
      ",new_capacity=", rec.new_capacity,
      ",restored_sink_flow=", rec.restored_sink_flow,
      ",restored_total_flow=", rec.restored_total_flow,
      ",sink_flow_profile=", rec.sink_flow_profile,
    )
  end
  if best_single === nothing
    println("node_upgrade_best_single=none")
  else
    println(
      "node_upgrade_best_single=node:", best_single.node,
      ",delta:", best_single.delta,
      ",new_capacity:", best_single.new_capacity,
      ",restored_sink_flow:", best_single.restored_sink_flow,
      ",restored_total_flow:", best_single.restored_total_flow,
    )
  end

  println("=== SENSITIVITY ===")
  for rec in result.sensitivity.critical_edges
    println("critical_edge=", edge_label(rec.edge), ",drop=", rec.drop, ",perturbed_flow=", rec.perturbed_flow)
  end

  for (e, mu) in sorted_edge_pairs(result.sensitivity.marginal_capacity)
    println("marginal_capacity=", edge_label(e), ",mu=", mu)
  end

  for (e, b) in sorted_edge_pairs(result.sensitivity.birnbaum)
    println("marginal_range=", edge_label(e), ",B=", b)
  end

  println("=== FAILURES ===")
println("top_single_edge_drop=", isempty(result.failure_impact.single_edge_failures) ? 0.0 : first(result.failure_impact.single_edge_failures).drop)
println("top_k2_drop=", isempty(result.failure_impact.k_edge_failures) ? 0.0 : first(result.failure_impact.k_edge_failures).drop)
  for rec in result.failure_impact.single_edge_failures
    println("single_edge_fail=", edge_label(rec.edge), ",drop=", rec.drop, ",perturbed_flow=", rec.perturbed_flow)
  end

  for (i, rec) in enumerate(result.failure_impact.k_edge_failures)
    i > 10 && break
    edges_lbl = [edge_label((Int64(e[1]), Int64(e[2]))) for e in rec.edges]
    println("k2_fail_rank=", i, ",edges=", edges_lbl, ",drop=", rec.drop, ",perturbed_flow=", rec.perturbed_flow)
  end

  for rec in result.failure_impact.degradation_results
    alpha = degradation_alphas[rec.scenario_id]
    println("degradation_alpha=", alpha, ",max_flow=", rec.max_flow, ",drop=", rec.drop_from_baseline, ",sink_flow=", sorted_pairs(rec.sink_flow))
  end

  println("=== FLOW DECOMPOSITION ===")
  for (i, comp) in enumerate(result.flow_decomposition.components)
    println("decomp_component=", i, ",flow=", comp.flow_value, ",bottleneck=", edge_label(comp.bottleneck_edge), ",path=", comp.path)
  end

  println("=== PARAMETRIC THRESHOLDS ===")
  for th in gateway_degradation_thresholds
    println("gateway_degrade_threshold=edge=", edge_label(th.target_edge), ",original=", th.original_capacity, ",threshold=", th.threshold_capacity, ",margin=", th.degradation_margin)
  end

  for th in upgrade_thresholds
    println("upgrade_threshold=edge=", edge_label(th.target_edge), ",required_capacity=", th.required_capacity, ",required_increase=", th.required_increase, ",ineffective=", th.upgrade_ineffective)
  end

  println("=== REDUNDANCY FOCUS (EDGES INTO 134/135/136) ===")
  for e in redundancy_focus_edges
    score = get(result.structure.edge_redundancy, e, -1)
    println("edge_redundancy=", edge_label(e), ",score=", score)
  end

  println("=== GLOBAL CONNECTIVITY ===")
println("lambda=", result.global_connectivity.edge_connectivity.lambda)
println("kappa=", result.global_connectivity.node_connectivity.kappa)