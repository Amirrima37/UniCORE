extends RefCounted
static func cad_sha256(bytes: PackedByteArray) -> String:
	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(bytes)
	return context.finish().hex_encode()
## SI-only engineering document. Commands are shared by UI and automation.
const Storage = preload("res://core/cae/assembly_storage.gd")
const Boundaries = preload("res://core/cae/assembly_boundaries.gd")
const Assembly = preload("res://core/cae/assembly_model.gd")
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
			"inner_radius":
				if p.kind!="Pipe": return "Inner radius applies to pipes"
				p.inner_diameter=float(value)*2
			"outer_radius":
				if p.kind!="Pipe": return "Outer radius applies to pipes"
				d[0]=float(value)*2
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
	if data.has("assembly_schema"):
		var ownership_error=Assembly.validate(data)
		if not ownership_error.is_empty():return ownership_error
	if command == "RotateInstanceAxis":
		var i = int(args.get("index",-1))
		if i<0 or i>=data.parts.size():return "Select an instance"
		var error = vector_error(args.get("axis"))
		if not error.is_empty():return error
		var a=args.axis;var axis=Vector3(a[0],a[1],a[2])
		var angle=args.get("angle")
		if axis.is_zero_approx() or not (angle is float or angle is int) or not is_finite(float(angle)):return "Invalid axis rotation"
		var r=data.parts[i].get("rotation",[0,0,0])
		var euler=(Basis(axis.normalized(),angle)*Basis.from_euler(Vector3(r[0],r[1],r[2]))).get_euler()
		return execute("SetRotation",{"index":i,"values":[euler.x,euler.y,euler.z]})
	command = {"CreatePartDefinition":"CreatePart", "DuplicateInstance":"Duplicate", "RemoveInstance":"Delete", "TranslateInstance":"SetPosition", "RotateInstance":"SetRotation"}.get(command, command)
	if command=="ApplyStudyBoundary":
		var staging=get_script().new()
		staging.data=data
		var error: String=staging.execute("SetAnalysis",{"analysis":args.get("analysis",{})})
		if not error.is_empty():return error
		error=staging.execute(str(args.get("command","")),args.get("arguments",{}))
		if not error.is_empty():return error
		if staging.data==data:return ""
		undo_stack.append(data)
		if undo_stack.size()>100:undo_stack.pop_front()
		redo_stack.clear()
		data=staging.data
		data.revision=int(undo_stack[-1].revision)+1
		changed.emit()
		return ""
	if args.has("index"):
		var value = args.index
		if not (value is int or value is float) or not is_finite(float(value)) or float(value) != floor(float(value)): return "Body index must be an integer"
	if args.has("parameters") and not args.parameters is Dictionary: return "Parameters must be a dictionary"
	# Meshes/results are immutable snapshots. Editing a small parameter should
	# not copy every finite-element field into another full result allocation.
	var next: Dictionary = data.duplicate(false)
	next.parts = Assembly.clone_parts(data.parts)
	Assembly.synchronize(next)
	var parts: Array = next.parts
	var index: int = int(args.get("index", -1))
	if command == "AddInstance":
		var source = {}
		for part in parts:
			if part.definition_uuid == args.get("definition_uuid"): source = part
		if source.is_empty():
			var definition = next.part_definitions.get(args.get("definition_uuid", ""), {})
			if definition.is_empty(): return "Unknown part definition"
			source = definition.template.duplicate(true)
			for key in definition.geometry:source[key]=definition.geometry[key]
		var copy = Assembly.clone_parts([source])[0]
		copy.id = Assembly.uuid()
		copy.instance_uuid = Assembly.uuid()
		copy.name += " instance"
		Boundaries.clear_instance(copy)
		parts.append(copy)
	elif command == "SetMeshSettings":
		if index<0 or index>=parts.size():return "Select a body for mesh settings"
		var config=args.get("settings")
		var config_error=preload("res://core/cae/mesh_config.gd").validate(config,surface_names(parts[index]))
		if not config_error.is_empty():return config_error
		parts[index].mesh_settings=config.duplicate(true)
		if config.get("order",1)==2:
			if next.get("analysis",{}).get("backend")!="calculix":return "TET10 requires the CalculiX backend"
			next.analysis=next.analysis.duplicate(true);next.analysis.element="TET10"
		elif config.schema==2:
			next.analysis=next.get("analysis",{}).duplicate(true);next.analysis.element="TET4"
	elif command == "CommitCADFeature":
		var result=args.get("part")
		if not result is Dictionary or result.get("kind")!="CAD":return "Missing evaluated CAD feature"
		var graph_error=preload("res://core/cae/cad_model.gd").validate(result.get("cad_model"))
		if not graph_error.is_empty():return graph_error
		if result.cad_model!=result.get("cad_evaluated_model"):return "CAD graph has not been evaluated"
		if cad_sha256(Marshalls.base64_to_raw(result.get("cad_base64","")))!=result.get("cad_sha256"):return "Corrupt evaluated CAD BRep"
		var removed=args.get("replace_ids",[])
		if not removed is Array or removed.is_empty():return "Select CAD operands"
		var base_index=-1
		for i in parts.size():
			if parts[i].id==removed[0]:base_index=i
		if base_index<0:return "CAD base no longer exists"
		var base=parts[base_index].duplicate(true)
		for key in result:
			# Geometry workers cannot replace instance ownership or engineering inputs.
			if key in ["id","instance_uuid","definition_uuid","geometry_revision","transformation_revision","material","visible","analysis_enabled","support","load_face","force","boundary_schema","boundary_refs","cad_pending_boundaries","cad_boundary_archive","cad_topology_review","pressure","prescribed","thermal","gravity","mesh_settings"]:continue
			base[key]=result[key]
		base.id=parts[base_index].id
		base.name=str(args.get("name",base.name))
		base.cad_topology_review=args.get("topology",{}).duplicate(true)
		# Keep displaced engineering inputs for inspection and explicit reassignment.
		base.cad_boundary_archive=base.get("cad_boundary_archive",[]).duplicate(true)
		base.cad_pending_boundaries=base.get("cad_pending_boundaries",{}).duplicate(true)
		var native_safe_faces: Array=result.get("cad_safe_continuations",[]) if result.get("cad_topology_metadata",{}).get("native_history",false) else []
		if base.has("mesh_settings"):
			for rule in base.mesh_settings.local:
				if not base.cad_faces.has(rule.face) or (result.has("cad_topology_metadata") and not native_safe_faces.has(rule.face)):rule.enabled=false;rule.needs_review=true
		for key in ["support","load_face"]:
			if not base.get(key,"").is_empty() and (not base.cad_faces.has(base[key]) or (result.has("cad_topology_metadata") and not native_safe_faces.has(base[key]))):
				base.cad_boundary_archive.append({"condition":key,"face":base[key],"force":base.get("force",[]).duplicate(true),"previous_descriptor":parts[base_index].get("cad_face_descriptors",{}).get(base[key],{}).duplicate(true),"geometry_revision":parts[base_index].get("cad_geometry_revision",""),"reason":"Face modified/deleted/ambiguous"})
				base.cad_topology_review[key]="Face modified/deleted/ambiguous; review and reassign"
				base.cad_pending_boundaries[key]=true
				base[key]=""
		# Other condition types are never transferred implicitly through topology changes.
		for key in ["pressure","prescribed","thermal"]:
			if base.has(key):
				base.cad_boundary_archive.append({"condition":key,"configuration":base[key],"reason":"CAD recomputation requires reassignment"})
				base.erase(key)
				base.cad_topology_review[key]="Review condition after CAD recomputation"
				base.cad_pending_boundaries[key]=true
		# Consumed operands can carry engineering conditions too. They cannot be
		# silently dropped or merged into the pack's single support/load slots.
		for operand in parts:
			if operand.id==base.id or operand.id not in removed:continue
			for key in ["support","load_face","pressure","prescribed","thermal"]:
				if not operand.has(key):continue
				var configuration=operand[key]
				if (configuration is String or configuration is Array or configuration is Dictionary) and configuration.is_empty():continue
				var token="operand:"+str(operand.id)+":"+key
				base.cad_boundary_archive.append({"condition":key,"source_body":operand.id,"configuration":configuration,"force":operand.get("force",[]).duplicate(true),"source_geometry":{"kind":operand.kind,"dimensions":operand.dimensions.duplicate(),"position":operand.position.duplicate(),"rotation":operand.get("rotation",[0,0,0]).duplicate()},"reason":"Consumed operand: explicitly review, clear and reassign conditions on the resulting body"})
				base.cad_pending_boundaries[token]=true
				base.cad_topology_review[token]="Consumed operand condition requires review"
		parts[base_index]=base
		for i in range(parts.size()-1,-1,-1):
			if parts[i].id in removed and parts[i].id!=base.id:parts.remove_at(i)
	elif command == "SetAnalysis":
		if not args.get("analysis") is Dictionary: return "Analysis settings must be a dictionary"
		var settings: Dictionary = args.get("analysis", {})
		if settings.get("type", "static_structural") not in ["static_structural", "steady_thermal", "transient_thermal"]: return "Analysis is not implemented"
		if settings.get("element", "TET4") not in ["TET4", "TET10", "HEX8"]: return "Unsupported element"
		if settings.get("element")=="TET10" and (settings.get("backend")!="calculix" or settings.get("type")!="static_structural"):return "TET10 supports CalculiX linear static structural only"
		if settings.get("type") == "transient_thermal":
			for key in ["time_step","steps","initial_temperature"]:
				var value = settings.get(key)
				if not (value is int or value is float) or not is_finite(float(value)): return "Transient thermal requires time_step, integer steps and initial_temperature"
			if settings.time_step<=0 or settings.steps<1 or settings.steps>200 or settings.steps!=floor(settings.steps) or settings.initial_temperature<0: return "Invalid transient time/temperature range"
		var solver_error := extreme_settings_error(settings.get("extreme_solver",{}))
		if not solver_error.is_empty(): return solver_error
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
	elif command == "ImportSTEP":
		if str(args.get("cad_base64", "")).length()>89478488: return "STEP asset exceeds 64 MiB import bound"
		var bytes := Marshalls.base64_to_raw(str(args.get("cad_base64", "")))
		if bytes.is_empty() or bytes.size()>64*1024*1024 or cad_sha256(bytes)!=args.get("cad_sha256", ""): return "Invalid STEP asset"
		var p := {"id": str(Time.get_ticks_usec()), "kind":"CAD", "name":str(args.get("name","Imported STEP")), "dimensions":[1.0,1.0,1.0], "position":[0.0,0.0,0.0], "rotation":[0.0,0.0,0.0], "scale":[1.0,1.0,1.0], "cad_base64":args.cad_base64, "cad_sha256":args.cad_sha256, "cad_faces":[], "material":{"name":"Steel","E":210e9,"nu":0.3,"density":7850.0}, "support":"", "load_face":"", "force":[0.0,1000.0,0.0]}
		normalize_part(p)
		parts.append(p)
	else:
		if index < 0 or index >= parts.size(): return "Select a body first"
		var p: Dictionary = parts[index]
		normalize_part(p)
		if p.has("cad_model") and command in ["SetParameters","SetDimensions","SetScale"]:return "Edit the CAD feature graph, then preview and confirm recomputation"
		match command:
			"SetAnalysisEnabled":
				if not args.get("enabled") is bool:return "Analysis participation must be boolean"
				p.analysis_enabled=args.enabled
			"RefreshCADFaces", "InitializeCADMetadata":
				var metadata=args.get("metadata",{})
				if p.kind!="CAD" or not metadata is Dictionary or metadata.get("source_sha256")!=p.cad_sha256:return "Face review source mismatch"
				var table=metadata.get("definition_faces",{})
				if not table is Dictionary or table.is_empty() or table.size()>4096:return "Missing native definition face evidence"
				for id in table:
					if not id is String or not table[id] is Dictionary:return "Invalid definition face evidence"
					for field in ["area","center","bounds","inertia"]:
						if not table[id].has(field):return "Incomplete native face descriptor"
				var initialize=command=="InitializeCADMetadata"
				var initial_geometry=initialize and p.get("cad_faces",[]).is_empty()
				var measured_dimensions=[]
				if initialize:
					if metadata.get("native_validation",{}).get("status")!="VALID":return "Native source metadata is not valid"
					if not p.get("cad_faces",[]).is_empty():
						var old_names=p.cad_faces.duplicate();var new_names=table.keys();old_names.sort();new_names.sort()
						if old_names!=new_names:return "Native preview changed face names; explicitly review and reassign"
					var factor=metadata.get("source_to_m")
					if not metadata.get("source_units") is String or not (factor is float or factor is int) or not is_finite(float(factor)) or factor<=0:return "Invalid native source units"
					for key in ["cad_source_units","cad_source_to_m"]:
						var measured=metadata["source_units" if key=="cad_source_units" else "source_to_m"]
						if p.has(key) and p[key]!=measured:return "Native source units differ from definition"
					if initial_geometry:
						var bounds=metadata.native_validation.get("bounds",[])
						if not bounds is Array or bounds.size()!=6:return "Missing native source bounds"
						for axis in 3:
							if not is_finite(float(bounds[axis])) or not is_finite(float(bounds[axis+3])) or bounds[axis+3]<=bounds[axis]:return "Invalid native source bounds"
							measured_dimensions.append(bounds[axis+3]-bounds[axis])
				for instance in parts:
					if instance.definition_uuid!=p.definition_uuid:continue
					if initialize:
						instance.cad_source_units=metadata.source_units;instance.cad_source_to_m=metadata.source_to_m
						if initial_geometry:instance.dimensions=measured_dimensions.duplicate()
					instance.cad_definition_faces=table.duplicate(true)
					instance.cad_validation=metadata.get("native_validation",{}).duplicate(true)
					instance.cad_volume=metadata.get("cad_volume",0)
					instance.cad_faces=table.keys()
					instance.cad_face_areas={};instance.cad_face_centers={}
					for id in table:
						instance.cad_face_areas[id]=table[id].area;instance.cad_face_centers[id]=table[id].center
					for key in instance.get("boundary_refs",{}):
						if initialize:continue
						instance.boundary_refs[key].state="unresolved"
						instance.boundary_refs[key].reason="Definition face names explicitly reviewed; select replacement or clear"
				next.part_definitions[p.definition_uuid]=next.part_definitions[p.definition_uuid].duplicate(false)
				next.part_definitions[p.definition_uuid].faces=table.duplicate(true)
				if initialize:
					var geometry=next.part_definitions[p.definition_uuid].geometry.duplicate(false)
					geometry.cad_source_units=metadata.source_units;geometry.cad_source_to_m=metadata.source_to_m
					if initial_geometry:geometry.dimensions=measured_dimensions.duplicate()
					next.part_definitions[p.definition_uuid].geometry=geometry
			"RemoveCondition":
				var key: String=str(args.get("key",""))
				if key.begins_with("thermal:"):
					var found := false
					var conditions: Array=p.get("thermal",[]).duplicate(true)
					for i in range(conditions.size()-1,-1,-1):
						if key=="thermal:"+conditions[i].kind+":"+conditions[i].face:
							conditions.remove_at(i)
							found=true
					if not found: return "Condition no longer exists"
					p.thermal=conditions
				elif key in ["support","load_face"]:
					if p.get(key,"").is_empty() and not p.get("boundary_refs",{}).has(key): return "Condition no longer exists"
					p[key]=""
					if p.has("boundary_refs"):p.boundary_refs.erase(key)
					if p.has("cad_pending_boundaries"):p.cad_pending_boundaries.erase(key)
				elif key in ["pressure","prescribed","gravity","heat_source"]:
					if not p.has(key): return "Condition no longer exists"
					p.erase(key)
				else: return "Unknown condition"
			"ClearAnalysisConditions":
				p.cad_pending_boundaries={}
				if p.has("boundary_refs"):p.boundary_refs={}
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
				if p.kind == "CAD" and command == "SetScale": return "CAD instance scaling is unsupported"
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
				if p.kind not in ["Box","Cylinder","Sphere","Pipe"]: return "Thermal regions require boxes, cylinders or spheres"
				var bc = args.get("boundary", {})
				if not bc is Dictionary or bc.get("face") not in surface_names(p): return "Invalid thermal face"
				if bc.get("kind") not in ["temperature","flux","convection","radiation"]: return "Unsupported thermal boundary"
				var keys: Array = ["emissivity","surroundings"] if bc.kind=="radiation" else ["h","ambient"] if bc.kind == "convection" else ["value"]
				if bc.kind=="radiation" and bc.get("use_material_emissivity",false):
					bc=bc.duplicate(true)
					bc.emissivity=p.material.get("emissivity")
				for key in keys:
					var value = bc.get(key)
					if not (value is int or value is float) or not is_finite(float(value)): return "Thermal boundary needs finite SI values"
				if bc.kind == "temperature" and bc.value < 0: return "Temperature must be in Kelvin"
				if bc.kind == "convection" and (bc.h <= 0 or bc.ambient < 0): return "Convection requires h>0 and ambient Kelvin>=0"
				if bc.kind=="radiation" and (bc.emissivity<0 or bc.emissivity>1 or bc.surroundings<0): return "Radiation requires 0<=emissivity<=1 and surroundings Kelvin>=0"
				var conditions: Array = p.get("thermal", []).duplicate(true)
				for i in range(conditions.size()-1,-1,-1):
					if conditions[i].face == bc.face and conditions[i].kind == bc.kind: conditions.remove_at(i)
				conditions.append(bc.duplicate(true))
				p.thermal = conditions
			"SetHeatSource":
				var value = args.get("value")
				if not (value is int or value is float) or not is_finite(float(value)): return "Heat source needs finite W/m³"
				p.heat_source = float(value)
			"ApplySphereExpansion":
				var strain=args.get("strain")
				if p.kind!="Sphere" or not (strain is float or strain is int) or not is_finite(float(strain)): return "Sphere expansion requires finite strain"
				p.prescribed={"face":"OuterSurface","values":[0.0,0.0,0.0],"radial_strain":float(strain)}
			"ApplyPressure", "ApplyDisplacement", "ApplyGravity":
				if p.kind not in ["Box","Cylinder","Sphere","Pipe"]: return "Analysis regions require boxes, cylinders or spheres"
				if p.kind in ["Cylinder","Sphere","Pipe"] and command=="ApplyGravity": return p.kind+" gravity export is not validated"
				if command != "ApplyGravity" and args.get("face") not in surface_names(p): return "Invalid geometric face"
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
				if p.kind not in ["Box","Cylinder","Sphere","Pipe","CAD"] or args.get("face") not in surface_names(p): return "Unsupported structural region"
				if command == "ApplySupport": p.support = args.face
				else:
					var error := vector_error(args.get("force"))
					if not error.is_empty(): return error
					p.load_face = args.face
					p.force = args.force.duplicate()
				if p.has("cad_pending_boundaries"):
					p.cad_pending_boundaries.erase("support" if command=="ApplySupport" else "load_face")
				if p.has("cad_topology_review"):
					p.cad_topology_review.erase("support" if command=="ApplySupport" else "load_face")
			"Delete": parts.remove_at(index)
			"Duplicate":
				var copy: Dictionary = Assembly.clone_parts([p])[0]
				copy.id = Assembly.uuid()
				copy.instance_uuid = Assembly.uuid()
				copy.name += " copy"
				Boundaries.clear_instance(copy)
				copy.position[0] += copy.dimensions[0] * 1.2
				parts.append(copy)
			_: return "Unknown command: " + command
	Assembly.synchronize(next)
	for part in next.parts:
		for old in data.parts:
			if old.id == part.id and [old.position, old.get("rotation"), old.get("scale")] != [part.position, part.get("rotation"), part.get("scale")]:
				part.transformation_revision = int(old.get("transformation_revision", 0)) + 1
		var previous={}
		for old in data.parts:
			if old.id==part.id:previous=old
		Boundaries.reconcile(part,previous,command)
		var conflict: String=preload("res://core/cae/condition_conflicts.gd").error(part)
		if not conflict.is_empty():return conflict
	if next.parts == data.parts and next.get("analysis", {}) == data.get("analysis", {}): return ""
	undo_stack.append(data)
	if undo_stack.size() > 100: undo_stack.pop_front()
	redo_stack.clear()
	next.revision = int(data.revision) + 1
	next.mesh = {}
	if command=="SetMeshSettings":next.mesh=data.mesh
	Storage.bind(next)
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
	var participation_error=preload("res://core/cae/analysis_participation.gd").error(data)
	if not participation_error.is_empty():errors.append(participation_error)
	var solver_error := extreme_settings_error(data.get("analysis",{}).get("extreme_solver",{}))
	if not solver_error.is_empty(): errors.append(solver_error)
	if data.parts.is_empty(): errors.append("Create a body")
	for p in data.parts:
		if not p.get("analysis_enabled",true):continue
		var boundary_error=Boundaries.error(p)
		if not boundary_error.is_empty():errors.append(boundary_error)
		var conflict: String=preload("res://core/cae/condition_conflicts.gd").error(p,data.get("mesh",{}))
		if not conflict.is_empty():errors.append(p.name+": "+conflict)
		if p.kind not in ["Box","Cylinder","Sphere","Pipe"]: errors.append(p.name + ": volume meshing supports boxes, cylinders or spheres only")
		if p.kind in ["Cylinder","Sphere","Pipe"] and data.get("analysis",{}).get("element","TET4")=="HEX8": errors.append(p.kind+" requires TET4")
		if p.kind in ["Cylinder","Sphere","Pipe"] and p.has("gravity"): errors.append(p.kind+" gravity export is not validated")
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
				if bc.get("kind")=="temperature" or (bc.get("kind")=="convection" and bc.get("h",0)>0) or (bc.get("kind")=="radiation" and bc.get("emissivity",0)>0): anchored=true
			if not anchored: errors.append(p.name + ": a temperature or positive convection condition is required")
	return errors

