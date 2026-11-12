class_name LaserObstacle
extends ObstacleController

@export var off_time := 2.0
@export var warning_time := 1.0
@export var damage: int = 2
@export var laser_on_time := 2.0
@export var cross_warning_time := 0.5
@export var cross_hold_time := 2.5   
@export var damage_tick_rate: float = 0.1
@export var stun_time: float = 0.0

var _damage_tick_timer: float = 0.0

@export var fire_sound: AudioStream

@onready var d1_a = $Diagonal1/MachineA
@onready var d1_a_off = $Diagonal1/MachineAOff
@onready var d1_beam: LaserBeamVFX = $Diagonal1/LaserBeamVfx
@onready var d1_hitbox = $Diagonal1/LaserHitBox
@onready var d1_muzzle_a = $Diagonal1/MachineA/Muzzle

@onready var d2_a = $Diagonal2/MachineA
@onready var d2_a_off = $Diagonal2/MachineAOff
@onready var d2_beam: LaserBeamVFX = $Diagonal2/LaserBeamVfx
@onready var d2_hitbox = $Diagonal2/LaserHitBox
@onready var d2_muzzle_a = $Diagonal2/MachineA/Muzzle

var is_running := true
var audio_player: AudioStreamPlayer2D

func _ready() -> void:
	audio_player = AudioStreamPlayer2D.new()
	audio_player.max_distance = 10000.0
	if AudioServer.get_bus_index("SFX") != -1:
		audio_player.bus = "SFX"
	else:
		audio_player.bus = "Master"
	add_child(audio_player)

func initialize(level: Node) -> void:
	var spawn_container = level.get_node("ObstacleSpawnPoints")
	var points: Array[Marker2D] = []
	for child in spawn_container.get_children():
		if child is Marker2D and child.name.begins_with("LaserSpawn"):
			points.append(child)
	if points.size() < 4:
		push_error("LaserObstacle needs 4 corner spawn points")
		return

	var used := []
	var pairs := []
	for i in points.size():
		if i in used:
			continue
		var best_j := -1
		var best_dist := -1.0
		for j in points.size():
			if j == i or j in used:
				continue
			var d = points[i].global_position.distance_to(points[j].global_position)
			if d > best_dist:
				best_dist = d
				best_j = j
		pairs.append([points[i], points[best_j]])
		used.append(i); used.append(best_j)

	
	_setup_diagonal(pairs[0][0], pairs[0][1], d1_a, d1_a_off, d1_muzzle_a, d1_beam, d1_hitbox)
	_setup_diagonal(pairs[1][0], pairs[1][1], d2_a, d2_a_off, d2_muzzle_a, d2_beam, d2_hitbox)

	_set_diagonal_off(d1_a, d1_a_off, d1_beam, d1_hitbox)
	_set_diagonal_off(d2_a, d2_a_off, d2_beam, d2_hitbox)

	start_cycle()

func _physics_process(delta: float) -> void:
	if not is_running:
		return
		
	_damage_tick_timer -= delta
	if _damage_tick_timer <= 0.0:
		_damage_tick_timer = damage_tick_rate
		if d1_hitbox.monitoring:
			_apply_area_damage(d1_hitbox)
		if d2_hitbox.monitoring:
			_apply_area_damage(d2_hitbox)

func _apply_area_damage(hitbox: Area2D) -> void:
	for body in hitbox.get_overlapping_bodies():
		obstacle_hit.emit(self, body)
		if body.has_method("apply_impact"):
			body.apply_impact(damage, global_position, 0, 0, stun_time)

