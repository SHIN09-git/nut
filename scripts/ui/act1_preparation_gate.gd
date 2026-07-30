class_name Act1PreparationGate
extends Control

signal start_requested

@onready var heading_label: Label = %PreparationHeading
@onready var body_label: Label = %PreparationBody
@onready var start_button: Button = %StartObservationButton


func _ready() -> void:
	start_button.pressed.connect(start_requested.emit)


func set_copy(
	heading_text: String,
	body_text: String,
	start_text: String
) -> void:
	heading_label.text = heading_text
	body_label.text = body_text
	start_button.text = start_text


func open() -> void:
	visible = true
	start_button.grab_focus()


func close() -> void:
	visible = false
