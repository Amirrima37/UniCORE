extends RefCounted
const Participation=preload("res://core/cae/analysis_participation.gd")
const Adapter=preload("res://core/cae/calculix_backend.gd")
var directory := ""
var cancelled := false
var started_ms := 0
var mesh_timeout_seconds := 120.0
var preview_job
var python := OS.get_environment("UNICORE_PYTHON") if not OS.get_environment("UNICORE_PYTHON").is_empty() else OS.get_environment("LOCALAPPDATA")+"/Python/pythoncore-3.14-64/python.exe"
var executable := "res://.tools/engines/calculix/CalculiX-2.23.0-win-x64/bin/ccx.exe"
func reset_cancel(): cancelled=false
func cancel():
	cancelled=true
	if preview_job!=null:preview_job.cancel()
	if not directory.is_empty():
		var f=FileAccess.open(directory+"/cancel",FileAccess.WRITE)
		if f: f.close()
func get_phase() -> int: return 4
func status_text() -> String:
	return "CalculiX — %s — elapsed %.1f s (indeterminate)" % ["cancellation requested" if cancelled else "owned solver job running",(Time.get_ticks_msec()-started_ms)/1000.0]
func preview_step(data: Dictionary) -> Dictionary:
	preview_job=preload("res://core/cae/cad_geometry_job.gd").new()
	if cancelled:preview_job.cancel()
	var result: Dictionary=preview_job.evaluate({"action":"preview","part":data.parts[0]})
	directory=preview_job.directory;preview_job=null
	return result.preview if result.get("ok",false) else {"error":str(result.get("error","Owned native preview failed"))}
func generate_mesh(data: Dictionary, size: float) -> Dictionary:
	var participation_error=Participation.error(data)
	if not participation_error.is_empty():return {"error":participation_error}
	var participation=Participation.signature(data)
	data=Participation.view(data)
	if data.parts.is_empty():return {"error":"Add a solid before meshing"}
	if data.parts[0].has("mesh_settings"):
		var config=data.parts[0].mesh_settings
		var error=preload("res://core/cae/mesh_config.gd").validate(config,load("res://core/cae/cae_document.gd").surface_names(data.parts[0]))
		if not error.is_empty():return {"error":error}
		mesh_timeout_seconds=config.timeout_s;size=config.target_size
	var base="user://gmsh_"+str(OS.get_process_id())+"_"+str(Time.get_ticks_usec())+"_"+Crypto.new().generate_random_bytes(8).hex_encode()
	DirAccess.make_dir_recursive_absolute(base)
	directory=base
	var transport=data.duplicate(true)
	transport["_assembly_mesh_settings"]={}
	for part in data.parts:
		if part.has("mesh_settings"):transport._assembly_mesh_settings[part.id]=preload("res://core/cae/mesh_config.gd").encode_numbers(part.mesh_settings)
	if data.parts[0].has("mesh_settings"):transport["_mesh_settings_exact"]=preload("res://core/cae/mesh_config.gd").encode_numbers(data.parts[0].mesh_settings)
	var f=FileAccess.open(base+"/study.json",FileAccess.WRITE);f.store_string(JSON.stringify(transport,"",true,true));f.close()
	if cancelled:cancel()
	var output=[]
	var code=OS.execute(python,PackedStringArray([ProjectSettings.globalize_path("res://scripts/engines/run_owned_mesh.py"),ProjectSettings.globalize_path(base),str(size),str(mesh_timeout_seconds),str(OS.get_process_id())]),output,true)
	if cancelled:return {"error":"Gmsh cancelled"}
	var receipt=JSON.parse_string(FileAccess.get_file_as_string(base+"/receipt.json"))
	if code!=0 or not receipt is Dictionary or receipt.get("state")!="completed":
		var diagnostic=""
		var log=FileAccess.open(base+"/stderr.txt",FileAccess.READ)
		if log!=null:diagnostic=log.get_buffer(mini(log.get_length(),4096)).get_string_from_utf8()
		return {"error":"Gmsh failed: "+str(receipt)+" "+diagnostic+". Inspect "+ProjectSettings.globalize_path(base)+"/stderr.txt. For curved boundary failures enable curvature sizing or reduce sizes; for resource limits coarsen the mesh."}
	var bounded=FileAccess.open(base+"/mesh.json",FileAccess.READ)
	if bounded==null or bounded.get_length()>192*1024*1024:return {"error":"Gmsh response missing or exceeds 192 MiB"}
	bounded.close()
	var mesh=JSON.parse_string(FileAccess.get_file_as_string(base+"/mesh.json"))
	if not mesh is Dictionary: return {"error":"Invalid mesh receipt"}
	if mesh.has("error"):return mesh
	if mesh.has("mesh_settings_exact"):
		mesh.mesh_settings=preload("res://core/cae/mesh_config.gd").decode_numbers(mesh.mesh_settings_exact);mesh.erase("mesh_settings_exact")
	for part_mesh in mesh.get("part_meshes",{}).values():
		if part_mesh.has("mesh_settings_exact"):
			part_mesh.mesh_settings=preload("res://core/cae/mesh_config.gd").decode_numbers(part_mesh.mesh_settings_exact)
			part_mesh.erase("mesh_settings_exact")
	mesh["analysis_participation"]=participation
	mesh["completion"]=receipt
	return mesh
