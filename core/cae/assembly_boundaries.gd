extends RefCounted
const Identity = preload("res://core/cae/mesh_fingerprint.gd")

static func same_numbers(a, b) -> bool:
	if a is Array and b is Array:
		if a.size()!=b.size():return false
		for i in a.size():
			if not same_numbers(a[i],b[i]):return false
		return true
	if (a is int or a is float) and (b is int or b is float):return is_finite(float(a)) and is_finite(float(b)) and abs(float(a)-float(b))<=maxf(1e-10,absf(float(a))*1e-8)
	return false

static func same_descriptor(field: String, a, b) -> bool:
	if field=="bounds" and a is Array and b is Array and a.size()==b.size():
		for i in a.size():
			if not (a[i] is int or a[i] is float) or not (b[i] is int or b[i] is float) or not is_finite(float(a[i])) or not is_finite(float(b[i])):return false
			if abs(float(a[i])-float(b[i]))>maxf(2e-7,absf(float(a[i]))*1e-9):return false
		return true
	return same_numbers(a,b)

static func anchor(p: Dictionary, face: String) -> Dictionary:
	var record={"area":p.get("cad_face_areas",{}).get(face,-1),"center":p.get("cad_face_centers",{}).get(face,[])}
	var table=p.get("cad_definition_faces",p.get("cad_face_descriptors",{})).get(face,{})
	for key in ["inertia","bounds","plane_outward_normal"]:
		if table.has(key):record[key]=table[key].duplicate() if table[key] is Array else table[key]
	return record.duplicate(true)

static func make_reference(p: Dictionary, face: String) -> Dictionary:
	var record={"schema":1,"instance_uuid":p.get("instance_uuid",""),"definition_uuid":p.get("definition_uuid",""),"geometry_revision":p.get("geometry_revision",0),"transformation_revision":p.get("transformation_revision",0),"source_sha256":p.get("cad_sha256",""),"definition_face_id":face,"state":"resolved","coordinate_system":"global"}
	if p.get("kind")=="CAD":
		record.source_face=anchor(p,face)
		var table=p.get("cad_definition_faces",p.get("cad_face_descriptors",{}))
		var center=p.get("cad_face_centers",{}).get(face,[])
		var area=float(p.get("cad_face_areas",{}).get(face,-1))
		if center.size()==3:
			for other in p.get("cad_faces",[]):
				if other==face:continue
				var c=p.get("cad_face_centers",{}).get(other,[])
				if c.size()!=3:continue
				if abs(float(p.get("cad_face_areas",{}).get(other,-2))-area)>maxf(1e-10,absf(area)*1e-8):continue
				if Vector3(c[0],c[1],c[2]).distance_to(Vector3(center[0],center[1],center[2]))>1e-8:continue
				if not table.get(face,{}).has("inertia") or not table.get(other,{}).has("inertia") or Identity.canonical(table[face].inertia)==Identity.canonical(table[other].inertia):
					record.state="unresolved";record.reason="Ambiguous source face descriptors; review definition faces and explicitly reassign"
	return record

static func migrate(p: Dictionary) -> void:
	if p.has("boundary_schema"):return
	p.boundary_schema=1;p.boundary_refs={}
	for key in ["support","load_face"]:
		if not p.get(key,"").is_empty():p.boundary_refs[key]=make_reference(p,p[key])

static func clear_instance(p: Dictionary) -> void:
	for key in ["support","load_face"]:p[key]=""
	for key in ["pressure","prescribed","gravity","thermal","heat_source","boundary_refs","boundary_schema","cad_pending_boundaries","cad_boundary_archive","cad_topology_review"]:p.erase(key)
	migrate(p)

static func assign(p: Dictionary, key: String) -> void:
	migrate(p)
	var previous=p.boundary_refs.get(key,{})
	var replacement=make_reference(p,p[key])
	if previous.get("state")=="unresolved":
		replacement.reassigned_from={"instance_uuid":previous.get("instance_uuid"),"definition_uuid":previous.get("definition_uuid"),"definition_face_id":previous.get("definition_face_id"),"source_sha256":previous.get("source_sha256"),"reason":previous.get("reason","")}
	p.boundary_refs[key]=replacement

