extends SceneTree

# ==============================================================================
# UniCORE Fundamental Scientific Simulation Platform
# Interactive Physics Layer & Tools Automated Headless Test Suite
#
# Engine Target: Godot 4.0.stable.official.92bee43ad
# Execution: & "C:\Godot\Godot_v4.0-stable_win64_console.exe" --headless --path c:\dev\UniCORE -s res://tests/test_physics_interaction_suite.gd
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
	print("   UniCORE Interactive Physics & Toolset: Headless Test Suite    ")
	print("==================================================================")
	print("Engine: Godot 4.0.stable (Headless)\n")

	var start_usec: int = Time.get_ticks_usec()

	# 1. ScreenRaycaster Math Tests
	_test_screen_raycaster()

	# 2. VelocityVectorGizmo Tests
	_test_velocity_vector_gizmo()

	# 3. KeplerTrajectoryPreview Tests
	_test_kepler_trajectory_preview()

	# 4. PhysicsInteractionManager Tests
	_test_physics_interaction_manager()

	# 5. Domain Interactive Tools Tests
	_test_celestial_spawner_tool()
	_test_particle_injector_tool()
	_test_nuclear_lab_tool()
	_test_quantum_bench_tool()
	_test_scientific_probe_tool()

	# 6. End-to-End Cross-Module Interaction Integration Test
	_test_e2e_interaction_pipeline()

	var elapsed_ms: float = float(Time.get_ticks_usec() - start_usec) / 1000.0
	print("\n==================================================================")
	print("SUMMARY: %d passed, %d failed in %.2f ms" % [passed_count, failed_count, elapsed_ms])
	if failed_count > 0:
		print("\nFAILURE LOG:")
		for f in failure_log:
			print(f)
		print("\nRESULT: FAILED (Exit Code: 1)")
		print("==================================================================")
		quit(1)
	else:
		print("\nRESULT: ALL INTERACTION TESTS PASSED (100% SUCCESS) (Exit Code: 0)")
		print("==================================================================")
		quit(0)

# ==============================================================================
# 1. ScreenRaycaster Tests
# ==============================================================================
func _test_screen_raycaster() -> void:
	print("\n--- 1. ScreenRaycaster Math Tests ---")
	
	# Ray from origin along -Z
	var ro: Vector3 = Vector3(0.0, 0.0, 10.0)
	var rd: Vector3 = Vector3(0.0, 0.0, -1.0)
	
	# Plane at Z = 0 facing +Z (normal = (0, 0, 1), d = 0)
	var hit: Variant = ScreenRaycaster.ray_plane_intersection(ro, rd, Vector3(0.0, 0.0, 1.0), 0.0)
	assert_test(hit != null and (hit as Vector3).is_equal_approx(Vector3(0.0, 0.0, 0.0)),
		"Ray intersects XY plane at origin", "Hit: %s" % str(hit))
	
	# Plane at Y = 2 facing +Y (normal = (0, 1, 0), d = 2)
	# Ray angled down
	var ro2: Vector3 = Vector3(0.0, 10.0, 0.0)
	var rd2: Vector3 = Vector3(0.0, -1.0, 0.0)
	var hit2: Variant = ScreenRaycaster.ray_plane_intersection(ro2, rd2, Vector3(0.0, 1.0, 0.0), 2.0)
	assert_test(hit2 != null and (hit2 as Vector3).is_equal_approx(Vector3(0.0, 2.0, 0.0)),
		"Ray intersects horizontal plane at Y=2", "Hit: %s" % str(hit2))
	
	# Parallel ray: normal = (0, 1, 0), rd = (1, 0, 0)
	var hit_parallel: Variant = ScreenRaycaster.ray_plane_intersection(Vector3.ZERO, Vector3(1.0, 0.0, 0.0), Vector3(0.0, 1.0, 0.0), 5.0)
	assert_test(hit_parallel == null, "Parallel ray returns null (no intersection)")
	
	# Ray pointing away from plane (negative t)
	var hit_behind: Variant = ScreenRaycaster.ray_plane_intersection(Vector3(0.0, 0.0, 5.0), Vector3(0.0, 0.0, 1.0), Vector3(0.0, 0.0, 1.0), 0.0)
	assert_test(hit_behind == null, "Ray pointing away from plane returns null")

