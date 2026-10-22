class_name ModuleRegistryClient
extends RefCounted

## Клиент Реестра и Библиотеки Готовых Модулей UniCORE
## Позволяет находить, скачивать из интернета или использовать предзагруженные
## проверенные модули и библиотеки (Godot AssetLib, GitHub, UniCORE Registry)
## без необходимости тратить токены LLM на стандартные механики.

const OFFICIAL_CATALOG_URL := "https://raw.githubusercontent.com/godotengine/godot-asset-library/master"
const LOCAL_REGISTRY_PATH := "res://modules/registry_cache.json"

## Локальная проверенная библиотека готовых модулей (Built-in Package Cache)
const VERIFIED_MODULE_TEMPLATES := {
	"cube_spawner": {
		"id": "cube_spawner_tool",
		"name": "Инструмент: Спавнер Красных Кубов",
		"category": "tools",
		"tags": ["spawner", "3d", "primitives", "cube", "red", "куб", "кубик", "спавнер", "красный"],
		"author": "UniCORE Core Team",
		"version": "1.0.0",
		"description": "Инструмент создания интерактивных красных 3D-кубов перед камерой по ЛКМ или клавише F.",
		"source_file": "res://modules/cube_spawner_tool.gd",
		"code": """extends UniCoreModule

## Инструмент создания красных кубов (Cube Spawner Tool)
var _spawned_cubes: Array[Node3D] = []
var _material: StandardMaterial3D

func get_module_id() -> String:
	return "cube_spawner_tool"

func get_module_name() -> String:
	return "Инструмент: Спавнер Красных Кубов"

func initialize(context: Dictionary) -> bool:
	super.initialize(context)
	_material = StandardMaterial3D.new()
	_material.albedo_color = Color(1.0, 0.15, 0.15, 1.0)
	_material.roughness = 0.3
	_material.metallic = 0.1
	spawn_cube(Vector3(0, 1.5, -4.0))
	return true

func _unhandled_input(event: InputEvent) -> void:
	if not is_initialized:
		return
	var should_spawn := false
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
			should_spawn = true
	if event is InputEventKey and event.pressed and not event.is_echo():
		if event.keycode == KEY_F or event.keycode == KEY_E:
			if Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
				should_spawn = true
	if should_spawn:
		var cam := get_viewport().get_camera_3d()
		var spawn_pos := Vector3(0, 1.5, -4.0)
		if cam:
			spawn_pos = cam.global_position - cam.global_transform.basis.z * 4.0
		spawn_cube(spawn_pos)
		get_viewport().set_input_as_handled()

func spawn_cube(pos: Vector3) -> MeshInstance3D:
	var mesh_inst := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(1.2, 1.2, 1.2)
	mesh_inst.mesh = box
	mesh_inst.material_override = _material
	mesh_inst.position = pos
	add_child(mesh_inst)
	_spawned_cubes.append(mesh_inst)
	return mesh_inst

func cleanup() -> void:
	for c in _spawned_cubes:
		if is_instance_valid(c):
			c.queue_free()
	_spawned_cubes.clear()
	super.cleanup()
"""
	},
	"sphere_spawner": {
		"id": "sphere_spawner_tool",
		"name": "Инструмент: Спавнер Синих Сфер",
		"category": "tools",
		"tags": ["spawner", "3d", "sphere", "neon", "blue", "сфера", "сферы", "шар", "шары", "спавнер"],
		"author": "UniCORE Community",
		"version": "1.0.0",
		"description": "Спавнит светящиеся синие сферы с физическим отскоком.",
		"code": """extends UniCoreModule

var _spawned_spheres: Array[Node3D] = []
var _material: StandardMaterial3D

func get_module_id() -> String:
	return "sphere_spawner_tool"

func get_module_name() -> String:
	return "Инструмент: Спавнер Синих Сфер"

func initialize(context: Dictionary) -> bool:
	super.initialize(context)
	_material = StandardMaterial3D.new()
	_material.albedo_color = Color(0.0, 0.7, 1.0)
	_material.emission_enabled = true
	_material.emission = Color(0.0, 0.5, 0.9)
	_material.emission_energy_multiplier = 1.5
	spawn_sphere(Vector3(0, 2.0, -3.5))
	return true

func _unhandled_input(event: InputEvent) -> void:
	if not is_initialized:
		return
	var should_spawn := false
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
			should_spawn = true
	if event is InputEventKey and event.pressed and not event.is_echo():
		if event.keycode == KEY_G or event.keycode == KEY_E:
			should_spawn = true
	if should_spawn:
		var cam := get_viewport().get_camera_3d()
		var pos := Vector3(0, 2.0, -3.5)
		if cam:
			pos = cam.global_position - cam.global_transform.basis.z * 3.5
		spawn_sphere(pos)
		get_viewport().set_input_as_handled()

func spawn_sphere(pos: Vector3) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.6
	sphere.height = 1.2
	mi.mesh = sphere
	mi.material_override = _material
	mi.position = pos
	add_child(mi)
	_spawned_spheres.append(mi)
	return mi

func cleanup() -> void:
	for s in _spawned_spheres:
		if is_instance_valid(s):
			s.queue_free()
	_spawned_spheres.clear()
	super.cleanup()
"""
	},
	"day_night_cycle": {
		"id": "day_night_cycle",
		"name": "Окружение: Смена Дня и Ночи",
		"category": "environment",
		"tags": ["lighting", "sky", "sun", "atmosphere", "day", "night", "свет", "солнце", "небо", "день", "ночь", "цикл"],
		"author": "UniCORE Community",
		"version": "1.0.0",
		"description": "Автоматическое медленное вращение солнца и изменение цвета неба.",
		"code": """extends UniCoreModule

var _sun: DirectionalLight3D
var _orbit_speed: float = 0.05

func get_module_id() -> String:
	return "day_night_cycle"

func get_module_name() -> String:
	return "Окружение: Смена Дня и Ночи"

func initialize(context: Dictionary) -> bool:
	super.initialize(context)
	_sun = DirectionalLight3D.new()
	_sun.name = "DynamicSun"
	_sun.shadow_enabled = true
	_sun.light_energy = 1.0
	_sun.light_color = Color(1.0, 0.95, 0.88)
	add_child(_sun)
	return true

func _process(delta: float) -> void:
	if not is_initialized or not _sun:
		return
	_sun.rotate_x(delta * _orbit_speed)

func cleanup() -> void:
	if _sun and is_instance_valid(_sun):
		_sun.queue_free()
	super.cleanup()
"""
	},
	"fps_counter": {
		"id": "fps_counter",
		"name": "Утилита: FPS и Монитор Производительности",
		"category": "utilities",
		"tags": ["debug", "hud", "performance", "fps", "фпс", "производительность", "монитор", "счетчик"],
		"author": "UniCORE Tools",
		"version": "1.0.0",
		"description": "Кибер-виджет счетчика кадров и памяти в стиле Detroit: Become Human.",
		"code": """extends UniCoreModule

var _label: Label
var _panel: PanelContainer

func get_module_id() -> String:
	return "fps_counter"

func get_module_name() -> String:
	return "Утилита: FPS и Производительность"

func initialize(context: Dictionary) -> bool:
	super.initialize(context)
	var canvas := CanvasLayer.new()
	canvas.layer = 90
	add_child(canvas)

	_panel = PanelContainer.new()
	_panel.anchors_preset = Control.PRESET_TOP_RIGHT
	_panel.anchor_left = 1.0
	_panel.anchor_right = 1.0
	_panel.offset_left = -160.0
	_panel.offset_top = 48.0
	_panel.offset_right = -12.0
	_panel.offset_bottom = 80.0
	canvas.add_child(_panel)

	_label = Label.new()
	_label.text = "FPS: 60"
	_label.add_theme_color_override("font_color", Color(0.0, 0.85, 1.0))
	_label.add_theme_font_size_override("font_size", 12)
	_panel.add_child(_label)
	return true

func _process(_delta: float) -> void:
	if not is_initialized or not _label:
		return
	var fps := Engine.get_frames_per_second()
	_label.text = "SYS_PERF: %d FPS" % fps

func cleanup() -> void:
	if _panel and is_instance_valid(_panel):
		_panel.queue_free()
	super.cleanup()
"""
	},
	"ground_plane_color": {
		"id": "ground_plane_color",
		"name": "Окружение: Цвет Базовой Плоскости",
		"category": "environment",
		"tags": ["ground", "plane", "floor", "color", "neon", "cyan", "green", "purple", "земля", "пол", "плоскость", "цвет", "базовая"],
		"author": "UniCORE Studio",
		"version": "1.0.0",
		"description": "Спавнит или меняет цвет базовой плоскости на выбранный цвет (neon cyan/green/purple).",
		"code": """extends UniCoreModule

var _ground_mesh: MeshInstance3D
var _material: StandardMaterial3D
var _palette: Array[Color] = [
	Color(0.0, 0.9, 1.0, 1.0),
	Color(0.1, 1.0, 0.3, 1.0),
	Color(0.7, 0.1, 1.0, 1.0)
]
var _current_color_idx: int = 0

func get_module_id() -> String:
	return "ground_plane_color"

func get_module_name() -> String:
	return "Окружение: Цвет Базовой Плоскости"

func initialize(context: Dictionary) -> bool:
	super.initialize(context)
	if context.has("color_index"):
		_current_color_idx = int(context["color_index"]) % _palette.size()
	elif context.has("color_idx"):
		_current_color_idx = int(context["color_idx"]) % _palette.size()
	_material = StandardMaterial3D.new()
	_material.albedo_color = _palette[_current_color_idx]
	_material.roughness = 0.4
	_material.metallic = 0.2
	_material.emission_enabled = true
	_material.emission = _palette[_current_color_idx] * 0.3

	var existing_ground: Node = null
	if is_inside_tree():
		var tree := get_tree()
		if tree and tree.root:
			existing_ground = tree.root.find_child("GroundPlane", true, false)

	if existing_ground and existing_ground is MeshInstance3D:
		_ground_mesh = existing_ground
		_ground_mesh.material_override = _material
	else:
		_ground_mesh = MeshInstance3D.new()
		_ground_mesh.name = "GroundPlane"
		var plane_mesh := PlaneMesh.new()
		plane_mesh.size = Vector2(50.0, 50.0)
		_ground_mesh.mesh = plane_mesh
		_ground_mesh.material_override = _material
		_ground_mesh.position = Vector3(0, 0, 0)
		add_child(_ground_mesh)

	return true

func set_color_index(idx: int) -> void:
	_current_color_idx = idx % _palette.size()
	if _material:
		_material.albedo_color = _palette[_current_color_idx]
		_material.emission = _palette[_current_color_idx] * 0.3

func cleanup() -> void:
	if _ground_mesh and is_instance_valid(_ground_mesh):
		if _ground_mesh.get_parent() == self:
			_ground_mesh.queue_free()
	super.cleanup()
"""
	},
	"lighting_setup": {
		"id": "lighting_setup",
		"name": "Освещение: Кибер-свет CyberLife",
		"category": "environment",
		"tags": ["lighting", "light", "cyberlife", "keylight", "filllight", "backlight", "shadows", "освещение", "свет", "киберлайф", "тени", "лампа"],
		"author": "UniCORE Studio",
		"version": "1.0.0",
		"description": "Создает трехточечное кибер-освещение CyberLife (KeyLight, FillLight, BackLight) с мягкими тенями.",
		"code": """extends UniCoreModule

var _key_light: DirectionalLight3D
var _fill_light: OmniLight3D
var _back_light: DirectionalLight3D

func get_module_id() -> String:
	return "lighting_setup"

func get_module_name() -> String:
	return "Освещение: Кибер-свет CyberLife"

func initialize(context: Dictionary) -> bool:
	super.initialize(context)

	_key_light = DirectionalLight3D.new()
	_key_light.name = "KeyLight"
	_key_light.light_color = Color(0.85, 0.95, 1.0)
	_key_light.light_energy = 1.2
	_key_light.shadow_enabled = true
	_key_light.shadow_blur = 1.5
	_key_light.directional_shadow_blend_splits = true
	_key_light.rotation_degrees = Vector3(-45.0, 30.0, 0.0)
	add_child(_key_light)

	_fill_light = OmniLight3D.new()
	_fill_light.name = "FillLight"
	_fill_light.light_color = Color(0.0, 0.8, 1.0)
	_fill_light.light_energy = 0.8
	_fill_light.omni_range = 30.0
	_fill_light.position = Vector3(-5.0, 3.0, 5.0)
	add_child(_fill_light)

	_back_light = DirectionalLight3D.new()
	_back_light.name = "BackLight"
	_back_light.light_color = Color(1.0, 0.7, 0.4)
	_back_light.light_energy = 0.6
	_back_light.shadow_enabled = true
	_back_light.shadow_blur = 1.5
	_back_light.rotation_degrees = Vector3(-30.0, -150.0, 0.0)
	add_child(_back_light)

	return true

func cleanup() -> void:
	if _key_light and is_instance_valid(_key_light):
		_key_light.queue_free()
	if _fill_light and is_instance_valid(_fill_light):
		_fill_light.queue_free()
	if _back_light and is_instance_valid(_back_light):
		_back_light.queue_free()
	super.cleanup()
"""
	},
	"physics_gravity": {
		"id": "physics_gravity",
		"name": "Физика: Интерактивный Физический Куб",
		"category": "physics",
		"tags": ["physics", "gravity", "rigidbody", "bounce", "cube", "гравитация", "физика", "отскок", "риджидбоди", "падение", "кубик", "куб", "физический"],
		"author": "UniCORE Physics",
		"version": "1.0.0",
		"description": "Интерактивный физический куб с RigidBody3D и отскоком при клике.",
		"code": """extends UniCoreModule

var _body: RigidBody3D
var _material: StandardMaterial3D

func get_module_id() -> String:
	return "physics_gravity"

func get_module_name() -> String:
	return "Физика: Интерактивный Физический Куб"

func initialize(context: Dictionary) -> bool:
	super.initialize(context)

	_body = RigidBody3D.new()
	_body.name = "PhysicsCube"
	_body.mass = 2.0

	var phys_mat := PhysicsMaterial.new()
	phys_mat.bounce = 0.65
	phys_mat.friction = 0.3
	_body.physics_material_override = phys_mat

	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(1.2, 1.2, 1.2)
	col.shape = shape
	_body.add_child(col)

	var mi := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(1.2, 1.2, 1.2)
	mi.mesh = box

	_material = StandardMaterial3D.new()
	_material.albedo_color = Color(1.0, 0.4, 0.1)
	_material.metallic = 0.2
	_material.roughness = 0.3
	_material.emission_enabled = true
	_material.emission = Color(0.8, 0.2, 0.0)
	mi.material_override = _material
	_body.add_child(mi)

	_body.position = Vector3(0, 4.0, -3.0)
	add_child(_body)
	return true

func _unhandled_input(event: InputEvent) -> void:
	if not is_initialized or not _body:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_apply_bounce_impulse()

func _apply_bounce_impulse() -> void:
	if is_instance_valid(_body):
		var upward := Vector3(randf_range(-1.0, 1.0), 8.0, randf_range(-1.0, 1.0))
		_body.apply_central_impulse(upward)
		_body.apply_torque_impulse(Vector3(randf_range(-2.0, 2.0), randf_range(-2.0, 2.0), randf_range(-2.0, 2.0)))

func cleanup() -> void:
	if _body and is_instance_valid(_body):
		_body.queue_free()
	super.cleanup()
"""
	},
	"camera_effects": {
		"id": "camera_effects",
		"name": "Камера: Процедурные Эффекты и FOV",
		"category": "camera",
		"tags": ["camera", "effects", "fov", "shake", "headbob", "камера", "эффекты", "покачивание", "шейк", "динамический", "фов"],
		"author": "UniCORE Visuals",
		"version": "1.0.0",
		"description": "Процедурное покачивание камеры или динамический FOV-эффект при движении.",
		"code": """extends UniCoreModule

var _camera: Camera3D
var _base_fov: float = 75.0
var _target_fov: float = 75.0
var _time_passed: float = 0.0

func get_module_id() -> String:
	return "camera_effects"

func get_module_name() -> String:
	return "Камера: Процедурные Эффекты и FOV"

func initialize(context: Dictionary) -> bool:
	super.initialize(context)
	var vp := get_viewport()
	if vp:
		_camera = vp.get_camera_3d()
	if _camera:
		_base_fov = _camera.fov
		_target_fov = _base_fov
	return true

func _process(delta: float) -> void:
	if not is_initialized:
		return
	if not _camera:
		var vp := get_viewport()
		if vp:
			_camera = vp.get_camera_3d()
		if not _camera:
			return
		_base_fov = _camera.fov
		_target_fov = _base_fov

	_time_passed += delta
	var bob_y := sin(_time_passed * 2.5) * 0.03
	var bob_x := cos(_time_passed * 1.25) * 0.02
	_camera.h_offset = bob_x
	_camera.v_offset = bob_y
	_camera.fov = lerpf(_camera.fov, _target_fov, delta * 4.0)

func set_speed_fov(is_sprinting: bool) -> void:
	_target_fov = (_base_fov + 12.0) if is_sprinting else _base_fov

func cleanup() -> void:
	if _camera and is_instance_valid(_camera):
		_camera.h_offset = 0.0
		_camera.v_offset = 0.0
		_camera.fov = _base_fov
	super.cleanup()
"""
	},
	"particle_system": {
		"id": "particle_system",
		"name": "Эффекты: Фонтан Неоновых Частиц",
		"category": "vfx",
		"tags": ["particle", "particles", "particle_system", "vfx", "fountain", "neon", "cpu", "партиклы", "частицы", "эффекты", "фонтан", "неон", "свечение", "светящийся"],
		"author": "UniCORE VFX",
		"version": "1.0.0",
		"description": "Светящийся фонтан частиц (CPUParticles3D) с неоновым свечением.",
		"code": """extends UniCoreModule

var _particles: CPUParticles3D
var _particle_material: StandardMaterial3D

func get_module_id() -> String:
	return "particle_system"

func get_module_name() -> String:
	return "Эффекты: Фонтан Неоновых Частиц"

func initialize(context: Dictionary) -> bool:
	super.initialize(context)

	_particles = CPUParticles3D.new()
	_particles.name = "NeonParticleFountain"
	_particles.amount = 120
	_particles.lifetime = 2.0
	_particles.speed_scale = 1.0
	_particles.explosiveness = 0.05
	_particles.randomness = 0.3

	_particles.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	_particles.emission_sphere_radius = 0.3
	_particles.direction = Vector3(0, 1, 0)
	_particles.spread = 25.0
	_particles.gravity = Vector3(0, -9.8, 0)
	_particles.initial_velocity_min = 6.0
	_particles.initial_velocity_max = 9.0

	var sphere := SphereMesh.new()
	sphere.radius = 0.08
	sphere.height = 0.16

	_particle_material = StandardMaterial3D.new()
	_particle_material.albedo_color = Color(0.0, 1.0, 0.85)
	_particle_material.emission_enabled = true
	_particle_material.emission = Color(0.0, 0.9, 0.8)
	_particle_material.emission_energy_multiplier = 2.5
	sphere.material = _particle_material

	_particles.mesh = sphere
	_particles.position = Vector3(0, 0.1, -3.0)
	add_child(_particles)
	_particles.emitting = true

	return true

func cleanup() -> void:
	if _particles and is_instance_valid(_particles):
		_particles.queue_free()
	super.cleanup()
"""
	}
}