func _setup_diagonal(pa: Marker2D, pb: Marker2D, machine_a: Node2D, machine_a_off: Node2D, muzzle_a: Node2D, beam: LaserBeamVFX, hitbox: Area2D) -> void:
	machine_a.global_position = pa.global_position
	machine_a_off.global_position = pa.global_position
	
	var p_start = beam.get_parent().to_local(muzzle_a.global_position)
	var p_end = beam.get_parent().to_local(pb.global_position)
	
	beam.setup(p_start, p_end)
	
	hitbox.position = (p_start + p_end) / 2.0
	hitbox.rotation = p_start.angle_to_point(p_end)
	var col_shape = hitbox.get_node_or_null("CollisionShape2D")
	if col_shape and col_shape.shape is RectangleShape2D:
		var new_shape = col_shape.shape.duplicate()
		new_shape.size.x = p_start.distance_to(p_end)
		col_shape.shape = new_shape
		col_shape.position = Vector2.ZERO
		col_shape.rotation = 0.0
		col_shape.scale = Vector2.ONE

func stop() -> void:
	is_running = false

func start_cycle() -> void:
	while is_running:
		# Phase 1: Diagonal1 fires alone
		await _warmup_diagonal(d1_a, d1_a_off)
		if !is_running: return
		_fire_diagonal(d1_beam, d1_hitbox, true)
		await get_tree().create_timer(laser_on_time).timeout
		if !is_running: return
		_fire_diagonal(d1_beam, d1_hitbox, false)
		_set_diagonal_off(d1_a, d1_a_off, d1_beam, d1_hitbox)

		await get_tree().create_timer(off_time).timeout
		if !is_running: return

		# Phase 2: Diagonal2 fires alone
		await _warmup_diagonal(d2_a, d2_a_off)
		if !is_running: return
		_fire_diagonal(d2_beam, d2_hitbox, true)
		await get_tree().create_timer(laser_on_time).timeout
		if !is_running: return
		_fire_diagonal(d2_beam, d2_hitbox, false)
		_set_diagonal_off(d2_a, d2_a_off, d2_beam, d2_hitbox)

		await get_tree().create_timer(off_time).timeout
		if !is_running: return

		# Phase 3: Both diagonals fire together (X formation)
		_show_on(d1_a, d1_a_off)
		_show_on(d2_a, d2_a_off)
		await get_tree().create_timer(cross_warning_time).timeout
		if !is_running: return

		_fire_diagonal(d1_beam, d1_hitbox, true)
		_fire_diagonal(d2_beam, d2_hitbox, true)
		await get_tree().create_timer(cross_hold_time).timeout
		if !is_running: return

		_fire_diagonal(d1_beam, d1_hitbox, false)
		_fire_diagonal(d2_beam, d2_hitbox, false)
		_set_diagonal_off(d1_a, d1_a_off, d1_beam, d1_hitbox)
		_set_diagonal_off(d2_a, d2_a_off, d2_beam, d2_hitbox)

		await get_tree().create_timer(off_time).timeout

func _warmup_diagonal(a, a_off) -> void:
	_show_on(a, a_off)
	await get_tree().create_timer(warning_time).timeout

func _fire_diagonal(beam: LaserBeamVFX, hitbox, active: bool) -> void:
	beam.set_active(active)
	hitbox.monitoring = active
	
	if active:
		_damage_tick_timer = 0.0
		if fire_sound and not audio_player.playing:
			if AudioPlayer.sound_enabled:
				audio_player.stream = fire_sound
				audio_player.play()
		AudioPlayer.duck_music()
	else:
		if not d1_hitbox.monitoring and not d2_hitbox.monitoring:
			audio_player.stop()
		AudioPlayer.unduck_music()

func _set_diagonal_off(a, a_off, beam: LaserBeamVFX, hitbox) -> void:
	_show_off(a, a_off)
	beam.set_active(false)
	hitbox.monitoring = false

func _show_off(a, a_off) -> void:
	a.visible = false
	a_off.visible = true

func _show_on(a, a_off) -> void:
	a.visible = true
	a_off.visible = false

# Replaced with _apply_area_damage for continuous overlapping checks
# func _on_body_entered(body: Node) -> void:
# 	obstacle_hit.emit(self, body)
# 	if body.has_method("apply_impact"):
# 		body.apply_impact(damage, global_position, 0, 0, 0.2)
