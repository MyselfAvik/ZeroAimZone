class_name SlidingWallObstacle
extends ObstacleController


@export var move_distance := 300.0
@export var move_duration := 2.0


var center_position: Vector2
var left_position: Vector2
var right_position: Vector2

var is_running := true
var movement_tween: Tween


func initialize(level: Node) -> void:
	print(level)
	var marker = level.get_node("StaticObstacle")
	#global_position = marker.global_position
	#center_position = marker.global_position
#
	#left_position = center_position + Vector2(-move_distance, 0)
	#right_position = center_position + Vector2(move_distance, 0)
#
	#global_position = center_position
#
	#start_movement()
	if marker ==null:
		push_error("marker not found")
		return
	#print("Marker global position :", marker.global_position)
	center_position= marker.global_position
	left_position =center_position+Vector2(-move_distance, 0)
	right_position =center_position+Vector2(move_distance, 0)
	position= center_position
	#print("Obstacle global_position after set:" , global_position)
	start_movement()
	
func start_movement() -> void:
	while is_running:

		await move_to(left_position)

		if not is_running:
			return

		await move_to(right_position)

		if not is_running:
			return


func move_to(target_position: Vector2) -> void:
	movement_tween = create_tween()

	movement_tween.set_trans(Tween.TRANS_SINE)
	movement_tween.set_ease(Tween.EASE_IN_OUT)

	movement_tween.tween_property(
		self,
		"global_position",
		target_position,
		move_duration
	)

	await movement_tween.finished


func stop() -> void:
	is_running = false

	if movement_tween and movement_tween.is_running():
		movement_tween.kill()
