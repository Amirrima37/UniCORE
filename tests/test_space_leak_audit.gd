extends SceneTree

# Memory Leak & Orphan Node Auditor for Space Transitions

func _init() -> void:
	print("==================================================")
	print("Starting SpaceManager Live Transition Leak Audit")
	print("==================================================")

	var eb_script = load("res://core/event_bus.gd")
	var event_bus: EventBus = eb_script.new()
	root.add_child(event_bus)

	var settings_script = load("res://core/settings_manager.gd")
	var settings_mgr = settings_script.new()
	root.add_child(settings_mgr)
	settings_mgr.setup(event_bus)

	var mod_mgr_script = load("res://core/module_manager.gd")
	var mod_mgr: ModuleManager = mod_mgr_script.new()
	root.add_child(mod_mgr)

	var world_root: Node3D = Node3D.new()
	root.add_child(world_root)
	mod_mgr.setup(event_bus, world_root)

	var space_mgr_script = load("res://core/space_manager.gd")
	var space_mgr: SpaceManager = space_mgr_script.new()
	root.add_child(space_mgr)
	space_mgr.setup(mod_mgr, event_bus, world_root, null, settings_mgr)

	# Wait a couple frames to let initial setup settle
	await process_frame
	await process_frame

	var initial_orphans = Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)
	var initial_nodes = Performance.get_monitor(Performance.OBJECT_NODE_COUNT)
	var initial_objects = Performance.get_monitor(Performance.OBJECT_COUNT)
	print("Initial State -> Orphans: %d, Nodes: %d, Objects: %d" % [initial_orphans, initial_nodes, initial_objects])

	var spaces = space_mgr.list_spaces()
	print("Found spaces: ", spaces.map(func(s): return s["id"]))

	# Run 20 space switches
	for i in range(20):
		var target_space = spaces[i % spaces.size()]
		space_mgr.load_space(target_space["id"])
		# Also spawn some extra objects if tool playground to see if cleanup handles them
		var tool_mod = mod_mgr.get_module("cube_spawner_tool")
		if tool_mod and tool_mod.has_method("spawn_cube"):
			tool_mod.spawn_cube(Vector3(i, 1.0, -2.0))

		# Wait 2 frames for queue_free processing
		await process_frame
		await process_frame

		var cur_orphans = Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)
		var cur_nodes = Performance.get_monitor(Performance.OBJECT_NODE_COUNT)
		var cur_objects = Performance.get_monitor(Performance.OBJECT_COUNT)
		print("Iteration %2d (%s) -> Orphans: %d, Nodes: %d, Objects: %d, WorldRoot Children: %d" % [
			i + 1, target_space["id"], cur_orphans, cur_nodes, cur_objects, world_root.get_child_count()
		])

	# Final check
	await process_frame
	await process_frame

	var final_orphans = Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)
	print("\nFinal Orphan Node Count: %d (expected 0)" % final_orphans)

	# Clean up
	space_mgr.queue_free()
	world_root.queue_free()
	mod_mgr.queue_free()
	settings_mgr.queue_free()
	event_bus.queue_free()

	await process_frame
	await process_frame

	print("Post-cleanup Orphan Node Count: %d" % Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT))
	quit(0 if final_orphans == 0 else 1)
