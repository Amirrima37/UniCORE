class_name ModuleSharing
extends Node

## Протокол безопасного обмена модулями между узлами UniCORE поверх NetworkTransport.
## Включает валидацию размера (<=64KB), криптографическую проверку SHA-256,
## статический анализ безопасности (CodeValidator) и фильтрацию пиров (Whitelist/Blacklist).

signal module_offered(peer_id: int, module_meta: Dictionary) # {id: String, name: String, hash: String, size: int, category: String}
signal module_received(module_id: String, source_code: String, sender_id: int)
signal module_request_received(peer_id: int, module_id: String)
signal sharing_error(peer_id: int, error: String)

const MAX_MODULE_SIZE_BYTES: int = 65536 # 64 KB защита от abuse
const CHANNEL_NAME: String = "module_share"

var _transport: NetworkTransport
var _module_library: ModuleLibrary # может быть null в юнит-тестах при моках
var _code_validator: Object # CodeValidator
var _pending_offers: Array[Dictionary] = [] # [{peer_id: int, module_meta: Dictionary}]
var _whitelist_peers: Array[int] = []
var _blacklist_peers: Array[int] = []

func _exit_tree() -> void:
	if _transport != null and is_instance_valid(_transport) and _transport.has_signal("message_received"):
		if _transport.message_received.is_connected(_on_transport_message_received):
			_transport.message_received.disconnect(_on_transport_message_received)

## Инициализация компонента ModuleSharing
func setup(transport: NetworkTransport, module_library: ModuleLibrary = null, code_validator: Object = null) -> void:
	if _transport != null and is_instance_valid(_transport) and _transport.has_signal("message_received"):
		if _transport.message_received.is_connected(_on_transport_message_received):
			_transport.message_received.disconnect(_on_transport_message_received)

	_transport = transport
	_module_library = module_library
	_code_validator = code_validator

	if _transport != null and is_instance_valid(_transport) and _transport.has_signal("message_received"):
		if not _transport.message_received.is_connected(_on_transport_message_received):
			_transport.message_received.connect(_on_transport_message_received)

## Отправить предложение модуля пиру (извлекает метаданные из module_library)
func offer_module(peer_id: int, module_id: String) -> void:
	if not is_peer_allowed(peer_id):
		sharing_error.emit(peer_id, "Peer %d is blacklisted or not allowed" % peer_id)
		return

	if _module_library == null:
		sharing_error.emit(peer_id, "No ModuleLibrary configured to offer module '%s'" % module_id)
		return

	var code: String = _module_library.get_module_source(module_id)
	if code.is_empty():
		sharing_error.emit(peer_id, "Module '%s' not found in library" % module_id)
		return

	var size_val: int = code.to_utf8_buffer().size()
	if size_val > MAX_MODULE_SIZE_BYTES:
		sharing_error.emit(peer_id, "Cannot offer module '%s': size %d exceeds limit of %d bytes" % [module_id, size_val, MAX_MODULE_SIZE_BYTES])
		return

	var hash_val: String = compute_sha256(code)
	var mod_name: String = module_id
	var category: String = "general"

	var all_mods: Array[Dictionary] = _module_library.get_all_modules()
	for item in all_mods:
		if item.get("id", "") == module_id:
			mod_name = item.get("name", module_id)
			category = item.get("category", "general")
			break

	var meta: Dictionary = {
		"id": module_id,
		"name": mod_name,
		"hash": hash_val,
		"size": size_val,
		"category": category
	}

	if _transport != null:
		_transport.send_message(peer_id, CHANNEL_NAME, {
			"action": "offer",
			"type": "offer",
			"meta": meta,
			"module_meta": meta
		})

## Отправить запрос на скачивание модуля
func request_module(peer_id: int, module_id: String) -> void:
	if not is_peer_allowed(peer_id):
		sharing_error.emit(peer_id, "Peer %d is blacklisted or not allowed" % peer_id)
		return

	if _transport != null:
		_transport.send_message(peer_id, CHANNEL_NAME, {
			"action": "request",
			"type": "request",
			"module_id": module_id
		})

## Объявить свой локальный каталог (список id, name, hash, size, category)
func broadcast_module_list() -> void:
	if _module_library == null:
		return

	var catalog_meta: Array[Dictionary] = []
	var all_mods: Array[Dictionary] = _module_library.get_all_modules()

	for item in all_mods:
		var mod_id: String = item.get("id", "")
		var code: String = _module_library.get_module_source(mod_id)
		var size_val: int = code.to_utf8_buffer().size()
		var hash_val: String = compute_sha256(code)
		catalog_meta.append({
			"id": mod_id,
			"name": item.get("name", mod_id),
			"hash": hash_val,
			"size": size_val,
			"category": item.get("category", "general")
		})

	if _transport != null:
		_transport.broadcast_message(CHANNEL_NAME, {
			"action": "catalog",
			"type": "catalog",
			"modules": catalog_meta
		})

