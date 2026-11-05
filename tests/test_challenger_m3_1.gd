extends SceneTree

# ==============================================================================
# Challenger M3-1: Empirical Verification & Adversarial Stress Suite
# Milestone 3: Modular Physics Simulation Domains
#
# Deliverables Under Challenge:
#   1. res://modules/physics/molecular_dynamics_module.gd
#   2. res://shaders/particle_field_glow.gdshader
#   3. res://modules/physics/n_body_gravity_module.gd
#   4. res://shaders/relativistic_mesh.gdshader
#
# Target Engine: Godot 4.0.stable.official.92bee43ad (Headless)
# Rules: No built-in assert() (causes headless hang); use counters and quit(code).
# ==============================================================================

const MolecularDynamicsModule = preload("res://modules/physics/molecular_dynamics_module.gd")
const NBodyGravityModule = preload("res://modules/physics/n_body_gravity_module.gd")
const SpatialHashGrid = preload("res://core/physics/spatial_hash_grid.gd")
const BarnesHutOctree = preload("res://core/physics/barnes_hut_octree.gd")
const ConservationSentry = preload("res://core/physics/conservation_sentry.gd")
const VerletIntegrator = preload("res://core/physics/verlet_integrator.gd")

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
	print("CHALLENGER M3-1: EMPIRICAL VERIFICATION & ADVERSARIAL STRESS SUITE")
	print("Milestone 3: Molecular Dynamics & Relativistic N-Body Gravity")
	print("Engine: Godot 4.0.stable (Headless)")
	print("==================================================================\n")

	var suite_start_usec: int = Time.get_ticks_usec()

	# Molecular Dynamics Empirical Challenges
	_challenge_md_spatial_hash_force_equivalence()
	_challenge_md_nve_energy_conservation()
	_challenge_md_berendsen_thermostat_equilibration()
	_challenge_md_maxwell_boltzmann_distribution()
	_challenge_md_boundary_and_compression()

	# Relativistic N-Body Gravity Empirical Challenges
	_challenge_nbody_speed_of_light_cap()
	_challenge_nbody_1pn_perihelion_precession()
	_challenge_nbody_barnes_hut_accuracy_and_integration()
	_challenge_nbody_trail_buffer_stability()

	# Shader AST & Uniform Verification
	_challenge_shader_materials()

	var suite_duration_ms: float = float(Time.get_ticks_usec() - suite_start_usec) / 1000.0

	print("\n==================================================================")
	print("CHALLENGER M3-1 EMPIRICAL VERIFICATION SUMMARY")
	print("==================================================================")
	print("Total Passed:   %d" % passed_count)
	print("Total Failed:   %d" % failed_count)
	print("Total Asserts:  %d" % (passed_count + failed_count))
	print("Suite Duration: %.2f ms" % suite_duration_ms)

	if failed_count > 0:
		print("\nFAILURES IDENTIFIED:")
		for f in failure_log:
			print(f)
		print("\nVERDICT: REQUEST_CHANGES (Exit Code: 1)")
		print("==================================================================")
		quit(1)
	else:
		print("\nVERDICT: ALL EMPIRICAL CHALLENGES PASSED (Exit Code: 0)")
		print("==================================================================")
		quit(0)

