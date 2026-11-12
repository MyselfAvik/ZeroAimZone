extends Label

@export var reveal_duration: float = 1.5  # total time to reveal all letters

func _ready() -> void:
	pivot_offset = size / 2.0
	visible_ratio = 0.0
	modulate.a = 0.0
	scale = Vector2(0.9, 0.9)

func play_round_animation(res:bool) -> void:
	if res==true:
		text="VICTORY"
	else:
		text="DEFEAT"
	scale = Vector2(0.9, 0.9)
	modulate.a = 0.0
	visible_ratio = 0.0
	show()

	var pop_tween := create_tween()
	pop_tween.set_parallel(true)
	pop_tween.tween_property(self, "scale", Vector2(1.0, 1.0), 0.25) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	pop_tween.tween_property(self, "modulate:a", 1.0, 0.15)

	# Reveal letters one by one
	var reveal_tween := create_tween()
	reveal_tween.tween_property(self, "visible_ratio", 1.0, reveal_duration) \
		.set_trans(Tween.TRANS_LINEAR)

	await reveal_tween.finished
	await get_tree().create_timer(0.75).timeout
	hide()
