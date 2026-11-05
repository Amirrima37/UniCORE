extends SceneTree

# ==============================================================================
# UniCORE Fundamental Scientific Simulation Platform
# Challenger M3-2 Adversarial Stress & Corner-Case Harness
#
# Target Modules:
#   1. NuclearDecayModule
#   2. QuantumWavePacketModule
# ==============================================================================

const NuclearDecayModule = preload("res://modules/physics/nuclear_decay_module.gd")
const QuantumWavePacketModule = preload("res://modules/physics/quantum_wavepacket_module.gd")
const ConservationSentry = preload("res://core/physics/conservation_sentry.gd")

var total_stress_tests: int = 0
var passed_stress_tests: int = 0
var findings: Array[String] = []

func log_stress(name: String, passed: bool, notes: String = "") -> void:
	total_stress_tests += 1
	if passed:
		passed_stress_tests += 1
		print("  [PASS] %s %s" % [name, ("- " + notes) if notes != "" else ""])
	else:
		findings.append("%s: %s" % [name, notes])
		print("  [WARN/FAIL] %s - %s" % [name, notes])

func _init() -> void:
	print("==================================================================")
	print("   CHALLENGER M3-2 ADVERSARIAL STRESS & CORNER-CASE HARNESS       ")
	print("==================================================================")

	# --------------------------------------------------------------------------
	# TEST 1: Concurrency / Multi-Neutron Same-Frame Collision on Single U-235
	# --------------------------------------------------------------------------
	print("\n--- Stress 1: Multi-Neutron Concurrent Collision on Single Fissile Nucleus ---")
	var nuc1: NuclearDecayModule = NuclearDecayModule.new()
	root.add_child(nuc1)
	nuc1.initialize({})
	nuc1._reset_buffers()
	var u_idx: int = nuc1.spawn_nucleus(Vector3.ZERO, Vector3.ZERO, "U-235")
	# Inject 2 neutrons right at the nucleus within collision radius (0.25)
	nuc1.inject_trigger_neutron(Vector3(0.05, 0.0, 0.0), Vector3(0.0, 0.0, 10.0))
	nuc1.inject_trigger_neutron(Vector3(-0.05, 0.0, 0.0), Vector3(0.0, 0.0, 10.0))
	
	# Step 1 tick
	nuc1.step_manual(0.01)
	var fissions_single_frame: int = nuc1.get_total_fission_events()
	var ba_count: int = nuc1.get_isotope_count("Ba-141")
	var kr_count: int = nuc1.get_isotope_count("Kr-92")
	print("    [Telemetry] Concurrent Collisions: Total Fissions=%d, Ba-141=%d, Kr-92=%d" % [fissions_single_frame, ba_count, kr_count])
	
	# A single nucleus cannot fission twice!
	if fissions_single_frame == 1 and ba_count == 1 and kr_count == 1:
		log_stress("Stress 1: Single nucleus fissions exactly once under multi-neutron strike", true, "1 fission, 1 Ba-141, 1 Kr-92")
	else:
		log_stress("Stress 1: Concurrent collision vulnerability", false, "Expected 1 fission, got %d fissions! Ba=%d, Kr=%d" % [fissions_single_frame, ba_count, kr_count])
	
	nuc1.cleanup()
	root.remove_child(nuc1)
	nuc1.free()

	# --------------------------------------------------------------------------
	# TEST 2: Buffer Saturation & Overflow Resistance (MAX_NUCLEI = 10,000)
	# --------------------------------------------------------------------------
	print("\n--- Stress 2: Buffer Capacity Saturation (MAX_NUCLEI = 10,000) ---")
	var nuc2: NuclearDecayModule = NuclearDecayModule.new()
	root.add_child(nuc2)
	nuc2.initialize({})
	nuc2._reset_buffers()
	
	var overflow_handled_gracefully: bool = true
	var spawned: int = 0
	for i in range(10050):
		var res: int = nuc2.spawn_nucleus(Vector3(i * 0.001, 0, 0), Vector3.ZERO, "He-4")
		if res >= 0:
			spawned += 1
		else:
			if res != -1:
				overflow_handled_gracefully = false
	
	print("    [Telemetry] Saturation test: requested=10050, spawned=%d, max_nuclei=%d" % [spawned, NuclearDecayModule.MAX_NUCLEI])
	var capacity_pass: bool = (spawned == NuclearDecayModule.MAX_NUCLEI and overflow_handled_gracefully)
	log_stress("Stress 2: Buffer overflow protection capped at MAX_NUCLEI", capacity_pass, "Spawned exactly %d" % spawned)
	
	nuc2.cleanup()
	root.remove_child(nuc2)
	nuc2.free()

	# --------------------------------------------------------------------------
	# TEST 3: Quantum 1D Cayley Stability Under Extreme Time Step dt = 0.5 (Large CFL violation for explicit, but Cayley is unconditionally stable)
	# --------------------------------------------------------------------------
	print("\n--- Stress 3: Quantum 1D Cayley Under Huge dt = 0.5 (Unconditional Stability Stress) ---")
	var qm3: QuantumWavePacketModule = QuantumWavePacketModule.new()
	root.add_child(qm3)
	qm3.grid_size_1d = 256
	qm3.domain_length_1d = 20.0
	qm3.initialize({})
	qm3.set_potential_type(QuantumWavePacketModule.PotentialType.RECTANGULAR_BARRIER)
	qm3.set_barrier_height(10.0)
	qm3.initialize_gaussian_wavepacket(-4.0, 0.8, 3.0)
	
	var max_drift_huge_dt: float = 0.0
	var is_nan: bool = false
	for s in range(100):
		qm3.step_manual(0.5) # Extremely large dt
		var cur_n: float = qm3.compute_norm()
		if is_nan(cur_n) or is_inf(cur_n):
			is_nan = true
			break
		var drift: float = absf(cur_n - 1.0)
		if drift > max_drift_huge_dt:
			max_drift_huge_dt = drift
	
	print("    [Telemetry] Huge dt=0.5 (100 steps): Final Norm=%.8f, Max Drift=%.8f, HasNaN=%s" % [qm3.compute_norm(), max_drift_huge_dt, str(is_nan)])
	var cayley_stable: bool = (not is_nan and max_drift_huge_dt < 1e-3)
	log_stress("Stress 3: 1D Cayley unconditionally stable under dt=0.5", cayley_stable, "Max drift: %.8f" % max_drift_huge_dt)
	
	qm3.cleanup()
	root.remove_child(qm3)
	qm3.free()

	# --------------------------------------------------------------------------
	# TEST 4: Quantum Tunneling Zero Barrier Width (d -> 0) & Infinite Barrier Width (d -> inf)
	# --------------------------------------------------------------------------
	print("\n--- Stress 4: Quantum Analytical Formula Boundary Limits (d -> 0, d -> 100) ---")
	var qm4: QuantumWavePacketModule = QuantumWavePacketModule.new()
	root.add_child(qm4)
	qm4.initialize({})
	qm4.set_potential_type(QuantumWavePacketModule.PotentialType.RECTANGULAR_BARRIER)
	qm4.set_barrier_height(8.0)
	
	# Limit 1: d -> 0
	qm4.set_barrier_width(0.0001)
	var t_zero_d: float = qm4.get_analytical_transmission()
	print("    [Telemetry] Analytical T for d=0.0001: T=%.6f (Expected -> 1.0)" % t_zero_d)
	var pass_limit_zero: bool = is_equal_approx(t_zero_d, 1.0)
	log_stress("Stress 4a: Tunneling transmission approaches 1.0 as d -> 0", pass_limit_zero, "T=%.6f" % t_zero_d)
	
	# Limit 2: d -> 50.0 (opaque)
	qm4.set_barrier_width(50.0)
	var t_huge_d: float = qm4.get_analytical_transmission()
	print("    [Telemetry] Analytical T for d=50.0: T=%.12f (Expected -> 0.0)" % t_huge_d)
	var pass_limit_inf: bool = (t_huge_d < 1e-10)
	log_stress("Stress 4b: Tunneling transmission vanishes as d -> inf", pass_limit_inf, "T=%.12f" % t_huge_d)
	
	qm4.cleanup()
	root.remove_child(qm4)
	qm4.free()

	# --------------------------------------------------------------------------
	# TEST 5: 2D Leapfrog CFL Stability Boundary Verification
	# --------------------------------------------------------------------------
	print("\n--- Stress 5: 2D Leapfrog CFL Limit Exploration ---")
	var qm5: QuantumWavePacketModule = QuantumWavePacketModule.new()
	root.add_child(qm5)
	qm5.grid_size_2d_x = 32
	qm5.grid_size_2d_z = 32
	qm5.domain_size_2d = Vector2(8.0, 8.0)
	qm5.active_dimension = QuantumWavePacketModule.SimulationDimension.DIMENSION_2D
	qm5.initialize({})
	qm5.set_potential_type(QuantumWavePacketModule.PotentialType.FREE_SPACE)
	qm5.initialize_2d_gaussian(-1.5, 0.0, 0.6, 2.0, 0.0)
	
	# With dx = dz = 8.0 / 31 = 0.258, CFL requires dt < dx^2 / 2 = 0.033
	# Let's test with stable dt = 0.01 vs unstable dt = 0.1
	var stable_dt: float = 0.01
	for s in range(50):
		qm5.step_manual(stable_dt)
	var norm_stable: float = qm5.compute_norm()
	print("    [Telemetry] 2D at stable dt=0.01 (50 steps): Norm=%.6f" % norm_stable)
	var pass_cfl_stable: bool = absf(norm_stable - 1.0) < 0.02
	log_stress("Stress 5a: 2D Leapfrog stable when dt obeys CFL (dt=0.01)", pass_cfl_stable, "Norm=%.6f" % norm_stable)
	
	# Now push dt into unstable regime dt = 0.1
	var went_unstable: bool = false
	for s in range(50):
		qm5.step_manual(0.1)
		var n_unstable: float = qm5.compute_norm()
		if absf(n_unstable - 1.0) > 0.1 or is_nan(n_unstable):
			went_unstable = true
			break
	print("    [Telemetry] 2D at violating dt=0.1: Instability correctly manifested = %s" % str(went_unstable))
	log_stress("Stress 5b: Explicit 2D leapfrog instability matches theoretical CFL expectation", went_unstable, "Confirmed CFL boundary")
	
	qm5.cleanup()
	root.remove_child(qm5)
	qm5.free()

	# --------------------------------------------------------------------------
	# SUMMARY
	# --------------------------------------------------------------------------
	print("\n==================================================================")
	print("STRESS SUMMARY: Passed %d / %d" % [passed_stress_tests, total_stress_tests])
	print("Findings / Caveats identified: %d" % findings.size())
	for f in findings:
		print("  - NOTE: %s" % f)
	print("==================================================================")
	quit(0 if findings.size() == 0 else 2)
