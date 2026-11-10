class_name PhysicsPresetBar
extends "res://ui/theme/glass_panel.gd"

## Панель Быстрых Научных Экспериментов и Пресетов (PhysicsPresetBar)
## Стиль: Detroit Liquid Glass
## Обеспечивает мгновенный запуск канонических сценариев симуляции в 1 клик.

signal preset_selected(preset_id: String)

@onready var btn_solar: Button = $MarginContainer/HBoxContainer/BtnSolar
@onready var btn_figure8: Button = $MarginContainer/HBoxContainer/BtnFigure8
@onready var btn_cluster: Button = $MarginContainer/HBoxContainer/BtnCluster
@onready var btn_gas: Button = $MarginContainer/HBoxContainer/BtnGas
@onready var btn_nuclear: Button = $MarginContainer/HBoxContainer/BtnNuclear
@onready var btn_quantum: Button = $MarginContainer/HBoxContainer/BtnQuantum
@onready var btn_doubleslit: Button = $MarginContainer/HBoxContainer/BtnDoubleSlit

var _event_bus: Node = null
var _current_preset: String = "solar_system"
var _preset_buttons: Dictionary = {}
var _preset_tools: Dictionary = {
	"solar_system": "gravity",
	"figure8": "gravity",
	"cluster": "gravity",
	"gas_box": "thermodynamics",
	"nuclear_reactor": "nuclear",
	"quantum_tunneling": "quantum",
	"double_slit": "quantum"
}

func _ready() -> void:
	super._ready()
	custom_accent_color = DesignTokens.COLOR_ACCENT_SPECTRAL_AMBER
	panel_corner_radius = 10.0
	blur_strength = 2.0
	bevel_width = 12.0

	_setup_buttons()
	_apply_active_preset("solar_system")

func setup(event_bus: Node) -> void:
	_event_bus = event_bus
	if _event_bus and _event_bus.has_method("subscribe"):
		_event_bus.subscribe("physics_preset_selected", _on_external_preset_selected)

func _setup_buttons() -> void:
	_preset_buttons = {
		"solar_system": btn_solar,
		"figure8": btn_figure8,
		"cluster": btn_cluster,
		"gas_box": btn_gas,
		"nuclear_reactor": btn_nuclear,
		"quantum_tunneling": btn_quantum,
		"double_slit": btn_doubleslit
	}

	for pid in _preset_buttons.keys():
		var btn: Button = _preset_buttons[pid]
		if btn and is_instance_valid(btn):
			btn.pressed.connect(func() -> void: _on_button_pressed(pid))

func _on_button_pressed(pid: String) -> void:
	_current_preset = pid
	_apply_active_preset(pid)
	preset_selected.emit(pid)

	if _event_bus:
		if _event_bus.has_method("publish"):
			_event_bus.publish("physics_load_preset", {"preset_id": pid})
			var linked_tool: String = _preset_tools.get(pid, "gravity")
			_event_bus.publish("physics_tool_selected", {"tool_id": linked_tool})
		elif _event_bus.has_method("emit"):
			_event_bus.emit("physics_load_preset", {"preset_id": pid})
			var linked_tool: String = _preset_tools.get(pid, "gravity")
			_event_bus.emit("physics_tool_selected", {"tool_id": linked_tool})

func _on_external_preset_selected(payload: Dictionary) -> void:
	var pid: String = str(payload.get("preset_id", "")).to_lower()
	if _preset_buttons.has(pid):
		_current_preset = pid
		_apply_active_preset(pid)

func _apply_active_preset(active_pid: String) -> void:
	for pid in _preset_buttons.keys():
		var btn: Button = _preset_buttons[pid]
		if not btn or not is_instance_valid(btn):
			continue
		if pid == active_pid:
			btn.modulate = Color(1.2, 1.2, 1.3, 1.0)
			btn.add_theme_color_override("font_color", DesignTokens.COLOR_ACCENT_PRISM_CYAN)
		else:
			btn.modulate = Color(0.75, 0.8, 0.85, 0.8)
			btn.add_theme_color_override("font_color", DesignTokens.COLOR_TEXT_SECONDARY)
