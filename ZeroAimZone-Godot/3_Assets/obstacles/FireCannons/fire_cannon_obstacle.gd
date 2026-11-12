class_name FireCannonsObstacle
extends ObstacleController

@export var cannon_scene: PackedScene
@export var initial_delay := 1.5   
@export var off_time := 2.0
@export var fire_time := 2.5

var cannons: Array[FireCannonPiece] = []
var is_running := true

func initialize(level: Node) -> void:
	var spawn_points := get_spawn_points(level)
	spawn_cannons(spawn_points)
	call_deferred("cycle_loop")

func get_spawn_points(level: Node) -> Array[Marker2D]:
	var points: Array[Marker2D] = []
	var container = level.get_node_or_null("Cannonpoints")
	if container:
		for child in container.get_children():
			if child is Marker2D:
				points.append(child)
	return points

func stop() -> void:
	is_running = false

func _exit_tree() -> void:
	stop()

func spawn_cannons(spawn_points: Array[Marker2D]) -> void:
	for point in spawn_points:
		var cannon = cannon_scene.instantiate() as FireCannonPiece
		get_parent().add_child(cannon)
		cannon.global_position = point.global_position
		cannon.global_rotation = point.global_rotation
		cannon.cannon_fired.connect(_on_cannon_fired)
		cannons.append(cannon)

func _on_cannon_fired(cannon: FireCannonPiece, body: Node) -> void:
	obstacle_hit.emit(self, body)
	if body.has_method("apply_impact"):
		body.apply_impact(cannon.damage, cannon.global_position, cannon.knockback, cannon.torque, cannon.stun_time)

func cycle_loop() -> void:
	for c in cannons:
		c.stop_firing()

	await get_tree().create_timer(initial_delay).timeout
	if !is_running: return

	var current_index := 0
	while is_running:
		var active_cannon = cannons[current_index]

		active_cannon.start_firing()
		await get_tree().create_timer(fire_time).timeout
		if !is_running: return
		active_cannon.stop_firing()

		await get_tree().create_timer(off_time).timeout
		if !is_running: return

		current_index = (current_index + 1) % cannons.size()
