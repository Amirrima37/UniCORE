extends SceneTree
const M=preload("res://core/cae/cylinder_mesher.gd")
const D=preload("res://core/cae/mesh_display.gd")
var rows: Array=[]
func require(ok: bool, message: String):
	if not ok: push_error(message); quit(1)
func _initialize():
	var previous_flux:=INF
	var previous_volume:=1.0;var previous_area:=1.0;var previous_temperature:=INF
	for density in [1,2,3,4]:
		var doc=load("res://core/cae/cae_document.gd").new()
		require(doc.execute("CreatePart",{"kind":"Sphere","parameters":{"radius":0.1}}).is_empty(),"Create sphere")
		doc.execute("AssignMaterial",{"index":0,"material":{"name":"Sphere reference","E":1000.0,"nu":0.25,"density":1.0,"k":10.0,"cp":1.0}})
		if density==2:
			doc.execute("SetRotation",{"index":0,"values":[0.3,0.7,-0.4]})
			doc.execute("SetPosition",{"index":0,"values":[1,-2,3]})
		require(doc.execute("ApplySphereExpansion",{"index":0,"strain":0.001}).is_empty(),"Expansion condition")
		require(doc.generate_mesh(density).is_empty(),"Sphere mesh")
		var mesh: Dictionary=doc.data.mesh;var part: Dictionary=doc.data.parts[0]
		var again: Dictionary=load("res://core/cae/sphere_mesher.gd").generate(doc.data,density).mesh
		for key in ["nodes","elements","regions","surface_regions","material_regions"]: require(mesh[key]==again[key],"Repeatability "+key)
		var faces: Dictionary={};var cells: Dictionary={};var used: Dictionary={};var adjacency: Array=[]
		var mean: Array=[];var edge: Array=[];var volume:=0.0;var warnings:=0;var edge_warnings:=0
		for e in mesh.elements.size():
			adjacency.append([])
			var cell: Array=mesh.elements[e];var key: Array=cell.duplicate();key.sort()
			require(not cells.has(str(key)),"Duplicate tet");cells[str(key)]=true
			var det:=M.determinant(M.sub(mesh.nodes[cell[1]],mesh.nodes[cell[0]]),M.sub(mesh.nodes[cell[2]],mesh.nodes[cell[0]]),M.sub(mesh.nodes[cell[3]],mesh.nodes[cell[0]]))
			require(det>0,"Signed volume");volume+=det/6
			require(mesh.material_regions[e]==part.id,"Material owner")
			for id in cell: used[id]=true
			for local in [[0,2,1],[0,1,3],[1,2,3],[2,0,3]]:
				var face: Array=[cell[local[0]],cell[local[1]],cell[local[2]]];key=face.duplicate();key.sort()
				if not faces.has(str(key)): faces[str(key)]=[]
				faces[str(key)].append({"element":e,"face":face})
			var q: Dictionary=D.quality(mesh,cell)
			require(not q.inverted and not q.degenerate and not q.invalid,"Quality validity")
			warnings+=int(q.status=="warning");edge_warnings+=int(q.edge_ratio>5)
			mean.append(q.mean_ratio);edge.append(q.edge_ratio)
		require(used.size()==mesh.nodes.size(),"Unused nodes")
		var boundary: Dictionary={};var area:=0.0;var resultant: Array=[0.0,0.0,0.0]
		var arithmetic=load("res://core/cae/extreme_jobs.gd").new()
		for face in mesh.surface_regions[part.id].OuterSurface:
			var key: Array=face.duplicate();key.sort()
			require(not boundary.has(str(key)),"Exterior uniqueness");boundary[str(key)]=true
			var a: Array=mesh.nodes[face[0]]
			var cross: Array=arithmetic.cross64(M.sub(mesh.nodes[face[1]],a),M.sub(mesh.nodes[face[2]],a))
			require(arithmetic.dot64(cross,M.sub(a,part.position))>0,"Outward normal")
			area+=sqrt(arithmetic.dot64(cross,cross))/2
			for j in 3: resultant[j]+=cross[j]/2
		for key in faces:
			var entries: Array=faces[key]
			require(entries.size() in [1,2],"Face multiplicity")
			if entries.size()==1: require(boundary.has(key),"Missing exterior")
			else:
				require(not boundary.has(key),"Interior boundary")
				var a: Array=entries[0].face;var b: Array=entries[1].face;var at: int=b.find(a[0])
				require(b[(at+1)%3]==a[2],"Shared face orientation")
				adjacency[entries[0].element].append(entries[1].element);adjacency[entries[1].element].append(entries[0].element)
		var visited: Dictionary={0:true};var queue: Array=[0];var cursor:=0
		while cursor<queue.size():
			for next in adjacency[queue[cursor]]:
				if not visited.has(next): visited[next]=true;queue.append(next)
			cursor+=1
		require(visited.size()==mesh.elements.size(),"Connected sphere")
		require(mesh.surface_regions[part.id].PositiveY.size()+mesh.surface_regions[part.id].NegativeY.size()==boundary.size(),"Hemisphere coverage")
		var volume_error:=absf(volume/(4.0/3*PI*pow(0.1,3))-1);var area_error:=absf(area/(4*PI*0.01)-1)
		require(volume_error<previous_volume and area_error<previous_area,"Geometry convergence");previous_volume=volume_error;previous_area=area_error
		require(sqrt(arithmetic.dot64(resultant,resultant))<1e-12,"Closed pressure resultant")
		mean.sort();edge.sort()
		var row: Dictionary={"density":density,"nodes":mesh.nodes.size(),"elements":mesh.elements.size(),"volume_relative_error":volume_error,"area_relative_error":area_error,"legacy_warning_count":warnings,"edge_ratio_over5_count":edge_warnings,"mean_ratio_max":mean[-1],"mean_ratio_min":mean[0],"mean_ratio_median":mean[mean.size()/2],"edge_ratio_max":edge[-1],"pressure_resultant_at_1Pa_N":resultant,"generation_ms":mesh.quality.generation_ms}
		var jobs=load("res://core/cae/extreme_jobs.gd").new()
		var directory: String=jobs.launch(doc,1,256);require(not directory.is_empty(),jobs.last_error)
		var deadline:=Time.get_ticks_msec()+15000
		while jobs.status(directory).get("state")!="Completed" and Time.get_ticks_msec()<deadline: await process_frame
		var imported: Dictionary=jobs.load_result(directory,doc.data);require(not imported.is_empty(),jobs.last_error)
		var result: Dictionary=imported.results;var displacement_error:=0.0;var stress_error:=0.0;var reactions: Array=[0.0,0.0,0.0]
		for id in mesh.nodes.size():
			for j in 3:
				displacement_error=maxf(displacement_error,absf(result.displacement[id][j]-0.001*(mesh.nodes[id][j]-part.position[j])))
				reactions[j]+=result.reactions[id][j]
		for stress in result.stress:
			for j in 6: stress_error=maxf(stress_error,absf(stress[j]-(2.0 if j<3 else 0.0)))
		require(displacement_error<1e-9 and stress_error<1e-5,"Affine expansion reference")
		require(sqrt(arithmetic.dot64(reactions,reactions))<1e-8,"Reaction balance")
		row.structural={"displacement_max_error_m":displacement_error,"stress_max_error_Pa":stress_error,"reaction_sum_N":reactions,"residual":result.get("relative_residual")}
		doc.data.results=result
		require(doc.save_project("res://.tools/stage6-sphere.ucae")==OK,"Project save")
		var reopened=load("res://core/cae/cae_document.gd").new()
		require(reopened.open_project("res://.tools/stage6-sphere.ucae").is_empty(),"Project reopen")
		require(not jobs.load_result(directory,reopened.data).is_empty(),"Reopened provenance")
		doc.execute("SetParameters",{"index":0,"parameters":{"radius":0.11}})
		require(jobs.load_result(directory,doc.data).is_empty(),"Stale sphere rejection")
		doc.undo();require(doc.data.parts[0].dimensions==part.dimensions,"Undo")
		require(not jobs.load_result(directory,doc.data).is_empty(),"Undo restores exact provenance")
		doc.redo();require(jobs.load_result(directory,doc.data).is_empty(),"Redo stale rejection")
		doc.undo()
		doc.execute("ClearAnalysisConditions",{"index":0})
		doc.execute("SetAnalysis",{"analysis":{"type":"steady_thermal","element":"TET4"}})
		doc.execute("SetHeatSource",{"index":0,"value":6000.0})
		doc.execute("ApplyThermalBoundary",{"index":0,"boundary":{"face":"OuterSurface","kind":"temperature","value":300.0}})
		require(doc.generate_mesh(density).is_empty(),"Thermal mesh")
		directory=jobs.launch(doc,1,256);require(not directory.is_empty(),jobs.last_error)
		deadline=Time.get_ticks_msec()+15000
		while jobs.status(directory).get("state")!="Completed" and Time.get_ticks_msec()<deadline: await process_frame
		imported=jobs.load_result(directory,doc.data);require(not imported.is_empty(),jobs.last_error);result=imported.results
		var temperature_error:=0.0;var heat:=0.0;var flux_error:=0.0;var flux_square:=0.0;var exact_square:=0.0
		for id in mesh.nodes.size():
			var delta: Array=M.sub(mesh.nodes[id],part.position)
			var exact: float=300+100*(0.01-arithmetic.dot64(delta,delta))
			temperature_error=maxf(temperature_error,absf(result.temperature[id]-exact));heat+=result.heat_reactions[id]
		for e in mesh.elements.size():
			var center: Array=[0.0,0.0,0.0]
			for id in mesh.elements[e]:
				for j in 3: center[j]+=(mesh.nodes[id][j]-part.position[j])/4
			var cell: Array=mesh.elements[e]
			var cell_volume:=M.determinant(M.sub(mesh.nodes[cell[1]],mesh.nodes[cell[0]]),M.sub(mesh.nodes[cell[2]],mesh.nodes[cell[0]]),M.sub(mesh.nodes[cell[3]],mesh.nodes[cell[0]]))/6
			for j in 3:
				var difference: float=result.heat_flux[e][j]-2000*center[j]
				flux_error=maxf(flux_error,absf(difference));flux_square+=difference*difference*cell_volume;exact_square+=pow(2000*center[j],2)*cell_volume
		var relative_flux:=sqrt(flux_square/exact_square)
		require(relative_flux<previous_flux,"Centroid flux refinement");previous_flux=relative_flux
		var energy_error:=absf(absf(heat)/(6000*volume)-1)
		require(temperature_error<previous_temperature,"Thermal refinement");previous_temperature=temperature_error
		require(energy_error<1e-7,"Energy conservation")
		row.thermal={"centroid_flux_volume_l2_relative_error":sqrt(flux_square/exact_square),"temperature_max_error_K":temperature_error,"flux_component_max_error_W_m2":flux_error,"heat_reaction_W":heat,"energy_relative_error":energy_error,"residual":result.get("relative_residual")}
		rows.append(row);print(JSON.stringify(row))
	var file=FileAccess.open("res://docs/workbench-2/stage6-sphere-numerical.json",FileAccess.WRITE);file.store_string(JSON.stringify(rows,"  "))
	print("Sphere geometry/topology/structural/thermal/provenance/persistence PASS")
	quit()
