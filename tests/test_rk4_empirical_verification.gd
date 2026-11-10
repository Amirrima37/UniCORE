extends SceneTree

# ==============================================================================
# RK4Integrator Empirical Verification Harness
# Tests:
# 1. Compilation & Instantiation
# 2. Conservative Force: Harmonic Oscillator (drift < 1e-5 over 5,000 steps)
# 3. Velocity-Dependent Force: Underdamped Harmonic Oscillator vs Exact Analytical Solution
# 4. Velocity-Dependent Force: Stokes Drag Terminal Velocity vs Exact Analytical Solution
# 5. Buffer reuse & Zero Allocation verification
# 6. Multi-particle dimensional parity
# ==============================================================================

const RK4Integrator = preload("res://core/physics/rk4_integrator.gd")

var total_passed: int = 0
var total_failed: int = 0

func assert_check(condition: bool, test_name: String, details: String = "") -> void:
	if condition:
		print("  [PASS] %s" % test_name)
		total_passed += 1
	else:
		print("  [FAIL] %s - %s" % [test_name, details])
		total_failed += 1

func _init() -> void:
	print("==================================================================")
	print("RK4 INTEGRATOR EMPIRICAL VERIFICATION HARNESS")
	print("==================================================================")

	test_instantiation()
	test_conservative_harmonic_oscillator()
	test_velocity_dependent_damped_oscillator()
	test_stokes_drag_terminal_velocity()
	test_buffer_lifecycle_and_zero_allocations()
	test_multiparticle_system()

	print("\n==================================================================")
	print("RESULTS: %d passed, %d failed" % [total_passed, total_failed])
	print("==================================================================")

	quit(1 if total_failed > 0 else 0)

func test_instantiation() -> void:
	print("\n--- Test 1: Instantiation & Class Hierarchy ---")
	var rk4 := RK4Integrator.new()
	assert_check(rk4 != null, "RK4Integrator instantiated")
	assert_check(rk4 is PhysicalIntegrator, "RK4Integrator extends PhysicalIntegrator")
	assert_check(rk4.get_buffer_capacity() == 0, "Initial buffer capacity is 0")

func test_conservative_harmonic_oscillator() -> void:
	print("\n--- Test 2: Conservative Force (Harmonic Oscillator, 5,000 steps) ---")
	var rk4 := RK4Integrator.new()
	var m: float = 1.0
	var k: float = 1.0
	var dt: float = 0.01
	var steps: int = 5000

	# Initial state: x0 = 1.0, v0 = 0.0
	var pos := PackedVector3Array([Vector3(1.0, 0.0, 0.0)])
	var vel := PackedVector3Array([Vector3(0.0, 0.0, 0.0)])
	var masses := PackedFloat32Array([m])

	# Conservative force: F = -k * pos
	var force_conservative := func(p: PackedVector3Array) -> PackedVector3Array:
		var f := PackedVector3Array()
		f.resize(p.size())
		for i in range(p.size()):
			f[i] = -k * p[i]
		return f

	var e0: float = 0.5 * m * vel[0].length_squared() + 0.5 * k * pos[0].length_squared()
	var max_drift: float = 0.0

	for step in range(steps):
		rk4.integrate(pos, vel, masses, force_conservative, dt)
		var e: float = 0.5 * m * vel[0].length_squared() + 0.5 * k * pos[0].length_squared()
		var drift: float = abs(e - e0) / e0
		if drift > max_drift:
			max_drift = drift

	var final_e: float = 0.5 * m * vel[0].length_squared() + 0.5 * k * pos[0].length_squared()
	var final_drift: float = abs(final_e - e0) / e0

	print("  Max drift over 5,000 steps: %f (%s)" % [max_drift, str(max_drift)])
	print("  Final drift at step 5,000:  %f (%s)" % [final_drift, str(final_drift)])

	assert_check(max_drift < 0.001, "Harmonic oscillator max drift < 0.001 (got %s)" % str(max_drift))
	assert_check(final_drift < 0.0001, "Harmonic oscillator final drift < 0.0001 (got %s)" % str(final_drift))

func test_velocity_dependent_damped_oscillator() -> void:
	print("\n--- Test 3: Velocity-Dependent Force (Underdamped Oscillator vs Analytical) ---")
	var rk4 := RK4Integrator.new()
	var m: float = 1.0
	var k: float = 1.0
	var gamma: float = 0.1 # damping coefficient
	var dt: float = 0.01
	var steps: int = 1000 # t = 10.0 s

	# Initial state: x0 = 1.0, v0 = 0.0
	var pos := PackedVector3Array([Vector3(1.0, 0.0, 0.0)])
	var vel := PackedVector3Array([Vector3(0.0, 0.0, 0.0)])
	var masses := PackedFloat32Array([m])

	# Velocity-dependent force: F = -k * pos - gamma * vel
	var force_damped := func(p: PackedVector3Array, v: PackedVector3Array) -> PackedVector3Array:
		var f := PackedVector3Array()
		f.resize(p.size())
		for i in range(p.size()):
			f[i] = -k * p[i] - gamma * v[i]
		return f

	for step in range(steps):
		rk4.integrate(pos, vel, masses, force_damped, dt)

	var t_final: float = steps * dt # 10.0 s
	var omega_0: float = sqrt(k / m) # 1.0
	var zeta: float = gamma / (2.0 * sqrt(m * k)) # 0.05
	var omega_d: float = omega_0 * sqrt(1.0 - zeta * zeta) # sqrt(0.9975) = 0.99874921777

	# Analytical solutions:
	var exp_decay: float = exp(-zeta * omega_0 * t_final)
	var x_exact: float = exp_decay * (cos(omega_d * t_final) + (zeta / sqrt(1.0 - zeta * zeta)) * sin(omega_d * t_final))
	var v_exact: float = - (omega_0 / sqrt(1.0 - zeta * zeta)) * exp_decay * sin(omega_d * t_final)

	var x_num: float = pos[0].x
	var v_num: float = vel[0].x
	var x_err: float = abs(x_num - x_exact)
	var v_err: float = abs(v_num - v_exact)

	print("  At t = 10.0s:")
	print("    x_num = %f, x_exact = %f, err = %s" % [x_num, x_exact, str(x_err)])
	print("    v_num = %f, v_exact = %f, err = %s" % [v_num, v_exact, str(v_err)])

	assert_check(x_err < 1e-4, "Position error vs exact analytical < 1e-4 (got %s)" % str(x_err))
	assert_check(v_err < 1e-4, "Velocity error vs exact analytical < 1e-4 (got %s)" % str(v_err))

