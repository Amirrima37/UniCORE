extends SceneTree

# ==============================================================================
# Adversarial Empirical Challenge Suite: Milestone 2
# Conservation Law Sentry, SpatialHashGrid, and BarnesHutOctree
# Author: Challenger M2-2 (Empirical Challenger)
# Engine: Godot 4.0.stable.official.92bee43ad
# ==============================================================================

const SpatialHashGrid = preload("res://core/physics/spatial_hash_grid.gd")
const BarnesHutOctree = preload("res://core/physics/barnes_hut_octree.gd")
const ConservationSentry = preload("res://core/physics/conservation_sentry.gd")

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
	print("CHALLENGER M2-2: EMPIRICAL ADVERSARIAL STRESS HARNESS")
	print("==================================================================")
	
	_test_spatial_hash_grid_5000_particles_benchmark()
	_test_spatial_hash_grid_adversarial_edge_cases()
	_test_barnes_hut_theta_zero_direct_equivalence()
	_test_barnes_hut_theta_half_accuracy()
	_test_barnes_hut_node_pooling_50_frames_zero_leaks()
	_test_barnes_hut_adversarial_edge_cases()
	_test_conservation_sentry_noether_invariants_and_triggers()
	
	print("\n==================================================================")
	print("EMPIRICAL ADVERSARIAL STRESS HARNESS SUMMARY")
	print("Passed: %d, Failed: %d" % [passed_count, failed_count])
	if failed_count > 0:
		print("FAILURES DETECTED:")
		for f in failure_messages:
			print(f)
	print("==================================================================")
	
	quit(1 if failed_count > 0 else 0)

# ==============================================================================
# Suite 1: SpatialHashGrid 5,000 Particles Benchmark & Precision/Recall
# ==============================================================================
func _test_spatial_hash_grid_5000_particles_benchmark() -> void:
	print("\n--- Suite 1: SpatialHashGrid 5,000 Particles Benchmark & Precision/Recall ---")
	
	var n_particles: int = 5000
	var positions: PackedVector3Array = PackedVector3Array()
	positions.resize(n_particles)
	
	# Seeded deterministic pseudo-random generator
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 424242
	
	var box_span: float = 100.0
	for i in range(n_particles):
		positions[i] = Vector3(
			rng.randf_range(-box_span * 0.5, box_span * 0.5),
			rng.randf_range(-box_span * 0.5, box_span * 0.5),
			rng.randf_range(-box_span * 0.5, box_span * 0.5)
		)
	
	var grid := SpatialHashGrid.new()
	var cell_size: float = 5.0
	grid.initialize(cell_size)
	
	var t_build_start: int = Time.get_ticks_usec()
	grid.build_grid(positions)
	var t_build_end: int = Time.get_ticks_usec()
	var build_ms: float = float(t_build_end - t_build_start) / 1000.0
	print("  SpatialHashGrid build time for 5,000 particles: %.3f ms (Buckets: %d)" % [build_ms, grid.get_bucket_count()])
	assert_check(grid.get_particle_count() == n_particles, "Grid registered all 5,000 particles")
	
	# Generate 25 probe queries across various spatial configurations
	var probes: Array[Vector3] = []
	var radii: Array[float] = [2.5, 5.0, 7.5, 10.0, 15.0]
	
	# Probes inside volume
	for i in range(15):
		probes.append(Vector3(
			rng.randf_range(-40.0, 40.0),
			rng.randf_range(-40.0, 40.0),
			rng.randf_range(-40.0, 40.0)
		))
	# Probes near boundaries
	probes.append(Vector3(-50.0, 0.0, 0.0))
	probes.append(Vector3(50.0, 50.0, -50.0))
	probes.append(Vector3(0.0, -50.0, 50.0))
	probes.append(Vector3(0.0, 0.0, 0.0))
	probes.append(Vector3(-49.9, -49.9, -49.9))
	# Probes centered exactly on specific particles
	probes.append(positions[0])
	probes.append(positions[2500])
	probes.append(positions[4999])
	probes.append(positions[1234])
	probes.append(positions[3456])
	
	var max_query_time_ms: float = 0.0
	var total_query_time_us: int = 0
	var total_queries: int = 0
	var all_precision_perfect: bool = true
	var all_recall_perfect: bool = true
	var worst_diff_summary: String = ""
	
	for p_idx in range(probes.size()):
		var probe_pos: Vector3 = probes[p_idx]
		var radius: float = radii[p_idx % radii.size()]
		var r_sq: float = radius * radius
		
		# 1. Naive O(N) brute-force linear search baseline
		var expected_neighbors: Array[int] = []
		for i in range(n_particles):
			if probe_pos.distance_squared_to(positions[i]) <= r_sq:
				expected_neighbors.append(i)
		expected_neighbors.sort()
		
		# 2. SpatialHashGrid neighbor query with high-resolution timing
		var t0: int = Time.get_ticks_usec()
		var grid_result: PackedInt32Array = grid.get_neighbors(probe_pos, radius)
		var t1: int = Time.get_ticks_usec()
		
		var elapsed_us: int = t1 - t0
		var elapsed_ms: float = float(elapsed_us) / 1000.0
		if elapsed_ms > max_query_time_ms:
			max_query_time_ms = elapsed_ms
		total_query_time_us += elapsed_us
		total_queries += 1
		
		# Convert grid_result to Array for comparison
		var actual_neighbors: Array[int] = []
		for idx in grid_result:
			actual_neighbors.append(idx)
		actual_neighbors.sort()
		
		# 3. Precision & Recall Evaluation
		if actual_neighbors != expected_neighbors:
			all_precision_perfect = false
			all_recall_perfect = false
			worst_diff_summary = "Probe %d (R=%.1f): expected %d particles, got %d" % [
				p_idx, radius, expected_neighbors.size(), actual_neighbors.size()
			]
			break
	
	var avg_query_time_us: float = float(total_query_time_us) / float(total_queries)
	print("  Executed %d probe queries on 5,000 particles" % total_queries)
	print("  Worst query time: %.3f ms (Requirement: strictly < 10.0 ms)" % max_query_time_ms)
	print("  Average query time: %.2f us (%.4f ms)" % [avg_query_time_us, avg_query_time_us / 1000.0])
	
	assert_check(max_query_time_ms < 10.0, "SpatialHashGrid query latency < 10 ms", "Max time was %.3f ms" % max_query_time_ms)
	assert_check(all_precision_perfect and all_recall_perfect, "100% precision and recall equivalence vs O(N^2) brute force", worst_diff_summary)

