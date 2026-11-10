extends SceneTree

## Юнит-тесты для протокола ModuleSharing и синхронизации SpaceSync

var passed_count: int = 0
var failed_count: int = 0
var _nodes_to_free: Array[Node] = []

func track_node(node: Node) -> Node:
	_nodes_to_free.append(node)
	return node

func free_tracked_nodes() -> void:
	for node in _nodes_to_free:
		if is_instance_valid(node):
			node.free()
	_nodes_to_free.clear()

func assert_true(condition: bool, test_name: String, error_msg: String = "") -> void:
	if condition:
		print("  [PASS] %s" % test_name)
		passed_count += 1
	else:
		print("  [FAIL] %s - %s" % [test_name, error_msg])
		failed_count += 1

func assert_false(condition: bool, test_name: String, error_msg: String = "") -> void:
	assert_true(not condition, test_name, error_msg)

func assert_eq(a: Variant, b: Variant, test_name: String) -> void:
	if a == b:
		print("  [PASS] %s" % test_name)
		passed_count += 1
	else:
		print("  [FAIL] %s - Expected '%s', got '%s'" % [test_name, str(b), str(a)])
		failed_count += 1

# Mock NetworkTransport для перехвата сообщений в тестах
class MockTransport extends NetworkTransport:
	var sent_messages: Array[Dictionary] = []
	var broadcast_messages: Array[Dictionary] = []

	func send_message(peer_id: int, channel: String, data: Dictionary) -> void:
		sent_messages.append({"peer_id": peer_id, "channel": channel, "data": data})

	func broadcast_message(channel: String, data: Dictionary) -> void:
		broadcast_messages.append({"channel": channel, "data": data})

	func clear_records() -> void:
		sent_messages.clear()
		broadcast_messages.clear()

# Mock ModuleLibrary для тестирования отправки и сохранения модулей
class MockModuleLibrary extends ModuleLibrary:
	var mock_modules: Dictionary = {}
	var imported_modules: Dictionary = {}

	func add_dummy_module(mod_id: String, source_code: String, mod_name: String = "", cat: String = "tools") -> void:
		mock_modules[mod_id] = {
			"id": mod_id,
			"name": mod_name if not mod_name.is_empty() else mod_id,
			"category": cat,
			"source": source_code
		}

	func get_module_source(mod_id: String) -> String:
		if mock_modules.has(mod_id):
			return mock_modules[mod_id].get("source", "")
		return ""

	func get_all_modules() -> Array[Dictionary]:
		var res: Array[Dictionary] = []
		for k in mock_modules:
			res.append({
				"id": mock_modules[k]["id"],
				"name": mock_modules[k]["name"],
				"category": mock_modules[k]["category"]
			})
		return res

	func import_module_from_source(mod_id: String, source_code: String) -> Dictionary:
		imported_modules[mod_id] = source_code
		return {"success": true, "module_id": mod_id}

# Mock SpaceManager для тестирования SpaceSync
class MockSpaceManager extends Node:
	var current_space_data: Dictionary = {
		"id": "mock_space_01",
		"name": "Test Space",
		"camera": {"position": [0, 1, 5]},
		"active_modules": []
	}
	var applied_spaces: Array[Dictionary] = []

	func serialize() -> Dictionary:
		return current_space_data.duplicate(true)

	func apply_space_data(data: Dictionary) -> bool:
		applied_spaces.append(data)
		current_space_data = data.duplicate(true)
		return true

func _init() -> void:
	print("==================================================")
	print("Starting ModuleSharing & SpaceSync Test Suite")
	print("==================================================")

	test_sha256_hashing()
	test_whitelist_blacklist()
	test_size_limit_protection()
	test_hash_integrity_verification()
	test_code_validator_integration()
	test_offer_accept_request_cycle()
	test_offer_rejection()
	test_space_sync()
	test_deleted_module_request_and_error_propagation()
	test_pending_offers_deduplication()
	test_empty_data_and_id_validation()
	test_additional_edge_cases()

	print("==================================================")
	print("Test Results: %d Passed, %d Failed" % [passed_count, failed_count])
	print("==================================================")

	free_tracked_nodes()

	if failed_count > 0:
		quit(1)
	else:
		quit(0)

