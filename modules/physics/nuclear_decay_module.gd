class_name NuclearDecayModule
extends UniCoreModule

## UniCORE Fundamental Scientific Simulation Platform
## Module: Nuclear Decay & Induced Reaction Engine
## Simulates Poisson radioactive decay, 4-momentum conservation, and chain reactions.

const SpatialHashGrid = preload("res://core/physics/spatial_hash_grid.gd")
const SimulationTimeController = preload("res://core/physics/simulation_time_controller.gd")
const ConservationSentry = preload("res://core/physics/conservation_sentry.gd")

signal decay_occurred(isotope_symbol: String, channel: int, position: Vector3, q_value: float)
signal fission_triggered(position: Vector3, fragments_count: int, prompt_neutrons: int, energy: float)
signal chain_reaction_status(k_effective: float, active_neutrons: int, active_nuclei: int)

enum DecayChannel {
	NONE = 0,
	ALPHA = 1,
	BETA_MINUS = 2,
	GAMMA = 3,
	INDUCED_FISSION = 4
}

enum RadiationType {
	NONE = 0,
	ALPHA = 1,
	BETA = 2,
	GAMMA = 3,
	NEUTRON = 4
}

# Physical Simulation Constants
const SPEED_OF_LIGHT_SIM: float = 50.0  # Scaled interactive c_sim (m/s)
const C_SQUARED: float = SPEED_OF_LIGHT_SIM * SPEED_OF_LIGHT_SIM
const MAX_NUCLEI: int = 10000
const MAX_RADIATION: int = 20000
const NEUTRON_COLLISION_RADIUS: float = 0.25
const DEFAULT_RADIATION_LIFETIME: float = 5.0
const LN2: float = 0.69314718056

# State Properties
@export var is_simulation_enabled: bool = true
@export var control_rod_depth: float = 0.0: # 0.0 = fully withdrawn, 1.0 = fully inserted
	set(val):
		control_rod_depth = clampf(val, 0.0, 1.0)
@export var half_life_multiplier: float = 1.0 # Interactive time scaling
@export var containment_radius: float = 40.0

# Internal Subsystems
var spatial_grid: SpatialHashGrid = null
var time_controller: SimulationTimeController = null
var conservation_sentry: ConservationSentry = null

# Contiguous Nuclei Buffers
var nuclei_positions: PackedVector3Array = PackedVector3Array()
var nuclei_velocities: PackedVector3Array = PackedVector3Array()
var nuclei_masses: PackedFloat32Array = PackedFloat32Array()
var nuclei_isotope_keys: Array[String] = []
var nuclei_half_lives: PackedFloat32Array = PackedFloat32Array()
var nuclei_channels: PackedInt32Array = PackedInt32Array()
var nuclei_active: PackedByteArray = PackedByteArray()
var active_nuclei_count: int = 0

# Contiguous Radiation Buffers
var rad_positions: PackedVector3Array = PackedVector3Array()
var rad_velocities: PackedVector3Array = PackedVector3Array()
var rad_masses: PackedFloat32Array = PackedFloat32Array()
var rad_types: PackedInt32Array = PackedInt32Array()
var rad_lifetimes: PackedFloat32Array = PackedFloat32Array()
var rad_active: PackedByteArray = PackedByteArray()
var active_rad_count: int = 0

# Visual Nodes
var nuclei_mesh_instance: MultiMeshInstance3D = null
var rad_mesh_instance: MultiMeshInstance3D = null

func set_simulation_active(val: bool) -> void:
	is_simulation_enabled = val
	if nuclei_mesh_instance and is_instance_valid(nuclei_mesh_instance):
		nuclei_mesh_instance.visible = val
	if rad_mesh_instance and is_instance_valid(rad_mesh_instance):
		rad_mesh_instance.visible = val

# Invariant & Telemetry Tracking
var initial_total_energy: float = 0.0
var initial_total_momentum: Vector3 = Vector3.ZERO
var total_fission_events: int = 0
var total_decay_events: int = 0
var last_k_effective: float = 1.0
var previous_neutron_count: int = 0
var sample_timer: float = 0.0
const SAMPLE_INTERVAL: float = 0.5

# Built-in Isotope Database
var isotope_db: Dictionary = {}

func _init() -> void:
	_initialize_isotope_database()
	spatial_grid = SpatialHashGrid.new()
	spatial_grid.initialize(0.5, 5000)

func get_module_id() -> String:
	return "nuclear_decay"

func get_module_name() -> String:
	return "Nuclear Decay & Reaction Module"

func get_action_bindings() -> Array[Dictionary]:
	return [
		{"action": "inject_neutron", "label": "Inject Trigger Neutron", "default_key": KEY_SPACE, "description": "Spawns a prompt neutron towards the core"},
		{"action": "insert_control_rods", "label": "Insert Control Rods", "default_key": KEY_DOWN, "description": "Absorbs neutrons to damp chain reaction"},
		{"action": "withdraw_control_rods", "label": "Withdraw Control Rods", "default_key": KEY_UP, "description": "Increases reactivity"},
		{"action": "reset_nuclear_core", "label": "Reset Nuclear Core", "default_key": KEY_R, "description": "Re-spawns pristine isotope assembly"}
	]

func initialize(context: Dictionary) -> bool:
	super.initialize(context)
	
	if core_context.has("time_controller") and core_context["time_controller"]:
		time_controller = core_context["time_controller"] as SimulationTimeController
		if time_controller:
			time_controller.sim_tick.connect(_on_sim_tick)
	
	if core_context.has("conservation_sentry") and core_context["conservation_sentry"]:
		conservation_sentry = core_context["conservation_sentry"] as ConservationSentry
	
	_setup_visualizers()
	_reset_buffers()
	
	# Initial default assembly: Pristine U-235 core
	setup_reactor_core(150, 3.0)
	set_simulation_active(false)
	
	return true

