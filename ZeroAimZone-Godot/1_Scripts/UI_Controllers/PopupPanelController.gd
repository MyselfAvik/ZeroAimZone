class_name PopupPanelController
extends Control

@export var daily_reward_popup: DailyRewardController
@export var round_countdown_popup: RoundCountdownController
@export var no_internet_popup: NoInternetPopupController
@export var freind_request_popup: FriendRequestPopupController
@export var chest_popup: ChestPopupController
@export var gun_stat_popup: Node
@export var black_screen_popup: BlackScreenPopupController
@export var room_close_popup: RoomClosePopupController
@export var quit_popup: QuitPopupController
@export var confirm_purchase_popup: ConfirmPurchasePopupController
@export var insufficient_diamonds_popup: EnoughCoinPopupController
@export var credits_popup: CreditPopupController
@export var tc_popup: TCPopupController
@export var game_quit_popup: GameQuitPopupController
@export var adbreak_popup: AdBreakPopupController
@export var delete_account_popup: DeleteAccountPopupController
@export var update_popup: UpdatePopupController
@export var confirm_skin_purchase_popup: ConfirmSkinPurchasePopupController
@export var skin_reward_panel: SkinRewardPanelController
@export var daily_gun_card_reward_popup: BasePopupController
@export var no_ads_popup: NoAdsPopupController
@export var auth_retry_popup: AuthRetryPopupController


enum PopupType {
	DAILYREWARD,
	ROUND_COUNTDOWN,
	NOINTERNET,
	FRIENDREQUEST,
	CHEST,
	GUNSTAT,
	BLACK,
	ROOMCLOSE,
	QUIT,
	CONFIRMPURCHASE,
	INSUFFICIENT_DIAMONDS,
	CREDITS,
	TC,
	GAMEQUIT,
	ADBREAK,
	DELETEACCOUNT,
	UPDATE,
	CONFIRMSKINPURCHASE,
	SKINREWARD,
	DAILYGUNCARDREWARD,
	NOADS,
	AUTH_RETRY
}
var popup_map = {
	
}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if not is_instance_valid(gun_stat_popup) and has_node("GunStatsPopup"):
		gun_stat_popup = get_node("GunStatsPopup")
	if not is_instance_valid(update_popup) and has_node("Update_Popup"):
		update_popup = get_node("Update_Popup")
	if not is_instance_valid(auth_retry_popup) and has_node("AuthRetryPopup"):
		auth_retry_popup = get_node("AuthRetryPopup")
		
	popup_map = {
		PopupType.DAILYREWARD: daily_reward_popup,
		PopupType.ROUND_COUNTDOWN: round_countdown_popup,
		PopupType.NOINTERNET: no_internet_popup,
		PopupType.FRIENDREQUEST: freind_request_popup,
		PopupType.CHEST: chest_popup,
		PopupType.GUNSTAT: gun_stat_popup,
		PopupType.BLACK: black_screen_popup,
		PopupType.ROOMCLOSE: room_close_popup,
		PopupType.QUIT: quit_popup,
		PopupType.CONFIRMPURCHASE: confirm_purchase_popup,
		PopupType.INSUFFICIENT_DIAMONDS: insufficient_diamonds_popup,
		PopupType.CREDITS: credits_popup,
		PopupType.TC: tc_popup,
		PopupType.GAMEQUIT: game_quit_popup,
		PopupType.ADBREAK: adbreak_popup,
		PopupType.DELETEACCOUNT: delete_account_popup,
		PopupType.UPDATE: update_popup,
		PopupType.CONFIRMSKINPURCHASE: confirm_skin_purchase_popup,
		PopupType.SKINREWARD: skin_reward_panel,
		PopupType.DAILYGUNCARDREWARD: daily_gun_card_reward_popup,
		PopupType.NOADS: no_ads_popup,
		PopupType.AUTH_RETRY: auth_retry_popup
	}


func show_popup(type: PopupType):
	var pop = popup_map.get(type, null)
	if not is_instance_valid(pop):
		return

	# If device is offline, only the No Internet popup is allowed to show
	if not NetworkMonitor.has_internet and type != PopupType.NOINTERNET:
		return

	# Strictly enforce single active popup: instantly hide other open popups to avoid overlapping
	for popup in popup_map.values():
		if is_instance_valid(popup) and popup != pop and popup.visible:
			popup.visible = false
			if popup.has_method("_stop_transition"):
				popup._stop_transition()

	show()
	visible = true
	if get_parent():
		get_parent().move_child(self, -1)
	pop.show_popup()


func show_chest_popup(crate_slot: CrateSlotController) -> void:
	chest_popup.setup(crate_slot)
	show_popup(PopupType.CHEST)


func show_confirm_purchase_popup(data: ShopData) -> void:
	confirm_purchase_popup.setup(data)
	show_popup(PopupType.CONFIRMPURCHASE)

func show_confirm_skin_purchase_popup(gunindex: int, skinindex: int, diamond_cost: int, gundata: GunSO) -> void:
	confirm_skin_purchase_popup.setup(gunindex, skinindex, diamond_cost, gundata)
	show_popup(PopupType.CONFIRMSKINPURCHASE)

func show_skin_reward_panel(gunindex: int, skinindex: int, gundata: GunSO) -> void:
	skin_reward_panel.setup_skin(gunindex, skinindex, gundata)
	show_popup(PopupType.SKINREWARD)

func show_gun_reward_panel(gunindex: int, gundata: GunSO) -> void:
	skin_reward_panel.setup_gun(gunindex, gundata)
	show_popup(PopupType.SKINREWARD)

func show_daily_gun_card_reward_popup(gunindex: int, card_amount: int, daily_reward: DailyRewardController) -> void:
	daily_gun_card_reward_popup.setup(gunindex, card_amount, daily_reward)
	show_popup(PopupType.DAILYGUNCARDREWARD)

func show_insufficient_diamonds_popup() -> void:
	show_popup(PopupType.INSUFFICIENT_DIAMONDS)

func show_no_ads_popup() -> void:
	show_popup(PopupType.NOADS)

func show_auth_retry_popup(message: String = "") -> void:
	if is_instance_valid(auth_retry_popup):
		if auth_retry_popup.has_method("set_message"):
			auth_retry_popup.set_message(message)
	show_popup(PopupType.AUTH_RETRY)

func hide_auth_retry_popup() -> void:
	if is_instance_valid(auth_retry_popup) and auth_retry_popup.visible:
		auth_retry_popup.hide_popup()


func hide_popup():
	for popup in popup_map.values():
		if is_instance_valid(popup):
			if not NetworkMonitor.has_internet and popup == no_internet_popup:
				continue
			if is_instance_valid(update_popup) and popup == update_popup and popup.visible:
				continue
			popup.hide_popup()

func is_popup_visible() -> bool:
	for popup in popup_map.values():
		if is_instance_valid(popup) and popup.visible:
			return true
	return false
