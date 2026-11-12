class_name IAPManager
extends Node


# ============================================================
# SIGNALS
# ============================================================

signal billing_connected
signal billing_disconnected
signal billing_error(code: int, message: String)

signal products_loaded(products: Dictionary)
signal product_query_failed(code: int, message: String)

signal purchase_started(product_id: String)
signal purchase_pending(product_id: String)
signal purchase_completed(product_id: String)
signal purchase_failed(product_id: String, code: int, message: String)

signal entitlement_granted(product_id: String)

signal purchase_consumed(product_id: String)
signal purchase_acknowledged(product_id: String)

signal purchases_restored


# ============================================================
# PRODUCT IDS
# ============================================================

const REMOVE_ADS_PRODUCT_ID := "remove_ad"


# ============================================================
# PRODUCT TYPES
# ============================================================

# Products that can be purchased repeatedly.
const CONSUMABLE_PRODUCTS := [
	REMOVE_ADS_PRODUCT_ID,
	"50_gems",
	"100_gems",
	"400_gems",
	"test_id"
]


# Products that are purchased once and permanently owned.
const NON_CONSUMABLE_PRODUCTS := [
]


# Subscriptions.
const SUBSCRIPTION_PRODUCTS := [
	# "premium_subscription"
]


# ============================================================
# BILLING
# ============================================================

var billing_client: BillingClient = null

var is_initialized: bool = false
var is_connecting: bool = false


# product_id -> product details
var products: Dictionary = {}


# purchase_token -> product_id
var pending_purchase_products: Dictionary = {}


# purchase_token -> purchase Dictionary
var pending_purchases: Dictionary = {}

var pending_diamond_amount: int = 0
var pending_diamond_pack_name: String = ""


# ============================================================
# READY
# ============================================================

func _ready() -> void:

	if OS.get_name() != "Android":
		print("[IAP] IAP disabled. Platform: ", OS.get_name())
		return

	print("[IAP] Initializing Google Play Billing...")

	billing_client = BillingClient.new()

	add_child(billing_client)

	_connect_billing_signals()

	call_deferred("_start_billing")


# ============================================================
# EXIT
# ============================================================

func _exit_tree() -> void:

	if billing_client:
		if billing_client.is_ready():
			billing_client.end_connection()

		billing_client = null


# ============================================================
# CONNECT BILLING SIGNALS
# ============================================================

func _connect_billing_signals() -> void:

	if billing_client == null:
		return

	if not billing_client.connected.is_connected(_on_billing_connected):
		billing_client.connected.connect(_on_billing_connected)

	if not billing_client.disconnected.is_connected(_on_billing_disconnected):
		billing_client.disconnected.connect(_on_billing_disconnected)

	if not billing_client.connect_error.is_connected(_on_billing_connect_error):
		billing_client.connect_error.connect(_on_billing_connect_error)

	if not billing_client.query_product_details_response.is_connected(
		_on_product_details_response
	):
		billing_client.query_product_details_response.connect(
			_on_product_details_response
		)

	if not billing_client.query_purchases_response.is_connected(
		_on_query_purchases_response
	):
		billing_client.query_purchases_response.connect(
			_on_query_purchases_response
		)

	if not billing_client.on_purchase_updated.is_connected(
		_on_purchase_updated
	):
		billing_client.on_purchase_updated.connect(
			_on_purchase_updated
		)

	if not billing_client.consume_purchase_response.is_connected(
		_on_consume_purchase_response
	):
		billing_client.consume_purchase_response.connect(
			_on_consume_purchase_response
		)

	if not billing_client.acknowledge_purchase_response.is_connected(
		_on_acknowledge_purchase_response
	):
		billing_client.acknowledge_purchase_response.connect(
			_on_acknowledge_purchase_response
		)


# ============================================================
# START BILLING
# ============================================================

func _start_billing() -> void:

	if billing_client == null:
		printerr("[IAP] BillingClient is null.")
		return

	if is_initialized:
		return

	if is_connecting:
		return

	is_connecting = true

	print("[IAP] Connecting to Google Play Billing...")

	billing_client.start_connection()


# ============================================================
# BILLING CONNECTED
# ============================================================

func _on_billing_connected() -> void:

	is_initialized = true
	is_connecting = false

	print("[IAP] Google Play Billing connected.")

	billing_connected.emit()

	# Query products.
	query_products()

	# Restore previous purchases.
	restore_purchases()


