class_name CombinedObservationController
extends Control

signal application_exit_requested
signal save_profile_requested
signal return_to_title_requested
signal settings_changed(settings: DemoSettingsState)

const SPECIES_A_DATA: SpeciesData = preload(
	"res://data/species/species_a.tres"
)
const COMBINED_SCENARIO_DATA: HabitatScenarioData = preload(
	"res://data/habitats/combined_observation_slice.tres"
)
const COPY_ROLE_META_KEY: StringName = &"evidence_copy_role"
const COPY_ROLE_OBSERVATION_CUE: StringName = &"observation_cue"
const COPY_ROLE_ACTION_AFFORDANCE: StringName = &"action_affordance"
const COPY_ROLE_NEUTRAL_PLACEHOLDER: StringName = &"neutral_placeholder"
const COPY_ROLE_POST_EVENT_CONCLUSION: StringName = &"post_event_conclusion"
const COPY_ROLE_SYSTEM_STATUS: StringName = &"system_status"
const COPY_ROLE_ERROR: StringName = &"error"

var _simulation_clock: SimulationClock
var _colony_simulation: ColonySimulation
var _latest_snapshot: GameSnapshot
var _player_annotation_state: PlayerAnnotationState
var _sugar_tool_armed: bool = false
var _fatal_simulation_error: String = ""
var _preparation_gate_active: bool = true
var _pause_menu_open: bool = false
var _paused_before_menu: bool = true
var _demo_settings_state: DemoSettingsState
var _ui_scale_theme: Theme

# Tests may replace these before _ready(). Both Resources are consumed only
# while ColonySimulation freezes the configuration at session construction.
var species_data_source: SpeciesData = SPECIES_A_DATA
var habitat_scenario_data_source: HabitatScenarioData = (
	COMBINED_SCENARIO_DATA
)
var exit_application_on_request: bool = true
var provided_settings_state: DemoSettingsState
var shell_managed: bool = false

@onready var _title_label: Label = %Title
@onready var _status_label: Label = %StatusLabel
@onready var _phase_label: Label = %PhaseLabel
@onready var _habitat_view: CombinedHabitatView = %CombinedHabitatView
@onready var _worker_observation_panel: WorkerObservationPanel = (
	%WorkerIdentityPanel
)
@onready var _instruction_label: Label = %InstructionLabel
@onready var _feedback_label: Label = %FeedbackLabel
@onready var _tool_heading: Label = %ToolHeading
@onready var _stage_action_button: Button = %StageActionButton
@onready var _stage_controls: VBoxContainer = %StageControls
@onready var _emergence_card_label: Label = %EmergenceCardLabel
@onready var _humidity_card_label: Label = %HumidityCardLabel
@onready var _sugar_card_label: Label = %SugarCardLabel
@onready var _completion_panel: VBoxContainer = %CompletionPanel
@onready var _completion_label: Label = %CompletionLabel
@onready var _restart_button: Button = %RestartButton
@onready var _debug_panel: PanelContainer = %DebugPanel
@onready var _debug_label: Label = %DebugLabel
@onready var _pause_button: Button = %PauseButton
@onready var _speed_1x_button: Button = %Speed1xButton
@onready var _speed_4x_button: Button = %Speed4xButton
@onready var _speed_16x_button: Button = %Speed16xButton
@onready var _preparation_gate: Control = %PreparationGate
@onready var _start_observation_button: Button = %StartObservationButton
@onready var _observation_heading: Label = %ObservationHeading
@onready var _completion_heading: Label = %CompletionHeading
@onready var _footer_label: Label = %Footer
@onready var _debug_title: Label = %DebugTitle
@onready var _preparation_heading: Label = %PreparationHeading
@onready var _preparation_description: Label = %PreparationDescription
@onready var _pause_menu: Control = %PauseMenu
@onready var _pause_heading: Label = %PauseHeading
@onready var _resume_button: Button = %ResumeButton
@onready var _pause_restart_button: Button = %PauseRestartButton
@onready var _save_game_button: Button = %SaveGameButton
@onready var _return_to_title_button: Button = %ReturnToTitleButton
@onready var _pause_save_status: Label = %PauseSaveStatus
@onready var _display_heading: Label = %DisplayHeading
@onready var _resolution_label: Label = %ResolutionLabel
@onready var _resolution_option: OptionButton = %ResolutionOption
@onready var _fullscreen_check: CheckButton = %FullscreenCheck
@onready var _language_label: Label = %LanguageLabel
@onready var _language_option: OptionButton = %LanguageOption
@onready var _ui_scale_label: Label = %UIScaleLabel
@onready var _ui_scale_option: OptionButton = %UIScaleOption
@onready var _reduced_motion_check: CheckButton = %ReducedMotionCheck
@onready var _master_volume_label: Label = %MasterVolumeLabel
@onready var _master_volume_slider: HSlider = %MasterVolumeSlider
@onready var _exit_button: Button = %ExitButton


