class_name MatchMakingController
extends Control
 
 
@export var opponent_card: Control = null
@export var wait_time: int = 3
 
@export var total_coin_image: TextureRect
@export var total_amount_label: Label
@export var enemy_coin_image: TextureRect
@export var enemy_coin_label: Label
@export var player_coin_label: Label
@export var player_coin_icon: TextureRect
@export var enemy_coin_icon: TextureRect
@export var player_coin_particles: CPUParticles2D
@export var enemy_coin_particles: CPUParticles2D
@export var timer: Timer
@export var timer_text: Label
@export var vs_icon: Label
@export var cancelBtn: TextureButton
@export var coin_count_label: Label
@export var diamond_count_label: Label
@export var premium_currency_effect_script: Script
@export var player_name_label: Label
@export var enemy_name_label: Label
@export var player_frame_icon: TextureRect
@export var enemy_frame_icon: TextureRect
@export var player_frame: TextureRect
@export var enemy_frame: TextureRect
@export var enemy_avatar: TextureRect
@export var player_avatar: TextureRect
@export var player_coin_image: TextureRect
@export var arena_logo: TextureRect
@export var room_title: TextureRect
@export var matchmaking_search_sound: AudioStream
@export var coin_collection_sound: AudioStream

@export var oppo_frame: TextureRect
@export var tip_label: Label

@export var avatar_frame_res: AvatarFrameList
 
@export_file("*.json")
var random_name_file_path: String
var avatar_textures: Array[Texture]

const GAME_TIPS: Array[String] = [
	"Tip: Running out of health will cause you to die.",
	"Tip: Enemies will shoot at you if they want to hit you.",
	"Tip: You cannot shoot your gun if you do not have any bullets.",
	"Tip: Winning the match requires you to beat the opponent.",
	"Tip: Bullets will travel in the direction that you are aiming.",
	"Tip: Standing still makes you a target that does not move.",
	"Tip: Taking damage from an enemy will decrease your health.",
	"Tip: If you see an enemy, they are currently there."
]
var origin_y
var isSearching: bool = false
var searchingLabel: Label
var opponent_avatar: TextureRect
var opponent_label: Label
var opponent_label2: Label
var opponent_label3: Label
var timer_value: int = 3
var is_timer_on: bool = false
var time_accumulator: float = 0.0
var loading_tween: Tween
var tween: Tween
var search_dots := 0
var search_request_id := 0
var entry_fee_paid := false
var coin_collection_tween: Tween
var coin_animation_id := 0
var is_rematch_flow: bool = false
var search_audio_player: AudioStreamPlayer
var search_audio_players: Array[AudioStreamPlayer] = []
var search_audio_loop_id := 0
var search_music_is_ducked := false
 
const COIN_EFFECT_DURATION := 0.82
const COIN_GRAVITY := 1200.0
 
 
const COIN_FLIGHT_DURATION := 0.7
const COIN_ARC_HEIGHT := 550.0
const SEARCH_SOUND_OVERLAP_SECONDS := 0.04


func _ready() -> void:
	searchingLabel = enemy_name_label
	opponent_avatar = enemy_avatar
	search_audio_player = AudioStreamPlayer.new()
	if AudioServer.get_bus_index("SFX") != -1:
		search_audio_player.bus = "SFX"
	add_child(search_audio_player)
	search_audio_players.append(search_audio_player)
	var second_search_audio_player := AudioStreamPlayer.new()
	if AudioServer.get_bus_index("SFX") != -1:
		second_search_audio_player.bus = "SFX"
	add_child(second_search_audio_player)
	search_audio_players.append(second_search_audio_player)
	await RenderingServer.frame_post_draw
	avatar_textures = avatar_frame_res.avatar_list
	refresh_player_profile()
   
	if is_instance_valid(GameManager.ui_manager) and GameManager.ui_manager.base_panel:
		GameManager.ui_manager.base_panel.profile_panel.profile_avatar_frame_updated.connect(refresh_player_profile)
	opponent_avatar.pivot_offset = opponent_avatar.size / 2.0
	origin_y = opponent_avatar.position.y
	update_currency()
	if GameManager.save_manager and not GameManager.save_manager.currency_updated.is_connected(update_currency):
		GameManager.save_manager.currency_updated.connect(update_currency)

	_add_premium_effect(coin_count_label)
	_add_premium_effect(diamond_count_label)
	update_random_tip()

