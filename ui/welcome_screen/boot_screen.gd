class_name BootScreen
extends Control

## UniCORE Quantum Genesis Boot Screen
## Кинематографичный загрузочный экран на базе физического чертежа CERN:
## - Отображение схемы квантового разума (genesis_schematic.jpg)
## - Процедурный радиальный сканер калибровки (360-градусный луч)
## - Потоковая служебная телеметрия инициализации ядра (0x01 .. 0xFF)
## - Дыхание центрального кристалла данных
## - Бесшовный переход в Главное Меню

signal boot_completed
signal telemetry_step_completed(step_code: String, description: String)

const DesignTokens = preload("res://ui/theme/design_tokens.gd")
const SCHEMATIC_TEXTURE_PATH := "res://ui/assets/splash/genesis_schematic.jpg"

@export var auto_start: bool = true
@export var step_interval: float = 0.45
@export var fade_duration: float = 0.6

# Узлы сцены
var _background_rect: ColorRect
var _schematic_rect: TextureRect
var _scanner_canvas: Control
var _telemetry_label: Label
var _status_code_label: Label
var _progress_bar: ProgressBar
var _skip_hint: Label

var _current_step: int = 0
var _scanner_angle: float = 0.0
var _is_booting: bool = false
var _is_completed: bool = false
var _crystal_pulse_time: float = 0.0

const BOOT_SEQUENCE: Array[Dictionary] = [
	{"code": "0x01", "desc": "CALIBRATING OPTICAL CORE & PRECISION MATRICES"},
	{"code": "0x1A", "desc": "MOUNTING EVENTBUS INTER-MODULE BUS"},
	{"code": "0x3C", "desc": "COMPILING PROCEDURAL LIQUID GLASS SHADERS"},
	{"code": "0x6E", "desc": "SYNCHRONIZING RECEPTIVE QUANTUM MEMORY [12.4 MB]"},
	{"code": "0x9F", "desc": "DISCOVERING LOCAL P2P SWARM & LAN BROADCASTS"},
	{"code": "0xC8", "desc": "CALIBRATING MOLECULAR SYNAPTIC GRAPH FABRIC"},
	{"code": "0xFF", "desc": "ALL CIRCUITS NOMINAL — LAUNCHING UNICORE INTERFACE"}
]

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_setup_ui_structure()

	if auto_start:
		start_boot_sequence()

func _setup_ui_structure() -> void:
	# 1. Лабораторный фон #F5F6F4
	_background_rect = ColorRect.new()
	_background_rect.name = "Background"
	_background_rect.color = Color(0.96, 0.965, 0.96, 1.0)
	_background_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_background_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_background_rect)

	# 2. Схема архитектуры разума (genesis_schematic.jpg)
	_schematic_rect = TextureRect.new()
	_schematic_rect.name = "Schematic"
	_schematic_rect.texture = DesignTokens.load_texture_safe(SCHEMATIC_TEXTURE_PATH)
	_schematic_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_schematic_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_schematic_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_schematic_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_schematic_rect.pivot_offset = size * 0.5
	add_child(_schematic_rect)

	# 3. Радиальный сканер калибровки (оверлей)
	_scanner_canvas = Control.new()
	_scanner_canvas.name = "ScannerCanvas"
	_scanner_canvas.set_anchors_preset(Control.PRESET_FULL_RECT)
	_scanner_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_scanner_canvas.draw.connect(_on_scanner_draw)
	add_child(_scanner_canvas)

	# 4. Нижняя панель телеметрии
	var bottom_panel := PanelContainer.new()
	bottom_panel.name = "TelemetryPanel"
	bottom_panel.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	bottom_panel.custom_minimum_size.y = 80.0
	bottom_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.04, 0.05, 0.07, 0.88)
	sb.border_width_top = 1
	sb.border_color = DesignTokens.COLOR_ACCENT_PRISM_CYAN
	sb.content_margin_left = 32
	sb.content_margin_right = 32
	sb.content_margin_top = 16
	sb.content_margin_bottom = 16
	bottom_panel.add_theme_stylebox_override("panel", sb)
	add_child(bottom_panel)

	var hbox := HBoxContainer.new()
	hbox.name = "TelemetryHBox"
	bottom_panel.add_child(hbox)

	_status_code_label = Label.new()
	_status_code_label.name = "StatusCode"
	_status_code_label.text = "[0x00]"
	_status_code_label.add_theme_color_override("font_color", DesignTokens.COLOR_ACCENT_PRISM_CYAN)
	_status_code_label.custom_minimum_size.x = 80.0
	hbox.add_child(_status_code_label)

	_telemetry_label = Label.new()
	_telemetry_label.name = "TelemetryLog"
	_telemetry_label.text = "INITIALIZING CORE SUBSYSTEMS..."
	_telemetry_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_telemetry_label.add_theme_color_override("font_color", DesignTokens.COLOR_TEXT_TITANIUM)
	hbox.add_child(_telemetry_label)

	_progress_bar = ProgressBar.new()
	_progress_bar.name = "BootProgress"
	_progress_bar.custom_minimum_size = Vector2(200, 8)
	_progress_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_progress_bar.show_percentage = false

	var pb_bg := StyleBoxFlat.new()
	pb_bg.bg_color = Color(0.1, 0.12, 0.16, 0.8)
	pb_bg.corner_radius_top_left = 2
	pb_bg.corner_radius_top_right = 2
	pb_bg.corner_radius_bottom_right = 2
	pb_bg.corner_radius_bottom_left = 2

	var pb_fill := StyleBoxFlat.new()
	pb_fill.bg_color = DesignTokens.COLOR_ACCENT_PRISM_CYAN
	pb_fill.corner_radius_top_left = 2
	pb_fill.corner_radius_top_right = 2
	pb_fill.corner_radius_bottom_right = 2
	pb_fill.corner_radius_bottom_left = 2

	_progress_bar.add_theme_stylebox_override("background", pb_bg)
	_progress_bar.add_theme_stylebox_override("fill", pb_fill)
	hbox.add_child(_progress_bar)

	# 5. Тултип пропуска (ESC)
	_skip_hint = Label.new()
	_skip_hint.name = "SkipHint"
	_skip_hint.text = "[ESC] ПРОПУСТИТЬ"
	_skip_hint.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_skip_hint.offset_left = -160
	_skip_hint.offset_top = 24
	_skip_hint.offset_right = -32
	_skip_hint.add_theme_color_override("font_color", Color(0.2, 0.25, 0.3, 0.6))
	add_child(_skip_hint)

