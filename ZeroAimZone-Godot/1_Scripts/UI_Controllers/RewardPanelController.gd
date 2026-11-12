class_name RewardPanelController
extends Control

@export var open_crate_button: TextureButton
@export var crate: TextureRect
@export var crate_glow: TextureRect
@export var crate_sprites: Array[Texture]
@export var crate_database: CrateDatabase
@export var back_button: TextureButton

@export var diamond_count_label: Label
@export var premium_currency_effect_script: Script
@export var coin_count_label: Label
@export var card_count_label: Label
@export var card_count_image: TextureRect
@export var open_indication: TextureRect
@export var reward_card: PackedScene
@export var reward_card_parent: Control
@export var scroll_container: ScrollContainer

@export var coin_texture: Texture2D
@export var diamond_texture: Texture2D

@export var avatar_frame_resource: AvatarFrameList
@export var all_guns_database: AllGunData

@export var card_flash_shader: Shader
@export var anim: AnimationPlayer

@export var glow_paricles: PackedScene
@export var chest_open_sound: AudioStream

var card_mat: ShaderMaterial
var avatar_list
var frame_list
var frame_icon_list

var guns_list: Array[GunSO]

var is_crate_open := false
var chest_crate_type: int = 0
var rewards: Array[Dictionary]
var crate_open_count: int = 0
var _unlocked_guns_in_crate: Array[int] = []

func _ready() -> void:
	if not crate_database:
		crate_database = load("res://ZeroAimZone-Godot/4_Resources/Tres/CrateDatabase.tres")
	GameManager.set_currency_collection_textures(coin_texture, diamond_texture)
	avatar_list = avatar_frame_resource.avatar_list
	frame_list = avatar_frame_resource.frame_list
	frame_icon_list = avatar_frame_resource.frame_icon_list
	guns_list = all_guns_database.all_guns
	back_button.visible = false
	open_crate_button.pressed.connect(open_crate)
	crate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	crate_glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	open_indication.mouse_filter = Control.MOUSE_FILTER_IGNORE
	back_button.pressed.connect(_on_back_button_pressed)

	update_currency()
	if GameManager.progression_manager:
		GameManager.progression_manager.progression_updated.connect(update_currency)
	if GameManager.save_manager and not GameManager.save_manager.currency_updated.is_connected(update_currency):
		GameManager.save_manager.currency_updated.connect(update_currency)
		
	_add_premium_effect(coin_count_label)
	_add_premium_effect(diamond_count_label)
	_rotate_anim(crate_glow)

	card_mat = ShaderMaterial.new()
	card_mat.shader = card_flash_shader

func _add_premium_effect(label: Label) -> void:
	if label and label.get_parent() and premium_currency_effect_script:
		var effect = premium_currency_effect_script.new()
		label.get_parent().add_child(effect)


func update_currency():
	if diamond_count_label:
		diamond_count_label.text = GameManager.format_number(GameManager.save_manager.game_data["currency"]["Diamonds"])
	if coin_count_label:
		coin_count_label.text = GameManager.format_number(GameManager.save_manager.game_data["currency"]["Coins"])


func _get_crate_tier_name() -> String:
	match chest_crate_type:
		0: return "bronze"
		1: return "silver"
		2: return "gold"
		_: return "bronze"

func show_reward_panel():
	crate_open_count = rewards.size()
	update_reward_ui()
	show()
	# A new crate always begins at the first reward card.
	scroll_container.scroll_horizontal = 0

	if crate_sprites.size() < 3:
		crate_sprites.resize(3)
		
	if crate_database and chest_crate_type < crate_database.Crates.size():
		var crate_info = crate_database.Crates[chest_crate_type]
		if crate_info:
			if crate_info.chest_icon:
				crate_sprites[0] = crate_info.chest_icon
			if crate_info.chest_open_glow_texture:
				crate_sprites[1] = crate_info.chest_open_glow_texture
			if crate_info.chest_empty_texture:
				crate_sprites[2] = crate_info.chest_empty_texture
				
			_update_animation_textures()

	crate.texture = crate_sprites[0]

	back_button.visible = false
	if crate_open_count <= 0:
		back_button.visible = true

