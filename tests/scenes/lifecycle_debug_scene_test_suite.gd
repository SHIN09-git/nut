class_name LifecycleDebugSceneTestSuite
extends RefCounted

const SPECIES_A_DATA: SpeciesData = preload("res://data/species/species_a.tres")
const LIFECYCLE_DEBUG_SCENE: PackedScene = preload(
	"res://scenes/debug/lifecycle_debug.tscn"
)

var _assertion_count: int = 0
var _failure_count: int = 0
var _scene_root: Node


func run(scene_root: Node) -> void:
	_scene_root = scene_root
	_test_scene_instantiates_with_clock_controls()
	_test_resource_derived_lifecycle_boundary()
	_test_debug_panel_toggle()
	_test_sixteen_x_keeps_resource_derived_boundary()
	_test_tick_desync_stops_the_scene()


func get_assertion_count() -> int:
	return _assertion_count


func get_failure_count() -> int:
	return _failure_count


func _test_scene_instantiates_with_clock_controls() -> void:
	var controller: Control = _create_controller()
	var clock: SimulationClock = _get_clock(controller)
	var simulation: ColonySimulation = _get_simulation(controller)
	var pause_button: Button = controller.get_node_or_null("%PauseButton") as Button
	var speed_1x_button: Button = controller.get_node_or_null("%Speed1xButton") as Button
	var speed_4x_button: Button = controller.get_node_or_null("%Speed4xButton") as Button
	var habitat: TestTubeHabitat = (
		controller.get_node_or_null("%TestTubeHabitat") as TestTubeHabitat
	)

	_expect_true(clock != null, "lifecycle debug scene creates a SimulationClock")
	_expect_true(simulation != null, "lifecycle debug scene creates a ColonySimulation")
	_expect_true(pause_button != null, "lifecycle debug scene exposes a pause control")
	_expect_true(speed_1x_button != null, "lifecycle debug scene exposes a 1x control")
	_expect_true(speed_4x_button != null, "lifecycle debug scene exposes a 4x control")
	_expect_true(habitat != null, "lifecycle debug scene contains its test-tube habitat")
	if (
		clock == null
		or simulation == null
		or pause_button == null
		or speed_1x_button == null
		or speed_4x_button == null
		or habitat == null
	):
		_destroy_controller(controller)
		return

	var view_adapter: ColonyViewAdapter = habitat.get_view_adapter()
	_expect_true(view_adapter != null, "lifecycle debug habitat exposes its view adapter")
	_expect_true(speed_1x_button.disabled, "lifecycle debug scene starts at 1x")

	controller.call("_process", SimulationClock.FIXED_STEP_SECONDS)
	_expect_int(clock.get_tick_index(), 1, "lifecycle debug scene advances one fixed Tick")
	_expect_int(
		simulation.create_snapshot().simulation_tick,
		clock.get_tick_index(),
		"lifecycle debug clock and simulation stay synchronized"
	)

	pause_button.pressed.emit()
	_expect_true(clock.is_paused(), "pause control pauses the lifecycle debug clock")
	if view_adapter != null:
		_expect_true(
			view_adapter.are_visuals_paused(),
			"pause control also pauses lifecycle presentation feedback"
		)
	var paused_signature: String = _snapshot_signature(simulation.create_snapshot())
	controller.call("_process", 1.0)
	_expect_string(
		_snapshot_signature(simulation.create_snapshot()),
		paused_signature,
		"paused lifecycle debug scene does not advance simulation state"
	)

	speed_4x_button.pressed.emit()
	_expect_int(clock.get_speed_multiplier(), 4, "4x control changes only the clock speed")
	pause_button.pressed.emit()
	_expect_true(not clock.is_paused(), "pause control resumes the lifecycle debug clock")
	controller.call("_process", 0.25)
	_expect_int(clock.get_tick_index(), 11, "resumed scene advances ten fixed Ticks at 4x")
	_expect_int(
		simulation.create_snapshot().simulation_tick,
		11,
		"resumed lifecycle simulation receives every fixed Tick"
	)

	_destroy_controller(controller)


