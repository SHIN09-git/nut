class_name WorkerIdentitySceneTestSuite
extends RefCounted

const SPECIES_A_DATA: SpeciesData = preload("res://data/species/species_a.tres")
const HUMIDITY_SCENARIO_DATA: HabitatScenarioData = preload(
	"res://data/habitats/humidity_relocation_slice.tres"
)
const MAIN_SCENE: PackedScene = preload("res://scenes/main/main.tscn")

var _assertion_count: int = 0
var _failure_count: int = 0
var _scene_root: Node
var _viewport_mouse_entered: bool = false


func run(scene_root: Node) -> void:
	_scene_root = scene_root
	_test_pointer_selection_uses_stable_worker_identity()
	_test_naming_is_session_only_and_simulation_neutral()
	_test_16x_batches_feed_selected_worker_history()
	_test_two_restarts_clear_identity_annotations()


func get_assertion_count() -> int:
	return _assertion_count


func get_failure_count() -> int:
	return _failure_count


func _test_pointer_selection_uses_stable_worker_identity() -> void:
	var controller: MainController = _create_controller()
	var habitat_view: HabitatView = controller.get_node_or_null(
		"%HabitatView"
	) as HabitatView
	var panel: WorkerObservationPanel = controller.get_node_or_null(
		"%WorkerIdentityPanel"
	) as WorkerObservationPanel
	var prompt_label: Label = controller.get_node_or_null(
		"%WorkerPromptLabel"
	) as Label
	var workers: Array[AntSnapshot] = _get_workers(
		controller._latest_snapshot
	)

	_expect_true(habitat_view != null, "M2 main scene contains a selectable HabitatView")
	_expect_true(panel != null, "M2 main scene contains a worker observation panel")
	_expect_true(prompt_label != null, "worker observation panel contains its empty-state prompt")
	_expect_int(workers.size(), 3, "identity fixture begins with three stable workers")
	_expect_int(
		controller._player_annotation_state.get_selected_worker_id(),
		-1,
		"identity session begins without a selected worker"
	)
	if habitat_view == null or panel == null or workers.size() < 2:
		_destroy_controller(controller)
		return

	var first_worker: AntSnapshot = workers[0]
	var second_worker: AntSnapshot = workers[1]
	var first_view: AntView = habitat_view.get_ant_view(first_worker.entity_id)
	var second_view: AntView = habitat_view.get_ant_view(second_worker.entity_id)
	_expect_true(first_view != null, "first stable worker has a visual node")
	_expect_true(second_view != null, "second stable worker has a visual node")
	if first_view == null or second_view == null:
		_destroy_controller(controller)
		return

	_click_habitat(habitat_view, first_view.position)
	_expect_int(
		controller._player_annotation_state.get_selected_worker_id(),
		first_worker.entity_id,
		"clicking a rendered worker selects its stable entity ID"
	)
	_expect_true(first_view.is_selected(), "selected worker receives the restrained outline")
	_expect_true(not second_view.is_selected(), "unselected workers do not receive the outline")
	if prompt_label != null:
		_expect_true(not prompt_label.visible, "selecting a worker hides the empty-state prompt")

	var original_first_view: AntView = first_view
	_advance_controller_to_tick(
		controller,
		SPECIES_A_DATA.decision_interval_ticks + 1
	)
	_expect_int(
		controller._player_annotation_state.get_selected_worker_id(),
		first_worker.entity_id,
		"selection remains attached through consecutive simulation snapshots"
	)
	_expect_true(
		habitat_view.get_ant_view(first_worker.entity_id) == original_first_view,
		"selection keeps the same stable AntView instance"
	)

	var brood: AntSnapshot = _get_first_brood(controller._latest_snapshot)
	var brood_view: AntView = (
		habitat_view.get_ant_view(brood.entity_id) if brood != null else null
	)
	_expect_true(brood_view != null, "pointer fixture identifies a brood visual")
	if brood_view != null:
		_click_habitat(habitat_view, brood_view.position)
		_expect_int(
			controller._player_annotation_state.get_selected_worker_id(),
			first_worker.entity_id,
			"clicking brood does not replace the selected worker"
		)
	_click_habitat(habitat_view, Vector2(2.0, 2.0))
	_expect_int(
		controller._player_annotation_state.get_selected_worker_id(),
		first_worker.entity_id,
		"clicking empty habitat space keeps the current selection"
	)

	second_view = habitat_view.get_ant_view(second_worker.entity_id)
	_click_habitat(habitat_view, second_view.position)
	_expect_int(
		controller._player_annotation_state.get_selected_worker_id(),
		second_worker.entity_id,
		"clicking a different worker changes selection deterministically"
	)
	_expect_true(
		not original_first_view.is_selected(),
		"previous worker outline clears after a new selection"
	)
	_expect_true(second_view.is_selected(), "newly selected worker receives the outline")

	_destroy_controller(controller)


