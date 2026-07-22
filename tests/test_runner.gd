extends SceneTree

const SimulationClockScript: Script = preload("res://scripts/core/simulation_clock.gd")
const LifecycleTestSuiteScript: Script = preload(
	"res://tests/simulation/lifecycle_test_suite.gd"
)
const MainScene: PackedScene = preload("res://scenes/main/main.tscn")

var _assertion_count: int = 0
var _failure_count: int = 0
var _captured_tick_indices: Array[int] = []
var _captured_tick_steps: Array[float] = []


func _initialize() -> void:
	call_deferred("_run_all_tests")


func _run_all_tests() -> void:
	_test_fixed_step_accumulation()
	_test_speed_multipliers_keep_fixed_step()
	_test_pause_stops_progress()
	_test_invalid_delta_does_not_change_state()
	_test_frame_partition_does_not_change_result()
	_test_tick_signal_contract()
	_test_backlog_is_retained()
	_test_ten_thousand_ticks_without_drift()
	_test_reset_restores_defaults()
	_test_main_scene_clock_controls()
	_test_main_scene_lifecycle_boundary()
	_test_main_scene_stops_on_tick_desync()
	_run_lifecycle_test_suite()

	if _failure_count == 0:
		print("PASS: %d project assertions" % _assertion_count)
		quit(0)
		return

	printerr(
		"FAIL: %d of %d project assertions failed"
		% [_failure_count, _assertion_count]
	)
	quit(1)


func _run_lifecycle_test_suite() -> void:
	var suite: LifecycleTestSuite = LifecycleTestSuiteScript.new()
	suite.run()
	_assertion_count += suite.get_assertion_count()
	_failure_count += suite.get_failure_count()


func _test_fixed_step_accumulation() -> void:
	var clock: SimulationClock = SimulationClockScript.new()

	_expect_int(clock.advance(0.04), 0, "0.04 seconds does not complete a Tick")
	_expect_int(clock.advance(0.06), 1, "accumulated 0.10 seconds completes one Tick")
	_expect_int(clock.get_tick_index(), 1, "Tick index advances once")
	_expect_float(
		clock.get_simulation_time_seconds(),
		SimulationClock.FIXED_STEP_SECONDS,
		"simulation time uses the fixed step"
	)


func _test_speed_multipliers_keep_fixed_step() -> void:
	var clock: SimulationClock = SimulationClockScript.new()

	_expect_true(clock.set_speed_multiplier(4), "4x is an accepted speed")
	_expect_int(clock.advance(0.25), 10, "0.25 real seconds at 4x yields 10 Ticks")
	_expect_float(clock.get_simulation_time_seconds(), 1.0, "4x advances one simulated second")

	clock.reset()
	_expect_true(clock.set_speed_multiplier(16), "16x is an accepted speed")
	_expect_int(clock.advance(0.1), 16, "0.1 real seconds at 16x yields 16 Ticks")
	_expect_float(clock.get_simulation_time_seconds(), 1.6, "16x keeps 0.1-second Tick size")


func _test_pause_stops_progress() -> void:
	var clock: SimulationClock = SimulationClockScript.new()

	clock.advance(0.05)
	clock.set_paused(true)
	_expect_int(clock.advance(10.0), 0, "paused clock processes no Ticks")
	_expect_int(clock.get_tick_index(), 0, "paused clock keeps its Tick index")

	clock.set_paused(false)
	_expect_int(clock.advance(0.05), 1, "pause preserves a partial Tick")


func _test_invalid_delta_does_not_change_state() -> void:
	var clock: SimulationClock = SimulationClockScript.new()

	_expect_int(clock.advance(-0.1), 0, "negative delta is rejected")
	_expect_int(clock.advance(NAN), 0, "NaN delta is rejected")
	_expect_int(clock.advance(INF), 0, "infinite delta is rejected")
	_expect_int(clock.get_tick_index(), 0, "invalid deltas do not advance state")


func _test_frame_partition_does_not_change_result() -> void:
	var single_frame_clock: SimulationClock = SimulationClockScript.new()
	var many_frames_clock: SimulationClock = SimulationClockScript.new()

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
	var clock: SimulationClock = SimulationClockScript.new()
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
	var clock: SimulationClock = SimulationClockScript.new(TEST_FRAME_CAP)

	_expect_int(
		clock.advance(1.0),
		TEST_FRAME_CAP,
		"one frame respects the safety cap"
	)
	_expect_true(clock.get_backlog_tick_count() > 0, "excess Ticks remain in the backlog")

	var total_processed_ticks: int = TEST_FRAME_CAP
	var drain_iteration: int = 0
	while (
		clock.get_backlog_tick_count() > 0
		and drain_iteration < MAX_DRAIN_ITERATIONS
	):
		total_processed_ticks += clock.advance(0.0)
		drain_iteration += 1

	_expect_int(clock.get_backlog_tick_count(), 0, "backlog drains within a bounded loop")
	_expect_int(total_processed_ticks, 10, "backlog drains without dropping simulated time")
	_expect_int(clock.get_tick_index(), 10, "all retained Ticks eventually run")


