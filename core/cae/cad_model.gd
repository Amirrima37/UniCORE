extends RefCounted
## Editable graph schema v1. Old documents without cad_model remain valid.
static func visit(id: String, nodes: Dictionary, visiting: Dictionary, done: Dictionary) -> String:
	if not nodes.has(id):return "Missing CAD dependency: "+id
	if visiting.has(id):return "Cyclic CAD graph"
	if done.has(id):return ""
	visiting[id]=true
	var n=nodes[id]
	if n.type in ["Union","Cut","Intersect"]:
		if n.get("base")==n.get("tool"):return "Boolean operands must differ"
		for key in ["base","tool"]:
			var error=visit(str(n.get(key,"")),nodes,visiting,done)
			if not error.is_empty():return error
	visiting.erase(id);done[id]=true
	return ""
static func validate(model) -> String:
	if not model is Dictionary or model.get("schema")!=1 or model.get("units")!="m":return "Unsupported CAD document schema or units"
	if not model.get("nodes") is Array or model.nodes.is_empty() or model.nodes.size()>64:return "CAD graph requires 1..64 features"
	var nodes={}
	for n in model.nodes:
		if not n is Dictionary or not n.get("id") is String or n.id.is_empty() or nodes.has(n.id):return "Invalid or duplicate CAD feature ID"
		if n.get("type") not in ["Box","Cylinder","Sphere","Pipe","STEP","Union","Cut","Intersect"]:return "Unsupported CAD feature type"
		for key in ["position","rotation","scale"]:
			var v=n.get(key,[1,1,1] if key=="scale" else [0,0,0])
			if not v is Array or v.size()!=3:return "Invalid CAD transform"
			for number in v:
				if not (number is int or number is float) or not is_finite(float(number)) or absf(float(number))>1e6 or (key=="scale" and absf(float(number))<=1e-8):return "Invalid CAD transform"
		if n.type=="STEP":
			if not n.get("source_base64") is String or n.source_base64.length()>89478488:return "CAD STEP input size bound"
			var bytes=Marshalls.base64_to_raw(n.source_base64)
			if bytes.is_empty() or load("res://core/cae/cae_document.gd").cad_sha256(bytes)!=n.get("source_sha256"):return "Corrupted CAD STEP source"
		elif n.type in ["Box","Cylinder","Sphere","Pipe"]:
			var dims=n.get("dimensions")
			if not dims is Array or dims.size()!=3:return "Invalid CAD dimensions"
			for value in dims:
				if not (value is float or value is int) or not is_finite(float(value)) or value<1e-6 or value>1000:return "CAD dimensions must be 1e-6..1000 metres"
			if n.type=="Pipe" and (not (n.get("inner_diameter") is float or n.get("inner_diameter") is int) or n.inner_diameter<=0 or n.inner_diameter>=dims[0]):return "Invalid pipe wall"
		nodes[n.id]=n
	if not nodes.has(model.get("root")):return "Missing CAD output feature"
	var done={}
	for id in nodes:
		var error=visit(id,nodes,{},done)
		if not error.is_empty():return error
	return ""
static func from_part(part: Dictionary) -> Dictionary:
	if part.has("cad_model"):return part.cad_model.duplicate(true)
	var n={"id":"feature_"+str(part.id),"type":"STEP" if part.kind=="CAD" else part.kind,"name":part.name,"position":part.get("position",[0,0,0]).duplicate(),"rotation":part.get("rotation",[0,0,0]).duplicate(),"scale":part.get("scale",[1,1,1]).duplicate()}
	for i in 3:n.rotation[i]=rad_to_deg(float(n.rotation[i]))
	if part.kind=="CAD":
		n.source_base64=part.cad_base64;n.source_sha256=part.cad_sha256;n.source_name=part.name
		# STEP already occupies source/world coordinates; legacy preview does not transform it.
	else:
		n.dimensions=part.dimensions.duplicate()
		if part.kind=="Pipe":n.inner_diameter=part.inner_diameter
	return {"schema":1,"units":"m","root":n.id,"nodes":[n]}
static func boolean_model(base: Dictionary, tool: Dictionary, operation: String) -> Dictionary:
	var a=from_part(base);var b=from_part(tool);var nodes=a.nodes.duplicate(true);var ids={}
	for n in nodes:ids[n.id]=n
	for n in b.nodes:
		if ids.has(n.id):
			if ids[n.id]!=n:return {"error":"Conflicting CAD feature identity; create distinct source bodies"}
		else:nodes.append(n)
	var id="boolean_"+str(Time.get_ticks_usec())
	nodes.append({"id":id,"name":operation+" result","type":operation,"base":a.root,"tool":b.root})
	return {"schema":1,"units":"m","root":id,"nodes":nodes}
