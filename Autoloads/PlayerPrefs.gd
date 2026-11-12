extends Node

const PREFS_PATH: String = "user://player_prefs.cfg"
const SECTION_NAME: String = "prefs"

var _config: ConfigFile = ConfigFile.new()

func _ready() -> void:
	load_prefs()

func load_prefs() -> void:
	var err = _config.load(PREFS_PATH)
	if err != OK:
		_config = ConfigFile.new()

func save() -> void:
	_config.save(PREFS_PATH)

# ==============================================================================
# SETTERS
# ==============================================================================

func set_int(key: String, value: int) -> void:
	_config.set_value(SECTION_NAME, key, value)
	save()

func set_float(key: String, value: float) -> void:
	_config.set_value(SECTION_NAME, key, value)
	save()

func set_string(key: String, value: String) -> void:
	_config.set_value(SECTION_NAME, key, value)
	save()

func set_bool(key: String, value: bool) -> void:
	_config.set_value(SECTION_NAME, key, value)
	save()

func set_value(key: String, value: Variant) -> void:
	_config.set_value(SECTION_NAME, key, value)
	save()

# ==============================================================================
# GETTERS
# ==============================================================================

func get_int(key: String, default_value: int = 0) -> int:
	return int(_config.get_value(SECTION_NAME, key, default_value))

func get_float(key: String, default_value: float = 0.0) -> float:
	return float(_config.get_value(SECTION_NAME, key, default_value))

func get_string(key: String, default_value: String = "") -> String:
	return str(_config.get_value(SECTION_NAME, key, default_value))

func get_bool(key: String, default_value: bool = false) -> bool:
	return bool(_config.get_value(SECTION_NAME, key, default_value))

func get_value(key: String, default_value: Variant = null) -> Variant:
	return _config.get_value(SECTION_NAME, key, default_value)

# ==============================================================================
# UTILITY
# ==============================================================================

func has_key(key: String) -> bool:
	return _config.has_section_key(SECTION_NAME, key)

func delete_key(key: String) -> void:
	if _config.has_section_key(SECTION_NAME, key):
		_config.erase_section_key(SECTION_NAME, key)
		save()

func delete_all() -> void:
	_config.erase_section(SECTION_NAME)
	save()
