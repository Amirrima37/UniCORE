## Name: Интерференция света в призме (волна/частица)
## Description: Модуль визуализирует прохождение света через призму. Свет представлен как поток движущихся частиц (фотонов), которые летят от источника, попадают в призму и преломляются, разлагаясь в радужный спектр. Частицы непрерывно движутся и повторяют цикл. Также добавлена волновая визуализация (синусоидальная волна), которая распространяется от источника к призме и далее расходится веером радужных лучей. Поддерживается переключение режима частица/волна клавишей W.
## Tags: optics, prism, light, particle, wave, rainbow, physics, visualization

extends UniCoreModule

var _world_root: Node3D
var _event_bus: Node
var _module_manager: Node

var _particles: Array[MeshInstance3D] = []
var _particle_data: Array = [] # {pos, vel, color, phase, alive}
var _wave_lines: Array[MeshInstance3D] = []
var _prism: MeshInstance3D
var _source: MeshInstance3D
var _mode: String = "particle" # "particle" or "wave"
var _time: float = 0.0
var _spawn_timer: float = 0.0
var _wave_phase: float = 0.0

const SOURCE_POS := Vector3(-4.0, 1.5, 0.0)
const PRISM_POS := Vector3(0.0, 1.5, 0.0)
const SPECTRUM_COLORS := [
	Color(1.0, 0.0, 0.0),   # red
	Color(1.0, 0.5, 0.0),   # orange
	Color(1.0, 1.0, 0.0),   # yellow
	Color(0.0, 1.0, 0.0),   # green
	Color(0.0, 0.5, 1.0),   # blue
	Color(0.3, 0.0, 1.0),   # indigo
	Color(0.6, 0.0, 1.0),   # violet
]

func get_module_id() -> String:
	return "prism_interference_experiment"

func get_module_name() -> String:
	return "Интерференция света в призме"

func get_action_bindings() -> Array[Dictionary]:
	return [
		{ 'action': 'prism_toggle_mode', 'label': 'Переключить режим (частица/волна)', 'default_key': KEY_W, 'description': 'Переключает визуализацию света между частицами и волной' }
	]

func initialize(context: Dictionary) -> bool:
	_world_root = context.get('world_root', null)
	_event_bus = context.get('event_bus', null)
	_module_manager = context.get('module_manager', null)

	if _world_root == null:
		push_error("prism_interference_experiment: world_root is null")
		return false

	_build_scene()
	return true

func _build_scene() -> void:
	# Prism (triangular)
	_prism = MeshInstance3D.new()
	var prism_mesh = PrismMesh.new()
	prism_mesh.size = Vector3(1.5, 1.5, 1.5)
	_prism.mesh = prism_mesh
	var prism_mat = StandardMaterial3D.new()
	prism_mat.albedo_color = Color(0.7, 0.85, 1.0, 0.35)
	prism_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	prism_mat.metallic = 0.3
	prism_mat.roughness = 0.1
	_prism.material_override = prism_mat
	_prism.position = PRISM_POS
	_prism.rotation_degrees = Vector3(0, 0, 0)
	add_child(_prism)

	# Light source (glowing sphere)
	_source = MeshInstance3D.new()
	var src_mesh = SphereMesh.new()
	src_mesh.radius = 0.25
	src_mesh.height = 0.5
	_source.mesh = src_mesh
	var src_mat = StandardMaterial3D.new()
	src_mat.albedo_color = Color(1.0, 1.0, 0.8)
	src_mat.emission_enabled = true
	src_mat.emission = Color(1.0, 1.0, 0.8)
	src_mat.emission_energy_multiplier = 3.0
	_source.material_override = src_mat
	_source.position = SOURCE_POS
	add_child(_source)

	# Add a small light
	var light = OmniLight3D.new()
	light.light_color = Color(1.0, 1.0, 0.9)
	light.light_energy = 2.0
	light.omni_range = 4.0
	light.position = SOURCE_POS
	add_child(light)

	# Pre-create particle pool
	for i in range(60):
		var p = MeshInstance3D.new()
		var s = SphereMesh.new()
		s.radius = 0.06
		s.height = 0.12
		p.mesh = s
		var m = StandardMaterial3D.new()
		m.albedo_color = Color.WHITE
		m.emission_enabled = true
		m.emission = Color.WHITE
		m.emission_energy_multiplier = 2.5
		p.material_override = m
		p.visible = false
		add_child(p)
		_particles.append(p)
		_particle_data.append({
			"pos": Vector3.ZERO,
			"vel": Vector3.ZERO,
			"color": Color.WHITE,
			"alive": false,
			"phase": 0.0,
			"stage": 0, # 0 = to prism, 1 = refracted
			"refract_dir": Vector3.ZERO,
			"refract_color": Color.WHITE,
		})

	# Wave lines pool (for wave mode)
	for i in range(7):
		var w = MeshInstance3D.new()
		var cyl = CylinderMesh.new()
		cyl.top_radius = 0.02
		cyl.bottom_radius = 0.02
		cyl.height = 1.0
		w.mesh = cyl
		var wm = StandardMaterial3D.new()
		wm.albedo_color = SPECTRUM_COLORS[i]
		wm.emission_enabled = true
		wm.emission = SPECTRUM_COLORS[i]
		wm.emission_energy_multiplier = 2.0
		w.material_override = wm
		w.visible = false
		add_child(w)
		_wave_lines.append(w)

