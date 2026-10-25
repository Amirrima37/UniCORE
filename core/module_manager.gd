class_name ModuleManager
extends Node

## Менеджер Модулей Ядра
## Отвечает за компиляцию в рантайме, инъекцию, выгрузку модулей,
## а также за перехват спавна динамических объектов и сетевую репликацию через SpaceSync.

signal module_loaded(module_id: String, instance: Node)
signal module_unloaded(module_id: String)
signal compile_failed(module_id: String, errors: Array)
signal network_spawn_requested(scene_path_or_id: String, transform: Transform3D, custom_data: Dictionary)
signal entity_spawned_from_network(network_id: int, instance: Node)

var _active_modules: Dictionary = {} # module_id -> Node
var _event_bus: EventBus = null
var _world_root: Node3D = null
var _space_sync: Node = null

# Реестр фабрик пользовательских прототипов: prototype_name -> Callable
var _prototype_factories: Dictionary = {}
var _spawn_counter: int = 0
var _is_handling_network_spawn: bool = false

func _exit_tree() -> void:
	if _event_bus != null:
		_event_bus.unsubscribe_all_for_target(self)
		if _event_bus.has_signal("network_spawn_requested"):
			var callable := Callable(self, "_on_event_bus_spawn_requested_signal")
			if _event_bus.is_connected("network_spawn_requested", callable):
				_event_bus.disconnect("network_spawn_requested", callable)

	if _space_sync != null and is_instance_valid(_space_sync):
		if _space_sync.has_signal("entity_spawned_from_network"):
			var callable := Callable(self, "_on_space_sync_entity_spawned")
			if _space_sync.is_connected("entity_spawned_from_network", callable):
				_space_sync.disconnect("entity_spawned_from_network", callable)

## Инициализация Менеджера Модулей
func setup(event_bus: EventBus, world_root: Node3D, space_sync: Node = null) -> void:
	if _event_bus != null:
		_event_bus.unsubscribe_all_for_target(self)
		if _event_bus.has_signal("network_spawn_requested"):
			var old_callable := Callable(self, "_on_event_bus_spawn_requested_signal")
			if _event_bus.is_connected("network_spawn_requested", old_callable):
				_event_bus.disconnect("network_spawn_requested", old_callable)

	_event_bus = event_bus
	_world_root = world_root

	if space_sync != null:
		set_space_sync(space_sync)

	_subscribe_to_event_bus()

func set_space_sync(space_sync: Node) -> void:
	if _space_sync != null and is_instance_valid(_space_sync):
		if _space_sync.has_signal("entity_spawned_from_network"):
			var callable := Callable(self, "_on_space_sync_entity_spawned")
			if _space_sync.is_connected("entity_spawned_from_network", callable):
				_space_sync.disconnect("entity_spawned_from_network", callable)

	_space_sync = space_sync

	if _space_sync != null and is_instance_valid(_space_sync):
		if _space_sync.has_method("set_module_manager"):
			if _space_sync.call("get_module_manager") != self:
				_space_sync.call("set_module_manager", self)

		if _space_sync.has_signal("entity_spawned_from_network"):
			var callable := Callable(self, "_on_space_sync_entity_spawned")
			if not _space_sync.is_connected("entity_spawned_from_network", callable):
				_space_sync.connect("entity_spawned_from_network", callable)

func get_space_sync() -> Node:
	return _space_sync

func set_world_root(world_root: Node3D) -> void:
	_world_root = world_root

func get_world_root() -> Node3D:
	return _world_root

# --- Регистрация прототипов динамических сущностей ---

func register_prototype(prototype_name: String, factory: Callable) -> void:
	_prototype_factories[prototype_name] = factory

func unregister_prototype(prototype_name: String) -> void:
	_prototype_factories.erase(prototype_name)

# --- Спавн динамических сущностей и сетевая репликация ---

