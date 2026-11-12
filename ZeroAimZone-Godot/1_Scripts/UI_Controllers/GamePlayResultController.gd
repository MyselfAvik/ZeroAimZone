class_name GamePlayResultController
extends Control

@export_group("Main References")
@export var rematching_label: Label
@export var rematch_button: TextureButton
@export var back_button: TextureButton
@export var coin_reward_label: Label
@export var coin_count_label: Label
@export var diamond_count_label: Label
@export var premium_currency_effect_script: Script
@export var arena_logo: TextureRect
@export var room_result: TextureRect
@export var reward_section: Control
@export var scroll_container: ScrollContainer
@export var reward_container: HBoxContainer
@export var tip_label: Label

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

var crate_database = preload("res://ZeroAimZone-Godot/4_Resources/Tres/CrateDatabase.tres")


@export_group("Player")
@export var player_win_label: Label
@export var player_rematch_card: TextureRect
@export var player_rematch_label: TextureRect
@export var player_cant_rematch_label: TextureRect
@export var player_avatar: TextureRect
@export var player_name_label: Label
@export var player_frame: TextureRect
@export var player_frame_icon: TextureRect
@export var player_container: VBoxContainer

@export_group("Enemy")
@export var enemy_win_label: Label
@export var enemy_rematch_card: TextureRect
@export var enemy_rematch_accept_button: TextureButton
@export var enemy_rematch_reject_button: TextureButton
@export var enemy_rematch_reject_label: TextureRect
@export var enemy_rematch_label: TextureRect
@export var enemy_avatar: TextureRect
@export var enemy_name_label: Label
@export var enemy_frame: TextureRect
@export var enemy_frame_icon: TextureRect
@export var enemy_left: TextureRect
@export var enemy_container: VBoxContainer

@export_group("Shine & Shader")
@export var player_shine: TextureRect
@export var enemy_shine: TextureRect
@export var winner_shader: Shader

@export_group("Particle")
@export var particle_spawn_area: Control
@export var particle_scene: PackedScene

var spawn_interval: float = 0.85
var spawn_timer: Timer
var spawned_particles: Array[Node] = []
var winner_shader_mat: ShaderMaterial

var enemy_rematch_request := false
var enemy_accept_rematch_request := false
var back_button_pressed := false
var button_pressed_action := false

var slide_offset: float = 80.0
var anim_duration: float = 0.35
var delay_between_items: float = 0.15


func set_match_coin_reward(amount: int) -> void:
	coin_reward_label.text = str(amount)


func setup_match_profiles() -> void:
	var match_data = GameManager.current_match
	player_name_label.text = match_data.player_name
	enemy_name_label.text = match_data.enemy_name
	player_avatar.texture = match_data.player_avatar
	enemy_avatar.texture = match_data.enemy_avatar
	player_frame.texture = match_data.player_frame
	enemy_frame.texture = match_data.enemy_frame
	player_frame_icon.texture = match_data.player_frame_icon
	enemy_frame_icon.texture = match_data.enemy_frame_icon
	arena_logo.texture = match_data.arena_texture
	if GameManager.current_state == GameManager.GameState.IN_GAME_SINGLEPLAYER:
		room_result.visible = false
		arena_logo.visible = true
	else:
		arena_logo.visible = false
		room_result.visible = true
	set_match_coin_reward(match_data.coin_reward)

func _ready() -> void:
	# Ensure background/avatar elements do not block button clicks
	var controls_to_ignore = [
		enemy_avatar, player_avatar,
		enemy_rematch_card, player_rematch_card,
		enemy_frame, player_frame,
		enemy_frame_icon, player_frame_icon,
		enemy_name_label, player_name_label,
		enemy_left
	]
	for ctrl in controls_to_ignore:
		if is_instance_valid(ctrl):
			ctrl.mouse_filter = Control.MOUSE_FILTER_IGNORE
			
	enemy_rematch_accept_button.pressed.connect(_on_enemy_accept_button_pressed)
	enemy_rematch_reject_button.pressed.connect(_on_enemy_reject_button_pressed)
	rematch_button.pressed.connect(_on_rematch_button_pressed)
	update_currency()
	if GameManager.save_manager and not GameManager.save_manager.currency_updated.is_connected(update_currency):
		GameManager.save_manager.currency_updated.connect(update_currency)

	_add_premium_effect(coin_count_label)
	_add_premium_effect(diamond_count_label)
	update_random_tip()

	spawn_timer = Timer.new()
	spawn_timer.wait_time = spawn_interval
	add_child(spawn_timer)

	winner_shader_mat = ShaderMaterial.new()
	winner_shader_mat.shader = winner_shader
	
	visibility_changed.connect(_on_visibility_changed)
	if back_button:
		if GameManager.is_rematch or enemy_accept_rematch_request:
			back_button.visible = false
		else:
			back_button.visible = !rematch_button.visible

