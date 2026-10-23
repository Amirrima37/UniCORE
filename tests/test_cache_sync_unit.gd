extends SceneTree

## Юнит-тесты для сетевой синхронизации семантического кэша (CacheSync) и интеграции с AgentBrain

const SemanticCache = preload("res://core/semantic_cache.gd")
const CacheSync = preload("res://core/net/cache_sync.gd")
const AgentBrain = preload("res://agent/agent_brain.gd")
const ModuleManager = preload("res://core/module_manager.gd")
const EventBus = preload("res://core/event_bus.gd")
const BaseLLMProvider = preload("res://agent/providers/base_llm_provider.gd")
const DiagnosticLogger = preload("res://core/diagnostic_logger.gd")

var passed_count: int = 0
var failed_count: int = 0
var _nodes_to_free: Array[Node] = []

const TEST_CACHE_PATH: String = "user://test_cache_sync_temp.json"

func track_node(node: Node) -> Node:
	_nodes_to_free.append(node)
	return node

func free_tracked_nodes() -> void:
	for node in _nodes_to_free:
		if is_instance_valid(node):
			node.free()
	_nodes_to_free.clear()

func assert_true(condition: bool, test_name: String, error_msg: String = "") -> void:
	if condition:
		print("  [PASS] %s" % test_name)
		passed_count += 1
	else:
		print("  [FAIL] %s - %s" % [test_name, error_msg])
		failed_count += 1

func assert_false(condition: bool, test_name: String, error_msg: String = "") -> void:
	assert_true(not condition, test_name, error_msg)

func assert_eq(a: Variant, b: Variant, test_name: String) -> void:
	if a == b:
		print("  [PASS] %s" % test_name)
		passed_count += 1
	else:
		print("  [FAIL] %s - Expected '%s', got '%s'" % [test_name, str(b), str(a)])
		failed_count += 1

func _cleanup_test_file() -> void:
	if FileAccess.file_exists(TEST_CACHE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_CACHE_PATH))

# --- Mocks ---

class MockTransport extends NetworkTransport:
	var broadcast_calls: Array[Dictionary] = [] # [{channel: String, data: Dictionary}]
	var send_to_peer_calls: Array[Dictionary] = [] # [{peer_id: int, channel: String, data: Dictionary}]
	var connected_peers_list: Array[int] = [10, 20]
	var mock_status: String = "connected"

	func broadcast(channel: String, data: Dictionary) -> void:
		broadcast_calls.append({"channel": channel, "data": data})

	func send_to_peer(peer_id: int, channel: String, data: Dictionary) -> void:
		send_to_peer_calls.append({"peer_id": peer_id, "channel": channel, "data": data})

	func get_connected_peers() -> Array[int]:
		return connected_peers_list.duplicate()

	func get_status() -> String:
		return mock_status

class MockLLMProvider extends BaseLLMProvider:
	var send_count: int = 0
	var last_system_prompt: String = ""
	var last_user_prompt: String = ""
	var next_response: String = ""

	func send_prompt(sys_prompt: String, u_prompt: String, _api_key: String) -> void:
		send_count += 1
		last_system_prompt = sys_prompt
		last_user_prompt = u_prompt
		if not next_response.is_empty():
			var resp := next_response
			next_response = ""
			call_deferred("_deliver_response", resp)

	func _deliver_response(resp: String) -> void:
		response_received.emit(resp)

class MockCacheSync extends "res://core/net/cache_sync.gd":
	var mock_results: Array[Dictionary] = []

	func has_connected_peers() -> bool:
		return true

	func query_network(_query: String, _timeout_sec: float = 3.0) -> Array[Dictionary]:
		return mock_results

# --- Test Runner ---

func _init() -> void:
	print("==================================================")
	print("Starting CacheSync & AgentBrain Integration Test Suite")
	print("==================================================")

	_cleanup_test_file()

	test_cache_sync_packet_formats()
	test_cache_sync_deduplication()
	test_cache_sync_timeout_and_process()
	test_agent_brain_cache_hit_chain()
	test_agent_brain_cache_miss_llm_fallback()
	test_agent_brain_p2p_hit_chain()

	_cleanup_test_file()
	free_tracked_nodes()

	# Cleanup test module artifact if written
	var test_mod_files := [
		"res://modules/orbital_gravity_sim.gd",
		"res://modules/proc_maze_tool.gd",
		"res://modules/p2p_laser_tool.gd"
	]
	for p in test_mod_files:
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(p))

	print("==================================================")
	print("Test Results: %d Passed, %d Failed" % [passed_count, failed_count])
	print("==================================================")

	quit(0 if failed_count == 0 else 1)

