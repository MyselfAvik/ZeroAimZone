extends Node2D

const PORT       = 9000
const UDP_PORT   = 9999
const CODE_CHARS = "0123456789"

const UDP_CLIENT_PORT = 10000

var peer: ENetMultiplayerPeer
var udp_server: PacketPeerUDP   
var udp_local: PacketPeerUDP    
var udp_client: PacketPeerUDP  
var broadcasting: bool = false

var my_id: int = 0

var my_info := {
	"name": "",
	"peer_id": 0,
	"avatar":0,
	"frame":0,
	"ip": "",
	"gun":0,
	"skin":0
}


var next_lobby_host:int=-1
var pending_match_players := []
var lobby_match_data := {}
var local_match_data := {}

var match_ack := {}

const MATCH_PORT_START = 9500
const MATCH_PORT_END   = 9600

var match_peer: ENetMultiplayerPeer
var peer_info := {
	
} 

# Godot RPC serialization sometimes stringifies integer dictionary keys.
# This safe getter checks both int and string key forms to prevent crashes.
func _get_peer(id: int) -> Dictionary:
	if peer_info.has(id):
		return peer_info[id]
	var str_id = str(id)
	if peer_info.has(str_id):
		return peer_info[str_id]
	printerr("[NetworkHandler] peer_info missing entry for id: ", id, " keys: ", peer_info.keys())
	return {}

func _enter_tree() -> void:
	GameManager.network_handler=self

func _ready() -> void:
	setup_network_lag()

func setup_network_lag() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

	# Set all autoload singletons to process always so they don't freeze when paused
	var root = get_tree().root
	var current_scene = get_tree().current_scene
	for child in root.get_children():
		if child != current_scene and child is Node:
			if child.process_mode == Node.PROCESS_MODE_INHERIT:
				child.process_mode = Node.PROCESS_MODE_ALWAYS

	# Pause engine when internet disconnects, resume when it reconnects
	if is_instance_valid(AuthManager) and AuthManager._network_monitor:
		if not AuthManager._network_monitor.internet_state_changed.is_connected(_on_internet_state_changed):
			AuthManager._network_monitor.internet_state_changed.connect(_on_internet_state_changed)

func _on_internet_state_changed(online: bool) -> void:
	if get_tree():
		get_tree().paused = not online

func _get_friend_panel():
	if is_instance_valid(GameManager.ui_manager) and is_instance_valid(GameManager.ui_manager.base_panel):
		return GameManager.ui_manager.base_panel.friend_panel
	return null

func reset():
	peer_info.clear()
	match_ack.clear()
	local_match_data.clear()
	lobby_match_data.clear()
	pending_match_players.clear()
	next_lobby_host = -1

	var fp = _get_friend_panel()
	if fp:
		fp.clear_cards()
func start_host() -> bool:
	reset()
	my_info["name"]=GameManager.save_manager.game_data["player_data"]["name"]
	my_info["avatar"]=GameManager.save_manager.game_data["player_data"]["profile_pic_index"]
	my_info["frame"]=GameManager.save_manager.game_data["player_data"]["profile_frame_index"]
	my_info["gun"]=GameManager.save_manager.game_data["guns_data"]["gun_selected_index"]
	my_info["skin"]=GameManager.save_manager.game_data["guns_data"]["skin_selected"][my_info["gun"]]
	
	var ip=get_local_ip()
	if ip=="":
		return false
	my_info["ip"] = ip
	var gun_idx = GameManager.save_manager.game_data["guns_data"]["gun_selected_index"]
	my_info["gun_index"] = gun_idx
	my_info["skin_index"] = GameManager.save_manager.game_data["guns_data"]["skin_selected"][gun_idx]
	
	
	if peer != null:
		print("[HOST] Existing peer found — closing before creating new host")
		stop_host()
	if await  _listen_for_host():
		return true
	
	peer = ENetMultiplayerPeer.new()
	var err = peer.create_server(PORT, 10)
	if err != OK:
		print("[HOST] Failed to create server — ", _explain_error(err))
		GameManager.ui_manager.base_panel.friend_panel.reset()
		GameManager.ui_manager.base_panel.friend_panel.none.visible=false
		
		GameManager.ui_manager.base_panel.friend_panel.error.visible=true
		GameManager.ui_manager.base_panel.friend_panel.error.text=GameManager.ui_manager.base_panel.friend_panel.error.text+"\n"+str(_explain_error(err))
		GameManager.ui_manager.base_panel.friend_panel.create_btn.get_child(0).text="Try Again"
		return false
	my_info["peer_id"] = 1
	peer_info[1] = my_info
	multiplayer.multiplayer_peer = peer
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	print("[HOST] Server created successfully on port ", PORT, " | My IP: ", my_info["ip"])
	_start_broadcasting()
	return true