func update_random_tip() -> void:
	var label := tip_label
	if label == null:
		label = get_node_or_null("ArenaPanel/Bg/SafeArea/HBoxContainer/MarginContainer/Control/VBoxContainer/Tip/TextureRect/Label") as Label
	if label:
		label.text = GAME_TIPS.pick_random()

func _on_visibility_changed() -> void:
	var visible_now := is_visible_in_tree()
	
	if visible_now:
		update_random_tip()
		GameAnalysis.track_screen_switch("Gameplay", "MatchResult")
		setup_match_profiles()
		if GameManager.current_state == GameManager.GameState.IN_GAME_SINGLEPLAYER:
			check_rematch_click()
	
	if visible_now and spawn_timer.is_stopped():
		spawn_timer.start()
	elif not visible_now and not spawn_timer.is_stopped():
		spawn_timer.stop()
		_clear_particles()

func check_rematch_click() -> void:
	button_pressed_action = false
	back_button_pressed = false

	await get_tree().create_timer(randf_range(11.5, 20.5)).timeout
	if not button_pressed_action:
		rematch_button.disabled = true
		rematch_button.visible = false
		if back_button:
			if GameManager.is_rematch or enemy_accept_rematch_request:
				back_button.visible = false
			else:
				back_button.visible = true
		enemy_rematch_reject_label.visible = true
		print("Enemy Reject: ", enemy_rematch_reject_label.visible)

func _add_premium_effect(label: Label) -> void:
	if label and label.get_parent() and premium_currency_effect_script:
		var effect = premium_currency_effect_script.new()
		label.get_parent().add_child(effect)


func reset_result_ui() -> void:
	update_random_tip()
	enemy_rematch_request = false
	enemy_accept_rematch_request = false
	back_button_pressed = false
	button_pressed_action = false
	if player_win_label: player_win_label.visible = false
	if enemy_win_label: enemy_win_label.visible = false
	if player_rematch_label: player_rematch_label.visible = false
	if enemy_rematch_label: enemy_rematch_label.visible = false
	if player_cant_rematch_label: player_cant_rematch_label.visible = false
	if enemy_rematch_reject_label: enemy_rematch_reject_label.visible = false
	if enemy_rematch_card: enemy_rematch_card.visible = false
	if enemy_left: enemy_left.visible = false
	if rematching_label: rematching_label.visible = false
	if rematch_button:
		rematch_button.disabled = false
		rematch_button.visible = true
	if back_button:
		back_button.visible = false
	if enemy_avatar: enemy_avatar.material = null
	if player_avatar: player_avatar.material = null
	if player_shine: player_shine.visible = false
	if enemy_shine: enemy_shine.visible = false
	if reward_container:
		var crate_label = reward_container.get_node_or_null("Reward2/Label") as Label
		if crate_label:
			crate_label.text = "x1"

func show_player_win():
	AudioPlayer.play_sfx(AudioPlayer.SOUND_DB.game_won)
	reset_result_ui()
	player_win_label.visible = true
	GameManager.custom_animation._scale_anim(player_win_label, 0.5, 1.5)
	_add_winner_shine(player_shine, player_avatar)
	if not spawn_timer.timeout.is_connected(_spawn_confetti):
		spawn_timer.timeout.connect(_spawn_confetti)
	if GameManager.current_state == GameManager.GameState.IN_GAME_SINGLEPLAYER:
		player_container.alignment = BoxContainer.ALIGNMENT_CENTER
		enemy_container.alignment = BoxContainer.ALIGNMENT_CENTER
		reward_section.visible = true
		if GameManager.progression_manager:
			var crate_type = GameManager.progression_manager.get_reward_crate_type()
			var has_slot: bool = GameManager.progression_manager.has_free_crate_slot()
			if crate_database and crate_type < crate_database.Crates.size():
				var crate_info = crate_database.Crates[crate_type]
				var crate_texture_rect = reward_container.get_node_or_null("Reward2/TextureRect")
				var crate_label = reward_container.get_node_or_null("Reward2/Label") as Label
				if crate_texture_rect and crate_info.chest_icon:
					crate_texture_rect.texture = crate_info.chest_icon
				if crate_label:
					crate_label.text = "x1" if has_slot else "FULL"
			if not has_slot:
				_notify_crate_slots_full()
		show_rewards_animated()
	else:
		reward_section.visible = false