func _ready() -> void:
	_initialize_demo_settings()
	_simulation_clock = SimulationClock.new()
	_player_annotation_state = PlayerAnnotationState.new()
	_colony_simulation = ColonySimulation.new(
		species_data_source,
		habitat_scenario_data_source
	)
	if not _colony_simulation.is_ready():
		_set_fatal_simulation_error(
			_colony_simulation.get_configuration_error()
		)
		return

	_connect_clock()
	_habitat_view.worker_selection_requested.connect(
		_on_worker_selection_requested
	)
	_habitat_view.sugar_drop_requested.connect(
		_on_sugar_drop_requested
	)
	_habitat_view.sugar_tool_cancel_requested.connect(
		_on_sugar_tool_cancel_requested
	)
	_worker_observation_panel.name_commit_requested.connect(
		_on_worker_name_commit_requested
	)
	_pause_button.pressed.connect(_on_pause_button_pressed)
	_resume_button.pressed.connect(_on_resume_button_pressed)
	_pause_restart_button.pressed.connect(
		_on_pause_restart_button_pressed
	)
	_save_game_button.pressed.connect(_on_save_game_button_pressed)
	_return_to_title_button.pressed.connect(
		_on_return_to_title_button_pressed
	)
	_resolution_option.item_selected.connect(
		_on_resolution_selected
	)
	_fullscreen_check.toggled.connect(_on_fullscreen_toggled)
	_language_option.item_selected.connect(_on_language_selected)
	_ui_scale_option.item_selected.connect(_on_ui_scale_selected)
	_reduced_motion_check.toggled.connect(_on_reduced_motion_toggled)
	_master_volume_slider.value_changed.connect(_on_master_volume_changed)
	_exit_button.pressed.connect(_on_exit_button_pressed)
	_stage_action_button.pressed.connect(_on_stage_action_button_pressed)
	_restart_button.pressed.connect(_on_restart_button_pressed)
	_start_observation_button.pressed.connect(
		_on_start_observation_button_pressed
	)
	_speed_1x_button.pressed.connect(
		_on_speed_button_pressed.bind(SimulationClock.NORMAL_SPEED)
	)
	_speed_4x_button.pressed.connect(
		_on_speed_button_pressed.bind(SimulationClock.FAST_SPEED)
	)
	_speed_16x_button.pressed.connect(
		_on_speed_button_pressed.bind(SimulationClock.VERY_FAST_SPEED)
	)

	_refresh_localized_ui()
	_exit_button.visible = not shell_managed
	_simulation_clock.set_paused(true)
	_apply_game_snapshot()
	_enter_preparation_gate()


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready():
		_refresh_localized_ui()


func _process(delta: float) -> void:
	if _simulation_clock == null or not _fatal_simulation_error.is_empty():
		return
	if _preparation_gate_active:
		return
	_simulation_clock.advance(delta)
	if _fatal_simulation_error.is_empty():
		_habitat_view.set_interpolation_alpha(
			_simulation_clock.get_interpolation_alpha()
		)


func _input(event: InputEvent) -> void:
	var key_event: InputEventKey = event as InputEventKey
	if key_event == null or not key_event.pressed or key_event.echo:
		return
	if key_event.keycode == KEY_F3 and _debug_controls_available():
		_toggle_debug_panel()
		get_viewport().set_input_as_handled()
	elif key_event.keycode == KEY_ESCAPE:
		if _pause_menu_open:
			_close_pause_menu(false)
		elif _sugar_tool_armed:
			_cancel_sugar_tool(tr("FEEDBACK_SUGAR_CANCELLED"))
		else:
			_open_pause_menu()
		get_viewport().set_input_as_handled()


func _on_simulation_tick_requested(
	tick_index: int,
	_tick_seconds: float
) -> void:
	if not _colony_simulation.advance_tick(tick_index):
		_set_fatal_simulation_error(
			tr("ERROR_NONCONTIGUOUS_TICK") % tick_index
		)
		return
	_apply_game_snapshot()


func _on_pause_button_pressed() -> void:
	_open_pause_menu()


func _on_resume_button_pressed() -> void:
	_close_pause_menu(true)


func _on_pause_restart_button_pressed() -> void:
	_pause_menu_open = false
	_pause_menu.visible = false
	_restart_session()


func _on_save_game_button_pressed() -> void:
	if (
		_preparation_gate_active
		or not _fatal_simulation_error.is_empty()
		or _simulation_clock == null
	):
		return
	save_profile_requested.emit()


func _on_return_to_title_button_pressed() -> void:
	if _simulation_clock == null:
		return
	_simulation_clock.set_paused(true)
	_habitat_view.set_visuals_paused(true)
	return_to_title_requested.emit()


func _on_resolution_selected(index: int) -> void:
	if not _demo_settings_state.select_resolution(index):
		return
	if not _demo_settings_state.is_fullscreen_requested():
		_apply_windowed_resolution()
	_emit_settings_changed()


func _on_fullscreen_toggled(enabled: bool) -> void:
	_demo_settings_state.set_fullscreen_requested(enabled)
	_apply_fullscreen_mode()
	_emit_settings_changed()


func _on_language_selected(index: int) -> void:
	if not _demo_settings_state.select_locale(index):
		return
	TranslationServer.set_locale(_demo_settings_state.get_locale_code())
	_refresh_localized_ui()
	_emit_settings_changed()


func _on_ui_scale_selected(index: int) -> void:
	if not _demo_settings_state.select_ui_scale(index):
		return
	_apply_ui_scale()
	_emit_settings_changed()


func _on_reduced_motion_toggled(enabled: bool) -> void:
	_demo_settings_state.set_reduced_motion(enabled)
	_apply_reduced_motion()
	_emit_settings_changed()


func _on_master_volume_changed(value: float) -> void:
	if not _demo_settings_state.set_master_volume(value):
		return
	_apply_master_volume()
	_emit_settings_changed()


func _on_exit_button_pressed() -> void:
	application_exit_requested.emit()
	if exit_application_on_request:
		get_tree().quit()


func _on_stage_action_button_pressed() -> void:
	if (
		_preparation_gate_active
		or _latest_snapshot == null
		or _stage_action_button.disabled
	):
		return
	match _latest_snapshot.sequence.phase:
		ScenarioSequenceSnapshot.Phase.IDENTITY_OBSERVATION:
			if _colony_simulation.submit_continue_observation_action():
				_apply_game_snapshot()
				_set_copy(
					_feedback_label,
					tr("FEEDBACK_CONTINUE_SUBMITTED"),
					COPY_ROLE_ACTION_AFFORDANCE
				)
		ScenarioSequenceSnapshot.Phase.HUMIDITY_OBSERVATION:
			if _colony_simulation.submit_water_action():
				_apply_game_snapshot()
				_set_copy(
					_feedback_label,
					tr("FEEDBACK_WATER_SUBMITTED"),
					COPY_ROLE_ACTION_AFFORDANCE
				)
		ScenarioSequenceSnapshot.Phase.SUGAR_FORAGING:
			if _sugar_tool_armed:
				_cancel_sugar_tool(tr("FEEDBACK_SUGAR_CANCELLED"))
			elif _can_arm_sugar_tool():
				_set_sugar_tool_armed(true)
				_set_copy(
					_feedback_label,
					tr("FEEDBACK_SUGAR_AIM"),
					COPY_ROLE_ACTION_AFFORDANCE
				)
				_update_control_state()


