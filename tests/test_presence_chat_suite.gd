extends SceneTree

# Test Suite for Presence System & P2P Chat (Subagent B)

const PresenceManagerScript = preload("res://core/net/presence_manager.gd")
const PeerMarkerScript = preload("res://ui/presence/peer_marker.gd")
const PeerChatScript = preload("res://core/net/peer_chat.gd")
const PeerChatWindowScript = preload("res://ui/chat/peer_chat_window.gd")

var passed_count: int = 0
var failed_count: int = 0

func _init() -> void:
	call_deferred("_run_tests")

func assert_true(condition: bool, test_name: String, message: String = "") -> void:
	if condition:
		passed_count += 1
		print("  [PASS] %s" % test_name)
	else:
		failed_count += 1
		print("  [FAIL] %s: %s" % [test_name, message])

func assert_false(condition: bool, test_name: String, message: String = "") -> void:
	assert_true(not condition, test_name, message)

func _run_tests() -> void:
	print("==================================================")
	print("Starting Presence System & P2P Chat Test Suite")
	print("==================================================")

	_test_presence_manager_setup()
	_test_presence_manager_state_and_broadcasting()
	_test_presence_manager_message_handling()
	_test_peer_marker()
	_test_peer_chat_logic()
	_test_peer_chat_window()

	print("==================================================")
	print("Test Results: %d Passed, %d Failed" % [passed_count, failed_count])
	print("==================================================")

	quit(1 if failed_count > 0 else 0)

func _test_presence_manager_setup() -> void:
	print("\n--- Testing PresenceManager Setup ---")
	var pm = PresenceManagerScript.new()
	pm.setup(null, 42, "CyberNode42")
	
	var state: Dictionary = pm.get_local_state()
	assert_true(state.get("peer_id") == 42, "PresenceManager local peer_id set")
	assert_true(state.get("name") == "CyberNode42", "PresenceManager local name set")
	assert_true(state.get("color") is Color, "PresenceManager local color generated")
	
	var color1: Color = PresenceManagerScript.generate_peer_color(1)
	var color2: Color = PresenceManagerScript.generate_peer_color(2)
	assert_true(color1 != color2, "Peer colors are distinct for different peer_ids")
	assert_true(color1.a == 1.0, "Peer color has full opacity")
	
	pm.free()

func _test_presence_manager_state_and_broadcasting() -> void:
	print("\n--- Testing PresenceManager State & Broadcasting ---")
	var pm = PresenceManagerScript.new()
	pm.setup(null, 10, "HostNode")
	
	pm.update_local_state(Vector3(10.5, 1.2, -4.0), Vector3(0.0, 1.57, 0.0), "editing_module", "cyber_grid")
	var s: Dictionary = pm.get_local_state()
	assert_true(s.get("position") == Vector3(10.5, 1.2, -4.0), "Local position updated")
	assert_true(s.get("rotation") == Vector3(0.0, 1.57, 0.0), "Local rotation updated")
	assert_true(s.get("activity") == "editing_module", "Local activity updated")
	assert_true(s.get("last_prompt") == "cyber_grid", "Local prompt updated")
	
	pm.set_local_activity("generating_module", "neon_mesh")
	s = pm.get_local_state()
	assert_true(s.get("activity") == "generating_module", "set_local_activity updated activity")
	assert_true(s.get("last_prompt") == "neon_mesh", "set_local_activity updated prompt")
	
	assert_false(pm.is_broadcasting(), "Initially not broadcasting")
	pm.start_broadcasting_presence(0.05)
	assert_true(pm.is_broadcasting(), "start_broadcasting_presence enables flag")
	pm.stop_broadcasting_presence()
	assert_false(pm.is_broadcasting(), "stop_broadcasting_presence disables flag")
	
	pm.free()

func _test_presence_manager_message_handling() -> void:
	print("\n--- Testing PresenceManager Message Handling ---")
	var pm = PresenceManagerScript.new()
	pm.setup(null, 1, "Server")
	
	var state_updated_captured: Array = []
	var activity_captured: Array = []
	var left_captured: Array = []
	
	pm.peer_state_updated.connect(func(pid: int, st: Dictionary): state_updated_captured.append([pid, st]))
	pm.peer_activity.connect(func(pid: int, act: String): activity_captured.append([pid, act]))
	pm.peer_left_presence.connect(func(pid: int): left_captured.append(pid))
	
	var remote_data: Dictionary = {
		"type": "presence_update",
		"state": {
			"name": "GuestAlpha",
			"position": Vector3(2.0, 0.0, -8.0),
			"rotation": Vector3(0.0, 3.14, 0.0),
			"activity": "browsing_gallery",
			"last_prompt": "prompt1",
			"color": Color(0.2, 0.8, 0.4, 1.0)
		}
	}
	pm.handle_message(101, "presence", remote_data)
	
	assert_true(state_updated_captured.size() == 1, "peer_state_updated emitted")
	assert_true(activity_captured.size() == 1, "peer_activity emitted on new activity")
	if activity_captured.size() > 0:
		assert_true(activity_captured[0][1] == "browsing_gallery", "Activity matches payload")
		
	var peer_st: Dictionary = pm.get_peer_state(101)
	assert_true(peer_st.get("name") == "GuestAlpha", "Peer state retrieved correctly")
	assert_true(peer_st.get("position") == Vector3(2.0, 0.0, -8.0), "Peer position stored correctly")
	
	var all_states: Dictionary = pm.get_all_peer_states()
	assert_true(all_states.has(101), "get_all_peer_states contains peer 101")
	
	# Disconnect peer
	pm._on_peer_disconnected(101)
	assert_true(left_captured.size() == 1, "peer_left_presence emitted on peer disconnect")
	assert_true(left_captured[0] == 101, "Disconnected peer ID matches")
	assert_true(pm.get_peer_state(101).is_empty(), "Disconnected peer state is erased")
	
	pm.free()

