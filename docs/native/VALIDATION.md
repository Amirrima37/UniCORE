# Validation report

Current milestone: conservation plus molecular, gravity, quantum and nuclear
numerical cores are implemented. Both Windows builds pass 28,216 native checks.
Earlier sections retain baseline history; the current solver and package/regression
evidence appears in the Phases 4B?4D and final sections below.

## Toolchain

Windows x86_64; Godot 4.0.stable.official.92bee43ad, single precision;
Python 3.14.7; SCons 4.10.1; Qt MinGW GCC 13.1.0; godot-cpp
9d1c396c54fc3bdfcc7da4f3abcb52b14f6cce8f. The root source archive has no Git revision.
See source-hashes.json for the numerical source/build hashes.

## Correctness

The existing physics engine suite passed 88/88 assertions before and after
optional delegation. The debug and release DLLs each passed 122 contract/parity
checks. The script-only project archive passed 119 checks in a fresh directory;
three native-only checks were skipped. The independent C++ analytical kernel
executable passed. Physics features passed 14/14 and space management passed
90/90 after the module-context preference was added. The documented build wrapper
was verified for both configurations. Intentional mismatch tests emit an error diagnostic.

The broader script-backend baseline ran 32 scripts:
30 exited zero; 2 exited nonzero:

- tests/test_app_shell_suite.gd: exit 3221225477
- tests/test_multiplayer_sync_suite.gd: exit 1

6 scripts logged SCRIPT ERROR diagnostics. Some validator and self-repair
tests intentionally compile invalid code. Zero exits plus diagnostics require
review; physics interaction, for example, logs a null camera access in
_frame_camera_for_domain. These observations were made without a loaded native
extension. No root cause has been assigned to the app-shell crash or multiplayer
failure. Per-script exit codes and diagnostics are in regression-baseline.json;
raw logs are in .tools/regression. These are not a passing release regression gate.

## Performance

Whole-audit timings with the native release DLL, hosted by the official Godot
editor executable. Both backends warm up 20 audits and run 11 batches of 100 audits
per size. Signals are disabled and no potential callback runs. Results are medians
of batch means. The native compiler build had finished before this measurement.

| Particles | GDScript audit us | Native audit us | Ratio |
| --- | --- | --- | --- |
| 2 | 2.64 | 3.40 | 0.78x |
| 100 | 15.98 | 4.54 | 3.52x |
| 1000 | 138.47 | 14.05 | 9.86x |
| 10000 | 1439.68 | 116.36 | 12.37x |

Native reduction overhead is larger at two particles. The current project default
is auto; conservation retains scripted reduction below a conservative 128-particle crossover.
Explicit native can override it. This threshold is workstation-specific.

These measurements include binding overhead, input validation and scripted
snapshot math. They do not measure kernel-only time, real rendering, memory
retention, frame percentiles or complete simulation CPU time. The p95 in the JSON
report is a percentile of batch means, not frame p95. No 20% full-simulation gate
or cross-platform result is claimed. Debug and release import tables contain
KERNEL32.dll and msvcrt.dll, with compiler runtimes statically linked.

## Packaging and remaining gates

Both native and script-only project archives were produced under .tools/packages.
Fresh script-only archive tests pass without a descriptor or native DLLs.
These are project archives; executable exports and graphical startup are untested.

The full migration remains unfinished. The molecular stepping solver is now
implemented as Phase 4A below. Gravity, quantum, nuclear, generation and probe
kernels remain scripted. Complete module checkpoints, RNG serialization, optional
workers, sanitizer validation, graphical/export gates and final API freeze remain
outstanding. Production reference algorithms have not been removed.

## Phase 4A: molecular implementation

Both debug and release native libraries pass 510 checks. This includes a captured
GDScript golden fixture, brute-force force comparisons, 1000-step differential
runs, thermostat/boundaries, small dt, edits, resets and spawning with seeded draws,
pause/step-once ordering, generated subclass/custom callback fallback, repeated
cleanup, ownership, rejected invalid state/config/steps, and checkpoint replay.
The overflowing-step test intentionally emits one rejection diagnostic. The
independent C++ molecular test passes with libstdc++ bounds assertions, including
1000 independent solver copies. No sanitizer-backed memory-safety claim is made.

