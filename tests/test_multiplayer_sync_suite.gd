extends SceneTree

# ==============================================================================
# UniCORE Test Suite: Multiplayer Space Sync & Realtime Collaboration
# ==============================================================================

const VectorClock = preload("res://core/net/vector_clock.gd")
const SpaceStateMachine = preload("res://core/net/space_state_machine.gd")
const PresenceManager = preload("res://core/net/presence_manager.gd")
const PeerChat = preload("res://core/net/peer_chat.gd")
const NetworkTransport = preload("res://core/net/network_transport.gd")
const AgentBrain = preload("res://agent/agent_brain.gd")
const ModuleManager = preload("res://core/module_manager.gd")
const EventBus = preload("res://core/event_bus.gd")
const BaseLLMProvider = preload("res://agent/providers/base_llm_provider.gd")
const DiagnosticLogger = preload("res://core/diagnostic_logger.gd")

var passed_count: int = 0
var failed_count: int = 0
var _tracked_nodes: Array[Node] = []

func track_node(node: Node) -> Node:
	_tracked_nodes.append(node)
	return node

func free_tracked_nodes() -> void:
	for node in _tracked_nodes:
		if is_instance_valid(node):
			node.free()
	_tracked_nodes.clear()

func assert_true(condition: bool, test_name: String, error_msg: String = "") -> void:
	if condition:
		print("  [PASS] %s" % test_name)
		passed_count += 1
	else:
		print("  [FAIL] %s %s" % [test_name, ("- " + error_msg) if not error_msg.is_empty() else ""])
		failed_count += 1

func assert_false(condition: bool, test_name: String, error_msg: String = "") -> void:
	assert_true(not condition, test_name, error_msg)

func assert_eq(val: Variant, expected: Variant, test_name: String) -> void:
	var matches: bool = (val == expected)
	assert_true(matches, test_name, "Expected '%s', got '%s'" % [str(expected), str(val)])

# --- Mock Classes ---

class MockTransport extends NetworkTransport:
	var broadcast_calls: Array[Dictionary] = []
	var send_to_peer_calls: Array[Dictionary] = []
	var connected_peers_list: Array[int] = [2, 3]

	func broadcast(channel: String, data: Dictionary) -> void:
		broadcast_calls.append({"channel": channel, "data": data})

	func send_to_peer(peer_id: int, channel: String, data: Dictionary) -> void:
		send_to_peer_calls.append({"peer_id": peer_id, "channel": channel, "data": data})

	func get_connected_peers() -> Array[int]:
		return connected_peers_list.duplicate()

	func get_status() -> String:
		return "connected"

class MockLLM extends BaseLLMProvider:
	var sent_prompts: Array[String] = []

	func send_prompt(sys_prompt: String, user_prompt: String, _api_key: String) -> void:
		sent_prompts.append(user_prompt)
		var valid_code := (
			"## Name: SyncMesh\n" +
			"## Description: A collaboratively synchronized test mesh\n" +
			"## Tags: 3d, sync, test\n" +
			"extends Node3D\n\n" +
			"func get_module_id() -> String:\n" +
			"    return \"sync_mesh_01\"\n\n" +
			"func get_module_name() -> String:\n" +
			"    return \"Sync Mesh\"\n\n" +
			"func initialize(_ctx: Dictionary) -> bool:\n" +
			"    return true\n\n" +
			"func cleanup() -> void:\n" +
			"    pass\n"
		)
		call_deferred("_reply", valid_code)

	func _reply(resp: String) -> void:
		response_received.emit(resp)

# --- Test Execution ---

func _init() -> void:
	call_deferred("_run_all_tests")

func _run_all_tests() -> void:
	print("==================================================")
	print("Starting Multiplayer Sync Comprehensive Suite")
	print("==================================================")

	_test_vector_clock()
	_test_space_state_machine()
	_test_presence_manager()
	_test_peer_chat()
	await _test_agent_brain_integration()

	# Cleanup generated test module file
	var temp_mod := "res://modules/sync_mesh_01.gd"
	if FileAccess.file_exists(temp_mod):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(temp_mod))

	free_tracked_nodes()

	print("\n==================================================")
	print("Test Results: %d Passed, %d Failed" % [passed_count, failed_count])
	print("==================================================")

	quit(1 if failed_count > 0 else 0)