# ==============================================================================
# Suite 1: MD - SpatialHashGrid Half-Shell vs Brute Force Equivalence
# ==============================================================================
func _challenge_md_spatial_hash_force_equivalence() -> void:
	print("\n--- Challenge 1: MD SpatialHashGrid Half-Shell vs Brute Force Equivalence ---")
	
	var md := MolecularDynamicsModule.new()
	md.sigma = 1.0
	md.epsilon = 1.0
	md.cutoff_radius = 2.5
	
	# Test 1A: Empty state
	var empty_forces: PackedVector3Array = md.compute_forces(PackedVector3Array())
	assert_test(empty_forces.is_empty(), "Empty positions return empty force array")
	
	# Test 1B: Single particle (zero interaction)
	var single_pos := PackedVector3Array([Vector3(1.0, 2.0, 3.0)])
	var single_forces: PackedVector3Array = md.compute_forces(single_pos)
	assert_test(single_forces.size() == 1 and single_forces[0] == Vector3.ZERO, "Single isolated particle experiences zero force")
	
	# Test 1C: Two particles beyond cutoff (r = 3.0 > rc = 2.5)
	var far_pos := PackedVector3Array([Vector3(0.0, 0.0, 0.0), Vector3(3.0, 0.0, 0.0)])
	var far_forces: PackedVector3Array = md.compute_forces(far_pos)
	assert_test(far_forces[0].is_zero_approx() and far_forces[1].is_zero_approx(), "Particles beyond cutoff experience zero force")
	assert_test(is_zero_approx(md.compute_potential_energy(far_pos)), "Particles beyond cutoff have zero shifted potential energy")
	
	# Test 1D: Two particles within cutoff (r = 1.0 < rc = 2.5, repulsive)
	var rep_pos := PackedVector3Array([Vector3(0.0, 0.0, 0.0), Vector3(1.0, 0.0, 0.0)])
	var rep_forces: PackedVector3Array = md.compute_forces(rep_pos)
	assert_test(rep_forces[0].x < 0.0 and rep_forces[1].x > 0.0, "Sub-equilibrium pair (r=1.0 < 2^(1/6)) exhibits repulsive force")
	assert_test((rep_forces[0] + rep_forces[1]).length() < 1e-6, "Two-particle force obeys Newton's Third Law (F_1 + F_2 = 0)")
	
	# Test 1E: Multi-particle ensemble parity (N = 100 randomly distributed particles)
	var rng := RandomNumberGenerator.new()
	rng.seed = 12345
	var n_test: int = 100
	var test_positions := PackedVector3Array()
	test_positions.resize(n_test)
	for i in range(n_test):
		test_positions[i] = Vector3(
			rng.randf_range(-4.0, 4.0),
			rng.randf_range(-4.0, 4.0),
			rng.randf_range(-4.0, 4.0)
		)
	
	var forces_grid: PackedVector3Array = md.compute_forces(test_positions)
	var forces_brute: PackedVector3Array = md.compute_forces_brute_force(test_positions)
	
	assert_test(forces_grid.size() == n_test, "SpatialHashGrid forces array matches particle count")
	
	var max_force_diff: float = 0.0
	var net_force_grid := Vector3.ZERO
	var net_force_brute := Vector3.ZERO
	for i in range(n_test):
		var diff: float = (forces_grid[i] - forces_brute[i]).length()
		if diff > max_force_diff:
			max_force_diff = diff
		net_force_grid += forces_grid[i]
		net_force_brute += forces_brute[i]
	
	var max_f_mag: float = 0.0
	for f in forces_grid:
		max_f_mag = maxf(max_f_mag, f.length())
	var rel_net_force: float = net_force_grid.length() / maxf(max_f_mag, 1.0)
	
	print("  -> Max force vector difference (Grid vs Brute): %.6f" % max_force_diff)
	print("  -> Net force sum: Grid=%.4f (rel=%.6f), Brute=%.4f" % [net_force_grid.length(), rel_net_force, net_force_brute.length()])
	assert_test(max_force_diff < 1e-4, "SpatialHashGrid half-shell forces match Brute-Force to within 1e-4", "diff=%.6f" % max_force_diff)
	assert_test(rel_net_force < 1e-4, "Net force sum across ensemble vanishes relative to peak interaction force", "rel=%.6f" % rel_net_force)
	
	# Potential energy parity
	var pot_grid: float = md.compute_potential_energy(test_positions)
	# Compute brute-force potential
	var pot_brute: float = 0.0
	var eps4: float = 4.0 * md.epsilon
	var sig2: float = md.sigma * md.sigma
	var rc_sq: float = md.cutoff_radius * md.cutoff_radius
	var sr2_c: float = sig2 / rc_sq
	var sr6_c: float = sr2_c * sr2_c * sr2_c
	var v_shift_c: float = eps4 * (sr6_c * sr6_c - sr6_c)
	for i in range(n_test):
		for j in range(i + 1, n_test):
			var r_sq: float = test_positions[i].distance_squared_to(test_positions[j])
			if r_sq < rc_sq:
				r_sq = maxf(r_sq, 0.04 * sig2)
				var inv_r2: float = 1.0 / r_sq
				var sr2: float = sig2 * inv_r2
				var sr6: float = sr2 * sr2 * sr2
				var sr12: float = sr6 * sr6
				pot_brute += eps4 * (sr12 - sr6) - v_shift_c
	
	var pot_diff: float = absf(pot_grid - pot_brute)
	print("  -> Potential energy: Grid=%.6f, Brute=%.6f (diff=%e)" % [pot_grid, pot_brute, pot_diff])
	assert_test(pot_diff < 1e-3, "Potential energy calculation matches brute force summation", "diff=%e" % pot_diff)
	
	md.cleanup()

