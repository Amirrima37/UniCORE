class_name WelcomeScreen
extends Control

## UniCORE Title & Welcome Screen (Asymmetric Monolith Architecture)
## Главный экран входа в систему:
## - Процедурный живой фон: сетка (grid_canvas.gdshader) + молекулярные графы (AmbientGraphCanvas)
## - Левая навигационная стела из матового кварца (GlassPanel)
## - Правая витрина активного пространства (пространство, модули, агент)
## - Бесшовный кинематографичный переход в 3D-пространство ("Through the Lens")
## - Полная отчуждаемость (Decoupled): связь с ядром через EventBus и сигналы

signal resume_requested
signal spaces_requested
signal modules_requested
signal network_requested
signal settings_requested
signal quit_requested

const DesignTokens = preload("res://ui/theme/design_tokens.gd")
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
var _optical_rail_marker: ColorRect
var _input_mapper_overlay: Control = null

# Кнопки навигации
var _btn_resume: Button
var _btn_spaces: Button
var _btn_modules: Button
var _btn_network: Button
var _btn_settings: Button
var _btn_quit: Button
var _nav_buttons: Array[Button] = []

# Метки телеметрии
var _space_name_label: Label
var _modules_count_label: Label
var _agent_status_label: Label
var _memory_label: Label
var _network_pill_label: Label

var _is_transitioning: bool = false

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_build_ui_layout()
	_update_telemetry_from_system()

	# Подписка на глобальную шину событий
	if Engine.has_singleton("EventBus"):
		var eb: Node = Engine.get_singleton("EventBus")
		if eb and eb.has_signal("event_emitted"):
			eb.connect("event_emitted", Callable(self, "_on_event_bus_event"))

func _build_ui_layout() -> void:
	# 1. Процедурная координатная сетка пустоты
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
	_top_bar = PanelContainer.new()
	_top_bar.name = "TopHeader"
	_top_bar.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_top_bar.custom_minimum_size.y = 52.0
	_top_bar.mouse_filter = Control.MOUSE_FILTER_PASS

	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.04, 0.05, 0.08, 0.8)
	sb.border_width_bottom = 1
	sb.border_color = DesignTokens.COLOR_GLASS_HAIRLINE
	sb.content_margin_left = 32
	sb.content_margin_right = 32
	_top_bar.add_theme_stylebox_override("panel", sb)
	add_child(_top_bar)

	var hsplit := HBoxContainer.new()
	hsplit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hsplit.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_top_bar.add_child(hsplit)

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

	var brand_title := Label.new()
	brand_title.text = "UniCORE"
	brand_title.add_theme_color_override("font_color", DesignTokens.COLOR_TEXT_TITANIUM)
	brand_box.add_child(brand_title)

	var version_badge := Label.new()
	version_badge.text = "[ v0.4.0 — GENESIS ]"
	version_badge.add_theme_color_override("font_color", DesignTokens.COLOR_TEXT_MUTED)
	brand_box.add_child(version_badge)

	# Распорка по центру
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hsplit.add_child(spacer)

	# Статус сети справа
	_network_pill_label = Label.new()
	_network_pill_label.name = "NetworkPill"
	_network_pill_label.text = "● P2P STANDALONE // 0 PEERS"
	_network_pill_label.add_theme_color_override("font_color", DesignTokens.COLOR_ACCENT_PRISM_CYAN)
	hsplit.add_child(_network_pill_label)

func _build_navigation_spine(parent_hbox: HBoxContainer) -> void:
	_left_nav_panel = GlassPanelScript.new()
	_left_nav_panel.name = "NavigationSpine"
	_left_nav_panel.custom_minimum_size = Vector2(360, 0)
	_left_nav_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	parent_hbox.add_child(_left_nav_panel)

	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 8)
	_left_nav_panel.add_child(vbox)

	var title_lbl := Label.new()
	title_lbl.text = "// СИСТЕМНАЯ НАВИГАЦИЯ"
	title_lbl.add_theme_color_override("font_color", DesignTokens.COLOR_TEXT_MUTED)
	vbox.add_child(title_lbl)

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

	# Световод активного выбора
	_optical_rail_marker = ColorRect.new()
	_optical_rail_marker.name = "OpticalRailMarker"
	_optical_rail_marker.custom_minimum_size = Vector2(2, 28)
	_optical_rail_marker.color = DesignTokens.COLOR_ACCENT_PRISM_CYAN
	_optical_rail_marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_left_nav_panel.add_child(_optical_rail_marker)
	_optical_rail_marker.position = Vector2(16, 56)

