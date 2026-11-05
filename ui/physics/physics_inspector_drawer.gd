class_name PhysicsInspectorDrawer
extends "res://ui/theme/glass_panel.gd"

## Выдвижная Панель Физического Инспектора (PhysicsInspectorDrawer)
## Стиль: Detroit Liquid Glass
## Отображает телеметрию выделенного объекта и контекстные научные параметры
## для выбранного физического инструмента (Гравитация, Термодинамика, Ядерный распад, Кванты).

@onready var btn_close: Button = $MarginContainer/VBoxContainer/HeaderPanel/BtnClose
@onready var label_header: Label = $MarginContainer/VBoxContainer/HeaderPanel/LabelHeader
@onready var scroll_container: ScrollContainer = $MarginContainer/VBoxContainer/ScrollContainer
@onready var section_entity_info: VBoxContainer = $MarginContainer/VBoxContainer/ScrollContainer/ContentVBox/SectionEntityInfo
@onready var section_parameters: VBoxContainer = $MarginContainer/VBoxContainer/ScrollContainer/ContentVBox/SectionParameters
@onready var section_actions: VBoxContainer = $MarginContainer/VBoxContainer/ScrollContainer/ContentVBox/SectionActions
@onready var footer_label: Label = $MarginContainer/VBoxContainer/FooterPanel/FooterLabel

# Элементы Entity Info
@onready var label_entity_name: Label = $MarginContainer/VBoxContainer/ScrollContainer/ContentVBox/SectionEntityInfo/LabelEntityName
@onready var label_entity_mass: Label = $MarginContainer/VBoxContainer/ScrollContainer/ContentVBox/SectionEntityInfo/LabelMass
@onready var label_entity_vel: Label = $MarginContainer/VBoxContainer/ScrollContainer/ContentVBox/SectionEntityInfo/LabelVelocity
@onready var label_entity_energy: Label = $MarginContainer/VBoxContainer/ScrollContainer/ContentVBox/SectionEntityInfo/LabelEnergy

# Кнопки действий
@onready var btn_delete_entity: Button = $MarginContainer/VBoxContainer/ScrollContainer/ContentVBox/SectionActions/BtnDeleteEntity
@onready var btn_reset_state: Button = $MarginContainer/VBoxContainer/ScrollContainer/ContentVBox/SectionActions/BtnResetState

var _event_bus: Node = null
var _is_open: bool = false
var _active_tool_id: String = "gravity"
var _selected_entity_id: String = ""
var _slide_tween: Tween = null
const DRAWER_WIDTH: float = 340.0

func _ready() -> void:
	super._ready()
	z_index = 20
	custom_accent_color = DesignTokens.COLOR_ACCENT_PRISM_CYAN
	panel_corner_radius = 8.0
	blur_strength = 2.5
	bevel_width = 16.0

	btn_close.pressed.connect(close_drawer)
	btn_delete_entity.pressed.connect(_on_delete_entity_pressed)
	btn_reset_state.pressed.connect(_on_reset_state_pressed)

	_apply_fonts_and_styles()
	_rebuild_tool_parameters("gravity")

	# Начальное состояние: закрыта (сдвинута вправо)
	set_anchors_preset(Control.PRESET_RIGHT_WIDE)
	offset_left = -DRAWER_WIDTH
	offset_right = 0.0
	offset_top = 48.0
	offset_bottom = -72.0
	custom_minimum_size = Vector2(DRAWER_WIDTH, 0)

	# Спрятать за пределы экрана
	visible = true
	position.x = get_viewport_rect().size.x

func setup(event_bus: Node) -> void:
	_event_bus = event_bus
	if not _event_bus:
		return

	if _event_bus.has_method("subscribe"):
		_event_bus.subscribe("physics_entity_selected", _on_entity_selected)
		_event_bus.subscribe("physics_tool_selected", _on_tool_selected)

func _publish(event_name: String, payload: Dictionary = {}) -> void:
	if not _event_bus:
		return
	if _event_bus.has_method("publish"):
		_event_bus.publish(event_name, payload)
	elif _event_bus.has_method("emit"):
		_event_bus.emit(event_name, payload)

func open_drawer() -> void:
	_is_open = true
	if is_instance_valid(_slide_tween):
		_slide_tween.kill()
	var target_x: float = get_viewport_rect().size.x - DRAWER_WIDTH
	_slide_tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_slide_tween.tween_property(self, "position:x", target_x, 0.28)

