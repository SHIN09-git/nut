class_name SimulationClock
extends RefCounted

signal tick_requested(tick_index: int, tick_seconds: float)

const FIXED_STEP_SECONDS: float = 0.1
const NORMAL_SPEED: int = 1
const FAST_SPEED: int = 4
const VERY_FAST_SPEED: int = 16
const DEFAULT_MAX_TICKS_PER_FRAME: int = 16
const ACCUMULATOR_EPSILON: float = 0.0000001

var _accumulator_seconds: float = 0.0
var _tick_index: int = 0
var _speed_multiplier: int = NORMAL_SPEED
var _paused: bool = false
var _max_ticks_per_frame: int = DEFAULT_MAX_TICKS_PER_FRAME


func _init(max_ticks_per_frame: int = DEFAULT_MAX_TICKS_PER_FRAME) -> void:
	if max_ticks_per_frame > 0:
		_max_ticks_per_frame = max_ticks_per_frame


func advance(real_delta_seconds: float) -> int:
	if (
		real_delta_seconds < 0.0
		or is_nan(real_delta_seconds)
		or is_inf(real_delta_seconds)
	):
		return 0
	if _paused:
		return 0

	_accumulator_seconds += real_delta_seconds * float(_speed_multiplier)
	var ticks_due: int = int(floor(
		(_accumulator_seconds + ACCUMULATOR_EPSILON) / FIXED_STEP_SECONDS
	))
	var ticks_to_process: int = ticks_due
	if ticks_to_process > _max_ticks_per_frame:
		ticks_to_process = _max_ticks_per_frame

	var processed_ticks: int = 0
	while processed_ticks < ticks_to_process:
		_accumulator_seconds -= FIXED_STEP_SECONDS
		if absf(_accumulator_seconds) < ACCUMULATOR_EPSILON:
			_accumulator_seconds = 0.0
		_tick_index += 1
		processed_ticks += 1
		tick_requested.emit(_tick_index, FIXED_STEP_SECONDS)

	return processed_ticks


func set_speed_multiplier(multiplier: int) -> bool:
	if (
		multiplier != NORMAL_SPEED
		and multiplier != FAST_SPEED
		and multiplier != VERY_FAST_SPEED
	):
		return false

	_speed_multiplier = multiplier
	return true


func set_paused(value: bool) -> void:
	_paused = value


func toggle_paused() -> bool:
	_paused = not _paused
	return _paused


func reset() -> void:
	_accumulator_seconds = 0.0
	_tick_index = 0
	_speed_multiplier = NORMAL_SPEED
	_paused = false


func get_tick_index() -> int:
	return _tick_index


func get_simulation_time_seconds() -> float:
	return float(_tick_index) * FIXED_STEP_SECONDS


func get_speed_multiplier() -> int:
	return _speed_multiplier


func is_paused() -> bool:
	return _paused


func get_interpolation_alpha() -> float:
	return clampf(_accumulator_seconds / FIXED_STEP_SECONDS, 0.0, 1.0)


func get_backlog_tick_count() -> int:
	return int(floor(
		(_accumulator_seconds + ACCUMULATOR_EPSILON) / FIXED_STEP_SECONDS
	))
