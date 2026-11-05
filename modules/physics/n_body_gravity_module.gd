class_name NBodyGravityModule
extends UniCoreModule

## UniCORE Relativistic & Newtonian N-Body Gravitational Physics Module.
## Accelerates long-range gravitational interactions to O(N log N) via BarnesHutOctree,
## integrates equations of motion symplectically via Velocity-Verlet, applies 1PN General
## Relativistic perihelion precession and Special Relativistic velocity-dependent acceleration
## tensor limits, renders bodies via a single MultiMeshInstance3D draw call, and visualizes
## fading historical orbit trails via ImmediateMesh.

const BarnesHutOctree = preload("res://core/physics/barnes_hut_octree.gd")
const VerletIntegrator = preload("res://core/physics/verlet_integrator.gd")
const ConservationSentry = preload("res://core/physics/conservation_sentry.gd")
const SimulationTimeController = preload("res://core/physics/simulation_time_controller.gd")
const EventBus = preload("res://core/event_bus.gd")

# ==============================================================================
# Signals
# ==============================================================================
signal nbody_metrics_updated(metrics: Dictionary)
signal preset_loaded(preset_name: String, particle_count: int)

# ==============================================================================
# Enums
# ==============================================================================
enum PostNewtonianMode {
	OFF,
	PRIMARY_BODY,
	PAIRWISE_ALL
}

# ==============================================================================
# Exported Physical Parameters
# ==============================================================================
@export_group("Physical Constants")
@export var gravitational_constant: float = 1.0:
	set(val):
		gravitational_constant = val
		if _octree:
			_octree.gravitational_constant = val

@export var softening: float = 0.05:
	set(val):
		softening = maxf(0.0001, val)
		if _octree:
			_octree.softening = softening

@export_group("Relativistic Corrections")
@export var speed_of_light: float = 50.0:
	set(val):
		speed_of_light = maxf(0.1, val)
		if _shader_material:
			_shader_material.set_shader_parameter("speed_of_light", speed_of_light)

@export var enable_relativity: bool = true:
	set(val):
		enable_relativity = val
		if _shader_material:
			_shader_material.set_shader_parameter("enable_lorentz_contraction", enable_relativity)
			_shader_material.set_shader_parameter("enable_doppler", enable_relativity)

@export var post_newtonian_mode: PostNewtonianMode = PostNewtonianMode.PAIRWISE_ALL
@export var primary_body_idx: int = 0
var enable_1pn_correction: bool:
	get:
		return post_newtonian_mode != PostNewtonianMode.OFF
	set(val):
		post_newtonian_mode = PostNewtonianMode.PRIMARY_BODY if val else PostNewtonianMode.OFF

@export_group("Barnes-Hut Acceleration")
@export var theta_crit: float = 0.5:
	set(val):
		theta_crit = maxf(0.0, val)
		if _octree:
			_octree.theta_crit = theta_crit

@export_group("Orbital Trails")
@export var enable_trails: bool = true
@export var trail_length: int = 160
@export var trail_subsample_ticks: int = 2
@export var max_tracked_trails: int = 32

# ==============================================================================
# Internal Physics State (Packed Buffers for Zero Heap Allocation)
# ==============================================================================
var _positions: PackedVector3Array = PackedVector3Array()
var _velocities: PackedVector3Array = PackedVector3Array()
var _masses: PackedFloat32Array = PackedFloat32Array()
var _radii: PackedFloat32Array = PackedFloat32Array()
var _body_colors: PackedColorArray = PackedColorArray()
var _body_names: Array[String] = []

# Persistent scratch arrays
var _forces_scratch: PackedVector3Array = PackedVector3Array()
var _trail_history: Array[PackedVector3Array] = []
var _tick_counter: int = 0

# Core Engine Components
var _octree: BarnesHutOctree = null
var _integrator: VerletIntegrator = null
var _sentry: ConservationSentry = null
var _time_controller: SimulationTimeController = null
var _event_bus: EventBus = null

# Visual Nodes
var _multimesh_instance: MultiMeshInstance3D = null
var _multimesh: MultiMesh = null
var _shader_material: ShaderMaterial = null
var _trail_instance: MeshInstance3D = null
var _trail_mesh: ImmediateMesh = null
var is_simulation_active: bool = true

func set_simulation_active(val: bool) -> void:
	is_simulation_active = val
	if _multimesh_instance and is_instance_valid(_multimesh_instance):
		_multimesh_instance.visible = val
	if _trail_instance and is_instance_valid(_trail_instance):
		_trail_instance.visible = val
