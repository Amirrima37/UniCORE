class_name PhysicsInteractionManager
extends Node3D

## Central 3D Interaction Dispatcher for the UniCORE Scientific Physics Platform.
## Connects observer camera mouse inputs, 3D raycasting, velocity dragging gizmos,
## and tool execution to underlying physical modules without physical collision overhead.

const ScreenRaycaster = preload("res://core/physics/interaction/screen_raycaster.gd")
const VelocityVectorGizmo = preload("res://core/physics/interaction/velocity_vector_gizmo.gd")
const KeplerTrajectoryPreview = preload("res://core/physics/interaction/kepler_trajectory_preview.gd")

signal tool_changed(new_tool: String)
signal entity_selected(entity_info: Dictionary)
signal entity_spawned(module_id: String, entity_data: Dictionary)
signal parameter_modified(module_id: String, param: String, value: Variant)

enum ToolMode {
	SELECT = 0,
	GRAVITY = 1,
	THERMODYNAMICS = 2,
	NUCLEAR = 3,
	QUANTUM = 4,
	SENSOR = 5
}

@export var default_focal_depth: float = 12.0
@export var max_drag_speed: float = 25.0

var current_tool_mode: ToolMode = ToolMode.SELECT
var current_tool_id: String = "select"
var active_domain: String = "gravity"

var _camera: Camera3D = null
var _event_bus: Node = null
var _module_manager: Node = null
var _time_controller: Node = null
var _sentry: Node = null

var _velocity_gizmo: VelocityVectorGizmo = null
var _orbit_preview: KeplerTrajectoryPreview = null

var _is_dragging: bool = false
var _drag_anchor: Vector3 = Vector3.ZERO
var _current_impulse: Vector3 = Vector3.ZERO
var _selected_entity_id: String = ""

# Tool Configuration States (configured via Inspector drawer)
var gravity_spawn_mass: float = 10.0
var gravity_body_type: String = "planet" # "star", "planet", "black_hole"
var thermo_inject_count: int = 50
var thermo_inject_temp: float = 1.5
var nuclear_selected_isotope: String = "U-235"
var quantum_barrier_type: int = 1 # 1: Rectangular, 2: Harmonic, 4: Double Slit
var quantum_barrier_v0: float = 6.0

func _ready() -> void:
	# Instantiate visual gizmos as children
	_velocity_gizmo = VelocityVectorGizmo.new()
	_velocity_gizmo.name = "VelocityGizmo"
	add_child(_velocity_gizmo)
	
	_orbit_preview = KeplerTrajectoryPreview.new()
	_orbit_preview.name = "OrbitPreview"
	add_child(_orbit_preview)

func setup(event_bus: Node, camera: Camera3D, module_manager: Node = null, time_controller: Node = null, sentry: Node = null) -> void:
	_event_bus = event_bus
	_camera = camera
	_module_manager = module_manager
	_time_controller = time_controller
	_sentry = sentry
	
	if _event_bus:
		_event_bus.subscribe("physics_tool_selected", _on_physics_tool_selected)
		_event_bus.subscribe("physics_time_command", _on_physics_time_command)
		_event_bus.subscribe("physics_parameter_changed", _on_physics_parameter_changed)
		_event_bus.subscribe("physics_load_preset", _on_physics_load_preset)
		_event_bus.subscribe("physics_spawn_entity", _on_physics_spawn_entity)
		_event_bus.subscribe("physics_entity_action", _on_physics_entity_action)

	# Initial activation: isolate domains, show only gravity system on start
	call_deferred("switch_domain", "gravity")

func _unhandled_input(event: InputEvent) -> void:
	if not _camera:
		_camera = get_viewport().get_camera_3d()
	if not _camera:
		return
	
	if event is InputEventMouseButton:
		_handle_mouse_button(event as InputEventMouseButton)
	elif event is InputEventMouseMotion and _is_dragging:
		_handle_mouse_motion(event as InputEventMouseMotion)

func _handle_mouse_button(event: InputEventMouseButton) -> void:
	if event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_start_drag(event.position)
		else:
			if _is_dragging:
				_finish_drag()
	elif event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		# Right-click cancels active drag or resets selection
		_cancel_drag()

