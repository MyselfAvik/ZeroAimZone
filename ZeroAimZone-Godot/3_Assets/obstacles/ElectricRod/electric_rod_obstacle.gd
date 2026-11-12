class_name ElectricRodObstacle
extends ObstacleController

@export var rod_scene: PackedScene
@export var activation_time: float = 1.0
@export var cooldown_time: float = 0.3

var rods: Array[ElectricRodPiece] = []
var is_running := true

func initialize(level: Node) -> void:

	var spawn_points: Array[Marker2D] = []

	var container = level.get_node("ObstacleSpawnPoints")

	for child in container.get_children():
		if child is Marker2D and child.name.begins_with("RodSpawn"):
			spawn_points.append(child)                         

	spawn_rods(spawn_points)

	call_deferred("activation_loop")

func stop() -> void:
	is_running = false

func _exit_tree() -> void:
	stop()

func _on_rod_hit(rod: ElectricRodPiece, body: Node) -> void:
	obstacle_hit.emit(self, body)
	if body.has_method("apply_impact"):
		body.apply_impact(rod.damage, rod.global_position, rod.knockback, rod.torque, rod.stun_time)

func activation_loop() -> void:
	while is_running:
		for rod in rods:
			if !is_running: return
			rod.activate()
			await get_tree().create_timer(activation_time).timeout
			if !is_running: return
			rod.deactivate()
			await get_tree().create_timer(cooldown_time).timeout

func spawn_rods(spawn_points: Array[Marker2D]) -> void:
	var rotations = [0, 90, 180, -90]
	for i in range(spawn_points.size()):
		var rod = rod_scene.instantiate() as ElectricRodPiece
		get_parent().add_child(rod)
		rod.global_position = spawn_points[i].global_position
		rod.rotation_degrees = rotations[i]
		rod.rod_hit.connect(_on_rod_hit)
		rods.append(rod)
