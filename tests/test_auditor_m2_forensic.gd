extends SceneTree

const ConservationSentry = preload("res://core/physics/conservation_sentry.gd")
const SpatialHashGrid = preload("res://core/physics/spatial_hash_grid.gd")
const BarnesHutOctree = preload("res://core/physics/barnes_hut_octree.gd")

## Independent Forensic Integrity Audit Suite for Milestone 2
## Tests ConservationSentry, SpatialHashGrid, and BarnesHutOctree.
## Strictly follows Godot 4 headless rules: no built-in assert(), uses counters & quit(code).

var total_tests: int = 0
var passed_tests: int = 0
var failed_tests: int = 0

func _init() -> void:
	print("=================================================================")
	print("STARTING INDEPENDENT FORENSIC INTEGRITY AUDIT: MILESTONE 2")
	print("=================================================================")
	
	test_conservation_sentry_exact_math()
	test_conservation_sentry_warning_signals()
	test_conservation_sentry_temperature_equipartition()
	test_conservation_sentry_zero_baselines()
	
	test_spatial_hash_grid_prime_formula()
	test_spatial_hash_grid_negative_coords()
	test_spatial_hash_grid_vs_bruteforce_exactness()
	test_spatial_hash_grid_performance_5000()
	
	test_barnes_hut_octree_exact_mass_and_com()
	test_barnes_hut_octree_vs_direct_gravity()
	test_barnes_hut_octree_coincident_particles()
	test_barnes_hut_octree_node_pool_recycling()
	test_barnes_hut_octree_potential_energy_exactness()
	
	print("=================================================================")
	print("FORENSIC AUDIT SUMMARY: Total: %d, Passed: %d, Failed: %d" % [total_tests, passed_tests, failed_tests])
	print("=================================================================")
	
	if failed_tests > 0:
		print("AUDIT RESULT: INTEGRITY VIOLATION / FAILURES DETECTED")
		quit(1)
	else:
		print("AUDIT RESULT: CLEAN - ALL FORENSIC CHECKS PASSED")
		quit(0)

func check(condition: bool, test_name: String, details: String = "") -> void:
	total_tests += 1
	if condition:
		passed_tests += 1
		print("  [PASS] %s" % test_name)
	else:
		failed_tests += 1
		print("  [FAIL] %s - %s" % [test_name, details])

# ==============================================================================
# ConservationSentry Forensic Tests
# ==============================================================================

func test_conservation_sentry_exact_math() -> void:
	print("\n--- Testing ConservationSentry Exact Calculations ---")
	var sentry: ConservationSentry = ConservationSentry.new()
	
	var positions: PackedVector3Array = PackedVector3Array([
		Vector3(1.0, 0.0, 0.0),
		Vector3(-1.0, 0.0, 0.0)
	])
	var velocities: PackedVector3Array = PackedVector3Array([
		Vector3(0.0, 2.0, 0.0),
		Vector3(0.0, -2.0, 0.0)
	])
	var masses: PackedFloat32Array = PackedFloat32Array([2.0, 2.0])
	
	var pot_calc = func(pos: PackedVector3Array) -> float:
		return -5.0
	
	var snap: Dictionary = sentry.audit(positions, velocities, masses, pot_calc)
	
	# Hand calculations:
	# Ek = 0.5 * 2.0 * 4.0 + 0.5 * 2.0 * 4.0 = 4.0 + 4.0 = 8.0
	# Ep = -5.0
	# Total E = 3.0
	# P = (2.0 * (0,2,0)) + (2.0 * (0,-2,0)) = (0,0,0)
	# L1 = (1,0,0) x (0,4,0) = (0,0,4)
	# L2 = (-1,0,0) x (0,-4,0) = (0,0,4)
	# Total L = (0,0,8)
	
	check(is_equal_approx(snap["kinetic_energy"], 8.0), "Kinetic energy exact match", "Expected 8.0, got %f" % snap["kinetic_energy"])
	check(is_equal_approx(snap["potential_energy"], -5.0), "Potential energy exact match", "Expected -5.0, got %f" % snap["potential_energy"])
	check(is_equal_approx(snap["total_energy"], 3.0), "Total energy exact match", "Expected 3.0, got %f" % snap["total_energy"])
	check(snap["linear_momentum"].is_equal_approx(Vector3.ZERO), "Linear momentum exact zero", "Got %s" % str(snap["linear_momentum"]))
	check(snap["angular_momentum"].is_equal_approx(Vector3(0, 0, 8.0)), "Angular momentum exact match", "Expected (0,0,8), got %s" % str(snap["angular_momentum"]))
	check(snap["is_conserved"] == true, "System conserved on initial baseline", "Expected true")
	
	# Now simulate a perturbed state with 10% energy boost
	var velocities_boosted: PackedVector3Array = PackedVector3Array([
		Vector3(0.0, 2.2, 0.0),
		Vector3(0.0, -2.2, 0.0)
	])
	var snap2: Dictionary = sentry.audit(positions, velocities_boosted, masses, pot_calc)
	# New Ek = 2 * 0.5 * 2 * (2.2)^2 = 2 * 4.84 = 9.68. Ep = -5.0. E = 4.68.
	# Drift = |4.68 - 3.0| / 3.0 = 1.68 / 3.0 = 0.56 (56% drift)
	var expected_drift: float = absf(4.68 - 3.0) / 3.0
	check(absf(snap2["energy_drift_ratio"] - expected_drift) < 1e-4, "Drift ratio calculated authentically", "Expected %f, got %f" % [expected_drift, snap2["energy_drift_ratio"]])
	check(snap2["is_conserved"] == false, "System flagged as unconserved upon 56% drift", "Expected false")
	sentry.free()

