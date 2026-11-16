# Stage 5.1 - result performance and bounded crash diagnostics

Stage 5.1 is complete for this bounded scope: bottlenecks measured, justified caches implemented, A/B and numerical evidence preserved, required regression checks passed, and the historical crash investigated with reproducible evidence. **The crash remains unresolved.** This is not full Stage 5 feature completion or production-release approval.

## 1. Baseline and methodology

Read STAGE5.md, the workbench index and HPC-2.4 before implementation. Preserved unrelated working-tree changes and saved pre-change sources before instrumenting the existing pipeline. An initial benchmark setup selected a structural material without Poisson ratio; that failed setup is excluded from measurements.

Four actual Extreme fixtures: box structural HEX8, box thermal TET4 (27 nodes / 8 base cells), cylinder structural and thermal TET4 (645 nodes / 2688 elements). Each was solved once, then A/B reused the exact same project, job and result bytes. [Archived fixtures and SHA-256 manifest](stage51-fixtures/manifest.json), [effective source/executable hashes](stage51-source-hashes.json), [source baselines](stage51-baseline-sources/structural_display.gd.txt).

Initial phase instrumentation: [baseline raw timings](stage51-baseline.json), [initial optimized timings](stage51-optimized.json). Final controlled comparison: sequential A then B, same Godot 4.0 Vulkan Forward+ configuration and AMD Radeon RX 6550M Windows host, no concurrent compilation/debugger/solver campaign. Five imports and six alternating field switches per case, including cold first visits; no samples discarded. Three structural build calls per structural case. Each process is capped at 150 seconds. This is a small warm-filesystem pass, not a large-model benchmark. Source replacement is restored byte-for-byte in `finally`.

All timings are CPU-side calling-thread wall times. Resource submission is asynchronous: no GPU duration, FPS or full frame-latency claim. Phase instrumentation is coarse and includes overlapping phases, as described below.

## 2. Controlled A/B results

[Summary and sampled process peaks](stage51-comparison.json), [A samples](stage51-A.json), [B samples](stage51-B.json), [A log](stage51-A.log), [B log](stage51-B.log). Earlier paired observations remain in stage51-first-comparison/first-A/first-B JSON; initial instrumented observations remain separately retained.

Times in ms, median [min, max]; import n=5, switches n=6 (three per field).

|Case|Operation|Before ms [min, max]|After ms [min, max]|Ratio|
|---|---|---:|---:|---:|
|Box-static_structural|import|9.885 [8.334, 10.752]|7.782 [6.854, 8.057]|1.27x|
|Box-static_structural|switch|23.755 [19.675, 38.044]|12.645 [9.686, 26.057]|1.88x|
|Box-steady_thermal|import|12.243 [10.079, 12.860]|9.338 [8.856, 10.362]|1.31x|
|Box-steady_thermal|switch|29.205 [21.004, 45.680]|22.611 [18.933, 38.769]|1.29x|
|Cylinder-static_structural|import|425.445 [420.149, 451.669]|314.310 [295.563, 407.770]|1.35x|
|Cylinder-static_structural|switch|632.257 [581.884, 665.787]|36.797 [31.993, 248.069]|17.18x|
|Cylinder-steady_thermal|import|366.660 [351.582, 404.064]|268.076 [265.512, 292.631]|1.37x|
|Cylinder-steady_thermal|switch|433.291 [423.384, 560.927]|37.597 [29.164, 254.176]|11.52x|

Cylinder switching exceeds the 2x target for both physics cases. Final cylinder imports improve about 26.1% structural and 26.9% thermal. Box switching does not reach 2x, and box imports do not reach 25%; their avoided hashing cost is smaller and inspector construction dominates. No uniform target-achievement claim is made. Cold optimized cylinder switches still take approximately 248-254 ms; the warm medians must not be presented as cold latency.

Sampled engine-process peak working set: **396.89 MiB A, 412.70 MiB B**, increase **15.81 MiB / 3.98%**. GetProcessMemoryInfo was sampled every 50 ms on the actual engine process, across all four cases. This is not a per-field allocation or GPU memory measurement. The first pair increased peak roughly 6.4%; restricting the structural snapshot to actual rendering dependencies reduced the final increase. Caches are bounded, but memory neutrality is not claimed. One pair is insufficient to establish large-model memory acceptance.

