# HPC 2.4 - measured standalone numeric input optimization

The completed optimization replaces per-number formatted stream extraction with bounded stack tokenization and C++17 `from_chars`. On this host, three alternating A/B measurements for each model show lower preparation and complete-process median times, with exact numerical field equality. This is a focused, validated increment; the full requested instrumentation/Windows tracing program remains incomplete as detailed below. No large campaign was resumed.

## Initial evidence and controlled experiment

Read HPC 2.3, the optimization index and Extreme-mode documentation before changes. The existing loader interleaves formatted conversion, connectivity validation and object construction. It also allocates a temporary connectivity vector per cell, grows element vectors geometrically, copies coordinates into both model types and hashes a second byte-at-a-time file pass. Those allocation patterns are source observations, not measured allocator bottlenecks.

`hpc24-initial.json` retains six instrumented baseline samples. The first six-TET4 thermal sample spends 1521 ms wall / 1422 ms process CPU in cell connectivity/material construction, versus 122 / 109 ms on nodes and 77 / 78 ms on boundaries. The data identifies a CPU-bound preparation interval, unlike the historical 709-second off-CPU event. A controlled replacement of only numeric extraction then isolates the practical cost of the formatted extraction path. No material or FEM layout rewrite was bundled with it.

A is `.tools/unicore_solver_hpc24_instrumented.exe`; B is the rebuilt release executable. Both use the same source model layout, phase instrumentation, MinGW GCC 13.1, C++17, `-O2 -static -fopenmp -ffp-contract=off -municode`, one compute thread, 1024 MiB budget, Jacobi defaults and full output. Input hashes and executable hashes are retained in every row. Hardware/environment is the existing Windows Ryzen 5 7535HS host. Shared-host activity was not controlled. Warm filesystem; no cold-cache claim. No benchmark overlapped compilation. Each case has a 10-second hard cap and each campaign a 90-second cap; processes run sequentially, with the existing benchmark mutex name. Fixtures are 14,739 structural DOF / 4096 HEX8 and 4913 thermal DOF / 24,576 TET4. Each campaign completes without retries or timeout. Original executable was also saved as `.tools/unicore_solver_hpc24_before.exe`.

## Preparation phase accounting

`preparation.json` contains exclusive wall and process CPU milliseconds for output initialization, file opening, header validation, node construction, cell connectivity/material construction, boundary conditions, final metadata, fingerprint read/hash and restart. It also records input bytes, node/element counts and peak working set at the end of preparation. `results.json` retains inclusive parse/model, cell interval, preparation, assembly, solve, postprocessing and whole-process peak measurements. Do not add inclusive and exclusive intervals. Process CPU uses GetProcessTimes and is quantized at approximately 15.625 ms; tiny intervals can report zero or more CPU than wall.

File reads remain buffered and interleaved with tokenization/conversion; these are NOT separately timed. Integer fields retain the existing finite-double, integral-value and budget validation for compatibility with tokens such as `4.0`. Integer versus floating conversion, material assignment versus element construction, connectivity bounds checking and allocation are still fused. Final kernel geometry/material validation remains in the existing solver path, outside loader timers. Thus this is not a complete fifteen-category breakdown. Timers are always enabled and use only coarse boundaries (no per-token clocks); a disabled instrumentation switch is outstanding. Diagnostic publication is a sidecar and not part of the exclusive interval sum. Fingerprint timing retains its historical inclusive restart interval in results; the sidecar splits them.

## Final paired results

Three samples per row; order A/B then B/A then A/B for each model. Medians, milliseconds except external wall/CPU seconds, MiB and decimal MB/s. Parse CPU is the sum of exclusive parse phases; independent medians need not sum. No slow samples were discarded. Final source including underflow compatibility was rebuilt before this pass. Earlier development measurements remain in `hpc24-paired.json`.

