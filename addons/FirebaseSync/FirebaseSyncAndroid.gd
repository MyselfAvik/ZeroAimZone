class_name FirebaseSyncAndroid
extends RefCounted

const PLUGIN_NAME := "FirebaseSync"

static var _plugin: Object = null


static func initialize() -> bool:
	if not (OS.get_name() == "Android" or OS.has_feature("android")):
		return false

	if _plugin == null or not is_instance_valid(_plugin):
		if Engine.has_singleton(PLUGIN_NAME):
			_plugin = Engine.get_singleton(PLUGIN_NAME)

	return _plugin != null and is_instance_valid(_plugin)


static func is_available() -> bool:
	return initialize()


static func start_sync(
	firestore_url: String,
	id_token: String,
	document_path: String,
	body: String
) -> void:
	if not (OS.get_name() == "Android" or OS.has_feature("android")):
		return

	if not initialize():
		printerr("FirebaseSync plugin unavailable")
		return

	_plugin.startSync(
		firestore_url,
		id_token,
		document_path,
		body
	)

