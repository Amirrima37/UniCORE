class_name TopBar
extends Control

const DetroitOrbScript = preload("res://ui/led_indicator/detroit_orb.gd")
const SettingsManagerScript = preload("res://core/settings_manager.gd")
const SpaceManagerScript = preload("res://core/space_manager.gd")

## Верхняя киберпанель интерфейса UniCORE (HUD Top Bar)
## В стиле "Detroit: Become Human": матовое стекло, неоновые акценты, LED-орб,
## быстрый доступ к меню, пространствам, настройкам и полноэкранному режиму.

signal menu_button_pressed(target_tab: String)
signal prompt_toggle_pressed
signal log_button_pressed
signal fullscreen_toggle_pressed

@onready var panel_container: PanelContainer = $PanelContainer
@onready var detroit_orb: Control = $PanelContainer/MarginContainer/HBoxContainer/LeftBox/DetroitOrb
@onready var space_badge_btn: Button = $PanelContainer/MarginContainer/HBoxContainer/LeftBox/SpaceBadgeButton
@onready var status_ticker_label: Label = $PanelContainer/MarginContainer/HBoxContainer/LeftBox/StatusTicker
@onready var fps_label: Label = $PanelContainer/MarginContainer/HBoxContainer/RightBox/FpsLabel

@onready var spaces_btn: Button = $PanelContainer/MarginContainer/HBoxContainer/RightBox/SpacesButton
@onready var settings_btn: Button = $PanelContainer/MarginContainer/HBoxContainer/RightBox/SettingsButton
@onready var prompt_btn: Button = $PanelContainer/MarginContainer/HBoxContainer/RightBox/PromptButton
@onready var log_btn: Button = $PanelContainer/MarginContainer/HBoxContainer/RightBox/LogButton
@onready var fullscreen_btn: Button = $PanelContainer/MarginContainer/HBoxContainer/RightBox/FullscreenButton
@onready var menu_btn: Button = $PanelContainer/MarginContainer/HBoxContainer/RightBox/MenuButton

var _settings_manager: Node
var _space_manager: Node
var _agent_brain: Node
var _event_bus: Node

func _ready() -> void:
	_apply_cyber_styling()

	spaces_btn.pressed.connect(func(): menu_button_pressed.emit("spaces"))
	settings_btn.pressed.connect(func(): menu_button_pressed.emit("settings"))
	prompt_btn.pressed.connect(func(): prompt_toggle_pressed.emit())
	log_btn.pressed.connect(func(): log_button_pressed.emit())
	fullscreen_btn.pressed.connect(func(): fullscreen_toggle_pressed.emit())
	menu_btn.pressed.connect(func(): menu_button_pressed.emit("menu"))
	space_badge_btn.pressed.connect(func(): menu_button_pressed.emit("spaces"))

func _process(_delta: float) -> void:
	if fps_label:
		fps_label.text = "%d FPS" % Engine.get_frames_per_second()

