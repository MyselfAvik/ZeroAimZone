class_name MultiplayerManager
extends Node2D
@export var multiplayer_player_data: MultiplayerPlayerData
@onready var spawner: MultiplayerSpawnerController = $MultiplayerSpawner
var level
var player_gun
var player_bullet
var player_start
var enemy_start
var ordered
var instantiatedLevel

var current_round: int = 0
var player_rounds: int = 0
var enemy_rounds: int = 0
var is_match_over: bool = false


var players_data = {
	
}

func _ready() -> void:
	GameManager.in_game_ui.gameplay_panel.reset_round_indicators()
	multiplayer.peer_disconnected.connect(on_disconnect)
	multiplayer.server_disconnected.connect(_on_server_disconnect)
	# Kick off the match — instantiate the level and spawn the guns.
	# _enter_tree has already populated level/player_gun/player_bullet.
	if level != null and not level.is_empty():
		start()
	else:
		push_error("[MultiplayerManager] _ready: level array is empty, cannot start match!")


func _on_server_disconnect() -> void:
	on_disconnect(1)

func on_disconnect(id: int) -> void:
	var interruption_reason = "HostLeft" if not multiplayer.is_server() or id == 1 else "Disconnect"
	GameAnalysis.fail_match(interruption_reason)
	if multiplayer.peer_disconnected.is_connected(on_disconnect):
		multiplayer.peer_disconnected.disconnect(on_disconnect)
	if multiplayer.server_disconnected.is_connected(_on_server_disconnect):
		multiplayer.server_disconnected.disconnect(_on_server_disconnect)

	is_match_over = true
	_disable_all_players()

	if id != multiplayer.get_unique_id():
		var ui = GameManager.in_game_ui
		if is_instance_valid(ui):
			var is_showing_result = ui.active_panels.has(ui.RESULT_PANEL_PATH) and is_instance_valid(ui.active_panels[ui.RESULT_PANEL_PATH]) and ui.active_panels[ui.RESULT_PANEL_PATH].is_visible_in_tree()
			if not is_showing_result:
				show_result(multiplayer.get_unique_id())
			if is_instance_valid(ui.gameplay_result_panel):
				ui.gameplay_result_panel.show_player_left()

	if is_instance_valid(GameManager.ui_manager):
		GameManager.ui_manager.base_panel.friend_panel.reset()

	_cleanup_all_match_nodes()


func _cleanup_all_match_nodes() -> void:
	if is_instance_valid(spawner):
		spawner.release_camera()
		for player in spawner.spawned_players:
			if is_instance_valid(player) and not player.is_queued_for_deletion():
				_mute_player(player)
				player.queue_free()
		spawner.spawned_players.clear()

	for player_node in get_tree().get_nodes_in_group("multiplayer_players"):
		if is_instance_valid(player_node) and not player_node.is_queued_for_deletion():
			_mute_player(player_node)
			player_node.queue_free()

	_cleanup_projectiles()

	if is_instance_valid(instantiatedLevel) and not instantiatedLevel.is_queued_for_deletion():
		instantiatedLevel.queue_free()
		instantiatedLevel = null


func _cleanup_projectiles() -> void:
	for projectile in get_tree().get_nodes_in_group("multiplayer_projectiles"):
		if is_instance_valid(projectile) and not projectile.is_queued_for_deletion():
			projectile.queue_free()


func _disable_all_players() -> void:
	if is_instance_valid(spawner):
		for player in spawner.spawned_players:
			if is_instance_valid(player):
				player.set_physics_process(false)
				player.set_process_input(false)
				player.set_process_unhandled_input(false)
				if "can_shoot" in player:
					player.can_shoot = false

func _mute_player(player: Node) -> void:
	player.set_physics_process(false)
	if player.has_node("MultiplayerSynchronizer"):
		player.get_node("MultiplayerSynchronizer").public_visibility = false
	

func _enter_tree() -> void:
	GameManager.multiplayer_manager = self
	# Read match data from the persistent network handler singleton, NOT from
	# GameFlowManager — that node lives in MainMenu and is freed before this
	# _enter_tree() fires during the scene transition.
	if is_instance_valid(GameManager.network_handler):
		players_data = GameManager.network_handler.local_match_data.get("match_info", {})
	else:
		players_data = GameManager.cached_match_info
	if multiplayer_player_data == null:
		push_error("multiplayer: level is not assigned in the Inspector!")
		return
	level = multiplayer_player_data.level
	player_gun = multiplayer_player_data.playerGun
	player_bullet = multiplayer_player_data.multiplayerBullet
	
	
