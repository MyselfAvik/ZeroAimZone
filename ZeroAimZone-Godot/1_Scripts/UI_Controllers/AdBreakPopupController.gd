class_name AdBreakPopupController
extends BasePopupController


func _ready() -> void:
	super._ready()
	if main_container:
		_set_content_children_to_ignore_mouse(main_container)
		main_container.gui_input.connect(_on_content_gui_input)

	if AdManager:
		AdManager.rewarded_ad_closed.connect(_on_ad_closed)
		AdManager.interstitial_ad_closed.connect(func(_p): _on_ad_closed(false, _p))


func _on_ad_closed(_earned: bool = false, _placement: String = "") -> void:
	if visible:
		hide_popup()


func _on_content_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		hide_popup()


func _set_content_children_to_ignore_mouse(node: Node) -> void:
	for child in node.get_children():
		if child is Control:
			child.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_set_content_children_to_ignore_mouse(child)
