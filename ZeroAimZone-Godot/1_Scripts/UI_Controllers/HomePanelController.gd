class_name HomePanelController
extends Control

@export var slot_container: HBoxContainer
@export var selected_gun: TextureRect
@export var gun_shadow: TextureRect
const DAILY_GLOW_ANGLE := 0.31415927 # 18 degrees in radians.
const DAILY_GLOW_HALF_CYCLE_SECONDS := 1.75

@onready var daily_reward_glow: TextureRect = $HBoxContainer/VBoxContainer/HBoxContainer/Daily/Daily_Reward_btn/TextureRect
@onready var daily_reward_label: Label = $HBoxContainer/VBoxContainer/HBoxContainer/Daily/Daily_Reward_btn/TextureRect3/HBoxContainer/Label
@onready var daily_reward_timer_icon: TextureRect = $HBoxContainer/VBoxContainer/HBoxContainer/Daily/Daily_Reward_btn/TextureRect3/HBoxContainer/timer_icon
@onready var play_btn: TextureButton = $HBoxContainer/VBoxContainer/Control/Play_Btn
const SHINE_SHADER = preload("res://ZeroAimZone-Godot/3_Assets/Shaders/WinnerShine.gdshader")

var slots: Array
var _daily_timer_acc: float = 0.0

func _ready():
	if play_btn:
		var shader_material := ShaderMaterial.new()
		shader_material.shader = SHINE_SHADER
		play_btn.material = shader_material

	slots = slot_container.get_children()
	daily_reward_glow.resized.connect(_center_daily_reward_glow)
	_center_daily_reward_glow()
	_animate_daily_reward_glow()

	refresh_slots()
	for slot in slots:
		if slot is CrateSlotController:
			slot.crate_opened.connect(refresh_slots)
	update_gun_texture()
	GameManager.ui_manager.base_panel.profile_panel.single_player_data.changed_data.connect(update_gun_texture)

	update_daily_reward_ui()
	if GameManager.save_manager:
		GameManager.save_manager.daily_reward_claimed.connect(update_daily_reward_ui)
	if TimeManager and not TimeManager.time_synced.is_connected(_on_time_synced):
		TimeManager.time_synced.connect(_on_time_synced)

func _on_time_synced(_trusted_unix_time: int) -> void:
	refresh_slots()
	update_daily_reward_ui()

func _process(delta: float) -> void:
	if not visible:
		return
	_daily_timer_acc += delta
	if _daily_timer_acc >= 1.0:
		_daily_timer_acc = 0.0
		update_daily_reward_ui()

func _notification(what: int) -> void:
	if what == NOTIFICATION_VISIBILITY_CHANGED and visible:
		update_daily_reward_ui()

func update_daily_reward_glow_visibility() -> void:
	update_daily_reward_ui()

func update_daily_reward_ui() -> void:
	if not GameManager.save_manager:
		return

	var can_claim: bool = GameManager.save_manager.can_claim_daily_reward()

	if daily_reward_glow:
		if GameManager.custom_animation:
			GameManager.custom_animation._toggle_anim(daily_reward_glow, can_claim, 0.2)
		else:
			daily_reward_glow.visible = can_claim

	if daily_reward_label:
		if can_claim:
			daily_reward_label.text = "Claim"
			if daily_reward_timer_icon:
				daily_reward_timer_icon.visible = false
		else:
			if daily_reward_timer_icon:
				daily_reward_timer_icon.visible = true
			var time_dict = TimeManager.get_datetime_dict() if TimeManager else Time.get_time_dict_from_system()
			var remaining_seconds = 86400 - (time_dict["hour"] * 3600 + time_dict["minute"] * 60 + time_dict["second"])
			var hours = remaining_seconds / 3600
			var minutes = (remaining_seconds % 3600) / 60
			var seconds = remaining_seconds % 60
			if hours > 0:
				daily_reward_label.text = "%02dH %02dM" % [hours, minutes]
			else:
				daily_reward_label.text = "%02dM %02dS" % [minutes, seconds]
func update_gun_texture():
	var tex = GameManager.ui_manager.base_panel.profile_panel.single_player_data.selected_gun_texture
	if selected_gun:
		selected_gun.texture = tex
	if gun_shadow:
		gun_shadow.texture = tex

func _center_daily_reward_glow() -> void:
	# Changing pivot_offset does not move the TextureRect in its layout.
	daily_reward_glow.pivot_offset = daily_reward_glow.size * 0.5


func _animate_daily_reward_glow() -> void:
	var glow_tween := create_tween().set_loops()
	glow_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	glow_tween.tween_property(daily_reward_glow, "rotation", DAILY_GLOW_ANGLE, DAILY_GLOW_HALF_CYCLE_SECONDS)
	glow_tween.tween_property(daily_reward_glow, "rotation", -DAILY_GLOW_ANGLE, DAILY_GLOW_HALF_CYCLE_SECONDS * 2.0)
	glow_tween.tween_property(daily_reward_glow, "rotation", 0.0, DAILY_GLOW_HALF_CYCLE_SECONDS)


func _on_play_btn_pressed() -> void:
	GameAnalysis.track_ui_click("UI:Clicks:Home:PlayButton")
	GameAnalysis.track_screen_switch("Home", "Arena")
	GameManager.current_state = GameManager.GameState.IN_GAME_SINGLEPLAYER
	GameManager.ui_manager.enable_panel(GameManager.ui_manager.PanelType.ARENA)


func _on_daily_mission_btn_pressed() -> void:
	GameAnalysis.track_ui_click("UI:Clicks:Home:DailyReward")
	GameManager.ui_manager.popup_panel.show_popup(GameManager.ui_manager.popup_panel.PopupType.DAILYREWARD)


func _on_back_button_pressed() -> void:
	GameAnalysis.track_screen_switch("Arena", "Home")
	GameManager.ui_manager.enable_panel(UIManager.PanelType.BASE)


func refresh_slots():
	for i in range(slots.size()):
		var slot: CrateSlotController = slots[i]
		slot.setup(i, GameManager.save_manager.game_data["slots"][i])