# --- Test 1: CacheSync Packet Formats ---
func test_cache_sync_packet_formats() -> void:
	print("\n--- Test Group 1: CacheSync Packet Formats ---")

	var transport := MockTransport.new()
	track_node(transport)
	var cache := SemanticCache.new()
	track_node(cache)
	cache.current_cache_path = TEST_CACHE_PATH
	cache.clear_cache()

	# Add verified module into cache
	var valid_code := """## Name: Лазерный Резак
## Description: Мощный лазерный резак для космических обломков
## Tags: laser, tool, cutter, weapon
extends Node3D

func get_module_id() -> String:
	return "laser_cutter_tool"

func get_module_name() -> String:
	return "Лазерный Резак"

func initialize(_ctx: Dictionary) -> bool:
	return true

func cleanup() -> void:
	queue_free()
"""
	cache.add_module({
		"id": "laser_cutter_tool",
		"name": "Лазерный Резак",
		"description": "Мощный лазерный резак для космических обломков",
		"tags": ["laser", "tool", "cutter"],
		"source_code": valid_code,
		"source_hash": SemanticCache.compute_sha256(valid_code),
		"verified": true,
		"reputation": 0.85
	})

	var sync := CacheSync.new()
	track_node(sync)
	sync.setup(transport, cache)

	# 1. Test query_network packet format
	var empty_res := sync.query_network("лазерный резак", 3.0)
	assert_eq(empty_res.size(), 0, "query_network returns empty array initially")
	assert_eq(transport.broadcast_calls.size(), 1, "broadcast called once for query")

	var q_call: Dictionary = transport.broadcast_calls[0]
	assert_eq(q_call.get("channel"), "cache_sync", "Query sent on 'cache_sync' channel")
	var q_packet: Dictionary = q_call.get("data", {})
	assert_eq(q_packet.get("type"), "cache_query", "Packet type is 'cache_query'")
	assert_eq(q_packet.get("query"), "лазерный резак", "Packet query matches request")
	var req_id: String = str(q_packet.get("request_id", ""))
	assert_true(req_id.begins_with("req_"), "request_id has 'req_' prefix")
	assert_true(sync.get_pending_queries().has(req_id), "Query registered in _pending_queries")

	# Test query_network when disconnected
	transport.connected_peers_list = []
	var disconn_res := sync.query_network("something")
	assert_eq(disconn_res.size(), 0, "query_network returns empty if no peers")
	assert_eq(transport.broadcast_calls.size(), 1, "No broadcast packet sent when peers list is empty")
	transport.connected_peers_list = [10, 20]

	# 2. Test handling incoming cache_query and sending cache_results
	transport.send_to_peer_calls.clear()
	sync.handle_message(10, "cache_sync", {
		"type": "cache_query",
		"query": "лазерный резак",
		"request_id": "test_req_remote_99"
	})

	assert_eq(transport.send_to_peer_calls.size(), 1, "Responded to peer 10 with results")
	var resp_call: Dictionary = transport.send_to_peer_calls[0]
	assert_eq(resp_call.get("peer_id"), 10, "Response sent to peer 10")
	assert_eq(resp_call.get("channel"), "cache_sync", "Response sent on channel 'cache_sync'")
	var resp_packet: Dictionary = resp_call.get("data", {})
	assert_eq(resp_packet.get("type"), "cache_results", "Response packet type is 'cache_results'")
	assert_eq(resp_packet.get("request_id"), "test_req_remote_99", "Response request_id matches incoming query")
	var results_arr: Array = resp_packet.get("results", [])
	assert_true(results_arr.size() >= 1, "Results array contains at least 1 match")
	assert_eq(results_arr[0].get("id"), "laser_cutter_tool", "Result module id matches")

	# 3. Test announce_cache packet format
	transport.broadcast_calls.clear()
	sync.announce_cache()
	assert_eq(transport.broadcast_calls.size(), 1, "announce_cache broadcasted packet")
	var ann_call: Dictionary = transport.broadcast_calls[0]
	assert_eq(ann_call.get("channel"), "cache_sync", "Announce broadcast on 'cache_sync'")
	var ann_packet: Dictionary = ann_call.get("data", {})
	assert_eq(ann_packet.get("type"), "cache_announce", "Announce packet type is 'cache_announce'")
	var ann_mods: Array = ann_packet.get("modules", [])
	assert_eq(ann_mods.size(), 1, "Announce modules array contains 1 verified module")
	assert_eq(ann_mods[0].get("id"), "laser_cutter_tool", "Summary id is correct")
	assert_eq(ann_mods[0].get("name"), "Лазерный Резак", "Summary name is correct")
	assert_true(ann_mods[0].has("source_hash"), "Summary contains source_hash")
	assert_true(ann_mods[0].has("reputation"), "Summary contains reputation")

	# Direct announce to peer (on peer connected)
	transport.send_to_peer_calls.clear()
	sync._on_peer_connected(55, {})
	assert_eq(transport.send_to_peer_calls.size(), 1, "Direct announce sent on peer_connected")
	assert_eq(transport.send_to_peer_calls[0].get("peer_id"), 55, "Sent directly to peer 55")

	# 4. Test incoming cache_announce signal
	var announced_payload: Array = []
	sync.cache_announce_received.connect(func(peer: int, summaries: Array):
		announced_payload.append({"peer": peer, "summaries": summaries})
	)
	sync.handle_message(77, "cache_sync", {
		"type": "cache_announce",
		"modules": [{"id": "peer_mod_1", "name": "Remote Mod", "source_hash": "hash123"}]
	})
	assert_eq(announced_payload.size(), 1, "cache_announce_received emitted on incoming announce")
	assert_eq(announced_payload[0]["peer"], 77, "Announce peer id matches")
	assert_eq(announced_payload[0]["summaries"].size(), 1, "Announce summaries count matches")

