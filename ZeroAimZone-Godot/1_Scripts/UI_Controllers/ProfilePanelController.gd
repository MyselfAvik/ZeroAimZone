class_name ProfilePanelController
extends Control

signal profile_avatar_frame_updated

@export_group("Panels")
@export var info_panel: Panel
@export var edit_panel: Panel

@export_group("Btn & Textures")

@export var info_name: MarginContainer
@export var edit_btn: TextureButton

@export var focus_edit_texture: Texture
@export var unfocus_edit_texture: Texture
@export var avatar_btn: TextureButton
@export var frame_btn: TextureButton
@export_group("Images")
@export var profile_pic: TextureRect
@export var profile_frame: TextureRect
@export var profile_frame_icon: TextureRect


@export_group("Grids")
@export var avatar_grid: GridContainer
@export var frame_grid: GridContainer
@export var avatar_scrollcontainer: SmoothScrollContainer
@export var frame_scrollcontainer: SmoothScrollContainer

@export_group("Labels")

@export var name_save: TextureButton
@export var warning: TextureRect
@export var warning_text: Label
@export var name_text: Label
@export var name_edit: LineEdit
@export var user_id: Label
@export var xp_progression: TextureProgressBar
@export var level_text: Label
@export var xp_countdown_text: Label
@export var win_rate_text: Label
@export var match_won_text: Label
@export var current_win_streak_text: Label
@export var best_win_streak_text: Label
@export var total_wining_coin_text: Label

@export_group("GunStats")
@export var selected_gun_texture: TextureRect
@export var selected_gun_name: Label
@export var selected_gun_damage: Label
@export var selected_gun_magazine: Label
@export var selected_gun_accuracy: Label
@export var selected_gun_reload: Label

@export var yellow_circle: Texture = preload("res://ZeroAimZone-Godot/3_Assets/Sprites/GameUI/Profile/active_points.png")
@export var gray_circle: Texture = preload("res://ZeroAimZone-Godot/3_Assets/Sprites/GameUI/Profile/inactive_points.png")

@export var damage_container: HBoxContainer
@export var accuracy_container: HBoxContainer
@export var reload_container: HBoxContainer
@export var magazine_container: HBoxContainer


@export_group("Data")
@export var avatar_frame_res: AvatarFrameList
@export var single_player_data: SinglePlayerData

var avatar_list: Array[Texture]
var frame_list: Array[Texture]
var frame_icon_list: Array[Texture]

var profile_pic_index: int = 0
var profile_frame_index: int = 0
var _initial_avatar_index: int = -1
var _initial_frame_index: int = -1
enum ProfileType {
	INFO,
	EDIT
}

var isAvatar = true
var currentType: ProfileType

var player_data
var regex := RegEx.new()
var has_letter := RegEx.new()
var blacklisted_words: Array[String] = [
	# Profanity & vulgar terms
	"fuck", "fucker", "fucking", "fck", "fuk", "fuxk", "fugg",
	"shit", "sh1t", "shite", "bullshit",
	"bitch", "b1tch", "btch", "biches",
	"asshole", "arsehole", "dumbass", "jackass", "badass",
	"bastard",
	"cunt",
	"dick", "d1ck", "dickhead", "cock", "c0ck", "cocksucker",
	"pussy", "puss",
	"slut", "whore", "hoe", "sex", "sexy",
	# Hate speech & slurs
	"nigger", "nigga", "n1gger", "n1gga", "nigg", "neger",
	"faggot", "fag",
	"retard", "r3tard",
	"nazi", "hitler",
	# Explicit content
	"porn", "porno", "xxx", "rape", "rapist", "pedophile", "pedo",
	# Hindi abusive terms & variations
	"bhenchod", "behenchod", "bhenchd", "bhnchod", "bhenchat", "benchod",
	"madarchod", "maderchod", "mdrchod", "madarjat",
	"bhosdike", "bhosadike", "bhosdi", "bhosda", "bhosad", "bsdk",
	"chutiya", "chutiye", "chutya", "chootiya", "choot", "chut",
	"gandu", "gand", "gaandu", "gandmasti", "gandfat", "gaand",
	"harami", "haraami", "haramkhor", "haramzada", "haramzade",
	"lauda", "loda", "lowda", "lund", "lodu", "lawda", "lavda",
	"randi", "rand", "raand", "rndi", "randwa", "randwe",
	"kutta", "kutte", "kutiya", "kuttiya",
	"saala", "saale", "kamina", "kamine", "jhatu",
	"bhadwa", "bhadwe", "bhadva", "chakka", "hijra", "tatte", "tatta"
]


