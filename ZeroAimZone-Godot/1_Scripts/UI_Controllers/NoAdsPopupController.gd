class_name NoAdsPopupController
extends BasePopupController

@export var header_label: Label
@export var text_label: Label

func _on_overlay_pressed() -> void:
	hide_popup()
