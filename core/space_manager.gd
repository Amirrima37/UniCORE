class_name SpaceManager
extends Node

## Менеджер Пространств UniCORE (Space Manager & Serialization)
## Отвечает за создание, сохранение, загрузку и переключение Пространств.
## Каждое Пространство — это автономный снимок мира (активные модули, параметры, окружение).

signal space_loaded(space_data: Dictionary)
signal space_saved(space_name: String, filepath: String)
signal space_created(space_name: String)
signal space_renamed(space_id: String, new_name: String)
signal space_deleted(space_id: String)
signal space_list_updated(spaces: Array)
signal space_error(message: String)

const SPACES_DIR: String = "user://spaces"
const SESSION_FILE: String = "user://session_space.json"
const DEFAULT_SPACE_ID: String = "space_default"

const TEMPLATE_DEFAULT_STUDIO: String = "default"
const TEMPLATE_CYBER_VOID: String = "cyber_void"
const TEMPLATE_CLEAN_SLATE: String = "clean_slate"
const TEMPLATE_TOOL_PLAYGROUND: String = "tool_studio"

var current_space_id: String = DEFAULT_SPACE_ID
var current_space_name: String = "Default Space"
var current_space_data: Dictionary = {}

var _module_manager: ModuleManager
var _event_bus: EventBus
var _world_root: Node3D
var _space_viewport: Node3D
var _settings_manager: Node
var _module_library: ModuleLibrary = null
var _cache_sync: Node = null
var _semantic_cache: Node = null

func setup(
	module_manager: ModuleManager,
	event_bus: EventBus,
	world_root: Node3D,
	space_viewport: Node3D,
	settings_manager: Node = null,
	module_library: ModuleLibrary = null,
	cache_sync: Node = null,
	semantic_cache: Node = null
) -> void:
	_module_manager = module_manager
	_event_bus = event_bus
	_world_root = world_root
	_space_viewport = space_viewport
	_settings_manager = settings_manager
	if module_library != null:
		_module_library = module_library
	if cache_sync != null:
		_cache_sync = cache_sync
	if semantic_cache != null:
		_semantic_cache = semantic_cache

	_ensure_directory_exists(SPACES_DIR)
	_ensure_default_spaces_exist()

	# Пытаемся загрузить последнее активное или дефолтное пространство
	var last_space_id: String = ""
	if _settings_manager and _settings_manager.has_method("get_setting"):
		last_space_id = _settings_manager.get_setting("session", "last_active_space", "")

	if last_space_id.is_empty() and FileAccess.file_exists(SESSION_FILE):
		var session_f := FileAccess.open(SESSION_FILE, FileAccess.READ)
		if session_f:
			var txt := session_f.get_as_text()
			session_f.close()
			var json := JSON.new()
			if json.parse(txt) == OK and json.get_data() is Dictionary:
				last_space_id = json.get_data().get("last_active_space", "")

	if not last_space_id.is_empty() and has_space(last_space_id):
		load_space(last_space_id)
	elif has_space(DEFAULT_SPACE_ID):
		load_space(DEFAULT_SPACE_ID)
	else:
		var spaces := list_spaces()
		if not spaces.is_empty():
			load_space(spaces[0]["id"])
		else:
			create_new_space("Default Studio", "default")

func has_space(space_id: String) -> bool:
	var file_path := "%s/%s.json" % [SPACES_DIR, space_id]
	return FileAccess.file_exists(file_path)

func _persist_last_space(space_id: String) -> void:
	if _settings_manager and _settings_manager.has_method("set_setting"):
		_settings_manager.set_setting("session", "last_active_space", space_id, true)
	var f := FileAccess.open(SESSION_FILE, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify({"last_active_space": space_id}))
		f.close()

func set_module_library(library: ModuleLibrary) -> void:
	_module_library = library

func get_module_library() -> ModuleLibrary:
	return _module_library

func set_cache_sync(cache_sync: Node) -> void:
	_cache_sync = cache_sync

func get_cache_sync() -> Node:
	return _cache_sync

func set_semantic_cache(semantic_cache: Node) -> void:
	_semantic_cache = semantic_cache

func get_semantic_cache() -> Node:
	return _semantic_cache

func _get_or_find_module_library() -> ModuleLibrary:
	if _module_library and is_instance_valid(_module_library):
		return _module_library
	if _space_viewport and is_instance_valid(_space_viewport):
		if _space_viewport.get("module_library") and _space_viewport.module_library is ModuleLibrary:
			_module_library = _space_viewport.module_library as ModuleLibrary
			return _module_library
		var found = _space_viewport.find_child("ModuleLibrary", true, false)
		if found is ModuleLibrary:
			_module_library = found as ModuleLibrary
			return _module_library
	if _world_root and is_instance_valid(_world_root):
		var parent = _world_root.get_parent()
		if parent and is_instance_valid(parent):
			var found = parent.find_child("ModuleLibrary", true, false)
			if found is ModuleLibrary:
				_module_library = found as ModuleLibrary
				return _module_library
	return null

func _get_or_find_cache_sync() -> Node:
	if _cache_sync and is_instance_valid(_cache_sync):
		return _cache_sync
	if _space_viewport and is_instance_valid(_space_viewport):
		if _space_viewport.get("cache_sync") and _space_viewport.cache_sync is Node:
			_cache_sync = _space_viewport.cache_sync as Node
			return _cache_sync
		var found = _space_viewport.find_child("CacheSync", true, false)
		if found:
			_cache_sync = found
			return _cache_sync
	return null

