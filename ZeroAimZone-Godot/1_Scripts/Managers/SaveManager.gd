class_name SaveManager
extends Node


var file_name := "gamedata.dat"
var file_path := ""
var game_data := {
	
}

const DAILY_REWARDS_CATEGORY := "daily_rewards"
const DAILY_REWARD_CURRENT_DAY := "current_day"
const DAILY_REWARD_LAST_CLAIMED_DATE := "last_claimed_date"
const DAILY_REWARD_LAST_CLAIMED_DAY := "last_claimed_day"
const MAX_CRATE_SLOTS := 4

signal player_info_updated
signal match_statistics_updated
signal currency_updated
signal gun_list_updated
signal skin_list_updated
signal daily_reward_claimed
signal gun_unlocked(gun_index: int)


func _init() -> void:
	create_path()
	load_data()
	EventBus.setting_changed.connect(_on_setting_changed)

func _on_setting_changed(setting_key: String, is_on: bool) -> void:
	save_game_data("game_settings", setting_key, is_on)


func _enter_tree() -> void:
	if AuthManager != null:
		AuthManager.initial_sync_completed.connect(refresh_ui)


func refresh_ui(val):
	if val == 1 or val == 1.0:
		match_statistics_updated.emit()
		currency_updated.emit()
		gun_list_updated.emit()
		skin_list_updated.emit()
		player_info_updated.emit()
		if GameManager and GameManager.ui_manager and GameManager.ui_manager.base_panel and GameManager.ui_manager.base_panel.profile_panel:
			GameManager.ui_manager.base_panel.profile_panel.profile_avatar_frame_updated.emit()
		if GameManager and GameManager.progression_manager:
			GameManager.progression_manager.progression_updated.emit()


func apply_remote_game_data(stats: Dictionary) -> void:
	if stats.is_empty():
		return
	var normalized := AuthData.normalize_game_stats(stats)

	# Merge local shop_coin_ads so cloud sync does not wipe active cooldowns or progress
	if game_data.has("shop_coin_ads") and game_data["shop_coin_ads"] is Dictionary:
		if not normalized.has("shop_coin_ads") or not (normalized["shop_coin_ads"] is Dictionary):
			normalized["shop_coin_ads"] = {}
		for pack_name in game_data["shop_coin_ads"].keys():
			var local_pack = game_data["shop_coin_ads"][pack_name]
			if local_pack is Dictionary:
				var local_ts: int = int(local_pack.get("last_claimed_timestamp", 0))
				var local_ads: int = int(local_pack.get("ads_watched", 0))
				var remote_pack = normalized["shop_coin_ads"].get(pack_name, {})
				var remote_ts: int = int(remote_pack.get("last_claimed_timestamp", 0)) if remote_pack is Dictionary else 0
				var remote_ads: int = int(remote_pack.get("ads_watched", 0)) if remote_pack is Dictionary else 0

				var best_ts := maxi(local_ts, remote_ts)
				var best_ads := maxi(local_ads, remote_ads) if best_ts == 0 else 0
				normalized["shop_coin_ads"][pack_name] = {
					"ads_watched": best_ads,
					"last_claimed_timestamp": best_ts
				}

	# Merge local IAP transaction history so cloud sync never loses purchases
	var local_player = game_data.get("player_data", {})
	if local_player is Dictionary and local_player.has("iap") and local_player["iap"] is Dictionary:
		var local_iap: Dictionary = local_player["iap"]
		if not normalized.has("player_data") or not (normalized["player_data"] is Dictionary):
			normalized["player_data"] = {}
		if not normalized["player_data"].has("iap") or not (normalized["player_data"]["iap"] is Dictionary):
			normalized["player_data"]["iap"] = {"entitlements": {}, "consumables": {}}
		var norm_iap: Dictionary = normalized["player_data"]["iap"]

		# Merge entitlements
		var local_ent = local_iap.get("entitlements", {})
		if local_ent is Dictionary:
			if not norm_iap.has("entitlements") or not (norm_iap["entitlements"] is Dictionary):
				norm_iap["entitlements"] = {}
			for k in local_ent.keys():
				norm_iap["entitlements"][str(k)] = local_ent[k]

		# Merge consumables
		var local_con = local_iap.get("consumables", {})
		if local_con is Dictionary:
			if not norm_iap.has("consumables") or not (norm_iap["consumables"] is Dictionary):
				norm_iap["consumables"] = {}
			for k in local_con.keys():
				norm_iap["consumables"][str(k)] = local_con[k]

	# Merge FTUE completion status
	if normalized.has("player_data") and normalized["player_data"] is Dictionary:
		normalized["player_data"]["ftue_completed"] = bool(local_player.get("ftue_completed", false)) or bool(normalized["player_data"].get("ftue_completed", false))

	game_data = normalized
	save_data()
	refresh_ui(1.0)


