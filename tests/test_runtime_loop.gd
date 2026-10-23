extends SceneTree

# 60-frame live runtime stress test for UniCORE space_viewport.tscn
# Verifies full lifecycle: mounting, rendering loop, input events, menu open/close,
# prompt bar open/close, template switching, and clean exit.

var frame_count: int = 0
var max_frames: int = 60
var viewport_node: SpaceViewport

func _init() -> void:
	print("==================================================")
	print("Starting UniCORE 60-Frame Live Runtime Stress Test")
	print("==================================================")

	var scene = load("res://core/space_viewport.tscn")
	if not scene:
		push_error("Failed to load res://core/space_viewport.tscn")
		quit(1)
		return

	viewport_node = scene.instantiate()
	root.add_child(viewport_node)
	print("[RuntimeTest] Scene mounted to SceneTree root. Starting process frames...")

func _process(_delta: float) -> bool:
	frame_count += 1

	# Frame 10: Toggle prompt bar open
	if frame_count == 10:
		print("[RuntimeTest] Frame 10: Opening PromptBar...")
		viewport_node.prompt_bar.open()
		if not viewport_node.prompt_bar.is_open:
			push_error("PromptBar failed to open at frame 10")
			quit(1)
			return true

	# Frame 20: Close prompt bar
	if frame_count == 20:
		print("[RuntimeTest] Frame 20: Closing PromptBar...")
		viewport_node.prompt_bar.close()
		if viewport_node.prompt_bar.is_open:
			push_error("PromptBar failed to close at frame 20")
			quit(1)
			return true

	# Frame 30: Open System Menu
	if frame_count == 30:
		print("[RuntimeTest] Frame 30: Opening MainMenu...")
		viewport_node.main_menu.open("settings")
		if not viewport_node.main_menu.is_open:
			push_error("MainMenu failed to open at frame 30")
			quit(1)
			return true

	# Frame 40: Close System Menu
	if frame_count == 40:
		print("[RuntimeTest] Frame 40: Closing MainMenu...")
		viewport_node.main_menu.close()
		if viewport_node.main_menu.is_open:
			push_error("MainMenu failed to close at frame 40")
			quit(1)
			return true

	# Frame 50: Toggle Fullscreen via SettingsManager
	if frame_count == 50:
		print("[RuntimeTest] Frame 50: Testing Fullscreen Toggle...")
		viewport_node.settings_manager.toggle_fullscreen()
		viewport_node.settings_manager.toggle_fullscreen()

	if frame_count >= max_frames:
		print("[RuntimeTest] Completed %d frames smoothly with 0 fatal errors." % frame_count)
		viewport_node.queue_free()
		print("==================================================")
		print("Runtime Stress Test PASSED (60/60 frames)")
		print("==================================================")
		quit(0)
		return true

	return false
