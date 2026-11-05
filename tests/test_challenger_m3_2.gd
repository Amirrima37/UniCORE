extends SceneTree

# ==============================================================================
# UniCORE Fundamental Scientific Simulation Platform
# Challenger M3-2 Empirical Verification & Adversarial Stress Suite
#
# Target Modules:
#   1. NuclearDecayModule (res://modules/physics/nuclear_decay_module.gd)
#   2. QuantumWavePacketModule (res://modules/physics/quantum_wavepacket_module.gd)
#
# Rules:
#   - Godot 4.0.stable headless execution
#   - NO native assert() — counters and exit codes only
#   - Strict empirical verification: generators, analytical oracles, stress tests
# ==============================================================================

const NuclearDecayModule = preload("res://modules/physics/nuclear_decay_module.gd")
const QuantumWavePacketModule = preload("res://modules/physics/quantum_wavepacket_module.gd")
const SimulationTimeController = preload("res://core/physics/simulation_time_controller.gd")
const ConservationSentry = preload("res://core/physics/conservation_sentry.gd")

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
	print("   CHALLENGER M3-2: NUCLEAR DECAY & QUANTUM TDSE VERIFICATION    ")
	print("==================================================================")
	print("Engine: Godot 4.0.stable (Official Headless)")
	print("Target: Empirical oracles, Noether conservation & TDSE unitarity\n")

	var suite_start_usec: int = Time.get_ticks_usec()

	# --------------------------------------------------------------------------
	# SECTION 1: NUCLEAR DECAY MODULE
	# --------------------------------------------------------------------------
	print("\n>>> SECTION 1: NUCLEAR DECAY & REACTION ENGINE <<<")
	_test_suite_1_exponential_decay_statistics()
	_test_suite_2_alpha_momentum_and_energy_conservation()
	_test_suite_3_beta_and_gamma_decay_kinematics()
	_test_suite_4_induced_fission_and_chain_reaction()
	_test_suite_5_control_rod_absorption()

	# --------------------------------------------------------------------------
	# SECTION 2: QUANTUM WAVEPACKET MODULE
	# --------------------------------------------------------------------------
	print("\n>>> SECTION 2: QUANTUM WAVEPACKET PROPAGATION (TDSE) <<<")
	_test_suite_6_1d_cayley_unconditional_norm_preservation()
	_test_suite_7_quantum_tunneling_rectangular_barrier()
	_test_suite_8_2d_leapfrog_and_double_slit_interference()
	_test_suite_9_boundary_and_corner_stress_cases()

	var duration_ms: float = float(Time.get_ticks_usec() - suite_start_usec) / 1000.0

	print("\n==================================================================")
	print("CHALLENGER M3-2 VERIFICATION SUMMARY")
	print("==================================================================")
	print("Total Passed:   %d" % passed_count)
	print("Total Failed:   %d" % failed_count)
	print("Total Asserts:  %d" % (passed_count + failed_count))
	print("Execution Time: %.2f ms" % duration_ms)

	if failed_count > 0:
		print("\nFAILURES ENCOUNTERED:")
		for f in failure_log:
			print(f)
		print("\nFINAL VERDICT: REQUEST_CHANGES (Exit Code: 1)")
		print("==================================================================")
		quit(1)
	else:
		print("\nFINAL VERDICT: APPROVE — ALL CHALLENGES PASSED (Exit Code: 0)")
		print("==================================================================")
		quit(0)