func _get_or_find_semantic_cache() -> Node:
	if _semantic_cache and is_instance_valid(_semantic_cache):
		return _semantic_cache
	if _space_viewport and is_instance_valid(_space_viewport):
		if _space_viewport.get("semantic_cache") and _space_viewport.semantic_cache is Node:
			_semantic_cache = _space_viewport.semantic_cache as Node
			return _semantic_cache
		var found = _space_viewport.find_child("SemanticCache", true, false)
		if found:
			_semantic_cache = found
			return _semantic_cache
	return null

func _ensure_directory_exists(dir_path: String) -> void:
	if not DirAccess.dir_exists_absolute(dir_path):
		var err := DirAccess.make_dir_recursive_absolute(dir_path)
		if err != OK:
			push_error("[SpaceManager] Failed to create directory: %s" % dir_path)

func _ensure_default_spaces_exist() -> void:
	# Гарантируем наличие 4 базовых пространств-шаблонов UniCORE:
	# Default Space, Cyber Void, Clean Slate, Tool Studio
	if not has_space(DEFAULT_SPACE_ID):
		_create_template_space_file(DEFAULT_SPACE_ID, "Default Space", "default")
	if not has_space("space_cyber_void"):
		_create_template_space_file("space_cyber_void", "Cyber Void", "cyber_void")
	if not has_space("space_clean_slate"):
		_create_template_space_file("space_clean_slate", "Clean Slate", "clean_slate")
	if not has_space("space_tools") and not has_space("space_tool_studio"):
		_create_template_space_file("space_tools", "Tool Studio", "tool_studio")

func list_spaces() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var dir := DirAccess.open(SPACES_DIR)
	if not dir:
		return result

	dir.list_dir_begin()
	var file_name = dir.get_next()
	while not file_name.is_empty():
		if not dir.current_is_dir() and file_name.ends_with(".json"):
			var file_path = "%s/%s" % [SPACES_DIR, file_name]
			var space_info = _read_space_header(file_path)
			if not space_info.is_empty():
				result.append(space_info)
		file_name = dir.get_next()
	dir.list_dir_end()

	# Сортируем: сначала самые свежие по updated_at
	result.sort_custom(func(a, b): return a.get("updated_at", "") > b.get("updated_at", ""))
	return result

func _read_space_header(file_path: String) -> Dictionary:
	var file := FileAccess.open(file_path, FileAccess.READ)
	if not file:
		return {}

	var text := file.get_as_text()
	file.close()

	var json := JSON.new()
	if json.parse(text) != OK:
		return {}

	var data = json.get_data()
	if data is Dictionary:
		var raw_dict: Dictionary = data as Dictionary
		var modules_list: Array = raw_dict.get("modules", raw_dict.get("active_modules", []))
		var sp_id: String = str(raw_dict.get("space_id", raw_dict.get("id", file_path.get_file().trim_suffix(".json"))))
		return {
			"space_id": sp_id,
			"id": sp_id,
			"name": str(raw_dict.get("name", "Unnamed Space")),
			"description": str(raw_dict.get("description", "")),
			"template": str(raw_dict.get("template", "custom")),
			"created_at": str(raw_dict.get("created_at", "")),
			"updated_at": str(raw_dict.get("updated_at", "")),
			"module_count": modules_list.size(),
			"file_path": file_path
		}
	return {}

func _generate_space_id(space_name: String) -> String:
	var clean := space_name.to_lower().strip_edges()
	for ch in ["\\", "/", ":", "*", "?", "\"", "<", ">", "|", " ", "\t", "\n"]:
		clean = clean.replace(ch, "_")
	while clean.contains("__"):
		clean = clean.replace("__", "_")
	clean = clean.trim_prefix("_").trim_suffix("_")
	if clean.is_empty():
		clean = "space"
	var base_id := "space_%s_%d" % [clean, Time.get_unix_time_from_system()]
	var candidate := base_id
	var counter := 1
	while has_space(candidate):
		candidate = "%s_%d" % [base_id, counter]
		counter += 1
	return candidate

func create_new_space(space_name: String, template_type: String = "default") -> Dictionary:
	var clean_name := space_name.strip_edges()
	if clean_name.is_empty():
		clean_name = "New Space"

	var id := _generate_space_id(clean_name)
	var data := _build_template_space_data(id, clean_name, template_type)

	var file_path := "%s/%s.json" % [SPACES_DIR, id]
	if _write_space_file(file_path, data):
		space_created.emit(clean_name)
		space_list_updated.emit(list_spaces())
		load_space(id)
		return data
	else:
		space_error.emit("Не удалось создать пространство: %s" % clean_name)
		return {}

func save_current_space() -> bool:
	return save_space_as(current_space_name)

func save_space_as(new_name: String) -> bool:
	if not _module_manager:
		return false

	var space_name := new_name.strip_edges()
	if space_name.is_empty():
		space_name = current_space_name

	var id := current_space_id
	var is_clone := (space_name != current_space_name)
	if is_clone:
		id = _generate_space_id(space_name)

	var camera_data := _gather_camera_data()
	var modules_data := _gather_modules_data()
	var environment_data := _gather_environment_data()
	var now := Time.get_datetime_string_from_system()

	var data: Dictionary = {
		"space_id": id,
		"id": id,
		"name": space_name,
		"description": "Пользовательское Пространство UniCORE",
		"template": current_space_data.get("template", "custom"),
		"created_at": now if is_clone else current_space_data.get("created_at", now),
		"updated_at": now,
		"camera": camera_data,
		"environment": environment_data,
		"modules": modules_data,
		"active_modules": modules_data
	}

	var file_path := "%s/%s.json" % [SPACES_DIR, id]
	if _write_space_file(file_path, data):
		current_space_id = id
		current_space_name = space_name
		current_space_data = data
		_persist_last_space(current_space_id)
		space_saved.emit(space_name, file_path)
		space_list_updated.emit(list_spaces())
		if _event_bus:
			_event_bus.emit("space_saved", {"id": id, "name": space_name})
		print("[SpaceManager] Space '%s' successfully saved to: %s" % [space_name, file_path])
		return true

	space_error.emit("Ошибка при сохранении пространства '%s'" % space_name)
	return false