## 3. Phase attribution and bottlenecks

The following medians are from the initial instrumented runs, distinct from the controlled final pair. Provenance includes snapshot time; inspector includes some current-result checks. Do not sum overlapping timings.

|Case|Phase|Baseline ms|Initial optimized ms|
|---|---|---:|---:|
|Cylinder-static_structural|parse_ms|27.994|33.362|
|Cylinder-static_structural|snapshot_ms|142.068|149.596|
|Cylinder-static_structural|provenance_ms|159.716|167.256|
|Cylinder-static_structural|compatibility_ms|160.524|58.748|
|Cylinder-static_structural|current_ms|475.430|22.562|
|Cylinder-static_structural|inspector_ms|176.074|16.175|
|Cylinder-steady_thermal|parse_ms|22.021|23.428|
|Cylinder-steady_thermal|snapshot_ms|142.646|148.036|
|Cylinder-steady_thermal|provenance_ms|154.046|160.583|
|Cylinder-steady_thermal|compatibility_ms|150.656|47.718|
|Cylinder-steady_thermal|current_ms|397.081|13.114|
|Cylinder-steady_thermal|inspector_ms|99.799|19.688|

Structural cylinder cold-build observations: scalar preparation about 1 ms, exterior extraction about 103 ms, vertex/color/scalar buffers about 15 ms, ArrayMesh/material/gradient construction and CPU resource submission about 0.3 ms. Cached field entries reuse mesh/material resources. GPU completion was not measured independently. Existing thermal timers record exterior extraction and surface construction; workspace instrumentation records inspector, accumulated current-result checks, and selected structural/thermal service timings. The public selection handler is timed end-to-end on the CPU. These cover the ten requested categories at CPU-call granularity; they are not a driver-level GPU profile.

Repeated serialization in `results_current()` was the dominant warm-switch bottleneck. Repeated exterior extraction was the next structural build cost. After caching, exact comparisons and inspector reconstruction dominate. Box inspector construction remains roughly 8-19 ms in the observed profiles. Full inspector reuse, independent GPU scalar uploads and deformation shader uniforms were not added in this bounded change.

## 4. Changes and cache invalidation

`result_identity.gd` owns one deep snapshot of [revision, parts, base mesh, analysis, full result]. Every request compares live values to that owned state using Godot deep equality. Any difference increments a generation and revalidates. No revision-only, timestamp, array-pointer or probabilistic-hash shortcut authorizes reuse. Parts cover transforms, materials and boundary conditions; mesh covers coordinates, ordering, connectivity and regions; the complete result covers imported arrays/history/metadata. Comparisons and snapshots remain O(state size), not O(1).

Existing source-mesh and model checks run on a cache miss. Newly completed normal-adapter solves now also retain the source-mesh digest and analysis reference; imported results retain analysis reference. Older in-memory normal result records without these optional references retain their existing fallback checks; they are not promoted into verified Extreme imports.

The generation participates in overlay and thermal preparation keys. This replaces the insufficient thermal revision/element-count-only key, so different imported results with the same counts cannot reuse stale surfaces. Structural display owns an exact snapshot of its rendering dependencies (ordered nodes/connectivity, displacement, von Mises and regions), one exterior topology and up to two current-field mesh/material entries at the current scale. Source changes clear derived data; scale changes clear field meshes while retaining compatible topology. Repeated field switches reuse existing ArrayMesh/material resources. Cold field visits and scale changes still generate buffers from original coordinates; no deformation accumulates.

Provenance import always rereads and verifies files: **no cached import authorization**. Snapshot canonicalization now selects exactly the original digest fields before serialization, excluding unrelated result data. Compatibility canonicalizes revision, parts, mesh and analysis individually, excluding duplicated export metadata and current results. Version-1 digest semantics, job SHA-256/FNV checks, strict malformed-data checks and legacy fail-closed behavior remain intact.

The new cache test deliberately bypasses revision updates for geometry, material, boundary force, analysis, coordinates, ordering, connectivity, region and imported identity changes. Associations are rejected and generations advance. Numerical-field changes invalidate derived meshes; repeated exact calls reuse the same resource. Existing provenance tests still reject changed jobs/snapshots, mismatched fingerprints and malformed fields. No hidden averaging, smoothing or new interpolation was introduced.

