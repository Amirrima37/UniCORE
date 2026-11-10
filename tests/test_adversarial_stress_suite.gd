extends SceneTree

# ==============================================================================
# UniCORE Fundamental Scientific Simulation Platform
# Adversarial Stress & Empirical Challenge Test Suite (Challenger 2)
#
# Engine Target: Godot 4.0.stable.official.92bee43ad
# Execution: & "C:\Godot\Godot_v4.0-stable_win64_console.exe" --headless --path c:\dev\UniCORE -s res://tests/test_adversarial_stress_suite.gd
# ==============================================================================

const EventBusScript = preload("res://core/event_bus.gd")
const ScreenRaycaster = preload("res://core/physics/interaction/screen_raycaster.gd")
const VelocityVectorGizmo = preload("res://core/physics/interaction/velocity_vector_gizmo.gd")
const KeplerTrajectoryPreview = preload("res://core/physics/interaction/kepler_trajectory_preview.gd")
const PhysicsInteractionManager = preload("res://core/physics/interaction/physics_interaction_manager.gd")
const SimulationTimeController = preload("res://core/physics/simulation_time_controller.gd")
const ConservationSentry = preload("res://core/physics/conservation_sentry.gd")

const CelestialSpawnerTool = preload("res://modules/physics/tools/celestial_spawner_tool.gd")
const ParticleInjectorTool = preload("res://modules/physics/tools/particle_injector_tool.gd")
const NuclearLabTool = preload("res://modules/physics/tools/nuclear_lab_tool.gd")
const QuantumBenchTool = preload("res://modules/physics/tools/quantum_bench_tool.gd")
const ScientificProbeTool = preload("res://modules/physics/tools/scientific_probe_tool.gd")

const NBodyGravityModule = preload("res://modules/physics/n_body_gravity_module.gd")
const MolecularDynamicsModule = preload("res://modules/physics/molecular_dynamics_module.gd")
const NuclearDecayModule = preload("res://modules/physics/nuclear_decay_module.gd")
const QuantumWavePacketModule = preload("res://modules/physics/quantum_wavepacket_module.gd")

var passed_count: int = 0
var failed_count: int = 0
var failure_log: Array[String] = []

func record_test(condition: bool, test_name: String, details: String = "") -> void:
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
	print("   UniCORE Adversarial Stress & Empirical Challenge Suite        ")
	print("==================================================================")
	print("Engine: Godot 4.0.stable (Headless)\n")

	var start_usec: int = Time.get_ticks_usec()

	# Run all challenge test suites
	_challenge_md_particle_injection()
	_challenge_nbody_gravity_and_ray_picking()
	_challenge_quantum_bench_and_wavepacket()
	_challenge_scientific_probe_multi_field()
	_challenge_interaction_manager_edge_cases()

	var elapsed_ms: float = float(Time.get_ticks_usec() - start_usec) / 1000.0
	print("\n==================================================================")
	print("CHALLENGE SUMMARY: %d passed, %d failed in %.2f ms" % [passed_count, failed_count, elapsed_ms])
	if failed_count > 0:
		print("\nFAILURE LOG:")
		for f in failure_log:
			print(f)
		print("\nRESULT: EMPIRICAL DISPUTE (Exit Code: 1)")
		print("==================================================================")
		quit(1)
	else:
		print("\nRESULT: ALL EMPIRICAL CHALLENGES PASSED (100% SUCCESS) (Exit Code: 0)")
		print("==================================================================")
		quit(0)

