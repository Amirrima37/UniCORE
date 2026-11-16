# HPC optimization work log (partial milestone)



This is an incomplete milestone. No assembly scalability, new preconditioner, job schema, UI, visualization or million-DOF improvement is claimed.



## Reproduction



Run `powershell -ExecutionPolicy Bypass -File native/extreme/build.ps1`, then `python tests/benchmark_extreme_axial.py` and `python tests/benchmark_extreme_thermal.py`. These scripts overwrite their historical Extreme report files; snapshots for this investigation are retained here. Debug build also succeeded with `-Debug`.



Hardware is recorded in hardware.json. Build uses MinGW GCC at C:/Qt/Tools/mingw1310_64, C++17, -O2, OpenMP, -ffp-contract=off, static runtime.



## Initial measurements



baseline-fem.json records real HEX8 axial manufactured displacement FEM at 1,029 through 107,811 DOF with 1/2/4 threads. Largest model: one thread 6.942 s, four threads 4.848 s; peak working set approximately 471 MiB. Assembly: 1451/916 ms; solve: 1416/593 ms; preparation: 1758/1740 ms. Preparation and assembly are material costs; these coarse phase timers do not separate sparsity, numbering and integration. No native sampling profiler, CPU utilization or process CPU-time capture was completed.



baseline-thermal.json records a 1,331-node, 6,000-TET4 steady manufactured conduction field. Maximum temperature error 3.08e-8 K, flux error 1.89e-7, 52 iterations.



## Implemented change



native/src/math/csr_backend.hpp accumulates each sparse product row in a local scalar and writes the result once. This reduces output stores and possible alias-related reloads. Row order, constraints, FP64 and parallel row ownership remain unchanged. Existing Jacobi PCG remains the only preconditioner. No altered convergence thresholds.



Exploratory after-fem.json and after-thermal.json overlap regression activity and show contention. They are not evidence of speedup. No measured causal performance gain is established. A clean follow-up FEM sample is stored separately when available; repeated controlled A/B testing remains necessary.



Largest structural sample retained 32 iterations, residual 9.052e-15 and maximum displacement error 5.94e-17 m across threads, identical to baseline. Thermal errors and iterations also remained identical.



## Verification and limitations



Release and debug standalone builds succeeded. Python CLI validation and transient checkpoint/restart rejection tests passed. Extended Godot regression output is preserved in regression-results.json; application-shell access violation 0xC0000005 reproduced. Some runner entries report script_error despite passed=true: inspect these flags rather than assuming a fully clean run. No crash stack was collected and no tests were suppressed. Godot binaries were not rebuilt for this header change, so those suites describe existing application behavior, not updated GDExtension validation.



No graphical verification or screenshots were completed. No frame-time measurements, binary parser, memory budget improvement, alternate assembly implementation or large-scale study above 107,811 FEM DOF was completed. Existing working-tree edits were preserved.



Files changed by this investigation: native/src/math/csr_backend.hpp; this report and adjacent measurement JSON files. Existing benchmark scripts also regenerated docs/extreme-mode/fem-benchmark.json and thermal-benchmark.json. The full requested milestone remains outstanding.



# HPC 2.1 ? deterministic parallel FEM scatter



This run implements parallel structural HEX8/TET4 and thermal TET4 volume assembly in the shared headers. It demonstrates a measured assembly improvement in a paired native benchmark. It does **not** establish an end-to-end solver speedup. The earlier work log above is preserved.



## Validation reliability and builds



Standalone release/debug and GDExtension template_debug/template_release were rebuilt using the existing PowerShell build scripts and MinGW GCC 13.1.0. Standalone release uses -O2 -fopenmp -ffp-contract=off; debug uses -O0 -g. Existing GDExtension build_direct.ps1 does not enable OpenMP, so that build exercises the serial fallback. No compiler/tolerance/physics change was introduced. Hardware remains Ryzen 5 7535HS, 6 cores / 12 logical processors; hardware.json records the host.



