class_name MultiplayerGun
extends RigidBody2D

@onready var fire_point: Marker2D = $FirePoint
@onready var sync: MultiplayerSynchronizer = $MultiplayerSynchronizer

@export var visual: Sprite2D

@export_group("Gun Configuration")
@export var my_gun_type: GunSO.GunType
@export var guns_database: AllGunData

@export_group("Particles")
@export var vertical_wall_particle: PackedScene
@export var horizontal_wall_particle: PackedScene
@export var muzzle_flash_scene: PackedScene
@export var gun_damage_particle: PackedScene

@export var gun_fire_audio: AudioStream
@export_group("Sync Tuning")
@export var interpolation_speed: float = 20.0

@export_group("Movement Feel")
@export var drift_angular_damp: float = 2.0
@export var max_linear_speed: float = 1350.0
@export var max_angular_speed: float = 14.0
@export var natural_recoil_spin: bool = true
@export var continuous_fire_window: float = 0.3
@export var continuous_linear_damp: float = 5
@export var continuous_angular_damp: float = 3.5

static var _gun_polygon_cache: Dictionary = {}

var time_since_last_shot: float = 999.0

var bullet_scene: PackedScene
var recoil_force: float
var upward_force: float
var torque_force: float
var health: int
var max_health: int
var is_dying := false
var damage: int = 0
var my_gun_index: int = 0
var my_skin_index: int = 0
var sync_position: Vector2 = Vector2.ZERO
var sync_rotation: float = 0.0
var sync_linear_vel: Vector2 = Vector2.ZERO
var sync_angular_vel: float = 0.0
var sync_scale: Vector2 = Vector2.ONE


var can_shoot := true
var cartridge := 6
var max_cartridge := 6
var reload_time := 1.0
var fire_cooldown := 0.12
var is_reloading := false


func _enter_tree() -> void:
	set_multiplayer_authority(name.to_int())
	_load_stats_from_database()
	

func _ready():
	add_to_group("multiplayer_players")
	contact_monitor = true
	max_contacts_reported = 4
	
	_setup_sync()
	_setup_outline()
	if is_multiplayer_authority():
		linear_damp = 0.0
		angular_damp = drift_angular_damp
		if is_instance_valid(SceneManager) and SceneManager._loading_popup != null:
			freeze = true
			SceneManager._loading_popup.tree_exited.connect(func():
				if is_instance_valid(self):
					freeze = false
			)
	else:
		freeze = true
		freeze_mode = RigidBody2D.FREEZE_MODE_KINEMATIC
		sync_position = global_position
		sync_rotation = global_rotation
		sync_scale = global_scale
	print("[GUN] name: ", name, " | authority: ", get_multiplayer_authority(), " | my id: ", multiplayer.get_unique_id(), " | is_authority: ", is_multiplayer_authority())

func _setup_outline():
	@warning_ignore("shadowed_variable_base_class")
	var material := visual.material.duplicate() as ShaderMaterial
	visual.material = material

	if is_multiplayer_authority():
		material.set_shader_parameter("outline_color", Color("#006c9b8c"))
	else:
		material.set_shader_parameter("outline_color", Color("#b326289e"))

func _setup_sync() -> void:
	sync.set_multiplayer_authority(get_multiplayer_authority())
	var replication_config = SceneReplicationConfig.new()
	_add_sync_property(replication_config, "sync_position")
	_add_sync_property(replication_config, "sync_rotation")
	_add_sync_property(replication_config, "sync_linear_vel")
	_add_sync_property(replication_config, "sync_angular_vel")
	_add_sync_property(replication_config, "sync_scale")
	sync.replication_config = replication_config
	sync.replication_interval = 0.016

func _add_sync_property(config: SceneReplicationConfig, prop: String) -> void:
	var path = NodePath(":"+ prop) # <-- add ":" prefix
	config.add_property(path)
	config.property_set_spawn(path, true)
	config.property_set_sync(path, true)
	config.property_set_watch(path, false)

