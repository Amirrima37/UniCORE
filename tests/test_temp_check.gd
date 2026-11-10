extends SceneTree

func _init() -> void:
	var a := PackedVector3Array([Vector3(1, 2, 3), Vector3(4, 5, 6)])
	var b := a
	b = PackedVector3Array()
	print("Size of a after b = PackedVector3Array(): ", a.size())
	quit(0)
