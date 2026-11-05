class_name PhysicsTimeBar
extends "res://ui/theme/glass_panel.gd"

## Панель Управления Временем Физической Платформы (PhysicsTimeBar)
## Стиль: Detroit Liquid Glass
## Управляет ходом времени симуляции: пауза/шаг, масштабирование (0.1x .. 100x), телеметрия времени t.

@onready var btn_play_pause: Button = $MarginContainer/HBoxContainer/BtnPlayPause
@onready var btn_step: Button = $MarginContainer/HBoxContainer/BtnStep
@onready var label_scale_text: Label = $MarginContainer/HBoxContainer/LabelScaleText
@onready var btn_scale_01: Button = $MarginContainer/HBoxContainer/BtnScale01
@onready var btn_scale_1: Button = $MarginContainer/HBoxContainer/BtnScale1
@onready var btn_scale_10: Button = $MarginContainer/HBoxContainer/BtnScale10
@onready var btn_scale_100: Button = $MarginContainer/HBoxContainer/BtnScale100
@onready var slider_time_scale: HSlider = $MarginContainer/HBoxContainer/SliderTimeScale
@onready var label_sim_time_icon: Label = $MarginContainer/HBoxContainer/LabelSimTimeIcon
@onready var label_sim_time: Label = $MarginContainer/HBoxContainer/LabelSimTime

var _event_bus: Node = null
var _current_scale: float = 1.0
var _is_paused: bool = false
var _scale_buttons: Array[Button] = []

func _ready() -> void:
	super._ready()
	mouse_filter = Control.MOUSE_FILTER_STOP
	custom_accent_color = DesignTokens.COLOR_ACCENT_PRISM_CYAN
	panel_corner_radius = 8.0
	blur_strength = 2.5
	bevel_width = 14.0

	_scale_buttons = [btn_scale_01, btn_scale_1, btn_scale_10, btn_scale_100]

	btn_play_pause.toggled.connect(_on_btn_play_pause_toggled)
	btn_step.pressed.connect(_on_btn_step_pressed)

	btn_scale_01.pressed.connect(func() -> void: _on_scale_button_pressed(0.1))
	btn_scale_1.pressed.connect(func() -> void: _on_scale_button_pressed(1.0))
	btn_scale_10.pressed.connect(func() -> void: _on_scale_button_pressed(10.0))
	btn_scale_100.pressed.connect(func() -> void: _on_scale_button_pressed(100.0))

	slider_time_scale.value_changed.connect(_on_slider_value_changed)

	_apply_fonts_and_styles()
	_highlight_active_scale_button(1.0)
	_update_play_pause_state(false)

func setup(event_bus: Node) -> void:
	_event_bus = event_bus
	if not _event_bus:
		return

	if _event_bus.has_method("subscribe"):
		_event_bus.subscribe("physics_time_tick", _on_time_tick)
		_event_bus.subscribe("physics_time_scale_changed", _on_scale_changed)
		_event_bus.subscribe("physics_simulation_paused", _on_paused)

func _publish(event_name: String, payload: Dictionary = {}) -> void:
	if not _event_bus:
		return
	if _event_bus.has_method("publish"):
		_event_bus.publish(event_name, payload)
	elif _event_bus.has_method("emit"):
		_event_bus.emit(event_name, payload)

func _on_btn_play_pause_toggled(button_pressed: bool) -> void:
	_is_paused = button_pressed
	_update_play_pause_state(_is_paused)
	_publish("physics_time_command", {"command": "set_paused", "value": _is_paused})

func _on_btn_step_pressed() -> void:
	_publish("physics_time_command", {"command": "step_once"})

func _on_scale_button_pressed(scale_val: float) -> void:
	_current_scale = scale_val
	slider_time_scale.set_value_no_signal(scale_val)
	_highlight_active_scale_button(scale_val)
	_publish("physics_time_command", {"command": "set_time_scale", "value": scale_val})

func _on_slider_value_changed(val: float) -> void:
	_current_scale = val
	_highlight_active_scale_button(val)
	_publish("physics_time_command", {"command": "set_time_scale", "value": val})

func _on_time_tick(payload: Dictionary) -> void:
	var sim_t: float = float(payload.get("sim_time", 0.0))
	label_sim_time.text = "t = %.3f s" % sim_t

func _on_scale_changed(payload: Dictionary) -> void:
	var scale_val: float = float(payload.get("time_scale", payload.get("scale", 1.0)))
	_current_scale = scale_val
	slider_time_scale.set_value_no_signal(scale_val)
	_highlight_active_scale_button(scale_val)

func _on_paused(payload: Dictionary) -> void:
	var paused_val: bool = bool(payload.get("is_paused", payload.get("paused", false)))
	if _is_paused != paused_val:
		_is_paused = paused_val
		btn_play_pause.set_pressed_no_signal(paused_val)
		_update_play_pause_state(paused_val)

func _update_play_pause_state(paused: bool) -> void:
	if paused:
		btn_play_pause.text = "▶ ПУСК"
		btn_play_pause.modulate = DesignTokens.COLOR_ACCENT_EMERALD_FLUX
	else:
		btn_play_pause.text = "⏸ ПАУЗА"
		btn_play_pause.modulate = DesignTokens.COLOR_ACCENT_PRISM_CYAN

func _highlight_active_scale_button(scale_val: float) -> void:
	for btn in _scale_buttons:
		if not is_instance_valid(btn):
			continue
		var matches: bool = false
		if btn == btn_scale_01 and is_equal_approx(scale_val, 0.1):
			matches = true
		elif btn == btn_scale_1 and is_equal_approx(scale_val, 1.0):
			matches = true
		elif btn == btn_scale_10 and is_equal_approx(scale_val, 10.0):
			matches = true
		elif btn == btn_scale_100 and is_equal_approx(scale_val, 100.0):
			matches = true

		if matches:
			btn.modulate = DesignTokens.COLOR_ACCENT_PRISM_CYAN
		else:
			btn.modulate = Color(0.8, 0.85, 0.9, 0.7)

func _apply_fonts_and_styles() -> void:
	var mono_font: Font = DesignTokens.get_font_mono()
	if mono_font:
		label_sim_time.add_theme_font_override("font", mono_font)
		label_scale_text.add_theme_font_override("font", mono_font)
	
	label_sim_time.add_theme_color_override("font_color", DesignTokens.COLOR_ACCENT_PRISM_CYAN)
	label_scale_text.add_theme_color_override("font_color", DesignTokens.COLOR_TEXT_SECONDARY)
	label_sim_time_icon.modulate = DesignTokens.COLOR_ACCENT_PRISM_CYAN
