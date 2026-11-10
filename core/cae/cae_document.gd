extends RefCounted
## SI-only engineering document. Commands are shared by UI and automation.
signal changed
var data: Dictionary = {"schema": 1, "revision": 0, "units": "m-N-Pa-kg", "parts": [], "mesh": {}, "results": {}}
var undo_stack: Array = []
var redo_stack: Array = []

func vector_error(value, positive := false) -> String:
	if not value is Array or value.size() != 3: return "Expected three numeric components"
	for v in value:
		if not (v is int or v is float) or not is_finite(float(v)): return "Expected finite numbers"
		if positive and v <= 0: return "Dimensions and scale must be positive"
	return ""

func normalize_part(p: Dictionary) -> void:
	if not p.has("rotation"): p.rotation = [0.0, 0.0, 0.0]
	if not p.has("scale"): p.scale = [1.0, 1.0, 1.0]
	if not p.has("visible"): p.visible = true
	if not p.has("inner_diameter"): p.inner_diameter = float(p.dimensions[0]) * 0.7

func apply_parameters(p: Dictionary, parameters: Dictionary) -> String:
	var d: Array = p.dimensions.duplicate()
	for key in parameters:
		var value = parameters[key]
		if not (value is int or value is float) or not is_finite(float(value)) or value <= 0:
			return "Parameters must be finite and positive"
		match key:
			"length":
				if p.kind == "Sphere": return "Spheres use radius or diameter"
				d[0 if p.kind == "Box" else 1] = float(value)
			"width":
				if p.kind != "Box": return "Width applies to boxes"
				d[2] = float(value)
			"height":
				if p.kind == "Sphere": return "Spheres use radius or diameter"
				d[1] = float(value)
			"diameter", "outer_diameter":
				if p.kind == "Box" or (key == "outer_diameter" and p.kind != "Pipe"): return "Diameter does not apply to this primitive"
				d[0] = float(value)
			"radius":
				if p.kind == "Box": return "Boxes do not have a radius"
				d[0] = float(value) * 2.0
			"inner_diameter":
				if p.kind != "Pipe": return "Inner diameter applies to pipes"
				p.inner_diameter = float(value)
			"wall_thickness":
				if p.kind != "Pipe": return "Wall thickness applies to pipes"
				p.inner_diameter = float(d[0]) - 2.0 * float(value)
			_: return "Unknown parameter: " + str(key)
	if p.kind == "Pipe" and (p.inner_diameter <= 0 or p.inner_diameter >= d[0]):
		return "Pipe inner diameter must be positive and smaller than outer diameter"
	p.dimensions = d
	return ""

