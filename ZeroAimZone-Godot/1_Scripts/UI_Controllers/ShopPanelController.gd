class_name ShopPanelController
extends Control

@export var content_vbox: VBoxContainer

var ad_offer_panel: PanelContainer
var ad_offer_button: Button


@export var remove_ads_panel:Panel
@export var shop_card: PackedScene
@export var shop_data: ShopDataBase
@export var coins_card_parent: GridContainer
@export var daimonds_card_parent: GridContainer
@export var shop_scroll: SmoothScrollContainer
@export var coins_header: Control
@export var gems_header: Control

const SECTION_SCROLL_DURATION := 0.4

var iap: IAPManager


func _ready() -> void:
	if OS.get_name()=="iOS":
		remove_ads_panel.visible=false
		gems_header.visible=false
		
	if AuthManager:
		# Get IAP manager
		iap = AuthManager._iap_manager
		if iap:
			if not iap.entitlement_granted.is_connected(_on_entitlement_granted):
				iap.entitlement_granted.connect(_on_entitlement_granted)

			if not iap.products_loaded.is_connected(_on_products_loaded):
				iap.products_loaded.connect(_on_products_loaded)
		elif AuthManager.has_signal("iap_manager_ready"):
			if not AuthManager.iap_manager_ready.is_connected(_on_iap_ready):
				AuthManager.iap_manager_ready.connect(_on_iap_ready)

		if not AuthManager.remote_config_received.is_connected(_on_remote_config_received):
			AuthManager.remote_config_received.connect(_on_remote_config_received)
		if not AuthManager.remote_config_data.is_empty():
			_on_remote_config_received(AuthManager.remote_config_data)

	if GameManager and GameManager.save_manager:
		if not GameManager.save_manager.player_info_updated.is_connected(_on_player_info_updated):
			GameManager.save_manager.player_info_updated.connect(_on_player_info_updated)

	visibility_changed.connect(_on_visibility_changed)
	_refresh_remove_ads_ui()
	_populate_cards()

func _on_remote_config_received(config: Dictionary) -> void:
	if config.is_empty() or shop_data == null:
		return

	var raw_shop = config.get("shop", config.get("Shop", null))
	if raw_shop == null:
		return

	var shop_dict: Dictionary = {}
	if raw_shop is Dictionary:
		shop_dict = raw_shop
	elif raw_shop is String:
		var parsed = JSON.parse_string(raw_shop)
		if parsed is Dictionary:
			shop_dict = parsed

	if shop_dict.is_empty():
		return

	# Update Coin Packs from 'coinpack' or 'coinpacks'
	var coin_packs = shop_dict.get("coinpack", shop_dict.get("coinpacks", shop_dict.get("coin_pack", shop_dict.get("coin_packs", []))))
	if coin_packs is Array:
		var count := mini(coin_packs.size(), shop_data.coin_items.size())
		for idx in range(count):
			var pack_data = coin_packs[idx]
			if pack_data is Dictionary and shop_data.coin_items[idx]:
				var reward_val = pack_data.get("reward", pack_data.get("amount", pack_data.get("coins", 0)))
				if int(reward_val) > 0:
					shop_data.coin_items[idx].amount = int(reward_val)

	# Update Diamond Packs from 'diamondpack' or 'diamondpacks'
	var diamond_packs = shop_dict.get("diamondpack", shop_dict.get("diamondpacks", shop_dict.get("diamond_pack", shop_dict.get("diamond_packs", []))))
	if diamond_packs is Array:
		var count := mini(diamond_packs.size(), shop_data.diamond_items.size())
		for idx in range(count):
			var pack_data = diamond_packs[idx]
			if pack_data is Dictionary and shop_data.diamond_items[idx]:
				var reward_val = pack_data.get("reward", pack_data.get("amount", pack_data.get("diamonds", pack_data.get("gems", 0))))
				if int(reward_val) > 0:
					shop_data.diamond_items[idx].amount = int(reward_val)

	_populate_cards()

