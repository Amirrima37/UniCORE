extends RefCounted
## Exterior triangles retain element ownership; no stress averaging or extrapolation.
var timings := {}
var source: Array=[]
var records: Array=[]
var fields := {}
var last_scale := NAN
const Display = preload("res://core/cae/mesh_display.gd")
const Colors = preload("res://core/cae/engineering_visuals.gd")
func values(result: Dictionary, field: String) -> Array:
	if field=="von_mises": return result.get(field,[])
	if field in ["ux","uy","uz"]:
		var components=[]
		for u in result.get("displacement",[]): components.append(u[["ux","uy","uz"].find(field)])
		return components
	if field.begins_with("stress_"):
		var components=[]
		var index=["stress_xx","stress_yy","stress_zz","stress_xy","stress_xz","stress_yz"].find(field)
		if index<0:return []
		for s in result.get("stress",[]):components.append(s[index])
		return components
	if field.begins_with("strain_"):
		var output=[];var index=["strain_xx","strain_yy","strain_zz","strain_xy","strain_xz","strain_yz"].find(field)
		if index<0:return []
		for strain in result.get("strain",[]):output.append(strain[index])
		return output
	var output := []
	for u in result.get("displacement",[]):
		output.append(sqrt(u[0]*u[0]+u[1]*u[1]+u[2]*u[2]) if u is Array and u.size()==3 else NAN)
	return output
func bounds(values_array: Array) -> Dictionary:
	var low := INF
	var high := -INF
	for v in values_array:
		if is_finite(v): low=minf(low,v); high=maxf(high,v)
	return {} if low==INF else {"low":low,"high":high}
func build(result: Dictionary, field: String, scale: float) -> Dictionary:
	# Exact equality covers numerical arrays and all metadata, including ownership.
	var relevant: Array=[result.get("nodes"),result.get("elements",result.get("tetrahedra",[])),result.get("displacement"),result.get("von_mises"),result.get("material_regions",[]),result.get("stress"),result.get("strain")]
	if relevant!=source:
		source=relevant.duplicate(true);records=[];fields.clear();last_scale=NAN
	if scale!=last_scale:
		fields.clear();last_scale=scale
	if fields.has(field):
		timings={"cache_hit":true}
		return fields[field]
	var nodes: Array=result.get("nodes",[])
	var cells: Array=result.get("elements",result.get("tetrahedra",[]))
	var displacement: Array=result.get("displacement",[])
	if nodes.is_empty() or displacement.size()!=nodes.size() or not is_finite(scale): return {"error":"Invalid displacement/node mapping"}
	for u in displacement:
		if not u is Array or u.size()!=3 or not (is_finite(u[0]) and is_finite(u[1]) and is_finite(u[2])): return {"error":"Invalid displacement vector"}
	for cell in cells:
		if cell.size() not in [4,8,10]: return {"error":"Unsupported result connectivity"}
		for id in cell:
			if int(id)!=id or id<0 or id>=nodes.size(): return {"error":"Invalid solver node ID"}
	var data := {"nodes":nodes,"elements":cells}
	var scalar_tick:=Time.get_ticks_usec()
	var scalar := values(result,field)
	var range_values := bounds(scalar)
	var low: float=range_values.get("low",0.0)
	var high: float=range_values.get("high",0.0)
	timings.scalar_ms=(Time.get_ticks_usec()-scalar_tick)/1000.0
	var surface_tick:=Time.get_ticks_usec()
	if records.is_empty():records=Display.surface_records(data)
	timings.exterior_ms=(Time.get_ticks_usec()-surface_tick)/1000.0
	var buffer_tick:=Time.get_ticks_usec()
	var vertices := PackedVector3Array()
	var colors := PackedColorArray()
	var scalars := PackedVector2Array()
	for record in records:
		for i in range(1,record.ids.size()-1):
			for id in [record.ids[0],record.ids[i],record.ids[i+1]]:
				var p: Array=nodes[id]
				var u: Array=displacement[id]
				vertices.append(Vector3(p[0]+scale*u[0],p[1]+scale*u[1],p[2]+scale*u[2]))
				var index: int=record.element if field=="von_mises" or field.begins_with("stress_") or field.begins_with("strain_") else id
				colors.append(Colors.color(scalar[index] if index<scalar.size() else NAN,low,high))
				var value: float=scalar[index] if index<scalar.size() else NAN
				scalars.append(Vector2((value-low)/(high-low) if high>low else 0.5,0) if is_finite(value) else Vector2(0,1))
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX]=vertices
	arrays[Mesh.ARRAY_COLOR]=colors
	arrays[Mesh.ARRAY_TEX_UV]=scalars
	timings.buffers_ms=(Time.get_ticks_usec()-buffer_tick)/1000.0
	var resource_tick:=Time.get_ticks_usec()
	var mesh := ArrayMesh.new()
	if not vertices.is_empty(): mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	var material := ShaderMaterial.new()
	material.shader=preload("res://shaders/cae_scalar.gdshader")
	var gradient := Gradient.new()
	gradient.set_color(0,Colors.color(0,0,1))
	gradient.set_color(1,Colors.color(1,0,1))
	for i in range(1,4): gradient.add_point(i/4.0,Colors.color(i/4.0,0,1))
	var texture := GradientTexture1D.new()
	texture.gradient=gradient
	texture.width=1024
	material.set_shader_parameter("color_map",texture)
	timings.resources_ms=(Time.get_ticks_usec()-resource_tick)/1000.0
	var mapped={"mesh":mesh,"material":material,"low":low,"high":high}
	fields[field]=mapped
	return mapped