func update_random_tip() -> void:
	var label := tip_label
	if label == null:
		label = get_node_or_null("ArenaPanel/Bg/SafeArea/HBoxContainer/MarginContainer/Control/VBoxContainer/Tip/TextureRect/Label") as Label
	if label:
		label.text = GAME_TIPS.pick_random()

func _ensure_references() -> void:
	if searchingLabel == null and enemy_name_label != null:
		searchingLabel = enemy_name_label
	if opponent_avatar == null and enemy_avatar != null:
		opponent_avatar = enemy_avatar

func _enter_tree() -> void:
	if vs_icon:
		vs_icon.visible = true
	if timer_text:
		timer_text.visible = false

func _add_premium_effect(label: Label) -> void:
	if label and label.get_parent() and premium_currency_effect_script:
		var effect = premium_currency_effect_script.new()
		label.get_parent().add_child(effect)

 
func update_currency() -> void:
	if diamond_count_label:
		diamond_count_label.text = GameManager.format_number(GameManager.save_manager.game_data["currency"]["Diamonds"])
	if coin_count_label:
		coin_count_label.text = GameManager.format_number(GameManager.save_manager.game_data["currency"]["Coins"])
 
 
func set_match_coin_amounts(entry_fee: int, reward_amount: int) -> void:
	player_coin_label.text = str(entry_fee)
	enemy_coin_label.text = str(entry_fee)
	total_amount_label.text = str(reward_amount)
 
func set_arena_texture(texture: Texture2D) -> void:
	arena_logo.texture = texture
 
func _pay_entry_fee_if_needed() -> bool:
	if entry_fee_paid:
		return true
 
	# Multiplayer / Private Room matches do not have an entry fee
	if GameManager and GameManager.game_flow_manager and GameManager.game_flow_manager.current_state == GameFlowManager.State.IN_GAME_MULTIPLAYER:
		entry_fee_paid = true
		return true

	var entry_fee := GameManager.current_match.entry_fee
	if entry_fee <= 0:
		return true
 
	if not GameManager.save_manager.use_coin(entry_fee):
		push_warning("Not enough coins for this match's entry fee.")
		return false

	var arena_name = GameManager.get_current_arena_name() if GameManager else "Tokyo"
	GameAnalysis.track_economy_event(GameAnalysis.RESOURCE_FLOW_TYPE_SINK, "Coins", float(entry_fee), "ArenaEntryFee", arena_name)
	entry_fee_paid = true
	update_currency()
	return true
 
 
func _confirm_opponent_selected() -> bool:
	if _pay_entry_fee_if_needed():
		return true

 
	# An opponent was found, but the player can no longer afford the entry fee.
	# Return to the arena without starting the match or charging any coins.
	GameAnalysis.track_screen_switch("Matchmaking", "Arena")
	GameManager.ui_manager.enable_panel(GameManager.ui_manager.PanelType.ARENA)
	return false
 
func _process(delta: float) -> void:
	if not is_visible_in_tree():
		search_dots = 0
		return
   
	time_accumulator += delta
 
	if isSearching and time_accumulator >= 1:
		search_dots = (search_dots + 1) % 4
		searchingLabel.text = "Searching" + ".".repeat(search_dots)
   
	if is_timer_on and time_accumulator >= 1.0:
		timer_value -= 1
		timer_text.text = str(timer_value)
	if time_accumulator >= 1.0:
		time_accumulator = 0.0
 
func setup_name_avatar(enemy_name: String, enemy_avatar_idx: int, enemy_frame_idx: int):
	enemy_name_label.text = enemy_name
	opponent_avatar.texture = avatar_textures[enemy_avatar_idx]
	oppo_frame.texture = avatar_frame_res.frame_list[enemy_frame_idx]
	if enemy_frame_idx > 0 and enemy_frame_idx - 1 < avatar_frame_res.frame_icon_list.size():
		enemy_frame_icon.texture = avatar_frame_res.frame_icon_list[enemy_frame_idx - 1]
	else:
		enemy_frame_icon.texture = null
	# Multiplayer supplies the opponent details after the matchmaking screen opens.
	if is_visible_in_tree():
		if _confirm_opponent_selected():
			_stop_matchmaking_search_sound()
 
 
