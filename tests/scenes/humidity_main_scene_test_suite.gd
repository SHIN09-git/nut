class_name HumidityMainSceneTestSuite
extends RefCounted

const SPECIES_A_DATA: SpeciesData = preload("res://data/species/species_a.tres")
const HUMIDITY_SCENARIO_DATA: HabitatScenarioData = preload(
	"res://data/habitats/humidity_relocation_slice.tres"
)
const MAIN_SCENE: PackedScene = preload("res://scenes/main/main.tscn")
const LEFT_ZONE_ID: StringName = &"left_chamber"
const RIGHT_ZONE_ID: StringName = &"right_chamber"

var _assertion_count: int = 0
var _failure_count: int = 0
var _scene_root: Node


func run(scene_root: Node) -> void:
	_scene_root = scene_root
	_test_main_scene_instantiates_headless()
	_test_humidity_scene_lifecycle_fields_are_not_applicable()
	_test_water_button_queues_until_next_tick()
	_test_real_water_button_path_unlocks_observation()
	_test_controller_freezes_runtime_resources()
	_test_completed_session_can_restart_twice_from_frozen_config()
	_test_f3_toggles_debug_panel()
	_test_pause_stops_environment_and_behavior()
	_test_speed_multipliers_match_at_the_same_tick()
	_test_habitat_view_reuses_nodes_and_attaches_carried_brood()


func get_assertion_count() -> int:
	return _assertion_count


func get_failure_count() -> int:
	return _failure_count


func _test_main_scene_instantiates_headless() -> void:
	var controller: MainController = _create_controller()
	var habitat_view: HabitatView = controller.get_node_or_null("%HabitatView") as HabitatView
	var water_button: Button = controller.get_node_or_null("%WaterButton") as Button
	var completion_panel: Control = controller.get_node_or_null("%CompletionPanel") as Control
	var restart_button: Button = controller.get_node_or_null("%RestartButton") as Button
	var debug_panel: Control = controller.get_node_or_null("%DebugPanel") as Control
	var pause_button: Button = controller.get_node_or_null("%PauseButton") as Button
	var speed_1x_button: Button = controller.get_node_or_null("%Speed1xButton") as Button
	var speed_4x_button: Button = controller.get_node_or_null("%Speed4xButton") as Button
	var speed_16x_button: Button = controller.get_node_or_null("%Speed16xButton") as Button

	_expect_true(habitat_view != null, "main scene contains a HabitatView")
	_expect_true(water_button != null, "main scene contains its humidity command control")
	_expect_true(completion_panel != null, "main scene contains an explicit completion state")
	_expect_true(restart_button != null, "main scene contains a restart control")
	_expect_true(debug_panel != null, "main scene contains its F3 diagnostic layer")
	_expect_true(pause_button != null, "main scene contains a pause control")
	_expect_true(speed_1x_button != null, "main scene contains a 1x control")
	_expect_true(speed_4x_button != null, "main scene contains a 4x control")
	_expect_true(speed_16x_button != null, "main scene contains a 16x control")
	_expect_true(controller._simulation_clock != null, "main scene creates its fixed simulation clock")
	_expect_true(controller._colony_simulation != null, "main scene creates its colony simulation")
	_expect_true(controller._latest_snapshot != null, "main scene publishes an initial snapshot")
	if controller._latest_snapshot != null:
		_expect_int(controller._latest_snapshot.simulation_tick, 0, "initial main snapshot starts at Tick zero")
		_expect_int(controller._latest_snapshot.zones.size(), 2, "initial main snapshot contains both zones")
		_expect_true(
			not controller._latest_snapshot.lifecycle_active,
			"humidity main scene identifies lifecycle counters as not applicable"
		)
		_expect_true(
			not controller._latest_snapshot.water_action_unlocked,
			"water action starts behind the authoritative observation gate"
		)
		_expect_true(
			not controller._latest_snapshot.water_action_available,
			"water action snapshot starts unavailable"
		)
		_expect_true(
			not controller._latest_snapshot.water_action_pending,
			"water action snapshot starts without queued input"
		)
		_expect_int(
			controller._latest_snapshot.ants.size(),
			HUMIDITY_SCENARIO_DATA.initial_worker_count
			+ HUMIDITY_SCENARIO_DATA.initial_brood_count,
			"initial main snapshot contains the configured workers and brood"
		)
	if habitat_view != null:
		_expect_int(
			habitat_view.get_ant_view_count(),
			HUMIDITY_SCENARIO_DATA.initial_worker_count
			+ HUMIDITY_SCENARIO_DATA.initial_brood_count,
			"HabitatView maps every configured ant entity"
		)
	if water_button != null:
		_expect_true(water_button.disabled, "water command starts locked during observation")
	if completion_panel != null:
		_expect_true(not completion_panel.visible, "completion state starts hidden")
	if restart_button != null:
		_expect_true(not restart_button.is_visible_in_tree(), "restart control starts hidden")
	if debug_panel != null:
		_expect_true(not debug_panel.visible, "F3 diagnostic layer starts hidden")
	if speed_1x_button != null:
		_expect_true(speed_1x_button.disabled, "main scene starts at 1x")

	_destroy_controller(controller)


func _test_humidity_scene_lifecycle_fields_are_not_applicable() -> void:
	var controller: MainController = _create_controller()
	var snapshot: ColonySnapshot = controller._latest_snapshot
	_expect_true(not snapshot.lifecycle_active, "humidity scenario disables lifecycle production")
	_expect_int(snapshot.queen_laid_egg_count, 0, "humidity scenario exposes no laid-egg count")
	_expect_int(snapshot.max_first_generation_brood, 0, "humidity scenario exposes no lifecycle brood cap")
	_expect_int(snapshot.next_egg_tick, -1, "humidity scenario exposes no next egg Tick")
	_destroy_controller(controller)


