class_name MolecularDynamicsModule
extends UniCoreModule

## Molecular Dynamics Simulation Module for UniCORE.
## Implements Lennard-Jones 12-6 pairwise interactions, SpatialHashGrid acceleration,
## Velocity-Verlet symplectic integration, Berendsen thermostat, reflective cubic boundaries,
## Maxwell-Boltzmann distribution, and single MultiMeshInstance3D GPU rendering.

const SpatialHashGrid = preload("res://core/physics/spatial_hash_grid.gd")
const VerletIntegrator = preload("res://core/physics/verlet_integrator.gd")
const ConservationSentry = preload("res://core/physics/conservation_sentry.gd")
const SimulationTimeController = preload("res://core/physics/simulation_time_controller.gd")

# --- Signals ---
signal md_telemetry_updated(snapshot: Dictionary)
signal target_temperature_changed(new_temp: float)
signal container_resized(new_half_extent: Vector3)

# --- Physical Constants & Parameters ---
@export_group("Lennard-Jones Parameters")
@export var particle_count: int = 500
@export var sigma: float = 1.0:
	set(val):
		sigma = val
		_update_lj_constants()
@export var epsilon: float = 1.0:
	set(val):
		epsilon = val
		_update_lj_constants()
@export var particle_mass: float = 1.0
@export var particle_radius: float = 0.2
@export var cutoff_radius: float = 2.5:
	set(val):
		cutoff_radius = val
		_update_lj_constants()

@export_group("Thermodynamics & Boundaries")
@export var box_half_extent: Vector3 = Vector3(10.0, 10.0, 10.0)
@export var restitution: float = 1.0
@export var target_temperature: float = 1.0
@export var thermostat_tau: float = 0.2
@export var thermostat_enabled: bool = true
@export var boltzmann_constant: float = 1.0

@export_group("Engine Integration")
@export var audit_frequency: int = 1
@export var speed_scale_visual: float = 3.0

# --- State Buffers (Contiguous Packed Arrays) ---
var _positions: PackedVector3Array = PackedVector3Array()
var _velocities: PackedVector3Array = PackedVector3Array()
var _masses: PackedFloat32Array = PackedFloat32Array()
var _forces: PackedVector3Array = PackedVector3Array()

# --- Precalculated Lennard-Jones Constants ---
var _sigma_sq: float = 1.0
var _cutoff_sq: float = 6.25
var _potential_shift: float = 0.0 # V(r_c)

# --- Subsystem References ---
var _spatial_grid: SpatialHashGrid = null
var _integrator: VerletIntegrator = null
var _sentry: ConservationSentry = null
var _time_controller: SimulationTimeController = null
var _event_bus: Node = null

# --- Visual Nodes ---
var _multimesh_instance: MultiMeshInstance3D = null
var _multimesh: MultiMesh = null
var _container_mesh_instance: MeshInstance3D = null
var _particle_shader_material: ShaderMaterial = null
var is_simulation_active: bool = false

func set_simulation_active(val: bool) -> void:
	is_simulation_active = val
	if _multimesh_instance and is_instance_valid(_multimesh_instance):
		_multimesh_instance.visible = val
	if _container_mesh_instance and is_instance_valid(_container_mesh_instance):
		_container_mesh_instance.visible = val

# --- Internal Bookkeeping ---
var _step_counter: int = 0
var _force_callable: Callable = Callable()
var _potential_callable: Callable = Callable()

# ==============================================================================
# 1. UniCoreModule Contract
# ==============================================================================

func _init() -> void:
	_update_lj_constants()

func get_module_id() -> String:
	return "molecular_dynamics"

func get_module_name() -> String:
	return "Молекулярная динамика (Lennard-Jones)"

func get_action_bindings() -> Array[Dictionary]:
	return [
		{
			"action": "md_heat_up",
			"label": "MD: Нагреть газ (+Temp)",
			"default_key": KEY_UP,
			"description": "Повысить целевую температуру термостата Берендсена"
		},
		{
			"action": "md_cool_down",
			"label": "MD: Охладить газ (-Temp)",
			"default_key": KEY_DOWN,
			"description": "Понизить целевую температуру термостата Берендсена"
		},
		{
			"action": "md_compress_box",
			"label": "MD: Сжать контейнер",
			"default_key": KEY_P,
			"description": "Уменьшить объем контейнера (повышение плотности и давления)"
		}
	]

