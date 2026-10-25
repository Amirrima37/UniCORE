class_name WelcomeScreen
extends Control

## UniCORE Title & Welcome Screen (Asymmetric Monolith Architecture)
## Главный экран входа в систему:
## - Процедурный живой фон: сетка (grid_canvas.gdshader) + молекулярные графы (AmbientGraphCanvas)
## - Левая навигационная стела из матового кварца (GlassPanel)
## - Правая витрина активного пространства (пространство, модули, агент)
## - Полная динамическая адаптация под светлую (CyberLife White) и темную (Cyber Void) темы
## - Бесшовный кинематографичный переход в 3D-пространство ("Through the Lens")
## - Полная отчуждаемость (Decoupled): связь с ядром через EventBus и сигналы

signal resume_requested
signal spaces_requested
signal modules_requested
signal network_requested
signal settings_requested
signal quit_requested

const DesignTokens = preload("res://ui/theme/design_tokens.gd")
const CyberTheme = preload("res://ui/theme/cyber_theme.gd")
const GlassPanelScript = preload("res://ui/theme/glass_panel.gd")
const AmbientGraphCanvasScript = preload("res://ui/menu/ambient_graph_canvas.gd")
const InputMapperOverlayScript = preload("res://ui/menu/components/input_mapper_overlay.gd")
const GRID_SHADER_PATH := "res://ui/shaders/grid_canvas.gdshader"
const ICON_TEXTURE_PATH := "res://ui/assets/icons/unicore_icon.jpg"

# Ссылки на элементы интерфейса
var _background_grid: ColorRect
var _ambient_graph: Control
var _top_bar: PanelContainer
var _left_nav_panel: PanelContainer
var _right_showcase_panel: PanelContainer
var _input_mapper_overlay: Control = null

# Внедренные зависимости ядра UniCORE
var _settings_manager: Node = null
var _space_manager: Node = null
var _module_manager: Node = null
var _event_bus: Node = null
var _input_mapper: Node = null

# Кнопки навигации
var _btn_resume: Button
var _btn_spaces: Button
var _btn_modules: Button
var _btn_network: Button
var _btn_settings: Button
var _btn_quit: Button
var _nav_buttons: Array[Button] = []

# Метки телеметрии и заголовки для стилизации
var _brand_title: Label
var _version_badge: Label
var _network_pill_label: Label
var _nav_title_lbl: Label
var _showcase_title_lbl: Label
var _showcase_card: PanelContainer
var _space_name_label: Label
var _modules_count_label: Label
var _agent_status_label: Label
var _memory_label: Label
var _hint_lbl: Label

var _is_transitioning: bool = false

func setup(p_settings_manager: Node, p_space_manager: Node, p_module_manager: Node, p_event_bus: Node, p_input_mapper: Node = null) -> void:
	_settings_manager = p_settings_manager
	_space_manager = p_space_manager
	_module_manager = p_module_manager
	_event_bus = p_event_bus
	_input_mapper = p_input_mapper

	if _event_bus and _event_bus.has_signal("event_emitted"):
		if not _event_bus.is_connected("event_emitted", Callable(self, "_on_event_bus_event")):
			_event_bus.connect("event_emitted", Callable(self, "_on_event_bus_event"))

	_update_telemetry_from_system()
	_apply_theme_styling()

func open_welcome() -> void:
	_is_transitioning = false
	visible = true
	if _left_nav_panel:
		_left_nav_panel.position.x = 0.0
		_left_nav_panel.modulate.a = 1.0
	if _right_showcase_panel:
		_right_showcase_panel.modulate.a = 1.0
	if _background_grid:
		_background_grid.modulate.a = 1.0
	_apply_theme_styling()
	_update_telemetry_from_system()
	if DisplayServer.has_feature(DisplayServer.FEATURE_MOUSE):
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_build_ui_layout()
	_apply_theme_styling()
	_update_telemetry_from_system()

	# Подписка на глобальную шину событий
	if Engine.has_singleton("EventBus"):
		var eb: Node = Engine.get_singleton("EventBus")
		if eb and eb.has_signal("event_emitted"):
			eb.connect("event_emitted", Callable(self, "_on_event_bus_event"))

