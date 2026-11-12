extends Node

signal time_synced(trusted_unix_time: int)

const TIME_SERVERS: Array[String] = [
	"https://www.google.com",
	"https://www.cloudflare.com",
	"https://worldtimeapi.org/api/timezone/Etc/UTC"
]

const MONTH_MAP: Dictionary = {
	"Jan": 1, "Feb": 2, "Mar": 3, "Apr": 4, "May": 5, "Jun": 6,
	"Jul": 7, "Aug": 8, "Sep": 9, "Oct": 10, "Nov": 11, "Dec": 12
}

const PERSISTENCE_PATH: String = "user://trusted_time_state.json"
const RESYNC_INTERVAL_SECONDS: float = 900.0 # 15 minutes

var _base_unix_time: int = 0
var _base_ticks_msec: int = 0
var _is_time_synced: bool = false
var _is_syncing: bool = false
var _max_observed_unix: int = 0
var _resync_timer: Timer

func _ready() -> void:
	_load_persisted_state()
	
	var local_sys_time: int = int(Time.get_unix_time_from_system())
	if local_sys_time < _max_observed_unix:
		_base_unix_time = _max_observed_unix
	else:
		_base_unix_time = local_sys_time
		_max_observed_unix = local_sys_time
	_base_ticks_msec = Time.get_ticks_msec()

	_resync_timer = Timer.new()
	_resync_timer.wait_time = RESYNC_INTERVAL_SECONDS
	_resync_timer.autostart = true
	_resync_timer.one_shot = false
	_resync_timer.timeout.connect(sync_time)
	add_child(_resync_timer)
	
	# Initial sync on startup
	call_deferred("sync_time")

func is_network_time_synced() -> bool:
	return _is_time_synced

func get_unix_time() -> int:
	var elapsed_seconds: int = int((Time.get_ticks_msec() - _base_ticks_msec) / 1000.0)
	var current_time: int = _base_unix_time + elapsed_seconds

	if current_time > _max_observed_unix:
		_max_observed_unix = current_time

	return current_time

func get_datetime_dict() -> Dictionary:
	return Time.get_datetime_dict_from_unix_time(get_unix_time())

func get_date_dict() -> Dictionary:
	return Time.get_date_dict_from_unix_time(get_unix_time())

func get_today_date_string() -> String:
	var date := get_date_dict()
	return "%04d-%02d-%02d" % [date["year"], date["month"], date["day"]]

func sync_time() -> void:
	if _is_syncing:
		return
	_is_syncing = true
	_try_next_server(0)

func _try_next_server(server_index: int) -> void:
	if server_index >= TIME_SERVERS.size():
		_is_syncing = false
		return

	var url := TIME_SERVERS[server_index]
	var http_request := HTTPRequest.new()
	http_request.timeout = 5.0
	add_child(http_request)

	http_request.request_completed.connect(func(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray):
		var parsed_time := 0
		if result == HTTPRequest.RESULT_SUCCESS and response_code >= 200 and response_code < 400:
			parsed_time = _extract_time_from_response(url, headers, body)
		
		http_request.queue_free()

		if parsed_time > 0:
			_apply_trusted_time(parsed_time)
			_is_syncing = false
		else:
			# Fallback to next server
			_try_next_server(server_index + 1)
	)

	var error := http_request.request(url, PackedStringArray(["User-Agent: ZeroAimZone/1.0"]), HTTPClient.METHOD_HEAD if not url.ends_with(".json") and not "worldtimeapi" in url else HTTPClient.METHOD_GET)
	if error != OK:
		http_request.queue_free()
		_try_next_server(server_index + 1)

func _extract_time_from_response(url: String, headers: PackedStringArray, body: PackedByteArray) -> int:
	if "worldtimeapi" in url and body.size() > 0:
		var json_str := body.get_string_from_utf8()
		var parsed = JSON.parse_string(json_str)
		if parsed is Dictionary and parsed.has("unixtime"):
			return int(parsed["unixtime"])

	for header in headers:
		var lower := header.to_lower()
		if lower.begins_with("date:"):
			var date_value := header.substr(5).strip_edges()
			var unix_time := _parse_http_date_to_unix(date_value)
			if unix_time > 0:
				return unix_time

	return 0

func _parse_http_date_to_unix(date_str: String) -> int:
	var clean_str := date_str
	if "," in clean_str:
		var comma_parts := clean_str.split(",")
		if comma_parts.size() > 1:
			clean_str = comma_parts[1].strip_edges()

	var tokens := clean_str.split(" ", false)
	if tokens.size() < 4:
		return 0

	var day := int(tokens[0])
	var month_str := tokens[1]
	var year := int(tokens[2])
	var time_token := tokens[3]

	if not MONTH_MAP.has(month_str):
		return 0
	var month: int = MONTH_MAP[month_str]

	var time_parts := time_token.split(":")
	if time_parts.size() < 3:
		return 0

	var hour := int(time_parts[0])
	var minute := int(time_parts[1])
	var second := int(time_parts[2])

	return Time.get_unix_time_from_datetime_dict({
		"year": year,
		"month": month,
		"day": day,
		"hour": hour,
		"minute": minute,
		"second": second
	})

func _apply_trusted_time(unix_time: int) -> void:
	_base_unix_time = unix_time
	_base_ticks_msec = Time.get_ticks_msec()
	_is_time_synced = true
	if _base_unix_time > _max_observed_unix:
		_max_observed_unix = _base_unix_time
	_save_persisted_state()
	print("[TimeManager] Successfully synced trusted network time: ", get_today_date_string(), " (Unix: ", unix_time, ")")
	time_synced.emit(unix_time)

func _load_persisted_state() -> void:
	if FileAccess.file_exists(PERSISTENCE_PATH):
		var file := FileAccess.open(PERSISTENCE_PATH, FileAccess.READ)
		if file:
			var parsed = JSON.parse_string(file.get_as_text())
			if parsed is Dictionary:
				_max_observed_unix = int(parsed.get("max_observed_unix", 0))
	if _max_observed_unix <= 0:
		_max_observed_unix = int(Time.get_unix_time_from_system())

func _save_persisted_state() -> void:
	var file := FileAccess.open(PERSISTENCE_PATH, FileAccess.WRITE)
	if file:
		var data := {
			"max_observed_unix": _max_observed_unix,
			"last_save_time": Time.get_unix_time_from_system()
		}
		file.store_string(JSON.stringify(data))
