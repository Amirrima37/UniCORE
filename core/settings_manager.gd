class_name SettingsManager
extends Node

## Менеджер глобальных настроек UniCORE
## Отвечает за сохранение, загрузку и применение параметров:
## графика (полноэкранный режим, разрешение, VSync), управление, звук и конфигурация ИИ.

const CyberTheme = preload("res://ui/theme/cyber_theme.gd")

signal setting_changed(category: String, key: String, value: Variant)
signal settings_applied()
signal interface_settings_changed(settings: Dictionary)

const SETTINGS_FILE_PATH: String = "user://settings.json"

const RESOLUTION_PRESETS: Array[Vector2i] = [
	Vector2i(1280, 720),
	Vector2i(1600, 900),
	Vector2i(1920, 1080),
	Vector2i(2560, 1440)
]

const DEFAULT_KEYBINDINGS: Dictionary = {
	"move_forward": KEY_W,
	"move_backward": KEY_S,
	"move_left": KEY_A,
	"move_right": KEY_D,
	"move_up": KEY_SPACE,
	"move_down": KEY_CTRL,
	"sprint": KEY_SHIFT,
	"toggle_fullscreen": KEY_F11
}

const DEFAULT_SETTINGS: Dictionary = {
	"display": {
		"fullscreen": false,
		"exclusive_fullscreen": false,
		"resolution_width": 1280,
		"resolution_height": 720,
		"resolution_index": 0,
		"vsync": true,
		"fps_limit": 0,
		"scale_factor": 1.0
	},
	"controls": {
		"mouse_sensitivity": 0.002,
		"invert_y": false,
		"move_speed": 10.0,
		"sprint_speed": 25.0,
		"bindings": {
			"move_forward": KEY_W,
			"move_backward": KEY_S,
			"move_left": KEY_A,
			"move_right": KEY_D,
			"move_up": KEY_SPACE,
			"move_down": KEY_CTRL,
			"sprint": KEY_SHIFT,
			"toggle_fullscreen": KEY_F11
		}
	},
	"audio": {
		"master_volume": 0.8,
		"music_volume": 0.8,
		"sfx_volume": 0.8,
		"ui_volume": 0.8,
		"ui_sound_enabled": true
	},
	"agent": {
		"provider": "local_embedded",
		"model": "qwen2.5-coder-1.5b",
		"auto_fallback_to_local": true,
		"custom_base_url": "",
		"custom_model": "",
		"local_model_path": "",
		"local_server_port": 8080,
		"local_server_threads": 4,
		"api_key": "",
		"api_keys": {
			"gemini": "",
			"openai": "",
			"openrouter": "",
			"deepseek": "",
			"groq": "",
			"anthropic": "",
			"mistral": "",
			"custom": ""
		},
		"models": {
			"gemini": "gemini-2.5-flash",
			"openai": "gpt-4o-mini",
			"openrouter": "google/gemini-2.5-flash",
			"deepseek": "deepseek-chat",
			"groq": "llama-3.3-70b-versatile",
			"anthropic": "claude-3-5-sonnet-20241022",
			"mistral": "codestral-latest",
			"local_embedded": "qwen2.5-coder-1.5b",
			"custom": ""
		}
	},
	"session": {
		"last_active_space": "space_default"
	},
	"interface": {
		"theme": "cyberlife_white",
		"glass_opacity": 0.75,
		"led_intensity": 1.0,
		"prompt_bar_autoclose": true
	},
	"network": {
		"auto_discovery": true,
		"share_modules": true,
		"host_port": 7777,
		"discovery_port": 7778,
		"player_name": "UniCORE Node",
		"max_module_size_kb": 64
	}
}

const AUDIO_BUS_SETTINGS_MAP: Dictionary = {
	"Master": "master_volume",
	"Music": "music_volume",
	"SFX": "sfx_volume",
	"UI": "ui_volume"
}

var _settings: Dictionary = DEFAULT_SETTINGS.duplicate(true)
var _event_bus: EventBus

func _init() -> void:
	ensure_audio_buses()

func setup(event_bus: EventBus = null) -> void:
	_event_bus = event_bus
	load_settings()
	apply_all_settings()

func reset_to_defaults() -> void:
	_settings = DEFAULT_SETTINGS.duplicate(true)
	apply_all_settings()
	save_settings()

