class_name AmbientGraphCanvas
extends Control

## UniCORE Ambient Synaptic Graph & Particle Canvas
## Процедурный живой фон:
## - Парящие квантовые микро-ноды с плавным броуновским дрейфом
## - Динамические молекулярные связи (связывание точек при сближении и разрыв при удалении)
## - Тончайшая эстетика лабораторной пустоты (полупрозрачные 1px hairlines)
## - Ультра-низкая нагрузка на процессор (оптимизированный _draw)

const DesignTokens = preload("res://ui/theme/design_tokens.gd")

@export var node_count: int = 28
@export var connection_distance: float = 95.0
@export var base_speed: float = 14.0
@export var dot_radius: float = 1.6
@export var max_connection_alpha: float = 0.16
@export var node_base_alpha: float = 0.35

# Внутренняя структура квантовой ноды
class SynapticPoint:
	var position: Vector2 = Vector2.ZERO
	var velocity: Vector2 = Vector2.ZERO
	var pulse_phase: float = 0.0
	var pulse_speed: float = 1.0

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
		node.position += node.velocity * delta
		node.pulse_phase += node.pulse_speed * delta

		# Мягкое отталкивание от границ холста
		if node.position.x < 0.0:
			node.position.x = 0.0
			node.velocity.x *= -1.0
		elif node.position.x > bounds.x:
			node.position.x = bounds.x
			node.velocity.x *= -1.0

		if node.position.y < 0.0:
			node.position.y = 0.0
			node.velocity.y *= -1.0
		elif node.position.y > bounds.y:
			node.position.y = bounds.y
			node.velocity.y *= -1.0

	# Запрашиваем перерисовку кадра
	queue_redraw()

func _draw() -> void:
	if _nodes.is_empty():
		return

	var cyan_col := DesignTokens.COLOR_ACCENT_PRISM_CYAN
	var count := _nodes.size()
	var conn_dist_sq := connection_distance * connection_distance

	# 1. Отрисовка молекулярных связей (линии графа)
	for i in range(count):
		var n1 := _nodes[i]
		for j in range(i + 1, count):
			var n2 := _nodes[j]
			var dist_sq := n1.position.distance_squared_to(n2.position)
			
			if dist_sq < conn_dist_sq:
				var dist := sqrt(dist_sq)
				# Плавное угасание линии к границе разрыва связи
				var proximity_factor := 1.0 - (dist / connection_distance)
				var line_alpha := proximity_factor * max_connection_alpha
				
				var line_color := Color(cyan_col.r, cyan_col.g, cyan_col.b, line_alpha)
				draw_line(n1.position, n2.position, line_color, 1.0, true)

	# 2. Отрисовка квантовых микро-нод
	for node in _nodes:
		var pulse := (sin(node.pulse_phase) * 0.5 + 0.5) * 0.3
		var alpha := clampf(node_base_alpha + pulse, 0.1, 0.8)
		var dot_color := Color(cyan_col.r, cyan_col.g, cyan_col.b, alpha)
		draw_circle(node.position, dot_radius, dot_color)