func on_initial_sync_completed(val:float) -> void:
	if val==1.0:
		match_statistics_updated.emit()
		currency_updated.emit()
		gun_list_updated.emit()
		skin_list_updated.emit()


func create_path():
	file_path = "user://" + file_name
	var absolute_path = ProjectSettings.globalize_path(file_path)
	print(absolute_path)


func save_data():
	var file = FileAccess.open(file_path, FileAccess.WRITE)
	if file:
		file.store_var(game_data)
		file.close()
		print("Saved successfully (DAT)")
		GameManager.push_changes()
	else:
		push_error("Save failed")


func load_data():
	if not FileAccess.file_exists(file_path):
		initialize_default_data()
		save_data()
		return

	var file = FileAccess.open(file_path, FileAccess.READ)
	if file:
		var result = file.get_var()

		if result != null and typeof(result) == TYPE_DICTIONARY:
			game_data = AuthData.normalize_game_stats(result)
			print("Loaded successfully (DAT)")
		else:
			print("Corrupted data, resetting...")
			initialize_default_data()
			save_data()

		file.close()


func initialize_default_data():
	game_data = {
		"player_data": {
			"profile_pic_index": 0,
			"profile_frame_index": 0,
			"name": "",
			"user_id": null,
			"total_game_played": 0,
			"win_game": 0,
			"total_ads_shown": 0,
			"current_win_streak": 0,
			"best_win_streak": 0,
			"xp": 0,
			"level": 1,
			"total_coins_winings": 0,
			"interstitial_match_counter": 0,
			"avatar_unlocked": [true, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false],
			"frame_unlocked": [true, false, false, false, false, false, false],
			"remove_ads": false,
			"ftue_completed": false,
			"iap": {
				"entitlements": {},
				"consumables": {}
			},
		},
		"guns_data": {
			"guns_unlocked": [true, false, false, true, false, false, true, false, false],
			"skins_unlocked": [
				[true, false, false],
				[true, false, false],
				[true, false, false],
				[true, false, false],
				[true, false, false],
				[true, false, false],
				[true, false, false],
				[true, false, false],
				[true, false, false],
				],
			"skin_selected": [0, 0, 0, 0, 0, 0, 0, 0, 0],
			"cards_collected": [0, 0, 0, 0, 0, 0, 0, 0, 0],
			"gun_selected_index": 0
		},
		"game_settings": {
			"music_on": true,
			"sound_on": true,
			"haptic_on": true
		},
		"DAILY_REWARDS_CATEGORY": {
			"DAILY_REWARD_CURRENT_DAY": 1,
			"DAILY_REWARD_LAST_CLAIMED_DATE": "",
			"DAILY_REWARD_LAST_CLAIMED_DAY": 0
		},
		"slots": [ {
				"unlocked": true,
				"occupied": false,
				"crate_type": 0,
				"gun_type": 0,
				"crate_unlocked_time": null,
			}, {
				"unlocked": true,
				"occupied": false,
				"crate_type": 0,
				"gun_type": 0,
				"crate_unlocked_time": null,
			}, {
				"unlocked": true,
				"occupied": false,
				"crate_type": 0,
				"gun_type": 0,
				"crate_unlocked_time": null,
			}, {
				"unlocked": true,
				"occupied": false,
				"crate_type": 0,
				"gun_type": 0,
				"crate_unlocked_time": null,
			}],
		"currency": {
			"Coins": 1000,
			"Diamonds": 5
		},
		"arena_attempts": {
			"tokyo": 0,
			"newyork": 0,
			"delhi": 0,
			"LAN_Play": 0
		},
		"shop_coin_ads": {}
	}