func solve_model(data: Dictionary) -> Dictionary:
	if not data.get("_participation_resolved",false):
		var participation_error=Participation.error(data)
		if not participation_error.is_empty():return {"ok":false,"error":participation_error}
		var expected=Participation.signature(data)
		if data.mesh.has("analysis_participation"):
			if preload("res://core/cae/mesh_fingerprint.gd").canonical(data.mesh.analysis_participation)!=preload("res://core/cae/mesh_fingerprint.gd").canonical(expected):return {"ok":false,"error":"Analysis participation changed; regenerate the mesh"}
		elif data.parts.any(func(p):return not p.get("analysis_enabled",true)):return {"ok":false,"error":"Regenerate mesh for current participation"}
		data=Participation.view(data)
	if data.parts.size()>1:return solve_assembly(data)
	started_ms=Time.get_ticks_msec()
	if not FileAccess.file_exists(executable):return {"ok":false,"error":"CalculiX executable missing: "+executable+". Restore the pinned CalculiX 2.23 pack or select an installed backend."}
	if data.get("analysis",{}).get("type","static_structural")!="static_structural" or data.parts.size()!=1: return {"ok":false,"error":"CalculiX supports one static solid"}
	var mesh: Dictionary=data.mesh
	var quadratic=mesh.get("formulation")=="TET10"
	if mesh.has("mesh_settings") and not preload("res://core/cae/mesh_config.gd").current(data):return {"ok":false,"error":"Mesh settings or geometry changed: regenerate the Gmsh mesh"}
	if data.get("analysis",{}).get("element","TET4")!=("TET10" if quadratic else "TET4"):return {"ok":false,"error":"Analysis element order must match the actual Gmsh mesh"}
	if quadratic and (mesh.get("mesh_schema")!=2 or mesh.get("node_order")!="CalculiX C3D10"):return {"ok":false,"error":"Unsupported quadratic mesh schema/order"}
	if mesh.get("geometry_backend","")!="gmsh_4.15.2": return {"ok":false,"error":"Generate a Gmsh mesh first"}
	var p: Dictionary=data.parts[0]
	var boundary_error=preload("res://core/cae/assembly_boundaries.gd").error(p)
	if not boundary_error.is_empty():return {"ok":false,"error":boundary_error}
	if p.kind=="CAD":
		var proof=mesh.get("face_resolution",{})
		for key in ["instance_uuid","definition_uuid","geometry_revision","transformation_revision"]:
			if proof.get(key)!=p.get(key):return {"ok":false,"error":"Missing/stale verified meshed face ownership: "+key}
		if proof.get("source_sha256")!=p.cad_sha256:return {"ok":false,"error":"Meshed face source geometry mismatch"}
		for key in ["support","load_face"]:
			var face_id=p.get(key,"")
			if not proof.get("source_faces",{}).has(face_id) or not proof.get("world_faces",{}).has(face_id) or proof.get("mesh_surfaces",{}).get(face_id,[]).is_empty():return {"ok":false,"error":"Unverified definition-to-mesh face: "+face_id}
			for field in p.boundary_refs[key].source_face:
				if not preload("res://core/cae/assembly_boundaries.gd").same_descriptor(field,p.boundary_refs[key].source_face[field],proof.source_faces[face_id].get(field)):return {"ok":false,"error":"Assigned physical face differs from meshed source: "+key}
	if not p.get("cad_pending_boundaries",{}).is_empty():return {"ok":false,"error":"CAD boundary conditions require explicit reassignment: "+str(p.cad_pending_boundaries.keys())}
	if p.has("cad_model") and p.cad_model!=p.get("cad_evaluated_model"):return {"ok":false,"error":"CAD graph changed: recompute/confirm the BRep and remesh before solving"}
	for key in ["id","kind","dimensions","position","rotation","scale","cad_sha256"]:
		if JSON.parse_string(JSON.stringify(mesh.get("geometry_part",{}).get(key)))!=JSON.parse_string(JSON.stringify(p.get(key))):return {"ok":false,"error":"Geometry changed since Gmsh generation; regenerate mesh"}
	if p.has("pressure") or p.has("prescribed") or p.has("gravity"): return {"ok":false,"error":"This pack supports fixed face and total face force only"}
	var groups: Dictionary=mesh.groups.get(p.id,{})
	if not groups.has(p.get("support","")) or not groups.has(p.get("load_face","")): return {"ok":false,"error":"Select valid support and load regions"}
	var surfaces: Dictionary=mesh.get("surface_regions",{}).get(p.id,{})
	if not surfaces.has(p.support) or not surfaces.has(p.load_face) or surfaces[p.load_face].is_empty():return {"ok":false,"error":"Missing CAD boundary physical surface"}
	if p.kind=="CAD" and (mesh.get("provenance",{}).get("cad_sha256","")!=p.get("cad_sha256","") or not p.get("cad_faces",[]).has(p.support) or not p.get("cad_faces",[]).has(p.load_face)):
		return {"ok":false,"error":"STEP source or selected CAD face identity mismatch"}
	for face_name in [p.support,p.load_face]:
		var listed={}
		for node_id in groups[face_name]:listed[int(node_id)]=true
		var actual={}
		for triangle in surfaces[face_name]:
			if triangle.size()!=3:return {"ok":false,"error":"Invalid CAD boundary triangle"}
			for node_id in triangle:
				if int(node_id)<0 or int(node_id)>=mesh.nodes.size():return {"ok":false,"error":"CAD boundary node out of range"}
				actual[int(node_id)]=true
		if listed!=actual:return {"ok":false,"error":"CAD face node group does not match boundary triangles"}
	var constraints=[];var loads=[]
	var supported_ids={}
	for id in groups[p.support]:
		supported_ids[int(id)]=true
		for axis in 3: constraints.append([int(id),axis,0.0])
	# Area-weighted consistent traction on linear boundary triangles.
	var weights={};var total=0.0
	for triangle in mesh.surface_regions[p.id][p.load_face]:
		if quadratic:break
		var points=[]
		for id in triangle:
			var a=mesh.nodes[id];points.append(Vector3(a[0],a[1],a[2]))
		var area=(points[1]-points[0]).cross(points[2]-points[0]).length()/2
		total+=area
		for id in triangle: weights[int(id)]=weights.get(int(id),0.0)+area/3
	if total<=0 and not quadratic: return {"ok":false,"error":"Empty loaded surface"}
	for id in weights:
		for axis in 3:
			if p.force[axis]!=0: loads.append([id,axis,p.force[axis]*weights[id]/total])
	for axis in 3:
		if quadratic:continue
		var applied=0.0
		for load in loads:
			if load[1]==axis:applied+=float(load[2])
		if absf(applied-float(p.force[axis]))>maxf(1e-8,absf(float(p.force[axis]))*1e-10):return {"ok":false,"error":"Total force distribution failed equilibrium check"}
	var model={"schema":1,"units":"SI","analysis":"static_structural","nodes":mesh.nodes,"elements":mesh.elements,"material":p.material,"constraints":constraints,"loads":loads}
	if quadratic:
		model.element_type="C3D10";model.node_order=mesh.node_order
		if not mesh.get("quadratic_surfaces",{}).has(p.id):return {"ok":false,"error":"Missing quadratic CAD surfaces"}
		model.quadratic_boundary={"faces":mesh.quadratic_surfaces[p.id],"groups":mesh.groups[p.id],"support":p.support,"load_face":p.load_face,"force":p.force}
	# JSON stores integral mesh IDs as floating-point values; normalize explicitly.
	model.elements=[]
	for cell in mesh.elements:
		var ids=[]
		for id in cell: ids.append(int(id))
		model.elements.append(ids)
	if data.get("_prepare_only",false):return {"ok":true,"model":model,"supported_ids":supported_ids}
	return finish_model(data,mesh,model,p,supported_ids)

