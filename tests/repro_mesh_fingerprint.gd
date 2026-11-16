extends SceneTree
func _initialize():
 var mesh=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/step/cylinder.mesh.json"))
 var a=JSON.stringify(JSON.parse_string(JSON.stringify(mesh,"",true,true)),"",true,true)
 var restored=JSON.parse_string(JSON.stringify(mesh,"\t",true,true))
 var b=JSON.stringify(JSON.parse_string(JSON.stringify(restored,"",true,true)),"",true,true)
 print("EQUAL=",mesh==restored," HASH=",a.sha256_text()==b.sha256_text())
 for i in mini(a.length(),b.length()):
  if a[i]!=b[i]:
   print("FIRST_BYTE=",i," BEFORE=",a.substr(maxi(0,i-60),140)," AFTER=",b.substr(maxi(0,i-60),140));break
 quit(0)
