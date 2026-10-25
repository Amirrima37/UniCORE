class_name ModuleToolbar
extends Control

## Панель инструментов активных модулей (Module Toolbar) в стиле "Detroit: Become Human"
## Отображается внизу экрана, показывает все загруженные модули.
## Позволяет переключать состояние модулей и отображает LED-индикацию.

signal module_toggled(module_id: String, enabled: bool)
signal module_selected(module_id: String)

const CyberTheme = preload("res://ui/theme/cyber_theme.gd")

var _module_manager: ModuleManager
var _event_bus: EventBus

@onready var toolbar_panel: PanelContainer = $ToolbarPanel
@onready var modules_container: HBoxContainer = $ToolbarPanel/MarginContainer/HBoxContainer/ScrollContainer/ModulesContainer
@onready var title_label: Label = $ToolbarPanel/MarginContainer/HBoxContainer/TitleLabel
@onready var module_count_label: Label = $ToolbarPanel/MarginContainer/HBoxContainer/CountLabel

# Tracks button references by module_id
var _module_buttons: Dictionary = {}

func _ready() -> void:
	show()
	_apply_cyber_styling()

func _apply_cyber_styling() -> void:
	var is_white := CyberTheme.is_white_theme()
	var bar_style := StyleBoxFlat.new()
	bar_style.bg_color = CyberTheme.get_default_glass_bg()
	bar_style.border_width_top = 1
	bar_style.border_color = CyberTheme.COLOR_ELECTRIC_BLUE if is_white else Color(0.0, 0.85, 1.0, 0.5)
	bar_style.shadow_color = Color(bar_style.border_color.r, bar_style.border_color.g, bar_style.border_color.b, clampf(0.15 * CyberTheme.get_led_intensity(), 0.05, 0.8))
	bar_style.shadow_size = int(round(4 * CyberTheme.get_led_intensity()))
	bar_style.set_content_margin_all(4)
	bar_style.content_margin_left = 12
	bar_style.content_margin_right = 12
	toolbar_panel.add_theme_stylebox_override("panel", bar_style)

	title_label.add_theme_color_override("font_color", CyberTheme.COLOR_ELECTRIC_BLUE if is_white else CyberTheme.COLOR_CYAN_GLOW)
	module_count_label.add_theme_color_override("font_color", CyberTheme.get_text_muted_color())

func setup(module_manager: ModuleManager, event_bus: EventBus) -> void:
	_module_manager = module_manager
	_event_bus = event_bus

	# Connect to ModuleManager signals
	_module_manager.module_loaded.connect(_on_module_loaded)
	_module_manager.module_unloaded.connect(_on_module_unloaded)

	# Subscribe to module_toggled on event_bus
	if _event_bus:
		_event_bus.subscribe("module_toggled", _on_event_module_toggled)
		_event_bus.subscribe("interface_settings_changed", func(_d):
			_apply_cyber_styling()
			for mod_id in _module_buttons:
				var btn: Button = _module_buttons[mod_id]
				if is_instance_valid(btn):
					_style_module_button(btn, btn.button_pressed)
		)

	# Populate with already-loaded modules
	for mod_id in _module_manager.get_active_module_ids():
		var instance = _module_manager.get_module(mod_id)
		_on_module_loaded(mod_id, instance)

func _on_module_loaded(module_id: String, instance: Node) -> void:
	if _module_buttons.has(module_id):
		return # Already tracked

	var is_active := true
	if instance and is_instance_valid(instance):
		is_active = (instance.process_mode != Node.PROCESS_MODE_DISABLED)

	var btn := Button.new()
	btn.toggle_mode = true
	btn.button_pressed = is_active
	btn.custom_minimum_size = Vector2(140, 28)
	btn.focus_mode = Control.FOCUS_NONE
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

	# Try to get a display name from the module
	var display_name := module_id
	if instance and instance.has_method("get_module_name"):
		var mod_name = instance.get_module_name()
		if mod_name is String and not mod_name.is_empty():
			display_name = mod_name

	btn.text = ("● " if is_active else "○ ") + display_name
	btn.tooltip_text = "Модуль: %s\nКликните для переключения активности" % module_id
	btn.add_theme_font_size_override("font_size", 12)

	_style_module_button(btn, is_active)

	# Connect toggle signal
	btn.toggled.connect(func(pressed: bool):
		btn.text = ("● " if pressed else "○ ") + display_name
		_style_module_button(btn, pressed)
		_on_module_button_toggled(module_id, pressed)
	)

	modules_container.add_child(btn)
	_module_buttons[module_id] = btn
	_update_count_label()