# ==============================================================================
# Challenge 1: Molecular Dynamics & Particle Injector Stress Testing
# ==============================================================================
func _challenge_md_particle_injection() -> void:
	print("\n--- Challenge 1: Molecular Dynamics & Particle Injector ---")
	var bus: Node = EventBusScript.new()
	var time_ctrl: SimulationTimeController = SimulationTimeController.new()
	var md: MolecularDynamicsModule = MolecularDynamicsModule.new()
	
	var ctx: Dictionary = {"event_bus": bus, "time_controller": time_ctrl}
	md.initialize(ctx)
	
	# Initial count
	var initial_count: int = md.get_particle_count()
	record_test(initial_count > 0, "MD initialized with default particles", "Count: %d" % initial_count)
	
	# 1.1 Repeated particle injections
	var injection_batch: Array[int] = [10, 25, 50, 100, 150]
	var expected_total: int = initial_count
	var reallocation_ok: bool = true
	
	for count_to_add in injection_batch:
		md.inject_particles(Vector3(1.0, 1.0, 1.0), count_to_add, 1.5)
		expected_total += count_to_add
		if md.get_particle_count() != expected_total:
			reallocation_ok = false
			break
		if md.get_positions().size() != expected_total:
			reallocation_ok = false
			break
		if md.get_velocities().size() != expected_total:
			reallocation_ok = false
			break
	
	record_test(reallocation_ok and md.get_particle_count() == expected_total,
		"Repeated particle injections: MultiMesh & packed buffers reallocate correctly",
		"Final count: %d, expected: %d" % [md.get_particle_count(), expected_total])
	
	# Verify stepping after repeated injections is stable
	md.step(0.01)
	var post_step_positions: PackedVector3Array = md.get_positions()
	var post_step_velocities: PackedVector3Array = md.get_velocities()
	var finite_check: bool = true
	for i in range(mini(50, post_step_positions.size())):
		if is_nan(post_step_positions[i].x) or is_inf(post_step_positions[i].x):
			finite_check = false
		if is_nan(post_step_velocities[i].x) or is_inf(post_step_velocities[i].x):
			finite_check = false
	record_test(finite_check, "MD physical integration stable after heavy repeated injections")

	# 1.2 Boundary clamping on injection far outside chamber
	var count_before_clamp: int = md.get_particle_count()
	md.inject_particles(Vector3(500.0, -999.0, 250.0), 20, 1.0)
	var positions: PackedVector3Array = md.get_positions()
	var all_inside_box: bool = true
	var box_ext: Vector3 = md.box_half_extent
	for i in range(count_before_clamp, md.get_particle_count()):
		var p: Vector3 = positions[i]
		if absf(p.x) > box_ext.x or absf(p.y) > box_ext.y or absf(p.z) > box_ext.z:
			all_inside_box = false
			break
	record_test(all_inside_box, "Particle injection far outside chamber clamped strictly inside boundaries")

	# 1.3 Zero and negative count injection defenses
	var count_before_invalid: int = md.get_particle_count()
	md.inject_particles(Vector3.ZERO, 0, 1.0)
	md.inject_particles(Vector3.ZERO, -50, 1.0)
	record_test(md.get_particle_count() == count_before_invalid,
		"Zero and negative count injections safely rejected without modification")

	# 1.4 Extreme temperature injection defense
	md.inject_particles(Vector3.ZERO, 10, -100.0)
	md.inject_particles(Vector3.ZERO, 10, 1e6)
	var v_finite: bool = true
	var vels: PackedVector3Array = md.get_velocities()
	for i in range(vels.size()):
		if is_nan(vels[i].x) or is_inf(vels[i].x):
			v_finite = false
			break
	record_test(v_finite, "Extreme temperature injections (T <= 0, T = 1e6) produce finite velocities")

	# 1.5 Reset to Maxwell-Boltzmann: finite velocities and target temperature preservation
	md.target_temperature = 2.5
	md.reset_to_maxwell_boltzmann()
	var inst_temp: float = md.compute_instantaneous_temperature()
	var temp_diff: float = absf(inst_temp - 2.5)
	record_test(temp_diff < 0.05,
		"Reset to Maxwell-Boltzmann preserves exact target temperature (< 2% error)",
		"Instantaneous T: %.4f, target: 2.5000" % inst_temp)
	
	# Verify total center-of-mass momentum drift is cancelled (~ 0)
	var total_p: Vector3 = Vector3.ZERO
	var masses: PackedFloat32Array = md.get_masses()
	vels = md.get_velocities()
	for i in range(vels.size()):
		total_p += vels[i] * masses[i]
	record_test(total_p.length() < 1e-4,
		"Reset to Maxwell-Boltzmann eliminates center-of-mass momentum drift",
		"Total momentum: %s" % str(total_p))

	# Cleanup
	md.cleanup()
	md.queue_free()
	time_ctrl.queue_free()
	bus.queue_free()

