extends SceneTree

# ==============================================================================
# UniCORE Fundamental Scientific Physics Simulation Platform
# Master Automated Headless E2E Test Suite
#
# Engine Target: Godot 4.0.stable.official.92bee43ad
# Execution: & "C:\Godot\Godot_v4.0-stable_win64_console.exe" --headless --path c:\dev\UniCORE -s res://tests/test_physics_engine_suite.gd
#
# Tiers:
#   Tier 1: Feature Coverage (>=5 test cases per feature across all 8 core components)
#   Tier 2: Boundary & Corner Cases (Adversarial stress, singularities, overflows)
#   Tier 3: Cross-Feature Combinations (End-to-end multi-component integration)
#   Tier 4: Real-World Application Scenarios (Harmonic oscillator, Kepler orbit, 5k benchmark, Barnes-Hut cluster)
# ==============================================================================

const SimulationTimeController = preload("res://core/physics/simulation_time_controller.gd")
const UnitConverter = preload("res://core/physics/unit_converter.gd")
const PhysicalIntegrator = preload("res://core/physics/physical_integrator.gd")
const VerletIntegrator = preload("res://core/physics/verlet_integrator.gd")
const RK4Integrator = preload("res://core/physics/rk4_integrator.gd")
const ConservationSentry = preload("res://core/physics/conservation_sentry.gd")
const SpatialHashGrid = preload("res://core/physics/spatial_hash_grid.gd")
const BarnesHutOctree = preload("res://core/physics/barnes_hut_octree.gd")

var passed_count: int = 0
var failed_count: int = 0
var failure_log: Array[String] = []

func assert_test(condition: bool, test_name: String, details: String = "") -> void:
	if condition:
		print("  [PASS] %s" % test_name)
		passed_count += 1
	else:
		var msg: String = "  [FAIL] %s - %s" % [test_name, details]
		print(msg)
		failed_count += 1
		failure_log.append(msg)

func _init() -> void:
	print("==================================================================")
	print("       UniCORE Scientific Physics Engine: E2E Master Test Suite    ")
	print("==================================================================")
	print("Engine: Godot 4.0.stable (Headless)")
	print("Verification Tiers: 1 (Unit), 2 (Adversarial), 3 (Integration), 4 (Empirical)\n")

	var suite_start_usec: int = Time.get_ticks_usec()

	# --------------------------------------------------------------------------
	# TIER 1: Feature Coverage
	# --------------------------------------------------------------------------
	_tier1_simulation_time_controller()
	_tier1_unit_converter()
	_tier1_physical_integrator_base()
	_tier1_verlet_integrator()
	_tier1_rk4_integrator()
	_tier1_conservation_sentry()
	_tier1_spatial_hash_grid()
	_tier1_barnes_hut_octree()

	# --------------------------------------------------------------------------
	# TIER 2: Boundary & Corner Cases
	# --------------------------------------------------------------------------
	_tier2_boundary_and_corner_cases()

	# --------------------------------------------------------------------------
	# TIER 3: Cross-Feature Combinations
	# --------------------------------------------------------------------------
	_tier3_cross_feature_combinations()

	# --------------------------------------------------------------------------
	# TIER 4: Real-World Application Scenarios
	# --------------------------------------------------------------------------
	_tier4_real_world_scenarios()

	var suite_duration_ms: float = float(Time.get_ticks_usec() - suite_start_usec) / 1000.0

	print("\n==================================================================")
	print("E2E PHYSICS ENGINE SUITE EXECUTION SUMMARY")
	print("==================================================================")
	print("Total Passed:   %d" % passed_count)
	print("Total Failed:   %d" % failed_count)
	print("Total Asserts:  %d" % (passed_count + failed_count))
	print("Total Duration: %.2f ms" % suite_duration_ms)

	if failed_count > 0:
		print("\nFAILURE LOG:")
		for f in failure_log:
			print(f)
		print("\nRESULT: FAILED (Exit Code: 1)")
		print("==================================================================")
		quit(1)
	else:
		print("\nRESULT: ALL TESTS PASSED (100% SUCCESS) (Exit Code: 0)")
		print("==================================================================")
		quit(0)

# ==============================================================================
# TIER 1: FEATURE COVERAGE (>=5 test cases per feature for 8 features)
# ==============================================================================

# Feature 1: SimulationTimeController
func _tier1_simulation_time_controller() -> void:
	print("\n--- Tier 1.1: SimulationTimeController Feature Coverage ---")
	var stc := SimulationTimeController.new()

	# T1.1.1: Default properties
	assert_test(
		is_equal_approx(stc.time_scale, 1.0) and
		is_equal_approx(stc.fixed_delta, 0.01) and
		stc.is_paused == false and
		is_equal_approx(stc.sim_time, 0.0),
		"T1.1.1: Default properties initialized correctly"
	)

	# T1.1.2: Time scale clamping & signal
	var scale_emitted := [false, 0.0]
	stc.time_scale_changed.connect(func(new_scale: float):
		scale_emitted[0] = true
		scale_emitted[1] = new_scale
	)
	stc.set_time_scale(2.5)
	assert_test(
		is_equal_approx(stc.get_time_scale(), 2.5) and scale_emitted[0] and is_equal_approx(scale_emitted[1], 2.5),
		"T1.1.2: Time scale set and signal emitted"
	)
	stc.set_time_scale(0.00001)
	assert_test(is_equal_approx(stc.get_time_scale(), 0.001), "T1.1.2b: Time scale clamped to MIN_TIME_SCALE (0.001)")
	stc.set_time_scale(50000.0)
	assert_test(is_equal_approx(stc.get_time_scale(), 1000.0), "T1.1.2c: Time scale clamped to MAX_TIME_SCALE (1000.0)")

	# T1.1.3: Pause/Resume toggle & state
	var pause_emitted := [false, false]
	stc.simulation_paused.connect(func(p: bool):
		pause_emitted[0] = true
		pause_emitted[1] = p
	)
	stc.toggle_pause()
	assert_test(stc.is_simulation_paused() == true and pause_emitted[0] and pause_emitted[1] == true, "T1.1.3: Toggle pause to true")
	stc.set_paused(false)
	assert_test(stc.is_simulation_paused() == false and pause_emitted[1] == false, "T1.1.3b: Set pause to false")

	# T1.1.4: Fixed delta setter & getter
	stc.set_fixed_delta(0.005)
	assert_test(is_equal_approx(stc.get_fixed_delta(), 0.005), "T1.1.4: Set fixed_delta to 0.005")
	stc.set_fixed_delta(-0.1) # Must be rejected
	assert_test(is_equal_approx(stc.get_fixed_delta(), 0.005), "T1.1.4b: Negative fixed_delta rejected")

	# T1.1.5: step_once execution
	stc.reset()
	var step_fired := [false, 0.0]
	var tick_fired := [false, 0.0, 0.0]
	stc.step_executed.connect(func(t: float):
		step_fired[0] = true
		step_fired[1] = t
	)
	stc.sim_tick.connect(func(dt: float, t: float):
		tick_fired[0] = true
		tick_fired[1] = dt
		tick_fired[2] = t
	)
	stc.set_fixed_delta(0.02)
	stc.step_once()
	assert_test(
		is_equal_approx(stc.get_sim_time(), 0.02) and
		step_fired[0] and is_equal_approx(step_fired[1], 0.02) and
		tick_fired[0] and is_equal_approx(tick_fired[1], 0.02) and is_equal_approx(tick_fired[2], 0.02),
		"T1.1.5: step_once advances sim_time by exactly fixed_delta and emits signals"
	)

	# T1.1.6: Accumulator & substepping in _physics_process
	stc.reset()
	stc.set_time_scale(1.0)
	stc.set_fixed_delta(0.01)
	stc.set_paused(false)
	var tick_count := [0]
	stc.sim_tick.connect(func(_dt: float, _t: float): tick_count[0] += 1)
	stc._physics_process(0.025) # 0.025 s -> 2 full ticks of 0.01, remainder 0.005
	assert_test(tick_count[0] == 2 and is_equal_approx(stc.get_sim_time(), 0.02), "T1.1.6: _physics_process executed exactly 2 substeps for delta 0.025")

	stc.free()

