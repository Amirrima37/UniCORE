extends SceneTree

# ==============================================================================
# Adversarial Empirical Challenge Suite: Milestone 2
# Conservation Law Sentry & Spatial Partitioning Acceleration
# Author: Reviewer & Adversarial Critic M2-2
# Engine: Godot 4.0.stable.official.92bee43ad
# ==============================================================================

const ConservationSentry = preload("res://core/physics/conservation_sentry.gd")
const SpatialHashGrid = preload("res://core/physics/spatial_hash_grid.gd")
const BarnesHutOctree = preload("res://core/physics/barnes_hut_octree.gd")

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
	print("REVIEWER M2-2: ADVERSARIAL STRESS & EMPIRICAL BENCHMARK HARNESS")
	print("==================================================================")

	_test_conservation_sentry_exhaustive()
	_test_spatial_hash_grid_exhaustive()
	_test_barnes_hut_octree_exhaustive()

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
# Suite 1: ConservationSentry
# ==============================================================================
func _test_conservation_sentry_exhaustive() -> void:
	print("\n--- Suite 1: ConservationSentry Invariants & Edge Cases ---")
	var sentry := ConservationSentry.new()

	# 1.1 Empty array resilience
	var empty_snap: Dictionary = sentry.audit(PackedVector3Array(), PackedVector3Array(), PackedFloat32Array(), Callable())
	assert_check(empty_snap.has("total_energy") and empty_snap["particle_count"] == 0, "Empty particle audit handled gracefully")
	assert_check(empty_snap["is_conserved"] == true, "Empty state marked as conserved")

	# 1.2 Mismatched array lengths
	var mismatch_snap: Dictionary = sentry.audit(
		PackedVector3Array([Vector3(1, 0, 0)]),
		PackedVector3Array(),
		PackedFloat32Array([1.0]),
		Callable()
	)
	assert_check(mismatch_snap.is_empty(), "Mismatched array sizes return empty Dictionary")

	# 1.3 Exact single-particle Ek, P, L calculation
	sentry.reset()
	var pos := PackedVector3Array([Vector3(2.0, 0.0, 0.0)])
	var vel := PackedVector3Array([Vector3(0.0, 3.0, 0.0)])
	var mass := PackedFloat32Array([2.0])
	
	# Potential calculator returning 10.0
	var pot_calc := func(_p: PackedVector3Array) -> float: return 10.0
	
	var snap1: Dictionary = sentry.audit(pos, vel, mass, pot_calc)
	# Ek = 0.5 * 2.0 * (3.0^2) = 9.0
	# P = 2.0 * (0, 3, 0) = (0, 6, 0)
	# L = (2, 0, 0) x (0, 6, 0) = (0, 0, 12)
	# Ep = 10.0 -> Total E = 19.0
	# T = 2 * 9.0 / (3 * 1 * 1.0) = 6.0
	assert_check(absf(snap1["kinetic_energy"] - 9.0) < 1e-6, "Kinetic energy exact evaluation", "Got: %f" % snap1["kinetic_energy"])
	assert_check(absf(snap1["potential_energy"] - 10.0) < 1e-6, "Potential energy exact evaluation")
	assert_check(absf(snap1["total_energy"] - 19.0) < 1e-6, "Total energy exact evaluation")
	assert_check(snap1["linear_momentum"].is_equal_approx(Vector3(0.0, 6.0, 0.0)), "Linear momentum exact evaluation")
	assert_check(snap1["angular_momentum"].is_equal_approx(Vector3(0.0, 0.0, 12.0)), "Angular momentum exact evaluation")
	assert_check(absf(snap1["temperature"] - 6.0) < 1e-6, "Equipartition temperature exact evaluation", "Got: %f" % snap1["temperature"])

	# 1.4 Self-registration on first audit
	assert_check(sentry.is_registered == true, "Sentry self-registers on first audit")
	assert_check(absf(sentry.initial_energy - 19.0) < 1e-6, "Sentry recorded initial energy")

	# 1.5 Drift tracking and warning signal emission
	var warning_fired: Array[String] = []
	sentry.conservation_warning.connect(func(v_type: String, _drift: float): warning_fired.append(v_type))
	
	# Perturb energy by +10% (from 19 to 20.9)
	var pot_calc_drift := func(_p: PackedVector3Array) -> float: return 11.9
	var snap2: Dictionary = sentry.audit(pos, vel, mass, pot_calc_drift)
	var expected_drift: float = absf(20.9 - 19.0) / 19.0 # 0.10
	assert_check(absf(snap2["energy_drift_ratio"] - expected_drift) < 1e-5, "Energy drift ratio accurately tracked", "Got: %f" % snap2["energy_drift_ratio"])
	assert_check(snap2["is_conserved"] == false, "Drift above tolerance correctly flagged as un-conserved")
	assert_check(warning_fired.has("energy"), "conservation_warning signal emitted for energy drift")

	# 1.6 Zero initial baseline division safeguards
	sentry.reset()
	sentry.register_system(0.0, Vector3.ZERO, Vector3.ZERO)
	var vel_zero := PackedVector3Array([Vector3.ZERO])
	var pot_zero := func(_p: PackedVector3Array) -> float: return 0.0
	var snap_zero: Dictionary = sentry.audit(pos, vel_zero, mass, pot_zero)
	assert_check(not is_nan(snap_zero["energy_drift_ratio"]) and not is_inf(snap_zero["energy_drift_ratio"]), "Division by zero safeguard for initial energy = 0")
	assert_check(not is_nan(snap_zero["linear_momentum_drift"]) and not is_inf(snap_zero["linear_momentum_drift"]), "Division by zero safeguard for initial momentum = 0")
	assert_check(not is_nan(snap_zero["angular_momentum_drift"]) and not is_inf(snap_zero["angular_momentum_drift"]), "Division by zero safeguard for initial angular momentum = 0")

	sentry.free()

