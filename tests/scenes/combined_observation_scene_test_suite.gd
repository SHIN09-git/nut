class_name CombinedObservationSceneTestSuite
extends RefCounted

const SPECIES_A_DATA: SpeciesData = preload(
	"res://data/species/species_a.tres"
)
const COMBINED_SCENARIO_DATA: HabitatScenarioData = preload(
	"res://data/habitats/combined_observation_slice.tres"
)
const COMBINED_SCENE: PackedScene = preload(
	"res://scenes/main/combined_observation.tscn"
)

var _assertion_count: int = 0
var _failure_count: int = 0
var _scene_root: Node


func run(scene_root: Node) -> void:
	_scene_root = scene_root
	_test_scene_instantiates_at_target_size()
	_test_preparation_gate_freezes_tick_and_projection()
	_test_pre_event_copy_roles_do_not_leak()
	_test_card_projection_uses_frozen_snapshot_ids()
	_test_real_viewport_path_reaches_summary_and_restarts()
	_test_pause_and_f3_freeze_projection()


func get_assertion_count() -> int:
	return _assertion_count


func get_failure_count() -> int:
	return _failure_count


func _test_scene_instantiates_at_target_size() -> void:
	var controller: CombinedObservationController = _create_controller()
	var habitat_view: CombinedHabitatView = controller.get_node_or_null(
		"%CombinedHabitatView"
	) as CombinedHabitatView
	var worker_panel: WorkerObservationPanel = controller.get_node_or_null(
		"%WorkerIdentityPanel"
	) as WorkerObservationPanel
	var stage_button: Button = controller.get_node_or_null(
		"%StageActionButton"
	) as Button
	var completion_panel: Control = controller.get_node_or_null(
		"%CompletionPanel"
	) as Control
	var debug_panel: Control = controller.get_node_or_null(
		"%DebugPanel"
	) as Control
	var preparation_gate: Control = controller.get_node_or_null(
		"%PreparationGate"
	) as Control
	var start_button: Button = controller.get_node_or_null(
		"%StartObservationButton"
	) as Button
	var pause_button: Button = controller.get_node_or_null(
		"%PauseButton"
	) as Button
	var pause_menu: Control = controller.get_node_or_null(
		"%PauseMenu"
	) as Control
	var speed_4x_button: Button = controller.get_node_or_null(
		"%Speed4xButton"
	) as Button
	var speed_16x_button: Button = controller.get_node_or_null(
		"%Speed16xButton"
	) as Button

	_expect_true(habitat_view != null, "combined scene contains one HabitatView")
	_expect_true(worker_panel != null, "combined scene reuses the identity panel")
	_expect_true(stage_button != null, "combined scene has one staged action control")
	_expect_true(completion_panel != null, "combined scene has a summary panel")
	_expect_true(debug_panel != null, "combined scene has an F3 diagnostic panel")
	_expect_true(
		controller.get_node_or_null("%DebugToggleButton") == null,
		"ordinary layout does not expose a debug button"
	)
	_expect_true(preparation_gate != null, "combined scene has a preparation gate")
	_expect_true(start_button != null, "preparation gate has one start affordance")
	_expect_true(pause_menu != null, "combined scene has one pause menu")
	_expect_true(
		controller._fatal_simulation_error.is_empty(),
		"combined scene starts without a simulation error"
	)
	_expect_true(
		controller._latest_snapshot != null
			and controller._latest_snapshot.sequence != null,
		"combined scene publishes its authoritative sequence snapshot"
	)
	if controller._latest_snapshot != null:
		var snapshot: GameSnapshot = controller._latest_snapshot
		_expect_int(snapshot.simulation_tick, 0, "combined scene starts at Tick zero")
		_expect_int(
			snapshot.sequence.phase,
			ScenarioSequenceSnapshot.Phase.FOUNDING_PRELUDE,
			"combined scene starts in the founding prelude"
		)
		_expect_int(
			snapshot.colony.ants.size(),
			COMBINED_SCENARIO_DATA.initial_brood_count + 1,
			"combined scene creates configured brood plus one late pupa"
		)
	if habitat_view != null:
		_expect_int(
			habitat_view.get_ant_view_count(),
			COMBINED_SCENARIO_DATA.initial_brood_count + 1,
			"one stable view maps every initial ant"
		)
		_expect_true(
			habitat_view.get_queen_view() != null,
			"the queen remains visible in the combined habitat"
		)
	if stage_button != null:
		_expect_true(stage_button.disabled, "intervention is gated during the prelude")
	if preparation_gate != null:
		_expect_true(preparation_gate.visible, "preparation gate starts visible")
	if start_button != null:
		_expect_true(not start_button.disabled, "start affordance is initially available")
	if pause_button != null:
		_expect_true(
			not pause_button.disabled,
			"menu remains available before observation starts"
		)
	if pause_menu != null:
		_expect_true(not pause_menu.visible, "pause menu starts hidden")
	if speed_4x_button != null:
		_expect_true(speed_4x_button.disabled, "4x is locked before observation starts")
	if speed_16x_button != null:
		_expect_true(speed_16x_button.disabled, "16x is locked before observation starts")
	_expect_true(
		controller._simulation_clock.is_paused(),
		"application clock starts frozen behind the preparation gate"
	)
	_expect_int(
		controller._simulation_clock.get_speed_multiplier(),
		SimulationClock.NORMAL_SPEED,
		"preparation gate fixes the application clock at 1x"
	)
	if completion_panel != null:
		_expect_true(not completion_panel.visible, "summary starts hidden")
	if debug_panel != null:
		_expect_true(not debug_panel.visible, "F3 starts hidden")

	_destroy_controller(controller)