func load_settings() -> void:
	if not FileAccess.file_exists(SETTINGS_FILE_PATH):
		print("[SettingsManager] Settings file not found, initializing defaults.")
		_settings = DEFAULT_SETTINGS.duplicate(true)
		save_settings()
		return

	var file := FileAccess.open(SETTINGS_FILE_PATH, FileAccess.READ)
	if not file:
		push_warning("[SettingsManager] Failed to read settings file: %s" % SETTINGS_FILE_PATH)
		return

	var json_str := file.get_as_text()
	file.close()

	if json_str.strip_edges().is_empty():
		push_warning("[SettingsManager] Settings file is empty. Recovering with default settings.")
		_recover_corrupted_file(json_str)
		return

	var json := JSON.new()
	var parse_err := json.parse(json_str)
	if parse_err != OK:
		push_warning("[SettingsManager] JSON parse error in settings: %s (at line %d). Recovering with default settings." % [json.get_error_message(), json.get_error_line()])
		_recover_corrupted_file(json_str)
		return

	var data = json.get_data()
	if not (data is Dictionary):
		push_warning("[SettingsManager] Settings root is not a Dictionary. Recovering with default settings.")
		_recover_corrupted_file(json_str)
		return

	# Merge loaded data on top of clean defaults with validation
	var merged: Dictionary = DEFAULT_SETTINGS.duplicate(true)
	for cat in data.keys():
		if merged.has(cat) and data[cat] is Dictionary:
			var cat_dict: Dictionary = data[cat]
			for key in cat_dict.keys():
				var raw_val = cat_dict[key]
				if merged[cat].has(key):
					var def_val = DEFAULT_SETTINGS[cat][key]
					var sanitized = _validate_and_sanitize(cat, key, raw_val, def_val)
					merged[cat][key] = sanitized
				else:
					merged[cat][key] = raw_val
		else:
			merged[cat] = data[cat]

	# Smooth migration and defaults integrity for agent settings
	if merged.has("agent") and merged["agent"] is Dictionary:
		var agent_dict: Dictionary = merged["agent"]
		if not (agent_dict.get("api_keys") is Dictionary):
			agent_dict["api_keys"] = (DEFAULT_SETTINGS["agent"]["api_keys"] as Dictionary).duplicate()
		else:
			var def_api_keys: Dictionary = DEFAULT_SETTINGS["agent"]["api_keys"]
			for k in def_api_keys.keys():
				if not agent_dict["api_keys"].has(k):
					agent_dict["api_keys"][k] = def_api_keys[k]

		if not (agent_dict.get("models") is Dictionary):
			agent_dict["models"] = (DEFAULT_SETTINGS["agent"]["models"] as Dictionary).duplicate()
		else:
			var def_models: Dictionary = DEFAULT_SETTINGS["agent"]["models"]
			for k in def_models.keys():
				if not agent_dict["models"].has(k):
					agent_dict["models"][k] = def_models[k]

		# Migration of legacy flat api_key
		var old_key: String = ""
		if data.has("agent") and (data["agent"] is Dictionary) and data["agent"].has("api_key"):
			old_key = str(data["agent"]["api_key"]).strip_edges()
		elif agent_dict.has("api_key"):
			old_key = str(agent_dict["api_key"]).strip_edges()

		if not old_key.is_empty():
			var p_name: String = str(agent_dict.get("provider", "local_embedded"))
			if agent_dict["api_keys"].has(p_name):
				if str(agent_dict["api_keys"][p_name]).is_empty():
					agent_dict["api_keys"][p_name] = old_key
			else:
				agent_dict["api_keys"][p_name] = old_key
			agent_dict["api_key"] = old_key

	_settings = merged
	print("[SettingsManager] Settings successfully loaded from disk.")

func _recover_corrupted_file(original_content: String) -> void:
	if not original_content.strip_edges().is_empty():
		var backup_path := SETTINGS_FILE_PATH + ".bak"
		var bak_file := FileAccess.open(backup_path, FileAccess.WRITE)
		if bak_file:
			bak_file.store_string(original_content)
			bak_file.close()
			print("[SettingsManager] Corrupted settings backed up to: %s" % backup_path)

	_settings = DEFAULT_SETTINGS.duplicate(true)
	save_settings()
	print("[SettingsManager] Recovered from corrupted/empty settings. Restored and saved defaults.")

