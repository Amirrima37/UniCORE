extends SceneTree
var rows: Array=[]
func controls(node: Node) -> Array:
	var found: Array=[]
	for child in node.get_children():
		found.append(child);found.append_array(controls(child))
	return found
func press(w,text: String,directory: String=""):
	for control in controls(w.properties):
		if control is Button and control.text==text and (directory.is_empty() or control.get_meta("job_directory","")==directory):
			control.pressed.emit();return
	push_error("Missing UI button: "+text);quit(1)
func probe_regions(w,current_results: bool=true):
	if current_results:w.show_result_inspector()
	if current_results and w.document.data.results.has("displacement"):w.deformation_scale=100
	if current_results:press(w,"Pick solver element")
	else:w.activate_mesh_pick("element")
	assert(not current_results or w.deformation_scale==0 or not w.document.data.results.has("displacement"))
	w.prepare_mesh_inspection()
	var deadline:=Time.get_ticks_msec()+15000
	while w.inspection_mesh_key.is_empty() and Time.get_ticks_msec()<deadline:await process_frame
	assert(not w.inspection_mesh_key.is_empty())
	var part: Dictionary=w.document.data.parts[0]
	var mesh: Dictionary=w.document.data.mesh
	var center:=Vector3(part.position[0],part.position[1],part.position[2])
	var basis:=Basis.from_euler(Vector3(part.rotation[0],part.rotation[1],part.rotation[2]))
	for region in mesh.surface_regions[part.id]:
		var direction:=Vector3(2,1,2).normalized()
		if region in ["InnerWall","OutletEnd","Top","PositiveY"]:direction=Vector3.UP
		if region in ["InletEnd","Bottom","NegativeY"]:direction=Vector3.DOWN
		direction=basis*direction
		w.camera.global_position=center+direction*maxf(part.dimensions[0],part.dimensions[1])*4
		w.camera.look_at(center,Vector3.FORWARD if absf(direction.dot(Vector3.UP))>0.95 else Vector3.UP)
		var targets: Dictionary={}
		for face in mesh.surface_regions[part.id][region]:
			var sorted: Array=face.duplicate();sorted.sort();targets[str(sorted)]=true
		var found:=false
		for face in mesh.surface_regions[part.id][region]:
			var position:=Vector3.ZERO
			for id in face:position+=w.mesh_inspection.point(id)/3
			var screen: Vector2=w.camera.unproject_position(position)
			var hit: Dictionary=w.mesh_inspection.pick(w.camera,screen,false)
			if hit.is_empty():continue
			var sorted: Array=hit.face.duplicate();sorted.sort()
			if not targets.has(str(sorted)):continue
			w.inspect_mesh_click(screen)
			assert(is_instance_valid(w.selection_highlight) and w.selection_highlight.get_meta("element")==hit.element)
			assert(mesh.material_regions[hit.element]==part.id)
			if current_results:
				var r: Dictionary=w.document.data.results
				var expected: String="Stored element stress (Pa): "+str(r.stress[hit.element]) if r.has("stress") else "Stored element flux (W/m^2): "+str(r.heat_flux[hit.element])
				var matched:=false
				for label in controls(w.properties):
					if label is Label and label.text.contains(expected):matched=true
				assert(matched,"Probe must expose original element values")
			var node_screen: Vector2=w.camera.unproject_position(w.mesh_inspection.point(hit.face[0]))
			var node: Dictionary=w.mesh_inspection.pick(w.camera,node_screen,true)
			assert(not node.is_empty() and node.node>=0 and node.node<mesh.nodes.size())
			w.mesh_pick_mode="node";w.inspect_mesh_click(node_screen)
			assert(is_instance_valid(w.selection_highlight))
			w.mesh_pick_mode="element"
			found=true;break
		assert(found,"No visible hit for "+region)
	print("Region element/node ownership PASS ",part.kind)

