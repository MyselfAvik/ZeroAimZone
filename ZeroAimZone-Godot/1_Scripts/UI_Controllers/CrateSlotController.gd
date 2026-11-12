class_name CrateSlotController
extends TextureButton

enum State { EMPTY, LOCKED, UNLOCKING, READY }

signal crate_opened

@export var unlock_duration_seconds: int = 60

@onready var free_slot_label: Label = $Label
@onready var crate_glow: TextureRect = $CrateGlow
@onready var glow: TextureRect = $Glow
@onready var crate_icon: TextureRect = $CrateIcon
@onready var action_button: TextureButton = $ActionButton
@onready var action_label: Label = $ActionButton/ActionLabel
@onready var ad_unlock_button: TextureButton = $AdUnlockButton
@export var unlocking_texture:Texture
@export var open_texture:Texture
@export var empty_slot_texture:Texture
@export var filled_slot_texture:Texture
@export var glow_slot_texture:Texture = preload("res://ZeroAimZone-Godot/3_Assets/Sprites/GameUI/InGamePops/ChestGlow.png")


@export var crate_database:CrateDatabase
var slot_index: int = -1
var crate_type: int = 0
var crate_unlock_time: Variant = null
var slot_uncloked:bool=false
var state: State = State.EMPTY
var _timer: Timer
var gun_type:int
var is_highlighted: bool = false

func _ready() -> void:
	if not glow_slot_texture and ResourceLoader.exists("res://ZeroAimZone-Godot/3_Assets/Sprites/GameUI/InGamePops/ChestGlow.png"):
		glow_slot_texture = load("res://ZeroAimZone-Godot/3_Assets/Sprites/GameUI/InGamePops/ChestGlow.png")
	if AuthManager:
		if not AuthManager.remote_config_received.is_connected(on_remote_fetched):
			AuthManager.remote_config_received.connect(on_remote_fetched)
		if not AuthManager.remote_config_data.is_empty():
			on_remote_fetched(AuthManager.remote_config_data)
	_timer = Timer.new()
	_timer.wait_time = 1.0
	_timer.one_shot = false
	_timer.timeout.connect(_on_tick)
	add_child(_timer)

	pressed.connect(_on_action_pressed)
	mouse_filter = Control.MOUSE_FILTER_STOP
	crate_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	crate_glow.mouse_filter = Control.MOUSE_FILTER_IGNORE

	action_button.pressed.connect(_on_action_pressed)
	ad_unlock_button.pressed.connect(_on_ad_unlock_pressed)
	if TimeManager and not TimeManager.time_synced.is_connected(_on_time_synced):
		TimeManager.time_synced.connect(_on_time_synced)

func _on_time_synced(_trusted_unix_time: int) -> void:
	if state != State.EMPTY:
		_resolve_state_from_data()
		_apply_ui()