func _on_sugar_drop_requested() -> void:
	if (
		not _sugar_tool_armed
		or _latest_snapshot == null
		or not _latest_snapshot.scenario.place_action_available
		or not _colony_simulation.submit_place_sugar_action()
	):
		_cancel_sugar_tool(tr("FEEDBACK_SUGAR_UNAVAILABLE"))
		return
	_set_sugar_tool_armed(false)
	_apply_game_snapshot()
	_set_copy(
		_feedback_label,
		tr("FEEDBACK_SUGAR_SUBMITTED"),
		COPY_ROLE_ACTION_AFFORDANCE
	)


func _on_sugar_tool_cancel_requested() -> void:
	if _sugar_tool_armed:
		_cancel_sugar_tool(tr("FEEDBACK_SUGAR_WRONG_ZONE"))


func _on_worker_selection_requested(entity_id: int) -> void:
	if (
		_latest_snapshot == null
		or not _player_annotation_state.select_worker(
			entity_id,
			_latest_snapshot.colony
		)
	):
		return
	_habitat_view.set_selected_worker_id(
		_player_annotation_state.get_selected_worker_id()
	)
	_update_worker_observation_panel()
	_update_player_guidance()


func _on_worker_name_commit_requested(worker_name: String) -> void:
	if _player_annotation_state.set_selected_worker_name(worker_name):
		_update_worker_observation_panel()
		_update_player_guidance()


func _on_restart_button_pressed() -> void:
	if (
		_latest_snapshot == null
		or not _latest_snapshot.sequence.completed
		or _restart_button.disabled
	):
		return
	_restart_session()


func _on_start_observation_button_pressed() -> void:
	if (
		not _preparation_gate_active
		or _pause_menu_open
		or not _fatal_simulation_error.is_empty()
		or _simulation_clock == null
	):
		return
	_preparation_gate_active = false
	_preparation_gate.visible = false
	_start_observation_button.disabled = true
	_simulation_clock.set_speed_multiplier(SimulationClock.NORMAL_SPEED)
	_simulation_clock.set_paused(false)
	_habitat_view.set_visuals_paused(false)
	_update_control_state()
	_update_debug_panel()


func _on_speed_button_pressed(multiplier: int) -> void:
	if _preparation_gate_active or _pause_menu_open:
		return
	_simulation_clock.set_speed_multiplier(multiplier)
	_update_control_state()
	_update_debug_panel()


func _toggle_debug_panel() -> void:
	if not _debug_controls_available():
		_debug_panel.visible = false
		return
	_debug_panel.visible = not _debug_panel.visible
	_update_control_state()
	_update_debug_panel()


func _apply_game_snapshot() -> void:
	_latest_snapshot = _colony_simulation.create_game_snapshot()
	if (
		_latest_snapshot == null
		or _latest_snapshot.colony == null
		or _latest_snapshot.scenario == null
		or _latest_snapshot.observations == null
		or _latest_snapshot.sequence == null
	):
		_set_fatal_simulation_error(
			tr("ERROR_INCOMPLETE_SNAPSHOT")
		)
		return

	_player_annotation_state.reconcile_entities(_latest_snapshot.colony)
	_player_annotation_state.consume_events(
		_latest_snapshot.observations.events
	)
	if not _habitat_view.apply_snapshot(_latest_snapshot):
		_set_fatal_simulation_error(tr("ERROR_VIEW_REJECTED"))
		return
	_habitat_view.set_selected_worker_id(
		_player_annotation_state.get_selected_worker_id()
	)

	if (
		_sugar_tool_armed
		and not _latest_snapshot.scenario.place_action_available
	):
		_set_sugar_tool_armed(false)

	_update_worker_observation_panel()
	_update_observation_cards()
	_update_player_guidance()
	_update_control_state()
	_update_debug_panel()


func _update_worker_observation_panel() -> void:
	var selected_worker_id: int = (
		_player_annotation_state.get_selected_worker_id()
	)
	if _latest_snapshot == null or selected_worker_id < 0:
		_worker_observation_panel.reset_panel()
		return
	var worker: AntSnapshot = _latest_snapshot.colony.find_ant(
		selected_worker_id
	)
	if worker == null or worker.life_stage != AntModel.LifeStage.WORKER:
		_worker_observation_panel.reset_panel()
		return
	_worker_observation_panel.apply_selection(
		worker,
		_player_annotation_state.get_worker_name(selected_worker_id),
		_player_annotation_state.get_recent_events(selected_worker_id)
	)


func _update_observation_cards() -> void:
	if _latest_snapshot == null:
		return
	_set_card_copy(
		_emergence_card_label,
		_latest_snapshot.observations.has_card(
			_latest_snapshot.sequence.first_worker_observation_card_id
		),
		"UI_CARD_FIRST_WORKER"
	)
	_set_card_copy(
		_humidity_card_label,
		_latest_snapshot.observations.has_card(
			_latest_snapshot.sequence.brood_humidity_observation_card_id
		),
		"UI_CARD_HUMIDITY"
	)
	_set_card_copy(
		_sugar_card_label,
		_latest_snapshot.observations.has_card(
			_latest_snapshot.sequence.sugar_foraging_observation_card_id
		),
		"UI_CARD_SUGAR"
	)