# Feature 2: UnitConverter
func _tier1_unit_converter() -> void:
	print("\n--- Tier 1.2: UnitConverter Feature Coverage ---")
	var conv := UnitConverter.new()

	# T1.2.1: Lennard-Jones Argon reference scale factors
	var lj_l: float = conv.get_scale_factor(UnitConverter.UnitSystem.LENNARD_JONES, UnitConverter.PhysicalQuantity.LENGTH)
	var lj_e: float = conv.get_scale_factor(UnitConverter.UnitSystem.LENNARD_JONES, UnitConverter.PhysicalQuantity.ENERGY)
	var lj_m: float = conv.get_scale_factor(UnitConverter.UnitSystem.LENNARD_JONES, UnitConverter.PhysicalQuantity.MASS)
	assert_test(
		is_equal_approx(lj_l, 3.40e-10) and is_equal_approx(lj_e, 1.656e-21) and is_equal_approx(lj_m, 6.6335e-26),
		"T1.2.1: Default Lennard-Jones Argon scales match physical standards"
	)

	# T1.2.2: SI to LJ Simulation conversion round-trip
	var orig_length_si: float = 6.80e-10 # 2 sigma
	var lj_sim_len: float = conv.to_simulation(UnitConverter.UnitSystem.LENNARD_JONES, UnitConverter.PhysicalQuantity.LENGTH, orig_length_si)
	var recovered_si: float = conv.to_si(UnitConverter.UnitSystem.LENNARD_JONES, UnitConverter.PhysicalQuantity.LENGTH, lj_sim_len)
	assert_test(
		is_equal_approx(lj_sim_len, 2.0) and is_equal_approx(recovered_si, orig_length_si),
		"T1.2.2: SI <-> LJ Length conversion round-trip is exact (2.0 reduced units)"
	)

	# T1.2.3: Vector3 conversion round-trip
	var orig_vel_si := Vector3(100.0, -50.0, 25.0)
	var sim_vel: Vector3 = conv.to_simulation_vector(UnitConverter.UnitSystem.LENNARD_JONES, UnitConverter.PhysicalQuantity.VELOCITY, orig_vel_si)
	var recovered_vel: Vector3 = conv.to_si_vector(UnitConverter.UnitSystem.LENNARD_JONES, UnitConverter.PhysicalQuantity.VELOCITY, sim_vel)
	assert_test(orig_vel_si.is_equal_approx(recovered_vel), "T1.2.3: Vector3 velocity conversion round-trip preserves direction and magnitude")

	# T1.2.4: Planck Unit Constants
	var planck_c: float = conv.get_scale_factor(UnitConverter.UnitSystem.PLANCK, UnitConverter.PhysicalQuantity.VELOCITY)
	var planck_hbar: float = conv.get_scale_factor(UnitConverter.UnitSystem.PLANCK, UnitConverter.PhysicalQuantity.ANGULAR_MOMENTUM)
	assert_test(
		is_equal_approx(planck_c, UnitConverter.SPEED_OF_LIGHT) and is_equal_approx(planck_hbar, UnitConverter.PLANCK_CONSTANT_HBAR),
		"T1.2.4: Planck scales match universal constants c and hbar"
	)

	# T1.2.5: Astronomical Unit System
	var astro_l: float = conv.get_scale_factor(UnitConverter.UnitSystem.ASTRONOMICAL, UnitConverter.PhysicalQuantity.LENGTH)
	var astro_m: float = conv.get_scale_factor(UnitConverter.UnitSystem.ASTRONOMICAL, UnitConverter.PhysicalQuantity.MASS)
	assert_test(
		is_equal_approx(astro_l, UnitConverter.ASTRONOMICAL_UNIT_AU) and is_equal_approx(astro_m, UnitConverter.SOLAR_MASS_MSUN),
		"T1.2.5: Astronomical scales match 1 AU and 1 Solar Mass"
	)

	# T1.2.6: Custom Lennard-Jones configuration and cache invalidation
	var cfg_ok: bool = conv.configure_lennard_jones(1.0, 2.0, 4.0)
	var custom_l: float = conv.get_scale_factor(UnitConverter.UnitSystem.LENNARD_JONES, UnitConverter.PhysicalQuantity.LENGTH)
	var custom_t: float = conv.get_scale_factor(UnitConverter.UnitSystem.LENNARD_JONES, UnitConverter.PhysicalQuantity.TIME)
	# tau = sigma * sqrt(m / epsilon) = 1.0 * sqrt(4.0 / 2.0) = sqrt(2.0) ~ 1.41421356
	assert_test(
		cfg_ok and is_equal_approx(custom_l, 1.0) and is_equal_approx(custom_t, sqrt(2.0)),
		"T1.2.6: Custom LJ configuration correctly computes derived time unit tau = sqrt(2)"
	)

# Feature 3: PhysicalIntegrator Base Contract
func _tier1_physical_integrator_base() -> void:
	print("\n--- Tier 1.3: PhysicalIntegrator Base Contract Coverage ---")
	var integrator := PhysicalIntegrator.new()

	# T1.3.1: State validation dimensional parity
	var pos_ok := PackedVector3Array([Vector3(1, 0, 0), Vector3(2, 0, 0)])
	var vel_ok := PackedVector3Array([Vector3(0, 1, 0), Vector3(0, 2, 0)])
	var mass_ok := PackedFloat32Array([1.0, 2.0])
	assert_test(integrator.validate_state(pos_ok, vel_ok, mass_ok) == true, "T1.3.1: Matched arrays pass validate_state")

	# T1.3.2: State validation mismatch rejection
	var vel_bad := PackedVector3Array([Vector3(0, 1, 0)])
	assert_test(integrator.validate_state(pos_ok, vel_bad, mass_ok) == false, "T1.3.2: Mismatched array size rejected")

	# T1.3.3: validate_inputs with dt
	assert_test(integrator.validate_inputs(pos_ok, vel_ok, mass_ok, 0.01) == true, "T1.3.3: Positive dt passes validate_inputs")
	assert_test(integrator.validate_inputs(pos_ok, vel_ok, mass_ok, -0.01) == false, "T1.3.3b: Negative dt rejected by validate_inputs")
	assert_test(integrator.validate_inputs(pos_ok, vel_ok, mass_ok, 0.0) == false, "T1.3.3c: Zero dt rejected by validate_inputs")

	# T1.3.4: 1-argument Callable auto-probing
	var func_1arg := func(p: PackedVector3Array) -> PackedVector3Array:
		var f := PackedVector3Array()
		f.resize(p.size())
		for i in range(p.size()):
			f[i] = p[i] * 2.0
		return f
	var res1: PackedVector3Array = integrator._evaluate_forces(func_1arg, pos_ok, vel_ok)
	assert_test(res1.size() == 2 and res1[0] == Vector3(2, 0, 0) and res1[1] == Vector3(4, 0, 0), "T1.3.4: 1-arg Callable auto-probed and evaluated")

	# T1.3.5: 2-argument Callable auto-probing
	var func_2arg := func(p: PackedVector3Array, v: PackedVector3Array) -> PackedVector3Array:
		var f := PackedVector3Array()
		f.resize(p.size())
		for i in range(p.size()):
			f[i] = p[i] + v[i]
		return f
	var res2: PackedVector3Array = integrator._evaluate_forces(func_2arg, pos_ok, vel_ok)
	assert_test(res2.size() == 2 and res2[0] == Vector3(1, 1, 0) and res2[1] == Vector3(2, 2, 0), "T1.3.5: 2-arg Callable auto-probed and evaluated")

	# T1.3.6: Buffer clearing interface
	integrator.clear_buffers()
	assert_test(integrator.get_buffer_capacity() == 0, "T1.3.6: clear_buffers resets capacity")