func _build_ui_layout() -> void:
	# 1. Процедурная координатная сетка
	_background_grid = ColorRect.new()
	_background_grid.name = "VoidGrid"
	_background_grid.set_anchors_preset(Control.PRESET_FULL_RECT)
	_background_grid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var grid_shader := load(GRID_SHADER_PATH) as Shader
	if grid_shader:
		var grid_mat := ShaderMaterial.new()
		grid_mat.shader = grid_shader
		_background_grid.material = grid_mat
	else:
		_background_grid.color = DesignTokens.COLOR_VOID_DEEP
	add_child(_background_grid)

	# 2. Молекулярный граф парящих частиц
	_ambient_graph = AmbientGraphCanvasScript.new()
	_ambient_graph.name = "AmbientGraph"
	add_child(_ambient_graph)

	# 3. Верхний информационный бар (Header)
	_build_header()

	# 4. Основной контейнер экрана (разбивка на 2 колонки)
	var main_margin := MarginContainer.new()
	main_margin.name = "MainMargin"
	main_margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	main_margin.add_theme_constant_override("margin_left", 48)
	main_margin.add_theme_constant_override("margin_right", 48)
	main_margin.add_theme_constant_override("margin_top", 80)
	main_margin.add_theme_constant_override("margin_bottom", 48)
	main_margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(main_margin)

	var hbox := HBoxContainer.new()
	hbox.name = "ColumnsHBox"
	hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	hbox.add_theme_constant_override("separation", 32)
	main_margin.add_child(hbox)

	# 5. Левая навигационная стела (Navigation Spine)
	_build_navigation_spine(hbox)

	# 6. Правая витрина контекста и пространства
	_build_context_showcase(hbox)

func _build_header() -> void:
	_top_bar = GlassPanelScript.new()
	_top_bar.name = "TopHeader"
	_top_bar.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_top_bar.custom_minimum_size.y = 52.0
	_top_bar.mouse_filter = Control.MOUSE_FILTER_PASS
	_top_bar.blur_strength = 2.2
	_top_bar.panel_corner_radius = 0.0
	add_child(_top_bar)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 32)
	margin.add_theme_constant_override("margin_right", 32)
	margin.mouse_filter = Control.MOUSE_FILTER_PASS
	_top_bar.add_child(margin)

	var hsplit := HBoxContainer.new()
	hsplit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hsplit.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.add_child(hsplit)

	# Логотип и бренд-блок слева
	var brand_box := HBoxContainer.new()
	brand_box.add_theme_constant_override("separation", 12)
	hsplit.add_child(brand_box)

	var icon_tex: Texture2D = DesignTokens.load_texture_safe(ICON_TEXTURE_PATH)
	if icon_tex:
		var icon_rect := TextureRect.new()
		icon_rect.texture = icon_tex
		icon_rect.custom_minimum_size = Vector2(24, 24)
		icon_rect.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		brand_box.add_child(icon_rect)

	_brand_title = Label.new()
	_brand_title.text = "UniCORE"
	brand_box.add_child(_brand_title)

	_version_badge = Label.new()
	_version_badge.text = "[ v0.4.0 — GENESIS ]"
	brand_box.add_child(_version_badge)

	# Распорка по центру
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hsplit.add_child(spacer)

	# Статус сети справа
	_network_pill_label = Label.new()
	_network_pill_label.name = "NetworkPill"
	_network_pill_label.text = "● P2P STANDALONE // 0 PEERS"
	hsplit.add_child(_network_pill_label)

