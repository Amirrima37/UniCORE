class_name ScientificProbeTool
extends UniCoreModule

## Инструмент Метрологии: Научные Измерительные Зонды (Scientific Probe Tool)
## Позволяет исследователю развертывать 3D-датчики в вакууме для измерения
## гравитационного поля g, локальной температуры/давления газа, радиационного потока CPS
## и квантовой плотности вероятности |psi|^2.

signal probe_spawned(probe_id: int, pos: Vector3)
signal probe_removed(probe_id: int)
signal probes_cleared()
signal telemetry_sampled(probe_id: int, data: Dictionary)

@export var sample_interval: float = 0.1
@export var sample_radius: float = 2.5
@export var max_probes: int = 16

var _probes: Dictionary = {} # probe_id (int) -> Dictionary: {"node": Node3D, "position": Vector3}
var _next_probe_id: int = 1
var _sample_timer: float = 0.0

var _gravity_module: Node = null
var _md_module: Node = null
var _nuclear_module: Node = null
var _quantum_module: Node = null
var _event_bus: Node = null

func get_module_id() -> String:
	return "scientific_probe_tool"

func get_module_name() -> String:
	return "Метрология: Научные Измерительные Зонды"

func get_action_bindings() -> Array[Dictionary]:
	return [
		{"action": "spawn_probe", "label": "Разместить зонд", "default_key": KEY_P, "description": "Размещение измерительного зонда в фокусе"},
		{"action": "clear_probes", "label": "Очистить все зонды", "default_key": KEY_C, "description": "Удаление всех развернутых сенсоров"}
	]

func initialize(context: Dictionary) -> bool:
	super.initialize(context)
	
	if core_context.has("event_bus") and core_context["event_bus"]:
		_event_bus = core_context["event_bus"]
		_event_bus.subscribe("physics_entity_spawned", _on_entity_spawned)
	
	_resolve_physics_modules()
	return true

func _resolve_physics_modules() -> void:
	var mm: Node = core_context.get("module_manager") as Node if core_context.has("module_manager") else null
	if mm and mm.has_method("get_module"):
		if not _gravity_module:
			_gravity_module = mm.get_module("n_body_gravity_module")
		if not _md_module:
			_md_module = mm.get_module("molecular_dynamics_module")
		if not _nuclear_module:
			_nuclear_module = mm.get_module("nuclear_decay_module")
		if not _quantum_module:
			_quantum_module = mm.get_module("quantum_wavepacket_module")

	var root: Node = get_tree().root if get_tree() else null
	if not root:
		return
	
	if not _gravity_module:
		_gravity_module = root.find_child("n_body_gravity_module", true, false)
		if not _gravity_module:
			_gravity_module = root.find_child("NBodyGravityModule", true, false)
	if not _md_module:
		_md_module = root.find_child("molecular_dynamics_module", true, false)
		if not _md_module:
			_md_module = root.find_child("MolecularDynamicsModule", true, false)
	if not _nuclear_module:
		_nuclear_module = root.find_child("nuclear_decay_module", true, false)
		if not _nuclear_module:
			_nuclear_module = root.find_child("NuclearDecayModule", true, false)
	if not _quantum_module:
		_quantum_module = root.find_child("quantum_wavepacket_module", true, false)
		if not _quantum_module:
			_quantum_module = root.find_child("QuantumWavePacketModule", true, false)

func deploy_probe(position: Vector3) -> int:
	if _probes.size() >= max_probes:
		# Remove oldest probe
		var oldest_id: int = _probes.keys()[0]
		remove_probe(oldest_id)
	
	var probe_id: int = _next_probe_id
	_next_probe_id += 1
	
	# Create 3D Visual Sensor Node
	var probe_node: Node3D = Node3D.new()
	probe_node.name = "Probe_%d" % probe_id
	probe_node.position = position
	
	var mesh_inst: MeshInstance3D = MeshInstance3D.new()
	var sphere: SphereMesh = SphereMesh.new()
	sphere.radius = 0.20
	sphere.height = 0.40
	sphere.radial_segments = 12
	sphere.rings = 6
	mesh_inst.mesh = sphere
	
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = Color(0.1, 0.85, 1.0, 0.9)
	mat.emission_enabled = true
	mat.emission = Color(0.15, 0.70, 0.95)
	mat.emission_energy_multiplier = 2.0
	mesh_inst.material_override = mat
	probe_node.add_child(mesh_inst)
	
	add_child(probe_node)
	
	_probes[probe_id] = {
		"node": probe_node,
		"position": position
	}
	
	probe_spawned.emit(probe_id, position)
	if _event_bus:
		_event_bus.publish("scientific_probe_deployed", {
			"probe_id": probe_id,
			"position": position
		})
	
	return probe_id

