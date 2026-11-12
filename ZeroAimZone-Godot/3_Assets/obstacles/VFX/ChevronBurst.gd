class_name ChevronBurst
extends Node2D

@export var pulse_duration := 0.35
@export var stagger_offset := 0.06
@export var min_alpha := 0.1
@export var max_alpha := 1.0
@export var base_color := Color(1.129, 1.129, 1.129, 1.0)

var chevrons: Array[Sprite2D] = []

func _ready() -> void:
	for child in get_children():
		if child is Sprite2D:
			chevrons.append(child)
			child.modulate = Color(base_color.r, base_color.g, base_color.b, 0.0)

func set_burst_color(color: Color) -> void:
	base_color = color
	# re-apply to already-collected chevrons (alpha stays 0 until play() animates it)
	for chevron in chevrons:
		chevron.modulate = Color(base_color.r, base_color.g, base_color.b, chevron.modulate.a)

func play() -> void:
	var t := create_tween()
	t.set_parallel(true)
	for i in chevrons.size():
		var chevron := chevrons[i]
		var delay: float = i * stagger_offset
		t.tween_property(chevron, "modulate", Color(base_color.r, base_color.g, base_color.b, max_alpha), pulse_duration * 0.4)\
			.set_delay(delay).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		t.tween_property(chevron, "modulate", Color(base_color.r, base_color.g, base_color.b, 0.0), pulse_duration * 0.6)\
			.set_delay(delay + pulse_duration * 0.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	var total_time: float = (chevrons.size() - 1) * stagger_offset + pulse_duration
	await get_tree().create_timer(total_time).timeout
	queue_free()