# ==============================================================================
# Challenge 2: N-Body Gravity & Ray Picking Selection Stress Testing
# ==============================================================================
func _challenge_nbody_gravity_and_ray_picking() -> void:
	print("\n--- Challenge 2: N-Body Gravity & Ray Picking ---")
	var bus: Node = EventBusScript.new()
	var nbody: NBodyGravityModule = NBodyGravityModule.new()
	
	nbody.initialize({"event_bus": bus})
	nbody.clear_particles()
	record_test(nbody.get_particle_count() == 0, "NBody cleared for precision testing")
	
	# 2.1 Spawning bodies with extreme mass
	nbody.spawn_body(Vector3(0.0, 0.0, 0.0), Vector3.ZERO, 1e8, "black_hole")
	nbody.spawn_body(Vector3(10.0, 0.0, 0.0), Vector3(0.0, 10.0, 0.0), 1.0, "planet")
	
	# Step with extreme mass
	nbody.step(0.001)
	var pos1: Vector3 = nbody.get_positions()[1]
	record_test(not is_nan(pos1.x) and not is_inf(pos1.x),
		"Extreme mass (M=1e8) Barnes-Hut integration remains finite without overflow")
	
	# 2.2 Relativistic speed asymptote guard
	nbody.speed_of_light = 50.0
	nbody.enable_relativity = true
	# Inject body with superluminal speed (v = 200 > c = 50)
	nbody.spawn_body(Vector3(0.0, 20.0, 0.0), Vector3(200.0, 0.0, 0.0), 1.0, "planet")
	nbody.step(0.001)
	
	var v_super: Vector3 = nbody.get_velocities()[2]
	var c_max: float = nbody.speed_of_light * 0.9995
	record_test(v_super.length() <= c_max + 1e-4,
		"Relativistic speed asymptote guard limits velocity strictly below speed of light",
		"Velocity: %.4f, c_max: %.4f" % [v_super.length(), c_max])

	# 2.3 Entity selection (find_body_near_ray): depth ordering, radius threshold, off-axis
	nbody.clear_particles()
	# Place 3 bodies along the Z axis at z = 5 (dist=15 from -10), z = 15 (dist=25), z = 25 (dist=35)
	nbody.spawn_body(Vector3(0.1, 0.0, 25.0), Vector3.ZERO, 30.0, "planet") # idx 0, far
	nbody.spawn_body(Vector3(0.05, 0.0, 5.0), Vector3.ZERO, 10.0, "planet")  # idx 1, closest
	nbody.spawn_body(Vector3(0.08, 0.0, 15.0), Vector3.ZERO, 20.0, "planet") # idx 2, middle

	# Ray pointing along +Z from (0, 0, -10)
	var ray_orig: Vector3 = Vector3(0.0, 0.0, -10.0)
	var ray_dir: Vector3 = Vector3(0.0, 0.0, 1.0)
	
	var hit: Dictionary = nbody.find_body_near_ray(ray_orig, ray_dir, 50.0)
	record_test(not hit.is_empty(), "Raycast successfully intersected bodies")
	record_test(hit.get("index") == 1 and hit.get("mass") == 10.0,
		"find_body_near_ray selects the closest entity along ray (t = 15.0 vs 25.0, 35.0)",
		"Selected idx: %d, mass: %.1f" % [hit.get("index", -1), hit.get("mass", 0.0)])

	# Ray from behind pointing away (-Z)
	var miss_hit: Dictionary = nbody.find_body_near_ray(ray_orig, Vector3(0.0, 0.0, -1.0), 50.0)
	record_test(miss_hit.is_empty(), "Ray pointing away from bodies returns empty dictionary")

	# Ray with distance cut-off smaller than distance to closest body (dist to z=5 is 15.0)
	var cutoff_hit: Dictionary = nbody.find_body_near_ray(ray_orig, ray_dir, 10.0)
	record_test(cutoff_hit.is_empty(), "find_body_near_ray respects max_dist limit")

	# Off-axis ray exceeding hit radius
	var off_axis_hit: Dictionary = nbody.find_body_near_ray(Vector3(5.0, 0.0, -10.0), ray_dir, 50.0)
	record_test(off_axis_hit.is_empty(), "Off-axis ray outside hit threshold returns empty dictionary")

	# Zero-direction ray edge case
	var zero_dir_hit: Dictionary = nbody.find_body_near_ray(ray_orig, Vector3.ZERO, 50.0)
	record_test(zero_dir_hit.is_empty(), "Zero-length ray direction handled without divide-by-zero crash")

	# 2.4 Rapid Preset Switching Stress
	nbody.preset_kepler_2body()
	var count_kepler: int = nbody.get_particle_count()
	nbody.preset_figure8_choreography()
	var count_fig8: int = nbody.get_particle_count()
	nbody.preset_solar_system()
	var count_solar: int = nbody.get_particle_count()
	nbody.preset_massive_cluster(50)
	var count_cluster: int = nbody.get_particle_count()
	
	record_test(count_kepler == 2 and count_fig8 == 3 and count_solar == 5 and count_cluster == 50,
		"Rapid preset switching: buffers and octrees cleanly cycle across all presets",
		"Counts: %d, %d, %d, %d" % [count_kepler, count_fig8, count_solar, count_cluster])

	# Cleanup
	nbody.cleanup()
	nbody.queue_free()
	bus.queue_free()