func _notify_crate_slots_full() -> void:
	if GameManager.in_game_ui and GameManager.in_game_ui.popup_panel and GameManager.in_game_ui.popup_panel.insufficient_diamonds_popup:
		var pop = GameManager.in_game_ui.popup_panel.insufficient_diamonds_popup
		pop.header_label.text = "SLOTS FULL"
		pop.text_label.text = "Crate slots are full — open a crate to collect match chests!"
		get_tree().create_timer(1.8).timeout.connect(func():
			if is_visible_in_tree() and GameManager.in_game_ui.popup_panel:
				GameManager.in_game_ui.popup_panel.show_insufficient_diamonds_popup()
		)

func show_enemy_win():
	AudioPlayer.play_sfx(AudioPlayer.SOUND_DB.game_over)
	reset_result_ui()
	enemy_win_label.visible = true
	GameManager.custom_animation._scale_anim(enemy_win_label, 0.5, 1.5)
	if GameManager.current_state == GameManager.GameState.IN_GAME_SINGLEPLAYER:
		player_container.alignment = BoxContainer.ALIGNMENT_BEGIN
		enemy_container.alignment = BoxContainer.ALIGNMENT_BEGIN
	reward_section.visible = false
	_add_winner_shine(enemy_shine, enemy_avatar)
	if spawn_timer.timeout.is_connected(_spawn_confetti):
		spawn_timer.timeout.disconnect(_spawn_confetti)
	_clear_particles()

func update_currency() -> void:
	if diamond_count_label:
		diamond_count_label.text = GameManager.format_number(GameManager.save_manager.game_data["currency"]["Diamonds"])
	if coin_count_label:
		coin_count_label.text = GameManager.format_number(GameManager.save_manager.game_data["currency"]["Coins"])

func _on_back_button_pressed() -> void:
	back_button_pressed = true
	if GameManager.current_state == GameManager.GameState.IN_GAME_SINGLEPLAYER:
		GameAnalysis.track_screen_switch("MatchResult", "Arena")
		if GameManager:
			GameManager.target_main_menu_panel = UIManager.PanelType.ARENA
	else:
		GameAnalysis.track_screen_switch("MatchResult", "Home")
		if GameManager.multiplayer_manager != null:
			GameManager.multiplayer_manager.disconnect_player()
		if GameManager:
			GameManager.target_main_menu_panel = UIManager.PanelType.BASE
			GameManager.target_base_sub_panel = BasePanelController.BasePanelType.FRIEND

	SceneManager.load_scene("res://ZeroAimZone-Godot/0_Scenes/MainMenu.tscn")
	
	enemy_rematch_reject_label.visible = false
	player_cant_rematch_label.visible = false
	player_rematch_label.visible = false
	enemy_rematch_label.visible = false
	rematching_label.visible = false
	enemy_rematch_card.visible = false
	enemy_left.visible = false
	
	GameManager.in_game_ui.hide_all_panels()

func show_player_left():
	enemy_left.visible = true
	enemy_rematch_card.visible = false
	enemy_rematch_label.visible = false
	enemy_rematch_reject_label.visible = false
	player_rematch_label.visible = false
	player_cant_rematch_label.visible = false
	rematching_label.visible = false
	rematch_button.disabled = true
	rematch_button.visible = false
	back_button.visible = true

func _on_rematch_button_pressed() -> void:
	button_pressed_action = true

	if GameManager.current_state == GameManager.GameState.IN_GAME_SINGLEPLAYER:
		if enemy_rematch_card.is_visible_in_tree():
			enemy_rematch_card.visible = false
			player_rematch_label.visible = true
			rematch_game()
		else:
			enemy_auto_accept_rematch()
	else:
		if enemy_rematch_card.is_visible_in_tree():
			enemy_rematch_card.visible = false
			player_rematch_label.visible = true
			rematch.rpc()
		else:
			show_enemy_rematch.rpc(multiplayer.get_unique_id())
		

@rpc("any_peer", "call_local", "reliable")
func show_enemy_rematch(my_id: int):
	player_rematch_label.visible = true if multiplayer.get_unique_id() == my_id else false
	enemy_rematch_card.visible = false if multiplayer.get_unique_id() == my_id else true
	if enemy_rematch_card.visible:
		_check_rematch_affordability()

func _on_enemy_accept_button_pressed() -> void:
	enemy_rematch_card.visible = false
	player_rematch_label.visible = true

	if GameManager.current_state == GameManager.GameState.IN_GAME_SINGLEPLAYER:
		rematch_game()
	else:
		rematch.rpc()
