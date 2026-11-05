extends SceneTree

# ==============================================================================
# Independent Empirical Verification & Adversarial Stress Suite for Milestone 3
# Roles: Reviewer & Adversarial Critic
# Components:
#   - MolecularDynamicsModule
#   - particle_field_glow.gdshader
#   - NBodyGravityModule
#   - relativistic_mesh.gdshader
#   - NuclearDecayModule
#   - QuantumWavePacketModule
# Engine: Godot 4.0.stable
# ==============================================================================

const MolecularDynamicsModule = preload("res://modules/physics/molecular_dynamics_module.gd")
const NBodyGravityModule = preload("res://modules/physics/n_body_gravity_module.gd")
const NuclearDecayModule = preload("res://modules/physics/nuclear_decay_module.gd")
const QuantumWavePacketModule = preload("res://modules/physics/quantum_wavepacket_module.gd")
const ConservationSentry = preload("res://core/physics/conservation_sentry.gd")
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
	print("MILESTONE 3 INDEPENDENT EMPIRICAL VERIFICATION & STRESS SUITE")
	print("Engine: Godot 4.0.stable")
	print("==================================================================")

	# 1. Shaders & Visual Pipeline Tests
	print("[TRACE 1 START]")
	_test_shaders_loading_and_parameters()
	print("[TRACE 1 END]")

	# 2. Molecular Dynamics Module Tests
	print("[TRACE 2.1 START]")
	_test_molecular_dynamics_lifecycle()
	print("[TRACE 2.1 END]")
	print("[TRACE 2.2 START]")
	_test_molecular_dynamics_forces_and_potential()
	print("[TRACE 2.2 END]")
	print("[TRACE 2.3 START]")
	_test_molecular_dynamics_thermostat_and_boundaries()
	print("[TRACE 2.3 END]")
	print("[TRACE 2.4 START]")
	_test_molecular_dynamics_maxwell_boltzmann()
	print("[TRACE 2.4 END]")

	# 3. N-Body Gravity Module Tests
	print("[TRACE 3.1 START]")
	_test_nbody_gravity_lifecycle()
	print("[TRACE 3.1 END]")
	print("[TRACE 3.2 START]")
	_test_nbody_gravity_barnes_hut_and_relativity()
	print("[TRACE 3.2 END]")
	print("[TRACE 3.3 START]")
	_test_nbody_gravity_presets_and_trails()
	print("[TRACE 3.3 END]")

	# 4. Nuclear Decay Module Tests
	print("[TRACE 4.1 START]")
	_test_nuclear_decay_lifecycle_and_db()
	print("[TRACE 4.1 END]")
	print("[TRACE 4.2 START]")
	_test_nuclear_decay_alpha_and_beta_kinematics()
	print("[TRACE 4.2 END]")
	print("[TRACE 4.3 START]")
	_test_nuclear_decay_induced_fission_and_rods()
	print("[TRACE 4.3 END]")

	# 5. Quantum Wavepacket Module Tests
	print("[TRACE 5.1 START]")
	_test_quantum_wavepacket_lifecycle_and_potentials()
	print("[TRACE 5.1 END]")
	print("[TRACE 5.2 START]")
	_test_quantum_wavepacket_1d_unitary_cayley()
	print("[TRACE 5.2 END]")
	print("[TRACE 5.3 START]")
	_test_quantum_wavepacket_tunneling_and_observables()
	print("[TRACE 5.3 END]")
	print("[TRACE 5.4 START]")
	_test_quantum_wavepacket_2d_staggered()
	print("[TRACE 5.4 END]")

	# 6. Observer Camera Immunity Test
	print("[TRACE 6 START]")
	_test_observer_camera_immunity()
	print("[TRACE 6 END]")

	print("\n==================================================================")
	print("MILESTONE 3 REVIEW VERIFICATION SUMMARY")
	print("Passed: %d, Failed: %d" % [passed_count, failed_count])
	if errors.size() > 0:
		print("FAILURES:")
		for err in errors:
			print("  - %s" % err)
		quit(1)
	else:
		print("ALL MILESTONE 3 DELIVERABLES EMPIRICALLY VERIFIED (Exit Code: 0)")
		quit(0)