|Model|Variant|Parse wall ms|Parse CPU ms|Preparation ms|Assembly ms|Solve ms|Process wall s [range]|Process CPU s|Peak MiB|Parsing MB/s|
|---|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|
|elastic-16|A|724.845|656.250|740.805|526.337|200.720|2.462 [1.815-2.532]|1.938|66.66|0.55|
|elastic-16|B|13.306|15.625|30.333|465.127|219.605|1.273 [0.630-1.692]|1.219|66.66|29.88|
|contrast-conduction-16|A|1538.288|1453.130|1564.270|63.657|59.288|1.914 [1.062-2.347]|1.766|16.81|0.61|
|contrast-conduction-16|B|26.634|31.250|49.930|61.557|46.480|0.404 [0.227-0.445]|0.391|16.82|34.98|

Structural complete-process median decreases from 2.462 to 1.273 s (1.93x); thermal from 1.914 to 0.404 s (4.73x). Parsing throughput includes model construction and validation, not only conversion. These ratios apply to this bounded pass, not arbitrary models or large jobs. The broad wall ranges and assembly variation show environmental noise; the preparation and CPU reductions are much larger and repeat across both retained paired campaigns. No performance claim is made for 250k–1M DOF. Input sizes are 397,608 and 931,611 bytes.

## Implementation, allocation and precision

`numeric_input.hpp` scans the existing stream buffer into a 1024-byte stack token, recognizes ASCII whitespace and parses decimal FP64 through `from_chars`, avoiding locale facet conversion and per-number heap tokens. Leading plus is explicitly supported. Invalid suffixes, double signs, nonfinite values, overflow, truncation and excessive token lengths fail explicitly. Extremely long numeric tokens now have a documented 1024-byte limit. Legacy decimal underflow acceptance and rounding to zero is preserved through a rare classic-locale stream fallback on out-of-range conversion; overflowing values still fail. No fast-math or reduced precision was introduced.

Existing count, index, boundary, surface, material, memory-estimate and solver validations remain. Cancellation polling every 16,384 numbers and fingerprint MiB remains. Huge whitespace/header-string scans still lack additional mid-scan cancellation hooks, an existing limitation. Coordinate copies, per-cell connectivity allocation and element growth remain unchanged to isolate the measured extraction improvement. Whole-process median peaks are essentially unchanged (66.66 MiB structural and approximately 16.8 MiB thermal). Allocation counts/bytes were not instrumented; no measured allocator-contention claim is made. The fixed token buffer adds 1 KiB stack storage per active extraction, without retaining another whole-file buffer.

## Correctness and regression evidence

All twelve final paired results compare exactly for displacement, reactions, stress, strain, von Mises, temperature, conductive flux, heat reactions, residuals and iteration counts where applicable. `job_numeric_test.cpp` checks 100,000 deterministic round-trip decimal cases, signed zero, extremes/subnormals/underflow, malformed tokens and token limits. Every numeric token in both benchmark inputs and the transient-radiation fixture compares exactly to legacy extraction; since model construction/assignment is unchanged, this also checks coordinates, connectivity, material values, loads, boundary and analysis numbers at the conversion boundary.

Release, debug and no-OpenMP standalone builds succeeded. `hpc24-regression.json` records exact serial/row-owned fields in all three builds on TET4 structural and nonlinear transient thermal cases. Existing native structural, HEX8, radiation, preconditioner and assembly binaries passed bounded reruns (they were not recompiled because shared kernels were unchanged). Established CLI/Unicode-path, malformed jobs, solver trailer/CLI precedence, Jacobi/block/IC options, steady thermal, transient radiation, checkpoint/restart, mismatch rejection and cancellation assertions passed. The final paired conduction workload has million-to-one conductivity contrast and exact A/B fields; this does not change HPC 2.3's flux tolerance limitations. The existing default numerical tolerances were preserved.

Validation helper initially refreshed several HPC 2.3 validation-only JSON reports through nested existing helpers (options, advanced checkpoint and cancellation); benchmark files were not touched. The wrapper now redirects those outputs to HPC24 paths. Historical benchmark/outlier data is preserved. Full Godot regressions were not rerun; the known app-shell 0xC0000005 remains unresolved. GDExtension was not rebuilt because this increment changes only standalone files, not shared native kernels or bindings.

