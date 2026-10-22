class_name ModuleGallery
extends Control

## UI Галереи Модулей UniCORE (Module Gallery)
## Реализовано в стиле "Detroit: Become Human" (Liquid Glass, CyberTheme).
## Обеспечивает просмотр, поиск, фильтрацию, сортировку, инъекцию (загрузку/выгрузку),
## дублирование, экспорт, импорт и инспекцию кода модулей Ядра.

signal module_load_requested(module_id: String)
signal module_unload_requested(module_id: String)
signal view_code_requested(module_id: String, source_code: String)
signal delete_requested(module_id: String)
signal rename_requested(module_id: String, new_id: String)
signal duplicate_requested(module_id: String, new_id: String)
signal export_requested(module_id: String, export_path: String)
signal import_requested(file_path: String)

const CyberTheme = preload("res://ui/theme/cyber_theme.gd")
const ModuleRegistryClient = preload("res://core/module_registry_client.gd")
const USER_MODULES_DIR := "user://modules"

var _module_library: Node = null
var _module_manager: Node = null

# Внутренний кэш пользовательских модулей
var _user_modules: Dictionary = {} # id -> Dictionary
var _all_modules: Dictionary = {}  # id -> Dictionary

# Текущий контекст действий диалогов
var _active_action_mod_id: String = ""

# Ссылки на ноды UI
@onready var search_edit: LineEdit = $VBoxContainer/HeaderPanel/MarginContainer/HeaderHBox/SearchEdit
@onready var clear_search_btn: Button = $VBoxContainer/HeaderPanel/MarginContainer/HeaderHBox/ClearButton
@onready var category_opt: OptionButton = $VBoxContainer/HeaderPanel/MarginContainer/HeaderHBox/CategoryOption
@onready var sort_opt: OptionButton = $VBoxContainer/HeaderPanel/MarginContainer/HeaderHBox/SortOption
@onready var refresh_btn: Button = $VBoxContainer/HeaderPanel/MarginContainer/HeaderHBox/RefreshButton

@onready var header_panel: PanelContainer = $VBoxContainer/HeaderPanel
@onready var scroll_container: ScrollContainer = $VBoxContainer/ScrollContainer
@onready var grid_container: GridContainer = $VBoxContainer/ScrollContainer/GridContainer
@onready var empty_label: Label = $VBoxContainer/EmptyLabel

@onready var footer_panel: PanelContainer = $VBoxContainer/FooterPanel
@onready var import_btn: Button = $VBoxContainer/FooterPanel/MarginContainer/FooterHBox/ImportButton
@onready var stats_label: Label = $VBoxContainer/FooterPanel/MarginContainer/FooterHBox/StatsLabel

# Диалоговые окна
var code_view_dialog: AcceptDialog
var code_view_text: TextEdit
var code_view_info_lbl: Label

var duplicate_dialog: ConfirmationDialog
var duplicate_edit: LineEdit

var rename_dialog: ConfirmationDialog
var rename_edit: LineEdit

var confirm_delete_dialog: ConfirmationDialog

var export_file_dialog: FileDialog
var import_file_dialog: FileDialog

func _ready() -> void:
	_ensure_user_dir()
	_setup_dialogs()
	_populate_dropdowns()
	_apply_styling()
	_connect_ui_signals()
	refresh_gallery()

func setup(module_library: Node, module_manager: Node = null) -> void:
	_module_library = module_library
	_module_manager = module_manager

	if _module_manager:
		if _module_manager.has_signal("module_loaded") and not _module_manager.module_loaded.is_connected(_on_manager_module_loaded):
			_module_manager.module_loaded.connect(_on_manager_module_loaded)
		if _module_manager.has_signal("module_unloaded") and not _module_manager.module_unloaded.is_connected(_on_manager_module_unloaded):
			_module_manager.module_unloaded.connect(_on_manager_module_unloaded)

	if _module_library:
		if _module_library.has_signal("modules_updated") and not _module_library.is_connected("modules_updated", Callable(self, "refresh_gallery")):
			_module_library.connect("modules_updated", Callable(self, "refresh_gallery"))
		if _module_library.has_signal("library_updated") and not _module_library.is_connected("library_updated", Callable(self, "refresh_gallery")):
			_module_library.connect("library_updated", Callable(self, "refresh_gallery"))

	refresh_gallery()

func get_module_library() -> Node:
	return _module_library

func get_module_manager() -> Node:
	return _module_manager

func _ensure_user_dir() -> void:
	if not DirAccess.dir_exists_absolute(USER_MODULES_DIR):
		DirAccess.make_dir_recursive_absolute(USER_MODULES_DIR)

func _populate_dropdowns() -> void:
	if is_instance_valid(category_opt):
		category_opt.clear()
		var categories := [
			"Все категории",
			"Инструменты (Tools)",
			"Визуальные (Visual)",
			"Физика (Physics)",
			"Камера и Ввод (Camera)",
			"Окружение (Environment)",
			"Пользовательские (User)"
		]
		for cat in categories:
			category_opt.add_item(cat)

	if is_instance_valid(sort_opt):
		sort_opt.clear()
		var sorts := [
			"По имени (A-Z)",
			"По имени (Z-A)",
			"Сначала активные",
			"По размеру"
		]
		for s in sorts:
			sort_opt.add_item(s)

