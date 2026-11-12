class_name GunCardController
extends Panel

@export var gun_name: Label
@export var lock_icon: TextureRect
@export var progress_bar: Control
@export var progress_bar_label: Label
@export var gun_image: TextureRect
@export var equiped_text: Label
@export var equiped_btn: TextureButton
@export var info_btn: TextureButton
@export var card: Control
@export var index: int
var gun_index: int
@export var equipped_texture: Texture
@export var equip_texture: Texture

func setup_ui(gunindex: int, gundata: GunSO):
	var gun_data = GameManager.save_manager.game_data["guns_data"]
	if not gun_data["guns_unlocked"][gunindex] and gun_data["cards_collected"][gunindex] >= gundata.cards_needed:
		GameManager.save_manager.unlock_gun(gunindex)
		if GameManager.ui_manager and GameManager.ui_manager.popup_panel:
			GameManager.ui_manager.popup_panel.show_gun_reward_panel(gunindex, gundata)
	gun_name.text = gundata.name
	gun_image.texture = gundata.get_gun_texture(0)
	equiped_text.text = "equipped" if gunindex == gun_data["gun_selected_index"] else "equip"
	var button_texture := equipped_texture if gunindex == gun_data["gun_selected_index"] else equip_texture
	equiped_btn.texture_normal = button_texture
	equiped_btn.texture_hover = button_texture
	card.visible = false if gun_data["guns_unlocked"][gunindex] else true
	equiped_btn.visible = true if gun_data["guns_unlocked"][gunindex] else false
	if info_btn:
		info_btn.visible = true
		info_btn.disabled = false
	progress_bar.max_value = gundata.cards_needed
	progress_bar.value = gun_data["cards_collected"][gunindex]
	progress_bar_label.text = str(gun_data["cards_collected"][gunindex]) + "/" + str(gundata.cards_needed)
	lock_icon.visible = false if gun_data["guns_unlocked"][gunindex] else true
