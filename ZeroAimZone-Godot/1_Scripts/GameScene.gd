extends Node2D

@export var single_player_controller: PackedScene = preload("res://ZeroAimZone-Godot/0_Scenes/SinglePlayer.tscn")
@export var multiplayer_controller: PackedScene

@onready var controllers_node: Node2D = $Controllers

func _enter_tree() -> void:
	# For multiplayer, add the controller node as early as possible so
	# incoming RPCs can resolve "GameScene/Controllers/Multiplayer" on
	# the client before _ready() fires.
	if GameManager.current_state == GameManager.GameState.IN_GAME_MULTIPLAYER:
		var ctrl_node = get_node_or_null("Controllers")
		if ctrl_node:
			_start_multiplayer(ctrl_node)

func _ready() -> void:
	AudioPlayer.start_bg_music(AudioPlayer.SOUND_DB.game_theme)

	match GameManager.current_state:
		GameManager.GameState.IN_GAME_SINGLEPLAYER:
			_start_singleplayer()
		GameManager.GameState.IN_GAME_MULTIPLAYER:
			# Already added in _enter_tree
			pass

func _start_singleplayer() -> void:
	if single_player_controller:
		var instance = single_player_controller.instantiate()
		controllers_node.add_child(instance)

func _start_multiplayer(parent_node: Node = null) -> void:
	if parent_node == null:
		parent_node = controllers_node
	# Avoid adding twice if already present
	if parent_node.has_node("Multiplayer"):
		return
	var controller = multiplayer_controller
	if not controller:
		controller = load("res://ZeroAimZone-Godot/0_Scenes/Multiplayer.tscn")
	if controller:
		var instance = controller.instantiate()
		instance.name = "Multiplayer"
		parent_node.add_child(instance)
	else:
		printerr("GameScene: multiplayer_controller scene not found!")
