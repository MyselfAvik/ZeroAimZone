extends Node

signal auth_state_changed(is_logged_in: bool)
signal guest_login(user_id: String)
signal provider_login(user_id: String, email: String)
signal auth_error(message: String)
signal delete_complete
signal delete_failed
signal iap_manager_ready(manager: Object)
signal handshake_finished
signal remote_config_received(config: Dictionary)
signal remote_config_error(error: String)
signal initial_sync_completed(value: float)

var auth_error_state: bool = false
var current_user_id: String = ""
var auth_session_id: int = 0
var is_pggs_checking: bool = false
var is_firebase_logging_in: bool = false
var is_firestore_data_fetched: bool = false 
var remote_config_data: Dictionary = {}
var _is_auth_flow_running: bool = false
var _is_logout_or_delete_in_progress: bool = false
var _first_auth_attempt_done: bool = false
var _last_auth_code: String = ""
var _last_auth_display_name: String = ""
var _link_retry_count: int = 0

const MAX_LINK_RETRIES: int = 2

func is_authenticated() -> bool:
	return not current_user_id.is_empty()

const DATA_PATH := "user://auth_system_user_data.json"
const REMOTE_CONFIG_CACHE_PATH := "user://remote_config_cache.json"
const REMOTE_CONFIG_CACHE_TTL_SECONDS: int = 3600 # 1 hour

class RemoteConfigCompat extends RefCounted:
	signal config_activated(values: Dictionary)
	signal fetch_failed(values: Dictionary)

var _network_monitor: NetworkMonitor
var _data_store: Dictionary = AuthData.data_store()
var _sync_handler: Node = null
var _iap_manager: IAPManager = null
var _remote_config := RemoteConfigCompat.new()
var _play_games_sign_in: PlayGamesSignInClient
var _play_games_players: PlayGamesPlayersClient
var _session_start_ticks: int = 0

func _load_data_store() -> void:
	if FileAccess.file_exists(DATA_PATH):
		var file := FileAccess.open(DATA_PATH, FileAccess.READ)
		if file != null:
			var text := file.get_as_text().strip_edges()
			if not text.is_empty():
				var json := JSON.new()
				var err := json.parse(text)
				if err == OK and json.data is Dictionary:
					_data_store = AuthData.normalize_store(json.data)
					print("[AuthManager] Loaded persistent data store. Stored User ID: '", _data_store.playerData.userId, "', Pending Writes: ", _data_store.pendingWrites.size(), ", Unsynced: ", _data_store.hasUnsyncedChanges)
					return
				else:
					push_warning("[AuthManager] Invalid or corrupted JSON in '%s'. Falling back to default data store." % DATA_PATH)
			else:
				push_warning("[AuthManager] Empty data store file at '%s'." % DATA_PATH)
	_data_store = AuthData.data_store()

func _save_data_store() -> void:
	var file := FileAccess.open(DATA_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(_data_store, "\t"))

func _load_remote_config_cache() -> Dictionary:
	if FileAccess.file_exists(REMOTE_CONFIG_CACHE_PATH):
		var file := FileAccess.open(REMOTE_CONFIG_CACHE_PATH, FileAccess.READ)
		if file != null:
			var text := file.get_as_text().strip_edges()
			if not text.is_empty():
				var json := JSON.new()
				var err := json.parse(text)
				if err == OK and json.data is Dictionary:
					return json.data
	return {}

func _save_remote_config_cache(entries: Dictionary, timestamp: int) -> void:
	var cache_data := {
		"last_fetch_unix": timestamp,
		"entries": entries
	}
	var file := FileAccess.open(REMOTE_CONFIG_CACHE_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(cache_data, "\t"))
		print("[RemoteConfig] Saved remote config to local cache at '%s' (timestamp: %d)." % [REMOTE_CONFIG_CACHE_PATH, timestamp])

static func _delete_file(godot_path: String) -> void:
	if FileAccess.file_exists(godot_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(godot_path))

func _flush_session_time_to_store() -> void:
	if _session_start_ticks > 0:
		var elapsed := int((Time.get_ticks_msec() - _session_start_ticks) / 1000.0)
		_data_store.playerData.totalScreenTimeSeconds = int(_data_store.playerData.get("totalScreenTimeSeconds", 0)) + elapsed
		_session_start_ticks = Time.get_ticks_msec()

func reset_session() -> void:
	_data_store = AuthData.data_store()
	_delete_file(DATA_PATH)
	reset_flags()

func reset_flags() -> void:
	print("[AuthManager] Resetting auth flags.")
	auth_session_id += 1
	is_firebase_logging_in = false
	is_pggs_checking = false
	is_firestore_data_fetched = false
	auth_error_state = false
	_first_auth_attempt_done = false
	_is_auth_flow_running = false
	_is_fetching_remote_config = false
	_last_synced_stats = {}
	_data_store.hasUnsyncedChanges = false
	_link_retry_count = 0

	for child in get_children():
		if child is HTTPRequest:
			child.cancel_request()
			child.queue_free()

	if Firebase and Firebase.get("Auth"):
		for child in Firebase.Auth.get_children():
			if child is HTTPRequest:
				child.cancel_request()
				child.queue_free()

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

	_load_data_store()

	var cached_rc := _load_remote_config_cache()
	if not cached_rc.is_empty() and cached_rc.has("entries") and cached_rc["entries"] is Dictionary:
		remote_config_data = cached_rc["entries"]
		print("[RemoteConfig] Initialized with cached data from '%s'." % REMOTE_CONFIG_CACHE_PATH)

	_session_start_ticks = Time.get_ticks_msec()
	_data_store.playerData.totalSessions = int(_data_store.playerData.get("totalSessions", 0)) + 1
	var dt_utc := Time.get_datetime_dict_from_system(true)
	_data_store.playerData.lastSessionDateUTC = "%02d-%02d-%04d" % [dt_utc.day, dt_utc.month, dt_utc.year]
	_save_data_store()

	print("[AuthManager] Initializing AuthManager on platform: ", OS.get_name())

	_iap_manager = IAPManager.new()
	add_child(_iap_manager)
	iap_manager_ready.emit(_iap_manager)

	GodotPlayGameServices.initialize()

	_play_games_sign_in = PlayGamesSignInClient.new()
	add_child(_play_games_sign_in)

	_play_games_players = PlayGamesPlayersClient.new()
	add_child(_play_games_players)
	_network_monitor = NetworkMonitor.new()
	add_child(_network_monitor)
	if OS.get_name() == "Android":
		var avail := FirebaseSyncAndroid.is_available()
		print("[AuthManager] Android FirebaseSync plugin available on boot: ", avail)
	elif OS.get_name() == "iOS":
		var avail := FirebaseSyncIOSClient.is_available()
		print("[AuthManager] iOS FirebaseSync plugin available on boot: ", avail)

	_register_events()
	call_deferred("_start_auth_sequence")