# --- Test 2: CacheSync Deduplication by source_hash ---
func test_cache_sync_deduplication() -> void:
	print("\n--- Test Group 2: Deduplication by source_hash ---")

	var transport := MockTransport.new()
	track_node(transport)
	var cache := SemanticCache.new()
	track_node(cache)
	var sync := CacheSync.new()
	track_node(sync)
	sync.setup(transport, cache)

	# Register a pending query
	var test_req_id := "req_dedup_test_001"
	sync.get_pending_queries()[test_req_id] = {
		"timer": 3.0,
		"results": [],
		"peers_responded": []
	}

	var completed_events: Array[Dictionary] = []
	sync.network_search_completed.connect(func(r_id: String, res: Array):
		completed_events.append({"request_id": r_id, "results": res})
	)

	var sync_received_events: Array[Dictionary] = []
	sync.cache_sync_received.connect(func(p_id: int, cnt: int):
		sync_received_events.append({"peer_id": p_id, "count": cnt})
	)

	# Peer 10 returns modA and modB
	sync.handle_message(10, "cache_sync", {
		"type": "cache_results",
		"request_id": test_req_id,
		"results": [
			{"id": "mod_a", "source_hash": "hash_aaa", "score": 0.8},
			{"id": "mod_b", "source_hash": "hash_bbb", "score": 0.7}
		]
	})

	assert_eq(sync_received_events.size(), 1, "cache_sync_received fired for peer 10")
	assert_eq(sync_received_events[0]["count"], 2, "Count from peer 10 is 2")
	assert_eq(completed_events.size(), 1, "network_search_completed fired for peer 10")
	assert_eq(completed_events[0]["results"].size(), 2, "Results size is 2 after first response")

	# Peer 20 returns modA (duplicate hash) and modC (new hash)
	sync.handle_message(20, "cache_sync", {
		"type": "cache_results",
		"request_id": test_req_id,
		"results": [
			{"id": "mod_a_dup", "source_hash": "hash_aaa", "score": 0.85},
			{"id": "mod_c", "source_hash": "hash_ccc", "score": 0.6}
		]
	})

	assert_eq(sync_received_events.size(), 2, "cache_sync_received fired for peer 20")
	assert_eq(completed_events.size(), 2, "network_search_completed fired for peer 20")

	var final_results: Array = completed_events[1]["results"]
	assert_eq(final_results.size(), 3, "Duplicate hash_aaa was deduplicated, total results = 3")

	var collected_hashes: Array[String] = []
	for item in final_results:
		collected_hashes.append(str(item.get("source_hash", "")))
	assert_true(collected_hashes.has("hash_aaa"), "Has hash_aaa")
	assert_true(collected_hashes.has("hash_bbb"), "Has hash_bbb")
	assert_true(collected_hashes.has("hash_ccc"), "Has hash_ccc")

	var pending: Dictionary = sync.get_pending_queries()[test_req_id]
	var peers_arr: Array = pending.get("peers_responded", [])
	assert_eq(peers_arr.size(), 2, "Both peers 10 and 20 registered in peers_responded")
	assert_true(10 in peers_arr, "Peer 10 in list")
	assert_true(20 in peers_arr, "Peer 20 in list")

