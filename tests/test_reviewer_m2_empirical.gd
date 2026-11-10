extends SceneTree

# ==============================================================================
# Independent Empirical Verification & Stress Test Suite for Milestone 2
# Roles: Reviewer & Adversarial Critic
# Components: ConservationSentry, SpatialHashGrid, BarnesHutOctree
# Engine: Godot 4.0.stable
# ==============================================================================

const ConservationSentry = preload("res://core/physics/conservation_sentry.gd")
const SpatialHashGrid = preload("res://core/physics/spatial_hash_grid.gd")
const BarnesHutOctree = preload("res://core/physics/barnes_hut_octree.gd")
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
	print("MILESTONE 2 INDEPENDENT EMPIRICAL VERIFICATION HARNESS")
	print("Engine: Godot 4.0.stable")
	print("==================================================================")

	# ConservationSentry Test Suites
	_test_sentry_contract_and_defaults()
	_test_sentry_edge_cases()
	_test_sentry_kepler_5000_steps()
	_test_sentry_warning_signals()
	_test_sentry_temperature_equipartition()

	# SpatialHashGrid Test Suites
	_test_spatial_grid_contract_and_quantization()
	_test_spatial_grid_deduplication_and_filtering()
	_test_spatial_grid_5000_particles_benchmark()

	# BarnesHutOctree Test Suites
	_test_octree_contract_and_bounds()
	_test_octree_coincident_and_depth_limit()
	_test_octree_pool_recycling()
	_test_octree_direct_summation_equivalence()
	_test_octree_accuracy_at_theta_05()
	_test_octree_potential_energy()

	print("\n==================================================================")
	print("MILESTONE 2 VERIFICATION SUMMARY")
	print("Passed: %d, Failed: %d" % [passed_count, failed_count])
	if errors.size() > 0:
		print("FAILURES:")
		for err in errors:
			print("  - %s" % err)
	print("==================================================================")

	quit(1 if failed_count > 0 else 0)

# ==============================================================================
# SECTION 1: ConservationSentry
# ==============================================================================

func _test_sentry_contract_and_defaults() -> void:
	print("\n--- Sentry Suite 1: Contract, Signals & Defaults ---")
	var sentry := ConservationSentry.new()
	assert_test(sentry != null, "ConservationSentry instantiates via new()")
	assert_test(sentry is Node, "ConservationSentry extends Node")
	assert_test(sentry.has_signal("invariants_updated"), "Has signal invariants_updated")
	assert_test(sentry.has_signal("conservation_warning"), "Has signal conservation_warning")
	assert_test(absf(sentry.energy_tolerance - 0.005) < 1e-6, "Default energy_tolerance is 0.005")
	assert_test(absf(sentry.momentum_tolerance - 0.01) < 1e-6, "Default momentum_tolerance is 0.01")
	assert_test(absf(sentry.angular_momentum_tolerance - 0.01) < 1e-6, "Default angular_momentum_tolerance is 0.01")
	assert_test(absf(sentry.boltzmann_constant - 1.0) < 1e-6, "Default boltzmann_constant is 1.0")
	sentry.free()

func _test_sentry_edge_cases() -> void:
	print("\n--- Sentry Suite 2: Edge Cases (Empty & Mismatched Arrays) ---")
	var sentry := ConservationSentry.new()
	
	# Empty arrays
	var empty_pos: PackedVector3Array = PackedVector3Array()
	var empty_vel: PackedVector3Array = PackedVector3Array()
	var empty_mass: PackedFloat32Array = PackedFloat32Array()
	var dummy_calc: Callable = Callable()
	
	var snap_empty: Dictionary = sentry.audit(empty_pos, empty_vel, empty_mass, dummy_calc)
	assert_test(snap_empty.has("particle_count") and snap_empty["particle_count"] == 0, "Empty audit returns particle_count 0")
	assert_test(snap_empty.has("is_conserved") and snap_empty["is_conserved"] == true, "Empty audit reports is_conserved true")
	
	# Mismatched array dimensions
	var pos1: PackedVector3Array = PackedVector3Array([Vector3(1, 0, 0)])
	var vel_empty: PackedVector3Array = PackedVector3Array()
	var mass1: PackedFloat32Array = PackedFloat32Array([1.0])
	var snap_mismatch: Dictionary = sentry.audit(pos1, vel_empty, mass1, dummy_calc)
	assert_test(snap_mismatch.is_empty(), "Mismatched dimensions safely return empty snapshot without crash")
	
	sentry.free()