func test_conservation_sentry_warning_signals() -> void:
	print("\n--- Testing ConservationSentry Warning Signals ---")
	var sentry: ConservationSentry = ConservationSentry.new()
	var warnings_received: Array = []
	
	sentry.conservation_warning.connect(func(type: String, drift: float):
		warnings_received.append({"type": type, "drift": drift})
	)
	
	var pos: PackedVector3Array = PackedVector3Array([Vector3(0, 0, 0)])
	var vel1: PackedVector3Array = PackedVector3Array([Vector3(1, 0, 0)])
	var mass: PackedFloat32Array = PackedFloat32Array([1.0])
	var dummy_pot = func(p): return 0.0
	
	# Initial audit
	sentry.audit(pos, vel1, mass, dummy_pot)
	check(warnings_received.size() == 0, "No warning on initial registration", "Got %d warnings" % warnings_received.size())
	
	# Violate momentum and energy
	var vel2: PackedVector3Array = PackedVector3Array([Vector3(5, 0, 0)])
	sentry.audit(pos, vel2, mass, dummy_pot)
	
	check(warnings_received.size() >= 1, "Conservation warnings triggered on violation", "Received %d warnings" % warnings_received.size())
	var has_energy_warning: bool = false
	var has_momentum_warning: bool = false
	for w in warnings_received:
		if w["type"] == "energy": has_energy_warning = true
		if w["type"] == "linear_momentum": has_momentum_warning = true
	check(has_energy_warning, "Energy warning signal received", "Missing energy warning")
	check(has_momentum_warning, "Momentum warning signal received", "Missing momentum warning")
	sentry.free()

func test_conservation_sentry_temperature_equipartition() -> void:
	print("\n--- Testing ConservationSentry Temperature Equipartition ---")
	var sentry: ConservationSentry = ConservationSentry.new()
	sentry.boltzmann_constant = 1.0
	
	# 3 particles, each with mass 1.0, velocity (1, 1, 1) -> v^2 = 3.0
	# Ek per particle = 0.5 * 1.0 * 3.0 = 1.5
	# Total Ek = 4.5
	# T = 2 * Ek / (3 * N * kB) = 2 * 4.5 / (3 * 3 * 1.0) = 9.0 / 9.0 = 1.0
	var pos: PackedVector3Array = PackedVector3Array([Vector3(0,0,0), Vector3(1,0,0), Vector3(0,1,0)])
	var vel: PackedVector3Array = PackedVector3Array([Vector3(1,1,1), Vector3(1,1,1), Vector3(1,1,1)])
	var masses: PackedFloat32Array = PackedFloat32Array([1.0, 1.0, 1.0])
	var pot = func(p): return 0.0
	
	var snap: Dictionary = sentry.audit(pos, vel, masses, pot)
	check(is_equal_approx(snap["temperature"], 1.0), "Kinetic temperature formula T = 2*Ek/(3*N*kB)", "Expected 1.0, got %f" % snap["temperature"])
	sentry.free()