# ==============================================================================
# SUITE 1: EXPONENTIAL DECAY STATISTICS (N=1,000 NUCLEI ENSEMBLE)
# ==============================================================================
func _test_suite_1_exponential_decay_statistics() -> void:
	print("\n--- Suite 1: Exponential Decay Law N(t) = N0 * exp(-lambda*t) ---")
	
	var mod: NuclearDecayModule = NuclearDecayModule.new()
	root.add_child(mod)
	mod.initialize({})
	
	# Test 1.1: Ra-226 Alpha Decay Ensemble (T1/2 = 15.0 s)
	# Ra-226 decays into Rn-222 (T1/2 = 3.82 s) which decays into Po-218
	seed(42)
	mod.setup_isotope_sample("Ra-226", 1000, 3.0)
	var n0: int = mod.get_isotope_count("Ra-226")
	assert_test(n0 == 1000, "Suite 1.1a: Initial Ra-226 ensemble count is 1000", "Got %d" % n0)
	
	# Step 30 steps with dt = 0.5 s -> total t = 15.0 s (exactly 1 half-life)
	var dt: float = 0.5
	for _i in range(30):
		mod.step_manual(dt)
	
	var n_half1: int = mod.get_isotope_count("Ra-226")
	var n_rn222: int = mod.get_isotope_count("Rn-222")
	var n_po218: int = mod.get_isotope_count("Po-218")
	var total_active1: int = mod.get_active_nuclei_count()
	
	# Analytical expected: N(T1/2) = 1000 * 0.5 = 500
	var expected_1: float = 500.0
	var err_pct_1: float = absf(float(n_half1) - expected_1) / 1000.0 * 100.0
	print("    [Telemetry] Ra-226 at t=15s (1 T_half): Remaining=%d, Rn-222=%d, Po-218=%d, Expected=500, Err=%.2f%%" % [n_half1, n_rn222, n_po218, err_pct_1])
	
	assert_test(err_pct_1 <= 5.0, "Suite 1.1b: Ra-226 remaining matches analytical 500 within +-5%", "Got %d (err: %.2f%%)" % [n_half1, err_pct_1])
	assert_test(n_half1 + n_rn222 + n_po218 == 1000, "Suite 1.1c: Exact nucleon/decay chain conservation (Ra + Rn + Po = 1000)", "Sum=%d" % (n_half1 + n_rn222 + n_po218))
	assert_test(total_active1 == 1000, "Suite 1.1d: Active nuclei count remains 1000", "Got %d" % total_active1)
	
	# Step another 30 steps (total t = 30.0 s, 2 half-lives)
	for _i in range(30):
		mod.step_manual(dt)
	
	var n_half2: int = mod.get_isotope_count("Ra-226")
	var n_rn222_2: int = mod.get_isotope_count("Rn-222")
	var n_po218_2: int = mod.get_isotope_count("Po-218")
	var expected_2: float = 250.0
	var err_pct_2: float = absf(float(n_half2) - expected_2) / 1000.0 * 100.0
	print("    [Telemetry] Ra-226 at t=30s (2 T_half): Remaining=%d, Rn-222=%d, Po-218=%d, Expected=250, Err=%.2f%%" % [n_half2, n_rn222_2, n_po218_2, err_pct_2])
	
	assert_test(err_pct_2 <= 5.0, "Suite 1.1e: Ra-226 at 2 half-lives matches analytical 250 within +-5%", "Got %d (err: %.2f%%)" % [n_half2, err_pct_2])
	assert_test(n_half2 + n_rn222_2 + n_po218_2 == 1000, "Suite 1.1f: Total decay chain sum strictly conserved at t=30s", "Sum=%d" % (n_half2 + n_rn222_2 + n_po218_2))

	# Test 1.2: C-14 Beta-minus Decay Ensemble (T1/2 = 20.0 s, daughter N-14 is STABLE)
	seed(99)
	mod.setup_isotope_sample("C-14", 1000, 3.0)
	for _i in range(40):
		mod.step_manual(dt)
	
	var n_c14: int = mod.get_isotope_count("C-14")
	var n_n14: int = mod.get_isotope_count("N-14")
	var err_c14: float = absf(float(n_c14) - 500.0) / 1000.0 * 100.0
	print("    [Telemetry] C-14 at t=20s (1 T_half): Remaining=%d, Daughter(N-14)=%d, Expected=500, Err=%.2f%%" % [n_c14, n_n14, err_c14])
	
	assert_test(err_c14 <= 5.0, "Suite 1.2a: C-14 beta decay matches analytical 500 within +-5%", "Got %d (err: %.2f%%)" % [n_c14, err_c14])
	assert_test(n_c14 + n_n14 == 1000, "Suite 1.2b: C-14 + N-14 strictly conserved", "Sum=%d" % (n_c14 + n_n14))

	# Test 1.3: Stable Isotope Invariance (He-4 has T1/2 = INF)
	mod.setup_isotope_sample("He-4", 500, 2.0)
	for _i in range(100):
		mod.step_manual(1.0)
	var n_he4: int = mod.get_isotope_count("He-4")
	assert_test(n_he4 == 500, "Suite 1.3: Stable He-4 experiences 0 decays over 100 steps", "Remaining=%d" % n_he4)

	mod.cleanup()
	root.remove_child(mod)
	mod.free()

