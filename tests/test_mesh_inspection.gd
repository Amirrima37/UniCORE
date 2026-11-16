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
	assert(inspection.connectivity[0] == [0])
	var first = inspection.contour("volume")
	assert(first.min == 1.0 and first.max == 1.0)
	assert(first.mesh == inspection.contour("volume").mesh)
	assert(inspection.contour("volume").mesh.get_surface_count()==1)
	var flat: Dictionary=data.duplicate(true)
	for n in flat.nodes: n[2]=0
	assert(Display.quality(flat,flat.elements[0]).degenerate)
	var reversed_hex: Dictionary=data.duplicate(true)
	for n in reversed_hex.nodes: n[0]=-n[0]
	assert(Display.quality(reversed_hex,reversed_hex.elements[0]).inverted)
	var distorted: Dictionary=data.duplicate(true)
	distorted.nodes[6]=[0.7,0.8,0.7]
	q=Display.quality(distorted,distorted.elements[0])
	assert(q.volume>0 and q.volume<1 and q.distortion>0)
	var nonfinite: Dictionary=data.duplicate(true)
	nonfinite.nodes[0]=[NAN,0,0]
	assert(Display.quality(nonfinite,nonfinite.elements[0]).invalid)
	nonfinite.nodes[0]=[INF,0,0]
	assert(Display.quality(nonfinite,nonfinite.elements[0]).invalid)
	inspection.prepare(nonfinite)
	assert(inspection.contour("jacobian").min==0)
	inspection.prepare(data)
	assert(inspection.contour("jacobian",true).mesh.get_surface_count()==0)
	var doc=load("res://core/cae/cae_document.gd").new()
	doc.execute("CreatePart")
	doc.generate_mesh(2)
	inspection.prepare(doc.data.mesh)
	assert(inspection.records.size()==24)
	assert(inspection.connectivity[13].size()==8)
	for record in inspection.records: assert(not record.ids.has(13))
	var volume := 0.0
	var minimum := INF
	for metric in inspection.metrics:
		volume+=metric.volume
		minimum=minf(minimum,metric.jacobian)
	if doc.data.mesh.has("quality"):
		assert(abs(volume-doc.data.mesh.quality.total_volume)<1e-8)
		assert(abs(minimum-doc.data.mesh.quality.minimum_jacobian)<1e-8)
	inspection.section(0.5)
	var exposed := false
	for record in inspection.records:
		if record.ids.has(13): exposed=true
	assert(exposed)
	assert(inspection.geometry("solid")==inspection.geometry("solid"))
	inspection.section(0.0)
	assert(inspection.records.is_empty())
	print("Mesh inspection: HEX8/TET4 analytical metrics, inversion, degeneracy, exterior extraction and contour PASS")
	quit()