func on_remote_fetched(data: Dictionary) -> void:
	if data.is_empty():
		return
	var raw_crate = data.get("crate_gems", data.get("Crate", null))
	if raw_crate == null:
		return
	
	var crate_remote_data: Dictionary = {}
	if raw_crate is String:
		var parsed = JSON.parse_string(raw_crate)
		if parsed is Dictionary:
			crate_remote_data = parsed
		else:
			return
	elif raw_crate is Dictionary:
		crate_remote_data = raw_crate
	else:
		return

	if crate_database == null:
		if ResourceLoader.exists("res://ZeroAimZone-Godot/4_Resources/Tres/CrateDatabase.tres"):
			crate_database = load("res://ZeroAimZone-Godot/4_Resources/Tres/CrateDatabase.tres")
		else:
			return

	if crate_database.Crates.size() > 0 and crate_database.Crates[0].rewards.size() > 1:
		if crate_remote_data.has("bronze_gems_min") and crate_remote_data.get("bronze_gems_min") != null:
			crate_database.Crates[0].rewards[1].min_diamond = int(crate_remote_data.get("bronze_gems_min"))
		if crate_remote_data.has("bronze_gems_max") and crate_remote_data.get("bronze_gems_max") != null:
			crate_database.Crates[0].rewards[1].max_diamond = int(crate_remote_data.get("bronze_gems_max"))

	if crate_database.Crates.size() > 1 and crate_database.Crates[1].rewards.size() > 1:
		if crate_remote_data.has("silver_gems_min") and crate_remote_data.get("silver_gems_min") != null:
			crate_database.Crates[1].rewards[1].min_diamond = int(crate_remote_data.get("silver_gems_min"))
		if crate_remote_data.has("silver_gems_max") and crate_remote_data.get("silver_gems_max") != null:
			crate_database.Crates[1].rewards[1].max_diamond = int(crate_remote_data.get("silver_gems_max"))

	if crate_database.Crates.size() > 2 and crate_database.Crates[2].rewards.size() > 1:
		if crate_remote_data.has("gold_gems_min") and crate_remote_data.get("gold_gems_min") != null:
			crate_database.Crates[2].rewards[1].min_diamond = int(crate_remote_data.get("gold_gems_min"))
		if crate_remote_data.has("gold_gems_max") and crate_remote_data.get("gold_gems_max") != null:
			crate_database.Crates[2].rewards[1].max_diamond = int(crate_remote_data.get("gold_gems_max"))
	
	

func set_highlighted(highlight: bool) -> void:
	is_highlighted = highlight
	if is_highlighted:
		z_as_relative = false
		z_index = 6
		mouse_filter = Control.MOUSE_FILTER_IGNORE
	else:
		z_as_relative = true
		z_index = 0
		mouse_filter = Control.MOUSE_FILTER_STOP
	_apply_ui()


func setup(index: int, slot_data: Dictionary) -> void:
	slot_index = index
	slot_uncloked = slot_data.get("unlocked", false)
	crate_type = int(slot_data.get("crate_type", 0))
	crate_unlock_time = slot_data.get("crate_unlocked_time", null)
	gun_type=slot_data.get("gun_type")
	set_has_crate(slot_data.get("occupied", false))
	set_crate_info()


func set_crate_info():
		crate_icon.texture=crate_database.Crates[crate_type].chest_icon
		if crate_database.Crates[crate_type].glow_texture:
			glow.texture = crate_database.Crates[crate_type].glow_texture
		unlock_duration_seconds=crate_database.Crates[crate_type].unlock_times_minutes*60
		
func set_has_crate(has_crate: bool) -> void:
	if !has_crate:
		state = State.EMPTY
		_apply_ui()
		return

	_resolve_state_from_data()
	_apply_ui()


func _resolve_state_from_data() -> void:
	if crate_unlock_time == null:
		state = State.LOCKED
	elif TimeManager.get_unix_time() >= int(crate_unlock_time):
		state = State.READY
	else:
		state = State.UNLOCKING


func _on_action_pressed() -> void:
	match state:
		State.LOCKED:
			if _has_another_unlocking_crate():
				GameManager.ui_manager.popup_panel.show_chest_popup(self)
				return

			unlock()

		State.READY:
			_open_crate()


func unlock() -> void:
	if state == State.LOCKED:
		GameAnalysis.track_crate_event(get_crate_tier_name(), "unlock")
		var duration: int = maxi(1, unlock_duration_seconds)
		crate_unlock_time = TimeManager.get_unix_time() + duration

		GameManager.save_manager.unlock_crate(
			slot_index,
			maxi(1, int(ceil(float(duration) / 60.0)))
		)

		state = State.UNLOCKING
		_apply_ui()




func get_crate_tier_name() -> String:
	match crate_type:
		0: return "bronze"
		1: return "silver"
		2: return "gold"
		_: return "bronze"


