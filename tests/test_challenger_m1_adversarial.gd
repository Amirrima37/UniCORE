extends SceneTree

# ==============================================================================
# Adversarial Empirical Challenge Suite: Milestone 1
# Central Simulation Time Engine & Integrators
# Author: Challenger M1-Iteration 2
# Engine: Godot 4.0.stable.official.92bee43ad
# ==============================================================================

const SimulationTimeController = preload("res://core/physics/simulation_time_controller.gd")
const UnitConverter = preload("res://core/physics/unit_converter.gd")
const PhysicalIntegrator = preload("res://core/physics/physical_integrator.gd")
const VerletIntegrator = preload("res://core/physics/verlet_integrator.gd")
const RK4Integrator = preload("res://core/physics/rk4_integrator.gd")

var passed_count: int = 0
var failed_count: int = 0
var failure_messages: Array[String] = []

func assert_check(condition: bool, test_name: String, details: String = "") -> void:
	if condition:
		print("  [PASS] %s" % test_name)
		passed_count += 1
	else:
		var msg: String = "  [FAIL] %s - %s" % [test_name, details]
		print(msg)
		failed_count += 1
		failure_messages.append(msg)

func _init() -> void:
	print("==================================================================")
	print("CHALLENGER M1-IT2: ADVERSARIAL STRESS HARNESS")
	print("==================================================================")

	_test_unit_converter_exhaustive_matrix()
	_test_verlet_harmonic_oscillator_5000_steps()
	_test_verlet_min_mass_clamping()
	_test_rk4_drag_forces_and_velocity_dependence()
	_test_integrator_callable_arity_alternation()
	_test_simulation_time_controller_timing_and_anti_death_spiral()

	print("\n==================================================================")
	print("ADVERSARIAL STRESS HARNESS SUMMARY")
	print("Passed: %d, Failed: %d" % [passed_count, failed_count])
	if failed_count > 0:
		print("FAILURES DETECTED:")
		for f in failure_messages:
			print(f)
	print("==================================================================")

	quit(1 if failed_count > 0 else 0)

# ==============================================================================
# Suite 1: UnitConverter Exhaustive Round-Trip & Edge Cases
# ==============================================================================
func _test_unit_converter_exhaustive_matrix() -> void:
	print("\n--- Suite 1: UnitConverter Exhaustive Matrix & Boundary Invariance ---")
	var conv := UnitConverter.new()

	var test_systems: Array[int] = [
		UnitConverter.UnitSystem.LENNARD_JONES,
		UnitConverter.UnitSystem.PLANCK,
		UnitConverter.UnitSystem.ASTRONOMICAL
	]

	var test_quantities: Array[int] = [
		UnitConverter.PhysicalQuantity.LENGTH,
		UnitConverter.PhysicalQuantity.MASS,
		UnitConverter.PhysicalQuantity.TIME,
		UnitConverter.PhysicalQuantity.VELOCITY,
		UnitConverter.PhysicalQuantity.ACCELERATION,
		UnitConverter.PhysicalQuantity.FORCE,
		UnitConverter.PhysicalQuantity.ENERGY,
		UnitConverter.PhysicalQuantity.MOMENTUM,
		UnitConverter.PhysicalQuantity.ANGULAR_MOMENTUM,
		UnitConverter.PhysicalQuantity.TEMPERATURE,
		UnitConverter.PhysicalQuantity.PRESSURE,
		UnitConverter.PhysicalQuantity.DENSITY,
		UnitConverter.PhysicalQuantity.CHARGE
	]

	var test_values: Array[float] = [1.0, 123.456, 0.00789, 1e-12, 1e6]

	var max_relative_error: float = 0.0
	var round_trips_checked: int = 0

	for sys in test_systems:
		for qty in test_quantities:
			for val in test_values:
				var sim_val: float = conv.to_simulation(sys, qty, val)
				var back_val: float = conv.to_si(sys, qty, sim_val)
				var rel_err: float = absf((back_val - val) / val)
				if rel_err > max_relative_error:
					max_relative_error = rel_err
				round_trips_checked += 1

	print("  Evaluated %d scalar round-trip conversions across 3 systems & 13 quantities." % round_trips_checked)
	print("  Maximum observed relative error: %s" % str(max_relative_error))
	assert_check(max_relative_error < 1e-6,
		"UnitConverter scalar round-trip error < 1e-6 across all systems/quantities",
		"Max relative error was: %s" % str(max_relative_error)
	)

	# Vector3 round trips
	var test_vec := Vector3(12.34, -56.78, 90.12)
	var max_vec_error: float = 0.0
	for sys in test_systems:
		for qty in [UnitConverter.PhysicalQuantity.VELOCITY, UnitConverter.PhysicalQuantity.FORCE, UnitConverter.PhysicalQuantity.MOMENTUM]:
			var sim_vec: Vector3 = conv.to_simulation_vector(sys, qty, test_vec)
			var back_vec: Vector3 = conv.to_si_vector(sys, qty, sim_vec)
			var err: float = (back_vec - test_vec).length() / test_vec.length()
			if err > max_vec_error:
				max_vec_error = err

	assert_check(max_vec_error < 1e-6,
		"UnitConverter Vector3 round-trip relative error < 1e-6",
		"Max vector relative error was: %s" % str(max_vec_error)
	)

	# Parameter validation
	var ok_lj: bool = conv.configure_lennard_jones(-1.0, 1.0, 1.0)
	assert_check(not ok_lj, "configure_lennard_jones rejects negative sigma")

	var ok_astro: bool = conv.configure_astronomical(1.0, -1.0)
	assert_check(not ok_astro, "configure_astronomical rejects negative mass")

