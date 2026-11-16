extends "res://core/cae/solver_backend.gd"
## Canonical SI TET4 adapter. Not registered until Workbench acceptance passes.
var executable := "res://.tools/engines/calculix/CalculiX-2.23.0-win-x64/bin/ccx.exe"
func dependency_status() -> Dictionary:
	var found=FileAccess.file_exists(executable)
	var verified=found and FileAccess.get_sha256(executable)=="27a9426a1ee2f72c38fbe892e0ffaf38e14867628ffd0235770261b6f3ec9c5f"
	return {"status":"pinned_binary_verified" if verified else "installed_unverified" if found else "missing_dependency","version":"2.23" if verified else "unknown","executable":executable,"diagnostic":"Native Windows static C3D4 pack; Gmsh SDK and Python also required"}
func prepare_job(model: Dictionary, directory: String) -> Dictionary:
	if model.get("element_type")=="C3D10":return prepare_quadratic_job(model,directory)
	var deck=input_deck(model)
	if deck.has("error"): return deck
	if DirAccess.dir_exists_absolute(directory): return {"error":"Refusing to reuse job directory"}
	if DirAccess.make_dir_recursive_absolute(directory)!=OK: return {"error":"Cannot create isolated directory"}
	var path=directory.path_join("model.inp")
	var file=FileAccess.open(path,FileAccess.WRITE)
	if file==null: return {"error":"Cannot write input"}
	file.store_string(deck.text); file.close()
	file=FileAccess.open(directory.path_join("canonical-model.json"),FileAccess.WRITE)
	if file==null:return {"error":"Cannot save canonical model snapshot"}
	file.store_string(JSON.stringify(model,"",true,true));file.close()
	return {"schema":1,"directory":directory,"model":model.duplicate(true),"input_sha256":FileAccess.get_sha256(path),"binary_sha256":FileAccess.get_sha256(executable),"executable":executable}
func execute_job(job: Dictionary) -> Dictionary:
	# Synchronous verification path only. Production monitor/timeout remains pending.
	if not FileAccess.file_exists(executable): return {"error":"CalculiX executable missing"}
	var directory: String=job.directory
	if FileAccess.get_sha256(directory.path_join("model.inp"))!=job.input_sha256: return {"error":"Input changed"}
	if FileAccess.get_sha256(executable)!=job.binary_sha256: return {"error":"Solver binary changed"}
	var output=[]
	var code=OS.execute(ProjectSettings.globalize_path(executable),PackedStringArray(["-i",ProjectSettings.globalize_path(directory.path_join("model"))]),output,true)
	var log="\n".join(output)
	var file=FileAccess.open(directory.path_join("solver.txt"),FileAccess.WRITE)
	file.store_string(log);file.close()
	if code!=0 or not "Job finished" in log or "*ERROR" in log: return {"error":"CalculiX failed; inspect solver.txt","exit_code":code}
	return import_results(job)
func import_results(job: Dictionary) -> Dictionary:
	var directory: String=job.directory
	if FileAccess.get_sha256(directory.path_join("model.inp"))!=job.input_sha256: return {"error":"Stale input"}
	var path=directory.path_join("model.dat")
	if not FileAccess.file_exists(path): return {"error":"Missing DAT"}
	var bounded=FileAccess.open(path,FileAccess.READ)
	if bounded==null or bounded.get_length()>32*1024*1024:return {"error":"DAT exceeds 32 MiB parser limit or cannot be opened"}
	bounded.close()
	var result=parse_dat(FileAccess.get_file_as_string(path),job.model)
	if result.has("error"): return result
	result.provenance={"schema":1,"input_sha256":job.input_sha256,"binary_sha256":job.binary_sha256,"dat_sha256":FileAccess.get_sha256(path)}
	return result
func capabilities() -> Dictionary:
	return {"schema":1,"id":"calculix","analyses":["static_structural"],"elements":["TET4","TET10"],"stress_association":"explicit integration-point values; C3D10 display tensor mean"}