# ==============================================================================
# SUITE 2: STRICT 4-MOMENTUM & ENERGY CONSERVATION IN ALPHA DECAY
# ==============================================================================
func _test_suite_2_alpha_momentum_and_energy_conservation() -> void:
	print("\n--- Suite 2: Strict 4-Momentum Conservation During Alpha Decay ---")
	
	var mod: NuclearDecayModule = NuclearDecayModule.new()
	root.add_child(mod)
	mod.initialize({})
	
	# Test 2.1: Stationary Parent Nucleus Alpha Decay (p_daughter = -p_alpha)
	mod._reset_buffers()
	var parent_idx: int = mod.spawn_nucleus(Vector3.ZERO, Vector3.ZERO, "Ra-226")
	var iso_p: Dictionary = mod.get_isotope_db()["Ra-226"]
	var m_parent: float = float(iso_p["atomic_mass_u"])
	var m_daughter: float = float(mod.get_isotope_db()["Rn-222"]["atomic_mass_u"])
	var m_alpha: float = float(mod.get_isotope_db()["He-4"]["atomic_mass_u"])
	var c_sim: float = mod.SPEED_OF_LIGHT_SIM
	var q_analytical: float = (m_parent - (m_daughter + m_alpha)) * c_sim * c_sim
	
	mod._execute_alpha_decay(parent_idx, iso_p)
	
	var v_daughter: Vector3 = mod.nuclei_velocities[parent_idx]
	var p_daughter: Vector3 = v_daughter * m_daughter
	var v_alpha: Vector3 = mod.rad_velocities[0]
	var p_alpha: Vector3 = v_alpha * m_alpha
	
	var p_net: Vector3 = p_daughter + p_alpha
	var p_net_mag: float = p_net.length()
	print("    [Telemetry] Alpha Decay (Rest Frame): |p_daughter|=%.6f, |p_alpha|=%.6f, |p_net|=%.8f" % [p_daughter.length(), p_alpha.length(), p_net_mag])
	
	assert_test(p_net_mag < 1e-4, "Suite 2.1a: Net momentum strictly zero in CM frame (|p_net| < 1e-4)", "Mag: %.8f" % p_net_mag)
	
	var dot_dirs: float = v_daughter.normalized().dot(v_alpha.normalized())
	assert_test(is_equal_approx(dot_dirs, -1.0), "Suite 2.1b: Daughter and alpha eject back-to-back (dot = -1.0)", "Dot: %.6f" % dot_dirs)
	
	var ek_d: float = 0.5 * m_daughter * v_daughter.length_squared()
	var ek_a: float = 0.5 * m_alpha * v_alpha.length_squared()
	var ek_total: float = ek_d + ek_a
	var q_err: float = absf(ek_total - q_analytical) / q_analytical
	print("    [Telemetry] Alpha Decay Q-Value: Q_analytic=%.6f, Ek_total=%.6f, RelErr=%.6f" % [q_analytical, ek_total, q_err])
	
	assert_test(q_err < 0.002, "Suite 2.1c: Kinetic energy matches mass-defect Q within 0.2%", "RelErr: %.6f" % q_err)
	
	var ek_ratio: float = ek_a / ek_d
	var mass_ratio: float = m_daughter / m_alpha
	var ratio_err: float = absf(ek_ratio - mass_ratio) / mass_ratio
	print("    [Telemetry] Ek Ratio=%.4f, Mass Ratio=%.4f, RelDiff=%.6f" % [ek_ratio, mass_ratio, ratio_err])
	assert_test(ratio_err < 1e-4, "Suite 2.1d: Ek ratio strictly matches inverse mass ratio MD/Malpha", "Diff: %.6f" % ratio_err)

	# Test 2.2: Relativistic Momentum & Center of Mass Velocity
	# When parent moves with velocity v_P, the mass defect delta_m = M_P - (M_D + M_alpha)
	# carries momentum delta_m * v_P in rest mass accounting.
	# At magnitude 3540, single-precision float32 quantization limit is ~0.00042.
	mod._reset_buffers()
	var initial_v: Vector3 = Vector3(12.5, -8.0, 5.0)
	var p_init: Vector3 = initial_v * m_parent
	var p_idx2: int = mod.spawn_nucleus(Vector3.ZERO, initial_v, "Ra-226")
	mod._execute_alpha_decay(p_idx2, iso_p)
	
	var v_d2: Vector3 = mod.nuclei_velocities[p_idx2]
	var v_a2: Vector3 = mod.rad_velocities[0]
	var p_products: Vector3 = (v_d2 * m_daughter) + (v_a2 * m_alpha)
	var delta_m: float = m_parent - (m_daughter + m_alpha)
	var p_mass_defect: Vector3 = initial_v * delta_m
	var p_total_conserved: Vector3 = p_products + p_mass_defect
	var p_drift: float = (p_total_conserved - p_init).length()
	print("    [Telemetry] Moving Frame Alpha: |p_init|=%.4f, |p_products|=%.4f, |p_defect|=%.4f, |drift|=%.8f" % [p_init.length(), p_products.length(), p_mass_defect.length(), p_drift])
	assert_test(p_drift < 0.0005, "Suite 2.2: 4-momentum strictly conserved within float32 precision", "Drift: %.8f" % p_drift)

	mod.cleanup()
	root.remove_child(mod)
	mod.free()

