class_name SugarForagingSceneTestSuite
extends RefCounted

const SPECIES_A_DATA: SpeciesData = preload("res://data/species/species_a.tres")
const SUGAR_FORAGING_SCENARIO_DATA: HabitatScenarioData = preload(
	"res://data/habitats/sugar_foraging_slice.tres"
)
const SUGAR_FORAGING_SCENE: PackedScene = preload(
	"res://scenes/foraging/sugar_foraging.tscn"
)

var _assertion_count: int = 0
var _failure_count: int = 0
var _scene_root: Node


func run(scene_root: Node) -> void:
	_scene_root = scene_root
	_test_scene_instantiates_with_independent_controls()
	_test_real_viewport_sugar_path_reaches_observation()
	_test_pause_freezes_simulation_and_projection()
	_test_two_restarts_clear_session_projection_and_annotations()


func get_assertion_count() -> int:
	return _assertion_count


func get_failure_count() -> int:
	return _failure_count


func _test_scene_instantiates_with_independent_controls() -> void:
	var controller: SugarForagingController = _create_controller()
	var habitat_view: SugarForagingHabitatView = controller.get_node_or_null(
		"%SugarForagingHabitatView"
	) as SugarForagingHabitatView
	var sugar_tool_button: Button = controller.get_node_or_null(
		"%SugarToolButton"
	) as Button
	var completion_panel: Control = controller.get_node_or_null(
		"%CompletionPanel"
	) as Control
	var restart_button: Button = controller.get_node_or_null(
		"%RestartButton"
	) as Button
	var debug_panel: Control = controller.get_node_or_null(
		"%DebugPanel"
	) as Control
	var pause_button: Button = controller.get_node_or_null(
		"%PauseButton"
	) as Button
	var speed_1x_button: Button = controller.get_node_or_null(
		"%Speed1xButton"
	) as Button
	var speed_4x_button: Button = controller.get_node_or_null(
		"%Speed4xButton"
	) as Button
	var speed_16x_button: Button = controller.get_node_or_null(
		"%Speed16xButton"
	) as Button

	_expect_true(habitat_view != null, "M3 scene contains its foraging HabitatView")
	_expect_true(sugar_tool_button != null, "M3 scene contains the sugar placement tool")
	_expect_true(completion_panel != null, "M3 scene contains an explicit completion state")
	_expect_true(restart_button != null, "M3 scene contains a restart control")
	_expect_true(debug_panel != null, "M3 scene contains its F3 diagnostic layer")
	_expect_true(pause_button != null, "M3 scene contains a pause control")
	_expect_true(speed_1x_button != null, "M3 scene contains a 1x control")
	_expect_true(speed_4x_button != null, "M3 scene contains a 4x control")
	_expect_true(speed_16x_button != null, "M3 scene contains a 16x control")
	_expect_true(
		controller._simulation_clock != null,
		"M3 scene creates its fixed simulation clock"
	)
	_expect_true(
		controller._colony_simulation != null,
		"M3 scene creates its colony simulation"
	)
	_expect_true(
		controller._latest_snapshot != null,
		"M3 scene publishes an initial GameSnapshot"
	)
	if controller._latest_snapshot != null:
		var snapshot: GameSnapshot = controller._latest_snapshot
		_expect_int(snapshot.simulation_tick, 0, "M3 scene begins at Tick zero")
		_expect_int(
			snapshot.scenario.phase,
			ForagingScenarioSnapshot.Phase.AWAITING_PLACEMENT,
			"M3 scene begins before sugar placement"
		)
		_expect_true(
			snapshot.scenario.place_action_available,
			"authoritative snapshot initially allows sugar placement"
		)
		_expect_true(
			not snapshot.scenario.place_action_pending,
			"initial snapshot has no queued placement"
		)
		_expect_int(
			snapshot.colony.food_sources.size(),
			0,
			"initial M3 snapshot has no placed food source"
		)
		_expect_true(
			not snapshot.colony.lifecycle_active,
			"M3 scenario does not expose lifecycle production counters"
		)
		_expect_int(
			snapshot.colony.ants.size(),
			SUGAR_FORAGING_SCENARIO_DATA.initial_worker_count,
			"M3 scene creates the configured worker count"
		)
	if habitat_view != null:
		_expect_int(
			habitat_view.get_ant_view_count(),
			SUGAR_FORAGING_SCENARIO_DATA.initial_worker_count,
			"foraging HabitatView maps every configured worker"
		)
		_expect_true(
			habitat_view.get_queen_view() != null,
			"foraging habitat keeps the queen visible"
		)
		_expect_true(
			not habitat_view.is_sugar_tool_armed(),
			"placement projection starts unarmed"
		)
	if sugar_tool_button != null:
		_expect_true(
			not sugar_tool_button.disabled,
			"authoritative initial state enables the sugar tool"
		)
	if completion_panel != null:
		_expect_true(
			not completion_panel.visible,
			"completion state starts hidden"
		)
	if restart_button != null:
		_expect_true(
			not restart_button.is_visible_in_tree(),
			"restart control starts hidden"
		)
	if debug_panel != null:
		_expect_true(not debug_panel.visible, "F3 diagnostic layer starts hidden")
	if speed_1x_button != null:
		_expect_true(speed_1x_button.disabled, "M3 scene starts at 1x")

	if debug_panel != null:
		_push_key(controller.get_viewport(), KEY_F3)
		_expect_true(debug_panel.visible, "F3 opens the M3 diagnostic layer")
		_push_key(controller.get_viewport(), KEY_F3)
		_expect_true(not debug_panel.visible, "a second F3 closes the diagnostic layer")

	_destroy_controller(controller)