# ------------------------------------------------------------------------------
# 1. Тестирование расчета SHA-256
# ------------------------------------------------------------------------------
func test_sha256_hashing() -> void:
	print("\n--- Test Group 1: SHA-256 Hashing ---")

	var empty_hash := ModuleSharing.compute_sha256("")
	assert_eq(empty_hash, "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855", "Empty string SHA-256 matches standard digest")

	var hello_hash := ModuleSharing.compute_sha256("hello")
	assert_eq(hello_hash, "2cf24dba5fb0a30e26e83b2ac5b9e29e1b161e5c1fa7425e73043362938b9824", "String 'hello' SHA-256 matches standard digest")

	var code_a := "class_name ModA\nextends Node\n"
	var code_b := "class_name ModB\nextends Node\n"
	var hash_a := ModuleSharing.compute_sha256(code_a)
	var hash_b := ModuleSharing.compute_sha256(code_b)
	assert_false(hash_a == hash_b, "Distinct source codes produce distinct SHA-256 hashes")
	assert_eq(hash_a.length(), 64, "SHA-256 output length is 64 hex characters")

# ------------------------------------------------------------------------------
# 2. Тестирование белого и черного списков пиров
# ------------------------------------------------------------------------------
func test_whitelist_blacklist() -> void:
	print("\n--- Test Group 2: Whitelist & Blacklist Peers ---")

	var sharing: ModuleSharing = track_node(ModuleSharing.new())
	var transport: MockTransport = track_node(MockTransport.new())
	sharing.setup(transport)

	assert_true(sharing.is_peer_allowed(10), "Peer 10 allowed by default with empty lists")
	assert_true(sharing.is_peer_allowed(20), "Peer 20 allowed by default with empty lists")

	sharing.set_peer_blacklisted(10, true)
	assert_false(sharing.is_peer_allowed(10), "Peer 10 rejected after blacklisting")
	assert_true(sharing.is_peer_allowed(20), "Peer 20 still allowed when peer 10 is blacklisted")

	sharing.set_peer_blacklisted(10, false)
	assert_true(sharing.is_peer_allowed(10), "Peer 10 allowed after un-blacklisting")

	sharing.set_peer_whitelisted(30, true)
	assert_true(sharing.is_peer_allowed(30), "Peer 30 allowed when on whitelist")
	assert_false(sharing.is_peer_allowed(40), "Peer 40 rejected when whitelist is active and peer is not listed")

	sharing.set_peer_blacklisted(30, true)
	assert_false(sharing.is_peer_allowed(30), "Peer 30 rejected after blacklisting, even if was whitelisted")

	var err_received := [false]
	var err_msg := [""]
	sharing.sharing_error.connect(func(p_id: int, err: String):
		err_received[0] = true
		err_msg[0] = err
	)

	sharing.handle_message(30, "module_share", {"action": "offer", "meta": {"id": "test"}})
	assert_true(err_received[0], "Incoming packet from blacklisted peer triggers sharing_error")
	assert_true(err_msg[0].contains("blacklisted"), "Error message specifies peer is blacklisted")

