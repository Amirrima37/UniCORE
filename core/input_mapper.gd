class_name InputMapper
extends Node

## Диспетчер назначения клавиш и управления UniCORE (Input Mapper)
## Отвечает за:
## 1. Регистрацию системных горячих клавиш UniCORE
## 2. Обнаружение действий активных модулей (через get_action_bindings() или парсинг скриптов)
## 3. Обнаружение действий модулей из Библиотеки
## 4. Человекопонятное форматирование клавиш
## 5. Детекцию конфликтов назначений
## 6. Связь с SettingsManager и Godot InputMap

signal binding_changed(action: String, old_key: int, new_key: int)
signal bindings_reset()
signal actions_refreshed()

const SettingsManagerScript = preload("res://core/settings_manager.gd")

# Категории действий
const CAT_SYSTEM := "system"
const CAT_ACTIVE := "active"
const CAT_LIBRARY := "library"

# Системные действия по умолчанию
const DEFAULT_SYSTEM_ACTIONS: Array[Dictionary] = [
	{
		"action": "toggle_menu",
		"label": "Главное меню / Пауза",
		"default_key": KEY_ESCAPE,
		"category": CAT_SYSTEM,
		"module_id": "system",
		"module_name": "Система UniCORE",
		"description": "Открытие и закрытие системного меню"
	},
	{
		"action": "toggle_fullscreen",
		"label": "Полноэкранный режим",
		"default_key": KEY_F11,
		"category": CAT_SYSTEM,
		"module_id": "system",
		"module_name": "Система UniCORE",
		"description": "Переключение между оконным и полноэкранным режимом"
	},
	{
		"action": "toggle_prompt_bar",
		"label": "Строка команд Агента (PromptBar)",
		"default_key": KEY_TAB,
		"category": CAT_SYSTEM,
		"module_id": "system",
		"module_name": "Система UniCORE",
		"description": "Быстрый вызов терминала ввода промптов"
	},
	{
		"action": "toggle_analysis_drawer",
		"label": "Панель диагностики и кода",
		"default_key": KEY_F10,
		"category": CAT_SYSTEM,
		"module_id": "system",
		"module_name": "Система UniCORE",
		"description": "Боковая панель телеметрии и инспектора GDScript"
	},
	{
		"action": "toggle_module_gallery",
		"label": "Галерея модулей (Библиотека)",
		"default_key": KEY_F9,
		"category": CAT_SYSTEM,
		"module_id": "system",
		"module_name": "Система UniCORE",
		"description": "Каталог модулей и шаблонов"
	}
]

var _settings_manager: Node = null
var _module_manager: Node = null
var _module_library: Node = null
var _event_bus: Node = null

# Хранилище зарегистрированных действий: action_name -> Dictionary
var _actions: Dictionary = {}

func setup(
	settings_manager: Node,
	module_manager: Node = null,
	module_library: Node = null,
	event_bus: Node = null
) -> void:
	_settings_manager = settings_manager
	_module_manager = module_manager
	_module_library = module_library
	_event_bus = event_bus

	_register_system_actions()

	if _event_bus:
		_event_bus.subscribe("module_loaded", _on_module_lifecycle_changed)
		_event_bus.subscribe("module_unloaded", _on_module_lifecycle_changed)
		_event_bus.subscribe("space_loaded", _on_space_loaded)

	refresh_actions()
	apply_all_bindings_to_input_map()

func _on_module_lifecycle_changed(_payload: Dictionary) -> void:
	refresh_actions()

func _on_space_loaded(_payload: Dictionary) -> void:
	refresh_actions()

## Регистрирует базовые системные действия
func _register_system_actions() -> void:
	for act in DEFAULT_SYSTEM_ACTIONS:
		register_action(
			act["action"],
			act["label"],
			act["default_key"],
			act["category"],
			act["module_id"],
			act["module_name"],
			act["description"]
		)

## Регистрация действия
func register_action(
	action: String,
	label: String,
	default_key: int,
	category: String = CAT_ACTIVE,
	module_id: String = "",
	module_name: String = "",
	description: String = ""
) -> void:
	_actions[action] = {
		"action": action,
		"label": label,
		"default_key": default_key,
		"category": category,
		"module_id": module_id,
		"module_name": module_name if not module_name.is_empty() else module_id,
		"description": description
	}