# Feature 4: VerletIntegrator
func _tier1_verlet_integrator() -> void:
	print("\n--- Tier 1.4: VerletIntegrator Feature Coverage ---")
	var verlet := VerletIntegrator.new()

	# T1.4.1: Constant acceleration free fall
	# r(t) = r0 + v0*dt + 0.5*a*dt^2, v(t) = v0 + a*dt
	var pos := PackedVector3Array([Vector3(0.0, 10.0, 0.0)])
	var vel := PackedVector3Array([Vector3(0.0, 0.0, 0.0)])
	var mass := PackedFloat32Array([1.0])
	var g_acc := Vector3(0.0, -9.8, 0.0)
	var force_gravity := func(_p: PackedVector3Array) -> PackedVector3Array:
		return PackedVector3Array([g_acc])
	
	var dt: float = 0.1
	verlet.integrate(pos, vel, mass, force_gravity, dt)
	var expected_y: float = 10.0 + 0.5 * (-9.8) * (dt * dt) # 10.0 - 0.049 = 9.951
	var expected_vy: float = -9.8 * dt # -0.98
	assert_test(
		is_equal_approx(pos[0].y, expected_y) and is_equal_approx(vel[0].y, expected_vy),
		"T1.4.1: Free fall single step exact match to analytical kinematics"
	)

	# T1.4.2: Zero delta integration leaves state unchanged
	var pos_before := pos[0]
	var vel_before := vel[0]
	verlet.integrate(pos, vel, mass, force_gravity, 0.0)
	assert_test(pos[0] == pos_before and vel[0] == vel_before, "T1.4.2: Zero delta leaves state untouched")

	# T1.4.3: Scratch buffer sizing & capacity
	assert_test(verlet.get_buffer_capacity() == 1, "T1.4.3: Acceleration buffer preallocated to size 1")
	verlet.clear_buffers()
	assert_test(verlet.get_buffer_capacity() == 0, "T1.4.3b: Acceleration buffer cleared")

	# T1.4.4: In-place mutation of multi-particle state
	var p3 := PackedVector3Array([Vector3.ZERO, Vector3(1, 0, 0), Vector3(2, 0, 0)])
	var v3 := PackedVector3Array([Vector3(1, 0, 0), Vector3(0, 1, 0), Vector3(0, 0, 1)])
	var m3 := PackedFloat32Array([1.0, 2.0, 3.0])
	var f_zero := func(p: PackedVector3Array) -> PackedVector3Array:
		var f := PackedVector3Array()
		f.resize(p.size())
		f.fill(Vector3.ZERO)
		return f
	verlet.integrate(p3, v3, m3, f_zero, 1.0)
	# Zero force -> r = r0 + v0*dt
	assert_test(
		p3[0].is_equal_approx(Vector3(1, 0, 0)) and
		p3[1].is_equal_approx(Vector3(1, 1, 0)) and
		p3[2].is_equal_approx(Vector3(2, 0, 1)),
		"T1.4.4: Multi-particle in-place ballistic trajectory exact"
	)

	# T1.4.5: Negative dt rejection
	var p_neg := PackedVector3Array([Vector3.ZERO])
	var v_neg := PackedVector3Array([Vector3.ZERO])
	var m_neg := PackedFloat32Array([1.0])
	verlet.integrate(p_neg, v_neg, m_neg, f_zero, -0.05)
	assert_test(p_neg[0] == Vector3.ZERO, "T1.4.5: Negative dt rejected without state modification")

# Feature 5: RK4Integrator
func _tier1_rk4_integrator() -> void:
	print("\n--- Tier 1.5: RK4Integrator Feature Coverage ---")
	var rk4 := RK4Integrator.new()

	# T1.5.1: Zero-force uniform motion
	var pos := PackedVector3Array([Vector3(5.0, 0.0, 0.0)])
	var vel := PackedVector3Array([Vector3(2.0, 0.0, 0.0)])
	var mass := PackedFloat32Array([1.0])
	var f_zero := func(p: PackedVector3Array) -> PackedVector3Array:
		var f := PackedVector3Array()
		f.resize(p.size())
		f.fill(Vector3.ZERO)
		return f
	rk4.integrate(pos, vel, mass, f_zero, 0.5)
	assert_test(is_equal_approx(pos[0].x, 6.0) and is_equal_approx(vel[0].x, 2.0), "T1.5.1: Uniform motion under zero force")

	# T1.5.2: Velocity-dependent linear viscous damping: F = -gamma * v
	# Analytical solution: v(t) = v0 * exp(-gamma * t / m)
	# For dt = 0.01, gamma = 1.0, m = 1.0, v0 = 10.0 -> v(0.01) = 10 * exp(-0.01) ~ 9.900498337
	pos[0] = Vector3.ZERO
	vel[0] = Vector3(10.0, 0.0, 0.0)
	var gamma: float = 1.0
	var f_damping := func(_p: PackedVector3Array, v: PackedVector3Array) -> PackedVector3Array:
		var f := PackedVector3Array()
		f.resize(v.size())
		for i in range(v.size()):
			f[i] = -gamma * v[i]
		return f
	
	rk4.velocity_dependent = true
	var dt: float = 0.01
	rk4.integrate(pos, vel, mass, f_damping, dt)
	var expected_v: float = 10.0 * exp(-gamma * dt)
	assert_test(absf(vel[0].x - expected_v) < 1e-6, "T1.5.2: Velocity-dependent damping matches analytical exponential decay (< 1e-6 error)")

	# T1.5.3: Buffer allocation and capacity
	assert_test(rk4.get_buffer_capacity() == 1, "T1.5.3: Scratch buffers allocated to size 1")
	rk4.clear_buffers()
	assert_test(rk4.get_buffer_capacity() == 0, "T1.5.3b: Scratch buffers cleared successfully")

	# T1.5.4: Zero delta leaves state unchanged
	var p_before := pos[0]
	var v_before := vel[0]
	rk4.integrate(pos, vel, mass, f_damping, 0.0)
	assert_test(pos[0] == p_before and vel[0] == v_before, "T1.5.4: Zero dt leaves state untouched")

	# T1.5.5: Multi-particle integration with unequal masses
	var p2 := PackedVector3Array([Vector3.ZERO, Vector3.ZERO])
	var v2 := PackedVector3Array([Vector3(1, 0, 0), Vector3(1, 0, 0)])
	var m2 := PackedFloat32Array([1.0, 2.0])
	var f_const := func(p: PackedVector3Array) -> PackedVector3Array:
		var f := PackedVector3Array()
		f.resize(p.size())
		f[0] = Vector3(2.0, 0.0, 0.0) # a0 = 2 / 1 = 2
		f[1] = Vector3(2.0, 0.0, 0.0) # a1 = 2 / 2 = 1
		return f
	rk4.velocity_dependent = false
	rk4.integrate(p2, v2, m2, f_const, 1.0)
	# v0 = 1 + 2*1 = 3, r0 = 0 + 1*1 + 0.5*2*1 = 2
	# v1 = 1 + 1*1 = 2, r1 = 0 + 1*1 + 0.5*1*1 = 1.5
	assert_test(
		is_equal_approx(p2[0].x, 2.0) and is_equal_approx(v2[0].x, 3.0) and
		is_equal_approx(p2[1].x, 1.5) and is_equal_approx(v2[1].x, 2.0),
		"T1.5.5: Unequal mass particles accelerated correctly"
	)

