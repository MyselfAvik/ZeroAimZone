class_name TCPopupController
extends BasePopupController

@export var accept_btn: Button

func _ready() -> void:
	super._ready()
	if accept_btn and not accept_btn.pressed.is_connected(_on_accept_pressed):
		accept_btn.pressed.connect(_on_accept_pressed)

func show_popup() -> void:
	super.show_popup()
	if GameAnalysis:
		GameAnalysis.track_ftue_step("terms_and_conditions_popup_shown")

func _on_accept_pressed() -> void:
	PlayerPrefs.set_bool("terms_accepted", true)
	if GameManager and GameManager.ui_manager:
		GameManager.ui_manager.terms_and_condition_accepted.emit(true)
	if GameAnalysis:
		GameAnalysis.track_ftue_step("terms_and_conditions_accepted")
	hide_popup()
