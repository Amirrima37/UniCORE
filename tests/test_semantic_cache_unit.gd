extends SceneTree

## Юнит-тесты для семантического кэша модулей (Stopwords, SemanticCache, N-gram, Search)

var passed_count: int = 0
var failed_count: int = 0
var _nodes_to_free: Array[Node] = []

const TEST_CACHE_PATH: String = "user://test_semantic_cache_data.json"

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

func _init() -> void:
	print("==================================================")
	print("Starting SemanticCache & Search Unit Test Suite")
	print("==================================================")

	_cleanup_test_file()

	test_stopwords()
	test_ngram_similarity()
	test_sha256_and_metadata_parsing()
	test_add_module_and_keyword_extraction()
	test_search_and_ranking()
	test_usage_and_reputation()
	test_persistence_and_removal()

	_cleanup_test_file()
	free_tracked_nodes()

	print("==================================================")
	print("Test Results: %d Passed, %d Failed" % [passed_count, failed_count])
	print("==================================================")

	if failed_count > 0:
		quit(1)
	else:
		quit(0)

# ------------------------------------------------------------------------------
# 1. Stopwords tests
# ------------------------------------------------------------------------------
func test_stopwords() -> void:
	print("\n--- Test Group 1: Stopwords ---")

	# Russian stopwords
	assert_true(Stopwords.is_stopword("и"), "Russian stopword 'и' recognized")
	assert_true(Stopwords.is_stopword("для"), "Russian stopword 'для' recognized")
	assert_true(Stopwords.is_stopword("это"), "Russian stopword 'это' recognized")
	assert_true(Stopwords.is_stopword("что"), "Russian stopword 'что' recognized")
	assert_true(Stopwords.is_stopword("  НЕ  "), "Stopword check handles case and whitespace")

	# English stopwords
	assert_true(Stopwords.is_stopword("the"), "English stopword 'the' recognized")
	assert_true(Stopwords.is_stopword("with"), "English stopword 'with' recognized")
	assert_true(Stopwords.is_stopword("is"), "English stopword 'is' recognized")
	assert_true(Stopwords.is_stopword("for"), "English stopword 'for' recognized")

	# Non-stopwords
	assert_false(Stopwords.is_stopword("spawner"), "'spawner' is not a stopword")
	assert_false(Stopwords.is_stopword("physics"), "'physics' is not a stopword")
	assert_false(Stopwords.is_stopword("генератор"), "'генератор' is not a stopword")
	assert_false(Stopwords.is_stopword("3d"), "'3d' is not a stopword")

	# clean_tokens
	var raw_tokens: Array[String] = ["the", "3d", "a", "mesh", "генератор", "для", "и", "cube", "x"]
	var cleaned: Array[String] = Stopwords.clean_tokens(raw_tokens)

	assert_true(cleaned.has("3d"), "clean_tokens keeps 2-char token '3d'")
	assert_true(cleaned.has("mesh"), "clean_tokens keeps 'mesh'")
	assert_true(cleaned.has("генератор"), "clean_tokens keeps 'генератор'")
	assert_true(cleaned.has("cube"), "clean_tokens keeps 'cube'")

	assert_false(cleaned.has("the"), "clean_tokens filtered out 'the'")
	assert_false(cleaned.has("a"), "clean_tokens filtered out 1-char token 'a'")
	assert_false(cleaned.has("x"), "clean_tokens filtered out 1-char token 'x'")
	assert_false(cleaned.has("для"), "clean_tokens filtered out 'для'")
	assert_false(cleaned.has("и"), "clean_tokens filtered out 'и'")
	assert_eq(cleaned.size(), 4, "clean_tokens left exactly 4 valid tokens")

