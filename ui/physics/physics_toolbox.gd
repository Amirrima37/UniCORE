class_name PhysicsToolbox
extends "res://ui/theme/glass_panel.gd"

## Палитра Научных Инструментов Физической Платформы (PhysicsToolbox)
## Стиль: Detroit Liquid Glass
## Позволяет переключать активный физический инструментарий (Гравитация, Термодинамика, Ядерная физика, Кванты, Зонды)
## Поддерживает горячие клавиши (Q, 1, 2, 3, 4, 5) и цветовую кодировку спектра.

signal tool_changed(tool_id: String)

@onready var btn_select: Button = $MarginContainer/VBoxContainer/BtnSelect
@onready var btn_gravity: Button = $MarginContainer/VBoxContainer/BtnGravity
@onready var btn_thermodynamics: Button = $MarginContainer/VBoxContainer/BtnThermodynamics
@onready var btn_nuclear: Button = $MarginContainer/VBoxContainer/BtnNuclear
@onready var btn_quantum: Button = $MarginContainer/VBoxContainer/BtnQuantum
@onready var btn_sensor: Button = $MarginContainer/VBoxContainer/BtnSensor

var _event_bus: Node = null
var _current_tool: String = "select"
var _button_group: ButtonGroup = ButtonGroup.new()
var _tool_buttons: Dictionary = {} # tool_id -> Button
var _tool_colors: Dictionary = {}  # tool_id -> Color

func _ready() -> void:
	super._ready()
	custom_accent_color = DesignTokens.COLOR_ACCENT_PRISM_CYAN
	panel_corner_radius = 12.0
	blur_strength = 2.5
	bevel_width = 16.0

	_setup_tools()
	_apply_active_style("select")

func setup(event_bus: Node) -> void:
	_event_bus = event_bus
	if _event_bus and _event_bus.has_method("subscribe"):
		_event_bus.subscribe("physics_tool_selected", _on_external_tool_selected)

func _setup_tools() -> void:
	_tool_buttons = {
		"select": btn_select,
		"gravity": btn_gravity,
		"thermodynamics": btn_thermodynamics,
		"nuclear": btn_nuclear,
		"quantum": btn_quantum,
		"sensor": btn_sensor
	}

	_tool_colors = {
		"select": Color(1.0, 1.0, 1.0, 1.0),
		"gravity": DesignTokens.COLOR_ACCENT_SPECTRAL_AMBER,
		"thermodynamics": DesignTokens.COLOR_ACCENT_PRISM_CYAN,
		"nuclear": DesignTokens.COLOR_ACCENT_EMERALD_FLUX,
		"quantum": DesignTokens.COLOR_ACCENT_ELECTRIC_BLUE,
		"sensor": DesignTokens.COLOR_ACCENT_CRIMSON_VALVE
	}

	for tool_id in _tool_buttons.keys():
		var btn: Button = _tool_buttons[tool_id]
		btn.button_group = _button_group
		btn.toggle_mode = true
		btn.pressed.connect(func() -> void: _on_tool_button_pressed(tool_id))

	btn_select.button_pressed = true

func _on_tool_button_pressed(tool_id: String) -> void:
	if _current_tool == tool_id and _tool_buttons[tool_id].button_pressed:
		return
	_current_tool = tool_id
	_apply_active_style(tool_id)
	tool_changed.emit(tool_id)

	if _event_bus:
		if _event_bus.has_method("publish"):
			_event_bus.publish("physics_tool_selected", {"tool_id": tool_id})
		elif _event_bus.has_method("emit"):
			_event_bus.emit("physics_tool_selected", {"tool_id": tool_id})

func _on_external_tool_selected(payload: Dictionary) -> void:
	var tool_id: String = str(payload.get("tool_id", ""))
	if tool_id.is_empty() or not _tool_buttons.has(tool_id):
		return
	if _current_tool != tool_id:
		_current_tool = tool_id
		var btn: Button = _tool_buttons[tool_id]
		btn.set_pressed_no_signal(true)
		_apply_active_style(tool_id)
		tool_changed.emit(tool_id)

func _apply_active_style(active_tool_id: String) -> void:
	for tool_id in _tool_buttons.keys():
		var btn: Button = _tool_buttons[tool_id]
		var col: Color = _tool_colors.get(tool_id, Color.WHITE)
		if tool_id == active_tool_id:
			btn.modulate = col
			btn.self_modulate = Color(1.3, 1.3, 1.3, 1.0) # subtle neon bloom
		else:
			btn.modulate = Color(0.7, 0.75, 0.8, 0.6)
			btn.self_modulate = Color(1.0, 1.0, 1.0, 1.0)

func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.is_pressed() or event.is_echo():
		return

	# Если фокус находится на поле ввода текста — не перехватываем горячие клавиши
	var focus_owner: Control = get_viewport().gui_get_focus_owner()
	if focus_owner is LineEdit or focus_owner is TextEdit:
		return

	var key_event := event as InputEventKey
	match key_event.keycode:
		KEY_Q:
			_select_tool_by_id("select")
			get_viewport().set_input_as_handled()
		KEY_1:
			_select_tool_by_id("gravity")
			get_viewport().set_input_as_handled()
		KEY_2:
			_select_tool_by_id("thermodynamics")
			get_viewport().set_input_as_handled()
		KEY_3:
			_select_tool_by_id("nuclear")
			get_viewport().set_input_as_handled()
		KEY_4:
			_select_tool_by_id("quantum")
			get_viewport().set_input_as_handled()
		KEY_5:
			_select_tool_by_id("sensor")
			get_viewport().set_input_as_handled()

func _select_tool_by_id(tool_id: String) -> void:
	if _tool_buttons.has(tool_id):
		var btn: Button = _tool_buttons[tool_id]
		btn.button_pressed = true
		_on_tool_button_pressed(tool_id)
