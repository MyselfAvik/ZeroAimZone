class_name GunPanelController
extends Control

@export var all_gun_data:AllGunData
@export var gun_cards:Array[GunCardController]
@export var skin_cards:Array[GunSkinContainerController]
@export var gun_stats_card_scene: PackedScene
@export var single_player_data:SinglePlayerData

@export var equipped_texture:Texture
@export var equip_texture:Texture

@export var weapon_btn:TextureButton
@export var cosmetic_btn:TextureButton

@export var active_texture:Texture
@export var inactive_texture:Texture


@export var weapon:VBoxContainer
@export var cosmetic:VBoxContainer

@export var tier_highlight: TextureRect


enum GunPanelType{
	WEAPON,
	COSMETIC
}

var current_type:GunPanelType
var current_tier_filter: GunSO.GunType = GunSO.GunType.STREET

var all_guns:Array[GunSO]
var gun_data={
	
}
var _tier_buttons: Array = []



func _ready() -> void:
	current_type=GunPanelType.WEAPON
	change_panel()
	gun_data=GameManager.save_manager.game_data["guns_data"]
	all_guns=all_gun_data.all_guns
	
	# Dynamically populate gun_cards
	var street_hbox = $HBoxContainer/VBoxContainer/Weapon/ScrollContainer/ContentVBox/StreetWeaponsScroll/MarginContainer/StreetWeaponsHBox
	var pro_hbox = $HBoxContainer/VBoxContainer/Weapon/ScrollContainer/ContentVBox/ProWeaponsScroll2/MarginContainer/ProWeaponsHBox
	var apex_hbox = $HBoxContainer/VBoxContainer/Weapon/ScrollContainer/ContentVBox/ApexWeaponsScroll2/MarginContainer/ApexWeaponsHBox
	gun_cards.clear()
	for child in street_hbox.get_children():
		if child is GunCardController: gun_cards.append(child)
	for child in pro_hbox.get_children():
		if child is GunCardController: gun_cards.append(child)
	for child in apex_hbox.get_children():
		if child is GunCardController: gun_cards.append(child)
		
	# Dynamically populate skin_cards
	var skin_vbox = $HBoxContainer/VBoxContainer/Cosmetic/ScrollContainer/ContentVBox
	skin_cards.clear()
	for child in skin_vbox.get_children():
		if child is GunSkinContainerController: 
			skin_cards.append(child)
			if not child.show_stats_requested.is_connected(show_stats):
				child.show_stats_requested.connect(show_stats)
	GameManager.save_manager.skin_list_updated.connect(update_skin_cards)
	GameManager.save_manager.skin_list_updated.connect(update_gun_card_ui)
	GameManager.save_manager.skin_list_updated.connect(_setup_single_player)

	GameManager.save_manager.gun_list_updated.connect(update_skin_cards)
	GameManager.save_manager.gun_list_updated.connect(update_gun_card_ui)
	GameManager.save_manager.gun_list_updated.connect(_setup_single_player)
	if AuthManager:
		if not AuthManager.remote_config_received.is_connected(refresh_gun_card_data):
			AuthManager.remote_config_received.connect(refresh_gun_card_data)
		if not AuthManager.remote_config_data.is_empty():
			refresh_gun_card_data(AuthManager.remote_config_data)
	update_gun_card_ui()
	connect_gun_card_methods()
	setup_skin_cards()
	
	# Connect tier selector buttons and retain their original appearance.
	_setup_tier_buttons()

	# Connect Play Again button to home panel navigation
	$HBoxContainer/VBoxContainer/Cosmetic/Control/TextureButton.pressed.connect(func():
		GameManager.ui_manager.base_panel._on_home_pressed()
	)

	# Initialize default tier filter to the equipped gun's tier
	var current_guns_data: Dictionary = GameManager.save_manager.game_data.get("guns_data", {})
	var equipped_idx: int = int(current_guns_data.get("gun_selected_index", 0))
	if equipped_idx >= 0 and equipped_idx < all_guns.size():
		current_tier_filter = all_guns[equipped_idx].gun_type
	filter_cosmetics_by_tier(current_tier_filter)

	_setup_single_player()

func refresh_gun_card_data(data: Dictionary) -> void:
	if data.is_empty():
		return
	
	var raw_cards = data.get("gun_cards_needed", null)
	if raw_cards == null:
		return

	var parsed_data = raw_cards
	if raw_cards is String:
		var parsed = JSON.parse_string(raw_cards)
		if parsed != null:
			parsed_data = parsed
		else:
			return

	if all_gun_data == null or all_gun_data.all_guns.is_empty():
		return

	# Handle case where the JSON contains nested {"gun_cards_needed": {...}}
	if parsed_data is Dictionary and parsed_data.has("gun_cards_needed"):
		var inner = parsed_data["gun_cards_needed"]
		if inner is String:
			var parsed_inner = JSON.parse_string(inner)
			if parsed_inner != null:
				parsed_data = parsed_inner
		elif inner is Dictionary or inner is Array:
			parsed_data = inner

	if parsed_data is Array:
		for i in range(mini(parsed_data.size(), all_gun_data.all_guns.size())):
			if all_gun_data.all_guns[i]:
				var val = parsed_data[i]
				if val is int or val is float or (val is String and str(val).is_valid_int()):
					all_gun_data.all_guns[i].cards_needed = int(val)
	elif parsed_data is Dictionary:
		for key in parsed_data.keys():
			if not str(key).is_valid_int():
				continue
			var idx := int(key)
			if idx >= 0 and idx < all_gun_data.all_guns.size() and all_gun_data.all_guns[idx]:
				var val = parsed_data[key]
				if val is int or val is float or (val is String and str(val).is_valid_int()):
					all_gun_data.all_guns[idx].cards_needed = int(val)

	update_gun_card_ui()

