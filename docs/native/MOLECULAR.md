# Molecular solver: Phase 4A

The existing MolecularDynamicsModule remains the scene controller. The owned
UniCoreMolecularSolver handles neighbor indexing, Lennard-Jones force/potential,
both Velocity-Verlet evaluations, reflective boundaries and Berendsen thermostat.
Its numerical header uses ordinary C++ containers and has no engine dependencies.
Bindings marshal packed arrays; no scene nodes, callbacks, RNG or workers enter C++.

## Algorithm contract

Neighbors are sorted by particle index to preserve the reference accumulation
order. Each pair is evaluated once. Exact-cutoff pairs are excluded; squared
separation is clamped to 0.04*sigma^2; potential uses the existing cutoff shift.
Acceleration uses max(mass,1e-12). Vector arithmetic rounds to float32 in the same
stages as single-precision Godot, with double scalar intermediates/accumulators.

Order is old forces, position update, new forces, velocity update, boundaries,
thermostat. The force cache represents the second force evaluation before boundary
and thermostat changes, matching the script. For dt below 1e-5 the integration is
skipped while boundaries/thermostat still run, matching is_zero_approx(dt).

## Native API

- configure(parameters) -> bool: partial configuration update, atomically validated.
- set_state(positions, velocities, masses) -> bool: copy into owned buffers; keeps
  the native tick counter and resets the native force cache to zero.
- advance(dt, substeps=1) -> bool: dt is the duration of each substep, not a total
  interval. 1..10000 substeps; atomically commits only when every stage is valid.
- evaluate(positions) -> Dictionary: stateless force and potential evaluation;
  returns forces and potential_energy, or an empty dictionary on rejection.
- get_snapshot() -> Dictionary: independent packed buffers with schema_version,
  units, revision, simulation_tick, positions, velocities, masses and forces.
- export_state() -> Dictionary: snapshot plus solver="molecular" and complete
  configuration. No integration history or random stream exists in this kernel.
- import_state(checkpoint) -> bool: validates exact schema/units, complete config,
  array types/counts and finite state before committing; rejection is atomic.
- clear(): drops owned state and resets its tick; configuration is retained.

Schema version is integer 1; units is the literal "simulation". Positions and
velocities use PackedVector3Array (single components); masses PackedFloat32Array;
forces PackedVector3Array; scalar parameters are Godot floats (double). Units are
consistent simulation length/mass/time, without hidden SI conversion. Revision is
a local state-commit counter, not the global simulation tick or checkpoint identity.
Import preserves the checkpoint simulation_tick but keeps a local revision history.

Configuration keys: schema_version, sigma, epsilon, cutoff_radius, particle_radius,
box_half_extent (Vector3), restitution, target_temperature, thermostat_tau,
boltzmann_constant and thermostat_enabled (bool). Native rejects nonnumeric or
nonfinite scalars, nonpositive sigma, cutoff <= 1e-6 and boxes not larger than the
particle radius. Existing restitution, tau, temperature and k_B safeguards retain
the scripted mathematical policy. Signed/zero finite masses retain the original
integrator clamp. Inputs are limited to one million particles and coordinate/cell
ratios below 1e12 to keep integer cell conversion safe. Invalid or overflowing
native advances leave the native state unchanged. Snapshots never expose internal vectors.

## Wrapper and compatibility

`compute_backend=inherit` reads ModuleManager context or physics/compute/backend.
The project setting is auto. gdscript/native/auto can be selected per instance.
A compatible solver exists once per built-in module. Script-only packages retain
the full scripted path. Generated subclasses and custom force/integrator callbacks
stay scripted. get_last_step_backend reports the last completed step's selection.

Legacy tools can edit exposed packed arrays. The wrapper therefore uploads them
at each tick boundary, advances entirely inside C++, then commits position,
velocity and force snapshots before visuals and telemetry. This compatibility
copy is included in benchmarks; removing it requires explicit tool edit commands.
Unsupported native configuration uses the scripted compatibility path. Rejected
state/advancement after a native solver was selected aborts the step and emits a
clear diagnostic; it does not rerun an overflowing step through GDScript.

Standalone boundary/thermostat/temperature facade methods remain available in
GDScript for existing tools. Their edits are reconciled before the next native
step. Presets, random initialization, insertion, visuals, sentry baseline ownership,
clock scheduling, EventBus publication and signals remain scripted. Cleanup clears
and releases the owned solver. There are no outstanding jobs to join.

Native checkpoints cover deterministic solver state only. They do not serialize
scene state, global RNG, UI settings, the shared sentry or SimulationTimeController.
The wrapper does not claim whole-module save/restore or automatic checkpoint-based
switching. Selecting a different backend between completed synchronous ticks uses
the wrapper's already committed arrays and preserves its counters and telemetry.

## Evidence and limits

Golden inputs/results are in tests/fixtures/molecular_v1.json, captured from the
explicit gdscript backend. The differential suite also compares optimized forces
with the independent brute-force reference, a 1000-step horizon, thermostat and
boundary cases, tiny dt, parameter edits, count changes, resets/spawns with
controlled draws, generated overrides, pause/step-once, cleanup, buffer ownership,
invalid inputs and checkpoint replay. Both native build configurations pass.
The independent C++ test checks an analytical force, cutoff, overlaps, atomic
rejection, replay and 1000 independent solver copies with libstdc++ assertions.
This is not an AddressSanitizer or Valgrind run.

Headless benchmarks compare whole steps including both integration stages, copies,
snapshots and optional auditing. Both auditing variants deliberately use the same
scripted sentry reductions, isolating this solver migration. Initialization is
outside timing, and no MultiMesh is allocated; graphical frame gates remain open.

Native commits now mutate existing packed containers in place so retained legacy references stay current; the expanded suite covers this behavior.