func initialize(context: Dictionary) -> bool:
	super.initialize(context)
	
	# Cache precomputed potential shift and squared cutoffs
	_update_lj_constants()
	
	# 1. Initialize Subsystems
	if _spatial_grid == null:
		_spatial_grid = SpatialHashGrid.new()
	_spatial_grid.initialize(cutoff_radius, particle_count * 2)
	
	if _integrator == null:
		_integrator = VerletIntegrator.new()
	_force_callable = Callable(self, "compute_forces")
	_potential_callable = Callable(self, "compute_potential_energy")
	
	# 2. Extract or Instantiate ConservationSentry
	if context.has("conservation_sentry") and context["conservation_sentry"] is ConservationSentry:
		_sentry = context["conservation_sentry"] as ConservationSentry
	elif context.has("sentry") and context["sentry"] is ConservationSentry:
		_sentry = context["sentry"] as ConservationSentry
	elif get_tree() and get_tree().root.find_child("ConservationSentry", true, false):
		_sentry = get_tree().root.find_child("ConservationSentry", true, false) as ConservationSentry
	else:
		_sentry = ConservationSentry.new()
		_sentry.name = "MD_ConservationSentry"
		_sentry.boltzmann_constant = boltzmann_constant
		add_child(_sentry)
	
	# 3. Extract or Connect SimulationTimeController
	if context.has("time_controller") and context["time_controller"] is SimulationTimeController:
		_time_controller = context["time_controller"] as SimulationTimeController
		_time_controller.sim_tick.connect(_on_sim_tick)
	elif get_tree() and get_tree().root.find_child("SimulationTimeController", true, false):
		_time_controller = get_tree().root.find_child("SimulationTimeController", true, false) as SimulationTimeController
		_time_controller.sim_tick.connect(_on_sim_tick)
	
	# 4. Extract EventBus
	if context.has("event_bus") and context["event_bus"] is Node:
		_event_bus = context["event_bus"] as Node
	elif get_tree() and get_tree().root.find_child("EventBus", true, false):
		_event_bus = get_tree().root.find_child("EventBus", true, false) as Node
	
	# 5. Build GPU MultiMesh Rendering Pipeline
	_setup_multimesh_renderer()
	
	# 6. Build Boundary Visualizer
	_setup_container_visual()
	
	# 7. Reset & Initialize Physical Particle Ensemble
	reset_simulation()
	set_simulation_active(false)
	
	return true

func cleanup() -> void:
	if _time_controller and is_instance_valid(_time_controller):
		var callable := Callable(self, "_on_sim_tick")
		if _time_controller.sim_tick.is_connected(callable):
			_time_controller.sim_tick.disconnect(callable)
	
	if _multimesh_instance and is_instance_valid(_multimesh_instance):
		_multimesh_instance.queue_free()
		_multimesh_instance = null
	
	if _container_mesh_instance and is_instance_valid(_container_mesh_instance):
		_container_mesh_instance.queue_free()
		_container_mesh_instance = null
	
	if _integrator:
		_integrator.clear_buffers()
	
	if _spatial_grid:
		_spatial_grid.clear()
	
	_positions.clear()
	_velocities.clear()
	_masses.clear()
	_forces.clear()
	
	super.cleanup()

# ==============================================================================
# 2. Simulation Lifecycle & Particle Initialization
# ==============================================================================

func _update_lj_constants() -> void:
	_sigma_sq = sigma * sigma
	_cutoff_sq = cutoff_radius * cutoff_radius
	
	# Compute shift V(r_c) = 4*epsilon * ((sigma/r_c)^12 - (sigma/r_c)^6)
	var sr2: float = _sigma_sq / _cutoff_sq
	var sr6: float = sr2 * sr2 * sr2
	var sr12: float = sr6 * sr6
	_potential_shift = 4.0 * epsilon * (sr12 - sr6)

func reset_simulation() -> void:
	if particle_count <= 0:
		return
	
	_update_lj_constants()
	
	if _spatial_grid == null:
		_spatial_grid = SpatialHashGrid.new()
		_spatial_grid.initialize(cutoff_radius, particle_count * 2)
	
	if _integrator == null:
		_integrator = VerletIntegrator.new()
	if not _force_callable.is_valid():
		_force_callable = Callable(self, "compute_forces")
	if not _potential_callable.is_valid():
		_potential_callable = Callable(self, "compute_potential_energy")
	
	# Allocate packed particle buffers
	_positions.resize(particle_count)
	_velocities.resize(particle_count)
	_masses.resize(particle_count)
	_forces.resize(particle_count)
	
	for i in range(particle_count):
		_masses[i] = particle_mass
		_forces[i] = Vector3.ZERO
	
	# 1. Place particles on uniform lattice to guarantee overlap-free initial state
	_initialize_lattice_positions()
	
	# 2. Sample velocities from Maxwell-Boltzmann distribution
	_initialize_maxwell_boltzmann_velocities()
	
	# 3. Synchronize MultiMesh instance count and initial transforms
	if _multimesh:
		_multimesh.instance_count = particle_count
		update_multimesh_visuals()
	
	# 4. Register initial physical state with ConservationSentry
	if _sentry:
		_sentry.reset()
		var initial_ek: float = 0.0
		var total_p := Vector3.ZERO
		var total_l := Vector3.ZERO
		for i in range(particle_count):
			var m: float = _masses[i]
			var v: Vector3 = _velocities[i]
			var r: Vector3 = _positions[i]
			initial_ek += 0.5 * m * v.length_squared()
			total_p += v * m
			total_l += r.cross(v * m)
		var initial_ep: float = compute_potential_energy(_positions)
		_sentry.register_system(initial_ek + initial_ep, total_p, total_l)