The project now defaults to auto after these correctness and headless CPU gates.
The molecular module falls back to GDScript when native capability is unavailable.
Its numerical and ownership contract is in MOLECULAR.md. Snapshot copies and legacy
state uploads are included in the benchmark; worker scheduling is not involved.

The following medians use the release native library and the same official Godot
host. Each mode warms up 3 ticks, then runs 7 batches (30 ticks at 2/64 particles;
3 ticks at 512/1000). Inputs reset outside each batch. dt=0.0005, thermostat off.
Audited rows use the same scripted conservation reducer on both backends. No mesh
is allocated: these are headless whole-step CPU measurements, not frame times.

| Particles | Auditing | GDScript step us | Native step us | Ratio |
| --- | --- | --- | --- | --- |
| 2 | no | 57.47 | 9.67 | 5.94x |
| 2 | yes | 89.30 | 20.53 | 4.35x |
| 64 | no | 2592.90 | 42.87 | 60.49x |
| 64 | yes | 4100.60 | 79.97 | 51.28x |
| 512 | no | 33579.00 | 602.67 | 55.72x |
| 512 | yes | 50017.33 | 1079.67 | 46.33x |
| 1000 | no | 76761.67 | 1307.67 | 58.70x |
| 1000 | yes | 114236.67 | 2138.67 | 53.41x |

These whole-step headless CPU measurements exceed the proposed 20% CPU
improvement target, including small tested particle counts. An isolated native
kernel timer was not measured; no separate kernel-only timing gate is claimed.
Rendering costs, representative user scenes and graphical frame p95 remain
unmeasured; no corresponding real-scene or production-release claim is made.

## Fresh-package validation

Both project archives were re-imported into separate fresh directories. The native
archive passes 510 molecular checks, 122 conservation checks and 14 physics feature
checks with automatic extension loading. The script-only archive passes 453
molecular fallback checks, 119 conservation checks and the same 14 feature checks
without native libraries. See molecular-package-checks.json. These are headless
project-package checks, not graphical smoke tests or executable export validation.

## Native-package regression comparison

The final native package ran 33 scripts: 31 exited zero and the same two baseline
suites failed (app-shell access violation and multiplayer synchronization exit 1).
The same six suites logged script diagnostics; there are no newly flagged suites.
The new molecular suite passes with actual native execution. This comparison does
not reclassify known baseline failures or diagnostic-bearing suites as clean.
See molecular-regression-results.json and molecular-regression-comparison.json.
The original pre-molecular baseline remains preserved in regression-baseline.json.

## Phases 4B?4D: gravity, quantum and nuclear

The three numerical cores are implemented in C++ with synchronous GDScript
controllers and selectable reference paths. The earlier remaining-work statements
above describe the molecular-only milestone; they are superseded for these cores.
All four controllers now preserve retained packed-array references on native
commits. get_positions() and wave/particle buffers continue updating in place.

Final debug and release validation each pass the following checks:

| Suite | Checks per build |
| --- | --- |
| test_native_metrics_suite.gd | 122 |
| test_native_molecular_suite.gd | 512 |
| test_native_gravity_suite.gd | 1722 |
| test_native_quantum_suite.gd | 8881 |
| test_native_nuclear_suite.gd | 16589 |
| test_native_remaining_fixtures_suite.gd | 390 |

Total: 28216 checks per build. See solver-validation-results.json.
Gravity covers force/potential, tree opening, relativistic modes, overlaps/masses,
integration, checkpoint replay, rejection and legacy views. Quantum covers both
dimensions, all five potential presets, evolution/density/observables, malformed
inputs, finite-result rejection and replay. Nuclear covers alpha/beta/gamma,
fission, rods, containment, expiry, exact RNG consumption, event order/payloads,
callback fallback and counter overflow. Typed golden snapshots provide a separate
captured oracle. The standalone C++ analytical executable passes with libstdc++
assertions. No sanitizer-backed memory-safety result is claimed.