func _build_navigation_spine(parent_hbox: HBoxContainer) -> void:
	_left_nav_panel = GlassPanelScript.new()
	_left_nav_panel.name = "NavigationSpine"
	_left_nav_panel.custom_minimum_size = Vector2(360, 0)
	_left_nav_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_left_nav_panel.blur_strength = 2.8
	_left_nav_panel.panel_corner_radius = 4.0
	parent_hbox.add_child(_left_nav_panel)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_top", 24)
	margin.add_theme_constant_override("margin_bottom", 24)
	_left_nav_panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 8)
	margin.add_child(vbox)

	_nav_title_lbl = Label.new()
	_nav_title_lbl.text = "// СИСТЕМНАЯ НАВИГАЦИЯ"
	vbox.add_child(_nav_title_lbl)

	var sep := HSeparator.new()
	vbox.add_child(sep)

	# Создание кнопок меню
	_btn_resume = _create_nav_button("01 // ПРОДОЛЖИТЬ СЕССИЮ", "_on_resume_pressed")
	_btn_spaces = _create_nav_button("02 // ПРОСТРАНСТВА", "_on_spaces_pressed")
	_btn_modules = _create_nav_button("03 // БИБЛИОТЕКА МОДУЛЕЙ", "_on_modules_pressed")
	_btn_network = _create_nav_button("04 // СЕТЬ & P2P", "_on_network_pressed")
	_btn_settings = _create_nav_button("05 // НАСТРОЙКИ СИСТЕМЫ", "_on_settings_pressed")
	_btn_quit = _create_nav_button("06 // ТЕРМИНАЦИЯ", "_on_quit_pressed")

	vbox.add_child(_btn_resume)
	vbox.add_child(_btn_spaces)
	vbox.add_child(_btn_modules)
	vbox.add_child(_btn_network)
	vbox.add_child(_btn_settings)
	vbox.add_child(_btn_quit)

func _create_nav_button(label_text: String, callback_name: String) -> Button:
	var btn := Button.new()
	btn.text = label_text
	btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	btn.custom_minimum_size.y = 44.0
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

	btn.pressed.connect(Callable(self, callback_name))
	_nav_buttons.append(btn)
	return btn

func _style_nav_button(btn: Button, is_white: bool) -> void:
	var sb_normal := StyleBoxFlat.new()
	sb_normal.bg_color = Color(0.92, 0.95, 0.99, 0.75) if is_white else Color(0.06, 0.09, 0.14, 0.35)
	sb_normal.border_width_left = 1
	sb_normal.border_color = Color(0.2, 0.55, 0.88, 0.25) if is_white else DesignTokens.COLOR_GLASS_HAIRLINE
	sb_normal.corner_radius_top_left = 2
	sb_normal.corner_radius_top_right = 2
	sb_normal.corner_radius_bottom_right = 2
	sb_normal.corner_radius_bottom_left = 2
	sb_normal.content_margin_left = 16

	var sb_hover := StyleBoxFlat.new()
	sb_hover.bg_color = Color(0.85, 0.92, 0.99, 0.98) if is_white else Color(0.09, 0.15, 0.24, 0.75)
	sb_hover.border_width_left = 3
	sb_hover.border_color = DesignTokens.COLOR_ACCENT_ELECTRIC_BLUE if is_white else DesignTokens.COLOR_ACCENT_PRISM_CYAN
	sb_hover.corner_radius_top_left = 2
	sb_hover.corner_radius_top_right = 2
	sb_hover.corner_radius_bottom_right = 2
	sb_hover.corner_radius_bottom_left = 2
	sb_hover.content_margin_left = 18

	btn.add_theme_stylebox_override("normal", sb_normal)
	btn.add_theme_stylebox_override("hover", sb_hover)
	btn.add_theme_stylebox_override("pressed", sb_hover)
	btn.add_theme_stylebox_override("focus", sb_hover)

	var f_col := Color(0.12, 0.18, 0.28, 1.0) if is_white else DesignTokens.COLOR_TEXT_SECONDARY
	var f_hover_col := DesignTokens.COLOR_TEXT_DARK if is_white else DesignTokens.COLOR_TEXT_TITANIUM
	btn.add_theme_color_override("font_color", f_col)
	btn.add_theme_color_override("font_hover_color", f_hover_col)
	btn.add_theme_color_override("font_focus_color", f_hover_col)