# ==============================================================================
# Suite 2: SpatialHashGrid Adversarial Edge Cases
# ==============================================================================
func _test_spatial_hash_grid_adversarial_edge_cases() -> void:
	print("\n--- Suite 2: SpatialHashGrid Adversarial Edge Cases ---")
	
	var grid := SpatialHashGrid.new()
	grid.initialize(2.0)
	
	# Edge Case 2.1: Empty grid query
	var empty_res: PackedInt32Array = grid.get_neighbors(Vector3(1, 2, 3), 5.0)
	assert_check(empty_res.is_empty(), "Empty grid returns empty neighbor list without error")
	
	# Edge Case 2.2: Negative search radius
	grid.insert(0, Vector3(0, 0, 0))
	var neg_radius_res: PackedInt32Array = grid.get_neighbors(Vector3(0, 0, 0), -1.0)
	assert_check(neg_radius_res.is_empty(), "Negative search radius returns empty array")
	
	# Edge Case 2.3: Degenerate radius R = 0.0
	var zero_radius_res: PackedInt32Array = grid.get_neighbors(Vector3(0, 0, 0), 0.0)
	assert_check(zero_radius_res.size() == 1 and zero_radius_res[0] == 0, "Zero search radius returns exact coincident particle")
	
	# Edge Case 2.4: Deep negative coordinates & boundary crossing
	var neg_positions: PackedVector3Array = PackedVector3Array([
		Vector3(-50.5, -50.5, -50.5), # idx 0
		Vector3(-50.0, -50.0, -50.0), # idx 1 (boundary)
		Vector3(-49.5, -49.5, -49.5), # idx 2
		Vector3(-0.01, -0.01, -0.01), # idx 3 (crossing zero)
		Vector3(0.01, 0.01, 0.01),    # idx 4
	])
	grid.build_grid(neg_positions)
	
	var probe_zero: Vector3 = Vector3(0, 0, 0)
	var res_zero: PackedInt32Array = grid.get_neighbors(probe_zero, 0.1)
	assert_check(res_zero.has(3) and res_zero.has(4) and res_zero.size() == 2, "Crosses negative-to-positive octant boundaries seamlessly")
	
	# Edge Case 2.5: Particles right on spherical boundary (distance == R)
	var boundary_grid := SpatialHashGrid.new()
	boundary_grid.initialize(1.0)
	var center := Vector3(10.0, 10.0, 10.0)
	var r: float = 3.0
	var boundary_positions: PackedVector3Array = PackedVector3Array([
		center + Vector3(r, 0, 0),            # Exact boundary
		center + Vector3(0, -r, 0),           # Exact boundary
		center + Vector3(0, 0, r),            # Exact boundary
		center + Vector3(r + 0.0001, 0, 0),   # Outside
		center + Vector3(r - 0.0001, 0, 0)    # Inside
	])
	boundary_grid.build_grid(boundary_positions)
	var b_neighbors: PackedInt32Array = boundary_grid.get_neighbors(center, r)
	assert_check(b_neighbors.has(0) and b_neighbors.has(1) and b_neighbors.has(2) and b_neighbors.has(4), "Exact boundary particles included in radius R")
	assert_check(not b_neighbors.has(3), "Particles outside boundary excluded")
	
	# Edge Case 2.6: Multiple coincident particles
	var coinc_grid := SpatialHashGrid.new()
	coinc_grid.initialize(2.0)
	var coinc_pos: Vector3 = Vector3(5, 5, 5)
	for i in range(10):
		coinc_grid.insert(i, coinc_pos)
	var coinc_res: PackedInt32Array = coinc_grid.get_neighbors(coinc_pos, 0.5)
	assert_check(coinc_res.size() == 10, "Handles 10 coincident particles without duplicate omission or duplication")

