extends SceneTree

# ==============================================================================
# UniCORE Comprehensive Test Suite: Network Layer & P2P Sharing
# ==============================================================================
# Covers:
# - Test 1: NetworkTransport instantiation, local peer info, serialization, channels
# - Test 2: LANDiscovery broadcast payload, JSON packet handling, peer timeout
# - Test 3: ModuleSharing SHA-256 calculation, CodeValidator security check, 64KB limit, whitelist/blacklist
# - Test 4: SpaceSync snapshot serialization and state change broadcasting
# - Test 5: SettingsManager network section defaults, validation, and serialization
# - Test 6: TopBar network LED indicator and MainMenu NetworkTab integration
# ==============================================================================

const NetworkTransport = preload("res://core/net/network_transport.gd")
const LANDiscovery = preload("res://core/net/lan_discovery.gd")
const ModuleSharing = preload("res://core/net/module_sharing.gd")
const SpaceSync = preload("res://core/net/space_sync.gd")
const SettingsManager = preload("res://core/settings_manager.gd")
const CodeValidator = preload("res://agent/code_validator.gd")
const TopBarScene = preload("res://ui/hud/top_bar.tscn")
const MainMenuScene = preload("res://ui/menu/main_menu.tscn")
const CyberTheme = preload("res://ui/theme/cyber_theme.gd")

var passed_count: int = 0
var failed_count: int = 0

func assert_true(condition: bool, test_name: String, error_msg: String = "") -> void:
	if condition:
		print("  [PASS] %s" % test_name)
		passed_count += 1
	else:
		print("  [FAIL] %s %s" % [test_name, ("- " + error_msg) if not error_msg.is_empty() else ""])
		failed_count += 1

func assert_false(condition: bool, test_name: String, error_msg: String = "") -> void:
	assert_true(not condition, test_name, error_msg)

func assert_eq(val, expected, test_name: String) -> void:
	var matches: bool = (val == expected)
	assert_true(matches, test_name, "Expected '%s', got '%s'" % [str(expected), str(val)])

func _init() -> void:
	print("==================================================")
	print("Starting UniCORE Network Layer Comprehensive Suite")
	print("==================================================")

	_run_test_1_network_transport()
	_run_test_2_lan_discovery()
	_run_test_3_module_sharing()
	_run_test_4_space_sync()
	_run_test_5_settings_manager()
	_run_test_6_ui_integration()

	print("\n==================================================")
	print("Network Layer Test Results: %d Passed, %d Failed" % [passed_count, failed_count])
	print("==================================================")

	quit(1 if failed_count > 0 else 0)