## Спавн локального инстанса сущности по прототипу
func spawn_prototype_instance(prototype: String, transform: Transform3D = Transform3D.IDENTITY, custom_data: Dictionary = {}, network_id: int = 0) -> Node:
	var instance: Node = null

	# 1. Проверка фабрики пользовательских прототипов
	if _prototype_factories.has(prototype):
		var factory: Callable = _prototype_factories[prototype]
		if factory.is_valid():
			instance = factory.call(transform, custom_data)

	# 2. Проверка пути к упакованной сцене (.tscn)
	if instance == null and prototype.ends_with(".tscn") and ResourceLoader.exists(prototype):
		var scene_res := load(prototype) as PackedScene
		if scene_res != null:
			instance = scene_res.instantiate()

	# 3. Проверка пути к GDScript (.gd)
	if instance == null and prototype.ends_with(".gd") and ResourceLoader.exists(prototype):
		var script_res := load(prototype) as Script
		if script_res != null:
			instance = script_res.new()

	# 4. Встроенные прототипы геометрических фигур
	if instance == null:
		var mesh_instance := MeshInstance3D.new()
		var material := StandardMaterial3D.new()
		var color: Color = custom_data.get("color", Color(0.1, 0.6, 1.0, 1.0))

		if prototype == "sphere" or prototype == "ball":
			var sphere := SphereMesh.new()
			sphere.radius = float(custom_data.get("radius", 0.5))
			sphere.height = float(custom_data.get("height", 1.0))
			mesh_instance.mesh = sphere
			material.albedo_color = custom_data.get("color", Color(0.2, 0.8, 1.0, 1.0))
		elif prototype == "cylinder":
			var cyl := CylinderMesh.new()
			cyl.top_radius = float(custom_data.get("top_radius", 0.5))
			cyl.bottom_radius = float(custom_data.get("bottom_radius", 0.5))
			cyl.height = float(custom_data.get("height", 1.5))
			mesh_instance.mesh = cyl
			material.albedo_color = color
		elif prototype == "red_cube":
			var box := BoxMesh.new()
			box.size = Vector3(1.2, 1.2, 1.2)
			mesh_instance.mesh = box
			material.albedo_color = Color(1.0, 0.15, 0.15, 1.0)
			material.roughness = 0.3
			material.metallic = 0.1
		else: # "cube", "box", default
			var box := BoxMesh.new()
			box.size = custom_data.get("size", Vector3(1.0, 1.0, 1.0))
			mesh_instance.mesh = box
			material.albedo_color = color

		mesh_instance.material_override = material
		instance = mesh_instance

	if instance == null:
		push_error("ModuleManager: Failed to instantiate prototype '%s'" % prototype)
		return null

	if instance is Node3D:
		instance.transform = transform

	if network_id != 0:
		instance.set_meta("network_id", network_id)
		instance.name = "NetEntity_%d" % network_id

	if _world_root != null and is_instance_valid(_world_root) and not instance.is_inside_tree():
		_world_root.add_child(instance)

	return instance

## Запрос локального спавна сущности с автоматической рассылкой через SpaceSync
func spawn_entity_local_and_broadcast(prototype: String, transform: Transform3D = Transform3D.IDENTITY, custom_data: Dictionary = {}) -> Node:
	var network_id: int = 0
	if _space_sync != null and _space_sync.has_method("generate_network_id"):
		network_id = int(_space_sync.call("generate_network_id"))
	else:
		_spawn_counter += 1
		var seed_str: String = "%d_%d_%d" % [1, Time.get_ticks_usec(), _spawn_counter]
		network_id = abs(int(hash(seed_str)))
		if network_id == 0:
			network_id = 1

	var instance: Node = spawn_prototype_instance(prototype, transform, custom_data, network_id)
	if instance == null:
		return null

	if _space_sync != null and is_instance_valid(_space_sync):
		if _space_sync.has_method("register_network_entity"):
			_space_sync.call("register_network_entity", network_id, instance)
		if _space_sync.has_method("broadcast_spawn_entity"):
			_space_sync.call("broadcast_spawn_entity", network_id, prototype, transform, custom_data)

	network_spawn_requested.emit(prototype, transform, custom_data)
	return instance

## Единая точка вызова спавна динамического сетевого объекта
func request_network_spawn(scene_path_or_id: String, transform: Transform3D = Transform3D.IDENTITY, custom_data: Dictionary = {}) -> Node:
	return spawn_entity_local_and_broadcast(scene_path_or_id, transform, custom_data)

# --- Подписка на EventBus и сетевые события ---

func _subscribe_to_event_bus() -> void:
	if _event_bus == null:
		return

	# Подписка на строковое событие в шине
	_event_bus.subscribe("network_spawn_requested", Callable(self, "_on_event_bus_spawn_requested_dict"))

	# Подписка на типизированный сигнал при его наличии
	if _event_bus.has_signal("network_spawn_requested"):
		var callable := Callable(self, "_on_event_bus_spawn_requested_signal")
		if not _event_bus.is_connected("network_spawn_requested", callable):
			_event_bus.connect("network_spawn_requested", callable)