## Алгоритм динамического программирования для вычисления расстояния Левенштейна
static func levenshtein_distance(s1: String, s2: String) -> int:
	var len1 := s1.length()
	var len2 := s2.length()
	if len1 == 0:
		return len2
	if len2 == 0:
		return len1
	if s1 == s2:
		return 0

	var prev_row: Array[int] = []
	prev_row.resize(len2 + 1)
	for j in range(len2 + 1):
		prev_row[j] = j

	var curr_row: Array[int] = []
	curr_row.resize(len2 + 1)

	for i in range(1, len1 + 1):
		curr_row[0] = i
		var c1 := s1[i - 1]
		for j in range(1, len2 + 1):
			var c2 := s2[j - 1]
			var cost := 0 if c1 == c2 else 1
			curr_row[j] = mini(
				curr_row[j - 1] + 1,
				mini(
					prev_row[j] + 1,
					prev_row[j - 1] + cost
				)
			)
		for j in range(len2 + 1):
			prev_row[j] = curr_row[j]

	return prev_row[len2]

## Очистка токена от пунктуации и пробелов
static func _clean_token(w: String) -> String:
	var s := w.strip_edges()
	s = s.trim_prefix("(").trim_suffix(")")
	s = s.trim_prefix("[").trim_suffix("]")
	s = s.trim_prefix("{").trim_suffix("}")
	s = s.trim_prefix("\"").trim_suffix("\"")
	s = s.trim_prefix("'").trim_suffix("'")
	s = s.trim_prefix("«").trim_suffix("»")
	s = s.trim_suffix(":").trim_suffix(";").trim_suffix(",").trim_suffix(".").trim_suffix("!").trim_suffix("?")
	return s.strip_edges()

