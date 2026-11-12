class_name SkinRewardPanelController
extends BasePopupController

@export var gun_image: TextureRect
@export var glow_image: TextureRect
@export var rays_image: TextureRect
@export var card_container: Control
@export var congratulations_label: Label
@export var skin_name_label: Label
@export var equip_button: Button
@export var sparkles: CPUParticles2D

var _gunindex: int
var _skinindex: int
var _gundata: GunSO
var _is_gun_unlock: bool = false

var _intro_tween: Tween
var _idle_tween: Tween
var _rays_tween: Tween
var _glow_tween: Tween
var _button_pulse_tween: Tween
var _can_dismiss: bool = false
var _gun_orig_pos: Vector2 = Vector2.ZERO
var _label_orig_pos: Vector2 = Vector2.ZERO
var _equip_orig_pos: Vector2 = Vector2.ZERO

func _ready():
	super._ready()
	if equip_button and not equip_button.pressed.is_connected(_on_equip_pressed):
		equip_button.pressed.connect(_on_equip_pressed)
	if not gui_input.is_connected(_on_panel_gui_input):
		gui_input.connect(_on_panel_gui_input)

	if gun_image:
		_gun_orig_pos = gun_image.position
	if congratulations_label:
		_label_orig_pos = congratulations_label.position
	if equip_button:
		_equip_orig_pos = equip_button.position


func setup(gunindex: int, skinindex: int, gundata: GunSO) -> void:
	setup_skin(gunindex, skinindex, gundata)


func setup_skin(gunindex: int, skinindex: int, gundata: GunSO) -> void:
	_is_gun_unlock = false
	_gunindex = gunindex
	_skinindex = skinindex
	_gundata = gundata
	_can_dismiss = false

	if gun_image and _gundata:
		gun_image.texture = _gundata.get_gun_texture(_skinindex)
	
	if congratulations_label:
		congratulations_label.text = "NEW SKIN UNLOCKED!"
	
	if skin_name_label and _gundata:
		skin_name_label.text = _gundata.name
		skin_name_label.visible = true

	if equip_button:
		equip_button.text = "EQUIP"
		equip_button.disabled = false

	_play_sound_and_animation()


func setup_gun(gunindex: int, gundata: GunSO) -> void:
	_is_gun_unlock = true
	_gunindex = gunindex
	_skinindex = 0
	_gundata = gundata
	_can_dismiss = false

	if gun_image and _gundata:
		gun_image.texture = _gundata.get_gun_texture(0)
	
	if congratulations_label:
		congratulations_label.text = "CONGRATULATIONS!\nYOU HAVE UNLOCKED A NEW GUN"
	
	if skin_name_label and _gundata:
		skin_name_label.text = _gundata.name
		skin_name_label.visible = true

	if equip_button:
		equip_button.text = "EQUIP"
		equip_button.disabled = false

	_play_sound_and_animation()


func _play_sound_and_animation() -> void:
	# Play reward sound
	if AudioPlayer:
		if "SOUND_DB" in AudioPlayer and AudioPlayer.SOUND_DB:
			if "crate_open" in AudioPlayer.SOUND_DB and AudioPlayer.SOUND_DB.crate_open:
				AudioPlayer.play_sfx(AudioPlayer.SOUND_DB.crate_open)
			elif "game_won" in AudioPlayer.SOUND_DB and AudioPlayer.SOUND_DB.game_won:
				AudioPlayer.play_sfx(AudioPlayer.SOUND_DB.game_won)

	play_reward_animation()


