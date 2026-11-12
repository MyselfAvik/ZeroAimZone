extends Control

@export var min_top_offset_ios: float = 180
@export var min_top_offset_tablet: float = 45
@export var is_gameplay: bool = false

func _ready() -> void:
	anchors_preset = PRESET_FULL_RECT
	apply_safe_area()
	get_viewport().size_changed.connect(apply_safe_area)
	visibility_changed.connect(apply_safe_area)
	if GameManager and GameManager.save_manager:
		if not GameManager.save_manager.player_info_updated.is_connected(apply_safe_area):
			GameManager.save_manager.player_info_updated.connect(apply_safe_area)

func _has_remove_ads() -> bool:
	if GameManager and GameManager.save_manager:
		return GameManager.save_manager.has_remove_ads()
	return false

func apply_safe_area() -> void:
	if not OS.has_feature("mobile"):
		offset_left = 0
		offset_top = 0
		offset_right = 0
		offset_bottom = 0
		return

	var safe := DisplayServer.get_display_safe_area()
	var screen := DisplayServer.screen_get_size()
	var viewport := get_viewport_rect().size
	var _scale := Vector2(
		viewport.x / screen.x,
		viewport.y / screen.y
	)
	offset_left = safe.position.x * _scale.x
	var off_top = safe.position.y * _scale.y
	
	var max_dim := maxf(screen.x, screen.y)
	var min_dim := minf(screen.x, screen.y)
	var aspect_ratio := max_dim / min_dim if min_dim > 0 else 2.0
	var model_name := OS.get_model_name().to_lower()
	var is_tablet := model_name.contains("ipad") or model_name.contains("tablet") or model_name.contains("tab") or model_name.contains("pad") or aspect_ratio <= 1.85

	var parent_node = get_parent()
	var in_gameplay = is_gameplay or (parent_node and (parent_node.name == "GamePlayPanel" or parent_node is GamePlayPanelController))
	var remove_ads_active = _has_remove_ads()
	var min_top = min_top_offset_tablet if is_tablet else min_top_offset_ios

	offset_right = -(screen.x - safe.end.x) * _scale.x
	if in_gameplay:
		offset_top = off_top
		offset_bottom = 0.0 if (OS.get_name() == "iOS" or is_tablet) else -(screen.y - safe.end.y) * _scale.y
	elif OS.get_name() == "iOS":
		if is_tablet:
			offset_top = 0.0 if remove_ads_active else clamp(off_top, min_top, 1000.0)
			offset_bottom = 0.0
		else:
			offset_top = off_top if remove_ads_active else clamp(off_top, min_top, 1000.0)
			offset_bottom = 0.0
	else:
		# Android & other platforms
		if remove_ads_active:
			offset_top = 0.0
		else:
			offset_top = clamp(off_top, min_top, 1000.0)
		offset_bottom = 0.0 if is_tablet else -(screen.y - safe.end.y) * _scale.y
