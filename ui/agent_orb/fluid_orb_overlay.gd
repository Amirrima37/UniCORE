class_name FluidOrbOverlay
extends Control

## UniCORE Fluid Singularity Agent Orb Overlay
## Интерактивное квантовое ядро Агента:
## - Процедурный шейдер жидкой плазмы (fluid_orb.gdshader)
## - Двухрежимная трансформация: DOCKED (в углу/HUD) <-> EXPANDED (центральная сингулярность)
## - Реакция на акустику (речь), интенсивность мышления и генерацию кода
## - Динамическая смена состояний (IDLE, LISTENING, THINKING, SUCCESS, ERROR, AUTONOMOUS)
## - Орбитальные калибровочные кольца в стиле CERN вокруг сферы

signal orb_clicked
signal state_transition_completed(new_state: String)
signal mode_changed(is_expanded: bool)

const DesignTokens = preload("res://ui/theme/design_tokens.gd")
const FLUID_ORB_SHADER_PATH := "res://ui/shaders/fluid_orb.gdshader"

# Режимы отображения
enum DisplayMode {
	DOCKED,   # Компактный режим в HUD (72x72)
	EXPANDED  # Центральный режим диалога и созидания (280x280)
}

@export var current_mode: DisplayMode = DisplayMode.DOCKED
@export var docked_size: Vector2 = Vector2(72, 72)
@export var expanded_size: Vector2 = Vector2(280, 280)
@export var show_orbital_rings: bool = true

# Внутренние ссылки
var _orb_rect: ColorRect
var _shader_mat: ShaderMaterial
var _rings_canvas: Control

# Параметры анимации и физики
var _target_state: String = "idle"
var _current_state: String = "idle"
var _audio_level: float = 0.0
var _target_audio_level: float = 0.0
var _thought_intensity: float = 0.0
var _target_thought_intensity: float = 0.0
var _alert_blend: float = 0.0
var _target_alert_blend: float = 0.0

var _ring_angle_1: float = 0.0
var _ring_angle_2: float = 0.0
var _is_hovered: bool = false
var _is_transitioning_mode: bool = false

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS
	_setup_orb_nodes()
	set_state("idle")
	_apply_mode_layout(false)

	# Подключение к глобальной шине событий
	if Engine.has_singleton("EventBus"):
		var eb: Node = Engine.get_singleton("EventBus")
		if eb and eb.has_signal("event_emitted"):
			eb.connect("event_emitted", Callable(self, "_on_event_bus_event"))

func _setup_orb_nodes() -> void:
	# 1. Слой калибровочных орбитальных колец (под сферой)
	_rings_canvas = Control.new()
	_rings_canvas.name = "OrbitalRings"
	_rings_canvas.set_anchors_preset(Control.PRESET_FULL_RECT)
	_rings_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rings_canvas.draw.connect(_on_rings_draw)
	add_child(_rings_canvas)

	# 2. Прямоугольник с шейдером жидкого ядра
	_orb_rect = ColorRect.new()
	_orb_rect.name = "FluidOrbRect"
	_orb_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_orb_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var orb_shader := load(FLUID_ORB_SHADER_PATH) as Shader
	if orb_shader:
		_shader_mat = ShaderMaterial.new()
		_shader_mat.shader = orb_shader
		_shader_mat.set_shader_parameter("primary_color", DesignTokens.COLOR_ACCENT_PRISM_CYAN)
		_shader_mat.set_shader_parameter("secondary_color", DesignTokens.COLOR_ACCENT_ELECTRIC_BLUE)
		_shader_mat.set_shader_parameter("core_color", Color(1.0, 1.0, 1.0, 1.0))
		_shader_mat.set_shader_parameter("alert_color", DesignTokens.COLOR_ACCENT_CRIMSON_VALVE)
		_shader_mat.set_shader_parameter("fluid_speed", 1.2)
		_shader_mat.set_shader_parameter("turbulence_intensity", 0.45)
		_shader_mat.set_shader_parameter("audio_level", 0.0)
		_shader_mat.set_shader_parameter("thought_intensity", 0.0)
		_shader_mat.set_shader_parameter("alert_blend", 0.0)
		_shader_mat.set_shader_parameter("sphere_radius", 0.38)
		_shader_mat.set_shader_parameter("fresnel_power", 2.4)
		_shader_mat.set_shader_parameter("corona_intensity", 0.85)
		_orb_rect.material = _shader_mat
	add_child(_orb_rect)