The three script-error entries are intentional anonymous invalid-script compilations in diagnostic_logger (1), self_repair (5), and validator (1). Their source tests assert rejection, their manifest declares exact expected counts, and each prints zero failed assertions. The existing runner already excluded only exact-count anonymous parse diagnostics with a successful test summary. Its JSON nevertheless used raw output for script_error. This run makes script_error describe unexpected diagnostics, adds expected_script_errors and preserves raw_script_error. Raw logs remain intact; unexpected diagnostics still fail. No manifest allowance or assertion was weakened.



Both baseline and final extended runs report 53/54 passed and zero unexpected script errors. The app-shell test still fails with 3221225477 (0xC0000005). Logs and JSON are retained; no crash cause or repair is claimed. Final tests used rebuilt GDExtension binaries. Numerical equivalence, advanced loads, thermal radiation and import suites passed within the manifest.



## Bottlenecks and approach evaluation



Previously, each 256-cell batch integrated in parallel, then one thread scattered every entry into per-row unordered_maps. Sparse pattern creation is dynamic: key insertion/allocation and numerical addition are fused in that scatter. CSR sorting/finalization occurs serially inside PCG; prescribed displacement elimination is another serial pass there. DOFs are already global Cartesian node indices (3 per structural node, 1 per thermal node), with no independent numbering operation. Cell preparation and rigid-mode validation remain serial.



Considered approaches:



* Full thread-local triplets and deterministic reduction: 32768 HEX8 cells generate 18,874,368 scalar contributions. A 16-byte (row,column,value) record alone costs 288 MiB before sorting scratch, final CSR, and solver vectors. This is feasible on this host, but unattractive against an existing approximately 471 MiB process. It was evaluated by storage/work estimates, **not timed**.

* Precomputed element-to-CSR mapping: approximately 72 MiB for 32-bit offsets or 144 MiB for 64-bit offsets on this model, plus construction and write-conflict management. It requires changes to the hash-map/thermal Newton matrix interface. It was evaluated architecturally, **not implemented or timed**.

* Selected bounded node ownership: integrate 2048 cells, sort only their node occurrences by (global node, element index, local node), then give each global node's rows to one task. No global triplet array, atomics or concurrent writes to the same unordered_map. The paired benchmark below times this against the old 256-cell serial scatter.



Every row retains element accumulation order. Structural rows include constrained DOFs, preserving the original reaction calculation and prescribed-value elimination. Material integration and element formulas are untouched. Thermal force/capacity use the same ownership; gradient storage and total-input reduction remain deterministic. Convection/radiation surface assembly and Newton tangents remain unchanged and serial. OpenMP parallel_for retains cooperative cancellation, exception propagation and the no-OpenMP serial fallback.



The larger batch bounds local structural matrices to roughly 12 MiB plus vector overhead and less than 1 MiB grouping data. Storage is independent of total model size. No per-thread copy of the global matrix is allocated. Adjacent row objects can still share cache lines, and allocator contention remains possible.



## Paired native assembly measurement



Actual 32768-HEX8 unit-cube FEM, 107811 DOF, E=1000 Pa, nu=0. Three repetitions per method/thread count; method order alternates by repetition. Each run integrates actual elements and constructs the full matrix. A retained reference matrix is compared entry-for-entry after the timed assembly; **all 36 assembled matrices compare exactly**. Total includes matrix initialization and local-buffer lifetimes; integration and scatter are timed separately. Scatter includes grouping/sorting and dynamic sparsity insertion. The retained reference adds memory/cache pressure to both methods, so absolute times are not directly comparable to standalone times. Samples were collected without our builds/tests running concurrently, but external load/frequency were not controlled.



Milliseconds, median [minimum?maximum]:



|Threads|Old assembly|Row-owned assembly|Old scatter median|Row-owned scatter median|Ratio of assembly medians|

|---:|---:|---:|---:|---:|---:|

|1|7266 [6042?7532]|6685 [4799?7975]|2812|2300|1.09x|

|2|4462 [4453?9844]|3235 [3046?5984]|2345|1142|1.38x|

|4|4280 [4177?8674]|2166 [2083?4286]|2607|761|1.98x|

|6|3971 [3543?6919]|1979 [1755?3070]|2702|739|2.01x|

|8|3422 [3388?4805]|1527 [1493?2856]|2353|583|2.24x|

