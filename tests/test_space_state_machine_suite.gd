extends SceneTree

# ==============================================================================
# UniCORE Test Suite: VectorClock & SpaceStateMachine
# ==============================================================================

const VectorClock = preload("res://core/net/vector_clock.gd")
const SpaceStateMachine = preload("res://core/net/space_state_machine.gd")

var passed_count: int = 0
var failed_count: int = 0

func assert_true(condition: bool, test_name: String, error_msg: String = "") -> void:
	if condition:
		print("  [PASS] %s" % test_name)
		passed_count += 1
	else:
		print("  [FAIL] %s %s" % [test_name, ("- " + error_msg) if not error_msg.is_empty() else ""])
		failed_count += 1

func assert_false(condition: bool, test_name: String, error_msg: String = "") -> void:
	assert_true(not condition, test_name, error_msg)

func assert_eq(val, expected, test_name: String) -> void:
	var matches: bool = (val == expected)
	assert_true(matches, test_name, "Expected '%s', got '%s'" % [str(expected), str(val)])

func _init() -> void:
	print("==================================================")
	print("Starting VectorClock & SpaceStateMachine Suite")
	print("==================================================")

	_run_vector_clock_tests()
	_run_space_state_machine_tests()

	print("\n==================================================")
	print("Test Results: %d Passed, %d Failed" % [passed_count, failed_count])
	print("==================================================")

	quit(1 if failed_count > 0 else 0)

func _run_vector_clock_tests() -> void:
	print("\n--- Testing VectorClock ---")

	var vc1 = VectorClock.new()
	assert_eq(vc1.get_counter(1), 0, "VectorClock: initial counter is 0")

	vc1.increment(1)
	assert_eq(vc1.get_counter(1), 1, "VectorClock: counter increments to 1")
	vc1.increment(1)
	assert_eq(vc1.get_counter(1), 2, "VectorClock: counter increments to 2")
	vc1.increment(2)
	assert_eq(vc1.get_counter(2), 1, "VectorClock: peer 2 counter increments to 1")

	var d1: Dictionary = vc1.to_dict()
	assert_eq(d1[1], 2, "VectorClock: to_dict contains peer 1")
	assert_eq(d1[2], 1, "VectorClock: to_dict contains peer 2")

	var vc2 = VectorClock.from_dict({1: 1, 2: 3, 3: 5})
	assert_eq(vc2.get_counter(3), 5, "VectorClock.from_dict correctly parses dictionary")

	# Test merge
	vc1.merge(vc2.to_dict())
	assert_eq(vc1.get_counter(1), 2, "VectorClock.merge: max(2, 1) = 2")
	assert_eq(vc1.get_counter(2), 3, "VectorClock.merge: max(1, 3) = 3")
	assert_eq(vc1.get_counter(3), 5, "VectorClock.merge: max(0, 5) = 5")

	# Test is_before and is_concurrent
	var a = VectorClock.from_dict({1: 1, 2: 1})
	var b = VectorClock.from_dict({1: 2, 2: 1})
	var c = VectorClock.from_dict({1: 1, 2: 2})

	assert_true(a.is_before(b.to_dict()), "VectorClock: a is before b")
	assert_false(b.is_before(a.to_dict()), "VectorClock: b is not before a")
	assert_false(a.is_concurrent(b.to_dict()), "VectorClock: a and b are not concurrent")

	# b: {1: 2, 2: 1} vs c: {1: 1, 2: 2} -> Concurrent!
	assert_true(b.is_concurrent(c.to_dict()), "VectorClock: b and c are concurrent")
	assert_true(c.is_concurrent(b.to_dict()), "VectorClock: c and b are concurrent")
	assert_false(b.is_before(c.to_dict()), "VectorClock: b is not before c")
	assert_false(c.is_before(b.to_dict()), "VectorClock: c is not before b")

	# Duplicate clock
	var dup = vc1.duplicate_clock()
	assert_eq(dup.get_counter(1), vc1.get_counter(1), "VectorClock.duplicate_clock copies counters")
	dup.increment(1)
	assert_true(dup.get_counter(1) > vc1.get_counter(1), "VectorClock.duplicate_clock is deep independent copy")