# --- Test 3: CacheSync Timeout & _process ---
func test_cache_sync_timeout_and_process() -> void:
	print("\n--- Test Group 3: Timeout & _process ---")

	var transport := MockTransport.new()
	track_node(transport)
	var cache := SemanticCache.new()
	track_node(cache)
	var sync := CacheSync.new()
	track_node(sync)
	sync.setup(transport, cache)

	var req_id := "req_timer_test"
	sync.get_pending_queries()[req_id] = {
		"timer": 1.0,
		"results": [{"id": "partial_res", "source_hash": "hash_p"}],
		"peers_responded": [10]
	}

	var timeout_events: Array[Dictionary] = []
	sync.network_search_completed.connect(func(r_id: String, res: Array):
		timeout_events.append({"request_id": r_id, "results": res})
	)

	# Advance 0.4s (timer = 0.6s remaining)
	sync._process(0.4)
	assert_true(sync.get_pending_queries().has(req_id), "Query still pending after 0.4s")
	assert_eq(timeout_events.size(), 0, "network_search_completed not emitted before timeout")

	# Advance 0.7s (timer expires: 0.6 - 0.7 = -0.1 <= 0.0)
	sync._process(0.7)
	assert_false(sync.get_pending_queries().has(req_id), "Query expired and erased from _pending_queries")
	assert_eq(timeout_events.size(), 1, "network_search_completed emitted on timeout")
	assert_eq(timeout_events[0]["request_id"], req_id, "Timed out request_id matches")
	assert_eq(timeout_events[0]["results"].size(), 1, "Accumulated results returned on timeout")

# --- Test 4: AgentBrain Cache HIT Chain ---
func test_agent_brain_cache_hit_chain() -> void:
	print("\n--- Test Group 4: AgentBrain Cache HIT Chain ---")

	var event_bus := EventBus.new()
	track_node(event_bus)
	var world_root := Node3D.new()
	track_node(world_root)
	var module_manager := ModuleManager.new()
	track_node(module_manager)
	module_manager.setup(event_bus, world_root)

	var mock_provider := MockLLMProvider.new()
	track_node(mock_provider)
	var logger := DiagnosticLogger.new()
	track_node(logger)
	logger.clear()

	var cache := SemanticCache.new()
	track_node(cache)
	cache.current_cache_path = TEST_CACHE_PATH
	cache.clear_cache()

	var gravity_code := """## Name: Орбитальная гравитация
## Description: Физический симулятор орбитальной гравитации планет и спутников
## Tags: physics, orbital, gravity, simulation
extends Node3D

func get_module_id() -> String:
	return "orbital_gravity_sim"

func get_module_name() -> String:
	return "Орбитальная гравитация"

func initialize(_ctx: Dictionary) -> bool:
	return true

func cleanup() -> void:
	queue_free()
"""
	cache.add_module({
		"id": "orbital_gravity_sim",
		"name": "Орбитальная гравитация",
		"description": "Физический симулятор орбитальной гравитации планет и спутников",
		"tags": ["physics", "orbital", "gravity"],
		"source_code": gravity_code,
		"source_hash": SemanticCache.compute_sha256(gravity_code),
		"verified": true,
		"usage_count": 5,
		"reputation": 0.7
	})

	var transport := MockTransport.new()
	track_node(transport)
	var cache_sync := CacheSync.new()
	track_node(cache_sync)
	cache_sync.setup(transport, cache)

	var brain := AgentBrain.new()
	track_node(brain)
	brain.api_key = "dummy_key"
	brain.setup(event_bus, module_manager, mock_provider, logger, null, null, cache, cache_sync)

	var resolved_events: Array[Dictionary] = []
	brain.module_resolved.connect(func(mod_id: String, source_type: String, dur: float):
		resolved_events.append({"id": mod_id, "source": source_type, "duration": dur})
	)

	var completed_modules: Array[String] = []
	brain.request_completed.connect(func(m_id: String):
		completed_modules.append(m_id)
	)

	# Execute prompt matching cache
	brain.process_prompt("симулятор орбитальной гравитации")

	assert_eq(resolved_events.size(), 1, "module_resolved signal emitted on Cache HIT")
	assert_eq(resolved_events[0]["id"], "orbital_gravity_sim", "Resolved module ID is orbital_gravity_sim")
	assert_eq(resolved_events[0]["source"], "cache", "Resolved source type is 'cache'")
	assert_eq(brain.last_module_source, "cache", "brain.last_module_source is 'cache'")
	assert_eq(completed_modules.size(), 1, "request_completed emitted")
	assert_eq(completed_modules[0], "orbital_gravity_sim", "request_completed has correct module ID")

	# Crucial: LLM must NOT be called when cache hits!
	assert_eq(mock_provider.send_count, 0, "LLM was NOT called on Cache HIT")

	# Check that module was actually mounted into ModuleManager
	var inst = module_manager.get_module("orbital_gravity_sim")
	assert_true(inst != null and is_instance_valid(inst), "Module loaded into ModuleManager runtime")

	# Check usage_count incremented in cache
	var cached_entry: Dictionary = cache.get_by_id("orbital_gravity_sim")
	assert_eq(cached_entry.get("usage_count"), 6, "Usage count incremented from 5 to 6 in cache")

	module_manager.unload_module("orbital_gravity_sim")

