class_name DailyRewardController
extends BasePopupController

@export var rewards_config: DailyRewardsConfig
@export var rewards_section: Control
@export var collect_button: Button
@export var claimed_tick: TextureRect
@export var normal_glow_bg: Texture2D
@export var day7_glow_bg: Texture2D

var day_cards: Array[Panel] = []
var claimed_ticks: Array[TextureRect] = []
var collect_ad_icon: TextureRect


func _ready() -> void:
	super._ready()
	_cache_day_cards()
	_cache_collect_button()
	_cache_claimed_tick()
	if TimeManager and not TimeManager.time_synced.is_connected(_on_time_synced):
		TimeManager.time_synced.connect(_on_time_synced)
	refresh()

func _on_time_synced(_trusted_unix_time: int) -> void:
	refresh()


func _notification(what: int) -> void:
	if what == NOTIFICATION_VISIBILITY_CHANGED and visible:
		refresh()


func _on_close_btn_pressed() -> void:
	GameManager.ui_manager.popup_panel.hide_popup()


func _on_overlay_pressed() -> void:
	# Keep the scene-connected Overlay signal on the same close path as the X.
	GameManager.ui_manager.popup_panel.hide_popup()

func show_popup() -> void:
	_stop_transition()
	visible = true

	if not main_container:
		return

	main_container.pivot_offset = main_container.size * 0.5
	main_container.scale = Vector2.ONE
	main_container.modulate.a = 0.0

	_transition_tween = create_tween()
	_transition_tween.tween_property(main_container, "modulate:a", 1.0, 0.2) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

func hide_popup() -> void:
	_stop_transition()

	if not visible:
		return

	if not main_container:
		visible = false
		return

	main_container.pivot_offset = main_container.size * 0.5
	_transition_tween = create_tween()
	_transition_tween.tween_property(main_container, "modulate:a", 0.0, 0.2) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	_transition_tween.tween_callback(func(): visible = false)


func _on_collect_button_pressed() -> void:
	if not rewards_config:
		return

	if not GameManager.save_manager.can_claim_daily_reward():
		refresh()
		return

	var current_day := GameManager.save_manager.get_daily_reward_current_day()
	var reward := rewards_config.get_reward_for_day(current_day)
	if not reward:
		return

	if reward.reward_type == DailyRewardData.RewardType.GUN_CARDS:
		_show_gun_card_reward(reward)
		return

	_apply_reward(reward)
	GameAnalysis.track_daily_reward_claim(current_day)
	GameManager.save_manager.mark_daily_reward_claimed(rewards_config.get_reward_count())
	refresh()


func refresh() -> void:
	if not is_inside_tree() or not rewards_config:
		return

	var current_day := GameManager.save_manager.get_daily_reward_current_day()
	var can_claim := GameManager.save_manager.can_claim_daily_reward()
	var claimed_day := GameManager.save_manager.get_daily_reward_last_claimed_day()
	var requires_ad := GameManager.save_manager.does_daily_reward_claim_require_ad()

	var effective_day := current_day
	if not can_claim:
		effective_day -= 1
		if effective_day <= 0:
			effective_day = day_cards.size()

	for day_index in range(1, day_cards.size() + 1):
		var card := day_cards[day_index - 1]
		var reward := rewards_config.get_reward_for_day(day_index)
		_update_card(card, reward, day_index, effective_day, can_claim)

	_update_collect_button(current_day, can_claim, requires_ad)
	_update_claimed_tick(effective_day, can_claim)


func _cache_day_cards() -> void:
	day_cards.clear()

	if not rewards_section:
		return

	for row in rewards_section.get_children():
		for child in row.get_children():
			if child is Panel and child.name.begins_with("Day") and child.name.ends_with("Card"):
				day_cards.append(child)
				
				# Connect gui_input if not already connected
				if not child.gui_input.is_connected(_on_day_card_gui_input.bind(child)):
					child.gui_input.connect(_on_day_card_gui_input.bind(child))

	day_cards.sort_custom(func(a: Panel, b: Panel): return _get_day_from_card(a) < _get_day_from_card(b))

func _on_day_card_gui_input(event: InputEvent, card: Panel) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		var card_day = _get_day_from_card(card)
		var current_day := GameManager.save_manager.get_daily_reward_current_day()
		var can_claim := GameManager.save_manager.can_claim_daily_reward()
		
		# Only allow clicking to claim if it's the current day, it can be claimed, and it doesn't require an ad
		if card_day == current_day and can_claim:
			var reward := rewards_config.get_reward_for_day(card_day)
			if reward and reward.reward_type == DailyRewardData.RewardType.GUN_CARDS:
				_show_gun_card_reward(reward)
			else:
				_on_collect_button_pressed()