func _test_resource_derived_lifecycle_boundary() -> void:
	var controller: Control = _create_controller()
	var clock: SimulationClock = _get_clock(controller)
	var simulation: ColonySimulation = _get_simulation(controller)
	var habitat: TestTubeHabitat = (
		controller.get_node_or_null("%TestTubeHabitat") as TestTubeHabitat
	)
	if clock == null or simulation == null or habitat == null:
		_record_failure(
			"lifecycle boundary fixture is complete",
			"clock, simulation, and habitat",
			"missing fixture node or runtime"
		)
		_destroy_controller(controller)
		return

	var first_egg_tick: int = SPECIES_A_DATA.first_egg_delay_ticks
	var adapter: ColonyViewAdapter = habitat.get_view_adapter()
	_advance_controller_to_tick(controller, clock, first_egg_tick - 1)
	var before_snapshot: ColonySnapshot = simulation.create_snapshot()
	_expect_int(
		before_snapshot.simulation_tick,
		first_egg_tick - 1,
		"lifecycle debug scene reaches the Resource-derived pre-laying boundary"
	)
	_expect_int(before_snapshot.ants.size(), 0, "no brood exists before the configured laying Tick")
	_expect_int(adapter.get_ant_view_count(), 0, "no brood view exists before the configured laying Tick")

	_advance_controller_to_tick(controller, clock, first_egg_tick)
	var laid_snapshot: ColonySnapshot = simulation.create_snapshot()
	_expect_int(laid_snapshot.simulation_tick, first_egg_tick, "scene reaches the configured laying Tick")
	_expect_int(laid_snapshot.ants.size(), 1, "the first brood appears on the configured laying Tick")
	var first_view: AntView = adapter.get_ant_view(1)
	_expect_true(first_view != null, "the configured first brood receives a stable view")
	if first_view != null:
		_expect_int(first_view.get_entity_id(), 1, "the first brood view keeps stable entity ID 1")
		_expect_int(
			first_view.get_life_stage(),
			AntModel.LifeStage.EGG,
			"the first brood view starts in the egg stage"
		)

	_destroy_controller(controller)


func _test_debug_panel_toggle() -> void:
	var controller: Control = _create_controller()
	var debug_panel: Control = controller.get_node_or_null("%DebugPanel") as Control
	var debug_toggle_button: Button = (
		controller.get_node_or_null("%DebugToggleButton") as Button
	)

	_expect_true(debug_panel != null, "lifecycle debug scene contains a diagnostic panel")
	_expect_true(debug_toggle_button != null, "lifecycle debug scene contains a diagnostic toggle")
	if debug_panel == null or debug_toggle_button == null:
		_destroy_controller(controller)
		return

	_expect_true(not debug_panel.visible, "lifecycle diagnostics start hidden")
	debug_toggle_button.pressed.emit()
	_expect_true(debug_panel.visible, "diagnostic toggle reveals the panel")
	debug_toggle_button.pressed.emit()
	_expect_true(not debug_panel.visible, "diagnostic toggle hides the panel again")

	_destroy_controller(controller)


func _test_sixteen_x_keeps_resource_derived_boundary() -> void:
	var controller: Control = _create_controller()
	var clock: SimulationClock = _get_clock(controller)
	var simulation: ColonySimulation = _get_simulation(controller)
	var speed_16x_button: Button = (
		controller.get_node_or_null("%Speed16xButton") as Button
	)
	var habitat: TestTubeHabitat = (
		controller.get_node_or_null("%TestTubeHabitat") as TestTubeHabitat
	)
	if clock == null or simulation == null or speed_16x_button == null or habitat == null:
		_record_failure(
			"16x lifecycle fixture is complete",
			"clock, simulation, speed control, and habitat",
			"missing fixture node or runtime"
		)
		_destroy_controller(controller)
		return

	speed_16x_button.pressed.emit()
	_expect_int(clock.get_speed_multiplier(), 16, "16x control selects the configured clock speed")
	var adapter: ColonyViewAdapter = habitat.get_view_adapter()
	var first_egg_tick: int = SPECIES_A_DATA.first_egg_delay_ticks
	var first_worker_tick: int = _get_first_worker_tick()

	_advance_controller_to_tick(controller, clock, first_egg_tick)
	var first_view: AntView = adapter.get_ant_view(1)
	_expect_true(first_view != null, "16x does not skip the configured first-egg boundary")

	_advance_controller_to_tick(controller, clock, first_worker_tick)
	_expect_int(
		simulation.create_snapshot().simulation_tick,
		first_worker_tick,
		"16x reaches the Resource-derived first-worker boundary exactly"
	)
	var worker_view: AntView = adapter.get_ant_view(1)
	_expect_true(worker_view != null, "entity 1 remains visible at its configured worker boundary")
	if first_view != null and worker_view != null:
		_expect_true(worker_view == first_view, "16x keeps entity 1's original view instance")
		_expect_int(
			worker_view.get_life_stage(),
			AntModel.LifeStage.WORKER,
			"16x delivers the configured worker transition"
		)
	_expect_true(
		adapter.get_ant_view_count() <= SPECIES_A_DATA.max_first_generation_brood,
		"16x never creates more views than the configured brood limit"
	)

	_destroy_controller(controller)


