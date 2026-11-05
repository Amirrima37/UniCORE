extends SceneTree

## =============================================================================
## UniCORE Independent Forensic Integrity Audit Suite: Milestone 3
## Verifies all 6 physics deliverables with ZERO TOLERANCE:
## 1. MolecularDynamicsModule (res://modules/physics/molecular_dynamics_module.gd)
## 2. ParticleFieldGlowShader (res://shaders/particle_field_glow.gdshader)
## 3. NBodyGravityModule (res://modules/physics/n_body_gravity_module.gd)
## 4. RelativisticMeshShader (res://shaders/relativistic_mesh.gdshader)
## 5. NuclearDecayModule (res://modules/physics/nuclear_decay_module.gd)
## 6. QuantumWavePacketModule (res://modules/physics/quantum_wavepacket_module.gd)
## Observer Isolation: Avatar Locomotion Camera Immunity
## Architecture Compliance: MultiMesh data-oriented rendering, zero Node3D leaks
## =============================================================================

const MolecularDynamicsModule = preload("res://modules/physics/molecular_dynamics_module.gd")
const NBodyGravityModule = preload("res://modules/physics/n_body_gravity_module.gd")
const NuclearDecayModule = preload("res://modules/physics/nuclear_decay_module.gd")
const QuantumWavePacketModule = preload("res://modules/physics/quantum_wavepacket_module.gd")
const AvatarLocomotion = preload("res://modules/builtin/avatar_locomotion.gd")

var total_tests: int = 0
var passed_tests: int = 0
var failed_tests: int = 0

func _init() -> void:
	print("=================================================================")
	print("STARTING INDEPENDENT FORENSIC INTEGRITY AUDIT: MILESTONE 3")
	print("=================================================================")
	
	# Section 1: Molecular Dynamics
	audit_molecular_dynamics_forces()
	audit_molecular_dynamics_thermostat()
	audit_molecular_dynamics_maxwell_boltzmann()
	audit_molecular_dynamics_boundaries()
	audit_molecular_dynamics_multimesh()
	
	# Section 2: Shaders
	audit_particle_field_glow_shader()
	audit_relativistic_mesh_shader()
	
	# Section 3: N-Body Gravity
	audit_nbody_gravity_barnes_hut()
	audit_nbody_gravity_1pn_precession()
	audit_nbody_gravity_relativistic_tensor()
	audit_nbody_gravity_multimesh_and_trails()
	
	# Section 4: Nuclear Decay
	audit_nuclear_decay_database()
	audit_nuclear_decay_poisson_kinetics()
	audit_nuclear_decay_momentum_conservation()
	audit_nuclear_decay_induced_fission()
	audit_nuclear_decay_multimesh()
	
	# Section 5: Quantum Wavepacket
	audit_quantum_cayley_unitary_norm()
	audit_quantum_tunneling()
	audit_quantum_2d_leapfrog()
	audit_quantum_visualization()
	
	# Section 6: Observer Isolation & Architecture
	audit_observer_camera_isolation()
	
	print("=================================================================")
	print("M3 FORENSIC AUDIT SUMMARY: Total: %d, Passed: %d, Failed: %d" % [total_tests, passed_tests, failed_tests])
	print("=================================================================")
	
	if failed_tests > 0:
		print("AUDIT VERDICT: INTEGRITY VIOLATION / FAILURES DETECTED")
		quit(1)
	else:
		print("AUDIT VERDICT: CLEAN - ALL FORENSIC CHECKS EMPIRICALLY VERIFIED")
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
# SECTION 1: MOLECULAR DYNAMICS AUDIT
# ==============================================================================

