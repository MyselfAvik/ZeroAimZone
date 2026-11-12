class_name LoadingPanelController
extends Control

@export var fire: TextureRect
@export var moving_bullet: TextureRect
@export var hand_with_gun: TextureRect

@export var bullet_start_x := 80.0
@export var bullet_end_x := 780.0

var current_progress: float = 0.0
var _is_data_fetched: bool = false
var _loading_tween: Tween = null

func start_loading() -> void:
	show()
	current_progress = 0.0
	_is_data_fetched = false
	_hide_auth_retry_popup()

	if GameAnalysis:
		GameAnalysis.track_ftue_step("loading_auth")

	if moving_bullet:
		moving_bullet.visible = true
		moving_bullet.position.x = bullet_start_x

	_play_gun_fire_animation()
	_listen_for_auth_sync()
	_start_progress_sequence()

func _play_gun_fire_animation() -> void:
	if fire:
		fire.modulate.a = 1.0
		var fire_tween = create_tween()
		fire_tween.tween_property(fire, "modulate:a", 0.0, 0.8).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

	if hand_with_gun:
		var gun_tween = create_tween()
		gun_tween.tween_property(hand_with_gun, "rotation", deg_to_rad(-25), 0.12).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		gun_tween.tween_property(hand_with_gun, "rotation", 0.0, 0.25).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func _listen_for_auth_sync() -> void:
	if AuthManager:
		var auth = AuthManager
		if auth.has_signal("initial_sync_completed") and not auth.initial_sync_completed.is_connected(_on_initial_sync_step):
			auth.initial_sync_completed.connect(_on_initial_sync_step)
		if auth.has_signal("auth_state_changed") and not auth.auth_state_changed.is_connected(_on_auth_state_changed):
			auth.auth_state_changed.connect(_on_auth_state_changed)
		if auth.has_signal("auth_error") and not auth.auth_error.is_connected(_on_auth_error):
			auth.auth_error.connect(_on_auth_error)
		if EventBus and EventBus.has_signal("auth_failed") and not EventBus.auth_failed.is_connected(_on_auth_failed):
			EventBus.auth_failed.connect(_on_auth_failed)

		if auth.is_authenticated() and auth.is_firestore_data_fetched:
			_on_data_fetch_completed(1.0)
			return
		elif auth.get("_first_auth_attempt_done") == true and not auth.is_authenticated() and not bool(auth.get("_is_auth_flow_running")):
			_show_auth_retry_popup()
	else:
		get_tree().create_timer(0.1).timeout.connect(_listen_for_auth_sync)

func _on_auth_state_changed(is_logged_in: bool) -> void:
	if not is_logged_in:
		_show_auth_retry_popup()

func _on_auth_error(error_message: String) -> void:
	print("[LoadingPanel] Auth error received: ", error_message)
	_show_auth_retry_popup(error_message)

func _on_auth_failed(_code: int, message: String) -> void:
	print("[LoadingPanel] Auth failed signal received: ", message)
	_show_auth_retry_popup(message)

func _on_initial_sync_step(value: float) -> void:
	if value >= 1.0:
		if AuthManager and AuthManager.is_authenticated() and AuthManager.is_firestore_data_fetched:
			_on_data_fetch_completed(value)
		elif AuthManager and not bool(AuthManager.get("_is_auth_flow_running")) and not bool(AuthManager.get("is_firebase_logging_in")):
			print("[LoadingPanel] Initial sync finished without active login or cloud data.")
			_show_auth_retry_popup()

func _on_data_fetch_completed(_value: float = 1.0) -> void:
	if not AuthManager or not AuthManager.is_authenticated() or not AuthManager.is_firestore_data_fetched:
		return

	if _is_data_fetched:
		return
	_is_data_fetched = true
	_hide_auth_retry_popup()
	print("[LoadingPanel] Data fetch complete signal received.")

	if current_progress >= 0.80:
		_complete_final_loading()

func _start_progress_sequence() -> void:
	if _loading_tween and _loading_tween.is_valid():
		_loading_tween.kill()

	_loading_tween = create_tween()
	_loading_tween.set_trans(Tween.TRANS_QUAD)
	_loading_tween.set_ease(Tween.EASE_OUT)

	# Smoothly advance from current progress to 80% over 3 seconds
	_loading_tween.tween_method(_set_progress, current_progress, 0.80, 3.0)

	_loading_tween.finished.connect(func():
		if _is_data_fetched and AuthManager and AuthManager.is_authenticated() and AuthManager.is_firestore_data_fetched:
			_complete_final_loading()
		else:
			print("[LoadingPanel] 80% reached. Waiting for authentication and cloud data...")
			if AuthManager and AuthManager.get("_first_auth_attempt_done") == true and not AuthManager.is_authenticated() and not bool(AuthManager.get("_is_auth_flow_running")):
				_show_auth_retry_popup()
			else:
				# Grace timeout: wait up to 8s for in-flight auth to finish before prompting retry
				get_tree().create_timer(8.0).timeout.connect(func():
					if not _is_data_fetched or not AuthManager or not AuthManager.is_authenticated() or not AuthManager.is_firestore_data_fetched:
						print("[LoadingPanel] Auth wait timeout reached.")
						_show_auth_retry_popup()
				)
	)

