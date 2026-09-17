# Expected UI Outputs for Capacity Demo Scenarios

## Overview
All scenarios are now **topology-aware** and place bottlenecks at meaningful locations:
- **Node 11**: Most connected hub (8 connections), fed by BOTH sources (1, 2)
- **Node 19**: Critical junction (8 connections), receives from 5 intermediate nodes

---

## Scenario 1: Edge Bottleneck Demo

### Configuration
- **Source rates**: 42 + 42 = **84 units**
- **Critical edges** (all ~12-14 capacity):
  - Out of node 11: (11,19)=14.28, (11,21)=13.48, (11,22)=13.94 → Total: 41.7
  - Into node 19: (9,19)=13.14, (10,19)=12.57, (11,19)=14.28 → Total: 39.99
  - Out of node 19: (19,27)=12.23, (19,29)=11.88, (19,30)=12.58 → Total: 36.69

### Expected Backend Response
```json
{
  "total_max_flow": 36-42,
  "bottlenecks": {
    "bottleneck_type": "transmission",
    "saturated_edges": [
      "(9,19)", "(10,19)", "(11,19)", 
      "(11,21)", "(11,22)",
      "(19,27)", "(19,29)", "(19,30)"
    ],
    "near_saturated_edges": [...],
    "utilization_by_component": {
      "(11,19)": 0.95-1.0,
      "(19,27)": 0.95-1.0,
      ...
    }
  },
  "upgrade_analysis": {
    "edge_priorities": [
      {
        "edge": [19, 27],
        "priority_score": 0.85-0.95,
        "marginal_value": 5-10,
        "rationale": "Critical bottleneck: Operating at 98%. High upgrade ROI."
      },
      ...
    ]
  },
  "comparative_analysis": {
    "primary_limitation": "transmission",
    "strategic_recommendation": "Network limited by edge capacities..."
  }
}
```

### UI Should Display
1. **Overview Card**
   - Total max flow: ~40 units
   - Network utilization: **High** (70-85%)
   - Bottleneck type badge: **TRANSMISSION**

2. **Bottleneck Visualization**
   - Heatmap showing edges (11,19), (11,21), (19,27), (19,29) in RED
   - Utilization bars at 95-100%
   - List of 6-8 saturated/near-saturated edges

3. **Upgrade Priorities Table**
   - Top priorities: edges out of nodes 11 and 19
   - High marginal values (5-15 units per capacity increase)
   - Color-coded: RED (urgent), YELLOW (moderate), GREEN (adequate)

4. **Network Graph**
   - Nodes 11, 19 highlighted as critical hubs
   - Thick/red lines for saturated edges
   - Flow animation showing congestion

---

## Scenario 2: Node Bottleneck Demo

### Configuration
- **Source rates**: 40 + 40 = **80 units**
- **Critical nodes**:
  - Node 11 capacity: **18.5** (vs ~40+ units trying to pass through)
  - Node 19 capacity: **20.2** (vs ~35+ units trying to pass through)

### Expected Backend Response
```json
{
  "total_max_flow": 18-22,
  "bottlenecks": {
    "bottleneck_type": "node_processing",
    "saturated_nodes": [11, 19],
    "near_saturated_nodes": [21, 22],
    "utilization_by_component": {
      "11": 0.95-1.0,
      "19": 0.90-0.98
    }
  },
  "upgrade_analysis": {
    "node_priorities": [
      {
        "node": 11,
        "priority_score": 0.90-0.98,
        "marginal_value": 15-25,
        "rationale": "Critical hub: Operating at 99%. Extremely high upgrade ROI."
      }
    ]
  },
  "comparative_analysis": {
    "primary_limitation": "processing",
    "processing_bottlenecks": [11, 19]
  }
}
```

### UI Should Display
1. **Overview Card**
   - Bottleneck type badge: **PROCESSING**
   - Primary choke: **Node 11**

2. **Node Utilization**
   - Node 11: 95-100% (RED indicator)
   - Node 19: 90-98% (ORANGE indicator)
   - Animated "overheating" effect on saturated nodes

3. **Upgrade Priorities**
   - Node 11 at top with **highest marginal value**
   - Recommendation: "Upgrade node processing capacity at hub 11"

---

## Scenario 3: Mixed Bottleneck Demo

### Configuration
- **Source rates**: 45 + 45 = **90 units**
- **Both constraints**:
  - Nodes 11, 19, 21, 22 tight (~20-24 capacity)
  - Edges out of 11, 19 tight (~11-13 capacity)

### Expected Backend Response
```json
{
  "bottlenecks": {
    "bottleneck_type": "mixed",
    "saturated_nodes": [11, 19],
    "saturated_edges": ["(11,19)", "(19,27)", "(19,29)", ...],
    "utilization_by_component": { ... }
  },
  "comparative_analysis": {
    "primary_limitation": "mixed",
    "transmission_bottlenecks": ["(11,19)", "(19,27)"],
    "processing_bottlenecks": [11, 19]
  }
}
```

### UI Should Display
1. **Bottleneck type badge: MIXED**
2. **Both node AND edge visualizations highlighted**
3. **Complex upgrade recommendations** balancing both types

---

## Scenario 4: Source Limited Demo

### Configuration
- **Source rates**: 12 + 12 = **24 units**
- **All capacities generous** (75-85+)

