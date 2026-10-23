class_name GlassPanel
extends PanelContainer

const DesignTokens = preload("res://ui/theme/design_tokens.gd")
const CyberTheme = preload("res://ui/theme/cyber_theme.gd")

## UniCORE Optical Quartz Glass Panel Node
## Высокотехнологичная панель из матового стекла:
## - Автоматически монтирует шейдер жидкого стекла (liquid_glass.gdshader)
## - Реагирует на глобальные изменения темы через EventBus
## - Поддерживает физическую дисперсию, фоновый блюр и интерактивный ховер

@export var custom_accent_color: Color = Color(-1, -1, -1, -1)
@export var blur_strength: float = 2.5
@export var panel_corner_radius: float = 4.0
@export var enable_interactive_hover: bool = false
@export var use_shader: bool = true

var _bg_rect: ColorRect
var _shader_mat: ShaderMaterial
var _is_hovered: bool = false

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS
	_setup_background()
	_update_styling()

	if Engine.has_singleton("EventBus"):
		var eb: Node = Engine.get_singleton("EventBus")
		if eb and eb.has_signal("event_emitted"):
			eb.connect("event_emitted", Callable(self, "_on_event_bus_event"))

	if enable_interactive_hover:
		mouse_entered.connect(_on_mouse_entered)
		mouse_exited.connect(_on_mouse_exited)

func _setup_background() -> void:
	if not use_shader:
		_apply_stylebox_fallback()
		return

	# Создаем фоновый ColorRect за контентом панели
	if not _bg_rect:
		_bg_rect = ColorRect.new()
		_bg_rect.name = "GlassBackground"
		_bg_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_bg_rect.show_behind_parent = true
		_bg_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
		add_child(_bg_rect)
		move_child(_bg_rect, 0)

	var is_white: bool = CyberTheme.is_white_theme()
	var opacity: float = CyberTheme.get_glass_opacity()

	_shader_mat = DesignTokens.create_glass_material(
		is_white,
		opacity,
		blur_strength,
		custom_accent_color,
		panel_corner_radius
	)

	if _shader_mat:
		_bg_rect.material = _shader_mat
	else:
		_apply_stylebox_fallback()

func _update_styling() -> void:
	if _shader_mat and use_shader:
		var is_white: bool = CyberTheme.is_white_theme()
		var opacity: float = CyberTheme.get_glass_opacity()
		var led_intensity: float = CyberTheme.get_led_intensity()

		var base_tint: Color
		var rim_col: Color

		if is_white:
			base_tint = Color(DesignTokens.COLOR_GLASS_QUARTZ_LIGHT.r, DesignTokens.COLOR_GLASS_QUARTZ_LIGHT.g, DesignTokens.COLOR_GLASS_QUARTZ_LIGHT.b, opacity)
			rim_col = custom_accent_color if custom_accent_color.a >= 0.0 else DesignTokens.COLOR_ACCENT_ELECTRIC_BLUE
		else:
			base_tint = Color(DesignTokens.COLOR_GLASS_QUARTZ_DARK.r, DesignTokens.COLOR_GLASS_QUARTZ_DARK.g, DesignTokens.COLOR_GLASS_QUARTZ_DARK.b, opacity)
			rim_col = custom_accent_color if custom_accent_color.a >= 0.0 else DesignTokens.COLOR_ACCENT_PRISM_CYAN

		if _is_hovered and enable_interactive_hover:
			rim_col = rim_col.lightened(0.2)
			led_intensity *= 1.3

		_shader_mat.set_shader_parameter("glass_tint", base_tint)
		_shader_mat.set_shader_parameter("blur_amount", blur_strength)
		_shader_mat.set_shader_parameter("rim_color", rim_col)
		_shader_mat.set_shader_parameter("rim_boost", 1.2 * led_intensity)
		_shader_mat.set_shader_parameter("corner_radius", panel_corner_radius)
	else:
		_apply_stylebox_fallback()

func _apply_stylebox_fallback() -> void:
	var sb: StyleBoxFlat = CyberTheme.create_glass_panel_style(
		custom_accent_color,
		Color(-1, -1, -1, -1),
		1,
		int(panel_corner_radius),
		4
	)
	add_theme_stylebox_override("panel", sb)

func _on_event_bus_event(event_name: String, _payload: Dictionary) -> void:
	if event_name == "interface_settings_changed":
		_update_styling()

func _on_mouse_entered() -> void:
	_is_hovered = true
	_update_styling()

func _on_mouse_exited() -> void:
	_is_hovered = false
	_update_styling()

func set_accent_color(col: Color) -> void:
	custom_accent_color = col
	_update_styling()