func _connect_ui_signals() -> void:
	if is_instance_valid(search_edit):
		search_edit.text_changed.connect(func(_t): _on_filter_changed())
	if is_instance_valid(clear_search_btn):
		clear_search_btn.pressed.connect(func():
			search_edit.text = ""
			_on_filter_changed()
		)
	if is_instance_valid(category_opt):
		category_opt.item_selected.connect(func(_idx): _on_filter_changed())
	if is_instance_valid(sort_opt):
		sort_opt.item_selected.connect(func(_idx): _on_filter_changed())
	if is_instance_valid(refresh_btn):
		refresh_btn.pressed.connect(refresh_gallery)
	if is_instance_valid(import_btn):
		import_btn.pressed.connect(_on_import_button_pressed)

func _apply_styling() -> void:
	# Header & Footer panels
	if is_instance_valid(header_panel):
		header_panel.add_theme_stylebox_override(
			"panel",
			CyberTheme.create_glass_panel_style(CyberTheme.COLOR_GLASS_BORDER, Color(-1, -1, -1, -1), 1, 4, 2)
		)
	if is_instance_valid(footer_panel):
		footer_panel.add_theme_stylebox_override(
			"panel",
			CyberTheme.create_glass_panel_style(CyberTheme.COLOR_GLASS_BORDER, Color(-1, -1, -1, -1), 1, 4, 2)
		)

	# Search LineEdit
	if is_instance_valid(search_edit):
		search_edit.add_theme_stylebox_override("normal", CyberTheme.create_input_style(false))
		search_edit.add_theme_stylebox_override("focus", CyberTheme.create_input_style(true))
		search_edit.add_theme_color_override("font_color", CyberTheme.get_text_primary_color())
		search_edit.add_theme_color_override("placeholder_color", CyberTheme.COLOR_TEXT_MUTED)

	# Buttons
	if is_instance_valid(clear_search_btn):
		clear_search_btn.add_theme_stylebox_override("normal", CyberTheme.create_cyber_button_style(Color(0.08, 0.12, 0.2, 0.7), CyberTheme.COLOR_GLASS_BORDER, 1, 3))
	if is_instance_valid(refresh_btn):
		refresh_btn.add_theme_stylebox_override("normal", CyberTheme.create_cyber_button_style(Color(0.08, 0.12, 0.2, 0.7), CyberTheme.COLOR_CYAN_GLOW, 1, 3))
	if is_instance_valid(import_btn):
		import_btn.add_theme_stylebox_override("normal", CyberTheme.create_cyber_button_style(Color(0.05, 0.14, 0.24, 0.85), CyberTheme.COLOR_CYAN_GLOW, 1, 4, 3))
		import_btn.add_theme_color_override("font_color", CyberTheme.COLOR_CYAN_GLOW)

	if is_instance_valid(category_opt):
		category_opt.add_theme_stylebox_override("normal", CyberTheme.create_cyber_button_style(Color(0.06, 0.11, 0.2, 0.8), CyberTheme.COLOR_GLASS_BORDER, 1, 3))
	if is_instance_valid(sort_opt):
		sort_opt.add_theme_stylebox_override("normal", CyberTheme.create_cyber_button_style(Color(0.06, 0.11, 0.2, 0.8), CyberTheme.COLOR_GLASS_BORDER, 1, 3))

	if is_instance_valid(stats_label):
		stats_label.add_theme_color_override("font_color", CyberTheme.COLOR_TEXT_CYAN)

	if is_instance_valid(empty_label):
		empty_label.add_theme_color_override("font_color", CyberTheme.COLOR_TEXT_MUTED)

