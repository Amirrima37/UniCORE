extends SceneTree
const Document=preload("res://core/cae/cae_document.gd")
const Boundary=preload("res://core/cae/assembly_boundaries.gd")
var out=OS.get_environment("UNICORE_FACE_OUT")
var checks=[]
func check(value: bool,name: String):
	checks.append({"name":name,"passed":value})
	var f=FileAccess.open(out+"/unit.json",FileAccess.WRITE);f.store_string(JSON.stringify(checks,"  "));f.close()
	if not value:push_error(name);quit(1);assert(false,name)
func _init():
	check(not Boundary.same_descriptor("bounds",[NAN,0,0,1,1,1],[0,0,0,1,1,1]),"nonfinite face bounds rejected")
	var d=Document.new();d.data.parts=[JSON.parse_string(FileAccess.get_file_as_string(out+"/source-part.json"))]
	preload("res://core/cae/assembly_model.gd").synchronize(d.data)
	var source=d.data.parts[0];var instance=source.instance_uuid
	check(Boundary.error(source).is_empty(),"legacy migration sealed")
	check(d.execute("AddInstance",{"definition_uuid":source.definition_uuid}).is_empty(),"add instance")
	check(d.data.parts[1].support.is_empty() and d.data.parts[1].load_face.is_empty() and d.data.parts[1].boundary_refs.is_empty(),"new instance has no inherited conditions")
	check(d.execute("ApplySupport",{"index":1,"face":source.load_face}).is_empty(),"assign independent reversed support")
	check(d.data.parts[1].boundary_refs.support.instance_uuid!=instance,"distinct owner")
	check(d.execute("ApplyLoad",{"index":1,"face":source.support,"force":[0,-1500,0]}).is_empty(),"independent load")
	var reference=d.data.parts[1].boundary_refs.load_face.definition_face_id
	check(d.execute("SetPosition",{"index":1,"values":[2,0,0]}).is_empty(),"translate")
	check(d.execute("SetRotation",{"index":1,"values":[.2,.3,.4]}).is_empty(),"rotate")
	check(Boundary.error(d.data.parts[1]).is_empty() and d.data.parts[1].boundary_refs.load_face.definition_face_id==reference,"rigid move preserves physical face")
	d.undo();d.redo();check(Boundary.error(d.data.parts[1]).is_empty(),"move undo redo")
	check(d.execute("RemoveCondition",{"index":1,"key":"load_face"}).is_empty(),"clear assignment")
	check(not d.data.parts[1].boundary_refs.has("load_face"),"clear reference")
	d.undo();check(d.data.parts[1].load_face==reference,"undo clear")
	var original=d.data.duplicate(true)
	for failure in ["missing-face","missing-instance","cross-instance","deleted-face","stale-transform"]:
		var p=original.parts[1].duplicate(true)
		match failure:
			"missing-face":p.boundary_refs.erase("load_face")
			"missing-instance":p.erase("instance_uuid")
			"cross-instance":p.boundary_refs.load_face.instance_uuid=instance
			"deleted-face":p.cad_faces.erase(reference)
			"stale-transform":p.transformation_revision+=1
		check(not Boundary.error(p).is_empty(),failure+" blocked")
	check(d.save_project(out+"/unit-project.json")==OK,"save")
	var reopened=Document.new();check(reopened.open_project(out+"/unit-project.json").is_empty(),"reopen")
	check(reopened.data.parts[1].boundary_refs.load_face.instance_uuid==original.parts[1].instance_uuid,"persistent owner")
	var corrupted=JSON.parse_string(FileAccess.get_file_as_string(out+"/unit-project.json"))
	if corrupted.has("canonical_outline"):
		var outline=bytes_to_var(Marshalls.base64_to_raw(corrupted.canonical_outline))
		outline.parts[1].boundary_refs.load_face.instance_uuid=instance
		corrupted.canonical_outline=Marshalls.raw_to_base64(var_to_bytes(outline))
	else:corrupted.parts[1].boundary_refs.load_face.instance_uuid=instance
	var f=FileAccess.open(out+"/corrupt-project.json",FileAccess.WRITE);f.store_string(JSON.stringify(corrupted));f.close()
	check(not reopened.open_project(out+"/corrupt-project.json").is_empty() and reopened.data.parts[1].instance_uuid==original.parts[1].instance_uuid,"corrupt open atomic rejection")
	check(d.execute("RemoveInstance",{"index":1}).is_empty(),"delete instance")
	check(d.data.parts.size()==1 and d.data.parts[0].instance_uuid==instance and d.data.parts[0].support==source.support,"deletion cannot migrate conditions")
	# Actual native history: untouched base faces preserve references; changed cap does not.
	var first=JSON.parse_string(FileAccess.get_file_as_string(out+"/history-original.json"))
	var edited=JSON.parse_string(FileAccess.get_file_as_string(out+"/history-edited.json"))
	var graph_part=first.part;graph_part.id="history";graph_part.name="History bar";graph_part.material=source.material;graph_part.force=[0,1000,0];graph_part.support="";graph_part.load_face=""
	var support="";var load_face="";var lo=INF;var hi=-INF
	for key in graph_part.cad_faces:
		var y=graph_part.cad_face_centers[key][1]
		if y<lo:lo=y;support=key
		if y>hi:hi=y;load_face=key
	var h=Document.new();h.data.parts=[graph_part];preload("res://core/cae/assembly_model.gd").synchronize(h.data)
	check(h.execute("ApplySupport",{"index":0,"face":support}).is_empty(),"history support")
	check(h.execute("ApplyLoad",{"index":0,"face":load_face,"force":[0,1000,0]}).is_empty(),"history load")
	check(h.execute("CommitCADFeature",{"part":edited.part,"replace_ids":["history"],"topology":edited.topology}).is_empty(),"native definition edit")
	check(h.data.parts[0].support==support and h.data.parts[0].boundary_refs.support.state=="resolved","proven native face preserved")
	check(h.data.parts[0].boundary_refs.load_face.state=="unresolved" and h.data.parts[0].boundary_refs.load_face.definition_face_id==load_face,"changed face retains unresolved origin")
	check(not Boundary.error(h.data.parts[0]).is_empty(),"unresolved definition blocks")
	check(h.save_project(out+"/unresolved.json")==OK,"save unresolved")
	var unresolved=Document.new();check(unresolved.open_project(out+"/unresolved.json").is_empty(),"reopen unresolved diagnostics")
	check(h.execute("ApplyLoad",{"index":0,"face":h.data.parts[0].cad_faces[0],"force":[0,1000,0]}).is_empty(),"explicit reassignment")
	h.undo();check(h.data.parts[0].boundary_refs.load_face.state=="unresolved","undo reassignment")
	h.redo();check(h.data.parts[0].boundary_refs.load_face.state=="resolved","redo reassignment")
	var primitive=Document.new();primitive.execute("CreatePart")
	primitive.execute("ApplySupport",{"index":0,"face":"X-"})
	var primitive_id=primitive.data.parts[0].id
	check(primitive.execute("CommitCADFeature",{"part":first.part,"replace_ids":[primitive_id],"topology":first.topology}).is_empty(),"primitive-to-CAD conversion")
	check(primitive.data.parts[0].boundary_refs.support.state=="unresolved","converted primitive boundary unresolved")
	check(primitive.save_project(out+"/converted-primitive.json")==OK,"save converted unresolved")
	var converted=Document.new();check(converted.open_project(out+"/converted-primitive.json").is_empty(),"reopen converted unresolved safely")
	print("FACE_UNIT_PASS ",checks.size());quit()
