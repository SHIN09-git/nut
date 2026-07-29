class_name Act1TestTubeController
extends Control

signal application_exit_requested
signal save_profile_requested
signal return_to_title_requested
signal settings_changed(settings: DemoSettingsState)

const SPECIES_A_DATA: SpeciesData = preload(
	"res://data/species/species_a.tres"
)
const ACT1_SCENARIO_DATA: HabitatScenarioData = preload(
	"res://data/habitats/act1_test_tube.tres"
)

var species_data_source: SpeciesData = SPECIES_A_DATA
var habitat_scenario_data_source: HabitatScenarioData = ACT1_SCENARIO_DATA
var exit_application_on_request: bool = true
var provided_settings_state: DemoSettingsState
var shell_managed: bool = false

var _simulation_clock: SimulationClock
var _colony_simulation: ColonySimulation
var _latest_snapshot: GameSnapshot
var _settings_state: DemoSettingsState
var _ui_scale_theme: Theme
var _preparation_gate_active: bool = true
var _pause_menu_open: bool = false
var _journal_open: bool = false
var _magnifier_active: bool = false
var _completion_dismissed: bool = false
var _fatal_error: String = ""
var _selected_facility_type_id: StringName = (
	CampaignState.FACILITY_SMALL_FORAGING_BOX
)

@onready var _habitat_view: Act1TestTubeView = %Act1TestTubeView
@onready var _title_label: Label = %Title
@onready var _chapter_label: Label = %ChapterLabel
@onready var _status_label: Label = %StatusLabel
@onready var _pause_button: Button = %PauseButton
@onready var _speed_1x_button: Button = %Speed1xButton
@onready var _speed_4x_button: Button = %Speed4xButton
@onready var _speed_16x_button: Button = %Speed16xButton
@onready var _objective_heading: Label = %ObjectiveHeading
@onready var _objective_label: Label = %ObjectiveLabel
@onready var _evidence_heading: Label = %EvidenceHeading
@onready var _evidence_label: Label = %EvidenceLabel
@onready var _guidance_label: Label = %GuidanceLabel
@onready var _cover_button: Button = %CoverButton
@onready var _magnifier_button: Button = %MagnifierButton
@onready var _sugar_button: Button = %SugarButton
@onready var _protein_button: Button = %ProteinButton
@onready var _clean_waste_button: Button = %CleanWasteButton
@onready var _layout_button: Button = %LayoutButton
@onready var _place_box_button: Button = %PlaceBoxButton
@onready var _facility_type_option: OptionButton = %FacilityTypeOption
@onready var _rotate_facility_button: Button = %RotateFacilityButton
@onready var _remove_facility_button: Button = %RemoveFacilityButton
@onready var _toggle_gate_button: Button = %ToggleGateButton
@onready var _zoom_out_button: Button = %ZoomOutButton
@onready var _reset_camera_button: Button = %ResetCameraButton
@onready var _zoom_in_button: Button = %ZoomInButton
@onready var _journal_button: Button = %JournalButton
@onready var _inspect_panel: PanelContainer = %InspectPanel
@onready var _inspect_label: Label = %InspectLabel
@onready var _preparation_gate: Control = %PreparationGate
@onready var _preparation_heading: Label = %PreparationHeading
@onready var _preparation_body: Label = %PreparationBody
@onready var _start_button: Button = %StartObservationButton
@onready var _journal_panel: Control = %JournalPanel
@onready var _journal_heading: Label = %JournalHeading
@onready var _journal_chapter_label: Label = %JournalChapterLabel
@onready var _journal_status_label: Label = %JournalStatusLabel
@onready var _journal_objective_label: Label = %JournalObjectiveLabel
@onready var _journal_evidence_label: Label = %JournalEvidenceLabel
@onready var _journal_hint_label: Label = %JournalHintLabel
@onready var _inference_buttons: Array[Button] = [
	%InferenceButton1,
	%InferenceButton2,
	%InferenceButton3,
]
@onready var _journal_close_button: Button = %JournalCloseButton
@onready var _completion_panel: Control = %CompletionPanel
@onready var _completion_heading: Label = %CompletionHeading
@onready var _completion_body: Label = %CompletionBody
@onready var _continue_button: Button = %ContinueFreeplayButton
@onready var _pause_menu: Control = %PauseMenu
@onready var _pause_heading: Label = %PauseHeading
@onready var _resume_button: Button = %ResumeButton
@onready var _save_button: Button = %SaveGameButton
@onready var _return_button: Button = %ReturnToTitleButton
@onready var _restart_button: Button = %RestartButton
@onready var _exit_button: Button = %ExitButton
@onready var _save_status: Label = %SaveStatus
@onready var _debug_panel: PanelContainer = %DebugPanel
@onready var _debug_label: Label = %DebugLabel


func _ready() -> void:
	_settings_state = provided_settings_state
	if _settings_state == null:
		_settings_state = DemoSettingsState.new(
			TranslationServer.get_locale()
		)
	_apply_ui_scale()
	_connect_controls()
	_initialize_session()
	_refresh_copy()
	_exit_button.visible = not shell_managed
	_simulation_clock.set_paused(true)
	_apply_snapshot()
	_enter_preparation_gate()


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready():
		_refresh_copy()


func _process(delta: float) -> void:
	if (
		_simulation_clock == null
		or not _fatal_error.is_empty()
		or _preparation_gate_active
	):
		return
	_simulation_clock.advance(delta)
	_habitat_view.set_interpolation_alpha(
		_simulation_clock.get_interpolation_alpha()
	)


func _unhandled_input(event: InputEvent) -> void:
	var key_event: InputEventKey = event as InputEventKey
	if key_event == null or not key_event.pressed or key_event.echo:
		return
	if key_event.keycode == KEY_F3:
		_debug_panel.visible = not _debug_panel.visible
		_update_debug()
		get_viewport().set_input_as_handled()
	elif (
		key_event.keycode == KEY_L
		and not _preparation_gate_active
		and not _pause_menu_open
		and not _journal_open
	):
		_set_facility_layout_mode(not _habitat_view.is_layout_mode())
		get_viewport().set_input_as_handled()
	elif (
		key_event.keycode == KEY_P
		and _habitat_view.is_layout_mode()
		and not _preparation_gate_active
		and not _pause_menu_open
		and not _journal_open
	):
		_on_place_box_pressed()
		get_viewport().set_input_as_handled()
	elif (
		_habitat_view.is_layout_mode()
		and not _preparation_gate_active
		and not _pause_menu_open
		and not _journal_open
		and _habitat_view.handle_layout_keyboard_action(
			key_event.keycode
		)
	):
		get_viewport().set_input_as_handled()
	elif key_event.keycode == KEY_ESCAPE:
		if _journal_open:
			_close_journal()
		elif _pause_menu_open:
			_close_pause_menu()
		else:
			_open_pause_menu()
		get_viewport().set_input_as_handled()


