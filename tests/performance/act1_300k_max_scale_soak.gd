extends SceneTree

const DEFAULT_SOAK_TICKS: int = 300_000
const CHECKPOINT_INTERVAL: int = 1_000
const SNAPSHOT_SAMPLE_INTERVAL: int = 1_000
const FRAME_SAMPLE_WARMUP: int = 60
const TICK_STRESS_THRESHOLD_US: int = 5_000
const SNAPSHOT_STRESS_THRESHOLD_US: int = 4_000
const VIEW_STRESS_THRESHOLD_US: int = 7_000
const FRAME_STRESS_THRESHOLD_US: int = 22_000
const VIEW_SCENE: PackedScene = preload(
	"res://scenes/habitat/act1_test_tube_habitat.tscn"
)

var _failed: bool = false
var _failure_message: String = ""


func _initialize() -> void:
	call_deferred(&"_run")


func _run() -> void:
	var soak_ticks: int = _read_tick_override()
	var frame_sample_count: int = _read_frame_sample_override()
	var simulation: ColonySimulation = Act1MaxScaleFixture.create_simulation()
	if simulation == null or not simulation.is_ready():
		_fail("max-scale fixture did not initialize")
		_finish()
		return
	var view: Act1TestTubeView = VIEW_SCENE.instantiate()
	root.add_child(view)
	if frame_sample_count > 0 and DisplayServer.get_name() != "headless":
		DisplayServer.window_set_size(Vector2i(1280, 720))
	var initial_snapshot: GameSnapshot = simulation.create_game_snapshot()
	if not view.apply_snapshot(initial_snapshot):
		_fail("max-scale view rejected the initial snapshot")
		_finish()
		return
	if view.get_ant_view_count() != Act1TestTubeView.MAX_VISIBLE_ANT_VIEWS:
		_fail(
			"max-scale view did not enforce the visible entity ceiling"
		)
		_finish()
		return
	var starting_tick: int = simulation._state.simulation_tick
	var starting_memory: int = OS.get_static_memory_usage()
	var peak_memory: int = starting_memory
	var memory_samples: PackedInt64Array = []
	var tick_durations_us: PackedInt64Array = []
	tick_durations_us.resize(soak_ticks)
	var snapshot_durations_us: Array[int] = []
	var view_durations_us: Array[int] = []
	var run_started_us: int = Time.get_ticks_usec()

	for index: int in soak_ticks:
		var tick_started_us: int = Time.get_ticks_usec()
		if not simulation.advance_tick(
			simulation._state.simulation_tick + 1
		):
			_fail("fixed Tick rejected at soak index %d" % index)
			break
		tick_durations_us[index] = Time.get_ticks_usec() - tick_started_us
		if (index + 1) % SNAPSHOT_SAMPLE_INTERVAL == 0:
			var snapshot_started_us: int = Time.get_ticks_usec()
			var snapshot: GameSnapshot = simulation.create_game_snapshot()
			snapshot_durations_us.append(
				Time.get_ticks_usec() - snapshot_started_us
			)
			var view_started_us: int = Time.get_ticks_usec()
			if not view.apply_snapshot(snapshot):
				_fail("view rejected checkpoint %d" % (index + 1))
				break
			view_durations_us.append(
				Time.get_ticks_usec() - view_started_us
			)
		if (index + 1) % CHECKPOINT_INTERVAL == 0:
			if not _checkpoint_is_valid(simulation):
				_fail("invalid authority at soak index %d" % (index + 1))
				break
			var current_memory: int = OS.get_static_memory_usage()
			memory_samples.append(current_memory)
			peak_memory = maxi(peak_memory, current_memory)

	if not _failed:
		if simulation._state.simulation_tick != starting_tick + soak_ticks:
			_fail("soak ended at the wrong fixed Tick")
		elif not _checkpoint_is_valid(simulation):
			_fail("final authority checkpoint is invalid")

	if not _failed:
		var final_snapshot: GameSnapshot = simulation.create_game_snapshot()
		var service := SaveGameService.new()
		var clock := SimulationClock.new()
		clock.restore_save_boundary(
			final_snapshot.simulation_tick,
			SimulationClock.VERY_FAST_SPEED,
			false
		)
		var envelope: Dictionary = service.create_envelope(
			simulation,
			clock,
			"r16_max_scale"
		)
		var save_bytes: int = (
			service.encode_envelope(envelope).to_utf8_buffer().size()
		)
		var elapsed_seconds: float = (
			float(Time.get_ticks_usec() - run_started_us) / 1_000_000.0
		)
		var final_memory: int = OS.get_static_memory_usage()
		print(
			(
				"R16_MAX_SCALE_SOAK_PASS ticks=%d start_tick=%d "
				+ "end_tick=%d elapsed_s=%.3f "
				+ "avg_tick_us=%.2f p95_tick_us=%d "
				+ "p99_tick_us=%d max_tick_us=%d tick_over_5000=%d "
				+ "avg_snapshot_us=%.2f p95_snapshot_us=%d "
				+ "max_snapshot_us=%d snapshot_over_4000=%d "
				+ "avg_view_us=%.2f p95_view_us=%d max_view_us=%d "
				+ "view_over_7000=%d "
				+ "memory_start_bytes=%d memory_peak_bytes=%d "
				+ "memory_final_bytes=%d memory_growth_bytes=%d "
				+ "memory_trend_slope_bytes_per_sample=%.2f "
				+ "save_bytes=%d workers=%d brood=%d facilities=%d "
				+ "zones=%d connections=%d food_sources=%d "
				+ "active_tasks=%d visible_ant_views=%d signature=%s"
			)
			% [
				soak_ticks,
				starting_tick,
				simulation._state.simulation_tick,
				elapsed_seconds,
				_average(tick_durations_us),
				_percentile(tick_durations_us, 0.95),
				_percentile(tick_durations_us, 0.99),
				_maximum(tick_durations_us),
				_count_over(
					tick_durations_us,
					TICK_STRESS_THRESHOLD_US
				),
				_average(snapshot_durations_us),
				_percentile(snapshot_durations_us, 0.95),
				_maximum(snapshot_durations_us),
				_count_over(
					snapshot_durations_us,
					SNAPSHOT_STRESS_THRESHOLD_US
				),
				_average(view_durations_us),
				_percentile(view_durations_us, 0.95),
				_maximum(view_durations_us),
				_count_over(
					view_durations_us,
					VIEW_STRESS_THRESHOLD_US
				),
				starting_memory,
				peak_memory,
				final_memory,
				final_memory - starting_memory,
				_linear_slope(memory_samples),
				save_bytes,
				_count_workers(final_snapshot),
				final_snapshot.colony.ants.size()
					- _count_workers(final_snapshot),
				final_snapshot.layout.facilities.size(),
				final_snapshot.colony.zones.size(),
				final_snapshot.layout.connections.size(),
				final_snapshot.colony.food_sources.size(),
				_count_active_tasks(final_snapshot),
				view.get_ant_view_count(),
				SimulationSnapshotSignature.game_snapshot_digest(
					final_snapshot
				),
			]
		)
		if (
			frame_sample_count > 0
			and DisplayServer.get_name() != "headless"
		):
			await _sample_render_frames(frame_sample_count)
	view.queue_free()
	_finish()