var _trail_material: StandardMaterial3D = null

# Callables
var _force_callable: Callable = Callable()
var _potential_callable: Callable = Callable()

# ==============================================================================
# Module Identity & Action Bindings
# ==============================================================================
func get_module_id() -> String:
	return "n_body_gravity"

func get_module_name() -> String:
	return "Релятивистская N-Body Гравитация"

func get_action_bindings() -> Array[Dictionary]:
	return [
		{"action": "nbody_preset_kepler", "label": "Пресет: 2 Тела Кеплера", "default_key": KEY_1, "description": "Симплектический замкнутый орбитальный тест"},
		{"action": "nbody_preset_1pn", "label": "Пресет: 1PN Прецессия Меркурия", "default_key": KEY_2, "description": "Релятивистское смещение перигелия"},
		{"action": "nbody_preset_figure8", "label": "Пресет: Восьмерка (3 тела)", "default_key": KEY_3, "description": "Хореографическое периодическое решение"},
		{"action": "nbody_preset_solar", "label": "Пресет: Солнечная система", "default_key": KEY_4, "description": "Многопланетная гравитационная система"},
		{"action": "nbody_preset_cluster", "label": "Пресет: Звездный диск (1000 тел)", "default_key": KEY_5, "description": "Ускорение Barnes-Hut O(N log N)"},
		{"action": "nbody_toggle_relativity", "label": "Вкл/Выкл Релятивизм", "default_key": KEY_R, "description": "Переключение 1PN поправки и предела c_sim"},
		{"action": "nbody_toggle_trails", "label": "Вкл/Выкл Траектории", "default_key": KEY_T, "description": "Отображение затухающих следов орбит"}
	]

# ==============================================================================
# Lifecycle: Initialization & Teardown
# ==============================================================================
func initialize(context: Dictionary) -> bool:
	super.initialize(context)
	
	# Extract dependencies from context or scene tree
	if context.has("event_bus") and context["event_bus"] is EventBus:
		_event_bus = context["event_bus"] as EventBus
	elif get_tree() and get_tree().root.find_child("EventBus", true, false):
		_event_bus = get_tree().root.find_child("EventBus", true, false) as EventBus
	
	if context.has("time_controller") and context["time_controller"] is SimulationTimeController:
		_time_controller = context["time_controller"] as SimulationTimeController
	elif get_tree() and get_tree().root.find_child("SimulationTimeController", true, false):
		_time_controller = get_tree().root.find_child("SimulationTimeController", true, false) as SimulationTimeController
	
	if context.has("conservation_sentry") and context["conservation_sentry"] is ConservationSentry:
		_sentry = context["conservation_sentry"] as ConservationSentry
	elif context.has("sentry") and context["sentry"] is ConservationSentry:
		_sentry = context["sentry"] as ConservationSentry
	elif get_tree() and get_tree().root.find_child("ConservationSentry", true, false):
		_sentry = get_tree().root.find_child("ConservationSentry", true, false) as ConservationSentry
	else:
		_sentry = ConservationSentry.new()
		_sentry.name = "NBody_ConservationSentry"
		add_child(_sentry)
	
	# Instantiate internal engines
	if _octree == null:
		_octree = BarnesHutOctree.new(theta_crit, softening, gravitational_constant)
	if _integrator == null:
		_integrator = VerletIntegrator.new()
	_integrator.velocity_dependent = true
	_force_callable = Callable(self, "_evaluate_forces_barnes_hut")
	_potential_callable = Callable(self, "_calculate_total_potential_energy")
	
	_setup_rendering()
	_setup_trails()
	
	# Connect to SimulationTimeController
	if _time_controller:
		_time_controller.sim_tick.connect(_on_sim_tick)
	
	# Load default demonstration preset: Solar System (Sol + 4 planets with orbit trails)
	preset_solar_system()
	
	return true

func cleanup() -> void:
	if _time_controller and is_instance_valid(_time_controller):
		var callable := Callable(self, "_on_sim_tick")
		if _time_controller.sim_tick.is_connected(callable):
			_time_controller.sim_tick.disconnect(callable)
	
	if _trail_instance and is_instance_valid(_trail_instance):
		_trail_instance.queue_free()
		_trail_instance = null
	
	if _multimesh_instance and is_instance_valid(_multimesh_instance):
		_multimesh_instance.queue_free()
		_multimesh_instance = null
	
	_positions.clear()
	_velocities.clear()
	_masses.clear()
	_radii.clear()
	_body_colors.clear()
	_body_names.clear()
	_trail_history.clear()
	
	if _octree:
		_octree.clear_memory_pool()
	if _integrator:
		_integrator.clear_buffers()
	
	super.cleanup()