|12|4322 [2818?4786]|1413 [1391?1813]|3129|485|3.06x|



At four threads the ratio is 1.98x for assembly and 3.43x for scatter. This includes both row ownership and increasing batch size; it does not isolate their individual contributions. Single-thread ranges overlap widely, so no robust one-thread improvement is claimed. See hpc21-paired.csv and hpc21-summary.json for integration timings and all ranges. Process accounting for the whole paired executable: 217.974 s wall, 243.563 s CPU, 1.117 average busy cores (about 9.3% of 12 logical processors). This includes serial comparisons, allocation/deallocation, and all requested thread counts; it is not per-phase CPU utilization or rendering FPS.



## End-to-end measurements and memory



The previous HPC 2.0 sample was 6.94 s / 4.85 s at 1 / 4 threads, approximately 471 MiB. This run's repeated standalone measurements follow (median of three; full ranges retained in JSON):



|Threads|Before wall s|After wall s|Before assembly ms|After assembly ms|Before solve ms|After solve ms|Before peak MiB|After peak MiB|

|---:|---:|---:|---:|---:|---:|---:|---:|---:|

|1|7.021|17.934|1656|4760|1067|1751|470.50|482.19|

|2|5.882|13.451|1109|2633|826|1301|470.44|483.80|

|4|5.278|11.093|1087|1496|611|921|470.60|484.23|

|6|4.962|9.554|982|1160|533|842|470.71|484.39|

|8|4.989|10.287|948|959|528|879|470.65|486.53|

|12|5.838|11.300|1326|962|719|922|471.01|487.24|



These standalone runs became slower overall. Unchanged loading/preparation rose from roughly 1.8 s to 5?7 s; the cause was not established. This is a confound, not evidence that assembly alone explains total slowdown. Do not use these files to claim an application speedup. Peak memory overhead is approximately 12?16 MiB depending on thread count, consistent with the larger local batch and allocator overhead; sampled native working-set counters are not exact allocation accounting.



A four-thread diagnostic sample in hpc21-phase-sample.json separates integration, grouped scatter, CSR finalization and constraint application. CSR/constraint clocks are also exposed in structural standalone results; solve_ms still includes those phases. Sparse pattern insertion remains fused with scatter and is **not independently timed**. Grouping/sorting is likewise included in scatter. A native sampling profiler and independent pattern-allocation profile were not completed.



## Numerical and regression evidence



* 107811-DOF baseline executable versus optimized results: exact equality of displacement, reaction, stress, strain and von Mises arrays. All thread benchmark runs have 32 iterations, residual 9.051919247460844e-15 and axial displacement error 5.930585883495709e-17 m. Exact equality is observed here, not promised across compilers/architectures.

* Native stress test: 60 mixed heterogeneous HEX8/TET4 matrix assemblies across 1/2/4/6/8/12 threads, exact serial-reference equality. Separate heterogeneous thermal TET4 stiffness/source/capacity comparisons pass at those thread counts. Cancellation is tested. Ownership correctness is additionally supported by exclusive row writes; no ThreadSanitizer run is claimed on this Windows toolchain.

* Steady 6000-TET4 conduction and transient nonlinear-radiation fixtures compare exactly against the saved pre-change executable at all six thread counts, including temperatures, flux/history, reactions, radiation power, energy balance, residual and iterations. See hpc21-thermal-equivalence.json. The thermal manufactured-field accuracy remains approximately 3.08e-8 K / 1.89e-7 W/m? as previously recorded.

* OpenMP release and debug native stress tests and a no-OpenMP release build pass (including the heterogeneous thermal matrix/source/capacity assertions in all three builds). Existing structural affine patch/rigid-mode/material tests and radiation analytical/tangent/equilibrium/transient convergence checks pass.

* CLI validation, checkpoint/restart, incompatible-model rejection and debug/release standalone execution tests pass. Final extended Godot report is hpc21-final-regression.json. Application-shell diagnostics are preserved separately. No assertions or solver tolerances were changed.



## Reproduction



From the repository root in PowerShell (compiler path is host-specific):