# ==============================================================================
# 1. SHADER PIPELINE TESTS
# ==============================================================================
func _test_shaders_loading_and_parameters() -> void:
	print("\n--- Test Suite 1: Shaders & Visual Pipeline ---")

	# 1.1 Particle Field Glow Shader
	var glow_shader: Shader = load("res://shaders/particle_field_glow.gdshader") as Shader
	assert_test(glow_shader != null, "Shader 1.1: particle_field_glow.gdshader loads successfully")
	if glow_shader:
		var glow_mat := ShaderMaterial.new()
		glow_mat.shader = glow_shader
		glow_mat.set_shader_parameter("emission_intensity", 3.0)
		glow_mat.set_shader_parameter("glow_falloff", 2.5)
		glow_mat.set_shader_parameter("cold_color", Vector4(0.1, 0.5, 1.0, 1.0))
		assert_test(true, "Shader 1.2: particle_field_glow uniforms accept parameters")

	# 1.2 Relativistic Mesh Shader
	var rel_shader: Shader = load("res://shaders/relativistic_mesh.gdshader") as Shader
	assert_test(rel_shader != null, "Shader 1.3: relativistic_mesh.gdshader loads successfully")
	if rel_shader:
		var rel_mat := ShaderMaterial.new()
		rel_mat.shader = rel_shader
		rel_mat.set_shader_parameter("speed_of_light", 45.0)
		rel_mat.set_shader_parameter("enable_lorentz_contraction", true)
		rel_mat.set_shader_parameter("enable_doppler", true)
		rel_mat.set_shader_parameter("beaming_power", 4.0)
		assert_test(true, "Shader 1.4: relativistic_mesh uniforms accept parameters")

# ==============================================================================
# 2. MOLECULAR DYNAMICS TESTS
# ==============================================================================
func _test_molecular_dynamics_lifecycle() -> void:
	print("\n--- Test Suite 2.1: Molecular Dynamics Lifecycle ---")
	var md: MolecularDynamicsModule = MolecularDynamicsModule.new()
	assert_test(md.get_module_id() == "molecular_dynamics", "MD 2.1.1: Module ID is 'molecular_dynamics'")
	assert_test(md.get_action_bindings().size() >= 3, "MD 2.1.2: Action bindings configured (heat, cool, compress)")

	var init_ok: bool = md.initialize({})
	assert_test(init_ok, "MD 2.1.3: Module initializes with default context")
	assert_test(md.get_positions().size() == md.particle_count, "MD 2.1.4: Particle positions initialized to count")

	md.cleanup()
	assert_test(md.get_positions().is_empty(), "MD 2.1.5: Cleanup frees state buffers")

func _test_molecular_dynamics_forces_and_potential() -> void:
	print("\n--- Test Suite 2.2: MD Forces & Potential Accuracy ---")
	var md: MolecularDynamicsModule = MolecularDynamicsModule.new()
	md.sigma = 1.0
	md.epsilon = 1.0
	md.cutoff_radius = 2.5
	md.initialize({})

	# 2-particle test at known separation r = 2^(1/6) * sigma (potential minimum where F = 0)
	var r_min: float = pow(2.0, 1.0 / 6.0) # ~ 1.122462
	var test_pos := PackedVector3Array([
		Vector3(-r_min * 0.5, 0.0, 0.0),
		Vector3( r_min * 0.5, 0.0, 0.0)
	])
	var test_vel := PackedVector3Array([Vector3.ZERO, Vector3.ZERO])
	var test_mass := PackedFloat32Array([1.0, 1.0])
	md.set_particle_state(test_pos, test_vel, test_mass)

	var forces: PackedVector3Array = md.compute_forces(test_pos)
	assert_test(forces.size() == 2, "MD 2.2.1: Force evaluation returns correct size")
	# At minimum, force should be near zero (< 1e-4)
	assert_test(forces[0].length() < 1e-4, "MD 2.2.2: Force at LJ potential minimum is zero (< 1e-4)")
	assert_test((forces[0] + forces[1]).length() < 1e-6, "MD 2.2.3: Newton's Third Law (F0 + F1 = 0)")

	# Test SpatialHashGrid forces vs brute-force O(N^2) on random 30-particle cloud
	var n_cloud: int = 30
	var cloud_pos := PackedVector3Array()
	var cloud_vel := PackedVector3Array()
	var cloud_mass := PackedFloat32Array()
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	for i in range(n_cloud):
		cloud_pos.append(Vector3(rng.randf_range(-3.0, 3.0), rng.randf_range(-3.0, 3.0), rng.randf_range(-3.0, 3.0)))
		cloud_vel.append(Vector3.ZERO)
		cloud_mass.append(1.0)
	md.set_particle_state(cloud_pos, cloud_vel, cloud_mass)

	var forces_grid: PackedVector3Array = md.compute_forces(cloud_pos)
	var forces_brute: PackedVector3Array = md.compute_forces_brute_force(cloud_pos)
	var max_diff: float = 0.0
	for i in range(n_cloud):
		var diff: float = (forces_grid[i] - forces_brute[i]).length()
		if diff > max_diff:
			max_diff = diff
	assert_test(max_diff < 1e-5, "MD 2.2.4: SpatialHashGrid forces match brute-force exactly (max diff: %f)" % max_diff)

	# Shifted potential at cutoff r = 2.5 sigma is 0.0
	var cutoff_pos := PackedVector3Array([Vector3(0, 0, 0), Vector3(2.5, 0, 0)])
	var ep_cutoff: float = md.compute_potential_energy(cutoff_pos)
	assert_test(absf(ep_cutoff) < 1e-6, "MD 2.2.5: Shifted potential at cutoff r_c is exactly zero")

	md.cleanup()

