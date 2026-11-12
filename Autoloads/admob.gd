extends Node

class_name AdMob

# ==============================================================================
# SIGNALS (Mirrored 1:1 with Yodo1Mas interface for zero-friction drop-in)
# ==============================================================================

signal onMasInitSuccessful()
signal onMasInitFailed()

signal onBannerAdLoaded()
signal onBannerAdFailedToLoad(error_code: int)
signal onBannerAdOpened()
signal onBannerAdClicked()
signal onBannerAdFailedToOpen(error_code: int)
signal onBannerAdClosed()

signal onInterstitialAdLoaded()
signal onInterstitialAdFailedToLoad(error_code: int)
signal onInterstitialAdOpened()
signal onInterstitialAdClicked()
signal onInterstitialAdFailedToOpen(error_code: int)
signal onInterstitialAdClosed()

signal onAppOpenAdLoaded()
signal onAppOpenAdFailedToLoad(error_code: int)
signal onAppOpenAdOpened()
signal onAppOpenAdFailedToOpen(error_code: int)
signal onAppOpenAdClosed()

signal onRewardAdLoaded()
signal onRewardAdFailedToLoad(error_code: int)
signal onRewardAdOpened()
signal onRewardAdClicked()
signal onRewardAdFailedToOpen(error_code: int)
signal onRewardAdEarned()
signal onRewardAdClosed()

# ==============================================================================
# CONFIGURATION & AD UNIT IDs
# ==============================================================================

## Toggle this to TRUE for production release, or FALSE for Google test ads
@export var is_real: bool = true
@export var is_test_europe_user_consent: bool = false

# App IDs
@export var app_id_android: String = "ca-app-pub-8530302013109448~2325377678"
@export var app_id_ios: String = "ca-app-pub-8530302013109448~6083070530"

# Production Android Unit IDs
@export var banner_id_android: String = "ca-app-pub-8530302013109448/5201201883"
@export var interstitial_id_android: String = "ca-app-pub-8530302013109448/2569297553"
@export var rewarded_id_android: String = "ca-app-pub-8530302013109448/2627738381"
@export var app_open_id_android: String = ""

# Production iOS Unit IDs
@export var banner_id_ios: String = "ca-app-pub-8530302013109448/5948173317"
@export var interstitial_id_ios: String = "ca-app-pub-8530302013109448/5882700498"
@export var rewarded_id_ios: String = "ca-app-pub-8530302013109448/8677232255"
@export var app_open_id_ios: String = ""
# Banner Positioning (Set custom to true to bypass Safe Area)
@export var banner_use_custom_position: bool = true
@export var banner_custom_x: int = 0
@export var banner_custom_y: int = 0

# Official Google Sample Test IDs
const TEST_BANNER_ANDROID: String = "ca-app-pub-3940256099942544/6300978111"
const TEST_INTERSTITIAL_ANDROID: String = "ca-app-pub-3940256099942544/1033173712"
const TEST_REWARDED_ANDROID: String = "ca-app-pub-3940256099942544/5224354917"
const TEST_APP_OPEN_ANDROID: String = "ca-app-pub-3940256099942544/9257395921"

const TEST_BANNER_IOS: String = "ca-app-pub-3940256099942544/2934735716"
const TEST_INTERSTITIAL_IOS: String = "ca-app-pub-3940256099942544/4411468910"
const TEST_REWARDED_IOS: String = "ca-app-pub-3940256099942544/1712485313"
const TEST_APP_OPEN_IOS: String = "ca-app-pub-3940256099942544/5575463023"

# Native Poing Objects
var _ad_view: AdView = null
var _rewarded_ad: RewardedAd = null
var _interstitial_ad: InterstitialAd = null

var _is_loading_rewarded: bool = false
var _is_loading_interstitial: bool = false

var _is_initialized: bool = false
var _is_banner_loaded: bool = false
var _is_rewarded_loaded: bool = false
var _is_interstitial_loaded: bool = false

# ==============================================================================
# LIFECYCLE & PRIVACY
# ==============================================================================

func set_gdpr(gdpr: bool) -> void:
	print("[AdMob] set_gdpr: ", gdpr)

func set_ccpa(ccpa: bool) -> void:
	print("[AdMob] set_ccpa: ", ccpa)

func set_coppa(coppa: bool) -> void:
	print("[AdMob] set_coppa: ", coppa)

func _ready() -> void:
	_load_env_keys()