func _test_real_viewport_sugar_path_reaches_observation() -> void:
	var controller: SugarForagingController = _create_controller()
	var habitat_view: SugarForagingHabitatView = controller.get_node_or_null(
		"%SugarForagingHabitatView"
	) as SugarForagingHabitatView
	var sugar_tool_button: Button = controller.get_node_or_null(
		"%SugarToolButton"
	) as Button
	var name_edit: LineEdit = controller.get_node_or_null(
		"%WorkerNameEdit"
	) as LineEdit
	var name_button: Button = controller.get_node_or_null(
		"%WorkerNameButton"
	) as Button
	var worker_panel: WorkerObservationPanel = controller.get_node_or_null(
		"%WorkerIdentityPanel"
	) as WorkerObservationPanel
	var completion_panel: Control = controller.get_node_or_null(
		"%CompletionPanel"
	) as Control

	if (
		habitat_view == null
		or sugar_tool_button == null
		or name_edit == null
		or name_button == null
		or worker_panel == null
	):
		_record_failure(
			"real M3 player-path fixture is complete",
			"all required controls",
			"one or more controls missing"
		)
		_destroy_controller(controller)
		return

	var workers: Array[AntSnapshot] = _get_workers(
		controller._latest_snapshot.colony
	)
	_expect_int(
		workers.size(),
		SUGAR_FORAGING_SCENARIO_DATA.initial_worker_count,
		"real player path begins with the configured stable workers"
	)
	if workers.is_empty():
		_destroy_controller(controller)
		return

	var original_views: Dictionary[int, AntView] = {}
	for worker: AntSnapshot in workers:
		var worker_view: AntView = habitat_view.get_ant_view(worker.entity_id)
		_expect_true(
			worker_view != null,
			"each stable worker has an AntView before foraging"
		)
		if worker_view != null:
			original_views[worker.entity_id] = worker_view

	var selected_worker: AntSnapshot = workers[0]
	var expected_active_worker_id: int = workers[0].entity_id
	for worker: AntSnapshot in workers:
		if worker.entity_id > selected_worker.entity_id:
			selected_worker = worker
		expected_active_worker_id = mini(
			expected_active_worker_id,
			worker.entity_id
		)
	_expect_true(
		selected_worker.entity_id != expected_active_worker_id,
		"selection fixture names a worker other than the deterministic assignee"
	)
	var selected_worker_view: AntView = habitat_view.get_ant_view(
		selected_worker.entity_id
	)
	if selected_worker_view == null:
		_destroy_controller(controller)
		return
	_click_control(habitat_view, selected_worker_view.position)
	_expect_int(
		controller._player_annotation_state.get_selected_worker_id(),
		selected_worker.entity_id,
		"real habitat click selects a stable worker before intervention"
	)

	var before_name_signature: String = _game_simulation_signature(
		controller._latest_snapshot
	)
	name_edit.text = "Scout"
	_click_control(name_button)
	_expect_string(
		controller._player_annotation_state.get_worker_name(
			selected_worker.entity_id
		),
		"Scout",
		"real name button stores a session-only worker name"
	)
	_expect_string(
		_game_simulation_signature(controller._latest_snapshot),
		before_name_signature,
		"selection and naming do not mutate simulation state"
	)

	var initial_tick: int = controller._latest_snapshot.simulation_tick
	_click_control(sugar_tool_button)
	_expect_true(controller._sugar_tool_armed, "real sugar button arms the placement tool")
	_expect_true(
		habitat_view.is_sugar_tool_armed(),
		"HabitatView mirrors the armed placement tool"
	)
	_expect_int(
		controller._latest_snapshot.simulation_tick,
		initial_tick,
		"arming the tool does not advance simulation time"
	)

	_click_control(
		habitat_view,
		habitat_view.get_placement_zone_center()
	)
	var queued_snapshot: GameSnapshot = controller._latest_snapshot
	_expect_true(
		not controller._sugar_tool_armed,
		"valid placement click consumes the armed tool"
	)
	_expect_true(
		not habitat_view.is_sugar_tool_armed(),
		"valid placement click clears the projected tool state"
	)
	_expect_true(
		queued_snapshot.scenario.place_action_pending,
		"real Viewport placement queues the high-level command"
	)
	_expect_int(
		queued_snapshot.simulation_tick,
		initial_tick,
		"queued placement remains on its submission Tick"
	)
	_expect_int(
		queued_snapshot.colony.food_sources.size(),
		0,
		"queued placement does not create a source immediately"
	)

	controller._process(SimulationClock.FIXED_STEP_SECONDS)
	var applied_snapshot: GameSnapshot = controller._latest_snapshot
	_expect_int(
		applied_snapshot.simulation_tick,
		initial_tick + 1,
		"the next fixed Tick applies the UI placement command"
	)
	_expect_true(
		not applied_snapshot.scenario.place_action_pending,
		"applied placement clears the pending flag"
	)
	_expect_int(
		applied_snapshot.scenario.place_action_count,
		1,
		"real player path applies exactly one configured placement"
	)
	_expect_int(
		applied_snapshot.colony.food_sources.size(),
		1,
		"the configured food source appears on the next Tick"
	)
	if not applied_snapshot.colony.food_sources.is_empty():
		_expect_string_name(
			applied_snapshot.colony.food_sources[0].zone_id,
			applied_snapshot.scenario.placement_zone_id,
			"placed source uses the authoritative placement zone"
		)

	var seen_states: Dictionary[int, bool] = {
		ForagingTaskSnapshot.State.IDLE: true,
	}
	var active_worker_id: int = -1
	var carried_sugar_seen: bool = false
	var source_owner_seen: bool = false
	var last_active_state: int = -1
	var completion_deadline: int = _get_completion_deadline()
	while (
		controller._latest_snapshot.scenario.phase
			!= ForagingScenarioSnapshot.Phase.COMPLETED
		and controller._latest_snapshot.simulation_tick < completion_deadline
	):
		var snapshot: GameSnapshot = controller._latest_snapshot
		for worker: AntSnapshot in _get_workers(snapshot.colony):
			var task: ForagingTaskSnapshot = worker.foraging_task
			if task == null or task.state == ForagingTaskSnapshot.State.IDLE:
				continue
			seen_states[task.state] = true
			if active_worker_id < 0:
				active_worker_id = worker.entity_id
				_expect_int(
					active_worker_id,
					expected_active_worker_id,
					"stable lowest worker is assigned independently of player selection"
				)
			_expect_int(
				worker.entity_id,
				active_worker_id,
				"one stable worker owns the full single-source task"
			)
			if task.state != last_active_state:
				last_active_state = task.state
				_expect_true(
					habitat_view.get_ant_view(worker.entity_id)
						== original_views.get(worker.entity_id),
					"state transition reuses the worker's AntView instance"
				)
			if task.carried_portions > 0:
				carried_sugar_seen = true
				var active_view: AntView = habitat_view.get_ant_view(
					worker.entity_id
				)
				_expect_true(
					active_view != null and active_view.z_index == 6,
					"carried sugar raises the worker projection above idle ants"
				)
				for source: FoodSourceSnapshot in snapshot.colony.food_sources:
					if source.food_source_id == task.target_food_source_id:
						source_owner_seen = (
							source.carrier_worker_id == worker.entity_id
						)

		_expect_int(
			habitat_view.get_ant_view_count(),
			SUGAR_FORAGING_SCENARIO_DATA.initial_worker_count,
			"foraging snapshots never duplicate AntView nodes"
		)
		controller._process(SimulationClock.FIXED_STEP_SECONDS)

	var completed_snapshot: GameSnapshot = controller._latest_snapshot
	for state: int in [
		ForagingTaskSnapshot.State.IDLE,
		ForagingTaskSnapshot.State.SEEKING_FOOD,
		ForagingTaskSnapshot.State.MOVING_TO_FOOD,
		ForagingTaskSnapshot.State.COLLECTING,
		ForagingTaskSnapshot.State.RETURNING_TO_NEST,
		ForagingTaskSnapshot.State.SHARING,
	]:
		_expect_true(
			seen_states.has(state),
			"real player path observes foraging state %d" % state
		)
	_expect_true(carried_sugar_seen, "real player path observes a carried sugar portion")
	_expect_true(
		source_owner_seen,
		"carried portion is owned by the same worker in the snapshot"
	)
	_expect_int(
		completed_snapshot.scenario.phase,
		ForagingScenarioSnapshot.Phase.COMPLETED,
		"real Viewport player path reaches the completed phase"
	)
	_expect_true(
		completed_snapshot.observations.has_card(
			SUGAR_FORAGING_SCENARIO_DATA.foraging_observation_card_id
		),
		"sharing unlocks the configured observation card"
	)
	_expect_true(
		_has_expected_foraging_events(completed_snapshot.observations.events),
		"completed journal retains each structured foraging transition"
	)
	_expect_true(
		completion_panel != null and completion_panel.visible,
		"completed snapshot reveals the completion panel"
	)
	_expect_int(
		habitat_view.get_ant_view_count(),
		SUGAR_FORAGING_SCENARIO_DATA.initial_worker_count,
		"completed projection retains exactly the configured workers"
	)
	for worker: AntSnapshot in _get_workers(completed_snapshot.colony):
		_expect_true(
			habitat_view.get_ant_view(worker.entity_id)
				== original_views.get(worker.entity_id),
			"completion keeps every stable AntView instance"
		)
	_expect_string(
		controller._player_annotation_state.get_worker_name(
			selected_worker.entity_id
		),
		"Scout",
		"session-only name coexists with the complete foraging loop"
	)
	_expect_true(
		worker_panel.get_visible_event_ids().is_empty(),
		"naming a different worker does not redirect foraging history"
	)
	var active_worker_view: AntView = habitat_view.get_ant_view(
		active_worker_id
	)
	_click_control(habitat_view, active_worker_view.position)
	_expect_true(
		not worker_panel.get_visible_event_ids().is_empty(),
		"selecting the autonomous assignee reveals its structured history"
	)
	for actor_entity_id: int in worker_panel.get_visible_actor_ids():
		_expect_int(
			actor_entity_id,
			active_worker_id,
			"visible history remains scoped to the autonomous assignee"
		)

	_destroy_controller(controller)


