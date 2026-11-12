class_name BasePanelController
extends Control


@export var home_panel: HomePanelController
@export var setting_panel: SettingPanelController
@export var profile_panel: ProfilePanelController
@export var gun_panel: GunPanelController
@export var friend_panel: FriendPanelController
@export var shop_panel: ShopPanelController


@export var ios_diamond_texture:Texture
@export var diamond_btn:TextureButton
@export var coin_count_label: Label
@export var diamond_count_label: Label
@export var premium_currency_effect_script: Script
@export var home_avatar: TextureButton
@export var home_frame: TextureRect
@export var home_frame_icon: TextureRect
@export var avatar_frame_res: AvatarFrameList

@export var active_texture: Texture
@export var inactive_texture: Texture

@export var home_btn: TextureButton
@export var friend_btn: TextureButton
@export var gun_btn: TextureButton
@export var shop_btn: TextureButton

@export var back_btn: TextureButton

@onready var panel_map := {
	BasePanelType.HOME: home_panel,
	BasePanelType.FRIEND: friend_panel,
	BasePanelType.GUN: gun_panel,
	BasePanelType.SETTING: setting_panel,
	BasePanelType.PROFILE: profile_panel,
	BasePanelType.SHOP: shop_panel,
}

enum BasePanelType {
	HOME,
	SETTING,
	PROFILE,
	FRIEND,
	GUN,
	SHOP
}

var diamond_count: int
var coin_count: int


var current_type: BasePanelType
var previous_panel_type: BasePanelType = BasePanelType.HOME

const SWIPE_MIN_DISTANCE_X: float = 120.0
const MAX_SWIPE_DURATION_MS: int = 600
const MAIN_TABS: Array[BasePanelType] = [
	BasePanelType.HOME,
	BasePanelType.FRIEND,
	BasePanelType.GUN,
	BasePanelType.SHOP
]

var _swipe_start_pos: Vector2 = Vector2.ZERO
var _swipe_start_time: int = 0
var _is_swiping: bool = false
var _swipe_touch_id: int = -1


func _ready() -> void:
	current_type = BasePanelType.HOME
	if GameManager and GameManager.target_base_sub_panel != -1:
		current_type = GameManager.target_base_sub_panel as BasePanelType
		GameManager.target_base_sub_panel = -1

	update_btn_ui()
	enable_panel(current_type)
	update_currency()
	refresh_home_avatar()
	_add_premium_effect(coin_count_label)
	_add_premium_effect(diamond_count_label)
	GameManager.save_manager.currency_updated.connect(update_currency)
	GameManager.ui_manager.base_panel.profile_panel.profile_avatar_frame_updated.connect(refresh_home_avatar)
	if OS.get_name()=="iOS":
		diamond_btn.texture_normal=ios_diamond_texture
		diamond_btn.get_child(2).visible=true
		diamond_btn.get_child(0).visible=false
		var label=diamond_btn.get_child(1) as Label
		label.offset_left=0.5
		
	if back_btn:
		back_btn.pressed.connect(_on_back_btn_pressed)
	_update_back_and_profile_buttons()

func _input(event: InputEvent) -> void:
	if not is_visible_in_tree() or not visible:
		_is_swiping = false
		return
		
	if event is InputEventScreenTouch:
		if event.pressed:
			_swipe_start_pos = event.position
			_swipe_start_time = Time.get_ticks_msec()
			_is_swiping = true
			_swipe_touch_id = event.index
		elif _is_swiping and event.index == _swipe_touch_id:
			_is_swiping = false
			_process_swipe(event.position)
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_swipe_start_pos = event.position
			_swipe_start_time = Time.get_ticks_msec()
			_is_swiping = true
			_swipe_touch_id = -1
		elif _is_swiping and _swipe_touch_id == -1:
			_is_swiping = false
			_process_swipe(event.position)

func _process_swipe(end_pos: Vector2) -> void:
	if not is_visible_in_tree() or not visible:
		return
	if not _is_swipe_allowed():
		return
		
	var duration: int = Time.get_ticks_msec() - _swipe_start_time
	if duration > MAX_SWIPE_DURATION_MS:
		return
		
	var delta: Vector2 = end_pos - _swipe_start_pos
	var abs_x: float = abs(delta.x)
	var abs_y: float = abs(delta.y)
	
	# Must be a clearly horizontal swipe
	if abs_x < SWIPE_MIN_DISTANCE_X or abs_x <= abs_y * 1.5:
		return
		
	var current_idx: int = MAIN_TABS.find(current_type)
	if current_idx == -1:
		return
		
	if delta.x < 0:
		# Swiped Left (finger moved left) -> Next Tab: Home -> Friend -> Gun -> Shop
		if current_idx < MAIN_TABS.size() - 1:
			switch_panel(MAIN_TABS[current_idx + 1])
			if AudioPlayer:
				AudioPlayer._play_button_click()
	else:
		# Swiped Right (finger moved right) -> Previous Tab: Shop -> Gun -> Friend -> Home
		if current_idx > 0:
			switch_panel(MAIN_TABS[current_idx - 1])
			if AudioPlayer:
				AudioPlayer._play_button_click()

