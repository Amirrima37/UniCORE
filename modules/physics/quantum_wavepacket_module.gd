class_name QuantumWavePacketModule
extends UniCoreModule

## UniCORE Fundamental Scientific Simulation Platform
## Module: Quantum Wavepacket Propagation Engine (1D / 2D TDSE)
## Solves Time-Dependent Schrödinger Equation with unitary norm conservation.

const SimulationTimeController = preload("res://core/physics/simulation_time_controller.gd")
const ConservationSentry = preload("res://core/physics/conservation_sentry.gd")

signal observables_updated(norm: float, x_mean: float, energy: float, transmission: float, reflection: float)
signal barrier_tunneling_analyzed(analytical_t: float, empirical_t: float, relative_error: float)

enum SimulationDimension {
	DIMENSION_1D = 1,
	DIMENSION_2D = 2
}

enum PotentialType {
	FREE_SPACE = 0,
	RECTANGULAR_BARRIER = 1,
	HARMONIC_WELL = 2,
	STEP_POTENTIAL = 3,
	DOUBLE_SLIT = 4
}

# Grid Configuration (1D)
@export var grid_size_1d: int = 512
@export var domain_length_1d: float = 24.0 # x in [-12, 12]

# Grid Configuration (2D)
@export var grid_size_2d_x: int = 64
@export var grid_size_2d_z: int = 64
@export var domain_size_2d: Vector2 = Vector2(16.0, 16.0)

# Wavepacket Properties
@export var packet_center_x: float = -6.0
@export var packet_center_z: float = 0.0
@export var packet_width: float = 0.8
@export var packet_wavenumber_k0: float = 3.0 # Incident kinetic energy E = k0^2 / 2 = 4.5

# Barrier Parameters
@export var potential_type: PotentialType = PotentialType.RECTANGULAR_BARRIER
@export var barrier_height_v0: float = 6.0 # V0 > E causes tunneling
@export var barrier_width_d: float = 0.8
@export var barrier_center_x: float = 0.0
@export var harmonic_omega: float = 1.0
@export var slit_width: float = 0.8
@export var slit_separation: float = 2.0

# Active Dimension & Visualization
@export var active_dimension: SimulationDimension = SimulationDimension.DIMENSION_1D
@export var height_visual_scale: float = 6.0
@export var is_simulation_enabled: bool = true

# Internal Subsystems
var time_controller: SimulationTimeController = null
var conservation_sentry: ConservationSentry = null

# Contiguous 1D Wavefunction Buffers
var psi_real_1d: PackedFloat32Array = PackedFloat32Array()
var psi_imag_1d: PackedFloat32Array = PackedFloat32Array()
var potential_1d: PackedFloat32Array = PackedFloat32Array()
var prob_density_1d: PackedFloat32Array = PackedFloat32Array()

# Contiguous 2D Wavefunction Buffers
var psi_real_2d: PackedFloat32Array = PackedFloat32Array()
var psi_imag_2d: PackedFloat32Array = PackedFloat32Array()
var potential_2d: PackedFloat32Array = PackedFloat32Array()
var prob_density_2d: PackedFloat32Array = PackedFloat32Array()

# Visualizer Mesh Nodes
var mesh_instance_1d: MeshInstance3D = null
var immediate_mesh_1d: ImmediateMesh = null
var mesh_instance_2d: MeshInstance3D = null
var array_mesh_2d: ArrayMesh = null
var barrier_mesh_instance: MeshInstance3D = null

func set_simulation_active(val: bool) -> void:
	is_simulation_enabled = val
	if mesh_instance_1d and is_instance_valid(mesh_instance_1d):
		mesh_instance_1d.visible = val and (active_dimension == SimulationDimension.DIMENSION_1D)
	if mesh_instance_2d and is_instance_valid(mesh_instance_2d):
		mesh_instance_2d.visible = val and (active_dimension == SimulationDimension.DIMENSION_2D)
	if barrier_mesh_instance and is_instance_valid(barrier_mesh_instance):
		barrier_mesh_instance.visible = val

# Precomputed 2D mesh index cache
var _mesh_indices_2d: PackedInt32Array = PackedInt32Array()

# Invariant & Telemetry State
var initial_packet_norm: float = 1.0
var current_norm: float = 1.0
var mean_position_x: float = 0.0
var expectation_energy: float = 0.0
var transmission_coeff: float = 0.0
var reflection_coeff: float = 0.0
var analytical_transmission: float = 0.0
var telemetry_timer: float = 0.0
const TELEMETRY_INTERVAL: float = 0.1

func get_module_id() -> String:
	return "quantum_wavepacket"

func get_module_name() -> String:
	return "Quantum Wavepacket Propagation Module"

