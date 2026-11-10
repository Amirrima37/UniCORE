extends SceneTree

const Gravity = preload("res://modules/physics/n_body_gravity_module.gd")
const PhysicsPrompt = preload("res://agent/physics_prompt.gd")
var failures: int = 0

func check(ok: bool, label: String) -> void:
	if not ok:
		failures += 1
		push_error(label)

func _init() -> void:
	var gravity = Gravity.new()
	gravity.compute_backend = "gdscript"
	gravity.enable_trails = false
	gravity.enable_relativity = false
	gravity.post_newtonian_mode = 0
	gravity.add_body("star", Vector3.ZERO, Vector3.ZERO, 10.0)
	gravity.add_body("planet", Vector3(2, 0, 0), Vector3.ZERO, 1.0)
	var before: PackedVector3Array = gravity.get_force_snapshot()
	check(gravity.edit_body("star", "mass", 20.0), "Mass edit accepted")
	check(gravity._forces_scratch[1].is_equal_approx(before[1] * 2.0), "Mass edit refreshes force immediately")
	check(gravity.edit_body("planet", "position", Vector3(4, 0, 0)), "Position edit accepted")
	check(gravity._forces_scratch[1].length() < before[1].length(), "Paused position edit refreshes force")
	check(gravity.get_positions()[1] == Vector3(4, 0, 0), "Force refresh does not integrate")
	check(gravity.edit_body("planet", "velocity", Vector3(0, 1, 0)), "Velocity edit accepted")
	gravity.step(0.001)
	check(gravity.get_positions()[1].y > 0.0, "Next integration uses edited velocity")
	check(not gravity.edit_body("star", "mass", -1), "Negative mass rejected")
	check(not gravity.edit_body("planet", "name", "star"), "Duplicate name rejected")
	check(not gravity.edit_body("planet", "color", 42), "Invalid color rejected")
	check(PhysicsPrompt.CONTEXT.contains("n_body_gravity"), "Physics API available to agent")
	gravity.free()
	print("Agent physics contract failures: ", failures)
	quit(1 if failures else 0)