func set_user_data(_name: String, user_id):
	if game_data["player_data"]["name"] == "":
		game_data["player_data"]["name"] = _name.left(15)
	if game_data["player_data"]["user_id"] == null:
		game_data["player_data"]["user_id"] = string_to_8_digit_hash(user_id) if typeof(user_id) == TYPE_STRING else user_id
	save_data()
	player_info_updated.emit()


func string_to_8_digit_hash(value: String) -> int:
	var hash_value := value.hash()
	return 10_000_000 + (abs(hash_value) % 90_000_000)

func get_arena_attempt(arena_name: String) -> int:
	if not game_data.has("arena_attempts") or typeof(game_data["arena_attempts"]) != TYPE_DICTIONARY:
		game_data["arena_attempts"] = {}
	if arena_name == "LAN_Play" or arena_name.to_lower() == "lan_play" or arena_name.to_lower() == "lanplay":
		if game_data["arena_attempts"].has("LAN_Play"):
			return int(game_data["arena_attempts"]["LAN_Play"])
		elif game_data["arena_attempts"].has("lan_play"):
			return int(game_data["arena_attempts"]["lan_play"])
		elif game_data["arena_attempts"].has("lanplay"):
			return int(game_data["arena_attempts"]["lanplay"])
		return 0
	var clean_key = arena_name.strip_edges().to_lower().replace(":", "_").replace(" ", "").replace("_", "")
	if game_data["arena_attempts"].has(clean_key):
		return int(game_data["arena_attempts"][clean_key])
	var underscore_key = arena_name.strip_edges().to_lower().replace(":", "_").replace(" ", "_")
	return int(game_data["arena_attempts"].get(underscore_key, 0))

func increment_arena_attempt(arena_name: String) -> int:
	if not game_data.has("arena_attempts") or typeof(game_data["arena_attempts"]) != TYPE_DICTIONARY:
		game_data["arena_attempts"] = {}
	var key_to_use = arena_name
	if arena_name == "LAN_Play" or arena_name.to_lower() == "lan_play" or arena_name.to_lower() == "lanplay":
		key_to_use = "LAN_Play"
		# Remove old duplicates
		game_data["arena_attempts"].erase("lanplay")
		game_data["arena_attempts"].erase("lan_play")
	else:
		key_to_use = arena_name.strip_edges().to_lower().replace(":", "_").replace(" ", "").replace("_", "")
	
	var current = get_arena_attempt(arena_name) + 1
	game_data["arena_attempts"][key_to_use] = current
	save_data()
	if GameManager and GameManager.has_method("push_changes"):
		GameManager.push_changes()
	return current

func get_total_ads_shown() -> int:
	if game_data.has("player_data") and game_data["player_data"].has("total_ads_shown"):
		return int(game_data["player_data"]["total_ads_shown"])
	return 0

func increment_total_ads_shown() -> int:
	if not game_data.has("player_data") or typeof(game_data["player_data"]) != TYPE_DICTIONARY:
		game_data["player_data"] = {}
	var count = int(game_data["player_data"].get("total_ads_shown", 0)) + 1
	game_data["player_data"]["total_ads_shown"] = count
	save_data()
	return count

func get_interstitial_match_counter() -> int:
	if game_data.has("player_data") and game_data["player_data"].has("interstitial_match_counter"):
		return int(game_data["player_data"]["interstitial_match_counter"])
	return 0

func set_interstitial_match_counter(count: int) -> void:
	if not game_data.has("player_data") or typeof(game_data["player_data"]) != TYPE_DICTIONARY:
		game_data["player_data"] = {}
	game_data["player_data"]["interstitial_match_counter"] = count
	save_data()