func _start_broadcasting():
	broadcasting = true
	udp_server = PacketPeerUDP.new()
	udp_server.set_broadcast_enabled(true)

	udp_local = PacketPeerUDP.new()
	udp_local.set_dest_address("127.0.0.1", UDP_CLIENT_PORT)

	var local_ip     = get_local_ip()
	var broadcast_ip = _get_broadcast_address(local_ip)
	print("[BROADCAST] Local IP: ", local_ip, " | Broadcasting to: ", broadcast_ip, " and 255.255.255.255")

	udp_server.set_dest_address(broadcast_ip, UDP_CLIENT_PORT)
	_broadcast_loop()

func _broadcast_loop():
	while broadcasting:
		var local_ip = get_local_ip()
		var msg      = (local_ip).to_utf8_buffer()

		# 1. LAN / hotspot subnet broadcast
		udp_server.put_packet(msg)

		# 2. Loopback for same-PC instances
		udp_local.put_packet(msg)

		# 3. Global broadcast fallback (helps with non-/24 subnets & mobile hotspots)
		var global_bc = PacketPeerUDP.new()
		global_bc.set_broadcast_enabled(true)
		global_bc.set_dest_address("255.255.255.255", UDP_CLIENT_PORT)
		global_bc.put_packet(msg)
		global_bc.close()

		# 4. Broadcast on every other local interface
		for ip in _get_all_local_ips():
			if ip != local_ip:
				var extra = PacketPeerUDP.new()
				extra.set_broadcast_enabled(true)
				extra.set_dest_address(_get_broadcast_address(ip), UDP_CLIENT_PORT)
				extra.put_packet(msg)
				extra.close()

		await get_tree().create_timer(1.0).timeout

func stop_host():
	print("[HOST] Stopping")
	broadcasting = false

	var fp = _get_friend_panel()
	if fp:
		fp.cancel_all_pending_challenges()
		fp.clear_cards()
	peer_info.clear()

	if udp_server:
		udp_server.close()
		udp_server = null
	if udp_local:
		udp_local.close()
		udp_local = null
	if udp_client:
		udp_client.close()
		udp_client = null
	_listening = false


	_disconnect_lobby_signals()

	if peer:
		peer.close()
		peer = null
	multiplayer.multiplayer_peer = null
	print("[HOST] Stopped")
	

func stop_broadcasting():
	peer_info.clear()
	broadcasting = false
	if udp_server:
		udp_server.close()
		udp_server = null
	if udp_local:
		udp_local.close()
		udp_local = null
	print("[HOST] Broadcasting stopped, peer still alive")
	

func _become_host_via_migration() -> void:
	my_info["ip"] = get_local_ip()

	peer = ENetMultiplayerPeer.new()
	var err = peer.create_server(PORT, 10)
	if err != OK:
		GameManager.ui_manager.base_panel.friend_panel.reset()
		GameManager.ui_manager.base_panel.friend_panel.none.visible=false
		GameManager.ui_manager.base_panel.friend_panel.error.visible=true
		GameManager.ui_manager.base_panel.friend_panel.error.text=GameManager.ui_manager.base_panel.friend_panel.error.text+"\n"+str(_explain_error(err))
		GameManager.ui_manager.base_panel.friend_panel.create_btn.get_child(0).text="Try Again"
		return

	multiplayer.multiplayer_peer = peer

	my_id = multiplayer.get_unique_id()   
	my_info["peer_id"] = my_id

	peer_info.clear()
	peer_info[my_id] = my_info

	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)

	_start_broadcasting()


# ── CLIENT ────────────────────────────────────────────────────────────────────

func start_client() -> bool:
	my_info["name"]=GameManager.save_manager.game_data["player_data"]["name"]
	return await _listen_for_host()
var _listening=false