# ==============================================================================
# Suite 2: SpatialHashGrid
# ==============================================================================
func _test_spatial_hash_grid_exhaustive() -> void:
	print("\n--- Suite 2: SpatialHashGrid Correctness & Performance ---")
	var grid := SpatialHashGrid.new()
	grid.initialize(2.0)

	# 2.1 Floor quantization on negative coordinates
	var c_neg1 := grid.get_cell_coords(Vector3(-0.5, -1.5, -2.5))
	# floor(-0.5/2.0) = floor(-0.25) = -1
	# floor(-1.5/2.0) = floor(-0.75) = -1
	# floor(-2.5/2.0) = floor(-1.25) = -2
	assert_check(c_neg1 == Vector3i(-1, -1, -2), "Negative coordinate floor quantization maps to correct integer cells", "Got: %s" % str(c_neg1))

	var c_pos1 := grid.get_cell_coords(Vector3(0.5, 1.5, 2.5))
	# floor(0.5/2.0) = 0, floor(1.5/2.0) = 0, floor(2.5/2.0) = 1
	assert_check(c_pos1 == Vector3i(0, 0, 1), "Positive coordinate quantization maps to correct integer cells", "Got: %s" % str(c_pos1))

	# 2.2 Equivalence against Brute-Force O(N^2)
	var rng := RandomNumberGenerator.new()
	rng.seed = 424242
	
	var n_test: int = 1000
	var test_positions := PackedVector3Array()
	test_positions.resize(n_test)
	for i in range(n_test):
		test_positions[i] = Vector3(
			rng.randf_range(-50.0, 50.0),
			rng.randf_range(-50.0, 50.0),
			rng.randf_range(-50.0, 50.0)
		)
	
	grid.build_grid(test_positions)
	assert_check(grid.get_particle_count() == n_test, "Bulk build correctly registered particle count")
	
	var query_radius: float = 8.0
	var query_radius_sq: float = query_radius * query_radius
	var brute_force_matches: int = 0
	var total_queries: int = 50

	for q in range(total_queries):
		var q_pos := Vector3(
			rng.randf_range(-40.0, 40.0),
			rng.randf_range(-40.0, 40.0),
			rng.randf_range(-40.0, 40.0)
		)
		
		# Ground truth brute force
		var expected: Array[int] = []
		for i in range(n_test):
			if q_pos.distance_squared_to(test_positions[i]) <= query_radius_sq:
				expected.append(i)
		expected.sort()
		
		var grid_result: PackedInt32Array = grid.get_neighbors(q_pos, query_radius)
		var grid_arr: Array = Array(grid_result)
		grid_arr.sort()
		
		if grid_arr == expected:
			brute_force_matches += 1
		else:
			print("Mismatch at query %d: expected %d particles, got %d" % [q, expected.size(), grid_arr.size()])
	
	assert_check(brute_force_matches == total_queries, "SpatialHashGrid 100% identical to Brute-Force O(N^2) across 50 random queries")

	# 2.3 Performance benchmark: 5,000 particles within 10ms
	var n_perf: int = 5000
	var perf_positions := PackedVector3Array()
	perf_positions.resize(n_perf)
	for i in range(n_perf):
		perf_positions[i] = Vector3(
			rng.randf_range(-100.0, 100.0),
			rng.randf_range(-100.0, 100.0),
			rng.randf_range(-100.0, 100.0)
		)
	
	grid.initialize(5.0)
	grid.build_grid(perf_positions)
	
	var t0: int = Time.get_ticks_usec()
	var test_q_pos := Vector3.ZERO
	var neighbors_found: PackedInt32Array = grid.get_neighbors(test_q_pos, 10.0)
	var t1: int = Time.get_ticks_usec()
	var query_time_ms: float = float(t1 - t0) / 1000.0
	
	print("  [BENCHMARK] 5,000 particle neighbor query took: %.3f ms (found %d neighbors)" % [query_time_ms, neighbors_found.size()])
	assert_check(query_time_ms < 10.0, "SpatialHashGrid query on 5,000 particles completes in < 10 ms (Acceptance Criteria)")

	# 2.4 Boundary edge cases
	var empty_query: PackedInt32Array = grid.get_neighbors(Vector3.ZERO, -1.0)
	assert_check(empty_query.is_empty(), "Negative search radius returns empty array")

	var zero_r_query: PackedInt32Array = grid.get_neighbors(perf_positions[0], 0.0)
	assert_check(zero_r_query.size() >= 1 and zero_r_query[0] == 0, "Zero search radius returns exact particle match")

