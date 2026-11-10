extends SceneTree

# ==============================================================================
# Empirical Verification Suite for VerletIntegrator
# Task: Milestone 1 Remediation (M1-Iteration2-2)
# ==============================================================================

const VerletIntegrator = preload("res://core/physics/verlet_integrator.gd")

var passed_count: int = 0
var failed_count: int = 0
var errors: Array[String] = []

func assert_test(condition: bool, test_name: String, details: String = "") -> void:
	if condition:
		print("  [PASS] %s" % test_name)
		passed_count += 1
	else:
		print("  [FAIL] %s - %s" % [test_name, details])
		failed_count += 1
		errors.append("%s: %s" % [test_name, details])

func _init() -> void:
	print("==================================================================")
	print("VERLET INTEGRATOR EMPIRICAL VERIFICATION HARNESS")
	print("Engine: Godot 4.0.stable")
	print("==================================================================")

	_test_instantiation_and_contract()
	_test_input_validation()
	_test_scratch_buffer_management()
	_test_harmonic_oscillator_5000_steps()
	_test_kepler_orbit_5000_steps_circular()
	_test_kepler_orbit_5000_steps_eccentric()
	_test_2arg_callable_compatibility()

	print("\n==================================================================")
	print("VERLET INTEGRATOR VERIFICATION SUMMARY")
	print("Passed: %d, Failed: %d" % [passed_count, failed_count])
	if errors.size() > 0:
		print("FAILURES:")
		for err in errors:
			print("  - %s" % err)
	print("==================================================================")

	quit(1 if failed_count > 0 else 0)

# ==============================================================================
# 1. Instantiation and Contract Parity
# ==============================================================================
func _test_instantiation_and_contract() -> void:
	print("\n--- Test Suite 1: Instantiation & Base Class Parity ---")
	var verlet := VerletIntegrator.new()
	assert_test(verlet != null, "VerletIntegrator instantiates via new()")
	assert_test(verlet is PhysicalIntegrator, "VerletIntegrator extends PhysicalIntegrator")
	assert_test(verlet.has_method("integrate"), "VerletIntegrator implements integrate()")
	assert_test(verlet.has_method("clear_buffers"), "VerletIntegrator implements clear_buffers()")
	assert_test(verlet.has_method("get_buffer_capacity"), "VerletIntegrator implements get_buffer_capacity()")

# ==============================================================================
# 2. Input Validation Parity
# ==============================================================================
func _test_input_validation() -> void:
	print("\n--- Test Suite 2: Input Validation ---")
	var verlet := VerletIntegrator.new()
	var dummy_callable := func(p: PackedVector3Array) -> PackedVector3Array: return p

	# Empty positions
	var empty_pos := PackedVector3Array()
	var empty_vel := PackedVector3Array()
	var empty_mass := PackedFloat32Array()
	verlet.integrate(empty_pos, empty_vel, empty_mass, dummy_callable, 0.01)
	assert_test(true, "Handles empty arrays without crash")

	# Zero dt
	var pos := PackedVector3Array([Vector3(1, 0, 0)])
	var vel := PackedVector3Array([Vector3(0, 0, 0)])
	var mass := PackedFloat32Array([1.0])
	verlet.integrate(pos, vel, mass, dummy_callable, 0.0)
	assert_test(pos[0] == Vector3(1, 0, 0), "Zero dt leaves state unmodified")

	# Negative dt
	verlet.integrate(pos, vel, mass, dummy_callable, -0.01)
	assert_test(pos[0] == Vector3(1, 0, 0), "Negative dt leaves state unmodified")

	# Array size mismatch
	var bad_vel := PackedVector3Array([Vector3.ZERO, Vector3.ZERO])
	verlet.integrate(pos, bad_vel, mass, dummy_callable, 0.01)
	assert_test(pos[0] == Vector3(1, 0, 0), "Array size mismatch leaves state unmodified")