func _test_water_button_queues_until_next_tick() -> void:
	var controller: MainController = _create_controller()
	var water_button: Button = controller.get_node_or_null("%WaterButton") as Button
	if water_button == null:
		_record_failure("water command fixture is complete", "WaterButton", "missing")
		_destroy_controller(controller)
		return

	_expect_true(water_button.disabled, "water command remains locked before the first relocation lands")
	var landed_tick: int = _advance_until_water_available(controller, _get_first_drop_deadline())
	_expect_true(landed_tick >= 0, "water command unlocks after a brood relocation lands")
	_expect_true(not water_button.disabled, "water command is enabled after the first relocation lands")
	if landed_tick < 0:
		_destroy_controller(controller)
		return

	var before_snapshot: ColonySnapshot = controller._colony_simulation.create_snapshot()
	var before_zone: HabitatZoneSnapshot = before_snapshot.find_zone(
		HUMIDITY_SCENARIO_DATA.humidity_adjustment_zone_id
	)
	_expect_true(before_zone != null, "water command target zone exists in the snapshot")
	if before_zone == null:
		_destroy_controller(controller)
		return

	var before_humidity: float = before_zone.humidity
	var before_action_count: int = before_snapshot.water_action_count
	water_button.pressed.emit()
	var queued_snapshot: ColonySnapshot = controller._latest_snapshot
	var queued_zone: HabitatZoneSnapshot = queued_snapshot.find_zone(
		HUMIDITY_SCENARIO_DATA.humidity_adjustment_zone_id
	)
	_expect_true(water_button.disabled, "water command disables while its queued input is pending")
	_expect_true(queued_snapshot.water_action_pending, "button click publishes the authoritative pending state")
	_expect_int(
		queued_snapshot.simulation_tick,
		before_snapshot.simulation_tick,
		"submitting a water command does not advance simulation time"
	)
	_expect_float(
		queued_zone.humidity,
		before_humidity,
		"submitting a water command does not mutate humidity immediately"
	)
	_expect_int(
		queued_snapshot.water_action_count,
		before_action_count,
		"submitting a water command does not count as an applied adjustment"
	)

	controller._process(SimulationClock.FIXED_STEP_SECONDS)
	var applied_snapshot: ColonySnapshot = controller._latest_snapshot
	var applied_zone: HabitatZoneSnapshot = applied_snapshot.find_zone(
		HUMIDITY_SCENARIO_DATA.humidity_adjustment_zone_id
	)
	_expect_int(
		applied_snapshot.simulation_tick,
		before_snapshot.simulation_tick + 1,
		"the next fixed Tick applies the queued water command"
	)
	_expect_float(
		applied_zone.humidity,
		clampf(
			before_humidity + HUMIDITY_SCENARIO_DATA.humidity_adjustment_amount,
			0.0,
			1.0
		),
		"the next fixed Tick changes humidity by the configured amount"
	)
	_expect_int(
		applied_snapshot.water_action_count,
		before_action_count + 1,
		"the next fixed Tick records exactly one applied humidity command"
	)
	_expect_true(not applied_snapshot.water_action_pending, "applied water command clears pending state")

	_destroy_controller(controller)


func _test_real_water_button_path_unlocks_observation() -> void:
	var controller: MainController = _create_controller()
	var water_button: Button = controller.get_node_or_null("%WaterButton") as Button
	if water_button == null:
		_record_failure("real player path fixture is complete", "WaterButton", "missing")
		_destroy_controller(controller)
		return

	var first_drop_tick: int = _advance_until_water_available(
		controller,
		_get_first_drop_deadline()
	)
	_expect_true(first_drop_tick >= 0, "first completed relocation unlocks the real water control")
	if first_drop_tick < 0:
		_destroy_controller(controller)
		return
	var first_drop_snapshot: ColonySnapshot = controller._latest_snapshot
	_expect_true(
		first_drop_snapshot.water_action_unlocked,
		"first landing is retained by authoritative simulation state"
	)
	_expect_true(
		_count_brood_in_zone(
			first_drop_snapshot,
			HUMIDITY_SCENARIO_DATA.initial_brood_zone_id
		) > 0,
		"water opens while brood still remains in the starting chamber"
	)

	var expected_action_count: int = _get_commands_to_reach_comfort()
	var submitted_actions: int = 0
	while (
		not controller._latest_snapshot.water_target_comfortable
		and submitted_actions < expected_action_count + 2
	):
		_expect_true(not water_button.disabled, "each required water action uses the enabled UI button")
		if water_button.disabled:
			break
		var before_snapshot: ColonySnapshot = controller._latest_snapshot
		water_button.pressed.emit()
		var pending_snapshot: ColonySnapshot = controller._latest_snapshot
		_expect_true(pending_snapshot.water_action_pending, "button path queues one high-level water action")
		_expect_int(
			pending_snapshot.water_action_count,
			before_snapshot.water_action_count,
			"queued UI action remains unapplied during its submission Tick"
		)
		controller._process(SimulationClock.FIXED_STEP_SECONDS)
		_expect_int(
			controller._latest_snapshot.simulation_tick,
			before_snapshot.simulation_tick + 1,
			"each UI water action applies at the start of the next fixed Tick"
		)
		_expect_int(
			controller._latest_snapshot.water_action_count,
			before_snapshot.water_action_count + 1,
			"each UI click applies exactly one frozen water action"
		)
		submitted_actions += 1

	_expect_int(submitted_actions, expected_action_count, "player needs only the configured small set of water actions")
	_expect_true(controller._latest_snapshot.water_target_comfortable, "real UI path makes the water target comfortable")
	_expect_true(water_button.disabled, "water control closes once its target is comfortable")

	var reevaluation_seen: bool = false
	var completion_deadline: int = (
		controller._latest_snapshot.simulation_tick
		+ SPECIES_A_DATA.minimum_zone_dwell_ticks
		+ SPECIES_A_DATA.decision_interval_ticks * 6
		+ (
			SPECIES_A_DATA.travel_duration_ticks * 2
			+ SPECIES_A_DATA.pickup_duration_ticks
			+ SPECIES_A_DATA.drop_duration_ticks
		) * HUMIDITY_SCENARIO_DATA.initial_brood_count
		+ HUMIDITY_SCENARIO_DATA.observation_stable_ticks
		+ 100
	)
	while (
		not controller._latest_snapshot.brood_humidity_observation_unlocked
		and controller._latest_snapshot.simulation_tick < completion_deadline
	):
		controller._process(SimulationClock.FIXED_STEP_SECONDS)
		for ant: AntSnapshot in controller._latest_snapshot.ants:
			if (
				ant.life_stage == AntModel.LifeStage.WORKER
				and ant.worker_task_state != WorkerTaskModel.State.IDLE
				and ant.target_zone_id
					== HUMIDITY_SCENARIO_DATA.humidity_adjustment_zone_id
			):
				reevaluation_seen = true

	_expect_true(reevaluation_seen, "workers visibly reevaluate toward the watered chamber")
	_expect_true(
		controller._latest_snapshot.brood_humidity_observation_unlocked,
		"the real button path reaches the observation unlock"
	)
	_expect_int(
		controller._latest_snapshot.count_active_relocations(),
		0,
		"observation unlock occurs only after relocation work settles"
	)
	_destroy_controller(controller)