func test_conservation_sentry_zero_baselines() -> void:
	print("\n--- Testing ConservationSentry Zero Baseline Safeguard ---")
	var sentry: ConservationSentry = ConservationSentry.new()
	
	# System starting at rest and zero potential
	var pos: PackedVector3Array = PackedVector3Array([Vector3(0,0,0)])
	var vel: PackedVector3Array = PackedVector3Array([Vector3(0,0,0)])
	var masses: PackedFloat32Array = PackedFloat32Array([1.0])
	var pot = func(p): return 0.0
	
	var snap: Dictionary = sentry.audit(pos, vel, masses, pot)
	check(is_equal_approx(snap["total_energy"], 0.0), "Zero energy handled without division by zero", "Got %f" % snap["total_energy"])
	check(snap["energy_drift_ratio"] == 0.0, "Drift ratio is 0 for zero initial energy", "Got %f" % snap["energy_drift_ratio"])
	sentry.free()

# ==============================================================================
# SpatialHashGrid Forensic Tests
# ==============================================================================

func test_spatial_hash_grid_prime_formula() -> void:
	print("\n--- Testing SpatialHashGrid Prime Hash Formula ---")
	var grid: SpatialHashGrid = SpatialHashGrid.new()
	grid.initialize(2.0)
	
	# Prime constants: 73856093, 19349663, 83492791
	var h: int = grid.hash_coords(2, 3, 4)
	var expected_h: int = (2 * 73856093) ^ (3 * 19349663) ^ (4 * 83492791)
	check(h == expected_h, "Prime hash function matches specification", "Expected %d, got %d" % [expected_h, h])

func test_spatial_hash_grid_negative_coords() -> void:
	print("\n--- Testing SpatialHashGrid Negative Coordinates Floor Mapping ---")
	var grid: SpatialHashGrid = SpatialHashGrid.new()
	grid.initialize(1.0)
	
	# In a 1.0 lattice:
	# -0.5 must map to lattice coordinate -1
	# 0.5 must map to lattice coordinate 0
	var c_neg: Vector3i = grid.get_cell_coords(Vector3(-0.5, -0.1, -1.9))
	check(c_neg.x == -1 and c_neg.y == -1 and c_neg.z == -2, "Floor mapping preserves negative lattice cubes", "Got %s" % str(c_neg))

func test_spatial_hash_grid_vs_bruteforce_exactness() -> void:
	print("\n--- Testing SpatialHashGrid vs Brute Force Exactness ---")
	var grid: SpatialHashGrid = SpatialHashGrid.new()
	grid.initialize(1.5)
	
	# Generate 200 random particles in range [-10, 10]^3
	var n: int = 200
	var positions: PackedVector3Array = PackedVector3Array()
	positions.resize(n)
	for i in range(n):
		positions[i] = Vector3(
			sin(float(i) * 1.37) * 8.0,
			cos(float(i) * 2.11) * 8.0,
			sin(float(i) * 3.49) * 8.0
		)
	
	grid.build_grid(positions)
	
	var search_radius: float = 2.5
	var r_sq: float = search_radius * search_radius
	
	var mismatch_count: int = 0
	# Test 20 query points
	for q in range(20):
		var query_pos: Vector3 = positions[q * 9]
		
		# Ground truth brute force O(N)
		var true_neighbors: Array[int] = []
		for i in range(n):
			if query_pos.distance_squared_to(positions[i]) <= r_sq:
				true_neighbors.append(i)
		true_neighbors.sort()
		
		# SpatialHashGrid query
		var grid_neighbors_packed: PackedInt32Array = grid.get_neighbors(query_pos, search_radius)
		var grid_neighbors: Array = Array(grid_neighbors_packed)
		grid_neighbors.sort()
		
		if true_neighbors.size() != grid_neighbors.size():
			mismatch_count += 1
		else:
			for k in range(true_neighbors.size()):
				if true_neighbors[k] != grid_neighbors[k]:
					mismatch_count += 1
					break
	
	check(mismatch_count == 0, "SpatialHashGrid matches 100% of brute-force neighbors", "Mismatches: %d / 20" % mismatch_count)

func test_spatial_hash_grid_performance_5000() -> void:
	print("\n--- Testing SpatialHashGrid Performance (5,000 Particles) ---")
	var grid: SpatialHashGrid = SpatialHashGrid.new()
	grid.initialize(2.0)
	
	var n: int = 5000
	var positions: PackedVector3Array = PackedVector3Array()
	positions.resize(n)
	for i in range(n):
		positions[i] = Vector3(
			sin(float(i) * 0.17) * 25.0,
			cos(float(i) * 0.23) * 25.0,
			sin(float(i) * 0.31) * 25.0
		)
	
	var t0: int = Time.get_ticks_usec()
	grid.build_grid(positions)
	var t_build_us: int = Time.get_ticks_usec() - t0
	
	var query_pos: Vector3 = positions[0]
	var t1: int = Time.get_ticks_usec()
	var neighbors: PackedInt32Array = grid.get_neighbors(query_pos, 3.0)
	var t_query_us: int = Time.get_ticks_usec() - t1
	
	print("    5000 particles build time: %d us (%.2f ms)" % [t_build_us, t_build_us / 1000.0])
	print("    Query time for radius 3.0: %d us (%.2f ms), found %d neighbors" % [t_query_us, t_query_us / 1000.0, neighbors.size()])
	
	check(t_query_us < 10000, "Query time well within 10 ms requirement", "Query took %d us" % t_query_us)
	check(neighbors.size() > 0, "Neighbor query returned non-empty valid set", "Found 0 neighbors")

