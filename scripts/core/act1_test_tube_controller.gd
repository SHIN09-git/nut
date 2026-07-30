class_name Act1TestTubeController
extends Control

signal application_exit_requested
signal save_profile_requested
signal return_to_title_requested
signal settings_changed(settings: DemoSettingsState)
signal presentation_audio_cue_requested(cue_id: StringName)

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
var _help_open: bool = false
var _help_was_clock_paused: bool = false
var _help_return_focus: Control
var _magnifier_active: bool = false
var _completion_dismissed: bool = false
var _fatal_error: String = ""
var _selected_facility_type_id: StringName = (
	CampaignState.FACILITY_SMALL_FORAGING_BOX
)

@onready var _habitat_view: Act1TestTubeView = %Act1TestTubeView
@onready var _top_bar: Act1TopBar = %Header
@onready var _sidebar: Act1ObservationSidebar = %SidePanel
@onready var _tool_bar: Act1ToolBar = %ToolBar
@onready var _preparation_gate: Act1PreparationGate = %PreparationGate
@onready var _journal_panel: Act1JournalPanel = %JournalPanel
@onready var _completion_panel: Act1CompletionPanel = %CompletionPanel
@onready var _help_panel: Act1HelpPanel = %HelpPanel
@onready var _pause_menu: Act1PauseMenu = %PauseMenu
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
	_pause_menu.set_exit_visible(not shell_managed)
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
	if key_event.keycode == KEY_F3 and _debug_controls_available():
		_debug_panel.visible = not _debug_panel.visible
		_update_debug()
		get_viewport().set_input_as_handled()
	elif (
		_settings_state != null
		and key_event.keycode == _settings_state.get_key_binding(
			DemoSettingsState.ACTION_HELP
		)
	):
		if _help_open:
			_close_help()
		elif not _pause_menu_open and not _journal_open:
			_open_help()
		get_viewport().set_input_as_handled()
	elif (
		_settings_state != null
		and key_event.keycode == _settings_state.get_key_binding(
			DemoSettingsState.ACTION_JOURNAL
		)
		and not _preparation_gate_active
		and not _pause_menu_open
		and not _help_open
	):
		if _journal_open:
			_close_journal()
		else:
			_open_journal()
		get_viewport().set_input_as_handled()
	elif (
		_settings_state != null
		and key_event.keycode == _settings_state.get_key_binding(
			DemoSettingsState.ACTION_LAYOUT
		)
		and not _preparation_gate_active
		and not _pause_menu_open
		and not _journal_open
		and not _help_open
	):
		_set_facility_layout_mode(not _habitat_view.is_layout_mode())
		get_viewport().set_input_as_handled()
	elif (
		key_event.keycode == KEY_P
		and _habitat_view.is_layout_mode()
		and not _preparation_gate_active
		and not _pause_menu_open
		and not _journal_open
		and not _help_open
	):
		_on_place_box_pressed()
		get_viewport().set_input_as_handled()
	elif (
		_habitat_view.is_layout_mode()
		and not _preparation_gate_active
		and not _pause_menu_open
		and not _journal_open
		and not _help_open
		and _habitat_view.handle_layout_keyboard_action(
			key_event.keycode
		)
	):
		get_viewport().set_input_as_handled()
	elif key_event.keycode == KEY_ESCAPE:
		if _help_open:
			_close_help()
		elif _journal_open:
			_close_journal()
		elif _pause_menu_open:
			_close_pause_menu()
		else:
			_open_pause_menu()
		get_viewport().set_input_as_handled()


func _debug_controls_available() -> bool:
	return OS.is_debug_build()