func _cache_collect_button() -> void:
	if collect_button and not collect_button.pressed.is_connected(_on_collect_button_pressed):
		collect_button.pressed.connect(_on_collect_button_pressed)

	if collect_button:
		collect_ad_icon = collect_button.get_node_or_null("CollectIcon") as TextureRect


func _cache_claimed_tick() -> void:
	if not claimed_tick:
		return

	claimed_ticks.clear()
	for card in day_cards:
		var tick: TextureRect
		if card == claimed_tick.get_parent():
			tick = claimed_tick
		else:
			tick = claimed_tick.duplicate()
			card.add_child(tick)
		
		tick.visible = false
		claimed_ticks.append(tick)


func _update_card(card: Panel, reward: DailyRewardData, day: int, current_day: int, can_claim: bool) -> void:
	var title_label := card.get_node_or_null("TitleLabel") as Label
	var reward_label := card.get_node_or_null("RewardLabel") as Label
	var reward_name_label := card.get_node_or_null("RewardNameLabel") as Label
	var icon := card.get_node_or_null("Icon") as TextureRect
	var lock_icon := card.get_node_or_null("LockIcon") as TextureRect

	if title_label:
		title_label.text = "Day " + str(day)

	if reward:
		if reward_label:
			reward_label.text = reward.get_display_text()
		if reward_name_label:
			reward_name_label.text = reward.reward_name
			reward_name_label.visible = reward.reward_name != ""
		if icon and reward.icon:
			icon.texture = reward.icon

	var is_future_reward := day > current_day
	if lock_icon:
		lock_icon.visible = is_future_reward

	var is_highlighted := day == current_day and can_claim

	var glow_bg := card.get_node_or_null("GlowBg") as TextureRect
	if not glow_bg:
		glow_bg = TextureRect.new()
		glow_bg.name = "GlowBg"
		if day == 7:
			if day7_glow_bg: glow_bg.texture = day7_glow_bg
		else:
			if normal_glow_bg: glow_bg.texture = normal_glow_bg
		glow_bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		glow_bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		var glow_margin = 15
		glow_bg.offset_left = -glow_margin
		glow_bg.offset_top = -glow_margin
		glow_bg.offset_right = glow_margin
		glow_bg.offset_bottom = glow_margin
		card.add_child(glow_bg)
		card.move_child(glow_bg, 0)

	glow_bg.visible = is_highlighted

	card.modulate = Color(1, 1, 1, 1) if is_highlighted and can_claim else Color(0.85, 0.85, 0.85, 1)


func _update_collect_button(current_day: int, can_claim: bool, requires_ad: bool) -> void:
	if not collect_button or current_day < 1 or current_day > day_cards.size():
		return

	var current_card := day_cards[current_day - 1]
	if collect_button.get_parent() != current_card:
		collect_button.reparent(current_card, false)

	collect_button.visible = can_claim and requires_ad
	collect_button.disabled = not (can_claim and requires_ad)

	if collect_ad_icon:
		collect_ad_icon.visible = can_claim and requires_ad


func _update_claimed_tick(effective_day: int, can_claim: bool) -> void:
	for i in range(claimed_ticks.size()):
		var day = i + 1
		var tick = claimed_ticks[i]
		
		tick.visible = day < effective_day or (day == effective_day and not can_claim)


func _apply_reward(reward: DailyRewardData) -> void:
	var source_card := day_cards[GameManager.save_manager.get_daily_reward_current_day() - 1] as Control
	var source_icon := source_card.get_node_or_null("Icon") as Control
	if not source_icon:
		source_icon = source_card
	var current_day_num = GameManager.save_manager.get_daily_reward_current_day()
	match reward.reward_type:
		DailyRewardData.RewardType.COINS:
			GameManager.save_manager.add_coin(reward.amount)
			GameAnalysis.track_economy_event(GameAnalysis.RESOURCE_FLOW_TYPE_SOURCE, "Coins", float(reward.amount), "DailyReward", "Day_%d" % current_day_num)
			GameManager.play_currency_collection(reward.icon, reward.amount, source_icon, GameManager.ui_manager.base_panel.coin_count_label)
		DailyRewardData.RewardType.DIAMONDS:
			GameManager.save_manager.add_diamond(reward.amount)
			GameAnalysis.track_economy_event(GameAnalysis.RESOURCE_FLOW_TYPE_SOURCE, "Diamonds", float(reward.amount), "DailyReward", "Day_%d" % current_day_num)
			GameManager.play_currency_collection(reward.icon, reward.amount, source_icon, GameManager.ui_manager.base_panel.diamond_count_label, true, 1.28)
		DailyRewardData.RewardType.AVATAR:
			GameManager.save_manager.save_game_data("player_data", "profile_pic_index", reward.item_id)
		DailyRewardData.RewardType.PROFILE_FRAME:
			GameManager.save_manager.save_game_data("player_data", "profile_frame_index", reward.item_id)
		DailyRewardData.RewardType.GUN_CARDS:
			_show_gun_card_reward(reward)
		DailyRewardData.RewardType.CRATE:
			add_crate()