```powershell

powershell -ExecutionPolicy Bypass -File native/extreme/build.ps1

powershell -ExecutionPolicy Bypass -File native/extreme/build.ps1 -Debug

powershell -ExecutionPolicy Bypass -File native/build_direct.ps1 -Target template_debug

powershell -ExecutionPolicy Bypass -File native/build_direct.ps1 -Target template_release

$cxx='C:/Qt/Tools/mingw1310_64/bin/x86_64-w64-mingw32-g++.exe'

& $cxx -std=c++17 -O2 -fopenmp -ffp-contract=off -static -Inative/src native/extreme/assembly_benchmark.cpp -o .tools/assembly_benchmark.exe

python tests/run_hpc_measured.py docs/hpc-optimization/hpc21-paired .tools/assembly_benchmark.exe

python tests/benchmark_hpc_assembly.py docs/hpc-optimization/hpc21-after.json

& $cxx -std=c++17 -O2 -fopenmp -ffp-contract=off -static -Inative/src native/tests/parallel_assembly_test.cpp -o .tools/parallel_assembly_test.exe

.tools/parallel_assembly_test.exe

python tests/test_extreme_cli.py

python tests/test_extreme_checkpoint.py

python tests/test_extreme_configurations.py

python native/run_regressions.py --godot .tools/godot/Godot_v4.0-stable_win64_console.exe --all-suites --output .tools/hpc21-final

```



Run benchmarks separately from builds/tests. assembly_benchmark.cpp contains both old and selected assembly algorithms, so the paired comparison does not require historical binaries. For historical whole-solver comparisons, preserve the pre-change executable as .tools/unicore_solver_hpc21_baseline.exe before rebuilding. tests/test_hpc_assembly_equivalence.py additionally requires fixtures produced by benchmark_extreme_thermal.py and test_extreme_checkpoint.py; it fails explicitly if the historical executable/fixtures are missing. The million-DOF and UI work from HPC 2.0 remains out of scope. CMake test/benchmark targets were added but CMake itself was not exercised.



## Modified files in this run



native/run_regressions.py; native/src/math/nodal_scatter.hpp; native/src/math/sparse_pcg.hpp (phase clocks); native/src/kernels/structural_solver.hpp; native/src/kernels/thermal_solver.hpp; native/extreme/main.cpp; native/extreme/assembly_benchmark.cpp; native/extreme/CMakeLists.txt; native/tests/parallel_assembly_test.cpp; tests/benchmark_hpc_assembly.py; tests/run_hpc_measured.py; tests/summarize_hpc_assembly.py; tests/test_hpc_assembly_equivalence.py; this report and adjacent hpc21 measurement/log files. Generated standalone/GDExtension binaries were rebuilt. All prior unrelated working-tree edits were preserved.


# HPC 2.2 — standalone regression investigation

## Finding and status

**The original 5.278 s versus 11.093 s comparison is not a reproducible assembly regression. The absolute historical performance has not been recovered, and its precise environmental cause remains unresolved.** The preserved historical executable now takes 13.461 s median; the preserved HPC 2.1 current executable takes 11.243 s on the same input in alternating runs. Preparation alone now takes 5.3–5.6 s in both executables, versus approximately 1.8 s in the old report. That work precedes assembly. Changing assembly cannot explain that increase.

Running both algorithms inside one newly built executable gives 13.869 s serial versus 11.400 s row-owned. Numerical results match exactly. This supports retaining row ownership for this workload, but **does not establish a portable speedup or explain every second of the original regression**. No speculative numerical optimization, new preconditioner, tolerance change, or physics change was made. The implementation changes are diagnostic timers and an explicit serial fallback. This investigation remains incomplete with respect to recovering the original absolute time and obtaining an idle-host hardware profile.

## Comparability and method

All successful sets below contain five fresh processes per configuration. Order reverses each repetition: A/B, B/A, A/B, B/A, A/B. No builds or regression tests ran concurrently with the measured sets. Model: the existing `.tools/extreme-axial/model.ucjob`, 32,768 HEX8 elements, 107,811 DOF, four OpenMP threads, 1024 MiB budget, all result arrays serialized and published normally to the same filesystem. Input SHA256 is recorded per sample. These are warm-filesystem measurements, without a cold-cache claim. The benchmark itself does not generate the model during timing.

