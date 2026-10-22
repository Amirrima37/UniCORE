class_name ModuleManager
extends Node

## Менеджер Модулей Ядра
## Отвечает за компиляцию в рантайме, инъекцию и выгрузку модулей.

signal module_loaded(module_id: String, instance: Node)
signal module_unloaded(module_id: String)
signal compile_failed(module_id: String, errors: Array)

var _active_modules: Dictionary = {} # module_id -> Node
var _event_bus: EventBus
var _world_root: Node3D

func setup(event_bus: EventBus, world_root: Node3D) -> void:
	_event_bus = event_bus
	_world_root = world_root

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
	_world_root.add_child(instance)
	_active_modules[module_id] = instance

	# Инициализация модуля с контекстом Ядра
	if instance.has_method("initialize"):
		var context := {
			"event_bus": _event_bus,
			"world_root": _world_root,
			"module_manager": self
		}
		instance.initialize(context)

	module_loaded.emit(module_id, instance)
	if _event_bus:
		_event_bus.emit("module_loaded", {"id": module_id})
	return instance

## Монтирование модуля из исходного кода GDScript прямо на лету (Runtime Injection)
func load_module_from_source(module_id: String, source_code: String) -> Variant:
	var script := GDScript.new()
	script.source_code = source_code
	var err := script.reload()
	if err != OK:
		var error_msg := "Failed to compile module '%s', error code: %d" % [module_id, err]
		push_error(error_msg)
		compile_failed.emit(module_id, [error_msg])
		return null
	return load_module_from_script(module_id, script)

func unload_module(module_id: String) -> bool:
	if not _active_modules.has(module_id):
		return false

	var instance: Node = _active_modules[module_id]
	if is_instance_valid(instance):
		if _event_bus and _event_bus.has_method("unsubscribe_all_for_target"):
			_event_bus.unsubscribe_all_for_target(instance)
		if instance.has_method("cleanup"):
			instance.cleanup()
		if is_instance_valid(instance):
			instance.free()

	_active_modules.erase(module_id)
	module_unloaded.emit(module_id)
	if _event_bus:
		_event_bus.emit("module_unloaded", {"id": module_id})
	return true

func unload_all_modules() -> void:
	var current_mod_ids := _active_modules.keys().duplicate()
	for mod_id in current_mod_ids:
		unload_module(mod_id)

func get_module(module_id: String) -> Node:
	return _active_modules.get(module_id, null)

func get_active_module_ids() -> Array:
	return _active_modules.keys()
