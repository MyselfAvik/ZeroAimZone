extends Node
# Env.gd - Lightweight .env File Parser for Godot 4
# Reads res://.env (or system environment variables) with fallback defaults.

static var _env_data: Dictionary = {}
static var _loaded: bool = false

func _ready():
	load_env()

static func load_env(path: String = "res://.env") -> void:
	_env_data.clear()
	_loaded = true
	
	if not FileAccess.file_exists(path):
		return

	var file = FileAccess.open(path, FileAccess.READ)
	if not file:
		return

	while not file.eof_reached():
		var line = file.get_line().strip_edges()
		if line.is_empty() or line.begins_with("#"):
			continue
		if "=" in line:
			var parts = line.split("=", true, 1)
			var key = parts[0].strip_edges()
			var val = parts[1].strip_edges()
			
			# Strip enclosing quotes if present
			if (val.begins_with('"') and val.ends_with('"')) or (val.begins_with("'") and val.ends_with("'")):
				if val.length() >= 2:
					val = val.substr(1, val.length() - 2)
			
			_env_data[key] = val

func get_var(key: String, default_val: String = "") -> String:
	if not _loaded:
		load_env()

	# 1. System Environment Variable (OS level)
	if OS.has_environment(key):
		var env_val = OS.get_environment(key).strip_edges()
		if not env_val.is_empty():
			return env_val
	# 2. .env file entry
	if _env_data.has(key):
		var val = str(_env_data[key]).strip_edges()
		if not val.is_empty():
			return val

	# 3. Fallback default
	return default_val

func get_var_array(key: String, default_val: Array[String] = []) -> Array[String]:
	var raw = get_var(key, "")
	if raw.is_empty():
		return default_val
	
	var result: Array[String] = []
	for part in raw.split(","):
		var item = part.strip_edges()
		if not item.is_empty():
			result.append(item)
	return result if not result.is_empty() else default_val