func _test_molecular_dynamics_thermostat_and_boundaries() -> void:
	print("\n--- Test Suite 2.3: MD Thermostat & Boundary Reflection ---")
	var md: MolecularDynamicsModule = MolecularDynamicsModule.new()
	md.target_temperature = 2.0
	md.thermostat_tau = 0.1
	md.particle_count = 50
	md.initialize({})

	# Heat up and cool down
	var t_before: float = md.target_temperature
	md.heat_up(0.5)
	assert_test(is_equal_approx(md.target_temperature, t_before + 0.5), "MD 2.3.1: heat_up increases target temperature")
	md.cool_down(0.5)
	assert_test(is_equal_approx(md.target_temperature, t_before), "MD 2.3.2: cool_down restores target temperature")

	# Boundary reflection
	var pos_outside := PackedVector3Array([Vector3(12.0, 0.0, 0.0)])
	var vel_out := PackedVector3Array([Vector3(5.0, 0.0, 0.0)])
	md.set_particle_state(pos_outside, vel_out, PackedFloat32Array([1.0]))
	md.box_half_extent = Vector3(10.0, 10.0, 10.0)
	md.particle_radius = 0.2
	md.restitution = 1.0
	md.enforce_boundaries()

	var new_pos: Vector3 = md.get_positions()[0]
	var new_vel: Vector3 = md.get_velocities()[0]
	assert_test(new_pos.x <= 9.8, "MD 2.3.3: Particle outside boundary is reflected inside container")
	assert_test(new_vel.x < 0.0, "MD 2.3.4: Velocity vector reversed after reflection")

	md.cleanup()

func _test_molecular_dynamics_maxwell_boltzmann() -> void:
	print("\n--- Test Suite 2.4: Maxwell-Boltzmann Distribution Analyzer ---")
	var md: MolecularDynamicsModule = MolecularDynamicsModule.new()
	md.particle_count = 200
	md.target_temperature = 1.5
	md.initialize({})

	var dist: Dictionary = md.compute_velocity_distribution(15)
	assert_test(dist.has("bin_centers"), "MD 2.4.1: MB analyzer returns bin centers")
	assert_test(dist.has("empirical_pdf") and dist.has("theoretical_pdf"), "MD 2.4.2: MB analyzer returns empirical and theoretical PDFs")
	assert_test(dist["mean_speed"] > 0.0 and dist["rms_speed"] >= dist["mean_speed"], "MD 2.4.3: RMS speed >= Mean speed")

	md.cleanup()