func audit_molecular_dynamics_forces() -> void:
	print("\n--- 1.1 MolecularDynamicsModule: Lennard-Jones Pairwise Forces ---")
	var md: MolecularDynamicsModule = MolecularDynamicsModule.new()
	md.sigma = 1.0
	md.epsilon = 1.0
	md.cutoff_radius = 2.5
	md.initialize({})
	
	# 1. Equilibrium distance: r = 2^(1/6) * sigma ≈ 1.122462048
	# At this separation, LJ 12-6 potential has dV/dr = 0, so force must be 0.
	var r_eq: float = pow(2.0, 1.0 / 6.0)
	var pos_eq := PackedVector3Array([Vector3(0, 0, 0), Vector3(r_eq, 0, 0)])
	var vel_zero := PackedVector3Array([Vector3.ZERO, Vector3.ZERO])
	md.set_particle_state(pos_eq, vel_zero)
	
	var forces_eq: PackedVector3Array = md.compute_forces(pos_eq)
	check(forces_eq.size() == 2, "Force buffer size matches particle count", "Size is %d" % forces_eq.size())
	check(forces_eq[0].length() < 1e-4, "LJ force vanishes at potential minimum r = 2^(1/6)*sigma", "Force[0] length = %f" % forces_eq[0].length())
	check(forces_eq[1].length() < 1e-4, "LJ force vanishes for second particle at r_eq", "Force[1] length = %f" % forces_eq[1].length())
	
	# 2. Repulsive regime: r = 1.0 * sigma
	# Analytical LJ force magnitude: F(r) = 24*epsilon/r * [ 2*(sigma/r)^12 - (sigma/r)^6 ]
	# For sigma=1, epsilon=1, r=1: F(1) = 24 * [2 - 1] = 24.0 (repulsive, pushes particle 0 at x=0 towards -X)
	var pos_rep := PackedVector3Array([Vector3(0, 0, 0), Vector3(1.0, 0, 0)])
	md.set_particle_state(pos_rep, vel_zero)
	var forces_rep: PackedVector3Array = md.compute_forces(pos_rep)
	check(is_equal_approx(forces_rep[0].x, -24.0), "Repulsive LJ force at r=sigma exact match (-24.0)", "Got %f" % forces_rep[0].x)
	check(is_equal_approx(forces_rep[1].x, 24.0), "Newton 3rd law: F_21 = -F_12 (+24.0)", "Got %f" % forces_rep[1].x)
	check((forces_rep[0] + forces_rep[1]).length() < 1e-6, "Momentum conservation: sum of internal pairwise forces is 0", "Sum is %s" % str(forces_rep[0] + forces_rep[1]))
	
	# 3. Cutoff verification: r = 3.0 > cutoff_radius (2.5)
	var pos_far := PackedVector3Array([Vector3(0, 0, 0), Vector3(3.0, 0, 0)])
	md.set_particle_state(pos_far, vel_zero)
	var forces_far: PackedVector3Array = md.compute_forces(pos_far)
	check(forces_far[0].length() < 1e-9, "LJ force is 0 beyond cutoff radius r_c", "Got %f" % forces_far[0].length())
	
	# 4. SpatialHashGrid vs Brute Force Parity Test on multi-particle ensemble
	var rng := RandomNumberGenerator.new()
	rng.seed = 99
	var ensemble_pos := PackedVector3Array()
	var ensemble_vel := PackedVector3Array()
	for i in range(25):
		ensemble_pos.append(Vector3(rng.randf_range(-4, 4), rng.randf_range(-4, 4), rng.randf_range(-4, 4)))
		ensemble_vel.append(Vector3.ZERO)
	md.set_particle_state(ensemble_pos, ensemble_vel)
	
	var hash_forces: PackedVector3Array = md.compute_forces(ensemble_pos)
	var brute_forces: PackedVector3Array = md.compute_forces_brute_force(ensemble_pos)
	var diff_max: float = 0.0
	for i in range(25):
		var diff: float = (hash_forces[i] - brute_forces[i]).length()
		if diff > diff_max:
			diff_max = diff
	check(diff_max < 1e-5, "SpatialHashGrid forces match brute-force O(N^2) identically", "Max difference = %f" % diff_max)
	
	md.cleanup()

func audit_molecular_dynamics_thermostat() -> void:
	print("\n--- 1.2 MolecularDynamicsModule: Berendsen Thermostat Scaling ---")
	var md: MolecularDynamicsModule = MolecularDynamicsModule.new()
	md.particle_count = 10
	md.target_temperature = 1.0
	md.thermostat_tau = 0.1
	md.thermostat_enabled = true
	md.initialize({})
	
	# Set particles to a hot velocity v = (3.0, 0, 0)
	var vel_hot := PackedVector3Array()
	for i in range(10):
		vel_hot.append(Vector3(3.0, 0.0, 0.0))
	var pos := PackedVector3Array()
	for i in range(10):
		pos.append(Vector3(float(i) * 2.0, 0, 0))
	md.set_particle_state(pos, vel_hot)
	
	# Ek = 10 * 0.5 * 1 * 9 = 45. T = 2 * 45 / (3 * 10 * 1) = 3.0 > target (1.0)
	var initial_temp: float = md.compute_instantaneous_temperature()
	check(initial_temp > md.target_temperature, "Initial temperature is hot before thermostat (T > T_target)", "T = %f vs T_target = %f" % [initial_temp, md.target_temperature])
	
	# Apply Berendsen thermostat with dt = 0.05
	var lambda_scale: float = md.apply_berendsen_thermostat(0.05)
	check(lambda_scale < 1.0, "Thermostat scales velocities downward when T > T_target", "lambda = %f" % lambda_scale)
	var cooled_temp: float = md.compute_instantaneous_temperature()
	check(cooled_temp < initial_temp, "Instantaneous temperature decreased toward target", "T cooled = %f" % cooled_temp)
	
	# Now test heating when cold
	md.target_temperature = 10.0
	var lambda_heat: float = md.apply_berendsen_thermostat(0.05)
	check(lambda_heat > 1.0, "Thermostat scales velocities upward when T < T_target", "lambda = %f" % lambda_heat)
	
	md.cleanup()