func _register_events() -> void:
	if not _play_games_sign_in.user_authenticated.is_connected(_on_play_games_user_authenticated):
		_play_games_sign_in.user_authenticated.connect(_on_play_games_user_authenticated)
	if not _play_games_sign_in.server_side_access_requested.is_connected(_on_play_games_server_side_access):
		_play_games_sign_in.server_side_access_requested.connect(_on_play_games_server_side_access)
	if not _play_games_players.current_player_loaded.is_connected(_on_play_games_current_player_loaded):
		_play_games_players.current_player_loaded.connect(_on_play_games_current_player_loaded)
	if _network_monitor and not _network_monitor.internet_state_changed.is_connected(_on_internet_state_changed):
		_network_monitor.internet_state_changed.connect(_on_internet_state_changed)

	if OS.get_name() == "iOS" and GameCenterManager:
		if not GameCenterManager.user_authenticated.is_connected(_on_game_center_user_authenticated):
			GameCenterManager.user_authenticated.connect(_on_game_center_user_authenticated)

	if Firebase and Firebase.get("Auth"):
		var auth_node = Firebase.Auth
		if not auth_node.login_succeeded.is_connected(_on_firebase_login_succeeded):
			auth_node.login_succeeded.connect(_on_firebase_login_succeeded)
		if not auth_node.signup_succeeded.is_connected(_on_firebase_login_succeeded):
			auth_node.signup_succeeded.connect(_on_firebase_login_succeeded)
		if not auth_node.login_failed.is_connected(_on_firebase_login_failed):
			auth_node.login_failed.connect(_on_firebase_login_failed)
		if not auth_node.logged_out.is_connected(_on_firebase_logged_out):
			auth_node.logged_out.connect(_on_firebase_logged_out)
		if auth_node.has_signal("token_refresh_succeeded") and not auth_node.token_refresh_succeeded.is_connected(_on_firebase_token_refresh_succeeded):
			auth_node.token_refresh_succeeded.connect(_on_firebase_token_refresh_succeeded)
		print("[AuthManager] Connected to Firebase.Auth signals successfully.")
	else:
		print("[AuthManager] Waiting for Firebase Autoload to connect signals...")
		get_tree().create_timer(0.2).timeout.connect(_register_events)

func set_game_sync_handler(handler: Node) -> void:
	print("[AuthManager] Registered game sync handler: ", str(handler.name) if handler else "null")
	_sync_handler = handler

func retry_authentication() -> void:
	print("[AuthManager] Retrying authentication...")
	reset_flags()
	_start_auth_sequence()

func _start_auth_sequence() -> void:
	if _is_auth_flow_running:
		return
	_is_auth_flow_running = true

	if GameAnalysis:
		GameAnalysis.track_ftue_step("loading_auth")

	var attempts := 0
	while attempts < 30 and (not Firebase or not Firebase.get("Auth")):
		await get_tree().create_timer(0.1).timeout
		attempts += 1

	if not Firebase or not Firebase.get("Auth"):
		printerr("[AuthManager Error] Firebase.Auth unavailable after waiting.")
		_finish_auth_flow_offline()
		_is_auth_flow_running = false
		return

	_register_events()

	# 1. Editor mode bypass
	if OS.has_feature("editor"):
		print("[AuthManager] Editor detected: restoring shared editor account...")
		var shared_editor_auth = {
			"localid": "editor_shared_user",
			"providerid": "google.com",
			"email": "editor_shared@local.dev",
			"displayname": "Editor User",
			"idtoken": "editor_token",
			"refreshtoken": "editor_refresh_token"
		}
		_on_firebase_login_succeeded(shared_editor_auth)
		_is_auth_flow_running = false
		return

	# 2. Platform auto sign-in (Play Games on Android, Game Center on iOS)
	if OS.get_name() == "Android":
		is_pggs_checking = true
		print("[PlayGames] Checking auto authentication...")
		if _first_auth_attempt_done and _play_games_sign_in and _play_games_sign_in.has_method("sign_in"):
			_play_games_sign_in.sign_in()
		elif _play_games_sign_in:
			_play_games_sign_in.is_authenticated()
		var handshake_ok = await _await_signal_with_timeout(handshake_finished, 10.0)
		if handshake_ok and is_authenticated():
			_is_auth_flow_running = false
			return
		is_pggs_checking = false
	elif OS.get_name() == "iOS":
		print("[AuthManager] iOS detected. Checking Game Center authentication...")
		if GameCenterManager:
			GameCenterManager.authenticate()
			var handshake_ok = await _await_signal_with_timeout(handshake_finished, 10.0)
			if handshake_ok and is_authenticated():
				_is_auth_flow_running = false
				return

	# 3. Cached Session Check (fallback if native auto-auth fails)
	if FileAccess.file_exists("user://user.auth"):
		print("[AuthManager] Found cached auth file on disk. Restoring session...")
		is_firebase_logging_in = true
		if Firebase and Firebase.get("Auth") and Firebase.Auth.has_method("check_auth_file"):
			var ok = Firebase.Auth.check_auth_file()
			if not ok:
				print("[AuthManager] check_auth_file() returned false. Removing stale auth.")
				if Firebase.Auth.has_method("remove_auth"):
					Firebase.Auth.remove_auth()
				is_firebase_logging_in = false
			else:
				var handshake_ok = await _await_signal_with_timeout(handshake_finished, 10.0)
				if handshake_ok and is_authenticated():
					_is_auth_flow_running = false
					return
				is_firebase_logging_in = false

	_finish_auth_flow_offline()
	_is_auth_flow_running = false

func _finish_auth_flow_offline() -> void:
	_first_auth_attempt_done = true
	handshake_finished.emit()
	initial_sync_completed.emit(1.0)

func _get_web_client_id() -> String:
	var cid = Env.get_var("FIREBASE_WEB_CLIENT_ID")
	if not cid.is_empty() and not cid.begins_with("your_"):
		return cid
	var pg_cid = Env.get_var("PLAY_GAMES_WEB_CLIENT_ID")
	if not pg_cid.is_empty() and not pg_cid.begins_with("your_"):
		return pg_cid
	if ResourceLoader.exists("res://config/authsystem_config.tres"):
		var cfg = ResourceLoader.load("res://config/authsystem_config.tres")
		if cfg:
			var wcid = str(cfg.get("google_web_client_id"))
			if not wcid.is_empty():
				return wcid
	return ""