func _test_naming_is_session_only_and_simulation_neutral() -> void:
	var named_controller: MainController = _create_controller()
	var control_controller: MainController
	var habitat_view: HabitatView = named_controller.get_node_or_null(
		"%HabitatView"
	) as HabitatView
	var name_edit: LineEdit = named_controller.get_node_or_null(
		"%WorkerNameEdit"
	) as LineEdit
	var name_button: Button = named_controller.get_node_or_null(
		"%WorkerNameButton"
	) as Button
	var display_name_label: Label = named_controller.get_node_or_null(
		"%WorkerDisplayNameLabel"
	) as Label
	var worker: AntSnapshot = _get_workers(
		named_controller._latest_snapshot
	)[0]
	var worker_view: AntView = habitat_view.get_ant_view(worker.entity_id)

	_click_habitat(habitat_view, worker_view.position)
	_expect_true(name_edit != null, "identity panel contains an optional name field")
	_expect_true(name_button != null, "identity panel contains a name commit control")
	if name_edit == null or name_button == null:
		_destroy_controller(named_controller)
		return

	name_edit.text = "  栗子  "
	name_button.pressed.emit()
	_expect_string(
		named_controller._player_annotation_state.get_worker_name(
			worker.entity_id
		),
		"栗子",
		"optional names are normalized and retained by the session layer"
	)
	if display_name_label != null:
		_expect_string(
			display_name_label.text,
			"栗子",
			"identity panel displays the session annotation"
		)

	control_controller = _create_controller()
	var comparison_tick: int = (
		SPECIES_A_DATA.decision_interval_ticks
		+ SPECIES_A_DATA.travel_duration_ticks
		+ SPECIES_A_DATA.pickup_duration_ticks
		+ SPECIES_A_DATA.travel_duration_ticks
		+ SPECIES_A_DATA.drop_duration_ticks
	)
	_advance_controller_to_tick(named_controller, comparison_tick)
	_advance_controller_to_tick(control_controller, comparison_tick)
	_expect_string(
		_simulation_signature(named_controller._latest_snapshot),
		_simulation_signature(control_controller._latest_snapshot),
		"naming changes no canonical simulation state or structured event"
	)

	name_edit.text = ""
	name_button.pressed.emit()
	_expect_string(
		named_controller._player_annotation_state.get_worker_name(
			worker.entity_id
		),
		"",
		"empty optional name clears the session annotation"
	)
	_expect_string(
		_simulation_signature(named_controller._latest_snapshot),
		_simulation_signature(control_controller._latest_snapshot),
		"clearing a name also leaves the simulation signature unchanged"
	)

	_destroy_controller(named_controller)
	_destroy_controller(control_controller)


