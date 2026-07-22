class_name MainController
extends Control

var _simulation_clock: SimulationClock

@onready var _status_label: Label = %StatusLabel
@onready var _tick_label: Label = %TickLabel
@onready var _simulation_time_label: Label = %SimulationTimeLabel
@onready var _pause_button: Button = %PauseButton
@onready var _speed_1x_button: Button = %Speed1xButton
@onready var _speed_4x_button: Button = %Speed4xButton
@onready var _speed_16x_button: Button = %Speed16xButton


func _ready() -> void:
	_simulation_clock = SimulationClock.new()
	_simulation_clock.tick_requested.connect(_on_simulation_tick_requested)

	_pause_button.pressed.connect(_on_pause_button_pressed)
	_speed_1x_button.pressed.connect(_on_speed_button_pressed.bind(
		SimulationClock.NORMAL_SPEED
	))
	_speed_4x_button.pressed.connect(_on_speed_button_pressed.bind(
		SimulationClock.FAST_SPEED
	))
	_speed_16x_button.pressed.connect(_on_speed_button_pressed.bind(
		SimulationClock.VERY_FAST_SPEED
	))

	_update_clock_labels()
	_update_control_state()


func _process(delta: float) -> void:
	_simulation_clock.advance(delta)


func _on_simulation_tick_requested(
	tick_index: int,
	tick_seconds: float
) -> void:
	_tick_label.text = "固定 Tick：%d" % tick_index
	_simulation_time_label.text = (
		"模拟时间：%.1f 秒" % (float(tick_index) * tick_seconds)
	)


func _on_pause_button_pressed() -> void:
	_simulation_clock.toggle_paused()
	_update_control_state()


func _on_speed_button_pressed(multiplier: int) -> void:
	_simulation_clock.set_speed_multiplier(multiplier)
	_update_control_state()


func _update_clock_labels() -> void:
	_tick_label.text = "固定 Tick：%d" % _simulation_clock.get_tick_index()
	_simulation_time_label.text = (
		"模拟时间：%.1f 秒" % _simulation_clock.get_simulation_time_seconds()
	)


func _update_control_state() -> void:
	var speed_multiplier: int = _simulation_clock.get_speed_multiplier()
	var paused: bool = _simulation_clock.is_paused()

	_status_label.text = (
		"已暂停 · %d×" % speed_multiplier
		if paused
		else "运行中 · %d×" % speed_multiplier
	)
	_pause_button.text = "继续" if paused else "暂停"
	_speed_1x_button.disabled = speed_multiplier == SimulationClock.NORMAL_SPEED
	_speed_4x_button.disabled = speed_multiplier == SimulationClock.FAST_SPEED
	_speed_16x_button.disabled = speed_multiplier == SimulationClock.VERY_FAST_SPEED