func _start_drag(screen_pos: Vector2) -> void:
	var hit: Variant = ScreenRaycaster.cast_to_depth_plane(_camera, screen_pos, default_focal_depth)
	if hit == null or not (hit is Vector3):
		return
	
	_drag_anchor = hit as Vector3
	_is_dragging = true
	_current_impulse = Vector3.ZERO
	_velocity_gizmo.set_vector(_drag_anchor, Vector3.ZERO)

func _handle_mouse_motion(event: InputEventMouseMotion) -> void:
	var hit: Variant = ScreenRaycaster.cast_to_camera_facing_plane(_camera, event.position, _drag_anchor)
	if hit == null or not (hit is Vector3):
		return
	
	var current_pos: Vector3 = hit as Vector3
	_current_impulse = (current_pos - _drag_anchor) * 2.0
	if _current_impulse.length() > max_drag_speed:
		_current_impulse = _current_impulse.normalized() * max_drag_speed
	
	_velocity_gizmo.set_vector(_drag_anchor, _current_impulse, max_drag_speed)
	
	# Orbit preview for celestial bodies if gravity tool is active
	if current_tool_mode == ToolMode.GRAVITY and _orbit_preview:
		_orbit_preview.update_orbit(Vector3.ZERO, _drag_anchor, _current_impulse, 1000.0)

func _finish_drag() -> void:
	_is_dragging = false
	_velocity_gizmo.hide_gizmo()
	if _orbit_preview:
		_orbit_preview.clear_orbit()
	
	match current_tool_mode:
		ToolMode.GRAVITY:
			_spawn_celestial_body(_drag_anchor, _current_impulse)
		ToolMode.THERMODYNAMICS:
			_inject_particles(_drag_anchor, _current_impulse)
		ToolMode.NUCLEAR:
			_spawn_nuclear_sample(_drag_anchor, _current_impulse)
		ToolMode.QUANTUM:
			_spawn_quantum_wavepacket(_drag_anchor, _current_impulse)
		ToolMode.SENSOR:
			_spawn_scientific_probe(_drag_anchor)
		ToolMode.SELECT:
			_select_entity_at(_drag_anchor)

func _cancel_drag() -> void:
	_is_dragging = false
	_current_impulse = Vector3.ZERO
	_velocity_gizmo.hide_gizmo()
	if _orbit_preview:
		_orbit_preview.clear_orbit()

# --- Module Resolver Helper ---

func _resolve_module(module_id: String) -> Node:
	if _module_manager and _module_manager.has_method("get_module"):
		var m: Node = _module_manager.get_module(module_id)
		if m and is_instance_valid(m):
			return m
	var root: Node = get_tree().root if get_tree() else null
	if root:
		var m2: Node = root.find_child(module_id, true, false)
		if m2 and is_instance_valid(m2):
			return m2
		var parts := module_id.split("_")
		var pascal: String = ""
		for p in parts:
			pascal += p.capitalize()
		var m3: Node = root.find_child(pascal, true, false)
		if m3 and is_instance_valid(m3):
			return m3
	return null

# --- Tool Execution Handlers ---

func _spawn_celestial_body(pos: Vector3, vel: Vector3) -> void:
	var grav: Node = _resolve_module("n_body_gravity_module")
	if not grav:
		grav = _resolve_module("n_body_gravity")
	
	var r: float = 0.25
	var col: Color = Color(0.2, 0.6, 1.0)
	var mass: float = gravity_spawn_mass
	match gravity_body_type:
		"star":
			r = 1.2
			col = Color(1.0, 0.9, 0.2)
			mass = maxf(mass, 50.0)
		"black_hole":
			r = 0.5
			col = Color(0.6, 0.1, 0.9)
			mass = maxf(mass, 500.0)
		_:
			r = 0.25
			col = Color(0.2, 0.6, 1.0)

	var b_name: String = "%s_%d" % [gravity_body_type.capitalize(), Time.get_ticks_msec() % 10000]
	if grav and grav.has_method("add_body"):
		grav.add_body(b_name, pos, vel, mass, r, col)

	var entity_data := {
		"position": pos,
		"velocity": vel,
		"mass": mass,
		"body_type": gravity_body_type,
		"radius": r,
		"color": col,
		"name": b_name
	}
	entity_spawned.emit("n_body_gravity_module", entity_data)
	if _event_bus:
		_event_bus.publish("physics_entity_spawned", {"module_id": "n_body_gravity_module", "entity": entity_data})

