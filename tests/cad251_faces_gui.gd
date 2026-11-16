extends SceneTree
var out=OS.get_environment("UNICORE_FACE_OUT")
var w
var events=[]
func _initialize():call_deferred("run")
func capture(name: String):
	for width in [1280,1920]:
		root.size=Vector2i(width,720 if width==1280 else 1080)
		for i in 10:await process_frame
		RenderingServer.force_draw(false)
		root.get_texture().get_image().save_png(out+"/"+name+"-"+str(width)+".png")
func buttons(node: Node,text: String) -> Array:
	var result=[]
	if node is Button and node.text==text:result.append(node)
	for child in node.get_children():result.append_array(buttons(child,text))
	return result
func click_face(index: int,face_id: String) -> bool:
	var p=w.document.data.parts[index]
	var source=w.document.data.mesh if not w.document.data.mesh.is_empty() else w.cad_preview
	var triangles=source.surface_regions[p.id][face_id]
	for triangle in triangles.slice(0,100):
		var center=Vector3.ZERO
		for n in triangle:
			var xyz=source.nodes[int(n)];center+=Vector3(xyz[0],xyz[1],xyz[2])/3
		var screen=w.cad.camera.unproject_position(center)
		var event=InputEventMouseButton.new();event.position=screen;event.button_index=MOUSE_BUTTON_LEFT;event.pressed=true
		w.cad.navigate(event)
		if w.selected==index and w.face.get_item_text(w.face.selected)==face_id:
			events.append({"instance":p.instance_uuid,"face":face_id,"pixel":[screen.x,screen.y],"ray_pick":true})
			return true
	return false
func run():
	w=load("res://ui/cae/cae_workspace.gd").new();root.add_child(w);w.set_active(true)
	assert(w.document.open_project(out+"/duplicate2.json").is_empty())
	w.selection_mode.select(1);w.cad.set_view("Top",false);w.fit_model()
	for i in 10:await process_frame
	for k in 2:
		var p=w.document.data.parts[k];var highest="";var hi=-INF
		for key in p.cad_faces:
			if p.cad_face_centers[key][1]>hi:hi=p.cad_face_centers[key][1];highest=key
		assert(click_face(k,highest),"Actual viewport face pick failed")
		await capture("instance-selected-"+str(k))
	for order in [1,2]:
		assert(w.document.open_project(out+"/duplicate"+str(order)+".json").is_empty())
		w.solve()
		while w.solve_thread!=null:await process_frame
		assert(w.document.data.results.get("ok",false))
		w.select_result_field("displacement");await capture("tet"+str(order)+"-result")
	w.show_results=false
	assert(w.document.open_project(out+"/step2.json").is_empty())
	w.cad.set_view("Top",false);w.fit_model();w.select_body(1)
	for i in 10:await process_frame
	assert(click_face(1,w.document.data.parts[1].load_face))
	await capture("rotated-step-selected")
	# Genuine native equal-area/equal-centroid ambiguity fixture.
	var source=JSON.parse_string(FileAccess.get_file_as_string(out+"/symmetric-part.json"))
	w.document.data={"schema":1,"revision":0,"units":"m-N-Pa-kg","parts":[source],"mesh":{},"results":{}}
	preload("res://core/cae/assembly_model.gd").synchronize(w.document.data);w.document.changed.emit();w.select_body(0)
	assert(w.document.data.parts[0].boundary_refs.load_face.state=="unresolved")
	while w.cad_preview_thread!=null:await process_frame
	await capture("ambiguous-unresolved")
	buttons(w,"Review shared definition faces...")[0].pressed.emit()
	for child in w.get_children():
		if child is AcceptDialog and child.title=="Review definition face identity":child.confirmed.emit();child.hide()
	while w.cad_geometry_thread!=null or w.cad_preview_thread!=null:await process_frame
	var p=w.document.data.parts[0]
	assert(p.boundary_refs.load_face.state=="unresolved")
	w.select_body(0);w.cad.set_view("Top",false);w.fit_model()
	await capture("explicit-reassignment")
	var lower="";var upper="";var lo=INF;var hi=-INF
	for key in p.cad_faces:
		var y=p.cad_face_centers[key][1]
		if y<lo:lo=y;lower=key
		if y>hi:hi=y;upper=key
	w.cad.set_view("Bottom",false)
	for i in 10:await process_frame
	assert(click_face(0,lower))
	buttons(w,"Reassign support")[0].pressed.emit()
	assert(w.document.data.parts[0].boundary_refs.support.state=="resolved")
	assert(w.cad_preview_thread==null,"Boundary-only assignment must reuse native preview")
	events.append({"assignment":"support","native_preview_reused":true})
	while w.cad_preview_thread!=null:await process_frame
	w.cad.set_view("Top",false)
	for i in 10:await process_frame
	assert(click_face(0,upper))
	buttons(w,"Reassign force")[0].pressed.emit()
	assert(w.document.data.parts[0].boundary_refs.load_face.state=="resolved")
	assert(w.cad_preview_thread==null,"Boundary-only assignment must reuse native preview")
	events.append({"assignment":"force","native_preview_reused":true})
	while w.cad_preview_thread!=null:await process_frame
	assert(w.document.save_project(out+"/gui-reassigned.json")==OK)
	assert(w.document.open_project(out+"/gui-reassigned.json").is_empty())
	w.select_body(0);await capture("reopened-reassignment")
	var f=FileAccess.open(out+"/gui-picks.json",FileAccess.WRITE);f.store_string(JSON.stringify(events,"  "));f.close()
	w.queue_free();await process_frame
	print("FACE_GUI_PASS ",events.size()," verified face clicks");quit()
