class_name LANDiscovery
extends Node

## LAN Discovery Layer for UniCORE
## Uses UDP broadcast datagrams via PacketPeerUDP to announce and discover
## neighbor UniCORE nodes on the local area network.

signal peer_discovered(peer_info: Dictionary)
signal peer_lost(address: String)

const DEFAULT_DISCOVERY_PORT: int = 7778
const DEFAULT_TRANSPORT_PORT: int = 7777
const ANNOUNCE_TYPE: String = "unicore_announce"
const DEFAULT_VERSION: String = "0.3.0"

@export var peer_timeout: float = 10.0
@export var broadcast_address: String = "255.255.255.255"
@export var allow_self_discovery: bool = false

# Sockets
var _broadcaster_peer: PacketPeerUDP = null
var _listener_peer: PacketPeerUDP = null

# State
var _is_broadcasting: bool = false
var _is_listening: bool = false
var _broadcast_port: int = DEFAULT_DISCOVERY_PORT
var _listen_port: int = DEFAULT_DISCOVERY_PORT
var _broadcast_interval: float = 2.0
var _broadcast_timer: float = 0.0
var _cleanup_timer: float = 0.0

var _node_id: String = ""

var _broadcast_payload: Dictionary = {
	"type": ANNOUNCE_TYPE,
	"version": DEFAULT_VERSION,
	"name": "UniCORE Node",
	"port": DEFAULT_TRANSPORT_PORT,
	"modules_count": 0
}

# Discovered peers: key ("address:port") -> peer_info Dictionary
var _discovered_peers: Dictionary = {}
var _peers_last_seen: Dictionary = {} # key -> float (seconds)

func _init() -> void:
	# Generate a random unique ID to identify this node instance
	_node_id = "%d_%d" % [Time.get_ticks_usec(), randi()]

func _exit_tree() -> void:
	stop_broadcasting()
	stop_listening()

func _process(delta: float) -> void:
	# Broadcast tick
	if _is_broadcasting and _broadcaster_peer != null:
		_broadcast_timer += delta
		if _broadcast_timer >= _broadcast_interval:
			_broadcast_timer = 0.0
			_send_broadcast_packet()

	# Listening tick
	if _is_listening and _listener_peer != null:
		_process_incoming_packets()
		_cleanup_stale_peers(delta)

# --- Public API ---

func start_broadcasting(port: int = DEFAULT_DISCOVERY_PORT, interval_sec: float = 2.0) -> void:
	if _is_broadcasting:
		stop_broadcasting()

	var peer: PacketPeerUDP = PacketPeerUDP.new()
	peer.set_broadcast_enabled(true)
	var err: Error = peer.set_dest_address(broadcast_address, port)
	if err != OK:
		push_error("LANDiscovery: Failed to set broadcast destination to %s:%d: %s" % [broadcast_address, port, error_string(err)])
		peer.close()
		return

	_broadcaster_peer = peer
	_broadcast_port = port
	_broadcast_interval = interval_sec
	_is_broadcasting = true
	_broadcast_timer = 0.0 # First broadcast is sent immediately below; reset timer for next interval
	_send_broadcast_packet()

func stop_broadcasting() -> void:
	_is_broadcasting = false
	if _broadcaster_peer != null:
		_broadcaster_peer.close()
		_broadcaster_peer = null
	_broadcast_timer = 0.0

func start_listening(port: int = DEFAULT_DISCOVERY_PORT) -> void:
	if _is_listening:
		stop_listening()

	var peer: PacketPeerUDP = PacketPeerUDP.new()
	var err: Error = peer.bind(port, "*")
	if err != OK:
		push_error("LANDiscovery: Failed to bind listening socket on port %d: %s" % [port, error_string(err)])
		peer.close()
		return

	_listener_peer = peer
	_listen_port = port
	_is_listening = true

func stop_listening() -> void:
	_is_listening = false
	if _listener_peer != null:
		_listener_peer.close()
		_listener_peer = null

	_discovered_peers.clear()
	_peers_last_seen.clear()

func get_discovered_peers() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for p in _discovered_peers.values():
		var copy: Dictionary = (p as Dictionary).duplicate()
		result.append(copy)
	return result

