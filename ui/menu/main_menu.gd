class_name MainMenu
extends Control

## Главное меню UniCORE (Pause / Main Menu Shell)
## Реализовано в стиле "Detroit: Become Human" (матовое стекло, неоновые линии,
## LED-индикация, управление Пространствами, Настройки, Модули и Справка).

signal menu_closed
signal menu_opened

const SettingsManagerScript = preload("res://core/settings_manager.gd")
const SpaceManagerScript = preload("res://core/space_manager.gd")
const ModuleGalleryScene = preload("res://ui/module_gallery/module_gallery.tscn")

var is_open: bool = false

var _settings_manager: Node
var _space_manager: Node
var _module_manager: Node
var _event_bus: Node
var _module_library: Node
var module_gallery: ModuleGallery = null
var _module_gallery: ModuleGallery = null

# Node References
@onready var modal_backdrop: ColorRect = $ModalBackdrop
@onready var main_panel: PanelContainer = $MainPanel
@onready var tab_container: TabContainer = $MainPanel/MarginContainer/VBoxContainer/TabContainer
@onready var close_btn: Button = $MainPanel/MarginContainer/VBoxContainer/HeaderHBox/CloseButton
@onready var resume_btn: Button = $MainPanel/MarginContainer/VBoxContainer/FooterHBox/ResumeButton
@onready var quit_btn: Button = $MainPanel/MarginContainer/VBoxContainer/FooterHBox/QuitButton

# Spaces Tab References
@onready var current_space_label: Label = $MainPanel/MarginContainer/VBoxContainer/TabContainer/SpacesTab/VBox/CurrentSpaceBanner/CurrentSpaceLabel
@onready var btn_quick_save: Button = $MainPanel/MarginContainer/VBoxContainer/TabContainer/SpacesTab/VBox/ActionsHBox/QuickSaveButton
@onready var btn_show_new_space: Button = $MainPanel/MarginContainer/VBoxContainer/TabContainer/SpacesTab/VBox/ActionsHBox/NewSpaceButton
@onready var btn_show_save_as: Button = $MainPanel/MarginContainer/VBoxContainer/TabContainer/SpacesTab/VBox/ActionsHBox/SaveAsButton

@onready var new_space_form: PanelContainer = $MainPanel/MarginContainer/VBoxContainer/TabContainer/SpacesTab/VBox/NewSpaceForm
@onready var new_space_name_edit: LineEdit = $MainPanel/MarginContainer/VBoxContainer/TabContainer/SpacesTab/VBox/NewSpaceForm/VBox/NameEdit
@onready var new_space_template_opt: OptionButton = $MainPanel/MarginContainer/VBoxContainer/TabContainer/SpacesTab/VBox/NewSpaceForm/VBox/TemplateOption
@onready var new_space_create_btn: Button = $MainPanel/MarginContainer/VBoxContainer/TabContainer/SpacesTab/VBox/NewSpaceForm/VBox/ButtonsHBox/CreateButton
@onready var new_space_cancel_btn: Button = $MainPanel/MarginContainer/VBoxContainer/TabContainer/SpacesTab/VBox/NewSpaceForm/VBox/ButtonsHBox/CancelButton

@onready var save_as_form: PanelContainer = $MainPanel/MarginContainer/VBoxContainer/TabContainer/SpacesTab/VBox/SaveAsForm
@onready var save_as_name_edit: LineEdit = $MainPanel/MarginContainer/VBoxContainer/TabContainer/SpacesTab/VBox/SaveAsForm/VBox/SaveAsNameEdit
@onready var save_as_confirm_btn: Button = $MainPanel/MarginContainer/VBoxContainer/TabContainer/SpacesTab/VBox/SaveAsForm/VBox/ButtonsHBox/ConfirmButton
@onready var save_as_cancel_btn: Button = $MainPanel/MarginContainer/VBoxContainer/TabContainer/SpacesTab/VBox/SaveAsForm/VBox/ButtonsHBox/CancelButton

@onready var spaces_list_container: VBoxContainer = $MainPanel/MarginContainer/VBoxContainer/TabContainer/SpacesTab/VBox/Scroll/SpacesList

# Settings Tab References
@onready var fullscreen_check: CheckBox = $MainPanel/MarginContainer/VBoxContainer/TabContainer/SettingsTab/Scroll/VBox/DisplaySection/FullscreenCheck
@onready var resolution_opt: OptionButton = $MainPanel/MarginContainer/VBoxContainer/TabContainer/SettingsTab/Scroll/VBox/DisplaySection/ResolutionOption
@onready var vsync_check: CheckBox = $MainPanel/MarginContainer/VBoxContainer/TabContainer/SettingsTab/Scroll/VBox/DisplaySection/VsyncCheck
@onready var fps_opt: OptionButton = $MainPanel/MarginContainer/VBoxContainer/TabContainer/SettingsTab/Scroll/VBox/DisplaySection/FpsOption

