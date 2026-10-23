extends SceneTree

func _init() -> void:
	print("Instantiating space_viewport.tscn...")
	var main_scene = load("res://core/space_viewport.tscn")
	var viewport_inst = main_scene.instantiate()
	root.add_child(viewport_inst)
	print("space_viewport instantiated and added to root")
	quit(0)