@onready var damage_icons := damage_container.get_children()
@onready var accuracy_icons := accuracy_container.get_children()
@onready var reload_icons := reload_container.get_children()
@onready var magazine_icons := magazine_container.get_children()

func _enter_tree() -> void:
	warning.visible = false
	single_player_data.changed_data.connect(update_selected_gun)
	name_edit.text_changed.connect(check_name)

func _ready() -> void:
	currentType = ProfileType.INFO
	avatar_list = avatar_frame_res.avatar_list
	frame_list = avatar_frame_res.frame_list
	frame_icon_list = avatar_frame_res.frame_icon_list
	refresh_player_data()
	profile_pic_index = GameManager.save_manager.game_data["player_data"]["profile_pic_index"]
	profile_frame_index = GameManager.save_manager.game_data["player_data"]["profile_frame_index"]
	_initial_avatar_index = profile_pic_index
	_initial_frame_index = profile_frame_index
	update_avatar(profile_pic_index)
	update_frame(profile_frame_index)
	set_frame_and_avatar_grid()
	update_ui()
	update_selected_gun()
	toggle_choice()
	GameManager.progression_manager.progression_updated.connect(update_progression)
	GameManager.save_manager.match_statistics_updated.connect(update_statistics)
	GameManager.save_manager.player_info_updated.connect(update_profile_info)
	profile_avatar_frame_updated.connect(avatar_frame_refresh)
	regex.compile("^[A-Za-z0-9_]+$")
	has_letter.compile("^[A-Za-z]")


func refresh_player_data():
	player_data = GameManager.save_manager.game_data["player_data"]
	

func avatar_frame_refresh():
	var frame_idx = GameManager.save_manager.game_data["player_data"]["profile_frame_index"]
	profile_pic.texture = avatar_list[GameManager.save_manager.game_data["player_data"]["profile_pic_index"]]
	profile_frame.texture = frame_list[frame_idx]

func update_profile_info():
	refresh_player_data()
	name_text.text = player_data["name"]
	name_edit.text = str(player_data["name"])
	user_id.text = "User ID : " + str(player_data["user_id"])

func update_progression():
	refresh_player_data()
	var current_level: int = int(player_data.get("level", 1))
	var current_xp: int = int(player_data.get("xp", 0))
	var max_level: int = GameManager.progression_manager.LEVEL_XP_REQUIRED.size() if GameManager and GameManager.progression_manager else 100
	
	if current_level >= max_level:
		var last_xp_req: int = GameManager.progression_manager.LEVEL_XP_REQUIRED[max_level - 1]
		xp_countdown_text.text = "MAX"
		xp_progression.max_value = last_xp_req
		xp_progression.value = last_xp_req
	else:
		var req_xp: int = GameManager.progression_manager.LEVEL_XP_REQUIRED[clampi(current_level - 1, 0, max_level - 1)]
		xp_countdown_text.text = "%s / %s" % [current_xp, req_xp]
		xp_progression.max_value = req_xp
		xp_progression.value = current_xp
	level_text.text = str(current_level)


func update_statistics() -> void:
	refresh_player_data()
	var total_games: int = int(player_data["total_game_played"])
	var won_games: int = int(player_data["win_game"])
	var win_rate: float = 0.0 if total_games == 0 else (float(won_games) / total_games) * 100.0
	win_rate_text.text = "%.1f%%" % win_rate
	match_won_text.text = "%s / %s" % [won_games, total_games]
	current_win_streak_text.text = str(player_data["current_win_streak"])
	best_win_streak_text.text = str(player_data["best_win_streak"])
	total_wining_coin_text.text = str(player_data["total_coins_winings"])


