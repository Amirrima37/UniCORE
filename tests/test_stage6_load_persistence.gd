extends SceneTree
func all(node: Node) -> Array:
	var out: Array=[]
	for child in node.get_children():out.append(child);out.append_array(all(child))
	return out
func press(w,text: String):
	for item in all(w.properties):
		if item is Button and item.text==text:item.pressed.emit();return
	push_error("Missing field button "+text);quit(1)
func _initialize():
	var w=load("res://ui/cae/cae_workspace.gd").new();root.add_child.call_deferred(w);await process_frame;w.set_active(true)
	var jobs=load("res://core/cae/extreme_jobs.gd").new();var seen: Dictionary={};var names: Array=Array(jobs.jobs());var inspected:=0
	for name in names:
		inspected+=1
		if inspected>250:break
		var path: String="user://extreme_jobs/"+name
		if jobs.status(path).get("state")!="Completed":continue
		var snapshot=JSON.parse_string(FileAccess.get_file_as_string(path+"/project.json"))
		if not snapshot is Dictionary or snapshot.parts.size()!=1:continue
		var kind: String=snapshot.parts[0].kind;var study: String=snapshot.get("analysis",{}).get("type","")
		if kind not in ["Cylinder","Sphere","Pipe"] or study not in ["static_structural","steady_thermal"]:continue
		var key: String=kind+study
		if seen.has(key):continue
		var loaded: Dictionary=jobs.load_result(path)
		if loaded.is_empty():continue
		w.document.data=loaded;w.document.changed.emit();w.select_body(0)
		if kind=="Sphere":
			w.select_result_field("temperature" if study=="steady_thermal" else "displacement")
			w.show_result_inspector()
			if study=="steady_thermal":
				var temperatures: Array=w.document.data.results.temperature.duplicate()
				var celsius: bool=w.celsius
				press(w,"Kelvin / Celsius");assert(w.celsius!=celsius);press(w,"Kelvin / Celsius");assert(w.celsius==celsius)
				for selection in [2,0]:
					for item in all(w.properties):
						if item is OptionButton and item.item_count==4 and item.get_item_text(0)=="temperature":item.select(selection);item.item_selected.emit(selection);break
				assert(w.thermal_palette=="temperature")
				for item in all(w.properties):
					if item is SpinBox:
						var label=item.get_parent().get_child(0)
						if label is Label:
							if label.text=="Display minimum":item.value=300
							if label.text=="Display maximum":item.value=400
							if label.text=="Arrow stride":item.value=4
							if label.text=="Temperature isolines":item.value=1
				press(w,"Apply physical color range");assert(w.thermal_low==300 and w.thermal_high==400)
				press(w,"Automatic range");assert(is_nan(w.thermal_low) and is_nan(w.thermal_high))
				var fixed: bool=w.fixed_thermal_scale
				press(w,"Fixed / per-frame range");assert(w.fixed_thermal_scale!=fixed);press(w,"Fixed / per-frame range")
				assert(w.document.data.results.temperature==temperatures)
			else:
				press(w,"Automatic display scale (10% diagonal)");assert(w.deformation_scale==w.automatic_deformation_scale())
				press(w,"True scale");assert(w.deformation_scale==1)
		var condition: String="prescribed" if kind=="Sphere" else "load_face"
		if study=="steady_thermal":
			var boundaries: Array=w.document.data.parts[0].get("thermal",[])
			if boundaries.is_empty():continue
			condition="thermal:"+boundaries[0].kind+":"+boundaries[0].face
		w.inspect_condition({"body":0,"key":condition})
		var changed:=false
		for item in all(w.properties):
			if item is SpinBox:item.value=301 if study=="steady_thermal" else 0.002 if kind=="Sphere" else 2;changed=true;break
		assert(changed)
		for item in all(w.properties):
			if item is Button and item.text=="Apply values":item.pressed.emit();break
		assert(jobs.load_result(path,w.document.data).is_empty())
		assert(w.document.generate_mesh(2).is_empty())
		var part: Dictionary=w.document.data.parts[0]
		for region in w.Document.surface_names(part):
			assert(not w.document.data.mesh.surface_regions[part.id][region].is_empty())
		assert(w.document.save_project("res://.tools/stage6-load.ucae")==OK)
		var reopened=load("res://core/cae/cae_document.gd").new();assert(reopened.open_project("res://.tools/stage6-load.ucae").is_empty())
		assert(reopened.data.parts==JSON.parse_string(JSON.stringify(w.document.data.parts,"",true,true)) and reopened.data.mesh.regions==JSON.parse_string(JSON.stringify(w.document.data.mesh.regions,"",true,true)))
		w.document.undo();assert(not jobs.load_result(path,w.document.data).is_empty())
		w.document.redo();assert(jobs.load_result(path,w.document.data).is_empty())
		seen[key]=true;print(kind," ",study," load/BC edit persistence PASS")
		if seen.size()==6:break
	assert(seen.size()==6)
	w.queue_free();await process_frame;quit()