func _test_controller_freezes_runtime_resources() -> void:
	var species_source: SpeciesData = SPECIES_A_DATA.duplicate(true) as SpeciesData
	var scenario_source: HabitatScenarioData = _duplicate_scenario_data()
	var original_target_zone_id: StringName = scenario_source.humidity_adjustment_zone_id
	var alternate_zone_id: StringName = (
		RIGHT_ZONE_ID
		if RIGHT_ZONE_ID != original_target_zone_id
		else LEFT_ZONE_ID
	)
	var original_amount: float = scenario_source.humidity_adjustment_amount
	var expected_action_count: int = _get_commands_to_reach_comfort_from_data(
		species_source,
		scenario_source
	)
	var controller: MainController = _create_controller(species_source, scenario_source)
	var water_button: Button = controller.get_node_or_null("%WaterButton") as Button
	var unlocked_tick: int = _advance_until_water_available(
		controller,
		_get_first_drop_deadline()
	)
	_expect_true(unlocked_tick >= 0, "freeze fixture reaches authoritative water availability")
	if water_button == null or unlocked_tick < 0:
		_destroy_controller(controller)
		return

	var before_mutation_snapshot: ColonySnapshot = controller._latest_snapshot
	var before_target: HabitatZoneSnapshot = before_mutation_snapshot.find_zone(
		original_target_zone_id
	)
	var before_alternate: HabitatZoneSnapshot = before_mutation_snapshot.find_zone(
		alternate_zone_id
	)
	_expect_true(before_target != null, "frozen-config water target exists")
	_expect_true(before_alternate != null, "frozen-config alternate zone exists")
	if before_target == null or before_alternate == null:
		_destroy_controller(controller)
		return
	scenario_source.humidity_adjustment_zone_id = alternate_zone_id
	scenario_source.humidity_adjustment_amount = 0.37
	species_source.brood_humidity_min = 0.90
	species_source.brood_humidity_max = 0.95
	controller._update_control_state()
	controller._update_player_guidance()
	_expect_true(not water_button.disabled, "mutating source Resources does not change UI availability")

	water_button.pressed.emit()
	_expect_true(controller._latest_snapshot.water_action_pending, "frozen-config UI action is accepted")
	controller._process(SimulationClock.FIXED_STEP_SECONDS)
	var applied_snapshot: ColonySnapshot = controller._latest_snapshot
	var applied_target: HabitatZoneSnapshot = applied_snapshot.find_zone(
		original_target_zone_id
	)
	var applied_alternate: HabitatZoneSnapshot = applied_snapshot.find_zone(
		alternate_zone_id
	)
	_expect_true(applied_target != null, "original frozen water target remains present")
	_expect_true(applied_alternate != null, "alternate zone remains present")
	if applied_target == null or applied_alternate == null:
		_destroy_controller(controller)
		return
	_expect_float(
		applied_target.humidity,
		clampf(before_target.humidity + original_amount, 0.0, 1.0),
		"simulation keeps the frozen water amount and original target"
	)
	_expect_float(
		applied_alternate.humidity,
		before_alternate.humidity,
		"mutated source target does not receive the water action"
	)

	while controller._latest_snapshot.water_action_count < expected_action_count:
		_expect_true(not water_button.disabled, "frozen comfort range keeps required UI actions available")
		if water_button.disabled:
			break
		water_button.pressed.emit()
		controller._process(SimulationClock.FIXED_STEP_SECONDS)
	_expect_int(
		controller._latest_snapshot.water_action_count,
		expected_action_count,
		"frozen scenario applies the original number of water actions"
	)
	_expect_true(
		controller._latest_snapshot.water_target_comfortable,
		"comfort result uses the frozen species range"
	)
	_expect_true(water_button.disabled, "UI follows frozen comfortable state after source mutation")
	_destroy_controller(controller)


