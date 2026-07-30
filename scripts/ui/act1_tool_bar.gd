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


func focus_primary_action() -> void:
	cover_button.grab_focus()
