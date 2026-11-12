extends Resource
class_name SinglePlayerData

signal changed_data

@export var playerGun: PackedScene
@export var level: Array[PackedScene]
@export var bullet:PackedScene

var selected_gun_texture:Texture
var selected_bullet_texture:Texture
var selected_muzzle_texture:Texture
var selected_trail_scene:PackedScene
var selected_gun_collision_shape:PackedVector2Array
var selected_fire_sound:AudioStream
var gun_name:String
var damage: float
var health: float
var accuracy: float
var bullet_speed: float
var recoil_force: float
var torque_force: float
var fire_cooldown: float
var cartridge: int
var reload_time: float

@export var horizontal_collision_particles:PackedScene
@export var vertical_collision_particles:PackedScene


func apply_gun(gun: GunSO, skin_index: int) -> void:
	selected_gun_texture = gun.get_gun_texture(skin_index)
	selected_bullet_texture = gun.get_bullet_texture(skin_index)
	selected_muzzle_texture = gun.get_muzzle_texture(skin_index)
	selected_trail_scene = gun.get_trail_scene(skin_index)
	selected_fire_sound = gun.get_fire_sound(skin_index)
	selected_gun_collision_shape = gun.collision_shape

	gun_name = gun.name
	damage = gun.damage
	health = gun.health
	accuracy = gun.accuracy

	bullet_speed = gun.bullet_speed
	recoil_force = gun.recoil_force
	torque_force = gun.torque_force

	fire_cooldown = gun.fire_cooldown
	cartridge = gun.cartridge
	reload_time = gun.reload_time
	changed_data.emit()