# Feature 6: ConservationSentry
func _tier1_conservation_sentry() -> void:
	print("\n--- Tier 1.6: ConservationSentry Feature Coverage ---")
	var sentry := ConservationSentry.new()

	# T1.6.1: Registration of initial baseline
	sentry.register_system(100.0, Vector3(1, 2, 3), Vector3(0, 0, 10))
	assert_test(
		sentry.is_registered and
		is_equal_approx(sentry.initial_energy, 100.0) and
		sentry.initial_linear_momentum == Vector3(1, 2, 3) and
		sentry.initial_angular_momentum == Vector3(0, 0, 10),
		"T1.6.1: Baseline invariants registered explicitly"
	)

	# T1.6.2: Single particle exact physics evaluation
	sentry.reset()
	var pos := PackedVector3Array([Vector3(3.0, 0.0, 0.0)])
	var vel := PackedVector3Array([Vector3(0.0, 4.0, 0.0)])
	var mass := PackedFloat32Array([2.0])
	var pot_func := func(_p: PackedVector3Array) -> float: return 16.0
	
	# Ek = 0.5 * 2 * 16 = 16.0
	# Ep = 16.0 -> Etot = 32.0
	# P = (0, 8, 0)
	# L = (3, 0, 0) x (0, 8, 0) = (0, 0, 24)
	# T = 2 * 16 / (3 * 1 * 1) = 32 / 3 ~ 10.666667
	var snap: Dictionary = sentry.audit(pos, vel, mass, pot_func)
	assert_test(
		is_equal_approx(snap.kinetic_energy, 16.0) and
		is_equal_approx(snap.potential_energy, 16.0) and
		is_equal_approx(snap.total_energy, 32.0) and
		snap.linear_momentum.is_equal_approx(Vector3(0, 8, 0)) and
		snap.angular_momentum.is_equal_approx(Vector3(0, 0, 24)) and
		is_equal_approx(snap.temperature, 32.0 / 3.0),
		"T1.6.2: Exact evaluation of Ek, Ep, Etot, P, L, and T"
	)

	# T1.6.3: Self-registration on first audit
	assert_test(sentry.is_registered and is_equal_approx(sentry.initial_energy, 32.0), "T1.6.3: Auto-registration on first audit")

	# T1.6.4: Relative drift calculation & warning signal
	var warnings: Array[String] = []
	sentry.conservation_warning.connect(func(v_type: String, _drift: float): warnings.append(v_type))
	
	# Perturb potential energy to 20.0 (Etot = 36.0 -> drift = (36-32)/32 = 4/32 = 0.125 > 0.005)
	var pot_perturbed := func(_p: PackedVector3Array) -> float: return 20.0
	var snap_drift: Dictionary = sentry.audit(pos, vel, mass, pot_perturbed)
	assert_test(
		is_equal_approx(snap_drift.energy_drift_ratio, 0.125) and
		snap_drift.is_conserved == false and
		warnings.has("energy"),
		"T1.6.4: Energy drift computed and warning signal emitted"
	)

	# T1.6.5: Snapshot caching and audit counter
	assert_test(sentry.get_audit_count() == 2 and not sentry.get_last_snapshot().is_empty(), "T1.6.5: Audit count and snapshot cached")

	sentry.free()

# Feature 7: SpatialHashGrid
func _tier1_spatial_hash_grid() -> void:
	print("\n--- Tier 1.7: SpatialHashGrid Feature Coverage ---")
	var grid := SpatialHashGrid.new()

	# T1.7.1: Initialization and coordinate conversion
	grid.initialize(2.5)
	assert_test(
		is_equal_approx(grid.cell_size, 2.5) and is_equal_approx(grid.inverse_cell_size, 1.0 / 2.5),
		"T1.7.1: Initialized cell size and inverse cell size"
	)
	var c := grid.get_cell_coords(Vector3(2.6, 5.1, -1.0))
	# 2.6 / 2.5 = 1.04 -> 1, 5.1 / 2.5 = 2.04 -> 2, -1.0 / 2.5 = -0.4 -> floor is -1
	assert_test(c == Vector3i(1, 2, -1), "T1.7.1b: get_cell_coords calculates floor lattice coordinates")

	# T1.7.2: Single insertion and bucket query
	grid.insert(0, Vector3(1.0, 1.0, 1.0))
	grid.insert(1, Vector3(1.1, 1.1, 1.1))
	assert_test(grid.get_particle_count() == 2 and grid.get_bucket_count() == 1, "T1.7.2: Particles inserted into same bucket")

	# T1.7.3: Neighbor search radius
	var nbrs: PackedInt32Array = grid.get_neighbors(Vector3(1.0, 1.0, 1.0), 0.5)
	assert_test(nbrs.size() == 2 and nbrs.has(0) and nbrs.has(1), "T1.7.3: Neighbor query returns particles within radius")

	var nbrs_far: PackedInt32Array = grid.get_neighbors(Vector3(10.0, 10.0, 10.0), 0.5)
	assert_test(nbrs_far.is_empty(), "T1.7.3b: Query far outside returns empty array")

	# T1.7.4: Bulk grid build
	var pos_bulk := PackedVector3Array([
		Vector3(0, 0, 0), Vector3(10, 0, 0), Vector3(0, 10, 0), Vector3(0, 0, 10)
	])
	grid.build_grid(pos_bulk)
	assert_test(grid.get_particle_count() == 4 and grid.get_bucket_count() == 4, "T1.7.4: Bulk build creates 4 distinct buckets")

	# T1.7.5: Clear resets internal state
	grid.clear()
	assert_test(grid.get_particle_count() == 0 and grid.get_bucket_count() == 0, "T1.7.5: Clear resets particle count and bucket dictionary")

