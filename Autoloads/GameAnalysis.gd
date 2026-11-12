extends Node

var ga: Object = null

# Disk Queue & FTUE Persistence Files
const QUEUE_FILE: String = "user://ga_pending_queue.json"
const FTUE_FILE: String = "user://ftue_completed.json"

# Defer queue for events fired during the pending startup initialization window
var _sdk_ready: bool = false
var _pending_events: Array[Dictionary] = []
var _ftue_completed_steps: Dictionary = {}
var _early_ftue_buffer: Array[String] = []
var _auth_sync_resolved: bool = false

# Event spam debouncer (Debounce threshold in milliseconds)
var _last_event_times: Dictionary = {}
const DEBOUNCE_THRESHOLD_MS: int = 250

# Match Lifecycle & Duration State
var _active_arena: String = ""
var _active_attempt: int = 1
var _match_start_ticks: int = 0
var _is_match_active: bool = false

# Valid Custom Dimension 01 values (Pre-registered before init)
# Used for progression match outcomes (Win/Lose) and abnormal match interruptions (Fail reasons)
const KNOWN_CUSTOM_DIMENSIONS_01: Array[String] = [
	"Win", "Lose", "Disconnect", "HostLeft", "AppClosed", "AppBackgrounded", "Home", "Resume"
]

# Resource Flow Types
const RESOURCE_FLOW_TYPE_SOURCE = 1
const RESOURCE_FLOW_TYPE_SINK = 2

# Error Severity Levels
const ERROR_SEVERITY_DEBUG = 1
const ERROR_SEVERITY_INFO = 2
const ERROR_SEVERITY_WARNING = 3
const ERROR_SEVERITY_ERROR = 4
const ERROR_SEVERITY_CRITICAL = 5

# Ad Actions
const AD_ACTION_CLICKED = 1
const AD_ACTION_SHOW = 2
const AD_ACTION_FAILED_SHOW = 3
const AD_ACTION_REWARD_RECEIVED = 4

# Ad Types
const AD_TYPE_VIDEO = 1
const AD_TYPE_REWARDED_VIDEO = 2
const AD_TYPE_INTERSTITIAL = 3
const AD_TYPE_BANNER = 4

# Currencies with non-standard decimal places
const ZERO_DECIMAL_CURRENCIES: Array[String] = [
	"BIF", "CLP", "DJF", "GNF", "ISK", "JPY", "KMF", "KRW", "PYG", "RWF", "UGX", "UYI", "VND", "VUV", "XAF", "XOF", "XPF"
]
const THREE_DECIMAL_CURRENCIES: Array[String] = [
	"BHD", "IQD", "JOD", "KWD", "LYD", "OMR", "TND"
]
const FOUR_DECIMAL_CURRENCIES: Array[String] = [
	"CLF", "UYW"
]

## Helper to get the correct minor units (decimal places) for any ISO-4217 code
func get_minor_units(currency_code: String) -> int:
	var code = currency_code.to_upper()
	if code in ZERO_DECIMAL_CURRENCIES:
		return 0
	elif code in THREE_DECIMAL_CURRENCIES:
		return 3
	elif code in FOUR_DECIMAL_CURRENCIES:
		return 4
	return 2 # Default to 2 for USD, INR, EUR, etc.

# ---------------------------------------------------------------------------
# IAP Product Catalog
# Maps every Google Play product_id → GA Business Event parameters.
# ---------------------------------------------------------------------------
const IAP_PRODUCT_CATALOG: Dictionary = {
	"50_gems": {
		"item_type": "Diamonds",
		"item_id": "50_gems",
		"cart_type": "Shop",
		"is_real_money": true
	},
	"100_gems": {
		"item_type": "Diamonds",
		"item_id": "100_gems",
		"cart_type": "Shop",
		"is_real_money": true
	},
	"400_gems": {
		"item_type": "Diamonds",
		"item_id": "400_gems",
		"cart_type": "Shop",
		"is_real_money": true
	},
	"remove_ad": {
		"item_type": "NoAds",
		"item_id": "remove_ad",
		"cart_type": "Shop",
		"is_real_money": true
	}
}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_load_ftue_state()
	_load_pending_queue()
	
	if _ftue_completed_steps.get("is_existing_player", false) == true or is_existing_player():
		_auth_sync_resolved = true
		_ftue_completed_steps["is_existing_player"] = true
	else:
		get_tree().create_timer(10.0).timeout.connect(_on_auth_sync_fallback_timeout)
	
	if Engine.has_singleton("GameAnalytics"):
		ga = Engine.get_singleton("GameAnalytics")
		
		# Enable info and verbose logging for verification in debug builds only
		ga.setEnabledInfoLog(true)
		# ga.setEnabledVerboseLog(true)
		
		# Enable automatic events (SDK Init and Performance: FPS, Memory, Hardware Info)
		ga.enableSDKInitEvent(true)
		ga.enableFpsHistogram(true)
		ga.enableMemoryHistogram(true)
		ga.enableHealthHardwareInfo(true)
		
		# Pre-register CustomDimension01 (Match Outcomes & Interruption reasons) BEFORE init()
		if ga.has_method("configureAvailableCustomDimensions01"):
			ga.configureAvailableCustomDimensions01(KNOWN_CUSTOM_DIMENSIONS_01)
			
		if ga.has_method("configureBuild"):
			if OS.get_name() == "iOS":
				ga.configureBuild("ZeroAimZone_iOS_test_0.0.3")
			else:
				ga.configureBuild("ZeroAimZone_0.0.21")
			
		# Initialize GameAnalytics with platform-specific keys
		print("[GameAnalysis] GA initializing...")
		var ios_game_key = "03273e27fff388ab9bc53aff8166a084"
		var ios_secret_key = "ecc4d017419bd1f86b9dbaeff2df62edce6ce427"
		var android_game_key = "eb2d56dee044bdbe4c4eb4372761993e"
		var android_secret_key = "db9e863877a4344885c15144952ed96bcc3402f0"
		
		if Env and Env.has_method("get_var"):
			var env_ios_gk = Env.get_var("GAMEANALYTICS_GAME_KEY_IOS")
			var env_ios_sk = Env.get_var("GAMEANALYTICS_SECRET_KEY_IOS")
			var env_and_gk = Env.get_var("GAMEANALYTICS_GAME_KEY_ANDROID")
			var env_and_sk = Env.get_var("GAMEANALYTICS_SECRET_KEY_ANDROID")
			if not env_ios_gk.is_empty(): ios_game_key = env_ios_gk
			if not env_ios_sk.is_empty(): ios_secret_key = env_ios_sk
			if not env_and_gk.is_empty(): android_game_key = env_and_gk
			if not env_and_sk.is_empty(): android_secret_key = env_and_sk
		if OS.get_name() == "iOS":
			ga.init(ios_game_key, ios_secret_key)
		else:
			ga.init(android_game_key, android_secret_key)
		print("[GameAnalysis] GameAnalytics initialized successfully.")
		
		# Buffer early events until native SDK session finishes starting
		_start_sdk_readiness_timer()
		
		# Initial app launch & splash screen event (Persisted one-time)
		track_ftue_step("app_launched")
		track_ftue_step("splash_screen")
		
		if EventBus:
			if EventBus.has_signal("firebase_failed"):
				EventBus.firebase_failed.connect(_on_firebase_failed)
			if EventBus.has_signal("auth_failed"):
				EventBus.auth_failed.connect(_on_auth_failed)
			if EventBus.has_signal("iap_purchase_success"):
				EventBus.iap_purchase_success.connect(_on_iap_purchase_success)
		if AuthManager and AuthManager.has_signal("initial_sync_completed"):
			if not AuthManager.initial_sync_completed.is_connected(_on_auth_initial_sync_completed):
				AuthManager.initial_sync_completed.connect(_on_auth_initial_sync_completed)
	else:
		print("[GameAnalysis] GameAnalytics singleton not found (Desktop Editor Mock [GA-DEV]).")
		if AuthManager and AuthManager.has_signal("initial_sync_completed"):
			if not AuthManager.initial_sync_completed.is_connected(_on_auth_initial_sync_completed):
				AuthManager.initial_sync_completed.connect(_on_auth_initial_sync_completed)
		_sdk_ready = true
		_flush_pending_events()
		track_ftue_step("app_launched")
		track_ftue_step("splash_screen")