# ------------------------------------------------------------------------------
# 2. N-gram similarity tests
# ------------------------------------------------------------------------------
func test_ngram_similarity() -> void:
	print("\n--- Test Group 2: N-gram Similarity ---")

	var cache: SemanticCache = track_node(SemanticCache.new())

	# Identical strings
	var sim_same := cache._ngram_similarity("spawner", "spawner", 3)
	assert_eq(sim_same, 1.0, "Identical strings similarity is 1.0")

	# Empty strings
	assert_eq(cache._ngram_similarity("", "", 3), 1.0, "Two empty strings similarity is 1.0")
	assert_eq(cache._ngram_similarity("cube", "", 3), 0.0, "Empty and non-empty string similarity is 0.0")

	# Substring containment & partial overlap
	var sim_sub := cache._ngram_similarity("spawner", "spawn", 3)
	assert_true(sim_sub > 0.6, "Similar words have high similarity score", "Got %f" % sim_sub)

	# Case-insensitivity
	var sim_case := cache._ngram_similarity("PhysicsEngine", "physicsengine", 3)
	assert_eq(sim_case, 1.0, "N-gram similarity is case-insensitive")

	# Short string fallback (< 3 chars)
	var sim_short_match := cache._ngram_similarity("3d", "3d", 3)
	assert_eq(sim_short_match, 1.0, "Short identical string fallback returns 1.0")

	var sim_short_sub := cache._ngram_similarity("3d", "3d_mesh", 3)
	assert_true(sim_short_sub > 0.0, "Short string fallback handles substring overlap")

	# Completely different strings
	var sim_diff := cache._ngram_similarity("alpha", "zzzzz", 3)
	assert_eq(sim_diff, 0.0, "Completely disjoint strings return 0.0")

# ------------------------------------------------------------------------------
# 3. SHA-256 and metadata parsing
# ------------------------------------------------------------------------------
func test_sha256_and_metadata_parsing() -> void:
	print("\n--- Test Group 3: SHA-256 & Code Metadata Parsing ---")

	var empty_hash := SemanticCache.compute_sha256("")
	assert_eq(empty_hash, "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855", "Empty string SHA-256 matches standard digest")

	var sample_code := "extends Node\nfunc _ready(): pass\n"
	var hash_1 := SemanticCache.compute_sha256(sample_code)
	var hash_2 := SemanticCache.compute_sha256(sample_code)
	assert_eq(hash_1, hash_2, "Deterministic SHA-256 generation")
	assert_eq(hash_1.length(), 64, "SHA-256 digest is 64 hex characters")

	# Metadata parsing from code comments
	var code_with_meta := """## Name: Procedural Starfield
## Description: Generates dynamic cosmic starfield with shaders
## Tags: space, visual, shader, 3d
extends Node3D

func generate():
	pass
"""
	var meta := SemanticCache.parse_metadata_from_code(code_with_meta)
	assert_eq(meta["name"], "Procedural Starfield", "Parsed module name from ## Name:")
	assert_eq(meta["description"], "Generates dynamic cosmic starfield with shaders", "Parsed description from ## Description:")
	var tags: Array[String] = meta["tags"]
	assert_true(tags.has("space"), "Parsed tag 'space'")
	assert_true(tags.has("visual"), "Parsed tag 'visual'")
	assert_true(tags.has("shader"), "Parsed tag 'shader'")
	assert_true(tags.has("3d"), "Parsed tag '3d'")

	# Single hash comments and brackets format
	var code_single_hash := """# Name: Laser Cannon
# Description: Raycast laser weapon with audio
# Tags: [weapon, 3d, combat]
extends Node
"""
	var meta_single := SemanticCache.parse_metadata_from_code(code_single_hash)
	assert_eq(meta_single["name"], "Laser Cannon", "Parsed name with single hash comment")
	assert_eq(meta_single["description"], "Raycast laser weapon with audio", "Parsed description with single hash")
	var tags_single: Array[String] = meta_single["tags"]
	assert_true(tags_single.has("weapon"), "Parsed bracketed tag 'weapon'")
	assert_true(tags_single.has("combat"), "Parsed bracketed tag 'combat'")