func _load_stats_from_database():
	if guns_database == null:
		push_warning(name + ": Guns Database not assigned!")
		return
	
	var peer_id = name.to_int()
	
	var player_key = "player1" if peer_id == 1 else "player2"
	var match_info: Dictionary = {}
	if is_instance_valid(GameManager.network_handler) and GameManager.network_handler.local_match_data.has("match_info"):
		match_info = GameManager.network_handler.local_match_data.get("match_info", {})
	elif GameManager.cached_match_info:
		match_info = GameManager.cached_match_info
	var peer_data = match_info.get(player_key, {})
	my_gun_index = peer_data.get("gun_index", 0)
	my_skin_index = peer_data.get("skin_index", 0)
	
	var stats = guns_database.all_guns[my_gun_index]
	if stats == null:
		push_error("No stats found for gun type: " + str(my_gun_index))
		return
		
	if visual:
		visual.texture = stats.get_gun_texture(my_skin_index)
		generate_collision_from_sprite(visual)
		
	bullet_scene = GameManager.multiplayer_manager.player_bullet
	recoil_force = stats.recoil_force
	torque_force = stats.torque_force
	health = stats.health
	max_health = stats.health
	damage = stats.damage
	cartridge = stats.cartridge if stats.cartridge > 0 else 6
	max_cartridge = stats.cartridge if stats.cartridge > 0 else 6
	reload_time = stats.reload_time if stats.reload_time > 0 else 1.0
	fire_cooldown = stats.fire_cooldown if stats.fire_cooldown > 0 else 0.2

func generate_collision_from_sprite(sprite: Sprite2D):
	# Clear previous dynamically added collision polygons
	for child in get_children():
		if child is CollisionPolygon2D and child.name.begins_with("collider"):
			child.queue_free()

	if not (sprite and sprite.texture):
		return

	var cache_key = str(my_gun_index) + "_" + str(my_skin_index)
	if _gun_polygon_cache.has(cache_key):
		_apply_collision_polygon(_gun_polygon_cache[cache_key], sprite.transform)
		return

	var image = sprite.texture.get_image()
	if not image:
		return
		
	if image.is_compressed():
		image = image.duplicate()
		image.decompress()

	var is_centered = sprite.centered
	var sprite_offset = sprite.offset
	var sprite_xform = sprite.transform

	# Offload heavy bitmap analysis & polygon decomposition to worker thread
	WorkerThreadPool.add_task(func():
		var bitmap = BitMap.new()
		bitmap.create_from_image_alpha(image, 0.1)
		
		var polygons = bitmap.opaque_to_polygons(Rect2(Vector2.ZERO, image.get_size()), 4.0)
		if polygons.size() == 0:
			return
			
		var largest_poly = polygons[0]
		var max_rect_area = 0.0
		for poly in polygons:
			var min_x = 99999.0
			var min_y = 99999.0
			var max_x = -99999.0
			var max_y = -99999.0
			for pt in poly:
				if pt.x < min_x: min_x = pt.x
				if pt.y < min_y: min_y = pt.y
				if pt.x > max_x: max_x = pt.x
				if pt.y > max_y: max_y = pt.y
			var area = (max_x - min_x) * (max_y - min_y)
			if area > max_rect_area:
				max_rect_area = area
				largest_poly = poly
		
		if largest_poly.size() < 3:
			return

		var clean_polys = Geometry2D.offset_polygon(largest_poly, 1.0)
		if clean_polys.size() > 0:
			largest_poly = clean_polys[0]
		
		var offset_pos = Vector2.ZERO
		if is_centered:
			offset_pos = - image.get_size() / 2.0
		offset_pos += sprite_offset
		
		var adjusted_poly = PackedVector2Array()
		for pt in largest_poly:
			adjusted_poly.append(pt + offset_pos)
		
		_gun_polygon_cache[cache_key] = adjusted_poly
		call_deferred("_apply_collision_polygon", adjusted_poly, sprite_xform)
	)

func _apply_collision_polygon(adjusted_poly: PackedVector2Array, sprite_xform: Transform2D) -> void:
	if not is_inside_tree():
		return
	var col_poly = get_node_or_null("collider_0") as CollisionPolygon2D
	if col_poly == null:
		col_poly = CollisionPolygon2D.new()
		col_poly.name = "collider_0"
		add_child(col_poly)
	col_poly.polygon = adjusted_poly
	col_poly.transform = sprite_xform

