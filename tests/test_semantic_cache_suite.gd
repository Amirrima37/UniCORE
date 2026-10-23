extends SceneTree

## Комплексный тестовый сьют: «P2P Семантический Кэш Модулей» (Фаза 3a)
## Проверяет Stopwords, SemanticCache, CacheSync, AgentBrain Search Cascade и UI интеграцию.

const Stopwords = preload("res://core/stopwords.gd")
const SemanticCache = preload("res://core/semantic_cache.gd")
const CacheSync = preload("res://core/net/cache_sync.gd")
const AgentBrain = preload("res://agent/agent_brain.gd")
const ModuleManager = preload("res://core/module_manager.gd")
const EventBus = preload("res://core/event_bus.gd")
const BaseLLMProvider = preload("res://agent/providers/base_llm_provider.gd")
const NetworkTransport = preload("res://core/net/network_transport.gd")
const MainMenuScript = preload("res://ui/menu/main_menu.gd")
const PromptBarScript = preload("res://ui/prompt_bar/prompt_bar.gd")

var passed_count: int = 0
var failed_count: int = 0
var _nodes_to_free: Array[Node] = []

const TEST_CACHE_PATH: String = "user://test_semantic_cache_suite_data.json"

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
		var detail = " (Error: %s)" % error_msg if not error_msg.is_empty() else ""
		print("  [FAIL] %s%s" % [test_name, detail])
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

class MockLLMProvider extends BaseLLMProvider:
	var send_count: int = 0
	var next_response: String = ""

	func send_prompt(_system_prompt: String, _user_prompt: String, _api_key: String) -> void:
		send_count += 1
		if not next_response.is_empty():
			var resp := next_response
			next_response = ""
			call_deferred("_deliver", resp)

	func _deliver(resp: String) -> void:
		response_received.emit(resp)

class MockTransport extends NetworkTransport:
	var sent_messages: Array[Dictionary] = []
	var connected_peers_list: Array[int] = [1, 2]

	func get_connected_peers() -> Array[int]:
		return connected_peers_list

	func is_hosting() -> bool:
		return true

	func get_status() -> String:
		return "hosting"

	func broadcast(channel: String, data: Dictionary) -> void:
		sent_messages.append({"channel": channel, "data": data, "target": "broadcast"})

	func send_to_peer(peer_id: int, channel: String, data: Dictionary) -> void:
		sent_messages.append({"channel": channel, "data": data, "target": peer_id})

class MockMockCacheSync extends "res://core/net/cache_sync.gd":
	var mock_results: Array[Dictionary] = []

	func has_connected_peers() -> bool:
		return true

	func query_network(_query: String, _timeout_sec: float = 3.0) -> Array[Dictionary]:
		return mock_results

func _init() -> void:
	print("==================================================")
	print("Starting UniCORE Phase 3a Semantic Cache Suite")
	print("==================================================")

	test_stopwords()
	test_ngram_similarity()
	test_semantic_cache_crud_and_keywords()
	test_semantic_cache_search_and_ranking()
	test_persistence()
	test_usage_and_reputation()
	test_cache_sync_protocol()
	test_agent_brain_cascade()
	test_ui_cache_integration()

	free_tracked_nodes()
	_cleanup_test_files()

	print("\n==================================================")
	print("Test Results: %d Passed, %d Failed" % [passed_count, failed_count])
	print("==================================================")

	if failed_count == 0:
		print("ALL TESTS PASSED SUCCESSFULLY! Quitting with code 0.")
		quit(0)
	else:
		print("SOME TESTS FAILED! Quitting with code 1.")
		quit(1)

func _cleanup_test_files() -> void:
	if FileAccess.file_exists(TEST_CACHE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_CACHE_PATH))
	var test_mod := "res://modules/suite_test_mod.gd"
	if FileAccess.file_exists(test_mod):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(test_mod))

# ----------------------------------------------------
# 1. Stopwords & Tokenization
# ----------------------------------------------------
func test_stopwords() -> void:
	print("\n--- 1. Testing Stopwords & Token Cleaning ---")
	assert_true(Stopwords.is_stopword("и"), "RU stopword 'и'")
	assert_true(Stopwords.is_stopword("для"), "RU stopword 'для'")
	assert_true(Stopwords.is_stopword("the"), "EN stopword 'the'")
	assert_true(Stopwords.is_stopword("with"), "EN stopword 'with'")
	assert_false(Stopwords.is_stopword("laser"), "Word 'laser' is not stopword")
	assert_false(Stopwords.is_stopword("куб"), "Word 'куб' is not stopword")

	var raw_tokens: Array[String] = ["the", "cube", "spawner", "and", "a", "3d", "куб"]
	var cleaned := Stopwords.clean_tokens(raw_tokens)
	assert_true("cube" in cleaned, "clean_tokens keeps 'cube'")
	assert_true("spawner" in cleaned, "clean_tokens keeps 'spawner'")
	assert_true("3d" in cleaned, "clean_tokens keeps 2-char token '3d'")
	assert_true("куб" in cleaned, "clean_tokens keeps 'куб'")
	assert_false("the" in cleaned, "clean_tokens removed 'the'")
	assert_false("and" in cleaned, "clean_tokens removed 'and'")
	assert_false("a" in cleaned, "clean_tokens removed 1-char token 'a'")