func _build_context_showcase(parent_hbox: HBoxContainer) -> void:
	_right_showcase_panel = GlassPanelScript.new()
	_right_showcase_panel.name = "ContextShowcase"
	_right_showcase_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_right_showcase_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_right_showcase_panel.blur_strength = 2.8
	_right_showcase_panel.panel_corner_radius = 4.0
	parent_hbox.add_child(_right_showcase_panel)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 28)
	margin.add_theme_constant_override("margin_right", 28)
	margin.add_theme_constant_override("margin_top", 24)
	margin.add_theme_constant_override("margin_bottom", 24)
	_right_showcase_panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 16)
	margin.add_child(vbox)

	_showcase_title_lbl = Label.new()
	_showcase_title_lbl.text = "// ТЕЛЕМЕТРИЯ АКТИВНОГО ПРОСТРАНСТВА"
	vbox.add_child(_showcase_title_lbl)

	var sep := HSeparator.new()
	vbox.add_child(sep)

	# Карточка пространства
	_showcase_card = GlassPanelScript.new()
	_showcase_card.name = "ShowcaseCard"
	_showcase_card.blur_strength = 2.0
	_showcase_card.panel_corner_radius = 4.0
	vbox.add_child(_showcase_card)

	var card_margin := MarginContainer.new()
	card_margin.add_theme_constant_override("margin_left", 20)
	card_margin.add_theme_constant_override("margin_right", 20)
	card_margin.add_theme_constant_override("margin_top", 16)
	card_margin.add_theme_constant_override("margin_bottom", 16)
	_showcase_card.add_child(card_margin)

	var card_vbox := VBoxContainer.new()
	card_vbox.add_theme_constant_override("separation", 10)
	card_margin.add_child(card_vbox)

	_space_name_label = Label.new()
	_space_name_label.text = "ПРОСТРАНСТВО: \"DEFAULT STUDIO\""
	card_vbox.add_child(_space_name_label)

	_modules_count_label = Label.new()
	_modules_count_label.text = "АКТИВНЫХ МОДУЛЕЙ: 2 (GroundPlane, AvatarLocomotion)"
	card_vbox.add_child(_modules_count_label)

	_agent_status_label = Label.new()
	_agent_status_label.text = "СТАТУС АГЕНТА: ГОТОВ К СИНТЕЗУ (IDLE)"
	card_vbox.add_child(_agent_status_label)

	_memory_label = Label.new()
	_memory_label.text = "ПАМЯТЬ СЕССИИ: ~12.4 MB"
	card_vbox.add_child(_memory_label)

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(spacer)

	_hint_lbl = Label.new()
	_hint_lbl.text = "Нажмите [ENTER] или кликните «ПРОДОЛЖИТЬ» для бесшовного входа в 3D-пространство."
	vbox.add_child(_hint_lbl)

