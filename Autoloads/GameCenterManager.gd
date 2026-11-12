extends Node


## GameCenterManager
## Handles iOS Game Center integration.

signal user_authenticated(is_authenticated: bool, data: Dictionary)
signal auth_signature_received(signature_data: Dictionary)

var game_center: Object = null
var cached_alias: String = ""
var cached_display_name: String = ""
var cached_auth_data: Dictionary = {}

func _ready() -> void:
	if OS.get_name() == "iOS":
		_initialize_game_center()
		set_process(true)
	else:
		print("[GameCenterManager] Non-iOS platform detected. Game Center will be disabled.")
		set_process(false)

func _initialize_game_center() -> void:
	if Engine.has_singleton("GameCenter"):
		game_center = Engine.get_singleton("GameCenter")
		print("[GameCenterManager] GameCenter singleton found and initialized for polling.")
	else:
		printerr("[GameCenterManager] GameCenter singleton NOT found. Is the plugin enabled in export presets?")

func _process(_delta: float) -> void:
	if game_center and game_center.has_method("get_pending_event_count"):
		while game_center.get_pending_event_count() > 0:
			var event = game_center.pop_pending_event()
			if event:
				_handle_event(event)

func _handle_event(event: Dictionary) -> void:
	print("[GameCenterManager] Received event: ", event)
	var type = event.get("type", "")
	
	match type:
		"authentication":
			var result = event.get("result", "")
			if result == "ok":
				var new_alias = str(event.get("alias", ""))
				var new_display = str(event.get("displayName", ""))
				var canonical_id = get_canonical_id(event, game_center)
				event["player_id"] = canonical_id
				
				var old_canonical = str(cached_auth_data.get("player_id", ""))
				var is_duplicate = (not cached_auth_data.is_empty()) and (canonical_id == old_canonical) and (new_alias == cached_alias)
				
				cached_alias = new_alias
				cached_display_name = new_display
				cached_auth_data = event.duplicate(true)
				
				if not is_duplicate:
					_on_authentication_success(event)
				else:
					print("[GameCenterManager] Duplicate authentication event ignored.")
			else:
				_on_authentication_failure()
		"identity_verification_signature":
			var result = event.get("result", "")
			if result == "success" or result == "ok":
				_on_signature_success(event)
			else:
				var error_msg = event.get("error_description", event.get("error", "Unknown signature error"))
				_on_signature_failure(error_msg)

## Triggers the manual Game Center authentication UI.
func authenticate() -> void:
	if game_center:
		if is_authenticated() and not cached_auth_data.is_empty():
			print("[GameCenterManager] Already authenticated with cached auth data. Signaling success immediately.")
			user_authenticated.emit(true, cached_auth_data)
			return
			
		# Trigger authentication to ensure we get the latest player data/alias via events
		print("[GameCenterManager] Requesting Game Center authentication...")
		var result = game_center.authenticate()
		print("[GameCenterManager] Plugin authenticate() call result: ", result)
		
		if result != OK:
			printerr("[GameCenterManager] Plugin returned immediate error %s. Signaling failure." % str(result))
			user_authenticated.emit(false, {})
	else:
		print("[GameCenterManager] GameCenter singleton not present.")
		user_authenticated.emit(false, {})

## Checks if the user is currently authenticated.
func is_authenticated() -> bool:
	if game_center:
		return game_center.is_authenticated()
	return false

