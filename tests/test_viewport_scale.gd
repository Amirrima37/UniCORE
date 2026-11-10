extends SceneTree

func _init() -> void:
	var win = root
	print("--- Root Window Viewport Scaling ---")
	print("content_scale_size: ", win.content_scale_size)
	print("content_scale_mode: ", win.content_scale_mode)
	print("content_scale_aspect: ", win.content_scale_aspect)
	print("content_scale_factor: ", win.content_scale_factor)
	print("CONTENT_SCALE_MODE_DISABLED: ", Window.CONTENT_SCALE_MODE_DISABLED)
	print("CONTENT_SCALE_MODE_CANVAS_ITEMS: ", Window.CONTENT_SCALE_MODE_CANVAS_ITEMS)
	print("CONTENT_SCALE_MODE_VIEWPORT: ", Window.CONTENT_SCALE_MODE_VIEWPORT)
	print("CONTENT_SCALE_ASPECT_EXPAND: ", Window.CONTENT_SCALE_ASPECT_EXPAND)
	quit(0)