# --- Test 5: AgentBrain Cache MISS -> LLM Fallback ---
func test_agent_brain_cache_miss_llm_fallback() -> void:
	print("\n--- Test Group 5: AgentBrain Cache MISS -> LLM Fallback ---")

	var event_bus := EventBus.new()
	track_node(event_bus)
	var world_root := Node3D.new()
	track_node(world_root)
	var module_manager := ModuleManager.new()
	track_node(module_manager)
	module_manager.setup(event_bus, world_root)

	var mock_provider := MockLLMProvider.new()
	track_node(mock_provider)
	var logger := DiagnosticLogger.new()
	track_node(logger)
	logger.clear()

	var cache := SemanticCache.new()
	track_node(cache)
	cache.current_cache_path = TEST_CACHE_PATH
	cache.clear_cache()

	var brain := AgentBrain.new()
	track_node(brain)
	brain.api_key = "dummy_key"
	brain.setup(event_bus, module_manager, mock_provider, logger, null, null, cache, null)

	var resolved_events: Array[Dictionary] = []
	brain.module_resolved.connect(func(mod_id: String, source_type: String, dur: float):
		resolved_events.append({"id": mod_id, "source": source_type, "duration": dur})
	)

	var generated_maze_code := """## Name: Процедурный Лабиринт
## Description: Генератор трехмерных процедурных лабиринтов
## Tags: maze, procedural, 3d, generator
extends Node3D

func get_module_id() -> String:
	return "proc_maze_tool"

func get_module_name() -> String:
	return "Процедурный Лабиринт"

func initialize(_ctx: Dictionary) -> bool:
	return true

func cleanup() -> void:
	queue_free()
"""

	# Prepare mock LLM reply
	mock_provider.next_response = generated_maze_code

	# Execute prompt that has NO cache hit
	brain.process_prompt("создай процедурный лабиринт")

	# LLM MUST be called when cache misses!
	assert_eq(mock_provider.send_count, 1, "LLM WAS called on Cache MISS")

	# Deliver LLM response directly to simulate completion
	brain._on_llm_response(generated_maze_code)

	assert_eq(brain.last_module_source, "llm", "brain.last_module_source is 'llm'")
	assert_true(resolved_events.size() >= 1, "module_resolved emitted for LLM generation")
	var last_event: Dictionary = resolved_events[resolved_events.size() - 1]
	assert_eq(last_event["id"], "proc_maze_tool", "Resolved module ID is proc_maze_tool")
	assert_eq(last_event["source"], "llm", "Resolved source is 'llm'")

	# Check that generated module was automatically cached into SemanticCache!
	var newly_cached: Dictionary = cache.get_by_id("proc_maze_tool")
	assert_false(newly_cached.is_empty(), "Newly generated LLM module was auto-added to SemanticCache")
	assert_eq(newly_cached.get("name"), "Процедурный Лабиринт", "Auto-cached name parsed from comments")
	assert_true(str(newly_cached.get("description")).to_lower().contains("лабиринт"), "Auto-cached description saved")
	assert_true(newly_cached.get("verified"), "Auto-cached module marked verified = true")
	var tags: Array = newly_cached.get("tags", [])
	assert_true("maze" in tags, "Tag 'maze' parsed into cache")
	assert_true("procedural" in tags, "Tag 'procedural' parsed into cache")

	module_manager.unload_module("proc_maze_tool")