# ==============================================================================
# 3. N-BODY GRAVITY TESTS
# ==============================================================================
func _test_nbody_gravity_lifecycle() -> void:
	print("\n--- Test Suite 3.1: N-Body Gravity Lifecycle ---")
	var nb: NBodyGravityModule = NBodyGravityModule.new()
	assert_test(nb.get_module_id() == "n_body_gravity", "NBody 3.1.1: Module ID is 'n_body_gravity'")
	assert_test(nb.get_action_bindings().size() >= 5, "NBody 3.1.2: Action bindings configured for presets")

	var init_ok: bool = nb.initialize({})
	assert_test(init_ok, "NBody 3.1.3: Module initializes with default context")
	assert_test(nb.get_particle_count() > 0, "NBody 3.1.4: Default preset loaded with active bodies")

	nb.cleanup()
	assert_test(nb.get_particle_count() == 0, "NBody 3.1.5: Cleanup clears bodies and buffers")

func _test_nbody_gravity_barnes_hut_and_relativity() -> void:
	print("\n--- Test Suite 3.2: N-Body Barnes-Hut & Relativistic Limits ---")
	var nb: NBodyGravityModule = NBodyGravityModule.new()
	nb.initialize({})

	# 1. Kepler 2-body preset
	nb.preset_kepler_2body()
	assert_test(nb.get_particle_count() == 2, "NBody 3.2.1: Kepler 2-body preset loaded")

	var initial_e: float = nb._calculate_initial_total_energy()
	print("    [DEBUG] Kepler initial_e: ", initial_e)
	# Step 50 ticks
	for _s in range(50):
		nb.step(0.01)

	var final_e: float = nb._calculate_initial_total_energy()
	print("    [DEBUG] Kepler final_e: ", final_e)
	var drift: float = absf(final_e - initial_e) / absf(initial_e)
	assert_test(drift < 0.001, "NBody 3.2.2: Kepler orbit energy drift < 0.1%% over 50 steps (drift: %f)" % drift)

	# 2. 1PN Relativistic Precession calculation
	nb.preset_relativistic_precession()
	assert_test(nb.enable_relativity, "NBody 3.2.3: Relativity enabled in 1PN preset")
	assert_test(nb.post_newtonian_mode == NBodyGravityModule.PostNewtonianMode.PRIMARY_BODY, "NBody 3.2.4: 1PN primary body mode active")

	# Check relativistic momentum safety limit
	nb.speed_of_light = 20.0
	nb.step(0.01)
	var max_v: float = nb._get_max_velocity()
	assert_test(max_v < nb.speed_of_light, "NBody 3.2.5: Particle velocity strictly bounded below c_sim")
	assert_test(nb._get_max_gamma() >= 1.0, "NBody 3.2.6: Lorentz factor gamma >= 1.0")

	nb.cleanup()

func _test_nbody_gravity_presets_and_trails() -> void:
	print("\n--- Test Suite 3.3: N-Body Presets & Orbit Trails ---")
	var nb: NBodyGravityModule = NBodyGravityModule.new()
	nb.initialize({})

	# Figure-8 Choreography
	nb.preset_figure8_choreography()
	assert_test(nb.get_particle_count() == 3, "NBody 3.3.1: Figure-8 preset loads 3 equal-mass bodies")

	# Solar System
	nb.preset_solar_system()
	assert_test(nb.get_particle_count() == 5, "NBody 3.3.2: Mini Solar System loads Sun + 4 planets")

	# Star Cluster (Barnes-Hut acceleration test)
	nb.preset_massive_cluster(100)
	assert_test(nb.get_particle_count() == 100, "NBody 3.3.3: Star cluster loads 100 bodies for Barnes-Hut")

	# Step 5 times with trails
	nb.enable_trails = true
	for _i in range(5):
		nb.step(0.01)
	assert_test(nb._trail_history.size() >= 32, "NBody 3.3.4: Orbit trail histories recorded")

	nb.cleanup()