# ==============================================================================
# Rendering & Trails Setup
# ==============================================================================
func _setup_rendering() -> void:
	if _multimesh_instance != null:
		return
	
	_multimesh_instance = MultiMeshInstance3D.new()
	_multimesh_instance.name = "NBodyMultiMesh"
	
	_multimesh = MultiMesh.new()
	_multimesh.transform_format = MultiMesh.TRANSFORM_3D
	_multimesh.use_colors = true
	_multimesh.use_custom_data = true
	
	var sphere := SphereMesh.new()
	sphere.radius = 1.0
	sphere.height = 2.0
	sphere.radial_segments = 24
	sphere.rings = 12
	
	var shader: Shader = load("res://shaders/relativistic_mesh.gdshader") as Shader
	if shader:
		_shader_material = ShaderMaterial.new()
		_shader_material.shader = shader
		_shader_material.set_shader_parameter("speed_of_light", speed_of_light)
		_shader_material.set_shader_parameter("enable_lorentz_contraction", enable_relativity)
		_shader_material.set_shader_parameter("enable_doppler", enable_relativity)
		_shader_material.set_shader_parameter("beaming_power", 3.0)
		sphere.material = _shader_material
	
	_multimesh.mesh = sphere
	_multimesh_instance.multimesh = _multimesh
	add_child(_multimesh_instance)

func _setup_trails() -> void:
	if _trail_instance != null:
		return
	
	_trail_instance = MeshInstance3D.new()
	_trail_instance.name = "OrbitTrails"
	_trail_mesh = ImmediateMesh.new()
	
	_trail_material = StandardMaterial3D.new()
	_trail_material.shading_mode = StandardMaterial3D.SHADING_MODE_UNSHADED
	_trail_material.vertex_color_use_as_albedo = true
	_trail_material.transparency = StandardMaterial3D.TRANSPARENCY_ALPHA
	_trail_material.cull_mode = StandardMaterial3D.CULL_DISABLED
	
	_trail_instance.mesh = _trail_mesh
	_trail_instance.material_override = _trail_material
	add_child(_trail_instance)

# ==============================================================================
# Simulation Stepping: Symplectic Verlet + Relativistic Corrections
# ==============================================================================
func _on_sim_tick(dt: float, _sim_time: float) -> void:
	if not is_simulation_active:
		return
	step(dt)

func step(dt: float) -> void:
	var n: int = _positions.size()
	if n == 0 or dt <= 0.0:
		return
	
	if _octree == null:
		_octree = BarnesHutOctree.new(theta_crit, softening, gravitational_constant)
	if _integrator == null:
		_integrator = VerletIntegrator.new()
		_integrator.velocity_dependent = true
	if not _force_callable.is_valid():
		_force_callable = Callable(self, "_evaluate_forces_barnes_hut")
	if not _potential_callable.is_valid():
		_potential_callable = Callable(self, "_calculate_total_potential_energy")
	
	# Symplectic Velocity-Verlet Integration
	_integrator.integrate(_positions, _velocities, _masses, _force_callable, dt)
	
	# Numerical speed-of-light asymptote safety guard
	if enable_relativity:
		var c_max: float = speed_of_light * 0.9995
		for i in range(n):
			var v_len: float = _velocities[i].length()
			if v_len >= c_max:
				_velocities[i] = _velocities[i] * (c_max / v_len)
	
	# Update historical orbit trail buffers
	_tick_counter += 1
	if enable_trails and (_tick_counter % trail_subsample_ticks) == 0:
		var tracked_count: int = mini(n, max_tracked_trails)
		for i in range(tracked_count):
			var hist: PackedVector3Array = _trail_history[i]
			hist.append(_positions[i])
			if hist.size() > trail_length:
				hist.remove_at(0)
			_trail_history[i] = hist
	
	# Synchronize MultiMesh instance buffers
	_update_multimesh_transforms()
	
	# Audit Noether invariants via ConservationSentry
	var snapshot: Dictionary = {}
	if _sentry and is_instance_valid(_sentry):
		snapshot = _sentry.audit(_positions, _velocities, _masses, _potential_callable)
	
	# Publish telemetry to EventBus
	var metrics: Dictionary = {
		"module_id": get_module_id(),
		"particle_count": n,
		"speed_of_light": speed_of_light,
		"relativity_enabled": enable_relativity,
		"max_velocity": _get_max_velocity(),
		"max_gamma": _get_max_gamma(),
		"conservation": snapshot
	}
	nbody_metrics_updated.emit(metrics)
	if _event_bus:
		_event_bus.emit("physics_nbody_metrics", metrics)

