class_name BootScreen
extends Control

## UniCORE Quantum Genesis Boot Screen
## Кинематографичный загрузочный экран на базе физического чертежа CERN:
## - Синхронизация палитры фона (#eef0ef) без швов с краями окна
## - Послойная кинетика: Контурная сетка -> Импульс ядра -> Бегущая телеметрия
## - Центральный оптический reticle с вращающимся лимбом калибровки
## - Нижняя панель телеметрии в стиле Detroit Liquid Glass
## - Многослойный каскадный Tween и бесшовный выход в систему

signal boot_completed
signal telemetry_step_completed(step_code: String, description: String)

const DesignTokens = preload("res://ui/theme/design_tokens.gd")
const SCHEMATIC_TEXTURE_PATH := "res://ui/assets/splash/genesis_schematic.jpg"

## Точный лабораторный цвет фона чертежа (#eef0ef) для исключения любых швов
const COLOR_SCHEMATIC_BG := Color(0.933333, 0.941176, 0.937255, 1.0)

## Индустриальные акценты CERN
const COLOR_ACCENT_ORANGE := Color(0.95, 0.42, 0.12, 1.0)
const COLOR_GRID_LINE := Color(0.12, 0.38, 0.62, 0.10)
const COLOR_GRID_CROSSHAIR := Color(0.12, 0.48, 0.78, 0.22)

@export var auto_start: bool = true
@export var step_interval: float = 0.45
@export var fade_duration: float = 0.6

# Послойные элементы сцены
var _background_rect: ColorRect
var _grid_canvas: Control
var _schematic_rect: TextureRect
var _core_canvas: Control
var _scanner_canvas: Control
var _header_telemetry: Control
var _telemetry_panel: PanelContainer

# Элементы интерфейса телеметрии
var _telemetry_label: Label
var _status_code_label: Label
var _progress_bar: ProgressBar
var _skip_hint: Label

# Состояние кинетики и анимации
var _current_step: int = 0
var _scanner_angle: float = 0.0
var _core_rotation_angle: float = 0.0
var _core_pulse_time: float = 0.0
var _core_pulse_energy: float = 1.0
var _is_booting: bool = false
var _is_completed: bool = false
var _is_ready_to_close: bool = false
var _cascade_tween: Tween = null
var _hint_pulse_tween: Tween = null

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

	if DisplayServer.get_name() == "headless":
		auto_start = false

	if auto_start:
		start_boot_sequence()