# ----------------------------------------------------
# 2. N-Gram Similarity
# ----------------------------------------------------
func test_ngram_similarity() -> void:
	print("\n--- 2. Testing N-Gram Similarity ---")
	var cache := SemanticCache.new()
	track_node(cache)

	assert_eq(cache._ngram_similarity("spawner", "spawner"), 1.0, "Exact match gives 1.0")
	assert_true(cache._ngram_similarity("spawner", "spawn") > 0.5, "Partial match gives > 0.5")
	assert_eq(cache._ngram_similarity("apple", "zebra"), 0.0, "Completely disjoint gives 0.0")
	assert_eq(cache._ngram_similarity("", ""), 1.0, "Two empty strings gives 1.0")

# ----------------------------------------------------
# 3. Semantic Cache CRUD & Keyword Extraction
# ----------------------------------------------------
func test_semantic_cache_crud_and_keywords() -> void:
	print("\n--- 3. Testing Semantic Cache CRUD & Keyword Extraction ---")
	var cache := SemanticCache.new()
	track_node(cache)
	cache.current_cache_path = TEST_CACHE_PATH
	cache.clear_cache()

	var code := """## Name: Кибер Сфера
## Description: Создает светящуюся кибер-сферу с физикой
## Tags: sphere, neon, physics, 3d
extends Node3D

func get_module_id() -> String:
	return "cyber_sphere_mod"
"""
	var added := cache.add_module({
		"id": "cyber_sphere_mod",
		"name": "Кибер Сфера",
		"description": "Создает светящуюся кибер-сферу с физикой",
		"tags": ["sphere", "neon", "physics", "3d"],
		"source_code": code,
		"verified": true,
		"author_node": "local_test"
	})
	assert_true(added, "add_module returns true")

	var entry := cache.get_by_id("cyber_sphere_mod")
	assert_false(entry.is_empty(), "get_by_id finds module")
	assert_eq(entry.get("name"), "Кибер Сфера", "Name matches")
	assert_true(entry.get("source_hash").length() == 64, "source_hash is 64 hex chars")
	assert_true(cache.get_total_modules_count() == 1, "get_total_modules_count returns 1")
	assert_true("physics" in cache.get_unique_tags(), "Unique tags contains 'physics'")

	var kw: Array = entry.get("keywords", [])
	assert_true("sphere" in kw, "Keywords has 'sphere'")
	assert_true("neon" in kw, "Keywords has 'neon'")
	assert_true("кибер" in kw, "Keywords has 'кибер'")

# ----------------------------------------------------
# 4. Search and Ranking
# ----------------------------------------------------
func test_semantic_cache_search_and_ranking() -> void:
	print("\n--- 4. Testing Search and Ranking ---")
	var cache := SemanticCache.new()
	track_node(cache)
	cache.current_cache_path = TEST_CACHE_PATH
	cache.clear_cache()

	cache.add_module({
		"id": "laser_gun",
		"name": "Лазерное Оружие",
		"description": "Высокоточный лазер для стрельбы и боя",
		"tags": ["laser", "weapon", "combat", "sci-fi"],
		"source_code": "extends Node3D\nfunc get_module_id(): return 'laser_gun'",
		"usage_count": 20,
		"reputation": 0.9,
		"verified": true
	})
	cache.add_module({
		"id": "shield_barrier",
		"name": "Энергетический Щит",
		"description": "Защитное поле, блокирующее выстрелы",
		"tags": ["shield", "defense", "barrier"],
		"source_code": "extends Node3D\nfunc get_module_id(): return 'shield_barrier'",
		"usage_count": 5,
		"reputation": 0.4,
		"verified": true
	})

	var res_laser := cache.search("лазерный бой", 5, 0.2)
	assert_true(res_laser.size() >= 1, "Search returns matches")
	assert_eq(res_laser[0]["id"], "laser_gun", "Top hit is laser_gun")
	assert_true(res_laser[0]["score"] > 0.25, "Score is high")

	var res_shield := cache.search("энергетический щит", 5, 0.2)
	assert_true(res_shield.size() >= 1, "Search finds shield")
	assert_eq(res_shield[0]["id"], "shield_barrier", "Top hit is shield_barrier")

	var res_empty := cache.search("неведомый банановый пирог", 5, 0.6)
	assert_true(res_empty.is_empty(), "Irrelevant query returns empty")