# ------------------------------------------------------------------------------
# 3. Тестирование лимита размера (>64 KB)
# ------------------------------------------------------------------------------
func test_size_limit_protection() -> void:
	print("\n--- Test Group 3: Size Limit (>64KB) Protection ---")

	var sharing: ModuleSharing = track_node(ModuleSharing.new())
	var transport: MockTransport = track_node(MockTransport.new())
	sharing.setup(transport)

	var err_emitted := [false]
	var err_text := [""]
	var mod_received := [false]

	sharing.sharing_error.connect(func(peer: int, err: String):
		err_emitted[0] = true
		err_text[0] = err
	)
	sharing.module_received.connect(func(_id: String, _code: String, _peer: int):
		mod_received[0] = true
	)

	var large_body: String = "# oversized comment padding\n"
	while large_body.to_utf8_buffer().size() < 66000:
		large_body += "# 123456789012345678901234567890123456789012345678901234567890\n"

	var large_hash: String = ModuleSharing.compute_sha256(large_body)

	sharing.handle_message(1, "module_share", {
		"action": "data",
		"module_id": "huge_mod",
		"source_code": large_body,
		"hash": large_hash
	})

	assert_true(err_emitted[0], "Packet >64KB emitted sharing_error")
	assert_true(err_text[0].contains("exceeds limit"), "Error message contains 'exceeds limit'")
	assert_false(mod_received[0], "module_received NOT emitted for packet >64KB")

	# Граничное значение: ровно 65536 байт (MAX_MODULE_SIZE_BYTES)
	err_emitted[0] = false
	err_text[0] = ""
	mod_received[0] = false

	var exact_64k := "class_name ExactLimit\nextends Node\n"
	while exact_64k.to_utf8_buffer().size() < 65536:
		exact_64k += "#"
	assert_eq(exact_64k.to_utf8_buffer().size(), 65536, "Payload size is exactly 65536 bytes")

	var exact_hash := ModuleSharing.compute_sha256(exact_64k)
	sharing.handle_message(1, "module_share", {
		"action": "data",
		"module_id": "exact_64k",
		"source_code": exact_64k,
		"hash": exact_hash
	})
	assert_false(err_emitted[0], "Payload exactly 65536 bytes does NOT emit size sharing_error")
	assert_true(mod_received[0], "Payload exactly 65536 bytes successfully emits module_received")

	# Граничное значение: ровно 65537 байт (MAX_MODULE_SIZE_BYTES + 1)
	err_emitted[0] = false
	err_text[0] = ""
	mod_received[0] = false

	var boundary_over := exact_64k + "#"
	assert_eq(boundary_over.to_utf8_buffer().size(), 65537, "Payload size is exactly 65537 bytes")
	var over_hash := ModuleSharing.compute_sha256(boundary_over)
	sharing.handle_message(1, "module_share", {
		"action": "data",
		"module_id": "boundary_over",
		"source_code": boundary_over,
		"hash": over_hash
	})
	assert_true(err_emitted[0], "Payload 65537 bytes emits size sharing_error")
	assert_true(err_text[0].contains("exceeds limit"), "Error contains 'exceeds limit'")
	assert_false(mod_received[0], "module_received NOT emitted for 65537 bytes")

# ------------------------------------------------------------------------------
# 4. Тестирование проверки целостности SHA-256
# ------------------------------------------------------------------------------
func test_hash_integrity_verification() -> void:
	print("\n--- Test Group 4: Hash Integrity Verification ---")

	var sharing: ModuleSharing = track_node(ModuleSharing.new())
	var transport: MockTransport = track_node(MockTransport.new())
	sharing.setup(transport)

	var err_emitted := [false]
	var err_text := [""]
	var mod_received := [false]

	sharing.sharing_error.connect(func(peer: int, err: String):
		err_emitted[0] = true
		err_text[0] = err
	)
	sharing.module_received.connect(func(_id: String, _code: String, _peer: int):
		mod_received[0] = true
	)

	var valid_code := "class_name SampleModule\nextends Node\n"
	var corrupt_hash := "0000000000000000000000000000000000000000000000000000000000000000"

	sharing.handle_message(1, "module_share", {
		"action": "data",
		"module_id": "sample_mod",
		"source_code": valid_code,
		"hash": corrupt_hash
	})

	assert_true(err_emitted[0], "Mismatched SHA-256 triggers sharing_error")
	assert_eq(err_text[0], "Hash verification failed", "Error text is exactly 'Hash verification failed'")
	assert_false(mod_received[0], "module_received NOT emitted when hash verification fails")

