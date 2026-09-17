const fs = require('fs');
const path = require('path');

const ROOT_DIR = __dirname;
const WATER_DIR = path.resolve(ROOT_DIR, '..');
const PACK_DIR = WATER_DIR;
const TARGET_NODES = [25, 26, 27, 28, 29, 30, 31, 32];

const EDGES = [
  [1,9], [1,11], [2,10], [2,11], [2,12], [3,11], [3,13], [3,14],
  [4,12], [4,15], [5,11], [5,13], [5,16], [6,11], [6,14], [6,16],
  [7,12], [7,15], [7,16], [8,13], [8,14], [8,16], [9,17], [9,19],
  [10,18], [10,19], [10,20], [11,19], [11,21], [11,22], [12,20],
  [12,23], [13,19], [13,21], [13,24], [14,19], [14,22], [14,24],
  [15,20], [15,23], [15,24], [16,21], [16,22], [16,24], [17,25],
  [17,27], [18,26], [18,27], [18,28], [19,27], [19,29], [19,30],
  [20,28], [20,31], [21,27], [21,29], [21,32], [22,27], [22,30],
  [22,32], [23,28], [23,31], [23,32], [24,29], [24,30], [24,32]
];

function ensureDir(dir) {
  if (!fs.existsSync(dir)) fs.mkdirSync(dir, { recursive: true });
}

function writeJson(filePath, obj) {
  fs.writeFileSync(filePath, JSON.stringify(obj, null, 2));
}

function round6(value) {
  return Math.round(value * 1e6) / 1e6;
}

function timeStep(node) {
  return Math.floor((node - 1) / 8);
}

function varIdx(node) {
  return (node - 1) % 8;
}

function nodeCategory(node) {
  const categories = ['source', 'source', 'hub', 'hub', 'process', 'process', 'discharge', 'sink'];
  return categories[varIdx(node)];
}

function edgeType(src, dst) {
  const edgeTypes = {
    self_temporal: [[1,9], [2,10], [3,11], [4,12], [5,13], [6,14], [7,15], [8,16]],
    input_to_bod: [[1,11], [2,11], [3,11], [5,11], [6,11]],
    input_to_discharge: [[1,11], [2,12], [3,14], [4,15], [6,16], [7,16], [8,16]],
    bod_chain: [[9,17], [10,18], [12,20], [13,19]],
    discharge_to_process: [[17,25], [18,26], [20,28], [21,29], [22,30], [23,31], [24,32]],
    feedback_to_bod: [[9,19], [10,20], [11,22], [13,24], [14,24], [15,24]],
    nitrogen_chain: [[2,11], [5,13], [8,16], [16,21], [16,22]],
    reverse_nitrogen: [[11,21], [13,24], [15,20], [21,32], [22,32]],
    discharge_feedback: [[17,27], [18,27], [19,27], [20,28], [21,27], [22,27]],
    other: []
  };

  for (const [type, pairs] of Object.entries(edgeTypes)) {
    if (type === 'other') continue;
    if (pairs.some(([a, b]) => a === src && b === dst)) return type;
  }
  return 'other';
}

function asInterval(lower, upper) {
  return { type: 'interval', lower: round6(Math.min(lower, upper)), upper: round6(Math.max(lower, upper)) };
}

function byDataType(dataType, valueOrRange) {
  if (dataType === 'Interval') {
    if (Array.isArray(valueOrRange)) return asInterval(valueOrRange[0], valueOrRange[1]);
    return asInterval(valueOrRange, valueOrRange);
  }
  if (Array.isArray(valueOrRange)) return round6((valueOrRange[0] + valueOrRange[1]) / 2);
  return round6(valueOrRange);
}

function valueByType(dataType, base, multiplier = 1.0) {
  if (Array.isArray(base)) return byDataType(dataType, [base[0] * multiplier, base[1] * multiplier]);
  return byDataType(dataType, base * multiplier);
}

