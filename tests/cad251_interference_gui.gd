extends SceneTree
var out=OS.get_environment("UNICORE_INTERFERENCE_OUT")
var w
func _initialize():call_deferred("run")
func capture(name: String):
	for width in [1280,1920]:
		root.size=Vector2i(width,720 if width==1280 else 1080)
		for i in 12:await process_frame
		RenderingServer.force_draw(false)
		root.get_texture().get_image().save_png(out+"/"+name+"-"+str(width)+".png")
func run():
	w=load("res://ui/cae/cae_workspace.gd").new();root.add_child(w);w.set_active(true)
	for scenario in ["rotated-disjoint","touching"]:
		assert(w.document.open_project(out+"/"+scenario+"2.json").is_empty())
		w.selected=1;w.select_body(1);w.fit_model()
		w.generate_analysis_mesh()
		while w.external_mesh_thread!=null:await process_frame
		assert(not w.document.data.mesh.is_empty())
		await capture(scenario)
		w.solve()
		while w.solve_thread!=null:await process_frame
		assert(w.document.data.results.get("ok",false))
		w.select_result_field("displacement")
		await capture(scenario+"-results")
	# Move the touching partner into positive-volume overlap through real commands.
	w.show_results=false;w.run_command("SetPosition",{"values":[.05,0,0]})
	while w.cad_preview_thread!=null:await process_frame
	assert(w.document.data.mesh.is_empty())
	w.generate_analysis_mesh()
	while w.external_mesh_thread!=null:await process_frame
	assert(w.document.data.mesh.is_empty())
	await capture("overlap-rejected")
	w.queue_free();await process_frame
	print("INTERFERENCE_GUI_PASS")
	quit()
