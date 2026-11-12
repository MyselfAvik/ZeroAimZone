class_name NoInternetPopupController
extends BasePopupController

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	super._ready()

func _on_overlay_pressed() -> void:
	pass