func _physics_process(delta: float):
	if multiplayer.multiplayer_peer == null:
		return
	time_since_last_shot += delta
	if is_multiplayer_authority():
		# Write live state into synced vars
		sync_position = global_position
		sync_rotation = global_rotation
		sync_linear_vel = linear_velocity
		sync_angular_vel = angular_velocity
		sync_scale = scale

		if not freeze and Input.is_action_just_pressed("Shoot"):
			if get_viewport().gui_get_hovered_control() == null:
				request_shoot(fire_point.global_position, fire_point.global_rotation, 1)

		_update_idle_damp()
		_clamp_motion()

		if health <= 0 and not is_dying:
			is_dying = true
			set_physics_process(false)
			sync.public_visibility = false
			if multiplayer.is_server():
				report_death(1)
			else:
				report_death.rpc_id(1, multiplayer.get_unique_id())
			return
		var state = PhysicsServer2D.body_get_direct_state(self.get_rid())
		if state != null and linear_velocity.length_squared() > 10000.0:
			for i in state.get_contact_count():
				var hit_position = state.get_contact_local_position(i)
				var hit_normal = state.get_contact_local_normal(i)
				var collider = state.get_contact_collider_object(i)
				if collider == null:
					continue
				if collider.name == "Left" or collider.name == "Right":
					spawn_particles(vertical_wall_particle, hit_position, hit_normal)
				elif collider.name == "Top" or collider.name == "Bottom":
					spawn_particles(horizontal_wall_particle, hit_position, hit_normal)
	else:
		# Dead-reckoning: project where the remote gun is heading using its synced velocity
		var target_pos = sync_position + sync_linear_vel * delta
		var target_rot = sync_rotation + sync_angular_vel * delta
		var t = clamp(interpolation_speed * delta, 0.0, 1.0)
		global_position = global_position.lerp(target_pos, t)
		global_rotation = lerp_angle(global_rotation, target_rot, t)
		scale = sync_scale


func _clamp_motion() -> void:
	# Prevent recoil from stacking into an uncontrollable flight speed / spin.
	if linear_velocity.length() > max_linear_speed:
		linear_velocity = linear_velocity.normalized() * max_linear_speed
	if abs(angular_velocity) > max_angular_speed:
		angular_velocity = sign(angular_velocity) * max_angular_speed


func _update_idle_damp() -> void:
	# If enough time has passed since the last shot, we're no longer in a
	# continuous-fire burst — drop damping back to idle/glide values so
	# leftover momentum carries through instead of getting braked forever
	# by whatever high continuous_* damping the last shot left behind.
	if time_since_last_shot > continuous_fire_window:
		linear_damp = 0
		angular_damp = drift_angular_damp


func request_shoot(spawn_pos: Vector2, spawn_rot: float, direction: int):
	if !is_multiplayer_authority():
		return

	if !can_shoot:
		return

	if is_reloading:
		return

	if cartridge <= 0:
		if !is_reloading:
			reloading()
		return

	cartridge -= 1

	update_ammo.rpc(cartridge)

	can_shoot = false
	start_fire_cooldown()

	if cartridge <= 0:
		reloading()

	# Replicate the firing gun/skin rather than reading any receiver's local
	# selection.  Every peer resolves the same GunSkinSO resource.
	spawn_bullet.rpc(spawn_pos, spawn_rot, direction, my_gun_index, my_skin_index)

