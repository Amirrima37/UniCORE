class_name NetworkTransport
extends Node

## Network Transport Layer for UniCORE
## Abstract transport layer on top of Godot 4 ENetMultiplayerPeer.
## Provides session hosting, joining, peer discovery, heartbeat ping/pong,
## and typed multi-channel reliable messaging.

# Signals as specified in task
signal peer_connected(peer_id: int, peer_info: Dictionary)
signal peer_disconnected(peer_id: int)
signal message_received(peer_id: int, channel: String, data: Dictionary)
signal connection_status_changed(status: String) # "disconnected", "connecting", "connected", "hosting"

# Supported channels
const CHANNEL_MODULE_SHARE: String = "module_share"
const CHANNEL_SPACE_SYNC: String = "space_sync"
const CHANNEL_CHAT: String = "chat"
const CHANNEL_DISCOVERY: String = "discovery"
const CHANNEL_HEARTBEAT: String = "heartbeat"
const CHANNEL_CACHE_SYNC: String = "cache_sync"

const SUPPORTED_CHANNELS: Array[String] = [
	CHANNEL_MODULE_SHARE,
	CHANNEL_SPACE_SYNC,
	CHANNEL_CHAT,
	CHANNEL_DISCOVERY,
	CHANNEL_HEARTBEAT,
	CHANNEL_CACHE_SYNC
]

# Status definitions
const STATUS_DISCONNECTED: String = "disconnected"
const STATUS_CONNECTING: String = "connecting"
const STATUS_CONNECTED: String = "connected"
const STATUS_HOSTING: String = "hosting"

# Configuration
const DEFAULT_PORT: int = 7777
const MAX_CLIENTS: int = 32

@export var heartbeat_interval: float = 5.0
@export var heartbeat_timeout: float = 15.0

# Internal state
var _peer: ENetMultiplayerPeer = null
var _custom_multiplayer: MultiplayerAPI = null
var _status: String = STATUS_DISCONNECTED

var _local_peer_info: Dictionary = {
	"id": 0,
	"name": "UniNode",
	"ip": "127.0.0.1",
	"port": DEFAULT_PORT,
	"modules_count": 0,
	"space_name": "Default Studio"
}

var _connected_peers: Array[int] = []
var _peers_info: Dictionary = {} # peer_id (int) -> Dictionary
var _peer_last_seen: Dictionary = {} # peer_id (int) -> float (sec)
var _peers_rtt: Dictionary = {} # peer_id (int) -> int (ms)
var _heartbeat_timer: float = 0.0

func _ready() -> void:
	var mp: MultiplayerAPI = _get_mp()
	if mp != null:
		_connect_multiplayer_signals(mp)

func _exit_tree() -> void:
	disconnect_session()
	var mp: MultiplayerAPI = _get_mp()
	if mp != null:
		_disconnect_multiplayer_signals(mp)

func _process(delta: float) -> void:
	if _peer == null or _status == STATUS_DISCONNECTED:
		return

	# Heartbeat sending
	_heartbeat_timer += delta
	if _heartbeat_timer >= heartbeat_interval:
		_heartbeat_timer = 0.0
		_send_heartbeat_ping()

	# Heartbeat timeout check
	_check_peer_timeouts()

# --- Public API ---

func host_session(port: int = DEFAULT_PORT) -> Error:
	if _peer != null:
		disconnect_session()

	var new_peer: ENetMultiplayerPeer = ENetMultiplayerPeer.new()
	var err: Error = new_peer.create_server(port, MAX_CLIENTS)
	if err != OK:
		push_error("NetworkTransport: Failed to create server on port %d: %s" % [port, error_string(err)])
		return err

	_peer = new_peer
	var mp: MultiplayerAPI = _get_mp()
	if mp == null:
		push_error("NetworkTransport: MultiplayerAPI is not available. Ensure node is in SceneTree.")
		_peer.close()
		_peer = null
		return ERR_UNCONFIGURED

	_connect_multiplayer_signals(mp)
	mp.multiplayer_peer = _peer

	_local_peer_info["id"] = 1
	_local_peer_info["port"] = port
	if _local_peer_info.get("ip", "127.0.0.1") == "127.0.0.1":
		_local_peer_info["ip"] = _detect_local_ip()

	_status = STATUS_HOSTING
	connection_status_changed.emit(_status)
	return OK