func refresh_player_profile() -> void:
	if not avatar_frame_res or not player_avatar:
		return
 
	var player_data: Dictionary = GameManager.save_manager.game_data["player_data"]
	var avatar_index := int(player_data.get("profile_pic_index", 0))
	var frame_index := int(player_data.get("profile_frame_index", 0))
	player_avatar.texture = avatar_frame_res.avatar_list[avatar_index]
	player_frame.texture = avatar_frame_res.frame_list[frame_index]
	if frame_index > 0 and frame_index - 1 < avatar_frame_res.frame_icon_list.size():
		player_frame_icon.texture = avatar_frame_res.frame_icon_list[frame_index - 1]
	else:
		player_frame_icon.texture = null
	player_name_label.text = player_data["name"]

 
func _on_visibility_changed() -> void:
	search_request_id += 1
	_ensure_references()
	if is_visible_in_tree():
		update_random_tip()
		is_rematch_flow = GameManager.is_rematch
		if arena_logo:
			GameManager.custom_animation._scale_anim(arena_logo, 0.3)
		isSearching = true
		refresh_player_profile()
		var request_id := search_request_id
		if timer:
			timer.wait_time = wait_time
		if timer_text:
			timer_text.text = str(wait_time)
	   

		await RenderingServer.frame_post_draw
		if opponent_avatar:
			opponent_avatar.pivot_offset = opponent_avatar.size / 2.0
		if player_coin_image:
			player_coin_image.visible = true
		
		if GameManager.current_state == GameManager.GameState.IN_GAME_SINGLEPLAYER:
			_enter_singleplayer_matchmaking(request_id)
		else:
			_enter_multiplayer_matchmaking()
	else:
		_reset_matchmaking()


func _enter_singleplayer_matchmaking(request_id: int):
	_ensure_references()
	if room_title:
		room_title.visible = false
	if arena_logo:
		arena_logo.visible = true

	if !GameManager.is_rematch:
		if searchingLabel:
			searchingLabel.text = "Searching"
		_play_matchmaking_search_sound()
		_scroll_and_pick_avatar(request_id)
		GameManager.set_enemy_gun_info()
	else:
		if enemy_name_label:
			enemy_name_label.text = GameManager.current_match.enemy_name
		if opponent_avatar:
			opponent_avatar.texture = GameManager.current_match.enemy_avatar
		if oppo_frame:
			oppo_frame.texture = GameManager.current_match.enemy_frame
			oppo_frame.visible = true
		if enemy_frame_icon:
			enemy_frame_icon.texture = GameManager.current_match.enemy_frame_icon
			enemy_frame_icon.visible = true
		if opponent_avatar:
			opponent_avatar.z_index = 1
			if origin_y != null:
				opponent_avatar.position.y = origin_y
			opponent_avatar.modulate.a = 1.0

		if not _confirm_opponent_selected():
			return
		isSearching = false
		is_timer_on = true
		if timer:
			timer.start()
		if vs_icon:
			vs_icon.visible = false
		if timer_text:
			timer_text.visible = true
		if cancelBtn:
			cancelBtn.visible = false
		_show_match_coins()
		GameManager.is_rematch = false

func _enter_multiplayer_matchmaking():
	_ensure_references()
	_play_matchmaking_search_sound()
	if arena_logo:
		arena_logo.visible = false
	if room_title:
		room_title.visible = true
	if oppo_frame:
		oppo_frame.visible = true
	if opponent_avatar:
		opponent_avatar.z_index = 1
	if enemy_frame_icon:
		enemy_frame_icon.visible = true
	isSearching = false
	is_timer_on = true
	if timer:
		timer.start()
	if vs_icon:
		vs_icon.visible = false
	if timer_text:
		timer_text.visible = true
	if cancelBtn:
		cancelBtn.visible = false
	if player_coin_image:
		player_coin_image.visible = false


