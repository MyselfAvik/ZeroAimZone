extends Node

class_name Yodo1Mas


# signals

signal onMasInitSuccessful()
signal onMasInitFailed()

signal onBannerAdLoaded()
signal onBannerAdFailedToLoad(error_code: int)
signal onBannerAdOpened()
signal onBannerAdFailedToOpen(error_code: int)
signal onBannerAdClosed()

signal onInterstitialAdLoaded()
signal onInterstitialAdFailedToLoad(error_code: int)
signal onInterstitialAdOpened()
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
signal onRewardAdFailedToOpen(error_code: int)
signal onRewardAdEarned()
signal onRewardAdClosed()

		

# properties
@export var app_id_ios: String = "EouaBTt14z"
@export var app_id_android: String = "UD1wVSg2DP"

# "private" properties
var _yodo1mas_singleton = null
var _is_initialized: bool = false
var _banner_created: bool = false

# initialization

func set_gdpr(gdpr: bool) -> void:
	print("Yodo1Mas, set_gdpr: ", gdpr)
	if _yodo1mas_singleton != null:
		_yodo1mas_singleton.setGDPR(gdpr)

func set_ccpa(ccpa: bool) -> void:
	print("Yodo1Mas, set_ccpa: ", ccpa)
	if _yodo1mas_singleton != null:
		_yodo1mas_singleton.setCCPA(ccpa)
	
func set_coppa(coppa: bool) -> void:
	print("Yodo1Mas, set_coppa: ", coppa)
	if _yodo1mas_singleton != null:
		_yodo1mas_singleton.setCOPPA(coppa)


func _ready() -> void:
	_load_env_keys()
	if Engine.has_singleton("GodotYodo1Mas"):
		_yodo1mas_singleton = Engine.get_singleton("GodotYodo1Mas")
		print("Yodo1Mas: GodotYodo1Mas singleton found")
		connect_signals()
	else:
		print("Yodo1Mas: GodotYodo1Mas singleton not found (running in Editor/Desktop or plugin disabled)")

func _load_env_keys() -> void:
	if Env:
		var env_android = Env.get_var("YODO1_APP_ID_ANDROID", "")
		if not env_android.is_empty():
			app_id_android = env_android
		var env_ios = Env.get_var("YODO1_APP_ID_IOS", "")
		if not env_ios.is_empty():
			app_id_ios = env_ios

func init() -> bool:
	_load_env_keys()
	print("Yodo1Mas: Initializing Yodo1 SDK...")
	if _yodo1mas_singleton == null and Engine.has_singleton("GodotYodo1Mas"):
		_yodo1mas_singleton = Engine.get_singleton("GodotYodo1Mas")

	if _yodo1mas_singleton != null:
		connect_signals()
		
		var os_name = OS.get_name()
		print("Yodo1Mas: OS detected as ", os_name)

		if os_name == "iOS":
			set_coppa(false)
			set_gdpr(true)
			set_ccpa(false)
			_yodo1mas_singleton.init(app_id_ios)
		elif os_name == "Android":
			set_coppa(false)
			set_gdpr(true)
			set_ccpa(false)
			_yodo1mas_singleton.init(app_id_android)
		else:
			print("Yodo1Mas: Unsupported OS for native ads: ", os_name)
			
		return true
	else:
		print("Yodo1Mas: Cannot initialize SDK, singleton is null")
	return false

