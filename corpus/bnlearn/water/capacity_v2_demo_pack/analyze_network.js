const edges = [[1,9], [1,11], [2,10], [2,11], [2,12], [3,11], [3,13], [3,14], [4,12], [4,15], [5,11], [5,13], [5,16], [6,11], [6,14], [6,16], [7,12], [7,15], [7,16], [8,13], [8,14], [8,16], [9,17], [9,19], [10,18], [10,19], [10,20], [11,19], [11,21], [11,22], [12,20], [12,23], [13,19], [13,21], [13,24], [14,19], [14,22], [14,24], [15,20], [15,23], [15,24], [16,21], [16,22], [16,24], [17,25], [17,27], [18,26], [18,27], [18,28], [19,27], [19,29], [19,30], [20,28], [20,31], [21,27], [21,29], [21,32], [22,27], [22,30], [22,32], [23,28], [23,31], [23,32], [24,29], [24,30], [24,32]];

const sources = [1, 2];
const layer1 = [9,10,11,12,13,14,15,16];
const layer2 = [17,18,19,20,21,22,23,24];
const targets = [25,26,27,28,29,30,31,32];

console.log('=== WATER NETWORK TOPOLOGY ANALYSIS ===\n');

console.log('ACTIVE SOURCES (1,2) → LAYER 1 CONNECTIONS:');
sources.forEach(s => {
  const outs = edges.filter(([a,b]) => a === s && layer1.includes(b));
  console.log(`  Source ${s} -> ${outs.map(([a,b]) => b).join(', ')}`);
  console.log(`    (${outs.length} outgoing edges)`);
});

console.log('\nLAYER 1 → LAYER 2 CONNECTIONS:');
layer1.forEach(n => {
  const outs = edges.filter(([a,b]) => a === n && layer2.includes(b));
  if(outs.length) {
    console.log(`  Node ${n} -> ${outs.map(([a,b]) => b).join(', ')}`);
  }
});

console.log('\nLAYER 2 → TARGETS:');
layer2.forEach(n => {
  const outs = edges.filter(([a,b]) => a === n && targets.includes(b));
  if(outs.length) {
    console.log(`  Node ${n} -> ${outs.map(([a,b]) => b).join(', ')}`);
  }
});

console.log('\nMOST CONNECTED NODES (potential bottleneck points):');
const nodeDegree = {};
[...layer1, ...layer2].forEach(n => {
  const inEdges = edges.filter(([a,b]) => b === n);
  const outEdges = edges.filter(([a,b]) => a === n);  
  nodeDegree[n] = { 
    in: inEdges.length, 
    out: outEdges.length, 
    total: inEdges.length + outEdges.length,
    inNodes: inEdges.map(([a]) => a),
    outNodes: outEdges.map(([,b]) => b)
  };
});

Object.entries(nodeDegree)
  .sort((a,b) => b[1].total - a[1].total)
  .slice(0,8)
  .forEach(([n, deg]) => {
    console.log(`  Node ${n}: ${deg.in} in, ${deg.out} out = ${deg.total} total`);
    console.log(`    <- ${deg.inNodes.join(',')}`);
    console.log(`    -> ${deg.outNodes.join(',')}`);
  });

console.log('\nCRITICAL OBSERVATION:');
console.log('Node 11 and 19 are the most connected (6+ connections each)');
console.log('All flow from sources (1,2) must pass through Layer 1 (9-16)');
console.log('To create meaningful bottlenecks:');
console.log('  - Tighten ALL edges out of high-degree nodes (11, 19)');
console.log('  - OR tighten node capacity at 11, 19');
console.log('  - OR tighten ALL edges in a specific layer transition');
