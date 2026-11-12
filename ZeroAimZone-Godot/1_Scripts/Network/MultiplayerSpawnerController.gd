class_name MultiplayerSpawnerController
extends MultiplayerSpawner

@export var multiplayer_manager:MultiplayerManager
@onready var camera: Camera2D = $"../Camera2D"
@onready var camera_home: Node = camera.get_parent()
var network_player

var spawned_players=[]
func _ready() -> void:
	network_player=multiplayer_manager.player_gun
	add_spawnable_scene(network_player.resource_path)
	spawn_function = _spawn_custom
	
	spawned.connect(_on_node_spawned)

func spawn_guns(peers: Array, player1pos: Node, player2pos: Node) -> void:
	if not multiplayer.is_server():
		return

	var positions = [player1pos, player2pos]
	for i in min(peers.size(), positions.size()):
		var id  = peers[i]
		var pos = positions[i]
		var data = {
			"peer_id": id,
			"position": pos.global_position,
			"rotation": pos.global_rotation,
			"scale":Vector2(-1, 1) if i==1 else Vector2(1, 1),
			"gun":GameManager.current_match.player_gun_index if i==0 else GameManager.current_match.enemy_gun_index,
			"skin":GameManager.current_match.player_skin_index if i==0 else GameManager.current_match.enemy_skin_index
		
		}
		var player = spawn(data)
		
		if not spawned_players.has(player):
			spawned_players.append(player)
		print("[SPAWN] id=", id, " name=", player.name, " authority=", player.get_multiplayer_authority())
		if id == multiplayer.get_unique_id():
			_attach_camera_to(player)



func _spawn_custom(data: Variant) -> Node:
	var player:MultiplayerGun = network_player.instantiate()
	player.name            = str(data["peer_id"])
	player.global_position = data["position"]
	player.global_rotation = data["rotation"]
	player.scale           = data["scale"]
	player.my_gun_index= data["gun"]
	player.my_skin_index= data["skin"]
	
	return player

func _on_node_spawned(node: Node) -> void:
	if not spawned_players.has(node):
		spawned_players.append(node)
	if node.name == str(multiplayer.get_unique_id()):
		_attach_camera_to(node)
		
func get_player(peer_id: int):
	for p in spawned_players:
		if p.name == str(peer_id):
			return p
	return null
	
func release_camera() -> void:
	if not is_instance_valid(camera) or not is_instance_valid(camera_home):
		return
	var parent = camera.get_parent()
	if parent and parent != camera_home:
		parent.remove_child(camera)
		camera_home.add_child(camera)
func _attach_camera_to(target: Node) -> void:
	if not is_instance_valid(camera):
		push_warning("[SPAWNER] Camera not found!")
		return
	var old_parent = camera.get_parent()
	if old_parent:
		old_parent.remove_child(camera)
	target.add_child(camera)
	camera.position = Vector2.ZERO
	camera.enabled  = true
	print("[CAMERA] Attached to: ", target.name)
