class_name QuitPopupController
extends BasePopupController

@export var exit_btn: Button
@export var continue_btn: Button

func _ready() -> void:
	super._ready()
	if exit_btn and not exit_btn.pressed.is_connected(_on_exit_pressed):
		exit_btn.pressed.connect(_on_exit_pressed)
	if continue_btn and not continue_btn.pressed.is_connected(_on_continue_pressed):
		continue_btn.pressed.connect(_on_continue_pressed)

func _on_exit_pressed() -> void:
	if GameManager.current_state == GameManager.GameState.IN_GAME_SINGLEPLAYER:
		if GameManager and GameManager.save_manager:
			GameManager.save_manager.record_match_result(false)
		GameAnalysis.fail_match("Home")
		GameAnalysis.track_screen_switch("Gameplay", "Arena")
		if GameManager:
			GameManager.target_main_menu_panel = UIManager.PanelType.ARENA
	else:
		if GameManager.multiplayer_manager:
			GameManager.multiplayer_manager.disconnect_player()
		GameAnalysis.fail_match("Home")
		GameAnalysis.track_screen_switch("Gameplay", "Home")
		if GameManager:
			GameManager.target_main_menu_panel = UIManager.PanelType.BASE
			GameManager.target_base_sub_panel = BasePanelController.BasePanelType.FRIEND

	if AdManager:
		AdManager.on_game_completed()
	SceneManager.load_scene("res://ZeroAimZone-Godot/0_Scenes/MainMenu.tscn")
	hide_popup()

func _on_continue_pressed() -> void:
	hide_popup()