# ------------------------------------------------------------------------------
# Test 1: NetworkTransport
# ------------------------------------------------------------------------------
func _run_test_1_network_transport() -> void:
	print("\n--- Test 1: NetworkTransport Creation, Peer Info & Serialization ---")

	var transport := NetworkTransport.new()

	assert_eq(transport.get_status(), NetworkTransport.STATUS_DISCONNECTED, "Initial status is disconnected")
	assert_false(transport.is_hosting(), "Initially not hosting")
	assert_false(transport.is_connected_to_host(), "Initially not connected as client")

	var info := transport.get_local_peer_info()
	assert_true(info is Dictionary, "Local peer info is a Dictionary")
	assert_true(info.has("name") and info.has("port") and info.has("modules_count"), "Peer info has standard keys")

	transport.set_local_peer_info({
		"name": "CustomNode_42",
		"port": 8888,
		"modules_count": 7,
		"space_name": "Cyber Void"
	})
	var updated_info := transport.get_local_peer_info()
	assert_eq(updated_info.get("name"), "CustomNode_42", "Updated peer name verified")
	assert_eq(updated_info.get("port"), 8888, "Updated peer port verified")
	assert_eq(updated_info.get("modules_count"), 7, "Updated modules_count verified")

	# Channels support
	assert_true(NetworkTransport.CHANNEL_MODULE_SHARE in NetworkTransport.SUPPORTED_CHANNELS, "module_share channel supported")
	assert_true(NetworkTransport.CHANNEL_SPACE_SYNC in NetworkTransport.SUPPORTED_CHANNELS, "space_sync channel supported")
	assert_true(NetworkTransport.CHANNEL_DISCOVERY in NetworkTransport.SUPPORTED_CHANNELS, "discovery channel supported")
	assert_true(NetworkTransport.CHANNEL_HEARTBEAT in NetworkTransport.SUPPORTED_CHANNELS, "heartbeat channel supported")

	# Serialization roundtrip
	var test_packet := {
		"channel": "test",
		"counter": 12345,
		"active": true,
		"coords": Vector3(1.5, -2.0, 3.25),
		"nested": {"id": "mod_x", "tags": ["tool", "3d"]}
	}
	var raw_bytes: PackedByteArray = var_to_bytes(test_packet)
	assert_true(raw_bytes.size() > 0, "Serialization produces non-empty bytes")
	var deserialized = bytes_to_var(raw_bytes)
	assert_eq(deserialized.get("counter"), 12345, "Deserialization preserves integers")
	assert_eq(deserialized.get("coords"), Vector3(1.5, -2.0, 3.25), "Deserialization preserves Vector3")
	assert_eq(deserialized.get("nested", {}).get("id"), "mod_x", "Deserialization preserves nested dicts")

	# Check aliases
	assert_true(transport.has_method("send_to_peer"), "NetworkTransport has send_to_peer")
	assert_true(transport.has_method("send_message"), "NetworkTransport has send_message alias")
	assert_true(transport.has_method("broadcast"), "NetworkTransport has broadcast")
	assert_true(transport.has_method("broadcast_message"), "NetworkTransport has broadcast_message alias")

	transport.free()

# ------------------------------------------------------------------------------
# Test 2: LANDiscovery
# ------------------------------------------------------------------------------
func _run_test_2_lan_discovery() -> void:
	print("\n--- Test 2: LANDiscovery Broadcast Payload, Parsing & Peer Timeout ---")

	var discovery := LANDiscovery.new()

	assert_eq(discovery.DEFAULT_DISCOVERY_PORT, 7778, "Default discovery port is 7778")
	assert_eq(discovery.DEFAULT_TRANSPORT_PORT, 7777, "Default transport port is 7777")
	assert_eq(discovery.ANNOUNCE_TYPE, "unicore_announce", "Announce type signature is correct")

	var payload := discovery.get_broadcast_payload()
	assert_eq(payload.get("type"), "unicore_announce", "Initial payload contains announce type")
	assert_true(payload.has("name") and payload.has("port") and payload.has("modules_count"), "Payload contains required keys")

	discovery.set_broadcast_payload({
		"name": "BeaconNode",
		"port": 9000,
		"modules_count": 3
	})
	var updated_payload := discovery.get_broadcast_payload()
	assert_eq(updated_payload.get("name"), "BeaconNode", "Payload name updated")
	assert_eq(updated_payload.get("port"), 9000, "Payload port updated")

	# Mock peer discovery insertion
	var mock_peer_info := {
		"address": "192.168.1.100",
		"port": 7777,
		"name": "RemoteNode_Alpha",
		"version": "0.3.0",
		"modules_count": 5
	}
	discovery._discovered_peers["192.168.1.100:7777"] = mock_peer_info
	discovery._peers_last_seen["192.168.1.100:7777"] = Time.get_ticks_msec() / 1000.0

	var peers_list := discovery.get_discovered_peers()
	assert_eq(peers_list.size(), 1, "Discovered peers list contains 1 peer")
	assert_eq(peers_list[0].get("name"), "RemoteNode_Alpha", "Discovered peer name is preserved")

	# Test peer timeout cleanup
	discovery.peer_timeout = 2.0
	discovery._peers_last_seen["192.168.1.100:7777"] = (Time.get_ticks_msec() / 1000.0) - 10.0 # 10 seconds ago

	var peer_lost_address := [""]
	discovery.peer_lost.connect(func(addr: String): peer_lost_address[0] = addr)

	discovery._cleanup_stale_peers(1.0)
	assert_eq(peer_lost_address[0], "192.168.1.100", "peer_lost emitted on timeout")
	assert_eq(discovery.get_discovered_peers().size(), 0, "Discovered peers list cleaned up after timeout")

	discovery.free()