# ------------------------------------------------------------------------------
# 1. Vector Clock Tests
# ------------------------------------------------------------------------------

func _test_vector_clock() -> void:
	print("\n--- 1. VectorClock Core Functionality ---")
	var vc1 := VectorClock.new()
	assert_eq(vc1.get_counter(1), 0, "VectorClock: initial counter is 0")

	vc1.increment(1)
	assert_eq(vc1.get_counter(1), 1, "VectorClock: increment(1) -> 1")
	vc1.increment(1)
	assert_eq(vc1.get_counter(1), 2, "VectorClock: increment(1) -> 2")
	vc1.increment(2)
	assert_eq(vc1.get_counter(2), 1, "VectorClock: increment(2) -> 1")

	# Serialization
	var d1: Dictionary = vc1.to_dict()
	assert_eq(d1.get(1), 2, "VectorClock: to_dict contains key 1")
	assert_eq(d1.get(2), 1, "VectorClock: to_dict contains key 2")

	var vc2 := VectorClock.from_dict({1: 1, 2: 3, 5: 10})
	assert_eq(vc2.get_counter(5), 10, "VectorClock.from_dict parses entries")

	# Merge
	vc1.merge(vc2.to_dict())
	assert_eq(vc1.get_counter(1), 2, "VectorClock.merge: max(2, 1) = 2")
	assert_eq(vc1.get_counter(2), 3, "VectorClock.merge: max(1, 3) = 3")
	assert_eq(vc1.get_counter(5), 10, "VectorClock.merge: max(0, 10) = 10")

	# Causal Ordering & Concurrency
	var clk_a := VectorClock.from_dict({1: 2, 2: 1})
	var clk_b := VectorClock.from_dict({1: 3, 2: 2})
	var clk_c := VectorClock.from_dict({1: 1, 2: 4})

	assert_true(clk_a.is_before(clk_b.to_dict()), "VectorClock: a is strictly before b")
	assert_false(clk_b.is_before(clk_a.to_dict()), "VectorClock: b is not before a")
	assert_false(clk_a.is_concurrent(clk_b.to_dict()), "VectorClock: a and b are not concurrent")

	assert_true(clk_b.is_concurrent(clk_c.to_dict()), "VectorClock: b and c are concurrent")
	assert_true(clk_c.is_concurrent(clk_b.to_dict()), "VectorClock: c and b are concurrent")

	# Duplicate Clock
	var clk_dup = clk_a.duplicate_clock()
	assert_eq(clk_dup.get_counter(1), 2, "VectorClock.duplicate_clock duplicates state")
	clk_dup.increment(1)
	assert_eq(clk_dup.get_counter(1), 3, "VectorClock.duplicate_clock modifies independently")
	assert_eq(clk_a.get_counter(1), 2, "VectorClock: original clock unaltered")

# ------------------------------------------------------------------------------
# 2. SpaceStateMachine Tests
# ------------------------------------------------------------------------------