func join_session(address: String, port: int = DEFAULT_PORT) -> Error:
	if _peer != null:
		disconnect_session()

	var target_addr: String = address
	if target_addr.is_empty():
		target_addr = "127.0.0.1"

	var new_peer: ENetMultiplayerPeer = ENetMultiplayerPeer.new()
	var err: Error = new_peer.create_client(target_addr, port)
	if err != OK:
		push_error("NetworkTransport: Failed to create client connecting to %s:%d: %s" % [target_addr, port, error_string(err)])
		return err

	_peer = new_peer
	var mp: MultiplayerAPI = _get_mp()
	if mp == null:
		push_error("NetworkTransport: MultiplayerAPI is not available. Ensure node is in SceneTree.")
		_peer.close()
		_peer = null
		return ERR_UNCONFIGURED

	_connect_multiplayer_signals(mp)
	mp.multiplayer_peer = _peer

	_local_peer_info["port"] = port
	if _local_peer_info.get("ip", "127.0.0.1") == "127.0.0.1":
		_local_peer_info["ip"] = _detect_local_ip()

	_status = STATUS_CONNECTING
	connection_status_changed.emit(_status)
	return OK

func disconnect_session() -> void:
	if _peer == null and _status == STATUS_DISCONNECTED:
		return

	var mp: MultiplayerAPI = _get_mp()
	if mp != null and mp.multiplayer_peer == _peer:
		mp.multiplayer_peer = null

	if _peer != null:
		_peer.close()
		_peer = null

	var previous_peers: Array[int] = _connected_peers.duplicate()
	_connected_peers.clear()
	_peers_info.clear()
	_peer_last_seen.clear()
	_peers_rtt.clear()
	_heartbeat_timer = 0.0
	_local_peer_info["id"] = 0

	for pid in previous_peers:
		peer_disconnected.emit(pid)

	if _status != STATUS_DISCONNECTED:
		_status = STATUS_DISCONNECTED
		connection_status_changed.emit(_status)

func send_to_peer(peer_id: int, channel: String, data: Dictionary) -> void:
	if not channel in SUPPORTED_CHANNELS:
		push_warning("NetworkTransport: Unsupported channel '%s'. Packet not sent." % channel)
		return

	if _peer == null or _peer.get_connection_status() != MultiplayerPeer.CONNECTION_CONNECTED:
		push_warning("NetworkTransport: Cannot send packet, transport is not connected.")
		return

	if peer_id <= 0:
		push_warning("NetworkTransport: Invalid peer_id %d. Packet not sent." % peer_id)
		return

	if not peer_id in _connected_peers and not (peer_id == 1 and is_connected_to_host()):
		push_warning("NetworkTransport: Peer %d is not connected. Packet not sent." % peer_id)
		return

	var payload_bytes: PackedByteArray = var_to_bytes(data)
	_receive_network_packet.rpc_id(peer_id, channel, payload_bytes)

func send_message(peer_id: int, channel: String, data: Dictionary) -> void:
	send_to_peer(peer_id, channel, data)

func broadcast(channel: String, data: Dictionary) -> void:
	if not channel in SUPPORTED_CHANNELS:
		push_warning("NetworkTransport: Unsupported channel '%s'. Packet not sent." % channel)
		return

	if _peer == null or _peer.get_connection_status() != MultiplayerPeer.CONNECTION_CONNECTED:
		push_warning("NetworkTransport: Cannot broadcast packet, transport is not connected.")
		return

	if _connected_peers.is_empty():
		return

	var payload_bytes: PackedByteArray = var_to_bytes(data)
	for peer_id in _connected_peers.duplicate():
		_receive_network_packet.rpc_id(peer_id, channel, payload_bytes)

func broadcast_message(channel: String, data: Dictionary) -> void:
	broadcast(channel, data)

func get_connected_peers() -> Array[int]:
	return _connected_peers.duplicate()

func get_local_peer_info() -> Dictionary:
	return _local_peer_info.duplicate()

func is_hosting() -> bool:
	return _status == STATUS_HOSTING and _peer != null and _peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED

func is_connected_to_host() -> bool:
	return _status == STATUS_CONNECTED and _peer != null and _peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED

func get_status() -> String:
	return _status

func set_local_peer_info(info: Dictionary) -> void:
	if info.has("name"):
		_local_peer_info["name"] = String(info["name"])
	if info.has("ip"):
		_local_peer_info["ip"] = String(info["ip"])
	if info.has("port"):
		_local_peer_info["port"] = int(info["port"])
	if info.has("modules_count"):
		_local_peer_info["modules_count"] = int(info["modules_count"])
	if info.has("space_name"):
		_local_peer_info["space_name"] = String(info["space_name"])
	if info.has("id") and not (is_hosting() or is_connected_to_host()):
		_local_peer_info["id"] = int(info["id"])

	# Announce updated info to all connected peers if currently active
	if is_hosting() or is_connected_to_host():
		var update_payload: Dictionary = {
			"type": "peer_info",
			"peer_info": get_local_peer_info()
		}
		broadcast(CHANNEL_DISCOVERY, update_payload)

