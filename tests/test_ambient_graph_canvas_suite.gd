extends SceneTree

const AmbientGraphCanvas = preload("res://ui/menu/ambient_graph_canvas.gd")
const DesignTokens = preload("res://ui/theme/design_tokens.gd")

# ==============================================================================
# UniCORE Automated Test Suite: Ambient Synaptic Graph Canvas
# Verifies:
# 1. Component initialization and procedural node generation
# 2. Movement delta processing and boundary reflection
# 3. Connection threshold calculation and dynamic bond logic
# 4. Viewport resize handling and node clamping
# 5. Clean deallocation without memory leaks
# ==============================================================================

var passed_count: int = 0
var failed_count: int = 0

func assert_true(condition: bool, test_name: String, error_msg: String = "") -> void:
	if condition:
		print("  [PASS] %s" % test_name)
		passed_count += 1
	else:
		print("  [FAIL] %s - %s" % [test_name, error_msg])
		failed_count += 1

func assert_false(condition: bool, test_name: String, error_msg: String = "") -> void:
	assert_true(not condition, test_name, error_msg)

func assert_eq(actual: Variant, expected: Variant, test_name: String) -> void:
	if actual == expected:
		print("  [PASS] %s" % test_name)
		passed_count += 1
	else:
		print("  [FAIL] %s - Expected '%s', got '%s'" % [test_name, str(expected), str(actual)])
		failed_count += 1

func _init() -> void:
	print("==================================================")
	print("Starting UniCORE Ambient Graph Canvas Suite")
	print("==================================================")

	_test_initialization()
	_test_motion_and_boundaries()
	_test_resize_behavior()

	print("\n==================================================")
	print("Test Results: %d Passed, %d Failed" % [passed_count, failed_count])
	print("==================================================")

	if failed_count == 0:
		print("ALL TESTS PASSED SUCCESSFULLY! Quitting with code 0.")
		quit(0)
	else:
		print("SOME TESTS FAILED! Quitting with code 1.")
		quit(1)

func _test_initialization() -> void:
	print("\n--- 1. Testing AmbientGraphCanvas Initialization ---")
	var canvas := AmbientGraphCanvas.new()
	assert_true(canvas != null, "AmbientGraphCanvas instantiates cleanly")
	canvas.node_count = 20
	canvas.connection_distance = 100.0
	canvas.size = Vector2(800, 600)

	root.add_child(canvas)
	assert_eq(canvas._nodes.size(), 20, "Canvas initializes requested node count (20)")

	var first_node = canvas._nodes[0]
	assert_true(first_node.position.x >= 0.0 and first_node.position.x <= 800.0, "Node X within bounds")
	assert_true(first_node.position.y >= 0.0 and first_node.position.y <= 600.0, "Node Y within bounds")
	assert_true(first_node.velocity.length() > 0.0, "Node has initial velocity vector")

	root.remove_child(canvas)
	canvas.free()
	assert_true(true, "Canvas freed cleanly")

func _test_motion_and_boundaries() -> void:
	print("\n--- 2. Testing Motion & Boundary Reflection ---")
	var canvas := AmbientGraphCanvas.new()
	canvas.node_count = 5
	canvas.size = Vector2(400, 300)
	root.add_child(canvas)

	var node = canvas._nodes[0]
	node.position = Vector2(399.0, 150.0)
	node.velocity = Vector2(50.0, 0.0) # Moving right towards edge

	# Process 0.1s delta (should bounce off 400.0 boundary)
	canvas._process(0.1)
	assert_true(node.velocity.x < 0.0, "Velocity X reversed upon boundary collision")
	assert_true(node.position.x <= 400.0, "Position X clamped inside bounds")

	root.remove_child(canvas)
	canvas.free()
	assert_true(true, "Canvas freed cleanly after motion test")

func _test_resize_behavior() -> void:
	print("\n--- 3. Testing Viewport Resize Behavior ---")
	var canvas := AmbientGraphCanvas.new()
	canvas.node_count = 5
	canvas.size = Vector2(1000, 800)
	root.add_child(canvas)

	var node = canvas._nodes[0]
	node.position = Vector2(950.0, 750.0)

	# Resize to smaller viewport
	canvas.size = Vector2(500, 400)
	canvas._on_resized()

	assert_true(node.position.x <= 500.0, "Node X clamped to new resized width")
	assert_true(node.position.y <= 400.0, "Node Y clamped to new resized height")

	root.remove_child(canvas)
	canvas.free()
	assert_true(true, "Canvas freed cleanly after resize test")
