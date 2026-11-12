class_name ZigZagWallsObstacle
extends ObstacleController

@export var wall_scene: PackedScene
@export var move_speed := 150.0

class WallData:
	var node: Node2D
	var direction: int  # 1 = right, -1 = left
	var detector: Area2D

var wall_data: Array[WallData] = []
var is_running := true

func initialize(level: Node) -> void:
	var spawn_points := get_spawn_points(level)
	if spawn_points.is_empty():
		push_error("No spawn points found for ZigZagWallsObstacle")
		return
	spawn_walls(spawn_points)
	set_physics_process(true)

func get_spawn_points(level: Node) -> Array[Marker2D]:
	var points: Array[Marker2D] = []
	var container = level.get_node_or_null("ZigZagSpawnPoints")
	if container:
		for child in container.get_children():
			if child is Marker2D:
				points.append(child)
	return points

func spawn_walls(spawn_points: Array[Marker2D]) -> void:
	for i in range(spawn_points.size()):
		var point = spawn_points[i]
		var wall = wall_scene.instantiate() as Node2D
		get_parent().add_child(wall)
		wall.global_position = point.global_position
		wall.global_rotation = point.global_rotation

		var data = WallData.new()
		data.node = wall
		data.direction = 1 if (i % 2 == 0) else -1

		var detector = wall.get_node_or_null("BoundsDetector") as Area2D
		if detector:
			detector.monitoring = true
			detector.body_entered.connect(_on_wall_touched_bound.bind(data))
		data.detector = detector

		wall_data.append(data)

func _physics_process(delta: float) -> void:
	if not is_running:
		return
	for data in wall_data:
		if is_instance_valid(data.node):
			data.node.global_position.x += data.direction * move_speed * delta

#func _on_wall_touched_bound(body: Node, data: WallData) -> void:
	#if body.is_in_group("play_area_bounds"):  # tag your Left/Right walls with this group
		#data.direction *= -1
		
func _on_wall_touched_bound(body: Node, data: WallData) -> void:
	print("Touched: ", body.name, " | group check: ", body.is_in_group("play_area_bounds"))
	if body.is_in_group("play_area_bounds"):
		data.direction *= -1
		
		
		

func stop() -> void:
	is_running = false
	set_physics_process(false)
	for data in wall_data:
		if is_instance_valid(data.node):
			data.node.queue_free()
	wall_data.clear()

func _exit_tree() -> void:
	stop()
