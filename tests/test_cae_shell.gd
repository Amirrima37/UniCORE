extends SceneTree
var failures:=0
func check(ok: bool,message: String) -> void:
	if not ok:
		failures+=1
		push_error(message)
func _initialize():
	create_timer(30).timeout.connect(func(): quit(2))
	root.size=Vector2i(1280,720)
	var shell=load("res://core/space_viewport.tscn").instantiate()
	shell.set_script(load("res://tests/cae_shell_fixture.gd"))
	root.add_child.call_deferred(shell)
	await process_frame
	shell._is_in_space=true
	shell.welcome_screen.hide()
	shell.boot_screen.hide()
	shell.event_bus.emit("modal_closed",{"source":"welcome_screen"})
	var selector: OptionButton=shell.top_bar.get_node("PanelContainer/MarginContainer/HBoxContainer/LeftBox/WorkspaceSelector")
	selector.item_selected.emit(1)
	check(shell.workspace_modes.current==1 and shell.cae_workspace.visible,"Global selector opens CAE")
	check(shell.world_root.process_mode==Node.PROCESS_MODE_DISABLED,"Actual sandbox modules suspended")
	shell.cae_workspace.create_part("Cylinder")
	shell.cae_workspace.back_requested.emit()
	check(shell.workspace_modes.current==0 and shell.world_root.visible,"Back button restores real sandbox")
	check(shell.world_root.process_mode!=Node.PROCESS_MODE_DISABLED,"Sandbox simulation restored")
	shell.top_bar.prompt_toggle_pressed.emit()
	check(shell.prompt_bar.is_open,"Original AI prompt opens after leaving CAE")
	shell.prompt_bar.prompt_submitted.emit("Create a test sphere module")
	check("CAD command mode" not in shell.agent_brain._provider.last_system and "GDScript" in shell.agent_brain._provider.last_system,"Sandbox prompt routes to existing agent")
	selector.item_selected.emit(1)
	check(shell.cae_workspace.document.data.parts.size()==1,"Real shell retains CAE session")
	for width in [1280,960]:
		root.size=Vector2i(width,720)
		await process_frame
		await process_frame
		check(selector.get_global_rect().end.x<=root.get_visible_rect().size.x,"Mode selector visible at " + str(width))
		check(shell.cae_workspace.get_global_rect().end.x<=root.get_visible_rect().size.x+1,"CAE fits window at " + str(width))
		check(shell.cae_workspace.properties.get_global_rect().end.x<=root.get_visible_rect().size.x+1,"Inspector fits window at " + str(width))
	# Optional graphical capture for manual layout review.
	if "--capture" in OS.get_cmdline_user_args():
		root.size=Vector2i(1280,720)
		shell.cae_workspace.cad.invalidate()
		for i in 8: await process_frame
		shell.cae_workspace.cad.viewport.get_texture().get_image().save_png("res://.tools/cae-viewport.png")
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://.tools/cae-recovery.png")
	shell.workspace_modes.set_mode(0)
	shell.queue_free()
	await process_frame
	print("CAE real-shell navigation and resize: ",failures," failures")
	quit(1 if failures else 0)