## 5. Numerical equivalence

An additional test loads the saved pre-optimization structural service and compares actual **vertex, color and UV scalar arrays and extrema exactly**, for HEX8 and TET4, displacement and unaveraged von Mises, scales 0/1/100, also checking mesh reuse: [equivalence log](stage51-checks/equivalence.log).

Cylinder conduction still matches the independent reference T=300+250(y-ymin) K and q=(0,-3750,0) W/m^2: maximum temperature error **2.99940e-9 K**, vector-flux error **2.25595e-6 W/m^2**, balance **1.39870e-11 W**. [Final data](stage51-cylinder-display-numerical.json). Cylinder axial/rotation verification reports zero failures. Box convection/radiation and recorded transient playback pass. Solver input/output bytes used by A/B are identical; no native kernel, convergence tolerance, material value or quality threshold changed.

## 6. Regression results

- Complete default manifest: **28 passed / 0 failed**, zero script errors/timeouts. [Results](stage51-regression/results.json).
- Focused/workflow/configuration runner: **26 passed / 0 failed**. [Results and logs](stage51-checks/results.json). Includes cache invalidation, provenance, mesh quality, visualization/mapping, probes, cylinder FEM, Stage 1-3 workflows, checkpoint/restart and incompatible restart rejection, three release-extension ABI tests, graphical playback/captures, and five native tests each in Debug and no-OpenMP modes.
- Separate baseline/optimized buffer equivalence test: passed, as above.
- Historical app-shell process: **three failed executions**, reported separately below. Its printed assertions are not treated as a clean process exit.

Native sources were unchanged; Debug/no-OpenMP tests rerun the freshly compiled Stage 5 stabilization binaries, not newly rebuilt binaries. Release-extension structural/thermal/radiation ABI checks use the existing release DLL; descriptor restoration is in `finally`, and those tests run sequentially. No native rebuild or sanitizer run is claimed for Stage 5.1. Headless dummy-renderer warnings remain recorded, not suppressed.

Malformed thermal history, missing radiation fields and out-of-range radiation face IDs are retested by graphical workflow assertions. The existing provenance suite covers stale/mismatched imports and legacy rejection.

## 7. Graphical validation

Sixteen fresh actual framebuffers were captured and opened at 1280x720 and 1920x1080. Legends/ranges/units, discontinuous element stress, physical-versus-display scale, and heat-flow direction agree with the numerical fields. Existing dense cylinder wireframe, small thermal 3D labels and fixed legend overlap with a corner of a zoomed box remain limitations. A normal hover tooltip appears in some 1080p captures without obscuring model/legend. No UI redesign was attempted.

|Case|1280x720|1920x1080|
|---|---|---|
|box displacement|[image](stage51-box-displacement-1280.png)|[image](stage51-box-displacement-1920.png)|
|box von_mises|[image](stage51-box-von_mises-1280.png)|[image](stage51-box-von_mises-1920.png)|
|box temperature|[image](stage51-box-temperature-1280.png)|[image](stage51-box-temperature-1920.png)|
|box heat_flux|[image](stage51-box-heat_flux-1280.png)|[image](stage51-box-heat_flux-1920.png)|
|cylinder displacement|[image](stage51-cylinder-displacement-1280.png)|[image](stage51-cylinder-displacement-1920.png)|
|cylinder von_mises|[image](stage51-cylinder-von_mises-1280.png)|[image](stage51-cylinder-von_mises-1920.png)|
|cylinder temperature|[image](stage51-cylinder-temperature-1280.png)|[image](stage51-cylinder-temperature-1920.png)|
|cylinder heat_flux|[image](stage51-cylinder-heat_flux-1280.png)|[image](stage51-cylinder-heat_flux-1920.png)|

## 8. Crash reproduction and evidence

**Unresolved; no speculative correction applied.** Direct diagnostic budget was capped at 15 minutes, with individual debugger attempts capped at 70 seconds, Windows debug-event capture at 40 seconds and ordinary runs at 30 seconds. No new tools installed; no LocalDumps policy, registry, system settings or ACL changes. A scoped elevated read copied only the existing Godot WER report.