## Сериализация текущего состояния Пространства в словарь (снимок)
func serialize() -> Dictionary:
	var camera_data := _gather_camera_data()
	var modules_data := _gather_modules_data() if _module_manager else []
	var environment_data := _gather_environment_data()
	var now := Time.get_datetime_string_from_system()

	var data: Dictionary = {
		"space_id": current_space_id,
		"id": current_space_id,
		"name": current_space_name,
		"description": current_space_data.get("description", "Пользовательское Пространство UniCORE"),
		"template": current_space_data.get("template", "custom"),
		"created_at": current_space_data.get("created_at", now),
		"updated_at": now,
		"camera": camera_data,
		"environment": environment_data,
		"modules": modules_data,
		"active_modules": modules_data
	}
	return data

## Сериализация текущего состояния Пространства в виде манифеста (канонический контракт)
func serialize_space() -> Dictionary:
	return serialize()

func clone_space(source_space_id: String, new_name: String = "") -> Dictionary:
	var file_path := "%s/%s.json" % [SPACES_DIR, source_space_id]
	if not FileAccess.file_exists(file_path):
		space_error.emit("Исходное пространство для клонирования не найдено: %s" % source_space_id)
		return {}

	var file := FileAccess.open(file_path, FileAccess.READ)
	if not file:
		space_error.emit("Не удалось прочитать исходное пространство: %s" % source_space_id)
		return {}

	var text := file.get_as_text()
	file.close()

	var json := JSON.new()
	if json.parse(text) != OK or not (json.get_data() is Dictionary):
		space_error.emit("Неверный формат исходного пространства.")
		return {}

	var src_data: Dictionary = json.get_data().duplicate(true)
	var final_name := new_name.strip_edges()
	if final_name.is_empty():
		final_name = "%s (Clone)" % src_data.get("name", "Space")

	var new_id := _generate_space_id(final_name)
	var now := Time.get_datetime_string_from_system()

	src_data["id"] = new_id
	src_data["name"] = final_name
	src_data["created_at"] = now
	src_data["updated_at"] = now

	var new_file_path := "%s/%s.json" % [SPACES_DIR, new_id]
	if _write_space_file(new_file_path, src_data):
		space_created.emit(final_name)
		space_list_updated.emit(list_spaces())
		if _event_bus:
			_event_bus.emit("space_cloned", {"source_id": source_space_id, "id": new_id, "name": final_name})
		return src_data

	space_error.emit("Не удалось сохранить клон пространства: %s" % final_name)
	return {}

func rename_space(space_id: String, new_name: String) -> bool:
	var clean_name := new_name.strip_edges()
	if clean_name.is_empty():
		space_error.emit("Имя пространства не может быть пустым.")
		return false

	var file_path := "%s/%s.json" % [SPACES_DIR, space_id]
	if not FileAccess.file_exists(file_path):
		space_error.emit("Пространство для переименования не найдено: %s" % space_id)
		return false

	var file := FileAccess.open(file_path, FileAccess.READ)
	if not file:
		space_error.emit("Не удалось прочитать файл пространства: %s" % space_id)
		return false

	var text := file.get_as_text()
	file.close()

	var json := JSON.new()
	if json.parse(text) != OK or not (json.get_data() is Dictionary):
		space_error.emit("Неверный формат файла пространства: %s" % space_id)
		return false

	var data: Dictionary = json.get_data()
	data["name"] = clean_name
	data["updated_at"] = Time.get_datetime_string_from_system()

	if _write_space_file(file_path, data):
		if current_space_id == space_id:
			current_space_name = clean_name
			current_space_data = data
		space_renamed.emit(space_id, clean_name)
		space_saved.emit(clean_name, file_path)
		space_list_updated.emit(list_spaces())
		if _event_bus:
			_event_bus.emit("space_renamed", {"id": space_id, "name": clean_name})
		return true

	space_error.emit("Не удалось записать обновленное имя пространства.")
	return false

func get_space_manifest() -> Array[Dictionary]:
	return list_spaces()

func get_space_data(space_id: String) -> Dictionary:
	var file_path := "%s/%s.json" % [SPACES_DIR, space_id]
	if not FileAccess.file_exists(file_path):
		return {}
	var file := FileAccess.open(file_path, FileAccess.READ)
	if not file:
		return {}
	var text := file.get_as_text()
	file.close()
	var json := JSON.new()
	if json.parse(text) != OK:
		return {}
	var data = json.get_data()
	return data if data is Dictionary else {}

func get_template_definitions() -> Dictionary:
	return {
		TEMPLATE_DEFAULT_STUDIO: {
			"key": TEMPLATE_DEFAULT_STUDIO,
			"name": "Default Studio",
			"description": "Стандартная Студия: Пол + Локомоция",
			"modules": ["builtin_ground_plane", "builtin_avatar_locomotion"],
			"environment": {"bg_color": [0.96, 0.96, 0.98, 1.0], "ambient_energy": 0.8}
		},
		TEMPLATE_CYBER_VOID: {
			"key": TEMPLATE_CYBER_VOID,
			"name": "Cyber Void",
			"description": "Кибер-Пустота: Темная неоновая среда",
			"modules": ["builtin_ground_plane", "builtin_avatar_locomotion"],
			"environment": {"bg_color": [0.02, 0.04, 0.08, 1.0], "ambient_energy": 0.35}
		},
		TEMPLATE_CLEAN_SLATE: {
			"key": TEMPLATE_CLEAN_SLATE,
			"name": "Clean Slate",
			"description": "Чистый Холст: Свободный полет в пустоте (без пола)",
			"modules": ["builtin_avatar_locomotion"],
			"environment": {"bg_color": [0.04, 0.06, 0.12, 1.0], "ambient_energy": 0.5}
		},
		TEMPLATE_TOOL_PLAYGROUND: {
			"key": TEMPLATE_TOOL_PLAYGROUND,
			"name": "Tool Playground",
			"description": "Песочница Инструментов: Спавнер 3D-кубов",
			"modules": ["builtin_ground_plane", "builtin_avatar_locomotion", "cube_spawner_tool"],
			"environment": {"bg_color": [0.15, 0.18, 0.22, 1.0], "ambient_energy": 0.9}
		}
	}