func _validate_and_sanitize(category: String, key: String, raw_val: Variant, default_val: Variant) -> Variant:
	if raw_val == null:
		return default_val

	match category:
		"display":
			match key:
				"fullscreen", "vsync", "exclusive_fullscreen":
					if raw_val is bool:
						return raw_val
					if (raw_val is int or raw_val is float) and not (raw_val is bool):
						return int(raw_val) != 0
					if raw_val is String:
						var s := (raw_val as String).to_lower().strip_edges()
						if s == "true" or s == "1": return true
						if s == "false" or s == "0": return false
					return default_val
				"resolution_width":
					if (raw_val is int or raw_val is float) and not (raw_val is bool):
						var w := int(raw_val)
						return clampi(w, 640, 15360)
					return default_val
				"resolution_height":
					if (raw_val is int or raw_val is float) and not (raw_val is bool):
						var h := int(raw_val)
						return clampi(h, 360, 8640)
					return default_val
				"resolution_index":
					if (raw_val is int or raw_val is float) and not (raw_val is bool):
						var idx := int(raw_val)
						return clampi(idx, 0, max(0, RESOLUTION_PRESETS.size() - 1))
					return default_val
				"fps_limit":
					if (raw_val is int or raw_val is float) and not (raw_val is bool):
						var fps := int(raw_val)
						return clampi(fps, 0, 1000)
					return default_val
				"scale_factor":
					if (raw_val is int or raw_val is float) and not (raw_val is bool):
						var sf := float(raw_val)
						if not is_nan(sf) and not is_inf(sf):
							return clampf(sf, 0.5, 3.0)
					return default_val

		"controls":
			match key:
				"mouse_sensitivity":
					if (raw_val is int or raw_val is float) and not (raw_val is bool):
						var sens := float(raw_val)
						if sens > 0.0 and sens <= 1.0:
							return clampf(sens, 0.0001, 0.1)
					return default_val
				"invert_y":
					if raw_val is bool:
						return raw_val
					if (raw_val is int or raw_val is float) and not (raw_val is bool):
						return int(raw_val) != 0
					if raw_val is String:
						var s := (raw_val as String).to_lower().strip_edges()
						if s == "true" or s == "1": return true
						if s == "false" or s == "0": return false
					return default_val
				"move_speed":
					if (raw_val is int or raw_val is float) and not (raw_val is bool):
						var spd := float(raw_val)
						if spd > 0.0:
							return clampf(spd, 1.0, 500.0)
					return default_val
				"sprint_speed":
					if (raw_val is int or raw_val is float) and not (raw_val is bool):
						var spd := float(raw_val)
						if spd > 0.0:
							return clampf(spd, 1.0, 1000.0)
					return default_val
				"bindings":
					if raw_val is Dictionary:
						var sanitized_bindings: Dictionary = DEFAULT_KEYBINDINGS.duplicate()
						for action in (raw_val as Dictionary).keys():
							var kc = (raw_val as Dictionary)[action]
							if (kc is int or kc is float) and not (kc is bool):
								var code := int(kc)
								if code >= 0:
									sanitized_bindings[str(action)] = code
						return sanitized_bindings
					return default_val

		"audio":
			match key:
				"master_volume", "music_volume", "sfx_volume", "ui_volume":
					if (raw_val is int or raw_val is float) and not (raw_val is bool):
						var f := float(raw_val)
						if is_nan(f) or is_inf(f):
							return 0.0
						return clampf(f, 0.0, 1.0)
					return default_val
				"ui_sound_enabled":
					if raw_val is bool:
						return raw_val
					if (raw_val is int or raw_val is float) and not (raw_val is bool):
						return int(raw_val) != 0
					return default_val

		"agent":
			match key:
				"provider", "model", "api_key", "custom_base_url", "custom_model", "local_model_path":
					if raw_val is String:
						return raw_val
					return str(raw_val)
				"auto_fallback_to_local":
					if raw_val is bool:
						return raw_val
					if (raw_val is int or raw_val is float) and not (raw_val is bool):
						return int(raw_val) != 0
					if raw_val is String:
						var s := (raw_val as String).to_lower().strip_edges()
						if s == "true" or s == "1": return true
						if s == "false" or s == "0": return false
					return default_val
				"local_server_port":
					if (raw_val is int or raw_val is float) and not (raw_val is bool):
						var port := int(raw_val)
						return clampi(port, 1024, 65535)
					return default_val
				"local_server_threads":
					if (raw_val is int or raw_val is float) and not (raw_val is bool):
						var threads := int(raw_val)
						return clampi(threads, 1, 64)
					return default_val
				"api_keys":
					if raw_val is Dictionary:
						var def_keys: Dictionary = default_val if (default_val is Dictionary) else (DEFAULT_SETTINGS["agent"]["api_keys"] as Dictionary).duplicate()
						var merged_keys: Dictionary = def_keys.duplicate()
						for k in (raw_val as Dictionary).keys():
							merged_keys[str(k)] = str((raw_val as Dictionary)[k])
						return merged_keys
					return default_val
				"models":
					if raw_val is Dictionary:
						var def_models: Dictionary = default_val if (default_val is Dictionary) else (DEFAULT_SETTINGS["agent"]["models"] as Dictionary).duplicate()
						var merged_models: Dictionary = def_models.duplicate()
						for k in (raw_val as Dictionary).keys():
							merged_models[str(k)] = str((raw_val as Dictionary)[k])
						return merged_models
					return default_val

		"session":
			match key:
				"last_active_space":
					if raw_val is String:
						return raw_val
					return str(raw_val)

		"interface":
			match key:
				"theme":
					if raw_val is String:
						var s := (raw_val as String).strip_edges().to_lower()
						if s == "cyberlife_white" or s == "cyber_void":
							return s
					return default_val
				"glass_opacity":
					if (raw_val is int or raw_val is float) and not (raw_val is bool):
						var f := float(raw_val)
						if not is_nan(f) and not is_inf(f):
							return clampf(f, 0.2, 0.95)
					return default_val
				"led_intensity":
					if (raw_val is int or raw_val is float) and not (raw_val is bool):
						var f := float(raw_val)
						if not is_nan(f) and not is_inf(f):
							return clampf(f, 0.5, 2.0)
					return default_val
				"prompt_bar_autoclose":
					if raw_val is bool:
						return raw_val
					if (raw_val is int or raw_val is float) and not (raw_val is bool):
						return int(raw_val) != 0
					if raw_val is String:
						var s := (raw_val as String).to_lower().strip_edges()
						if s == "true" or s == "1": return true
						if s == "false" or s == "0": return false
					return default_val

		"network":
			match key:
				"auto_discovery", "share_modules":
					if raw_val is bool:
						return raw_val
					if (raw_val is int or raw_val is float) and not (raw_val is bool):
						return int(raw_val) != 0
					if raw_val is String:
						var s := (raw_val as String).to_lower().strip_edges()
						if s == "true" or s == "1": return true
						if s == "false" or s == "0": return false
					return default_val
				"host_port", "discovery_port":
					if (raw_val is int or raw_val is float) and not (raw_val is bool):
						var port := int(raw_val)
						return clampi(port, 1024, 65535)
					return default_val
				"player_name":
					if raw_val is String:
						var name_str := (raw_val as String).strip_edges()
						if not name_str.is_empty():
							return name_str.substr(0, 32)
					return default_val
				"max_module_size_kb":
					if (raw_val is int or raw_val is float) and not (raw_val is bool):
						var sz := int(raw_val)
						return clampi(sz, 1, 1024)
					return default_val

	return raw_val