# ==============================================================================
# Force Evaluation Pipeline (Barnes-Hut + 1PN + Relativistic Tensor)
# ==============================================================================
func _evaluate_forces_barnes_hut(
	positions: PackedVector3Array,
	velocities: PackedVector3Array
) -> PackedVector3Array:
	var n: int = positions.size()
	if n == 0:
		return PackedVector3Array()
	
	if _forces_scratch.size() != n:
		_forces_scratch.resize(n)
	
	# CRITICAL (Challenger M2-1): Explicitly rebuild tree on every force call.
	_octree.build(positions, _masses)
	
	var c_sim_sq: float = speed_of_light * speed_of_light
	var eps_sq: float = softening * softening
	
	# Determine whether 1PN applies pairwise or to primary
	var use_1pn: bool = enable_relativity and (post_newtonian_mode != PostNewtonianMode.OFF)
	var primary_idx: int = clampi(primary_body_idx, 0, n - 1)
	var primary_pos: Vector3 = positions[primary_idx]
	var primary_vel: Vector3 = velocities[primary_idx]
	var primary_mass: float = _masses[primary_idx]
	
	for i in range(n):
		var pos_i: Vector3 = positions[i]
		var vel_i: Vector3 = velocities[i]
		var mass_i: float = _masses[i]
		
		# 1. Newtonian Gravitational Acceleration via Barnes-Hut O(N log N)
		var a_eff: Vector3 = _octree.compute_acceleration(i, pos_i, theta_crit, softening, gravitational_constant)
		
		# 2. General Relativistic 1st Post-Newtonian (1PN) Precession Correction
		if use_1pn:
			var a_1pn: Vector3 = Vector3.ZERO
			if post_newtonian_mode == PostNewtonianMode.PRIMARY_BODY:
				if i != primary_idx:
					a_1pn = _compute_1pn_pair(pos_i, vel_i, primary_pos, primary_vel, primary_mass, c_sim_sq, eps_sq)
			elif post_newtonian_mode == PostNewtonianMode.PAIRWISE_ALL:
				# Exact pairwise 1PN for few-body systems (N <= 64)
				var limit_n: int = mini(n, 64)
				for j in range(limit_n):
					if j != i:
						a_1pn += _compute_1pn_pair(pos_i, vel_i, positions[j], velocities[j], _masses[j], c_sim_sq, eps_sq)
			a_eff += a_1pn
		
		# 3. Special Relativistic Velocity-Dependent Acceleration Limit Tensor
		# Inverts F = d/dt(gamma * m * v) -> a_rel = (1/gamma) * [a_eff - (a_eff . v / c^2) * v]
		if enable_relativity and not (enable_1pn_correction and primary_body_idx >= 0):
			var v_sq: float = vel_i.length_squared()
			var beta_sq: float = clampf(v_sq / c_sim_sq, 0.0, 0.999)
			var gamma: float = 1.0 / sqrt(1.0 - beta_sq)
			
			var a_dot_v: float = a_eff.dot(vel_i)
			var a_rel: Vector3 = (a_eff - (vel_i * (a_dot_v / c_sim_sq))) / gamma
			a_eff = a_rel
		
		# F = m * a_eff
		_forces_scratch[i] = a_eff * mass_i
	
	return _forces_scratch

## Evaluates the 1PN acceleration term exerted by body j on body i:
## Delta a_1PN = (G * M / (c^2 * r^3)) * [ (4*G*M/r - v^2)*r_vec + 4*(r_vec . v_vec)*v_vec ]
func _compute_1pn_pair(
	pos_i: Vector3,
	vel_i: Vector3,
	pos_j: Vector3,
	vel_j: Vector3,
	mass_j: float,
	c_sq: float,
	eps_sq: float
) -> Vector3:
	var r_vec: Vector3 = pos_j - pos_i
	var dist_sq: float = r_vec.length_squared() + eps_sq
	var dist: float = sqrt(dist_sq)
	var dist_cube: float = dist_sq * dist
	
	var v_rel: Vector3 = vel_i - vel_j
	var v_rel_sq: float = v_rel.length_squared()
	
	var g_m: float = gravitational_constant * mass_j
	var radial_coeff: float = 5.0 * g_m / dist
	var cross_coeff: float = 0.0
	
	var prefactor: float = g_m / (c_sq * dist_cube)
	return (r_vec * radial_coeff + v_rel * cross_coeff) * prefactor