func _inject_particles(pos: Vector3, vel: Vector3) -> void:
	var md: Node = _resolve_module("molecular_dynamics_module")
	if not md:
		md = _resolve_module("molecular_dynamics")
	
	if md and md.has_method("inject_particles"):
		md.inject_particles(pos, thermo_inject_count, thermo_inject_temp, vel)

	var entity_data := {
		"position": pos,
		"initial_velocity": vel,
		"count": thermo_inject_count,
		"temperature": thermo_inject_temp
	}
	entity_spawned.emit("molecular_dynamics_module", entity_data)
	if _event_bus:
		_event_bus.publish("physics_entity_spawned", {"module_id": "molecular_dynamics_module", "entity": entity_data})

func _spawn_nuclear_sample(pos: Vector3, vel: Vector3) -> void:
	var nuc: Node = _resolve_module("nuclear_decay_module")
	if not nuc:
		nuc = _resolve_module("nuclear_decay")
	
	if nuc:
		if vel.length_squared() > 1.0:
			if nuc.has_method("inject_trigger_neutron"):
				nuc.inject_trigger_neutron(pos, vel * 2.0)
		else:
			if nuc.has_method("spawn_nucleus"):
				nuc.spawn_nucleus(pos, vel, nuclear_selected_isotope)

	var entity_data := {
		"position": pos,
		"velocity": vel,
		"isotope": nuclear_selected_isotope
	}
	entity_spawned.emit("nuclear_decay_module", entity_data)
	if _event_bus:
		_event_bus.publish("physics_entity_spawned", {"module_id": "nuclear_decay_module", "entity": entity_data})

func _spawn_quantum_wavepacket(pos: Vector3, impulse: Vector3) -> void:
	var qm: Node = _resolve_module("quantum_wavepacket_module")
	if not qm:
		qm = _resolve_module("quantum_wavepacket")
	
	var k0: float = maxf(impulse.length(), 1.0)
	if qm and qm.has_method("initialize_gaussian_wavepacket"):
		qm.initialize_gaussian_wavepacket(pos.x, 0.8, k0)

	var entity_data := {
		"center": pos,
		"k0": k0,
		"barrier_type": quantum_barrier_type,
		"barrier_v0": quantum_barrier_v0
	}
	entity_spawned.emit("quantum_wavepacket_module", entity_data)
	if _event_bus:
		_event_bus.publish("physics_entity_spawned", {"module_id": "quantum_wavepacket_module", "entity": entity_data})

func _spawn_scientific_probe(pos: Vector3) -> void:
	var entity_data := {
		"position": pos,
		"probe_type": "universal_field_probe"
	}
	entity_spawned.emit("scientific_probe_module", entity_data)
	if _event_bus:
		_event_bus.publish("physics_entity_spawned", {"module_id": "scientific_probe_module", "entity": entity_data})

func _select_entity_at(pos: Vector3) -> void:
	var info: Dictionary = {}
	if _camera:
		var grav: Node = _resolve_module("n_body_gravity_module")
		if not grav:
			grav = _resolve_module("n_body_gravity")
		
		if grav and grav.has_method("find_body_near_ray"):
			var ro := _camera.global_position
			var rd := (pos - ro).normalized()
			var hit: Dictionary = grav.find_body_near_ray(ro, rd, default_focal_depth * 2.0)
			if not hit.is_empty():
				info = {
					"entity_id": str(hit.get("name", "celestial_body")),
					"module_id": "n_body_gravity_module",
					"position": hit.get("position", pos),
					"entity": hit,
					"status": "selected"
				}

	if info.is_empty():
		info = {
			"entity_id": "probe_target",
			"position": pos,
			"status": "active"
		}
	entity_selected.emit(info)
	if _event_bus:
		_event_bus.publish("physics_entity_selected", info)


# --- Domain Isolation & Camera Framing ---