func _create_nav_button(label_text: String, callback_name: String) -> Button:
	var btn := Button.new()
	btn.text = label_text
	btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	btn.custom_minimum_size.y = 44.0
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var sb_normal := StyleBoxFlat.new()
	sb_normal.bg_color = Color(0.06, 0.09, 0.14, 0.35)
	sb_normal.border_width_left = 1
	sb_normal.border_color = DesignTokens.COLOR_GLASS_HAIRLINE
	sb_normal.corner_radius_top_left = 2
	sb_normal.corner_radius_top_right = 2
	sb_normal.corner_radius_bottom_right = 2
	sb_normal.corner_radius_bottom_left = 2
	sb_normal.content_margin_left = 16

	var sb_hover := StyleBoxFlat.new()
	sb_hover.bg_color = Color(0.08, 0.14, 0.22, 0.65)
	sb_hover.border_width_left = 2
	sb_hover.border_color = DesignTokens.COLOR_ACCENT_PRISM_CYAN
	sb_hover.corner_radius_top_left = 2
	sb_hover.corner_radius_top_right = 2
	sb_hover.corner_radius_bottom_right = 2
	sb_hover.corner_radius_bottom_left = 2
	sb_hover.content_margin_left = 18

	btn.add_theme_stylebox_override("normal", sb_normal)
	btn.add_theme_stylebox_override("hover", sb_hover)
	btn.add_theme_stylebox_override("pressed", sb_hover)
	btn.add_theme_color_override("font_color", DesignTokens.COLOR_TEXT_SECONDARY)
	btn.add_theme_color_override("font_hover_color", DesignTokens.COLOR_TEXT_TITANIUM)

	btn.pressed.connect(Callable(self, callback_name))
	btn.mouse_entered.connect(func(): _move_optical_rail(btn))

	_nav_buttons.append(btn)
	return btn

func _build_context_showcase(parent_hbox: HBoxContainer) -> void:
	_right_showcase_panel = GlassPanelScript.new()
	_right_showcase_panel.name = "ContextShowcase"
	_right_showcase_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_right_showcase_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	parent_hbox.add_child(_right_showcase_panel)

	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 16)
	_right_showcase_panel.add_child(vbox)

	var title_lbl := Label.new()
	title_lbl.text = "// ТЕЛЕМЕТРИЯ АКТИВНОГО ПРОСТРАНСТВА"
	title_lbl.add_theme_color_override("font_color", DesignTokens.COLOR_TEXT_MUTED)
	vbox.add_child(title_lbl)

	var sep := HSeparator.new()
	vbox.add_child(sep)

	# Карточка пространства
	var card := PanelContainer.new()
	var card_sb := StyleBoxFlat.new()
	card_sb.bg_color = Color(0.04, 0.06, 0.1, 0.6)
	card_sb.border_width_left = 1
	card_sb.border_width_top = 1
	card_sb.border_width_right = 1
	card_sb.border_width_bottom = 1
	card_sb.border_color = Color(0.0, 0.9, 1.0, 0.25)
	card_sb.corner_radius_top_left = 4
	card_sb.corner_radius_top_right = 4
	card_sb.corner_radius_bottom_right = 4
	card_sb.corner_radius_bottom_left = 4
	card_sb.content_margin_left = 24
	card_sb.content_margin_right = 24
	card_sb.content_margin_top = 20
	card_sb.content_margin_bottom = 20
	card.add_theme_stylebox_override("panel", card_sb)
	vbox.add_child(card)

	var card_vbox := VBoxContainer.new()
	card_vbox.add_theme_constant_override("separation", 10)
	card.add_child(card_vbox)

	_space_name_label = Label.new()
	_space_name_label.text = "ПРОСТРАНСТВО: \"GENESIS\""
	_space_name_label.add_theme_color_override("font_color", DesignTokens.COLOR_TEXT_TITANIUM)
	card_vbox.add_child(_space_name_label)

	_modules_count_label = Label.new()
	_modules_count_label.text = "АКТИВНЫХ МОДУЛЕЙ: 2 (GroundPlane, AvatarLocomotion)"
	_modules_count_label.add_theme_color_override("font_color", DesignTokens.COLOR_TEXT_SECONDARY)
	card_vbox.add_child(_modules_count_label)

	_agent_status_label = Label.new()
	_agent_status_label.text = "СТАТУС АГЕНТА: ГОТОВ К СИНТЕЗУ (IDLE)"
	_agent_status_label.add_theme_color_override("font_color", DesignTokens.COLOR_ACCENT_PRISM_CYAN)
	card_vbox.add_child(_agent_status_label)

	_memory_label = Label.new()
	_memory_label.text = "ПАМЯТЬ СЕССИИ: ~12.4 MB"
	_memory_label.add_theme_color_override("font_color", DesignTokens.COLOR_TEXT_MUTED)
	card_vbox.add_child(_memory_label)

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(spacer)

	var hint_lbl := Label.new()
	hint_lbl.text = "Нажмите [ENTER] или кликните «ПРОДОЛЖИТЬ» для бесшовного входа в 3D-пространство."
	hint_lbl.add_theme_color_override("font_color", DesignTokens.COLOR_TEXT_MUTED)
	vbox.add_child(hint_lbl)

