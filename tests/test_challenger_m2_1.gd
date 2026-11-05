extends SceneTree

# ==============================================================================
# Challenger M2-1 Empirical Verification & Adversarial Stress Suite
# Milestone 2: Conservation Law Sentry & Spatial Partitioning
# ==============================================================================

const ConservationSentry = preload("res://core/physics/conservation_sentry.gd")
const VerletIntegrator = preload("res://core/physics/verlet_integrator.gd")
const SpatialHashGrid = preload("res://core/physics/spatial_hash_grid.gd")
const BarnesHutOctree = preload("res://core/physics/barnes_hut_octree.gd")

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
	print("CHALLENGER M2-1: EMPIRICAL STRESS & CONSERVATION VERIFICATION")
	print("Engine: Godot 4.0.stable")
	print("==================================================================")

	_test_suite_1_kepler_2body_conservative_orbit()
	_test_suite_2_artificial_perturbations()
	_test_suite_3_unequal_mass_orbit()
	_test_suite_3b_eccentric_orbit()
	_test_suite_4_sentry_edge_cases()
	_test_suite_5_spatial_hash_grid_5000_particles()
	_test_suite_6_barnes_hut_conservation_integration()

	print("\n==================================================================")
	print("CHALLENGER M2-1 VERIFICATION SUMMARY")
	print("Passed: %d, Failed: %d" % [passed_count, failed_count])
	if errors.size() > 0:
		print("FAILURES:")
		for err in errors:
			print("  - %s" % err)
	print("==================================================================")

	quit(1 if failed_count > 0 else 0)

