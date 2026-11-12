class_name ChestPopupController
extends BasePopupController

@export var close_button: TextureButton
@export var pointer: TextureRect
@export var max_coin: Label
@export var max_diamond: Label
@export var max_card: Label

@onready var unlock_in_parallel_button: Button = $MainContainer/HBoxContainer/Button
@onready var open_now_button: Button = $MainContainer/HBoxContainer/Button2
@export var open_now_cost_label: Label
@onready var chest_icon: TextureRect = $MainContainer/TextureRect
@onready var chest_title_label: Label = $MainContainer/Label

var crate_slot: CrateSlotController


func get_open_now_cost() -> int:
	if not is_instance_valid(crate_slot):
		return 1
	var remaining_seconds: int = 0
	if crate_slot.crate_unlock_time != null:
		remaining_seconds = maxi(0, int(crate_slot.crate_unlock_time) - TimeManager.get_unix_time())
	else:
		remaining_seconds = maxi(0, crate_slot.unlock_duration_seconds)

	if remaining_seconds <= 0:
		return 0

	var remaining_minutes: float = float(remaining_seconds) / 60.0
	var cost: int = 1
	if remaining_minutes <= 30.0:
		cost = int(ceil(remaining_minutes / 6.0))
	elif remaining_minutes <= 120.0:
		cost = 5 + int(ceil((remaining_minutes - 30.0) / 9.0))
	elif remaining_minutes <= 480.0:
		cost = 15 + int(ceil((remaining_minutes - 120.0) / 14.4))
	else:
		cost = 40 + int(ceil((remaining_minutes - 480.0) / 20.0))

	return maxi(1, cost)


func update_cost_ui() -> void:
	if open_now_cost_label:
		open_now_cost_label.text = str(get_open_now_cost())


func _process(_delta: float) -> void:
	if visible and is_instance_valid(crate_slot):
		update_cost_ui()


func _ready() -> void:
	super._ready()
	if not pointer and has_node("MainContainer/TextureRect2"):
		pointer = get_node("MainContainer/TextureRect2") as TextureRect
	if not chest_title_label and has_node("MainContainer/Label"):
		chest_title_label = get_node("MainContainer/Label") as Label

	if main_container:
		main_container.z_index = 5

	close_button.pressed.connect(_close_popup)
	unlock_in_parallel_button.pressed.connect(_on_unlock_in_parallel_pressed)
	open_now_button.pressed.connect(_on_open_now_pressed)


func _notification(what: int) -> void:
	if what == NOTIFICATION_VISIBILITY_CHANGED:
		if not visible and is_instance_valid(crate_slot):
			crate_slot.set_highlighted(false)
	elif what == NOTIFICATION_RESIZED:
		if visible:
			_update_pointer_position()


func setup(slot: CrateSlotController) -> void:
	if crate_slot and crate_slot != slot and is_instance_valid(crate_slot):
		crate_slot.set_highlighted(false)

	crate_slot = slot

	if crate_slot and is_instance_valid(crate_slot):
		crate_slot.set_highlighted(true)

	if crate_slot and crate_slot.crate_database:
		var crate_info = crate_slot.crate_database.Crates[crate_slot.crate_type]
		if chest_icon and crate_info.chest_icon:
			chest_icon.texture = crate_info.chest_icon
		if chest_title_label:
			var type_name = ProgressionManager.CRATE_TYPE.keys()[crate_slot.crate_type]
			chest_title_label.text = type_name.to_upper() + " CHEST"

		var m_coin := 0
		var m_diamond := 0
		var min_card:=1
		var m_card := 1
		
		for reward in crate_info.rewards:
			if reward.contains == CrateReward.Contains.COIN:
				m_coin = maxi(m_coin, reward.max_coin)
			elif reward.contains == CrateReward.Contains.DIAMOND:
				m_diamond = maxi(m_diamond, reward.max_diamond)
			elif reward.contains == CrateReward.Contains.GUNCARD:
				m_card = maxi(m_card, reward.max_cards)
				min_card=reward.min_cards
				
		var are_all_guns_unlocked := false
		if GameManager and GameManager.save_manager and GameManager.save_manager.game_data.has("guns_data") and GameManager.save_manager.game_data["guns_data"].has("guns_unlocked"):
			var u_list: Array = GameManager.save_manager.game_data["guns_data"]["guns_unlocked"]
			if not u_list.is_empty():
				are_all_guns_unlocked = true
				for u in u_list:
					if not bool(u):
						are_all_guns_unlocked = false
						break

		if max_coin:
			max_coin.text = str(m_coin)
		if max_diamond:
			max_diamond.text = str(m_diamond)
		if max_card:
			if are_all_guns_unlocked:
				max_card.text = "0"
			else:
				max_card.text = "x"+str(min_card)+" - " + str(m_card)

	update_cost_ui()
	_update_pointer_position()
	call_deferred("_update_pointer_position")