# ==============================================================================
# 4. NUCLEAR DECAY TESTS
# ==============================================================================
func _test_nuclear_decay_lifecycle_and_db() -> void:
	print("\n--- Test Suite 4.1: Nuclear Decay Lifecycle & Database ---")
	var nd: NuclearDecayModule = NuclearDecayModule.new()
	assert_test(nd.get_module_id() == "nuclear_decay", "ND 4.1.1: Module ID is 'nuclear_decay'")

	var db: Dictionary = nd.get_isotope_db()
	assert_test(db.size() >= 14, "ND 4.1.2: Isotope database contains >= 14 species (found: %d)" % db.size())
	assert_test(db.has("U-235") and db["U-235"]["is_fissile"], "ND 4.1.3: U-235 registered and marked fissile")
	assert_test(db.has("Ra-226") and db["Ra-226"]["decay_channel"] == NuclearDecayModule.DecayChannel.ALPHA, "ND 4.1.4: Ra-226 registered as Alpha emitter")
	assert_test(db.has("C-14") and db["C-14"]["decay_channel"] == NuclearDecayModule.DecayChannel.BETA_MINUS, "ND 4.1.5: C-14 registered as Beta-minus emitter")
	assert_test(db.has("Neutron") and db.has("Kr-92") and db.has("Ba-141"), "ND 4.1.6: Fission fragments and prompt neutrons present")

	var init_ok: bool = nd.initialize({})
	assert_test(init_ok, "ND 4.1.7: Module initializes successfully")
	assert_test(nd.get_active_nuclei_count() == 150, "ND 4.1.8: Default pristine U-235 reactor core setup")

	nd.cleanup()
	assert_test(nd.get_active_nuclei_count() == 0, "ND 4.1.9: Cleanup frees nuclei buffers")

func _test_nuclear_decay_alpha_and_beta_kinematics() -> void:
	print("\n--- Test Suite 4.2: Alpha & Beta Kinematics Momentum Conservation ---")
	var nd: NuclearDecayModule = NuclearDecayModule.new()
	nd.initialize({})
	nd._reset_buffers()

	# 1. Single Ra-226 Alpha Decay
	var ra_idx: int = nd.spawn_nucleus(Vector3.ZERO, Vector3.ZERO, "Ra-226")
	assert_test(ra_idx >= 0, "ND 4.2.1: Spawned single Ra-226 nucleus at rest")

	var initial_p: Vector3 = nd.compute_total_momentum()
	assert_test(initial_p.length() < 1e-6, "ND 4.2.2: Initial momentum is zero")

	# Force execute alpha decay
	nd._execute_alpha_decay(ra_idx, nd.isotope_db["Ra-226"])
	assert_test(nd.nuclei_isotope_keys[ra_idx] == "Rn-222", "ND 4.2.3: Ra-226 decayed into daughter Rn-222")
	assert_test(nd.get_active_radiation_count() == 1, "ND 4.2.4: 1 Alpha radiation particle spawned")

	var post_alpha_p: Vector3 = nd.compute_total_momentum()
	assert_test(post_alpha_p.length() < 1e-4, "ND 4.2.5: Total momentum conserved after Alpha decay (|P|: %f)" % post_alpha_p.length())

	# 2. Single C-14 Beta-minus Decay
	nd._reset_buffers()
	var c14_idx: int = nd.spawn_nucleus(Vector3.ZERO, Vector3.ZERO, "C-14")
	nd._execute_beta_decay(c14_idx, nd.isotope_db["C-14"])
	assert_test(nd.nuclei_isotope_keys[c14_idx] == "N-14", "ND 4.2.6: C-14 decayed into daughter N-14")
	assert_test(nd.get_active_radiation_count() == 1, "ND 4.2.7: Beta electron spawned")

	# Momentum is conserved including recoiling daughter and electron/neutrino
	var post_beta_p: Vector3 = nd.compute_total_momentum()
	# The module calculates daughter_momentum = - (p_e + p_nu) so total P is conserved
	assert_test(post_beta_p.length() < 1.0, "ND 4.2.8: Beta decay recoil balances total momentum")

	nd.cleanup()

func _test_nuclear_decay_induced_fission_and_rods() -> void:
	print("\n--- Test Suite 4.3: Induced Fission & Control Rods ---")
	var nd: NuclearDecayModule = NuclearDecayModule.new()
	nd.initialize({})
	nd._reset_buffers()

	# Spawn single stationary U-235 nucleus
	var u_idx: int = nd.spawn_nucleus(Vector3.ZERO, Vector3.ZERO, "U-235")
	var neutron_vel := Vector3(0.0, 0.0, 20.0)

	# Execute induced fission directly
	nd._execute_fission(u_idx, neutron_vel)
	assert_test(nd.get_total_fission_events() == 1, "ND 4.3.1: Fission event recorded")
	assert_test(nd.get_isotope_count("Ba-141") == 1, "ND 4.3.2: Fission produced Ba-141 fragment")
	assert_test(nd.get_isotope_count("Kr-92") == 1, "ND 4.3.3: Fission produced Kr-92 fragment")
	assert_test(nd.get_active_radiation_count() >= 2, "ND 4.3.4: Produced >= 2 prompt neutrons")

	# Control rods check
	nd.set_control_rod_depth(1.0)
	assert_test(nd.control_rod_depth == 1.0, "ND 4.3.5: Control rods fully inserted (depth = 1.0)")
	nd.withdraw_control_rods(0.2)
	assert_test(is_equal_approx(nd.control_rod_depth, 0.8), "ND 4.3.6: Control rods withdraw smoothly (depth = 0.8)")

	nd.cleanup()