# ==============================================================================
# Suite 2: VerletIntegrator 5,000-Step Harmonic Oscillator Conservation
# ==============================================================================
func _test_verlet_harmonic_oscillator_5000_steps() -> void:
	print("\n--- Suite 2: VerletIntegrator 5,000-Step SHO & Symplectic Invariance ---")
	var verlet := VerletIntegrator.new()

	var m: float = 1.0
	var k: float = 1.0
	var dt: float = 0.01
	var steps: int = 5000

	var pos := PackedVector3Array([Vector3(1.0, 0.0, 0.0)])
	var vel := PackedVector3Array([Vector3(0.0, 0.0, 0.0)])
	var masses := PackedFloat32Array([m])

	var e0: float = 0.5 * m * vel[0].length_squared() + 0.5 * k * pos[0].length_squared()
	var max_drift: float = 0.0

	var force_harmonic := func(p: PackedVector3Array) -> PackedVector3Array:
		var f := PackedVector3Array()
		f.resize(p.size())
		for i in range(p.size()):
			f[i] = -k * p[i]
		return f

	for s in range(steps):
		verlet.integrate(pos, vel, masses, force_harmonic, dt)
		var e: float = 0.5 * m * vel[0].length_squared() + 0.5 * k * pos[0].length_squared()
		var drift: float = absf((e - e0) / e0)
		if drift > max_drift:
			max_drift = drift

	var final_e: float = 0.5 * m * vel[0].length_squared() + 0.5 * k * pos[0].length_squared()
	var final_drift: float = absf((final_e - e0) / e0)

	print("  Initial E0: %.6f J, Final E: %.6f J" % [e0, final_e])
	print("  Final relative drift: %.8f, Max peak drift: %.8f" % [final_drift, max_drift])

	assert_check(final_drift < 0.001,
		"VerletIntegrator 5,000-step harmonic oscillator final drift < 0.001",
		"Got: %f" % final_drift
	)
	assert_check(max_drift < 0.001,
		"VerletIntegrator 5,000-step harmonic oscillator peak drift < 0.001",
		"Got: %f" % max_drift
	)

