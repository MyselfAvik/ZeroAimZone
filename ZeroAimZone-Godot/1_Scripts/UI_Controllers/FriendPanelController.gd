class_name FriendPanelController
extends Control

@export var create_btn:TextureButton
@export var close_btn:TextureButton

@export var none:Label

@export var friend_list:VBoxContainer

@export var friend_card:PackedScene
@export var loading:TextureRect
@export var error:Label

var pending_challenge_cards: Dictionary = {}
var pending_challenges: Dictionary = {}
var _loading_tween: Tween = null


func _ready() -> void:
	reset()
	if not visibility_changed.is_connected(_on_visibility_changed):
		visibility_changed.connect(_on_visibility_changed)

func _on_visibility_changed() -> void:
	if not is_visible_in_tree():
		cancel_all_pending_challenges()
		_stop_loading_animation()

func _start_loading_animation() -> void:
	if not is_instance_valid(loading):
		return
	loading.pivot_offset = loading.size * 0.5
	loading.rotation = 0.0
	loading.visible = true

	if _loading_tween and _loading_tween.is_valid():
		_loading_tween.kill()

	_loading_tween = create_tween().set_loops()
	_loading_tween.tween_property(loading, "rotation", TAU, 1.2).from(0.0).set_trans(Tween.TRANS_LINEAR)

func _stop_loading_animation() -> void:
	if _loading_tween and _loading_tween.is_valid():
		_loading_tween.kill()
	_loading_tween = null
	if is_instance_valid(loading):
		loading.visible = false
		loading.rotation = 0.0

func reset():
	if GameManager and GameManager.current_match:
		GameManager.current_match.entry_fee = 0
		GameManager.current_match.coin_reward = 0
	cancel_all_pending_challenges()
	clear_cards()
	_stop_loading_animation()
	error.visible = false
	create_btn.visible = true
	create_btn.disabled = false
	if create_btn.get_child_count() > 0 and create_btn.get_child(0) is Label:
		create_btn.get_child(0).text = "Create"
	close_btn.visible = false
	none.visible = true

func _on_create_room_btn_pressed() -> void:
	if GameManager and GameManager.current_match:
		GameManager.current_match.entry_fee = 0
		GameManager.current_match.coin_reward = 0
	GameAnalysis.track_ui_click("UI:Clicks:PrivateRoom:CreateRoom")
	error.visible = false
	none.visible = false
	_start_loading_animation()
	create_btn.visible = true
	create_btn.disabled = true
	if create_btn.get_child_count() > 0 and create_btn.get_child(0) is Label:
		create_btn.get_child(0).text = "Waiting"
	close_btn.visible = false

	if not await GameManager.network_handler.start_host():
		_stop_loading_animation()
		create_btn.disabled = false
		create_btn.visible = true
		close_btn.visible = false
		error.visible = true
		if create_btn.get_child_count() > 0 and create_btn.get_child(0) is Label:
			create_btn.get_child(0).text = "Try Again"
		return
		
	error.visible = false
	_stop_loading_animation()
	create_btn.visible = false
	close_btn.visible = true
	


func is_room_active() -> bool:
	if close_btn != null and close_btn.visible:
		return true
	if loading != null and loading.visible:
		return true
	if create_btn != null and create_btn.get_child_count() > 0 and create_btn.get_child(0) is Label:
		if create_btn.get_child(0).text == "Waiting":
			return true
	return false

func _on_cancel_room_btn_pressed() -> void:
	GameManager.ui_manager.popup_panel.show_popup(PopupPanelController.PopupType.ROOMCLOSE)


func clear_cards():
	for i in friend_list.get_children():
		if is_instance_valid(i):
			i.queue_free()
	pending_challenge_cards.clear()

func add_cards(id: int, _name: String):
	var card: FriendCardController = friend_card.instantiate()
	card.challange_btn.pressed.connect(_on_challenge_pressed.bind(id,GameManager.save_manager.game_data["player_data"]["name"], card))
	card.friend_name.text = str(_name)
	friend_list.add_child(card)