@rpc("authority", "call_local", "reliable")
func spawn_bullet(spawn_pos: Vector2, spawn_rot: float, direction: int, fired_gun_index: int, fired_skin_index: int):
	# recoil (authority only)
	if is_multiplayer_authority():
		var is_continuous_fire: bool = time_since_last_shot <= continuous_fire_window
		time_since_last_shot = 0.0

		if is_continuous_fire:
			linear_damp = continuous_linear_damp
			angular_damp = continuous_angular_damp
		else:
			linear_damp = 0
			angular_damp = drift_angular_damp

		# Normal single tap: real recoil, pushes opposite the muzzle direction.
		# Continuous rapid fire: cancel whatever momentum/spin already exists,
		# then thrust forward — so spamming can't stack force shot over shot.
		var facing: Vector2 = fire_point.global_transform.x.normalized()
		var recoil_dir: Vector2 = facing if is_continuous_fire else -facing
		var recoil_impulse: Vector2 = recoil_dir * recoil_force * direction

		if is_continuous_fire:
			linear_velocity = Vector2.ZERO
			angular_velocity = 0.0

		if natural_recoil_spin:
			# Apply the impulse at the muzzle's offset from the body's origin
			# instead of dead-center — physics derives the resulting torque
			# from that lever arm on its own, so it can't snowball into a
			# one-direction spin the way a constant torque impulse does.
			apply_impulse(recoil_impulse, fire_point.position)
		else:
			apply_central_impulse(recoil_impulse)
			apply_torque_impulse(-torque_force * direction)

	if muzzle_flash_scene:
		var flash = muzzle_flash_scene.instantiate()
		var particle = flash is CPUParticles2D

		# Capture the muzzle transform, then let the burst travel independently.
		add_child(flash)
		flash.global_position = fire_point.global_position
		flash.global_rotation = fire_point.global_rotation
		if particle:
			if guns_database and my_gun_index < guns_database.all_guns.size():
				var stats = guns_database.all_guns[my_gun_index]
				if stats:
					flash.texture = stats.get_muzzle_texture(my_skin_index)
			flash.restart()
			flash.finished.connect(flash.queue_free)
		else:
			if flash.has_method("play"):
				flash.call("play")
			elif flash.has_node("AnimationPlayer"):
				var anim = flash.get_node("AnimationPlayer")
				anim.play("Poof_Flash")
			if flash.has_node("AnimationPlayer"):
				flash.get_node("AnimationPlayer").animation_finished.connect(func(_anim_name): flash.queue_free())
		
		var fire_snd: AudioStream = null
		if guns_database and my_gun_index < guns_database.all_guns.size():
			var stats = guns_database.all_guns[my_gun_index]
			if stats:
				fire_snd = stats.get_fire_sound(my_skin_index)
		if fire_snd:
			AudioPlayer.play_sfx(fire_snd)

	if bullet_scene == null:
		push_error("No bullet prefab assigned for: " + str(my_gun_type))
		return
	var bullet = bullet_scene.instantiate()
	_configure_bullet_skin(bullet, fired_gun_index, fired_skin_index)
	var fired_gun: GunSO = null
	if guns_database and fired_gun_index >= 0 and fired_gun_index < guns_database.all_guns.size():
		fired_gun = guns_database.all_guns[fired_gun_index]

	if fired_gun and "bullet_speed" in fired_gun:
		bullet.speed = fired_gun.bullet_speed * 0.45
	else:
		bullet.speed = bullet.speed * 0.45
	get_tree().root.add_child(bullet)
	bullet.global_position = spawn_pos
	bullet.global_rotation = spawn_rot
	bullet.velocity = Vector2.RIGHT.rotated(spawn_rot) * bullet.speed * direction
	bullet.self_id = name
	if fired_gun:
		bullet.damage = fired_gun.damage
	else:
		bullet.damage = damage


func _configure_bullet_skin(bullet: Node, fired_gun_index: int, fired_skin_index: int) -> void:
	if guns_database == null or fired_gun_index < 0 or fired_gun_index >= guns_database.all_guns.size():
		push_error("Invalid firing gun index for bullet: " + str(fired_gun_index))
		return
	var fired_gun: GunSO = guns_database.all_guns[fired_gun_index]
	if fired_gun == null:
		push_error("Missing firing gun data for bullet: " + str(fired_gun_index))
		return
	var trail_scene := fired_gun.get_trail_scene(fired_skin_index)
	# Configure both assets before add_child() invokes the bullet's _ready().
	# The gun/skin indices originate from the firing peer's RPC, so remote
	# clients cannot accidentally use their own selected trail.
	if bullet.has_method("configure_from_gun_skin"):
		bullet.configure_from_gun_skin(fired_gun.get_bullet_texture(fired_skin_index), trail_scene, self)
	elif bullet.has_method("configure_bullet_texture"):
		bullet.configure_bullet_texture(fired_gun.get_bullet_texture(fired_skin_index), self)
		bullet.set("bullet_trail_scene", trail_scene)