# ============================================================
# BILLING DISCONNECTED
# ============================================================

func _on_billing_disconnected() -> void:

	is_initialized = false
	is_connecting = false

	print("[IAP] Google Play Billing disconnected.")

	billing_disconnected.emit()


# ============================================================
# BILLING CONNECTION ERROR
# ============================================================

func _on_billing_connect_error(
	code: int,
	message: String
) -> void:

	is_initialized = false
	is_connecting = false

	printerr(
		"[IAP] Billing connection error. Code: ",
		code,
		" Message: ",
		message
	)

	billing_error.emit(code, message)


# ============================================================
# QUERY PRODUCTS
# ============================================================

func query_products() -> void:

	if not _is_billing_ready():
		printerr("[IAP] Billing is not ready.")
		return


	# --------------------------------------------------------
	# INAPP PRODUCTS
	# --------------------------------------------------------

	var inapp_products := PackedStringArray()

	for product_id in CONSUMABLE_PRODUCTS:
		if not inapp_products.has(product_id):
			inapp_products.append(product_id)

	for product_id in NON_CONSUMABLE_PRODUCTS:
		if not inapp_products.has(product_id):
			inapp_products.append(product_id)

	# Include product IDs from environment variables if defined
	if Env:
		for p_id in Env.get_var_array("IAP_CONSUMABLE_PRODUCT_IDS"):
			if not p_id.is_empty() and not inapp_products.has(p_id):
				inapp_products.append(p_id)

	# Include diamond pack product IDs from ShopDataBase
	if ResourceLoader.exists("res://ZeroAimZone-Godot/4_Resources/Tres/ShopDataBase.tres"):
		var s_data = load("res://ZeroAimZone-Godot/4_Resources/Tres/ShopDataBase.tres")
		if s_data and "diamond_items" in s_data:
			for item in s_data.diamond_items:
				if item and "product_id" in item and not item.product_id.is_empty():
					if not inapp_products.has(item.product_id):
						inapp_products.append(item.product_id)

	if not inapp_products.is_empty():

		print(
			"[IAP] Querying INAPP products: ",
			inapp_products
		)

		billing_client.query_product_details(
			inapp_products,
			BillingClient.ProductType.INAPP
		)


	# --------------------------------------------------------
	# SUBSCRIPTIONS
	# --------------------------------------------------------

	if not SUBSCRIPTION_PRODUCTS.is_empty():

		var subscription_products := PackedStringArray()

		for product_id in SUBSCRIPTION_PRODUCTS:
			subscription_products.append(product_id)


		print(
			"[IAP] Querying SUBS products: ",
			subscription_products
		)

		billing_client.query_product_details(
			subscription_products,
			BillingClient.ProductType.SUBS
		)


# ============================================================
# PRODUCT DETAILS RESPONSE
# ============================================================

func _on_product_details_response(response: Dictionary) -> void:

	print("[IAP] Product details response: ", response)

	var response_code := int(
		response.get("response_code", -1)
	)

	if response_code != BillingClient.BillingResponseCode.OK:

		var message := str(
			response.get(
				"debug_message",
				"Failed to query products."
			)
		)

		printerr(
			"[IAP] Product query failed. Code: ",
			response_code,
			" Message: ",
			message
		)

		product_query_failed.emit(
			response_code,
			message
		)

		return


	var product_details = response.get(
		"product_details",
		[]
	)

	if not product_details is Array:
		return


	for product in product_details:

		if not product is Dictionary:
			continue

		var product_id := str(
			product.get(
				"product_id",
				product.get("productId", product.get("sku", ""))
			)
		)

		if product_id.is_empty():
			continue

		products[product_id] = product

		print(
			"[IAP] Product loaded: ",
			product_id,
			" -> ",
			product
		)


	products_loaded.emit(products)


# ============================================================
# GET PRODUCT
# ============================================================

func get_product(product_id: String) -> Dictionary:

	if products.has(product_id):
		return products[product_id]

	if product_id == "remove_ad" and products.has("remove_ads"):
		return products["remove_ads"]
	if product_id == "remove_ads" and products.has("remove_ad"):
		return products["remove_ad"]

	for k in products.keys():
		if str(k).to_lower() == product_id.to_lower():
			return products[k]

	return {}


# ============================================================
# GET PRODUCT PRICE
# ============================================================