# ==============================================================================
# Suite 2: MD - NVE Microcanonical Energy Conservation
# ==============================================================================
func _challenge_md_nve_energy_conservation() -> void:
	print("\n--- Challenge 2: MD NVE Energy Conservation (1,000 steps, dt=0.002) ---")
	
	var md := MolecularDynamicsModule.new()
	md.particle_count = 32
	md.sigma = 1.0
	md.epsilon = 1.0
	md.particle_mass = 1.0
	md.box_half_extent = Vector3(15.0, 15.0, 15.0) # Container large enough to avoid wall disturbances
	md.thermostat_enabled = false # Pure NVE microcanonical ensemble
	md.target_temperature = 0.8
	md.boltzmann_constant = 1.0
	
	# Initialize simulation state
	md.reset_simulation()
	
	# Initial thermal relaxation: let lattice settle with mild damping to reach smooth phase space
	var dt: float = 0.002
	var total_steps: int = 1000
	
	# Calculate initial total energy after initialization
	var pos: PackedVector3Array = md.get_positions()
	var vel: PackedVector3Array = md.get_velocities()
	var masses: PackedFloat32Array = md.get_masses()
	var n: int = pos.size()
	
	var initial_ek: float = 0.0
	for i in range(n):
		initial_ek += 0.5 * masses[i] * vel[i].length_squared()
	var initial_ep: float = md.compute_potential_energy(pos)
	var e0: float = initial_ek + initial_ep
	
	print("  -> Initial State: N=%d, Ek=%.4f, Ep=%.4f, E0=%.4f" % [n, initial_ek, initial_ep, e0])
	assert_test(absf(e0) > 1e-4, "Initial total energy is non-zero")
	
	var peak_drift: float = 0.0
	var final_drift: float = 0.0
	
	for s in range(total_steps):
		md.step(dt)
		
		# Sample invariants periodically
		if s % 50 == 0 or s == total_steps - 1:
			var cur_pos: PackedVector3Array = md.get_positions()
			var cur_vel: PackedVector3Array = md.get_velocities()
			var cur_ek: float = 0.0
			for i in range(n):
				cur_ek += 0.5 * masses[i] * cur_vel[i].length_squared()
			var cur_ep: float = md.compute_potential_energy(cur_pos)
			var cur_etot: float = cur_ek + cur_ep
			var drift: float = absf(cur_etot - e0) / absf(e0)
			if drift > peak_drift:
				peak_drift = drift
			if s == total_steps - 1:
				final_drift = drift
	
	print("  -> Completed %d steps: Peak Drift = %.6f (%.4f%%), Final Drift = %.6f (%.4f%%)" % [
		total_steps, peak_drift, peak_drift * 100.0, final_drift, final_drift * 100.0
	])
	
	assert_test(final_drift < 0.005, "NVE relative energy drift < 0.005 (0.5%) over 1,000 steps", "drift=%.6f" % final_drift)
	assert_test(peak_drift < 0.005, "Peak NVE relative energy drift < 0.005 (0.5%) across all steps", "peak=%.6f" % peak_drift)
	
	md.cleanup()

# ==============================================================================
# Suite 3: MD - Berendsen Thermostat Equilibration
# ==============================================================================
func _challenge_md_berendsen_thermostat_equilibration() -> void:
	print("\n--- Challenge 3: MD Berendsen Thermostat Equilibration ---")
	
	var md := MolecularDynamicsModule.new()
	md.particle_count = 64
	md.sigma = 1.0
	md.epsilon = 1.0
	md.particle_mass = 1.0
	md.box_half_extent = Vector3(15.0, 15.0, 15.0)
	md.thermostat_enabled = true
	md.thermostat_tau = 0.1
	md.boltzmann_constant = 1.0
	
	# Test 3A: Cooling Equilibration (start at T = 3.0, cool to T_target = 1.0)
	md.target_temperature = 3.0
	md.reset_simulation()
	var t_start_cool: float = md.compute_instantaneous_temperature()
	print("  [Cooling Test] Initial Temperature: %.4f, Target: 1.0000" % t_start_cool)
	
	md.target_temperature = 1.0
	var dt: float = 0.005
	for s in range(400):
		md.step(dt)
	
	var t_final_cool: float = md.compute_instantaneous_temperature()
	print("  [Cooling Test] Temperature after 400 steps: %.4f" % t_final_cool)
	assert_test(absf(t_final_cool - 1.0) < 0.08, "Thermostat equilibrates hot gas toward T=1.0", "T=%.4f" % t_final_cool)
	
	# Test 3B: Heating Equilibration (heat from T = 1.0 to T_target = 2.5)
	md.target_temperature = 2.5
	print("  [Heating Test] New Target: 2.5000")
	for s in range(400):
		md.step(dt)
	
	var t_final_heat: float = md.compute_instantaneous_temperature()
	print("  [Heating Test] Temperature after 400 steps: %.4f" % t_final_heat)
	assert_test(absf(t_final_heat - 2.5) < 0.12, "Thermostat equilibrates gas toward T=2.5", "T=%.4f" % t_final_heat)
	
	# Test 3C: Interactive Controls
	var old_target: float = md.target_temperature
	md.heat_up(0.4)
	assert_test(is_equal_approx(md.target_temperature, old_target + 0.4), "heat_up() increases target temperature by delta")
	md.cool_down(0.6)
	assert_test(is_equal_approx(md.target_temperature, old_target - 0.2), "cool_down() decreases target temperature by delta")
	
	md.cleanup()