# ==============================================================================
# APP LIFECYCLE NOTIFICATIONS & INTERRUPTION DETECTOR
# ==============================================================================

var _is_backgrounded: bool = false
var _was_in_match_when_backgrounded: bool = false
var _saved_backgrounded_arena: String = ""
var _saved_backgrounded_attempt: int = 1
var _saved_backgrounded_round: int = 1

func _notification(what: int) -> void:
	match what:
		NOTIFICATION_WM_CLOSE_REQUEST:
			var in_match = _is_match_active or is_gameplay_continuing()
			print("[GameAnalysis] LifeCycle Close/Exit Notification: %d (InMatch: %s)" % [what, str(in_match)])
			if in_match:
				var arena = _active_arena if not _active_arena.is_empty() else _get_current_arena_fallback()
				var attempt = _active_attempt if _active_attempt > 0 else 1
				_is_match_active = true  # Force-activate so fail_match() won't silently return when is_gameplay_continuing() was the trigger
				_sdk_ready = false
				fail_match("AppClosed", arena, attempt, false)
			else:
				_sdk_ready = false
			_save_pending_queue()
		NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_WM_WINDOW_FOCUS_OUT:
			if _is_backgrounded:
				return
			_is_backgrounded = true
			_sdk_ready = false
			var in_match = _is_match_active or is_gameplay_continuing()
			print("[GameAnalysis] Native Window Focus Out Notification: %d (InMatch: %s, Scene: %s)" % [what, str(in_match), str(get_tree().current_scene.name) if get_tree().current_scene else "None"])
			if in_match:
				_was_in_match_when_backgrounded = true
				_saved_backgrounded_arena = _active_arena if not _active_arena.is_empty() else _get_current_arena_fallback()
				_saved_backgrounded_attempt = _active_attempt if _active_attempt > 0 else 1
				_saved_backgrounded_round = _active_round if _active_round > 0 else 1
				print("[GameAnalysis] Window focus lost during match in %s (Round %d). Queuing Progression:Fail (reason=AppBackgrounded)." % [_saved_backgrounded_arena, _saved_backgrounded_round])
				# Force-activate so fail_match() won't silently return when is_gameplay_continuing() was the trigger
				_is_match_active = true
				fail_match("AppBackgrounded", _saved_backgrounded_arena, _saved_backgrounded_attempt, false)
			else:
				_was_in_match_when_backgrounded = false
			_save_pending_queue()
		NOTIFICATION_APPLICATION_PAUSED:
			if not _is_backgrounded:
				_is_backgrounded = true
				_sdk_ready = false
				var in_match = _is_match_active or is_gameplay_continuing()
				if in_match:
					_was_in_match_when_backgrounded = true
					_saved_backgrounded_arena = _active_arena if not _active_arena.is_empty() else _get_current_arena_fallback()
					_saved_backgrounded_attempt = _active_attempt if _active_attempt > 0 else 1
					_saved_backgrounded_round = _active_round if _active_round > 0 else 1
					_is_match_active = true
					fail_match("AppBackgrounded", _saved_backgrounded_arena, _saved_backgrounded_attempt, false)
				_save_pending_queue()
		NOTIFICATION_APPLICATION_FOCUS_IN, NOTIFICATION_APPLICATION_RESUMED, NOTIFICATION_WM_WINDOW_FOCUS_IN:
			if not _is_backgrounded:
				return
			_is_backgrounded = false
			print("[GameAnalysis] LifeCycle Resume Notification: %d" % what)
			call_deferred("_handle_app_resumed")

func _handle_app_resumed() -> void:
	# Buffer for 1.2s to allow native SDK onResume() session to start before flushing
	get_tree().create_timer(1.2, true).timeout.connect(_flush_after_resume)

func _flush_after_resume() -> void:
	print("[GameAnalysis] App resumed. Re-authorizing SDK and flushing pending events...")
	_sdk_ready = true
	_flush_pending_events()
	if _was_in_match_when_backgrounded:
		_was_in_match_when_backgrounded = false
		if is_gameplay_continuing():
			print("[GameAnalysis] Resumed back to active gameplay in %s (Round %d). Triggering Progression:Start (dim01=Resume)..." % [_saved_backgrounded_arena, _saved_backgrounded_round])
			_match_start_ticks = Time.get_ticks_msec()
			_is_match_active = true
			start_round(_saved_backgrounded_arena, _saved_backgrounded_attempt, _saved_backgrounded_round, "Resume")