func _test_sentry_kepler_5000_steps() -> void:
	print("\n--- Sentry Suite 3: 5,000-Step Kepler 2-Body Orbit Invariant Audit ---")
	var sentry := ConservationSentry.new()
	var verlet := VerletIntegrator.new()
	
	# 2-body isolated symmetric Kepler binary:
	# m1 = m2 = 1.0, G = 1.0, d = 2.0, r1 = (-1, 0, 0), r2 = (1, 0, 0)
	# Centripetal acc for r=1: v^2/r = 0.25 / 1.0 = 0.25 -> v = 0.5.
	var positions: PackedVector3Array = PackedVector3Array([Vector3(-1, 0, 0), Vector3(1, 0, 0)])
	var velocities: PackedVector3Array = PackedVector3Array([Vector3(0, -0.5, 0), Vector3(0, 0.5, 0)])
	var masses: PackedFloat32Array = PackedFloat32Array([1.0, 1.0])
	
	var force_calc: Callable = func(pos: PackedVector3Array) -> PackedVector3Array:
		var f: PackedVector3Array = PackedVector3Array([Vector3.ZERO, Vector3.ZERO])
		var dr: Vector3 = pos[1] - pos[0]
		var dist: float = dr.length()
		if dist > 1e-6:
			var force_mag: float = 1.0 / (dist * dist)
			var force_dir: Vector3 = dr / dist
			f[0] = force_dir * force_mag
			f[1] = -force_dir * force_mag
		return f
	
	var pot_calc: Callable = func(pos: PackedVector3Array) -> float:
		var dr: Vector3 = pos[1] - pos[0]
		var dist: float = dr.length()
		return -1.0 / dist if dist > 1e-6 else 0.0
	
	# Initial audit (auto-registers system)
	var snap0: Dictionary = sentry.audit(positions, velocities, masses, pot_calc)
	var e0: float = snap0["total_energy"]
	assert_test(absf(e0 - (-0.25)) < 1e-5, "Initial Kepler energy analytically correct (-0.25)", "Got %f" % e0)
	assert_test(snap0["linear_momentum"].length() < 1e-6, "Initial linear momentum is Vector3.ZERO")
	assert_test(absf(snap0["angular_momentum"].z - 1.0) < 1e-5, "Initial angular momentum L_z == 1.0")
	
	var dt: float = 0.01
	var max_e_drift: float = 0.0
	var max_p_drift: float = 0.0
	var max_l_drift: float = 0.0
	
	for step in range(5000):
		verlet.integrate(positions, velocities, masses, force_calc, dt)
		var snap: Dictionary = sentry.audit(positions, velocities, masses, pot_calc)
		max_e_drift = maxf(max_e_drift, snap["energy_drift_ratio"])
		max_p_drift = maxf(max_p_drift, snap["linear_momentum_drift"])
		max_l_drift = maxf(max_l_drift, snap["angular_momentum_drift"])
	
	assert_test(max_e_drift < 0.001, "5000-step Kepler energy drift < 0.001 (0.1%)", "Max drift: %f" % max_e_drift)
	assert_test(max_p_drift < 1e-4, "5000-step linear momentum drift < 1e-4", "Max drift: %f" % max_p_drift)
	assert_test(max_l_drift < 1e-4, "5000-step angular momentum drift < 1e-4", "Max drift: %f" % max_l_drift)
	assert_test(sentry.is_system_conserved(), "System remains conserved after 5000 steps")
	
	sentry.free()

