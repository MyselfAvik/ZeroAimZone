class_name CurrencyCollectionAnimator
extends Control

const MAX_POOLED_ICONS := 18
const ICON_SIZE := Vector2(42.0, 42.0)
const FLIGHT_MIN_SECONDS := 0.48
const FLIGHT_MAX_SECONDS := 0.70
const ICON_LAUNCH_INTERVAL := 0.06

@export var coin_texture: Texture2D
@export var diamond_texture: Texture2D
@export var collection_sound: AudioStream

var _available_icons: Array[TextureRect] = []
var _active_icons: Array[TextureRect] = []
var _counter_tweens: Dictionary = {}

var _displayed_values: Dictionary = {}
var _target_values: Dictionary = {}


func _ready() -> void:
	position = Vector2.ZERO
	size = get_viewport_rect().size
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	for _index in MAX_POOLED_ICONS:
		_available_icons.append(_create_icon())


func collect(_currency_texture: Texture2D, amount: int, source: Control, target_label: Label, is_diamond: bool = false, icon_scale: float = 1.0) -> void:
	if amount <= 0 or not is_instance_valid(source) or not is_instance_valid(target_label):
		return

	await get_tree().process_frame

	if not is_instance_valid(source) or not is_instance_valid(target_label):
		return

	var target := target_label.get_parent() as Control
	if not is_instance_valid(target):
		target = target_label

	var icon_count := mini(clampi(int(ceil(float(amount) / 20.0)), 7, 16), amount)

	var start := source.get_global_rect().get_center()
	var end := target.get_global_rect().get_center()

	var final_total := _parse_formatted_number(target_label.text)

	var flight_texture: Texture2D = diamond_texture if is_diamond else coin_texture
	if not flight_texture:
		flight_texture = _currency_texture
	if not flight_texture:
		return

	_begin_counter(target_label, max(0, final_total - amount), final_total)

	for index in icon_count:
		var icon := _acquire_icon()
		if icon == null:
			break

		icon.texture = flight_texture
		icon.global_position = start - ICON_SIZE * 0.5
		icon.scale = Vector2.ZERO
		icon.rotation = randf_range(-0.25, 0.25)
		icon.visible = true

		var scatter := Vector2(
			randf_range(-54.0, 54.0),
			randf_range(-38.0, 28.0)
		)

		var bend := Vector2(
			randf_range(-110.0, 110.0),
			randf_range(-150.0, -64.0)
		)

		var delay := ICON_LAUNCH_INTERVAL * index
		var duration := randf_range(FLIGHT_MIN_SECONDS, FLIGHT_MAX_SECONDS)

		var count_increment := amount / icon_count
		if index < amount % icon_count:
			count_increment += 1

		_fly_icon(
			icon,
			start,
			scatter,
			bend,
			end,
			delay,
			duration,
			target,
			target_label,
			count_increment,
			icon_scale
		)


func _create_icon() -> TextureRect:
	var icon := TextureRect.new()
	icon.custom_minimum_size = ICON_SIZE
	icon.size = ICON_SIZE
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.pivot_offset = ICON_SIZE * 0.5
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.visible = false
	add_child(icon)
	return icon


func _acquire_icon() -> TextureRect:
	var icon: TextureRect

	if _available_icons.is_empty():
		icon = _create_icon()
	else:
		icon = _available_icons.pop_back()

	_active_icons.append(icon)

	return icon


func _fly_icon(
	icon: TextureRect,
	start: Vector2,
	scatter: Vector2,
	bend: Vector2,
	end: Vector2,
	delay: float,
	duration: float,
	target: Control,
	target_label: Label,
	count_increment: int,
	icon_scale: float
) -> void:

	var pop_end := start + scatter

	var tween := create_tween().set_parallel(false)

	tween.tween_interval(delay)

	var full_scale := Vector2.ONE * icon_scale

	tween.tween_property(
		icon,
		"scale",
		full_scale * 1.14,
		0.12
	).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	tween.parallel().tween_property(
		icon,
		"global_position",
		pop_end - ICON_SIZE * 0.5,
		0.12
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

	tween.tween_method(
		_move_on_curve.bind(
			icon,
			pop_end,
			pop_end + bend,
			end - ICON_SIZE * 0.5
		),
		0.0,
		1.0,
		duration
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	tween.parallel().tween_property(
		icon,
		"scale",
		full_scale * 0.24,
		duration
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)

	tween.tween_callback(
		_on_icon_arrived.bind(
			icon,
			target,
			target_label,
			count_increment
		)
	)


func _move_on_curve(
	progress: float,
	icon: TextureRect,
	from: Vector2,
	control: Vector2,
	to: Vector2
) -> void:

	var inverse := 1.0 - progress

	icon.global_position = (
		inverse * inverse * from +
		2.0 * inverse * progress * control +
		progress * progress * to
	)

	icon.rotation = sin(progress * PI) * 0.18


func _on_icon_arrived(
	icon: TextureRect,
	target: Control,
	target_label: Label,
	count_increment: int
) -> void:

	icon.visible = false
	_active_icons.erase(icon)
	_available_icons.append(icon)

	if collection_sound and has_node("/root/AudioPlayer"):
		AudioPlayer.play_sfx(collection_sound)

	_bounce(target)
	_roll_counter(target_label, count_increment)


func _begin_counter(label: Label, initial_value: int, final_total: int) -> void:
	var key := label.get_instance_id()
	
	var is_animating = false
	if _counter_tweens.has(key) and is_instance_valid(_counter_tweens[key]) and _counter_tweens[key].is_running():
		is_animating = true

	if not is_animating:
		_displayed_values[key] = initial_value
		
	_target_values[key] = final_total

	if _counter_tweens.has(key):
		if is_instance_valid(_counter_tweens[key]):
			_counter_tweens[key].kill()

	label.text = GameManager.format_number(_displayed_values[key])


func _roll_counter(label: Label, increment: int) -> void:
	if not is_instance_valid(label):
		return

	var key := label.get_instance_id()

	if _counter_tweens.has(key):
		if is_instance_valid(_counter_tweens[key]):
			_counter_tweens[key].kill()

	var from: int = _displayed_values.get(key, _parse_formatted_number(label.text))
	var to: int = from + increment
	
	if _target_values.has(key):
		to = mini(to, _target_values[key])

	_displayed_values[key] = to

	var tween := create_tween()
	_counter_tweens[key] = tween

	tween.tween_method(
		func(value: float):
			if is_instance_valid(label):
				label.text = GameManager.format_number(int(round(value))),
		float(from),
		float(to),
		0.16
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func _bounce(target: Control) -> void:
	if not is_instance_valid(target):
		return

	target.pivot_offset = target.size * 0.5

	var tween := create_tween()

	tween.tween_property(
		target,
		"scale",
		Vector2(1.12, 1.12),
		0.07
	).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	tween.tween_property(
		target,
		"scale",
		Vector2.ONE,
		0.13
	).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)

func _parse_formatted_number(text: String) -> int:
	text = text.to_upper()
	if text.ends_with("K"):
		return int(float(text.trim_suffix("K")) * 1000)
	elif text.ends_with("M"):
		return int(float(text.trim_suffix("M")) * 1000000)
	elif text.ends_with("B"):
		return int(float(text.trim_suffix("B")) * 1000000000)
	else:
		return text.to_int()