func is_gameplay_continuing() -> bool:
	if not is_inside_tree():
		return false
	var current_scene = get_tree().current_scene
	if current_scene and ("GameScene" in current_scene.name or current_scene.name.to_lower().begins_with("game")):
		if GameManager and "in_game_ui" in GameManager and GameManager.in_game_ui:
			var ui = GameManager.in_game_ui
			if "active_panels" in ui and ui.active_panels is Dictionary:
				var result_panel = ui.active_panels.get(ui.RESULT_PANEL_PATH)
				if result_panel and is_instance_valid(result_panel) and result_panel.visible:
					return false
		return true
	return false

func _get_current_arena_fallback() -> String:
	if GameManager and "current_match" in GameManager and GameManager.current_match:
		var idx = GameManager.current_match.get("arena_index")
		if idx == 0: return "Tokyo"
		elif idx == 1: return "NewYork"
		elif idx == 2: return "Delhi"
		elif idx != null: return "Arena_%s" % str(idx)
	return "Arena"

# ==============================================================================
# 1. PROGRESSION EVENTS (MATCH LIFECYCLE & TIMING)
# ==============================================================================

var _active_round: int = 1

func get_and_increment_arena_attempt(arena_name: String) -> int:
	var clean_arena = _clean_str(arena_name)
	if GameManager and GameManager.save_manager:
		var attempt_no = GameManager.save_manager.increment_arena_attempt(clean_arena)
		if PlayerPrefs and PlayerPrefs.has_method("set_int"):
			PlayerPrefs.set_int("arena_attempt_" + clean_arena.to_lower(), attempt_no)
		return attempt_no

	var key = "arena_attempt_" + clean_arena.to_lower()
	var attempt = 1
	if PlayerPrefs and PlayerPrefs.has_method("get_int"):
		attempt = PlayerPrefs.get_int(key, 0) + 1
		PlayerPrefs.set_int(key, attempt)
	return attempt

func get_current_arena_attempt(arena_name: String) -> int:
	var clean_arena = _clean_str(arena_name)
	if GameManager and GameManager.save_manager:
		var attempt = GameManager.save_manager.get_arena_attempt(clean_arena)
		if attempt >= 0:
			return attempt

	var key = "arena_attempt_" + clean_arena.to_lower()
	if PlayerPrefs and PlayerPrefs.has_method("get_int"):
		return max(1, PlayerPrefs.get_int(key, 1))
	return 1

## Start progression when entering a match.
## Automatically increments attempt in PlayerPrefs for the given arena.
func start_match(arena_or_mode: String, attempt_n: int = -1, custom_dim01: String = "") -> void:
	var clean_arena = _clean_str(arena_or_mode)
	if clean_arena.is_empty():
		clean_arena = _get_current_arena_fallback()

	track_ftue_step("GAMEPLAY_START:%s" % clean_arena)

	if AnalyticsManager:
		AnalyticsManager.track_match_start(clean_arena)

	var attempt = attempt_n if attempt_n > 0 else get_and_increment_arena_attempt(clean_arena)

	_active_arena = clean_arena
	_active_attempt = attempt
	_active_round = 1
	_match_start_ticks = Time.get_ticks_msec()
	_is_match_active = true

	start_round(_active_arena, _active_attempt, 1, custom_dim01)

## Start a specific round within the current match.
func start_round(arena_or_mode: String = "", attempt_n: int = -1, round_n: int = 1, custom_dim01: String = "") -> void:
	var clean_arena = _clean_str(arena_or_mode) if not arena_or_mode.is_empty() else _active_arena
	if clean_arena.is_empty():
		clean_arena = _get_current_arena_fallback()
	var attempt = attempt_n if attempt_n > 0 else (_active_attempt if _active_attempt > 0 else get_current_arena_attempt(clean_arena))
	
	_active_arena = clean_arena
	_active_attempt = attempt
	_active_round = round_n
	_is_match_active = true
	if _match_start_ticks <= 0:
		_match_start_ticks = Time.get_ticks_msec()

	var attempt_str = "Attempt_%d" % attempt
	var round_str = "Round_%d" % round_n
	print("[GameAnalysis] Starting Round: %s %s %s" % [clean_arena, attempt_str, round_str])
	track_progression_event("Start", clean_arena, attempt_str, round_str, -1, custom_dim01)

## Complete a specific round.
func complete_round(is_win: bool, round_n: int = -1, coins_earned: int = 0, arena_override: String = "") -> void:
	var arena = _clean_str(arena_override) if not arena_override.is_empty() else _active_arena
	if arena.is_empty():
		arena = _get_current_arena_fallback()
	var attempt = _active_attempt if _active_attempt > 0 else get_current_arena_attempt(arena)
	var round_num = round_n if round_n > 0 else _active_round

	var attempt_str = "Attempt_%d" % attempt
	var round_str = "Round_%d" % round_num
	var outcome = "Win" if is_win else "Lose"
	print("[GameAnalysis] Round Completed: %s %s %s | Outcome=%s, Score=%d" % [arena, attempt_str, round_str, outcome, coins_earned])
	track_progression_event("Complete", arena, attempt_str, round_str, coins_earned, outcome)

## Complete progression when match reaches normal end (Win or Lose).
## Automatically calculates and logs match duration.
func complete_match(is_win: bool, coins_earned: int = 0, arena_override: String = "", attempt_override: int = -1) -> void:
	if not _is_match_active:
		return
	_is_match_active = false

	var arena = _clean_str(arena_override) if not arena_override.is_empty() else _active_arena
	if arena.is_empty():
		arena = _get_current_arena_fallback()
	var attempt = attempt_override if attempt_override > 0 else (_active_attempt if _active_attempt > 0 else get_current_arena_attempt(arena))
	var duration_sec: float = 0.0
	
	if _match_start_ticks > 0:
		duration_sec = (Time.get_ticks_msec() - _match_start_ticks) / 1000.0
	_match_start_ticks = 0

	track_ftue_step("GAMEPLAY_COMPLETE:%s" % arena)

	var outcome = "Win" if is_win else "Lose"
	print("[GameAnalysis] Match Completed: %s Attempt_%d Round_%d | Outcome=%s, Duration=%.2fs" % [arena, attempt, _active_round, outcome, duration_sec])

	if duration_sec > 0.0:
		track_gameplay_duration(arena, attempt, duration_sec)