func _on_enemy_reject_button_pressed() -> void:
	if GameManager.current_state == GameManager.GameState.IN_GAME_SINGLEPLAYER:
		enemy_rematch_card.visible = false
		enemy_rematch_label.visible = false
		player_cant_rematch_label.visible = true
		rematch_button.disabled = true
		rematch_button.visible = false
		back_button.visible = true
		button_pressed_action = true
		# GameManager.ui_manager.enable_panel(GameManager.ui_manager.PanelType.BASE)
	else:
		rematch_reject.rpc(multiplayer.get_unique_id())


@rpc("any_peer", "call_local", "reliable")
func rematch_reject(my_id: int):
	player_cant_rematch_label.visible = true if multiplayer.get_unique_id() == my_id else false
	enemy_rematch_card.visible = false
	enemy_rematch_label.visible = false
	enemy_rematch_reject_label.visible = false if multiplayer.get_unique_id() == my_id else true
	rematch_button.disabled = true
	rematch_button.visible = false
	if back_button:
		if GameManager.is_rematch or enemy_accept_rematch_request:
			back_button.visible = false
		else:
			back_button.visible = true

@rpc("any_peer", "call_local", "reliable")
func rematch():
	GameManager.is_rematch = true
	enemy_rematch_label.visible = true
	rematch_button.disabled = true
	rematch_button.visible = false
	if back_button:
		if GameManager.is_rematch or enemy_accept_rematch_request:
			back_button.visible = false
		else:
			back_button.visible = true
	await get_tree().create_timer(2.0).timeout
	
	if GameManager.current_state == GameManager.GameState.IN_GAME_MULTIPLAYER:
		if multiplayer.multiplayer_peer == null or (multiplayer.is_server() and multiplayer.get_peers().is_empty()) or not is_instance_valid(GameManager.multiplayer_manager):
			show_player_left()
			return

	reset_result_ui()
	
	GameAnalysis.track_screen_switch("GamePlayResult_Rematch", "Gameplay")
	GameManager.in_game_ui.hide_all_panels()
	GameManager.in_game_ui.show_gameplay()
	GameManager.in_game_ui.gameplay_panel.reset_round_indicators()
	
	if GameManager.multiplayer_manager != null:
		GameManager.multiplayer_manager.start_rematch()
	
func enable_enemy_rematch_card() -> void:
	if !is_visible_in_tree():
		return

	enemy_rematch_request = randf() < 0.6
	print("Enemy rematch request: ", enemy_rematch_request)

	if enemy_rematch_request:
		await get_tree().create_timer(randf_range(1.3, 2.5)).timeout
		enemy_rematch_card.visible = true
		_check_rematch_affordability()
		await get_tree().create_timer(randf_range(4.5, 5.5)).timeout
		enemy_rematch_card.visible = false
		enemy_rematch_request = false

func enemy_auto_accept_rematch() -> void:
	if !is_visible_in_tree():
		return

	enemy_accept_rematch_request = randf() < 0.4
	print("Enemy accept rematch request: ", enemy_accept_rematch_request)

	if !enemy_rematch_request:
		player_rematch_label.visible = true
		rematch_button.visible = false
		if back_button:
			if GameManager.is_rematch or enemy_accept_rematch_request:
				back_button.visible = false
			else:
				back_button.visible = true
		if enemy_accept_rematch_request:
			await get_tree().create_timer(1.2).timeout
			rematching_label.visible = true
			await get_tree().create_timer(randf_range(1.7, 2.5)).timeout
			rematch_game()
		else:
			await get_tree().create_timer(randf_range(1.7, 2.5)).timeout
			if !back_button_pressed:
				enemy_rematch_reject_label.visible = true
			else:
				back_button_pressed = false

func rematch_game() -> void:
	if not _pay_for_rematch():
		_show_insufficient_coins_popup()
		return

	GameManager.is_rematch = true
	enemy_rematch_label.visible = true
	rematch_button.disabled = true
	rematch_button.visible = false
	if back_button:
		if GameManager.is_rematch or enemy_accept_rematch_request:
			back_button.visible = false
		else:
			back_button.visible = true
	await get_tree().create_timer(2.0).timeout
	enemy_rematch_label.visible = false
	enemy_rematch_card.visible = false
	player_rematch_label.visible = false
	rematching_label.visible = false
	rematch_button.disabled = false
	rematch_button.visible = true
	if back_button:
		if GameManager.is_rematch or enemy_accept_rematch_request:
			back_button.visible = false
		else:
			back_button.visible = !rematch_button.visible
	GameManager.in_game_ui.hide_all_panels()
	GameManager.in_game_ui.match_making_panel.set_arena_texture(arena_logo.texture)
	GameManager.in_game_ui.match_making_panel.set_match_coin_amounts(GameManager.current_match.entry_fee, GameManager.current_match.coin_reward)
	GameManager.in_game_ui.match_making_panel.show()
	if reward_section.visible:
		scroll_container.scroll_horizontal = 0
	# GameManager.game_flow_manager._enter_state(GameManager.game_flow_manager.State.IN_GAME_SINGLEPLAYER)


