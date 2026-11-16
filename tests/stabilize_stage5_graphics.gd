extends SceneTree
func _initialize():
	create_timer(90).timeout.connect(func():quit(2))
	var w=load("res://ui/cae/cae_workspace.gd").new()
	root.add_child.call_deferred(w)
	await process_frame
	w.set_active(true)
	w.create_part("Cylinder")
	w.run_command("SetParameters",{"parameters":{"length":0.4,"diameter":0.2}})
	w.run_command("AssignMaterialById",{"material_id":"Aluminum 6061-T6"})
	w.run_command("ApplySupport",{"face":"Bottom"})
	w.run_command("ApplyLoad",{"face":"Top","force":[0,100,0]})
	w.divisions.value=4
	w.generate_analysis_mesh()
	var evidence:=[]
	var timings:=[]
	var manager=load("res://core/cae/extreme_jobs.gd").new()
	for study in ["static_structural","steady_thermal"]:
		if study=="steady_thermal":
			w.run_command("AssignMaterialById",{"material_id":"Stainless steel 316"})
			w.document.execute("SetAnalysis",{"analysis":{"type":study,"element":"TET4"}})
			w.run_command("ApplyThermalBoundary",{"boundary":{"face":"Bottom","kind":"temperature","value":300}})
			w.run_command("ApplyThermalBoundary",{"boundary":{"face":"Top","kind":"temperature","value":400}})
			w.generate_analysis_mesh()
		var directory: String=manager.launch(w.document,1,256)
		assert(not directory.is_empty(),manager.last_error)
		while manager.status(directory).get("state")!="Completed":
			assert(manager.status(directory).get("state")!="Failed")
			await process_frame
		var samples:=[]
		var loaded: Dictionary
		for sample in 3:
			var start:=Time.get_ticks_usec()
			loaded=manager.load_result(directory,w.document.data)
			samples.append((Time.get_ticks_usec()-start)/1000.0)
		timings.append({"analysis":study,"operation":"import_parse_hash_validate","samples_ms":samples,"nodes":645,"elements":2688})
		assert(not loaded.is_empty(),manager.last_error)
		if study=="steady_thermal":
			var snapshot=JSON.parse_string(FileAccess.get_file_as_string(directory+"/project.json"))
			var raw=JSON.parse_string(FileAccess.get_file_as_string(directory+"/results.json"))
			var bad: Dictionary=raw.duplicate(true)
			bad.history=[[300]];bad.times=[0]
			assert("history mapping" in manager.validate_provenance(directory,snapshot,bad))
			bad=raw.duplicate(true);bad.erase("radiative_power_W")
			assert("radiation field" in manager.validate_provenance(directory,snapshot,bad))
			bad=raw.duplicate(true);bad.radiation_surface_nodes=[[0,1,999999]]
			assert("node ID" in manager.validate_provenance(directory,snapshot,bad))
			var temperature_error:=0.0;var flux_error:=0.0
			var r: Dictionary=loaded.results
			var expected_flux: float=-float(loaded.parts[0].material.k)*100/0.4
			var min_y:=INF
			for p in r.nodes:min_y=minf(min_y,p[1])
			for id in r.nodes.size():temperature_error=maxf(temperature_error,absf(r.temperature[id]-(300+250*(r.nodes[id][1]-min_y))))
			for q in r.heat_flux:flux_error=maxf(flux_error,Vector3(q[0],q[1]-expected_flux,q[2]).length())
			assert(temperature_error<1e-5 and flux_error<1e-3)
			evidence.append({"temperature_error_K":temperature_error,"flux_vector_error_W_m2":flux_error,"expected_flux_y_W_m2":expected_flux,"energy_balance_W":r.energy_balance_W})
		w.document.data=loaded
		w.document.changed.emit()
		w.inspection_mesh_key="";w.thermal_display_key="";w.overlay_key=[]
		w.deformation_scale=w.automatic_deformation_scale() if study=="static_structural" else 1
		w.structural_wireframe=true
		if study=="static_structural":
			var build_samples:=[]
			for sample in 3:
				var start:=Time.get_ticks_usec()
				var built=load("res://core/cae/structural_display.gd").new().build(loaded.results,"von_mises",w.deformation_scale)
				assert(not built.has("error"))
				build_samples.append((Time.get_ticks_usec()-start)/1000.0)
			timings.append({"operation":"structural_contour_build","samples_ms":build_samples})
			w.mesh_inspection.prepare(w.inspection_data())
			var pick_samples:=[]
			for sample in 3:
				var start:=Time.get_ticks_usec()
				w.mesh_inspection.pick(w.camera,Vector2(w.cad.size)/2,false)
				pick_samples.append((Time.get_ticks_usec()-start)/1000.0)
			timings.append({"operation":"probe_bvh_query","samples_ms":pick_samples})
		for field in (["displacement","von_mises"] if study=="static_structural" else ["temperature","heat_flux"]):
			var switch_start:=Time.get_ticks_usec()
			w.select_result_field("temperature" if field=="heat_flux" else field)
			if field=="heat_flux":w.thermal_field="heat_flux";w.show_flux_arrows=true;w.flux_stride=24;w.flux_scale=0.05;w.overlay_key=[];w.render_model();w.show_result_inspector()
			timings.append({"operation":"field_switch","field":field,"ms":(Time.get_ticks_usec()-switch_start)/1000.0})
			w.fit_model()
			w.cad.distance*=0.7;w.cad.update_camera()
			w.active_ribbon="Results";w.populate_ribbon()
			for resolution in [Vector2i(1280,720),Vector2i(1920,1080)]:
				root.size=resolution
				for i in 10:await process_frame
				await RenderingServer.frame_post_draw
				root.get_texture().get_image().save_png("res://docs/workbench-2/stage5-final-cylinder-%s-%d.png" % [field,resolution.x])
	var output=FileAccess.open("res://docs/workbench-2/stage5-final-cylinder-display-numerical.json",FileAccess.WRITE)
	output.store_string(JSON.stringify(evidence,"\t"))
	var perf=FileAccess.open("res://docs/workbench-2/stage5-final-performance.json",FileAccess.WRITE)
	perf.store_string(JSON.stringify(timings,"\t"))
	w.queue_free()
	await process_frame
	quit()
