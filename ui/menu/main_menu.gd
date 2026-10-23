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
const InputMapperScript = preload("res://core/input_mapper.gd")

var is_open: bool = false

var _settings_manager: Node
var _space_manager: Node
var _module_manager: Node
var _event_bus: Node
var _module_library: Node
var module_gallery: ModuleGallery = null
var _module_gallery: ModuleGallery = null

var _network_transport: Node = null
var _lan_discovery: Node = null
var _module_sharing: Node = null
var _space_sync: Node = null
var _pending_module_offers: Array[Dictionary] = []

# Input Mapper References
var _input_mapper: Node = null
var keybindings_section_panel: PanelContainer = null
var active_bindings_container: VBoxContainer = null
var library_bindings_container: VBoxContainer = null
var system_bindings_container: VBoxContainer = null
var reset_all_bindings_btn: Button = null

# Key Capture Modal
var _key_capture_modal: Control = null
var _key_capture_action: String = ""
var _key_capture_label: String = ""
var _key_capture_module: String = ""
var _key_capture_desc: Label = null
var _key_capture_prompt: Label = null
var _key_capture_conflict_lbl: Label = null
var _key_capture_pending_key: int = KEY_NONE

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

# Network Tab References
@onready var network_tab: MarginContainer = $MainPanel/MarginContainer/VBoxContainer/TabContainer/NetworkTab
@onready var session_status_label: Label = $MainPanel/MarginContainer/VBoxContainer/TabContainer/NetworkTab/Scroll/VBox/SessionSection/VBox/HeaderHBox/StatusLabel
@onready var host_session_btn: Button = $MainPanel/MarginContainer/VBoxContainer/TabContainer/NetworkTab/Scroll/VBox/SessionSection/VBox/ControlsHBox/HostButton
@onready var session_ip_port_edit: LineEdit = $MainPanel/MarginContainer/VBoxContainer/TabContainer/NetworkTab/Scroll/VBox/SessionSection/VBox/ControlsHBox/IpPortEdit
@onready var connect_session_btn: Button = $MainPanel/MarginContainer/VBoxContainer/TabContainer/NetworkTab/Scroll/VBox/SessionSection/VBox/ControlsHBox/ConnectButton
@onready var disconnect_session_btn: Button = $MainPanel/MarginContainer/VBoxContainer/TabContainer/NetworkTab/Scroll/VBox/SessionSection/VBox/ControlsHBox/DisconnectButton

@onready var refresh_lan_btn: Button = $MainPanel/MarginContainer/VBoxContainer/TabContainer/NetworkTab/Scroll/VBox/LanSection/VBox/HeaderHBox/RefreshLanButton
@onready var lan_peers_list: VBoxContainer = $MainPanel/MarginContainer/VBoxContainer/TabContainer/NetworkTab/Scroll/VBox/LanSection/VBox/LanPeersList

@onready var connected_peers_list: VBoxContainer = $MainPanel/MarginContainer/VBoxContainer/TabContainer/NetworkTab/Scroll/VBox/ConnectedSection/VBox/ConnectedPeersList

@onready var offer_module_btn: Button = $MainPanel/MarginContainer/VBoxContainer/TabContainer/NetworkTab/Scroll/VBox/SharingSection/VBox/HeaderHBox/OfferModuleButton
@onready var module_offers_list: VBoxContainer = $MainPanel/MarginContainer/VBoxContainer/TabContainer/NetworkTab/Scroll/VBox/SharingSection/VBox/ModuleOffersList

# Cache UI References
var _semantic_cache: Node = null
var _last_resolved_source: String = "—"
var cache_section_panel: PanelContainer = null
var cache_stats_label: Label = null
var cache_source_label: Label = null
var cache_popular_list: VBoxContainer = null
var clear_cache_btn: Button = null

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
	tab_container.set_tab_title(4, " СЕТЬ ")
	tab_container.set_tab_title(5, " СИСТЕМА ")

	if is_instance_valid(library_tab) and not module_gallery:
		module_gallery = ModuleGalleryScene.instantiate()
		library_tab.add_child(module_gallery)
		_module_gallery = module_gallery

	_apply_styling()
	_setup_base_signals()
	_setup_cache_ui()
	_setup_keybindings_ui()

func setup(settings_mgr: Node, space_mgr: Node, module_mgr: Node, event_bus: Node, module_library: Node = null, transport: Node = null, discovery: Node = null, sharing: Node = null, sync: Node = null, cache: Node = null, input_mapper: Node = null) -> void:
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

	if transport != null or discovery != null:
		setup_network(transport, discovery, sharing, sync)

	if cache != null:
		setup_cache(cache)

	if input_mapper != null:
		setup_input_mapper(input_mapper)

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

	if is_instance_valid(host_session_btn):
		host_session_btn.pressed.connect(_on_host_session_pressed)
	if is_instance_valid(connect_session_btn):
		connect_session_btn.pressed.connect(_on_connect_session_pressed)
	if is_instance_valid(disconnect_session_btn):
		disconnect_session_btn.pressed.connect(_on_disconnect_session_pressed)
	if is_instance_valid(refresh_lan_btn):
		refresh_lan_btn.pressed.connect(func(): update_lan_peers())
	if is_instance_valid(offer_module_btn):
		offer_module_btn.pressed.connect(_on_offer_module_pressed)

func _on_space_error(message: String) -> void:
	if current_space_label:
		current_space_label.text = "ОШИБКА ПРОСТРАНСТВА: %s" % message.to_upper()
		current_space_label.modulate = CyberTheme.COLOR_RED_LED

func _unhandled_input(event: InputEvent) -> void:
	if _key_capture_modal and _key_capture_modal.visible:
		if event is InputEventKey and event.is_pressed() and not event.is_echo():
			var kc: int = event.keycode if event.keycode != 0 else event.physical_keycode
			_handle_captured_key(kc)
			get_viewport().set_input_as_handled()
			return

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
			"network", "net":
				tab_container.current_tab = 4
				update_network_ui()
			"about", "system":
				tab_container.current_tab = 5
			_:
				tab_container.current_tab = 0

	_refresh_spaces_ui()
	_refresh_modules_ui()
	_load_settings_into_ui()
	_refresh_keybindings_ui()
	if _event_bus:
		_event_bus.emit("modal_opened", {"source": "main_menu"})
	menu_opened.emit()