# ------------------------------------------------------------------------------
# 5. Тестирование валидации через CodeValidator
# ------------------------------------------------------------------------------
func test_code_validator_integration() -> void:
	print("\n--- Test Group 5: CodeValidator Security & Syntax Validation ---")

	var sharing: ModuleSharing = track_node(ModuleSharing.new())
	var transport: MockTransport = track_node(MockTransport.new())
	var validator := CodeValidator.new()
	sharing.setup(transport, null, validator)

	var err_emitted := [false]
	var err_text := [""]
	var mod_received := [false]

	sharing.sharing_error.connect(func(peer: int, err: String):
		err_emitted[0] = true
		err_text[0] = err
	)
	sharing.module_received.connect(func(_id: String, _code: String, _peer: int):
		mod_received[0] = true
	)

	# 5.1 Опасный код с OS.execute
	var dangerous_code := """class_name EvilMod
extends Node
func initialize(ctx: Dictionary) -> void:
	OS.execute('cmd.exe', [])
func cleanup() -> void:
	pass
func get_module_id() -> String:
	return 'evil_mod'
"""
	var dangerous_hash: String = ModuleSharing.compute_sha256(dangerous_code)

	sharing.handle_message(1, "module_share", {
		"action": "data",
		"module_id": "evil_mod",
		"source_code": dangerous_code,
		"hash": dangerous_hash
	})

	assert_true(err_emitted[0], "Malicious script with OS.execute triggers sharing_error")
	assert_true(err_text[0].contains("Security/syntax check failed"), "Error indicates security/syntax failure")
	assert_false(mod_received[0], "module_received NOT emitted for malicious script")

	# 5.2 Синтаксическая ошибка в коде
	err_emitted[0] = false
	err_text[0] = ""
	mod_received[0] = false

	var broken_syntax := "class_name Broken extends Node func broken_syntax( { : return"
	var broken_hash: String = ModuleSharing.compute_sha256(broken_syntax)

	sharing.handle_message(1, "module_share", {
		"action": "data",
		"module_id": "broken_mod",
		"source_code": broken_syntax,
		"hash": broken_hash
	})

	assert_true(err_emitted[0], "Invalid syntax code triggers sharing_error")
	assert_true(err_text[0].contains("Security/syntax check failed"), "Error indicates syntax failure")
	assert_false(mod_received[0], "module_received NOT emitted for broken syntax")

	# 5.3 Валидный модуль UniCoreModule
	err_emitted[0] = false
	err_text[0] = ""
	mod_received[0] = false

	var valid_code := """class_name ValidMod
extends Node

func get_module_id() -> String:
	return "valid_mod"

func initialize(core_context: Dictionary) -> void:
	pass

func cleanup() -> void:
	pass
"""
	var valid_hash: String = ModuleSharing.compute_sha256(valid_code)

	sharing.handle_message(1, "module_share", {
		"action": "data",
		"module_id": "valid_mod",
		"source_code": valid_code,
		"hash": valid_hash
	})

	assert_false(err_emitted[0], "Valid UniCoreModule does not emit sharing_error")
	assert_true(mod_received[0], "Valid UniCoreModule successfully emits module_received")

# ------------------------------------------------------------------------------
# 6. Полный цикл протокола: offer -> accept -> request -> data -> verify
# ------------------------------------------------------------------------------
func test_offer_accept_request_cycle() -> void:
	print("\n--- Test Group 6: Full Sharing Cycle (offer -> accept -> request -> data -> verify) ---")

	var transport_a: MockTransport = track_node(MockTransport.new())
	var transport_b: MockTransport = track_node(MockTransport.new())

	var lib_a: MockModuleLibrary = track_node(MockModuleLibrary.new())
	var lib_b: MockModuleLibrary = track_node(MockModuleLibrary.new())

	var valid_cube_code := """class_name CubeTool
extends Node

func get_module_id() -> String:
	return "cube_tool"

func initialize(core_context: Dictionary) -> void:
	pass

func cleanup() -> void:
	pass
"""
	lib_a.add_dummy_module("cube_tool", valid_cube_code, "Cube Spawner Tool", "tools")

	var peer_a_sharing: ModuleSharing = track_node(ModuleSharing.new())
	var peer_b_sharing: ModuleSharing = track_node(ModuleSharing.new())

	var validator := CodeValidator.new()

	peer_a_sharing.setup(transport_a, lib_a, validator)
	peer_b_sharing.setup(transport_b, lib_b, validator)

	# Шаг 1: Peer A предлагает модуль Peer B
	var b_offered := [false]
	var b_offered_meta := [{}]
	peer_b_sharing.module_offered.connect(func(peer: int, meta: Dictionary):
		b_offered[0] = true
		b_offered_meta[0] = meta
	)

	peer_a_sharing.offer_module(2, "cube_tool")
	assert_eq(transport_a.sent_messages.size(), 1, "Peer A sent 1 message over transport")
	var offer_msg = transport_a.sent_messages[0]
	assert_eq(offer_msg["channel"], "module_share", "Message sent on 'module_share' channel")
	assert_eq(offer_msg["data"]["action"], "offer", "Action is 'offer'")
	assert_eq(offer_msg["data"]["meta"]["id"], "cube_tool", "Offered module ID matches")

	# Доставляем offer сообщение на Peer B
	peer_b_sharing.handle_message(1, "module_share", offer_msg["data"])
	assert_true(b_offered[0], "Peer B received module_offered signal")
	assert_eq(b_offered_meta[0]["id"], "cube_tool", "Peer B sees offered module id 'cube_tool'")
	assert_eq(peer_b_sharing.get_pending_offers().size(), 1, "Peer B has 1 pending offer")

	# Шаг 2: Peer B принимает предложение (accept_module)
	var a_req_received := [false]
	var a_req_mod_id := [""]
	peer_a_sharing.module_request_received.connect(func(peer: int, m_id: String):
		a_req_received[0] = true
		a_req_mod_id[0] = m_id
	)

	transport_a.clear_records()
	transport_b.clear_records()

	peer_b_sharing.accept_module(1, "cube_tool")
	assert_eq(peer_b_sharing.get_pending_offers().size(), 0, "Pending offer removed on Peer B after accept")
	assert_eq(transport_b.sent_messages.size(), 1, "Peer B sent exactly 1 request packet (no duplicate accept message)")
	var req_msg = transport_b.sent_messages[0]
	assert_eq(req_msg["data"]["action"], "request", "Action is 'request'")

	# Доставляем request на Peer A
	peer_a_sharing.handle_message(2, "module_share", req_msg["data"])
	assert_true(a_req_received[0], "Peer A received module_request_received signal")
	assert_eq(a_req_mod_id[0], "cube_tool", "Peer A received request for 'cube_tool'")

	# Peer A автоматически отвечает пакетом 'data' с исходным кодом и хешем
	assert_eq(transport_a.sent_messages.size(), 1, "Peer A sent exactly 1 data message in response to request")
	var data_msg = transport_a.sent_messages[0]
	assert_eq(data_msg["data"]["action"], "data", "Peer A response action is 'data'")
	assert_eq(data_msg["data"]["module_id"], "cube_tool", "Data message module_id is 'cube_tool'")
	assert_eq(data_msg["data"]["source_code"], valid_cube_code, "Source code correctly attached")

	# Шаг 3: Peer B получает пакет 'data' и верифицирует его
	var b_mod_received_count := [0]
	var b_received_id := [""]
	var b_received_sender := [0]
	peer_b_sharing.module_received.connect(func(m_id: String, _code: String, s_id: int):
		b_mod_received_count[0] += 1
		b_received_id[0] = m_id
		b_received_sender[0] = s_id
	)

	peer_b_sharing.handle_message(1, "module_share", data_msg["data"])
	assert_eq(b_mod_received_count[0], 1, "Peer B emitted module_received signal exactly once")
	assert_eq(b_received_id[0], "cube_tool", "Peer B received correct module_id")
	assert_eq(b_received_sender[0], 1, "Peer B identified correct sender_id (1)")
	assert_true(lib_b.imported_modules.has("cube_tool"), "Module automatically imported into Peer B library")

