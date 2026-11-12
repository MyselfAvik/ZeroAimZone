class_name ProNode
extends Control

@onready var progress: TextureRect = get_node_or_null("Control/Progress") as TextureRect
@onready var bg_bar_2: TextureRect = get_node_or_null("BgBar2") as TextureRect

var max_value: float = 100.0 :
	set(val):
		max_value = val
		_update_ui()

var value: float = 0.0 :
	set(val):
		value = val
		_update_ui()

func _ready():
	_update_ui()

func _update_ui():
	if not is_inside_tree():
		return
	if progress == null:
		progress = get_node_or_null("Control/Progress") as TextureRect
	if bg_bar_2 == null:
		bg_bar_2 = get_node_or_null("BgBar2") as TextureRect

	if value <= 0 or max_value <= 0:
		if progress:
			progress.position.x = -370.0
			progress.visible = false
		if bg_bar_2:
			bg_bar_2.visible = false
		return

	if progress:
		progress.visible = true
	if bg_bar_2:
		bg_bar_2.visible = true

	var percentage = clamp(value / max_value, 0.0, 1.0)
	var min_pos = -370.0
	var max_pos = -44.0
	if progress:
		progress.position.x = lerp(min_pos, max_pos, percentage)
