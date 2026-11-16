### Baseline measurements

|Workload / DOF|Method|n|Iterations|Setup ms|PCG ms|Solve ms|Wall s [min-max]|Peak MiB|Precond. MiB|
|---|---|---:|---:|---:|---:|---:|---:|---:|---:|
|baseline / 107811|hpc22-jacobi|5|32|0.000|393.324|821.205|9.855 [9.210-10.244]|484.52|0.000|
|baseline / 107811|hpc23-jacobi|5|32|0.583|387.319|1571.432|10.420 [10.276-10.559]|485.12|0.823|



### Small measurements

|Workload / DOF|Method|n|Iterations|Setup ms|PCG ms|Solve ms|Wall s [min-max]|Peak MiB|Precond. MiB|
|---|---|---:|---:|---:|---:|---:|---:|---:|---:|
|elastic-8 / 2187|jacobi|3|8|0.028|4.944|20.242|0.214 [0.212-0.232]|14.42|0.017|
|elastic-8 / 2187|block-jacobi|3|41|0.529|20.020|35.241|0.215 [0.209-0.230]|14.55|0.067|
|elastic-8 / 2187|ic0|3|32|7.694|23.751|43.669|0.240 [0.224-0.279]|14.50|0.705|
|elastic-8 / 2187|auto|3|8|0.033|3.715|20.549|0.188 [0.187-0.243]|14.45|0.017|
|elastic-16 / 14739|jacobi|3|16|0.129|62.701|185.536|1.355 [1.333-1.415]|66.36|0.112|
|elastic-16 / 14739|block-jacobi|3|78|3.986|330.080|467.260|1.586 [1.556-1.666]|67.17|0.450|
|elastic-16 / 14739|ic0|3|60|78.608|360.432|545.355|1.683 [1.570-1.757]|72.08|5.691|
|elastic-16 / 14739|auto|3|16|0.117|64.697|209.347|1.352 [1.293-1.450]|66.67|0.112|
|slender-bending / 3675|jacobi|3|208|0.043|192.636|225.742|0.532 [0.513-0.561]|19.60|0.028|
|slender-bending / 3675|block-jacobi|3|195|1.077|185.571|230.354|0.506 [0.503-0.521]|19.52|0.112|
|slender-bending / 3675|ic0|3|145|11.438|188.329|226.249|0.534 [0.484-0.569]|19.41|1.260|
|slender-bending / 3675|auto|3|208|0.036|185.981|226.903|0.492 [0.483-0.514]|19.47|0.028|
|heterogeneous-elastic / 4131|jacobi|3|112|0.045|116.917|157.300|0.495 [0.461-0.531]|23.70|0.032|
|heterogeneous-elastic / 4131|block-jacobi|3|109|1.379|134.982|180.588|0.529 [0.487-0.599]|24.11|0.126|
|heterogeneous-elastic / 4131|ic0|3|113|18.672|183.335|243.697|0.676 [0.557-0.729]|24.31|1.503|
|heterogeneous-elastic / 4131|auto|3|112|0.059|117.601|154.985|0.503 [0.480-0.588]|23.82|0.032|
|contrast-conduction-8 / 729|jacobi|3|48|0.005|2.308|5.229|0.238 [0.234-0.253]|6.20|0.006|
|contrast-conduction-8 / 729|block-jacobi -> jacobi (fallback)|3|48|0.019|2.874|6.163|0.279 [0.239-0.291]|6.17|0.006|
|contrast-conduction-8 / 729|ic0|3|19|0.125|2.092|5.499|0.263 [0.244-0.280]|6.20|0.028|
|contrast-conduction-8 / 729|auto|3|48|0.005|2.108|4.751|0.266 [0.253-0.267]|6.16|0.006|
|contrast-conduction-16 / 4913|jacobi|3|91|0.048|28.951|50.207|1.649 [1.617-1.843]|16.36|0.037|
|contrast-conduction-16 / 4913|block-jacobi -> jacobi (fallback)|3|91|0.059|26.431|46.468|1.904 [1.659-1.960]|16.42|0.037|
|contrast-conduction-16 / 4913|ic0|3|33|0.719|14.175|31.950|1.720 [1.701-1.844]|16.60|0.215|
|contrast-conduction-16 / 4913|auto|3|91|0.052|28.680|46.226|1.767 [1.748-1.975]|16.41|0.037|