`hpc22-binary-audit.json` records hashes, sizes and embedded GCC identifiers. Both saved executables identify MinGW GCC 13.1.0 and import KERNEL32/msvcrt, with static compiler/OpenMP runtimes. PE build timestamps were 10:35:50 and 10:41:53 on November 11. Historical flags are supported by the HPC 2.1 build log, not independently recoverable from the binary; a complete historical source/build manifest is unavailable. Thus their complete build equivalence cannot be certified. The decisive internal comparison uses **one binary hash**, built with the unchanged release script (`-std=c++17 -municode -static -fopenmp -ffp-contract=off -O2`), switching only assembly strategy/batch size. CPU, input, output policy, executable and flags are thereby shared.

Process times use Windows GetProcessTimes. Internal-set reports additionally retain GetProcessIoCounters and system busy CPU from GetSystemTimes. External wall includes process creation and exit; internal total starts inside `run` and ends before final durable publication and object destruction. Their difference is a combined startup/exit/publication remainder, **not an isolated loader measurement**. All successful runs assert exact displacement, reaction, stress, strain, von Mises, iteration and residual equality within each set. Every run has 32 iterations and residual 9.051919247460844e-15.

## Complete solver measurements

Seconds except memory. Medians and full wall ranges; no slower successful sample was removed. JSON retains every sample and phase.

|Configuration|Wall median [min–max] s|Process CPU s|Average busy cores|Peak working set MiB|
|---|---:|---:|---:|---:|
|Historical saved executable|13.461 [13.067–13.843]|19.047|1.408|470.58|
|HPC 2.1 saved current executable|11.243 [10.993–11.722]|17.875|1.602|484.59|
|Same binary, serial scatter / 256 cells|13.869 [12.530–14.152]|17.984|1.321|470.66|
|Same binary, row-owned / 2048 cells|11.400 [10.712–12.604]|17.312|1.515|484.59|
|Same binary, serial, OMP_WAIT_POLICY=PASSIVE|13.531 [13.412–19.900]|18.234|1.349|470.71|
|Same binary, row-owned, OMP_WAIT_POLICY=PASSIVE|11.704 [11.584–29.703]|17.578|1.493|484.30|

One busy core is 8.33% of this 12-logical-processor host; the default internal samples average approximately 11.0% and 12.6% machine utilization for the solver. These whole-process figures include serial parsing/output and do not measure assembly parallel efficiency. Passive waiting did not improve the median; the slow 29.703 s result is explicitly retained. No wait-policy change was adopted.

## Phase accounting

Internal default-policy medians, milliseconds. These are medians of individual phases and do not sum to the median wall time. Existing assembly/solve/post timers are inclusive; do not add them to their constituent timers.

|Phase|Serial|Row-owned|
|---|---:|---:|
|Preparation, inclusive|5936.414|5977.951|
|Parsing, validation and model construction, inclusive|5863.065|5910.185|
|Cell/material model construction within parsing (nested)|2151.075|2295.173|
|Input fingerprint / restart interval|69.958|66.314|
|Element list preparation and rigid-mode validation|12.738|12.210|
|Empty sparse row container allocation|3.294|3.739|
|Element integration|746.504|669.901|
|Scatter including dynamic pattern insertion/allocation|2295.347|654.966|
|Assembly, inclusive|3064.394|1377.337|
|CSR finalization / sorting / initial vectors|680.488|458.968|
|Constraint elimination|44.743|44.852|
|Initial Jacobi application|0.276|0.308|
|PCG initialization and iterations|471.470|478.596|
|Linear reactions and residual verification|14.408|14.613|
|Solve, inclusive (also includes temporary destruction)|1241.080|1006.570|
|Element field postprocessing|643.564|617.788|
|Field ordering and result serialization, excluding final publication|2000.153|1986.726|

