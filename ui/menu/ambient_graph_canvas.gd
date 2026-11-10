class_name AmbientGraphCanvas
extends Control

## UniCORE Ambient Synaptic Graph & Particle Canvas
## Процедурный живой фон:
## - Парящие квантовые микро-ноды с плавным броуновским дрейфом
## - Динамические молекулярные связи (связывание точек при сближении и разрыв при удалении)
## - Тончайшая эстетика лабораторной пустоты (полупрозрачные 1px hairlines)
## - Ультра-низкая нагрузка на процессор (оптимизированный _draw)

const DesignTokens = preload("res://ui/theme/design_tokens.gd")

@export var node_count: int = 64
@export var min_connection_distance: float = 24.0
@export var connection_distance: float = 115.0
@export var base_speed: float = 14.0
@export var dot_radius: float = 1.6
@export var max_connection_alpha: float = 0.16
@export var node_base_alpha: float = 0.35
@export var custom_color: Color = Color(-1, -1, -1, -1)

# Внутренняя структура квантовой ноды
class SynapticPoint:
	var position: Vector2 = Vector2.ZERO
	var velocity: Vector2 = Vector2.ZERO
	var pulse_phase: float = 0.0
	var pulse_speed: float = 1.0
	var drift_angle: float = 0.0
	var base_speed: float = 14.0

var _nodes: Array[SynapticPoint] = []
var _is_active: bool = true

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	resized.connect(_on_resized)
	_initialize_nodes()

func _on_resized() -> void:
	# Корректируем координаты нод при изменении размера окна
	if size.x <= 0 or size.y <= 0:
		return
	for node in _nodes:
		node.position.x = clampf(node.position.x, 0.0, size.x)
		node.position.y = clampf(node.position.y, 0.0, size.y)

func _initialize_nodes() -> void:
	_nodes.clear()
	var current_size := size
	if current_size.x <= 10.0 or current_size.y <= 10.0:
		current_size = Vector2(1920, 1080) # Дефолтный fallback

	for i in range(node_count):
		var gn := SynapticPoint.new()
		gn.position = Vector2(
			randf_range(0.0, current_size.x),
			randf_range(0.0, current_size.y)
		)
		var angle := randf_range(0.0, TAU)
		var speed := randf_range(base_speed * 0.5, base_speed * 1.5)
		gn.base_speed = speed
		gn.drift_angle = angle
		gn.velocity = Vector2(cos(angle), sin(angle)) * speed
		gn.pulse_phase = randf_range(0.0, TAU)
		gn.pulse_speed = randf_range(0.8, 2.2)
		_nodes.append(gn)

func _process(delta: float) -> void:
	if not _is_active or _nodes.is_empty():
		return

	var bounds := size
	if bounds.x <= 10.0 or bounds.y <= 10.0:
		bounds = Vector2(1920, 1080)

	for node in _nodes:
		# Плавный броуновский дрейф вектора скорости
		node.drift_angle += randf_range(-1.2, 1.2) * delta
		var target_vel := Vector2(cos(node.drift_angle), sin(node.drift_angle)) * node.base_speed
		node.velocity = node.velocity.lerp(target_vel, clampf(delta * 2.0, 0.0, 1.0))

		node.position += node.velocity * delta
		node.pulse_phase += node.pulse_speed * delta

		# Мягкое отталкивание от границ холста с перенаправлением угла дрейфа
		if node.position.x < 0.0:
			node.position.x = 0.0
			node.velocity.x = absf(node.velocity.x)
			node.drift_angle = atan2(node.velocity.y, node.velocity.x)
		elif node.position.x > bounds.x:
			node.position.x = bounds.x
			node.velocity.x = -absf(node.velocity.x)
			node.drift_angle = atan2(node.velocity.y, node.velocity.x)

		if node.position.y < 0.0:
			node.position.y = 0.0
			node.velocity.y = absf(node.velocity.y)
			node.drift_angle = atan2(node.velocity.y, node.velocity.x)
		elif node.position.y > bounds.y:
			node.position.y = bounds.y
			node.velocity.y = -absf(node.velocity.y)
			node.drift_angle = atan2(node.velocity.y, node.velocity.x)

	# Запрашиваем перерисовку кадра
	queue_redraw()

func _draw() -> void:
	if _nodes.is_empty():
		return

	var base_col: Color = custom_color if custom_color.a >= 0.0 else DesignTokens.COLOR_ACCENT_PRISM_CYAN
	var r: float = base_col.r
	var g: float = base_col.g
	var b: float = base_col.b
	var count: int = _nodes.size()
	var conn_dist_sq: float = connection_distance * connection_distance
	var min_dist: float = min_connection_distance
	var max_dist: float = connection_distance

	# 1. Оптимизированная отрисовка молекулярных связей (smoothstep fade/dissolve)
	for i in range(count):
		var n1: SynapticPoint = _nodes[i]
		var p1: Vector2 = n1.position
		for j in range(i + 1, count):
			var n2: SynapticPoint = _nodes[j]
			var p2: Vector2 = n2.position
			var dist_sq: float = p1.distance_squared_to(p2)

			if dist_sq < conn_dist_sq:
				var dist: float = sqrt(dist_sq)
				# Плавное появление и разрыв по кривой Эрмита (smoothstep)
				var line_factor: float = smoothstep(max_dist, min_dist, dist)
				var line_alpha: float = line_factor * max_connection_alpha
				if line_alpha > 0.003:
					draw_line(p1, p2, Color(r, g, b, line_alpha), 1.0, true)

	# 2. Отрисовка квантовых микро-нод
	for node in _nodes:
		var pulse: float = (sin(node.pulse_phase) * 0.5 + 0.5) * 0.3
		var alpha: float = clampf(node_base_alpha + pulse, 0.1, 0.8)
		draw_circle(node.position, dot_radius, Color(r, g, b, alpha))
