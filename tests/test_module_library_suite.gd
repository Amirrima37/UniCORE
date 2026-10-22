extends SceneTree

# ==============================================================================
# UniCORE Test Suite: ModuleLibrary Backend Suite
# ==============================================================================

const ModuleLibrary = preload("res://core/module_library.gd")
const ModuleManager = preload("res://core/module_manager.gd")
const EventBus = preload("res://core/event_bus.gd")
const CodeValidator = preload("res://agent/code_validator.gd")
const ModuleGalleryScene = preload("res://ui/module_gallery/module_gallery.tscn")
const MainMenuScene = preload("res://ui/menu/main_menu.tscn")
const SettingsManager = preload("res://core/settings_manager.gd")
const SpaceManager = preload("res://core/space_manager.gd")

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
	print("Starting ModuleLibrary Backend Test Suite")
	print("==================================================")

	var library := ModuleLibrary.new()
	var module_mgr := ModuleManager.new()
	var event_bus := EventBus.new()
	var world_root := Node3D.new()
	module_mgr.setup(event_bus, world_root)

	# --------------------------------------------------------------------------
	# Test 1: Setup and Signal Connection
	# --------------------------------------------------------------------------
	print("\n--- Test 1: Setup and Initial Scan ---")
	var library_updated_emitted := [false]
	library.library_updated.connect(func(): library_updated_emitted[0] = true)
	library.setup(module_mgr, event_bus)

	assert_true(library_updated_emitted[0], "library_updated emitted during setup/scan")

	var all_mods := library.get_all_modules()
	assert_true(all_mods.size() > 0, "Catalog is populated after scan", "Size: %d" % all_mods.size())

	# --------------------------------------------------------------------------
	# Test 2: Field Schema Validation
	# --------------------------------------------------------------------------
	print("\n--- Test 2: Field Schema Validation ---")
	var required_fields := [
		"id", "name", "description", "category", "file_path",
		"is_builtin", "is_active", "created_at", "file_size", "tags", "source"
	]
	var schema_ok := true
	for item in all_mods:
		for f in required_fields:
			if not item.has(f):
				schema_ok = false
				print("Missing field: %s in module %s" % [f, item.get("id", "unknown")])
				break
	assert_true(schema_ok, "All catalog items conform to required schema")

	# --------------------------------------------------------------------------
	# Test 3: Built-in, User, and Registry Classification
	# --------------------------------------------------------------------------
	print("\n--- Test 3: Module Source and Built-in Checks ---")
	var ground_mod: Dictionary = {}
	var locomotion_mod: Dictionary = {}
	var cube_mod: Dictionary = {}
	var sphere_mod: Dictionary = {}

	for m in all_mods:
		match m.get("id", ""):
			"builtin_ground_plane":
				ground_mod = m
			"builtin_avatar_locomotion":
				locomotion_mod = m
			"cube_spawner_tool":
				cube_mod = m
			"sphere_spawner_tool":
				sphere_mod = m

	assert_false(ground_mod.is_empty(), "Found builtin_ground_plane in catalog")
	if not ground_mod.is_empty():
		assert_true(ground_mod["is_builtin"], "ground_plane is_builtin == true")
		assert_eq(ground_mod["source"], "builtin", "ground_plane source == 'builtin'")
		assert_eq(ground_mod["category"], "environment", "ground_plane category == 'environment'")

	assert_false(locomotion_mod.is_empty(), "Found builtin_avatar_locomotion in catalog")
	if not locomotion_mod.is_empty():
		assert_true(locomotion_mod["is_builtin"], "avatar_locomotion is_builtin == true")
		assert_eq(locomotion_mod["source"], "builtin", "avatar_locomotion source == 'builtin'")
		assert_eq(locomotion_mod["category"], "camera", "avatar_locomotion category == 'camera'")

	assert_false(cube_mod.is_empty(), "Found cube_spawner_tool in catalog")
	if not cube_mod.is_empty():
		assert_false(cube_mod["is_builtin"], "cube_spawner_tool is_builtin == false")
		assert_eq(cube_mod["source"], "user", "cube_spawner_tool on disk source == 'user'")
		assert_eq(cube_mod["category"], "tools", "cube_spawner_tool category == 'tools'")

	assert_false(sphere_mod.is_empty(), "Found sphere_spawner_tool in catalog")
	if not sphere_mod.is_empty():
		assert_false(sphere_mod["is_builtin"], "sphere_spawner_tool is_builtin == false")
		assert_eq(sphere_mod["source"], "registry", "sphere_spawner_tool source == 'registry'")

	# --------------------------------------------------------------------------
	# Test 4: Category Filtering
	# --------------------------------------------------------------------------
	print("\n--- Test 4: Category Filtering ---")
	var tools_mods := library.get_modules_by_category("tools")
	assert_true(tools_mods.size() >= 2, "Filtered 'tools' returned multiple modules", "Count: %d" % tools_mods.size())
	for tm in tools_mods:
		assert_eq(tm.get("category", ""), "tools", "Module %s belongs to tools" % tm.get("id", ""))

	var camera_mods := library.get_modules_by_category("CAMERA") # Test case-insensitivity
	assert_true(camera_mods.size() >= 1, "Case-insensitive category filter works", "Count: %d" % camera_mods.size())

	var all_by_cat := library.get_modules_by_category("all")
	assert_eq(all_by_cat.size(), all_mods.size(), "get_modules_by_category('all') returns all modules")

	# --------------------------------------------------------------------------
	# Test 5: Dynamic is_active state with ModuleManager
	# --------------------------------------------------------------------------
	print("\n--- Test 5: Dynamic is_active with ModuleManager ---")
	var initial_cube: Dictionary = {}
	for m in library.get_all_modules():
		if m["id"] == "cube_spawner_tool":
			initial_cube = m
			break
	assert_false(initial_cube["is_active"], "cube_spawner_tool initially inactive")

	var cube_src := library.get_module_source("cube_spawner_tool")
	assert_true(cube_src.length() > 0, "get_module_source retrieves code for cube_spawner_tool")

	var spawned_node = module_mgr.load_module_from_source("cube_spawner_tool", cube_src)
	assert_true(spawned_node != null, "ModuleManager loaded cube_spawner_tool")

	var active_cube: Dictionary = {}
	for m in library.get_all_modules():
		if m["id"] == "cube_spawner_tool":
			active_cube = m
			break
	assert_true(active_cube["is_active"], "cube_spawner_tool is_active == true after mount")

	module_mgr.unload_module("cube_spawner_tool")
	var inactive_cube: Dictionary = {}
	for m in library.get_all_modules():
		if m["id"] == "cube_spawner_tool":
			inactive_cube = m
			break
	assert_false(inactive_cube["is_active"], "cube_spawner_tool is_active == false after unmount")

	# --------------------------------------------------------------------------
	# Test 6: Built-in Protection against Deletion and Renaming
	# --------------------------------------------------------------------------
	print("\n--- Test 6: Built-in Protection ---")
	var del_builtin := library.delete_module("builtin_ground_plane")
	assert_false(del_builtin, "delete_module rejected on built-in module")

	var ren_builtin := library.rename_module("builtin_ground_plane", "custom_ground_plane")
	assert_false(ren_builtin, "rename_module rejected on built-in module")

	# --------------------------------------------------------------------------
	# Test 7: Duplicate Module
	# --------------------------------------------------------------------------
	print("\n--- Test 7: Duplicate Module ---")
	var dup_id := "test_duplicated_spawner"
	var dup_ok := library.duplicate_module("cube_spawner_tool", dup_id)
	assert_true(dup_ok, "duplicate_module succeeded")

	var dup_src := library.get_module_source(dup_id)
	assert_true(dup_src.contains('return "%s"' % dup_id), "Duplicated module has updated get_module_id() return value")
	assert_true(FileAccess.file_exists("res://modules/%s.gd" % dup_id), "Duplicated file exists on disk")

	# --------------------------------------------------------------------------
	# Test 8: Rename Module
	# --------------------------------------------------------------------------
	print("\n--- Test 8: Rename Module ---")
	var ren_id := "test_renamed_spawner"
	var ren_ok := library.rename_module(dup_id, ren_id)
	assert_true(ren_ok, "rename_module succeeded")
	assert_false(FileAccess.file_exists("res://modules/%s.gd" % dup_id), "Old file removed after rename")
	assert_true(FileAccess.file_exists("res://modules/%s.gd" % ren_id), "New file created after rename")

	var ren_src := library.get_module_source(ren_id)
	assert_true(ren_src.contains('return "%s"' % ren_id), "Renamed module has updated get_module_id()")

	# --------------------------------------------------------------------------
	# Test 9: Delete Module
	# --------------------------------------------------------------------------
	print("\n--- Test 9: Delete Module ---")
	var del_ok := library.delete_module(ren_id)
	assert_true(del_ok, "delete_module succeeded for user module")
	assert_false(FileAccess.file_exists("res://modules/%s.gd" % ren_id), "File removed from disk")

	# --------------------------------------------------------------------------
	# Test 10: Export Module
	# --------------------------------------------------------------------------
	print("\n--- Test 10: Export Module ---")
	var export_path := "user://test_export_sphere.gd"
	var exp_ok := library.export_module("sphere_spawner_tool", export_path)
	assert_true(exp_ok, "export_module succeeded for registry template")
	assert_true(FileAccess.file_exists(export_path), "Exported file created on disk")

	var exp_f := FileAccess.open(export_path, FileAccess.READ)
	assert_true(exp_f != null, "Can open exported file")
	if exp_f:
		var exp_content := exp_f.get_as_text()
		exp_f.close()
		assert_true(exp_content.contains("sphere_spawner_tool"), "Exported content matches module source")

	# --------------------------------------------------------------------------
	# Test 11: Import Module (Safe & Unsafe)
	# --------------------------------------------------------------------------
	print("\n--- Test 11: Import Module ---")
	# Valid import
	var imp_res := library.import_module(export_path)
	assert_true(imp_res.get("success", false), "import_module succeeded with valid code")
	var imported_id: String = imp_res.get("module_id", "")
	assert_eq(imported_id, "sphere_spawner_tool", "Imported module ID matches")
	assert_true(FileAccess.file_exists("res://modules/%s.gd" % imported_id), "Imported module saved to res://modules/")

	# Clean up imported user file
	var del_imported := library.delete_module(imported_id)
	assert_true(del_imported, "delete_module cleaned up imported module file")

	# Malicious import rejection
	var unsafe_path := "user://test_unsafe_module.gd"
	var unsafe_code := """extends UniCoreModule
func get_module_id() -> String:
	return "unsafe_tool"
func initialize(context: Dictionary) -> bool:
	OS.execute("calc.exe", [])
	return true
func cleanup() -> void:
	pass
"""
	var uf := FileAccess.open(unsafe_path, FileAccess.WRITE)
	if uf:
		uf.store_string(unsafe_code)
		uf.close()

	var unsafe_imp := library.import_module(unsafe_path)
	assert_false(unsafe_imp.get("success", true), "import_module rejected dangerous code with OS.execute")
	assert_true(unsafe_imp.get("error", "").contains("OS.execute"), "Error message mentions OS.execute security violation")
	assert_false(FileAccess.file_exists("res://modules/unsafe_tool.gd"), "Malicious file was NOT written to res://modules/")

	# Clean up temporary test files
	DirAccess.remove_absolute(export_path)
	DirAccess.remove_absolute(unsafe_path)

	# --------------------------------------------------------------------------
	# Test 12: ModuleGallery UI Component & Signals
	# --------------------------------------------------------------------------
	print("\n--- Test 12: ModuleGallery UI Component ---")
	var gallery = ModuleGalleryScene.instantiate()
	root.add_child(gallery)
	gallery.setup(library, module_mgr)

	assert_true(gallery != null, "ModuleGallery instantiated")
	assert_true(gallery.get_module_library() == library, "ModuleGallery has ModuleLibrary reference")
	assert_true(gallery.get_module_manager() == module_mgr, "ModuleGallery has ModuleManager reference")

	# Test category filter & search UI
	assert_true(gallery.category_opt != null, "Category OptionButton exists")
	assert_true(gallery.category_opt.item_count > 0, "Category options populated")
	assert_true(gallery.search_edit != null, "Search LineEdit exists")
	assert_true(gallery.grid_container != null, "Card GridContainer exists")

	# Test card view code signal
	var view_code_emitted := [false]
	var view_code_id := [""]
	gallery.view_code_requested.connect(func(mid, _code):
		view_code_emitted[0] = true
		view_code_id[0] = mid
	)
	gallery._on_view_code("cube_spawner_tool")
	assert_true(view_code_emitted[0], "view_code_requested signal emitted")
	assert_eq(view_code_id[0], "cube_spawner_tool", "view_code_requested emitted for cube_spawner_tool")

	gallery.queue_free()

	# --------------------------------------------------------------------------
	# Test 13: MainMenu Library Tab Integration
	# --------------------------------------------------------------------------
	print("\n--- Test 13: MainMenu Library Tab Integration ---")
	var settings_mgr = SettingsManager.new()
	var space_mgr = SpaceManager.new()
	root.add_child(settings_mgr)
	root.add_child(space_mgr)

	var menu = MainMenuScene.instantiate()
	root.add_child(menu)
	menu.setup(settings_mgr, space_mgr, module_mgr, event_bus, library)

	assert_true(menu.module_gallery != null, "MainMenu automatically instantiates ModuleGallery")
	assert_true(menu.library_tab != null, "MainMenu has LibraryTab MarginContainer")

	menu.open("library")
	assert_true(menu.is_open, "MainMenu opened on library request")
	assert_eq(menu.tab_container.current_tab, 2, "TabContainer switched to LibraryTab (tab 2)")

	menu.open("spaces")
	assert_eq(menu.tab_container.current_tab, 0, "TabContainer switched to SpacesTab (tab 0)")

	menu.open("settings")
	assert_eq(menu.tab_container.current_tab, 1, "TabContainer switched to SettingsTab (tab 1)")

	menu.close()
	assert_false(menu.is_open, "MainMenu closed")

	menu.queue_free()
	settings_mgr.queue_free()
	space_mgr.queue_free()

	# Clean up scene objects
	world_root.free()
	module_mgr.free()
	event_bus.free()
	library.free()

	print("\n==================================================")
	print("ModuleLibrary Test Results: %d Passed, %d Failed" % [passed_count, failed_count])
	print("==================================================")

	quit(1 if failed_count > 0 else 0)