func _test_sentry_warning_signals() -> void:
	print("\n--- Sentry Suite 4: Warning Signal Emission on Invariant Violation ---")
	var sentry := ConservationSentry.new()
	var warnings_received: Array[Dictionary] = []
	
	sentry.conservation_warning.connect(func(v_type: String, drift: float) -> void:
		warnings_received.append({"type": v_type, "drift": drift})
	)
	
	var positions: PackedVector3Array = PackedVector3Array([Vector3(0, 0, 0)])
	var velocities: PackedVector3Array = PackedVector3Array([Vector3(1, 0, 0)])
	var masses: PackedFloat32Array = PackedFloat32Array([1.0])
	var dummy_calc: Callable = func(p: PackedVector3Array) -> float: return 0.0
	
	# Initial audit: registers E0 = 0.5
	sentry.audit(positions, velocities, masses, dummy_calc)
	assert_test(warnings_received.is_empty(), "No warning on initial registered audit")
	
	# Induce +20% velocity perturbation -> energy changes by ~44% (> tolerance 0.005)
	velocities[0] = Vector3(1.2, 0, 0)
	sentry.audit(positions, velocities, masses, dummy_calc)
	
	assert_test(warnings_received.size() >= 1, "Warning signal emitted on energy violation")
	var found_energy_warning: bool = false
	for w in warnings_received:
		if w["type"] == "energy" and w["drift"] > 0.005:
			found_energy_warning = true
	assert_test(found_energy_warning, "Energy warning accurately specifies violation type and drift")
	
	sentry.free()

func _test_sentry_temperature_equipartition() -> void:
	print("\n--- Sentry Suite 5: Thermodynamic Kinetic Temperature Equipartition ---")
	var sentry := ConservationSentry.new()
	sentry.boltzmann_constant = 1.0
	
	var positions: PackedVector3Array = PackedVector3Array([Vector3(0,0,0), Vector3(1,0,0), Vector3(2,0,0)])
	var velocities: PackedVector3Array = PackedVector3Array([Vector3(sqrt(3.0),0,0), Vector3(0,sqrt(3.0),0), Vector3(0,0,sqrt(3.0))])
	var masses: PackedFloat32Array = PackedFloat32Array([1.0, 1.0, 1.0])
	var dummy_calc: Callable = func(p: PackedVector3Array) -> float: return 0.0
	
	var snap: Dictionary = sentry.audit(positions, velocities, masses, dummy_calc)
	assert_test(absf(snap["temperature"] - 1.0) < 1e-5, "Kinetic temperature evaluates exactly to 1.0 under equipartition", "Got %f" % snap["temperature"])
	
	sentry.free()

# ==============================================================================
# SECTION 2: SpatialHashGrid
# ==============================================================================

func _test_spatial_grid_contract_and_quantization() -> void:
	print("\n--- Spatial Grid Suite 1: Contract, Initialization & Floor Quantization ---")
	var grid := SpatialHashGrid.new()
	grid.initialize(2.5, 5000)
	assert_test(absf(grid.cell_size - 2.5) < 1e-6, "cell_size initialized to 2.5")
	assert_test(absf(grid.inverse_cell_size - 0.4) < 1e-6, "inverse_cell_size initialized to 1/2.5 = 0.4")
	
	# Negative coordinate floor quantization:
	var c_neg: Vector3i = grid.get_cell_coords(Vector3(-0.5, -0.5, -0.5))
	assert_test(c_neg == Vector3i(-1, -1, -1), "Negative coordinate (-0.5, -0.5, -0.5) quantizes to (-1, -1, -1)", "Got %s" % str(c_neg))
	
	var c_pos: Vector3i = grid.get_cell_coords(Vector3(0.5, 0.5, 0.5))
	assert_test(c_pos == Vector3i(0, 0, 0), "Positive coordinate (0.5, 0.5, 0.5) quantizes to (0, 0, 0)", "Got %s" % str(c_pos))

func _test_spatial_grid_deduplication_and_filtering() -> void:
	print("\n--- Spatial Grid Suite 2: Deduplication, Filtering & Radius Edge Cases ---")
	var grid := SpatialHashGrid.new()
	grid.initialize(2.0)
	
	grid.insert(0, Vector3(0, 0, 0))
	grid.insert(1, Vector3(1.0, 0, 0))
	grid.insert(2, Vector3(1.8, 0, 0))
	grid.insert(3, Vector3(2.5, 0, 0))
	
	var neighbors: PackedInt32Array = grid.get_neighbors(Vector3(0, 0, 0), 1.5)
	assert_test(neighbors.size() == 2, "Euclidean filter includes exactly 2 particles", "Got %d" % neighbors.size())
	assert_test(neighbors.has(0) and neighbors.has(1), "Returns p0 and p1")
	assert_test(not neighbors.has(2), "Correctly excludes p2 (dist 1.8 > 1.5) even though it shares cell with p1")
	assert_test(not neighbors.has(3), "Correctly excludes p3 (dist 2.5 > 1.5)")
	
	# Radius 0.0 query: exactly coincident particles
	var coinc_neighbors: PackedInt32Array = grid.get_neighbors(Vector3(0, 0, 0), 0.0)
	assert_test(coinc_neighbors.size() == 1 and coinc_neighbors[0] == 0, "Radius 0.0 query returns exactly coincident particle")

