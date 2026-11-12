@tool
extends EditorPlugin

var export_plugin: FirebaseSyncExportPlugin


func _enter_tree() -> void:
	export_plugin = FirebaseSyncExportPlugin.new()
	add_export_plugin(export_plugin)


func _exit_tree() -> void:
	remove_export_plugin(export_plugin)
	export_plugin = null


class FirebaseSyncExportPlugin extends EditorExportPlugin:
	var _plugin_name := "FirebaseSync"

	func _supports_platform(platform: EditorExportPlatform) -> bool:
		return platform is EditorExportPlatformAndroid

	func _get_android_libraries(platform: EditorExportPlatform, debug: bool) -> PackedStringArray:
		if debug:
			return PackedStringArray([_plugin_name + "/bin/debug/" + _plugin_name + "-debug.aar"])
		else:
			return PackedStringArray([_plugin_name + "/bin/release/" + _plugin_name + "-release.aar"])

	func _get_android_dependencies(platform: EditorExportPlatform, debug: bool) -> PackedStringArray:
		return PackedStringArray([])

	func _export_begin(
		features: PackedStringArray,
		is_debug: bool,
		path: String,
		flags: int
	) -> void:
		pass

	func _get_name() -> String:
		return _plugin_name