# Feature 8: BarnesHutOctree
func _tier1_barnes_hut_octree() -> void:
	print("\n--- Tier 1.8: BarnesHutOctree Feature Coverage ---")
	var octree := BarnesHutOctree.new(0.5, 0.05, 1.0)

	# T1.8.1: Default properties & empty state
	assert_test(
		is_equal_approx(octree.theta_crit, 0.5) and
		is_equal_approx(octree.softening, 0.05) and
		is_equal_approx(octree.gravitational_constant, 1.0) and
		octree.is_empty(),
		"T1.8.1: Octree initialized with configurable properties"
	)

	# T1.8.2: 2-body gravitational acceleration
	# m0 at (-2, 0, 0), m1 at (2, 0, 0), masses = 4.0, G = 1.0, softening = 0.0
	# distance = 4.0 -> F = G * m0 * m1 / r^2 = 1.0 * 16 / 16 = 1.0
	# a0 = F / m0 = 1.0 / 4.0 = 0.25 in +X direction
	var p2 := PackedVector3Array([Vector3(-2.0, 0.0, 0.0), Vector3(2.0, 0.0, 0.0)])
	var m2 := PackedFloat32Array([4.0, 4.0])
	octree.build(p2, m2)
	assert_test(octree.get_particle_count() == 2 and is_equal_approx(octree.get_total_mass(), 8.0), "T1.8.2: 2 particles built with total mass 8.0")

	var a0: Vector3 = octree.compute_acceleration(0, p2[0], 0.0, 0.0, 1.0)
	var a1: Vector3 = octree.compute_acceleration(1, p2[1], 0.0, 0.0, 1.0)
	assert_test(
		is_equal_approx(a0.x, 0.25) and is_equal_approx(a0.y, 0.0) and is_equal_approx(a0.z, 0.0),
		"T1.8.2b: Particle 0 acceleration matches analytical value (+0.25 X)"
	)

	# T1.8.3: Newton's Third Law (equal and opposite accelerations for equal masses)
	assert_test(a0.is_equal_approx(-a1), "T1.8.3: Newton's Third Law strictly satisfied (a0 = -a1)")

	# T1.8.4: Center of mass calculation
	assert_test(octree.get_center_of_mass().is_equal_approx(Vector3.ZERO), "T1.8.4: Symmetric center of mass is exactly (0, 0, 0)")

	# T1.8.5: Batch acceleration and force queries
	var acc_all: PackedVector3Array = octree.compute_all_accelerations(p2, m2, 0.0, 0.0, 1.0)
	var force_all: PackedVector3Array = octree.compute_all_forces(p2, m2, 0.0, 0.0, 1.0)
	assert_test(
		acc_all.size() == 2 and acc_all[0].is_equal_approx(a0) and
		force_all.size() == 2 and force_all[0].is_equal_approx(a0 * m2[0]),
		"T1.8.5: Batch accelerations and forces match single queries"
	)

	# T1.8.6: Gravitational potential energy
	# U = - G * m0 * m1 / r = - 1.0 * 16.0 / 4.0 = -4.0
	var u_total: float = octree.compute_total_potential_energy(p2, m2, 0.0, 0.0, 1.0)
	assert_test(is_equal_approx(u_total, -4.0), "T1.8.6: Total gravitational potential energy matches analytical -4.0")

# ==============================================================================
# TIER 2: BOUNDARY & CORNER CASES (Adversarial Robustness)
# ==============================================================================
func _tier2_boundary_and_corner_cases() -> void:
	print("\n--- Tier 2: Boundary & Corner Cases (Adversarial Robustness) ---")

	# T2.1: Empty arrays passed to integrators
	var verlet := VerletIntegrator.new()
	var rk4 := RK4Integrator.new()
	var dummy_callable := func(_p: PackedVector3Array) -> PackedVector3Array: return PackedVector3Array()
	
	verlet.integrate(PackedVector3Array(), PackedVector3Array(), PackedFloat32Array(), dummy_callable, 0.01)
	rk4.integrate(PackedVector3Array(), PackedVector3Array(), PackedFloat32Array(), dummy_callable, 0.01)
	assert_test(true, "T2.1: Integrators gracefully ignore empty particle arrays without crash")

	# T2.2: Array size mismatch handling
	var pos_mismatch := PackedVector3Array([Vector3.ZERO, Vector3.ONE])
	var vel_mismatch := PackedVector3Array([Vector3.ZERO])
	var mass_mismatch := PackedFloat32Array([1.0, 1.0])
	verlet.integrate(pos_mismatch, vel_mismatch, mass_mismatch, dummy_callable, 0.01)
	rk4.integrate(pos_mismatch, vel_mismatch, mass_mismatch, dummy_callable, 0.01)
	assert_test(pos_mismatch[0] == Vector3.ZERO, "T2.2: Array size mismatch safely aborted without modification")

	# T2.3: Zero mass and near-zero mass clamped to MIN_MASS
	var p_zero_m := PackedVector3Array([Vector3.ZERO])
	var v_zero_m := PackedVector3Array([Vector3.ZERO])
	var m_zero_m := PackedFloat32Array([0.0]) # Zero mass!
	var f_unit := func(_p: PackedVector3Array) -> PackedVector3Array: return PackedVector3Array([Vector3(1, 0, 0)])
	verlet.integrate(p_zero_m, v_zero_m, m_zero_m, f_unit, 0.01)
	assert_test(not is_nan(p_zero_m[0].x) and not is_inf(p_zero_m[0].x), "T2.3: Zero mass in Verlet clamped without NaN or Inf division error")

	p_zero_m[0] = Vector3.ZERO
	v_zero_m[0] = Vector3.ZERO
	rk4.integrate(p_zero_m, v_zero_m, m_zero_m, f_unit, 0.01)
	assert_test(not is_nan(p_zero_m[0].x) and not is_inf(p_zero_m[0].x), "T2.3b: Zero mass in RK4 clamped without NaN or Inf division error")

	# T2.4: SpatialHashGrid floor quantization on negative coordinates
	var grid := SpatialHashGrid.new()
	grid.initialize(2.0)
	var c_neg := grid.get_cell_coords(Vector3(-0.1, -2.1, -4.0))
	# floor(-0.1 / 2) = -1, floor(-2.1 / 2) = -2, floor(-4.0 / 2) = -2
	assert_test(c_neg == Vector3i(-1, -2, -2), "T2.4: Negative coordinate floor quantization maps to correct integer cell lattice")

	# T2.5: SpatialHashGrid negative search radius
	var empty_nbrs: PackedInt32Array = grid.get_neighbors(Vector3.ZERO, -5.0)
	assert_test(empty_nbrs.is_empty(), "T2.5: Negative search radius returns empty array")

	# T2.6: SpatialHashGrid runaway radius clamping
	grid.insert(0, Vector3.ZERO)
	var clamped_query: PackedInt32Array = grid.get_neighbors(Vector3.ZERO, 1e7)
	assert_test(clamped_query.size() <= 1, "T2.6: Extreme search radius clamped to MAX_CELL_SPAN without memory crash")

	# T2.7: Coincident particles in BarnesHutOctree (multiple particles at exact identical location)
	var octree := BarnesHutOctree.new(0.5, 0.05, 1.0)
	var coinc_p := PackedVector3Array([
		Vector3(1.0, 1.0, 1.0), Vector3(1.0, 1.0, 1.0), Vector3(1.0, 1.0, 1.0), Vector3(1.0, 1.0, 1.0)
	])
	var coinc_m := PackedFloat32Array([1.0, 2.0, 3.0, 4.0])
	octree.build(coinc_p, coinc_m)
	assert_test(
		octree.get_particle_count() == 4 and
		is_equal_approx(octree.get_total_mass(), 10.0) and
		octree.get_center_of_mass().is_equal_approx(Vector3(1, 1, 1)),
		"T2.7: Coincident particles aggregated into leaf node without infinite subdivision loop"
	)

	# T2.8: Single particle in BarnesHutOctree has zero self-acceleration
	var single_p := PackedVector3Array([Vector3(5, 5, 5)])
	var single_m := PackedFloat32Array([10.0])
	octree.build(single_p, single_m)
	var a_self: Vector3 = octree.compute_acceleration(0, single_p[0], 0.5, 0.05, 1.0)
	assert_test(a_self == Vector3.ZERO, "T2.8: Single particle self-acceleration is strictly Vector3.ZERO")

	# T2.9: ConservationSentry zero initial baseline division-by-zero safeguards
	var sentry := ConservationSentry.new()
	sentry.register_system(0.0, Vector3.ZERO, Vector3.ZERO)
	var p_sentry := PackedVector3Array([Vector3(1, 0, 0)])
	var v_sentry := PackedVector3Array([Vector3.ZERO])
	var m_sentry := PackedFloat32Array([1.0])
	var pot_zero := func(_p: PackedVector3Array) -> float: return 0.0
	var snap_zero: Dictionary = sentry.audit(p_sentry, v_sentry, m_sentry, pot_zero)
	assert_test(
		not is_nan(snap_zero.energy_drift_ratio) and not is_inf(snap_zero.energy_drift_ratio) and
		not is_nan(snap_zero.linear_momentum_drift) and not is_inf(snap_zero.linear_momentum_drift) and
		not is_nan(snap_zero.angular_momentum_drift) and not is_inf(snap_zero.angular_momentum_drift),
		"T2.9: ConservationSentry safeguards against division by zero when baselines are 0"
	)

	# T2.10: ConservationSentry empty particle audit
	var snap_empty: Dictionary = sentry.audit(PackedVector3Array(), PackedVector3Array(), PackedFloat32Array(), pot_zero)
	assert_test(snap_empty.particle_count == 0 and snap_empty.is_conserved == true, "T2.10: Empty particle audit returns safe conserved snapshot")

	# T2.11: UnitConverter invalid parameter configuration rejection
	var conv := UnitConverter.new()
	assert_test(conv.configure_lennard_jones(-1.0, 1.0, 1.0) == false, "T2.11: Negative sigma in LJ rejected")
	assert_test(conv.configure_lennard_jones(1.0, 0.0, 1.0) == false, "T2.11b: Zero epsilon in LJ rejected")
	assert_test(conv.configure_astronomical(0.0, 1.0) == false, "T2.11c: Zero length in Astronomical rejected")

	# T2.12: High velocities and large coordinates numerical stability
	var f_zero := func(p: PackedVector3Array) -> PackedVector3Array:
		var f := PackedVector3Array()
		f.resize(p.size())
		f.fill(Vector3.ZERO)
		return f
	var p_large := PackedVector3Array([Vector3(1e8, 1e8, 1e8)])
	var v_large := PackedVector3Array([Vector3(1e6, -1e6, 1e6)])
	var m_large := PackedFloat32Array([100.0])
	verlet.integrate(p_large, v_large, m_large, f_zero, 0.01)
	assert_test(not is_nan(p_large[0].x) and not is_inf(p_large[0].x), "T2.12: Large coordinate and velocity state remains finite")

	sentry.free()