func get_peer_info(peer_id: int) -> Dictionary:
	if peer_id == _local_peer_info.get("id", 0):
		return get_local_peer_info()
	return _peers_info.get(peer_id, {}).duplicate()

func get_peer_latency(peer_id: int) -> int:
	return _peers_rtt.get(peer_id, -1)

func _detect_local_ip() -> String:
	for addr in IP.get_local_addresses():
		if addr.contains(":") or addr.begins_with("127.") or addr.begins_with("169.254."):
			continue
		return addr
	return "127.0.0.1"

func set_custom_multiplayer(custom_mp: MultiplayerAPI) -> void:
	if _custom_multiplayer != null:
		_disconnect_multiplayer_signals(_custom_multiplayer)
	_custom_multiplayer = custom_mp
	if _custom_multiplayer != null:
		_connect_multiplayer_signals(_custom_multiplayer)

# --- Internal Multiplayer & RPC Handling ---

func _get_mp() -> MultiplayerAPI:
	if _custom_multiplayer != null:
		return _custom_multiplayer
	if is_inside_tree():
		return get_multiplayer()
	return null

@rpc("any_peer", "reliable")
func _receive_network_packet(channel: String, payload_bytes: PackedByteArray) -> void:
	if _peer == null or _status == STATUS_DISCONNECTED:
		return

	var mp: MultiplayerAPI = _get_mp()
	var sender_id: int = 1
	if mp != null:
		var remote_sender: int = mp.get_remote_sender_id()
		if remote_sender != 0:
			sender_id = remote_sender

	var current_time: float = Time.get_ticks_msec() / 1000.0
	_peer_last_seen[sender_id] = current_time

	var data_variant: Variant = bytes_to_var(payload_bytes)
	if typeof(data_variant) != TYPE_DICTIONARY:
		push_warning("NetworkTransport: Received malformed non-dictionary packet on channel '%s'" % channel)
		return

	var data: Dictionary = data_variant

	# Heartbeat handling
	if channel == CHANNEL_HEARTBEAT:
		_handle_heartbeat_packet(sender_id, data)
		message_received.emit(sender_id, channel, data)
		return

	# Discovery / handshake handling
	if channel == CHANNEL_DISCOVERY:
		_handle_discovery_packet(sender_id, data)
		message_received.emit(sender_id, channel, data)
		return

	# Standard supported channels
	if channel in SUPPORTED_CHANNELS:
		# Auto-register peer if not registered yet
		if not sender_id in _connected_peers:
			_register_peer_with_info(sender_id, _make_default_peer_info(sender_id))
		message_received.emit(sender_id, channel, data)
	else:
		push_warning("NetworkTransport: Dropped packet on unsupported channel '%s'" % channel)

func _handle_heartbeat_packet(sender_id: int, data: Dictionary) -> void:
	var msg_type: String = String(data.get("type", ""))
	if msg_type == "ping":
		var pong: Dictionary = {
			"type": "pong",
			"timestamp": data.get("timestamp", 0)
		}
		var payload: PackedByteArray = var_to_bytes(pong)
		_receive_network_packet.rpc_id(sender_id, CHANNEL_HEARTBEAT, payload)
	elif msg_type == "pong":
		var sent_time: int = int(data.get("timestamp", 0))
		if sent_time > 0:
			var rtt: int = int(Time.get_ticks_msec()) - sent_time
			_peers_rtt[sender_id] = maxi(0, rtt)

func _handle_discovery_packet(sender_id: int, data: Dictionary) -> void:
	var msg_type: String = String(data.get("type", ""))
	if msg_type == "peer_info" and data.has("peer_info"):
		var info_variant: Variant = data["peer_info"]
		if typeof(info_variant) == TYPE_DICTIONARY:
			var info: Dictionary = info_variant
			_register_peer_with_info(sender_id, info)

func _register_peer_with_info(peer_id: int, info: Dictionary) -> void:
	var is_new: bool = not (peer_id in _connected_peers)
	var merged_info: Dictionary = _peers_info.get(peer_id, _make_default_peer_info(peer_id))
	for k in info.keys():
		merged_info[k] = info[k]
	merged_info["id"] = peer_id
	_peers_info[peer_id] = merged_info
	if is_new:
		_connected_peers.append(peer_id)
		peer_connected.emit(peer_id, merged_info)

func _make_default_peer_info(peer_id: int) -> Dictionary:
	return {
		"id": peer_id,
		"name": "Peer %d" % peer_id,
		"ip": "127.0.0.1",
		"port": DEFAULT_PORT,
		"modules_count": 0,
		"space_name": "Default Studio"
	}