# ------------------------------------------------------------------------------
# 7. Тестирование отклонения предложения (reject_module)
# ------------------------------------------------------------------------------
func test_offer_rejection() -> void:
	print("\n--- Test Group 7: Offer Rejection ---")

	var sharing: ModuleSharing = track_node(ModuleSharing.new())
	var transport: MockTransport = track_node(MockTransport.new())
	sharing.setup(transport)

	sharing.handle_message(5, "module_share", {
		"action": "offer",
		"meta": {
			"id": "unwanted_mod",
			"name": "Unwanted Module",
			"hash": "abc",
			"size": 123,
			"category": "misc"
		}
	})

	assert_eq(sharing.get_pending_offers().size(), 1, "Pending offer registered")

	sharing.reject_module(5, "unwanted_mod", "Not needed")
	assert_eq(sharing.get_pending_offers().size(), 0, "Pending offer removed after reject_module")
	assert_eq(transport.sent_messages.size(), 1, "Reject message dispatched to transport")
	assert_eq(transport.sent_messages[0]["data"]["action"], "reject", "Action is 'reject'")
	assert_eq(transport.sent_messages[0]["data"]["reason"], "Not needed", "Reason matches 'Not needed'")

# ------------------------------------------------------------------------------
# 8. Тестирование SpaceSync
# ------------------------------------------------------------------------------
func test_space_sync() -> void:
	print("\n--- Test Group 8: SpaceSync State Synchronization ---")

	var transport_a: MockTransport = track_node(MockTransport.new())
	var transport_b: MockTransport = track_node(MockTransport.new())

	var space_mgr_a: MockSpaceManager = track_node(MockSpaceManager.new())
	var space_mgr_b: MockSpaceManager = track_node(MockSpaceManager.new())

	var sync_a: SpaceSync = track_node(SpaceSync.new())
	var sync_b: SpaceSync = track_node(SpaceSync.new())

	sync_a.setup(transport_a, space_mgr_a)
	sync_b.setup(transport_b, space_mgr_b)

	# 8.1 Отправка снимка пространства (send_space_snapshot)
	sync_a.send_space_snapshot(2)
	assert_eq(transport_a.sent_messages.size(), 1, "SpaceSync A sent snapshot message")
	var snap_msg = transport_a.sent_messages[0]
	assert_eq(snap_msg["channel"], "space_sync", "Snapshot sent on 'space_sync' channel")
	assert_eq(snap_msg["data"]["action"], "snapshot", "Action is 'snapshot'")
	assert_eq(snap_msg["data"]["snapshot"]["id"], "mock_space_01", "Snapshot space ID matches")

	# 8.2 Прием снимка пространства на стороне Sync B
	var b_snap_received := [false]
	var b_sync_completed := [false]
	sync_b.snapshot_received.connect(func(peer: int, snap: Dictionary):
		b_snap_received[0] = true
	)
	sync_b.sync_completed.connect(func(peer: int):
		b_sync_completed[0] = true
	)

	sync_b.handle_message(1, "space_sync", snap_msg["data"])
	assert_true(b_snap_received[0], "Peer B received snapshot_received signal")
	assert_true(b_sync_completed[0], "Peer B emitted sync_completed signal")
	assert_eq(space_mgr_b.applied_spaces.size(), 1, "SpaceManager B applied received snapshot")
	assert_eq(space_mgr_b.current_space_data["id"], "mock_space_01", "SpaceManager B current space updated")

	# 8.3 Запрос снимка (request_space_snapshot)
	transport_a.clear_records()
	transport_b.clear_records()

	sync_b.request_space_snapshot(1)
	assert_eq(transport_b.sent_messages.size(), 1, "Peer B sent request_snapshot")
	var req_msg = transport_b.sent_messages[0]
	assert_eq(req_msg["data"]["action"], "request_snapshot", "Action is 'request_snapshot'")

	# Доставляем запрос на Sync A -> Sync A должен ответить снимком
	sync_a.handle_message(2, "space_sync", req_msg["data"])
	assert_eq(transport_a.sent_messages.size(), 1, "Sync A answered request with snapshot")
	assert_eq(transport_a.sent_messages[0]["data"]["action"], "snapshot", "Response action is 'snapshot'")

	# 8.4 Оповещение об изменении состояния модуля (broadcast_module_state_change)
	transport_a.clear_records()
	var b_change_received := [false]
	var b_change_dict := [{}]
	sync_b.state_change_received.connect(func(peer: int, change: Dictionary):
		b_change_received[0] = true
		b_change_dict[0] = change
	)

	sync_a.broadcast_module_state_change("module_loaded", "laser_tool", {"color": "red"})
	assert_eq(transport_a.broadcast_messages.size(), 1, "broadcast_module_state_change triggered broadcast")
	var change_msg = transport_a.broadcast_messages[0]
	assert_eq(change_msg["channel"], "space_sync", "Change broadcasted on channel 'space_sync'")
	assert_eq(change_msg["data"]["change"]["change_type"], "module_loaded", "change_type matches")
	assert_eq(change_msg["data"]["change"]["module_id"], "laser_tool", "module_id matches")

	# Доставляем оповещение на Sync B
	sync_b.handle_message(1, "space_sync", change_msg["data"])
	assert_true(b_change_received[0], "Sync B emitted state_change_received")
	assert_eq(b_change_dict[0]["module_id"], "laser_tool", "Received module_id is 'laser_tool'")

	# 8.5 Пустой снимок игнорируется и не повреждает текущее пространство
	var empty_snap_received := [false]
	sync_b.snapshot_received.connect(func(_p: int, _s: Dictionary): empty_snap_received[0] = true)
	sync_b.handle_message(1, "space_sync", {"action": "snapshot", "snapshot": {}})
	assert_false(empty_snap_received[0], "Empty snapshot packet ignored by SpaceSync")
	assert_eq(space_mgr_b.current_space_data["id"], "mock_space_01", "Space state preserved despite empty packet")