func _test_ten_thousand_ticks_without_drift() -> void:
	var clock: SimulationClock = SimulationClockScript.new()
	var iteration: int = 0
	var total_processed_ticks: int = 0

	while iteration < 10_000:
		total_processed_ticks += clock.advance(SimulationClock.FIXED_STEP_SECONDS)
		iteration += 1

	_expect_int(total_processed_ticks, 10_000, "10,000 fixed steps process 10,000 Ticks")
	_expect_int(clock.get_tick_index(), 10_000, "10,000 Tick soak has no clock drift")


func _test_reset_restores_defaults() -> void:
	var clock: SimulationClock = SimulationClockScript.new()
	clock.set_speed_multiplier(16)
	clock.set_paused(true)
	clock.reset()

	_expect_int(clock.get_tick_index(), 0, "reset clears the Tick index")
	_expect_int(clock.get_speed_multiplier(), 1, "reset restores 1x speed")
	_expect_true(not clock.is_paused(), "reset resumes the clock")


func _test_main_scene_clock_controls() -> void:
	var main_controller: MainController = MainScene.instantiate() as MainController
	root.add_child(main_controller)

	var pause_button: Button = main_controller.get_node("%PauseButton") as Button
	var speed_1x_button: Button = main_controller.get_node("%Speed1xButton") as Button
	var speed_4x_button: Button = main_controller.get_node("%Speed4xButton") as Button
	var status_label: Label = main_controller.get_node("%StatusLabel") as Label
	var tick_label: Label = main_controller.get_node("%TickLabel") as Label

	_expect_true(speed_1x_button.disabled, "main scene starts at 1x")
	main_controller._process(0.1)
	_expect_string(tick_label.text, "固定 Tick：1", "main scene displays the first Tick")

	pause_button.pressed.emit()
	_expect_true(status_label.text.begins_with("已暂停"), "pause button updates status")
	var paused_tick_text: String = tick_label.text
	main_controller._process(1.0)
	_expect_string(tick_label.text, paused_tick_text, "paused main scene does not advance")

	speed_4x_button.pressed.emit()
	_expect_true(speed_4x_button.disabled, "4x button becomes the active speed")
	pause_button.pressed.emit()
	main_controller._process(0.25)
	_expect_string(tick_label.text, "固定 Tick：11", "resumed main scene uses selected 4x speed")

	root.remove_child(main_controller)
	main_controller.free()


func _test_main_scene_lifecycle_boundary() -> void:
	var main_controller: MainController = MainScene.instantiate() as MainController
	root.add_child(main_controller)
	var tick_label: Label = main_controller.get_node("%TickLabel") as Label
	var stage_counts_label: Label = main_controller.get_node("%StageCountsLabel") as Label
	var individuals_label: Label = main_controller.get_node("%IndividualsLabel") as Label

	var tick_iteration: int = 0
	while tick_iteration < 1199:
		main_controller._process(SimulationClock.FIXED_STEP_SECONDS)
		tick_iteration += 1
	_expect_string(tick_label.text, "固定 Tick：1199", "main scene reaches the pre-laying boundary")
	_expect_string(
		stage_counts_label.text,
		"卵 0    幼虫 0    蛹 0    工蚁 0",
		"main scene has no egg at Tick 1199"
	)
	_expect_int(
		main_controller._colony_simulation.create_snapshot().simulation_tick,
		1199,
		"main scene clock and colony match before laying"
	)

	main_controller._process(SimulationClock.FIXED_STEP_SECONDS)
	_expect_string(tick_label.text, "固定 Tick：1200", "main scene reaches the exact laying Tick")
	_expect_string(
		stage_counts_label.text,
		"卵 1    幼虫 0    蛹 0    工蚁 0",
		"main scene displays the first egg exactly at Tick 1200"
	)
	_expect_true(individuals_label.text.contains("#001  卵"), "main scene lists the stable brood ID")
	_expect_int(
		main_controller._colony_simulation.create_snapshot().simulation_tick,
		1200,
		"main scene clock and colony match after laying"
	)

	root.remove_child(main_controller)
	main_controller.free()


func _test_main_scene_stops_on_tick_desync() -> void:
	var main_controller: MainController = MainScene.instantiate() as MainController
	root.add_child(main_controller)
	var status_label: Label = main_controller.get_node("%StatusLabel") as Label
	var pause_button: Button = main_controller.get_node("%PauseButton") as Button
	var tick_label: Label = main_controller.get_node("%TickLabel") as Label

	_expect_true(
		main_controller._colony_simulation.advance_tick(1),
		"fault injection advances colony ahead of its clock"
	)
	main_controller._process(10.0)
	_expect_string(status_label.text, "模拟错误 · 已暂停", "Tick desync enters a visible fatal state")
	_expect_true(pause_button.disabled, "fatal Tick desync disables resume")
	_expect_string(tick_label.text, "固定 Tick：1", "fatal desync stops the current multi-Tick batch")
	var stopped_tick_text: String = tick_label.text
	main_controller._process(10.0)
	_expect_string(
		tick_label.text,
		stopped_tick_text,
		"fatal Tick desync stops further clock progress"
	)

	root.remove_child(main_controller)
	main_controller.free()


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


func _expect_string(actual: String, expected: String, message: String) -> void:
	_assertion_count += 1
	if actual == expected:
		return
	_record_failure(message, expected, actual)


func _record_failure(message: String, expected: String, actual: String) -> void:
	_failure_count += 1
	printerr("  %s — expected %s, got %s" % [message, expected, actual])