func _setup_ui_structure() -> void:
	# 1. Слой 0: Лабораторный фон #eef0ef (точный цвет периметра чертежа)
	_background_rect = ColorRect.new()
	_background_rect.name = "Background"
	_background_rect.color = COLOR_SCHEMATIC_BG
	_background_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_background_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_background_rect)

	# 2. Слой 1: Контурная координатная сетка и визирные рамки
	_grid_canvas = Control.new()
	_grid_canvas.name = "GridCanvas"
	_grid_canvas.set_anchors_preset(Control.PRESET_FULL_RECT)
	_grid_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_grid_canvas.draw.connect(_on_grid_draw)
	add_child(_grid_canvas)

	# 3. Слой 2: Схема архитектуры разума (Genesis Schematic)
	_schematic_rect = TextureRect.new()
	_schematic_rect.name = "Schematic"
	_schematic_rect.texture = DesignTokens.load_texture_safe(SCHEMATIC_TEXTURE_PATH)
	_schematic_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_schematic_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_schematic_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_schematic_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_schematic_rect.pivot_offset = size * 0.5
	add_child(_schematic_rect)

	# 4. Слой 3: Центральное квантовое ядро (Оптический Reticle с калибровкой)
	_core_canvas = Control.new()
	_core_canvas.name = "CoreReticleCanvas"
	_core_canvas.set_anchors_preset(Control.PRESET_FULL_RECT)
	_core_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_core_canvas.pivot_offset = size * 0.5
	_core_canvas.draw.connect(_on_core_draw)
	add_child(_core_canvas)

	# 5. Слой 4: Радиальный сканер калибровки (360-градусный луч)
	_scanner_canvas = Control.new()
	_scanner_canvas.name = "ScannerCanvas"
	_scanner_canvas.set_anchors_preset(Control.PRESET_FULL_RECT)
	_scanner_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_scanner_canvas.draw.connect(_on_scanner_draw)
	add_child(_scanner_canvas)

	# 6. Слой 5: Верхняя телеметрия спецификации чертежа
	_header_telemetry = Control.new()
	_header_telemetry.name = "HeaderTelemetry"
	_header_telemetry.set_anchors_preset(Control.PRESET_FULL_RECT)
	_header_telemetry.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_header_telemetry)

	var header_spec := Label.new()
	header_spec.name = "SpecLabel"
	header_spec.text = "SYS_ARCH // 0x9F_QUANTUM_CORE\nCALIBRATION: ACTIVE MATRIX"
	header_spec.offset_left = 32.0
	header_spec.offset_top = 24.0
	header_spec.add_theme_color_override("font_color", Color(0.24, 0.32, 0.42, 0.8))
	header_spec.add_theme_font_size_override("font_size", 11)
	var mono_font: Font = DesignTokens.get_font_mono()
	if mono_font:
		header_spec.add_theme_font_override("font", mono_font)
	_header_telemetry.add_child(header_spec)

	_skip_hint = Label.new()
	_skip_hint.name = "SkipHint"
	_skip_hint.text = "[ESC] ПРОПУСТИТЬ"
	_skip_hint.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_skip_hint.offset_left = -180.0
	_skip_hint.offset_top = 24.0
	_skip_hint.offset_right = -32.0
	_skip_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_skip_hint.add_theme_color_override("font_color", Color(0.24, 0.32, 0.42, 0.75))
	_skip_hint.add_theme_font_size_override("font_size", 12)
	var sans_font: Font = DesignTokens.get_font_sans()
	if sans_font:
		_skip_hint.add_theme_font_override("font", sans_font)
	_header_telemetry.add_child(_skip_hint)

	# 7. Слой 6: Нижняя панель телеметрии (Detroit Liquid Glass)
	_telemetry_panel = PanelContainer.new()
	_telemetry_panel.name = "TelemetryPanel"
	_telemetry_panel.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_telemetry_panel.custom_minimum_size.y = 80.0
	_telemetry_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.05, 0.08, 0.14, 0.94)
	sb.border_width_top = 1
	sb.border_color = DesignTokens.COLOR_ACCENT_PRISM_CYAN
	sb.shadow_color = Color(0.0, 0.85, 1.0, 0.18)
	sb.shadow_size = 6
	sb.content_margin_left = 32
	sb.content_margin_right = 32
	sb.content_margin_top = 16
	sb.content_margin_bottom = 16
	_telemetry_panel.add_theme_stylebox_override("panel", sb)
	add_child(_telemetry_panel)

	var hbox := HBoxContainer.new()
	hbox.name = "TelemetryHBox"
	_telemetry_panel.add_child(hbox)

	_status_code_label = Label.new()
	_status_code_label.name = "StatusCode"
	_status_code_label.text = "[0x00]"
	_status_code_label.add_theme_color_override("font_color", DesignTokens.COLOR_ACCENT_PRISM_CYAN)
	_status_code_label.add_theme_font_size_override("font_size", 14)
	if mono_font:
		_status_code_label.add_theme_font_override("font", mono_font)
	_status_code_label.custom_minimum_size.x = 88.0
	hbox.add_child(_status_code_label)

	_telemetry_label = Label.new()
	_telemetry_label.name = "TelemetryLog"
	_telemetry_label.text = "INITIALIZING CORE SUBSYSTEMS..."
	_telemetry_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_telemetry_label.add_theme_color_override("font_color", DesignTokens.COLOR_TEXT_TITANIUM)
	_telemetry_label.add_theme_font_size_override("font_size", 13)
	if sans_font:
		_telemetry_label.add_theme_font_override("font", sans_font)
	hbox.add_child(_telemetry_label)

	_progress_bar = ProgressBar.new()
	_progress_bar.name = "BootProgress"
	_progress_bar.custom_minimum_size = Vector2(220, 8)
	_progress_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_progress_bar.show_percentage = false

	var pb_bg := StyleBoxFlat.new()
	pb_bg.bg_color = Color(0.1, 0.14, 0.2, 0.85)
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

func _process(delta: float) -> void:
	if not _is_booting:
		return

	# Вращение луча радиального сканера
	_scanner_angle += delta * 1.05
	if _scanner_angle > TAU:
		_scanner_angle -= TAU

	# Вращение внешнего лимба калибровочного ядра
	_core_rotation_angle += delta * 0.45
	if _core_rotation_angle > TAU:
		_core_rotation_angle -= TAU

	# Дыхание квантовой энергии ядра (без масштабирования всей картинки чертежа)
	_core_pulse_time += delta
	var target_energy: float = 1.0 + sin(_core_pulse_time * 2.8) * 0.18
	_core_pulse_energy = move_toward(_core_pulse_energy, target_energy, delta * 2.0)

	if _core_canvas:
		_core_canvas.pivot_offset = size * 0.5
		_core_canvas.queue_redraw()

	if _scanner_canvas:
		_scanner_canvas.queue_redraw()

	if _grid_canvas:
		_grid_canvas.queue_redraw()

