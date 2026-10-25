class_name DesignTokens
extends RefCounted

## UniCORE Global Design System & Design Tokens Foundation
## Чистый архитектурный фундамент визуального языка UniCORE:
## - Цветовая палитра: Первородный Обсидиан (Void), Оптический Кварц (Liquid Glass), Спектральная Дисперсия
## - Метрическая система: 8-пиксельная швейцарская сетка, 1px Hairlines, прецизионные радиусы скругления
## - Временные и кинетические константы (Tween easing/durations)
## - Полная отчуждаемость (Decoupled): чистый слой данных и фабрика стилей без завязки на ядро

# ==============================================================================
# 1. ЦВЕТОВАЯ ПАЛИТРА (THE VOID & THE SPECTRUM)
# ==============================================================================

# 1.1 Первородный Обсидиан (Void Base)
const COLOR_VOID_DEEP := Color(0.024, 0.027, 0.035, 1.0)       # #060709: Абсолютная глубина космоса
const COLOR_VOID_SURFACE := Color(0.043, 0.051, 0.067, 1.0)    # #0B0D11: Базовый темный фон
const COLOR_VOID_ELEVATED := Color(0.071, 0.082, 0.106, 1.0)   # #12151B: Поднятые панели и карточки

# 1.2 Оптический Кварц (Liquid Glass & Refraction)
const COLOR_GLASS_QUARTZ_DARK := Color(0.05, 0.08, 0.14, 0.72)  # Темное оптическое кварцевое стекло
const COLOR_GLASS_QUARTZ_LIGHT := Color(0.93, 0.96, 0.99, 0.82) # Лабораторное арктическое белое стекло
const COLOR_GLASS_HAIRLINE := Color(1.0, 1.0, 1.0, 0.14)        # 1px прецизионный контур
const COLOR_GLASS_SPECULAR := Color(1.0, 1.0, 1.0, 0.28)        # Верхний скользящий блик света
const COLOR_GLASS_SHADOW := Color(0.0, 0.0, 0.0, 0.45)          # Физическая тень отсечения

# 1.3 Титановый контраст и Типографика
const COLOR_TEXT_TITANIUM := Color(0.94, 0.96, 0.98, 1.0)       # #F0F5FA: Первичный текст высокой читаемости
const COLOR_TEXT_SECONDARY := Color(0.68, 0.73, 0.80, 0.85)     # #ADBACD: Вторичный текст, подписи
const COLOR_TEXT_MUTED := Color(0.42, 0.47, 0.55, 0.65)         # #6B788C: Служебная телеметрия, таймкоды
const COLOR_TEXT_DARK := Color(0.08, 0.12, 0.18, 1.0)           # Текст для белого лабораторного режима
const COLOR_TEXT_DARK_MUTED := Color(0.35, 0.42, 0.52, 0.85)    # Приглушенный текст для белого режима

# 1.3.1 Шрифты типографики UniCORE
const FONT_SANS_PATH := "res://ui/assets/fonts/tech_sans.ttf"
const FONT_BOLD_PATH := "res://ui/assets/fonts/tech_sans_bold.ttf"
const FONT_MONO_PATH := "res://ui/assets/fonts/tech_mono.ttf"

static func get_font_sans() -> Font:
	if FileAccess.file_exists(FONT_SANS_PATH):
		var ff := FontFile.new()
		ff.data = FileAccess.get_file_as_bytes(FONT_SANS_PATH)
		return ff
	return null

static func get_font_bold() -> Font:
	if FileAccess.file_exists(FONT_BOLD_PATH):
		var ff := FontFile.new()
		ff.data = FileAccess.get_file_as_bytes(FONT_BOLD_PATH)
		return ff
	return null

static func get_font_mono() -> Font:
	if FileAccess.file_exists(FONT_MONO_PATH):
		var ff := FontFile.new()
		ff.data = FileAccess.get_file_as_bytes(FONT_MONO_PATH)
		return ff
	return null

static func get_text_primary_color(is_white: bool) -> Color:
	return COLOR_TEXT_DARK if is_white else COLOR_TEXT_TITANIUM

static func get_text_secondary_color(is_white: bool) -> Color:
	return COLOR_TEXT_DARK_MUTED if is_white else COLOR_TEXT_SECONDARY

static func get_text_muted_color(is_white: bool) -> Color:
	return Color(0.35, 0.42, 0.52, 0.9) if is_white else COLOR_TEXT_MUTED

# 1.4 Спектральная Дисперсия и LED-акценты (Physical Prism Accents)
const COLOR_ACCENT_PRISM_CYAN := Color(0.0, 0.9, 1.0, 1.0)      # #00E5FF: Оптический циан (фокус, интерфейс)
const COLOR_ACCENT_ELECTRIC_BLUE := Color(0.12, 0.58, 1.0, 1.0) # #1F94FF: Электрический синий (канал связи)
const COLOR_ACCENT_SPECTRAL_AMBER := Color(1.0, 0.73, 0.05, 1.0)# #FFBA0D: Спектральный янтарь (синтез, мышление)
const COLOR_ACCENT_EMERALD_FLUX := Color(0.0, 0.92, 0.52, 1.0)  # #00EB85: Изумрудный поток (успех, стабильность)
const COLOR_ACCENT_CRIMSON_VALVE := Color(1.0, 0.22, 0.28, 1.0) # #FF3847: Рубиновый клапан (ошибка, прерывание)
const COLOR_ACCENT_QUANTUM_VIOLET := Color(0.62, 0.38, 1.0, 1.0)# #9E61FF: Квантовый фиолетовый (автономия Агента)