func cleanup() -> void:
	if time_controller and time_controller.sim_tick.is_connected(_on_sim_tick):
		time_controller.sim_tick.disconnect(_on_sim_tick)
	
	time_controller = null
	conservation_sentry = null
	
	if nuclei_mesh_instance and is_instance_valid(nuclei_mesh_instance):
		nuclei_mesh_instance.queue_free()
		nuclei_mesh_instance = null
	
	if rad_mesh_instance and is_instance_valid(rad_mesh_instance):
		rad_mesh_instance.queue_free()
		rad_mesh_instance = null
	
	_reset_buffers()
	super.cleanup()

# ==============================================================================
# ISOTOPE DATABASE SPECIFICATION (14 SPECIES)
# ==============================================================================

func _initialize_isotope_database() -> void:
	isotope_db.clear()
	
	# 1. Uranium-235 (Fissile Alpha emitter)
	isotope_db["U-235"] = {
		"symbol": "U-235", "name": "Uranium-235", "z": 92, "a": 235,
		"atomic_mass_u": 235.0439, "half_life_seconds": 30.0,
		"decay_channel": DecayChannel.ALPHA, "daughter_symbol": "Th-231",
		"q_value_mev": 4.68, "is_fissile": true,
		"color": Color(0.20, 0.95, 0.30), "visual_scale": 1.40
	}
	# 2. Radium-226 (Alpha emitter)
	isotope_db["Ra-226"] = {
		"symbol": "Ra-226", "name": "Radium-226", "z": 88, "a": 226,
		"atomic_mass_u": 226.0254, "half_life_seconds": 15.0,
		"decay_channel": DecayChannel.ALPHA, "daughter_symbol": "Rn-222",
		"q_value_mev": 4.87, "is_fissile": false,
		"color": Color(0.10, 0.85, 0.85), "visual_scale": 1.38
	}
	# 3. Carbon-14 (Beta-minus emitter)
	isotope_db["C-14"] = {
		"symbol": "C-14", "name": "Carbon-14", "z": 6, "a": 14,
		"atomic_mass_u": 14.0032, "half_life_seconds": 20.0,
		"decay_channel": DecayChannel.BETA_MINUS, "daughter_symbol": "N-14",
		"q_value_mev": 0.156, "is_fissile": false,
		"color": Color(0.65, 0.55, 0.35), "visual_scale": 0.70
	}
	# 4. Tritium (H-3 Beta-minus emitter)
	isotope_db["H-3"] = {
		"symbol": "H-3", "name": "Tritium", "z": 1, "a": 3,
		"atomic_mass_u": 3.0160, "half_life_seconds": 12.0,
		"decay_channel": DecayChannel.BETA_MINUS, "daughter_symbol": "He-3",
		"q_value_mev": 0.0186, "is_fissile": false,
		"color": Color(0.35, 0.70, 1.00), "visual_scale": 0.45
	}
	# 5. Deuterium (H-2 Stable)
	isotope_db["H-2"] = {
		"symbol": "H-2", "name": "Deuterium", "z": 1, "a": 2,
		"atomic_mass_u": 2.0141, "half_life_seconds": INF,
		"decay_channel": DecayChannel.NONE, "daughter_symbol": "",
		"q_value_mev": 0.0, "is_fissile": false,
		"color": Color(0.70, 0.85, 1.00), "visual_scale": 0.40
	}
	# 6. Alpha Particle (He-4 Stable)
	isotope_db["He-4"] = {
		"symbol": "He-4", "name": "Alpha Particle", "z": 2, "a": 4,
		"atomic_mass_u": 4.0015, "half_life_seconds": INF,
		"decay_channel": DecayChannel.NONE, "daughter_symbol": "",
		"q_value_mev": 0.0, "is_fissile": false,
		"color": Color(1.00, 0.75, 0.15), "visual_scale": 0.50
	}
	# 7. Thorium-231 (Beta-minus emitter)
	isotope_db["Th-231"] = {
		"symbol": "Th-231", "name": "Thorium-231", "z": 90, "a": 231,
		"atomic_mass_u": 231.0363, "half_life_seconds": 25.5,
		"decay_channel": DecayChannel.BETA_MINUS, "daughter_symbol": "Pa-231",
		"q_value_mev": 0.39, "is_fissile": false,
		"color": Color(0.35, 0.65, 0.45), "visual_scale": 1.39
	}
	# 8. Radon-222 (Alpha emitter)
	isotope_db["Rn-222"] = {
		"symbol": "Rn-222", "name": "Radon-222", "z": 86, "a": 222,
		"atomic_mass_u": 222.0176, "half_life_seconds": 3.82,
		"decay_channel": DecayChannel.ALPHA, "daughter_symbol": "Po-218",
		"q_value_mev": 5.59, "is_fissile": false,
		"color": Color(0.25, 0.70, 0.90), "visual_scale": 1.37
	}
	# 9. Nitrogen-14 (Stable)
	isotope_db["N-14"] = {
		"symbol": "N-14", "name": "Nitrogen-14", "z": 7, "a": 14,
		"atomic_mass_u": 14.0031, "half_life_seconds": INF,
		"decay_channel": DecayChannel.NONE, "daughter_symbol": "",
		"q_value_mev": 0.0, "is_fissile": false,
		"color": Color(0.50, 0.50, 0.60), "visual_scale": 0.70
	}
	# 10. Helium-3 (Stable)
	isotope_db["He-3"] = {
		"symbol": "He-3", "name": "Helium-3", "z": 2, "a": 3,
		"atomic_mass_u": 3.0160, "half_life_seconds": INF,
		"decay_channel": DecayChannel.NONE, "daughter_symbol": "",
		"q_value_mev": 0.0, "is_fissile": false,
		"color": Color(0.55, 0.85, 0.95), "visual_scale": 0.45
	}
	# 11. Krypton-92 (Fission Fragment)
	isotope_db["Kr-92"] = {
		"symbol": "Kr-92", "name": "Krypton-92", "z": 36, "a": 92,
		"atomic_mass_u": 91.926, "half_life_seconds": INF,
		"decay_channel": DecayChannel.NONE, "daughter_symbol": "",
		"q_value_mev": 0.0, "is_fissile": false,
		"color": Color(1.00, 0.30, 0.20), "visual_scale": 1.05
	}
	# 12. Barium-141 (Fission Fragment)
	isotope_db["Ba-141"] = {
		"symbol": "Ba-141", "name": "Barium-141", "z": 56, "a": 141,
		"atomic_mass_u": 140.914, "half_life_seconds": INF,
		"decay_channel": DecayChannel.NONE, "daughter_symbol": "",
		"q_value_mev": 0.0, "is_fissile": false,
		"color": Color(0.95, 0.15, 0.40), "visual_scale": 1.20
	}
	# 13. Neutron (Subatomic / Prompt)
	isotope_db["Neutron"] = {
		"symbol": "Neutron", "name": "Free Neutron", "z": 0, "a": 1,
		"atomic_mass_u": 1.0087, "half_life_seconds": 100.0,
		"decay_channel": DecayChannel.NONE, "daughter_symbol": "",
		"q_value_mev": 0.0, "is_fissile": false,
		"color": Color(1.00, 1.00, 0.60), "visual_scale": 0.25
	}
	# 14. Electron / Beta Particle
	isotope_db["Electron"] = {
		"symbol": "Electron", "name": "Beta Particle", "z": -1, "a": 0,
		"atomic_mass_u": 0.00054858, "half_life_seconds": INF,
		"decay_channel": DecayChannel.NONE, "daughter_symbol": "",
		"q_value_mev": 0.0, "is_fissile": false,
		"color": Color(0.20, 0.60, 1.00), "visual_scale": 0.15
	}
	# 15. Gamma Photon
	isotope_db["Gamma"] = {
		"symbol": "Gamma", "name": "Gamma Photon", "z": 0, "a": 0,
		"atomic_mass_u": 0.0, "half_life_seconds": INF,
		"decay_channel": DecayChannel.NONE, "daughter_symbol": "",
		"q_value_mev": 0.0, "is_fissile": false,
		"color": Color(0.90, 0.40, 1.00), "visual_scale": 0.10
	}
	# Additional decay products (daughters)
	isotope_db["Pa-231"] = {
		"symbol": "Pa-231", "name": "Protactinium-231", "z": 91, "a": 231,
		"atomic_mass_u": 231.0358, "half_life_seconds": INF,
		"decay_channel": DecayChannel.NONE, "daughter_symbol": "",
		"q_value_mev": 0.0, "is_fissile": false,
		"color": Color(0.40, 0.60, 0.50), "visual_scale": 1.39
	}
	isotope_db["Po-218"] = {
		"symbol": "Po-218", "name": "Polonium-218", "z": 84, "a": 218,
		"atomic_mass_u": 218.0089, "half_life_seconds": INF,
		"decay_channel": DecayChannel.NONE, "daughter_symbol": "",
		"q_value_mev": 0.0, "is_fissile": false,
		"color": Color(0.30, 0.75, 0.70), "visual_scale": 1.36
	}