## Расчет схожести строки запроса с шаблоном
## Учитывает:
## 1) Точное совпадение (1.0)
## 2) Вхождение подстроки query в id, name, tags (0.75-0.9)
## 3) Пересечение ключевых слов (query.split(" ") с tags и словами name/description) (0.5-0.8)
## 4) Нормализованное расстояние Левенштейна (1.0 - dist / max_len) для опечаток (0.3-0.7)
static func _calculate_similarity(query: String, tags: Array, name: String, description: String, id: String = "") -> float:
	var q := query.to_lower().strip_edges()
	if q.is_empty():
		return 0.0

	var name_lower := name.to_lower().strip_edges()
	var desc_lower := description.to_lower().strip_edges()
	var id_lower := id.to_lower().strip_edges()

	var tags_lower: Array[String] = []
	for t in tags:
		var st := str(t).to_lower().strip_edges()
		if not st.is_empty():
			tags_lower.append(st)

	# 1. Точное совпадение (1.0)
	if not id_lower.is_empty() and q == id_lower:
		return 1.0
	if q == name_lower:
		return 1.0
	for t in tags_lower:
		if q == t:
			return 1.0

	var best_score: float = 0.0

	# 2. Вхождение подстроки query в id, name, tags (0.75-0.9)
	# query является подстрокой целевого поля. Требует q.length() >= 2 чтобы одиночные символы не давали ложный матч.
	if q.length() >= 2:
		var sub_score: float = 0.0
		for t in tags_lower:
			if t.contains(q):
				var ratio := float(q.length()) / float(t.length())
				sub_score = maxf(sub_score, 0.75 + 0.15 * ratio)
		if not id_lower.is_empty() and id_lower.contains(q):
			var ratio := float(q.length()) / float(id_lower.length())
			sub_score = maxf(sub_score, 0.75 + 0.13 * ratio)
		if name_lower.contains(q):
			var ratio := float(q.length()) / float(name_lower.length())
			sub_score = maxf(sub_score, 0.75 + 0.10 * ratio)
		elif desc_lower.contains(q):
			var ratio := float(q.length()) / float(maxi(desc_lower.length(), 1))
			sub_score = maxf(sub_score, 0.75 + 0.05 * ratio)

		best_score = maxf(best_score, sub_score)

	# 3. Пересечение ключевых слов (0.5-0.8)
	var q_words: PackedStringArray = q.split(" ", false)
	var clean_q_words: Array[String] = []
	for w in q_words:
		var cw := _clean_token(w)
		if cw.length() >= 2:
			clean_q_words.append(cw)

	if not clean_q_words.is_empty():
		var target_words: Array[String] = []
		if not id_lower.is_empty():
			for w in id_lower.replace("_", " ").replace("-", " ").split(" ", false):
				var cw := _clean_token(w)
				if cw.length() >= 2 and not target_words.has(cw):
					target_words.append(cw)
		for t in tags_lower:
			for w in t.replace("_", " ").replace("-", " ").split(" ", false):
				var cw := _clean_token(w)
				if cw.length() >= 2 and not target_words.has(cw):
					target_words.append(cw)
		for w in name_lower.split(" ", false):
			var cw := _clean_token(w)
			if cw.length() >= 2 and not target_words.has(cw):
				target_words.append(cw)
		for w in desc_lower.split(" ", false):
			var cw := _clean_token(w)
			if cw.length() >= 2 and not target_words.has(cw):
				target_words.append(cw)

		var matched_q_words: int = 0
		for qw in clean_q_words:
			var matched := false
			for tw in target_words:
				if qw == tw or (qw.length() >= 3 and tw.length() >= 3 and (tw.begins_with(qw) or qw.begins_with(tw))):
					matched = true
					break
			if matched:
				matched_q_words += 1

		if matched_q_words > 0:
			var overlap_ratio := float(matched_q_words) / float(clean_q_words.size())
			var word_score := 0.5 + 0.3 * overlap_ratio
			best_score = maxf(best_score, word_score)

	# 4. Нормализованное расстояние Левенштейна (1.0 - dist / max_len) для опечаток (0.3-0.7)
	var lev_score: float = 0.0

	var candidate_words: Array[String] = []
	if not id_lower.is_empty():
		candidate_words.append(id_lower)
		for w in id_lower.replace("_", " ").split(" ", false):
			var cw := _clean_token(w)
			if cw.length() >= 3 and not candidate_words.has(cw):
				candidate_words.append(cw)
	for t in tags_lower:
		candidate_words.append(t)
		for w in t.split(" ", false):
			var cw := _clean_token(w)
			if cw.length() >= 3 and not candidate_words.has(cw):
				candidate_words.append(cw)
	for w in name_lower.split(" ", false):
		var cw := _clean_token(w)
		if cw.length() >= 3 and not candidate_words.has(cw):
			candidate_words.append(cw)

	var query_tokens_to_test: Array[String] = [q]
	for qw in clean_q_words:
		if not query_tokens_to_test.has(qw):
			query_tokens_to_test.append(qw)

	for q_token in query_tokens_to_test:
		if q_token.length() < 3:
			continue
		for cand in candidate_words:
			if cand.length() < 3:
				continue
			var max_len := maxi(q_token.length(), cand.length())
			var dist := levenshtein_distance(q_token, cand)
			var norm := 1.0 - float(dist) / float(max_len)
			if norm >= 0.45 and dist <= 3:
				var scaled_lev := 0.3 + 0.4 * norm
				lev_score = maxf(lev_score, scaled_lev)

	best_score = maxf(best_score, lev_score)
	return best_score