func _connect_controls() -> void:
	_start_button.pressed.connect(_on_start_pressed)
	_pause_button.pressed.connect(_open_pause_menu)
	_resume_button.pressed.connect(_close_pause_menu)
	_save_button.pressed.connect(_on_save_pressed)
	_return_button.pressed.connect(_on_return_pressed)
	_restart_button.pressed.connect(_restart_session)
	_exit_button.pressed.connect(_on_exit_pressed)
	_speed_1x_button.pressed.connect(
		_set_speed.bind(SimulationClock.NORMAL_SPEED)
	)
	_speed_4x_button.pressed.connect(
		_set_speed.bind(SimulationClock.FAST_SPEED)
	)
	_speed_16x_button.pressed.connect(
		_set_speed.bind(SimulationClock.VERY_FAST_SPEED)
	)
	_cover_button.pressed.connect(_on_cover_pressed)
	_magnifier_button.pressed.connect(_on_magnifier_pressed)
	_sugar_button.pressed.connect(_on_sugar_pressed)
	_protein_button.pressed.connect(_on_protein_pressed)
	_clean_waste_button.pressed.connect(_on_clean_waste_pressed)
	_layout_button.pressed.connect(_on_layout_pressed)
	_place_box_button.pressed.connect(_on_place_box_pressed)
	_facility_type_option.item_selected.connect(
		_on_facility_type_selected
	)
	_rotate_facility_button.pressed.connect(
		_habitat_view.request_rotate_selected_facility
	)
	_remove_facility_button.pressed.connect(
		_habitat_view.request_remove_selected_facility
	)
	_toggle_gate_button.pressed.connect(_on_toggle_gate_pressed)
	_zoom_out_button.pressed.connect(_habitat_view.zoom_layout_out)
	_reset_camera_button.pressed.connect(
		_habitat_view.reset_layout_camera
	)
	_zoom_in_button.pressed.connect(_habitat_view.zoom_layout_in)
	_journal_button.pressed.connect(_open_journal)
	_journal_close_button.pressed.connect(_close_journal)
	_continue_button.pressed.connect(_on_continue_freeplay_pressed)
	for index: int in _inference_buttons.size():
		_inference_buttons[index].pressed.connect(
			_on_inference_pressed.bind(index)
		)
	_habitat_view.worker_selection_requested.connect(
		_on_worker_selected
	)
	_habitat_view.facility_placement_requested.connect(
		_on_facility_placement_requested
	)
	_habitat_view.facility_rotation_requested.connect(
		_on_facility_rotation_requested
	)
	_habitat_view.facility_removal_requested.connect(
		_on_facility_removal_requested
	)
	_habitat_view.facility_selection_changed.connect(
		func(_facility_id: int) -> void:
			_update_controls()
	)


func _initialize_session() -> void:
	_simulation_clock = SimulationClock.new()
	_colony_simulation = ColonySimulation.new(
		species_data_source,
		habitat_scenario_data_source
	)
	if not _colony_simulation.is_ready():
		_set_fatal_error(_colony_simulation.get_configuration_error())
		return
	_simulation_clock.tick_requested.connect(_on_tick_requested)
	_habitat_view.set_reduced_motion(
		_settings_state.is_reduced_motion()
	)


func _on_tick_requested(tick_index: int, _tick_seconds: float) -> void:
	if not _colony_simulation.advance_tick(tick_index):
		_set_fatal_error(
			"Simulation rejected Tick %d" % tick_index
		)
		return
	_apply_snapshot()


func _apply_snapshot() -> void:
	_latest_snapshot = _colony_simulation.create_game_snapshot()
	if (
		_latest_snapshot == null
		or _latest_snapshot.colony == null
		or _latest_snapshot.campaign == null
		or _latest_snapshot.nutrition == null
		or _latest_snapshot.act1 == null
		or not _habitat_view.apply_snapshot(_latest_snapshot)
	):
		_set_fatal_error(tr("ERROR_INCOMPLETE_SNAPSHOT"))
		return
	_update_main_panel()
	_update_journal()
	_update_controls()
	_update_inspector()
	_update_debug()


func _enter_preparation_gate() -> void:
	_preparation_gate_active = true
	_preparation_gate.visible = true
	_pause_menu.visible = false
	_pause_menu_open = false
	_journal_panel.visible = false
	_journal_open = false
	_completion_panel.visible = false
	_start_button.grab_focus()


func _on_start_pressed() -> void:
	if not _fatal_error.is_empty():
		return
	_preparation_gate_active = false
	_preparation_gate.visible = false
	_simulation_clock.set_paused(false)
	_habitat_view.set_visuals_paused(false)
	_cover_button.grab_focus()
	_update_controls()


func _on_cover_pressed() -> void:
	if _colony_simulation.submit_apply_light_cover_action():
		_apply_snapshot()
		_guidance_label.text = tr("ACT1_FEEDBACK_COVER_PENDING")


func _on_sugar_pressed() -> void:
	if _colony_simulation.submit_place_sugar_action():
		_apply_snapshot()
		_guidance_label.text = tr("ACT1_FEEDBACK_SUGAR_PENDING")


func _on_protein_pressed() -> void:
	if _colony_simulation.submit_place_protein_action():
		_apply_snapshot()
		_guidance_label.text = tr("R10_FEEDBACK_PROTEIN_PENDING")


func _on_clean_waste_pressed() -> void:
	if (
		_latest_snapshot == null
		or _latest_snapshot.work == null
		or _latest_snapshot.work.cleanable_tray_facility_ids.is_empty()
	):
		return
	var facility_id: int = (
		_latest_snapshot.work.cleanable_tray_facility_ids[0]
	)
	if _colony_simulation.submit_clean_waste_tray_action(facility_id):
		_apply_snapshot()
		_guidance_label.text = tr("R9_CLEAN_WASTE_PENDING")


