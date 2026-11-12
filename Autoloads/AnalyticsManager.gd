extends Node

var _plugin_name = "FirebaseAnalyticsPlugin"
var _plugin = null


func _ready():
	_setup_plugin()
	_connect_signals()

func _setup_plugin():
	var os_name := OS.get_name()
	if os_name == "Android" or os_name == "iOS":
		if Engine.has_singleton(_plugin_name):
			_plugin = Engine.get_singleton(_plugin_name)
			print("[AnalyticsManager] Native FirebaseAnalyticsPlugin connected successfully.")
		else:
			print("[AnalyticsManager] Native FirebaseAnalyticsPlugin not found. Falling back to local console logging.")
	else:
		print("[AnalyticsManager] Not on a mobile platform. Falling back to local console logging.")

func _connect_signals():
	if EventBus:
		if EventBus.has_signal("auth_user_logged_in"):
			EventBus.auth_user_logged_in.connect(_on_user_logged_in)
		if EventBus.has_signal("auth_user_logged_out"):
			EventBus.auth_user_logged_out.connect(_on_user_logged_out)
		if EventBus.has_signal("iap_purchase_success"):
			EventBus.iap_purchase_success.connect(_on_iap_purchase_success)

func _on_user_logged_in(user_data: Dictionary) -> void:
	var uid = user_data.get("uid", user_data.get("localid", ""))
	if not uid.is_empty():
		set_user_id(uid)
		set_user_property("auth_provider", user_data.get("provider", "anonymous"))
		log_event("login", {"method": user_data.get("provider", "anonymous")})

func _on_user_logged_out() -> void:
	set_user_id("")
	log_event("logout", {})

func _on_iap_purchase_success(product_id: String, purchase_data: Dictionary) -> void:
	log_event("in_app_purchase", {
		"product_id": product_id,
		"currency": purchase_data.get("currency", "USD"),
		"price": purchase_data.get("price", 0.0)
	})

# --- PUBLIC INTERFACE ---

## Log a custom event with optional parameters.
func log_event(event_name: String, params: Dictionary = {}):
	if _plugin:
		_plugin.logEvent(event_name, params)
		print("[Analytics] Logged: ", event_name, " | Params: ", params)
	else:
		print("[Analytics-Fallback] Logged: ", event_name, " | Params: ", params)

## Set the User ID for the current session.
func set_user_id(user_id: String):
	if _plugin:
		_plugin.setUserId(user_id)
		print("[Analytics] Set User ID: ", user_id)
	else:
		print("[Analytics-Fallback] Set User ID: ", user_id)

## Set a custom user property.
func set_user_property(property_name: String, property_value: String):
	if _plugin:
		_plugin.setUserProperty(property_name, property_value)
		print("[Analytics] Set User Property: ", property_name, " = ", property_value)
	else:
		print("[Analytics-Fallback] Set User Property: ", property_name, " = ", property_value)

## Dynamically enable or disable analytics collection.
func set_analytics_collection_enabled(enabled: bool):
	if _plugin:
		_plugin.setAnalyticsCollectionEnabled(enabled)
		print("[Analytics] Set Collection Enabled: ", enabled)
	else:
		print("[Analytics-Fallback] Set Collection Enabled: ", enabled)

## Convenience helper to log screen transitions.
func log_screen(screen_name: String):
	log_event("screen_view", {"screen_name": screen_name})

## Track match start event with arena parameter.
func track_match_start(arena_name: String):
	log_event("match_start", {"arena": arena_name})