func _test_spatial_grid_5000_particles_benchmark() -> void:
	print("\n--- Spatial Grid Suite 3: 5,000-Particle Benchmark & Brute-Force Equivalence ---")
	var grid := SpatialHashGrid.new()
	grid.initialize(2.5, 5000)
	
	var n: int = 5000
	var positions: PackedVector3Array = PackedVector3Array()
	positions.resize(n)
	
	# Pseudo-random deterministic distribution in [-25.0, 25.0]^3
	var seed_val: int = 42
	for i in range(n):
		seed_val = (seed_val * 1664525 + 1013904223) & 0x7FFFFFFF
		var rx: float = (float(seed_val) / float(0x7FFFFFFF)) * 50.0 - 25.0
		seed_val = (seed_val * 1664525 + 1013904223) & 0x7FFFFFFF
		var ry: float = (float(seed_val) / float(0x7FFFFFFF)) * 50.0 - 25.0
		seed_val = (seed_val * 1664525 + 1013904223) & 0x7FFFFFFF
		var rz: float = (float(seed_val) / float(0x7FFFFFFF)) * 50.0 - 25.0
		positions[i] = Vector3(rx, ry, rz)
	
	# Benchmark build time
	var t0: int = Time.get_ticks_usec()
	grid.build_grid(positions)
	var t1: int = Time.get_ticks_usec()
	var build_ms: float = float(t1 - t0) / 1000.0
	print("  SpatialHashGrid build_grid(5000) took: %f ms" % build_ms)
	assert_test(build_ms < 10.0, "Build time on 5000 particles < 10 ms budget", "%f ms" % build_ms)
	
	var search_radius: float = 2.5
	var r_sq: float = search_radius * search_radius
	var equivalence_passed: bool = true
	var query_time_total_usec: int = 0
	
	var probe_positions: Array[Vector3] = [
		Vector3.ZERO,
		Vector3(-24, -24, -24),
		Vector3(24, 24, 24),
		Vector3(-10, 15, -5),
		positions[0],
		positions[2500],
		positions[4999]
	]
	
	for probe in probe_positions:
		var q_t0: int = Time.get_ticks_usec()
		var grid_res: PackedInt32Array = grid.get_neighbors(probe, search_radius)
		var q_t1: int = Time.get_ticks_usec()
		query_time_total_usec += (q_t1 - q_t0)
		
		# Brute-force ground truth
		var brute_res: Array[int] = []
		for i in range(n):
			if probe.distance_squared_to(positions[i]) <= r_sq:
				brute_res.append(i)
		brute_res.sort()
		
		if grid_res.size() != brute_res.size():
			equivalence_passed = false
			print("  [FAIL] Size mismatch at probe %s: grid=%d, brute=%d" % [str(probe), grid_res.size(), brute_res.size()])
			break
		
		for k in range(grid_res.size()):
			if grid_res[k] != brute_res[k]:
				equivalence_passed = false
				print("  [FAIL] Element mismatch at probe %s, index %d" % [str(probe), k])
				break
	
	var avg_query_ms: float = (float(query_time_total_usec) / float(probe_positions.size())) / 1000.0
	print("  Average single query latency: %f ms" % avg_query_ms)
	assert_test(equivalence_passed, "100% Equivalence: Grid query matches Brute Force across all probes (0 false pos/neg)")
	assert_test(avg_query_ms < 1.0, "Average query latency < 1.0 ms", "%f ms" % avg_query_ms)

# ==============================================================================
# SECTION 3: BarnesHutOctree
# ==============================================================================

