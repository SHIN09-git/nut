class_name Act1PauseMenu
extends Control

signal resume_requested
signal save_requested
signal return_requested
signal restart_requested
signal exit_requested

@onready var heading_label: Label = %PauseHeading
@onready var resume_button: Button = %ResumeButton
@onready var save_button: Button = %SaveGameButton
@onready var return_button: Button = %ReturnToTitleButton
@onready var restart_button: Button = %RestartButton
@onready var exit_button: Button = %ExitButton
@onready var save_status: Label = %SaveStatus


func _ready() -> void:
	resume_button.pressed.connect(resume_requested.emit)
	save_button.pressed.connect(save_requested.emit)
	return_button.pressed.connect(return_requested.emit)
	restart_button.pressed.connect(restart_requested.emit)
	exit_button.pressed.connect(exit_requested.emit)


func set_copy(
	heading_text: String,
	resume_text: String,
	save_text: String,
	return_text: String,
	restart_text: String,
	exit_text: String
) -> void:
	heading_label.text = heading_text
	resume_button.text = resume_text
	save_button.text = save_text
	return_button.text = return_text
	restart_button.text = restart_text
	exit_button.text = exit_text


func open_and_focus() -> void:
	visible = true
	resume_button.grab_focus()


func close() -> void:
	visible = false


func set_exit_visible(value: bool) -> void:
	exit_button.visible = value


func show_save_result(message: String, success: bool) -> void:
	save_status.text = message
	save_status.modulate = (
		Color(0.68, 0.9, 0.72)
		if success else Color(1.0, 0.62, 0.52)
	)
	save_status.visible = true