func get_isotope_db() -> Dictionary:
	return isotope_db

# ==============================================================================
# BUFFER SETUP & VISUALIZERS
# ==============================================================================

func _setup_visualizers() -> void:
	# Nuclei MultiMeshInstance3D
	nuclei_mesh_instance = MultiMeshInstance3D.new()
	nuclei_mesh_instance.name = "NucleiMultiMesh"
	var n_mm: MultiMesh = MultiMesh.new()
	n_mm.transform_format = MultiMesh.TRANSFORM_3D
	n_mm.use_colors = true
	var n_sphere: SphereMesh = SphereMesh.new()
	n_sphere.radius = 0.15
	n_sphere.height = 0.30
	n_sphere.radial_segments = 12
	n_sphere.rings = 6
	n_mm.mesh = n_sphere
	n_mm.instance_count = MAX_NUCLEI
	n_mm.visible_instance_count = 0
	nuclei_mesh_instance.multimesh = n_mm
	var n_mat: StandardMaterial3D = StandardMaterial3D.new()
	n_mat.vertex_color_use_as_albedo = true
	n_mat.roughness = 0.4
	nuclei_mesh_instance.material_override = n_mat
	add_child(nuclei_mesh_instance)
	
	# Radiation MultiMeshInstance3D
	rad_mesh_instance = MultiMeshInstance3D.new()
	rad_mesh_instance.name = "RadiationMultiMesh"
	var r_mm: MultiMesh = MultiMesh.new()
	r_mm.transform_format = MultiMesh.TRANSFORM_3D
	r_mm.use_colors = true
	var r_sphere: SphereMesh = SphereMesh.new()
	r_sphere.radius = 0.06
	r_sphere.height = 0.12
	r_sphere.radial_segments = 8
	r_sphere.rings = 4
	r_mm.mesh = r_sphere
	r_mm.instance_count = MAX_RADIATION
	r_mm.visible_instance_count = 0
	rad_mesh_instance.multimesh = r_mm
	var r_mat: StandardMaterial3D = StandardMaterial3D.new()
	r_mat.vertex_color_use_as_albedo = true
	r_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	rad_mesh_instance.material_override = r_mat
	add_child(rad_mesh_instance)