# ==============================================================================
# Suite 1: Core Acceptance Criterion - 2-Body Keplerian Orbit (5,000 steps, dt=0.01)
# ==============================================================================
func _test_suite_1_kepler_2body_conservative_orbit() -> void:
	print("\n--- Suite 1: Closed 2-Body Keplerian Orbit (5,000 steps, dt=0.01) ---")
	
	var sentry := ConservationSentry.new()
	var verlet := VerletIntegrator.new()
	
	var warning_events: Array[Dictionary] = []
	var update_events: Array[Dictionary] = []
	
	sentry.conservation_warning.connect(func(v_type: String, r_drift: float):
		warning_events.append({"type": v_type, "drift": r_drift})
	)
	sentry.invariants_updated.connect(func(snap: Dictionary):
		update_events.append(snap)
	)
	
	var m1: float = 1.0
	var m2: float = 1.0
	var g_const: float = 1.0
	var r_sep: float = 2.0
	var v_rel: float = sqrt((g_const * (m1 + m2)) / r_sep) # 1.0
	var dt: float = 0.01
	var total_steps: int = 5000
	
	# Center of mass configuration in XY plane
	# Body 0 at (-1, 0, 0), moving along -Y with v=0.5
	# Body 1 at (+1, 0, 0), moving along +Y with v=0.5
	var positions := PackedVector3Array([Vector3(-1.0, 0.0, 0.0), Vector3(1.0, 0.0, 0.0)])
	var velocities := PackedVector3Array([Vector3(0.0, -0.5, 0.0), Vector3(0.0, 0.5, 0.0)])
	var masses := PackedFloat32Array([m1, m2])
	
	var force_kepler := func(p: PackedVector3Array) -> PackedVector3Array:
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
	
	var potential_kepler := func(p: PackedVector3Array) -> float:
		var dist: float = (p[1] - p[0]).length()
		if dist < 1e-6:
			dist = 1e-6
		return - (g_const * m1 * m2) / dist
	
	# Initial theoretical invariants:
	# E_k = 0.5 * 1.0 * 0.25 + 0.5 * 1.0 * 0.25 = 0.25
	# E_p = - 1.0 / 2.0 = -0.5
	# E_0 = -0.25
	# P_0 = (0, 0, 0)
	# L_0 = (-1,0,0)x(0,-0.5,0) + (1,0,0)x(0,0.5,0) = (0,0,0.5) + (0,0,0.5) = (0,0,1.0)
	var initial_snap: Dictionary = sentry.audit(positions, velocities, masses, potential_kepler)
	
	assert_test(is_equal_approx(initial_snap.total_energy, -0.25),
		"Initial total energy E_0 = -0.25",
		"Got: %f" % initial_snap.total_energy
	)
	assert_test(initial_snap.linear_momentum.length() < 1e-7,
		"Initial linear momentum |P_0| ~ 0",
		"Got: %f" % initial_snap.linear_momentum.length()
	)
	assert_test(is_equal_approx(initial_snap.angular_momentum.z, 1.0),
		"Initial angular momentum L_0.z = 1.0",
		"Got: %f" % initial_snap.angular_momentum.z
	)
	
	var max_energy_drift: float = 0.0
	var max_p_mag: float = 0.0
	var max_l_drift: float = 0.0
	var min_sep: float = 1e9
	var max_sep: float = 0.0
	
	# Execute 5,000 integration steps
	for step in range(total_steps):
		verlet.integrate(positions, velocities, masses, force_kepler, dt)
		var snap: Dictionary = sentry.audit(positions, velocities, masses, potential_kepler)
		if step < 5:
			print("    [SUITE 1 STEP %d] Ek=%.6f, Ep=%.6f, Etot=%.6f, drift=%.8f, r0=%s, v0=%s" % [
				step, snap.kinetic_energy, snap.potential_energy, snap.total_energy, snap.energy_drift_ratio,
				str(positions[0]), str(velocities[0])
			])
		
		var e_drift: float = snap.energy_drift_ratio
		if e_drift > max_energy_drift:
			max_energy_drift = e_drift
		
		var p_mag: float = snap.linear_momentum.length()
		if p_mag > max_p_mag:
			max_p_mag = p_mag
		
		var l_drift: float = snap.angular_momentum_drift
		if l_drift > max_l_drift:
			max_l_drift = l_drift
		
		var current_sep: float = (positions[1] - positions[0]).length()
		if current_sep < min_sep:
			min_sep = current_sep
		if current_sep > max_sep:
			max_sep = current_sep
	
	var final_snap: Dictionary = sentry.get_last_snapshot()
	var final_e_drift: float = final_snap.energy_drift_ratio
	var simulated_time: float = total_steps * dt
	var orbit_period: float = 2.0 * PI * r_sep / v_rel # 4*PI ~ 12.566 s
	var orbits_completed: float = simulated_time / orbit_period
	
	print("  -> Simulated Time:             %.2f s (~%.2f orbits)" % [simulated_time, orbits_completed])
	print("  -> Final Energy Drift Ratio:   %.8f (%.6f pct)" % [final_e_drift, final_e_drift * 100.0])
	print("  -> Peak Energy Drift Ratio:    %.8f (%.6f pct)" % [max_energy_drift, max_energy_drift * 100.0])
	print("  -> Max Linear Momentum |P|:    %.10f" % max_p_mag)
	print("  -> Max Angular Momentum Drift: %.10f" % max_l_drift)
	print("  -> Separation Radial Range:    [%.6f, %.6f] (delta = %.6f)" % [min_sep, max_sep, max_sep - min_sep])
	print("  -> Warnings Emitted:           %d" % warning_events.size())
	print("  -> Update Signals Emitted:     %d" % update_events.size())
	
	assert_test(final_e_drift < 0.001,
		"Final energy_drift_ratio < 0.001 (0.1%)",
		"Got final drift: %f" % final_e_drift
	)
	assert_test(max_energy_drift < 0.001,
		"Peak energy_drift_ratio < 0.001 across all 5,000 steps",
		"Got peak drift: %f" % max_energy_drift
	)
	assert_test(max_p_mag < 1e-5,
		"Linear momentum |P| strictly conserved near zero (< 1e-5)",
		"Got max |P|: %f" % max_p_mag
	)
	assert_test(max_l_drift < 0.01,
		"Angular momentum vector L conserved (drift < 0.01)",
		"Got max L drift: %f" % max_l_drift
	)
	assert_test(final_snap.angular_momentum.distance_to(Vector3(0, 0, 1.0)) < 1e-4,
		"Angular momentum vector points strictly along +Z (diff < 1e-4)",
		"L vector: %s" % str(final_snap.angular_momentum)
	)
	assert_test(warning_events.size() == 0,
		"Zero conservation_warning signals emitted during 5,000 conservative steps",
		"Got warnings: %s" % str(warning_events)
	)
	assert_test(final_snap.is_conserved == true,
		"ConservationSentry reports is_conserved == true",
		"Got is_conserved: %s" % str(final_snap.is_conserved)
	)
	assert_test(update_events.size() == total_steps + 1,
		"invariants_updated signal emitted on every audit cycle (%d times)" % (total_steps + 1),
		"Got count: %d" % update_events.size()
	)
	
	sentry.free()

