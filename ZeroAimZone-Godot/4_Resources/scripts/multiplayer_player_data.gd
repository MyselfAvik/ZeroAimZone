extends Resource
class_name MultiplayerPlayerData

@export var playerGun: PackedScene
@export var level: Array[PackedScene]
@export var multiplayerBullet:PackedScene

var selected_gun_texture:Texture
var selected_bullet_texture:Texture
var selected_gun_collision_shape:Shape2D

var damage: float
var health: float
var accuracy: float
var bullet_speed: float
var recoil_force: float
var torque_force: float
var fire_cooldown: float
var cartridge: int
var reload_time: float
