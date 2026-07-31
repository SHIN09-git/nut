class_name Act1ToolBar
extends PanelContainer

signal cover_requested
signal magnifier_requested
signal sugar_requested
signal protein_requested
signal clean_waste_requested
signal layout_requested(enabled: bool)
signal placement_requested
signal facility_type_selected(index: int)
signal rotate_requested
signal remove_requested
signal gate_toggle_requested
signal zoom_out_requested
signal camera_reset_requested
signal zoom_in_requested

@onready var cover_button: Button = %CoverButton
@onready var magnifier_button: Button = %MagnifierButton
@onready var sugar_placement_option: OptionButton = %SugarPlacementOption
@onready var sugar_button: Button = %SugarButton
@onready var protein_button: Button = %ProteinButton
@onready var clean_waste_button: Button = %CleanWasteButton
@onready var layout_button: Button = %LayoutButton
@onready var facility_type_option: OptionButton = %FacilityTypeOption
@onready var place_button: Button = %PlaceBoxButton
@onready var rotate_button: Button = %RotateFacilityButton
@onready var remove_button: Button = %RemoveFacilityButton
@onready var gate_button: Button = %ToggleGateButton
@onready var zoom_out_button: Button = %ZoomOutButton
@onready var reset_camera_button: Button = %ResetCameraButton
@onready var zoom_in_button: Button = %ZoomInButton
@onready var action_feedback_label: Label = %ActionFeedbackLabel
@onready var context_label: Label = %ContextLabel
@onready var layout_controls: ScrollContainer = %LayoutRowScroll
@onready var prototype_label: Label = %PrototypeLabel

var _disabled_reasons: Dictionary[Button, String] = {}


func _ready() -> void:
	cover_button.pressed.connect(cover_requested.emit)
	magnifier_button.pressed.connect(magnifier_requested.emit)
	sugar_button.pressed.connect(sugar_requested.emit)
	protein_button.pressed.connect(protein_requested.emit)
	clean_waste_button.pressed.connect(clean_waste_requested.emit)
	layout_button.pressed.connect(
		func() -> void:
			layout_requested.emit(layout_button.button_pressed)
	)
	place_button.pressed.connect(placement_requested.emit)
	facility_type_option.item_selected.connect(
		facility_type_selected.emit
	)
	rotate_button.pressed.connect(rotate_requested.emit)
	remove_button.pressed.connect(remove_requested.emit)
	gate_button.pressed.connect(gate_toggle_requested.emit)
	zoom_out_button.pressed.connect(zoom_out_requested.emit)
	reset_camera_button.pressed.connect(camera_reset_requested.emit)
	zoom_in_button.pressed.connect(zoom_in_requested.emit)
	for button: Button in _reason_buttons():
		button.mouse_entered.connect(
			_show_button_reason.bind(button)
		)
		button.focus_entered.connect(
			_show_button_reason.bind(button)
		)


func set_copy(
	cover_text: String,
	magnifier_text: String,
	sugar_text: String,
	protein_text: String,
	clean_waste_text: String,
	layout_text: String,
	rotate_text: String,
	remove_text: String,
	gate_text: String,
	reset_camera_text: String,
	prototype_notice_text: String
) -> void:
	cover_button.text = cover_text
	magnifier_button.text = magnifier_text
	sugar_button.text = sugar_text
	protein_button.text = protein_text
	clean_waste_button.text = clean_waste_text
	layout_button.text = layout_text
	rotate_button.text = rotate_text
	remove_button.text = remove_text
	gate_button.text = gate_text
	reset_camera_button.text = reset_camera_text
	prototype_label.text = prototype_notice_text


func set_sugar_placement_choices(
	choice_ids: Array[StringName],
	choice_labels: Array[String],
	selected_choice_id: StringName = &""
) -> void:
	var previous_choice_id: StringName = get_sugar_placement_choice_id()
	sugar_placement_option.clear()
	for index: int in choice_ids.size():
		sugar_placement_option.add_item(choice_labels[index])
		sugar_placement_option.set_item_metadata(index, choice_ids[index])
	var target_choice_id: StringName = (
		selected_choice_id
		if not selected_choice_id.is_empty()
		else previous_choice_id
	)
	for index: int in sugar_placement_option.item_count:
		if StringName(
			sugar_placement_option.get_item_metadata(index)
		) == target_choice_id:
			sugar_placement_option.select(index)
			return
	if sugar_placement_option.item_count > 0:
		sugar_placement_option.select(0)


func get_sugar_placement_choice_id() -> StringName:
	var selected_index: int = sugar_placement_option.selected
	if (
		selected_index < 0
		or selected_index >= sugar_placement_option.item_count
	):
		return &""
	return StringName(
		sugar_placement_option.get_item_metadata(selected_index)
	)


func set_layout_enabled(value: bool) -> void:
	layout_button.button_pressed = value
	layout_controls.visible = value


func set_context_text(value: String) -> void:
	context_label.text = value


func set_feedback(
	message: String,
	is_error: bool
) -> void:
	action_feedback_label.text = "%s %s" % [
		"!" if is_error else "✓",
		message,
	]
	action_feedback_label.modulate = (
		Color(1.0, 0.68, 0.56)
		if is_error else Color(0.68, 0.9, 0.72)
	)
	action_feedback_label.visible = true


func set_disabled_reason(button: Button, reason: String) -> void:
	if button == null:
		return
	_disabled_reasons[button] = reason
	button.tooltip_text = reason if button.disabled else ""


func set_hint(message: String) -> void:
	action_feedback_label.text = "• %s" % message
	action_feedback_label.modulate = Color(0.77, 0.86, 0.78)
	action_feedback_label.visible = not message.is_empty()


func _show_button_reason(button: Button) -> void:
	if button == null or not button.disabled:
		return
	var reason: String = _disabled_reasons.get(button, "")
	if not reason.is_empty():
		set_hint(reason)


func _reason_buttons() -> Array[Button]:
	return [
		cover_button,
		sugar_button,
		protein_button,
		clean_waste_button,
		layout_button,
		place_button,
		rotate_button,
		remove_button,
		gate_button,
		zoom_out_button,
		reset_camera_button,
		zoom_in_button,
		magnifier_button,
	]


func focus_primary_action() -> void:
	cover_button.grab_focus()