func load_space(space_id: String) -> bool:
	var file_path := "%s/%s.json" % [SPACES_DIR, space_id]
	if not FileAccess.file_exists(file_path):
		space_error.emit("Файл пространства не найден: %s" % space_id)
		return false

	var file := FileAccess.open(file_path, FileAccess.READ)
	if not file:
		space_error.emit("Не удалось прочитать файл: %s" % file_path)
		return false

	var text := file.get_as_text()
	file.close()

	var json := JSON.new()
	if json.parse(text) != OK:
		space_error.emit("Ошибка парсинга JSON пространства: %s" % json.get_error_message())
		return false

	var data = json.get_data()
	if not (data is Dictionary):
		space_error.emit("Неверный формат данных пространства.")
		return false

	return apply_space_data(data)

## Полная и чистая выгрузка текущего пространства:
## Корректно освобождает все активные модули, узлы окружения, якоря камеры и висячие узлы без утечек памяти.
func unload_current_space() -> void:
	# 1. Выгрузка всех активных модулей через ModuleManager
	if _module_manager:
		if _module_manager.has_method("unload_all_modules"):
			_module_manager.unload_all_modules()
		else:
			var current_mod_ids := _module_manager.get_active_module_ids().duplicate()
			for mod_id in current_mod_ids:
				_module_manager.unload_module(mod_id)

	# 2. Очистка и освобождение любых оставшихся узлов в world_root (окружение, свет, якоря камер, висячие ноды)
	if _world_root:
		for child in _world_root.get_children():
			if is_instance_valid(child):
				if _event_bus and _event_bus.has_method("unsubscribe_all_for_target"):
					_event_bus.unsubscribe_all_for_target(child)
				if child.has_method("cleanup"):
					child.cleanup()
				if is_instance_valid(child):
					child.free()

	# 3. Очистка невалидных подписчиков в EventBus
	if _event_bus and _event_bus.has_method("cleanup_invalid_listeners"):
		_event_bus.cleanup_invalid_listeners()

func apply_space_data(data: Dictionary) -> bool:
	if not _module_manager:
		return false

	current_space_id = str(data.get("space_id", data.get("id", "space_unknown")))
	current_space_name = str(data.get("name", "Unnamed Space"))
	current_space_data = data

	_persist_last_space(current_space_id)

	print("[SpaceManager] Applying space: '%s' (ID: %s)" % [current_space_name, current_space_id])

	# 1. Полная и чистая выгрузка текущего пространства (модули, узлы, окружение, якоря)
	unload_current_space()

	# 2. Восстановление модулей из конфигурации пространства
	var modules: Array = data.get("modules", data.get("active_modules", []))
	for mod_info in modules:
		if not (mod_info is Dictionary):
			continue

		var mod_dict: Dictionary = mod_info as Dictionary
		var mod_id: String = str(mod_dict.get("id", "")).strip_edges()
		if mod_id.is_empty():
			continue

		var is_builtin: bool = bool(mod_dict.get("is_builtin", false)) or mod_id.begins_with("builtin_") or FileAccess.file_exists("res://modules/builtin/%s.gd" % mod_id)

		var params: Dictionary = {}
		if mod_dict.has("params") and mod_dict["params"] is Dictionary:
			params = (mod_dict["params"] as Dictionary).duplicate(true)
		elif mod_dict.has("state") and mod_dict["state"] is Dictionary:
			params = (mod_dict["state"] as Dictionary).duplicate(true)

		var enabled: bool = true
		if params.has("enabled"):
			enabled = bool(params["enabled"])
		elif mod_dict.has("enabled"):
			enabled = bool(mod_dict["enabled"])

		var mod_transform := Transform3D.IDENTITY
		if mod_dict.has("transform"):
			var raw_t = mod_dict["transform"]
			if raw_t is Transform3D:
				mod_transform = raw_t as Transform3D
			elif raw_t is Dictionary:
				mod_transform = _parse_transform_from_dict(raw_t as Dictionary)
			elif raw_t is Array:
				mod_transform = _parse_transform_from_array(raw_t as Array)
			elif raw_t is String:
				mod_transform = _parse_transform_from_string(raw_t as String)

		var loaded := false
		if is_builtin:
			loaded = _load_builtin_module(mod_id)

		if not loaded:
			# Запрашиваем исходник модуля из ModuleLibrary по module_id.
			# Если модуля нет локально — запрос в CacheSync / Реестр.
			var source_code := _resolve_module_source(mod_id)
			if not source_code.strip_edges().is_empty():
				_module_manager.load_module_from_source(mod_id, source_code)
				loaded = true
			elif mod_dict.has("source_code") and not str(mod_dict["source_code"]).strip_edges().is_empty():
				# Фоллбек обратной совместимости для старых JSON-файлов пространств
				var legacy_code: String = str(mod_dict["source_code"])
				_module_manager.load_module_from_source(mod_id, legacy_code)
				loaded = true
			else:
				push_warning("[SpaceManager] Module '%s' source not found in ModuleLibrary, CacheSync, or Registry" % mod_id)

		# Применяем transform и params к инстанциированному модулю
		var instance = _module_manager.get_module(mod_id)
		if instance and is_instance_valid(instance):
			# 1. Применяем Transform3D
			if instance is Node3D and mod_dict.has("transform"):
				instance.transform = mod_transform

			# 2. Применяем параметры состояния
			if instance.has_method("set_params"):
				instance.set_params(params)
			elif instance.has_method("set_state"):
				if params.has("state") and params["state"] is Dictionary:
					instance.set_state(params["state"] as Dictionary)
				else:
					instance.set_state(params)

			# 3. Применяем состояние enabled/disabled
			if not enabled:
				instance.process_mode = Node.PROCESS_MODE_DISABLED
				if instance is Node3D or instance is CanvasItem:
					instance.hide()
			else:
				instance.process_mode = Node.PROCESS_MODE_INHERIT
				if instance is Node3D or instance is CanvasItem:
					instance.show()

			if _event_bus and _event_bus.has_method("emit"):
				_event_bus.emit("module_toggled", {"id": mod_id, "enabled": enabled})

	# 3. Восстановление позиции и ориентации камеры
	if data.has("camera"):
		_restore_camera_data(data["camera"])

	# 4. Восстановление параметров окружения (WorldEnvironment)
	if data.has("environment"):
		_restore_environment_data(data["environment"])

	space_loaded.emit(data)
	if _event_bus:
		_event_bus.emit("space_loaded", {"id": current_space_id, "name": current_space_name})

	print("[SpaceManager] Space '%s' loaded. Active modules: %s" % [current_space_name, str(_module_manager.get_active_module_ids())])
	return true

