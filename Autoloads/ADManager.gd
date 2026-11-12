extends Node

var is_ad_ready: bool = false
var admob: AdMob

var _is_banner_requested_visible: bool = false
var _is_banner_loaded: bool = false
var _is_banner_currently_shown: bool = false
var _banner_impression_logged: bool = false

signal banner_shown()
signal banner_clicked()
signal banner_refreshed()
signal banner_failed_to_load(error_code: int)
signal banner_failed_to_open(error_code: int)
signal banner_closed()

signal rewarded_ad_earned(placement: String)
signal rewarded_ad_clicked(placement: String)
signal rewarded_ad_closed(earned_reward: bool, placement: String)

signal interstitial_ad_opened(placement: String)
signal interstitial_ad_clicked(placement: String)
signal interstitial_ad_closed(placement: String)

var _current_rewarded_placement: String = ""
var _reward_earned: bool = false
var _on_reward_callback: Callable = Callable()

var _is_interstitial_loaded: bool = false
var _current_interstitial_placement: String = ""
var _on_interstitial_callback: Callable = Callable()

# 5-Second On-Demand Loading State
const AD_LOAD_TIMEOUT_SECONDS: float = 5.0
var _is_waiting_for_rewarded: bool = false
var _rewarded_load_token: int = 0

var _is_waiting_for_interstitial: bool = false
var _interstitial_load_token: int = 0

var games_played_counter: int = 0
const GAMES_PER_INTERSTITIAL: int = 2

func _ready() -> void:
	admob = AdMob.new()
	admob.onMasInitSuccessful.connect(_on_admob_init_success)
	admob.onMasInitFailed.connect(_on_admob_init_failed)

	# Banner signals
	admob.onBannerAdLoaded.connect(_on_banner_ad_loaded)
	admob.onBannerAdFailedToLoad.connect(_on_banner_ad_failed_to_load)
	admob.onBannerAdOpened.connect(_on_banner_ad_opened)
	admob.onBannerAdClicked.connect(_on_banner_ad_clicked)
	admob.onBannerAdFailedToOpen.connect(_on_banner_ad_failed_to_open)
	admob.onBannerAdClosed.connect(_on_banner_ad_closed)

	# Rewarded signals
	admob.onRewardAdLoaded.connect(_on_reward_ad_loaded)
	admob.onRewardAdFailedToLoad.connect(_on_reward_ad_failed_to_load)
	admob.onRewardAdOpened.connect(_on_reward_ad_opened)
	admob.onRewardAdClicked.connect(_on_reward_ad_clicked)
	admob.onRewardAdFailedToOpen.connect(_on_reward_ad_failed_to_open)
	admob.onRewardAdEarned.connect(_on_reward_ad_earned)
	admob.onRewardAdClosed.connect(_on_reward_ad_closed)

	# Interstitial signals
	admob.onInterstitialAdLoaded.connect(_on_interstitial_ad_loaded)
	admob.onInterstitialAdFailedToLoad.connect(_on_interstitial_ad_failed_to_load)
	admob.onInterstitialAdOpened.connect(_on_interstitial_ad_opened)
	admob.onInterstitialAdClicked.connect(_on_interstitial_ad_clicked)
	admob.onInterstitialAdFailedToOpen.connect(_on_interstitial_ad_failed_to_open)
	admob.onInterstitialAdClosed.connect(_on_interstitial_ad_closed)

	add_child(admob)
	admob.init()

func _on_admob_init_success() -> void:
	is_ad_ready = true
	print("[ADManager] AdMob Init Successful.")
	admob.loadBannerAd("Banner", "Center", "Top", "banner")

func _on_admob_init_failed() -> void:
	is_ad_ready = false
	print("[ADManager] AdMob Init Failed.")

func has_remove_ads() -> bool:
	if GameManager and GameManager.save_manager:
		return GameManager.save_manager.has_remove_ads()
	return false

# ==============================================================================
# POPUP HELPERS (AdBreak "Please wait" & NoAds "Ad not available")
# ==============================================================================

func show_adbreak_popup() -> void:
	if GameManager:
		if GameManager.ui_manager and is_instance_valid(GameManager.ui_manager.popup_panel):
			GameManager.ui_manager.popup_panel.show_popup(PopupPanelController.PopupType.ADBREAK)
		elif GameManager.in_game_ui and is_instance_valid(GameManager.in_game_ui.popup_panel):
			GameManager.in_game_ui.popup_panel.show_popup(PopupPanelController.PopupType.ADBREAK)