# ==============================================================================
# Suite 3: BarnesHutOctree Direct Summation Equivalence (theta_crit = 0.0)
# ==============================================================================
func _test_barnes_hut_theta_zero_direct_equivalence() -> void:
	print("\n--- Suite 3: BarnesHutOctree Direct Summation Equivalence (theta = 0.0) ---")
	
	var n: int = 200
	var positions: PackedVector3Array = PackedVector3Array()
	positions.resize(n)
	var masses: PackedFloat32Array = PackedFloat32Array()
	masses.resize(n)
	
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 987654
	
	for i in range(n):
		positions[i] = Vector3(
			rng.randf_range(-25.0, 25.0),
			rng.randf_range(-25.0, 25.0),
			rng.randf_range(-25.0, 25.0)
		)
		masses[i] = rng.randf_range(0.5, 3.0)
	
	var eps: float = 0.1
	var g: float = 1.0
	var eps_sq: float = eps * eps
	
	# 1. Compute exact brute-force direct summation accelerations
	var direct_accels: PackedVector3Array = PackedVector3Array()
	direct_accels.resize(n)
	
	for i in range(n):
		var acc_i: Vector3 = Vector3.ZERO
		var p_i: Vector3 = positions[i]
		for j in range(n):
			if i == j:
				continue
			var dr: Vector3 = positions[j] - p_i
			var dist_sq: float = dr.length_squared()
			var denom: float = dist_sq + eps_sq
			var inv_dist3: float = 1.0 / (denom * sqrt(denom))
			acc_i += dr * (g * masses[j] * inv_dist3)
		direct_accels[i] = acc_i
	
	# 2. Compute via BarnesHutOctree with theta_crit = 0.0
	var octree := BarnesHutOctree.new(0.0, eps, g)
	octree.build(positions, masses)
	
	var octree_accels: PackedVector3Array = octree.compute_all_accelerations(positions, masses, 0.0, eps, g)
	
	var max_diff: float = 0.0
	var sum_diff: float = 0.0
	var sum_direct: float = 0.0
	
	for i in range(n):
		var diff_vec: Vector3 = octree_accels[i] - direct_accels[i]
		var diff_mag: float = diff_vec.length()
		if diff_mag > max_diff:
			max_diff = diff_mag
		sum_diff += diff_mag
		sum_direct += direct_accels[i].length()
	
	var rel_error_direct: float = sum_diff / sum_direct
	print("  BarnesHut (theta=0.0) vs Direct Summation on N=%d:" % n)
	print("    Max Vector Difference: %.8f" % max_diff)
	print("    Cumulative Relative Difference: %.8f" % rel_error_direct)
	
	# In float arithmetic with different summation order, differences should be < 1e-4
	assert_check(max_diff < 1e-4, "BarnesHut (theta=0.0) matches direct summation within machine float epsilon", "Max diff was %.8f" % max_diff)
	assert_check(rel_error_direct < 1e-5, "Cumulative relative difference is below 1e-5", "Relative diff was %.8f" % rel_error_direct)
	
	# Also verify total potential energy direct summation vs octree
	var direct_potential: float = 0.0
	for i in range(n):
		for j in range(i + 1, n):
			var dist: float = sqrt((positions[i] - positions[j]).length_squared() + eps_sq)
			direct_potential -= g * masses[i] * masses[j] / dist
	
	var octree_potential: float = octree.compute_total_potential_energy(positions, masses, 0.0, eps, g)
	var pot_rel_diff: float = absf(octree_potential - direct_potential) / absf(direct_potential)
	print("    Direct Potential: %.6f, Octree Potential: %.6f, Rel Diff: %.8f" % [direct_potential, octree_potential, pot_rel_diff])
	assert_check(pot_rel_diff < 1e-5, "Direct potential energy matches octree potential (theta=0.0)")