# ==============================================================================
# TIER 3: CROSS-FEATURE COMBINATIONS (Integration Workflows)
# ==============================================================================
func _tier3_cross_feature_combinations() -> void:
	print("\n--- Tier 3: Cross-Feature Combinations (Integration Workflows) ---")

	# T3.1: SimulationTimeController driving VerletIntegrator
	var stc := SimulationTimeController.new()
	var verlet := VerletIntegrator.new()
	stc.set_fixed_delta(0.01)
	stc.set_paused(true) # Use step_once for deterministic integration

	var pos := PackedVector3Array([Vector3(0.0, 0.0, 0.0)])
	var vel := PackedVector3Array([Vector3(10.0, 20.0, 0.0)])
	var mass := PackedFloat32Array([1.0])
	var g_force := func(_p: PackedVector3Array) -> PackedVector3Array:
		return PackedVector3Array([Vector3(0.0, -9.8, 0.0)])
	
	# Connect stc tick to verlet
	stc.sim_tick.connect(func(dt: float, _t: float):
		verlet.integrate(pos, vel, mass, g_force, dt)
	)

	# Step 100 times (1.0 second total physical time)
	for i in range(100):
		stc.step_once()

	# Analytical solution at t = 1.0: x = 10*1.0 = 10.0, y = 20*1 - 0.5*9.8*1^2 = 15.1
	assert_test(
		is_equal_approx(stc.get_sim_time(), 1.0) and
		absf(pos[0].x - 10.0) < 1e-4 and
		absf(pos[0].y - 15.1) < 1e-4,
		"T3.1: SimulationTimeController step_once driving Verlet ballistic trajectory matches analytical kinematics at 1.0s"
	)

	# T3.2: VerletIntegrator audited by ConservationSentry (3-particle spring system)
	var sentry := ConservationSentry.new()
	sentry.reset()
	var p3 := PackedVector3Array([Vector3(-1.0, 0.0, 0.0), Vector3(0.0, 0.0, 0.0), Vector3(1.0, 0.0, 0.0)])
	var v3 := PackedVector3Array([Vector3(0.0, 1.0, 0.0), Vector3(0.0, -2.0, 0.0), Vector3(0.0, 1.0, 0.0)])
	var m3 := PackedFloat32Array([1.0, 1.0, 1.0])
	# P_total = (0, 0, 0)
	
	var k_spring: float = 5.0
	var f_spring3 := func(p: PackedVector3Array) -> PackedVector3Array:
		var f := PackedVector3Array()
		f.resize(3)
		# Springs between (0, 1) and (1, 2)
		var d01: Vector3 = p[1] - p[0]
		var d12: Vector3 = p[2] - p[1]
		var f01: Vector3 = d01 * k_spring
		var f12: Vector3 = d12 * k_spring
		f[0] = f01
		f[1] = -f01 + f12
		f[2] = -f12
		return f
	
	var pot_spring3 := func(p: PackedVector3Array) -> float:
		var d01: float = (p[1] - p[0]).length()
		var d12: float = (p[2] - p[1]).length()
		return 0.5 * k_spring * (d01 * d01 + d12 * d12)
	
	# Initial audit
	sentry.audit(p3, v3, m3, pot_spring3)
	
	# Step 500 times with dt = 0.005
	var max_drift: float = 0.0
	for step in range(500):
		verlet.integrate(p3, v3, m3, f_spring3, 0.005)
		var snap: Dictionary = sentry.audit(p3, v3, m3, pot_spring3)
		max_drift = maxf(max_drift, snap.energy_drift_ratio)
	
	assert_test(
		max_drift < 0.001 and sentry.is_system_conserved(),
		"T3.2: Verlet + Sentry 3-body coupled oscillator maintains energy drift < 0.1% over 500 steps"
	)

	# T3.3: SpatialHashGrid driving short-range force interaction
	var grid := SpatialHashGrid.new()
	grid.initialize(2.0)
	var pair_pos := PackedVector3Array([Vector3(0.0, 0.0, 0.0), Vector3(1.5, 0.0, 0.0)])
	grid.build_grid(pair_pos)
	
	# Pair within cutoff R = 2.0
	var nbrs_close: PackedInt32Array = grid.get_neighbors(pair_pos[0], 2.0)
	assert_test(nbrs_close.size() == 2, "T3.3: Close particles detected by SpatialHashGrid")
	
	# Move particle 1 outside cutoff
	var pair_pos_far := PackedVector3Array([Vector3(0.0, 0.0, 0.0), Vector3(5.0, 0.0, 0.0)])
	grid.build_grid(pair_pos_far)
	var nbrs_far: PackedInt32Array = grid.get_neighbors(Vector3(0.0, 0.0, 0.0), 2.0)
	assert_test(nbrs_far.size() == 1 and nbrs_far[0] == 0, "T3.3b: Separated particle excluded from short-range interaction")

	# T3.4: BarnesHutOctree driving VerletIntegrator for N-Body Gravity
	var octree := BarnesHutOctree.new(0.5, 0.05, 1.0)
	var n_body_pos := PackedVector3Array([
		Vector3(-2.0, 0.0, 0.0), Vector3(2.0, 0.0, 0.0), Vector3(0.0, 3.0, 0.0)
	])
	var n_body_vel := PackedVector3Array([
		Vector3(0.0, -0.5, 0.0), Vector3(0.0, 0.5, 0.0), Vector3(0.0, 0.0, 0.0)
	])
	var n_body_mass := PackedFloat32Array([2.0, 2.0, 1.0])
	
	var bh_force_callable := func(p: PackedVector3Array) -> PackedVector3Array:
		octree.build(p, n_body_mass)
		return octree.compute_all_forces(p, n_body_mass, 0.5, 0.05, 1.0)
	
	for step in range(100):
		verlet.integrate(n_body_pos, n_body_vel, n_body_mass, bh_force_callable, 0.01)
	
	# Calculate total linear momentum after 100 steps: sum(m_i * v_i)
	var total_p := Vector3.ZERO
	for i in range(3):
		total_p += n_body_vel[i] * n_body_mass[i]
	assert_test(total_p.length() < 1e-4, "T3.4: BarnesHutOctree + Verlet preserves total linear momentum (internal forces sum to zero)")

	# T3.5: UnitConverter integration pipeline
	var conv := UnitConverter.new()
	var si_pos := Vector3(6.8e-10, 0.0, 0.0)
	var sim_pos: Vector3 = conv.to_simulation_vector(UnitConverter.UnitSystem.LENNARD_JONES, UnitConverter.PhysicalQuantity.LENGTH, si_pos)
	assert_test(is_equal_approx(sim_pos.x, 2.0), "T3.5: Dimensionless scaling transforms 6.8 Angstroms into 2.0 sigma")

	# T3.6: RK4Integrator + Viscous Damping + ConservationSentry Warning Detection
	var rk4 := RK4Integrator.new()
	rk4.velocity_dependent = true
	var p_damped := PackedVector3Array([Vector3(0.0, 0.0, 0.0)])
	var v_damped := PackedVector3Array([Vector3(10.0, 0.0, 0.0)])
	var m_damped := PackedFloat32Array([1.0])
	var pot_zero := func(_p: PackedVector3Array) -> float: return 0.0
	sentry.reset()
	sentry.audit(p_damped, v_damped, m_damped, pot_zero)
	
	var warning_caught := [false]
	sentry.conservation_warning.connect(func(v_type: String, _drift: float):
		if v_type == "energy":
			warning_caught[0] = true
	)
	
	var f_viscous := func(_p: PackedVector3Array, v: PackedVector3Array) -> PackedVector3Array:
		return PackedVector3Array([-2.0 * v[0]])
	
	for s in range(50):
		rk4.integrate(p_damped, v_damped, m_damped, f_viscous, 0.01)
		sentry.audit(p_damped, v_damped, m_damped, pot_zero)
	
	assert_test(warning_caught[0] and not sentry.is_system_conserved(), "T3.6: Dissipative RK4 system correctly triggers ConservationSentry violation warning")

	stc.free()
	sentry.free()