func _initialize_lattice_positions() -> void:
	var n: int = particle_count
	var side: int = int(ceil(pow(float(n), 1.0 / 3.0)))
	var spacing: float = 1.25 * sigma
	var half_span: float = float(side - 1) * spacing * 0.5
	
	var idx: int = 0
	for ix in range(side):
		for iy in range(side):
			for iz in range(side):
				if idx >= n:
					break
				var pos := Vector3(
					float(ix) * spacing - half_span,
					float(iy) * spacing - half_span,
					float(iz) * spacing - half_span
				)
				# Tiny jitter to break symmetry without causing overlaps
				var jitter := Vector3(
					randf_range(-0.02, 0.02),
					randf_range(-0.02, 0.02),
					randf_range(-0.02, 0.02)
				) * sigma
				_positions[idx] = pos + jitter
				idx += 1
			if idx >= n:
				break
		if idx >= n:
			break

func _initialize_maxwell_boltzmann_velocities() -> void:
	var n: int = particle_count
	var kb: float = boltzmann_constant if boltzmann_constant > 0.0 else 1.0
	var sigma_v: float = sqrt(kb * target_temperature / maxf(particle_mass, 1e-9))
	var total_p := Vector3.ZERO
	
	# Box-Muller Gaussian sampling for independent Cartesian components
	for i in range(n):
		var u1: float = maxf(randf(), 1e-12)
		var u2: float = randf()
		var u3: float = maxf(randf(), 1e-12)
		var u4: float = randf()
		
		var r1: float = sqrt(-2.0 * log(u1))
		var theta1: float = 2.0 * PI * u2
		var z0: float = r1 * cos(theta1)
		var z1: float = r1 * sin(theta1)
		
		var r2: float = sqrt(-2.0 * log(u3))
		var theta2: float = 2.0 * PI * u4
		var z2: float = r2 * cos(theta2)
		
		var v := Vector3(z0 * sigma_v, z1 * sigma_v, z2 * sigma_v)
		_velocities[i] = v
		total_p += v * particle_mass
	
	# Eliminate center-of-mass momentum drift
	var v_cm: Vector3 = total_p / (float(n) * particle_mass)
	for i in range(n):
		_velocities[i] = _velocities[i] - v_cm
	
	# Rescale to match exact target temperature
	var current_t: float = compute_instantaneous_temperature()
	if current_t > 1e-9:
		var scale: float = sqrt(target_temperature / current_t)
		for i in range(n):
			_velocities[i] = _velocities[i] * scale

func reset_to_maxwell_boltzmann() -> void:
	if _positions.is_empty():
		return
	_initialize_maxwell_boltzmann_velocities()

