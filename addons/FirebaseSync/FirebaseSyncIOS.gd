class_name FirebaseSyncIOSClient
extends RefCounted

const PLUGIN_NAME := "FirebaseSync"

static var _plugin: Object = null


static func initialize() -> bool:
	if not (OS.get_name() == "iOS" or OS.has_feature("ios")):
		return false

	if _plugin == null or not is_instance_valid(_plugin):
		if Engine.has_singleton(PLUGIN_NAME):
			_plugin = Engine.get_singleton(PLUGIN_NAME)
			print("[FirebaseSyncIOS] Connected to iOS singleton '", PLUGIN_NAME, "' successfully.")
		else:
			print("[FirebaseSyncIOS] Singleton '", PLUGIN_NAME, "' not found. Available singletons: ", Engine.get_singleton_list())

	return _plugin != null and is_instance_valid(_plugin)


static func is_available() -> bool:
	return initialize()


static func start_sync(
	firestore_url: String,
	id_token: String,
	document_path: String,
	body: String
) -> void:
	if not (OS.get_name() == "iOS" or OS.has_feature("ios")):
		return

	if not initialize():
		printerr("[FirebaseSyncIOS Error] FirebaseSync iOS plugin unavailable")
		return

	if _plugin.has_method("start_sync"):
		_plugin.start_sync(
			firestore_url,
			id_token,
			document_path,
			body
		)
	elif _plugin.has_method("startSync"):
		_plugin.startSync(
			firestore_url,
			id_token,
			document_path,
			body
		)
	else:
		printerr("[FirebaseSyncIOS Error] Neither start_sync nor startSync found on plugin.")