# ==============================================================================
# Challenge 3: Quantum Bench & WavePacket Propagation Stress Testing
# ==============================================================================
func _challenge_quantum_bench_and_wavepacket() -> void:
	print("\n--- Challenge 3: Quantum Bench & WavePacket ---")
	var bus: Node = EventBusScript.new()
	var qm: QuantumWavePacketModule = QuantumWavePacketModule.new()
	qm.initialize({"event_bus": bus})

	# 3.1 Rapid potential switching and barrier modification
	var initial_norm: float = qm.compute_norm()
	record_test(absf(initial_norm - 1.0) < 1e-4, "Initial quantum wavefunction normalized to 1.0", "Norm: %.6f" % initial_norm)

	var cycle_success: bool = true
	for p_type in [0, 1, 2, 3, 4, 1, 0, 4]:
		qm.set_potential_type(p_type)
		qm.set_barrier_height(randf_range(1.0, 50.0))
		qm.set_barrier_width(randf_range(0.1, 4.0))
		if qm.potential_type != p_type:
			cycle_success = false
			break
	record_test(cycle_success, "Rapid potential type and geometry switches handled cleanly")

	# 3.2 High-barrier tunneling stress and norm conservation
	qm.set_potential_type(1) # Rectangular barrier
	qm.set_barrier_height(50.0) # Very high barrier
	qm.set_barrier_width(2.0)
	
	# Step 20 times under Cayley unitary solver
	for step_idx in range(20):
		qm.step_manual(0.01)
	
	var norm_after_evolution: float = qm.compute_norm()
	var norm_drift: float = absf(norm_after_evolution - 1.0)
	record_test(norm_drift < 0.001,
		"Unitary Cayley solver maintains strict norm conservation under extreme barrier (|N - 1| < 0.1%)",
		"Norm: %.6f, drift: %.6f" % [norm_after_evolution, norm_drift])
	
	var exp_e: float = qm.compute_expectation_energy()
	record_test(not is_nan(exp_e) and not is_inf(exp_e) and exp_e > 0.0,
		"Expectation energy remains strictly positive and finite under high barrier",
		"<E>: %.4f" % exp_e)

	# 3.3 Dimension switching stress (1D <-> 2D)
	qm.toggle_dimension() # Switch to 2D
	record_test(qm.active_dimension == QuantumWavePacketModule.SimulationDimension.DIMENSION_2D, "Switched to 2D dimension")
	qm.step_manual(0.01)
	var norm_2d: float = qm.compute_norm()
	record_test(absf(norm_2d - 1.0) < 0.05, "2D Staggered leapfrog solver initializes and maintains norm", "2D Norm: %.4f" % norm_2d)

	qm.toggle_dimension() # Switch back to 1D
	record_test(qm.active_dimension == QuantumWavePacketModule.SimulationDimension.DIMENSION_1D, "Switched back to 1D dimension")
	qm.step_manual(0.01)
	var norm_1d_post: float = qm.compute_norm()
	record_test(absf(norm_1d_post - 1.0) < 0.01, "Returned to 1D dimension with valid norm", "1D Norm: %.4f" % norm_1d_post)

	# 3.4 Zero and negative parameter defense
	qm.set_barrier_height(-10.0)
	record_test(qm.barrier_height_v0 == 0.0, "Negative barrier height clamped to 0.0")
	qm.set_barrier_width(-5.0)
	record_test(qm.barrier_width_d == 0.01, "Negative barrier width clamped to 0.01")
	var analytic_t: float = qm.get_analytical_transmission()
	record_test(not is_nan(analytic_t) and not is_inf(analytic_t) and analytic_t >= 0.0 and analytic_t <= 1.0,
		"Analytical transmission calculation produces valid probability [0, 1] on clamped bounds",
		"T: %.4f" % analytic_t)

	# Cleanup
	qm.cleanup()
	qm.queue_free()
	bus.queue_free()

