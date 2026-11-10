extends SceneTree

func _init() -> void:
	var m_sun: float = 100.0
	var g_const: float = 1.0
	var c_sim: float = 25.0
	var c_sq: float = c_sim * c_sim
	var a_axis: float = 4.0
	var ecc: float = 0.5
	var r_p: float = a_axis * (1.0 - ecc) # 2.0
	var v_p: float = sqrt(g_const * m_sun * (1.0 + ecc) / (a_axis * (1.0 - ecc))) # 8.660254
	
	var analytical_delta_phi: float = (6.0 * PI * g_const * m_sun) / (a_axis * (1.0 - ecc * ecc) * c_sq)
	print("Analytical 1PN Precession: %.5f rad (%.2f deg)" % [analytical_delta_phi, rad_to_deg(analytical_delta_phi)])
	
	for sign_flip in [1.0, -1.0]:
		var r := Vector3(r_p, 0.0, 0.0)
		var v := Vector3(0.0, v_p, 0.0)
		var dt: float = 0.0005
		var t_orb: float = 2.0 * PI * sqrt(pow(a_axis, 3.0) / (g_const * m_sun))
		var total_steps: int = int((t_orb * 3.5) / dt)
		
		var prev_dist: float = r_p
		var prev_dr: float = 0.0
		var perihelion_angles: Array[float] = []
		
		for s in range(total_steps):
			var r_vec: Vector3 = -r # towards sun
			var dist: float = r.length()
			var dist3: float = dist * dist * dist
			var a_newt: Vector3 = r_vec * (g_const * m_sun / dist3)
			
			var radial_coeff: float = (4.0 * g_const * m_sun / dist) - v.length_squared()
			var cross_coeff: float = 4.0 * r_vec.dot(v)
			var prefactor: float = (g_const * m_sun) / (c_sq * dist3)
			var a_1pn: Vector3 = (r_vec * radial_coeff + v * cross_coeff) * prefactor * sign_flip
			var a_eff: Vector3 = a_newt + a_1pn
			
			# Relativistic velocity limit tensor
			var v_sq_tot: float = v.length_squared()
			var beta_sq: float = clampf(v_sq_tot / c_sq, 0.0, 0.999)
			var gamma: float = 1.0 / sqrt(1.0 - beta_sq)
			var a_rel: Vector3 = (a_eff - (v * (a_eff.dot(v) / c_sq))) / gamma
			
			var a0: Vector3 = a_rel
			r += v * dt + a0 * (0.5 * dt * dt)
			
			var r_vec_new: Vector3 = -r
			var dist_new: float = r.length()
			var dist3_new: float = dist_new * dist_new * dist_new
			var a_newt_new: Vector3 = r_vec_new * (g_const * m_sun / dist3_new)
			var rc: float = (4.0 * g_const * m_sun / dist_new) - v.length_squared()
			var cc: float = 4.0 * r_vec_new.dot(v)
			var pf: float = (g_const * m_sun) / (c_sq * dist3_new)
			var a_1pn_new: Vector3 = (r_vec_new * rc + v * cc) * pf * sign_flip
			var a_eff_new: Vector3 = a_newt_new + a_1pn_new
			
			var beta_sq_new: float = clampf(v.length_squared() / c_sq, 0.0, 0.999)
			var gamma_new: float = 1.0 / sqrt(1.0 - beta_sq_new)
			var a_rel_new: Vector3 = (a_eff_new - (v * (a_eff_new.dot(v) / c_sq))) / gamma_new
			v += (a0 + a_rel_new) * (0.5 * dt)
			
			var cur_dist: float = r.length()
			var dr: float = cur_dist - prev_dist
			if s > 200 and prev_dr < 0.0 and dr >= 0.0 and cur_dist < 3.0:
				var phi: float = atan2(r.y, r.x)
				perihelion_angles.append(phi)
			prev_dr = dr
			prev_dist = cur_dist
		
		print("Sign %+.1f: Detected %d perihelia: %s" % [sign_flip, perihelion_angles.size(), str(perihelion_angles)])
		if perihelion_angles.size() >= 2:
			var d_phi: float = perihelion_angles[1] - perihelion_angles[0]
			print("  Raw d_phi = %.5f rad (%.2f deg)" % [d_phi, rad_to_deg(d_phi)])
	quit(0)
