extends SceneTree
func capture(name: String) -> void:
	if DisplayServer.get_name()=="headless":return
	for width in [1280,1920]:
		root.size=Vector2i(width,720 if width==1280 else 1080)
		for i in 5:await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://.tools/step-calculix/workbench/%s-%d.png" % [name,width])
func fail(message: String) -> void:
	push_error(message)
	quit(1)
func _initialize() -> void:
	var fixture=OS.get_environment("UNICORE_STEP_FIXTURE")
	if fixture.is_empty():fixture="bar"
	if fixture not in ["bar","cylinder"]:fail("Unsupported test fixture");return
	DirAccess.make_dir_recursive_absolute("res://.tools/step-calculix/workbench")
	var w=load("res://ui/cae/cae_workspace.gd").new()
	root.add_child.call_deferred(w)
	await process_frame
	w.set_active(true)
	var bytes=FileAccess.get_file_as_bytes("res://tests/fixtures/step/"+fixture+".step")
	var Document=load("res://core/cae/cae_document.gd")
	var hash=Document.cad_sha256(bytes)
	var error=w.document.execute("ImportSTEP",{"cad_base64":Marshalls.raw_to_base64(bytes),"cad_sha256":hash,"name":fixture+".step"})
	if not error.is_empty():fail(error);return
	w.selected=0
	w.document.execute("SetAnalysis",{"analysis":{"type":"static_structural","element":"TET4","backend":"calculix"}})
	w.start_cad_preview()
	var deadline=Time.get_ticks_msec()+120000
	while w.cad_preview_thread!=null and Time.get_ticks_msec()<deadline:await process_frame
	if w.cad_preview.is_empty():fail("OCC preview: "+w.status.text);return
	if not w.document.data.mesh.is_empty():fail("FEM mesh created during preview");return
	await capture(fixture+"-import")
	var p=w.document.data.parts[0]
	var bottom="";var top="";var low=INF;var high=-INF
	for name in p.cad_face_centers:
		var y=float(p.cad_face_centers[name][1])
		if y<low:low=y;bottom=name
		if y>high:high=y;top=name
	if bottom==top or p.cad_face_areas[bottom]<0.009 or p.cad_face_areas[top]<0.009:fail("Invalid CAD ends");return
	w.selection_mode.select(1)
	w.face.select(p.cad_faces.find(top))
	w.show_selected_face()
	await capture(fixture+"-selected-face")
	p.material.nu=0.0 if fixture=="bar" else 0.3
	error=w.document.execute("ApplySupport",{"index":0,"face":bottom})
	if not error.is_empty():fail(error);return
	error=w.document.execute("ApplyLoad",{"index":0,"face":top,"force":[0.0,1000.0,0.0]})
	if not error.is_empty():fail(error);return
	w.divisions.value=2
	w.generate_analysis_mesh()
	deadline=Time.get_ticks_msec()+120000
	while w.external_mesh_thread!=null and Time.get_ticks_msec()<deadline:await process_frame
	if w.document.data.mesh.is_empty():fail("Gmsh mesh: "+w.status.text);return
	if w.document.data.mesh.provenance.cad_sha256!=hash:fail("Mesh source hash mismatch");return
	w.mesh_visible=true;w.render_model();w.fit_model()
	await capture(fixture+"-tet4")
	w.show_selected_face()
	await capture(fixture+"-support")
	w.face.select(p.cad_faces.find(top));w.show_selected_face()
	await capture(fixture+"-force")
	w.open_analysis_editor()
	await capture(fixture+"-backend")
	w.analysis_editor.hide()
	w.solve()
	await capture(fixture+"-solving")
	deadline=Time.get_ticks_msec()+150000
	while w.solve_thread!=null and Time.get_ticks_msec()<deadline:await process_frame
	if not w.document.data.results.get("ok",false):fail("CalculiX: "+w.status.text);return
	if not w.results_current():fail("Result provenance mismatch");return
	w.deformation_scale=w.automatic_deformation_scale();w.structural_wireframe=true
	w.select_result_field("displacement");await capture(fixture+"-displacement")
	w.select_result_field("von_mises");await capture(fixture+"-von-mises")
	var prior_mesh=w.document.data.mesh.duplicate(true)
	var path="res://.tools/step-calculix/workbench/"+fixture+".ucae"
	if w.document.save_project(path)!=OK:fail("Save failed");return
	if not w.document.open_project(path).is_empty():fail("Reopen failed");return
	if w.document.data.parts[0].cad_sha256!=hash or not w.results_current():
		var r=w.document.data.results
		print("REOPEN_DIAGNOSTIC parts=",r.get("model_parts",[])==w.document.data.parts," analysis=",r.get("model_analysis",{})==w.document.data.analysis," mesh=",r.get("source_mesh_sha256","")==JSON.stringify(JSON.parse_string(JSON.stringify(w.document.data.mesh,"",true,true)),"",true,true).sha256_text())
		for key in prior_mesh:
			if JSON.stringify(prior_mesh[key],"",true,true)!=JSON.stringify(w.document.data.mesh.get(key),"",true,true):
				print("MESH_CHANGE ",key)
				if key=="nodes":
					for j in prior_mesh.nodes.size():
						if prior_mesh.nodes[j]!=w.document.data.mesh.nodes[j]:print("NODE_CHANGE ",j," ",prior_mesh.nodes[j]," -> ",w.document.data.mesh.nodes[j]);break
		fail("Reopened study stale");return
	if preload("res://core/cae/mesh_fingerprint.gd").fingerprint(prior_mesh)!=preload("res://core/cae/mesh_fingerprint.gd").fingerprint(w.document.data.mesh):fail("Lossless mesh changed");return
	for dependency in ["coordinate","connectivity","geometry","material","load"]:
		var original=w.document.data.duplicate(true)
		match dependency:
			"coordinate":w.document.data.mesh.nodes[0][0]+=0.001
			"connectivity":w.document.data.mesh.elements[0].reverse()
			"geometry":w.document.data.parts[0].position[0]+=0.01
			"material":w.document.data.parts[0].material.E*=2
			"load":w.document.data.parts[0].force[1]+=1
		if w.results_current():fail("Accepted stale "+dependency);return
		w.document.data=original
		if not w.results_current():fail("Original result lost");return
	w.render_model();await capture(fixture+"-reopened")
	print("STEP_CALCULIX_WORKBENCH_PASS ",fixture," nodes=",w.document.data.mesh.nodes.size()," elements=",w.document.data.mesh.elements.size()," max_displacement=",w.document.data.results.max_displacement)
	w.queue_free();await process_frame;quit()

