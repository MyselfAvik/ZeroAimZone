class_name ArenaSelectionPanelController
extends Control

@export var arena_database:ArenaDatabase


var arena_infos:Array[ArenaInfo]
@export var diamond_texture_ios:Texture
@export var arena_card_parent: Control
@export var coin_count_label: Label
@export var diamond_count_label: Label
@export var premium_currency_effect_script: Script
@export var coin_button: TextureButton
@export var diamond_button: TextureButton


func _ready() -> void:
	arena_infos=arena_database.arena_database
	var i=0
	for card:ArenaCardController in arena_card_parent.get_children():
		card.entry_amount=arena_infos[i].entry_fee
		card.reward_amount=arena_infos[i].winning_amount
		card.bg_texture=arena_infos[i].bg_texture
		card.logo_texture=arena_infos[i].logo_texture
		card.logo_star_color =arena_infos[i].logo_glow_color
		card.arena_index=i
		var button = card.get_child(0) as TextureButton
		card.setup()
		button.pressed.connect(go_to_gameplay.bind(card))
		i+=1
	diamond_button.pressed.connect(_on_diamond_button_pressed)
	coin_button.pressed.connect(_on_coin_button_pressed)
	if OS.get_name()=="iOS":
		diamond_button.texture_normal=diamond_texture_ios
		diamond_button.get_child(0).visible=false
		
		diamond_button.get_child(1).visible=true
		diamond_button.get_child(2).offset_left=0.5
		
		
	update_currency()
	if GameManager.save_manager and not GameManager.save_manager.currency_updated.is_connected(update_currency):
		GameManager.save_manager.currency_updated.connect(update_currency)

	_add_premium_effect(coin_count_label)
	_add_premium_effect(diamond_count_label)


func _add_premium_effect(label: Label) -> void:
	if label and label.get_parent() and premium_currency_effect_script:
		var effect = premium_currency_effect_script.new()
		label.get_parent().add_child(effect)



func update_currency() -> void:
	if diamond_count_label:
		diamond_count_label.text = GameManager.format_number(GameManager.save_manager.game_data["currency"]["Diamonds"])
	if coin_count_label:
		coin_count_label.text = GameManager.format_number(GameManager.save_manager.game_data["currency"]["Coins"])



func _on_back_button_pressed() -> void:
	GameAnalysis.track_screen_switch("Arena", "Home")
	GameManager.ui_manager.enable_panel(GameManager.ui_manager.PanelType.BASE)

func _on_diamond_button_pressed() -> void:
	if OS.get_name()=="iOS":
		return
	GameAnalysis.track_ui_click("UI:Clicks:Arena:Add_Diamonds")
	CurrencyNavigation.open_shop(CurrencyNavigation.Section.GEMS)
	GameAnalysis.track_screen_switch("Arena", "Home")

	


func _on_coin_button_pressed() -> void:
	GameAnalysis.track_ui_click("UI:Clicks:Arena:Add_Coins")
	CurrencyNavigation.open_shop(CurrencyNavigation.Section.COINS)
	GameAnalysis.track_screen_switch("Arena", "Home")


func go_to_gameplay(card: ArenaCardController) -> void:
	if arena_card_parent.has_dragged:
		return
	

	var reward_amount := card.reward_amount
	var entry_fee := card.entry_amount
	var logo_texture := card.logo_texture
	if reward_amount <= 0 or entry_fee <= 0:
		push_error("Selected arena has an invalid coin reward or entry fee.")
		return

	if int(GameManager.save_manager.game_data["currency"]["Coins"]) < entry_fee:
		GameManager.ui_manager.popup_panel.insufficient_diamonds_popup.header_label.text = "not enough coins"
		GameManager.ui_manager.popup_panel.insufficient_diamonds_popup.text_label.text = "Top up to get more coins or play to earn."
		GameManager.ui_manager.popup_panel.show_insufficient_diamonds_popup()
		push_warning("Not enough coins for this arena's entry fee.")
		return
	GameManager.current_match.arena_gameplay_color=arena_database.arena_database[card.arena_index].gameplay_bg_color
	GameManager.current_match.arena_index=card.arena_index
	GameManager.current_match.coin_reward = reward_amount
	GameManager.current_match.entry_fee = entry_fee
	GameManager.ui_manager.match_making_panel.set_match_coin_amounts(entry_fee, reward_amount)
	GameManager.ui_manager.match_making_panel.set_arena_texture(logo_texture)
	GameAnalysis.track_screen_switch("Arena", "Matchmaking")
	GameManager.ui_manager.enable_panel(GameManager.ui_manager.PanelType.MATCHMAKING)