func _on_play_games_user_authenticated(authenticated: bool) -> void:
	print("[PlayGames] User authenticated callback: ", authenticated)
	is_pggs_checking = false
	if authenticated:
		if _play_games_players:
			_play_games_players.load_current_player(true)
		var web_client_id := _get_web_client_id()
		print("[PlayGames] Web Client ID resolved: ", web_client_id)
		if not web_client_id.is_empty():
			print("[PlayGames] Requesting server side access token...")
			_play_games_sign_in.request_server_side_access(web_client_id, false)
		else:
			printerr("[PlayGames Error] Web Client ID empty in Env!")
			handshake_finished.emit()
	else:
		print("[PlayGames] Auto authentication failed.")
		handshake_finished.emit()

func _on_play_games_current_player_loaded(player: PlayGamesPlayer) -> void:
	if player:
		print("[PlayGames] Current Player Loaded: Display Name = '", player.display_name, "', Player ID = '", player.player_id, "'")
		if not player.display_name.is_empty():
			_last_auth_display_name = player.display_name

func _on_play_games_server_side_access(token: String) -> void:
	print("[PlayGames] Server auth code received: ", token.left(15) if not token.is_empty() else "empty")
	if token.is_empty():
		_on_firebase_login_failed(0, "Empty Play Games Auth Code")
		return
	_last_auth_code = token
	if Firebase and Firebase.get("Auth"):
		print("[Firebase Auth] Logging in with Google Play auth code...")
		is_firebase_logging_in = true
		Firebase.Auth.login_with_google_play(token)

func _on_game_center_user_authenticated(authenticated: bool, data: Dictionary) -> void:
	print("[GameCenter] User authenticated callback: ", authenticated, " | Data: ", data)
	if authenticated and not data.is_empty():
		var alias: String = str(data.get("alias", data.get("displayName", "")))
		if not alias.is_empty():
			_last_auth_display_name = alias
		
		if is_firebase_logging_in:
			print("[AuthManager] Firebase login is already in progress. Ignoring duplicate Game Center callback.")
			return

		if is_authenticated():
			print("[AuthManager] User is already authenticated (%s). Skipping redundant Game Center login." % current_user_id)
			return

		if Firebase and Firebase.get("Auth"):
			print("[Firebase Auth] Logging in with Game Center account...")
			is_firebase_logging_in = true
			Firebase.Auth.login_with_game_center(data)
		else:
			printerr("[Firebase Auth Error] Firebase.Auth unavailable for Game Center login.")
			handshake_finished.emit()
	else:
		print("[GameCenter] Auto authentication failed or user cancelled.")
		handshake_finished.emit()

func _on_firebase_login_succeeded(auth_result: Dictionary) -> void:
	print("[Firebase Auth] login_succeeded callback payload: ", auth_result)
	var user_id := ""
	for key in ["localid", "localId", "userid", "user_id", "sub", "federatedid", "federatedId"]:
		if auth_result.has(key) and not str(auth_result[key]).is_empty():
			user_id = str(auth_result[key])
			break

	if user_id.is_empty() and Firebase and Firebase.get("Auth") and Firebase.Auth.auth:
		for key in ["localid", "localId", "userid", "user_id", "sub"]:
			if Firebase.Auth.auth.has(key) and not str(Firebase.Auth.auth[key]).is_empty():
				user_id = str(Firebase.Auth.auth[key])
				break

	print("[Firebase Auth] SUCCESS! User UID resolved: ", user_id)
	var stored_uid := str(_data_store.get("playerData", {}).get("userId", "")).strip_edges()
	var is_same := is_same_user(user_id)

	is_firebase_logging_in = false
	auth_error_state = false
	_link_retry_count = 0
	current_user_id = user_id

	var display_name := str(auth_result.get("displayname", auth_result.get("nickname", auth_result.get("display_name", ""))))
	if not display_name.is_empty():
		_last_auth_display_name = display_name

	var email := str(auth_result.get("email", ""))
	var photo_url := str(auth_result.get("photourl", auth_result.get("photo_url", "")))
	var provider_id := str(auth_result.get("providerid", auth_result.get("provider_id", auth_result.get("providerId", ""))))
	if provider_id.is_empty() and auth_result.has("provideruserinfo") and auth_result.provideruserinfo is Array and not auth_result.provideruserinfo.is_empty():
		provider_id = str(auth_result.provideruserinfo[0].get("providerId", auth_result.provideruserinfo[0].get("providerid", "")))
	if provider_id.is_empty() and OS.get_name() == "Android":
		provider_id = "playgames.google.com"
	elif provider_id.is_empty() and OS.get_name() == "iOS":
		provider_id = "gamecenter.apple.com"

	var is_account_switch := not stored_uid.is_empty() and stored_uid != user_id
	if is_account_switch:
		print("[AuthManager] USER CHANGED from '", stored_uid, "' to '", user_id, "'. Clearing local storage first...")
		_data_store.pendingWrites.clear()
		_data_store.hasUnsyncedChanges = false
		_last_synced_stats = {}
		_data_store.playerData = AuthData.user_data()
		_data_store.playerData.totalSessions = 1
		_data_store.playerData.totalScreenTimeSeconds = 0
		_session_start_ticks = Time.get_ticks_msec()
		if _sync_handler and _sync_handler.has_method("reset_all_local_data"):
			_sync_handler.reset_all_local_data()
		elif GameManager and GameManager.save_manager and GameManager.save_manager.has_method("initialize_default_data"):
			GameManager.save_manager.initialize_default_data()
			GameManager.save_manager.save_data()
		elif GameManager and GameManager.has_method("reset_all_local_data"):
			GameManager.reset_all_local_data()

	_data_store.playerData.userId = user_id
	_data_store.playerData.userName = _last_auth_display_name
	_data_store.playerData.email = email
	_data_store.playerData["photoUrl"] = photo_url
	_data_store.playerData["providerId"] = provider_id
	_save_data_store()

	if Firebase and Firebase.get("Firestore"):
		var token_val := ""
		for tk in ["idtoken", "idToken", "token", "id_token"]:
			if auth_result.has(tk) and not str(auth_result[tk]).is_empty():
				token_val = str(auth_result[tk])
				break
		if not token_val.is_empty():
			auth_result["idtoken"] = token_val
			auth_result["idToken"] = token_val

		Firebase.Firestore.auth = auth_result
		for child in Firebase.Firestore.get_children():
			if child is FirestoreCollection:
				child.auth = auth_result

	var user_doc_path := "users/%s" % user_id
	var user_profile := AuthData.user_profile_to_map(_last_auth_display_name, email, photo_url, OS.get_name())
	_data_store.pendingWrites = _data_store.pendingWrites.filter(
		func(w): return str(w.get("documentPath", "")) != user_doc_path
	)
	_data_store.pendingWrites.append(AuthData.pending_write(user_doc_path, user_profile))
	_data_store.hasUnsyncedChanges = true

	if Firebase and Firebase.get("Auth") and Firebase.Auth.has_method("save_auth"):
		Firebase.Auth.save_auth(auth_result)

	current_user_id = user_id

	# Distinguish guest vs. provider logins for anyone listening.
	if provider_id.is_empty() or provider_id.to_lower() == "anonymous":
		guest_login.emit(user_id)
	else:
		provider_login.emit(user_id, email)

	if EventBus and EventBus.has_signal("auth_user_logged_in"):
		EventBus.auth_user_logged_in.emit({
			"uid": user_id,
			"localid": user_id,
			"email": email,
			"name": _last_auth_display_name,
			"provider": provider_id if not provider_id.is_empty() else "anonymous"
		})

	GameManager.save_manager.set_user_data(_last_auth_display_name, user_id)
	_first_auth_attempt_done = true
	auth_state_changed.emit(true)
	handshake_finished.emit()

	fetch_remote_config()

	# If SAME USER and has pending offline writes or unsynced changes, push them before fetching remote
	if is_same and has_unsynced_data():
		print("[AuthManager] Unsynced offline data detected on startup for same user. Pushing to cloud before remote fetch...")
		queue_current_game_stats_snapshot()
		push_pending_local_data()
		await get_tree().create_timer(0.5).timeout

	initial_sync_completed.emit(0.5)
	await _fetch_remote_firestore_data()
	initial_sync_completed.emit(1.0)