func _reset_buffers() -> void:
	nuclei_positions.clear()
	nuclei_velocities.clear()
	nuclei_masses.clear()
	nuclei_isotope_keys.clear()
	nuclei_half_lives.clear()
	nuclei_channels.clear()
	nuclei_active.clear()
	active_nuclei_count = 0
	
	rad_positions.clear()
	rad_velocities.clear()
	rad_masses.clear()
	rad_types.clear()
	rad_lifetimes.clear()
	rad_active.clear()
	active_rad_count = 0
	
	total_fission_events = 0
	total_decay_events = 0
	last_k_effective = 1.0
	previous_neutron_count = 0
	sample_timer = 0.0

# ==============================================================================
# SPAWNING & REACTOR CORE SETUP
# ==============================================================================

func spawn_nucleus(
	pos: Vector3,
	vel: Vector3,
	isotope_symbol: String
) -> int:
	var iso: Dictionary = isotope_db.get(isotope_symbol, {})
	if iso.is_empty():
		push_error("NuclearDecayModule: Unknown isotope %s" % isotope_symbol)
		return -1
	
	var idx: int = -1
	var total_slots: int = nuclei_positions.size()
	
	# Reuse inactive slot if available
	for i in range(total_slots):
		if nuclei_active[i] == 0:
			idx = i
			break
	
	var m: float = float(iso.get("atomic_mass_u", 1.0))
	var t_half: float = float(iso.get("half_life_seconds", INF))
	var ch: int = int(iso.get("decay_channel", DecayChannel.NONE))
	
	if idx >= 0:
		nuclei_positions[idx] = pos
		nuclei_velocities[idx] = vel
		nuclei_masses[idx] = m
		nuclei_isotope_keys[idx] = isotope_symbol
		nuclei_half_lives[idx] = t_half
		nuclei_channels[idx] = ch
		nuclei_active[idx] = 1
	else:
		if total_slots >= MAX_NUCLEI:
			return -1
		idx = nuclei_positions.size()
		nuclei_positions.append(pos)
		nuclei_velocities.append(vel)
		nuclei_masses.append(m)
		nuclei_isotope_keys.append(isotope_symbol)
		nuclei_half_lives.append(t_half)
		nuclei_channels.append(ch)
		nuclei_active.append(1)
	
	active_nuclei_count += 1
	return idx

func spawn_radiation(
	pos: Vector3,
	vel: Vector3,
	mass: float,
	rad_type: int,
	lifetime: float = DEFAULT_RADIATION_LIFETIME
) -> int:
	var idx: int = -1
	var total_slots: int = rad_positions.size()
	
	for i in range(total_slots):
		if rad_active[i] == 0:
			idx = i
			break
	
	if idx >= 0:
		rad_positions[idx] = pos
		rad_velocities[idx] = vel
		rad_masses[idx] = mass
		rad_types[idx] = rad_type
		rad_lifetimes[idx] = lifetime
		rad_active[idx] = 1
	else:
		if total_slots >= MAX_RADIATION:
			return -1
		idx = rad_positions.size()
		rad_positions.append(pos)
		rad_velocities.append(vel)
		rad_masses.append(mass)
		rad_types.append(rad_type)
		rad_lifetimes.append(lifetime)
		rad_active.append(1)
	
	active_rad_count += 1
	return idx

func setup_reactor_core(u235_count: int = 150, radius: float = 3.0) -> void:
	_reset_buffers()
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 42
	
	for _i in range(u235_count):
		# Distribute uniformly in sphere
		var u: float = rng.randf()
		var r: float = radius * pow(u, 1.0 / 3.0)
		var cos_theta: float = rng.randf_range(-1.0, 1.0)
		var sin_theta: float = sqrt(maxf(0.0, 1.0 - cos_theta * cos_theta))
		var phi: float = rng.randf_range(0.0, TAU)
		
		var pos: Vector3 = Vector3(
			r * sin_theta * cos(phi),
			r * sin_theta * sin(phi),
			r * cos_theta
		)
		var vel: Vector3 = Vector3.ZERO
		spawn_nucleus(pos, vel, "U-235")
	
	initial_total_energy = compute_total_energy()
	initial_total_momentum = compute_total_momentum()
	if conservation_sentry:
		conservation_sentry.register_system(initial_total_energy, initial_total_momentum)
	
	_update_multimesh()

func setup_isotope_sample(isotope_symbol: String, count: int = 500, radius: float = 2.0) -> void:
	_reset_buffers()
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 123
	
	for _i in range(count):
		var u: float = rng.randf()
		var r: float = radius * pow(u, 1.0 / 3.0)
		var cos_theta: float = rng.randf_range(-1.0, 1.0)
		var sin_theta: float = sqrt(maxf(0.0, 1.0 - cos_theta * cos_theta))
		var phi: float = rng.randf_range(0.0, TAU)
		
		var pos: Vector3 = Vector3(
			r * sin_theta * cos(phi),
			r * sin_theta * sin(phi),
			r * cos_theta
		)
		spawn_nucleus(pos, Vector3.ZERO, isotope_symbol)
	
	initial_total_energy = compute_total_energy()
	initial_total_momentum = compute_total_momentum()
	if conservation_sentry:
		conservation_sentry.register_system(initial_total_energy, initial_total_momentum)
	
	_update_multimesh()