func _read_tick_override() -> int:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--ticks="):
			return maxi(
				1,
				int(argument.trim_prefix("--ticks="))
			)
	return DEFAULT_SOAK_TICKS


func _read_frame_sample_override() -> int:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--frame-samples="):
			return maxi(
				0,
				int(argument.trim_prefix("--frame-samples="))
			)
	return 0


func _sample_render_frames(sample_count: int) -> void:
	for unused: int in FRAME_SAMPLE_WARMUP:
		await process_frame
	var frame_durations_us: PackedInt64Array = []
	frame_durations_us.resize(sample_count)
	var previous_frame_us: int = Time.get_ticks_usec()
	for index: int in sample_count:
		await process_frame
		var current_frame_us: int = Time.get_ticks_usec()
		frame_durations_us[index] = current_frame_us - previous_frame_us
		previous_frame_us = current_frame_us
	print(
		(
			"R16_MAX_SCALE_FRAME_PASS samples=%d avg_frame_us=%.2f "
			+ "p95_frame_us=%d p99_frame_us=%d max_frame_us=%d "
			+ "frame_over_22000=%d "
			+ "window_width=%d window_height=%d"
		)
		% [
			sample_count,
			_average(frame_durations_us),
			_percentile(frame_durations_us, 0.95),
			_percentile(frame_durations_us, 0.99),
			_maximum(frame_durations_us),
			_count_over(
				frame_durations_us,
				FRAME_STRESS_THRESHOLD_US
			),
			DisplayServer.window_get_size().x,
			DisplayServer.window_get_size().y,
		]
	)


