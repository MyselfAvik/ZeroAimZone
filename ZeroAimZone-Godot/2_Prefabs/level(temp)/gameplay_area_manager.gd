extends Control

@export var empty_area_scene: PackedScene
@export var bouncy_area_scene: PackedScene
@export var obstacle_area_scene: PackedScene

@onready var round_container = $RoundContainer

var current_round = 1
var current_scene : Node

func _ready():
	load_round(1)

func load_round(round_number:int):

	if current_scene:
		current_scene.queue_free()

	match round_number:

		1:
			current_scene = empty_area_scene.instantiate()

		2:
			current_scene = bouncy_area_scene.instantiate()

		3:
			current_scene = obstacle_area_scene.instantiate()

	round_container.add_child(current_scene)
	current_scene.round_finished.connect(_on_round_finished)
func _on_round_finished():

	print("Loading Next Round")

	current_round += 1

	if current_round <= 3:
		load_round(current_round)
	else:
		print("Game Finished")