func _on_grid_draw() -> void:
	if not _grid_canvas:
		return

	var w: float = size.x
	var h: float = size.y
	var center: Vector2 = size * 0.5

	# 1. Координатные оси калибровки
	_grid_canvas.draw_line(Vector2(0.0, center.y), Vector2(w, center.y), COLOR_GRID_LINE, 1.0)
	_grid_canvas.draw_line(Vector2(center.x, 0.0), Vector2(center.x, h), COLOR_GRID_LINE, 1.0)

	# 2. Калибровочные риски по осям с шагом 64px
	var tick_size: float = 4.0
	var step_px: float = 64.0

	var x_pos: float = center.x - floorf(center.x / step_px) * step_px
	while x_pos < w:
		_grid_canvas.draw_line(Vector2(x_pos, center.y - tick_size), Vector2(x_pos, center.y + tick_size), COLOR_GRID_CROSSHAIR, 1.0)
		x_pos += step_px

	var y_pos: float = center.y - floorf(center.y / step_px) * step_px
	while y_pos < h:
		_grid_canvas.draw_line(Vector2(center.x - tick_size, y_pos), Vector2(center.x + tick_size, y_pos), COLOR_GRID_CROSSHAIR, 1.0)
		y_pos += step_px

	# 3. Угловые визирные рамки спецификации
	var corner_margin: float = 28.0
	var bracket_len: float = 22.0
	var bracket_col := Color(0.12, 0.45, 0.75, 0.35)

	# Top-Left
	_grid_canvas.draw_line(Vector2(corner_margin, corner_margin), Vector2(corner_margin + bracket_len, corner_margin), bracket_col, 1.5)
	_grid_canvas.draw_line(Vector2(corner_margin, corner_margin), Vector2(corner_margin, corner_margin + bracket_len), bracket_col, 1.5)

	# Top-Right
	_grid_canvas.draw_line(Vector2(w - corner_margin, corner_margin), Vector2(w - corner_margin - bracket_len, corner_margin), bracket_col, 1.5)
	_grid_canvas.draw_line(Vector2(w - corner_margin, corner_margin), Vector2(w - corner_margin, corner_margin + bracket_len), bracket_col, 1.5)

	# Bottom-Left (над панелью телеметрии)
	var b_y: float = h - 96.0
	_grid_canvas.draw_line(Vector2(corner_margin, b_y), Vector2(corner_margin + bracket_len, b_y), bracket_col, 1.5)
	_grid_canvas.draw_line(Vector2(corner_margin, b_y), Vector2(corner_margin, b_y - bracket_len), bracket_col, 1.5)

	# Bottom-Right
	_grid_canvas.draw_line(Vector2(w - corner_margin, b_y), Vector2(w - corner_margin - bracket_len, b_y), bracket_col, 1.5)
	_grid_canvas.draw_line(Vector2(w - corner_margin, b_y), Vector2(w - corner_margin, b_y - bracket_len), bracket_col, 1.5)

func _on_core_draw() -> void:
	if not _core_canvas:
		return

	var center: Vector2 = size * 0.5
	var base_radius: float = minf(size.x, size.y) * 0.16

	# 1. Внешний вращающийся лимб с 24 радиальными рисками
	var tick_count: int = 24
	var outer_r: float = base_radius * 1.15
	var tick_col := Color(0.12, 0.55, 0.9, 0.32 * _core_pulse_energy)
	for i in range(tick_count):
		var angle: float = _core_rotation_angle + (float(i) * TAU / float(tick_count))
		var dir := Vector2(cos(angle), sin(angle))
		var p1: Vector2 = center + dir * (outer_r - 5.0)
		var p2: Vector2 = center + dir * (outer_r + 5.0)
		_core_canvas.draw_line(p1, p2, tick_col, 1.0)

	# 2. Оптическое кольцо фокуса (Cyber Cyan)
	var ring_col := Color(
		DesignTokens.COLOR_ACCENT_PRISM_CYAN.r,
		DesignTokens.COLOR_ACCENT_PRISM_CYAN.g,
		DesignTokens.COLOR_ACCENT_PRISM_CYAN.b,
		0.45 * clampf(_core_pulse_energy, 0.5, 1.8)
	)
	_core_canvas.draw_arc(center, base_radius, 0.0, TAU, 64, ring_col, 1.2, true)

	# 3. Внутренний лимб с реверсивным вращением и оранжевым акцентом CERN
	var inner_r: float = base_radius * 0.85
	var amber_arc_col := Color(
		COLOR_ACCENT_ORANGE.r,
		COLOR_ACCENT_ORANGE.g,
		COLOR_ACCENT_ORANGE.b,
		0.65 * clampf(_core_pulse_energy, 0.6, 2.0)
	)
	_core_canvas.draw_arc(center, inner_r, -_core_rotation_angle * 1.6, -_core_rotation_angle * 1.6 + PI * 0.45, 24, amber_arc_col, 1.5, true)
	_core_canvas.draw_arc(center, inner_r, -_core_rotation_angle * 1.6 + PI, -_core_rotation_angle * 1.6 + PI * 1.45, 24, amber_arc_col, 1.5, true)

	# 4. Центральный маркер фокуса (Quantum Core Beacon)
	var beacon_r: float = 4.5 * _core_pulse_energy
	var beacon_col: Color = DesignTokens.COLOR_ACCENT_PRISM_CYAN
	_core_canvas.draw_circle(center, beacon_r, beacon_col)
	_core_canvas.draw_circle(center, beacon_r * 2.4, Color(beacon_col.r, beacon_col.g, beacon_col.b, 0.22 * _core_pulse_energy))

