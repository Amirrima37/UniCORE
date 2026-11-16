extends RefCounted
## Owned deep snapshot: dictionary/array equality detects mutations even without revisions.
## The cache is bounded to one exact state; no probabilistic hash authorizes reuse.
var state: Array=[]
var generation := 0
var valid := false
func current(data: Dictionary) -> bool:
	var r: Dictionary=data.get("results",{})
	var candidate: Array=[data.get("revision"),data.get("parts"),data.get("mesh"),data.get("analysis"),r]
	if candidate==state:return valid
	state=candidate.duplicate(true)
	generation+=1
	valid=r.get("ok",false) and r.get("revision",-1)==data.get("revision") and r.get("model_parts",[])==data.get("parts") and r.get("mesh_divisions",-1)==data.get("mesh",{}).get("divisions",-2)
	if r.has("model_analysis"):valid=valid and r.model_analysis==data.get("analysis",{})
	if valid and data.get("mesh",{}).has("mesh_settings"):valid=preload("res://core/cae/mesh_config.gd").current(data)
	if valid and r.has("source_mesh_sha256"):
		var encoding=int(r.get("mesh_fingerprint_version",1))
		var codec=preload("res://core/cae/mesh_fingerprint.gd")
		if encoding==codec.VERSION:valid=r.source_mesh_sha256==codec.fingerprint(data.mesh)
		elif encoding==1:valid=r.source_mesh_sha256==codec.legacy(data.mesh)
		else:valid=false
	return valid

