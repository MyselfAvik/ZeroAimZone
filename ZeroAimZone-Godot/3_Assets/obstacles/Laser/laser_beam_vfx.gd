extends Node2D
class_name LaserBeamVFX

@export var color := Color(1.0, 0.05, 0.05, 1.0) : set = set_color
@export var line_width := 85.0
@export var growth_time := 0.12

@onready var line_2d: Line2D = %Line2D
@onready var start_muzzle_orb: Node2D = %StartMuzzleOrb
@onready var end_muzzle_orb: Node2D = %EndMuzzleOrb
@onready var casting_particles: CPUParticles2D = %CastingParticles2D
@onready var beam_particles: CPUParticles2D = %BeamParticles2D
@onready var impact_particles: CPUParticles2D = %ImpactParticles2D
@onready var beam_cast: RayCast2D = %BeamCast

var tween: Tween
var _start_point := Vector2.ZERO
var _max_end_point := Vector2.ZERO 
var _last_end_point := Vector2.INF

func _ready() -> void:
	line_2d.visible = false
	if start_muzzle_orb:
		start_muzzle_orb.scale = Vector2.ZERO
	if end_muzzle_orb:
		end_muzzle_orb.scale = Vector2.ZERO
	set_color(color)
	set_physics_process(false)

func setup(start_point: Vector2, end_point: Vector2) -> void:
	_start_point = start_point
	_max_end_point = end_point
	_last_end_point = Vector2.INF
	if start_muzzle_orb:
		start_muzzle_orb.position = start_point
	if end_muzzle_orb:
		end_muzzle_orb.position = end_point
	casting_particles.position = start_point
	beam_cast.position = start_point
	beam_cast.target_position = end_point - start_point
	_update_beam(end_point)

func set_active(active: bool) -> void:
	casting_particles.emitting = active
	if beam_particles:
		beam_particles.emitting = active
	set_physics_process(active)
	if active:
		_last_end_point = Vector2.INF
		_appear()
	else:
		impact_particles.emitting = false
		_disappear()

func _physics_process(_delta: float) -> void:
	var current_end := _max_end_point
	if beam_cast.is_colliding():
		current_end = to_local(beam_cast.get_collision_point())
	
	if current_end.distance_squared_to(_last_end_point) > 1.0:
		_last_end_point = current_end
		_update_beam(current_end)
		if end_muzzle_orb:
			end_muzzle_orb.position = current_end
		impact_particles.position = current_end

	if not impact_particles.emitting:
		impact_particles.emitting = true
	
func _update_beam(end_point: Vector2) -> void:
	line_2d.points = PackedVector2Array([_start_point, end_point])
	if beam_particles:
		beam_particles.position = (_start_point + end_point) * 0.5
		beam_particles.rotation = _start_point.angle_to_point(end_point)
		beam_particles.emission_rect_extents.x = _start_point.distance_to(end_point) * 0.5
			
func _appear() -> void:
	line_2d.visible = true
	if tween and tween.is_running():
		tween.kill()
	tween = create_tween().set_parallel(true)
	tween.tween_property(line_2d, "width", line_width, growth_time).from(0.0)
	if start_muzzle_orb:
		tween.tween_property(start_muzzle_orb, "scale", Vector2.ONE, growth_time).from(Vector2.ZERO).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if end_muzzle_orb:
		tween.tween_property(end_muzzle_orb, "scale", Vector2.ONE, growth_time).from(Vector2.ZERO).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _disappear() -> void:
	if tween and tween.is_running():
		tween.kill()
	tween = create_tween().set_parallel(true)
	tween.tween_property(line_2d, "width", 0.0, growth_time).from_current()
	if start_muzzle_orb:
		tween.tween_property(start_muzzle_orb, "scale", Vector2.ZERO, growth_time).from_current()
	if end_muzzle_orb:
		tween.tween_property(end_muzzle_orb, "scale", Vector2.ZERO, growth_time).from_current()
	tween.chain().tween_callback(line_2d.hide)

func set_color(new_color: Color) -> void:
	color = new_color
	if line_2d == null:
		return
	if line_2d.material is ShaderMaterial:
		line_2d.material.set_shader_parameter("beam_color", color)
	else:
		line_2d.modulate = color
	
	if start_muzzle_orb and start_muzzle_orb.has_node("OuterGlow"):
		start_muzzle_orb.get_node("OuterGlow").modulate = color * 1.8
	if end_muzzle_orb and end_muzzle_orb.has_node("OuterGlow"):
		end_muzzle_orb.get_node("OuterGlow").modulate = color * 1.8