func increment_interstitial_match_counter() -> int:
	var count: int = get_interstitial_match_counter() + 1
	set_interstitial_match_counter(count)
	return count

func reset_interstitial_match_counter() -> void:
	set_interstitial_match_counter(0)

func add_total_coin_wining(value: int):
	game_data["player_data"]["total_coins_winings"] += value
	save_data()
	match_statistics_updated.emit()
	
func add_coin(value: int):
	game_data["currency"]["Coins"] += value
	save_data()
	currency_updated.emit()

func add_diamond(value: int):
	game_data["currency"]["Diamonds"] = game_data["currency"]["Diamonds"] + value
	save_data()
	currency_updated.emit()

func use_diamond(value: int) -> bool:
	if value <= 0 or int(game_data["currency"]["Diamonds"]) < value:
		return false
	game_data["currency"]["Diamonds"] = game_data["currency"]["Diamonds"] - value
	save_data()
	currency_updated.emit()
	AudioPlayer.play_sfx(AudioPlayer.SOUND_DB.cash_spent)
	return true

func use_coin(value: int) -> bool:
	if value <= 0 or int(game_data["currency"]["Coins"]) < value:
		return false

	game_data["currency"]["Coins"] = game_data["currency"]["Coins"] - value
	save_data()
	currency_updated.emit()
	AudioPlayer.play_sfx(AudioPlayer.SOUND_DB.cash_spent)
	return true

func save_game_data(category: String, key: String, value):
	if not game_data.has(category):
		game_data[category] = {}
	game_data[category][key] = value
	save_data()
	if category == "player_data":
		player_info_updated.emit()

func has_remove_ads() -> bool:
	var p_data = game_data.get("player_data", {})
	return bool(p_data.get("remove_ads", false))

func has_entitlement(product_id: String) -> bool:
	if product_id == "remove_ad" or product_id == "test_id" or product_id == "remove_ads":
		return has_remove_ads()
	var p_data = game_data.get("player_data", {})
	if p_data.has("iap") and p_data["iap"] is Dictionary and p_data["iap"].has("entitlements"):
		var ent = p_data["iap"]["entitlements"].get(product_id, false)
		if ent is bool:
			return ent
		elif ent is Dictionary:
			return bool(ent.get("active", true))
	return false

func get_iap_data() -> Dictionary:
	var p_data = game_data.get("player_data", {})
	if p_data.has("iap") and p_data["iap"] is Dictionary:
		return p_data["iap"]
	return {"entitlements": {}, "consumables": {}}

func set_iap_data(iap_dict: Dictionary) -> void:
	if not game_data.has("player_data") or not (game_data["player_data"] is Dictionary):
		game_data["player_data"] = {}
	game_data["player_data"]["iap"] = iap_dict
	save_data()

func record_iap_entitlement(product_id: String, details: Dictionary = {}) -> void:
	if not game_data.has("player_data") or not (game_data["player_data"] is Dictionary):
		game_data["player_data"] = {}
	if not game_data["player_data"].has("iap") or not (game_data["player_data"]["iap"] is Dictionary):
		game_data["player_data"]["iap"] = {"entitlements": {}, "consumables": {}}
	if not game_data["player_data"]["iap"].has("entitlements") or not (game_data["player_data"]["iap"]["entitlements"] is Dictionary):
		game_data["player_data"]["iap"]["entitlements"] = {}

	var record := {
		"product_id": product_id,
		"timestamp": int(Time.get_unix_time_from_system()),
		"date_utc": Time.get_datetime_string_from_system(true),
		"active": true
	}
	for k in details.keys():
		record[str(k)] = details[k]

	game_data["player_data"]["iap"]["entitlements"][product_id] = record
	save_data()
	AuthManager.push_pending_local_data()