func _process(delta: float) -> void:
	_time += delta
	if _mode == "particle":
		_update_particles(delta)
	else:
		_update_wave(delta)

func _update_particles(delta: float) -> void:
	# Spawn new particles from source
	_spawn_timer -= delta
	if _spawn_timer <= 0.0:
		_spawn_timer = 0.05
		_spawn_particle()

	for i in range(_particles.size()):
		var data = _particle_data[i]
		var p = _particles[i]
		if not data["alive"]:
			continue

		data["pos"] += data["vel"] * delta
		data["phase"] += delta * 8.0

		if data["stage"] == 0:
			# Traveling to prism
			if data["pos"].distance_to(PRISM_POS) < 0.9:
				# Refract: split into spectrum direction
				data["stage"] = 1
				var idx = randi() % SPECTRUM_COLORS.size()
				data["refract_color"] = SPECTRUM_COLORS[idx]
				var angle = lerp(-0.6, 0.6, float(idx) / float(SPECTRUM_COLORS.size() - 1))
				var dir = Vector3(cos(angle), sin(angle) * 0.3, 0.0).normalized()
				data["refract_dir"] = dir
				data["vel"] = dir * 4.0
				var m = p.material_override as StandardMaterial3D
				m.albedo_color = data["refract_color"]
				m.emission = data["refract_color"]
		else:
			# Refracted - fade out
			if data["pos"].length() > 8.0 or data["pos"].x > 6.0:
				data["alive"] = false
				p.visible = false
				continue

		p.position = data["pos"]
		# Pulse size
		var pulse = 1.0 + sin(data["phase"]) * 0.3
		p.scale = Vector3.ONE * pulse

func _spawn_particle() -> void:
	for i in range(_particles.size()):
		var data = _particle_data[i]
		if not data["alive"]:
			data["alive"] = true
			data["stage"] = 0
			data["pos"] = SOURCE_POS + Vector3(randf_range(-0.1, 0.1), randf_range(-0.1, 0.1), randf_range(-0.1, 0.1))
			var target = PRISM_POS + Vector3(randf_range(-0.3, 0.3), randf_range(-0.3, 0.3), randf_range(-0.3, 0.3))
			data["vel"] = (target - data["pos"]).normalized() * 3.5
			data["phase"] = randf() * TAU
			var p = _particles[i]
			var m = p.material_override as StandardMaterial3D
			m.albedo_color = Color(1.0, 1.0, 0.9)
			m.emission = Color(1.0, 1.0, 0.9)
			p.visible = true
			p.position = data["pos"]
			return

func _update_wave(delta: float) -> void:
	_wave_phase += delta * 3.0
	# Show wave lines fanning out from prism
	for i in range(_wave_lines.size()):
		var w = _wave_lines[i]
		w.visible = true
		var angle = lerp(-0.7, 0.7, float(i) / float(_wave_lines.size() - 1))
		var dir = Vector3(cos(angle), sin(angle) * 0.4, 0.0)
		var length = 3.0 + sin(_wave_phase + i * 0.5) * 0.5
		var start = PRISM_POS + dir * 0.8
		var end = PRISM_POS + dir * (0.8 + length)
		var mid = (start + end) * 0.5
		w.position = mid
		w.scale = Vector3(1.0, length, 1.0)
		# Orient cylinder along dir
		var up = Vector3.UP
		var axis = up.cross(dir).normalized()
		if axis.length() > 0.001:
			var angle_rad = up.angle_to(dir)
			w.quaternion = Quaternion(axis, angle_rad)
		# Pulse emission
		var m = w.material_override as StandardMaterial3D
		m.emission_energy_multiplier = 1.5 + sin(_wave_phase * 2.0 + i) * 0.8

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("prism_toggle_mode"):
		_toggle_mode()

func _toggle_mode() -> void:
	if _mode == "particle":
		_mode = "wave"
		for p in _particles:
			p.visible = false
		for d in _particle_data:
			d["alive"] = false
	else:
		_mode = "particle"
		for w in _wave_lines:
			w.visible = false

func cleanup() -> void:
	for p in _particles:
		if is_instance_valid(p):
			p.queue_free()
	_particles.clear()
	_particle_data.clear()
	for w in _wave_lines:
		if is_instance_valid(w):
			w.queue_free()
	_wave_lines.clear()
	if is_instance_valid(_prism):
		_prism.queue_free()
	if is_instance_valid(_source):
		_source.queue_free()
	queue_free()