func close_drawer() -> void:
	_is_open = false
	if is_instance_valid(_slide_tween):
		_slide_tween.kill()
	var target_x: float = get_viewport_rect().size.x
	_slide_tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	_slide_tween.tween_property(self, "position:x", target_x, 0.24)

func toggle_drawer() -> void:
	if _is_open:
		close_drawer()
	else:
		open_drawer()

func set_active_tool(tool_id: String) -> void:
	_active_tool_id = tool_id
	_rebuild_tool_parameters(tool_id)
	if not _is_open and tool_id != "select":
		open_drawer()

func _on_tool_selected(payload: Dictionary) -> void:
	var tool_id: String = str(payload.get("tool_id", "select"))
	set_active_tool(tool_id)

func _on_entity_selected(payload: Dictionary) -> void:
	_selected_entity_id = str(payload.get("entity_id", payload.get("id", "")))
	if _selected_entity_id.is_empty():
		label_entity_name.text = "ОБЪЕКТ НЕ ВЫБРАН"
		label_entity_mass.text = "Масса: —"
		label_entity_vel.text = "Скорость: —"
		label_entity_energy.text = "Энергия: —"
		btn_delete_entity.disabled = true
		btn_reset_state.disabled = true
		return

	btn_delete_entity.disabled = false
	btn_reset_state.disabled = false

	var entity_data: Dictionary = payload.get("entity", payload) if (payload.get("entity") is Dictionary) else payload
	var mass_val: float = float(entity_data.get("mass", payload.get("mass", 1.0)))
	var vel_val: Vector3 = entity_data.get("velocity", payload.get("velocity", Vector3.ZERO))
	var energy_val: float = 0.5 * mass_val * vel_val.length_squared()

	label_entity_name.text = "ОБЪЕКТ: %s" % _selected_entity_id
	label_entity_mass.text = "Масса: %.2f kg" % mass_val
	label_entity_vel.text = "Скорость: %.2f m/s" % vel_val.length()
	label_entity_energy.text = "Кинетическая E: %.3f J" % energy_val

	if not _is_open:
		open_drawer()

func _on_delete_entity_pressed() -> void:
	if not _selected_entity_id.is_empty():
		_publish("physics_entity_action", {"action": "delete", "entity_id": _selected_entity_id})
		_selected_entity_id = ""
		label_entity_name.text = "ОБЪЕКТ УДАЛЕН"
		btn_delete_entity.disabled = true

func _on_reset_state_pressed() -> void:
	if not _selected_entity_id.is_empty():
		_publish("physics_entity_action", {"action": "reset", "entity_id": _selected_entity_id})

# ==============================================================================
# Динамические Секции Параметров под каждый Научный Модуль
# ==============================================================================

func _rebuild_tool_parameters(tool_id: String) -> void:
	for child in section_parameters.get_children():
		child.queue_free()

	match tool_id:
		"gravity":
			_build_gravity_params()
		"thermodynamics":
			_build_thermo_params()
		"nuclear":
			_build_nuclear_params()
		"quantum":
			_build_quantum_params()
		"sensor":
			_build_sensor_params()
		_:
			_build_select_params()

func _add_header_label(text: String, color: Color) -> Label:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_override("font", DesignTokens.get_font_bold())
	lbl.add_theme_font_size_override("font_size", 12)
	lbl.modulate = color
	section_parameters.add_child(lbl)
	return lbl

func _add_slider_row(label_text: String, min_v: float, max_v: float, default_v: float, step_v: float, callback: Callable) -> HSlider:
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 8)

	var lbl := Label.new()
	lbl.text = label_text
	lbl.custom_minimum_size = Vector2(120, 0)
	lbl.add_theme_font_size_override("font_size", 11)
	lbl.add_theme_color_override("font_color", DesignTokens.COLOR_TEXT_SECONDARY)
	hbox.add_child(lbl)

	var slider := HSlider.new()
	slider.min_value = min_v
	slider.max_value = max_v
	slider.step = step_v
	slider.value = default_v
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hbox.add_child(slider)

	var val_lbl := Label.new()
	val_lbl.text = "%.2f" % default_v
	val_lbl.custom_minimum_size = Vector2(44, 0)
	val_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	val_lbl.add_theme_font_size_override("font_size", 11)
	val_lbl.add_theme_font_override("font", DesignTokens.get_font_mono())
	hbox.add_child(val_lbl)

	slider.value_changed.connect(func(v: float) -> void:
		val_lbl.text = "%.2f" % v
		callback.call(v)
	)

	section_parameters.add_child(hbox)
	return slider

