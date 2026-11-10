extends SceneTree
const Display=preload("res://core/cae/mesh_display.gd")
func _initialize():
	var data={"nodes":[[0,0,0],[1,0,0],[1,1,0],[0,1,0],[0,0,1],[1,0,1],[1,1,1],[0,1,1]],"elements":[[0,1,2,3,4,5,6,7]]}
	var q=Display.quality(data,data.elements[0])
	assert(abs(q.volume-1)<1e-12)
	assert(abs(q.jacobian-0.125)<1e-12)
	assert(abs(q.aspect_ratio-1)<1e-12)
	assert(abs(q.distortion)<1e-12)
	var tet=[0,1,3,4]
	q=Display.quality(data,tet)
	assert(abs(q.volume-1.0/6)<1e-12)
	q=Display.quality(data,[0,3,1,4])
	assert(q.inverted)
	q=Display.quality(data,[0,1,3,2])
	assert(q.degenerate)
	assert(Display.exterior_faces([tet,[0,3,1,5]]).size()==6)
	var Inspection=load("res://core/cae/mesh_inspection.gd")
	var inspection=Inspection.new()
	inspection.prepare(data)
	assert(inspection.records.size()==6)
	assert(inspection.contour("volume").mesh.get_surface_count()==1)
	print("Mesh inspection: HEX8/TET4 analytical metrics, inversion, degeneracy, exterior extraction and contour PASS")
	quit()