# ==============================================================================
# Suite 4: BarnesHutOctree Multipole Approximation Error (theta_crit = 0.5)
# ==============================================================================
func _test_barnes_hut_theta_half_accuracy() -> void:
	print("\n--- Suite 4: BarnesHutOctree Multipole Approximation Error (theta = 0.5) ---")
	
	var n: int = 1000
	var positions: PackedVector3Array = PackedVector3Array()
	positions.resize(n)
	var masses: PackedFloat32Array = PackedFloat32Array()
	masses.resize(n)
	
	# Create Plummer-like spherical cluster
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 11223344
	
	var scale_radius: float = 10.0
	for i in range(n):
		# Rejection sampling for spherical Plummer density profile
		var u: float = rng.randf_range(0.001, 0.999)
		var r: float = scale_radius / sqrt(pow(u, -2.0 / 3.0) - 1.0)
		r = minf(r, 40.0) # truncate tail
		var costheta: float = rng.randf_range(-1.0, 1.0)
		var phi: float = rng.randf_range(0.0, TAU)
		var sintheta: float = sqrt(maxf(0.0, 1.0 - costheta * costheta))
		
		positions[i] = Vector3(
			r * sintheta * cos(phi),
			r * sintheta * sin(phi),
			r * costheta
		)
		masses[i] = 1.0
	
	var eps: float = 0.5
	var g: float = 1.0
	var eps_sq: float = eps * eps
	
	# 1. Compute direct summation forces for a random representative sample of 100 particles
	# (comparing sample to avoid excessive O(N^2) time while retaining rigorous statistical power)
	var sample_indices: Array[int] = []
	var sample_count: int = 150
	for s in range(sample_count):
		sample_indices.append(rng.randi_range(0, n - 1))
	
	var direct_sample_forces: Array[Vector3] = []
	for s_idx in sample_indices:
		var f_i: Vector3 = Vector3.ZERO
		var p_i: Vector3 = positions[s_idx]
		for j in range(n):
			if s_idx == j:
				continue
			var dr: Vector3 = positions[j] - p_i
			var dist_sq: float = dr.length_squared()
			var denom: float = dist_sq + eps_sq
			var inv_dist3: float = 1.0 / (denom * sqrt(denom))
			f_i += dr * (g * masses[s_idx] * masses[j] * inv_dist3)
		direct_sample_forces.append(f_i)
	
	# 2. Compute via BarnesHutOctree with theta = 0.5
	var octree := BarnesHutOctree.new(0.5, eps, g)
	octree.build(positions, masses)
	
	var sum_force_error: float = 0.0
	var sum_direct_force: float = 0.0
	var particle_relative_errors: Array[float] = []
	
	for s in range(sample_count):
		var s_idx: int = sample_indices[s]
		var f_direct: Vector3 = direct_sample_forces[s]
		var f_bh: Vector3 = octree.compute_force(s_idx, positions[s_idx], masses[s_idx], 0.5, eps, g)
		
		var err_mag: float = (f_bh - f_direct).length()
		var dir_mag: float = f_direct.length()
		sum_force_error += err_mag
		sum_direct_force += dir_mag
		
		if dir_mag > 1e-12:
			particle_relative_errors.append(err_mag / dir_mag)
	
	var system_relative_error: float = sum_force_error / sum_direct_force
	particle_relative_errors.sort()
	var median_rel_error: float = particle_relative_errors[particle_relative_errors.size() / 2]
	
	print("  Barnes-Hut (theta=0.5) Force Error on N=%d Plummer Cluster:" % n)
	print("    System-Wide Relative Force Error: %.4f %% (Requirement: < 1.00 %%)" % [system_relative_error * 100.0])
	print("    Median Particle Relative Error: %.4f %%" % [median_rel_error * 100.0])
	
	assert_check(system_relative_error < 0.01, "BarnesHut (theta=0.5) system relative force error < 1%", "Error was %.4f %%" % [system_relative_error * 100.0])
	assert_check(median_rel_error < 0.01, "Median particle relative error < 1%", "Median was %.4f %%" % [median_rel_error * 100.0])

