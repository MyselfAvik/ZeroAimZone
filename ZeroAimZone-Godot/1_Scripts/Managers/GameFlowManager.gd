class_name GameFlowManager
extends Node2D

enum State {LOADING, MAIN_MENU, IN_GAME_SINGLEPLAYER, IN_GAME_MULTIPLAYER}


@export var single_player_data: Resource


var info
var instantiatedSinglePlayer: Node2D
var instantiatedMultiPlayer: Node2D
var current_state: State = State.MAIN_MENU
func _enter_tree() -> void:
	GameManager.game_flow_manager = self
func _ready() -> void:
	pass

func _enter_state(state: State) -> void:
	match state:
		State.MAIN_MENU:
			current_state = State.MAIN_MENU
			if AudioPlayer:
				AudioPlayer.start_bg_music(AudioPlayer.SOUND_DB.main_theme)
		State.IN_GAME_SINGLEPLAYER:
			current_state = State.IN_GAME_SINGLEPLAYER
			start_game_singleplayer()
			
		State.IN_GAME_MULTIPLAYER:
			current_state = State.IN_GAME_MULTIPLAYER
			info = GameManager.network_handler.local_match_data["match_info"]
			GameManager.cached_peer_info = GameManager.network_handler.peer_info.duplicate(true)
			GameManager.cached_match_info = info.duplicate(true)

			var am_i_host = GameManager.network_handler.local_match_data["host"]
			var opponent_info = info["player2"] if am_i_host else info["player1"]
			var player_info = info["player2"] if not am_i_host else info["player1"]
			
			GameManager.current_match.enemy_gun_index=opponent_info["gun"]
			GameManager.current_match.enemy_skin_index=opponent_info["skin"]
			GameManager.current_match.player_gun_index=player_info["gun"]
			GameManager.current_match.player_skin_index=player_info["skin"]
			GameManager.current_match.entry_fee = 0
			GameManager.current_match.coin_reward = 0
			GameManager.current_match.arena_gameplay_color=Color(0, 0, 0, 1)
			
			GameAnalysis.track_screen_switch("Home", "Matchmaking")
			GameManager.change_panel(UIManager.PanelType.MATCHMAKING)
			GameManager.ui_manager.popup_panel.hide_popup()
			GameManager.ui_manager.match_making_panel.setup_name_avatar(
				opponent_info["name"],
				opponent_info["avatar"],
				opponent_info["frame"]
				)

func _run_loading() -> void:
	await get_tree().create_timer(0.5).timeout # placeholder for asset preload
	_enter_state(State.MAIN_MENU)


func start_game_singleplayer() -> void:
	AudioPlayer.play_sfx(AudioPlayer.SOUND_DB.game_start)
	print("Starting Singleplayer mode (handled by GameScene)")

func start_game_multiplayer() -> void:
	AudioPlayer.play_sfx(AudioPlayer.SOUND_DB.game_start)
	SceneManager.load_scene("res://ZeroAimZone-Godot/0_Scenes/GameScene.tscn")

func return_to_menu() -> void:
	_enter_state(State.MAIN_MENU)