func _update_player_guidance() -> void:
	if _latest_snapshot == null:
		return
	var phase: ScenarioSequenceSnapshot.Phase = _latest_snapshot.sequence.phase
	_phase_label.text = _get_phase_heading(phase)
	_set_completion_state(
		phase == ScenarioSequenceSnapshot.Phase.OBSERVATION_SUMMARY
	)

	match phase:
		ScenarioSequenceSnapshot.Phase.FOUNDING_PRELUDE:
			_tool_heading.text = tr("TOOL_FOUNDING")
			_set_copy(
				_instruction_label,
				tr("GUIDE_FOUNDING_INSTRUCTION"),
				COPY_ROLE_OBSERVATION_CUE
			)
			_set_copy(
				_feedback_label,
				tr("GUIDE_FOUNDING_FEEDBACK"),
				COPY_ROLE_OBSERVATION_CUE
			)
		ScenarioSequenceSnapshot.Phase.IDENTITY_OBSERVATION:
			_tool_heading.text = tr("TOOL_IDENTITY")
			_set_copy(
				_instruction_label,
				tr("GUIDE_IDENTITY_INSTRUCTION"),
				COPY_ROLE_OBSERVATION_CUE
			)
			_set_copy(
				_feedback_label,
				tr("GUIDE_IDENTITY_FEEDBACK"),
				COPY_ROLE_OBSERVATION_CUE
			)
		ScenarioSequenceSnapshot.Phase.HUMIDITY_OBSERVATION:
			_tool_heading.text = tr("TOOL_HUMIDITY")
			if not _latest_snapshot.colony.water_action_unlocked:
				_set_copy(
					_instruction_label,
					tr("GUIDE_HUMIDITY_LOCKED_INSTRUCTION"),
					COPY_ROLE_OBSERVATION_CUE
				)
				_set_copy(
					_feedback_label,
					tr("GUIDE_HUMIDITY_LOCKED_FEEDBACK"),
					COPY_ROLE_OBSERVATION_CUE
				)
			elif _latest_snapshot.colony.water_target_comfortable:
				_set_copy(
					_instruction_label,
					tr("GUIDE_HUMIDITY_COMFORTABLE_INSTRUCTION"),
					COPY_ROLE_OBSERVATION_CUE
				)
				_set_copy(
					_feedback_label,
					tr("GUIDE_HUMIDITY_COMFORTABLE_FEEDBACK"),
					COPY_ROLE_OBSERVATION_CUE
				)
			else:
				_set_copy(
					_instruction_label,
					tr("GUIDE_HUMIDITY_ACTION_INSTRUCTION"),
					COPY_ROLE_OBSERVATION_CUE
				)
				_set_copy(
					_feedback_label,
					tr("GUIDE_HUMIDITY_ACTION_FEEDBACK"),
					COPY_ROLE_ACTION_AFFORDANCE
				)
		ScenarioSequenceSnapshot.Phase.SUGAR_FORAGING:
			_tool_heading.text = tr("TOOL_SUGAR")
			if _latest_snapshot.scenario.place_action_count == 0:
				_set_copy(
					_instruction_label,
					tr("GUIDE_SUGAR_EMPTY_INSTRUCTION"),
					COPY_ROLE_OBSERVATION_CUE
				)
				if not _sugar_tool_armed:
					_set_copy(
						_feedback_label,
						tr("GUIDE_SUGAR_EMPTY_FEEDBACK"),
						COPY_ROLE_ACTION_AFFORDANCE
					)
			else:
				_set_copy(
					_instruction_label,
					tr("GUIDE_SUGAR_PLACED_INSTRUCTION"),
					COPY_ROLE_OBSERVATION_CUE
				)
				_set_copy(
					_feedback_label,
					tr("GUIDE_SUGAR_PLACED_FEEDBACK"),
					COPY_ROLE_OBSERVATION_CUE
				)
		ScenarioSequenceSnapshot.Phase.OBSERVATION_SUMMARY:
			_tool_heading.text = tr("TOOL_SUMMARY")
			_set_copy(
				_instruction_label,
				tr("GUIDE_SUMMARY_INSTRUCTION"),
				COPY_ROLE_POST_EVENT_CONCLUSION
			)
			_set_copy(
				_feedback_label,
				tr("GUIDE_SUMMARY_FEEDBACK"),
				COPY_ROLE_POST_EVENT_CONCLUSION
			)
			_completion_label.text = _build_completion_summary()


