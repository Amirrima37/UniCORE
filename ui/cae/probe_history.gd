extends Control
var values: Array=[]
var times: Array=[]
func _draw():
	if values.size()<2:return
	var lo: float=values.min();var hi: float=values.max();var points:=PackedVector2Array()
	for i in values.size():points.append(Vector2((times[i]-times[0])/maxf(times[-1]-times[0],1e-30)*size.x,size.y-4-(values[i]-lo)/maxf(hi-lo,1e-30)*(size.y-8)))
	draw_polyline(points,Color("62b7d9"),2,true)
