extends Node

var _plugin_name = "FirebaseCrashlyticsPlugin"
var _plugin = null

func _ready() -> void:
	# Debug/Testing: Uncomment the line below to trigger a deliberate Crashlytics crash after 15 seconds.
	#get_tree().create_timer(15.0).timeout.connect(trigger_test_crash)
	_setup_plugin()
	_connect_signals()

func _setup_plugin() -> void:
	var os_name := OS.get_name()
	if os_name == "Android" or os_name == "iOS":
		if Engine.has_singleton(_plugin_name):
			_plugin = Engine.get_singleton(_plugin_name)
			print("[CrashlyticsManager] Native FirebaseCrashlyticsPlugin connected successfully.")
			log_message("Crashlytics plugin initialized in GDScript.")
		else:
			printerr("[CrashlyticsManager] Native FirebaseCrashlyticsPlugin not found. Make sure the plugin is active in export presets.")
	else:
		print("[CrashlyticsManager] Not on a mobile platform. Falling back to local console logging.")

func _connect_signals() -> void:
	if EventBus:
		if EventBus.has_signal("auth_user_logged_in"):
			EventBus.auth_user_logged_in.connect(_on_user_logged_in)
		if EventBus.has_signal("auth_user_logged_out"):
			EventBus.auth_user_logged_out.connect(_on_user_logged_out)
		if EventBus.has_signal("firebase_failed"):
			EventBus.firebase_failed.connect(_on_firebase_failed)
		if EventBus.has_signal("auth_failed"):
			EventBus.auth_failed.connect(_on_auth_failed)
		if EventBus.has_signal("network_connectivity_changed"):
			EventBus.network_connectivity_changed.connect(_on_network_connectivity_changed)

# --- PUBLIC INTERFACE ---

## Log a message to Firebase Crashlytics.
func log_message(message: String) -> void:
	if _plugin:
		_plugin.log(message)
	else:
		print("[Crashlytics-Fallback] Log: ", message)

## Set the User ID for Crashlytics.
func set_user_id(user_id: String) -> void:
	if _plugin:
		_plugin.setUserId(user_id)
	else:
		print("[Crashlytics-Fallback] Set User ID: ", user_id)

## Set a custom key-value pair for Crashlytics logs.
func set_custom_key(key: String, value) -> void:
	if _plugin:
		match typeof(value):
			TYPE_STRING:
				_plugin.setCustomKey(key, value)
			TYPE_INT:
				_plugin.setCustomKeyInt(key, value)
			TYPE_BOOL:
				_plugin.setCustomKeyBool(key, value)
			TYPE_FLOAT:
				_plugin.setCustomKeyFloat(key, value)
			_:
				_plugin.setCustomKey(key, str(value))
	else:
		print("[Crashlytics-Fallback] Set Custom Key: ", key, " = ", value)

## Force a crash for testing/verification.
func crash() -> void:
	if _plugin:
		print("[Crashlytics] Forcing a native crash...")
		_plugin.crash()
	else:
		push_error("[Crashlytics-Fallback] Crash called but not running on Android or iOS.")

## Deliberately triggers a Crashlytics crash call for testing/verification.
func trigger_test_crash() -> void:
	crash()

# --- AUTOMATIC SIGNAL HANDLERS ---

func _on_user_logged_in(user_data: Dictionary) -> void:
	var uid = user_data.get("uid", user_data.get("localid", ""))
	if not uid.is_empty():
		set_user_id(uid)
		set_custom_key("auth_provider", user_data.get("provider", "anonymous"))
		log_message("User logged in to Crashlytics: " + uid)

func _on_user_logged_out() -> void:
	set_user_id("")
	log_message("User logged out from Crashlytics")

func _on_firebase_failed(error_code: int, message: String) -> void:
	log_message("Firebase error %d: %s" % [error_code, message])
	set_custom_key("last_firebase_error", "Error %d: %s" % [error_code, message])

func _on_auth_failed(code: int, message: String) -> void:
	log_message("Auth error %d: %s" % [code, message])
	set_custom_key("last_auth_error", "Error %d: %s" % [code, message])

func _on_network_connectivity_changed(is_net_connected: bool) -> void:
	set_custom_key("network_connected", is_net_connected)
