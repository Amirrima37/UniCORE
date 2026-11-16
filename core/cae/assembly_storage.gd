extends RefCounted
const Model=preload("res://core/cae/assembly_model.gd")
const HEAVY=["cad_base64","cad_model","cad_evaluated_model","cad_topology_metadata","cad_face_descriptors","cad_definition_faces","source_base64","geometry_identity"]
static func collision_error(document: Dictionary) -> String:
	if document.has("geometry_assets") or document.has("canonical_outline"):return "Reserved canonical storage field already present"
	for definition in document.get("part_definitions",{}).values():
		if definition.has("geometry_ref"):return "Reserved definition geometry reference already present"
	for part in document.get("results",{}).get("model_parts",[]):
		if part.has("storage_snapshot_geometry"):return "Reserved snapshot geometry reference already present"
	return ""
static func valid_references(value, assets: Dictionary) -> bool:
	if value is Array:
		for v in value:
			if not valid_references(v,assets):return false
	elif value is Dictionary:
		for key in value:
			if key in HEAVY:
				if not value[key] is Dictionary or not assets.has(value[key].get("unicore_asset")):return false
			elif not valid_references(value[key],assets):return false
	return true
static func sha(bytes: PackedByteArray) -> String:
	var context=HashingContext.new();context.start(HashingContext.HASH_SHA256);context.update(bytes)
	return context.finish().hex_encode()
static func intern(value, assets: Dictionary) -> Dictionary:
	var bytes=var_to_bytes(value);var id=sha(bytes)
	if not assets.has(id):assets[id]=Marshalls.raw_to_base64(bytes)
	return {"unicore_asset":id}
static func blobs(value, result: Array) -> void:
	if value is Dictionary:
		for key in value:
			if key in ["cad_base64","source_base64"] and value[key] is String and value[key].length()>128 and not result.has(value[key]):result.append(value[key])
			else:blobs(value[key],result)
	elif value is Array:
		for v in value:blobs(v,result)
static func identity_payload(value, assets: Dictionary, sources: Array):
	if not value is String:return ["literal",encode(value,assets,sources)]
	var segments=[value]
	for source in sources:
		var next=[]
		for segment in segments:
			if not segment is String:next.append(segment);continue
			var pieces=segment.split(source)
			for i in pieces.size():
				if i>0:next.append(intern(source,assets))
				next.append(pieces[i])
		segments=next
	return ["segments",segments]
static func encode(value, assets: Dictionary, sources: Array=[]):
	if value is Array:
		var a=[]
		for v in value:a.append(encode(v,assets,sources))
		return a
	if value is Dictionary:
		var d={}
		for key in value:
			if key=="geometry_identity":d[key]=intern(identity_payload(value[key],assets,sources),assets)
			elif key in HEAVY:d[key]=intern(encode(value[key],assets,sources),assets)
			else:d[key]=encode(value[key],assets,sources)
		return d
	return value
static func decode(value, assets: Dictionary):
	if value is Array:
		var a=[]
		for v in value:a.append(decode(v,assets))
		return a
	if value is Dictionary:
		var d={}
		for key in value:
			if key in HEAVY:
				if not value[key] is Dictionary or not assets.has(value[key].get("unicore_asset")):return null
				var payload=assets[value[key].unicore_asset]
				if key=="geometry_identity":
					if not payload is Array or payload.size()!=2:return null
					if payload[0]=="literal":d[key]=decode(payload[1],assets)
					elif payload[0]=="segments":
						var text=""
						for segment in payload[1]:
							if segment is String:text+=segment
							elif segment is Dictionary and assets.get(segment.get("unicore_asset")) is String:text+=assets[segment.unicore_asset]
							else:return null
						d[key]=text
					else:return null
				else:d[key]=decode(payload,assets)
			else:d[key]=decode(value[key],assets)
		return d
	return value
static func pack(document: Dictionary) -> Dictionary:
	var saved=document.duplicate(true);var assets={};var sources=[]
	blobs(saved.get("part_definitions",{}),sources)
	for id in saved.part_definitions:
		var definition=saved.part_definitions[id]
		definition.geometry_ref=intern(encode(definition.geometry,assets,sources),assets)
		definition.erase("geometry")
		for key in Model.GEOMETRY:definition.get("template",{}).erase(key)
	for part in saved.parts:
		for key in Model.GEOMETRY:part.erase(key)
	for part in saved.get("results",{}).get("model_parts",[]):
		part.storage_snapshot_geometry=intern(encode(Model.geometry(part),assets,sources),assets)
		for key in Model.GEOMETRY:part.erase(key)
	saved.mesh={"canonical_mesh_asset":intern(encode(saved.mesh,assets,sources),assets)}
	saved=encode(saved,assets,sources)
	saved.assembly_storage_schema=2
	saved.erase("assembly_definitions_encoding");saved.erase("assembly_definitions_payload")
	var index=[]
	for part in saved.parts:index.append({"id":part.id,"instance_uuid":part.instance_uuid,"definition_uuid":part.definition_uuid})
	return {"schema":1,"assembly_storage_schema":2,"parts":index,"canonical_outline":Marshalls.raw_to_base64(var_to_bytes(saved)),"geometry_assets":assets}