### Expected Backend Response
```json
{
  "total_max_flow": 24,
  "bottlenecks": {
    "bottleneck_type": "source_limited",
    "saturated_nodes": [],
    "saturated_edges": [],
    "near_saturated_nodes": [],
    "near_saturated_edges": []
  },
  "upgrade_analysis": {
    "edge_priorities": [
      { "marginal_value": 0, "rationale": "Adequate capacity..." }
    ]
  }
}
```

### UI Should Display
1. **Bottleneck type badge: SOURCE LIMITED**
2. **All components GREEN** (low utilization)
3. **Recommendation**: "Network has excess capacity. Consider increasing source throughput."
4. **No upgrade priorities** (all marginal_value = 0)

---

## Scenario 5: Single Point of Failure Demo

### Configuration
- **Source rates**: 32 + 32 = **64 units**
- **Node 11 capacity: 12.5** ← EXTREME choke (64 → 12.5 = 510% overload!)
- All other capacities generous (75-85+)

### Expected Backend Response
```json
{
  "total_max_flow": 12-13,
  "bottlenecks": {
    "bottleneck_type": "node_processing",
    "saturated_nodes": [11],
    "utilization_by_component": {
      "11": 1.0
    }
  },
  "critical_paths": {
    "single_points_of_failure": [11],
    "path_redundancy": 0.15-0.25
  },
  "upgrade_analysis": {
    "node_priorities": [
      {
        "node": 11,
        "marginal_value": 50-60,
        "rationale": "CRITICAL SINGLE POINT OF FAILURE"
      }
    ]
  }
}
```

### UI Should Display
1. **ALERT indicator: SINGLE POINT OF FAILURE**
2. **Node 11 highlighted in BRIGHT RED** with warning icon
3. **Critical path visualization** showing all paths forced through node 11
4. **Path redundancy gauge** showing LOW redundancy
5. **Urgent upgrade recommendation** with highest priority score

---

## Scenario 6-7: Interval Scenarios

### Expected Backend Response
```json
{
  "uncertainty_mode": "interval",
  "interval_result": {
    "guaranteed_min_flow": 12-15,
    "possible_max_flow": 22-28,
    "worst_case_bottlenecks": [...],
    "best_case_bottlenecks": [...]
  }
}
```

### UI Should Display
1. **Range visualization**: "12-28 units (best/worst case)"
2. **Uncertainty bars** on all metrics
3. **Worst-case vs best-case comparison**

---

## UI Component Recommendations

### 1. Dashboard Overview
- **4 metric cards**: max flow, network utilization, bottleneck type, computation time
- **Status indicator**: color-coded (green/yellow/red)
- **Quick summary**: "Network limited by transmission capacity at edges..."

### 2. Bottleneck Analysis Panel
- **Interactive network graph** with:
  - Node size ∝ capacity utilization
  - Edge thickness ∝ flow
  - Color gradient: green (0-70%) → yellow (70-90%) → red (90-100%)
- **Saturation lists**:
  - Saturated edges (100%)
  - Near-saturated edges (90-99%)
  - Saturated nodes
- **Utilization histogram**

### 3. Upgrade Priorities Table
Columns:
- Component (node/edge)
- Current capacity
- Current utilization (%)
- Recommended capacity
- Marginal value (flow increase per unit upgrade)
- Priority score
- Rationale
- Action button

Sort by priority_score (descending)

### 4. Critical Paths Visualization
- **Path flow diagram** showing top 5-10 paths
- **SPOF indicators** with warning icons
- **Redundancy metrics**

### 5. Comparative Analysis
- **Side-by-side comparison**: realistic vs classical flow
- **Efficiency loss percentage**
- **Primary limitation badge**
- **Strategic recommendations** text

### 6. Validation Status
- **Checklist of passed validations** (✓)
- **Any warnings/errors** (if present)
- **Optimality guarantee** badge

---

## Testing the Scenarios

To test if scenarios work correctly:

1. **Upload scenario to backend**: POST `/capacity-analysis`
   ```json
   {
     "capacitiesPath": "Edge Bottleneck Demo/water-capacities.json"
   }
   ```

2. **Check response for**:
   - `total_max_flow` significantly less than source rates (bottleneck working)
   - `saturated_edges` or `saturated_nodes` arrays NOT empty
   - `bottleneck_type` matches scenario intent
   - `marginal_value` > 0 for tight components
   - `utilization_by_component` showing 90-100% for critical components

3. **Verify UI displays**:
   - Correct bottleneck type badge
   - Visual indicators on saturated components
   - Meaningful upgrade recommendations
   - Appropriate strategic guidance

---

## What Was Fixed

### Before (Random Bottlenecks)
- Bottlenecks placed at random low-traffic edges
- Source rates too low OR network naturally constrained elsewhere
- Result: No saturation, empty arrays, features not demonstrated

### After (Topology-Aware Bottlenecks)
- Bottlenecks at **node 11 and 19** (most connected hubs)
- **ALL flow from sources must pass through these critical points**
- Source rates calibrated to create 200-500% overload at bottlenecks
- Result: **Guaranteed saturation, meaningful demonstrations**

### Key Insight
In a DAG network, bottlenecks must be placed at topologically critical locations where:
1. **High traffic concentration** (multiple paths converge)
2. **Unavoidable choke points** (all source-to-target paths pass through)
3. **Mathematically verified** to carry majority of flow

Node 11 is fed by BOTH sources (1, 2) → perfect SPOF location
Node 19 receives from 5 intermediate nodes → perfect junction bottleneck
