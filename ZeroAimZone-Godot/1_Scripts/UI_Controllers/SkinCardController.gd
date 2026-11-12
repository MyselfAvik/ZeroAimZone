class_name SkinCardController
extends Panel


@export var info_btn:TextureButton
@export var gun_image:TextureRect
@export var equipped_Btn:TextureButton
@export var label:Label
@export var diamond:Control
@export var equipped_texture:Texture
@export var unlock_texture:Texture


enum State{
	LOCKED,
	UNLOCKED,
	EQUIPPED
}
var gunidx:int
var skinidx:int
var current_state:State
var diamond_cost:int = 0

func setup(gunindex:int,skinindex:int,gundata:GunSO):
	gunidx=gunindex
	skinidx=skinindex
	gun_image.texture=gundata.get_gun_texture(skinindex)
	
	var unlocked=GameManager.save_manager.game_data["guns_data"]["skins_unlocked"][gunindex][skinindex]
	var skin_selected_index=GameManager.save_manager.game_data["guns_data"]["skin_selected"][gunindex]
	diamond_cost = gundata.get_skin_diamonds_to_unlock(skinindex)

	if not unlocked :
		current_state=State.LOCKED
		equipped_Btn.texture_normal=unlock_texture
		equipped_Btn.texture_hover=unlock_texture
		if diamond_cost > 0:
			label.text=str(diamond_cost)
			diamond.visible=true
		else:
			label.text="unlock"
			diamond.visible=false
	elif skin_selected_index==skinindex:
		current_state=State.EQUIPPED
		equipped_Btn.texture_normal=equipped_texture
		equipped_Btn.texture_hover=equipped_texture
		label.text="equipped"
		diamond.visible=false
	else :
		equipped_Btn.texture_normal=unlock_texture
		equipped_Btn.texture_hover=unlock_texture
		current_state=State.UNLOCKED
		label.text="equip"
		diamond.visible=false
	
