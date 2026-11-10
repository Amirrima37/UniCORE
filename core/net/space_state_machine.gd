class_name SpaceStateMachine
extends Node

## Reactive Space State Machine & Conflict Resolution for UniCORE.
## Synchronizes space mutations in real-time over NetworkTransport (channel "space_sync").
## Provides causal vector clock ordering and Last-Writer-Wins / Unload-Priority conflict resolution.

signal operation_applied(op: Dictionary)
signal conflict_detected(local_op: Dictionary, remote_op: Dictionary, resolution: String)
signal state_synced(peer_id: int, ops_count: int)

const CHANNEL_NAME: String = "space_sync"
const MAX_LOG_SIZE: int = 100
const OP_MODULE_LOAD: String = "module_load"
const OP_MODULE_UNLOAD: String = "module_unload"
const OP_MODULE_EDIT: String = "module_edit"
const OP_SETTING_CHANGE: String = "setting_change"
const OP_SPACE_SWITCH: String = "space_switch"

const VectorClock = preload("res://core/net/vector_clock.gd")

var _transport: NetworkTransport = null
var _module_manager: ModuleManager = null
var _space_manager: Node = null
var _vector_clock: VectorClock
var _op_log: Array[Dictionary] = [] # Up to MAX_LOG_SIZE operations
var _applied_op_ids: Dictionary = {} # op_id -> bool for idempotency
var _local_peer_id: int = 1
var _is_applying_remote: bool = false
var _is_applying_local: bool = false

func _init() -> void:
	_vector_clock = VectorClock.new()

func _exit_tree() -> void:
	_disconnect_signals()

func setup(transport: NetworkTransport, module_manager: ModuleManager = null, space_manager: Node = null, local_peer_id: int = 1) -> void:
	_disconnect_signals()

	_transport = transport
	_module_manager = module_manager
	_space_manager = space_manager
	_local_peer_id = local_peer_id

	if _vector_clock == null:
		_vector_clock = VectorClock.new()

	if _transport != null and is_instance_valid(_transport):
		if _transport.has_signal("message_received"):
			_transport.message_received.connect(_on_transport_message_received)
		if _transport.has_signal("peer_connected"):
			_transport.peer_connected.connect(_on_transport_peer_connected)

	if _module_manager != null and is_instance_valid(_module_manager):
		if _module_manager.has_signal("module_loaded"):
			_module_manager.module_loaded.connect(_on_module_manager_module_loaded)
		if _module_manager.has_signal("module_unloaded"):
			_module_manager.module_unloaded.connect(_on_module_manager_module_unloaded)

func apply_local_operation(op_type: String, data: Dictionary) -> Dictionary:
	_vector_clock.increment(_local_peer_id)

	var op_id: String = "op_%d_%d" % [Time.get_ticks_usec(), randi()]
	var op: Dictionary = {
		"op_id": op_id,
		"op_type": op_type,
		"author_id": _local_peer_id,
		"timestamp": Time.get_unix_time_from_system(),
		"data": data.duplicate(true),
		"vector_clock": _vector_clock.to_dict()
	}

	_op_log.append(op)
	if _op_log.size() > MAX_LOG_SIZE:
		_op_log.pop_front()
	_applied_op_ids[op_id] = true

	# Local application if needed
	_is_applying_local = true
	_apply_to_subsystems(op_type, data)
	_is_applying_local = false

	# Broadcast to peers
	_broadcast_packet({
		"type": "op",
		"op": op
	})

	operation_applied.emit(op)
	return op

func apply_remote_operation(op: Dictionary) -> bool:
	if op.is_empty():
		return false

	var op_id: String = str(op.get("op_id", ""))
	if op_id.is_empty() or _applied_op_ids.has(op_id):
		return false

	var op_clock: Dictionary = op.get("vector_clock", {})
	if not op_clock.is_empty():
		_vector_clock.merge(op_clock)

	# Check conflicts against recent operations in reverse order (newest to oldest)
	var is_rejected: bool = false
	for i in range(_op_log.size() - 1, -1, -1):
		var recent_op: Dictionary = _op_log[i]
		var resolution: String = _resolve_conflict(recent_op, op)
		if resolution != "no_conflict":
			conflict_detected.emit(recent_op, op, resolution)
			if resolution == "reject_remote" or resolution == "local_wins" or (resolution == "unload_wins" and str(recent_op.get("op_type", "")) == OP_MODULE_UNLOAD):
				is_rejected = true
				break
			elif resolution == "remote_wins" or (resolution == "unload_wins" and str(op.get("op_type", "")) == OP_MODULE_UNLOAD):
				# Remote operation wins against this recent operation
				break

	if is_rejected:
		_applied_op_ids[op_id] = true
		return false

	_is_applying_remote = true
	var op_type: String = str(op.get("op_type", ""))
	var data: Dictionary = op.get("data", {})
	_apply_to_subsystems(op_type, data)
	_is_applying_remote = false

	_op_log.append(op)
	if _op_log.size() > MAX_LOG_SIZE:
		_op_log.pop_front()
	_applied_op_ids[op_id] = true

	operation_applied.emit(op)
	return true