# ==============================================================================
# 2. VelocityVectorGizmo Tests
# ==============================================================================
func _test_velocity_vector_gizmo() -> void:
	print("\n--- 2. VelocityVectorGizmo Tests ---")
	var gizmo: VelocityVectorGizmo = VelocityVectorGizmo.new()
	gizmo._ready()
	
	assert_test(gizmo.visible == false, "Gizmo initially invisible")
	
	gizmo.set_vector(Vector3(0.0, 1.0, 0.0), Vector3(5.0, 0.0, 0.0), 25.0)
	assert_test(gizmo.visible == true, "Gizmo visible after set_vector")
	assert_test(gizmo.position.is_equal_approx(Vector3(0.0, 1.0, 0.0)), "Gizmo positioned at anchor")
	
	# Zero velocity should auto-hide gizmo
	gizmo.set_vector(Vector3.ZERO, Vector3.ZERO)
	assert_test(gizmo.visible == false, "Zero velocity hides gizmo")
	
	gizmo.queue_free()

# ==============================================================================
# 3. KeplerTrajectoryPreview Tests
# ==============================================================================
func _test_kepler_trajectory_preview() -> void:
	print("\n--- 3. KeplerTrajectoryPreview Tests ---")
	var preview: KeplerTrajectoryPreview = KeplerTrajectoryPreview.new()
	preview._ready()
	
	# Update circular orbit around origin with mu = 1000, r = 10, v = sqrt(1000/10) = 10
	var pos: Vector3 = Vector3(10.0, 0.0, 0.0)
	var vel: Vector3 = Vector3(0.0, 0.0, 10.0)
	preview.update_orbit(Vector3.ZERO, pos, vel, 1000.0)
	
	assert_test(preview.visible == true, "Preview visible when orbit updated")
	
	preview.clear_orbit()
	assert_test(preview.visible == false, "clear_orbit hides preview")
	
	preview.queue_free()

# ==============================================================================
# 4. PhysicsInteractionManager Tests
# ==============================================================================
func _test_physics_interaction_manager() -> void:
	print("\n--- 4. PhysicsInteractionManager Tests ---")
	var bus: Node = EventBusScript.new()
	var time_ctrl: SimulationTimeController = SimulationTimeController.new()
	var sentry: ConservationSentry = ConservationSentry.new()
	sentry.setup(bus)
	
	var mgr: PhysicsInteractionManager = PhysicsInteractionManager.new()
	mgr._ready()
	mgr.setup(bus, null, null, time_ctrl, sentry)
	
	# Test tool switching via event bus
	bus.publish("physics_tool_selected", {"tool_id": "gravity"})
	assert_test(mgr.current_tool_mode == PhysicsInteractionManager.ToolMode.GRAVITY, "Tool mode switched to GRAVITY")
	
	bus.publish("physics_tool_selected", {"tool_id": "thermo"})
	assert_test(mgr.current_tool_mode == PhysicsInteractionManager.ToolMode.THERMODYNAMICS, "Tool mode switched to THERMODYNAMICS")
	
	bus.publish("physics_tool_selected", {"tool_id": "nuclear"})
	assert_test(mgr.current_tool_mode == PhysicsInteractionManager.ToolMode.NUCLEAR, "Tool mode switched to NUCLEAR")
	
	bus.publish("physics_tool_selected", {"tool_id": "quantum"})
	assert_test(mgr.current_tool_mode == PhysicsInteractionManager.ToolMode.QUANTUM, "Tool mode switched to QUANTUM")
	
	bus.publish("physics_tool_selected", {"tool_id": "sensor"})
	assert_test(mgr.current_tool_mode == PhysicsInteractionManager.ToolMode.SENSOR, "Tool mode switched to SENSOR")
	
	# Test time commands via event bus
	bus.publish("physics_time_command", {"command": "set_paused", "value": true})
	assert_test(time_ctrl.is_paused == true, "Time command paused time controller")
	
	bus.publish("physics_time_command", {"command": "set_time_scale", "value": 2.5})
	assert_test(is_equal_approx(time_ctrl.time_scale, 2.5), "Time command updated time scale to 2.5")
	
	# Test parameter change via event bus
	bus.publish("physics_parameter_changed", {"param": "gravity_mass", "value": 500.0})
	assert_test(is_equal_approx(mgr.gravity_spawn_mass, 500.0), "Parameter change updated gravity_spawn_mass to 500.0")
	
	# Test tool execution signals
	var spawned_received: Array = []
	mgr.entity_spawned.connect(func(mod_id: String, data: Dictionary) -> void:
		spawned_received.append({"mod_id": mod_id, "data": data})
	)
	
	mgr._spawn_celestial_body(Vector3(1.0, 2.0, 3.0), Vector3(4.0, 0.0, 0.0))
	assert_test(spawned_received.size() == 1, "Celestial body spawn emitted entity_spawned")
	assert_test(spawned_received[0]["mod_id"] == "n_body_gravity_module", "Module ID is n_body_gravity_module")
	assert_test(spawned_received[0]["data"]["mass"] == 500.0, "Mass passed correctly")
	
	mgr.queue_free()
	time_ctrl.queue_free()
	sentry.queue_free()
	bus.queue_free()

