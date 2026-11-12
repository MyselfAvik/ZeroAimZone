extends ScrollContainer

@export var parent_scroll: ScrollContainer

var dragging := false
var direction_locked := false
var horizontal_drag := false

const THRESHOLD := 10.0

func _gui_input(event):
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				dragging = true
				direction_locked = false
				parent_scroll.mouse_filter = Control.MOUSE_FILTER_PASS
			else:
				dragging = false
				parent_scroll.mouse_filter = Control.MOUSE_FILTER_PASS

	elif event is InputEventMouseMotion and dragging:
		if !direction_locked:
			var total = event.position

			if total.length() < THRESHOLD:
				return

			horizontal_drag = abs(event.relative.x) > abs(event.relative.y)
			direction_locked = true

			if horizontal_drag:
				# Block parent from scrolling
				parent_scroll.mouse_filter = Control.MOUSE_FILTER_IGNORE

		if horizontal_drag:
			scroll_horizontal -= int(event.relative.x)
		else:
			parent_scroll.scroll_vertical -= int(event.relative.y)

		accept_event()