func _test_preparation_gate_freezes_tick_and_projection() -> void:
	var controller: CombinedObservationController = _create_controller()
	var habitat_view: CombinedHabitatView = controller.get_node(
		"%CombinedHabitatView"
	) as CombinedHabitatView
	var start_button: Button = controller.get_node(
		"%StartObservationButton"
	) as Button
	var pause_button: Button = controller.get_node("%PauseButton") as Button
	var speed_4x_button: Button = controller.get_node(
		"%Speed4xButton"
	) as Button
	var speed_16x_button: Button = controller.get_node(
		"%Speed16xButton"
	) as Button
	var stage_button: Button = controller.get_node(
		"%StageActionButton"
	) as Button
	var first_ant_id: int = (
		controller._latest_snapshot.sequence.first_worker_entity_id
	)
	var ant_view: AntView = habitat_view.get_ant_view(first_ant_id)
	var queen_view: QueenView = habitat_view.get_queen_view()
	var initial_ant_position: Vector2 = ant_view.position
	var initial_queen_position: Vector2 = queen_view.position
	var initial_signature: String = (
		SimulationSnapshotSignature.canonical_game_snapshot(
			controller._latest_snapshot
		)
	)

	_click_control(pause_button)
	_click_control(speed_4x_button)
	_click_control(speed_16x_button)
	_click_control(stage_button)
	controller._process(3.0)

	_expect_true(
		controller.is_preparation_gate_active(),
		"preparation gate remains active until the start affordance is used"
	)
	_expect_int(
		controller._latest_snapshot.simulation_tick,
		0,
		"processing time behind the preparation gate does not advance Tick"
	)
	_expect_string(
		SimulationSnapshotSignature.canonical_game_snapshot(
			controller._latest_snapshot
		),
		initial_signature,
		"locked controls cannot mutate the initial simulation snapshot"
	)
	_expect_int(
		controller._simulation_clock.get_speed_multiplier(),
		SimulationClock.NORMAL_SPEED,
		"locked speed controls cannot leave 1x"
	)
	_expect_true(
		controller._simulation_clock.is_paused(),
		"locked pause control cannot release the application clock"
	)
	_expect_true(
		habitat_view.are_visuals_paused(),
		"preparation gate freezes habitat projection"
	)
	_expect_float(
		habitat_view.get_interpolation_alpha(),
		0.0,
		"preparation gate holds interpolation at its initial boundary"
	)
	_expect_vector2(
		ant_view.position,
		initial_ant_position,
		"late pupa projection does not move before start"
	)
	_expect_vector2(
		queen_view.position,
		initial_queen_position,
		"queen projection does not move before start"
	)
	_expect_true(
		controller.is_pause_menu_open(),
		"menu button opens settings without releasing the preparation gate"
	)
	(controller.get_node("%ResumeButton") as Button).pressed.emit()
	_expect_true(
		not controller.is_pause_menu_open(),
		"resume closes the menu while the preparation gate remains frozen"
	)

	_press_start_button(controller)
	_expect_true(
		not controller.is_preparation_gate_active(),
		"start button signal releases the preparation gate"
	)
	_expect_true(
		not controller._simulation_clock.is_paused(),
		"start affordance releases only the application clock"
	)
	_expect_true(
		not habitat_view.are_visuals_paused(),
		"start affordance releases visual interpolation"
	)
	_expect_int(
		controller._latest_snapshot.simulation_tick,
		0,
		"starting observation does not submit a simulation command"
	)
	controller._process(SimulationClock.FIXED_STEP_SECONDS)
	_expect_int(
		controller._latest_snapshot.simulation_tick,
		1,
		"first post-start fixed step advances to Tick one"
	)
	_destroy_controller(controller)