func delete_space(space_id: String) -> bool:
	var file_path := "%s/%s.json" % [SPACES_DIR, space_id]
	if not FileAccess.file_exists(file_path):
		return false

	var err := DirAccess.remove_absolute(file_path)
	if err != OK:
		space_error.emit("Не удалось удалить файл пространства: %s" % space_id)
		return false

	space_deleted.emit(space_id)
	var remaining := list_spaces()
	space_list_updated.emit(remaining)

	# Если удалили текущее пространство, загружаем первое доступное или создаем дефолтное
	if current_space_id == space_id:
		if not remaining.is_empty():
			load_space(remaining[0]["id"])
		else:
			create_new_space("Default Studio", "default")
	else:
		var last_saved := ""
		if _settings_manager and _settings_manager.has_method("get_setting"):
			last_saved = _settings_manager.get_setting("session", "last_active_space", "")
		if last_saved == space_id:
			_persist_last_space(current_space_id)

	print("[SpaceManager] Space '%s' deleted." % space_id)
	return true

func _load_builtin_module(mod_id: String) -> bool:
	var path := ""
	if mod_id == "builtin_ground_plane":
		path = "res://modules/builtin/ground_plane.gd"
	elif mod_id == "builtin_avatar_locomotion":
		path = "res://modules/builtin/avatar_locomotion.gd"
	elif mod_id == "cube_spawner_tool":
		path = "res://modules/cube_spawner_tool.gd"
	elif FileAccess.file_exists("res://modules/builtin/%s.gd" % mod_id):
		path = "res://modules/builtin/%s.gd" % mod_id
	elif FileAccess.file_exists("res://modules/%s.gd" % mod_id):
		path = "res://modules/%s.gd" % mod_id

	if path.is_empty():
		push_error("[SpaceManager] Unknown built-in module ID: %s" % mod_id)
		return false

	var script = load(path)
	if script:
		if _module_manager and _module_manager.has_method("load_module_from_script"):
			var inst = _module_manager.load_module_from_script(mod_id, script)
			return inst != null
		elif not script.source_code.is_empty():
			var inst = _module_manager.load_module_from_source(mod_id, script.source_code)
			return inst != null

	var f := FileAccess.open(path, FileAccess.READ)
	if f:
		var src := f.get_as_text()
		f.close()
		if not src.is_empty():
			var inst = _module_manager.load_module_from_source(mod_id, src)
			return inst != null

	push_error("[SpaceManager] Failed to read source for module '%s' at: %s" % [mod_id, path])
	return false

func _gather_camera_data() -> Dictionary:
	var locomotion = _module_manager.get_module("builtin_avatar_locomotion") if _module_manager else null
	if locomotion and is_instance_valid(locomotion):
		var pos := [0.0, 1.8, 5.0]
		var rot := [0.0, 0.0, 0.0]
		var pitch: float = 0.0
		var yaw: float = 0.0
		if locomotion.get("yaw_node") and is_instance_valid(locomotion.yaw_node):
			var yn: Node3D = locomotion.yaw_node
			pos = [yn.global_position.x, yn.global_position.y, yn.global_position.z]
			yaw = yn.rotation.y
			rot[1] = yaw
		if locomotion.get("pitch_node") and is_instance_valid(locomotion.pitch_node):
			pitch = locomotion.pitch_node.rotation.x
			rot[0] = pitch
		return {
			"position": pos,
			"rotation": rot,
			"pitch": pitch,
			"yaw": yaw
		}

	var anchor := _get_camera_anchor()
	if anchor and is_instance_valid(anchor):
		return {
			"position": [anchor.global_position.x, anchor.global_position.y, anchor.global_position.z],
			"rotation": [anchor.rotation.x, anchor.rotation.y, anchor.rotation.z],
			"pitch": anchor.rotation.x,
			"yaw": anchor.rotation.y
		}

	var cam := _get_active_camera()
	if cam and is_instance_valid(cam):
		return {
			"position": [cam.global_position.x, cam.global_position.y, cam.global_position.z],
			"rotation": [cam.rotation.x, cam.rotation.y, cam.rotation.z],
			"pitch": cam.rotation.x,
			"yaw": cam.rotation.y
		}
	return {
		"position": [0.0, 1.8, 5.0],
		"rotation": [0.0, 0.0, 0.0],
		"pitch": 0.0,
		"yaw": 0.0
	}