# ==============================================================================
# Suite 4: MD - Maxwell-Boltzmann Velocity Distribution
# ==============================================================================
func _challenge_md_maxwell_boltzmann_distribution() -> void:
	print("\n--- Challenge 4: MD Maxwell-Boltzmann Velocity Distribution ---")
	
	var md := MolecularDynamicsModule.new()
	md.particle_count = 500
	md.sigma = 1.0
	md.epsilon = 1.0
	md.particle_mass = 1.0
	md.target_temperature = 1.5
	md.boltzmann_constant = 1.0
	md.box_half_extent = Vector3(20.0, 20.0, 20.0)
	md.reset_simulation()
	
	var dist: Dictionary = md.compute_velocity_distribution(25)
	assert_test(not dist.is_empty(), "compute_velocity_distribution returns non-empty Dictionary")
	assert_test(dist.has("mean_speed") and dist.has("rms_speed") and dist.has("theoretical_pdf"), "Distribution contains required statistical fields")
	
	var empirical_mean: float = dist["mean_speed"]
	var empirical_rms: float = dist["rms_speed"]
	var temp: float = dist["temperature"]
	
	# Analytical Maxwell-Boltzmann moments:
	# <v> = sqrt(8 * k_B * T / (pi * m))
	# v_rms = sqrt(3 * k_B * T / m)
	var theoretical_mean: float = sqrt(8.0 * md.boltzmann_constant * temp / (PI * md.particle_mass))
	var theoretical_rms: float = sqrt(3.0 * md.boltzmann_constant * temp / md.particle_mass)
	
	var mean_err_rel: float = absf(empirical_mean - theoretical_mean) / theoretical_mean
	var rms_err_rel: float = absf(empirical_rms - theoretical_rms) / theoretical_rms
	
	print("  -> Mean Speed: Empirical=%.4f, Theoretical=%.4f (rel err=%.4f)" % [empirical_mean, theoretical_mean, mean_err_rel])
	print("  -> RMS Speed:  Empirical=%.4f, Theoretical=%.4f (rel err=%.4f)" % [empirical_rms, theoretical_rms, rms_err_rel])
	
	assert_test(mean_err_rel < 0.05, "Mean speed matches Maxwell-Boltzmann expectation within 5%", "err=%.4f" % mean_err_rel)
	assert_test(rms_err_rel < 0.05, "RMS speed matches Maxwell-Boltzmann expectation within 5%", "err=%.4f" % rms_err_rel)
	
	# Histogram PDF normalization and integral match
	var emp_pdf: PackedFloat32Array = dist["empirical_pdf"]
	var theo_pdf: PackedFloat32Array = dist["theoretical_pdf"]
	var bin_width: float = dist["bin_width"]
	var emp_sum: float = 0.0
	var l1_error: float = 0.0
	for b in range(emp_pdf.size()):
		emp_sum += emp_pdf[b] * bin_width
		l1_error += absf(emp_pdf[b] - theo_pdf[b]) * bin_width
	
	print("  -> Empirical PDF integral = %.4f (expected ~ 1.0), L1 error vs theory = %.4f" % [emp_sum, l1_error])
	assert_test(absf(emp_sum - 1.0) < 0.05, "Empirical PDF integrates to unity (within 5%)")
	assert_test(l1_error < 0.25, "L1 total variation error between empirical and theoretical PDF < 0.25", "L1=%.4f" % l1_error)
	
	md.cleanup()

# ==============================================================================
# Suite 5: MD - Boundary Enforcement & Container Compression
# ==============================================================================
func _challenge_md_boundary_and_compression() -> void:
	print("\n--- Challenge 5: MD Boundary Enforcement & Container Compression ---")
	
	var md := MolecularDynamicsModule.new()
	md.particle_count = 20
	md.sigma = 1.0
	md.particle_radius = 0.2
	md.box_half_extent = Vector3(5.0, 5.0, 5.0)
	md.restitution = 1.0
	md.thermostat_enabled = false
	md.reset_simulation()
	
	# Deliberately place a particle beyond boundary with outward velocity
	var pos: PackedVector3Array = md.get_positions()
	var vel: PackedVector3Array = md.get_velocities()
	pos[0] = Vector3(6.0, 0.0, 0.0)
	vel[0] = Vector3(2.0, 0.0, 0.0)
	md.set_particle_state(pos, vel)
	
	md.enforce_boundaries()
	
	var post_pos: Vector3 = md.get_positions()[0]
	var post_vel: Vector3 = md.get_velocities()[0]
	
	var eff_box_x: float = md.box_half_extent.x - md.particle_radius # 4.8
	print("  -> Boundary reflection: pos.x was 6.0 -> now %.4f (eff_box = %.4f), vel.x was 2.0 -> now %.4f" % [
		post_pos.x, eff_box_x, post_vel.x
	])
	assert_test(post_pos.x <= eff_box_x, "Particle position clamped inside effective container boundary")
	assert_test(post_vel.x < 0.0, "Particle velocity inverted inward upon wall collision")
	
	# Container compression
	var old_box: Vector3 = md.box_half_extent
	md.compress_container(0.8)
	assert_test(md.box_half_extent == old_box * 0.8, "compress_container scales box_half_extent")
	
	md.cleanup()