# ==============================================================================
# SUITE 3: BETA-MINUS & GAMMA DECAY KINEMATICS
# ==============================================================================
func _test_suite_3_beta_and_gamma_decay_kinematics() -> void:
	print("\n--- Suite 3: Beta-Minus & Gamma Decay Recoil Dynamics ---")
	
	var mod: NuclearDecayModule = NuclearDecayModule.new()
	root.add_child(mod)
	mod.initialize({})
	
	# Test 3.1: Beta-Minus Decay Momentum Conservation (3-body recoil)
	mod._reset_buffers()
	var v_parent: Vector3 = Vector3(2.0, 1.0, -1.5)
	var iso_c14: Dictionary = mod.get_isotope_db()["C-14"]
	var c14_idx: int = mod.spawn_nucleus(Vector3.ZERO, v_parent, "C-14")
	mod._execute_beta_decay(c14_idx, iso_c14)
	
	var v_n14: Vector3 = mod.nuclei_velocities[c14_idx]
	assert_test(mod.nuclei_isotope_keys[c14_idx] == "N-14", "Suite 3.1a: C-14 transformed into N-14 daughter", "Got %s" % mod.nuclei_isotope_keys[c14_idx])
	assert_test(mod.rad_types[0] == NuclearDecayModule.RadiationType.BETA, "Suite 3.1b: Radiation type is BETA particle", "Type=%d" % mod.rad_types[0])
	assert_test(v_n14 != v_parent, "Suite 3.1c: Daughter received non-zero recoil kick", "v_n14=%s" % str(v_n14))

	# Test 3.2: Gamma Decay Photon Recoil
	mod._reset_buffers()
	var g_iso: Dictionary = {
		"symbol": "Meta-Nucleus", "name": "Isomer", "z": 50, "a": 100,
		"atomic_mass_u": 100.0, "half_life_seconds": 1.0,
		"decay_channel": NuclearDecayModule.DecayChannel.GAMMA, "daughter_symbol": "Meta-Nucleus",
		"q_value_mev": 2.5, "is_fissile": false
	}
	mod.get_isotope_db()["Meta-Nucleus"] = g_iso
	var g_idx: int = mod.spawn_nucleus(Vector3.ZERO, Vector3.ZERO, "Meta-Nucleus")
	mod._execute_gamma_decay(g_idx, g_iso)
	
	var v_recoil: Vector3 = mod.nuclei_velocities[g_idx]
	var v_gamma: Vector3 = mod.rad_velocities[0]
	assert_test(v_gamma.length() == mod.SPEED_OF_LIGHT_SIM, "Suite 3.2a: Gamma photon propagates at c_sim", "Speed=%.2f" % v_gamma.length())
	assert_test(v_recoil.normalized().dot(v_gamma.normalized()) < -0.999, "Suite 3.2b: Gamma daughter recoils antiparallel to emitted photon", "Dot=%.4f" % v_recoil.normalized().dot(v_gamma.normalized()))

	mod.cleanup()
	root.remove_child(mod)
	mod.free()

# ==============================================================================
# SUITE 4: INDUCED FISSION & CHAIN REACTION DYNAMICS
# ==============================================================================
func _test_suite_4_induced_fission_and_chain_reaction() -> void:
	print("\n--- Suite 4: Induced Fission Chain Reaction (Ba-141, Kr-92, Prompt Neutrons) ---")
	
	var mod: NuclearDecayModule = NuclearDecayModule.new()
	root.add_child(mod)
	mod.initialize({})
	
	# Test 4.1: Single Induced Fission Products and Energy Partitioning
	mod._reset_buffers()
	var u_idx: int = mod.spawn_nucleus(Vector3.ZERO, Vector3.ZERO, "U-235")
	var v_neutron: Vector3 = Vector3(0.0, 0.0, 25.0)
	
	mod._execute_fission(u_idx, v_neutron)
	
	var count_ba: int = mod.get_isotope_count("Ba-141")
	var count_kr: int = mod.get_isotope_count("Kr-92")
	var active_rad: int = mod.get_active_radiation_count()
	
	print("    [Telemetry] Single Fission: Ba-141=%d, Kr-92=%d, Active Rad (prompt neutrons)=%d" % [count_ba, count_kr, active_rad])
	assert_test(count_ba == 1, "Suite 4.1a: Fission generates exactly 1 Ba-141 fragment", "Got %d" % count_ba)
	assert_test(count_kr == 1, "Suite 4.1b: Fission generates exactly 1 Kr-92 fragment", "Got %d" % count_kr)
	assert_test(active_rad >= 2 and active_rad <= 3, "Suite 4.1c: Fission emits 2 or 3 prompt neutrons (mean ~2.43)", "Got %d" % active_rad)
	
	# Total momentum check:
	# Compound nucleus velocity v_compound = (m_n * v_n) / M_compound
	# Fragments and prompt neutrons are ejected symmetrically around v_compound
	var v_ba: Vector3 = mod.nuclei_velocities[u_idx]
	var v_kr: Vector3 = mod.nuclei_velocities[1]
	var m_ba: float = float(mod.get_isotope_db()["Ba-141"]["atomic_mass_u"])
	var m_kr: float = float(mod.get_isotope_db()["Kr-92"]["atomic_mass_u"])
	var m_n: float = float(mod.get_isotope_db()["Neutron"]["atomic_mass_u"])
	var m_u: float = float(mod.get_isotope_db()["U-235"]["atomic_mass_u"])
	var m_comp: float = m_u + m_n
	var v_comp: Vector3 = (v_neutron * m_n) / m_comp
	
	# In compound center of mass, sum of fragment momenta is zero
	var p_frag_cm: Vector3 = (v_ba - v_comp) * m_ba + (v_kr - v_comp) * m_kr
	print("    [Telemetry] Fission Fragment CM Momentum: |p_frag_cm|=%.8f" % p_frag_cm.length())
	assert_test(p_frag_cm.length() < 1e-4, "Suite 4.1d: Fission fragments emitted back-to-back in compound CM frame", "Mag: %.8f" % p_frag_cm.length())

	# Test 4.2: Fission Chain Reaction Cascade in Dense Assembly (control rods out)
	mod.set_control_rod_depth(0.0)
	mod.setup_reactor_core(250, 1.8)
	mod.inject_trigger_neutron(Vector3(0, 0, -2.5), Vector3(0, 0, 20.0))
	
	for _s in range(50):
		mod.step_manual(0.02)
	
	var total_fissions: int = mod.get_total_fission_events()
	var final_neutrons: int = mod.get_active_radiation_count()
	print("    [Telemetry] Chain Reaction (Rods Out): Total Fissions=%d, Active Neutrons=%d" % [total_fissions, final_neutrons])
	assert_test(total_fissions > 1, "Suite 4.2: Multi-generation chain reaction cascade achieved (>1 fissions)", "Fissions=%d" % total_fissions)

	mod.cleanup()
	root.remove_child(mod)
	mod.free()

