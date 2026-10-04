# Net3 with the demand super-sink (capacity analysis)

The edge list and inputs that the Net3 capacity analysis reads (thesis Chapter 10).

- `net3-supply.EDGES`: the 119 edges of `../net3.EDGES`, unchanged, plus one edge from each of
  the 58 demand junctions to an added super-sink, node 98. 98 nodes, 177 edges.
- `net3-supply-node-mapping.txt`: `../net3-node-mapping.txt` with the row for node 98.
- `{Baseline,Degraded,Interval}/*-capacities.json`: the capacities of section 3 of
  `../RESULTS.md`. Each file sets `"target_nodes": [98]`, so the super-sink is the only sink.
  Without it, the two filling tanks (3, 5) and the dead-end junction 96 (EPANET 601), which has
  no demand, would also be taken as sinks.
- `{Baseline,Degraded,Interval}/*-cpm-inputs.json`: the schedule inputs of `../net3-scenarios/`
  with node 98 and the 58 demand edges added at zero duration and zero delay. The schedule result
  is unchanged (1,773.33 hours, the same 28 critical activities, plus node 98). These are used
  only to draw the critical path and the minimum cut on one network (thesis Figure 10.14).
- `check_maxflow_oracle.py`: an independent max-flow check (pure-Python Edmonds-Karp, no shared
  code with the toolkit). Its output is in `check_maxflow_oracle_output.txt`.

The reliability and schedule analyses of Chapter 10 read `../net3.EDGES`, because adding node 98
would create new diamonds and change the reliability decomposition.
