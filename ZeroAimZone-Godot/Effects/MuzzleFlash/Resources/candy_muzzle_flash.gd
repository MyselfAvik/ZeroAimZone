class_name CandyMuzzleFlash
extends Node2D

## Reusable candy muzzle flash. Keep instances in a pool and call play() when fired.
@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var embers: GPUParticles2D = $FlashGroup/Embers
@onready var sprinkles: GPUParticles2D = $FlashGroup/Sprinkles

func _ready() -> void:
	animation_player.animation_finished.connect(_on_animation_finished)
	reset()

func play() -> void:
	reset()
	embers.restart()
	sprinkles.restart()
	embers.emitting = true
	sprinkles.emitting = true
	animation_player.play(&"Poof_Flash")

func reset() -> void:
	animation_player.stop()
	visible = true
	embers.emitting = false
	sprinkles.emitting = false
	animation_player.play(&"RESET")

func stop() -> void:
	animation_player.stop()
	embers.emitting = false
	sprinkles.emitting = false
	visible = false

func _on_animation_finished(animation_name: StringName) -> void:
	if animation_name == &"Poof_Flash":
		stop()