func _complete_final_loading() -> void:
	if not AuthManager or not AuthManager.is_authenticated() or not AuthManager.is_firestore_data_fetched:
		_show_auth_retry_popup()
		return

	if _loading_tween and _loading_tween.is_valid():
		_loading_tween.kill()

	_loading_tween = create_tween()
	_loading_tween.set_trans(Tween.TRANS_CUBIC)
	_loading_tween.set_ease(Tween.EASE_OUT)

	# Complete from current progress to 100% over 0.5s
	_loading_tween.tween_method(_set_progress, current_progress, 1.0, 0.5)

	_loading_tween.finished.connect(func():
		await get_tree().create_timer(0.2).timeout
		_on_loading_finished()
	)

func _on_loading_finished() -> void:
	if not AuthManager or not AuthManager.is_authenticated() or not AuthManager.is_firestore_data_fetched:
		_show_auth_retry_popup()
		return

	if not PlayerPrefs.get_bool("terms_accepted", false):
		print("[LoadingPanel] Waiting for Terms & Conditions acceptance...")
		if GameManager and GameManager.ui_manager:
			await GameManager.ui_manager.terms_and_condition_accepted
		print("[LoadingPanel] Terms & Conditions accepted. Proceeding to Main Menu...")

	if AudioPlayer:
		AudioPlayer.start_bg_music(AudioPlayer.SOUND_DB.main_theme)

	if GameManager:
		if GameManager.target_main_menu_panel != -1:
			var target = GameManager.target_main_menu_panel
			GameManager.target_main_menu_panel = -1
			GameManager.change_panel(target)
		else:
			GameManager.change_panel(UIManager.PanelType.BASE)

func _set_progress(value: float) -> void:
	current_progress = clampf(value, 0.0, 1.0)
	update_loader(current_progress)

func update_loader(value: float) -> void:
	if moving_bullet:
		moving_bullet.visible = true
		var target_x := lerpf(bullet_start_x, bullet_end_x, value)
		moving_bullet.position.x = target_x

func _on_visibility_changed() -> void:
	if is_visible_in_tree():
		start_loading()

# ---------------------------------------------------------
# Authentication Retry Popup
# ---------------------------------------------------------
func _show_auth_retry_popup(message: String = "") -> void:
	# If offline, No Internet popup takes top priority
	if not NetworkMonitor.has_internet:
		return

	# If data is already fetched or user is authenticated & synced, do not show
	if _is_data_fetched or (AuthManager and AuthManager.is_authenticated() and AuthManager.is_firestore_data_fetched):
		return

	# If auth flow is actively running, do not interrupt
	if AuthManager and (bool(AuthManager.get("_is_auth_flow_running")) or bool(AuthManager.get("is_firebase_logging_in")) or bool(AuthManager.get("is_pggs_checking"))):
		return

	# If Terms & Conditions or No Internet popup is currently active, do not overlap
	if GameManager and GameManager.ui_manager and GameManager.ui_manager.popup_panel:
		var pp = GameManager.ui_manager.popup_panel
		if is_instance_valid(pp.no_internet_popup) and pp.no_internet_popup.visible:
			return
		if is_instance_valid(pp.tc_popup) and pp.tc_popup.visible:
			return

	if _loading_tween and _loading_tween.is_valid():
		_loading_tween.kill()

	if GameManager and GameManager.ui_manager and GameManager.ui_manager.popup_panel:
		GameManager.ui_manager.popup_panel.show_auth_retry_popup(message)

func _hide_auth_retry_popup() -> void:
	if GameManager and GameManager.ui_manager and GameManager.ui_manager.popup_panel:
		GameManager.ui_manager.popup_panel.hide_auth_retry_popup()

func retry_auth_flow() -> void:
	print("[LoadingPanel] Retrying authentication flow...")
	_hide_auth_retry_popup()
	_is_data_fetched = false
	current_progress = 0.1
	_set_progress(current_progress)
	_play_gun_fire_animation()

	if AuthManager:
		if AuthManager.has_method("retry_authentication"):
			AuthManager.retry_authentication()
		elif AuthManager.has_method("reset_flags"):
			AuthManager.reset_flags()
			AuthManager._start_auth_sequence()

	_start_progress_sequence()