# Interface Section References
@onready var interface_theme_opt: OptionButton = $MainPanel/MarginContainer/VBoxContainer/TabContainer/SettingsTab/Scroll/VBox/InterfaceSection/ThemeOption
@onready var glass_opacity_slider: HSlider = $MainPanel/MarginContainer/VBoxContainer/TabContainer/SettingsTab/Scroll/VBox/InterfaceSection/OpacitySlider
@onready var glass_opacity_val_label: Label = $MainPanel/MarginContainer/VBoxContainer/TabContainer/SettingsTab/Scroll/VBox/InterfaceSection/OpacityValLabel
@onready var led_intensity_slider: HSlider = $MainPanel/MarginContainer/VBoxContainer/TabContainer/SettingsTab/Scroll/VBox/InterfaceSection/LedSlider
@onready var led_intensity_val_label: Label = $MainPanel/MarginContainer/VBoxContainer/TabContainer/SettingsTab/Scroll/VBox/InterfaceSection/LedValLabel
@onready var prompt_autoclose_check: CheckBox = $MainPanel/MarginContainer/VBoxContainer/TabContainer/SettingsTab/Scroll/VBox/InterfaceSection/AutocloseCheck

@onready var mouse_sens_slider: HSlider = $MainPanel/MarginContainer/VBoxContainer/TabContainer/SettingsTab/Scroll/VBox/ControlsSection/SensitivitySlider
@onready var mouse_sens_val_label: Label = $MainPanel/MarginContainer/VBoxContainer/TabContainer/SettingsTab/Scroll/VBox/ControlsSection/SensitivityValLabel
@onready var invert_y_check: CheckBox = $MainPanel/MarginContainer/VBoxContainer/TabContainer/SettingsTab/Scroll/VBox/ControlsSection/InvertYCheck
@onready var move_speed_slider: HSlider = $MainPanel/MarginContainer/VBoxContainer/TabContainer/SettingsTab/Scroll/VBox/ControlsSection/SpeedSlider
@onready var move_speed_val_label: Label = $MainPanel/MarginContainer/VBoxContainer/TabContainer/SettingsTab/Scroll/VBox/ControlsSection/SpeedValLabel

@onready var master_vol_slider: HSlider = $MainPanel/MarginContainer/VBoxContainer/TabContainer/SettingsTab/Scroll/VBox/AudioSection/VolumeSlider
@onready var master_vol_val_label: Label = $MainPanel/MarginContainer/VBoxContainer/TabContainer/SettingsTab/Scroll/VBox/AudioSection/VolumeValLabel

@onready var agent_provider_opt: OptionButton = $MainPanel/MarginContainer/VBoxContainer/TabContainer/SettingsTab/Scroll/VBox/AgentSection/ProviderOption
@onready var agent_model_edit: LineEdit = $MainPanel/MarginContainer/VBoxContainer/TabContainer/SettingsTab/Scroll/VBox/AgentSection/ModelEdit
@onready var agent_key_edit: LineEdit = $MainPanel/MarginContainer/VBoxContainer/TabContainer/SettingsTab/Scroll/VBox/AgentSection/KeyEdit
@onready var save_settings_btn: Button = $MainPanel/MarginContainer/VBoxContainer/TabContainer/SettingsTab/Scroll/VBox/SaveSettingsButton

# Library & Modules Tab References
@onready var library_tab: MarginContainer = $MainPanel/MarginContainer/VBoxContainer/TabContainer/LibraryTab
@onready var modules_list_container: VBoxContainer = $MainPanel/MarginContainer/VBoxContainer/TabContainer/ModulesTab/Scroll/ModulesList

# Confirm Dialog
@onready var confirm_dialog: ConfirmationDialog = $ConfirmDialog

func _ready() -> void:
	hide()
	new_space_form.hide()
	save_as_form.hide()

	# Detroit: Become Human Tabs naming
	tab_container.set_tab_title(0, " ПРОСТРАНСТВА ")
	tab_container.set_tab_title(1, " НАСТРОЙКИ ")
	tab_container.set_tab_title(2, " БИБЛИОТЕКА ")
	tab_container.set_tab_title(3, " МОДУЛИ ")
	tab_container.set_tab_title(4, " СИСТЕМА ")

	if is_instance_valid(library_tab) and not module_gallery:
		module_gallery = ModuleGalleryScene.instantiate()
		library_tab.add_child(module_gallery)
		_module_gallery = module_gallery

	_apply_styling()
	_setup_base_signals()