func _listen_for_host() -> bool:
	if _listening:
		print("[CLIENT] Already listening — ignoring duplicate call")
		return false
	_listening = true

	udp_client = PacketPeerUDP.new()
	var err = udp_client.bind(UDP_CLIENT_PORT, "0.0.0.0")
	if err != OK:
		print("[CLIENT] Failed to bind port ", UDP_CLIENT_PORT, " — ", _explain_error(err))
		_listening = false
		return false

	print("[CLIENT] Listening on port ", UDP_CLIENT_PORT, " | My IPs: ", _get_all_local_ips())
	var timeout = 8.0
	var elapsed = 0.0
	while elapsed < timeout and _listening and udp_client != null:
		while udp_client and udp_client.get_available_packet_count() > 0:
			var pkt = udp_client.get_packet()
			var msg = pkt.get_string_from_utf8()
			var sender_ip = udp_client.get_packet_ip()
			var sender_port = udp_client.get_packet_port()
			print("[CLIENT] Received broadcast — host IP in msg: ", msg, " | sender: ", sender_ip, ":", sender_port)
			# Ignore our own broadcasts (same device running host+client)
			var my_ips = _get_all_local_ips()
			# Use the IP from the message (the host's chosen LAN IP)
			udp_client.close()
			udp_client = null
			_listening = false
			_connect_to_host(msg)
			return true
		await get_tree().create_timer(0.5).timeout
		elapsed += 0.5
		if int(elapsed) % 2 == 0 and elapsed == int(elapsed):
			print("[CLIENT] Still waiting for host broadcast... ", elapsed, "s / ", timeout, "s")

	print("[CLIENT] Timed out or cancelled — no host found ")
	if udp_client:
		udp_client.close()
		udp_client = null
	_listening = false
	return false

func _connect_to_host(host_ip: String):
	print("[CLIENT] Connecting to ", host_ip, ":", PORT, " | My IP: ", get_local_ip())
	peer = ENetMultiplayerPeer.new()
	var err = peer.create_client(host_ip, PORT)
	if err != OK:
		print("[CLIENT] create_client failed — ", _explain_error(err))
		return
	print("[CLIENT] create_client OK — waiting for connected_to_server signal...")
	multiplayer.multiplayer_peer = peer
	multiplayer.connected_to_server.connect(_on_connected)
	multiplayer.connection_failed.connect(_on_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)
	

# ── CALLBACKS ─────────────────────────────────────────────────────────────────

@rpc("any_peer", "reliable")
func _register_info(info: Dictionary):
	var sender_id = multiplayer.get_remote_sender_id()
	peer_info[sender_id] = info
	print("[HOST] Registered peer ", sender_id, ": ", info)
	print("[HOST] peer_info now has keys: ", peer_info.keys())
	_sync_all_info.rpc(peer_info)
	# Host doesn't get the call_local anymore — refresh its own UI directly
	if multiplayer.is_server():
		_refresh_friend_ui()

@rpc("authority", "reliable")
func _sync_all_info(all_info: Dictionary):
	print("[SYNC] _sync_all_info received — keys: ", all_info.keys(), " | is_server: ", multiplayer.is_server())
	# Only update peer_info on clients — the host never runs this locally
	# (call_local was removed to prevent integer keys being stringified by
	#  Godot's RPC serializer when the dictionary is applied to self).
	if not multiplayer.is_server():
		peer_info = all_info
	_refresh_friend_ui()

func _refresh_friend_ui() -> void:
	if not is_instance_valid(GameManager.ui_manager):
		print("[UI] _refresh_friend_ui — ui_manager invalid!")
		return
	var mine_id = multiplayer.get_unique_id()
	print("[UI] _refresh_friend_ui — my_id: ", mine_id, " | peer_info keys: ", peer_info.keys())
	GameManager.ui_manager.base_panel.friend_panel.clear_cards()
	for id in peer_info:
		var int_id = int(str(id)) if typeof(id) == TYPE_STRING else id
		if int_id == mine_id:
			continue
		var entry = peer_info[id]
		if entry is Dictionary and entry.has("name"):
			GameManager.ui_manager.base_panel.friend_panel.add_cards(int_id, entry["name"])
			print("[UI] Adding card for peer: ", int_id, " name: ", entry["name"])
		else:
			print("[UI] Skipping peer ", id, " — entry invalid or no name: ", entry)

func _on_failed():
	print("[CLIENT] Connection FAILED! Could not reach host via ENet TCP")
	print("[CLIENT] This usually means firewall is blocking port ", PORT, " or the host IP is wrong")