func _add_checkbox_row(label_text: String, default_v: bool, callback: Callable) -> CheckBox:
	var cb := CheckBox.new()
	cb.text = label_text
	cb.button_pressed = default_v
	cb.add_theme_font_size_override("font_size", 11)
	cb.toggled.connect(func(pressed: bool) -> void: callback.call(pressed))
	section_parameters.add_child(cb)
	return cb

func _build_gravity_params() -> void:
	_add_header_label("ПАРАМЕТРЫ: АСТРОФИЗИКА & СТО", DesignTokens.COLOR_ACCENT_SPECTRAL_AMBER)
	_add_slider_row("Скорость света c_sim", 5.0, 100.0, 30.0, 1.0, func(v: float) -> void:
		_publish("physics_parameter_changed", {"module_id": "gravity", "param": "c_sim", "value": v})
	)
	_add_checkbox_row("ОТО 1PN прецессия перигелия", true, func(v: bool) -> void:
		_publish("physics_parameter_changed", {"module_id": "gravity", "param": "gr_1pn_enabled", "value": v})
	)
	_add_slider_row("Масса спавна M", 1.0, 100.0, 10.0, 0.5, func(v: float) -> void:
		_publish("physics_parameter_changed", {"module_id": "gravity", "param": "spawn_mass", "value": v})
	)

	var hbox_spawn := HBoxContainer.new()
	hbox_spawn.add_theme_constant_override("separation", 6)

	var btn_star := Button.new()
	btn_star.text = "+ Звезда"
	btn_star.tooltip_text = "Спавн массивной звезды в центре (M=200)"
	btn_star.pressed.connect(func() -> void:
		_publish("physics_parameter_changed", {"module_id": "gravity", "param": "gravity_type", "value": "star"})
		_publish("physics_spawn_entity", {"module_id": "n_body_gravity_module", "entity": {"position": Vector3.ZERO, "velocity": Vector3.ZERO, "mass": 200.0, "body_type": "star"}})
	)
	hbox_spawn.add_child(btn_star)

	var btn_planet := Button.new()
	btn_planet.text = "+ Планета"
	btn_planet.tooltip_text = "Выбрать режим спавна планеты (кликните в 3D для размещения)"
	btn_planet.pressed.connect(func() -> void:
		_publish("physics_parameter_changed", {"module_id": "gravity", "param": "gravity_type", "value": "planet"})
	)
	hbox_spawn.add_child(btn_planet)

	var btn_bh := Button.new()
	btn_bh.text = "+ Ч. Дыра"
	btn_bh.tooltip_text = "Спавн сверхмассивной черной дыры (M=500)"
	btn_bh.pressed.connect(func() -> void:
		_publish("physics_parameter_changed", {"module_id": "gravity", "param": "gravity_type", "value": "black_hole"})
		_publish("physics_spawn_entity", {"module_id": "n_body_gravity_module", "entity": {"position": Vector3.ZERO, "velocity": Vector3.ZERO, "mass": 500.0, "body_type": "black_hole"}})
	)
	hbox_spawn.add_child(btn_bh)
	section_parameters.add_child(hbox_spawn)

	footer_label.text = "Гравитация: Симплектический Verlet / 1PN"