func setup(settings_mgr: Node, space_mgr: Node, module_mgr: Node, event_bus: Node, module_library: Node = null) -> void:
	_settings_manager = settings_mgr
	_space_manager = space_mgr
	_module_manager = module_mgr
	_event_bus = event_bus
	_module_library = module_library

	if module_gallery and _module_library:
		module_gallery.setup(_module_library, _module_manager)

	if _space_manager:
		_space_manager.space_loaded.connect(_on_space_loaded)
		_space_manager.space_list_updated.connect(_on_space_list_updated)
		_refresh_spaces_ui()

	if _settings_manager:
		_settings_manager.setting_changed.connect(_on_setting_changed)

	if _module_manager:
		_module_manager.module_loaded.connect(func(_id, _inst): _refresh_modules_ui())
		_module_manager.module_unloaded.connect(func(_id): _refresh_modules_ui())

	_load_settings_into_ui()

func _setup_base_signals() -> void:
	close_btn.pressed.connect(close)
	resume_btn.pressed.connect(close)
	quit_btn.pressed.connect(_on_quit_pressed)

	btn_show_new_space.pressed.connect(func():
		new_space_form.visible = not new_space_form.visible
		save_as_form.hide()
		if new_space_form.visible:
			new_space_name_edit.grab_focus()
	)
	new_space_cancel_btn.pressed.connect(func(): new_space_form.hide())
	new_space_create_btn.pressed.connect(_on_create_space_clicked)

	btn_show_save_as.pressed.connect(func():
		save_as_form.visible = not save_as_form.visible
		new_space_form.hide()
		if save_as_form.visible:
			if _space_manager:
				save_as_name_edit.text = "%s (Copy)" % _space_manager.current_space_name
			save_as_name_edit.grab_focus()
	)
	save_as_cancel_btn.pressed.connect(func(): save_as_form.hide())
	save_as_confirm_btn.pressed.connect(_on_save_as_clicked)

	btn_quick_save.pressed.connect(func():
		if _space_manager:
			_space_manager.save_current_space()
			_refresh_spaces_ui()
	)

	# Settings controls
	fullscreen_check.toggled.connect(func(pressed):
		if _settings_manager:
			_settings_manager.set_fullscreen(pressed)
	)
	resolution_opt.item_selected.connect(func(idx):
		if _settings_manager:
			_settings_manager.set_resolution_by_index(idx)
	)
	vsync_check.toggled.connect(func(pressed):
		if _settings_manager:
			_settings_manager.set_vsync(pressed)
	)
	fps_opt.item_selected.connect(func(idx):
		var fps_vals := [0, 60, 120, 144]
		if idx >= 0 and idx < fps_vals.size() and _settings_manager:
			_settings_manager.set_setting("display", "fps_limit", fps_vals[idx])
			Engine.max_fps = fps_vals[idx]
	)

	# Interface controls
	if is_instance_valid(interface_theme_opt):
		interface_theme_opt.item_selected.connect(func(idx: int):
			var th_name := "cyberlife_white" if idx == 0 else "cyber_void"
			if _settings_manager:
				_settings_manager.set_setting("interface", "theme", th_name, true)
			_apply_styling()
		)

	if is_instance_valid(glass_opacity_slider):
		glass_opacity_slider.value_changed.connect(func(val: float):
			if is_instance_valid(glass_opacity_val_label):
				glass_opacity_val_label.text = "%d%%" % int(round(val * 100.0))
			if _settings_manager:
				_settings_manager.set_setting("interface", "glass_opacity", val, true)
			_apply_styling()
		)

	if is_instance_valid(led_intensity_slider):
		led_intensity_slider.value_changed.connect(func(val: float):
			if is_instance_valid(led_intensity_val_label):
				led_intensity_val_label.text = "%d%%" % int(round(val * 100.0))
			if _settings_manager:
				_settings_manager.set_setting("interface", "led_intensity", val, true)
			_apply_styling()
		)

	if is_instance_valid(prompt_autoclose_check):
		prompt_autoclose_check.toggled.connect(func(pressed: bool):
			if _settings_manager:
				_settings_manager.set_setting("interface", "prompt_bar_autoclose", pressed, true)
		)

	mouse_sens_slider.value_changed.connect(func(val):
		mouse_sens_val_label.text = "%.4f" % val
		if _settings_manager:
			_settings_manager.set_mouse_sensitivity(val)
	)
	invert_y_check.toggled.connect(func(pressed):
		if _settings_manager:
			_settings_manager.set_invert_y(pressed)
	)
	move_speed_slider.value_changed.connect(func(val):
		move_speed_val_label.text = "%.1f m/s" % val
		if _settings_manager:
			_settings_manager.set_move_speed(val)
	)

	master_vol_slider.value_changed.connect(func(val):
		master_vol_val_label.text = "%d%%" % int(val * 100.0)
		if _settings_manager:
			_settings_manager.set_master_volume(val)
	)

	save_settings_btn.pressed.connect(_on_save_settings_pressed)