func _get_camera_anchor() -> Node3D:
	if _world_root and _world_root.is_inside_tree():
		var anchor = _world_root.get_node_or_null("CameraAnchor")
		if anchor and is_instance_valid(anchor) and anchor is Node3D and anchor.is_inside_tree():
			return anchor
		for child in _world_root.get_children():
			if is_instance_valid(child) and child.is_in_group("camera_anchors") and child is Node3D and child.is_inside_tree():
				return child
	return null

func _get_active_camera() -> Camera3D:
	if _space_viewport and _space_viewport.get_viewport():
		var cam := _space_viewport.get_viewport().get_camera_3d()
		if cam and is_instance_valid(cam):
			return cam
	if _space_viewport:
		var cam_child = _space_viewport.find_child("AvatarCamera", true, false)
		if cam_child is Camera3D and is_instance_valid(cam_child):
			return cam_child
	if _world_root:
		for child in _world_root.get_children():
			if child is Camera3D and is_instance_valid(child):
				return child
			var child_cam = child.find_child("Camera3D", true, false)
			if child_cam is Camera3D and is_instance_valid(child_cam):
				return child_cam
	return null

func _restore_camera_data(cam_data: Dictionary) -> void:
	if cam_data.is_empty():
		return

	var pos_arr: Array = cam_data.get("position", [0.0, 1.8, 5.0])
	var rot_arr: Array = cam_data.get("rotation", [0.0, 0.0, 0.0])

	var pitch: float = 0.0
	var yaw: float = 0.0
	var roll: float = 0.0

	if rot_arr.size() >= 2:
		pitch = float(rot_arr[0])
		yaw = float(rot_arr[1])
	if rot_arr.size() >= 3:
		roll = float(rot_arr[2])

	if cam_data.has("pitch"):
		pitch = float(cam_data["pitch"])
	if cam_data.has("yaw"):
		yaw = float(cam_data["yaw"])

	var locomotion = _module_manager.get_module("builtin_avatar_locomotion") if _module_manager else null
	if locomotion and is_instance_valid(locomotion):
		if pos_arr.size() >= 3 and locomotion.get("yaw_node") and is_instance_valid(locomotion.yaw_node):
			locomotion.yaw_node.global_position = Vector3(float(pos_arr[0]), float(pos_arr[1]), float(pos_arr[2]))
		if locomotion.get("yaw_node") and is_instance_valid(locomotion.yaw_node):
			locomotion.yaw_node.rotation.y = yaw
		if locomotion.get("pitch_node") and is_instance_valid(locomotion.pitch_node):
			locomotion.pitch_node.rotation.x = pitch
		return

	var anchor := _get_camera_anchor()
	if anchor and is_instance_valid(anchor):
		if pos_arr.size() >= 3:
			anchor.global_position = Vector3(float(pos_arr[0]), float(pos_arr[1]), float(pos_arr[2]))
		anchor.rotation = Vector3(pitch, yaw, roll)
		return

	var cam := _get_active_camera()
	if cam and is_instance_valid(cam) and cam.is_inside_tree():
		if pos_arr.size() >= 3:
			cam.global_position = Vector3(float(pos_arr[0]), float(pos_arr[1]), float(pos_arr[2]))
		cam.rotation = Vector3(pitch, yaw, roll)

func _get_world_environment_node() -> WorldEnvironment:
	if _space_viewport:
		var env_node: WorldEnvironment = _space_viewport.get_node_or_null("WorldEnvironment")
		if env_node and is_instance_valid(env_node):
			return env_node
		var found = _space_viewport.find_child("WorldEnvironment", true, false)
		if found is WorldEnvironment and is_instance_valid(found):
			return found
	if _world_root:
		var env_node: WorldEnvironment = _world_root.get_node_or_null("WorldEnvironment")
		if env_node and is_instance_valid(env_node):
			return env_node
		var found = _world_root.find_child("WorldEnvironment", true, false)
		if found is WorldEnvironment and is_instance_valid(found):
			return found
	return null

func _gather_environment_data() -> Dictionary:
	var env_node := _get_world_environment_node()
	if env_node and env_node.environment:
		var c: Color = env_node.environment.background_color
		return {
			"bg_color": [c.r, c.g, c.b, c.a],
			"ambient_energy": env_node.environment.ambient_light_energy
		}
	return {"bg_color": [0.96, 0.96, 0.98, 1.0], "ambient_energy": 0.8}

func _restore_environment_data(env_dict: Dictionary) -> void:
	if env_dict.is_empty():
		return

	var env_node := _get_world_environment_node()
	if env_node and env_node.environment:
		var bg_val = env_dict.get("bg_color", [0.96, 0.96, 0.98, 1.0])
		if bg_val is Array:
			if bg_val.size() >= 4:
				env_node.environment.background_color = Color(float(bg_val[0]), float(bg_val[1]), float(bg_val[2]), float(bg_val[3]))
			elif bg_val.size() == 3:
				env_node.environment.background_color = Color(float(bg_val[0]), float(bg_val[1]), float(bg_val[2]), 1.0)
		elif bg_val is String:
			env_node.environment.background_color = Color.from_string(bg_val, Color(0.96, 0.96, 0.98, 1.0))
		elif bg_val is Color:
			env_node.environment.background_color = bg_val

		if env_dict.has("ambient_energy"):
			env_node.environment.ambient_light_energy = float(env_dict["ambient_energy"])

