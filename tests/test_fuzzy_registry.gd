extends SceneTree

# ==============================================================================
# UniCORE Test Suite: Fuzzy Registry Search & Enhanced ModuleRegistryClient
# Tests Levenshtein distance, similarity calculations, fuzzy search with typos,
# verified templates compilation, and UniCoreModule inheritance.
# ==============================================================================

const ModuleRegistryClient = preload("res://core/module_registry_client.gd")

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

func assert_ge(val: float, expected: float, test_name: String) -> void:
	assert_true(val >= expected, test_name, "Expected >= %f, got %f" % [expected, val])

func assert_in_range(val: float, min_val: float, max_val: float, test_name: String) -> void:
	assert_true(val >= min_val and val <= max_val, test_name, "Expected [%f, %f], got %f" % [min_val, max_val, val])

func _init() -> void:
	print("==================================================")
	print("UniCORE: Fuzzy Registry Search & Registry Audit")
	print("==================================================")

	assert_true(ModuleRegistryClient != null, "ModuleRegistryClient loaded successfully")

	# --------------------------------------------------------------------------
	# Group 1: Levenshtein Distance Algorithm Unit Tests
	# --------------------------------------------------------------------------
	print("\n--- Group 1: Levenshtein Distance Algorithm Unit Tests ---")
	assert_eq(ModuleRegistryClient.levenshtein_distance("", ""), 0, "Levenshtein empty strings is 0")
	assert_eq(ModuleRegistryClient.levenshtein_distance("hello", "hello"), 0, "Levenshtein identical strings is 0")
	assert_eq(ModuleRegistryClient.levenshtein_distance("", "test"), 4, "Levenshtein empty to 4-char string is 4")
	assert_eq(ModuleRegistryClient.levenshtein_distance("test", ""), 4, "Levenshtein 4-char to empty is 4")
	assert_eq(ModuleRegistryClient.levenshtein_distance("kitten", "sitting"), 3, "Levenshtein 'kitten' to 'sitting' is 3")
	assert_eq(ModuleRegistryClient.levenshtein_distance("кубик", "кубик"), 0, "Levenshtein identical Cyrillic is 0")
	assert_eq(ModuleRegistryClient.levenshtein_distance("кубик", "кубики"), 1, "Levenshtein 'кубик' -> 'кубики' is 1")
	assert_eq(ModuleRegistryClient.levenshtein_distance("кубик", "куб"), 2, "Levenshtein 'кубик' -> 'куб' is 2")
	assert_eq(ModuleRegistryClient.levenshtein_distance("гравитация", "гравитаця"), 1, "Levenshtein 'гравитация' -> 'гравитаця' is 1")
	assert_eq(ModuleRegistryClient.levenshtein_distance("партиклы", "партикли"), 1, "Levenshtein 'партиклы' -> 'партикли' is 1")
	assert_eq(ModuleRegistryClient.levenshtein_distance("освещение", "освещени"), 1, "Levenshtein 'освещение' -> 'освещени' is 1")
	assert_eq(ModuleRegistryClient.levenshtein_distance("земля", "земя"), 1, "Levenshtein 'земля' -> 'земя' is 1")
	assert_eq(ModuleRegistryClient.levenshtein_distance("сферы", "сферры"), 1, "Levenshtein 'сферы' -> 'сферры' is 1")

	# --------------------------------------------------------------------------
	# Group 2: Similarity Scoring Function (_calculate_similarity)
	# --------------------------------------------------------------------------
	print("\n--- Group 2: Similarity Scoring Verification ---")
	var sample_tags = ["cube", "spawner", "3d", "куб", "кубик"]
	var sample_name = "Инструмент: Спавнер Красных Кубов"
	var sample_desc = "Инструмент создания интерактивных кубов"

	# 1) Точное совпадение (1.0)
	var exact_score_tag = ModuleRegistryClient._calculate_similarity("кубик", sample_tags, sample_name, sample_desc)
	assert_eq(exact_score_tag, 1.0, "Exact tag match gives 1.0")
	var exact_score_id = ModuleRegistryClient._calculate_similarity("cube_tool", sample_tags, sample_name, sample_desc, "cube_tool")
	assert_eq(exact_score_id, 1.0, "Exact id match gives 1.0")

	# 2) Вхождение подстроки (0.75-0.9)
	var sub_score_tag = ModuleRegistryClient._calculate_similarity("spawn", sample_tags, sample_name, sample_desc)
	assert_in_range(sub_score_tag, 0.75, 0.90, "Substring match in tags falls in [0.75, 0.9]")
	var sub_score_desc = ModuleRegistryClient._calculate_similarity("интерактивных", [], "Простой Модуль", sample_desc)
	assert_in_range(sub_score_desc, 0.75, 0.90, "Substring match in description falls in [0.75, 0.9]")

	# 3) Пересечение ключевых слов (0.5-0.8)
	var kw_score = ModuleRegistryClient._calculate_similarity("красных кубов", ["разное"], sample_name, sample_desc)
	assert_in_range(kw_score, 0.50, 0.85, "Keyword intersection score is in [0.5, 0.85]")

	# 4) Нормализованное расстояние Левенштейна для опечаток (0.3-0.7)
	var typo_score = ModuleRegistryClient._calculate_similarity("кубек", ["кубик"], "Тестовый Модуль", "Описание без совпадений")
	assert_in_range(typo_score, 0.30, 0.70, "Typo with 1 edit substitution falls in [0.3, 0.7]")

	# 5) Полное несовпадение -> 0.0
	var zero_score = ModuleRegistryClient._calculate_similarity("абсолютно_другое_слово_999", sample_tags, sample_name, sample_desc)
	assert_eq(zero_score, 0.0, "Completely unrelated query gives 0.0 similarity")

	# --------------------------------------------------------------------------
	# Group 3: Fuzzy Search Queries Specified in Requirements
	# Checks: 'кубик', 'сферы', 'освещение', 'земля', 'гравитация', 'партиклы'
	# --------------------------------------------------------------------------
	print("\n--- Group 3: Fuzzy Search Required Keywords & Variants ---")

	var q_cube = ModuleRegistryClient.fuzzy_search("кубик")
	assert_true(not q_cube.is_empty(), "Search 'кубик' found template")
	assert_eq(q_cube.get("id"), "cube_spawner_tool", "Search 'кубик' resolved to cube_spawner_tool")

	var q_sphere = ModuleRegistryClient.fuzzy_search("сферы")
	assert_true(not q_sphere.is_empty(), "Search 'сферы' found template")
	assert_eq(q_sphere.get("id"), "sphere_spawner_tool", "Search 'сферы' resolved to sphere_spawner_tool")

	var q_light = ModuleRegistryClient.fuzzy_search("освещение")
	assert_true(not q_light.is_empty(), "Search 'освещение' found template")
	assert_eq(q_light.get("id"), "lighting_setup", "Search 'освещение' resolved to lighting_setup")

	var q_ground = ModuleRegistryClient.fuzzy_search("земля")
	assert_true(not q_ground.is_empty(), "Search 'земля' found template")
	assert_eq(q_ground.get("id"), "ground_plane_color", "Search 'земля' resolved to ground_plane_color")

	var q_grav = ModuleRegistryClient.fuzzy_search("гравитация")
	assert_true(not q_grav.is_empty(), "Search 'гравитация' found template")
	assert_eq(q_grav.get("id"), "physics_gravity", "Search 'гравитация' resolved to physics_gravity")

	var q_part = ModuleRegistryClient.fuzzy_search("партиклы")
	assert_true(not q_part.is_empty(), "Search 'партиклы' found template")
	assert_eq(q_part.get("id"), "particle_system", "Search 'партиклы' resolved to particle_system")

	# --------------------------------------------------------------------------
	# Group 4: Robust Typos & Misspellings (Real Fuzzy Tests)
	# --------------------------------------------------------------------------
	print("\n--- Group 4: Typos and Misspellings Resilience ---")

	var typo_cube = ModuleRegistryClient.fuzzy_search("кубикк")
	assert_eq(typo_cube.get("id"), "cube_spawner_tool", "Typo 'кубикк' resolved to cube_spawner_tool")

	var typo_sphere = ModuleRegistryClient.fuzzy_search("сферры")
	assert_eq(typo_sphere.get("id"), "sphere_spawner_tool", "Typo 'сферры' resolved to sphere_spawner_tool")

	var typo_light = ModuleRegistryClient.fuzzy_search("освещени")
	assert_eq(typo_light.get("id"), "lighting_setup", "Typo 'освещени' resolved to lighting_setup")

	var typo_ground = ModuleRegistryClient.fuzzy_search("земя")
	assert_eq(typo_ground.get("id"), "ground_plane_color", "Typo 'земя' resolved to ground_plane_color")

	var typo_grav = ModuleRegistryClient.fuzzy_search("гравитаця")
	assert_eq(typo_grav.get("id"), "physics_gravity", "Typo 'гравитаця' resolved to physics_gravity")

	var typo_part = ModuleRegistryClient.fuzzy_search("партикли")
	assert_eq(typo_part.get("id"), "particle_system", "Typo 'партикли' resolved to particle_system")

	# English typos
	var typo_en_grav = ModuleRegistryClient.fuzzy_search("graviti")
	assert_eq(typo_en_grav.get("id"), "physics_gravity", "English typo 'graviti' resolved to physics_gravity")

	var typo_en_part = ModuleRegistryClient.fuzzy_search("particls")
	assert_eq(typo_en_part.get("id"), "particle_system", "English typo 'particls' resolved to particle_system")

	var typo_en_cam = ModuleRegistryClient.fuzzy_search("cameera")
	assert_eq(typo_en_cam.get("id"), "camera_effects", "English typo 'cameera' resolved to camera_effects")

	# Extended realistic Cyrillic typos
	assert_eq(ModuleRegistryClient.fuzzy_search("кубек").get("id"), "cube_spawner_tool", "Typo 'кубек' resolved to cube_spawner_tool")
	assert_eq(ModuleRegistryClient.fuzzy_search("освешение").get("id"), "lighting_setup", "Typo 'освешение' resolved to lighting_setup")
	assert_eq(ModuleRegistryClient.fuzzy_search("гравитацыя").get("id"), "physics_gravity", "Typo 'гравитацыя' resolved to physics_gravity")
	assert_eq(ModuleRegistryClient.fuzzy_search("партикл").get("id"), "particle_system", "Typo 'партикл' resolved to particle_system")
	assert_eq(ModuleRegistryClient.fuzzy_search("сфери").get("id"), "sphere_spawner_tool", "Typo 'сфери' resolved to sphere_spawner_tool")
	assert_eq(ModuleRegistryClient.fuzzy_search("зимля").get("id"), "ground_plane_color", "Typo 'зимля' resolved to ground_plane_color")

	# Multi-word semantic queries
	assert_eq(ModuleRegistryClient.fuzzy_search("красный кубик").get("id"), "cube_spawner_tool", "Multi-word 'красный кубик' resolved to cube_spawner_tool")
	assert_eq(ModuleRegistryClient.fuzzy_search("синяя сфера").get("id"), "sphere_spawner_tool", "Multi-word 'синяя сфера' resolved to sphere_spawner_tool")
	assert_eq(ModuleRegistryClient.fuzzy_search("кибер освещение").get("id"), "lighting_setup", "Multi-word 'кибер освещение' resolved to lighting_setup")
	assert_eq(ModuleRegistryClient.fuzzy_search("фонтан частиц").get("id"), "particle_system", "Multi-word 'фонтан частиц' resolved to particle_system")
	assert_eq(ModuleRegistryClient.fuzzy_search("покачивание камеры").get("id"), "camera_effects", "Multi-word 'покачивание камеры' resolved to camera_effects")
	assert_eq(ModuleRegistryClient.fuzzy_search("физический кубик").get("id"), "physics_gravity", "Multi-word 'физический кубик' resolved to physics_gravity")

	# --------------------------------------------------------------------------
	# Group 5: Edge Cases, Thresholds, and Backward Compatibility
	# --------------------------------------------------------------------------
	print("\n--- Group 5: Edge Cases & Backward Compatibility ---")

	assert_true(ModuleRegistryClient.fuzzy_search("").is_empty(), "Empty query returns empty dict")
	assert_true(ModuleRegistryClient.fuzzy_search("   ").is_empty(), "Whitespace query returns empty dict")
	assert_true(ModuleRegistryClient.fuzzy_search("xyz_non_existent_token_404").is_empty(), "Non-existent token returns empty dict")

	# Single-character queries protection (must not trigger false substring matches)
	assert_true(ModuleRegistryClient.fuzzy_search("a").is_empty(), "Single-character 'a' returns empty dict")
	assert_true(ModuleRegistryClient.fuzzy_search("e").is_empty(), "Single-character 'e' returns empty dict")
	assert_true(ModuleRegistryClient.fuzzy_search("х").is_empty(), "Single-character Cyrillic 'х' returns empty dict")

	# Punctuated queries
	assert_eq(ModuleRegistryClient.fuzzy_search("«кубик»").get("id"), "cube_spawner_tool", "Punctuated '«кубик»' resolved to cube_spawner_tool")
	assert_eq(ModuleRegistryClient.fuzzy_search("[гравитация]!").get("id"), "physics_gravity", "Punctuated '[гравитация]!' resolved to physics_gravity")

	# Backward compatible search_template function
	var st_cube = ModuleRegistryClient.search_template("кубик")
	assert_eq(st_cube.get("id"), "cube_spawner_tool", "search_template('кубик') works via fuzzy_search")

	var st_part = ModuleRegistryClient.search_template("партиклы")
	assert_eq(st_part.get("id"), "particle_system", "search_template('партиклы') works via fuzzy_search")

	var st_cam = ModuleRegistryClient.search_template("камера")
	assert_eq(st_cam.get("id"), "camera_effects", "search_template('камера') works via fuzzy_search")

	# --------------------------------------------------------------------------
	# Group 6: get_all_templates() Verification
	# --------------------------------------------------------------------------
	print("\n--- Group 6: get_all_templates() Verification ---")

	var all_templates: Array[Dictionary] = ModuleRegistryClient.get_all_templates()
	print("  Total templates returned by get_all_templates(): %d" % all_templates.size())
	assert_ge(float(all_templates.size()), 8.0, "get_all_templates() returns at least 8 templates")

	var template_ids: Array[String] = []
	for t in all_templates:
		assert_true(t.has("id"), "Template has 'id'")
		assert_true(t.has("name"), "Template has 'name'")
		assert_true(t.has("tags"), "Template has 'tags'")
		assert_true(t.has("category"), "Template has 'category'")
		assert_true(t.has("description"), "Template has 'description'")
		template_ids.append(t["id"])

	# Проверяем наличие всех требуемых шаблонов
	assert_true(template_ids.has("ground_plane_color"), "Templates contain 'ground_plane_color'")
	assert_true(template_ids.has("lighting_setup"), "Templates contain 'lighting_setup'")
	assert_true(template_ids.has("physics_gravity"), "Templates contain 'physics_gravity'")
	assert_true(template_ids.has("camera_effects"), "Templates contain 'camera_effects'")
	assert_true(template_ids.has("particle_system"), "Templates contain 'particle_system'")
	assert_true(template_ids.has("cube_spawner_tool"), "Templates contain 'cube_spawner_tool'")
	assert_true(template_ids.has("sphere_spawner_tool"), "Templates contain 'sphere_spawner_tool'")
	assert_true(template_ids.has("day_night_cycle"), "Templates contain 'day_night_cycle'")
	assert_true(template_ids.has("fps_counter"), "Templates contain 'fps_counter'")

	# --------------------------------------------------------------------------
	# Group 7: Compilation & Inheritance of All Templates (UniCoreModule)
	# --------------------------------------------------------------------------
	print("\n--- Group 7: Compilation & Inheritance of All Templates ---")

	for tmpl in all_templates:
		var tid: String = tmpl["id"]
		var source_code: String = ModuleRegistryClient.get_module_source(tmpl)
		assert_false(source_code.is_empty(), "Source code for '%s' is not empty" % tid)

		var script := GDScript.new()
		script.source_code = source_code
		var err := script.reload()
		assert_eq(err, OK, "GDScript reload OK for '%s'" % tid)

		var inst = script.new()
		assert_true(inst != null, "Instance created for '%s'" % tid)
		assert_true(inst is UniCoreModule, "Instance of '%s' extends UniCoreModule" % tid)
		assert_eq(inst.get_module_id(), tid, "Instance get_module_id() matches template id for '%s'" % tid)
		assert_false(inst.get_module_name().is_empty(), "Instance get_module_name() is not empty for '%s'" % tid)

		# Test lifecycle initialize and cleanup
		root.add_child(inst)
		var init_success: bool = inst.initialize({})
		assert_true(init_success, "Instance initialize() returns true for '%s'" % tid)
		inst.cleanup()
		inst.queue_free()

	print("\n==================================================")
	print("Test Results: %d Passed, %d Failed" % [passed_count, failed_count])
	print("==================================================")

	if failed_count == 0:
		print("AUDIT SUCCESS: All fuzzy registry search & template tests passed with 100% success.")
		quit(0)
	else:
		print("AUDIT FAILED: %d tests failed." % failed_count)
		quit(1)