func _setup_dialogs() -> void:
	# 1. Code View Dialog
	code_view_dialog = AcceptDialog.new()
	code_view_dialog.title = "Просмотр кода модуля // Liquid Glass"
	code_view_dialog.ok_button_text = "Закрыть"
	code_view_dialog.initial_position = Window.WINDOW_INITIAL_POSITION_CENTER_PRIMARY_SCREEN
	code_view_dialog.size = Vector2i(720, 520)

	var cv_margin := MarginContainer.new()
	cv_margin.add_theme_constant_override("margin_left", 8)
	cv_margin.add_theme_constant_override("margin_right", 8)
	cv_margin.add_theme_constant_override("margin_top", 8)
	cv_margin.add_theme_constant_override("margin_bottom", 8)

	var cv_vbox := VBoxContainer.new()
	cv_vbox.add_theme_constant_override("separation", 8)
	cv_margin.add_child(cv_vbox)

	code_view_info_lbl = Label.new()
	code_view_info_lbl.add_theme_color_override("font_color", CyberTheme.COLOR_CYAN_GLOW)
	code_view_info_lbl.add_theme_font_size_override("font_size", 12)
	cv_vbox.add_child(code_view_info_lbl)

	code_view_text = TextEdit.new()
	code_view_text.editable = false
	code_view_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	code_view_text.custom_minimum_size = Vector2(680, 380)
	code_view_text.add_theme_stylebox_override("normal", CyberTheme.create_input_style(false))
	code_view_text.add_theme_color_override("font_color", CyberTheme.COLOR_TEXT_PRIMARY)
	cv_vbox.add_child(code_view_text)

	var copy_btn := Button.new()
	copy_btn.text = "Скопировать код в буфер обмена"
	copy_btn.add_theme_stylebox_override("normal", CyberTheme.create_cyber_button_style(Color(0.08, 0.16, 0.28, 0.8), CyberTheme.COLOR_CYAN_GLOW, 1, 3))
	copy_btn.pressed.connect(func():
		DisplayServer.clipboard_set(code_view_text.text)
	)
	cv_vbox.add_child(copy_btn)

	code_view_dialog.add_child(cv_margin)
	add_child(code_view_dialog)

	# 2. Duplicate Dialog
	duplicate_dialog = ConfirmationDialog.new()
	duplicate_dialog.title = "Дублировать модуль"
	duplicate_dialog.ok_button_text = "Дублировать"
	duplicate_dialog.cancel_button_text = "Отмена"
	duplicate_dialog.initial_position = Window.WINDOW_INITIAL_POSITION_CENTER_PRIMARY_SCREEN
	duplicate_dialog.size = Vector2i(420, 150)

	var dup_vbox := VBoxContainer.new()
	dup_vbox.add_theme_constant_override("separation", 8)
	var dup_lbl := Label.new()
	dup_lbl.text = "Введите идентификатор нового модуля:"
	dup_vbox.add_child(dup_lbl)
	duplicate_edit = LineEdit.new()
	duplicate_edit.add_theme_stylebox_override("normal", CyberTheme.create_input_style(false))
	duplicate_edit.add_theme_stylebox_override("focus", CyberTheme.create_input_style(true))
	dup_vbox.add_child(duplicate_edit)
	duplicate_dialog.add_child(dup_vbox)
	duplicate_dialog.confirmed.connect(_on_duplicate_confirmed)
	add_child(duplicate_dialog)

	# 3. Rename Dialog
	rename_dialog = ConfirmationDialog.new()
	rename_dialog.title = "Переименовать модуль"
	rename_dialog.ok_button_text = "Сохранить"
	rename_dialog.cancel_button_text = "Отмена"
	rename_dialog.initial_position = Window.WINDOW_INITIAL_POSITION_CENTER_PRIMARY_SCREEN
	rename_dialog.size = Vector2i(420, 150)

	var ren_vbox := VBoxContainer.new()
	ren_vbox.add_theme_constant_override("separation", 8)
	var ren_lbl := Label.new()
	ren_lbl.text = "Введите новый идентификатор модуля:"
	ren_vbox.add_child(ren_lbl)
	rename_edit = LineEdit.new()
	rename_edit.add_theme_stylebox_override("normal", CyberTheme.create_input_style(false))
	rename_edit.add_theme_stylebox_override("focus", CyberTheme.create_input_style(true))
	ren_vbox.add_child(rename_edit)
	rename_dialog.add_child(ren_vbox)
	rename_dialog.confirmed.connect(_on_rename_confirmed)
	add_child(rename_dialog)

	# 4. Confirm Delete Dialog
	confirm_delete_dialog = ConfirmationDialog.new()
	confirm_delete_dialog.title = "Подтверждение удаления"
	confirm_delete_dialog.ok_button_text = "Удалить"
	confirm_delete_dialog.cancel_button_text = "Отмена"
	confirm_delete_dialog.initial_position = Window.WINDOW_INITIAL_POSITION_CENTER_PRIMARY_SCREEN
	confirm_delete_dialog.size = Vector2i(380, 120)
	confirm_delete_dialog.confirmed.connect(_on_delete_confirmed)
	add_child(confirm_delete_dialog)

	# 5. Export FileDialog
	export_file_dialog = FileDialog.new()
	export_file_dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE
	export_file_dialog.access = FileDialog.ACCESS_FILESYSTEM
	export_file_dialog.filters = PackedStringArray(["*.gd ; GDScript Module (*.gd)"])
	export_file_dialog.title = "Экспорт модуля в файл"
	export_file_dialog.initial_position = Window.WINDOW_INITIAL_POSITION_CENTER_PRIMARY_SCREEN
	export_file_dialog.size = Vector2i(700, 450)
	export_file_dialog.file_selected.connect(_on_export_file_selected)
	add_child(export_file_dialog)

	# 6. Import FileDialog
	import_file_dialog = FileDialog.new()
	import_file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	import_file_dialog.access = FileDialog.ACCESS_FILESYSTEM
	import_file_dialog.filters = PackedStringArray(["*.gd ; GDScript Module (*.gd)"])
	import_file_dialog.title = "Импорт модуля GDScript"
	import_file_dialog.initial_position = Window.WINDOW_INITIAL_POSITION_CENTER_PRIMARY_SCREEN
	import_file_dialog.size = Vector2i(700, 450)
	import_file_dialog.file_selected.connect(_on_import_file_selected)
	add_child(import_file_dialog)

func _on_manager_module_loaded(_id: String, _inst: Node) -> void:
	refresh_gallery()

func _on_manager_module_unloaded(_id: String) -> void:
	refresh_gallery()