func save_settings() -> bool:
	var file := FileAccess.open(SETTINGS_FILE_PATH, FileAccess.WRITE)
	if not file:
		push_error("[SettingsManager] Cannot write settings file: %s" % SETTINGS_FILE_PATH)
		return false

	var json_str := JSON.stringify(_settings, "\t")
	file.store_string(json_str)
	file.close()
	print("[SettingsManager] Settings successfully saved to disk.")
	return true

func get_setting(category: String, key: String, default_val: Variant = null) -> Variant:
	if _settings.has(category) and _settings[category].has(key):
		return _settings[category][key]
	return default_val

func get_category(category: String) -> Dictionary:
	return _settings.get(category, {}).duplicate()

func set_setting(category: String, key: String, value: Variant, auto_save: bool = true) -> void:
	if not _settings.has(category):
		_settings[category] = {}

	var def_val = null
	if DEFAULT_SETTINGS.has(category) and DEFAULT_SETTINGS[category].has(key):
		def_val = DEFAULT_SETTINGS[category][key]

	var sanitized_val = _validate_and_sanitize(category, key, value, def_val) if def_val != null else value
	_settings[category][key] = sanitized_val

	setting_changed.emit(category, key, sanitized_val)
	if _event_bus:
		_event_bus.emit("setting_changed", {
			"category": category,
			"key": key,
			"value": sanitized_val
		})
		if category == "controls":
			_event_bus.emit("controls_settings_updated", get_category("controls"))

	if category == "interface":
		var iface_data: Dictionary = get_category("interface")
		CyberTheme.apply_interface_settings(iface_data)
		interface_settings_changed.emit(iface_data)
		if _event_bus:
			_event_bus.emit("interface_settings_changed", iface_data)

	if category == "controls" and key == "bindings":
		apply_input_bindings()

	if auto_save:
		save_settings()

func apply_all_settings() -> void:
	# 1. Display
	var fs: bool = bool(get_setting("display", "fullscreen", false))
	set_fullscreen(fs, false)

	var rw: int = int(get_setting("display", "resolution_width", 1280))
	var rh: int = int(get_setting("display", "resolution_height", 720))
	if not fs:
		set_resolution(rw, rh, false)

	var vsync: bool = bool(get_setting("display", "vsync", true))
	set_vsync(vsync, false)

	var fps_limit: int = int(get_setting("display", "fps_limit", 0))
	set_fps_limit(fps_limit, false)

	var scale_factor: float = float(get_setting("display", "scale_factor", 1.0))
	set_viewport_scale_factor(scale_factor, false)

	# 2. Audio
	ensure_audio_buses()
	var master_vol: float = float(get_setting("audio", "master_volume", 0.8))
	set_master_volume(master_vol, false)
	var music_vol: float = float(get_setting("audio", "music_volume", 0.8))
	set_music_volume(music_vol, false)
	var sfx_vol: float = float(get_setting("audio", "sfx_volume", 0.8))
	set_sfx_volume(sfx_vol, false)
	var ui_vol: float = float(get_setting("audio", "ui_volume", 0.8))
	set_ui_volume(ui_vol, false)
	var ui_snd: bool = bool(get_setting("audio", "ui_sound_enabled", true))
	set_ui_sound_enabled(ui_snd, false)

	# 3. Controls & InputMap
	apply_input_bindings()
	if _event_bus:
		_event_bus.emit("controls_settings_updated", get_category("controls"))

	# 4. Interface & CyberTheme
	var iface_data: Dictionary = get_category("interface")
	CyberTheme.apply_interface_settings(iface_data)
	interface_settings_changed.emit(iface_data)
	if _event_bus:
		_event_bus.emit("interface_settings_changed", iface_data)

	settings_applied.emit()
	print("[SettingsManager] All settings applied.")