func _on_space_error(message: String) -> void:
	if current_space_label:
		current_space_label.text = "ОШИБКА ПРОСТРАНСТВА: %s" % message.to_upper()
		current_space_label.modulate = CyberTheme.COLOR_RED_LED

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.is_pressed() and not event.is_echo():
		if event.keycode == KEY_ESCAPE:
			if is_open:
				close()
				get_viewport().set_input_as_handled()

func toggle() -> void:
	if is_open:
		close()
	else:
		open()

func open(target_tab: String = "") -> void:
	is_open = true
	show()
	if DisplayServer.has_feature(DisplayServer.FEATURE_MOUSE):
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

	if not target_tab.is_empty():
		match target_tab.to_lower():
			"spaces":
				tab_container.current_tab = 0
			"settings":
				tab_container.current_tab = 1
			"library", "gallery":
				tab_container.current_tab = 2
				if module_gallery and module_gallery.has_method("refresh_gallery"):
					module_gallery.refresh_gallery()
			"modules":
				tab_container.current_tab = 3
			"about", "system":
				tab_container.current_tab = 4
			_:
				tab_container.current_tab = 0

	_refresh_spaces_ui()
	_refresh_modules_ui()
	_load_settings_into_ui()
	if _event_bus:
		_event_bus.emit("modal_opened", {"source": "main_menu"})
	menu_opened.emit()

func close() -> void:
	is_open = false
	hide()
	new_space_form.hide()
	save_as_form.hide()
	if _event_bus:
		_event_bus.emit("modal_closed", {"source": "main_menu"})
	menu_closed.emit()

func _on_space_loaded(_data: Dictionary) -> void:
	_refresh_spaces_ui()
	_refresh_modules_ui()

func _on_space_list_updated(_spaces: Array) -> void:
	_refresh_spaces_ui()

func _refresh_spaces_ui() -> void:
	if not _space_manager or not is_instance_valid(current_space_label):
		return

	var current_name: String = _space_manager.current_space_name
	var current_id: String = _space_manager.current_space_id
	var mod_count: int = 0
	if _module_manager:
		mod_count = _module_manager.get_active_module_ids().size()

	current_space_label.text = "ТЕКУЩЕЕ ПРОСТРАНСТВО: %s (ID: %s) | АКТИВНЫХ МОДУЛЕЙ: %d" % [current_name.to_upper(), current_id, mod_count]

	# Очистка списка
	for child in spaces_list_container.get_children():
		child.queue_free()

	var spaces: Array[Dictionary] = _space_manager.list_spaces()
	for s_info in spaces:
		var sid: String = s_info.get("id", "")
		var sname: String = s_info.get("name", "Unnamed")
		var sdate: String = s_info.get("updated_at", "")
		var smods: int = s_info.get("module_count", 0)
		var stemplate: String = s_info.get("template", "custom")
		var is_current: bool = (sid == current_id)

		var card := PanelContainer.new()
		var card_style := CyberTheme.create_glass_panel_style(
			CyberTheme.COLOR_CYAN_GLOW if is_current else Color(0.0, 0.6, 0.8, 0.3),
			Color(0.05, 0.09, 0.16, 0.85),
			1,
			4
		)
		card.add_theme_stylebox_override("panel", card_style)

		var hbox := HBoxContainer.new()
		hbox.add_theme_constant_override("separation", 12)

		var info_vbox := VBoxContainer.new()
		info_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL

		var title_lbl := Label.new()
		title_lbl.text = sname + (" [АКТИВНО]" if is_current else "")
		title_lbl.add_theme_color_override("font_color", CyberTheme.COLOR_CYAN_GLOW if is_current else CyberTheme.COLOR_TEXT_PRIMARY)
		title_lbl.add_theme_font_size_override("font_size", 14)
		info_vbox.add_child(title_lbl)

		var meta_lbl := Label.new()
		meta_lbl.text = "Шаблон: %s | Модулей: %d | Изменено: %s" % [stemplate, smods, sdate]
		meta_lbl.add_theme_color_override("font_color", CyberTheme.COLOR_TEXT_MUTED)
		meta_lbl.add_theme_font_size_override("font_size", 11)
		info_vbox.add_child(meta_lbl)

		hbox.add_child(info_vbox)

		# Кнопка Загрузить
		var load_btn := Button.new()
		load_btn.text = "ЗАГРУЗИТЬ"
		load_btn.disabled = is_current
		load_btn.custom_minimum_size = Vector2(100, 30)
		load_btn.add_theme_font_size_override("font_size", 12)
		var btn_style := CyberTheme.create_cyber_button_style(Color(0.08, 0.16, 0.28, 0.8), CyberTheme.COLOR_CYAN_GLOW, 1, 3)
		load_btn.add_theme_stylebox_override("normal", btn_style)
		load_btn.pressed.connect(func():
			_space_manager.load_space(sid)
			_refresh_spaces_ui()
		)
		hbox.add_child(load_btn)

		# Кнопка Удалить
		var del_btn := Button.new()
		del_btn.text = "УДАЛИТЬ"
		del_btn.custom_minimum_size = Vector2(80, 30)
		del_btn.add_theme_font_size_override("font_size", 12)
		var del_style := CyberTheme.create_cyber_button_style(Color(0.2, 0.05, 0.08, 0.8), CyberTheme.COLOR_RED_LED, 1, 3)
		del_btn.add_theme_stylebox_override("normal", del_style)
		del_btn.pressed.connect(func():
			_show_confirm("Удалить пространство '%s'?" % sname, func():
				_space_manager.delete_space(sid)
			)
		)
		hbox.add_child(del_btn)

		card.add_child(hbox)
		spaces_list_container.add_child(card)