func update_selected_gun():
	if single_player_data == null:
		return
	if selected_gun_texture:
		selected_gun_texture.texture = single_player_data.selected_gun_texture
	if selected_gun_name:
		selected_gun_name.text = single_player_data.gun_name
	if selected_gun_damage:
		selected_gun_damage.text = str(int(round(single_player_data.damage)))
	if selected_gun_accuracy:
		selected_gun_accuracy.text = str(single_player_data.accuracy)
	if selected_gun_magazine:
		selected_gun_magazine.text = str(single_player_data.cartridge)
	var r_time: float = single_player_data.reload_time if single_player_data.reload_time > 0.0 else 1.8
	if selected_gun_reload:
		selected_gun_reload.text = "%.1fs" % r_time

	if damage_icons.is_empty() and damage_container:
		damage_icons = damage_container.get_children()
	if magazine_icons.is_empty() and magazine_container:
		magazine_icons = magazine_container.get_children()
	if accuracy_icons.is_empty() and accuracy_container:
		accuracy_icons = accuracy_container.get_children()
	if reload_icons.is_empty() and reload_container:
		reload_icons = reload_container.get_children()

	var dmg_b: int = clampi(int(round(single_player_data.damage / 5.5)), 1, 10)
	var mag_b: int = clampi(single_player_data.cartridge, 1, 10)
	var acc_val: float = single_player_data.accuracy if single_player_data.accuracy > 1.0 else (single_player_data.accuracy * 10.0)
	var acc_b: int = clampi(int(round(acc_val)), 1, 10)
	var rel_norm: float = clampf((3.0 - r_time) / 1.5, 0.0, 1.0)
	var rel_b: int = clampi(int(round(lerpf(2.0, 10.0, rel_norm))), 1, 10)

	for i in range(damage_icons.size()):
		damage_icons[i].texture = yellow_circle if i < dmg_b else gray_circle
	for i in range(magazine_icons.size()):
		magazine_icons[i].texture = yellow_circle if i < mag_b else gray_circle
	for i in range(accuracy_icons.size()):
		accuracy_icons[i].texture = yellow_circle if i < acc_b else gray_circle
	for i in range(reload_icons.size()):
		reload_icons[i].texture = yellow_circle if i < rel_b else gray_circle
		
		
func select_avatar(i: int):
	var avatar_unlocked = player_data.get("avatar_unlocked", [])
	if i < avatar_unlocked.size() and not avatar_unlocked[i]:
		return
		
	var old_avatar = GameManager.save_manager.game_data["player_data"].get("profile_pic_index", -1)
	if old_avatar != i:
		GameManager.save_manager.save_game_data("player_data", "profile_pic_index", i)
		update_avatar(i)
		profile_avatar_frame_updated.emit()

func buy_avatar(idx: int):
	var diamond_cost = avatar_frame_res.avatar_cost[idx] if avatar_frame_res.avatar_cost and idx < avatar_frame_res.avatar_cost.size() else 50
	if int(GameManager.save_manager.game_data["currency"]["Diamonds"]) < diamond_cost:
		if GameManager.ui_manager and GameManager.ui_manager.popup_panel:
			GameManager.ui_manager.popup_panel.show_insufficient_diamonds_popup()
		return
		
	var popup_panel = GameManager.ui_manager.popup_panel
	if not popup_panel or not popup_panel.confirm_purchase_popup:
		return
		
	var confirm_popup = popup_panel.confirm_purchase_popup
	
	_cleanup_purchase_connections(confirm_popup)
			
	confirm_popup.continue_btn.pressed.connect(_on_confirm_avatar_purchase.bind(idx))
	confirm_popup.visibility_changed.connect(_on_popup_visibility_changed.bind(confirm_popup))
	
	confirm_popup._current_data = null
	
	if confirm_popup.amount_label:
		confirm_popup.amount_label.visible = false
	if confirm_popup.continue_btn:
		confirm_popup.continue_btn.text = "Unlock"
	if confirm_popup.pack_name_label:
		confirm_popup.pack_name_label.text = "UNLOCK AVATAR"
	if confirm_popup.gem_icon:
		confirm_popup.gem_icon.texture = avatar_list[idx]
		
	popup_panel.show_popup(PopupPanelController.PopupType.CONFIRMPURCHASE)

func _cleanup_purchase_connections(confirm_popup):
	for conn in confirm_popup.continue_btn.pressed.get_connections():
		if conn["callable"].get_object() == self and (conn["callable"].get_method() == "_on_confirm_avatar_purchase" or conn["callable"].get_method() == "_on_confirm_frame_purchase"):
			confirm_popup.continue_btn.pressed.disconnect(conn["callable"])
	for conn in confirm_popup.visibility_changed.get_connections():
		if conn["callable"].get_object() == self and conn["callable"].get_method() == "_on_popup_visibility_changed":
			confirm_popup.visibility_changed.disconnect(conn["callable"])

func _on_popup_visibility_changed(confirm_popup):
	if not confirm_popup.visible:
		confirm_popup.frame_icon.visible=false
		_cleanup_purchase_connections(confirm_popup)