## Fail progression when match is abnormally interrupted (Quit, Disconnect, Host Left, etc.).
## Interruption reason is recorded via CustomDimension01.
## Valid reasons: "Disconnect", "HostLeft", "AppClosed", "AppBackgrounded", "Home"
func fail_match(reason: String, arena_override: String = "", attempt_override: int = -1, bypass_queue: bool = false) -> void:
	if not _is_match_active:
		return
	_is_match_active = false

	var arena = _clean_str(arena_override) if not arena_override.is_empty() else _active_arena
	if arena.is_empty():
		arena = _get_current_arena_fallback()
	var attempt = attempt_override if attempt_override > 0 else (_active_attempt if _active_attempt > 0 else get_current_arena_attempt(arena))
	var duration_sec: float = 0.0
	
	if _match_start_ticks > 0:
		duration_sec = (Time.get_ticks_msec() - _match_start_ticks) / 1000.0
	_match_start_ticks = 0

	var attempt_str = "Attempt_%d" % attempt
	var round_str = "Round_%d" % _active_round
	var clean_reason = reason if reason in KNOWN_CUSTOM_DIMENSIONS_01 else "Disconnect"
	print("[GameAnalysis] Match Interrupted (Fail): %s %s %s | Reason=%s, Duration=%.2fs" % [arena, attempt_str, round_str, clean_reason, duration_sec])
	track_progression_event("Fail", arena, attempt_str, round_str, -1, clean_reason, bypass_queue)

	if duration_sec > 0.0:
		track_gameplay_duration(arena, attempt, duration_sec, bypass_queue)

func track_progression_event(status: String, progression01: String, progression02: String = "", progression03: String = "", score: int = -1, custom_dim01: String = "", bypass_queue: bool = false) -> void:
	if not _sdk_ready and not bypass_queue:
		print("[GameAnalysis] SDK not ready. Deferring progression event: %s %s (dim01=%s)" % [status, progression01, custom_dim01])
		_pending_events.append({
			"type": "progression",
			"status": status,
			"progression01": progression01,
			"progression02": progression02,
			"progression03": progression03,
			"score": score,
			"custom_dimension_01": custom_dim01
		})
		_save_pending_queue()
		return

	var custom_fields: Dictionary = {}
	if not custom_dim01.is_empty():
		_set_custom_dimension01(custom_dim01)
		custom_fields["custom_01"] = custom_dim01
	else:
		_set_custom_dimension01("")

	if ga:
		if score >= 0:
			ga.addProgressionEventWithScore(status, progression01, progression02, progression03, score, custom_fields)
			print("[GameAnalysis] Tracked progression event with score: %s %s %s %s (score: %d, dim01: %s)" % [status, progression01, progression02, progression03, score, custom_dim01])
		else:
			ga.addProgressionEvent(status, progression01, progression02, progression03, custom_fields)
			print("[GameAnalysis] Tracked progression event: %s %s %s %s (dim01: %s)" % [status, progression01, progression02, progression03, custom_dim01])
		
		# Immediately clear CustomDimension01 so it does not bleed into subsequent events
		_set_custom_dimension01("")
	else:
		print("[GameAnalysis-Mock] Progression event: %s %s %s %s (score: %d, dim01: %s)" % [status, progression01, progression02, progression03, score, custom_dim01])
		_set_custom_dimension01("")

# ==============================================================================
# 2. UI DESIGN EVENTS (CLICKS & SCREEN SWITCHES)
# ==============================================================================

## Generic UI Click tracker (Formats as "UI:Clicks:<location>:<button>")
func track_ui_click(event_path: String) -> void:
	var path = event_path.replace("+", "").replace(" ", "_")
	if not path.begins_with("UI:Clicks:"):
		if path.begins_with("UI:"):
			path = path.replace("UI:", "UI:Clicks:")
		else:
			path = "UI:Clicks:" + path
	track_design_event(path)

## Track shop item selection/click (e.g. "Coins", "Pack1" -> "UI:Clicks:Shop:Coins:Pack1")
func track_shop_click(currency_type: String, item_name: String) -> void:
	var clean_curr = _clean_str(currency_type)
	var clean_item = _clean_str(item_name)
	track_design_event("UI:Clicks:Shop:%s:%s" % [clean_curr, clean_item])

## Track gun screen tab click (e.g. "Weapons", "Cosmetics" -> "UI:Clicks:GunScreen:Cosmetics")
func track_gun_screen_click(tab: String) -> void:
	track_design_event("UI:Clicks:GunScreen:%s" % _clean_str(tab))

## Track settings actions and toggles (e.g. "UI:Clicks:Settings:MusicToggle", "UI:Clicks:Settings:DeleteAccount:Attempt")
func track_settings_click(action: String, sub_action: String = "") -> void:
	var path = "UI:Clicks:Settings:%s" % _clean_str(action)
	if not sub_action.is_empty():
		path += ":%s" % _clean_str(sub_action)
	track_design_event(path)

## Track Screen Transitions (e.g. "Home_to_Arena", "Arena_to_Gameplay", "Gameplay_to_Home")
func track_screen_switch(from_screen: String, to_screen: String) -> void:
	track_design_event("UI:ScreenSwitch:%s_to_%s" % [_clean_str(from_screen), _clean_str(to_screen)])

# ==============================================================================
# 3. META EVENTS (DAILY REWARDS, CRATES, COSMETICS, WEAPONS)
# ==============================================================================

func _on_auth_initial_sync_completed(val: float) -> void:
	if val >= 1.0:
		_resolve_ftue_auth_sync()

func _on_auth_sync_fallback_timeout() -> void:
	if not _auth_sync_resolved:
		print("[GameAnalysis] Auth sync resolution timeout reached. Resolving FTUE state...")
		_resolve_ftue_auth_sync()

