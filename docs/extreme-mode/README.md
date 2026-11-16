# UniCORE Extreme Calculation Mode

Validated on Windows x86_64, AMD Ryzen 5 7535HS (6 physical cores / 12 logical processors), approximately 16 GB installed RAM. Compiler: MinGW GCC 13.1.0, C++17, `-O2 -fopenmp -ffp-contract=off`, static C++/OpenMP runtime linkage. Debug standalone uses `-O0 -g`. The GDExtension debug/release configurations were also rebuilt. GPU rendering tests used Godot 4.0 stable / Vulkan / Radeon RX 6550M; this is not GPU numerical acceleration.

## Working components

* `bin/unicore_solver.exe`: independent native executable; no Godot runtime dependency. PE dependency evidence is in dependencies.txt.
* The existing Godot-free `native/src/kernels` and `native/src/math` headers are the shared compute library, exposed through the `unicore_compute` CMake INTERFACE target. Normal and Extreme modes include these same kernels; no second stiffness, conduction or radiation solver was introduced.
* Standalone input validation, immutable numerical models, independent process execution, cooperative cancellation, persistent job discovery, numerical result import and a compact Extreme CPU panel are integrated into the existing CAE workspace.
* OpenMP runs bounded element-integration batches and postprocessing; assembly scatter remains deterministic and serial. CSR sparse products use parallel rows on sufficiently large systems. Dot products remain serial to preserve reduction order. CSR conversion reserves its buffers and reuses sorting scratch storage instead of allocating a temporary vector for every row.
* Shared thermal results now include computed conductive/radiative flux histories. The GDExtension adapter consumes those shared results instead of separately reimplementing that processing.
* Transient thermal checkpoints support physical-state restart, including nonlinear radiation. Structural checkpoint/restart is not supported or advertised.

## Build and execution

The PowerShell builds below were executed successfully in this workspace. They use the existing Qt MinGW compiler location; change the compiler path in the script for another installation.

```powershell
powershell -ExecutionPolicy Bypass -File native/extreme/build.ps1
powershell -ExecutionPolicy Bypass -File native/extreme/build.ps1 -Debug
powershell -ExecutionPolicy Bypass -File native/build_direct.ps1 -Target template_debug
powershell -ExecutionPolicy Bypass -File native/build_direct.ps1 -Target template_release
bin/unicore_solver.exe --job model.ucjob --threads 2 --memory-mb 1024 --output results
```

`native/extreme/CMakeLists.txt` is an alternative standalone/library target. CMake was not available in this environment, so the CMake invocation itself was not tested. Without OpenMP, the core has a serial fallback and the executable accepts one compute thread; unsupported parallel requests fail explicitly. The supplied standalone launcher/monitoring implementation is Windows-specific; the numerical headers contain no Godot/UI dependency.

Binaries are generated build outputs and are ignored by the repository's existing `.gitignore`. Rebuild them after a clean checkout. The standalone executable must be deployed as an external file, not treated as an executable inside a Godot PCK.

## Version 1 numerical job format

The job is whitespace-delimited ASCII numeric data (UTF-8 paths are supported). Comments are not part of the numeric grammar. Node and element IDs are zero-based. Units are SI: coordinates/displacements m, forces N, stresses and E Pa, temperature K, conductivity W/(m K), volumetric capacity J/(m^3 K), volumetric source W/m^3, surface flux W/m^2, heat rates W, time s. Surface flux is positive inward; radiation/convection loss is positive outward.

```
UNICORE_JOB 1 ANALYSIS
NODE_COUNT ELEMENT_COUNT
x y z                         # repeated NODE_COUNT times; omit comments in files
ARITY node_ids... material...  # repeated ELEMENT_COUNT times
```

Supported analyses are exactly `static_structural`, `steady_thermal`, `transient_thermal`.

Structural cell records have arity 4 or 8 followed by connected IDs, E, nu. Each of the 3*N global Cartesian DOFs then has `force fixed_flag prescribed_displacement`. The fixed flag is 0 or 1. HEX8 uses the existing full 2x2x2 integration; TET4 uses the existing constant-strain formulation. Stress/strain component order is xx, yy, zz, xy, yz, xz. Mixed input cell fields are remapped to original input element order before output.

Thermal cell records require arity 4, IDs, `conductivity source volumetric_capacity`. Capacity is required positive for transient analyses and may be zero in steady analyses. Next come N records `fixed_flag temperature`, then a surface count and that many records:

```
a b c inward_flux h ambient_K emissivity surroundings_K
```

Surfaces must be actual exterior TET faces with positive area. Convection and radiation can coexist in one record; separate contributions on the same face are also supported. All indices, counts, finite values and physical parameter ranges are checked. The last thermal record is `dt steps initial_temperature_K`; steady mode requires `0 0 initial_K`, transient mode requires dt>0 and 1..200 steps. The existing 200-step thermal limit is preserved, not presented as a new DOF restriction.

