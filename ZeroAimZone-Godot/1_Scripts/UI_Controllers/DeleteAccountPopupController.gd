class_name DeleteAccountPopupController
extends BasePopupController

@export var yes_button: Button
@export var no_button: Button


func _on_no_pressed() -> void:
	hide()


func _on_yes_pressed() -> void:
	hide()
	AuthManager.delete_user_account()
	GameManager.ui_manager.enable_panel(UIManager.PanelType.LOADING)
	GameManager.ui_manager.base_panel._on_home_pressed()
