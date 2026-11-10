class_name PresenceManager
extends Node

## UniCORE Real-Time Peer Presence Manager
## Отслеживает позиции, ориентацию и активность всех узлов в сети.
## Работает через канал "presence" сетевого транспорта NetworkTransport.

signal peer_state_updated(peer_id: int, state: Dictionary)
signal peer_activity(peer_id: int, activity: String)
signal peer_left_presence(peer_id: int)

const CHANNEL_NAME: String = "presence"
const DEFAULT_BROADCAST_INTERVAL: float = 0.1

var _transport: NetworkTransport = null
var _local_peer_id: int = 1
var _local_name: String = "UniNode"
var _local_position: Vector3 = Vector3.ZERO
var _local_rotation: Vector3 = Vector3.ZERO
var _local_activity: String = "idle"
var _local_prompt: String = ""
var _local_color: Color = Color(0.0, 0.9, 1.0, 1.0)

var _peers_state: Dictionary = {} # peer_id: int -> Dictionary
var _is_broadcasting: bool = false
var _broadcast_interval: float = DEFAULT_BROADCAST_INTERVAL
var _broadcast_timer: float = 0.0

func _exit_tree() -> void:
	stop_broadcasting_presence()
	_cleanup_transport_connections()

func _process(delta: float) -> void:
	if not _is_broadcasting:
		return
	
	_broadcast_timer += delta
	if _broadcast_timer >= _broadcast_interval:
		_broadcast_timer = 0.0
		_broadcast_current_state()

## Инициализация менеджера присутствия
func setup(transport: NetworkTransport, local_peer_id: int = 1, local_name: String = "UniNode") -> void:
	_cleanup_transport_connections()
	_transport = transport
	_local_peer_id = local_peer_id
	_local_name = local_name
	_local_color = generate_peer_color(local_peer_id)
	
	if _transport != null and is_instance_valid(_transport):
		if not _transport.message_received.is_connected(_on_transport_message_received):
			_transport.message_received.connect(_on_transport_message_received)
		if not _transport.peer_disconnected.is_connected(_on_peer_disconnected):
			_transport.peer_disconnected.connect(_on_peer_disconnected)

## Запуск регулярного вещания состояния (по умолчанию 10 раз в сек)
func start_broadcasting_presence(interval_sec: float = DEFAULT_BROADCAST_INTERVAL) -> void:
	_broadcast_interval = maxf(interval_sec, 0.02)
	_is_broadcasting = true
	_broadcast_timer = 0.0

## Остановка вещания состояния
func stop_broadcasting_presence() -> void:
	_is_broadcasting = false
	_broadcast_timer = 0.0

## Активно ли вещание присутствия
func is_broadcasting() -> bool:
	return _is_broadcasting

## Обновление локального положения и ориентации
func update_local_state(pos: Vector3, rot: Vector3, activity: String = "", last_prompt: String = "") -> void:
	_local_position = pos
	_local_rotation = rot
	if not activity.is_empty():
		_local_activity = activity
	if not last_prompt.is_empty():
		_local_prompt = last_prompt

## Обновление статуса текущей активности узла
func set_local_activity(activity: String, prompt: String = "") -> void:
	_local_activity = activity
	if not prompt.is_empty():
		_local_prompt = prompt

## Получение локального состояния
func get_local_state() -> Dictionary:
	return {
		"peer_id": _local_peer_id,
		"name": _local_name,
		"position": _local_position,
		"rotation": _local_rotation,
		"activity": _local_activity,
		"last_prompt": _local_prompt,
		"color": _local_color
	}

## Получение состояния конкретного пира
func get_peer_state(peer_id: int) -> Dictionary:
	if _peers_state.has(peer_id):
		return _peers_state[peer_id].duplicate(true)
	return {}

## Получение состояний всех известных пиров
func get_all_peer_states() -> Dictionary:
	var result: Dictionary = {}
	for pid in _peers_state:
		result[pid] = _peers_state[pid].duplicate(true)
	return result

## Детерминированная генерация неонового цвета для ID узла
static func generate_peer_color(peer_id: int) -> Color:
	var hue: float = fmod(float(abs(hash(peer_id)) % 360) / 360.0, 1.0)
	return Color.from_hsv(hue, 0.75, 0.95, 1.0)

## Обработка входящего пакета по каналу presence
func handle_message(peer_id: int, channel: String, data: Dictionary) -> void:
	if channel != CHANNEL_NAME:
		return
	
	var msg_type: String = String(data.get("type", ""))
	if msg_type != "presence_update":
		return
	
	var raw_state: Dictionary = data.get("state", {})
	if raw_state.is_empty():
		return
	
	var old_state: Dictionary = _peers_state.get(peer_id, {})
	var old_activity: String = String(old_state.get("activity", ""))
	
	var raw_pos = raw_state.get("position", Vector3.ZERO)
	var pos: Vector3 = Vector3.ZERO
	if raw_pos is Vector3:
		pos = raw_pos
	elif raw_pos is Array and raw_pos.size() >= 3:
		pos = Vector3(float(raw_pos[0]), float(raw_pos[1]), float(raw_pos[2]))
		
	var raw_rot = raw_state.get("rotation", Vector3.ZERO)
	var rot: Vector3 = Vector3.ZERO
	if raw_rot is Vector3:
		rot = raw_rot
	elif raw_rot is Array and raw_rot.size() >= 3:
		rot = Vector3(float(raw_rot[0]), float(raw_rot[1]), float(raw_rot[2]))
		
	var color_val = raw_state.get("color", null)
	var p_color: Color
	if color_val is Color:
		p_color = color_val
	else:
		p_color = generate_peer_color(peer_id)
		
	var p_activity: String = String(raw_state.get("activity", "idle"))
	var p_name: String = String(raw_state.get("name", "Peer_%d" % peer_id))
	var p_prompt: String = String(raw_state.get("last_prompt", ""))
	
	var new_state: Dictionary = {
		"peer_id": peer_id,
		"name": p_name,
		"position": pos,
		"rotation": rot,
		"activity": p_activity,
		"last_prompt": p_prompt,
		"color": p_color
	}
	
	_peers_state[peer_id] = new_state
	peer_state_updated.emit(peer_id, new_state)
	
	if p_activity != old_activity:
		peer_activity.emit(peer_id, p_activity)

## Удаление отключившегося пира
func _on_peer_disconnected(peer_id: int) -> void:
	if _peers_state.has(peer_id):
		_peers_state.erase(peer_id)
		peer_left_presence.emit(peer_id)

func _on_transport_message_received(sender_peer_id: int, channel: String, data: Dictionary) -> void:
	handle_message(sender_peer_id, channel, data)

func _broadcast_current_state() -> void:
	if _transport == null or not is_instance_valid(_transport):
		return
	
	var packet: Dictionary = {
		"type": "presence_update",
		"state": get_local_state()
	}
	_transport.broadcast(CHANNEL_NAME, packet)

func _cleanup_transport_connections() -> void:
	if _transport != null and is_instance_valid(_transport):
		if _transport.has_signal("message_received") and _transport.message_received.is_connected(_on_transport_message_received):
			_transport.message_received.disconnect(_on_transport_message_received)
		if _transport.has_signal("peer_disconnected") and _transport.peer_disconnected.is_connected(_on_peer_disconnected):
			_transport.peer_disconnected.disconnect(_on_peer_disconnected)