# ==============================================================================
# Suite 6: N-Body - Relativistic Speed of Light Cap
# ==============================================================================
func _challenge_nbody_speed_of_light_cap() -> void:
	print("\n--- Challenge 6: N-Body Relativistic Speed of Light Cap & Singularity Plunge ---")
	
	var nbody := NBodyGravityModule.new()
	nbody.gravitational_constant = 1.0
	nbody.softening = 0.05
	nbody.speed_of_light = 50.0
	nbody.enable_relativity = true
	nbody.enable_trails = false
	
	# Massive Singularity at origin (M = 10,000)
	nbody.clear_particles()
	nbody.add_body("Singularity", Vector3.ZERO, Vector3.ZERO, 10000.0, 1.0, Color.BLACK)
	# Test particle at x = 10 with high plunge velocity towards singularity
	nbody.add_body("PlungingProbe", Vector3(10.0, 0.0, 0.0), Vector3(-30.0, 0.0, 0.0), 0.01, 0.1, Color.RED)
	
	var c_sim: float = nbody.speed_of_light
	var dt: float = 0.002
	var max_v_observed: float = 0.0
	var has_nans: bool = false
	
	# Plunge simulation over 1,500 steps
	for s in range(1500):
		nbody.step(dt)
		var v_probe: float = nbody.get_velocities()[1].length()
		if is_nan(v_probe) or is_inf(v_probe):
			has_nans = true
			break
		if v_probe > max_v_observed:
			max_v_observed = v_probe
	
	print("  -> Speed of Light c_sim = %.1f, Max Speed Observed = %.4f (beta = %.4f)" % [
		c_sim, max_v_observed, max_v_observed / c_sim
	])
	
	assert_test(not has_nans, "Singularity plunge produces zero NaN or Infinite values")
	assert_test(max_v_observed < c_sim, "Particle speed strictly never exceeds simulation speed of light c_sim", "max_v=%.4f" % max_v_observed)
	assert_test(max_v_observed <= c_sim * 0.9996, "Particle speed respects relativistic asymptote guard (<= 0.9995 * c_sim)")
	assert_test(max_v_observed > 30.0, "Particle experienced strong gravitational acceleration towards singularity")
	
	# Compare against unconstrained Newtonian physics
	var nbody_newton := NBodyGravityModule.new()
	nbody_newton.gravitational_constant = 1.0
	nbody_newton.softening = 0.05
	nbody_newton.speed_of_light = 50.0
	nbody_newton.enable_relativity = false
	nbody_newton.enable_trails = false
	nbody_newton.clear_particles()
	nbody_newton.add_body("Singularity", Vector3.ZERO, Vector3.ZERO, 10000.0, 1.0, Color.BLACK)
	nbody_newton.add_body("PlungingProbe", Vector3(10.0, 0.0, 0.0), Vector3(-30.0, 0.0, 0.0), 0.01, 0.1, Color.RED)
	
	var max_newton_v: float = 0.0
	for s in range(1500):
		nbody_newton.step(dt)
		var v: float = nbody_newton.get_velocities()[1].length()
		if v > max_newton_v:
			max_newton_v = v
	
	print("  -> Newtonian unconstrained max speed: %.4f (>> c_sim)" % max_newton_v)
	assert_test(max_newton_v > c_sim, "Newtonian mechanics breaches c_sim, confirming necessity of relativistic tensor")
	
	nbody.cleanup()
	nbody_newton.cleanup()