func _test_16x_batches_feed_selected_worker_history() -> void:
	var fast_species_data: SpeciesData = _create_fast_event_species_data()
	var controller: MainController = _create_controller(fast_species_data)
	var habitat_view: HabitatView = controller.get_node_or_null(
		"%HabitatView"
	) as HabitatView
	var panel: WorkerObservationPanel = controller.get_node_or_null(
		"%WorkerIdentityPanel"
	) as WorkerObservationPanel
	var speed_button: Button = controller.get_node_or_null(
		"%Speed16xButton"
	) as Button
	var worker: AntSnapshot = _get_workers(controller._latest_snapshot)[0]
	var worker_view: AntView = habitat_view.get_ant_view(worker.entity_id)

	_click_habitat(habitat_view, worker_view.position)
	speed_button.pressed.emit()
	_expect_int(
		controller._simulation_clock.get_speed_multiplier(),
		SimulationClock.VERY_FAST_SPEED,
		"history fixture runs the real main scene at 16x"
	)
	controller._process(SimulationClock.FIXED_STEP_SECONDS)
	_expect_int(
		controller._latest_snapshot.simulation_tick,
		SimulationClock.VERY_FAST_SPEED,
		"one 16x render frame spans sixteen fixed simulation Ticks"
	)
	var batch_events: Array[ObservationEvent] = (
		controller._latest_snapshot.observation_events
	)
	_expect_true(
		batch_events.size() >= 12,
		"one 16x frame retains events from several distinct transition Ticks"
	)
	var event_ticks: Dictionary[int, bool] = {}
	for event: ObservationEvent in batch_events:
		event_ticks[event.tick] = true
	_expect_true(
		event_ticks.size() >= 4,
		"the 16x fixture crosses several event-producing Tick boundaries"
	)
	_expect_int(
		controller._player_annotation_state.get_last_consumed_event_id(),
		batch_events[-1].event_id,
		"session cursor consumes the complete multi-boundary event batch"
	)
	var selected_events: Array[ObservationEvent] = (
		controller._player_annotation_state.get_recent_events(
			worker.entity_id
		)
	)
	_expect_int(
		selected_events.size(),
		PlayerAnnotationState.MAX_RECENT_EVENTS_PER_WORKER,
		"selected worker keeps the bounded tail from the complete batch"
	)
	_expect_true(
		not controller._player_annotation_state.has_event_gap(),
		"per-Tick delivery at 16x produces no event cursor gap"
	)
	var reference_controller: MainController = _create_controller(
		fast_species_data
	)
	_advance_controller_to_tick(
		reference_controller,
		SimulationClock.VERY_FAST_SPEED
	)
	_expect_string(
		_simulation_signature(controller._latest_snapshot),
		_simulation_signature(reference_controller._latest_snapshot),
		"16x multi-boundary delivery matches the complete 1x event sequence"
	)
	_destroy_controller(reference_controller)

	var visible_event_ids: Array[int] = panel.get_visible_event_ids()
	var visible_actor_ids: Array[int] = panel.get_visible_actor_ids()
	_expect_int(visible_event_ids.size(), 4, "player panel shows the requested recent 3-5 records")
	_expect_true(
		_ids_are_strictly_increasing(visible_event_ids),
		"visible worker history preserves structured event order"
	)
	for actor_entity_id: int in visible_actor_ids:
		_expect_int(
			actor_entity_id,
			worker.entity_id,
			"visible history contains only the selected worker's records"
		)

	_destroy_controller(controller)