func _update_control_state() -> void:
	if not _fatal_simulation_error.is_empty():
		_status_label.text = tr("STATUS_ERROR")
		for button: Button in [
			_pause_button,
			_stage_action_button,
			_restart_button,
			_save_game_button,
			_speed_1x_button,
			_speed_4x_button,
			_speed_16x_button,
		]:
			button.disabled = true
		return
	if _latest_snapshot == null:
		return

	var speed_multiplier: int = _simulation_clock.get_speed_multiplier()
	var paused: bool = _simulation_clock.is_paused()
	var completed: bool = _latest_snapshot.sequence.completed
	if _preparation_gate_active:
		_set_copy(
			_status_label,
			tr("STATUS_PREPARING"),
			COPY_ROLE_SYSTEM_STATUS
		)
		_pause_button.text = tr("UI_MENU")
		for gated_button: Button in [
			_stage_action_button,
			_restart_button,
			_save_game_button,
			_speed_1x_button,
			_speed_4x_button,
			_speed_16x_button,
		]:
			gated_button.disabled = true
		_pause_button.disabled = _pause_menu_open
		_pause_restart_button.disabled = true
		_return_to_title_button.disabled = false
		_start_observation_button.disabled = _pause_menu_open
		return
	_set_copy(
		_status_label,
		(
			tr("STATUS_PAUSED") % speed_multiplier
			if paused
			else (
				tr("STATUS_COMPLETE") % speed_multiplier
				if completed
				else tr("STATUS_OBSERVING") % speed_multiplier
			)
		),
		COPY_ROLE_SYSTEM_STATUS
	)
	_pause_button.text = tr("UI_MENU")
	_pause_button.disabled = _pause_menu_open
	_pause_restart_button.disabled = false
	_save_game_button.disabled = false
	_return_to_title_button.disabled = false
	_speed_1x_button.disabled = (
		_pause_menu_open
		or speed_multiplier == SimulationClock.NORMAL_SPEED
	)
	_speed_4x_button.disabled = (
		_pause_menu_open
		or speed_multiplier == SimulationClock.FAST_SPEED
	)
	_speed_16x_button.disabled = (
		_pause_menu_open
		or speed_multiplier == SimulationClock.VERY_FAST_SPEED
	)

	match _latest_snapshot.sequence.phase:
		ScenarioSequenceSnapshot.Phase.FOUNDING_PRELUDE:
			_stage_action_button.text = tr("ACTION_WAIT_FIRST_WORKER")
			_stage_action_button.disabled = true
		ScenarioSequenceSnapshot.Phase.IDENTITY_OBSERVATION:
			_stage_action_button.text = tr("ACTION_CONTINUE_ENVIRONMENT")
			_stage_action_button.disabled = (
				paused or _pause_menu_open
				or not _latest_snapshot.sequence.continue_action_available
			)
		ScenarioSequenceSnapshot.Phase.HUMIDITY_OBSERVATION:
			_stage_action_button.text = (
				tr("ACTION_WATER_PENDING")
				if _latest_snapshot.colony.water_action_pending
				else (
					tr("ACTION_CONTINUE_RELOCATION")
					if _latest_snapshot.colony.water_target_comfortable
					else tr("ACTION_WATER_NURSERY")
				)
			)
			_stage_action_button.disabled = (
				paused
				or _pause_menu_open
				or not _latest_snapshot.colony.water_action_available
			)
		ScenarioSequenceSnapshot.Phase.SUGAR_FORAGING:
			_stage_action_button.text = (
				tr("ACTION_CANCEL_PLACEMENT")
				if _sugar_tool_armed
				else tr("ACTION_PREPARE_SUGAR")
			)
			_stage_action_button.disabled = (
				paused
				or _pause_menu_open
				or (
					not _sugar_tool_armed
					and not _can_arm_sugar_tool()
				)
			)
		ScenarioSequenceSnapshot.Phase.OBSERVATION_SUMMARY:
			_stage_action_button.disabled = true

	_restart_button.disabled = not completed


func _initialize_demo_settings() -> void:
	var initial_window_size: Vector2i = Vector2i(1280, 720)
	var initial_fullscreen: bool = false
	if DisplayServer.get_name().to_lower() != "headless":
		initial_window_size = DisplayServer.window_get_size()
		var window_mode: DisplayServer.WindowMode = (
			DisplayServer.window_get_mode()
		)
		initial_fullscreen = window_mode in [
			DisplayServer.WINDOW_MODE_FULLSCREEN,
			DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN,
		]
	_demo_settings_state = provided_settings_state
	if _demo_settings_state == null:
		_demo_settings_state = DemoSettingsState.new(
			TranslationServer.get_locale(),
			initial_window_size,
			initial_fullscreen
		)
	TranslationServer.set_locale(_demo_settings_state.get_locale_code())
	_resolution_option.clear()
	_resolution_option.add_item("1280 × 720")
	_resolution_option.add_item("1920 × 1080")
	_resolution_option.select(_demo_settings_state.get_resolution_index())
	_language_option.clear()
	_language_option.add_item("")
	_language_option.add_item("")
	_language_option.select(_demo_settings_state.get_locale_index())
	_ui_scale_option.clear()
	for scale_factor: float in DemoSettingsState.UI_SCALE_FACTORS:
		_ui_scale_option.add_item("%d%%" % int(scale_factor * 100.0))
	_ui_scale_option.select(_demo_settings_state.get_ui_scale_index())
	_fullscreen_check.set_pressed_no_signal(
		_demo_settings_state.is_fullscreen_requested()
	)
	_reduced_motion_check.set_pressed_no_signal(
		_demo_settings_state.is_reduced_motion()
	)
	_master_volume_slider.set_value_no_signal(
		_demo_settings_state.get_master_volume()
	)
	_apply_all_settings()


func _refresh_localized_ui() -> void:
	_title_label.text = tr("UI_TITLE")
	_observation_heading.text = tr("UI_OBSERVATION_CARDS")
	_completion_heading.text = tr("UI_COMPLETION_HEADING")
	_completion_label.text = tr("UI_COMPLETION_DEFAULT")
	_restart_button.text = tr("UI_RESTART_OBSERVATION")
	_footer_label.text = tr("UI_FOOTER_PROTOTYPE")
	_debug_title.text = tr("UI_DEBUG_HEADING")
	_preparation_heading.text = tr("UI_PREPARATION_HEADING")
	_preparation_description.text = tr("UI_PREPARATION_DESCRIPTION")
	_start_observation_button.text = tr("UI_START_OBSERVATION")
	_pause_heading.text = tr("UI_PAUSE_HEADING")
	_resume_button.text = tr("UI_RESUME")
	_pause_restart_button.text = tr("UI_RESTART_CHAPTER")
	_save_game_button.text = tr("UI_SAVE_GAME")
	_return_to_title_button.text = tr("UI_SAVE_RETURN_TITLE")
	_display_heading.text = tr("UI_DISPLAY_HEADING")
	_resolution_label.text = tr("UI_RESOLUTION")
	_fullscreen_check.text = tr("UI_FULLSCREEN")
	_language_label.text = tr("UI_LANGUAGE")
	_ui_scale_label.text = tr("UI_SCALE")
	_reduced_motion_check.text = tr("UI_REDUCED_MOTION")
	_master_volume_label.text = tr("UI_MASTER_VOLUME")
	_exit_button.text = tr("UI_EXIT")
	if _resolution_option.item_count >= 2:
		_resolution_option.set_item_text(0, tr("UI_RESOLUTION_1280"))
		_resolution_option.set_item_text(1, tr("UI_RESOLUTION_1920"))
	if _language_option.item_count >= 2:
		_language_option.set_item_text(0, tr("UI_LANGUAGE_ZH"))
		_language_option.set_item_text(1, tr("UI_LANGUAGE_EN"))
	if _latest_snapshot == null:
		_debug_label.text = tr("UI_DEBUG_WAITING")
	if _latest_snapshot != null:
		_update_worker_observation_panel()
		_update_observation_cards()
		_update_player_guidance()
		_update_control_state()


