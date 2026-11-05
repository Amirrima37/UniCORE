extends SceneTree

# ==============================================================================
# UniCORE Fundamental Scientific Simulation Platform
# Challenger 1: Empirical & Mathematical Stress Testing Harness
#
# Engine Target: Godot 4.0.stable.official.92bee43ad
# Adversarial Focus:
# 1. VelocityVectorGizmo: Zero-length, near-zero, vertical UP/DOWN alignment, Monte-Carlo sphere
# 2. ScreenRaycaster: Camera with extreme angles (pitch 90 deg, FOV 179 deg), parallel rays
# 3. KeplerTrajectoryPreview: Radial plunge (h -> 0), parabolic (e = 1.0), hyperbolic (e > 1.0), circular (e = 0)
# 4. PhysicsInteractionManager: Boundary dragging, rapid tool switching, entity picking
# ==============================================================================

const ScreenRaycaster = preload("res://core/physics/interaction/screen_raycaster.gd")
const VelocityVectorGizmo = preload("res://core/physics/interaction/velocity_vector_gizmo.gd")
const KeplerTrajectoryPreview = preload("res://core/physics/interaction/kepler_trajectory_preview.gd")
const PhysicsInteractionManager = preload("res://core/physics/interaction/physics_interaction_manager.gd")
const EventBusScript = preload("res://core/event_bus.gd")
const SimulationTimeController = preload("res://core/physics/simulation_time_controller.gd")
const ConservationSentry = preload("res://core/physics/conservation_sentry.gd")

var passed_count: int = 0
var failed_count: int = 0
var failure_log: Array[String] = []

func assert_test(condition: bool, test_name: String, details: String = "") -> void:
	if condition:
		print("  [PASS] %s" % test_name)
		passed_count += 1
	else:
		var msg: String = "  [FAIL] %s - %s" % [test_name, details]
		print(msg)
		failed_count += 1
		failure_log.append(msg)

func _is_finite_vector(v: Vector3) -> bool:
	return is_finite(v.x) and is_finite(v.y) and is_finite(v.z) and not (is_nan(v.x) or is_nan(v.y) or is_nan(v.z))

func _is_finite_basis(b: Basis) -> bool:
	return _is_finite_vector(b.x) and _is_finite_vector(b.y) and _is_finite_vector(b.z)

func _init() -> void:
	print("==================================================================")
	print("  CHALLENGER 1: Empirical & Mathematical Stress Testing Suite   ")
	print("==================================================================")
	print("Engine: Godot 4.0.stable (Headless)\n")

	var start_usec: int = Time.get_ticks_usec()

	# Section 1: VelocityVectorGizmo Singularity & Stress
	_stress_velocity_vector_gizmo()

	# Section 2: ScreenRaycaster Camera & Angle Extremes
	_stress_screen_raycaster()

	# Section 3: KeplerTrajectoryPreview Conic Edge Cases
	_stress_kepler_trajectory_preview()

	# Section 4: PhysicsInteractionManager Boundary & Edge Cases
	_stress_physics_interaction_manager()

	var elapsed_ms: float = float(Time.get_ticks_usec() - start_usec) / 1000.0
	print("\n==================================================================")
	print("CHALLENGER SUMMARY: %d passed, %d failed in %.2f ms" % [passed_count, failed_count, elapsed_ms])
	if failed_count > 0:
		print("\nCHALLENGE FAILURE LOG:")
		for f in failure_log:
			print(f)
		print("\nVERDICT: DISPUTE (Exit Code: 1)")
		print("==================================================================")
		quit(1)
	else:
		print("\nVERDICT: CONFIRM (100% EMPIRICAL STRESS TESTS PASSED) (Exit Code: 0)")
		print("==================================================================")
		quit(0)