func _test_completed_session_can_restart_twice_from_frozen_config() -> void:
	var species_source: SpeciesData = SPECIES_A_DATA.duplicate(true) as SpeciesData
	var scenario_source: HabitatScenarioData = _duplicate_scenario_data()
	var original_left_zone_id: StringName = LEFT_ZONE_ID
	var original_right_zone_id: StringName = RIGHT_ZONE_ID
	var original_target_zone_id: StringName = scenario_source.humidity_adjustment_zone_id
	var original_left_humidity: float = _find_zone_data(
		scenario_source,
		original_left_zone_id
	).initial_humidity
	var original_right_humidity: float = _find_zone_data(
		scenario_source,
		original_right_zone_id
	).initial_humidity
	var original_water_amount: float = scenario_source.humidity_adjustment_amount
	var expected_entity_count: int = (
		scenario_source.initial_worker_count
		+ scenario_source.initial_brood_count
	)
	var expected_action_count: int = _get_commands_to_reach_comfort_from_data(
		species_source,
		scenario_source
	)
	var controller: MainController = _create_controller(
		species_source,
		scenario_source
	)
	var habitat_view: HabitatView = controller.get_node_or_null(
		"%HabitatView"
	) as HabitatView
	var water_controls: Control = controller.get_node_or_null(
		"%WaterControls"
	) as Control
	var water_button: Button = controller.get_node_or_null("%WaterButton") as Button
	var completion_panel: Control = controller.get_node_or_null(
		"%CompletionPanel"
	) as Control
	var restart_button: Button = controller.get_node_or_null(
		"%RestartButton"
	) as Button
	var debug_panel: Control = controller.get_node_or_null("%DebugPanel") as Control
	var debug_toggle_button: Button = controller.get_node_or_null(
		"%DebugToggleButton"
	) as Button
	var pause_button: Button = controller.get_node_or_null("%PauseButton") as Button
	var speed_16x_button: Button = controller.get_node_or_null(
		"%Speed16xButton"
	) as Button
	if (
		habitat_view == null
		or water_controls == null
		or water_button == null
		or completion_panel == null
		or restart_button == null
		or debug_panel == null
		or debug_toggle_button == null
		or pause_button == null
		or speed_16x_button == null
	):
		_record_failure(
			"restart fixture is complete",
			"all session controls",
			"one or more controls missing"
		)
		_destroy_controller(controller)
		return

	var stable_clock: SimulationClock = controller._simulation_clock
	var stable_simulation: ColonySimulation = controller._colony_simulation

	# Mutate every source value that would materially expose a restart that
	# rereads Resources instead of reusing the simulation's frozen configs.
	scenario_source.initial_worker_count = 1
	scenario_source.initial_brood_count = 1
	scenario_source.humidity_adjustment_zone_id = (
		original_right_zone_id
		if original_target_zone_id != original_right_zone_id
		else original_left_zone_id
	)
	scenario_source.humidity_adjustment_amount = 0.37
	scenario_source.observation_stable_ticks = 1
	_find_zone_data(
		scenario_source,
		original_left_zone_id
	).initial_humidity = 0.88
	_find_zone_data(
		scenario_source,
		original_right_zone_id
	).initial_humidity = 0.12
	species_source.brood_humidity_min = 0.90
	species_source.brood_humidity_max = 0.95

	for restart_index: int in range(2):
		_expect_true(
			_complete_session_through_player_controls(controller),
			"session %d completes through visible player controls" % (restart_index + 1)
		)
		_expect_true(
			controller._latest_snapshot.brood_humidity_observation_unlocked,
			"completed session exposes the observation result"
		)
		_expect_int(
			controller._latest_snapshot.water_action_count,
			expected_action_count,
			"completed session keeps the frozen water-action semantics"
		)
		_expect_true(completion_panel.visible, "completed session shows an explicit completion state")
		_expect_true(
			restart_button.is_visible_in_tree(),
			"completed session exposes the restart control"
		)
		_expect_true(not water_controls.visible, "completed session replaces the water controls")
		_expect_true(not restart_button.disabled, "restart remains available after completion")

		var old_first_ant_id: int = controller._latest_snapshot.ants[0].entity_id
		var old_first_ant_view: AntView = habitat_view.get_ant_view(old_first_ant_id)
		speed_16x_button.pressed.emit()
		debug_toggle_button.pressed.emit()
		pause_button.pressed.emit()
		_expect_int(
			controller._simulation_clock.get_speed_multiplier(),
			SimulationClock.VERY_FAST_SPEED,
			"restart fixture first leaves the clock at a non-default speed"
		)
		_expect_true(controller._simulation_clock.is_paused(), "restart fixture first pauses the clock")
		_expect_true(debug_panel.visible, "restart fixture first opens the diagnostic layer")

		restart_button.pressed.emit()
		_expect_true(
			controller._simulation_clock == stable_clock,
			"restart resets the existing clock so its signal is connected only once"
		)
		_expect_true(
			controller._colony_simulation == stable_simulation,
			"restart reinitializes the simulation from its frozen configs"
		)
		_expect_int(
			controller._simulation_clock.get_tick_index(),
			0,
			"restart returns the fixed clock to Tick zero"
		)
		_expect_int(
			controller._simulation_clock.get_speed_multiplier(),
			SimulationClock.NORMAL_SPEED,
			"restart restores 1x speed"
		)
		_expect_true(
			not controller._simulation_clock.is_paused(),
			"restart resumes the new observation session"
		)
		_expect_true(not debug_panel.visible, "restart hides the F3 diagnostic layer")
		_expect_true(not completion_panel.visible, "restart clears the prior completion state")
		_expect_true(water_controls.visible, "restart restores the initial water-tool area")
		_expect_true(
			not restart_button.is_visible_in_tree(),
			"restart control hides until the next completed observation"
		)
		_expect_true(water_button.disabled, "restart locks water until the first new relocation")

		var reset_snapshot: ColonySnapshot = controller._latest_snapshot
		_expect_int(reset_snapshot.simulation_tick, 0, "reset snapshot starts at Tick zero")
		_expect_true(
			not reset_snapshot.water_action_unlocked,
			"reset snapshot clears the first-relocation gate"
		)
		_expect_true(
			not reset_snapshot.water_action_pending,
			"reset snapshot contains no command from the previous session"
		)
		_expect_int(reset_snapshot.water_action_count, 0, "reset snapshot clears water-action count")
		_expect_true(
			not reset_snapshot.brood_humidity_observation_unlocked,
			"reset snapshot clears the observation unlock"
		)
		_expect_int(
			reset_snapshot.ants.size(),
			expected_entity_count,
			"restart keeps the frozen initial entity counts"
		)
		_expect_int(
			habitat_view.get_ant_view_count(),
			expected_entity_count,
			"restart projects exactly one view per frozen initial entity"
		)
		var reset_left_zone: HabitatZoneSnapshot = reset_snapshot.find_zone(
			original_left_zone_id
		)
		var reset_right_zone: HabitatZoneSnapshot = reset_snapshot.find_zone(
			original_right_zone_id
		)
		_expect_true(reset_left_zone != null, "restart keeps the frozen left-zone ID")
		_expect_true(reset_right_zone != null, "restart keeps the frozen right-zone ID")
		if reset_left_zone != null:
			_expect_float(
				reset_left_zone.humidity,
				original_left_humidity,
				"restart keeps the frozen left-zone humidity"
			)
		if reset_right_zone != null:
			_expect_float(
				reset_right_zone.humidity,
				original_right_humidity,
				"restart keeps the frozen right-zone humidity"
			)
		var reset_first_ant_view: AntView = habitat_view.get_ant_view(old_first_ant_id)
		_expect_true(
			reset_first_ant_view != null,
			"restart rebuilds the stable entity ID projection"
		)
		_expect_true(
			reset_first_ant_view != old_first_ant_view,
			"restart leaves no visual node from the completed session"
		)

	# The third fresh session confirms a single button press still queues and
	# applies exactly one action with the original frozen target and amount.
	var unlocked_tick: int = _advance_until_water_available(
		controller,
		_get_first_drop_deadline()
	)
	_expect_true(unlocked_tick >= 0, "twice-restarted session opens its water control")
	if unlocked_tick >= 0:
		var before_zone: HabitatZoneSnapshot = controller._latest_snapshot.find_zone(
			original_target_zone_id
		)
		_expect_true(before_zone != null, "twice-restarted session keeps the frozen water target")
		if before_zone != null:
			var before_humidity: float = before_zone.humidity
			water_button.pressed.emit()
			_expect_true(
				controller._latest_snapshot.water_action_pending,
				"one click after two restarts queues one command"
			)
			controller._process(SimulationClock.FIXED_STEP_SECONDS)
			var applied_zone: HabitatZoneSnapshot = controller._latest_snapshot.find_zone(
				original_target_zone_id
			)
			_expect_int(
				controller._latest_snapshot.water_action_count,
				1,
				"one click after two restarts applies exactly one command"
			)
			if applied_zone != null:
				_expect_float(
					applied_zone.humidity,
					clampf(before_humidity + original_water_amount, 0.0, 1.0),
					"restart keeps the original frozen water amount and target"
				)

	_destroy_controller(controller)