func _serialize_transform(t: Transform3D) -> Dictionary:
	var bx: Array[float] = [t.basis.x.x, t.basis.x.y, t.basis.x.z]
	var by: Array[float] = [t.basis.y.x, t.basis.y.y, t.basis.y.z]
	var bz: Array[float] = [t.basis.z.x, t.basis.z.y, t.basis.z.z]
	var o: Array[float] = [t.origin.x, t.origin.y, t.origin.z]
	return {
		"origin": o,
		"basis": [bx, by, bz]
	}

func _parse_transform_from_dict(d: Dictionary) -> Transform3D:
	var orig := Vector3.ZERO
	if d.has("origin") and d["origin"] is Array:
		var o_arr: Array = d["origin"] as Array
		if o_arr.size() >= 3:
			orig = Vector3(float(o_arr[0]), float(o_arr[1]), float(o_arr[2]))

	var bas := Basis.IDENTITY
	if d.has("basis") and d["basis"] is Array:
		var b_arr: Array = d["basis"] as Array
		if b_arr.size() >= 3 and b_arr[0] is Array and b_arr[1] is Array and b_arr[2] is Array:
			var bx: Array = b_arr[0] as Array
			var by: Array = b_arr[1] as Array
			var bz: Array = b_arr[2] as Array
			if bx.size() >= 3 and by.size() >= 3 and bz.size() >= 3:
				bas = Basis(
					Vector3(float(bx[0]), float(bx[1]), float(bx[2])),
					Vector3(float(by[0]), float(by[1]), float(by[2])),
					Vector3(float(bz[0]), float(bz[1]), float(bz[2]))
				)

	return Transform3D(bas, orig)

func _parse_transform_from_array(arr: Array) -> Transform3D:
	if arr.size() == 12:
		var b := Basis(
			Vector3(float(arr[0]), float(arr[1]), float(arr[2])),
			Vector3(float(arr[3]), float(arr[4]), float(arr[5])),
			Vector3(float(arr[6]), float(arr[7]), float(arr[8]))
		)
		var o := Vector3(float(arr[9]), float(arr[10]), float(arr[11]))
		return Transform3D(b, o)
	return Transform3D.IDENTITY

func _parse_transform_from_string(s: String) -> Transform3D:
	var parsed = str_to_var(s)
	if parsed is Transform3D:
		return parsed as Transform3D
	return Transform3D.IDENTITY

func _resolve_module_source(mod_id: String) -> String:
	# 1. Запрос исходника из ModuleLibrary по module_id
	var lib := _get_or_find_module_library()
	if lib and is_instance_valid(lib):
		var src := lib.get_module_source(mod_id)
		if not src.strip_edges().is_empty():
			return src

	# 2. Если модуль не найден в каталоге ModuleLibrary:
	# Проверяем локальные пути на диске (res://modules/, res://modules/builtin/, user://modules/)
	var disk_paths: Array[String] = [
		"res://modules/%s.gd" % mod_id,
		"res://modules/builtin/%s.gd" % mod_id,
		"user://modules/%s.gd" % mod_id
	]
	for dp in disk_paths:
		if FileAccess.file_exists(dp):
			var f := FileAccess.open(dp, FileAccess.READ)
			if f:
				var src := f.get_as_text()
				f.close()
				if not src.strip_edges().is_empty():
					if lib and is_instance_valid(lib) and not lib.has_module(mod_id):
						lib.scan_library()
					return src

	# 3. Запрос в локальный семантический кэш SemanticCache
	var sem_cache := _get_or_find_semantic_cache()
	if sem_cache and is_instance_valid(sem_cache) and sem_cache.has_method("get_by_id"):
		var cached_entry: Dictionary = sem_cache.get_by_id(mod_id)
		if not cached_entry.is_empty():
			var src := str(cached_entry.get("source_code", ""))
			if not src.strip_edges().is_empty():
				if lib and is_instance_valid(lib):
					lib.import_module_from_source(mod_id, src)
				return src

	# 4. Запрос в CacheSync (сетевой P2P-поиск в рое пиров)
	var cs := _get_or_find_cache_sync()
	if cs and is_instance_valid(cs) and cs.has_method("query_network") and cs.has_method("has_connected_peers"):
		if cs.has_connected_peers():
			var results: Array[Dictionary] = cs.query_network(mod_id, 2.0)
			for r in results:
				var entry: Dictionary = r.get("module_data", r)
				if entry.get("id", "") == mod_id or entry.get("name", "") == mod_id:
					var src := str(entry.get("source_code", ""))
					if not src.strip_edges().is_empty():
						if lib and is_instance_valid(lib):
							lib.import_module_from_source(mod_id, src)
						return src

	# 5. Запрос в Реестр шаблонов ModuleRegistryClient
	for tmpl in ModuleRegistryClient.get_all_templates():
		if str(tmpl.get("id", "")).strip_edges() == mod_id:
			var src := ModuleRegistryClient.get_module_source(tmpl)
			if not src.strip_edges().is_empty():
				if lib and is_instance_valid(lib):
					lib.import_module_from_source(mod_id, src)
				return src

	return ""