func _collect_all_modules() -> Dictionary:
	var result: Dictionary = {}

	# 1. Builtin Modules
	var builtins := [
		{
			"id": "builtin_ground_plane",
			"name": "Плоскость земли (Ground Plane)",
			"category": "environment",
			"tags": ["ground", "plane", "environment", "земля", "пол"],
			"description": "Базовая статическая плоскость окружения с координатной сеткой.",
			"source_file": "res://modules/builtin/ground_plane.gd",
			"type": "builtin",
			"is_builtin": true
		},
		{
			"id": "builtin_avatar_locomotion",
			"name": "Аватар: Управление и Камера",
			"category": "camera",
			"tags": ["avatar", "locomotion", "camera", "movement", "аватар", "камера"],
			"description": "Управление аватаром от первого лица, свободный полет, ускорение и обзор мышью.",
			"source_file": "res://modules/builtin/avatar_locomotion.gd",
			"type": "builtin",
			"is_builtin": true
		}
	]

	# Сканирование дополнительных файлов в res://modules/builtin
	if DirAccess.dir_exists_absolute("res://modules/builtin"):
		var b_dir := DirAccess.open("res://modules/builtin")
		if b_dir:
			b_dir.list_dir_begin()
			var fn := b_dir.get_next()
			while not fn.is_empty():
				if not b_dir.current_is_dir() and fn.ends_with(".gd"):
					var b_id := "builtin_" + fn.trim_suffix(".gd")
					var exists := false
					for b in builtins:
						if b["id"] == b_id or b["id"] == fn.trim_suffix(".gd"):
							exists = true
							break
					if not exists:
						builtins.append({
							"id": b_id,
							"name": "Встроенный: " + fn.trim_suffix(".gd"),
							"category": "environment",
							"tags": ["builtin"],
							"description": "Встроенный модуль UniCORE.",
							"source_file": "res://modules/builtin/" + fn,
							"type": "builtin",
							"is_builtin": true
						})
				fn = b_dir.get_next()
			b_dir.list_dir_end()

	for b in builtins:
		result[b["id"]] = b

	# 2. Registry Templates
	var templates: Array[Dictionary] = ModuleRegistryClient.get_all_templates()
	for tmpl in templates:
		var tid: String = str(tmpl.get("id", ""))
		var tname: String = str(tmpl.get("name", tid))
		var tcat: String = str(tmpl.get("category", "tools"))
		var ttags: Array = tmpl.get("tags", [])
		var tdesc: String = str(tmpl.get("description", ""))
		var tcode: String = ModuleRegistryClient.get_module_source(tmpl)
		var tfile: String = str(tmpl.get("source_file", ""))

		result[tid] = {
			"id": tid,
			"name": tname,
			"category": tcat,
			"tags": ttags,
			"description": tdesc,
			"code": tcode,
			"source_file": tfile,
			"type": "registry",
			"is_builtin": true
		}

	# 3. User Saved Modules (from user://modules/)
	if DirAccess.dir_exists_absolute(USER_MODULES_DIR):
		var u_dir := DirAccess.open(USER_MODULES_DIR)
		if u_dir:
			u_dir.list_dir_begin()
			var ufn := u_dir.get_next()
			while not ufn.is_empty():
				if not u_dir.current_is_dir() and ufn.ends_with(".gd"):
					var uid := ufn.trim_suffix(".gd")
					var u_path := "%s/%s" % [USER_MODULES_DIR, ufn]
					var f := FileAccess.open(u_path, FileAccess.READ)
					var u_code := ""
					if f:
						u_code = f.get_as_text()
						f.close()
					result[uid] = {
						"id": uid,
						"name": uid.capitalize(),
						"category": "user",
						"tags": ["user", "custom"],
						"description": "Пользовательский модуль GDScript из локального хранилища.",
						"code": u_code,
						"source_file": u_path,
						"type": "user",
						"is_builtin": false
					}
				ufn = u_dir.get_next()
			u_dir.list_dir_end()

	# 4. In-Memory User Modules
	for uid in _user_modules:
		result[uid] = _user_modules[uid]

	# 5. External ModuleLibrary (if provided)
	if _module_library:
		var lib_mods: Array = []
		if _module_library.has_method("get_all_modules"):
			lib_mods = _module_library.get_all_modules()
		elif _module_library.has_method("get_modules"):
			lib_mods = _module_library.get_modules()
		elif _module_library.has_method("get_all_templates"):
			lib_mods = _module_library.get_all_templates()
		elif _module_library.has_method("list_modules"):
			lib_mods = _module_library.list_modules()

		for m in lib_mods:
			if m is Dictionary and m.has("id"):
				var mid: String = str(m["id"])
				if result.has(mid):
					result[mid].merge(m, true)
				else:
					result[mid] = m

	# Calculate sizes and active status
	var active_ids: Array = []
	if _module_manager and _module_manager.has_method("get_active_module_ids"):
		active_ids = _module_manager.get_active_module_ids()

	for k in result:
		var item: Dictionary = result[k]
		item["is_active"] = active_ids.has(k)
		var c_str: String = item.get("code", "")
		if c_str.is_empty() and not str(item.get("source_file", "")).is_empty():
			var sf: String = item["source_file"]
			if FileAccess.file_exists(sf):
				var f2 := FileAccess.open(sf, FileAccess.READ)
				if f2:
					c_str = f2.get_as_text()
					item["code"] = c_str
					f2.close()
		item["size"] = c_str.length()

	return result

func refresh_gallery() -> void:
	_all_modules = _collect_all_modules()
	_update_stats_label()
	_render_cards()

func _update_stats_label() -> void:
	if not is_instance_valid(stats_label):
		return

	var total_count: int = _all_modules.size()
	var active_count: int = 0
	var templates_count: int = 0

	for k in _all_modules:
		var item: Dictionary = _all_modules[k]
		if bool(item.get("is_active", false)):
			active_count += 1
		if str(item.get("type", "")) == "registry" or (bool(item.get("is_builtin", false)) and not str(item.get("type", "")) == "builtin"):
			templates_count += 1

	stats_label.text = "Всего: %d | Активно: %d | Шаблонов: %d" % [total_count, active_count, templates_count]

func _on_filter_changed() -> void:
	_render_cards()

func _get_filtered_and_sorted_modules() -> Array:
	var query: String = search_edit.text.strip_edges() if is_instance_valid(search_edit) else ""
	var cat_idx: int = category_opt.selected if is_instance_valid(category_opt) else 0
	var sort_idx: int = sort_opt.selected if is_instance_valid(sort_opt) else 0

	var filtered: Array = []
	for k in _all_modules:
		var mod: Dictionary = _all_modules[k]
		if _matches_category(mod, cat_idx) and _matches_query(mod, query):
			filtered.append(mod)

	_sort_modules(filtered, sort_idx)
	return filtered