func solve_assembly(data: Dictionary) -> Dictionary:
	var mesh: Dictionary=data.get("mesh",{})
	var interference=mesh.get("interference",{})
	if interference.get("algorithm")!="occt-solid-pair-v1":return {"ok":false,"error":"Regenerate assembly mesh: native interference classification required"}
	var codec=preload("res://core/cae/mesh_fingerprint.gd")
	var identities=[]
	for p in data.parts:
		var identity={}
		for key in ["id","instance_uuid","definition_uuid","geometry_revision","transformation_revision","kind","dimensions","position","rotation","scale","cad_sha256"]:identity[key]=p.get(key)
		identities.append(identity)
	if codec.canonical(interference.get("geometry_parts",[]))!=codec.canonical(identities):return {"ok":false,"error":"Assembly classification is stale; regenerate mesh"}
	if interference.get("pairs",[]).size()!=data.parts.size()*(data.parts.size()-1)/2:return {"ok":false,"error":"Incomplete assembly pair classification"}
	for pair in interference.pairs:
		if pair.get("classification") not in ["SEPARATED","TOUCHING"]:return {"ok":false,"error":"Assembly pair blocked: "+str(pair)}
	if not mesh.has("part_meshes"):return {"ok":false,"error":"Generate independent assembly meshes first"}
	var model={"schema":1,"units":"SI","analysis":"static_structural","nodes":mesh.nodes,"elements":[],"materials":[],"element_materials":[],"constraints":[],"loads":[]}
	var supported={}
	for p in data.parts:
		if not mesh.part_meshes.has(p.id):return {"ok":false,"error":"Instance mesh missing"}
		var single=data.duplicate(false)
		single.parts=[p];single.mesh=mesh.part_meshes[p.id];single._prepare_only=true
		var prepared=solve_model(single)
		if not prepared.get("ok",false):return prepared
		var local: Dictionary=prepared.model
		# Reuse the qualified quadratic consistent traction integration before offsets.
		if local.has("quadratic_boundary"):
			var adapter=Adapter.new()
			var temp="user://calculix_prepare/"+str(Time.get_ticks_usec())
			var job=adapter.prepare_quadratic_job(local,temp)
			if job.has("error"):return {"ok":false,"error":job.error}
			local=job.model
		var offset: int=mesh.instances[p.id].node_range[0]
		var material_index=model.materials.size()
		model.materials.append(p.material)
		for cell in local.elements:
			var row=[]
			for node in cell:row.append(int(node)+offset)
			model.elements.append(row);model.element_materials.append(material_index)
		for field in ["constraints","loads"]:
			for row in local[field]:model[field].append([int(row[0])+offset,int(row[1]),row[2]])
		for node in prepared.supported_ids:supported[int(node)+offset]=true
	model.material=model.materials[0]
	if preload("res://core/cae/mesh_fingerprint.gd").canonical(model.elements)!=preload("res://core/cae/mesh_fingerprint.gd").canonical(mesh.elements):return {"ok":false,"error":"Assembly element ownership or order changed"}
	if mesh.formulation=="TET10":model.element_type="C3D10";model.node_order="CalculiX C3D10"
	return finish_model(data,mesh,model,data.parts[0],supported)