func inject_particles(pos: Vector3, count: int, temp: float, stream_vel: Vector3 = Vector3.ZERO) -> void:
	if count <= 0:
		return
	
	var kb: float = boltzmann_constant if boltzmann_constant > 0.0 else 1.0
	var effective_temp: float = maxf(temp, 0.01)
	var sigma_v: float = sqrt(kb * effective_temp / maxf(particle_mass, 1e-9))
	
	var cluster_radius: float = clampf(pow(float(count), 1.0 / 3.0) * sigma * 0.8, 0.5, box_half_extent.x * 0.5)
	
	for i in range(count):
		# Random position within cluster sphere, clamped inside container
		var u := randf()
		var theta := randf() * TAU
		var phi := acos(randf_range(-1.0, 1.0))
		var r := pow(u, 1.0 / 3.0) * cluster_radius
		var offset := Vector3(
			r * sin(phi) * cos(theta),
			r * sin(phi) * sin(theta),
			r * cos(phi)
		)
		var p: Vector3 = pos + offset
		p.x = clampf(p.x, -box_half_extent.x + particle_radius, box_half_extent.x - particle_radius)
		p.y = clampf(p.y, -box_half_extent.y + particle_radius, box_half_extent.y - particle_radius)
		p.z = clampf(p.z, -box_half_extent.z + particle_radius, box_half_extent.z - particle_radius)
		
		# Box-Muller velocity sampling
		var u1: float = maxf(randf(), 1e-12)
		var u2: float = randf()
		var u3: float = maxf(randf(), 1e-12)
		var u4: float = randf()
		var r1: float = sqrt(-2.0 * log(u1))
		var th1: float = 2.0 * PI * u2
		var r2_bm: float = sqrt(-2.0 * log(u3))
		var th2: float = 2.0 * PI * u4
		var v := Vector3(r1 * cos(th1) * sigma_v, r1 * sin(th1) * sigma_v, r2_bm * cos(th2) * sigma_v) + stream_vel
		
		_positions.append(p)
		_velocities.append(v)
		_masses.append(particle_mass)
		_forces.append(Vector3.ZERO)
	
	particle_count = _positions.size()
	
	if _spatial_grid:
		_spatial_grid.initialize(cutoff_radius, particle_count * 2)
	
	if _multimesh:
		_multimesh.instance_count = particle_count
		update_multimesh_visuals()


## Allows explicit configuration of particles for deterministic unit tests.
func set_particle_state(
	p_positions: PackedVector3Array,
	p_velocities: PackedVector3Array,
	p_masses: PackedFloat32Array = PackedFloat32Array()
) -> void:
	var n: int = p_positions.size()
	if n == 0 or p_velocities.size() != n:
		return
	
	particle_count = n
	_positions = p_positions.duplicate()
	_velocities = p_velocities.duplicate()
	
	if p_masses.size() == n:
		_masses = p_masses.duplicate()
	else:
		_masses.resize(n)
		for i in range(n):
			_masses[i] = particle_mass
	
	_forces.resize(n)
	for i in range(n):
		_forces[i] = Vector3.ZERO
	
	_update_lj_constants()
	
	if _spatial_grid == null:
		_spatial_grid = SpatialHashGrid.new()
	_spatial_grid.initialize(cutoff_radius, particle_count * 2)
	
	if _integrator == null:
		_integrator = VerletIntegrator.new()
	if not _force_callable.is_valid():
		_force_callable = Callable(self, "compute_forces")
	if not _potential_callable.is_valid():
		_potential_callable = Callable(self, "compute_potential_energy")
	
	if _multimesh:
		_multimesh.instance_count = particle_count
		update_multimesh_visuals()
	
	if _sentry:
		_sentry.reset()
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
		var initial_ep: float = compute_potential_energy(_positions)
		_sentry.register_system(initial_ek + initial_ep, total_p, total_l)

func get_positions() -> PackedVector3Array:
	return _positions

func get_velocities() -> PackedVector3Array:
	return _velocities

func get_masses() -> PackedFloat32Array:
	return _masses

func get_forces() -> PackedVector3Array:
	return _forces

func get_particle_count() -> int:
	return _positions.size()


# ==============================================================================
# 3. Physics Integration & Core Step

# ==============================================================================

func _on_sim_tick(dt: float, _sim_time: float) -> void:
	if not is_simulation_active:
		return
	step(dt)

func step(dt: float) -> void:
	if _positions.is_empty() or dt <= 0.0:
		return
	
	if _integrator == null:
		_integrator = VerletIntegrator.new()
	if not _force_callable.is_valid():
		_force_callable = Callable(self, "compute_forces")
	if not _potential_callable.is_valid():
		_potential_callable = Callable(self, "compute_potential_energy")
	
	# 1. Symplectic Velocity-Verlet Integration
	_integrator.integrate(_positions, _velocities, _masses, _force_callable, dt)
	
	# 2. Reflective Cubic Container Boundaries
	enforce_boundaries()
	
	# 3. Berendsen Thermostat (NVT regulation)
	if thermostat_enabled:
		apply_berendsen_thermostat(dt)
	
	# 4. Update GPU MultiMesh Transforms and Glow Colors
	update_multimesh_visuals()
	
	# 5. Invariant Auditing via ConservationSentry
	_step_counter += 1
	if _sentry and (_step_counter % audit_frequency == 0):
		var snapshot: Dictionary = _sentry.audit(
			_positions,
			_velocities,
			_masses,
			_potential_callable
		)
		if not snapshot.is_empty():
			md_telemetry_updated.emit(snapshot)
			if _event_bus:
				_event_bus.emit("md_telemetry_updated", snapshot)