func setup(settings_mgr: Node, space_mgr: Node, brain: Node, event_bus: Node) -> void:
	_settings_manager = settings_mgr
	_space_manager = space_mgr
	_agent_brain = brain
	_event_bus = event_bus

	if _space_manager:
		_space_manager.space_loaded.connect(_on_space_loaded)
		_space_manager.space_saved.connect(_on_space_saved)
		_space_manager.space_error.connect(_on_space_error)
		_update_space_badge(_space_manager.current_space_name)

	if _settings_manager:
		_settings_manager.setting_changed.connect(_on_setting_changed)
		var is_fs: bool = _settings_manager.get_setting("display", "fullscreen", false)
		fullscreen_btn.text = "ОКНО [F11]" if is_fs else "ЭКРАН [F11]"

	if _agent_brain:
		_agent_brain.request_started.connect(func(_p):
			detroit_orb.set_processing("Генерация модуля...")
			status_ticker_label.text = "// AGENT: GENERATING MODULE..."
			status_ticker_label.modulate = CyberTheme.COLOR_AMBER_LED
		)
		_agent_brain.request_completed.connect(func(mod_id):
			detroit_orb.flash_success("Модуль смонтирован!")
			status_ticker_label.text = "// MODULE MOUNTED: %s" % mod_id.to_upper()
			status_ticker_label.modulate = CyberTheme.COLOR_SUCCESS_LED
		)
		_agent_brain.request_failed.connect(func(err):
			detroit_orb.flash_error("Сбой агента")
			status_ticker_label.text = "// ERROR: %s" % err
			status_ticker_label.modulate = CyberTheme.COLOR_RED_LED
		)

	if _event_bus:
		_event_bus.subscribe("space_saved", func(payload):
			detroit_orb.flash_success("Пространство сохранено!")
			var sname: String = payload.get("name", "Space")
			status_ticker_label.text = "// SAVED: %s" % sname.to_upper()
			status_ticker_label.modulate = CyberTheme.COLOR_SUCCESS_LED
		)
		_event_bus.subscribe("space_loaded", func(payload):
			var sname: String = payload.get("name", "Space")
			_update_space_badge(sname)
			detroit_orb.flash_success("Пространство загружено")
			status_ticker_label.text = "// SPACE READY: %s" % sname.to_upper()
			status_ticker_label.modulate = CyberTheme.COLOR_TEXT_CYAN
		)
		_event_bus.subscribe("space_cloned", func(payload):
			var sname: String = payload.get("name", "Clone")
			detroit_orb.flash_success("Пространство клонировано")
			status_ticker_label.text = "// CLONED: %s" % sname.to_upper()
			status_ticker_label.modulate = CyberTheme.COLOR_TEXT_CYAN
		)
		_event_bus.subscribe("module_loaded", func(payload):
			var mid: String = payload.get("id", "Module")
			detroit_orb.flash_success("Модуль активен")
			status_ticker_label.text = "// MODULE ACTIVE: %s" % mid.to_upper()
			status_ticker_label.modulate = CyberTheme.COLOR_SUCCESS_LED
		)
		_event_bus.subscribe("module_unloaded", func(payload):
			var mid: String = payload.get("id", "Module")
			status_ticker_label.text = "// MODULE UNLOADED: %s" % mid.to_upper()
			status_ticker_label.modulate = CyberTheme.COLOR_TEXT_MUTED
		)

func _on_space_loaded(data: Dictionary) -> void:
	var sname: String = data.get("name", "Unnamed Space")
	_update_space_badge(sname)
	detroit_orb.flash_success("Пространство загружено")
	status_ticker_label.text = "// SPACE READY: %s" % sname.to_upper()
	status_ticker_label.modulate = CyberTheme.COLOR_TEXT_CYAN

func _on_space_saved(sname: String, _path: String) -> void:
	_update_space_badge(sname)
	detroit_orb.flash_success("Сохранено")
	status_ticker_label.text = "// SAVED: %s" % sname.to_upper()
	status_ticker_label.modulate = CyberTheme.COLOR_SUCCESS_LED

func _update_space_badge(sname: String) -> void:
	if space_badge_btn:
		space_badge_btn.text = " ПРОСТРАНСТВО: %s " % sname.to_upper()

func _on_space_error(msg: String) -> void:
	detroit_orb.flash_error("Сбой пространства")
	status_ticker_label.text = "// ERROR: %s" % msg.to_upper()
	status_ticker_label.modulate = CyberTheme.COLOR_RED_LED

func _on_setting_changed(category: String, key: String, value: Variant) -> void:
	if category == "display" and key == "fullscreen":
		var is_fs := bool(value)
		if fullscreen_btn:
			fullscreen_btn.text = "ОКНО [F11]" if is_fs else "ЭКРАН [F11]"
	elif category == "interface":
		_apply_cyber_styling()

