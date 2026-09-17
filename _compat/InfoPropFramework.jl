# Compatibility shim: the pre-package facade name, backed by the registered package.
#
# The validation and case-study scripts in this repository were written against the
# working monorepo, where the algorithm code lived at
# `InfoPropFrmwrk/src/Algorithms/InfoPropFramework.jl` and was loaded with
#
#     include(joinpath(REPO, "InfoPropFrmwrk", "src", "Algorithms", "InfoPropFramework.jl"))
#     using .InfoPropFramework
#
# That algorithm layer is now the registered package `InformationPropagationAnalysis`
# (v0.2.1), whose public API is namespaced by toolkit (`Input`, `Diamonds`,
# `Probability`, `CriticalPath`, `Flow`). This shim keeps the old flat name so the
# scripts run unchanged apart from the include path:
#
#     include(joinpath(@__DIR__, "..", "_compat", "InfoPropFramework.jl"))
#     using .InfoPropFramework
#
# It re-exports the flat symbol list the scripts use and aliases the old internal
# module names they reference (`CapacityAnalysisKit`, `InputProcessingModule`,
# `ProbabilityPropagationModule`, `CriticalPathV2Module`, `DiamondDecompositionModule`).
#
# Pinned package version: see this directory's Project.toml / Manifest.toml.
module InfoPropFramework

using InformationPropagationAnalysis
const IPA = InformationPropagationAnalysis

# --- toolkit submodules under their pre-registration names --------------------
const InputProcessingModule        = IPA.Input
const DiamondDecompositionModule   = IPA.Diamonds
const ProbabilityPropagationModule = IPA.Probability
const CriticalPathV2Module         = IPA.CriticalPath
const CapacityAnalysisKit          = IPA.Flow
const CapacityAnalysisKitResult    = IPA.Flow.FlowCapacityResult

# --- flat re-exports (Input) -------------------------------------------------
using InformationPropagationAnalysis.Input:
    read_graph_to_dict, read_complete_network,
    find_iteration_sets, identify_fork_and_join_nodes,
    read_node_priors_from_json, read_edge_probabilities_from_json,
    read_node_priors_from_json_pbox, read_edge_probabilities_from_json_pbox,
    read_node_priors_from_json_interval, read_edge_probabilities_from_json_interval,
    read_node_priors_from_json_float64, read_edge_probabilities_from_json_float64,
    read_edge_capacities_from_json, read_node_capacities_from_json, read_capacities_input

# --- flat re-exports (Diamonds) --------------------------------------------
using InformationPropagationAnalysis.Diamonds:
    Diamond, DiamondsAtNode, DiamondComputationData, new_identify, create_diamond_hash_key

# --- flat re-exports (Probability) ----------------------------------------
using InformationPropagationAnalysis.Probability:
    update_beliefs_iterative, validate_network_data,
    calculate_regular_belief, inclusion_exclusion,
    CacheKey, DiamondCacheEntry, make_cache_key

# --- flat re-exports (CriticalPath) --------------------------------------
using InformationPropagationAnalysis.CriticalPath: critical_path

# --- flat re-exports (Flow) ----------------------------------------------
using InformationPropagationAnalysis.Flow:
    analyze_all,
    solve_max_flow_dinic, solve_max_flow_edmonds_karp, solve_max_flow_push_relabel

# --- value types ---------------------------------------------------------
using InformationPropagationAnalysis: Interval, pbox
const PBA = IPA.PBA

export
    IPA,
    InputProcessingModule, DiamondDecompositionModule, ProbabilityPropagationModule,
    CriticalPathV2Module, CapacityAnalysisKit, CapacityAnalysisKitResult,
    read_graph_to_dict, read_complete_network,
    find_iteration_sets, identify_fork_and_join_nodes,
    read_node_priors_from_json, read_edge_probabilities_from_json,
    read_node_priors_from_json_pbox, read_edge_probabilities_from_json_pbox,
    read_node_priors_from_json_interval, read_edge_probabilities_from_json_interval,
    read_node_priors_from_json_float64, read_edge_probabilities_from_json_float64,
    read_edge_capacities_from_json, read_node_capacities_from_json, read_capacities_input,
    Diamond, DiamondsAtNode, DiamondComputationData, new_identify, create_diamond_hash_key,
    update_beliefs_iterative, validate_network_data,
    calculate_regular_belief, inclusion_exclusion,
    CacheKey, DiamondCacheEntry, make_cache_key,
    critical_path,
    analyze_all,
    solve_max_flow_dinic, solve_max_flow_edmonds_karp, solve_max_flow_push_relabel,
    Interval, pbox, PBA

end # module InfoPropFramework
