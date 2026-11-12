class_name UpdatePopupController
extends BasePopupController

@export var install_button: Button
@export var installing_section: Control

const PACKAGE_NAME := "com.TheGameWise.ZeroAimZone"
const PLAY_STORE_URL := "https://play.google.com/store/apps/details?id=" + PACKAGE_NAME
const APP_STORE_URL := "https://apps.apple.com/us/app/zero-aim-zone/id6762611814"

func _ready() -> void:
	super._ready()
	_reset_install_state()
	if install_button and not install_button.pressed.is_connected(_on_install_button_pressed):
		install_button.pressed.connect(_on_install_button_pressed)


func show_popup() -> void:
	_reset_install_state()
	super.show_popup()


func _on_overlay_pressed() -> void:
	# Persistent forced update: user cannot dismiss the popup by tapping the overlay
	pass

func _on_install_button_pressed() -> void:
	if install_button:
		install_button.visible = false
	if installing_section:
		installing_section.visible = true

	var url := APP_STORE_URL if OS.get_name() == "iOS" else PLAY_STORE_URL
	print("[UpdatePopup] Opening store URL: ", url)
	OS.shell_open(url)


func _reset_install_state() -> void:
	if install_button:
		install_button.visible = true
	if installing_section:
		installing_section.visible = false