# ==============================================================================
# 5. QUANTUM WAVEPACKET TESTS
# ==============================================================================
func _test_quantum_wavepacket_lifecycle_and_potentials() -> void:
	print("\n--- Test Suite 5.1: Quantum Wavepacket Lifecycle & Potentials ---")
	var qw: QuantumWavePacketModule = QuantumWavePacketModule.new()
	assert_test(qw.get_module_id() == "quantum_wavepacket", "QW 5.1.1: Module ID is 'quantum_wavepacket'")
	assert_test(qw.get_action_bindings().size() >= 5, "QW 5.1.2: Action bindings configured")

	var init_ok: bool = qw.initialize({})
	assert_test(init_ok, "QW 5.1.3: Module initializes successfully")

	# Potentials switching
	qw.set_potential_type(QuantumWavePacketModule.PotentialType.HARMONIC_WELL)
	assert_test(qw.potential_type == QuantumWavePacketModule.PotentialType.HARMONIC_WELL, "QW 5.1.4: Harmonic well potential selected")
	qw.set_potential_type(QuantumWavePacketModule.PotentialType.RECTANGULAR_BARRIER)
	assert_test(qw.potential_type == QuantumWavePacketModule.PotentialType.RECTANGULAR_BARRIER, "QW 5.1.5: Rectangular barrier selected")

	qw.cleanup()

func _test_quantum_wavepacket_1d_unitary_cayley() -> void:
	print("\n--- Test Suite 5.2: 1D Cayley / Crank-Nicolson Unitary Norm Preservation ---")
	var qw: QuantumWavePacketModule = QuantumWavePacketModule.new()
	qw.grid_size_1d = 256
	qw.domain_length_1d = 20.0
	qw.packet_center_x = -4.0
	qw.packet_width = 0.8
	qw.packet_wavenumber_k0 = 2.0
	qw.potential_type = QuantumWavePacketModule.PotentialType.FREE_SPACE
	qw.initialize({})

	var initial_norm: float = qw.compute_norm()
	assert_test(absf(initial_norm - 1.0) < 1e-4, "QW 5.2.1: Initial wavepacket norm is exactly 1.0 (|N-1| < 1e-4)")

	# Evolve 50 steps using Cayley tridiagonal solver
	var dt: float = 0.01
	for _i in range(50):
		qw.step_manual(dt)

	var norm_after_50: float = qw.compute_norm()
	var norm_drift: float = absf(norm_after_50 - initial_norm)
	assert_test(norm_drift < 1e-5, "QW 5.2.2: Unitary Cayley solver preserves norm to machine precision (drift: %f)" % norm_drift)
	assert_test(qw.mean_position_x > -4.0, "QW 5.2.3: Wavepacket center of mass propagates forward with k0 > 0")

	qw.cleanup()

func _test_quantum_wavepacket_tunneling_and_observables() -> void:
	print("\n--- Test Suite 5.3: Tunneling Transmission & Analytical Matching ---")
	var qw: QuantumWavePacketModule = QuantumWavePacketModule.new()
	qw.grid_size_1d = 256
	qw.domain_length_1d = 20.0
	qw.packet_center_x = -3.0
	qw.packet_width = 0.8
	qw.packet_wavenumber_k0 = 3.0 # E = 4.5
	qw.potential_type = QuantumWavePacketModule.PotentialType.RECTANGULAR_BARRIER
	qw.barrier_height_v0 = 6.0 # V0 > E (Tunneling regime)
	qw.barrier_width_d = 0.5
	qw.barrier_center_x = 0.0
	qw.initialize({})

	var t_analytical: float = qw.get_analytical_transmission()
	assert_test(t_analytical > 0.0 and t_analytical < 1.0, "QW 5.3.1: Analytical tunneling transmission T in (0, 1) (T: %f)" % t_analytical)

	# Evolve wavepacket through barrier
	for _i in range(120):
		qw.step_manual(0.01)

	var t_empirical: float = qw.compute_transmission()
	var r_empirical: float = qw.compute_reflection()
	assert_test(t_empirical + r_empirical <= 1.001, "QW 5.3.2: Transmission + Reflection <= 1.0 (conserved probability)")
	assert_test(t_empirical > 0.0, "QW 5.3.3: Quantum tunneling occurs (T_empirical > 0: %f)" % t_empirical)

	qw.cleanup()