## Сканирует активные модули и модули из библиотеки
func refresh_actions() -> void:
	# 1. Сбрасываем модульные действия, сохраняя системные
	var to_remove: Array[String] = []
	for act_name in _actions.keys():
		if _actions[act_name]["category"] != CAT_SYSTEM:
			to_remove.append(act_name)
	for act_name in to_remove:
		_actions.erase(act_name)

	var active_module_ids: Array[String] = []

	# 2. Сканируем активные модули из ModuleManager
	if _module_manager and _module_manager.has_method("get_active_modules"):
		var active_mods: Array = _module_manager.get_active_modules()
		for mod in active_mods:
			if not (mod is Node):
				continue
			var mod_id: String = mod.get_module_id() if mod.has_method("get_module_id") else mod.name
			var mod_name: String = mod.get_module_name() if mod.has_method("get_module_name") else mod_id
			active_module_ids.append(mod_id)

			# А) Метод get_action_bindings()
			if mod.has_method("get_action_bindings"):
				var bindings = mod.get_action_bindings()
				if bindings is Array:
					for b in bindings:
						if b is Dictionary and b.has("action"):
							register_action(
								b["action"],
								b.get("label", b["action"]),
								int(b.get("default_key", KEY_NONE)),
								CAT_ACTIVE,
								mod_id,
								mod_name,
								b.get("description", "")
							)

			# Б) Если метод ничего не вернул или отсутствует — парсим скрипт
			var script_obj = mod.get_script()
			if script_obj and script_obj is Script:
				var src: String = script_obj.source_code
				_parse_actions_from_source(src, mod_id, mod_name, CAT_ACTIVE)

	# 3. Сканируем модули из ModuleLibrary (те, что не активны)
	if _module_library and _module_library.has_method("get_available_modules"):
		var lib_mods: Array[Dictionary] = _module_library.get_available_modules()
		for item in lib_mods:
			var mod_id: String = item.get("id", "")
			if mod_id.is_empty() or active_module_ids.has(mod_id):
				continue # Уже учтен в активных
			var mod_name: String = item.get("name", mod_id)
			var file_path: String = item.get("file_path", "")
			if not file_path.is_empty() and FileAccess.file_exists(file_path):
				var f := FileAccess.open(file_path, FileAccess.READ)
				if f:
					var src: String = f.get_as_text()
					f.close()
					_parse_actions_from_source(src, mod_id, mod_name, CAT_LIBRARY)

	actions_refreshed.emit()

## Парсинг действий из исходного кода модуля
func _parse_actions_from_source(
	source: String,
	module_id: String,
	module_name: String,
	category: String
) -> void:
	if source.is_empty():
		return

	# Регулярка для комментариев: ## Action: action_name (Default: Key, Label: "...")
	# или # Action: action_name = KEY_W
	var lines := source.split("\n")
	for line in lines:
		var stripped := line.strip_edges()
		if stripped.begins_with("## Action:") or stripped.begins_with("# Action:"):
			var content := stripped.substr(stripped.find(":") + 1).strip_edges()
			_parse_single_action_directive(content, module_id, module_name, category)

	# Регулярка для поиска Input.is_action_pressed("action") / Input.is_action_just_pressed("action")
	var regex := RegEx.new()
	var err := regex.compile('Input\\.(?:is_action_pressed|is_action_just_pressed|is_action_just_released)\\s*\\(\\s*["\']([a-zA-Z0-9_]+)["\']\\s*\\)')
	if err == OK:
		var matches := regex.search_all(source)
		for m in matches:
			var act_name: String = m.get_string(1)
			if not _actions.has(act_name):
				var default_key: int = _get_known_default_key(act_name)
				var label: String = _format_action_label(act_name)
				register_action(
					act_name,
					label,
					default_key,
					category,
					module_id,
					module_name,
					"Действие модуля %s" % module_name
				)

func _parse_single_action_directive(
	directive: String,
	module_id: String,
	module_name: String,
	category: String
) -> void:
	# Пример: move_forward = KEY_W ("Вперед", "Перемещение")
	var parts := directive.split("=")
	if parts.size() < 2:
		return
	var act_name := parts[0].strip_edges()
	var rest := parts[1].strip_edges()

	var key_code: int = KEY_NONE
	var label: String = act_name
	var desc: String = ""

	# Ищем название клавиши
	var words := rest.split(" ")
	if words.size() > 0:
		var key_str := words[0].strip_edges()
		key_code = parse_key_string_to_code(key_str)

	# Ищем кавычки для label и description
	var quote_reg := RegEx.new()
	if quote_reg.compile('"([^"]*)"') == OK:
		var q_matches := quote_reg.search_all(rest)
		if q_matches.size() > 0:
			label = q_matches[0].get_string(1)
		if q_matches.size() > 1:
			desc = q_matches[1].get_string(1)

	register_action(act_name, label, key_code, category, module_id, module_name, desc)

