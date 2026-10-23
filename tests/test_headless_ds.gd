extends SceneTree

func _init() -> void:
	print("--- Headless DisplayServer window calls ---")
	print("Initial mode: ", DisplayServer.window_get_mode())
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	print("After set FULLSCREEN: ", DisplayServer.window_get_mode())
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN)
	print("After set EXCLUSIVE_FULLSCREEN: ", DisplayServer.window_get_mode())
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	print("After set WINDOWED: ", DisplayServer.window_get_mode())
	
	print("Initial size: ", DisplayServer.window_get_size())
	DisplayServer.window_set_size(Vector2i(1920, 1080))
	print("After set 1920x1080: ", DisplayServer.window_get_size())
	
	print("Initial position: ", DisplayServer.window_get_position())
	DisplayServer.window_set_position(Vector2i(100, 100))
	print("After set pos: ", DisplayServer.window_get_position())
	
	print("Screen size: ", DisplayServer.screen_get_size())
	quit(0)