func inject_trigger_neutron(
	pos: Vector3 = Vector3(0.0, 0.0, -5.0),
	vel: Vector3 = Vector3(0.0, 0.0, 25.0)
) -> void:
	var m_n: float = float(isotope_db["Neutron"]["atomic_mass_u"])
	spawn_radiation(pos, vel, m_n, RadiationType.NEUTRON, 10.0)
	_update_multimesh()

# ==============================================================================
# SIMULATION STEPPING & MAIN TICK
# ==============================================================================

func _on_sim_tick(dt: float, _sim_time: float) -> void:
	if not is_simulation_enabled or dt <= 0.0:
		return
	
	# 1. Stochastic Poisson radioactive decays
	_process_decays(dt)
	
	# 2. Collision detection and induced fission chain reactions
	_process_fission_collisions(dt)
	
	# 3. Kinematic position updates
	_integrate_kinematics(dt)
	
	# 4. Radiation lifetimes and vacuum absorption
	_process_radiation(dt)
	
	# 5. Multiplication factor k_eff telemetry
	_sample_chain_reaction(dt)
	
	# 6. Synchronize rendering
	_update_multimesh()

func step_manual(dt: float) -> void:
	_on_sim_tick(dt, 0.0)

# ==============================================================================
# POISSON DECAY ENGINE
# ==============================================================================

func _process_decays(dt: float) -> void:
	var n_nuclei: int = nuclei_positions.size()
	for i in range(n_nuclei):
		if nuclei_active[i] == 0:
			continue
		
		var t_half: float = nuclei_half_lives[i] * half_life_multiplier
		if is_inf(t_half) or t_half <= 0.0:
			continue
		
		# Exact memoryless Poisson probability: P = 1 - exp(-lambda * dt)
		var lambda_decay: float = LN2 / t_half
		var p_decay: float = 1.0 - exp(-lambda_decay * dt)
		
		if randf() < p_decay:
			_execute_decay(i)

func _execute_decay(idx: int) -> void:
	var ch: int = nuclei_channels[idx]
	var symbol: String = nuclei_isotope_keys[idx]
	var iso: Dictionary = isotope_db.get(symbol, {})
	if iso.is_empty():
		return
	
	match ch:
		DecayChannel.ALPHA:
			_execute_alpha_decay(idx, iso)
		DecayChannel.BETA_MINUS:
			_execute_beta_decay(idx, iso)
		DecayChannel.GAMMA:
			_execute_gamma_decay(idx, iso)

func _execute_alpha_decay(idx: int, iso: Dictionary) -> void:
	var parent_pos: Vector3 = nuclei_positions[idx]
	var parent_vel: Vector3 = nuclei_velocities[idx]
	var m_parent: float = nuclei_masses[idx]
	
	var daughter_key: String = String(iso.get("daughter_symbol", ""))
	var d_iso: Dictionary = isotope_db.get(daughter_key, {})
	var m_daughter: float = float(d_iso.get("atomic_mass_u", m_parent - 4.0))
	var m_alpha: float = float(isotope_db["He-4"]["atomic_mass_u"])
	
	# Q-value mass-energy equivalence: Q = (m_p - m_d - m_alpha) * c^2
	var delta_m: float = m_parent - (m_daughter + m_alpha)
	var q_energy: float = maxf(0.0001, delta_m * C_SQUARED)
	
	# Center-of-mass momentum magnitude:
	# p_cm = sqrt(2 * Q * m_alpha * m_daughter / (m_alpha + m_daughter))
	var p_cm: float = sqrt(2.0 * q_energy * m_alpha * m_daughter / (m_alpha + m_daughter))
	
	# Isotropic random direction on S^2 (Archimedes projection)
	var cos_theta: float = randf_range(-1.0, 1.0)
	var sin_theta: float = sqrt(maxf(0.0, 1.0 - cos_theta * cos_theta))
	var phi: float = randf_range(0.0, TAU)
	var dir: Vector3 = Vector3(sin_theta * cos(phi), sin_theta * sin(phi), cos_theta)
	
	# 4-Momentum Conservation:
	# v_alpha = v_p + (p_cm / m_alpha) * dir
	# v_daughter = v_p - (p_cm / m_daughter) * dir
	var alpha_vel: Vector3 = parent_vel + (p_cm / m_alpha) * dir
	var daughter_vel: Vector3 = parent_vel - (p_cm / m_daughter) * dir
	
	# Update parent slot into daughter nucleus
	nuclei_isotope_keys[idx] = daughter_key
	nuclei_masses[idx] = m_daughter
	nuclei_half_lives[idx] = float(d_iso.get("half_life_seconds", INF))
	nuclei_channels[idx] = int(d_iso.get("decay_channel", DecayChannel.NONE))
	nuclei_velocities[idx] = daughter_vel
	
	# Spawn ejected alpha radiation
	spawn_radiation(parent_pos, alpha_vel, m_alpha, RadiationType.ALPHA, DEFAULT_RADIATION_LIFETIME)
	
	total_decay_events += 1
	decay_occurred.emit(iso["symbol"], DecayChannel.ALPHA, parent_pos, q_energy)

