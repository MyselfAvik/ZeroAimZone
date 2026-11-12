class_name ProgressionManager
extends Node

var xp: int
var level:int
signal progression_updated
const LEVEL_XP_REQUIRED: Array[int] = [
	100, 120, 140, 160, 180, 200, 220, 240, 260, 280,
	300, 325, 350, 375, 400, 425, 450, 475, 500, 525,
	550, 580, 610, 640, 670, 700, 730, 760, 790, 820,
	850, 885, 920, 955, 990, 1025, 1060, 1095, 1130, 1165,
	1200, 1240, 1280, 1320, 1360, 1400, 1440, 1480, 1520, 1560,
	1600, 1650, 1700, 1750, 1800, 1850, 1900, 1950, 2000, 2050,
	2100, 2160, 2220, 2280, 2340, 2400, 2460, 2520, 2580, 2640,
	2700, 2770, 2840, 2910, 2980, 3050, 3120, 3190, 3260, 3330,
	3400, 3480, 3560, 3640, 3720, 3800, 3880, 3960, 4040, 4120,
	4200, 4290, 4380, 4470, 4560, 4650, 4740, 4830, 4920, 5000
]

enum CRATE_TYPE{
	BRONZE=0,
	SILVER=1,
	GOLD=2
}

func _enter_tree() -> void:
	pass


func add_xp(amount: int) -> void:
	xp = GameManager.save_manager.game_data["player_data"]["xp"]
	level = GameManager.save_manager.game_data["player_data"]["level"]
	var max_level: int = LEVEL_XP_REQUIRED.size()

	if level >= max_level:
		xp = 0
		level = max_level
	else:
		xp += amount
		while level < max_level and xp >= LEVEL_XP_REQUIRED[level - 1]:
			xp -= LEVEL_XP_REQUIRED[level - 1]
			level += 1
		if level >= max_level:
			xp = 0
			level = max_level

	GameManager.save_manager.game_data["player_data"]["xp"] = xp
	GameManager.save_manager.game_data["player_data"]["level"] = level
	GameManager.save_manager.save_data()
	
	progression_updated.emit()

func add_coins(amount: int) -> void:
	if amount <= 0:
		return
	GameManager.save_manager.add_coin(amount)
	var arena_name = GameManager.get_current_arena_name() if GameManager else "MatchWin"
	GameAnalysis.track_economy_event(GameAnalysis.RESOURCE_FLOW_TYPE_SOURCE, "Coins", float(amount), "Reward", "MatchWin_" + arena_name)

func add_diamonds(amount: int) -> void:
	if amount <= 0:
		return
	GameManager.save_manager.add_diamond(amount)
	var arena_name = GameManager.get_current_arena_name() if GameManager else "MatchWin"
	GameAnalysis.track_economy_event(GameAnalysis.RESOURCE_FLOW_TYPE_SOURCE, "Diamonds", float(amount), "Reward", "MatchWin_" + arena_name)

var current_match_crate: CRATE_TYPE = CRATE_TYPE.BRONZE
var has_calculated_crate: bool = false

func reward_for_match(res:int):
	GameManager.save_manager.record_match_result(res == 0)
	if res == 0:
		give_wining_rewards()
	else:
		give_lossing_rewards()
	has_calculated_crate = false

func give_wining_rewards():
	var coin_reward = GameManager.current_match.coin_reward if (GameManager and GameManager.current_match) else 0
	if coin_reward > 0:
		add_coins(coin_reward)
		GameManager.save_manager.add_total_coin_wining(coin_reward)
	var free_slot_index:Array[int]=[]
	add_xp(100)
	for i in range(GameManager.save_manager.game_data["slots"].size()):
		if GameManager.save_manager.game_data["slots"][i].unlocked==true and GameManager.save_manager.game_data["slots"][i].occupied==false:
			free_slot_index.append(i)
	if free_slot_index.size()>=1:
		GameManager.save_manager.add_crate_to_slot(free_slot_index[0],get_reward_crate_type(),get_current_gun_type())


func has_free_crate_slot() -> bool:
	if not GameManager or not GameManager.save_manager or not GameManager.save_manager.game_data.has("slots"):
		return false
	for slot in GameManager.save_manager.game_data["slots"]:
		if slot.get("unlocked", false) and not slot.get("occupied", false):
			return true
	return false


func give_lossing_rewards():
	add_xp(50)

func calculate_reward_crate_type() -> CRATE_TYPE:
	var entry_fee: int = GameManager.current_match.entry_fee if (GameManager and GameManager.current_match) else 100
	var rand: float = randf() * 100.0
	var crate: CRATE_TYPE = CRATE_TYPE.BRONZE


	if entry_fee < 300: 
		if rand < 70.0:
			crate = CRATE_TYPE.BRONZE
		elif rand < 95.0:
			crate = CRATE_TYPE.SILVER
		else:
			crate = CRATE_TYPE.GOLD
	elif entry_fee < 700: # New York (400)
		if rand < 5.0:
			crate = CRATE_TYPE.BRONZE
		elif rand < 75.0:
			crate = CRATE_TYPE.SILVER
		else:
			crate = CRATE_TYPE.GOLD
	else: # Delhi (800+)
		if rand < 55.0:
			crate = CRATE_TYPE.SILVER
		else:
			crate = CRATE_TYPE.GOLD

	# B. Win-Streak Boosters
	var streak: int = 0
	if GameManager and GameManager.save_manager and GameManager.save_manager.game_data.has("player_data"):
		streak = int(GameManager.save_manager.game_data["player_data"].get("current_win_streak", 0))

	if streak >= 5:
		crate = CRATE_TYPE.GOLD
	elif streak >= 3:
		if crate == CRATE_TYPE.BRONZE:
			crate = CRATE_TYPE.SILVER

	current_match_crate = crate
	has_calculated_crate = true
	return current_match_crate

func get_reward_crate_type() -> CRATE_TYPE:
	if has_calculated_crate:
		return current_match_crate
	return calculate_reward_crate_type()

func get_current_gun_type() -> int:
	var all_guns_res: AllGunData = preload("res://ZeroAimZone-Godot/4_Resources/Tres/all_gun_data.tres")
	if GameManager and GameManager.save_manager and GameManager.save_manager.game_data.has("guns_data"):
		var idx = int(GameManager.save_manager.game_data["guns_data"].get("gun_selected_index", 0))
		if all_guns_res and idx >= 0 and idx < all_guns_res.all_guns.size() and all_guns_res.all_guns[idx]:
			return int(all_guns_res.all_guns[idx].gun_type)
	return 0
