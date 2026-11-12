class_name UIManager
extends CanvasLayer

signal terms_and_condition_accepted(val:bool)

@export var base_panel: BasePanelController
@export var arena_selection_panel: ArenaSelectionPanelController
@export var popup_panel: PopupPanelController
@export var match_making_panel: MatchMakingController
@export var reward_panel: RewardPanelController
@export var loading_panel: LoadingPanelController

var currency_collection_animator: CurrencyCollectionAnimator

enum PanelType {
	LOADING,
	BASE,
	ARENA,
	MATCHMAKING,
	REWARD
}

var panel_map = {
	
}
func _enter_tree() -> void:
	GameManager.ui_manager = self


func _ready() -> void:
	panel_map = {
		PanelType.BASE: base_panel,
		PanelType.ARENA: arena_selection_panel,
		PanelType.MATCHMAKING: match_making_panel,
		PanelType.REWARD: reward_panel,
		PanelType.LOADING: loading_panel
	}
	enable_panel(PanelType.LOADING)
	if not PlayerPrefs.get_bool("terms_accepted", false):
		popup_panel.show_popup(PopupPanelController.PopupType.TC)

	if AuthManager:
		if not AuthManager.remote_config_received.is_connected(_on_remote_config_received):
			AuthManager.remote_config_received.connect(_on_remote_config_received)
		if not AuthManager.remote_config_data.is_empty():
			_on_remote_config_received(AuthManager.remote_config_data)

func _on_remote_config_received(config: Dictionary) -> void:
	if not config:
		return
	var version_key := "latest_version_ios" if OS.get_name() == "iOS" else "latest_version_android"
	if config.has(version_key):
		var latest_ver := str(config.get(version_key, "")).strip_edges()
		var current_ver := str(ProjectSettings.get_setting("application/config/version", "1.0.0")).strip_edges()
		if is_version_newer(latest_ver, current_ver):
			print("[VersionCheck] Outdated %s app version (Current: %s, Required: %s). Forcing update popup." % [OS.get_name(), current_ver, latest_ver])
			popup_panel.show_popup(PopupPanelController.PopupType.UPDATE)

static func is_version_newer(latest_ver: String, current_ver: String) -> bool:
	if latest_ver.is_empty():
		return false
	var latest_parts := latest_ver.split(".")
	var current_parts := current_ver.split(".")
	var max_len := maxi(latest_parts.size(), current_parts.size())
	for i in range(max_len):
		var v_latest := int(latest_parts[i]) if i < latest_parts.size() and latest_parts[i].is_valid_int() else 0
		var v_curr := int(current_parts[i]) if i < current_parts.size() and current_parts[i].is_valid_int() else 0
		if v_latest > v_curr:
			return true
		elif v_latest < v_curr:
			return false
	return false
	


func enable_panel(type: PanelType):
	var was_base_visible: bool = is_instance_valid(base_panel) and base_panel.visible

	for p in panel_map.values():
		p.hide()

	panel_map[type].show()
	if type == PanelType.MATCHMAKING:
		if was_base_visible:
			GameAnalysis.track_screen_switch("Home", "Matchmaking")
	elif type == PanelType.BASE:
		AdManager.show_banner()
		if GameManager and GameManager.target_base_sub_panel != -1 and is_instance_valid(base_panel):
			var target_sub = GameManager.target_base_sub_panel as BasePanelController.BasePanelType
			GameManager.target_base_sub_panel = -1
			base_panel.switch_panel(target_sub, false, false)
		elif is_instance_valid(base_panel) and is_instance_valid(base_panel.home_panel):
			base_panel.home_panel.refresh_slots()
	elif type == PanelType.ARENA:
		AdManager.show_banner()
	elif type == PanelType.LOADING:
		AdManager.hide_banner()