const scenarios = [
  {
    name: 'Edge Bottleneck Demo',
    dataType: 'Float64',
    intent: 'Pure edge-capacity bottleneck: High source rates pushing through tight edges out of critical hub node 11. Demonstrates saturated edges, transmission bottleneck type, edge upgrade priorities.',
    sourceRateBase: { 0: 42.0, 1: 42.0, 2: 0, 3: 0, 4: 0, 5: 0, 6: 0, 7: 0 },
    nodeCapBase: { source: 85, hub: 90, process: 85, discharge: 80, sink: 85 },
    nodeOverrides: { },
    edgeCapBase: {
      self_temporal: 55, input_to_bod: 50, input_to_discharge: 48, bod_chain: 52,
      discharge_to_process: 48, feedback_to_bod: 45, nitrogen_chain: 47,
      reverse_nitrogen: 42, discharge_feedback: 44, other: 46
    },
    edgeOverrides: {
      '(11,19)': 12.5, '(11,21)': 11.8, '(11,22)': 12.2,
      '(9,19)': 11.5, '(10,19)': 11.0, '(13,19)': 10.8,
      '(19,27)': 10.5, '(19,29)': 10.2, '(19,30)': 10.8
    },
    redundancy: 1.05,
    reachability: {
      sourcePriors: { 0: 0.82, 1: 0.82, 2: 0.76, 3: 0.74, 4: 0.79, 5: 0.76, 6: 0.74, 7: 0.70 },
      interiorPriors: { 0: 0.84, 1: 0.84, 2: 0.81, 3: 0.79, 4: 0.82, 5: 0.80, 6: 0.78, 7: 0.76 },
      edgeProbs: {
        self_temporal: 0.95, input_to_bod: 0.93, input_to_discharge: 0.91, bod_chain: 0.93,
        discharge_to_process: 0.89, feedback_to_bod: 0.90, nitrogen_chain: 0.87,
        reverse_nitrogen: 0.82, discharge_feedback: 0.88, other: 0.89
      }
    },
    cpm: {
      nodeDurations: { source: 2.0, hub: 3.2, process: 2.4, discharge: 1.6, sink: 1.2 },
      edgeDelays: {
        self_temporal: 1.2, input_to_bod: 2.5, input_to_discharge: 2.1, bod_chain: 2.2,
        discharge_to_process: 1.8, feedback_to_bod: 1.6, nitrogen_chain: 2.0,
        reverse_nitrogen: 1.5, discharge_feedback: 1.7, other: 1.8
      },
      nodeCosts: { source: 150, hub: 285, process: 205, discharge: 130, sink: 105 },
      edgeCosts: {
        self_temporal: 46, input_to_bod: 98, input_to_discharge: 84, bod_chain: 92,
        discharge_to_process: 74, feedback_to_bod: 68, nitrogen_chain: 78,
        reverse_nitrogen: 58, discharge_feedback: 63, other: 69
      }
    }
  },
  {
    name: 'Node Bottleneck Demo',
    dataType: 'Float64',
    intent: 'Pure node-processing bottleneck: High source rates constrained by tight capacity at critical hub node 11. Demonstrates saturated nodes, processing bottleneck type, node upgrade priorities.',
    sourceRateBase: { 0: 40.0, 1: 40.0, 2: 0, 3: 0, 4: 0, 5: 0, 6: 0, 7: 0 },
    nodeCapBase: { source: 85, hub: 88, process: 85, discharge: 80, sink: 85 },
    nodeOverrides: { 11: 18.5, 19: 20.2 },
    edgeCapBase: {
      self_temporal: 58, input_to_bod: 55, input_to_discharge: 52, bod_chain: 56,
      discharge_to_process: 54, feedback_to_bod: 50, nitrogen_chain: 52,
      reverse_nitrogen: 48, discharge_feedback: 50, other: 52
    },
    redundancy: 1.10,
    reachability: {
      sourcePriors: { 0: 0.81, 1: 0.81, 2: 0.75, 3: 0.73, 4: 0.77, 5: 0.75, 6: 0.72, 7: 0.68 },
      interiorPriors: { 0: 0.83, 1: 0.83, 2: 0.79, 3: 0.77, 4: 0.80, 5: 0.78, 6: 0.75, 7: 0.73 },
      edgeProbs: {
        self_temporal: 0.94, input_to_bod: 0.92, input_to_discharge: 0.90, bod_chain: 0.92,
        discharge_to_process: 0.84, feedback_to_bod: 0.89, nitrogen_chain: 0.85,
        reverse_nitrogen: 0.80, discharge_feedback: 0.82, other: 0.87
      }
    },
    cpm: {
      nodeDurations: { source: 2.1, hub: 3.4, process: 2.5, discharge: 1.9, sink: 1.6 },
      nodeDurationOverrides: { 29: 2.1, 30: 2.2, 31: 2.0, 32: 2.3 },
      edgeDelays: {
        self_temporal: 1.3, input_to_bod: 2.7, input_to_discharge: 2.2, bod_chain: 2.4,
        discharge_to_process: 2.6, feedback_to_bod: 1.8, nitrogen_chain: 2.1,
        reverse_nitrogen: 1.7, discharge_feedback: 2.5, other: 2.0
      },
      nodeCosts: { source: 155, hub: 300, process: 215, discharge: 150, sink: 138 },
      edgeCosts: {
        self_temporal: 48, input_to_bod: 104, input_to_discharge: 89, bod_chain: 97,
        discharge_to_process: 120, feedback_to_bod: 73, nitrogen_chain: 82,
        reverse_nitrogen: 62, discharge_feedback: 118, other: 74
      }
    }
  },
  {
    name: 'Mixed Bottleneck Demo',
    dataType: 'Float64',
    intent: 'Combined edge and node bottlenecks at network hubs: Very high source rates with tight constraints on both node 11/19 capacities AND their outgoing edges. Demonstrates mixed bottleneck type, complex upgrade prioritization.',
    sourceRateBase: { 0: 45.0, 1: 45.0, 2: 0, 3: 0, 4: 0, 5: 0, 6: 0, 7: 0 },
    nodeCapBase: { source: 90, hub: 85, process: 82, discharge: 80, sink: 82 },
    nodeOverrides: { 11: 22.5, 19: 24.0, 21: 22.0, 22: 21.5 },
    edgeCapBase: {
      self_temporal: 60, input_to_bod: 58, input_to_discharge: 55, bod_chain: 58,
      discharge_to_process: 55, feedback_to_bod: 52, nitrogen_chain: 54,
      reverse_nitrogen: 50, discharge_feedback: 52, other: 54
    },
    edgeOverrides: {
      '(11,19)': 13.5, '(11,21)': 12.8, '(11,22)': 13.2,
      '(9,19)': 12.5, '(10,19)': 12.0, '(13,19)': 11.8,
      '(19,27)': 11.5, '(19,29)': 11.8, '(19,30)': 12.0,
      '(21,27)': 11.0, '(21,29)': 10.8, '(22,27)': 10.5, '(22,30)': 11.2
    },
    redundancy: 1.08,
    reachability: {
      sourcePriors: { 0: 0.80, 1: 0.80, 2: 0.74, 3: 0.71, 4: 0.76, 5: 0.74, 6: 0.71, 7: 0.67 },
      interiorPriors: { 0: 0.82, 1: 0.82, 2: 0.78, 3: 0.75, 4: 0.79, 5: 0.77, 6: 0.74, 7: 0.71 },
      edgeProbs: {
        self_temporal: 0.93, input_to_bod: 0.90, input_to_discharge: 0.89, bod_chain: 0.90,
        discharge_to_process: 0.88, feedback_to_bod: 0.87, nitrogen_chain: 0.84,
        reverse_nitrogen: 0.79, discharge_feedback: 0.85, other: 0.86
      }
    },
    cpm: {
      nodeDurations: { source: 2.3, hub: 3.8, process: 2.9, discharge: 1.9, sink: 1.5 },
      edgeDelays: {
        self_temporal: 1.4, input_to_bod: 2.9, input_to_discharge: 2.4, bod_chain: 2.6,
        discharge_to_process: 2.0, feedback_to_bod: 2.0, nitrogen_chain: 2.2,
        reverse_nitrogen: 1.8, discharge_feedback: 2.0, other: 2.1
      },
      nodeCosts: { source: 165, hub: 320, process: 232, discharge: 148, sink: 120 },
      edgeCosts: {
        self_temporal: 52, input_to_bod: 112, input_to_discharge: 95, bod_chain: 104,
        discharge_to_process: 88, feedback_to_bod: 84, nitrogen_chain: 90,
        reverse_nitrogen: 69, discharge_feedback: 86, other: 80
      }
    }
  },
  {
    name: 'Source Limited Demo',
    dataType: 'Float64',
    intent: 'Source-limited network: Low source rates relative to very generous capacities. Demonstrates bottleneck_type: source_limited, minimal component saturation.',
    sourceRateBase: { 0: 12.0, 1: 12.0, 2: 0, 3: 0, 4: 0, 5: 0, 6: 0, 7: 0 },
    nodeCapBase: { source: 75, hub: 85, process: 80, discharge: 75, sink: 80 },
    edgeCapBase: {
      self_temporal: 45, input_to_bod: 42, input_to_discharge: 40, bod_chain: 43,
      discharge_to_process: 41, feedback_to_bod: 38, nitrogen_chain: 40,
      reverse_nitrogen: 35, discharge_feedback: 37, other: 39
    },
    redundancy: 1.28,
    reachability: {
      sourcePriors: { 0: 0.88, 1: 0.88, 2: 0.84, 3: 0.82, 4: 0.86, 5: 0.84, 6: 0.82, 7: 0.79 },
      interiorPriors: { 0: 0.90, 1: 0.90, 2: 0.87, 3: 0.85, 4: 0.88, 5: 0.87, 6: 0.85, 7: 0.83 },
      edgeProbs: {
        self_temporal: 0.98, input_to_bod: 0.96, input_to_discharge: 0.95, bod_chain: 0.96,
        discharge_to_process: 0.94, feedback_to_bod: 0.94, nitrogen_chain: 0.92,
        reverse_nitrogen: 0.88, discharge_feedback: 0.93, other: 0.94
      }
    },
    cpm: {
      nodeDurations: { source: 1.5, hub: 2.3, process: 1.8, discharge: 1.0, sink: 0.8 },
      edgeDelays: {
        self_temporal: 0.8, input_to_bod: 1.6, input_to_discharge: 1.4, bod_chain: 1.5,
        discharge_to_process: 1.1, feedback_to_bod: 1.0, nitrogen_chain: 1.3,
        reverse_nitrogen: 0.9, discharge_feedback: 1.1, other: 1.2
      },
      nodeCosts: { source: 185, hub: 375, process: 270, discharge: 180, sink: 142 },
      edgeCosts: {
        self_temporal: 72, input_to_bod: 152, input_to_discharge: 132, bod_chain: 145,
        discharge_to_process: 118, feedback_to_bod: 110, nitrogen_chain: 125,
        reverse_nitrogen: 95, discharge_feedback: 115, other: 108
      }
    }
  },
  {
    name: 'Single Point of Failure Demo',
    dataType: 'Float64',
    intent: 'Critical choke point at hub node 11: Moderate source rates with one extreme bottleneck at the most connected node. Demonstrates single_points_of_failure identification and critical path dependency.',
    sourceRateBase: { 0: 32.0, 1: 32.0, 2: 0, 3: 0, 4: 0, 5: 0, 6: 0, 7: 0 },
    nodeCapBase: { source: 80, hub: 85, process: 80, discharge: 75, sink: 80 },
    nodeOverrides: { 11: 12.5 },
    edgeCapBase: {
      self_temporal: 52, input_to_bod: 50, input_to_discharge: 48, bod_chain: 50,
      discharge_to_process: 48, feedback_to_bod: 45, nitrogen_chain: 47,
      reverse_nitrogen: 44, discharge_feedback: 46, other: 48
    },
    redundancy: 1.15,
    reachability: {
      sourcePriors: { 0: 0.84, 1: 0.84, 2: 0.79, 3: 0.77, 4: 0.81, 5: 0.79, 6: 0.77, 7: 0.74 },
      interiorPriors: { 0: 0.86, 1: 0.86, 2: 0.82, 3: 0.80, 4: 0.84, 5: 0.82, 6: 0.80, 7: 0.78 },
      edgeProbs: {
        self_temporal: 0.96, input_to_bod: 0.94, input_to_discharge: 0.92, bod_chain: 0.94,
        discharge_to_process: 0.91, feedback_to_bod: 0.91, nitrogen_chain: 0.89,
        reverse_nitrogen: 0.84, discharge_feedback: 0.90, other: 0.91
      }
    },
    cpm: {
      nodeDurations: { source: 1.9, hub: 3.0, process: 2.3, discharge: 1.5, sink: 1.1 },
      nodeDurationOverrides: { 19: 4.5 },
      edgeDelays: {
        self_temporal: 1.1, input_to_bod: 2.3, input_to_discharge: 1.9, bod_chain: 2.1,
        discharge_to_process: 1.6, feedback_to_bod: 1.5, nitrogen_chain: 1.8,
        reverse_nitrogen: 1.3, discharge_feedback: 1.5, other: 1.6
      },
      nodeCosts: { source: 165, hub: 310, process: 225, discharge: 148, sink: 118 },
      edgeCosts: {
        self_temporal: 54, input_to_bod: 116, input_to_discharge: 98, bod_chain: 108,
        discharge_to_process: 88, feedback_to_bod: 82, nitrogen_chain: 95,
        reverse_nitrogen: 70, discharge_feedback: 85, other: 82
      }
    }
  },
  {
    name: 'Interval Conservative',
    dataType: 'Interval',
    intent: 'Conservative uncertainty: low minima, wide ranges, and stressed worst-case behavior.',
    sourceRateBase: { 0: [7.0, 10.5], 1: [6.8, 10.3], 2: 0, 3: 0, 4: 0, 5: 0, 6: 0, 7: 0 },
    nodeCapBase: { source: [18, 24], hub: [20, 32], process: [18, 28], discharge: [16, 25], sink: [17, 27] },
    nodeOverrides: { 19: [14, 22], 21: [13, 21], 22: [13, 21], 29: [11, 20], 30: [10, 19], 32: [10, 18] },
    edgeCapBase: {
      self_temporal: [13, 20], input_to_bod: [11, 17], input_to_discharge: [10, 16], bod_chain: [11, 18],
      discharge_to_process: [9, 15], feedback_to_bod: [9, 15], nitrogen_chain: [10, 16],
      reverse_nitrogen: [7.5, 12.5], discharge_feedback: [8, 14], other: [9, 15]
    },
    redundancy: [0.98, 1.12],
    reachability: {
      sourcePriors: { 0: [0.72, 0.88], 1: [0.72, 0.88], 2: [0.66, 0.84], 3: [0.62, 0.82], 4: [0.68, 0.85], 5: [0.66, 0.84], 6: [0.64, 0.82], 7: [0.60, 0.79] },
      interiorPriors: { 0: [0.75, 0.90], 1: [0.75, 0.90], 2: [0.70, 0.87], 3: [0.66, 0.85], 4: [0.72, 0.88], 5: [0.70, 0.86], 6: [0.68, 0.84], 7: [0.66, 0.82] },
      edgeProbs: {
        self_temporal: [0.88, 0.96], input_to_bod: [0.84, 0.93], input_to_discharge: [0.83, 0.92], bod_chain: [0.84, 0.94],
        discharge_to_process: [0.80, 0.90], feedback_to_bod: [0.80, 0.91], nitrogen_chain: [0.76, 0.88],
        reverse_nitrogen: [0.72, 0.85], discharge_feedback: [0.78, 0.90], other: [0.80, 0.91]
      }
    },
    cpm: {
      nodeDurations: { source: [2.0, 2.8], hub: [3.3, 4.8], process: [2.6, 3.7], discharge: [1.8, 2.8], sink: [1.3, 2.0] },
      edgeDelays: {
        self_temporal: [1.2, 1.8], input_to_bod: [2.5, 3.5], input_to_discharge: [2.2, 3.2], bod_chain: [2.3, 3.3],
        discharge_to_process: [1.9, 2.9], feedback_to_bod: [1.8, 2.8], nitrogen_chain: [2.0, 3.0],
        reverse_nitrogen: [1.6, 2.5], discharge_feedback: [1.9, 2.9], other: [1.9, 2.8]
      },
      nodeCosts: { source: [150, 190], hub: [290, 370], process: [220, 280], discharge: [140, 210], sink: [110, 165] },
      edgeCosts: {
        self_temporal: [48, 68], input_to_bod: [104, 142], input_to_discharge: [89, 128], bod_chain: [98, 136],
        discharge_to_process: [84, 126], feedback_to_bod: [80, 120], nitrogen_chain: [88, 126],
        reverse_nitrogen: [65, 100], discharge_feedback: [84, 125], other: [78, 116]
      }
    }
  },
  {
    name: 'Interval Optimistic',
    dataType: 'Interval',
    intent: 'Optimistic uncertainty: stronger capacities and tighter intervals, improved best-case limits.',
    sourceRateBase: { 0: [9.8, 11.4], 1: [9.6, 11.2], 2: 0, 3: 0, 4: 0, 5: 0, 6: 0, 7: 0 },
    nodeCapBase: { source: [22, 25], hub: [30, 35], process: [24, 28], discharge: [22, 26], sink: [27, 31] },
    nodeOverrides: { 11: [33, 37], 13: [32, 36], 16: [33, 37], 21: [28, 32], 22: [28, 32] },
    edgeCapBase: {
      self_temporal: [18, 22], input_to_bod: [17, 21], input_to_discharge: [16, 20], bod_chain: [17, 21],
      discharge_to_process: [16, 20], feedback_to_bod: [15, 19], nitrogen_chain: [16, 20],
      reverse_nitrogen: [12, 15], discharge_feedback: [15, 19], other: [15, 19]
    },
    redundancy: [1.16, 1.24],
    reachability: {
      sourcePriors: { 0: [0.83, 0.90], 1: [0.83, 0.90], 2: [0.78, 0.87], 3: [0.75, 0.85], 4: [0.80, 0.88], 5: [0.78, 0.87], 6: [0.76, 0.85], 7: [0.73, 0.83] },
      interiorPriors: { 0: [0.85, 0.92], 1: [0.85, 0.92], 2: [0.81, 0.89], 3: [0.78, 0.87], 4: [0.83, 0.90], 5: [0.81, 0.89], 6: [0.79, 0.87], 7: [0.77, 0.85] },
      edgeProbs: {
        self_temporal: [0.93, 0.97], input_to_bod: [0.91, 0.96], input_to_discharge: [0.90, 0.95], bod_chain: [0.92, 0.96],
        discharge_to_process: [0.89, 0.94], feedback_to_bod: [0.89, 0.94], nitrogen_chain: [0.86, 0.92],
        reverse_nitrogen: [0.83, 0.89], discharge_feedback: [0.88, 0.94], other: [0.89, 0.94]
      }
    },
    cpm: {
      nodeDurations: { source: [1.7, 2.1], hub: [2.8, 3.5], process: [2.1, 2.8], discharge: [1.2, 1.8], sink: [0.9, 1.4] },
      edgeDelays: {
        self_temporal: [0.9, 1.3], input_to_bod: [1.9, 2.6], input_to_discharge: [1.6, 2.3], bod_chain: [1.8, 2.5],
        discharge_to_process: [1.3, 1.9], feedback_to_bod: [1.2, 1.8], nitrogen_chain: [1.5, 2.2],
        reverse_nitrogen: [1.1, 1.6], discharge_feedback: [1.3, 1.9], other: [1.3, 1.9]
      },
      nodeCosts: { source: [175, 195], hub: [335, 370], process: [240, 270], discharge: [160, 190], sink: [125, 150] },
      edgeCosts: {
        self_temporal: [58, 70], input_to_bod: [124, 146], input_to_discharge: [106, 128], bod_chain: [116, 138],
        discharge_to_process: [94, 116], feedback_to_bod: [90, 110], nitrogen_chain: [98, 120],
        reverse_nitrogen: [74, 92], discharge_feedback: [92, 114], other: [88, 108]
      }
    }
  }
];