# ==============================================================================
# Suite 2: Artificial Perturbation / Warning Signal Triggering
# ==============================================================================
func _test_suite_2_artificial_perturbations() -> void:
	print("\n--- Suite 2: Artificial Perturbation & Signal Triggering ---")
	
	var sentry := ConservationSentry.new()
	var warning_log: Array[Dictionary] = []
	sentry.conservation_warning.connect(func(v_type: String, r_drift: float):
		warning_log.append({"type": v_type, "drift": r_drift})
	)
	
	var positions := PackedVector3Array([Vector3(-1.0, 0.0, 0.0), Vector3(1.0, 0.0, 0.0)])
	var velocities := PackedVector3Array([Vector3(0.0, -0.5, 0.0), Vector3(0.0, 0.5, 0.0)])
	var masses := PackedFloat32Array([1.0, 1.0])
	var pot_fn := func(p: PackedVector3Array) -> float:
		return -1.0 / (p[1] - p[0]).length()
	
	# Register clean baseline: E_0 = -0.25
	sentry.audit(positions, velocities, masses, pot_fn)
	warning_log.clear()
	
	# 2.1: Artificial Energy Jump > 0.005 (boost velocity by 10%)
	# v = 0.5 * 1.1 = 0.55 -> E_k = 2 * (0.5 * 1.0 * 0.55^2) = 0.3025
	# E_tot = 0.3025 - 0.5 = -0.1975
	# Drift = |-0.1975 - (-0.25)| / 0.25 = 0.0525 / 0.25 = 0.21 (21% jump >> 0.005 tolerance)
	var boosted_vel := PackedVector3Array([Vector3(0.0, -0.55, 0.0), Vector3(0.0, 0.55, 0.0)])
	var snap_e_jump: Dictionary = sentry.audit(positions, boosted_vel, masses, pot_fn)
	
	var got_energy_warning: bool = false
	var energy_drift_recorded: float = 0.0
	for w in warning_log:
		if w.type == "energy":
			got_energy_warning = true
			energy_drift_recorded = w.drift
	
	assert_test(got_energy_warning,
		"conservation_warning emitted on artificial energy jump > 0.005",
		"Warnings: %s" % str(warning_log)
	)
	assert_test(energy_drift_recorded > 0.005,
		"Reported energy drift exceeds tolerance (got %.4f > 0.005)" % energy_drift_recorded,
		"Got drift: %f" % energy_drift_recorded
	)
	assert_test(snap_e_jump.is_conserved == false,
		"Snapshot marks is_conserved == false on energy violation",
		"Got: %s" % str(snap_e_jump.is_conserved)
	)
	
	# 2.2: Artificial Linear Momentum Violation
	# Apply unbalanced momentum kick of +0.5 to body 0 along X
	warning_log.clear()
	var kicked_vel := PackedVector3Array([Vector3(0.5, -0.5, 0.0), Vector3(0.0, 0.5, 0.0)])
	var snap_p_kick: Dictionary = sentry.audit(positions, kicked_vel, masses, pot_fn)
	
	var got_p_warning: bool = false
	var p_drift_recorded: float = 0.0
	for w in warning_log:
		if w.type == "linear_momentum":
			got_p_warning = true
			p_drift_recorded = w.drift
	
	assert_test(got_p_warning,
		"conservation_warning emitted on linear momentum kick",
		"Warnings: %s" % str(warning_log)
	)
	assert_test(p_drift_recorded > sentry.momentum_tolerance,
		"Reported momentum drift (%f) exceeds momentum_tolerance (%f)" % [p_drift_recorded, sentry.momentum_tolerance]
	)
	
	# 2.3: Artificial Angular Momentum Violation
	# Reverse velocity of body 0 to break angular momentum
	warning_log.clear()
	var torqued_vel := PackedVector3Array([Vector3(0.0, 0.5, 0.0), Vector3(0.0, 0.5, 0.0)])
	var snap_l_torque: Dictionary = sentry.audit(positions, torqued_vel, masses, pot_fn)
	
	var got_l_warning: bool = false
	var l_drift_recorded: float = 0.0
	for w in warning_log:
		if w.type == "angular_momentum":
			got_l_warning = true
			l_drift_recorded = w.drift
	
	assert_test(got_l_warning,
		"conservation_warning emitted on angular momentum violation",
		"Warnings: %s" % str(warning_log)
	)
	assert_test(l_drift_recorded > sentry.angular_momentum_tolerance,
		"Reported angular momentum drift (%f) exceeds angular_momentum_tolerance (%f)" % [l_drift_recorded, sentry.angular_momentum_tolerance]
	)
	
	sentry.free()