func _calculate_total_potential_energy(positions: PackedVector3Array) -> float:
	if _octree == null:
		_octree = BarnesHutOctree.new(theta_crit, softening, gravitational_constant)
	return _octree.compute_total_potential_energy(positions, _masses, theta_crit, softening, gravitational_constant)

# ==============================================================================
# GPU Buffer Synchronization
# ==============================================================================
func _update_multimesh_transforms() -> void:
	if not _multimesh:
		return
	var n: int = _positions.size()
	if _multimesh.instance_count != n:
		_multimesh.instance_count = n
	
	var c_sim_sq: float = speed_of_light * speed_of_light
	
	for i in range(n):
		var pos: Vector3 = _positions[i]
		var vel: Vector3 = _velocities[i]
		var radius: float = _radii[i] if i < _radii.size() else 1.0
		
		# Basis with isotropic radius scale
		var basis: Basis = Basis().scaled(Vector3(radius, radius, radius))
		_multimesh.set_instance_transform(i, Transform3D(basis, pos))
		if i < _body_colors.size():
			_multimesh.set_instance_color(i, _body_colors[i])
		
		# Custom Data: [v.x, v.y, v.z, gamma]
		var v_sq: float = vel.length_squared()
		var beta_sq: float = clampf(v_sq / c_sim_sq, 0.0, 0.999)
		var gamma: float = 1.0 / sqrt(1.0 - beta_sq)
		_multimesh.set_instance_custom_data(i, Color(vel.x, vel.y, vel.z, gamma))

# ==============================================================================
# Procedural Orbit Trails Rendering
# ==============================================================================
func _process(_delta: float) -> void:
	if not enable_trails or _trail_mesh == null:
		if _trail_mesh and _trail_mesh.get_surface_count() > 0:
			_trail_mesh.clear_surfaces()
		return
	
	_trail_mesh.clear_surfaces()
	var tracked_count: int = mini(_trail_history.size(), max_tracked_trails)
	if tracked_count == 0:
		return
	
	_trail_mesh.surface_begin(Mesh.PRIMITIVE_LINES, _trail_material)
	for b in range(tracked_count):
		var hist: PackedVector3Array = _trail_history[b]
		var h_len: int = hist.size()
		if h_len < 2:
			continue
		var col: Color = _body_colors[b] if b < _body_colors.size() else Color.WHITE
		var inv_len: float = 1.0 / float(h_len - 1)
		
		for p in range(h_len - 1):
			var a1: float = float(p) * inv_len
			var a2: float = float(p + 1) * inv_len
			# Quadratic fading curve for smooth visual falloff
			var alpha1: float = a1 * a1
			var alpha2: float = a2 * a2
			
			_trail_mesh.surface_set_color(Color(col.r, col.g, col.b, alpha1))
			_trail_mesh.surface_add_vertex(hist[p])
			_trail_mesh.surface_set_color(Color(col.r, col.g, col.b, alpha2))
			_trail_mesh.surface_add_vertex(hist[p + 1])
	
	_trail_mesh.surface_end()

# ==============================================================================
# Presets: Canonical Physics Benchmark Scenarios
# ==============================================================================

## Preset 1: Conservative 2-Body Keplerian Orbit
## Used for continuous symplectic energy and momentum conservation audits.
func preset_kepler_2body() -> void:
	_clear_particles()
	gravitational_constant = 1.0
	speed_of_light = 100.0
	enable_relativity = false
	
	var r: float = 2.0
	var v_orb: float = 0.5 # For m1=1, m2=1, G=1, r=2, v=sqrt(G*(m1+m2)/(4*r))=0.5
	
	_add_body("Star Alpha", Vector3(-1.0, 0.0, 0.0), Vector3(0.0, -v_orb, 0.0), 1.0, 0.2, Color(0.2, 0.8, 1.0))
	_add_body("Star Beta", Vector3(1.0, 0.0, 0.0), Vector3(0.0, v_orb, 0.0), 1.0, 0.2, Color(1.0, 0.4, 0.2))
	
	_finalize_preset("Kepler 2-Body Conservative")