## Canonical sticky ID resolver for Apple Game Center IDs
static func get_canonical_id(data: Dictionary, gc_singleton: Object = null) -> String:
	# 1. Collect all non-empty raw candidate IDs (matching Thinkfinity canonical order)
	var raw_candidates: Array[String] = []
	for k in ["player_id", "playerId", "game_player_id", "team_player_id"]:
		if data.has(k) and not str(data[k]).strip_edges().is_empty():
			raw_candidates.append(str(data[k]))
	
	if gc_singleton and gc_singleton.has_method("get_local_player_id"):
		var local_id = str(gc_singleton.get_local_player_id()).strip_edges()
		if not local_id.is_empty() and not raw_candidates.has(local_id):
			raw_candidates.append(local_id)

	# 2. Clean and sanitize candidates
	var clean_candidates: Array[String] = []
	for raw in raw_candidates:
		var cleaned = raw
		if cleaned.contains(":"):
			cleaned = cleaned.split(":")[1]
		cleaned = cleaned.strip_edges().to_lower()
		if not cleaned.is_empty() and not clean_candidates.has(cleaned):
			clean_candidates.append(cleaned)

	if clean_candidates.is_empty():
		return ""

	# 3. Check persistent storage for an already bound ID
	var bound_id := ""
	if Engine.get_main_loop() and Engine.get_main_loop().root:
		var pp = Engine.get_main_loop().root.get_node_or_null("PlayerPrefs")
		if pp and pp.has_method("get_string"):
			bound_id = pp.get_string("bound_gc_id", "").strip_edges().to_lower()

	if bound_id.is_empty() and FileAccess.file_exists("user://bound_gc_id.txt"):
		var f = FileAccess.open("user://bound_gc_id.txt", FileAccess.READ)
		if f:
			bound_id = f.get_as_text().strip_edges().to_lower()

	# If we have a bound ID and candidates are valid, lock to the bound ID permanently!
	if not bound_id.is_empty():
		return bound_id

	# 4. If no bound ID yet, pick the best candidate (deterministic preferred order: team -> game -> player)
	var chosen_id: String = clean_candidates[0]

	# 5. Persist the chosen ID permanently
	if Engine.get_main_loop() and Engine.get_main_loop().root:
		var pp = Engine.get_main_loop().root.get_node_or_null("PlayerPrefs")
		if pp and pp.has_method("set_string"):
			pp.set_string("bound_gc_id", chosen_id)

	var f_out = FileAccess.open("user://bound_gc_id.txt", FileAccess.WRITE)
	if f_out:
		f_out.store_string(chosen_id)

	print("[GameCenterManager] Bound and locked canonical Game Center ID: ", chosen_id)
	return chosen_id

func clear_cache() -> void:
	cached_alias = ""
	cached_display_name = ""
	cached_auth_data.clear()
	print("[GameCenterManager] Cached authentication data cleared.")

## Triggers fetching the authentication signature (for Firebase verification)
func fetch_signature() -> void:
	if game_center and game_center.has_method("request_identity_verification_signature"):
		print("[GameCenterManager] Requesting identity verification signature...")
		game_center.request_identity_verification_signature()
	else:
		printerr("[GameCenterManager] Cannot fetch signature: Method missing.")
		auth_signature_received.emit({})

# --- Internal Signal Handlers (Triggered by Events) ---

func _on_authentication_success(event: Dictionary) -> void:
	print("[GameCenterManager] Authentication Success Event!")
	user_authenticated.emit(true, event)

func _on_authentication_failure() -> void:
	print("[GameCenterManager] Authentication Failure Event.")
	user_authenticated.emit(false, {})

func _on_signature_success(event: Dictionary) -> void:
	print("[GameCenterManager] Signature Success Event!")
	
	var public_key_url = event.get("public_key_url", "")
	var signature = event.get("signature", "")
	var salt = event.get("salt", "")
	var timestamp = event.get("timestamp", 0)
	
	var player_id = get_canonical_id(event, game_center)
	print("[GameCenterManager] Resolved Canonical Player ID: ", player_id)

	var data = {
		"player_id": player_id,
		"team_player_id": event.get("team_player_id", ""), 
		"game_player_id": event.get("game_player_id", ""), 
		"public_key_url": public_key_url,
		"signature": signature,
		"salt": salt,
		"timestamp": timestamp
	}
	
	auth_signature_received.emit(data)

func _on_signature_failure(error: String) -> void:
	printerr("[GameCenterManager] Signature Failure Event: ", error)
	auth_signature_received.emit({})

# --- Score Reporting (Future Proofing) ---

func report_score(leaderboard_id: String, score: int) -> void:
	if game_center and is_authenticated():
		print("[GameCenterManager] Reporting score %d to leaderboard: %s" % [score, leaderboard_id])
		game_center.post_score(leaderboard_id, score)
	else:
		print("[GameCenterManager] Cannot report score: Not authenticated or plugin missing.")

func test_show_ui() -> void:
	if game_center and game_center.has_method("show_game_center"):
		print("[GameCenterManager] Testing Game Center UI visibility...")
		game_center.show_game_center({"view": "default"})
	else:
		print("[GameCenterManager] show_game_center method not found.")

func show_game_center_leaderboard() -> void:
	pass
