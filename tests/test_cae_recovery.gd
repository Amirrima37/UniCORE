extends SceneTree
var failures := 0
func check(condition: bool,message: String) -> void:
	if not condition:
		failures+=1
		push_error(message)
func _initialize() -> void:
	var timeout:=create_timer(30)
	timeout.timeout.connect(func(): push_error("Recovery test timeout"); quit(2))
	var workspace=load("res://ui/cae/cae_workspace.gd").new()
	root.add_child.call_deferred(workspace)
	await process_frame
	var sandbox:=Control.new()
	root.add_child(sandbox)
	var prompt:=LineEdit.new()
	prompt.size=Vector2(250,30)
	sandbox.add_child(prompt)
	prompt.grab_focus()
	var controller=load("res://core/workspace_mode_controller.gd").new()
	root.add_child(controller)
	var roots: Array[Node]=[sandbox]
	controller.setup(workspace,roots)
	controller.set_mode(1)
	check(workspace.active and not sandbox.visible,"Enter CAE: exclusive visibility")
	check(sandbox.process_mode==Node.PROCESS_MODE_DISABLED,"Sandbox input/process suspended")
	check(workspace.cad.viewport.render_target_update_mode!=SubViewport.UPDATE_DISABLED,"CAE render enabled")
	workspace.create_part("Cylinder")
	var p: Dictionary=workspace.document.data.parts[0]
	check(abs(p.dimensions[0]-.1)<1e-10 and abs(p.dimensions[1]-.2)<1e-10,"Cylinder defaults 100 x 200 mm")
	var body: MeshInstance3D=workspace.meshes[0]
	var old_id:=body.get_instance_id()
	# Change the actual bound diameter field, as a user would.
	workspace.inspector_bindings[0].node.value=150
	check(abs(workspace.document.data.parts[0].dimensions[0]-.15)<1e-10,"Inspector updates authoritative diameter")
	check(abs(workspace.meshes[0].mesh.top_radius-.075)<1e-8,"Inspector regenerates actual mesh")
	check(workspace.meshes[0].get_instance_id()==old_id,"Mesh instance retained")
	workspace.document.undo()
	check(abs(workspace.meshes[0].mesh.top_radius-.05)<1e-8,"Undo geometry")
	workspace.document.redo()
	check(abs(workspace.meshes[0].mesh.top_radius-.075)<1e-8,"Redo geometry")
	workspace.inspector_bindings[1].node.value=100
	check(abs(workspace.inspector_bindings[0].node.value-200)<1e-8,"Radius synchronizes diameter")
	workspace.run_command("SetRotation",{"values":[0,0,.5]})
	check(abs(workspace.meshes[0].rotation.z-.5)<1e-6,"Rotation updates transform")
	workspace.run_command("Rename",{"name":"Cylinder_01"})
	workspace.run_command("SetVisibility",{"visible":false})
	check(not workspace.meshes[0].visible,"Hide actual geometry")
	workspace.run_command("SetVisibility",{"visible":true})
	check(workspace.tree_items[0].get_text(0)=="Cylinder_01","Tree/name synchronization")
	var builds: int=workspace.cad.geometry_builds
	for i in 30: workspace.select_body(0)
	check(workspace.cad.geometry_builds==builds,"Selection does not rebuild geometry")
	workspace.create_part("Box")
	for title in ["Top","Front","Back","Left","Right","Bottom","Isometric"]:
		workspace.cad.set_view(title,false)
		check(workspace.camera.projection==Camera3D.PROJECTION_ORTHOGONAL,title+" orthographic")
		var direction: Vector3=-workspace.camera.global_transform.basis.z
		var expected: Vector3={"Top":Vector3.DOWN,"Front":Vector3.FORWARD,"Back":Vector3.BACK,"Left":Vector3.RIGHT,"Right":Vector3.LEFT,"Bottom":Vector3.UP,"Isometric":Vector3(-1,-1,-1).normalized()}[title]
		check(direction.dot(expected)>.999,title+" camera direction")
	workspace.cad.set_view("Top",true)
	await workspace.cad.transition.finished
	check((-workspace.camera.global_transform.basis.z).dot(Vector3.DOWN)>.999,"Animated standard-view transition completes")
	var model_transform: Transform3D=workspace.meshes[1].transform
	workspace.cad.set_view("Perspective",false)
	check(workspace.meshes[1].transform==model_transform,"Changing view does not rotate model")
	var event:=InputEventMouseMotion.new()
	event.button_mask=MOUSE_BUTTON_MASK_RIGHT
	event.relative=Vector2(10,10)
	workspace.cad.navigate(event)
	check(workspace.cad.orbit!=Vector2(.65,.45),"Manual orbit after standard views")
	workspace.create_part("Pipe")
	workspace.run_command("SetParameters",{"parameters":{"outer_diameter":.1,"inner_diameter":.08}})
	check(workspace.meshes[2].mesh.get_faces().size()==48*8*3,"Hollow pipe has outer/inner walls and end rings")
	check(workspace.document.execute("SetParameters",{"index":2,"parameters":{"inner_diameter":.2}})!="","Invalid pipe wall rejected")
	check(workspace.document.save_project("res://.tools/cae-recovery.ucae")==OK,"Save engineering document")
	var loaded=load("res://core/cae/cae_document.gd").new()
	check(loaded.open_project("res://.tools/cae-recovery.ucae")=="","Load engineering document")
	check(JSON.stringify(loaded.data.parts,"",true,true)==JSON.stringify(workspace.document.data.parts,"",true,true),"All primitive parameters roundtrip")
	workspace.file_dialog(true)
	var escape:=InputEventKey.new()
	escape.keycode=KEY_ESCAPE
	escape.pressed=true
	controller._input(escape)
	check(controller.current==1 and not workspace.dialog.visible,"Escape closes modal first")
	controller._input(escape)
	check(controller.current==0 and sandbox.visible,"Escape returns to sandbox")
	check(sandbox.process_mode==Node.PROCESS_MODE_INHERIT,"Original processing restored")
	check(prompt.has_focus(),"Original UI focus restored")
	check(workspace.mouse_filter==Control.MOUSE_FILTER_IGNORE and not workspace.visible,"Hidden overlay cannot intercept input")
	check(workspace.cad.viewport.render_target_update_mode==SubViewport.UPDATE_DISABLED,"Hidden viewport rendering disabled")
	var nodes_before:=int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
	for i in 30:
		controller.set_mode(1)
		controller.set_mode(0)
	controller.set_mode(1)
	check(workspace.document.data.parts.size()==3,"Repeated mode switches preserve session")
	await process_frame
	check(int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))<=nodes_before+2,"Mode switching does not grow scene-tree nodes")
	check(not workspace.is_processing(),"No idle workspace process callback")
	check(workspace.camera.environment==null,"Viewport uses its own dark world environment")
	# Real triangle picking must not select through the pipe bore.
	workspace.select_body(2)
	workspace.run_command("SetPosition",{"values":[0,0,1]})
	workspace.cad.fit(2)
	workspace.cad.set_view("Front",false)
	await process_frame
	var screen: Vector2=workspace.camera.unproject_position(workspace.meshes[2].position)
	workspace.cad.pick(screen)
	check(workspace.selected==2,"Viewport picking updates tree/inspector selection")
	check(workspace.tree.get_selected().get_metadata(0)==2,"Picking synchronizes tree")
	workspace.cad.set_view("Top",false)
	workspace.cad.pick(workspace.camera.unproject_position(workspace.meshes[2].position))
	check(workspace.selected==-1,"Triangle picking passes through an empty pipe bore")
	print("CAE recovery acceptance checks: ",failures," failures; retained geometry builds: ",workspace.cad.geometry_builds)
	controller.set_mode(0)
	workspace.queue_free()
	controller.queue_free()
	sandbox.queue_free()
	await process_frame
	quit(1 if failures else 0)