func close() -> void:
	is_open = false
	hide()
	new_space_form.hide()
	save_as_form.hide()
	_close_key_capture()
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

	# Network Buttons Styling
	var net_btn_style := CyberTheme.create_cyber_button_style(
		Color(0.85, 0.91, 0.98, CyberTheme.get_glass_opacity()) if is_white else Color(0.06, 0.12, 0.22, 0.8),
		CyberTheme.COLOR_ELECTRIC_BLUE if is_white else Color(0.0, 0.7, 0.9, 0.4),
		1,
		3
	)
	var net_btn_hover := CyberTheme.create_cyber_button_style(
		Color(0.78, 0.88, 0.98, min(CyberTheme.get_glass_opacity() + 0.1, 1.0)) if is_white else Color(0.09, 0.18, 0.32, 0.95),
		CyberTheme.COLOR_CYAN_GLOW,
		1,
		3
	)
	for b in [host_session_btn, connect_session_btn, disconnect_session_btn, refresh_lan_btn, offer_module_btn]:
		if is_instance_valid(b):
			b.add_theme_stylebox_override("normal", net_btn_style)
			b.add_theme_stylebox_override("hover", net_btn_hover)
			b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
			b.add_theme_color_override("font_color", CyberTheme.COLOR_TEXT_DARK if is_white else CyberTheme.COLOR_TEXT_PRIMARY)
			b.add_theme_color_override("font_hover_color", CyberTheme.COLOR_ELECTRIC_BLUE if is_white else CyberTheme.COLOR_CYAN_GLOW)
			b.add_theme_font_size_override("font_size", 12)

# ----------------------------------------------------
# Network Layer Integration & Handlers
# ----------------------------------------------------

func setup_network(transport: Node, discovery: Node, sharing: Node = null, sync: Node = null) -> void:
	_network_transport = transport
	_lan_discovery = discovery
	_module_sharing = sharing
	_space_sync = sync

	if _network_transport:
		if not _network_transport.connection_status_changed.is_connected(update_network_ui):
			_network_transport.connection_status_changed.connect(update_network_ui)
		if not _network_transport.peer_connected.is_connected(_on_peer_connected_event):
			_network_transport.peer_connected.connect(_on_peer_connected_event)
		if not _network_transport.peer_disconnected.is_connected(_on_peer_disconnected_event):
			_network_transport.peer_disconnected.connect(_on_peer_disconnected_event)

	if _lan_discovery:
		if not _lan_discovery.peer_discovered.is_connected(update_lan_peers):
			_lan_discovery.peer_discovered.connect(update_lan_peers)
		if not _lan_discovery.peer_lost.is_connected(update_lan_peers):
			_lan_discovery.peer_lost.connect(update_lan_peers)

	if _module_sharing:
		if not _module_sharing.module_offered.is_connected(add_module_offer):
			_module_sharing.module_offered.connect(add_module_offer)

	update_network_ui()

func _on_peer_connected_event(_pid: int, _info: Dictionary) -> void:
	_refresh_connected_peers()
	if is_instance_valid(session_status_label) and _network_transport:
		update_network_ui(_network_transport.get_status())

func _on_peer_disconnected_event(_pid: int) -> void:
	_refresh_connected_peers()
	if is_instance_valid(session_status_label) and _network_transport:
		update_network_ui(_network_transport.get_status())

func _on_host_session_pressed() -> void:
	if not _network_transport:
		return
	if _network_transport.is_hosting():
		_network_transport.disconnect_session()
		if _lan_discovery:
			_lan_discovery.stop_broadcasting()
	else:
		var port: int = int(_settings_manager.get_setting("network", "host_port", 7777)) if _settings_manager else 7777
		var err: int = int(_network_transport.host_session(port))
		if err == OK:
			if _lan_discovery and bool(_settings_manager.get_setting("network", "auto_discovery", true) if _settings_manager else true):
				_lan_discovery.start_broadcasting(int(_settings_manager.get_setting("network", "discovery_port", 7778) if _settings_manager else 7778))
	update_network_ui()

func _on_connect_session_pressed() -> void:
	if not _network_transport:
		return
	if _lan_discovery and _network_transport.is_hosting():
		_lan_discovery.stop_broadcasting()
	var text: String = session_ip_port_edit.text.strip_edges() if is_instance_valid(session_ip_port_edit) else "127.0.0.1:7777"
	var addr: String = "127.0.0.1"
	var port: int = int(_settings_manager.get_setting("network", "host_port", 7777)) if _settings_manager else 7777
	if text.contains(":"):
		var parts := text.split(":")
		addr = parts[0].strip_edges()
		if addr.is_empty():
			addr = "127.0.0.1"
		if parts.size() > 1 and parts[1].is_valid_int():
			port = int(parts[1])
	elif not text.is_empty():
		addr = text
	_network_transport.join_session(addr, port)
	update_network_ui()

func _on_disconnect_session_pressed() -> void:
	if _network_transport:
		_network_transport.disconnect_session()
	if _lan_discovery:
		_lan_discovery.stop_broadcasting()
	update_network_ui()

func update_network_ui(_status_str: String = "") -> void:
	var cur_status: String = _network_transport.get_status() if _network_transport else "disconnected"
	var peer_count: int = _network_transport.get_connected_peers().size() if _network_transport else 0

	if cur_status.to_lower() == "disconnected" and _lan_discovery and _lan_discovery.is_broadcasting():
		_lan_discovery.stop_broadcasting()

	if is_instance_valid(session_status_label):
		match cur_status.to_lower():
			"hosting":
				session_status_label.text = "СТАТУС: ХОСТ (УЗЛОВ: %d)" % peer_count
				session_status_label.modulate = CyberTheme.COLOR_CYAN_GLOW
				if is_instance_valid(host_session_btn):
					host_session_btn.text = "ОСТАНОВИТЬ ХОСТ"
				if is_instance_valid(disconnect_session_btn):
					disconnect_session_btn.visible = true
			"connected":
				session_status_label.text = "СТАТУС: ПОДКЛЮЧЕН (УЗЛОВ: %d)" % peer_count
				session_status_label.modulate = CyberTheme.COLOR_SUCCESS_LED
				if is_instance_valid(host_session_btn):
					host_session_btn.text = "СОЗДАТЬ СЕССИЮ (ХОСТ)"
				if is_instance_valid(disconnect_session_btn):
					disconnect_session_btn.visible = true
			"connecting":
				session_status_label.text = "СТАТУС: ПОДКЛЮЧЕНИЕ..."
				session_status_label.modulate = CyberTheme.COLOR_AMBER_LED
				if is_instance_valid(disconnect_session_btn):
					disconnect_session_btn.visible = true
			_:
				session_status_label.text = "СТАТУС: OFFLINE"
				session_status_label.modulate = CyberTheme.COLOR_TEXT_MUTED
				if is_instance_valid(host_session_btn):
					host_session_btn.text = "СОЗДАТЬ СЕССИЮ (ХОСТ)"
				if is_instance_valid(disconnect_session_btn):
					disconnect_session_btn.visible = false

	_refresh_connected_peers()
	update_lan_peers()
	_refresh_module_offers_ui()