func generate_mesh(divisions: int) -> String:
	if not data.get("_participation_resolved",false):
		var participation=preload("res://core/cae/analysis_participation.gd")
		var error=participation.error(data)
		if not error.is_empty():return error
		var staging=get_script().new();staging.data=participation.view(data)
		error=staging.generate_mesh(divisions)
		if not error.is_empty():return error
		data.mesh=staging.data.mesh
		data.mesh.analysis_participation=participation.signature(data)
		changed.emit();return ""
	if divisions < 1 or divisions > 16: return "Mesh divisions must be 1..16"
	if data.parts.is_empty(): return "Create a box first"
	if data.parts.any(func(part): return part.kind=="Pipe"):
		if data.get("analysis",{}).get("element","TET4")=="HEX8": return "Pipe requires TET4"
		var generated: Dictionary=preload("res://core/cae/pipe_mesher.gd").generate(data,divisions)
		if generated.has("error"): return generated.error
		data.mesh=generated.mesh
		changed.emit()
		return ""
	if data.parts.any(func(part): return part.kind=="Sphere"):
		if data.get("analysis",{}).get("element","TET4")=="HEX8": return "Sphere volume meshing requires TET4"
		var generated: Dictionary=preload("res://core/cae/sphere_mesher.gd").generate(data,divisions)
		if generated.has("error"): return generated.error
		data.mesh=generated.mesh
		changed.emit()
		return ""
	if data.parts.any(func(part): return part.kind=="Cylinder"):
		if data.get("analysis",{}).get("element","TET4")=="HEX8": return "Cylinder volume meshing requires TET4"
		var generated: Dictionary=preload("res://core/cae/cylinder_mesher.gd").generate(data,divisions)
		if generated.has("error"): return generated.error
		data.mesh=generated.mesh
		changed.emit()
		return ""
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
					var local = Vector3((float(i)/divisions-0.5)*p.dimensions[0], (float(j)/divisions-0.5)*p.dimensions[1], (float(k)/divisions-0.5)*p.dimensions[2])
					var r = p.get("rotation", [0,0,0])
					var scale = p.get("scale", [1,1,1])
					var world = Basis.from_euler(Vector3(r[0],r[1],r[2])) * (local * Vector3(scale[0],scale[1],scale[2])) + Vector3(p.position[0],p.position[1],p.position[2])
					nodes.append([world.x,world.y,world.z])
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
	if not Storage.collision_error(data).is_empty():return ERR_INVALID_DATA
	if not Assembly.validate(data).is_empty():return ERR_INVALID_DATA
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null: return FileAccess.get_open_error()
	var saved=data.duplicate(true)
	Assembly.synchronize(saved)
	
	for part in saved.parts+saved.get("results",{}).get("model_parts",[]):
		if part.has("mesh_settings"):
			part.mesh_settings_encoding="unicore-mesh-settings-v1"
			part.mesh_settings_payload=Marshalls.raw_to_base64(var_to_bytes(part.mesh_settings))
			part.erase("mesh_settings")
	# Preserve exact binary64 coordinates; bytes_to_var never permits objects.
	saved.mesh=data.mesh
	file.store_string(JSON.stringify(Storage.pack(saved), "\t", true, true))
	return OK