func _resolve_ftue_auth_sync() -> void:
	if _auth_sync_resolved:
		return
	_auth_sync_resolved = true

	if is_existing_player():
		print("[GameAnalysis] Returning player confirmed upon cloud sync. Dropping %d early FTUE events and marking FTUE complete." % _early_ftue_buffer.size())
		_early_ftue_buffer.clear()
		_ftue_completed_steps["is_existing_player"] = true
		_save_ftue_state()
	else:
		print("[GameAnalysis] Fresh new player confirmed. Dispatching %d buffered early FTUE steps." % _early_ftue_buffer.size())
		var buffered = _early_ftue_buffer.duplicate()
		_early_ftue_buffer.clear()
		for step_name in buffered:
			track_ftue_step(step_name)


func is_existing_player() -> bool:
	if _ftue_completed_steps.get("is_existing_player", false) == true:
		return true

	if GameManager and GameManager.save_manager and GameManager.save_manager.game_data:
		var p_data: Dictionary = GameManager.save_manager.game_data.get("player_data", {})
		if p_data.get("ftue_completed", false) == true:
			return true
		if int(p_data.get("total_game_played", 0)) > 0:
			return true
		if int(p_data.get("win_game", 0)) > 0:
			return true
		if int(p_data.get("level", 1)) > 1 or int(p_data.get("xp", 0)) > 0:
			return true

	if AuthManager and AuthManager.get("_data_store") != null:
		var ds: Dictionary = AuthManager._data_store
		var p_data: Dictionary = ds.get("playerData", {})
		if int(p_data.get("totalSessions", 1)) > 1:
			return true
		var g_stats: Dictionary = p_data.get("gameStats", {})
		var stats_pdata: Dictionary = g_stats.get("player_data", {})
		if stats_pdata.get("ftue_completed", false) == true:
			return true
		if int(stats_pdata.get("total_game_played", 0)) > 0 or int(stats_pdata.get("level", 1)) > 1 or int(stats_pdata.get("win_game", 0)) > 0:
			return true

	return false


## One-time FTUE step tracker with disk persistence
func track_ftue_step(step_name: String) -> void:
	if _ftue_completed_steps.get(step_name, false) == true:
		return

	# If the user is already confirmed as an existing player (account with matches/progress restored), do not fire FTUE events
	if is_existing_player():
		_ftue_completed_steps[step_name] = true
		_ftue_completed_steps["is_existing_player"] = true
		_save_ftue_state()
		print("[GameAnalysis] Skipping FTUE step '%s' for existing player." % step_name)
		return

	# If auth sync is still pending during startup, hold early FTUE steps in buffer until cloud state is known
	if not _auth_sync_resolved:
		if not _early_ftue_buffer.has(step_name):
			print("[GameAnalysis] Buffering early FTUE step '%s' pending cloud auth sync..." % step_name)
			_early_ftue_buffer.append(step_name)
		return

	_ftue_completed_steps[step_name] = true
	_save_ftue_state()
	var event_id := step_name
	if not event_id.begins_with("FTUE:"):
		if event_id.begins_with("ftue:"):
			event_id = "FTUE:" + event_id.substr(5)
		else:
			event_id = "FTUE:" + event_id
	track_design_event(event_id)

## FTUE: Splash Screen & Loading Auth
func track_splash_screen() -> void:
	track_ftue_step("splash_screen")

func track_loading_auth() -> void:
	track_ftue_step("loading_auth")

## FTUE: Terms & Conditions Popup
func track_terms_and_conditions_popup_shown() -> void:
	track_ftue_step("terms_and_conditions_popup_shown")

func track_terms_and_conditions_accepted() -> void:
	track_ftue_step("terms_and_conditions_accepted")

## FTUE: Gameplay Start & Complete
func track_ftue_gameplay_start(arena: String = "Tokyo") -> void:
	track_ftue_step("GAMEPLAY_START:%s" % _clean_str(arena))

func track_ftue_gameplay_complete(arena: String = "Tokyo") -> void:
	track_ftue_step("GAMEPLAY_COMPLETE:%s" % _clean_str(arena))

## Daily reward claimed (e.g. day 1 -> "Meta:DailyRewards:claim_day_1", Day 1 also tracked as FTUE)
func track_daily_reward_claim(day: int) -> void:
	track_design_event("Meta:DailyRewards:claim_day_%d" % day)
	if day == 1:
		track_ftue_step("DailyRewards:claim_day_1")

## Crate actions (e.g. tier: "bronze"|"silver"|"gold"|"premium", action: "unlock"|"open")
func track_crate_event(crate_tier: String, action: String) -> void:
	track_design_event("Meta:Crate:%s:%s" % [_clean_str(crate_tier).to_lower(), _clean_str(action).to_lower()])

## Profile updates (Name change, Avatar equipped, Frame equipped)
func track_profile_name_changed() -> void:
	track_design_event("Meta:Profile:NameChange")

func track_profile_avatar_changed(avatar_idx: int) -> void:
	track_design_event("Meta:Profile:Avatar:Avatar_%d" % avatar_idx)

func track_profile_frame_changed(frame_idx: int) -> void:
	track_design_event("Meta:Profile:Frame:Frame_%d" % frame_idx)

## Cosmetics unlocked or equipped
func track_cosmetics_event(action: String, item_id: String) -> void:
	track_design_event("Meta:Cosmetics:%s:%s" % [_clean_str(action).to_lower(), _clean_str(item_id)])

## Weapons unlocked or equipped
func track_weapons_event(action: String, item_id: String) -> void:
	track_design_event("Meta:Weapons:%s:%s" % [_clean_str(action).to_lower(), _clean_str(item_id)])

var _unlocked_guns_tracked: Dictionary = {}
var _unlocked_skins_tracked: Dictionary = {}

func track_gun_unlocked(gun_idx: int, gun_name: String = "") -> void:
	if _unlocked_guns_tracked.has(gun_idx):
		return
	_unlocked_guns_tracked[gun_idx] = true
	var name_str = gun_name if not gun_name.is_empty() else ("Gun_%d" % gun_idx)
	track_design_event("Meta:Weapons:Unlocked:%s" % _clean_str(name_str))