func _on_event_bus_spawn_requested_dict(payload: Dictionary) -> void:
	if _is_handling_network_spawn:
		return

	_is_handling_network_spawn = true

	var scene_or_id: String = str(payload.get("scene_path_or_id", payload.get("prototype", "")))
	var xform: Transform3D = payload.get("transform", Transform3D.IDENTITY)
	var custom_data: Dictionary = payload.get("custom_data", payload.get("data", {}))

	# Если в событии уже передан готовый локальный инстанс, регистрируем и реплицируем его
	var existing_node: Node = payload.get("instance", null)
	if existing_node != null and is_instance_valid(existing_node):
		var network_id: int = 0
		if existing_node.has_meta("network_id"):
			network_id = int(existing_node.get_meta("network_id"))
		elif _space_sync != null and _space_sync.has_method("generate_network_id"):
			network_id = int(_space_sync.call("generate_network_id"))
		else:
			_spawn_counter += 1
			network_id = abs(int(hash("%d_%d_%d" % [1, Time.get_ticks_usec(), _spawn_counter])))
			if network_id == 0:
				network_id = 1
			existing_node.set_meta("network_id", network_id)

		if _space_sync != null and is_instance_valid(_space_sync):
			if _space_sync.has_method("register_network_entity"):
				_space_sync.call("register_network_entity", network_id, existing_node)
			if _space_sync.has_method("broadcast_spawn_entity"):
				_space_sync.call("broadcast_spawn_entity", network_id, scene_or_id, xform, custom_data)
	elif not scene_or_id.is_empty():
		spawn_entity_local_and_broadcast(scene_or_id, xform, custom_data)

	_is_handling_network_spawn = false

func _on_event_bus_spawn_requested_signal(scene_path_or_id: String, transform: Transform3D, custom_data: Dictionary) -> void:
	if _is_handling_network_spawn:
		return
	_is_handling_network_spawn = true
	spawn_entity_local_and_broadcast(scene_path_or_id, transform, custom_data)
	_is_handling_network_spawn = false

func _on_space_sync_entity_spawned(network_id: int, instance: Node) -> void:
	entity_spawned_from_network.emit(network_id, instance)
	if _event_bus != null:
		_event_bus.emit("entity_spawned_from_network", {
			"network_id": network_id,
			"instance": instance
		})

# --- Жизненный цикл модулей ядра (Mount / Unmount) ---

## Монтирование модуля из скомпилированного скрипта
func load_module_from_script(module_id: String, script: Script) -> Variant:
	if not script:
		return null
	if _active_modules.has(module_id):
		unload_module(module_id)

	var instance: Node = script.new()
	if not instance:
		push_error("Failed to instantiate module: %s" % module_id)
		return null

	instance.name = module_id
	if _world_root != null and is_instance_valid(_world_root):
		_world_root.add_child(instance)
	_active_modules[module_id] = instance

	# Инициализация модуля с контекстом Ядра
	if instance.has_method("initialize"):
		var context: Dictionary = {
			"event_bus": _event_bus,
			"world_root": _world_root,
			"module_manager": self,
			"space_sync": _space_sync
		}
		instance.call("initialize", context)

	module_loaded.emit(module_id, instance)
	if _event_bus != null:
		_event_bus.emit("module_loaded", {"id": module_id})
	return instance

## Монтирование модуля из исходного кода GDScript прямо на лету (Runtime Injection)
func load_module_from_source(module_id: String, source_code: String) -> Variant:
	var script := GDScript.new()
	script.source_code = source_code
	var err: Error = script.reload()
	if err != OK:
		var error_msg: String = "Failed to compile module '%s', error code: %d" % [module_id, err]
		push_error(error_msg)
		compile_failed.emit(module_id, [error_msg])
		return null
	return load_module_from_script(module_id, script)

func unload_module(module_id: String) -> bool:
	if not _active_modules.has(module_id):
		return false

	var instance: Node = _active_modules[module_id]
	if is_instance_valid(instance):
		if _event_bus != null and _event_bus.has_method("unsubscribe_all_for_target"):
			_event_bus.unsubscribe_all_for_target(instance)
		if instance.has_method("cleanup"):
			instance.cleanup()
		if is_instance_valid(instance):
			instance.free()

	_active_modules.erase(module_id)
	module_unloaded.emit(module_id)
	if _event_bus != null:
		_event_bus.emit("module_unloaded", {"id": module_id})
	return true

func unload_all_modules() -> void:
	var current_mod_ids: Array = _active_modules.keys().duplicate()
	for mod_id in current_mod_ids:
		unload_module(mod_id)

func get_module(module_id: String) -> Node:
	return _active_modules.get(module_id, null)

func get_active_module_ids() -> Array:
	return _active_modules.keys()

func get_active_modules() -> Array:
	var list: Array = []
	for node in _active_modules.values():
		if is_instance_valid(node):
			list.append(node)
	return list

func register_module_instance(module_id: String, instance: Node) -> void:
	if not instance:
		return
	if _active_modules.has(module_id):
		unload_module(module_id)
	instance.name = module_id
	if _world_root != null and not instance.is_inside_tree():
		_world_root.add_child(instance)
	_active_modules[module_id] = instance
	module_loaded.emit(module_id, instance)
	if _event_bus != null:
		_event_bus.emit("module_loaded", {"id": module_id})