func hide_adbreak_popup() -> void:
	if GameManager:
		if GameManager.ui_manager and is_instance_valid(GameManager.ui_manager.popup_panel):
			var p = GameManager.ui_manager.popup_panel
			if is_instance_valid(p.adbreak_popup) and p.adbreak_popup.visible:
				p.adbreak_popup.hide_popup()
		elif GameManager.in_game_ui and is_instance_valid(GameManager.in_game_ui.popup_panel):
			var p = GameManager.in_game_ui.popup_panel
			if is_instance_valid(p.adbreak_popup) and p.adbreak_popup.visible:
				p.adbreak_popup.hide_popup()

func show_no_ads_popup() -> void:
	if GameManager:
		if GameManager.ui_manager and is_instance_valid(GameManager.ui_manager.popup_panel):
			GameManager.ui_manager.popup_panel.show_no_ads_popup()
		elif GameManager.in_game_ui and is_instance_valid(GameManager.in_game_ui.popup_panel):
			GameManager.in_game_ui.popup_panel.show_no_ads_popup()

func _is_banner_allowed_right_now() -> bool:
	if has_remove_ads():
		return false
	if not _is_banner_requested_visible:
		return false
	if GameManager:
		if GameManager.ui_manager and is_instance_valid(GameManager.ui_manager.popup_panel):
			if GameManager.ui_manager.popup_panel.is_popup_visible():
				return false
		if GameManager.in_game_ui and is_instance_valid(GameManager.in_game_ui.popup_panel):
			if GameManager.in_game_ui.popup_panel.is_popup_visible():
				return false
	return true

func _force_hide_banner_if_not_allowed() -> void:
	if not _is_banner_allowed_right_now():
		if admob:
			admob.hideBannerAd()
		_is_banner_currently_shown = false

# ==============================================================================
# BANNER ADS
# ==============================================================================

func _on_banner_ad_loaded() -> void:
	var was_already_loaded := _is_banner_loaded
	_is_banner_loaded = true
	print("[ADManager] Banner ad loaded. Was already loaded (refresh): ", was_already_loaded, " | Desired visibility: ", _is_banner_requested_visible)

	if was_already_loaded:
		_banner_impression_logged = false
		banner_refreshed.emit()

	if not _is_banner_allowed_right_now():
		_is_banner_currently_shown = false
		if admob:
			admob.hideBannerAd()
		return

	if admob:
		admob.showBannerAd()
	_is_banner_currently_shown = true

	if not _banner_impression_logged:
		_banner_impression_logged = true
		banner_shown.emit()
		GameAnalysis.track_ad_event(GameAnalysis.AD_ACTION_SHOW, GameAnalysis.AD_TYPE_BANNER, "admob", "top")

func _on_banner_ad_failed_to_load(error_code: int = 0) -> void:
	print("[ADManager] Banner ad failed to load. Error: ", error_code)
	_is_banner_loaded = false
	_is_banner_currently_shown = false
	_banner_impression_logged = false
	if admob:
		admob.hideBannerAd()
	banner_failed_to_load.emit(error_code)
	if _is_banner_requested_visible:
		GameAnalysis.track_ad_event(GameAnalysis.AD_ACTION_FAILED_SHOW, GameAnalysis.AD_TYPE_BANNER, "admob", "top", -1, str(error_code))

func _on_banner_ad_failed_to_open(error_code: int = 0) -> void:
	print("[ADManager] Banner ad failed to open. Error: ", error_code)
	_is_banner_loaded = false
	_is_banner_currently_shown = false
	_banner_impression_logged = false
	if admob:
		admob.hideBannerAd()
	banner_failed_to_open.emit(error_code)
	GameAnalysis.track_ad_event(GameAnalysis.AD_ACTION_FAILED_SHOW, GameAnalysis.AD_TYPE_BANNER, "admob", "top", -1, str(error_code))

func _on_banner_ad_opened() -> void:
	print("[ADManager] Banner ad opened.")
	banner_shown.emit()