func _on_scanner_draw() -> void:
	if not _is_booting or not _scanner_canvas:
		return

	var center: Vector2 = size * 0.5
	var scan_radius: float = minf(size.x, size.y) * 0.42
	var ray_end: Vector2 = center + Vector2(cos(_scanner_angle), sin(_scanner_angle)) * scan_radius

	# Тонкий луч калибровки
	var ray_col := Color(
		DesignTokens.COLOR_ACCENT_PRISM_CYAN.r,
		DesignTokens.COLOR_ACCENT_PRISM_CYAN.g,
		DesignTokens.COLOR_ACCENT_PRISM_CYAN.b,
		0.22
	)
	_scanner_canvas.draw_line(center, ray_end, ray_col, 1.0, true)

	# Точечный маркер на кончике луча
	_scanner_canvas.draw_circle(ray_end, 2.5, DesignTokens.COLOR_ACCENT_PRISM_CYAN)

func start_boot_sequence() -> void:
	if _is_booting or _is_completed:
		return

	_is_booting = true
	_current_step = 0
	_progress_bar.max_value = float(BOOT_SEQUENCE.size())
	_progress_bar.value = 0.0
	_run_cascade_intro()

func _run_cascade_intro() -> void:
	if _cascade_tween and _cascade_tween.is_valid():
		_cascade_tween.kill()

	# Исходное скрытие слоев перед каскадом
	_grid_canvas.modulate.a = 0.0
	_schematic_rect.modulate.a = 0.0
	_schematic_rect.scale = Vector2.ONE

	_core_canvas.modulate.a = 0.0
	_core_canvas.scale = Vector2(0.3, 0.3)
	_core_canvas.pivot_offset = size * 0.5
	_core_pulse_energy = 0.2

	_scanner_canvas.modulate.a = 0.0
	_header_telemetry.modulate.a = 0.0
	_telemetry_panel.modulate.a = 0.0

	_cascade_tween = create_tween()
	_cascade_tween.set_parallel(false)

	# 1. Каскад, Фаза 1: Проявление контурной сетки и чертежа (ровно 0.3с)
	_cascade_tween.parallel().tween_property(_grid_canvas, "modulate:a", 1.0, 0.3).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	_cascade_tween.parallel().tween_property(_schematic_rect, "modulate:a", 1.0, 0.3).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	_cascade_tween.parallel().tween_property(_header_telemetry, "modulate:a", 1.0, 0.3).set_ease(Tween.EASE_OUT)

	# 2. Каскад, Фаза 2: Импульс центрального ядра (Scale bounce & Core Flash)
	_cascade_tween.tween_callback(func():
		_core_pulse_energy = 2.0
	)
	_cascade_tween.parallel().tween_property(_core_canvas, "modulate:a", 1.0, 0.22).set_ease(Tween.EASE_OUT)
	_cascade_tween.parallel().tween_property(_core_canvas, "scale", Vector2(1.2, 1.2), 0.22).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	_cascade_tween.parallel().tween_property(_scanner_canvas, "modulate:a", 1.0, 0.25)

	_cascade_tween.tween_property(_core_canvas, "scale", Vector2.ONE, 0.16).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)

	# 3. Каскад, Фаза 3: Проявление нижней панели телеметрии и запуск бегущей строки инициализации
	_cascade_tween.parallel().tween_property(_telemetry_panel, "modulate:a", 1.0, 0.25).set_ease(Tween.EASE_OUT)
	_cascade_tween.tween_callback(func():
		_execute_next_step()
	)