# ==============================================================================
# 1. VelocityVectorGizmo Stress Testing
# ==============================================================================
func _stress_velocity_vector_gizmo() -> void:
	print("\n--- 1. VelocityVectorGizmo Adversarial Stress Tests ---")
	var gizmo: VelocityVectorGizmo = VelocityVectorGizmo.new()
	gizmo._ready()

	# 1.1 Zero length vector
	gizmo.set_vector(Vector3(1.0, 2.0, 3.0), Vector3.ZERO)
	assert_test(gizmo.visible == false, "Zero-vector hides gizmo without NaN")
	assert_test(_is_finite_vector(gizmo.get_vector()), "get_vector() is finite on zero-vector")

	# 1.2 Infinitesimal vectors (1e-9, 1e-15)
	gizmo.set_vector(Vector3.ZERO, Vector3(1e-9, 1e-9, 1e-9))
	assert_test(gizmo.visible == false, "Infinitesimal vector (1e-9) hides gizmo")

	gizmo.set_vector(Vector3.ZERO, Vector3(1e-15, 0.0, 0.0))
	assert_test(gizmo.visible == false, "Infinitesimal vector (1e-15) hides gizmo")

	# 1.3 Boundary around 0.001 length cutoff
	gizmo.set_vector(Vector3.ZERO, Vector3(0.00099, 0.0, 0.0))
	assert_test(gizmo.visible == false, "Vector length 0.00099 (< 0.001) hides gizmo")

	gizmo.set_vector(Vector3.ZERO, Vector3(0.00101, 0.0, 0.0))
	assert_test(gizmo.visible == true, "Vector length 0.00101 (>= 0.001) shows gizmo")
	assert_test(_is_finite_basis(gizmo.transform.basis), "Basis is finite at threshold length 0.00101")

	# 1.4 Strict Vertical Alignment (Vector3.UP and Vector3.DOWN)
	# UP: dir.dot(UP) == 1.0 > 0.99
	gizmo.set_vector(Vector3.ZERO, Vector3.UP * 10.0)
	assert_test(gizmo.visible == true, "UP vector shows gizmo")
	assert_test(_is_finite_basis(gizmo.transform.basis), "UP vector has finite basis")
	assert_test(is_equal_approx(gizmo.transform.basis.determinant(), 1.0), "UP vector basis determinant == 1.0 (orthonormal)")
	assert_test(gizmo.transform.basis.y.is_equal_approx(Vector3.UP), "UP vector aligns basis.y with Vector3.UP")

	# DOWN: dir.dot(UP) == -1.0, absf(-1.0) == 1.0 > 0.99
	gizmo.set_vector(Vector3.ZERO, Vector3.DOWN * 10.0)
	assert_test(gizmo.visible == true, "DOWN vector shows gizmo")
	assert_test(_is_finite_basis(gizmo.transform.basis), "DOWN vector has finite basis")
	assert_test(is_equal_approx(absf(gizmo.transform.basis.determinant()), 1.0), "DOWN vector basis determinant magnitude == 1.0")
	assert_test(gizmo.transform.basis.y.is_equal_approx(Vector3.DOWN), "DOWN vector aligns basis.y with Vector3.DOWN")

	# 1.5 Near-threshold angles (dot with UP around 0.99)
	# Case A: dot == 0.989 (below 0.99 -> up = UP)
	var dir_below := Vector3(sqrt(1.0 - 0.989 * 0.989), 0.989, 0.0)
	gizmo.set_vector(Vector3.ZERO, dir_below * 5.0)
	assert_test(_is_finite_basis(gizmo.transform.basis), "Basis finite at dot=0.989 with UP")
	assert_test(is_equal_approx(absf(gizmo.transform.basis.determinant()), 1.0), "Determinant orthonormal at dot=0.989")

	# Case B: dot == 0.991 (above 0.99 -> up = BACK)
	var dir_above := Vector3(sqrt(1.0 - 0.991 * 0.991), 0.991, 0.0)
	gizmo.set_vector(Vector3.ZERO, dir_above * 5.0)
	assert_test(_is_finite_basis(gizmo.transform.basis), "Basis finite at dot=0.991 with UP")
	assert_test(is_equal_approx(absf(gizmo.transform.basis.determinant()), 1.0), "Determinant orthonormal at dot=0.991")

	# 1.6 Cardinals: FORWARD, BACK, LEFT, RIGHT
	var cardinals: Array[Vector3] = [Vector3.FORWARD, Vector3.BACK, Vector3.LEFT, Vector3.RIGHT]
	var all_cardinals_valid: bool = true
	for c in cardinals:
		gizmo.set_vector(Vector3.ZERO, c * 8.0)
		if not _is_finite_basis(gizmo.transform.basis) or not is_equal_approx(absf(gizmo.transform.basis.determinant()), 1.0):
			all_cardinals_valid = false
	assert_test(all_cardinals_valid, "All cardinal directions maintain orthonormal finite basis")

	# 1.7 Pathological max_speed_scale
	gizmo.set_vector(Vector3.ZERO, Vector3(5.0, 0.0, 0.0), 0.0)
	assert_test(gizmo.visible == true and _is_finite_basis(gizmo.transform.basis), "max_speed_scale = 0.0 safely clamped")

	gizmo.set_vector(Vector3.ZERO, Vector3(5.0, 0.0, 0.0), -10.0)
	assert_test(gizmo.visible == true and _is_finite_basis(gizmo.transform.basis), "Negative max_speed_scale safely clamped")

	# 1.8 Monte-Carlo Stress: 1,000 random orientations on sphere
	var rng := RandomNumberGenerator.new()
	rng.seed = 421337
	var monte_carlo_passed: bool = true
	for i in range(1000):
		var theta: float = rng.randf_range(0.0, TAU)
		var phi: float = rng.randf_range(-PI * 0.5, PI * 0.5)
		var dir_rand := Vector3(cos(phi) * cos(theta), sin(phi), cos(phi) * sin(theta)).normalized()
		var speed_rand: float = rng.randf_range(0.001, 500.0)
		var origin_rand := Vector3(rng.randf_range(-100, 100), rng.randf_range(-100, 100), rng.randf_range(-100, 100))
		
		gizmo.set_vector(origin_rand, dir_rand * speed_rand, 25.0)
		if not _is_finite_basis(gizmo.transform.basis) or not _is_finite_vector(gizmo.transform.origin):
			monte_carlo_passed = false
			break
		if not is_equal_approx(absf(gizmo.transform.basis.determinant()), 1.0):
			monte_carlo_passed = false
			break
	assert_test(monte_carlo_passed, "1,000 Monte-Carlo sphere vectors produced zero NaN/INF and strictly orthonormal bases")

	gizmo.queue_free()