func _apply_cyber_styling() -> void:
	var is_white := CyberTheme.is_white_theme()
	# Стиль матового стекла с неоновой нижней линией (Cyber HUD Glass)
	var top_style := StyleBoxFlat.new()
	top_style.bg_color = CyberTheme.get_default_glass_bg()
	top_style.border_width_bottom = 1
	top_style.border_color = CyberTheme.COLOR_ELECTRIC_BLUE if is_white else Color(0.0, 0.85, 1.0, 0.65)
	top_style.shadow_color = Color(top_style.border_color.r, top_style.border_color.g, top_style.border_color.b, clampf(0.2 * CyberTheme.get_led_intensity(), 0.05, 0.8))
	top_style.shadow_size = int(round(4 * CyberTheme.get_led_intensity()))
	top_style.set_content_margin_all(6)
	top_style.content_margin_left = 14
	top_style.content_margin_right = 14
	panel_container.add_theme_stylebox_override("panel", top_style)

	# Стили кнопок
	var btn_normal: StyleBoxFlat
	var btn_hover: StyleBoxFlat
	var btn_pressed: StyleBoxFlat
	var btn_focus := StyleBoxEmpty.new()

	if is_white:
		btn_normal = CyberTheme.create_cyber_button_style(Color(0.88, 0.93, 0.98, CyberTheme.get_glass_opacity()), Color(0.2, 0.6, 0.95, 0.5), 1, 3)
		btn_hover = CyberTheme.create_cyber_button_style(Color(0.8, 0.9, 0.98, 0.95), CyberTheme.COLOR_ELECTRIC_BLUE, 1, 3)
		btn_pressed = CyberTheme.create_cyber_button_style(Color(0.2, 0.65, 0.95, 0.95), CyberTheme.COLOR_CYAN_GLOW, 2, 3)
	else:
		btn_normal = CyberTheme.create_cyber_button_style(Color(0.05, 0.1, 0.18, 0.7), Color(0.0, 0.75, 1.0, 0.35), 1, 3)
		btn_hover = CyberTheme.create_cyber_button_style(Color(0.08, 0.18, 0.32, 0.95), CyberTheme.COLOR_CYAN_GLOW, 1, 3)
		btn_pressed = CyberTheme.create_cyber_button_style(Color(0.0, 0.45, 0.75, 0.95), CyberTheme.COLOR_CYAN_GLOW, 2, 3)

	for btn in [spaces_btn, settings_btn, prompt_btn, log_btn, fullscreen_btn, menu_btn]:
		if is_instance_valid(btn):
			btn.add_theme_stylebox_override("normal", btn_normal)
			btn.add_theme_stylebox_override("hover", btn_hover)
			btn.add_theme_stylebox_override("pressed", btn_pressed)
			btn.add_theme_stylebox_override("focus", btn_focus)
			btn.add_theme_color_override("font_color", CyberTheme.COLOR_TEXT_DARK if is_white else CyberTheme.COLOR_TEXT_PRIMARY)
			btn.add_theme_color_override("font_hover_color", CyberTheme.COLOR_ELECTRIC_BLUE if is_white else CyberTheme.COLOR_CYAN_GLOW)
			btn.add_theme_font_size_override("font_size", 12)

	# Подсказки (Tooltips) для быстрых кнопок
	spaces_btn.tooltip_text = "Управление Пространствами (создание, загрузка, сохранение)"
	settings_btn.tooltip_text = "Системные Настройки (графика, управление, ИИ-агент)"
	prompt_btn.tooltip_text = "Командная строка Агента [Tab / ~]"
	log_btn.tooltip_text = "Журнал и панель диагностики CyberLife [F10]"
	fullscreen_btn.tooltip_text = "Полноэкранный режим [F11]"
	menu_btn.tooltip_text = "Системное меню UniCORE [Esc]"

	# Бейдж пространства
	var badge_style := CyberTheme.create_cyber_button_style(
		Color(0.82, 0.9, 0.98, 0.9) if is_white else Color(0.02, 0.14, 0.24, 0.85),
		CyberTheme.COLOR_ELECTRIC_BLUE if is_white else Color(0.0, 0.85, 1.0, 0.6),
		1,
		3
	)
	if is_instance_valid(space_badge_btn):
		space_badge_btn.add_theme_stylebox_override("normal", badge_style)
		space_badge_btn.add_theme_stylebox_override("hover", btn_hover)
		space_badge_btn.add_theme_stylebox_override("pressed", btn_pressed)
		space_badge_btn.add_theme_stylebox_override("focus", btn_focus)
		space_badge_btn.add_theme_color_override("font_color", CyberTheme.COLOR_ELECTRIC_BLUE if is_white else CyberTheme.COLOR_CYAN_GLOW)
		space_badge_btn.add_theme_font_size_override("font_size", 12)
		space_badge_btn.tooltip_text = "Текущее активное пространство (кликните для выбора)"