# ==============================================================================
# Suite 3: Unequal Mass Keplerian Orbit (5,000 steps, dt=0.01)
# ==============================================================================
func _test_suite_3_unequal_mass_orbit() -> void:
	print("\n--- Suite 3: Unequal Mass Keplerian Orbit (m1=10, m2=0.1, 5,000 steps) ---")
	
	var sentry := ConservationSentry.new()
	var verlet := VerletIntegrator.new()
	
	var m1: float = 10.0
	var m2: float = 0.1
	var total_m: float = m1 + m2
	var g_const: float = 1.0
	var r_sep: float = 2.0
	var v_rel: float = sqrt((g_const * total_m) / r_sep) # sqrt(10.1 / 2.0) ~ 2.24722
	var dt: float = 0.01
	var total_steps: int = 5000
	
	# Center of mass coordinates:
	# r1 = - r_sep * (m2 / total_m)
	# r2 = + r_sep * (m1 / total_m)
	var r1_x: float = - r_sep * (m2 / total_m)
	var r2_x: float = + r_sep * (m1 / total_m)
	var v1_y: float = - v_rel * (m2 / total_m)
	var v2_y: float = + v_rel * (m1 / total_m)
	
	var positions := PackedVector3Array([Vector3(r1_x, 0.0, 0.0), Vector3(r2_x, 0.0, 0.0)])
	var velocities := PackedVector3Array([Vector3(0.0, v1_y, 0.0), Vector3(0.0, v2_y, 0.0)])
	var masses := PackedFloat32Array([m1, m2])
	
	var force_kepler := func(p: PackedVector3Array) -> PackedVector3Array:
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
	
	var potential_kepler := func(p: PackedVector3Array) -> float:
		var dist: float = (p[1] - p[0]).length()
		if dist < 1e-6:
			dist = 1e-6
		return - (g_const * m1 * m2) / dist
	
	var init_snap: Dictionary = sentry.audit(positions, velocities, masses, potential_kepler)
	var max_e_drift: float = 0.0
	var max_p_mag: float = 0.0
	
	for step in range(total_steps):
		verlet.integrate(positions, velocities, masses, force_kepler, dt)
		var snap: Dictionary = sentry.audit(positions, velocities, masses, potential_kepler)
		if snap.energy_drift_ratio > max_e_drift:
			max_e_drift = snap.energy_drift_ratio
		var p_mag: float = snap.linear_momentum.length()
		if p_mag > max_p_mag:
			max_p_mag = p_mag
	
	var final_snap: Dictionary = sentry.get_last_snapshot()
	
	print("  -> Final Energy Drift Ratio: %.8f (%.6f pct)" % [final_snap.energy_drift_ratio, final_snap.energy_drift_ratio * 100.0])
	print("  -> Peak Energy Drift Ratio:  %.8f (%.6f pct)" % [max_e_drift, max_e_drift * 100.0])
	print("  -> Max Linear Momentum |P|:  %.10f" % max_p_mag)
	
	assert_test(final_snap.energy_drift_ratio < 0.001,
		"Unequal mass final energy_drift_ratio < 0.001",
		"Got: %f" % final_snap.energy_drift_ratio
	)
	assert_test(max_e_drift < 0.001,
		"Unequal mass peak energy_drift_ratio < 0.001 over 5,000 steps",
		"Got: %f" % max_e_drift
	)
	assert_test(max_p_mag < 1e-5,
		"Unequal mass |P| conserved near zero (< 1e-5)",
		"Got: %f" % max_p_mag
	)
	assert_test(final_snap.is_conserved == true,
		"Unequal mass system is_conserved == true"
	)
	
	sentry.free()