func _test_pause_freezes_simulation_and_projection() -> void:
	var controller: SugarForagingController = _create_controller()
	var habitat_view: SugarForagingHabitatView = controller.get_node_or_null(
		"%SugarForagingHabitatView"
	) as SugarForagingHabitatView
	var sugar_tool_button: Button = controller.get_node_or_null(
		"%SugarToolButton"
	) as Button
	var pause_button: Button = controller.get_node_or_null(
		"%PauseButton"
	) as Button
	if (
		habitat_view == null
		or sugar_tool_button == null
		or pause_button == null
	):
		_record_failure(
			"pause fixture is complete",
			"HabitatView and controls",
			"one or more controls missing"
		)
		_destroy_controller(controller)
		return

	var workers: Array[AntSnapshot] = _get_workers(
		controller._latest_snapshot.colony
	)
	var worker_view: AntView = habitat_view.get_ant_view(
		workers[0].entity_id
	)

	_click_control(sugar_tool_button)
	_expect_true(controller._sugar_tool_armed, "pause fixture arms the sugar tool")
	_click_control(pause_button)
	_expect_true(
		controller._simulation_clock.is_paused(),
		"real pause control pauses the fixed clock"
	)
	_expect_true(
		not controller._sugar_tool_armed,
		"pausing cancels an unfinished placement interaction"
	)
	_expect_true(
		not habitat_view.is_sugar_tool_armed(),
		"paused projection clears the placement target"
	)

	controller._process(5.0)
	_expect_int(
		controller._latest_snapshot.simulation_tick,
		0,
		"paused controller does not advance before placement"
	)
	_expect_true(
		sugar_tool_button.disabled,
		"paused scene does not allow a new placement interaction"
	)

	_click_control(pause_button)
	_expect_true(
		not controller._simulation_clock.is_paused(),
		"real pause control resumes the fixed clock"
	)
	_expect_true(
		not sugar_tool_button.disabled,
		"resuming restores the authoritative placement control"
	)
	_expect_true(
		_start_sugar_via_real_ui(controller, habitat_view),
		"pause fixture starts foraging through the real two-step UI"
	)
	var moving_target_tick: int = (
		1
		+ SUGAR_FORAGING_SCENARIO_DATA.foraging_data.discovery_delay_ticks
		+ 2
	)
	while controller._latest_snapshot.simulation_tick < moving_target_tick:
		controller._process(SimulationClock.FIXED_STEP_SECONDS)
	var moving_worker: AntSnapshot = controller._latest_snapshot.colony.find_ant(
		workers[0].entity_id
	)
	_expect_int(
		moving_worker.foraging_task.state,
		ForagingTaskSnapshot.State.MOVING_TO_FOOD,
		"pause fixture reaches an in-motion foraging state"
	)

	habitat_view.set_interpolation_alpha(0.37)
	var moving_tick: int = controller._latest_snapshot.simulation_tick
	var moving_alpha: float = habitat_view._interpolation_alpha
	var moving_position: Vector2 = worker_view.position
	_click_control(pause_button)
	controller._process(5.0)
	_expect_int(
		controller._latest_snapshot.simulation_tick,
		moving_tick,
		"pause freezes the simulation during worker travel"
	)
	_expect_float(
		habitat_view._interpolation_alpha,
		moving_alpha,
		"pause freezes interpolation during worker travel"
	)
	_expect_vector2(
		worker_view.position,
		moving_position,
		"pause freezes the worker projection during travel"
	)

	_click_control(pause_button)
	controller._process(SimulationClock.FIXED_STEP_SECONDS * 0.5)
	_expect_int(
		controller._latest_snapshot.simulation_tick,
		moving_tick,
		"resumed interpolation advances before the next fixed Tick"
	)
	_expect_true(
		worker_view.position.distance_to(moving_position) > 0.001,
		"resumed interpolation continues the snapshot-derived movement"
	)
	controller._process(SimulationClock.FIXED_STEP_SECONDS * 0.5)
	_expect_int(
		controller._latest_snapshot.simulation_tick,
		moving_tick + 1,
		"resumed travel advances on the next fixed Tick"
	)

	_destroy_controller(controller)


