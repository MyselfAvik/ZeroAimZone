extends GunBase

enum AIState {BURST, SEEKING}

@export_group("AI Behavior - Base (Easy) Stats")
@export var base_shots_min: int = 1
@export var base_shots_max: int = 2
@export var base_seek_interval: float = 0.2
@export var base_seek_timeout: float = 2.2
@export var base_sight_radius: float = 12.0
@export var base_fire_delay_mult: float = 1.0   # multiplies gun_data's own delays
@export var base_reaction_delay: float = 0.35   # extra hesitation before first shot

@export_group("AI Behavior - Max (Hard) Stats")
@export var max_shots_min: int = 3
@export var max_shots_max: int = 5
@export var max_seek_interval: float = 0.05
@export var max_seek_timeout: float = 1.0
@export var max_sight_radius: float = 30.0
@export var max_fire_delay_mult: float = 0.35
@export var max_reaction_delay: float = 0.0

@export_group("AI Behavior - Difficulty Scaling")
@export var level_weight: float = 0.6      # how much player level contributes
@export var entry_fee_weight: float = 0.4  # how much stake contributes
@export var level_soft_cap: float = 100   # level at which level-contribution saturates
@export var fee_soft_cap: float = 800   # fee at which fee-contribution saturates

@export var sight_distance: float = 1200.0
@export var target_group: StringName = &"player"

## Base per-shot delay range BEFORE the difficulty multiplier is applied.
## Easy (mult ~1.0) stays above continuous_fire_window (0.25s in GunBase)
## so easy enemies fire single, normal-recoil shots. Hard (mult ~0.35)
## dips below it during bursts, so hard enemies trigger the same
## continuous-fire forward-thrust behavior the player gets from rapid tapping.
@export var min_fire_delay: float = 0.35
@export var max_fire_delay: float = 0.65

var _difficulty: float = 0.0  # 0 = weakest, 1 = strongest

# runtime (resolved from base/max via difficulty)
var shots_before_seek_min: int
var shots_before_seek_max: int
var seek_check_interval: float
var seek_timeout: float
var sight_radius: float
var _fire_delay_mult: float
var _reaction_delay: float

var _state: AIState = AIState.BURST
var _shots_left: int = 0
var _seek_elapsed: float = 0.0
var _sight_cast: ShapeCast2D

func _ready():
	super()
	add_to_group("enemy")
	_apply_difficulty()
	_build_sight_cast()
	_start_new_burst()
	fire_loop()
	


## Call this from your spawner BEFORE _ready runs (or right after instancing,
## before add_child) with the player's level and the arena's entry fee.
func configure_difficulty(player_level: int, entry_fee: float) -> void:
	var level_t = clamp(float(player_level) / level_soft_cap, 0.0, 1.0)
	var fee_t = clamp(entry_fee / fee_soft_cap, 0.0, 1.0)

	# Weighted blend, then a slight curve so mid-tier games aren't already brutal.
	var raw = level_t * level_weight + fee_t * entry_fee_weight
	_difficulty = clamp(pow(raw, 0.8), 0.0, 1.0)
	_apply_difficulty()


func _apply_difficulty() -> void:
	shots_before_seek_min = int(round(lerp(float(base_shots_min), float(max_shots_min), _difficulty)))
	shots_before_seek_max = int(round(lerp(float(base_shots_max), float(max_shots_max), _difficulty)))
	seek_check_interval = lerp(base_seek_interval, max_seek_interval, _difficulty)
	seek_timeout = lerp(base_seek_timeout, max_seek_timeout, _difficulty)
	sight_radius = lerp(base_sight_radius, max_sight_radius, _difficulty)
	_fire_delay_mult = lerp(base_fire_delay_mult, max_fire_delay_mult, _difficulty)
	_reaction_delay = lerp(base_reaction_delay, max_reaction_delay, _difficulty)

	# If your GunData has damage/spread, scale those too, e.g.:
	# gun_data.damage = lerp(base_damage, max_damage, _difficulty)
	# gun_data.spread_degrees = lerp(base_spread, max_spread, _difficulty)

	if _sight_cast:
		(_sight_cast.shape as CapsuleShape2D).radius = sight_radius
		(_sight_cast.shape as CapsuleShape2D).height = sight_radius * 2.0


func _build_sight_cast() -> void:
	_sight_cast = ShapeCast2D.new()
	var shape := CapsuleShape2D.new()
	shape.radius = sight_radius
	shape.height = sight_radius * 2.0
	_sight_cast.shape = shape
	_sight_cast.target_position = Vector2(sight_distance, 0.0)
	_sight_cast.collision_mask = 0xFFFFFFFF
	_sight_cast.enabled = false
	fire_point.add_child(_sight_cast)
	_sight_cast.add_exception(self)


func _start_new_burst() -> void:
	_shots_left = randi_range(shots_before_seek_min, shots_before_seek_max)
	_state = AIState.BURST


func fire_loop() -> void:
	while not has_died:
		if _state == AIState.BURST:
			await _burst_tick()
		else:
			await _seek_tick()


func _burst_tick() -> void:
	# max() floor ensures the delay is never shorter than the gun's own
	# fire_cooldown — otherwise this AI value is silently overridden by
	# GunBase's throttling and difficulty tuning stops doing anything.
	var delay: float = max(
		randf_range(min_fire_delay, max_fire_delay) * _fire_delay_mult,
		fire_cooldown
	)
	await get_tree().create_timer(delay).timeout
	if not await _try_shoot():
		return
	_shots_left -= 1
	if _shots_left <= 0:
		_state = AIState.SEEKING
		_seek_elapsed = 0.0

func _on_Player_died() -> void:
	if not has_died:
		_state = AIState.SEEKING
		_seek_elapsed = seek_timeout

func load_gun_data(skin_index: int):
	super(skin_index)
	if gun_sprite:
		generate_collision_from_sprite(gun_sprite)

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
		

		var polygons = bitmap.opaque_to_polygons(Rect2(Vector2.ZERO, image.get_size()), 20.0)
		
		if polygons.size() == 0:
			return
			
		var largest_poly = polygons[0]
		for poly in polygons:
			if poly.size() > largest_poly.size():
				largest_poly = poly
		
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

func _seek_tick() -> void:
	await get_tree().create_timer(seek_check_interval).timeout
	_seek_elapsed += seek_check_interval
	if _has_line_on_target():
		if _reaction_delay > 0.0:
			await get_tree().create_timer(_reaction_delay).timeout
		if await _try_shoot():
			_start_new_burst()
			return
	if _seek_elapsed >= seek_timeout:
		_start_new_burst()


func _has_line_on_target() -> bool:
	_sight_cast.force_shapecast_update()
	if not _sight_cast.is_colliding():
		return false
	for i in _sight_cast.get_collision_count():
		var collider = _sight_cast.get_collider(i)
		if collider and collider.is_in_group(target_group):
			return true
	return false


func _try_shoot() -> bool:
	if is_reloading:
		await reload_finished
	var fired: bool = shoot(1)
	if not fired and is_reloading:
		await reload_finished
		fired = shoot(1)
	return fired