# ==============================================================================
# 5. Domain Interactive Tools Tests
# ==============================================================================
func _test_celestial_spawner_tool() -> void:
	print("\n--- 5a. CelestialSpawnerTool Tests ---")
	var tool: CelestialSpawnerTool = CelestialSpawnerTool.new()
	assert_test(tool.get_module_id() == "celestial_spawner_tool", "Tool ID is celestial_spawner_tool")
	assert_test(tool.get_action_bindings().size() >= 3, "Action bindings registered")
	
	var bus: Node = EventBusScript.new()
	tool.initialize({"event_bus": bus})
	
	var emitted: Array = []
	tool.body_spawned_into_gravity.connect(func(p: Vector3, v: Vector3, m: float, t: String) -> void:
		emitted.append({"pos": p, "vel": v, "mass": m, "type": t})
	)
	
	tool.spawn_body(Vector3(10.0, 0.0, 0.0), Vector3(0.0, 5.0, 0.0), 100.0, "planet")
	assert_test(emitted.size() == 1, "body_spawned_into_gravity signal emitted")
	assert_test(emitted[0]["mass"] == 100.0 and emitted[0]["type"] == "planet", "Parameters matched")
	
	tool.cleanup()
	tool.queue_free()
	bus.queue_free()

func _test_particle_injector_tool() -> void:
	print("\n--- 5b. ParticleInjectorTool Tests ---")
	var tool: ParticleInjectorTool = ParticleInjectorTool.new()
	assert_test(tool.get_module_id() == "particle_injector_tool", "Tool ID is particle_injector_tool")
	assert_test(tool.get_action_bindings().size() >= 3, "Action bindings registered")
	
	var bus: Node = EventBusScript.new()
	tool.initialize({"event_bus": bus})
	
	var injected: Array = []
	tool.gas_injected.connect(func(pos: Vector3, count: int, temp: float) -> void:
		injected.append({"pos": pos, "count": count, "temp": temp})
	)
	
	tool.inject_molecules(Vector3(0.0, 1.0, 0.0), 100, 1.5)
	assert_test(injected.size() == 1, "gas_injected signal emitted")
	assert_test(injected[0]["count"] == 100 and injected[0]["temp"] == 1.5, "Injection params matched")
	
	tool.cleanup()
	tool.queue_free()
	bus.queue_free()