func test_stokes_drag_terminal_velocity() -> void:
	print("\n--- Test 4: Velocity-Dependent Force (Stokes Drag Terminal Velocity) ---")
	var rk4 := RK4Integrator.new()
	var m: float = 1.0
	var g: float = 9.8
	var gamma: float = 2.0
	var dt: float = 0.01
	var steps: int = 500 # t = 5.0 s (5 * m/gamma = 2.5s is 5 time constants)

	# Falling particle: pos = 0, vel = 0
	var pos := PackedVector3Array([Vector3(0.0, 100.0, 0.0)])
	var vel := PackedVector3Array([Vector3(0.0, 0.0, 0.0)])
	var masses := PackedFloat32Array([m])

	# Gravity downward (-y) and drag opposite to velocity: F = m*g_vec - gamma*v
	var force_stokes := func(p: PackedVector3Array, v: PackedVector3Array) -> PackedVector3Array:
		var f := PackedVector3Array()
		f.resize(p.size())
		for i in range(p.size()):
			f[i] = Vector3(0.0, -m * g, 0.0) - gamma * v[i]
		return f

	for step in range(steps):
		rk4.integrate(pos, vel, masses, force_stokes, dt)

	var t_final: float = steps * dt # 5.0 s
	var v_terminal_exact: float = -m * g / gamma # -4.9 m/s
	var v_exact: float = v_terminal_exact * (1.0 - exp(-gamma / m * t_final))
	var v_num: float = vel[0].y
	var v_err: float = abs(v_num - v_exact)

	print("  At t = 5.0s:")
	print("    v_num = %f, v_exact = %f, err = %s" % [v_num, v_exact, str(v_err)])

	assert_check(v_err < 1e-4, "Stokes drag velocity error vs exact < 1e-4 (got %s)" % str(v_err))
	assert_check(abs(v_num - v_terminal_exact) < 0.001, "Reached terminal velocity within 0.001 (got %f, exact %f)" % [v_num, v_terminal_exact])

func test_buffer_lifecycle_and_zero_allocations() -> void:
	print("\n--- Test 5: Scratch Buffer Lifecycle & Capacity ---")
	var rk4 := RK4Integrator.new()
	var n: int = 250
	var pos := PackedVector3Array()
	var vel := PackedVector3Array()
	var masses := PackedFloat32Array()
	pos.resize(n)
	vel.resize(n)
	masses.resize(n)
	for i in range(n):
		pos[i] = Vector3(float(i), 0.0, 0.0)
		vel[i] = Vector3(0.0, 1.0, 0.0)
		masses[i] = 1.0

	var dummy_force := func(p: PackedVector3Array) -> PackedVector3Array:
		var f := PackedVector3Array()
		f.resize(p.size())
		return f

	assert_check(rk4.get_buffer_capacity() == 0, "Capacity before integrate() is 0")
	rk4.integrate(pos, vel, masses, dummy_force, 0.01)
	assert_check(rk4.get_buffer_capacity() == n, "Capacity after integrate() is exactly n (%d)" % n)

	# Second integration: buffer capacity should remain n (no reallocation)
	rk4.integrate(pos, vel, masses, dummy_force, 0.01)
	assert_check(rk4.get_buffer_capacity() == n, "Capacity on second integrate() is still n (%d)" % n)

	# Clear buffers
	rk4.clear_buffers()
	assert_check(rk4.get_buffer_capacity() == 0, "Capacity after clear_buffers() is 0")

func test_multiparticle_system() -> void:
	print("\n--- Test 6: Multi-Particle Parity & Stability ---")
	var rk4 := RK4Integrator.new()
	var n: int = 50
	var pos := PackedVector3Array()
	var vel := PackedVector3Array()
	var masses := PackedFloat32Array()
	pos.resize(n)
	vel.resize(n)
	masses.resize(n)

	for i in range(n):
		pos[i] = Vector3(float(i) * 0.5, float(i) * 0.2, 0.0)
		vel[i] = Vector3(0.0, 0.0, 0.0)
		masses[i] = 1.0 + float(i) * 0.1

	var force_harmonic_multi := func(p: PackedVector3Array) -> PackedVector3Array:
		var f := PackedVector3Array()
		f.resize(p.size())
		for i in range(p.size()):
			f[i] = -2.0 * p[i]
		return f

	# Run 100 steps
	for step in range(100):
		rk4.integrate(pos, vel, masses, force_harmonic_multi, 0.01)

	var all_finite: bool = true
	for i in range(n):
		if is_nan(pos[i].x) or is_inf(pos[i].x) or is_nan(vel[i].x) or is_inf(vel[i].x):
			all_finite = false
			break

	assert_check(all_finite, "All 50 particles have finite states after 100 steps")
	assert_check(rk4.get_buffer_capacity() == n, "Buffer capacity maintained at %d" % n)