func _on_layout_pressed() -> void:
	_set_facility_layout_mode(_layout_button.button_pressed)


func _set_facility_layout_mode(value: bool) -> void:
	_habitat_view.set_layout_mode(value)
	if not value:
		_habitat_view.cancel_facility_placement()
	_layout_button.button_pressed = value
	_update_controls()


func _on_place_box_pressed() -> void:
	if _habitat_view.begin_facility_placement(
		_selected_facility_type_id
	):
		_layout_button.button_pressed = true
		_update_controls()


func _on_facility_type_selected(index: int) -> void:
	if index < 0 or index >= _facility_type_option.item_count:
		return
	_selected_facility_type_id = StringName(
		_facility_type_option.get_item_metadata(index)
	)
	_update_controls()


func _on_toggle_gate_pressed() -> void:
	if _latest_snapshot == null or _latest_snapshot.layout == null:
		return
	var selected_id: int = _habitat_view.get_selected_facility_id()
	for connection: HabitatConnectionSnapshot in (
		_latest_snapshot.layout.connections
	):
		if (
			connection.owner_facility_id == selected_id
			and connection.gated
			and _colony_simulation.submit_set_gate_open_action(
				connection.connection_id,
				not connection.open
			)
		):
			_apply_snapshot()
			_guidance_label.text = tr("R10_FEEDBACK_GATE_PENDING")
			return


func _on_facility_placement_requested(
	type_id: StringName,
	slot: Vector2i,
	orientation: int
) -> void:
	if _colony_simulation.submit_place_facility_action(
		type_id,
		slot,
		orientation
	):
		_apply_snapshot()
		_guidance_label.text = tr("R7_LAYOUT_ACTION_PENDING")


func _on_facility_rotation_requested(
	facility_id: int,
	orientation: int
) -> void:
	if _colony_simulation.submit_rotate_facility_action(
		facility_id,
		orientation
	):
		_apply_snapshot()
		_guidance_label.text = tr("R7_LAYOUT_ACTION_PENDING")


func _on_facility_removal_requested(facility_id: int) -> void:
	if _colony_simulation.submit_remove_facility_action(facility_id):
		_apply_snapshot()
		_guidance_label.text = tr("R7_LAYOUT_ACTION_PENDING")


func _on_magnifier_pressed() -> void:
	_magnifier_active = not _magnifier_active
	_inspect_panel.visible = _magnifier_active
	_update_inspector()
	_update_controls()


func _on_worker_selected(entity_id: int) -> void:
	_habitat_view.set_selected_worker_id(entity_id)
	_magnifier_active = true
	_inspect_panel.visible = true
	_update_inspector()
	_update_controls()


func _open_journal() -> void:
	if _preparation_gate_active or _pause_menu_open:
		return
	_journal_open = true
	_journal_panel.visible = true
	_simulation_clock.set_paused(true)
	_habitat_view.set_visuals_paused(true)
	_update_journal()
	var focus_target: Control = _journal_close_button
	for button: Button in _inference_buttons:
		if button.visible and not button.disabled:
			focus_target = button
			break
	focus_target.grab_focus()
	_update_controls()


func _close_journal() -> void:
	_journal_open = false
	_journal_panel.visible = false
	if not _pause_menu_open and not _preparation_gate_active:
		_simulation_clock.set_paused(false)
		_habitat_view.set_visuals_paused(false)
	_journal_button.grab_focus()
	_update_controls()


func _on_inference_pressed(index: int) -> void:
	if index < 0 or index >= _inference_buttons.size():
		return
	var inference_id: StringName = StringName(
		_inference_buttons[index].get_meta(&"inference_id", &"")
	)
	if (
		not inference_id.is_empty()
		and _colony_simulation.submit_campaign_inference_action(
			inference_id
		)
	):
		_apply_snapshot()
		_journal_status_label.text = tr(
			"CAMPAIGN_INFERENCE_SUBMITTED"
		)


func _open_pause_menu() -> void:
	if _preparation_gate_active or _journal_open:
		return
	_pause_menu_open = true
	_pause_menu.visible = true
	_simulation_clock.set_paused(true)
	_habitat_view.set_visuals_paused(true)
	_resume_button.grab_focus()
	_update_controls()


func _close_pause_menu() -> void:
	_pause_menu_open = false
	_pause_menu.visible = false
	if not _preparation_gate_active and not _journal_open:
		_simulation_clock.set_paused(false)
		_habitat_view.set_visuals_paused(false)
	_pause_button.grab_focus()
	_update_controls()


func _on_save_pressed() -> void:
	if not _preparation_gate_active and _fatal_error.is_empty():
		save_profile_requested.emit()


func _on_return_pressed() -> void:
	return_to_title_requested.emit()


func _on_exit_pressed() -> void:
	application_exit_requested.emit()
	if exit_application_on_request:
		get_tree().quit()


func _restart_session() -> void:
	if not start_new_profile():
		_set_fatal_error("Could not restart Act 1")


func _on_continue_freeplay_pressed() -> void:
	_completion_dismissed = true
	_completion_panel.visible = false
	_close_journal()


func _set_speed(multiplier: int) -> void:
	if _simulation_clock.set_speed_multiplier(multiplier):
		_update_controls()
		_update_debug()


func _update_main_panel() -> void:
	if _latest_snapshot == null:
		return
	var campaign: CampaignSnapshot = _latest_snapshot.campaign
	_chapter_label.text = _chapter_name(campaign.chapter)
	_objective_label.text = _objective_text(campaign)
	_evidence_label.text = _evidence_text(campaign)
	_guidance_label.text = _guidance_text(campaign)
	_completion_panel.visible = (
		campaign.completed
		and not _preparation_gate_active
		and not _completion_dismissed
	)