func remove_probe(probe_id: int) -> void:
	if not _probes.has(probe_id):
		return
	
	var data: Dictionary = _probes[probe_id]
	var node: Node3D = data.get("node") as Node3D
	if node and is_instance_valid(node):
		node.queue_free()
	
	_probes.erase(probe_id)
	probe_removed.emit(probe_id)
	if _event_bus:
		_event_bus.publish("scientific_probe_removed", {"probe_id": probe_id})

func clear_all_probes() -> void:
	for probe_id in _probes.keys():
		var data: Dictionary = _probes[probe_id]
		var node: Node3D = data.get("node") as Node3D
		if node and is_instance_valid(node):
			node.queue_free()
	
	_probes.clear()
	probes_cleared.emit()
	if _event_bus:
		_event_bus.publish("scientific_probes_cleared", {})

func _process(delta: float) -> void:
	if not is_initialized or _probes.is_empty():
		return
	
	_sample_timer += delta
	if _sample_timer >= sample_interval:
		_sample_timer = 0.0
		_sample_all_probes()

func _sample_all_probes() -> void:
	_resolve_physics_modules()
	
	for probe_id in _probes:
		var info: Dictionary = _probes[probe_id]
		var pos: Vector3 = info.get("position", Vector3.ZERO)
		var telemetry: Dictionary = sample_at_point(pos)
		telemetry["probe_id"] = probe_id
		telemetry["position"] = pos
		
		telemetry_sampled.emit(probe_id, telemetry)
		if _event_bus:
			_event_bus.publish("physics_probe_telemetry", telemetry)

func sample_at_point(point: Vector3) -> Dictionary:
	var result: Dictionary = {
		"gravity_vector": Vector3.ZERO,
		"gravity_magnitude": 0.0,
		"gas_density": 0.0,
		"gas_temperature": 0.0,
		"gas_pressure": 0.0,
		"radiation_cps": 0,
		"quantum_probability_density": 0.0
	}
	
	# 1. Gravitational Field Sampling
	if _gravity_module and is_instance_valid(_gravity_module):
		var g_acc: Vector3 = _compute_gravity_at(point)
		result["gravity_vector"] = g_acc
		result["gravity_magnitude"] = g_acc.length()
	
	# 2. Molecular Dynamics (Gas Density & Temp)
	if _md_module and is_instance_valid(_md_module):
		_sample_gas_at(point, result)
	
	# 3. Nuclear Radiation (CPS)
	if _nuclear_module and is_instance_valid(_nuclear_module):
		_sample_radiation_at(point, result)
	
	# 4. Quantum Wavepacket Density
	if _quantum_module and is_instance_valid(_quantum_module):
		_sample_quantum_at(point, result)
	
	return result

func _compute_gravity_at(point: Vector3) -> Vector3:
	var total_g: Vector3 = Vector3.ZERO
	if _gravity_module.get("is_simulation_enabled") == false:
		return total_g
	
	var positions: PackedVector3Array
	if _gravity_module.has_method("get_positions"):
		positions = _gravity_module.get_positions()
	elif _gravity_module.get("_positions") != null:
		positions = _gravity_module.get("_positions")
	elif _gravity_module.get("positions") != null:
		positions = _gravity_module.get("positions")
	
	var masses: PackedFloat32Array
	if _gravity_module.has_method("get_masses"):
		masses = _gravity_module.get_masses()
	elif _gravity_module.get("_masses") != null:
		masses = _gravity_module.get("_masses")
	elif _gravity_module.get("masses") != null:
		masses = _gravity_module.get("masses")
	
	var g_const: float = float(_gravity_module.get("gravitational_constant"))
	if g_const <= 0.0:
		g_const = 1.0
	var eps_sq: float = float(_gravity_module.get("softening"))
	eps_sq = eps_sq * eps_sq if eps_sq > 0.0 else 0.0025
	
	var n: int = min(positions.size(), masses.size())
	for i in range(n):
		var delta_r: Vector3 = positions[i] - point
		var dist_sq: float = delta_r.length_squared() + eps_sq
		var inv_dist: float = 1.0 / sqrt(dist_sq)
		var inv_dist3: float = inv_dist * inv_dist * inv_dist
		total_g += delta_r * (g_const * masses[i] * inv_dist3)
	
	return total_g