func _on_firebase_login_failed(code: Variant, message: Variant) -> void:
	var msg_str := str(message)
	printerr("[Firebase Auth Error] Code: ", code, " | Message: ", msg_str)
	if _is_logout_or_delete_in_progress:
		return

	if msg_str == "FEDERATED_USER_ID_ALREADY_LINKED" or msg_str == "EMAIL_EXISTS":
		if _link_retry_count < MAX_LINK_RETRIES and OS.get_name() == "Android" and _play_games_sign_in:
			_link_retry_count += 1
			print("[Firebase Auth] Account linking conflict detected (attempt ", _link_retry_count, "/", MAX_LINK_RETRIES, "). Clearing stale auth and re-requesting server access code...")
			if Firebase and Firebase.get("Auth"):
				if Firebase.Auth.has_method("remove_auth"):
					Firebase.Auth.remove_auth()
				Firebase.Auth.auth = {}
			_delete_file("user://user.auth")
			_play_games_sign_in.request_server_side_access(_get_web_client_id(), false)
			return
		else:
			printerr("[Firebase Auth Error] Account linking conflict persisted after ", _link_retry_count, " attempt(s). Giving up.")

	is_firebase_logging_in = false
	is_pggs_checking = false
	auth_error_state = true
	_first_auth_attempt_done = true
	_link_retry_count = 0
	handshake_finished.emit()

	if EventBus and EventBus.has_signal("auth_failed"):
		EventBus.auth_failed.emit(int(code) if str(code).is_valid_int() else 0, msg_str)

	var friendly := _get_friendly_error_message(msg_str)
	auth_error.emit(friendly)
	initial_sync_completed.emit(1.0)

func _on_firebase_logged_out() -> void:
	print("[Firebase Auth] User logged out.")
	current_user_id = ""
	remote_config_data = {}
	_rc_installation_id = ""
	_rc_installation_token = ""
	_rc_installation_token_expires_unix = 0
	_is_fetching_remote_config = false
	_last_synced_stats = {}
	_data_store.hasUnsyncedChanges = false
	auth_state_changed.emit(false)
	if EventBus and EventBus.has_signal("auth_user_logged_out"):
		EventBus.auth_user_logged_out.emit()

func _on_firebase_token_refresh_succeeded(_auth_result: Dictionary) -> void:
	print("[Firebase Auth] Token refresh succeeded. Refreshing Remote Config parameters...")
	fetch_remote_config()

var _rc_controller: RemoteConfigController = null
var _rc_installation_id: String = ""
var _rc_installation_token: String = ""
var _rc_installation_token_expires_unix: int = 0
var _is_fetching_remote_config: bool = false
var _last_synced_stats: Dictionary = {}

func _get_remote_config_controller() -> RemoteConfigController:
	if _rc_controller != null:
		return _rc_controller

	var project_id := Env.get_var("FIREBASE_PROJECT_ID")
	var api_key := Env.get_var("FIREBASE_API_KEY")
	var app_id := Env.get_var("FIREBASE_APP_ID")

	if (project_id.is_empty() or api_key.is_empty() or app_id.is_empty()) and ResourceLoader.exists("res://config/authsystem_config.tres"):
		var cfg = ResourceLoader.load("res://config/authsystem_config.tres")
		if cfg:
			if project_id.is_empty(): project_id = str(cfg.get("firebase_project_id"))
			if api_key.is_empty(): api_key = str(cfg.get("firebase_api_key"))
			if app_id.is_empty(): app_id = str(cfg.get("firebase_app_id"))

	if project_id.is_empty() or api_key.is_empty() or app_id.is_empty():
		printerr("[RemoteConfig Error] Missing FIREBASE_PROJECT_ID / FIREBASE_API_KEY / FIREBASE_APP_ID in .env or authsystem_config.tres.")
		return null

	_rc_controller = RemoteConfigController.new(project_id, api_key, app_id, self)
	
	return _rc_controller