func _reset_matchmaking():
	is_rematch_flow = false
	_ensure_references()
	_stop_matchmaking_search_sound()
	_cancel_coin_collection_animation()
	if is_instance_valid(GameManager.ui_manager) and is_instance_valid(GameManager.ui_manager.base_panel) and is_instance_valid(GameManager.ui_manager.base_panel.friend_panel):
		GameManager.ui_manager.base_panel.friend_panel.cancel_all_pending_challenges()
	if oppo_frame:
		oppo_frame.visible = false
	if enemy_frame_icon:
		enemy_frame_icon.visible = false
	entry_fee_paid = false
	timer_value = wait_time
	time_accumulator = 0.0
	isSearching = false
	if opponent_avatar != null:
		if origin_y != null:
			opponent_avatar.position.y = origin_y
		opponent_avatar.z_index = 0

	if cancelBtn:
		cancelBtn.visible = true
	if vs_icon:
		vs_icon.visible = true
	if timer_text:
		timer_text.visible = false
	if searchingLabel:
		searchingLabel.visible = true
	if tween != null:
		tween.kill()
	if enemy_coin_label:
		enemy_coin_label.visible = false
	if total_coin_image:
		total_coin_image.visible = false
	if total_amount_label:
		total_amount_label.visible = false
	if enemy_coin_image:
		enemy_coin_image.visible = false

func _scroll_and_pick_avatar(request_id: int) -> void:
	if avatar_textures.is_empty():
		return
 
	var final_index := randi() % avatar_textures.size()
   
	var repeats := 20
 
	for i in repeats:
		var texture := avatar_textures[i % avatar_textures.size()]
		if opponent_avatar:
			opponent_avatar.texture = texture
			if origin_y != null:
				opponent_avatar.position.y = origin_y
			opponent_avatar.modulate.a = 1.0
 
		tween = create_tween()
		tween.set_trans(Tween.TRANS_LINEAR)
		if opponent_avatar and origin_y != null:
			tween.tween_property(opponent_avatar, "position:y", origin_y - opponent_avatar.size.y, 0.25)
		await tween.finished
 
	if opponent_avatar:
		if origin_y != null:
			opponent_avatar.position.y = origin_y
		opponent_avatar.modulate.a = 0.0
 
	await get_tree().create_timer(0.15).timeout
	if request_id != search_request_id or not is_visible_in_tree():
		return
 
	_set_final_avatar(avatar_textures[final_index], origin_y)
	if oppo_frame:
		oppo_frame.visible = true
	var random_frame_idx = randi_range(0, avatar_frame_res.frame_list.size() - 1)
	if oppo_frame:
		oppo_frame.texture = avatar_frame_res.frame_list[random_frame_idx]
	if enemy_frame_icon:
		if random_frame_idx > 0 and random_frame_idx - 1 < avatar_frame_res.frame_icon_list.size():
			enemy_frame_icon.texture = avatar_frame_res.frame_icon_list[random_frame_idx - 1]
		else:
			enemy_frame_icon.texture = null
	if not _confirm_opponent_selected():
		return
	_stop_matchmaking_search_sound()
	isSearching = false
	if searchingLabel:
		searchingLabel.text = choose_random_name()
	is_timer_on = true
	if timer:
		timer.start()
	if vs_icon:
		vs_icon.visible = false
	if timer_text:
		timer_text.visible = true
	if cancelBtn:
		cancelBtn.visible = false
	_show_match_coins()
 
 
func _show_match_coins() -> void:
	if player_coin_image:
		player_coin_image.visible = true
	if enemy_coin_image:
		enemy_coin_image.visible = true
	if enemy_coin_label:
		enemy_coin_label.visible = true
	if total_coin_image:
		total_coin_image.visible = true
		total_coin_image.modulate.a = 1.0
		total_coin_image.scale = Vector2.ONE
	if total_amount_label:
		total_amount_label.visible = false
	_play_coin_collection_animation()
 
 
func _play_coin_collection_animation() -> void:
	_cancel_coin_collection_animation()
	coin_animation_id += 1
	var animation_id := coin_animation_id
	await get_tree().process_frame
	if animation_id != coin_animation_id or not is_visible_in_tree():
		return

	if not player_coin_icon or not enemy_coin_icon or not total_coin_image or not player_coin_particles or not enemy_coin_particles:
		_show_total_coins()
		return
 
	if coin_collection_sound and has_node("/root/AudioPlayer"):
		AudioPlayer.play_sfx(coin_collection_sound)

	var pot_centre := _canvas_position_to_local(total_coin_image.get_global_rect().get_center())
	_launch_coin_stream(player_coin_particles, player_coin_icon, pot_centre)
	_launch_coin_stream(enemy_coin_particles, enemy_coin_icon, pot_centre)
	await get_tree().create_timer(COIN_FLIGHT_DURATION).timeout

	if animation_id == coin_animation_id and is_visible_in_tree():
		_show_total_coins()