func get_action_bindings() -> Array[Dictionary]:
	return [
		{"action": "reset_wavepacket", "label": "Reset Wavepacket", "default_key": KEY_R, "description": "Re-initializes Gaussian wavepacket"},
		{"action": "cycle_potential", "label": "Cycle Potential Type", "default_key": KEY_B, "description": "Toggles Barrier, Well, Double-Slit, Free"},
		{"action": "increase_barrier", "label": "Increase Barrier Height", "default_key": KEY_UP, "description": "Increases V0"},
		{"action": "decrease_barrier", "label": "Decrease Barrier Height", "default_key": KEY_DOWN, "description": "Decreases V0"},
		{"action": "toggle_dimension", "label": "Toggle 1D/2D View", "default_key": KEY_M, "description": "Switches between 1D ribbon and 2D surface"}
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
	_rebuild_potential()
	reset_simulation()
	set_simulation_active(false)
	
	return true

func cleanup() -> void:
	if time_controller and time_controller.sim_tick.is_connected(_on_sim_tick):
		time_controller.sim_tick.disconnect(_on_sim_tick)
	
	time_controller = null
	conservation_sentry = null
	
	if mesh_instance_1d and is_instance_valid(mesh_instance_1d):
		mesh_instance_1d.queue_free()
		mesh_instance_1d = null
	
	if mesh_instance_2d and is_instance_valid(mesh_instance_2d):
		mesh_instance_2d.queue_free()
		mesh_instance_2d = null
	
	if barrier_mesh_instance and is_instance_valid(barrier_mesh_instance):
		barrier_mesh_instance.queue_free()
		barrier_mesh_instance = null
	
	super.cleanup()

# ==============================================================================
# VISUALIZER NODES SETUP
# ==============================================================================

func _setup_visualizers() -> void:
	# 1. 1D ImmediateMesh Ribbon
	mesh_instance_1d = MeshInstance3D.new()
	mesh_instance_1d.name = "QuantumRibbon1D"
	immediate_mesh_1d = ImmediateMesh.new()
	mesh_instance_1d.mesh = immediate_mesh_1d
	
	var mat_1d: StandardMaterial3D = StandardMaterial3D.new()
	mat_1d.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat_1d.vertex_color_use_as_albedo = true
	mat_1d.cull_mode = BaseMaterial3D.CULL_DISABLED
	mesh_instance_1d.material_override = mat_1d
	add_child(mesh_instance_1d)
	
	# 2. 2D ArrayMesh Surface
	mesh_instance_2d = MeshInstance3D.new()
	mesh_instance_2d.name = "QuantumSurface2D"
	array_mesh_2d = ArrayMesh.new()
	mesh_instance_2d.mesh = array_mesh_2d
	
	var mat_2d: StandardMaterial3D = StandardMaterial3D.new()
	mat_2d.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat_2d.vertex_color_use_as_albedo = true
	mat_2d.cull_mode = BaseMaterial3D.CULL_DISABLED
	mesh_instance_2d.material_override = mat_2d
	add_child(mesh_instance_2d)
	
	# 3. Translucent Barrier Visualizer
	barrier_mesh_instance = MeshInstance3D.new()
	barrier_mesh_instance.name = "BarrierVisualizer"
	var b_box: BoxMesh = BoxMesh.new()
	b_box.size = Vector3(barrier_width_d, 2.0, 4.0)
	barrier_mesh_instance.mesh = b_box
	var b_mat: StandardMaterial3D = StandardMaterial3D.new()
	b_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	b_mat.albedo_color = Color(1.0, 0.2, 0.2, 0.35)
	barrier_mesh_instance.material_override = b_mat
	barrier_mesh_instance.position = Vector3(barrier_center_x, 1.0, 0.0)
	add_child(barrier_mesh_instance)
	
	_precalculate_2d_mesh_indices()
	_update_dimension_visibility()

func _precalculate_2d_mesh_indices() -> void:
	_mesh_indices_2d.clear()
	var nx: int = grid_size_2d_x
	var nz: int = grid_size_2d_z
	
	for z in range(nz - 1):
		for x in range(nx - 1):
			var i0: int = z * nx + x
			var i1: int = i0 + 1
			var i2: int = (z + 1) * nx + x
			var i3: int = i2 + 1
			
			# Triangle 1
			_mesh_indices_2d.append(i0)
			_mesh_indices_2d.append(i2)
			_mesh_indices_2d.append(i1)
			# Triangle 2
			_mesh_indices_2d.append(i1)
			_mesh_indices_2d.append(i2)
			_mesh_indices_2d.append(i3)

func _update_dimension_visibility() -> void:
	if mesh_instance_1d:
		mesh_instance_1d.visible = (active_dimension == SimulationDimension.DIMENSION_1D)
	if mesh_instance_2d:
		mesh_instance_2d.visible = (active_dimension == SimulationDimension.DIMENSION_2D)
	if barrier_mesh_instance:
		barrier_mesh_instance.visible = (potential_type != PotentialType.FREE_SPACE)

# ==============================================================================
# STATE INITIALIZATION & POTENTIAL SETUP
# ==============================================================================

func reset_simulation() -> void:
	_rebuild_potential()
	
	if active_dimension == SimulationDimension.DIMENSION_1D:
		initialize_gaussian_wavepacket(packet_center_x, packet_width, packet_wavenumber_k0)
	else:
		initialize_2d_gaussian(packet_center_x, packet_center_z, packet_width, packet_wavenumber_k0, 0.0)
	
	initial_packet_norm = compute_norm()
	current_norm = initial_packet_norm
	
	if conservation_sentry:
		conservation_sentry.register_system(1.0, Vector3(packet_wavenumber_k0, 0, 0))
	
	_compute_analytical_transmission()
	_update_visualization()

func _rebuild_potential() -> void:
	# 1D Potential Buffer
	potential_1d.resize(grid_size_1d)
	var dx1: float = domain_length_1d / float(grid_size_1d - 1)
	var x_start1: float = -domain_length_1d * 0.5
	var d_half: float = barrier_width_d * 0.5
	
	for j in range(grid_size_1d):
		var x: float = x_start1 + float(j) * dx1
		var v: float = 0.0
		match potential_type:
			PotentialType.FREE_SPACE:
				v = 0.0
			PotentialType.RECTANGULAR_BARRIER:
				if absf(x - barrier_center_x) <= d_half:
					v = barrier_height_v0
			PotentialType.HARMONIC_WELL:
				v = 0.5 * harmonic_omega * harmonic_omega * x * x
			PotentialType.STEP_POTENTIAL:
				if x >= barrier_center_x:
					v = barrier_height_v0
			PotentialType.DOUBLE_SLIT:
				# 1D single barrier representation
				if absf(x - barrier_center_x) <= d_half:
					v = barrier_height_v0
		potential_1d[j] = v
	
	# 2D Potential Buffer
	var total_2d: int = grid_size_2d_x * grid_size_2d_z
	potential_2d.resize(total_2d)
	var dx2: float = domain_size_2d.x / float(grid_size_2d_x - 1)
	var dz2: float = domain_size_2d.y / float(grid_size_2d_z - 1)
	var x_start2: float = -domain_size_2d.x * 0.5
	var z_start2: float = -domain_size_2d.y * 0.5
	var slit_h: float = slit_width * 0.5
	var slit_sep_h: float = slit_separation * 0.5
	
	for z in range(grid_size_2d_z):
		var z_pos: float = z_start2 + float(z) * dz2
		var row: int = z * grid_size_2d_x
		for x in range(grid_size_2d_x):
			var x_pos: float = x_start2 + float(x) * dx2
			var idx: int = row + x
			var v: float = 0.0
			
			match potential_type:
				PotentialType.FREE_SPACE:
					v = 0.0
				PotentialType.RECTANGULAR_BARRIER:
					if absf(x_pos - barrier_center_x) <= d_half:
						v = barrier_height_v0
				PotentialType.HARMONIC_WELL:
					v = 0.5 * harmonic_omega * harmonic_omega * (x_pos * x_pos + z_pos * z_pos)
				PotentialType.STEP_POTENTIAL:
					if x_pos >= barrier_center_x:
						v = barrier_height_v0
				PotentialType.DOUBLE_SLIT:
					if absf(x_pos - barrier_center_x) <= d_half:
						# In barrier wall: slits are apertures where V = 0
						var in_slit1: bool = absf(z_pos - slit_sep_h) <= slit_h
						var in_slit2: bool = absf(z_pos + slit_sep_h) <= slit_h
						if not (in_slit1 or in_slit2):
							v = barrier_height_v0
			
			potential_2d[idx] = v
	
	# Update barrier visualizer transform
	if barrier_mesh_instance:
		var b_box: BoxMesh = barrier_mesh_instance.mesh as BoxMesh
		if b_box:
			b_box.size = Vector3(barrier_width_d, maxf(1.0, barrier_height_v0 * 0.2), 6.0)
		barrier_mesh_instance.position = Vector3(barrier_center_x, b_box.size.y * 0.5 if b_box else 0.5, 0.0)

func initialize_gaussian_wavepacket(
	x0: float = -6.0,
	sigma: float = 0.8,
	k0: float = 3.0
) -> void:
	packet_center_x = x0
	packet_width = sigma
	packet_wavenumber_k0 = k0
	
	var n: int = grid_size_1d
	psi_real_1d.resize(n)
	psi_imag_1d.resize(n)
	prob_density_1d.resize(n)
	
	var dx: float = domain_length_1d / float(n - 1)
	var x_start: float = -domain_length_1d * 0.5
	var two_sigma_sq: float = 2.0 * sigma * sigma
	var four_sigma_sq: float = 4.0 * sigma * sigma
	
	# Normalization prefactor: A = (2 * PI * sigma^2)^(-1/4)
	var prefactor: float = pow(PI * two_sigma_sq, -0.25)
	
	for j in range(n):
		var x: float = x_start + float(j) * dx
		var diff: float = x - x0
		var envelope: float = prefactor * exp(-(diff * diff) / four_sigma_sq)
		var phase: float = k0 * x
		
		psi_real_1d[j] = envelope * cos(phase)
		psi_imag_1d[j] = envelope * sin(phase)
		prob_density_1d[j] = envelope * envelope
	
	# Enforce Dirichlet boundaries at endpoints
	psi_real_1d[0] = 0.0
	psi_imag_1d[0] = 0.0
	psi_real_1d[n - 1] = 0.0
	psi_imag_1d[n - 1] = 0.0
	
	# Normalize exactly: sum(|psi|^2) * dx = 1.0
	var norm_val: float = compute_norm()
	if norm_val > 0.0:
		var inv_sqrt_norm: float = 1.0 / sqrt(norm_val)
		for j in range(n):
			psi_real_1d[j] *= inv_sqrt_norm
			psi_imag_1d[j] *= inv_sqrt_norm
			prob_density_1d[j] = psi_real_1d[j] * psi_real_1d[j] + psi_imag_1d[j] * psi_imag_1d[j]

func initialize_2d_gaussian(
	x0: float = -4.0,
	z0: float = 0.0,
	sigma: float = 0.8,
	kx: float = 3.0,
	kz: float = 0.0
) -> void:
	packet_center_x = x0
	packet_center_z = z0
	packet_width = sigma
	packet_wavenumber_k0 = kx
	
	var nx: int = grid_size_2d_x
	var nz: int = grid_size_2d_z
	var total: int = nx * nz
	psi_real_2d.resize(total)
	psi_imag_2d.resize(total)
	prob_density_2d.resize(total)
	
	var dx: float = domain_size_2d.x / float(nx - 1)
	var dz: float = domain_size_2d.y / float(nz - 1)
	var x_start: float = -domain_size_2d.x * 0.5
	var z_start: float = -domain_size_2d.y * 0.5
	var four_sigma_sq: float = 4.0 * sigma * sigma
	
	var prefactor: float = 1.0 / (sqrt(TAU) * sigma)
	
	for z in range(nz):
		var z_pos: float = z_start + float(z) * dz
		var diff_z: float = z_pos - z0
		var row: int = z * nx
		
		for x in range(nx):
			var x_pos: float = x_start + float(x) * dx
			var diff_x: float = x_pos - x0
			var r_sq: float = diff_x * diff_x + diff_z * diff_z
			var envelope: float = prefactor * exp(-r_sq / four_sigma_sq)
			var phase: float = kx * x_pos + kz * z_pos
			var idx: int = row + x
			
			if x == 0 or x == nx - 1 or z == 0 or z == nz - 1:
				psi_real_2d[idx] = 0.0
				psi_imag_2d[idx] = 0.0
				prob_density_2d[idx] = 0.0
			else:
				psi_real_2d[idx] = envelope * cos(phase)
				psi_imag_2d[idx] = envelope * sin(phase)
				prob_density_2d[idx] = envelope * envelope
	
	# Normalize 2D
	var norm_val: float = compute_norm()
	if norm_val > 0.0:
		var inv_sqrt_norm: float = 1.0 / sqrt(norm_val)
		for i in range(total):
			psi_real_2d[i] *= inv_sqrt_norm
			psi_imag_2d[i] *= inv_sqrt_norm
			prob_density_2d[i] = psi_real_2d[i] * psi_real_2d[i] + psi_imag_2d[i] * psi_imag_2d[i]

# ==============================================================================
# SIMULATION TICK & NUMERICAL EVOLUTION
# ==============================================================================

func _on_sim_tick(dt: float, _sim_time: float) -> void:
	if not is_simulation_enabled or dt <= 0.0:
		return
	
	step_manual(dt)

func step_manual(dt: float) -> void:
	if active_dimension == SimulationDimension.DIMENSION_1D:
		_evolve_1d_cayley(dt)
		_update_prob_density_1d()
	else:
		_evolve_2d_staggered(dt)
		_update_prob_density_2d()
	
	_compute_observables()
	_update_visualization()
	
	telemetry_timer += dt
	if telemetry_timer >= TELEMETRY_INTERVAL:
		telemetry_timer = 0.0
		observables_updated.emit(current_norm, mean_position_x, expectation_energy, transmission_coeff, reflection_coeff)
		
		if potential_type == PotentialType.RECTANGULAR_BARRIER:
			var rel_err: float = 0.0
			if analytical_transmission > 1e-7:
				rel_err = absf(transmission_coeff - analytical_transmission) / analytical_transmission
			barrier_tunneling_analyzed.emit(analytical_transmission, transmission_coeff, rel_err)
		
		# Sentry audit: verify global phase U(1) invariance (norm conservation)
		if conservation_sentry:
			var norm_drift: float = absf(current_norm - 1.0)
			if norm_drift > conservation_sentry.energy_tolerance:
				conservation_sentry.conservation_warning.emit("quantum_norm", norm_drift)

# ==============================================================================
# 1D CAYLEY / CRANK-NICOLSON UNITARY TRIDIAGONAL SOLVER
# ==============================================================================

func _evolve_1d_cayley(dt: float) -> void:
	var n: int = grid_size_1d
	if n < 3:
		return
	
	var dx: float = domain_length_1d / float(n - 1)
	var alpha: float = dt / (4.0 * dx * dx) # Off-diagonal coupling beta = dt / (4*dx^2)
	
	# Auxiliary vectors for Thomas tridiagonal algorithm
	var cp_r: PackedFloat32Array = PackedFloat32Array()
	var cp_i: PackedFloat32Array = PackedFloat32Array()
	var dp_r: PackedFloat32Array = PackedFloat32Array()
	var dp_i: PackedFloat32Array = PackedFloat32Array()
	cp_r.resize(n)
	cp_i.resize(n)
	dp_r.resize(n)
	dp_i.resize(n)
	
	# 1. Compute RHS vector chi = (I - i*H*dt/2) psi^n
	var chi_r: PackedFloat32Array = PackedFloat32Array()
	var chi_i: PackedFloat32Array = PackedFloat32Array()
	chi_r.resize(n)
	chi_i.resize(n)
	
	for j in range(1, n - 1):
		var v_term: float = dt * potential_1d[j] * 0.5
		var diag_r: float = 1.0
		var diag_i: float = -(2.0 * alpha + v_term)
		
		# (+i * alpha) * (psi_{j-1} + psi_{j+1})
		var lap_r: float = -alpha * (psi_imag_1d[j - 1] + psi_imag_1d[j + 1])
		var lap_i: float = alpha * (psi_real_1d[j - 1] + psi_real_1d[j + 1])
		
		chi_r[j] = diag_r * psi_real_1d[j] - diag_i * psi_imag_1d[j] + lap_r
		chi_i[j] = diag_r * psi_imag_1d[j] + diag_i * psi_real_1d[j] + lap_i
	
	# 2. Forward Sweep of Thomas Algorithm
	# Boundary condition at j = 0: psi_0 = 0
	cp_r[0] = 0.0
	cp_i[0] = 0.0
	dp_r[0] = 0.0
	dp_i[0] = 0.0
	
	for j in range(1, n - 1):
		var v_term: float = dt * potential_1d[j] * 0.5
		
		# In tridiagonal system: a_j = -i*alpha, b_j = 1 + i*(2*alpha + v_term), c_j = -i*alpha
		# denom = b_j - a_j * cp_{j-1}
		# Note a_j * cp = (-i*alpha) * (cp_r + i*cp_i) = alpha * cp_i - i * alpha * cp_r
		var denom_r: float = 1.0 - alpha * cp_i[j - 1]
		var denom_i: float = (2.0 * alpha + v_term) + alpha * cp_r[j - 1]
		var denom_mag_sq: float = denom_r * denom_r + denom_i * denom_i
		if denom_mag_sq < 1e-24:
			denom_mag_sq = 1e-24
		
		# c_j = -i * alpha
		# cp_j = c_j / denom = (-alpha * denom_i - i * alpha * denom_r) / denom_mag_sq
		cp_r[j] = (-alpha * denom_i) / denom_mag_sq
		cp_i[j] = (-alpha * denom_r) / denom_mag_sq
		
		# num = chi_j - a_j * dp_{j-1}
		# a_j * dp = alpha * dp_i - i * alpha * dp_r
		var num_r: float = chi_r[j] - alpha * dp_i[j - 1]
		var num_i: float = chi_i[j] + alpha * dp_r[j - 1]
		
		# dp_j = num / denom
		dp_r[j] = (num_r * denom_r + num_i * denom_i) / denom_mag_sq
		dp_i[j] = (num_i * denom_r - num_r * denom_i) / denom_mag_sq
	
	# 3. Back Substitution
	# Boundary condition at j = n - 1: psi_{n-1} = 0
	psi_real_1d[n - 1] = 0.0
	psi_imag_1d[n - 1] = 0.0
	
	for j in range(n - 2, 0, -1):
		# psi_j = dp_j - cp_j * psi_{j+1}
		var next_r: float = psi_real_1d[j + 1]
		var next_i: float = psi_imag_1d[j + 1]
		var prod_r: float = cp_r[j] * next_r - cp_i[j] * next_i
		var prod_i: float = cp_r[j] * next_i + cp_i[j] * next_r
		
		psi_real_1d[j] = dp_r[j] - prod_r
		psi_imag_1d[j] = dp_i[j] - prod_i
	
	psi_real_1d[0] = 0.0
	psi_imag_1d[0] = 0.0

func _update_prob_density_1d() -> void:
	var n: int = grid_size_1d
	for j in range(n):
		var r: float = psi_real_1d[j]
		var i: float = psi_imag_1d[j]
		prob_density_1d[j] = r * r + i * i

# ==============================================================================
# 2D SYMPLECTIC STAGGERED-TIME LEAPFROG SOLVER
# ==============================================================================

func _evolve_2d_staggered(dt: float) -> void:
	var nx: int = grid_size_2d_x
	var nz: int = grid_size_2d_z
	var dx: float = domain_size_2d.x / float(nx - 1)
	var dz: float = domain_size_2d.y / float(nz - 1)
	var inv_dx2: float = 1.0 / (dx * dx)
	var inv_dz2: float = 1.0 / (dz * dz)
	
	# Substep A: Update Real part: psi_R(t + dt) = psi_R(t) + dt * H * psi_I(t + dt/2)
	for z in range(1, nz - 1):
		var row: int = z * nx
		for x in range(1, nx - 1):
			var idx: int = row + x
			var lap: float = (
				(psi_imag_2d[idx + 1] + psi_imag_2d[idx - 1] - 2.0 * psi_imag_2d[idx]) * inv_dx2 +
				(psi_imag_2d[idx + nx] + psi_imag_2d[idx - nx] - 2.0 * psi_imag_2d[idx]) * inv_dz2
			)
			var h_psi_i: float = -0.5 * lap + potential_2d[idx] * psi_imag_2d[idx]
			psi_real_2d[idx] += dt * h_psi_i
	
	# Substep B: Update Imaginary part: psi_I(t + 3dt/2) = psi_I(t + dt/2) - dt * H * psi_R(t + dt)
	for z in range(1, nz - 1):
		var row: int = z * nx
		for x in range(1, nx - 1):
			var idx: int = row + x
			var lap: float = (
				(psi_real_2d[idx + 1] + psi_real_2d[idx - 1] - 2.0 * psi_real_2d[idx]) * inv_dx2 +
				(psi_real_2d[idx + nx] + psi_real_2d[idx - nx] - 2.0 * psi_real_2d[idx]) * inv_dz2
			)
			var h_psi_r: float = -0.5 * lap + potential_2d[idx] * psi_real_2d[idx]
			psi_imag_2d[idx] -= dt * h_psi_r

func _update_prob_density_2d() -> void:
	var total: int = grid_size_2d_x * grid_size_2d_z
	for i in range(total):
		var r: float = psi_real_2d[i]
		var im: float = psi_imag_2d[i]
		prob_density_2d[i] = r * r + im * im

# ==============================================================================
# OBSERVABLES & INVARIANTS COMPUTATION
# ==============================================================================

func compute_norm() -> float:
	if active_dimension == SimulationDimension.DIMENSION_1D:
		var n: int = grid_size_1d
		if n == 0 or prob_density_1d.size() != n:
			return 0.0
		var dx: float = domain_length_1d / float(n - 1)
		var total_sum: float = 0.0
		for j in range(n):
			total_sum += prob_density_1d[j]
		return total_sum * dx
	else:
		var total: int = grid_size_2d_x * grid_size_2d_z
		if total == 0 or prob_density_2d.size() != total:
			return 0.0
		var dx: float = domain_size_2d.x / float(grid_size_2d_x - 1)
		var dz: float = domain_size_2d.y / float(grid_size_2d_z - 1)
		var total_sum: float = 0.0
		for i in range(total):
			total_sum += prob_density_2d[i]
		return total_sum * (dx * dz)

func compute_mean_position() -> float:
	if active_dimension == SimulationDimension.DIMENSION_1D:
		var n: int = grid_size_1d
		var dx: float = domain_length_1d / float(n - 1)
		var x_start: float = -domain_length_1d * 0.5
		var weighted_x: float = 0.0
		var total_prob: float = 0.0
		
		for j in range(n):
			var x: float = x_start + float(j) * dx
			var rho: float = prob_density_1d[j]
			weighted_x += x * rho
			total_prob += rho
		
		return weighted_x / maxf(1e-12, total_prob)
	else:
		var nx: int = grid_size_2d_x
		var nz: int = grid_size_2d_z
		var dx: float = domain_size_2d.x / float(nx - 1)
		var x_start: float = -domain_size_2d.x * 0.5
		var weighted_x: float = 0.0
		var total_prob: float = 0.0
		
		for z in range(nz):
			var row: int = z * nx
			for x in range(nx):
				var x_pos: float = x_start + float(x) * dx
				var rho: float = prob_density_2d[row + x]
				weighted_x += x_pos * rho
				total_prob += rho
		
		return weighted_x / maxf(1e-12, total_prob)

func compute_expectation_energy() -> float:
	if active_dimension == SimulationDimension.DIMENSION_1D:
		var n: int = grid_size_1d
		if n < 3:
			return 0.0
		var dx: float = domain_length_1d / float(n - 1)
		var inv_two_dx: float = 1.0 / (2.0 * dx)
		var e_total: float = 0.0
		
		for j in range(1, n - 1):
			# Kinetic energy density: 0.5 * |d(psi)/dx|^2
			var d_real: float = (psi_real_1d[j + 1] - psi_real_1d[j - 1]) * inv_two_dx
			var d_imag: float = (psi_imag_1d[j + 1] - psi_imag_1d[j - 1]) * inv_two_dx
			var t_dens: float = 0.5 * (d_real * d_real + d_imag * d_imag)
			
			# Potential energy density: V(x) * |psi(x)|^2
			var v_dens: float = potential_1d[j] * prob_density_1d[j]
			
			e_total += (t_dens + v_dens) * dx
		
		return e_total
	else:
		return 0.0

func compute_transmission() -> float:
	var x_right: float = barrier_center_x + barrier_width_d * 0.5
	if active_dimension == SimulationDimension.DIMENSION_1D:
		var n: int = grid_size_1d
		var dx: float = domain_length_1d / float(n - 1)
		var x_start: float = -domain_length_1d * 0.5
		var sum_trans: float = 0.0
		
		for j in range(n):
			var x: float = x_start + float(j) * dx
			if x > x_right:
				sum_trans += prob_density_1d[j]
		
		var current_n: float = compute_norm()
		return (sum_trans * dx) / maxf(1e-12, current_n)
	else:
		var nx: int = grid_size_2d_x
		var nz: int = grid_size_2d_z
		var dx: float = domain_size_2d.x / float(nx - 1)
		var dz: float = domain_size_2d.y / float(nz - 1)
		var x_start: float = -domain_size_2d.x * 0.5
		var sum_trans: float = 0.0
		
		for z in range(nz):
			var row: int = z * nx
			for x in range(nx):
				var x_pos: float = x_start + float(x) * dx
				if x_pos > x_right:
					sum_trans += prob_density_2d[row + x]
		
		var current_n: float = compute_norm()
		return (sum_trans * dx * dz) / maxf(1e-12, current_n)

func compute_reflection() -> float:
	var x_left: float = barrier_center_x - barrier_width_d * 0.5
	if active_dimension == SimulationDimension.DIMENSION_1D:
		var n: int = grid_size_1d
		var dx: float = domain_length_1d / float(n - 1)
		var x_start: float = -domain_length_1d * 0.5
		var sum_ref: float = 0.0
		
		for j in range(n):
			var x: float = x_start + float(j) * dx
			if x < x_left:
				sum_ref += prob_density_1d[j]
		
		var current_n: float = compute_norm()
		return (sum_ref * dx) / maxf(1e-12, current_n)
	else:
		return 1.0 - compute_transmission()

func _compute_observables() -> void:
	current_norm = compute_norm()
	mean_position_x = compute_mean_position()
	expectation_energy = compute_expectation_energy()
	transmission_coeff = compute_transmission()
	reflection_coeff = compute_reflection()

func _compute_analytical_transmission() -> void:
	if potential_type != PotentialType.RECTANGULAR_BARRIER:
		analytical_transmission = 1.0
		return
	
	var e_k: float = 0.5 * packet_wavenumber_k0 * packet_wavenumber_k0
	var v0: float = barrier_height_v0
	var d: float = barrier_width_d
	
	if e_k <= 0.0 or v0 <= 0.0:
		analytical_transmission = 1.0
		return
	
	if v0 > e_k:
		# Quantum tunneling regime: T = [1 + (V0^2 * sinh^2(kappa*d)) / (4*E*(V0 - E))]^-1
		var kappa: float = sqrt(2.0 * (v0 - e_k))
		var sinh_term: float = sinh(kappa * d)
		var denom: float = 1.0 + (v0 * v0 * sinh_term * sinh_term) / (4.0 * e_k * (v0 - e_k))
		analytical_transmission = 1.0 / denom
	elif is_equal_approx(v0, e_k):
		analytical_transmission = 1.0 / (1.0 + 0.5 * v0 * d * d)
	else:
		# Above-barrier transmission resonance
		var k1: float = sqrt(2.0 * (e_k - v0))
		var sin_term: float = sin(k1 * d)
		var denom: float = 1.0 + (v0 * v0 * sin_term * sin_term) / (4.0 * e_k * (e_k - v0))
		analytical_transmission = 1.0 / denom

func get_analytical_transmission() -> float:
	return analytical_transmission

# ==============================================================================
# VISUALIZATION RENDERING (HEIGHT + PHASE COLOR)
# ==============================================================================

func _update_visualization() -> void:
	if active_dimension == SimulationDimension.DIMENSION_1D:
		_render_1d_ribbon()
	else:
		_render_2d_surface()

func _render_1d_ribbon() -> void:
	if not immediate_mesh_1d:
		return
	
	var n: int = grid_size_1d
	if n < 2 or prob_density_1d.size() != n:
		return
	
	immediate_mesh_1d.clear_surfaces()
	immediate_mesh_1d.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
	
	var dx: float = domain_length_1d / float(n - 1)
	var x_start: float = -domain_length_1d * 0.5
	
	for j in range(n):
		var x: float = x_start + float(j) * dx
		var rho: float = prob_density_1d[j]
		var phase: float = atan2(psi_imag_1d[j], psi_real_1d[j]) # [-PI, PI]
		var hue: float = fposmod((phase + PI) / TAU, 1.0)
		var col: Color = Color.from_hsv(hue, 0.90, 1.0)
		
		# Upper vertex (probability density peak)
		immediate_mesh_1d.surface_set_color(col)
		immediate_mesh_1d.surface_add_vertex(Vector3(x, rho * height_visual_scale, 0.0))
		
		# Lower vertex (baseline)
		immediate_mesh_1d.surface_set_color(col * 0.25)
		immediate_mesh_1d.surface_add_vertex(Vector3(x, 0.0, 0.0))
	
	immediate_mesh_1d.surface_end()

func _render_2d_surface() -> void:
	if not array_mesh_2d:
		return
	
	var nx: int = grid_size_2d_x
	var nz: int = grid_size_2d_z
	var total: int = nx * nz
	if prob_density_2d.size() != total:
		return
	
	var dx: float = domain_size_2d.x / float(nx - 1)
	var dz: float = domain_size_2d.y / float(nz - 1)
	var x_start: float = -domain_size_2d.x * 0.5
	var z_start: float = -domain_size_2d.y * 0.5
	
	var vertices: PackedVector3Array = PackedVector3Array()
	var colors: PackedColorArray = PackedColorArray()
	vertices.resize(total)
	colors.resize(total)
	
	for z in range(nz):
		var z_pos: float = z_start + float(z) * dz
		var row: int = z * nx
		for x in range(nx):
			var idx: int = row + x
			var x_pos: float = x_start + float(x) * dx
			var rho: float = prob_density_2d[idx]
			var phase: float = atan2(psi_imag_2d[idx], psi_real_2d[idx])
			var hue: float = fposmod((phase + PI) / TAU, 1.0)
			
			vertices[idx] = Vector3(x_pos, rho * height_visual_scale, z_pos)
			colors[idx] = Color.from_hsv(hue, 0.85, 1.0)
	
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_INDEX] = _mesh_indices_2d
	
	array_mesh_2d.clear_surfaces()
	array_mesh_2d.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)

# ==============================================================================
# INTERACTIVE CONTROLS
# ==============================================================================

func set_potential_type(p_type: int) -> void:
	potential_type = p_type as PotentialType
	_rebuild_potential()
	_compute_analytical_transmission()
	_update_dimension_visibility()

func cycle_potential_type() -> void:
	var next_val: int = (int(potential_type) + 1) % 5
	set_potential_type(next_val)

func set_dimension(dim: int) -> void:
	active_dimension = dim as SimulationDimension
	_update_dimension_visibility()
	reset_simulation()


func toggle_dimension() -> void:
	if active_dimension == SimulationDimension.DIMENSION_1D:
		set_dimension(SimulationDimension.DIMENSION_2D)
	else:
		set_dimension(SimulationDimension.DIMENSION_1D)

func set_barrier_height(v0: float) -> void:
	barrier_height_v0 = maxf(0.0, v0)
	_rebuild_potential()
	_compute_analytical_transmission()

func set_barrier_width(width: float) -> void:
	barrier_width_d = maxf(0.01, width)
	_rebuild_potential()
	_compute_analytical_transmission()