func switch_domain(target_domain: String) -> void:
	active_domain = target_domain.to_lower()
	
	var grav: Node = _resolve_module("n_body_gravity_module")
	var md: Node = _resolve_module("molecular_dynamics_module")
	var nuc: Node = _resolve_module("nuclear_decay_module")
	var qm: Node = _resolve_module("quantum_wavepacket_module")
	
	var is_grav: bool = (active_domain == "gravity" or active_domain == "astrophysics")
	var is_md: bool = (active_domain == "thermodynamics" or active_domain == "thermo" or active_domain == "md")
	var is_nuc: bool = (active_domain == "nuclear")
	var is_qm: bool = (active_domain == "quantum")
	
	if grav and grav.has_method("set_simulation_active"):
		grav.set_simulation_active(is_grav)
	if md and md.has_method("set_simulation_active"):
		md.set_simulation_active(is_md)
	if nuc and nuc.has_method("set_simulation_active"):
		nuc.set_simulation_active(is_nuc)
	if qm and qm.has_method("set_simulation_active"):
		qm.set_simulation_active(is_qm)
	
	_frame_camera_for_domain(active_domain)

func _frame_camera_for_domain(domain: String) -> void:
	if not _camera:
		_camera = get_viewport().get_camera_3d()
	if not _camera:
		return
	
	var avatar_node: Node = _camera.get_parent() # AvatarPitch
	var yaw_node: Node3D = null
	if avatar_node and avatar_node.get_parent() is Node3D:
		yaw_node = avatar_node.get_parent() as Node3D
	
	match domain:
		"gravity", "astrophysics":
			if yaw_node:
				yaw_node.global_position = Vector3(0.0, 14.0, 22.0)
				yaw_node.rotation = Vector3.ZERO
			if avatar_node is Node3D:
				(avatar_node as Node3D).rotation = Vector3(-0.55, 0.0, 0.0)
		"thermodynamics", "thermo", "md":
			if yaw_node:
				yaw_node.global_position = Vector3(0.0, 6.0, 14.0)
				yaw_node.rotation = Vector3.ZERO
			if avatar_node is Node3D:
				(avatar_node as Node3D).rotation = Vector3(-0.35, 0.0, 0.0)
		"nuclear":
			if yaw_node:
				yaw_node.global_position = Vector3(0.0, 0.0, 9.0)
				yaw_node.rotation = Vector3.ZERO
			if avatar_node is Node3D:
				(avatar_node as Node3D).rotation = Vector3.ZERO
		"quantum":
			if yaw_node:
				yaw_node.global_position = Vector3(0.0, 10.0, 15.0)
				yaw_node.rotation = Vector3.ZERO
			if avatar_node is Node3D:
				(avatar_node as Node3D).rotation = Vector3(-0.6, 0.0, 0.0)

# --- EventBus Subscriptions ---

func _on_physics_tool_selected(payload: Dictionary) -> void:
	var tool_id: String = str(payload.get("tool_id", "select")).to_lower()
	current_tool_id = tool_id
	match tool_id:
		"gravity", "1":
			current_tool_mode = ToolMode.GRAVITY
			switch_domain("gravity")
		"thermo", "thermodynamics", "2":
			current_tool_mode = ToolMode.THERMODYNAMICS
			switch_domain("thermodynamics")
		"nuclear", "3":
			current_tool_mode = ToolMode.NUCLEAR
			switch_domain("nuclear")
		"quantum", "4":
			current_tool_mode = ToolMode.QUANTUM
			switch_domain("quantum")
		"sensor", "probe", "5":
			current_tool_mode = ToolMode.SENSOR
		_:
			current_tool_mode = ToolMode.SELECT
	tool_changed.emit(current_tool_id)

func _on_physics_time_command(payload: Dictionary) -> void:
	var cmd: String = str(payload.get("command", ""))
	if not _time_controller:
		return
	
	match cmd:
		"set_paused":
			var paused: bool = bool(payload.get("value", false))
			if _time_controller.has_method("set_paused"):
				_time_controller.set_paused(paused)
		"toggle_pause":
			if _time_controller.has_method("toggle_pause"):
				_time_controller.toggle_pause()
		"step_once":
			if _time_controller.has_method("step_once"):
				_time_controller.step_once()
		"set_time_scale":
			var scale_val: float = float(payload.get("value", 1.0))
			if _time_controller.has_method("set_time_scale"):
				_time_controller.set_time_scale(scale_val)