func _matches_category(mod_info: Dictionary, cat_idx: int) -> bool:
	if cat_idx <= 0:
		return true
	var cat: String = str(mod_info.get("category", "")).to_lower()
	var type_str: String = str(mod_info.get("type", "")).to_lower()
	var is_builtin: bool = bool(mod_info.get("is_builtin", false))

	match cat_idx:
		1: # Инструменты (Tools)
			return cat == "tools"
		2: # Визуальные (Visual)
			return cat == "visual" or cat == "vfx" or cat == "utilities"
		3: # Физика (Physics)
			return cat == "physics"
		4: # Камера и Ввод (Camera)
			return cat == "camera" or cat == "input"
		5: # Окружение (Environment)
			return cat == "environment" or cat == "lighting"
		6: # Пользовательские (User)
			return cat == "user" or type_str == "user" or not is_builtin
		_:
			return true

func _matches_query(mod_info: Dictionary, query: String) -> bool:
	if query.is_empty():
		return true
	var q := query.to_lower()
	if str(mod_info.get("id", "")).to_lower().contains(q):
		return true
	if str(mod_info.get("name", "")).to_lower().contains(q):
		return true
	if str(mod_info.get("description", "")).to_lower().contains(q):
		return true
	for tag in mod_info.get("tags", []):
		var t_str := str(tag).to_lower()
		if t_str.contains(q) or q.contains(t_str):
			return true
	return false

func _sort_modules(modules_list: Array, sort_idx: int) -> void:
	match sort_idx:
		0: # По имени (A-Z)
			modules_list.sort_custom(func(a, b):
				return str(a.get("name", "")).naturalnocasecmp_to(str(b.get("name", ""))) < 0
			)
		1: # По имени (Z-A)
			modules_list.sort_custom(func(a, b):
				return str(a.get("name", "")).naturalnocasecmp_to(str(b.get("name", ""))) > 0
			)
		2: # Сначала активные
			modules_list.sort_custom(func(a, b):
				var a_act: bool = bool(a.get("is_active", false))
				var b_act: bool = bool(b.get("is_active", false))
				if a_act != b_act:
					return a_act and not b_act
				return str(a.get("name", "")).naturalnocasecmp_to(str(b.get("name", ""))) < 0
			)
		3: # По размеру
			modules_list.sort_custom(func(a, b):
				var a_size: int = int(a.get("size", 0))
				var b_size: int = int(b.get("size", 0))
				if a_size != b_size:
					return a_size > b_size
				return str(a.get("name", "")).naturalnocasecmp_to(str(b.get("name", ""))) < 0
			)

func _get_category_color(category: String) -> Color:
	match category.to_lower():
		"tools":
			return CyberTheme.COLOR_CYAN_GLOW
		"visual", "vfx", "utilities":
			return CyberTheme.COLOR_AMBER_LED
		"physics":
			return CyberTheme.COLOR_SUCCESS_LED
		"camera", "input":
			return CyberTheme.COLOR_ELECTRIC_BLUE
		"environment", "lighting":
			return Color(0.2, 0.8, 0.8, 1.0)
		"user":
			return Color(0.9, 0.9, 1.0, 0.8)
		_:
			return CyberTheme.COLOR_CYAN_GLOW

func _get_category_display_name(category: String) -> String:
	match category.to_lower():
		"tools": return "ИНСТРУМЕНТЫ"
		"visual", "vfx": return "ВИЗУАЛ"
		"physics": return "ФИЗИКА"
		"camera", "input": return "КАМЕРА / ВВОД"
		"environment", "lighting": return "ОКРУЖЕНИЕ"
		"user": return "ПОЛЬЗОВАТЕЛЬСКИЙ"
		"utilities": return "УТИЛИТЫ"
		_: return category.to_upper()

func _render_cards() -> void:
	if not is_instance_valid(grid_container):
		return

	# Очистка предыдущих карточек
	for child in grid_container.get_children():
		child.queue_free()

	var modules_to_display := _get_filtered_and_sorted_modules()

	if modules_to_display.is_empty():
		if is_instance_valid(empty_label):
			empty_label.show()
		return
	else:
		if is_instance_valid(empty_label):
			empty_label.hide()

	for mod in modules_to_display:
		var card := _create_module_card(mod)
		grid_container.add_child(card)

