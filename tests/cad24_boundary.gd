extends SceneTree
func _initialize():
	var d=preload("res://core/cae/cae_document.gd").new()
	d.data=JSON.parse_string(FileAccess.get_file_as_string("res://docs/architecture/evidence/cad21/fuse.json"))
	var p=d.data.parts[0]
	p.support=p.cad_faces[0];p.load_face=p.cad_faces[1]
	var evaluated=p.duplicate(true)
	evaluated.cad_topology_metadata={"schema":1,"native_history":false}
	assert(d.execute("CommitCADFeature",{"part":evaluated,"replace_ids":[p.id]}).is_empty())
	var current=d.data.parts[0]
	assert(current.support=="" and current.load_face=="")
	assert(current.cad_boundary_archive.size()==2)
	assert(current.cad_pending_boundaries.size()==2)
	assert(d.execute("ApplySupport",{"index":0,"face":current.cad_faces[0]}).is_empty())
	assert(d.data.parts[0].cad_pending_boundaries.size()==1)
	assert(d.execute("ApplyLoad",{"index":0,"face":current.cad_faces[1],"force":[0,1000,0]}).is_empty())
	assert(d.data.parts[0].cad_pending_boundaries.is_empty())
	assert(d.save_project(preload("res://tests/development_paths.gd").output_file("CAD/cad24-completion/boundary.ucae"))==OK)
	assert(d.open_project(preload("res://tests/development_paths.gd").output_file("CAD/cad24-completion/boundary.ucae")).is_empty())
	assert(d.data.parts[0].cad_boundary_archive.size()==2)
	var unknown=d.data.parts[0].duplicate(true);unknown.cad_topology_metadata.schema=999
	assert(not d.decode_cad_graph(unknown).is_empty())
	unknown.cad_topology_metadata=[]
	assert(not d.decode_cad_graph(unknown).is_empty())
	var original=d.data.duplicate(true)
	var malformed=d.data.duplicate(true);malformed.parts[0].cad_topology_metadata.schema=999
	var invalid_path=preload("res://tests/development_paths.gd").output_file("CAD/cad24-completion/unknown-topology-version.json")
	var invalid_file=FileAccess.open(invalid_path,FileAccess.WRITE);invalid_file.store_string(JSON.stringify(malformed,"",true,true));invalid_file.close()
	assert(not d.open_project(invalid_path).is_empty())
	assert(d.data==original)
	var tool=d.data.parts[0].duplicate(true);tool.id="consumed-tool";tool.support=tool.cad_faces[0];tool.load_face=tool.cad_faces[1];tool.force=[0,2000,0]
	d.data.parts.append(tool)
	var native_fixture=d.data.parts[0].duplicate(true)
	assert(d.execute("CommitCADFeature",{"part":native_fixture,"replace_ids":[d.data.parts[0].id,tool.id]}).is_empty())
	assert(d.data.parts.size()==1)
	assert(d.data.parts[0].cad_pending_boundaries.has("operand:consumed-tool:load_face"))
	assert(d.data.parts[0].cad_pending_boundaries.has("operand:consumed-tool:support"))
	var archived_tool_load=false
	for entry in d.data.parts[0].cad_boundary_archive:
		if entry.get("source_body")==tool.id and entry.condition=="load_face":archived_tool_load=entry.force==[0,2000,0]
	assert(archived_tool_load)
	assert(d.execute("ClearAnalysisConditions",{"index":0}).is_empty())
	assert(d.data.parts[0].cad_pending_boundaries.is_empty())
	print("CAD24_BOUNDARY_PASS")
	quit()