# connect the AdMob/MAS signals
func connect_signals() -> void:
	if _yodo1mas_singleton == null:
		return

	if not _yodo1mas_singleton.onMasInitSuccessful.is_connected(_onMasInitSuccessful):
		_yodo1mas_singleton.onMasInitSuccessful.connect(_onMasInitSuccessful)
	if not _yodo1mas_singleton.onMasInitFailed.is_connected(_onMasInitFailed):
		_yodo1mas_singleton.onMasInitFailed.connect(_onMasInitFailed)
	
	if not _yodo1mas_singleton.onBannerAdLoaded.is_connected(_onBannerAdLoaded):
		_yodo1mas_singleton.onBannerAdLoaded.connect(_onBannerAdLoaded)
	if not _yodo1mas_singleton.onBannerAdFailedToLoad.is_connected(_onBannerAdFailedToLoad):
		_yodo1mas_singleton.onBannerAdFailedToLoad.connect(_onBannerAdFailedToLoad)
	if not _yodo1mas_singleton.onBannerAdOpened.is_connected(_onBannerAdOpened):
		_yodo1mas_singleton.onBannerAdOpened.connect(_onBannerAdOpened)
	if not _yodo1mas_singleton.onBannerAdFailedToOpen.is_connected(_onBannerAdFailedToOpen):
		_yodo1mas_singleton.onBannerAdFailedToOpen.connect(_onBannerAdFailedToOpen)
	if not _yodo1mas_singleton.onBannerAdClosed.is_connected(_onBannerAdClosed):
		_yodo1mas_singleton.onBannerAdClosed.connect(_onBannerAdClosed)

	if not _yodo1mas_singleton.onInterstitialAdLoaded.is_connected(_onInterstitialAdLoaded):
		_yodo1mas_singleton.onInterstitialAdLoaded.connect(_onInterstitialAdLoaded)
	if not _yodo1mas_singleton.onInterstitialAdFailedToLoad.is_connected(_onInterstitialAdFailedToLoad):
		_yodo1mas_singleton.onInterstitialAdFailedToLoad.connect(_onInterstitialAdFailedToLoad)
	if not _yodo1mas_singleton.onInterstitialAdOpened.is_connected(_onInterstitialAdOpened):
		_yodo1mas_singleton.onInterstitialAdOpened.connect(_onInterstitialAdOpened)
	if not _yodo1mas_singleton.onInterstitialAdFailedToOpen.is_connected(_onInterstitialAdFailedToOpen):
		_yodo1mas_singleton.onInterstitialAdFailedToOpen.connect(_onInterstitialAdFailedToOpen)
	if not _yodo1mas_singleton.onInterstitialAdClosed.is_connected(_onInterstitialAdClosed):
		_yodo1mas_singleton.onInterstitialAdClosed.connect(_onInterstitialAdClosed)

	if not _yodo1mas_singleton.onAppOpenAdLoaded.is_connected(_onAppOpenAdLoaded):
		_yodo1mas_singleton.onAppOpenAdLoaded.connect(_onAppOpenAdLoaded)
	if not _yodo1mas_singleton.onAppOpenAdFailedToLoad.is_connected(_onAppOpenAdFailedToLoad):
		_yodo1mas_singleton.onAppOpenAdFailedToLoad.connect(_onAppOpenAdFailedToLoad)
	if not _yodo1mas_singleton.onAppOpenAdOpened.is_connected(_onAppOpenAdOpened):
		_yodo1mas_singleton.onAppOpenAdOpened.connect(_onAppOpenAdOpened)
	if not _yodo1mas_singleton.onAppOpenAdFailedToOpen.is_connected(_onAppOpenAdFailedToOpen):
		_yodo1mas_singleton.onAppOpenAdFailedToOpen.connect(_onAppOpenAdFailedToOpen)
	if not _yodo1mas_singleton.onAppOpenAdClosed.is_connected(_onAppOpenAdClosed):
		_yodo1mas_singleton.onAppOpenAdClosed.connect(_onAppOpenAdClosed)

	if not _yodo1mas_singleton.onRewardAdLoaded.is_connected(_onRewardAdLoaded):
		_yodo1mas_singleton.onRewardAdLoaded.connect(_onRewardAdLoaded)
	if not _yodo1mas_singleton.onRewardAdFailedToLoad.is_connected(_onRewardAdFailedToLoad):
		_yodo1mas_singleton.onRewardAdFailedToLoad.connect(_onRewardAdFailedToLoad)
	if not _yodo1mas_singleton.onRewardAdOpened.is_connected(_onRewardAdOpened):
		_yodo1mas_singleton.onRewardAdOpened.connect(_onRewardAdOpened)
	if not _yodo1mas_singleton.onRewardAdFailedToOpen.is_connected(_onRewardAdFailedToOpen):
		_yodo1mas_singleton.onRewardAdFailedToOpen.connect(_onRewardAdFailedToOpen)
	if not _yodo1mas_singleton.onRewardAdEarned.is_connected(_onRewardAdEarned):
		_yodo1mas_singleton.onRewardAdEarned.connect(_onRewardAdEarned)
	if not _yodo1mas_singleton.onRewardAdClosed.is_connected(_onRewardAdClosed):
		_yodo1mas_singleton.onRewardAdClosed.connect(_onRewardAdClosed)


# show / hide
func showReportAd() -> void:
	if _yodo1mas_singleton != null:
		_yodo1mas_singleton.showReportAd()
		
func loadBannerAd(size: String, horizontalAlignment: String, verticalAlignment: String, placementId: String = "base") -> void:
	_banner_created = true
	if _yodo1mas_singleton != null:
		_yodo1mas_singleton.loadBannerAd(size, horizontalAlignment, verticalAlignment, placementId)
		
func hideBannerAd() -> void:
	if _yodo1mas_singleton != null and _banner_created:
		_yodo1mas_singleton.hideBannerAd()
		
func showBannerAd() -> void:
	if _yodo1mas_singleton != null and _banner_created:
		_yodo1mas_singleton.showBannerAd()
		
func isInterstitialAdLoaded() -> bool:
	if _yodo1mas_singleton == null:
		return false
	return _yodo1mas_singleton.isInterstitialAdLoaded()
	
func initializeInterstitialAd() -> void:
	if _yodo1mas_singleton != null:
		_yodo1mas_singleton.initializeInterstitialAd()
		
func showInterstitialAd(placementId: String = "") -> void:
	if _yodo1mas_singleton != null:
		_yodo1mas_singleton.showInterstitialAd(placementId)