func _refresh_modules_ui() -> void:
	if not _module_manager or not is_instance_valid(modules_list_container):
		return

	for child in modules_list_container.get_children():
		child.queue_free()

	var active_ids: Array = _module_manager.get_active_module_ids()
	if active_ids.is_empty():
		var empty_lbl := Label.new()
		empty_lbl.text = "Нет загруженных модулей."
		empty_lbl.add_theme_color_override("font_color", CyberTheme.COLOR_TEXT_MUTED)
		modules_list_container.add_child(empty_lbl)
		return

	for mod_id in active_ids:
		var inst: Node = _module_manager.get_module(mod_id)
		var is_enabled := true
		var mod_title: String = mod_id
		if inst and is_instance_valid(inst):
			is_enabled = (inst.process_mode != Node.PROCESS_MODE_DISABLED)
			if inst.has_method("get_module_name"):
				mod_title = inst.get_module_name()

		var card := PanelContainer.new()
		var card_style := CyberTheme.create_glass_panel_style(
			Color(0.0, 0.7, 0.9, 0.3),
			Color(0.04, 0.08, 0.14, 0.8),
			1,
			3
		)
		card.add_theme_stylebox_override("panel", card_style)

		var hbox := HBoxContainer.new()
		hbox.add_theme_constant_override("separation", 12)

		var chk := CheckBox.new()
		chk.text = "%s (%s)" % [mod_title, mod_id]
		chk.button_pressed = is_enabled
		chk.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		chk.add_theme_font_size_override("font_size", 13)
		chk.toggled.connect(func(pressed: bool):
			if inst and is_instance_valid(inst):
				inst.process_mode = Node.PROCESS_MODE_INHERIT if pressed else Node.PROCESS_MODE_DISABLED
				if inst is Node3D or inst is CanvasItem:
					inst.visible = pressed
		)
		hbox.add_child(chk)

		var unload_btn := Button.new()
		unload_btn.text = "ВЫГРУЗИТЬ"
		unload_btn.custom_minimum_size = Vector2(90, 28)
		unload_btn.add_theme_font_size_override("font_size", 11)
		var u_style := CyberTheme.create_cyber_button_style(Color(0.18, 0.08, 0.1, 0.7), CyberTheme.COLOR_RED_LED, 1, 3)
		unload_btn.add_theme_stylebox_override("normal", u_style)
		unload_btn.pressed.connect(func():
			_module_manager.unload_module(mod_id)
		)
		hbox.add_child(unload_btn)

		card.add_child(hbox)
		modules_list_container.add_child(card)

