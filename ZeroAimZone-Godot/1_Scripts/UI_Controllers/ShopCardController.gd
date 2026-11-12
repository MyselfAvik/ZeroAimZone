class_name ShopCardController
extends Panel
@export var icon:TextureRect
@export var pack_name:Label
@export var amount:Label
@export var btn:TextureButton
@export var coin_control:Control
@export var diamond_control:Control
@export var coin_cost:Label
@export var diamond_cost:Label
@export var glow_rect:TextureRect
@export var coin_glow:Texture2D
@export var gem_glow:Texture2D

const COOLDOWN_SECONDS: int = 86400 # 24 hours (1 day)

var _card_data: ShopData
var _card_type: int = 0
var _cooldown_timer: Timer

func _get_cooldown_remaining() -> int:
	if GameManager and GameManager.save_manager and _card_data:
		return GameManager.save_manager.get_shop_coin_pack_cooldown(_card_data.pack_name)
	return 0

func _get_ads_watched() -> int:
	if GameManager and GameManager.save_manager and _card_data:
		var data: Dictionary = GameManager.save_manager.get_shop_coin_ad_data(_card_data.pack_name)
		return int(data.get("ads_watched", 0))
	return 0

func _format_time(total_seconds: int) -> String:
	var hours = total_seconds / 3600
	var minutes = (total_seconds % 3600) / 60
	var seconds = total_seconds % 60
	if hours > 0:
		return "%02d:%02d:%02d" % [hours, minutes, seconds]
	return "%02d:%02d" % [minutes, seconds]

func _ready() -> void:
	if TimeManager and not TimeManager.time_synced.is_connected(_on_time_synced):
		TimeManager.time_synced.connect(_on_time_synced)
	if _card_type == 0 and _card_data != null:
		_update_coin_ui()

func _on_time_synced(_trusted_unix_time: int) -> void:
	if _card_type == 0 and _card_data != null:
		_update_coin_ui()

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_RESUMED or what == NOTIFICATION_VISIBILITY_CHANGED or what == NOTIFICATION_WM_WINDOW_FOCUS_IN:
		if _card_type == 0 and _card_data != null:
			_update_coin_ui()

func _update_coin_ui() -> void:
	if _card_type != 0 or _card_data == null or not is_instance_valid(coin_control):
		return

	var remaining := _get_cooldown_remaining()
	var req_ads: int = maxi(1, _card_data.price)
	var video_icon = coin_control.get_node_or_null("Control/TextureRect")

	if remaining > 0:
		btn.disabled = true
		if video_icon:
			video_icon.visible = false
		coin_cost.text = _format_time(remaining)
		_start_cooldown_timer()
	else:
		btn.disabled = false
		if video_icon:
			video_icon.visible = true
		var watched_ads: int = _get_ads_watched()
		coin_cost.text = "%d/%d" % [watched_ads, req_ads]
		_stop_cooldown_timer()

func _start_cooldown_timer() -> void:
	if not is_inside_tree():
		return
	if _cooldown_timer == null:
		_cooldown_timer = Timer.new()
		_cooldown_timer.wait_time = 1.0
		_cooldown_timer.one_shot = false
		_cooldown_timer.timeout.connect(_update_coin_ui)
		add_child(_cooldown_timer)
	if _cooldown_timer.is_stopped():
		_cooldown_timer.start()

func _stop_cooldown_timer() -> void:
	if _cooldown_timer and not _cooldown_timer.is_stopped():
		_cooldown_timer.stop()

func setup(type:int,data:ShopData):
	_card_type = type
	_card_data = data
	icon.texture=data.icon
	pack_name.text=data.pack_name
	amount.text=str(data.amount)

	if type==0:
		if glow_rect:
			glow_rect.texture = coin_glow
		coin_control.visible=true
		diamond_control.visible=false
		_update_coin_ui()
		if not btn.pressed.is_connected(shop_coin):
			btn.pressed.connect(shop_coin)
	else:
		_stop_cooldown_timer()
		if glow_rect:
			glow_rect.texture = gem_glow
		diamond_control.visible=true
		coin_control.visible=false
		btn.disabled = false
		
		var iap = AuthManager._iap_manager if AuthManager else null
		var pid = data.product_id if "product_id" in data and not data.product_id.is_empty() else "test_id"
		var store_price: String = iap.get_product_price(pid) if (iap and iap.has_method("get_product_price")) else ""
		
		var curr_lbl = diamond_control.get_node_or_null("Control/TextureRect")
		if not store_price.is_empty():
			if curr_lbl:
				curr_lbl.visible = false
			diamond_cost.text = store_price
		else:
			if curr_lbl:
				curr_lbl.visible = true
			diamond_cost.text = str(data.price)

		if not btn.pressed.is_connected(shop_diamond):
			btn.pressed.connect(shop_diamond)
	
func shop_coin():
	if _get_cooldown_remaining() > 0:
		return

	var req_ads: int = maxi(1, _card_data.price)
	
	if AdManager == null or OS.get_name() not in ["Android", "iOS"]:
		_grant_coin_ad_progress(req_ads)
		return

	var placement := "Shop_CoinPack_" + _card_data.pack_name.replace(" ", "_")
	AdManager.show_rewarded(placement, func():
		_grant_coin_ad_progress(req_ads)
	)

func _grant_coin_ad_progress(req_ads: int) -> void:
	if GameManager and GameManager.save_manager:
		var res: Dictionary = GameManager.save_manager.record_shop_coin_ad_watched(_card_data.pack_name, req_ads, _card_data.amount)
		_update_coin_ui()

		if bool(res.get("completed", false)):
			GameAnalysis.track_economy_event(GameAnalysis.RESOURCE_FLOW_TYPE_SOURCE, "Coins", float(_card_data.amount), "Shop", "CoinPack_" + _card_data.pack_name)
			
			if GameManager.ui_manager and GameManager.ui_manager.currency_collection_animator:
				var header_coin = GameManager.ui_manager.base_panel.get_node_or_null("SafeArea/TopBar/CoinCounter/CoinLabel") if GameManager.ui_manager.base_panel else null
				if header_coin:
					GameManager.ui_manager.currency_collection_animator.collect(null, _card_data.amount, btn, header_coin, false)
	else:
		_update_coin_ui()

func shop_diamond():
	GameAnalysis.track_shop_click("Gems", _card_data.pack_name)
	GameManager.ui_manager.popup_panel.show_confirm_purchase_popup(_card_data)