# ==============================================================================
# Suite 3: VerletIntegrator MIN_MASS Clamping & Input Boundaries
# ==============================================================================
func _test_verlet_min_mass_clamping() -> void:
	print("\n--- Suite 3: VerletIntegrator MIN_MASS Clamping & Input Boundaries ---")
	var verlet := VerletIntegrator.new()

	var pos := PackedVector3Array([Vector3(1.0, 0.0, 0.0)])
	var vel := PackedVector3Array([Vector3(0.0, 0.0, 0.0)])
	var zero_mass := PackedFloat32Array([0.0]) # Stress test zero mass

	var dummy_force := func(p: PackedVector3Array) -> PackedVector3Array:
		return PackedVector3Array([Vector3(1.0, 0.0, 0.0)])

	verlet.integrate(pos, vel, zero_mass, dummy_force, 0.01)

	assert_check(not is_nan(pos[0].x) and not is_inf(pos[0].x),
		"VerletIntegrator clamps mass <= MIN_MASS without NaN/Inf explosion",
		"Result pos: %s, vel: %s" % [str(pos[0]), str(vel[0])]
	)

# ==============================================================================
# Suite 4: RK4Integrator Drag Forces & Velocity-Dependent Dissipation
# ==============================================================================
func _test_rk4_drag_forces_and_velocity_dependence() -> void:
	print("\n--- Suite 4: RK4Integrator Drag Forces & Velocity-Dependent Dissipation ---")
	var rk4 := RK4Integrator.new()

	# Test Stokes drag with gravity: dv/dt = -g - (gamma/m)*v
	# Terminal velocity: v_term = -m*g/gamma
	var m: float = 2.0
	var g: float = 9.8
	var gamma: float = 4.0
	var v_expected_term: float = -m * g / gamma # -4.9 m/s
	var dt: float = 0.01
	var steps: int = 600 # 6.0 seconds = 12 time constants (tau = m/gamma = 0.5s)

	var pos := PackedVector3Array([Vector3(0.0, 100.0, 0.0)])
	var vel := PackedVector3Array([Vector3(0.0, 0.0, 0.0)])
	var masses := PackedFloat32Array([m])

	var drag_force := func(p: PackedVector3Array, v: PackedVector3Array) -> PackedVector3Array:
		var f := PackedVector3Array()
		f.resize(p.size())
		for i in range(p.size()):
			f[i] = Vector3(0.0, -m * g - gamma * v[i].y, 0.0)
		return f

	for s in range(steps):
		rk4.integrate(pos, vel, masses, drag_force, dt)

	var v_final: float = vel[0].y
	var diff: float = absf(v_final - v_expected_term)
	print("  Stokes drag final velocity: %.6f m/s, Expected terminal: %.6f m/s, Diff: %s" % [
		v_final, v_expected_term, str(diff)
	])

	assert_check(diff < 1e-3,
		"RK4Integrator Stokes drag reaches analytical terminal velocity within 1e-3",
		"Diff: %s" % str(diff)
	)

# ==============================================================================
# Suite 5: Dynamic Callable Arity Alternation & Zero Allocation State
# ==============================================================================
func _test_integrator_callable_arity_alternation() -> void:
	print("\n--- Suite 5: Callable Arity Alternation on Same Integrator Instance ---")
	var rk4 := RK4Integrator.new()

	var pos := PackedVector3Array([Vector3(1.0, 0.0, 0.0)])
	var vel := PackedVector3Array([Vector3(0.0, 1.0, 0.0)])
	var masses := PackedFloat32Array([1.0])

	var call_1_arg := func(p: PackedVector3Array) -> PackedVector3Array:
		return PackedVector3Array([-p[0]])

	var call_2_arg := func(p: PackedVector3Array, v: PackedVector3Array) -> PackedVector3Array:
		return PackedVector3Array([-p[0] - 0.1 * v[0]])

	# Call with 1-arg callable
	rk4.integrate(pos, vel, masses, call_1_arg, 0.01)
	assert_check(not is_nan(pos[0].x), "RK4 integrates 1-arg callable successfully")

	# Immediately call with 2-arg callable WITHOUT clear_buffers
	rk4.integrate(pos, vel, masses, call_2_arg, 0.01)
	assert_check(not is_nan(pos[0].x), "RK4 integrates 2-arg callable immediately after 1-arg without error")

	# Call again with 1-arg callable
	rk4.integrate(pos, vel, masses, call_1_arg, 0.01)
	assert_check(not is_nan(pos[0].x), "RK4 integrates 1-arg callable again successfully")

