extends RigidBody2D
class_name GunBase

signal died(gun: GunBase)
signal health_changed(gun: GunBase, current_health: float, max_health: float)
signal reload_finished(gun: GunBase) # new

@export_group("Gun")
@export var gun_type: GunSO.GunType
@export var guns_database: AllGunData
@export var bullet_scene:PackedScene
@export var gun_sprite:Sprite2D
@export var gun_fire_audio: AudioStream

@export_group("Scene References")
@export var shoot_particles: CPUParticles2D
@export var muzzle_flash_scene: PackedScene
@export var gun_damage_particles: PackedScene

@export_group("Movement Feel")
@export var drift_angular_damp: float = 2.0
## Hard caps so repeated same-direction shots can't fling the gun off-arena.
@export var max_linear_speed: float = 1350.0
@export var max_angular_speed: float = 14.0
## If true, spin comes naturally from recoil being off-center (muzzle vs
## body center) instead of a fixed torque kick every shot. This is what
## stops rapid-fire from snowballing into a full spin — recommended on.
@export var natural_recoil_spin: bool = true
## If the next shot comes within this many seconds of the last one, it
## counts as "continuous fire" and damping switches to the higher
## continuous_* values below so force can't keep piling up.
@export var continuous_fire_window: float = 0.3
@export var continuous_linear_damp: float = 4
@export var continuous_angular_damp: float = 4

var time_since_last_shot: float = 999.0
@warning_ignore("unused_private_class_variable")
var _cached_bullet_polygon: PackedVector2Array = PackedVector2Array()

@onready var fire_point: Marker2D = $FirePoint
var gun_data: GunSO
var can_shoot: bool = true
var bullet_container: Node

var damage: float
var health: float
var max_health: float
var accuracy: float

var my_skin_index: int = 0
var cartridge: int
var max_cartridge: int = 6
var reload_time: float
var is_reloading: bool = false
var bullet_speed: float
var recoil_force: float
var torque_force: float
var fire_cooldown: float

var has_died: bool = false
var shader_tween: Tween

func _ready():
	bullet_container = get_parent()
	angular_damp = drift_angular_damp

	if gun_sprite.material:
		gun_sprite.material = gun_sprite.material.duplicate()

func setup_gun(gun_index:int,skin_index:int):
	gun_data = guns_database.all_guns[gun_index]
	if gun_data == null:
		push_error("Gun data not found.")
		return
	load_gun_data(skin_index)

func load_gun_data(skin_index:int):
	my_skin_index = skin_index
	var skin := gun_data.get_skin(skin_index)
	if skin:
		gun_sprite.texture = skin.gun_texture
	damage = gun_data.damage
	health = gun_data.health
	max_health = gun_data.health
	cartridge = gun_data.cartridge if gun_data.cartridge > 0 else 6
	max_cartridge = gun_data.cartridge if gun_data.cartridge > 0 else 6
	reload_time = gun_data.reload_time if gun_data.reload_time > 0 else 1.0
	bullet_speed = gun_data.bullet_speed
	recoil_force = gun_data.recoil_force
	torque_force = gun_data.torque_force
	fire_cooldown = gun_data.fire_cooldown if gun_data.fire_cooldown > 0 else 0.2

func take_damage(amount: float):
	health = clampf(health - amount, 0.0, max_health)
	health_changed.emit(self, health, max_health)
	if health <= 0:
		die()

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

func shoot(direction := 1) -> bool: # changed: now returns whether it actually fired
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
	GameManager.in_game_ui.gameplay_panel.update_enemy_bullet(cartridge)
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

	var bullet_texture = null
	var trail_scene = null
	if gun_data:
		bullet_texture = gun_data.get_bullet_texture(my_skin_index)
		trail_scene = gun_data.get_trail_scene(my_skin_index)
	# Enemy bullets use the enemy gun's chosen skin for both bullet and trail,
	# never the scene default.  This occurs before _ready() can instantiate it.
	if bullet.has_method("configure_from_gun_skin"):
		bullet.configure_from_gun_skin(bullet_texture, trail_scene, self)
	elif bullet.has_method("configure_bullet_texture"):
		bullet.configure_bullet_texture(bullet_texture, self)
		bullet.set("bullet_trail_scene", trail_scene)

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
		get_tree().root.add_child(flash)
		flash.global_position = fire_point.global_position
		flash.global_rotation = fire_point.global_rotation
		if particle:
			flash.texture = gun_data.get_muzzle_texture(my_skin_index)
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

	var fire_sfx: AudioStream = gun_data.get_fire_sound(my_skin_index) if gun_data else gun_fire_audio
	if fire_sfx:
		AudioPlayer.play_sfx(fire_sfx)

	if shoot_particles:
		shoot_particles.emitting = true
		get_tree().create_timer(0.15).timeout.connect(func():
			if is_instance_valid(shoot_particles):
				shoot_particles.emitting = false
		)
	
	if cartridge <= 0:
		if not is_reloading:
			reloading()
	return true # new

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
	cartridge = max_cartridge if max_cartridge > 0 else (gun_data.cartridge if gun_data else 6)
	GameManager.in_game_ui.gameplay_panel.update_enemy_bullet(cartridge)
	is_reloading = false
	can_shoot = true
	reload_finished.emit(self)

func _physics_process(delta: float) -> void:
	time_since_last_shot += delta
	_clamp_motion()
	_update_idle_damp()



func _update_idle_damp() -> void:
	# If enough time has passed since the last shot, we're no longer in a
	# continuous-fire burst — drop damping back to idle/glide values so
	# leftover momentum carries through instead of getting braked forever
	# by whatever high continuous_* damping the last shot left behind.
	if time_since_last_shot > continuous_fire_window:
		linear_damp = 0
		angular_damp = drift_angular_damp
func _clamp_motion() -> void:
	# Prevent recoil from stacking into an uncontrollable flight speed / spin.
	if linear_velocity.length() > max_linear_speed:
		linear_velocity = linear_velocity.normalized() * max_linear_speed

	if abs(angular_velocity) > max_angular_speed:
		angular_velocity = sign(angular_velocity) * max_angular_speed

func apply_impact(
	damage: float = 0,
	source_position: Vector2 = Vector2.ZERO,
	knockback: float = 0,
	torque: float = 0,
	stun_time: float = 0
) -> void:
	if damage > 0:
		take_damage(damage)
	if knockback > 0:
		var direction = (global_position - source_position).normalized()
		linear_velocity *= 0.25
		apply_central_impulse(direction * knockback)
	if torque > 0:
		apply_torque_impulse(randf_range(-torque, torque))
	if stun_time > 0:
		can_shoot = false
		await get_tree().create_timer(stun_time).timeout
		can_shoot = true

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