func _load_settings_into_ui() -> void:
	if not _settings_manager:
		return

	if is_instance_valid(fullscreen_check):
		fullscreen_check.set_pressed_no_signal(bool(_settings_manager.get_setting("display", "fullscreen", false)))
	if is_instance_valid(vsync_check):
		vsync_check.set_pressed_no_signal(bool(_settings_manager.get_setting("display", "vsync", true)))

	var res_idx: int = int(_settings_manager.get_setting("display", "resolution_index", 0))
	if is_instance_valid(resolution_opt) and res_idx >= 0 and res_idx < resolution_opt.item_count:
		resolution_opt.selected = res_idx

	var fps_limit: int = int(_settings_manager.get_setting("display", "fps_limit", 0))
	if is_instance_valid(fps_opt):
		match fps_limit:
			0: fps_opt.selected = 0
			60: fps_opt.selected = 1
			120: fps_opt.selected = 2
			144: fps_opt.selected = 3
			_: fps_opt.selected = 0

	# Interface settings
	var cur_theme: String = str(_settings_manager.get_setting("interface", "theme", "cyberlife_white"))
	if is_instance_valid(interface_theme_opt):
		interface_theme_opt.selected = 0 if cur_theme == "cyberlife_white" else 1

	var cur_opacity: float = float(_settings_manager.get_setting("interface", "glass_opacity", 0.75))
	if is_instance_valid(glass_opacity_slider):
		glass_opacity_slider.set_value_no_signal(cur_opacity)
	if is_instance_valid(glass_opacity_val_label):
		glass_opacity_val_label.text = "%d%%" % int(round(cur_opacity * 100.0))

	var cur_led: float = float(_settings_manager.get_setting("interface", "led_intensity", 1.0))
	if is_instance_valid(led_intensity_slider):
		led_intensity_slider.set_value_no_signal(cur_led)
	if is_instance_valid(led_intensity_val_label):
		led_intensity_val_label.text = "%d%%" % int(round(cur_led * 100.0))

	var cur_autoclose: bool = bool(_settings_manager.get_setting("interface", "prompt_bar_autoclose", true))
	if is_instance_valid(prompt_autoclose_check):
		prompt_autoclose_check.set_pressed_no_signal(cur_autoclose)

	var sens: float = float(_settings_manager.get_setting("controls", "mouse_sensitivity", 0.002))
	if is_instance_valid(mouse_sens_slider):
		mouse_sens_slider.set_value_no_signal(sens)
	if is_instance_valid(mouse_sens_val_label):
		mouse_sens_val_label.text = "%.4f" % sens

	if is_instance_valid(invert_y_check):
		invert_y_check.set_pressed_no_signal(bool(_settings_manager.get_setting("controls", "invert_y", false)))

	var spd: float = float(_settings_manager.get_setting("controls", "move_speed", 10.0))
	if is_instance_valid(move_speed_slider):
		move_speed_slider.set_value_no_signal(spd)
	if is_instance_valid(move_speed_val_label):
		move_speed_val_label.text = "%.1f m/s" % spd

	var vol: float = float(_settings_manager.get_setting("audio", "master_volume", 0.8))
	if is_instance_valid(master_vol_slider):
		master_vol_slider.set_value_no_signal(vol)
	if is_instance_valid(master_vol_val_label):
		master_vol_val_label.text = "%d%%" % int(vol * 100.0)

	var prov: String = str(_settings_manager.get_setting("agent", "provider", "gemini"))
	if is_instance_valid(agent_provider_opt):
		match prov:
			"gemini": agent_provider_opt.selected = 0
			"openrouter": agent_provider_opt.selected = 1
			"openai": agent_provider_opt.selected = 2
			"deepseek": agent_provider_opt.selected = 3
			_: agent_provider_opt.selected = 0

	if is_instance_valid(agent_model_edit):
		agent_model_edit.text = str(_settings_manager.get_setting("agent", "model", "gemini-2.5-flash"))
	if is_instance_valid(agent_key_edit):
		agent_key_edit.text = str(_settings_manager.get_setting("agent", "api_key", ""))

func _on_save_settings_pressed() -> void:
	if not _settings_manager:
		return

	var prov_names := ["gemini", "openrouter", "openai", "deepseek"]
	var selected_prov: String = prov_names[agent_provider_opt.selected] if agent_provider_opt.selected < prov_names.size() else "gemini"

	_settings_manager.set_agent_config(selected_prov, agent_model_edit.text.strip_edges(), agent_key_edit.text.strip_edges())
	_settings_manager.save_settings()
	_settings_manager.apply_all_settings()

func _on_setting_changed(category: String, key: String, value: Variant) -> void:
	if category == "display":
		if key == "fullscreen" and is_instance_valid(fullscreen_check):
			fullscreen_check.set_pressed_no_signal(bool(value))
		elif key == "vsync" and is_instance_valid(vsync_check):
			vsync_check.set_pressed_no_signal(bool(value))
		elif key == "resolution_index" and is_instance_valid(resolution_opt):
			var idx: int = int(value)
			if idx >= 0 and idx < resolution_opt.item_count:
				resolution_opt.selected = idx
		elif key == "fps_limit" and is_instance_valid(fps_opt):
			match int(value):
				0: fps_opt.selected = 0
				60: fps_opt.selected = 1
				120: fps_opt.selected = 2
				144: fps_opt.selected = 3
				_: fps_opt.selected = 0
	elif category == "controls":
		if key == "mouse_sensitivity" and is_instance_valid(mouse_sens_slider):
			var sens: float = float(value)
			mouse_sens_slider.set_value_no_signal(sens)
			if is_instance_valid(mouse_sens_val_label):
				mouse_sens_val_label.text = "%.4f" % sens
		elif key == "invert_y" and is_instance_valid(invert_y_check):
			invert_y_check.set_pressed_no_signal(bool(value))
		elif key == "move_speed" and is_instance_valid(move_speed_slider):
			var spd: float = float(value)
			move_speed_slider.set_value_no_signal(spd)
			if is_instance_valid(move_speed_val_label):
				move_speed_val_label.text = "%.1f m/s" % spd
	elif category == "audio":
		if key == "master_volume" and is_instance_valid(master_vol_slider):
			var vol: float = float(value)
			master_vol_slider.set_value_no_signal(vol)
			if is_instance_valid(master_vol_val_label):
				master_vol_val_label.text = "%d%%" % int(vol * 100.0)
	elif category == "interface":
		if key == "theme" and is_instance_valid(interface_theme_opt):
			var th_str: String = str(value)
			interface_theme_opt.selected = 0 if th_str == "cyberlife_white" else 1
			_apply_styling()
		elif key == "glass_opacity" and is_instance_valid(glass_opacity_slider):
			var op_val: float = float(value)
			glass_opacity_slider.set_value_no_signal(op_val)
			if is_instance_valid(glass_opacity_val_label):
				glass_opacity_val_label.text = "%d%%" % int(round(op_val * 100.0))
			_apply_styling()
		elif key == "led_intensity" and is_instance_valid(led_intensity_slider):
			var led_val: float = float(value)
			led_intensity_slider.set_value_no_signal(led_val)
			if is_instance_valid(led_intensity_val_label):
				led_intensity_val_label.text = "%d%%" % int(round(led_val * 100.0))
			_apply_styling()
		elif key == "prompt_bar_autoclose" and is_instance_valid(prompt_autoclose_check):
			prompt_autoclose_check.set_pressed_no_signal(bool(value))