# ==============================================================================
# 3. Scratch Buffer Management
# ==============================================================================
func _test_scratch_buffer_management() -> void:
	print("\n--- Test Suite 3: Scratch Buffer Management ---")
	var verlet := VerletIntegrator.new()
	assert_test(verlet.get_buffer_capacity() == 0, "Initial buffer capacity is 0")

	var pos := PackedVector3Array([Vector3(1, 0, 0), Vector3(2, 0, 0)])
	var vel := PackedVector3Array([Vector3.ZERO, Vector3.ZERO])
	var mass := PackedFloat32Array([1.0, 1.0])
	var force_fn := func(p: PackedVector3Array) -> PackedVector3Array:
		var f := PackedVector3Array()
		f.resize(p.size())
		for i in range(p.size()):
			f[i] = -p[i]
		return f

	verlet.integrate(pos, vel, mass, force_fn, 0.01)
	assert_test(verlet.get_buffer_capacity() == 2, "Buffer resized to 2 particles")

	# Expand to 5 particles
	var pos5 := PackedVector3Array([Vector3(1, 0, 0), Vector3(2, 0, 0), Vector3(3, 0, 0), Vector3(4, 0, 0), Vector3(5, 0, 0)])
	var vel5 := PackedVector3Array([Vector3.ZERO, Vector3.ZERO, Vector3.ZERO, Vector3.ZERO, Vector3.ZERO])
	var mass5 := PackedFloat32Array([1.0, 1.0, 1.0, 1.0, 1.0])
	verlet.integrate(pos5, vel5, mass5, force_fn, 0.01)
	assert_test(verlet.get_buffer_capacity() == 5, "Buffer resized to 5 particles")

	verlet.clear_buffers()
	assert_test(verlet.get_buffer_capacity() == 0, "Buffer cleared to 0 after clear_buffers()")

# ==============================================================================
# 4. Harmonic Oscillator (5,000 steps, dt=0.01, m=1, k=1)
# ==============================================================================
func _test_harmonic_oscillator_5000_steps() -> void:
	print("\n--- Test Suite 4: Harmonic Oscillator (5,000 steps) ---")
	var verlet := VerletIntegrator.new()

	var m: float = 1.0
	var k: float = 1.0
	var dt: float = 0.01
	var total_steps: int = 5000

	# Initial conditions: x(0) = 1.0, v(0) = 0.0
	var pos := PackedVector3Array([Vector3(1.0, 0.0, 0.0)])
	var vel := PackedVector3Array([Vector3(0.0, 0.0, 0.0)])
	var masses := PackedFloat32Array([m])

	var e0: float = 0.5 * m * vel[0].length_squared() + 0.5 * k * pos[0].length_squared()
	assert_test(is_equal_approx(e0, 0.5), "Initial harmonic oscillator energy E_0 = 0.5 J")

	var force_sho := func(p: PackedVector3Array) -> PackedVector3Array:
		var f := PackedVector3Array()
		f.resize(p.size())
		for i in range(p.size()):
			f[i] = -k * p[i]
		return f

	var max_drift: float = 0.0
	var min_energy: float = e0
	var max_energy: float = e0

	for step in range(total_steps):
		verlet.integrate(pos, vel, masses, force_sho, dt)
		var current_e: float = 0.5 * m * vel[0].length_squared() + 0.5 * k * pos[0].length_squared()
		var drift: float = absf((current_e - e0) / e0)
		if drift > max_drift:
			max_drift = drift
		if current_e < min_energy:
			min_energy = current_e
		if current_e > max_energy:
			max_energy = current_e

	var final_e: float = 0.5 * m * vel[0].length_squared() + 0.5 * k * pos[0].length_squared()
	var final_drift: float = absf((final_e - e0) / e0)

	print("  -> Initial energy E_0:               %.6f J" % e0)
	print("  -> Final energy E(5000):             %.6f J" % final_e)
	print("  -> Final relative drift:             %.8f (%.6f%%)" % [final_drift, final_drift * 100.0])
	print("  -> Peak relative drift:              %.8f (%.6f%%)" % [max_drift, max_drift * 100.0])
	print("  -> Energy oscillation band:          [%.6f, %.6f] (delta = %.8f)" % [min_energy, max_energy, max_energy - min_energy])

	assert_test(final_drift < 0.001,
		"SHO final relative energy drift < 0.001 (0.1%)",
		"Got final drift: %f" % final_drift
	)
	assert_test(max_drift < 0.001,
		"SHO peak relative energy drift < 0.001 across all 5,000 steps",
		"Got peak drift: %f" % max_drift
	)
	assert_test(absf(max_energy - min_energy) < 0.0001,
		"SHO shadow Hamiltonian conservation band < 0.0001 J (no secular dissipation)",
		"Got band: %f" % absf(max_energy - min_energy)
	)