func _build_thermo_params() -> void:
	_add_header_label("ПАРАМЕТРЫ: МОЛЕКУЛЯРНАЯ ДИНАМИКА", DesignTokens.COLOR_ACCENT_PRISM_CYAN)
	_add_slider_row("Целевая темп. T_target", 0.1, 10.0, 1.0, 0.1, func(v: float) -> void:
		_publish("physics_parameter_changed", {"module_id": "thermodynamics", "param": "target_temp", "value": v})
	)
	_add_checkbox_row("Берендсен Термостат", true, func(v: bool) -> void:
		_publish("physics_parameter_changed", {"module_id": "thermodynamics", "param": "thermostat_enabled", "value": v})
	)
	_add_slider_row("Радиус отсечки r_c", 1.0, 10.0, 2.5, 0.1, func(v: float) -> void:
		_publish("physics_parameter_changed", {"module_id": "thermodynamics", "param": "cutoff_rc", "value": v})
	)

	var hbox_thermo_act := HBoxContainer.new()
	hbox_thermo_act.add_theme_constant_override("separation", 6)

	var btn_inject := Button.new()
	btn_inject.text = "+ Впрыск (+50)"
	btn_inject.pressed.connect(func() -> void:
		_publish("physics_spawn_entity", {"module_id": "molecular_dynamics_module", "entity": {"position": Vector3.ZERO, "initial_velocity": Vector3(0, 5, 0), "count": 50, "temperature": 1.5}})
	)
	hbox_thermo_act.add_child(btn_inject)

	var btn_heat := Button.new()
	btn_heat.text = "🔥 +T"
	btn_heat.pressed.connect(func() -> void:
		_publish("physics_parameter_changed", {"module_id": "thermodynamics", "param": "target_temp", "value": 2.5})
	)
	hbox_thermo_act.add_child(btn_heat)

	var btn_cool := Button.new()
	btn_cool.text = "❄️ -T"
	btn_cool.pressed.connect(func() -> void:
		_publish("physics_parameter_changed", {"module_id": "thermodynamics", "param": "target_temp", "value": 0.4})
	)
	hbox_thermo_act.add_child(btn_cool)
	section_parameters.add_child(hbox_thermo_act)

	var btn_maxwell := Button.new()
	btn_maxwell.text = "СБРОС СКОРОСТЕЙ (МАКСВЕЛЛ)"
	btn_maxwell.pressed.connect(func() -> void:
		_publish("physics_parameter_changed", {"module_id": "thermodynamics", "param": "reset_maxwell", "value": true})
	)
	section_parameters.add_child(btn_maxwell)
	footer_label.text = "Термодинамика: Потенциал Леннард-Джонса 12-6"

func _build_nuclear_params() -> void:
	_add_header_label("ПАРАМЕТРЫ: ЯДЕРНЫЙ РАСПАД & РЕАКТОР", DesignTokens.COLOR_ACCENT_EMERALD_FLUX)
	_add_slider_row("Стержни поглотителя", 0.0, 1.0, 0.3, 0.01, func(v: float) -> void:
		_publish("physics_parameter_changed", {"module_id": "nuclear", "param": "control_rods", "value": v})
	)

	var lbl_iso := Label.new()
	lbl_iso.text = "Изотоп распада:"
	lbl_iso.add_theme_font_size_override("font_size", 11)
	section_parameters.add_child(lbl_iso)

	var opt_iso := OptionButton.new()
	opt_iso.add_item("Uranium-235 (Деление)")
	opt_iso.add_item("Radium-226 (Альфа-распад)")
	opt_iso.add_item("Carbon-14 (Бета-распад)")
	opt_iso.item_selected.connect(func(idx: int) -> void:
		var iso_names := ["U-235", "Ra-226", "C-14"]
		_publish("physics_parameter_changed", {"module_id": "nuclear", "param": "isotope", "value": iso_names[idx]})
	)
	section_parameters.add_child(opt_iso)

	var hbox_nuc := HBoxContainer.new()
	hbox_nuc.add_theme_constant_override("separation", 6)

	var btn_pulse := Button.new()
	btn_pulse.text = "ИМПУЛЬС НЕЙТРОНОВ"
	btn_pulse.pressed.connect(func() -> void:
		_publish("physics_parameter_changed", {"module_id": "nuclear", "param": "neutron_pulse", "value": true})
	)
	hbox_nuc.add_child(btn_pulse)

	var btn_reset_core := Button.new()
	btn_reset_core.text = "ПЕРЕЗАГРУЗКА U-235"
	btn_reset_core.pressed.connect(func() -> void:
		_publish("physics_load_preset", {"preset_id": "nuclear_reactor"})
	)
	hbox_nuc.add_child(btn_reset_core)
	section_parameters.add_child(hbox_nuc)

	footer_label.text = "Ядерная физика: Пуассоновский распад / Сечения"