## Принять предложение и запросить код модуля
func accept_module(peer_id: int, module_id: String) -> void:
	# Удаляем из ожидающих предложений
	for i in range(_pending_offers.size() - 1, -1, -1):
		var offer: Dictionary = _pending_offers[i]
		if offer.get("peer_id", 0) == peer_id and offer.get("module_meta", {}).get("id", "") == module_id:
			_pending_offers.remove_at(i)

	request_module(peer_id, module_id)

## Отклонить предложение
func reject_module(peer_id: int, module_id: String, reason: String = "User declined") -> void:
	for i in range(_pending_offers.size() - 1, -1, -1):
		var offer: Dictionary = _pending_offers[i]
		if offer.get("peer_id", 0) == peer_id and offer.get("module_meta", {}).get("id", "") == module_id:
			_pending_offers.remove_at(i)

	if _transport != null and is_peer_allowed(peer_id):
		_transport.send_message(peer_id, CHANNEL_NAME, {
			"action": "reject",
			"type": "reject",
			"module_id": module_id,
			"reason": reason
		})

## Получить список ожидающих предложений модулей
func get_pending_offers() -> Array[Dictionary]:
	return _pending_offers.duplicate(true)

## Управление белым списком пиров
func set_peer_whitelisted(peer_id: int, whitelisted: bool) -> void:
	if whitelisted:
		if not peer_id in _whitelist_peers:
			_whitelist_peers.append(peer_id)
		_blacklist_peers.erase(peer_id)
	else:
		_whitelist_peers.erase(peer_id)

## Управление черным списком пиров
func set_peer_blacklisted(peer_id: int, blacklisted: bool) -> void:
	if blacklisted:
		if not peer_id in _blacklist_peers:
			_blacklist_peers.append(peer_id)
		_whitelist_peers.erase(peer_id)
	else:
		_blacklist_peers.erase(peer_id)

## Проверка разрешения на взаимодействие с пиром
func is_peer_allowed(peer_id: int) -> bool:
	if peer_id in _blacklist_peers:
		return false
	if not _whitelist_peers.is_empty():
		return peer_id in _whitelist_peers
	return true

## Расчет SHA-256 хеша через HashingContext (HASH_SHA256)
static func compute_sha256(source: String) -> String:
	var ctx := HashingContext.new()
	var err := ctx.start(HashingContext.HASH_SHA256)
	if err != OK:
		return ""
	var raw_bytes := source.to_utf8_buffer()
	if raw_bytes.size() > 0:
		err = ctx.update(raw_bytes)
		if err != OK:
			return ""
	var digest: PackedByteArray = ctx.finish()
	return digest.hex_encode().to_lower()