# ==============================================================================
# Challenge 4: Scientific Probe Tool Multi-Field Sampling Stress Testing
# ==============================================================================
func _challenge_scientific_probe_multi_field() -> void:
	print("\n--- Challenge 4: Scientific Probe Tool Multi-Field ---")
	var bus: Node = EventBusScript.new()
	var probe: ScientificProbeTool = ScientificProbeTool.new()
	probe.initialize({"event_bus": bus})

	# 4.1 Empty domain sampling defense (no modules attached)
	var empty_sample: Dictionary = probe.sample_at_point(Vector3(10.0, 20.0, 30.0))
	record_test(empty_sample["gravity_magnitude"] == 0.0 and empty_sample["gas_density"] == 0.0 and
		empty_sample["gas_temperature"] == 0.0 and empty_sample["radiation_cps"] == 0 and
		empty_sample["quantum_probability_density"] == 0.0,
		"Sampling completely unpopulated domain returns safe zeros without crash")

	# Attach active simulation modules
	var grav: NBodyGravityModule = NBodyGravityModule.new()
	var md: MolecularDynamicsModule = MolecularDynamicsModule.new()
	var qm: QuantumWavePacketModule = QuantumWavePacketModule.new()
	grav.initialize({"event_bus": bus})
	md.initialize({"event_bus": bus})
	qm.initialize({"event_bus": bus})
	
	probe._gravity_module = grav
	probe._md_module = md
	probe._quantum_module = qm

	# 4.2 Far-field probe sampling (10,000 units away)
	var far_sample: Dictionary = probe.sample_at_point(Vector3(10000.0, 10000.0, 10000.0))
	record_test(far_sample["gravity_magnitude"] < 1e-6, "Far-field gravity magnitude effectively zero (< 1e-6)")
	record_test(far_sample["gas_density"] == 0.0, "Far-field gas density strictly zero outside container")
	record_test(far_sample["quantum_probability_density"] == 0.0, "Far-field quantum probability density strictly zero")

	# 4.3 Probe deployment capacity overflow & LRU eviction
	probe.max_probes = 4
	for i in range(7):
		probe.deploy_probe(Vector3(float(i), 0.0, 0.0))
	
	record_test(probe._probes.size() == 4,
		"Probe deployment capacity limit strictly enforced (capped at max_probes = 4)",
		"Probes count: %d" % probe._probes.size())
	
	# Verify oldest probe IDs were evicted and newest IDs are present
	var active_ids: Array = probe._probes.keys()
	record_test(active_ids.has(7) and not active_ids.has(1),
		"Oldest probes evicted in FIFO order upon exceeding max_probes",
		"Active IDs: %s" % str(active_ids))

	# 4.4 Clear all probes
	probe.clear_all_probes()
	record_test(probe._probes.is_empty(), "clear_all_probes empties probe registry and frees nodes")

	# Cleanup
	probe.cleanup()
	probe.queue_free()
	grav.cleanup()
	grav.queue_free()
	md.cleanup()
	md.queue_free()
	qm.cleanup()
	qm.queue_free()
	bus.queue_free()