func execute(command: String, args: Dictionary = {}) -> String:
	if args.has("index"):
		var value = args.index
		if not (value is int or value is float) or not is_finite(float(value)) or float(value) != floor(float(value)): return "Body index must be an integer"
	if args.has("parameters") and not args.parameters is Dictionary: return "Parameters must be a dictionary"
	# Meshes/results are immutable snapshots. Editing a small parameter should
	# not copy every finite-element field into another full result allocation.
	var next: Dictionary = data.duplicate(false)
	next.parts = data.parts.duplicate(true)
	var parts: Array = next.parts
	var index: int = int(args.get("index", -1))
	if command == "SetAnalysis":
		if not args.get("analysis") is Dictionary: return "Analysis settings must be a dictionary"
		var settings: Dictionary = args.get("analysis", {})
		if settings.get("type", "static_structural") not in ["static_structural", "steady_thermal", "transient_thermal"]: return "Analysis is not implemented"
		if settings.get("element", "TET4") not in ["TET4", "HEX8"]: return "Unsupported element"
		if settings.get("type") == "transient_thermal":
			for key in ["time_step","steps","initial_temperature"]:
				var value = settings.get(key)
				if not (value is int or value is float) or not is_finite(float(value)): return "Transient thermal requires time_step, integer steps and initial_temperature"
			if settings.time_step<=0 or settings.steps<1 or settings.steps>200 or settings.steps!=floor(settings.steps) or settings.initial_temperature<0: return "Invalid transient time/temperature range"
		next.analysis = settings.duplicate(true)
	elif command == "CreatePart":
		var kind: String = str(args.get("kind", "Box"))
		if kind not in ["Box", "Cylinder", "Sphere", "Pipe"]: return "Unsupported primitive"
		var p := {"id": str(Time.get_ticks_usec()), "kind": kind, "name": args.get("name", kind + " " + str(parts.size()+1)), "dimensions": [1.0, 0.2, 0.2], "position": [0.0, 0.0, 0.0], "material": {"name": "Steel", "E": 210e9, "nu": 0.3, "density": 7850.0}, "support": "", "load_face": "", "force": [0.0, -1000.0, 0.0]}
		normalize_part(p)
		if not p.name is String or p.name.strip_edges().is_empty() or p.name.length()>80: return "Invalid part name"
		var error := apply_parameters(p, args.get("parameters", {}))
		if not error.is_empty(): return error
		parts.append(p)
	else:
		if index < 0 or index >= parts.size(): return "Select a body first"
		var p: Dictionary = parts[index]
		normalize_part(p)
		match command:
			"ClearAnalysisConditions":
				p.support = ""
				p.load_face = ""
				for key in ["pressure","prescribed","gravity","thermal","heat_source"]: p.erase(key)
			"SetParameters":
				var error := apply_parameters(p, args.get("parameters", {}))
				if not error.is_empty(): return error
			"SetDimensions", "SetPosition", "SetRotation", "SetScale":
				var values = args.get("values")
				var error := vector_error(values, command in ["SetDimensions", "SetScale"])
				if not error.is_empty(): return error
				var key: String = {"SetDimensions":"dimensions", "SetPosition":"position", "SetRotation":"rotation", "SetScale":"scale"}[command]
				p[key] = values.duplicate()
				if p.kind == "Pipe" and p.inner_diameter >= p.dimensions[0]: return "Inner diameter exceeds outer diameter"
			"Rename":
				var title: String = str(args.get("name", "")).strip_edges()
				if title.is_empty() or title.length() > 80: return "Name must contain 1 to 80 characters"
				p.name = title
			"SetVisibility": p.visible = bool(args.get("visible", true))
			"AssignMaterial", "AssignMaterialById":
				var material = args.get("material", {})
				if command == "AssignMaterialById": material = preload("res://core/cae/material_library.gd").new().find_material(str(args.get("material_id", "")))
				if not material is Dictionary or material.is_empty(): return "Unknown or invalid material"
				if ClassDB.class_exists("UniCoreGeometryTools"):
					var validation: Dictionary = ClassDB.instantiate("UniCoreGeometryTools").validate_material(material,"definition")
					if not validation.valid_definition: return str(validation.errors)
				else:
					for key in ["E","nu","density"]:
						if not (material.get(key) is int or material.get(key) is float): return "Native material validator required for incomplete records"
				p.material = material.duplicate(true)
			"ApplyThermalBoundary":
				if p.kind != "Box": return "Thermal regions currently require boxes"
				var bc = args.get("boundary", {})
				if not bc is Dictionary or bc.get("face") not in ["X-","X+","Y-","Y+","Z-","Z+"]: return "Invalid thermal face"
				if bc.get("kind") not in ["temperature","flux","convection"]: return "Unsupported thermal boundary"
				var keys: Array = ["h","ambient"] if bc.kind == "convection" else ["value"]
				for key in keys:
					var value = bc.get(key)
					if not (value is int or value is float) or not is_finite(float(value)): return "Thermal boundary needs finite SI values"
				if bc.kind == "temperature" and bc.value < 0: return "Temperature must be in Kelvin"
				if bc.kind == "convection" and (bc.h <= 0 or bc.ambient < 0): return "Convection requires h>0 and ambient Kelvin>=0"
				var conditions: Array = p.get("thermal", []).duplicate(true)
				for i in range(conditions.size()-1,-1,-1):
					if conditions[i].face == bc.face and conditions[i].kind == bc.kind: conditions.remove_at(i)
				conditions.append(bc.duplicate(true))
				p.thermal = conditions
			"SetHeatSource":
				var value = args.get("value")
				if not (value is int or value is float) or not is_finite(float(value)): return "Heat source needs finite W/m³"
				p.heat_source = float(value)
			"ApplyPressure", "ApplyDisplacement", "ApplyGravity":
				if p.kind != "Box": return "Analysis boundary regions currently support boxes"
				if command != "ApplyGravity" and args.get("face") not in ["X-","X+","Y-","Y+","Z-","Z+"]: return "Invalid geometric face"
				if command == "ApplyPressure":
					var value = args.get("value")
					if not (value is int or value is float) or not is_finite(float(value)): return "Invalid pressure"
					p.pressure = {"face":args.face,"value":float(value)}
				else:
					var error := vector_error(args.get("values"))
					if not error.is_empty(): return error
					if command == "ApplyGravity": p.gravity = args.values.duplicate()
					else: p.prescribed = {"face":args.face,"values":args.values.duplicate()}
			"ApplySupport", "ApplyLoad":
				if p.kind != "Box" or args.get("face") not in ["X-", "X+", "Y-", "Y+", "Z-", "Z+"]: return "Structural faces currently support boxes only"
				if command == "ApplySupport": p.support = args.face
				else:
					var error := vector_error(args.get("force"))
					if not error.is_empty(): return error
					p.load_face = args.face
					p.force = args.force.duplicate()
			"Delete": parts.remove_at(index)
			"Duplicate":
				var copy: Dictionary = p.duplicate(true)
				copy.id = str(Time.get_ticks_usec())
				copy.name += " copy"
				copy.position[0] += copy.dimensions[0] * 1.2
				parts.append(copy)
			_: return "Unknown command: " + command
	if next.parts == data.parts and next.get("analysis", {}) == data.get("analysis", {}): return ""
	undo_stack.append(data)
	if undo_stack.size() > 100: undo_stack.pop_front()
	redo_stack.clear()
	next.revision = int(data.revision) + 1
	next.mesh = {}
	data = next
	changed.emit()
	return ""