`configuration.json` records schema, CPU FP64 backend, thread count, memory budget and the fixed version-1 solver configuration: PCG tolerance 1e-10, final linear acceptance residual 1e-7, radiation Newton tolerance 1e-9. These retain the existing validated core tolerances. Version 1 writes all supported outputs; arbitrary tolerance overrides or output-selection flags are not implemented and must not be assumed.

The Godot exporter resolves materials, thermal conditions, prescribed displacements, pressure, face forces and gravity into numerical data. Its exported mesh uses the same HEX8/TET4 split as the native adapter. Face-force weighting is area-consistent; geometric load calculations use scalar double arithmetic. The original CAD snapshot is a separate `project.json` sidecar; rendering objects and old result fields are not exported into the numerical job.

## Persistent execution and UI

Open **Extreme CPU > Configure / jobs**. CPU is the available backend. CUDA, ROCm and Vulkan Compute are disabled future choices. Balanced / High Performance / Maximum / Custom control compute threads; the presets are workload-dependent heuristics informed by the saved measurements, not universal autotuning. Memory can be automatic (reserving headroom) or manually selected. Normal, minimal-rendering and headless-safe launch choices are available.

The application uses `OS.create_process` with an argument array, not a shell-built command. A solver process is not retained as an application-owned computation thread. Minimal mode disables CAE viewport updates and cancels unnecessary inspection preparation/playback; monitoring labels remain active. Closing the actual Godot application does not stop the worker. `test_extreme_lifetime.py` verifies that a worker remains Running after Godot exits, rejects a duplicate launch in its directory, then honours a cancellation request made after the GUI has closed.

Managed jobs reside under `user://extreme_jobs/<unique-id>/` and are rediscovered from disk on reopening the panel/application. Each directory contains the numerical model, CAD sidecar, process receipt, configuration, status and results. Start, cancellation, logs/diagnostics, result loading and return to CAE are functional. Result loading restores the job's model snapshot and feeds the existing structural/thermal visualization; it does not overwrite the running solver's inputs.

States: Created, Queued, Validating, Running, Completed, Failed, Cancelled; orphaned PID/lock records are interpreted as Interrupted or Restartable when a physical checkpoint exists. Queued is the persistent handoff before launch, not a claim that a separate cluster scheduler exists. Concurrent jobs are independent processes; there is no global fair-share scheduler or automatic memory reservation across multiple jobs.

`status.json` reports real numerical phase, wall elapsed time, current linear iteration/residual and sampled working set. Final status contains actual convergence residual/iteration totals and peak process memory. It never invents percentage completion. Phase 3 is assembly, 4 is solving, 5 is postprocessing. Current linear residual is distinguished from the final nonlinear residual. Progress is polled at approximately 100 ms natively and one second in the GUI. A condition-variable wakeup avoids delaying short jobs merely to stop the monitor.

Files are published by temporary-file replacement with bounded retry for Windows sharing conflicts. Results are streamed to a temporary file instead of retaining a second complete serialized result in memory. Completed result/checkpoint data is flushed before publication. An exclusive delete-on-close `running.lock` prevents two workers from writing the same job directory. Readers close handles promptly. `error.log` and structured Failed status preserve diagnostics. Do not consume `results.json` unless the job status is Completed; partial `.tmp` files are not results.

Exit codes: 0 completed; 2 invalid input/numerical failure; 3 cooperative cancellation; 4 memory budget exceeded; 5 progress-publication failure; 6 locked/unwritable job directory. Requested memory must be positive and cannot exceed detected physical RAM. Allocation estimates are preliminary screening, not exact prediction. Working-set monitoring is a sampled soft guard, not a hard virtual-address-space guarantee; brief allocation peaks or pre-monitor input allocation can exceed an estimate.

## Checkpoint/restart contract

Every completed transient thermal step publishes `checkpoint.ucstate`. Format `UNICORE_STATE 1` includes a byte-exact FNV-64 model fingerprint, dt, completed step count, node count and full-precision temperatures. Time is completed_steps*dt. Solver precision/tolerances are fixed by schema version 1; CPU threads and memory budget may change on restart. Model mismatch, wrong version/dimensions, invalid Kelvin values, incompatible dt and already-complete states are rejected.

```powershell
bin/unicore_solver.exe --job model.ucjob --output results --pause-after 1
bin/unicore_solver.exe --job model.ucjob --output results --restart results/checkpoint.ucstate --threads 2
```