func track_skin_unlocked(gun_idx: int, skin_idx: int, gun_name: String = "") -> void:
	var key = "%d_%d" % [gun_idx, skin_idx]
	if _unlocked_skins_tracked.has(key):
		return
	_unlocked_skins_tracked[key] = true
	var name_str = gun_name if not gun_name.is_empty() else ("Gun_%d" % gun_idx)
	track_design_event("Meta:Cosmetic:Skin_unlock:%s:Skin_%d" % [_clean_str(name_str), skin_idx])

func track_skin_equipped(gun_idx: int, skin_idx: int, gun_name: String = "") -> void:
	var name_str = gun_name if not gun_name.is_empty() else ("Gun_%d" % gun_idx)
	track_design_event("Meta:Cosmetic:Skin_equipped:%s:Skin_%d" % [_clean_str(name_str), skin_idx])

# ==============================================================================
# 4. GAMEPLAY EVENTS (DURATION)
# ==============================================================================

## Duration of gameplay in seconds
func track_gameplay_duration(arena_or_lan: String, attempt_n: int, duration_seconds: float, bypass_queue: bool = false) -> void:
	var path = "Gameplay:Duration:%s:Attempt_%d" % [_clean_str(arena_or_lan), attempt_n]
	track_design_event(path, duration_seconds, bypass_queue)

# ==============================================================================
# 5. ECONOMY (RESOURCE) TRACKING
# ==============================================================================

## Economy flow tracking: flow_type is RESOURCE_FLOW_TYPE_SOURCE or RESOURCE_FLOW_TYPE_SINK
func track_economy_event(flow_type: int, currency: String, amount: float, item_type: String, item_id: String) -> void:
	if amount <= 0.0:
		return
	var flow_str = "Source" if flow_type == RESOURCE_FLOW_TYPE_SOURCE else "Sink"
	var clean_currency = _clean_str(currency)
	var clean_item_type = _clean_str(item_type)
	var clean_item_id = _clean_str(item_id)
	var event_name = "Economy:%s:%s:%s:%s" % [flow_str, clean_currency, clean_item_type, clean_item_id]
	track_design_event(event_name, amount)

func track_resource_event(flow_type: int, resource_type: String, amount: float, item_type: String, item_id: String) -> void:
	track_economy_event(flow_type, resource_type, amount, item_type, item_id)

# ==============================================================================
# 6. ERROR & TECHNICAL TRACKING
# ==============================================================================

func track_error_event(severity: int, message: String, bypass_queue: bool = false) -> void:
	var severity_str = "info"
	match severity:
		ERROR_SEVERITY_DEBUG: severity_str = "debug"
		ERROR_SEVERITY_INFO: severity_str = "info"
		ERROR_SEVERITY_WARNING: severity_str = "warning"
		ERROR_SEVERITY_ERROR: severity_str = "error"
		ERROR_SEVERITY_CRITICAL: severity_str = "critical"

	if not _sdk_ready and not bypass_queue:
		print("[GameAnalysis] SDK not ready. Deferring error event: Severity=%s, Message=%s" % [severity_str, message])
		_pending_events.append({
			"type": "error",
			"severity": severity,
			"message": message
		})
		_save_pending_queue()
		return

	if ga:
		if ga.has_method("addErrorEvent"):
			ga.addErrorEvent(severity_str, message, {})
			print("[GameAnalysis] Tracked native error event: Severity=%s, Message=%s" % [severity_str, message])
			return
			
	track_design_event("tech:error:" + severity_str + ":" + message.left(40).replace(":", "_").replace(" ", "_"), null, bypass_queue)

# ==============================================================================
# 7. CORE DESIGN & AD & IAP TRACKING
# ==============================================================================

func track_design_event(event_name: String, value = null, bypass_queue: bool = false) -> void:
	# Debounce identical design events fired rapidly within DEBOUNCE_THRESHOLD_MS (bypass when flushing queue)
	if not bypass_queue:
		var now = Time.get_ticks_msec()
		if _last_event_times.has(event_name):
			if now - int(_last_event_times[event_name]) < DEBOUNCE_THRESHOLD_MS:
				return
		_last_event_times[event_name] = now

	if not _sdk_ready and not bypass_queue:
		print("[GameAnalysis] SDK not ready. Deferring design event: %s" % event_name)
		_pending_events.append({
			"type": "design",
			"name": event_name,
			"value": value
		})
		_save_pending_queue()
		return

	if ga:
		if value != null:
			ga.addDesignEventWithValue(event_name, float(value), {})
			print("[GameAnalysis] Tracked design event: %s with value: %f" % [event_name, float(value)])
		else:
			ga.addDesignEvent(event_name, {})
			print("[GameAnalysis] Tracked design event: %s" % event_name)
	else:
		print("[GameAnalysis-Mock] Design event: %s (value: %s)" % [event_name, str(value)])

func _set_custom_dimension01(value: String) -> void:
	if not ga:
		return
	if ga.has_method("setCustomDimension01"):
		ga.setCustomDimension01(value)
		if value.is_empty():
			print("[GameAnalysis] CustomDimension01 cleared.")
		else:
			print("[GameAnalysis] CustomDimension01 set to: \"%s\"" % value)
	else:
		push_warning("[GameAnalysis] setCustomDimension01 not found on GA singleton.")

func _map_ga_no_ad_reason(reason: String) -> String:
	var clean := reason.to_lower().strip_edges()
	if clean.is_empty():
		return "unknown"
	if clean in ["no_fill", "invalid_request", "offline", "unable_to_precache", "internal_error", "unknown"]:
		return clean
	if "600204" in clean or "1001" in clean or "no_fill" in clean or "nofill" in clean or "inventory" in clean:
		return "no_fill"
	if "600202" in clean or "1004" in clean or "invalid" in clean or "disabled" in clean or "plugin_unavailable" in clean:
		return "invalid_request"
	if "timeout" in clean or "600200" in clean or "1002" in clean or "network" in clean or "offline" in clean:
		return "offline"
	if "2001" in clean or "2002" in clean or "not_ready" in clean or "expired" in clean or "unavailable" in clean or "precache" in clean:
		return "unable_to_precache"
	if "600201" in clean or "1003" in clean or "threw" in clean or "crash" in clean or "internal" in clean or "exception" in clean or "null" in clean:
		return "internal_error"
	return "unknown"