func _on_create_space_clicked() -> void:
	if not _space_manager:
		return

	var sname: String = new_space_name_edit.text.strip_edges()
	if sname.is_empty():
		sname = "New Space"

	var template_map := ["default", "cyber_void", "clean_slate", "tool_studio"]
	var t_idx: int = new_space_template_opt.selected
	var template_type: String = template_map[t_idx] if t_idx < template_map.size() else "default"

	_space_manager.create_new_space(sname, template_type)
	new_space_form.hide()
	new_space_name_edit.text = ""
	_refresh_spaces_ui()

func _on_save_as_clicked() -> void:
	if not _space_manager:
		return

	var new_name: String = save_as_name_edit.text.strip_edges()
	if not new_name.is_empty():
		_space_manager.save_space_as(new_name)
		save_as_form.hide()
		_refresh_spaces_ui()

func _on_quit_pressed() -> void:
	_show_confirm("Вы действительно хотите выйти из UniCORE?", func():
		get_tree().quit()
	)

func _show_confirm(text: String, on_ok: Callable) -> void:
	confirm_dialog.dialog_text = text
	# Disconnect any previous ok connections
	for conn in confirm_dialog.confirmed.get_connections():
		confirm_dialog.confirmed.disconnect(conn.callable)
	confirm_dialog.confirmed.connect(on_ok, CONNECT_ONE_SHOT)
	confirm_dialog.popup_centered()