func _test_two_restarts_clear_identity_annotations() -> void:
	var controller: MainController = _create_controller()
	var habitat_view: HabitatView = controller.get_node_or_null(
		"%HabitatView"
	) as HabitatView
	var name_edit: LineEdit = controller.get_node_or_null(
		"%WorkerNameEdit"
	) as LineEdit
	var name_button: Button = controller.get_node_or_null(
		"%WorkerNameButton"
	) as Button
	var restart_button: Button = controller.get_node_or_null(
		"%RestartButton"
	) as Button
	var panel: WorkerObservationPanel = controller.get_node_or_null(
		"%WorkerIdentityPanel"
	) as WorkerObservationPanel

	for restart_index: int in range(2):
		var worker: AntSnapshot = _get_workers(controller._latest_snapshot)[0]
		var worker_view: AntView = habitat_view.get_ant_view(worker.entity_id)
		_click_habitat(habitat_view, worker_view.position)
		name_edit.text = "观察对象%d" % (restart_index + 1)
		name_button.pressed.emit()
		_advance_controller_to_tick(controller, _get_first_drop_tick())
		var worker_events: Array[ObservationEvent] = (
			controller._player_annotation_state.get_recent_events(
				worker.entity_id
			)
		)
		_expect_true(
			not worker_events.is_empty(),
			"each session records behavior before completion"
		)
		if not worker_events.is_empty():
			_expect_int(
				worker_events[0].event_id,
				1,
				"each fresh session begins its structured event IDs at one"
			)
		_expect_true(
			_complete_session_through_player_controls(controller),
			"each identity session completes through the real water controls"
		)
		_expect_true(
			restart_button != null and not restart_button.disabled,
			"completed identity session exposes the real restart control"
		)
		restart_button.pressed.emit()

		_expect_int(
			controller._latest_snapshot.simulation_tick,
			0,
			"restart returns the simulation to Tick zero"
		)
		_expect_int(
			controller._player_annotation_state.get_selected_worker_id(),
			-1,
			"restart clears the selected worker"
		)
		_expect_string(
			controller._player_annotation_state.get_worker_name(
				worker.entity_id
			),
			"",
			"restart clears optional worker names"
		)
		_expect_int(
			controller._player_annotation_state.get_recent_events(
				worker.entity_id
			).size(),
			0,
			"restart clears session behavior history"
		)
		_expect_int(
			controller._player_annotation_state.get_last_consumed_event_id(),
			0,
			"restart clears the structured event consumer cursor"
		)
		_expect_int(
			panel.get_visible_event_ids().size(),
			0,
			"restart clears visible recent-action rows"
		)
		_expect_string(name_edit.text, "", "restart clears the optional name field")
		worker_view = habitat_view.get_ant_view(worker.entity_id)
		_expect_true(
			worker_view != null and not worker_view.is_selected(),
			"restart creates an unselected projection for the new session"
		)

	_destroy_controller(controller)


func _complete_session_through_player_controls(
	controller: MainController
) -> bool:
	var water_button: Button = controller.get_node_or_null(
		"%WaterButton"
	) as Button
	if water_button == null:
		return false
	var deadline_tick: int = (
		controller._latest_snapshot.simulation_tick
		+ SPECIES_A_DATA.minimum_zone_dwell_ticks
		+ SPECIES_A_DATA.decision_interval_ticks
		* HUMIDITY_SCENARIO_DATA.initial_brood_count
		+ (
			SPECIES_A_DATA.travel_duration_ticks * 2
			+ SPECIES_A_DATA.pickup_duration_ticks
			+ SPECIES_A_DATA.drop_duration_ticks
		) * HUMIDITY_SCENARIO_DATA.initial_brood_count
		+ HUMIDITY_SCENARIO_DATA.observation_stable_ticks
		+ 100
	)
	while (
		not controller._latest_snapshot.water_target_comfortable
		and controller._latest_snapshot.simulation_tick < deadline_tick
	):
		if water_button.disabled:
			controller._process(SimulationClock.FIXED_STEP_SECONDS)
			continue
		water_button.pressed.emit()
		if not controller._latest_snapshot.water_action_pending:
			return false
		controller._process(SimulationClock.FIXED_STEP_SECONDS)

	while (
		not controller._latest_snapshot.brood_humidity_observation_unlocked
		and controller._latest_snapshot.simulation_tick < deadline_tick
	):
		controller._process(SimulationClock.FIXED_STEP_SECONDS)
	return controller._latest_snapshot.brood_humidity_observation_unlocked


func _create_controller(
	species_data_source: SpeciesData = SPECIES_A_DATA
) -> MainController:
	var controller: MainController = MAIN_SCENE.instantiate() as MainController
	controller.species_data_source = species_data_source
	_scene_root.add_child(controller)
	controller.set_anchors_preset(Control.PRESET_TOP_LEFT)
	controller.position = Vector2.ZERO
	controller.size = controller.get_viewport_rect().size
	_force_container_layout(controller)
	return controller