func track_ad_event(action: int, ad_type: int, ad_sdk_name: String, ad_placement: String, duration: int = -1, no_ad_reason: String = "", bypass_queue: bool = false) -> void:
	var action_str = "clicked"
	match action:
		AD_ACTION_CLICKED: action_str = "clicked"
		AD_ACTION_SHOW: action_str = "show"
		AD_ACTION_FAILED_SHOW: action_str = "failed_show"
		AD_ACTION_REWARD_RECEIVED: action_str = "reward_received"
		
	var type_str = "interstitial"
	match ad_type:
		AD_TYPE_VIDEO: type_str = "video"
		AD_TYPE_REWARDED_VIDEO: type_str = "rewarded_video"
		AD_TYPE_INTERSTITIAL: type_str = "interstitial"
		AD_TYPE_BANNER: type_str = "banner"

	var resolved_placement = ad_placement
	if ad_placement == "post_match":
		var arena = _active_arena if not _active_arena.is_empty() else _get_current_arena_fallback()
		var attempt = _active_attempt
		if attempt <= 0:
			attempt = get_current_arena_attempt(arena)
		resolved_placement = "post_match_%s_Attempt_%d" % [arena, max(1, attempt)]

	if not _sdk_ready and not bypass_queue:
		print("[GameAnalysis] SDK not ready. Deferring ad event: Action=%s, Type=%s, Sdk=%s, Placement=%s" % [action_str, type_str, ad_sdk_name, resolved_placement])
		_pending_events.append({
			"type": "ad",
			"action": action,
			"ad_type": ad_type,
			"ad_sdk_name": ad_sdk_name,
			"ad_placement": resolved_placement,
			"duration": duration,
			"no_ad_reason": no_ad_reason
		})
		_save_pending_queue()
		return

	if ga and action_str in ["clicked", "show", "failed_show", "reward_received"]:
		if ga.has_method("addAdEvent"):
			var params = {}
			if duration >= 0:
				params["duration"] = duration
			if not no_ad_reason.is_empty() or action_str == "failed_show":
				var mapped_reason := _map_ga_no_ad_reason(no_ad_reason)
				params["reason"] = mapped_reason
				params["noAdReason"] = mapped_reason
				params["no_ad_reason"] = mapped_reason
			ga.addAdEvent(action_str, type_str, ad_sdk_name.to_lower(), resolved_placement, params)
			print("[GameAnalysis] Tracked native ad event: Action=%s, Type=%s, Sdk=%s, Placement=%s, Params=%s" % [action_str, type_str, ad_sdk_name.to_lower(), resolved_placement, str(params)])
			return
		
	track_design_event("ads:" + action_str + ":" + type_str + "_" + resolved_placement.replace(":", "_").replace(" ", "_"), null, bypass_queue)

## Track Rewarded Ad Opt-In (Design event triggered when the player opts in to view a rewarded ad)
func track_reward_opt_in(placement: String = "default") -> void:
	var clean_placement = _clean_str(placement)
	if clean_placement.is_empty():
		clean_placement = "default"
	track_design_event("UI:Clicks:RewardOptIn:%s" % clean_placement)

func track_business_event(currency: String, amount_cents: int, item_type: String, item_id: String, cart_type: String, receipt: String = "", signature: String = "", bypass_queue: bool = false) -> void:
	if not _sdk_ready and not bypass_queue:
		print("[GameAnalysis] SDK not ready. Deferring business event: Currency=%s, Amount=%d, ItemId=%s" % [currency, amount_cents, item_id])
		_pending_events.append({
			"type": "business",
			"currency": currency,
			"amount_cents": amount_cents,
			"item_type": item_type,
			"item_id": item_id,
			"cart_type": cart_type,
			"receipt": receipt,
			"signature": signature
		})
		_save_pending_queue()
		return

	if ga:
		if ga.has_method("addBusinessEvent"):
			var opt_args = {}
			if not receipt.is_empty():
				opt_args["receipt"] = receipt
			if not signature.is_empty():
				opt_args["signature"] = signature
			
			var platform = OS.get_name()
			if platform == "Android":
				opt_args["store"] = "google_play"
			
			ga.addBusinessEvent(currency, amount_cents, item_type, item_id, cart_type, opt_args)
			print("[GameAnalysis] Tracked native business event: Currency=%s, Amount=%d, ItemType=%s, ItemId=%s, CartType=%s, OptArgs=%s" % [currency, amount_cents, item_type, item_id, cart_type, str(opt_args)])
			return
			
	var event_name = "business:%s:%s:%s:%s" % [currency.to_lower(), item_type, item_id, cart_type]
	track_design_event(event_name, float(amount_cents) / 100.0, bypass_queue)

func _on_network_connectivity_changed(_is_connected: bool) -> void:
	pass

func _on_firebase_failed(error_code: int, message: String) -> void:
	track_error_event(ERROR_SEVERITY_ERROR, "Firebase error %d: %s" % [error_code, message])

func _on_auth_failed(code: int, message: String) -> void:
	track_error_event(ERROR_SEVERITY_ERROR, "Auth error %d: %s" % [code, message])