# ==============================================================================
# SUITE 5: CONTROL ROD NEUTRON ABSORPTION
# ==============================================================================
func _test_suite_5_control_rod_absorption() -> void:
	print("\n--- Suite 5: Control Rod Neutron Absorption & Reactor Quenching ---")
	
	var mod: NuclearDecayModule = NuclearDecayModule.new()
	root.add_child(mod)
	mod.initialize({})
	
	mod.set_control_rod_depth(1.0)
	mod.setup_reactor_core(250, 1.8)
	mod.inject_trigger_neutron(Vector3(0, 0, -2.5), Vector3(0, 0, 20.0))
	
	for _s in range(50):
		mod.step_manual(0.02)
	
	var damped_fissions: int = mod.get_total_fission_events()
	
	# Count active prompt neutrons specifically (distinguishing from background alpha particles)
	var active_neutrons: int = 0
	for r in range(mod.rad_positions.size()):
		if mod.rad_active[r] == 1 and mod.rad_types[r] == NuclearDecayModule.RadiationType.NEUTRON:
			active_neutrons += 1
	
	print("    [Telemetry] Control Rods In (depth=1.0): Total Fissions=%d, Active Prompt Neutrons=%d" % [damped_fissions, active_neutrons])
	
	assert_test(damped_fissions <= 1, "Suite 5.1: Fully inserted control rods suppress runaway chain reaction (fissions <= 1)", "Got %d" % damped_fissions)
	assert_test(active_neutrons == 0, "Suite 5.2: 100% of prompt neutrons absorbed by control rods (active neutrons = 0)", "Got %d" % active_neutrons)

	mod.cleanup()
	root.remove_child(mod)
	mod.free()

