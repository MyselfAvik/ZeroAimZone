class_name GameQuitPopupController
extends BasePopupController

@export var exit_btn: Button
@export var continue_btn: Button

func _ready() -> void:
	super._ready()
	if exit_btn and not exit_btn.pressed.is_connected(_on_exit_pressed):
		exit_btn.pressed.connect(_on_exit_pressed)
	if continue_btn and not continue_btn.pressed.is_connected(_on_continue_pressed):
		continue_btn.pressed.connect(_on_continue_pressed)

func _on_exit_pressed() -> void:
	get_tree().quit()

func _on_continue_pressed() -> void:
	GameManager.ui_manager.popup_panel.hide_popup()