func _apply_all_settings() -> void:
	TranslationServer.set_locale(_demo_settings_state.get_locale_code())
	_apply_fullscreen_mode()
	_apply_ui_scale()
	_apply_reduced_motion()
	_apply_master_volume()


func _apply_ui_scale() -> void:
	var window: Window = get_window()
	if window != null:
		window.content_scale_factor = 1.0
	var scale_factor: float = _demo_settings_state.get_ui_scale_factor()
	if _ui_scale_theme == null:
		_ui_scale_theme = Theme.new()
		theme = _ui_scale_theme
	_ui_scale_theme.default_base_scale = scale_factor
	_ui_scale_theme.default_font_size = int(round(16.0 * scale_factor))
	_apply_explicit_font_scale(self, scale_factor)


func _apply_explicit_font_scale(node: Node, scale_factor: float) -> void:
	if node is Control:
		var control: Control = node as Control
		if control.has_theme_font_size_override(&"font_size"):
			if not control.has_meta(&"ui_scale_base_font_size"):
				control.set_meta(
					&"ui_scale_base_font_size",
					control.get_theme_font_size(&"font_size")
				)
			control.add_theme_font_size_override(
				&"font_size",
				int(round(
					float(control.get_meta(&"ui_scale_base_font_size"))
					* scale_factor
				))
			)
	for child: Node in node.get_children():
		_apply_explicit_font_scale(child, scale_factor)


func _apply_reduced_motion() -> void:
	if _habitat_view != null:
		_habitat_view.set_reduced_motion(
			_demo_settings_state.is_reduced_motion()
		)


func _apply_master_volume() -> void:
	var bus_index: int = AudioServer.get_bus_index(&"Master")
	if bus_index < 0:
		return
	var volume: float = _demo_settings_state.get_master_volume()
	AudioServer.set_bus_mute(bus_index, volume <= 0.0001)
	if volume > 0.0001:
		AudioServer.set_bus_volume_db(bus_index, linear_to_db(volume))


func _emit_settings_changed() -> void:
	settings_changed.emit(_demo_settings_state)


func _open_pause_menu() -> void:
	if _pause_menu_open or _simulation_clock == null:
		return
	if _sugar_tool_armed:
		_cancel_sugar_tool(tr("FEEDBACK_PAUSED_CANCELLED"))
	_paused_before_menu = _simulation_clock.is_paused()
	_pause_menu_open = true
	_pause_menu.visible = true
	_pause_save_status.visible = false
	_simulation_clock.set_paused(true)
	_habitat_view.set_visuals_paused(true)
	_update_control_state()
	_update_debug_panel()
	_resume_button.grab_focus()


func _close_pause_menu(force_resume: bool) -> void:
	if not _pause_menu_open or _simulation_clock == null:
		return
	_pause_menu_open = false
	_pause_menu.visible = false
	var paused: bool = (
		true
		if _preparation_gate_active
			or not _fatal_simulation_error.is_empty()
		else (false if force_resume else _paused_before_menu)
	)
	_simulation_clock.set_paused(paused)
	_habitat_view.set_visuals_paused(paused)
	_update_control_state()
	_update_debug_panel()


func _apply_windowed_resolution() -> void:
	if DisplayServer.get_name().to_lower() == "headless":
		return
	DisplayServer.window_set_size(
		_demo_settings_state.get_windowed_resolution()
	)


func _apply_fullscreen_mode() -> void:
	if DisplayServer.get_name().to_lower() == "headless":
		return
	if _demo_settings_state.is_fullscreen_requested():
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		return
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	_apply_windowed_resolution()


func _update_debug_panel() -> void:
	if not _debug_panel.visible or _latest_snapshot == null:
		return
	var zone_lines: PackedStringArray = []
	for zone: HabitatZoneSnapshot in _latest_snapshot.colony.zones:
		zone_lines.append(
			"%s  humidity=%.3f  available=%s  links=%s"
			% [
				zone.zone_id,
				zone.humidity,
				str(zone.available),
				",".join(zone.connected_zone_ids),
			]
		)
	var worker_lines: PackedStringArray = []
	for ant: AntSnapshot in _latest_snapshot.colony.ants:
		if ant.life_stage != AntModel.LifeStage.WORKER:
			continue
		var forage_state: int = (
			ant.foraging_task.state
			if ant.foraging_task != null
			else ForagingTaskSnapshot.State.IDLE
		)
		worker_lines.append(
			(
				"#%03d zone=%s relocate=%d brood=#%s carry=#%s"
				+ " forage=%d food=#%s sugar=%d"
			)
			% [
				ant.entity_id,
				ant.zone_id,
				ant.worker_task_state,
				_format_optional_id(ant.target_brood_id),
				_format_optional_id(ant.carried_brood_id),
				forage_state,
				_format_optional_id(
					ant.foraging_task.target_food_source_id
					if ant.foraging_task != null
					else -1
				),
				(
					ant.foraging_task.carried_portions
					if ant.foraging_task != null
					else 0
				),
			]
		)
	if worker_lines.is_empty():
		worker_lines.append("none")
	_debug_label.text = (
		"Tick %d | speed %d× | paused=%s\n"
		+ "phase=%s entered=%d first_worker=#%s\n"
		+ "continue pending=%s | water pending=%s | sugar pending=%s\n"
		+ "cards=%s\n\nzones:\n%s\n\nworkers:\n%s\n\n"
		+ "events=%d | AntViews=%d"
	) % [
		_latest_snapshot.simulation_tick,
		_simulation_clock.get_speed_multiplier(),
		str(_simulation_clock.is_paused()),
		_get_phase_name(_latest_snapshot.sequence.phase),
		_latest_snapshot.sequence.phase_entered_tick,
		_format_optional_id(
			_latest_snapshot.sequence.first_worker_entity_id
		),
		str(_latest_snapshot.sequence.continue_action_pending),
		str(_latest_snapshot.colony.water_action_pending),
		str(_latest_snapshot.scenario.place_action_pending),
		",".join(_latest_snapshot.observations.unlocked_card_ids),
		"\n".join(zone_lines),
		"\n".join(worker_lines),
		_latest_snapshot.observations.events.size(),
		_habitat_view.get_ant_view_count(),
	]