func _load_env_keys() -> void:
	if Env:
		var env_real = Env.get_var("ADMOB_IS_REAL", "")
		if not env_real.is_empty():
			is_real = env_real.to_lower() == "true" or env_real == "1"

		var env_app_android = Env.get_var("ADMOB_APP_ID_ANDROID", "")
		if not env_app_android.is_empty(): app_id_android = env_app_android
		var env_app_ios = Env.get_var("ADMOB_APP_ID_IOS", "")
		if not env_app_ios.is_empty(): app_id_ios = env_app_ios

		var env_banner_android = Env.get_var("ADMOB_BANNER_ID_ANDROID", "")
		if not env_banner_android.is_empty(): banner_id_android = env_banner_android
		var env_inter_android = Env.get_var("ADMOB_INTERSTITIAL_ID_ANDROID", "")
		if not env_inter_android.is_empty(): interstitial_id_android = env_inter_android
		var env_reward_android = Env.get_var("ADMOB_REWARDED_ID_ANDROID", "")
		if not env_reward_android.is_empty(): rewarded_id_android = env_reward_android
		var env_app_open_android = Env.get_var("ADMOB_APP_OPEN_ID_ANDROID", "")
		if not env_app_open_android.is_empty(): app_open_id_android = env_app_open_android

		var env_banner_ios = Env.get_var("ADMOB_BANNER_ID_IOS", "")
		if not env_banner_ios.is_empty(): banner_id_ios = env_banner_ios
		var env_inter_ios = Env.get_var("ADMOB_INTERSTITIAL_ID_IOS", "")
		if not env_inter_ios.is_empty(): interstitial_id_ios = env_inter_ios
		var env_reward_ios = Env.get_var("ADMOB_REWARDED_ID_IOS", "")
		if not env_reward_ios.is_empty(): rewarded_id_ios = env_reward_ios
		var env_app_open_ios = Env.get_var("ADMOB_APP_OPEN_ID_IOS", "")
		if not env_app_open_ios.is_empty(): app_open_id_ios = env_app_open_ios

# ==============================================================================
# INITIALIZATION
# ==============================================================================

func init() -> bool:
	_load_env_keys()
	print("[AdMob] Initializing AdMob SDK (is_real=", is_real, " | mode=", "PRODUCTION" if is_real else "TEST", ")...")
	
	if OS.get_name() in ["Android", "iOS"]:
		var on_init_listener := OnInitializationCompleteListener.new()
		on_init_listener.on_initialization_complete = func(status: InitializationStatus):
			print("[AdMob] Poing AdMob MobileAds initialization complete.")
			_is_initialized = true
			onMasInitSuccessful.emit()
		
		MobileAds.initialize(on_init_listener)
		return true
	else:
		print("[AdMob] Running in editor or desktop. Simulating successful AdMob init.")
		_is_initialized = true
		get_tree().create_timer(0.2).timeout.connect(func():
			onMasInitSuccessful.emit()
		)
		return true

func _get_current_unit_id(ad_type: String) -> String:
	var os_name = OS.get_name()
	var is_ios = (os_name == "iOS")

	if not is_real:
		match ad_type:
			"banner":
				return TEST_BANNER_IOS if is_ios else TEST_BANNER_ANDROID
			"interstitial":
				return TEST_INTERSTITIAL_IOS if is_ios else TEST_INTERSTITIAL_ANDROID
			"rewarded":
				return TEST_REWARDED_IOS if is_ios else TEST_REWARDED_ANDROID
			"app_open":
				return TEST_APP_OPEN_IOS if is_ios else TEST_APP_OPEN_ANDROID
	else:
		match ad_type:
			"banner":
				return banner_id_ios if is_ios else banner_id_android
			"interstitial":
				return interstitial_id_ios if is_ios else interstitial_id_android
			"rewarded":
				return rewarded_id_ios if is_ios else rewarded_id_android
			"app_open":
				return app_open_id_ios if is_ios else app_open_id_android

	return ""

# ==============================================================================
# BANNER ADS
# ==============================================================================