func _on_physics_parameter_changed(payload: Dictionary) -> void:
	var mod_id: String = str(payload.get("module_id", ""))
	var param: String = str(payload.get("param", ""))
	var val: Variant = payload.get("value")
	
	match param:
		"gravity_mass", "spawn_mass":
			gravity_spawn_mass = float(val)
		"gravity_type", "body_type":
			gravity_body_type = str(val)
		"c_sim", "speed_of_light":
			var grav := _resolve_module("n_body_gravity_module")
			if grav: grav.set("speed_of_light", float(val))
		"gr_1pn_enabled", "enable_1pn_correction":
			var grav := _resolve_module("n_body_gravity_module")
			if grav: grav.set("enable_1pn_correction", bool(val))
		"thermo_temp", "target_temp":
			thermo_inject_temp = float(val)
			var md := _resolve_module("molecular_dynamics_module")
			if md: md.set("target_temperature", float(val))
		"thermo_count", "inject_count":
			thermo_inject_count = int(val)
		"thermostat_enabled":
			var md := _resolve_module("molecular_dynamics_module")
			if md: md.set("enable_thermostat", bool(val))
		"cutoff_rc":
			var md := _resolve_module("molecular_dynamics_module")
			if md: md.set("cutoff_radius", float(val))
		"reset_maxwell":
			var md := _resolve_module("molecular_dynamics_module")
			if md and md.has_method("reset_to_maxwell_boltzmann"):
				md.reset_to_maxwell_boltzmann()
		"nuclear_isotope", "isotope":
			nuclear_selected_isotope = str(val)
		"control_rods":
			var nuc := _resolve_module("nuclear_decay_module")
			if nuc and nuc.has_method("set_control_rod_depth"):
				nuc.set_control_rod_depth(float(val))
		"neutron_pulse":
			var nuc := _resolve_module("nuclear_decay_module")
			if nuc and nuc.has_method("inject_trigger_neutron"):
				nuc.inject_trigger_neutron(Vector3(0, 0, 4.0), Vector3(0, 0, -15.0))
		"quantum_v0", "barrier_height":
			quantum_barrier_v0 = float(val)
			var qm := _resolve_module("quantum_wavepacket_module")
			if qm and qm.has_method("set_barrier_height"):
				qm.set_barrier_height(float(val))
		"quantum_k0", "wavepacket_k0":
			var qm := _resolve_module("quantum_wavepacket_module")
			if qm:
				qm.set("packet_wavenumber_k0", float(val))
				if qm.has_method("initialize_gaussian_wavepacket"):
					qm.initialize_gaussian_wavepacket(qm.get("packet_center_x"), qm.get("packet_width"), float(val))
		"quantum_barrier_type", "potential_type":
			var p_type_int: int = 1
			if val is String:
				match str(val):
					"free": p_type_int = 0
					"barrier": p_type_int = 1
					"harmonic": p_type_int = 2
					"double_slit": p_type_int = 4
					_: p_type_int = 1
			else:
				p_type_int = int(val)
			quantum_barrier_type = p_type_int
			var qm := _resolve_module("quantum_wavepacket_module")
			if qm and qm.has_method("set_potential_type"):
				qm.set_potential_type(p_type_int)

	parameter_modified.emit(mod_id, param, val)