func _test_f3_toggles_debug_panel() -> void:
	var controller: MainController = _create_controller()
	var debug_panel: Control = controller.get_node_or_null("%DebugPanel") as Control
	if debug_panel == null:
		_record_failure("F3 fixture is complete", "DebugPanel", "missing")
		_destroy_controller(controller)
		return

	_expect_true(not debug_panel.visible, "diagnostic layer starts hidden")
	var f3_event: InputEventKey = InputEventKey.new()
	f3_event.keycode = KEY_F3
	f3_event.pressed = true
	controller._input(f3_event)
	_expect_true(debug_panel.visible, "F3 reveals the diagnostic layer")

	var echo_event: InputEventKey = InputEventKey.new()
	echo_event.keycode = KEY_F3
	echo_event.pressed = true
	echo_event.echo = true
	controller._input(echo_event)
	_expect_true(debug_panel.visible, "an F3 key-repeat does not retrigger the diagnostic layer")

	controller._input(f3_event)
	_expect_true(not debug_panel.visible, "a second F3 press hides the diagnostic layer")

	_destroy_controller(controller)


func _test_pause_stops_environment_and_behavior() -> void:
	var controller: MainController = _create_controller()
	var pause_button: Button = controller.get_node_or_null("%PauseButton") as Button
	var habitat_view: HabitatView = controller.get_node_or_null("%HabitatView") as HabitatView
	if pause_button == null:
		_record_failure("pause fixture is complete", "PauseButton", "missing")
		_destroy_controller(controller)
		return

	_advance_controller_to_tick(controller, SPECIES_A_DATA.decision_interval_ticks)
	_expect_true(
		controller._latest_snapshot.count_active_relocations() > 0,
		"pause fixture reaches active worker behavior"
	)
	controller._process(SimulationClock.FIXED_STEP_SECONDS)
	controller._process(SimulationClock.FIXED_STEP_SECONDS * 0.5)
	var active_worker: AntSnapshot = _find_active_worker(controller._latest_snapshot)
	var active_worker_view: AntView = (
		habitat_view.get_ant_view(active_worker.entity_id)
		if habitat_view != null and active_worker != null
		else null
	)
	var paused_visual_position: Vector2 = (
		active_worker_view.position if active_worker_view != null else Vector2.ZERO
	)
	var paused_signature: String = _snapshot_signature(
		controller._colony_simulation.create_snapshot()
	)
	var paused_tick: int = controller._simulation_clock.get_tick_index()
	pause_button.pressed.emit()
	_expect_true(controller._simulation_clock.is_paused(), "pause control pauses the fixed clock")
	controller._process(10.0)
	_expect_int(
		controller._simulation_clock.get_tick_index(),
		paused_tick,
		"paused main scene does not advance Tick"
	)
	_expect_string(
		_snapshot_signature(controller._colony_simulation.create_snapshot()),
		paused_signature,
		"paused main scene changes neither environment nor worker behavior"
	)
	_expect_true(active_worker_view != null, "pause fixture identifies a moving worker view")
	if active_worker_view != null:
		_expect_vector2(
			active_worker_view.position,
			paused_visual_position,
			"paused main scene freezes render interpolation"
		)

	pause_button.pressed.emit()
	_expect_true(not controller._simulation_clock.is_paused(), "pause control resumes the fixed clock")
	controller._process(SimulationClock.FIXED_STEP_SECONDS)
	_expect_int(
		controller._simulation_clock.get_tick_index(),
		paused_tick + 1,
		"resumed main scene continues at the next fixed Tick"
	)
	_expect_true(
		_snapshot_signature(controller._latest_snapshot) != paused_signature,
		"resumed worker behavior advances again"
	)

	_destroy_controller(controller)


