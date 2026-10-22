class_name EventBus
extends Node

## Шина событий Ядра (EventBus)
## Обеспечивает независимую (decoupled) коммуникацию между Ядром, Агентом и Модулями.

# Общие системные сигналы
signal event_emitted(event_name: String, payload: Dictionary)
signal module_registered(module_id: String)
signal module_unregistered(module_id: String)
signal agent_state_changed(new_state: String)

var _listeners: Dictionary = {}

func subscribe(event_name: String, callback: Callable) -> void:
	if not _listeners.has(event_name):
		_listeners[event_name] = []
	if not _listeners[event_name].has(callback):
		_listeners[event_name].append(callback)

func unsubscribe(event_name: String, callback: Callable) -> void:
	if _listeners.has(event_name):
		_listeners[event_name].erase(callback)
		if _listeners[event_name].is_empty():
			_listeners.erase(event_name)

func emit(event_name: String, payload: Dictionary = {}) -> void:
	event_emitted.emit(event_name, payload)
	if _listeners.has(event_name):
		var valid_listeners: Array = []
		for callback in _listeners[event_name]:
			if callback.is_valid():
				valid_listeners.append(callback)
				callback.call(payload)
		_listeners[event_name] = valid_listeners

func unsubscribe_all_for_target(target: Object) -> void:
	if not target:
		return
	for event_name in _listeners.keys():
		var valid_listeners: Array = []
		for callback in _listeners[event_name]:
			if callback.is_valid() and callback.get_object() != target:
				valid_listeners.append(callback)
		if valid_listeners.is_empty():
			_listeners.erase(event_name)
		else:
			_listeners[event_name] = valid_listeners

func cleanup_invalid_listeners() -> void:
	for event_name in _listeners.keys():
		var valid_listeners: Array = []
		for callback in _listeners[event_name]:
			if callback.is_valid():
				valid_listeners.append(callback)
		if valid_listeners.is_empty():
			_listeners.erase(event_name)
		else:
			_listeners[event_name] = valid_listeners

func get_listener_count(event_name: String = "") -> int:
	if not event_name.is_empty():
		return _listeners.get(event_name, []).size()
	var total := 0
	for list in _listeners.values():
		total += list.size()
	return total