# ==============================================================================
# Suite 3b: Eccentric 2-Body Keplerian Orbit (e = 0.3, 5,000 steps, dt=0.002)
# ==============================================================================
func _test_suite_3b_eccentric_orbit() -> void:
	print("\n--- Suite 3b: Eccentric 2-Body Keplerian Orbit (e=0.3, 5,000 steps, dt=0.002) ---")
	
	var sentry := ConservationSentry.new()
	var verlet := VerletIntegrator.new()
	
	var m1: float = 1.0
	var m2: float = 1.0
	var total_m: float = m1 + m2
	var g_const: float = 1.0
	var a_semi: float = 1.0
	var ecc: float = 0.3
	var r_p: float = a_semi * (1.0 - ecc) # 0.7
	var v_rel_p: float = sqrt(g_const * total_m * (2.0 / r_p - 1.0 / a_semi)) # sqrt(2 * (2/0.7 - 1)) ~ 1.927248
	var dt: float = 0.002
	var total_steps: int = 5000
	
	var r0_x: float = -0.5 * r_p
	var r1_x: float = +0.5 * r_p
	var v0_y: float = -0.5 * v_rel_p
	var v1_y: float = +0.5 * v_rel_p
	
	var positions := PackedVector3Array([Vector3(r0_x, 0.0, 0.0), Vector3(r1_x, 0.0, 0.0)])
	var velocities := PackedVector3Array([Vector3(0.0, v0_y, 0.0), Vector3(0.0, v1_y, 0.0)])
	var masses := PackedFloat32Array([m1, m2])
	
	var force_kepler := func(p: PackedVector3Array) -> PackedVector3Array:
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
	
	var potential_kepler := func(p: PackedVector3Array) -> float:
		var dist: float = (p[1] - p[0]).length()
		if dist < 1e-6:
			dist = 1e-6
		return - (g_const * m1 * m2) / dist
	
	var init_snap: Dictionary = sentry.audit(positions, velocities, masses, potential_kepler)
	assert_test(is_equal_approx(init_snap.total_energy, -0.5),
		"Initial eccentric total energy E_0 = -0.5",
		"Got: %f" % init_snap.total_energy
	)
	
	var max_e_drift: float = 0.0
	var max_p_mag: float = 0.0
	var max_l_drift: float = 0.0
	
	for step in range(total_steps):
		verlet.integrate(positions, velocities, masses, force_kepler, dt)
		var snap: Dictionary = sentry.audit(positions, velocities, masses, potential_kepler)
		if snap.energy_drift_ratio > max_e_drift:
			max_e_drift = snap.energy_drift_ratio
		var p_mag: float = snap.linear_momentum.length()
		if p_mag > max_p_mag:
			max_p_mag = p_mag
		if snap.angular_momentum_drift > max_l_drift:
			max_l_drift = snap.angular_momentum_drift
	
	var final_snap: Dictionary = sentry.get_last_snapshot()
	print("  -> Eccentric Final Energy Drift: %.8f (%.6f pct)" % [final_snap.energy_drift_ratio, final_snap.energy_drift_ratio * 100.0])
	print("  -> Eccentric Peak Energy Drift:  %.8f (%.6f pct)" % [max_e_drift, max_e_drift * 100.0])
	print("  -> Eccentric Max Linear |P|:    %.10f" % max_p_mag)
	print("  -> Eccentric Max Angular Drift: %.10f" % max_l_drift)
	
	assert_test(final_snap.energy_drift_ratio < 0.001,
		"Eccentric orbit final energy_drift_ratio < 0.001",
		"Got: %f" % final_snap.energy_drift_ratio
	)
	assert_test(max_e_drift < 0.001,
		"Eccentric orbit peak energy_drift_ratio < 0.001 over 5,000 steps",
		"Got: %f" % max_e_drift
	)
	assert_test(max_p_mag < 1e-5,
		"Eccentric orbit |P| conserved near zero (< 1e-5)",
		"Got: %f" % max_p_mag
	)
	assert_test(max_l_drift < 0.01,
		"Eccentric orbit angular momentum conserved (drift < 0.01)",
		"Got: %f" % max_l_drift
	)
	assert_test(final_snap.is_conserved == true,
		"Eccentric orbit system is_conserved == true"
	)
	
	sentry.free()