func _test_space_state_machine() -> void:
	print("\n--- 2. SpaceStateMachine & Conflict Resolution ---")
	var transport := MockTransport.new()
	track_node(transport)

	var ssm := SpaceStateMachine.new()
	track_node(ssm)
	ssm.setup(transport, null, null, 1)

	# Local Op Generation
	var op := ssm.apply_local_operation(SpaceStateMachine.OP_MODULE_LOAD, {
		"module_id": "test_holo_screen",
		"source_code": "extends UniCoreModule\n"
	})
	assert_true(op.has("op_id"), "SpaceStateMachine generates op_id")
	assert_eq(op.get("op_type"), SpaceStateMachine.OP_MODULE_LOAD, "SpaceStateMachine sets op_type")
	assert_eq(op.get("author_id"), 1, "SpaceStateMachine records author_id 1")
	assert_eq(ssm.get_vector_clock().get(1), 1, "SpaceStateMachine increments local vector clock")

	var log_ops := ssm.get_operation_log()
	assert_eq(log_ops.size(), 1, "SpaceStateMachine appends op to log")
	assert_true(transport.broadcast_calls.size() > 0, "SpaceStateMachine broadcasts local op to transport")

	# Remote Op Application & Idempotency
	var remote_op: Dictionary = {
		"op_id": "remote_op_101",
		"op_type": SpaceStateMachine.OP_MODULE_LOAD,
		"author_id": 2,
		"timestamp": Time.get_unix_time_from_system() + 5.0,
		"data": {
			"module_id": "remote_synth",
			"source_code": "extends UniCoreModule\n"
		},
		"vector_clock": {2: 1}
	}

	var first_apply := ssm.apply_remote_operation(remote_op)
	assert_true(first_apply, "SpaceStateMachine applies valid new remote operation")
	assert_eq(ssm.get_vector_clock().get(2), 1, "SpaceStateMachine merges remote vector clock")

	var dupe_apply := ssm.apply_remote_operation(remote_op)
	assert_false(dupe_apply, "SpaceStateMachine rejects duplicate op_id (idempotency)")

	# Conflict Resolution Matrix
	# Case A: Different modules -> no conflict
	var c_diff1 := {"op_type": SpaceStateMachine.OP_MODULE_LOAD, "data": {"module_id": "cube_a"}}
	var c_diff2 := {"op_type": SpaceStateMachine.OP_MODULE_LOAD, "data": {"module_id": "cube_b"}}
	assert_eq(ssm._resolve_conflict(c_diff1, c_diff2), "no_conflict", "Conflict matrix: different modules = no_conflict")

	# Case B: Load vs Unload -> Unload wins
	var c_load := {"op_type": SpaceStateMachine.OP_MODULE_LOAD, "data": {"module_id": "door_01"}}
	var c_unload := {"op_type": SpaceStateMachine.OP_MODULE_UNLOAD, "data": {"module_id": "door_01"}}
	assert_eq(ssm._resolve_conflict(c_load, c_unload), "unload_wins", "Conflict matrix: load vs unload = unload_wins")
	assert_eq(ssm._resolve_conflict(c_unload, c_load), "unload_wins", "Conflict matrix: unload vs load = unload_wins")

	# Case C: Edit vs Edit -> Last-Writer-Wins
	var c_edit_early := {
		"op_type": SpaceStateMachine.OP_MODULE_EDIT,
		"timestamp": 1000.0,
		"author_id": 1,
		"data": {"module_id": "grid_01"}
	}
	var c_edit_late := {
		"op_type": SpaceStateMachine.OP_MODULE_EDIT,
		"timestamp": 2000.0,
		"author_id": 2,
		"data": {"module_id": "grid_01"}
	}
	assert_eq(ssm._resolve_conflict(c_edit_early, c_edit_late), "remote_wins", "Conflict matrix: remote newer timestamp = remote_wins")
	assert_eq(ssm._resolve_conflict(c_edit_late, c_edit_early), "local_wins", "Conflict matrix: remote older timestamp = local_wins")

	# Case D: Equal Timestamp -> Tie-breaker by author_id
	var c_tie_low := {
		"op_type": SpaceStateMachine.OP_MODULE_EDIT,
		"timestamp": 1500.0,
		"author_id": 2,
		"data": {"module_id": "core_lamp"}
	}
	var c_tie_high := {
		"op_type": SpaceStateMachine.OP_MODULE_EDIT,
		"timestamp": 1500.0,
		"author_id": 5,
		"data": {"module_id": "core_lamp"}
	}
	assert_eq(ssm._resolve_conflict(c_tie_low, c_tie_high), "remote_wins", "Conflict matrix: tie-breaker selects higher author_id")
	assert_eq(ssm._resolve_conflict(c_tie_high, c_tie_low), "local_wins", "Conflict matrix: tie-breaker rejects lower author_id")

	# Remote load rejected when local has unload
	ssm.apply_local_operation(SpaceStateMachine.OP_MODULE_UNLOAD, {"module_id": "target_del"})
	var bad_load := {
		"op_id": "bad_load_01",
		"op_type": SpaceStateMachine.OP_MODULE_LOAD,
		"author_id": 2,
		"timestamp": Time.get_unix_time_from_system() + 10.0,
		"data": {"module_id": "target_del", "source_code": "extends UniCoreModule\n"},
		"vector_clock": {2: 5}
	}
	var applied_bad := ssm.apply_remote_operation(bad_load)
	assert_false(applied_bad, "SpaceStateMachine rejects remote load when local is unloaded")