func _move_optical_rail(target_btn: Button) -> void:
	if not _optical_rail_marker or not target_btn:
		return
	var target_y := target_btn.position.y + 8.0
	var tween := create_tween()
	tween.tween_property(_optical_rail_marker, "position:y", target_y, DesignTokens.DURATION_FAST).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

func _update_telemetry_from_system() -> void:
	if Engine.has_singleton("SpaceManager"):
		var sm: Node = Engine.get_singleton("SpaceManager")
		if sm and sm.has_method("get_active_space_name"):
			_space_name_label.text = "ПРОСТРАНСТВО: \"%s\"" % str(sm.call("get_active_space_name"))

func _on_event_bus_event(event_name: String, payload: Dictionary) -> void:
	if event_name == "agent_state_changed":
		var state := str(payload.get("new_state", "idle"))
		_agent_status_label.text = "СТАТУС АГЕНТА: %s" % state.to_upper()
		_agent_status_label.add_theme_color_override("font_color", DesignTokens.get_agent_state_color(state))
	elif event_name == "network_status_updated":
		var peer_count: int = int(payload.get("peer_count", 0))
		_network_pill_label.text = "● P2P SWARM // %d PEERS" % peer_count

func _on_resume_pressed() -> void:
	if _is_transitioning:
		return
	_is_transitioning = true

	# Кинематика перехода Through the Lens:
	# Стелы плавно раздвигаются, фон растворяется, камера выходит в 3D
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(_left_nav_panel, "position:x", -400.0, DesignTokens.DURATION_FLUID).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUINT)
	tween.tween_property(_right_showcase_panel, "modulate:a", 0.0, DesignTokens.DURATION_FLUID)
	tween.tween_property(_background_grid, "modulate:a", 0.0, DesignTokens.DURATION_FLUID)
	tween.chain().tween_callback(func():
		resume_requested.emit()
		if Engine.has_singleton("EventBus"):
			var eb: Node = Engine.get_singleton("EventBus")
			if eb and eb.has_method("emit"):
				eb.call("emit", "space_resume_requested", {})
		visible = false
	)

func _on_spaces_pressed() -> void:
	spaces_requested.emit()
	if Engine.has_singleton("EventBus"):
		var eb: Node = Engine.get_singleton("EventBus")
		if eb and eb.has_method("emit"):
			eb.call("emit", "open_spaces_requested", {})

func _on_modules_pressed() -> void:
	modules_requested.emit()
	if Engine.has_singleton("EventBus"):
		var eb: Node = Engine.get_singleton("EventBus")
		if eb and eb.has_method("emit"):
			eb.call("emit", "open_modules_requested", {})

func _on_network_pressed() -> void:
	network_requested.emit()
	if Engine.has_singleton("EventBus"):
		var eb: Node = Engine.get_singleton("EventBus")
		if eb and eb.has_method("emit"):
			eb.call("emit", "open_network_requested", {})

func _on_settings_pressed() -> void:
	settings_requested.emit()
	if Engine.has_singleton("EventBus"):
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
