class_name SinglePlayerGun
extends RigidBody2D

signal died(gun)
signal health_changed(gun, current_health: float, max_health: float)
signal reload_finished(gun)


var single_player_data: SinglePlayerData

@export var gun_fire_audio: AudioStream

@export_group("Scene References")
@export var shoot_particles: CPUParticles2D
@export var muzzle_flash_scene: PackedScene
@export var gun_damage_particles: PackedScene
@export var gun_sprite: Sprite2D
@export var camera2D: Camera2D

@export_group("Movement Feel")

@export var drift_angular_damp: float = 2

@export var max_linear_speed: float = 1350
@export var max_angular_speed: float = 14.0

@export var natural_recoil_spin: bool = true

@export var continuous_fire_window: float = 0.3
@export var continuous_linear_damp: float = 4
@export var continuous_angular_damp: float = 4

var time_since_last_shot: float = 999.0

@onready var fire_point: Marker2D = $FirePoint
@export var visual: Sprite2D
@export var collision_polygon: CollisionPolygon2D
var can_shoot: bool = true
var bullet_scene: PackedScene
var bullet_container: Node

var damage: float
var health: float
var max_health: float
var accuracy: float

var cartridge: int
var max_cartridge: int
var reload_time: float
var is_reloading: bool = false
var bullet_speed: float
var recoil_force: float
var torque_force: float
var fire_cooldown: float

var has_died: bool = false
var shader_tween: Tween
var camera_tween: Tween

var cameraShakeNoise: FastNoiseLite

func _ready():
	bullet_container = get_parent()

	if max_cartridge <= 0 and single_player_data:
		cartridge = single_player_data.cartridge
		max_cartridge = single_player_data.cartridge

	add_to_group("player")

	contact_monitor = true
	max_contacts_reported = 4


	angular_damp = drift_angular_damp

	if gun_sprite.material:
		gun_sprite.material = gun_sprite.material.duplicate()
	
	if gun_sprite:
		generate_collision_from_sprite(gun_sprite)
	cameraShakeNoise = FastNoiseLite.new()


func setup_player_gun():
	visual.texture = single_player_data.selected_gun_texture
	#collision_polygon.polygon=single_player_data.selected_gun_collision_shape
	load_gun_data(single_player_data)

func generate_collision_from_sprite(sprite: Sprite2D):
	# Clear previous dynamically added collision polygons
	for child in get_children():
		if child is CollisionPolygon2D and child.name.begins_with("collider"):
			child.queue_free()

	if sprite and sprite.texture:
		var image = sprite.texture.get_image()
		if not image:
			return
			
		if image.is_compressed():
			image.decompress()
			
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
		if sprite.centered:
			offset_pos = - image.get_size() / 2.0
		offset_pos += sprite.offset
		
		var col_poly = CollisionPolygon2D.new()
		col_poly.name = "collider_0"
		
		var adjusted_poly = PackedVector2Array()
		for pt in largest_poly:
			adjusted_poly.append(pt + offset_pos)
		col_poly.polygon = adjusted_poly
		
		col_poly.transform = sprite.transform
		add_child(col_poly)

func load_gun_data(single_player_data: SinglePlayerData):
	damage = single_player_data.damage
	health = single_player_data.health
	max_health = single_player_data.health
	accuracy = single_player_data.accuracy
	cartridge = single_player_data.cartridge
	max_cartridge = single_player_data.cartridge
	reload_time = single_player_data.reload_time if single_player_data.reload_time > 0 else 1.0
	bullet_speed = single_player_data.bullet_speed
	recoil_force = single_player_data.recoil_force
	torque_force = single_player_data.torque_force
	fire_cooldown = single_player_data.fire_cooldown if single_player_data.fire_cooldown > 0 else 0.2
	bullet_scene = single_player_data.bullet

