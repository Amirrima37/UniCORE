extends RefCounted
## Definitions are immutable geometry snapshots. parts remains the instance view.
const Identity = preload("res://core/cae/mesh_fingerprint.gd")
const GEOMETRY = ["kind", "dimensions", "inner_diameter", "cad_base64", "cad_sha256", "cad_format", "cad_model", "cad_evaluated_model", "cad_source_units", "cad_source_to_m"]

static func uuid() -> String:
	var b = Crypto.new().generate_random_bytes(16)
	b[6] = (b[6] & 15) | 64
	b[8] = (b[8] & 63) | 128
	var h = b.hex_encode()
	return h.substr(0,8)+"-"+h.substr(8,4)+"-"+h.substr(12,4)+"-"+h.substr(16,4)+"-"+h.substr(20)

static func geometry(part: Dictionary) -> Dictionary:
	var result = {}
	for key in GEOMETRY:
		if part.has(key): result[key] = part[key]
	return result

static func synchronize(document: Dictionary) -> void:
	document.assembly_schema = 1
	document.part_definitions = document.get("part_definitions", {}).duplicate(false)
	for part in document.parts:
		if not part.has("analysis_enabled"):part.analysis_enabled=true
		if not part.has("inner_diameter"): part.inner_diameter = float(part.dimensions[0]) * 0.7
		if not part.has("instance_uuid"): part.instance_uuid = uuid()
		var source = geometry(part)
		var previous = document.part_definitions.get(part.get("definition_uuid", ""), {})
		if Identity.canonical(previous.get("geometry")) != Identity.canonical(source):
			part.definition_uuid = uuid()
			part.geometry_revision = int(previous.get("geometry_revision", 0)) + 1
			document.part_definitions[part.definition_uuid] = {"uuid":part.definition_uuid, "geometry_revision":part.geometry_revision, "geometry":source.duplicate(true), "template":template_view(part)}
		if not part.has("transformation_revision"): part.transformation_revision = 0
		preload("res://core/cae/assembly_boundaries.gd").migrate(part)

static func validate(document: Dictionary) -> String:
	if not document.has("assembly_schema"): return "" # Explicit legacy path.
	if document.assembly_schema != 1 or not document.get("part_definitions") is Dictionary: return "Invalid assembly schema"
	var seen = {}
	for part in document.parts:
		if not part.get("analysis_enabled",true) is bool:return "Invalid analysis participation"
		var id = part.get("instance_uuid", "")
		if not id is String or id.length()!=36 or seen.has(id): return "Invalid instance UUID"
		seen[id] = true
		var definition = document.part_definitions.get(part.get("definition_uuid", ""), {})
		if definition.get("uuid") != part.get("definition_uuid") or Identity.canonical(definition.get("geometry")) != Identity.canonical(geometry(part)): return "Instance geometry differs from definition"
		if definition.get("geometry_revision") != part.get("geometry_revision"): return "Invalid geometry revision"
	return ""

static func template_view(part: Dictionary) -> Dictionary:
	var result=part.duplicate(false)
	for key in GEOMETRY:result.erase(key)
	return result.duplicate(true)
static func clone_parts(parts: Array) -> Array:
	var result=[]
	for part in parts:
		var copy=part.duplicate(false)
		for key in copy:
			if key not in GEOMETRY and (copy[key] is Dictionary or copy[key] is Array):copy[key]=copy[key].duplicate(true)
		result.append(copy)
	return result