## Обработка входящих сообщений протокола "module_share"
func handle_message(peer_id: int, channel: String, data: Dictionary) -> void:
	if not channel.is_empty() and channel != CHANNEL_NAME:
		return

	# Проверка черного списка и прав доступа
	if not is_peer_allowed(peer_id):
		sharing_error.emit(peer_id, "Peer %d is blacklisted or not allowed" % peer_id)
		return

	var action: String = str(data.get("action", data.get("type", "")))
	match action:
		"offer":
			var meta: Dictionary = data.get("meta", data.get("module_meta", {}))
			if not meta.has("id"):
				meta["id"] = str(data.get("module_id", ""))
			if not meta.has("name"):
				meta["name"] = meta.get("id", "")
			if not meta.has("hash"):
				meta["hash"] = str(data.get("hash", ""))
			if not meta.has("size"):
				meta["size"] = int(data.get("size", 0))
			if not meta.has("category"):
				meta["category"] = "general"

			var offer_mod_id := str(meta.get("id", "")).strip_edges()
			if offer_mod_id.is_empty():
				sharing_error.emit(peer_id, "Received offer with empty module id")
				return

			var offer_size: int = int(meta.get("size", 0))
			if offer_size > MAX_MODULE_SIZE_BYTES:
				sharing_error.emit(peer_id, "Offered module size %d exceeds limit of %d bytes" % [offer_size, MAX_MODULE_SIZE_BYTES])
				return

			# Дедупликация: заменяем предыдущий оффер для этого же пира и модуля
			for i in range(_pending_offers.size() - 1, -1, -1):
				var existing: Dictionary = _pending_offers[i]
				if existing.get("peer_id", 0) == peer_id and existing.get("module_meta", {}).get("id", "") == offer_mod_id:
					_pending_offers.remove_at(i)

			_pending_offers.append({
				"peer_id": peer_id,
				"module_meta": meta
			})
			module_offered.emit(peer_id, meta)

		"request", "accept":
			var req_id: String = str(data.get("module_id", "")).strip_edges()
			if req_id.is_empty():
				sharing_error.emit(peer_id, "Received request with empty module_id")
				return

			module_request_received.emit(peer_id, req_id)
			if _module_library != null:
				var code: String = _module_library.get_module_source(req_id)
				if not code.is_empty():
					var size_val: int = code.to_utf8_buffer().size()
					if size_val > MAX_MODULE_SIZE_BYTES:
						var size_err := "Module '%s' exceeds size limit of %d bytes" % [req_id, MAX_MODULE_SIZE_BYTES]
						sharing_error.emit(peer_id, size_err)
						if _transport != null:
							_transport.send_message(peer_id, CHANNEL_NAME, {
								"action": "error",
								"type": "error",
								"error": size_err
							})
						return

					var hash_val: String = compute_sha256(code)
					if _transport != null:
						_transport.send_message(peer_id, CHANNEL_NAME, {
							"action": "data",
							"type": "data",
							"module_id": req_id,
							"source_code": code,
							"hash": hash_val,
							"size": size_val
						})
				else:
					var not_found_err := "Requested module '%s' not found" % req_id
					sharing_error.emit(peer_id, not_found_err)
					if _transport != null:
						_transport.send_message(peer_id, CHANNEL_NAME, {
							"action": "error",
							"type": "error",
							"error": not_found_err
						})
			else:
				var no_lib_err := "No ModuleLibrary configured to fulfill request for '%s'" % req_id
				sharing_error.emit(peer_id, no_lib_err)
				if _transport != null:
					_transport.send_message(peer_id, CHANNEL_NAME, {
						"action": "error",
						"type": "error",
						"error": no_lib_err
					})

		"reject":
			pass

		"catalog":
			pass

		"error":
			var err_msg: String = str(data.get("error", "Remote sharing error"))
			sharing_error.emit(peer_id, err_msg)

		"data":
			var mod_id: String = str(data.get("module_id", ""))
			var source_code: String = str(data.get("source_code", ""))
			var received_hash: String = str(data.get("hash", ""))
			var size_bytes: int = source_code.to_utf8_buffer().size()

			# 0. Валидация наличия идентификатора и непустого кода
			if mod_id.strip_edges().is_empty():
				sharing_error.emit(peer_id, "Received module data without module_id")
				return
			if source_code.strip_edges().is_empty():
				sharing_error.emit(peer_id, "Module source code is empty")
				return

			# 1. Защита от превышения размера (>64 KB)
			if size_bytes > MAX_MODULE_SIZE_BYTES:
				sharing_error.emit(peer_id, "Module size exceeds limit of %d bytes (got %d bytes)" % [MAX_MODULE_SIZE_BYTES, size_bytes])
				return

			# 2. Проверка целостности SHA-256
			var calculated_hash: String = compute_sha256(source_code)
			if received_hash.is_empty() or calculated_hash.to_lower() != received_hash.to_lower():
				sharing_error.emit(peer_id, "Hash verification failed")
				return

			# 3. Проверка безопасности через CodeValidator (статический метод в Godot 4.0)
			if _code_validator != null:
				var val_res: Dictionary = {}
				if _code_validator.has_method("validate_script_source"):
					val_res = _code_validator.validate_script_source(source_code)
				else:
					val_res = CodeValidator.validate_script_source(source_code)

				if not val_res.get("is_valid", false):
					var err_msg: String = str(val_res.get("error_message", val_res.get("error", "Validation failed")))
					sharing_error.emit(peer_id, "Security/syntax check failed: %s" % err_msg)
					return

			# 4. Успешный прием модуля
			module_received.emit(mod_id, source_code, peer_id)
			if _module_library != null and _module_library.has_method("import_module_from_source"):
				var import_res = _module_library.import_module_from_source(mod_id, source_code)
				if import_res is Dictionary and not import_res.get("success", true):
					sharing_error.emit(peer_id, "Failed to save module: %s" % import_res.get("error", "unknown error"))

func _on_transport_message_received(peer_id: int, channel: String, data: Dictionary) -> void:
	if channel == CHANNEL_NAME:
		handle_message(peer_id, channel, data)