func _execute_next_step() -> void:
	if _is_completed or not is_inside_tree() or not is_instance_valid(self):
		return

	if _current_step >= BOOT_SEQUENCE.size():
		_on_boot_sequence_ready()
		return

	var step: Dictionary = BOOT_SEQUENCE[_current_step]
	_status_code_label.text = "[%s]" % step["code"]
	_telemetry_label.text = step["desc"]

	# Плавная анимация продвижения шкалы
	var p_tween := create_tween()
	p_tween.tween_property(_progress_bar, "value", float(_current_step + 1), 0.25).set_ease(Tween.EASE_OUT)

	# Микро-импульс цвета кода
	_status_code_label.modulate = Color(1.4, 1.4, 1.4, 1.0)
	var col_tween := create_tween()
	col_tween.tween_property(_status_code_label, "modulate", Color.WHITE, 0.25)

	telemetry_step_completed.emit(str(step["code"]), str(step["desc"]))
	_current_step += 1

	var timer := get_tree().create_timer(step_interval)
	timer.timeout.connect(func():
		if not _is_completed and not _is_ready_to_close:
			_execute_next_step()
	)

func _on_boot_sequence_ready() -> void:
	if _is_completed or _is_ready_to_close:
		return

	_is_ready_to_close = true

	if _status_code_label:
		_status_code_label.text = "[0xFF]"
		_status_code_label.add_theme_color_override("font_color", DesignTokens.COLOR_ACCENT_EMERALD_FLUX)
	if _telemetry_label:
		_telemetry_label.text = "СИСТЕМА ГОТОВА К РАБОТЕ // НАЖМИТЕ ЛЮБУЮ КЛАВИШУ ДЛЯ ВХОДА"
	if _progress_bar:
		_progress_bar.value = _progress_bar.max_value

	if _skip_hint:
		_skip_hint.text = "[ НАЖМИТЕ ЛЮБУЮ КЛАВИШУ ]"
		_skip_hint.add_theme_color_override("font_color", DesignTokens.COLOR_ACCENT_PRISM_CYAN)

		if _hint_pulse_tween and _hint_pulse_tween.is_valid():
			_hint_pulse_tween.kill()
		_hint_pulse_tween = create_tween().set_loops()
		_hint_pulse_tween.tween_property(_skip_hint, "modulate:a", 0.35, 0.65).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
		_hint_pulse_tween.tween_property(_skip_hint, "modulate:a", 1.0, 0.65).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)

func _finish_boot() -> void:
	_close_and_exit()

func _close_and_exit() -> void:
	if _is_completed:
		return

	_is_completed = true
	_is_booting = false
	_is_ready_to_close = false

	if _cascade_tween and _cascade_tween.is_valid():
		_cascade_tween.kill()

	if _hint_pulse_tween and _hint_pulse_tween.is_valid():
		_hint_pulse_tween.kill()

	if _status_code_label:
		_status_code_label.text = "[0xFF]"
		_status_code_label.add_theme_color_override("font_color", DesignTokens.COLOR_ACCENT_EMERALD_FLUX)
	if _telemetry_label:
		_telemetry_label.text = "CORE SYNCHRONIZATION COMPLETE — SYSTEM ONLINE"
	if _progress_bar:
		_progress_bar.value = _progress_bar.max_value

	# Кинематографичный плавный многослойный переход
	var exit_tween := create_tween()
	exit_tween.set_parallel(true)
	exit_tween.tween_property(self, "modulate:a", 0.0, fade_duration).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUINT)
	exit_tween.tween_property(_core_canvas, "scale", Vector2(1.25, 1.25), fade_duration).set_ease(Tween.EASE_OUT)
	exit_tween.chain().tween_callback(func():
		boot_completed.emit()
		visible = false
	)

func skip_boot() -> void:
	if _is_completed:
		return
	_close_and_exit()

func _unhandled_input(event: InputEvent) -> void:
	_handle_input_event(event)

func _gui_input(event: InputEvent) -> void:
	_handle_input_event(event)
	accept_event()

func _handle_input_event(event: InputEvent) -> void:
	if _is_completed:
		return

	if event is InputEventKey and event.is_pressed() and not event.is_echo():
		if _is_ready_to_close:
			_close_and_exit()
		elif event.keycode == KEY_ESCAPE:
			skip_boot()
	elif event is InputEventMouseButton and event.is_pressed():
		if _is_ready_to_close:
			_close_and_exit()