func _connect_controls() -> void:
	_preparation_gate.start_requested.connect(_on_start_pressed)
	_top_bar.help_requested.connect(_open_help)
	_help_panel.close_requested.connect(_close_help)
	_top_bar.pause_requested.connect(_open_pause_menu)
	_pause_menu.resume_requested.connect(_close_pause_menu)
	_pause_menu.save_requested.connect(_on_save_pressed)
	_pause_menu.return_requested.connect(_on_return_pressed)
	_pause_menu.restart_requested.connect(_restart_session)
	_pause_menu.exit_requested.connect(_on_exit_pressed)
	_top_bar.speed_requested.connect(_set_speed)
	_tool_bar.cover_requested.connect(_on_cover_pressed)
	_tool_bar.magnifier_requested.connect(_on_magnifier_pressed)
	_tool_bar.sugar_requested.connect(_on_sugar_pressed)
	_tool_bar.protein_requested.connect(_on_protein_pressed)
	_tool_bar.clean_waste_requested.connect(_on_clean_waste_pressed)
	_tool_bar.layout_requested.connect(_set_facility_layout_mode)
	_tool_bar.placement_requested.connect(_on_place_box_pressed)
	_tool_bar.facility_type_selected.connect(
		_on_facility_type_selected
	)
	_tool_bar.rotate_requested.connect(
		_habitat_view.request_rotate_selected_facility
	)
	_tool_bar.remove_requested.connect(
		_habitat_view.request_remove_selected_facility
	)
	_tool_bar.gate_toggle_requested.connect(_on_toggle_gate_pressed)
	_tool_bar.zoom_out_requested.connect(_habitat_view.zoom_layout_out)
	_tool_bar.camera_reset_requested.connect(
		_habitat_view.reset_layout_camera
	)
	_tool_bar.zoom_in_requested.connect(_habitat_view.zoom_layout_in)
	_sidebar.journal_requested.connect(_open_journal)
	_journal_panel.close_requested.connect(_close_journal)
	_journal_panel.inference_requested.connect(
		_on_inference_requested
	)
	_completion_panel.continue_requested.connect(
		_on_continue_freeplay_pressed
	)
	_completion_panel.return_requested.connect(_on_return_pressed)
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
		func(facility_id: int) -> void:
			if facility_id >= 0:
				_habitat_view.set_selected_worker_id(-1)
				_magnifier_active = true
				_sidebar.set_inspector_visible(true)
			_update_inspector()
			_update_controls()
	)
	_habitat_view.facility_feedback_requested.connect(
		_on_facility_feedback_requested
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
	var previous_chapter: int = -1
	var previous_report_available: bool = false
	if (
		_latest_snapshot != null
		and _latest_snapshot.campaign != null
		and _latest_snapshot.act1 != null
	):
		previous_chapter = _latest_snapshot.campaign.chapter
		previous_report_available = (
			_latest_snapshot.act1.final_report_available
		)
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
	if (
		previous_chapter >= 0
		and not previous_report_available
		and _latest_snapshot.act1.final_report_available
	):
		presentation_audio_cue_requested.emit(&"report_reveal")
	elif (
		previous_chapter >= 0
		and previous_chapter != _latest_snapshot.campaign.chapter
	):
		presentation_audio_cue_requested.emit(&"chapter_complete")


func _enter_preparation_gate() -> void:
	_preparation_gate_active = true
	_preparation_gate.open()
	_pause_menu.close()
	_pause_menu_open = false
	_journal_panel.close()
	_journal_open = false
	_completion_panel.visible = false


func _on_start_pressed() -> void:
	if not _fatal_error.is_empty():
		return
	_preparation_gate_active = false
	_preparation_gate.visible = false
	_simulation_clock.set_paused(false)
	_habitat_view.set_visuals_paused(false)
	_tool_bar.focus_primary_action()
	_update_controls()
	presentation_audio_cue_requested.emit(&"ui_confirm")


func _on_cover_pressed() -> void:
	if _colony_simulation.submit_apply_light_cover_action():
		_apply_snapshot()
		_sidebar.set_guidance_text(
			tr("ACT1_FEEDBACK_COVER_PENDING")
		)
		presentation_audio_cue_requested.emit(&"glass_tap")


func _on_sugar_pressed() -> void:
	if _colony_simulation.submit_place_sugar_action():
		_apply_snapshot()
		_sidebar.set_guidance_text(
			tr("ACT1_FEEDBACK_SUGAR_PENDING")
		)
		presentation_audio_cue_requested.emit(&"ui_confirm")


func _on_protein_pressed() -> void:
	if _colony_simulation.submit_place_protein_action():
		_apply_snapshot()
		_sidebar.set_guidance_text(
			tr("R10_FEEDBACK_PROTEIN_PENDING")
		)
		presentation_audio_cue_requested.emit(&"ui_confirm")


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
		_sidebar.set_guidance_text(tr("R9_CLEAN_WASTE_PENDING"))
		presentation_audio_cue_requested.emit(&"facility_place")


func _set_facility_layout_mode(value: bool) -> void:
	_habitat_view.set_layout_mode(value)
	if not value:
		_habitat_view.cancel_facility_placement()
	_tool_bar.set_layout_enabled(value)
	_update_controls()


func _on_place_box_pressed() -> void:
	if _habitat_view.begin_facility_placement(
		_selected_facility_type_id
	):
		_tool_bar.set_layout_enabled(true)
		_update_controls()


func _on_facility_type_selected(index: int) -> void:
	if (
		index < 0
		or index >= _tool_bar.facility_type_option.item_count
	):
		return
	_selected_facility_type_id = StringName(
		_tool_bar.facility_type_option.get_item_metadata(index)
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
			_sidebar.set_guidance_text(
				tr("R10_FEEDBACK_GATE_PENDING")
			)
			presentation_audio_cue_requested.emit(&"gate_toggle")
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
		_sidebar.set_guidance_text(tr("R7_LAYOUT_ACTION_PENDING"))
		_show_action_feedback("R13_ACTION_QUEUED", false)
		presentation_audio_cue_requested.emit(
			&"water_drop"
			if type_id == CampaignState.FACILITY_HYDRATION_MODULE
			else &"facility_place"
		)
	else:
		_show_action_feedback("R13_ACTION_UNAVAILABLE", true)


func _on_facility_rotation_requested(
	facility_id: int,
	orientation: int
) -> void:
	if _colony_simulation.submit_rotate_facility_action(
		facility_id,
		orientation
	):
		_apply_snapshot()
		_sidebar.set_guidance_text(tr("R7_LAYOUT_ACTION_PENDING"))
		_show_action_feedback("R13_ACTION_QUEUED", false)
		presentation_audio_cue_requested.emit(&"facility_place")
	else:
		_show_action_feedback("R13_ACTION_UNAVAILABLE", true)


func _on_facility_removal_requested(facility_id: int) -> void:
	if _colony_simulation.submit_remove_facility_action(facility_id):
		_apply_snapshot()
		_sidebar.set_guidance_text(tr("R7_LAYOUT_ACTION_PENDING"))
		_show_action_feedback("R13_ACTION_QUEUED", false)
		presentation_audio_cue_requested.emit(&"facility_place")
	else:
		_show_action_feedback("R13_ACTION_UNAVAILABLE", true)


func _on_magnifier_pressed() -> void:
	_magnifier_active = not _magnifier_active
	_sidebar.set_inspector_visible(_magnifier_active)
	_update_inspector()
	_update_controls()


func _on_worker_selected(entity_id: int) -> void:
	_habitat_view.set_selected_worker_id(entity_id)
	_magnifier_active = true
	_sidebar.set_inspector_visible(true)
	_update_inspector()
	_update_controls()


func _open_journal() -> void:
	if _preparation_gate_active or _pause_menu_open or _help_open:
		return
	_journal_open = true
	_simulation_clock.set_paused(true)
	_habitat_view.set_visuals_paused(true)
	_update_journal()
	presentation_audio_cue_requested.emit(&"journal_open")
	_journal_panel.open_and_focus()
	_update_controls()


func _close_journal() -> void:
	_journal_open = false
	_journal_panel.close()
	if not _pause_menu_open and not _preparation_gate_active:
		_simulation_clock.set_paused(false)
		_habitat_view.set_visuals_paused(false)
	_sidebar.focus_journal_button()
	_update_controls()


func _on_inference_requested(inference_id: StringName) -> void:
	if (
		not inference_id.is_empty()
		and _colony_simulation.submit_campaign_inference_action(
			inference_id
		)
	):
		_apply_snapshot()
		_journal_panel.show_submitted_status(
			tr("CAMPAIGN_INFERENCE_SUBMITTED")
		)
		presentation_audio_cue_requested.emit(&"ui_confirm")


func _open_pause_menu() -> void:
	if _preparation_gate_active or _journal_open or _help_open:
		return
	_pause_menu_open = true
	_simulation_clock.set_paused(true)
	_habitat_view.set_visuals_paused(true)
	_pause_menu.open_and_focus()
	_update_controls()


func _close_pause_menu() -> void:
	_pause_menu_open = false
	_pause_menu.close()
	if not _preparation_gate_active and not _journal_open:
		_simulation_clock.set_paused(false)
		_habitat_view.set_visuals_paused(false)
	_top_bar.focus_pause_button()
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
	_top_bar.chapter_label.text = _chapter_name(campaign.chapter)
	_sidebar.set_observation_text(
		_current_observation_text(campaign),
		_recent_evidence_text(campaign),
		_guidance_text(campaign)
	)
	if campaign.completed and _latest_snapshot.act1.final_report_available:
		_completion_panel.set_body(_completion_report_text())
	_completion_panel.visible = (
		campaign.completed
		and not _preparation_gate_active
		and not _completion_dismissed
	)


func _open_help() -> void:
	if _help_open or _pause_menu_open or _journal_open:
		return
	_help_return_focus = get_viewport().gui_get_focus_owner()
	_help_was_clock_paused = (
		true
		if _simulation_clock == null
		else _simulation_clock.is_paused()
	)
	_help_open = true
	_help_panel.open_and_focus()
	if _simulation_clock != null:
		_simulation_clock.set_paused(true)
	_habitat_view.set_visuals_paused(true)
	_update_help_copy()
	_update_controls()


func _close_help() -> void:
	if not _help_open:
		return
	_help_open = false
	_help_panel.close()
	if (
		_simulation_clock != null
		and not _preparation_gate_active
		and not _pause_menu_open
	):
		_simulation_clock.set_paused(_help_was_clock_paused)
		_habitat_view.set_visuals_paused(_help_was_clock_paused)
	if (
		is_instance_valid(_help_return_focus)
		and _help_return_focus.is_visible_in_tree()
		and _help_return_focus.focus_mode != Control.FOCUS_NONE
	):
		_help_return_focus.grab_focus()
	else:
		_top_bar.help_button.grab_focus()
	_help_return_focus = null
	_update_controls()


func _update_help_copy() -> void:
	if _settings_state == null:
		return
	_help_panel.set_copy(
		tr("R13_HELP_HEADING"),
		tr("R13_HELP_BODY") % [
			_settings_state.get_key_binding_label(
				DemoSettingsState.ACTION_HELP
			),
			_settings_state.get_key_binding_label(
				DemoSettingsState.ACTION_JOURNAL
			),
			_settings_state.get_key_binding_label(
				DemoSettingsState.ACTION_LAYOUT
			),
		],
		tr("R13_HELP_CLOSE")
	)


func _on_facility_feedback_requested(feedback: int) -> void:
	match feedback:
		FacilityLayoutView.InteractionFeedback.PLACEMENT_INVALID:
			_show_action_feedback("R13_LAYOUT_INVALID", true)
		FacilityLayoutView.InteractionFeedback.SELECTION_REQUIRED:
			_show_action_feedback("R13_LAYOUT_SELECT_FIRST", true)
		FacilityLayoutView.InteractionFeedback.ACTION_PENDING:
			_show_action_feedback("R13_LAYOUT_WAIT_PENDING", true)
		_:
			_show_action_feedback("R13_LAYOUT_NO_SUPPLY", true)


func _show_action_feedback(message_key: String, is_error: bool) -> void:
	_tool_bar.set_feedback(tr(message_key), is_error)


func _update_journal() -> void:
	if _latest_snapshot == null:
		return
	var campaign: CampaignSnapshot = _latest_snapshot.campaign
	var inference_ids: Array[StringName] = []
	var inference_labels: Array[String] = []
	for inference_id: StringName in campaign.available_inference_ids:
		inference_ids.append(inference_id)
		inference_labels.append(_inference_text(inference_id))
	_journal_panel.set_content(
		_chapter_name(campaign.chapter),
		campaign.chapter,
		_campaign_status(campaign),
		_objective_text(campaign),
		_evidence_text(campaign),
		_hint_text(campaign),
		inference_ids,
		inference_labels,
		campaign.inference_action_available,
		campaign.inference_action_pending
	)


func _update_controls() -> void:
	if _latest_snapshot == null or _simulation_clock == null:
		return
	var blocked: bool = (
		_preparation_gate_active
		or _pause_menu_open
		or _journal_open
		or _help_open
		or not _fatal_error.is_empty()
	)
	var care: QueenCareSnapshot = _latest_snapshot.act1.queen_care
	_tool_bar.cover_button.disabled = (
		blocked or not care.light_cover_action_available
	)
	_tool_bar.cover_button.text = (
		tr("ACT1_TOOL_COVER_APPLIED")
		if care.light_cover_applied
		else tr("ACT1_TOOL_COVER_PENDING")
			if care.light_cover_action_pending
			else tr("ACT1_TOOL_COVER")
	)
	_tool_bar.sugar_button.visible = (
		_latest_snapshot.campaign.has_unlocked_facility(
			CampaignState.FACILITY_MICRO_FEEDING_PORT
		)
	)
	_tool_bar.sugar_button.disabled = (
		blocked or not _latest_snapshot.nutrition.sugar_action_available
	)
	_tool_bar.protein_button.visible = (
		_latest_snapshot.campaign.has_unlocked_facility(
			CampaignState.FACILITY_PROTEIN_DISH
		)
	)
	_tool_bar.protein_button.disabled = (
		blocked or not _latest_snapshot.nutrition.protein_action_available
	)
	var work: ColonyWorkSnapshot = _latest_snapshot.work
	_tool_bar.clean_waste_button.visible = (
		work != null
		and (
			not work.cleanable_tray_facility_ids.is_empty()
			or work.clean_action_pending_facility_id >= 0
		)
	)
	_tool_bar.clean_waste_button.disabled = (
		blocked
		or work == null
		or work.cleanable_tray_facility_ids.is_empty()
		or work.clean_action_pending_facility_id >= 0
	)
	_tool_bar.clean_waste_button.text = (
		tr("R9_TOOL_CLEAN_WASTE_PENDING")
		if work != null and work.clean_action_pending_facility_id >= 0
		else tr("R9_TOOL_CLEAN_WASTE")
	)
	var layout: HabitatLayoutSnapshot = _latest_snapshot.layout
	var layout_available: bool = layout != null and layout.active
	_tool_bar.layout_button.visible = layout_available
	_tool_bar.layout_button.disabled = blocked or not layout_available
	_tool_bar.set_layout_enabled(_habitat_view.is_layout_mode())
	var layout_mode: bool = _habitat_view.is_layout_mode()
	_update_facility_palette(layout if layout_available else null)
	var selected_supply: FacilitySupplySnapshot = (
		layout.get_supply(_selected_facility_type_id)
		if layout_available
		else null
	)
	_tool_bar.place_button.visible = (
		layout_mode and not _selected_facility_type_id.is_empty()
	)
	_tool_bar.place_button.disabled = (
		blocked
		or not layout_available
		or not _habitat_view.is_layout_mode()
		or layout.action_pending
		or selected_supply == null
		or selected_supply.remaining_count <= 0
	)
	if selected_supply != null:
		_tool_bar.place_button.text = tr("R10_LAYOUT_PLACE_SELECTED") % (
			selected_supply.remaining_count
		)
	var selected_facility: FacilitySnapshot = (
		layout.get_facility(_habitat_view.get_selected_facility_id())
		if layout_available
		else null
	)
	_tool_bar.set_context_text(
		_context_action_text(layout_mode, selected_facility)
	)
	var can_edit_selected: bool = (
		not blocked
		and layout_mode
		and not layout.action_pending
		and selected_facility != null
		and selected_facility.player_removable
	)
	_tool_bar.rotate_button.visible = layout_mode
	_tool_bar.remove_button.visible = layout_mode
	_tool_bar.rotate_button.disabled = not can_edit_selected
	_tool_bar.remove_button.disabled = not can_edit_selected
	var selected_gate: HabitatConnectionSnapshot = (
		_get_selected_gate_connection(layout, selected_facility.facility_id)
		if selected_facility != null
		else null
	)
	_tool_bar.gate_button.visible = layout_mode and selected_gate != null
	_tool_bar.gate_button.disabled = (
		blocked
		or not layout_mode
		or layout.action_pending
		or selected_gate == null
	)
	if selected_gate != null:
		_tool_bar.gate_button.text = (
			tr("R10_GATE_CLOSE")
			if selected_gate.open
			else tr("R10_GATE_OPEN")
		)
	for camera_button: Button in [
		_tool_bar.zoom_out_button,
		_tool_bar.reset_camera_button,
		_tool_bar.zoom_in_button,
	]:
		camera_button.visible = layout_mode
		camera_button.disabled = blocked or not layout_mode
	_tool_bar.magnifier_button.disabled = blocked
	_tool_bar.magnifier_button.button_pressed = _magnifier_active
	_sidebar.set_journal_disabled(
		_preparation_gate_active or _pause_menu_open or _help_open
	)
	var speed: int = _simulation_clock.get_speed_multiplier()
	_top_bar.set_runtime_state(
		_chapter_name(_latest_snapshot.campaign.chapter),
		(
			tr("ACT1_STATUS_PAUSED")
			if _simulation_clock.is_paused()
			else tr("ACT1_STATUS_RUNNING") % speed
		),
		speed,
		blocked,
		_pause_menu_open
			or _journal_open
			or not _fatal_error.is_empty()
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
			CampaignState.FACILITY_DUAL_CHAMBER_NEST,
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
	_tool_bar.facility_type_option.clear()
	for type_id: StringName in available_ids:
		var index: int = _tool_bar.facility_type_option.item_count
		_tool_bar.facility_type_option.add_item(
			_facility_display_name(type_id)
		)
		_tool_bar.facility_type_option.set_item_metadata(
			index,
			String(type_id)
		)
		if type_id == _selected_facility_type_id:
			_tool_bar.facility_type_option.select(index)
	_tool_bar.facility_type_option.visible = (
		_habitat_view.is_layout_mode() and not available_ids.is_empty()
	)
	_tool_bar.facility_type_option.disabled = (
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
		CampaignState.FACILITY_DUAL_CHAMBER_NEST:
			return tr("R11_FACILITY_DUAL_CHAMBER")
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
			_sidebar.set_inspector_text(
				tr("R19_INSPECT_WORKER") % [
					selected_id,
					_worker_activity(worker),
					_zone_display_name(worker.zone_id),
					_carried_item_text(worker),
				]
			)
			return
	var selected_facility_id: int = _habitat_view.get_selected_facility_id()
	if (
		selected_facility_id >= 0
		and _latest_snapshot.layout != null
	):
		var facility: FacilitySnapshot = (
			_latest_snapshot.layout.get_facility(selected_facility_id)
		)
		if facility != null:
			_sidebar.set_inspector_text(
				tr("R19_INSPECT_FACILITY") % [
					_facility_display_name(facility.type_id),
					facility.facility_id,
					_zone_display_name(facility.zone_id),
					_environment_cue_text(facility),
					facility.ports.size(),
					tr(
						"R19_FACILITY_REMOVABLE"
						if facility.player_removable
						else "R19_FACILITY_FIXED"
					),
				]
			)
			return
	var counts: Dictionary[int, int] = {
		AntModel.LifeStage.EGG: 0,
		AntModel.LifeStage.LARVA: 0,
		AntModel.LifeStage.PUPA: 0,
		AntModel.LifeStage.WORKER: 0,
	}
	for ant: AntSnapshot in _latest_snapshot.colony.ants:
		counts[ant.life_stage] += 1
	_sidebar.set_inspector_text(
		tr("ACT1_INSPECT_COLONY") % [
			counts[AntModel.LifeStage.EGG],
			counts[AntModel.LifeStage.LARVA],
			counts[AntModel.LifeStage.PUPA],
			counts[AntModel.LifeStage.WORKER],
			_queen_activity(),
		]
	)


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
		CampaignState.Chapter.ACT1_ENVIRONMENT_MANAGEMENT:
			return tr("R10_CHAPTER_ENVIRONMENT")
		CampaignState.Chapter.ACT1_MODULAR_MIGRATION:
			return tr("R11_CHAPTER_MIGRATION")
		_:
			return tr("R12_CHAPTER_FINALE")


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
	if (
		campaign.chapter
		== CampaignState.Chapter.ACT1_ENVIRONMENT_MANAGEMENT
	):
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
	if campaign.chapter == CampaignState.Chapter.ACT1_MODULAR_MIGRATION:
		return tr("R11_OBJECTIVES_MIGRATION") % [
			_check(campaign.has_evidence(
				CampaignState.EVIDENCE_DUAL_NEST_CONNECTED
			)),
			_check(campaign.has_evidence(
				CampaignState.EVIDENCE_DUAL_NEST_SCOUTED
			)),
			_check(campaign.has_evidence(
				CampaignState.EVIDENCE_CORE_BROOD_MIGRATED
			)),
			_check(campaign.has_evidence(
				CampaignState.EVIDENCE_QUEEN_MIGRATED
			)),
			_check(campaign.has_evidence(
				CampaignState.EVIDENCE_FUNCTIONAL_ZONING
			)),
		]
	return tr("R12_OBJECTIVES_FINALE") % [
		_check(campaign.has_evidence(
			CampaignState.EVIDENCE_FIRST_WORKER_HISTORY
		)),
		_check(campaign.has_evidence(
			CampaignState.EVIDENCE_KEY_INTERVENTIONS
		)),
		_check(campaign.has_evidence(
			CampaignState.EVIDENCE_FINAL_LAYOUT_STABLE
		)),
		_check(campaign.has_evidence(
			CampaignState.EVIDENCE_LONG_TERM_PATTERN
		)),
	]


func _current_observation_text(campaign: CampaignSnapshot) -> String:
	var lines: PackedStringArray = _objective_text(campaign).split("\n")
	for line: String in lines:
		if line.begins_with("○"):
			return line
	if campaign.status == CampaignState.Status.AWAITING_INFERENCE:
		return tr("ACT1_GUIDANCE_INFERENCE")
	return _guidance_text(campaign)


func _evidence_text(campaign: CampaignSnapshot) -> String:
	var lines: PackedStringArray = []
	for evidence_id: StringName in _chapter_evidence_ids(campaign.chapter):
		if campaign.has_evidence(evidence_id):
			lines.append("• " + _evidence_name(evidence_id))
	if lines.is_empty():
		lines.append("• " + tr("CAMPAIGN_EVIDENCE_NONE"))
	return "\n".join(lines)


func _recent_evidence_text(campaign: CampaignSnapshot) -> String:
	var all_lines: PackedStringArray = _evidence_text(campaign).split("\n")
	if all_lines.size() <= 3:
		return "\n".join(all_lines)
	var recent_lines: PackedStringArray = []
	for index: int in range(all_lines.size() - 3, all_lines.size()):
		recent_lines.append(all_lines[index])
	return "\n".join(recent_lines)


func _chapter_evidence_ids(chapter: int) -> Array[StringName]:
	match chapter:
		CampaignState.Chapter.ACT1_FOUNDING:
			return [
				CampaignState.EVIDENCE_QUEEN_CARE,
				CampaignState.EVIDENCE_FIRST_PUPA,
			]
		CampaignState.Chapter.ACT1_FIRST_WORKERS:
			return [
				CampaignState.EVIDENCE_FIRST_WORKER,
				CampaignState.EVIDENCE_FIRST_WORKER_CARE,
				CampaignState.EVIDENCE_FIRST_NUTRIENT_EXCHANGE,
			]
		CampaignState.Chapter.ACT1_FORAGING_EXPANSION:
			return [
				CampaignState.EVIDENCE_FORAGING_ZONE_SCOUTED,
				CampaignState.EVIDENCE_FORAGING_SUGAR_CYCLE,
				CampaignState.EVIDENCE_PROTEIN_CARE,
				CampaignState.EVIDENCE_WASTE_TRAY_CLEANED,
				CampaignState.EVIDENCE_SMALL_COLONY_STABLE,
			]
		CampaignState.Chapter.ACT1_ENVIRONMENT_MANAGEMENT:
			return [
				CampaignState.EVIDENCE_HYDRATION_RESPONSE,
				CampaignState.EVIDENCE_POLLUTION_AVOIDANCE,
				CampaignState.EVIDENCE_PARTIAL_MIGRATION,
				CampaignState.EVIDENCE_ENVIRONMENT_STABLE,
			]
		CampaignState.Chapter.ACT1_MODULAR_MIGRATION:
			return [
				CampaignState.EVIDENCE_DUAL_NEST_CONNECTED,
				CampaignState.EVIDENCE_DUAL_NEST_SCOUTED,
				CampaignState.EVIDENCE_CORE_BROOD_MIGRATED,
				CampaignState.EVIDENCE_QUEEN_MIGRATED,
				CampaignState.EVIDENCE_FUNCTIONAL_ZONING,
			]
		_:
			return [
				CampaignState.EVIDENCE_FIRST_WORKER_HISTORY,
				CampaignState.EVIDENCE_KEY_INTERVENTIONS,
				CampaignState.EVIDENCE_FINAL_LAYOUT_STABLE,
				CampaignState.EVIDENCE_LONG_TERM_PATTERN,
			]


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
		CampaignState.EVIDENCE_DUAL_NEST_CONNECTED:
			return tr("R11_EVIDENCE_CONNECTED")
		CampaignState.EVIDENCE_DUAL_NEST_SCOUTED:
			return tr("R11_EVIDENCE_SCOUTED")
		CampaignState.EVIDENCE_CORE_BROOD_MIGRATED:
			return tr("R11_EVIDENCE_BROOD")
		CampaignState.EVIDENCE_QUEEN_MIGRATED:
			return tr("R11_EVIDENCE_QUEEN")
		CampaignState.EVIDENCE_FUNCTIONAL_ZONING:
			return tr("R11_EVIDENCE_ZONING")
		CampaignState.EVIDENCE_FIRST_WORKER_HISTORY:
			return tr("R12_EVIDENCE_FIRST_WORKER_HISTORY")
		CampaignState.EVIDENCE_KEY_INTERVENTIONS:
			return tr("R12_EVIDENCE_INTERVENTIONS")
		CampaignState.EVIDENCE_FINAL_LAYOUT_STABLE:
			return tr("R12_EVIDENCE_LAYOUT")
		CampaignState.EVIDENCE_LONG_TERM_PATTERN:
			return tr("R12_EVIDENCE_PATTERN")
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
	if (
		campaign.chapter
		== CampaignState.Chapter.ACT1_MODULAR_MIGRATION
	):
		return tr("R11_GUIDANCE_MIGRATION")
	if (
		campaign.chapter
		== CampaignState.Chapter.ACT1_STABLE_COLONY_SUMMARY
	):
		return tr("R12_GUIDANCE_FINALE")
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
	if (
		campaign.chapter
		== CampaignState.Chapter.ACT1_STABLE_COLONY_SUMMARY
	):
		var finale_keys: PackedStringArray = [
			"R12_HINT_COMPARE",
			"R12_HINT_HISTORY",
			"R12_HINT_LAYOUT",
			"R12_HINT_EXPLICIT",
		]
		return tr(
			finale_keys[mini(campaign.hint_tier, finale_keys.size() - 1)]
		)
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
		CampaignState.INFERENCE_MIGRATION_CONDITIONS:
			return tr("R11_INFERENCE_MIGRATION")
		CampaignState.INFERENCE_MIGRATION_DIRECTED:
			return tr("R11_INFERENCE_DIRECTED")
		CampaignState.INFERENCE_MIGRATION_SIZE:
			return tr("R11_INFERENCE_SIZE")
		CampaignState.INFERENCE_LAYOUT_SHAPES_BEHAVIOR:
			return tr("R12_INFERENCE_LAYOUT")
		CampaignState.INFERENCE_FINALE_RANDOM:
			return tr("R12_INFERENCE_RANDOM")
		CampaignState.INFERENCE_FINALE_DIRECTED:
			return tr("R12_INFERENCE_DIRECTED")
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


func _context_action_text(
	layout_mode: bool,
	selected_facility: FacilitySnapshot
) -> String:
	if not layout_mode:
		return tr("R19_CONTEXT_OBSERVATION")
	if selected_facility != null:
		return tr("R19_CONTEXT_FACILITY") % (
			_facility_display_name(selected_facility.type_id)
		)
	return tr("R19_CONTEXT_LAYOUT")


func _zone_display_name(zone_id: StringName) -> String:
	if zone_id.is_empty():
		return tr("R19_ZONE_IN_TRANSIT")
	match zone_id:
		&"test_tube_nest":
			return tr("R19_ZONE_TEST_TUBE")
		&"tube_passage":
			return tr("R19_ZONE_PASSAGE")
		&"foraging_box":
			return tr("R19_ZONE_FORAGING")
	return String(zone_id).replace("_", " ")


func _carried_item_text(worker: AntSnapshot) -> String:
	if worker.carried_brood_id >= 0:
		return tr("R19_CARRYING_BROOD") % worker.carried_brood_id
	if (
		worker.migration_task != null
		and worker.migration_task.carried_entity_id >= 0
	):
		return tr("R19_CARRYING_BROOD") % (
			worker.migration_task.carried_entity_id
		)
	return tr("R19_CARRYING_NONE")


func _environment_cue_text(facility: FacilitySnapshot) -> String:
	var humidity_cue: String = tr("R19_HUMIDITY_BALANCED")
	if facility.zone_humidity < 0.35:
		humidity_cue = tr("R19_HUMIDITY_DRY")
	elif facility.zone_humidity > 0.75:
		humidity_cue = tr("R19_HUMIDITY_DAMP")
	var light_cue: String = (
		tr("R19_LIGHT_SHELTERED")
		if facility.zone_light_exposure < 0.35
		else tr("R19_LIGHT_EXPOSED")
	)
	var pollution_cue: String = (
		tr("R19_POLLUTION_PRESENT")
		if facility.zone_pollution >= 0.3
		else tr("R19_POLLUTION_CLEAR")
	)
	return "%s · %s · %s" % [
		humidity_cue,
		light_cue,
		pollution_cue,
	]


func _completion_report_text() -> String:
	if _latest_snapshot == null:
		return tr("ACT1_COMPLETION_BODY")
	var worker_count: int = 0
	for ant: AntSnapshot in _latest_snapshot.colony.ants:
		if ant.life_stage == AntModel.LifeStage.WORKER:
			worker_count += 1
	return tr("R12_REPORT_BODY") % [
		_format_observation_time(
			_latest_snapshot.act1.first_worker_emerged_tick
		),
		worker_count,
		_latest_snapshot.layout.facilities.size(),
		_latest_snapshot.work.completed_migration_count,
		_latest_snapshot.nutrition.completed_feeding_count,
		_latest_snapshot.work.cleaned_waste_tray_count,
	]


func _format_observation_time(tick: int) -> String:
	var total_seconds: int = maxi(
		0,
		int(floor(float(tick) * SimulationClock.FIXED_STEP_SECONDS))
	)
	return "%02d:%02d" % [total_seconds / 60, total_seconds % 60]


func _check(done: bool) -> String:
	return "✓" if done else "○"


func _refresh_copy() -> void:
	_top_bar.set_copy(
		tr("ACT1_TITLE"),
		tr("R13_HELP_TOOLTIP") % (
			_settings_state.get_key_binding_label(
				DemoSettingsState.ACTION_HELP
			)
			if _settings_state != null else "F1"
		),
		tr("R19_PAUSE_BUTTON")
	)
	_sidebar.set_copy(
		tr("ACT1_OBJECTIVE_HEADING"),
		tr("ACT1_EVIDENCE_HEADING"),
		tr("CAMPAIGN_JOURNAL_OPEN"),
		tr("R19_INSPECTOR_HEADING")
	)
	_tool_bar.set_copy(
		tr("ACT1_TOOL_COVER"),
		tr("ACT1_TOOL_MAGNIFIER"),
		tr("ACT1_TOOL_SUGAR"),
		tr("R10_TOOL_PROTEIN"),
		tr("R9_TOOL_CLEAN_WASTE"),
		tr("R7_LAYOUT_TOGGLE"),
		tr("R7_LAYOUT_ROTATE"),
		tr("R7_LAYOUT_REMOVE"),
		tr("R10_GATE_TOGGLE"),
		tr("R7_LAYOUT_RESET_CAMERA"),
		tr("R19_PROTOTYPE_NOTICE")
	)
	_preparation_gate.set_copy(
		tr("ACT1_PREPARATION_HEADING"),
		tr("ACT1_PREPARATION_BODY"),
		tr("UI_START_OBSERVATION")
	)
	_journal_panel.set_copy(
		tr("CAMPAIGN_JOURNAL_HEADING"),
		tr("CAMPAIGN_JOURNAL_CLOSE")
	)
	_completion_panel.set_copy(
		tr("ACT1_COMPLETION_HEADING"),
		(
			_completion_report_text()
			if (
				_latest_snapshot != null
				and _latest_snapshot.act1.final_report_available
			)
			else tr("ACT1_COMPLETION_BODY")
		),
		tr("ACT1_CONTINUE_FREEPLAY"),
		tr("R12_SAVE_RETURN_TITLE")
	)
	_update_help_copy()
	_pause_menu.set_copy(
		tr("UI_PAUSE_HEADING"),
		tr("UI_RESUME"),
		tr("UI_SAVE_GAME"),
		tr("UI_SAVE_RETURN_TITLE"),
		tr("UI_RESTART_CHAPTER"),
		tr("UI_EXIT")
	)
	if _latest_snapshot != null:
		_update_main_panel()
		_update_journal()
		_update_controls()
		_update_inspector()


func _set_fatal_error(message: String) -> void:
	_fatal_error = message
	if _simulation_clock != null:
		_simulation_clock.set_paused(true)
	_top_bar.show_fatal_status(
		"%s %s" % [
			tr("ERROR_INCOMPLETE_SNAPSHOT"),
			message,
		]
	)


func create_profile_envelope(
	saved_at_utc: String = "",
	profile_playtime: Dictionary = {}
) -> Dictionary:
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
		saved_at_utc,
		profile_playtime
	)


func get_profile_playtime_context() -> Dictionary:
	if (
		_preparation_gate_active
		or not _fatal_error.is_empty()
		or _latest_snapshot == null
		or _latest_snapshot.campaign == null
	):
		return {
			"active": false,
			"chapter": -1,
			"completed": false,
		}
	return {
		"active": true,
		"chapter": int(_latest_snapshot.campaign.chapter),
		"completed": _latest_snapshot.campaign.completed,
	}


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
	_help_open = false
	_help_panel.visible = false
	_help_return_focus = null
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
	_help_open = false
	_help_panel.visible = false
	_help_return_focus = null
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
		_ui_scale_theme = (
			theme.duplicate(true) as Theme
			if theme != null else Theme.new()
		)
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
	_pause_menu.show_save_result(
		(
			tr("PROFILE_SAVE_SUCCESS")
			if success
			else tr("PROFILE_SAVE_FAILURE")
		),
		success
	)


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
