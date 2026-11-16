extends SceneTree
var out=OS.get_environment("UNICORE_FACE_OUT")
const Document=preload("res://core/cae/cae_document.gd")
func _initialize():call_deferred("run")
func run():
	var d=Document.new();assert(d.open_project(out+"/duplicate2.json").is_empty())
	var bridge=preload("res://core/cae/calculix_workbench.gd").new();var rows=[]
	for name in ["missing-reference","deleted-face","missing-instance","cross-instance","stale-mesh","stale-classification","missing-mesh-face","misbound-cache","corrupted-anchor"]:
		var data=d.data.duplicate(true);var p=data.parts[0]
		match name:
			"missing-reference":p.boundary_refs.erase("load_face")
			"deleted-face":p.cad_faces.erase(p.load_face)
			"missing-instance":p.erase("instance_uuid")
			"cross-instance":p.boundary_refs.load_face.instance_uuid=data.parts[1].instance_uuid
			"stale-mesh":p.position[0]+=.01
			"stale-classification":p.geometry_revision+=1
			"missing-mesh-face":data.mesh.part_meshes[p.id].face_resolution.world_faces.erase(p.load_face)
			"misbound-cache":p.cad_face_centers[p.load_face]=p.cad_face_centers[p.support].duplicate()
			"corrupted-anchor":p.boundary_refs.load_face.source_face.center=[99,99,99]
		var result=bridge.solve_model(data)
		assert(not result.get("ok",false),name)
		rows.append({"case":name,"error":result.get("error")})
	assert(preload("res://core/cae/result_identity.gd").new().current(d.data))
	assert(d.execute("ApplyLoad",{"index":0,"face":d.data.parts[0].load_face,"force":[0,1200,0]}).is_empty())
	assert(not preload("res://core/cae/result_identity.gd").new().current(d.data))
	rows.append({"case":"stale-results-after-boundary-edit","passed":true})
	d.undo();assert(preload("res://core/cae/result_identity.gd").new().current(d.data))
	assert(d.execute("SetPosition",{"index":1,"values":[.05,0,0]}).is_empty())
	var rejected=bridge.generate_mesh(d.data,.05)
	assert(rejected.has("error") and "OVERLAPPING" in str(rejected.error))
	rows.append({"case":"overlap-after-assignment","error":rejected.error})
	var f=FileAccess.open(out+"/negative-document.json",FileAccess.WRITE);f.store_string(JSON.stringify(rows,"  "));f.close()
	print("FACE_NEGATIVE_PASS ",rows.size());quit()