func is_fullscreen() -> bool:
	if DisplayServer.get_name() != "headless":
		var cur_mode := DisplayServer.window_get_mode()
		if cur_mode == DisplayServer.WINDOW_MODE_FULLSCREEN or cur_mode == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN:
			return true
		elif cur_mode == DisplayServer.WINDOW_MODE_WINDOWED or cur_mode == DisplayServer.WINDOW_MODE_MAXIMIZED:
			return false
	return bool(get_setting("display", "fullscreen", false))

func is_exclusive_fullscreen() -> bool:
	if DisplayServer.get_name() != "headless":
		return DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN
	return bool(get_setting("display", "fullscreen", false)) and bool(get_setting("display", "exclusive_fullscreen", false))

func set_exclusive_fullscreen(enabled: bool, update_stored: bool = true) -> void:
	if update_stored:
		set_setting("display", "exclusive_fullscreen", enabled, true)
	if is_fullscreen():
		set_fullscreen(true, false, enabled)

func toggle_fullscreen() -> bool:
	var is_fs: bool = is_fullscreen()
	var new_mode := not is_fs
	set_fullscreen(new_mode, true)
	if not new_mode:
		var rw: int = int(get_setting("display", "resolution_width", 1280))
		var rh: int = int(get_setting("display", "resolution_height", 720))
		set_resolution(rw, rh, false)
	return new_mode

func set_fullscreen(enabled: bool, update_stored: bool = true, exclusive: Variant = null) -> void:
	var use_exclusive: bool
	if exclusive != null:
		use_exclusive = bool(exclusive)
	else:
		use_exclusive = bool(get_setting("display", "exclusive_fullscreen", false))

	if enabled:
		if use_exclusive:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN)
		else:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)

	if update_stored:
		set_setting("display", "fullscreen", enabled, true)

func get_resolution_preset_index(width: int, height: int) -> int:
	for i in range(RESOLUTION_PRESETS.size()):
		if RESOLUTION_PRESETS[i].x == width and RESOLUTION_PRESETS[i].y == height:
			return i
	return -1

func get_resolution_presets() -> Array[Vector2i]:
	return RESOLUTION_PRESETS.duplicate()

func set_resolution(width: int, height: int, update_stored: bool = true) -> void:
	width = clampi(width, 640, 15360)
	height = clampi(height, 360, 8640)

	var current_mode := DisplayServer.window_get_mode()
	var in_fs := is_fullscreen() or current_mode == DisplayServer.WINDOW_MODE_FULLSCREEN or current_mode == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN
	if in_fs:
		# If fullscreen, switch to windowed to apply resolution
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		set_setting("display", "fullscreen", false, true)

	var new_size := Vector2i(width, height)
	DisplayServer.window_set_size(new_size)

	# Center on primary screen if possible
	var screen_size := DisplayServer.screen_get_size()
	if screen_size.x > 0 and screen_size.y > 0:
		var centered_pos := Vector2i(
			maxi(0, (screen_size.x - width) / 2),
			maxi(0, (screen_size.y - height) / 2)
		)
		DisplayServer.window_set_position(centered_pos)

	if update_stored:
		var matched_idx := get_resolution_preset_index(width, height)
		if matched_idx != -1:
			set_setting("display", "resolution_index", matched_idx, false)
		set_setting("display", "resolution_width", width, false)
		set_setting("display", "resolution_height", height, true)

func set_resolution_by_index(index: int) -> void:
	if index >= 0 and index < RESOLUTION_PRESETS.size():
		var res: Vector2i = RESOLUTION_PRESETS[index]
		set_setting("display", "resolution_index", index, false)
		set_resolution(res.x, res.y, true)
	else:
		push_warning("[SettingsManager] Invalid resolution preset index: %d (range: 0 to %d)" % [index, RESOLUTION_PRESETS.size() - 1])