func _test_pre_event_copy_roles_do_not_leak() -> void:
	var controller: CombinedObservationController = _create_controller()
	var instruction_label: Label = controller.get_node(
		"%InstructionLabel"
	) as Label
	var feedback_label: Label = controller.get_node(
		"%FeedbackLabel"
	) as Label
	var worker_prompt_label: Label = controller.get_node(
		"%WorkerPromptLabel"
	) as Label
	var selected_worker_content: Control = controller.get_node(
		"%SelectedWorkerContent"
	) as Control
	var name_edit: LineEdit = controller.get_node(
		"%WorkerNameEdit"
	) as LineEdit
	var footer: Label = controller.get_node(
		"SafeArea/Content/Footer"
	) as Label
	var card_labels: Array[Label] = [
		controller.get_node("%EmergenceCardLabel") as Label,
		controller.get_node("%HumidityCardLabel") as Label,
		controller.get_node("%SugarCardLabel") as Label,
	]

	for card_label: Label in card_labels:
		_expect_copy_role(
			card_label,
			CombinedObservationController.COPY_ROLE_NEUTRAL_PLACEHOLDER,
			"locked observation card exposes only a neutral placeholder"
		)
		_expect_string(
			card_label.text,
			TranslationServer.translate("UI_CARD_LOCKED"),
			"locked observation card does not reveal its conclusion"
		)
	_expect_copy_role(
		instruction_label,
		CombinedObservationController.COPY_ROLE_OBSERVATION_CUE,
		"founding instruction is an observable clue"
	)
	_expect_copy_role(
		feedback_label,
		CombinedObservationController.COPY_ROLE_OBSERVATION_CUE,
		"founding feedback is an observable clue"
	)
	_expect_copy_role(
		worker_prompt_label,
		CombinedObservationController.COPY_ROLE_OBSERVATION_CUE,
		"unselected identity prompt is a neutral observation cue"
	)
	_expect_copy_role(
		footer,
		CombinedObservationController.COPY_ROLE_SYSTEM_STATUS,
		"ordinary footer contains status information only"
	)
	_expect_true(
		not selected_worker_content.visible,
		"identity controls remain hidden until independent worker selection"
	)
	_expect_true(
		not name_edit.is_visible_in_tree(),
		"naming affordance is absent before independent worker selection"
	)

	_press_start_button(controller)
	var emergence_ticks: int = (
		SPECIES_A_DATA.pupa_duration_ticks
		- COMBINED_SCENARIO_DATA.sequence_data
			.first_worker_initial_pupa_age_ticks
	)
	for step_index: int in range(emergence_ticks):
		controller._process(SimulationClock.FIXED_STEP_SECONDS)

	_expect_int(
		controller._latest_snapshot.sequence.phase,
		ScenarioSequenceSnapshot.Phase.IDENTITY_OBSERVATION,
		"identity copy audit begins only after emergence evidence exists"
	)
	_expect_copy_role(
		instruction_label,
		CombinedObservationController.COPY_ROLE_OBSERVATION_CUE,
		"identity instruction remains an observation cue"
	)
	_expect_copy_role(
		feedback_label,
		CombinedObservationController.COPY_ROLE_OBSERVATION_CUE,
		"identity feedback remains an observation cue"
	)
	_expect_copy_role(
		card_labels[0],
		CombinedObservationController.COPY_ROLE_POST_EVENT_CONCLUSION,
		"emergence conclusion appears only after its event"
	)
	for locked_card_index: int in range(1, card_labels.size()):
		_expect_copy_role(
			card_labels[locked_card_index],
			CombinedObservationController.COPY_ROLE_NEUTRAL_PLACEHOLDER,
			"future card %d remains neutral" % locked_card_index
		)
	_expect_true(
		not selected_worker_content.visible,
		"identity phase does not force or preselect a worker"
	)
	_expect_true(
		not name_edit.is_visible_in_tree(),
		"identity phase does not expose naming before selection"
	)
	_destroy_controller(controller)