# --- Test 6: AgentBrain P2P Hit Chain ---
func test_agent_brain_p2p_hit_chain() -> void:
	print("\n--- Test Group 6: AgentBrain P2P Hit Chain ---")

	var event_bus := EventBus.new()
	track_node(event_bus)
	var world_root := Node3D.new()
	track_node(world_root)
	var module_manager := ModuleManager.new()
	track_node(module_manager)
	module_manager.setup(event_bus, world_root)

	var mock_provider := MockLLMProvider.new()
	track_node(mock_provider)
	var logger := DiagnosticLogger.new()
	track_node(logger)

	var cache := SemanticCache.new()
	track_node(cache)
	cache.current_cache_path = TEST_CACHE_PATH
	cache.clear_cache()

	# Subclass CacheSync to mock immediate P2P search result
	var p2p_code := """## Name: P2P Лазер
## Description: Сетевой лазерный инструмент
## Tags: laser, p2p, weapon
extends Node3D

func get_module_id() -> String:
	return "p2p_laser_tool"

func get_module_name() -> String:
	return "P2P Лазер"

func initialize(_ctx: Dictionary) -> bool:
	return true

func cleanup() -> void:
	queue_free()
"""
	var transport := MockTransport.new()
	track_node(transport)

	var sync := CacheSync.new()
	track_node(sync)
	sync.setup(transport, cache)

	# Pre-populate pending query response on query_network call
	var p2p_hit_result: Array[Dictionary] = [
		{
			"id": "p2p_laser_tool",
			"name": "P2P Лазер",
			"source_code": p2p_code,
			"source_hash": SemanticCache.compute_sha256(p2p_code),
			"score": 0.95
		}
	]

	# We override query_network by wrapping or injecting
	# In our CacheSync, if we pre-set a pending result or query:
	# Let's test P2P path by testing brain with a MockCacheSync that returns p2p_hit_result
	var mock_sync := MockCacheSync.new()
	track_node(mock_sync)
	mock_sync.mock_results = p2p_hit_result
	mock_sync.setup(transport, cache)

	var brain := AgentBrain.new()
	track_node(brain)
	brain.api_key = "dummy_key"
	brain.setup(event_bus, module_manager, mock_provider, logger, null, null, cache, mock_sync)

	var resolved_events: Array[Dictionary] = []
	brain.module_resolved.connect(func(mod_id: String, source_type: String, dur: float):
		resolved_events.append({"id": mod_id, "source": source_type, "duration": dur})
	)

	brain.process_prompt("найди p2p лазерный инструмент")

	assert_eq(resolved_events.size(), 1, "module_resolved emitted for P2P hit")
	assert_eq(resolved_events[0]["id"], "p2p_laser_tool", "Module ID is p2p_laser_tool")
	assert_eq(resolved_events[0]["source"], "p2p", "Source is 'p2p'")
	assert_eq(brain.last_module_source, "p2p", "brain.last_module_source is 'p2p'")
	assert_eq(mock_provider.send_count, 0, "LLM was NOT called when P2P hit succeeded")

	# Verify P2P module was added into local semantic cache
	var local_entry: Dictionary = cache.get_by_id("p2p_laser_tool")
	assert_false(local_entry.is_empty(), "P2P module was automatically saved to local SemanticCache")
	assert_eq(local_entry.get("author_node"), "p2p_peer", "Author node recorded as p2p_peer")

	module_manager.unload_module("p2p_laser_tool")