var client_loaded = false

@rpc("any_peer", "call_local", "reliable")
func client_ready_for_spawning():
	if multiplayer.is_server():
		client_loaded = true

@rpc("authority", "call_local", "unreliable")
func ping_client_ready():
	if not multiplayer.is_server():
		client_ready_for_spawning.rpc_id(1)

func _exit_tree() -> void:
	if multiplayer.peer_disconnected.is_connected(on_disconnect):
		multiplayer.peer_disconnected.disconnect(on_disconnect)
	if multiplayer.server_disconnected.is_connected(_on_server_disconnect):
		multiplayer.server_disconnected.disconnect(_on_server_disconnect)
	GameManager.multiplayer_manager = null

func start_rematch() -> void:
	if multiplayer.multiplayer_peer == null or (multiplayer.is_server() and multiplayer.get_peers().is_empty()):
		on_disconnect(0)
		return

	is_match_over = false
	current_round = 0
	player_rounds = 0
	enemy_rounds = 0
	client_loaded = false
	
	SceneManager.show_transition_loading()

	if multiplayer.is_server():
		deinstantiate_level.rpc()
		await get_tree().create_timer(0.25).timeout
		if is_match_over or multiplayer.multiplayer_peer == null or multiplayer.get_peers().is_empty():
			SceneManager.hide_transition_loading()
			on_disconnect(0)
			return
		start()
	else:
		if is_instance_valid(instantiatedLevel):
			instantiatedLevel.queue_free()
			instantiatedLevel = null
		await get_tree().create_timer(0.25).timeout
		if is_match_over or multiplayer.multiplayer_peer == null:
			SceneManager.hide_transition_loading()
			on_disconnect(1)
			return
		start()

func start() -> void:
	if current_round == 0:
		GameAnalysis.start_match("LAN_Play", -1)
	else:
		GameAnalysis.start_round("LAN_Play", -1, current_round + 1)
	if is_match_over:
		return

	if multiplayer.multiplayer_peer == null:
		on_disconnect(0)
		return

	Initialization()

	if multiplayer.is_server():
		if multiplayer.get_peers().is_empty():
			print("[MM] Opponent not connected — aborting match start")
			on_disconnect(0)
			return

		print("[MM] Waiting for client to load scene...")
		var attempts = 0
		while not client_loaded and attempts < 100:
			if is_match_over or multiplayer.multiplayer_peer == null or multiplayer.get_peers().is_empty():
				print("[MM] Client disconnected while waiting for handshake")
				on_disconnect(0)
				return
			if attempts % 2 == 0:
				ping_client_ready.rpc()
			await get_tree().create_timer(0.1).timeout
			attempts += 1

		if not client_loaded or multiplayer.get_peers().is_empty():
			print("[MM] Handshake timed out or peer disconnected")
			on_disconnect(0)
			return

		var peers = multiplayer.get_peers()
		print("[MM] connected peers: ", peers)
		ordered = peers.duplicate()
		ordered.insert(0, 1)
	
		print("[MM] spawn order: ", ordered)
		
		spawner.spawn_guns(ordered, player_start, enemy_start)
		setup_health.rpc(ordered[0], ordered[1])
		setup_ammo.rpc(ordered[0], ordered[1])
		SceneManager.hide_transition_loading()
	else:
		client_ready_for_spawning.rpc_id(1)
		SceneManager.hide_transition_loading()
func Initialization() -> void:
	var round_index = clamp(current_round, 0, level.size() - 1)
	instantiatedLevel = level[round_index].instantiate()
	print("level instantiated!!!")
	player_start = instantiatedLevel.get_node("playerSpawn")
	enemy_start = instantiatedLevel.get_node("enemySpawn")

	var match_data = {}
	if is_instance_valid(GameManager.network_handler):
		match_data = GameManager.network_handler.local_match_data

	var round_color = Color(match_data.get("arena_gameplay_color", "#de587e"))

	var bg = instantiatedLevel.gameplay_bg as TextureRect
	bg.self_modulate = round_color
	if bg.get_viewport() is SubViewport:
		(bg.get_viewport() as SubViewport).render_target_update_mode = SubViewport.UPDATE_ONCE
	var bg2 = instantiatedLevel.get_node_or_null("bg2") as Sprite2D
	if bg2:
		bg2.self_modulate = round_color

	add_child(instantiatedLevel)

	var bouncy_icons = instantiatedLevel.find_child("BouncyFrame", true, false)
	if bouncy_icons:
		bouncy_icons.queue_free()

	# 2. Convert bouncy walls to normal impact walls for Multiplayer
	for node in get_tree().get_nodes_in_group("bouncy_wall"):
		# Make sure we only affect the walls in this specific level
		if node.owner == instantiatedLevel or node.get_parent() == instantiatedLevel:
			node.remove_from_group("bouncy_wall")
			node.add_to_group("impact_wall")

