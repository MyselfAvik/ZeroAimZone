extends Node2D
class_name SinglePlayerController

@export var single_player_data: SinglePlayerData
@export var enemyGun: PackedScene
@export var obstacle_list: ObstacleList
var current_level: Node = null
var current_obstacle: ObstacleController = null
var current_arena: ArenaInfo
var playerGun: PackedScene
var player_spawn: Marker2D
var enemy_spawn: Marker2D


var player: SinglePlayerGun
var enemy
var current_round: int
var player_rounds: int = 0
var enemy_rounds: int = 0
var match_coin_reward: int = 0
var arena_name: String = "Tokyo"


func _ready() -> void:
	_ensure_single_player_data()
	match_coin_reward = GameManager.current_match.coin_reward
	current_round = 0

	arena_name = "Arena_%d" % GameManager.current_match.arena_index
	if GameManager.current_match.arena_index == 0: arena_name = "Tokyo"
	elif GameManager.current_match.arena_index == 1: arena_name = "NewYork"
	elif GameManager.current_match.arena_index == 2: arena_name = "Delhi"
	GameAnalysis.start_match(arena_name, -1)

	playerGun = single_player_data.playerGun
	GameManager.in_game_ui.gameplay_panel.reset_round_indicators()
	instantiate_level()

func _ensure_single_player_data() -> void:
	if single_player_data == null:
		return
	if single_player_data.selected_gun_texture == null or single_player_data.selected_fire_sound == null:
		var all_guns_resource: AllGunData = preload("res://ZeroAimZone-Godot/4_Resources/Tres/all_gun_data.tres")
		var gun_idx: int = 0
		var skin_idx: int = 0
		if GameManager.save_manager and GameManager.save_manager.game_data.has("guns_data"):
			var gd = GameManager.save_manager.game_data["guns_data"]
			gun_idx = gd.get("gun_selected_index", 0)
			if gd.has("skin_selected") and gun_idx < gd["skin_selected"].size():
				skin_idx = gd["skin_selected"][gun_idx]
		if all_guns_resource and gun_idx < all_guns_resource.all_guns.size():
			single_player_data.apply_gun(all_guns_resource.all_guns[gun_idx], skin_idx)


func instantiate_level() -> void:
	_create_level()
	_spawn_player()
	_spawn_enemy()
	GameManager.in_game_ui.gameplay_panel.setup_health_bars(player.max_health, enemy.max_health)
	GameManager.in_game_ui.gameplay_panel.setup_gun_bullet_container(player.cartridge, enemy.cartridge)



func _create_level():
	current_level = single_player_data.level[current_round].instantiate()
	add_child(current_level)

	if current_round == 2 and obstacle_list.obstacle_scene[GameManager.current_match.arena_index] != null:
		current_obstacle = obstacle_list.obstacle_scene[GameManager.current_match.arena_index].instantiate() as ObstacleController
		add_child(current_obstacle)

		current_obstacle.initialize(current_level)

		#current_obstacle.initialize(get_obstacle_spawn_points())
	player_spawn = current_level.playerSpawn
	enemy_spawn = current_level.enemySpawn
	var bg = current_level.gameplay_bg as TextureRect
	bg.self_modulate = GameManager.current_match.arena_gameplay_color
	if bg.get_viewport() is SubViewport:
		(bg.get_viewport() as SubViewport).render_target_update_mode = SubViewport.UPDATE_ONCE
	var bg2 = current_level.bg2 as Sprite2D
	if bg2:
		bg2.self_modulate = GameManager.current_match.arena_gameplay_color
	var bouncy_icons = current_level.find_child("BouncyFrame", true, false)
	if bouncy_icons:
		bouncy_icons.modulate = GameManager.current_match.arena_gameplay_color
	ChevronFX.set_arena_color(GameManager.current_match.arena_gameplay_color) 


