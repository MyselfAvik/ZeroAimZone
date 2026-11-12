extends Control

signal round_finished

@export var test_ball_scene : PackedScene

@onready var ball_spawn = $Panel/Node2D/TestBallSpawn

func _ready():
	spawn_ball()

func spawn_ball():

	var ball = test_ball_scene.instantiate()

	ball.global_position = ball_spawn.global_position

	#get_tree().current_scene.
	add_child(ball)
	
func _input(event):

	if event.is_action_pressed("ui_accept"):
		print("Obstacle Round Finished")
		round_finished.emit()
