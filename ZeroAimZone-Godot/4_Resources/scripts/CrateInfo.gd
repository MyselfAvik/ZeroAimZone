@tool
class_name CrateInfo
extends Resource

@export var crate_type: ProgressionManager.CRATE_TYPE
@export var unlock_times_minutes: int
@export var min_reward_item: int
@export var max_reward_item: int
@export var chest_icon:Texture
@export var chest_open_glow_texture: Texture
@export var chest_empty_texture: Texture
@export var glow_texture: Texture
@export var rewards: Array[CrateReward]
var gun_type_for_reward:int

func get_rewards(gun_type:int) -> Array[Dictionary]:
	gun_type_for_reward = gun_type
	var result: Array[Dictionary] = []

	var reward_count := randi_range(min_reward_item, max_reward_item)
	
	var sim_unlocked: Array = []
	var sim_cards: Array = []
	if GameManager and GameManager.save_manager and GameManager.save_manager.game_data.has("guns_data"):
		sim_unlocked = GameManager.save_manager.game_data["guns_data"].get("guns_unlocked", []).duplicate()
		sim_cards = GameManager.save_manager.game_data["guns_data"].get("cards_collected", []).duplicate()

	var used_reward_types: Array[int] = []
	for i in reward_count:
		var picked_rewards = _pick_reward(sim_unlocked, sim_cards, used_reward_types)
		if picked_rewards.is_empty():
			# Fallback if nothing picked: provide a standard coin bundle
			picked_rewards = [{
				"key": CrateReward.Contains.COIN,
				"value": randi_range(40, 80)
			}]
		result.append_array(picked_rewards)

	return result

func _is_tier_unlocked(guns_unlocked: Array, target_tier: int) -> bool:
	if guns_unlocked.is_empty():
		return false
	var all_gun_data: AllGunData = load("res://ZeroAimZone-Godot/4_Resources/Tres/all_gun_data.tres")
	if not all_gun_data or all_gun_data.all_guns.is_empty():
		return false
	for i in range(mini(guns_unlocked.size(), all_gun_data.all_guns.size())):
		if all_gun_data.all_guns[i] and int(all_gun_data.all_guns[i].gun_type) == target_tier:
			if not bool(guns_unlocked[i]):
				return false
	return true

func _are_all_guns_unlocked(guns_unlocked: Array) -> bool:
	if guns_unlocked.is_empty():
		return false
	for unlocked in guns_unlocked:
		if not bool(unlocked):
			return false
	return true


func _pick_reward(sim_unlocked: Array, sim_cards: Array, used_types: Array[int]) -> Array[Dictionary]:
	if rewards.is_empty():
		return []

	var eligible_rewards: Array[CrateReward] = []
	var total_weight := 0.0

	# First pass: try to pick an unused reward category
	for reward in rewards:
		if used_types.has(reward.contains):
			continue
		eligible_rewards.append(reward)
		total_weight += reward.probability_to_get

	# Fallback pass: if all unique categories were already used, allow Coin or Diamond bundles only (never guncards again)
	if eligible_rewards.is_empty() or total_weight <= 0.0:
		for reward in rewards:
			if reward.contains == CrateReward.Contains.COIN or reward.contains == CrateReward.Contains.DIAMOND:
				eligible_rewards.append(reward)
				total_weight += reward.probability_to_get

	if eligible_rewards.is_empty() or total_weight <= 0.0:
		return [{
			"key": CrateReward.Contains.COIN,
			"value": randi_range(40, 80)
		}]

	var random_weight := randf_range(0.0, total_weight)
	var current_weight := 0.0

	for reward in eligible_rewards:
		current_weight += reward.probability_to_get
		if random_weight <= current_weight:
			if not used_types.has(reward.contains):
				used_types.append(reward.contains)
			return _create_reward(reward, sim_unlocked, sim_cards)

	var fallback_reward = eligible_rewards[0]
	if not used_types.has(fallback_reward.contains):
		used_types.append(fallback_reward.contains)
	return _create_reward(fallback_reward, sim_unlocked, sim_cards)