func get_product_price(product_id: String) -> String:

	var product := get_product(product_id)

	if product.is_empty():
		return ""

	var price_keys := ["formatted_price", "formattedPrice", "price", "price_formatted", "localized_price", "localizedPrice"]

	# 1. Top-level keys
	for key in price_keys:
		if product.has(key) and not str(product[key]).is_empty():
			return str(product[key])

	# 2. One-time purchase offer details (Array or Dictionary)
	for list_key in ["one_time_purchase_offer_details_list", "oneTimePurchaseOfferDetailsList", "one_time_purchase_offer_details", "oneTimePurchaseOfferDetails"]:
		if product.has(list_key):
			var details = product[list_key]
			if details is Array:
				for item in details:
					if item is Dictionary:
						for key in price_keys:
							if item.has(key) and not str(item[key]).is_empty():
								return str(item[key])
			elif details is Dictionary:
				for key in price_keys:
					if details.has(key) and not str(details[key]).is_empty():
						return str(details[key])

	# 3. Subscription offer details (Array or Dictionary)
	for sub_key in ["subscription_offer_details_list", "subscriptionOfferDetailsList", "subscription_offer_details", "subscriptionOfferDetails", "offers"]:
		if product.has(sub_key):
			var offers = product[sub_key]
			if offers is Array:
				for offer in offers:
					if offer is Dictionary:
						for key in price_keys:
							if offer.has(key) and not str(offer[key]).is_empty():
								return str(offer[key])
						for phases_key in ["pricing_phases", "pricingPhases", "pricing_phases_list", "pricingPhasesList"]:
							var phases = offer.get(phases_key, [])
							if phases is Array:
								for phase in phases:
									if phase is Dictionary:
										for key in price_keys:
											if phase.has(key) and not str(phase[key]).is_empty():
												return str(phase[key])
			elif offers is Dictionary:
				for key in price_keys:
					if offers.has(key) and not str(offers[key]).is_empty():
						return str(offers[key])

	return ""


# ============================================================
# PRODUCT AVAILABLE
# ============================================================

func is_product_available(product_id: String) -> bool:

	return products.has(product_id)


# ============================================================
# BUY PRODUCT
# ============================================================

func buy_product(product_id: String) -> bool:

	if not _is_billing_ready():

		if OS.has_feature("editor") or OS.get_name() != "Android":
			print("[IAP] Editor/Simulator: Simulating purchase for: ", product_id)
			purchase_started.emit(product_id)
			if product_id in CONSUMABLE_PRODUCTS:
				_grant_consumable(product_id)
				purchase_consumed.emit(product_id)
			elif product_id in NON_CONSUMABLE_PRODUCTS:
				_grant_non_consumable(product_id)
			purchase_completed.emit(product_id)
			entitlement_granted.emit(product_id)
			return true
		else:
			printerr(
				"[IAP] Billing is not ready."
			)
			return false


	if product_id.is_empty():

		printerr(
			"[IAP] Product ID is empty."
		)

		return false


	if not products.has(product_id):

		printerr(
			"[IAP] Product has not been loaded: ",
			product_id
		)

		purchase_failed.emit(
			product_id,
			BillingClient.BillingResponseCode.ITEM_UNAVAILABLE,
			"Product details are not loaded."
		)

		return false


	print(
		"[IAP] Launching purchase: ",
		product_id
	)

	purchase_started.emit(product_id)


	var result: Dictionary = billing_client.purchase(
		product_id
	)


	print(
		"[IAP] Purchase launch result: ",
		result
	)


	var response_code := int(
		result.get(
			"response_code",
			-1
		)
	)


	if response_code != BillingClient.BillingResponseCode.OK:

		var message := str(
			result.get(
				"debug_message",
				"Could not launch purchase."
			)
		)

		printerr(
			"[IAP] Purchase launch failed: ",
			response_code,
			" ",
			message
		)

		purchase_failed.emit(
			product_id,
			response_code,
			message
		)

		return false


	return true


# ============================================================
# PURCHASE UPDATED
# ============================================================