func _on_ad_unlock_pressed() -> void:
	if state == State.EMPTY or state == State.READY:
		return
	var placement := "unlock_chest_" + get_crate_tier_name()
	AdManager.show_rewarded(placement, func():
		_timer.stop()
		crate_unlock_time = TimeManager.get_unix_time()
		if GameManager.save_manager:
			GameManager.save_manager.game_data["slots"][slot_index]["crate_unlocked_time"] = crate_unlock_time
			GameManager.save_manager.save_data()
		state = State.READY
		_apply_ui()
	)
	


func open_immediately() -> void:
	if state == State.LOCKED or state == State.UNLOCKING:
		_open_crate()


func _open_crate() -> void:
	var target_gun_type: int = 0
	if gun_type != null and int(gun_type) >= 0:
		target_gun_type = int(gun_type)
	elif GameManager and GameManager.progression_manager:
		target_gun_type = GameManager.progression_manager.get_current_gun_type()

	var rewards = crate_database.Crates[crate_type].get_rewards(target_gun_type)
	GameManager.ui_manager.reward_panel.rewards=rewards
	GameManager.ui_manager.reward_panel.crate_database=crate_database
	GameManager.ui_manager.reward_panel.chest_crate_type=crate_type
	GameManager.ui_manager.enable_panel(UIManager.PanelType.REWARD)
	GameManager.ui_manager.reward_panel.show_reward_panel()
	GameManager.save_manager.clear_slot(slot_index)
	crate_opened.emit()
	crate_type = 0
	crate_unlock_time = null
	state = State.EMPTY
	_apply_ui()


func _has_another_unlocking_crate() -> bool:
	for index in range(GameManager.save_manager.game_data["slots"].size()):
		if index == slot_index:
			continue

		var other_slot: Dictionary = GameManager.save_manager.game_data["slots"][index]
		var unlock_time: Variant = other_slot.get("crate_unlocked_time", null)
		if other_slot.get("occupied", false) and unlock_time != null and TimeManager.get_unix_time() < int(unlock_time):
			return true

	return false


func _on_tick() -> void:
	if state != State.UNLOCKING:
		return

	if crate_unlock_time == null or TimeManager.get_unix_time() >= int(crate_unlock_time):
		state = State.READY
		_timer.stop()

	_apply_ui()


func _apply_ui() -> void:
	if is_highlighted and glow_slot_texture:
		texture_normal = glow_slot_texture
	elif state == State.EMPTY:
		if empty_slot_texture:
			texture_normal = empty_slot_texture
	else:
		if filled_slot_texture:
			texture_normal = filled_slot_texture

	free_slot_label.visible = state == State.EMPTY
	free_slot_label.text="Locked" if slot_uncloked==false else"Chest Slot"
	crate_glow.visible = state != State.EMPTY
	if is_instance_valid(glow):
		glow.visible = state != State.EMPTY
	crate_icon.visible = state != State.EMPTY
	action_button.visible = state != State.EMPTY and not is_highlighted
	disabled = is_highlighted or state == State.EMPTY or state == State.UNLOCKING
	ad_unlock_button.visible = not is_highlighted and (
		state == State.UNLOCKING
	)

	match state:
		State.EMPTY:
			action_label.text = ""
			action_button.disabled = true
			_timer.stop()

		State.LOCKED:
			action_label.text = "Unlock"
			action_button.disabled = false
			_timer.stop()

		State.UNLOCKING:
			action_button.texture_normal=unlocking_texture
			action_label.text = _format_remaining()
			action_button.disabled = true

			if _timer.is_stopped():
				_timer.start()

		State.READY:
			action_label.text = "Open"
			action_button.texture_normal = open_texture
			action_button.disabled = false
			_timer.stop()



func _format_remaining() -> String:
	if crate_unlock_time == null:
		return "0s"

	var remaining = maxi(
		0,
		int(crate_unlock_time) - TimeManager.get_unix_time()
	)

	if remaining < 60:
		return "%ds" % remaining

	if remaining < 3600:
		var mins = remaining / 60
		var seconds = remaining % 60
		return "%dm %ds" % [mins, seconds]

	var hours = remaining / 3600
	var minutes = (remaining % 3600) / 60

	return "%dh %dm" % [hours, minutes]
