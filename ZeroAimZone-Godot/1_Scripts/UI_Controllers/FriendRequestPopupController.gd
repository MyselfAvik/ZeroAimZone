class_name FriendRequestPopupController
extends BasePopupController


@export var accept_btn:Button
@export var reject_btn:Button

@export var name_label:Label
@export var timer_label: Label
@export var timer_progress_bar: TextureProgressBar
@export var countdown_timer: Timer

var challenger_id: int = 0
var timer_value: int = 10

func setup(data:Dictionary):
	challenger_id=data["challenger_id"]
	name_label.text=data["challenger_name"]+" Challanged You"
	_start_countdown()

func _start_countdown() -> void:
	timer_value = 10
	timer_label.text = str(timer_value)
	timer_progress_bar.value = timer_progress_bar.max_value
	countdown_timer.wait_time = 1.0
	countdown_timer.one_shot = false
	if not countdown_timer.timeout.is_connected(_on_countdown_tick):
		countdown_timer.timeout.connect(_on_countdown_tick)
	countdown_timer.start()

func _on_countdown_tick() -> void:
	timer_value -= 1
	timer_label.text = str(timer_value)

	var target_value = timer_value * 10
	var progress_tween = create_tween()
	progress_tween.tween_property(timer_progress_bar,"value",target_value, 1.0)\
	.set_trans(Tween.TRANS_QUART)\
	.set_ease(Tween.EASE_OUT)

	if timer_value <= 0:
		countdown_timer.stop()
		_on_reject_button_pressed()

func _on_accept_button_pressed() -> void:
	countdown_timer.stop()
	GameAnalysis.track_ui_click("UI:Clicks:Challenge:Accept")
	if multiplayer.has_multiplayer_peer() and is_instance_valid(GameManager.network_handler):
		var accepter_id = multiplayer.get_unique_id()
		if multiplayer.is_server():
			GameManager.network_handler.accept_challenge(challenger_id, accepter_id)
		else:
			GameManager.network_handler.accept_challenge.rpc_id(1, challenger_id, accepter_id)
	
	var base_panel = GameManager.ui_manager.base_panel if is_instance_valid(GameManager.ui_manager) else null
	if base_panel and is_instance_valid(base_panel.friend_panel):
		base_panel.friend_panel.cancel_all_pending_challenges()
	
	queue_free()


func _on_reject_button_pressed() -> void:
	countdown_timer.stop()
	GameAnalysis.track_ui_click("UI:Clicks:Challenge:Reject")
	if multiplayer.has_multiplayer_peer() and is_instance_valid(GameManager.network_handler):
		var my_id = multiplayer.get_unique_id()
		if multiplayer.is_server():
			GameManager.network_handler.reject_challenge(challenger_id, my_id)
		else:
			GameManager.network_handler.reject_challenge.rpc_id(1, challenger_id, my_id)
	queue_free()

func expire() -> void:
	if is_instance_valid(countdown_timer):
		countdown_timer.stop()
	challenger_id = 0
	if is_instance_valid(GameManager.ui_manager) and is_instance_valid(GameManager.ui_manager.popup_panel):
		GameManager.ui_manager.popup_panel.hide_popup()
	queue_free()