func set_vsync(enabled: bool, update_stored: bool = true) -> void:
	var mode := DisplayServer.VSYNC_ENABLED if enabled else DisplayServer.VSYNC_DISABLED
	DisplayServer.window_set_vsync_mode(mode)
	if update_stored:
		set_setting("display", "vsync", enabled, true)

func set_fps_limit(limit: int, update_stored: bool = true) -> void:
	var clamped := clampi(limit, 0, 1000)
	Engine.max_fps = clamped
	if update_stored:
		set_setting("display", "fps_limit", clamped, true)

func get_viewport_scaling_settings() -> Dictionary:
	var win := get_tree().root if is_inside_tree() and get_tree() else null
	if win:
		return {
			"content_scale_size": win.content_scale_size,
			"content_scale_mode": win.content_scale_mode,
			"content_scale_aspect": win.content_scale_aspect,
			"content_scale_factor": win.content_scale_factor
		}
	return {
		"content_scale_size": Vector2i(1280, 720),
		"content_scale_mode": 1,
		"content_scale_aspect": 4,
		"content_scale_factor": 1.0
	}

func set_viewport_scale_factor(factor: float, update_stored: bool = true) -> void:
	if is_nan(factor) or is_inf(factor) or factor <= 0.0:
		factor = 1.0
	var clamped := clampf(factor, 0.5, 3.0)
	var win := get_tree().root if is_inside_tree() and get_tree() else null
	if win:
		win.content_scale_factor = clamped
	if update_stored:
		set_setting("display", "scale_factor", clamped, true)

func get_viewport_scale_factor() -> float:
	return float(get_setting("display", "scale_factor", 1.0))

func set_mouse_sensitivity(val: float) -> void:
	var clamped := clampf(val, 0.0001, 0.1)
	set_setting("controls", "mouse_sensitivity", clamped, true)

func set_invert_y(enabled: bool) -> void:
	set_setting("controls", "invert_y", enabled, true)

func set_move_speed(val: float) -> void:
	var clamped := clampf(val, 1.0, 500.0)
	set_setting("controls", "move_speed", clamped, true)

func set_sprint_speed(val: float) -> void:
	var clamped := clampf(val, 1.0, 1000.0)
	set_setting("controls", "sprint_speed", clamped, true)

# ----------------------------------------------------
# InputMap Control Rebinding Serialization & Restoration
# ----------------------------------------------------

func apply_input_bindings() -> void:
	var bindings_val = get_setting("controls", "bindings", null)
	var bindings: Dictionary = bindings_val if (bindings_val is Dictionary) else DEFAULT_KEYBINDINGS.duplicate()
	for action in bindings.keys():
		var kc = bindings[action]
		if (kc is int or kc is float) and not (kc is bool):
			_bind_action_key(str(action), int(kc))

func _bind_action_key(action: String, keycode: int) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	else:
		InputMap.action_erase_events(action)

	if keycode > 0:
		var ev := InputEventKey.new()
		ev.physical_keycode = keycode as Key
		ev.keycode = keycode as Key
		InputMap.action_add_event(action, ev)
		if action == "toggle_fullscreen":
			var alt_enter := InputEventKey.new()
			alt_enter.keycode = KEY_ENTER
			alt_enter.alt_pressed = true
			InputMap.action_add_event(action, alt_enter)

func get_binding(action: String, default_keycode: int = KEY_NONE) -> int:
	var bindings_val = get_setting("controls", "bindings", null)
	if bindings_val is Dictionary and (bindings_val as Dictionary).has(action):
		return int((bindings_val as Dictionary)[action])
	if DEFAULT_KEYBINDINGS.has(action):
		return int(DEFAULT_KEYBINDINGS[action])
	return default_keycode

func set_binding(action: String, keycode: int, auto_save: bool = true) -> void:
	var bindings_val = get_setting("controls", "bindings", null)
	var current_bindings: Dictionary = (bindings_val.duplicate() if bindings_val is Dictionary else DEFAULT_KEYBINDINGS.duplicate())
	current_bindings[action] = keycode
	_bind_action_key(action, keycode)
	set_setting("controls", "bindings", current_bindings, auto_save)

func get_all_bindings() -> Dictionary:
	var bindings_val = get_setting("controls", "bindings", null)
	if bindings_val is Dictionary:
		return (bindings_val as Dictionary).duplicate()
	return DEFAULT_KEYBINDINGS.duplicate()

func reset_bindings_to_defaults(auto_save: bool = true) -> void:
	set_setting("controls", "bindings", DEFAULT_KEYBINDINGS.duplicate(), auto_save)
	apply_input_bindings()

# ----------------------------------------------------
# Audio & Agent Config
# ----------------------------------------------------