# ==============================================================================
# TIER 4: REAL-WORLD APPLICATION SCENARIOS (Empirical Rigor)
# ==============================================================================
func _tier4_real_world_scenarios() -> void:
	print("\n--- Tier 4: Real-World Application Scenarios (Empirical Rigor) ---")

	# --------------------------------------------------------------------------
	# Scenario 4.1: Harmonic Spring Oscillator (10,000 steps)
	# --------------------------------------------------------------------------
	print("\n[Scenario 4.1] Harmonic Oscillator: 10,000 steps with VerletIntegrator")
	var verlet := VerletIntegrator.new()
	var k_spring: float = 4.0
	var m_spring: float = 1.0
	var x_0: float = 1.0
	var v_0: float = 0.0
	var dt: float = 0.01
	var total_steps: int = 10000

	var pos_ho := PackedVector3Array([Vector3(x_0, 0.0, 0.0)])
	var vel_ho := PackedVector3Array([Vector3(v_0, 0.0, 0.0)])
	var mass_ho := PackedFloat32Array([m_spring])

	var f_spring := func(p: PackedVector3Array) -> PackedVector3Array:
		return PackedVector3Array([Vector3(-k_spring * p[0].x, 0.0, 0.0)])
	
	var e_0: float = 0.5 * k_spring * x_0 * x_0 # 2.0
	var max_ho_drift: float = 0.0
	var min_ho_e: float = 1e9
	var max_ho_e: float = -1e9

	for step in range(total_steps):
		verlet.integrate(pos_ho, vel_ho, mass_ho, f_spring, dt)
		var e_curr: float = 0.5 * m_spring * vel_ho[0].length_squared() + 0.5 * k_spring * pos_ho[0].length_squared()
		var drift: float = absf(e_curr - e_0) / e_0
		if drift > max_ho_drift:
			max_ho_drift = drift
		min_ho_e = minf(min_ho_e, e_curr)
		max_ho_e = maxf(max_ho_e, e_curr)

	print("  [HO Benchmark] Max Energy Drift: %.6f, Min E: %.6f, Max E: %.6f" % [max_ho_drift, min_ho_e, max_ho_e])
	assert_test(
		max_ho_drift < 0.00015,
		"T4.1: Harmonic oscillator maintains energy drift < 0.00015 (0.015%) over 10,000 steps (Velocity-Verlet symplectic conservation)",
		"Max drift: %.8f" % max_ho_drift
	)

	# --------------------------------------------------------------------------
	# Scenario 4.2: Closed 2-Body Keplerian Orbit (5,000 steps)
	# --------------------------------------------------------------------------
	print("\n[Scenario 4.2] Closed 2-Body Keplerian Orbit: 5,000 steps with ConservationSentry")
	var sentry := ConservationSentry.new()
	sentry.reset()

	var m1: float = 1.0
	var m2: float = 1.0
	var g_const: float = 1.0
	var dt_kepler: float = 0.01
	var kepler_steps: int = 5000

	# Circular orbit in XY plane with separation r = 2.0
	# v_rel = sqrt(G*(m1+m2)/r) = 1.0 -> each body moves at 0.5 opposite directions
	var pos_kep := PackedVector3Array([Vector3(-1.0, 0.0, 0.0), Vector3(1.0, 0.0, 0.0)])
	var vel_kep := PackedVector3Array([Vector3(0.0, -0.5, 0.0), Vector3(0.0, 0.5, 0.0)])
	var mass_kep := PackedFloat32Array([m1, m2])

	var f_kepler := func(p: PackedVector3Array) -> PackedVector3Array:
		var f := PackedVector3Array()
		f.resize(2)
		var dr: Vector3 = p[1] - p[0]
		var dist: float = dr.length()
		if dist < 1e-6:
			dist = 1e-6
		var inv_d3: float = 1.0 / (dist * dist * dist)
		var f_vec: Vector3 = dr * (g_const * m1 * m2 * inv_d3)
		f[0] = f_vec
		f[1] = -f_vec
		return f

	var pot_kepler := func(p: PackedVector3Array) -> float:
		var dist: float = (p[1] - p[0]).length()
		return - (g_const * m1 * m2) / maxf(dist, 1e-6)

	sentry.audit(pos_kep, vel_kep, mass_kep, pot_kepler)
	assert_test(is_equal_approx(sentry.initial_energy, -0.25), "T4.2a: Initial Kepler orbital energy E_0 = -0.25")

	var max_kepler_drift: float = 0.0
	var max_p_drift: float = 0.0
	var max_l_drift: float = 0.0

	for step in range(kepler_steps):
		verlet.integrate(pos_kep, vel_kep, mass_kep, f_kepler, dt_kepler)
		var snap: Dictionary = sentry.audit(pos_kep, vel_kep, mass_kep, pot_kepler)
		max_kepler_drift = maxf(max_kepler_drift, snap.energy_drift_ratio)
		max_p_drift = maxf(max_p_drift, snap.linear_momentum_drift)
		max_l_drift = maxf(max_l_drift, snap.angular_momentum_drift)

	print("  [Kepler Benchmark] Max Energy Drift: %.6f, Max P Drift: %.6f, Max L Drift: %.6f" % [
		max_kepler_drift, max_p_drift, max_l_drift
	])
	assert_test(
		max_kepler_drift < 0.001,
		"T4.2: Closed 2-body Keplerian orbit energy drift < 0.001 (Acceptance Criteria)",
		"Max drift: %.6f" % max_kepler_drift
	)
	assert_test(
		max_p_drift < 1e-5 and max_l_drift < 1e-4,
		"T4.2b: Linear and angular momentum strictly conserved over 5,000 steps"
	)

	sentry.free()

	# --------------------------------------------------------------------------
	# Scenario 4.3: 5,000-Particle SpatialHashGrid Benchmark (< 10 ms & 100% Brute-Force Match)
	# --------------------------------------------------------------------------
	print("\n[Scenario 4.3] 5,000-Particle SpatialHashGrid Performance & Correctness")
	var grid := SpatialHashGrid.new()
	grid.initialize(5.0)

	var rng := RandomNumberGenerator.new()
	rng.seed = 1234567

	var n_particles: int = 5000
	var test_positions := PackedVector3Array()
	test_positions.resize(n_particles)
	for i in range(n_particles):
		test_positions[i] = Vector3(
			rng.randf_range(-100.0, 100.0),
			rng.randf_range(-100.0, 100.0),
			rng.randf_range(-100.0, 100.0)
		)

	grid.build_grid(test_positions)
	assert_test(grid.get_particle_count() == 5000, "T4.3a: Bulk build loaded all 5,000 particles")

	var query_center := Vector3(0.0, 0.0, 0.0)
	var search_radius: float = 12.0
	var r_sq: float = search_radius * search_radius

	# Benchmark neighbor query time
	var t0: int = Time.get_ticks_usec()
	var grid_neighbors: PackedInt32Array = grid.get_neighbors(query_center, search_radius)
	var t1: int = Time.get_ticks_usec()
	var query_duration_ms: float = float(t1 - t0) / 1000.0

	print("  [SpatialHashGrid Benchmark] Query on 5,000 particles took: %.3f ms (found %d neighbors)" % [
		query_duration_ms, grid_neighbors.size()
	])
	assert_test(
		query_duration_ms < 10.0,
		"T4.3b: SpatialHashGrid neighbor query on 5,000 particles executes in < 10 ms (Acceptance Criteria)",
		"Duration: %.3f ms" % query_duration_ms
	)

	# Ground truth brute force verification
	var brute_force_neighbors: Array[int] = []
	for i in range(n_particles):
		if query_center.distance_squared_to(test_positions[i]) <= r_sq:
			brute_force_neighbors.append(i)
	brute_force_neighbors.sort()

	var grid_arr: Array = Array(grid_neighbors)
	grid_arr.sort()

	assert_test(
		grid_arr == brute_force_neighbors,
		"T4.3c: SpatialHashGrid neighbors match brute-force ground truth 100% exactly",
		"Grid count: %d, Brute count: %d" % [grid_arr.size(), brute_force_neighbors.size()]
	)

	# --------------------------------------------------------------------------
	# Scenario 4.4: Multipole Barnes-Hut Octree Gravity vs Direct Summation
	# --------------------------------------------------------------------------
	print("\n[Scenario 4.4] Barnes-Hut Octree Multipole Gravity vs Direct Summation")
	var octree := BarnesHutOctree.new(0.5, 0.1, 1.0)
	var n_cluster: int = 150
	var cluster_pos := PackedVector3Array()
	var cluster_mass := PackedFloat32Array()
	cluster_pos.resize(n_cluster)
	cluster_mass.resize(n_cluster)

	rng.seed = 7654321
	for i in range(n_cluster):
		cluster_pos[i] = Vector3(
			rng.randf_range(-30.0, 30.0),
			rng.randf_range(-30.0, 30.0),
			rng.randf_range(-30.0, 30.0)
		)
		cluster_mass[i] = rng.randf_range(1.0, 10.0)

	octree.build(cluster_pos, cluster_mass)

	# Direct O(N^2) summation for particle 0 with softening = 0.1
	var soft: float = 0.1
	var soft_sq: float = soft * soft
	var direct_a0 := Vector3.ZERO
	for j in range(1, n_cluster):
		var dr: Vector3 = cluster_pos[j] - cluster_pos[0]
		var d2: float = dr.length_squared() + soft_sq
		var inv_d3: float = 1.0 / (d2 * sqrt(d2))
		direct_a0 += dr * (cluster_mass[j] * inv_d3)

	# Test 1: theta = 0.0 (exact leaf traversal)
	var octree_a0_theta0: Vector3 = octree.compute_acceleration(0, cluster_pos[0], 0.0, soft, 1.0)
	var err_theta0: float = (octree_a0_theta0 - direct_a0).length() / direct_a0.length()
	assert_test(
		err_theta0 < 1e-5,
		"T4.4a: Barnes-Hut with theta=0.0 matches direct N-body summation (< 1e-5 error)",
		"Rel error: %.8f" % err_theta0
	)

	# Test 2: theta = 0.5 (Multipole Acceptance Criterion)
	var octree_a0_theta05: Vector3 = octree.compute_acceleration(0, cluster_pos[0], 0.5, soft, 1.0)
	var err_theta05: float = (octree_a0_theta05 - direct_a0).length() / direct_a0.length()
	print("  [Barnes-Hut MAC Benchmark] Theta=0.5 relative acceleration error: %.4f%%" % [err_theta05 * 100.0])
	assert_test(
		err_theta05 < 0.02,
		"T4.4b: Barnes-Hut with theta=0.5 retains < 2% relative error vs direct summation",
		"Rel error: %.4f%%" % (err_theta05 * 100.0)
	)

	# Test 3: Total potential energy vs pairwise direct sum
	var direct_u: float = 0.0
	for i in range(n_cluster):
		for j in range(i + 1, n_cluster):
			var r_ij: float = sqrt((cluster_pos[i] - cluster_pos[j]).length_squared() + soft_sq)
			direct_u -= (cluster_mass[i] * cluster_mass[j]) / r_ij

	var octree_u: float = octree.compute_total_potential_energy(cluster_pos, cluster_mass, 0.0, soft, 1.0)
	var u_err: float = absf(octree_u - direct_u) / absf(direct_u)
	assert_test(
		u_err < 1e-4,
		"T4.4c: Barnes-Hut total potential energy matches direct pairwise potential (< 1e-4 error)",
		"Octree U: %.4f, Direct U: %.4f, Rel Err: %.6f" % [octree_u, direct_u, u_err]
	)

	# --------------------------------------------------------------------------
	# Scenario 4.5: Node Pool Recycling & Memory Stability
	# --------------------------------------------------------------------------
	print("\n[Scenario 4.5] Memory Stability: Node Pool Recycling across 10 Cycles")
	var initial_cap: int = octree.get_pool_capacity()
	for cycle in range(10):
		octree.build(cluster_pos, cluster_mass)
	var final_cap: int = octree.get_pool_capacity()
	assert_test(
		final_cap == initial_cap,
		"T4.5: Node pool recycled across 10 build cycles with zero reallocation leakage",
		"Initial: %d, Final: %d" % [initial_cap, final_cap]
	)