Pattern key creation, allocator calls and numerical additions are fused in `unordered_map::operator[]`; they are not independently timed. Row-owned scatter also includes occurrence grouping/sorting and parallel region overhead. Model input conversion and construction are interleaved; the nested cell-construction timer includes reading connectivity/material values, not pure allocation time. Diagonal extraction/validation for Jacobi remains fused with CSR construction; only the initial diagonal application is separately measured. Subsequent applications are inside PCG. The detailed new output timers are structural diagnostics; thermal correctness is tested separately, not a thermal phase-performance study. Thermal serialization timing is currently an unmeasured zero placeholder and must not be interpreted as free work.

The unaccounted wall remainder includes sparse matrix destruction after the solver returns, buffer lifetimes, monitor activity, status output and durable publication. Neither process startup nor every allocation can be isolated from these measurements. These boundaries are intentionally documented rather than assigning misleading precision.

## Interference, memory and causal limits

GetSystemTimes reports **4.383 other busy cores median** during row-owned internal samples and **5.374** during serial samples. This is substantial uncontrolled host load despite excluding our builds/tests. A separate ten-second user-process CPU snapshot (`hpc22-competing-processes.json`) found CrossDeviceService consuming 8.89 CPU seconds, webviews 6.11 combined and Explorer 3.20, among other activity; system/kernel work is not fully attributed by that snapshot. We did not terminate unrelated applications. Windows reported Balanced power mode, a 1914 MHz CPU clock snapshot (3301 MHz reported maximum), and approximately 2.7 GiB available physical memory out of 15.2 GiB. A single clock reading does not prove thermal/power throttling, and available memory does not establish paging. Sustained frequency, hardware cache-miss counters, heap lock stacks and page-fault traces were not collected.

Two interrupted attempts are retained separately rather than silently discarded: an internal serial run completed in 222.120 s, including 214.059 s preparation; an initial passive serial attempt completed in 327.549 s, including 321.449 s preparation (`hpc22-environment.json`, `hpc22-second-stall.json`). The original harness timed out at 180 s before those eventual completions. They are outside the subsequent complete five-pair sets; the partial passive set is retained in `hpc22-passive-interrupted.json`. The harness now allows 600 s and kills/reaps a timed-out child. These extreme pre-assembly stalls are additional evidence of unstable execution conditions, not assembly timings or a proven diagnosis of their underlying cause.

Peak working-set overhead in the internal default pair is **13.93 MiB**. This is consistent with the bounded larger element buffers and grouping storage. Both methods retain one global hash matrix, without per-thread global copies. For this regular grid both insert approximately 8.214 million scalar keys (including zero contributions); key allocation and rehashing remain potential allocator costs. No allocation-count or allocator-contention trace was obtained. The measured scatter decrease gives no evidence of a dominant allocator-lock regression in this workload, but does not rule one out elsewhere. CSR is also slower after serial scatter; different heap placement/cache locality is plausible, but has not been demonstrated with hardware counters. Process I/O counters record roughly 6.76 MB read and 12.47 MB written per internal run, including input fingerprint reread and full results; I/O operation counts include monitor status activity and are not physical-disk measurements.

The supported conclusion is that the old cross-session comparison conflates a shared pre-assembly slowdown with an algorithm change. Significant competing CPU load is directly measured. Frequency, scheduling, memory pressure and the very long stalls remain unresolved contributors. **No implementation defect causing the reported end-to-end regression was confirmed, so no speculative performance fix is claimed.**

## Fallback and reproduction

`--assembly row-owned` is the standalone default. `--assembly serial` retains parallel element integration but restores 256-cell batches and original-order serial scatter for both structural and thermal volume assembly. It preserves cancellation and rejects invalid option values. The shared diagnostic selector must be configured before solver workers start. Existing callers retain row ownership by default.

For the tested large structural workload, row ownership is preferable on both complete paired sets by median, with about 14 MiB additional memory. Use serial when that memory matters or when a workload-specific complete-solver benchmark favors it. Small structural, steady conduction and transient radiation fixtures have exact fallback equivalence but **no measured speed recommendation**; no universal small-model threshold is inferred.

