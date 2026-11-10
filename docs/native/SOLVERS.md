# Gravity, quantum and nuclear native contracts

All classes are RefCounted, discovered through ClassDB strings by ComputeBackend.
They have no scene nodes or GDScript callbacks inside numerical stepping. Kernels
use ordinary C++ buffers; bindings marshal packed arrays. Execution is synchronous
on the main thread. No asynchronous jobs or workers have been introduced.

Controllers preserve their public methods, inputs, visualization, signals and
clock ordering. Each owns a separate solver. Legacy mutable packed arrays are
reconciled at tick boundaries and snapshot commits update the existing containers
with clear/append_array, preserving references held by tools and generated code.
Native snapshots own independent buffers; mutating them cannot change kernel state.
Cleanup releases native state, and resetting presets drops stale native buffers.
Generated subclasses and custom force/integrator/tree implementations stay scripted.
A rejected selected-native advance aborts the controller step without rerunning it
through GDScript. Invalid nonfinite timesteps do not mutate controller state.

## Common precision and units

Native schema version is integer 1 and units is the literal simulation. There is
no implicit unit conversion. Vector buffers and existing scalar particle/wave
buffers retain float32 storage; GDScript float calculations use double scalar
intermediates. Evaluation order, packed-buffer rounding and lack of fast-math are
preserved. Native limits are validation bounds, not new scientific unit definitions.
These versions target the pinned official single-precision Godot 4.0 Windows host.

## UniCoreGravitySolver

configure(parameters), set_state(positions, velocities, masses), advance(dt,
substeps=1), evaluate(positions), get_snapshot(), export_state(), import_state(),
and clear() follow the molecular binding pattern. dt is per substep. Counts must
match and be <= 1,000,000. Inputs must be finite; position components are limited
to 1e15. Forces and potential must remain finite. Substeps are integer 1..10000.
Failed configuration, uploads, imports and advancement do not partially commit.

Configuration: schema_version, gravitational_constant, theta_crit, softening,
speed_of_light, enable_relativity, post_newtonian_mode (0..2), primary_body_idx.
Snapshot: schema_version, units, revision, simulation_tick, positions, velocities,
masses, forces. Checkpoints additionally contain solver=gravity and complete
configuration. Revision counts local state commits; simulation_tick counts native
advancements and is not the shared clock. State uploads zero the force cache.

The tree retains source insertion order, cubic bounds/padding, approximate-position
coincident handling, depth cap, child traversal order and mass policy. Both force
evaluations rebuild the tree. The implemented 1PN radial coefficient is 5*G*M/r
with zero velocity cross coefficient, exactly matching executable GDScript; it was
not replaced by the different expression in its comment. The pairwise 1PN cap of
64 sources, special-relativity condition and post-integration speed cap are kept.
This preserves existing model limitations rather than changing them during the port.

get_octree() lazily refreshes the retained scripted tree for legacy introspection;
native stepping itself does not rebuild a second scripted tree. Snapshot forces
remain the second integration evaluation before velocity limiting, as in source.
Custom integrator, tree and force callback paths remain scripted.

## UniCoreQuantumSolver

set_state(state) takes a complete flat configuration/state dictionary. Required
keys: schema_version, dimension (1 or 2), nx, nz, length, depth, barrier_center,
barrier_width, real, imag, potential. The three buffers are PackedFloat32Array.
For 1D, nx>=3 and nz=1. For 2D both dimensions are >=3. Total cells <=1,000,000;
length/depth are positive finite values <=1e15. Shapes and finite buffers/derived
observables are validated atomically.

advance(dt, substeps=1), get_snapshot(), export_state(), import_state(), clear()
operate on owned active-wave buffers. Snapshot additionally returns units,
simulation_tick, ready, density, norm, mean_position, energy, transmission and
reflection. No separate upload revision is exposed by this provisional class;
simulation_tick identifies native advances, not edits or the global clock.
Checkpoints preserve the active grid, parameters, potential and wave buffers.
They do not contain inactive controller grids, visuals or clock/telemetry state.