# ==============================================================================
# Suite 3: BarnesHutOctree
# ==============================================================================
func _test_barnes_hut_octree_exhaustive() -> void:
	print("\n--- Suite 3: BarnesHutOctree Tree & Multipole Gravity ---")
	var octree := BarnesHutOctree.new(0.5, 0.05, 1.0)

	# 3.1 Empty tree queries
	assert_check(octree.is_empty(), "Initial tree is empty")
	assert_check(octree.compute_acceleration(0, Vector3.ZERO) == Vector3.ZERO, "Empty tree acceleration returns Vector3.ZERO")
	assert_check(octree.compute_total_potential_energy(PackedVector3Array(), PackedFloat32Array()) == 0.0, "Empty tree potential energy returns 0.0")

	# 3.2 Two-body gravitational force exact verification
	# m1 at (-5, 0, 0), m2 at (5, 0, 0), masses = 10.0, softening = 0.0, G = 1.0
	# distance = 10.0 -> F = G * m1 * m2 / r^2 = 1.0 * 10 * 10 / 100 = 1.0
	# a1 = F / m1 = 1.0 / 10.0 = 0.1 in +x direction
	var two_pos := PackedVector3Array([Vector3(-5.0, 0.0, 0.0), Vector3(5.0, 0.0, 0.0)])
	var two_mass := PackedFloat32Array([10.0, 10.0])
	octree.build(two_pos, two_mass)
	
	var a0: Vector3 = octree.compute_acceleration(0, two_pos[0], 0.0, 0.0, 1.0)
	var a1: Vector3 = octree.compute_acceleration(1, two_pos[1], 0.0, 0.0, 1.0)
	
	assert_check(absf(a0.x - 0.1) < 1e-5 and absf(a0.y) < 1e-6 and absf(a0.z) < 1e-6, "Two-body acceleration a0 magnitude and direction exact (+x 0.1)", "Got: %s" % str(a0))
	assert_check(absf(a1.x - (-0.1)) < 1e-5 and absf(a1.y) < 1e-6 and absf(a1.z) < 1e-6, "Two-body acceleration a1 magnitude and direction exact (-x -0.1)", "Got: %s" % str(a1))
	assert_check(a0.is_equal_approx(-a1), "Newton's Third Law (a0 = -a1 for equal masses) strictly conserved")

	# 3.3 Coincident particles (singularity & infinite loop guard)
	var coinc_pos := PackedVector3Array([Vector3(1.0, 1.0, 1.0), Vector3(1.0, 1.0, 1.0), Vector3(1.0, 1.0, 1.0)])
	var coinc_mass := PackedFloat32Array([2.0, 3.0, 5.0])
	octree.build(coinc_pos, coinc_mass)
	assert_check(absf(octree.get_total_mass() - 10.0) < 1e-5, "Coincident particles total mass aggregated correctly (10.0)", "Got: %f" % octree.get_total_mass())
	assert_check(octree.get_center_of_mass().is_equal_approx(Vector3(1.0, 1.0, 1.0)), "Coincident particles CoM exact at (1, 1, 1)")

	# 3.4 Direct N-body Equivalence at theta = 0.0 (Zero approximation)
	var rng := RandomNumberGenerator.new()
	rng.seed = 98765
	var n_nb: int = 100
	var nb_pos := PackedVector3Array()
	var nb_mass := PackedFloat32Array()
	nb_pos.resize(n_nb)
	nb_mass.resize(n_nb)
	for i in range(n_nb):
		nb_pos[i] = Vector3(rng.randf_range(-20.0, 20.0), rng.randf_range(-20.0, 20.0), rng.randf_range(-20.0, 20.0))
		nb_mass[i] = rng.randf_range(1.0, 5.0)

	octree.build(nb_pos, nb_mass)
	
	# Direct brute-force acceleration for particle 0 with softening = 0.1
	var soft: float = 0.1
	var soft_sq: float = soft * soft
	var direct_a0 := Vector3.ZERO
	for j in range(1, n_nb):
		var dr: Vector3 = nb_pos[j] - nb_pos[0]
		var d2: float = dr.length_squared() + soft_sq
		var inv_d3: float = 1.0 / (d2 * sqrt(d2))
		direct_a0 += dr * (nb_mass[j] * inv_d3)
	
	# Compute via octree with theta = 0.0 (forces full traversal of all leaves)
	var octree_a0_theta0: Vector3 = octree.compute_acceleration(0, nb_pos[0], 0.0, soft, 1.0)
	var diff_theta0: float = (octree_a0_theta0 - direct_a0).length()
	var rel_err_theta0: float = diff_theta0 / direct_a0.length()
	assert_check(rel_err_theta0 < 1e-5, "Barnes-Hut with theta=0.0 is numerically identical to direct summation (< 1e-5 error)", "Relative error: %f" % rel_err_theta0)

	# 3.5 Multipole opening angle theta = 0.5 accuracy
	var octree_a0_theta05: Vector3 = octree.compute_acceleration(0, nb_pos[0], 0.5, soft, 1.0)
	var diff_theta05: float = (octree_a0_theta05 - direct_a0).length()
	var rel_err_theta05: float = diff_theta05 / direct_a0.length()
	print("  [ACCURACY] Barnes-Hut with theta=0.5 relative error vs direct: %.4f%%" % [rel_err_theta05 * 100.0])
	assert_check(rel_err_theta05 < 0.02, "Barnes-Hut with theta=0.5 retains < 2% relative error vs direct summation")

	# 3.6 Potential Energy U = 0.5 * sum(m_i * Phi(r_i)) vs Brute-Force U
	var direct_u: float = 0.0
	for i in range(n_nb):
		for j in range(i + 1, n_nb):
			var r_ij: float = sqrt((nb_pos[i] - nb_pos[j]).length_squared() + soft_sq)
			direct_u -= (nb_mass[i] * nb_mass[j]) / r_ij
	
	var octree_u: float = octree.compute_total_potential_energy(nb_pos, nb_mass, 0.0, soft, 1.0)
	var u_rel_err: float = absf(octree_u - direct_u) / absf(direct_u)
	assert_check(u_rel_err < 1e-4, "Barnes-Hut total potential energy matches direct pairwise potential (< 1e-4 error)", "Octree U: %f, Direct U: %f, Rel Err: %f" % [octree_u, direct_u, u_rel_err])

	# 3.7 Node pool recycling verification (zero allocation leaks across frames)
	var cap_before: int = octree.get_pool_capacity()
	for cycle in range(5):
		octree.build(nb_pos, nb_mass)
	var cap_after: int = octree.get_pool_capacity()
	assert_check(cap_after == cap_before, "Node pool recycled without memory growth over multiple build cycles", "Before: %d, After: %d" % [cap_before, cap_after])