# ==============================================================================
# 5. 2-Body Kepler Orbit (5,000 steps, Circular Orbit)
# ==============================================================================
func _test_kepler_orbit_5000_steps_circular() -> void:
	print("\n--- Test Suite 5: Kepler Orbit (Circular, 5,000 steps, dt=0.005) ---")
	var verlet := VerletIntegrator.new()

	var gm: float = 1.0
	var m: float = 0.001
	var r0: float = 1.0
	var v_circ: float = sqrt(gm / r0) # 1.0
	var dt: float = 0.005
	var total_steps: int = 5000

	# Circular orbit in XY plane: r = (1, 0, 0), v = (0, 1, 0)
	var pos := PackedVector3Array([Vector3(r0, 0.0, 0.0)])
	var vel := PackedVector3Array([Vector3(0.0, v_circ, 0.0)])
	var masses := PackedFloat32Array([m])

	var e0: float = 0.5 * m * vel[0].length_squared() - (gm * m) / pos[0].length()
	# E0 = 0.5 * 0.001 * 1.0 - 1.0 * 0.001 / 1.0 = 0.0005 - 0.001 = -0.0005
	assert_test(is_equal_approx(e0, -0.0005), "Initial Kepler circular energy E_0 = -0.0005 J")

	var force_kepler := func(p: PackedVector3Array) -> PackedVector3Array:
		var f := PackedVector3Array()
		f.resize(p.size())
		for i in range(p.size()):
			var r_vec: Vector3 = p[i]
			var dist: float = r_vec.length()
			if dist < 1e-6:
				dist = 1e-6
			var dist_cubed: float = dist * dist * dist
			# F = - G * M * m / r^3 * r_vec
			f[i] = -r_vec * ((gm * m) / dist_cubed)
		return f

	var max_drift: float = 0.0
	var min_energy: float = e0
	var max_energy: float = e0

	for step in range(total_steps):
		verlet.integrate(pos, vel, masses, force_kepler, dt)
		var dist: float = pos[0].length()
		var current_e: float = 0.5 * m * vel[0].length_squared() - (gm * m) / dist
		var drift: float = absf((current_e - e0) / absf(e0))
		if drift > max_drift:
			max_drift = drift
		if current_e < min_energy:
			min_energy = current_e
		if current_e > max_energy:
			max_energy = current_e

	var final_dist: float = pos[0].length()
	var final_e: float = 0.5 * m * vel[0].length_squared() - (gm * m) / final_dist
	var final_drift: float = absf((final_e - e0) / absf(e0))

	# Total simulated time = 5000 * 0.005 = 25.0 s (period T = 2*PI = 6.283s -> ~4 orbits)
	print("  -> Simulated time:                   %.2f s (~%.2f orbits)" % [total_steps * dt, (total_steps * dt) / (2.0 * PI)])
	print("  -> Initial radius:                   %.6f" % r0)
	print("  -> Final radius:                     %.6f" % final_dist)
	print("  -> Final relative energy drift:      %.8f (%.6f%%)" % [final_drift, final_drift * 100.0])
	print("  -> Peak relative energy drift:       %.8f (%.6f%%)" % [max_drift, max_drift * 100.0])

	assert_test(final_drift < 0.001,
		"Kepler circular final relative energy drift < 0.001",
		"Got final drift: %f" % final_drift
	)
	assert_test(max_drift < 0.001,
		"Kepler circular peak relative energy drift < 0.001 across all 5,000 steps",
		"Got peak drift: %f" % max_drift
	)
	assert_test(absf(final_dist - r0) < 0.01,
		"Orbital radius remains stable (drift < 1%)",
		"Radius diff: %f" % absf(final_dist - r0)
	)