func _apply_theme_styling() -> void:
	var is_white := CyberTheme.is_white_theme()

	# 1. Фоновая координатная сетка
	if _background_grid and _background_grid.material is ShaderMaterial:
		var sm := _background_grid.material as ShaderMaterial
		if is_white:
			sm.set_shader_parameter("bg_color", Color(0.955, 0.965, 0.975, 1.0))
			sm.set_shader_parameter("grid_color", Color(0.12, 0.52, 0.88, 0.08))
			sm.set_shader_parameter("crosshair_color", Color(0.08, 0.5, 0.85, 0.22))
		else:
			sm.set_shader_parameter("bg_color", DesignTokens.COLOR_VOID_DEEP)
			sm.set_shader_parameter("grid_color", Color(0.0, 0.9, 1.0, 0.06))
			sm.set_shader_parameter("crosshair_color", Color(0.0, 0.9, 1.0, 0.18))
	elif _background_grid:
		_background_grid.color = Color(0.955, 0.965, 0.975, 1.0) if is_white else DesignTokens.COLOR_VOID_DEEP

	# 2. Молекулярный граф
	if _ambient_graph and "custom_color" in _ambient_graph:
		_ambient_graph.custom_color = Color(0.12, 0.48, 0.85, 0.5) if is_white else DesignTokens.COLOR_ACCENT_PRISM_CYAN

	# 3. TopHeader
	if _top_bar and _top_bar.has_method("_update_styling"):
		_top_bar.call("_update_styling")

	if _brand_title:
		_brand_title.add_theme_color_override("font_color", DesignTokens.COLOR_TEXT_DARK if is_white else DesignTokens.COLOR_TEXT_TITANIUM)
	if _version_badge:
		_version_badge.add_theme_color_override("font_color", DesignTokens.COLOR_TEXT_DARK_MUTED if is_white else DesignTokens.COLOR_TEXT_MUTED)
	if _network_pill_label:
		_network_pill_label.add_theme_color_override("font_color", DesignTokens.COLOR_ACCENT_ELECTRIC_BLUE if is_white else DesignTokens.COLOR_ACCENT_PRISM_CYAN)

	# 4. Навигационная стела и кнопки
	if _left_nav_panel and _left_nav_panel.has_method("_update_styling"):
		_left_nav_panel.call("_update_styling")

	if _nav_title_lbl:
		_nav_title_lbl.add_theme_color_override("font_color", DesignTokens.COLOR_TEXT_DARK_MUTED if is_white else DesignTokens.COLOR_TEXT_MUTED)

	for btn in _nav_buttons:
		_style_nav_button(btn, is_white)

	# 5. Витрина контекста
	if _right_showcase_panel and _right_showcase_panel.has_method("_update_styling"):
		_right_showcase_panel.call("_update_styling")

	if _showcase_title_lbl:
		_showcase_title_lbl.add_theme_color_override("font_color", DesignTokens.COLOR_TEXT_DARK_MUTED if is_white else DesignTokens.COLOR_TEXT_MUTED)

	if _showcase_card and _showcase_card.has_method("_update_styling"):
		_showcase_card.call("_update_styling")

	if _space_name_label:
		_space_name_label.add_theme_color_override("font_color", DesignTokens.COLOR_TEXT_DARK if is_white else DesignTokens.COLOR_TEXT_TITANIUM)
	if _modules_count_label:
		_modules_count_label.add_theme_color_override("font_color", Color(0.2, 0.3, 0.42, 1.0) if is_white else DesignTokens.COLOR_TEXT_SECONDARY)
	if _agent_status_label:
		_agent_status_label.add_theme_color_override("font_color", DesignTokens.COLOR_ACCENT_ELECTRIC_BLUE if is_white else DesignTokens.COLOR_ACCENT_PRISM_CYAN)
	if _memory_label:
		_memory_label.add_theme_color_override("font_color", DesignTokens.COLOR_TEXT_DARK_MUTED if is_white else DesignTokens.COLOR_TEXT_MUTED)
	if _hint_lbl:
		_hint_lbl.add_theme_color_override("font_color", DesignTokens.COLOR_TEXT_DARK_MUTED if is_white else DesignTokens.COLOR_TEXT_MUTED)

func _update_telemetry_from_system() -> void:
	if _space_manager:
		var s_name: String = ""
		if _space_manager.has_method("get_active_space_name"):
			s_name = str(_space_manager.call("get_active_space_name"))
		elif "current_space_name" in _space_manager:
			s_name = str(_space_manager.current_space_name)
		if not s_name.is_empty() and _space_name_label:
			_space_name_label.text = "ПРОСТРАНСТВО: \"%s\"" % s_name.to_upper()
	elif Engine.has_singleton("SpaceManager"):
		var sm: Node = Engine.get_singleton("SpaceManager")
		if sm and sm.has_method("get_active_space_name"):
			_space_name_label.text = "ПРОСТРАНСТВО: \"%s\"" % str(sm.call("get_active_space_name"))

	if _module_manager and _modules_count_label:
		if _module_manager.has_method("get_active_module_ids"):
			var active_ids: Array = _module_manager.call("get_active_module_ids")
			var count: int = active_ids.size()
			var summary: String = ", ".join(active_ids) if count > 0 else "НЕТ"
			_modules_count_label.text = "АКТИВНЫХ МОДУЛЕЙ: %d (%s)" % [count, summary]

	var mem_mb: float = float(OS.get_static_memory_usage()) / (1024.0 * 1024.0)
	if _memory_label:
		_memory_label.text = "ПАМЯТЬ СЕССИИ: ~%.1f MB" % mem_mb