func _test_two_restarts_clear_session_projection_and_annotations() -> void:
	var controller: SugarForagingController = _create_controller()
	var habitat_view: SugarForagingHabitatView = controller.get_node_or_null(
		"%SugarForagingHabitatView"
	) as SugarForagingHabitatView
	var name_edit: LineEdit = controller.get_node_or_null(
		"%WorkerNameEdit"
	) as LineEdit
	var name_button: Button = controller.get_node_or_null(
		"%WorkerNameButton"
	) as Button
	var restart_button: Button = controller.get_node_or_null(
		"%RestartButton"
	) as Button
	var worker_panel: WorkerObservationPanel = controller.get_node_or_null(
		"%WorkerIdentityPanel"
	) as WorkerObservationPanel
	if (
		habitat_view == null
		or name_edit == null
		or name_button == null
		or restart_button == null
		or worker_panel == null
	):
		_record_failure(
			"restart fixture is complete",
			"all restart controls",
			"one or more controls missing"
		)
		_destroy_controller(controller)
		return

	for restart_index: int in range(2):
		var workers: Array[AntSnapshot] = _get_workers(
			controller._latest_snapshot.colony
		)
		var worker: AntSnapshot = workers[0]
		var worker_view: AntView = habitat_view.get_ant_view(
			worker.entity_id
		)
		_click_control(habitat_view, worker_view.position)
		name_edit.text = "Session%d" % (restart_index + 1)
		_click_control(name_button)

		_expect_true(
			_start_sugar_via_real_ui(controller, habitat_view),
			"each restart fixture submits sugar through the real two-step UI"
		)
		_expect_true(
			_advance_until_completion(controller),
			"each restart fixture reaches observation completion"
		)
		_expect_true(
			not controller._player_annotation_state.get_recent_events(
				worker.entity_id
			).is_empty(),
			"each completed session retains selected-worker history"
		)
		_expect_true(
			restart_button.is_visible_in_tree() and not restart_button.disabled,
			"completed session exposes an enabled restart control"
		)

		_click_control(restart_button)
		var restarted_snapshot: GameSnapshot = controller._latest_snapshot
		_expect_int(
			restarted_snapshot.simulation_tick,
			0,
			"restart returns M3 simulation to Tick zero"
		)
		_expect_int(
			restarted_snapshot.scenario.phase,
			ForagingScenarioSnapshot.Phase.AWAITING_PLACEMENT,
			"restart restores the placement phase"
		)
		_expect_true(
			restarted_snapshot.scenario.place_action_available,
			"restart restores authoritative placement availability"
		)
		_expect_true(
			not restarted_snapshot.scenario.place_action_pending,
			"restart clears any queued placement"
		)
		_expect_int(
			restarted_snapshot.scenario.place_action_count,
			0,
			"restart clears the applied placement count"
		)
		_expect_int(
			restarted_snapshot.colony.food_sources.size(),
			0,
			"restart removes the prior session's food source"
		)
		_expect_true(
			not restarted_snapshot.observations.has_card(
				SUGAR_FORAGING_SCENARIO_DATA.foraging_observation_card_id
			),
			"restart clears the session observation card"
		)
		_expect_true(
			not controller._sugar_tool_armed
				and not habitat_view.is_sugar_tool_armed(),
			"restart clears controller and View tool state"
		)
		_expect_int(
			habitat_view.get_ant_view_count(),
			SUGAR_FORAGING_SCENARIO_DATA.initial_worker_count,
			"restart projects exactly one AntView per fresh worker"
		)
		_expect_int(
			habitat_view._entity_layer.get_child_count(),
			SUGAR_FORAGING_SCENARIO_DATA.initial_worker_count + 1,
			"restart leaves no stale or duplicate entity nodes"
		)
		_expect_int(
			controller._player_annotation_state.get_selected_worker_id(),
			-1,
			"restart clears worker selection"
		)
		_expect_string(
			controller._player_annotation_state.get_worker_name(
				worker.entity_id
			),
			"",
			"restart clears the optional worker name"
		)
		_expect_int(
			controller._player_annotation_state.get_recent_events(
				worker.entity_id
			).size(),
			0,
			"restart clears selected-worker history"
		)
		_expect_int(
			controller._player_annotation_state.get_last_consumed_event_id(),
			0,
			"restart clears the structured-event cursor"
		)
		_expect_int(
			worker_panel.get_visible_event_ids().size(),
			0,
			"restart clears visible history rows"
		)
		_expect_string(name_edit.text, "", "restart clears the optional name field")

	_destroy_controller(controller)