func _on_purchase_updated(response: Dictionary) -> void:

	print(
		"[IAP] Purchase updated: ",
		response
	)


	var response_code := int(
		response.get(
			"response_code",
			-1
		)
	)


	if response_code != BillingClient.BillingResponseCode.OK:

		var message := str(
			response.get(
				"debug_message",
				"Purchase failed."
			)
		)

		var product_id := str(
			response.get(
				"product_id",
				""
			)
		)


		purchase_failed.emit(
			product_id,
			response_code,
			message
		)

		return


	var purchases = response.get(
		"purchases",
		[]
	)


	if not purchases is Array:
		return


	for purchase in purchases:

		if purchase is Dictionary:

			_process_purchase(purchase)


# ============================================================
# PROCESS PURCHASE
# ============================================================

func _process_purchase(purchase: Dictionary, is_restore: bool = false) -> void:

	print("[IAP] Processing purchase (is_restore=%s): " % str(is_restore), purchase)

	# --------------------------------------------------------
	# PRODUCT IDS
	# --------------------------------------------------------

	var product_ids: Array = []

	if purchase.has("product_ids"):
		var raw_product_ids = purchase["product_ids"]
		if raw_product_ids is Array or raw_product_ids is PackedStringArray:
			for id in raw_product_ids:
				product_ids.append(str(id))
		elif raw_product_ids is String and not str(raw_product_ids).is_empty():
			product_ids.append(str(raw_product_ids))
	elif purchase.has("products"):
		var raw_products = purchase["products"]
		if raw_products is Array or raw_products is PackedStringArray:
			for id in raw_products:
				product_ids.append(str(id))
		elif raw_products is String and not str(raw_products).is_empty():
			product_ids.append(str(raw_products))
	elif purchase.has("product_id") and not str(purchase["product_id"]).is_empty():
		product_ids.append(str(purchase["product_id"]))
	elif purchase.has("sku") and not str(purchase["sku"]).is_empty():
		product_ids.append(str(purchase["sku"]))
	elif purchase.has("skus"):
		var raw_skus = purchase["skus"]
		if raw_skus is Array or raw_skus is PackedStringArray:
			for id in raw_skus:
				product_ids.append(str(id))

	if product_ids.is_empty() and purchase.has("original_json"):
		var parsed = JSON.parse_string(str(purchase["original_json"]))
		if parsed is Dictionary:
			if parsed.has("productId") and not str(parsed["productId"]).is_empty():
				product_ids.append(str(parsed["productId"]))
			elif parsed.has("productIds"):
				var raw_p = parsed["productIds"]
				if raw_p is Array or raw_p is PackedStringArray:
					for id in raw_p:
						product_ids.append(str(id))

	if product_ids.is_empty():
		printerr(
			"[IAP] Purchase has no product IDs. Full purchase: ",
			purchase
		)
		return


	print(
		"[IAP] Product IDs: ",
		product_ids
	)


	# --------------------------------------------------------
	# PURCHASE TOKEN
	# --------------------------------------------------------

	var purchase_token := str(
		purchase.get(
			"purchase_token",
			""
		)
	)

	if purchase_token.is_empty():

		printerr(
			"[IAP] Purchase token is empty."
		)

		return


	# --------------------------------------------------------
	# PURCHASE STATE
	# --------------------------------------------------------

	var purchase_state := int(
		purchase.get(
			"purchase_state",
			BillingClient.PurchaseState.UNSPECIFIED_STATE
		)
	)


	print(
		"[IAP] Purchase state: ",
		purchase_state
	)


	# --------------------------------------------------------
	# PENDING
	# --------------------------------------------------------

	if purchase_state == BillingClient.PurchaseState.PENDING:

		for product_id in product_ids:

			print(
				"[IAP] Purchase pending: ",
				product_id
			)

			purchase_pending.emit(
				str(product_id)
			)

		return


	# --------------------------------------------------------
	# NOT PURCHASED
	# --------------------------------------------------------

	if purchase_state != BillingClient.PurchaseState.PURCHASED:

		print(
			"[IAP] Purchase not completed."
		)

		return


	# --------------------------------------------------------
	# ACKNOWLEDGED?
	# --------------------------------------------------------

	var acknowledged := bool(
		purchase.get(
			"is_acknowledged",
			false
		)
	)


	print(
		"[IAP] Acknowledged: ",
		acknowledged
	)


	# Save purchase
	pending_purchases[purchase_token] = purchase


	# --------------------------------------------------------
	# PROCESS PRODUCTS
	# --------------------------------------------------------

	for product_id_value in product_ids:

		var product_id := str(
			product_id_value
		)

		print(
			"[IAP] Processing product: ",
			product_id
		)

		pending_purchase_products[
			purchase_token
		] = product_id


		# ----------------------------------------------------
		# CONSUMABLE
		# ----------------------------------------------------

		if product_id in CONSUMABLE_PRODUCTS:

			_process_consumable_purchase(
				product_id,
				purchase_token,
				is_restore
			)


		# ----------------------------------------------------
		# NON-CONSUMABLE
		# ----------------------------------------------------

		elif product_id in NON_CONSUMABLE_PRODUCTS:

			_process_non_consumable_purchase(
				product_id,
				purchase_token,
				acknowledged,
				is_restore
			)


		# ----------------------------------------------------
		# SUBSCRIPTION
		# ----------------------------------------------------

		elif product_id in SUBSCRIPTION_PRODUCTS:

			_process_subscription_purchase(
				product_id,
				purchase_token,
				acknowledged,
				is_restore
			)


		else:

			printerr(
				"[IAP] Unknown product ID: ",
				product_id
			)