func _run_space_state_machine_tests() -> void:
	print("\n--- Testing SpaceStateMachine ---")

	var sm = SpaceStateMachine.new()
	sm.setup(null, null, null, 1)

	# 1. Local operation generation
	var op = sm.apply_local_operation(SpaceStateMachine.OP_MODULE_LOAD, {
		"module_id": "test_module",
		"source_code": "extends Node\n"
	})

	assert_true(op.has("op_id"), "apply_local_operation creates op_id")
	assert_eq(op.get("op_type"), SpaceStateMachine.OP_MODULE_LOAD, "apply_local_operation sets op_type")
	assert_eq(op.get("author_id"), 1, "apply_local_operation sets author_id")
	assert_true(op.get("timestamp") > 0.0, "apply_local_operation sets timestamp")
	assert_eq(sm.get_vector_clock().get(1), 1, "apply_local_operation increments local vector clock")

	var log_ops = sm.get_operation_log()
	assert_eq(log_ops.size(), 1, "SpaceStateMachine records operation in log")

	# 2. Remote operation application & idempotency
	var remote_op: Dictionary = {
		"op_id": "remote_op_001",
		"op_type": SpaceStateMachine.OP_MODULE_LOAD,
		"author_id": 2,
		"timestamp": Time.get_unix_time_from_system() + 10.0,
		"data": {
			"module_id": "peer_module",
			"source_code": "extends Node\n"
		},
		"vector_clock": {2: 1}
	}

	var applied_first: bool = sm.apply_remote_operation(remote_op)
	assert_true(applied_first, "apply_remote_operation returns true for valid new operation")
	assert_eq(sm.get_vector_clock().get(2), 1, "apply_remote_operation merges remote vector clock")

	var applied_duplicate: bool = sm.apply_remote_operation(remote_op)
	assert_false(applied_duplicate, "apply_remote_operation is idempotent (duplicate rejected)")

	# 3. Conflict resolution tests
	# 3a. Different resources -> "no_conflict"
	var op_diff_1 = {
		"op_type": SpaceStateMachine.OP_MODULE_LOAD,
		"data": {"module_id": "mod_a"}
	}
	var op_diff_2 = {
		"op_type": SpaceStateMachine.OP_MODULE_LOAD,
		"data": {"module_id": "mod_b"}
	}
	assert_eq(sm._resolve_conflict(op_diff_1, op_diff_2), "no_conflict", "_resolve_conflict: different modules = no_conflict")

	# 3b. Load vs Unload -> "unload_wins"
	var op_load = {
		"op_type": SpaceStateMachine.OP_MODULE_LOAD,
		"data": {"module_id": "mod_target"}
	}
	var op_unload = {
		"op_type": SpaceStateMachine.OP_MODULE_UNLOAD,
		"data": {"module_id": "mod_target"}
	}
	assert_eq(sm._resolve_conflict(op_load, op_unload), "unload_wins", "_resolve_conflict: load vs unload = unload_wins")
	assert_eq(sm._resolve_conflict(op_unload, op_load), "unload_wins", "_resolve_conflict: unload vs load = unload_wins")

	# 3c. Edit vs Edit (Last-Writer-Wins)
	var op_edit_old = {
		"op_type": SpaceStateMachine.OP_MODULE_EDIT,
		"timestamp": 100.0,
		"author_id": 1,
		"data": {"module_id": "mod_edit"}
	}
	var op_edit_new = {
		"op_type": SpaceStateMachine.OP_MODULE_EDIT,
		"timestamp": 200.0,
		"author_id": 2,
		"data": {"module_id": "mod_edit"}
	}
	assert_eq(sm._resolve_conflict(op_edit_old, op_edit_new), "remote_wins", "_resolve_conflict: remote newer timestamp = remote_wins")
	assert_eq(sm._resolve_conflict(op_edit_new, op_edit_old), "local_wins", "_resolve_conflict: remote older timestamp = local_wins")

	# 3d. Tie-break by author_id
	var op_tie_1 = {
		"op_type": SpaceStateMachine.OP_MODULE_EDIT,
		"timestamp": 500.0,
		"author_id": 1,
		"data": {"module_id": "mod_tie"}
	}
	var op_tie_2 = {
		"op_type": SpaceStateMachine.OP_MODULE_EDIT,
		"timestamp": 500.0,
		"author_id": 3,
		"data": {"module_id": "mod_tie"}
	}
	assert_eq(sm._resolve_conflict(op_tie_1, op_tie_2), "remote_wins", "_resolve_conflict: equal timestamp tie-break by higher author_id = remote_wins")
	assert_eq(sm._resolve_conflict(op_tie_2, op_tie_1), "local_wins", "_resolve_conflict: equal timestamp tie-break by lower author_id = local_wins")

	# 4. Conflict rejection in apply_remote_operation
	# Apply local UNLOAD for "secure_module"
	sm.apply_local_operation(SpaceStateMachine.OP_MODULE_UNLOAD, {"module_id": "secure_module"})
	# Remote tries to LOAD "secure_module"
	var remote_load_conflict = {
		"op_id": "remote_load_conflict_01",
		"op_type": SpaceStateMachine.OP_MODULE_LOAD,
		"author_id": 2,
		"timestamp": Time.get_unix_time_from_system() + 50.0,
		"data": {"module_id": "secure_module", "source_code": "extends Node\n"},
		"vector_clock": {2: 5}
	}
	var rejected = not sm.apply_remote_operation(remote_load_conflict)
	assert_true(rejected, "apply_remote_operation rejects remote load when local has unload")

	# 5. Handle message protocol
	var synced_received := [false]
	sm.state_synced.connect(func(peer_id, count): synced_received[0] = true)

	sm.handle_message(2, "space_sync", {
		"type": "state_full",
		"ops": [
			{
				"op_id": "synced_op_1",
				"op_type": SpaceStateMachine.OP_SETTING_CHANGE,
				"author_id": 2,
				"timestamp": 10.0,
				"data": {"key": "val"},
				"vector_clock": {2: 10}
			}
		],
		"vector_clock": {2: 10}
	})

	assert_true(synced_received[0], "handle_message('state_full') emits state_synced")
	assert_eq(sm.get_vector_clock().get(2), 10, "handle_message('state_full') merges clock")

	sm.free()