# ------------------------------------------------------------------------------
# Test 3: ModuleSharing (SHA-256, CodeValidator, Limits, Whitelist/Blacklist)
# ------------------------------------------------------------------------------
func _run_test_3_module_sharing() -> void:
	print("\n--- Test 3: ModuleSharing Security, SHA-256, Size Limit & Filtering ---")

	var sharing := ModuleSharing.new()

	# 1. SHA-256 calculation
	var sample_code := "class_name SampleModule\nextends Node\nfunc _ready():\n\tpass\n"
	var hash_1: String = ModuleSharing.compute_sha256(sample_code)
	assert_true(hash_1.length() == 64, "SHA-256 hash length is 64 hex characters")
	var hash_1_repeat: String = ModuleSharing.compute_sha256(sample_code)
	assert_eq(hash_1, hash_1_repeat, "SHA-256 is deterministic")

	var hash_diff: String = ModuleSharing.compute_sha256(sample_code + "# modified")
	assert_true(hash_1 != hash_diff, "Different code produces different SHA-256")

	var empty_hash: String = ModuleSharing.compute_sha256("")
	assert_eq(empty_hash, "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855", "Empty string SHA-256 matches NIST standard")

	# 2. CodeValidator verification
	var safe_script := "extends Node3D\n\nfunc get_module_id() -> String:\n\treturn \"safe_tool\"\n\nfunc initialize(_context: Dictionary) -> void:\n\tpass\n\nfunc cleanup() -> void:\n\tpass\n"
	var safe_val: Dictionary = CodeValidator.validate_script_source(safe_script)
	assert_true(safe_val.get("is_valid", false), "Safe module passes CodeValidator static analysis")

	var malicious_script := "class_name EvilMod\nextends Node\nfunc _ready():\n\tOS.execute('cmd.exe', ['/c', 'dir'])\n"
	var malicious_val: Dictionary = CodeValidator.validate_script_source(malicious_script)
	assert_false(malicious_val.get("is_valid", true), "Malicious script with OS.execute is rejected by CodeValidator")

	# 3. Size limit (64 KB)
	assert_eq(ModuleSharing.MAX_MODULE_SIZE_BYTES, 65536, "Max module size limit is exactly 64 KB")
	var error_received := [""]
	sharing.sharing_error.connect(func(_pid: int, err: String): error_received[0] = err)

	var oversized_code: String = "var a = 1\n".repeat(7000) # > 70 KB
	assert_true(oversized_code.to_utf8_buffer().size() > 65536, "Generated code exceeds 64 KB limit")

	sharing.setup(null, null, CodeValidator)
	sharing.handle_message(10, "module_share", {
		"action": "data",
		"module_id": "huge_mod",
		"source_code": oversized_code,
		"hash": ModuleSharing.compute_sha256(oversized_code)
	})
	assert_true(error_received[0].contains("exceeds limit"), "Oversized module rejected with error", error_received[0])

	# 4. Hash mismatch rejection
	error_received[0] = ""
	sharing.handle_message(10, "module_share", {
		"action": "data",
		"module_id": "tampered_mod",
		"source_code": safe_script,
		"hash": "0000000000000000000000000000000000000000000000000000000000000000" # wrong hash
	})
	assert_true(error_received[0].contains("Hash verification failed"), "Tampered module rejected due to hash mismatch")

	# 4b. Dangerous / malicious script rejection in handle_message
	error_received[0] = ""
	var received_module_flag := [false]
	sharing.module_received.connect(func(_id: String, _src: String, _sender: int): received_module_flag[0] = true)
	sharing.handle_message(10, "module_share", {
		"action": "data",
		"module_id": "malicious_mod",
		"source_code": malicious_script,
		"hash": ModuleSharing.compute_sha256(malicious_script)
	})
	assert_true(error_received[0].contains("Security/syntax check failed"), "Dangerous script rejected by ModuleSharing handle_message")
	assert_false(received_module_flag[0], "module_received NOT emitted for dangerous script")

	# 5. Whitelist & Blacklist peer filtering
	assert_true(sharing.is_peer_allowed(100), "Peer 100 initially allowed")

	sharing.set_peer_blacklisted(100, true)
	assert_false(sharing.is_peer_allowed(100), "Blacklisted peer 100 is rejected")
	assert_true(sharing.is_peer_allowed(101), "Non-blacklisted peer 101 is allowed")

	sharing.set_peer_blacklisted(100, false)
	assert_true(sharing.is_peer_allowed(100), "Unblacklisted peer 100 is allowed again")

	sharing.set_peer_whitelisted(200, true)
	assert_true(sharing.is_peer_allowed(200), "Whitelisted peer 200 is allowed")
	assert_false(sharing.is_peer_allowed(201), "Non-whitelisted peer 201 is denied when whitelist is active")

	sharing.set_peer_whitelisted(200, false)
	assert_true(sharing.is_peer_allowed(201), "When whitelist is empty, all non-blacklisted peers are allowed")

	sharing.free()