func update_lan_peers(_arg: Variant = null) -> void:
	if not is_instance_valid(lan_peers_list):
		return

	for child in lan_peers_list.get_children():
		lan_peers_list.remove_child(child)
		child.queue_free()

	var peers: Array[Dictionary] = []
	if _lan_discovery:
		peers = _lan_discovery.get_discovered_peers()

	if peers.is_empty():
		var empty_lbl := Label.new()
		empty_lbl.text = "Узлы в локальной сети не обнаружены (нажмите [ОБНОВИТЬ])."
		empty_lbl.add_theme_color_override("font_color", CyberTheme.COLOR_TEXT_MUTED)
		empty_lbl.add_theme_font_size_override("font_size", 12)
		lan_peers_list.add_child(empty_lbl)
		return

	var is_white := CyberTheme.is_white_theme()
	for p_info in peers:
		var card := PanelContainer.new()
		var card_style := CyberTheme.create_glass_panel_style(
			Color(0.0, 0.75, 1.0, 0.4) if not is_white else CyberTheme.COLOR_ELECTRIC_BLUE,
			Color(0.03, 0.08, 0.15, 0.75) if not is_white else Color(0.9, 0.94, 0.98, 0.9),
			1,
			3
		)
		card.add_theme_stylebox_override("panel", card_style)

		var hbox := HBoxContainer.new()
		hbox.add_theme_constant_override("separation", 10)

		var p_name: String = str(p_info.get("name", "UniNode"))
		var p_addr: String = str(p_info.get("address", "127.0.0.1"))
		var p_port: int = int(p_info.get("port", 7777))
		var p_mods: int = int(p_info.get("modules_count", 0))

		var info_lbl := Label.new()
		info_lbl.text = "● %s  [%s:%d]  •  Модулей: %d" % [p_name, p_addr, p_port, p_mods]
		info_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		info_lbl.add_theme_color_override("font_color", CyberTheme.COLOR_TEXT_CYAN if not is_white else CyberTheme.COLOR_TEXT_DARK)
		info_lbl.add_theme_font_size_override("font_size", 12)
		hbox.add_child(info_lbl)

		var conn_btn := Button.new()
		conn_btn.text = "ПОДКЛЮЧИТЬСЯ"
		conn_btn.custom_minimum_size = Vector2(110, 26)
		conn_btn.add_theme_font_size_override("font_size", 11)
		var b_style := CyberTheme.create_cyber_button_style(
			Color(0.0, 0.35, 0.55, 0.85) if not is_white else Color(0.8, 0.9, 0.98, 0.9),
			CyberTheme.COLOR_CYAN_GLOW if not is_white else CyberTheme.COLOR_ELECTRIC_BLUE,
			1,
			3
		)
		conn_btn.add_theme_stylebox_override("normal", b_style)
		conn_btn.pressed.connect(func():
			_connect_to_peer_address(p_addr, p_port)
		)
		hbox.add_child(conn_btn)

		card.add_child(hbox)
		lan_peers_list.add_child(card)

func _connect_to_peer_address(address: String, port: int) -> void:
	if is_instance_valid(session_ip_port_edit):
		session_ip_port_edit.text = "%s:%d" % [address, port]
	if _network_transport:
		_network_transport.join_session(address, port)
	update_network_ui()

func _refresh_connected_peers() -> void:
	if not is_instance_valid(connected_peers_list):
		return

	for child in connected_peers_list.get_children():
		connected_peers_list.remove_child(child)
		child.queue_free()

	if not _network_transport:
		return

	var pids: Array[int] = _network_transport.get_connected_peers()
	if pids.is_empty():
		var empty_lbl := Label.new()
		empty_lbl.text = "Нет подключенных узлов."
		empty_lbl.add_theme_color_override("font_color", CyberTheme.COLOR_TEXT_MUTED)
		empty_lbl.add_theme_font_size_override("font_size", 12)
		connected_peers_list.add_child(empty_lbl)
		return

	var is_white := CyberTheme.is_white_theme()
	for pid in pids:
		var p_info: Dictionary = _network_transport.get_peer_info(pid)
		var p_name: String = str(p_info.get("name", "Peer #%d" % pid))
		var p_ip: String = str(p_info.get("ip", "remote"))
		var p_mods: int = int(p_info.get("modules_count", 0))

		var card := PanelContainer.new()
		var card_style := CyberTheme.create_glass_panel_style(
			Color(0.0, 0.85, 0.45, 0.4) if not is_white else CyberTheme.COLOR_ELECTRIC_BLUE,
			Color(0.03, 0.1, 0.08, 0.75) if not is_white else Color(0.9, 0.96, 0.92, 0.9),
			1,
			3
		)
		card.add_theme_stylebox_override("panel", card_style)

		var hbox := HBoxContainer.new()
		hbox.add_theme_constant_override("separation", 10)

		var lbl := Label.new()
		lbl.text = "● [ID: %d] %s (%s)  •  Модулей: %d" % [pid, p_name, p_ip, p_mods]
		lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		lbl.add_theme_color_override("font_color", CyberTheme.COLOR_SUCCESS_LED if not is_white else CyberTheme.COLOR_TEXT_DARK)
		lbl.add_theme_font_size_override("font_size", 12)
		hbox.add_child(lbl)

		var offer_btn := Button.new()
		offer_btn.text = "ПРЕДЛОЖИТЬ МОДУЛЬ"
		offer_btn.custom_minimum_size = Vector2(130, 26)
		offer_btn.add_theme_font_size_override("font_size", 11)
		var b_style := CyberTheme.create_cyber_button_style(
			Color(0.0, 0.35, 0.45, 0.85) if not is_white else Color(0.8, 0.9, 0.98, 0.9),
			CyberTheme.COLOR_CYAN_GLOW,
			1,
			3
		)
		offer_btn.add_theme_stylebox_override("normal", b_style)
		offer_btn.pressed.connect(func():
			_prompt_offer_module_to_peer(pid)
		)
		hbox.add_child(offer_btn)

		card.add_child(hbox)
		connected_peers_list.add_child(card)

func add_module_offer(peer_id: int, module_meta: Dictionary) -> void:
	var mod_id: String = str(module_meta.get("id", ""))
	for i in range(_pending_module_offers.size() - 1, -1, -1):
		var existing: Dictionary = _pending_module_offers[i]
		if existing.get("peer_id", 0) == peer_id and existing.get("module_meta", {}).get("id", "") == mod_id:
			_pending_module_offers.remove_at(i)

	_pending_module_offers.append({
		"peer_id": peer_id,
		"module_meta": module_meta
	})
	_refresh_module_offers_ui()