### Headless release benchmarks

Same official Godot 4.0 host and final release DLL. Each case has 3 warmup ticks,
then 5 batches of 3 ticks; reset/initialization is outside timing. dt=0.0005.
Gravity uses the current pairwise 1PN implementation; quantum covers 1D and square
2D grids; nuclear includes quiet decay and a reactor with injected neutrons.
Signals have no subscribers and meshes are not allocated. Copy/validation costs,
legacy-array commits and controller telemetry are included. Results are medians
of batch means; p95 in the JSON is a batch-mean percentile, not frame p95.

| Workload | Size | Script us | Native us | Ratio | Auto chooses |
| --- | --- | --- | --- | --- | --- |
| gravity | 2 | 56.33 | 14.00 | 4.02x | native |
| gravity | 64 | 11229.00 | 141.67 | 79.26x | native |
| gravity | 256 | 86982.67 | 797.33 | 109.09x | native |
| gravity | 512 | 328128.33 | 2564.33 | 127.96x | native |
| quantum_1d | 9 | 47.67 | 23.67 | 2.01x | gdscript |
| quantum_1d | 128 | 273.67 | 54.67 | 5.01x | native |
| quantum_1d | 512 | 972.33 | 80.33 | 12.10x | native |
| quantum_2d | 3 | 19.00 | 18.00 | 1.06x | gdscript |
| quantum_2d | 16 | 413.33 | 27.33 | 15.12x | native |
| quantum_2d | 32 | 1144.33 | 59.00 | 19.40x | native |
| nuclear | 64 | 31.33 | 154.67 | 0.20x | gdscript |
| nuclear | 512 | 838.00 | 576.67 | 1.45x | native |
| nuclear | 1024 | 1811.67 | 945.33 | 1.92x | native |
| nuclear_fission | 64 | 743.00 | 186.00 | 3.99x | native |
| nuclear_fission | 512 | 2045.67 | 570.00 | 3.59x | native |
| nuclear_fission | 1024 | 3623.33 | 1111.00 | 3.26x | native |

See remaining-solvers-benchmark.json for raw native/script/auto timings. Explicit
native is slower for quiet 64-slot nuclear state, so auto keeps that workload
scripted. Auto still has dispatch overhead; these results do not promise a gain
for every small case. Fission, larger gravity and quantum cases improve strongly.
Absolute timings vary with CPU scheduling/load. They are headless computation
results, not graphical frame-rate or universal kernel-only claims.

Nuclear retains the global Godot RNG and marks RNG checkpoints unavailable.
Per-event listener timing is preserved through scripted compatibility selection.
See SOLVERS.md for limits, schemas, ownership and remaining release gates.

## Final all-solver package and regression checks

Fresh native and script-only archives both pass physics feature checks (14/14).
The native archive passes all six native suites with actual class loading: 28,216
checks. The script-only archive passes its reference/fallback suites without DLLs;
the native-only golden fixture checks are skipped explicitly. See
all-solvers-package-checks.json for exact per-suite counts and skip evidence.

The fresh native package ran 37 regression scripts: 35 exited zero. The app-shell
access violation and multiplayer synchronization failure match the original
baseline. The same six suites log script diagnostics; no newly failing or newly
flagged suite was introduced. Zero-exit diagnostic-bearing suites are not promoted
to clean results. See all-solvers-regression-results.json and
all-solvers-regression-comparison.json. Native input/differential suites have no
script-error diagnostics; deliberate rejection tests can emit expected error logs.

Remaining gates are full module/RNG checkpoint ownership, sanitizers and retained-
memory profiling, graphical frame timings, executable exports, any measured
initialization/probe ports, optional workers and API freeze. The known baseline
failures remain release blockers. No old numerical reference path was deleted.