func _execute_beta_decay(idx: int, iso: Dictionary) -> void:
	var parent_pos: Vector3 = nuclei_positions[idx]
	var parent_vel: Vector3 = nuclei_velocities[idx]
	var m_parent: float = nuclei_masses[idx]
	
	var daughter_key: String = String(iso.get("daughter_symbol", ""))
	var d_iso: Dictionary = isotope_db.get(daughter_key, {})
	var m_daughter: float = float(d_iso.get("atomic_mass_u", m_parent))
	var m_electron: float = float(isotope_db["Electron"]["atomic_mass_u"])
	
	var delta_m: float = m_parent - (m_daughter + m_electron)
	var q_energy: float = maxf(0.0001, delta_m * C_SQUARED)
	
	# 3-body continuous energy distribution: sample electron kinetic energy
	var e_fraction: float = randf()
	var e_electron: float = q_energy * e_fraction
	var e_neutrino: float = q_energy - e_electron
	
	var p_electron: float = sqrt(2.0 * m_electron * e_electron)
	var p_neutrino: float = e_neutrino / SPEED_OF_LIGHT_SIM
	
	# Sample random directions for electron and neutrino
	var dir_e: Vector3 = _random_unit_sphere()
	var dir_nu: Vector3 = _random_unit_sphere()
	
	var p_e_vec: Vector3 = dir_e * p_electron
	var p_nu_vec: Vector3 = dir_nu * p_neutrino
	
	# Recoil momentum to conserve total momentum exactly:
	# p_daughter = M_parent * v_parent - (p_e + p_nu)
	var daughter_momentum: Vector3 = (parent_vel * m_parent) - (p_e_vec + p_nu_vec)
	var daughter_vel: Vector3 = daughter_momentum / m_daughter
	var electron_vel: Vector3 = parent_vel + (p_e_vec / m_electron)
	
	# Update parent slot
	nuclei_isotope_keys[idx] = daughter_key
	nuclei_masses[idx] = m_daughter
	nuclei_half_lives[idx] = float(d_iso.get("half_life_seconds", INF))
	nuclei_channels[idx] = int(d_iso.get("decay_channel", DecayChannel.NONE))
	nuclei_velocities[idx] = daughter_vel
	
	spawn_radiation(parent_pos, electron_vel, m_electron, RadiationType.BETA, DEFAULT_RADIATION_LIFETIME)
	
	total_decay_events += 1
	decay_occurred.emit(iso["symbol"], DecayChannel.BETA_MINUS, parent_pos, q_energy)

func _execute_gamma_decay(idx: int, iso: Dictionary) -> void:
	var parent_pos: Vector3 = nuclei_positions[idx]
	var parent_vel: Vector3 = nuclei_velocities[idx]
	var m_parent: float = nuclei_masses[idx]
	
	var e_gamma: float = float(iso.get("q_value_mev", 1.0))
	var p_gamma_mag: float = e_gamma / SPEED_OF_LIGHT_SIM
	var dir: Vector3 = _random_unit_sphere()
	var p_gamma: Vector3 = dir * p_gamma_mag
	
	# Recoil daughter
	var daughter_vel: Vector3 = parent_vel - (p_gamma / m_parent)
	nuclei_velocities[idx] = daughter_vel
	
	# Spawn gamma photon
	var gamma_vel: Vector3 = dir * SPEED_OF_LIGHT_SIM
	spawn_radiation(parent_pos, gamma_vel, 0.0, RadiationType.GAMMA, DEFAULT_RADIATION_LIFETIME)
	
	total_decay_events += 1
	decay_occurred.emit(iso["symbol"], DecayChannel.GAMMA, parent_pos, e_gamma)

# ==============================================================================
# INDUCED FISSION & SPATIAL HASH ACCELERATION
# ==============================================================================

func _process_fission_collisions(_dt: float) -> void:
	if active_rad_count == 0 or active_nuclei_count == 0:
		return
	
	# 1. Gather all active fissile nuclei positions
	var fissile_indices: PackedInt32Array = PackedInt32Array()
	var fissile_pos: PackedVector3Array = PackedVector3Array()
	var n_nuclei: int = nuclei_positions.size()
	
	for i in range(n_nuclei):
		if nuclei_active[i] == 1:
			var iso: Dictionary = isotope_db.get(nuclei_isotope_keys[i], {})
			if bool(iso.get("is_fissile", false)):
				fissile_indices.append(i)
				fissile_pos.append(nuclei_positions[i])
	
	if fissile_indices.is_empty():
		return
	
	# 2. Build spatial hash grid over active fissile nuclei
	spatial_grid.build_grid(fissile_pos)
	
	# 3. Check collisions for each active neutron
	var n_rad: int = rad_positions.size()
	for r in range(n_rad):
		if rad_active[r] == 0 or rad_types[r] != RadiationType.NEUTRON:
			continue
		
		# Control rod neutron absorption check
		if control_rod_depth > 0.0 and randf() < (control_rod_depth * 0.95):
			rad_active[r] = 0
			active_rad_count -= 1
			continue
		
		var n_pos: Vector3 = rad_positions[r]
		var neighbors: PackedInt32Array = spatial_grid.get_neighbors(n_pos, NEUTRON_COLLISION_RADIUS)
		
		if not neighbors.is_empty():
			var local_fissile_idx: int = neighbors[0]
			var hit_nucleus_idx: int = fissile_indices[local_fissile_idx]
			
			# Deactivate incident neutron
			rad_active[r] = 0
			active_rad_count -= 1
			
			# Trigger induced fission
			_execute_fission(hit_nucleus_idx, rad_velocities[r])