# ============================================================
# CONSUMABLE PURCHASE
# ============================================================

func _process_consumable_purchase(
	product_id: String,
	purchase_token: String,
	is_restore: bool = false
) -> void:

	print(
		"[IAP] Processing consumable: ",
		product_id
	)


	# Grant the item.
	#
	# IMPORTANT:
	# In production, verify the purchase token on your
	# backend before granting valuable consumables.

	var reward_meta: Dictionary = _grant_consumable(product_id)
	if not is_restore:
		_notify_purchase_success(product_id, purchase_token, reward_meta)

	if GameManager and GameManager.save_manager:
		var txn_details := {
			"purchase_token": purchase_token,
			"reward": reward_meta
		}
		GameManager.save_manager.record_iap_consumable(product_id, txn_details)

	# Consumables must be consumed so they can be purchased
	# again.

	print(
		"[IAP] Consuming purchase: ",
		product_id
	)

	billing_client.consume_purchase(
		purchase_token
	)


# ============================================================
# NON-CONSUMABLE PURCHASE
# ============================================================

func _process_non_consumable_purchase(
	product_id: String,
	purchase_token: String,
	acknowledged: bool,
	is_restore: bool = false
) -> void:

	print(
		"[IAP] Processing non-consumable: ",
		product_id
	)

	# Grant entitlement
	var reward_meta: Dictionary = _grant_non_consumable(product_id)
	
	# Only notify purchase success (which triggers GameAnalytics Business Event) if this is a new purchase
	if not is_restore and not acknowledged:
		_notify_purchase_success(product_id, purchase_token, reward_meta)

	if GameManager and GameManager.save_manager:
		var txn_details := {
			"purchase_token": purchase_token,
			"reward": reward_meta
		}
		GameManager.save_manager.record_iap_entitlement(product_id, txn_details)

	if not acknowledged:

		print(
			"[IAP] Acknowledging purchase: ",
			product_id
		)

		billing_client.acknowledge_purchase(
			purchase_token
		)

	else:

		print(
			"[IAP] Already acknowledged: ",
			product_id
		)

		_finish_purchase_entitlement(
			product_id,
			purchase_token
		)

# ============================================================
# SUBSCRIPTION PURCHASE
# ============================================================

func _process_subscription_purchase(
	product_id: String,
	purchase_token: String,
	acknowledged: bool,
	is_restore: bool = false
) -> void:

	print(
		"[IAP] Processing subscription: ",
		product_id
	)

	_grant_subscription(
		product_id
	)
	if not is_restore and not acknowledged:
		_notify_purchase_success(product_id, purchase_token)

	if GameManager and GameManager.save_manager:
		var txn_details := {
			"purchase_token": purchase_token,
			"type": "subscription"
		}
		GameManager.save_manager.record_iap_entitlement(product_id, txn_details)

	if not acknowledged:

		print(
			"[IAP] Acknowledging subscription: ",
			product_id
		)

		billing_client.acknowledge_purchase(
			purchase_token
		)

	else:

		_finish_purchase_entitlement(
			product_id,
			purchase_token
		)


func _notify_purchase_success(product_id: String, purchase_token: String, extra_meta: Dictionary = {}) -> void:
	var purchase = pending_purchases.get(purchase_token, {}).duplicate()
	for k in extra_meta:
		purchase[k] = extra_meta[k]
	if EventBus and EventBus.has_signal("iap_purchase_success"):
		EventBus.iap_purchase_success.emit(product_id, purchase)