# ------------------------------------------------------------------------------
# 4. Add module and keyword extraction
# ------------------------------------------------------------------------------
func test_add_module_and_keyword_extraction() -> void:
	print("\n--- Test Group 4: Add Module & Keyword Extraction ---")

	var cache: SemanticCache = track_node(SemanticCache.new())
	cache.current_cache_path = TEST_CACHE_PATH

	var signal_captured := [false, "", ""]
	cache.cache_updated.connect(func(mid: String, action: String):
		signal_captured[0] = true
		signal_captured[1] = mid
		signal_captured[2] = action
	)

	var mod_data := {
		"id": "module_spawner_01",
		"name": "Enemy Wave Spawner",
		"description": "Автоматический спавнер врагов и физических объектов в 3D мире",
		"tags": ["spawner", "ai", "3d", "physics"],
		"source_code": "extends Node\n# Custom enemy logic and spawn points\n",
		"author_node": "node_alpha",
		"usage_count": 5,
		"reputation": 0.85,
		"verified": true
	}

	var added := cache.add_module(mod_data)
	assert_true(added, "add_module returns true on valid data")
	assert_true(signal_captured[0], "cache_updated signal emitted")
	assert_eq(signal_captured[1], "module_spawner_01", "Signal contains correct module_id")
	assert_eq(signal_captured[2], "added", "Signal contains 'added' action")

	# Verify stored entry
	var retrieved := cache.get_by_id("module_spawner_01")
	assert_eq(retrieved["id"], "module_spawner_01", "get_by_id retrieves correct ID")
	assert_eq(retrieved["name"], "Enemy Wave Spawner", "Retrieved entry has correct name")
	assert_eq(retrieved["usage_count"], 5, "Retrieved entry has correct usage_count")
	assert_eq(retrieved["reputation"], 0.85, "Retrieved entry has correct reputation")
	assert_true(retrieved["verified"], "Retrieved entry verified status is true")
	assert_false(retrieved["source_hash"].is_empty(), "source_hash was automatically calculated")

	# Verify keyword extraction
	var keywords: Array = retrieved["keywords"]
	assert_true(keywords.has("enemy"), "Keywords contains 'enemy'")
	assert_true(keywords.has("wave"), "Keywords contains 'wave'")
	assert_true(keywords.has("spawner"), "Keywords contains 'spawner'")
	assert_true(keywords.has("спавнер"), "Keywords contains Russian 'спавнер'")
	assert_true(keywords.has("врагов"), "Keywords contains Russian 'врагов'")
	assert_true(keywords.has("физических"), "Keywords contains Russian 'физических'")
	assert_true(keywords.has("объектов"), "Keywords contains Russian 'объектов'")
	assert_true(keywords.has("physics"), "Keywords contains 'physics'")
	assert_true(keywords.has("spawn"), "Keywords contains code comment keyword 'spawn'")

	# Stopwords excluded from keywords
	assert_false(keywords.has("и"), "Stopword 'и' excluded from keywords")
	assert_false(keywords.has("в"), "Stopword 'в' excluded from keywords")

	# Hash lookup
	var by_hash := cache.get_by_hash(retrieved["source_hash"])
	assert_eq(by_hash["id"], "module_spawner_01", "get_by_hash successfully finds module")

	# Adding second module using code metadata inference
	var mod_data_code_meta := {
		"source_code": """## Name: Gravity Field
## Description: Physics zone applying planetary gravity
## Tags: physics, gravity, orbital
extends Area3D
"""
	}
	var added_code_meta := cache.add_module(mod_data_code_meta)
	assert_true(added_code_meta, "add_module infers ID and metadata from code")
	var grav_mod := cache.get_by_id("gravity_field")
	assert_eq(grav_mod["name"], "Gravity Field", "Inferred name matches code metadata")
	assert_true(grav_mod["tags"].has("gravity"), "Inferred tags match code metadata")

	assert_eq(cache.get_total_modules_count(), 2, "Total modules count is 2")
	var unique_tags := cache.get_unique_tags()
	assert_true(unique_tags.has("ai"), "Unique tags has 'ai'")
	assert_true(unique_tags.has("gravity"), "Unique tags has 'gravity'")
	assert_true(unique_tags.has("orbital"), "Unique tags has 'orbital'")