# ==============================================================================
# Suite 5: BarnesHutOctree 50 Consecutive Frames Node Pooling & Leak Verification
# ==============================================================================
func _test_barnes_hut_node_pooling_50_frames_zero_leaks() -> void:
	print("\n--- Suite 5: BarnesHutOctree 50-Frame Node Pooling & Zero Allocation Leaks ---")
	
	var n: int = 500
	var positions: PackedVector3Array = PackedVector3Array()
	positions.resize(n)
	var velocities: PackedVector3Array = PackedVector3Array()
	velocities.resize(n)
	var masses: PackedFloat32Array = PackedFloat32Array()
	masses.resize(n)
	
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 556677
	
	for i in range(n):
		positions[i] = Vector3(
			rng.randf_range(-15.0, 15.0),
			rng.randf_range(-15.0, 15.0),
			rng.randf_range(-15.0, 15.0)
		)
		velocities[i] = Vector3(
			rng.randf_range(-1.0, 1.0),
			rng.randf_range(-1.0, 1.0),
			rng.randf_range(-1.0, 1.0)
		)
		masses[i] = 1.0
	
	var octree := BarnesHutOctree.new(0.5, 0.1, 1.0)
	var dt: float = 0.01
	
	var capacity_history: Array[int] = []
	var node_count_history: Array[int] = []
	
	# Run 50 consecutive frames simulating real-time game loop
	for frame in range(50):
		# Integrate positions linearly
		for i in range(n):
			positions[i] += velocities[i] * dt
		
		# Rebuild octree and compute accelerations
		octree.build(positions, masses)
		var _acc: PackedVector3Array = octree.compute_all_accelerations(positions, masses)
		
		var pool_cap: int = octree.get_pool_capacity()
		var node_cnt: int = octree.get_node_count()
		capacity_history.append(pool_cap)
		node_count_history.append(node_cnt)
	
	var initial_capacity: int = capacity_history[0]
	var frame10_capacity: int = capacity_history[9]
	var final_capacity: int = capacity_history[49]
	
	# Calculate whether capacity grew monotonically or stabilized
	var capacity_grew_after_frame_10: bool = false
	for f in range(10, 50):
		if capacity_history[f] > frame10_capacity * 1.2: # allow small headroom for spatial dispersion
			capacity_grew_after_frame_10 = true
			break
	
	print("  Frame 1 Pool Capacity: %d, Nodes used: %d" % [initial_capacity, node_count_history[0]])
	print("  Frame 10 Pool Capacity: %d, Nodes used: %d" % [frame10_capacity, node_count_history[9]])
	print("  Frame 50 Pool Capacity: %d, Nodes used: %d" % [final_capacity, node_count_history[49]])
	
	assert_check(initial_capacity > 0, "Node pool initialized and populated with reusable nodes")
	assert_check(final_capacity >= node_count_history[49], "Pool capacity satisfies maximum active tree requirement")
	assert_check(not capacity_grew_after_frame_10, "Node pool capacity stabilized without unbounded monotonic growth (zero leak)")

