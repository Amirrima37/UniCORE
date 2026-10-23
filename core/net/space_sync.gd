class_name SpaceSync
extends Node

## Синхронизация состояния Пространств UniCORE (SpaceSync) поверх NetworkTransport.
## Передает снимки пространств (Space Snapshots) и диффы изменений состояния модулей.

signal snapshot_received(peer_id: int, snapshot: Dictionary)
signal sync_completed(peer_id: int)
signal state_change_received(peer_id: int, change: Dictionary)

const CHANNEL_NAME: String = "space_sync"

var _transport: NetworkTransport
var _space_manager: Node

func _exit_tree() -> void:
	if _transport != null and is_instance_valid(_transport) and _transport.has_signal("message_received"):
		if _transport.message_received.is_connected(_on_transport_message_received):
			_transport.message_received.disconnect(_on_transport_message_received)

## Инициализация компонента SpaceSync
func setup(transport: NetworkTransport, space_manager: Node = null) -> void:
	if _transport != null and is_instance_valid(_transport) and _transport.has_signal("message_received"):
		if _transport.message_received.is_connected(_on_transport_message_received):
			_transport.message_received.disconnect(_on_transport_message_received)

	_transport = transport
	_space_manager = space_manager

	if _transport != null and is_instance_valid(_transport) and _transport.has_signal("message_received"):
		if not _transport.message_received.is_connected(_on_transport_message_received):
			_transport.message_received.connect(_on_transport_message_received)

## Отправка снимка пространства пиру (сериализованный через space_manager.serialize() или переданный словарь)
func send_space_snapshot(peer_id: int, custom_snapshot: Dictionary = {}) -> void:
	var snapshot: Dictionary = custom_snapshot
	if snapshot.is_empty() and _space_manager != null:
		if _space_manager.has_method("serialize"):
			snapshot = _space_manager.serialize()
		elif "current_space_data" in _space_manager:
			snapshot = _space_manager.current_space_data

	if snapshot.is_empty():
		return

	if _transport != null:
		_transport.send_message(peer_id, CHANNEL_NAME, {
			"action": "snapshot",
			"type": "snapshot",
			"snapshot": snapshot
		})

## Отправка запроса на получение снимка пространства
func request_space_snapshot(peer_id: int) -> void:
	if _transport != null:
		_transport.send_message(peer_id, CHANNEL_NAME, {
			"action": "request_snapshot",
			"type": "request_snapshot"
		})

## Широковещательная рассылка текущего снимка пространства всем пирам
func broadcast_space_state() -> void:
	var snapshot: Dictionary = {}
	if _space_manager != null:
		if _space_manager.has_method("serialize"):
			snapshot = _space_manager.serialize()
		elif "current_space_data" in _space_manager:
			snapshot = _space_manager.current_space_data

	if snapshot.is_empty():
		return

	if _transport != null:
		_transport.broadcast_message(CHANNEL_NAME, {
			"action": "snapshot",
			"type": "snapshot",
			"snapshot": snapshot
		})

## Широковещательное оповещение об изменении состояния модуля ("module_loaded", "module_unloaded")
func broadcast_module_state_change(change_type: String, module_id: String, details: Dictionary = {}) -> void:
	if change_type.is_empty() or module_id.is_empty():
		return

	var change_dict: Dictionary = {
		"change_type": change_type,
		"module_id": module_id,
		"details": details,
		"timestamp": Time.get_datetime_string_from_system()
	}

	if _transport != null:
		_transport.broadcast_message(CHANNEL_NAME, {
			"action": "state_change",
			"type": "state_change",
			"change": change_dict
		})

## Обработка входящих сообщений протокола синхронизации пространств "space_sync"
func handle_message(peer_id: int, channel: String, data: Dictionary) -> void:
	if not channel.is_empty() and channel != CHANNEL_NAME:
		return

	var action: String = str(data.get("action", data.get("type", "")))
	match action:
		"request_snapshot":
			send_space_snapshot(peer_id)

		"snapshot":
			var snapshot: Dictionary = data.get("snapshot", {})
			if snapshot.is_empty():
				return
			snapshot_received.emit(peer_id, snapshot)
			if _space_manager != null and _space_manager.has_method("apply_space_data"):
				_space_manager.apply_space_data(snapshot)
			sync_completed.emit(peer_id)

		"state_change":
			var change: Dictionary = data.get("change", {})
			if not change.is_empty():
				state_change_received.emit(peer_id, change)

func _on_transport_message_received(peer_id: int, channel: String, data: Dictionary) -> void:
	if channel == CHANNEL_NAME:
		handle_message(peer_id, channel, data)