# ------------------------------------------------------------------------------
# Test 4: SpaceSync
# ------------------------------------------------------------------------------
func _run_test_4_space_sync() -> void:
	print("\n--- Test 4: SpaceSync Snapshot Serialization & State Changes ---")

	var sync := SpaceSync.new()
	assert_eq(SpaceSync.CHANNEL_NAME, "space_sync", "SpaceSync channel is 'space_sync'")

	var received_snapshot := [{}]
	var sync_completed_flag := [false]
	var received_state_change := [{}]

	sync.snapshot_received.connect(func(_pid: int, snap: Dictionary): received_snapshot[0] = snap)
	sync.sync_completed.connect(func(_pid: int): sync_completed_flag[0] = true)
	sync.state_change_received.connect(func(_pid: int, ch: Dictionary): received_state_change[0] = ch)

	# Simulate incoming snapshot
	var mock_snapshot := {
		"name": "Cyber Studio Lab",
		"version": "1.0",
		"modules": [
			{"id": "ground_plane", "active": true},
			{"id": "cube_spawner", "active": false}
		],
		"camera": {
			"position": Vector3(0, 5, 10),
			"rotation": Vector3(-0.3, 0, 0)
		}
	}

	sync.handle_message(5, "space_sync", {
		"action": "snapshot",
		"snapshot": mock_snapshot
	})

	assert_true(sync_completed_flag[0], "sync_completed signal fired")
	assert_eq(received_snapshot[0].get("name"), "Cyber Studio Lab", "Snapshot name correctly deserialized")
	assert_eq(received_snapshot[0].get("modules", []).size(), 2, "Snapshot modules array intact")

	# Simulate module state change event
	sync.handle_message(5, "space_sync", {
		"action": "state_change",
		"change": {
			"change_type": "module_loaded",
			"module_id": "laser_tool",
			"details": {"author": "UniNode"}
		}
	})

	assert_eq(received_state_change[0].get("change_type"), "module_loaded", "State change type parsed")
	assert_eq(received_state_change[0].get("module_id"), "laser_tool", "State change module_id parsed")

	sync.free()

