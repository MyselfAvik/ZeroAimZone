class_name FirebaseSync
extends RefCounted

const PLUGIN_NAME := "FirebaseSync"

static var _plugin: Object = null


static func is_supported_platform() -> bool:
	var name := OS.get_name()
	return name == "Android" or name == "iOS" or OS.has_feature("android") or OS.has_feature("ios")


static func initialize() -> bool:
	if not is_supported_platform():
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
	if not is_supported_platform():
		return

	if not initialize():
		printerr("[FirebaseSync Error] Plugin unavailable on platform: ", OS.get_name())
		return

	if OS.get_name() == "Android":
		if _plugin.has_method("startSync"):
			_plugin.startSync(
				firestore_url,
				id_token,
				document_path,
				body
			)
		elif _plugin.has_method("start_sync"):
			_plugin.start_sync(
				firestore_url,
				id_token,
				document_path,
				body
			)
	elif OS.get_name() == "iOS":
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
			printerr("[FirebaseSync Error] Neither start_sync nor startSync found on iOS plugin.")

