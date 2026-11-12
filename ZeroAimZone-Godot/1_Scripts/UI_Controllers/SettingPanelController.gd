class_name SettingPanelController
extends Control

@export var sfx_bg: TextureRect
@export var sfx_circle: TextureRect

@export var music_bg: TextureRect
@export var music_circle: TextureRect

@export var vibration_bg: TextureRect
@export var vibration_circle: TextureRect

@export var enabled_knob_texture: Texture2D
@export var disabled_knob_texture: Texture2D

@export var credits_btn: TextureButton
@export var privacy_policy_btn: TextureButton
@export var delete_account_btn: TextureButton

@export var version:Label

var settings: Dictionary
var _initial_settings: Dictionary = {}

const BASE_ROW_HEIGHT := 150.0





func refresh_ui(val):
	if val==1:
		settings = GameManager.save_manager.game_data["game_settings"]
		
		
		
func _ready() -> void:
	settings = GameManager.save_manager.game_data["game_settings"]
	if AuthManager != null and AuthManager.has_signal("initial_sync_completed"):
		AuthManager.initial_sync_completed.connect(refresh_ui)

	setup_toggle("sound_on", sfx_bg, sfx_circle)
	setup_toggle("music_on", music_bg, music_circle)
	setup_toggle("haptic_on", vibration_bg, vibration_circle)
	call_deferred("_sync_toggle_transforms")
	
	if credits_btn and not credits_btn.pressed.is_connected(_on_credits_btn_pressed):
		credits_btn.pressed.connect(_on_credits_btn_pressed)
	if privacy_policy_btn and not privacy_policy_btn.pressed.is_connected(_on_privacy_policy_btn_pressed):
		privacy_policy_btn.pressed.connect(_on_privacy_policy_btn_pressed)

	visibility_changed.connect(_on_visibility_changed)
	version.text=str("Version : "+ProjectSettings.get_setting("application/config/version", "1.0.0")).strip_edges()


func _on_visibility_changed() -> void:
	if is_visible_in_tree():
		_initial_settings = settings.duplicate(true)
	else:
		_flush_setting_analytics()


func _exit_tree() -> void:
	_flush_setting_analytics()


func _flush_setting_analytics() -> void:
	if _initial_settings.is_empty():
		return

	if settings.get("sound_on", true) != _initial_settings.get("sound_on", true):
		GameAnalysis.track_settings_click("SoundToggle")
	if settings.get("music_on", true) != _initial_settings.get("music_on", true):
		GameAnalysis.track_settings_click("MusicToggle")
	if settings.get("haptic_on", true) != _initial_settings.get("haptic_on", true):
		GameAnalysis.track_settings_click("VibrationToggle")

	_initial_settings.clear()


func _on_credits_btn_pressed() -> void:
	GameAnalysis.track_settings_click("Credits")
	GameManager.show_popup(PopupPanelController.PopupType.CREDITS)

func _on_privacy_policy_btn_pressed() -> void:
	GameAnalysis.track_settings_click("PrivacyPolicy")
	OS.shell_open("http://www.thegamewise.com/privacy-policy/")


func setup_toggle(setting_key: String, bg_node: TextureRect, circle_node: TextureRect) -> void:
	# Enable input on background
	bg_node.mouse_filter = Control.MOUSE_FILTER_STOP
	bg_node.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

	# Ignore input on knob
	circle_node.mouse_filter = Control.MOUSE_FILTER_IGNORE

	# Connect click event
	bg_node.gui_input.connect(
		func(event):
			_on_toggle_gui_input(event, setting_key, bg_node, circle_node)
	)
	bg_node.resized.connect(
		func() -> void:
			animate_toggle(bg_node, circle_node, settings.get(setting_key, true), false)
	)


func _sync_toggle_transforms() -> void:
	animate_toggle(sfx_bg, sfx_circle, settings.get("sound_on", true), false)
	animate_toggle(music_bg, music_circle, settings.get("music_on", true), false)
	animate_toggle(vibration_bg, vibration_circle, settings.get("haptic_on", true), false)


func _on_toggle_gui_input(
	event: InputEvent,
	setting_key: String,
	bg_node: TextureRect,
	circle_node: TextureRect
) -> void:

	if event is InputEventMouseButton \
	and event.button_index == MOUSE_BUTTON_LEFT \
	and event.pressed:

		toggle_setting(setting_key, bg_node, circle_node)
	

func toggle_setting(
	setting_key: String,
	bg_node: TextureRect,
	circle_node: TextureRect
) -> void:

	var is_on : bool = !settings.get(setting_key, true)
	settings[setting_key] = is_on

	EventBus.setting_changed.emit(setting_key, is_on)

	animate_toggle(bg_node, circle_node, is_on, true)


func animate_toggle(
	bg_node: TextureRect,
	circle_node: TextureRect,
	is_on: bool,
	animate: bool
) -> void:
	
	if is_on and enabled_knob_texture:
		circle_node.texture = enabled_knob_texture
	elif not is_on and disabled_knob_texture:
		circle_node.texture = disabled_knob_texture
	var track_size := bg_node.size
	var track_offset := Vector2.ZERO
	var knob_size := Vector2(circle_node.texture.get_size())

	if bg_node.texture:
		var source_track_size := Vector2(bg_node.texture.get_size())
		var texture_scale := minf(
			bg_node.size.x / source_track_size.x,
			bg_node.size.y / source_track_size.y
		)
		track_size = source_track_size * texture_scale
		track_offset = (bg_node.size - track_size) * 0.5
		knob_size *= texture_scale

	circle_node.size = knob_size

	var target_x := track_offset.x if not is_on else track_offset.x + track_size.x - knob_size.x
	var target_y := track_offset.y + (track_size.y - knob_size.y) * 0.5
	var target_position := Vector2(target_x, target_y)

	if animate:
		create_tween()\
			.tween_property(circle_node, "position", target_position, 0.2)\
			.set_trans(Tween.TRANS_SINE)\
			.set_ease(Tween.EASE_IN_OUT)
	else:
		circle_node.position = target_position


func _on_close_btn_pressed() -> void:
	if GameManager.ui_manager and is_instance_valid(GameManager.ui_manager.base_panel):
		GameManager.ui_manager.base_panel.close_setting_panel()


func _on_delete_pressed() -> void:
	print("delete")
	GameAnalysis.track_settings_click("DeleteAccount", "Attempt")
	GameManager.ui_manager.popup_panel.show_popup(PopupPanelController.PopupType.DELETEACCOUNT)


func _on_credits_button_pressed() -> void:
	GameManager.show_popup(PopupPanelController.PopupType.CREDITS)