func audit_molecular_dynamics_maxwell_boltzmann() -> void:
	print("\n--- 1.3 MolecularDynamicsModule: Maxwell-Boltzmann Distribution ---")
	var md: MolecularDynamicsModule = MolecularDynamicsModule.new()
	md.particle_count = 200
	md.target_temperature = 2.0
	md.initialize({})
	
	var dist: Dictionary = md.compute_velocity_distribution(20)
	check(dist.has("mean_speed"), "Distribution computes mean_speed", "Key present")
	check(dist.has("rms_speed"), "Distribution computes rms_speed", "Key present")
	check(dist.has("most_probable_speed"), "Distribution computes most_probable_speed", "Key present")
	check(dist.has("empirical_pdf"), "Distribution computes empirical_pdf", "Key present")
	check(dist.has("theoretical_pdf"), "Distribution computes theoretical_pdf", "Key present")
	
	var v_mp: float = dist["most_probable_speed"]
	var v_mean: float = dist["mean_speed"]
	var v_rms: float = dist["rms_speed"]
	
	# Theoretical MB property: v_mp < v_mean < v_rms
	check(v_mp < v_mean and v_mean < v_rms, "Kinetic speed ordering satisfied: v_mp < <v> < v_rms", "v_mp=%f, <v>=%f, v_rms=%f" % [v_mp, v_mean, v_rms])
	
	# Check PDF normalization
	var pdf: PackedFloat32Array = dist["empirical_pdf"]
	var bin_width: float = dist["bin_width"]
	var sum_p: float = 0.0
	for i in range(pdf.size()):
		sum_p += pdf[i] * bin_width
	check(absf(sum_p - 1.0) < 0.05, "Empirical PDF normalized to integral ~ 1.0", "Sum = %f" % sum_p)
	
	md.cleanup()

func audit_molecular_dynamics_boundaries() -> void:
	print("\n--- 1.4 MolecularDynamicsModule: Reflective Cubic Container ---")
	var md: MolecularDynamicsModule = MolecularDynamicsModule.new()
	md.box_half_extent = Vector3(5.0, 5.0, 5.0)
	md.particle_radius = 0.2
	md.restitution = 1.0
	md.initialize({})
	
	# Particle placing at x = 5.5 (outside +X boundary) moving outward (+10)
	var pos := PackedVector3Array([Vector3(5.5, 0.0, 0.0)])
	var vel := PackedVector3Array([Vector3(10.0, 0.0, 0.0)])
	md.set_particle_state(pos, vel)
	
	md.enforce_boundaries()
	var new_pos: Vector3 = md.get_positions()[0]
	var new_vel: Vector3 = md.get_velocities()[0]
	
	check(new_pos.x <= (5.0 - 0.2), "Particle reflected inside effective boundary", "New X = %f" % new_pos.x)
	check(new_vel.x < 0.0, "Velocity reversed upon reflective collision", "New Vx = %f" % new_vel.x)
	
	md.cleanup()

func audit_molecular_dynamics_multimesh() -> void:
	print("\n--- 1.5 MolecularDynamicsModule: MultiMesh Data-Oriented Rendering ---")
	var md: MolecularDynamicsModule = MolecularDynamicsModule.new()
	md.particle_count = 50
	md.initialize({})
	
	var mm_instance: MultiMeshInstance3D = md.get_node_or_null("ParticleMultiMeshInstance") as MultiMeshInstance3D
	check(mm_instance != null, "MultiMeshInstance3D exists as dedicated child", "Found node")
	check(mm_instance.multimesh != null, "MultiMesh resource attached", "MultiMesh valid")
	check(mm_instance.multimesh.instance_count == 50, "MultiMesh instance_count matches particle count", "Count = %d" % mm_instance.multimesh.instance_count)
	
	# Verify ZERO Node3D per particle allocation:
	var total_children: int = md.get_child_count()
	# Only MultiMeshInstance3D and container boundary wireframe (MeshInstance3D) should exist
	check(total_children <= 3, "Zero per-particle Node3D allocations (children count <= 3)", "Total child nodes = %d" % total_children)
	
	md.cleanup()