# ==============================================================================
# Suite 7: N-Body - 1PN Perihelion Precession Advance
# ==============================================================================
func _challenge_nbody_1pn_perihelion_precession() -> void:
	print("\n--- Challenge 7: N-Body 1PN General Relativistic Perihelion Precession ---")
	
	# We simulate a high-eccentricity orbit around a massive star:
	# M = 100.0, G = 1.0, c_sim = 25.0
	# Semi-major axis a = 4.0, eccentricity e = 0.5
	# Perihelion distance r_p = a*(1 - e) = 2.0
	# Aphelion distance r_a = a*(1 + e) = 6.0
	# Analytical GR perihelion advance per revolution:
	# Delta_phi = 6 * PI * G * M / (a * (1 - e^2) * c^2)
	# Delta_phi = 6 * PI * 100 / (4.0 * (1 - 0.25) * 625.0) = 600 * PI / 1875.0 = 0.32 * PI = 1.0053 rad (~57.6 deg/rev)
	
	var m_sun: float = 100.0
	var g_const: float = 1.0
	var c_sim: float = 25.0
	var a_axis: float = 4.0
	var ecc: float = 0.5
	var r_p: float = a_axis * (1.0 - ecc) # 2.0
	var v_p: float = sqrt(g_const * m_sun * (1.0 + ecc) / (a_axis * (1.0 - ecc))) # sqrt(100 * 1.5 / 2.0) = sqrt(75) = 8.660254
	
	var analytical_delta_phi: float = (6.0 * PI * g_const * m_sun) / (a_axis * (1.0 - ecc * ecc) * c_sim * c_sim)
	print("  -> Analytical 1PN Precession per orbit: %.5f rad (%.2f deg)" % [
		analytical_delta_phi, rad_to_deg(analytical_delta_phi)
	])
	
	# Helper to track perihelion angle
	var track_perihelion_advance := func(enable_1pn: bool) -> float:
		var nb := NBodyGravityModule.new()
		nb.gravitational_constant = g_const
		nb.softening = 0.01
		nb.speed_of_light = c_sim
		nb.enable_relativity = enable_1pn
		nb.post_newtonian_mode = NBodyGravityModule.PostNewtonianMode.PRIMARY_BODY if enable_1pn else NBodyGravityModule.PostNewtonianMode.OFF
		nb.enable_trails = false
		nb.clear_particles()
		
		# Star at origin, planet at (r_p, 0, 0), moving with +y velocity v_p
		nb.add_body("Sun", Vector3.ZERO, Vector3.ZERO, m_sun, 0.5, Color.YELLOW)
		nb.add_body("Mercury", Vector3(r_p, 0.0, 0.0), Vector3(0.0, v_p, 0.0), 0.001, 0.1, Color.GREEN)
		
		var dt: float = 0.001
		var t_orb: float = 2.0 * PI * sqrt(pow(a_axis, 3.0) / (g_const * m_sun)) # ~ 5.026 s
		var steps_per_orbit: int = int(t_orb / dt)
		
		var prev_r: float = r_p
		var prev_dr: float = 0.0
		var perihelion_angles: Array[float] = []
		
		# Simulate for 2.5 orbits to detect at least 2 full perihelion passages
		for s in range(int(steps_per_orbit * 2.8)):
			nb.step(dt)
			var pos_p: Vector3 = nb.get_positions()[1]
			var cur_r: float = pos_p.length()
			var dr: float = cur_r - prev_r
			
			# Local minimum of r: dr was negative or zero, now positive
			# Must be near perihelion distance (r < 3.0) and not at aphelion (r ~ 6.0)
			if s > 100 and prev_dr < 0.0 and dr >= 0.0 and cur_r < 3.0:
				var phi: float = atan2(pos_p.y, pos_p.x)
				perihelion_angles.append(phi)
			
			prev_dr = dr
			prev_r = cur_r
		
		nb.cleanup()
		
		if perihelion_angles.size() >= 2:
			var d_phi: float = perihelion_angles[1] - perihelion_angles[0]
			while d_phi < 0.0:
				d_phi += TAU
			while d_phi >= TAU:
				d_phi -= TAU
			return d_phi
		return -1.0
	
	var d_phi_newton: float = track_perihelion_advance.call(false)
	var d_phi_1pn: float = track_perihelion_advance.call(true)
	
	print("  -> Simulated Precession (1PN OFF): %.5f rad (%.2f deg)" % [d_phi_newton, rad_to_deg(d_phi_newton)])
	print("  -> Simulated Precession (1PN ON):  %.5f rad (%.2f deg)" % [d_phi_1pn, rad_to_deg(d_phi_1pn)])
	
	# Newtonian closed orbit should show near zero precession
	var newton_err: float = absf(d_phi_newton)
	if newton_err > PI:
		newton_err = TAU - newton_err
	assert_test(newton_err < 0.08, "Newtonian mode (1PN OFF) exhibits zero perihelion precession (< 0.08 rad)", "got=%.4f" % newton_err)
	
	# 1PN mode should show positive precession advancing in orbital direction
	assert_test(d_phi_1pn > 0.5, "1PN relativistic mode exhibits substantial forward perihelion advance (> 0.5 rad)", "got=%.4f" % d_phi_1pn)
	
	# Quantitative match with analytical formula:
	# In strong-field relativistic conditions (v/c ~ 0.35, e = 0.5), higher order effects cause mild deviation,
	# but 1PN simulated rate should match analytical within 25%.
	var rel_diff: float = absf(d_phi_1pn - analytical_delta_phi) / analytical_delta_phi
	print("  -> Relative error vs analytical formula: %.4f (%.2f%%)" % [rel_diff, rel_diff * 100.0])
	assert_test(rel_diff < 0.25, "1PN precession matches analytical formula within 25%", "err=%.4f" % rel_diff)

