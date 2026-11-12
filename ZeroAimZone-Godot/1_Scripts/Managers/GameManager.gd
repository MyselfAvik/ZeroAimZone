extends IGameSyncHandler
 

var game_flow_manager: GameFlowManager
var in_game_ui: InGameUIManager
var ui_manager: UIManager
var save_manager: SaveManager
var progression_manager: ProgressionManager
var network_handler
var multiplayer_manager: MultiplayerManager
var custom_animation: CustomAnimation
# var gamedata:Dictionary

var cached_peer_info: Dictionary = {}
var cached_match_info: Dictionary = {}

var player_bullet_collider_cache: Array[CollisionPolygon2D] = []
var enemy_bullet_collider_cache: Array[CollisionPolygon2D] = []

func clear_bullet_polygon_caches():
	for c in player_bullet_collider_cache:
		if is_instance_valid(c):
			c.free()
	for c in enemy_bullet_collider_cache:
		if is_instance_valid(c):
			c.free()
	player_bullet_collider_cache.clear()
	enemy_bullet_collider_cache.clear()


var is_rematch := false
var target_main_menu_panel: int = -1
var target_base_sub_panel: int = -1

enum GameState {MAIN_MENU, IN_GAME_SINGLEPLAYER, IN_GAME_MULTIPLAYER}
var current_state: GameState = GameState.MAIN_MENU

var enemy_gun_index: int = 0
var enemy_skin_index: int = 0

var current_match: MatchData = MatchData.new()

const CURRENCY_COLLECTION_ANIMATOR_SCENE = preload("res://ZeroAimZone-Godot/2_Prefabs/UI/CurrencyCollectionAnimator.tscn")
var currency_collection_animator: CurrencyCollectionAnimator

func get_current_arena_name() -> String:
	if current_match:
		match current_match.arena_index:
			0: return "Tokyo"
			1: return "NewYork"
			2: return "Delhi"
			_: return "Arena_%d" % current_match.arena_index
	return "Tokyo"

func set_enemy_gun_info() -> void:
	var player_gun_idx: int = 0
	if save_manager and save_manager.game_data.has("guns_data"):
		player_gun_idx = int(save_manager.game_data["guns_data"].get("gun_selected_index", 0))

	var all_guns_res: AllGunData = preload("res://ZeroAimZone-Godot/4_Resources/Tres/all_gun_data.tres")
	if all_guns_res and player_gun_idx >= 0 and player_gun_idx < all_guns_res.all_guns.size() and all_guns_res.all_guns[player_gun_idx]:
		var player_tier: GunSO.GunType = all_guns_res.all_guns[player_gun_idx].gun_type
		var same_tier_gun_indices: Array[int] = []
		for i in range(all_guns_res.all_guns.size()):
			if all_guns_res.all_guns[i] and all_guns_res.all_guns[i].gun_type == player_tier:
				same_tier_gun_indices.append(i)
		
		if not same_tier_gun_indices.is_empty():
			enemy_gun_index = same_tier_gun_indices.pick_random()
		else:
			enemy_gun_index = player_gun_idx
	else:
		var tier_start: int = (player_gun_idx / 3) * 3
		enemy_gun_index = randi_range(tier_start, mini(tier_start + 2, 8))

	enemy_skin_index = randi_range(0, 2)
	if current_match:
		current_match.enemy_gun_index = enemy_gun_index
		current_match.enemy_skin_index = enemy_skin_index

func _ready() -> void:
	print("Game Manager Initialized")
	get_tree().quit_on_go_back = false
	
	var currency_canvas = CanvasLayer.new()
	currency_canvas.layer = 120
	add_child(currency_canvas)
	currency_collection_animator = CURRENCY_COLLECTION_ANIMATOR_SCENE.instantiate()
	currency_canvas.add_child(currency_collection_animator)
	initialize_game()
	AuthManager.delete_complete.connect(on_delete_complete)

func play_currency_collection(currency_texture: Texture2D, amount: int, source: Control, target_label: Label, is_diamond: bool = false, icon_scale: float = 1.0) -> void:
	if currency_collection_animator:
		currency_collection_animator.collect(currency_texture, amount, source, target_label, is_diamond, icon_scale)

func set_currency_collection_textures(coin_texture: Texture2D, diamond_texture: Texture2D) -> void:
	if currency_collection_animator:
		currency_collection_animator.coin_texture = coin_texture
		currency_collection_animator.diamond_texture = diamond_texture

func on_delete_complete():
	AuthManager.initial_sync_completed.emit(1.0)
	