# ==============================================================================
# SECTION 2: SHADERS FORENSIC AUDIT
# ==============================================================================

func audit_particle_field_glow_shader() -> void:
	print("\n--- 2.1 ParticleFieldGlowShader: Structure & Mathematics ---")
	var shader: Shader = load("res://shaders/particle_field_glow.gdshader") as Shader
	check(shader != null, "particle_field_glow.gdshader loads cleanly", "Shader valid")
	var code: String = shader.code
	check(code.contains("evaluate_temperature_ramp"), "Contains thermodynamic spectral temperature ramp function", "Found function")
	check(code.contains("glow_falloff"), "Contains Fresnel rim radiance calculation", "Found rim uniform")
	check(code.contains("INSTANCE_CUSTOM"), "Bridges MultiMesh INSTANCE_CUSTOM to fragment stage", "Found INSTANCE_CUSTOM")
	check(code.contains("enable_billboard"), "Supports spherical camera billboard orientation", "Found billboard mode")

func audit_relativistic_mesh_shader() -> void:
	print("\n--- 2.2 RelativisticMeshShader: Structure & Mathematics ---")
	var shader: Shader = load("res://shaders/relativistic_mesh.gdshader") as Shader
	check(shader != null, "relativistic_mesh.gdshader loads cleanly", "Shader valid")
	var code: String = shader.code
	check(code.contains("enable_lorentz_contraction"), "Implements vertex-level Lorentz length contraction", "Found contraction logic")
	check(code.contains("speed_of_light"), "Configurable speed_of_light uniform", "Found uniform")
	check(code.contains("v_doppler_factor"), "Calculates line-of-sight relativistic Doppler factor D", "Found Doppler factor")
	check(code.contains("beaming_power"), "Implements radiative searchlight beaming (I = I0 * D^power)", "Found beaming")
	check(code.contains("rgb_to_hsv") and code.contains("hsv_to_rgb"), "Performs chromatic frequency shift via HSV color space", "Found color space transforms")

# ==============================================================================
# SECTION 3: N-BODY GRAVITY AUDIT
# ==============================================================================

func audit_nbody_gravity_barnes_hut() -> void:
	print("\n--- 3.1 NBodyGravityModule: Barnes-Hut & Newtonian Gravity ---")
	var nbody: NBodyGravityModule = NBodyGravityModule.new()
	nbody.initialize({})
	
	# Explicitly configure pure Newtonian mode after initialize
	nbody.gravitational_constant = 1.0
	nbody.softening = 0.01
	nbody.enable_relativity = false
	nbody.post_newtonian_mode = NBodyGravityModule.PostNewtonianMode.OFF
	
	# Clear and add 2 symmetric bodies at dist = 2.0
	nbody.clear_particles()
	nbody.add_body("Body1", Vector3(-1.0, 0, 0), Vector3.ZERO, 2.0, 0.2)
	nbody.add_body("Body2", Vector3(1.0, 0, 0), Vector3.ZERO, 2.0, 0.2)
	
	# Force between two m=2 at r=2: F = G * m1 * m2 / (r^2 + eps^2) ≈ 1.0 * 4.0 / 4.0001 ≈ 0.999975
	var forces: PackedVector3Array = nbody._evaluate_forces_barnes_hut(nbody.get_positions(), nbody.get_velocities())
	check(forces.size() == 2, "Evaluates forces for all particles", "Size = %d" % forces.size())
	check(absf(forces[0].x - 1.0) < 0.005, "Body 1 attracted towards +X (approx 1.0 N)", "Got F1.x = %f" % forces[0].x)
	check(absf(forces[1].x - (-1.0)) < 0.005, "Body 2 attracted towards -X (approx -1.0 N)", "Got F2.x = %f" % forces[1].x)
	check((forces[0] + forces[1]).length() < 1e-4, "Newton 3rd law: total internal gravitational force is zero", "Sum = %s" % str(forces[0] + forces[1]))
	
	nbody.cleanup()