func _play_matchmaking_search_sound() -> void:
	if not matchmaking_search_sound or search_audio_players.is_empty():
		return
	if has_node("/root/AudioPlayer") and not AudioPlayer.sound_enabled:
		return

	_stop_matchmaking_search_sound()
	for player in search_audio_players:
		player.stream = matchmaking_search_sound
		if matchmaking_search_sound is AudioStreamMP3 or matchmaking_search_sound is AudioStreamOggVorbis:
			matchmaking_search_sound.loop = false
		elif matchmaking_search_sound is AudioStreamWAV:
			matchmaking_search_sound.loop_mode = AudioStreamWAV.LOOP_DISABLED

	search_audio_loop_id += 1
	if not search_music_is_ducked and has_node("/root/AudioPlayer"):
		AudioPlayer.duck_music()
		search_music_is_ducked = true
	_run_matchmaking_search_sound_loop(search_audio_loop_id)


func _run_matchmaking_search_sound_loop(loop_id: int) -> void:
	var active_index := 0
	var clip_length := maxf(0.01, matchmaking_search_sound.get_length())
	search_audio_players[active_index].play()

	while loop_id == search_audio_loop_id and is_visible_in_tree():
		var next_index := 1 - active_index
		var wait_time := maxf(0.01, clip_length - SEARCH_SOUND_OVERLAP_SECONDS)
		await get_tree().create_timer(wait_time).timeout
		if loop_id != search_audio_loop_id or not is_visible_in_tree():
			return

		search_audio_players[next_index].play()
		await get_tree().create_timer(SEARCH_SOUND_OVERLAP_SECONDS).timeout
		search_audio_players[active_index].stop()
		active_index = next_index


func _stop_matchmaking_search_sound() -> void:
	search_audio_loop_id += 1
	for player in search_audio_players:
		if is_instance_valid(player) and player.playing:
			player.stop()
	if search_music_is_ducked and has_node("/root/AudioPlayer"):
		AudioPlayer.unduck_music()
		search_music_is_ducked = false


func _launch_coin_stream(particles: CPUParticles2D, source: TextureRect, target: Vector2) -> void:
	var origin := _canvas_position_to_local(source.get_global_rect().get_center())
	var launch_velocity := (target - origin) / COIN_FLIGHT_DURATION + Vector2.UP * COIN_ARC_HEIGHT
	particles.position = origin
	particles.direction = launch_velocity.normalized()
	particles.initial_velocity_min = launch_velocity.length()
	particles.initial_velocity_max = launch_velocity.length()
	particles.gravity = 2.0 * (target - origin - launch_velocity * COIN_FLIGHT_DURATION) / (COIN_FLIGHT_DURATION * COIN_FLIGHT_DURATION)
	particles.visible = true
	particles.restart()
	particles.emitting = true


func _canvas_position_to_local(canvas_position: Vector2) -> Vector2:
	return get_global_transform_with_canvas().affine_inverse() * canvas_position
 
 
func _show_total_coins() -> void:
	if total_coin_image:
		total_coin_image.visible = true
		total_coin_image.modulate.a = 1.0
		total_coin_image.scale = Vector2.ONE
	if total_amount_label:
		total_amount_label.visible = true
		total_amount_label.modulate.a = 0.0
		total_amount_label.scale = Vector2(0.75, 0.75)
		total_amount_label.pivot_offset = total_amount_label.size / 2.0
		coin_collection_tween = create_tween()
		coin_collection_tween.set_parallel(true)
		coin_collection_tween.tween_property(total_amount_label, "modulate:a", 1.0, 0.18)
		coin_collection_tween.tween_property(total_amount_label, "scale", Vector2.ONE, 0.28).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if player_coin_label:
		player_coin_label.text = "0"
	if enemy_coin_label:
		enemy_coin_label.text = "0"
 
 
func _cancel_coin_collection_animation() -> void:
	coin_animation_id += 1
	if coin_collection_tween:
		coin_collection_tween.kill()
		coin_collection_tween = null
	if player_coin_particles:
		player_coin_particles.emitting = false
		player_coin_particles.visible = false
	if enemy_coin_particles:
		enemy_coin_particles.emitting = false
		enemy_coin_particles.visible = false
   
