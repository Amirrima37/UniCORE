extends SceneTree
const Codec=preload("res://core/cae/mesh_fingerprint.gd")
var failures=0
func check(ok: bool, label: String):
 if not ok:failures+=1;push_error(label)
func _initialize():
 var Identity=load("res://core/cae/result_identity.gd")
 var mesh=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/step/cylinder.mesh.json"))
 var a=Codec.legacy(mesh)
 var restored=JSON.parse_string(JSON.stringify(mesh,"\t",true,true))
 check(a!=Codec.legacy(restored),"legacy mismatch reproduced")
 var first=JSON.stringify(JSON.parse_string(JSON.stringify(mesh,"",true,true)),"",true,true)
 var second=JSON.stringify(JSON.parse_string(JSON.stringify(restored,"",true,true)),"",true,true)
 for i in mini(first.length(),second.length()):
  if first[i]!=second[i]:print("FIRST_DIFFERENCE byte=",i," original=",first.substr(i-30,80)," restored=",second.substr(i-30,80));break
 check(Codec.fingerprint({"x":0,"y":-0.0})==Codec.fingerprint({"y":0.0,"x":0.0}),"key order, integer/float, signed zero")
 check(Codec.fingerprint({"x":1.0})!=Codec.fingerprint({"x":1.0000000000000002}),"one ULP change rejected")
 check(Codec.fingerprint({"x":[1,2]})!=Codec.fingerprint({"x":[2,1]}),"array order significant")
 var data={"revision":1,"parts":[{"dimensions":[1,2,3],"material":{"E":100},"force":[0,1,0]}],"mesh":mesh,"analysis":{"type":"static"}}
 data.mesh.divisions=2
 data.results={"ok":true,"revision":1,"model_parts":data.parts.duplicate(true),"model_analysis":data.analysis.duplicate(true),"mesh_divisions":2,"source_mesh_sha256":Codec.fingerprint(mesh),"mesh_fingerprint_version":2}
 var identity=Identity.new()
 check(identity.current(data),"fresh result")
 for change in ["coordinate","connectivity","node_order","geometry","material","load","analysis","hash","version"]:
  var modified=data.duplicate(true)
  match change:
   "coordinate":modified.mesh.nodes[0][0]+=0.000001
   "connectivity":modified.mesh.elements[0].reverse()
   "node_order":modified.mesh.nodes.reverse()
   "geometry":modified.parts[0].dimensions[0]+=1
   "material":modified.parts[0].material.E+=1
   "load":modified.parts[0].force[1]+=1
   "analysis":modified.analysis.type="other"
   "hash":modified.results.source_mesh_sha256="invalid"
   "version":modified.results.mesh_fingerprint_version=99
  check(not identity.current(modified),"reject "+change)
 var legacy=data.duplicate(true)
 legacy.results.erase("mesh_fingerprint_version")
 legacy.results.source_mesh_sha256=Codec.legacy(legacy.mesh)
 check(identity.current(legacy),"valid legacy retained")
 legacy.results.source_mesh_sha256="invalid"
 check(not identity.current(legacy),"invalid legacy rejected")
 print("CANONICAL_MESH_TEST failures=",failures)
 quit(1 if failures else 0)