func _on_iap_purchase_success(product_id: String, purchase_data: Dictionary = {}) -> void:
	var info: Dictionary = {}
	if IAP_PRODUCT_CATALOG.has(product_id):
		info = IAP_PRODUCT_CATALOG[product_id]
		if not info.get("is_real_money", false):
			track_design_event("economy:iap:ad_gated:" + product_id)
			return

	var currency = "USD"
	var amount_cents = 99
	var price_retrieved_from_store = false
	
	var iap_manager = null
	if AuthManager and "_iap_manager" in AuthManager and AuthManager._iap_manager:
		iap_manager = AuthManager._iap_manager

	if iap_manager:
		var prod_dict: Dictionary = {}
		if "products" in iap_manager and iap_manager.products is Dictionary and iap_manager.products.has(product_id):
			prod_dict = iap_manager.products[product_id]
		elif "cached_product_details" in iap_manager and iap_manager.cached_product_details is Dictionary and iap_manager.cached_product_details.has(product_id):
			prod_dict = iap_manager.cached_product_details[product_id]

		if not prod_dict.is_empty():
			var list_details = prod_dict.get("one_time_purchase_offer_details_list", prod_dict.get("oneTimePurchaseOfferDetailsList", null))
			if (list_details is Array or list_details is PackedStringArray) and list_details.size() > 0:
				var offer = list_details[0]
				if offer is Dictionary:
					currency = offer.get("price_currency_code", "USD").to_upper()
					var micros = int(offer.get("price_amount_micros", 990000))
					var minor_units = get_minor_units(currency)
					var divisor = int(pow(10, 6 - minor_units))
					amount_cents = micros / divisor
					price_retrieved_from_store = true
			
			if not price_retrieved_from_store:
				if prod_dict.has("one_time_purchase_offer_details") and prod_dict.one_time_purchase_offer_details is Dictionary:
					var offer = prod_dict.one_time_purchase_offer_details
					currency = offer.get("price_currency_code", "USD").to_upper()
					var micros = int(offer.get("price_amount_micros", 990000))
					var minor_units = get_minor_units(currency)
					var divisor = int(pow(10, 6 - minor_units))
					amount_cents = micros / divisor
					price_retrieved_from_store = true
				elif prod_dict.has("price_currency_code") and prod_dict.has("price_amount_micros"):
					currency = prod_dict.get("price_currency_code", "USD").to_upper()
					var micros = int(prod_dict.get("price_amount_micros", 990000))
					var minor_units = get_minor_units(currency)
					var divisor = int(pow(10, 6 - minor_units))
					amount_cents = micros / divisor
					price_retrieved_from_store = true
			
	if not price_retrieved_from_store:
		if not info.is_empty():
			currency = info.get("currency", "USD")
			amount_cents = info.get("amount", 99)

	var reward_type = purchase_data.get("reward_type", "")
	var reward_amount = int(purchase_data.get("reward_amount", 0))

	var item_type = "Diamonds"
	var item_id = "100_gems"
	var cart_type = "Shop"

	if IAP_PRODUCT_CATALOG.has(product_id):
		var cat = IAP_PRODUCT_CATALOG[product_id]
		item_type = cat.get("item_type", "Diamonds")
		item_id = cat.get("item_id", product_id)
		cart_type = cat.get("cart_type", "Shop")
	elif reward_type == "NoAds" or product_id == "remove_ad" or product_id == "remove_ads" or "noads" in product_id.to_lower() or "remove_ad" in product_id.to_lower():
		item_type = "NoAds"
		item_id = "remove_ad"
		cart_type = "Shop"
	elif reward_type == "Diamonds" or reward_amount > 0:
		var amt = reward_amount if reward_amount > 0 else 100
		item_type = "Diamonds"
		item_id = "%d_gems" % amt
		cart_type = "Shop"
	elif product_id == "test_id":
		item_type = "Diamonds"
		item_id = "100_gems"
		cart_type = "Shop"
	else:
		item_type = "Diamonds"
		item_id = _clean_str(product_id)
		cart_type = "Shop"

	var receipt = purchase_data.get("original_json", purchase_data.get("originalJson", purchase_data.get("purchase_token", "")))
	var signature = purchase_data.get("signature", purchase_data.get("purchaseSignature", purchase_data.get("signature", "")))
		
	track_business_event(currency, amount_cents, item_type, item_id, cart_type, receipt, signature)

# ==============================================================================
# DISK PERSISTENCE & QUEUE MANAGEMENT
# ==============================================================================

func _save_pending_queue() -> void:
	var file = FileAccess.open(QUEUE_FILE, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(_pending_events))
		file.close()

func _load_pending_queue() -> void:
	if FileAccess.file_exists(QUEUE_FILE):
		var file = FileAccess.open(QUEUE_FILE, FileAccess.READ)
		if file:
			var parsed = JSON.parse_string(file.get_as_text())
			file.close()
			if parsed is Array:
				for item in parsed:
					if item is Dictionary:
						_pending_events.append(item)

func _save_ftue_state() -> void:
	var file = FileAccess.open(FTUE_FILE, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(_ftue_completed_steps))
		file.close()

func _load_ftue_state() -> void:
	if FileAccess.file_exists(FTUE_FILE):
		var file = FileAccess.open(FTUE_FILE, FileAccess.READ)
		if file:
			var parsed = JSON.parse_string(file.get_as_text())
			file.close()
			if parsed is Dictionary:
				_ftue_completed_steps = parsed

const SDK_SESSION_INIT_DELAY_SEC: float = 2.5

func _start_sdk_readiness_timer() -> void:
	if not ga:
		_sdk_ready = true
		_flush_pending_events()
		return
		
	_sdk_ready = false
	print("[GameAnalysis] Buffering early events for %.1fs while native session initializes..." % SDK_SESSION_INIT_DELAY_SEC)
	get_tree().create_timer(SDK_SESSION_INIT_DELAY_SEC, true).timeout.connect(_on_sdk_session_ready)

func _on_sdk_session_ready() -> void:
	print("[GameAnalysis] Native session initialization buffer elapsed (%.1fs). SDK ready. Flushing events..." % SDK_SESSION_INIT_DELAY_SEC)
	_sdk_ready = true
	_flush_pending_events()

func _flush_pending_events() -> void:
	if _pending_events.is_empty():
		_sdk_ready = true
		return

	print("[GameAnalysis] SDK is authorized/ready. Flushing %d deferred events." % _pending_events.size())
	
	var queue_to_flush = _pending_events.duplicate()
	_pending_events.clear()
	_save_pending_queue()
	
	for event in queue_to_flush:
		match event.type:
			"design":
				track_design_event(event.name, event.value, true)
			"progression":
				var dim01 = event.get("custom_dimension_01", "")
				track_progression_event(event.status, event.progression01, event.progression02, event.progression03, event.score, dim01, true)
			"error":
				track_error_event(event.severity, event.message, true)
			"ad":
				track_ad_event(event.action, event.ad_type, event.ad_sdk_name, event.ad_placement, event.duration, event.no_ad_reason, true)
			"business":
				track_business_event(event.currency, event.amount_cents, event.item_type, event.item_id, event.cart_type, event.receipt, event.signature, true)
				
	if not _pending_events.is_empty():
		_flush_pending_events()
	else:
		_sdk_ready = true
		_save_pending_queue()

func _clean_str(text: String) -> String:
	return text.strip_edges().replace(":", "_").replace(" ", "_").replace("+", "").replace("-", "_").replace("$", "")