func _refresh_module_offers_ui() -> void:
	if not is_instance_valid(module_offers_list):
		return

	for child in module_offers_list.get_children():
		module_offers_list.remove_child(child)
		child.queue_free()

	if _pending_module_offers.is_empty():
		var empty_lbl := Label.new()
		empty_lbl.text = "Нет входящих предложений модулей."
		empty_lbl.add_theme_color_override("font_color", CyberTheme.COLOR_TEXT_MUTED)
		empty_lbl.add_theme_font_size_override("font_size", 12)
		module_offers_list.add_child(empty_lbl)
		return

	var is_white := CyberTheme.is_white_theme()
	for i in range(_pending_module_offers.size()):
		var offer: Dictionary = _pending_module_offers[i]
		var pid: int = int(offer.get("peer_id", 0))
		var meta: Dictionary = offer.get("module_meta", {})
		var mod_id: String = str(meta.get("id", "unknown"))
		var mod_name: String = str(meta.get("name", mod_id))
		var mod_sz: int = int(meta.get("size", 0))
		var mod_hash: String = str(meta.get("hash", "")).substr(0, 8)

		var card := PanelContainer.new()
		var card_style := CyberTheme.create_glass_panel_style(
			CyberTheme.COLOR_AMBER_LED,
			Color(0.12, 0.08, 0.02, 0.75) if not is_white else Color(0.98, 0.95, 0.88, 0.9),
			1,
			3
		)
		card.add_theme_stylebox_override("panel", card_style)

		var hbox := HBoxContainer.new()
		hbox.add_theme_constant_override("separation", 10)

		var lbl := Label.new()
		lbl.text = "📦 %s (%s) • %.1f KB • SHA: %s • от Peer #%d" % [
			mod_name, mod_id, mod_sz / 1024.0, mod_hash, pid
		]
		lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		lbl.add_theme_color_override("font_color", CyberTheme.COLOR_AMBER_LED if not is_white else CyberTheme.COLOR_TEXT_DARK)
		lbl.add_theme_font_size_override("font_size", 12)
		hbox.add_child(lbl)

		var accept_btn := Button.new()
		accept_btn.text = "ПРИНЯТЬ"
		accept_btn.custom_minimum_size = Vector2(80, 26)
		accept_btn.add_theme_font_size_override("font_size", 11)
		var acc_style := CyberTheme.create_cyber_button_style(
			Color(0.05, 0.25, 0.15, 0.85) if not is_white else Color(0.85, 0.95, 0.88, 0.9),
			CyberTheme.COLOR_SUCCESS_LED,
			1,
			3
		)
		accept_btn.add_theme_stylebox_override("normal", acc_style)
		var current_offer := offer
		accept_btn.pressed.connect(func():
			if _module_sharing:
				_module_sharing.accept_module(pid, mod_id)
			_pending_module_offers.erase(current_offer)
			_refresh_module_offers_ui()
		)
		hbox.add_child(accept_btn)

		var reject_btn := Button.new()
		reject_btn.text = "ОТКЛОНИТЬ"
		reject_btn.custom_minimum_size = Vector2(80, 26)
		reject_btn.add_theme_font_size_override("font_size", 11)
		var rej_style := CyberTheme.create_cyber_button_style(
			Color(0.25, 0.08, 0.1, 0.85) if not is_white else Color(0.96, 0.86, 0.88, 0.9),
			CyberTheme.COLOR_RED_LED,
			1,
			3
		)
		reject_btn.add_theme_stylebox_override("normal", rej_style)
		reject_btn.pressed.connect(func():
			if _module_sharing:
				_module_sharing.reject_module(pid, mod_id)
			_pending_module_offers.erase(current_offer)
			_refresh_module_offers_ui()
		)
		hbox.add_child(reject_btn)

		card.add_child(hbox)
		module_offers_list.add_child(card)

func _on_offer_module_pressed() -> void:
	if not _network_transport or _network_transport.get_connected_peers().is_empty():
		_show_confirm("Нет подключенных узлов для передачи модулей.", func(): pass)
		return

	var pids: Array[int] = _network_transport.get_connected_peers()
	_prompt_offer_module_to_peer(pids[0])

func _prompt_offer_module_to_peer(target_peer_id: int) -> void:
	if not _module_library:
		return

	var all_mods: Array[Dictionary] = _module_library.get_all_modules()
	if all_mods.is_empty():
		_show_confirm("В библиотеке нет доступных модулей для передачи.", func(): pass)
		return

	if all_mods.size() == 1:
		var mod_id: String = str(all_mods[0].get("id", ""))
		var mod_name: String = str(all_mods[0].get("name", mod_id))
		_show_confirm("Предложить модуль '%s' узлу Peer #%d?" % [mod_name, target_peer_id], func():
			if _module_sharing:
				_module_sharing.offer_module(target_peer_id, mod_id)
		)
		return

	_show_module_selection_for_offer(target_peer_id, all_mods)

func _show_module_selection_for_offer(target_peer_id: int, mods: Array[Dictionary]) -> void:
	var dlg := ConfirmationDialog.new()
	dlg.title = "Выбор модуля для отправки"
	dlg.initial_position = Window.WINDOW_INITIAL_POSITION_CENTER_MAIN_WINDOW_SCREEN
	dlg.size = Vector2i(380, 160)
	dlg.ok_button_text = "Отправить"
	dlg.cancel_button_text = "Отмена"

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)

	var lbl := Label.new()
	lbl.text = "Выберите модуль для отправки пиру Peer #%d:" % target_peer_id
	lbl.add_theme_font_size_override("font_size", 12)
	vbox.add_child(lbl)

	var opt := OptionButton.new()
	for i in range(mods.size()):
		var m: Dictionary = mods[i]
		var mid: String = str(m.get("id", ""))
		var mname: String = str(m.get("name", mid))
		opt.add_item("%s (%s)" % [mname, mid], i)
	vbox.add_child(opt)

	dlg.add_child(vbox)
	add_child(dlg)

	dlg.confirmed.connect(func():
		var sel_idx := opt.get_selected_id()
		if sel_idx >= 0 and sel_idx < mods.size():
			var selected_mod_id: String = str(mods[sel_idx].get("id", ""))
			if _module_sharing:
				_module_sharing.offer_module(target_peer_id, selected_mod_id)
		dlg.queue_free()
	)
	dlg.canceled.connect(func(): dlg.queue_free())
	dlg.popup_centered()

# ----------------------------------------------------
# Semantic Cache UI & Management
# ----------------------------------------------------