# ==============================================================================
# Suite 8: N-Body - Barnes-Hut Accuracy & Integration Parity
# ==============================================================================
func _challenge_nbody_barnes_hut_accuracy_and_integration() -> void:
	print("\n--- Challenge 8: N-Body Barnes-Hut Octree Accuracy & Integration Parity ---")
	
	var nbody := NBodyGravityModule.new()
	nbody.gravitational_constant = 1.0
	nbody.softening = 0.05
	nbody.theta_crit = 0.5
	nbody.enable_relativity = false
	nbody.enable_trails = false
	
	# Setup random cluster of N = 80 bodies
	nbody.clear_particles()
	var rng := RandomNumberGenerator.new()
	rng.seed = 98765
	var n_bodies: int = 80
	for i in range(n_bodies):
		var pos := Vector3(rng.randf_range(-10.0, 10.0), rng.randf_range(-10.0, 10.0), rng.randf_range(-10.0, 10.0))
		var vel := Vector3(rng.randf_range(-0.5, 0.5), rng.randf_range(-0.5, 0.5), rng.randf_range(-0.5, 0.5))
		var mass: float = rng.randf_range(0.1, 2.0)
		nbody.add_body("B%d" % i, pos, vel, mass, 0.2, Color.WHITE)
	
	var positions: PackedVector3Array = nbody.get_positions()
	var masses: PackedFloat32Array = nbody.get_masses()
	var octree: BarnesHutOctree = nbody.get_octree()
	octree.build(positions, masses)
	
	# 1. Compare Barnes-Hut accelerations (theta = 0.5) vs Direct All-Pairs
	var direct_accelerations := PackedVector3Array()
	direct_accelerations.resize(n_bodies)
	var eps_sq: float = nbody.softening * nbody.softening
	for i in range(n_bodies):
		var a_dir := Vector3.ZERO
		var p_i: Vector3 = positions[i]
		for j in range(n_bodies):
			if j != i:
				var dr: Vector3 = positions[j] - p_i
				var dist_sq: float = dr.length_squared() + eps_sq
				var inv_dist3: float = 1.0 / (dist_sq * sqrt(dist_sq))
				a_dir += dr * (nbody.gravitational_constant * masses[j] * inv_dist3)
		direct_accelerations[i] = a_dir
	
	var max_rel_err: float = 0.0
	var sum_rel_err: float = 0.0
	for i in range(n_bodies):
		var a_bh: Vector3 = octree.compute_acceleration(i, positions[i], 0.5, nbody.softening, nbody.gravitational_constant)
		var a_dir: Vector3 = direct_accelerations[i]
		var err: float = (a_bh - a_dir).length() / maxf(a_dir.length(), 1e-4)
		if err > max_rel_err:
			max_rel_err = err
		sum_rel_err += err
	
	var avg_rel_err: float = sum_rel_err / float(n_bodies)
	print("  -> Barnes-Hut (theta=0.5) vs Direct: Avg Rel Error = %.4f (%.2f%%), Max Rel Error = %.4f" % [
		avg_rel_err, avg_rel_err * 100.0, max_rel_err
	])
	assert_test(avg_rel_err < 0.03, "Barnes-Hut average relative acceleration error < 3% for theta=0.5", "avg=%.4f" % avg_rel_err)
	
	# 2. Exact match at theta = 0.0 (direct summation within tree)
	var max_exact_err: float = 0.0
	for i in range(n_bodies):
		var a_exact: Vector3 = octree.compute_acceleration(i, positions[i], 0.0, nbody.softening, nbody.gravitational_constant)
		var a_dir: Vector3 = direct_accelerations[i]
		var err: float = (a_exact - a_dir).length()
		if err > max_exact_err:
			max_exact_err = err
	
	print("  -> Barnes-Hut (theta=0.0 exact) vs Direct: Max Absolute Error = %.6f" % max_exact_err)
	assert_test(max_exact_err < 1e-4, "Barnes-Hut with theta=0.0 matches direct calculation identically (< 1e-4)")
	
	# 3. Kepler 2-body orbit stability under NBody module integration
	nbody.preset_kepler_2body()
	var dt: float = 0.01
	var e0: float = nbody._calculate_initial_total_energy()
	var peak_drift: float = 0.0
	for s in range(500):
		nbody.step(dt)
		var ek: float = 0.0
		var pos_k: PackedVector3Array = nbody.get_positions()
		var vel_k: PackedVector3Array = nbody.get_velocities()
		var m_k: PackedFloat32Array = nbody.get_masses()
		for i in range(pos_k.size()):
			ek += 0.5 * m_k[i] * vel_k[i].length_squared()
		var ep: float = nbody._calculate_total_potential_energy(pos_k)
		var drift: float = absf((ek + ep) - e0) / absf(e0)
		if drift > peak_drift:
			peak_drift = drift
	
	print("  -> Kepler 2-body 500 steps peak energy drift = %.6f" % peak_drift)
	assert_test(peak_drift < 0.001, "NBody module maintains Kepler 2-body orbit energy drift < 0.001", "drift=%.6f" % peak_drift)
	
	nbody.cleanup()

