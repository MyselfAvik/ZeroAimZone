class_name RoundCountdownController
extends BasePopupController


@export var countdown: Label
@export var result_label: Label
@export var round_name_label: Label
@export var bg_overlay: TextureRect
@export var gameplay_bg: TextureRect
@export var countdown_color: Array[Color]

var target_position

func _ready() -> void:
	super._ready()
	target_position = round_name_label.position
	round_name_label.visible = false
	round_name_label.modulate.a = 0.0
	visibility_changed.connect(_is_visible_in_tree)

func _is_visible_in_tree() -> void:
	var gameplay_panel = GameManager.in_game_ui.gameplay_panel
	if gameplay_panel.ingame_setting_panel.visible:
		gameplay_panel.ingame_setting_panel.visible = false

func _update_ui(current_round: int) -> void:
	var bg_color: Color
	if GameManager.current_state == GameManager.GameState.IN_GAME_MULTIPLAYER:
		var match_data = {}
		if is_instance_valid(GameManager.network_handler):
			match_data = GameManager.network_handler.local_match_data
		bg_color = Color(match_data.get("arena_gameplay_color", "#de587e"))
	else:
		bg_color = GameManager.current_match.arena_gameplay_color if GameManager.current_match else Color("#de587e")

	bg_overlay.self_modulate = bg_color
	if gameplay_bg:
		gameplay_bg.self_modulate = bg_color

func start_countdown(current_round:int, res:bool):
	_update_ui(current_round)
	show()
	countdown.visible=false
	await  result_label.play_round_animation(res)
	await move_round_label_in(current_round)
	countdown.visible=true
	
	for i in range(3, 0, -1):
		countdown.text = str(i)
		countdown.self_modulate = countdown_color[i-1]
		countdown.pivot_offset = countdown.size * 0.5
		countdown.scale = Vector2(0.2, 0.2)

		var tween = create_tween()
		tween.tween_property(countdown, "scale", Vector2(1, 1), 0.25) \
			.set_trans(Tween.TRANS_BACK) \
			.set_ease(Tween.EASE_OUT)

		await tween.finished

		if i > 1:
			await get_tree().create_timer(0.75).timeout

	await move_round_label_out()
	hide()

func move_round_label_in(current_round: int) -> void:
	round_name_label.text = "ROUND " + str(current_round + 1)
	round_name_label.visible = true
	round_name_label.modulate.a = 0.0
	round_name_label.position = target_position

	var tween := create_tween()
	tween.tween_property(
		round_name_label,
		"modulate:a",
		1.0,
		0.5
	).set_trans(Tween.TRANS_LINEAR).set_ease(Tween.EASE_IN_OUT)

	await tween.finished


func move_round_label_out() -> void:
	var tween := create_tween()
	tween.tween_property(
		round_name_label,
		"modulate:a",
		0.0,
		0.5
	).set_trans(Tween.TRANS_LINEAR).set_ease(Tween.EASE_IN_OUT)

	await tween.finished

	round_name_label.visible = false