func setup_cache(cache: Node) -> void:
	_semantic_cache = cache
	if _semantic_cache and _semantic_cache.has_signal("cache_updated"):
		if not _semantic_cache.cache_updated.is_connected(_on_cache_updated):
			_semantic_cache.cache_updated.connect(_on_cache_updated)
	_refresh_cache_ui()

func update_cache_source(source_type: String) -> void:
	match source_type.to_lower():
		"cache": _last_resolved_source = "🔵 Локальный Кэш"
		"p2p": _last_resolved_source = "🟢 P2P Сеть"
		"registry": _last_resolved_source = "⚪ Реестр шаблонов"
		_: _last_resolved_source = "🟡 Внешнее LLM API"
	_refresh_cache_ui()

func _on_cache_updated(_mod_id: String, _action: String) -> void:
	_refresh_cache_ui()

func _setup_cache_ui() -> void:
	var net_scroll_vbox = get_node_or_null("MainPanel/MarginContainer/VBoxContainer/TabContainer/NetworkTab/Scroll/VBox")
	if not net_scroll_vbox:
		return

	var is_white := CyberTheme.is_white_theme()

	cache_section_panel = PanelContainer.new()
	cache_section_panel.name = "CacheSection"
	var card_style := CyberTheme.create_glass_panel_style(
		Color(0.0, 0.75, 1.0, 0.4) if not is_white else CyberTheme.COLOR_ELECTRIC_BLUE,
		Color(0.03, 0.08, 0.15, 0.75) if not is_white else Color(0.9, 0.94, 0.98, 0.9),
		1,
		4
	)
	cache_section_panel.add_theme_stylebox_override("panel", card_style)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	cache_section_panel.add_child(vbox)

	# Header HBox
	var header_hbox := HBoxContainer.new()
	vbox.add_child(header_hbox)

	var title_lbl := Label.new()
	title_lbl.text = "// СЕМАНТИЧЕСКИЙ КЭШ МОДУЛЕЙ"
	title_lbl.add_theme_color_override("font_color", CyberTheme.COLOR_CYAN_GLOW if not is_white else CyberTheme.COLOR_ELECTRIC_BLUE)
	title_lbl.add_theme_font_size_override("font_size", 14)
	title_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_hbox.add_child(title_lbl)

	clear_cache_btn = Button.new()
	clear_cache_btn.text = "ОЧИСТИТЬ КЭШ"
	clear_cache_btn.custom_minimum_size = Vector2(110, 24)
	clear_cache_btn.add_theme_font_size_override("font_size", 11)
	var clear_btn_style := CyberTheme.create_cyber_button_style(
		Color(0.3, 0.08, 0.1, 0.85) if not is_white else Color(0.95, 0.85, 0.88, 0.9),
		CyberTheme.COLOR_RED_LED,
		1,
		3
	)
	clear_cache_btn.add_theme_stylebox_override("normal", clear_btn_style)
	clear_cache_btn.pressed.connect(_on_clear_cache_pressed)
	header_hbox.add_child(clear_cache_btn)

	# Stats and Source
	var info_hbox := HBoxContainer.new()
	info_hbox.add_theme_constant_override("separation", 16)
	vbox.add_child(info_hbox)

	cache_stats_label = Label.new()
	cache_stats_label.text = "Локальный кэш: 0 модулей • 0 уникальных тегов"
	cache_stats_label.add_theme_color_override("font_color", CyberTheme.COLOR_TEXT_CYAN if not is_white else CyberTheme.COLOR_TEXT_DARK)
	cache_stats_label.add_theme_font_size_override("font_size", 12)
	info_hbox.add_child(cache_stats_label)

	cache_source_label = Label.new()
	cache_source_label.text = "Источник последнего модуля: —"
	cache_source_label.add_theme_color_override("font_color", CyberTheme.COLOR_AMBER_LED if not is_white else CyberTheme.COLOR_TEXT_MUTED)
	cache_source_label.add_theme_font_size_override("font_size", 12)
	info_hbox.add_child(cache_source_label)

	# Popular modules subtitle
	var pop_lbl := Label.new()
	pop_lbl.text = "Популярные модули из кэша (Топ-10):"
	pop_lbl.add_theme_color_override("font_color", CyberTheme.COLOR_TEXT_MUTED)
	pop_lbl.add_theme_font_size_override("font_size", 11)
	vbox.add_child(pop_lbl)

	# Popular modules list
	cache_popular_list = VBoxContainer.new()
	cache_popular_list.add_theme_constant_override("separation", 4)
	vbox.add_child(cache_popular_list)

	net_scroll_vbox.add_child(cache_section_panel)
	_refresh_cache_ui()

func _refresh_cache_ui() -> void:
	if not is_instance_valid(cache_stats_label):
		return

	var mod_count := 0
	var tag_count := 0
	if _semantic_cache != null and is_instance_valid(_semantic_cache):
		if _semantic_cache.has_method("get_total_modules_count"):
			mod_count = _semantic_cache.get_total_modules_count()
		if _semantic_cache.has_method("get_unique_tags"):
			tag_count = _semantic_cache.get_unique_tags().size()

	cache_stats_label.text = "Локальный кэш: %d модулей • %d уникальных тегов" % [mod_count, tag_count]
	if is_instance_valid(cache_source_label):
		cache_source_label.text = "Источник последнего модуля: %s" % _last_resolved_source

	if not is_instance_valid(cache_popular_list):
		return

	for c in cache_popular_list.get_children():
		cache_popular_list.remove_child(c)
		c.queue_free()

	if _semantic_cache == null or not is_instance_valid(_semantic_cache) or mod_count == 0:
		var empty_lbl := Label.new()
		empty_lbl.text = "Кэш пуст. Проверенные модули будут автоматически кэшироваться здесь."
		empty_lbl.add_theme_color_override("font_color", CyberTheme.COLOR_TEXT_MUTED)
		empty_lbl.add_theme_font_size_override("font_size", 11)
		cache_popular_list.add_child(empty_lbl)
		return

	var pop_mods: Array[Dictionary] = []
	if _semantic_cache.has_method("get_popular_modules"):
		pop_mods = _semantic_cache.get_popular_modules(10)

	var is_white := CyberTheme.is_white_theme()
	for m in pop_mods:
		var card := PanelContainer.new()
		var card_style := CyberTheme.create_glass_panel_style(
			CyberTheme.COLOR_CYAN_GLOW if not is_white else CyberTheme.COLOR_ELECTRIC_BLUE,
			Color(0.04, 0.08, 0.14, 0.6) if not is_white else Color(0.92, 0.95, 0.99, 0.8),
			1,
			2
		)
		card.add_theme_stylebox_override("panel", card_style)

		var hbox := HBoxContainer.new()
		hbox.add_theme_constant_override("separation", 8)
		card.add_child(hbox)

		var m_id: String = str(m.get("id", ""))
		var m_name: String = str(m.get("name", m_id))
		var m_uses: int = int(m.get("usage_count", 0))
		var m_rep: float = float(m.get("reputation", 0.0))
		var m_tags: Array = m.get("tags", [])
		var tags_str := ", ".join(m_tags) if not m_tags.is_empty() else "—"

		var lbl := Label.new()
		lbl.text = "📦 %s [%s] • Загрузок: %d • Репутация: %.2f • Теги: %s" % [m_name, m_id, m_uses, m_rep, tags_str]
		lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		lbl.add_theme_color_override("font_color", CyberTheme.COLOR_TEXT_PRIMARY if not is_white else CyberTheme.COLOR_TEXT_DARK)
		lbl.add_theme_font_size_override("font_size", 11)
		hbox.add_child(lbl)

		cache_popular_list.add_child(card)