```powershell
powershell -ExecutionPolicy Bypass -File native/extreme/build.ps1
python tests/investigate_hpc22.py docs/hpc-optimization/hpc22-original-config.json docs/hpc-optimization/hpc22-original.json
python tests/investigate_hpc22.py docs/hpc-optimization/hpc22-internal-config.json docs/hpc-optimization/hpc22-internal.json
$env:OMP_WAIT_POLICY='PASSIVE'
python tests/investigate_hpc22.py docs/hpc-optimization/hpc22-passive-config.json docs/hpc-optimization/hpc22-passive.json
Remove-Item Env:OMP_WAIT_POLICY
python tests/summarize_hpc22.py
python tests/test_hpc22_fallback.py
```

The original configuration requires the two preserved `.tools` executables identified by the audit; the internal configuration needs only the new build. Scripts overwrite the named reports, so use new report paths to retain this evidence. The model remains the HPC 2.1 axial fixture; regenerate it with the existing axial benchmark if absent, separately from measured runs. `hpc22-summary.json` contains phase medians and raw files contain output/input hashes, CPU, memory and I/O accounting. An idle-host rerun with monitored sustained clock, heap and cache profiling is still needed before claiming recovery to 5.278 s or assigning the slowdown to a specific external process.



## HPC 2.2 validation and changed code

Release and debug standalone builds and both GDExtension configurations were rebuilt. Native structural affine/rigid-mode/material tests, HEX8 integration/strain/invalid-model tests, thermal radiation analytical/tangent/equilibrium/transient checks, parallel assembly stress tests, explicit serial fallback stress tests, and no-OpenMP stress tests passed. CLI validation/Unicode paths, checkpoint/restart and incompatible-model rejection, and debug/release configurations passed. `hpc22-validation.log` retains the native/CLI output. An initial Godot launch through the Windows Python alias failed before running tests; rerunning with the installed interpreter path completed the suite.

`test_hpc22_fallback.py` verifies exact structural/conduction/transient-radiation fields for serial and row-owned modes at 1/4/12 threads (`hpc22-fallback-equivalence.json`). The existing historical-executable thermal equivalence test was also run, saving to `hpc22-thermal-equivalence.json`: exact equality at 1/2/4/6/8/12 threads. No assertion or tolerance was weakened.

The final rebuilt Godot suite reports **53/54 passed**, zero unexpected script errors (`hpc22-final-regression.json`). The known application-shell access violation 3221225477 / 0xC0000005 persists; `hpc22-app-shell.log` retains diagnostics. This is not an all-green application run. Other structural, thermal, radiation and advanced-load entries passed.

Changes made for HPC 2.2: `native/src/math/nodal_scatter.hpp` (diagnostic serial selector/scatter), structural and thermal kernel headers (batch selection and structural phase results), `native/src/math/sparse_pcg.hpp` (phase accounting with unchanged arithmetic), `native/extreme/main.cpp` (standalone switch/timers), `native/tests/parallel_assembly_test.cpp` (explicit fallback mode), `tests/investigate_hpc22.py`, `tests/summarize_hpc22.py`, `tests/test_hpc22_fallback.py`, and this report/evidence. Existing unrelated working-tree changes were retained. No additional optimization feature was introduced. The fallback is available because the original absolute slowdown has not been fully resolved.


# HPC 2.3 - advanced sparse solver investigation

See [HPC-2.3.md](HPC-2.3.md) for implemented Jacobi/block-Jacobi/IC(0) options, applicability, setup/memory/iteration/complete-wall comparisons and validation. Row-owned assembly and the serial fallback remain available. The large benchmark campaign was stopped at the user's request; 25 completed large measurements and the 709-second off-CPU preparation outlier are preserved. No automatic large-case continuation is scheduled. New diagnostics have strict case/campaign budgets, CPU/phase sampling, fallback labels and early regression guards. Native/CLI/checkpoint and release/debug/no-OpenMP validation passed; rebuilt Godot remains 53/54 with the known app-shell crash. High-contrast thermal flux accuracy requires explicit tolerance convergence checks; defaults remain unchanged. No general complete-solver speedup is claimed.

## HPC 2.4 - preparation pipeline

See [HPC-2.4.md](HPC-2.4.md) for bounded numeric-input A/B measurements, exact equivalence checks, phase diagnostics and remaining Windows tracing limitations. No large campaign was resumed.