func _apply_styling() -> void:
	var is_white := CyberTheme.is_white_theme()

	# Фоновый полупрозрачный блюр-оверлей
	if is_white:
		modal_backdrop.color = Color(0.85, 0.9, 0.96, 0.55)
	else:
		modal_backdrop.color = Color(0.01, 0.02, 0.05, 0.75)

	# Главная панель в стиле Detroit Liquid Glass
	var main_style := CyberTheme.create_glass_panel_style(
		CyberTheme.COLOR_CYAN_GLOW if not is_white else CyberTheme.COLOR_ELECTRIC_BLUE,
		Color(-1, -1, -1, -1),
		2,
		6,
		int(round(6 * CyberTheme.get_led_intensity()))
	)
	main_panel.add_theme_stylebox_override("panel", main_style)

	var subpanel_style := CyberTheme.create_glass_panel_style(
		CyberTheme.COLOR_ELECTRIC_BLUE if is_white else Color(0.0, 0.75, 1.0, 0.4),
		Color(-1, -1, -1, -1),
		1,
		4,
		int(round(4 * CyberTheme.get_led_intensity()))
	)
	new_space_form.add_theme_stylebox_override("panel", subpanel_style)
	save_as_form.add_theme_stylebox_override("panel", subpanel_style)

	# Применение кибер-темы к TabContainer
	tab_container.theme = CyberTheme.build_theme()

	# Кнопка закрытия (Header Close Button)
	var close_btn_style := CyberTheme.create_cyber_button_style(
		Color(0.95, 0.85, 0.85, 0.8) if is_white else Color(0.18, 0.05, 0.08, 0.7),
		CyberTheme.COLOR_RED_LED,
		1,
		3
	)
	var close_btn_hover := CyberTheme.create_cyber_button_style(
		Color(1.0, 0.8, 0.8, 0.95) if is_white else Color(0.35, 0.08, 0.12, 0.95),
		Color(1.0, 0.4, 0.4, 1.0),
		1,
		3
	)
	close_btn.add_theme_stylebox_override("normal", close_btn_style)
	close_btn.add_theme_stylebox_override("hover", close_btn_hover)
	close_btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	close_btn.add_theme_color_override("font_color", CyberTheme.COLOR_RED_LED if is_white else Color.WHITE)

	# Кнопки действий Пространств
	var action_btn_style := CyberTheme.create_cyber_button_style(
		Color(0.85, 0.91, 0.98, CyberTheme.get_glass_opacity()) if is_white else Color(0.06, 0.12, 0.22, 0.8),
		CyberTheme.COLOR_ELECTRIC_BLUE if is_white else Color(0.0, 0.7, 0.9, 0.4),
		1,
		3
	)
	var action_btn_hover := CyberTheme.create_cyber_button_style(
		Color(0.78, 0.88, 0.98, min(CyberTheme.get_glass_opacity() + 0.1, 1.0)) if is_white else Color(0.09, 0.18, 0.32, 0.95),
		CyberTheme.COLOR_CYAN_GLOW,
		1,
		3
	)
	for b in [btn_show_new_space, btn_quick_save, btn_show_save_as]:
		b.add_theme_stylebox_override("normal", action_btn_style)
		b.add_theme_stylebox_override("hover", action_btn_hover)
		b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
		b.add_theme_color_override("font_color", CyberTheme.COLOR_TEXT_DARK if is_white else CyberTheme.COLOR_TEXT_PRIMARY)
		b.add_theme_color_override("font_hover_color", CyberTheme.COLOR_ELECTRIC_BLUE if is_white else CyberTheme.COLOR_CYAN_GLOW)
		b.add_theme_font_size_override("font_size", 12)

	# Кнопка сохранения настроек
	var save_btn_style := CyberTheme.create_cyber_button_style(
		Color(0.8, 0.9, 0.98, 0.9) if is_white else Color(0.0, 0.3, 0.5, 0.85),
		CyberTheme.COLOR_ELECTRIC_BLUE if is_white else CyberTheme.COLOR_CYAN_GLOW,
		1,
		4
	)
	var save_btn_hover := CyberTheme.create_cyber_button_style(
		Color(0.7, 0.85, 0.98, 0.98) if is_white else Color(0.0, 0.45, 0.75, 0.95),
		CyberTheme.COLOR_CYAN_GLOW if is_white else Color.WHITE,
		2,
		4
	)
	save_settings_btn.add_theme_stylebox_override("normal", save_btn_style)
	save_settings_btn.add_theme_stylebox_override("hover", save_btn_hover)
	save_settings_btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	save_settings_btn.add_theme_color_override("font_color", CyberTheme.COLOR_ELECTRIC_BLUE if is_white else CyberTheme.COLOR_CYAN_GLOW)
	save_settings_btn.add_theme_color_override("font_hover_color", CyberTheme.COLOR_CYAN_GLOW if is_white else Color.WHITE)

	# Стили кнопок футера
	var resume_style := CyberTheme.create_cyber_button_style(
		Color(0.8, 0.9, 0.98, 0.9) if is_white else Color(0.0, 0.35, 0.55, 0.85),
		CyberTheme.COLOR_ELECTRIC_BLUE if is_white else CyberTheme.COLOR_CYAN_GLOW,
		1,
		4
	)
	var resume_hover := CyberTheme.create_cyber_button_style(
		Color(0.7, 0.85, 0.98, 0.98) if is_white else Color(0.0, 0.5, 0.8, 0.95),
		CyberTheme.COLOR_CYAN_GLOW if is_white else Color.WHITE,
		2,
		4
	)
	resume_btn.add_theme_stylebox_override("normal", resume_style)
	resume_btn.add_theme_stylebox_override("hover", resume_hover)
	resume_btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	resume_btn.add_theme_color_override("font_color", CyberTheme.COLOR_ELECTRIC_BLUE if is_white else Color.WHITE)

	var quit_style := CyberTheme.create_cyber_button_style(
		Color(0.96, 0.86, 0.88, 0.8) if is_white else Color(0.2, 0.06, 0.08, 0.75),
		CyberTheme.COLOR_RED_LED,
		1,
		4
	)
	var quit_hover := CyberTheme.create_cyber_button_style(
		Color(1.0, 0.8, 0.84, 0.95) if is_white else Color(0.38, 0.08, 0.12, 0.95),
		Color(1.0, 0.4, 0.4, 1.0),
		2,
		4
	)
	quit_btn.add_theme_stylebox_override("normal", quit_style)
	quit_btn.add_theme_stylebox_override("hover", quit_hover)
	quit_btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	quit_btn.add_theme_color_override("font_color", CyberTheme.COLOR_RED_LED if is_white else Color.WHITE)