func _test_octree_contract_and_bounds() -> void:
	print("\n--- Octree Suite 1: Contract, Initialization & Cubic Bounds ---")
	var octree := BarnesHutOctree.new(0.5, 0.05, 1.0)
	assert_test(octree != null, "BarnesHutOctree instantiates via new()")
	assert_test(absf(octree.theta_crit - 0.5) < 1e-6, "theta_crit is 0.5")
	assert_test(absf(octree.softening - 0.05) < 1e-6, "softening is 0.05")
	assert_test(absf(octree.gravitational_constant - 1.0) < 1e-6, "G is 1.0")
	
	var p: PackedVector3Array = PackedVector3Array([Vector3(5, 5, 5)])
	var m: PackedFloat32Array = PackedFloat32Array([10.0])
	octree.build(p, m)
	
	assert_test(octree.get_particle_count() == 1, "Particle count is 1")
	assert_test(octree.get_node_count() == 1, "Node count is 1 for single particle")
	assert_test(absf(octree.get_total_mass() - 10.0) < 1e-6, "Total mass is 10.0")
	assert_test(octree.get_center_of_mass().is_equal_approx(Vector3(5, 5, 5)), "Center of mass is at (5, 5, 5)")
	
	var b: AABB = octree.get_root_bounds()
	assert_test(absf(b.size.x - b.size.y) < 1e-5 and absf(b.size.y - b.size.z) < 1e-5, "Root bounds are cubic")
	assert_test(b.has_point(Vector3(5, 5, 5)), "Root bounds contain the particle")

func _test_octree_coincident_and_depth_limit() -> void:
	print("\n--- Octree Suite 2: Coincident Particles & Depth Safeguard ---")
	var octree := BarnesHutOctree.new()
	
	var p: PackedVector3Array = PackedVector3Array()
	var m: PackedFloat32Array = PackedFloat32Array()
	p.resize(10)
	m.resize(10)
	for i in range(10):
		p[i] = Vector3(5, 5, 5)
		m[i] = 1.0
	
	octree.build(p, m)
	assert_test(octree.get_particle_count() == 10, "Handles 10 coincident particles")
	assert_test(octree.get_node_count() == 1, "Single leaf node holds all coincident particles")
	assert_test(absf(octree.get_total_mass() - 10.0) < 1e-6, "Combined mass is 10.0")
	assert_test(octree.get_max_depth() <= 32, "Depth strictly <= MAX_DEPTH (32)")

func _test_octree_pool_recycling() -> void:
	print("\n--- Octree Suite 3: Node Pool Recycling (Zero Leaks) ---")
	var octree := BarnesHutOctree.new()
	
	var n: int = 200
	var p: PackedVector3Array = PackedVector3Array()
	var m: PackedFloat32Array = PackedFloat32Array()
	p.resize(n)
	m.resize(n)
	for i in range(n):
		p[i] = Vector3(sin(float(i)), cos(float(i)), sin(float(i) * 2.0)) * 10.0
		m[i] = 1.0
	
	octree.build(p, m)
	var initial_capacity: int = octree.get_pool_capacity()
	assert_test(initial_capacity > 0, "Pool populated with nodes")
	
	var leak_detected: bool = false
	for cycle in range(20):
		octree.build(p, m)
		if octree.get_pool_capacity() != initial_capacity:
			leak_detected = true
			break
	
	assert_test(not leak_detected, "Node pool capacity completely stabilized (zero ongoing allocations)")

func _test_octree_direct_summation_equivalence() -> void:
	print("\n--- Octree Suite 4: Direct Summation Equivalence at theta_crit = 0.0 ---")
	var octree := BarnesHutOctree.new(0.0, 0.05, 1.0)
	
	var n: int = 30
	var positions: PackedVector3Array = PackedVector3Array()
	var masses: PackedFloat32Array = PackedFloat32Array()
	positions.resize(n)
	masses.resize(n)
	
	for i in range(n):
		var ang: float = float(i) * (PI * 2.0 / float(n))
		positions[i] = Vector3(cos(ang) * 5.0, sin(ang) * 5.0, float(i) * 0.2)
		masses[i] = 1.0 + float(i) * 0.1
	
	octree.build(positions, masses)
	
	var eps_sq: float = 0.05 * 0.05
	var direct_accels: PackedVector3Array = PackedVector3Array()
	direct_accels.resize(n)
	
	for i in range(n):
		var acc_i: Vector3 = Vector3.ZERO
		for j in range(n):
			if i == j: continue
			var dr: Vector3 = positions[j] - positions[i]
			var dist_sq: float = dr.length_squared()
			var denom: float = dist_sq + eps_sq
			var inv_dist: float = 1.0 / sqrt(denom)
			var inv_dist3: float = inv_dist * inv_dist * inv_dist
			acc_i += dr * (1.0 * masses[j] * inv_dist3)
		direct_accels[i] = acc_i
	
	var octree_accels: PackedVector3Array = octree.compute_all_accelerations(positions, masses, 0.0, 0.05, 1.0)
	
	var max_diff: float = 0.0
	for i in range(n):
		var diff: float = (direct_accels[i] - octree_accels[i]).length()
		max_diff = maxf(max_diff, diff)
	
	print("  Max difference at theta=0.0: %f" % max_diff)
	assert_test(max_diff < 1e-4, "BarnesHut at theta=0 matches direct summation to machine precision (< 1e-4)", "Max diff: %f" % max_diff)