# ------------------------------------------------------------------------------
# Test 5: SettingsManager Network Section
# ------------------------------------------------------------------------------
func _run_test_5_settings_manager() -> void:
	print("\n--- Test 5: SettingsManager Network Section & Validation ---")

	var settings := SettingsManager.new()
	settings.reset_to_defaults()

	# Defaults validation
	assert_eq(settings.get_setting("network", "auto_discovery"), true, "Default auto_discovery is true")
	assert_eq(settings.get_setting("network", "share_modules"), true, "Default share_modules is true")
	assert_eq(settings.get_setting("network", "host_port"), 7777, "Default host_port is 7777")
	assert_eq(settings.get_setting("network", "discovery_port"), 7778, "Default discovery_port is 7778")
	assert_eq(settings.get_setting("network", "player_name"), "UniCORE Node", "Default player_name is 'UniCORE Node'")
	assert_eq(settings.get_setting("network", "max_module_size_kb"), 64, "Default max_module_size_kb is 64")

	# Helper methods
	var net_dict: Dictionary = settings.get_network_settings()
	assert_true(net_dict.has("host_port") and net_dict.has("discovery_port"), "get_network_settings() returns full dict")

	# Clamping and sanitization
	settings.set_setting("network", "host_port", 999999, false)
	assert_eq(settings.get_setting("network", "host_port"), 65535, "Port clamped to 65535 on high overflow")

	settings.set_setting("network", "host_port", 10, false)
	assert_eq(settings.get_setting("network", "host_port"), 1024, "Port clamped to 1024 on privileged port underflow")

	settings.set_setting("network", "max_module_size_kb", 2048, false)
	assert_eq(settings.get_setting("network", "max_module_size_kb"), 1024, "max_module_size_kb clamped to 1024 KB max")

	settings.set_setting("network", "auto_discovery", "false", false)
	assert_eq(settings.get_setting("network", "auto_discovery"), false, "auto_discovery parses string 'false' as bool false")

	settings.set_setting("network", "auto_discovery", "true", false)
	assert_eq(settings.get_setting("network", "auto_discovery"), true, "auto_discovery parses string 'true' as bool true")

	# Player name sanitization
	settings.set_setting("network", "player_name", "  CyberAgent_999  ", false)
	assert_eq(settings.get_setting("network", "player_name"), "CyberAgent_999", "Player name is stripped of surrounding whitespace")

	settings.free()