func _on_banner_ad_clicked() -> void:
	print("[ADManager] Banner ad clicked.")
	banner_clicked.emit()
	GameAnalysis.track_ad_event(GameAnalysis.AD_ACTION_CLICKED, GameAnalysis.AD_TYPE_BANNER, "admob", "top")

func _on_banner_ad_closed() -> void:
	print("[ADManager] Banner ad closed.")
	_is_banner_currently_shown = false
	banner_closed.emit()

func show_banner() -> void:
	_is_banner_requested_visible = true
	print("[ADManager] show_banner() called")
	if not _is_banner_allowed_right_now():
		_force_hide_banner_if_not_allowed()
		return
	if not is_ad_ready or admob == null:
		return
	if _is_banner_loaded:
		admob.showBannerAd()
		_is_banner_currently_shown = true
		if not _banner_impression_logged:
			_banner_impression_logged = true
			banner_shown.emit()
			GameAnalysis.track_ad_event(GameAnalysis.AD_ACTION_SHOW, GameAnalysis.AD_TYPE_BANNER, "admob", "top")
	else:
		admob.loadBannerAd("Banner", "Center", "Top", "banner")

func hide_banner() -> void:
	_is_banner_requested_visible = false
	_is_banner_currently_shown = false
	print("[ADManager] hide_banner() called")
	if admob:
		admob.hideBannerAd()

# ==============================================================================
# REWARDED ADS (On-Demand 5-Second Load Flow)
# ==============================================================================

func is_rewarded_loaded() -> bool:
	if not is_ad_ready or admob == null:
		return false
	return admob.isRewardedAdLoaded()

func load_rewarded() -> void:
	if admob:
		admob.initializeRewardedAd()

func _get_mas_placement(placement: String) -> String:
	if placement.begins_with("unlock_chest") or placement.begins_with("chest_unlock") or placement.begins_with("chest_tap_to_unlock"):
		return "chest_unlock"
	return placement

func show_rewarded(placement: String = "default", on_reward_earned: Callable = Callable()) -> bool:
	print("[ADManager] show_rewarded() called for placement: ", placement)
	if _is_waiting_for_rewarded:
		print("[ADManager] Rewarded ad request already in progress. Ignoring duplicate call.")
		return false

	_current_rewarded_placement = placement
	_reward_earned = false
	_on_reward_callback = on_reward_earned

	# Track Reward Opt-In design event with full placement detail in GameAnalytics
	GameAnalysis.track_reward_opt_in(placement)

	# Mock simulation in editor or non-mobile platforms
	if OS.get_name() not in ["Android", "iOS"]:
		print("[ADManager] Non-mobile platform. Simulating 5s wait and reward callback...")
		show_adbreak_popup()
		get_tree().create_timer(1.0).timeout.connect(func():
			hide_adbreak_popup()
			_simulate_reward_callback()
		)
		return true

	if not is_ad_ready:
		print("[ADManager] AdMob not initialized yet.")
		show_no_ads_popup()
		return false

	# If already loaded in memory, show immediately
	var mas_placement := _get_mas_placement(placement)
	if admob.isRewardedAdLoaded():
		hide_adbreak_popup()
		GameAnalysis.track_ad_event(GameAnalysis.AD_ACTION_SHOW, GameAnalysis.AD_TYPE_REWARDED_VIDEO, "admob", placement)
		admob.showRewardedAd(mas_placement)
		return true

	# On-demand load: Display "Ad is loading, please wait" popup for up to 5 seconds
	print("[ADManager] Loading rewarded ad on the spot with %ds timeout..." % int(AD_LOAD_TIMEOUT_SECONDS))
	show_adbreak_popup()
	_is_waiting_for_rewarded = true
	var token := Time.get_ticks_msec()
	_rewarded_load_token = token

	admob.initializeRewardedAd()

	# Start 5-second countdown timer
	get_tree().create_timer(AD_LOAD_TIMEOUT_SECONDS).timeout.connect(func():
		if _is_waiting_for_rewarded and _rewarded_load_token == token:
			print("[ADManager] Rewarded ad 5-second timeout reached. Stopping wait and showing No Ads popup.")
			_is_waiting_for_rewarded = false
			_rewarded_load_token = 0
			hide_adbreak_popup()
			show_no_ads_popup()
			GameAnalysis.track_ad_event(GameAnalysis.AD_ACTION_FAILED_SHOW, GameAnalysis.AD_TYPE_REWARDED_VIDEO, "admob", _current_rewarded_placement, -1, "timeout_5s")
			rewarded_ad_closed.emit(false, _current_rewarded_placement)
	)

	return true