func isAppOpenAdLoaded() -> bool:
	if _yodo1mas_singleton == null:
		return false
	return _yodo1mas_singleton.isAppOpenAdLoaded()
	
func initializeAppOpenAd() -> void:
	if _yodo1mas_singleton != null:
		_yodo1mas_singleton.initializeAppOpenAd()
		
func showAppOpenAd(placementId: String = "") -> void:
	if _yodo1mas_singleton != null:
		_yodo1mas_singleton.showAppOpenAd(placementId)

func isRewardedAdLoaded() -> bool:
	if _yodo1mas_singleton == null:
		return false
	return _yodo1mas_singleton.isRewardedAdLoaded()
	
func initializeRewardedAd() -> void:
	if _yodo1mas_singleton != null:
		_yodo1mas_singleton.initializeRewardedAd()
		
func showRewardedAd(placementId: String = "") -> void:
	if _yodo1mas_singleton != null:
		_yodo1mas_singleton.showRewardedAd(placementId)


# callbacks from native plugin

func _onMasInitSuccessful() -> void:
	print("Yodo1Mas: Init successful")
	_is_initialized = true
	onMasInitSuccessful.emit()

func _onMasInitFailed() -> void:
	print("Yodo1Mas: Init failed")
	_is_initialized = false
	onMasInitFailed.emit()

func _onBannerAdLoaded() -> void:
	print("Yodo1Mas: Banner ad loaded")
	onBannerAdLoaded.emit()

func _onBannerAdFailedToLoad(error_code: int) -> void:
	print("Yodo1Mas: Banner ad failed to load, error code: ", error_code)
	onBannerAdFailedToLoad.emit(error_code)

func _onBannerAdOpened() -> void:
	print("Yodo1Mas: Banner ad opened")
	onBannerAdOpened.emit()

func _onBannerAdFailedToOpen(error_code: int) -> void:
	print("Yodo1Mas: Banner ad failed to open, error code: ", error_code)
	onBannerAdFailedToOpen.emit(error_code)

func _onBannerAdClosed() -> void:
	print("Yodo1Mas: Banner ad closed")
	onBannerAdClosed.emit()

func _onInterstitialAdLoaded() -> void:
	print("Yodo1Mas: Interstitial ad loaded successfully")
	onInterstitialAdLoaded.emit()

func _onInterstitialAdFailedToLoad(error_code: int) -> void:
	print("Yodo1Mas: Interstitial ad failed to load, error code: ", error_code)
	onInterstitialAdFailedToLoad.emit(error_code)

func _onInterstitialAdOpened() -> void:
	print("Yodo1Mas: Interstitial ad opened")
	onInterstitialAdOpened.emit()

func _onInterstitialAdFailedToOpen(error_code: int) -> void:
	print("Yodo1Mas: Interstitial ad failed to open, error code: ", error_code)
	onInterstitialAdFailedToOpen.emit(error_code)

func _onInterstitialAdClosed() -> void:
	print("Yodo1Mas: Interstitial ad closed")
	onInterstitialAdClosed.emit()

func _onAppOpenAdLoaded() -> void:
	print("Yodo1Mas: App Open ad loaded")
	onAppOpenAdLoaded.emit()

func _onAppOpenAdFailedToLoad(error_code: int) -> void:
	print("Yodo1Mas: App Open ad failed to load, error code: ", error_code)
	onAppOpenAdFailedToLoad.emit(error_code)

func _onAppOpenAdOpened() -> void:
	print("Yodo1Mas: App Open ad opened")
	onAppOpenAdOpened.emit()

func _onAppOpenAdFailedToOpen(error_code: int) -> void:
	print("Yodo1Mas: App Open ad failed to open, error code: ", error_code)
	onAppOpenAdFailedToOpen.emit(error_code)

func _onAppOpenAdClosed() -> void:
	print("Yodo1Mas: App Open ad closed")
	onAppOpenAdClosed.emit()

func _onRewardAdLoaded() -> void:
	print("Yodo1Mas: Reward ad loaded")
	onRewardAdLoaded.emit()

func _onRewardAdFailedToLoad(error_code: int) -> void:
	print("Yodo1Mas: Reward ad failed to load, error code: ", error_code)
	onRewardAdFailedToLoad.emit(error_code)

func _onRewardAdOpened() -> void:
	print("Yodo1Mas: Reward ad opened")
	onRewardAdOpened.emit()

func _onRewardAdFailedToOpen(error_code: int) -> void:
	print("Yodo1Mas: Reward ad failed to open, error code: ", error_code)
	onRewardAdFailedToOpen.emit(error_code)

func _onRewardAdEarned() -> void:
	print("Yodo1Mas: Reward ad earned")
	onRewardAdEarned.emit()

func _onRewardAdClosed() -> void:
	print("Yodo1Mas: Reward ad closed")
	onRewardAdClosed.emit()