func _on_connected():
	print("[CLIENT] Connected to host! ENet handshake successful")
	my_id = multiplayer.get_unique_id()
	my_info["peer_id"] = my_id
	my_info["ip"] = get_local_ip()
	my_info["avatar"]=GameManager.save_manager.game_data["player_data"]["profile_pic_index"]
	my_info["frame"]=GameManager.save_manager.game_data["player_data"]["profile_frame_index"]
	var gun_idx = GameManager.save_manager.game_data["guns_data"]["gun_selected_index"]
	my_info["gun_index"] = gun_idx
	my_info["skin_index"] = GameManager.save_manager.game_data["guns_data"]["skin_selected"][gun_idx]
	print("[CLIENT] Sending _register_info to host — my_id: ", my_id, " name: ", my_info["name"])
	_register_info.rpc_id(1, my_info)

func _on_peer_connected(id: int):
	print("[HOST] Player connected — id: ", id, " | total peers: ", multiplayer.get_peers().size())
	if multiplayer.is_server():
		peer_info[multiplayer.get_unique_id()] = my_info

func _on_peer_disconnected(id: int):
	print("[HOST] Player disconnected — id: ", id)
	var popup_panel = GameManager.ui_manager.popup_panel if is_instance_valid(GameManager.ui_manager) else null
	if popup_panel and is_instance_valid(popup_panel.freind_request_popup):
		if popup_panel.freind_request_popup.challenger_id == id:
			popup_panel.freind_request_popup.expire()

	var fp = _get_friend_panel()
	if fp:
		fp.reset_challenge_button(id)
		if fp.pending_challenges.has(id):
			fp.pending_challenges.erase(id)
		for target_id in fp.pending_challenges.keys():
			if fp.pending_challenges[target_id] == id:
				fp.pending_challenges.erase(target_id)
				fp._deliver_challenge_expired.rpc_id(target_id, id)

	if multiplayer.is_server():
		peer_info.erase(id)
		call_deferred("_broadcast_peer_info")

func _broadcast_peer_info():
	if multiplayer.multiplayer_peer == null:
		return

	if multiplayer.multiplayer_peer.get_connection_status() != MultiplayerPeer.CONNECTION_CONNECTED:
		return

	_sync_all_info.rpc(peer_info)

func _on_server_disconnected():
	print("[CLIENT] Host disconnected — starting migration")

	var popup_panel = GameManager.ui_manager.popup_panel if is_instance_valid(GameManager.ui_manager) else null
	if popup_panel and is_instance_valid(popup_panel.freind_request_popup):
		popup_panel.freind_request_popup.expire()

	_disconnect_lobby_signals()

	var fp = _get_friend_panel()
	if fp:
		fp.clear_cards()
	peer_info.erase(1)

	await get_tree().process_frame

	if next_lobby_host == -1:
		next_lobby_host = choose_next_lobby_host(0, 0, -1)

	peer = null
	multiplayer.multiplayer_peer = null

	if next_lobby_host == -1:
		peer_info.clear()
		return

	if my_id == next_lobby_host:
		print("[MIGRATE] I'm the next lobby host")
		_become_host_via_migration()
	else:
		print("[MIGRATE] Waiting for new lobby host")
		start_client()

	peer_info.clear()


# ── ACCEPT FLOW ────────────────────────────────────

@rpc("any_peer", "reliable")
func accept_challenge(challenger_id:int, accepter_id:int):

	if !multiplayer.is_server():
		return

	var target_id = accepter_id
	var host_id = multiplayer.get_unique_id()

	# Validate that challenger is still connected
	if challenger_id != host_id and not peer_info.has(challenger_id) and not peer_info.has(str(challenger_id)):
		print("[HOST] Cannot accept challenge: challenger ", challenger_id, " is no longer in the lobby")
		return

	print(str(challenger_id,accepter_id))
	match_ack.clear()
	
	
	var port = find_free_match_port()

	if port == -1:
		print("No free ports!")
		return
	
	var host_is_playing = (challenger_id == host_id or target_id == host_id)
	var next_host = -1

	if host_is_playing:
		next_host = choose_next_lobby_host(challenger_id, target_id, host_id)
		set_next_host.rpc(next_host)

	pending_match_players = [
		challenger_id,
		target_id
	]

	var challenger_ip := ""

	if challenger_id == host_id:
		challenger_ip = my_info["ip"]
	else:
		challenger_ip = _get_peer(challenger_id).get("ip", "")

	lobby_match_data = {
	"challenger": challenger_id,
	"target": target_id,
	"challenger_ip": challenger_ip,
	"port": port
	}

	# Snapshot peer_info BEFORE the sync RPC — the RPC serializer stringifies
	# integer keys, which would corrupt our local peer_info if call_local were
	# used.  We build match_info from the clean snapshot instead.
	var peer_snapshot := peer_info.duplicate()

	_sync_all_info.rpc(peer_info)
	
	var match_info = {
	"player1": peer_snapshot.get(challenger_id, peer_snapshot.get(str(challenger_id), {})),
	"player2": peer_snapshot.get(target_id, peer_snapshot.get(str(target_id), {})),
	"host_peer": challenger_id,
	"host_ip": challenger_ip,
	"port": port,
	"opponent": target_id
	}
	await get_tree().process_frame

	if challenger_id == host_id:
		_start_match(match_info, true)
	else:
		_start_match.rpc_id(challenger_id, match_info, true)

	if target_id == host_id:
		_start_match(match_info, false)
	else:
		_start_match.rpc_id(target_id, match_info, false)

	var fp = _get_friend_panel()
	if fp:
		for pending_target in fp.pending_challenges.keys():
			var pending_challenger = fp.pending_challenges[pending_target]
			if pending_target == target_id and pending_challenger == challenger_id:
				continue
			_deliver_rejection.rpc_id(pending_challenger, pending_target)
			fp._deliver_challenge_expired.rpc_id(pending_target, pending_challenger)
		fp.pending_challenges.clear()
	