func record_iap_consumable(product_id: String, details: Dictionary = {}) -> void:
	if not game_data.has("player_data") or not (game_data["player_data"] is Dictionary):
		game_data["player_data"] = {}
	if not game_data["player_data"].has("iap") or not (game_data["player_data"]["iap"] is Dictionary):
		game_data["player_data"]["iap"] = {"entitlements": {}, "consumables": {}}
	if not game_data["player_data"]["iap"].has("consumables") or not (game_data["player_data"]["iap"]["consumables"] is Dictionary):
		game_data["player_data"]["iap"]["consumables"] = {}

	var now := int(Time.get_unix_time_from_system())
	var token_suffix := str(details.get("purchase_token", "")).left(12)
	var txn_id := "txn_%d_%s" % [now, product_id] if token_suffix.is_empty() else "txn_%d_%s_%s" % [now, product_id, token_suffix]

	var record := {
		"product_id": product_id,
		"timestamp": now,
		"date_utc": Time.get_datetime_string_from_system(true)
	}
	for k in details.keys():
		record[str(k)] = details[k]

	game_data["player_data"]["iap"]["consumables"][txn_id] = record
	save_data()
	AuthManager.push_pending_local_data()


func unlock_gun(idx: int):
	if idx >= 0 and idx < game_data["guns_data"]["guns_unlocked"].size():
		if not game_data["guns_data"]["guns_unlocked"][idx]:
			game_data["guns_data"]["guns_unlocked"][idx] = true
			_track_gun_unlock(idx)
			save_data()
			gun_list_updated.emit()
			gun_unlocked.emit(idx)


func unlock_skin(idx: int, skin: int):
	if idx >= 0 and idx < game_data["guns_data"]["skins_unlocked"].size() and skin >= 0 and skin < game_data["guns_data"]["skins_unlocked"][idx].size():
		if not game_data["guns_data"]["skins_unlocked"][idx][skin]:
			game_data["guns_data"]["skins_unlocked"][idx][skin] = true
			_track_skin_unlock(idx, skin)
			save_data()
			skin_list_updated.emit()


func skin_select(idx: int, skin: int):
	if idx >= 0 and idx < game_data["guns_data"]["skin_selected"].size():
		if int(game_data["guns_data"]["skin_selected"][idx]) == skin:
			return
		game_data["guns_data"]["skin_selected"][idx] = skin
		_track_skin_equipped(idx, skin)
		save_data()
		skin_list_updated.emit()

func cards_update(idx: int, card: int):
	var all_gun_data: AllGunData = load("res://ZeroAimZone-Godot/4_Resources/Tres/all_gun_data.tres")
	var cards_needed := 10
	if all_gun_data and idx >= 0 and idx < all_gun_data.all_guns.size() and all_gun_data.all_guns[idx]:
		cards_needed = all_gun_data.all_guns[idx].cards_needed

	game_data["guns_data"]["cards_collected"][idx] = mini(game_data["guns_data"]["cards_collected"][idx] + card, cards_needed)
	if game_data["guns_data"]["cards_collected"][idx] >= cards_needed:
		if not game_data["guns_data"]["guns_unlocked"][idx]:
			unlock_gun(idx)
			return
	gun_list_updated.emit()
	save_data()


func _track_gun_unlock(idx: int) -> void:
	var gun_name_str := "Gun_%d" % idx
	var all_gun_data: AllGunData = load("res://ZeroAimZone-Godot/4_Resources/Tres/all_gun_data.tres")
	if all_gun_data and idx >= 0 and idx < all_gun_data.all_guns.size() and all_gun_data.all_guns[idx]:
		var g_name: String = all_gun_data.all_guns[idx].name
		if not g_name.is_empty():
			gun_name_str = g_name
	GameAnalysis.track_gun_unlocked(idx, gun_name_str)


func _track_skin_unlock(idx: int, skin_idx: int) -> void:
	var gun_name_str := "Gun_%d" % idx
	var all_gun_data: AllGunData = load("res://ZeroAimZone-Godot/4_Resources/Tres/all_gun_data.tres")
	if all_gun_data and idx >= 0 and idx < all_gun_data.all_guns.size() and all_gun_data.all_guns[idx]:
		var g_name: String = all_gun_data.all_guns[idx].name
		if not g_name.is_empty():
			gun_name_str = g_name
	GameAnalysis.track_skin_unlocked(idx, skin_idx, gun_name_str)


