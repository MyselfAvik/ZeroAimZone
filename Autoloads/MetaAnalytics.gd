extends Node

# On Android, App ID and Client Token are read from AndroidManifest.xml / strings.xml
# by the Facebook SDK's auto-initialization (no code needed).
# On iOS, we still pass them programmatically since there is no equivalent auto-init.
const META_APP_ID = "4431833103752906"
const META_CLIENT_TOKEN = "c2ffdf7cfb802cd688b54463dea22779"

var _plugin = null
var current_user_id: String = ""

# --- Event buffering for async SDK init (Android) ---
var _sdk_ready: bool = false
var _event_queue: Array[Dictionary] = []
# Safety timeout: if the signal never fires, flush after this many seconds
const SDK_INIT_TIMEOUT_SEC: float = 10.0

func _ready():
	_setup_plugin()
	_connect_signals()

func _setup_plugin():
	var meta_singleton = ""
	if OS.get_name() == "Android":
		meta_singleton = "MetaSDKPlugin"
	elif OS.get_name() == "iOS":
		meta_singleton = "MetaSdk"

	if not meta_singleton.is_empty() and Engine.has_singleton(meta_singleton):
		_plugin = Engine.get_singleton(meta_singleton)
		
		# Listen for the native SDK's ready signal BEFORE calling initialize
		if _plugin.has_signal("sdk_initialized"):
			_plugin.sdk_initialized.connect(_on_sdk_initialized)
		
		# Android: SDK auto-initializes from the manifest, no args needed.
		# iOS: must pass App ID and Client Token programmatically.
		if OS.get_name() == "Android":
			_plugin.initialize()
		else:
			var app_id = META_APP_ID
			var client_token = META_CLIENT_TOKEN
			if Env and Env.has_method("get_var"):
				app_id = Env.get_var("META_APP_ID", META_APP_ID)
				client_token = Env.get_var("META_CLIENT_TOKEN", META_CLIENT_TOKEN)
			_plugin.initialize(app_id, client_token)
		
		# If the plugin reports ready synchronously (iOS), mark immediately
		if _plugin.has_method("isReady") and _plugin.isReady():
			_mark_sdk_ready()
		else:
			# Start a safety timeout in case the signal never fires (e.g. init failure)
			var timer = get_tree().create_timer(SDK_INIT_TIMEOUT_SEC)
			timer.timeout.connect(_on_sdk_init_timeout)
		
		print("[MetaAnalytics] Native Meta SDK connected. Waiting for initialization...")
	else:
		# Editor / non-mobile: no native plugin, mark ready immediately for fallback logging
		_mark_sdk_ready()
		print("[MetaAnalytics] Native Meta SDK not found. Running in editor or non-mobile platform.")

func _on_sdk_initialized():
	print("[MetaAnalytics] Received sdk_initialized signal from native plugin.")
	_mark_sdk_ready()

func _on_sdk_init_timeout():
	if not _sdk_ready:
		push_warning("[MetaAnalytics] SDK init timeout (%.1fs). Flushing %d queued events." % [SDK_INIT_TIMEOUT_SEC, _event_queue.size()])
		_mark_sdk_ready()

func _mark_sdk_ready():
	if _sdk_ready:
		return
	_sdk_ready = true
	
	# Now that the SDK is ready, apply deferred setup
	if _plugin:
		# Set debug mode based on build type
		_plugin.setDebugEnabled(OS.is_debug_build())
		
		# Native persistent tracking of first install vs returning launches
		_plugin.handleFirstLaunch("first_opened", "app_opened_again")
	
	print("[MetaAnalytics] SDK ready. Flushing %d queued events." % _event_queue.size())
	_flush_event_queue()

func _flush_event_queue():
	for entry in _event_queue:
		var event_name: String = entry["event_name"]
		var params: Dictionary = entry["params"]
		_do_log_event(event_name, params)
	_event_queue.clear()

func _connect_signals():
	pass

# --- PUBLIC INTERFACE ---

## Log a custom event with optional parameters.
## Events are queued if the SDK is not ready yet and flushed once it initializes.
func log_event(event_name: String, params: Dictionary = {}):
	if _sdk_ready:
		_do_log_event(event_name, params)
	else:
		_event_queue.append({"event_name": event_name, "params": params})
		print("[MetaAnalytics] Queued (SDK not ready): ", event_name, " | Params: ", params)

## Internal: actually send the event to the native plugin or fallback log.
func _do_log_event(event_name: String, params: Dictionary = {}):
	if _plugin:
		_plugin.logEvent(event_name, params)
		print("[MetaAnalytics] Logged: ", event_name, " | Params: ", params)
	else:
		print("[MetaAnalytics-Fallback] Logged: ", event_name, " | Params: ", params)

## Set the User ID for the current session.
func set_user_id(user_id: String):
	current_user_id = user_id
	if _plugin:
		_plugin.setUserId(user_id)
		print("[MetaAnalytics] Set User ID: ", user_id)
	else:
		print("[MetaAnalytics-Fallback] Set User ID: ", user_id)

# --- HELPER FUNCTIONS ---

func get_identity() -> String:
	if _plugin:
		return _plugin.getMetaIdentity()
	return "editor_mock_meta_identity"

## Track milestone ad events on 1, 5, 10, 15, 20, ... ads shown
func track_ad_impression_milestone(total_ads: int, ad_type: String = "") -> void:
	if total_ads == 1 or (total_ads > 0 and total_ads % 5 == 0):
		var event_name := "ad_watched_%d" % total_ads
		log_event(event_name, {
			"total_ads": total_ads,
			"milestone": total_ads,
			"ad_type": ad_type
		})
		log_event("Ad_Impression_Milestone", {
			"milestone": total_ads,
			"ad_type": ad_type
		})
		print("[MetaAnalytics] Tracked ad milestone: %s (Total Ads: %d, Type: %s)" % [event_name, total_ads, ad_type])