func _simulate_reward_callback() -> void:
	get_tree().create_timer(0.5).timeout.connect(func():
		_on_reward_ad_earned()
		_on_reward_ad_closed()
	)

func _on_reward_ad_loaded() -> void:
	print("[ADManager] Rewarded ad loaded successfully.")
	if _is_waiting_for_rewarded:
		_is_waiting_for_rewarded = false
		_rewarded_load_token = 0
		hide_adbreak_popup()
		print("[ADManager] Rewarded ad loaded within 5s window. Showing ad now...")
		var mas_placement := _get_mas_placement(_current_rewarded_placement)
		GameAnalysis.track_ad_event(GameAnalysis.AD_ACTION_SHOW, GameAnalysis.AD_TYPE_REWARDED_VIDEO, "admob", _current_rewarded_placement)
		admob.showRewardedAd(mas_placement)

func _on_reward_ad_failed_to_load(error_code: int = 0) -> void:
	print("[ADManager] Rewarded ad failed to load. Error: ", error_code)
	if _is_waiting_for_rewarded:
		_is_waiting_for_rewarded = false
		_rewarded_load_token = 0
		hide_adbreak_popup()
		show_no_ads_popup()
		GameAnalysis.track_ad_event(GameAnalysis.AD_ACTION_FAILED_SHOW, GameAnalysis.AD_TYPE_REWARDED_VIDEO, "admob", _current_rewarded_placement, -1, "failed_to_load_" + str(error_code))
		rewarded_ad_closed.emit(false, _current_rewarded_placement)

func _on_ad_shown(ad_type: String) -> void:
	var total_ads: int = 1
	if GameManager and GameManager.save_manager:
		total_ads = GameManager.save_manager.increment_total_ads_shown()
	else:
		total_ads = PlayerPrefs.get_int("total_ads_shown", 0) + 1 if (PlayerPrefs and PlayerPrefs.has_method("get_int")) else 1
		if PlayerPrefs and PlayerPrefs.has_method("set_int"):
			PlayerPrefs.set_int("total_ads_shown", total_ads)

	print("[ADManager] Ad Shown (%s). Total ads shown: %d" % [ad_type, total_ads])

	if MetaAnalytics:
		MetaAnalytics.track_ad_impression_milestone(total_ads, ad_type)

func _on_reward_ad_opened() -> void:
	print("[ADManager] Rewarded ad opened.")
	if AudioPlayer:
		AudioPlayer.mute_for_ad()
	hide_adbreak_popup()
	_on_ad_shown("rewarded")

func _on_reward_ad_clicked() -> void:
	print("[ADManager] Rewarded ad clicked.")
	rewarded_ad_clicked.emit(_current_rewarded_placement)
	GameAnalysis.track_ad_event(GameAnalysis.AD_ACTION_CLICKED, GameAnalysis.AD_TYPE_REWARDED_VIDEO, "admob", _current_rewarded_placement)

func _on_reward_ad_failed_to_open(error_code: int = 0) -> void:
	print("[ADManager] Rewarded ad failed to open. Error: ", error_code)
	if AudioPlayer:
		AudioPlayer.unmute_after_ad()
	_is_waiting_for_rewarded = false
	_rewarded_load_token = 0
	hide_adbreak_popup()
	show_no_ads_popup()
	GameAnalysis.track_ad_event(GameAnalysis.AD_ACTION_FAILED_SHOW, GameAnalysis.AD_TYPE_REWARDED_VIDEO, "admob", _current_rewarded_placement, -1, "open_failed_" + str(error_code))
	rewarded_ad_closed.emit(false, _current_rewarded_placement)

func _on_reward_ad_earned() -> void:
	print("[ADManager] Rewarded ad earned! Placement: ", _current_rewarded_placement)
	_reward_earned = true
	rewarded_ad_earned.emit(_current_rewarded_placement)
	GameAnalysis.track_ad_event(GameAnalysis.AD_ACTION_REWARD_RECEIVED, GameAnalysis.AD_TYPE_REWARDED_VIDEO, "admob", _current_rewarded_placement)
	if _on_reward_callback.is_valid():
		_on_reward_callback.call()
		_on_reward_callback = Callable()