func play_reward_animation() -> void:
	_kill_tweens()

	# Center pivots
	if card_container:
		card_container.pivot_offset = card_container.size * 0.5
		card_container.scale = Vector2.ZERO
		card_container.modulate.a = 1.0

	if gun_image:
		gun_image.pivot_offset = gun_image.size * 0.5
		gun_image.scale = Vector2.ZERO
		gun_image.rotation = -0.35
		gun_image.position = _gun_orig_pos
		if gun_image.material:
			gun_image.material.set_shader_parameter("flash_amount", 0.0)

	if rays_image:
		rays_image.pivot_offset = rays_image.size * 0.5
		rays_image.scale = Vector2.ZERO
		rays_image.modulate.a = 0.0
		rays_image.rotation = 0.0

	if glow_image:
		glow_image.pivot_offset = glow_image.size * 0.5
		glow_image.scale = Vector2.ZERO
		glow_image.modulate.a = 0.0

	if congratulations_label:
		congratulations_label.pivot_offset = congratulations_label.size * 0.5
		congratulations_label.scale = Vector2(0.5, 0.5)
		congratulations_label.modulate.a = 0.0

	if skin_name_label:
		skin_name_label.pivot_offset = skin_name_label.size * 0.5
		skin_name_label.scale = Vector2(0.5, 0.5)
		skin_name_label.modulate.a = 0.0

	if equip_button:
		equip_button.pivot_offset = equip_button.size * 0.5
		equip_button.scale = Vector2(0.6, 0.6)
		equip_button.modulate.a = 0.0

	if sparkles:
		sparkles.emitting = true
		sparkles.restart()

	# Intro Animation
	_intro_tween = create_tween()
	_intro_tween.set_parallel(true)

	# 1. Card Container pop-in
	if card_container:
		_intro_tween.tween_property(card_container, "scale", Vector2.ONE, 0.45) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	# 2. Sunburst rays expansion & continuous rotation
	if rays_image:
		_intro_tween.tween_property(rays_image, "scale", Vector2.ONE, 0.5) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		_intro_tween.tween_property(rays_image, "modulate:a", 0.9, 0.3) \
			.set_trans(Tween.TRANS_LINEAR).set_ease(Tween.EASE_IN)
		
		_rays_tween = create_tween().set_loops()
		_rays_tween.tween_property(rays_image, "rotation", TAU, 6.0) \
			.from(0.0).set_trans(Tween.TRANS_LINEAR)

	# 3. Soft Aura Glow breathing loop
	if glow_image:
		_intro_tween.tween_property(glow_image, "scale", Vector2.ONE, 0.4) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		_intro_tween.tween_property(glow_image, "modulate:a", 0.9, 0.35) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

		_glow_tween = create_tween().set_loops()
		_glow_tween.tween_property(glow_image, "scale", Vector2(1.2, 1.2), 1.2) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		_glow_tween.tween_property(glow_image, "scale", Vector2(0.9, 0.9), 1.2) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	# 4. Gun Image hero burst & shine flash
	if gun_image:
		_intro_tween.tween_property(gun_image, "scale", Vector2(1.2, 1.2), 0.35) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		_intro_tween.tween_property(gun_image, "rotation", -0.174, 0.35) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

		# Settle down to 1.0
		var settle_tween := create_tween()
		settle_tween.tween_interval(0.35)
		settle_tween.tween_property(gun_image, "scale", Vector2.ONE, 0.25) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)

		# Shader Flash
		if gun_image.material:
			var flash_tween := create_tween()
			flash_tween.tween_property(gun_image, "material:shader_parameter/flash_amount", 1.0, 0.18) \
				.set_trans(Tween.TRANS_LINEAR).set_ease(Tween.EASE_OUT)
			flash_tween.tween_property(gun_image, "material:shader_parameter/flash_amount", 0.0, 0.45) \
				.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

		# Gentle idle floating & tilt sway
		_idle_tween = create_tween().set_loops()
		_idle_tween.tween_property(gun_image, "position:y", _gun_orig_pos.y - 10.0, 1.4) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		_idle_tween.parallel().tween_property(gun_image, "rotation", -0.22, 1.4) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		_idle_tween.tween_property(gun_image, "position:y", _gun_orig_pos.y + 10.0, 1.4) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		_idle_tween.parallel().tween_property(gun_image, "rotation", -0.13, 1.4) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	# 5. Congratulations Label slide-down bounce
	if congratulations_label:
		var label_tween := create_tween()
		label_tween.tween_interval(0.15)
		label_tween.set_parallel(true)
		label_tween.tween_property(congratulations_label, "scale", Vector2.ONE, 0.35) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		label_tween.tween_property(congratulations_label, "modulate:a", 1.0, 0.25) \
			.set_trans(Tween.TRANS_LINEAR).set_ease(Tween.EASE_IN)

	if skin_name_label:
		var sname_tween := create_tween()
		sname_tween.tween_interval(0.2)
		sname_tween.set_parallel(true)
		sname_tween.tween_property(skin_name_label, "scale", Vector2.ONE, 0.35) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		sname_tween.tween_property(skin_name_label, "modulate:a", 1.0, 0.25) \
			.set_trans(Tween.TRANS_LINEAR).set_ease(Tween.EASE_IN)

	# 6. Equip Button slide-up bounce + pulsing loop
	if equip_button:
		var btn_tween := create_tween()
		btn_tween.tween_interval(0.28)
		btn_tween.set_parallel(true)
		btn_tween.tween_property(equip_button, "scale", Vector2.ONE, 0.35) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		btn_tween.tween_property(equip_button, "modulate:a", 1.0, 0.25) \
			.set_trans(Tween.TRANS_LINEAR).set_ease(Tween.EASE_IN)

		_button_pulse_tween = create_tween().set_loops()
		_button_pulse_tween.tween_property(equip_button, "scale", Vector2(1.06, 1.06), 0.7) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		_button_pulse_tween.tween_property(equip_button, "scale", Vector2(0.98, 0.98), 0.7) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	# Cooldown to allow full viewing experience
	get_tree().create_timer(0.45).timeout.connect(func():
		_can_dismiss = true
	)