# ==============================================================================
# SUITE 6: UNCONDITIONAL NORM PRESERVATION IN 1D CAYLEY SOLVER (TDSE)
# ==============================================================================
func _test_suite_6_1d_cayley_unconditional_norm_preservation() -> void:
	print("\n--- Suite 6: 1D Cayley / Crank-Nicolson Unconditional Norm Preservation ---")
	
	var qm: QuantumWavePacketModule = QuantumWavePacketModule.new()
	root.add_child(qm)
	qm.grid_size_1d = 512
	qm.domain_length_1d = 24.0
	qm.initialize({})
	
	# Test 6.1: Free Space Wavepacket Norm Drift over 500 Steps
	qm.set_potential_type(QuantumWavePacketModule.PotentialType.FREE_SPACE)
	qm.initialize_gaussian_wavepacket(-6.0, 0.8, 3.0)
	
	var initial_norm: float = qm.compute_norm()
	assert_test(is_equal_approx(initial_norm, 1.0), "Suite 6.1a: Initial 1D packet normalized to 1.0", "Norm=%.8f" % initial_norm)
	
	var max_drift_free: float = 0.0
	var dt: float = 0.01
	for step in range(500):
		qm.step_manual(dt)
		var current_n: float = qm.compute_norm()
		var drift: float = absf(current_n - 1.0)
		if drift > max_drift_free:
			max_drift_free = drift
	
	print("    [Telemetry] Free Space 500 Steps: Final Norm=%.8f, Max Relative Norm Drift=%.8f" % [qm.compute_norm(), max_drift_free])
	assert_test(max_drift_free < 1e-4, "Suite 6.1b: Free space norm drift < 1e-4 over 500 steps (unconditional unitarity)", "MaxDrift=%.8f" % max_drift_free)

	# Test 6.2: Rectangular Barrier Wavepacket Norm Drift over 500 Steps
	qm.set_potential_type(QuantumWavePacketModule.PotentialType.RECTANGULAR_BARRIER)
	qm.barrier_height_v0 = 6.0
	qm.barrier_width_d = 0.8
	qm.initialize_gaussian_wavepacket(-6.0, 0.8, 3.0)
	
	var max_drift_barrier: float = 0.0
	for step in range(500):
		qm.step_manual(dt)
		var current_n: float = qm.compute_norm()
		var drift: float = absf(current_n - 1.0)
		if drift > max_drift_barrier:
			max_drift_barrier = drift
	
	print("    [Telemetry] Rectangular Barrier 500 Steps: Final Norm=%.8f, Max Relative Norm Drift=%.8f" % [qm.compute_norm(), max_drift_barrier])
	assert_test(max_drift_barrier < 1e-4, "Suite 6.2: Barrier scattering norm drift < 1e-4 over 500 steps", "MaxDrift=%.8f" % max_drift_barrier)

	# Test 6.3: Harmonic Well Confining Potential over 500 Steps
	qm.set_potential_type(QuantumWavePacketModule.PotentialType.HARMONIC_WELL)
	qm.harmonic_omega = 1.0
	qm.initialize_gaussian_wavepacket(-2.0, 0.6, 0.0)
	
	var max_drift_well: float = 0.0
	for step in range(500):
		qm.step_manual(dt)
		var current_n: float = qm.compute_norm()
		var drift: float = absf(current_n - 1.0)
		if drift > max_drift_well:
			max_drift_well = drift
	
	print("    [Telemetry] Harmonic Well 500 Steps: Final Norm=%.8f, Max Relative Norm Drift=%.8f" % [qm.compute_norm(), max_drift_well])
	assert_test(max_drift_well < 1e-4, "Suite 6.3: Harmonic oscillator norm drift < 1e-4 over 500 steps", "MaxDrift=%.8f" % max_drift_well)

	qm.cleanup()
	root.remove_child(qm)
	qm.free()

# ==============================================================================
# SUITE 7: QUANTUM TUNNELING THROUGH RECTANGULAR POTENTIAL BARRIER
# ==============================================================================
func _test_suite_7_quantum_tunneling_rectangular_barrier() -> void:
	print("\n--- Suite 7: Quantum Tunneling Through Rectangular Barrier (V0 > E) ---")
	
	var qm: QuantumWavePacketModule = QuantumWavePacketModule.new()
	root.add_child(qm)
	qm.grid_size_1d = 512
	qm.domain_length_1d = 24.0
	qm.initialize({})
	
	qm.set_potential_type(QuantumWavePacketModule.PotentialType.RECTANGULAR_BARRIER)
	qm.set_barrier_height(6.0)
	qm.set_barrier_width(0.8)
	qm.initialize_gaussian_wavepacket(-6.0, 0.8, 3.0)
	
	var t_analytical: float = qm.get_analytical_transmission()
	print("    [Telemetry] Analytical Plane-Wave Transmission T_analytical = %.4f" % t_analytical)
	assert_test(t_analytical > 0.16 and t_analytical < 0.19, "Suite 7.1a: Analytical transmission formula matches physical derivation ~0.175", "T=%.4f" % t_analytical)
	
	var dt: float = 0.01
	for _s in range(350):
		qm.step_manual(dt)
	
	var t_emp: float = qm.compute_transmission()
	var r_emp: float = qm.compute_reflection()
	
	# Compute evanescent probability density inside the barrier [x_left, x_right]
	var n: int = qm.grid_size_1d
	var dx: float = qm.domain_length_1d / float(n - 1)
	var x_start: float = -qm.domain_length_1d * 0.5
	var d_half: float = qm.barrier_width_d * 0.5
	var p_inside_barrier: float = 0.0
	for j in range(n):
		var x: float = x_start + float(j) * dx
		if absf(x - qm.barrier_center_x) <= d_half:
			p_inside_barrier += qm.prob_density_1d[j]
	p_inside_barrier *= dx
	
	var total_prob: float = t_emp + r_emp + p_inside_barrier
	print("    [Telemetry] Empirical Tunneling: T_emp = %.4f (%.2f%%), R_emp = %.4f (%.2f%%), P_barrier = %.4f (%.2f%%), Total = %.6f" % [t_emp, t_emp * 100.0, r_emp, r_emp * 100.0, p_inside_barrier, p_inside_barrier * 100.0, total_prob])
	
	assert_test(is_equal_approx(total_prob, 1.0), "Suite 7.1b: Transmission + Reflection + Barrier density strictly equals 1.0", "Total=%.6f" % total_prob)
	assert_test(t_emp >= 0.10 and t_emp <= 0.25, "Suite 7.1c: Empirical wavepacket tunneling matches analytical T within spectral spread", "Got T=%.4f (expected ~0.175)" % t_emp)

	# Test 7.2: Impenetrable Barrier (V0 = 200.0 >> E -> T -> 0, R -> 1)
	qm.set_barrier_height(200.0)
	qm.initialize_gaussian_wavepacket(-6.0, 0.8, 3.0)
	for _s in range(350):
		qm.step_manual(dt)
	
	var t_inf: float = qm.compute_transmission()
	var r_inf: float = qm.compute_reflection()
	print("    [Telemetry] Extreme Barrier (V0=200): T_emp = %.6f, R_emp = %.6f" % [t_inf, r_inf])
	assert_test(t_inf < 0.001, "Suite 7.2a: Extreme barrier produces negligible tunneling (T < 0.001)", "T=%.6f" % t_inf)
	assert_test(r_inf > 0.999, "Suite 7.2b: Extreme barrier exhibits total reflection (R > 0.999)", "R=%.6f" % r_inf)

	# Test 7.3: Free Space Zero Barrier (V0 = 0.0 -> full wavepacket transmission)
	qm.set_barrier_height(0.0)
	qm.initialize_gaussian_wavepacket(-6.0, 0.8, 3.0)
	for _s in range(450):
		qm.step_manual(dt)
	
	var t_zero: float = qm.compute_transmission()
	print("    [Telemetry] Zero Barrier (V0=0, 450 steps): T_emp = %.4f" % t_zero)
	assert_test(t_zero > 0.99, "Suite 7.3: Zero barrier exhibits full transmission (T > 0.99)", "T=%.4f" % t_zero)

	qm.cleanup()
	root.remove_child(qm)
	qm.free()

