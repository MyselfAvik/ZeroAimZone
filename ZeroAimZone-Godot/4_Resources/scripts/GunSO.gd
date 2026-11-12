class_name GunSO
extends Resource

enum GunType {
	STREET,
	PRO,
	APEX,
}

@export var gun_type: GunType



@export_group("Gameplay")
@export var collision_shape: PackedVector2Array
@export var fire_point: Vector2

@export_group("Skins")
@export var skins: Array[GunSkinSO] = []


@export_group("Shop")
@export var name: String
@export var cards_needed: int



@export_group("Stats")
@export var damage: float = 25.0
@export var health: float = 100.0
@export var accuracy: float = 1.0
@export var bullet_speed: float = 5000
@export var recoil_force: float = 1500
@export var torque_force: float = 30
@export var fire_cooldown: float = 0.3
@export var cartridge: int
@export var reload_time: float


func get_skin(skin_index: int) -> GunSkinSO:
	if skins.is_empty():
		return null
	if skin_index < 0 or skin_index >= skins.size():
		return skins[0]
	return skins[skin_index]


func get_skin_diamonds_to_unlock(skin_index: int) -> int:
	var skin := get_skin(skin_index)
	if skin != null:
		return skin.diamonds_to_unlock
	return 0


func get_gun_texture(skin_index: int) -> Texture:
	var skin := get_skin(skin_index)
	if skin == null:
		return null
	return skin.gun_texture


func get_bullet_texture(skin_index: int) -> Texture:
	var skin := get_skin(skin_index)
	if skin == null:
		return null
	return skin.bullet_texture

func get_trail_scene(skin_index: int) -> PackedScene:
	var skin := get_skin(skin_index)
	if skin == null:
		return null
	return skin.trail_effect_scene

func get_muzzle_texture(skin_index: int) -> Texture:
	var skin := get_skin(skin_index)
	if skin == null:
		return null
	return skin.muzzle_flash_icon

func get_fire_sound(skin_index: int) -> AudioStream:
	var skin := get_skin(skin_index)
	if skin == null:
		return null
	return skin.fire_sound
