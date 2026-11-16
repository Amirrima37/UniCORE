# HPC 2.3 - sparse solver algorithms and measured limits

## Scope and outcome

**Large benchmark campaign stopped by user request; completed data and implementation preserved.** This milestone adds explicit, validated choices of scalar Jacobi, structural nodal block Jacobi and IC(0), with diagnostics and failure handling. Deterministic row-owned assembly and `--assembly serial` remain intact. Existing jobs still select Jacobi with the original numerical tolerances. `auto` deliberately selects Jacobi: the measured FEM cases do not support a universally faster advanced preconditioner.

These algorithms are available for actual structural and thermal solves, including thermal Newton tangents. Fewer iterations are not treated as a speedup. All tables below include setup and full process timings, slower cases, memory and resource skips. This host remains shared and externally loaded; these measurements cannot establish portable speedups or resolution of the HPC 2.2 absolute-time discrepancy.

## Existing solver analysis and changes

The solver assembles per-row hash maps, then sorts each row into contiguous FP64 CSR (`size_t` offsets, 32-bit column indices, double coefficients). The original full matrix is retained for prescribed-value elimination and reaction recovery. CSR creation and the original hash matrix therefore overlap in memory. Each CPU matvec exclusively owns an output row and skips constrained rows/columns. OpenMP activates at 20,000 rows with static scheduling. The redundant zero-fill of `ap` was removed because the backend writes every output row.

Dot products and vector updates remain serial, in their original accumulation order. We did not introduce nondeterministic OpenMP reductions or claim vector scalability improvements. PCG vectors are allocated once per solve; preconditioner application allocates no iteration-local storage. IC triangular substitutions are serial, which limits scalability even when iteration counts improve. Preconditioners are rebuilt on every solve, including each thermal step/Newton tangent; there is no unverified reuse across changed matrices.

The free/free matrix is now checked for finite entries, positive diagonals, and numerical symmetry before PCG/preconditioner setup. Symmetry uses `1e-12 * max(|a_ij|, |a_ji|, sqrt(a_ii)*sqrt(a_jj))`; a missing reverse entry is treated as zero. Prescribed couplings are RHS terms rather than part of the free operator. The symmetry pass has a measured cost, included in CSR/solve timing and separately reported. Positive diagonals and symmetry are necessary conditions, **not a proof of positive definiteness**. Physics validation, factor pivots and positive PCG curvature provide further safeguards; no complete sparse Cholesky certification or indefinite-system solver is claimed.

Previously an exhausted 20,000-iteration loop could pass the looser final residual check. Exhaustion and nonfinite recursive residuals now fail explicitly. PCG also rejects nonpositive/nonfinite `r^T M^-1 r` and `p^T A p`; singular or indefinite breakdown is not silently accepted. Cancellation propagates through validation, factor construction, assembly and the iteration loop.

## Algorithms and applicability

- **Jacobi:** divide by the positive free diagonal; prescribed rows use identity. This remains the backward-compatible default.
- **Block Jacobi:** factor each node's 3-by-3 Cartesian displacement block with dense Cholesky. Couplings to prescribed components are removed and those components use identity. Apply with forward/back substitution, without explicitly inverting blocks. This is a suitable structural nodal block, not a bending/coarse-space correction. Thermal systems have one scalar per node: requesting block Jacobi records `BLOCK_STRUCTURE_UNAVAILABLE` and uses Jacobi rather than inventing arbitrary three-temperature blocks.
- **IC(0):** construct an unshifted incomplete Cholesky factor in natural DOF order, on the original numerically nonzero lower pattern of the constrained free system. Sorted-row intersections compute updates without fill; forward and transpose backward substitution apply `M^-1`, where `M = L L^T`. Exact-zero assembled keys are omitted from the factor pattern. Factors use FP64 values, 32-bit columns and `size_t` offsets. There is no drop-tolerance tuning, reordering, diagonal shift, level scheduling or global dense factor.
- **Fallback:** a nonpositive/nonfinite block or IC pivot releases partial factor storage and records `BLOCK_INVALID_PIVOT` / `IC0_INVALID_PIVOT`, then uses Jacobi. IC(0) can break down even for an SPD matrix; a signed-cycle SPD test explicitly exercises this case. Fallback does not certify an indefinite matrix: PCG curvature and convergence checks still apply. Allocation failures and cancellation are not disguised as successful solves.
- **Automatic:** the conservative policy chooses Jacobi. Block/IC are explicit opt-in choices until broader measured workloads justify a dependable selection rule. No universal cutoff or claim of automatic optimality is made.