# ==============================================================================
# SUITE 8: 2D STAGGERED LEAPFROG & DOUBLE-SLIT INTERFERENCE
# ==============================================================================
func _test_suite_8_2d_leapfrog_and_double_slit_interference() -> void:
	print("\n--- Suite 8: 2D Staggered Leapfrog & Double-Slit Quantum Interference ---")
	
	var qm: QuantumWavePacketModule = QuantumWavePacketModule.new()
	root.add_child(qm)
	# Use odd grid dimensions (65x65) for exact center symmetry (z=0 index is 32)
	qm.grid_size_2d_x = 65
	qm.grid_size_2d_z = 65
	qm.domain_size_2d = Vector2(16.0, 16.0)
	qm.active_dimension = QuantumWavePacketModule.SimulationDimension.DIMENSION_2D
	qm.initialize({})
	
	# Test 8.1: 2D Leapfrog Norm Stability (CFL stable dt = 0.005)
	qm.set_potential_type(QuantumWavePacketModule.PotentialType.FREE_SPACE)
	qm.initialize_2d_gaussian(-3.0, 0.0, 0.8, 3.0, 0.0)
	
	var initial_norm_2d: float = qm.compute_norm()
	assert_test(is_equal_approx(initial_norm_2d, 1.0), "Suite 8.1a: 2D wavepacket normalized to 1.0", "Norm=%.6f" % initial_norm_2d)
	
	var dt: float = 0.005
	var max_drift_2d: float = 0.0
	for step in range(200):
		qm.step_manual(dt)
		var n_cur: float = qm.compute_norm()
		var d: float = absf(n_cur - 1.0)
		if d > max_drift_2d:
			max_drift_2d = d
	
	print("    [Telemetry] 2D Leapfrog Free Space 200 Steps: Final Norm=%.6f, Max Drift=%.6f" % [qm.compute_norm(), max_drift_2d])
	assert_test(max_drift_2d < 0.01, "Suite 8.1b: 2D symplectic leapfrog maintains norm stability (< 1%) under CFL", "MaxDrift=%.6f" % max_drift_2d)

	# Test 8.2: Double-Slit Quantum Aperture Transmission & Wave Interference
	qm.set_potential_type(QuantumWavePacketModule.PotentialType.DOUBLE_SLIT)
	qm.barrier_height_v0 = 25.0
	qm.barrier_width_d = 0.8
	qm.slit_width = 0.8
	qm.slit_separation = 2.4
	qm.initialize_2d_gaussian(-3.5, 0.0, 0.7, 4.0, 0.0)
	
	for step in range(200):
		qm.step_manual(dt)
	
	var nx: int = qm.grid_size_2d_x
	var nz: int = qm.grid_size_2d_z
	var dx: float = qm.domain_size_2d.x / float(nx - 1)
	var x_start: float = -qm.domain_size_2d.x * 0.5
	
	# Verify transmission through the double slit into forward half-space (x > 0.4)
	var forward_prob: float = 0.0
	for z in range(nz):
		var row: int = z * nx
		for x in range(nx):
			var x_pos: float = x_start + float(x) * dx
			if x_pos > 0.4:
				forward_prob += qm.prob_density_2d[row + x]
	forward_prob *= (dx * (qm.domain_size_2d.y / float(nz - 1)))
	
	print("    [Telemetry] Double-Slit Forward Transmitted Probability: P(x > 0.4) = %.4f (%.2f%%)" % [forward_prob, forward_prob * 100.0])
	assert_test(forward_prob > 0.05, "Suite 8.2a: Wavepacket transmitted through double slit apertures into forward domain", "P=%.4f" % forward_prob)

	# Sample beam profile along slit apertures (z = +1.2 and z = -1.2)
	# On 65x65 grid with domain [-8, 8], dz = 16.0 / 64 = 0.25. Center index is 32 (z = 0.0).
	# Offset to z = +-1.25 is exactly 5 grid cells (z = +-1.25).
	var slit_x_idx: int = int(round((1.5 - x_start) / dx))
	var center_z_idx: int = 32
	var slit_offset: int = 5
	
	var rho_slit_pos: float = qm.prob_density_2d[(center_z_idx + slit_offset) * nx + slit_x_idx]
	var rho_slit_neg: float = qm.prob_density_2d[(center_z_idx - slit_offset) * nx + slit_x_idx]
	var rho_center: float = qm.prob_density_2d[center_z_idx * nx + slit_x_idx]
	
	print("    [Telemetry] Aperture Beams at x=1.5: rho(slit+)=%.6f, rho(slit-)=%.6f, rho(mid)=%.6f" % [rho_slit_pos, rho_slit_neg, rho_center])
	assert_test(rho_slit_pos > 0.0 and rho_slit_neg > 0.0, "Suite 8.2b: Symmetrical beam emergence through both slits", "pos=%.6f, neg=%.6f" % [rho_slit_pos, rho_slit_neg])
	
	var parity_diff: float = absf(rho_slit_pos - rho_slit_neg) / maxf(1e-9, rho_slit_pos)
	print("    [Telemetry] Bilateral Parity Symmetry Difference: %.4f%%" % (parity_diff * 100.0))
	assert_test(parity_diff < 0.05, "Suite 8.2c: Bilateral parity symmetry preserved across slits (< 5% diff)", "diff=%.4f" % parity_diff)

	qm.cleanup()
	root.remove_child(qm)
	qm.free()