func _is_swipe_allowed() -> bool:
	if GameManager.ui_manager and is_instance_valid(GameManager.ui_manager.popup_panel):
		if GameManager.ui_manager.popup_panel.is_popup_visible():
			return false
	return current_type in MAIN_TABS

func _add_premium_effect(label: Label) -> void:
	if label and label.get_parent() and premium_currency_effect_script:
		var effect = premium_currency_effect_script.new()
		label.get_parent().add_child(effect)

var _transition_tween: Tween

func switch_panel(type: BasePanelType, track_analytics: bool = true, animate: bool = true):
	if current_type == type:
		return
	
	if current_type == BasePanelType.FRIEND and is_instance_valid(friend_panel) and friend_panel.is_room_active():
		if GameManager.ui_manager and is_instance_valid(GameManager.ui_manager.popup_panel):
			GameManager.ui_manager.popup_panel.show_popup(PopupPanelController.PopupType.ROOMCLOSE)
		return
	
	var prev_type = current_type
	var prev_panel: Control = panel_map.get(prev_type, null)
	var next_panel: Control = panel_map.get(type, null)
	
	if prev_type == BasePanelType.FRIEND and is_instance_valid(friend_panel):
		friend_panel.cancel_all_pending_challenges()
	
	if track_analytics:
		match type:
			BasePanelType.HOME:
				GameAnalysis.track_ui_click("UI:Clicks:Home")
			BasePanelType.FRIEND:
				GameAnalysis.track_ui_click("UI:Clicks:PrivateRoom")
			BasePanelType.GUN:
				var sub_tab := "Weapons"
				if is_instance_valid(gun_panel) and gun_panel.current_type == GunPanelController.GunPanelType.COSMETIC:
					sub_tab = "Cosmetics"
				GameAnalysis.track_ui_click("UI:Clicks:GunScreen:%s" % sub_tab)
			BasePanelType.SHOP:
				GameAnalysis.track_ui_click("UI:Clicks:Shop")
			BasePanelType.PROFILE:
				GameAnalysis.track_ui_click("UI:Clicks:Profile")
				profile_panel._on_back_pressed()
			BasePanelType.SETTING:
				GameAnalysis.track_settings_click("Open")

	current_type = type
	update_btn_ui()
	_update_back_and_profile_buttons()

	if animate and is_instance_valid(prev_panel) and is_instance_valid(next_panel) and prev_panel != next_panel:
		_animate_panel_transition(prev_type, type, prev_panel, next_panel)
	else:
		enable_panel(type)

func _animate_panel_transition(from_type: BasePanelType, to_type: BasePanelType, prev_panel: Control, next_panel: Control) -> void:
	if _transition_tween and _transition_tween.is_running():
		_transition_tween.kill()
		_reset_all_panel_transforms()

	var from_idx: int = MAIN_TABS.find(from_type)
	var to_idx: int = MAIN_TABS.find(to_type)
	
	# Determine direction based on tab index order
	var slide_width: float = size.x if size.x > 0 else 1080.0
	var direction: float = 1.0 # Moving forward / right: next panel comes from right (+X)
	if from_idx != -1 and to_idx != -1:
		direction = 1.0 if to_idx > from_idx else -1.0
	elif from_type == BasePanelType.PROFILE or from_type == BasePanelType.SETTING:
		direction = -1.0
	
	var incoming_start_x: float = slide_width * direction
	var outgoing_target_x: float = -slide_width * direction

	# Hide any other unrelated panels
	for p in panel_map.values():
		if p != prev_panel and p != next_panel and is_instance_valid(p):
			p.hide()

	# Set initial transforms
	next_panel.position.x = incoming_start_x
	next_panel.modulate.a = 0.0
	next_panel.show()

	prev_panel.position.x = 0.0
	prev_panel.modulate.a = 1.0
	prev_panel.show()

	var duration: float = 0.22
	_transition_tween = create_tween().set_parallel(true)
	_transition_tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

	# Animate incoming panel
	_transition_tween.tween_property(next_panel, "position:x", 0.0, duration)
	_transition_tween.tween_property(next_panel, "modulate:a", 1.0, duration * 0.75)

	# Animate outgoing panel fully off-screen with clean fade
	_transition_tween.tween_property(prev_panel, "position:x", outgoing_target_x, duration)
	_transition_tween.tween_property(prev_panel, "modulate:a", 0.0, duration * 0.55)

	_transition_tween.chain().tween_callback(func():
		prev_panel.hide()
		_reset_all_panel_transforms()
	)