func _track_skin_equipped(idx: int, skin_idx: int) -> void:
	var gun_name_str := "Gun_%d" % idx
	var all_gun_data: AllGunData = load("res://ZeroAimZone-Godot/4_Resources/Tres/all_gun_data.tres")
	if all_gun_data and idx >= 0 and idx < all_gun_data.all_guns.size() and all_gun_data.all_guns[idx]:
		var g_name: String = all_gun_data.all_guns[idx].name
		if not g_name.is_empty():
			gun_name_str = g_name
	GameAnalysis.track_skin_equipped(idx, skin_idx, gun_name_str)
	
func select_gun(idx: int):
	game_data["guns_data"]["gun_selected_index"] = idx
	save_data()
	gun_list_updated.emit()
	
	
func record_match_result(player_won: bool) -> void:
	var player_data: Dictionary = game_data["player_data"]
	player_data["total_game_played"] = int(player_data["total_game_played"]) + 1
	player_data["ftue_completed"] = true

	if player_won:
		player_data["win_game"] = int(player_data["win_game"]) + 1
		player_data["current_win_streak"] = int(player_data["current_win_streak"]) + 1
		player_data["best_win_streak"] = max(
			int(player_data["best_win_streak"]),
			int(player_data["current_win_streak"])
		)
	else:
		player_data["current_win_streak"] = 0

	save_data()
	match_statistics_updated.emit()


func add_crate_to_slot(position: int, crate_type: int, gun_type: int) -> void:
	game_data["slots"][position]["occupied"] = true
	game_data["slots"][position]["crate_type"] = crate_type
	game_data["slots"][position]["gun_type"] = gun_type
	
	save_data()

func clear_slot(position: int) -> void:
	game_data["slots"][position]["occupied"] = false
	game_data["slots"][position]["crate_type"] = 0
	game_data["slots"][position]["crate_unlocked_time"] = null
	game_data["slots"][position]["gun_type"] = -1
	save_data()

func _get_trusted_unix_time() -> int:
	return TimeManager.get_unix_time()


func unlock_crate(position: int, time_minutes: int):
	var duration_seconds: int = maxi(1, time_minutes * 60)
	game_data["slots"][position]["crate_unlocked_time"] = _get_trusted_unix_time() + duration_seconds
	save_data()


func refresh_daily_reward_streak() -> void:
	var last_claimed_date := str(game_data["DAILY_REWARDS_CATEGORY"]["DAILY_REWARD_LAST_CLAIMED_DATE"])
	if last_claimed_date == "":
		return

	var today_str := _get_today_date_string()
	var days_since_claim := _days_between_dates(last_claimed_date, today_str)
	if days_since_claim < 0:
		# Clock manipulated backwards; do not reset streak or corrupt state
		return

	if days_since_claim > 1:
		var should_save := int(game_data["DAILY_REWARDS_CATEGORY"]["DAILY_REWARD_CURRENT_DAY"]) != 1
		game_data["DAILY_REWARDS_CATEGORY"]["DAILY_REWARD_CURRENT_DAY"] = 1

		if should_save:
			save_data()


func get_daily_reward_current_day() -> int:
	refresh_daily_reward_streak()
	return int(game_data["DAILY_REWARDS_CATEGORY"]["DAILY_REWARD_CURRENT_DAY"])


func get_daily_reward_last_claimed_date() -> String:
	return str(game_data["DAILY_REWARDS_CATEGORY"]["DAILY_REWARD_LAST_CLAIMED_DATE"])


func get_daily_reward_last_claimed_day() -> int:
	if get_daily_reward_last_claimed_date() != _get_today_date_string():
		return 0

	return int(game_data["DAILY_REWARDS_CATEGORY"]["DAILY_REWARD_LAST_CLAIMED_DAY"])


func can_claim_daily_reward() -> bool:
	refresh_daily_reward_streak()
	var last_claimed_date := get_daily_reward_last_claimed_date()
	if last_claimed_date == "":
		return true
	var today_date := _get_today_date_string()
	var diff := _days_between_dates(last_claimed_date, today_date)
	return diff > 0


