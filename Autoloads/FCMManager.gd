extends Node

signal fcm_token_received(token: String)
signal fcm_message_received(title: String, body: String, data: Dictionary)
signal notification_permission_granted
signal notification_permission_denied

var _plugin = null
var _plugin_name = "FirebaseMessagingPlugin"
var _permission_granted: bool = false

func _ready() -> void:
	_setup_plugin()

func _setup_plugin() -> void:
	var os_name := OS.get_name()
	if os_name == "Android" or os_name == "iOS":
		if Engine.has_singleton(_plugin_name):
			_plugin = Engine.get_singleton(_plugin_name)
			print("[FCMManager] Plugin '", _plugin_name, "' found.")
			
			# Connect signals
			_plugin.fcm_token_received.connect(_on_fcm_token_received)
			_plugin.fcm_message_received.connect(_on_fcm_message_received)
			_plugin.notification_permission_result.connect(_on_notification_permission_result)
			
			# Start notification permission and pending token flow after a short delay at app start
			_start_fcm_flow_delayed()
		else:
			printerr("[FCMManager] Plugin '", _plugin_name, "' not found. Make sure the plugin is enabled in export settings.")
	else:
		print("[FCMManager] Not on a mobile platform, plugin will not be loaded.")

func _start_fcm_flow_delayed() -> void:
	print("[FCMManager] Waiting 1.5 seconds at app start to request notification permission...")
	await get_tree().create_timer(1.5).timeout
	if _plugin:
		print("[FCMManager] Delay finished. Checking pending token and requesting permission...")
		_plugin.checkPendingToken()
		request_notification_permission()

func fetch_fcm_token() -> void:
	if _plugin:
		_plugin.fetchFCMToken()
		print("[FCMManager] Requested FCM token fetch.")

func has_notification_permission() -> bool:
	if _plugin:
		return _plugin.hasNotificationPermission()
	return true

func request_notification_permission() -> void:
	if _plugin:
		_plugin.requestNotificationPermission()
		print("[FCMManager] Requested notification permission.")

func _on_notification_permission_result(granted: bool) -> void:
	_permission_granted = granted
	if granted:
		print("[FCMManager] Notification permission GRANTED.")
		notification_permission_granted.emit()
		await get_tree().create_timer(1.0).timeout
		fetch_fcm_token()
	else:
		print("[FCMManager] Notification permission DENIED by user.")
		notification_permission_denied.emit()

func _on_fcm_token_received(token: String) -> void:
	print("[FCMManager] Token received: ", token)
	var default_topic = "global"
	if Env and Env.has_method("get_var"):
		default_topic = Env.get_var("FIREBASE_FCM_DEFAULT_TOPIC", "global")
	subscribe_to_topic(default_topic)
			
	fcm_token_received.emit(token)

func subscribe_to_topic(topic: String) -> void:
	if _plugin and _plugin.has_method("subscribeToTopic"):
		_plugin.subscribeToTopic(topic)
		print("[FCMManager] Requested subscription to topic: ", topic)

func unsubscribe_from_topic(topic: String) -> void:
	if _plugin and _plugin.has_method("unsubscribeFromTopic"):
		_plugin.unsubscribeFromTopic(topic)
		print("[FCMManager] Requested unsubscription from topic: ", topic)

func _on_fcm_message_received(title: String, body: String, data_json: String) -> void:
	print("[FCMManager] Message received - Title: ", title, ", Body: ", body, ", Data JSON: ", data_json)
	var data = {}
	if data_json != "":
		var parsed = JSON.parse_string(data_json)
		if parsed is Dictionary:
			data = parsed
	fcm_message_received.emit(title, body, data)
