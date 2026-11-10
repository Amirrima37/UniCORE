extends RefCounted
const DEFAULT_PATH="res://data/materials/library.json"
const CUSTOM_PATH="user://engineering_materials.json"
var records: Array=[]
func _init() -> void:
	var builtin=JSON.parse_string(FileAccess.get_file_as_string(DEFAULT_PATH))
	if builtin is Dictionary: records=builtin.materials
	if FileAccess.file_exists(CUSTOM_PATH):
		var custom=JSON.parse_string(FileAccess.get_file_as_string(CUSTOM_PATH))
		if custom is Array: records.append_array(custom)
func validate(material: Dictionary,analysis: String="definition") -> Dictionary:
	if ClassDB.class_exists("UniCoreGeometryTools"):
		return ClassDB.instantiate("UniCoreGeometryTools").validate_material(material,analysis)
	return {"ok":false,"valid_definition":false,"errors":["Updated native material validator unavailable"],"missing":[]}
func persist_custom(material: Dictionary) -> String:
	var status:=validate(material)
	if not status.valid_definition: return str(status.errors)
	if str(material.get("name","")).strip_edges().is_empty(): return "Material needs a name"
	var copy:=material.duplicate(true)
	copy.id="custom_"+str(Time.get_ticks_usec())
	copy.definition_version=1
	copy.custom=true
	records.append(copy)
	var custom: Array=[]
	for record in records:
		if record.get("custom",false): custom.append(record)
	var file:=FileAccess.open(CUSTOM_PATH,FileAccess.WRITE)
	if file==null: return "Could not save custom materials"
	file.store_string(JSON.stringify(custom,"\t",true,true))
	return ""
func find_material(title: String) -> Dictionary:
	for record in records:
		if record.id==title or record.name.to_lower()==title.to_lower(): return record.duplicate(true)
	return {}