## Binary format decision

Defer production binary input and prototype. Optimized text parse/model medians are 13 and 27 ms in these bounded workloads, versus complete times of 1.273 and 0.404 s. Even eliminating parsing entirely cannot save more than those measured intervals on these samples; this does not establish a benefit at large sizes. A new binary compatibility surface is not justified by current bounded measurements. Text remains the sole supported format. A future binary design would need explicit magic/version, little-endian fixed-width sections, IEEE FP64 encoding, checked lengths/offsets, integrity checks and cancellable deterministic conversion, independently tested before integration. No partial production parser was added.

## Windows off-CPU investigation

`wpr.exe` is available at C:/Windows/system32/wpr.exe; WPA was not found on PATH. No system-wide ETW session was started, security settings changed or tools installed. Bounded runs did not reproduce the historical off-CPU stall. Preparation CPU advances roughly with wall in baseline samples; the old 709-second event remains unexplained. No evidence assigns it to parser CPU, allocator, antivirus, storage or OS suspension.

`tests/sample_hpc24_waits.ps1` provides a read-only, at-most-ten-second sampler for an existing PID: thread state/wait reason, CPU, working set, peak and paged memory at roughly 100 ms. It refuses an existing report and does not create a solver or leave background work. The hook was added but not exercised against a reproduced stall. It does not capture stacks, hard faults, I/O operations, system contention or prove process suspension. Those, and a bounded ETW stack trace during an actual recurrence, remain future diagnostic work. Existing HPC23 CPU/phase samples and the historical outlier are retained.

## Reproduction

Run builds separately from benchmarks. Use fresh report names and preserve reference executables before rebuilding.

```powershell
powershell -ExecutionPolicy Bypass -File native/extreme/build.ps1
powershell -ExecutionPolicy Bypass -File native/extreme/build.ps1 -Debug
powershell -ExecutionPolicy Bypass -File native/extreme/build.ps1 -NoOpenMP
python tests/benchmark_hpc24.py docs/hpc-optimization/hpc24-new-paired.json .tools/unicore_solver_hpc24_instrumented.exe bin/unicore_solver.exe
python tests/test_hpc24_validation.py
python tests/test_hpc24_modes.py
C:/Qt/Tools/mingw1310_64/bin/x86_64-w64-mingw32-g++.exe -std=c++17 -O2 -static native/tests/job_numeric_test.cpp -o .tools/job_numeric_test.exe
.tools/job_numeric_test.exe .tools/hpc23-bench/elastic-16.ucjob .tools/hpc23-bench/contrast-conduction-16.ucjob .tools/extreme-checkpoint/model.ucjob
powershell -ExecutionPolicy Bypass -File tests/sample_hpc24_waits.ps1 -ProcessId 1234 -Seconds 10 -Output docs/hpc-optimization/hpc24-new-waits.json
```

Use the installed Python interpreter if the Windows alias fails. Benchmarks require the existing small HPC23 fixtures; the large fixtures are never selected. Mode regressions need the existing retained native test binaries and the transient fixture generated by validation. The mode test is supplemental, not a substitute for compiling shared tests after shared changes.

## Modified files and remaining work

Standalone `main.cpp`, new `preparation.hpp` and `numeric_input.hpp`; native `job_numeric_test.cpp`; `benchmark_hpc24.py`, `test_hpc24_validation.py`, `test_hpc24_modes.py`, `sample_hpc24_waits.ps1`; this report, optimization index link and adjacent HPC24 JSON/table evidence. Generated standalone executables rebuilt. Pre-existing unrelated repository edits retained.

The measured CPU bottleneck optimization is complete and buildable. Full disabled/enabled detailed numeric/allocation instrumentation, independently captured wait stacks/ETW, exhaustive malicious-input fuzzing, a binary prototype and a new full Godot regression campaign remain unfinished. No contiguous FEM representation change or large-model speedup is claimed. Stop here with the validated optimization and retained bounded evidence rather than launching another expensive campaign.