`--pause-after` is a controlled cooperative stop after completed physical steps. Restart reconstructs matrices and resumes from the saved temperature field. It does not continue an interrupted PCG/Newton iteration. Restart output histories contain the resumed physical time segment. Structural restart is rejected. A stale lock after a machine-level storage/power failure may require explicit operator inspection/removal; no claim of recovery from every storage failure is made.

## Numerical validation

The initial primary manifest was rerun: 26/26 passed before changes. Displacements, stresses, reactions, final temperatures, conductive flux, thermal history and energy balance are compared against the GDExtension using the same inputs and kernels. Advanced tests cover HEX8/TET4 pressure, gravity and prescribed displacement. The stored equivalence data is in equivalence.json and advanced-loads.json; checkpoint/rejection evidence is in restart.json and cli-validation.json.

| Analysis | Maximum primary field difference | Stress/flux difference | History difference |
|---|---:|---:|---:|
|static_structural|3.30872e-24|4.54747e-13|0|
|steady_thermal|5.68434e-14|2.27374e-13|0|
|transient_thermal|5.68434e-14|6.93889e-18|5.68434e-14|

Displacement comparisons use 1e-13 m in the small common-model regression; stress/flux checks use 1e-6 in their SI units, reaction checks 1e-8 N, temperature/history checks 1e-7 K, energy difference 1e-7 W, and both solvers must satisfy their residual acceptance. Reported measured differences are much smaller than these limits. No assertions were relaxed for the standalone path. The radiation analytical, tangent, equilibrium and transient-cooling regression is also rerun; see radiation-regression.txt.

## Measured performance

These are individual runs on the stated host, not statistical guarantees. They include process startup, numerical input loading and output costs where wall time is shown. CPU core timings separately isolate assembly/integration, sparse solve and postprocessing. Mesh generation/write timing is measured by the external fixture generator. No rendering FPS claim is made.

### Actual structural FEM axial patch

E=1000 Pa, nu=0, unit cube, area-consistent unit axial load, fixed X- face. Exact displacement is u_x=.001*x; all thread counts preserve the same iteration counts and numerical answers. `tests/benchmark_extreme_axial.py` generates the fixtures and saves all stages, residuals, errors and Windows peak working-set counters.

| DOF | HEX8 elements | Threads | Total wall s | Preparation ms | Assembly ms | Solve ms | Post ms | Peak MiB |
|---:|---:|---:|---:|---:|---:|---:|---:|---:|
|1029|216|1|0.273|27.167|8.906|1.931|4.109|8.53|
|1029|216|2|0.058|19.752|8.540|2.250|2.196|8.56|
|1029|216|4|0.056|19.157|7.397|2.095|1.962|8.71|
|10125|2744|1|0.497|179.270|119.188|51.490|56.447|45.79|
|10125|2744|2|0.504|174.895|118.632|58.468|61.342|46.13|
|10125|2744|4|0.425|172.287|77.935|49.592|30.428|46.16|
|27783|8000|1|1.396|468.611|345.777|179.141|167.677|121.35|
|27783|8000|2|1.287|450.913|319.895|162.285|102.596|121.02|
|27783|8000|4|1.175|465.473|295.088|112.740|66.187|121.20|
|107811|32768|1|7.305|1858.526|1665.198|1382.343|1081.070|472.30|
|107811|32768|2|6.873|2263.868|1492.970|1089.629|716.629|470.73|
|107811|32768|4|5.259|1803.341|1104.700|675.279|407.483|470.75|

The largest tested FEM problem is 107811 DOF / 32768 HEX8 cells. A million-DOF FEM model was not run given available memory headroom; the million-row test below is explicitly a scalar linear-algebra benchmark, not a million-DOF FEM claim. These axial patches validate an exact field and are not a substitute for benchmarking complex industrial geometries.

### Normal Mode versus standalone

The common 4096-element HEX8 model has 14739 DOF. `normal-comparison.json` contains normal adapter wall time, normal core stages, meshing time, standalone stages and Godot export/launch overhead separately. The normal adapter includes model/material preparation and field conversion, while standalone total time includes input decoding and output serialization; only like-for-like core stages should be compared directly. Responsive GUI behavior is not a numerical speedup measurement.

Normal native wall: 430.120 ms; mesh: 5.314 ms; core stages: {'assembly': 172.4025, 'postprocessing': 82.0732, 'solve': 85.0498}.

### Sparse algebra, layout and SIMD

`pcg-benchmark.csv` reports 1000, 10000, 100000 and 1000000 rows for a manufactured SPD tridiagonal system with known x=1 and 1/2/4/8/12 thread requests. This is a real PCG solve, but is not FEM. `pcg-before.csv` preserves earlier measurements before CSR scratch reuse. Samples were collected at different moments and CPU load/frequency/cache state was not controlled; do not treat the ratio of those files as an isolated causal speedup estimate.