# ==============================================================================
# BarnesHutOctree Forensic Tests
# ==============================================================================

func test_barnes_hut_octree_exact_mass_and_com() -> void:
	print("\n--- Testing BarnesHutOctree Exact Mass & Center of Mass ---")
	var octree: BarnesHutOctree = BarnesHutOctree.new(0.5, 0.05, 1.0)
	
	var pos: PackedVector3Array = PackedVector3Array([
		Vector3(10.0, 0.0, 0.0),
		Vector3(-10.0, 0.0, 0.0)
	])
	var masses: PackedFloat32Array = PackedFloat32Array([3.0, 1.0])
	
	octree.build(pos, masses)
	
	# Total mass: 4.0
	# CoM: (10*3 + (-10)*1) / 4 = (30 - 10) / 4 = 20 / 4 = 5.0 in x
	var tot_mass: float = octree.get_total_mass()
	var com: Vector3 = octree.get_center_of_mass()
	
	check(is_equal_approx(tot_mass, 4.0), "Total mass calculation exact", "Expected 4.0, got %f" % tot_mass)
	check(com.is_equal_approx(Vector3(5.0, 0.0, 0.0)), "Center of mass calculation exact", "Expected (5,0,0), got %s" % str(com))

func test_barnes_hut_octree_vs_direct_gravity() -> void:
	print("\n--- Testing BarnesHutOctree Accuracy vs Direct N-Body Gravity ---")
	# With theta = 0 (direct evaluation without multipole approximation), results should match exact Newtonian gravity
	var octree_direct: BarnesHutOctree = BarnesHutOctree.new(0.0, 0.0, 1.0)
	
	var pos: PackedVector3Array = PackedVector3Array([
		Vector3(0.0, 0.0, 0.0),
		Vector3(5.0, 0.0, 0.0),
		Vector3(0.0, 10.0, 0.0)
	])
	var masses: PackedFloat32Array = PackedFloat32Array([100.0, 10.0, 20.0])
	
	octree_direct.build(pos, masses)
	
	# Analytical acceleration on particle 1 (at x=5, y=0, z=0):
	# From particle 0 (at 0,0,0, mass 100):
	# dr = (0,0,0) - (5,0,0) = (-5, 0, 0). dist = 5.0.
	# a_01 = dr * G * m0 / dist^3 = (-5, 0, 0) * 100 / 125 = (-4.0, 0, 0)
	# From particle 2 (at 0,10,0, mass 20):
	# dr = (0,10,0) - (5,0,0) = (-5, 10, 0). dist^2 = 25 + 100 = 125. dist = sqrt(125) = 11.1803
	# dist^3 = 125 * sqrt(125) = 1397.542
	# a_21 = (-5, 10, 0) * 20 / 1397.542 = (-0.07155, 0.14311, 0)
	# Total analytical a1 = (-4.07155, 0.14311, 0)
	
	var a1: Vector3 = octree_direct.compute_acceleration(1, pos[1])
	var expected_a1: Vector3 = Vector3(-4.071554, 0.143108, 0.0)
	
	check(a1.is_equal_approx(expected_a1), "Theta=0 direct evaluation matches exact Newtonian gravity", "Expected %s, got %s" % [str(expected_a1), str(a1)])
	
	# Now test theta = 0.5 (Barnes-Hut approximation) on an 80-particle cluster
	var n: int = 80
	var cluster_pos: PackedVector3Array = PackedVector3Array()
	var cluster_mass: PackedFloat32Array = PackedFloat32Array()
	cluster_pos.resize(n)
	cluster_mass.resize(n)
	for i in range(n):
		cluster_pos[i] = Vector3(
			sin(float(i) * 0.43) * 15.0,
			cos(float(i) * 0.71) * 15.0,
			sin(float(i) * 1.13) * 15.0
		)
		cluster_mass[i] = 1.0 + float(i % 5)
	
	var octree_approx: BarnesHutOctree = BarnesHutOctree.new(0.5, 0.01, 1.0)
	octree_approx.build(cluster_pos, cluster_mass)
	
	var octree_exact: BarnesHutOctree = BarnesHutOctree.new(0.0, 0.01, 1.0)
	octree_exact.build(cluster_pos, cluster_mass)
	
	var max_rel_err: float = 0.0
	for i in range(10):
		var a_app: Vector3 = octree_approx.compute_acceleration(i, cluster_pos[i])
		var a_ex: Vector3 = octree_exact.compute_acceleration(i, cluster_pos[i])
		var err: float = (a_app - a_ex).length() / (a_ex.length() if a_ex.length() > 1e-6 else 1.0)
		if err > max_rel_err:
			max_rel_err = err
	
	print("    Max relative error of theta=0.5 Barnes-Hut vs exact: %.4f (%.2f%%)" % [max_rel_err, max_rel_err * 100.0])
	check(max_rel_err < 0.05, "Theta=0.5 relative error is strictly below 5%", "Max error was %.4f" % max_rel_err)