func format_number(value: int) -> String:
	var abs_val := absi(value)
	var sign_str := "-" if value < 0 else ""
	
	if abs_val >= 1000000000:
		return sign_str + _format_abbreviated(abs_val / 1000000000.0, "B")
	elif abs_val >= 1000000:
		return sign_str + _format_abbreviated(abs_val / 1000000.0, "M")
	elif abs_val >= 1000:
		return sign_str + _format_abbreviated(abs_val / 1000.0, "K")
	else:
		return str(value)

func _format_abbreviated(num: float, suffix: String) -> String:
	var rounded := snappedf(num, 0.01)
	var s := "%.2f" % rounded
	if s.find(".") != -1:
		s = s.rstrip("0").rstrip(".")
	return s + suffix

func initialize_game() -> void:
	initialize_services()
 

# func refresh_gamedata():
# 	gamedata = save_manager.game_data
 
func initialize_services() -> void:
	print("Initializing Services")
 
	save_manager = SaveManager.new()
	add_child(save_manager)
	save_manager.refresh_daily_reward_streak()
	# gamedata = save_manager.game_data
	progression_manager = ProgressionManager.new()
	add_child(progression_manager)
	
	custom_animation = CustomAnimation.new()
	add_child(custom_animation)
   
	# Audio Manager
	# Authentication
	# Cloud Services
	# Ads
 
 
func change_panel(panel):
	if ui_manager:
		ui_manager.enable_panel(panel)
 
 
func show_popup(type):
	if ui_manager:
		ui_manager.popup_panel.show_popup(type)
 
 
# =========================
# Application Handling
# =========================
 
 
# func _notification(what):
 
#   match what:
 
#       NOTIFICATION_APPLICATION_PAUSED:
 
#           pause_game()
 
 
#       NOTIFICATION_APPLICATION_RESUMED:
 
#           resume_game()
 
func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		handle_back_button()

func handle_back_button() -> void:
	if is_instance_valid(in_game_ui):
		if in_game_ui.gameplay_panel.visible:
			return

		if in_game_ui.gameplay_result_panel.visible:
			in_game_ui.gameplay_result_panel._on_back_button_pressed()
			return

		if is_instance_valid(in_game_ui.popup_panel):
			if in_game_ui.popup_panel.is_popup_visible():
				in_game_ui.popup_panel.hide_popup()
				return


	if not is_instance_valid(ui_manager):
		return

	if is_instance_valid(ui_manager.popup_panel):
		if is_instance_valid(ui_manager.popup_panel.update_popup) and ui_manager.popup_panel.update_popup.visible:
			return
		if ui_manager.popup_panel.is_popup_visible():
			ui_manager.popup_panel.hide_popup()
			return

	if ui_manager.arena_selection_panel.visible:
		ui_manager.enable_panel(ui_manager.PanelType.BASE)
		return

	if ui_manager.reward_panel.visible:
		if ui_manager.reward_panel.crate_open_count <= 0:
			ui_manager.reward_panel._on_back_button_pressed()
		return

	if ui_manager.base_panel.visible:
		if ui_manager.base_panel.current_type == ui_manager.base_panel.BasePanelType.PROFILE:
			ui_manager.base_panel.profile_panel._on_back_pressed()
			return

		elif ui_manager.base_panel.current_type == ui_manager.base_panel.BasePanelType.SETTING:
			ui_manager.base_panel.close_setting_panel()
			return

		else:
			ui_manager.popup_panel.show_popup(ui_manager.popup_panel.PopupType.GAMEQUIT)
			return

	return

func quit_game():
	save_game()
 
	get_tree().quit()
 
 
func save_game():
	print("Saving Game Data")


func get_local_progress_for_migration(include_iap := false) -> Dictionary:
	var progress := {
		"stats": AuthData.normalize_game_stats(save_manager.game_data)
	}
	if include_iap:
		progress["iap"] = save_manager.get_iap_data()
	return progress
	
func apply_remote_stats(stats: Dictionary, _is_initial_sync := false) -> void:
	if save_manager == null or AuthManager == null:
		return
	AuthManager._data_store.playerData.gameStats = stats
	save_manager.apply_remote_game_data(stats)


func has_unsynced_data() -> bool:
	if AuthManager != null:
		return AuthManager.has_unsynced_data()
	return false


func push_changes() -> void:
	if AuthManager != null:
		if not AuthManager.is_firestore_data_fetched:
			return
		AuthManager.sync_save_to_firestore()

func apply_remote_iap(_iap: Dictionary) -> void:
## Called after remote IAP data (entitlements/consumables) has been
## fetched from Firestore, so the game can restore purchases locally
## (e.g. on a fresh install or a new device).
	if save_manager == null:
		return
	save_manager.set_iap_data(_iap)



func reset_all_local_data() -> void:
	GameManager.save_manager.initialize_default_data()
	GameManager.save_manager.save_data()