# ------------------------------------------------------------------------------
# 3. PresenceManager Tests
# ------------------------------------------------------------------------------

func _test_presence_manager() -> void:
	print("\n--- 3. PresenceManager & 3D Tracking ---")
	var transport := MockTransport.new()
	track_node(transport)

	var pm := PresenceManager.new()
	track_node(pm)
	pm.setup(transport, 7, "GhostNode")

	var local_st := pm.get_local_state()
	assert_eq(local_st.get("peer_id"), 7, "PresenceManager: sets peer_id")
	assert_eq(local_st.get("name"), "GhostNode", "PresenceManager: sets local name")
	assert_true(local_st.get("color") is Color, "PresenceManager: generates peer Color")

	# Color Determinism & Uniqueness
	var col1: Color = PresenceManager.generate_peer_color(10)
	var col2: Color = PresenceManager.generate_peer_color(10)
	var col3: Color = PresenceManager.generate_peer_color(20)
	assert_eq(col1, col2, "PresenceManager: color generation is deterministic for same peer_id")
	assert_true(col1 != col3, "PresenceManager: distinct colors for different peer_ids")

	# Local State Updates
	pm.update_local_state(Vector3(5.0, 1.0, -2.5), Vector3(0.0, 3.14, 0.0), "generating_module", "cyber_core")
	var updated := pm.get_local_state()
	assert_eq(updated.get("position"), Vector3(5.0, 1.0, -2.5), "PresenceManager: local position updated")
	assert_eq(updated.get("rotation"), Vector3(0.0, 3.14, 0.0), "PresenceManager: local rotation updated")
	assert_eq(updated.get("activity"), "generating_module", "PresenceManager: local activity updated")
	assert_eq(updated.get("last_prompt"), "cyber_core", "PresenceManager: last_prompt updated")

	# Remote Updates
	var emitted_peer_update := [false]
	var emitted_activity := [false]
	var emitted_left := [false]

	pm.peer_state_updated.connect(func(pid: int, st: Dictionary): emitted_peer_update[0] = true)
	pm.peer_activity.connect(func(pid: int, act: String): emitted_activity[0] = true)
	pm.peer_left_presence.connect(func(pid: int): emitted_left[0] = true)

	pm.handle_message(2, "presence", {
		"type": "presence_update",
		"state": {
			"peer_id": 2,
			"name": "PeerTwo",
			"position": Vector3(1.0, 0.0, 2.0),
			"rotation": Vector3.ZERO,
			"activity": "editing_module",
			"last_prompt": "laser_grid",
			"color": Color(0.2, 0.8, 0.9, 1.0)
		}
	})

	assert_true(emitted_peer_update[0], "PresenceManager: emits peer_state_updated on remote message")
	assert_true(emitted_activity[0], "PresenceManager: emits peer_activity when activity transitions")
	assert_eq(pm.get_peer_state(2).get("name"), "PeerTwo", "PresenceManager: stores peer state in map")

	# Peer Disconnect
	pm._on_peer_disconnected(2)
	assert_true(emitted_left[0], "PresenceManager: emits peer_left_presence on disconnect")
	assert_true(pm.get_peer_state(2).is_empty(), "PresenceManager: removes disconnected peer from map")

# ------------------------------------------------------------------------------
# 4. PeerChat Tests
# ------------------------------------------------------------------------------

