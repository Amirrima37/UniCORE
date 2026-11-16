extends SceneTree
func all(node: Node) -> Array:
	var out: Array=[]
	for child in node.get_children():out.append(child);out.append_array(all(child))
	return out
func press(node: Node,text: String):
	for item in all(node):
		if item is Button and item.text==text:item.pressed.emit();return
	push_error("Missing button "+text);quit(1)
func edit(w,key: String,value: float):
	w.inspect_condition({"body":0,"key":key})
	for item in all(w.properties):
		if item is SpinBox:item.value=value;break
	press(w.properties,"Apply values")
func _initialize():
	var w=load("res://ui/cae/cae_workspace.gd").new();root.add_child.call_deferred(w);await process_frame;w.set_active(true)
	for kind in ["Cylinder","Sphere","Pipe"]:
		w.new_project();w.create_part(kind);w.open_analysis_editor()
		var e=w.analysis_editor
		e.analysis.select(0);e.populate();e.boundary.select(2);e.refresh_fields();e.face.select(1);e.numbers[0].value=10
		press(e,"Apply condition to selected body / face")
		assert(w.document.data.parts[0].pressure.value==10)
		e.hide();edit(w,"pressure",20);assert(w.document.data.parts[0].pressure.value==20)
		e.numbers[0].value=30;press(e,"Apply condition to selected body / face");assert(w.document.data.parts[0].pressure.value==30)
		w.inspect_condition({"body":0,"key":"pressure"});press(w.properties,"Delete condition (undo available)");assert(not w.document.data.parts[0].has("pressure"))
		for mode in ([0,1,3,5] if kind=="Sphere" else [0,1,3]):
			e.boundary.select(mode);e.refresh_fields();e.numbers[0].value=0.001 if mode in [3,5] else 1
			press(e,"Apply condition to selected body / face")
			var key: String="support" if mode==0 else "load_face" if mode==1 else "prescribed"
			if mode==3:
				assert(absf(w.document.data.parts[0].prescribed["values"][0]-0.001)<1e-12)
				edit(w,key,0.002);assert(absf(w.document.data.parts[0].prescribed["values"][0]-0.002)<1e-12)
			if mode==5:
				assert(absf(w.document.data.parts[0].prescribed.radial_strain-0.001)<1e-12)
				edit(w,key,0.002);assert(absf(w.document.data.parts[0].prescribed.radial_strain-0.002)<1e-12)
			w.inspect_condition({"body":0,"key":key});press(w.properties,"Delete condition (undo available)")
		# Rejected thermal condition must not first commit different study settings.
		e.analysis.select(1);e.populate();e.boundary.select(0);e.refresh_fields();e.face.select(0);e.numbers[0].value=-1
		var before: Dictionary=w.document.data.duplicate(true);var history: int=w.document.undo_stack.size()
		press(e,"Apply condition to selected body / face")
		assert(w.document.data==before and w.document.undo_stack.size()==history)
		e.numbers[0].value=300;press(e,"Apply condition to selected body / face")
		var face: String=e.face.get_item_text(e.face.selected)
		e.hide();edit(w,"thermal:temperature:"+face,310);assert(w.document.data.parts[0].thermal[0].value==310)
		e.numbers[0].value=320;press(e,"Apply condition to selected body / face")
		assert(w.document.data.parts[0].thermal.size()==1 and w.document.data.parts[0].thermal[0].value==320)
		if kind=="Sphere":
			e.face.select(1);e.boundary.select(1);e.refresh_fields();e.numbers[0].value=10
			before=w.document.data.duplicate(true);history=w.document.undo_stack.size();press(e,"Apply condition to selected body / face")
			assert(w.document.data==before and w.document.undo_stack.size()==history)
		assert(w.document.save_project("res://.tools/stage6-dialog.ucae")==OK)
		assert(w.document.open_project("res://.tools/stage6-dialog.ucae").is_empty())
		assert(w.document.data.parts[0].thermal[0].face==face and w.document.data.parts[0].thermal[0].value==320)
		w.inspect_condition({"body":0,"key":"thermal:temperature:"+face});press(w.properties,"Delete condition (undo available)")
		assert(w.document.data.parts[0].thermal.is_empty())
		for mode in [1,2,3,4]:
			e.boundary.select(mode);e.refresh_fields();e.numbers[0].value=0.5 if mode==4 else 10;e.numbers[1].value=300;e.use_material.button_pressed=false
			press(e,"Apply condition to selected body / face")
			var key: String="heat_source" if mode==3 else "thermal:"+({1:"flux",2:"convection",4:"radiation"}[mode])+":"+e.face.get_item_text(e.face.selected)
			edit(w,key,0.25 if mode==4 else 2)
			w.inspect_condition({"body":0,"key":key});press(w.properties,"Delete condition (undo available)")
			for entry in load("res://core/cae/condition_catalog.gd").entries(w.document.data.parts[0]):assert(entry.key!=key)
		print(kind," condition dialog create/edit/replace/delete/reject/persist PASS")
	w.queue_free();await process_frame;quit()
