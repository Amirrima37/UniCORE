extends SceneTree

# Independent Forensic Integrity Verification Harness for Milestone 1 Iteration 2
# Designed and executed by Forensic Integrity Auditor (auditor_m1_it2_1)

var _passed: int = 0
var _failed: int = 0

func _init() -> void:
	print("==================================================================")
	print("AUDITOR M1-IT2: INDEPENDENT FORENSIC AUDIT HARNESS")
	print("==================================================================")
	
	test_physical_integrator_callable_dispatch()
	test_verlet_symplectic_long_term_stability()
	test_rk4_fourth_order_convergence_and_damping()
	test_simulation_time_controller_rigor()
	test_unit_converter_invariance_and_cache()
	
	print("==================================================================")
	print("AUDITOR M1-IT2 FINAL RESULTS: %d passed, %d failed" % [_passed, _failed])
	print("==================================================================")
	
	if _failed > 0:
		quit(1)
	else:
		quit(0)

func _assert(condition: bool, test_name: String) -> void:
	if condition:
		_passed += 1
		print("  [PASS] %s" % test_name)
	else:
		_failed += 1
		print("  [FAIL] %s" % test_name)

func test_physical_integrator_callable_dispatch() -> void:
	print("\n--- Test Suite 1: PhysicalIntegrator Callable Dispatch & Cache Invalidation ---")
	var integrator := PhysicalIntegrator.new()
	
	var pos := PackedVector3Array([Vector3(1, 2, 3), Vector3(4, 5, 6)])
	var vel := PackedVector3Array([Vector3(0.1, 0.2, 0.3), Vector3(0.4, 0.5, 0.6)])
	
	# 1. 1-argument callable auto-detection
	var call1: Callable = func(p: PackedVector3Array) -> PackedVector3Array:
		var f := PackedVector3Array()
		f.resize(p.size())
		for i in range(p.size()):
			f[i] = -p[i]
		return f
	
	var f_out1: PackedVector3Array = integrator._evaluate_forces(call1, pos, vel)
	_assert(f_out1.size() == 2 and f_out1[0] == Vector3(-1, -2, -3), "1-arg callable auto-detected and evaluated")
	_assert(integrator._cached_is_2arg == false, "Cached arity is 1-arg (false)")
	
	# 2. Fast-path hit for same callable
	var f_out1_fast: PackedVector3Array = integrator._evaluate_forces(call1, pos, vel)
	_assert(f_out1_fast[1] == Vector3(-4, -5, -6), "Fast-path cached 1-arg evaluation matches")
	
	# 3. Switching callable to 2-argument callable: Cache invalidation & re-probe
	var call2: Callable = func(p: PackedVector3Array, v: PackedVector3Array) -> PackedVector3Array:
		var f := PackedVector3Array()
		f.resize(p.size())
		for i in range(p.size()):
			f[i] = -p[i] - 2.0 * v[i]
		return f
	
	var f_out2: PackedVector3Array = integrator._evaluate_forces(call2, pos, vel)
	_assert(f_out2.size() == 2, "2-arg callable evaluated")
	_assert(f_out2[0].is_equal_approx(Vector3(-1.2, -2.4, -3.6)), "2-arg callable computed -p - 2*v accurately")
	_assert(integrator._cached_is_2arg == true, "Cached arity updated to 2-arg (true)")
	
	# 4. Fast-path hit for 2-argument callable
	var f_out2_fast: PackedVector3Array = integrator._evaluate_forces(call2, pos, vel)
	_assert(f_out2_fast[1].is_equal_approx(Vector3(-4.8, -6.0, -7.2)), "Fast-path cached 2-arg evaluation matches")
	
	# 5. velocity_dependent manual override
	integrator.velocity_dependent = true
	var f_out_vd: PackedVector3Array = integrator._evaluate_forces(call2, pos, vel)
	_assert(f_out_vd[0].is_equal_approx(Vector3(-1.2, -2.4, -3.6)), "velocity_dependent override works cleanly")
	
	# 6. Invalid callable handling
	var bad_call: Callable = Callable()
	var f_bad: PackedVector3Array = integrator._evaluate_forces(bad_call, pos, vel)
	_assert(f_bad.is_empty(), "Invalid callable safely returns empty array without crashing")
	
	# 7. Buffer reset
	integrator.clear_buffers()
	_assert(integrator._cached_callable == Callable() and integrator._cached_is_2arg == false, "clear_buffers resets cache")