# ------------------------------------------------------------------------------
# Test 6: TopBar LED & MainMenu NetworkTab Integration
# ------------------------------------------------------------------------------
func _run_test_6_ui_integration() -> void:
	print("\n--- Test 6: TopBar LED & MainMenu NetworkTab UI Integration ---")

	var root := Node.new()
	get_root().add_child(root)

	var settings_mgr := SettingsManager.new()
	root.add_child(settings_mgr)

	var transport := NetworkTransport.new()
	var discovery := LANDiscovery.new()
	var sharing := ModuleSharing.new()
	var sync := SpaceSync.new()
	root.add_child(transport)
	root.add_child(discovery)
	root.add_child(sharing)
	root.add_child(sync)

	# 1. TopBar LED testing
	var top_bar := TopBarScene.instantiate()
	root.add_child(top_bar)
	top_bar.setup(settings_mgr, null, null, null)

	assert_true(top_bar.network_btn != null, "TopBar has network_btn")
	assert_true(top_bar.network_status_led != null, "TopBar has network_status_led")

	# Test Offline
	top_bar.update_network_status("offline")
	assert_eq(top_bar.get_network_status_color(), top_bar.COLOR_NET_OFFLINE, "Offline status color is gray/dim cyan")
	assert_true(top_bar.network_btn.tooltip_text.contains("Offline"), "Offline tooltip reflects state")

	# Test Hosting
	top_bar.update_network_status("hosting", 0)
	assert_eq(top_bar.get_network_status_color(), top_bar.COLOR_NET_HOSTING, "Hosting status color is cyber cyan")
	assert_eq(top_bar.network_btn.text, "● ХОСТ", "Initial host text with 0 peers")

	# Test peer count transitions in Hosting state
	top_bar.update_network_status("hosting", 3)
	assert_true(top_bar.network_btn.text.contains("ХОСТ (3)"), "Button label shows host peer count 3")
	top_bar.update_network_status("hosting", 1)
	assert_true(top_bar.network_btn.text.contains("ХОСТ (1)"), "Button label dynamically updates when peer disconnects")

	# Test Connected (Client)
	top_bar.update_network_status("connected", 2, "MainServer")
	assert_eq(top_bar.get_network_status_color(), top_bar.COLOR_NET_CONNECTED, "Connected status color is emerald LED")
	assert_true(top_bar.network_btn.tooltip_text.contains("MainServer"), "Connected tooltip displays host name")

	# Test Syncing
	top_bar.update_network_status("syncing")
	assert_eq(top_bar.get_network_status_color(), top_bar.COLOR_NET_SYNCING, "Syncing status color is amber LED")

	# Test network button click emits menu request
	var requested_tab := [""]
	top_bar.menu_button_pressed.connect(func(tab: String): requested_tab[0] = tab)
	top_bar.network_btn.pressed.emit()
	assert_eq(requested_tab[0], "network", "Clicking network LED button requests 'network' tab")

	# 2. MainMenu NetworkTab testing
	var main_menu := MainMenuScene.instantiate()
	root.add_child(main_menu)
	main_menu.setup(settings_mgr, null, null, null, null, transport, discovery, sharing, sync)

	assert_true(main_menu.network_tab != null, "MainMenu has network_tab MarginContainer")
	assert_true(main_menu.session_status_label != null, "MainMenu has session_status_label")
	assert_true(main_menu.lan_peers_list != null, "MainMenu has lan_peers_list container")
	assert_true(main_menu.connected_peers_list != null, "MainMenu has connected_peers_list container")
	assert_true(main_menu.module_offers_list != null, "MainMenu has module_offers_list container")

	# Verify Tab title
	assert_true(main_menu.tab_container.get_tab_title(4).contains("СЕТЬ"), "TabContainer tab 4 is titled 'СЕТЬ'")

	# Open network tab
	main_menu.open("network")
	assert_true(main_menu.is_open, "MainMenu opened on 'network' command")
	assert_eq(main_menu.tab_container.current_tab, 4, "Current tab is 4 (NetworkTab)")

	# Test LAN peers UI update
	discovery._discovered_peers["10.0.0.5:7777"] = {
		"name": "AlphaNode",
		"address": "10.0.0.5",
		"port": 7777,
		"modules_count": 4
	}
	main_menu.update_lan_peers()
	assert_true(main_menu.lan_peers_list.get_child_count() > 0, "LAN peers list displays discovered nodes")

	# Test Module Offers UI update
	main_menu.add_module_offer(1, {
		"id": "laser_blaster",
		"name": "Laser Blaster Tool",
		"size": 4096,
		"hash": "abcdef123456"
	})
	assert_eq(main_menu.module_offers_list.get_child_count(), 1, "Module offers list populated with incoming offer")

	# Test offer deduplication: adding identical offer should NOT create second card
	main_menu.add_module_offer(1, {
		"id": "laser_blaster",
		"name": "Laser Blaster Tool",
		"size": 4096,
		"hash": "abcdef123456"
	})
	assert_eq(main_menu.module_offers_list.get_child_count(), 1, "Duplicate offer is correctly deduplicated")

	# Test stop hosting stops LAN broadcasting
	var host_err: Error = transport.host_session(18895)
	if host_err == OK:
		discovery.start_broadcasting(7778)
		assert_true(transport.is_hosting(), "Transport is hosting")
		assert_true(discovery.is_broadcasting(), "LANDiscovery is broadcasting while hosting")
		main_menu._on_host_session_pressed()
		assert_false(transport.is_hosting(), "Host session toggled off")
		assert_false(discovery.is_broadcasting(), "Stopping host session stops LAN broadcasting")

	# Test disconnect button also stops broadcasting
	discovery.start_broadcasting(7778)
	assert_true(discovery.is_broadcasting(), "LANDiscovery is broadcasting before disconnect button")
	main_menu._on_disconnect_session_pressed()
	assert_false(discovery.is_broadcasting(), "Disconnecting session stops LAN broadcasting")

	# Close menu
	main_menu.close()
	assert_false(main_menu.is_open, "MainMenu closed")

	# Cleanup
	root.queue_free()