func _test_nuclear_lab_tool() -> void:
	print("\n--- 5c. NuclearLabTool Tests ---")
	var tool: NuclearLabTool = NuclearLabTool.new()
	assert_test(tool.get_module_id() == "nuclear_lab_tool", "Tool ID is nuclear_lab_tool")
	assert_test(tool.get_action_bindings().size() >= 4, "Action bindings registered")
	
	var bus: Node = EventBusScript.new()
	tool.initialize({"event_bus": bus})
	
	var fired: Array = []
	tool.neutron_fired.connect(func(p: Vector3, v: Vector3) -> void:
		fired.append({"pos": p, "vel": v})
	)
	
	tool.fire_neutron(Vector3(0.0, 0.0, -5.0), Vector3(0.0, 0.0, 25.0))
	assert_test(fired.size() == 1, "neutron_fired signal emitted")
	assert_test(fired[0]["vel"].is_equal_approx(Vector3(0.0, 0.0, 25.0)), "Neutron velocity matches")
	
	var rods_changed: Array = []
	tool.control_rods_adjusted.connect(func(d: float) -> void:
		rods_changed.append(d)
	)
	
	tool.set_control_rods(0.45)
	assert_test(rods_changed.size() == 1 and is_equal_approx(rods_changed[0], 0.45), "Control rods depth adjusted to 0.45")
	
	tool.cleanup()
	tool.queue_free()
	bus.queue_free()

func _test_quantum_bench_tool() -> void:
	print("\n--- 5d. QuantumBenchTool Tests ---")
	var tool: QuantumBenchTool = QuantumBenchTool.new()
	assert_test(tool.get_module_id() == "quantum_bench_tool", "Tool ID is quantum_bench_tool")
	assert_test(tool.get_action_bindings().size() >= 4, "Action bindings registered")
	
	var bus: Node = EventBusScript.new()
	tool.initialize({"event_bus": bus})
	
	var injected: Array = []
	tool.wavepacket_injected.connect(func(c: Vector3, k: float) -> void:
		injected.append({"center": c, "k0": k})
	)
	
	tool.inject_wavepacket(Vector3(-5.0, 0.0, 0.0), 3.5)
	assert_test(injected.size() == 1, "wavepacket_injected signal emitted")
	assert_test(is_equal_approx(injected[0]["k0"], 3.5), "Wavepacket wavenumber matched")
	
	tool.cleanup()
	tool.queue_free()
	bus.queue_free()

func _test_scientific_probe_tool() -> void:
	print("\n--- 5e. ScientificProbeTool Tests ---")
	var tool: ScientificProbeTool = ScientificProbeTool.new()
	assert_test(tool.get_module_id() == "scientific_probe_tool", "Tool ID is scientific_probe_tool")
	assert_test(tool.get_action_bindings().size() >= 2, "Action bindings registered")
	
	var bus: Node = EventBusScript.new()
	tool.initialize({"event_bus": bus})
	
	var p_id: int = tool.deploy_probe(Vector3(1.0, 2.0, 3.0))
	assert_test(p_id > 0, "Probe deployed with valid id")
	assert_test(tool._probes.size() == 1, "Probe stored in probe map")
	
	var sampled: Dictionary = tool.sample_at_point(Vector3(1.0, 2.0, 3.0))
	assert_test(sampled.has("gravity_vector"), "Telemetry contains gravity_vector")
	assert_test(sampled.has("gas_density"), "Telemetry contains gas_density")
	assert_test(sampled.has("gas_temperature"), "Telemetry contains gas_temperature")
	assert_test(sampled.has("radiation_cps"), "Telemetry contains radiation_cps")
	assert_test(sampled.has("quantum_probability_density"), "Telemetry contains quantum_probability_density")
	
	tool.remove_probe(p_id)
	assert_test(tool._probes.size() == 0, "Probe removed successfully")
	
	tool.cleanup()
	tool.queue_free()
	bus.queue_free()