func _can_arm_sugar_tool() -> bool:
	return (
		_fatal_simulation_error.is_empty()
		and not _preparation_gate_active
		and not _pause_menu_open
		and _simulation_clock != null
		and not _simulation_clock.is_paused()
		and _latest_snapshot != null
		and _latest_snapshot.sequence.phase
			== ScenarioSequenceSnapshot.Phase.SUGAR_FORAGING
		and _latest_snapshot.scenario.place_action_available
		and not _latest_snapshot.scenario.place_action_pending
	)


func _set_sugar_tool_armed(value: bool) -> void:
	_sugar_tool_armed = value
	if _habitat_view != null:
		_habitat_view.set_sugar_tool_armed(value)


func _cancel_sugar_tool(feedback_text: String) -> void:
	_set_sugar_tool_armed(false)
	if _feedback_label != null:
		_set_copy(
			_feedback_label,
			feedback_text,
			COPY_ROLE_ACTION_AFFORDANCE
		)
	_update_control_state()


func _set_completion_state(completed: bool) -> void:
	_stage_controls.visible = not completed
	_completion_panel.visible = completed
	if completed:
		_set_sugar_tool_armed(false)


func _restart_session() -> void:
	if not _colony_simulation.restart_session():
		var message: String = _colony_simulation.get_configuration_error()
		if message.is_empty():
			message = tr("ERROR_RESTART")
		_set_fatal_simulation_error(message)
		return

	_fatal_simulation_error = ""
	_latest_snapshot = null
	_player_annotation_state.reset_session()
	_preparation_gate_active = true
	_pause_menu_open = false
	_pause_menu.visible = false
	_simulation_clock.reset()
	_simulation_clock.set_paused(true)
	_set_sugar_tool_armed(false)
	_debug_panel.visible = false
	_debug_label.text = tr("UI_DEBUG_WAITING")
	_worker_observation_panel.reset_panel()
	_habitat_view.reset_projection()
	_apply_game_snapshot()
	_enter_preparation_gate()


func _build_completion_summary() -> String:
	var first_worker_id: int = _latest_snapshot.sequence.first_worker_entity_id
	var display_name: String = _player_annotation_state.get_worker_name(
		first_worker_id
	)
	var subject: String = (
		display_name
		if not display_name.is_empty()
		else tr("COMPLETION_DEFAULT_SUBJECT")
	)
	return tr("COMPLETION_SUMMARY") % subject


func _get_phase_heading(phase: int) -> String:
	match phase:
		ScenarioSequenceSnapshot.Phase.FOUNDING_PRELUDE:
			return tr("PHASE_1")
		ScenarioSequenceSnapshot.Phase.IDENTITY_OBSERVATION:
			return tr("PHASE_2")
		ScenarioSequenceSnapshot.Phase.HUMIDITY_OBSERVATION:
			return tr("PHASE_3")
		ScenarioSequenceSnapshot.Phase.SUGAR_FORAGING:
			return tr("PHASE_4")
		ScenarioSequenceSnapshot.Phase.OBSERVATION_SUMMARY:
			return tr("PHASE_5")
		_:
			return tr("PHASE_FALLBACK")


func _get_phase_name(phase: int) -> String:
	match phase:
		ScenarioSequenceSnapshot.Phase.FOUNDING_PRELUDE:
			return "FOUNDING_PRELUDE"
		ScenarioSequenceSnapshot.Phase.IDENTITY_OBSERVATION:
			return "IDENTITY_OBSERVATION"
		ScenarioSequenceSnapshot.Phase.HUMIDITY_OBSERVATION:
			return "HUMIDITY_OBSERVATION"
		ScenarioSequenceSnapshot.Phase.SUGAR_FORAGING:
			return "SUGAR_FORAGING"
		ScenarioSequenceSnapshot.Phase.OBSERVATION_SUMMARY:
			return "OBSERVATION_SUMMARY"
		_:
			return "UNKNOWN"


func _enter_preparation_gate() -> void:
	_preparation_gate_active = true
	_preparation_gate.visible = true
	_pause_menu_open = false
	_pause_menu.visible = false
	_start_observation_button.disabled = not _fatal_simulation_error.is_empty()
	_debug_panel.visible = false
	_set_sugar_tool_armed(false)
	if _simulation_clock != null:
		_simulation_clock.set_speed_multiplier(SimulationClock.NORMAL_SPEED)
		_simulation_clock.set_paused(true)
	if _habitat_view != null:
		_habitat_view.set_interpolation_alpha(0.0)
		_habitat_view.set_visuals_paused(true)
	_update_control_state()
	_update_debug_panel()


func is_preparation_gate_active() -> bool:
	return _preparation_gate_active


func is_pause_menu_open() -> bool:
	return _pause_menu_open