func open_project(path: String) -> String:
	var source := FileAccess.open(path,FileAccess.READ)
	if source==null:return "Cannot open CAE project"
	if source.get_length()>256*1024*1024:return "CAE project exceeds 256 MiB import bound"
	source.close()
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not parsed is Dictionary or parsed.get("schema") != 1 or not parsed.get("parts") is Array:
		return "Invalid CAE project"
	var storage_error=Storage.unpack(parsed)
	if not storage_error.is_empty():return storage_error
	if parsed.has("assembly_definitions_encoding"):
		if parsed.assembly_definitions_encoding!="unicore-assembly-definitions-v1" or not parsed.get("assembly_definitions_payload") is String:return "Invalid assembly definitions encoding"
		var definitions=bytes_to_var(Marshalls.base64_to_raw(parsed.assembly_definitions_payload))
		if not definitions is Dictionary:return "Invalid assembly definitions payload"
		parsed.part_definitions=definitions
		parsed.erase("assembly_definitions_encoding");parsed.erase("assembly_definitions_payload")
	if not parsed.get("mesh", {}) is Dictionary or not parsed.get("results", {}) is Dictionary: return "Invalid mesh/results envelope"
	if parsed.mesh.has("encoding"):
		if parsed.mesh.encoding!="unicore-variant-mesh-v1" or not parsed.mesh.get("payload") is String:return "Unsupported mesh encoding"
		var restored=bytes_to_var(Marshalls.base64_to_raw(parsed.mesh.payload))
		if not restored is Dictionary:return "Invalid lossless mesh payload"
		parsed.mesh=restored
	for part in parsed.get("results",{}).get("model_parts",[]):
		if part is Dictionary:
			var settings_error=decode_mesh_settings(part)
			if not settings_error.is_empty():return settings_error
			var graph_error=decode_cad_graph(part)
			if not graph_error.is_empty():return graph_error
	if not (parsed.get("revision") is int or parsed.get("revision") is float): return "Invalid revision"
	var ids := {}
	# Validate before replacing the active document.
	for p in parsed.parts:
		if not p is Dictionary: return "Invalid body"
		var settings_error=decode_mesh_settings(p)
		if not settings_error.is_empty():return settings_error
		if p.has("cad_graph_encoding") or p.has("cad_topology_metadata"):
			var graph_error=decode_cad_graph(p)
			if not graph_error.is_empty():return graph_error
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
		if p.kind not in ["Box", "Cylinder", "Sphere", "Pipe", "CAD"]: return "Unsupported geometry"
		if p.kind == "CAD":
			if p.has("cad_model"):
				if p.cad_model!=p.get("cad_evaluated_model"):return "CAD graph changed without recomputation; regenerate the evaluated BRep"
				var graph_error=preload("res://core/cae/cad_model.gd").validate(p.cad_model)
				if not graph_error.is_empty():return graph_error
			if str(p.get("cad_base64", "")).length()>89478488:return "Embedded STEP asset exceeds 64 MiB import bound"
			var bytes := Marshalls.base64_to_raw(str(p.get("cad_base64", "")))
			if bytes.is_empty() or bytes.size()>64*1024*1024 or cad_sha256(bytes)!=p.get("cad_sha256", ""): return "Missing or corrupted embedded STEP asset"
		if p.has("mesh_settings"):
			var config_error=preload("res://core/cae/mesh_config.gd").validate(p.mesh_settings,surface_names(p))
			if not config_error.is_empty():return config_error
		for key in ["position", "rotation", "scale", "force"]:
			var error := vector_error(p[key], key == "scale")
			if not error.is_empty(): return error
		if p.kind == "Pipe" and (p.inner_diameter <= 0 or p.inner_diameter >= p.dimensions[0]): return "Invalid pipe wall"
	if parsed.mesh.has("mesh_settings"):
		var mesh_error=preload("res://core/cae/mesh_config.gd").validate(parsed.mesh.mesh_settings,[],false)
		if not mesh_error.is_empty():return "Invalid stored mesh settings: "+mesh_error
	if parsed.mesh.has("mesh_schema") and parsed.mesh.mesh_schema!=2:return "Unsupported mesh schema"
	if parsed.mesh.get("formulation")=="TET10":
		if parsed.mesh.get("mesh_schema")!=2 or parsed.mesh.get("node_order")!="CalculiX C3D10":return "Unsupported quadratic mesh schema or node ordering"
		var nodes=parsed.mesh.get("nodes",[])
		if not nodes is Array or nodes.is_empty() or nodes.size()>200000:return "Invalid quadratic mesh node count"
		for point in nodes:
			if not vector_error(point).is_empty():return "Invalid quadratic mesh coordinate"
		if not parsed.mesh.get("elements") is Array or parsed.mesh.elements.is_empty() or parsed.mesh.elements.size()>1000000:return "Invalid quadratic element count"
		for cell in parsed.mesh.get("elements",[]):
			if not cell is Array or cell.size()!=10:return "Invalid quadratic connectivity"
			var seen={}
			for id in cell:
				if not (id is int or id is float) or not is_finite(float(id)) or id!=floor(id) or id<0 or id>=nodes.size() or seen.has(id):return "Invalid quadratic node index"
				seen[id]=true
	var assembly_error = Assembly.validate(parsed)
	if not assembly_error.is_empty(): return assembly_error
	Assembly.synchronize(parsed)
	for part in parsed.parts:
		var boundary_error=Boundaries.error(part,false)
		if not boundary_error.is_empty():return boundary_error
	Storage.bind(parsed)
	data = parsed
	undo_stack.clear()
	redo_stack.clear()
	changed.emit()
	return ""