# ==============================================================================
# 6. End-to-End Cross-Module Pipeline Integration
# ==============================================================================
func _test_e2e_interaction_pipeline() -> void:
	print("\n--- 6. E2E Cross-Module Interaction Pipeline ---")
	var bus: Node = EventBusScript.new()
	var time_ctrl: SimulationTimeController = SimulationTimeController.new()
	var sentry: ConservationSentry = ConservationSentry.new()
	sentry.setup(bus)
	
	# Instantiate domain modules
	var grav_mod: NBodyGravityModule = NBodyGravityModule.new()
	var md_mod: MolecularDynamicsModule = MolecularDynamicsModule.new()
	var nuc_mod: NuclearDecayModule = NuclearDecayModule.new()
	var qm_mod: QuantumWavePacketModule = QuantumWavePacketModule.new()
	
	var context: Dictionary = {
		"event_bus": bus,
		"time_controller": time_ctrl,
		"conservation_sentry": sentry
	}
	
	grav_mod.initialize(context)
	md_mod.initialize(context)
	nuc_mod.initialize(context)
	qm_mod.initialize(context)
	
	# Instantiate probe tool
	var probe_tool: ScientificProbeTool = ScientificProbeTool.new()
	probe_tool.initialize(context)
	probe_tool._gravity_module = grav_mod
	probe_tool._md_module = md_mod
	probe_tool._nuclear_module = nuc_mod
	probe_tool._quantum_module = qm_mod
	
	# Add a mass to gravity module
	grav_mod.add_body("CentralStar", Vector3(0.0, 0.0, 0.0), Vector3.ZERO, 1000.0)
	
	# Deploy probe at (5, 0, 0)
	var p_id: int = probe_tool.deploy_probe(Vector3(5.0, 0.0, 0.0))
	assert_test(p_id > 0, "Probe deployed into active simulation domain")
	
	# Sample telemetry: gravity field should point towards (0, 0, 0), i.e. delta_r = (0,0,0) - (5,0,0) = (-5,0,0)
	var telemetry: Dictionary = probe_tool.sample_at_point(Vector3(5.0, 0.0, 0.0))
	var g_vec: Vector3 = telemetry["gravity_vector"]
	assert_test(g_vec.x < -1e-4, "Probe detected negative gravitational acceleration towards origin", "g_vec: %s" % str(g_vec))
	assert_test(telemetry["gravity_magnitude"] > 0.0, "Non-zero gravity magnitude measured")
	
	# Test gas measurement
	md_mod.inject_particles(Vector3(5.0, 0.0, 0.0), 30, 2.0)
	var gas_telemetry: Dictionary = probe_tool.sample_at_point(Vector3(5.0, 0.0, 0.0))
	assert_test(gas_telemetry["gas_density"] > 0.0, "Probe measured positive gas density near injection", "Density: %.4f" % gas_telemetry["gas_density"])
	
	# Test spawn_body and ray picking in NBodyGravityModule
	grav_mod.spawn_body(Vector3(12.0, 0.0, 0.0), Vector3(0.0, 2.0, 0.0), 5.0, "planet")
	var ray_hit: Dictionary = grav_mod.find_body_near_ray(Vector3(12.0, 10.0, 0.0), Vector3(0.0, -1.0, 0.0))
	assert_test(not ray_hit.is_empty(), "find_body_near_ray located spawned body")
	assert_test(ray_hit.get("mass", 0.0) == 5.0, "Ray picked entity has mass 5.0")

	# Test reset_to_maxwell_boltzmann in MolecularDynamicsModule
	md_mod.reset_to_maxwell_boltzmann()
	assert_test(md_mod.get_particle_count() > 0, "MD particles maintained after Maxwell reset")

	# Test QuantumWavePacketModule public setters
	qm_mod.set_potential_type(1)
	assert_test(qm_mod.potential_type == 1, "Quantum potential_type set to 1 (Rectangular Barrier)")
	qm_mod.set_barrier_height(8.0)
	assert_test(is_equal_approx(qm_mod.barrier_height_v0, 8.0), "Barrier height set to 8.0")
	qm_mod.set_barrier_width(1.5)
	assert_test(is_equal_approx(qm_mod.barrier_width_d, 1.5), "Barrier width set to 1.5")
	qm_mod.cycle_potential_type()
	assert_test(qm_mod.potential_type == 2, "Quantum potential cycled to 2 (Harmonic Well)")
	qm_mod.toggle_dimension()
	assert_test(qm_mod.active_dimension == 2, "Quantum active dimension toggled to 2D")

	
	# Cleanup
	probe_tool.cleanup()
	probe_tool.queue_free()
	grav_mod.cleanup()
	grav_mod.queue_free()
	md_mod.cleanup()
	md_mod.queue_free()
	nuc_mod.cleanup()
	nuc_mod.queue_free()
	qm_mod.cleanup()
	qm_mod.queue_free()
	sentry.queue_free()
	time_ctrl.queue_free()
	bus.queue_free()
	print("  E2E interaction pipeline completed cleanly.")