func _destroy_controller(controller: MainController) -> void:
	_scene_root.remove_child(controller)
	controller.free()


func _advance_controller_to_tick(
	controller: MainController,
	target_tick: int
) -> void:
	var clock: SimulationClock = controller._simulation_clock
	while clock.get_tick_index() < target_tick:
		var previous_tick: int = clock.get_tick_index()
		var remaining_ticks: int = target_tick - previous_tick
		var frame_ticks: int = mini(
			remaining_ticks,
			clock.get_speed_multiplier()
		)
		var real_delta: float = (
			float(frame_ticks)
			* SimulationClock.FIXED_STEP_SECONDS
			/ float(clock.get_speed_multiplier())
		)
		controller._process(real_delta)
		if clock.get_tick_index() <= previous_tick:
			_record_failure(
				"identity controller advances toward target Tick",
				"Tick greater than %d" % previous_tick,
				str(clock.get_tick_index())
			)
			return


func _click_habitat(habitat_view: HabitatView, local_position: Vector2) -> void:
	var viewport_position: Vector2 = (
		habitat_view.get_global_transform_with_canvas() * local_position
	)
	var viewport: Viewport = habitat_view.get_viewport()
	if not _viewport_mouse_entered:
		viewport.notify_mouse_entered()
		_viewport_mouse_entered = true
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


func _get_first_brood(snapshot: ColonySnapshot) -> AntSnapshot:
	for ant: AntSnapshot in snapshot.ants:
		if ant.life_stage != AntModel.LifeStage.WORKER:
			return ant
	return null


func _get_first_drop_tick() -> int:
	return (
		SPECIES_A_DATA.decision_interval_ticks
		+ SPECIES_A_DATA.travel_duration_ticks
		+ SPECIES_A_DATA.pickup_duration_ticks
		+ SPECIES_A_DATA.travel_duration_ticks
		+ SPECIES_A_DATA.drop_duration_ticks
	)


func _create_fast_event_species_data() -> SpeciesData:
	var fast_data: SpeciesData = SPECIES_A_DATA.duplicate(true) as SpeciesData
	fast_data.decision_interval_ticks = 1
	fast_data.travel_duration_ticks = 2
	fast_data.pickup_duration_ticks = 2
	fast_data.drop_duration_ticks = 2
	fast_data.minimum_zone_dwell_ticks = 0
	return fast_data


func _ids_are_strictly_increasing(ids: Array[int]) -> bool:
	for index: int in range(1, ids.size()):
		if ids[index] <= ids[index - 1]:
			return false
	return true


func _simulation_signature(snapshot: ColonySnapshot) -> String:
	var parts: PackedStringArray = [
		str(snapshot.simulation_tick),
		str(snapshot.lifecycle_active),
		str(snapshot.queen_entity_id),
		str(snapshot.queen_laid_egg_count),
		str(snapshot.max_first_generation_brood),
		str(snapshot.next_egg_tick),
		String(snapshot.scenario_id),
		str(snapshot.humidity_adjustment_count),
		str(snapshot.water_action_unlocked),
		str(snapshot.water_action_available),
		str(snapshot.water_action_pending),
		str(snapshot.water_action_count),
		str(snapshot.water_target_comfortable),
		str(snapshot.observation_stable_ticks),
		str(snapshot.brood_humidity_observation_unlocked),
	]
	for zone: HabitatZoneSnapshot in snapshot.zones:
		parts.append(
			"z:%s:%.6f:%s:%s"
			% [
				zone.zone_id,
				zone.humidity,
				str(zone.available),
				",".join(zone.connected_zone_ids),
			]
		)
	for ant: AntSnapshot in snapshot.ants:
		parts.append(
			"a:%d:%d:%s:%d:%d:%d:%d:%s:%d:%d:%d:%d"
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
				ant.task_elapsed_ticks,
				ant.task_duration_ticks,
			]
		)
	for event: ObservationEvent in snapshot.observation_events:
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