# ----------------------------------------------------
# 5. Persistence
# ----------------------------------------------------
func test_persistence() -> void:
	print("\n--- 5. Testing Persistence ---")
	var cache1 := SemanticCache.new()
	track_node(cache1)
	cache1.current_cache_path = TEST_CACHE_PATH
	cache1.clear_cache()

	cache1.add_module({
		"id": "persisted_mod",
		"name": "Персистентный Модуль",
		"description": "Тест сохранения",
		"tags": ["persist", "test"],
		"source_code": "extends Node",
		"verified": true
	})
	assert_true(FileAccess.file_exists(TEST_CACHE_PATH), "Cache file written to disk")

	var cache2 := SemanticCache.new()
	track_node(cache2)
	cache2.current_cache_path = TEST_CACHE_PATH
	cache2.load_from_disk(TEST_CACHE_PATH)

	assert_eq(cache2.get_total_modules_count(), 1, "Loaded 1 module from disk")
	assert_eq(cache2.get_by_id("persisted_mod").get("name"), "Персистентный Модуль", "Loaded module name matches")

# ----------------------------------------------------
# 6. Usage and Reputation
# ----------------------------------------------------
func test_usage_and_reputation() -> void:
	print("\n--- 6. Testing Usage and Reputation ---")
	var cache := SemanticCache.new()
	track_node(cache)
	cache.current_cache_path = TEST_CACHE_PATH
	cache.clear_cache()

	cache.add_module({
		"id": "rep_mod",
		"name": "Репутационный Модуль",
		"description": "Тест репутации",
		"tags": ["test"],
		"source_code": "extends Node",
		"usage_count": 0,
		"reputation": 0.5,
		"verified": true
	})

	cache.increment_usage("rep_mod")
	var e := cache.get_by_id("rep_mod")
	assert_eq(e.get("usage_count"), 1, "Usage count incremented to 1")
	assert_true(e.get("reputation") > 0.5, "Reputation increased")

	cache.update_reputation("rep_mod", 0.3)
	assert_true(cache.get_by_id("rep_mod").get("reputation") > 0.8, "Reputation updated by delta")

# ----------------------------------------------------
# 7. CacheSync Protocol
# ----------------------------------------------------
func test_cache_sync_protocol() -> void:
	print("\n--- 7. Testing CacheSync Protocol ---")
	var transport := MockTransport.new()
	track_node(transport)
	var cache := SemanticCache.new()
	track_node(cache)
	cache.current_cache_path = TEST_CACHE_PATH
	cache.clear_cache()

	cache.add_module({
		"id": "sync_sample",
		"name": "Sync Sample",
		"description": "Protocol test",
		"tags": ["sample"],
		"source_code": "extends Node",
		"source_hash": "hash_sample_123",
		"verified": true
	})

	var sync := CacheSync.new()
	track_node(sync)
	sync.setup(transport, cache)

	# 7.1 Announce
	sync.announce_cache()
	assert_true(transport.sent_messages.size() >= 1, "announce_cache broadcasted packet")
	var msg = transport.sent_messages[0]
	assert_eq(msg["channel"], "cache_sync", "Announce sent on 'cache_sync'")
	assert_eq(msg["data"]["type"], "cache_announce", "Packet type is 'cache_announce'")

	# 7.2 Incoming query handling
	transport.sent_messages.clear()
	sync.handle_message(10, "cache_sync", {
		"type": "cache_query",
		"query": "sample",
		"request_id": "req_test_01"
	})
	assert_true(transport.sent_messages.size() == 1, "Replied to cache_query")
	var reply = transport.sent_messages[0]
	assert_eq(reply["target"], 10, "Reply targeted to peer 10")
	assert_eq(reply["data"]["type"], "cache_results", "Reply type is 'cache_results'")
	assert_eq(reply["data"]["request_id"], "req_test_01", "Reply request_id matches")

