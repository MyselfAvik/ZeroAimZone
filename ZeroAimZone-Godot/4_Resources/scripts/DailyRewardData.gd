class_name DailyRewardData
extends Resource

enum RewardType {
	COINS,
	DIAMONDS,
	XP,
	AVATAR,
	PROFILE_FRAME,
	GUN_CARDS,
	CRATE
}

@export_range(1, 31) var day: int = 1
@export var reward_type: RewardType = RewardType.COINS
@export var amount: int = 1
@export var item_id: int = -1
@export var reward_key: String = ""
@export var reward_name: String = ""
@export var display_text: String = ""
@export var icon: Texture2D


func get_display_text() -> String:
	if display_text != "":
		return display_text

	return "x" + str(amount)