func validate_model(model: Dictionary) -> Array:
	if model.get("element_type")=="C3D10":
		var job=prepare_quadratic_job(model,"user://calculix_validation/"+str(Time.get_ticks_usec()))
		return [job.error] if job.has("error") else []
	var errors := []
	if model.get("schema") != 1 or model.get("units") != "SI": errors.append("Expected canonical schema 1, SI")
	if model.get("analysis") != "static_structural": errors.append("Only linear static structural supported")
	var nodes: Array = model.get("nodes",[])
	if nodes.is_empty() or model.get("elements",[]).is_empty(): errors.append("Empty mesh")
	for p in nodes:
		if not p is Array or p.size()!=3: errors.append("Invalid node"); continue
		for v in p:
			if not (v is float or v is int) or not is_finite(v): errors.append("Nonfinite coordinate")
	if not errors.is_empty(): return errors
	for cell in model.get("elements",[]):
		if not cell is Array or cell.size()!=4: errors.append("Only TET4 connectivity supported"); continue
		var valid := true
		for id in cell:
			if not id is int or id<0 or id>=nodes.size(): valid=false
		if not valid: errors.append("Invalid node index"); continue
		var a=Vector3(nodes[cell[0]][0],nodes[cell[0]][1],nodes[cell[0]][2])
		var b=Vector3(nodes[cell[1]][0],nodes[cell[1]][1],nodes[cell[1]][2])-a
		var c=Vector3(nodes[cell[2]][0],nodes[cell[2]][1],nodes[cell[2]][2])-a
		var d=Vector3(nodes[cell[3]][0],nodes[cell[3]][1],nodes[cell[3]][2])-a
		if b.dot(c.cross(d))<=0: errors.append("Nonpositive TET4 orientation")
	var material: Dictionary=model.get("material",{})
	var young=float(material.get("E",0)); var nu=float(material.get("nu",-2))
	if not is_finite(young) or young<=0 or not is_finite(nu) or nu<=-1 or nu>=0.5: errors.append("Invalid isotropic elastic material")
	for key in ["constraints","loads"]:
		for row in model.get(key,[]):
			if not row is Array or row.size()!=3: errors.append("Invalid DOF row"); continue
			if not row[0] is int or row[0]<0 or row[0]>=nodes.size() or not row[1] is int or row[1]<0 or row[1]>2 or not (row[2] is float or row[2] is int) or not is_finite(row[2]): errors.append("Invalid DOF mapping")
	return errors

func prepare_quadratic_job(model: Dictionary,directory: String) -> Dictionary:
	if DirAccess.dir_exists_absolute(directory):return {"error":"Refusing to reuse solver job"}
	if DirAccess.make_dir_recursive_absolute(directory)!=OK:return {"error":"Cannot create C3D10 job"}
	var snapshot=model.duplicate(true);var bytes=PackedByteArray();bytes.resize(model.nodes.size()*24)
	for i in model.nodes.size():
		for j in 3:bytes.encode_double(i*24+j*8,float(model.nodes[i][j]))
	snapshot.nodes_binary64=Marshalls.raw_to_base64(bytes)
	var f=FileAccess.open(directory+"/request.json",FileAccess.WRITE);f.store_string(JSON.stringify(snapshot,"",true,true));f.close()
	var python=OS.get_environment("UNICORE_PYTHON")
	if python.is_empty():python=OS.get_environment("LOCALAPPDATA")+"/Python/pythoncore-3.14-64/python.exe"
	var output=[];var code=OS.execute(python,PackedStringArray([ProjectSettings.globalize_path("res://scripts/engines/run_owned_prepare.py"),ProjectSettings.globalize_path(directory),str(OS.get_process_id())]),output,true)
	if code!=0:return {"error":"C3D10 geometry/load preparation failed: "+FileAccess.get_file_as_string(directory+"/prepare-error.txt")+". Inspect "+ProjectSettings.globalize_path(directory)}
	var prepared=JSON.parse_string(FileAccess.get_file_as_string(directory+"/canonical-model.json"))
	if not prepared is Dictionary:return {"error":"Malformed prepared C3D10 model"}
	return {"schema":1,"directory":directory,"model":prepared,"input_sha256":FileAccess.get_sha256(directory+"/model.inp"),"binary_sha256":FileAccess.get_sha256(executable),"executable":executable}