func ensure_audio_buses() -> void:
	var required_buses := ["Master", "Music", "SFX", "UI"]
	for bus_name in required_buses:
		if bus_name == "Master":
			continue
		if AudioServer.get_bus_index(bus_name) < 0:
			var idx := AudioServer.bus_count
			AudioServer.add_bus(idx)
			AudioServer.set_bus_name(idx, bus_name)
			AudioServer.set_bus_send(idx, "Master")

func _get_bus_setting_key(bus_name: String) -> String:
	if AUDIO_BUS_SETTINGS_MAP.has(bus_name):
		return AUDIO_BUS_SETTINGS_MAP[bus_name]
	return bus_name.to_lower() + "_volume"

func set_bus_volume(bus_name: String, linear_vol: float, update_stored: bool = true) -> void:
	if is_nan(linear_vol) or is_inf(linear_vol):
		linear_vol = 0.0
	var clamped := clampf(linear_vol, 0.0, 1.0)
	var bus_idx := AudioServer.get_bus_index(bus_name)
	if bus_idx >= 0:
		var is_mute := clamped <= 0.0001
		if bus_name == "UI" and not bool(get_setting("audio", "ui_sound_enabled", true)):
			is_mute = true
		AudioServer.set_bus_mute(bus_idx, is_mute)
		var db := -80.0 if clamped <= 0.0001 else linear_to_db(clamped)
		AudioServer.set_bus_volume_db(bus_idx, db)
	else:
		push_warning("[SettingsManager] Audio bus '%s' not found." % bus_name)

	var setting_key := _get_bus_setting_key(bus_name)
	if update_stored:
		set_setting("audio", setting_key, clamped, true)
	else:
		if not _settings.has("audio") or not (_settings["audio"] is Dictionary):
			_settings["audio"] = {}
		_settings["audio"][setting_key] = clamped

func get_bus_volume(bus_name: String, default_val: float = 0.8) -> float:
	var setting_key := _get_bus_setting_key(bus_name)
	return float(get_setting("audio", setting_key, default_val))

func get_bus_volume_db(bus_name: String) -> float:
	var bus_idx := AudioServer.get_bus_index(bus_name)
	if bus_idx >= 0:
		return AudioServer.get_bus_volume_db(bus_idx)
	push_warning("[SettingsManager] Audio bus '%s' not found." % bus_name)
	return -80.0

func is_bus_muted(bus_name: String) -> bool:
	var bus_idx := AudioServer.get_bus_index(bus_name)
	if bus_idx >= 0:
		return AudioServer.is_bus_mute(bus_idx)
	push_warning("[SettingsManager] Audio bus '%s' not found." % bus_name)
	return true

func set_bus_mute(bus_name: String, muted: bool) -> void:
	var bus_idx := AudioServer.get_bus_index(bus_name)
	if bus_idx >= 0:
		AudioServer.set_bus_mute(bus_idx, muted)
	else:
		push_warning("[SettingsManager] Audio bus '%s' not found." % bus_name)

func set_master_volume(linear_vol: float, update_stored: bool = true) -> void:
	set_bus_volume("Master", linear_vol, update_stored)

func set_music_volume(linear_vol: float, update_stored: bool = true) -> void:
	set_bus_volume("Music", linear_vol, update_stored)

func set_sfx_volume(linear_vol: float, update_stored: bool = true) -> void:
	set_bus_volume("SFX", linear_vol, update_stored)

func set_ui_volume(linear_vol: float, update_stored: bool = true) -> void:
	set_bus_volume("UI", linear_vol, update_stored)

func set_ui_sound_enabled(enabled: bool, update_stored: bool = true) -> void:
	if update_stored:
		set_setting("audio", "ui_sound_enabled", enabled, true)
	else:
		if not _settings.has("audio") or not (_settings["audio"] is Dictionary):
			_settings["audio"] = {}
		_settings["audio"]["ui_sound_enabled"] = enabled

	var bus_idx := AudioServer.get_bus_index("UI")
	if bus_idx >= 0:
		var ui_vol: float = float(get_setting("audio", "ui_volume", 0.8))
		var is_mute := (not enabled) or (ui_vol <= 0.0001)
		AudioServer.set_bus_mute(bus_idx, is_mute)
		var db := -80.0 if ui_vol <= 0.0001 else linear_to_db(ui_vol)
		AudioServer.set_bus_volume_db(bus_idx, db)

func is_ui_sound_enabled() -> bool:
	return bool(get_setting("audio", "ui_sound_enabled", true))

func set_agent_config(provider: String, model: String, api_key: String) -> void:
	set_setting("agent", "provider", provider, false)
	set_setting("agent", "model", model, false)
	set_setting("agent", "api_key", api_key, false)
	var agent_data: Dictionary = get_category("agent")
	var api_keys: Dictionary = agent_data.get("api_keys", {}).duplicate()
	var models: Dictionary = agent_data.get("models", {}).duplicate()
	api_keys[provider] = api_key
	models[provider] = model
	set_setting("agent", "api_keys", api_keys, false)
	set_setting("agent", "models", models, true)

