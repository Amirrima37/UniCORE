class_name InputMapperOverlay
extends Control

## UniCORE High-End Input Mapper & Keybindings Overlay
## Премиальная панель конфигурации управления в стиле "Detroit Liquid Glass":
## - Группировка действий: Системные, Активные модули, Библиотека
## - Живой поиск и фильтрация действий на лету
## - Стилизованные 1px титановые кейкапы клавиш [ KEY ]
## - Кинематографичный модальный диалог захвата клавиши ("Press any key")
## - Детекция и разрешение конфликтов с янтарной индикацией

signal closed
signal key_rebound(action: String, keycode: int)

const DesignTokens = preload("res://ui/theme/design_tokens.gd")
const GlassPanelScript = preload("res://ui/theme/glass_panel.gd")
const InputMapperScript = preload("res://core/input_mapper.gd")

var _input_mapper: Node = null

# Основные контейнеры UI
var _modal_backdrop: ColorRect
var _main_window: PanelContainer
var _search_edit: LineEdit
var _category_buttons_hbox: HBoxContainer
var _scroll_container: ScrollContainer
var _cards_vbox: VBoxContainer
var _selected_category: String = "all" # all, system, active, library
var _search_filter: String = ""

# Модальное окно перехвата клавиши
var _capture_modal: Control
var _capture_backdrop: ColorRect
var _capture_panel: PanelContainer
var _capture_action_label: Label
var _capture_prompt_label: Label
var _capture_conflict_label: Label
var _capture_pulse_time: float = 0.0

var _target_action: String = ""
var _target_action_label: String = ""
var _target_module_name: String = ""
var _pending_conflict_key: int = KEY_NONE

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_build_ui_layout()
	_setup_capture_modal()

func setup(mapper: Node) -> void:
	_input_mapper = mapper
	if _input_mapper:
		if _input_mapper.has_signal("actions_refreshed") and not _input_mapper.actions_refreshed.is_connected(refresh_list):
			_input_mapper.actions_refreshed.connect(refresh_list)
		if _input_mapper.has_signal("bindings_reset") and not _input_mapper.bindings_reset.is_connected(refresh_list):
			_input_mapper.bindings_reset.connect(refresh_list)
		if _input_mapper.has_signal("binding_changed"):
			_input_mapper.binding_changed.connect(func(_a, _o, _n): refresh_list())
	refresh_list()

func _build_ui_layout() -> void:
	# 1. Полупрозрачная подложка с блюром
	_modal_backdrop = ColorRect.new()
	_modal_backdrop.name = "ModalBackdrop"
	_modal_backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	_modal_backdrop.color = Color(0.02, 0.03, 0.05, 0.85)
	var glass_mat := DesignTokens.create_glass_material(false, 0.85, 3.0)
	if glass_mat:
		_modal_backdrop.material = glass_mat
	add_child(_modal_backdrop)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)

	# 2. Главное стеклянное окно (820x600)
	_main_window = GlassPanelScript.new()
	_main_window.name = "InputMapperWindow"
	_main_window.custom_minimum_size = Vector2(820, 600)
	center.add_child(_main_window)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_bottom", 20)
	_main_window.add_child(margin)

	var root_vbox := VBoxContainer.new()
	root_vbox.add_theme_constant_override("separation", 14)
	margin.add_child(root_vbox)

	# 3. Верхний Header окна
	var header_hbox := HBoxContainer.new()
	root_vbox.add_child(header_hbox)

	var title_vbox := VBoxContainer.new()
	title_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_hbox.add_child(title_vbox)

	var tag_lbl := Label.new()
	tag_lbl.text = "// КОНФИГУРАЦИЯ УПРАВЛЕНИЯ"
	tag_lbl.add_theme_color_override("font_color", DesignTokens.COLOR_ACCENT_PRISM_CYAN)
	tag_lbl.add_theme_font_size_override("font_size", 11)
	title_vbox.add_child(tag_lbl)

	var header_lbl := Label.new()
	header_lbl.text = "МЕНЕДЖЕР ГОРЯЧИХ КЛАВИШ (INPUT MAPPER)"
	header_lbl.add_theme_color_override("font_color", DesignTokens.COLOR_TEXT_TITANIUM)
	header_lbl.add_theme_font_size_override("font_size", 16)
	title_vbox.add_child(header_lbl)

	# Кнопка сброса всех биндов
	var reset_all_btn := Button.new()
	reset_all_btn.text = "СБРОСИТЬ ВСЕ"
	reset_all_btn.custom_minimum_size = Vector2(120, 28)
	reset_all_btn.pressed.connect(_on_reset_all_pressed)
	header_hbox.add_child(reset_all_btn)

	# Кнопка закрытия окна
	var close_btn := Button.new()
	close_btn.text = "✕"
	close_btn.custom_minimum_size = Vector2(32, 28)
	close_btn.pressed.connect(func():
		closed.emit()
		visible = false
	)
	header_hbox.add_child(close_btn)

	# 4. Панель фильтрации и поиска
	var filter_hbox := HBoxContainer.new()
	filter_hbox.add_theme_constant_override("separation", 10)
	root_vbox.add_child(filter_hbox)

	_search_edit = LineEdit.new()
	_search_edit.placeholder_text = "Поиск действия или модуля... (W, Jump, Menu)"
	_search_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_search_edit.text_changed.connect(_on_search_changed)
	filter_hbox.add_child(_search_edit)

	# Вкладки фильтрации категорий
	_category_buttons_hbox = HBoxContainer.new()
	_category_buttons_hbox.add_theme_constant_override("separation", 6)
	filter_hbox.add_child(_category_buttons_hbox)

	_add_category_tab("ВСЕ", "all")
	_add_category_tab("СИСТЕМНЫЕ", "system")
	_add_category_tab("АКТИВНЫЕ", "active")
	_add_category_tab("БИБЛИОТЕКА", "library")

	var sep := HSeparator.new()
	root_vbox.add_child(sep)

	# 5. Прокручиваемый список карточек действий
	_scroll_container = ScrollContainer.new()
	_scroll_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root_vbox.add_child(_scroll_container)

	_cards_vbox = VBoxContainer.new()
	_cards_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_cards_vbox.add_theme_constant_override("separation", 12)
	_scroll_container.add_child(_cards_vbox)

