extends SceneTree

func _init() -> void:
	print("\n=== [TEST] PHYSICS FEATURES & INTERACTION AUDIT ===")
	var counters: Array[int] = [0, 0] # [passed, failed]
	var assert_fn := func(cond: bool, test_name: String) -> void:
		if cond:
			counters[0] += 1
			print("  [PASS] %s" % test_name)
		else:
			counters[1] += 1
			print("  [FAIL] %s" % test_name)

	# 1. Setup EventBus & Space Layer
	var EventBusScript = load("res://core/event_bus.gd")
	var eb = EventBusScript.new()
	root.add_child(eb)

	var TimeControllerScript = load("res://core/physics/simulation_time_controller.gd")
	var time_ctrl = TimeControllerScript.new()
	root.add_child(time_ctrl)
	time_ctrl.setup(eb)

	var ModuleManagerScript = load("res://core/module_manager.gd")
	var mm = ModuleManagerScript.new()
	root.add_child(mm)
	var wr = Node3D.new()
	root.add_child(wr)
	mm.setup(eb, wr)
	mm.set_physics_context(time_ctrl, null)

	# Mount modules directly
	var GravScript = load("res://modules/physics/n_body_gravity_module.gd")
	var grav_mod = GravScript.new()
	grav_mod.name = "n_body_gravity_module"
	wr.add_child(grav_mod)
	grav_mod.initialize({"event_bus": eb, "module_manager": mm, "world_root": wr, "time_controller": time_ctrl})
	mm._active_modules["n_body_gravity_module"] = grav_mod

	var MDScript = load("res://modules/physics/molecular_dynamics_module.gd")
	var md_mod = MDScript.new()
	md_mod.name = "molecular_dynamics_module"
	wr.add_child(md_mod)
	md_mod.initialize({"event_bus": eb, "module_manager": mm, "world_root": wr, "time_controller": time_ctrl})
	mm._active_modules["molecular_dynamics_module"] = md_mod

	var NucScript = load("res://modules/physics/nuclear_decay_module.gd")
	var nuc_mod = NucScript.new()
	nuc_mod.name = "nuclear_decay_module"
	wr.add_child(nuc_mod)
	nuc_mod.initialize({"event_bus": eb, "module_manager": mm, "world_root": wr, "time_controller": time_ctrl})
	mm._active_modules["nuclear_decay_module"] = nuc_mod

	var QMScript = load("res://modules/physics/quantum_wavepacket_module.gd")
	var qm_mod = QMScript.new()
	qm_mod.name = "quantum_wavepacket_module"
	wr.add_child(qm_mod)
	qm_mod.initialize({"event_bus": eb, "module_manager": mm, "world_root": wr, "time_controller": time_ctrl})
	mm._active_modules["quantum_wavepacket_module"] = qm_mod

	assert_fn.call(grav_mod != null, "NBodyGravityModule loaded successfully")
	assert_fn.call(md_mod != null, "MolecularDynamicsModule loaded successfully")
	assert_fn.call(nuc_mod != null, "NuclearDecayModule loaded successfully")
	assert_fn.call(qm_mod != null, "QuantumWavePacketModule loaded successfully")

	# Interaction Manager
	var InteractionManagerScript = load("res://core/physics/interaction/physics_interaction_manager.gd")
	var im = InteractionManagerScript.new()
	root.add_child(im)
	im.setup(eb, null, mm, time_ctrl, null)

	# Inspector Drawer
	var InspectorScene = load("res://ui/physics/physics_inspector_drawer.tscn")
	var drawer = InspectorScene.instantiate()
	root.add_child(drawer)
	drawer.setup(eb)

	# --- TEST GROUP 1: Inspector Spawning Entities via EventBus ---
	var initial_bodies: int = grav_mod._positions.size()
	print("Initial gravity bodies: ", initial_bodies)

	# Test 1.1: Spawn Star via EventBus command
	eb.publish("physics_spawn_entity", {
		"module_id": "n_body_gravity_module",
		"entity": {"position": Vector3(10, 0, 0), "velocity": Vector3(0, 1, 0), "mass": 200.0, "body_type": "star"}
	})
	assert_fn.call(grav_mod._positions.size() == initial_bodies + 1, "Spawning star increases body count by 1")

	# Test 1.2: Spawn Black Hole
	eb.publish("physics_spawn_entity", {
		"module_id": "n_body_gravity_module",
		"entity": {"position": Vector3(-10, 0, 0), "velocity": Vector3(0, -1, 0), "mass": 500.0, "body_type": "black_hole"}
	})
	assert_fn.call(grav_mod._positions.size() == initial_bodies + 2, "Spawning black hole increases body count by 2")

	# --- TEST GROUP 2: Entity Selection & Inspector Display ---
	# Select the last added body
	var last_body_name: String = grav_mod._body_names[grav_mod._body_names.size() - 1]
	eb.publish("physics_entity_selected", {
		"entity_id": last_body_name,
		"module_id": "n_body_gravity_module",
		"entity": {"mass": 500.0, "velocity": Vector3(0, -1, 0), "energy": 250.0}
	})
	assert_fn.call(drawer.label_entity_name.text.contains(last_body_name), "Inspector displays selected entity name correctly")
	assert_fn.call(drawer.btn_delete_entity.disabled == false, "Delete button enabled when entity selected")

	# --- TEST GROUP 3: Deletion via physics_entity_action ---
	eb.publish("physics_entity_action", {"action": "delete", "entity_id": last_body_name})
	assert_fn.call(grav_mod._positions.size() == initial_bodies + 1, "Delete entity action removes body from NBodyGravityModule")

	# --- TEST GROUP 4: Molecular Dynamics Particle Injection via UI ---
	var initial_particles: int = md_mod.particle_count
	eb.publish("physics_spawn_entity", {
		"module_id": "molecular_dynamics_module",
		"entity": {"position": Vector3.ZERO, "initial_velocity": Vector3(0, 5, 0), "count": 25, "temperature": 1.2}
	})
	assert_fn.call(md_mod.particle_count == initial_particles + 25, "Injecting particles increases MD particle count by 25")

	# --- TEST GROUP 5: Nuclear Decay Module Spawning ---
	var init_nuclei: int = nuc_mod.nuclei_positions.size()
	im.nuclear_selected_isotope = "U-235"
	im._spawn_nuclear_sample(Vector3(1, 1, 1), Vector3.ZERO)
	assert_fn.call(nuc_mod.nuclei_positions.size() == init_nuclei + 1, "Spawning U-235 nucleus adds nucleus to NuclearDecayModule")

	# --- TEST GROUP 6: Quantum Wavepacket k0 Tuning & Double Slit ---
	eb.publish("physics_parameter_changed", {"module_id": "quantum", "param": "wavepacket_k0", "value": 7.5})
	assert_fn.call(is_equal_approx(qm_mod.packet_wavenumber_k0, 7.5), "Parameter wavepacket_k0 updates QuantumWavePacketModule")

	eb.publish("physics_load_preset", {"preset_id": "double_slit"})
	assert_fn.call(qm_mod.active_dimension == 2, "Double slit preset configures dimension 2D (enum 2)")
	assert_fn.call(qm_mod.potential_type == 4, "Double slit preset configures potential type 4")

	# Cleanup
	drawer.queue_free()
	im.queue_free()
	grav_mod.cleanup()
	grav_mod.queue_free()
	md_mod.cleanup()
	md_mod.queue_free()
	nuc_mod.cleanup()
	nuc_mod.queue_free()
	qm_mod.cleanup()
	qm_mod.queue_free()
	mm.queue_free()
	wr.queue_free()
	time_ctrl.queue_free()
	eb.queue_free()

	print("\nPhysics Features Audit: passed=%d, failed=%d" % [counters[0], counters[1]])
	quit(counters[1])
