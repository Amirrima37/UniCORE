extends SceneTree
var failures := 0
func check(ok: bool, title: String) -> void:
	if not ok: failures+=1; push_error(title)
func _initialize():
	var w=load("res://ui/cae/cae_workspace.gd").new()
	root.add_child.call_deferred(w)
	await process_frame
	w.set_active(true)
	w.create_part("Box")
	w.create_part("Cylinder")
	w.run_command("SetPosition",{"values":[0.25,0,0]})
	w.fit_model()
	for i in 8: await process_frame
	w.cad.pick(w.camera.unproject_position(w.cad.meshes[1].global_position))
	check(w.selected==1,"Viewport triangle picking selects cylinder")
	w.tree_items[0].select(0)
	check(w.selected==0,"Explorer selection synchronizes inspector")
	w.select_body(1)
	var original_inspector=w.name_edit
	var original_tree=w.tree_items[1]
	# Edit the bound diameter control in the inspector, rather than a separate document fixture.
	var diameter=w.inspector_bindings[0].node
	diameter.value=160
	check(is_equal_approx(w.document.data.parts[1].dimensions[0],0.16),"Diameter edit reaches SI document")
	check(is_equal_approx(w.inspector_bindings[1].node.value,80),"Radius follows diameter")
	check(w.name_edit==original_inspector,"Small edit retains inspector controls")
	check(w.tree_items[1]==original_tree,"Small edit retains explorer items")
	w.document.undo()
	check(is_equal_approx(w.document.data.parts[1].dimensions[0],0.1),"Undo dimension")
	w.document.redo()
	check(is_equal_approx(w.document.data.parts[1].dimensions[0],0.16),"Redo dimension")
	var revision=w.document.data.revision
	w.run_command("SetParameters",{"parameters":{"diameter":-1}})
	check(w.document.data.revision==revision,"Invalid dimension rejected without revision change")
	check("positive" in w.status.text,"Invalid dimension feedback")
	w.open_material_library()
	var editor=w.material_editor
	check(not editor.visible_records.is_empty(),"Existing material browser populated")
	var record: Dictionary=editor.visible_records[0]
	editor.material_chosen.emit(record)
	check(w.document.data.parts[1].material.name==record.name,"Library assignment reaches document")
	editor.hide()
	w.select_body(0)
	w.tree.get_root().get_first_child().collapsed=true
	w.run_command("Rename",{"name":"Structural block"})
	check(w.tree.get_root().get_first_child().collapsed,"Explorer expansion survives rebuild")
	w.outer_split.split_offset=235
	w.run_command("SetParameters",{"parameters":{"length":0.2}})
	check(w.outer_split.split_offset==235,"Panel width retained during editing")
	# Only boxes have a supported volume mesher: hide/delete the display primitive first.
	w.document.execute("Delete",{"index":1})
	w.run_command("ApplySupport",{"face":"X-"})
	w.run_command("ApplyLoad",{"face":"X+","force":[10,0,0]})
	w.divisions.value=2
	w.generate_analysis_mesh()
	check(not w.document.data.mesh.is_empty(),"Supported volume mesh generated")
	w.open_analysis_editor()
	check(w.analysis_editor.visible,"Simulation settings accessible")
	w.analysis_editor.hide()
	w.solve()
	var deadline=Time.get_ticks_msec()+30000
	while w.solve_thread!=null and Time.get_ticks_msec()<deadline: await process_frame
	check(w.results_current(),"Native result current")
	check(w.tool_requirement("Results","Displacement").is_empty(),"Structural displacement field available")
	check(not w.tool_requirement("Results","Temperature").is_empty(),"Unavailable thermal field disabled")
	w.show_result_inspector()
	check(w.properties.get_child_count()>0,"Available result fields inspected")
	for tab in ["Home","Geometry","Materials","Mesh","Loads & Constraints","Simulation","Results","Inspection"]:
		w.active_ribbon=tab
		w.populate_ribbon()
		check(not w.ribbon_buttons.is_empty(),"Functional ribbon group "+tab)
	print("Stage 2 workflow failures=",failures)
	w.queue_free()
	await process_frame
	quit(0 if failures==0 else 1)
