class_name GunStatsPopup
extends BasePopupController

@export var title_label: Label
@export var gun_image: TextureRect
@export var damage_label: Label
@export var accuracy_label: Label
@export var reload_label: Label
@export var magazine_label: Label

@export var damage_container: HBoxContainer
@export var magazine_container: HBoxContainer
@export var accuracy_container: HBoxContainer
@export var reload_container: HBoxContainer

@export var active_bullet_texture: Texture2D = preload("res://ZeroAimZone-Godot/3_Assets/Sprites/GameUI/Profile/active_points.png")
@export var inactive_bullet_texture: Texture2D = preload("res://ZeroAimZone-Godot/3_Assets/Sprites/GameUI/Profile/inactive_points.png")

@export var bullet_img: TextureRect
@export var muzzle_img: TextureRect
@export var bullet_trail_img: TextureRect

@export var close_btn: TextureButton

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	close_btn.pressed.connect(_on_close_pressed)
	z_index = 100
	_resolve_containers()

func _resolve_containers() -> void:
	if damage_container == null:
		damage_container = get_node_or_null("ModalPanel/stat/VBoxContainer/HBoxContainer/VBoxContainer/DamageContainer")
	if magazine_container == null:
		magazine_container = get_node_or_null("ModalPanel/stat/VBoxContainer/HBoxContainer2/VBoxContainer/MagazineContainer")
	if accuracy_container == null:
		accuracy_container = get_node_or_null("ModalPanel/stat/VBoxContainer/HBoxContainer3/VBoxContainer/AccuracyContainer")
	if reload_container == null:
		reload_container = get_node_or_null("ModalPanel/stat/VBoxContainer/HBoxContainer4/VBoxContainer/ReloadContainer")

func display_stat(gundata: GunSO, skin_idx: int = 0) -> void:
	_resolve_containers()
	title_label.text = gundata.name
	damage_label.text = str(int(round(gundata.damage)))
	accuracy_label.text = str(gundata.accuracy)
	var r_time: float = gundata.reload_time if gundata.reload_time > 0.0 else 1.8
	reload_label.text = "%.1fs" % r_time
	magazine_label.text = str(gundata.cartridge)

	var skin := gundata.get_skin(skin_idx)
	if skin != null:
		gun_image.texture = skin.gun_texture
		if bullet_img:
			bullet_img.texture = skin.bullet_texture
		if muzzle_img:
			muzzle_img.texture = skin.muzzle_flash_icon
		if bullet_trail_img:
			bullet_trail_img.texture = skin.trail_effect_icon

	_update_bullet_bars(gundata)

func _update_bullet_bars(gundata: GunSO) -> void:
	# Damage bar: 10 bullets scaling
	var dmg_bullets: int = clampi(int(round(gundata.damage / 5.5)), 1, 10)
	_set_container_bullets(damage_container, dmg_bullets)

	# Magazine bar: 1-to-1 with cartridge count (e.g. 3 to 7 bullets)
	var mag_bullets: int = clampi(gundata.cartridge, 1, 10)
	_set_container_bullets(magazine_container, mag_bullets)

	# Accuracy bar: mapped across 10 bullets
	var acc_val: float = gundata.accuracy if gundata.accuracy > 1.0 else (gundata.accuracy * 10.0)
	var acc_bullets: int = clampi(int(round(acc_val)), 1, 10)
	_set_container_bullets(accuracy_container, acc_bullets)

	# Reload bar: faster reload (lower time) = more bullets (higher rating)
	# 1.6s -> 9, 1.8s -> 8, 2.0s -> 7, 2.2s -> 6, 2.4s -> 5, 2.6s -> 4, 2.8s -> 3
	var r_time: float = gundata.reload_time if gundata.reload_time > 0.0 else 1.8
	var reload_norm: float = clampf((3.0 - r_time) / 1.5, 0.0, 1.0)
	var rel_bullets: int = clampi(int(round(lerpf(2.0, 10.0, reload_norm))), 1, 10)
	_set_container_bullets(reload_container, rel_bullets)

func _set_container_bullets(container: HBoxContainer, active_count: int) -> void:
	if container == null:
		return
	var children = container.get_children()
	for i in range(children.size()):
		var child = children[i] as TextureRect
		if child != null:
			child.texture = active_bullet_texture if i < active_count else inactive_bullet_texture

func _on_close_pressed() -> void:
	hide()