func is_broadcasting() -> bool:
	return _is_broadcasting and _broadcaster_peer != null

func is_listening() -> bool:
	return _is_listening and _listener_peer != null and _listener_peer.is_bound()

func set_broadcast_payload(payload: Dictionary) -> void:
	if payload.has("name"):
		_broadcast_payload["name"] = String(payload["name"])
	if payload.has("version"):
		_broadcast_payload["version"] = String(payload["version"])
	if payload.has("port"):
		_broadcast_payload["port"] = int(payload["port"])
	if payload.has("modules_count"):
		_broadcast_payload["modules_count"] = int(payload["modules_count"])
	for key in payload.keys():
		if not key in ["type", "name", "version", "port", "modules_count"]:
			_broadcast_payload[key] = payload[key]
	_broadcast_payload["type"] = ANNOUNCE_TYPE

func get_broadcast_payload() -> Dictionary:
	return _broadcast_payload.duplicate()

func get_node_id() -> String:
	return _node_id

# --- Internal Packet Processing ---

func _send_broadcast_packet() -> void:
	if _broadcaster_peer == null:
		return

	var packet_data: Dictionary = _broadcast_payload.duplicate()
	packet_data["type"] = ANNOUNCE_TYPE
	packet_data["timestamp"] = int(Time.get_unix_time_from_system())
	packet_data["node_id"] = _node_id

	var json_str: String = JSON.stringify(packet_data)
	var buffer: PackedByteArray = json_str.to_utf8_buffer()
	var err: Error = _broadcaster_peer.put_packet(buffer)
	if err != OK:
		push_warning("LANDiscovery: Failed to broadcast datagram: %s" % error_string(err))

func _process_incoming_packets() -> void:
	if _listener_peer == null:
		return

	while _listener_peer.get_available_packet_count() > 0:
		var pkt: PackedByteArray = _listener_peer.get_packet()
		var sender_ip: String = _listener_peer.get_packet_ip()
		if sender_ip.is_empty() or sender_ip == "0.0.0.0":
			sender_ip = "127.0.0.1"

		var json_str: String = pkt.get_string_from_utf8()

		var parsed: Variant = JSON.parse_string(json_str)
		if typeof(parsed) != TYPE_DICTIONARY:
			continue

		var data: Dictionary = parsed
		if String(data.get("type", "")) != ANNOUNCE_TYPE:
			continue

		# Ignore self-broadcasts unless explicitly allowed
		if String(data.get("node_id", "")) == _node_id and not allow_self_discovery:
			continue

		var transport_port: int = int(data.get("port", DEFAULT_TRANSPORT_PORT))
		var peer_key: String = "%s:%d" % [sender_ip, transport_port]
		var is_new: bool = not _discovered_peers.has(peer_key)

		var peer_info: Dictionary = {
			"address": sender_ip,
			"port": transport_port,
			"name": String(data.get("name", "Unknown")),
			"version": String(data.get("version", DEFAULT_VERSION)),
			"modules_count": int(data.get("modules_count", 0))
		}

		var old_info: Dictionary = _discovered_peers.get(peer_key, {})
		var info_changed: bool = (not is_new) and (old_info != peer_info)

		_discovered_peers[peer_key] = peer_info
		_peers_last_seen[peer_key] = Time.get_ticks_msec() / 1000.0

		if is_new or info_changed:
			peer_discovered.emit(peer_info)

func _cleanup_stale_peers(delta: float) -> void:
	_cleanup_timer += delta
	if _cleanup_timer < 0.2:
		return
	_cleanup_timer = 0.0

	var now: float = Time.get_ticks_msec() / 1000.0
	var stale_keys: Array[String] = []

	for key in _peers_last_seen.keys():
		var last_seen: float = float(_peers_last_seen.get(key, 0.0))
		if (now - last_seen) > peer_timeout:
			stale_keys.append(key)

	for key in stale_keys:
		var info: Dictionary = _discovered_peers.get(key, {})
		var addr: String = String(info.get("address", key.split(":")[0]))
		_discovered_peers.erase(key)
		_peers_last_seen.erase(key)
		peer_lost.emit(addr)