func finish_model(data: Dictionary,mesh: Dictionary,model: Dictionary,p: Dictionary,supported_ids: Dictionary) -> Dictionary:
	var quadratic=model.get("element_type")=="C3D10"
	var adapter=Adapter.new();adapter.executable=executable
	directory="user://calculix_jobs/"+str(OS.get_process_id())+"_"+str(Time.get_ticks_usec())+"_"+Crypto.new().generate_random_bytes(8).hex_encode()
	var job=adapter.prepare_job(model,directory)
	if job.has("error"): return {"ok":false,"error":job.error}
	if cancelled: cancel()
	var output=[]
	var code=OS.execute(python,PackedStringArray([ProjectSettings.globalize_path("res://scripts/engines/run_owned_solver.py"),ProjectSettings.globalize_path(directory),ProjectSettings.globalize_path(executable)]),output,true)
	var launcher_log=FileAccess.open(directory+"/launcher-output.txt",FileAccess.WRITE)
	if launcher_log:launcher_log.store_string("exit="+str(code)+"\n"+str(output).left(16384));launcher_log.close()
	if cancelled:return {"ok":false,"error":"Cancelled; no result published"}
	var receipt=JSON.parse_string(FileAccess.get_file_as_string(directory+"/receipt.json"))
	if code!=0 or not receipt is Dictionary or receipt.get("state")!="completed" or receipt.get("exit_code")!=0: return {"ok":false,"error":"CalculiX failed/cancelled/timed out (launcher "+str(code)+"): "+str(receipt)+". Inspect "+ProjectSettings.globalize_path(directory)+"/stdout.txt, stderr.txt and launcher-error.txt; check the executable and model, then retry."}
	var r=adapter.import_results(job)
	if r.has("error"): return {"ok":false,"error":r.error}
	var u=[];var stress=[];var mises=[];var maximum=0.0;var reactions=[];var strain=[]
	var integration=[];var mises_ip=[]
	for i in mesh.nodes.size():
		var v=r.displacement_by_id[i];u.append(v);maximum=maxf(maximum,Vector3(v[0],v[1],v[2]).length())
		reactions.append(r.reaction_by_id[i] if supported_ids.has(i) else [0,0,0])
	for i in mesh.elements.size():
		var s=r.stress_by_id[i];stress.append(s)
		var material: Dictionary=model.materials[model.element_materials[i]] if model.has("materials") else p.material
		var young: float=material.E;var nu: float=material.nu
		strain.append([(s[0]-nu*(s[1]+s[2]))/young,(s[1]-nu*(s[0]+s[2]))/young,(s[2]-nu*(s[0]+s[1]))/young,2*(1+nu)*s[3]/young,2*(1+nu)*s[4]/young,2*(1+nu)*s[5]/young])
		mises.append(sqrt(0.5*(pow(s[0]-s[1],2)+pow(s[1]-s[2],2)+pow(s[2]-s[0],2))+3*(s[3]*s[3]+s[4]*s[4]+s[5]*s[5])))
		if quadratic:
			var points=[];var vm=[]
			for ip in 4:
				var tensor=r.stress_integration_points[i][ip];points.append(tensor)
				vm.append(sqrt(0.5*(pow(tensor[0]-tensor[1],2)+pow(tensor[1]-tensor[2],2)+pow(tensor[2]-tensor[0],2))+3*(tensor[3]*tensor[3]+tensor[4]*tensor[4]+tensor[5]*tensor[5])))
			integration.append(points);mises_ip.append(vm)
	var result={"ok":true,"nodes":mesh.nodes,"elements":model.elements,"tetrahedra":model.elements,"element_type":"C3D10" if quadratic else "C3D4","displacement":u,"stress":stress,"stress_integration_points":integration,"von_mises_integration_points":mises_ip,"strain":strain,"strain_definition":"engineering strain from compliance of displayed stress tensor; xy,xz,yz","reactions":reactions,"von_mises":mises,"max_displacement":maximum,"relative_residual":"not reported by CalculiX","backend":"CalculiX 2.23","revision":data.revision,"mesh_divisions":mesh.divisions,"stress_association":r.stress_association,"von_mises_definition":"von Mises of arithmetic mean of four integration-point tensors" if quadratic else "integration-point von Mises","surface_load_proof":job.model.get("surface_load_proof",{}),"provenance":r.provenance,"completion":receipt}
	for key in ["node_owners","element_owners","instances","analysis_participation"]:
		if mesh.has(key):result[key]=mesh[key]
	return result