# ==============================================================================
# 4. Force & Potential Calculations (Lennard-Jones + Spatial Hash)
# ==============================================================================

func compute_forces(pos: PackedVector3Array) -> PackedVector3Array:
	var n: int = pos.size()
	if n == 0:
		return PackedVector3Array()
	
	if _forces.size() != n:
		_forces.resize(n)
	for i in range(n):
		_forces[i] = Vector3.ZERO
	
	if _spatial_grid == null or _spatial_grid.cell_size != cutoff_radius:
		_spatial_grid = SpatialHashGrid.new()
		_spatial_grid.initialize(cutoff_radius, n * 2)
	
	# Build 3D spatial hash grid in O(N)
	_spatial_grid.build_grid(pos)
	
	var eps24: float = 24.0 * epsilon
	var sig2: float = _sigma_sq
	var rc_sq: float = _cutoff_sq
	var min_r_sq: float = 0.04 * sig2 # Overlap clamp
	
	# Half-shell pairwise loop: Newton's Third Law (F_ji = -F_ij)
	for i in range(n):
		var pos_i: Vector3 = pos[i]
		var neighbors: PackedInt32Array = _spatial_grid.get_neighbors(pos_i, cutoff_radius)
		var n_neighbors: int = neighbors.size()
		
		for k in range(n_neighbors):
			var j: int = neighbors[k]
			if j > i: # Pair visited exactly once
				var r_vec: Vector3 = pos_i - pos[j]
				var r_sq: float = r_vec.length_squared()
				
				if r_sq < rc_sq:
					r_sq = maxf(r_sq, min_r_sq)
					var inv_r2: float = 1.0 / r_sq
					var sr2: float = sig2 * inv_r2
					var sr6: float = sr2 * sr2 * sr2
					var sr12: float = sr6 * sr6
					
					var factor: float = eps24 * inv_r2 * (2.0 * sr12 - sr6)
					var f_ij: Vector3 = r_vec * factor
					
					_forces[i] += f_ij
					_forces[j] -= f_ij
	
	return _forces

## Brute-force O(N^2) force computation for algorithmic parity and benchmark testing.
func compute_forces_brute_force(pos: PackedVector3Array) -> PackedVector3Array:
	var n: int = pos.size()
	var forces: PackedVector3Array = PackedVector3Array()
	if n == 0:
		return forces
	forces.resize(n)
	for i in range(n):
		forces[i] = Vector3.ZERO
	
	var eps24: float = 24.0 * epsilon
	var sig2: float = _sigma_sq
	var rc_sq: float = _cutoff_sq
	var min_r_sq: float = 0.04 * sig2
	
	for i in range(n):
		var pos_i: Vector3 = pos[i]
		for j in range(i + 1, n):
			var r_vec: Vector3 = pos_i - pos[j]
			var r_sq: float = r_vec.length_squared()
			if r_sq < rc_sq:
				r_sq = maxf(r_sq, min_r_sq)
				var inv_r2: float = 1.0 / r_sq
				var sr2: float = sig2 * inv_r2
				var sr6: float = sr2 * sr2 * sr2
				var sr12: float = sr6 * sr6
				var factor: float = eps24 * inv_r2 * (2.0 * sr12 - sr6)
				var f_ij: Vector3 = r_vec * factor
				forces[i] += f_ij
				forces[j] -= f_ij
	return forces

func compute_potential_energy(pos: PackedVector3Array) -> float:
	var n: int = pos.size()
	if n == 0:
		return 0.0
	
	if _spatial_grid == null or _spatial_grid.cell_size != cutoff_radius:
		_spatial_grid = SpatialHashGrid.new()
		_spatial_grid.initialize(cutoff_radius, n * 2)
	_spatial_grid.build_grid(pos)
	
	var total_v: float = 0.0
	var eps4: float = 4.0 * epsilon
	var sig2: float = _sigma_sq
	var rc_sq: float = _cutoff_sq
	var shift: float = _potential_shift
	var min_r_sq: float = 0.04 * sig2
	
	for i in range(n):
		var pos_i: Vector3 = pos[i]
		var neighbors: PackedInt32Array = _spatial_grid.get_neighbors(pos_i, cutoff_radius)
		var n_neighbors: int = neighbors.size()
		
		for k in range(n_neighbors):
			var j: int = neighbors[k]
			if j > i:
				var r_sq: float = pos_i.distance_squared_to(pos[j])
				if r_sq < rc_sq:
					r_sq = maxf(r_sq, min_r_sq)
					var inv_r2: float = 1.0 / r_sq
					var sr2: float = sig2 * inv_r2
					var sr6: float = sr2 * sr2 * sr2
					var sr12: float = sr6 * sr6
					
					var v_shift: float = eps4 * (sr12 - sr6) - shift
					total_v += v_shift
	
	return total_v