func test_verlet_symplectic_long_term_stability() -> void:
	print("\n--- Test Suite 2: Verlet Long-Term Symplectic Invariance (10,000 steps) ---")
	var verlet := VerletIntegrator.new()
	
	var pos := PackedVector3Array([Vector3(1.0, 0.0, 0.0)])
	var vel := PackedVector3Array([Vector3(0.0, 0.0, 0.0)])
	var masses := PackedFloat32Array([1.0])
	var k: float = 1.0
	var dt: float = 0.005 # 10,000 steps = 50 seconds = ~8 full oscillations
	
	var force_calc: Callable = func(p: PackedVector3Array) -> PackedVector3Array:
		var f := PackedVector3Array()
		f.resize(p.size())
		for i in range(p.size()):
			f[i] = -k * p[i]
		return f
	
	var e0: float = 0.5 * k * pos[0].length_squared() + 0.5 * masses[0] * vel[0].length_squared()
	var max_drift: float = 0.0
	
	for step in range(10000):
		verlet.integrate(pos, vel, masses, force_calc, dt)
		var e: float = 0.5 * k * pos[0].length_squared() + 0.5 * masses[0] * vel[0].length_squared()
		var drift: float = absf((e - e0) / e0)
		if drift > max_drift:
			max_drift = drift
	
	var ef: float = 0.5 * k * pos[0].length_squared() + 0.5 * masses[0] * vel[0].length_squared()
	var final_drift: float = absf((ef - e0) / e0)
	
	print("  -> 10,000 steps max relative drift:   %0.8f" % max_drift)
	print("  -> 10,000 steps final relative drift: %0.8f" % final_drift)
	_assert(max_drift < 0.0001, "Verlet peak drift < 0.0001 over 10,000 steps (requirement < 0.001)")
	_assert(final_drift < 0.00002, "Verlet final drift < 0.00002 with zero secular growth")
	
	# Buffer size check
	_assert(verlet.get_buffer_capacity() == 1, "Verlet scratch buffer capacity is 1")
	verlet.clear_buffers()
	_assert(verlet.get_buffer_capacity() == 0, "Verlet scratch buffer cleared to 0")

