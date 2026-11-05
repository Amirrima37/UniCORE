extends SceneTree

# ==============================================================================
# Empirical Challenge Suite for Milestone 1 (M1-1)
# Central Simulation Time Engine & Integrators
#
# Challenger: challenger_m1_1
# Mode: Empirical verification under Godot 4.0.stable headless
# ==============================================================================

const SimulationTimeController = preload("res://core/physics/simulation_time_controller.gd")
const UnitConverter = preload("res://core/physics/unit_converter.gd")

var passed_count: int = 0
var failed_count: int = 0
var critical_defects: Array[String] = []

func assert_test(condition: bool, test_name: String, details: String = "") -> void:
	if condition:
		print("  [PASS] %s" % test_name)
		passed_count += 1
	else:
		print("  [FAIL] %s - %s" % [test_name, details])
		failed_count += 1

func _init() -> void:
	print("==================================================================")
	print("CHALLENGER M1-1: EMPIRICAL VERIFICATION HARNESS")
	print("==================================================================")

	_run_simulation_time_controller_tests()
	_run_unit_converter_tests()
	_verify_worker_integrator_compilation()
	_run_mathematical_verlet_harmonic_oscillator()

	print("\n==================================================================")
	print("EMPIRICAL CHALLENGE SUITE SUMMARY")
	print("Passed: %d, Failed: %d" % [passed_count, failed_count])
	if critical_defects.size() > 0:
		print("CRITICAL DEFECTS IDENTIFIED (%d):" % critical_defects.size())
		for defect in critical_defects:
			print("  - %s" % defect)
	print("==================================================================")

	quit(1 if failed_count > 0 or critical_defects.size() > 0 else 0)

# ==============================================================================
# 1. SIMULATION TIME CONTROLLER EMPIRICAL TESTS
# ==============================================================================
func _run_simulation_time_controller_tests() -> void:
	print("\n--- Test Suite 1: SimulationTimeController ---")

	var stc := SimulationTimeController.new()
	var tick_count: Array[int] = [0]
	var last_tick_dt: Array[float] = [0.0]
	var last_tick_time: Array[float] = [0.0]
	var step_executed_count: Array[int] = [0]
	var last_step_time: Array[float] = [0.0]

	stc.sim_tick.connect(func(dt: float, time: float) -> void:
		tick_count[0] += 1
		last_tick_dt[0] = dt
		last_tick_time[0] = time
	)

	stc.step_executed.connect(func(time: float) -> void:
		step_executed_count[0] += 1
		last_step_time[0] = time
	)

	# 1.1 fixed_delta configuration
	stc.set_fixed_delta(0.01)
	assert_test(is_equal_approx(stc.get_fixed_delta(), 0.01), "fixed_delta is configured to 0.01s")

	# 1.2 step_once() advances sim_time by exactly fixed_delta
	stc.step_once()
	assert_test(is_equal_approx(stc.get_sim_time(), 0.01),
		"step_once() advances sim_time by exactly fixed_delta (0.01s)",
		"Got: %f" % stc.get_sim_time()
	)
	assert_test(tick_count[0] == 1, "step_once() emits exactly 1 sim_tick")
	assert_test(is_equal_approx(last_tick_dt[0], 0.01), "sim_tick receives dt = 0.01")
	assert_test(is_equal_approx(last_tick_time[0], 0.01), "sim_tick receives sim_time = 0.01")
	assert_test(step_executed_count[0] == 1, "step_once() emits exactly 1 step_executed")
	assert_test(is_equal_approx(last_step_time[0], 0.01), "step_executed receives sim_time = 0.01")

	# Consecutive step_once()
	stc.step_once()
	assert_test(is_equal_approx(stc.get_sim_time(), 0.02),
		"Second step_once() advances sim_time to 0.02s",
		"Got: %f" % stc.get_sim_time()
	)
	assert_test(tick_count[0] == 2, "Second step_once() emits 2nd sim_tick")

	# 1.3 Pause freezes tick emissions in _physics_process
	stc.set_paused(true)
	assert_test(stc.is_simulation_paused(), "Simulation is paused")

	var ticks_before: int = tick_count[0]
	var time_before: float = stc.get_sim_time()

	# Run 0.1s in physics process while paused
	stc._physics_process(0.1)
	assert_test(tick_count[0] == ticks_before, "No sim_ticks emitted during _physics_process when paused")
	assert_test(is_equal_approx(stc.get_sim_time(), time_before), "sim_time remains frozen when paused")

	# Unpause via toggle_pause and verify ticks resume
	stc.toggle_pause()
	assert_test(not stc.is_simulation_paused(), "Simulation unpaused via toggle_pause()")
	stc._physics_process(0.02)
	assert_test(tick_count[0] == ticks_before + 2, "Unpaused physics process executed 2 ticks for 0.02s delta")
	assert_test(is_equal_approx(stc.get_sim_time(), time_before + 0.02), "sim_time advanced by 0.02s")

	# 1.4 Time scale clamping and dynamics
	stc.set_time_scale(0.00001)
	assert_test(is_equal_approx(stc.get_time_scale(), 0.001), "time_scale clamped to MIN_TIME_SCALE (0.001)")
	stc.set_time_scale(5000.0)
	assert_test(is_equal_approx(stc.get_time_scale(), 1000.0), "time_scale clamped to MAX_TIME_SCALE (1000.0)")

	stc.set_time_scale(2.0)
	stc.reset()
	tick_count[0] = 0
	# delta 0.01 at 2x scale = 0.02 simulated time = 2 ticks at fixed_delta 0.01
	stc._physics_process(0.01)
	assert_test(tick_count[0] == 2, "2.0x time scale executes 2 ticks for 0.01s real delta at fixed_delta 0.01")

	# 1.5 Substepping cap and anti-death-spiral lag protection
	stc.reset()
	stc.set_time_scale(1.0)
	stc.fixed_delta = 0.01
	stc.max_substeps = 10
	var spiral_ticks: Array[int] = [0]
	stc.sim_tick.connect(func(_dt: float, _time: float) -> void:
		spiral_ticks[0] += 1
	)

	# Simulate 1.0 second lag spike (100x fixed_delta)
	stc._physics_process(1.0)
	assert_test(spiral_ticks[0] == 10,
		"Under 1.0s lag spike, ticks capped strictly at max_substeps = 10",
		"Executed %d ticks" % spiral_ticks[0]
	)
	assert_test(is_equal_approx(stc.get_sim_time(), 0.10),
		"sim_time advanced by exactly max_substeps * fixed_delta = 0.10s",
		"Got: %f" % stc.get_sim_time()
	)

	# Subsequent frame with normal delta 0.01
	spiral_ticks[0] = 0
	stc._physics_process(0.01)
	assert_test(spiral_ticks[0] == 1,
		"Next frame executes exactly 1 tick (excess backlog discarded, death spiral prevented)",
		"Executed %d ticks" % spiral_ticks[0]
	)

	stc.free()