func take_damage(amount: float):
	health = clampf(health - amount, 0.0, max_health)
	health_changed.emit(self, health, max_health)

	if GameManager.save_manager and GameManager.save_manager.game_data.has("game_settings") and GameManager.save_manager.game_data["game_settings"].get("haptic_on", true):
		Input.vibrate_handheld(150)

	if health <= 0:
		die()
	
	camera_tween = get_tree().create_tween()
	camera_tween.tween_method(cameraShake, 30.0, 1.0, 0.5)

	if shader_tween:
		shader_tween.kill()

	setShader_blinkIntensity(1.0)
	shader_tween = get_tree().create_tween()
	shader_tween.tween_method(setShader_blinkIntensity, 1.0, 0.0, 0.5)
	await shader_tween.finished
	shader_tween = null

	print(name, " Health:", health)

func setShader_blinkIntensity(value: float):
	gun_sprite.material.set_shader_parameter("blink_intensity", value)

func cameraShake(intensity: float):
	var cameraOffset = cameraShakeNoise.get_noise_1d(Time.get_ticks_msec()) * intensity
	camera2D.offset.x = cameraOffset
	camera2D.offset.y = cameraOffset

func shoot(direction := 1) -> bool:
	if bullet_scene == null:
		return false

	if (can_shoot == false):
		return false

	if cartridge <= 0:
		if not is_reloading:
			reloading()
		return false
	print(name, " cartridge :", cartridge)
	cartridge -= 1
	GameManager.in_game_ui.gameplay_panel.update_player_bullet(cartridge)
	can_shoot = false
	start_fire_cooldown()

	var is_continuous_fire: bool = time_since_last_shot <= continuous_fire_window
	time_since_last_shot = 0.0

	if is_continuous_fire:
		linear_damp = continuous_linear_damp
		angular_damp = continuous_angular_damp
	else:
		linear_damp = 0
		angular_damp = drift_angular_damp

	var bullet = bullet_scene.instantiate()

	# Configure both the bullet and trail from the equipped player gun before
	# adding the projectile, which invokes its _ready().
	if bullet.has_method("configure_from_gun_skin"):
		bullet.configure_from_gun_skin(single_player_data.selected_bullet_texture, single_player_data.selected_trail_scene, self)
	elif bullet.has_method("configure_bullet_texture"):
		bullet.configure_bullet_texture(single_player_data.selected_bullet_texture, self)
		bullet.set("bullet_trail_scene", single_player_data.selected_trail_scene)

	bullet_container.add_child(bullet)
	bullet.dmg = damage
	bullet.global_position = fire_point.global_position
	bullet.velocity = fire_point.global_transform.x * bullet_speed * direction
	bullet.global_rotation = bullet.velocity.angle()

	# Normal single tap: real recoil, pushes opposite the muzzle direction.
	# Continuous rapid fire: cancel whatever momentum/spin already exists,
	# then thrust forward — so spamming can't stack force shot over shot,
	# it just gets the same clean forward push every time.
	var facing: Vector2 = fire_point.global_transform.x.normalized()
	var recoil_dir: Vector2 = facing if is_continuous_fire else -facing
	var recoil_impulse: Vector2 = recoil_dir * recoil_force * direction

	if is_continuous_fire:
		linear_velocity = Vector2.ZERO
		angular_velocity = 0.0

	if natural_recoil_spin:
		# Apply the impulse at the muzzle's offset from the body's origin
		# instead of dead-center. Physics then derives the resulting torque
		# from that lever arm on its own — it's naturally small and it
		# flips sign as the gun rotates, so it can't snowball into a
		# one-direction spin the way a constant torque impulse does.
		apply_impulse(recoil_impulse, fire_point.position)
	else:
		apply_central_impulse(recoil_impulse)
		apply_torque_impulse(-direction * torque_force)

	if muzzle_flash_scene:
		var flash = muzzle_flash_scene.instantiate()
		var particle = flash is CPUParticles2D

		# Capture the muzzle transform, then let the burst travel independently.
		add_child(flash)
		flash.global_position = fire_point.global_position
		flash.global_rotation = fire_point.global_rotation
		if particle:
			flash.texture = single_player_data.selected_muzzle_texture
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

	if single_player_data and single_player_data.selected_fire_sound:
		AudioPlayer.play_sfx(single_player_data.selected_fire_sound)

	if shoot_particles:
		shoot_particles.emitting = true
		get_tree().create_timer(0.15).timeout.connect(func():
			if is_instance_valid(shoot_particles):
				shoot_particles.emitting = false
		)
	
	if cartridge <= 0:
		if not is_reloading:
			reloading()
	return true