# ==============================================================================
# Suite 4: ConservationSentry Edge Cases & API Robustness
# ==============================================================================
func _test_suite_4_sentry_edge_cases() -> void:
	print("\n--- Suite 4: ConservationSentry Edge Cases & API Robustness ---")
	
	var sentry := ConservationSentry.new()
	var dummy_pot := func(_p: PackedVector3Array) -> float: return 0.0
	
	# 4.1: Empty particle arrays
	var empty_snap: Dictionary = sentry.audit(PackedVector3Array(), PackedVector3Array(), PackedFloat32Array(), dummy_pot)
	assert_test(not empty_snap.is_empty(), "Empty arrays return non-empty Dictionary")
	assert_test(empty_snap.particle_count == 0, "Empty snapshot reports particle_count == 0")
	assert_test(empty_snap.is_conserved == true, "Empty snapshot reports is_conserved == true")
	
	# 4.2: Array size mismatch
	var bad_snap: Dictionary = sentry.audit(
		PackedVector3Array([Vector3.ZERO]),
		PackedVector3Array([Vector3.ZERO, Vector3.ZERO]),
		PackedFloat32Array([1.0]),
		dummy_pot
	)
	assert_test(bad_snap.is_empty(), "Mismatched array sizes return empty dictionary gracefully without crash")
	
	# 4.3: Invalid potential callable
	var invalid_callable := Callable()
	var valid_pos := PackedVector3Array([Vector3(1, 0, 0)])
	var valid_vel := PackedVector3Array([Vector3(0, 1, 0)])
	var valid_mass := PackedFloat32Array([2.0])
	var no_pot_snap: Dictionary = sentry.audit(valid_pos, valid_vel, valid_mass, invalid_callable)
	assert_test(no_pot_snap.potential_energy == 0.0, "Invalid callable defaults potential energy to 0.0")
	assert_test(is_equal_approx(no_pot_snap.kinetic_energy, 1.0), "Kinetic energy evaluated correctly with invalid callable")
	
	# 4.4: Zero initial energy (e_denom protection)
	sentry.reset()
	sentry.register_system(0.0, Vector3.ZERO, Vector3.ZERO)
	var zero_e_snap: Dictionary = sentry.audit(
		PackedVector3Array([Vector3.ZERO]),
		PackedVector3Array([Vector3.ZERO]),
		PackedFloat32Array([1.0]),
		dummy_pot
	)
	assert_test(not is_nan(zero_e_snap.energy_drift_ratio) and not is_inf(zero_e_snap.energy_drift_ratio),
		"Zero initial energy handles e_denom guard without NaN/Inf crash"
	)
	
	# 4.5: Temperature calculation
	# T = 2 * E_k / (3 * N * k_B)
	# N = 1, k_B = 1.0, E_k = 1.0 -> T = 2.0 / 3.0 ~ 0.666667
	var temp_snap: Dictionary = sentry.audit(valid_pos, valid_vel, valid_mass, dummy_pot)
	assert_test(is_equal_approx(temp_snap.temperature, 2.0 / 3.0),
		"Kinetic temperature conforms to 2*E_k/(3*N*k_B)",
		"Got: %f" % temp_snap.temperature
	)
	
	# 4.6: validate_state helper
	assert_test(sentry.validate_state(valid_pos, valid_vel, valid_mass) == true, "validate_state accepts valid inputs")
	assert_test(sentry.validate_state(PackedVector3Array(), valid_vel, valid_mass) == false, "validate_state rejects empty positions")
	assert_test(sentry.validate_state(valid_pos, PackedVector3Array(), valid_mass) == false, "validate_state rejects empty velocities")
	
	# 4.7: reset clears all state
	sentry.reset()
	assert_test(sentry.is_registered == false, "reset sets is_registered == false")
	assert_test(sentry.get_audit_count() == 0, "reset zeroes audit count")
	assert_test(sentry.get_last_snapshot().is_empty(), "reset clears last snapshot")
	
	sentry.free()