@rpc("authority", "call_local", "reliable")
func shoot(direction: int, spawn_pos: Vector2, spawn_rot: float):
	if is_multiplayer_authority():
		if !can_shoot:
			return

		if cartridge <= 0:
			if !is_reloading:
				reloading()
			return

		cartridge -= 1

		update_ammo.rpc(cartridge)

		can_shoot = false
		start_fire_cooldown()

		if cartridge <= 0 and !is_reloading:
			reloading()
		var is_continuous_fire: bool = time_since_last_shot <= continuous_fire_window
		time_since_last_shot = 0.0

		if is_continuous_fire:
			linear_damp = continuous_linear_damp
			angular_damp = continuous_angular_damp
		else:
			linear_damp = 0
			angular_damp = drift_angular_damp

		# Normal single tap: real recoil, pushes opposite the muzzle direction.
		# Continuous rapid fire: cancel whatever momentum/spin already exists,
		# then thrust forward — so spamming can't stack force shot over shot.
		var facing: Vector2 = fire_point.global_transform.x.normalized()
		var recoil_dir: Vector2 = facing if is_continuous_fire else -facing
		var recoil_impulse: Vector2 = recoil_dir * recoil_force * direction

		if is_continuous_fire:
			linear_velocity = Vector2.ZERO
			angular_velocity = 0.0

		if natural_recoil_spin:
			# Apply the impulse at the muzzle's offset from the body's origin
			# instead of dead-center — physics derives the resulting torque
			# from that lever arm on its own, so it can't snowball into a
			# one-direction spin the way a constant torque impulse does.
			apply_impulse(recoil_impulse, fire_point.position)
		else:
			apply_central_impulse(recoil_impulse)
			apply_torque_impulse(-torque_force * direction)

	if bullet_scene == null:
		push_error("No bullet prefab assigned for: " + str(my_gun_type))
		return
	var bullet = bullet_scene.instantiate()
	_configure_bullet_skin(bullet, my_gun_index, my_skin_index)
	var fired_gun: GunSO = null
	if guns_database and my_gun_index >= 0 and my_gun_index < guns_database.all_guns.size():
		fired_gun = guns_database.all_guns[my_gun_index]
	if fired_gun and "bullet_speed" in fired_gun:
		bullet.speed = fired_gun.bullet_speed * 0.45
	else:
		bullet.speed = bullet.speed * 0.45
	get_tree().root.add_child(bullet)
	bullet.global_position = spawn_pos
	bullet.global_rotation = spawn_rot
	bullet.velocity = Vector2.RIGHT.rotated(spawn_rot) * bullet.speed * direction
	bullet.self_id = name
	bullet.damage = damage


func start_fire_cooldown() -> void:
	if not is_inside_tree():
		return
	await get_tree().create_timer(fire_cooldown).timeout

	if not is_inside_tree() or not is_multiplayer_authority():
		return

	if !is_reloading:
		can_shoot = true

func reloading() -> void:
	if is_reloading or not is_inside_tree():
		return

	is_reloading = true
	can_shoot = false

	# Optional: show reload progress here

	await get_tree().create_timer(reload_time).timeout

	if not is_inside_tree() or not is_multiplayer_authority():
		return

	cartridge = max_cartridge

	update_ammo.rpc(cartridge)

	is_reloading = false
	can_shoot = true

func spawn_particles(scene: PackedScene, hit_position: Vector2, hit_normal: Vector2):
	if scene == null:
		return
	var particles = scene.instantiate()
	particles.add_to_group("multiplayer_projectiles")
	get_tree().root.add_child(particles)
	particles.global_position = hit_position
	particles.rotation = hit_normal.angle()
	particles.one_shot = true
	particles.emitting = true
	particles.finished.connect(particles.queue_free)

@rpc("any_peer", "reliable")
func report_death(death_id: int):
	if !multiplayer.is_server():
		return

	GameManager.multiplayer_manager.update_round.rpc(death_id)

@rpc("any_peer", "call_local", "reliable")
func take_damage(amount: int):
	if not is_multiplayer_authority(): return
	if is_dying: return
	health -= amount
	_broadcast_health.rpc(name, health, max_health)
	print("[GUN] took damage, health: ", health)
	
	if GameManager.save_manager and GameManager.save_manager.game_data.has("game_settings") and GameManager.save_manager.game_data["game_settings"].get("haptic_on", true):
		Input.vibrate_handheld(150)

@rpc("authority", "call_local", "reliable")
func _broadcast_health(gun_name: String, current: float, max_h: float) -> void:
	if gun_name == str(multiplayer.get_unique_id()):
		GameManager.in_game_ui.gameplay_panel.update_player_health(current, max_h)
	else:
		GameManager.in_game_ui.gameplay_panel.update_enemy_health(current, max_h)


@rpc("authority", "call_local", "reliable")
func update_ammo(current: int):
	if name == str(multiplayer.get_unique_id()):
		GameManager.in_game_ui.gameplay_panel.update_player_bullet(current)
	else:
		GameManager.in_game_ui.gameplay_panel.update_enemy_bullet(current)
