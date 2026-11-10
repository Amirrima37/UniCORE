class_name SpaceSync
extends Node

## Синхронизация состояния Пространств UniCORE (SpaceSync) поверх NetworkTransport.
## Передает снимки пространств (Space Snapshots), диффы изменений состояния модулей,
## а также обеспечивает распределенную репликацию спавна динамических объектов (Multiplayer Object Sync).

signal snapshot_received(peer_id: int, snapshot: Dictionary)
signal sync_completed(peer_id: int)
signal state_change_received(peer_id: int, change: Dictionary)
signal entity_spawned_from_network(network_id: int, instance: Node)
signal entity_despawned_from_network(network_id: int)

const CHANNEL_NAME: String = "space_sync"

var _transport: NetworkTransport = null
var _space_manager: Node = null
var _module_manager: Node = null

# Распределенный реестр сетевых сущностей: network_id (int) -> Node
var _network_entities: Dictionary = {}
var _spawn_counter: int = 0

func _exit_tree() -> void:
	if _transport != null and is_instance_valid(_transport) and _transport.has_signal("message_received"):
		if _transport.message_received.is_connected(_on_transport_message_received):
			_transport.message_received.disconnect(_on_transport_message_received)
	_network_entities.clear()

## Инициализация компонента SpaceSync
func setup(transport: NetworkTransport, space_manager: Node = null, module_manager: Node = null) -> void:
	if _transport != null and is_instance_valid(_transport) and _transport.has_signal("message_received"):
		if _transport.message_received.is_connected(_on_transport_message_received):
			_transport.message_received.disconnect(_on_transport_message_received)

	_transport = transport
	_space_manager = space_manager
	if module_manager != null:
		set_module_manager(module_manager)

	if _transport != null and is_instance_valid(_transport) and _transport.has_signal("message_received"):
		if not _transport.message_received.is_connected(_on_transport_message_received):
			_transport.message_received.connect(_on_transport_message_received)

func set_module_manager(module_manager: Node) -> void:
	_module_manager = module_manager
	if _module_manager != null and _module_manager.has_method("set_space_sync"):
		if _module_manager.call("get_space_sync") != self:
			_module_manager.call("set_space_sync", self)

func get_module_manager() -> Node:
	return _module_manager

func set_space_manager(space_manager: Node) -> void:
	_space_manager = space_manager

func get_space_manager() -> Node:
	return _space_manager

func set_transport(transport: NetworkTransport) -> void:
	if _transport != null and is_instance_valid(_transport) and _transport.has_signal("message_received"):
		if _transport.message_received.is_connected(_on_transport_message_received):
			_transport.message_received.disconnect(_on_transport_message_received)

	_transport = transport
	if _transport != null and is_instance_valid(_transport) and _transport.has_signal("message_received"):
		if not _transport.message_received.is_connected(_on_transport_message_received):
			_transport.message_received.connect(_on_transport_message_received)

func get_transport() -> NetworkTransport:
	return _transport

# --- Распределенный реестр и идентификаторы сетевых сущностей ---

## Генерация уникального идентификатора сущности: hash(peer_id + timestamp + counter)
func generate_network_id(peer_id: int = 0) -> int:
	_spawn_counter += 1
	var actual_peer_id: int = peer_id
	if actual_peer_id <= 0:
		if _transport != null and _transport.has_method("get_local_peer_info"):
			var info: Dictionary = _transport.get_local_peer_info()
			actual_peer_id = int(info.get("id", 1))
		else:
			actual_peer_id = 1

	var seed_str: String = "%d_%d_%d" % [actual_peer_id, Time.get_ticks_usec(), _spawn_counter]
	var net_id: int = abs(int(hash(seed_str)))
	if net_id == 0:
		net_id = 1
	return net_id

## Псевдоним для согласованности с архитектурой
func generate_network_instance_id(peer_id: int = 0) -> int:
	return generate_network_id(peer_id)

## Регистрация сетевой сущности в реестре
func register_network_entity(network_id: int, instance: Node) -> void:
	if network_id == 0 or instance == null or not is_instance_valid(instance):
		return

	_network_entities[network_id] = instance
	instance.set_meta("network_id", network_id)

	var callable := Callable(self, "_on_entity_tree_exited").bind(network_id)
	if not instance.tree_exited.is_connected(callable):
		instance.tree_exited.connect(callable)

## Удаление сущности из реестра
func unregister_network_entity(network_id: int) -> void:
	if _network_entities.has(network_id):
		_network_entities.erase(network_id)

## Получение сетевой сущности по ее network_id
func get_network_entity(network_id: int) -> Node:
	var entity: Node = _network_entities.get(network_id, null)
	if entity != null and is_instance_valid(entity):
		return entity
	return null

## Проверка наличия сущности в реестре
func has_network_entity(network_id: int) -> bool:
	return get_network_entity(network_id) != null

## Получить полный словарь зарегистрированных сущностей
func get_all_network_entities() -> Dictionary:
	var valid_dict: Dictionary = {}
	for k in _network_entities.keys():
		var node: Node = _network_entities[k]
		if node != null and is_instance_valid(node):
			valid_dict[k] = node
	return valid_dict

# --- Сетевая передача (Spawn / Despawn) ---

## Широковещательная рассылка создания сущности остальным узлам
func broadcast_spawn_entity(network_id: int, prototype: String, transform: Transform3D, custom_data: Dictionary = {}) -> void:
	var packet_payload: Dictionary = {
		"action": "spawn_entity",
		"type": "spawn_entity",
		"network_id": network_id,
		"prototype": prototype,
		"transform": transform,
		"data": custom_data
	}

	# Встроенная сериализация байтов Godot
	var raw_bytes: PackedByteArray = var_to_bytes(packet_payload)
	packet_payload["bytes"] = raw_bytes

	if _transport != null:
		_transport.broadcast_message(CHANNEL_NAME, packet_payload)