func loadBannerAd(size: String = "Banner", horizontalAlignment: String = "Center", verticalAlignment: String = "Top", placementId: String = "base") -> void:
	var unit_id = _get_current_unit_id("banner")
	print("[AdMob] loadBannerAd requested for unit ID: ", unit_id)

	if OS.get_name() in ["Android", "iOS"]:
		if _ad_view != null:
			_ad_view.destroy()
			_ad_view = null

		var ad_listener := AdListener.new()
		ad_listener.on_ad_loaded = func():
			print("[AdMob] Banner loaded successfully.")
			_is_banner_loaded = true
			onBannerAdLoaded.emit()
		ad_listener.on_ad_failed_to_load = func(err: LoadAdError):
			var code = err.code if err else -1
			print("[AdMob] Banner failed to load: ", err.message if err else "error", " (code: ", code, ")")
			_is_banner_loaded = false
			onBannerAdFailedToLoad.emit(code)
		ad_listener.on_ad_opened = func():
			print("[AdMob] Banner opened.")
			onBannerAdOpened.emit()
		ad_listener.on_ad_clicked = func():
			print("[AdMob] Banner clicked.")
			onBannerAdClicked.emit()
		ad_listener.on_ad_closed = func():
			print("[AdMob] Banner closed.")
			onBannerAdClosed.emit()

		var ad_position: AdPosition.Values = AdPosition.Values.TOP
		if verticalAlignment.to_lower() == "bottom":
			ad_position = AdPosition.Values.BOTTOM

		# Full horizontal width adaptive banner
		var banner_size: AdSize = AdSize.get_current_orientation_anchored_adaptive_banner_ad_size(AdSize.FULL_WIDTH)
		if banner_size.width == 0 and banner_size.height == 0:
			banner_size = AdSize.BANNER

		_ad_view = AdView.new(unit_id, banner_size, ad_position)
		_ad_view.ad_listener = ad_listener
		_ad_view.load_ad(AdRequest.new())
	else:
		# Editor fallback simulation
		_is_banner_loaded = true
		get_tree().create_timer(0.3).timeout.connect(func(): onBannerAdLoaded.emit())

func hideBannerAd() -> void:
	print("[AdMob] hideBannerAd()")
	if _ad_view != null:
		_ad_view.hide()

func showBannerAd() -> void:
	print("[AdMob] showBannerAd()")
	if _ad_view != null:
		_ad_view.show()

# ==============================================================================
# REWARDED ADS
# ==============================================================================

func isRewardedAdLoaded() -> bool:
	return _is_rewarded_loaded

func initializeRewardedAd() -> void:
	if _is_loading_rewarded or _is_rewarded_loaded:
		return

	var unit_id = _get_current_unit_id("rewarded")
	print("[AdMob] initializeRewardedAd() for unit ID: ", unit_id)

	if OS.get_name() in ["Android", "iOS"]:
		_is_loading_rewarded = true
		var load_callback := RewardedAdLoadCallback.new()
		load_callback.on_ad_loaded = func(rewarded_ad: RewardedAd):
			print("[AdMob] Rewarded ad loaded.")
			_is_loading_rewarded = false
			_is_rewarded_loaded = true
			_rewarded_ad = rewarded_ad
			
			var content_callback := FullScreenContentCallback.new()
			content_callback.on_ad_showed_full_screen_content = func():
				print("[AdMob] Rewarded ad opened fullscreen.")
				onRewardAdOpened.emit()
			content_callback.on_ad_clicked = func():
				print("[AdMob] Rewarded ad clicked.")
				onRewardAdClicked.emit()
			content_callback.on_ad_failed_to_show_full_screen_content = func(err: AdError):
				var code = err.code if err else -1
				print("[AdMob] Rewarded ad failed to show: ", err.message if err else "error", " (code: ", code, ")")
				_is_rewarded_loaded = false
				onRewardAdFailedToOpen.emit(code)
			content_callback.on_ad_dismissed_full_screen_content = func():
				print("[AdMob] Rewarded ad dismissed/closed.")
				_is_rewarded_loaded = false
				if _rewarded_ad != null:
					_rewarded_ad.destroy()
					_rewarded_ad = null
				onRewardAdClosed.emit()
				# Preload next rewarded ad
				initializeRewardedAd()

			_rewarded_ad.full_screen_content_callback = content_callback
			onRewardAdLoaded.emit()

		load_callback.on_ad_failed_to_load = func(err: LoadAdError):
			var code = err.code if err else -1
			print("[AdMob] Rewarded ad failed to load: ", err.message if err else "error", " (code: ", code, ")")
			_is_loading_rewarded = false
			_is_rewarded_loaded = false
			onRewardAdFailedToLoad.emit(code)

		RewardedAdLoader.new().load(unit_id, AdRequest.new(), load_callback)
	else:
		# Editor fallback simulation
		_is_rewarded_loaded = true
		get_tree().create_timer(0.3).timeout.connect(func(): onRewardAdLoaded.emit())

