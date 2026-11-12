@tool
class_name CrateReward
extends Resource

enum Contains {
	COIN,
	DIAMOND,
	AVATAR,
	FRAME,
	GUNCARD,
	SKIN
}

@export var contains: Contains:
	set(value):
		contains = value
		notify_property_list_changed()

@export var min_coin := 0
@export var max_coin := 0



@export var min_diamond := 0
@export var max_diamond := 0


@export var min_cards := 0
@export var max_cards := 0

@export_range(0, 100, 1, "suffix:%")
var probability_to_get: float = 1

func _validate_property(property: Dictionary) -> void:
	match property.name:
		"min_coin", "max_coin":
			if contains != Contains.COIN:
				property.usage = PROPERTY_USAGE_NO_EDITOR

		"min_diamond", "max_diamond":
			if contains != Contains.DIAMOND:
				property.usage = PROPERTY_USAGE_NO_EDITOR



		"min_cards", "max_cards":
			if contains != Contains.GUNCARD:
				property.usage = PROPERTY_USAGE_NO_EDITOR