func get_agent_api_key(provider_name: String) -> String:
	var agent_data: Dictionary = get_category("agent")
	var api_keys: Dictionary = agent_data.get("api_keys", {})
	var key_val: String = str(api_keys.get(provider_name, "")).strip_edges()
	if not key_val.is_empty():
		return key_val

	if str(agent_data.get("provider", "")) == provider_name:
		var flat_key: String = str(agent_data.get("api_key", "")).strip_edges()
		if not flat_key.is_empty():
			return flat_key

	match provider_name:
		"gemini":
			return OS.get_environment("GEMINI_API_KEY").strip_edges()
		"openai":
			return OS.get_environment("OPENAI_API_KEY").strip_edges()
		"openrouter":
			return OS.get_environment("OPENROUTER_API_KEY").strip_edges()
		"deepseek":
			return OS.get_environment("DEEPSEEK_API_KEY").strip_edges()
		"groq":
			return OS.get_environment("GROQ_API_KEY").strip_edges()
		"anthropic":
			return OS.get_environment("ANTHROPIC_API_KEY").strip_edges()
		"mistral":
			return OS.get_environment("MISTRAL_API_KEY").strip_edges()
		"custom":
			return OS.get_environment("CUSTOM_API_KEY").strip_edges()
	return ""

func set_agent_api_key(provider_name: String, key_value: String) -> void:
	var agent_data: Dictionary = get_category("agent")
	var api_keys: Dictionary = agent_data.get("api_keys", {}).duplicate()
	api_keys[provider_name] = key_value
	set_setting("agent", "api_keys", api_keys, false)
	if get_agent_provider() == provider_name:
		set_setting("agent", "api_key", key_value, false)
	save_settings()

func get_agent_model(provider_name: String) -> String:
	var agent_data: Dictionary = get_category("agent")
	var models: Dictionary = agent_data.get("models", {})
	if models.has(provider_name) and not str(models[provider_name]).strip_edges().is_empty():
		return str(models[provider_name]).strip_edges()
	var def_models: Dictionary = DEFAULT_SETTINGS["agent"]["models"]
	if def_models.has(provider_name):
		return str(def_models[provider_name])
	return str(agent_data.get("model", ""))

func set_agent_model(provider_name: String, model_name: String) -> void:
	var agent_data: Dictionary = get_category("agent")
	var models: Dictionary = agent_data.get("models", {}).duplicate()
	models[provider_name] = model_name
	set_setting("agent", "models", models, false)
	if get_agent_provider() == provider_name:
		set_setting("agent", "model", model_name, false)
	save_settings()

func get_agent_provider() -> String:
	return str(get_setting("agent", "provider", "local_embedded"))

func set_agent_provider(provider_name: String) -> void:
	set_setting("agent", "provider", provider_name, false)
	var mod_name := get_agent_model(provider_name)
	if not mod_name.is_empty():
		set_setting("agent", "model", mod_name, false)
	var key_val := get_agent_api_key(provider_name)
	set_setting("agent", "api_key", key_val, false)
	save_settings()

func is_auto_fallback_to_local_enabled() -> bool:
	return bool(get_setting("agent", "auto_fallback_to_local", true))

func set_auto_fallback_to_local(enabled: bool) -> void:
	set_setting("agent", "auto_fallback_to_local", enabled, true)

func get_active_provider_info() -> Dictionary:
	var prov: String = get_agent_provider()
	return {
		"provider": prov,
		"model": get_agent_model(prov),
		"api_key": get_agent_api_key(prov),
		"auto_fallback_to_local": is_auto_fallback_to_local_enabled(),
		"custom_base_url": str(get_setting("agent", "custom_base_url", "")),
		"custom_model": str(get_setting("agent", "custom_model", "")),
		"local_model_path": str(get_setting("agent", "local_model_path", "")),
		"local_server_port": int(get_setting("agent", "local_server_port", 8080)),
		"local_server_threads": int(get_setting("agent", "local_server_threads", 4))
	}

func get_interface_settings() -> Dictionary:
	return get_category("interface")

func set_interface_theme(t_name: String) -> void:
	set_setting("interface", "theme", t_name, true)

func set_glass_opacity(opacity: float) -> void:
	set_setting("interface", "glass_opacity", opacity, true)

func set_led_intensity(intensity: float) -> void:
	set_setting("interface", "led_intensity", intensity, true)

func set_prompt_bar_autoclose(enabled: bool) -> void:
	set_setting("interface", "prompt_bar_autoclose", enabled, true)

func get_network_settings() -> Dictionary:
	return get_category("network")

func set_network_setting(key: String, value: Variant) -> void:
	set_setting("network", key, value, true)

