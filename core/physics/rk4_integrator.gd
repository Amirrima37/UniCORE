class_name RK4Integrator
extends PhysicalIntegrator

## RK4Integrator: Classical 4th-Order Runge-Kutta Integrator for particle systems.
## Extends PhysicalIntegrator to provide O(dt^4) local accuracy for general, dissipative,
## and velocity-dependent physical force fields.
##
## Mathematical Formulation:
##   k1 = v,                                    l1 = F(r, v) / m
##   k2 = v + 0.5 * dt * l1,                    l2 = F(r + 0.5 * dt * k1, v + 0.5 * dt * l1) / m
##   k3 = v + 0.5 * dt * l2,                    l3 = F(r + 0.5 * dt * k2, v + 0.5 * dt * l2) / m
##   k4 = v + dt * l3,                          l4 = F(r + dt * k3, v + dt * l3) / m
##   r_new = r + (dt / 6.0) * (k1 + 2.0 * k2 + 2.0 * k3 + k4)
##   v_new = v + (dt / 6.0) * (l1 + 2.0 * l2 + 2.0 * l3 + l4)

# Persistent scratch buffers to achieve zero runtime heap allocations in the integration loop.
var _temp_pos: PackedVector3Array = PackedVector3Array()
var _temp_vel: PackedVector3Array = PackedVector3Array()
var _sum_k: PackedVector3Array = PackedVector3Array()
var _sum_l: PackedVector3Array = PackedVector3Array()
var _inv_masses: PackedFloat32Array = PackedFloat32Array()

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
		push_error("RK4Integrator: dt must be positive, got: %f" % dt)
		return

	var n: int = positions.size()
	if velocities.size() != n or masses.size() != n:
		push_error("RK4Integrator: Array size mismatch (pos: %d, vel: %d, mass: %d)" % [
			n, velocities.size(), masses.size()
		])
		return
	if not force_callable.is_valid():
		push_error("RK4Integrator: force_callable is not valid")
		return

	_ensure_buffers(n)

	# Precompute reciprocal masses with minimum mass clamping to avoid division by zero
	for i in range(n):
		var m: float = masses[i]
		_inv_masses[i] = 1.0 / (m if m > MIN_MASS else MIN_MASS)

	var half_dt: float = 0.5 * dt

	# =========================================================================
	# STAGE 1: t
	# k1 = v
	# l1 = F(r, v) / m
	# =========================================================================
	var f1: PackedVector3Array = _evaluate_forces(force_callable, positions, velocities)
	if f1.size() != n:
		push_error("RK4Integrator: force_callable returned invalid array size at stage 1")
		return

	for i in range(n):
		var k1: Vector3 = velocities[i]
		var l1: Vector3 = f1[i] * _inv_masses[i]
		_sum_k[i] = k1
		_sum_l[i] = l1
		_temp_pos[i] = positions[i] + half_dt * k1
		_temp_vel[i] = velocities[i] + half_dt * l1

	# =========================================================================
	# STAGE 2: t + 0.5 * dt
	# k2 = temp_vel (v + 0.5 * dt * l1)
	# l2 = F(temp_pos, temp_vel) / m
	# =========================================================================
	var f2: PackedVector3Array = _evaluate_forces(force_callable, _temp_pos, _temp_vel)
	if f2.size() != n:
		push_error("RK4Integrator: force_callable returned invalid array size at stage 2")
		return

	for i in range(n):
		var k2: Vector3 = _temp_vel[i]
		var l2: Vector3 = f2[i] * _inv_masses[i]
		_sum_k[i] += 2.0 * k2
		_sum_l[i] += 2.0 * l2
		_temp_pos[i] = positions[i] + half_dt * k2
		_temp_vel[i] = velocities[i] + half_dt * l2

	# =========================================================================
	# STAGE 3: t + 0.5 * dt
	# k3 = temp_vel (v + 0.5 * dt * l2)
	# l3 = F(temp_pos, temp_vel) / m
	# =========================================================================
	var f3: PackedVector3Array = _evaluate_forces(force_callable, _temp_pos, _temp_vel)
	if f3.size() != n:
		push_error("RK4Integrator: force_callable returned invalid array size at stage 3")
		return

	for i in range(n):
		var k3: Vector3 = _temp_vel[i]
		var l3: Vector3 = f3[i] * _inv_masses[i]
		_sum_k[i] += 2.0 * k3
		_sum_l[i] += 2.0 * l3
		_temp_pos[i] = positions[i] + dt * k3
		_temp_vel[i] = velocities[i] + dt * l3

	# =========================================================================
	# STAGE 4: t + dt
	# k4 = temp_vel (v + dt * l3)
	# l4 = F(temp_pos, temp_vel) / m
	# =========================================================================
	var f4: PackedVector3Array = _evaluate_forces(force_callable, _temp_pos, _temp_vel)
	if f4.size() != n:
		push_error("RK4Integrator: force_callable returned invalid array size at stage 4")
		return

	var dt_sixth: float = dt / 6.0

	# =========================================================================
	# FINAL STATE UPDATE:
	# r_new = r + (dt / 6) * (k1 + 2*k2 + 2*k3 + k4)
	# v_new = v + (dt / 6) * (l1 + 2*l2 + 2*l3 + l4)
	# =========================================================================
	for i in range(n):
		var k4: Vector3 = _temp_vel[i]
		var l4: Vector3 = f4[i] * _inv_masses[i]
		_sum_k[i] += k4
		_sum_l[i] += l4
		positions[i] += dt_sixth * _sum_k[i]
		velocities[i] += dt_sixth * _sum_l[i]

func _ensure_buffers(n: int) -> void:
	if _temp_pos.size() != n:
		_temp_pos.resize(n)
		_temp_vel.resize(n)
		_sum_k.resize(n)
		_sum_l.resize(n)
		_inv_masses.resize(n)

## Releases allocated scratch buffers.
func clear_buffers() -> void:
	_temp_pos = PackedVector3Array()
	_temp_vel = PackedVector3Array()
	_sum_k = PackedVector3Array()
	_sum_l = PackedVector3Array()
	_inv_masses = PackedFloat32Array()

## Returns current allocated scratch buffer capacity in elements.
func get_buffer_capacity() -> int:
	return _temp_pos.size()