func _on_clear_cache_pressed() -> void:
	_show_confirm("Вы действительно хотите полностью очистить локальный семантический кэш?", func():
		if _semantic_cache and _semantic_cache.has_method("clear_cache"):
			_semantic_cache.clear_cache()
			_refresh_cache_ui()
	)

# ----------------------------------------------------
# Input Mapper & Keybindings UI
# ----------------------------------------------------

func setup_input_mapper(mapper: Node) -> void:
	_input_mapper = mapper
	if _input_mapper:
		if _input_mapper.has_signal("actions_refreshed") and not _input_mapper.actions_refreshed.is_connected(_refresh_keybindings_ui):
			_input_mapper.actions_refreshed.connect(_refresh_keybindings_ui)
		if _input_mapper.has_signal("bindings_reset") and not _input_mapper.bindings_reset.is_connected(_refresh_keybindings_ui):
			_input_mapper.bindings_reset.connect(_refresh_keybindings_ui)
		if _input_mapper.has_signal("binding_changed") and not _input_mapper.binding_changed.is_connected(func(_a, _o, _n): _refresh_keybindings_ui()):
			_input_mapper.binding_changed.connect(func(_a, _o, _n): _refresh_keybindings_ui())
	_refresh_keybindings_ui()

func _setup_keybindings_ui() -> void:
	var settings_scroll_vbox = get_node_or_null("MainPanel/MarginContainer/VBoxContainer/TabContainer/SettingsTab/Scroll/VBox")
	if not settings_scroll_vbox:
		return

	_setup_key_capture_modal()

	var is_white := CyberTheme.is_white_theme()

	keybindings_section_panel = PanelContainer.new()
	keybindings_section_panel.name = "KeybindingsSection"
	var panel_style := CyberTheme.create_glass_panel_style(
		Color(0.0, 0.75, 1.0, 0.45) if not is_white else CyberTheme.COLOR_ELECTRIC_BLUE,
		Color(0.03, 0.08, 0.15, 0.75) if not is_white else Color(0.9, 0.94, 0.98, 0.9),
		1,
		4
	)
	keybindings_section_panel.add_theme_stylebox_override("panel", panel_style)

	var main_vbox := VBoxContainer.new()
	main_vbox.add_theme_constant_override("separation", 10)
	keybindings_section_panel.add_child(main_vbox)

	# 1. Header & Reset All Button
	var header_hbox := HBoxContainer.new()
	main_vbox.add_child(header_hbox)

	var title_lbl := Label.new()
	title_lbl.text = "// НАЗНАЧЕНИЕ КЛАВИШ УПРАВЛЕНИЯ (INPUT MAPPER)"
	title_lbl.add_theme_color_override("font_color", CyberTheme.COLOR_CYAN_GLOW if not is_white else CyberTheme.COLOR_ELECTRIC_BLUE)
	title_lbl.add_theme_font_size_override("font_size", 14)
	title_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_hbox.add_child(title_lbl)

	reset_all_bindings_btn = Button.new()
	reset_all_bindings_btn.text = "СБРОСИТЬ ВСЕ БИНДЫ"
	reset_all_bindings_btn.custom_minimum_size = Vector2(140, 24)
	reset_all_bindings_btn.add_theme_font_size_override("font_size", 11)
	var reset_btn_style := CyberTheme.create_cyber_button_style(
		Color(0.25, 0.1, 0.12, 0.85) if not is_white else Color(0.95, 0.85, 0.88, 0.9),
		CyberTheme.COLOR_RED_LED,
		1,
		3
	)
	reset_all_bindings_btn.add_theme_stylebox_override("normal", reset_btn_style)
	reset_all_bindings_btn.pressed.connect(_on_reset_all_bindings_pressed)
	header_hbox.add_child(reset_all_bindings_btn)

	var desc_lbl := Label.new()
	desc_lbl.text = "Кликните по кнопке с клавишей для переназначения. Конфликты клавиш определяются и разрешаются автоматически."
	desc_lbl.add_theme_color_override("font_color", CyberTheme.COLOR_TEXT_MUTED)
	desc_lbl.add_theme_font_size_override("font_size", 11)
	main_vbox.add_child(desc_lbl)

	# 2. Section: Active Modules
	var act_header := Label.new()
	act_header.text = "► АКТИВНЫЕ МОДУЛИ (ТЕКУЩЕЕ ПРОСТРАНСТВО)"
	act_header.add_theme_color_override("font_color", CyberTheme.COLOR_CYAN_GLOW)
	act_header.add_theme_font_size_override("font_size", 12)
	main_vbox.add_child(act_header)

	active_bindings_container = VBoxContainer.new()
	active_bindings_container.add_theme_constant_override("separation", 6)
	main_vbox.add_child(active_bindings_container)

	# 3. Section: Library Modules
	var lib_header := Label.new()
	lib_header.text = "► МОДУЛИ ИЗ БИБЛИОТЕКИ"
	lib_header.add_theme_color_override("font_color", CyberTheme.COLOR_ELECTRIC_BLUE)
	lib_header.add_theme_font_size_override("font_size", 12)
	main_vbox.add_child(lib_header)

	library_bindings_container = VBoxContainer.new()
	library_bindings_container.add_theme_constant_override("separation", 6)
	main_vbox.add_child(library_bindings_container)

	# 4. Section: System Hotkeys
	var sys_header := Label.new()
	sys_header.text = "► СИСТЕМНЫЕ ГОРЯЧИЕ КЛАВИШИ UNICORE"
	sys_header.add_theme_color_override("font_color", CyberTheme.COLOR_TEXT_PRIMARY if not is_white else CyberTheme.COLOR_TEXT_DARK)
	sys_header.add_theme_font_size_override("font_size", 12)
	main_vbox.add_child(sys_header)

	system_bindings_container = VBoxContainer.new()
	system_bindings_container.add_theme_constant_override("separation", 6)
	main_vbox.add_child(system_bindings_container)

	settings_scroll_vbox.add_child(keybindings_section_panel)
	_refresh_keybindings_ui()

