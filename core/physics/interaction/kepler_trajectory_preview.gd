class_name KeplerTrajectoryPreview
extends MeshInstance3D

## Conic-section 3D orbital trajectory preview for CelestialSpawnerTool in UniCORE.
## Predicts instantaneous closed (ellipse/circle) or open (hyperbola) Keplerian orbits
## from position and velocity state vectors in real time.

@export var segments: int = 120
@export var default_color: Color = Color(0.2, 0.9, 0.4, 0.85)

var _imm_mesh: ImmediateMesh
var _material: StandardMaterial3D

func _ready() -> void:
	_imm_mesh = ImmediateMesh.new()
	mesh = _imm_mesh
	_material = StandardMaterial3D.new()
	_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_material.vertex_color_use_as_albedo = true
	_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material_override = _material
	visible = false

## Clears and hides the orbital preview line.
func clear_orbit() -> void:
	if _imm_mesh:
		_imm_mesh.clear_surfaces()
	visible = false

## Updates the predicted Keplerian orbit line strip.
## [param primary_pos]: 3D coordinates of the central massive attractor (e.g. Star).
## [param body_pos]: 3D coordinates of the orbiting body.
## [param velocity]: 3D initial velocity vector.
## [param mu]: Standard gravitational parameter G * M_primary.
func update_orbit(primary_pos: Vector3, body_pos: Vector3, velocity: Vector3, mu: float) -> void:
	if mu <= 0.0:
		clear_orbit()
		return
	
	var rel_pos: Vector3 = body_pos - primary_pos
	var r_mag: float = rel_pos.length()
	var v_mag: float = velocity.length()
	if r_mag < 0.01 or v_mag < 0.001:
		clear_orbit()
		return
	
	var h_vec: Vector3 = rel_pos.cross(velocity)
	var h_mag: float = h_vec.length()
	if h_mag < 0.0001:
		# Degenerate radial plunge
		clear_orbit()
		return
	
	# Eccentricity vector e = (v x h)/mu - r/|r|
	var e_vec: Vector3 = (velocity.cross(h_vec) / mu) - (rel_pos / r_mag)
	var e: float = e_vec.length()
	var p: float = (h_mag * h_mag) / mu # Semi-latus rectum
	
	# Perifocal coordinate frame basis (P in direction of periapsis, W along angular momentum)
	var P: Vector3 = e_vec / e if e > 0.0001 else rel_pos / r_mag
	var W: Vector3 = h_vec / h_mag
	var Q: Vector3 = W.cross(P).normalized()
	
	var points: Array[Vector3] = []
	
	if e < 0.99:
		# Elliptical / Circular Orbit
		var angle_step: float = TAU / float(segments)
		for i in range(segments + 1):
			var theta: float = float(i) * angle_step
			var denom: float = 1.0 + e * cos(theta)
			if denom > 0.001:
				var r: float = p / denom
				var orb_pos: Vector3 = P * (r * cos(theta)) + Q * (r * sin(theta))
				points.append(primary_pos + orb_pos)
	else:
		# Hyperbolic / Parabolic Escape Trajectory
		var max_theta: float = acos(clampf(-1.0 / maxf(e, 1.001), -0.999, 0.999)) - 0.1
		var angle_step: float = (max_theta * 2.0) / float(segments)
		for i in range(segments + 1):
			var theta: float = -max_theta + float(i) * angle_step
			var denom: float = 1.0 + e * cos(theta)
			if denom > 0.001:
				var r: float = p / denom
				var orb_pos: Vector3 = P * (r * cos(theta)) + Q * (r * sin(theta))
				points.append(primary_pos + orb_pos)
	
	if points.size() < 2:
		clear_orbit()
		return
	
	visible = true
	_imm_mesh.clear_surfaces()
	_imm_mesh.surface_begin(Mesh.PRIMITIVE_LINE_STRIP, _material)
	var orbit_col: Color = default_color if e < 1.0 else Color(1.0, 0.4, 0.2, 0.85)
	for pt in points:
		_imm_mesh.surface_set_color(orbit_col)
		_imm_mesh.surface_add_vertex(pt)
	_imm_mesh.surface_end()