func _test_card_projection_uses_frozen_snapshot_ids() -> void:
	var source_species: SpeciesData = (
		SPECIES_A_DATA.duplicate(true) as SpeciesData
	)
	var source_scenario: HabitatScenarioData = (
		_deep_duplicate_combined_scenario()
	)
	var frozen_card_id: StringName = &"custom_frozen_emergence_card"
	source_scenario.sequence_data.first_worker_observation_card_id = (
		frozen_card_id
	)
	var emergence_ticks: int = (
		source_species.pupa_duration_ticks
		- source_scenario.sequence_data.first_worker_initial_pupa_age_ticks
	)
	var controller: CombinedObservationController = (
		_create_controller_with_sources(source_species, source_scenario)
	)
	source_scenario.sequence_data.first_worker_observation_card_id = (
		&"post_ready_mutation"
	)

	_press_start_button(controller)
	for step_index: int in range(emergence_ticks):
		controller._process(SimulationClock.FIXED_STEP_SECONDS)
	var snapshot: GameSnapshot = controller._latest_snapshot
	var emergence_card: Label = controller.get_node(
		"%EmergenceCardLabel"
	) as Label
	_expect_string_name(
		snapshot.sequence.first_worker_observation_card_id,
		frozen_card_id,
		"the controller receives the card ID frozen into the sequence snapshot"
	)
	_expect_true(
		snapshot.observations.has_card(frozen_card_id),
		"emergence unlocks the configured frozen card ID"
	)
	_expect_true(
		not snapshot.observations.has_card(&"post_ready_mutation"),
		"post-ready Resource mutation cannot replace the unlocked card"
	)
	_expect_true(
		emergence_card != null and emergence_card.text.begins_with("✓"),
		"the ordinary card UI resolves unlock state through the snapshot ID"
	)
	_destroy_controller(controller)