func _show_insufficient_coins_popup() -> void:
	GameManager.in_game_ui.popup_panel.insufficient_diamonds_popup.header_label.text = "not enough coins"
	GameManager.in_game_ui.popup_panel.insufficient_diamonds_popup.text_label.text = "Top up to get more coins."
	GameManager.in_game_ui.popup_panel.show_insufficient_diamonds_popup()
	
	if rematch_button:
		rematch_button.visible = false
	if back_button:
		back_button.visible = true

func _pay_for_rematch() -> bool:
	var entry_fee := GameManager.current_match.entry_fee
	var reward_amount := GameManager.current_match.coin_reward
	if entry_fee <= 0 or reward_amount <= 0:
		push_error("Cannot start a rematch without a valid arena entry fee and reward.")
		return false
	if int(GameManager.save_manager.game_data["currency"]["Coins"]) < entry_fee:
		push_warning("Not enough coins to place the rematch entry fee.")
		return false

	set_match_coin_reward(reward_amount)
	return true

func _check_rematch_affordability() -> void:
	if not is_instance_valid(GameManager) or not is_instance_valid(GameManager.save_manager) or GameManager.current_match == null:
		return
	var entry_fee := GameManager.current_match.entry_fee
	if int(GameManager.save_manager.game_data["currency"]["Coins"]) < entry_fee:
		# Don't disable to show popup
		pass
	else:
		if enemy_rematch_accept_button:
			enemy_rematch_accept_button.disabled = false

func _add_winner_shine(shine_effect: TextureRect, avatar: TextureRect) -> void:
	shine_effect.visible = true
	var shine_tween = create_tween()
	shine_tween.set_loops()
	shine_tween.tween_property(shine_effect, "rotation", rotation + TAU, 20.0) \
	.as_relative() \
	.set_trans(Tween.TRANS_LINEAR)

	avatar.material = winner_shader_mat

func _spawn_confetti() -> void:
	if not is_visible_in_tree():
		return
	var p = particle_scene.instantiate()
	add_child(p)
	
	var local_point = Vector2(randf_range(0, particle_spawn_area.size.x), randf_range(0, particle_spawn_area.size.y))
	p.global_position = particle_spawn_area.global_position + local_point
	p.one_shot = true
	p.emitting = true
	p.restart()

	p.finished.connect(_on_particle_finished.bind(p))
	spawned_particles.append(p)

func _on_particle_finished(p: Node) -> void:
	spawned_particles.erase(p)
	p.queue_free()

func _clear_particles() -> void:
	for p in spawned_particles:
		if is_instance_valid(p):
			p.queue_free()
	spawned_particles.clear()

func show_rewards_animated() -> void:
	var children := reward_container.get_children()

	set_scroll_enabled(false)
	await get_tree().process_frame

	var final_positions: Array = []
	for child in children:
		final_positions.append(child.position)
		child.modulate.a = 0.0
		child.position.x = final_positions[final_positions.size() - 1].x + slide_offset

	await get_tree().create_timer(0.85).timeout

	for i in range(children.size()):
		var child = children[i]
		var target_x = final_positions[i].x

		var tween := create_tween()
		tween.set_parallel(true)
		tween.tween_property(child, "position:x", target_x, anim_duration) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tween.tween_property(child, "modulate:a", 1.0, anim_duration) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

		GameManager.custom_animation._play_card_flash(child)
		scroll_to_child(child)

		await tween.finished

		if i < children.size() - 1:
			await get_tree().create_timer(delay_between_items).timeout

	set_scroll_enabled(true)

func scroll_to_child(child: Control) -> void:
	var target_scroll_x: float = child.position.x + child.size.x - scroll_container.size.x
	target_scroll_x = clamp(target_scroll_x, 0.0, reward_container.size.x - scroll_container.size.x)
	target_scroll_x = max(target_scroll_x, 0.0)

	var scroll_tween := create_tween()
	scroll_tween.tween_property(scroll_container, "scroll_horizontal", int(target_scroll_x), 0.3) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

func set_scroll_enabled(enabled: bool) -> void:
	scroll_container.mouse_filter = Control.MOUSE_FILTER_STOP if enabled else Control.MOUSE_FILTER_IGNORE