func _add_category_tab(label_text: String, cat_id: String) -> void:
	var btn := Button.new()
	btn.text = label_text
	btn.custom_minimum_size = Vector2(80, 28)
	btn.pressed.connect(func():
		_selected_category = cat_id
		refresh_list()
	)
	_category_buttons_hbox.add_child(btn)

func _on_search_changed(new_text: String) -> void:
	_search_filter = new_text.strip_edges().to_lower()
	refresh_list()

func refresh_list() -> void:
	if not _cards_vbox:
		return

	for c in _cards_vbox.get_children():
		_cards_vbox.remove_child(c)
		c.queue_free()

	if _input_mapper == null:
		var empty_lbl := Label.new()
		empty_lbl.text = "InputMapper не подключен."
		empty_lbl.add_theme_color_override("font_color", DesignTokens.COLOR_TEXT_MUTED)
		_cards_vbox.add_child(empty_lbl)
		return

	# Получаем действия по категориям
	if _selected_category == "all" or _selected_category == "active":
		var active_groups: Dictionary = _input_mapper.call("get_actions_grouped_by_module", "active")
		_render_module_groups("АКТИВНЫЕ МОДУЛИ", active_groups, DesignTokens.COLOR_ACCENT_PRISM_CYAN)

	if _selected_category == "all" or _selected_category == "system":
		var sys_actions: Array = _input_mapper.call("get_actions_by_category", "system")
		var sys_group := {"system": {"name": "Система UniCORE", "actions": sys_actions}}
		_render_module_groups("СИСТЕМНЫЕ КЛАВИШИ", sys_group, DesignTokens.COLOR_TEXT_TITANIUM)

	if _selected_category == "all" or _selected_category == "library":
		var lib_groups: Dictionary = _input_mapper.call("get_actions_grouped_by_module", "library")
		_render_module_groups("МОДУЛИ БИБЛИОТЕКИ", lib_groups, DesignTokens.COLOR_ACCENT_ELECTRIC_BLUE)

func _render_module_groups(section_header: String, groups: Dictionary, accent_col: Color) -> void:
	if groups.is_empty():
		return

	for mod_id in groups.keys():
		var grp: Dictionary = groups[mod_id]
		var mod_name: String = str(grp.get("name", mod_id))
		var actions: Array = grp.get("actions", [])

		# Фильтрация по поиску
		var filtered_actions: Array = []
		for act in actions:
			var act_dict: Dictionary = act
			var act_label: String = str(act_dict.get("label", ""))
			var act_name: String = str(act_dict.get("action", ""))
			if _search_filter.is_empty() or _search_filter in act_label.to_lower() or _search_filter in act_name.to_lower() or _search_filter in mod_name.to_lower():
				filtered_actions.append(act_dict)

		if filtered_actions.is_empty():
			continue

		var card := _build_module_card(mod_name, filtered_actions, accent_col)
		_cards_vbox.add_child(card)

