class_name FireEffect
extends Node2D

@onready var sprite: Sprite2D = $Sprite2D
@onready var animation_player: AnimationPlayer = $AnimationPlayer

var is_firing := false

func _ready() -> void:
	sprite.visible = false
	if animation_player:
		animation_player.animation_finished.connect(_on_animation_finished)

func start_firing() -> void:
	is_firing = true
	sprite.visible = true
	if animation_player:
		animation_player.play(&"fire_start")

func stop_firing() -> void:
	is_firing = false
	if animation_player:
		if animation_player.current_animation == &"fire_loop" or animation_player.current_animation == &"fire_start":
			animation_player.play(&"fire_stop")
		elif animation_player.is_playing():
			pass
		else:
			sprite.visible = false

func _on_animation_finished(anim_name: StringName) -> void:
	if anim_name == &"fire_start":
		if is_firing:
			animation_player.play(&"fire_loop")
		else:
			animation_player.play(&"fire_stop")
	elif anim_name == &"fire_stop":
		sprite.visible = false
