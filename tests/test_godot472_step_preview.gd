extends SceneTree
func _initialize() -> void:
	var w=load("res://ui/cae/cae_workspace.gd").new()
	root.add_child.call_deferred(w)
	await process_frame
	w.set_active(true)
	var path="res://tests/fixtures/step/bar.step"
	var bytes=FileAccess.get_file_as_bytes(path)
	var document=load("res://core/cae/cae_document.gd")
	var error=w.document.execute("ImportSTEP",{"cad_base64":Marshalls.raw_to_base64(bytes),"cad_sha256":document.cad_sha256(bytes),"name":"bar.step"})
	if not error.is_empty():push_error(error);quit(1);return
	w.selected=0
	w.start_cad_preview()
	var deadline=Time.get_ticks_msec()+120000
	while w.cad_preview_thread!=null and Time.get_ticks_msec()<deadline:await process_frame
	if w.cad_preview.is_empty():push_error("No STEP preview: "+w.status.text);quit(1);return
	if w.document.data.mesh.size()!=0:push_error("Preview generated volume mesh");quit(1);return
	if w.document.data.parts[0].cad_faces.size()!=6:push_error("Wrong OCC face count");quit(1);return
	if w.cad.meshes[0].mesh==null:push_error("No visible STEP solid");quit(1);return
	DirAccess.make_dir_recursive_absolute("res://.tools/step-calculix/workbench")
	if DisplayServer.get_name()!="headless":
		for width in [1280,1920]:
			root.size=Vector2i(width,720 if width==1280 else 1080)
			for i in 5:await process_frame
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("res://.tools/step-calculix/workbench/bar-preview-%d.png" % width)
	print("STEP_PREVIEW_WORKBENCH_PASS")
	w.queue_free()
	await process_frame
	quit()
