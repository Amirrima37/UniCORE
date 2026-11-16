extends RefCounted
## Read-only descriptors over the existing persisted numerical model; no second BC store.
static func entries(part: Dictionary) -> Array:
	var out: Array=[]
	if not part.get("support","").is_empty(): out.append(record("support","Fixed support",part.support,"ApplySupport",{"face":part.support},[],[]))
	if not part.get("load_face","").is_empty(): out.append(record("load_face","Force",part.load_face,"ApplyLoad",{"face":part.load_face,"force":part.force},["Fx · N","Fy · N","Fz · N"],part.force))
	if part.has("pressure"): out.append(record("pressure","Pressure",part.pressure.face,"ApplyPressure",part.pressure,["Pressure · Pa"],[part.pressure.value]))
	if part.has("prescribed") and part.prescribed.has("radial_strain"): out.append(record("prescribed","Sphere uniform expansion","OuterSurface","ApplySphereExpansion",{"strain":part.prescribed.radial_strain},["Strain"],[part.prescribed.radial_strain]))
	elif part.has("prescribed"): out.append(record("prescribed","Prescribed displacement",part.prescribed.face,"ApplyDisplacement",part.prescribed,["Ux · m","Uy · m","Uz · m"],part.prescribed.values))
	if part.has("gravity"): out.append(record("gravity","Gravity","Body","ApplyGravity",{"values":part.gravity},["gx · m/s²","gy · m/s²","gz · m/s²"],part.gravity))
	if part.has("heat_source"): out.append(record("heat_source","Heat source","Body","SetHeatSource",{"value":part.heat_source},["Source · W/m³"],[part.heat_source]))
	for bc in part.get("thermal",[]):
		var labels: Array=[]
		var values: Array=[]
		match bc.kind:
			"temperature": labels=["Temperature · K"]; values=[bc.value]
			"flux": labels=["Inward flux · W/m²"]; values=[bc.value]
			"convection": labels=["h · W/m²/K","Ambient · K"]; values=[bc.h,bc.ambient]
			"radiation": labels=["Emissivity · 0…1","Surroundings · K"]; values=[bc.emissivity,bc.surroundings]
		out.append(record("thermal:"+bc.kind+":"+bc.face,bc.kind.capitalize(),bc.face,"ApplyThermalBoundary",{"boundary":bc},labels,values))
	return out

static func record(key: String,title: String,target: String,command: String,args: Dictionary,labels: Array,values: Array) -> Dictionary:
	return {"key":key,"title":title,"target":target,"command":command,"args":args.duplicate(true),"labels":labels,"values":values.duplicate()}

static func edited_args(entry: Dictionary, values: Array) -> Dictionary:
	var args: Dictionary=entry.args.duplicate(true)
	match entry.command:
		"ApplyLoad": args.force=values
		"ApplyGravity","ApplyDisplacement": args["values"]=values
		"ApplySphereExpansion": args.strain=values[0]
		"ApplyPressure","SetHeatSource": args.value=values[0]
		"ApplyThermalBoundary":
			var keys: Array=["h","ambient"] if args.boundary.kind=="convection" else ["emissivity","surroundings"] if args.boundary.kind=="radiation" else ["value"]
			for i in keys.size(): args.boundary[keys[i]]=values[i]
			if args.boundary.kind=="radiation": args.boundary.use_material_emissivity=false
	return args