# ==============================================================================
# 5. Thermodynamics & Berendsen Thermostat
# ==============================================================================

func compute_instantaneous_temperature() -> float:
	var n: int = _velocities.size()
	if n == 0:
		return 0.0
	var total_ek: float = 0.0
	for i in range(n):
		total_ek += 0.5 * _masses[i] * _velocities[i].length_squared()
	var kb: float = boltzmann_constant if boltzmann_constant > 0.0 else 1.0
	return (2.0 * total_ek) / (3.0 * float(n) * kb)

func apply_berendsen_thermostat(dt: float) -> float:
	var n: int = _velocities.size()
	if n == 0 or dt <= 0.0:
		return 1.0
	
	var t_inst: float = compute_instantaneous_temperature()
	if t_inst < 1e-9:
		t_inst = 1e-9
	
	var tau: float = maxf(thermostat_tau, 1e-4)
	var factor: float = 1.0 + (dt / tau) * ((target_temperature / t_inst) - 1.0)
	var lambda_scale: float = sqrt(maxf(factor, 0.0))
	
	# Clamp velocity multiplier to prevent numerical shock waves
	lambda_scale = clampf(lambda_scale, 0.5, 2.0)
	
	for i in range(n):
		_velocities[i] = _velocities[i] * lambda_scale
	
	return lambda_scale

func heat_up(delta_temp: float = 0.2) -> void:
	target_temperature += delta_temp
	target_temperature_changed.emit(target_temperature)
	if _event_bus:
		_event_bus.emit("md_target_temp_changed", {"target_temperature": target_temperature})

func cool_down(delta_temp: float = 0.2) -> void:
	target_temperature = maxf(target_temperature - delta_temp, 0.05)
	target_temperature_changed.emit(target_temperature)
	if _event_bus:
		_event_bus.emit("md_target_temp_changed", {"target_temperature": target_temperature})

# ==============================================================================
# 6. Container Boundaries & Compression
# ==============================================================================

func enforce_boundaries() -> void:
	var n: int = _positions.size()
	var eff_box: Vector3 = box_half_extent - Vector3(particle_radius, particle_radius, particle_radius)
	var e: float = clampf(restitution, 0.0, 1.0)
	
	for i in range(n):
		var pos: Vector3 = _positions[i]
		var vel: Vector3 = _velocities[i]
		
		# Axis X
		if pos.x > eff_box.x:
			pos.x = eff_box.x - (pos.x - eff_box.x) * e
			vel.x = -vel.x * e
		elif pos.x < -eff_box.x:
			pos.x = -eff_box.x + (-eff_box.x - pos.x) * e
			vel.x = -vel.x * e
		
		# Axis Y
		if pos.y > eff_box.y:
			pos.y = eff_box.y - (pos.y - eff_box.y) * e
			vel.y = -vel.y * e
		elif pos.y < -eff_box.y:
			pos.y = -eff_box.y + (-eff_box.y - pos.y) * e
			vel.y = -vel.y * e
		
		# Axis Z
		if pos.z > eff_box.z:
			pos.z = eff_box.z - (pos.z - eff_box.z) * e
			vel.z = -vel.z * e
		elif pos.z < -eff_box.z:
			pos.z = -eff_box.z + (-eff_box.z - pos.z) * e
			vel.z = -vel.z * e
		
		# Final clamping safeguard
		pos.x = clampf(pos.x, -eff_box.x, eff_box.x)
		pos.y = clampf(pos.y, -eff_box.y, eff_box.y)
		pos.z = clampf(pos.z, -eff_box.z, eff_box.z)
		
		_positions[i] = pos
		_velocities[i] = vel

func compress_container(scale_factor: float = 0.95) -> void:
	var target_box: Vector3 = box_half_extent * scale_factor
	var min_dim: float = 3.0 * sigma
	target_box.x = maxf(target_box.x, min_dim)
	target_box.y = maxf(target_box.y, min_dim)
	target_box.z = maxf(target_box.z, min_dim)
	
	box_half_extent = target_box
	enforce_boundaries()
	_update_container_mesh()
	
	container_resized.emit(box_half_extent)
	if _event_bus:
		_event_bus.emit("md_container_compressed", {"box_half_extent": box_half_extent})

# ==============================================================================
# 7. Maxwell-Boltzmann Speed Distribution Analysis
# ==============================================================================