## Собирает манифест активных модулей пространства.
## Полный запрет на сериализацию исходного кода .gd внутрь JSON-файлов пространств.
## В манифест пишутся строго: id, version, transform (Transform3D), params (Dictionary).
func _gather_modules_data() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if not _module_manager:
		return result

	var lib := _get_or_find_module_library()

	for mod_id in _module_manager.get_active_module_ids():
		var inst := _module_manager.get_module(mod_id)
		var is_builtin: bool = mod_id.begins_with("builtin_") or mod_id == "cube_spawner_tool" or FileAccess.file_exists("res://modules/builtin/%s.gd" % mod_id)
		var is_enabled: bool = true
		var mod_transform := Transform3D.IDENTITY
		var params: Dictionary = {}
		var version: String = "1.0.0"

		if inst and is_instance_valid(inst):
			is_enabled = (inst.process_mode != Node.PROCESS_MODE_DISABLED)

			# 1. Извлечение Transform3D для Node3D
			if inst is Node3D:
				mod_transform = (inst as Node3D).transform

			# 2. Параметры состояния
			if inst.has_method("get_state"):
				var st = inst.get_state()
				if st is Dictionary:
					params = (st as Dictionary).duplicate(true)
			elif inst.has_method("get_params"):
				var p = inst.get_params()
				if p is Dictionary:
					params = (p as Dictionary).duplicate(true)

			# 3. Версия модуля
			if inst.has_method("get_module_version"):
				version = str(inst.get_module_version())
			elif lib and is_instance_valid(lib):
				var info := lib.get_module_info(mod_id)
				if info.has("version"):
					version = str(info["version"])

		params["enabled"] = is_enabled

		var mod_manifest: Dictionary = {
			"id": mod_id,
			"version": version,
			"transform": _serialize_transform(mod_transform),
			"params": params,
			"is_builtin": is_builtin,
			"enabled": is_enabled
		}

		result.append(mod_manifest)

	return result

func normalize_template_type(raw_type: String) -> String:
	var norm := raw_type.to_lower().strip_edges().replace(" ", "_").replace("-", "_")
	match norm:
		"default", "default_studio", "standard", "standard_studio", "studio":
			return TEMPLATE_DEFAULT_STUDIO
		"cyber_void", "cyber", "cybervoid", "void":
			return TEMPLATE_CYBER_VOID
		"clean_slate", "clean", "cleanslate", "slate":
			return TEMPLATE_CLEAN_SLATE
		"tool_studio", "tool_playground", "playground", "tools", "toolstudio":
			return TEMPLATE_TOOL_PLAYGROUND
		_:
			return TEMPLATE_DEFAULT_STUDIO

func _build_template_space_data(id: String, space_name: String, template_type: String) -> Dictionary:
	var now := Time.get_datetime_string_from_system()
	var modules: Array[Dictionary] = []
	var env_settings := {"bg_color": [0.96, 0.96, 0.98, 1.0], "ambient_energy": 0.8}

	var norm_type := normalize_template_type(template_type)
	var def_transform := _serialize_transform(Transform3D.IDENTITY)

	match norm_type:
		TEMPLATE_DEFAULT_STUDIO:
			modules.append({"id": "builtin_ground_plane", "version": "1.0.0", "transform": def_transform, "params": {}, "is_builtin": true, "enabled": true})
			modules.append({"id": "builtin_avatar_locomotion", "version": "1.0.0", "transform": def_transform, "params": {}, "is_builtin": true, "enabled": true})
			env_settings = {"bg_color": [0.96, 0.96, 0.98, 1.0], "ambient_energy": 0.8}
		TEMPLATE_CYBER_VOID:
			modules.append({"id": "builtin_ground_plane", "version": "1.0.0", "transform": def_transform, "params": {}, "is_builtin": true, "enabled": true})
			modules.append({"id": "builtin_avatar_locomotion", "version": "1.0.0", "transform": def_transform, "params": {}, "is_builtin": true, "enabled": true})
			env_settings = {"bg_color": [0.02, 0.04, 0.08, 1.0], "ambient_energy": 0.35}
		TEMPLATE_CLEAN_SLATE:
			modules.append({"id": "builtin_avatar_locomotion", "version": "1.0.0", "transform": def_transform, "params": {}, "is_builtin": true, "enabled": true})
			env_settings = {"bg_color": [0.04, 0.06, 0.12, 1.0], "ambient_energy": 0.5}
		TEMPLATE_TOOL_PLAYGROUND:
			modules.append({"id": "builtin_ground_plane", "version": "1.0.0", "transform": def_transform, "params": {}, "is_builtin": true, "enabled": true})
			modules.append({"id": "builtin_avatar_locomotion", "version": "1.0.0", "transform": def_transform, "params": {}, "is_builtin": true, "enabled": true})
			modules.append({"id": "cube_spawner_tool", "version": "1.0.0", "transform": def_transform, "params": {}, "is_builtin": true, "enabled": true})
			env_settings = {"bg_color": [0.15, 0.18, 0.22, 1.0], "ambient_energy": 0.9}

	return {
		"space_id": id,
		"id": id,
		"name": space_name,
		"description": "Шаблон: %s" % norm_type,
		"template": norm_type,
		"created_at": now,
		"updated_at": now,
		"camera": {
			"position": [0.0, 1.8, 5.0],
			"rotation": [0.0, 0.0, 0.0],
			"pitch": 0.0,
			"yaw": 0.0
		},
		"environment": env_settings,
		"modules": modules,
		"active_modules": modules
	}

func _create_template_space_file(id: String, space_name: String, template_type: String) -> void:
	var file_path := "%s/%s.json" % [SPACES_DIR, id]
	if not FileAccess.file_exists(file_path):
		var data := _build_template_space_data(id, space_name, template_type)
		_write_space_file(file_path, data)

func _write_space_file(file_path: String, data: Dictionary) -> bool:
	_ensure_directory_exists(file_path.get_base_dir())
	var file := FileAccess.open(file_path, FileAccess.WRITE)
	if not file:
		return false
	file.store_string(JSON.stringify(data, "\t"))
	file.close()
	return true
