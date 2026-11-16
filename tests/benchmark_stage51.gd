extends SceneTree
func _initialize():
	create_timer(150).timeout.connect(func():quit(2))
	var label: String=OS.get_environment("UNICORE_STAGE51_VARIANT")
	if label.is_empty():label="baseline"
	var rows:=[]
	var w=load("res://ui/cae/cae_workspace.gd").new()
	root.add_child.call_deferred(w);await process_frame
	w.set_active(true)
	var manager=load("res://core/cae/extreme_jobs.gd").new()
	var paths: Dictionary={}
	if FileAccess.file_exists("res://.tools/stage51-fixtures.json"):paths=JSON.parse_string(FileAccess.get_file_as_string("res://.tools/stage51-fixtures.json"))
	for kind in ["Box","Cylinder"]:
		for study in ["static_structural","steady_thermal"]:
			var name: String=kind+"-"+study
			if not paths.has(name):
				var doc=load("res://core/cae/cae_document.gd").new()
				doc.execute("CreatePart",{"kind":kind})
				if kind=="Cylinder":doc.execute("SetParameters",{"index":0,"parameters":{"diameter":0.2,"length":0.4}})
				doc.execute("AssignMaterialById",{"index":0,"material_id":"Aluminum 6061-T6" if study=="static_structural" else "Stainless steel 316"})
				doc.execute("SetAnalysis",{"analysis":{"type":study,"element":"HEX8" if kind=="Box" and study=="static_structural" else "TET4"}})
				var bottom: String="X-" if kind=="Box" else "Bottom"
				var top: String="X+" if kind=="Box" else "Top"
				if study=="static_structural":
					doc.execute("ApplySupport",{"index":0,"face":bottom})
					doc.execute("ApplyLoad",{"index":0,"face":top,"force":[100,0,0] if kind=="Box" else [0,100,0]})
				else:
					for entry in [[bottom,300],[top,400]]:doc.execute("ApplyThermalBoundary",{"index":0,"boundary":{"kind":"temperature","face":entry[0],"value":entry[1]}})
				assert(doc.generate_mesh(2 if kind=="Box" else 4).is_empty())
				paths[name]=manager.launch(doc,1,256)
				assert(not paths[name].is_empty(),manager.last_error)
				while manager.status(paths[name]).get("state")!="Completed":
					assert(manager.status(paths[name]).get("state")!="Failed")
					await process_frame
				var file=FileAccess.open("res://.tools/stage51-fixtures.json",FileAccess.WRITE);file.store_string(JSON.stringify(paths));file.close()
			var snapshot: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(paths[name]+"/project.json"))
			var imported: Dictionary
			for sample in 5:
				var tick:=Time.get_ticks_usec()
				imported=manager.load_result(paths[name],snapshot)
				assert(not imported.is_empty(),manager.last_error)
				rows.append({"case":name,"operation":"import","sample":sample,"ms":(Time.get_ticks_usec()-tick)/1000.0,"phases":manager.timings.duplicate(true)})
			w.document.data=imported;w.thermal_display_key="";w.overlay_key=[];w.inspection_mode="";w.quality_metric="";w.thermal_frame=-1;w.show_flux_arrows=false
			var fields: Array=["displacement","von_mises"] if study=="static_structural" else ["temperature","heat_flux"]
			for sample in 6:
				var field: String=fields[sample%2]
				w.post_timings={}
				var tick:=Time.get_ticks_usec()
				if study=="static_structural":w.select_result_field(field)
				else:
					w.thermal_field=field;w.select_result_field("temperature")
				var elapsed: float=(Time.get_ticks_usec()-tick)/1000.0
				rows.append({"case":name,"operation":"switch","field":field,"sample":sample,"ms":elapsed,"phases":w.post_timings.duplicate(true)})
				await process_frame
			if study=="static_structural":
				var display=load("res://core/cae/structural_display.gd").new()
				for sample in 3:
					var built=display.build(imported.results,"von_mises",1.0)
					assert(not built.has("error"))
					rows.append({"case":name,"operation":"build","phases":display.timings.duplicate(true)})
	var output=FileAccess.open("res://docs/workbench-2/stage51-"+label+".json",FileAccess.WRITE);output.store_string(JSON.stringify(rows,"\t"));output.close()
	w.queue_free();await process_frame
	print("Stage51 benchmark ",label," PASS rows=",rows.size())
	quit()