func showRewardedAd(placementId: String = "") -> void:
	print("[AdMob] showRewardedAd() placement: ", placementId)
	if OS.get_name() in ["Android", "iOS"]:
		if _rewarded_ad != null and _is_rewarded_loaded:
			var reward_listener := OnUserEarnedRewardListener.new()
			reward_listener.on_user_earned_reward = func(_item: RewardedItem):
				print("[AdMob] User earned reward!")
				onRewardAdEarned.emit()
			_rewarded_ad.show(reward_listener)
		else:
			print("[AdMob] showRewardedAd called but ad is not ready!")
			onRewardAdFailedToOpen.emit(-1)
	else:
		# Editor simulation
		onRewardAdOpened.emit()
		onRewardAdEarned.emit()
		get_tree().create_timer(0.8).timeout.connect(func():
			_is_rewarded_loaded = false
			onRewardAdClosed.emit()
		)

# ==============================================================================
# INTERSTITIAL ADS
# ==============================================================================

func isInterstitialAdLoaded() -> bool:
	return _is_interstitial_loaded

func initializeInterstitialAd() -> void:
	if _is_loading_interstitial or _is_interstitial_loaded:
		return

	var unit_id = _get_current_unit_id("interstitial")
	print("[AdMob] initializeInterstitialAd() for unit ID: ", unit_id)

	if OS.get_name() in ["Android", "iOS"]:
		_is_loading_interstitial = true
		var load_callback := InterstitialAdLoadCallback.new()
		load_callback.on_ad_loaded = func(interstitial_ad: InterstitialAd):
			print("[AdMob] Interstitial ad loaded.")
			_is_loading_interstitial = false
			_is_interstitial_loaded = true
			_interstitial_ad = interstitial_ad

			var content_callback := FullScreenContentCallback.new()
			content_callback.on_ad_showed_full_screen_content = func():
				print("[AdMob] Interstitial ad opened fullscreen.")
				onInterstitialAdOpened.emit()
			content_callback.on_ad_clicked = func():
				print("[AdMob] Interstitial ad clicked.")
				onInterstitialAdClicked.emit()
			content_callback.on_ad_failed_to_show_full_screen_content = func(err: AdError):
				var code = err.code if err else -1
				print("[AdMob] Interstitial failed to show: ", err.message if err else "error", " (code: ", code, ")")
				_is_interstitial_loaded = false
				onInterstitialAdFailedToOpen.emit(code)
			content_callback.on_ad_dismissed_full_screen_content = func():
				print("[AdMob] Interstitial dismissed/closed.")
				_is_interstitial_loaded = false
				if _interstitial_ad != null:
					_interstitial_ad.destroy()
					_interstitial_ad = null
				onInterstitialAdClosed.emit()
				# Preload next interstitial ad
				initializeInterstitialAd()

			_interstitial_ad.full_screen_content_callback = content_callback
			onInterstitialAdLoaded.emit()

		load_callback.on_ad_failed_to_load = func(err: LoadAdError):
			var code = err.code if err else -1
			print("[AdMob] Interstitial failed to load: ", err.message if err else "error", " (code: ", code, ")")
			_is_loading_interstitial = false
			_is_interstitial_loaded = false
			onInterstitialAdFailedToLoad.emit(code)

		InterstitialAdLoader.new().load(unit_id, AdRequest.new(), load_callback)
	else:
		# Editor fallback simulation
		_is_interstitial_loaded = true
		get_tree().create_timer(0.3).timeout.connect(func(): onInterstitialAdLoaded.emit())

func showInterstitialAd(placementId: String = "") -> void:
	print("[AdMob] showInterstitialAd() placement: ", placementId)
	if OS.get_name() in ["Android", "iOS"]:
		if _interstitial_ad != null and _is_interstitial_loaded:
			_interstitial_ad.show()
		else:
			print("[AdMob] showInterstitialAd called but ad is not ready!")
			onInterstitialAdFailedToOpen.emit(-1)
	else:
		# Editor simulation
		onInterstitialAdOpened.emit()
		get_tree().create_timer(0.8).timeout.connect(func():
			_is_interstitial_loaded = false
			onInterstitialAdClosed.emit()
		)

# ==============================================================================
# APP OPEN ADS (Stub for interface parity)
# ==============================================================================

func isAppOpenAdLoaded() -> bool:
	return false

func initializeAppOpenAd() -> void:
	pass

func showAppOpenAd(placementId: String = "") -> void:
	pass
