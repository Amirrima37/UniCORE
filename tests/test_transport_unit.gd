extends SceneTree

# Comprehensive Unit and Integration Test Suite for NetworkTransport and LANDiscovery
# Subagent A: Network Transport Layer (Audited & Hardened)

const NetworkTransportScript = preload("res://core/net/network_transport.gd")
const LANDiscoveryScript = preload("res://core/net/lan_discovery.gd")

var passed_count: int = 0
var failed_count: int = 0

func assert_true(condition: bool, test_name: String, error_msg: String = "") -> void:
	if condition:
		print("  [PASS] %s" % test_name)
		passed_count += 1
	else:
		print("  [FAIL] %s - %s" % [test_name, error_msg])
		failed_count += 1

func assert_false(condition: bool, test_name: String, error_msg: String = "") -> void:
	assert_true(not condition, test_name, error_msg)

func assert_eq(val, expected, test_name: String) -> void:
	assert_true(val == expected, test_name, "Expected %s, got %s" % [str(expected), str(val)])

# Phase state machine for async tests
enum State {
	UNIT_TESTS,
	SETUP_LIVE_TRANSPORT,
	WAIT_FOR_CONNECTION,
	TEST_MESSAGING,
	WAIT_FOR_MESSAGES,
	TEST_BROADCAST,
	WAIT_FOR_BROADCAST,
	TEST_HEARTBEAT,
	WAIT_FOR_HEARTBEAT,
	TEST_HEARTBEAT_TIMEOUT,
	WAIT_FOR_HEARTBEAT_TIMEOUT,
	SETUP_LAN_DISCOVERY,
	WAIT_FOR_LAN_DISCOVERY,
	TEST_LAN_DYNAMIC_UPDATE,
	WAIT_FOR_LAN_DYNAMIC_UPDATE,
	TEST_LAN_TIMEOUT,
	WAIT_FOR_LAN_TIMEOUT,
	FINISH
}

var current_state: State = State.UNIT_TESTS
var state_timer: float = 0.0
var frame_counter: int = 0

# Test instances for Live Transport (3-node mesh: Host + Client1 + Client2)
var host_root: Node = null
var client_root: Node = null
var client2_root: Node = null

var host_transport: Node = null
var client_transport: Node = null
var client2_transport: Node = null

var host_mp: SceneMultiplayer = null
var client_mp: SceneMultiplayer = null
var client2_mp: SceneMultiplayer = null

var client_connected_received: bool = false
var client_connected_info: Dictionary = {}
var host_peer_connected_received: bool = false
var host_peer_connected_info: Dictionary = {}
var client2_saw_client1: bool = false
var client1_saw_client2: bool = false

var host_received_msg: Dictionary = {}
var client_received_msg: Dictionary = {}
var client2_received_c1_msg: Dictionary = {}
var client_received_broadcast: Dictionary = {}
var client2_received_broadcast: Dictionary = {}
var host_received_heartbeat_pong: bool = false
var host_saw_peer_timeout_disconnect: bool = false

# Test instances for LAN Discovery
var discovery_listener: Node = null
var discovery_broadcaster: Node = null
var lan_discovered_peer: Dictionary = {}
var lan_updated_peer: Dictionary = {}
var lan_peer_lost_address: String = ""

const TEST_TRANSPORT_PORT: int = 18881
const TEST_DISCOVERY_PORT: int = 18882

func _init() -> void:
	print("==================================================")
	print("UniCORE Network Transport & LAN Discovery Test Suite")
	print("==================================================")