# ============================================================
# GRANT CONSUMABLE
# ============================================================

func _grant_consumable(
	product_id: String
) -> Dictionary:

	print(
		"[IAP] Granting consumable: ",
		product_id
	)

	if pending_diamond_amount > 0:
		var amount = pending_diamond_amount
		var pack_name = pending_diamond_pack_name
		_add_diamonds(amount)
		pending_diamond_amount = 0
		pending_diamond_pack_name = ""
		entitlement_granted.emit(product_id)
		return {
			"reward_type": "Diamonds",
			"reward_amount": amount,
			"pack_name": pack_name
		}

	match product_id:

		"50_gems":
			_add_diamonds(50)
			entitlement_granted.emit(product_id)
			return {
				"reward_type": "Diamonds",
				"reward_amount": 50,
				"pack_name": "Handful of Gems"
			}

		"100_gems":
			_add_diamonds(100)
			entitlement_granted.emit(product_id)
			return {
				"reward_type": "Diamonds",
				"reward_amount": 100,
				"pack_name": "Pile of Gems"
			}

		"400_gems":
			_add_diamonds(400)
			entitlement_granted.emit(product_id)
			return {
				"reward_type": "Diamonds",
				"reward_amount": 400,
				"pack_name": "Locker of Gems"
			}

		REMOVE_ADS_PRODUCT_ID:

			if GameManager and GameManager.save_manager:

				GameManager.save_manager.save_game_data(
					"player_data",
					"remove_ads",
					true
				)

			if AdManager and AdManager.has_method("hide_banner"):
				AdManager.hide_banner()

			print(
				"[IAP] Remove Ads unlocked (consumable)."
			)

			entitlement_granted.emit(product_id)
			return {
				"reward_type": "NoAds",
				"reward_item": "Remove_Ads"
			}

		_:

			printerr(
				"[IAP] No consumable reward configured: ",
				product_id
			)
			return {}


# ============================================================
# GRANT NON-CONSUMABLE
# ============================================================

func _grant_non_consumable(
	product_id: String
) -> Dictionary:

	print(
		"[IAP] Granting non-consumable: ",
		product_id
	)


	match product_id:

		REMOVE_ADS_PRODUCT_ID:

			if GameManager and GameManager.save_manager:

				GameManager.save_manager.save_game_data(
					"player_data",
					"remove_ads",
					true
				)

			if AdManager and AdManager.has_method("hide_banner"):
				AdManager.hide_banner()

			print(
				"[IAP] Remove Ads unlocked."
			)

			entitlement_granted.emit(product_id)
			return {
				"reward_type": "NoAds",
				"reward_item": "Remove_Ads"
			}

		_:

			printerr(
				"[IAP] Unknown non-consumable: ",
				product_id
			)
			return {}


# ============================================================
# GRANT SUBSCRIPTION
# ============================================================

func _grant_subscription(
	product_id: String
) -> void:

	print(
		"[IAP] Granting subscription: ",
		product_id
	)


	match product_id:

		_:

			print(
				"[IAP] No subscription reward configured."
			)


# ============================================================
# ADD DIAMONDS
# ============================================================

func _add_diamonds(
	amount: int
) -> void:

	if not GameManager or not GameManager.save_manager:

		printerr(
			"[IAP] SaveManager unavailable."
		)

		return

	GameManager.save_manager.add_diamond(amount)
	GameAnalysis.track_economy_event(GameAnalysis.RESOURCE_FLOW_TYPE_SOURCE, "Diamonds", float(amount), "IAP", "Store")

	print(
		"[IAP] Added ",
		amount,
		" diamonds."
	)


# ============================================================
# ACKNOWLEDGE RESPONSE
# ============================================================

func _on_acknowledge_purchase_response(
	response: Dictionary
) -> void:

	print(
		"[IAP] Acknowledge response: ",
		response
	)


	var response_code := int(
		response.get(
			"response_code",
			-1
		)
	)


	var purchase_token := str(
		response.get(
			"purchase_token",
			""
		)
	)


	if response_code != BillingClient.BillingResponseCode.OK:

		var message := str(
			response.get(
				"debug_message",
				"Failed to acknowledge purchase."
			)
		)


		printerr(
			"[IAP] Acknowledgement failed. Code: ",
			response_code,
			" Message: ",
			message
		)


		return


	var product_id := str(
		pending_purchase_products.get(
			purchase_token,
			""
		)
	)


	print(
		"[IAP] Purchase acknowledged: ",
		product_id
	)


	if product_id.is_empty():
		return


	purchase_acknowledged.emit(
		product_id
	)


	_finish_purchase_entitlement(
		product_id,
		purchase_token
	)