func _build_quantum_params() -> void:
	_add_header_label("ПАРАМЕТРЫ: КВАНТОВАЯ МЕХАНИКА", DesignTokens.COLOR_ACCENT_ELECTRIC_BLUE)

	var lbl_pot := Label.new()
	lbl_pot.text = "Потенциальный профиль V(x):"
	lbl_pot.add_theme_font_size_override("font_size", 11)
	section_parameters.add_child(lbl_pot)

	var opt_pot := OptionButton.new()
	opt_pot.add_item("Свободное пространство (Free Space)")
	opt_pot.add_item("Потенциальный барьер (Barrier)")
	opt_pot.add_item("Гармонический осциллятор (Harmonic)")
	opt_pot.add_item("Двухщелевой экран (Double Slit)")
	opt_pot.item_selected.connect(func(idx: int) -> void:
		var pot_ids := ["free", "barrier", "harmonic", "double_slit"]
		_publish("physics_parameter_changed", {"module_id": "quantum", "param": "potential_type", "value": pot_ids[idx]})
	)
	section_parameters.add_child(opt_pot)

	_add_slider_row("Высота барьера V0", 0.0, 50.0, 10.0, 0.5, func(v: float) -> void:
		_publish("physics_parameter_changed", {"module_id": "quantum", "param": "barrier_height", "value": v})
	)
	_add_slider_row("Энергия пакета k0", 0.1, 20.0, 5.0, 0.1, func(v: float) -> void:
		_publish("physics_parameter_changed", {"module_id": "quantum", "param": "wavepacket_k0", "value": v})
	)

	var btn_wave := Button.new()
	btn_wave.text = "🌊 ПУСК ВОЛНОВОГО ПАКЕТА"
	btn_wave.pressed.connect(func() -> void:
		_publish("physics_load_preset", {"preset_id": "quantum_tunneling"})
	)
	section_parameters.add_child(btn_wave)

	footer_label.text = "Кванты: Метод Split-Step Fourier / Шрёдингер"

func _build_sensor_params() -> void:
	_add_header_label("ПАРАМЕТРЫ: 3D ДАТЧИКИ & ЗОНДЫ", DesignTokens.COLOR_ACCENT_CRIMSON_VALVE)

	var opt_mode := OptionButton.new()
	opt_mode.add_item("Точечный зонд (Point Probe)")
	opt_mode.add_item("Поток частиц (Flux Detector)")
	opt_mode.add_item("Плотность энергии (Energy Density)")
	opt_mode.item_selected.connect(func(idx: int) -> void:
		_publish("physics_parameter_changed", {"module_id": "sensor", "param": "sensor_mode", "value": idx})
	)
	section_parameters.add_child(opt_mode)

	_add_checkbox_row("Отображать векторное поле", true, func(v: bool) -> void:
		_publish("physics_parameter_changed", {"module_id": "sensor", "param": "show_vector_field", "value": v})
	)
	_add_slider_row("Сетка выборки", 16.0, 128.0, 32.0, 8.0, func(v: float) -> void:
		_publish("physics_parameter_changed", {"module_id": "sensor", "param": "sample_grid_res", "value": int(v)})
	)
	footer_label.text = "Зонды: 3D-тензоры градиентов & поля"

func _build_select_params() -> void:
	_add_header_label("ВЫБОР ОБЪЕКТОВ", Color.WHITE)
	var lbl := Label.new()
	lbl.text = "Кликните левой кнопкой мыши по любому физическому объекту в сцене для отображения кинематических инвариантов."
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl.add_theme_font_size_override("font_size", 11)
	lbl.add_theme_color_override("font_color", DesignTokens.COLOR_TEXT_SECONDARY)
	section_parameters.add_child(lbl)
	footer_label.text = "Режим курсора: Выделение & Манипуляция"

func _apply_fonts_and_styles() -> void:
	var bold_font: Font = DesignTokens.get_font_bold()
	var mono_font: Font = DesignTokens.get_font_mono()
	if bold_font:
		label_header.add_theme_font_override("font", bold_font)
	if mono_font:
		label_entity_mass.add_theme_font_override("font", mono_font)
		label_entity_vel.add_theme_font_override("font", mono_font)
		label_entity_energy.add_theme_font_override("font", mono_font)
		footer_label.add_theme_font_override("font", mono_font)

	label_header.modulate = DesignTokens.COLOR_ACCENT_PRISM_CYAN
	footer_label.modulate = DesignTokens.COLOR_TEXT_MUTED