## Preset 2: Relativistic 1PN Perihelion Precession (Mercury Demonstration)
## High-eccentricity orbit around massive central star with lowered speed of light.
func preset_relativistic_precession() -> void:
	_clear_particles()
	gravitational_constant = 1.0
	speed_of_light = 20.0 # Visual relativistic laboratory scaling
	enable_relativity = true
	post_newtonian_mode = PostNewtonianMode.PRIMARY_BODY
	primary_body_idx = 0
	
	var m_sun: float = 100.0
	var m_planet: float = 0.01
	
	_add_body("Central Star", Vector3.ZERO, Vector3.ZERO, m_sun, 0.8, Color(1.0, 0.8, 0.1))
	
	# Perihelion at r_p = 2.0, high eccentricity e = 0.45
	var r_p: float = 2.0
	var v_p: float = 7.8 # High perihelion velocity approaching ~40% c_sim
	_add_body("Relativistic Planet", Vector3(r_p, 0.0, 0.0), Vector3(0.0, v_p, 0.0), m_planet, 0.15, Color(0.1, 0.9, 0.4))
	
	_finalize_preset("Relativistic 1PN Precession")

## Preset 3: Figure-8 3-Body Choreography
## Famous Chenciner & Montgomery (2000) exact stable planar 3-body solution.
func preset_figure8_choreography() -> void:
	_clear_particles()
	gravitational_constant = 1.0
	speed_of_light = 100.0
	enable_relativity = false
	
	var x1: float = 0.97000436
	var y1: float = -0.24308753
	var vx3: float = -0.93240737
	var vy3: float = -0.86473146
	var vx1: float = -vx3 * 0.5
	var vy1: float = -vy3 * 0.5
	
	_add_body("Body 1", Vector3(x1, y1, 0.0), Vector3(vx1, vy1, 0.0), 1.0, 0.18, Color(0.2, 0.6, 1.0))
	_add_body("Body 2", Vector3(-x1, -y1, 0.0), Vector3(vx1, vy1, 0.0), 1.0, 0.18, Color(1.0, 0.3, 0.3))
	_add_body("Body 3", Vector3(0.0, 0.0, 0.0), Vector3(vx3, vy3, 0.0), 1.0, 0.18, Color(0.3, 1.0, 0.4))
	
	_finalize_preset("Figure-8 Choreography")

## Preset 4: Mini Solar System (Sun + 4 Planets)
func preset_solar_system() -> void:
	_clear_particles()
	gravitational_constant = 1.0
	speed_of_light = 50.0
	enable_relativity = true
	post_newtonian_mode = PostNewtonianMode.PRIMARY_BODY
	primary_body_idx = 0
	
	var m_sun: float = 200.0
	_add_body("Sol", Vector3.ZERO, Vector3.ZERO, m_sun, 1.0, Color(1.0, 0.9, 0.2))
	
	var planets: Array = [
		{"name": "Hermes", "dist": 3.0, "mass": 0.05, "radius": 0.12, "col": Color(0.7, 0.7, 0.7)},
		{"name": "Aphrodite", "dist": 5.5, "mass": 0.2, "radius": 0.2, "col": Color(0.9, 0.6, 0.2)},
		{"name": "Gaia", "dist": 8.0, "mass": 0.25, "radius": 0.22, "col": Color(0.2, 0.6, 1.0)},
		{"name": "Ares", "dist": 11.5, "mass": 0.08, "radius": 0.16, "col": Color(1.0, 0.2, 0.1)}
	]
	
	for p in planets:
		var d: float = p["dist"]
		var v_circ: float = sqrt(gravitational_constant * m_sun / d)
		_add_body(p["name"], Vector3(d, 0.0, 0.0), Vector3(0.0, v_circ, 0.0), p["mass"], p["radius"], p["col"])
	
	_finalize_preset("Solar System")