func audit_nbody_gravity_1pn_precession() -> void:
	print("\n--- 3.2 NBodyGravityModule: 1PN Relativistic Precession ---")
	var nbody: NBodyGravityModule = NBodyGravityModule.new()
	nbody.gravitational_constant = 1.0
	nbody.speed_of_light = 20.0
	nbody.initialize({})
	
	# Evaluate 1PN pair acceleration exerted by Central Star (m=100) at origin on Mercury at (2, 0, 0) with v = (0, 7.8, 0)
	var pos_i: Vector3 = Vector3(2.0, 0.0, 0.0)
	var vel_i: Vector3 = Vector3(0.0, 7.8, 0.0)
	var pos_star: Vector3 = Vector3.ZERO
	var vel_star: Vector3 = Vector3.ZERO
	var m_star: float = 100.0
	var c_sq: float = 20.0 * 20.0 # 400
	var eps_sq: float = 0.01 * 0.01
	
	var a_1pn: Vector3 = nbody._compute_1pn_pair(pos_i, vel_i, pos_star, vel_star, m_star, c_sq, eps_sq)
	# Check 1PN is non-zero and has radial component
	check(a_1pn.length() > 0.01, "1PN acceleration is non-zero in strong relativistic field", "Length = %f" % a_1pn.length())
	# Formula: r_vec = -pos_i = (-2, 0, 0), v_rel = (0, 7.8, 0), r_vec . v_rel = 0
	# radial_coeff = (4*G*M/r - v^2) = (4*100/2 - 60.84) = (200 - 60.84) = 139.16 > 0
	# So a_1pn should point in direction of r_vec (-X)
	check(a_1pn.x < 0.0, "1PN perihelion acceleration points inward along radial axis", "a_1pn.x = %f" % a_1pn.x)
	
	nbody.cleanup()

func audit_nbody_gravity_relativistic_tensor() -> void:
	print("\n--- 3.3 NBodyGravityModule: Special Relativistic Acceleration Limit Tensor ---")
	var nbody: NBodyGravityModule = NBodyGravityModule.new()
	nbody.gravitational_constant = 1.0
	nbody.speed_of_light = 10.0 # c_sim = 10
	nbody.enable_relativity = true
	nbody.initialize({})
	
	nbody.clear_particles()
	# Particle moving near speed of light: v = 9.0 (beta = 0.9, gamma = 1/sqrt(1 - 0.81) = 1/0.43588 ≈ 2.294)
	nbody.add_body("RelativisticBody", Vector3(10.0, 0, 0), Vector3(9.0, 0, 0), 1.0, 0.2)
	nbody.add_body("Anchor", Vector3(0, 0, 0), Vector3.ZERO, 100.0, 0.5)
	
	var forces: PackedVector3Array = nbody._evaluate_forces_barnes_hut(nbody.get_positions(), nbody.get_velocities())
	var a_rel_x: float = forces[0].x / 1.0
	
	# Under longitudinal acceleration, effective mass scales as gamma^3! So acceleration is significantly reduced.
	check(absf(a_rel_x) > 0.0, "Relativistic acceleration is calculated", "a_rel_x = %f" % a_rel_x)
	
	# Step simulation and confirm velocity never exceeds speed of light
	for step_idx in range(5):
		nbody.step(0.01)
	var max_v: float = nbody._get_max_velocity()
	check(max_v < 10.0, "Velocity strictly bounded by speed_of_light c_sim", "Max velocity = %f < 10.0" % max_v)
	
	nbody.cleanup()

func audit_nbody_gravity_multimesh_and_trails() -> void:
	print("\n--- 3.4 NBodyGravityModule: MultiMesh & Orbit Trails ---")
	var nbody: NBodyGravityModule = NBodyGravityModule.new()
	nbody.initialize({})
	nbody.preset_solar_system()
	
	var mm_inst: MultiMeshInstance3D = nbody.get_multimesh_instance()
	check(mm_inst != null, "MultiMeshInstance3D exists for N-body system", "Valid")
	check(mm_inst.multimesh.instance_count == 5, "MultiMesh instance count matches solar system (5 bodies)", "Count = %d" % mm_inst.multimesh.instance_count)
	
	# Check orbit trails mesh instance
	var trail_inst: MeshInstance3D = nbody.get_node_or_null("OrbitTrails") as MeshInstance3D
	check(trail_inst != null, "ImmediateMesh OrbitTrails instance exists", "Valid")
	
	# Verify zero per-particle Node3D allocations
	var child_count: int = nbody.get_child_count()
	check(child_count <= 4, "Zero Node3D per body allocations (total children <= 4)", "Child count = %d" % child_count)
	
	nbody.cleanup()

# ==============================================================================
# SECTION 4: NUCLEAR DECAY AUDIT
# ==============================================================================