# ------------------------------------------------------------------------------
# 5. Search and ranking tests
# ------------------------------------------------------------------------------
func test_search_and_ranking() -> void:
	print("\n--- Test Group 5: Search & Ranking ---")

	var cache: SemanticCache = track_node(SemanticCache.new())
	cache.current_cache_path = TEST_CACHE_PATH
	cache.clear_cache()

	# Populate 3 distinct modules
	cache.add_module({
		"id": "mod_laser",
		"name": "Laser Blaster",
		"description": "High damage energy laser weapon system",
		"tags": ["weapon", "laser", "combat"],
		"reputation": 0.9,
		"usage_count": 100,
		"verified": true,
		"source_code": "extends Node\n"
	})

	cache.add_module({
		"id": "mod_shield",
		"name": "Energy Shield Generator",
		"description": "Protective bubble deflecting laser beams and physical projectiles",
		"tags": ["defense", "shield", "energy"],
		"reputation": 0.7,
		"usage_count": 50,
		"verified": true,
		"source_code": "extends Node\n"
	})

	cache.add_module({
		"id": "mod_terrain",
		"name": "Procedural Terrain Voxel",
		"description": "Voxel based terrain generator with cave systems",
		"tags": ["terrain", "voxel", "procedural", "3d"],
		"reputation": 0.6,
		"usage_count": 30,
		"verified": false,
		"source_code": "extends Node\n"
	})

	# 5.1 Search by exact tag
	var res_tag := cache.search("combat")
	assert_true(res_tag.size() >= 1, "Search by tag 'combat' returned results")
	assert_eq(res_tag[0]["id"], "mod_laser", "Laser blaster ranked #1 for 'combat'")
	assert_true(res_tag[0]["score"] >= 0.3, "Score exceeds minimum threshold")

	# 5.2 Search by description keyword
	var res_desc := cache.search("deflecting projectiles")
	assert_true(res_desc.size() >= 1, "Search by description keywords returned results")
	assert_eq(res_desc[0]["id"], "mod_shield", "Shield generator ranked #1 for deflection query")

	# 5.3 Multi-term search with ranking comparison
	# "laser" appears in mod_laser (name, tag, description) and in mod_shield (description only)
	var res_laser := cache.search("laser weapon", 5, 0.2)
	assert_true(res_laser.size() >= 1, "Search for 'laser weapon' found results")
	assert_eq(res_laser[0]["id"], "mod_laser", "Laser weapon ranked higher than shield")
	if res_laser.size() > 1:
		assert_true(res_laser[0]["score"] > res_laser[1]["score"], "Higher score sorted first")

	# 5.4 Search result structure verification
	var first_res: Dictionary = res_laser[0]
	assert_true(first_res.has("module_data"), "Result contains 'module_data'")
	assert_true(first_res.has("score"), "Result contains 'score'")
	assert_true(first_res.has("id"), "Result contains 'id'")
	assert_true(first_res.has("name"), "Result contains 'name'")
	assert_true(first_res.has("description"), "Result contains 'description'")
	assert_true(first_res.has("source_code"), "Result contains 'source_code'")
	assert_true(first_res.has("source_hash"), "Result contains 'source_hash'")

	# 5.5 Max results limit
	var res_limit := cache.search("energy", 1, 0.1)
	assert_eq(res_limit.size(), 1, "max_results = 1 respected")

	# 5.6 Min score filter for irrelevant queries
	var res_irrelevant := cache.search("totally_unrelated_query_xylophone_999", 5, 0.3)
	assert_eq(res_irrelevant.size(), 0, "Irrelevant query filtered out by min_score")

	# 5.7 Empty query
	var res_empty := cache.search("")
	assert_eq(res_empty.size(), 0, "Empty query returns empty array")

	# 5.8 get_all_verified
	var verified_mods := cache.get_all_verified()
	assert_eq(verified_mods.size(), 2, "get_all_verified returns only 2 verified modules")

# ------------------------------------------------------------------------------
# 6. Usage and reputation tests
# ------------------------------------------------------------------------------
func test_usage_and_reputation() -> void:
	print("\n--- Test Group 6: Usage & Reputation ---")

	var cache: SemanticCache = track_node(SemanticCache.new())
	cache.current_cache_path = TEST_CACHE_PATH

	var signal_captured := [false, "", ""]
	cache.cache_updated.connect(func(mid: String, act: String):
		signal_captured[0] = true
		signal_captured[1] = mid
		signal_captured[2] = act
	)

	cache.add_module({
		"id": "mod_stats_test",
		"name": "Stats Test",
		"description": "Testing usage and reputation increments",
		"usage_count": 10,
		"reputation": 0.50
	})

	# Test increment_usage
	signal_captured[0] = false
	cache.increment_usage("mod_stats_test")
	assert_true(signal_captured[0], "increment_usage emitted cache_updated")
	assert_eq(signal_captured[1], "mod_stats_test", "Signal module ID matches")
	assert_eq(signal_captured[2], "usage_incremented", "Signal action is 'usage_incremented'")

	var item := cache.get_by_id("mod_stats_test")
	assert_eq(item["usage_count"], 11, "usage_count incremented to 11")
	assert_true(is_equal_approx(item["reputation"], 0.52), "reputation incremented by +0.02")

	# Test update_reputation
	signal_captured[0] = false
	cache.update_reputation("mod_stats_test", 0.15)
	assert_true(signal_captured[0], "update_reputation emitted cache_updated")
	assert_eq(signal_captured[2], "reputation_updated", "Signal action is 'reputation_updated'")

	item = cache.get_by_id("mod_stats_test")
	assert_true(is_equal_approx(item["reputation"], 0.67), "reputation updated with delta +0.15")

	# Test reputation clamping to 1.0
	cache.update_reputation("mod_stats_test", 1.5)
	item = cache.get_by_id("mod_stats_test")
	assert_eq(item["reputation"], 1.0, "reputation clamped at 1.0 max")

	# Test reputation clamping to 0.0
	cache.update_reputation("mod_stats_test", -2.0)
	item = cache.get_by_id("mod_stats_test")
	assert_eq(item["reputation"], 0.0, "reputation clamped at 0.0 min")

	# Test get_popular_modules
	var popular := cache.get_popular_modules(5)
	assert_true(popular.size() >= 1, "get_popular_modules returns modules")
	assert_true(popular[0]["usage_count"] >= 11, "Most used module is first")