@rpc("any_peer", "call_local", "reliable")
func reject_challenge(challenger_id:int, rejecter_id: int):
	if not multiplayer.is_server():
		return
	var fp = _get_friend_panel()
	if fp:
		fp.pending_challenges.erase(rejecter_id)
	_deliver_rejection.rpc_id(challenger_id, rejecter_id)
	
@rpc("authority","call_local","reliable")
func _deliver_rejection(rejecter_id: int):
	var fp = _get_friend_panel()
	if fp:
		fp.reset_challenge_button(rejecter_id)

@rpc("authority","reliable")
func _start_match(match_info: Dictionary, am_i_host: bool):

	local_match_data = {
	"match_info": match_info,
	"host": am_i_host
	}
	
	
	if multiplayer.is_server():
		match_ack[multiplayer.get_unique_id()] = true
	else:
		_start_match_ack.rpc_id(1)



@rpc("any_peer","reliable")
func _start_match_ack():

	if !multiplayer.is_server():
		return

	var id = multiplayer.get_remote_sender_id()

	match_ack[id] = true

	print("[HOST] ACK from ", id)

	var challenger = lobby_match_data["challenger"]
	var target = lobby_match_data["target"]

	if challenger == multiplayer.get_unique_id():
		match_ack[challenger] = true

	if target == multiplayer.get_unique_id():
		match_ack[target] = true

	if match_ack.has(challenger) and match_ack.has(target):

		print("[HOST] Both players acknowledged")

		await _send_players_to_match(challenger, target)



func _send_players_to_match(challenger: int, target: int):
	var host_id = multiplayer.get_unique_id()
	var host_is_playing = (challenger == host_id or target == host_id)

	if challenger != host_id:
		_leave_lobby.rpc_id(challenger)
	if target != host_id:
		_leave_lobby.rpc_id(target)

	if host_is_playing:
		await get_tree().create_timer(0.15).timeout

		_host_leaves_for_match()

		_leave_lobby()


func _disconnect_lobby_signals():
	if multiplayer.connected_to_server.is_connected(_on_connected):
		multiplayer.connected_to_server.disconnect(_on_connected)
	if multiplayer.connection_failed.is_connected(_on_failed):
		multiplayer.connection_failed.disconnect(_on_failed)
	if multiplayer.server_disconnected.is_connected(_on_server_disconnected):
		multiplayer.server_disconnected.disconnect(_on_server_disconnected)
	if multiplayer.peer_connected.is_connected(_on_peer_connected):
		multiplayer.peer_connected.disconnect(_on_peer_connected)
	if multiplayer.peer_disconnected.is_connected(_on_peer_disconnected):
		multiplayer.peer_disconnected.disconnect(_on_peer_disconnected)

@rpc("authority","reliable")
func _leave_lobby():

	_disconnect_lobby_signals()

	if peer:
		peer.close()
		peer = null

	multiplayer.multiplayer_peer = null

	var am_i_host = local_match_data["host"]
	var match_info = local_match_data["match_info"]

	var host_ip = match_info["host_ip"]
	var port = match_info["port"]
	match_peer = ENetMultiplayerPeer.new()

	if am_i_host:
		var err = match_peer.create_server(port,2)

		if err != OK:
			print(err)
			return

	else:

		var err = match_peer.create_client(host_ip,port)

		if err != OK:
			print(err)
			return

	multiplayer.multiplayer_peer = match_peer
	
	print("[MATCH] Connected")
	GameManager.current_state = GameManager.GameState.IN_GAME_MULTIPLAYER
	
	# Trigger the scene load and game flow — the match peer is now live.
	if is_instance_valid(GameManager.game_flow_manager):
		GameManager.game_flow_manager._enter_state(GameFlowManager.State.IN_GAME_MULTIPLAYER)