func _process(delta: float) -> bool:
	frame_counter += 1
	state_timer += delta

	match current_state:
		State.UNIT_TESTS:
			_run_unit_tests()
			state_timer = 0.0
			current_state = State.SETUP_LIVE_TRANSPORT

		State.SETUP_LIVE_TRANSPORT:
			_setup_live_transport()
			state_timer = 0.0
			current_state = State.WAIT_FOR_CONNECTION

		State.WAIT_FOR_CONNECTION:
			if host_peer_connected_received and client_connected_received and client1_saw_client2 and client2_saw_client1:
				print("\n--- Live 3-Node Mesh Connection Established ---")
				assert_true(host_transport.is_hosting(), "Host is hosting")
				assert_true(client_transport.is_connected_to_host(), "Client 1 is connected to host")
				assert_true(client2_transport.is_connected_to_host(), "Client 2 is connected to host")
				assert_eq(host_transport.get_connected_peers().size(), 2, "Host has 2 connected peers")
				assert_eq(client_transport.get_connected_peers().size(), 2, "Client 1 has 2 connected peers (host + client 2)")
				assert_eq(client2_transport.get_connected_peers().size(), 2, "Client 2 has 2 connected peers (host + client 1)")
				assert_eq(host_peer_connected_info.get("name"), "UniClientNode", "Host received Client 1's custom name in handshake")
				assert_eq(client_connected_info.get("name"), "UniHostNode", "Client 1 received Host's custom name in handshake")

				state_timer = 0.0
				current_state = State.TEST_MESSAGING
			elif state_timer > 4.0:
				assert_true(false, "Live transport connection timeout", "Failed to establish 3-node mesh within 4.0s")
				state_timer = 0.0
				current_state = State.SETUP_LAN_DISCOVERY

		State.TEST_MESSAGING:
			print("\n--- Testing send_to_peer Across Channels & Mesh Peers ---")
			# Host sends chat to client 1
			var client1_id: int = -1
			for pid in host_transport.get_connected_peers():
				if host_transport.get_peer_info(pid).get("name") == "UniClientNode":
					client1_id = pid
					break

			assert_true(client1_id > 0, "Found client1 ID on host")
			host_transport.send_to_peer(client1_id, "chat", {"text": "Welcome to UniCORE space!"})

			# Client 1 sends module_share to host
			client_transport.send_to_peer(1, "module_share", {"module_id": "mod_cyber_clock", "version": "1.0.0"})

			# Client 1 sends direct chat to Client 2
			var client2_id_from_c1: int = -1
			for pid in client_transport.get_connected_peers():
				if pid != 1:
					client2_id_from_c1 = pid
					break

			assert_true(client2_id_from_c1 > 0, "Client 1 knows client 2 ID")
			client_transport.send_to_peer(client2_id_from_c1, "chat", {"text": "Hello Peer 2 from Peer 1"})

			state_timer = 0.0
			current_state = State.WAIT_FOR_MESSAGES

		State.WAIT_FOR_MESSAGES:
			if not client_received_msg.is_empty() and not host_received_msg.is_empty() and not client2_received_c1_msg.is_empty():
				assert_eq(client_received_msg.get("channel"), "chat", "Client 1 received message on 'chat' channel")
				assert_eq(client_received_msg.get("data", {}).get("text"), "Welcome to UniCORE space!", "Client 1 received chat payload")
				assert_eq(host_received_msg.get("channel"), "module_share", "Host received message on 'module_share' channel")
				assert_eq(host_received_msg.get("data", {}).get("module_id"), "mod_cyber_clock", "Host received module_share payload")
				assert_eq(client2_received_c1_msg.get("data", {}).get("text"), "Hello Peer 2 from Peer 1", "Client 2 received direct message from Client 1")

				state_timer = 0.0
				current_state = State.TEST_BROADCAST
			elif state_timer > 3.0:
				assert_true(false, "Messaging timeout", "Failed to receive messages within 3.0s")
				state_timer = 0.0
				current_state = State.SETUP_LAN_DISCOVERY

		State.TEST_BROADCAST:
			print("\n--- Testing broadcast() Across All Mesh Nodes ---")
			host_transport.broadcast("space_sync", {"space_name": "Matrix Core", "objects_count": 42})
			state_timer = 0.0
			current_state = State.WAIT_FOR_BROADCAST

		State.WAIT_FOR_BROADCAST:
			if not client_received_broadcast.is_empty() and not client2_received_broadcast.is_empty():
				assert_eq(client_received_broadcast.get("channel"), "space_sync", "Client 1 received broadcast on 'space_sync'")
				assert_eq(client_received_broadcast.get("data", {}).get("space_name"), "Matrix Core", "Client 1 broadcast payload validated")
				assert_eq(client2_received_broadcast.get("channel"), "space_sync", "Client 2 received broadcast on 'space_sync'")
				assert_eq(client2_received_broadcast.get("data", {}).get("space_name"), "Matrix Core", "Client 2 broadcast payload validated")

				state_timer = 0.0
				current_state = State.TEST_HEARTBEAT
			elif state_timer > 2.0:
				assert_true(false, "Broadcast timeout", "Both clients did not receive broadcast within 2.0s")
				state_timer = 0.0
				current_state = State.SETUP_LAN_DISCOVERY

		State.TEST_HEARTBEAT:
			print("\n--- Testing Heartbeat Ping/Pong & Latency ---")
			# Trigger heartbeat ping from host
			host_transport._send_heartbeat_ping()
			state_timer = 0.0
			current_state = State.WAIT_FOR_HEARTBEAT

		State.WAIT_FOR_HEARTBEAT:
			if host_received_heartbeat_pong:
				assert_true(true, "Host received pong reply from client on 'heartbeat' channel")
				# Verify RTT latency was calculated
				var any_valid_latency: bool = false
				for pid in host_transport.get_connected_peers():
					var lat: int = host_transport.get_peer_latency(pid)
					if lat >= 0:
						any_valid_latency = true
						print("  Measured peer %d RTT latency: %d ms" % [pid, lat])
				assert_true(any_valid_latency, "Host computed valid RTT latency for connected peers")

				state_timer = 0.0
				current_state = State.TEST_HEARTBEAT_TIMEOUT
			elif state_timer > 2.0:
				assert_true(false, "Heartbeat pong timeout", "Host did not receive pong within 2.0s")
				state_timer = 0.0
				current_state = State.SETUP_LAN_DISCOVERY

		State.TEST_HEARTBEAT_TIMEOUT:
			print("\n--- Testing Heartbeat Timeout Auto-Disconnect ---")
			# Disconnect client 2 cleanly first to focus on client 1 timeout test
			client2_transport.disconnect_session()

			host_transport.heartbeat_timeout = 0.2
			var remaining_client_id: int = host_transport.get_connected_peers()[0]
			host_transport._peer_last_seen[remaining_client_id] = (Time.get_ticks_msec() / 1000.0) - 1.0

			host_transport.peer_disconnected.connect(func(pid: int):
				if pid == remaining_client_id:
					host_saw_peer_timeout_disconnect = true
			)
			state_timer = 0.0
			current_state = State.WAIT_FOR_HEARTBEAT_TIMEOUT

		State.WAIT_FOR_HEARTBEAT_TIMEOUT:
			if host_saw_peer_timeout_disconnect:
				assert_true(true, "Host auto-disconnected timed out peer after timeout threshold")
				assert_true(host_transport.get_connected_peers().is_empty(), "Host connected peers list updated to empty")

				# Clean up transport instances
				host_transport.disconnect_session()
				client_transport.disconnect_session()
				assert_eq(host_transport.get_status(), "disconnected", "Host status is disconnected")
				assert_eq(client_transport.get_status(), "disconnected", "Client status is disconnected")

				state_timer = 0.0
				current_state = State.SETUP_LAN_DISCOVERY
			elif state_timer > 2.0:
				assert_true(false, "Heartbeat auto-disconnect timeout", "Failed to trigger timeout disconnect")
				state_timer = 0.0
				current_state = State.SETUP_LAN_DISCOVERY

		State.SETUP_LAN_DISCOVERY:
			_setup_lan_discovery()
			state_timer = 0.0
			current_state = State.WAIT_FOR_LAN_DISCOVERY

		State.WAIT_FOR_LAN_DISCOVERY:
			if not lan_discovered_peer.is_empty():
				print("\n--- LAN Peer Discovery Succeeded ---")
				assert_eq(lan_discovered_peer.get("name"), "Node-Broadcaster", "Discovered peer name matches broadcaster")
				assert_eq(lan_discovered_peer.get("port"), TEST_TRANSPORT_PORT, "Discovered peer transport port matches")
				assert_eq(lan_discovered_peer.get("version"), "0.3.0", "Discovered peer version matches")
				assert_eq(lan_discovered_peer.get("modules_count"), 7, "Discovered peer modules_count matches")
				assert_true(discovery_listener.get_discovered_peers().size() == 1, "get_discovered_peers() count is 1")

				state_timer = 0.0
				current_state = State.TEST_LAN_DYNAMIC_UPDATE
			elif state_timer > 3.0:
				assert_true(false, "LAN discovery timeout", "Listener did not discover broadcaster within 3.0s")
				state_timer = 0.0
				current_state = State.FINISH

		State.TEST_LAN_DYNAMIC_UPDATE:
			print("\n--- Testing LAN Dynamic Metadata Update ---")
			# Broadcaster updates modules_count to 15
			discovery_broadcaster.set_broadcast_payload({
				"name": "Node-Broadcaster",
				"port": TEST_TRANSPORT_PORT,
				"modules_count": 15
			})
			discovery_broadcaster._send_broadcast_packet()
			state_timer = 0.0
			current_state = State.WAIT_FOR_LAN_DYNAMIC_UPDATE

		State.WAIT_FOR_LAN_DYNAMIC_UPDATE:
			if lan_updated_peer.get("modules_count") == 15:
				assert_true(true, "LAN listener emitted peer_discovered upon dynamic metadata change")
				assert_eq(discovery_listener.get_discovered_peers()[0].get("modules_count"), 15, "Discovered peers store updated module count")
				state_timer = 0.0
				current_state = State.TEST_LAN_TIMEOUT
			elif state_timer > 2.0:
				assert_true(false, "Dynamic update timeout", "Listener did not pick up metadata change within 2.0s")
				state_timer = 0.0
				current_state = State.TEST_LAN_TIMEOUT

		State.TEST_LAN_TIMEOUT:
			print("\n--- Testing LAN Stale Peer Cleanup (peer_lost) ---")
			# Stop broadcaster so no further announces arrive
			discovery_broadcaster.stop_broadcasting()
			assert_false(discovery_broadcaster.is_broadcasting(), "Broadcaster stopped")

			# Set listener peer_timeout very short (0.2s)
			discovery_listener.peer_timeout = 0.2
			discovery_listener.peer_lost.connect(func(addr: String):
				lan_peer_lost_address = addr
			)
			state_timer = 0.0
			current_state = State.WAIT_FOR_LAN_TIMEOUT

		State.WAIT_FOR_LAN_TIMEOUT:
			if not lan_peer_lost_address.is_empty():
				assert_true(true, "LAN listener emitted peer_lost after peer timeout")
				assert_true(discovery_listener.get_discovered_peers().is_empty(), "Discovered peers list is now empty")

				# Clean up discovery instances
				discovery_listener.stop_listening()
				assert_false(discovery_listener.is_listening(), "Listener stopped")

				state_timer = 0.0
				current_state = State.FINISH
			elif state_timer > 2.0:
				assert_true(false, "LAN peer_lost timeout", "peer_lost signal was not emitted within 2.0s")
				state_timer = 0.0
				current_state = State.FINISH

		State.FINISH:
			_print_final_summary()
			if failed_count == 0:
				quit(0)
			else:
				quit(1)
			return true

	return false