@rpc("authority", "call_local", "reliable")
func update_round(death_id: int):
	if is_match_over:
		return

	var is_player_win = (death_id != multiplayer.get_unique_id())
	GameManager.in_game_ui.gameplay_panel.update_round_result(current_round, is_player_win)
	GameAnalysis.complete_round(is_player_win, current_round + 1)

	if is_player_win:
		player_rounds = player_rounds + 1
	else:
		enemy_rounds = enemy_rounds + 1

	if multiplayer.is_server():
		if player_rounds >= 2 or enemy_rounds >= 2:
			var winner_peer_id = multiplayer.get_unique_id() if player_rounds >= 2 else death_id
			show_result.rpc(winner_peer_id)
			return
		deinstantiate_level.rpc()
	else:
		if player_rounds >= 2 or enemy_rounds >= 2:
			return

	client_loaded = false
	current_round += 1
	GameManager.in_game_ui.popup_panel.show_popup(PopupPanelController.PopupType.ROUND_COUNTDOWN)
	await GameManager.in_game_ui.popup_panel.round_countdown_popup.start_countdown(current_round, death_id != multiplayer.get_unique_id())
	start()


@rpc("authority", "call_local", "reliable")
func setup_health(p1_id: int, p2_id: int) -> void:
	var p1: MultiplayerGun = await _wait_for_player(p1_id)
	var p2: MultiplayerGun = await _wait_for_player(p2_id)
	if p1 == null or p2 == null:
		push_warning("[MM] setup_health: players not found yet")
		return
	GameManager.in_game_ui.gameplay_panel.setup_health_bars(p1.max_health, p2.max_health)

@rpc("authority", "call_local", "reliable")
func setup_ammo(p1_id: int, p2_id: int) -> void:
	var p1: MultiplayerGun = await _wait_for_player(p1_id)
	var p2: MultiplayerGun = await _wait_for_player(p2_id)
	if p1 == null or p2 == null:
		push_warning("[MM] setup_bullet: players not found yet")
		return
	GameManager.in_game_ui.gameplay_panel.setup_gun_bullet_container(p1.max_cartridge, p2.max_cartridge)

func _wait_for_player(id: int) -> MultiplayerGun:
	if not is_instance_valid(spawner):
		return null
	var p: MultiplayerGun = spawner.get_player(id)
	var max_frames = 120
	while p == null and max_frames > 0:
		await get_tree().process_frame
		if not is_instance_valid(spawner) or not is_inside_tree():
			return null
		p = spawner.get_player(id)
		max_frames -= 1
	return p


@rpc("authority", "call_local", "reliable")
func deinstantiate_level():
	if is_instance_valid(spawner):
		spawner.release_camera()
		if multiplayer.is_server():
			for player in spawner.spawned_players:
				if is_instance_valid(player) and not player.is_queued_for_deletion():
					player.queue_free()
		spawner.spawned_players.clear()

	_cleanup_projectiles()

	if is_instance_valid(instantiatedLevel) and not instantiatedLevel.is_queued_for_deletion():
		instantiatedLevel.queue_free()
		instantiatedLevel = null

@rpc("authority", "call_local", "reliable")
func show_result(winner_peer_id: int) -> void:
	is_match_over = true
	_disable_all_players()
	var did_player_win: bool = (winner_peer_id == multiplayer.get_unique_id())
	GameAnalysis.complete_match(did_player_win)
	if did_player_win:
		GameManager.in_game_ui.gameplay_result_panel.show_player_win()
	else:
		GameManager.in_game_ui.gameplay_result_panel.show_enemy_win()

	if GameManager.progression_manager:
		GameManager.progression_manager.add_xp(30)

	GameManager.in_game_ui.show_result()


func disconnect_player():
	is_match_over = true
	if multiplayer.multiplayer_peer:
		multiplayer.multiplayer_peer.close()
		multiplayer.multiplayer_peer = null

	_cleanup_all_match_nodes()

	# Reset local state
	players_data.clear()
	current_round = 0
	player_rounds = 0
	enemy_rounds = 0

	call_deferred("queue_free")
