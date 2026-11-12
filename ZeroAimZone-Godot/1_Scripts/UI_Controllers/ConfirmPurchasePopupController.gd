class_name ConfirmPurchasePopupController
extends BasePopupController

@export var pack_name_label: Label
@export var amount_label: Label
@export var exit_btn: Button
@export var continue_btn: Button
@export var gem_icon: TextureRect
@export var frame_icon:TextureRect
var _current_data: ShopData

func _ready() -> void:
	super._ready()
	if exit_btn and not exit_btn.pressed.is_connected(_on_exit_pressed):
		exit_btn.pressed.connect(_on_exit_pressed)
	if continue_btn and not continue_btn.pressed.is_connected(_on_continue_pressed):
		continue_btn.pressed.connect(_on_continue_pressed)

func setup(data: ShopData) -> void:
	_current_data = data
	if amount_label:
		amount_label.visible = true
		amount_label.text = str(data.amount)
	if pack_name_label:
		pack_name_label.text = "CONFIRM PURCHASE"
	if gem_icon:
		gem_icon.texture = data.icon
	if continue_btn:
		var price_text = "₹ " + str(data.price) + ".00"
		var iap = AuthManager._iap_manager if AuthManager else null
		var pid = data.product_id if "product_id" in data and not data.product_id.is_empty() else "test_id"
		if iap and iap.has_method("get_product_price"):
			var store_price = iap.get_product_price(pid)
			if not store_price.is_empty():
				price_text = store_price
		continue_btn.text = price_text

func _on_overlay_pressed() -> void:
	# Keep the scene-connected Overlay signal on the same close path as the X.
	GameManager.ui_manager.popup_panel.hide_popup()
	
func _on_exit_pressed() -> void:
	hide_popup()

func _on_continue_pressed() -> void:
	if _current_data:
		var iap: IAPManager = AuthManager._iap_manager if AuthManager else null
		var pid = _current_data.product_id if "product_id" in _current_data and not _current_data.product_id.is_empty() else "test_id"
		if iap and OS.get_name() == "Android" and iap.billing_client and iap.billing_client.is_ready():
			iap.pending_diamond_amount = _current_data.amount
			iap.pending_diamond_pack_name = _current_data.pack_name
			iap.buy_product(pid)
		else:
			# Fallback for desktop / editor testing or when billing is offline
			GameManager.save_manager.add_diamond(_current_data.amount)
			GameManager.save_manager.record_iap_consumable(pid, {
				"pack_name": _current_data.pack_name,
				"amount": _current_data.amount,
				"price": _current_data.price
			})
			GameAnalysis.track_economy_event(GameAnalysis.RESOURCE_FLOW_TYPE_SOURCE, "Diamonds", float(_current_data.amount), "IAP", "Pack_" + _current_data.pack_name)
	hide_popup()