func is_simulation_paused() -> bool:
	return _simulation_clock == null or _simulation_clock.is_paused()


func get_simulation_tick() -> int:
	return (
		_latest_snapshot.simulation_tick
		if _latest_snapshot != null
		else 0
	)


func get_requested_window_resolution() -> Vector2i:
	return _demo_settings_state.get_windowed_resolution()


func is_fullscreen_requested() -> bool:
	return _demo_settings_state.is_fullscreen_requested()


func get_selected_locale() -> String:
	return _demo_settings_state.get_locale_code()


func get_ui_scale_factor() -> float:
	return _demo_settings_state.get_ui_scale_factor()


func is_reduced_motion_requested() -> bool:
	return _demo_settings_state.is_reduced_motion()


func get_master_volume() -> float:
	return _demo_settings_state.get_master_volume()


func create_profile_envelope(saved_at_utc: String = "") -> Dictionary:
	if (
		_preparation_gate_active
		or not _fatal_simulation_error.is_empty()
		or _colony_simulation == null
		or _simulation_clock == null
	):
		return {}
	return SaveGameService.new().create_envelope(
		_colony_simulation,
		_simulation_clock,
		ProfileStore.MAIN_SLOT_ID,
		saved_at_utc
	)


func start_new_profile() -> bool:
	var simulation: ColonySimulation = ColonySimulation.new(
		species_data_source,
		habitat_scenario_data_source
	)
	if not simulation.is_ready():
		return false
	_disconnect_clock()
	_colony_simulation = simulation
	_simulation_clock = SimulationClock.new()
	_connect_clock()
	_reset_session_projection()
	_apply_game_snapshot()
	_enter_preparation_gate()
	return _fatal_simulation_error.is_empty()


func restore_loaded_session(
	simulation: ColonySimulation,
	clock: SimulationClock
) -> bool:
	if (
		simulation == null
		or clock == null
		or not simulation.is_ready()
		or simulation.create_snapshot().simulation_tick != clock.get_tick_index()
	):
		return false
	_disconnect_clock()
	_colony_simulation = simulation
	_simulation_clock = clock
	_connect_clock()
	_reset_session_projection()
	_preparation_gate_active = false
	_preparation_gate.visible = false
	_start_observation_button.disabled = true
	_apply_game_snapshot()
	if not _fatal_simulation_error.is_empty():
		return false
	var restored_paused: bool = _simulation_clock.is_paused()
	_habitat_view.set_visuals_paused(restored_paused)
	if restored_paused:
		_paused_before_menu = true
		_pause_menu_open = true
		_pause_menu.visible = true
		_resume_button.grab_focus()
	else:
		_pause_menu_open = false
		_pause_menu.visible = false
	_update_control_state()
	_update_debug_panel()
	return true


func apply_external_settings(settings: DemoSettingsState) -> void:
	if settings == null:
		return
	_demo_settings_state = settings
	provided_settings_state = settings
	_initialize_demo_settings()
	_refresh_localized_ui()


func report_profile_save_result(success: bool) -> void:
	_pause_save_status.text = (
		tr("PROFILE_SAVE_SUCCESS")
		if success
		else tr("PROFILE_SAVE_FAILURE")
	)
	_pause_save_status.modulate = (
		Color(0.68, 0.9, 0.72)
		if success
		else Color(1.0, 0.62, 0.52)
	)
	_pause_save_status.visible = true
	_set_copy(
		_feedback_label,
		tr("PROFILE_SAVE_SUCCESS")
		if success
		else tr("PROFILE_SAVE_FAILURE"),
		COPY_ROLE_SYSTEM_STATUS if success else COPY_ROLE_ERROR
	)


func _connect_clock() -> void:
	if (
		_simulation_clock != null
		and not _simulation_clock.tick_requested.is_connected(
			_on_simulation_tick_requested
		)
	):
		_simulation_clock.tick_requested.connect(
			_on_simulation_tick_requested
		)


func _disconnect_clock() -> void:
	if (
		_simulation_clock != null
		and _simulation_clock.tick_requested.is_connected(
			_on_simulation_tick_requested
		)
	):
		_simulation_clock.tick_requested.disconnect(
			_on_simulation_tick_requested
		)


func _reset_session_projection() -> void:
	_fatal_simulation_error = ""
	_latest_snapshot = null
	_player_annotation_state.reset_session()
	_pause_menu_open = false
	_pause_menu.visible = false
	_set_sugar_tool_armed(false)
	_debug_panel.visible = false
	_debug_label.text = tr("UI_DEBUG_WAITING")
	_worker_observation_panel.reset_panel()
	_habitat_view.reset_projection()


func _debug_controls_available() -> bool:
	return OS.is_debug_build()


func _set_card_copy(
	label: Label,
	unlocked: bool,
	unlocked_text: String
) -> void:
	if unlocked:
		_set_copy(
			label,
			"✓  %s" % tr(unlocked_text),
			COPY_ROLE_POST_EVENT_CONCLUSION
		)
	else:
		_set_copy(
			label,
			tr("UI_CARD_LOCKED"),
			COPY_ROLE_NEUTRAL_PLACEHOLDER
		)


func _set_copy(label: Label, text: String, role: StringName) -> void:
	label.text = text
	label.set_meta(COPY_ROLE_META_KEY, role)


func _format_optional_id(entity_id: int) -> String:
	return "%03d" % entity_id if entity_id >= 0 else "---"


func _set_fatal_simulation_error(message: String) -> void:
	_fatal_simulation_error = message
	if _simulation_clock != null:
		_simulation_clock.set_paused(true)
	if _habitat_view != null:
		_habitat_view.set_visuals_paused(true)
		_habitat_view.set_sugar_tool_armed(false)
	_sugar_tool_armed = false
	if is_node_ready():
		_set_copy(_instruction_label, message, COPY_ROLE_ERROR)
		_start_observation_button.disabled = true
		_update_control_state()