# ==============================================================================
# 6. 2-Body Kepler Orbit (5,000 steps, Eccentric Orbit e = 0.3)
# ==============================================================================
func _test_kepler_orbit_5000_steps_eccentric() -> void:
	print("\n--- Test Suite 6: Kepler Orbit (Eccentric e=0.3, 5,000 steps, dt=0.002) ---")
	var verlet := VerletIntegrator.new()

	var gm: float = 1.0
	var m: float = 0.001
	var a: float = 1.0 # semi-major axis
	var e: float = 0.3 # eccentricity
	# Periapsis distance: r_p = a * (1 - e) = 0.7
	var r_p: float = a * (1.0 - e)
	# Periapsis velocity: v_p = sqrt(gm * (2/r_p - 1/a)) = sqrt(1.0 * (2/0.7 - 1/1.0)) = sqrt(2.85714 - 1) = sqrt(1.85714) ~ 1.36277
	var v_p: float = sqrt(gm * (2.0 / r_p - 1.0 / a))
	var dt: float = 0.002
	var total_steps: int = 5000

	var pos := PackedVector3Array([Vector3(r_p, 0.0, 0.0)])
	var vel := PackedVector3Array([Vector3(0.0, v_p, 0.0)])
	var masses := PackedFloat32Array([m])

	var e0: float = 0.5 * m * vel[0].length_squared() - (gm * m) / pos[0].length()

	var force_kepler := func(p: PackedVector3Array) -> PackedVector3Array:
		var f := PackedVector3Array()
		f.resize(p.size())
		for i in range(p.size()):
			var r_vec: Vector3 = p[i]
			var dist: float = r_vec.length()
			if dist < 1e-6:
				dist = 1e-6
			var dist_cubed: float = dist * dist * dist
			f[i] = -r_vec * ((gm * m) / dist_cubed)
		return f

	var max_drift: float = 0.0

	for step in range(total_steps):
		verlet.integrate(pos, vel, masses, force_kepler, dt)
		var dist: float = pos[0].length()
		var current_e: float = 0.5 * m * vel[0].length_squared() - (gm * m) / dist
		var drift: float = absf((current_e - e0) / absf(e0))
		if drift > max_drift:
			max_drift = drift

	var final_dist: float = pos[0].length()
	var final_e: float = 0.5 * m * vel[0].length_squared() - (gm * m) / final_dist
	var final_drift: float = absf((final_e - e0) / absf(e0))

	print("  -> Eccentricity e:                   %.2f" % e)
	print("  -> Simulated time:                   %.2f s (~%.2f orbits)" % [total_steps * dt, (total_steps * dt) / (2.0 * PI)])
	print("  -> Final relative energy drift:      %.8f (%.6f%%)" % [final_drift, final_drift * 100.0])
	print("  -> Peak relative energy drift:       %.8f (%.6f%%)" % [max_drift, max_drift * 100.0])

	assert_test(final_drift < 0.001,
		"Eccentric Kepler final relative energy drift < 0.001",
		"Got final drift: %f" % final_drift
	)
	assert_test(max_drift < 0.001,
		"Eccentric Kepler peak relative energy drift < 0.001",
		"Got peak drift: %f" % max_drift
	)

# ==============================================================================
# 7. 2-Argument Callable Compatibility
# ==============================================================================
func _test_2arg_callable_compatibility() -> void:
	print("\n--- Test Suite 7: 2-Argument Callable Compatibility ---")
	var verlet := VerletIntegrator.new()

	var m: float = 1.0
	var k: float = 1.0
	var dt: float = 0.01

	var pos := PackedVector3Array([Vector3(1.0, 0.0, 0.0)])
	var vel := PackedVector3Array([Vector3(0.0, 0.0, 0.0)])
	var masses := PackedFloat32Array([m])

	# Callable that takes BOTH positions and velocities (ignoring vel for conservative force)
	var force_2arg := func(p: PackedVector3Array, _v: PackedVector3Array) -> PackedVector3Array:
		var f := PackedVector3Array()
		f.resize(p.size())
		for i in range(p.size()):
			f[i] = -k * p[i]
		return f

	var e0: float = 0.5 * m * vel[0].length_squared() + 0.5 * k * pos[0].length_squared()

	for step in range(1000):
		verlet.integrate(pos, vel, masses, force_2arg, dt)

	var final_e: float = 0.5 * m * vel[0].length_squared() + 0.5 * k * pos[0].length_squared()
	var final_drift: float = absf((final_e - e0) / e0)

	print("  -> 2-arg Callable 1,000 steps final drift: %.8f (%.6f%%)" % [final_drift, final_drift * 100.0])
	assert_test(final_drift < 0.001,
		"2-argument Callable successfully integrates with drift < 0.001",
		"Got drift: %f" % final_drift
	)