# ==============================================================================
# Suite 6: SimulationTimeController Timing Precision & Death-Spiral Protection
# ==============================================================================
func _test_simulation_time_controller_timing_and_anti_death_spiral() -> void:
	print("\n--- Suite 6: SimulationTimeController Timing & Anti-Death-Spiral ---")
	var stc := SimulationTimeController.new()
	stc.fixed_delta = 0.01
	stc.max_substeps = 10

	var ticks_received: Array[int] = [0]
	var last_dt: Array[float] = [0.0]
	var last_sim_time: Array[float] = [0.0]
	var steps_executed: Array[int] = [0]

	stc.sim_tick.connect(func(dt: float, s_time: float) -> void:
		ticks_received[0] += 1
		last_dt[0] = dt
		last_sim_time[0] = s_time
	)

	stc.step_executed.connect(func(s_time: float) -> void:
		steps_executed[0] += 1
	)

	# 1. step_once advances sim_time by exactly fixed_delta
	stc.step_once()
	assert_check(is_equal_approx(stc.get_sim_time(), 0.01),
		"step_once() advances sim_time by exactly fixed_delta",
		"Got: %f" % stc.get_sim_time()
	)
	assert_check(ticks_received[0] == 1, "step_once() emits exactly 1 sim_tick")
	assert_check(steps_executed[0] == 1, "step_once() emits exactly 1 step_executed")
	assert_check(is_equal_approx(last_dt[0], 0.01), "sim_tick received dt == fixed_delta")
	assert_check(is_equal_approx(last_sim_time[0], 0.01), "sim_tick received sim_time == fixed_delta")

	# 2. Pause freezes ticks and sim_time
	stc.set_paused(true)
	var time_at_pause: float = stc.get_sim_time()
	var ticks_at_pause: int = ticks_received[0]

	stc._physics_process(0.5)
	assert_check(ticks_received[0] == ticks_at_pause, "Paused state produces 0 ticks during _physics_process")
	assert_check(is_equal_approx(stc.get_sim_time(), time_at_pause), "Paused state freezes sim_time")

	# 3. Unpause and test massive 5.0s lag spike for death-spiral protection
	stc.set_paused(false)
	ticks_received[0] = 0
	stc._physics_process(5.0)

	assert_check(ticks_received[0] == 10,
		"Under 5.0s lag spike, steps capped strictly at max_substeps = 10",
		"Got ticks: %d" % ticks_received[0]
	)

	# Next normal frame must execute exactly 1 tick, showing backlog was dropped
	ticks_received[0] = 0
	stc._physics_process(0.01)
	assert_check(ticks_received[0] == 1,
		"Subsequent frame executes 1 tick, verifying excess backlog was discarded",
		"Got ticks: %d" % ticks_received[0]
	)

	# 4. Time scale clamping
	stc.set_time_scale(-100.0)
	assert_check(is_equal_approx(stc.get_time_scale(), 0.001), "Negative time_scale clamped to MIN_TIME_SCALE")

	stc.set_time_scale(99999.0)
	assert_check(is_equal_approx(stc.get_time_scale(), 1000.0), "Excessive time_scale clamped to MAX_TIME_SCALE")

	stc.free()