func input_deck(model: Dictionary) -> Dictionary:
	if model.get("element_type")=="C3D10":
		var job=prepare_quadratic_job(model,"user://calculix_decks/"+str(Time.get_ticks_usec()))
		return job if job.has("error") else {"text":FileAccess.get_file_as_string(job.directory+"/model.inp")}
	var errors=validate_model(model)
	if not errors.is_empty(): return {"error":"; ".join(errors)}
	var lines=PackedStringArray(["*HEADING","UniCORE SI linear static TET4","*NODE,NSET=NALL"])
	for i in model.nodes.size(): lines.append("%d,%.17f,%.17f,%.17f" % [i+1,model.nodes[i][0],model.nodes[i][1],model.nodes[i][2]])
	lines.append("*ELEMENT,TYPE=C3D4,ELSET=EALL")
	for i in model.elements.size():
		var c=model.elements[i]
		lines.append("%d,%d,%d,%d,%d" % [i+1,c[0]+1,c[1]+1,c[2]+1,c[3]+1])
	if model.has("materials"):
		if model.get("element_materials",[]).size()!=model.elements.size():return {"error":"Incomplete material ownership"}
		for k in model.materials.size():
			var m: Dictionary=model.materials[k]
			if not is_finite(float(m.get("E",0))) or m.get("E",0)<=0 or not is_finite(float(m.get("nu",-2))) or m.get("nu",-2)<=-1 or m.get("nu",-2)>=0.5:return {"error":"Invalid assembly material"}
			lines.append("*ELSET,ELSET=REGION%d" % k)
			for i in model.elements.size():
				if model.element_materials[i]==k:lines.append(str(i+1))
			lines.append_array(PackedStringArray(["*MATERIAL,NAME=MAT%d" % k,"*ELASTIC","%.17f,%.17f" % [m.E,m.nu],"*SOLID SECTION,ELSET=REGION%d,MATERIAL=MAT%d" % [k,k]]))
		for k in model.element_materials:
			if k<0 or k>=model.materials.size():return {"error":"Missing element material"}
		lines.append("*BOUNDARY")
	else:
		lines.append_array(PackedStringArray(["*MATERIAL,NAME=ELASTIC","*ELASTIC","%.17f,%.17f" % [model.material.E,model.material.nu],"*SOLID SECTION,ELSET=EALL,MATERIAL=ELASTIC","*BOUNDARY"]))
	for row in model.get("constraints",[]): lines.append("%d,%d,%d,%.17f" % [row[0]+1,row[1]+1,row[1]+1,row[2]])
	lines.append_array(PackedStringArray(["*STEP","*STATIC","*CLOAD"]))
	for row in model.get("loads",[]): lines.append("%d,%d,%.17f" % [row[0]+1,row[1]+1,row[2]])
	lines.append_array(PackedStringArray(["*NODE PRINT,NSET=NALL","U,RF","*EL PRINT,ELSET=EALL","S","*NODE FILE","U","*EL FILE","S","*END STEP",""]))
	return {"text":"\n".join(lines)}
func parse_dat(text: String, model: Dictionary) -> Dictionary:
	var displacement := {}; var stress := {}; var reactions := {}; var section := ""
	var quadratic=model.get("element_type")=="C3D10";var integration={}
	for line in text.split("\n"):
		var lower=line.to_lower()
		if "displacements" in lower: section="u"; continue
		if "stresses" in lower: section="s"; continue
		if "forces" in lower: section="rf"; continue
		var tokens=line.strip_edges().split(" ",false)
		if tokens.is_empty() or not tokens[0].is_valid_int(): continue
		var id=int(tokens[0])-1
		var values=[]
		var offset=2 if section=="s" else 1
		for j in range(offset,tokens.size()):
			var token=tokens[j].strip_edges().replace("D","e").replace("E","e")
			if not token.is_valid_float() or not is_finite(float(token)): return {"error":"Nonfinite or malformed DAT field"}
			values.append(float(token))
		if section in ["u","rf"] and values.size()==3 and id>=0 and id<model.nodes.size():
			var target=displacement if section=="u" else reactions
			if target.has(id): return {"error":"Duplicate result node"}
			target[id]=values
		elif section=="s" and values.size()==6 and id>=0 and id<model.elements.size():
			if quadratic:
				if not tokens[1].is_valid_int() or int(tokens[1])<1 or int(tokens[1])>4:return {"error":"Invalid C3D10 integration point"}
				if not integration.has(id):integration[id]={}
				var ip=int(tokens[1])-1
				if integration[id].has(ip):return {"error":"Duplicate C3D10 integration point"}
				integration[id][ip]=values
			else:
				if tokens[1]!="1" or stress.has(id): return {"error":"Unsupported integration-point mapping"}
				stress[id]=values
		elif section in ["u","rf","s"]: return {"error":"Unknown or malformed result identity"}
	if quadratic:
		if integration.size()!=model.elements.size():return {"error":"Incomplete C3D10 stresses"}
		for id in integration:
			if integration[id].size()!=4:return {"error":"Incomplete C3D10 integration points"}
			var mean=[0.0,0.0,0.0,0.0,0.0,0.0]
			for ip in 4:
				for axis in 6:mean[axis]+=integration[id][ip][axis]/4.0
			stress[id]=mean
	if displacement.size()!=model.nodes.size() or reactions.size()!=model.nodes.size() or stress.size()!=model.elements.size(): return {"error":"Incomplete DAT result"}
	return {"displacement_by_id":displacement,"stress_by_id":stress,"stress_integration_points":integration,"reaction_by_id":reactions,"stress_association":"element arithmetic mean of 4 integration-point tensors" if quadratic else "integration_point","stress_order":["xx","yy","zz","xy","xz","yz"]}