func _create_module_card(mod: Dictionary) -> Control:
	var mod_id: String = str(mod.get("id", ""))
	var mod_name: String = str(mod.get("name", mod_id))
	var category: String = str(mod.get("category", "tools"))
	var mod_desc: String = str(mod.get("description", ""))
	var is_active: bool = bool(mod.get("is_active", false))
	var is_builtin: bool = bool(mod.get("is_builtin", false))
	var type_str: String = str(mod.get("type", "registry"))
	var cat_color := _get_category_color(category)

	var card := PanelContainer.new()
	card.name = "Card_" + mod_id
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.custom_minimum_size = Vector2(240, 165)

	var card_sb := CyberTheme.create_glass_panel_style(
		cat_color,
		Color(-1, -1, -1, -1),
		1,
		4,
		3,
		Color(cat_color.r, cat_color.g, cat_color.b, 0.22)
	)
	card.add_theme_stylebox_override("panel", card_sb)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_bottom", 10)
	card.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	margin.add_child(vbox)

	# 1. Header HBox
	var header_hbox := HBoxContainer.new()
	header_hbox.add_theme_constant_override("separation", 6)
	vbox.add_child(header_hbox)

	# Category LED indicator
	var led := Panel.new()
	led.custom_minimum_size = Vector2(8, 8)
	led.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var led_sb := StyleBoxFlat.new()
	led_sb.bg_color = cat_color
	led_sb.corner_radius_top_left = 4
	led_sb.corner_radius_top_right = 4
	led_sb.corner_radius_bottom_right = 4
	led_sb.corner_radius_bottom_left = 4
	led.add_theme_stylebox_override("panel", led_sb)
	header_hbox.add_child(led)

	# Category name (10px, muted)
	var cat_lbl := Label.new()
	cat_lbl.text = _get_category_display_name(category)
	cat_lbl.add_theme_font_size_override("font_size", 10)
	cat_lbl.add_theme_color_override("font_color", CyberTheme.COLOR_TEXT_MUTED)
	header_hbox.add_child(cat_lbl)

	# Spacer
	var header_spacer := Control.new()
	header_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_hbox.add_child(header_spacer)

	# Status LED badge: "АКТИВЕН" (зеленый LED) / "НЕАКТИВЕН" (серый)
	var status_lbl := Label.new()
	if is_active:
		status_lbl.text = "● АКТИВЕН"
		status_lbl.add_theme_color_override("font_color", CyberTheme.COLOR_SUCCESS_LED)
	else:
		status_lbl.text = "○ НЕАКТИВЕН"
		status_lbl.add_theme_color_override("font_color", CyberTheme.COLOR_TEXT_MUTED)
	status_lbl.add_theme_font_size_override("font_size", 10)
	header_hbox.add_child(status_lbl)

	# Type badge: "[ВСТРОЕННЫЙ]" / "[ПОЛЬЗОВАТЕЛЬСКИЙ]" / "[РЕЕСТР]"
	var type_lbl := Label.new()
	match type_str:
		"builtin":
			type_lbl.text = "[ВСТРОЕННЫЙ]"
			type_lbl.add_theme_color_override("font_color", CyberTheme.COLOR_ELECTRIC_BLUE)
		"user":
			type_lbl.text = "[ПОЛЬЗОВАТЕЛЬСКИЙ]"
			type_lbl.add_theme_color_override("font_color", Color(0.9, 0.9, 1.0, 0.85))
		"registry", _:
			type_lbl.text = "[РЕЕСТР]"
			type_lbl.add_theme_color_override("font_color", CyberTheme.COLOR_AMBER_LED)
	type_lbl.add_theme_font_size_override("font_size", 10)
	header_hbox.add_child(type_lbl)

	# 2. Title
	var title_lbl := Label.new()
	title_lbl.text = mod_name
	title_lbl.add_theme_font_size_override("font_size", 14)
	title_lbl.add_theme_color_override("font_color", CyberTheme.COLOR_CYAN_GLOW)
	title_lbl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	title_lbl.tooltip_text = mod_name
	vbox.add_child(title_lbl)

	# 3. ID (monospace font / small)
	var id_lbl := Label.new()
	id_lbl.text = "ID: " + mod_id
	id_lbl.add_theme_font_size_override("font_size", 10)
	id_lbl.add_theme_color_override("font_color", CyberTheme.COLOR_TEXT_MUTED)
	vbox.add_child(id_lbl)

	# 4. Description
	var desc_lbl := Label.new()
	desc_lbl.text = mod_desc
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_lbl.max_lines_visible = 3
	desc_lbl.size_flags_vertical = Control.SIZE_EXPAND_FILL
	desc_lbl.custom_minimum_size = Vector2(0, 36)
	desc_lbl.add_theme_font_size_override("font_size", 11)
	desc_lbl.add_theme_color_override("font_color", CyberTheme.COLOR_TEXT_PRIMARY)
	vbox.add_child(desc_lbl)

	# 5. Footer HBox with buttons
	var footer_hbox := HBoxContainer.new()
	footer_hbox.add_theme_constant_override("separation", 6)
	vbox.add_child(footer_hbox)

	# Toggle Button
	var toggle_btn := Button.new()
	toggle_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	toggle_btn.custom_minimum_size = Vector2(80, 28)
	toggle_btn.add_theme_font_size_override("font_size", 11)
	toggle_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	if is_active:
		toggle_btn.text = "ВЫГРУЗИТЬ"
		toggle_btn.add_theme_stylebox_override("normal", CyberTheme.create_cyber_button_style(Color(0.2, 0.05, 0.08, 0.8), CyberTheme.COLOR_RED_LED, 1, 3))
	else:
		toggle_btn.text = "ЗАГРУЗИТЬ"
		toggle_btn.add_theme_stylebox_override("normal", CyberTheme.create_cyber_button_style(Color(0.08, 0.16, 0.28, 0.8), CyberTheme.COLOR_CYAN_GLOW, 1, 3))
	toggle_btn.pressed.connect(func(): _on_toggle_module(mod_id, is_active))
	footer_hbox.add_child(toggle_btn)

	# Code Button
	var code_btn := Button.new()
	code_btn.text = "КОД"
	code_btn.custom_minimum_size = Vector2(48, 28)
	code_btn.add_theme_font_size_override("font_size", 11)
	code_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	code_btn.add_theme_stylebox_override("normal", CyberTheme.create_cyber_button_style(Color(0.06, 0.12, 0.2, 0.7), CyberTheme.COLOR_GLASS_BORDER, 1, 3))
	code_btn.pressed.connect(func(): _on_view_code(mod_id))
	footer_hbox.add_child(code_btn)

	# MenuButton [ ⋯ ]
	var menu_btn := MenuButton.new()
	menu_btn.text = "⋯"
	menu_btn.custom_minimum_size = Vector2(30, 28)
	menu_btn.add_theme_font_size_override("font_size", 13)
	menu_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	menu_btn.add_theme_stylebox_override("normal", CyberTheme.create_cyber_button_style(Color(0.06, 0.12, 0.2, 0.7), CyberTheme.COLOR_GLASS_BORDER, 1, 3))

	var popup := menu_btn.get_popup()
	popup.clear()
	popup.add_item("Дублировать", 0)
	popup.add_item("Переименовать", 1)
	popup.set_item_disabled(1, is_builtin)
	popup.add_item("Экспортировать...", 2)
	popup.add_item("Удалить", 3)
	popup.set_item_disabled(3, is_builtin)

	popup.id_pressed.connect(func(action_id: int):
		_on_card_menu_action(action_id, mod_id, is_builtin)
	)
	footer_hbox.add_child(menu_btn)

	return card

