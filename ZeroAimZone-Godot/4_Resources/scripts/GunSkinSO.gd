class_name GunSkinSO
extends Resource

@export var skin_name: String
@export var diamonds_to_unlock: int = 0

@export_group("Textures")
@export var gun_texture: Texture
@export var bullet_texture: Texture

@export_group("Muzzle Flash")
@export var muzzle_flash_icon: Texture
# @export var muzzle_flash_scene: PackedScene

@export_group("Trail Effect")
@export var trail_effect_icon: Texture
@export var trail_effect_scene: PackedScene

@export_group("Gun Audio")
@export var fire_sound: AudioStream
