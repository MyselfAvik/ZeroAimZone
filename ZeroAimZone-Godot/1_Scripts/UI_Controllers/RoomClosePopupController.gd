class_name RoomClosePopupController
extends BasePopupController


func _on_continue_pressed() -> void:
	# hide()
	GameManager.ui_manager.popup_panel.hide_popup()


func _on_close_pressed() -> void:
	GameAnalysis.track_ui_click("UI:Clicks:PrivateRoom:CloseRoom")
	if is_instance_valid(GameManager.ui_manager) and is_instance_valid(GameManager.ui_manager.base_panel) and is_instance_valid(GameManager.ui_manager.base_panel.friend_panel):
		GameManager.ui_manager.base_panel.friend_panel.cancel_all_pending_challenges()
	GameManager.network_handler.stop_host()
	if is_instance_valid(GameManager.ui_manager) and is_instance_valid(GameManager.ui_manager.base_panel) and is_instance_valid(GameManager.ui_manager.base_panel.friend_panel):
		GameManager.ui_manager.base_panel.friend_panel.reset()
	# hide()
	if is_instance_valid(GameManager.ui_manager) and is_instance_valid(GameManager.ui_manager.popup_panel):
		GameManager.ui_manager.popup_panel.hide_popup()