func _update_journal() -> void:
	if _latest_snapshot == null:
		return
	var campaign: CampaignSnapshot = _latest_snapshot.campaign
	_journal_chapter_label.text = _chapter_name(campaign.chapter)
	_journal_status_label.text = _campaign_status(campaign)
	_journal_objective_label.text = _objective_text(campaign)
	_journal_evidence_label.text = _evidence_text(campaign)
	_journal_hint_label.text = _hint_text(campaign)
	for index: int in _inference_buttons.size():
		var button: Button = _inference_buttons[index]
		var visible: bool = index < campaign.available_inference_ids.size()
		button.visible = visible
		button.disabled = (
			not visible
			or not campaign.inference_action_available
			or campaign.inference_action_pending
		)
		if not visible:
			button.remove_meta(&"inference_id")
			continue
		var inference_id: StringName = (
			campaign.available_inference_ids[index]
		)
		button.set_meta(&"inference_id", inference_id)
		button.text = _inference_text(inference_id)


func _update_controls() -> void:
	if _latest_snapshot == null or _simulation_clock == null:
		return
	var blocked: bool = (
		_preparation_gate_active
		or _pause_menu_open
		or _journal_open
		or not _fatal_error.is_empty()
	)
	var care: QueenCareSnapshot = _latest_snapshot.act1.queen_care
	_cover_button.disabled = (
		blocked or not care.light_cover_action_available
	)
	_cover_button.text = (
		tr("ACT1_TOOL_COVER_APPLIED")
		if care.light_cover_applied
		else tr("ACT1_TOOL_COVER_PENDING")
			if care.light_cover_action_pending
			else tr("ACT1_TOOL_COVER")
	)
	_sugar_button.visible = _latest_snapshot.campaign.has_unlocked_facility(
		CampaignState.FACILITY_MICRO_FEEDING_PORT
	)
	_sugar_button.disabled = (
		blocked or not _latest_snapshot.nutrition.sugar_action_available
	)
	_protein_button.visible = (
		_latest_snapshot.campaign.has_unlocked_facility(
			CampaignState.FACILITY_PROTEIN_DISH
		)
	)
	_protein_button.disabled = (
		blocked or not _latest_snapshot.nutrition.protein_action_available
	)
	var work: ColonyWorkSnapshot = _latest_snapshot.work
	_clean_waste_button.visible = (
		work != null
		and (
			not work.cleanable_tray_facility_ids.is_empty()
			or work.clean_action_pending_facility_id >= 0
		)
	)
	_clean_waste_button.disabled = (
		blocked
		or work == null
		or work.cleanable_tray_facility_ids.is_empty()
		or work.clean_action_pending_facility_id >= 0
	)
	_clean_waste_button.text = (
		tr("R9_TOOL_CLEAN_WASTE_PENDING")
		if work != null and work.clean_action_pending_facility_id >= 0
		else tr("R9_TOOL_CLEAN_WASTE")
	)
	var layout: HabitatLayoutSnapshot = _latest_snapshot.layout
	var layout_available: bool = layout != null and layout.active
	_layout_button.visible = layout_available
	_layout_button.disabled = blocked or not layout_available
	_layout_button.button_pressed = _habitat_view.is_layout_mode()
	var layout_mode: bool = _habitat_view.is_layout_mode()
	_update_facility_palette(layout if layout_available else null)
	var selected_supply: FacilitySupplySnapshot = (
		layout.get_supply(_selected_facility_type_id)
		if layout_available
		else null
	)
	_place_box_button.visible = (
		layout_mode and not _selected_facility_type_id.is_empty()
	)
	_place_box_button.disabled = (
		blocked
		or not layout_available
		or not _habitat_view.is_layout_mode()
		or layout.action_pending
		or selected_supply == null
		or selected_supply.remaining_count <= 0
	)
	if selected_supply != null:
		_place_box_button.text = tr("R10_LAYOUT_PLACE_SELECTED") % (
			selected_supply.remaining_count
		)
	var selected_facility: FacilitySnapshot = (
		layout.get_facility(_habitat_view.get_selected_facility_id())
		if layout_available
		else null
	)
	var can_edit_selected: bool = (
		not blocked
		and layout_mode
		and not layout.action_pending
		and selected_facility != null
		and selected_facility.player_removable
	)
	_rotate_facility_button.visible = layout_mode
	_remove_facility_button.visible = layout_mode
	_rotate_facility_button.disabled = not can_edit_selected
	_remove_facility_button.disabled = not can_edit_selected
	var selected_gate: HabitatConnectionSnapshot = (
		_get_selected_gate_connection(layout, selected_facility.facility_id)
		if selected_facility != null
		else null
	)
	_toggle_gate_button.visible = layout_mode and selected_gate != null
	_toggle_gate_button.disabled = (
		blocked
		or not layout_mode
		or layout.action_pending
		or selected_gate == null
	)
	if selected_gate != null:
		_toggle_gate_button.text = (
			tr("R10_GATE_CLOSE")
			if selected_gate.open
			else tr("R10_GATE_OPEN")
		)
	for camera_button: Button in [
		_zoom_out_button,
		_reset_camera_button,
		_zoom_in_button,
	]:
		camera_button.visible = layout_mode
		camera_button.disabled = blocked or not layout_mode
	_magnifier_button.disabled = blocked
	_magnifier_button.button_pressed = _magnifier_active
	_journal_button.disabled = (
		_preparation_gate_active or _pause_menu_open
	)
	for button: Button in [
		_pause_button,
		_speed_1x_button,
		_speed_4x_button,
		_speed_16x_button,
	]:
		button.disabled = blocked
	var speed: int = _simulation_clock.get_speed_multiplier()
	_speed_1x_button.button_pressed = speed == SimulationClock.NORMAL_SPEED
	_speed_4x_button.button_pressed = speed == SimulationClock.FAST_SPEED
	_speed_16x_button.button_pressed = speed == SimulationClock.VERY_FAST_SPEED
	_status_label.text = (
		tr("ACT1_STATUS_PAUSED")
		if _simulation_clock.is_paused()
		else tr("ACT1_STATUS_RUNNING") % speed
	)