func die() -> void:
	if has_died:
		return
	has_died = true

	# Stop any running blink tween
	if shader_tween:
		shader_tween.kill()
		shader_tween = null

	# Reset shader
	setShader_blinkIntensity(0.0)

	died.emit(self)


func start_fire_cooldown() -> void:
	await get_tree().create_timer(fire_cooldown).timeout
	can_shoot = true

func reloading() -> void:
	is_reloading = true
	can_shoot = false
	await get_tree().create_timer(reload_time).timeout
	cartridge = max_cartridge if max_cartridge > 0 else (single_player_data.cartridge if single_player_data else 6)
	GameManager.in_game_ui.gameplay_panel.update_player_bullet(cartridge)
	is_reloading = false
	can_shoot = true
	reload_finished.emit(self)


func _physics_process(delta: float) -> void:
	time_since_last_shot += delta
	if Input.is_action_just_pressed("Shoot"):
		if get_viewport().gui_get_hovered_control() == null:
			shoot()
	_update_idle_damp()
	_clamp_motion()
	check_collisions()

func _update_idle_damp() -> void:
	if time_since_last_shot > continuous_fire_window:
		linear_damp = 0
		angular_damp = drift_angular_damp


func _clamp_motion() -> void:
	# Prevent recoil from stacking into an uncontrollable flight speed / spin.
	if linear_velocity.length() > max_linear_speed:
		linear_velocity = linear_velocity.normalized() * max_linear_speed

	if abs(angular_velocity) > max_angular_speed:
		angular_velocity = sign(angular_velocity) * max_angular_speed


func check_collisions():
	var state = PhysicsServer2D.body_get_direct_state(get_rid())

	if state == null:
		return

	for i in state.get_contact_count():
		var collider = state.get_contact_collider_object(i)

		if collider == null:
			continue

		var hit_position = state.get_contact_local_position(i)
		var hit_normal = state.get_contact_local_normal(i)

		if collider.name == "Left" or collider.name == "Right":
			spawn_particles(
				single_player_data.vertical_collision_particles,
				hit_position,
				hit_normal
			)

		elif collider.name == "Top" or collider.name == "Bottom":
			spawn_particles(
				single_player_data.horizontal_collision_particles,
				hit_position,
				hit_normal
			)

func spawn_particles(scene: PackedScene, pos: Vector2, normal: Vector2):
	if scene == null:
		return

	var particles = scene.instantiate()

	get_tree().root.add_child(particles)

	particles.global_position = pos
	particles.rotation = normal.angle()
	particles.one_shot = true
	particles.emitting = true

	particles.finished.connect(particles.queue_free)

func apply_impact(
	damage: float = 0,
	source_position: Vector2 = Vector2.ZERO,
	impulse: float = 0,
	torque: float = 0,
	stun_time: float = 0
) -> void:
	if damage > 0:
		take_damage(damage)

	if impulse > 0:
		var direction = (global_position - source_position).normalized()
		apply_central_impulse(direction * impulse)

	if torque > 0:
		apply_torque_impulse(randf_range(-torque, torque))

	if stun_time > 0:
		can_shoot = false
		if not is_inside_tree():
			return
		await get_tree().create_timer(stun_time).timeout
		if is_inside_tree():
			can_shoot = true