func _on_physics_load_preset(payload: Dictionary) -> void:
	var preset_id: String = str(payload.get("preset_id", "")).to_lower()
	match preset_id:
		"solar_system", "solar":
			switch_domain("gravity")
			var grav := _resolve_module("n_body_gravity_module")
			if grav and grav.has_method("preset_solar_system"):
				grav.preset_solar_system()
		"figure8", "figure_8":
			switch_domain("gravity")
			var grav := _resolve_module("n_body_gravity_module")
			if grav and grav.has_method("preset_figure8_choreography"):
				grav.preset_figure8_choreography()
		"cluster", "star_cluster":
			switch_domain("gravity")
			var grav := _resolve_module("n_body_gravity_module")
			if grav and grav.has_method("preset_massive_cluster"):
				grav.preset_massive_cluster(300)
		"kepler", "kepler_2body":
			switch_domain("gravity")
			var grav := _resolve_module("n_body_gravity_module")
			if grav and grav.has_method("preset_kepler_2body"):
				grav.preset_kepler_2body()
		"gas_box", "thermodynamics":
			switch_domain("thermodynamics")
			var md := _resolve_module("molecular_dynamics_module")
			if md and md.has_method("reset_simulation"):
				md.reset_simulation()
		"nuclear_reactor", "nuclear":
			switch_domain("nuclear")
			var nuc := _resolve_module("nuclear_decay_module")
			if nuc and nuc.has_method("setup_reactor_core"):
				nuc.setup_reactor_core(120, 2.5)
		"quantum_tunneling", "quantum":
			switch_domain("quantum")
			var qm := _resolve_module("quantum_wavepacket_module")
			if qm:
				if qm.has_method("set_potential_type"):
					qm.set_potential_type(1)
				if qm.has_method("initialize_gaussian_wavepacket"):
					qm.initialize_gaussian_wavepacket(-10.0, 3.5, 1.2)
		"double_slit":
			switch_domain("quantum")
			var qm := _resolve_module("quantum_wavepacket_module")
			if qm:
				if qm.has_method("set_dimension"):
					qm.set_dimension(2)
				if qm.has_method("set_potential_type"):
					qm.set_potential_type(4)
				if qm.has_method("initialize_2d_gaussian"):
					qm.initialize_2d_gaussian(-4.0, 0.0, 0.8, 3.0, 0.0)

func _on_physics_spawn_entity(payload: Dictionary) -> void:
	var mod_id: String = str(payload.get("module_id", ""))
	var entity: Dictionary = payload.get("entity", {})
	match mod_id:
		"n_body_gravity_module", "gravity":
			var pos: Vector3 = entity.get("position", Vector3.ZERO)
			var vel: Vector3 = entity.get("velocity", Vector3.ZERO)
			var mass: float = float(entity.get("mass", gravity_spawn_mass))
			var b_type: String = str(entity.get("body_type", gravity_body_type))
			var grav := _resolve_module("n_body_gravity_module")
			if grav and grav.has_method("spawn_body"):
				grav.spawn_body(pos, vel, mass, b_type)
			else:
				gravity_spawn_mass = mass
				gravity_body_type = b_type
				_spawn_celestial_body(pos, vel)
		"molecular_dynamics_module", "thermodynamics":
			var pos: Vector3 = entity.get("position", Vector3.ZERO)
			var vel: Vector3 = entity.get("initial_velocity", Vector3(0, 5, 0))
			var count: int = int(entity.get("count", thermo_inject_count))
			var temp: float = float(entity.get("temperature", thermo_inject_temp))
			var md := _resolve_module("molecular_dynamics_module")
			if md and md.has_method("inject_particles"):
				md.inject_particles(pos, count, temp, vel)
		"nuclear_decay_module", "nuclear":
			var pos: Vector3 = entity.get("position", Vector3.ZERO)
			var vel: Vector3 = entity.get("velocity", Vector3.ZERO)
			_spawn_nuclear_sample(pos, vel)
		"quantum_wavepacket_module", "quantum":
			var pos: Vector3 = entity.get("position", Vector3.ZERO)
			var vel: Vector3 = entity.get("impulse", Vector3(3, 0, 0))
			_spawn_quantum_wavepacket(pos, vel)

func _on_physics_entity_action(payload: Dictionary) -> void:
	var action: String = str(payload.get("action", ""))
	var entity_id: String = str(payload.get("entity_id", ""))
	match action:
		"delete":
			var grav := _resolve_module("n_body_gravity_module")
			if grav and grav.has_method("remove_body_by_name"):
				grav.remove_body_by_name(entity_id)
		"reset":
			var grav := _resolve_module("n_body_gravity_module")
			if grav and grav.has_method("preset_solar_system"):
				grav.preset_solar_system()
