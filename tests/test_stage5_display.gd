extends SceneTree
const Display=preload("res://core/cae/structural_display.gd")
const Colors=preload("res://core/cae/engineering_visuals.gd")
func _initialize():
	var display=Display.new()
	var r={"nodes":[[0,0,0],[1,0,0],[0,1,0],[0,0,1]],"elements":[[0,1,2,3]],"displacement":[[0,0,0],[0.001,0,0],[0,0,0],[0,0,0]],"von_mises":[123.0]}
	var original=JSON.stringify(r)
	var start=Time.get_ticks_usec()
	var built=display.build(r,"displacement",100)
	assert(not built.has("error"))
	var vertices=built.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	assert(vertices.size()==12)
	assert(abs(vertices[1].x-1.1)<1e-6 or vertices.has(Vector3(1.1,0,0)))
	assert(abs(built.high-0.001)<1e-12 and built.low==0)
	var stress=display.build(r,"von_mises",0)
	for color in stress.mesh.surface_get_arrays(0)[Mesh.ARRAY_COLOR]: assert(color.is_equal_approx(Colors.color(123,123,123)))
	display.build(r,"displacement",100)
	assert(JSON.stringify(r)==original)
	r.von_mises=[]
	for color in display.build(r,"von_mises",0).mesh.surface_get_arrays(0)[Mesh.ARRAY_COLOR]: assert(color==Color.MAGENTA)
	r.elements=[[0,1,2,99]]
	assert(display.build(r,"displacement",1).has("error"))
	print("Stage5 mapping / constant stress / missing / deformation PASS; small build checks us=",Time.get_ticks_usec()-start)
	quit()