static func unpack(document: Dictionary) -> String:
	if not document.has("assembly_storage_schema"):return ""
	if document.assembly_storage_schema!=2 or not document.get("geometry_assets") is Dictionary:return "Unsupported canonical assembly storage"
	var assets={}
	var encoded_assets=document.geometry_assets
	if document.has("canonical_outline"):
		if not document.canonical_outline is String:return "Invalid canonical outline"
		var outline=bytes_to_var(Marshalls.base64_to_raw(document.canonical_outline))
		if not outline is Dictionary or not outline.get("parts") is Array:return "Invalid lossless document outline"
		var index=[]
		for part in outline.parts:
			if not part is Dictionary:return "Invalid canonical instance record"
			index.append({"id":part.get("id"),"instance_uuid":part.get("instance_uuid"),"definition_uuid":part.get("definition_uuid")})
		if Model.Identity.canonical(index)!=Model.Identity.canonical(document.parts):return "Canonical instance index mismatch"
		document.clear();document.merge(outline);document.geometry_assets=encoded_assets
	for id in document.geometry_assets:
		if not id is String or id.length()!=64:return "Invalid geometry asset identity"
		if not document.geometry_assets[id] is String:return "Invalid geometry asset"
		var bytes=Marshalls.base64_to_raw(document.geometry_assets[id])
		if bytes.is_empty() or sha(bytes)!=id:return "Corrupted geometry asset"
		assets[id]=bytes_to_var(bytes)
	document.erase("geometry_assets")
	if not valid_references(document,assets):return "Missing canonical asset reference"
	var decoded=decode(document,assets)
	if not decoded is Dictionary or not decoded.get("part_definitions") is Dictionary:return "Invalid canonical definitions"
	if not decoded.get("mesh",{}) is Dictionary or not decoded.get("results",{}) is Dictionary:return "Invalid canonical analysis envelope"
	for id in decoded.part_definitions:
		var definition=decoded.part_definitions[id]
		if not definition is Dictionary or not definition.get("geometry_ref") is Dictionary:return "Invalid definition geometry reference"
		if not definition.get("template",{}) is Dictionary:return "Invalid definition compatibility template"
		var geometry=assets.get(definition.get("geometry_ref",{}).get("unicore_asset"))
		if not geometry is Dictionary:return "Missing definition geometry"
		if not valid_references(geometry,assets):return "Missing geometry payload asset"
		geometry=decode(geometry,assets)
		if not geometry is Dictionary:return "Invalid definition geometry"
		definition.geometry=geometry;definition.erase("geometry_ref")
		for key in Model.GEOMETRY:definition.get("template",{}).erase(key)
	if decoded.get("mesh",{}).has("canonical_mesh_asset"):
		if not decoded.mesh.canonical_mesh_asset is Dictionary:return "Invalid canonical mesh reference"
		var mesh=assets.get(decoded.mesh.canonical_mesh_asset.get("unicore_asset"))
		if not mesh is Dictionary or not valid_references(mesh,assets):return "Invalid canonical mesh asset"
		decoded.mesh=decode(mesh,assets)
	for part in decoded.parts:
		var definition=decoded.part_definitions.get(part.get("definition_uuid"),{})
		if not definition.has("geometry"):return "Missing instance definition"
		for key in definition.geometry:
			if part.has(key):return "Duplicate mutable instance geometry"
			part[key]=definition.geometry[key]
	var snapshots=decoded.get("results",{}).get("model_parts",[])
	if not snapshots is Array:return "Invalid historical instance records"
	for part in snapshots:
		if not part is Dictionary or not part.get("storage_snapshot_geometry") is Dictionary:return "Invalid historical geometry reference"
		var geometry=assets.get(part.get("storage_snapshot_geometry",{}).get("unicore_asset"))
		if not geometry is Dictionary:return "Missing historical geometry"
		if not valid_references(geometry,assets):return "Missing historical payload asset"
		geometry=decode(geometry,assets)
		for key in geometry:part[key]=geometry[key]
		part.erase("storage_snapshot_geometry")
	document.clear();document.merge(decoded)
	return ""
static func freeze(value) -> void:
	if value is Dictionary:
		for v in value.values():freeze(v)
		value.make_read_only()
	elif value is Array:
		for v in value:freeze(v)
		value.make_read_only()
static func bind(document: Dictionary) -> void:
	for definition in document.get("part_definitions",{}).values():freeze(definition.geometry)
	for part in document.parts:
		var geometry=document.part_definitions[part.definition_uuid].geometry
		for key in geometry:part[key]=geometry[key]

	for part in document.get("results",{}).get("model_parts",[]):
		var geometry=document.part_definitions.get(part.get("definition_uuid"),{}).get("geometry",{})
		if not geometry.is_empty() and Model.Identity.canonical(Model.geometry(part))==Model.Identity.canonical(geometry):
			for key in geometry:part[key]=geometry[key]