static func reconcile(p: Dictionary, previous: Dictionary, command: String) -> void:
	migrate(p)
	for key in ["support","load_face"]:
		if p.get(key,"").is_empty():
			if p.boundary_refs.has(key) and p.get("cad_pending_boundaries",{}).get(key,false):
				p.boundary_refs[key].state="unresolved";p.boundary_refs[key].reason="CAD face changed or deleted; explicitly reassign or clear"
			elif p.boundary_refs.has(key) and p.boundary_refs[key].get("state")=="resolved":p.boundary_refs.erase(key)
			continue
		if (command=="ApplySupport" and key=="support") or (command=="ApplyLoad" and key=="load_face"):
			assign(p,key);continue
		if not p.boundary_refs.has(key):continue # Never repair a missing current-schema reference implicitly.
		var r: Dictionary=p.boundary_refs[key]
		if r.get("instance_uuid")!=p.instance_uuid:
			r.state="unresolved";r.reason="Boundary owner mismatch; explicitly reassign or clear"
			continue
		if r.get("definition_uuid")!=p.definition_uuid or r.get("source_sha256")!=p.get("cad_sha256","") or r.get("geometry_revision")!=p.geometry_revision:
			if (p.kind!="CAD" and previous.get("kind")==p.kind) or (command=="CommitCADFeature" and p.get("cad_topology_metadata",{}).get("native_history",false) and p.get("cad_safe_continuations",[]).has(p[key])):
				assign(p,key)
			else:
				r.state="unresolved";r.reason="Definition geometry changed; select a verified replacement face or clear this condition"
		elif r.get("state")=="resolved" and previous.get("instance_uuid")==p.instance_uuid:
			# Only document-owned rigid moves advance placement acceptance. Native
			# correspondence must still succeed before a meshed face can be used.
			r.transformation_revision=p.transformation_revision

static func error(p: Dictionary, require_current := true) -> String:
	if p.get("boundary_schema")!=1 or not p.get("boundary_refs") is Dictionary:return "Missing assembly boundary identity; reopen legacy document or explicitly reassign"
	if str(p.get("instance_uuid","")).length()!=36:return "Missing boundary instance UUID"
	for key in ["support","load_face"]:
		if p.get(key,"").is_empty() and not p.boundary_refs.has(key):continue
		var r=p.boundary_refs.get(key)
		if not r is Dictionary or r.get("schema")!=1:return "Missing or corrupted face identity: "+key
		if r.get("instance_uuid")!=p.instance_uuid:return "Cross-instance boundary reference: "+key
		if r.get("coordinate_system")!="global":return "Unsupported boundary coordinate system"
		if p.kind=="CAD" and r.get("state")!="unresolved":
			if not r.get("source_face") is Dictionary or not r.source_face.has("area") or not r.source_face.has("center"):return "Missing/corrupted persistent source-face anchor: "+key
			if r.get("state")=="resolved":
				var current=anchor(p,str(r.get("definition_face_id","")))
				for field in r.source_face:
					if not same_descriptor(field,r.source_face[field],current.get(field)):return "Source face descriptor changed without reassignment: "+key

		if r.get("state")=="unresolved":
			if require_current:return "Unresolved "+key+": "+str(r.get("reason","Reassign face"))
			continue
		if r.get("state")!="resolved" or r.get("definition_face_id")!=p.get(key):return "Corrupted boundary face reference: "+key
		if r.get("definition_uuid")!=p.get("definition_uuid") or r.get("source_sha256")!=p.get("cad_sha256","") or r.get("geometry_revision")!=p.get("geometry_revision"):return "Obsolete definition boundary reference: "+key
		if int(r.get("transformation_revision",-1))!=int(p.get("transformation_revision",0)):return "Stale boundary placement: "+key
		var known=p.get("cad_faces",[]) if p.kind=="CAD" else ["X-","X+","Y-","Y+","Z-","Z+"] if p.kind=="Box" else ["OuterSurface","PositiveY","NegativeY"] if p.kind=="Sphere" else ["InnerWall","OuterWall","InletEnd","OutletEnd"] if p.kind=="Pipe" else ["Bottom","Top","Lateral"]
		if not known.has(r.definition_face_id):return "Deleted or missing definition face: "+key
	return ""