func _refresh_keybindings_ui() -> void:
	if not is_instance_valid(active_bindings_container) or not is_instance_valid(library_bindings_container) or not is_instance_valid(system_bindings_container):
		return

	for c in active_bindings_container.get_children():
		active_bindings_container.remove_child(c)
		c.queue_free()

	for c in library_bindings_container.get_children():
		library_bindings_container.remove_child(c)
		c.queue_free()

	for c in system_bindings_container.get_children():
		system_bindings_container.remove_child(c)
		c.queue_free()

	if _input_mapper == null or not is_instance_valid(_input_mapper):
		var lbl := Label.new()
		lbl.text = "InputMapper не инициализирован."
		lbl.add_theme_color_override("font_color", CyberTheme.COLOR_TEXT_MUTED)
		lbl.add_theme_font_size_override("font_size", 11)
		active_bindings_container.add_child(lbl)
		return

	# Заполняем активные модули
	var active_groups: Dictionary = _input_mapper.get_actions_grouped_by_module("active")
	if active_groups.is_empty():
		var empty_act := Label.new()
		empty_act.text = "Нет активных модулей с настраиваемым управлением."
		empty_act.add_theme_color_override("font_color", CyberTheme.COLOR_TEXT_MUTED)
		empty_act.add_theme_font_size_override("font_size", 11)
		active_bindings_container.add_child(empty_act)
	else:
		for mod_id in active_groups.keys():
			var grp: Dictionary = active_groups[mod_id]
			var card := _create_module_bindings_card(grp, true)
			active_bindings_container.add_child(card)

	# Заполняем модули из библиотеки
	var lib_groups: Dictionary = _input_mapper.get_actions_grouped_by_module("library")
	if lib_groups.is_empty():
		var empty_lib := Label.new()
		empty_lib.text = "В библиотеке нет незагруженных модулей с элементами управления."
		empty_lib.add_theme_color_override("font_color", CyberTheme.COLOR_TEXT_MUTED)
		empty_lib.add_theme_font_size_override("font_size", 11)
		library_bindings_container.add_child(empty_lib)
	else:
		for mod_id in lib_groups.keys():
			var grp: Dictionary = lib_groups[mod_id]
			var card := _create_module_bindings_card(grp, false)
			library_bindings_container.add_child(card)

	# Заполняем системные горячие клавиши
	var sys_actions: Array[Dictionary] = _input_mapper.get_actions_by_category("system")
	var sys_card := _create_actions_table_card("Система UniCORE", sys_actions, CyberTheme.COLOR_TEXT_PRIMARY)
	system_bindings_container.add_child(sys_card)

func _create_module_bindings_card(group_data: Dictionary, is_active: bool) -> PanelContainer:
	var mod_name: String = group_data.get("name", "Модуль")
	var actions: Array = group_data.get("actions", [])
	var badge_color := CyberTheme.COLOR_CYAN_GLOW if is_active else CyberTheme.COLOR_ELECTRIC_BLUE
	var title_prefix := "[АКТИВЕН] " if is_active else "[БИБЛИОТЕКА] "
	return _create_actions_table_card(title_prefix + mod_name, actions, badge_color)

func _create_actions_table_card(title_str: String, actions: Array, accent_color: Color) -> PanelContainer:
	var is_white := CyberTheme.is_white_theme()
	var card := PanelContainer.new()
	var card_style := CyberTheme.create_glass_panel_style(
		accent_color,
		Color(0.04, 0.08, 0.14, 0.6) if not is_white else Color(0.92, 0.95, 0.99, 0.8),
		1,
		2
	)
	card.add_theme_stylebox_override("panel", card_style)

	var card_vbox := VBoxContainer.new()
	card_vbox.add_theme_constant_override("separation", 6)
	card.add_child(card_vbox)

	var title_lbl := Label.new()
	title_lbl.text = title_str
	title_lbl.add_theme_color_override("font_color", accent_color)
	title_lbl.add_theme_font_size_override("font_size", 12)
	card_vbox.add_child(title_lbl)

	for act in actions:
		var act_dict: Dictionary = act
		var act_name: String = act_dict.get("action", "")
		var act_label: String = act_dict.get("label", act_name)
		var current_key: int = int(act_dict.get("current_key", KEY_NONE))
		var mod_name: String = act_dict.get("module_name", title_str)

		var row_hbox := HBoxContainer.new()
		row_hbox.add_theme_constant_override("separation", 8)
		card_vbox.add_child(row_hbox)

		var act_info_lbl := Label.new()
		act_info_lbl.text = "%s  (%s)" % [act_label, act_name]
		act_info_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		act_info_lbl.add_theme_color_override("font_color", CyberTheme.COLOR_TEXT_PRIMARY if not is_white else CyberTheme.COLOR_TEXT_DARK)
		act_info_lbl.add_theme_font_size_override("font_size", 11)
		row_hbox.add_child(act_info_lbl)

		# Key Button
		var key_btn := Button.new()
		var key_display: String = InputMapperScript.get_key_display_name(current_key)
		key_btn.text = "[ %s ]" % key_display
		key_btn.custom_minimum_size = Vector2(90, 22)
		key_btn.add_theme_font_size_override("font_size", 11)
		var btn_style := CyberTheme.create_cyber_button_style(
			Color(0.08, 0.16, 0.28, 0.85) if not is_white else Color(0.85, 0.92, 0.98, 0.9),
			CyberTheme.COLOR_CYAN_GLOW if not is_white else CyberTheme.COLOR_ELECTRIC_BLUE,
			1,
			2
		)
		key_btn.add_theme_stylebox_override("normal", btn_style)
		key_btn.pressed.connect(func():
			_open_key_capture(act_name, act_label, mod_name)
		)
		row_hbox.add_child(key_btn)

		# Reset button
		var reset_btn := Button.new()
		reset_btn.text = "↺"
		reset_btn.tooltip_text = "Сбросить к клавише по умолчанию"
		reset_btn.custom_minimum_size = Vector2(24, 22)
		reset_btn.add_theme_font_size_override("font_size", 11)
		reset_btn.pressed.connect(func():
			if _input_mapper:
				_input_mapper.reset_action_to_default(act_name)
				_refresh_keybindings_ui()
		)
		row_hbox.add_child(reset_btn)

	return card