# ------------------------------------------------------------------------------
# 7. Persistence and removal tests
# ------------------------------------------------------------------------------
func test_persistence_and_removal() -> void:
	print("\n--- Test Group 7: Persistence & Removal ---")

	var cache_1: SemanticCache = track_node(SemanticCache.new())
	cache_1.current_cache_path = TEST_CACHE_PATH
	cache_1.clear_cache()

	cache_1.add_module({
		"id": "persist_mod_1",
		"name": "Persistence Module 1",
		"description": "Module for testing JSON persistence across restarts",
		"tags": ["storage", "json"],
		"source_code": "extends Node\nfunc persist(): pass\n",
		"usage_count": 42,
		"reputation": 0.77,
		"verified": true
	})

	var saved := cache_1.save_to_disk(TEST_CACHE_PATH)
	assert_true(saved, "save_to_disk succeeded")
	assert_true(FileAccess.file_exists(TEST_CACHE_PATH), "Cache file exists on disk")

	# Create second instance to load from disk
	var cache_2: SemanticCache = track_node(SemanticCache.new())
	cache_2.current_cache_path = TEST_CACHE_PATH
	var loaded := cache_2.load_from_disk(TEST_CACHE_PATH)
	assert_true(loaded, "load_from_disk succeeded on fresh cache instance")
	assert_eq(cache_2.get_total_modules_count(), 1, "Restored exactly 1 module")

	var loaded_mod := cache_2.get_by_id("persist_mod_1")
	assert_eq(loaded_mod["name"], "Persistence Module 1", "Restored module name matches")
	assert_eq(loaded_mod["usage_count"], 42, "Restored usage_count matches")
	assert_true(is_equal_approx(loaded_mod["reputation"], 0.77), "Restored reputation matches")
	assert_true(loaded_mod["verified"], "Restored verified status matches")
	assert_true(loaded_mod["tags"].has("storage"), "Restored tags match")
	assert_true(loaded_mod["keywords"].has("persistence"), "Restored keywords match")

	# Test remove_module
	var signal_captured := [false, "", ""]
	cache_2.cache_updated.connect(func(mid: String, act: String):
		signal_captured[0] = true
		signal_captured[1] = mid
		signal_captured[2] = act
	)

	var removed := cache_2.remove_module("persist_mod_1")
	assert_true(removed, "remove_module returned true")
	assert_true(signal_captured[0], "remove_module emitted cache_updated")
	assert_eq(signal_captured[1], "persist_mod_1", "Removed module ID in signal")
	assert_eq(signal_captured[2], "removed", "Signal action is 'removed'")
	assert_eq(cache_2.get_total_modules_count(), 0, "Module successfully erased from cache")

	# Test clear_cache
	cache_2.add_module({"id": "dummy_1", "name": "Dummy"})
	cache_2.add_module({"id": "dummy_2", "name": "Dummy 2"})
	assert_eq(cache_2.get_total_modules_count(), 2, "Added 2 dummy modules")

	signal_captured[0] = false
	cache_2.clear_cache()
	assert_true(signal_captured[0], "clear_cache emitted signal")
	assert_eq(signal_captured[2], "cleared", "Signal action is 'cleared'")
	assert_eq(cache_2.get_total_modules_count(), 0, "Cache is empty after clear_cache")
