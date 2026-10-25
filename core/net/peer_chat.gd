class_name PeerChat
extends Node

## UniCORE P2P Peer Chat Service
## Обеспечивает обмен широковещательными и личными сообщениями между узлами через канал "chat".

signal message_received(peer_id: int, peer_name: String, text: String, timestamp: float, is_private: bool)
signal history_cleared()

const CHANNEL_NAME: String = "chat"
const MAX_HISTORY: int = 200

var _transport: NetworkTransport = null
var _local_name: String = "UniNode"
var _history: Array[Dictionary] = []

func _exit_tree() -> void:
	_cleanup_transport()

## Настройка сервиса чата с привязкой к транспорту
func setup(transport: NetworkTransport, local_name: String = "UniNode") -> void:
	_cleanup_transport()
	_transport = transport
	_local_name = local_name
	
	if _transport != null and is_instance_valid(_transport):
		if not _transport.message_received.is_connected(_on_transport_message_received):
			_transport.message_received.connect(_on_transport_message_received)

## Обновление локального отображаемого имени
func set_local_name(new_name: String) -> void:
	if not new_name.strip_edges().is_empty():
		_local_name = new_name.strip_edges()

## Получение локального имени
func get_local_name() -> String:
	return _local_name

## Отправка общего сообщения всем участникам пространства
func send_message(text: String) -> void:
	var clean_text: String = text.strip_edges()
	if clean_text.is_empty():
		return
	
	var ts: float = Time.get_unix_time_from_system()
	var local_id: int = _get_local_peer_id()
	
	if _transport != null and is_instance_valid(_transport):
		var packet: Dictionary = {
			"type": "chat_message",
			"text": clean_text,
			"sender_name": _local_name,
			"timestamp": ts
		}
		_transport.broadcast(CHANNEL_NAME, packet)
	
	_add_message_to_history(local_id, _local_name, clean_text, ts, false)
	message_received.emit(local_id, _local_name, clean_text, ts, false)

## Отправка личного сообщения конкретному пиру
func send_private(peer_id: int, text: String) -> void:
	var clean_text: String = text.strip_edges()
	if clean_text.is_empty() or peer_id <= 0:
		return
	
	var ts: float = Time.get_unix_time_from_system()
	var local_id: int = _get_local_peer_id()
	
	if _transport != null and is_instance_valid(_transport):
		var packet: Dictionary = {
			"type": "chat_private",
			"text": clean_text,
			"sender_name": _local_name,
			"recipient_id": peer_id,
			"timestamp": ts
		}
		_transport.send_to_peer(peer_id, CHANNEL_NAME, packet)
	
	_add_message_to_history(local_id, _local_name, clean_text, ts, true)
	message_received.emit(local_id, _local_name, clean_text, ts, true)

## Получение среза истории сообщений
func get_history(count: int = 50) -> Array[Dictionary]:
	if count <= 0 or _history.is_empty():
		return []
	if count >= _history.size():
		return _history.duplicate(true)
	return _history.slice(_history.size() - count, _history.size())

## Очистка локальной истории сообщений
func clear_history() -> void:
	_history.clear()
	history_cleared.emit()

## Обработка входящего пакета из сети
func handle_message(peer_id: int, channel: String, data: Dictionary) -> void:
	if channel != CHANNEL_NAME:
		return
	
	var msg_type: String = String(data.get("type", ""))
	var text: String = String(data.get("text", "")).strip_edges()
	if text.is_empty():
		return
	
	var sender_name: String = String(data.get("sender_name", "Peer_%d" % peer_id))
	var ts: float = float(data.get("timestamp", Time.get_unix_time_from_system()))
	
	match msg_type:
		"chat_message":
			_add_message_to_history(peer_id, sender_name, text, ts, false)
			message_received.emit(peer_id, sender_name, text, ts, false)
		"chat_private":
			_add_message_to_history(peer_id, sender_name, text, ts, true)
			message_received.emit(peer_id, sender_name, text, ts, true)

func _add_message_to_history(peer_id: int, sender_name: String, text: String, timestamp: float, is_private: bool) -> void:
	var msg: Dictionary = {
		"peer_id": peer_id,
		"peer_name": sender_name,
		"text": text,
		"timestamp": timestamp,
		"is_private": is_private
	}
	_history.append(msg)
	if _history.size() > MAX_HISTORY:
		_history.pop_front()

func _get_local_peer_id() -> int:
	if _transport != null and is_instance_valid(_transport) and _transport.has_method("get_local_peer_info"):
		var info: Dictionary = _transport.get_local_peer_info()
		if info.has("id") and int(info["id"]) != 0:
			return int(info["id"])
	return 1

func _on_transport_message_received(sender_peer_id: int, channel: String, data: Dictionary) -> void:
	handle_message(sender_peer_id, channel, data)

func _cleanup_transport() -> void:
	if _transport != null and is_instance_valid(_transport):
		if _transport.has_signal("message_received") and _transport.message_received.is_connected(_on_transport_message_received):
			_transport.message_received.disconnect(_on_transport_message_received)