func _kill_tweens() -> void:
	if _intro_tween and _intro_tween.is_valid():
		_intro_tween.kill()
	if _idle_tween and _idle_tween.is_valid():
		_idle_tween.kill()
	if _rays_tween and _rays_tween.is_valid():
		_rays_tween.kill()
	if _glow_tween and _glow_tween.is_valid():
		_glow_tween.kill()
	if _button_pulse_tween and _button_pulse_tween.is_valid():
		_button_pulse_tween.kill()


func _on_equip_pressed() -> void:
	if _is_gun_unlock:
		GameManager.save_manager.select_gun(_gunindex)
		GameManager.save_manager.skin_select(_gunindex, 0)
		GameManager.save_manager.gun_list_updated.emit()
		GameManager.save_manager.skin_list_updated.emit()
	else:
		GameManager.save_manager.skin_select(_gunindex, _skinindex)
		GameManager.save_manager.skin_list_updated.emit()

	if equip_button:
		equip_button.text = "EQUIPPED"
		equip_button.disabled = true

	# Play punch button scale
	var t := create_tween()
	t.tween_property(equip_button, "scale", Vector2(1.2, 1.2), 0.1).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(equip_button, "scale", Vector2.ONE, 0.15).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await t.finished

	_animate_close()


func _on_overlay_pressed() -> void:
	if not _can_dismiss:
		return
	_animate_close()


func _on_panel_gui_input(event: InputEvent) -> void:
	if not _can_dismiss:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_animate_close()


func _input(event: InputEvent) -> void:
	if not visible or not _can_dismiss or not event is InputEventMouseButton or event.button_index != MOUSE_BUTTON_LEFT or not event.pressed:
		return
	if equip_button and equip_button.get_global_rect().has_point(event.position):
		return
	_animate_close()


func _animate_close() -> void:
	_kill_tweens()
	_can_dismiss = false
	var close_tween := create_tween()
	close_tween.set_parallel(true)
	if card_container:
		close_tween.tween_property(card_container, "scale", Vector2(0.6, 0.6), 0.2) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
		close_tween.tween_property(card_container, "modulate:a", 0.0, 0.18) \
			.set_trans(Tween.TRANS_LINEAR)
	
	await close_tween.finished
	hide_popup()