# ==============================================================================
# 2. UNIT CONVERTER EMPIRICAL TESTS
# ==============================================================================
func _run_unit_converter_tests() -> void:
	print("\n--- Test Suite 2: UnitConverter Invariance & Round-Trip ---")

	var conv := UnitConverter.new()

	# Lennard-Jones Argon conversions
	var length_si: float = 3.40e-10 # 1 sigma
	var length_lj: float = conv.to_simulation(UnitConverter.UnitSystem.LENNARD_JONES, UnitConverter.PhysicalQuantity.LENGTH, length_si)
	assert_test(is_equal_approx(length_lj, 1.0),
		"1 sigma SI (3.40e-10 m) converts to exactly 1.0 in LJ reduced units",
		"Got: %f" % length_lj
	)

	var length_si_back: float = conv.to_si(UnitConverter.UnitSystem.LENNARD_JONES, UnitConverter.PhysicalQuantity.LENGTH, length_lj)
	assert_test(is_equal_approx(length_si_back / length_si, 1.0),
		"Lennard-Jones length round-trip preserves value within float precision",
		"Ratio: %f" % (length_si_back / length_si)
	)

	# Vector conversion round trip
	var force_si := Vector3(1.23e-11, -4.56e-11, 7.89e-11)
	var force_lj: Vector3 = conv.to_simulation_vector(UnitConverter.UnitSystem.LENNARD_JONES, UnitConverter.PhysicalQuantity.FORCE, force_si)
	var force_si_reconstructed: Vector3 = conv.to_si_vector(UnitConverter.UnitSystem.LENNARD_JONES, UnitConverter.PhysicalQuantity.FORCE, force_lj)

	var diff_len: float = (force_si_reconstructed - force_si).length()
	assert_test(diff_len < 1e-15,
		"Force Vector3 round-trip through LJ units is exact",
		"Diff: %e" % diff_len
	)