func _test_peer_chat() -> void:
	print("\n--- 4. PeerChat & Message History ---")
	var transport := MockTransport.new()
	track_node(transport)

	var chat := PeerChat.new()
	track_node(chat)
	chat.setup(transport, "NexusHost")

	var captured_msg := [false]
	chat.message_received.connect(func(pid: int, pname: String, txt: String, ts: float, is_priv: bool):
		captured_msg[0] = true
	)

	# Broadcast
	chat.send_message("System online")
	assert_true(captured_msg[0], "PeerChat: send_message emits message_received")
	assert_true(transport.broadcast_calls.size() > 0, "PeerChat: broadcast sent to network")
	var history := chat.get_history(10)
	assert_eq(history.size(), 1, "PeerChat: message recorded in history")
	assert_eq(history[0].get("text"), "System online", "PeerChat: text matches")

	# Private Message
	captured_msg[0] = false
	chat.send_private(3, "Direct ping")
	assert_true(captured_msg[0], "PeerChat: send_private emits message_received")
	assert_true(transport.send_to_peer_calls.size() > 0, "PeerChat: private packet dispatched to peer 3")

	# Incoming remote messages
	chat.handle_message(2, "chat", {
		"type": "chat_message",
		"sender_name": "Explorer",
		"text": "Hello world!",
		"timestamp": Time.get_unix_time_from_system()
	})
	assert_eq(chat.get_history().size(), 3, "PeerChat: incoming message saved to history")

	# Ring Buffer Limit (Overflow Test)
	for i in range(250):
		chat.handle_message(2, "chat", {
			"type": "chat_message",
			"sender_name": "Spammer",
			"text": "msg_%d" % i,
			"timestamp": Time.get_unix_time_from_system()
		})
	assert_eq(chat.get_history(300).size(), PeerChat.MAX_HISTORY, "PeerChat: history capped strictly at MAX_HISTORY (200)")

	chat.clear_history()
	assert_eq(chat.get_history().size(), 0, "PeerChat: clear_history clears buffer")

# ------------------------------------------------------------------------------
# 5. AgentBrain + SpaceStateMachine + PresenceManager Integration Test
# ------------------------------------------------------------------------------

func _test_agent_brain_integration() -> void:
	print("\n--- 5. AgentBrain & Multiplayer Sync Integration ---")
	var event_bus := EventBus.new()
	track_node(event_bus)

	var world_root := Node3D.new()
	track_node(world_root)

	var module_manager := ModuleManager.new()
	track_node(module_manager)
	module_manager.setup(event_bus, world_root)

	var transport := MockTransport.new()
	track_node(transport)

	var ssm := SpaceStateMachine.new()
	track_node(ssm)
	ssm.setup(transport, module_manager, null, 1)

	var pm := PresenceManager.new()
	track_node(pm)
	pm.setup(transport, 1, "HostAgent")

	var mock_llm := MockLLM.new()
	track_node(mock_llm)

	var diag := DiagnosticLogger.new()
	track_node(diag)

	var brain := AgentBrain.new()
	track_node(brain)
	brain.setup(event_bus, module_manager, mock_llm, diag, null, null, null, null, ssm, pm)

	assert_eq(brain.get_space_state_machine(), ssm, "AgentBrain: SpaceStateMachine linked")
	assert_eq(brain.get_presence_manager(), pm, "AgentBrain: PresenceManager linked")

	var prompt_done := [false]
	var resolved_source := [""]
	brain.prompt_completed.connect(func(_mid: String = ""): prompt_done[0] = true)
	brain.module_resolved.connect(func(mid: String, src: String, dur: float): resolved_source[0] = src)

	# Execute Prompt
	brain.process_prompt("Create a synchronized mesh module")

	# Check presence activity was set to generating
	assert_eq(pm.get_local_state().get("activity"), "generating_module", "AgentBrain: sets presence activity to 'generating_module' on prompt start")

	# Await deferred LLM response and completion (with 3 second backstop)
	var timer: float = 0.0
	while not prompt_done[0] and timer < 3.0:
		await process_frame
		timer += 0.016

	assert_true(prompt_done[0], "AgentBrain: prompt_completed received")
	assert_eq(resolved_source[0], "llm", "AgentBrain: module resolved via LLM fallback")
	assert_eq(pm.get_local_state().get("activity"), "idle", "AgentBrain: resets presence activity to 'idle' on completion")

	# Verify SpaceStateMachine logged and broadcasted the operation!
	var op_log := ssm.get_operation_log()
	assert_true(op_log.size() > 0, "SpaceStateMachine: received operation from AgentBrain")
	var last_op: Dictionary = op_log[op_log.size() - 1]
	assert_eq(last_op.get("op_type"), SpaceStateMachine.OP_MODULE_LOAD, "SpaceStateMachine: op_type is module_load")
	assert_eq(last_op.get("author_id"), 1, "SpaceStateMachine: author_id is 1")
	assert_true(last_op.get("data", {}).has("module_id"), "SpaceStateMachine: op payload contains module_id")
	assert_true(transport.broadcast_calls.size() > 0, "SpaceStateMachine: broadcast packet dispatched to network peers")
