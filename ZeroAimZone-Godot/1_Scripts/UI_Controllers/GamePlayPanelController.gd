class_name GamePlayPanelController
extends Control

@export var ingame_setting_panel:Panel
@export var player_health_bar: TextureProgressBar
@export var enemy_health_bar: TextureProgressBar
@export var player_round_container: HBoxContainer
@export var enemy_round_container: HBoxContainer
@export var round_win_texture: Texture2D
@export var round_lose_texture: Texture2D
@export var round_normal_texture: Texture2D
@export var bullet_empty_texture:Texture2D
@export var bullet_filled_texture:Texture2D

@export var player_bullet_container:VBoxContainer
@export var enemy_bullet_container:VBoxContainer

@export var vibrate_button:  TextureButton
@export var sound_button:  TextureButton
@export var music_button:  TextureButton
@export var player_avatar: TextureRect
@export var enemy_avatar: TextureRect
@export var player_name_label: Label
@export var enemy_name_label: Label

@export var vibrate_icon: Array[Texture2D]
@export var sound_icon: Array[Texture2D]
@export var music_icon: Array[Texture2D]
@export var enabled_setting_button_texture: Texture2D

@export var coin_bulk: Control
@export var total_amount: Control

@export var enemy_frame:TextureRect
@export var player_frame:TextureRect
@export var enemy_frame_icon:TextureRect
@export var player_frame_icon:TextureRect

var _default_button_textures: Dictionary = {}


func _ready() -> void:
	setup_match_profiles()
	reset_round_indicators()
	var settings = GameManager.save_manager.game_data["game_settings"] if GameManager.save_manager else {}
	_setup_toggle_button(vibrate_button, vibrate_icon, "haptic_on", settings.get("haptic_on", true))
	_setup_toggle_button(sound_button, sound_icon, "sound_on", settings.get("sound_on", true))
	_setup_toggle_button(music_button, music_icon, "music_on", settings.get("music_on", true))


func setup_health_bars(player_max_health: float, enemy_max_health: float) -> void:
	_setup_health_bar(player_health_bar, player_max_health)
	_setup_health_bar(enemy_health_bar, enemy_max_health)

func setup_gun_bullet_container(player_mag,opponent_mag):
	setup_bullet_container(player_bullet_container,player_mag)
	setup_bullet_container(enemy_bullet_container,opponent_mag)
	

func setup_bullet_container(container: VBoxContainer, _size: int) -> void:
	for child in container.get_children():
		child.queue_free()

	for i in range(_size):
		var image := TextureRect.new()
		image.texture = bullet_filled_texture
		image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		image.size_flags_vertical = Control.SIZE_EXPAND_FILL

		if container == enemy_bullet_container:
			image.flip_h = true
		else:
			image.flip_h = false

		container.add_child(image)


func update_bullet_container(container:VBoxContainer, mag_amount:int):
	var children = container.get_children()
	for i in range(children.size()):
		var child = children[i]
		var tex = bullet_filled_texture if mag_amount > i else bullet_empty_texture
		if child.texture != tex:
			child.texture = tex


func update_player_bullet(bullet:int):
	update_bullet_container(player_bullet_container,bullet)

func update_enemy_bullet(bullet:int):
	update_bullet_container(enemy_bullet_container,bullet)

func update_player_health(current_health: float, max_health: float) -> void:
	_update_health_bar(player_health_bar, current_health, max_health)


func update_enemy_health(current_health: float, max_health: float) -> void:
	_update_health_bar(enemy_health_bar, current_health, max_health)


func setup_match_profiles() -> void:
	var match_data = GameManager.current_match
	player_name_label.text = match_data.player_name
	enemy_name_label.text = match_data.enemy_name
	player_avatar.texture = match_data.player_avatar
	enemy_avatar.texture = match_data.enemy_avatar
	player_frame.texture=match_data.player_frame
	enemy_frame.texture=match_data.enemy_frame
	player_frame_icon.texture=match_data.player_frame_icon
	enemy_frame_icon.texture=match_data.enemy_frame_icon


func reset_round_indicators() -> void:
	_set_all_round_indicators(player_round_container, round_normal_texture)
	_set_all_round_indicators(enemy_round_container, round_normal_texture)