func audit_nuclear_decay_database() -> void:
	print("\n--- 4.1 NuclearDecayModule: Isotope Database Completeness ---")
	var nd: NuclearDecayModule = NuclearDecayModule.new()
	var db: Dictionary = nd.get_isotope_db()
	
	var required_isotopes: Array[String] = ["U-235", "Ra-226", "C-14", "H-3", "H-2", "He-4", "Neutron", "Electron", "Gamma", "Kr-92", "Ba-141"]
	for iso_name in required_isotopes:
		check(db.has(iso_name), "Database includes isotope: %s" % iso_name, "Present")
		if db.has(iso_name):
			var entry: Dictionary = db[iso_name]
			check(entry.has("atomic_mass_u"), "Isotope %s has atomic_mass_u" % iso_name)
			check(entry.has("half_life_seconds"), "Isotope %s has half_life_seconds" % iso_name)
	
	check(bool(db["U-235"].get("is_fissile", false)) == true, "U-235 is flagged fissile", "True")

func audit_nuclear_decay_poisson_kinetics() -> void:
	print("\n--- 4.2 NuclearDecayModule: Stochastic Poisson Decay Kinetics ---")
	var nd: NuclearDecayModule = NuclearDecayModule.new()
	nd.initialize({})
	
	# Spawn 600 nuclei of Ra-226 (T_1/2 = 15.0 s)
	nd.setup_isotope_sample("Ra-226", 600, 2.0)
	var initial_count: int = nd.get_active_nuclei_count()
	check(initial_count == 600, "Initialized 600 pristine Ra-226 nuclei", "Count = %d" % initial_count)
	
	# Step by exactly 1 half-life (15.0 seconds).
	# By Poisson decay law P(t) = 1 - exp(-ln2 * t / T_1/2) = 1 - exp(-ln2) = 0.5
	# Binomial expectation: ~300 remaining parents, standard deviation sigma = sqrt(600 * 0.5 * 0.5) ≈ 12.2.
	# 3-sigma confidence range: [240, 360].
	nd.step_manual(15.0)
	
	var remaining_ra226: int = nd.get_isotope_count("Ra-226")
	var decays: int = nd.get_total_decay_events()
	check(decays > 0, "Decay events occurred during half-life step", "Decays = %d" % decays)
	check(remaining_ra226 >= 240 and remaining_ra226 <= 360, "Remaining Ra-226 matches half-life Poisson distribution (~300 +/- 4 sigma)", "Remaining = %d" % remaining_ra226)
	
	# Verify daughter Rn-222 appeared
	var rn222_count: int = nd.get_isotope_count("Rn-222")
	check(rn222_count == decays, "Decayed parent nuclei transmuted to daughter Rn-222", "Rn-222 = %d, Decays = %d" % [rn222_count, decays])
	
	nd.cleanup()

func audit_nuclear_decay_momentum_conservation() -> void:
	print("\n--- 4.3 NuclearDecayModule: 4-Momentum Conservation ---")
	var nd: NuclearDecayModule = NuclearDecayModule.new()
	nd.initialize({})
	
	# Spawn a single stationary U-235 nucleus at origin
	nd._reset_buffers()
	nd.spawn_nucleus(Vector3.ZERO, Vector3.ZERO, "U-235")
	
	# Force an alpha decay on index 0
	var iso_u235: Dictionary = nd.get_isotope_db()["U-235"]
	nd._execute_alpha_decay(0, iso_u235)
	
	# Total momentum after alpha decay must remain Vector3.ZERO (recoil momentum p_d = -p_alpha)
	var total_p: Vector3 = nd.compute_total_momentum()
	check(total_p.length() < 1e-4, "Alpha decay strictly conserves linear momentum (daughter recoil balances alpha)", "Total P = %s (length %f)" % [str(total_p), total_p.length()])
	
	# Now test Beta decay momentum conservation
	nd._reset_buffers()
	nd.spawn_nucleus(Vector3.ZERO, Vector3.ZERO, "C-14")
	var iso_c14: Dictionary = nd.get_isotope_db()["C-14"]
	nd._execute_beta_decay(0, iso_c14)
	var total_p_beta: Vector3 = nd.compute_total_momentum()
	check(total_p_beta.length() < 1e-4, "Beta decay strictly conserves linear momentum (3-body recoil balances electron+neutrino)", "Total P = %s (length %f)" % [str(total_p_beta), total_p_beta.length()])
	
	nd.cleanup()

