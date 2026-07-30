class_name Act1CompletionPanel
extends Control

signal continue_requested
signal return_requested

@onready var heading_label: Label = %CompletionHeading
@onready var body_label: Label = %CompletionBody
@onready var continue_button: Button = %ContinueFreeplayButton
@onready var return_button: Button = %CompletionReturnTitleButton


func _ready() -> void:
	continue_button.pressed.connect(continue_requested.emit)
	return_button.pressed.connect(return_requested.emit)


func set_copy(
	heading_text: String,
	body_text: String,
	continue_text: String,
	return_text: String
) -> void:
	heading_label.text = heading_text
	body_label.text = body_text
	continue_button.text = continue_text
	return_button.text = return_text


func set_body(value: String) -> void:
	body_label.text = value
