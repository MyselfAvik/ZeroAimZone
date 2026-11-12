extends Control

@export_group("Nodes")
@export var cards_container: Control
@export var left_button: TextureButton
@export var right_button: TextureButton

@export_group("Behaviour")
@export var enable_drag: bool = true
@export var enable_buttons: bool = true

@export_group("Card Size")
@export_range(0.1, 1.0)
var width_ratio = 0.75
@export_range(0.1, 1.0)
var height_ratio = 0.75
@export var card_aspect = 0.75

@export_group("Animation")
@export var animation_speed = 8.0
@export var overlap = 0.95
@export var visible_range = 1.0

@export_group("Visual")
@export var center_scale = 1.0
@export var side_scale = 0.75
@export var side_opacity = 0.6

@export_group("Dragging")
@export var drag_threshold = 12.0
@export var swipe_velocity = 0.25

var cards: Array = []
var current_index: int = 0
var current_offset: float = 0.0
var target_offset: float = 0.0
var card_width = 0.0
var card_height = 0.0
var step = 0.0

# Drag
var is_dragging = false
var has_dragged = false
var drag_start_position = Vector2.ZERO
var last_position = Vector2.ZERO
var drag_velocity_value = 0.0


func _ready():
	if cards_container == null:
		push_error("Cards Container not assigned.")
		return

	for child in cards_container.get_children():
		if child is Control:
			cards.append(child)

	target_offset = current_index
	current_offset = current_index

	if enable_buttons:
		if left_button:
			left_button.pressed.connect(previous)

		if right_button:
			right_button.pressed.connect(next)

	update_buttons()

	recalculate_layout()

	get_viewport().size_changed.connect(recalculate_layout)


func next():
	if current_index >= cards.size() - 1:
		return

	current_index += 1

	target_offset = current_index

	update_buttons()


func previous():
	if current_index <= 0:
		return

	current_index -= 1

	target_offset = current_index

	update_buttons()


func go_to(index: int):
	current_index = clamp(index, 0, cards.size() - 1)

	target_offset = current_index

	update_buttons()


func get_current_index():
	return current_index


func get_current_card():
	if cards.is_empty():
		return null

	return cards[current_index]


func _input(event):
	if !is_visible_in_tree():
		return
	if !enable_drag:
		return

	if GameManager.ui_manager.popup_panel.insufficient_diamonds_popup.is_visible_in_tree():
		return

	# Mouse Press
	if event is InputEventMouseButton:
		if event.button_index != MOUSE_BUTTON_LEFT:
			return

		if event.pressed:
			if !get_global_rect().has_point(event.global_position):
				return

			is_dragging = true
			has_dragged = false

			last_position = event.global_position
			drag_start_position = event.global_position

			drag_velocity_value = 0.0

		else:
			if is_dragging:
				is_dragging = false

				release_drag()

		return

	# Touch
	if event is InputEventScreenTouch:
		if event.pressed:
			if !get_global_rect().has_point(event.position):
				return

			is_dragging = true
			has_dragged = false

			last_position = event.position
			drag_start_position = event.position

			drag_velocity_value = 0.0

		else:
			if is_dragging:
				is_dragging = false

				release_drag()

		return

	# Ignore
	if !is_dragging:
		return


	var current_pos = Vector2.ZERO

	if event is InputEventMouseMotion:
		current_pos = event.global_position

	elif event is InputEventScreenDrag:
		current_pos = event.position

	else:
		return


	var dx = current_pos.x - last_position.x


	if !has_dragged:
		if current_pos.distance_to(drag_start_position) > drag_threshold:
			has_dragged = true


	drag_velocity_value = lerp(
		drag_velocity_value,
		- dx / max(step, 1),
		0.35
	)

	target_offset -= dx / max(step, 1)

	last_position = current_pos

	get_viewport().set_input_as_handled()


# RELEASE DRAG
func release_drag():
	if abs(drag_velocity_value) > swipe_velocity:
		target_offset += sign(drag_velocity_value)

	target_offset = round(target_offset)

	target_offset = clamp(
		target_offset,
		0,
		cards.size() - 1
	)

	current_index = int(target_offset)

	update_buttons()


# PROCESS
func _process(delta):
	# Smooth animation
	current_offset = lerp(
		current_offset,
		float(target_offset),
		animation_speed * delta
	)

	var center = cards_container.size / 2.0

	for i in range(cards.size()):
		var card: Control = cards[i]
		var play_button = card.get_child(0) as TextureButton
		play_button.mouse_filter = play_button.MOUSE_FILTER_STOP if i == current_index else play_button.MOUSE_FILTER_IGNORE

		var rel = float(i) - current_offset

		# Hide far cards
		if abs(rel) > float(visible_range) + 0.5:
			card.visible = false
			continue

		card.visible = true

		var t = clamp(abs(rel), 0.0, 1.0)

		# Scale
		var scale_value = lerp(
			center_scale,
			side_scale,
			t
		)

		card.scale = Vector2.ONE * scale_value

		# Opacity
		var alpha = lerp(
			1.0,
			side_opacity,
			t
		)

		card.modulate = Color(
			1,
			1,
			1,
			alpha
		)

		# Position
		# Keep spacing perfectly symmetric

		var x = center.x + rel * step
		var y = center.y

		card.position = Vector2(
			x - card_width / 2.0,
			y - card_height / 2.0
		)


# RESPONSIVE LAYOUT
func recalculate_layout():
	await get_tree().process_frame	

	var w = cards_container.size.x
	var h = cards_container.size.y

	if w <= 0:
		w = size.x

	if h <= 0:
		h = size.y

	var max_width = w * width_ratio
	var max_height = h * height_ratio

	# Maintain aspect ratio
	card_width = min(
		max_width,
		max_height * card_aspect
	)

	card_height = card_width / card_aspect

	# Distance between centres of cards
	step = card_width * overlap

	for card in cards:

		card.size = Vector2(
			card_width,
			card_height
		)

		card.pivot_offset = Vector2(
			card_width / 2.0,
			card_height / 2.0
		)


# BUTTON VISIBILITY
func update_buttons():
	if !enable_buttons:
		return

	if left_button:
		left_button.visible = current_index > 0

	if right_button:
		right_button.visible = current_index < cards.size() - 1


# ENABLE / DISABLE
func set_drag_enabled(value: bool):
	enable_drag = value


func set_buttons_enabled(value: bool):
	enable_buttons = value

	if left_button:
		left_button.visible = value and current_index > 0

	if right_button:
		right_button.visible = value and current_index < cards.size() - 1


# PUBLIC API
func refresh():
	recalculate_layout()


func set_overlap(value):
	overlap = value
	step = card_width * overlap


func set_center_scale(value):
	center_scale = value


func set_side_scale(value):
	side_scale = value


func set_side_opacity(value):
	side_opacity = value


func get_card_count():
	return cards.size()


func is_first():
	return current_index == 0


func is_last():
	return current_index == cards.size() - 1