Mathematical background follows [Netlib's Templates for the Solution of Linear Systems](https://www.netlib.org/templates/templates.html), particularly PCG and incomplete factorizations. AMG remains a future option if refinement studies demonstrate a need for a coarse space; no external library or GPU dependency was added.

## Configuration and convergence

Old `UNICORE_JOB 1` inputs remain valid unchanged. Optional trailing configuration:

```text
SOLVER ic0 20000 1e-10 1e-10
```

Fields are preconditioner, maximum iterations, relative tolerance and absolute tolerance. Supported names are `auto`, `jacobi`, `block-jacobi`, `ic0`. CLI overrides the corresponding job values:

```powershell
bin/unicore_solver.exe --job model.ucjob --output output --threads 4 --memory-mb 1024 --assembly row-owned --preconditioner ic0 --max-iterations 20000 --relative-tolerance 1e-10 --absolute-tolerance 1e-10
```

Default stopping threshold is `max(rtol * ||b_free - A_free,fixed*x_fixed||_2, atol)`. Both tolerances default to `1e-10`, exactly reproducing the former `1e-10 * max(norm, 1)` threshold; the limit remains 20,000. Negative/nonfinite tolerances, two zero tolerances, invalid methods and nonpositive limits are rejected. These are recursive-residual stopping tolerances. The solver independently recomputes the physical free-row residual using the original CSR and retains the existing final normalized acceptance ceiling `1e-7`; it does not silently tighten that legacy ceiling. The reported legacy `relative_residual` uses `max(rhs_norm,1)` in the denominator. `absolute_linear_residual` is also exposed so small-load cases can be assessed without assuming that normalized value is a conventional relative error.

`configuration.json` records requested method, limit and tolerances at precision 17. Result fields include selected method, fallback reason, preconditioner bytes, setup/apply initialization time, iteration time, symmetry time and absolute linear residual. Structural legacy phase fields remain. Thermal setup/iteration/symmetry times sum over all linear solves; reported preconditioner memory is the maximum live factor size across them and absolute residual describes the last linear solve. Preconditioner time includes construction and initial application. Factor memory counts vector capacities, including its diagonal, not total solver or allocator overhead. Working-set peak is separately measured for the entire process. No new acceptance threshold is inferred from benchmark accuracy checks.

## FEM workloads and measurement method

`tests/benchmark_hpc23.py` generates real HEX8 elasticity and six-TET4-per-cell conduction jobs. It launches independent standalone processes at four threads, all standard output arrays enabled and durable publication retained. Method order reverses each repetition. Small cases use three repetitions per method. The 107,811-DOF large structural case uses five, and other feasible large cases use three. Input/executable hashes, CPU time, output diagnostics and peak working set accompany raw samples. Generation, Python JSON parsing and cross-result comparisons are outside process wall timing. This is a warm-filesystem study, without affinity, frequency or cache-flush control. Builds/tests run separately from performance collection.

Workloads:

- Uniform unit-cube axial elasticity, E=1000, nu=0, full fixed x=0 face, consistent unit traction at x=1. The exact field is `u_x=0.001*x`, other displacements zero. Refinement levels include 8, 16 and larger cell counts.
- A 12:1 cantilever, 48-by-4-by-4 HEX8 cells, nu=0.3, end traction in y. This is actual bending; the comparison uses independently converged Jacobi fields and equilibrium residuals, without pretending an Euler-beam formula is exact for this 3D clamped model.
- Heterogeneous 16-by-8-by-8 elasticity with a 10,000:1 modulus jump and nu=0.3. Accuracy is assessed against the Jacobi FEM solution, not a homogeneous analytical displacement.
- TET4 conduction with a 1,000,000:1 conductivity jump halfway along x, prescribed 300/400 K end faces and adiabatic remaining faces. The piecewise-linear exact temperature uses the series thermal resistance, providing an analytical field check in addition to residuals and cross-method agreement.

Global memory is checked before generating large jobs. Initial estimates are conservative; after successful large runs, the largest observed bytes/DOF for that physics is scaled by 1.25 (initial large pass used 1.5; the revised harness uses that smaller conservative multiplier; additional large attempts were not launched while retaining the 25% available-RAM reserve) for subsequent mesh estimates. A case is skipped if its estimate exceeds 75% of currently available RAM. This avoids relying on a large pagefile to report an apparent engineering-model success. Skips are resource limitations, **not completed scalability tests**. The existing standalone input preflight also conservatively budgets 1024 bytes/node plus 4096 bytes/element and refuses a requested budget above physical RAM; this can limit large tetrahedral jobs independently of estimated live storage.

An initial harness error allocated only 420 MiB to a known approximately 485 MiB structural solve. The resulting `MEMORY_BUDGET_EXCEEDED` failures are retained in `hpc23-large-budget-failures.json`; they are not solver breakdowns or timing samples. The harness now budgets the larger of preflight allowance, 1 GiB and 1.25 times estimated process memory. The earlier pilot small-case report is retained in `hpc23-small-pilot.json`; its preliminary auto policy selected structural blocks and was replaced after those timings showed that this was not consistently faster.

## Measurements

The following tables are generated from retained JSON by `tests/summarize_hpc23.py`. Times are medians; wall ranges include every successful sample. Setup includes initial preconditioner application, solve includes CSR/symmetry/constraints/setup/iterations/reactions and cleanup, and wall includes parsing, assembly, postprocessing, serialization and process lifetime. These are nested quantities, not additive independent timers. Whole-process peak includes assembly/hash matrix, CSR, vectors, fields, factors and runtime. Preconditioner memory is only its live vector storage. The historical executable has no factor-memory counter or comparable separate setup timer, so zeros in those baseline-only columns mean unavailable instrumentation.

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



## Validation and interpretation

The large campaign was stopped at the user's request. **No automatic large-case continuation is scheduled.** Twenty-five completed large measurements remain in `hpc23-large.json` and the immutable stop snapshot `hpc23-large-stopped.json`. The in-flight 250,047-node thermal block request exited cooperatively with `Cancelled`; it is not counted as a completed result. Its partial files remain in `.tools/hpc23-bench/thermal-large-62/block-jacobi-0`. `hpc23-stop.json` records the stop. Structural 255,552 / 499,125 / 1,029,000 DOF cases were memory-based skips. Thermal 250,047 DOF has only one completed Jacobi sample; 500,000 and million-DOF thermal cases were not completed. No scalability conclusion at those sizes is claimed.

### The 709-second outlier and thread uncertainty

The retained 103,823-node Jacobi sample took **709.052 s wall but only 46.766 s process CPU** (0.066 average busy cores, approximately 0.55% of this 12-logical-processor machine). Parsing/model construction consumed **700.745 s**, including **696.875 s** in the nested cell/material input-construction interval; CSR/setup/PCG/reactions took only **1.555 s**, with the same **229 iterations** and **9.045e-11** residual as the much shorter samples. This is evidence of a long off-CPU delay during preparation, not an iteration explosion. Counters do not identify whether I/O blocking, scheduling, process suspension or other host interference caused that delay. No sampling stack or wait trace was captured; the root cause of that stall remains unresolved. `hpc23-bottleneck.json` preserves the evidence. The 709-second sample remains in the range and raw data, not excluded as an inconvenient result.

Even the completed 250,047-node run spends about **111 s parsing/model construction out of 134 s wall**, versus **4.63 s** in the linear solve. Text conversion, connectivity/material construction and per-element allocation are interleaved in this interval; the nested timer does not isolate allocator cost. These results identify preparation as the principal end-to-end bottleneck, but do not establish which operation or external wait is responsible. Increasing preconditioner sophistication cannot remove that preparation cost. Thermal `serialization_ms=0` is an unmeasured legacy placeholder, not a measurement of free output; wall time includes serialization/publication and phase remainders.

The old large campaign used four threads throughout, so it cannot explain the reported one-versus-two-thread slowdown. A new bounded pass tested actual 729/4,913-node conduction and 2,187-DOF elasticity at one and two threads, once per configuration. All **14** cases completed below their **10 s** case cap and **60 s** campaign cap. The 729-node conduction cases were slightly slower with two threads (Jacobi 0.262 -> 0.280 s; IC 0.242 -> 0.256 s); the 4,913-node cases were faster in that pass, with substantial differences in serial preparation time as well. These single samples neither reproduce nor disprove a severe thread regression on larger systems. Matvec OpenMP is inactive below 20,000 DOF; these small tests primarily examine assembly overhead and shared-host variability. No general thread speedup is inferred.

`hpc23-diagnostic.json` records phase timings, per-process CPU time, average busy cores, machine utilization percentage, and sampled process CPU/progress state during each case. For example, the 4,913-node Jacobi runs used 1.484/1.031 CPU seconds over 1.810/1.082 s wall at one/two threads. Samples during `Validating` show CPU advancing roughly one core at a time; that is consistent with serial input work. It does not explain the separate off-CPU 709-second stall.

### Bounded benchmark policy

The harness now defaults to small diagnostics, a **10-second hard process wall cap**, a **90-second overall campaign cap**, and a **15,000-DOF guard**. The completed diagnostic pass explicitly used a 60-second overall cap. Runs are sequential; a Windows named mutex rejects another concurrent instance of this harness. Each case gets a fresh output directory, and an existing report path is refused to protect completed data. Cancellation is requested shortly before the deadline, with bounded forced termination/reaping if necessary. Phase/CPU samples and exit state are retained on timeout. A two-thread run is capped early if it exceeds 1.75 times its matching one-thread baseline (with a one-second noise floor). An exact-configuration ledger records pathological cases; expensive completed large configurations are also excluded from automatic reruns. A timeout while still validating blocks other variants of the same preparation workload. Large suites require explicit opt-in and a raised DOF guard and are **not authorized for resumption in this investigation**.

Thermal Block Jacobi is explicitly labeled `block-jacobi -> jacobi (fallback)` in tables and is never counted as successful block preconditioning. New thermal diagnostics skip this already-known scalar fallback rather than repeatedly timing Jacobi under a block label.

The original parser did not observe cancellation until the post-parse monitor started. It now checks the request every 16,384 input numbers and every MiB of fingerprint input. A small-model cancellation test returned exit code 3 in **0.077 s** after the request (`hpc23-cancellation.json`). This is a targeted responsiveness fix, not a claimed parsing-speed optimization.

### Numerical validation and limitations

Native preconditioner and deterministic-assembly tests passed in release OpenMP, debug OpenMP and no-OpenMP builds. Tests cover prescribed values, zero RHS, asymmetry, indefinite curvature, iteration exhaustion, cancellation, invalid options and IC(0) pivot failure on an SPD signed-cycle matrix with explicit Jacobi fallback. Structural/HEX8 tests, radiation analytical/tangent/equilibrium/transient tests with Jacobi and advanced requests, CLI validation, debug/release configuration checks, and checkpoint/restart plus incompatible-model rejection passed. Advanced checkpoint cases and job-trailer/CLI precedence passed. No pre-existing assertion or tolerance was weakened.

The first new high-contrast flux-equivalence assertion failed: default Jacobi and IC fields differed by 0.1527 W/m2 in one eight-cell-per-axis case. This failure is retained as a limitation, not dismissed by loosening its field-comparison bound. Default global residual scaling is dominated by the high-conductivity prescribed-temperature RHS; a small temperature error can be magnified by conductivity in flux recovery. On the 16-cell case, default maximum analytical flux errors were **0.424 W/m2 Jacobi** and **0.790 W/m2 IC**, against approximately 200 W/m2 exact flux. Consequently default settings are not a promise of tight heat-flux accuracy for a million-to-one contrast.

Validation was repeated with **explicit** `rtol=atol=1e-13`, leaving runtime defaults and default benchmark results unchanged. The same flux-agreement bound then passed; maximum analytical flux errors on that case decreased to **0.000298 / 0.000547 W/m2** for Jacobi/IC. `hpc23-flux-accuracy.json` reports both default and tighter outcomes. `hpc23-numerical-validation.json` records which comparisons use explicit tighter tolerances; structural comparisons use defaults. This is evidence of a stopping-tolerance/conditioning sensitivity, not exact equivalence between different preconditioners. Users requiring accurate high-contrast fluxes must check field convergence as well as the reported residual.

Default legacy steady-thermal and transient-radiation fields still match the saved HPC 2.1 executable exactly at 1/2/4/6/8/12 threads (`hpc23-thermal-equivalence.json`). Serial/row-owned assembly fallback equivalence also passes (`hpc23-fallback-equivalence.json`). Release/debug/no-OpenMP actual HEX8 manufactured fields pass for every supported method. Native and CLI logs are in `hpc23-validation.log`; the initial new flux assertion failure and its diagnosis above remain documented.

Both GDExtension configurations were rebuilt. Final Godot results are **53/54 passed**, zero unexpected script errors. The known app-shell access violation **3221225477 / 0xC0000005** persists; `hpc23-final-regression.json` and `hpc23-app-shell.log` retain it. It is not fixed or suppressed.

### Performance conclusions

The five-pair baseline comparison has a **9.855 s HPC 2.2 Jacobi median versus 10.420 s HPC 2.3 Jacobi median** with exact default structural fields. The new symmetry pass costs approximately **0.768 s median** on that workload and is included in solve time. This is a documented robustness cost and an observed end-to-end regression in this pass; no default solver speedup is claimed. It remains a candidate for measured optimization, not a reason to silently omit matrix validation.

At 107,811 structural DOF, Jacobi is preferable on the tested axial load: 32 iterations and 10.764 s median, versus block Jacobi 142 / 12.476 s and IC 116 / 14.209 s. IC memory is about 530 MiB peak versus approximately 485 MiB for Jacobi. The simple axial field happens to converge especially quickly with diagonal scaling; advanced preconditioning can destroy that favorable iteration pattern. The heterogeneous and bending examples also do not establish a general complete-solver improvement.

For the tested large high-contrast conduction case, IC reduces 229 iterations to 85, but complete-wall medians remain close and externally noisy (49.275 s Jacobi, 48.503 s IC, with the 709-second Jacobi outlier retained). Preparation dominates; these results do not justify automatic IC selection or a portable speedup claim. `auto` and the default therefore remain Jacobi. Block and IC are completed, tested options with explicit applicability/fallback reporting, rather than unconditionally faster replacements. The large campaign remains stopped pending a focused investigation of input conversion/construction and off-CPU stalls under bounded profiling.


## Reproduction

Run from the repository root on the documented Windows/MinGW host. Compiler path is `C:/Qt/Tools/mingw1310_64/bin/x86_64-w64-mingw32-g++.exe`, GCC 13.1.0; release flags remain C++17, `-O2 -static -fopenmp -ffp-contract=off -municode`. CPU is the Ryzen 5 7535HS, 6 cores/12 logical processors. Use the installed Python interpreter directly if the Windows `python` alias fails.

```powershell
# No large campaign is resumed. Choose a fresh report name.
python tests/benchmark_hpc23.py --suite diagnostic --case-budget-s 10 --campaign-budget-s 60 --report docs/hpc-optimization/hpc23-diagnostic-next.json
python tests/summarize_hpc23.py
# Run validation separately from benchmarks; existing small fixtures are preserved:
powershell -ExecutionPolicy Bypass -File tests/run_hpc23_validation.ps1 -ReuseRelease
# Optional separate builds:
powershell -ExecutionPolicy Bypass -File native/extreme/build.ps1 -Debug
powershell -ExecutionPolicy Bypass -File native/extreme/build.ps1 -NoOpenMP
```

The baseline configuration needs the preserved `.tools/unicore_solver_hpc23_baseline.exe`, saved from HPC 2.2 before this build, and the existing `.tools/extreme-axial/model.ucjob` fixture. The new benchmark generator is self-contained. Validation reads generated small benchmark fixtures/results, and the historical thermal-equivalence check needs the earlier HPC 2.1 reference executable and fixtures. The bounded harness refuses existing report paths; other historical helpers may overwrite their reports, so use fresh paths. The current summary includes the named retained diagnostic report; a differently named future report must be selected explicitly in the summarizer. Standalone `build.ps1 -Debug` and `build.ps1 -NoOpenMP` build separate executables. CMake contains the added native preconditioner test target, but this host's direct compiler builds are the verified path.

Relevant code: `native/src/math/preconditioner.hpp`, `sparse_pcg.hpp`, structural/thermal kernel headers, standalone `main.cpp` and `build.ps1`, native preconditioner tests, benchmark/option/numerical tests and validation script. Existing unrelated edits were preserved.