function generateScenario(scenario) {
  const dir = path.join(PACK_DIR, scenario.name);
  ensureDir(dir);

  const dt = scenario.dataType;
  const isInterval = dt === 'Interval';

  const nodePriors = {};
  for (let n = 1; n <= 32; n++) {
    const t = timeStep(n);
    const v = varIdx(n);
    const base = t === 0 ? scenario.reachability.sourcePriors[v] : scenario.reachability.interiorPriors[v];
    nodePriors[String(n)] = byDataType(dt, base);
  }

  const linkProbabilities = {};
  for (const [src, dst] of EDGES) {
    const typ = edgeType(src, dst);
    const base = scenario.reachability.edgeProbs[typ] || scenario.reachability.edgeProbs.other;
    linkProbabilities[`(${src},${dst})`] = byDataType(dt, base);
  }

  const nodes = {};
  const sourceRates = {};
  const edges = {};

  for (let n = 1; n <= 32; n++) {
    const category = nodeCategory(n);
    const t = timeStep(n);
    const timeMultiplier = 1 + t * 0.03;
    const baseCap = (scenario.nodeOverrides && scenario.nodeOverrides[n]) || scenario.nodeCapBase[category];

    if (isInterval) {
      const baseRange = Array.isArray(baseCap) ? baseCap : [baseCap, baseCap];
      const red = Array.isArray(scenario.redundancy) ? scenario.redundancy : [scenario.redundancy, scenario.redundancy];
      nodes[String(n)] = asInterval(baseRange[0] * red[0] * timeMultiplier, baseRange[1] * red[1] * timeMultiplier);
    } else {
      const red = Array.isArray(scenario.redundancy) ? (scenario.redundancy[0] + scenario.redundancy[1]) / 2 : scenario.redundancy;
      nodes[String(n)] = round6(baseCap * red * timeMultiplier);
    }

    if (t === 0) {
      const rate = scenario.sourceRateBase[varIdx(n)];
      if (isInterval) {
        if (Array.isArray(rate) && rate[0] > 0) sourceRates[String(n)] = asInterval(rate[0], rate[1]);
      } else if (typeof rate === 'number' && rate > 0) {
        sourceRates[String(n)] = round6(rate);
      }
    }
  }

  for (const [src, dst] of EDGES) {
    const key = `(${src},${dst})`;
    const typ = edgeType(src, dst);
    const base = (scenario.edgeOverrides && scenario.edgeOverrides[key]) || scenario.edgeCapBase[typ] || scenario.edgeCapBase.other;
    const depthMultiplier = 1 + timeStep(src) * 0.02;

    if (isInterval) {
      const baseRange = Array.isArray(base) ? base : [base, base];
      const red = Array.isArray(scenario.redundancy) ? scenario.redundancy : [scenario.redundancy, scenario.redundancy];
      edges[key] = asInterval(baseRange[0] * red[0] * depthMultiplier, baseRange[1] * red[1] * depthMultiplier);
    } else {
      const red = Array.isArray(scenario.redundancy) ? (scenario.redundancy[0] + scenario.redundancy[1]) / 2 : scenario.redundancy;
      edges[key] = round6(base * red * depthMultiplier);
    }
  }

  const nodeDurations = {};
  const nodeCosts = {};
  for (let n = 1; n <= 32; n++) {
    const cat = nodeCategory(n);
    const dur = (scenario.cpm.nodeDurationOverrides && scenario.cpm.nodeDurationOverrides[n]) || scenario.cpm.nodeDurations[cat];
    const cost = (scenario.cpm.nodeCostOverrides && scenario.cpm.nodeCostOverrides[n]) || scenario.cpm.nodeCosts[cat];
    nodeDurations[String(n)] = byDataType(dt, dur);
    nodeCosts[String(n)] = byDataType(dt, cost);
  }

  const edgeDelays = {};
  const edgeCosts = {};
  for (const [src, dst] of EDGES) {
    const key = `(${src},${dst})`;
    const typ = edgeType(src, dst);
    edgeDelays[key] = byDataType(dt, scenario.cpm.edgeDelays[typ] || scenario.cpm.edgeDelays.other);
    edgeCosts[key] = byDataType(dt, scenario.cpm.edgeCosts[typ] || scenario.cpm.edgeCosts.other);
  }

  writeJson(path.join(dir, 'water-nodepriors.json'), {
    nodes: nodePriors,
    data_type: dt,
    serialization: 'compact',
    scenario_intent: scenario.intent,
    description: `Node prior probabilities for WATER network - ${scenario.name}. ${scenario.intent}`
  });

  writeJson(path.join(dir, 'water-linkprobabilities.json'), {
    links: linkProbabilities,
    data_type: dt,
    serialization: 'compact',
    scenario_intent: scenario.intent,
    description: `Link/edge probabilities for WATER network - ${scenario.name}. ${scenario.intent}`
  });

  writeJson(path.join(dir, 'water-capacities.json'), {
    network_type: 'capacity_flow',
    data_type: dt,
    capacities: {
      nodes,
      source_rates: sourceRates,
      edges
    },
    target_nodes: TARGET_NODES,
    scenario_intent: scenario.intent,
    description: `Capacity analysis inputs for WATER network - ${scenario.name}. ${scenario.intent}`,
    generation_info: {
      total_nodes: 32,
      total_edges: 66,
      source_nodes_count: 8,
      generator: 'capacity_v2_demo_pack/generate_demo_pack.js'
    }
  });

  writeJson(path.join(dir, 'water-cpm-inputs.json'), {
    time_analysis: {
      edge_delays: edgeDelays,
      combination_function: 'max_combination',
      initial_time: isInterval ? { lower: 0, upper: 0, type: 'interval' } : 0,
      analysis_type: 'longest_path_time',
      propagation_function: 'additive_propagation',
      node_durations: nodeDurations
    },
    network_type: 'critical_path',
    data_type: dt,
    cost_analysis: {
      initial_cost: isInterval ? { lower: 0, upper: 0, type: 'interval' } : 0,
      combination_function: 'max_combination',
      node_costs: nodeCosts,
      analysis_type: 'total_project_cost',
      propagation_function: 'additive_propagation',
      edge_costs: edgeCosts
    },
    scenario_intent: scenario.intent,
    description: `Critical Path Module inputs for WATER network - ${scenario.name}. ${scenario.intent}`,
    generation_info: {
      total_nodes: 32,
      total_edges: 66,
      generator: 'capacity_v2_demo_pack/generate_demo_pack.js'
    }
  });
}

function run() {
  ensureDir(PACK_DIR);

  for (const s of scenarios) {
    generateScenario(s);
    console.log(`Generated ${s.name} (${s.dataType})`);
  }

  console.log(`Done. Output folder: ${PACK_DIR}`);
}

run();
