extends SceneTree

func _init() -> void:
	print("--- Testing extreme resolutions ---")
	DisplayServer.window_set_size(Vector2i(100000, 100000))
	print("Extreme size set without crash.")
	DisplayServer.window_set_size(Vector2i(-999, -999))
	print("Negative size set without crash.")
	quit(0)