# ============================================================
# FINISH NON-CONSUMABLE / SUBSCRIPTION
# ============================================================

func _finish_purchase_entitlement(
	product_id: String,
	purchase_token: String
) -> void:

	print(
		"[IAP] Entitlement confirmed: ",
		product_id
	)


	purchase_completed.emit(
		product_id
	)


	entitlement_granted.emit(
		product_id
	)


	pending_purchase_products.erase(
		purchase_token
	)

	pending_purchases.erase(
		purchase_token
	)


# ============================================================
# CONSUME RESPONSE
# ============================================================

func _on_consume_purchase_response(
	response: Dictionary
) -> void:

	print(
		"[IAP] Consume response: ",
		response
	)


	var response_code := int(
		response.get(
			"response_code",
			-1
		)
	)


	var purchase_token := str(
		response.get(
			"purchase_token",
			""
		)
	)


	if response_code != BillingClient.BillingResponseCode.OK:

		var message := str(
			response.get(
				"debug_message",
				"Failed to consume purchase."
			)
		)


		printerr(
			"[IAP] Consume failed. Code: ",
			response_code,
			" Message: ",
			message
		)


		return


	var product_id := str(
		pending_purchase_products.get(
			purchase_token,
			""
		)
	)


	print(
		"[IAP] Purchase consumed: ",
		product_id
	)


	if product_id.is_empty():
		return


	purchase_consumed.emit(
		product_id
	)


	purchase_completed.emit(
		product_id
	)


	entitlement_granted.emit(
		product_id
	)


	pending_purchase_products.erase(
		purchase_token
	)

	pending_purchases.erase(
		purchase_token
	)


# ============================================================
# RESTORE PURCHASES
# ============================================================

func restore_purchases() -> void:

	if not _is_billing_ready():
		return


	print(
		"[IAP] Restoring INAPP purchases..."
	)


	billing_client.query_purchases(
		BillingClient.ProductType.INAPP
	)


	if not SUBSCRIPTION_PRODUCTS.is_empty():

		print(
			"[IAP] Restoring subscriptions..."
		)

		billing_client.query_purchases(
			BillingClient.ProductType.SUBS
		)


# ============================================================
# RESTORE RESPONSE
# ============================================================

func _on_query_purchases_response(
	response: Dictionary
) -> void:

	print(
		"[IAP] Query purchases response: ",
		response
	)


	var response_code := int(
		response.get(
			"response_code",
			-1
		)
	)


	if response_code != BillingClient.BillingResponseCode.OK:

		printerr(
			"[IAP] Restore purchases failed. Code: ",
			response_code
		)

		return


	var purchases = response.get(
		"purchases",
		[]
	)


	if not purchases is Array:
		return


	for purchase in purchases:

		if purchase is Dictionary:

			_process_purchase(
				purchase,
				true
			)


	purchases_restored.emit()


# ============================================================
# CHECK REMOVE ADS
# ============================================================

func has_remove_ads() -> bool:

	if GameManager == null:
		return false

	if GameManager.save_manager == null:
		return false


	return GameManager.save_manager.has_entitlement(
		REMOVE_ADS_PRODUCT_ID
	)


# ============================================================
# CHECK PRODUCT OWNERSHIP
# ============================================================

func has_entitlement(
	product_id: String
) -> bool:

	if product_id == REMOVE_ADS_PRODUCT_ID:

		return has_remove_ads()


	return false


# ============================================================
# BILLING READY
# ============================================================

func _is_billing_ready() -> bool:

	if OS.get_name() != "Android":
		return false


	if billing_client == null:
		return false


	return billing_client.is_ready()


func is_ready() -> bool:

	return _is_billing_ready()


# ============================================================
# DEBUG
# ============================================================

func print_products() -> void:

	print(
		"[IAP] ================= PRODUCTS ================="
	)


	for product_id in products.keys():

		print(
			"[IAP] ",
			product_id,
			" = ",
			products[product_id]
		)


	print(
		"[IAP] ============================================"
	)