func _resolve_conflict(local_op: Dictionary, remote_op: Dictionary) -> String:
	var local_type: String = str(local_op.get("op_type", ""))
	var remote_type: String = str(remote_op.get("op_type", ""))
	var local_data: Dictionary = local_op.get("data", {})
	var remote_data: Dictionary = remote_op.get("data", {})

	var is_local_mod: bool = local_type in [OP_MODULE_LOAD, OP_MODULE_UNLOAD, OP_MODULE_EDIT]
	var is_remote_mod: bool = remote_type in [OP_MODULE_LOAD, OP_MODULE_UNLOAD, OP_MODULE_EDIT]

	if is_local_mod and is_remote_mod:
		var local_mid: String = str(local_data.get("module_id", ""))
		var remote_mid: String = str(remote_data.get("module_id", ""))
		if local_mid.is_empty() or remote_mid.is_empty() or local_mid != remote_mid:
			return "no_conflict"

		# Conflict between LOAD / EDIT and UNLOAD for the same module: unload always wins
		if (local_type == OP_MODULE_UNLOAD and remote_type in [OP_MODULE_LOAD, OP_MODULE_EDIT]) \
			or (remote_type == OP_MODULE_UNLOAD and local_type in [OP_MODULE_LOAD, OP_MODULE_EDIT]):
			return "unload_wins"

		# Concurrent edits / loads on the same module: Last-Writer-Wins
		var local_ts: float = float(local_op.get("timestamp", 0.0))
		var remote_ts: float = float(remote_op.get("timestamp", 0.0))
		if remote_ts > local_ts:
			return "remote_wins"
		elif remote_ts < local_ts:
			return "local_wins"
		else:
			# Equal timestamp: tie-break by author_id
			var local_author: int = int(local_op.get("author_id", 0))
			var remote_author: int = int(remote_op.get("author_id", 0))
			return "remote_wins" if remote_author > local_author else "local_wins"

	if local_type == OP_SPACE_SWITCH and remote_type == OP_SPACE_SWITCH:
		var local_space: String = str(local_data.get("space_id", ""))
		var remote_space: String = str(remote_data.get("space_id", ""))
		if local_space.is_empty() or remote_space.is_empty() or local_space == remote_space:
			return "no_conflict"

		var local_ts: float = float(local_op.get("timestamp", 0.0))
		var remote_ts: float = float(remote_op.get("timestamp", 0.0))
		if remote_ts > local_ts:
			return "remote_wins"
		elif remote_ts < local_ts:
			return "local_wins"
		else:
			var local_author: int = int(local_op.get("author_id", 0))
			var remote_author: int = int(remote_op.get("author_id", 0))
			return "remote_wins" if remote_author > local_author else "local_wins"

	return "no_conflict"

func get_operation_log() -> Array[Dictionary]:
	return _op_log.duplicate(true)

func get_vector_clock() -> Dictionary:
	return _vector_clock.to_dict() if _vector_clock != null else {}

func sync_state_with_peer(peer_id: int) -> void:
	if _transport == null:
		return

	var is_host: bool = false
	if _transport.has_method("is_hosting"):
		is_host = _transport.is_hosting()
	elif _local_peer_id == 1:
		is_host = true

	if is_host or not _op_log.is_empty():
		_send_packet(peer_id, {
			"type": "state_full",
			"ops": _op_log.duplicate(true),
			"vector_clock": _vector_clock.to_dict()
		})
	else:
		_send_packet(peer_id, {
			"type": "state_request"
		})