func _create_reward(reward: CrateReward, sim_unlocked: Array, sim_cards: Array) -> Array[Dictionary]:
	match reward.contains:
		CrateReward.Contains.COIN:
			return [{
				"key": reward.contains,
				"value": randi_range(reward.min_coin, reward.max_coin)
			}]

		CrateReward.Contains.DIAMOND:
			return [{
				"key": reward.contains,
				"value": randi_range(reward.min_diamond, reward.max_diamond)
			}]

		CrateReward.Contains.GUNCARD:
			var gun_idx = pick_locked_gun(sim_unlocked)
			if gun_idx == -1:
				# All guns in this tier are unlocked: roll a gun from this tier to animate, then convert to 100 coins
				var display_gun_idx = pick_any_gun_in_tier()
				return [{
					"key": CrateReward.Contains.GUNCARD,
					"value": {
						"gun_index": display_gun_idx,
						"cards_amount": 1,
						"converted_to_coins": 100
					}
				}]

			var cards_amount = randi_range(reward.min_cards, reward.max_cards)
			var all_gun_data: AllGunData = load("res://ZeroAimZone-Godot/4_Resources/Tres/all_gun_data.tres")

			if gun_idx >= 0 and gun_idx < sim_cards.size():
				var cards_needed = all_gun_data.all_guns[gun_idx].cards_needed if all_gun_data and gun_idx < all_gun_data.all_guns.size() and all_gun_data.all_guns[gun_idx] else 10
				var current_cards = sim_cards[gun_idx]
				var remaining_needed = maxi(1, cards_needed - current_cards)
				cards_amount = mini(cards_amount, remaining_needed)

				sim_cards[gun_idx] += cards_amount
				if sim_cards[gun_idx] >= cards_needed:
					sim_unlocked[gun_idx] = true

			return [{
				"key": reward.contains,
				"value": {"gun_index": gun_idx, "cards_amount": cards_amount}
			}]

		CrateReward.Contains.AVATAR:
			var avatar_idx = pick_avatar()
			if avatar_idx == -1:
				var display_avatar_idx = pick_any_avatar()
				return [{
					"key": CrateReward.Contains.AVATAR,
					"value": display_avatar_idx,
					"converted_to_coins": 50
				}]
			return [{
				"key": reward.contains,
				"value": avatar_idx
			}]

		CrateReward.Contains.FRAME:
			var frame_idx = pick_frame()
			if frame_idx == -1:
				var display_frame_idx = pick_any_frame()
				return [{
					"key": CrateReward.Contains.FRAME,
					"value": display_frame_idx,
					"converted_to_coins": 50
				}]
			return [{
				"key": reward.contains,
				"value": frame_idx
			}]

		# CrateReward.Contains.SKIN:
		# 	return [{
		# 		"key": reward.contains,
		# 		"value": pick_skin()
		# 	}]

	return []
	
func pick_avatar() -> int:
	if not GameManager or not GameManager.save_manager or not GameManager.save_manager.game_data.has("player_data"):
		return -1
	var avatars: Array = GameManager.save_manager.game_data["player_data"].get("avatar_unlocked", [])
	var available_avatar: Array[int] = []
	for i in range(avatars.size()):
		if !avatars[i]:
			available_avatar.append(i)
	if available_avatar.is_empty():
		return -1
	return available_avatar.pick_random()

func pick_any_avatar() -> int:
	if GameManager and GameManager.save_manager and GameManager.save_manager.game_data.has("player_data"):
		var avatars: Array = GameManager.save_manager.game_data["player_data"].get("avatar_unlocked", [])
		if not avatars.is_empty():
			return randi_range(0, avatars.size() - 1)
	return 0
	
func pick_frame() -> int:
	if not GameManager or not GameManager.save_manager or not GameManager.save_manager.game_data.has("player_data"):
		return -1
	var frames: Array = GameManager.save_manager.game_data["player_data"].get("frame_unlocked", [])
	var available_frame: Array[int] = []
	for i in range(frames.size()):
		if !frames[i]:
			available_frame.append(i)
	if available_frame.is_empty():
		return -1
	return available_frame.pick_random()

func pick_any_frame() -> int:
	if GameManager and GameManager.save_manager and GameManager.save_manager.game_data.has("player_data"):
		var frames: Array = GameManager.save_manager.game_data["player_data"].get("frame_unlocked", [])
		if not frames.is_empty():
			return randi_range(0, frames.size() - 1)
	return 0

func pick_skin() -> Dictionary:
	var available_skins: Array = []

	for gun_index in range(GameManager.save_manager.game_data["guns_data"]["skins_unlocked"].size()):
		for skin_index in range(GameManager.save_manager.game_data["guns_data"]["skins_unlocked"][gun_index].size()):
			if !GameManager.save_manager.game_data["guns_data"]["skins_unlocked"][gun_index][skin_index]:
				available_skins.append({
					"gun_index": gun_index,
					"skin_index": skin_index
				})

	if available_skins.is_empty():
		return {}

	return available_skins.pick_random()


func pick_locked_gun(guns_unlocked: Array) -> int:
	if guns_unlocked.is_empty():
		return -1

	var all_gun_data: AllGunData = load("res://ZeroAimZone-Godot/4_Resources/Tres/all_gun_data.tres")
	if not all_gun_data or all_gun_data.all_guns.is_empty():
		return -1

	# Find all locked guns that match the exact target tier of the playing gun
	var target_tier_locked: Array[int] = []
	for i in range(mini(guns_unlocked.size(), all_gun_data.all_guns.size())):
		if not bool(guns_unlocked[i]):
			if all_gun_data.all_guns[i] and int(all_gun_data.all_guns[i].gun_type) == gun_type_for_reward:
				target_tier_locked.append(i)

	if not target_tier_locked.is_empty():
		return target_tier_locked.pick_random()

	# If all guns in this tier are unlocked, return -1
	return -1

func pick_any_gun_in_tier() -> int:
	var all_gun_data: AllGunData = load("res://ZeroAimZone-Godot/4_Resources/Tres/all_gun_data.tres")
	if not all_gun_data or all_gun_data.all_guns.is_empty():
		return 0
	var matching_tier_guns: Array[int] = []
	for i in range(all_gun_data.all_guns.size()):
		if all_gun_data.all_guns[i] and int(all_gun_data.all_guns[i].gun_type) == gun_type_for_reward:
			matching_tier_guns.append(i)
	if not matching_tier_guns.is_empty():
		return matching_tier_guns.pick_random()
	return 0