func _on_event_bus_event(event_name: String, payload: Dictionary) -> void:
	if event_name == "interface_settings_changed":
		_apply_theme_styling()
	elif event_name == "agent_state_changed":
		var state := str(payload.get("new_state", "idle"))
		if _agent_status_label:
			_agent_status_label.text = "СТАТУС АГЕНТА: %s" % state.to_upper()
			_agent_status_label.add_theme_color_override("font_color", DesignTokens.get_agent_state_color(state))
	elif event_name == "network_status_updated":
		var peer_count: int = int(payload.get("peer_count", 0))
		var status_str: String = str(payload.get("status", "standalone")).to_upper()
		if _network_pill_label:
			_network_pill_label.text = "● P2P %s // %d PEERS" % [status_str, peer_count]
	elif event_name == "module_loaded" or event_name == "module_unloaded" or event_name == "space_loaded":
		_update_telemetry_from_system()

func _on_resume_pressed() -> void:
	if _is_transitioning:
		return
	_is_transitioning = true
	resume_requested.emit()
	if _event_bus and _event_bus.has_method("emit"):
		_event_bus.emit("space_resume_requested", {})
		_event_bus.emit("modal_closed", {"source": "welcome_screen"})
	elif Engine.has_singleton("EventBus"):
		var eb: Node = Engine.get_singleton("EventBus")
		if eb and eb.has_method("emit"):
			eb.call("emit", "space_resume_requested", {})

	# Кинематика перехода Through the Lens:
	# Стелы плавно раздвигаются, фон растворяется, камера выходит в 3D
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(_left_nav_panel, "position:x", -400.0, DesignTokens.DURATION_FLUID).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUINT)
	tween.tween_property(_left_nav_panel, "modulate:a", 0.0, DesignTokens.DURATION_FLUID)
	tween.tween_property(_right_showcase_panel, "modulate:a", 0.0, DesignTokens.DURATION_FLUID)
	tween.tween_property(_background_grid, "modulate:a", 0.0, DesignTokens.DURATION_FLUID)
	tween.chain().tween_callback(func():
		visible = false
	)

func _on_spaces_pressed() -> void:
	spaces_requested.emit()
	if _event_bus and _event_bus.has_method("emit"):
		_event_bus.emit("open_spaces_requested", {})
	elif Engine.has_singleton("EventBus"):
		var eb: Node = Engine.get_singleton("EventBus")
		if eb and eb.has_method("emit"):
			eb.call("emit", "open_spaces_requested", {})

func _on_modules_pressed() -> void:
	modules_requested.emit()
	if _event_bus and _event_bus.has_method("emit"):
		_event_bus.emit("open_modules_requested", {})
	elif Engine.has_singleton("EventBus"):
		var eb: Node = Engine.get_singleton("EventBus")
		if eb and eb.has_method("emit"):
			eb.call("emit", "open_modules_requested", {})

func _on_network_pressed() -> void:
	network_requested.emit()
	if _event_bus and _event_bus.has_method("emit"):
		_event_bus.emit("open_network_requested", {})
	elif Engine.has_singleton("EventBus"):
		var eb: Node = Engine.get_singleton("EventBus")
		if eb and eb.has_method("emit"):
			eb.call("emit", "open_network_requested", {})

func _on_settings_pressed() -> void:
	settings_requested.emit()
	if _event_bus and _event_bus.has_method("emit"):
		_event_bus.emit("open_settings_requested", {})
	elif Engine.has_singleton("EventBus"):
		var eb: Node = Engine.get_singleton("EventBus")
		if eb and eb.has_method("emit"):
			eb.call("emit", "open_settings_requested", {})

func open_input_mapper(input_mapper: Node = null) -> void:
	if not _input_mapper_overlay:
		_input_mapper_overlay = InputMapperOverlayScript.new()
		add_child(_input_mapper_overlay)
	if input_mapper:
		_input_mapper_overlay.setup(input_mapper)
	_input_mapper_overlay.visible = true

func _on_quit_pressed() -> void:
	quit_requested.emit()
	get_tree().quit()

func _gui_input(event: InputEvent) -> void:
	if event is InputEventKey and event.is_pressed():
		if event.keycode == KEY_ENTER:
			_on_resume_pressed()
		elif event.keycode == KEY_ESCAPE:
			_on_quit_pressed()