func _start_sugar_via_real_ui(
	controller: SugarForagingController,
	habitat_view: SugarForagingHabitatView
) -> bool:
	var sugar_tool_button: Button = controller.get_node_or_null(
		"%SugarToolButton"
	) as Button
	if sugar_tool_button == null or sugar_tool_button.disabled:
		return false
	_click_control(sugar_tool_button)
	if not controller._sugar_tool_armed:
		return false
	_click_control(
		habitat_view,
		habitat_view.get_placement_zone_center()
	)
	if not controller._latest_snapshot.scenario.place_action_pending:
		return false
	controller._process(SimulationClock.FIXED_STEP_SECONDS)
	return (
		controller._latest_snapshot.colony.food_sources.size() == 1
		and not controller._latest_snapshot.scenario.place_action_pending
	)


func _advance_until_completion(
	controller: SugarForagingController
) -> bool:
	var deadline_tick: int = _get_completion_deadline()
	while (
		controller._latest_snapshot.scenario.phase
			!= ForagingScenarioSnapshot.Phase.COMPLETED
		and controller._latest_snapshot.simulation_tick < deadline_tick
	):
		controller._process(SimulationClock.FIXED_STEP_SECONDS)
	return (
		controller._latest_snapshot.scenario.phase
		== ForagingScenarioSnapshot.Phase.COMPLETED
	)