func fetch_remote_config(force_refresh: bool = false) -> void:
	if _is_fetching_remote_config:
		print("[RemoteConfig] Fetch already in progress. Skipping duplicate call.")
		return

	var cached := _load_remote_config_cache()
	var now := int(Time.get_unix_time_from_system())
	var last_fetch := int(cached.get("last_fetch_unix", 0))
	var cached_entries: Dictionary = cached.get("entries", {})

	if not force_refresh and not cached_entries.is_empty() and last_fetch > 0 and (now - last_fetch) < REMOTE_CONFIG_CACHE_TTL_SECONDS:
		var elapsed := now - last_fetch
		print("[RemoteConfig] Local cache is fresh (fetched %d seconds ago, < 1 hour). Using cached values." % elapsed)
		_on_remote_config_fetch_succeeded(cached_entries)
		return

	_is_fetching_remote_config = true

	var controller := _get_remote_config_controller()
	if not controller:
		var err_msg := "RemoteConfig REST client unavailable (missing Firebase .env / auth config values)."
		_remote_config.fetch_failed.emit({"error": err_msg})
		remote_config_error.emit(err_msg)
		_is_fetching_remote_config = false
		if not cached_entries.is_empty():
			print("[RemoteConfig] Falling back to local cached remote config.")
			_on_remote_config_fetch_succeeded(cached_entries)
		return

	# Reuse the cached installation until its auth token expires.
	if _rc_installation_id.is_empty() or _rc_installation_token.is_empty() or now >= _rc_installation_token_expires_unix:
		print("[RemoteConfig] Creating Firebase Installation...")
		var install_result: Dictionary = await controller.create_installation()
		if not install_result.get("ok", false):
			var msg := "Failed to create Firebase Installation: %s" % str(install_result.get("error", "unknown"))
			printerr("[RemoteConfig Error] ", msg)
			remote_config_error.emit(msg)
			_is_fetching_remote_config = false
			if not cached_entries.is_empty():
				print("[RemoteConfig] Falling back to local cached remote config.")
				_on_remote_config_fetch_succeeded(cached_entries)
			return
		_rc_installation_id = install_result.fid
		_rc_installation_token = install_result.auth_token
		_rc_installation_token_expires_unix = install_result.token_expires_unix
		print("[RemoteConfig] Installation ready: ", _rc_installation_id)

	print("[RemoteConfig] Fetching config from Firebase (last fetch was > 1 hour ago or cache was empty)...")
	var fetch_result: Dictionary = await controller.fetch_config(_rc_installation_id, _rc_installation_token)
	_is_fetching_remote_config = false
	if not fetch_result.get("ok", false):
		var msg := "Remote config fetch failed: %s" % str(fetch_result.get("error", "unknown"))
		printerr("[RemoteConfig Error] ", msg)
		_remote_config.fetch_failed.emit({"error": msg})
		remote_config_error.emit(msg)
		if not cached_entries.is_empty():
			print("[RemoteConfig] Falling back to local cached remote config.")
			_on_remote_config_fetch_succeeded(cached_entries)
		return

	_save_remote_config_cache(fetch_result.entries, now)
	_on_remote_config_fetch_succeeded(fetch_result.entries)

func _on_remote_config_fetch_succeeded(entries: Dictionary) -> void:
	print("[RemoteConfig] Remote config activated.")
	remote_config_data = entries
	_print_remote_config(entries)
	_remote_config.config_activated.emit(remote_config_data)
	remote_config_received.emit(remote_config_data)

func _print_remote_config(raw: Dictionary) -> void:
	for key in raw.keys():
		print("  ", key, " = ", raw[key])

# Helper Utilities
func _get_friendly_error_message(msg: String) -> String:
	if msg.is_empty():
		return "An unexpected authentication error occurred."
	var upper = msg.to_upper()
	if upper.contains("INVALID_ID_TOKEN") or upper.contains("INVALID_TOKEN"):
		return "Invalid session token. Please sign in again."
	elif upper.contains("TOKEN_EXPIRED"):
		return "Your session has expired. Please sign in again."
	elif upper.contains("REQUIRES_RECENT_LOGIN") or upper.contains("CREDENTIAL_TOO_OLD"):
		return "For security reasons, please log in again before deleting your account."
	return msg

func _await_signal_with_timeout(sig: Signal, timeout: float) -> bool:
	var timer = Timer.new()
	timer.wait_time = timeout
	timer.one_shot = true
	add_child(timer)

	var completed = [false]
	var timed_out = [false]
	var on_signal = func(_a = null, _b = null, _c = null): completed[0] = true
	var on_timeout = func():
		timed_out[0] = true
		completed[0] = true

	sig.connect(on_signal, CONNECT_ONE_SHOT)
	timer.timeout.connect(on_timeout, CONNECT_ONE_SHOT)
	timer.start()

	var current_session = auth_session_id
	while not completed[0]:
		await get_tree().process_frame
		if auth_session_id != current_session:
			break

	if is_instance_valid(timer):
		timer.stop()
		timer.queue_free()
	return completed[0] and not timed_out[0] and auth_session_id == current_session

# Public Sign-In API Methods
func start_guest(user_name: String) -> void:
	print("[Firebase Auth] Starting Guest Login for: ", user_name)
	if Firebase and Firebase.get("Auth"):
		is_firebase_logging_in = true
		Firebase.Auth.login_anonymous()
		_data_store.playerData.userName = user_name

func StartGuest(user_name: String) -> void:
	start_guest(user_name)

func sign_in_with_playgames() -> void:
	print("[PlayGames] Explicit sign_in() invoked.")
	if OS.get_name() == "Android":
		is_pggs_checking = true
		_play_games_sign_in.sign_in()
	else:
		print("[PlayGames] Platform is not Android. Skipping sign_in().")

func SignInWithPlayGames() -> void:
	sign_in_with_playgames()

func sign_in_with_google() -> void:
	sign_in_with_playgames()

func SignInWithGoogle() -> void:
	sign_in_with_google()

func sign_in_with_google_id_token(google_id_token: String) -> void:
	print("[Firebase Auth] Signing in with Google ID token...")
	if Firebase and Firebase.get("Auth"):
		is_firebase_logging_in = true
		Firebase.Auth.login_with_custom_token(google_id_token)

func SignInWithGoogleIdToken(google_id_token: String) -> void:
	sign_in_with_google_id_token(google_id_token)

func sign_in_with_game_center() -> void:
	print("[GameCenter] Explicit sign_in() invoked.")
	if OS.get_name() == "iOS" and GameCenterManager:
		GameCenterManager.authenticate()
	else:
		print("[GameCenter] Platform is not iOS or GameCenterManager missing. Skipping.")

func SignInWithGameCenter() -> void:
	sign_in_with_game_center()