func does_daily_reward_claim_require_ad() -> bool:
	return false


func mark_daily_reward_claimed(reward_count: int) -> void:
	var current_day := int(game_data["DAILY_REWARDS_CATEGORY"]["DAILY_REWARD_CURRENT_DAY"])
	game_data["DAILY_REWARDS_CATEGORY"]["DAILY_REWARD_LAST_CLAIMED_DATE"] = _get_today_date_string()
	game_data["DAILY_REWARDS_CATEGORY"]["DAILY_REWARD_LAST_CLAIMED_DAY"] = current_day
	game_data["DAILY_REWARDS_CATEGORY"]["DAILY_REWARD_CURRENT_DAY"] = (current_day % max(reward_count, 1)) + 1
	save_data()
	daily_reward_claimed.emit()


func _get_today_date_string() -> String:
	return TimeManager.get_today_date_string()


func _days_between_dates(from_date: String, to_date: String) -> int:
	var from_parts := from_date.split("-")
	var to_parts := to_date.split("-")

	if from_parts.size() != 3 or to_parts.size() != 3:
		return 0

	var from_unix := Time.get_unix_time_from_datetime_dict({
		"year": int(from_parts[0]),
		"month": int(from_parts[1]),
		"day": int(from_parts[2]),
		"hour": 0,
		"minute": 0,
		"second": 0
	})
	var to_unix := Time.get_unix_time_from_datetime_dict({
		"year": int(to_parts[0]),
		"month": int(to_parts[1]),
		"day": int(to_parts[2]),
		"hour": 0,
		"minute": 0,
		"second": 0
	})

	return int((to_unix - from_unix) / 86400.0)


# ============================================================
# SHOP COIN ADS (REWARDED ADS)
# ============================================================

const SHOP_COIN_AD_COOLDOWN_SECONDS: int = 86400 # 24 hours

func get_shop_coin_ad_data(pack_name: String) -> Dictionary:
	if game_data.has("shop_coin_ads") and game_data["shop_coin_ads"] is Dictionary:
		var pack_data = game_data["shop_coin_ads"].get(pack_name, {})
		if pack_data is Dictionary:
			return pack_data
		elif pack_data is int:
			return {"ads_watched": pack_data, "last_claimed_timestamp": 0}
	return {"ads_watched": 0, "last_claimed_timestamp": 0}

func set_shop_coin_ad_data(pack_name: String, ads_watched: int, last_claimed_timestamp: int) -> void:
	if not game_data.has("shop_coin_ads") or not game_data["shop_coin_ads"] is Dictionary:
		game_data["shop_coin_ads"] = {}
	game_data["shop_coin_ads"][pack_name] = {
		"ads_watched": ads_watched,
		"last_claimed_timestamp": last_claimed_timestamp
	}
	save_data()

func get_shop_coin_pack_cooldown(pack_name: String) -> int:
	var data := get_shop_coin_ad_data(pack_name)
	var last_claimed: int = int(data.get("last_claimed_timestamp", 0))
	if last_claimed <= 0:
		return 0
	var elapsed := _get_trusted_unix_time() - last_claimed
	if elapsed < SHOP_COIN_AD_COOLDOWN_SECONDS:
		return SHOP_COIN_AD_COOLDOWN_SECONDS - elapsed
	return 0

func record_shop_coin_ad_watched(pack_name: String, required_ads: int, reward_amount: int) -> Dictionary:
	var data := get_shop_coin_ad_data(pack_name)
	var current_watched: int = int(data.get("ads_watched", 0))
	var next_watched := current_watched + 1
	var completed := false

	if next_watched >= required_ads:
		completed = true
		var now := _get_trusted_unix_time()
		set_shop_coin_ad_data(pack_name, 0, now)
		add_coin(reward_amount)
	else:
		set_shop_coin_ad_data(pack_name, next_watched, 0)

	return {
		"completed": completed,
		"ads_watched": 0 if completed else next_watched,
		"cooldown_remaining": SHOP_COIN_AD_COOLDOWN_SECONDS if completed else 0
	}