func _on_player_info_updated() -> void:
	_refresh_remove_ads_ui()
	_update_all_cards_ui()

func _on_visibility_changed() -> void:
	if is_visible_in_tree():
		_update_all_cards_ui()

func _update_all_cards_ui() -> void:
	if coins_card_parent:
		for child in coins_card_parent.get_children():
			if child is ShopCardController and child.has_method("_update_coin_ui"):
				child._update_coin_ui()

func _on_iap_ready(manager: Object) -> void:
	if manager is IAPManager:
		iap = manager
		if not iap.entitlement_granted.is_connected(_on_entitlement_granted):
			iap.entitlement_granted.connect(_on_entitlement_granted)
		if not iap.products_loaded.is_connected(_on_products_loaded):
			iap.products_loaded.connect(_on_products_loaded)
		_refresh_remove_ads_ui()
		_populate_cards()

func _populate_cards() -> void:
	if coins_card_parent == null or daimonds_card_parent == null or shop_card == null or shop_data == null:
		return

	# Clear existing cards
	for child in coins_card_parent.get_children():
		child.queue_free()
	for child in daimonds_card_parent.get_children():
		child.queue_free()

	for i in shop_data.coin_items:
		var card: ShopCardController = shop_card.instantiate()
		coins_card_parent.add_child(card)
		card.setup(0, i)
	if OS.get_name()!="iOS":
		for i in shop_data.diamond_items:
			var card: ShopCardController = shop_card.instantiate()
			daimonds_card_parent.add_child(card)
			card.setup(1, i)



func scroll_to_section(section: CurrencyNavigation.Section) -> void:
	var header := coins_header if section == CurrencyNavigation.Section.COINS else gems_header

	if header == null or shop_scroll == null:
		return

	_scroll_to_header_after_layout(header)


func _scroll_to_header_after_layout(header: Control) -> void:
	await get_tree().process_frame

	if not is_visible_in_tree() or not is_instance_valid(header):
		return

	var target_scroll := shop_scroll.scroll_vertical \
		+ header.get_global_rect().position.y \
		- shop_scroll.get_global_rect().position.y

	shop_scroll.scroll_y_to(-target_scroll, SECTION_SCROLL_DURATION)








func _on_remove_ads_pressed() -> void:
	GameAnalysis.track_ui_click("UI:Clicks:Home:Shop:NoAds")
	if iap == null:
		print("[Shop] IAP manager unavailable.")
		return

	if GameManager.save_manager.has_entitlement(
		iap.REMOVE_ADS_PRODUCT_ID
	):
		print("[Shop] Remove Ads already owned.")
		return

	print("[Shop] Purchasing Remove Ads...")

	iap.buy_product(
		iap.REMOVE_ADS_PRODUCT_ID
	)


func _on_entitlement_granted(product_id: String) -> void:
	if iap == null:
		return

	if product_id == iap.REMOVE_ADS_PRODUCT_ID:
		print("[Shop] Remove Ads entitlement granted.")
		_refresh_remove_ads_ui()


func _on_products_loaded(_products: Dictionary) -> void:
	_refresh_remove_ads_ui()
	_populate_cards()


func _refresh_remove_ads_ui() -> void:
	var button: Button = get_node_or_null("HBoxContainer/MarginContainer/MainLayout/ScrollContainer/ContentVBox/Panel/Button")
	if button:
		var is_owned := false
		if GameManager and GameManager.save_manager:
			is_owned = GameManager.save_manager.has_remove_ads()
		button.disabled = is_owned
		var lbl: Label = button.get_node_or_null("Label")
		if lbl:
			if is_owned:
				lbl.text = "OWNED"
			else:
				var price := ""
				if iap and iap.has_method("get_product_price"):
					price = iap.get_product_price(iap.REMOVE_ADS_PRODUCT_ID)
				if not price.is_empty():
					lbl.text = price
				else:
					lbl.text = "₹ 00.00"