func _on_confirm_avatar_purchase(idx: int):
	var popup_panel = GameManager.ui_manager.popup_panel
	if popup_panel and popup_panel.confirm_purchase_popup:
		var confirm_popup = popup_panel.confirm_purchase_popup
		_cleanup_purchase_connections(confirm_popup)
		if confirm_popup._current_data != null:
			return
			
	var diamond_cost = avatar_frame_res.avatar_cost[idx] if avatar_frame_res.avatar_cost and idx < avatar_frame_res.avatar_cost.size() else 50
	if GameManager.save_manager.use_diamond(diamond_cost):
		GameAnalysis.track_economy_event(GameAnalysis.RESOURCE_FLOW_TYPE_SINK, "Diamonds", float(diamond_cost), "Avatar", "Avatar_%d" % idx)
		var avatar_unlocked = player_data.get("avatar_unlocked", [])
		if idx < avatar_unlocked.size():
			avatar_unlocked[idx] = true
			GameManager.save_manager.save_game_data("player_data", "avatar_unlocked", avatar_unlocked)
			set_frame_and_avatar_grid()


func select_frame(i: int):
	var frame_unlocked = player_data.get("frame_unlocked", [])
	if i < frame_unlocked.size() and not frame_unlocked[i]:
		return
		
	var old_frame = GameManager.save_manager.game_data["player_data"].get("profile_frame_index", -1)
	if old_frame != i:
		GameManager.save_manager.save_game_data("player_data", "profile_frame_index", i)
		update_frame(i)
		profile_avatar_frame_updated.emit()

func buy_frame(idx: int):
	var diamond_cost = avatar_frame_res.frame_cost[idx] if avatar_frame_res.frame_cost and idx < avatar_frame_res.frame_cost.size() else 50
	if int(GameManager.save_manager.game_data["currency"]["Diamonds"]) < diamond_cost:
		if GameManager.ui_manager and GameManager.ui_manager.popup_panel:
			GameManager.ui_manager.popup_panel.show_insufficient_diamonds_popup()
		return
		
	var popup_panel = GameManager.ui_manager.popup_panel
	if not popup_panel or not popup_panel.confirm_purchase_popup:
		return
		
	var confirm_popup = popup_panel.confirm_purchase_popup
	
	_cleanup_purchase_connections(confirm_popup)
	confirm_popup.continue_btn.pressed.connect(_on_confirm_frame_purchase.bind(idx))
	confirm_popup.visibility_changed.connect(_on_popup_visibility_changed.bind(confirm_popup))
	
	confirm_popup._current_data = null
	
	if confirm_popup.amount_label:
		confirm_popup.amount_label.visible = false
	if confirm_popup.continue_btn:
		confirm_popup.continue_btn.text = "Unlock"
	if confirm_popup.pack_name_label:
		confirm_popup.pack_name_label.text = "UNLOCK FRAME"
	if confirm_popup.gem_icon:
		confirm_popup.gem_icon.texture = frame_list[idx]
	if confirm_popup.frame_icon:
		confirm_popup.frame_icon.visible=true
		confirm_popup.frame_icon.texture = avatar_frame_res.frame_icon_list[idx-1]
		
	popup_panel.show_popup(PopupPanelController.PopupType.CONFIRMPURCHASE)

func _on_confirm_frame_purchase(idx: int):
	var popup_panel = GameManager.ui_manager.popup_panel
	if popup_panel and popup_panel.confirm_purchase_popup:
		var confirm_popup = popup_panel.confirm_purchase_popup
		_cleanup_purchase_connections(confirm_popup)
		confirm_popup.frame_icon.visible=false
		if confirm_popup._current_data != null:
			return
			
	var diamond_cost = avatar_frame_res.frame_cost[idx] if avatar_frame_res.frame_cost and idx < avatar_frame_res.frame_cost.size() else 50
	if GameManager.save_manager.use_diamond(diamond_cost):
		GameAnalysis.track_economy_event(GameAnalysis.RESOURCE_FLOW_TYPE_SINK, "Diamonds", float(diamond_cost), "Frame", "Frame_%d" % idx)
		var frame_unlocked = player_data.get("frame_unlocked", [])
		if idx < frame_unlocked.size():
			frame_unlocked[idx] = true
			GameManager.save_manager.save_game_data("player_data", "frame_unlocked", frame_unlocked)
			set_frame_and_avatar_grid()
	