# ------------------------------------------------------------------------------
# 9. Тестирование запроса удаленного модуля и распространение ошибки
# ------------------------------------------------------------------------------
func test_deleted_module_request_and_error_propagation() -> void:
	print("\n--- Test Group 9: Deleted Module Request & Error Propagation ---")

	var transport_host: MockTransport = track_node(MockTransport.new())
	var transport_client: MockTransport = track_node(MockTransport.new())
	var lib_host: MockModuleLibrary = track_node(MockModuleLibrary.new())

	var sharing_host: ModuleSharing = track_node(ModuleSharing.new())
	var sharing_client: ModuleSharing = track_node(ModuleSharing.new())

	sharing_host.setup(transport_host, lib_host)
	sharing_client.setup(transport_client)

	var host_err := [""]
	var client_err := [""]

	sharing_host.sharing_error.connect(func(_p: int, e: String): host_err[0] = e)
	sharing_client.sharing_error.connect(func(_p: int, e: String): client_err[0] = e)

	# Клиент запрашивает модуль, которого нет на хосте
	sharing_host.handle_message(2, "module_share", {
		"action": "request",
		"module_id": "deleted_or_missing_mod"
	})

	assert_true(host_err[0].contains("not found"), "Host detected missing module")
	assert_eq(transport_host.sent_messages.size(), 1, "Host notified requesting client with error packet")
	var err_packet = transport_host.sent_messages[0]
	assert_eq(err_packet["data"]["action"], "error", "Error packet sent to client")

	# Доставляем сообщение об ошибке клиенту
	sharing_client.handle_message(1, "module_share", err_packet["data"])
	assert_true(client_err[0].contains("not found"), "Client caught sharing_error from remote peer")

