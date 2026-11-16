extends RefCounted
static func defaults(size: float=0.05) -> Dictionary:
	return {"schema":1,"target_size":size,"min_size":size/10,"max_size":size,"curvature_points":0,"boundary_extension":true,"algorithm":"delaunay","optimization":"gmsh","optimize_iterations":1,"max_nodes":100000,"max_elements":500000,"timeout_s":120.0,"memory_mb":1536,"min_quality":0.03,"max_edge_ratio":100.0,"local":[]}
static func validate(config, faces: Array=[], check_faces: bool=true) -> String:
	if not config is Dictionary:return "Invalid mesh settings"
	if not (config.get("schema") is int or config.get("schema") is float) or (config.schema!=1 and config.schema!=2):return "Unsupported mesh settings schema"
	if config.size()!=defaults().size()+(1 if config.schema==2 else 0):return "Incomplete mesh settings"
	for key in defaults():
		if not config.has(key):return "Missing mesh setting: "+key
	if config.schema==2 and (not (config.get("order") is int or config.get("order") is float) or (config.order!=1 and config.order!=2)):return "Unsupported element order"
	var ranges={"target_size":[1e-6,1000,false],"min_size":[1e-6,1000,false],"max_size":[1e-6,1000,false],"curvature_points":[0,100,true],"optimize_iterations":[1,5,true],"max_nodes":[4,200000,true],"max_elements":[1,1000000,true],"timeout_s":[0.1,180,false],"memory_mb":[768,4096,true],"min_quality":[0,1,false],"max_edge_ratio":[1,10000,false]}
	for key in ranges:
		var v=config[key];var bounds=ranges[key]
		if not (v is int or v is float) or not is_finite(float(v)) or v<bounds[0] or v>bounds[1] or (bounds[2] and v!=floor(v)):return "Invalid mesh setting: "+key
	if config.min_size>config.target_size or config.target_size>config.max_size:return "Mesh sizes require min <= target <= max"
	if not config.boundary_extension is bool or config.algorithm not in ["delaunay","hxt"] or config.optimization not in ["none","gmsh","netgen"]:return "Unsupported mesh algorithm/optimization/boundary setting"
	if not config.local is Array or config.local.size()>64:return "At most 64 local sizing rules"
	var ids={}
	for rule in config.local:
		if not rule is Dictionary or rule.size()!=8:return "Malformed local sizing rule"
		for key in ["id","face","enabled","needs_review","mode","size","dist_min","dist_max"]:
			if not rule.has(key):return "Missing local sizing field: "+key
		if not rule.id is String or rule.id.is_empty() or ids.has(rule.id) or not rule.face is String or rule.face.is_empty():return "Invalid local sizing identity"
		ids[rule.id]=true
		if not rule.enabled is bool or not rule.needs_review is bool or rule.mode not in ["face","distance"]:return "Invalid local sizing state"
		for key in ["size","dist_min","dist_max"]:
			if not (rule[key] is int or rule[key] is float) or not is_finite(float(rule[key])):return "Nonfinite local sizing distance"
		if rule.size<config.min_size or rule.size>config.max_size or rule.dist_min<0 or rule.dist_min>=rule.dist_max or rule.dist_max>1000:return "Local size outside global bounds or invalid near/far distances"
		if rule.enabled and (rule.needs_review or (check_faces and not faces.has(rule.face))):return "Local refinement face requires review: "+rule.face
	return ""
static func current(data: Dictionary) -> bool:
	if not data.get("_participation_resolved",false):
		var participation=preload("res://core/cae/analysis_participation.gd")
		if not participation.error(data).is_empty():return false
		if data.get("mesh",{}).has("analysis_participation") and preload("res://core/cae/mesh_fingerprint.gd").canonical(data.mesh.analysis_participation)!=preload("res://core/cae/mesh_fingerprint.gd").canonical(participation.signature(data)):return false
		data=participation.view(data)
	var mesh=data.get("mesh",{})
	if mesh.is_empty():return false
	if data.parts.size()>1:
		if not mesh.has("part_meshes") or mesh.part_meshes.size()!=data.parts.size():return false
		for part in data.parts:
			if not mesh.part_meshes.has(part.id):return false
			if not current({"parts":[part],"mesh":mesh.part_meshes[part.id]}):return false
		return true
	if not mesh.has("mesh_settings"):return not data.parts.any(func(p):return p.has("mesh_settings"))
	if data.parts.size()!=1:return false
	var p=data.parts[0]
	if encode_numbers(p.get("mesh_settings"))!=encode_numbers(mesh.mesh_settings) or not validate(mesh.mesh_settings,[],false).is_empty():return false
	if p.has("cad_model") and p.cad_model!=p.get("cad_evaluated_model"):return false
	if p.has("cad_geometry_revision") and mesh.get("geometry_revision")!=p.cad_geometry_revision:return false
	if mesh.get("formulation")!=("TET10" if mesh.mesh_settings.get("order",1)==2 else "TET4"):return false
	if mesh.get("formulation")=="TET10" and (mesh.get("mesh_schema")!=2 or mesh.get("node_order")!="CalculiX C3D10"):return false
	for key in ["id","kind","dimensions","position","rotation","scale","cad_sha256"]:
		if preload("res://core/cae/mesh_fingerprint.gd").canonical(mesh.get("geometry_part",{}).get(key))!=preload("res://core/cae/mesh_fingerprint.gd").canonical(p.get(key)):return false
	return not mesh.get("generation_id","").is_empty()

static func encode_numbers(value):
	if value is int or value is float:
		var bytes=PackedByteArray();bytes.resize(8);bytes.encode_double(0,float(value));return {"binary64":bytes.hex_encode()}
	if value is Array:
		var result=[]
		for item in value:result.append(encode_numbers(item))
		return result
	if value is Dictionary:
		var result={}
		for key in value:result[key]=encode_numbers(value[key])
		return result
	return value
static func decode_numbers(value):
	if value is Array:
		var result=[]
		for item in value:result.append(decode_numbers(item))
		return result
	if value is Dictionary:
		if value.size()==1 and value.has("binary64"):
			var bytes=str(value.binary64).hex_decode()
			return bytes.decode_double(0) if bytes.size()==8 else NAN
		var result={}
		for key in value:result[key]=decode_numbers(value[key])
		return result
	return value