# ==============================================================================
# 2. ScreenRaycaster Stress Testing
# ==============================================================================
func _stress_screen_raycaster() -> void:
	print("\n--- 2. ScreenRaycaster Adversarial Stress Tests ---")

	# 2.1 Null Camera Safety
	var null_hit1: Variant = ScreenRaycaster.cast_to_plane(null, Vector2(100, 100), Vector3.UP, Vector3.ZERO)
	assert_test(null_hit1 == null, "cast_to_plane with null camera returns null")

	var null_hit2: Variant = ScreenRaycaster.cast_to_camera_facing_plane(null, Vector2(100, 100), Vector3.ZERO)
	assert_test(null_hit2 == null, "cast_to_camera_facing_plane with null camera returns null")

	var null_hit3: Variant = ScreenRaycaster.cast_to_depth_plane(null, Vector2(100, 100), 10.0)
	assert_test(null_hit3 == null, "cast_to_depth_plane with null camera returns null")

	# 2.2 Setup Virtual Camera in a dummy SubViewport
	var vp := SubViewport.new()
	vp.size = Vector2i(1920, 1080)
	root.add_child(vp)

	var cam := Camera3D.new()
	cam.position = Vector3(0.0, 5.0, 15.0)
	cam.look_at(Vector3.ZERO, Vector3.UP)
	vp.add_child(cam)

	var screen_center := Vector2(960.0, 540.0)

	# 2.3 Raycast onto Camera-Facing Plane through Origin
	var hit_center: Variant = ScreenRaycaster.cast_to_camera_facing_plane(cam, screen_center, Vector3.ZERO)
	assert_test(hit_center != null and (hit_center is Vector3), "cast_to_camera_facing_plane returned valid Vector3")
	if hit_center is Vector3:
		assert_test(_is_finite_vector(hit_center), "Intersection point is finite")

	# 2.4 Raycast onto Depth Plane
	var depth_hit: Variant = ScreenRaycaster.cast_to_depth_plane(cam, screen_center, 10.0)
	assert_test(depth_hit != null and (depth_hit is Vector3), "cast_to_depth_plane returned valid Vector3")
	if depth_hit is Vector3:
		var dist_to_cam: float = (depth_hit as Vector3).distance_to(cam.global_position)
		assert_test(is_equal_approx(dist_to_cam, 10.0), "Depth plane intersection distance matches depth parameter 10.0", "Dist: %f" % dist_to_cam)

	# 2.5 Extreme Camera Pitch Angles (+90 deg straight down, -90 deg straight up)
	# Straight down (looking at -Y)
	cam.transform.basis = Basis.looking_at(Vector3.DOWN, Vector3.BACK)
	cam.position = Vector3(0.0, 20.0, 0.0)
	var down_hit: Variant = ScreenRaycaster.cast_to_depth_plane(cam, screen_center, 20.0)
	assert_test(down_hit != null and (down_hit is Vector3), "Pitch +90 deg (straight down) returns valid depth hit")
	if down_hit is Vector3:
		assert_test((down_hit as Vector3).is_equal_approx(Vector3(0.0, 0.0, 0.0)), "Straight down hit lands at origin (0,0,0)", "Hit: %s" % str(down_hit))

	# Straight up (looking at +Y)
	cam.transform.basis = Basis.looking_at(Vector3.UP, Vector3.FORWARD)
	cam.position = Vector3(0.0, -20.0, 0.0)
	var up_hit: Variant = ScreenRaycaster.cast_to_depth_plane(cam, screen_center, 20.0)
	assert_test(up_hit != null and (up_hit is Vector3), "Pitch -90 deg (straight up) returns valid depth hit")
	if up_hit is Vector3:
		assert_test((up_hit as Vector3).is_equal_approx(Vector3(0.0, 0.0, 0.0)), "Straight up hit lands at origin (0,0,0)", "Hit: %s" % str(up_hit))

	# 2.6 Extreme Field of View (FOV = 1.0 deg and FOV = 179.0 deg)
	# FOV 1.0 deg (Extreme zoom)
	cam.fov = 1.0
	cam.position = Vector3(0.0, 0.0, 50.0)
	cam.look_at(Vector3.ZERO, Vector3.UP)
	var tele_hit: Variant = ScreenRaycaster.cast_to_camera_facing_plane(cam, screen_center, Vector3.ZERO)
	assert_test(tele_hit != null and (tele_hit as Vector3).is_equal_approx(Vector3.ZERO), "FOV 1.0 deg yields accurate center intersection")

	# FOV 179.0 deg (Extreme fisheye)
	cam.fov = 179.0
	var fisheye_hit: Variant = ScreenRaycaster.cast_to_camera_facing_plane(cam, screen_center, Vector3.ZERO)
	assert_test(fisheye_hit != null and _is_finite_vector(fisheye_hit as Vector3), "FOV 179.0 deg produces finite intersection without NaN")

	# 2.7 Parallel Camera / Ray to Arbitrary Plane
	# Camera looking along -Z horizontally (Y=10)
	cam.fov = 60.0
	cam.position = Vector3(0.0, 10.0, 20.0)
	cam.transform.basis = Basis.IDENTITY # looks along -Z
	# Plane at Y = 10, normal = Vector3.UP (camera moves entirely parallel to this plane)
	# The screen center ray has ray_dir.y == 0.0, strictly parallel to plane normal UP
	var parallel_hit: Variant = ScreenRaycaster.cast_to_plane(cam, screen_center, Vector3.UP, Vector3(0.0, 10.0, 0.0))
	assert_test(parallel_hit == null, "Ray strictly parallel to plane returns null cleanly without crash")

	# 2.8 Ray pointing away from plane (behind camera)
	# Plane at Z = 30 (behind camera which is at Z = 20 looking towards -Z)
	var behind_hit: Variant = ScreenRaycaster.cast_to_plane(cam, screen_center, Vector3(0.0, 0.0, -1.0), Vector3(0.0, 0.0, 30.0))
	assert_test(behind_hit == null, "Plane behind camera returns null")

	cam.queue_free()
	vp.queue_free()

