class_name IGameSyncHandler
extends Node

func get_local_progress_for_migration(include_iap := false) -> Dictionary:
	return {}

func apply_remote_stats(_stats: Dictionary) -> void:
	pass

func apply_remote_iap(_iap: Dictionary) -> void:
	pass

func push_changes() -> void:
	pass

func reset_all_local_data() -> void:
	pass