func _test_speed_multipliers_match_at_the_same_tick() -> void:
	var signatures: PackedStringArray = []
	var speeds: Array[int] = [
		SimulationClock.NORMAL_SPEED,
		SimulationClock.FAST_SPEED,
		SimulationClock.VERY_FAST_SPEED,
	]
	var first_command_tick: int = _get_aligned_first_command_tick()
	var command_count: int = _get_commands_to_reach_comfort()
	var command_spacing_ticks: int = SimulationClock.VERY_FAST_SPEED
	var target_tick: int = (
		first_command_tick
		+ command_count * command_spacing_ticks
		+ command_spacing_ticks
	)

	for speed: int in speeds:
		var controller: MainController = _create_controller()
		var water_button: Button = controller.get_node_or_null("%WaterButton") as Button
		var speed_button: Button = _get_speed_button(controller, speed)
		if speed_button != null and speed != SimulationClock.NORMAL_SPEED:
			speed_button.pressed.emit()
		_expect_int(
			controller._simulation_clock.get_speed_multiplier(),
			speed,
			"main clock accepts each supported speed"
		)

		var command_index: int = 0
		while command_index < command_count:
			var command_tick: int = (
				first_command_tick + command_index * command_spacing_ticks
			)
			_advance_controller_to_tick(controller, command_tick)
			_expect_true(
				water_button != null and not water_button.disabled,
				"the same Tick command schedule is available at every speed"
			)
			if water_button != null and not water_button.disabled:
				water_button.pressed.emit()
			command_index += 1

		_advance_controller_to_tick(controller, target_tick)
		_expect_int(
			controller._latest_snapshot.simulation_tick,
			target_tick,
			"each speed reaches the same exact simulation Tick"
		)
		signatures.append(_snapshot_signature(controller._latest_snapshot))
		_destroy_controller(controller)

	_expect_string(signatures[1], signatures[0], "4x produces the same humidity snapshot as 1x")
	_expect_string(signatures[2], signatures[0], "16x produces the same humidity snapshot as 1x")


func _test_habitat_view_reuses_nodes_and_attaches_carried_brood() -> void:
	var controller: MainController = _create_controller()
	var habitat_view: HabitatView = controller.get_node_or_null("%HabitatView") as HabitatView
	if habitat_view == null:
		_record_failure("HabitatView fixture is complete", "HabitatView", "missing")
		_destroy_controller(controller)
		return

	var initial_snapshot: ColonySnapshot = controller._latest_snapshot
	var initial_views: Dictionary[int, AntView] = {}
	for ant: AntSnapshot in initial_snapshot.ants:
		var ant_view: AntView = habitat_view.get_ant_view(ant.entity_id)
		_expect_true(ant_view != null, "each initial entity has one stable habitat view")
		if ant_view != null:
			initial_views[ant.entity_id] = ant_view
	_expect_true(habitat_view.apply_snapshot(initial_snapshot), "HabitatView accepts an identical snapshot")
	_expect_int(
		habitat_view.get_ant_view_count(),
		initial_snapshot.ants.size(),
		"reapplying a habitat snapshot creates no duplicate views"
	)
	for entity_id: int in initial_views:
		_expect_true(
			habitat_view.get_ant_view(entity_id) == initial_views[entity_id],
			"reapplying a habitat snapshot preserves each entity view"
		)

	var carrying_snapshot: ColonySnapshot = _advance_until_carrying(
		controller,
		_get_first_drop_deadline()
	)
	_expect_true(carrying_snapshot != null, "worker behavior reaches a visible carrying state")
	if carrying_snapshot == null:
		_destroy_controller(controller)
		return
	var carried_brood: AntSnapshot = _find_carried_brood(carrying_snapshot)
	_expect_true(carried_brood != null, "carrying snapshot identifies the carried brood")
	if carried_brood == null:
		_destroy_controller(controller)
		return
	var carrier: AntSnapshot = carrying_snapshot.find_ant(carried_brood.carrier_ant_id)
	var brood_view: AntView = habitat_view.get_ant_view(carried_brood.entity_id)
	var worker_view: AntView = habitat_view.get_ant_view(carried_brood.carrier_ant_id)
	_expect_true(carrier != null, "carrying snapshot identifies exactly one carrier")
	_expect_true(brood_view != null, "carried brood remains present in HabitatView")
	_expect_true(worker_view != null, "carrier remains present in HabitatView")
	if carrier == null or brood_view == null or worker_view == null:
		_destroy_controller(controller)
		return

	# Advance once to make both interpolation endpoints part of the carrying
	# state, then sample halfway between them without advancing another Tick.
	controller._process(SimulationClock.FIXED_STEP_SECONDS)
	var next_carried_brood: AntSnapshot = controller._latest_snapshot.find_ant(
		carried_brood.entity_id
	)
	_expect_int(
		next_carried_brood.carrier_ant_id,
		carrier.entity_id,
		"carried brood keeps the same carrier during the next travel Tick"
	)
	var interpolation_tick: int = controller._latest_snapshot.simulation_tick
	var initial_worker_position: Vector2 = worker_view.position
	var initial_brood_position: Vector2 = brood_view.position
	var initial_carry_offset: Vector2 = initial_brood_position - initial_worker_position
	controller._process(SimulationClock.FIXED_STEP_SECONDS * 0.5)
	_expect_int(
		controller._latest_snapshot.simulation_tick,
		interpolation_tick,
		"render interpolation does not advance simulation state"
	)
	_expect_true(
		not worker_view.position.is_equal_approx(initial_worker_position),
		"carrier advances smoothly between fixed Tick endpoints"
	)
	_expect_true(
		not brood_view.position.is_equal_approx(initial_brood_position),
		"carried brood advances smoothly with its carrier"
	)
	_expect_vector2(
		brood_view.position - worker_view.position,
		initial_carry_offset,
		"carried brood preserves its visual attachment offset"
	)

	_destroy_controller(controller)


