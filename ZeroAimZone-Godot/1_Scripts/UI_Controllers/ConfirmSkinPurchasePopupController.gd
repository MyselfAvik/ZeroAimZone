class_name ConfirmSkinPurchasePopupController
extends BasePopupController

@export var pack_name_label: Label
@export var amount_label: Label
@export var exit_btn: Button
@export var continue_btn: Button
@export var gem_icon: TextureRect

var _gunindex: int
var _skinindex: int
var _diamond_cost: int
var _gundata: GunSO

func _ready() -> void:
	super._ready()
	if exit_btn and not exit_btn.pressed.is_connected(_on_exit_pressed):
		exit_btn.pressed.connect(_on_exit_pressed)
	if continue_btn and not continue_btn.pressed.is_connected(_on_continue_pressed):
		continue_btn.pressed.connect(_on_continue_pressed)

func setup(gunindex: int, skinindex: int, diamond_cost: int, gundata: GunSO) -> void:
	_gunindex = gunindex
	_skinindex = skinindex
	_diamond_cost = diamond_cost
	_gundata = gundata
	
	if pack_name_label:
		pack_name_label.text = "CONFIRM PURCHASE"
		
	if amount_label:
		amount_label.text = str(_diamond_cost)
		
	if gem_icon:
		gem_icon.texture = _gundata.get_gun_texture(_skinindex)
		
	if continue_btn:
		continue_btn.text = "BUY"

func _on_overlay_pressed() -> void:
	GameManager.ui_manager.popup_panel.hide_popup()
	
func _on_exit_pressed() -> void:
	hide_popup()

func _on_continue_pressed() -> void:
	if GameManager.save_manager.use_diamond(_diamond_cost):
		var g_name = str(_gundata.name) if _gundata else "Gun"
		GameAnalysis.track_economy_event(GameAnalysis.RESOURCE_FLOW_TYPE_SINK, "Diamonds", float(_diamond_cost), "Cosmetics", "SkinUnlock_%s_%d" % [g_name, _skinindex])
		GameManager.save_manager.unlock_skin(_gunindex, _skinindex)
		GameManager.save_manager.skin_list_updated.emit()
		
		# Show SkinRewardPanel
		GameManager.ui_manager.popup_panel.show_skin_reward_panel(_gunindex, _skinindex, _gundata)
		hide_popup()
	else:
		hide_popup()
		if GameManager.ui_manager and GameManager.ui_manager.popup_panel:
			GameManager.ui_manager.popup_panel.insufficient_diamonds_popup.header_label.text = "not enough gems"
			GameManager.ui_manager.popup_panel.insufficient_diamonds_popup.text_label.text = "Top up to get more gems or play to earn."
			GameManager.ui_manager.popup_panel.show_insufficient_diamonds_popup()