func _test_tick_desync_stops_the_scene() -> void:
	var controller: Control = _create_controller()
	var clock: SimulationClock = _get_clock(controller)
	var simulation: ColonySimulation = _get_simulation(controller)
	var pause_button: Button = controller.get_node_or_null("%PauseButton") as Button
	if clock == null or simulation == null or pause_button == null:
		_record_failure(
			"Tick desync fixture is complete",
			"clock, simulation, and pause control",
			"missing fixture node or runtime"
		)
		_destroy_controller(controller)
		return

	_expect_true(simulation.advance_tick(1), "fault injection advances simulation ahead of its clock")
	controller.call("_process", 10.0)
	_expect_true(clock.is_paused(), "a rejected Tick pauses the lifecycle debug clock")
	_expect_true(pause_button.disabled, "a rejected Tick disables the resume control")
	_expect_int(clock.get_tick_index(), 1, "Tick rejection stops the current clock batch")
	_expect_int(simulation.create_snapshot().simulation_tick, 1, "Tick rejection leaves simulation unchanged")
	controller.call("_process", 10.0)
	_expect_int(clock.get_tick_index(), 1, "fatal desynchronization prevents further clock progress")

	_destroy_controller(controller)


func _create_controller() -> Control:
	var controller: Control = LIFECYCLE_DEBUG_SCENE.instantiate() as Control
	_scene_root.add_child(controller)
	return controller


func _destroy_controller(controller: Control) -> void:
	_scene_root.remove_child(controller)
	controller.free()


func _get_clock(controller: Control) -> SimulationClock:
	return controller.get("_simulation_clock") as SimulationClock


func _get_simulation(controller: Control) -> ColonySimulation:
	return controller.get("_colony_simulation") as ColonySimulation


func _advance_controller_to_tick(
	controller: Control,
	clock: SimulationClock,
	target_tick: int
) -> void:
	while clock.get_tick_index() < target_tick:
		var previous_tick: int = clock.get_tick_index()
		var remaining_ticks: int = target_tick - previous_tick
		var frame_ticks: int = mini(remaining_ticks, clock.get_speed_multiplier())
		var real_delta: float = (
			float(frame_ticks)
			* SimulationClock.FIXED_STEP_SECONDS
			/ float(clock.get_speed_multiplier())
		)
		controller.call("_process", real_delta)
		if clock.get_tick_index() <= previous_tick:
			_record_failure(
				"lifecycle debug controller advances toward target Tick",
				"Tick greater than %d" % previous_tick,
				str(clock.get_tick_index())
			)
			return


func _get_first_worker_tick() -> int:
	return (
		SPECIES_A_DATA.first_egg_delay_ticks
		+ SPECIES_A_DATA.egg_duration_ticks
		+ SPECIES_A_DATA.larva_duration_ticks
		+ SPECIES_A_DATA.pupa_duration_ticks
	)


func _snapshot_signature(snapshot: ColonySnapshot) -> String:
	var parts: PackedStringArray = [str(snapshot.simulation_tick)]
	for ant: AntSnapshot in snapshot.ants:
		parts.append(
			"%d:%d:%d:%d"
			% [
				ant.entity_id,
				ant.life_stage,
				ant.total_age_ticks,
				ant.stage_age_ticks,
			]
		)
	return "|".join(parts)


func _expect_int(actual: int, expected: int, message: String) -> void:
	_assertion_count += 1
	if actual == expected:
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
	printerr("  %s - expected %s, got %s" % [message, expected, actual])
