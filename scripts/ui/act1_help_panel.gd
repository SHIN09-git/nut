class_name Act1HelpPanel
extends Control

signal close_requested

@onready var heading_label: Label = %HelpHeading
@onready var body_label: Label = %HelpBody
@onready var close_button: Button = %HelpCloseButton


func _ready() -> void:
	close_button.pressed.connect(close_requested.emit)


func set_copy(
	heading_text: String,
	body_text: String,
	close_text: String
) -> void:
	heading_label.text = heading_text
	body_label.text = body_text
	close_button.text = close_text


func open_and_focus() -> void:
	visible = true
	close_button.grab_focus()


func close() -> void:
	visible = false