func _complete_session_through_player_controls(
	controller: MainController
) -> bool:
	var water_button: Button = controller.get_node_or_null("%WaterButton") as Button
	if water_button == null:
		return false
	if _advance_until_water_available(controller, _get_first_drop_deadline()) < 0:
		return false

	var maximum_action_count: int = _get_commands_to_reach_comfort() + 2
	var submitted_action_count: int = 0
	while (
		not controller._latest_snapshot.water_target_comfortable
		and submitted_action_count < maximum_action_count
	):
		if water_button.disabled:
			return false
		water_button.pressed.emit()
		if not controller._latest_snapshot.water_action_pending:
			return false
		controller._process(SimulationClock.FIXED_STEP_SECONDS)
		submitted_action_count += 1

	if not controller._latest_snapshot.water_target_comfortable:
		return false
	var completion_deadline: int = (
		controller._latest_snapshot.simulation_tick
		+ SPECIES_A_DATA.minimum_zone_dwell_ticks
		+ SPECIES_A_DATA.decision_interval_ticks * 6
		+ (
			SPECIES_A_DATA.travel_duration_ticks * 2
			+ SPECIES_A_DATA.pickup_duration_ticks
			+ SPECIES_A_DATA.drop_duration_ticks
		) * HUMIDITY_SCENARIO_DATA.initial_brood_count
		+ HUMIDITY_SCENARIO_DATA.observation_stable_ticks
		+ 100
	)
	while (
		not controller._latest_snapshot.brood_humidity_observation_unlocked
		and controller._latest_snapshot.simulation_tick < completion_deadline
	):
		controller._process(SimulationClock.FIXED_STEP_SECONDS)
	return controller._latest_snapshot.brood_humidity_observation_unlocked


func _duplicate_scenario_data() -> HabitatScenarioData:
	var scenario_copy: HabitatScenarioData = (
		HUMIDITY_SCENARIO_DATA.duplicate(true) as HabitatScenarioData
	)
	var duplicated_zones: Array[HabitatZoneData] = []
	for source_zone: HabitatZoneData in HUMIDITY_SCENARIO_DATA.zones:
		duplicated_zones.append(
			source_zone.duplicate(true) as HabitatZoneData
		)
	scenario_copy.zones = duplicated_zones
	return scenario_copy


func _find_zone_data(
	scenario_data: HabitatScenarioData,
	zone_id: StringName
) -> HabitatZoneData:
	for zone_data: HabitatZoneData in scenario_data.zones:
		if zone_data != null and zone_data.zone_id == zone_id:
			return zone_data
	return null


func _create_controller(
	species_source: SpeciesData = null,
	scenario_source: HabitatScenarioData = null
) -> MainController:
	var controller: MainController = MAIN_SCENE.instantiate() as MainController
	if species_source != null:
		controller.species_data_source = species_source
	if scenario_source != null:
		controller.habitat_scenario_data_source = scenario_source
	_scene_root.add_child(controller)
	return controller


func _destroy_controller(controller: MainController) -> void:
	_scene_root.remove_child(controller)
	controller.free()


func _advance_controller_to_tick(controller: MainController, target_tick: int) -> void:
	var clock: SimulationClock = controller._simulation_clock
	while clock.get_tick_index() < target_tick:
		var previous_tick: int = clock.get_tick_index()
		var remaining_ticks: int = target_tick - previous_tick
		var frame_ticks: int = mini(remaining_ticks, clock.get_speed_multiplier())
		var real_delta: float = (
			float(frame_ticks)
			* SimulationClock.FIXED_STEP_SECONDS
			/ float(clock.get_speed_multiplier())
		)
		controller._process(real_delta)
		if clock.get_tick_index() <= previous_tick:
			_record_failure(
				"main controller advances toward target Tick",
				"Tick greater than %d" % previous_tick,
				str(clock.get_tick_index())
			)
			return