func signed_out() -> void:
	print("[AuthManager] Signed out requested.")
	_is_logout_or_delete_in_progress = true
	if Firebase and Firebase.get("Auth"):
		if Firebase.Auth.has_method("remove_auth"):
			Firebase.Auth.remove_auth()
		Firebase.Auth.logout()
	elif FileAccess.file_exists("user://user.auth"):
		DirAccess.remove_absolute("user://user.auth")

	if GameCenterManager and GameCenterManager.has_method("clear_cache"):
		GameCenterManager.clear_cache()

	current_user_id = ""
	reset_flags()
	if _sync_handler != null and _sync_handler.has_method("reset_all_local_data"):
		_sync_handler.reset_all_local_data()
	elif GameManager and GameManager.save_manager and GameManager.save_manager.has_method("initialize_default_data"):
		GameManager.save_manager.initialize_default_data()
		GameManager.save_manager.save_data()
	elif GameManager and GameManager.has_method("reset_all_local_data"):
		GameManager.reset_all_local_data()
	auth_state_changed.emit(false)
	_is_logout_or_delete_in_progress = false

func SignedOut() -> void:
	signed_out()

func get_user_id() -> String:
	if not current_user_id.is_empty():
		return current_user_id
	var stored_uid := str(_data_store.get("playerData", {}).get("userId", "")).strip_edges()
	if not stored_uid.is_empty() and stored_uid != "null":
		return stored_uid
	if Firebase and Firebase.get("Auth") and Firebase.Auth.auth is Dictionary:
		for k in ["localid", "localId", "userid", "user_id", "sub"]:
			if Firebase.Auth.auth.has(k) and not str(Firebase.Auth.auth[k]).is_empty():
				return str(Firebase.Auth.auth[k])
	return ""

func delete_user_account() -> void:
	print("[AuthManager] Delete account / erase data requested.")
	_is_logout_or_delete_in_progress = true
	var user_id := get_user_id()
	var game_id := _get_game_id()
	var _name=GameManager.save_manager.game_data["player_data"]["name"]
	var id=GameManager.save_manager.game_data["player_data"]["user_id"]

	# 1. Delete Firestore game document (erases cloud stats, levels, coins)
	if Firebase and Firebase.get("Firestore") and not user_id.is_empty():
		print("[AuthManager] Deleting Firestore game doc: users/%s/games/%s" % [user_id, game_id])
		var games_coll = Firebase.Firestore.collection("users/" + user_id + "/games")
		if Firebase.get("Auth") and Firebase.Auth.auth is Dictionary:
			games_coll.auth = Firebase.Auth.auth
		if games_coll and games_coll.has_method("delete_doc"):
			games_coll.delete_doc(game_id)
			await get_tree().create_timer(1.0).timeout

	# 2. Reset all local data to default
	_data_store.pendingWrites.clear()
	_data_store.hasUnsyncedChanges = false
	_last_synced_stats = {}
	_data_store.playerData.totalSessions = 1
	_data_store.playerData.totalScreenTimeSeconds = 0
	_session_start_ticks = Time.get_ticks_msec()
	_save_data_store()

	if GameManager and GameManager.has_method("reset_all_local_data"):
		GameManager.reset_all_local_data()
		GameManager.save_manager.set_user_data(_name,id)
	

	_is_logout_or_delete_in_progress = false
	print("[AuthManager] Game data document successfully erased from cloud and local reset to default.")
	
	if GameAnalysis and GameAnalysis.has_method("track_settings_click"):
		GameAnalysis.track_settings_click("DeleteAccount", "Success")
	
	delete_complete.emit()

func DeleteUserAccount() -> void:
	delete_user_account()

func _get_current_local_stats() -> Dictionary:
	var stats: Dictionary = {}
	if _sync_handler and _sync_handler.has_method("get_local_progress_for_migration"):
		var progress: Dictionary = _sync_handler.get_local_progress_for_migration()
		stats = progress.get("stats", {})
	elif GameManager and GameManager.save_manager:
		stats = GameManager.save_manager.game_data
	elif GameManager and GameManager.get("game_data"):
		stats = GameManager.game_data
	if not stats.is_empty():
		return AuthData.normalize_game_stats(stats)
	return {}

func is_same_user(target_user_id: String) -> bool:
	if target_user_id.is_empty():
		return false
	var stored_uid := str(_data_store.get("playerData", {}).get("userId", "")).strip_edges()
	if stored_uid.is_empty() or stored_uid == "null":
		return false
	return stored_uid == target_user_id

func has_unsynced_data() -> bool:
	if _data_store.get("hasUnsyncedChanges", false) or not _data_store.get("pendingWrites", []).is_empty():
		return true
	var current_stats := _get_current_local_stats()
	if not current_stats.is_empty() and current_stats != _last_synced_stats:
		return true
	return false

func _get_game_id() -> String:
	return "com.TheGameWise.ZeroAimZone"

func push_pending_local_data() -> void:
	if not is_firestore_data_fetched:
		print("[Firestore Sync] Initial sync is not complete. Skipping Firebase write.")
		return

	if _data_store.pendingWrites.is_empty():
		return

	if not Firebase or not Firebase.get("Firestore"):
		return

	var auth_dict: Dictionary = {}
	if Firebase.get("Auth") and Firebase.Auth.auth is Dictionary and not Firebase.Auth.auth.is_empty():
		auth_dict = Firebase.Auth.auth
	elif typeof(Firebase.Firestore.auth) == TYPE_DICTIONARY and not Firebase.Firestore.auth.is_empty():
		auth_dict = Firebase.Firestore.auth

	if not auth_dict.is_empty():
		var id_tok := ""
		for tk in ["idtoken", "idToken", "token", "id_token"]:
			if auth_dict.has(tk) and not str(auth_dict[tk]).is_empty():
				id_tok = str(auth_dict[tk])
				break
		if not id_tok.is_empty():
			auth_dict["idtoken"] = id_tok
			auth_dict["idToken"] = id_tok

	for write in _data_store.pendingWrites.duplicate(true):
		var doc_path: String = str(write.get("documentPath", ""))
		var data: Dictionary = write.get("data", {})
		if doc_path.is_empty() or data.is_empty():
			_data_store.pendingWrites.erase(write)
			continue

		var collection_path: String = doc_path.get_base_dir()
		var doc_name: String = doc_path.get_file()
		var collection = Firebase.Firestore.collection(collection_path)
		if not auth_dict.is_empty():
			collection.auth = auth_dict

		print("[AuthManager] Pushing pending offline write to path: ", doc_path)
		collection.set_doc(doc_name, data)
		_data_store.pendingWrites.erase(write)

	_data_store.hasUnsyncedChanges = not _data_store.pendingWrites.is_empty()
	_data_store.lastSyncTicks = Time.get_ticks_msec()
	_last_synced_stats = _get_current_local_stats().duplicate(true)
	_save_data_store()

