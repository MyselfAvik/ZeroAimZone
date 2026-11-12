class_name AuthData
extends RefCounted

static func game_stats() -> Dictionary:
	return {
		"player_data": {
			"name": "",
			"user_id": "",
			"profile_pic_index": 0,
			"profile_frame_index": 0,
			"total_game_played": 0,
			"win_game": 0,
			"current_win_streak": 0,
			"best_win_streak": 0,
			"xp": 0,
			"level": 1,
			"total_coins_winings": 0,
			"total_ads_shown": 0,
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

static func user_data() -> Dictionary:
	return {
		"userId": "",
		"userName": "",
		"email": "",
		"profilePics": [],
		"gameStats": game_stats(),
		"totalScreenTimeSeconds": 0,
		"totalSessions": 0,
		"lastSessionDateUTC": ""
	}

static func data_store() -> Dictionary:
	return {
		"playerData": user_data(),
		"pendingWrites": [],
		"hasUnsyncedChanges": false,
		"lastSyncTicks": 0
	}

static func pending_write(document_path: String, data: Dictionary) -> Dictionary:
	return {
		"documentPath": document_path,
		"data": data
	}

static func normalize_store(store: Variant) -> Dictionary:
	var normalized := data_store()
	if typeof(store) != TYPE_DICTIONARY:
		return normalized
	_merge_existing(normalized, store)
	_normalize_player_data(normalized.playerData)
	if typeof(normalized.pendingWrites) != TYPE_ARRAY:
		normalized.pendingWrites = []
	return normalized

static func user_profile_to_map(name: String, email: String, photo_url: String, client_type: String) -> Dictionary:
	return {
		"name": name,
		"email": email,
		"photoUrl": photo_url,
		"clientType": client_type,
		"lastLogin": Time.get_datetime_string_from_system(false)
	}

static func game_profile_to_map(name: String, package_name: String, include_stats := true) -> Dictionary:
	var map := {
		"name": name,
		"packageName": package_name,
		"screenTime": 0,
		"session": 0,
		"updatedAt": Time.get_datetime_string_from_system(true)
	}
	if include_stats:
		map["stats"] = {}
	return map

static func _normalize_player_data(player_data: Dictionary) -> void:
	var defaults := user_data()
	_merge_existing(defaults, player_data)
	player_data.clear()
	_merge_existing(player_data, defaults)
	if typeof(player_data.profilePics) != TYPE_ARRAY:
		player_data.profilePics = []
	if typeof(player_data.gameStats) != TYPE_DICTIONARY:
		player_data.gameStats = game_stats()
	var stats := game_stats()
	_merge_existing(stats, player_data.gameStats)
	player_data.gameStats = stats

static func _merge_existing(target: Dictionary, source: Dictionary) -> void:
	for key in source.keys():
		if (
			target.has(key)
			and typeof(target[key]) == TYPE_DICTIONARY
			and typeof(source[key]) == TYPE_DICTIONARY
		):
			_merge_existing(target[key], source[key])
		else:
			target[key] = source[key]

static func normalize_game_stats(stats: Variant) -> Dictionary:
	var defaults := game_stats()

	if typeof(stats) != TYPE_DICTIONARY:
		return defaults

	_merge_existing(defaults, stats)

	var player_data: Dictionary = defaults.player_data
	var guns_data: Dictionary = defaults.guns_data
	var settings: Dictionary = defaults.game_settings
	var rewards: Dictionary = defaults.DAILY_REWARDS_CATEGORY
	var currency: Dictionary = defaults.currency

	player_data.profile_pic_index = int(player_data.profile_pic_index)
	player_data.profile_frame_index = int(player_data.profile_frame_index)
	player_data.total_game_played = int(player_data.total_game_played)
	player_data.win_game = int(player_data.win_game)
	player_data.current_win_streak = int(player_data.current_win_streak)
	player_data.best_win_streak = int(player_data.best_win_streak)
	player_data.xp = int(player_data.xp)
	player_data.level = int(player_data.level)
	player_data.total_coins_winings = int(player_data.total_coins_winings)
	player_data.total_ads_shown = int(player_data.get("total_ads_shown", 0))
	player_data.interstitial_match_counter = int(player_data.get("interstitial_match_counter", 0))

	if typeof(player_data.avatar_unlocked) == TYPE_ARRAY:
		for i in range(player_data.avatar_unlocked.size()):
			player_data.avatar_unlocked[i] = bool(player_data.avatar_unlocked[i])

	if typeof(player_data.frame_unlocked) == TYPE_ARRAY:
		for i in range(player_data.frame_unlocked.size()):
			player_data.frame_unlocked[i] = bool(player_data.frame_unlocked[i])

	player_data.remove_ads = bool(player_data.get("remove_ads", false))
	player_data.ftue_completed = bool(player_data.get("ftue_completed", false))

	if not player_data.has("iap") or typeof(player_data.iap) != TYPE_DICTIONARY:
		player_data["iap"] = {
			"entitlements": {},
			"consumables": {}
		}
	else:
		if not player_data.iap.has("entitlements") or typeof(player_data.iap.entitlements) != TYPE_DICTIONARY:
			player_data.iap["entitlements"] = {}
		if not player_data.iap.has("consumables") or typeof(player_data.iap.consumables) != TYPE_DICTIONARY:
			player_data.iap["consumables"] = {}

	guns_data.gun_selected_index = int(guns_data.gun_selected_index)

	if typeof(guns_data.guns_unlocked) == TYPE_ARRAY:
		for i in range(guns_data.guns_unlocked.size()):
			guns_data.guns_unlocked[i] = bool(guns_data.guns_unlocked[i])

	# Normalize 2D skins_unlocked array from Firestore wrapper { "values": [...] }
	var raw_skins = null
	if typeof(stats) == TYPE_DICTIONARY and stats.has("guns_data") and typeof(stats.guns_data) == TYPE_DICTIONARY:
		raw_skins = stats.guns_data.get("skins_unlocked", null)
	if raw_skins == null:
		raw_skins = guns_data.get("skins_unlocked", null)

	guns_data.skins_unlocked = _normalize_skins_unlocked(raw_skins, game_stats().guns_data.skins_unlocked)

	if typeof(guns_data.skin_selected) == TYPE_ARRAY:
		for i in guns_data.skin_selected.size():
			guns_data.skin_selected[i] = int(guns_data.skin_selected[i])

	if typeof(guns_data.cards_collected) == TYPE_ARRAY:
		for i in guns_data.cards_collected.size():
			guns_data.cards_collected[i] = int(guns_data.cards_collected[i])

	rewards.DAILY_REWARD_CURRENT_DAY = int(
		rewards.DAILY_REWARD_CURRENT_DAY
	)

	rewards.DAILY_REWARD_LAST_CLAIMED_DAY = int(
		rewards.DAILY_REWARD_LAST_CLAIMED_DAY
	)

	currency.Coins = int(currency.Coins)
	currency.Diamonds = int(currency.Diamonds)

	if not defaults.has("arena_attempts") or typeof(defaults.arena_attempts) != TYPE_DICTIONARY:
		defaults["arena_attempts"] = {}
	if typeof(stats) == TYPE_DICTIONARY and stats.has("arena_attempts") and typeof(stats.arena_attempts) == TYPE_DICTIONARY:
		for k in stats.arena_attempts.keys():
			var key_str := str(k)
			if key_str.to_lower() == "lan_play" or key_str.to_lower() == "lanplay":
				defaults.arena_attempts["LAN_Play"] = int(stats.arena_attempts[k])
			else:
				defaults.arena_attempts[key_str.to_lower()] = int(stats.arena_attempts[k])
		if defaults.arena_attempts.has("LAN_Play"):
			defaults.arena_attempts.erase("lanplay")
			defaults.arena_attempts.erase("lan_play")

	if not defaults.has("shop_coin_ads") or typeof(defaults.shop_coin_ads) != TYPE_DICTIONARY:
		defaults["shop_coin_ads"] = {}
	if typeof(stats) == TYPE_DICTIONARY and stats.has("shop_coin_ads") and typeof(stats.shop_coin_ads) == TYPE_DICTIONARY:
		for pack in stats.shop_coin_ads.keys():
			var p_data = stats.shop_coin_ads[pack]
			if p_data is Dictionary:
				defaults.shop_coin_ads[str(pack)] = {
					"ads_watched": int(p_data.get("ads_watched", 0)),
					"last_claimed_timestamp": int(p_data.get("last_claimed_timestamp", 0))
				}
			elif p_data is int or p_data is float:
				defaults.shop_coin_ads[str(pack)] = {
					"ads_watched": int(p_data),
					"last_claimed_timestamp": 0
				}

	return defaults


static func _normalize_skins_unlocked(raw_skins: Variant, default_skins: Array) -> Array:
	var result: Array = []
	var raw_list: Array = []

	if typeof(raw_skins) == TYPE_ARRAY:
		raw_list = raw_skins
	elif typeof(raw_skins) == TYPE_DICTIONARY:
		for i in range(default_skins.size()):
			var key_str := str(i)
			if raw_skins.has(key_str):
				raw_list.append(raw_skins[key_str])
			elif raw_skins.has(i):
				raw_list.append(raw_skins[i])
			else:
				raw_list.append(null)

	for i in range(default_skins.size()):
		var sub_array: Array = []
		var default_sub: Array = default_skins[i]

		var raw_sub = raw_list[i] if i < raw_list.size() else null

		if typeof(raw_sub) == TYPE_ARRAY:
			for j in range(default_sub.size()):
				if j < raw_sub.size():
					sub_array.append(bool(raw_sub[j]))
				else:
					sub_array.append(bool(default_sub[j]))
		elif typeof(raw_sub) == TYPE_DICTIONARY:
			# Firestore wrapper format `{ "values": [true, true, true] }`
			if raw_sub.has("values") and typeof(raw_sub.values) == TYPE_ARRAY:
				var vals: Array = raw_sub.values
				for j in range(default_sub.size()):
					if j < vals.size():
						sub_array.append(bool(vals[j]))
					else:
						sub_array.append(bool(default_sub[j]))
			else:
				for j in range(default_sub.size()):
					var key_str := str(j)
					if raw_sub.has(key_str):
						sub_array.append(bool(raw_sub[key_str]))
					elif raw_sub.has(j):
						sub_array.append(bool(raw_sub[j]))
					else:
						sub_array.append(bool(default_sub[j]))
		else:
			sub_array = default_sub.duplicate(true)

		result.append(sub_array)

	return result