func update_avatar(idx: int):
	profile_pic_index = idx
	profile_pic.texture = avatar_list[profile_pic_index]

	var frames := frame_grid.get_children()
	for i in frames.size():
		frames[i].get_child(1).texture = avatar_list[profile_pic_index]

	var children := avatar_grid.get_children()
	for i in children.size():
		children[i].get_child(1).visible = i == idx

func update_frame(idx: int):
	profile_frame_index = idx
	profile_frame.texture = frame_list[profile_frame_index]
	if idx > 0 and profile_frame_index - 1 < frame_icon_list.size():
		profile_frame_icon.texture = frame_icon_list[profile_frame_index - 1]
	else:
		profile_frame_icon.texture = null
	var children := frame_grid.get_children()
	for i in children.size():
		children[i].get_child(0).visible = i == idx

func set_frame_and_avatar_grid():
	var avatar_unlocked = player_data.get("avatar_unlocked", [])
	var buy_btn_template = null
	
	if avatar_grid.get_child_count() > 0:
		buy_btn_template = avatar_grid.get_child(0).get_node_or_null("BuyButton")
		
	var i = 0
	for btn in avatar_grid.get_children():
		var texture_btn := btn as TextureButton
		var idx = i
		if texture_btn:
			texture_btn.texture_normal = avatar_list[idx]
			
			var is_unlocked = false
			if idx < avatar_unlocked.size():
				is_unlocked = avatar_unlocked[idx]
				
			var buy_btn = texture_btn.get_node_or_null("BuyButton")
			if not buy_btn and buy_btn_template:
				buy_btn = buy_btn_template.duplicate()
				texture_btn.add_child(buy_btn)
				
			if buy_btn:
				var cost_label = buy_btn.get_node_or_null("Control/HBoxContainer/Label")
				var cost = avatar_frame_res.avatar_cost[idx] if avatar_frame_res.avatar_cost and idx < avatar_frame_res.avatar_cost.size() else 50
				if cost_label:
					cost_label.text = str(cost)
					
				for conn in buy_btn.pressed.get_connections():
					if conn["callable"].get_object() == self and conn["callable"].get_method() == "buy_avatar":
						buy_btn.pressed.disconnect(conn["callable"])
				buy_btn.pressed.connect(buy_avatar.bind(idx))
				
			if is_unlocked:
				texture_btn.disabled = false
				texture_btn.self_modulate = Color("ffffff")
				if texture_btn.has_node("Frame"):
					texture_btn.get_node("Frame").modulate = Color("ffffff")
				if buy_btn:
					buy_btn.visible = false
			else:
				texture_btn.disabled = false
				texture_btn.self_modulate = Color("939393c8")
				if texture_btn.has_node("Frame"):
					texture_btn.get_node("Frame").modulate = Color("939393c8")
				if buy_btn:
					buy_btn.visible = true
				
			for conn in texture_btn.pressed.get_connections():
				if conn["callable"].get_object() == self and conn["callable"].get_method() == "select_avatar":
					texture_btn.pressed.disconnect(conn["callable"])
			texture_btn.pressed.connect(select_avatar.bind(idx))
			i += 1
	i = 0
	var frame_unlocked = player_data.get("frame_unlocked", [])
	for btn in frame_grid.get_children():
		var frame_btns := btn as TextureButton
		var idx = i
		if frame_btns:
			frame_btns.texture_normal = frame_list[i]
			
			var is_unlocked = false
			if idx < frame_unlocked.size():
				is_unlocked = frame_unlocked[idx]
				
			var buy_btn = frame_btns.get_node_or_null("BuyButton")
				
			if buy_btn:
				var cost_label = buy_btn.get_node_or_null("Control/HBoxContainer/Label")
				var cost = avatar_frame_res.frame_cost[idx] if avatar_frame_res.frame_cost and idx < avatar_frame_res.frame_cost.size() else 50
				if cost_label:
					cost_label.text = str(cost)
					
				for conn in buy_btn.pressed.get_connections():
					if conn["callable"].get_object() == self and conn["callable"].get_method() == "buy_frame":
						buy_btn.pressed.disconnect(conn["callable"])
				buy_btn.pressed.connect(buy_frame.bind(idx))
				
			if is_unlocked:
				frame_btns.disabled = false
				frame_btns.self_modulate = Color("ffffff")
				if frame_btns.has_node("Frame"):
					frame_btns.get_node("Frame").modulate = Color("ffffff")
				if buy_btn:
					buy_btn.visible = false
			else:
				frame_btns.disabled = false
				frame_btns.self_modulate = Color("898989c8")
				if frame_btns.has_node("Frame"):
					frame_btns.get_node("Frame").modulate = Color("898989c8")
				if buy_btn:
					buy_btn.visible = true
					
			for conn in frame_btns.pressed.get_connections():
				if conn["callable"].get_object() == self and conn["callable"].get_method() == "select_frame":
					frame_btns.pressed.disconnect(conn["callable"])
			frame_btns.pressed.connect(select_frame.bind(idx))
			
		i += 1