func queue_current_game_stats_snapshot() -> void:
	if not is_firestore_data_fetched:
		print("[Firestore Sync] Initial sync is not complete. Skipping cloud snapshot queue.")
		return

	var stats := _get_current_local_stats()
	if stats.is_empty():
		return

	var user_id := current_user_id
	if user_id.is_empty():
		user_id = str(_data_store.get("playerData", {}).get("userId", "")).strip_edges()

	if user_id.is_empty():
		print("[Firestore Sync] User not logged in. Skipping cloud queue.")
		return

	var game_id := _get_game_id()
	var doc_path := "users/%s/games/%s" % [user_id, game_id]

	var dt_utc := Time.get_datetime_dict_from_system(true)
	var date_str := "%02d-%02d-%04d" % [dt_utc.day, dt_utc.month, dt_utc.year]
	var current_session_seconds := int((Time.get_ticks_msec() - _session_start_ticks) / 1000.0)
	var total_screen_time := int(_data_store.playerData.get("totalScreenTimeSeconds", 0)) + current_session_seconds
	var total_sessions = max(1, int(_data_store.playerData.get("totalSessions", 1)))

	var payload := {
		"lastSessionDateUTC": date_str,
		"screenTime": total_screen_time,
		"session": total_sessions,
		"sessionDeltaCount": 0,
		"sessionDeltaSeconds": current_session_seconds,
		"stats": stats,
		"updatedAt": Time.get_datetime_string_from_system(true)
	}

	_data_store.pendingWrites = _data_store.pendingWrites.filter(
		func(w): return str(w.get("documentPath", "")) != doc_path
	)
	_data_store.pendingWrites.append(AuthData.pending_write(doc_path, payload))
	_data_store.hasUnsyncedChanges = true
	_save_data_store()

func sync_save_to_firestore() -> void:
	if not is_firestore_data_fetched:
		print("[Firestore Sync] Initial sync is not complete. Skipping Firestore sync.")
		return
	queue_current_game_stats_snapshot()


func erase_local_data() -> void:
	_data_store.pendingWrites.clear()
	_data_store.hasUnsyncedChanges = false
	_data_store.playerData = AuthData.user_data()
	if _sync_handler != null and _sync_handler.has_method("reset_all_local_data"):
		_sync_handler.reset_all_local_data()
	elif GameManager and GameManager.save_manager and GameManager.save_manager.has_method("initialize_default_data"):
		GameManager.save_manager.initialize_default_data()
		GameManager.save_manager.save_data()
	elif GameManager and GameManager.has_method("reset_all_local_data"):
		GameManager.reset_all_local_data()
	_delete_file(DATA_PATH)
	_delete_file("user://user.auth")

func _fetch_remote_firestore_data() -> void:
	var user_id = current_user_id
	if user_id.is_empty():
		print("[Firestore Fetch] No user ID. Skipping fetch.")
		return
	if not Firebase or not Firebase.get("Firestore"):
		printerr("[Firestore Fetch Error] Firebase.Firestore not available!")
		return

	var game_id := _get_game_id()
	print("[Firestore Fetch] Fetching document for path: users/%s/games/%s" % [user_id, game_id])

	var auth_dict: Dictionary = {}
	if Firebase.get("Auth") and Firebase.Auth.auth is Dictionary and not Firebase.Auth.auth.is_empty():
		auth_dict = Firebase.Auth.auth
	elif typeof(Firebase.Firestore.auth) == TYPE_DICTIONARY and not Firebase.Firestore.auth.is_empty():
		auth_dict = Firebase.Firestore.auth

	if not auth_dict.is_empty():
		var id_tok := ""
		for tk in ["idtoken", "idToken", "token", "id_token"]:
			if auth_dict.has(tk) and not str(auth_dict[tk]).is_empty():
				id_tok = str(auth_dict[tk])
				break
		if not id_tok.is_empty():
			auth_dict["idtoken"] = id_tok
			auth_dict["idToken"] = id_tok

	var games_collection = Firebase.Firestore.collection("users/" + user_id + "/games")
	if not auth_dict.is_empty():
		games_collection.auth = auth_dict

	var doc = await games_collection.get_doc(game_id)
	if not doc or not (doc is FirestoreDocument):
		var alt_game_id := game_id.to_lower()
		if alt_game_id != game_id:
			print("[Firestore Fetch] Exact game_id '%s' doc not found. Retrying with '%s'..." % [game_id, alt_game_id])
			doc = await games_collection.get_doc(alt_game_id)

	if doc and doc is FirestoreDocument:
		var remote_stats = doc.get_value("stats")
		if typeof(remote_stats) != TYPE_DICTIONARY or remote_stats.is_empty():
			remote_stats = doc.get_value("gameStats")

		var remote_screen_time = doc.get_value("screenTime")
		if typeof(remote_screen_time) in [TYPE_INT, TYPE_FLOAT] and remote_screen_time > 0:
			_data_store.playerData.totalScreenTimeSeconds = max(int(_data_store.playerData.get("totalScreenTimeSeconds", 0)), int(remote_screen_time))

		var remote_sessions = doc.get_value("session")
		if typeof(remote_sessions) in [TYPE_INT, TYPE_FLOAT] and remote_sessions > 0:
			_data_store.playerData.totalSessions = max(int(_data_store.playerData.get("totalSessions", 0)), int(remote_sessions))

		var remote_last_date = doc.get_value("lastSessionDateUTC")
		if typeof(remote_last_date) == TYPE_STRING and not remote_last_date.is_empty():
			_data_store.playerData.lastSessionDateUTC = str(remote_last_date)

		if typeof(remote_stats) == TYPE_DICTIONARY and not remote_stats.is_empty():
			print("[Firestore Fetch] Remote stats found. Applying to local save...")
			var normalized_remote := AuthData.normalize_game_stats(remote_stats)
			_last_synced_stats = normalized_remote.duplicate(true)
			is_firestore_data_fetched = true
			if _sync_handler and _sync_handler.has_method("apply_remote_stats"):
				await _sync_handler.apply_remote_stats(normalized_remote)
			elif GameManager and GameManager.save_manager:
				GameManager.save_manager.apply_remote_game_data(normalized_remote)
			elif GameManager and GameManager.has_method("apply_remote_stats"):
				GameManager.apply_remote_stats(normalized_remote)
		else:
			print("[Firestore Fetch] Document retrieved but stats is empty (new user). Seeding initial cloud save from local progress.")
			_last_synced_stats = _get_current_local_stats().duplicate(true)
			is_firestore_data_fetched = true
			queue_current_game_stats_snapshot()
			push_pending_local_data()

	else:
		print("[Firestore Fetch] Document null or not found for path: users/%s/games/%s. Seeding initial cloud save from local progress." % [user_id, game_id])
		_last_synced_stats = _get_current_local_stats().duplicate(true)
		is_firestore_data_fetched = true
		queue_current_game_stats_snapshot()
		push_pending_local_data()

	_data_store.hasUnsyncedChanges = not _data_store.pendingWrites.is_empty()
	is_firestore_data_fetched = true
	push_pending_local_data()
	_save_data_store()