func _spawn_player():
	player = playerGun.instantiate() as SinglePlayerGun
	player.single_player_data = single_player_data
	player.setup_player_gun()
	player.global_position = player_spawn.global_position
	player.died.connect(_on_gun_died)
	player.health_changed.connect(_on_gun_health_changed)
	add_child(player)


func _spawn_enemy():
	enemy = enemyGun.instantiate()
	enemy.setup_gun(GameManager.enemy_gun_index, GameManager.enemy_skin_index)
	enemy.configure_difficulty(GameManager.save_manager.game_data["player_data"]["level"], GameManager.current_match.entry_fee)
	enemy.global_position = enemy_spawn.global_position
	enemy.died.connect(_on_gun_died)
	enemy.health_changed.connect(_on_gun_health_changed)
	add_child(enemy)

func get_obstacle_spawn_points() -> Array[Marker2D]:
	var points: Array[Marker2D] = []
	var spawn_container = current_level.get_node_or_null("ObstacleSpawnPoints")
	if spawn_container != null:
		for child in spawn_container.get_children():
			if child is Marker2D:
				points.append(child)
	return points


func _on_gun_died(gun) -> void:
	if gun is SinglePlayerGun:
		enemy_win()
	else:
		player_win()


func _on_gun_health_changed(gun, current_health: float, max_health: float) -> void:
	if gun is SinglePlayerGun:
		GameManager.in_game_ui.gameplay_panel.update_player_health(current_health, max_health)
	elif gun.is_in_group("enemy"):
		GameManager.in_game_ui.gameplay_panel.update_enemy_health(current_health, max_health)


func deinstantiate_level() -> void:
	if current_obstacle:
		current_obstacle.stop()
		current_obstacle = null
	for child in get_children():
		child.queue_free()
		current_level = null
		player = null
		enemy = null

func update_rounds(result: bool) -> void:
	GameManager.in_game_ui.gameplay_panel.update_round_result(current_round, result)
	GameAnalysis.complete_round(result, current_round + 1)

	if (result):
		player_rounds = player_rounds + 1
	else:
		enemy_rounds = enemy_rounds + 1

	if (player_rounds == 2 or enemy_rounds == 2):
		var res = 0 if player_rounds == 2 else 1
		show_result(res)
		return

	current_round += 1
	GameAnalysis.start_round(arena_name, -1, current_round + 1)
	GameManager.in_game_ui.popup_panel.show_popup(PopupPanelController.PopupType.ROUND_COUNTDOWN)
	
	deinstantiate_level()
	await GameManager.in_game_ui.popup_panel.round_countdown_popup.start_countdown(current_round, result)
	instantiate_level()
	

func player_win() -> void:
	update_rounds(true)

func enemy_win() -> void:
	update_rounds(false)

func show_result(res: int) -> void:
	var is_player_win = (res == 0)
	var coins = GameManager.current_match.coin_reward if is_player_win else 0
	GameAnalysis.complete_match(is_player_win, coins)

	if res == 0:
		GameManager.in_game_ui.gameplay_result_panel.show_player_win()
	else:
		GameManager.in_game_ui.gameplay_result_panel.show_enemy_win()
	GameManager.progression_manager.reward_for_match(res)
	GameManager.in_game_ui.show_result()
	if res == 0:
		var reward_coin_icon := GameManager.in_game_ui.gameplay_result_panel.reward_section.get_node_or_null("RewardBg/HBoxContainer/Reward1/CoinBulk") as Control
		var coin_tex = preload("res://ZeroAimZone-Godot/3_Assets/Sprites/GameUI/ShopPanel/coin.png")
		GameManager.play_currency_collection(coin_tex, GameManager.current_match.coin_reward, reward_coin_icon, GameManager.in_game_ui.gameplay_result_panel.coin_count_label)
	GameManager.in_game_ui.gameplay_result_panel.enable_enemy_rematch_card()
	call_deferred("queue_free")