func _get_completion_deadline() -> int:
	var foraging_data: ForagingData = (
		SUGAR_FORAGING_SCENARIO_DATA.foraging_data
	)
	return (
		1
		+ foraging_data.discovery_delay_ticks
		+ foraging_data.outbound_travel_duration_ticks
		+ foraging_data.collection_duration_ticks
		+ foraging_data.return_travel_duration_ticks
		+ foraging_data.sharing_duration_ticks
		+ 20
	)


func _has_expected_foraging_events(
	events: Array[ObservationEvent]
) -> bool:
	var event_types: Dictionary[int, bool] = {}
	for event: ObservationEvent in events:
		event_types[event.event_type] = true
	for expected_type: int in [
		ObservationEvent.Type.FOOD_SEEK_STARTED,
		ObservationEvent.Type.FOOD_TRAVEL_STARTED,
		ObservationEvent.Type.SUGAR_COLLECTED,
		ObservationEvent.Type.SUGAR_RETURN_STARTED,
		ObservationEvent.Type.SUGAR_SHARED,
		ObservationEvent.Type.SUGAR_OBSERVATION_COMPLETED,
	]:
		if not event_types.has(expected_type):
			return false
	return true


func _create_controller() -> SugarForagingController:
	var controller: SugarForagingController = (
		SUGAR_FORAGING_SCENE.instantiate() as SugarForagingController
	)
	_scene_root.add_child(controller)
	controller.set_anchors_preset(Control.PRESET_TOP_LEFT)
	controller.position = Vector2.ZERO
	controller.size = controller.get_viewport_rect().size
	_force_container_layout(controller)
	return controller