Three runs of `.tools/godot/Godot_v4.0-stable_win64_console.exe --headless --path . -s res://tests/test_app_shell_suite.gd` reproduced **3221225477 / 0xc0000005**, after 11.091, 11.323 and 11.828 s. All print `91 Passed, 0 Failed` before process failure. [Exit records](stage51-crash/reproductions.json), [stdout/stderr 0](stage51-crash/reproduction-0.log), [1](stage51-crash/reproduction-1.log), [2](stage51-crash/reproduction-2.log).

Windows records exception **0xc0000005**, faulting module **Godot_v4.0-stable_win64.exe**, version **4.0.0.0**, offset **0x0000000000518504**. [Application/WER events](stage51-crash/windows-events.txt), [preserved Report.wer](stage51-crash/Report.wer). Loaded module paths are preserved, including the UniCORE debug extension; [file/product versions](stage51-crash/module-versions.json). The engine file reports 4.0.stable.official. **A faulting module does not establish causal responsibility**: invalid state may originate elsewhere. No finding blames Godot, UniCORE, a driver or extension unloading.

## 9. Native stack/dump findings and failure stage

No useful native stack, absolute fault address or exception-time dump was obtained. Installed GDB first followed the console launcher, observing termination but no useful live stack. A second attempt debugged the engine executable and timed out while instantiating the main scene, before the usual final assertion banner. A built-in Windows debug-event/minidump attempt also stalled earlier and ended with a teardown-wait timeout; it produced no usable dump. [Launcher log](stage51-crash/gdb.log), [engine debugger log](stage51-crash/gdb-main.log), [debuggee log](stage51-crash/debuggee.log), [commands](stage51-crash/capture.gdb). These attempts are not claimed as successful captures or clean retests. The WER temporary dump no longer existed; the accessible archived report directory contained Report.wer only.

Verified stage: after the ordinary test's assertions/completion banner, before a clean exit. Source queues viewport/menu/topbar/space and module managers/world root/event bus/settings nodes for deletion, then calls quit(0). A deferred-deletion/shutdown lifetime fault is a **hypothesis**, not an identified phase or responsible frame. Native destruction, extension unloading, worker termination and rendering cleanup cannot be distinguished from this evidence. No supported minimal fix is available, so none was applied. The smallest next action is a usable exception-time dump/stack with matching symbols under a setup that preserves the ordinary reproduction; any new machine-wide dump policy or tool installation would require separate approval as appropriate.

## 10. Remaining limitations and Stage 6 readiness

The major small-cylinder bottlenecks are measured and substantially reduced with exact buffer equivalence and provenance protections intact. Cold field construction, imports (~0.27-0.31 s), full inspector reconstruction and O(n) exact comparisons remain synchronous. Box performance targets and memory neutrality were not achieved uniformly. A single paired process peak cannot certify large-model memory use. More invasive GPU uploads, shader deformation and asynchronous import remain future measured work.

Stage 6 development can proceed on this validated subset; no Stage 6 meshing was implemented. Product-wide release remains blocked by the historical crash. Stage 5.1 completion here means bounded reproducible diagnostics are documented, **not a crash fix**. All remaining original Stage 5 feature limitations continue to apply.

## 11. Files and reproduction

Production: new `core/cae/result_identity.gd`, limited changes to `extreme_jobs.gd`, `structural_display.gd` and workspace adapters/timers. Thermal rendering service code is unchanged; its workspace preparation key is stronger. Test tools: `benchmark_stage51.gd`, `compare_stage51.py`, cache/equivalence tests, `validate_stage51.py`, three stage51 graphical scripts and the bounded diagnostic-attempt script. Raw fixtures, baseline sources, source hashes, timing evidence, WER/module records, logs and screenshots accompany this report. Unrelated edits preserved.

Generate fixtures with `benchmark_stage51.gd`; run `compare_stage51.py` sequentially without editing/testing concurrently (it temporarily swaps source files). The harness uses `.tools/stage51-baseline/` and `.tools/stage51-fixtures.json`; preserved `.gd.txt` sources and archived exact project/job/result/status bytes allow restoring these inputs. Then run the default manifest, `validate_stage51.py` and `test_stage51_equivalence.gd`. Use the installed Python interpreter instead of the unavailable Windows alias. Native executables must match Stage 5 stabilization. Diagnostic scripts do not establish a permanent dump policy.
