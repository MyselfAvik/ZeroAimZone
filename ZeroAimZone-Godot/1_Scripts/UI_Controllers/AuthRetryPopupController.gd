class_name AuthRetryPopupController
extends BasePopupController

@export var title_label: Label
@export var message_label: Label
@export var retry_button: Button

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	super._ready()
	if retry_button and not retry_button.pressed.is_connected(_on_retry_pressed):
		retry_button.pressed.connect(_on_retry_pressed)

func _on_overlay_pressed() -> void:
	# Persistent auth popup: player cannot dismiss just by tapping background
	pass

func set_message(custom_message: String = "") -> void:
	if message_label:
		if not custom_message.is_empty():
			message_label.text = custom_message
		else:
			message_label.text = "Authentication and online connection are required to play. Please check your internet connection and try again."

func _on_retry_pressed() -> void:
	print("[AuthRetryPopup] User tapped Retry.")
	hide_popup()
	if GameManager and GameManager.ui_manager and GameManager.ui_manager.loading_panel:
		GameManager.ui_manager.loading_panel.retry_auth_flow()
	elif AuthManager:
		if AuthManager.has_method("retry_authentication"):
			AuthManager.retry_authentication()
		elif AuthManager.has_method("reset_flags"):
			AuthManager.reset_flags()
			AuthManager._start_auth_sequence()