func _destroy_controller(controller: SugarForagingController) -> void:
	_scene_root.remove_child(controller)
	controller.free()


func _click_control(
	control: Control,
	local_position: Vector2 = Vector2.INF
) -> void:
	var click_position: Vector2 = local_position
	if not is_finite(click_position.x) or not is_finite(click_position.y):
		click_position = control.size * 0.5
	var viewport_position: Vector2 = (
		control.get_global_transform_with_canvas() * click_position
	)
	var viewport: Viewport = control.get_viewport()

	var motion_event: InputEventMouseMotion = InputEventMouseMotion.new()
	motion_event.position = viewport_position
	motion_event.global_position = viewport_position
	viewport.push_input(motion_event, true)

	var click_event: InputEventMouseButton = InputEventMouseButton.new()
	click_event.button_index = MOUSE_BUTTON_LEFT
	click_event.button_mask = MOUSE_BUTTON_MASK_LEFT
	click_event.pressed = true
	click_event.position = viewport_position
	click_event.global_position = viewport_position
	viewport.push_input(click_event, true)

	var release_event: InputEventMouseButton = click_event.duplicate()
	release_event.pressed = false
	release_event.button_mask = 0
	viewport.push_input(release_event, true)


func _push_key(viewport: Viewport, keycode: Key) -> void:
	var press_event: InputEventKey = InputEventKey.new()
	press_event.keycode = keycode
	press_event.physical_keycode = keycode
	press_event.pressed = true
	viewport.push_input(press_event, true)

	var release_event: InputEventKey = press_event.duplicate()
	release_event.pressed = false
	viewport.push_input(release_event, true)