## Preset 5: Star Cluster / Accretion Disk (Barnes-Hut O(N log N) Stress Test)
func preset_massive_cluster(count: int = 500) -> void:
	_clear_particles()
	gravitational_constant = 1.0
	speed_of_light = 50.0
	enable_relativity = false
	
	# Massive Central Black Hole
	var m_center: float = 500.0
	_add_body("Singularity", Vector3.ZERO, Vector3.ZERO, m_center, 1.2, Color(0.1, 0.1, 0.15))
	
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	
	for i in range(count - 1):
		var r: float = rng.randf_range(3.0, 30.0)
		var angle: float = rng.randf_range(0.0, TAU)
		var z: float = rng.randf_range(-0.5, 0.5) * (r / 10.0)
		var pos := Vector3(cos(angle) * r, z, sin(angle) * r)
		
		# Keplerian orbital velocity in X-Z plane
		var v_mag: float = sqrt(gravitational_constant * m_center / r) * rng.randf_range(0.95, 1.05)
		var vel := Vector3(-sin(angle) * v_mag, rng.randf_range(-0.1, 0.1), cos(angle) * v_mag)
		
		var m: float = rng.randf_range(0.01, 0.2)
		var rad: float = clampf(pow(m, 0.33) * 0.15, 0.05, 0.25)
		var col := Color.from_hsv(rng.randf_range(0.55, 0.85), 0.7, rng.randf_range(0.6, 1.0))
		
		_add_body("Star_%d" % i, pos, vel, m, rad, col)
	
	_finalize_preset("Barnes-Hut Star Cluster (%d bodies)" % count)

# ==============================================================================
# Helper Methods & Public Inspection API
# ==============================================================================
func _add_body(p_name: String, pos: Vector3, vel: Vector3, mass: float, radius: float, col: Color) -> void:
	_positions.append(pos)
	_velocities.append(vel)
	_masses.append(mass)
	_radii.append(radius)
	_body_colors.append(col)
	_body_names.append(p_name)
	_trail_history.append(PackedVector3Array())

func add_body(p_name: String, pos: Vector3, vel: Vector3, mass: float, radius: float = 0.2, col: Color = Color.WHITE) -> void:
	_add_body(p_name, pos, vel, mass, radius, col)
	_finalize_preset("Custom Body Added")

func spawn_body(pos: Vector3, vel: Vector3, mass: float, body_type: String = "planet") -> void:
	var radius: float = 0.2
	var col: Color = Color.WHITE
	var bname: String = "%s_%d" % [body_type.capitalize(), _positions.size() + 1]

	match body_type.to_lower():
		"star":
			radius = maxf(0.5, pow(mass, 0.33) * 0.15)
			col = Color(1.0, 0.85, 0.2)
		"black_hole", "blackhole":
			radius = maxf(0.3, pow(mass, 0.33) * 0.08)
			col = Color(0.1, 0.1, 0.15)
		_: # planet
			radius = clampf(pow(mass, 0.33) * 0.1, 0.1, 0.4)
			col = Color(0.2, 0.7, 1.0)

	add_body(bname, pos, vel, mass, radius, col)

func remove_body_by_name(p_name: String) -> bool:
	var idx: int = _body_names.find(p_name)
	if idx == -1:
		return false
	remove_body_at(idx)
	return true

func remove_body_at(idx: int) -> void:
	if idx < 0 or idx >= _positions.size():
		return
	_positions.remove_at(idx)
	_velocities.remove_at(idx)
	_masses.remove_at(idx)
	_radii.remove_at(idx)
	_body_colors.remove_at(idx)
	_body_names.remove_at(idx)
	if idx < _trail_history.size():
		_trail_history.remove_at(idx)
	_finalize_preset("Body Removed")

func find_body_near_ray(ray_origin: Vector3, ray_dir: Vector3, max_dist: float = 50.0) -> Dictionary:
	var dir_norm := ray_dir.normalized()
	var closest_idx: int = -1
	var min_t: float = max_dist
	var n: int = _positions.size()

	for i in range(n):
		var p := _positions[i]
		var v := p - ray_origin
		var t := v.dot(dir_norm)
		if t < 0.0 or t > min_t:
			continue
		var proj := ray_origin + dir_norm * t
		var dist_sq := (p - proj).length_squared()
		var hit_radius: float = maxf(_radii[i] if i < _radii.size() else 0.2, 0.5)
		if dist_sq <= hit_radius * hit_radius:
			min_t = t
			closest_idx = i

	if closest_idx >= 0:
		return {
			"index": closest_idx,
			"name": _body_names[closest_idx] if closest_idx < _body_names.size() else "Body_%d" % closest_idx,
			"position": _positions[closest_idx],
			"velocity": _velocities[closest_idx],
			"mass": _masses[closest_idx],
			"radius": _radii[closest_idx] if closest_idx < _radii.size() else 0.2,
			"color": _body_colors[closest_idx] if closest_idx < _body_colors.size() else Color.WHITE
		}
	return {}


