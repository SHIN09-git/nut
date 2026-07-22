class_name SimulationClockTestSuite
extends RefCounted

var _assertion_count: int = 0
var _failure_count: int = 0
var _captured_tick_indices: Array[int] = []
var _captured_tick_steps: Array[float] = []


func run() -> void:
	_test_fixed_step_accumulation()
	_test_speed_multipliers_keep_fixed_step()
	_test_pause_stops_progress()
	_test_invalid_delta_does_not_change_state()
	_test_frame_partition_does_not_change_result()
	_test_tick_signal_contract()
	_test_backlog_is_retained()
	_test_ten_thousand_ticks_without_drift()
	_test_reset_restores_defaults()


func get_assertion_count() -> int:
	return _assertion_count


func get_failure_count() -> int:
	return _failure_count


func _test_fixed_step_accumulation() -> void:
	var clock: SimulationClock = SimulationClock.new()

	_expect_int(clock.advance(0.04), 0, "0.04 seconds does not complete a Tick")
	_expect_int(clock.advance(0.06), 1, "accumulated 0.10 seconds completes one Tick")
	_expect_int(clock.get_tick_index(), 1, "Tick index advances once")
	_expect_float(
		clock.get_simulation_time_seconds(),
		SimulationClock.FIXED_STEP_SECONDS,
		"simulation time uses the fixed step"
	)


func _test_speed_multipliers_keep_fixed_step() -> void:
	var clock: SimulationClock = SimulationClock.new()

	_expect_true(clock.set_speed_multiplier(4), "4x is an accepted speed")
	_expect_int(clock.advance(0.25), 10, "0.25 real seconds at 4x yields 10 Ticks")
	_expect_float(clock.get_simulation_time_seconds(), 1.0, "4x advances one simulated second")

	clock.reset()
	_expect_true(clock.set_speed_multiplier(16), "16x is an accepted speed")
	_expect_int(clock.advance(0.1), 16, "0.1 real seconds at 16x yields 16 Ticks")
	_expect_float(clock.get_simulation_time_seconds(), 1.6, "16x keeps 0.1-second Tick size")


func _test_pause_stops_progress() -> void:
	var clock: SimulationClock = SimulationClock.new()

	clock.advance(0.05)
	clock.set_paused(true)
	_expect_int(clock.advance(10.0), 0, "paused clock processes no Ticks")
	_expect_int(clock.get_tick_index(), 0, "paused clock keeps its Tick index")

	clock.set_paused(false)
	_expect_int(clock.advance(0.05), 1, "pause preserves a partial Tick")


func _test_invalid_delta_does_not_change_state() -> void:
	var clock: SimulationClock = SimulationClock.new()

	_expect_int(clock.advance(-0.1), 0, "negative delta is rejected")
	_expect_int(clock.advance(NAN), 0, "NaN delta is rejected")
	_expect_int(clock.advance(INF), 0, "infinite delta is rejected")
	_expect_int(clock.get_tick_index(), 0, "invalid deltas do not advance state")


func _test_frame_partition_does_not_change_result() -> void:
	var single_frame_clock: SimulationClock = SimulationClock.new()
	var many_frames_clock: SimulationClock = SimulationClock.new()

	single_frame_clock.advance(1.0)
	var frame_index: int = 0
	while frame_index < 60:
		many_frames_clock.advance(1.0 / 60.0)
		frame_index += 1

	_expect_int(
		many_frames_clock.get_tick_index(),
		single_frame_clock.get_tick_index(),
		"frame partition does not change the Tick result"
	)


func _test_tick_signal_contract() -> void:
	var clock: SimulationClock = SimulationClock.new()
	_captured_tick_indices.clear()
	_captured_tick_steps.clear()
	clock.tick_requested.connect(_capture_tick_request)

	clock.advance(0.3)

	_expect_int(_captured_tick_indices.size(), 3, "three Ticks emit three requests")
	_expect_int(_captured_tick_indices[0], 1, "first signal uses Tick index 1")
	_expect_int(_captured_tick_indices[1], 2, "second signal uses Tick index 2")
	_expect_int(_captured_tick_indices[2], 3, "third signal uses Tick index 3")
	_expect_float(
		_captured_tick_steps[0],
		SimulationClock.FIXED_STEP_SECONDS,
		"signal exposes the fixed step"
	)
	_expect_float(
		_captured_tick_steps[2],
		SimulationClock.FIXED_STEP_SECONDS,
		"every signal keeps the same fixed step"
	)


func _test_backlog_is_retained() -> void:
	const TEST_FRAME_CAP: int = 3
	const MAX_DRAIN_ITERATIONS: int = 10
	var clock: SimulationClock = SimulationClock.new(TEST_FRAME_CAP)

	_expect_int(clock.advance(1.0), TEST_FRAME_CAP, "one frame respects the safety cap")
	_expect_true(clock.get_backlog_tick_count() > 0, "excess Ticks remain in the backlog")

	var total_processed_ticks: int = TEST_FRAME_CAP
	var drain_iteration: int = 0
	while clock.get_backlog_tick_count() > 0 and drain_iteration < MAX_DRAIN_ITERATIONS:
		total_processed_ticks += clock.advance(0.0)
		drain_iteration += 1

	_expect_int(clock.get_backlog_tick_count(), 0, "backlog drains within a bounded loop")
	_expect_int(total_processed_ticks, 10, "backlog drains without dropping simulated time")
	_expect_int(clock.get_tick_index(), 10, "all retained Ticks eventually run")


func _test_ten_thousand_ticks_without_drift() -> void:
	const SOAK_TICK_COUNT: int = 10_000
	var clock: SimulationClock = SimulationClock.new()
	var iteration: int = 0
	var total_processed_ticks: int = 0

	while iteration < SOAK_TICK_COUNT:
		total_processed_ticks += clock.advance(SimulationClock.FIXED_STEP_SECONDS)
		iteration += 1

	_expect_int(
		total_processed_ticks,
		SOAK_TICK_COUNT,
		"10,000 fixed steps process 10,000 Ticks"
	)
	_expect_int(clock.get_tick_index(), SOAK_TICK_COUNT, "10,000 Tick soak has no clock drift")


func _test_reset_restores_defaults() -> void:
	var clock: SimulationClock = SimulationClock.new()
	clock.set_speed_multiplier(16)
	clock.set_paused(true)
	clock.reset()

	_expect_int(clock.get_tick_index(), 0, "reset clears the Tick index")
	_expect_int(clock.get_speed_multiplier(), 1, "reset restores 1x speed")
	_expect_true(not clock.is_paused(), "reset resumes the clock")


func _capture_tick_request(tick_index: int, tick_seconds: float) -> void:
	_captured_tick_indices.append(tick_index)
	_captured_tick_steps.append(tick_seconds)


func _expect_int(actual: int, expected: int, message: String) -> void:
	_assertion_count += 1
	if actual == expected:
		return
	_record_failure(message, str(expected), str(actual))


func _expect_float(actual: float, expected: float, message: String) -> void:
	_assertion_count += 1
	if is_equal_approx(actual, expected):
		return
	_record_failure(message, str(expected), str(actual))


func _expect_true(actual: bool, message: String) -> void:
	_assertion_count += 1
	if actual:
		return
	_record_failure(message, "true", "false")


func _record_failure(message: String, expected: String, actual: String) -> void:
	_failure_count += 1
	printerr("  %s - expected %s, got %s" % [message, expected, actual])
