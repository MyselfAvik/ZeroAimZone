class_name MultiplayerBullet
extends Area2D

const DEFAULT_HIT_EFFECT := preload("res://ZeroAimZone-Godot/3_Assets/obstacles/StaticWall/HitEffect.tscn")

@export var speed: float = 2250.0
@export var hit_effect_scene: PackedScene
## Assigned by the firing gun before this bullet enters the scene tree.  This
## lets each peer create the trail that belongs to the gun/skin that fired,
## instead of relying on the local player's currently equipped selection.
var bullet_trail_scene: PackedScene
var velocity: Vector2
var self_id: String
var damage: int
var has_hit := false
var bounce_count := 0
var max_bounce := 1
var arena_bounds := Rect2()
var has_arena_bounds := false
var bullet_visual: Sprite2D
var collision_polygon: CollisionPolygon2D
var gun_instance: Node = null

func configure_from_gun_skin(texture: Texture = null, trail_scene: PackedScene = null, p_gun_instance: Node = null) -> void:
	bullet_trail_scene = trail_scene
	configure_bullet_texture(texture, p_gun_instance)

func configure_bullet_texture(texture = null, p_gun_instance = null) -> void:
	_resolve_visual_nodes()
	if p_gun_instance != null:
		gun_instance = p_gun_instance
	if texture != null:
		bullet_visual.texture = texture
		
	if gun_instance == null and is_inside_tree() and "self_id" in self and str(self_id) != "":
		gun_instance = get_tree().get_root().find_child(str(self_id), true, false)
	
	if gun_instance != null and "_cached_bullet_polygon" in gun_instance and not gun_instance._cached_bullet_polygon.is_empty():
		collision_polygon.polygon = gun_instance._cached_bullet_polygon
		collision_polygon.transform = bullet_visual.transform
		return
		
	_generate_collision_from_texture()
	
	if gun_instance != null and "_cached_bullet_polygon" in gun_instance:
		gun_instance._cached_bullet_polygon = collision_polygon.polygon

func _resolve_visual_nodes() -> void:
	if bullet_visual == null:
		bullet_visual = get_node("BulletVisual") as Sprite2D
	if collision_polygon == null:
		collision_polygon = get_node("CollisionPolygon2D") as CollisionPolygon2D

func _generate_collision_from_texture() -> void:
	_resolve_visual_nodes()
	if not bullet_visual.texture:
		collision_polygon.polygon = PackedVector2Array()
		return
	var texture = bullet_visual.texture
	var image: Image
	
	if texture is AtlasTexture:
		var base_texture = texture.atlas
		if not base_texture:
			collision_polygon.polygon = PackedVector2Array()
			return
		var base_image = base_texture.get_image()
		if not base_image:
			collision_polygon.polygon = PackedVector2Array()
			return
		if base_image.is_compressed():
			base_image.decompress()
		var region = texture.region
		image = Image.create_empty(int(region.size.x), int(region.size.y), false, base_image.get_format())
		image.blit_rect(base_image, region, Vector2i.ZERO)
	else:
		image = texture.get_image()
	if not image:
		collision_polygon.polygon = PackedVector2Array()
		return
	if image.is_compressed():
		image.decompress()
	var bitmap := BitMap.new()
	bitmap.create_from_image_alpha(image, 0.1)
	# Increased epsilon to 5.0 to make the polygon less detailed and save performance
	var polygons := bitmap.opaque_to_polygons(Rect2(Vector2.ZERO, image.get_size()), 5.0)
	if polygons.is_empty():
		collision_polygon.polygon = PackedVector2Array()
		return
	var largest_polygon: PackedVector2Array = polygons[0]
	for polygon in polygons:
		if polygon.size() > largest_polygon.size():
			largest_polygon = polygon
			
	# Simplify the polygon further to avoid pixel-to-pixel precision
	var clean_polys = Geometry2D.offset_polygon(largest_polygon, 1.0)
	if clean_polys.size() > 0:
		largest_polygon = clean_polys[0]
		
	var offset := bullet_visual.offset
	if bullet_visual.centered:
		offset -= image.get_size() / 2.0
	var adjusted_polygon := PackedVector2Array()
	for point in largest_polygon:
		adjusted_polygon.append(point + offset)
	collision_polygon.polygon = adjusted_polygon
	collision_polygon.transform = bullet_visual.transform