func _on_event_module_toggled(payload: Dictionary) -> void:
	var mod_id: String = payload.get("id", "")
	var enabled: bool = payload.get("enabled", true)
	if _module_buttons.has(mod_id):
		var btn: Button = _module_buttons[mod_id]
		if is_instance_valid(btn):
			btn.set_pressed_no_signal(enabled)
			_style_module_button(btn, enabled)

func _style_module_button(btn: Button, active: bool) -> void:
	var is_white := CyberTheme.is_white_theme()
	if active:
		var on_style := CyberTheme.create_cyber_button_style(
			Color(0.85, 0.92, 0.98, 0.9) if is_white else Color(0.04, 0.14, 0.25, 0.88),
			CyberTheme.COLOR_ELECTRIC_BLUE if is_white else CyberTheme.COLOR_CYAN_GLOW,
			1,
			3
		)
		var hover_style := CyberTheme.create_cyber_button_style(
			Color(0.8, 0.9, 0.98, 0.95) if is_white else Color(0.08, 0.2, 0.35, 0.95),
			CyberTheme.COLOR_CYAN_GLOW,
			1,
			3
		)
		btn.add_theme_stylebox_override("normal", on_style)
		btn.add_theme_stylebox_override("hover", hover_style)
		btn.add_theme_stylebox_override("pressed", on_style)
		btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
		btn.add_theme_color_override("font_color", CyberTheme.COLOR_ELECTRIC_BLUE if is_white else CyberTheme.COLOR_CYAN_GLOW)
		btn.add_theme_color_override("font_hover_color", CyberTheme.COLOR_CYAN_GLOW if is_white else Color.WHITE)
	else:
		var off_style := CyberTheme.create_cyber_button_style(
			Color(0.92, 0.94, 0.97, 0.7) if is_white else Color(0.03, 0.05, 0.09, 0.6),
			Color(0.65, 0.75, 0.85, 0.5) if is_white else Color(0.25, 0.35, 0.45, 0.3),
			1,
			3
		)
		var off_hover := CyberTheme.create_cyber_button_style(
			Color(0.88, 0.92, 0.96, 0.85) if is_white else Color(0.06, 0.09, 0.15, 0.8),
			Color(0.4, 0.6, 0.85, 0.7) if is_white else Color(0.4, 0.55, 0.7, 0.5),
			1,
			3
		)
		btn.add_theme_stylebox_override("normal", off_style)
		btn.add_theme_stylebox_override("hover", off_hover)
		btn.add_theme_stylebox_override("pressed", off_style)
		btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
		btn.add_theme_color_override("font_color", CyberTheme.get_text_muted_color())

func _on_module_unloaded(module_id: String) -> void:
	if _module_buttons.has(module_id):
		var btn: Button = _module_buttons[module_id]
		if is_instance_valid(btn):
			btn.queue_free()
		_module_buttons.erase(module_id)
		_update_count_label()

func _on_module_button_toggled(module_id: String, enabled: bool) -> void:
	if not _module_manager:
		return

	var instance = _module_manager.get_module(module_id)
	if instance and is_instance_valid(instance):
		if enabled:
			instance.process_mode = Node.PROCESS_MODE_INHERIT
			if instance is Node3D or instance is CanvasItem:
				instance.show()
			print("[ModuleToolbar] Module '%s' enabled" % module_id)
		else:
			instance.process_mode = Node.PROCESS_MODE_DISABLED
			if instance is Node3D or instance is CanvasItem:
				instance.hide()
			print("[ModuleToolbar] Module '%s' disabled" % module_id)

	module_toggled.emit(module_id, enabled)

	if _event_bus:
		_event_bus.emit("module_toggled", {"id": module_id, "enabled": enabled})

func _update_count_label() -> void:
	if module_count_label:
		module_count_label.text = "[%d]" % _module_buttons.size()