## Нечеткий поиск наиболее подходящего шаблона по запросу.
## Возвращает шаблон с наивысшим баллом схожести >= threshold, либо {} если ничего не найдено.
static func fuzzy_search(query: String, threshold: float = 0.3) -> Dictionary:
	var q := query.to_lower().strip_edges()
	if q.is_empty():
		return {}

	var best_template: Dictionary = {}
	var best_score: float = -1.0

	for key in VERIFIED_MODULE_TEMPLATES:
		var item: Dictionary = VERIFIED_MODULE_TEMPLATES[key]
		var item_id: String = str(item.get("id", key))
		var item_name: String = str(item.get("name", ""))
		var item_desc: String = str(item.get("description", ""))
		var item_tags: Array = item.get("tags", [])

		var score := _calculate_similarity(q, item_tags, item_name, item_desc, item_id)
		if score >= threshold and score > best_score:
			best_score = score
			best_template = item

	return best_template

## Поиск модуля по семантическим тегам или запросу (обратная совместимость через fuzzy_search с порогом 0.35)
static func search_template(query: String) -> Dictionary:
	return fuzzy_search(query, 0.35)

## Получить список всех доступных проверенных шаблонов (для UI галереи модулей)
static func get_all_templates() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for key in VERIFIED_MODULE_TEMPLATES:
		result.append(VERIFIED_MODULE_TEMPLATES[key])
	return result

## Получить исходный код модуля из библиотеки
static func get_module_source(template_info: Dictionary) -> String:
	if template_info.has("code"):
		return template_info["code"]
	if template_info.has("source_file"):
		var f := FileAccess.open(template_info["source_file"], FileAccess.READ)
		if f:
			var code := f.get_as_text()
			f.close()
			return code
	return ""