func undo() -> void:
	if undo_stack.is_empty(): return
	redo_stack.append(data.duplicate(true))
	data = undo_stack.pop_back()
	changed.emit()

func redo() -> void:
	if redo_stack.is_empty(): return
	undo_stack.append(data.duplicate(true))
	data = redo_stack.pop_back()
	changed.emit()

func validate() -> PackedStringArray:
	var errors := PackedStringArray()
	if data.parts.is_empty(): errors.append("Create a body")
	for p in data.parts:
		if p.kind != "Box": errors.append(p.name + ": volume meshing currently supports boxes only")
		var analysis: String = data.get("analysis",{}).get("type","static_structural")
		if ClassDB.class_exists("UniCoreGeometryTools"):
			var material_status: Dictionary = ClassDB.instantiate("UniCoreGeometryTools").validate_material(p.material,analysis)
			if not material_status.ok: errors.append(p.name + ": material missing " + str(material_status.missing) + "; " + str(material_status.errors))
		if analysis == "static_structural":
			if p.support == "" and not p.has("prescribed"): errors.append(p.name + ": fixed or prescribed displacement support required")
			if p.load_face == "" and not p.has("pressure") and not p.has("gravity") and not p.has("prescribed"): errors.append(p.name + ": load required")
			if p.has("gravity") and (p.material.get("density") == null or float(p.material.density)<=0): errors.append(p.name + ": gravity requires positive material density")
		elif analysis == "steady_thermal":
			var anchored := false
			for bc in p.get("thermal",[]):
				if bc.get("kind")=="temperature" or (bc.get("kind")=="convection" and bc.get("h",0)>0): anchored=true
			if not anchored: errors.append(p.name + ": a temperature or positive convection condition is required")
	return errors