func _force_container_layout(node: Node) -> void:
	if node is Container:
		node.notification(Container.NOTIFICATION_SORT_CHILDREN)
	for child: Node in node.get_children():
		_force_container_layout(child)


func _get_workers(snapshot: ColonySnapshot) -> Array[AntSnapshot]:
	var workers: Array[AntSnapshot] = []
	for ant: AntSnapshot in snapshot.ants:
		if ant.life_stage == AntModel.LifeStage.WORKER:
			workers.append(ant)
	workers.sort_custom(
		func(first: AntSnapshot, second: AntSnapshot) -> bool:
			return first.entity_id < second.entity_id
	)
	return workers


func _game_simulation_signature(snapshot: GameSnapshot) -> String:
	var parts: PackedStringArray = [
		str(snapshot.simulation_tick),
		String(snapshot.scenario.scenario_id),
		str(snapshot.scenario.phase),
		str(snapshot.scenario.place_action_available),
		str(snapshot.scenario.place_action_pending),
		str(snapshot.scenario.place_action_count),
	]
	for zone: HabitatZoneSnapshot in snapshot.colony.zones:
		parts.append(
			"z:%s:%.6f:%s:%s"
			% [
				zone.zone_id,
				zone.humidity,
				str(zone.available),
				",".join(zone.connected_zone_ids),
			]
		)
	for ant: AntSnapshot in snapshot.colony.ants:
		var task: ForagingTaskSnapshot = ant.foraging_task
		parts.append(
			"a:%d:%d:%s:%d:%d:%d:%s:%s:%d:%d"
			% [
				ant.entity_id,
				ant.life_stage,
				ant.zone_id,
				task.state if task != null else -1,
				task.target_food_source_id if task != null else -1,
				task.carried_portions if task != null else 0,
				task.origin_zone_id if task != null else &"",
				task.target_zone_id if task != null else &"",
				task.elapsed_ticks if task != null else 0,
				task.duration_ticks if task != null else 0,
			]
		)
	for source: FoodSourceSnapshot in snapshot.colony.food_sources:
		parts.append(
			"f:%d:%s:%d:%s:%d:%d"
			% [
				source.food_source_id,
				source.zone_id,
				source.remaining_portions,
				str(source.available),
				source.reserved_by_worker_id,
				source.carrier_worker_id,
			]
		)
	for event: ObservationEvent in snapshot.observations.events:
		parts.append(
			"e:%d:%d:%d:%d:%d:%s:%s"
			% [
				event.event_id,
				event.tick,
				event.event_type,
				event.actor_entity_id,
				event.subject_entity_id,
				event.source_zone_id,
				event.target_zone_id,
			]
		)
	for card_id: StringName in snapshot.observations.unlocked_card_ids:
		parts.append("c:%s" % card_id)
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


func _expect_vector2(
	actual: Vector2,
	expected: Vector2,
	message: String
) -> void:
	_assertion_count += 1
	if actual.is_equal_approx(expected):
		return
	_record_failure(message, str(expected), str(actual))


func _expect_true(actual: bool, message: String) -> void:
	_assertion_count += 1
	if actual:
		return
	_record_failure(message, "true", "false")


func _expect_string(
	actual: String,
	expected: String,
	message: String
) -> void:
	_assertion_count += 1
	if actual == expected:
		return
	_record_failure(message, expected, actual)


func _expect_string_name(
	actual: StringName,
	expected: StringName,
	message: String
) -> void:
	_assertion_count += 1
	if actual == expected:
		return
	_record_failure(message, String(expected), String(actual))


func _record_failure(
	message: String,
	expected: String,
	actual: String
) -> void:
	_failure_count += 1
	printerr("  %s - expected %s, got %s" % [message, expected, actual])