# ==============================================================================
# Suite 6: BarnesHutOctree Adversarial Edge Cases
# ==============================================================================
func _test_barnes_hut_adversarial_edge_cases() -> void:
	print("\n--- Suite 6: BarnesHutOctree Adversarial Edge Cases ---")
	
	# Edge Case 6.1: Empty tree
	var empty_tree := BarnesHutOctree.new()
	var empty_acc: Vector3 = empty_tree.compute_acceleration(0, Vector3.ZERO)
	assert_check(empty_acc == Vector3.ZERO, "Empty octree compute_acceleration returns Vector3.ZERO")
	assert_check(empty_tree.is_empty(), "Empty octree is_empty() returns true")
	
	# Edge Case 6.2: Single particle system
	var single_tree := BarnesHutOctree.new()
	var single_pos := PackedVector3Array([Vector3(5, 5, 5)])
	var single_mass := PackedFloat32Array([10.0])
	single_tree.build(single_pos, single_mass)
	assert_check(single_tree.get_particle_count() == 1, "Single particle tree builds successfully")
	var self_acc: Vector3 = single_tree.compute_acceleration(0, Vector3(5, 5, 5))
	assert_check(self_acc == Vector3.ZERO, "Self-acceleration of single particle is zero")
	var probe_acc: Vector3 = single_tree.compute_acceleration(-1, Vector3(5, 5, 7), 0.0, 0.0, 1.0)
	assert_check(probe_acc.is_equal_approx(Vector3(0, 0, -2.5)), "Probe acceleration from single particle is exact G*M/r^2")
	
	# Edge Case 6.3: Coincident particles stress test (10 particles at identical coordinate)
	var coinc_tree := BarnesHutOctree.new()
	var coinc_positions: PackedVector3Array = PackedVector3Array()
	var coinc_masses: PackedFloat32Array = PackedFloat32Array()
	var shared_pos := Vector3(12.34, -56.78, 90.12)
	for i in range(10):
		coinc_positions.append(shared_pos)
		coinc_masses.append(2.0)
	
	coinc_tree.build(coinc_positions, coinc_masses)
	assert_check(coinc_tree.get_particle_count() == 10, "Coincident particles tree builds without infinite recursion")
	assert_check(coinc_tree.get_max_depth() <= BarnesHutOctree.MAX_DEPTH, "Max tree depth respects MAX_DEPTH limit")
	assert_check(is_equal_approx(coinc_tree.get_total_mass(), 20.0), "Coincident particles combined total mass is accurate")
	
	# Edge Case 6.4: Zero mass particles
	var zero_mass_tree := BarnesHutOctree.new()
	var zm_pos: PackedVector3Array = PackedVector3Array([Vector3(0, 0, 0), Vector3(10, 0, 0)])
	var zm_mass: PackedFloat32Array = PackedFloat32Array([0.0, 0.0])
	zero_mass_tree.build(zm_pos, zm_mass)
	var zm_acc: Vector3 = zero_mass_tree.compute_acceleration(0, zm_pos[0])
	assert_check(zm_acc == Vector3.ZERO, "Zero mass particles produce zero gravitational acceleration")
	
	# Edge Case 6.5: Softening parameter singularity guard
	var soft_tree := BarnesHutOctree.new(0.0, 0.5, 1.0)
	var pair_pos: PackedVector3Array = PackedVector3Array([Vector3(0, 0, 0), Vector3(0, 0, 0)])
	var pair_mass: PackedFloat32Array = PackedFloat32Array([1.0, 1.0])
	soft_tree.build(pair_pos, pair_mass)
	var soft_acc: Vector3 = soft_tree.compute_acceleration(0, pair_pos[0], 0.0, 0.5, 1.0)
	assert_check(not is_nan(soft_acc.x) and not is_inf(soft_acc.x), "Softening prevents NaN/Inf singularity at zero distance")