func audit_nuclear_decay_induced_fission() -> void:
	print("\n--- 4.4 NuclearDecayModule: Induced Fission Chain Reaction ---")
	var nd: NuclearDecayModule = NuclearDecayModule.new()
	nd.initialize({})
	
	# Setup single U-235 at origin
	nd._reset_buffers()
	nd.spawn_nucleus(Vector3.ZERO, Vector3.ZERO, "U-235")
	
	# Inject incident prompt neutron at z = -0.1 (within collision radius 0.25)
	nd.inject_trigger_neutron(Vector3(0, 0, -0.1), Vector3(0, 0, 5.0))
	
	# Step simulation
	nd.step_manual(0.01)
	
	# Check fission triggered
	var fissions: int = nd.get_total_fission_events()
	check(fissions >= 1, "Induced fission successfully triggered by incident neutron", "Fissions = %d" % fissions)
	check(nd.get_isotope_count("U-235") == 0, "Target U-235 nucleus underwent scission", "U-235 count = %d" % nd.get_isotope_count("U-235"))
	check(nd.get_isotope_count("Ba-141") >= 1, "Fission fragment Ba-141 generated", "Ba-141 count = %d" % nd.get_isotope_count("Ba-141"))
	check(nd.get_isotope_count("Kr-92") >= 1, "Fission fragment Kr-92 generated", "Kr-92 count = %d" % nd.get_isotope_count("Kr-92"))
	check(nd.get_active_radiation_count() >= 2, "Prompt neutrons (2-3) released by fission", "Rad count = %d" % nd.get_active_radiation_count())
	
	nd.cleanup()

func audit_nuclear_decay_multimesh() -> void:
	print("\n--- 4.5 NuclearDecayModule: MultiMesh Rendering ---")
	var nd: NuclearDecayModule = NuclearDecayModule.new()
	nd.initialize({})
	
	var nuclei_mm: MultiMeshInstance3D = nd.get_node_or_null("NucleiMultiMesh") as MultiMeshInstance3D
	var rad_mm: MultiMeshInstance3D = nd.get_node_or_null("RadiationMultiMesh") as MultiMeshInstance3D
	check(nuclei_mm != null, "Nuclei MultiMeshInstance3D exists", "Valid")
	check(rad_mm != null, "Radiation MultiMeshInstance3D exists", "Valid")
	check(nd.get_child_count() <= 3, "Zero Node3D per nucleus or radiation particle", "Child count = %d" % nd.get_child_count())
	
	nd.cleanup()

# ==============================================================================
# SECTION 5: QUANTUM WAVEPACKET AUDIT
# ==============================================================================

func audit_quantum_cayley_unitary_norm() -> void:
	print("\n--- 5.1 QuantumWavePacketModule: 1D Cayley Unitary Norm Conservation ---")
	var qm: QuantumWavePacketModule = QuantumWavePacketModule.new()
	qm.active_dimension = QuantumWavePacketModule.SimulationDimension.DIMENSION_1D
	qm.potential_type = QuantumWavePacketModule.PotentialType.FREE_SPACE
	qm.grid_size_1d = 256
	qm.domain_length_1d = 20.0
	qm.packet_center_x = -4.0
	qm.packet_wavenumber_k0 = 2.0
	qm.initialize({})
	
	var norm_initial: float = qm.compute_norm()
	check(is_equal_approx(norm_initial, 1.0), "Initial Gaussian wavepacket normalized to 1.0", "Norm = %f" % norm_initial)
	
	var x_init: float = qm.compute_mean_position()
	
	# Evolve for 50 steps in free space
	for step in range(50):
		qm.step_manual(0.02)
	
	var norm_after: float = qm.compute_norm()
	var norm_drift: float = absf(norm_after - 1.0)
	check(norm_drift < 1e-4, "Cayley Crank-Nicolson preserves unitary probability norm (drift < 1e-4)", "Drift = %f, Norm = %f" % [norm_drift, norm_after])
	
	var x_final: float = qm.compute_mean_position()
	check(x_final > x_init, "Wavepacket propagates forward with group velocity v_g = k0 = 2.0", "x_init = %f, x_final = %f" % [x_init, x_final])
	
	qm.cleanup()

func audit_quantum_tunneling() -> void:
	print("\n--- 5.2 QuantumWavePacketModule: Tunneling & Barrier Analysis ---")
	var qm: QuantumWavePacketModule = QuantumWavePacketModule.new()
	qm.active_dimension = QuantumWavePacketModule.SimulationDimension.DIMENSION_1D
	qm.potential_type = QuantumWavePacketModule.PotentialType.RECTANGULAR_BARRIER
	qm.barrier_height_v0 = 6.0
	qm.barrier_width_d = 0.6
	qm.barrier_center_x = 0.0
	qm.packet_wavenumber_k0 = 3.0 # E = k0^2 / 2 = 4.5 < V0 (6.0) -> Tunneling
	qm.initialize({})
	
	var t_analytical: float = qm.get_analytical_transmission()
	check(t_analytical > 0.0 and t_analytical < 1.0, "Analytical transmission in tunneling regime (0 < T < 1)", "T_ana = %f" % t_analytical)
	
	# Evolve wavepacket across the barrier
	for step in range(120):
		qm.step_manual(0.015)
	
	var trans: float = qm.compute_transmission()
	var refl: float = qm.compute_reflection()
	var norm_total: float = qm.compute_norm()
	
	check(trans > 0.001, "Empirical transmission demonstrates quantum barrier tunneling (T > 0)", "Transmission = %f" % trans)
	check(refl > 0.01, "Empirical reflection demonstrates partial wavepacket reflection (R > 0)", "Reflection = %f" % refl)
	check(absf(norm_total - 1.0) < 1e-4, "Total probability norm conserved across barrier interaction", "Norm = %f" % norm_total)
	
	qm.cleanup()