func _update_facility_palette(layout: HabitatLayoutSnapshot) -> void:
	var available_ids: Array[StringName] = []
	if layout != null:
		var ordered_ids: Array[StringName] = [
			CampaignState.FACILITY_SMALL_FORAGING_BOX,
			CampaignState.FACILITY_SUGAR_STATION,
			CampaignState.FACILITY_PROTEIN_DISH,
			CampaignState.FACILITY_WASTE_TRAY,
			CampaignState.FACILITY_TEST_TUBE_NEST,
			&"connector_tube",
			&"connector_elbow",
			&"connector_gate",
			CampaignState.FACILITY_HYDRATION_MODULE,
		]
		for type_id: StringName in ordered_ids:
			var supply: FacilitySupplySnapshot = layout.get_supply(type_id)
			if (
				supply != null
				and supply.unlocked
				and supply.remaining_count > 0
				and _has_placement_option(layout, type_id)
			):
				available_ids.append(type_id)
	if (
		not available_ids.has(_selected_facility_type_id)
		and (layout == null or not layout.action_pending)
	):
		_selected_facility_type_id = (
			available_ids[0] if not available_ids.is_empty() else &""
		)
	_facility_type_option.clear()
	for type_id: StringName in available_ids:
		var index: int = _facility_type_option.item_count
		_facility_type_option.add_item(_facility_display_name(type_id))
		_facility_type_option.set_item_metadata(index, String(type_id))
		if type_id == _selected_facility_type_id:
			_facility_type_option.select(index)
	_facility_type_option.visible = (
		_habitat_view.is_layout_mode() and not available_ids.is_empty()
	)
	_facility_type_option.disabled = (
		not _habitat_view.is_layout_mode()
		or layout == null
		or layout.action_pending
	)


func _has_placement_option(
	layout: HabitatLayoutSnapshot,
	type_id: StringName
) -> bool:
	for option: FacilityPlacementOptionSnapshot in layout.placement_options:
		if option.type_id == type_id:
			return true
	return false


func _facility_display_name(type_id: StringName) -> String:
	match type_id:
		CampaignState.FACILITY_SMALL_FORAGING_BOX:
			return tr("R10_FACILITY_FORAGING_BOX")
		CampaignState.FACILITY_SUGAR_STATION:
			return tr("R10_FACILITY_SUGAR_STATION")
		CampaignState.FACILITY_PROTEIN_DISH:
			return tr("R10_FACILITY_PROTEIN_DISH")
		CampaignState.FACILITY_WASTE_TRAY:
			return tr("R10_FACILITY_WASTE_TRAY")
		CampaignState.FACILITY_TEST_TUBE_NEST:
			return tr("R10_FACILITY_SPARE_TUBE")
		&"connector_tube":
			return tr("R10_FACILITY_CONNECTOR")
		&"connector_elbow":
			return tr("R10_FACILITY_ELBOW")
		&"connector_gate":
			return tr("R10_FACILITY_GATE")
		CampaignState.FACILITY_HYDRATION_MODULE:
			return tr("R10_FACILITY_HYDRATION")
	return String(type_id)


func _get_selected_gate_connection(
	layout: HabitatLayoutSnapshot,
	facility_id: int
) -> HabitatConnectionSnapshot:
	if layout == null or facility_id < 0:
		return null
	for connection: HabitatConnectionSnapshot in layout.connections:
		if connection.owner_facility_id == facility_id and connection.gated:
			return connection
	return null


func _update_inspector() -> void:
	if _latest_snapshot == null:
		return
	var selected_id: int = _habitat_view.get_selected_worker_id()
	if selected_id >= 0:
		var worker: AntSnapshot = _latest_snapshot.colony.find_ant(
			selected_id
		)
		if worker != null:
			_inspect_label.text = tr("ACT1_INSPECT_WORKER") % [
				selected_id,
				_worker_activity(worker),
			]
			return
	var counts: Dictionary[int, int] = {
		AntModel.LifeStage.EGG: 0,
		AntModel.LifeStage.LARVA: 0,
		AntModel.LifeStage.PUPA: 0,
		AntModel.LifeStage.WORKER: 0,
	}
	for ant: AntSnapshot in _latest_snapshot.colony.ants:
		counts[ant.life_stage] += 1
	_inspect_label.text = tr("ACT1_INSPECT_COLONY") % [
		counts[AntModel.LifeStage.EGG],
		counts[AntModel.LifeStage.LARVA],
		counts[AntModel.LifeStage.PUPA],
		counts[AntModel.LifeStage.WORKER],
		_queen_activity(),
	]


func _update_debug() -> void:
	if not _debug_panel.visible or _latest_snapshot == null:
		return
	var lines: PackedStringArray = [
		"Tick %d · %d× · %s"
			% [
				_latest_snapshot.simulation_tick,
				_simulation_clock.get_speed_multiplier(),
				"paused" if _simulation_clock.is_paused() else "running",
			],
		"Chapter %d · status %d"
			% [
				_latest_snapshot.campaign.chapter,
				_latest_snapshot.campaign.status,
			],
		"Environment stable %d/%d"
			% [
				_latest_snapshot.act1.environment_stable_ticks,
				_latest_snapshot.act1.environment_stable_required_ticks,
			],
		"Cover %s · queen care %d (%d/%d) · target #%d"
			% [
				str(_latest_snapshot.act1.queen_care.light_cover_applied),
				_latest_snapshot.act1.queen_care.care_state,
				_latest_snapshot.act1.queen_care.elapsed_ticks,
				_latest_snapshot.act1.queen_care.duration_ticks,
				_latest_snapshot.act1.queen_care.target_brood_id,
			],
		"Sugar reserve %d · protein reserve %d · feedings %d"
			% [
				_latest_snapshot.nutrition.sugar_reserve_portions,
				_latest_snapshot.nutrition.protein_reserve_portions,
				_latest_snapshot.nutrition.completed_feeding_count,
		],
	]
	lines.append(
		"Layout revision %d · facilities %d · pending %s · zoom %.2f"
		% [
			_latest_snapshot.layout.revision,
			_latest_snapshot.layout.facilities.size(),
			str(_latest_snapshot.layout.action_pending),
			_habitat_view.get_layout_camera_zoom(),
		]
	)
	for zone: HabitatZoneSnapshot in _latest_snapshot.colony.zones:
		lines.append(
			"zone=%s humidity=%.3f light=%.3f pollution=%.3f discovered=%s"
			% [
				String(zone.zone_id),
				zone.humidity,
				zone.light_exposure,
				zone.pollution,
				str(zone.discovered),
			]
		)
	if _latest_snapshot.work != null:
		lines.append(
			"work waste=%d scout=%d migration=%d target=%s stable=%d"
			% [
				_latest_snapshot.work.active_waste_task_count,
				_latest_snapshot.work.active_scout_task_count,
				_latest_snapshot.work.active_migration_task_count,
				String(_latest_snapshot.work.migration_target_zone_id),
				_latest_snapshot.work.migration_candidate_stable_ticks,
			]
		)
	for facility: FacilitySnapshot in _latest_snapshot.layout.facilities:
		lines.append(
			"facility=%d type=%s zone=%s effect=%d waste=%.3f"
			% [
				facility.facility_id,
				String(facility.type_id),
				String(facility.zone_id),
				facility.effect_kind,
				facility.waste_fill_ratio,
			]
		)
	for ant: AntSnapshot in _latest_snapshot.colony.ants:
		lines.append(
			"#%03d stage=%d zone=%s forage=%d feed=%d waste=%d scout=%d migration=%d"
			% [
				ant.entity_id,
				ant.life_stage,
				String(ant.zone_id),
				ant.foraging_task.state
					if ant.foraging_task != null else -1,
				ant.feeding_task.state
					if ant.feeding_task != null else -1,
				ant.waste_cleanup_task.state
					if ant.waste_cleanup_task != null else -1,
				ant.scout_task.state
					if ant.scout_task != null else -1,
				ant.migration_task.state
					if ant.migration_task != null else -1,
			]
		)
	_debug_label.text = "\n".join(lines)


