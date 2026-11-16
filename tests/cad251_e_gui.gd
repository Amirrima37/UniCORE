extends SceneTree
var out=OS.get_environment("UNICORE_E_GUI_OUT")
var source=OS.get_environment("UNICORE_D_SOURCE")
var w
var events=[]
func _initialize():print("GUI_INITIALIZED");call_deferred("run")
func buttons(node: Node,text: String) -> Array:
	var result=[]
	if node is Button and node.text==text:result.append(node)
	for child in node.get_children():result.append_array(buttons(child,text))
	return result
func settle():
	var deadline=Time.get_ticks_msec()+180000
	while w.cad_preview_thread!=null or w.external_mesh_thread!=null or w.solve_thread!=null or w.cad_geometry_thread!=null:
		if Time.get_ticks_msec()>deadline:push_error("GUI job wait exceeded 180 seconds");quit(1);return
		await process_frame
	for i in 6:await process_frame
func capture(title: String):
	print("GUI_CAPTURE ",title)
	w.cad.set_view("Perspective",false);w.fit_model()
	for width in [1280,1920]:
		root.size=Vector2i(width,720 if width==1280 else 1080)
		for i in 10:await process_frame
		RenderingServer.force_draw(false)
		assert(root.get_texture().get_image().save_png(out+"/"+title+"-"+str(width)+".png")==OK)
func pick(index: int,id: String) -> bool:
	var part=w.document.data.parts[index];var display=w.cad_display_source()
	for triangle in display.surface_regions[part.id][id].slice(0,150):
		var center=Vector3.ZERO
		for n in triangle:
			var xyz=display.nodes[int(n)];center+=Vector3(xyz[0],xyz[1],xyz[2])/3
		var event=InputEventMouseButton.new();event.position=w.cad.camera.unproject_position(center);event.button_index=MOUSE_BUTTON_LEFT;event.pressed=true
		w.cad.navigate(event)
		if w.selected==index and w.face.get_item_text(w.face.selected)==id:
			events.append({"ray_pick":true,"instance":part.instance_uuid,"face":id});return true
	return false