func _checkpoint_is_valid(simulation: ColonySimulation) -> bool:
	if (
		simulation == null
		or not simulation.is_ready()
		or not simulation.has_valid_habitat_ownership()
	):
		return false
	var snapshot: GameSnapshot = simulation.create_game_snapshot()
	if (
		snapshot == null
		or not snapshot.campaign.completed
		or not snapshot.act1.final_report_available
		or _count_workers(snapshot)
			!= Act1MaxScaleFixture.TARGET_WORKER_COUNT
		or snapshot.colony.ants.size() - _count_workers(snapshot)
			!= Act1MaxScaleFixture.TARGET_BROOD_COUNT
		or snapshot.layout.facilities.size()
			!= Act1MaxScaleFixture.TARGET_FACILITY_COUNT
		or snapshot.colony.zones.size()
			!= Act1MaxScaleFixture.TARGET_ZONE_COUNT
		or snapshot.layout.connections.size()
			!= Act1MaxScaleFixture.TARGET_CONNECTION_COUNT
		or snapshot.colony.food_sources.size()
			!= Act1MaxScaleFixture.TARGET_FOOD_SOURCE_COUNT
		or _count_active_tasks(snapshot)
			!= Act1MaxScaleFixture.TARGET_WORKER_COUNT
	):
		return false
	for zone: HabitatZoneSnapshot in snapshot.colony.zones:
		if (
			not is_finite(zone.humidity)
			or zone.humidity < 0.0
			or zone.humidity > 1.0
			or not is_finite(zone.light_exposure)
			or zone.light_exposure < 0.0
			or zone.light_exposure > 1.0
			or not is_finite(zone.pollution)
			or zone.pollution < 0.0
			or zone.pollution > 1.0
		):
			return false
	return true


func _count_workers(snapshot: GameSnapshot) -> int:
	var count: int = 0
	for ant: AntSnapshot in snapshot.colony.ants:
		if ant.life_stage == AntModel.LifeStage.WORKER:
			count += 1
	return count


func _count_active_tasks(snapshot: GameSnapshot) -> int:
	var count: int = 0
	for ant: AntSnapshot in snapshot.colony.ants:
		if (
			ant.life_stage == AntModel.LifeStage.WORKER
			and ant.worker_task_state != WorkerTaskModel.State.IDLE
		):
			count += 1
	return count


func _average(values: Variant) -> float:
	if values.size() == 0:
		return 0.0
	var total: float = 0.0
	for value: int in values:
		total += float(value)
	return total / float(values.size())


func _percentile(values: Variant, percentile: float) -> int:
	if values.size() == 0:
		return 0
	var sorted: Array[int] = []
	for value: int in values:
		sorted.append(value)
	sorted.sort()
	var index: int = clampi(
		int(ceil(float(sorted.size()) * percentile)) - 1,
		0,
		sorted.size() - 1
	)
	return sorted[index]


func _maximum(values: Variant) -> int:
	var result: int = 0
	for value: int in values:
		result = maxi(result, value)
	return result


func _count_over(values: Variant, threshold: int) -> int:
	var result: int = 0
	for value: int in values:
		if value > threshold:
			result += 1
	return result


func _linear_slope(values: PackedInt64Array) -> float:
	if values.size() < 2:
		return 0.0
	var count: float = float(values.size())
	var sum_x: float = 0.0
	var sum_y: float = 0.0
	var sum_xy: float = 0.0
	var sum_x_squared: float = 0.0
	for index: int in values.size():
		var x: float = float(index)
		var y: float = float(values[index])
		sum_x += x
		sum_y += y
		sum_xy += x * y
		sum_x_squared += x * x
	var denominator: float = count * sum_x_squared - sum_x * sum_x
	if is_zero_approx(denominator):
		return 0.0
	return (count * sum_xy - sum_x * sum_y) / denominator


func _fail(message: String) -> void:
	_failed = true
	_failure_message = message
	printerr("R16_MAX_SCALE_SOAK_FAIL %s" % message)


func _finish() -> void:
	quit(1 if _failed else 0)
