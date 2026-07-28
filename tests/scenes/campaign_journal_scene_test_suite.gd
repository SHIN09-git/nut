class_name CampaignJournalSceneTestSuite
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
	_test_wrong_then_correct_inference_uses_real_controls()
	_test_journal_fits_supported_minimum_viewport_at_150_percent()


func get_assertion_count() -> int:
	return _assertion_count


func get_failure_count() -> int:
	return _failure_count


func _test_wrong_then_correct_inference_uses_real_controls() -> void:
	var controller: CombinedObservationController = _create_controller(1.0)
	var journal_button: Button = controller.get_node("%JournalButton") as Button
	var journal_panel: Control = controller.get_node("%JournalPanel") as Control
	var first_choice: Button = (
		controller.get_node("%InferenceButton1") as Button
	)
	var wrong_choice: Button = (
		controller.get_node("%InferenceButton2") as Button
	)
	var hint_label: Label = controller.get_node("%JournalHintLabel") as Label

	(controller.get_node("%StartObservationButton") as Button).pressed.emit()
	var emergence_ticks: int = (
		SPECIES_A_DATA.pupa_duration_ticks
		- COMBINED_SCENARIO_DATA.sequence_data
			.first_worker_initial_pupa_age_ticks
	)
	for tick_index: int in range(emergence_ticks):
		controller._process(SimulationClock.FIXED_STEP_SECONDS)

	_expect_int(
		controller._latest_snapshot.campaign.status,
		CampaignState.Status.AWAITING_INFERENCE,
		"first-worker evidence authoritatively opens the journal inference"
	)
	journal_button.pressed.emit()
	_expect_true(journal_panel.visible, "journal button opens the modal")
	_expect_true(
		first_choice.visible and wrong_choice.visible,
		"journal exposes explicit inference choices after evidence"
	)
	_expect_true(
		controller.get_viewport().gui_get_focus_owner() == first_choice,
		"journal gives keyboard focus to the first available inference"
	)
	_expect_string_name(
		StringName(wrong_choice.get_meta(&"campaign_inference_id", "")),
		CampaignState.INFERENCE_FIRST_WORKER_RANDOM,
		"second visible choice carries the explicit wrong inference ID"
	)
	var hint_before: String = hint_label.text
	var submission_tick: int = (
		controller._latest_snapshot.simulation_tick
	)
	wrong_choice.pressed.emit()
	_expect_true(
		controller._latest_snapshot.campaign.inference_action_pending,
		"wrong choice uses the queued simulation command boundary"
	)
	_expect_int(
		controller._latest_snapshot.campaign.incorrect_inference_attempts,
		0,
		"submitting a choice does not mutate campaign authority immediately"
	)
	controller._process(SimulationClock.FIXED_STEP_SECONDS)
	_expect_int(
		controller._latest_snapshot.simulation_tick,
		submission_tick + 1,
		"queued journal choice applies on the next fixed Tick"
	)
	_expect_int(
		controller._latest_snapshot.campaign.hint_tier,
		1,
		"wrong inference reveals one recoverable hint tier"
	)
	_expect_true(
		hint_label.text != hint_before,
		"journal visibly updates its hint after an incorrect inference"
	)
	_expect_string_name(
		StringName(
			hint_label.get_meta(
				CombinedObservationController.COPY_ROLE_META_KEY,
				&""
			)
		),
		CombinedObservationController.COPY_ROLE_OBSERVATION_CUE,
		"hint remains an observation cue rather than a pre-event conclusion"
	)

	var escape: InputEventKey = InputEventKey.new()
	escape.keycode = KEY_ESCAPE
	escape.pressed = true
	controller._input(escape)
	_expect_true(not journal_panel.visible, "Escape closes the journal modal")
	_expect_true(
		controller.get_viewport().gui_get_focus_owner() == journal_button,
		"closing the journal restores keyboard focus to its opener"
	)
	journal_button.pressed.emit()
	first_choice.pressed.emit()
	_expect_true(
		controller._latest_snapshot.campaign.inference_action_pending,
		"correct inference also queues through the real button"
	)
	controller._process(SimulationClock.FIXED_STEP_SECONDS)
	var chapter_two: CampaignSnapshot = controller._latest_snapshot.campaign
	_expect_int(
		chapter_two.chapter,
		CampaignState.Chapter.ENVIRONMENTAL_CARE,
		"correct first inference advances the explicit chapter"
	)
	_expect_true(
		chapter_two.has_unlocked_facility(
			CampaignState.FACILITY_MICRO_FEEDING_PORT
		),
		"correct inference unlocks the chapter facility kit"
	)
	_expect_true(
		not first_choice.visible and not wrong_choice.visible,
		"inference controls hide until the next evidence boundary"
	)
	_destroy_controller(controller)


func _test_journal_fits_supported_minimum_viewport_at_150_percent() -> void:
	var controller: CombinedObservationController = _create_controller(1.5)
	(controller.get_node("%StartObservationButton") as Button).pressed.emit()
	var emergence_ticks: int = (
		SPECIES_A_DATA.pupa_duration_ticks
		- COMBINED_SCENARIO_DATA.sequence_data
			.first_worker_initial_pupa_age_ticks
	)
	for tick_index: int in range(emergence_ticks):
		controller._process(SimulationClock.FIXED_STEP_SECONDS)
	(controller.get_node("%JournalButton") as Button).pressed.emit()
	_settle_container_layout(controller)
	var panel: Control = controller.get_node(
		"JournalPanel/Center/Panel"
	) as Control
	var close_button: Button = (
		controller.get_node("%JournalCloseButton") as Button
	)
	var inference_button: Button = (
		controller.get_node("%InferenceButton1") as Button
	)
	var viewport_rect: Rect2 = Rect2(Vector2.ZERO, controller.size)
	_expect_true(
		viewport_rect.encloses(panel.get_global_rect()),
		"150 percent journal panel fits inside 1280x720"
	)
	_expect_true(
		viewport_rect.encloses(close_button.get_global_rect()),
		"150 percent journal close action remains visible"
	)
	_expect_true(
		inference_button.is_visible_in_tree(),
		"150 percent journal keeps inference actions in its scrollable body"
	)
	_destroy_controller(controller)


func _create_controller(ui_scale: float) -> CombinedObservationController:
	var settings: DemoSettingsState = DemoSettingsState.new(
		"zh_CN",
		Vector2i(1280, 720),
		false,
		ui_scale
	)
	var controller: CombinedObservationController = (
		COMBINED_SCENE.instantiate() as CombinedObservationController
	)
	controller.provided_settings_state = settings
	_scene_root.add_child(controller)
	controller.set_anchors_preset(Control.PRESET_TOP_LEFT)
	controller.position = Vector2.ZERO
	controller.size = Vector2(1280.0, 720.0)
	_settle_container_layout(controller)
	return controller


func _destroy_controller(controller: CombinedObservationController) -> void:
	_scene_root.remove_child(controller)
	controller.free()


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