func _chapter_name(chapter: int) -> String:
	match chapter:
		CampaignState.Chapter.ACT1_FOUNDING:
			return tr("ACT1_CHAPTER_FOUNDING")
		CampaignState.Chapter.ACT1_FIRST_WORKERS:
			return tr("ACT1_CHAPTER_FIRST_WORKERS")
		CampaignState.Chapter.ACT1_FORAGING_EXPANSION:
			return tr("R10_CHAPTER_FORAGING")
		_:
			return tr("R10_CHAPTER_ENVIRONMENT")


func _objective_text(campaign: CampaignSnapshot) -> String:
	if campaign.chapter == CampaignState.Chapter.ACT1_FOUNDING:
		return tr("ACT1_OBJECTIVES_FOUNDING") % [
			_check(campaign.has_evidence(CampaignState.EVIDENCE_QUEEN_CARE)),
			_check(campaign.has_evidence(CampaignState.EVIDENCE_FIRST_PUPA)),
			_check(
				campaign.has_confirmed_inference(
					CampaignState.INFERENCE_QUEEN_CARE
				)
			),
		]
	if campaign.chapter == CampaignState.Chapter.ACT1_FIRST_WORKERS:
		return tr("ACT1_OBJECTIVES_WORKERS") % [
			_check(campaign.has_evidence(CampaignState.EVIDENCE_FIRST_WORKER)),
			_check(
				campaign.has_evidence(
					CampaignState.EVIDENCE_FIRST_WORKER_CARE
				)
			),
			_check(
				campaign.has_evidence(
					CampaignState.EVIDENCE_FIRST_NUTRIENT_EXCHANGE
				)
			),
			_check(
				campaign.has_confirmed_inference(
					CampaignState.INFERENCE_WORKER_NUTRITION
				)
			),
		]
	if campaign.chapter == CampaignState.Chapter.ACT1_FORAGING_EXPANSION:
		return tr("R10_OBJECTIVES_FORAGING") % [
			_check(campaign.has_evidence(
				CampaignState.EVIDENCE_FORAGING_ZONE_SCOUTED
			)),
			_check(campaign.has_evidence(
				CampaignState.EVIDENCE_FORAGING_SUGAR_CYCLE
			)),
			_check(campaign.has_evidence(
				CampaignState.EVIDENCE_PROTEIN_CARE
			)),
			_check(campaign.has_evidence(
				CampaignState.EVIDENCE_WASTE_TRAY_CLEANED
			)),
			_check(campaign.has_evidence(
				CampaignState.EVIDENCE_SMALL_COLONY_STABLE
			)),
		]
	return tr("R10_OBJECTIVES_ENVIRONMENT") % [
		_check(campaign.has_evidence(
			CampaignState.EVIDENCE_HYDRATION_RESPONSE
		)),
		_check(campaign.has_evidence(
			CampaignState.EVIDENCE_POLLUTION_AVOIDANCE
		)),
		_check(campaign.has_evidence(
			CampaignState.EVIDENCE_PARTIAL_MIGRATION
		)),
		_check(campaign.has_evidence(
			CampaignState.EVIDENCE_ENVIRONMENT_STABLE
		)),
	]


func _evidence_text(campaign: CampaignSnapshot) -> String:
	var lines: PackedStringArray = []
	for evidence_id: StringName in campaign.collected_evidence_ids:
		lines.append("• " + _evidence_name(evidence_id))
	if lines.is_empty():
		lines.append("• " + tr("CAMPAIGN_EVIDENCE_NONE"))
	return "\n".join(lines)


func _evidence_name(evidence_id: StringName) -> String:
	match evidence_id:
		CampaignState.EVIDENCE_QUEEN_CARE:
			return tr("ACT1_EVIDENCE_QUEEN_CARE")
		CampaignState.EVIDENCE_FIRST_PUPA:
			return tr("ACT1_EVIDENCE_FIRST_PUPA")
		CampaignState.EVIDENCE_FIRST_WORKER:
			return tr("ACT1_EVIDENCE_FIRST_WORKER")
		CampaignState.EVIDENCE_FIRST_WORKER_CARE:
			return tr("ACT1_EVIDENCE_WORKER_CARE")
		CampaignState.EVIDENCE_FIRST_NUTRIENT_EXCHANGE:
			return tr("ACT1_EVIDENCE_NUTRIENT")
		CampaignState.EVIDENCE_FORAGING_ZONE_SCOUTED:
			return tr("R10_EVIDENCE_SCOUT")
		CampaignState.EVIDENCE_FORAGING_SUGAR_CYCLE:
			return tr("R10_EVIDENCE_SUGAR")
		CampaignState.EVIDENCE_PROTEIN_CARE:
			return tr("R10_EVIDENCE_PROTEIN")
		CampaignState.EVIDENCE_WASTE_TRAY_CLEANED:
			return tr("R10_EVIDENCE_WASTE")
		CampaignState.EVIDENCE_SMALL_COLONY_STABLE:
			return tr("R10_EVIDENCE_SCALE")
		CampaignState.EVIDENCE_HYDRATION_RESPONSE:
			return tr("R10_EVIDENCE_HYDRATION")
		CampaignState.EVIDENCE_POLLUTION_AVOIDANCE:
			return tr("R10_EVIDENCE_POLLUTION")
		CampaignState.EVIDENCE_PARTIAL_MIGRATION:
			return tr("R10_EVIDENCE_MIGRATION")
		CampaignState.EVIDENCE_ENVIRONMENT_STABLE:
			return tr("R10_EVIDENCE_STABLE")
	return tr("CAMPAIGN_EVIDENCE_UNKNOWN")


