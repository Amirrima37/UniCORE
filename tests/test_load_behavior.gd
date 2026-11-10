extends SceneTree

func _init() -> void:
	print("Testing dynamic load of physical_integrator.gd...")
	var script_res = load("res://core/physics/physical_integrator.gd")
	print("script_res is: ", script_res)
	var instance = script_res.new()
	print("instance is: ", instance)
	quit(0)
