extends Node2D

@onready var mat1 := $ColorRect.material as ShaderMaterial
#@onready var mat2 := $ColorRect2.material as ShaderMaterial

var _tween: Tween
var _looping := false

func _ready() -> void:
	visible = false

func start(duration: float = 0.15, gap: float = 0.05) -> void:
	_looping = true
	visible = true
	_run_cycle(duration, gap)

func stop() -> void:
	_looping = false
	if _tween:
		_tween.kill()
	mat1.set_shader_parameter("progress", 0.0)
	#mat2.set_shader_parameter("progress", 0.0)
	visible = false

func _run_cycle(duration: float, gap: float) -> void:
	if not _looping:
		return
	mat1.set_shader_parameter("progress", 0.0)
	#mat2.set_shader_parameter("progress", 0.0)
	_tween = create_tween()
	_tween.parallel().tween_property(mat1, "shader_parameter/progress", 1.0, duration)
	#_tween.parallel().tween_property(mat2, "shader_parameter/progress", 1.0, duration)
	await _tween.finished
	if not _looping:
		return
	await get_tree().create_timer(gap).timeout
	_run_cycle(duration, gap)
