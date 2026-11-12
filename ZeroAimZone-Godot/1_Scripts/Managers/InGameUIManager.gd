extends CanvasLayer
class_name InGameUIManager

var active_panels: Dictionary = {}
var preloaded_panels: Dictionary = {}
var currency_collection_animator: CurrencyCollectionAnimator

const CURRENCY_COLLECTION_ANIMATOR_SCENE = preload("res://ZeroAimZone-Godot/2_Prefabs/UI/CurrencyCollectionAnimator.tscn")
const GAMEPLAY_PANEL_PATH = "res://ZeroAimZone-Godot/2_Prefabs/UI/Panels/GamePlayPanel.tscn"
const RESULT_PANEL_PATH = "res://ZeroAimZone-Godot/2_Prefabs/UI/Panels/GamePlayResultPanel.tscn"
const POPUP_PANEL_PATH = "res://ZeroAimZone-Godot/2_Prefabs/UI/Panels/PopupPanel.tscn"
const MATCHMAKING_PANEL_PATH = "res://ZeroAimZone-Godot/2_Prefabs/UI/Panels/MatchMakingPanel.tscn"

const GAMEPLAY_PANEL_SCENE = preload("res://ZeroAimZone-Godot/2_Prefabs/UI/Panels/GamePlayPanel.tscn")
const RESULT_PANEL_SCENE = preload("res://ZeroAimZone-Godot/2_Prefabs/UI/Panels/GamePlayResultPanel.tscn")
const POPUP_PANEL_SCENE = preload("res://ZeroAimZone-Godot/2_Prefabs/UI/Panels/PopupPanel.tscn")
const MATCHMAKING_PANEL_SCENE = preload("res://ZeroAimZone-Godot/2_Prefabs/UI/Panels/MatchMakingPanel.tscn")


var gameplay_panel: GamePlayPanelController:
	get: return open_panel(GAMEPLAY_PANEL_PATH) as GamePlayPanelController

var gameplay_result_panel: GamePlayResultController:
	get: return open_panel(RESULT_PANEL_PATH) as GamePlayResultController

var popup_panel: PopupPanelController:
	get: return open_panel(POPUP_PANEL_PATH) as PopupPanelController

var match_making_panel: MatchMakingController:
	get: return open_panel(MATCHMAKING_PANEL_PATH) as MatchMakingController

var instantiating_panels: Dictionary = {}


func _init() -> void:
	preloaded_panels = {
		POPUP_PANEL_PATH: POPUP_PANEL_SCENE,
		GAMEPLAY_PANEL_PATH: GAMEPLAY_PANEL_SCENE,
		RESULT_PANEL_PATH: RESULT_PANEL_SCENE,
		MATCHMAKING_PANEL_PATH: MATCHMAKING_PANEL_SCENE,
	}
	currency_collection_animator = CURRENCY_COLLECTION_ANIMATOR_SCENE.instantiate()
	add_child(currency_collection_animator)


func _enter_tree() -> void:
	GameManager.in_game_ui = self
	AdManager.hide_banner()

func _exit_tree() -> void:
	if GameManager.in_game_ui == self:
		GameManager.in_game_ui = null

func _ready() -> void:
	# Pre-instantiate popup panel and result panel during scene load so there's no frame drop mid-game
	var popup = open_panel(POPUP_PANEL_PATH)
	if is_instance_valid(popup):
		popup.hide()

	var result_panel = open_panel(RESULT_PANEL_PATH)
	if is_instance_valid(result_panel):
		result_panel.hide()

func open_panel(panel_path: String) -> Control:
	if active_panels.has(panel_path):
		var panel = active_panels[panel_path]
		if is_instance_valid(panel):
			return panel
		else:
			active_panels.erase(panel_path)
			
	if instantiating_panels.has(panel_path):
		return null
		
	var packed_scene: PackedScene
	
	if preloaded_panels.has(panel_path):
		packed_scene = preloaded_panels[panel_path]
	else:
		packed_scene = load(panel_path)
		
	if packed_scene:
		instantiating_panels[panel_path] = true
		var panel_instance = packed_scene.instantiate() as Control
		instantiating_panels.erase(panel_path)
		
		if is_instance_valid(panel_instance):
			panel_instance.name = panel_path.get_file().get_basename()
			active_panels[panel_path] = panel_instance
			add_child(panel_instance)
		return panel_instance
		
	printerr("InGameUIManager: Failed to load panel at path ", panel_path)
	return null

func close_panel(panel_path: String) -> void:
	if active_panels.has(panel_path):
		var panel = active_panels[panel_path]
		if is_instance_valid(panel):
			panel.queue_free()
		active_panels.erase(panel_path)

func hide_all_panels() -> void:
	for path in active_panels:
		if is_instance_valid(active_panels[path]):
			active_panels[path].hide()

func show_gameplay() -> void:
	hide_all_panels()
	gameplay_panel.show()
	AdManager.hide_banner()
	

func show_result() -> void:
	hide_all_panels()
	gameplay_result_panel.show()
	AdManager.show_banner()
	AdManager.on_game_completed()
