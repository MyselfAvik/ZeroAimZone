extends Node2D
@onready var particles := $CPUParticles2D as CPUParticles2D

func _ready() -> void:
	if particles:
		particles.emitting = true
		particles.finished.connect(queue_free)
