class_name DailyGunCardRewardController
extends BasePopupController

@export var gun_image: TextureRect
@export var gun_name_label: Label
@export var reward_label: Label
@export var collect_button: Button

var _gun_index: int
var _card_amount: int
var _daily_reward: DailyRewardController

func _ready() -> void:
	super._ready()
	if collect_button and not collect_button.pressed.is_connected(_on_collect_pressed):
		collect_button.pressed.connect(_on_collect_pressed)

func setup(gun_index: int, card_amount: int, daily_reward: DailyRewardController) -> void:
	_gun_index = gun_index
	_card_amount = card_amount
	_daily_reward = daily_reward

	var all_gun_data: AllGunData = load("res://ZeroAimZone-Godot/4_Resources/Tres/all_gun_data.tres")
	if not all_gun_data or gun_index < 0 or gun_index >= all_gun_data.all_guns.size():
		return

	var gun_data := all_gun_data.all_guns[gun_index]
	if gun_image:
		gun_image.texture = gun_data.get_gun_texture(0)
	if gun_name_label:
		gun_name_label.text = gun_data.name
	if reward_label:
		reward_label.text = "Congratulations you earned the gun card"
	if collect_button:
		collect_button.disabled = false

func _on_collect_pressed() -> void:
	if not _daily_reward:
		return

	var was_unlocked_before: bool = false
	if GameManager.save_manager.game_data.has("guns_data") and GameManager.save_manager.game_data["guns_data"].has("guns_unlocked") and _gun_index >= 0 and _gun_index < GameManager.save_manager.game_data["guns_data"]["guns_unlocked"].size():
		was_unlocked_before = bool(GameManager.save_manager.game_data["guns_data"]["guns_unlocked"][_gun_index])

	GameManager.save_manager.cards_update(_gun_index, _card_amount)

	var is_unlocked_now: bool = false
	if GameManager.save_manager.game_data.has("guns_data") and GameManager.save_manager.game_data["guns_data"].has("guns_unlocked") and _gun_index >= 0 and _gun_index < GameManager.save_manager.game_data["guns_data"]["guns_unlocked"].size():
		is_unlocked_now = bool(GameManager.save_manager.game_data["guns_data"]["guns_unlocked"][_gun_index])

	var current_day_num := GameManager.save_manager.get_daily_reward_current_day()
	var gun_name_str := "Gun_%d" % _gun_index
	var all_gun_data: AllGunData = load("res://ZeroAimZone-Godot/4_Resources/Tres/all_gun_data.tres")
	if all_gun_data and _gun_index >= 0 and _gun_index < all_gun_data.all_guns.size() and all_gun_data.all_guns[_gun_index]:
		gun_name_str = all_gun_data.all_guns[_gun_index].name
	GameAnalysis.track_economy_event(GameAnalysis.RESOURCE_FLOW_TYPE_SOURCE, "GunCards", float(_card_amount), "DailyReward", "Day_%d_%s" % [current_day_num, gun_name_str])

	_daily_reward.complete_gun_card_reward()
	hide_popup()

	if not was_unlocked_before and is_unlocked_now:
		if all_gun_data and _gun_index >= 0 and _gun_index < all_gun_data.all_guns.size() and all_gun_data.all_guns[_gun_index]:
			if GameManager.ui_manager and GameManager.ui_manager.popup_panel:
				GameManager.ui_manager.popup_panel.show_gun_reward_panel(_gun_index, all_gun_data.all_guns[_gun_index])