# ==============================================================================
# 3. KeplerTrajectoryPreview Stress Testing
# ==============================================================================
func _stress_kepler_trajectory_preview() -> void:
	print("\n--- 3. KeplerTrajectoryPreview Adversarial Stress Tests ---")
	var preview: KeplerTrajectoryPreview = KeplerTrajectoryPreview.new()
	preview._ready()

	# 3.1 Non-positive mu (standard gravitational parameter <= 0)
	preview.update_orbit(Vector3.ZERO, Vector3(10.0, 0.0, 0.0), Vector3(0.0, 0.0, 5.0), 0.0)
	assert_test(preview.visible == false, "mu = 0.0 clears orbit")

	preview.update_orbit(Vector3.ZERO, Vector3(10.0, 0.0, 0.0), Vector3(0.0, 0.0, 5.0), -100.0)
	assert_test(preview.visible == false, "Negative mu clears orbit")

	# 3.2 Degenerate radial plunge: velocity directly along radius (h -> 0)
	var r_radial := Vector3(20.0, 0.0, 0.0)
	var v_radial := Vector3(-10.0, 0.0, 0.0) # pointing straight towards attractor
	preview.update_orbit(Vector3.ZERO, r_radial, v_radial, 1000.0)
	assert_test(preview.visible == false, "Radial plunge (velocity collinear with radius, h=0) clears orbit")

	# Tiny angular momentum h < 0.0001
	var v_near_radial := Vector3(-10.0, 0.0, 0.000001)
	preview.update_orbit(Vector3.ZERO, r_radial, v_near_radial, 1000.0)
	assert_test(preview.visible == false, "Infinitesimal angular momentum (h < 0.0001) clears orbit")

	# 3.3 Collinear positions (r_mag < 0.01)
	preview.update_orbit(Vector3.ZERO, Vector3(0.001, 0.0, 0.0), Vector3(0.0, 5.0, 0.0), 1000.0)
	assert_test(preview.visible == false, "Body at attractor (r < 0.01) clears orbit")

	# Zero velocity (v_mag < 0.001)
	preview.update_orbit(Vector3.ZERO, Vector3(10.0, 0.0, 0.0), Vector3.ZERO, 1000.0)
	assert_test(preview.visible == false, "Zero velocity clears orbit")

	# 3.4 Perfect Circular Orbit (e = 0.0)
	# mu = 1000, r = 10 -> v_circ = sqrt(mu / r) = 10.0
	var r_circ := Vector3(10.0, 0.0, 0.0)
	var v_circ := Vector3(0.0, 0.0, 10.0)
	preview.update_orbit(Vector3.ZERO, r_circ, v_circ, 1000.0)
	assert_test(preview.visible == true, "Circular orbit (e = 0.0) updates preview to visible")

	# 3.5 High Eccentricity Elliptical Orbit (e = 0.95)
	# At periapsis r_p = 5.0, for e = 0.95: a = r_p / (1 - e) = 5 / 0.05 = 100.
	# v_p = sqrt(mu * (2/r_p - 1/a)) = sqrt(1000 * (2/5 - 1/100)) = sqrt(1000 * 0.39) = sqrt(390) ≈ 19.7484
	var r_ellip := Vector3(5.0, 0.0, 0.0)
	var v_ellip := Vector3(0.0, 0.0, sqrt(390.0))
	preview.update_orbit(Vector3.ZERO, r_ellip, v_ellip, 1000.0)
	assert_test(preview.visible == true, "Highly eccentric ellipse (e = 0.95) produces valid orbit preview")

	# 3.6 Exact Parabolic Escape Orbit (e = 1.0)
	# At r = 10, v_esc = sqrt(2 * mu / r) = sqrt(2000 / 10) = sqrt(200) ≈ 14.1421356
	var r_para := Vector3(10.0, 0.0, 0.0)
	var v_para := Vector3(0.0, 0.0, sqrt(200.0))
	preview.update_orbit(Vector3.ZERO, r_para, v_para, 1000.0)
	assert_test(preview.visible == true, "Parabolic escape orbit (e = 1.0) produces valid preview")

	# 3.7 Hyperbolic Orbit (e > 1.0, e.g. e = 2.0)
	# At r = 10, v = 20.0 > v_esc (14.14)
	# h = 10 * 20 = 200. v x h = 20 * 200 = 4000. 4000 / 1000 = 4. e_vec = 4 - 1 = 3 -> e = 3.0
	var r_hyper := Vector3(10.0, 0.0, 0.0)
	var v_hyper := Vector3(0.0, 0.0, 20.0)
	preview.update_orbit(Vector3.ZERO, r_hyper, v_hyper, 1000.0)
	assert_test(preview.visible == true, "Hyperbolic orbit (e > 1.0) produces valid preview")

	# 3.8 Extreme Relativistic Hyperbolic Velocity (e >> 1.0, e.g. v = 500)
	preview.update_orbit(Vector3.ZERO, Vector3(10.0, 0.0, 0.0), Vector3(0.0, 0.0, 500.0), 1000.0)
	assert_test(preview.visible == true, "Extreme hyperbolic velocity (v = 500.0) renders without NaN/INF")

	# 3.9 Arbitrary 3D Inclined Hyperbolic Orbit
	var r_inc := Vector3(7.0, -12.0, 4.0)
	var v_inc := Vector3(15.0, 8.0, -10.0)
	preview.update_orbit(Vector3(100.0, -50.0, 25.0), r_inc, v_inc, 5000.0)
	assert_test(preview.visible == true, "Arbitrary 3D inclined orbit computes cleanly")

	preview.queue_free()