func compute_velocity_distribution(num_bins: int = 20, max_speed: float = 0.0) -> Dictionary:
	var n: int = _velocities.size()
	if n == 0 or num_bins <= 0:
		return {}
	
	var speeds := PackedFloat32Array()
	speeds.resize(n)
	var max_v: float = 0.0
	var sum_v: float = 0.0
	var sum_v2: float = 0.0
	
	for i in range(n):
		var spd: float = _velocities[i].length()
		speeds[i] = spd
		max_v = maxf(max_v, spd)
		sum_v += spd
		sum_v2 += spd * spd
	
	if max_speed <= 0.0:
		max_speed = maxf(max_v * 1.15, 1.0)
	
	var bin_width: float = max_speed / float(num_bins)
	var counts := PackedInt32Array()
	counts.resize(num_bins)
	
	for i in range(n):
		var b: int = int(floor(speeds[i] / bin_width))
		b = clampi(b, 0, num_bins - 1)
		counts[b] += 1
	
	var bin_centers := PackedFloat32Array()
	bin_centers.resize(num_bins)
	var empirical_pdf := PackedFloat32Array()
	empirical_pdf.resize(num_bins)
	var theoretical_pdf := PackedFloat32Array()
	theoretical_pdf.resize(num_bins)
	
	var temp: float = compute_instantaneous_temperature()
	var kb: float = boltzmann_constant if boltzmann_constant > 0.0 else 1.0
	var m: float = particle_mass
	
	# Analytical prefactor 4*PI * (m / (2*PI*kb*T))^(3/2)
	var prefactor: float = 0.0
	if temp > 1e-6:
		var beta: float = m / (2.0 * PI * kb * temp)
		prefactor = 4.0 * PI * pow(beta, 1.5)
	
	var norm: float = 1.0 / (float(n) * bin_width)
	for b in range(num_bins):
		var v_c: float = (float(b) + 0.5) * bin_width
		bin_centers[b] = v_c
		empirical_pdf[b] = float(counts[b]) * norm
		if temp > 1e-6:
			var exponent: float = -(m * v_c * v_c) / (2.0 * kb * temp)
			theoretical_pdf[b] = prefactor * v_c * v_c * exp(exponent)
		else:
			theoretical_pdf[b] = 0.0
	
	var mean_spd: float = sum_v / float(n)
	var rms_spd: float = sqrt(sum_v2 / float(n))
	var mp_spd: float = sqrt(2.0 * kb * temp / m) if temp > 1e-6 else 0.0
	
	return {
		"bin_centers": bin_centers,
		"empirical_pdf": empirical_pdf,
		"theoretical_pdf": theoretical_pdf,
		"bin_width": bin_width,
		"mean_speed": mean_spd,
		"rms_speed": rms_spd,
		"most_probable_speed": mp_spd,
		"temperature": temp,
		"particle_count": n
	}

# ==============================================================================
# 8. GPU MultiMesh Rendering Pipeline & Container Visualizer
# ==============================================================================

func _setup_multimesh_renderer() -> void:
	_multimesh_instance = MultiMeshInstance3D.new()
	_multimesh_instance.name = "ParticleMultiMeshInstance"
	
	_multimesh = MultiMesh.new()
	_multimesh.transform_format = MultiMesh.TRANSFORM_3D
	_multimesh.use_colors = true
	_multimesh.use_custom_data = true
	
	var sphere := SphereMesh.new()
	sphere.radius = particle_radius
	sphere.height = particle_radius * 2.0
	sphere.radial_segments = 12
	sphere.rings = 6
	
	# Load or construct specialized particle glow shader material
	var shader := load("res://shaders/particle_field_glow.gdshader") as Shader
	if shader:
		_particle_shader_material = ShaderMaterial.new()
		_particle_shader_material.shader = shader
		sphere.material = _particle_shader_material
	else:
		# Fallback standard material if shader not loaded yet
		var std_mat := StandardMaterial3D.new()
		std_mat.albedo_color = Color(0.2, 0.6, 1.0)
		std_mat.emission_enabled = true
		std_mat.emission = Color(0.1, 0.4, 0.9)
		sphere.material = std_mat
	
	_multimesh.mesh = sphere
	_multimesh_instance.multimesh = _multimesh
	add_child(_multimesh_instance)