func _build_module_card(module_title: String, actions: Array, accent_col: Color) -> PanelContainer:
	var card := GlassPanelScript.new()
	card.custom_accent_color = accent_col
	card.panel_corner_radius = 2.0

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	card.add_child(vbox)

	var title_lbl := Label.new()
	title_lbl.text = "► %s" % module_title.to_upper()
	title_lbl.add_theme_color_override("font_color", accent_col)
	title_lbl.add_theme_font_size_override("font_size", 12)
	vbox.add_child(title_lbl)

	for act in actions:
		var act_dict: Dictionary = act
		var act_name: String = str(act_dict.get("action", ""))
		var act_label: String = str(act_dict.get("label", act_name))
		var current_key: int = int(act_dict.get("current_key", KEY_NONE))

		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		vbox.add_child(row)

		var lbl := Label.new()
		lbl.text = "%s  (%s)" % [act_label, act_name]
		lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		lbl.add_theme_color_override("font_color", DesignTokens.COLOR_TEXT_SECONDARY)
		lbl.add_theme_font_size_override("font_size", 12)
		row.add_child(lbl)

		# Кнопка-кейкап клавиши [ KEY ]
		var key_display := InputMapperScript.get_key_display_name(current_key)
		var key_btn := Button.new()
		key_btn.text = "[ %s ]" % key_display
		key_btn.custom_minimum_size = Vector2(96, 26)

		var sb_key := StyleBoxFlat.new()
		sb_key.bg_color = Color(0.06, 0.1, 0.16, 0.8)
		sb_key.border_width_left = 1
		sb_key.border_width_top = 1
		sb_key.border_width_right = 1
		sb_key.border_width_bottom = 1
		sb_key.border_color = DesignTokens.COLOR_ACCENT_PRISM_CYAN
		sb_key.corner_radius_top_left = 2
		sb_key.corner_radius_top_right = 2
		sb_key.corner_radius_bottom_right = 2
		sb_key.corner_radius_bottom_left = 2
		key_btn.add_theme_stylebox_override("normal", sb_key)
		key_btn.add_theme_color_override("font_color", DesignTokens.COLOR_TEXT_TITANIUM)

		key_btn.pressed.connect(func():
			_open_capture_dialog(act_name, act_label, module_title)
		)
		row.add_child(key_btn)

		# Кнопка сброса к дефолту
		var reset_btn := Button.new()
		reset_btn.text = "↺"
		reset_btn.custom_minimum_size = Vector2(26, 26)
		reset_btn.tooltip_text = "Сбросить к клавише по умолчанию"
		reset_btn.pressed.connect(func():
			if _input_mapper:
				_input_mapper.call("reset_action_to_default", act_name)
				refresh_list()
		)
		row.add_child(reset_btn)

	return card

# ==============================================================================
# МОДАЛЬНЫЙ ДИАЛОГ ПЕРЕХВАТА КЛАВИШИ
# ==============================================================================

func _setup_capture_modal() -> void:
	_capture_modal = Control.new()
	_capture_modal.name = "KeyCaptureModal"
	_capture_modal.set_anchors_preset(Control.PRESET_FULL_RECT)
	_capture_modal.mouse_filter = Control.MOUSE_FILTER_STOP
	_capture_modal.visible = false
	add_child(_capture_modal)

	_capture_backdrop = ColorRect.new()
	_capture_backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	_capture_backdrop.color = Color(0.01, 0.02, 0.04, 0.88)
	var modal_glass := DesignTokens.create_glass_material(false, 0.9, 4.0)
	if modal_glass:
		_capture_backdrop.material = modal_glass
	_capture_modal.add_child(_capture_backdrop)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_capture_modal.add_child(center)

	_capture_panel = GlassPanelScript.new()
	_capture_panel.name = "CapturePanel"
	_capture_panel.custom_minimum_size = Vector2(480, 220)
	_capture_panel.custom_accent_color = DesignTokens.COLOR_ACCENT_PRISM_CYAN
	center.add_child(_capture_panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_bottom", 20)
	_capture_panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 14)
	margin.add_child(vbox)

	var title := Label.new()
	title.text = "// НАЗНАЧЕНИЕ КЛАВИШИ"
	title.add_theme_color_override("font_color", DesignTokens.COLOR_ACCENT_PRISM_CYAN)
	title.add_theme_font_size_override("font_size", 12)
	vbox.add_child(title)

	_capture_action_label = Label.new()
	_capture_action_label.text = "Действие: —"
	_capture_action_label.add_theme_color_override("font_color", DesignTokens.COLOR_TEXT_TITANIUM)
	vbox.add_child(_capture_action_label)

	_capture_prompt_label = Label.new()
	_capture_prompt_label.text = "[ НАЖМИТЕ ЛЮБУЮ КЛАВИШУ... ]"
	_capture_prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_capture_prompt_label.add_theme_color_override("font_color", DesignTokens.COLOR_ACCENT_PRISM_CYAN)
	_capture_prompt_label.add_theme_font_size_override("font_size", 15)
	vbox.add_child(_capture_prompt_label)

	_capture_conflict_label = Label.new()
	_capture_conflict_label.text = ""
	_capture_conflict_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_capture_conflict_label.add_theme_color_override("font_color", DesignTokens.COLOR_ACCENT_SPECTRAL_AMBER)
	_capture_conflict_label.add_theme_font_size_override("font_size", 11)
	_capture_conflict_label.visible = false
	vbox.add_child(_capture_conflict_label)

	var cancel_btn := Button.new()
	cancel_btn.text = "Отмена (Esc)"
	cancel_btn.size_flags_horizontal = Control.SIZE_SHRINK_END
	cancel_btn.pressed.connect(_close_capture_dialog)
	vbox.add_child(cancel_btn)