# ==============================================================================
# 3. WORKER INTEGRATOR COMPILATION & LOAD AUDIT
# ==============================================================================
func _verify_worker_integrator_compilation() -> void:
	print("\n--- Test Suite 3: Worker Integrator Implementation Load Audit ---")

	# Check PhysicalIntegrator load
	var phys_script: GDScript = load("res://core/physics/physical_integrator.gd") as GDScript
	if phys_script == null or not phys_script.can_instantiate():
		assert_test(false,
			"res://core/physics/physical_integrator.gd compiles and can instantiate",
			"CRITICAL: Failed to load/instantiate. Callable.get_argument_count() on line 66 does not exist in Godot 4.0.stable!"
		)
		critical_defects.append("res://core/physics/physical_integrator.gd:66: Callable.get_argument_count() is not supported in Godot 4.0.stable, breaking compilation.")
	else:
		assert_test(true, "res://core/physics/physical_integrator.gd compiles successfully")

	# Check VerletIntegrator load
	var verlet_script: GDScript = load("res://core/physics/verlet_integrator.gd") as GDScript
	if verlet_script == null or not verlet_script.can_instantiate():
		assert_test(false,
			"res://core/physics/verlet_integrator.gd compiles and can instantiate",
			"CRITICAL: Cannot instantiate VerletIntegrator because superclass PhysicalIntegrator failed compilation!"
		)
		critical_defects.append("res://core/physics/verlet_integrator.gd: cannot instantiate due to superclass PhysicalIntegrator failure.")
	else:
		assert_test(true, "res://core/physics/verlet_integrator.gd compiles successfully")

	# Check RK4Integrator load
	var rk4_script: GDScript = load("res://core/physics/rk4_integrator.gd") as GDScript
	if rk4_script == null or not rk4_script.can_instantiate():
		assert_test(false,
			"res://core/physics/rk4_integrator.gd compiles and can instantiate",
			"CRITICAL: Cannot instantiate RK4Integrator because superclass PhysicalIntegrator failed compilation!"
		)
		critical_defects.append("res://core/physics/rk4_integrator.gd: cannot instantiate due to superclass PhysicalIntegrator failure.")
	else:
		assert_test(true, "res://core/physics/rk4_integrator.gd compiles successfully")

# ==============================================================================
# 4. MATHEMATICAL VERIFICATION OF VELOCITY-VERLET ALGORITHM (HARMONIC OSCILLATOR)
# ==============================================================================
# Here we test the exact Velocity-Verlet formula implemented in verlet_integrator.gd,
# evaluating force via force_callable.call(pos), to independently verify whether
# the mathematical model satisfies |(E(5000) - E_0) / E_0| < 0.001 once the base
# class compilation bug is resolved.
func _run_mathematical_verlet_harmonic_oscillator() -> void:
	print("\n--- Test Suite 4: Velocity-Verlet Harmonic Oscillator (5,000 steps, dt=0.01) ---")

	var m: float = 1.0
	var k: float = 1.0
	var dt: float = 0.01
	var total_steps: int = 5000

	# Initial conditions: r_0 = (1, 0, 0), v_0 = (0, 0, 0)
	var pos := PackedVector3Array([Vector3(1.0, 0.0, 0.0)])
	var vel := PackedVector3Array([Vector3(0.0, 0.0, 0.0)])
	var masses := PackedFloat32Array([m])

	var e0: float = 0.5 * m * vel[0].length_squared() + 0.5 * k * pos[0].length_squared()
	assert_test(is_equal_approx(e0, 0.5), "Initial energy E_0 is exactly 0.5 J")

	var a0_buf := PackedVector3Array([Vector3.ZERO])
	var max_drift: float = 0.0
	var min_energy: float = e0
	var max_energy: float = e0

	var dt_sq_half: float = 0.5 * dt * dt
	var dt_half: float = 0.5 * dt
	var inv_m: float = 1.0 / m

	# Run 5,000 steps of Velocity-Verlet
	for step in range(total_steps):
		# Step 1: F_0 = -k * pos
		var f0: Vector3 = -k * pos[0]
		var a0: Vector3 = f0 * inv_m
		a0_buf[0] = a0

		# Step 2: r(t + dt) = r(t) + v(t)*dt + 0.5*a_0*dt^2
		pos[0] += vel[0] * dt + a0 * dt_sq_half

		# Step 3: F_new = -k * pos_new
		var f_new: Vector3 = -k * pos[0]
		var a_new: Vector3 = f_new * inv_m

		# Step 4: v(t + dt) = v(t) + 0.5*(a_0 + a_new)*dt
		vel[0] += (a0_buf[0] + a_new) * dt_half

		# Audit energy
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
	print("  -> Peak relative drift (5000 steps): %.8f (%.6f%%)" % [max_drift, max_drift * 100.0])
	print("  -> Shadow Hamiltonian band:          [%.6f, %.6f]" % [min_energy, max_energy])

	assert_test(final_drift < 0.001,
		"Velocity-Verlet mathematical formulation satisfies |(E(5000) - E_0) / E_0| < 0.001 (0.1%)",
		"Relative drift was: %f" % final_drift
	)
	assert_test(max_drift < 0.001,
		"Velocity-Verlet peak relative drift strictly < 0.001 over entire 5,000 steps",
		"Peak relative drift was: %f" % max_drift
	)
	assert_test(absf(max_energy - min_energy) < 0.0001,
		"Energy oscillates within tight shadow Hamiltonian boundary (< 0.0001 J) with zero secular decay",
		"Band width: %f" % absf(max_energy - min_energy)
	)
