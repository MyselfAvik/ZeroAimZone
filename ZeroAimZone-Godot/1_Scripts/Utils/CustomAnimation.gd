class_name CustomAnimation
extends Control

var effect_instance: Node

func _spawn_particle_effect(effect_scene: PackedScene, spawn_position: Vector2, parent: Control) -> void:
	effect_instance = effect_scene.instantiate()
	effect_instance.global_position = spawn_position
	parent.add_child(effect_instance)

func _clear_particle_effect() -> void:
	if effect_instance and effect_instance.is_inside_tree():
		effect_instance.queue_free()


#region UI Animations

# Card flash animation
func _play_card_flash(target: CanvasItem, duration: float = 0.7) -> void:
	if not target.material:
		return
	target.material.set_shader_parameter("flash_amount", 0.0)
	
	var t := create_tween()
	t.tween_property(target, "material:shader_parameter/flash_amount", 1.0, duration * 0.15) \
		.set_trans(Tween.TRANS_LINEAR).set_ease(Tween.EASE_OUT)
	t.tween_property(target, "material:shader_parameter/flash_amount", 0.0, duration * 0.85) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


# Card transform animation
func _card_anim(object: Control, target: Vector2, duration: float = 0.25) -> Tween:
	object.scale = Vector2.ZERO
	object.modulate.a = 0.0
	var anim := create_tween()
	anim.set_parallel(true)

	anim.tween_property(object, "global_position", target, duration) \
		.set_trans(Tween.TRANS_LINEAR).set_ease(Tween.EASE_OUT)
	anim.tween_property(object, "modulate:a", 1.0, duration) \
		.set_trans(Tween.TRANS_LINEAR).set_ease(Tween.EASE_IN)
	anim.tween_property(object, "scale", Vector2.ONE, duration) \
		.set_trans(Tween.TRANS_LINEAR).set_ease(Tween.EASE_OUT)

	return anim


# Scale animation
func _scale_anim(object:Control, duration: float = 0.2, scale_factor: float = 1.2) -> void:
	object.pivot_offset = object.size / 2
	var t := create_tween()
	t.set_parallel(true)
	t.tween_property(object, "scale", Vector2(scale_factor, scale_factor), duration * 0.5) \
		.set_trans(Tween.TRANS_LINEAR).set_ease(Tween.EASE_OUT)
	t.chain().tween_property(object, "scale", Vector2.ONE, duration * 0.5) \
		.set_trans(Tween.TRANS_LINEAR).set_ease(Tween.EASE_IN)


# Toggle visibility and scale animation
func _toggle_anim(object: Control, is_open: bool, duration: float = 0.1) -> void:
	if not is_instance_valid(object):
		return

	var t := create_tween()
	t.set_parallel(true)

	if is_open:
		object.visible = true
		t.tween_property(object, "modulate:a", 1.0, duration) \
			.set_trans(Tween.TRANS_LINEAR).set_ease(Tween.EASE_IN)
		t.tween_property(object, "scale", Vector2.ONE, duration) \
			.set_trans(Tween.TRANS_LINEAR).set_ease(Tween.EASE_IN)
	else:
		t.tween_property(object, "modulate:a", 0.0, duration) \
			.set_trans(Tween.TRANS_LINEAR).set_ease(Tween.EASE_OUT)
		t.tween_property(object, "scale", Vector2(0.8, 0.8), duration) \
			.set_trans(Tween.TRANS_LINEAR).set_ease(Tween.EASE_OUT)
		t.chain().tween_callback(func():
			if is_instance_valid(object):
				object.visible = false
		)
