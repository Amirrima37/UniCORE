extends SceneTree
var failures:=0
func check(ok: bool,message: String):
	if not ok:
		failures+=1
		push_error(message)
func _initialize():
	create_timer(20).timeout.connect(func(): quit(2))
	var workspace=load("res://ui/cae/cae_workspace.gd").new()
	root.add_child.call_deferred(workspace)
	await process_frame
	workspace.set_active(true)
	var brain=load("res://agent/agent_brain.gd").new()
	root.add_child(brain)
	var provider=load("res://tests/cae_mock_provider.gd").new()
	brain.add_child(provider)
	brain.setup(null,null,provider)
	brain.api_key="test"
	brain.engineering_context=workspace.engineering_context
	brain.engineering_executor=workspace.apply_engineering_response
	var messages: Array=[]
	brain.engineering_finished.connect(func(message): messages.append(message))
	provider.next_response='{"commands":[{"command":"CreatePart","args":{"kind":"Cylinder","parameters":{"diameter":0.1,"length":0.5}}}]}'
	brain.process_user_prompt("Create a steel cylinder with diameter 100 mm and length 500 mm")
	await process_frame
	check(workspace.document.data.parts.size()==1,"Existing AgentBrain dispatches validated CreatePart")
	check(abs(workspace.document.data.parts[0].dimensions[0]-.1)<1e-10,"AI dimensions in SI")
	check(workspace.selected==0,"AI selects created body")
	provider.next_response='{"commands":[{"command":"SetParameters","args":{"parameters":{"diameter":0.2}}}]}'
	brain.process_user_prompt("Change selected diameter to 200 mm")
	await process_frame
	check(abs(workspace.meshes[0].mesh.top_radius-.1)<1e-8,"AI modifies actual geometry via same document command")
	workspace.document.undo()
	check(abs(workspace.document.data.parts[0].dimensions[0]-.1)<1e-10,"AI operation undo")
	var original: Dictionary=workspace.document.data.duplicate(true)
	var error: String=workspace.apply_engineering_response({"commands":[{"command":"CreatePart","args":{"kind":"Box"}},{"command":"SetParameters","args":{"parameters":{"width":-1}}}]},workspace.engineering_context().signature)
	check(not error.is_empty() and workspace.document.data==original,"Invalid command batch is atomic")
	provider.next_response=""
	brain.process_engineering_prompt("Change selected diameter")
	workspace.run_command("Rename",{"name":"Changed while waiting"})
	provider.response_received.emit('{"commands":[{"command":"Delete"}]}')
	check(workspace.document.data.parts.size()==1 and "changed" in str(messages.back()).to_lower(),"Stale AI response rejected")
	provider.next_response='{"question":"What length should the part have?"}'
	brain.process_engineering_prompt("Create a cylinder")
	await process_frame
	check("length" in str(messages.back()),"Missing inputs presented as questions")
	workspace.set_active(false)
	# Sandbox requests must still follow the existing GDScript/module path.
	provider.next_response=""
	brain.process_user_prompt("create a glowing sphere module")
	check("GDScript" in provider.last_system and not "CAD command mode" in provider.last_system,"Original module-generation prompt preserved in AI Sandbox")
	print("CAE existing-agent integration: ",failures," failures (mock provider transport, real command execution)")
	workspace.queue_free()
	brain.queue_free()
	await process_frame
	quit(1 if failures else 0)

