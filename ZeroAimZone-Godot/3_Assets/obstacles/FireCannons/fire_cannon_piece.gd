class_name FireCannonPiece
extends Node2D

signal cannon_fired(cannon: FireCannonPiece, body: Node)

@export var flame_hitbox: Area2D
@export var damage: int = 10
@export var knockback := 800.0
@export var torque := 40.0
@export var stun_time := 0.2
@export var fire_sound: AudioStream

@onready var fire_vfx: Node2D = $Muzzle/Fire

var is_firing := false
var audio_player: AudioStreamPlayer2D

func _ready() -> void:
	flame_hitbox.monitoring = false
	flame_hitbox.body_entered.connect(_on_body_entered)
	_set_vfx_emitting(false)
	audio_player = AudioStreamPlayer2D.new()
	add_child(audio_player)
	

func start_firing() -> void:
	is_firing = true
	flame_hitbox.monitoring = true
	_set_vfx_emitting(true)

	if fire_sound and not audio_player.playing:
		if AudioPlayer.sound_enabled:
			audio_player.stream = fire_sound
			audio_player.play()
			AudioPlayer.duck_music() # Lowers the BGM

func stop_firing() -> void:
	is_firing = false
	flame_hitbox.monitoring = false
	_set_vfx_emitting(false)

	if audio_player.playing:
		audio_player.stop()

	AudioPlayer.unduck_music() # Restores the BGM

func _set_vfx_emitting(value: bool) -> void:
	if fire_vfx.has_method("start_firing") and fire_vfx.has_method("stop_firing"):
		if value:
			fire_vfx.start_firing()
		else:
			fire_vfx.stop_firing()
	else:
		for child in fire_vfx.get_children():
			if child is CPUParticles2D or child is GPUParticles2D:
				child.emitting = value

func _on_body_entered(body: Node) -> void:
	if !is_firing:
		return
	if body.has_method("apply_impact"):
		print("Gun hit by fire: ", body.name)

	cannon_fired.emit(self, body)  