# ==============================================================================
# SUITE 9: BOUNDARY, SENTRY AUDIT & ADVERSARIAL EDGE CASES
# ==============================================================================
func _test_suite_9_boundary_and_corner_stress_cases() -> void:
	print("\n--- Suite 9: Robustness, Sentry Audit & Corner Stress Cases ---")
	
	# Test 9.1: Zero and Negative dt Invariance
	var qm: QuantumWavePacketModule = QuantumWavePacketModule.new()
	root.add_child(qm)
	qm.initialize({})
	var norm_before: float = qm.compute_norm()
	qm.step_manual(0.0)
	qm.step_manual(-0.1)
	var norm_after: float = qm.compute_norm()
	assert_test(is_equal_approx(norm_before, norm_after), "Suite 9.1: Zero and negative dt step does not alter quantum state", "Before=%.6f, After=%.6f" % [norm_before, norm_after])
	qm.cleanup()
	root.remove_child(qm)
	qm.free()

	# Test 9.2: Nuclear Decay Module Zero dt Invariance
	var nuc: NuclearDecayModule = NuclearDecayModule.new()
	root.add_child(nuc)
	nuc.initialize({})
	var n_before: int = nuc.get_active_nuclei_count()
	nuc.step_manual(0.0)
	nuc.step_manual(-1.0)
	var n_after: int = nuc.get_active_nuclei_count()
	assert_test(n_before == n_after, "Suite 9.2: Zero/negative dt does not trigger spurious nuclear decays", "Count=%d" % n_after)

	# Test 9.3: Conservation Sentry Integration
	var sentry: ConservationSentry = ConservationSentry.new()
	var warnings_emitted: Array[String] = []
	sentry.conservation_warning.connect(func(inv_name: String, _drift: float):
		warnings_emitted.append(inv_name)
	)
	
	var ctx: Dictionary = {"conservation_sentry": sentry}
	var qm_sentry: QuantumWavePacketModule = QuantumWavePacketModule.new()
	root.add_child(qm_sentry)
	qm_sentry.initialize(ctx)
	
	# Artificially scale wavepacket to trigger sentry warning
	for i in range(qm_sentry.psi_real_1d.size()):
		qm_sentry.psi_real_1d[i] *= 1.5
	qm_sentry._update_prob_density_1d()
	qm_sentry.step_manual(0.15)
	
	assert_test(warnings_emitted.has("quantum_norm"), "Suite 9.3: ConservationSentry fires warning on perturbed quantum norm", "Warnings: %s" % str(warnings_emitted))

	qm_sentry.cleanup()
	root.remove_child(qm_sentry)
	qm_sentry.free()
	nuc.cleanup()
	root.remove_child(nuc)
	nuc.free()