func _process(delta: float) -> void:
	# 1. Плавная интерполяция реактивных параметров (сглаживание шумов)
	_audio_level = lerpf(_audio_level, _target_audio_level, delta * 12.0)
	_thought_intensity = lerpf(_thought_intensity, _target_thought_intensity, delta * 6.0)
	_alert_blend = lerpf(_alert_blend, _target_alert_blend, delta * 8.0)

	# 2. Вращение орбитальных колец в противоположные стороны
	var spin_mult := 1.0 + _thought_intensity * 2.0
	_ring_angle_1 += delta * 0.45 * spin_mult
	_ring_angle_2 -= delta * 0.3 * spin_mult

	# 3. Передача обновленных параметров в шейдер
	if _shader_mat:
		_shader_mat.set_shader_parameter("audio_level", _audio_level)
		_shader_mat.set_shader_parameter("thought_intensity", _thought_intensity)
		_shader_mat.set_shader_parameter("alert_blend", _alert_blend)

	if _rings_canvas and show_orbital_rings:
		_rings_canvas.queue_redraw()

func _on_rings_draw() -> void:
	if not show_orbital_rings:
		return

	var center := size * 0.5
	var base_radius := minf(size.x, size.y) * 0.44
	var cyan_col := DesignTokens.COLOR_ACCENT_PRISM_CYAN

	# Внешнее калибровочное кольцо с разрывами
	var ring_col := Color(cyan_col.r, cyan_col.g, cyan_col.b, 0.18 + _audio_level * 0.25)
	_draw_dashed_circle(center, base_radius * 1.08, _ring_angle_1, 6, 0.3, ring_col, 1.0)

	# Внутреннее эллиптическое кольцо траектории частиц
	var orbit_col := Color(cyan_col.r, cyan_col.g, cyan_col.b, 0.12 + _thought_intensity * 0.2)
	_draw_dashed_circle(center, base_radius * 0.95, _ring_angle_2, 4, 0.5, orbit_col, 1.0)

	# Кардинальные риски калибровки
	for i in range(4):
		var a := float(i) * (PI * 0.5) + _ring_angle_1 * 0.2
		var p1 := center + Vector2(cos(a), sin(a)) * (base_radius * 1.04)
		var p2 := center + Vector2(cos(a), sin(a)) * (base_radius * 1.14)
		_rings_canvas.draw_line(p1, p2, ring_col, 1.0, true)

func _draw_dashed_circle(center: Vector2, radius: float, start_angle: float, segments: int, arc_ratio: float, color: Color, width: float) -> void:
	var step := TAU / float(segments)
	var arc_len := step * arc_ratio

	for i in range(segments):
		var a0 := start_angle + float(i) * step
		var a1 := a0 + arc_len
		_rings_canvas.draw_arc(center, radius, a0, a1, 16, color, width, true)

# ==============================================================================
# ПУБЛИЧНЫЙ API УПРАВЛЕНИЯ СФЕРОЙ
# ==============================================================================

