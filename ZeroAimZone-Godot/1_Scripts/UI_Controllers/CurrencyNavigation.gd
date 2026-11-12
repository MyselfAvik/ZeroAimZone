class_name CurrencyNavigation
extends RefCounted


enum Section {
	COINS,
	GEMS,
}


static func open_shop(section: Section) -> void:
	if GameManager.ui_manager == null or GameManager.ui_manager.base_panel == null:
		return

	if not GameManager.ui_manager.base_panel.is_visible_in_tree():
		GameManager.ui_manager.enable_panel(UIManager.PanelType.BASE)

	GameManager.ui_manager.base_panel.open_shop_section(section)