func _advance_until_water_available(controller: MainController, deadline_tick: int) -> int:
	var water_button: Button = controller.get_node_or_null("%WaterButton") as Button
	while (
		water_button != null
		and water_button.disabled
		and controller._simulation_clock.get_tick_index() < deadline_tick
	):
		controller._process(SimulationClock.FIXED_STEP_SECONDS)
	if water_button != null and not water_button.disabled:
		return controller._simulation_clock.get_tick_index()
	return -1


func _advance_until_carrying(
	controller: MainController,
	deadline_tick: int
) -> ColonySnapshot:
	while controller._simulation_clock.get_tick_index() < deadline_tick:
		controller._process(SimulationClock.FIXED_STEP_SECONDS)
		for ant: AntSnapshot in controller._latest_snapshot.ants:
			if (
				ant.life_stage == AntModel.LifeStage.WORKER
				and ant.worker_task_state == WorkerTaskModel.State.CARRYING_TO_ZONE
				and ant.carried_brood_id >= 0
			):
				return controller._latest_snapshot
	return null


func _find_carried_brood(snapshot: ColonySnapshot) -> AntSnapshot:
	for ant: AntSnapshot in snapshot.ants:
		if ant.life_stage != AntModel.LifeStage.WORKER and ant.carrier_ant_id >= 0:
			return ant
	return null


func _find_active_worker(snapshot: ColonySnapshot) -> AntSnapshot:
	for ant: AntSnapshot in snapshot.ants:
		if (
			ant.life_stage == AntModel.LifeStage.WORKER
			and ant.worker_task_state != WorkerTaskModel.State.IDLE
		):
			return ant
	return null


func _count_brood_in_zone(
	snapshot: ColonySnapshot,
	zone_id: StringName
) -> int:
	var count: int = 0
	for ant: AntSnapshot in snapshot.ants:
		if ant.life_stage != AntModel.LifeStage.WORKER and ant.zone_id == zone_id:
			count += 1
	return count


func _get_first_drop_deadline() -> int:
	return (
		SPECIES_A_DATA.decision_interval_ticks
		+ SPECIES_A_DATA.travel_duration_ticks
		+ SPECIES_A_DATA.pickup_duration_ticks
		+ SPECIES_A_DATA.travel_duration_ticks
		+ SPECIES_A_DATA.drop_duration_ticks
		+ SPECIES_A_DATA.decision_interval_ticks
	)


func _get_aligned_first_command_tick() -> int:
	var first_drop_tick: int = (
		SPECIES_A_DATA.decision_interval_ticks
		+ SPECIES_A_DATA.travel_duration_ticks
		+ SPECIES_A_DATA.pickup_duration_ticks
		+ SPECIES_A_DATA.travel_duration_ticks
		+ SPECIES_A_DATA.drop_duration_ticks
	)
	return (
		ceili(float(first_drop_tick) / float(SimulationClock.VERY_FAST_SPEED))
		* SimulationClock.VERY_FAST_SPEED
	)


func _get_commands_to_reach_comfort() -> int:
	return _get_commands_to_reach_comfort_from_data(
		SPECIES_A_DATA,
		HUMIDITY_SCENARIO_DATA
	)


func _get_commands_to_reach_comfort_from_data(
	species_data: SpeciesData,
	scenario_data: HabitatScenarioData
) -> int:
	var initial_zone: HabitatZoneData = _find_zone_data(
		scenario_data,
		scenario_data.humidity_adjustment_zone_id
	)
	if initial_zone == null:
		return 0
	var humidity_gap: float = maxf(
		species_data.brood_humidity_min - initial_zone.initial_humidity,
		0.0
	)
	return ceili(
		(humidity_gap - 0.000001)
		/ scenario_data.humidity_adjustment_amount
	)


func _get_speed_button(controller: MainController, speed: int) -> Button:
	match speed:
		SimulationClock.NORMAL_SPEED:
			return controller.get_node_or_null("%Speed1xButton") as Button
		SimulationClock.FAST_SPEED:
			return controller.get_node_or_null("%Speed4xButton") as Button
		SimulationClock.VERY_FAST_SPEED:
			return controller.get_node_or_null("%Speed16xButton") as Button
		_:
			return null


func _snapshot_signature(snapshot: ColonySnapshot) -> String:
	var parts: PackedStringArray = [
		str(snapshot.simulation_tick),
		str(snapshot.lifecycle_active),
		str(snapshot.water_action_unlocked),
		str(snapshot.water_action_available),
		str(snapshot.water_action_pending),
		str(snapshot.water_action_count),
		str(snapshot.water_target_comfortable),
		str(snapshot.observation_stable_ticks),
		str(snapshot.brood_humidity_observation_unlocked),
	]
	for zone: HabitatZoneSnapshot in snapshot.zones:
		var connection_names: PackedStringArray = []
		for connected_zone_id: StringName in zone.connected_zone_ids:
			connection_names.append(String(connected_zone_id))
		parts.append(
			"z:%s:%.6f:%s:%s"
			% [
				zone.zone_id,
				zone.humidity,
				str(zone.available),
				",".join(connection_names),
			]
		)
	for ant: AntSnapshot in snapshot.ants:
		parts.append(
			"a:%d:%d:%s:%d:%d:%d:%d:%s:%d:%d"
			% [
				ant.entity_id,
				ant.life_stage,
				ant.zone_id,
				ant.zone_entered_tick,
				ant.reserved_by_ant_id,
				ant.carrier_ant_id,
				ant.worker_task_state,
				ant.target_zone_id,
				ant.target_brood_id,
				ant.carried_brood_id,
			]
		)
		parts.append("p:%d:%d" % [ant.task_elapsed_ticks, ant.task_duration_ticks])
	return "|".join(parts)


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


func _expect_vector2(actual: Vector2, expected: Vector2, message: String) -> void:
	_assertion_count += 1
	if actual.is_equal_approx(expected):
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