# ----------------------------------------------------
# 8. AgentBrain Search Cascade (Cache Hit & Fallback)
# ----------------------------------------------------
func test_agent_brain_cascade() -> void:
	print("\n--- 8. Testing AgentBrain Cascade (Cache Hit & LLM Fallback) ---")
	var event_bus := EventBus.new()
	track_node(event_bus)
	var world := Node3D.new()
	track_node(world)
	var mm := ModuleManager.new()
	track_node(mm)
	mm.setup(event_bus, world)

	var mock_llm := MockLLMProvider.new()
	track_node(mock_llm)
	var cache := SemanticCache.new()
	track_node(cache)
	cache.current_cache_path = TEST_CACHE_PATH
	cache.clear_cache()

	var cached_code := """## Name: Каскадный Кварц
## Description: Кварцевый модуль из семантического кэша
## Tags: quartz, crystal, visual
extends Node3D

func get_module_id() -> String:
	return "quartz_cached_mod"

func initialize(_ctx: Dictionary) -> bool:
	return true

func cleanup() -> void:
	pass
"""
	cache.add_module({
		"id": "quartz_cached_mod",
		"name": "Каскадный Кварц",
		"description": "Кварцевый модуль из семантического кэша",
		"tags": ["кварц", "кристалл", "каскадный", "quartz"],
		"source_code": cached_code,
		"source_hash": SemanticCache.compute_sha256(cached_code),
		"verified": true,
		"usage_count": 3,
		"reputation": 0.8
	})

	var brain := AgentBrain.new()
	track_node(brain)
	brain.api_key = "dummy"
	brain.setup(event_bus, mm, mock_llm, null, null, null, cache, null)

	var resolved_events: Array[Dictionary] = []
	brain.module_resolved.connect(func(mid: String, src: String, dur: float):
		resolved_events.append({"id": mid, "source": src, "duration": dur})
	)

	# 8.1 Cache Hit: LLM must NOT be called
	brain.process_prompt("каскадный кварц")
	assert_eq(mock_llm.send_count, 0, "LLM was NOT called on Cache HIT")
	assert_eq(brain.last_module_source, "cache", "Source is 'cache'")
	assert_true(resolved_events.size() == 1, "module_resolved signal emitted")
	assert_eq(resolved_events[0]["id"], "quartz_cached_mod", "Resolved ID matches")
	assert_eq(cache.get_by_id("quartz_cached_mod").get("usage_count"), 4, "Usage incremented")

	mm.unload_module("quartz_cached_mod")

	# 8.2 Cache Miss -> Fallback to LLM
	var new_mod_code := """## Name: Новая Турель
## Description: Сгенерированная турель
## Tags: turret, defense
extends Node3D

func get_module_id() -> String:
	return "llm_turret_mod"

func initialize(_ctx: Dictionary) -> bool:
	return true

func cleanup() -> void:
	pass
"""
	mock_llm.next_response = new_mod_code
	brain.process_prompt("построй защитную автоматическую турель")
	assert_eq(mock_llm.send_count, 1, "LLM WAS called on Cache MISS")
	brain._on_llm_response(new_mod_code)
	assert_eq(brain.last_module_source, "llm", "Source is 'llm'")
	assert_true(cache.get_by_id("llm_turret_mod").size() > 0, "Newly generated LLM module was auto-added to cache")

	mm.unload_module("llm_turret_mod")

# ----------------------------------------------------
# 9. UI Integration (MainMenu & PromptBar)
# ----------------------------------------------------
func test_ui_cache_integration() -> void:
	print("\n--- 9. Testing UI Cache Integration ---")
	var cache := SemanticCache.new()
	track_node(cache)
	cache.current_cache_path = TEST_CACHE_PATH
	cache.clear_cache()

	cache.add_module({
		"id": "ui_test_mod",
		"name": "UI Test Module",
		"description": "UI display test",
		"tags": ["ui", "hud"],
		"source_code": "extends Node",
		"usage_count": 7,
		"reputation": 0.85,
		"verified": true
	})

	const MainMenuScene = preload("res://ui/menu/main_menu.tscn")
	const PromptBarScene = preload("res://ui/prompt_bar/prompt_bar.tscn")

	var menu: MainMenu = MainMenuScene.instantiate()
	track_node(menu)
	root.add_child(menu)
	menu.setup_cache(cache)

	menu.update_cache_source("cache")
	assert_true(menu.cache_stats_label != null, "cache_stats_label created")
	assert_true(menu.cache_stats_label.text.contains("1 модулей"), "Stats label reflects 1 module")
	assert_true(menu.cache_source_label.text.contains("Локальный Кэш"), "Source label reflects cache")
	assert_true(menu.cache_popular_list.get_child_count() == 1, "Popular list has 1 item")

	# Test clear cache
	cache.clear_cache()
	menu._refresh_cache_ui()
	assert_true(menu.cache_stats_label.text.contains("0 модулей"), "Stats label updated after clear")

	# PromptBar test
	var pbar: PromptBar = PromptBarScene.instantiate()
	track_node(pbar)
	root.add_child(pbar)
	pbar.set_resolution_status("test_module", "cache", 0.25)
	assert_true(pbar.status_label.text.contains("Кэш"), "PromptBar status shows 'Кэш'")
	assert_true(pbar.status_label.text.contains("0.25 сек"), "PromptBar status shows duration")
