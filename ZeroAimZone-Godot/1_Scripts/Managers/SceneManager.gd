extends CanvasLayer

const LOADER_POPUP_PATH := "res://ZeroAimZone-Godot/2_Prefabs/UI/Popups/loader_popup.tscn"

var _loading_popup: LoaderPopupController = null
var _target_path: String = ""
var _is_loading: bool = false

func _ready() -> void:
	layer = 100 # Highest Z index to overlay everything

func load_scene(path: String) -> void:
	if _is_loading:
		return
	_is_loading = true
	_target_path = path

	GameManager.clear_bullet_polygon_caches()
	AudioPlayer.stop_bgm()

	# Show the loader popup
	_loading_popup = _create_loader_popup()
	if _loading_popup:
		add_child(_loading_popup)

	# Wait a frame so the popup renders before we kick off loading
	await get_tree().process_frame

	# Start threaded background loading
	ResourceLoader.load_threaded_request(path)

func _process(_delta: float) -> void:
	if not _is_loading or _target_path == "":
		return

	var progress_array: Array = []
	var status = ResourceLoader.load_threaded_get_status(_target_path, progress_array)

	match status:
		ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			# Feed real loading progress into the popup animation (0.0 - 1.0)
			if _loading_popup and progress_array.size() > 0:
				# The popup has its own spinning animation; this is a no-op hook
				# for if you want to drive a progress bar in the future
				pass

		ResourceLoader.THREAD_LOAD_LOADED:
			# Loading done — swap scene without freezing
			var packed: PackedScene = ResourceLoader.load_threaded_get(_target_path)
			_target_path = ""
			_is_loading = false

			if is_instance_valid(_loading_popup):
				if _loading_popup.has_method("spinning"):
					_loading_popup.spinning = false
			
			# Change scene while the loading screen is still visible
			get_tree().change_scene_to_packed(packed)
			
			# Wait a bit to ensure the new scene is fully instanced and rendered
			if GameManager.current_state == GameManager.GameState.IN_GAME_MULTIPLAYER:
				await get_tree().create_timer(2.0).timeout
			else:
				await get_tree().create_timer(0.5).timeout
			
			if is_instance_valid(_loading_popup):
				_loading_popup.queue_free()
				_loading_popup = null

		ResourceLoader.THREAD_LOAD_FAILED:
			printerr("SceneManager: Background load FAILED for: ", _target_path)
			_target_path = ""
			_is_loading = false
			if is_instance_valid(_loading_popup):
				_loading_popup.queue_free()
				_loading_popup = null

func _create_loader_popup() -> LoaderPopupController:
	var loader_scene = ResourceLoader.load(LOADER_POPUP_PATH)
	if not loader_scene:
		return null
	var popup = loader_scene.instantiate() as LoaderPopupController
	if not popup:
		return null

	# Add a solid black ColorRect behind everything to completely hide the engine background
	var bg := ColorRect.new()
	bg.name = "SolidBackground"
	bg.color = Color.BLACK
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	popup.add_child(bg)
	popup.move_child(bg, 0)

	# Disable overlay button interactions so clicking during loading doesn't dismiss it
	var overlay = popup.get_node_or_null("Overlay")
	if overlay is TextureButton:
		overlay.disabled = true

	return popup

func show_transition_loading() -> void:
	if not is_instance_valid(_loading_popup):
		_loading_popup = _create_loader_popup()
		if _loading_popup:
			add_child(_loading_popup)

func hide_transition_loading() -> void:
	if is_instance_valid(_loading_popup):
		if _loading_popup.has_method("spinning"):
			_loading_popup.spinning = false
		_loading_popup.queue_free()
		_loading_popup = null
