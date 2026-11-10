class_name PhysicalIntegrator
extends RefCounted

## Abstract base class for numerical differential equation integrators.
## Integrators operate directly on packed typed arrays to achieve zero-allocation
## performance in continuous physical simulations.

const MIN_MASS: float = 1e-12

## Cached callable state for automatic arity detection without Callable.get_argument_count()
var _cached_callable: Callable = Callable()
var _cached_is_2arg: bool = false

## Optional manual override: true forces (pos, vel) evaluation, false enables auto-detection / 1-arg primary.
var velocity_dependent: bool = false

## Abstract integration method. Must be overridden by subclasses.
## [param positions]: Contiguous array of particle 3D positions, mutated in-place.
## [param velocities]: Contiguous array of particle 3D velocities, mutated in-place.
## [param masses]: Array of particle masses in simulation units.
## [param force_callable]: Callable with signature func(positions: PackedVector3Array) -> PackedVector3Array
##                         or func(positions: PackedVector3Array, velocities: PackedVector3Array) -> PackedVector3Array.
## [param dt]: Time step duration in seconds.
func integrate(
	positions: PackedVector3Array,
	velocities: PackedVector3Array,
	masses: PackedFloat32Array,
	force_callable: Callable,
	dt: float
) -> void:
	push_error("PhysicalIntegrator.integrate() is abstract and must be overridden")

## Validates the dimensional parity and non-emptiness of particle states.
func validate_state(
	positions: PackedVector3Array,
	velocities: PackedVector3Array,
	masses: PackedFloat32Array
) -> bool:
	var n: int = positions.size()
	if n == 0 or velocities.is_empty() or masses.is_empty():
		return false
	if velocities.size() != n or masses.size() != n:
		push_error("PhysicalIntegrator: Array size mismatch (pos: %d, vel: %d, mass: %d)" % [
			n, velocities.size(), masses.size()
		])
		return false
	return true

## Validates input arrays and parameters for dimensional parity and positive time step.
## Returns true if inputs are valid for integration, false otherwise.
func validate_inputs(
	positions: PackedVector3Array,
	velocities: PackedVector3Array,
	masses: PackedFloat32Array,
	dt: float
) -> bool:
	if not validate_state(positions, velocities, masses):
		return false
	if dt <= 0.0:
		push_error("PhysicalIntegrator: dt must be positive, got: %f" % dt)
		return false
	return true

## Evaluates forces using either 1-argument (pos) or 2-argument (pos, vel) force callables.
## 100% compatible with Godot 4.0.stable without relying on non-existent Callable.get_argument_count().
func _evaluate_forces(
	force_callable: Callable,
	pos: PackedVector3Array,
	vel: PackedVector3Array
) -> PackedVector3Array:
	if not force_callable.is_valid():
		push_error("PhysicalIntegrator: force_callable is not valid")
		return PackedVector3Array()
	
	# Fast path 1: Manual override enabled
	if velocity_dependent:
		var res: Variant = force_callable.call(pos, vel)
		if res is PackedVector3Array:
			return res as PackedVector3Array
		push_error("PhysicalIntegrator: force_callable must return PackedVector3Array")
		return PackedVector3Array()
	
	# Fast path 2: Cached callable arity match (zero heap allocation loop)
	if force_callable == _cached_callable:
		var res: Variant = force_callable.call(pos, vel) if _cached_is_2arg else force_callable.call(pos)
		if res is PackedVector3Array:
			return res as PackedVector3Array
		push_error("PhysicalIntegrator: force_callable must return PackedVector3Array")
		return PackedVector3Array()
	
	# Initial probe for new callable: determine arity safely without get_argument_count()
	_cached_callable = force_callable
	var n: int = pos.size()
	
	# Probe 1: 1-argument callv([pos])
	var test_1: Variant = force_callable.callv([pos])
	if test_1 is PackedVector3Array and (test_1 as PackedVector3Array).size() == n:
		_cached_is_2arg = false
		return test_1 as PackedVector3Array
	
	# Probe 2: 2-argument callv([pos, vel])
	var test_2: Variant = force_callable.callv([pos, vel])
	if test_2 is PackedVector3Array and (test_2 as PackedVector3Array).size() == n:
		_cached_is_2arg = true
		return test_2 as PackedVector3Array
	
	# Fallback: direct 1-argument call
	_cached_is_2arg = false
	var res_fb: Variant = force_callable.call(pos)
	if res_fb is PackedVector3Array:
		return res_fb as PackedVector3Array
	push_error("PhysicalIntegrator: force_callable must return PackedVector3Array")
	return PackedVector3Array()

## Releases internal scratch buffers. Subclasses can override.
func clear_buffers() -> void:
	_cached_callable = Callable()
	_cached_is_2arg = false

## Returns current allocated scratch buffer capacity in elements.
func get_buffer_capacity() -> int:
	return 0