func _execute_fission(parent_idx: int, incident_vel: Vector3) -> void:
	var pos: Vector3 = nuclei_positions[parent_idx]
	var parent_vel: Vector3 = nuclei_velocities[parent_idx]
	var m_parent: float = nuclei_masses[parent_idx]
	var m_neutron: float = float(isotope_db["Neutron"]["atomic_mass_u"])
	
	# Intermediate compound nucleus state: [U-236]*
	var m_compound: float = m_parent + m_neutron
	var p_compound: Vector3 = (parent_vel * m_parent) + (incident_vel * m_neutron)
	var v_compound: Vector3 = p_compound / m_compound
	
	# Scission products: Kr-92 (Fragment 1) + Ba-141 (Fragment 2) + 2 or 3 prompt neutrons
	var prompt_neutrons_count: int = 2 if randf() < 0.57 else 3 # Mean ~ 2.43
	var m_kr: float = float(isotope_db["Kr-92"]["atomic_mass_u"])
	var m_ba: float = float(isotope_db["Ba-141"]["atomic_mass_u"])
	
	# Mass defect and fission Q-value: Q ≈ (M_comp - M_kr - M_ba - ν * m_n) * c^2
	var delta_m: float = m_compound - (m_kr + m_ba + float(prompt_neutrons_count) * m_neutron)
	var q_fission: float = maxf(20.0, delta_m * C_SQUARED) # ~200 MeV equivalent
	
	# Kinetic energy partitioning: ~84% to heavy fission fragments, ~16% to prompt neutrons
	var e_fragments: float = q_fission * 0.84
	var e_neutrons_total: float = q_fission * 0.16
	var e_per_neutron: float = e_neutrons_total / float(prompt_neutrons_count)
	
	# Heavy fragments back-to-back emission in compound rest frame
	var p_frag_cm: float = sqrt(2.0 * e_fragments * m_kr * m_ba / (m_kr + m_ba))
	var scission_axis: Vector3 = _random_unit_sphere()
	
	var v_kr: Vector3 = v_compound + (p_frag_cm / m_kr) * scission_axis
	var v_ba: Vector3 = v_compound - (p_frag_cm / m_ba) * scission_axis
	
	# Update parent slot with Ba-141
	nuclei_isotope_keys[parent_idx] = "Ba-141"
	nuclei_masses[parent_idx] = m_ba
	nuclei_half_lives[parent_idx] = INF
	nuclei_channels[parent_idx] = DecayChannel.NONE
	nuclei_velocities[parent_idx] = v_ba
	
	# Spawn Kr-92 fragment
	spawn_nucleus(pos, v_kr, "Kr-92")
	
	# Spawn prompt neutrons isotropically
	var p_n_cm: float = sqrt(2.0 * m_neutron * e_per_neutron)
	for _k in range(prompt_neutrons_count):
		var n_dir: Vector3 = _random_unit_sphere()
		var v_prompt_n: Vector3 = v_compound + (p_n_cm / m_neutron) * n_dir
		spawn_radiation(pos, v_prompt_n, m_neutron, RadiationType.NEUTRON, DEFAULT_RADIATION_LIFETIME * 1.5)
	
	total_fission_events += 1
	fission_triggered.emit(pos, 2, prompt_neutrons_count, q_fission)

# ==============================================================================
# KINEMATICS, LIFETIMES & INVARIANTS
# ==============================================================================

func _integrate_kinematics(dt: float) -> void:
	# Nuclei motion
	var n_nuclei: int = nuclei_positions.size()
	for i in range(n_nuclei):
		if nuclei_active[i] == 1:
			var p: Vector3 = nuclei_positions[i] + nuclei_velocities[i] * dt
			# Soft containment boundary reflection
			if p.length_squared() > (containment_radius * containment_radius):
				nuclei_velocities[i] = -nuclei_velocities[i] * 0.8
				p = p.normalized() * containment_radius
			nuclei_positions[i] = p
	
	# Radiation motion
	var n_rad: int = rad_positions.size()
	for r in range(n_rad):
		if rad_active[r] == 1:
			rad_positions[r] += rad_velocities[r] * dt

func _process_radiation(dt: float) -> void:
	var n_rad: int = rad_positions.size()
	var active_count: int = 0
	var r_bound_sq: float = (containment_radius * 2.0) * (containment_radius * 2.0)
	
	for r in range(n_rad):
		if rad_active[r] == 1:
			rad_lifetimes[r] -= dt
			if rad_lifetimes[r] <= 0.0 or rad_positions[r].length_squared() > r_bound_sq:
				rad_active[r] = 0
			else:
				active_count += 1
	
	active_rad_count = active_count

func _sample_chain_reaction(dt: float) -> void:
	sample_timer += dt
	if sample_timer >= SAMPLE_INTERVAL:
		sample_timer = 0.0
		
		# Count current active neutrons
		var current_neutrons: int = 0
		var n_rad: int = rad_positions.size()
		for r in range(n_rad):
			if rad_active[r] == 1 and rad_types[r] == RadiationType.NEUTRON:
				current_neutrons += 1
		
		if previous_neutron_count > 0:
			last_k_effective = float(current_neutrons) / float(previous_neutron_count)
		else:
			last_k_effective = 1.0 if current_neutrons > 0 else 0.0
		
		previous_neutron_count = current_neutrons
		chain_reaction_status.emit(last_k_effective, current_neutrons, active_nuclei_count)
		
		# Invariant sentry audit
		if conservation_sentry:
			var cur_e: float = compute_total_energy()
			var cur_p: Vector3 = compute_total_momentum()
			var e_drift: float = absf(cur_e - initial_total_energy) / maxf(1.0, absf(initial_total_energy))
			if e_drift > conservation_sentry.energy_tolerance:
				conservation_sentry.conservation_warning.emit("energy", e_drift)