func switch_panel(type: GunPanelType):
	if current_type == type:
		return

	current_type = type
	change_panel()
	
	if current_type == GunPanelType.COSMETIC:
		var current_guns_data: Dictionary = GameManager.save_manager.game_data.get("guns_data", {})
		var equipped_idx: int = int(current_guns_data.get("gun_selected_index", 0))
		if equipped_idx >= 0 and equipped_idx < all_guns.size():
			current_tier_filter = all_guns[equipped_idx].gun_type
		update_skin_cards()

func filter_cosmetics_by_tier(tier: GunSO.GunType):
	current_tier_filter = tier
	var current_guns_data: Dictionary = GameManager.save_manager.game_data.get("guns_data", {})
	var guns_unlocked_arr: Array = current_guns_data.get("guns_unlocked", [])
	var unlocked_any = false
	for i in range(min(skin_cards.size(), all_guns.size())):
		var gun = all_guns[i]
		var is_unlocked: bool = bool(guns_unlocked_arr[i]) if i < guns_unlocked_arr.size() else false
		if gun.gun_type == tier and is_unlocked:
			skin_cards[i].visible = true
			unlocked_any = true
		else:
			skin_cards[i].visible = false

	# Show Control if no guns are unlocked/equipped in this tier, else show ScrollContainer
	$HBoxContainer/VBoxContainer/Cosmetic/ScrollContainer.visible = unlocked_any
	$HBoxContainer/VBoxContainer/Cosmetic/Control.visible = not unlocked_any

	_update_tier_selector(tier)


func _setup_tier_buttons() -> void:
	_tier_buttons = [
		$HBoxContainer/VBoxContainer/Cosmetic/TierSelector/ProBtn as Button,
		$HBoxContainer/VBoxContainer/Cosmetic/TierSelector/ProBtn2 as Button,
		$HBoxContainer/VBoxContainer/Cosmetic/TierSelector/ProBtn3 as Button,
	]
	var tiers := [GunSO.GunType.PRO, GunSO.GunType.STREET, GunSO.GunType.APEX]
	for index in range(_tier_buttons.size()):
		var button := _tier_buttons[index] as Button
		if button:
			button.flat = true
			button.pressed.connect(filter_cosmetics_by_tier.bind(tiers[index]))


func _update_tier_selector(selected_tier: GunSO.GunType) -> void:
	if tier_highlight:
		var selected_index := 0 if selected_tier == GunSO.GunType.PRO else 1 if selected_tier == GunSO.GunType.STREET else 2
		tier_highlight.anchor_left = float(selected_index) / 3.0
		tier_highlight.anchor_right = float(selected_index + 1) / 3.0
		tier_highlight.offset_left = 0.0
		tier_highlight.offset_right = 0.0

func setup_skin_cards():
	for i in range(min(skin_cards.size(), all_guns.size())):
		skin_cards[i].setup(i,all_guns[i])
		

func update_skin_cards():
	for i in range(min(skin_cards.size(), all_guns.size())):
		skin_cards[i].update(i,all_guns[i])
	filter_cosmetics_by_tier(current_tier_filter)


func update_gun_card_ui():
	for i in range(gun_cards.size()):
		var gun_card: GunCardController = gun_cards[i]
		if i >= all_guns.size():
			gun_card.visible = false
			continue
		gun_card.visible = true
		gun_card.setup_ui(i, all_guns[i])

func connect_gun_card_methods():
	for i in range(min(gun_cards.size(), all_guns.size())):
		var gun_card = gun_cards[i]
		gun_card.equiped_btn.pressed.connect(update_equiped.bind(i))
		if gun_card.info_btn:
			gun_card.info_btn.pressed.connect(show_stats.bind(i))

	

func show_stats(idx: int, skin_idx: int = 0):
	GameManager.ui_manager.popup_panel.gun_stat_popup.display_stat(all_guns[idx], skin_idx)
	GameManager.ui_manager.popup_panel.show_popup(PopupPanelController.PopupType.GUNSTAT)

func get_gun_texture(idx: int) -> Texture:
	var current_guns_data = GameManager.save_manager.game_data["guns_data"]
	return all_guns[idx].get_gun_texture(int(current_guns_data["skin_selected"][idx]))

func update_equiped(idx:int):
	var current_guns_data = GameManager.save_manager.game_data["guns_data"]
	if int(current_guns_data["gun_selected_index"]) == idx:
		return
	if idx >= 0 and idx < all_guns.size():
		GameAnalysis.track_weapons_event("equipped", all_guns[idx].name)
	GameManager.save_manager.select_gun(idx)
	_setup_single_player()


func change_panel():
	weapon.visible = current_type == GunPanelType.WEAPON
	cosmetic.visible = current_type == GunPanelType.COSMETIC
	weapon_btn.texture_normal=active_texture if current_type==GunPanelType.WEAPON else inactive_texture
	cosmetic_btn.texture_normal=active_texture if current_type==GunPanelType.COSMETIC else inactive_texture
	

func _on_cosmetic_btn_pressed() -> void:
	if current_type == GunPanelType.COSMETIC:
		return
	GameAnalysis.track_gun_screen_click("Cosmetics")
	switch_panel(GunPanelType.COSMETIC)


func _on_weapon_btn_pressed() -> void:
	if current_type == GunPanelType.WEAPON:
		return
	GameAnalysis.track_gun_screen_click("Weapons")
	switch_panel(GunPanelType.WEAPON)


func _setup_single_player():
	var current_guns_data = GameManager.save_manager.game_data["guns_data"]
	var gun_index = int(current_guns_data["gun_selected_index"])
	var skin_index = int(current_guns_data["skin_selected"][gun_index])

	single_player_data.apply_gun(all_guns[gun_index], skin_index)
