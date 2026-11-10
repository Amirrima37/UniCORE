# Native API (provisional version 1)

This provisional API implements conservation reductions and all four built-in
simulation cores. See MOLECULAR.md for molecular state and SOLVERS.md for gravity,
quantum and nuclear contracts. Generation, probe batching and worker interfaces
remain outside the implemented API; the complete version has not been frozen.

`UniCoreNativeInfo.get_capabilities()` returns `api_version`, `godot_cpp_revision`,
`precision` and the `particle_metrics`, `molecular_solver`, `gravity_solver`, `quantum_solver` and
`nuclear_solver` capabilities. `nuclear_rng_checkpoint` is false. Discovery uses ClassDB and rejects
unsupported versions without referencing native types in GDScript annotations.

`UniCoreParticleMetrics.reduce(positions, velocities, masses)` accepts equal-length
PackedVector3Array positions and velocities and PackedFloat32Array masses. Input
buffers are read-only and retained only for the call. Empty input returns zero
metrics. Mismatched or nonfinite input returns an empty dictionary. Finite signed
and zero masses preserve legacy reduction behavior. Results contain exactly:

| Key | Type | Units |
| --- | --- | --- |
| kinetic_energy | float (double accumulator) | mass * length squared / time squared |
| linear_momentum | Vector3 (float components) | mass * length / time |
| angular_momentum | Vector3 (float components) | mass * length squared / time |

The caller supplies consistent simulation units; this API performs no SI conversion.
Vector operations round to single precision in the existing evaluation order.
Results own their values; changing input arrays after the call cannot change results.
No scene objects, callbacks, signals, global baselines, random streams or workers
are present inside this reduction. The kernel header has no engine dependencies.

ConservationSentry retains its original public audit signature. Its exported
`compute_backend` inherits `physics/compute/backend` from ProjectSettings (`auto` by default); `native` and `auto` discover a compatible
extension and fall back when unavailable. An explicit native request still permits
fallback; tests use `--require-native` to fail instead of silently skipping parity.
Reduction rejection falls back to the original loop to preserve scripted behavior.
A backend choice is cached per sentry until that choice changes.

Empty audits neither register nor increment nor emit. Size mismatches return an
empty snapshot without incrementing. The potential callback, temperature policy,
thresholds, audit count, warning ordering, EventBus payload, cached snapshots and
energy-only `is_conserved` policy remain scripted.

The existing sentry is shared by ModuleManager's initialization context. A reset
or registration by one module still changes the baseline used by other modules.
Independent baseline ownership has deliberately not been introduced by this port.
Backend switching changes only a stateless reduction; no solver state moves.

ModuleManager includes the optional `compute_backend` preference in module initialization contexts. Existing modules may ignore this key. The shared sentry reads the same project setting when instantiated.

`auto` uses native reductions for 128 or more particles and retains the script loop below that conservative crossover. Explicit `native` bypasses the size threshold. This workstation-specific threshold should be recalibrated for other workloads.

The molecular module inherits the project/context preference, or accepts a per-instance gdscript/native/auto override. Its new native API remains discovered through ClassDB strings.