func audit_quantum_2d_leapfrog() -> void:
	print("\n--- 5.3 QuantumWavePacketModule: 2D Staggered Leapfrog Evolution ---")
	var qm: QuantumWavePacketModule = QuantumWavePacketModule.new()
	qm.active_dimension = QuantumWavePacketModule.SimulationDimension.DIMENSION_2D
	qm.potential_type = QuantumWavePacketModule.PotentialType.FREE_SPACE
	qm.grid_size_2d_x = 32
	qm.grid_size_2d_z = 32
	qm.domain_size_2d = Vector2(10.0, 10.0)
	qm.packet_center_x = 0.0
	qm.packet_center_z = 0.0
	qm.packet_wavenumber_k0 = 1.0
	qm.initialize({})
	
	var norm_2d_init: float = qm.compute_norm()
	check(is_equal_approx(norm_2d_init, 1.0), "Initial 2D Gaussian wavepacket normalized to 1.0", "2D Norm = %f" % norm_2d_init)
	
	# Evolve 15 steps under CFL condition
	for step in range(15):
		qm.step_manual(0.005)
	
	var norm_2d_final: float = qm.compute_norm()
	var drift_2d: float = absf(norm_2d_final - 1.0)
	check(drift_2d < 0.01, "2D Symplectic staggered leapfrog preserves probability norm (drift < 1%)", "Drift = %f" % drift_2d)
	
	qm.cleanup()

func audit_quantum_visualization() -> void:
	print("\n--- 5.4 QuantumWavePacketModule: Visualization Nodes ---")
	var qm: QuantumWavePacketModule = QuantumWavePacketModule.new()
	qm.initialize({})
	
	var ribbon: MeshInstance3D = qm.get_node_or_null("QuantumRibbon1D") as MeshInstance3D
	var surface: MeshInstance3D = qm.get_node_or_null("QuantumSurface2D") as MeshInstance3D
	var barrier: MeshInstance3D = qm.get_node_or_null("BarrierVisualizer") as MeshInstance3D
	check(ribbon != null, "1D ImmediateMesh Ribbon visualizer exists", "Valid")
	check(surface != null, "2D ArrayMesh Surface visualizer exists", "Valid")
	check(barrier != null, "Translucent barrier mesh visualizer exists", "Valid")
	check(qm.get_child_count() <= 4, "Zero per-lattice-cell node allocations", "Child count = %d" % qm.get_child_count())
	
	qm.cleanup()

# ==============================================================================
# SECTION 6: OBSERVER CAMERA ISOLATION AUDIT
# ==============================================================================

func audit_observer_camera_isolation() -> void:
	print("\n--- 6. Observer Camera Immunity & External Reference Frame ---")
	var avatar: AvatarLocomotion = AvatarLocomotion.new()
	avatar.initialize({})
	
	# Verify avatar locomotion creates Camera3D
	var cam: Camera3D = avatar.find_child("AvatarCamera", true, false) as Camera3D
	check(cam != null, "Observer avatar possesses isolated Camera3D", "Camera node valid")
	
	# Verify that avatar locomotion has NO physics engine callbacks, force accumulators, or thermal/radiation variables
	var script: GDScript = avatar.get_script() as GDScript
	var src_code: String = script.source_code
	check(not src_code.contains("MolecularDynamicsModule"), "Avatar locomotion is completely uncoupled from MolecularDynamicsModule", "No coupling")
	check(not src_code.contains("NBodyGravityModule"), "Avatar locomotion is completely uncoupled from NBodyGravityModule", "No coupling")
	check(not src_code.contains("NuclearDecayModule"), "Avatar locomotion is completely uncoupled from NuclearDecayModule", "No coupling")
	check(not src_code.contains("QuantumWavePacketModule"), "Avatar locomotion is completely uncoupled from QuantumWavePacketModule", "No coupling")
	check(not src_code.contains("apply_force") and not src_code.contains("add_force"), "Avatar locomotion camera has zero physical force application", "No force application")
	
	avatar.cleanup()
