class_name UniCoreModule
extends Node

## Базовый класс для всех Модулей в UniCORE
## Любой модуль, созданный человеком или Агентом, наследуется от этого класса.

signal module_ready(module_id: String)
signal module_error(module_id: String, error_message: String)

var core_context: Dictionary = {}
var is_initialized: bool = false

func get_module_id() -> String:
	return "base_module"

func get_module_name() -> String:
	return "Base Module"

## Возвращает список действий управления для автоматической регистрации в InputMapper.
## Формат элементов массива:
## { "action": "action_name", "label": "Имя действия", "default_key": KEY_W, "description": "Описание" }
func get_action_bindings() -> Array[Dictionary]:
	return []

func initialize(context: Dictionary) -> bool:
	core_context = context
	is_initialized = true
	module_ready.emit(get_module_id())
	return true

func cleanup() -> void:
	is_initialized = false
	queue_free()