func _open_capture_dialog(action_name: String, action_label: String, module_name: String) -> void:
	_target_action = action_name
	_target_action_label = action_label
	_target_module_name = module_name
	_pending_conflict_key = KEY_NONE

	_capture_action_label.text = "Модуль: %s\nДействие: %s (%s)" % [module_name, action_label, action_name]
	_capture_prompt_label.text = "[ НАЖМИТЕ ЛЮБУЮ КЛАВИШУ... ]"
	_capture_prompt_label.add_theme_color_override("font_color", DesignTokens.COLOR_ACCENT_PRISM_CYAN)
	_capture_conflict_label.text = ""
	_capture_conflict_label.visible = false

	_capture_modal.visible = true

func _close_capture_dialog() -> void:
	_capture_modal.visible = false
	_target_action = ""
	_target_action_label = ""
	_target_module_name = ""
	_pending_conflict_key = KEY_NONE

func _process(delta: float) -> void:
	if _capture_modal and _capture_modal.visible:
		_capture_pulse_time += delta
		var pulse := sin(_capture_pulse_time * 4.0) * 0.35 + 0.65
		var cur_col: Color = _capture_prompt_label.get_theme_color("font_color")
		cur_col.a = pulse
		_capture_prompt_label.add_theme_color_override("font_color", cur_col)

func _input(event: InputEvent) -> void:
	if not _capture_modal or not _capture_modal.visible:
		return

	if event is InputEventKey and event.is_pressed():
		var kc: int = event.keycode
		if kc == KEY_ESCAPE and _pending_conflict_key == KEY_NONE:
			_close_capture_dialog()
			get_viewport().set_input_as_handled()
			return

		if _input_mapper:
			var conflict: Dictionary = _input_mapper.call("check_conflict", _target_action, kc)
			if conflict.get("has_conflict", false) == true and _pending_conflict_key != kc:
				_pending_conflict_key = kc
				var key_name: String = InputMapperScript.get_key_display_name(kc)
				var other_lbl: String = str(conflict.get("conflicting_label", ""))
				var other_mod: String = str(conflict.get("conflicting_module", ""))

				_capture_conflict_label.text = "⚠️ Клавиша [%s] уже используется действием '%s' (%s)!\nНажмите [%s] еще раз для подтверждения или Esc для отмены." % [key_name, other_lbl, other_mod, key_name]
				_capture_conflict_label.visible = true

				_capture_prompt_label.text = "[ НАЖМИТЕ ЕЩЕ РАЗ ДЛЯ ПЕРЕНАЗНАЧЕНИЯ ]"
				_capture_prompt_label.add_theme_color_override("font_color", DesignTokens.COLOR_ACCENT_SPECTRAL_AMBER)
				get_viewport().set_input_as_handled()
				return

			_input_mapper.call("rebind_action", _target_action, kc, true)
			key_rebound.emit(_target_action, kc)

		_close_capture_dialog()
		refresh_list()
		get_viewport().set_input_as_handled()

func _on_reset_all_pressed() -> void:
	if _input_mapper:
		_input_mapper.call("reset_all_to_defaults", true)
		refresh_list()
