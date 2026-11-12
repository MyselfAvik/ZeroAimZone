extends Node
const CHEVRON_BURST_SCENE := preload("res://ZeroAimZone-Godot/3_Assets/obstacles/VFX/BounceEffect.tscn")

var current_arena_color: Color = Color(1, 1, 1, 1)

func set_arena_color(color: Color) -> void:
	current_arena_color = color

func spawn_wall_bounce(wall: Node, level: Node) -> void:
	var spawn_container: Node = null
	if wall.owner and wall.owner.has_node("BounceEffectSpawnPoints"):
		spawn_container = wall.owner.get_node("BounceEffectSpawnPoints")
	elif level and level.has_node("BounceEffectSpawnPoints"):
		spawn_container = level.get_node("BounceEffectSpawnPoints")
	elif wall.get_parent() and wall.get_parent().get_parent() and wall.get_parent().get_parent().has_node("BounceEffectSpawnPoints"):
		spawn_container = wall.get_parent().get_parent().get_node("BounceEffectSpawnPoints")
	elif wall.has_node("../BounceEffectSpawnPoints"):
		spawn_container = wall.get_node("../BounceEffectSpawnPoints")
	elif wall.has_node("../../BounceEffectSpawnPoints"):
		spawn_container = wall.get_node("../../BounceEffectSpawnPoints")

	if not spawn_container:
		push_error("BounceEffectSpawnPoints not found")
		return

	var marker_names: Array[String] = []
	var rotations: Array[float] = []
	var wall_name = wall.name
	if wall_name == "Collider" and wall.get_parent():
		wall_name = wall.get_parent().name
	if "Bottom" in wall_name:
		wall_name = "Bottom"
	elif "Top" in wall_name:
		wall_name = "Top"
	elif "Left" in wall_name:
		wall_name = "Left"
	elif "Right" in wall_name:
		wall_name = "Right"

	match wall_name:
		"Left":
			marker_names = ["LeftMarkerUp", "LeftMarkerDown"]
			rotations = [0, 180]
		"Right":
			marker_names = ["RightMarkerUp", "RightMarkerDown"]
			rotations = [0, 180]
		"Top":
			marker_names = ["TopMarkerLeft", "TopMarkerRight"]
			rotations = [-90, 90]
		"Bottom":
			marker_names = ["BottomMarkerLeft", "BottomMarkerRight"]
			rotations = [-90, 90]
		_:
			push_error("Unknown wall name: " + wall.name)
			return

	for i in marker_names.size():
		var marker = spawn_container.get_node_or_null(marker_names[i])
		if not marker:
			push_error("Marker not found: " + marker_names[i])
			continue
		_spawn_burst(spawn_container, marker.global_position, rotations[i])

func _spawn_burst(parent: Node, pos: Vector2, rot_degrees: float) -> void:
	var burst := CHEVRON_BURST_SCENE.instantiate()
	burst.z_index = 20
	parent.add_child(burst)
	burst.global_position = pos
	burst.rotation_degrees = rot_degrees
	burst.scale = Vector2(0.5, 0.5)
	burst.set_burst_color(current_arena_color)
	burst.play()