func _update_animation_textures() -> void:
	if not anim:
		return
	
	if anim.has_animation("Crate_open"):
		var crate_open_anim = anim.get_animation("Crate_open")
		var track_idx = crate_open_anim.find_track("Panel/SafeArea/OpenCrateButton/HBoxContainer/Control/MarginContainer/VBoxContainer/Crate/ChestCrate:texture", Animation.TYPE_VALUE)
		if track_idx != -1:
			crate_open_anim.track_set_key_value(track_idx, 0, crate_sprites[0])
			crate_open_anim.track_set_key_value(track_idx, 1, crate_sprites[1])
	
	if anim.has_animation("RESET"):
		var reset_anim = anim.get_animation("RESET")
		var track_idx = reset_anim.find_track("Panel/SafeArea/OpenCrateButton/HBoxContainer/Control/MarginContainer/VBoxContainer/Crate/ChestCrate:texture", Animation.TYPE_VALUE)
		if track_idx != -1:
			reset_anim.track_set_key_value(track_idx, 0, crate_sprites[0])

func _on_back_button_pressed() -> void:
	var newly_unlocked_guns := _unlocked_guns_in_crate.duplicate()
	_unlocked_guns_in_crate.clear()

	for i in reward_card_parent.get_children():
		i.queue_free()
	GameManager.ui_manager.enable_panel(UIManager.PanelType.BASE)
	if GameManager.ui_manager.base_panel:
		GameManager.ui_manager.base_panel.switch_panel(BasePanelController.BasePanelType.HOME)
	crate_open_count = rewards.size()
	update_reward_ui()
	GameManager.custom_animation._toggle_anim(open_indication, true, 0.01)
	GameManager.custom_animation._toggle_anim(crate_glow, true, 0.01)
	GameManager.custom_animation._toggle_anim(card_count_image, true, 0.01)
	GameManager.custom_animation._clear_particle_effect()
	scroll_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	crate.texture = crate_sprites[0]
	is_crate_open = false
	anim.play("RESET")

	if not newly_unlocked_guns.is_empty():
		var all_gun_data: AllGunData = load("res://ZeroAimZone-Godot/4_Resources/Tres/all_gun_data.tres")
		if all_gun_data:
			for g_idx in newly_unlocked_guns:
				if g_idx >= 0 and g_idx < all_gun_data.all_guns.size() and all_gun_data.all_guns[g_idx]:
					if GameManager.ui_manager and GameManager.ui_manager.popup_panel:
						GameManager.ui_manager.popup_panel.show_gun_reward_panel(g_idx, all_gun_data.all_guns[g_idx])
						break

func open_crate():
	if crate_open_count <= 0:
		return

	if !is_crate_open:
		GameManager.custom_animation._clear_particle_effect()

		is_crate_open = true
		if crate_open_count == rewards.size():
			GameAnalysis.track_crate_event(_get_crate_tier_name(), "open")
		crate_open_count -= 1
		AudioPlayer.play_sfx(chest_open_sound)

		var reward_index := rewards.size() - 1 - crate_open_count
		
		if crate_open_count == rewards.size() - 1:
			anim.play("Crate_open")
			await anim.animation_finished
		else:
			var shake_tween = create_tween()
			var orig_rot = crate.rotation_degrees
			shake_tween.tween_property(crate, "rotation_degrees", orig_rot - 7.5, 0.1)
			shake_tween.tween_property(crate, "rotation_degrees", orig_rot, 0.1)
			shake_tween.tween_property(crate, "rotation_degrees", orig_rot + 7.5, 0.1)
			shake_tween.tween_property(crate, "rotation_degrees", orig_rot, 0.1)
			await shake_tween.finished

		GameManager.custom_animation._spawn_particle_effect(glow_paricles, Vector2(350, 300), crate)
		_spawn_reward_card(reward_index)
		update_reward_ui()

		if crate_open_count <= 0:
			scroll_container.mouse_filter = Control.MOUSE_FILTER_STOP
			# GameManager.custom_animation._toggle_anim(card_count_image,false, 0.25)
			await get_tree().create_timer(0.5).timeout
			crate.texture = crate_sprites[2]
			GameManager.custom_animation._clear_particle_effect()
			back_button.visible = true

		is_crate_open = false