func QueueCurrentGameStatsSnapshot() -> void:
	queue_current_game_stats_snapshot()

func EraseLocalData() -> void:
	erase_local_data()

func set_score_data(score: String) -> void:
	if score.is_valid_int():
		var val := int(score)
		if _data_store.playerData.gameStats.has("player_data") and _data_store.playerData.gameStats.player_data is Dictionary:
			_data_store.playerData.gameStats.player_data["total_score"] = val
		_data_store.playerData.gameStats["totalScore"] = val




func set_remove_ads() -> void:
	if GameManager and GameManager.save_manager:
		GameManager.save_manager.save_game_data("player_data", "remove_ads", true)
	if _data_store.playerData.gameStats.has("player_data") and _data_store.playerData.gameStats.player_data is Dictionary:
		_data_store.playerData.gameStats.player_data["remove_ads"] = true
	sync_save_to_firestore()
	push_pending_local_data()

# Public utility for callers (e.g. custom backend requests) that need the raw
# Firebase ID token directly.
func _get_firebase_id_token() -> String:
	if Firebase and Firebase.get("Auth") and Firebase.Auth.auth is Dictionary:
		for k in ["idtoken", "id_token", "token", "idToken"]:
			if Firebase.Auth.auth.has(k) and not str(Firebase.Auth.auth[k]).is_empty():
				return str(Firebase.Auth.auth[k])
	return ""

func _on_internet_state_changed(online: bool) -> void:
	if EventBus and EventBus.has_signal("network_connectivity_changed"):
		EventBus.network_connectivity_changed.emit(online)

	if online and has_unsynced_data():
		if OS.get_name() in ["Android", "iOS"] and is_firestore_data_fetched and is_authenticated():
			var current_stats := _get_current_local_stats()
			if not current_stats.is_empty() and current_stats != _last_synced_stats:
				print("[AuthManager] Internet connection restored with unsynced stats. Queuing snapshot...")
				queue_current_game_stats_snapshot()
			if not _data_store.pendingWrites.is_empty():
				print("[AuthManager] Internet connection restored. Pushing pending writes to cloud...")
				push_pending_local_data()

func sync_via_foreground_process() -> bool:
	var os_name := OS.get_name()
	if os_name == "Android":
		if not FirebaseSyncAndroid.is_available():
			return false
	elif os_name == "iOS":
		if not FirebaseSyncIOSClient.is_available():
			return false
	else:
		return false

	if not has_unsynced_data():
		print("[FirebaseSync] No unsynced changes. Skipping foreground sync.")
		return false

	var user_id := get_user_id()
	if user_id.is_empty():
		return false

	if not Firebase or not Firebase.get("Firestore"):
		return false

	# 1. Get Auth ID Token
	var id_token := _get_firebase_id_token()
	if id_token.is_empty():
		return false

	# 2. Build Firestore REST API URL and Document Path
	var project_id: String = str(Firebase.Firestore._config.get("projectId", ""))
	if project_id.is_empty():
		return false
	var base_url := "https://firestore.googleapis.com/v1/projects/%s/databases/(default)/documents" % project_id
	var game_id := _get_game_id()
	var doc_path := "users/%s/games/%s" % [user_id, game_id]

	# 3. Create Latest Snapshot Payload
	var stats := _get_current_local_stats()
	var dt_utc := Time.get_datetime_dict_from_system(true)
	var date_str := "%02d-%02d-%04d" % [dt_utc.day, dt_utc.month, dt_utc.year]
	var current_session_seconds := int((Time.get_ticks_msec() - _session_start_ticks) / 1000.0)
	var total_screen_time := int(_data_store.playerData.get("totalScreenTimeSeconds", 0)) + current_session_seconds
	var total_sessions = max(1, int(_data_store.playerData.get("totalSessions", 1)))

	var payload := {
		"lastSessionDateUTC": date_str,
		"screenTime": total_screen_time,
		"session": total_sessions,
		"sessionDeltaCount": 0,
		"sessionDeltaSeconds": current_session_seconds,
		"stats": stats,
		"updatedAt": Time.get_datetime_string_from_system(true)
	}

	# 4. Format Body as Firestore Fields
	var body := JSON.stringify(Utilities.dict2fields(payload))

	# 5. Launch Native Foreground/Background Sync based on OS
	if os_name == "Android":
		print("[FirebaseSync Android] Dispatching foreground sync for: ", doc_path)
		FirebaseSyncAndroid.start_sync(
			base_url,
			id_token,
			doc_path,
			body
		)
	elif os_name == "iOS":
		print("[FirebaseSync iOS] Dispatching native sync for: ", doc_path)
		FirebaseSyncIOSClient.start_sync(
			base_url,
			id_token,
			doc_path,
			body
		)

	_last_synced_stats = stats.duplicate(true)
	_data_store.pendingWrites.clear()
	_data_store.hasUnsyncedChanges = false
	_save_data_store()
	return true

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED \
	or what == NOTIFICATION_APPLICATION_FOCUS_OUT \
	or what == NOTIFICATION_WM_WINDOW_FOCUS_OUT \
	or what == NOTIFICATION_WM_CLOSE_REQUEST \
	or what == NOTIFICATION_PREDELETE:
		_flush_session_time_to_store()
		_save_data_store()

		var has_unsynced := has_unsynced_data()
		print("[AuthManager] LifeCycle Notification: %d. Has unsynced changes: %s" % [what, str(has_unsynced)])

		if not has_unsynced:
			return

		if OS.get_name() in ["Android", "iOS"] and is_firestore_data_fetched and is_authenticated():
			if sync_via_foreground_process():
				print("[AuthManager] Foreground sync dispatched on app pause/exit.")
				return

			if Firebase and Firebase.get("Firestore"):
				push_pending_local_data()
		else:
			push_pending_local_data()
