extends SceneTree

# Comprehensive Test Suite: SpaceManager Live Switching, Memory Leaks & Dangling Node Prevention
# Validates zero orphan nodes, signal disconnections, EventBus cleanup, environment/camera cleanup

var passed_count: int = 0
var failed_count: int = 0

class DummyListener extends Node:
	var received: bool = false
	func on_space_event(_payload: Dictionary) -> void:
		received = true

func assert_true(condition: bool, test_name: String, error_msg: String = "") -> void:
	if condition:
		print("  [PASS] %s" % test_name)
		passed_count += 1
	else:
		print("  [FAIL] %s - %s" % [test_name, error_msg])
		failed_count += 1

func assert_false(condition: bool, test_name: String, error_msg: String = "") -> void:
	assert_true(not condition, test_name, error_msg)

func assert_eq(a, b, test_name: String) -> void:
	assert_true(a == b, test_name, "Expected %s, got %s" % [str(b), str(a)])

func _init() -> void:
	print("==================================================")
	print("Starting UniCORE SpaceManager Leak & Lifecycle Test Suite")
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

	# ----------------------------------------------------
	# Test Group 1: Explicit Space Unloading & Tree Sanitization
	# ----------------------------------------------------
	print("\n--- Test Group 1: Explicit Space Unload & Tree Sanitization ---")

	# Add loose custom nodes, environment nodes, and camera anchors to world_root
	var loose_cube = MeshInstance3D.new()
	loose_cube.name = "LooseCube"
	world_root.add_child(loose_cube)

	var custom_env = WorldEnvironment.new()
	custom_env.name = "CustomWorldEnv"
	world_root.add_child(custom_env)

	var cam_anchor = Marker3D.new()
	cam_anchor.name = "CameraAnchor"
	cam_anchor.add_to_group("camera_anchors")
	world_root.add_child(cam_anchor)

	assert_true(world_root.has_node("LooseCube"), "world_root has LooseCube")
	assert_true(world_root.has_node("CustomWorldEnv"), "world_root has CustomWorldEnv")
	assert_true(world_root.has_node("CameraAnchor"), "world_root has CameraAnchor")

	# Explicitly call unload_current_space()
	space_mgr.unload_current_space()

	assert_false(world_root.has_node("LooseCube"), "LooseCube freed on unload")
	assert_false(world_root.has_node("CustomWorldEnv"), "CustomWorldEnv freed on unload")
	assert_false(world_root.has_node("CameraAnchor"), "CameraAnchor freed on unload")
	assert_eq(world_root.get_child_count(), 0, "world_root has 0 children after unload")
	assert_eq(mod_mgr.get_active_module_ids().size(), 0, "0 active modules in ModuleManager after unload")

	var orphans_after_unload = Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)
	assert_eq(orphans_after_unload, 0, "0 orphan nodes immediately after unload_current_space()")

	# ----------------------------------------------------
	# Test Group 2: EventBus & Signal Disconnections
	# ----------------------------------------------------
	print("\n--- Test Group 2: EventBus & Signal Disconnections ---")

	# Create a dummy module that listens to EventBus events
	var listener_obj = DummyListener.new()
	root.add_child(listener_obj)

	event_bus.subscribe("test_space_event", Callable(listener_obj, "on_space_event"))

	event_bus.emit("test_space_event", {"msg": "hello"})
	assert_true(listener_obj.received, "EventBus listener received event before unload")

	# Unsubscribe listener via target helper
	listener_obj.received = false
	event_bus.unsubscribe_all_for_target(listener_obj)
	event_bus.emit("test_space_event", {"msg": "hello again"})
	assert_false(listener_obj.received, "EventBus listener disconnected via unsubscribe_all_for_target")

	listener_obj.queue_free()

	# Test EventBus cleanup of freed/dead callbacks
	var dead_node = Node.new()
	root.add_child(dead_node)
	event_bus.subscribe("dead_event", Callable(dead_node, "queue_free"))
	dead_node.free() # immediately destroy

	var count_before = event_bus.get_listener_count("dead_event")
	assert_true(count_before >= 1, "Dead listener registered before cleanup")
	event_bus.cleanup_invalid_listeners()
	var count_after = event_bus.get_listener_count("dead_event")
	assert_eq(count_after, 0, "Dead listener purged from EventBus via cleanup_invalid_listeners()")

	# Test signal disconnections on space_loaded / space_saved
	var signal_received := [false]
	var callable = func(_data): signal_received[0] = true
	space_mgr.space_loaded.connect(callable)
	space_mgr.load_space("space_cyber_void")
	assert_true(signal_received[0], "space_loaded signal received")

	space_mgr.space_loaded.disconnect(callable)
	signal_received[0] = false
	space_mgr.load_space("space_clean_slate")
	assert_false(signal_received[0], "Disconnected signal listener did not receive event")

	# ----------------------------------------------------
	# Test Group 3: Repeated Live Space Transitions & 0 Orphan Nodes
	# ----------------------------------------------------
	print("\n--- Test Group 3: Repeated Live Transitions & Zero Orphan Nodes ---")

	var spaces_to_test = ["space_default", "space_cyber_void", "space_clean_slate", "space_tools"]
	var zero_orphans_maintained := true

	for cycle in range(5):
		for space_id in spaces_to_test:
			space_mgr.load_space(space_id)

			# Also test spawning temporary nodes into world_root
			var loose = Node3D.new()
			loose.name = "DanglingNode_Cycle%d" % cycle
			world_root.add_child(loose)

			var orphan_count = Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)
			if orphan_count != 0:
				zero_orphans_maintained = false
				print("    [WARNING] Orphan count detected: %d on %s (cycle %d)" % [orphan_count, space_id, cycle])

	assert_true(zero_orphans_maintained, "0 orphan nodes maintained across 20 rapid transitions")
	var final_orphan_count = Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)
	assert_eq(final_orphan_count, 0, "Final orphan node count is exactly 0")

	# ----------------------------------------------------
	# Test Group 4: Memory Leak & Node Count Stability
	# ----------------------------------------------------
	print("\n--- Test Group 4: Memory & Node Count Stability ---")

	# Let tree settle
	space_mgr.load_space("space_clean_slate")
	var baseline_nodes = Performance.get_monitor(Performance.OBJECT_NODE_COUNT)
	var baseline_world_children = world_root.get_child_count()

	# Perform 10 transitions between default studio and clean slate
	for i in range(10):
		space_mgr.load_space("space_default")
		space_mgr.load_space("space_clean_slate")

	var after_nodes = Performance.get_monitor(Performance.OBJECT_NODE_COUNT)
	var after_world_children = world_root.get_child_count()

	assert_eq(after_world_children, baseline_world_children, "world_root child count returns to baseline (1 module: locomotion)")
	assert_eq(after_nodes, baseline_nodes, "Node count completely stable across 10 repeated space transitions (no node leak)")

	# ----------------------------------------------------
	# Test Group 5: Camera Anchor Persistence & Retrieval
	# ----------------------------------------------------
	print("\n--- Test Group 5: Camera Anchor Handling ---")

	# Create a space with a custom CameraAnchor in world_root
	space_mgr.create_new_space("Anchor Test Space", "clean_slate")
	var test_anchor = Marker3D.new()
	test_anchor.name = "CameraAnchor"
	test_anchor.global_position = Vector3(7.5, 4.2, -12.0)
	test_anchor.rotation = Vector3(0.3, -0.7, 0.0)
	world_root.add_child(test_anchor)

	# Save space
	var save_ok = space_mgr.save_current_space()
	assert_true(save_ok, "save_current_space with CameraAnchor returns true")
	var anchor_space_id = space_mgr.current_space_id

	# Switch away to Cyber Void
	space_mgr.load_space("space_cyber_void")
	assert_false(world_root.has_node("CameraAnchor"), "Previous CameraAnchor removed on space switch")

	# Load back Anchor Test Space
	space_mgr.load_space(anchor_space_id)
	assert_true(space_mgr.current_space_name == "Anchor Test Space", "Reloaded Anchor Test Space")

	# Clean up test space
	space_mgr.delete_space(anchor_space_id)

	# ----------------------------------------------------
	# Cleanup Test Fixtures
	# ----------------------------------------------------
	space_mgr.queue_free()
	world_root.queue_free()
	mod_mgr.queue_free()
	settings_mgr.queue_free()
	event_bus.queue_free()

	print("\n==================================================")
	print("Leak & Lifecycle Test Results: %d Passed, %d Failed" % [passed_count, failed_count])
	print("==================================================")

	if failed_count == 0:
		quit(0)
	else:
		quit(1)