func _spawn_reward_card(index: int) -> void:
	if index < 0 or index >= rewards.size():
		return

	var i = rewards[index]
	var reward = reward_card.instantiate() as RewardCardController
	reward.modulate.a = 0.0
	reward.scale = Vector2.ZERO
	
	match i.key:
		0:
			reward.setup("Coin", str(i.value), coin_texture)
		1:
			reward.setup("Daimond", str(i.value), diamond_texture)
			
		2:
			var avatar_text = "OWNED" if i.has("converted_to_coins") else "X1"
			reward.setup("Avatar", avatar_text, avatar_list[i.value])
		3:
			var frame_text = "OWNED" if i.has("converted_to_coins") else "X1"
			var frame_icon_tex = frame_icon_list[i.value - 1] if (i.value - 1 >= 0 and i.value - 1 < frame_icon_list.size()) else null
			reward.setup("Frame", frame_text, frame_list[i.value], frame_icon_tex)
		4:
			var gun_idx = int(i.value.gun_index)
			if gun_idx >= 0 and gun_idx < guns_list.size() and guns_list[gun_idx]:
				var card_text = "MAX" if i.value.has("converted_to_coins") else ("X" + str(i.value.cards_amount))
				reward.setup(guns_list[gun_idx].name, card_text, guns_list[gun_idx].get_gun_texture(0))
		# 5:
		# 	reward.setup("Skin", str(i.value), diamond_texture)

	reward_card_parent.add_child(reward)

	await get_tree().process_frame

	var target_global: Vector2 = reward.global_position

	reward.reparent(self, true)
	reward.global_position = crate.global_position

	GameManager.custom_animation._play_card_flash(card_count_image)
	GameManager.custom_animation._scale_anim(card_count_image)

	var reward_card_anim := GameManager.custom_animation._card_anim(reward, target_global)

	await reward_card_anim.finished
	if not is_instance_valid(reward) or not is_inside_tree():
		return
	reward.reparent(reward_card_parent, true)
	reward.material = card_mat.duplicate()
	GameManager.custom_animation._play_card_flash(reward)
	if reward_card_parent.get_child_count() == 4:
		await _scroll_to_reward_card(reward)
	
	if i.has("converted_to_coins") or (i.key == 4 and i.value is Dictionary and i.value.has("converted_to_coins")):
		var coin_amt: int = int(i.get("converted_to_coins", i.value.get("converted_to_coins", 50) if i.value is Dictionary else 50))
		await _animate_guncard_to_coins(reward, coin_amt)
		return

	if i.key == 0:
		GameManager.save_manager.add_coin(i.value)
		GameAnalysis.track_economy_event(GameAnalysis.RESOURCE_FLOW_TYPE_SOURCE, "Coins", float(i.value), "Reward", "Crate")
	elif i.key == 1:
		GameManager.save_manager.add_diamond(i.value)
		GameAnalysis.track_economy_event(GameAnalysis.RESOURCE_FLOW_TYPE_SOURCE, "Diamonds", float(i.value), "Reward", "Crate")
	elif i.key == 2:
		if i.value >= 0 and i.value < GameManager.save_manager.game_data["player_data"]["avatar_unlocked"].size():
			GameManager.save_manager.game_data["player_data"]["avatar_unlocked"][i.value] = true
			GameManager.save_manager.save_data()
		if GameManager.ui_manager and GameManager.ui_manager.base_panel and GameManager.ui_manager.base_panel.profile_panel:
			GameManager.ui_manager.base_panel.profile_panel.refresh_player_data()
			GameManager.ui_manager.base_panel.profile_panel.set_frame_and_avatar_grid()
	elif i.key == 3:
		if i.value >= 0 and i.value < GameManager.save_manager.game_data["player_data"]["frame_unlocked"].size():
			GameManager.save_manager.game_data["player_data"]["frame_unlocked"][i.value] = true
			GameManager.save_manager.save_data()
		if GameManager.ui_manager and GameManager.ui_manager.base_panel and GameManager.ui_manager.base_panel.profile_panel:
			GameManager.ui_manager.base_panel.profile_panel.refresh_player_data()
			GameManager.ui_manager.base_panel.profile_panel.set_frame_and_avatar_grid()
	elif i.key == 4:
		var target_gun_idx: int = int(i.value.gun_index)
		var was_unlocked_before: bool = false
		if GameManager.save_manager.game_data.has("guns_data") and GameManager.save_manager.game_data["guns_data"].has("guns_unlocked") and target_gun_idx >= 0 and target_gun_idx < GameManager.save_manager.game_data["guns_data"]["guns_unlocked"].size():
			was_unlocked_before = bool(GameManager.save_manager.game_data["guns_data"]["guns_unlocked"][target_gun_idx])

		GameManager.save_manager.cards_update(target_gun_idx, i.value.cards_amount)

		var is_unlocked_now: bool = false
		if GameManager.save_manager.game_data.has("guns_data") and GameManager.save_manager.game_data["guns_data"].has("guns_unlocked") and target_gun_idx >= 0 and target_gun_idx < GameManager.save_manager.game_data["guns_data"]["guns_unlocked"].size():
			is_unlocked_now = bool(GameManager.save_manager.game_data["guns_data"]["guns_unlocked"][target_gun_idx])

		if not was_unlocked_before and is_unlocked_now:
			if not _unlocked_guns_in_crate.has(target_gun_idx):
				_unlocked_guns_in_crate.append(target_gun_idx)

		var gun_name_str := "Gun_%d" % target_gun_idx
		var all_gun_data: AllGunData = load("res://ZeroAimZone-Godot/4_Resources/Tres/all_gun_data.tres")
		if all_gun_data and target_gun_idx >= 0 and target_gun_idx < all_gun_data.all_guns.size() and all_gun_data.all_guns[target_gun_idx]:
			gun_name_str = all_gun_data.all_guns[target_gun_idx].name
		GameAnalysis.track_economy_event(GameAnalysis.RESOURCE_FLOW_TYPE_SOURCE, "GunCards", float(i.value.cards_amount), "Reward", "Crate_" + gun_name_str)

	_play_reward_currency_collection(i, reward)