func _setup_key_capture_modal() -> void:
	if _key_capture_modal:
		return

	_key_capture_modal = Control.new()
	_key_capture_modal.name = "KeyCaptureModal"
	_key_capture_modal.set_anchors_preset(Control.PRESET_FULL_RECT)
	_key_capture_modal.mouse_filter = Control.MOUSE_FILTER_STOP
	_key_capture_modal.focus_mode = Control.FOCUS_ALL
	_key_capture_modal.visible = false

	var backdrop := ColorRect.new()
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop.color = Color(0.01, 0.02, 0.04, 0.82)
	_key_capture_modal.add_child(backdrop)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_key_capture_modal.add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(460, 220)
	var is_white := CyberTheme.is_white_theme()
	var panel_style := CyberTheme.create_glass_panel_style(
		CyberTheme.COLOR_CYAN_GLOW if not is_white else CyberTheme.COLOR_ELECTRIC_BLUE,
		Color(0.04, 0.07, 0.12, 0.95) if not is_white else Color(0.94, 0.96, 0.99, 0.98),
		2,
		6,
		16,
		Color(0.0, 0.8, 1.0, 0.35)
	)
	panel.add_theme_stylebox_override("panel", panel_style)
	center.add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_top", 18)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_bottom", 18)
	panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	margin.add_child(vbox)

	var title := Label.new()
	title.text = "// НАЗНАЧЕНИЕ КЛАВИШИ УПРАВЛЕНИЯ"
	title.add_theme_color_override("font_color", CyberTheme.COLOR_CYAN_GLOW if not is_white else CyberTheme.COLOR_ELECTRIC_BLUE)
	title.add_theme_font_size_override("font_size", 14)
	vbox.add_child(title)

	_key_capture_desc = Label.new()
	_key_capture_desc.text = "Действие: —"
	_key_capture_desc.add_theme_color_override("font_color", CyberTheme.COLOR_TEXT_PRIMARY if not is_white else CyberTheme.COLOR_TEXT_DARK)
	_key_capture_desc.add_theme_font_size_override("font_size", 13)
	vbox.add_child(_key_capture_desc)

	_key_capture_prompt = Label.new()
	_key_capture_prompt.text = "[ НАЖМИТЕ ЛЮБУЮ КЛАВИШУ... ]"
	_key_capture_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_key_capture_prompt.add_theme_color_override("font_color", CyberTheme.COLOR_CYAN_GLOW)
	_key_capture_prompt.add_theme_font_size_override("font_size", 16)
	vbox.add_child(_key_capture_prompt)

	_key_capture_conflict_lbl = Label.new()
	_key_capture_conflict_lbl.text = ""
	_key_capture_conflict_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_key_capture_conflict_lbl.add_theme_color_override("font_color", CyberTheme.COLOR_AMBER_LED)
	_key_capture_conflict_lbl.add_theme_font_size_override("font_size", 11)
	_key_capture_conflict_lbl.visible = false
	vbox.add_child(_key_capture_conflict_lbl)

	var btn_hbox := HBoxContainer.new()
	btn_hbox.alignment = BoxContainer.ALIGNMENT_END
	vbox.add_child(btn_hbox)

	var cancel_btn := Button.new()
	cancel_btn.text = "Отмена (Esc)"
	cancel_btn.custom_minimum_size = Vector2(100, 30)
	var cancel_btn_style := CyberTheme.create_cyber_button_style(
		Color(0.2, 0.25, 0.32, 0.8),
		CyberTheme.COLOR_TEXT_MUTED,
		1,
		3
	)
	cancel_btn.add_theme_stylebox_override("normal", cancel_btn_style)
	cancel_btn.pressed.connect(_close_key_capture)
	btn_hbox.add_child(cancel_btn)

	add_child(_key_capture_modal)

func _open_key_capture(action_name: String, action_label: String, module_name: String) -> void:
	_setup_key_capture_modal()
	_key_capture_action = action_name
	_key_capture_label = action_label
	_key_capture_module = module_name
	_key_capture_pending_key = KEY_NONE

	if _key_capture_desc:
		_key_capture_desc.text = "Модуль: %s\nДействие: %s (%s)" % [module_name, action_label, action_name]
	if _key_capture_prompt:
		_key_capture_prompt.text = "[ НАЖМИТЕ ЛЮБУЮ КЛАВИШУ... ]"
		_key_capture_prompt.add_theme_color_override("font_color", CyberTheme.COLOR_CYAN_GLOW)
	if _key_capture_conflict_lbl:
		_key_capture_conflict_lbl.text = ""
		_key_capture_conflict_lbl.hide()

	if _key_capture_modal:
		_key_capture_modal.show()
		_key_capture_modal.grab_focus()

func _close_key_capture() -> void:
	if _key_capture_modal:
		_key_capture_modal.hide()
	_key_capture_action = ""
	_key_capture_label = ""
	_key_capture_module = ""
	_key_capture_pending_key = KEY_NONE

func _handle_captured_key(kc: int) -> void:
	if kc == KEY_ESCAPE and _key_capture_pending_key == KEY_NONE:
		_close_key_capture()
		return

	if _input_mapper:
		var conflict: Dictionary = _input_mapper.check_conflict(_key_capture_action, kc)
		if conflict.get("has_conflict", false) == true and _key_capture_pending_key != kc:
			_key_capture_pending_key = kc
			var key_name := InputMapperScript.get_key_display_name(kc)
			var other_lbl: String = str(conflict.get("conflicting_label", ""))
			var other_mod: String = str(conflict.get("conflicting_module", ""))
			if _key_capture_conflict_lbl:
				_key_capture_conflict_lbl.text = "⚠️ Клавиша [%s] уже используется действием '%s' (%s)!\nНажмите клавишу [%s] еще раз для подтверждения или Esc для отмены." % [key_name, other_lbl, other_mod, key_name]
				_key_capture_conflict_lbl.show()
			if _key_capture_prompt:
				_key_capture_prompt.text = "[ НАЖМИТЕ ЕЩЕ РАЗ ДЛЯ ПЕРЕНАЗНАЧЕНИЯ ]"
				_key_capture_prompt.add_theme_color_override("font_color", CyberTheme.COLOR_AMBER_LED)
			return

		_input_mapper.rebind_action(_key_capture_action, kc, true)

	_close_key_capture()
	_refresh_keybindings_ui()

func _on_reset_all_bindings_pressed() -> void:
	_show_confirm("Сбросить все назначения клавиш управления к значениям по умолчанию?", func():
		if _input_mapper:
			_input_mapper.reset_all_to_defaults()
			_refresh_keybindings_ui()
	)
