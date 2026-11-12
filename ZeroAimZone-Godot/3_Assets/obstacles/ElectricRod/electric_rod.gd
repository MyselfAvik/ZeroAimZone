class_name ElectricRodPiece
extends Node2D

signal rod_hit(rod, body)

@export var rod_sprite: Sprite2D
@export var lightning: Node2D
@export var area: Area2D
@export var body: StaticBody2D
@onready var collision: CollisionShape2D = $Area2D/CollisionShape2D

@export var damage: int = 10
@export var knockback := 1000
@export var torque := 50.0
@export var stun_time := 0.15

var is_active: bool = false

func _ready() -> void:
	area.monitoring = false
	collision.disabled = true
	area.body_entered.connect(_on_body_entered)

func activate() -> void:
	is_active = true
	area.monitoring = true
	collision.disabled = false
	if lightning:
		lightning.start()

func deactivate() -> void:
	is_active = false
	area.monitoring = false
	collision.disabled = true
	if lightning:
		lightning.stop()

func _on_body_entered(hit_body: Node) -> void:
	if !is_active:
		return
	emit_signal("rod_hit", self, hit_body)