func toggle_choice():
	avatar_scrollcontainer.visible = isAvatar
	frame_scrollcontainer.visible = !isAvatar
	avatar_btn.texture_normal = focus_edit_texture if isAvatar else unfocus_edit_texture
	frame_btn.texture_normal = focus_edit_texture if !isAvatar else unfocus_edit_texture
	

func update_ui():
	feed_data()
	info_panel.visible = (currentType == ProfileType.INFO)
	edit_panel.visible = (currentType == ProfileType.EDIT)
	name_edit.visible = (currentType == ProfileType.EDIT)
	name_text.visible = (currentType == ProfileType.INFO)
	edit_btn.visible = (currentType == ProfileType.INFO)
	warning.visible = false
	name_save.disabled = (currentType != ProfileType.EDIT)
	

func feed_data():
	update_profile_info()
	update_progression()
	update_statistics()
	update_selected_gun()


func _on_back_pressed() -> void:
	warning.visible = false
	name_save.disabled = false
	currentType = ProfileType.INFO
	update_ui()
	GameManager.ui_manager.base_panel.close_profile_panel()


func _on_edit_btn_pressed() -> void:
	_initial_avatar_index = profile_pic_index
	_initial_frame_index = profile_frame_index
	currentType = ProfileType.EDIT
	update_ui()
	
func check_name(_text: String):
	name_save.disabled = !validate_username()
	warning.visible = !validate_username()

func validate_username() -> bool:
	var username = name_edit.text.strip_edges()

	if username.is_empty():
		warning_text.text = "This field can't be empty"
		return false
	
	elif regex.search(username) == null:
		warning_text.text = "Invalid username format"
		return false

	elif has_letter.search(username) == null:
		warning_text.text = "First character must be a letter"
		return false

	elif is_blacklisted(username):
		warning_text.text = "Inappropriate username"
		return false
	
	return true


func is_blacklisted(username: String) -> bool:
	var clean := username.to_lower()
	
	if clean == "ass" or clean.begins_with("ass_") or clean.ends_with("_ass") or "_ass_" in clean:
		return true

	if clean in ["mc", "bc"] or clean.begins_with("mc_") or clean.begins_with("bc_") or clean.ends_with("_mc") or clean.ends_with("_bc") or "_mc_" in clean or "_bc_" in clean:
		return true

	for word in blacklisted_words:
		if word in clean:
			return true

	# Check leetspeak and underscore-separated variations (e.g. b_1_t_c_h -> bitch)
	var normalized := clean.replace("_", "")
	normalized = normalized.replace("0", "o").replace("1", "i").replace("3", "e").replace("4", "a").replace("5", "s").replace("7", "t").replace("8", "b")
	
	if normalized == "ass":
		return true

	for word in blacklisted_words:
		if word in normalized:
			return true

	return false


func save_name() -> void:
	name_save.disabled = false
	var player_name := name_edit.text.strip_edges().left(15)
	var old_name = GameManager.save_manager.game_data["player_data"].get("name", "")
	if player_name != old_name:
		GameManager.save_manager.save_game_data("player_data", "name", player_name)
		GameAnalysis.track_profile_name_changed()

func _on_continue_btn_pressed() -> void:
	warning.visible = !validate_username()

	if !validate_username():
		return

	if _initial_avatar_index != profile_pic_index:
		GameAnalysis.track_profile_avatar_changed(profile_pic_index)
		_initial_avatar_index = profile_pic_index

	if _initial_frame_index != profile_frame_index:
		GameAnalysis.track_profile_frame_changed(profile_frame_index)
		_initial_frame_index = profile_frame_index

	currentType = ProfileType.INFO
	save_name()
	update_ui()


func _on_avatar_btn_pressed() -> void:
	if isAvatar:
		return
	isAvatar = true
	toggle_choice()


func _on_frame_btn_pressed() -> void:
	if !isAvatar:
		return
	isAvatar = false
	toggle_choice()


func _on_name_save_pressed() -> void:
	if !validate_username():
		return
	save_name()