func choose_random_name() -> String:
	if random_name_file_path.is_empty():
		return "Player"

	if !FileAccess.file_exists(random_name_file_path):
		push_warning("Random name file not found: " + random_name_file_path)
		return "Player"

	var file := FileAccess.open(random_name_file_path, FileAccess.READ)
	if file == null:
		return "Player"

	var json_text := file.get_as_text()
	file.close()

	var parsed: Variant = JSON.parse_string(json_text)

	if parsed is Array and not parsed.is_empty():
		return parsed.pick_random()

	push_warning("Failed to parse random name JSON at: " + random_name_file_path)
	return "Player"


func _set_final_avatar(texture: Texture2D, origin_y_local: float) -> void:
	opponent_avatar.texture = texture
	opponent_avatar.position.y = origin_y_local
	opponent_avatar.modulate.a = 1.0
	opponent_avatar.z_index = 1
	enemy_frame_icon.visible = true
 
	var shake := create_tween()
	shake.set_trans(Tween.TRANS_SINE)
	shake.set_ease(Tween.EASE_IN_OUT)
 
	shake.tween_property(opponent_avatar, "scale", Vector2(1.2, 0.8), 0.05)
	shake.tween_property(opponent_avatar, "scale", Vector2(0.8, 1.2), 0.05)
	shake.tween_property(opponent_avatar, "scale", Vector2(1.15, 0.85), 0.05)
	shake.tween_property(opponent_avatar, "scale", Vector2(0.85, 1.15), 0.05)
	shake.tween_property(opponent_avatar, "scale", Vector2(1.1, 0.9), 0.05)
	shake.tween_property(opponent_avatar, "scale", Vector2(0.9, 1.1), 0.05)
	shake.tween_property(opponent_avatar, "scale", Vector2(1.0, 1.0), 0.05)
 
	await shake.finished
 
 
func _on_timer_timeout() -> void:
	timer.stop()
	is_timer_on = false
	fill_match_data()
	if is_rematch_flow:
		GameAnalysis.track_screen_switch("GamePlayResult_Rematch", "Gameplay")
	else:
		GameAnalysis.track_screen_switch("Matchmaking", "Gameplay")
	SceneManager.load_scene("res://ZeroAimZone-Godot/0_Scenes/GameScene.tscn")
 

func fill_match_data():
	var match_data = GameManager.current_match
	match_data.player_name = player_name_label.text
	match_data.enemy_name = enemy_name_label.text
	match_data.player_avatar = player_avatar.texture
	match_data.enemy_avatar = opponent_avatar.texture
	match_data.player_frame = player_frame.texture
	match_data.enemy_frame = oppo_frame.texture
	match_data.player_frame_icon = player_frame_icon.texture
	match_data.enemy_frame_icon = enemy_frame_icon.texture
	match_data.arena_texture = arena_logo.texture
 	

func _on_cancel_search_pressed() -> void:
	timer.stop()
	is_timer_on = false
	var arena_name = GameManager.get_current_arena_name() if GameManager else "Tokyo"
	var current_attempt := 1
	if GameAnalysis and GameAnalysis.has_method("get_current_arena_attempt"):
		current_attempt = GameAnalysis.get_current_arena_attempt(arena_name)
	GameAnalysis.track_ui_click("UI:Clicks:Matchmaking:Cancel_%s:Attempt_%d" % [arena_name, current_attempt+1])

	if entry_fee_paid:
		GameManager.save_manager.add_coin(GameManager.current_match_entry_fee)
		GameAnalysis.track_economy_event(GameAnalysis.RESOURCE_FLOW_TYPE_SOURCE, "Coins", float(GameManager.current_match_entry_fee), "Refund", "MatchmakingCancel")
		entry_fee_paid = false
	GameAnalysis.track_screen_switch("Matchmaking", "Arena")
	if is_instance_valid(GameManager.ui_manager) and is_instance_valid(GameManager.ui_manager.base_panel) and is_instance_valid(GameManager.ui_manager.base_panel.friend_panel):
		GameManager.ui_manager.base_panel.friend_panel.cancel_all_pending_challenges()
	GameManager.ui_manager.enable_panel(GameManager.ui_manager.PanelType.ARENA)