func extreme_settings_error(options) -> String:
	if not options is Dictionary: return "Extreme solver settings must be a dictionary"
	if options.is_empty(): return ""
	if options.get("preconditioner","jacobi") not in ["jacobi","block-jacobi","ic0"]: return "Unsupported preconditioner"
	for key in ["relative_tolerance","absolute_tolerance","max_iterations","threads","memory_mb"]:
		var value=options.get(key)
		if not (value is int or value is float) or not is_finite(float(value)): return "Missing or nonfinite solver setting: "+key
	if options.relative_tolerance<0 or options.absolute_tolerance<0 or options.relative_tolerance+options.absolute_tolerance<=0: return "At least one nonnegative tolerance must be positive"
	for key in ["max_iterations","threads","memory_mb"]:
		if options[key]<1 or options[key]!=floor(options[key]): return "Positive integer required: "+key
	if options.max_iterations>2147483647 or options.threads>OS.get_processor_count(): return "Solver iteration/thread limit exceeded"
	return ""

static func surface_names(part: Dictionary) -> Array:
	return part.get("cad_faces",[]) if part.kind=="CAD" else ["InnerWall","OuterWall","InletEnd","OutletEnd"] if part.kind=="Pipe" else ["OuterSurface","PositiveY","NegativeY"] if part.kind=="Sphere" else ["Bottom","Top","Lateral"] if part.kind=="Cylinder" else ["X-","X+","Y-","Y+","Z-","Z+"]