func _reset_all_panel_transforms() -> void:
	for p in panel_map.values():
		if is_instance_valid(p):
			p.position.x = 0.0
			p.modulate = Color.WHITE

func update_currency():
	coin_count_label.text = GameManager.format_number(GameManager.save_manager.game_data["currency"]["Coins"])
	diamond_count_label.text = GameManager.format_number(GameManager.save_manager.game_data["currency"]["Diamonds"])


func refresh_home_avatar() -> void:
	var avatar_index := int(GameManager.save_manager.game_data["player_data"].get("profile_pic_index", 0))
	var frame_index := int(GameManager.save_manager.game_data["player_data"].get("profile_frame_index", 0))
	
	home_avatar.texture_normal = avatar_frame_res.avatar_list[avatar_index]
	home_frame.texture = avatar_frame_res.frame_list[frame_index]
	if frame_index > 0 and frame_index - 1 < avatar_frame_res.frame_icon_list.size():
		home_frame_icon.texture = avatar_frame_res.frame_icon_list[frame_index - 1]
	else:
		home_frame_icon.texture = null

	
func enable_panel(type: BasePanelType):
	if _transition_tween and _transition_tween.is_running():
		_transition_tween.kill()
	_reset_all_panel_transforms()
	for panel in panel_map.values():
		if is_instance_valid(panel):
			panel.hide()

	if panel_map.has(type) and is_instance_valid(panel_map[type]):
		panel_map[type].show()

func update_btn_ui():
		home_btn.texture_normal = active_texture if current_type == BasePanelType.HOME else inactive_texture
		shop_btn.texture_normal = active_texture if current_type == BasePanelType.SHOP else inactive_texture
		gun_btn.texture_normal = active_texture if current_type == BasePanelType.GUN else inactive_texture
		friend_btn.texture_normal = active_texture if current_type == BasePanelType.FRIEND else inactive_texture


func _on_home_pressed() -> void:
	switch_panel(BasePanelType.HOME)

func _on_friend_pressed() -> void:
	switch_panel(BasePanelType.FRIEND)


func _on_gun_pressed() -> void:
	switch_panel(BasePanelType.GUN)


func _on_shop_pressed() -> void:
	switch_panel(BasePanelType.SHOP)


func open_shop_section(section: CurrencyNavigation.Section) -> void:
	switch_panel(BasePanelType.SHOP, false)
	shop_panel.scroll_to_section(section)


func _on_profile_btn_pressed() -> void:
	previous_panel_type = current_type
	switch_panel(BasePanelType.PROFILE)

	
func _on_setting_btn_pressed() -> void:
	previous_panel_type = current_type
	switch_panel(BasePanelType.SETTING)

	
func _on_diamond_btn_pressed() -> void:
	if OS.get_name()=="iOS":
		return
	GameAnalysis.track_ui_click("UI:Clicks:Home:Add_Diamonds")
	CurrencyNavigation.open_shop(CurrencyNavigation.Section.GEMS)


func _on_coin_btn_pressed() -> void:
	GameAnalysis.track_ui_click("UI:Clicks:Home:Add_Coins")
	CurrencyNavigation.open_shop(CurrencyNavigation.Section.COINS)


func close_setting_panel() -> void:
	var target_panel: BasePanelType = previous_panel_type if previous_panel_type != BasePanelType.SETTING else BasePanelType.HOME
	switch_panel(target_panel)


func close_profile_panel() -> void:
	var target_panel: BasePanelType = previous_panel_type if previous_panel_type != BasePanelType.PROFILE else BasePanelType.HOME
	switch_panel(target_panel)


func _on_back_btn_pressed() -> void:
	if current_type == BasePanelType.PROFILE:
		profile_panel._on_back_pressed()
	elif current_type == BasePanelType.SETTING:
		close_setting_panel()
	else:
		_on_home_pressed()


func _update_back_and_profile_buttons() -> void:
	if not is_node_ready():
		return
	if current_type == BasePanelType.SETTING or current_type == BasePanelType.PROFILE:
		if home_avatar:
			home_avatar.visible = false
			home_avatar.disabled = true
		if back_btn:
			back_btn.visible = true
			back_btn.disabled = false
	else:
		if home_avatar:
			home_avatar.visible = true
			home_avatar.disabled = false
		if back_btn:
			back_btn.visible = false
			back_btn.disabled = true