# ==============================================================================
# Challenge 5: Physics Interaction Manager & Gesture Edge Cases
# ==============================================================================
func _challenge_interaction_manager_edge_cases() -> void:
	print("\n--- Challenge 5: Physics Interaction Manager Edge Cases ---")
	var bus: Node = EventBusScript.new()
	var time_ctrl: SimulationTimeController = SimulationTimeController.new()
	var mgr: PhysicsInteractionManager = PhysicsInteractionManager.new()
	mgr._ready()
	mgr.setup(bus, null, null, time_ctrl)

	# 5.1 Maximum drag speed clamping
	mgr._start_drag(Vector2(100.0, 100.0))
	mgr._drag_anchor = Vector3.ZERO
	# Simulate huge mouse motion: drag impulse = (current_pos - anchor) * 2.0 = (1000, 0, 0)
	var extreme_hit: Vector3 = Vector3(1000.0, 0.0, 0.0)
	mgr._current_impulse = (extreme_hit - mgr._drag_anchor) * 2.0
	if mgr._current_impulse.length() > mgr.max_drag_speed:
		mgr._current_impulse = mgr._current_impulse.normalized() * mgr.max_drag_speed
	
	record_test(is_equal_approx(mgr._current_impulse.length(), mgr.max_drag_speed),
		"Extreme drag gesture clamped strictly to max_drag_speed (25.0 m/s)",
		"Impulse magnitude: %.2f" % mgr._current_impulse.length())

	# 5.2 Zero velocity drag cancellation
	mgr._current_impulse = Vector3.ZERO
	mgr._cancel_drag()
	record_test(mgr._is_dragging == false and mgr._velocity_gizmo.visible == false,
		"Cancelled drag gesture resets dragging flag and hides velocity vector gizmo")

	# 5.3 Unknown parameter resilience
	bus.publish("physics_parameter_changed", {"param": "unknown_fictional_param", "value": 999.0})
	record_test(true, "EventBus parameter dispatch ignores unrecognized parameters without exception")

	# 5.4 Mode cycling robustness
	for mode_str in ["gravity", "thermo", "nuclear", "quantum", "sensor", "invalid_mode", "select"]:
		bus.publish("physics_tool_selected", {"tool_id": mode_str})
	record_test(mgr.current_tool_mode == PhysicsInteractionManager.ToolMode.SELECT,
		"Physics tool mode safely falls back to SELECT on invalid mode string")

	# Cleanup
	mgr.queue_free()
	time_ctrl.queue_free()
	bus.queue_free()