func generate_mesh(divisions: int) -> String:
	if divisions < 1 or divisions > 16: return "Mesh divisions must be 1..16"
	if data.parts.is_empty(): return "Create a box first"
	if data.parts.size() * (divisions+1) * (divisions+1) * (divisions+1) > 10000: return "Mesh node limit: 10000"
	for p in data.parts:
		if p.kind != "Box": return "Only boxes support analysis volume meshing"
	if ClassDB.class_exists("UniCoreStructuralSolver"):
		var mesher = ClassDB.instantiate("UniCoreStructuralSolver")
		var generated: Dictionary = mesher.generate_mesh(data, divisions)
		if not generated.get("ok", false): return str(generated.get("error", "Meshing failed"))
		data.mesh = generated.mesh
		changed.emit()
		return ""
	for p in data.parts:
		var r: Array = p.get("rotation",[0,0,0])
		var scale: Array = p.get("scale",[1,1,1])
		if not Vector3(r[0],r[1],r[2]).is_zero_approx() or not Vector3(scale[0],scale[1],scale[2]).is_equal_approx(Vector3.ONE): return "Transformed mesh requires native extension"
	var nodes: Array = []
	var elements: Array = []
	var regions: Dictionary = {}
	for p in data.parts:
		if p.kind != "Box": return "Only boxes support volume meshing in this version"
		var offset: int = nodes.size()
		var n: int = divisions + 1
		var faces := {"X-": [], "X+": [], "Y-": [], "Y+": [], "Z-": [], "Z+": []}
		for k in n:
			for j in n:
				for i in n:
					var id: int = nodes.size()
					nodes.append([p.position[0] + (float(i)/divisions-0.5)*p.dimensions[0], p.position[1] + (float(j)/divisions-0.5)*p.dimensions[1], p.position[2] + (float(k)/divisions-0.5)*p.dimensions[2]])
					if i == 0: faces["X-"].append(id)
					if i == divisions: faces["X+"].append(id)
					if j == 0: faces["Y-"].append(id)
					if j == divisions: faces["Y+"].append(id)
					if k == 0: faces["Z-"].append(id)
					if k == divisions: faces["Z+"].append(id)
		for k in divisions:
			for j in divisions:
				for i in divisions:
					var a: int = offset + i + n*j + n*n*k
					elements.append([a, a+1, a+n+1, a+n, a+n*n, a+n*n+1, a+n*n+n+1, a+n*n+n])
		regions[p.id] = faces
	data.mesh = {"revision": data.revision, "formulation": "HEX8", "nodes": nodes, "elements": elements, "regions": regions, "divisions": divisions}
	changed.emit()
	return ""

func save_project(path: String) -> Error:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null: return FileAccess.get_open_error()
	file.store_string(JSON.stringify(data, "\t", true, true))
	return OK

func open_project(path: String) -> String:
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not parsed is Dictionary or parsed.get("schema") != 1 or not parsed.get("parts") is Array:
		return "Invalid CAE project"
	if not parsed.get("mesh", {}) is Dictionary or not parsed.get("results", {}) is Dictionary: return "Invalid mesh/results envelope"
	if not (parsed.get("revision") is int or parsed.get("revision") is float): return "Invalid revision"
	var ids := {}
	# Validate before replacing the active document.
	for p in parsed.parts:
		if not p is Dictionary: return "Invalid body"
		for key in ["id", "kind", "name", "dimensions", "position", "material", "support", "load_face", "force"]:
			if not p.has(key): return "Missing body field: " + key
		if not p.id is String or p.id.is_empty() or ids.has(p.id): return "Invalid or duplicate body identifier"
		ids[p.id] = true
		if not p.name is String or p.name.strip_edges().is_empty(): return "Invalid body name"
		if not p.material is Dictionary: return "Invalid material"
		for key in ["E", "nu", "density"]:
			var v = p.material.get(key)
			if v != null and (not (v is int or v is float) or not is_finite(float(v))): return "Invalid material value"
		for key in ["dimensions", "position", "force"]:
			if not p[key] is Array or p[key].size() != 3: return "Invalid " + key
		for value in p.dimensions:
			if not value is float and not value is int: return "Invalid dimension"
			if not is_finite(float(value)) or value <= 0: return "Invalid dimension"
	if parsed.get("units") != "m-N-Pa-kg": return "Unsupported units"
	for p in parsed.parts:
		normalize_part(p)
		if p.kind not in ["Box", "Cylinder", "Sphere", "Pipe"]: return "Unsupported geometry"
		for key in ["position", "rotation", "scale", "force"]:
			var error := vector_error(p[key], key == "scale")
			if not error.is_empty(): return error
		if p.kind == "Pipe" and (p.inner_diameter <= 0 or p.inner_diameter >= p.dimensions[0]): return "Invalid pipe wall"
	data = parsed
	undo_stack.clear()
	redo_stack.clear()
	changed.emit()
	return ""