func _on_toggle_module(mod_id: String, is_active: bool) -> void:
	if is_active:
		module_unload_requested.emit(mod_id)
		if _module_manager and _module_manager.has_method("unload_module"):
			_module_manager.unload_module(mod_id)
	else:
		module_load_requested.emit(mod_id)
		_load_module_by_id(mod_id)

	refresh_gallery()

func _load_module_by_id(mod_id: String) -> bool:
	if not _module_manager:
		return false

	# 1. Custom library load method
	if _module_library and _module_library.has_method("load_module"):
		var res = _module_library.load_module(mod_id)
		if res:
			return true

	# 2. Already active
	if _module_manager.has_method("get_active_module_ids") and _module_manager.get_active_module_ids().has(mod_id):
		return true

	# 3. From cached modules dict
	if _all_modules.has(mod_id):
		var info: Dictionary = _all_modules[mod_id]
		var sf: String = str(info.get("source_file", ""))
		var cd: String = str(info.get("code", ""))

		if not sf.is_empty() and FileAccess.file_exists(sf) and _module_manager.has_method("load_module_from_script"):
			var script = load(sf)
			if script:
				return _module_manager.load_module_from_script(mod_id, script) != null
		if not cd.is_empty() and _module_manager.has_method("load_module_from_source"):
			return _module_manager.load_module_from_source(mod_id, cd) != null

	# 4. From registry client
	if ModuleRegistryClient.VERIFIED_MODULE_TEMPLATES.has(mod_id):
		var tmpl: Dictionary = ModuleRegistryClient.VERIFIED_MODULE_TEMPLATES[mod_id]
		var cd2 := ModuleRegistryClient.get_module_source(tmpl)
		if not cd2.is_empty() and _module_manager.has_method("load_module_from_source"):
			return _module_manager.load_module_from_source(mod_id, cd2) != null

	# 5. Local paths
	var local_paths := [
		"res://modules/%s.gd" % mod_id,
		"res://modules/builtin/%s.gd" % mod_id,
		"%s/%s.gd" % [USER_MODULES_DIR, mod_id]
	]
	for lp in local_paths:
		if FileAccess.file_exists(lp) and _module_manager.has_method("load_module_from_script"):
			var script = load(lp)
			if script:
				return _module_manager.load_module_from_script(mod_id, script) != null

	return false

func get_module_source_code(mod_id: String) -> String:
	if _all_modules.has(mod_id):
		var info: Dictionary = _all_modules[mod_id]
		var code: String = str(info.get("code", ""))
		if not code.is_empty():
			return code
		var sf: String = str(info.get("source_file", ""))
		if not sf.is_empty() and FileAccess.file_exists(sf):
			var f := FileAccess.open(sf, FileAccess.READ)
			if f:
				var res := f.get_as_text()
				f.close()
				return res

	if ModuleRegistryClient.VERIFIED_MODULE_TEMPLATES.has(mod_id):
		return ModuleRegistryClient.get_module_source(ModuleRegistryClient.VERIFIED_MODULE_TEMPLATES[mod_id])

	for t in ModuleRegistryClient.get_all_templates():
		if str(t.get("id", "")) == mod_id:
			return ModuleRegistryClient.get_module_source(t)

	var user_file := "%s/%s.gd" % [USER_MODULES_DIR, mod_id]
	if FileAccess.file_exists(user_file):
		var uf := FileAccess.open(user_file, FileAccess.READ)
		if uf:
			var res2 := uf.get_as_text()
			uf.close()
			return res2

	return ""

func _on_view_code(mod_id: String) -> void:
	var code := get_module_source_code(mod_id)
	view_code_requested.emit(mod_id, code)

	if is_instance_valid(code_view_dialog) and is_instance_valid(code_view_text):
		code_view_info_lbl.text = "МОДУЛЬ: %s | Длина: %d символов" % [mod_id, code.length()]
		code_view_text.text = code
		code_view_dialog.popup_centered(Vector2i(720, 520))

