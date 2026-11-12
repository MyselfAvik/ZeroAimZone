class_name BasePopupController
extends Control

@onready var overlay: TextureButton = get_node_or_null("Overlay") as TextureButton
@onready var main_container: Control = _get_main_container()

var _transition_tween: Tween


func _ready() -> void:
	if not overlay:
		return
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.focus_mode = Control.FOCUS_NONE
	_set_overlay_children_to_ignore_mouse(overlay)
	if not overlay.pressed.is_connected(_on_overlay_pressed):
		overlay.pressed.connect(_on_overlay_pressed)


func _on_overlay_pressed() -> void:
	hide_popup()


func _set_overlay_children_to_ignore_mouse(node: Node) -> void:
	for child in node.get_children():
		if child is Control:
			child.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_set_overlay_children_to_ignore_mouse(child)


func show_popup() -> void:
	_stop_transition()
	visible = true

	if not main_container:
		return

	main_container.pivot_offset = main_container.size * 0.5
	main_container.scale = Vector2(0.85, 0.85)
	main_container.modulate.a = 0.0

	_transition_tween = create_tween().set_parallel(true)
	_transition_tween.tween_property(main_container, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_transition_tween.tween_property(main_container, "modulate:a", 1.0, 0.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


func hide_popup() -> void:
	_stop_transition()

	if not visible:
		return

	if not main_container:
		visible = false
		return

	main_container.pivot_offset = main_container.size * 0.5
	_transition_tween = create_tween().set_parallel(true)
	_transition_tween.tween_property(main_container, "scale", Vector2(0.85, 0.85), 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	_transition_tween.tween_property(main_container, "modulate:a", 0.0, 0.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	_transition_tween.chain().tween_callback(func(): visible = false)


func _stop_transition() -> void:
	if _transition_tween and _transition_tween.is_valid():
		_transition_tween.kill()


func _get_main_container() -> Control:
	var container := get_node_or_null("MainContainer") as Control
	if container:
		return container
	return get_node_or_null("PopupPanel") as Control if has_node("PopupPanel") else get_node_or_null("Panel") as Control
