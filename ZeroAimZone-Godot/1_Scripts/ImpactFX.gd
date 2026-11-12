extends Node

func spawn_wall_hit(hit_effect_scene: PackedScene, wall: Node2D, hit_pos: Vector2) -> void:
	if hit_effect_scene == null:
		return
		
	var effect = hit_effect_scene.instantiate() as Node2D
	effect.z_index = 10
	
	# Get the closest point on the wall's collider in pure global space
	var exact_pos = _get_closest_point_on_wall(wall, hit_pos)
	
	print("ImpactFX spawn: hit_pos=", hit_pos, ", exact_pos=", exact_pos)
	
	# Add the effect to the level root
	var parent = wall.owner
	if parent == null:
		parent = wall.get_parent()
		
	# CRITICAL FIX: We must set the position BEFORE add_child() because HitEffect.tscn
	# sets emitting = true in _ready(). If we add_child() first, it emits at (0,0)!
	var local_pos = exact_pos
	if parent is CanvasItem:
		local_pos = parent.get_global_transform().affine_inverse() * exact_pos
		
	effect.position = local_pos
	parent.add_child(effect)
	
	# Orient the effect properly (the hit effect naturally faces right, we want it to face away from the wall)
	# Assuming it hit the left wall, it should face right. Let's just face it towards the center for now or leave it.
	# The CPUParticles2D inside HitEffect.tscn is rotated 90 degrees by default.

func _get_closest_point_on_wall(wall: Node2D, hit_pos: Vector2) -> Vector2:
	var collider = wall.get_node_or_null("CollisionPolygon2D")
	if collider == null:
		collider = wall.get_node_or_null("Collider")
		
	if collider is CollisionPolygon2D:
		var poly = collider.polygon
		if poly.size() < 3:
			return hit_pos
			
		var wall_transform = wall.global_transform * collider.transform
		
		# Convert all polygon points to global coordinates to avoid inverse transform bugs
		var global_poly = []
		for p in poly:
			global_poly.append(wall_transform * p)
			
		var closest_dist = INF
		var closest_point = hit_pos
		
		for i in range(global_poly.size()):
			var p1 = global_poly[i]
			var p2 = global_poly[(i + 1) % global_poly.size()]
			var closest = Geometry2D.get_closest_point_to_segment(hit_pos, p1, p2)
			var dist = hit_pos.distance_squared_to(closest)
			if dist < closest_dist:
				closest_dist = dist
				closest_point = closest
				
		return closest_point
		
	elif collider is CollisionShape2D and collider.shape is RectangleShape2D:
		var rect = collider.shape as RectangleShape2D
		var extents = rect.size / 2.0
		var wall_transform = wall.global_transform * collider.transform
		var local_pos = wall_transform.affine_inverse() * hit_pos
		
		var clamped_local = Vector2(
			clamp(local_pos.x, -extents.x, extents.x),
			clamp(local_pos.y, -extents.y, extents.y)
		)
		
		if abs(clamped_local.x) < extents.x and abs(clamped_local.y) < extents.y:
			var dist_x = extents.x - abs(clamped_local.x)
			var dist_y = extents.y - abs(clamped_local.y)
			if dist_x < dist_y:
				clamped_local.x = extents.x * sign(clamped_local.x)
			else:
				clamped_local.y = extents.y * sign(clamped_local.y)
				
		return wall_transform * clamped_local

	return hit_pos
