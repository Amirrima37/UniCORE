class_name VerletIntegrator
extends PhysicalIntegrator

## Symplectic Velocity-Verlet numerical integrator.
## Preserves the Hamiltonian phase-space 2-form (d r ^ d p) with zero secular energy drift.
## Uses a preallocated acceleration buffer to ensure zero heap allocations inside the loop.

## Internal preallocated scratch buffer for initial accelerations (Step 1 -> Step 4).
var _a0: PackedVector3Array = PackedVector3Array()

## Advances the physical state by time step [param dt] using Velocity-Verlet integration.
## Positions and velocities are mutated in-place.
func integrate(
	positions: PackedVector3Array,
	velocities: PackedVector3Array,
	masses: PackedFloat32Array,
	force_callable: Callable,
	dt: float
) -> void:
	if positions.is_empty():
		return
	if is_zero_approx(dt):
		return
	if dt < 0.0:
		push_error("VerletIntegrator: dt must be positive, got: %f" % dt)
		return
	
	var n: int = positions.size()
	if velocities.size() != n or masses.size() != n:
		push_error("VerletIntegrator: Array size mismatch (pos: %d, vel: %d, mass: %d)" % [
			n, velocities.size(), masses.size()
		])
		return
	if not force_callable.is_valid():
		push_error("VerletIntegrator: force_callable is not valid")
		return
	
	# Preallocate or resize scratch acceleration buffer only when particle count changes
	if _a0.size() != n:
		_a0.resize(n)
	
	# Step 1: Compute initial forces F_0 = force_callable.call(positions)
	var forces_0: PackedVector3Array = _evaluate_forces(force_callable, positions, velocities)
	if forces_0.size() != n:
		push_error("VerletIntegrator: force_callable returned invalid array size at Step 1")
		return
	
	# Fused Step 1 & Step 2:
	# Compute a_0 = F_0 / m and update positions r(t + dt) = r(t) + v(t)*dt + 0.5*a_0*dt^2
	var dt_sq_half: float = 0.5 * dt * dt
	for i in range(n):
		var m: float = masses[i]
		if m < MIN_MASS:
			m = MIN_MASS
		var inv_m: float = 1.0 / m
		var a0: Vector3 = forces_0[i] * inv_m
		_a0[i] = a0
		positions[i] += velocities[i] * dt + a0 * dt_sq_half
	
	# Step 3: Compute new forces F_new = force_callable.call(positions) at new positions
	var forces_new: PackedVector3Array = _evaluate_forces(force_callable, positions, velocities)
	if forces_new.size() != n:
		push_error("VerletIntegrator: force_callable returned invalid array size at Step 3")
		return
	
	# Step 4: Compute a_new = F_new / m and update velocities v(t + dt) = v(t) + 0.5*(a_0 + a_new)*dt
	var dt_half: float = 0.5 * dt
	for i in range(n):
		var m: float = masses[i]
		if m < MIN_MASS:
			m = MIN_MASS
		var inv_m: float = 1.0 / m
		var a_new: Vector3 = forces_new[i] * inv_m
		velocities[i] += (_a0[i] + a_new) * dt_half

## Releases allocated scratch buffers.
func clear_buffers() -> void:
	_a0 = PackedVector3Array()

## Returns current allocated scratch buffer capacity in elements.
func get_buffer_capacity() -> int:
	return _a0.size()