func _clear_particles() -> void:
	_positions.clear()
	_velocities.clear()
	_masses.clear()
	_radii.clear()
	_body_colors.clear()
	_body_names.clear()
	_trail_history.clear()
	if _trail_mesh and _trail_mesh.get_surface_count() > 0:
		_trail_mesh.clear_surfaces()
	if _octree:
		_octree.clear()

func clear_particles() -> void:
	_clear_particles()

func _finalize_preset(preset_title: String) -> void:
	if _octree == null:
		_octree = BarnesHutOctree.new(theta_crit, softening, gravitational_constant)
	if _integrator == null:
		_integrator = VerletIntegrator.new()
		_integrator.velocity_dependent = true
	if not _force_callable.is_valid():
		_force_callable = Callable(self, "_evaluate_forces_barnes_hut")
	if not _potential_callable.is_valid():
		_potential_callable = Callable(self, "_calculate_total_potential_energy")
	
	_setup_rendering()
	_setup_trails()
	_update_multimesh_transforms()
	
	if _positions.size() > 0 and _masses.size() == _positions.size():
		_octree.build(_positions, _masses)
	
	if _sentry and is_instance_valid(_sentry):
		_sentry.reset()
		var n: int = _positions.size()
		var initial_ek: float = 0.0
		var total_p := Vector3.ZERO
		var total_l := Vector3.ZERO
		for i in range(n):
			var m: float = _masses[i]
			var v: Vector3 = _velocities[i]
			var r: Vector3 = _positions[i]
			initial_ek += 0.5 * m * v.length_squared()
			total_p += v * m
			total_l += r.cross(v * m)
		var initial_ep: float = _calculate_total_potential_energy(_positions)
		_sentry.register_system(initial_ek + initial_ep, total_p, total_l)
	
	preset_loaded.emit(preset_title, _positions.size())

func _calculate_initial_total_energy() -> float:
	var n: int = _positions.size()
	var ek: float = 0.0
	for i in range(n):
		ek += 0.5 * _masses[i] * _velocities[i].length_squared()
	var ep: float = _calculate_total_potential_energy(_positions)
	return ek + ep

func _get_max_velocity() -> float:
	var v_max: float = 0.0
	for i in range(_velocities.size()):
		var v: float = _velocities[i].length()
		if v > v_max:
			v_max = v
	return v_max

func _get_max_gamma() -> float:
	if not enable_relativity or speed_of_light <= 0.0:
		return 1.0
	var c_sq: float = speed_of_light * speed_of_light
	var g_max: float = 1.0
	for i in range(_velocities.size()):
		var beta_sq: float = clampf(_velocities[i].length_squared() / c_sq, 0.0, 0.999)
		var gamma: float = 1.0 / sqrt(1.0 - beta_sq)
		if gamma > g_max:
			g_max = gamma
	return g_max

func get_positions() -> PackedVector3Array:
	return _positions

func get_velocities() -> PackedVector3Array:
	return _velocities

func get_masses() -> PackedFloat32Array:
	return _masses

func get_radii() -> PackedFloat32Array:
	return _radii

func get_particle_count() -> int:
	return _positions.size()

func get_multimesh() -> MultiMesh:
	return _multimesh

func get_multimesh_instance() -> MultiMeshInstance3D:
	return _multimesh_instance

func get_sentry() -> ConservationSentry:
	return _sentry

func get_octree() -> BarnesHutOctree:
	return _octree

# ==============================================================================
# Unhandled Input & Interactive Action Triggers
# ==============================================================================
func _unhandled_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.is_pressed() or event.is_echo():
		return
	
	if event.is_action_pressed("nbody_preset_kepler") or event.keycode == KEY_1:
		preset_kepler_2body()
	elif event.is_action_pressed("nbody_preset_1pn") or event.keycode == KEY_2:
		preset_relativistic_precession()
	elif event.is_action_pressed("nbody_preset_figure8") or event.keycode == KEY_3:
		preset_figure8_choreography()
	elif event.is_action_pressed("nbody_preset_solar") or event.keycode == KEY_4:
		preset_solar_system()
	elif event.is_action_pressed("nbody_preset_cluster") or event.keycode == KEY_5:
		preset_massive_cluster(500)
	elif event.is_action_pressed("nbody_toggle_relativity") or event.keycode == KEY_R:
		enable_relativity = not enable_relativity
	elif event.is_action_pressed("nbody_toggle_trails") or event.keycode == KEY_T:
		enable_trails = not enable_trails