func _initialize():
	var w=load("res://ui/cae/cae_workspace.gd").new()
	root.add_child.call_deferred(w);await process_frame;w.set_active(true)
	var jobs=load("res://core/cae/extreme_jobs.gd").new()
	for kind in ["Cylinder","Sphere","Pipe"]:
		print("UI create ",kind)
		w.new_project();w.create_part(kind)
		assert(w.selected==0 and w.document.data.parts.size()==1)
		w.run_command("SetParameters",{"parameters":{"radius":0.1} if kind=="Sphere" else {"diameter":0.2,"length":0.1}})
		w.run_command("AssignMaterial",{"material":{"name":"Workbench fixture","E":1000.0,"nu":0.0,"density":1.0,"k":10.0,"cp":1.0}})
		if kind=="Pipe":w.run_command("SetParameters",{"parameters":{"inner_radius":0.05}})
		for study in ["static_structural","steady_thermal"]:
			print("UI configure ",kind," ",study)
			w.run_command("ClearAnalysisConditions")
			w.document.execute("SetAnalysis",{"analysis":{"type":study,"element":"TET4"}})
			var first: String="OuterSurface" if kind=="Sphere" else "InletEnd" if kind=="Pipe" else "Bottom"
			var second: String="OuterSurface" if kind=="Sphere" else "OutletEnd" if kind=="Pipe" else "Top"
			if study=="static_structural":
				if kind=="Sphere":w.run_command("ApplySphereExpansion",{"strain":0.001})
				else:
					w.run_command("ApplySupport",{"face":first})
					w.run_command("ApplyLoad",{"face":second,"force":[0,1,0]})
			else:
				w.run_command("ApplyThermalBoundary",{"boundary":{"face":first,"kind":"temperature","value":300.0}})
				if kind=="Sphere":w.run_command("SetHeatSource",{"value":6000.0})
				else:w.run_command("ApplyThermalBoundary",{"boundary":{"face":second,"kind":"temperature","value":400.0}})
			w.divisions.value=2;w.generate_analysis_mesh()
			for i in w.face.item_count:
				w.face.select(i);w.show_selected_face();assert(is_instance_valid(w.face_highlight))
			w.solve() # Must route to the Extreme workspace, without a box-only solve thread.
			assert(w.solve_thread==null)
			print("UI launch ",kind," ",study)
			press(w,"Start independent job")
			var directory: String=w.last_extreme_directory;assert(not directory.is_empty())
			var deadline:=Time.get_ticks_msec()+15000
			while jobs.status(directory).get("state")!="Completed" and Time.get_ticks_msec()<deadline:await process_frame
			assert(jobs.status(directory).get("state")=="Completed")
			w.open_extreme_mode();press(w,"Open completed results",directory)
			assert(w.results_current() and w.show_results)
			var result: Dictionary=w.document.data.results
			assert(w.document.data.mesh.nodes==result.nodes and w.document.data.mesh.elements==result.elements)
			for field in (["displacement","von_mises"] if study=="static_structural" else ["temperature"]):
				w.select_result_field(field);assert(w.results_current())
			w.show_result_inspector();press(w,"Show / hide viewport legend");assert(not w.viewport_legend.visible)
			press(w,"Show / hide viewport legend");assert(w.viewport_legend.visible)
			if study=="steady_thermal":
				press(w,"Temperature / heat-flux magnitude");assert(w.thermal_field=="heat_flux")
				var arrows: bool=w.show_flux_arrows
				press(w,"Heat-flux arrows");assert(w.show_flux_arrows!=arrows)
				press(w,"Heat-flux arrows");assert(w.show_flux_arrows==arrows)
				var normalized: bool=w.normalize_flux
				press(w,"Normalize arrows");assert(w.normalize_flux!=normalized)
				press(w,"Normalize arrows");assert(w.normalize_flux==normalized)
				press(w,"Temperature / heat-flux magnitude");assert(w.thermal_field=="temperature")
			await probe_regions(w)
			var saved: Dictionary=w.document.data.duplicate(true)
			assert(w.document.save_project("res://.tools/stage6-ui.ucae")==OK)
			assert(w.document.open_project("res://.tools/stage6-ui.ucae").is_empty())
			assert(not jobs.load_result(directory,w.document.data).is_empty())
			for edit in [{"command":"SetParameters","parameters":{"radius":0.11}}, {"command":"SetRotation","values":[0.2,0.3,-0.1]},{"command":"SetPosition","values":[1,-2,3]},{"command":"SetScale","values":[1.1,1.1,1.1]},{"command":"AssignMaterial","material":{"name":"Edited","E":2000.0,"nu":0.0,"density":1.0,"k":20.0,"cp":1.0}}]:
				var args: Dictionary=edit.duplicate();args.index=0
				assert(w.document.execute(edit.command,args).is_empty())
				assert(w.document.generate_mesh(2).is_empty())
				assert(jobs.load_result(directory,w.document.data).is_empty())
				if edit.command=="SetRotation":await probe_regions(w,false)
				w.document.undo();assert(not jobs.load_result(directory,w.document.data).is_empty())
				w.document.redo();assert(jobs.load_result(directory,w.document.data).is_empty());w.document.undo()
			assert(w.document.generate_mesh(1).is_empty());assert(jobs.load_result(directory,w.document.data).is_empty())
			w.document.data=saved;w.document.changed.emit();w.select_result_field("displacement" if study=="static_structural" else "temperature")
			if kind!="Cylinder":
				w.fit_model();w.cad.distance*=0.5;w.cad.update_camera()
				for size in [Vector2i(1280,720),Vector2i(1920,1080)]:
					root.size=size;w.cad.invalidate()
					for i in 6:await process_frame
					RenderingServer.force_draw()
					root.get_texture().get_image().save_png("res://docs/workbench-2/stage6-ui-%s-%s-%d.png"%[kind,study,size.x])
			rows.append({"geometry":kind,"study":study,"nodes":result.nodes.size(),"elements":result.elements.size(),"residual":result.get("relative_residual"),"ui_launch_import":true,"edit_undo_redo_cases":5})
			var progress=FileAccess.open("res://docs/workbench-2/stage6-ui-progress.json",FileAccess.WRITE);progress.store_string(JSON.stringify(rows,"  "));progress.close()
			print(kind," ",study," UI PASS")
	w.queue_free();await process_frame
	var file=FileAccess.open("res://docs/workbench-2/stage6-ui-results.json",FileAccess.WRITE);file.store_string(JSON.stringify(rows,"  "))
	quit()