## Возвращает дефолтный keycode для общепринятых действий
func _get_known_default_key(action: String) -> int:
	match action:
		"move_forward": return KEY_W
		"move_backward": return KEY_S
		"move_left": return KEY_A
		"move_right": return KEY_D
		"move_up", "jump": return KEY_SPACE
		"move_down", "crouch": return KEY_CTRL
		"sprint": return KEY_SHIFT
		"interact": return KEY_E
		"reload": return KEY_R
		"flashlight": return KEY_F
		"fire", "primary_action": return KEY_NONE
		_: return KEY_NONE

## Форматирует имя действия в читаемый вид, если нет метаданных
func _format_action_label(action: String) -> String:
	match action:
		"move_forward": return "Движение вперед"
		"move_backward": return "Движение назад"
		"move_left": return "Движение влево"
		"move_right": return "Движение вправо"
		"move_up": return "Подъем / Полет вверх"
		"move_down": return "Спуск / Полет вниз"
		"sprint": return "Ускорение (Спринт)"
		"jump": return "Прыжок"
		"crouch": return "Приседание"
		"interact": return "Взаимодействие"
		"flashlight": return "Фонарь"
		_:
			var words := action.replace("_", " ").capitalize()
			return words

## Получить текущий назначенный keycode для действия
func get_bound_key(action: String) -> int:
	if _settings_manager and _settings_manager.has_method("get_binding"):
		var def_key: int = KEY_NONE
		if _actions.has(action):
			def_key = _actions[action]["default_key"]
		return _settings_manager.get_binding(action, def_key)
	if _actions.has(action):
		return _actions[action]["default_key"]
	return KEY_NONE

## Получить дефолтный keycode для действия
func get_default_key(action: String) -> int:
	if _actions.has(action):
		return _actions[action]["default_key"]
	return KEY_NONE

## Назначить новую клавишу действию
func rebind_action(action: String, new_keycode: int, auto_save: bool = true) -> bool:
	if not _actions.has(action):
		# Если действие еще не в списке, но переназначается, регистрируем его
		register_action(action, _format_action_label(action), new_keycode)

	var old_key: int = get_bound_key(action)

	# 1. Сохраняем в SettingsManager
	if _settings_manager and _settings_manager.has_method("set_binding"):
		_settings_manager.set_binding(action, new_keycode, auto_save)

	# 2. Обновляем Godot InputMap
	_bind_to_input_map(action, new_keycode)

	binding_changed.emit(action, old_key, new_keycode)
	return true

## Сброс одного действия к дефолтной клавише
func reset_action_to_default(action: String) -> void:
	if _actions.has(action):
		var def_key: int = _actions[action]["default_key"]
		rebind_action(action, def_key, true)

## Сброс всех действий к дефолтным клавишам
func reset_all_to_defaults() -> void:
	for act_name in _actions.keys():
		var def_key: int = _actions[act_name]["default_key"]
		if _settings_manager and _settings_manager.has_method("set_binding"):
			_settings_manager.set_binding(act_name, def_key, false)
		_bind_to_input_map(act_name, def_key)

	if _settings_manager and _settings_manager.has_method("save_settings"):
		_settings_manager.save_settings()

	bindings_reset.emit()

## Применяет все бинды к InputMap Godot
func apply_all_bindings_to_input_map() -> void:
	for act_name in _actions.keys():
		var kc := get_bound_key(act_name)
		_bind_to_input_map(act_name, kc)

func _bind_to_input_map(action: String, keycode: int) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	else:
		InputMap.action_erase_events(action)

	if keycode > 0:
		var ev := InputEventKey.new()
		ev.physical_keycode = keycode as Key
		ev.keycode = keycode as Key
		InputMap.action_add_event(action, ev)

		# Для полноэкранного режима дублируем Alt+Enter
		if action == "toggle_fullscreen":
			var alt_enter := InputEventKey.new()
			alt_enter.keycode = KEY_ENTER
			alt_enter.alt_pressed = true
			InputMap.action_add_event(action, alt_enter)

## Проверка конфликта клавиш
func check_conflict(action: String, keycode: int) -> Dictionary:
	if keycode == KEY_NONE or keycode <= 0:
		return {"has_conflict": false}

	for other_act in _actions.keys():
		if other_act == action:
			continue
		var other_key := get_bound_key(other_act)
		if other_key == keycode:
			var act_info: Dictionary = _actions[other_act]
			return {
				"has_conflict": true,
				"conflicting_action": other_act,
				"conflicting_label": act_info.get("label", other_act),
				"conflicting_module": act_info.get("module_name", ""),
				"category": act_info.get("category", "")
			}

	return {"has_conflict": false}