func _on_reward_ad_closed() -> void:
	print("[ADManager] Rewarded ad closed. Earned: ", _reward_earned)
	if AudioPlayer:
		AudioPlayer.unmute_after_ad()
	hide_adbreak_popup()
	rewarded_ad_closed.emit(_reward_earned, _current_rewarded_placement)
	_reward_earned = false
	_is_waiting_for_rewarded = false

# ==============================================================================
# INTERSTITIAL ADS (On-Demand 5-Second Load Flow)
# ==============================================================================

func is_interstitial_loaded() -> bool:
	if not is_ad_ready or admob == null:
		return false
	return admob.isInterstitialAdLoaded()

func load_interstitial() -> void:
	if admob:
		admob.initializeInterstitialAd()

func show_interstitial(placement: String = "default", on_closed: Callable = Callable()) -> bool:
	if has_remove_ads():
		print("[ADManager] Interstitial skipped - ads removed.")
		if on_closed.is_valid():
			on_closed.call()
		return true

	if _is_waiting_for_interstitial:
		print("[ADManager] Interstitial request already in progress. Ignoring duplicate call.")
		return false

	print("[ADManager] show_interstitial() called for placement: ", placement)
	_current_interstitial_placement = placement
	_on_interstitial_callback = on_closed

	# Non-mobile platform simulation
	if OS.get_name() not in ["Android", "iOS"]:
		print("[ADManager] Non-mobile platform. Simulating 5s wait and interstitial callback...")
		show_adbreak_popup()
		get_tree().create_timer(1.0).timeout.connect(func():
			hide_adbreak_popup()
			_simulate_interstitial_callback()
		)
		return true

	if not is_ad_ready:
		print("[ADManager] AdMob not ready.")
		show_no_ads_popup()
		if on_closed.is_valid():
			on_closed.call()
		return false

	# If already loaded in memory, show immediately
	if admob.isInterstitialAdLoaded():
		hide_adbreak_popup()
		GameAnalysis.track_ad_event(GameAnalysis.AD_ACTION_SHOW, GameAnalysis.AD_TYPE_INTERSTITIAL, "admob", placement)
		admob.showInterstitialAd(placement)
		return true

	# On-demand load: Display "Ad is loading, please wait" popup for up to 5 seconds
	print("[ADManager] Loading interstitial ad on the spot with %ds timeout..." % int(AD_LOAD_TIMEOUT_SECONDS))
	show_adbreak_popup()
	_is_waiting_for_interstitial = true
	var token := Time.get_ticks_msec()
	_interstitial_load_token = token

	admob.initializeInterstitialAd()

	# Start 5-second countdown timer
	get_tree().create_timer(AD_LOAD_TIMEOUT_SECONDS).timeout.connect(func():
		if _is_waiting_for_interstitial and _interstitial_load_token == token:
			print("[ADManager] Interstitial ad 5-second timeout reached. Stopping wait and showing No Ads popup.")
			_is_waiting_for_interstitial = false
			_interstitial_load_token = 0
			hide_adbreak_popup()
			show_no_ads_popup()
			GameAnalysis.track_ad_event(GameAnalysis.AD_ACTION_FAILED_SHOW, GameAnalysis.AD_TYPE_INTERSTITIAL, "admob", _current_interstitial_placement, -1, "timeout_5s")
			if _on_interstitial_callback.is_valid():
				_on_interstitial_callback.call()
				_on_interstitial_callback = Callable()
			interstitial_ad_closed.emit(_current_interstitial_placement)
	)

	return true

func _simulate_interstitial_callback() -> void:
	get_tree().create_timer(0.5).timeout.connect(func():
		_on_interstitial_ad_opened()
		_on_interstitial_ad_closed()
	)

func _on_interstitial_ad_loaded() -> void:
	_is_interstitial_loaded = true
	print("[ADManager] Interstitial ad loaded successfully.")
	if _is_waiting_for_interstitial:
		_is_waiting_for_interstitial = false
		_interstitial_load_token = 0
		hide_adbreak_popup()
		print("[ADManager] Interstitial ad loaded within 5s window. Showing ad now...")
		GameAnalysis.track_ad_event(GameAnalysis.AD_ACTION_SHOW, GameAnalysis.AD_TYPE_INTERSTITIAL, "admob", _current_interstitial_placement)
		admob.showInterstitialAd(_current_interstitial_placement)