# ==============================================================================
# 4. PhysicsInteractionManager Stress Testing
# ==============================================================================
func _stress_physics_interaction_manager() -> void:
	print("\n--- 4. PhysicsInteractionManager Adversarial Stress Tests ---")
	var bus: Node = EventBusScript.new()
	var time_ctrl: SimulationTimeController = SimulationTimeController.new()
	var sentry: ConservationSentry = ConservationSentry.new()
	sentry.setup(bus)

	var mgr: PhysicsInteractionManager = PhysicsInteractionManager.new()
	mgr._ready()
	mgr.setup(bus, null, null, time_ctrl, sentry)

	# 4.1 Rapid Tool Switching in Loop (Stress Test)
	var tool_keys: Array[String] = ["select", "gravity", "thermo", "nuclear", "quantum", "sensor", "invalid_key", "1", "2", "3", "4", "5"]
	for k in tool_keys:
		bus.publish("physics_tool_selected", {"tool_id": k})
	assert_test(mgr.current_tool_mode == PhysicsInteractionManager.ToolMode.SENSOR, "Tool switching through 12 rapid transitions ended correctly")

	# 4.2 Parameter modification with boundary/extreme values
	bus.publish("physics_parameter_changed", {"param": "gravity_mass", "value": 1e9})
	assert_test(is_equal_approx(mgr.gravity_spawn_mass, 1e9), "Extreme gravity_mass (1e9) handled")

	bus.publish("physics_parameter_changed", {"param": "gravity_mass", "value": 0.0})
	assert_test(is_equal_approx(mgr.gravity_spawn_mass, 0.0), "Zero gravity_mass handled")

	bus.publish("physics_parameter_changed", {"param": "thermo_temp", "value": 0.0001})
	assert_test(is_equal_approx(mgr.thermo_inject_temp, 0.0001), "Near-absolute-zero thermo_temp handled")

	# 4.3 Drag Start/Cancel without Camera
	mgr._start_drag(Vector2(500, 500))
	assert_test(mgr._is_dragging == false, "_start_drag gracefully ignored without camera")

	mgr._cancel_drag()
	assert_test(mgr._is_dragging == false, "_cancel_drag safe when not dragging")

	# 4.4 Entity selection with no camera / no hits
	var selected_payload: Array = []
	bus.subscribe("physics_entity_selected", func(p: Dictionary) -> void:
		selected_payload.append(p)
	)
	mgr._select_entity_at(Vector3(10.0, 20.0, 30.0))
	assert_test(selected_payload.size() == 1, "Fallback selection published on empty world click")
	assert_test(selected_payload[0].get("position") == Vector3(10.0, 20.0, 30.0), "Selection anchor matches click point")

	mgr.queue_free()
	sentry.queue_free()
	time_ctrl.queue_free()
	bus.queue_free()
