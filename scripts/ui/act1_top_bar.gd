class_name Act1TopBar
extends PanelContainer

signal help_requested
signal pause_requested
signal speed_requested(multiplier: int)

@onready var title_label: Label = %Title
@onready var chapter_label: Label = %ChapterLabel
@onready var status_label: Label = %StatusLabel
@onready var help_button: Button = %HelpButton
@onready var pause_button: Button = %PauseButton
@onready var speed_1x_button: Button = %Speed1xButton
@onready var speed_4x_button: Button = %Speed4xButton
@onready var speed_16x_button: Button = %Speed16xButton


func _ready() -> void:
	help_button.pressed.connect(help_requested.emit)
	pause_button.pressed.connect(pause_requested.emit)
	speed_1x_button.pressed.connect(
		speed_requested.emit.bind(SimulationClock.NORMAL_SPEED)
	)
	speed_4x_button.pressed.connect(
		speed_requested.emit.bind(SimulationClock.FAST_SPEED)
	)
	speed_16x_button.pressed.connect(
		speed_requested.emit.bind(SimulationClock.VERY_FAST_SPEED)
	)


func set_copy(
	title_text: String,
	help_tooltip: String
) -> void:
	title_label.text = title_text
	help_button.text = "?"
	help_button.tooltip_text = help_tooltip


func set_runtime_state(
	chapter_text: String,
	status_text: String,
	speed_multiplier: int,
	controls_blocked: bool,
	help_blocked: bool
) -> void:
	chapter_label.text = chapter_text
	status_label.text = status_text
	help_button.disabled = help_blocked
	for button: Button in [
		pause_button,
		speed_1x_button,
		speed_4x_button,
		speed_16x_button,
	]:
		button.disabled = controls_blocked
	speed_1x_button.button_pressed = (
		speed_multiplier == SimulationClock.NORMAL_SPEED
	)
	speed_4x_button.button_pressed = (
		speed_multiplier == SimulationClock.FAST_SPEED
	)
	speed_16x_button.button_pressed = (
		speed_multiplier == SimulationClock.VERY_FAST_SPEED
	)


func show_fatal_status(message: String) -> void:
	status_label.text = message
	status_label.modulate = Color(1.0, 0.55, 0.46)


func focus_pause_button() -> void:
	pause_button.grab_focus()