func compute_total_energy() -> float:
	var total_e: float = 0.0
	
	# Nuclei rest mass + kinetic energy
	var n_nuclei: int = nuclei_positions.size()
	for i in range(n_nuclei):
		if nuclei_active[i] == 1:
			var m: float = nuclei_masses[i]
			var v_sq: float = nuclei_velocities[i].length_squared()
			total_e += (m * C_SQUARED) + (0.5 * m * v_sq)
	
	# Radiation rest mass + kinetic energy
	var n_rad: int = rad_positions.size()
	for r in range(n_rad):
		if rad_active[r] == 1:
			var m_r: float = rad_masses[r]
			var v_sq_r: float = rad_velocities[r].length_squared()
			if rad_types[r] == RadiationType.GAMMA:
				# Photons have E = p * c = m_eff * c^2
				total_e += 1.0 # Nominal photon packet energy
			else:
				total_e += (m_r * C_SQUARED) + (0.5 * m_r * v_sq_r)
	
	return total_e

func compute_total_momentum() -> Vector3:
	var total_p: Vector3 = Vector3.ZERO
	
	var n_nuclei: int = nuclei_positions.size()
	for i in range(n_nuclei):
		if nuclei_active[i] == 1:
			total_p += nuclei_velocities[i] * nuclei_masses[i]
	
	var n_rad: int = rad_positions.size()
	for r in range(n_rad):
		if rad_active[r] == 1:
			if rad_types[r] == RadiationType.GAMMA:
				total_p += rad_velocities[r].normalized() * (1.0 / SPEED_OF_LIGHT_SIM)
			else:
				total_p += rad_velocities[r] * rad_masses[r]
	
	return total_p

# ==============================================================================
# MULTIMESH SYNCHRONIZATION
# ==============================================================================

func _update_multimesh() -> void:
	if not nuclei_mesh_instance or not rad_mesh_instance:
		return
	
	var n_mm: MultiMesh = nuclei_mesh_instance.multimesh
	var r_mm: MultiMesh = rad_mesh_instance.multimesh
	if not n_mm or not r_mm:
		return
	
	# 1. Update Nuclei MultiMesh
	var n_vis: int = 0
	var n_nuclei: int = nuclei_positions.size()
	for i in range(n_nuclei):
		if nuclei_active[i] == 1 and n_vis < MAX_NUCLEI:
			var iso: Dictionary = isotope_db.get(nuclei_isotope_keys[i], {})
			var sc: float = float(iso.get("visual_scale", 1.0))
			var col: Color = iso.get("color", Color.WHITE)
			
			var xform: Transform3D = Transform3D(Basis.from_scale(Vector3.ONE * sc), nuclei_positions[i])
			n_mm.set_instance_transform(n_vis, xform)
			n_mm.set_instance_color(n_vis, col)
			n_vis += 1
	n_mm.visible_instance_count = n_vis
	
	# 2. Update Radiation MultiMesh
	var r_vis: int = 0
	var n_rad: int = rad_positions.size()
	for r in range(n_rad):
		if rad_active[r] == 1 and r_vis < MAX_RADIATION:
			var r_type: int = rad_types[r]
			var col: Color = Color.WHITE
			var sc: float = 0.5
			
			match r_type:
				RadiationType.ALPHA:
					col = Color(1.00, 0.75, 0.15)
					sc = 0.8
				RadiationType.BETA:
					col = Color(0.20, 0.60, 1.00)
					sc = 0.4
				RadiationType.GAMMA:
					col = Color(0.90, 0.40, 1.00)
					sc = 0.3
				RadiationType.NEUTRON:
					col = Color(1.00, 1.00, 0.60)
					sc = 0.6
			
			var xform: Transform3D = Transform3D(Basis.from_scale(Vector3.ONE * sc), rad_positions[r])
			r_mm.set_instance_transform(r_vis, xform)
			r_mm.set_instance_color(r_vis, col)
			r_vis += 1
	r_mm.visible_instance_count = r_vis

# ==============================================================================
# UTILITIES & CONTROL HELPERS
# ==============================================================================

func insert_control_rods(amount: float = 0.1) -> void:
	control_rod_depth = clampf(control_rod_depth + amount, 0.0, 1.0)

func withdraw_control_rods(amount: float = 0.1) -> void:
	control_rod_depth = clampf(control_rod_depth - amount, 0.0, 1.0)

func set_control_rod_depth(depth: float) -> void:
	control_rod_depth = clampf(depth, 0.0, 1.0)

func get_active_nuclei_count() -> int:
	return active_nuclei_count

func get_active_radiation_count() -> int:
	return active_rad_count

func get_isotope_count(symbol: String) -> int:
	var count: int = 0
	var n_nuclei: int = nuclei_positions.size()
	for i in range(n_nuclei):
		if nuclei_active[i] == 1 and nuclei_isotope_keys[i] == symbol:
			count += 1
	return count

func get_total_fission_events() -> int:
	return total_fission_events

func get_total_decay_events() -> int:
	return total_decay_events

func get_k_effective() -> float:
	return last_k_effective

func _random_unit_sphere() -> Vector3:
	var cos_theta: float = randf_range(-1.0, 1.0)
	var sin_theta: float = sqrt(maxf(0.0, 1.0 - cos_theta * cos_theta))
	var phi: float = randf_range(0.0, TAU)
	return Vector3(sin_theta * cos(phi), sin_theta * sin(phi), cos_theta)