func _send_heartbeat_ping() -> void:
	if _connected_peers.is_empty():
		return
	var ping_data: Dictionary = {
		"type": "ping",
		"timestamp": Time.get_ticks_msec()
	}
	var payload: PackedByteArray = var_to_bytes(ping_data)
	for peer_id in _connected_peers.duplicate():
		_receive_network_packet.rpc_id(peer_id, CHANNEL_HEARTBEAT, payload)

func _check_peer_timeouts() -> void:
	var now: float = Time.get_ticks_msec() / 1000.0
	var timed_out_peers: Array[int] = []
	for peer_id in _connected_peers:
		var last_seen: float = _peer_last_seen.get(peer_id, now)
		if (now - last_seen) > heartbeat_timeout:
			timed_out_peers.append(peer_id)

	for peer_id in timed_out_peers:
		push_warning("NetworkTransport: Peer %d timed out (no heartbeat for > %.1fs)" % [peer_id, heartbeat_timeout])
		if is_hosting():
			if _peer != null:
				_peer.disconnect_peer(peer_id)
			_on_peer_disconnected(peer_id)
		elif is_connected_to_host() and peer_id == 1:
			disconnect_session()
			break
		else:
			_on_peer_disconnected(peer_id)

# --- Multiplayer Signal Handlers ---

func _on_peer_connected(id: int) -> void:
	var current_time: float = Time.get_ticks_msec() / 1000.0
	_peer_last_seen[id] = current_time

	# Immediately transmit local peer info to newly connected peer
	var info_payload: Dictionary = {
		"type": "peer_info",
		"peer_info": get_local_peer_info()
	}
	var bytes: PackedByteArray = var_to_bytes(info_payload)
	_receive_network_packet.rpc_id(id, CHANNEL_DISCOVERY, bytes)

func _on_peer_disconnected(id: int) -> void:
	_peers_info.erase(id)
	_peer_last_seen.erase(id)
	if id in _connected_peers:
		_connected_peers.erase(id)
		peer_disconnected.emit(id)

func _on_connected_to_server() -> void:
	var mp: MultiplayerAPI = _get_mp()
	if mp != null:
		_local_peer_info["id"] = mp.get_unique_id()

	_status = STATUS_CONNECTED
	connection_status_changed.emit(_status)

	# Transmit handshake info to server (peer 1)
	_peer_last_seen[1] = Time.get_ticks_msec() / 1000.0
	var info_payload: Dictionary = {
		"type": "peer_info",
		"peer_info": get_local_peer_info()
	}
	var bytes: PackedByteArray = var_to_bytes(info_payload)
	_receive_network_packet.rpc_id(1, CHANNEL_DISCOVERY, bytes)

func _on_connection_failed() -> void:
	push_warning("NetworkTransport: Connection attempt failed.")
	disconnect_session()

func _on_server_disconnected() -> void:
	push_warning("NetworkTransport: Disconnected from host.")
	disconnect_session()

func _connect_multiplayer_signals(mp: MultiplayerAPI) -> void:
	if mp == null:
		return
	if not mp.peer_connected.is_connected(_on_peer_connected):
		mp.peer_connected.connect(_on_peer_connected)
	if not mp.peer_disconnected.is_connected(_on_peer_disconnected):
		mp.peer_disconnected.connect(_on_peer_disconnected)
	if not mp.connected_to_server.is_connected(_on_connected_to_server):
		mp.connected_to_server.connect(_on_connected_to_server)
	if not mp.connection_failed.is_connected(_on_connection_failed):
		mp.connection_failed.connect(_on_connection_failed)
	if not mp.server_disconnected.is_connected(_on_server_disconnected):
		mp.server_disconnected.connect(_on_server_disconnected)

func _disconnect_multiplayer_signals(mp: MultiplayerAPI) -> void:
	if mp == null:
		return
	if mp.peer_connected.is_connected(_on_peer_connected):
		mp.peer_connected.disconnect(_on_peer_connected)
	if mp.peer_disconnected.is_connected(_on_peer_disconnected):
		mp.peer_disconnected.disconnect(_on_peer_disconnected)
	if mp.connected_to_server.is_connected(_on_connected_to_server):
		mp.connected_to_server.disconnect(_on_connected_to_server)
	if mp.connection_failed.is_connected(_on_connection_failed):
		mp.connection_failed.disconnect(_on_connection_failed)
	if mp.server_disconnected.is_connected(_on_server_disconnected):
		mp.server_disconnected.disconnect(_on_server_disconnected)