func _test_real_viewport_path_reaches_summary_and_restarts() -> void:
	var controller: CombinedObservationController = _create_controller()
	var habitat_view: CombinedHabitatView = controller.get_node(
		"%CombinedHabitatView"
	) as CombinedHabitatView
	var stage_button: Button = controller.get_node(
		"%StageActionButton"
	) as Button
	var name_edit: LineEdit = controller.get_node(
		"%WorkerNameEdit"
	) as LineEdit
	var name_button: Button = controller.get_node(
		"%WorkerNameButton"
	) as Button
	var completion_panel: Control = controller.get_node(
		"%CompletionPanel"
	) as Control
	var restart_button: Button = controller.get_node(
		"%RestartButton"
	) as Button

	var initial: GameSnapshot = controller._latest_snapshot
	var first_worker_id: int = initial.sequence.first_worker_entity_id
	var first_worker_before: AntSnapshot = initial.colony.find_ant(
		first_worker_id
	)
	var stable_view: AntView = habitat_view.get_ant_view(first_worker_id)
	_expect_true(first_worker_before != null, "initial snapshot identifies the late pupa")
	_expect_int(
		first_worker_before.life_stage,
		AntModel.LifeStage.PUPA,
		"the persistent first worker begins as a late pupa"
	)
	_expect_true(stable_view != null, "the late pupa has its stable AntView")

	_press_start_button(controller)
	var emergence_ticks: int = (
		SPECIES_A_DATA.pupa_duration_ticks
		- COMBINED_SCENARIO_DATA.sequence_data
			.first_worker_initial_pupa_age_ticks
	)
	for step_index: int in range(emergence_ticks - 1):
		controller._process(SimulationClock.FIXED_STEP_SECONDS)
	_expect_int(
		controller._latest_snapshot.colony.find_ant(first_worker_id).life_stage,
		AntModel.LifeStage.PUPA,
		"the late pupa remains a pupa immediately before its Resource boundary"
	)
	controller._process(SimulationClock.FIXED_STEP_SECONDS)
	var emerged: GameSnapshot = controller._latest_snapshot
	_expect_int(
		emerged.sequence.phase,
		ScenarioSequenceSnapshot.Phase.IDENTITY_OBSERVATION,
		"emergence advances exactly to identity observation"
	)
	_expect_int(
		emerged.colony.find_ant(first_worker_id).life_stage,
		AntModel.LifeStage.WORKER,
		"the same entity becomes a worker at the exact boundary"
	)
	_expect_true(
		habitat_view.get_ant_view(first_worker_id) == stable_view,
		"pupa-to-worker projection reuses the exact AntView instance"
	)
	_expect_pre_event_guidance_roles(
		controller,
		"identity phase"
	)

	_click_control(habitat_view, stable_view.position)
	_expect_int(
		controller._player_annotation_state.get_selected_worker_id(),
		first_worker_id,
		"real habitat click selects the emerged first worker"
	)
	_settle_container_layout(controller)
	var before_name_signature: String = (
		SimulationSnapshotSignature.canonical_game_snapshot(
			controller._latest_snapshot
		)
	)
	name_edit.text = "Amber"
	_click_control(name_button)
	_expect_string(
		controller._player_annotation_state.get_worker_name(first_worker_id),
		"Amber",
		"real naming control stores the optional session name"
	)
	_expect_string(
		SimulationSnapshotSignature.canonical_game_snapshot(
			controller._latest_snapshot
		),
		before_name_signature,
		"selection and naming do not change the simulation snapshot"
	)

	var identity_tick: int = emerged.simulation_tick
	_click_control(stage_button)
	_expect_true(
		controller._latest_snapshot.sequence.continue_action_pending,
		"real continue button queues a high-level phase command"
	)
	_expect_int(
		controller._latest_snapshot.simulation_tick,
		identity_tick,
		"continue submission does not advance the fixed Tick"
	)
	controller._process(SimulationClock.FIXED_STEP_SECONDS)
	_expect_int(
		controller._latest_snapshot.sequence.phase,
		ScenarioSequenceSnapshot.Phase.HUMIDITY_OBSERVATION,
		"the queued continue command applies on the next fixed Tick"
	)
	_expect_pre_event_guidance_roles(
		controller,
		"initial humidity phase"
	)

	var carrying_seen: bool = false
	for humidity_step: int in range(1000):
		if (
			controller._latest_snapshot.colony.water_action_available
			or not controller._fatal_simulation_error.is_empty()
		):
			break
		for ant: AntSnapshot in controller._latest_snapshot.colony.ants:
			if (
				ant.life_stage == AntModel.LifeStage.WORKER
				and ant.carried_brood_id >= 0
			):
				carrying_seen = true
		controller._process(SimulationClock.FIXED_STEP_SECONDS)
	_expect_true(carrying_seen, "normal view path crosses a visible brood carry")
	_expect_true(
		controller._latest_snapshot.colony.water_action_available,
		"first completed relocation authoritatively opens watering"
	)
	_expect_true(
		habitat_view.get_ant_view(first_worker_id) == stable_view,
		"humidity relocation keeps the first worker AntView"
	)
	_expect_pre_event_guidance_roles(
		controller,
		"watering affordance"
	)

	for water_index: int in range(3):
		var before_water: GameSnapshot = controller._latest_snapshot
		var before_zone: HabitatZoneSnapshot = before_water.colony.find_zone(
			COMBINED_SCENARIO_DATA.humidity_adjustment_zone_id
		)
		var before_humidity: float = before_zone.humidity
		var submit_tick: int = before_water.simulation_tick
		_click_control(stage_button)
		_expect_true(
			controller._latest_snapshot.colony.water_action_pending,
			"water click %d queues one high-level action" % (water_index + 1)
		)
		_expect_float(
			controller._latest_snapshot.colony.find_zone(
				COMBINED_SCENARIO_DATA.humidity_adjustment_zone_id
			).humidity,
			before_humidity,
			"queued water click does not mutate humidity immediately"
		)
		controller._process(SimulationClock.FIXED_STEP_SECONDS)
		_expect_int(
			controller._latest_snapshot.simulation_tick,
			submit_tick + 1,
			"water click %d applies on the next Tick" % (water_index + 1)
		)
		_expect_float(
			controller._latest_snapshot.colony.find_zone(
				COMBINED_SCENARIO_DATA.humidity_adjustment_zone_id
			).humidity,
			minf(
				before_humidity
					+ COMBINED_SCENARIO_DATA.humidity_adjustment_amount,
				1.0
			),
			"applied water click uses the frozen configured amount"
		)

	for sugar_phase_step: int in range(1200):
		if (
			controller._latest_snapshot.sequence.phase
				!= ScenarioSequenceSnapshot.Phase.HUMIDITY_OBSERVATION
			or not controller._fatal_simulation_error.is_empty()
		):
			break
		controller._process(SimulationClock.FIXED_STEP_SECONDS)
	_expect_int(
		controller._latest_snapshot.sequence.phase,
		ScenarioSequenceSnapshot.Phase.SUGAR_FORAGING,
		"real water path reaches the sugar phase"
	)
	_expect_true(
		controller._latest_snapshot.observations.has_card(&"brood_humidity_response"),
		"stable humidity unlocks the second observation card"
	)
	_expect_pre_event_guidance_roles(
		controller,
		"pre-placement sugar phase"
	)

	_click_control(stage_button)
	_expect_true(controller._sugar_tool_armed, "real sugar button arms placement")
	_click_control(
		habitat_view,
		habitat_view.get_placement_zone_center()
	)
	_expect_true(
		controller._latest_snapshot.scenario.place_action_pending,
		"real foraging-area click queues configured sugar placement"
	)
	_expect_int(
		controller._latest_snapshot.colony.food_sources.size(),
		0,
		"queued placement does not create food on the submission Tick"
	)
	controller._process(SimulationClock.FIXED_STEP_SECONDS)
	_expect_int(
		controller._latest_snapshot.colony.food_sources.size(),
		1,
		"the next fixed Tick creates one configured food source"
	)
	_expect_pre_event_guidance_roles(
		controller,
		"post-placement evidence collection"
	)

	var carried_sugar_seen: bool = false
	for summary_step: int in range(1000):
		if (
			controller._latest_snapshot.sequence.completed
			or not controller._fatal_simulation_error.is_empty()
		):
			break
		var worker: AntSnapshot = controller._latest_snapshot.colony.find_ant(
			first_worker_id
		)
		if (
			worker != null
			and worker.foraging_task != null
			and worker.foraging_task.carried_portions > 0
		):
			carried_sugar_seen = true
		controller._process(SimulationClock.FIXED_STEP_SECONDS)

	(controller.get_node("%JournalButton") as Button).pressed.emit()
	(controller.get_node("%InferenceButton1") as Button).pressed.emit()
	controller._process(SimulationClock.FIXED_STEP_SECONDS)
	_expect_int(
		controller._latest_snapshot.campaign.completed_chapter_count,
		1,
		"the real journal path completes the first campaign chapter"
	)
	(controller.get_node("%InferenceButton1") as Button).pressed.emit()
	controller._process(SimulationClock.FIXED_STEP_SECONDS)
	_expect_true(
		controller._latest_snapshot.campaign.completed,
		"the real journal path completes the campaign inference set"
	)
	(controller.get_node("%JournalCloseButton") as Button).pressed.emit()

	var completed: GameSnapshot = controller._latest_snapshot
	_expect_true(carried_sugar_seen, "normal view path crosses carried sugar")
	_expect_int(
		completed.sequence.phase,
		ScenarioSequenceSnapshot.Phase.OBSERVATION_SUMMARY,
		"real UI path reaches the observation summary"
	)
	for card_id: StringName in [
		&"first_worker_emerged",
		&"brood_humidity_response",
		&"sugar_return_and_share",
	]:
		_expect_true(
			completed.observations.has_card(card_id),
			"summary contains card %s" % card_id
		)
	_expect_true(
		completion_panel.visible,
		"completed snapshot reveals the summary panel"
	)
	_expect_copy_role(
		controller.get_node("%InstructionLabel") as Label,
		CombinedObservationController.COPY_ROLE_POST_EVENT_CONCLUSION,
		"summary instruction may state the completed conclusion"
	)
	_expect_copy_role(
		controller.get_node("%FeedbackLabel") as Label,
		CombinedObservationController.COPY_ROLE_POST_EVENT_CONCLUSION,
		"summary feedback may state the completed conclusion"
	)
	_expect_true(
		habitat_view.get_ant_view(first_worker_id) == stable_view,
		"the same first worker AntView reaches the final summary"
	)
	_expect_int(
		controller._player_annotation_state.get_selected_worker_id(),
		first_worker_id,
		"worker selection persists through all five phases"
	)
	_expect_string(
		controller._player_annotation_state.get_worker_name(first_worker_id),
		"Amber",
		"worker name persists through all five phases"
	)

	_click_control(restart_button)
	var restarted: GameSnapshot = controller._latest_snapshot
	_expect_int(restarted.simulation_tick, 0, "restart returns to Tick zero")
	_expect_int(
		restarted.sequence.phase,
		ScenarioSequenceSnapshot.Phase.FOUNDING_PRELUDE,
		"restart returns to the founding prelude"
	)
	_expect_int(
		restarted.observations.unlocked_card_ids.size(),
		0,
		"restart clears all observation cards"
	)
	_expect_int(
		restarted.colony.food_sources.size(),
		0,
		"restart removes the prior food source"
	)
	_expect_int(
		controller._player_annotation_state.get_selected_worker_id(),
		-1,
		"restart clears the selected worker"
	)
	_expect_string(
		controller._player_annotation_state.get_worker_name(first_worker_id),
		"",
		"restart clears the worker name"
	)
	_expect_true(
		habitat_view.get_ant_view(first_worker_id) != stable_view,
		"restart discards every prior AntView instance"
	)
	_expect_int(
		habitat_view.get_ant_view_count(),
		COMBINED_SCENARIO_DATA.initial_brood_count + 1,
		"restart creates exactly one clean view per initial ant"
	)
	_expect_int(
		controller._simulation_clock.get_speed_multiplier(),
		SimulationClock.NORMAL_SPEED,
		"restart restores 1x"
	)
	_expect_true(
		controller._simulation_clock.is_paused(),
		"restart returns to the frozen preparation clock"
	)
	_expect_true(
		controller.is_preparation_gate_active(),
		"restart returns to the preparation gate"
	)
	_expect_true(
		(controller.get_node("%PreparationGate") as Control).visible,
		"restart makes the preparation gate visible again"
	)
	_press_start_button(controller)
	_expect_true(
		not controller.is_preparation_gate_active(),
		"restarted session can begin through the same start affordance"
	)
	controller._process(SimulationClock.FIXED_STEP_SECONDS)
	_expect_int(
		controller._latest_snapshot.simulation_tick,
		1,
		"restarted session advances normally after its start affordance"
	)

	_destroy_controller(controller)