func show_popup() -> void:
	update_cost_ui()
	_update_pointer_position()
	super.show_popup()


func hide_popup() -> void:
	super.hide_popup()
	if is_instance_valid(crate_slot):
		crate_slot.set_highlighted(false)


func _update_pointer_position() -> void:
	if not pointer:
		if has_node("MainContainer/TextureRect2"):
			pointer = get_node("MainContainer/TextureRect2") as TextureRect
		else:
			return

	if not is_instance_valid(crate_slot) or not crate_slot.is_inside_tree():
		pointer.visible = false
		return

	if not is_instance_valid(main_container):
		return

	pointer.visible = true

	var slot_center_x: float = crate_slot.get_global_rect().get_center().x
	var container_unscaled_left: float = global_position.x + main_container.position.x
	var local_x: float = slot_center_x - container_unscaled_left
	var pointer_width: float = pointer.size.x if pointer.size.x > 0.0 else (pointer.offset_right - pointer.offset_left)
	if pointer_width <= 0.0:
		pointer_width = 80.0

	var min_x: float = 15.0
	var max_x: float = maxf(min_x, main_container.size.x - pointer_width - 15.0)
	var target_left: float = clampf(local_x - pointer_width * 0.5, min_x, max_x)

	pointer.offset_left = target_left
	pointer.offset_right = target_left + pointer_width


func _close_popup() -> void:
	var popup_panel := get_parent() as PopupPanelController
	if popup_panel:
		popup_panel.hide_popup()
	else:
		hide_popup()


func _on_unlock_in_parallel_pressed() -> void:
	var slot_to_unlock := crate_slot
	_close_popup()
	if is_instance_valid(slot_to_unlock):
		var tier_name: String = slot_to_unlock.get_crate_tier_name() if slot_to_unlock.has_method("get_crate_tier_name") else "chest"
		var placement := "chest_unlock_parallel_" + tier_name
		AdManager.show_rewarded(placement, func():
			if is_instance_valid(slot_to_unlock):
				slot_to_unlock.unlock()
		)


func _on_open_now_pressed() -> void:
	var cost := get_open_now_cost()
	if cost > 0:
		if crate_slot == null or int(GameManager.save_manager.game_data["currency"]["Diamonds"]) < cost:
			if GameManager.ui_manager and GameManager.ui_manager.popup_panel and GameManager.ui_manager.popup_panel.insufficient_diamonds_popup:
				GameManager.ui_manager.popup_panel.insufficient_diamonds_popup.header_label.text = "not enough gems"
				GameManager.ui_manager.popup_panel.insufficient_diamonds_popup.text_label.text = "Top up to get more gems or play to earn."
				GameManager.ui_manager.popup_panel.show_insufficient_diamonds_popup()
			return

		GameManager.save_manager.use_diamond(cost)
		GameAnalysis.track_economy_event(GameAnalysis.RESOURCE_FLOW_TYPE_SINK, "Diamonds", float(cost), "SpeedUp", "Chest_OpenNow")

	var slot_to_open := crate_slot
	_close_popup()
	if is_instance_valid(slot_to_open):
		slot_to_open.open_immediately()