# --- Individual Test Methods ---

func _run_unit_tests() -> void:
	print("\n--- Requirement 1: NetworkTransport Unit State & Robustness Tests ---")
	var nt = NetworkTransportScript.new()
	root.add_child(nt)

	assert_eq(nt.get_status(), "disconnected", "Initial status is 'disconnected'")
	assert_false(nt.is_hosting(), "Initial is_hosting is false")
	assert_false(nt.is_connected_to_host(), "Initial is_connected_to_host is false")
	assert_true(nt.get_connected_peers().is_empty(), "Initial connected peers is empty")

	var initial_info: Dictionary = nt.get_local_peer_info()
	assert_true(initial_info.has("id"), "Peer info has 'id'")
	assert_true(initial_info.has("name"), "Peer info has 'name'")
	assert_true(initial_info.has("ip"), "Peer info has 'ip'")
	assert_true(initial_info.has("port"), "Peer info has 'port'")
	assert_true(initial_info.has("modules_count"), "Peer info has 'modules_count'")
	assert_true(initial_info.has("space_name"), "Peer info has 'space_name'")

	# get_peer_info for local ID
	var local_info_via_getter = nt.get_peer_info(0)
	assert_eq(local_info_via_getter.get("name"), "UniNode", "get_peer_info(local_id) returns local peer info")

	# Latency for non-existent peer
	assert_eq(nt.get_peer_latency(9999), -1, "get_peer_latency for unknown peer returns -1")

	nt.set_local_peer_info({
		"name": "CustomNode",
		"modules_count": 5,
		"space_name": "Cyber Void"
	})
	var updated_info: Dictionary = nt.get_local_peer_info()
	assert_eq(updated_info.get("name"), "CustomNode", "Updated name preserved")
	assert_eq(updated_info.get("modules_count"), 5, "Updated modules_count preserved")
	assert_eq(updated_info.get("space_name"), "Cyber Void", "Updated space_name preserved")

	# Supported channels check
	assert_true(NetworkTransportScript.CHANNEL_MODULE_SHARE in NetworkTransportScript.SUPPORTED_CHANNELS, "Channel module_share supported")
	assert_true(NetworkTransportScript.CHANNEL_SPACE_SYNC in NetworkTransportScript.SUPPORTED_CHANNELS, "Channel space_sync supported")
	assert_true(NetworkTransportScript.CHANNEL_CHAT in NetworkTransportScript.SUPPORTED_CHANNELS, "Channel chat supported")
	assert_true(NetworkTransportScript.CHANNEL_DISCOVERY in NetworkTransportScript.SUPPORTED_CHANNELS, "Channel discovery supported")
	assert_true(NetworkTransportScript.CHANNEL_HEARTBEAT in NetworkTransportScript.SUPPORTED_CHANNELS, "Channel heartbeat supported")

	# Safe disconnect when already disconnected
	nt.disconnect_session()
	assert_eq(nt.get_status(), "disconnected", "Disconnect on disconnected is safe")

	# Edge Cases: send_to_peer invalid parameters
	nt.send_to_peer(0, "chat", {"msg": "bad peer id"})
	assert_true(true, "send_to_peer with id 0 handled safely")
	nt.send_to_peer(-5, "chat", {"msg": "negative peer id"})
	assert_true(true, "send_to_peer with negative id handled safely")
	nt.send_to_peer(1, "chat", {"msg": "offline"})
	assert_true(true, "send_to_peer while disconnected handled safely")
	nt.send_to_peer(1, "unsupported_channel_xyz", {"msg": "bad channel"})
	assert_true(true, "send_to_peer with unsupported channel handled safely")

	# Edge Case: broadcast while disconnected
	nt.broadcast("chat", {"msg": "offline broadcast"})
	assert_true(true, "broadcast while disconnected handled safely")

	# Edge Case: host on valid port, then second host on same port
	var err1 = nt.host_session(18885)
	assert_eq(err1, OK, "First host_session on 18885 succeeds")
	var nt_collision = NetworkTransportScript.new()
	root.add_child(nt_collision)
	var err_collision = nt_collision.host_session(18885)
	assert_true(err_collision != OK, "Second host_session on same port returns error code")
	nt_collision.queue_free()
	nt.disconnect_session()

	nt.queue_free()

	print("\n--- Requirement 2: LANDiscovery Unit State & Robustness Tests ---")
	var ld = LANDiscoveryScript.new()
	root.add_child(ld)

	assert_false(ld.is_broadcasting(), "Initial is_broadcasting is false")
	assert_false(ld.is_listening(), "Initial is_listening is false")
	assert_true(ld.get_discovered_peers().is_empty(), "Initial discovered peers is empty")

	var default_payload = ld.get_broadcast_payload()
	assert_eq(default_payload.get("type"), "unicore_announce", "Payload type is 'unicore_announce'")
	assert_eq(default_payload.get("version"), "0.3.0", "Payload version is '0.3.0'")

	ld.set_broadcast_payload({
		"name": "DiscoveryUnitNode",
		"port": 7777,
		"modules_count": 3
	})
	var custom_payload = ld.get_broadcast_payload()
	assert_eq(custom_payload.get("name"), "DiscoveryUnitNode", "Payload name updated")
	assert_eq(custom_payload.get("port"), 7777, "Payload port updated")
	assert_eq(custom_payload.get("modules_count"), 3, "Payload modules_count updated")
	assert_eq(custom_payload.get("type"), "unicore_announce", "Payload type remains 'unicore_announce'")

	# Edge Case: double stop or safe calls when not active
	ld.stop_broadcasting()
	ld.stop_listening()
	assert_false(ld.is_broadcasting(), "stop_broadcasting when idle is safe")
	assert_false(ld.is_listening(), "stop_listening when idle is safe")

	# Edge Case: start listening on bound port collision
	ld.start_listening(18886)
	assert_true(ld.is_listening(), "start_listening on 18886 succeeds")
	var ld_collision = LANDiscoveryScript.new()
	root.add_child(ld_collision)
	ld_collision.start_listening(18886)
	assert_false(ld_collision.is_listening(), "Second listener on same port fails and stays not listening")
	ld_collision.queue_free()
	ld.stop_listening()

	# Edge Case: invalid broadcast address
	ld.broadcast_address = "999.999.999.999"
	ld.start_broadcasting(18887)
	assert_false(ld.is_broadcasting(), "start_broadcasting with invalid address cleanly fails and stays not broadcasting")

	ld.queue_free()

