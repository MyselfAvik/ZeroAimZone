extends Panel
class_name GunSkinContainerController

@export var skin_cards:Array[SkinCardController]
@export var gun_name:Label
@export var parent_Scroll:ScrollContainer
@export var horizontal_scroll:ScrollContainer

signal show_stats_requested(gunindex: int, skinindex: int)

var _gundata: GunSO

func _ready() -> void:
	horizontal_scroll.parent_scroll=parent_Scroll
func setup(gunindex,gundata:GunSO):
	_gundata = gundata
	var i=0
	for card in skin_cards:
		gun_name.text=gundata.name
		card.setup(gunindex,i,gundata)
		if not card.equipped_Btn.pressed.is_connected(equip_skin):
			card.equipped_Btn.pressed.connect(equip_skin.bind(gunindex,i))
		if card.info_btn and not card.info_btn.pressed.is_connected(emit_show_stats):
			card.info_btn.pressed.connect(emit_show_stats.bind(gunindex, i))
		i+=1

func emit_show_stats(gunidx: int, skinidx: int):
	show_stats_requested.emit(gunidx, skinidx)

func update(gunindex,gundata:GunSO):
	_gundata = gundata
	var i=0
	for card in skin_cards:
		card.setup(gunindex,i,gundata)
		i+=1

func equip_skin(gunindex,skindex):
	if skin_cards[skindex].current_state==SkinCardController.State.EQUIPPED:
		return
	elif skin_cards[skindex].current_state==SkinCardController.State.UNLOCKED:
		GameManager.save_manager.skin_select(gunindex,skindex)
	else:
		var diamond_cost = skin_cards[skindex].diamond_cost
		if diamond_cost > 0:
			if int(GameManager.save_manager.game_data["currency"]["Diamonds"]) < diamond_cost:
				if GameManager.ui_manager and GameManager.ui_manager.popup_panel and GameManager.ui_manager.popup_panel.insufficient_diamonds_popup:
					GameManager.ui_manager.popup_panel.insufficient_diamonds_popup.header_label.text = "not enough gems"
					GameManager.ui_manager.popup_panel.insufficient_diamonds_popup.text_label.text = "Top up to get more gems or play to earn."
					GameManager.ui_manager.popup_panel.show_insufficient_diamonds_popup()
			else:
				if GameManager.ui_manager and GameManager.ui_manager.popup_panel:
					GameManager.ui_manager.popup_panel.show_confirm_skin_purchase_popup(gunindex, skindex, diamond_cost, _gundata)
			return
		else:
			GameManager.save_manager.unlock_skin(gunindex,skindex)
			GameManager.save_manager.skin_select(gunindex,skindex)
		
	GameManager.save_manager.skin_list_updated.emit()