FP64 CSR values/indices and reusable vectors are contiguous. Sorted assembly and deterministic merging preserve arithmetic order. No `-ffast-math` or host-only ISA requirement was added. GCC vectorization diagnostics are saved in vectorization.txt; strict reduction semantics and control flow limit vectorization. SIMD was not forced at the expense of validated numerical behavior.

Thermal manufactured-field thread measurements are in thermal-benchmark.json. Small thermal jobs can be slower with additional threads because setup/synchronization/process costs dominate; larger is not automatically faster. Thread scaling must be assessed per workload.

## GPU foundation

`math/csr_backend.hpp` defines the immutable FP64 CSR view and a linear-backend operator interface. CPU is implemented; availability for CUDA/ROCm/Vulkan is false. No CPU routine is presented as a GPU solver. Future implementations must preserve FP64 accuracy/convergence, define device ownership and memory limits, and avoid transferring host vectors on every iteration by extending the device-resident solver pipeline. There are no mandatory GPU SDK dependencies.

## Crash investigation and regressions

The existing failing test is `tests/test_app_shell_suite.gd`, executable `Godot_v4.0-stable_win64.exe`, exit 0xC0000005 after 91 passing assertions. It was reproduced before architectural work. The exception is generic and provides no basis for connecting it to another application's crash. Existing Windows evidence identifies a fault inside Godot.exe (previously observed offset 0x518504); the bounded GDB run did not reproduce the fault and exited normally with lifecycle/ObjectDB diagnostics. No reliable crash stack/dump was obtained. Its origin is unresolved, not assigned to the GDExtension or hardware without evidence. The failure remains visible and is not suppressed. See crash-baseline.log and crash-gdb.log.

The extended final runner executed 54 suites: 53 passed, 1 failed. Full details: regression-results.json. The remaining failure is the same app-shell access violation. The primary manifest includes the new Extreme equivalence/advanced-load tests. Graphical integration and Python process/checkpoint tests are executed separately from the headless manifest.

The console-wrapper test initially held inherited output pipes open while a worker lived. The independent-lifetime test therefore closes the actual Godot engine executable with non-pipe output handles, verifies Running after its exit, rejects a concurrent launch into the same directory, and cancels the worker afterward. This distinguishes console capture lifetime from numerical worker lifetime.

## Reproduction commands

```powershell
python native/run_regressions.py --godot .tools/godot/Godot_v4.0-stable_win64_console.exe --all-suites --output .tools/extreme-final-validation
.tools/godot/Godot_v4.0-stable_win64_console.exe --headless --path . --script tests/test_extreme_equivalence.gd
.tools/godot/Godot_v4.0-stable_win64_console.exe --headless --path . --script tests/test_extreme_advanced.gd
.tools/godot/Godot_v4.0-stable_win64_console.exe --path . --script tests/test_extreme_gui.gd
python tests/test_extreme_cli.py
python tests/test_extreme_checkpoint.py
python tests/test_extreme_lifetime.py
python tests/test_extreme_configurations.py
python tests/benchmark_extreme_axial.py
python tests/benchmark_extreme_thermal.py
.tools/godot/Godot_v4.0-stable_win64_console.exe --headless --path . --script tests/benchmark_extreme_normal.gd
```

Graphical evidence: configuration.png, static_structural.png, transient_thermal.png. These are actual Godot framebuffer captures. The GUI test exercises process launch, minimal rendering, persistent discovery through a new manager, result import and thermal restart. It calls application handlers; exhaustive physical mouse/keyboard interaction is not claimed.

## Remaining limits

* App-shell access violation remains unresolved; the extended suite is not fully green.
* Standalone process/resource/persistence APIs are validated on Windows x86_64 only. CMake configuration and other compilers/platforms were not exercised here.
* Version-1 job configuration preserves fixed existing solver tolerances and writes all supported fields; configurable tolerance/output subsets are future work.
* Structural and thermal material laws remain the validated isotropic models. No CFD, nonlinear structural material law, GPU solver, cluster scheduler or surface-to-surface radiation model is added.
* There is no structural checkpoint or exact Krylov/Newton restart. Physical transient thermal state restart is the validated scope.
* Memory estimates are approximate and the RSS guard is sampled. History output, text parsing/serialization and serial sparse scatter/reductions can still dominate large jobs.
* Presets are workload-dependent. Million-row scalar tests must not be confused with million-DOF FEM validation.
* The existing CAD mesher's limits remain in Normal Mode. The standalone reader accepts larger supplied numerical meshes subject to actual resource/numerical checks.

The list of source files touched by Extreme Mode is in modified-files.txt. The workspace also contained prior uncommitted Mesh Inspection/CAE changes; those have been preserved rather than attributed to a clean baseline.