func test_rk4_fourth_order_convergence_and_damping() -> void:
	print("\n--- Test Suite 3: RK4 O(dt^4) Convergence & Dissipative System ---")
	var rk4 := RK4Integrator.new()
	
	# Part A: Test 4th order convergence ratio for harmonic oscillator
	# Error should scale as dt^4. If dt is halved, error should reduce by factor of ~16.
	var k: float = 4.0
	var force_harm: Callable = func(p: PackedVector3Array) -> PackedVector3Array:
		var f := PackedVector3Array()
		f.resize(p.size())
		for i in range(p.size()):
			f[i] = -k * p[i]
		return f
	
	var t_end: float = 2.0
	
	# Run 1 with dt1 = 0.10
	var dt1: float = 0.10
	var steps1: int = int(round(t_end / dt1))
	var p1 := PackedVector3Array([Vector3(1.0, 0.0, 0.0)])
	var v1 := PackedVector3Array([Vector3(0.0, 0.0, 0.0)])
	var m1 := PackedFloat32Array([1.0])
	for s in range(steps1):
		rk4.integrate(p1, v1, m1, force_harm, dt1)
	var x1: float = p1[0].x
	var exact_x: float = cos(sqrt(k) * t_end) # x(t) = cos(2t)
	var err1: float = absf(x1 - exact_x)
	
	# Run 2 with dt2 = 0.05 (half of dt1)
	var dt2: float = 0.05
	var steps2: int = int(round(t_end / dt2))
	var p2 := PackedVector3Array([Vector3(1.0, 0.0, 0.0)])
	var v2 := PackedVector3Array([Vector3(0.0, 0.0, 0.0)])
	var m2 := PackedFloat32Array([1.0])
	for s in range(steps2):
		rk4.integrate(p2, v2, m2, force_harm, dt2)
	var x2: float = p2[0].x
	var err2: float = absf(x2 - exact_x)
	
	var convergence_ratio: float = err1 / err2 if err2 > 0.0 else 0.0
	print("  -> RK4 err(dt=0.10): %0.8f, err(dt=0.05): %0.8f, ratio: %0.4f (ideal: ~16.0)" % [err1, err2, convergence_ratio])
	_assert(convergence_ratio > 14.0 and convergence_ratio < 17.5, "RK4 convergence ratio matches O(dt^4) theoretical 16x scaling")
	
	# Part B: Damped oscillator vs exact solution
	# m*x'' + gamma*x' + k*x = 0
	# with m=1, gamma=0.5, k=4
	# omega_0 = 2, gamma/(2m) = 0.25, omega_d = sqrt(4 - 0.0625) = 1.98431348
	# x(t) = exp(-0.25*t) * cos(omega_d * t)
	var gamma: float = 0.5
	var force_damped: Callable = func(p: PackedVector3Array, v: PackedVector3Array) -> PackedVector3Array:
		var f := PackedVector3Array()
		f.resize(p.size())
		for i in range(p.size()):
			f[i] = -k * p[i] - gamma * v[i]
		return f
	
	var p_damp := PackedVector3Array([Vector3(1.0, 0.0, 0.0)])
	var v_damp := PackedVector3Array([Vector3(0.0, 0.0, 0.0)])
	var m_damp := PackedFloat32Array([1.0])
	var dt_damp: float = 0.005
	var t_damp_total: float = 4.0
	var steps_damp: int = int(round(t_damp_total / dt_damp))
	
	for s in range(steps_damp):
		rk4.integrate(p_damp, v_damp, m_damp, force_damped, dt_damp)
	
	var omega_d: float = sqrt(4.0 - 0.0625)
	# Wait: x(0) = 1, v(0) = 0.
	# For underdamped oscillator x(t) = exp(-gamma/(2m)*t) * [A*cos(omega_d*t) + B*sin(omega_d*t)]
	# x(0) = A = 1.
	# v(t) = -alpha*exp(-alpha*t)*cos(omega_d*t) - omega_d*exp(-alpha*t)*sin(omega_d*t) + B*(...)
	# v(0) = -alpha + B*omega_d = 0 => B = alpha / omega_d = 0.25 / 1.98431348 !
	# If B was omitted, x(t) was not exact for v(0)=0!
	var alpha: float = gamma / 2.0
	var B: float = alpha / omega_d
	var x_damp_exact: float = exp(-alpha * t_damp_total) * (cos(omega_d * t_damp_total) + B * sin(omega_d * t_damp_total))
	var damp_error: float = absf(p_damp[0].x - x_damp_exact)
	print("  -> Damped x_num: %0.6f, x_exact: %0.6f, error: %0.10f" % [p_damp[0].x, x_damp_exact, damp_error])
	_assert(damp_error < 1e-4, "RK4 handles velocity-dependent damping with analytical precision (< 1e-4)")

