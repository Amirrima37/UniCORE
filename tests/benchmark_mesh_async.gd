extends SceneTree
func _initialize():
	var camera:=Camera3D.new(); root.add_child(camera)
	camera.position=Vector3(2,2,3); camera.look_at(Vector3.ZERO)
	var results:=[]
	for dims in [Vector3i(16,16,16),Vector3i(20,20,25),Vector3i(50,50,20),Vector3i(50,50,40)]:
		var start:=Time.get_ticks_usec()
		var nodes:=[]; var elements:=[]
		for z in dims.z+1:
			for y in dims.y+1:
				for x in dims.x+1: nodes.append([float(x)/dims.x-.5,float(y)/dims.y-.5,float(z)/dims.z-.5])
		var nx: int=dims.x+1; var plane: int=nx*(dims.y+1)
		for z in dims.z:
			for y in dims.y:
				for x in dims.x:
					var a: int=x+nx*y+plane*z
					elements.append([a,a+1,a+nx+1,a+nx,a+plane,a+plane+1,a+plane+nx+1,a+plane+nx])
		var generation:=(Time.get_ticks_usec()-start)/1000.0
		var job=load("res://core/cae/mesh_prepare_job.gd").new()
		start=Time.get_ticks_usec(); job.start({"nodes":nodes,"elements":elements},1,1.0,true)
		var snapshot_ms:=(Time.get_ticks_usec()-start)/1000.0
		var frames:=0; var gap:=0.0; var last:=Time.get_ticks_usec()
		while job.copying or job.thread.is_alive():
			job.pump_snapshot()
			await process_frame
			var now:=Time.get_ticks_usec(); gap=maxf(gap,(now-last)/1000.0);last=now;frames+=1
		var prepared=job.thread.wait_to_finish()
		var preparation:=(Time.get_ticks_usec()-start)/1000.0
		start=Time.get_ticks_usec();prepared.geometry("solid");prepared.geometry("edges");prepared.geometry("nodes");prepared.contour("jacobian")
		var resources:=(Time.get_ticks_usec()-start)/1000.0
		var picks:=[]
		for i in 100:
			start=Time.get_ticks_usec();prepared.pick(camera,camera.unproject_position(Vector3.ZERO)+Vector2(i%10,i/10));picks.append((Time.get_ticks_usec()-start)/1000.0)
		picks.sort()
		var item={"nodes":nodes.size(),"elements":elements.size(),"generation_ms":generation,"worker_wall_ms":preparation,"snapshot_ms":snapshot_ms,"resource_ms":resources,"frames_during_preparation":frames,"max_frame_gap_ms":gap,"pick_p95_ms":picks[94],"stages":prepared.timings,"static_memory_bytes":OS.get_static_memory_usage()}
		results.append(item);print(JSON.stringify(item))
		var file:=FileAccess.open("res://docs/cae-upgrade/large-mesh.json",FileAccess.WRITE);file.store_string(JSON.stringify(results,"\t"))
	quit()