func _process(delta: float) -> void:
	if not _is_booting:
		return

	# Вращение луча калибровки
	_scanner_angle += delta * 1.05
	if _scanner_angle > TAU:
		_scanner_angle -= TAU

	# Дыхание центральной геометрии
	_crystal_pulse_time += delta
	var pulse_scale := 1.0 + sin(_crystal_pulse_time * 2.5) * 0.008
	if _schematic_rect:
		_schematic_rect.pivot_offset = size * 0.5
		_schematic_rect.scale = Vector2(pulse_scale, pulse_scale)

	if _scanner_canvas:
		_scanner_canvas.queue_redraw()

func _on_scanner_draw() -> void:
	if not _is_booting or not _scanner_canvas:
		return

	var center := size * 0.5
	var scan_radius := minf(size.x, size.y) * 0.42
	var ray_end := center + Vector2(cos(_scanner_angle), sin(_scanner_angle)) * scan_radius

	# Тонкий луч калибровки
	var ray_col := Color(
		DesignTokens.COLOR_ACCENT_PRISM_CYAN.r,
		DesignTokens.COLOR_ACCENT_PRISM_CYAN.g,
		DesignTokens.COLOR_ACCENT_PRISM_CYAN.b,
		0.22
	)
	_scanner_canvas.draw_line(center, ray_end, ray_col, 1.0, true)

	# Точечный маркер на кончике луча
	_scanner_canvas.draw_circle(ray_end, 2.0, DesignTokens.COLOR_ACCENT_PRISM_CYAN)

func start_boot_sequence() -> void:
	if _is_booting or _is_completed:
		return

	_is_booting = true
	_current_step = 0
	_progress_bar.max_value = float(BOOT_SEQUENCE.size())
	_progress_bar.value = 0.0
	_execute_next_step()

func _execute_next_step() -> void:
	if _current_step >= BOOT_SEQUENCE.size():
		_finish_boot()
		return

	var step: Dictionary = BOOT_SEQUENCE[_current_step]
	_status_code_label.text = "[%s]" % step["code"]
	_telemetry_label.text = step["desc"]
	_progress_bar.value = float(_current_step + 1)

	telemetry_step_completed.emit(str(step["code"]), str(step["desc"]))
	_current_step += 1

	var timer := get_tree().create_timer(step_interval)
	timer.timeout.connect(_execute_next_step)

func _finish_boot() -> void:
	if _is_completed:
		return

	_is_completed = true
	_is_booting = false

	if _status_code_label:
		_status_code_label.add_theme_color_override("font_color", DesignTokens.COLOR_ACCENT_EMERALD_FLUX)
	if _progress_bar:
		_progress_bar.value = _progress_bar.max_value

	# Кинематографичный плавный Dissolve
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "modulate:a", 0.0, fade_duration).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUINT)
	tween.tween_property(_schematic_rect, "scale", Vector2(1.08, 1.08), fade_duration)
	tween.chain().tween_callback(func():
		boot_completed.emit()
		visible = false
	)

func skip_boot() -> void:
	if _is_completed:
		return
	_finish_boot()

func _gui_input(event: InputEvent) -> void:
	if event is InputEventKey and event.is_pressed():
		if event.keycode == KEY_ESCAPE or event.keycode == KEY_SPACE or event.keycode == KEY_ENTER:
			skip_boot()
