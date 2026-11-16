extends SceneTree
func _initialize():
	create_timer(30).timeout.connect(func(): print("Graphical test timeout");quit(2))
	var workspace=load("res://ui/cae/cae_workspace.gd").new()
	root.add_child.call_deferred(workspace)
	await process_frame
	workspace.set_active(true)
	workspace.create_part("Box")
	workspace.document.generate_mesh(5)
	workspace.fit_model()
	var pick_checks := 0
	for mode in ["combined","nodes","quality","elements","wireframe","solid","invalid"]:
		print("Capture mode: ",mode)
		workspace.set_inspection_mode(mode)
		if mode=="elements":
			workspace.section_fraction=0.5
			workspace.mesh_inspection.section(0.5)
			workspace.overlay_key=[]
			workspace.render_model()
			workspace.highlight_mesh_entity({"element":30})
		for i in 4: await process_frame
		if mode in ["nodes","elements"]:
			var found := false
			for record in workspace.mesh_inspection.records:
				var center := Vector3.ZERO
				for id in record.ids: center+=workspace.mesh_inspection.point(id)
				center/=record.ids.size()
				var screen: Vector2=workspace.camera.unproject_position(workspace.mesh_inspection.point(record.ids[0]) if mode=="nodes" else center)
				var hit: Dictionary=workspace.mesh_inspection.pick(workspace.camera,screen,mode=="nodes")
				if hit.is_empty(): continue
				workspace.inspect_mesh_click(screen)
				assert(is_instance_valid(workspace.selection_highlight))
				found=true; pick_checks+=1; break
			assert(found)
			workspace.toggle_projection()
			workspace.cad.set_view("Isometric")
			var camera_hit := false
			for record in workspace.mesh_inspection.records:
				var position: Vector3=workspace.mesh_inspection.point(record.ids[0])
				var projected: Vector2=workspace.camera.unproject_position(position)
				var changed_hit: Dictionary=workspace.mesh_inspection.pick(workspace.camera,projected,mode=="nodes")
				if not changed_hit.is_empty(): camera_hit=true; break
			assert(camera_hit)
			workspace.cad.invalidate()
			for i in 4: await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://.tools/mesh-"+mode+".png")
	workspace.document.generate_mesh(2)
	assert(not is_instance_valid(workspace.selection_highlight))
	workspace.section_fraction=1.0
	workspace.document.data.mesh={"nodes":[[0,0,0],[1,0,0],[0,1,0],[0,0,1]],"elements":[[0,1,2,3]],"regions":{}}
	workspace.inspection_mesh_key=""
	workspace.set_inspection_mode("quality")
	workspace.cad.target=Vector3(0.25,0.25,0.25)
	workspace.cad.distance=2.5
	workspace.cad.set_view("Isometric",false)
	for i in 4: await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://.tools/mesh-tet4.png")
	print("Graphical mesh modes, node/element picking and highlighting checks: ",pick_checks)
	workspace.queue_free()
	await process_frame
	quit()