func handle_message(peer_id: int, channel: String, data: Dictionary) -> void:
	if not channel.is_empty() and channel != CHANNEL_NAME:
		return

	var msg_type: String = str(data.get("type", ""))
	match msg_type:
		"op":
			var op_data: Dictionary = data.get("op", {})
			if not op_data.is_empty():
				apply_remote_operation(op_data)
		"state_request":
			_send_packet(peer_id, {
				"type": "state_full",
				"ops": _op_log.duplicate(true),
				"vector_clock": _vector_clock.to_dict()
			})
		"state_full":
			var remote_clock: Dictionary = data.get("vector_clock", {})
			if not remote_clock.is_empty():
				_vector_clock.merge(remote_clock)
			var ops: Array = data.get("ops", [])
			for item in ops:
				if item is Dictionary:
					apply_remote_operation(item)
			state_synced.emit(peer_id, ops.size())

# --- Internal helpers ---

func _apply_to_subsystems(op_type: String, data: Dictionary) -> void:
	match op_type:
		OP_MODULE_LOAD, OP_MODULE_EDIT:
			if _module_manager != null and data.has("module_id"):
				var mid: String = str(data["module_id"])
				var source: String = str(data.get("source_code", ""))
				if not source.is_empty():
					var existing: Node = _module_manager.get_module(mid)
					if existing == null or op_type == OP_MODULE_EDIT:
						_module_manager.load_module_from_source(mid, source)
		OP_MODULE_UNLOAD:
			if _module_manager != null and data.has("module_id"):
				var mid: String = str(data["module_id"])
				if _module_manager.get_module(mid) != null:
					_module_manager.unload_module(mid)
		OP_SPACE_SWITCH:
			if _space_manager != null and data.has("space_id"):
				var sid: String = str(data["space_id"])
				if _space_manager.has_method("load_space"):
					_space_manager.load_space(sid)

func _send_packet(peer_id: int, payload: Dictionary) -> void:
	if _transport == null:
		return
	if _transport.has_method("send_message"):
		_transport.send_message(peer_id, CHANNEL_NAME, payload)
	elif _transport.has_method("send_to_peer"):
		_transport.send_to_peer(peer_id, CHANNEL_NAME, payload)

func _broadcast_packet(payload: Dictionary) -> void:
	if _transport == null:
		return
	if _transport.has_method("broadcast"):
		_transport.broadcast(CHANNEL_NAME, payload)
	elif _transport.has_method("broadcast_message"):
		_transport.broadcast_message(CHANNEL_NAME, payload)

func _disconnect_signals() -> void:
	if _transport != null and is_instance_valid(_transport):
		if _transport.has_signal("message_received") and _transport.message_received.is_connected(_on_transport_message_received):
			_transport.message_received.disconnect(_on_transport_message_received)
		if _transport.has_signal("peer_connected") and _transport.peer_connected.is_connected(_on_transport_peer_connected):
			_transport.peer_connected.disconnect(_on_transport_peer_connected)

	if _module_manager != null and is_instance_valid(_module_manager):
		if _module_manager.has_signal("module_loaded") and _module_manager.module_loaded.is_connected(_on_module_manager_module_loaded):
			_module_manager.module_loaded.disconnect(_on_module_manager_module_loaded)
		if _module_manager.has_signal("module_unloaded") and _module_manager.module_unloaded.is_connected(_on_module_manager_module_unloaded):
			_module_manager.module_unloaded.disconnect(_on_module_manager_module_unloaded)

func _on_transport_message_received(peer_id: int, channel: String, data: Dictionary) -> void:
	if channel == CHANNEL_NAME:
		handle_message(peer_id, channel, data)

func _on_transport_peer_connected(peer_id: int, _peer_info: Dictionary = {}) -> void:
	sync_state_with_peer(peer_id)

func _on_module_manager_module_loaded(module_id: String, instance: Node) -> void:
	if _is_applying_remote or _is_applying_local:
		return
	var source_code: String = ""
	if instance != null and instance.get_script() != null:
		var script: Script = instance.get_script()
		source_code = script.source_code
	apply_local_operation(OP_MODULE_LOAD, {
		"module_id": module_id,
		"source_code": source_code
	})

func _on_module_manager_module_unloaded(module_id: String) -> void:
	if _is_applying_remote or _is_applying_local:
		return
	apply_local_operation(OP_MODULE_UNLOAD, {
		"module_id": module_id
	})