# ------------------------------------------------------------------------------
# 10. Тестирование дедупликации офферов (Pending Offers)
# ------------------------------------------------------------------------------
func test_pending_offers_deduplication() -> void:
	print("\n--- Test Group 10: Pending Offers Deduplication ---")

	var sharing: ModuleSharing = track_node(ModuleSharing.new())
	var transport: MockTransport = track_node(MockTransport.new())
	sharing.setup(transport)

	var offer_payload := {
		"action": "offer",
		"meta": {
			"id": "repeated_mod",
			"name": "Repeated Module",
			"hash": "abc",
			"size": 500,
			"category": "tools"
		}
	}

	sharing.handle_message(1, "module_share", offer_payload)
	sharing.handle_message(1, "module_share", offer_payload)
	sharing.handle_message(1, "module_share", offer_payload)

	var pending := sharing.get_pending_offers()
	assert_eq(pending.size(), 1, "Repeated identical offers deduplicated into 1 pending offer")

	# Оффер с превышением размера (>64KB) отклоняется сразу
	var err_seen := [false]
	sharing.sharing_error.connect(func(_p: int, _e: String): err_seen[0] = true)
	sharing.handle_message(1, "module_share", {
		"action": "offer",
		"meta": {
			"id": "huge_offer",
			"size": 70000
		}
	})
	assert_true(err_seen[0], "Offer advertising size > 64KB rejected with sharing_error")
	assert_eq(sharing.get_pending_offers().size(), 1, "Pending offers list not polluted with oversized offer")

# ------------------------------------------------------------------------------
# 11. Тестирование валидации пустых данных и идентификаторов
# ------------------------------------------------------------------------------
func test_empty_data_and_id_validation() -> void:
	print("\n--- Test Group 11: Empty Data & ID Validation ---")

	var sharing: ModuleSharing = track_node(ModuleSharing.new())
	var transport: MockTransport = track_node(MockTransport.new())
	sharing.setup(transport)

	var err_msg := [""]
	sharing.sharing_error.connect(func(_p: int, e: String): err_msg[0] = e)

	# Data без module_id
	sharing.handle_message(1, "module_share", {
		"action": "data",
		"module_id": "",
		"source_code": "extends Node\n",
		"hash": ModuleSharing.compute_sha256("extends Node\n")
	})
	assert_true(err_msg[0].contains("without module_id"), "Empty module_id in data rejected")

	# Data с пустым source_code
	err_msg[0] = ""
	sharing.handle_message(1, "module_share", {
		"action": "data",
		"module_id": "empty_code_mod",
		"source_code": "",
		"hash": ModuleSharing.compute_sha256("")
	})
	assert_true(err_msg[0].contains("empty"), "Empty source_code in data rejected")