## Устанавливает состояние Агента и плавно перенастраивает шейдер
func set_state(new_state: String) -> void:
	_target_state = new_state.to_lower()
	_current_state = _target_state

	var primary := DesignTokens.get_agent_state_color(_current_state)
	var secondary: Color
	var speed: float = 1.2
	var turb: float = 0.45

	match _current_state:
		"idle", "ready":
			secondary = DesignTokens.COLOR_ACCENT_ELECTRIC_BLUE
			_target_thought_intensity = 0.0
			_target_alert_blend = 0.0
			speed = 1.0
			turb = 0.35
		"listening", "analyzing":
			secondary = DesignTokens.COLOR_ACCENT_PRISM_CYAN
			_target_thought_intensity = 0.2
			_target_alert_blend = 0.0
			speed = 1.6
			turb = 0.6
		"thinking", "generating", "synthesizing":
			secondary = Color(1.0, 0.45, 0.05, 1.0) # Янтарно-огненный акцент
			_target_thought_intensity = 1.2
			_target_alert_blend = 0.0
			speed = 3.2
			turb = 1.1
		"success", "verified", "mounted":
			secondary = Color(0.2, 1.0, 0.8, 1.0)
			_target_thought_intensity = 0.0
			_target_alert_blend = 0.0
			speed = 0.8
			turb = 0.25
		"error", "failed", "critical":
			secondary = Color(0.8, 0.1, 0.1, 1.0)
			_target_alert_blend = 1.0
			_target_thought_intensity = 0.5
			speed = 2.4
			turb = 1.3
		"autonomous", "singularity", "refactoring":
			secondary = DesignTokens.COLOR_ACCENT_PRISM_CYAN
			_target_thought_intensity = 0.9
			_target_alert_blend = 0.0
			speed = 2.0
			turb = 0.8
		_:
			secondary = DesignTokens.COLOR_ACCENT_ELECTRIC_BLUE

	if _shader_mat:
		var cur_pri: Variant = _shader_mat.get_shader_parameter("primary_color")
		var start_pri: Color = cur_pri if cur_pri is Color else DesignTokens.COLOR_ACCENT_PRISM_CYAN

		var cur_sec: Variant = _shader_mat.get_shader_parameter("secondary_color")
		var start_sec: Color = cur_sec if cur_sec is Color else secondary

		var cur_spd: Variant = _shader_mat.get_shader_parameter("fluid_speed")
		var start_spd: float = float(cur_spd) if cur_spd != null else 1.2

		var cur_turb: Variant = _shader_mat.get_shader_parameter("turbulence_intensity")
		var start_turb: float = float(cur_turb) if cur_turb != null else 0.45

		var tween := create_tween()
		tween.set_parallel(true)
		tween.tween_method(func(c: Color): _shader_mat.set_shader_parameter("primary_color", c), start_pri, primary, DesignTokens.DURATION_NORMAL)
		tween.tween_method(func(c: Color): _shader_mat.set_shader_parameter("secondary_color", c), start_sec, secondary, DesignTokens.DURATION_NORMAL)
		tween.tween_method(func(v: float): _shader_mat.set_shader_parameter("fluid_speed", v), start_spd, speed, DesignTokens.DURATION_NORMAL)
		tween.tween_method(func(v: float): _shader_mat.set_shader_parameter("turbulence_intensity", v), start_turb, turb, DesignTokens.DURATION_NORMAL)

	state_transition_completed.emit(_current_state)

## Переключает между DOCKED (HUD) и EXPANDED (центральный фокус)
func set_mode(mode: DisplayMode, animate: bool = true) -> void:
	current_mode = mode
	_apply_mode_layout(animate)
	mode_changed.emit(current_mode == DisplayMode.EXPANDED)

func toggle_mode(animate: bool = true) -> void:
	var next_mode := DisplayMode.EXPANDED if current_mode == DisplayMode.DOCKED else DisplayMode.DOCKED
	set_mode(next_mode, animate)

func _apply_mode_layout(animate: bool) -> void:
	var target_size := expanded_size if current_mode == DisplayMode.EXPANDED else docked_size

	if not animate:
		custom_minimum_size = target_size
		size = target_size
		return

	_is_transitioning_mode = true
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "custom_minimum_size", target_size, DesignTokens.DURATION_FLUID).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUINT)
	tween.tween_property(self, "size", target_size, DesignTokens.DURATION_FLUID).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUINT)
	tween.chain().tween_callback(func(): _is_transitioning_mode = false)

## Передает уровень громкости звука речи для акустического резонанса
func set_audio_energy(level: float) -> void:
	_target_audio_level = clampf(level, 0.0, 1.0)

## Устанавливает степень вычислительной нагрузки мышления
func set_thought_load(load_factor: float) -> void:
	_target_thought_intensity = clampf(load_factor, 0.0, 2.0)

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.is_pressed() and event.button_index == MOUSE_BUTTON_LEFT:
		orb_clicked.emit()
		toggle_mode(true)

func _on_event_bus_event(event_name: String, payload: Dictionary) -> void:
	if event_name == "agent_state_changed":
		var state := str(payload.get("new_state", "idle"))
		set_state(state)
	elif event_name == "agent_speech_amplitude":
		var amp := float(payload.get("amplitude", 0.0))
		set_audio_energy(amp)
	elif event_name == "agent_thought_intensity":
		var intensity := float(payload.get("intensity", 0.0))
		set_thought_load(intensity)