The 1D Cayley/Thomas method preserves float32 storage at every auxiliary array
write, with double arithmetic between reads and writes. The 2D real-then-imaginary
staggered update retains boundary behavior. Reductions use the same order and
normalization policy. In particular, 2D energy remains zero and 2D reflection
remains 1-transmission, matching the source. Initialization and mesh construction
stay scripted. Auto retains script execution below 128 cells in 1D and 256 in 2D;
explicit native bypasses these conservative size gates.

## UniCoreNuclearSolver

set_state(state, isotope_models), advance(dt), get_snapshot(), clear(). State
contains the existing packed nuclei/radiation arrays and scalar controls/counters.
Nuclear isotope keys cross as PackedStringArray; the controller retains its typed
Array[String] facade. Models are copied into native numerical records. Shapes,
binary masks, enum ranges, counts and finite values are validated before sampling.
Infinite half-lives remain valid. Existing caps of 10,000 nuclei and 20,000
radiation slots apply. Position/velocity components are bounded to 1e12; dt must
be positive finite and <=1e6. Counter-overflow risk is rejected before RNG draws.

Snapshots return schema_version, units, revision, simulation_tick, ready, scalar
controls/counters, all packed state arrays, energy, momentum, neutron_count and
packed event type/channel/position/symbol/energy/prompt-count buffers. Event data
is captured at the original decay/fission position, before kinematic movement.
Revision counts local uploads/commits; tick counts successful native advances.

Poisson decisions, alpha/beta/gamma recoil and products, induced fission, slot
reuse, spatial collision choice, containment, radiation movement/expiry, rest and
kinetic energy, nominal photon energy and momentum follow source order. The
fissile index set and neutron loop length are captured at the same stages. This
also preserves source behavior when multiple incidents hit a nucleus from the
original fissile set within one tick. Chain-reaction telemetry scheduling and
shared-sentry warning policy remain in the controller.

The thin binding calls the same Godot randf/randf_range utilities as GDScript,
without calling into GDScript. The numerical kernel accepts ordinary random-number
providers. This preserves the existing global stream and draw order; it does not
introduce an independent native RNG. Seeded tests compare exact next draws and
ordered event payloads. Worker execution is not supported for this RNG policy.

There is deliberately no complete nuclear checkpoint import/export API: engine-
global RNG state, isotope models and controller state cannot be reconstructed from
particle buffers alone. Snapshots expose rng_policy=godot_global and
rng_restorable=false; NativeInfo also reports nuclear_rng_checkpoint=false.
Reproducibility currently requires a recorded initial state/seed or controlled draw
replay. Restoring a numerical snapshot alone is not deterministic rollback. Input
validation and counter rejection consume no RNG; a later numerical failure can
consume draws even though particle state is not committed.

Any connected decay/fission listener selects the scripted path in every preference
mode, preserving listeners that mutate state or consume RNG during a reaction.
Without such listeners, the native event batch is delivered after the synchronous
commit. Auto retains script execution for fewer than 512 total slots unless active
neutrons and a present fissile isotope indicate potential fission work. This avoids
the measured marshaling penalty in small quiet simulations. Explicit native skips
that workload gate, but still respects callback/subclass compatibility guards.

## Evidence and remaining gates

Typed golden fixtures encode only data with Godot var_to_bytes/base64 so packed
precision, integer types and infinite half-lives survive serialization. They are
trusted repository fixtures from explicit gdscript execution, not runtime objects.
Differential suites cover configurations and horizons; analytical C++ tests cover
Newtonian pair force/potential, a discrete quantum eigenmode's phase/norm, and
alpha-decay energy/momentum with controlled draws. libstdc++ bounds assertions were
enabled for the standalone executable. No sanitizer or cross-platform guarantee
is implied. Full module checkpoints, owned stochastic streams, rendering/export
verification, optional generation/probe ports and final API freeze remain open.
