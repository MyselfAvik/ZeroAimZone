class_name ArenaCardController
extends Panel

@export var reward_amount_label: Label 
@export var entry_amount_label: Label
@export var bg_btn:TextureButton
@export var logo:TextureRect
@export var logo_star: TextureRect

var reward_amount: int
var entry_amount: int
var arena_index:int
var bg_texture:Texture2D
var logo_texture:Texture2D
var logo_star_color: Color

var shine_tween: Tween


func _ready() -> void:
	visibility_changed.connect(_on_visibility_changed)


func _on_visibility_changed() -> void:
	if is_visible_in_tree():
		_spin_logo_shine()
	else:
		if shine_tween and shine_tween.is_valid():
			shine_tween.pause()


func setup() -> void:
	set_reward_and_fee_amount()


func set_reward_and_fee_amount() -> void:
	entry_amount_label.text = str(entry_amount)
	reward_amount_label.text = str(reward_amount)
	bg_btn.texture_normal=bg_texture
	logo.texture=logo_texture
	logo_star.modulate = logo_star_color


func _on_arena_select_button_pressed() -> void:
	pass


func _spin_logo_shine() -> void:
	if shine_tween and shine_tween.is_valid():
		shine_tween.play()
		return

	shine_tween = create_tween()
	shine_tween.set_loops()
	shine_tween.tween_property(logo_star, "rotation", rotation + TAU, 20.0)\
	.as_relative()\
	.set_trans(Tween.TRANS_LINEAR)
