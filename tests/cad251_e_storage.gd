extends SceneTree
const Document=preload("res://core/cae/cae_document.gd")
const Model=preload("res://core/cae/assembly_model.gd")
var failed=false
var out=OS.get_environment("UNICORE_E_OUT")
func check(ok: bool,text: String):
	if not ok:failed=true;push_error(text);quit(1);assert(false,text)
func legacy_save(d,path):
	var saved=d.data.duplicate(true);Model.synchronize(saved)
	for definition in saved.part_definitions.values():
		for key in definition.geometry:definition.template[key]=definition.geometry[key]
	saved.assembly_definitions_encoding="unicore-assembly-definitions-v1"
	saved.assembly_definitions_payload=Marshalls.raw_to_base64(var_to_bytes(saved.part_definitions))
	saved.mesh={"encoding":"unicore-variant-mesh-v1","payload":Marshalls.raw_to_base64(var_to_bytes(saved.mesh))}
	var f=FileAccess.open(path,FileAccess.WRITE);f.store_string(JSON.stringify(saved,"\t",true,true));f.close()
func _init():
	var rows=[]
	var source=JSON.parse_string(FileAccess.get_file_as_string(OS.get_environment("UNICORE_D_SOURCE")+"/source-part.json"))
	for kind in ["brep","step","several"]:
		for count in ([1,2,10] if kind=="brep" else [10]):
			var d=Document.new()
			if kind=="step":
				var raw=FileAccess.get_file_as_bytes("res://tests/fixtures/step/bar.step")
				check(d.execute("ImportSTEP",{"cad_base64":Marshalls.raw_to_base64(raw),"cad_sha256":d.cad_sha256(raw)}).is_empty(),"STEP")
			else:
				d.data.parts=[source.duplicate(true)];Model.synchronize(d.data)
			var definition=d.data.parts[0].definition_uuid
			for k in count-1:check(d.execute("AddInstance",{"definition_uuid":definition}).is_empty(),"instance")
			if kind=="several":
				for k in 3:check(d.execute("CreatePart",{"kind":"Box"}).is_empty(),"different definition")
			d.data.future_engineering={"opaque":[1,"kept",{"unsupported":"retained"}]}
			d.data.parts[0].future_instance={"data":[7,8,9]}
			check(d.execute("SetAnalysisEnabled",{"index":0,"enabled":false}).is_empty(),"exclude")
			check(d.execute("SetVisibility",{"index":0,"visible":false}).is_empty(),"hide")
			var name=kind+str(count);var legacy=out+"/legacy-"+name+".json";var path=out+"/canonical-"+name+".json"
			legacy_save(d,legacy)
			check(d.save_project(path)==OK,"canonical save")
			var parsed=JSON.parse_string(FileAccess.get_file_as_string(path))
			check(parsed.assembly_storage_schema==2,"schema")
			if d.data.parts[0].has("cad_base64"):
				var copies=0
				for payload in parsed.geometry_assets.values():
					var value=bytes_to_var(Marshalls.base64_to_raw(payload))
					if value is String and value==d.data.parts[0].cad_base64:copies+=1
				check(copies==1,"source payload stored exactly once")
			for part in parsed.parts:
				for key in Model.GEOMETRY:check(not part.has(key),"instance has no independent persisted geometry")
			var reopened=Document.new();check(reopened.open_project(path).is_empty(),"canonical reopen")
			check(reopened.data.parts[0].instance_uuid==d.data.parts[0].instance_uuid and reopened.data.parts[0].definition_uuid==definition,"identities")
			check(not reopened.data.parts[0].analysis_enabled and not reopened.data.parts[0].visible,"flags")
			check(reopened.data.future_engineering==d.data.future_engineering and reopened.data.parts[0].future_instance==d.data.parts[0].future_instance,"unknown engineering fields")
			check(reopened.data.parts[0].dimensions.is_read_only(),"immutable canonical view")
			if count>1:check(is_same(reopened.data.parts[0].dimensions,reopened.data.parts[1].dimensions),"instances share canonical geometry in memory")
			check(reopened.execute("SetPosition",{"index":0,"values":[2,3,4]}).is_empty(),"canonical instance edit")
			reopened.undo();reopened.redo();check(reopened.data.parts[0].position==[2,3,4],"canonical undo redo")
			check(reopened.save_project(path+".roundtrip")==OK,"roundtrip")
			var migrated=Document.new();check(migrated.open_project(legacy).is_empty(),"legacy migration")
			check(migrated.data.parts[0].instance_uuid==d.data.parts[0].instance_uuid,"migration UUID")
			var invalid=parsed.duplicate(true);var first=invalid.geometry_assets.keys()[0];invalid.geometry_assets[first]="AAAA"
			var bad_path=path+".corrupted";var bad=FileAccess.open(bad_path,FileAccess.WRITE);bad.store_string(JSON.stringify(invalid));bad.close()
			check(not Document.new().open_project(bad_path).is_empty(),"corrupt asset rejects safely")
			for corruption in ["instance-record","definition-record","geometry-reference","mesh-envelope","mesh-reference","definition-template","historical-record"]:
				var malformed=parsed.duplicate(true);var outline=bytes_to_var(Marshalls.base64_to_raw(malformed.canonical_outline))
				match corruption:
					"instance-record":outline.parts[0]=null
					"definition-record":outline.part_definitions[definition]=null
					"geometry-reference":outline.part_definitions[definition].geometry_ref="broken"
					"mesh-envelope":outline.mesh="broken"
					"mesh-reference":outline.mesh.canonical_mesh_asset="broken"
					"definition-template":outline.part_definitions[definition].template="broken"
					"historical-record":outline.results.model_parts=[null]
				malformed.canonical_outline=Marshalls.raw_to_base64(var_to_bytes(outline))
				bad_path=path+"."+corruption;bad=FileAccess.open(bad_path,FileAccess.WRITE);bad.store_string(JSON.stringify(malformed));bad.close()
				var before=reopened.data
				check(not reopened.open_project(bad_path).is_empty() and is_same(before,reopened.data),"malformed canonical document rejects atomically: "+corruption)
			rows.append({"kind":kind,"instances":d.data.parts.size(),"definitions":d.data.part_definitions.size(),"legacy_bytes":FileAccess.get_file_as_bytes(legacy).size(),"canonical_bytes":FileAccess.get_file_as_bytes(path).size(),"asset_count":parsed.geometry_assets.size(),"static_memory_bytes":OS.get_static_memory_usage()})
			var f=FileAccess.open(out+"/storage.json",FileAccess.WRITE);f.store_string(JSON.stringify(rows,"  "));f.close()
	var legacy_doc=Document.new();check(legacy_doc.execute("CreatePart",{"kind":"Box"}).is_empty(),"primitive")
	legacy_doc.data.parts[0].erase("analysis_enabled")
	legacy_save(legacy_doc,out+"/legacy-default.json")
	var default_doc=Document.new();check(default_doc.open_project(out+"/legacy-default.json").is_empty(),"legacy no participation")
	check(default_doc.data.parts[0].analysis_enabled,"explicit legacy enabled default")
	if failed:quit(1);return
	print("CANONICAL_STORAGE_GATE_PASS");quit()