func _test_pause_and_f3_freeze_projection() -> void:
	var controller: CombinedObservationController = _create_controller()
	var habitat_view: CombinedHabitatView = controller.get_node(
		"%CombinedHabitatView"
	) as CombinedHabitatView
	var pause_button: Button = controller.get_node("%PauseButton") as Button
	var debug_panel: Control = controller.get_node("%DebugPanel") as Control
	var first_ant_id: int = (
		controller._latest_snapshot.sequence.first_worker_entity_id
	)
	var ant_view: AntView = habitat_view.get_ant_view(first_ant_id)

	_press_start_button(controller)
	controller._process(SimulationClock.FIXED_STEP_SECONDS * 2.0)
	_click_control(pause_button)
	var paused_tick: int = controller._latest_snapshot.simulation_tick
	var paused_position: Vector2 = ant_view.position
	_expect_true(
		controller._simulation_clock.is_paused(),
		"menu button pauses the fixed clock"
	)
	_expect_true(
		controller.is_pause_menu_open(),
		"menu button exposes the pause menu"
	)
	_expect_true(
		habitat_view.are_visuals_paused(),
		"real pause button freezes the view interpolation"
	)
	controller._process(2.0)
	_expect_int(
		controller._latest_snapshot.simulation_tick,
		paused_tick,
		"paused processing does not advance simulation"
	)
	_expect_vector2(
		ant_view.position,
		paused_position,
		"paused processing does not move the projected late pupa"
	)

	_push_key(controller.get_viewport(), KEY_F3)
	_expect_true(debug_panel.visible, "F3 opens the combined diagnostic layer")
	_push_key(controller.get_viewport(), KEY_F3)
	_expect_true(not debug_panel.visible, "second F3 closes the diagnostic layer")
	_destroy_controller(controller)