func run():
	print("GUI_RUN")
	w=load("res://ui/cae/cae_workspace.gd").new();root.add_child(w);w.set_active(true)
	w.section_state.Identity=true
	# Exercise existing creation/duplication controls before the native STEP workflow.
	w.create_part("Box");w.run_command("Duplicate")
	assert(w.document.data.parts.size()==2 and w.document.data.parts[0].definition_uuid==w.document.data.parts[1].definition_uuid)
	w.run_command("Delete");w.select_body(0);w.run_command("Delete")
	w.import_step_dialog();w.dialog.file_selected.emit(ProjectSettings.globalize_path("res://tests/fixtures/step/bar.step"));w.dialog.hide()
	print("GUI_IMPORTED")
	await settle();w.select_body(0)
	w.run_command("Rename",{"name":"STEP reusable / A"});w.run_command("Duplicate")
	w.run_command("Rename",{"name":"STEP reusable / B"});w.run_command("SetPosition",{"values":[2.0,0,0]});w.run_command("SetRotation",{"values":[0,0,.3]})
	await settle()
	assert(w.document.data.parts[0].definition_uuid==w.document.data.parts[1].definition_uuid)
	for k in 2:
		w.select_body(k)
		w.run_command("AssignMaterial",{"material":{"name":"Independent "+str(k+1),"E":100e9*(k+1),"nu":0.0,"density":7800.0}})
		var p=w.document.data.parts[k];var lower="";var upper="";var lo=INF;var hi=-INF
		for face in p.cad_faces:
			var y=p.cad_face_centers[face][1]
			if y<lo:lo=y;lower=face
			if y>hi:hi=y;upper=face
		w.selection_mode.select(1);w.cad.set_view("Bottom",false);w.fit_model();await settle()
		assert(pick(k,lower),"Support viewport pick")
		buttons(w,"Assign support")[0].pressed.emit()
		w.cad.set_view("Top",false);await settle()
		assert(pick(k,upper),"Load viewport pick")
		var angle=.3 if k==1 else 0.0
		for axis in 3:w.force_fields[axis].value=[-sin(angle)*1000,cos(angle)*1000,0][axis]
		buttons(w,"Assign force")[0].pressed.emit()
		await capture("independent-face-"+str(k))
	await capture("transformed-step-materials")
	# Distinct real controls, document state, and Undo/Redo.
	w.select_body(1);buttons(w,"Include in analysis")[0].button_pressed=false
	assert(not w.document.data.parts[1].analysis_enabled and w.document.data.parts[1].visible)
	await settle();w.cad.set_view("Top",false);w.fit_model()
	await capture("visible-excluded")
	w.document.undo();assert(w.document.data.parts[1].analysis_enabled)
	w.document.redo();assert(not w.document.data.parts[1].analysis_enabled)
	buttons(w,"Visible")[0].button_pressed=false
	assert(not w.document.data.parts[1].visible and not w.document.data.parts[1].analysis_enabled)
	buttons(w,"Include in analysis")[0].button_pressed=true
	assert(not w.document.data.parts[1].visible and w.document.data.parts[1].analysis_enabled)
	await capture("hidden-enabled")
	buttons(w,"Visible")[0].button_pressed=true
	await capture("reenabled-instance")
	for order in [1,2]:
		for p in w.document.data.parts:
			p.mesh_settings=preload("res://core/cae/mesh_config.gd").defaults(.05);p.mesh_settings.schema=2;p.mesh_settings.order=order
		w.document.data.analysis.element="TET10" if order==2 else "TET4"
		w.generate_analysis_mesh();await settle();assert(not w.document.data.mesh.is_empty())
		w.solve();await settle();assert(w.document.data.results.get("ok",false) and w.results_current())
		w.select_result_field("displacement");await capture("tet"+str(order)+"-displacement")
		w.select_result_field("von_mises");await capture("tet"+str(order)+"-stress")
		events.append({"solve":true,"order":order,"job":ProjectSettings.globalize_path(w.native_solver.directory),"completion":w.document.data.results.completion})
	# Regenerate with a visible excluded CAD instance: it remains real and pickable.
	w.show_results=false;w.select_body(1);buttons(w,"Include in analysis")[0].button_pressed=false
	w.generate_analysis_mesh();await settle();assert(not w.document.data.mesh.is_empty())
	assert(not w.document.data.mesh.surface_regions.has(w.document.data.parts[1].id))
	assert(w.cad.instances[w.document.data.parts[1].id].visible and w.cad.instances[w.document.data.parts[1].id].mesh!=null)
	w.cad.set_view("Top",false);w.fit_model();await settle()
	assert(pick(1,w.document.data.parts[1].load_face),"Excluded visible body remains pickable after active-only meshing")
	await capture("excluded-after-meshing")
	w.solve();await settle();assert(w.document.data.results.get("ok",false))
	w.show_results=false;w.select_body(1);buttons(w,"Include in analysis")[0].button_pressed=true
	w.run_command("SetPosition",{"values":[0,0,0]});w.run_command("SetRotation",{"values":[0,0,0]});await settle()
	w.generate_analysis_mesh();await settle();assert(w.document.data.mesh.is_empty())
	w.console_panel.visible=true
	await capture("rejected-active-overlap")
	w.document.undo();w.document.undo();await settle();w.console_panel.visible=false
	assert(w.document.save_project(out+"/gui-restored.json")==OK)
	assert(w.document.open_project(out+"/gui-restored.json").is_empty());await settle()
	w.select_body(1);w.fit_model();await capture("save-reopen")
	# Existing explicit native review and reassignment, never automatic migration.
	var part=JSON.parse_string(FileAccess.get_file_as_string(source+"/symmetric-part.json"))
	w.document.data={"schema":1,"revision":0,"units":"m-N-Pa-kg","parts":[part],"mesh":{},"results":{}}
	preload("res://core/cae/assembly_model.gd").synchronize(w.document.data);w.document.changed.emit();w.select_body(0);await settle()
	assert(w.document.data.parts[0].boundary_refs.load_face.state=="unresolved")
	await capture("unresolved-warning")
	buttons(w,"Review shared definition faces...")[0].pressed.emit()
	for child in w.get_children():
		if child is AcceptDialog and child.title=="Review definition face identity":child.confirmed.emit();child.hide()
	await settle();w.select_body(0);await capture("explicit-reassignment")
	var p=w.document.data.parts[0];var lower="";var upper="";var lo=INF;var hi=-INF
	for key in p.cad_faces:
		var y=p.cad_face_centers[key][1]
		if y<lo:lo=y;lower=key
		if y>hi:hi=y;upper=key
	w.cad.set_view("Bottom",false);w.fit_model();await settle();assert(pick(0,lower));buttons(w,"Reassign support")[0].pressed.emit()
	w.cad.set_view("Top",false);await settle();assert(pick(0,upper));buttons(w,"Reassign force")[0].pressed.emit()
	assert(w.document.data.parts[0].boundary_refs.load_face.state=="resolved")
	assert(w.document.save_project(out+"/gui-reassigned.json")==OK)
	assert(w.document.open_project(out+"/gui-reassigned.json").is_empty());await settle()
	assert(w.document.data.parts[0].boundary_refs.load_face.state=="resolved")
	await capture("reassigned-reopened")
	var f=FileAccess.open(out+"/gui.json",FileAccess.WRITE);f.store_string(JSON.stringify(events,"  "));f.close()
	w.queue_free();w=null
	for i in 20:await process_frame
	root.print_orphan_nodes()
	print("FINAL_WORKBENCH_GUI_PASS");quit()