## Отправка создания сущности конкретному пиру
func send_spawn_entity(peer_id: int, network_id: int, prototype: String, transform: Transform3D, custom_data: Dictionary = {}) -> void:
	var packet_payload: Dictionary = {
		"action": "spawn_entity",
		"type": "spawn_entity",
		"network_id": network_id,
		"prototype": prototype,
		"transform": transform,
		"data": custom_data
	}

	var raw_bytes: PackedByteArray = var_to_bytes(packet_payload)
	packet_payload["bytes"] = raw_bytes

	if _transport != null:
		_transport.send_message(peer_id, CHANNEL_NAME, packet_payload)

## Широковещательная рассылка удаления сущности
func broadcast_despawn_entity(network_id: int) -> void:
	var packet_payload: Dictionary = {
		"action": "despawn_entity",
		"type": "despawn_entity",
		"network_id": network_id
	}

	var raw_bytes: PackedByteArray = var_to_bytes(packet_payload)
	packet_payload["bytes"] = raw_bytes

	if _transport != null:
		_transport.broadcast_message(CHANNEL_NAME, packet_payload)

# --- Снимки пространства и изменение состояний ---

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

# --- Обработка входящих сообщений протокола "space_sync" ---

func handle_message(peer_id: int, channel: String, data: Dictionary) -> void:
	if not channel.is_empty() and channel != CHANNEL_NAME:
		return

	# Десериализация байтов, если передан бинарный пакет
	var payload_dict: Dictionary = data
	if data.has("bytes"):
		var raw_val = data["bytes"]
		if raw_val is PackedByteArray and not raw_val.is_empty():
			var decoded = bytes_to_var(raw_val)
			if decoded is Dictionary:
				payload_dict = decoded
	elif data.has("payload_bytes"):
		var raw_val2 = data["payload_bytes"]
		if raw_val2 is PackedByteArray and not raw_val2.is_empty():
			var decoded2 = bytes_to_var(raw_val2)
			if decoded2 is Dictionary:
				payload_dict = decoded2

	var action: String = str(payload_dict.get("action", payload_dict.get("type", "")))
	match action:
		"spawn_entity":
			var network_id: int = int(payload_dict.get("network_id", 0))
			var prototype: String = str(payload_dict.get("prototype", ""))
			var xform: Transform3D = payload_dict.get("transform", Transform3D.IDENTITY)
			var custom_data: Dictionary = payload_dict.get("data", {})

			if network_id == 0 or prototype.is_empty():
				return

			# Идемпотентность: не дублируем уже существующую сущность
			if has_network_entity(network_id):
				return

			var instance: Node = null
			if _module_manager != null and _module_manager.has_method("spawn_prototype_instance"):
				instance = _module_manager.call("spawn_prototype_instance", prototype, xform, custom_data, network_id)
			else:
				instance = _create_fallback_entity(prototype, xform, custom_data)
				if _space_manager != null and "world_root" in _space_manager and _space_manager.world_root != null:
					_space_manager.world_root.add_child(instance)
				else:
					add_child(instance)

			if instance != null and is_instance_valid(instance):
				register_network_entity(network_id, instance)
				entity_spawned_from_network.emit(network_id, instance)

		"despawn_entity":
			var network_id: int = int(payload_dict.get("network_id", 0))
			if network_id != 0 and has_network_entity(network_id):
				var node: Node = get_network_entity(network_id)
				unregister_network_entity(network_id)
				if node != null and is_instance_valid(node):
					node.queue_free()
				entity_despawned_from_network.emit(network_id)

		"request_snapshot":
			send_space_snapshot(peer_id)

		"snapshot":
			var snapshot: Dictionary = payload_dict.get("snapshot", {})
			if snapshot.is_empty():
				return
			snapshot_received.emit(peer_id, snapshot)
			if _space_manager != null and _space_manager.has_method("apply_space_data"):
				_space_manager.apply_space_data(snapshot)
			sync_completed.emit(peer_id)

		"state_change":
			var change: Dictionary = payload_dict.get("change", {})
			if not change.is_empty():
				state_change_received.emit(peer_id, change)

func _create_fallback_entity(prototype: String, transform: Transform3D, custom_data: Dictionary) -> Node:
	var mesh_inst := MeshInstance3D.new()
	var mat := StandardMaterial3D.new()
	var color: Color = custom_data.get("color", Color(0.1, 0.6, 1.0, 1.0))

	if prototype == "sphere" or prototype == "ball":
		var sphere := SphereMesh.new()
		sphere.radius = 0.5
		sphere.height = 1.0
		mesh_inst.mesh = sphere
		mat.albedo_color = custom_data.get("color", Color(0.2, 0.8, 1.0, 1.0))
	elif prototype == "red_cube":
		var box := BoxMesh.new()
		box.size = Vector3(1.2, 1.2, 1.2)
		mesh_inst.mesh = box
		mat.albedo_color = Color(1.0, 0.15, 0.15, 1.0)
	else:
		var box := BoxMesh.new()
		box.size = custom_data.get("size", Vector3(1.0, 1.0, 1.0))
		mesh_inst.mesh = box
		mat.albedo_color = color

	mesh_inst.material_override = mat
	mesh_inst.transform = transform
	return mesh_inst

func _on_entity_tree_exited(network_id: int) -> void:
	unregister_network_entity(network_id)

func _on_transport_message_received(peer_id: int, channel: String, data: Dictionary) -> void:
	if channel == CHANNEL_NAME:
		handle_message(peer_id, channel, data)