## Получить все зарегистрированные действия по категориям
func get_actions_by_category(category: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for act_name in _actions.keys():
		var entry: Dictionary = _actions[act_name]
		if entry.get("category") == category:
			var copy: Dictionary = entry.duplicate()
			copy["current_key"] = get_bound_key(act_name)
			result.append(copy)
	return result

## Получить действия, сгруппированные по модулям
func get_actions_grouped_by_module(category_filter: String = "") -> Dictionary:
	var groups: Dictionary = {} # module_id -> { "name": String, "actions": Array }
	for act_name in _actions.keys():
		var entry: Dictionary = _actions[act_name]
		var cat: String = entry.get("category", "")
		if not category_filter.is_empty() and cat != category_filter:
			continue

		var mod_id: String = entry.get("module_id", "general")
		var mod_name: String = entry.get("module_name", mod_id)

		if not groups.has(mod_id):
			groups[mod_id] = {
				"id": mod_id,
				"name": mod_name,
				"category": cat,
				"actions": []
			}

		var act_copy: Dictionary = entry.duplicate()
		act_copy["current_key"] = get_bound_key(act_name)
		groups[mod_id]["actions"].append(act_copy)

	return groups

## Получить список всех действий
func get_all_actions() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for act_name in _actions.keys():
		var entry: Dictionary = _actions[act_name].duplicate()
		entry["current_key"] = get_bound_key(act_name)
		result.append(entry)
	return result

## Форматирует код клавиши в читаемый текст (Detroit/Clean стиль)
static func get_key_display_name(keycode: int) -> String:
	if keycode <= 0 or keycode == KEY_NONE:
		return "—"

	match keycode:
		KEY_ESCAPE: return "ESC"
		KEY_TAB: return "TAB"
		KEY_BACKSPACE: return "BACKSPACE"
		KEY_ENTER: return "ENTER"
		KEY_SPACE: return "SPACE"
		KEY_INSERT: return "INS"
		KEY_DELETE: return "DEL"
		KEY_HOME: return "HOME"
		KEY_END: return "END"
		KEY_PAGEUP: return "PGUP"
		KEY_PAGEDOWN: return "PGDN"
		KEY_LEFT: return "← LEFT"
		KEY_RIGHT: return "→ RIGHT"
		KEY_UP: return "↑ UP"
		KEY_DOWN: return "↓ DOWN"
		KEY_SHIFT: return "SHIFT"
		KEY_CTRL: return "CTRL"
		KEY_ALT: return "ALT"
		KEY_CAPSLOCK: return "CAPS"
		KEY_F1: return "F1"
		KEY_F2: return "F2"
		KEY_F3: return "F3"
		KEY_F4: return "F4"
		KEY_F5: return "F5"
		KEY_F6: return "F6"
		KEY_F7: return "F7"
		KEY_F8: return "F8"
		KEY_F9: return "F9"
		KEY_F10: return "F10"
		KEY_F11: return "F11"
		KEY_F12: return "F12"
		_:
			var s := OS.get_keycode_string(keycode)
			if not s.is_empty():
				return s.to_upper()
			return "KEY_%d" % keycode

## Парсит строковое имя клавиши (например, "KEY_W", "SPACE", "F11") в целое число
static func parse_key_string_to_code(str_val: String) -> int:
	var clean := str_val.strip_edges().to_upper()
	if clean.begins_with("KEY_"):
		clean = clean.substr(4)

	match clean:
		"NONE", "": return KEY_NONE
		"ESC", "ESCAPE": return KEY_ESCAPE
		"TAB": return KEY_TAB
		"SPACE": return KEY_SPACE
		"ENTER", "RETURN": return KEY_ENTER
		"BACKSPACE": return KEY_BACKSPACE
		"SHIFT": return KEY_SHIFT
		"CTRL", "CONTROL": return KEY_CTRL
		"ALT": return KEY_ALT
		"UP": return KEY_UP
		"DOWN": return KEY_DOWN
		"LEFT": return KEY_LEFT
		"RIGHT": return KEY_RIGHT
		"F1": return KEY_F1
		"F2": return KEY_F2
		"F3": return KEY_F3
		"F4": return KEY_F4
		"F5": return KEY_F5
		"F6": return KEY_F6
		"F7": return KEY_F7
		"F8": return KEY_F8
		"F9": return KEY_F9
		"F10": return KEY_F10
		"F11": return KEY_F11
		"F12": return KEY_F12
		_:
			if clean.length() == 1:
				var c := clean.unicode_at(0)
				if c >= 65 and c <= 90: # A-Z
					return c
				if c >= 48 and c <= 57: # 0-9
					return c
			var find_key := OS.find_keycode_from_string(clean)
			if find_key != 0:
				return find_key
			return KEY_NONE
