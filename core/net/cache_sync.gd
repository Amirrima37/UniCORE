class_name CacheSync
extends Node

## CacheSync — Сетевая синхронизация семантического кэша модулей UniCORE.
## Обеспечивает P2P-поиск и распространение модулей через NetworkTransport (канал "cache_sync").

signal network_search_completed(request_id: String, results: Array)
signal cache_sync_received(peer_id: int, count: int)
signal cache_announce_received(peer_id: int, module_summaries: Array)

const CHANNEL_NAME: String = "cache_sync"
const SemanticCache = preload("res://core/semantic_cache.gd")

var _transport: NetworkTransport = null
var _cache: SemanticCache = null
var _sharing: ModuleSharing = null
var _pending_queries: Dictionary = {} # request_id -> { "timer": float, "results": Array, "peers_responded": Array }
var last_request_id: String = ""

func _exit_tree() -> void:
	if _transport != null and is_instance_valid(_transport):
		if _transport.has_signal("message_received") and _transport.message_received.is_connected(_on_transport_message_received):
			_transport.message_received.disconnect(_on_transport_message_received)
		if _transport.has_signal("peer_connected") and _transport.peer_connected.is_connected(_on_peer_connected):
			_transport.peer_connected.disconnect(_on_peer_connected)

func setup(transport: NetworkTransport, cache: SemanticCache, sharing: ModuleSharing = null) -> void:
	if _transport != null and is_instance_valid(_transport):
		if _transport.has_signal("message_received") and _transport.message_received.is_connected(_on_transport_message_received):
			_transport.message_received.disconnect(_on_transport_message_received)
		if _transport.has_signal("peer_connected") and _transport.peer_connected.is_connected(_on_peer_connected):
			_transport.peer_connected.disconnect(_on_peer_connected)

	_transport = transport
	_cache = cache
	_sharing = sharing

	if _transport != null and is_instance_valid(_transport):
		if _transport.has_signal("message_received") and not _transport.message_received.is_connected(_on_transport_message_received):
			_transport.message_received.connect(_on_transport_message_received)
		if _transport.has_signal("peer_connected") and not _transport.peer_connected.is_connected(_on_peer_connected):
			_transport.peer_connected.connect(_on_peer_connected)

func query_network(query: String, timeout_sec: float = 3.0) -> Array[Dictionary]:
	last_request_id = ""
	var empty_results: Array[Dictionary] = []

	if _transport == null or not is_instance_valid(_transport):
		return empty_results

	var peers: Array[int] = _transport.get_connected_peers()
	if peers.is_empty():
		return empty_results

	var request_id: String = "req_%d_%d" % [Time.get_ticks_msec(), randi() % 10000]
	last_request_id = request_id

	_pending_queries[request_id] = {
		"timer": timeout_sec,
		"results": [],
		"peers_responded": []
	}

	var packet: Dictionary = {
		"type": "cache_query",
		"query": query,
		"request_id": request_id
	}
	_transport.broadcast(CHANNEL_NAME, packet)

	return empty_results

func announce_cache(peer_id: int = 0) -> void:
	if _cache == null or not is_instance_valid(_cache):
		return

	var module_summaries: Array = []
	var verified_modules: Array[Dictionary] = _cache.get_all_verified()
	for m in verified_modules:
		module_summaries.append({
			"id": m.get("id", ""),
			"name": m.get("name", ""),
			"source_hash": m.get("source_hash", ""),
			"tags": m.get("tags", []),
			"reputation": m.get("reputation", 0.5)
		})

	var packet: Dictionary = {
		"type": "cache_announce",
		"modules": module_summaries
	}

	if _transport != null and is_instance_valid(_transport):
		if peer_id > 0:
			_transport.send_to_peer(peer_id, CHANNEL_NAME, packet)
		else:
			_transport.broadcast(CHANNEL_NAME, packet)

func _on_peer_connected(peer_id: int, _info: Dictionary) -> void:
	announce_cache(peer_id)

func _on_transport_message_received(peer_id: int, channel: String, data: Dictionary) -> void:
	if channel != CHANNEL_NAME:
		return
	handle_message(peer_id, channel, data)

func handle_message(peer_id: int, _channel: String, data: Dictionary) -> void:
	var msg_type: String = str(data.get("type", ""))

	match msg_type:
		"cache_query":
			if _cache != null and is_instance_valid(_cache):
				var query_str: String = str(data.get("query", ""))
				var req_id: String = str(data.get("request_id", ""))
				var found_results: Array[Dictionary] = _cache.search(query_str, 3, 0.25)
				if not found_results.is_empty() and _transport != null and is_instance_valid(_transport):
					var results_packet: Dictionary = {
						"type": "cache_results",
						"request_id": req_id,
						"results": found_results
					}
					_transport.send_to_peer(peer_id, CHANNEL_NAME, results_packet)

		"cache_results":
			var req_id: String = str(data.get("request_id", ""))
			var incoming_results: Array = data.get("results", [])
			if _pending_queries.has(req_id):
				var pending: Dictionary = _pending_queries[req_id]
				var current_results: Array = pending.get("results", [])
				var peers_responded: Array = pending.get("peers_responded", [])
				if not peer_id in peers_responded:
					peers_responded.append(peer_id)

				var seen_hashes: Dictionary = {}
				for item in current_results:
					if item is Dictionary and item.has("source_hash"):
						seen_hashes[item["source_hash"]] = true

				for item in incoming_results:
					if item is Dictionary:
						var sh: String = str(item.get("source_hash", ""))
						if sh.is_empty() or not seen_hashes.has(sh):
							if not sh.is_empty():
								seen_hashes[sh] = true
							current_results.append(item)

				pending["results"] = current_results
				pending["peers_responded"] = peers_responded
				cache_sync_received.emit(peer_id, incoming_results.size())
				network_search_completed.emit(req_id, current_results)
			else:
				cache_sync_received.emit(peer_id, incoming_results.size())
				network_search_completed.emit(req_id, incoming_results)

		"cache_announce":
			var module_summaries: Array = data.get("modules", [])
			cache_announce_received.emit(peer_id, module_summaries)

func _process(delta: float) -> void:
	if _pending_queries.is_empty():
		return

	var expired: Array[String] = []
	for req_id in _pending_queries.keys():
		var entry: Dictionary = _pending_queries[req_id]
		var t: float = float(entry.get("timer", 0.0)) - delta
		entry["timer"] = t
		if t <= 0.0:
			expired.append(req_id)

	for req_id in expired:
		var entry: Dictionary = _pending_queries[req_id]
		var results: Array = entry.get("results", [])
		_pending_queries.erase(req_id)
		network_search_completed.emit(req_id, results)

func get_pending_queries() -> Dictionary:
	return _pending_queries

func has_connected_peers() -> bool:
	if _transport == null or not is_instance_valid(_transport):
		return false
	return not _transport.get_connected_peers().is_empty()