func _expect_pre_event_guidance_roles(
	controller: CombinedObservationController,
	context: String
) -> void:
	_expect_role_in(
		controller.get_node("%InstructionLabel") as Label,
		[
			CombinedObservationController.COPY_ROLE_OBSERVATION_CUE,
			CombinedObservationController.COPY_ROLE_ACTION_AFFORDANCE,
		],
		"%s instruction does not state a conclusion" % context
	)
	_expect_role_in(
		controller.get_node("%FeedbackLabel") as Label,
		[
			CombinedObservationController.COPY_ROLE_OBSERVATION_CUE,
			CombinedObservationController.COPY_ROLE_ACTION_AFFORDANCE,
		],
		"%s feedback does not state a conclusion" % context
	)


func _expect_copy_role(
	label: Label,
	expected: StringName,
	message: String
) -> void:
	var actual: StringName = StringName(
		label.get_meta(
			CombinedObservationController.COPY_ROLE_META_KEY,
			&""
		)
	)
	_expect_string_name(actual, expected, message)


func _expect_role_in(
	label: Label,
	allowed_roles: Array[StringName],
	message: String
) -> void:
	_assertion_count += 1
	var actual: StringName = StringName(
		label.get_meta(
			CombinedObservationController.COPY_ROLE_META_KEY,
			&""
		)
	)
	if allowed_roles.has(actual):
		return
	_record_failure(message, str(allowed_roles), String(actual))