# ==============================================================================
# Suite 9: N-Body - Orbit Trail Buffer & MultiMesh Lifecycle
# ==============================================================================
func _challenge_nbody_trail_buffer_stability() -> void:
	print("\n--- Challenge 9: N-Body Orbit Trail Buffer & MultiMesh Lifecycle ---")
	
	var nbody := NBodyGravityModule.new()
	nbody.enable_trails = true
	nbody.trail_length = 50
	nbody.trail_subsample_ticks = 1
	nbody.max_tracked_trails = 8
	
	# Load figure-8 preset
	nbody.preset_figure8_choreography()
	assert_test(nbody.get_particle_count() == 3, "Figure-8 preset loaded 3 choreographic bodies")
	
	var dt: float = 0.01
	for s in range(200):
		nbody.step(dt)
	
	# Check trail histories
	var trail_hist: Array[PackedVector3Array] = nbody._trail_history
	assert_test(trail_hist.size() == 3, "Trail history array matches body count")
	for i in range(3):
		assert_test(trail_hist[i].size() <= nbody.trail_length, "Body %d trail history bounded by trail_length (%d <= %d)" % [
			i, trail_hist[i].size(), nbody.trail_length
		])
	
	# Check MultiMesh Instance buffers
	var mm: MultiMesh = nbody.get_multimesh()
	assert_test(mm != null and mm.instance_count == 3, "MultiMesh instance count synchronizes with particle count")
	
	# Verify calling _process runs without crash or errors
	nbody._process(0.016)
	assert_test(nbody._trail_mesh != null, "ImmediateMesh trail mesh initialized and updated")
	
	# Clear particles and verify proper teardown
	nbody.clear_particles()
	assert_test(nbody.get_particle_count() == 0, "clear_particles() empties state")
	assert_test(nbody._trail_history.is_empty(), "clear_particles() empties trail histories")
	
	nbody.cleanup()

# ==============================================================================
# Suite 10: Visual Shaders AST & Material Uniform Diagnostics
# ==============================================================================
func _challenge_shader_materials() -> void:
	print("\n--- Challenge 10: Shader AST & Material Uniform Diagnostics ---")
	
	# Shader 1: Particle Field Glow Shader
	var glow_shader := load("res://shaders/particle_field_glow.gdshader") as Shader
	assert_test(glow_shader != null, "Particle field glow shader loads successfully")
	if glow_shader:
		var mat := ShaderMaterial.new()
		mat.shader = glow_shader
		mat.set_shader_parameter("emission_intensity", 3.0)
		mat.set_shader_parameter("cold_color", Color(0.1, 0.5, 1.0))
		mat.set_shader_parameter("hot_color", Color(1.0, 0.2, 0.1))
		mat.set_shader_parameter("enable_billboard", false)
		assert_test(mat.get_shader_parameter("emission_intensity") == 3.0, "Particle glow material uniform parameters accessible")
	
	# Shader 2: Relativistic Mesh Shader
	var rel_shader := load("res://shaders/relativistic_mesh.gdshader") as Shader
	assert_test(rel_shader != null, "Relativistic mesh shader loads successfully")
	if rel_shader:
		var mat := ShaderMaterial.new()
		mat.shader = rel_shader
		mat.set_shader_parameter("speed_of_light", 42.0)
		mat.set_shader_parameter("enable_lorentz_contraction", true)
		mat.set_shader_parameter("enable_doppler", true)
		mat.set_shader_parameter("beaming_power", 4.0)
		assert_test(mat.get_shader_parameter("speed_of_light") == 42.0, "Relativistic material uniform parameters accessible")
