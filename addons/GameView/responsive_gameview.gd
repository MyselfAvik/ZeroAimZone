@tool
extends EditorPlugin

const RATIOS := {
	"3:4": Vector2i(3, 4),
	"9:16": Vector2i(9, 16),
	"9:21": Vector2i(9, 21),
	"3:5": Vector2i(3, 5),
}
const ORIENTATION_LANDSCAPE := 0
const ORIENTATION_PORTRAIT := 1

var _panel: PanelContainer
var _orientation_button: OptionButton
var _ratio_button: OptionButton
var _short_side_spin: SpinBox
var _resolution_label: Label
var _setting_label: Label
var _bottom_panel_button: Button


func _enter_tree() -> void:
	_panel = _build_panel()
	_bottom_panel_button = add_control_to_bottom_panel(_panel, "GameView Controls")
	_update_preview()


func _exit_tree() -> void:
	if _panel != null:
		remove_control_from_bottom_panel(_panel)
		_panel.queue_free()
		_panel = null
	_bottom_panel_button = null


func _build_panel() -> PanelContainer:
	var panel := PanelContainer.new()
	panel.name = "ResponsiveGameView"
	panel.custom_minimum_size = Vector2(460, 220)

	var margins := MarginContainer.new()
	margins.add_theme_constant_override("margin_left", 12)
	margins.add_theme_constant_override("margin_top", 12)
	margins.add_theme_constant_override("margin_right", 12)
	margins.add_theme_constant_override("margin_bottom", 12)
	panel.add_child(margins)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 10)
	margins.add_child(root)

	var title := Label.new()
	title.text = "Responsive GameView"
	title.add_theme_font_size_override("font_size", 18)
	root.add_child(title)

	var settings_grid := GridContainer.new()
	settings_grid.columns = 2
	settings_grid.add_theme_constant_override("h_separation", 12)
	settings_grid.add_theme_constant_override("v_separation", 8)
	root.add_child(settings_grid)

	settings_grid.add_child(_field_label("Orientation"))
	_orientation_button = OptionButton.new()
	_orientation_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_orientation_button.add_item("Portrait")
	_orientation_button.add_item("Landscape")
	_orientation_button.item_selected.connect(_on_setting_changed)
	settings_grid.add_child(_orientation_button)

	settings_grid.add_child(_field_label("Aspect ratio"))
	_ratio_button = OptionButton.new()
	_ratio_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for ratio_name in RATIOS.keys():
		_ratio_button.add_item(ratio_name)
	_ratio_button.item_selected.connect(_on_setting_changed)
	settings_grid.add_child(_ratio_button)

	settings_grid.add_child(_field_label("Short side"))
	_short_side_spin = SpinBox.new()
	_short_side_spin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_short_side_spin.min_value = 240
	_short_side_spin.max_value = 4320
	_short_side_spin.step = 1
	_short_side_spin.value = 1080
	_short_side_spin.suffix = " px"
	_short_side_spin.value_changed.connect(_on_short_side_changed)
	settings_grid.add_child(_short_side_spin)

	_resolution_label = Label.new()
	_resolution_label.text = "Resolution: -"
	root.add_child(_resolution_label)

	var button_row := HBoxContainer.new()
	button_row.add_theme_constant_override("separation", 8)
	root.add_child(button_row)

	var apply_button := Button.new()
	apply_button.text = "Apply to Project"
	apply_button.pressed.connect(_apply_resolution)
	button_row.add_child(apply_button)

	var copy_button := Button.new()
	copy_button.text = "Copy Resolution"
	copy_button.pressed.connect(_copy_resolution)
	button_row.add_child(copy_button)

	_setting_label = Label.new()
	_setting_label.text = ""
	root.add_child(_setting_label)

	return panel


func _field_label(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return label


func _on_setting_changed(_index: int) -> void:
	_update_preview()


func _on_short_side_changed(_value: float) -> void:
	_update_preview()


func _get_resolution() -> Vector2i:
	var ratio_name := _ratio_button.get_item_text(_ratio_button.selected)
	var ratio: Vector2i = RATIOS[ratio_name]
	var short_side := int(_short_side_spin.value)

	if _orientation_button.selected == 0:
		return Vector2i(short_side, roundi(float(short_side) * ratio.y / ratio.x))

	return Vector2i(roundi(float(short_side) * ratio.y / ratio.x), short_side)


func _update_preview() -> void:
	if _resolution_label == null:
		return

	var resolution := _get_resolution()
	_resolution_label.text = "Resolution: %d x %d" % [resolution.x, resolution.y]


func _apply_resolution() -> void:
	var resolution := _get_resolution()
	var orientation := ORIENTATION_PORTRAIT if _orientation_button.selected == 0 else ORIENTATION_LANDSCAPE

	ProjectSettings.set_setting("display/window/size/viewport_width", resolution.x)
	ProjectSettings.set_setting("display/window/size/viewport_height", resolution.y)
	ProjectSettings.set_setting("display/window/size/window_width_override", resolution.x)
	ProjectSettings.set_setting("display/window/size/window_height_override", resolution.y)
	ProjectSettings.set_setting("display/window/handheld/orientation", orientation)
	ProjectSettings.save()
	_setting_label.text = "Applied %d x %d to project settings." % [resolution.x, resolution.y]


func _copy_resolution() -> void:
	var resolution := _get_resolution()
	DisplayServer.clipboard_set("%dx%d" % [resolution.x, resolution.y])
	_setting_label.text = "Copied %d x %d." % [resolution.x, resolution.y]