# ==============================================================================
# 2. МЕТРИЧЕСКАЯ СИСТЕМА (8-PIXEL GRID & PRECISE CORNERS)
# ==============================================================================

const SPACE_XXS: int = 2     # Hairline-отступы, субпиксельные смещения
const SPACE_XS: int = 4      # Микро-разделители, иконки в строках
const SPACE_S: int = 8       # Базовый шаг сетки, интервалы списков
const SPACE_M: int = 16      # Внутренние поля панелей (Padding)
const SPACE_L: int = 24      # Пространство между крупными смысловыми блоками
const SPACE_XL: int = 32     # Внешние поля окон и модальных диалогов
const SPACE_2XL: int = 48    # Поля рабочего стола / HUD

const CORNER_SHARP: int = 0  # Монолитная строгая грань
const CORNER_SUBTLE: int = 2 # Кнопки и поля ввода
const CORNER_PANEL: int = 4  # Модульные плавающие карточки
const CORNER_PILL: int = 999 # Овальные статусные чипы (Tags)

const BORDER_HAIRLINE: int = 1 # 1px строгий контур

# ==============================================================================
# 3. КИНЕТИКА И ПЛАВНОСТЬ (TWEEN TIMINGS & EASING)
# ==============================================================================

const DURATION_INSTANT: float = 0.08 # Реакция на ховер курсора
const DURATION_FAST: float = 0.18    # Смена состояний кнопок, тултипы
const DURATION_NORMAL: float = 0.32  # Раскрытие карточек, дроверы
const DURATION_FLUID: float = 0.55   # Кинематографичный переход между экранами
const DURATION_ORB_BREATH: float = 2.4 # Базовый цикл дыхания Сферы Агента

# ==============================================================================
# 4. ФАБРИКА СТИЛЕЙ И ШЕЙДЕРОВ (MATERIAL & STYLE FACTORY)
# ==============================================================================

const SHADER_LIQUID_GLASS_PATH := "res://ui/shaders/liquid_glass.gdshader"

## Создает настроенный ShaderMaterial для матового оптического стекла
static func create_glass_material(
	is_white_mode: bool = false,
	opacity: float = 0.72,
	blur: float = 2.5,
	led_color: Color = Color(-1, -1, -1, -1),
	corner_rad: float = 4.0
) -> ShaderMaterial:
	var shader := load(SHADER_LIQUID_GLASS_PATH) as Shader
	if not shader:
		return null

	var mat := ShaderMaterial.new()
	mat.shader = shader

	var base_tint: Color
	var rim: Color

	if is_white_mode:
		base_tint = Color(COLOR_GLASS_QUARTZ_LIGHT.r, COLOR_GLASS_QUARTZ_LIGHT.g, COLOR_GLASS_QUARTZ_LIGHT.b, opacity)
		rim = COLOR_ACCENT_ELECTRIC_BLUE if led_color.a < 0.0 else led_color
	else:
		base_tint = Color(COLOR_GLASS_QUARTZ_DARK.r, COLOR_GLASS_QUARTZ_DARK.g, COLOR_GLASS_QUARTZ_DARK.b, opacity)
		rim = COLOR_ACCENT_PRISM_CYAN if led_color.a < 0.0 else led_color

	mat.set_shader_parameter("glass_tint", base_tint)
	mat.set_shader_parameter("blur_amount", blur)
	mat.set_shader_parameter("chromatic_dispersion", 0.0035)
	mat.set_shader_parameter("rim_color", rim)
	mat.set_shader_parameter("rim_thickness", 1.0)
	mat.set_shader_parameter("rim_boost", 1.2)
	mat.set_shader_parameter("noise_intensity", 0.02)
	mat.set_shader_parameter("sheen_intensity", 0.15)
	mat.set_shader_parameter("corner_radius", corner_rad)

	return mat

## Безопасная загрузка текстуры (поддерживает как импортированные ресурсы, так и прямую загрузку файлов)
static func load_texture_safe(res_path: String) -> Texture2D:
	if ResourceLoader.exists(res_path):
		var res: Resource = load(res_path)
		if res is Texture2D:
			return res
	var global_path: String = ProjectSettings.globalize_path(res_path)
	if FileAccess.file_exists(global_path):
		var img: Image = Image.load_from_file(global_path)
		if img and not img.is_empty():
			return ImageTexture.create_from_image(img)
	return null

## Возвращает спектральный цвет индикатора по имени состояния Агента
static func get_agent_state_color(agent_state: String) -> Color:
	match agent_state.to_lower():
		"idle", "ready":
			return COLOR_ACCENT_PRISM_CYAN
		"listening", "analyzing":
			return COLOR_ACCENT_ELECTRIC_BLUE
		"thinking", "generating", "synthesizing":
			return COLOR_ACCENT_SPECTRAL_AMBER
		"success", "verified", "mounted":
			return COLOR_ACCENT_EMERALD_FLUX
		"error", "failed", "critical":
			return COLOR_ACCENT_CRIMSON_VALVE
		"autonomous", "singularity", "refactoring":
			return COLOR_ACCENT_QUANTUM_VIOLET
		_:
			return COLOR_ACCENT_PRISM_CYAN