func _guidance_text(campaign: CampaignSnapshot) -> String:
	if campaign.completed:
		return tr("ACT1_GUIDANCE_COMPLETE")
	if campaign.status == CampaignState.Status.AWAITING_INFERENCE:
		return tr("ACT1_GUIDANCE_INFERENCE")
	if campaign.chapter == CampaignState.Chapter.ACT1_FOUNDING:
		if not _latest_snapshot.act1.queen_care.light_cover_applied:
			return tr("ACT1_GUIDANCE_COVER")
		return tr("ACT1_GUIDANCE_WATCH_QUEEN")
	if _latest_snapshot.act1.first_worker_emerged_tick < 0:
		return tr("ACT1_GUIDANCE_WAIT_WORKER")
	if campaign.chapter == CampaignState.Chapter.ACT1_FORAGING_EXPANSION:
		return tr("R10_GUIDANCE_FORAGING")
	if (
		campaign.chapter
		== CampaignState.Chapter.ACT1_ENVIRONMENT_MANAGEMENT
	):
		return tr("R10_GUIDANCE_ENVIRONMENT")
	if _latest_snapshot.nutrition.sugar_action_available:
		return tr("ACT1_GUIDANCE_PLACE_SUGAR")
	return tr("ACT1_GUIDANCE_WATCH_WORKER")


func _campaign_status(campaign: CampaignSnapshot) -> String:
	if campaign.completed:
		return tr("CAMPAIGN_STATUS_COMPLETE")
	if campaign.inference_action_pending:
		return tr("CAMPAIGN_STATUS_INFERENCE_PENDING")
	if campaign.status == CampaignState.Status.AWAITING_INFERENCE:
		return tr("CAMPAIGN_STATUS_AWAITING_INFERENCE")
	return tr("CAMPAIGN_STATUS_COLLECTING")


func _hint_text(campaign: CampaignSnapshot) -> String:
	if campaign.completed:
		return tr("CAMPAIGN_HINT_COMPLETE")
	if campaign.status != CampaignState.Status.AWAITING_INFERENCE:
		return tr("CAMPAIGN_HINT_OBSERVE")
	var keys: PackedStringArray = [
		"CAMPAIGN_HINT_COMPARE",
		"ACT1_HINT_DIRECTION",
		"ACT1_HINT_OPERATION",
		"ACT1_HINT_EXPLICIT",
	]
	return tr(keys[mini(campaign.hint_tier, keys.size() - 1)])


func _inference_text(inference_id: StringName) -> String:
	match inference_id:
		CampaignState.INFERENCE_QUEEN_CARE:
			return tr("ACT1_INFERENCE_QUEEN_CARE")
		CampaignState.INFERENCE_QUEEN_CARE_RANDOM:
			return tr("ACT1_INFERENCE_QUEEN_RANDOM")
		CampaignState.INFERENCE_QUEEN_CARE_DIRECTED:
			return tr("ACT1_INFERENCE_QUEEN_DIRECTED")
		CampaignState.INFERENCE_WORKER_NUTRITION:
			return tr("ACT1_INFERENCE_WORKER_NUTRITION")
		CampaignState.INFERENCE_WORKER_NUTRITION_RANDOM:
			return tr("ACT1_INFERENCE_WORKER_RANDOM")
		CampaignState.INFERENCE_WORKER_NUTRITION_DIRECTED:
			return tr("ACT1_INFERENCE_WORKER_DIRECTED")
		CampaignState.INFERENCE_FORAGING_ROLES:
			return tr("R10_INFERENCE_FORAGING")
		CampaignState.INFERENCE_FORAGING_RANDOM:
			return tr("R10_INFERENCE_FORAGING_RANDOM")
		CampaignState.INFERENCE_FORAGING_DIRECTED:
			return tr("R10_INFERENCE_FORAGING_DIRECTED")
		CampaignState.INFERENCE_ENVIRONMENT_GRADIENT:
			return tr("R10_INFERENCE_ENVIRONMENT")
		CampaignState.INFERENCE_ENVIRONMENT_MAXIMUM:
			return tr("R10_INFERENCE_ENVIRONMENT_MAX")
		CampaignState.INFERENCE_GRADIENT_DIRECTED:
			return tr("R10_INFERENCE_ENVIRONMENT_DIRECTED")
	return tr("CAMPAIGN_INFERENCE_UNKNOWN")


func _queen_activity() -> String:
	match _latest_snapshot.act1.queen_care.care_state:
		Act1State.QueenCareState.RESTING:
			return tr("ACT1_QUEEN_RESTING")
		Act1State.QueenCareState.GATHERING:
			return tr("ACT1_QUEEN_GATHERING")
		Act1State.QueenCareState.BROOD_CARE:
			return tr("ACT1_QUEEN_CARING")
	return ""


func _worker_activity(worker: AntSnapshot) -> String:
	if (
		worker.waste_cleanup_task != null
		and worker.waste_cleanup_task.state
			!= WasteCleanupTaskModel.State.IDLE
	):
		return tr("R9_WORKER_CLEANING")
	if (
		worker.scout_task != null
		and worker.scout_task.state != ScoutTaskModel.State.IDLE
	):
		return tr("R9_WORKER_SCOUTING")
	if (
		worker.migration_task != null
		and worker.migration_task.state != MigrationTaskModel.State.IDLE
	):
		return tr("R9_WORKER_MIGRATING")
	if (
		worker.feeding_task != null
		and worker.feeding_task.state != BroodFeedingTaskModel.State.IDLE
	):
		return tr("ACT1_WORKER_FEEDING")
	if (
		worker.foraging_task != null
		and worker.foraging_task.state != ForagingTaskSnapshot.State.IDLE
	):
		return tr("ACT1_WORKER_FORAGING")
	return tr("ACT1_WORKER_RESTING")