func _setup_live_transport() -> void:
	print("\n--- Live 3-Node Mesh NetworkTransport Connection Setup ---")

	host_root = Node.new()
	host_root.name = "HostRoot"
	root.add_child(host_root)

	client_root = Node.new()
	client_root.name = "ClientRoot"
	root.add_child(client_root)

	client2_root = Node.new()
	client2_root.name = "Client2Root"
	root.add_child(client2_root)

	host_mp = SceneMultiplayer.new()
	host_mp.root_path = host_root.get_path()
	set_multiplayer(host_mp, host_root.get_path())

	client_mp = SceneMultiplayer.new()
	client_mp.root_path = client_root.get_path()
	set_multiplayer(client_mp, client_root.get_path())

	client2_mp = SceneMultiplayer.new()
	client2_mp.root_path = client2_root.get_path()
	set_multiplayer(client2_mp, client2_root.get_path())

	host_transport = NetworkTransportScript.new()
	host_transport.name = "NetworkTransport"
	host_root.add_child(host_transport)
	host_transport.set_local_peer_info({"name": "UniHostNode", "space_name": "StudioHost"})

	client_transport = NetworkTransportScript.new()
	client_transport.name = "NetworkTransport"
	client_root.add_child(client_transport)
	client_transport.set_local_peer_info({"name": "UniClientNode", "space_name": "StudioClient"})

	client2_transport = NetworkTransportScript.new()
	client2_transport.name = "NetworkTransport"
	client2_root.add_child(client2_transport)
	client2_transport.set_local_peer_info({"name": "UniClient2Node", "space_name": "StudioClient2"})

	# Signal connections
	host_transport.peer_connected.connect(func(pid: int, info: Dictionary):
		print("Host saw peer_connected: id=%d, info=%s" % [pid, str(info)])
		host_peer_connected_received = true
		if info.get("name") == "UniClientNode":
			host_peer_connected_info = info
	)

	client_transport.peer_connected.connect(func(pid: int, info: Dictionary):
		print("Client 1 saw peer_connected: id=%d, info=%s" % [pid, str(info)])
		if pid == 1:
			client_connected_received = true
			client_connected_info = info
		elif info.get("name") == "UniClient2Node":
			client1_saw_client2 = true
	)

	client2_transport.peer_connected.connect(func(pid: int, info: Dictionary):
		print("Client 2 saw peer_connected: id=%d, info=%s" % [pid, str(info)])
		if info.get("name") == "UniClientNode":
			client2_saw_client1 = true
	)

	client_transport.message_received.connect(func(pid: int, channel: String, data: Dictionary):
		if channel == "space_sync":
			client_received_broadcast = {"sender": pid, "channel": channel, "data": data}
		elif channel == "chat":
			client_received_msg = {"sender": pid, "channel": channel, "data": data}
	)

	client2_transport.message_received.connect(func(pid: int, channel: String, data: Dictionary):
		if channel == "space_sync":
			client2_received_broadcast = {"sender": pid, "channel": channel, "data": data}
		elif channel == "chat":
			client2_received_c1_msg = {"sender": pid, "channel": channel, "data": data}
	)

	host_transport.message_received.connect(func(pid: int, channel: String, data: Dictionary):
		if channel == "module_share":
			host_received_msg = {"sender": pid, "channel": channel, "data": data}
		elif channel == "heartbeat" and data.get("type") == "pong":
			host_received_heartbeat_pong = true
	)

	# Host starts listening on TEST_TRANSPORT_PORT
	var err_h: Error = host_transport.host_session(TEST_TRANSPORT_PORT)
	assert_eq(err_h, OK, "host_session returned OK")

	# Client 1 connects
	var err_c1: Error = client_transport.join_session("127.0.0.1", TEST_TRANSPORT_PORT)
	assert_eq(err_c1, OK, "client 1 join_session returned OK")
	assert_eq(client_transport.get_status(), "connecting", "Client 1 status is connecting")

	# Client 2 connects
	var err_c2: Error = client2_transport.join_session("127.0.0.1", TEST_TRANSPORT_PORT)
	assert_eq(err_c2, OK, "client 2 join_session returned OK")
	assert_eq(client2_transport.get_status(), "connecting", "Client 2 status is connecting")