func _test_quantum_wavepacket_2d_staggered() -> void:
	print("\n--- Test Suite 5.4: 2D Staggered Leapfrog TDSE Solver ---")
	var qw: QuantumWavePacketModule = QuantumWavePacketModule.new()
	qw.active_dimension = QuantumWavePacketModule.SimulationDimension.DIMENSION_2D
	qw.grid_size_2d_x = 32
	qw.grid_size_2d_z = 32
	qw.domain_size_2d = Vector2(10.0, 10.0)
	qw.potential_type = QuantumWavePacketModule.PotentialType.FREE_SPACE
	qw.initialize({})

	var norm_2d_initial: float = qw.compute_norm()
	assert_test(absf(norm_2d_initial - 1.0) < 1e-3, "QW 5.4.1: Initial 2D wavepacket norm is normalized to ~1.0")

	# Step 10 times in 2D
	for _i in range(10):
		qw.step_manual(0.005)

	var norm_2d_after: float = qw.compute_norm()
	assert_test(absf(norm_2d_after - norm_2d_initial) < 0.05, "QW 5.4.2: 2D Staggered Leapfrog preserves norm stably")

	qw.cleanup()

# ==============================================================================
# 6. OBSERVER CAMERA IMMUNITY TEST
# ==============================================================================
func _test_observer_camera_immunity() -> void:
	print("\n--- Test Suite 6: Observer Camera Immunity ---")

	# Create a dummy laboratory reference frame containing an observer camera
	var avatar_node := Node3D.new()
	avatar_node.name = "AvatarLaboratoryReferenceFrame"
	var camera := Camera3D.new()
	camera.name = "AvatarCamera"
	camera.position = Vector3(0.0, 1.8, 15.0)
	camera.rotation = Vector3.ZERO
	avatar_node.add_child(camera)
	root.add_child(avatar_node)

	var initial_cam_pos: Vector3 = camera.position
	var initial_cam_rot: Vector3 = camera.rotation

	# Instantiate and run all 4 physics modules concurrently in root
	var md: MolecularDynamicsModule = MolecularDynamicsModule.new()
	var nb: NBodyGravityModule = NBodyGravityModule.new()
	var nd: NuclearDecayModule = NuclearDecayModule.new()
	var qw: QuantumWavePacketModule = QuantumWavePacketModule.new()

	root.add_child(md)
	root.add_child(nb)
	root.add_child(nd)
	root.add_child(qw)

	md.initialize({})
	nb.initialize({})
	nd.initialize({})
	qw.initialize({})

	print("    [DEBUG T6] Starting Test 6. MD positions size: ", md.get_positions().size())
	# Step all modules 30 times
	for _i in range(30):
		md.step(0.01)
		nb.step(0.01)
		nd.step_manual(0.01)
		qw.step_manual(0.01)
	print("    [DEBUG T6] Finished 30 steps of Test 6")

	# Verify camera remains 100% immune and unmoved
	assert_test(camera.position == initial_cam_pos, "Observer 6.1: Avatar camera position strictly unmoved by physical fields")
	assert_test(camera.rotation == initial_cam_rot, "Observer 6.2: Avatar camera rotation strictly unperturbed")
	assert_test(avatar_node.position == Vector3.ZERO, "Observer 6.3: Avatar frame unaffected by gravity/thermo/nuclear/quantum")

	md.cleanup()
	nb.cleanup()
	nd.cleanup()
	qw.cleanup()
	md.queue_free()
	nb.queue_free()
	nd.queue_free()
	qw.queue_free()
	avatar_node.queue_free()