func _on_interstitial_ad_failed_to_load(error_code: int = 0) -> void:
	_is_interstitial_loaded = false
	print("[ADManager] Interstitial ad failed to load. Error: ", error_code)
	if _is_waiting_for_interstitial:
		_is_waiting_for_interstitial = false
		_interstitial_load_token = 0
		hide_adbreak_popup()
		show_no_ads_popup()
		GameAnalysis.track_ad_event(GameAnalysis.AD_ACTION_FAILED_SHOW, GameAnalysis.AD_TYPE_INTERSTITIAL, "admob", _current_interstitial_placement, -1, "failed_to_load_" + str(error_code))
		if _on_interstitial_callback.is_valid():
			_on_interstitial_callback.call()
			_on_interstitial_callback = Callable()
		interstitial_ad_closed.emit(_current_interstitial_placement)

func _reset_interstitial_counter() -> void:
	games_played_counter = 0
	if GameManager and GameManager.save_manager:
		GameManager.save_manager.reset_interstitial_match_counter()
	elif PlayerPrefs and PlayerPrefs.has_method("set_int"):
		PlayerPrefs.set_int("interstitial_match_counter", 0)

func _on_interstitial_ad_opened() -> void:
	print("[ADManager] Interstitial ad opened.")
	if AudioPlayer:
		AudioPlayer.mute_for_ad()
	hide_adbreak_popup()
	_reset_interstitial_counter()
	_on_ad_shown("interstitial")
	interstitial_ad_opened.emit(_current_interstitial_placement)

func _on_interstitial_ad_clicked() -> void:
	print("[ADManager] Interstitial ad clicked.")
	interstitial_ad_clicked.emit(_current_interstitial_placement)
	GameAnalysis.track_ad_event(GameAnalysis.AD_ACTION_CLICKED, GameAnalysis.AD_TYPE_INTERSTITIAL, "admob", _current_interstitial_placement)

func _on_interstitial_ad_failed_to_open(error_code: int = 0) -> void:
	print("[ADManager] Interstitial ad failed to open. Error: ", error_code)
	if AudioPlayer:
		AudioPlayer.unmute_after_ad()
	_is_waiting_for_interstitial = false
	_interstitial_load_token = 0
	hide_adbreak_popup()
	show_no_ads_popup()
	GameAnalysis.track_ad_event(GameAnalysis.AD_ACTION_FAILED_SHOW, GameAnalysis.AD_TYPE_INTERSTITIAL, "admob", _current_interstitial_placement, -1, "open_failed_" + str(error_code))
	if _on_interstitial_callback.is_valid():
		_on_interstitial_callback.call()
		_on_interstitial_callback = Callable()
	interstitial_ad_closed.emit(_current_interstitial_placement)

func _on_interstitial_ad_closed() -> void:
	print("[ADManager] Interstitial ad closed.")
	if AudioPlayer:
		AudioPlayer.unmute_after_ad()
	hide_adbreak_popup()
	_is_waiting_for_interstitial = false
	interstitial_ad_closed.emit(_current_interstitial_placement)
	if _on_interstitial_callback.is_valid():
		_on_interstitial_callback.call()
		_on_interstitial_callback = Callable()

# ==============================================================================
# GAME MATCH TRACKING (INTERSTITIAL TRIGGER)
# ==============================================================================

func on_game_completed() -> void:
	if has_remove_ads():
		return

	var count: int = 0
	if GameManager and GameManager.save_manager:
		count = GameManager.save_manager.increment_interstitial_match_counter()
	elif PlayerPrefs and PlayerPrefs.has_method("get_int"):
		count = PlayerPrefs.get_int("interstitial_match_counter", 0) + 1
		PlayerPrefs.set_int("interstitial_match_counter", count)
	else:
		games_played_counter += 1
		count = games_played_counter

	games_played_counter = count
	print("[ADManager] Game completed. Match count: %d / %d" % [count, GAMES_PER_INTERSTITIAL])

	if count >= GAMES_PER_INTERSTITIAL:
		print("[ADManager] Reached %d games threshold. Showing interstitial ad..." % GAMES_PER_INTERSTITIAL)
		show_interstitial("post_match")
