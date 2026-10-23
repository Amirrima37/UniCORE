extends SceneTree

func _init() -> void:
	var ev = InputEventKey.new()
	ev.keycode = KEY_F11
	ev.pressed = true
	print("Has action: ", InputMap.has_action("toggle_fullscreen"))
	# Check if is_action_pressed errors when not in InputMap
	if InputMap.has_action("toggle_fullscreen"):
		print("is_action: ", ev.is_action_pressed("toggle_fullscreen"))
	else:
		print("toggle_fullscreen not in InputMap, adding it dynamically...")
		InputMap.add_action("toggle_fullscreen")
		var key_ev = InputEventKey.new()
		key_ev.keycode = KEY_F11
		InputMap.action_add_event("toggle_fullscreen", key_ev)
		print("After adding: ", ev.is_action_pressed("toggle_fullscreen"))
	quit(0)
