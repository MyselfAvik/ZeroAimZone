class_name NetworkMonitor
extends Node

static var has_internet: bool = true

signal internet_state_changed(online: bool)

@export var poll_seconds: float = 3.0

var _timer: Timer
var _http_request: HTTPRequest
var _is_requesting: bool = false

# Require multiple consecutive failures before declaring offline to avoid
# transient blips (e.g. one slow DNS lookup) from showing the popup.
const CONSECUTIVE_FAILURES_REQUIRED: int = 2
var _consecutive_failures: int = 0

# Multiple endpoints — if one is blocked in a region, others may still work.
var _check_urls: Array[String] = [
	"https://connectivitycheck.gstatic.com/generate_204",
	"https://www.google.com/generate_204",
	"https://clients3.google.com/generate_204",
	"https://cp.cloudflare.com/",
]
var _current_url_index: int = 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

	# In the desktop editor, skip network checks entirely — the popup is
	# disruptive during development and the editor environment often has
	# different SSL/proxy behaviour that causes false positives.
	if OS.has_feature("editor"):
		has_internet = true
		return

	_ensure_singletons_process_always()

	_http_request = HTTPRequest.new()
	_http_request.process_mode = Node.PROCESS_MODE_ALWAYS
	_http_request.timeout = 3.0
	add_child(_http_request)

	_http_request.request_completed.connect(
		_on_request_completed
	)

	_timer = Timer.new()
	_timer.process_mode = Node.PROCESS_MODE_ALWAYS
	_timer.wait_time = poll_seconds
	_timer.autostart = true

	_timer.timeout.connect(
		_check_internet
	)

	add_child(_timer)

	_check_internet()


func _ensure_singletons_process_always() -> void:
	if is_instance_valid(GameManager) and is_instance_valid(GameManager.network_handler):
		GameManager.network_handler.setup_network_lag()
	var root = get_tree().root if is_inside_tree() and get_tree() else null
	if root:
		var current_scene = get_tree().current_scene
		for child in root.get_children():
			if child != current_scene and child is Node:
				if child.process_mode == Node.PROCESS_MODE_INHERIT:
					child.process_mode = Node.PROCESS_MODE_ALWAYS

func _get_active_popup_panel() -> PopupPanelController:
	if is_instance_valid(GameManager.in_game_ui) and is_instance_valid(GameManager.in_game_ui.popup_panel):
		return GameManager.in_game_ui.popup_panel
	elif is_instance_valid(GameManager.ui_manager) and is_instance_valid(GameManager.ui_manager.popup_panel):
		return GameManager.ui_manager.popup_panel
	return null

func _wait_for_ui_ready() -> void:
	var attempts := 0
	while not _get_active_popup_panel() and attempts < 120 and is_inside_tree():
		await get_tree().process_frame
		attempts += 1


func _check_internet() -> void:

	# Don't start another request if one is already running.
	if _is_requesting or _http_request.get_http_client_status() != HTTPClient.STATUS_DISCONNECTED:
		return

	_is_requesting = true
	var url = _check_urls[_current_url_index]
	var error := _http_request.request(url)

	if error != OK:
		_is_requesting = false
		_on_check_failed()


func _on_request_completed(
	result: int,
	response_code: int,
	_headers: PackedStringArray,
	_body: PackedByteArray
) -> void:

	_is_requesting = false

	var online := (
		result == HTTPRequest.RESULT_SUCCESS
		and response_code >= 200
		and response_code < 400
	)

	if online:
		_consecutive_failures = 0
		_current_url_index = 0
		_set_internet_state(true)
	else:
		_on_check_failed()


func _on_check_failed() -> void:
	_consecutive_failures += 1

	# Rotate to the next URL for the next attempt so we don't keep hitting
	# a single blocked endpoint.
	_current_url_index = (_current_url_index + 1) % _check_urls.size()

	if _consecutive_failures >= CONSECUTIVE_FAILURES_REQUIRED:
		_set_internet_state(false)


func _set_internet_state(online: bool) -> void:

	if online == has_internet:
		return

	has_internet = online

	print(
		"[NetworkMonitor] Internet: ",
		has_internet
	)

	internet_state_changed.emit(has_internet)
	_update_no_internet_popup(has_internet)

	if has_internet and TimeManager:
		TimeManager.sync_time()


func _update_no_internet_popup(online: bool) -> void:
	if not online:
		_ensure_singletons_process_always()
		var popup_panel = _get_active_popup_panel()
		# If user comes offline right at startup, UI is not ready yet.
		# Wait for UI to mount before pausing, otherwise engine freezes before popup can appear!
		if not popup_panel:
			await _wait_for_ui_ready()
			_ensure_singletons_process_always()
			popup_panel = _get_active_popup_panel()

		# Only pause and show popup if still offline after waiting
		if not has_internet:
			if get_tree():
				get_tree().paused = true
			if popup_panel:
				popup_panel.process_mode = Node.PROCESS_MODE_ALWAYS
				popup_panel.show_popup(PopupPanelController.PopupType.NOINTERNET)
	else:
		if get_tree():
			get_tree().paused = false
		var popup_panel = _get_active_popup_panel()
		if popup_panel and is_instance_valid(popup_panel.no_internet_popup) and popup_panel.no_internet_popup.visible:
			popup_panel.no_internet_popup.hide_popup()
			if not PlayerPrefs.get_bool("terms_accepted", false):
				popup_panel.show_popup(PopupPanelController.PopupType.TC)


func wait_until_online() -> void:

	if has_internet:
		return

	await internet_state_changed