func choose_next_lobby_host(challenger_id: int, accepter_id: int, host_id: int) -> int:
	var candidates: Array[int] = []
	for id in peer_info.keys():
		if id == challenger_id: continue
		if id == accepter_id: continue
		if id == host_id: continue
		candidates.append(id)
	candidates.sort()
	if candidates.is_empty():
		return -1
	return candidates[0]

@rpc("authority", "reliable")
func set_next_host(id:int):
	next_lobby_host = id

func _host_leaves_for_match():
	print("[HOST] Leaving lobby to play in a match")
	broadcasting = false
	if udp_server:
		udp_server.close()
		udp_server = null
	if udp_local:
		udp_local.close()
		udp_local = null
	_disconnect_lobby_signals()
# ── HELPERS ───────────────────────────────────────────────────────────────────
func find_free_match_port() -> int:
	for port in range(MATCH_PORT_START, MATCH_PORT_END + 1):
		var test = ENetMultiplayerPeer.new()

		var err = test.create_server(port, 2)

		if err == OK:
			test.close()
			return port

	return -1

func _get_broadcast_address(local_ip: String) -> String:
	var parts = local_ip.split(".")
	if parts.size() == 4:
		return parts[0] + "." + parts[1] + "." + parts[2] + ".255"
	return "255.255.255.255"

func _get_all_local_ips() -> Array:
	var result = []
	for ip in IP.get_local_addresses():
		# Skip IPv6 addresses and broadcast
		if ":" in ip or ip.ends_with(".255"):
			continue
		# Skip loopback
		if ip.begins_with("127.") or ip == "0.0.0.0":
			continue
		# Skip link-local (169.254.x.x) — these are APIPA addresses with no router
		if ip.begins_with("169.254."):
			continue
		result.append(ip)
	print("[NET] All valid local IPs: ", result, " | Raw: ", IP.get_local_addresses())
	return result

func get_local_ip() -> String:
	var all = _get_all_local_ips()
	if all.is_empty():
		var raw = IP.get_local_addresses()
		print("[NET] ⚠ No LAN IP found! Your device may not be connected to WiFi/LAN.")
		print("[NET] Raw IPs: ", raw)
		# Show raw IPs on screen so we can debug on Android
		var err_popup = GameManager.ui_manager.popup_panel.black_screen_popup
		err_popup.show_label(0)
		err_popup.no_lan_ip_label.text = "No LAN IP detected.\nConnect to same WiFi or Hotspot."
		GameManager.ui_manager.popup_panel.show_popup(PopupPanelController.PopupType.BLACK)
		return ""
	# When multiple IPs exist (e.g. WiFi + VPN adapter), pick the most likely
	# LAN one by preferring 192.168.x.x addresses first, then 10.x, then 172.x.
	var priorities = ["192.168.", "10.", "172.", "100."]
	for prefix in priorities:
		for ip in all:
			if ip.begins_with(prefix):
				print("[NET] Using LAN IP: ", ip, " | All: ", all)
				return ip
	# Fallback: use any valid IP we have
	print("[NET] All: ", all)
	var fallback_popup = GameManager.ui_manager.popup_panel.black_screen_popup
	fallback_popup.show_label(0)
	fallback_popup.no_lan_ip_label.text = "No LAN IP detected.\nConnect to same WiFi or Hotspot."
	GameManager.ui_manager.popup_panel.show_popup(PopupPanelController.PopupType.BLACK)
	return ""

func _explain_error(err: int) -> String:
	match err:
		ERR_ALREADY_IN_USE:    return "Port already in use"
		ERR_CANT_CREATE:       return "Cannot create socket"
		ERR_INVALID_PARAMETER: return "Invalid parameter"
		ERR_UNAVAILABLE:       return "Network unavailable"
		ERR_CONNECTION_ERROR:  return "Connection error"
		12:                    return "ERR_CANT_BIND — port blocked or in use"
		_:                     return "Unknown error: " + str(err)

func _exit_tree():
	broadcasting = false
	if udp_server: udp_server.close()
	if udp_local:  udp_local.close()
	if udp_client: udp_client.close()