func test_barnes_hut_octree_coincident_particles() -> void:
	print("\n--- Testing BarnesHutOctree Coincident Particles Handling ---")
	var octree: BarnesHutOctree = BarnesHutOctree.new()
	
	# Two particles at EXACT same location
	var pos: PackedVector3Array = PackedVector3Array([
		Vector3(1.0, 2.0, 3.0),
		Vector3(1.0, 2.0, 3.0),
		Vector3(5.0, 5.0, 5.0)
	])
	var masses: PackedFloat32Array = PackedFloat32Array([2.0, 3.0, 1.0])
	
	octree.build(pos, masses)
	
	check(octree.get_particle_count() == 3, "All 3 particles accommodated including coincident ones", "Got %d" % octree.get_particle_count())
	check(is_equal_approx(octree.get_total_mass(), 6.0), "Total mass sums correctly for coincident particles", "Got %f" % octree.get_total_mass())
	
	# Acceleration at external point (0,0,0) from the coincident pair (mass 5 at 1,2,3):
	var a: Vector3 = octree.compute_acceleration(-1, Vector3.ZERO)
	check(a.length() > 0.0 and not a.is_zero_approx(), "Acceleration computed cleanly from coincident cluster", "Got %s" % str(a))

func test_barnes_hut_octree_node_pool_recycling() -> void:
	print("\n--- Testing BarnesHutOctree Node Pool Recycling ---")
	var octree: BarnesHutOctree = BarnesHutOctree.new()
	
	var pos: PackedVector3Array = PackedVector3Array()
	var masses: PackedFloat32Array = PackedFloat32Array()
	pos.resize(50)
	masses.resize(50)
	for i in range(50):
		pos[i] = Vector3(float(i), float(i * 2), float(i * 3))
		masses[i] = 1.0
	
	octree.build(pos, masses)
	var pool_size_1: int = octree.get_pool_capacity()
	check(pool_size_1 > 0, "Initial build populated node pool", "Pool size: %d" % pool_size_1)
	
	# Rebuild with new data
	octree.build(pos, masses)
	var pool_size_2: int = octree.get_pool_capacity()
	
	check(pool_size_2 == pool_size_1, "Subsequent build recycled nodes with zero net allocation", "Initial: %d, Second: %d" % [pool_size_1, pool_size_2])

func test_barnes_hut_octree_potential_energy_exactness() -> void:
	print("\n--- Testing BarnesHutOctree Gravitational Potential Energy ---")
	var octree: BarnesHutOctree = BarnesHutOctree.new(0.0, 0.0, 1.0) # theta=0, softening=0, G=1
	
	# Two bodies: m1=2 at (0,0,0), m2=3 at (4,0,0). Distance r = 4.
	# Direct gravitational potential energy: U = - G * m1 * m2 / r = - 1.0 * 2.0 * 3.0 / 4.0 = -1.5
	var pos: PackedVector3Array = PackedVector3Array([
		Vector3(0.0, 0.0, 0.0),
		Vector3(4.0, 0.0, 0.0)
	])
	var masses: PackedFloat32Array = PackedFloat32Array([2.0, 3.0])
	
	var u: float = octree.compute_total_potential_energy(pos, masses, 0.0, 0.0, 1.0)
	check(is_equal_approx(u, -1.5), "Total potential energy U = 0.5 * sum(m_i * Phi_i) exact match", "Expected -1.5, got %f" % u)
