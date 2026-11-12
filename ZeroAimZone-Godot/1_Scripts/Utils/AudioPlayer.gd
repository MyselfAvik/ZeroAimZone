extends Node

const SOUND_DB = preload("res://ZeroAimZone-Godot/4_Resources/Tres/SoundDb.tres")

var sound_enabled: bool = true
var music_enabled: bool = true

var bgm_player: AudioStreamPlayer

@export var duck_volume_db: float = -17.0     # how much quieter music gets while ducked
@export var duck_time: float = 0.8 

var _duck_tween: Tween
var _duck_count: int = 0  

func _ready() -> void:
	bgm_player = AudioStreamPlayer.new()
	if AudioServer.get_bus_index("Music") != -1:
		bgm_player.bus = "Music"
	else:
		bgm_player.bus = "Master"
	add_child(bgm_player)
	
	sync_state()
	
	EventBus.setting_changed.connect(_on_setting_changed)
	get_tree().node_added.connect(_on_node_added)
	
	_connect_buttons(get_tree().root)

func _on_node_added(node: Node) -> void:
	if node is BaseButton:
		if not node.pressed.is_connected(_play_button_click.bind(node)):
			node.pressed.connect(_play_button_click.bind(node))

func _connect_buttons(node: Node) -> void:
	if node is BaseButton:
		if not node.pressed.is_connected(_play_button_click.bind(node)):
			node.pressed.connect(_play_button_click.bind(node))
	for child in node.get_children():
		_connect_buttons(child)

func _play_button_click(node: BaseButton = null) -> void:
	if SOUND_DB.button_clicks.size() > 0:
		var sound_index: int = 0
		if node and node.has_meta("sound_index"):
			sound_index = node.get_meta("sound_index")
		
		sound_index = clampi(sound_index, 0, SOUND_DB.button_clicks.size() - 1)
		var sound = SOUND_DB.button_clicks[sound_index]
		play_sfx(sound)

func stop_bgm() -> void:
	_duck_count = 0
	if _duck_tween and _duck_tween.is_running():
		_duck_tween.kill()
	if is_instance_valid(bgm_player):
		bgm_player.volume_db = 0.0
		if bgm_player.playing:
			bgm_player.stop()

func _on_setting_changed(setting_key: String, is_on: bool) -> void:
	if setting_key == "music_on":
		music_enabled = is_on
		if music_enabled:
			var current_scene = get_tree().current_scene
			if current_scene:
				if current_scene.name == "MainMenu":
					start_bg_music(SOUND_DB.main_theme)
				elif current_scene.name == "GameScene":
					start_bg_music(SOUND_DB.game_theme)
				else:
					if bgm_player.stream != null and not bgm_player.playing:
						bgm_player.play()
			else:
				if bgm_player.stream != null and not bgm_player.playing:
					bgm_player.play()
		else:
			stop_bgm()
	elif setting_key == "sound_on":
		sound_enabled = is_on

func sync_state() -> void:
	if GameManager.save_manager and GameManager.save_manager.game_data.has("game_settings"):
		var settings = GameManager.save_manager.game_data["game_settings"]
		sound_enabled = settings.get("sound_on", true)
		music_enabled = settings.get("music_on", true)
	
	if music_enabled:
		if bgm_player.stream != null and not bgm_player.playing:
			bgm_player.play()
	else:
		if bgm_player.playing:
			bgm_player.stop()

func play_sfx(audio_stream: AudioStream, pitch: float = 1.0, should_duck: bool = true) -> void:
	if not sound_enabled:
		return
	if audio_stream == null:
		return
		
	var sfx_player := AudioStreamPlayer.new()
	sfx_player.stream = audio_stream
	sfx_player.pitch_scale = pitch
	if AudioServer.get_bus_index("SFX") != -1:
		sfx_player.bus = "SFX"
	else:
		sfx_player.bus = "Master"
	if should_duck:
		duck_music()
		sfx_player.finished.connect(unduck_music)
	add_child(sfx_player)
	sfx_player.play()
	sfx_player.finished.connect(sfx_player.queue_free)

func start_bg_music(stream: AudioStream = null) -> void:
	if not music_enabled:
		return

	_duck_count = 0
	if _duck_tween and _duck_tween.is_running():
		_duck_tween.kill()
	if is_instance_valid(bgm_player):
		bgm_player.volume_db = 0.0

	if stream != null:
		if bgm_player.stream != stream:
			if stream is AudioStreamMP3 or stream is AudioStreamOggVorbis:
				stream.loop = true
			elif stream is AudioStreamWAV:
				stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
				if stream.loop_end <= stream.loop_begin:
					stream.loop_end = int(round(stream.get_length() * stream.mix_rate))
			bgm_player.stream = stream
		elif stream is AudioStreamWAV:
			stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
			if stream.loop_end <= stream.loop_begin:
				stream.loop_end = int(round(stream.get_length() * stream.mix_rate))

		if not bgm_player.playing:
			bgm_player.play()
	else:
		if bgm_player.stream != null and not bgm_player.playing:
			bgm_player.play()
			
func duck_music() -> void:
	_duck_count += 1
	if _duck_count > 1:
		return 
	_animate_bgm_volume(duck_volume_db)

func unduck_music() -> void:
	_duck_count = max(_duck_count - 1, 0)
	if _duck_count > 0:
		return  
	_animate_bgm_volume(0.0)

func _animate_bgm_volume(target_db: float) -> void:
	if _duck_tween and _duck_tween.is_running():
		_duck_tween.kill()
	_duck_tween = create_tween()
	_duck_tween.tween_property(bgm_player, "volume_db", target_db, duck_time)

func mute_for_ad() -> void:
	print("[AudioPlayer] Muting game audio and pausing BGM for ad...")
	var master_bus := AudioServer.get_bus_index("Master")
	if master_bus != -1:
		AudioServer.set_bus_mute(master_bus, true)
	if is_instance_valid(bgm_player) and bgm_player.playing:
		bgm_player.stream_paused = true

func unmute_after_ad() -> void:
	print("[AudioPlayer] Unmuting game audio and resuming BGM after ad...")
	var master_bus := AudioServer.get_bus_index("Master")
	if master_bus != -1:
		AudioServer.set_bus_mute(master_bus, false)
	if is_instance_valid(bgm_player) and bgm_player.stream_paused:
		bgm_player.stream_paused = false