func _press_start_button(controller: CombinedObservationController) -> void:
	var start_button: Button = controller.get_node(
		"%StartObservationButton"
	) as Button
	start_button.pressed.emit()


func _create_controller() -> CombinedObservationController:
	return _create_controller_with_sources(
		SPECIES_A_DATA,
		COMBINED_SCENARIO_DATA
	)


func _create_controller_with_sources(
	species_data: SpeciesData,
	scenario_data: HabitatScenarioData
) -> CombinedObservationController:
	var controller: CombinedObservationController = (
		COMBINED_SCENE.instantiate() as CombinedObservationController
	)
	controller.species_data_source = species_data
	controller.habitat_scenario_data_source = scenario_data
	_scene_root.add_child(controller)
	controller.set_anchors_preset(Control.PRESET_TOP_LEFT)
	controller.position = Vector2.ZERO
	controller.size = Vector2(1280.0, 720.0)
	_settle_container_layout(controller)
	return controller


func _deep_duplicate_combined_scenario() -> HabitatScenarioData:
	var duplicate: HabitatScenarioData = (
		COMBINED_SCENARIO_DATA.duplicate(true) as HabitatScenarioData
	)
	var duplicated_zones: Array[HabitatZoneData] = []
	for source_zone: HabitatZoneData in COMBINED_SCENARIO_DATA.zones:
		duplicated_zones.append(
			source_zone.duplicate(true) as HabitatZoneData
		)
	duplicate.zones = duplicated_zones
	duplicate.sequence_data = (
		COMBINED_SCENARIO_DATA.sequence_data.duplicate(true)
		as ScenarioSequenceData
	)
	duplicate.foraging_data = (
		COMBINED_SCENARIO_DATA.foraging_data.duplicate(true)
		as ForagingData
	)
	return duplicate


func _destroy_controller(controller: CombinedObservationController) -> void:
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


func _settle_container_layout(node: Node) -> void:
	for pass_index: int in range(4):
		_force_container_layout(node)


func _expect_true(actual: bool, message: String) -> void:
	_assertion_count += 1
	if actual:
		return
	_record_failure(message, "true", "false")


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


func _expect_string(actual: String, expected: String, message: String) -> void:
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


func _expect_vector2(
	actual: Vector2,
	expected: Vector2,
	message: String
) -> void:
	_assertion_count += 1
	if actual.is_equal_approx(expected):
		return
	_record_failure(message, str(expected), str(actual))


func _record_failure(
	message: String,
	expected: String,
	actual: String
) -> void:
	_failure_count += 1
	printerr("  %s - expected %s, got %s" % [message, expected, actual])
