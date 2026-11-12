class_name DailyRewardsConfig
extends Resource

@export var rewards: Array[DailyRewardData] = []


func get_reward_for_day(day: int) -> DailyRewardData:
	if day > 0 and day <= rewards.size():
		return rewards[day - 1]
	return null


func get_reward_count() -> int:
	return rewards.size()