func _test_octree_accuracy_at_theta_05() -> void:
	print("\n--- Octree Suite 5: Approximation Accuracy at theta_crit = 0.5 ---")
	var octree := BarnesHutOctree.new(0.5, 0.05, 1.0)
	
	var n: int = 50
	var positions: PackedVector3Array = PackedVector3Array()
	var masses: PackedFloat32Array = PackedFloat32Array()
	positions.resize(n)
	masses.resize(n)
	
	for i in range(n):
		positions[i] = Vector3(sin(float(i * 3)), cos(float(i * 5)), sin(float(i * 7))) * 8.0
		masses[i] = 1.0
	
	octree.build(positions, masses)
	
	var eps_sq: float = 0.05 * 0.05
	var direct_accels: PackedVector3Array = PackedVector3Array()
	direct_accels.resize(n)
	
	for i in range(n):
		var acc_i: Vector3 = Vector3.ZERO
		for j in range(n):
			if i == j: continue
			var dr: Vector3 = positions[j] - positions[i]
			var dist_sq: float = dr.length_squared()
			var denom: float = dist_sq + eps_sq
			var inv_dist: float = 1.0 / sqrt(denom)
			var inv_dist3: float = inv_dist * inv_dist * inv_dist
			acc_i += dr * (1.0 * masses[j] * inv_dist3)
		direct_accels[i] = acc_i
	
	var octree_accels: PackedVector3Array = octree.compute_all_accelerations(positions, masses, 0.5, 0.05, 1.0)
	
	var max_rel_err: float = 0.0
	var sum_rel_err: float = 0.0
	var count: int = 0
	for i in range(n):
		var mag_true: float = direct_accels[i].length()
		if mag_true > 1e-6:
			var rel_err: float = (direct_accels[i] - octree_accels[i]).length() / mag_true
			max_rel_err = maxf(max_rel_err, rel_err)
			sum_rel_err += rel_err
			count += 1
	
	var avg_rel_err: float = sum_rel_err / float(count)
	print("  Average relative error at theta=0.5: %f%%" % (avg_rel_err * 100.0))
	print("  Peak relative error at theta=0.5: %f%%" % (max_rel_err * 100.0))
	assert_test(avg_rel_err < 0.015, "Average relative force error < 1.5% at theta=0.5", "Avg: %f%%" % (avg_rel_err * 100.0))
	assert_test(max_rel_err < 0.08, "Peak relative force error < 8.0% at theta=0.5", "Peak: %f%%" % (max_rel_err * 100.0))

func _test_octree_potential_energy() -> void:
	print("\n--- Octree Suite 6: Gravitational Potential Energy U = 0.5 * sum(m_i * Phi_i) ---")
	var octree := BarnesHutOctree.new(0.0, 0.0, 1.0)
	
	var p: PackedVector3Array = PackedVector3Array([Vector3(0, 0, 0), Vector3(3.0, 0, 0)])
	var m: PackedFloat32Array = PackedFloat32Array([1.0, 2.0])
	
	var u: float = octree.compute_total_potential_energy(p, m, 0.0, 0.0, 1.0)
	print("  Computed U = %f, Expected U = %f" % [u, -2.0 / 3.0])
	assert_test(absf(u - (-2.0 / 3.0)) < 1e-5, "Potential energy matches analytical formula (-2/3 J)", "Got %f" % u)