# ==============================================================================
# Suite 5: SpatialHashGrid Acceptance & Stress Test (5,000 Particles)
# ==============================================================================
func _test_suite_5_spatial_hash_grid_5000_particles() -> void:
	print("\n--- Suite 5: SpatialHashGrid Acceptance & Stress Test (5,000 Particles) ---")
	
	var grid := SpatialHashGrid.new()
	var n_particles: int = 5000
	var cell_size: float = 2.5
	grid.initialize(cell_size, n_particles)
	
	# Generate 5,000 pseudo-random particles in [-50, 50]^3 box
	var positions := PackedVector3Array()
	positions.resize(n_particles)
	
	# Deterministic pseudo-random seed generator
	var seed_state: int = 123456789
	var next_rand := func() -> float:
		seed_state = (seed_state * 1103515245 + 12345) & 0x7FFFFFFF
		return (float(seed_state) / 2147483648.0) * 100.0 - 50.0
	
	for i in range(n_particles):
		positions[i] = Vector3(next_rand.call(), next_rand.call(), next_rand.call())
	
	# Bulk build grid
	var build_start_time: int = Time.get_ticks_usec()
	grid.build_grid(positions)
	var build_elapsed_ms: float = float(Time.get_ticks_usec() - build_start_time) / 1000.0
	print("  -> Grid build for 5,000 particles: %.2f ms (Buckets: %d)" % [build_elapsed_ms, grid.get_bucket_count()])
	
	assert_test(grid.get_particle_count() == n_particles, "Grid registered all 5,000 particles")
	assert_test(grid.get_bucket_count() > 0, "Grid populated non-empty hash buckets")
	
	# Execute 50 neighbor queries with search radius R = 4.0 and compare with brute-force O(N)
	var search_radius: float = 4.0
	var r_sq: float = search_radius * search_radius
	var query_count: int = 50
	var query_time_total_usec: int = 0
	var mismatch_found: bool = false
	var total_neighbors_found: int = 0
	
	for q in range(query_count):
		var query_pos := Vector3(next_rand.call(), next_rand.call(), next_rand.call())
		
		# 1. SpatialHashGrid query
		var q_start: int = Time.get_ticks_usec()
		var grid_neighbors: PackedInt32Array = grid.get_neighbors(query_pos, search_radius)
		query_time_total_usec += (Time.get_ticks_usec() - q_start)
		
		total_neighbors_found += grid_neighbors.size()
		
		# 2. Brute-force O(N) ground truth
		var brute_neighbors: PackedInt32Array = PackedInt32Array()
		for i in range(n_particles):
			if query_pos.distance_squared_to(positions[i]) <= r_sq:
				brute_neighbors.append(i)
		brute_neighbors.sort()
		
		# 3. Exact comparison
		if grid_neighbors.size() != brute_neighbors.size():
			mismatch_found = true
			print("    [MISMATCH] Size diff at query %d: Grid %d vs Brute %d" % [q, grid_neighbors.size(), brute_neighbors.size()])
			break
		
		for idx in range(grid_neighbors.size()):
			if grid_neighbors[idx] != brute_neighbors[idx]:
				mismatch_found = true
				print("    [MISMATCH] Index diff at query %d pos %d: Grid %d vs Brute %d" % [q, idx, grid_neighbors[idx], brute_neighbors[idx]])
				break
		
		if mismatch_found:
			break
	
	var avg_query_ms: float = (float(query_time_total_usec) / float(query_count)) / 1000.0
	print("  -> Average query time over 50 queries: %.4f ms" % avg_query_ms)
	print("  -> Total neighbors matched:             %d" % total_neighbors_found)
	
	assert_test(not mismatch_found,
		"SpatialHashGrid neighbor queries match brute-force ground truth 100% identically across 50 queries"
	)
	assert_test(avg_query_ms < 10.0,
		"SpatialHashGrid query runs within 10 ms (got %.4f ms)" % avg_query_ms,
		"Query time: %f ms" % avg_query_ms
	)
	
	# Negative coordinate boundary test:
	var neg_pos := Vector3(-2.4, -0.1, -10.5)
	var neg_coords: Vector3i = grid.get_cell_coords(neg_pos)
	assert_test(neg_coords.x == int(floor(-2.4 / cell_size)) and neg_coords.y == int(floor(-0.1 / cell_size)),
		"get_cell_coords uses strict floor for negative coordinates"
	)
	
	# Runaway search radius clamp test
	var huge_radius: float = 100000.0
	var clamped_res: PackedInt32Array = grid.get_neighbors(Vector3.ZERO, huge_radius)
	assert_test(clamped_res is PackedInt32Array, "Runaway search radius handles MAX_CELL_SPAN clamp safely")