# ==============================================================================
# Suite 7: ConservationSentry Noether Invariants & Trigger Verification
# ==============================================================================
func _test_conservation_sentry_noether_invariants_and_triggers() -> void:
	print("\n--- Suite 7: ConservationSentry Noether Invariants & Trigger Verification ---")
	
	var sentry := ConservationSentry.new()
	sentry.energy_tolerance = 0.005 # 0.5%
	sentry.momentum_tolerance = 0.01 # 1.0%
	sentry.angular_momentum_tolerance = 0.01 # 1.0%
	
	# 7.1 Virialized 2-body orbit initial condition
	var positions := PackedVector3Array([Vector3(-1.0, 0.0, 0.0), Vector3(1.0, 0.0, 0.0)])
	var velocities := PackedVector3Array([Vector3(0.0, -0.5, 0.0), Vector3(0.0, 0.5, 0.0)])
	var masses := PackedFloat32Array([1.0, 1.0])
	
	var dummy_potential := func(_pos: PackedVector3Array) -> float:
		return -1.0 # Constant gravitational potential
	
	var warnings_emitted: Array[String] = []
	sentry.conservation_warning.connect(func(type: String, _drift: float):
		warnings_emitted.append(type)
	)
	
	var snap1: Dictionary = sentry.audit(positions, velocities, masses, dummy_potential)
	
	# Verify physical calculations
	# E_k = 0.5 * 1.0 * (0.25) + 0.5 * 1.0 * (0.25) = 0.25
	# E_p = -1.0 => Total E = -0.75
	# P = (0, -0.5, 0) + (0, 0.5, 0) = Vector3.ZERO
	# L = (-1, 0, 0) x (0, -0.5, 0) + (1, 0, 0) x (0, 0.5, 0) = (0, 0, 0.5) + (0, 0, 0.5) = (0, 0, 1.0)
	assert_check(is_equal_approx(snap1.kinetic_energy, 0.25), "Sentry kinetic energy calculation is exact")
	assert_check(is_equal_approx(snap1.total_energy, -0.75), "Sentry total energy calculation is exact")
	assert_check(snap1.linear_momentum.is_equal_approx(Vector3.ZERO), "Sentry linear momentum is zero in center-of-mass frame")
	assert_check(snap1.angular_momentum.is_equal_approx(Vector3(0, 0, 1.0)), "Sentry angular momentum is exact (0, 0, 1)")
	assert_check(snap1.is_conserved == true, "Initial state audited as conserved")
	
	# 7.2 Inject 2% unphysical energy drift
	warnings_emitted.clear()
	var drifted_potential := func(_pos: PackedVector3Array) -> float:
		return -1.015 # shifts total energy from -0.75 to -0.765 (drift = 0.015 / 0.75 = 2.0% > 0.5%)
	
	var snap2: Dictionary = sentry.audit(positions, velocities, masses, drifted_potential)
	assert_check(snap2.is_conserved == false, "Sentry detects 2% energy drift violation")
	assert_check(warnings_emitted.has("energy"), "Sentry emitted conservation_warning for energy")
	
	# 7.3 Inject linear momentum violation
	warnings_emitted.clear()
	var kicked_velocities := PackedVector3Array([Vector3(0.0, -0.5, 0.0), Vector3(0.0, 0.55, 0.0)]) # net P = (0, 0.05, 0)
	var snap3: Dictionary = sentry.audit(positions, kicked_velocities, masses, dummy_potential)
	assert_check(warnings_emitted.has("linear_momentum"), "Sentry emitted conservation_warning for linear momentum drift")
	
	# 7.4 Edge Case: Mismatched array lengths handled gracefully
	var bad_velocities := PackedVector3Array([Vector3.ZERO]) # length 1 vs 2
	var snap_err: Dictionary = sentry.audit(positions, bad_velocities, masses, dummy_potential)
	assert_check(snap_err.is_empty(), "Mismatched array sizes return empty dictionary without crashing")
	
	sentry.free()