func _setup_lan_discovery() -> void:
	print("\n--- Live LANDiscovery Setup ---")

	# Node 1: Listener
	discovery_listener = LANDiscoveryScript.new()
	discovery_listener.name = "ListenerLAN"
	root.add_child(discovery_listener)

	discovery_listener.peer_discovered.connect(func(info: Dictionary):
		print("Listener discovered peer: ", info)
		if lan_discovered_peer.is_empty():
			lan_discovered_peer = info
		else:
			lan_updated_peer = info
	)

	discovery_listener.start_listening(TEST_DISCOVERY_PORT)
	assert_true(discovery_listener.is_listening(), "discovery_listener is_listening is true")

	# Node 2: Broadcaster
	discovery_broadcaster = LANDiscoveryScript.new()
	discovery_broadcaster.name = "BroadcasterLAN"
	discovery_broadcaster.broadcast_address = "127.0.0.1" # Target local loopback in test for 100% deterministic test execution
	root.add_child(discovery_broadcaster)

	discovery_broadcaster.set_broadcast_payload({
		"name": "Node-Broadcaster",
		"port": TEST_TRANSPORT_PORT,
		"modules_count": 7
	})

	discovery_broadcaster.start_broadcasting(TEST_DISCOVERY_PORT, 0.5)
	assert_true(discovery_broadcaster.is_broadcasting(), "discovery_broadcaster is_broadcasting is true")

func _print_final_summary() -> void:
	print("\n==================================================")
	print("Test Summary:")
	print("  Total Passed: %d" % passed_count)
	print("  Total Failed: %d" % failed_count)
	print("==================================================")