# ------------------------------------------------------------------------------
# 12. Дополнительные краевые случаи и проверки надежности
# ------------------------------------------------------------------------------
func test_additional_edge_cases() -> void:
	print("\n--- Test Group 12: Edge Cases & Robustness ---")

	var transport: MockTransport = track_node(MockTransport.new())
	var lib: MockModuleLibrary = track_node(MockModuleLibrary.new())
	var sharing: ModuleSharing = track_node(ModuleSharing.new())
	sharing.setup(transport, lib)

	# 12.1 broadcast_module_list()
	lib.add_dummy_module("mod_alpha", "class_name ModAlpha extends Node\n", "Alpha", "math")
	lib.add_dummy_module("mod_beta", "class_name ModBeta extends Node\n", "Beta", "visual")

	sharing.broadcast_module_list()
	assert_eq(transport.broadcast_messages.size(), 1, "broadcast_module_list sends 1 broadcast packet")
	var cat_msg = transport.broadcast_messages[0]
	assert_eq(cat_msg["channel"], "module_share", "Catalog channel is 'module_share'")
	assert_eq(cat_msg["data"]["action"], "catalog", "Catalog action is 'catalog'")
	var cat_modules: Array = cat_msg["data"]["modules"]
	assert_eq(cat_modules.size(), 2, "Broadcast catalog contains 2 modules")

	# 12.2 offer_module() при отсутствии ModuleLibrary
	var sharing_no_lib: ModuleSharing = track_node(ModuleSharing.new())
	var trans_no_lib: MockTransport = track_node(MockTransport.new())
	sharing_no_lib.setup(trans_no_lib, null)

	var err_seen := [false]
	var err_txt := [""]
	sharing_no_lib.sharing_error.connect(func(p: int, e: String):
		err_seen[0] = true
		err_txt[0] = e
	)
	sharing_no_lib.offer_module(1, "mod_alpha")
	assert_true(err_seen[0], "offer_module without library emits sharing_error")
	assert_true(err_txt[0].contains("No ModuleLibrary configured"), "Error specifies no library")

	# 12.3 offer_module() для несуществующего модуля
	err_seen[0] = false
	err_txt[0] = ""
	sharing.sharing_error.connect(func(p: int, e: String):
		err_seen[0] = true
		err_txt[0] = e
	)
	sharing.offer_module(1, "non_existent_module_xyz")
	assert_true(err_seen[0], "offer_module for missing module emits sharing_error")
	assert_true(err_txt[0].contains("not found in library"), "Error specifies module not found")

	# 12.4 request_module() для заблокированного пира
	err_seen[0] = false
	err_txt[0] = ""
	sharing.set_peer_blacklisted(77, true)
	sharing.request_module(77, "mod_alpha")
	assert_true(err_seen[0], "request_module to blacklisted peer emits sharing_error")

	# 12.5 Сброс белого списка возвращает доступ по умолчанию для всех
	sharing.set_peer_blacklisted(77, false)
	sharing.set_peer_whitelisted(88, true)
	assert_true(sharing.is_peer_allowed(88), "Peer 88 is allowed on whitelist")
	assert_false(sharing.is_peer_allowed(89), "Peer 89 is blocked when whitelist has peer 88")

	sharing.set_peer_whitelisted(88, false)
	assert_true(sharing.is_peer_allowed(89), "Peer 89 is allowed again when whitelist is completely cleared")
	assert_true(sharing.is_peer_allowed(88), "Peer 88 is also allowed when whitelist is cleared")

	# 12.6 Передача кастомного снимка в send_space_snapshot()
	var sync_inst: SpaceSync = track_node(SpaceSync.new())
	var sync_trans: MockTransport = track_node(MockTransport.new())
	sync_inst.setup(sync_trans, null)

	var custom_snap := {"id": "custom_01", "name": "Custom Space", "meta": "test"}
	sync_inst.send_space_snapshot(42, custom_snap)
	assert_eq(sync_trans.sent_messages.size(), 1, "send_space_snapshot with custom dict sent 1 message")
	assert_eq(sync_trans.sent_messages[0]["data"]["snapshot"]["id"], "custom_01", "Custom snapshot data preserved")

	# 12.7 offer_module() с кодом > 64KB блокируется
	lib.add_dummy_module("oversized_local_mod", "A".repeat(66000))
	err_seen[0] = false
	err_txt[0] = ""
	sharing.offer_module(1, "oversized_local_mod")
	assert_true(err_seen[0], "offer_module for >64KB module emits sharing_error")
	assert_true(err_txt[0].contains("exceeds limit"), "Error specifies exceeds limit")