### Large measurements

|Workload / DOF|Method|n|Iterations|Setup ms|PCG ms|Solve ms|Wall s [min-max]|Peak MiB|Precond. MiB|
|---|---|---:|---:|---:|---:|---:|---:|---:|---:|
|elastic-large-32 / 107811|jacobi|5|32|0.642|381.519|1642.787|10.764 [10.533-10.932]|485.08|0.823|
|elastic-large-32 / 107811|block-jacobi|5|142|32.879|1916.281|3183.987|12.476 [12.093-12.626]|487.85|3.290|
|elastic-large-32 / 107811|ic0|5|116|651.564|3214.674|5114.020|14.209 [13.993-14.635]|530.51|45.843|
|elastic-large-43 / 255552||0|resource skip / failed||||||
|elastic-large-54 / 499125||0|resource skip / failed||||||
|elastic-large-69 / 1029000||0|resource skip / failed||||||
|thermal-large-46 / 103823|jacobi|3|229|0.646|997.898|1555.052|49.275 [46.012-709.052]|266.86|0.792|
|thermal-large-46 / 103823|block-jacobi -> jacobi (fallback)|3|229|0.915|978.767|1634.452|48.751 [44.811-51.156]|266.89|0.792|
|thermal-large-46 / 103823|ic0|3|85|20.375|679.960|1316.127|48.503 [47.934-59.545]|271.08|4.923|
|thermal-large-62 / 250047|jacobi|1|288|1.844|3083.251|4633.377|133.860 [133.860-133.860]|642.66|1.908|



### Diagnostic measurements

|Workload / DOF|Method|n|Iterations|Setup ms|PCG ms|Solve ms|Wall s [min-max]|Peak MiB|Precond. MiB|
|---|---|---:|---:|---:|---:|---:|---:|---:|---:|
|diagnostic-elastic-8 / 2187|jacobi / 1 threads|1|8|0.059|3.837|15.992|0.678 [0.678-0.678]|13.89|0.017|
|diagnostic-elastic-8 / 2187|jacobi / 2 threads|1|8|0.041|3.966|16.004|0.258 [0.258-0.258]|14.50|0.017|
|diagnostic-elastic-8 / 2187|block-jacobi / 1 threads|1|41|0.431|41.104|57.448|0.507 [0.507-0.507]|13.96|0.067|
|diagnostic-elastic-8 / 2187|block-jacobi / 2 threads|1|41|0.387|21.599|35.925|0.306 [0.306-0.306]|14.27|0.067|
|diagnostic-elastic-8 / 2187|ic0 / 1 threads|1|32|8.637|20.867|42.810|0.299 [0.299-0.299]|13.92|0.705|
|diagnostic-elastic-8 / 2187|ic0 / 2 threads|1|32|10.720|19.581|43.983|0.248 [0.248-0.248]|14.09|0.705|
|diagnostic-conduction-8 / 729|jacobi / 1 threads|1|48|0.004|3.408|6.298|0.262 [0.262-0.262]|6.03|0.006|
|diagnostic-conduction-8 / 729|jacobi / 2 threads|1|48|0.011|2.052|4.130|0.280 [0.280-0.280]|6.10|0.006|
|diagnostic-conduction-8 / 729|ic0 / 1 threads|1|19|0.102|1.024|2.855|0.242 [0.242-0.242]|6.05|0.028|
|diagnostic-conduction-8 / 729|ic0 / 2 threads|1|19|0.131|1.334|3.848|0.256 [0.256-0.256]|6.11|0.028|
|diagnostic-conduction-16 / 4913|jacobi / 1 threads|1|91|0.040|24.413|37.243|1.810 [1.810-1.810]|16.31|0.037|
|diagnostic-conduction-16 / 4913|jacobi / 2 threads|1|91|0.030|16.111|29.095|1.082 [1.082-1.082]|16.16|0.037|
|diagnostic-conduction-16 / 4913|ic0 / 1 threads|1|33|0.376|8.514|19.473|0.955 [0.955-0.955]|16.37|0.215|
|diagnostic-conduction-16 / 4913|ic0 / 2 threads|1|33|0.443|8.128|19.982|0.919 [0.919-0.919]|16.40|0.215|