func _check(done: bool) -> String:
	return "✓" if done else "○"


func _refresh_copy() -> void:
	_title_label.text = tr("ACT1_TITLE")
	_objective_heading.text = tr("ACT1_OBJECTIVE_HEADING")
	_evidence_heading.text = tr("ACT1_EVIDENCE_HEADING")
	_cover_button.text = tr("ACT1_TOOL_COVER")
	_magnifier_button.text = tr("ACT1_TOOL_MAGNIFIER")
	_sugar_button.text = tr("ACT1_TOOL_SUGAR")
	_protein_button.text = tr("R10_TOOL_PROTEIN")
	_clean_waste_button.text = tr("R9_TOOL_CLEAN_WASTE")
	_layout_button.text = tr("R7_LAYOUT_TOGGLE")
	_rotate_facility_button.text = tr("R7_LAYOUT_ROTATE")
	_remove_facility_button.text = tr("R7_LAYOUT_REMOVE")
	_toggle_gate_button.text = tr("R10_GATE_TOGGLE")
	_reset_camera_button.text = tr("R7_LAYOUT_RESET_CAMERA")
	_journal_button.text = tr("CAMPAIGN_JOURNAL_OPEN")
	_preparation_heading.text = tr("ACT1_PREPARATION_HEADING")
	_preparation_body.text = tr("ACT1_PREPARATION_BODY")
	_start_button.text = tr("UI_START_OBSERVATION")
	_journal_heading.text = tr("CAMPAIGN_JOURNAL_HEADING")
	_journal_close_button.text = tr("CAMPAIGN_JOURNAL_CLOSE")
	_completion_heading.text = tr("ACT1_COMPLETION_HEADING")
	_completion_body.text = tr("ACT1_COMPLETION_BODY")
	_continue_button.text = tr("ACT1_CONTINUE_FREEPLAY")
	_pause_heading.text = tr("UI_PAUSE_HEADING")
	_resume_button.text = tr("UI_RESUME")
	_save_button.text = tr("UI_SAVE_GAME")
	_return_button.text = tr("UI_SAVE_RETURN_TITLE")
	_restart_button.text = tr("UI_RESTART_CHAPTER")
	_exit_button.text = tr("UI_EXIT")
	if _latest_snapshot != null:
		_update_main_panel()
		_update_journal()
		_update_controls()
		_update_inspector()


func _set_fatal_error(message: String) -> void:
	_fatal_error = message
	if _simulation_clock != null:
		_simulation_clock.set_paused(true)
	_status_label.text = "%s %s" % [
		tr("ERROR_INCOMPLETE_SNAPSHOT"),
		message,
	]
	_status_label.modulate = Color(1.0, 0.55, 0.46)


func create_profile_envelope(saved_at_utc: String = "") -> Dictionary:
	if (
		_preparation_gate_active
		or not _fatal_error.is_empty()
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
	if (
		_simulation_clock != null
		and _simulation_clock.tick_requested.is_connected(
			_on_tick_requested
		)
	):
		_simulation_clock.tick_requested.disconnect(_on_tick_requested)
	_colony_simulation = simulation
	_simulation_clock = SimulationClock.new()
	_simulation_clock.tick_requested.connect(_on_tick_requested)
	_fatal_error = ""
	_magnifier_active = false
	_completion_dismissed = false
	_habitat_view.reset_projection()
	_habitat_view.set_layout_mode(false)
	_apply_snapshot()
	_simulation_clock.set_paused(true)
	_enter_preparation_gate()
	return _fatal_error.is_empty()


func restore_loaded_session(
	simulation: ColonySimulation,
	clock: SimulationClock
) -> bool:
	if (
		simulation == null
		or clock == null
		or not simulation.is_ready()
		or simulation.create_snapshot().scenario_id != &"act1_test_tube"
		or simulation.create_snapshot().simulation_tick
			!= clock.get_tick_index()
	):
		return false
	if (
		_simulation_clock != null
		and _simulation_clock.tick_requested.is_connected(
			_on_tick_requested
		)
	):
		_simulation_clock.tick_requested.disconnect(_on_tick_requested)
	_colony_simulation = simulation
	_simulation_clock = clock
	_simulation_clock.tick_requested.connect(_on_tick_requested)
	_preparation_gate_active = false
	_preparation_gate.visible = false
	_fatal_error = ""
	_habitat_view.set_layout_mode(false)
	_completion_dismissed = false
	_habitat_view.reset_projection()
	_apply_snapshot()
	if not _fatal_error.is_empty():
		return false
	_pause_menu_open = _simulation_clock.is_paused()
	_pause_menu.visible = _pause_menu_open
	_habitat_view.set_visuals_paused(_simulation_clock.is_paused())
	_update_controls()
	return true


func apply_external_settings(settings: DemoSettingsState) -> void:
	if settings == null:
		return
	_settings_state = settings
	provided_settings_state = settings
	_apply_ui_scale()
	_habitat_view.set_reduced_motion(settings.is_reduced_motion())
	_refresh_copy()


func _apply_ui_scale() -> void:
	if _settings_state == null:
		return
	var scale_factor: float = _settings_state.get_ui_scale_factor()
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


func report_profile_save_result(success: bool) -> void:
	_save_status.text = (
		tr("PROFILE_SAVE_SUCCESS")
		if success
		else tr("PROFILE_SAVE_FAILURE")
	)
	_save_status.modulate = (
		Color(0.68, 0.9, 0.72)
		if success
		else Color(1.0, 0.62, 0.52)
	)
	_save_status.visible = true


func get_latest_snapshot() -> GameSnapshot:
	return _latest_snapshot


func get_colony_simulation() -> ColonySimulation:
	return _colony_simulation


func get_simulation_clock() -> SimulationClock:
	return _simulation_clock


func get_simulation_tick() -> int:
	return (
		_latest_snapshot.simulation_tick
		if _latest_snapshot != null else 0
	)


func is_simulation_paused() -> bool:
	return (
		_simulation_clock == null or _simulation_clock.is_paused()
	)


func is_pause_menu_open() -> bool:
	return _pause_menu_open
