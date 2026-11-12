@tool
extends EditorPlugin

func _enter_tree() -> void:
	# Register the custom node
	# Args: name, parent_type, script, icon
	add_custom_type(
		"TrailRenderer",          # Node name shown in editor
		"Node2D",                 # What it inherits (or Node3D for 3D)
		preload("trail_renderer.gd"),
		preload("trail_renderer.png")  # optional, else pass null
	)

func _exit_tree() -> void:
	remove_custom_type("TrailRenderer")