func _on_challenge_pressed(id: int,_name:String, card: FriendCardController):
	GameAnalysis.track_ui_click("UI:Clicks:PrivateRoom:SendChallenge")
	card.challange_btn.text = "Sent"
	card.challange_btn.disabled = true
	pending_challenge_cards[id] = card
	request_challenge.rpc_id(1, id,_name)

func reset_challenge_button(target_id: int) -> void:
	if pending_challenge_cards.has(target_id):
		var card = pending_challenge_cards.get(target_id, null)
		if is_instance_valid(card):
			card.challange_btn.text = "Challenge"
			card.challange_btn.disabled = false
		pending_challenge_cards.erase(target_id)

func cancel_all_pending_challenges() -> void:
	if multiplayer.has_multiplayer_peer() and multiplayer.multiplayer_peer != null and multiplayer.multiplayer_peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED:
		var my_id = multiplayer.get_unique_id()
		for target_id in pending_challenge_cards.keys():
			if multiplayer.is_server():
				cancel_challenge(target_id, my_id)
			else:
				cancel_challenge.rpc_id(1, target_id, my_id)

		if multiplayer.is_server():
			for target_id in pending_challenges.keys():
				_deliver_challenge_expired.rpc_id(target_id, pending_challenges[target_id])

	for target_id in pending_challenge_cards.keys():
		var card = pending_challenge_cards.get(target_id, null)
		if is_instance_valid(card):
			card.challange_btn.text = "Challenge"
			card.challange_btn.disabled = false

	pending_challenge_cards.clear()
	pending_challenges.clear()

@rpc("any_peer", "call_local", "reliable")
func cancel_challenge(target_id: int, from_challenger_id: int):
	if not multiplayer.is_server():
		return
	if pending_challenges.has(target_id) and pending_challenges[target_id] == from_challenger_id:
		pending_challenges.erase(target_id)
	_deliver_challenge_expired.rpc_id(target_id, from_challenger_id)

@rpc("authority", "call_local", "reliable")
func _deliver_challenge_expired(from_challenger_id: int):
	print("[FRIEND] Challenge from ", from_challenger_id, " expired/cancelled")
	var popup_panel = GameManager.ui_manager.popup_panel if is_instance_valid(GameManager.ui_manager) else null
	if popup_panel and is_instance_valid(popup_panel.freind_request_popup):
		var req = popup_panel.freind_request_popup
		if req.challenger_id == from_challenger_id or from_challenger_id == -1:
			req.expire()

@rpc("any_peer", "call_local", "reliable")
func request_challenge(target_id: int,_name:String):
	if not multiplayer.is_server():
		return 
	var challenger_id = multiplayer.get_remote_sender_id()
	# If target already has a pending challenge from someone else,
	# auto-reject that earlier challenger first
	if pending_challenges.has(target_id):
		var previous_challenger_id: int = pending_challenges[target_id]
		if previous_challenger_id != challenger_id:
			GameManager.network_handler._deliver_rejection.rpc_id(previous_challenger_id, target_id)

	pending_challenges[target_id] = challenger_id
	_deliver_challenge.rpc_id(target_id,challenger_id,_name)

@rpc("authority", "call_local", "reliable")
func _deliver_challenge(id:int,_name:String):
	var popup_panel = GameManager.ui_manager.popup_panel
	if not is_instance_valid(popup_panel.freind_request_popup):
		var popup_scene = load("res://ZeroAimZone-Godot/2_Prefabs/UI/Popups/friend_request_popup.tscn")
		var popup_instance = popup_scene.instantiate()
		popup_panel.add_child(popup_instance)
		popup_panel.freind_request_popup = popup_instance
		popup_panel.popup_map[PopupPanelController.PopupType.FRIENDREQUEST] = popup_instance
		
	GameManager.show_popup(PopupPanelController.PopupType.FRIENDREQUEST)
	popup_panel.freind_request_popup.setup({
		"challenger_id":id,
		"challenger_name":_name
	})
