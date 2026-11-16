extends RefCounted
## No implicit additive loading of a sphere parent and its child patches.
static func overlaps(a: String,b: String) -> bool:
	return a==b or a=="OuterSurface" or b=="OuterSurface"
static func error(part: Dictionary,mesh: Dictionary={}) -> String:
	if part.kind=="Sphere":
		if part.has("pressure") and not part.get("load_face","").is_empty() and overlaps(part.pressure.face,part.load_face):
			return "Overlapping sphere pressure and force targets; use one load or disjoint hemispheres"
		var thermal: Array=part.get("thermal",[])
		for i in thermal.size():
			for j in range(i+1,thermal.size()):
				if thermal[i].face!=thermal[j].face and overlaps(thermal[i].face,thermal[j].face):
					return "Overlapping sphere parent/child thermal conditions; use one surface or disjoint patches"
	if mesh.is_empty():return ""
	var groups: Dictionary=mesh.get("regions",{}).get(part.id,{})
	var temperatures: Dictionary={}
	for bc in part.get("thermal",[]):
		if bc.kind!="temperature":continue
		if not groups.has(bc.face):return "Thermal target no longer resolves to mesh nodes"
		for id in groups[bc.face]:
			if temperatures.has(id) and temperatures[id]!=bc.value:return "Conflicting temperatures on shared boundary nodes"
			temperatures[id]=bc.value
	return ""