# ==============================================================================
# Suite 6: BarnesHutOctree Integration & Conservation Audit
# ==============================================================================
func _test_suite_6_barnes_hut_conservation_integration() -> void:
	print("\n--- Suite 6: BarnesHutOctree Integration & Conservation Audit ---")
	
	var octree := BarnesHutOctree.new(0.0, 0.0, 1.0) # theta=0.0 (exact direct sum), softening=0.0, G=1.0
	var verlet := VerletIntegrator.new()
	var sentry := ConservationSentry.new()
	
	var m1: float = 1.0
	var m2: float = 1.0
	var positions := PackedVector3Array([Vector3(-1.0, 0.0, 0.0), Vector3(1.0, 0.0, 0.0)])
	var velocities := PackedVector3Array([Vector3(0.0, -0.5, 0.0), Vector3(0.0, 0.5, 0.0)])
	var masses := PackedFloat32Array([m1, m2])
	var dt: float = 0.01
	var steps: int = 1000
	
	var force_fn := func(p: PackedVector3Array) -> PackedVector3Array:
		octree.build(p, masses)
		return octree.compute_all_forces(p, masses, 0.0, 0.0, 1.0)
	
	var pot_fn := func(p: PackedVector3Array) -> float:
		octree.build(p, masses)
		return octree.compute_total_potential_energy(p, masses, 0.0, 0.0, 1.0)
	
	var initial_snap: Dictionary = sentry.audit(positions, velocities, masses, pot_fn)
	assert_test(is_equal_approx(initial_snap.total_energy, -0.25),
		"BarnesHut potential energy evaluates initial 2-body energy E_0 = -0.25",
		"Got: %f" % initial_snap.total_energy
	)
	
	var max_e_drift: float = 0.0
	for step in range(steps):
		verlet.integrate(positions, velocities, masses, force_fn, dt)
		var snap: Dictionary = sentry.audit(positions, velocities, masses, pot_fn)
		if step < 5:
			print("    [EARLY STEP %d] Ek=%.6f, Ep=%.6f, Etot=%.6f, drift=%.8f, r0=%s, r1=%s, v0=%s, v1=%s" % [
				step, snap.kinetic_energy, snap.potential_energy, snap.total_energy, snap.energy_drift_ratio,
				str(positions[0]), str(positions[1]), str(velocities[0]), str(velocities[1])
			])
		if snap.energy_drift_ratio > max_e_drift:
			max_e_drift = snap.energy_drift_ratio
	
	var final_snap: Dictionary = sentry.get_last_snapshot()
	print("  -> BarnesHut 1,000 steps final energy drift: %.8f (%.6f pct)" % [final_snap.energy_drift_ratio, final_snap.energy_drift_ratio * 100.0])
	print("  -> BarnesHut 1,000 steps peak energy drift:  %.8f (%.6f pct)" % [max_e_drift, max_e_drift * 100.0])
	print("  -> BarnesHut linear momentum |P|:           %.10f" % final_snap.linear_momentum.length())
	
	assert_test(final_snap.energy_drift_ratio < 0.001,
		"BarnesHut 2-body orbit maintains energy drift < 0.001",
		"Got: %f" % final_snap.energy_drift_ratio
	)
	assert_test(final_snap.linear_momentum.length() < 1e-5,
		"BarnesHut 2-body orbit maintains linear momentum |P| < 1e-5"
	)
	assert_test(final_snap.is_conserved == true,
		"BarnesHut integrated system remains conserved"
	)
	
	sentry.free()
