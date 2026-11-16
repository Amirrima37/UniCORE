extends SceneTree
var drawing:=false
func _initialize():
	for i in 3:
		await process_frame
		if "signal" in OS.get_cmdline_user_args():await RenderingServer.frame_post_draw
		assert(is_instance_valid(root))
		if drawing:
			print("Reentrant render wait with live SceneTree")
			quit(2);return
		drawing=true
		RenderingServer.force_draw()
		drawing=false
	print("Render wait control completed with live SceneTree")
	quit()