func _on_card_menu_action(action_id: int, mod_id: String, is_builtin: bool) -> void:
	_active_action_mod_id = mod_id
	match action_id:
		0: # Дублировать
			if is_instance_valid(duplicate_dialog) and is_instance_valid(duplicate_edit):
				duplicate_edit.text = "%s_copy" % mod_id
				duplicate_dialog.popup_centered(Vector2i(420, 150))
				duplicate_edit.grab_focus()
		1: # Переименовать
			if not is_builtin and is_instance_valid(rename_dialog) and is_instance_valid(rename_edit):
				rename_edit.text = mod_id
				rename_dialog.popup_centered(Vector2i(420, 150))
				rename_edit.grab_focus()
		2: # Экспортировать...
			if is_instance_valid(export_file_dialog):
				export_file_dialog.current_file = "%s.gd" % mod_id
				export_file_dialog.popup_centered(Vector2i(700, 450))
		3: # Удалить
			if not is_builtin and is_instance_valid(confirm_delete_dialog):
				confirm_delete_dialog.dialog_text = "Вы уверены, что хотите удалить модуль '%s'?" % mod_id
				confirm_delete_dialog.popup_centered(Vector2i(380, 120))

func _on_duplicate_confirmed() -> void:
	var new_id := duplicate_edit.text.strip_edges()
	if new_id.is_empty():
		return
	duplicate_module(_active_action_mod_id, new_id)

func duplicate_module(orig_id: String, new_id: String) -> bool:
	var src_code := get_module_source_code(orig_id)
	if src_code.is_empty():
		src_code = "# Module %s\nextends UniCoreModule\n" % new_id

	_ensure_user_dir()
	var dest_file := "%s/%s.gd" % [USER_MODULES_DIR, new_id]
	var f := FileAccess.open(dest_file, FileAccess.WRITE)
	if f:
		f.store_string(src_code)
		f.close()

	_user_modules[new_id] = {
		"id": new_id,
		"name": new_id.capitalize(),
		"category": "user",
		"tags": ["user", "copy"],
		"description": "Копия модуля %s" % orig_id,
		"code": src_code,
		"source_file": dest_file,
		"type": "user",
		"is_builtin": false
	}

	duplicate_requested.emit(orig_id, new_id)
	if _module_library and _module_library.has_method("duplicate_module"):
		_module_library.duplicate_module(orig_id, new_id)

	refresh_gallery()
	return true

func _on_rename_confirmed() -> void:
	var new_id := rename_edit.text.strip_edges()
	if new_id.is_empty() or new_id == _active_action_mod_id:
		return
	rename_module(_active_action_mod_id, new_id)

func rename_module(old_id: String, new_id: String) -> bool:
	var old_file := "%s/%s.gd" % [USER_MODULES_DIR, old_id]
	var new_file := "%s/%s.gd" % [USER_MODULES_DIR, new_id]

	if FileAccess.file_exists(old_file):
		DirAccess.rename_absolute(old_file, new_file)

	if _user_modules.has(old_id):
		var mod_data: Dictionary = _user_modules[old_id]
		_user_modules.erase(old_id)
		mod_data["id"] = new_id
		mod_data["name"] = new_id.capitalize()
		mod_data["source_file"] = new_file
		_user_modules[new_id] = mod_data

	rename_requested.emit(old_id, new_id)
	if _module_library and _module_library.has_method("rename_module"):
		_module_library.rename_module(old_id, new_id)

	refresh_gallery()
	return true

func _on_delete_confirmed() -> void:
	delete_module(_active_action_mod_id)

func delete_module(mod_id: String) -> bool:
	if _module_manager and _module_manager.has_method("unload_module"):
		_module_manager.unload_module(mod_id)

	var u_file := "%s/%s.gd" % [USER_MODULES_DIR, mod_id]
	if FileAccess.file_exists(u_file):
		DirAccess.remove_absolute(u_file)

	_user_modules.erase(mod_id)
	_all_modules.erase(mod_id)

	delete_requested.emit(mod_id)
	if _module_library and _module_library.has_method("delete_module"):
		_module_library.delete_module(mod_id)

	refresh_gallery()
	return true

func _on_export_file_selected(path: String) -> void:
	export_module_to_file(_active_action_mod_id, path)

func export_module_to_file(mod_id: String, path: String) -> bool:
	var code := get_module_source_code(mod_id)
	var f := FileAccess.open(path, FileAccess.WRITE)
	if not f:
		return false
	f.store_string(code)
	f.close()

	export_requested.emit(mod_id, path)
	if _module_library and _module_library.has_method("export_module"):
		_module_library.export_module(mod_id, path)

	return true

func _on_import_button_pressed() -> void:
	if is_instance_valid(import_file_dialog):
		import_file_dialog.popup_centered(Vector2i(700, 450))

func _on_import_file_selected(path: String) -> void:
	import_module_from_file(path)

func import_module_from_file(file_path: String) -> bool:
	if not FileAccess.file_exists(file_path):
		return false

	var f := FileAccess.open(file_path, FileAccess.READ)
	if not f:
		return false
	var code := f.get_as_text()
	f.close()

	var base_name := file_path.get_file().trim_suffix(".gd")
	var new_id := base_name
	_ensure_user_dir()
	var dest_file := "%s/%s.gd" % [USER_MODULES_DIR, new_id]
	var out_f := FileAccess.open(dest_file, FileAccess.WRITE)
	if out_f:
		out_f.store_string(code)
		out_f.close()

	_user_modules[new_id] = {
		"id": new_id,
		"name": new_id.capitalize(),
		"category": "user",
		"tags": ["user", "imported"],
		"description": "Импортированный модуль из %s" % file_path,
		"code": code,
		"source_file": dest_file,
		"type": "user",
		"is_builtin": false
	}

	import_requested.emit(file_path)
	if _module_library and _module_library.has_method("import_module"):
		_module_library.import_module(file_path)

	refresh_gallery()
	return true
