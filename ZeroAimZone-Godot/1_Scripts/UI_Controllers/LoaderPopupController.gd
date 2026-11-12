class_name LoaderPopupController
extends BasePopupController

@export_group("Loader")
@export var bullet_loader: TextureRect

var spinning := false

@export var rotation_speed := 60.0
@export var target_speed := 60.0
const SLOW_SPEED := 300.0
const FAST_SPEED := 500.0
const ACCELERATION := 500.0

func _ready() -> void:
	super._ready()
	rotate_loader()


func _process(delta: float) -> void:
	if !spinning:
		return
	
	rotation_speed = move_toward(rotation_speed, target_speed, ACCELERATION * delta)
	bullet_loader.rotation += deg_to_rad(rotation_speed) * delta


# Call this function to start the loader popup animation 
func rotate_loader():
	spinning = true
	var fast_time = randf_range(1.0, 2.0)
	var slow_time = randf_range(2.0, 3.5)

	while spinning:
		target_speed = FAST_SPEED
		create_tween()\
			.tween_property(bullet_loader, "modulate:a", 1.0, fast_time)\
			.set_trans(Tween.TRANS_SINE)\
			.set_ease(Tween.EASE_IN_OUT)
		await get_tree().create_timer(fast_time).timeout

		target_speed = SLOW_SPEED
		create_tween()\
			.tween_property(bullet_loader, "modulate:a", 0.5, slow_time)\
			.set_trans(Tween.TRANS_SINE)\
			.set_ease(Tween.EASE_IN_OUT)		
		await get_tree().create_timer(slow_time).timeout