func _test_peer_marker() -> void:
	print("\n--- Testing PeerMarker Scene & Script ---")
	var marker_scene: PackedScene = load("res://ui/presence/peer_marker.tscn")
	assert_true(marker_scene != null, "peer_marker.tscn loads successfully")
	
	var marker = marker_scene.instantiate()
	assert_true(marker != null, "peer_marker instantiated successfully")
	
	root.add_child(marker)
	marker.setup(99, "NeoUser", Color(1.0, 0.5, 0.0, 1.0))
	assert_true(marker.peer_id == 99, "PeerMarker peer_id initialized")
	assert_true(marker.peer_name == "NeoUser", "PeerMarker peer_name initialized")
	
	marker.update_state({
		"position": Vector3(3.0, 1.0, -5.0),
		"rotation": Vector3(0.0, 1.2, 0.0),
		"activity": "generating_module",
		"last_prompt": "quantum_core"
	})
	
	assert_true(marker.target_position == Vector3(3.0, 1.0, -5.0), "target_position updated")
	assert_true(marker.target_rotation == Vector3(0.0, 1.2, 0.0), "target_rotation updated")
	assert_true(marker.peer_activity == "generating_module", "peer_activity updated")
	
	marker.queue_free()

func _test_peer_chat_logic() -> void:
	print("\n--- Testing PeerChat Logic ---")
	var chat = PeerChatScript.new()
	chat.setup(null, "LocalOperator")
	
	var msg_captured: Array = []
	var cleared_captured: Array = []
	
	chat.message_received.connect(func(pid: int, pname: String, txt: String, ts: float, is_priv: bool):
		msg_captured.append({"peer_id": pid, "name": pname, "text": txt, "timestamp": ts, "is_private": is_priv})
	)
	chat.history_cleared.connect(func(): cleared_captured.append(true))
	
	chat.send_message("System test message")
	assert_true(msg_captured.size() == 1, "Public message emitted signal")
	assert_true(msg_captured[0]["name"] == "LocalOperator", "Sender name is LocalOperator")
	assert_true(msg_captured[0]["text"] == "System test message", "Message text matches")
	assert_false(msg_captured[0]["is_private"], "Public message is_private is false")
	
	chat.send_private(5, "Secret ping")
	assert_true(msg_captured.size() == 2, "Private message emitted signal")
	assert_true(msg_captured[1]["is_private"], "Private message is_private is true")
	
	# Incoming message simulation
	chat.handle_message(55, "chat", {
		"type": "chat_message",
		"text": "Remote peer reply",
		"sender_name": "RemoteAgent",
		"timestamp": Time.get_unix_time_from_system()
	})
	assert_true(msg_captured.size() == 3, "Handled incoming message emitted signal")
	assert_true(msg_captured[2]["name"] == "RemoteAgent", "Remote author name matches")
	
	var history: Array[Dictionary] = chat.get_history(10)
	assert_true(history.size() == 3, "History contains 3 messages")
	
	chat.clear_history()
	assert_true(chat.get_history().is_empty(), "clear_history emptied history array")
	assert_true(cleared_captured.size() == 1, "history_cleared signal emitted")
	
	chat.free()

func _test_peer_chat_window() -> void:
	print("\n--- Testing PeerChatWindow UI ---")
	var win_scene: PackedScene = load("res://ui/chat/peer_chat_window.tscn")
	assert_true(win_scene != null, "peer_chat_window.tscn loads successfully")
	
	var win = win_scene.instantiate()
	assert_true(win != null, "peer_chat_window instantiated successfully")
	
	root.add_child(win)
	
	var chat = PeerChatScript.new()
	chat.setup(null, "TesterUI")
	win.setup(chat)
	
	win.open()
	assert_true(win.visible, "PeerChatWindow open() makes it visible")
	
	win.toggle()
	assert_false(win.visible, "PeerChatWindow toggle() hides when visible")
	
	win.toggle()
	assert_true(win.visible, "PeerChatWindow toggle() shows when hidden")
	
	win.close()
	assert_false(win.visible, "PeerChatWindow close() hides window")
	
	win.append_message(1, "Peer1", "Hello BBCode test!", Time.get_unix_time_from_system(), false)
	win.append_message(2, "Peer2", "Private test!", Time.get_unix_time_from_system(), true)
	
	win.queue_free()
	chat.free()
