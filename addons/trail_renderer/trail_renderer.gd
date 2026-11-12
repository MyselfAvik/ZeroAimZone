@tool
class_name TrailRenderer
extends Node2D

@export var trail_length: int = 20
@export var trail_width: int = 5
@export var trail_color: Color = Color.GHOST_WHITE

var trail: Line2D

func _ready() -> void:
	trail = Line2D.new()
	trail.width = trail_width
	trail.default_color = trail_color

	var curve = Curve.new()
	curve.add_point(Vector2(0.0, 1.0))
	curve.add_point(Vector2(1.0, 0.0))
	trail.width_curve = curve

	get_tree().root.call_deferred("add_child", trail)

func _physics_process(_delta: float) -> void:
	if trail == null:
		return
	trail.add_point(global_position, 0)
	if trail.get_point_count() > trail_length:
		trail.remove_point(trail.get_point_count() - 1)

func _exit_tree():
	if trail:
		trail.queue_free()