func update_multimesh_visuals() -> void:
	if not _multimesh or _positions.is_empty():
		return
	
	var n: int = _positions.size()
	if _multimesh.instance_count != n:
		_multimesh.instance_count = n
	
	var spd_scale: float = speed_scale_visual if speed_scale_visual > 0.0 else 3.0
	
	for i in range(n):
		var pos: Vector3 = _positions[i]
		var vel: Vector3 = _velocities[i]
		var spd: float = vel.length()
		var t_norm: float = clampf(spd / spd_scale, 0.0, 1.0)
		
		# Set instance transform in laboratory frame
		_multimesh.set_instance_transform(i, Transform3D(Basis(), pos))
		
		# Set instance custom data: r=normalized_speed, g=raw_speed, b=kinetic_energy, a=mass
		var e_k: float = 0.5 * _masses[i] * spd * spd
		_multimesh.set_instance_custom_data(i, Color(t_norm, spd, e_k, _masses[i]))
		
		# Set instance vertex color fallback (smooth cold-blue to warm-red)
		var col: Color = Color(t_norm, 0.5 * (1.0 - t_norm), 1.0 - t_norm, 1.0)
		_multimesh.set_instance_color(i, col)

func _setup_container_visual() -> void:
	_container_mesh_instance = MeshInstance3D.new()
	_container_mesh_instance.name = "ContainerBoundaryWireframe"
	var mat := StandardMaterial3D.new()
	mat.shading_mode = StandardMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(0.2, 0.8, 1.0, 0.4)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_container_mesh_instance.material_override = mat
	add_child(_container_mesh_instance)
	_update_container_mesh()

func _update_container_mesh() -> void:
	if not _container_mesh_instance:
		return
	
	var im: ImmediateMesh = _container_mesh_instance.mesh as ImmediateMesh
	if im == null:
		im = ImmediateMesh.new()
		_container_mesh_instance.mesh = im
	
	im.clear_surfaces()
	im.surface_begin(Mesh.PRIMITIVE_LINES)
	var b: Vector3 = box_half_extent
	
	# Bottom 4 edges (-Y)
	im.surface_add_vertex(Vector3(-b.x, -b.y, -b.z))
	im.surface_add_vertex(Vector3( b.x, -b.y, -b.z))
	im.surface_add_vertex(Vector3( b.x, -b.y, -b.z))
	im.surface_add_vertex(Vector3( b.x, -b.y,  b.z))
	im.surface_add_vertex(Vector3( b.x, -b.y,  b.z))
	im.surface_add_vertex(Vector3(-b.x, -b.y,  b.z))
	im.surface_add_vertex(Vector3(-b.x, -b.y,  b.z))
	im.surface_add_vertex(Vector3(-b.x, -b.y, -b.z))
	
	# Top 4 edges (+Y)
	im.surface_add_vertex(Vector3(-b.x,  b.y, -b.z))
	im.surface_add_vertex(Vector3( b.x,  b.y, -b.z))
	im.surface_add_vertex(Vector3( b.x,  b.y, -b.z))
	im.surface_add_vertex(Vector3( b.x,  b.y,  b.z))
	im.surface_add_vertex(Vector3( b.x,  b.y,  b.z))
	im.surface_add_vertex(Vector3(-b.x,  b.y,  b.z))
	im.surface_add_vertex(Vector3(-b.x,  b.y,  b.z))
	im.surface_add_vertex(Vector3(-b.x,  b.y, -b.z))
	
	# Vertical 4 pillars
	im.surface_add_vertex(Vector3(-b.x, -b.y, -b.z))
	im.surface_add_vertex(Vector3(-b.x,  b.y, -b.z))
	im.surface_add_vertex(Vector3( b.x, -b.y, -b.z))
	im.surface_add_vertex(Vector3( b.x,  b.y, -b.z))
	im.surface_add_vertex(Vector3( b.x, -b.y,  b.z))
	im.surface_add_vertex(Vector3( b.x,  b.y,  b.z))
	im.surface_add_vertex(Vector3(-b.x, -b.y,  b.z))
	im.surface_add_vertex(Vector3(-b.x,  b.y,  b.z))
	
	im.surface_end()

# ==============================================================================
# 9. Input & Interactive Control
# ==============================================================================

func _unhandled_input(event: InputEvent) -> void:
	if not is_initialized:
		return
	
	if event.is_action_pressed("md_heat_up") or (event is InputEventKey and event.pressed and not event.is_echo() and event.keycode == KEY_UP):
		heat_up(0.2)
	elif event.is_action_pressed("md_cool_down") or (event is InputEventKey and event.pressed and not event.is_echo() and event.keycode == KEY_DOWN):
		cool_down(0.2)
	elif event.is_action_pressed("md_compress_box") or (event is InputEventKey and event.pressed and not event.is_echo() and event.keycode == KEY_P):
		compress_container(0.95)