func _ready():
	add_to_group("multiplayer_projectiles")
	_resolve_visual_nodes()
	_cache_arena_bounds()
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)
	if hit_effect_scene == null:
		hit_effect_scene = DEFAULT_HIT_EFFECT
	if collision_polygon.polygon.is_empty():
		configure_bullet_texture(bullet_visual.texture, gun_instance)
	velocity = transform.x * speed
	
	if bullet_trail_scene and has_node("TrailPoint"):
		var trail_instance = bullet_trail_scene.instantiate()
		$TrailPoint.add_child(trail_instance)
		
	await get_tree().create_timer(5.0).timeout
	queue_free()

func _physics_process(delta: float) -> void:
	if has_hit:
		return
	global_position += velocity * delta
	if has_arena_bounds and not arena_bounds.grow(100.0).has_point(global_position):
		has_hit = true
		queue_free()

func _cache_arena_bounds() -> void:
	var walls: Dictionary = {}
	for group_name in [&"impact_wall", &"bouncy_wall"]:
		for node in get_tree().get_nodes_in_group(group_name):
			if node is Node2D and node.name in [&"Left", &"Right", &"Top", &"Bottom"]:
				walls[node.name] = node
	if not (walls.has(&"Left") and walls.has(&"Right") and walls.has(&"Top") and walls.has(&"Bottom")):
		return
	var top_left := Vector2(walls[&"Left"].global_position.x, walls[&"Top"].global_position.y)
	var bottom_right := Vector2(walls[&"Right"].global_position.x, walls[&"Bottom"].global_position.y)
	arena_bounds = Rect2(top_left, bottom_right - top_left).abs()
	has_arena_bounds = arena_bounds.size.x > 0.0 and arena_bounds.size.y > 0.0

func _on_body_entered(body: Node2D) -> void:
	if has_hit or body == null:
		return
	if body.name == self_id:
		return

	# Bouncy wall logic
	if body.is_in_group("bouncy_wall"):
		if bounce_count < max_bounce:
			bounce_count += 1
			damage /= 2
			ChevronFX.spawn_wall_bounce(body, get_tree().current_scene)
			velocity = velocity.bounce(get_wall_normal(body))

			rotation = velocity.angle()
			global_position += velocity.normalized()
			return
		else:
			queue_free()
			return

	# Impact wall logic
	if body.is_in_group("impact_wall"):
		if hit_effect_scene:
			ImpactFX.spawn_wall_hit(hit_effect_scene, body, global_position)

	if body is MultiplayerGun:
		# Shooter-side hit registration: only the bullet's owner reports the damage to prevent double-damage
		if self_id == str(multiplayer.get_unique_id()):
			body.take_damage.rpc_id(body.name.to_int(), damage)
	if body.has_method("spawn_particles"):
		var hit_pos = global_position
		var hit_normal = (global_position - body.global_position).normalized()
		body.spawn_particles(body.gun_damage_particle, hit_pos, hit_normal)
	has_hit = true
	queue_free()

func get_wall_normal(wall: Node2D) -> Vector2:
	var wname = wall.name
	if wname == "Collider" and wall.get_parent():
		wname = wall.get_parent().name
	if "Left" in wname:
		return Vector2.RIGHT
	elif "Right" in wname:
		return Vector2.LEFT
	elif "Top" in wname:
		return Vector2.DOWN
	elif "Bottom" in wname:
		return Vector2.UP
	return Vector2.ZERO