static func decode_cad_graph(part: Dictionary) -> String:
	if part.has("cad_topology_metadata"):
		if not part.cad_topology_metadata is Dictionary:return "Invalid CAD topology metadata record"
		var topology_version=part.cad_topology_metadata.get("schema")
		if (not (topology_version is int or topology_version is float)) or (topology_version!=1 and topology_version!=2):return "Unsupported CAD topology metadata; recompute with a supported version"
	if not part.has("cad_graph_encoding"):return ""
	if part.cad_graph_encoding!="unicore-cad-graph-v1" or not part.get("cad_graph_payload") is String:return "Unsupported CAD graph encoding"
	var graph=bytes_to_var(Marshalls.base64_to_raw(part.cad_graph_payload))
	if not graph is Array or graph.size()!=2 or not graph[0] is Dictionary or not graph[1] is Dictionary:return "Corrupted CAD graph payload"
	part.cad_model=graph[0];part.cad_evaluated_model=graph[1]
	part.erase("cad_graph_payload");part.erase("cad_graph_encoding")
	return ""

static func decode_mesh_settings(part: Dictionary) -> String:
	if not part.has("mesh_settings_encoding"):return ""
	if part.mesh_settings_encoding!="unicore-mesh-settings-v1" or not part.get("mesh_settings_payload") is String:return "Unsupported mesh settings encoding"
	var value=bytes_to_var(Marshalls.base64_to_raw(part.mesh_settings_payload))
	var error=preload("res://core/cae/mesh_config.gd").validate(value,[],false)
	if not error.is_empty():return error
	part.mesh_settings=value;part.erase("mesh_settings_payload");part.erase("mesh_settings_encoding")
	return ""