func _animate_guncard_to_coins(reward: RewardCardController, coin_amount: int) -> void:
	# Give player a brief moment to see the gun card
	await get_tree().create_timer(0.4).timeout

	if not is_instance_valid(reward) or not reward.is_inside_tree():
		# Still safely grant coins if player exited before the timer finished
		if GameManager and GameManager.save_manager:
			GameManager.save_manager.add_coin(coin_amount)
		return

	# Swap card visual directly to Coins
	reward.setup("Coin", str(coin_amount), coin_texture)

	# Flash and pop effect
	if GameManager and GameManager.custom_animation:
		GameManager.custom_animation._play_card_flash(reward)
		GameManager.custom_animation._scale_anim(reward, 0.2, 1.1)

	# Grant coins and trigger coin collection particle animation
	if GameManager and GameManager.save_manager:
		GameManager.save_manager.add_coin(coin_amount)
	GameAnalysis.track_economy_event(GameAnalysis.RESOURCE_FLOW_TYPE_SOURCE, "Coins", float(coin_amount), "Reward", "Crate_MaxGunConvert")
	if is_instance_valid(reward) and is_instance_valid(reward.image) and is_instance_valid(coin_count_label):
		GameManager.play_currency_collection(coin_texture, coin_amount, reward.image, coin_count_label)

func _scroll_to_reward_card(reward: Control) -> void:
	# Wait for the HBoxContainer to lay out the newly reparented fourth card.
	await get_tree().process_frame
	if not is_instance_valid(reward) or not is_instance_valid(scroll_container):
		return
	var max_scroll := maxf(0.0, reward_card_parent.size.x - scroll_container.size.x)
	var target_scroll := clampf(
		reward.position.x - (scroll_container.size.x - reward.size.x) * 0.5,
		0.0,
		max_scroll
	)
	var scroll_tween := create_tween()
	scroll_tween.tween_property(scroll_container, "scroll_horizontal", target_scroll, 0.35) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	await scroll_tween.finished

func _play_reward_currency_collection(reward_data: Dictionary, reward: RewardCardController) -> void:
	match reward_data.key:
		0:
			GameManager.play_currency_collection(coin_texture, int(reward_data.value), reward.image, coin_count_label)
		1:
			GameManager.play_currency_collection(diamond_texture, int(reward_data.value), reward.image, diamond_count_label, true, 1.28)

func update_reward_ui() -> void:
	card_count_label.text = str(crate_open_count)
	if crate_open_count < rewards.size():
		GameManager.custom_animation._toggle_anim(open_indication, false)
		GameManager.custom_animation._toggle_anim(crate_glow, false)

func _rotate_anim(object: TextureRect) -> void:
	var rotate_tween = create_tween()
	rotate_tween.set_loops()
	rotate_tween.tween_property(object, "rotation", rotation + TAU, 50.0) \
	.as_relative() \
	.set_trans(Tween.TRANS_LINEAR)

var _click_start_pos := Vector2.ZERO
var _is_dragging := false

func _input(event: InputEvent) -> void:
	if not visible or is_crate_open:
		return

	if crate_open_count <= 0:
		var is_valid_input = (
			event is InputEventScreenTouch
			or (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT)
		)

		if is_valid_input:
			if event.pressed:
				_click_start_pos = event.position
				_is_dragging = false
			else:
				if not _is_dragging:
					_on_back_button_pressed()
				get_viewport().set_input_as_handled()