func add_crate():
	var free_slot_index: Array[int] = []
	for i in range(GameManager.save_manager.game_data["slots"].size()):
		if GameManager.save_manager.game_data["slots"][i].unlocked==true and GameManager.save_manager.game_data["slots"][i].occupied==false:
			free_slot_index.append(i)
	if free_slot_index.size()>=1:
		GameManager.save_manager.add_crate_to_slot(free_slot_index[0],ProgressionManager.CRATE_TYPE.GOLD,GameManager.progression_manager.get_current_gun_type())

func _show_gun_card_reward(reward: DailyRewardData) -> void:
	var all_gun_data: AllGunData = load("res://ZeroAimZone-Godot/4_Resources/Tres/all_gun_data.tres")
	if not all_gun_data or all_gun_data.all_guns.is_empty():
		return

	var guns_unlocked: Array = GameManager.save_manager.game_data["guns_data"]["guns_unlocked"]
	var selected_gun_index := int(GameManager.save_manager.game_data["guns_data"]["gun_selected_index"])
	var gun_type := int(all_gun_data.all_guns[selected_gun_index].gun_type)

	var current_tier_locked: Array[int] = []
	var all_locked: Array[int] = []

	for i in range(mini(guns_unlocked.size(), all_gun_data.all_guns.size())):
		if not bool(guns_unlocked[i]):
			all_locked.append(i)
			if all_gun_data.all_guns[i] and int(all_gun_data.all_guns[i].gun_type) == gun_type:
				current_tier_locked.append(i)

	var gun_index := -1
	if not current_tier_locked.is_empty():
		gun_index = current_tier_locked.pick_random()
	elif not all_locked.is_empty():
		gun_index = all_locked.pick_random()

	# If all guns in the game are unlocked (gun_index == -1), fallback to 100 coins reward
	if gun_index < 0:
		var current_day := GameManager.save_manager.get_daily_reward_current_day()
		var fallback_coins: int = 100
		GameManager.save_manager.add_coin(fallback_coins)
		GameAnalysis.track_economy_event(GameAnalysis.RESOURCE_FLOW_TYPE_SOURCE, "Coins", float(fallback_coins), "DailyReward_AllGunsUnlocked", "Day_%d" % current_day)
		
		var source_card: Control = null
		if current_day >= 1 and current_day <= day_cards.size():
			source_card = day_cards[current_day - 1] as Control
		var source_icon: Control = source_card.get_node_or_null("Icon") as Control if source_card else null
		if not source_icon:
			source_icon = source_card
			
		var coin_icon: Texture2D = load("res://ZeroAimZone-Godot/3_Assets/Sprites/GameUI/ShopPanel/3coins.png") if ResourceLoader.exists("res://ZeroAimZone-Godot/3_Assets/Sprites/GameUI/ShopPanel/3coins.png") else reward.icon
		if GameManager.ui_manager and GameManager.ui_manager.base_panel and GameManager.ui_manager.base_panel.coin_count_label:
			GameManager.play_currency_collection(coin_icon, fallback_coins, source_icon, GameManager.ui_manager.base_panel.coin_count_label)
		
		GameAnalysis.track_daily_reward_claim(current_day)
		GameManager.save_manager.mark_daily_reward_claimed(rewards_config.get_reward_count())
		refresh()
		return

	if GameManager.ui_manager and GameManager.ui_manager.popup_panel:
		GameManager.ui_manager.popup_panel.show_daily_gun_card_reward_popup(gun_index, reward.amount, self)


func complete_gun_card_reward() -> void:
	var current_day := GameManager.save_manager.get_daily_reward_current_day()
	var reward := rewards_config.get_reward_for_day(current_day)
	if not reward or reward.reward_type != DailyRewardData.RewardType.GUN_CARDS:
		return

	GameAnalysis.track_daily_reward_claim(current_day)
	GameManager.save_manager.mark_daily_reward_claimed(rewards_config.get_reward_count())
	refresh()


func _get_day_from_card(card: Panel) -> int:
	return int(str(card.name).replace("Day", "").replace("Card", ""))