func test_simulation_time_controller_rigor() -> void:
	print("\n--- Test Suite 4: SimulationTimeController Clock Rigor & Clamping ---")
	var stc := SimulationTimeController.new()
	
	# Clamping test
	stc.time_scale = 0.00001
	_assert(stc.time_scale == 0.001, "time_scale clamped to MIN_TIME_SCALE (0.001)")
	stc.time_scale = 50000.0
	_assert(stc.time_scale == 1000.0, "time_scale clamped to MAX_TIME_SCALE (1000.0)")
	stc.time_scale = 1.0
	
	# Step once exactness
	stc.fixed_delta = 0.02
	stc.reset()
	_assert(stc.get_sim_time() == 0.0, "sim_time reset to 0.0")
	
	stc.step_once()
	_assert(is_equal_approx(stc.get_sim_time(), 0.02), "step_once advances by exactly fixed_delta (0.02s)")
	stc.step_once()
	_assert(is_equal_approx(stc.get_sim_time(), 0.04), "2nd step_once advances to exactly 0.04s")
	
	# Pause test
	stc.set_paused(true)
	_assert(stc.is_simulation_paused() == true, "Simulation is paused")
	stc._physics_process(1.0)
	_assert(is_equal_approx(stc.get_sim_time(), 0.04), "sim_time remains frozen under _physics_process while paused")
	stc.set_paused(false)
	
	# Death spiral backlog cap
	stc.max_substeps = 5
	stc.reset()
	# Inject a 2.0s massive lag spike
	stc._physics_process(2.0)
	_assert(is_equal_approx(stc.get_sim_time(), 5 * 0.02), "Lag spike ticked exactly max_substeps (5 * 0.02 = 0.10s)")
	_assert(stc._accumulator == 0.0, "Backlog dropped after exceeding max_substeps (accumulator zeroed)")
	
	stc.free()

func test_unit_converter_invariance_and_cache() -> void:
	print("\n--- Test Suite 5: UnitConverter Exactness & Cache Invalidation ---")
	var conv := UnitConverter.new()
	
	# LJ Argon test
	var r_si: float = 3.40e-10
	var r_lj: float = conv.to_simulation(UnitConverter.UnitSystem.LENNARD_JONES, UnitConverter.PhysicalQuantity.LENGTH, r_si)
	_assert(is_equal_approx(r_lj, 1.0), "1 LJ sigma converts to 1.0 reduced units")
	var r_si_back: float = conv.to_si(UnitConverter.UnitSystem.LENNARD_JONES, UnitConverter.PhysicalQuantity.LENGTH, r_lj)
	_assert(is_equal_approx(r_si_back, r_si), "LJ length round-trip exact within float precision")
	
	# Cache key test & cache invalidation
	var key: int = (int(UnitConverter.UnitSystem.LENNARD_JONES) << 8) | int(UnitConverter.PhysicalQuantity.LENGTH)
	_assert(conv._scale_cache.has(key), "Scale factor is cached")
	
	conv.configure_lennard_jones(6.80e-10, 1.656e-21, 6.6335e-26)
	_assert(conv._scale_cache.is_empty(), "configure_lennard_jones clears scale cache")
	var r_lj_new: float = conv.to_simulation(UnitConverter.UnitSystem.LENNARD_JONES, UnitConverter.PhysicalQuantity.LENGTH, 6.80e-10)
	_assert(is_equal_approx(r_lj_new, 1.0), "New sigma correctly converts to 1.0 after cache invalidation")
	
	# Vector round trip
	var vec_si := Vector3(1.2e-9, -3.4e-9, 5.6e-9)
	var vec_sim: Vector3 = conv.to_simulation_vector(UnitConverter.UnitSystem.LENNARD_JONES, UnitConverter.PhysicalQuantity.LENGTH, vec_si)
	var vec_si_back: Vector3 = conv.to_si_vector(UnitConverter.UnitSystem.LENNARD_JONES, UnitConverter.PhysicalQuantity.LENGTH, vec_sim)
	_assert(vec_si_back.is_equal_approx(vec_si), "Vector3 round-trip conversion preserves values")
	
	# Planck scale test
	var e_p_si: float = conv.get_scale_factor(UnitConverter.UnitSystem.PLANCK, UnitConverter.PhysicalQuantity.ENERGY)
	_assert(e_p_si > 1.0e9 and e_p_si < 2.5e9, "Planck energy scale ~1.956e9 J is physically sound")
	
	# Astronomical scale test
	var astro_m: float = conv.get_scale_factor(UnitConverter.UnitSystem.ASTRONOMICAL, UnitConverter.PhysicalQuantity.MASS)
	_assert(is_equal_approx(astro_m, 1.98847e30), "Astronomical mass scale matches Solar Mass")