func update_round_result(round_index: int, player_won: bool) -> void:
	if is_instance_valid(GameManager.in_game_ui) and is_instance_valid(GameManager.in_game_ui.popup_panel) and is_instance_valid(GameManager.in_game_ui.popup_panel.quit_popup) and GameManager.in_game_ui.popup_panel.quit_popup.visible:
		GameManager.in_game_ui.popup_panel.quit_popup.hide_popup()
	_set_round_indicator(player_round_container, round_index, round_win_texture if player_won else round_lose_texture)
	_set_round_indicator(enemy_round_container, round_index, round_lose_texture if player_won else round_win_texture)


func _setup_health_bar(health_bar: TextureProgressBar, max_health: float) -> void:
	if health_bar == null:
		return

	health_bar.min_value = 0
	health_bar.max_value = max_health
	health_bar.value = max_health


func _update_health_bar(health_bar: TextureProgressBar, current_health: float, max_health: float) -> void:
	if health_bar == null:
		return

	health_bar.max_value = max_health
	health_bar.value = clampf(current_health, health_bar.min_value, health_bar.max_value)


func _set_all_round_indicators(round_container: HBoxContainer, texture: Texture2D) -> void:
	if round_container == null:
		return

	for child in round_container.get_children():
		if child is TextureRect:
			child.texture = texture


func _set_round_indicator(round_container: HBoxContainer, round_index: int, texture: Texture2D) -> void:
	if round_container == null:
		return
	if round_index < 0 or round_index >= round_container.get_child_count():
		return

	var child = round_container.get_child(round_index)
	if child is TextureRect:
		child.texture = texture

func _setup_toggle_button(button: TextureButton, icons: Array[Texture2D], setting_key: String, initial_state: bool) -> void:
	if button == null or icons.size() < 2:
		return
	_default_button_textures[button] = button.texture_normal
	button.toggle_mode = true
	button.set_pressed_no_signal(initial_state)
	_update_button_icon(button, icons)
	button.toggled.connect(func(pressed: bool) -> void:
		_on_button_toggled(button, icons, setting_key, pressed)
	)


func _on_button_toggled(button: TextureButton, icons: Array[Texture2D], setting_key: String, pressed: bool) -> void:
	_update_button_icon(button, icons)
	EventBus.setting_changed.emit(setting_key, pressed)


func _update_button_icon(button: TextureButton, icons: Array[Texture2D]) -> void:
	var texture_icon := button.get_node_or_null("TextureRect") as TextureRect
	if texture_icon:
		texture_icon.texture = icons[1] if button.button_pressed else icons[0]
	_update_button_background(button)


func _update_button_background(button: TextureButton) -> void:
	if button.button_pressed and enabled_setting_button_texture:
		button.texture_normal = enabled_setting_button_texture
	elif _default_button_textures.has(button):
		button.texture_normal = _default_button_textures[button]

func _on_ingame_setting_pressed() -> void:
	var settings_are_open := not ingame_setting_panel.visible
	ingame_setting_panel.visible = settings_are_open


func _on_quit_game_button_pressed() -> void:
	_on_ingame_setting_pressed()
	
	if not is_instance_valid(GameManager.in_game_ui) or not is_instance_valid(GameManager.in_game_ui.popup_panel):
		return
		
	if GameManager.current_state == GameManager.GameState.IN_GAME_SINGLEPLAYER:
		GameManager.in_game_ui.popup_panel.show_popup(PopupPanelController.PopupType.QUIT)
	else:
		GameAnalysis.fail_match("Home")
		GameAnalysis.track_screen_switch("Gameplay", "Home")
		if GameManager.multiplayer_manager:
			GameManager.multiplayer_manager.disconnect_player()
		if AdManager:
			AdManager.on_game_completed()
		if GameManager:
			GameManager.target_main_menu_panel = UIManager.PanelType.BASE
			GameManager.target_base_sub_panel = BasePanelController.BasePanelType.FRIEND
		SceneManager.load_scene("res://ZeroAimZone-Godot/0_Scenes/MainMenu.tscn")