func _sample_gas_at(point: Vector3, out_result: Dictionary) -> void:
	var positions: PackedVector3Array
	if _md_module.has_method("get_positions"):
		positions = _md_module.get_positions()
	elif _md_module.get("_positions") != null:
		positions = _md_module.get("_positions")
	elif _md_module.get("positions") != null:
		positions = _md_module.get("positions")
	
	var velocities: PackedVector3Array
	if _md_module.has_method("get_velocities"):
		velocities = _md_module.get_velocities()
	elif _md_module.get("_velocities") != null:
		velocities = _md_module.get("_velocities")
	elif _md_module.get("velocities") != null:
		velocities = _md_module.get("velocities")
	
	var n: int = min(positions.size(), velocities.size())
	var r_sq: float = sample_radius * sample_radius
	
	var count: int = 0
	var sum_v_sq: float = 0.0
	for i in range(n):
		if (positions[i] - point).length_squared() <= r_sq:
			count += 1
			sum_v_sq += velocities[i].length_squared()
	
	var vol: float = (4.0 / 3.0) * PI * (sample_radius * sample_radius * sample_radius)
	var density: float = float(count) / vol
	var temp: float = (sum_v_sq / float(count * 3)) if count > 0 else 0.0
	var pressure: float = density * temp # Ideal gas approximation P = rho * T
	
	out_result["gas_density"] = density
	out_result["gas_temperature"] = temp
	out_result["gas_pressure"] = pressure

func _sample_radiation_at(point: Vector3, out_result: Dictionary) -> void:
	var rad_pos: PackedVector3Array = _nuclear_module.get("rad_positions")
	var rad_active: PackedByteArray = _nuclear_module.get("rad_active")
	var n: int = rad_pos.size()
	var r_sq: float = (sample_radius * 1.5) * (sample_radius * 1.5)
	
	var counts: int = 0
	for i in range(n):
		if rad_active.size() > i and rad_active[i] == 0:
			continue
		if (rad_pos[i] - point).length_squared() <= r_sq:
			counts += 1
	
	out_result["radiation_cps"] = int(float(counts) / sample_interval)

func _sample_quantum_at(point: Vector3, out_result: Dictionary) -> void:
	var dim: int = int(_quantum_module.get("active_dimension"))
	var density: float = 0.0
	
	if dim == 1:
		var prob_1d: PackedFloat32Array = _quantum_module.get("prob_density_1d")
		var n: int = prob_1d.size()
		var length_1d: float = float(_quantum_module.get("domain_length_1d"))
		if n > 1 and length_1d > 0.0:
			var idx: int = int(roundf(((point.x + length_1d * 0.5) / length_1d) * float(n - 1)))
			if idx >= 0 and idx < n:
				density = prob_1d[idx]
	else:
		var prob_2d: PackedFloat32Array = _quantum_module.get("prob_density_2d")
		var nx: int = int(_quantum_module.get("grid_size_2d_x"))
		var nz: int = int(_quantum_module.get("grid_size_2d_z"))
		var dom_size: Vector2 = _quantum_module.get("domain_size_2d")
		if nx > 1 and nz > 1 and dom_size.x > 0.0 and dom_size.y > 0.0:
			var ix: int = int(roundf(((point.x + dom_size.x * 0.5) / dom_size.x) * float(nx - 1)))
			var iz: int = int(roundf(((point.z + dom_size.y * 0.5) / dom_size.y) * float(nz - 1)))
			if ix >= 0 and ix < nx and iz >= 0 and iz < nz:
				density = prob_2d[iz * nx + ix]
	
	out_result["quantum_probability_density"] = density

func _unhandled_input(event: InputEvent) -> void:
	if not is_initialized:
		return
	
	if event.is_action_pressed("spawn_probe"):
		deploy_probe(Vector3.ZERO)
	elif event.is_action_pressed("clear_probes"):
		clear_all_probes()

func _on_entity_spawned(payload: Dictionary) -> void:
	var mod_id: String = str(payload.get("module_id", ""))
	if mod_id != "scientific_probe_module" and mod_id != "scientific_probe_tool":
		return
	
	var entity: Dictionary = payload.get("entity", {})
	var pos: Vector3 = entity.get("position", Vector3.ZERO)
	deploy_probe(pos)

func cleanup() -> void:
	clear_all_probes()
	_gravity_module = null
	_md_module = null
	_nuclear_module = null
	_quantum_module = null
	_event_bus = null
	super.cleanup()
