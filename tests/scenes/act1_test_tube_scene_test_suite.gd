class_name Act1TestTubeSceneTestSuite
extends RefCounted

const ACT1_SCENE: PackedScene = preload(
	"res://scenes/main/act1_test_tube.tscn"
)
const ACT1_SCENARIO_DATA: HabitatScenarioData = preload(
	"res://data/habitats/act1_test_tube.tres"
)

var _assertion_count: int = 0
var _failure_count: int = 0
var _scene_root: Node


func run(scene_root: Node) -> void:
	_scene_root = scene_root
	_test_real_controls_complete_both_chapters()
	_test_pause_and_f3_boundaries()
	_test_colony_work_projection()
	_test_waste_tray_clean_button_boundary()
	_test_supported_viewport_layouts()


func get_assertion_count() -> int:
	return _assertion_count


func get_failure_count() -> int:
	return _failure_count


func _test_real_controls_complete_both_chapters() -> void:
	var controller: Act1TestTubeController = _create_controller(
		Vector2(1280, 720)
	)
	var start: Button = controller.get_node(
		"%StartObservationButton"
	) as Button
	var cover: Button = controller.get_node("%CoverButton") as Button
	var sugar: Button = controller.get_node("%SugarButton") as Button
	var journal: Button = controller.get_node("%JournalButton") as Button
	var close_journal: Button = controller.get_node(
		"%JournalCloseButton"
	) as Button
	start.pressed.emit()
	_expect_true(not cover.disabled, "real UI exposes the cover facility")

	var before_cover: GameSnapshot = controller.get_latest_snapshot()
	cover.pressed.emit()
	var submitted: GameSnapshot = controller.get_latest_snapshot()
	_expect_true(
		submitted.act1.queen_care.light_cover_action_pending,
		"cover button submits a queued simulation command"
	)
	_expect_true(
		not submitted.act1.queen_care.light_cover_applied,
		"cover button does not mutate the same Tick"
	)
	controller._process(SimulationClock.FIXED_STEP_SECONDS)
	_expect_int(
		controller.get_latest_snapshot().simulation_tick,
		before_cover.simulation_tick + 1,
		"cover command applies at the next fixed Tick"
	)
	_expect_true(
		controller.get_latest_snapshot().act1.queen_care
			.light_cover_applied,
		"cover becomes authoritative after the Tick"
	)

	_expect_true(
		_process_until(
			controller,
			func(snapshot: GameSnapshot) -> bool:
				return (
					snapshot.campaign.status
					== CampaignState.Status.AWAITING_INFERENCE
				),
			250
		),
		"real observation path reaches the founding inference"
	)
	var view: Act1TestTubeView = controller.get_node(
		"%Act1TestTubeView"
	) as Act1TestTubeView
	var first_pupa_view: AntView = view.get_ant_view(1)
	_expect_true(
		first_pupa_view != null,
		"first-worker entity has a visible stable node before emergence"
	)
	journal.pressed.emit()
	var queen_inference: Button = _find_inference_button(
		controller,
		CampaignState.INFERENCE_QUEEN_CARE
	)
	_expect_true(
		queen_inference != null and not queen_inference.disabled,
		"journal exposes the evidence-backed queen-care inference"
	)
	if queen_inference == null:
		_destroy_controller(controller)
		return
	queen_inference.pressed.emit()
	_expect_true(
		controller.get_latest_snapshot().campaign.inference_action_pending,
		"inference button also uses the next-Tick command boundary"
	)
	close_journal.pressed.emit()
	controller._process(SimulationClock.FIXED_STEP_SECONDS)
	_expect_int(
		controller.get_latest_snapshot().campaign.chapter,
		CampaignState.Chapter.ACT1_FIRST_WORKERS,
		"correct inference enters Chapter 2 through real controls"
	)

	_expect_true(
		_process_until(
			controller,
			func(snapshot: GameSnapshot) -> bool:
				return (
					snapshot.act1.first_worker_emerged_tick >= 0
					and snapshot.nutrition.sugar_action_available
				),
			1000
		),
		"real path reaches first-worker emergence and sugar placement"
	)
	_expect_true(
		view.get_ant_view(1) == first_pupa_view,
		"the first pupa becomes a worker on the same AntView instance"
	)
	_expect_true(
		sugar.visible and not sugar.disabled,
		"micro feeding-port sugar action is visible and enabled"
	)
	var sugar_before: int = (
		controller.get_latest_snapshot()
			.nutrition.total_sugar_portions_supplied
	)
	sugar.pressed.emit()
	_expect_true(
		controller.get_latest_snapshot().nutrition.sugar_action_pending,
		"sugar button queues one high-level action"
	)
	_expect_int(
		controller.get_latest_snapshot()
			.nutrition.total_sugar_portions_supplied,
		sugar_before,
		"sugar is not supplied in the submission Tick"
	)
	controller._process(SimulationClock.FIXED_STEP_SECONDS)
	_expect_int(
		controller.get_latest_snapshot()
			.nutrition.total_sugar_portions_supplied,
		sugar_before + 1,
		"next Tick uses the frozen one-portion sugar action"
	)
	_expect_true(
		_process_until(
			controller,
			func(snapshot: GameSnapshot) -> bool:
				return (
					snapshot.campaign.status
					== CampaignState.Status.AWAITING_INFERENCE
					and snapshot.campaign.chapter
						== CampaignState.Chapter.ACT1_FIRST_WORKERS
				),
			1800
		),
		"real UI path reaches worker care and nutrient exchange"
	)
	journal.pressed.emit()
	var worker_inference: Button = _find_inference_button(
		controller,
		CampaignState.INFERENCE_WORKER_NUTRITION
	)
	_expect_true(
		worker_inference != null and not worker_inference.disabled,
		"journal exposes the final worker-care inference"
	)
	if worker_inference != null:
		worker_inference.pressed.emit()
		close_journal.pressed.emit()
		controller._process(SimulationClock.FIXED_STEP_SECONDS)
	_expect_true(
		not controller.get_latest_snapshot().campaign.completed,
		"real buttons continue from Chapter 2 into Chapter 3"
	)
	_expect_int(
		controller.get_latest_snapshot().campaign.chapter,
		CampaignState.Chapter.ACT1_FORAGING_EXPANSION,
		"real Chapter 2 conclusion opens the small-foraging chapter"
	)
	_expect_true(
		not (controller.get_node("%CompletionPanel") as Control).visible,
		"Act completion stays hidden while later chapters remain"
	)
	_test_layout_controls_after_chapter_two(controller)
	_destroy_controller(controller)


func _test_pause_and_f3_boundaries() -> void:
	var controller: Act1TestTubeController = _create_controller(
		Vector2(1280, 720)
	)
	(controller.get_node("%StartObservationButton") as Button).pressed.emit()
	controller._process(SimulationClock.FIXED_STEP_SECONDS)
	(controller.get_node("%PauseButton") as Button).pressed.emit()
	var paused_tick: int = controller.get_simulation_tick()
	var view: Act1TestTubeView = controller.get_node(
		"%Act1TestTubeView"
	) as Act1TestTubeView
	var alpha_before: float = view._interpolation_alpha
	controller._process(1.0)
	_expect_int(
		controller.get_simulation_tick(),
		paused_tick,
		"pause stops authoritative simulation progress"
	)
	_expect_true(
		view.are_visuals_paused()
			and is_equal_approx(view._interpolation_alpha, alpha_before),
		"pause also freezes view interpolation"
	)
	var debug_panel: Control = controller.get_node("%DebugPanel") as Control
	var f3: InputEventKey = InputEventKey.new()
	f3.keycode = KEY_F3
	f3.pressed = true
	controller._unhandled_input(f3)
	_expect_true(debug_panel.visible, "F3 reveals the Act 1 debug layer")
	controller._unhandled_input(f3)
	_expect_true(not debug_panel.visible, "F3 hides the debug layer")
	_destroy_controller(controller)


func _test_colony_work_projection() -> void:
	var controller: Act1TestTubeController = _create_controller(
		Vector2(1280, 720)
	)
	var snapshot: GameSnapshot = controller.get_latest_snapshot()
	var worker: AntSnapshot = snapshot.colony.ants[0]
	var brood: AntSnapshot = snapshot.colony.ants[1]
	worker.life_stage = AntModel.LifeStage.WORKER
	worker.zone_id = &"test_tube_nest"
	var task := MigrationTaskModel.new()
	task.begin(
		MigrationTaskModel.State.CARRYING_TO_ZONE,
		&"test_tube_nest",
		&"test_tube_nest",
		brood.entity_id,
		&"tube_passage",
		[&"test_tube_nest", &"tube_passage"],
		10
	)
	task.carried_entity_id = brood.entity_id
	task.elapsed_ticks = 5
	worker.migration_task = MigrationTaskSnapshot.new(task)
	brood.zone_id = &""
	brood.carrier_ant_id = worker.entity_id
	var view: Act1TestTubeView = controller.get_node(
		"%Act1TestTubeView"
	) as Act1TestTubeView
	_expect_true(
		view.apply_snapshot(snapshot),
		"Act 1 view accepts a migration task snapshot"
	)
	view.set_interpolation_alpha(1.0)
	var worker_view: AntView = view.get_ant_view(worker.entity_id)
	var brood_view: AntView = view.get_ant_view(brood.entity_id)
	_expect_true(
		worker_view != null and brood_view != null,
		"migration keeps stable worker and brood view nodes"
	)
	if worker_view != null and brood_view != null:
		_expect_vector_near(
			brood_view.position,
			worker_view.position + Vector2(13.0, -12.0),
			0.01,
			"carried brood follows the snapshot-derived worker position"
		)
	_destroy_controller(controller)


func _test_waste_tray_clean_button_boundary() -> void:
	var scenario: HabitatScenarioData = (
		ACT1_SCENARIO_DATA.duplicate(true) as HabitatScenarioData
	)
	var tray := InitialFacilityData.new()
	tray.facility_id = 3
	tray.type_id = &"waste_tray"
	tray.slot = Vector2i(1, 3)
	tray.orientation = 0
	tray.zone_id = &"test_tube_nest"
	tray.available = true
	tray.player_removable = false
	scenario.facility_catalog_data.initial_facilities.append(tray)
	var controller: Act1TestTubeController = _create_controller(
		Vector2(1280, 720),
		1.0,
		scenario
	)
	(controller.get_node("%StartObservationButton") as Button).pressed.emit()
	controller._process(SimulationClock.FIXED_STEP_SECONDS)
	var clean_button: Button = controller.get_node(
		"%CleanWasteButton"
	) as Button
	_expect_true(
		clean_button.visible and not clean_button.disabled,
		"clean tool appears when the authoritative tray is cleanable"
	)
	var before: FacilitySnapshot = (
		controller.get_latest_snapshot().layout.get_facility(3)
	)
	var stored_before: float = before.waste_fill_ratio
	clean_button.pressed.emit()
	var submitted: GameSnapshot = controller.get_latest_snapshot()
	_expect_int(
		submitted.work.clean_action_pending_facility_id,
		3,
		"clean button submits the stable tray ID"
	)
	_expect_true(
		is_equal_approx(
			submitted.layout.get_facility(3).waste_fill_ratio,
			stored_before
		),
		"clean button does not change tray state in the submission Tick"
	)
	controller._process(SimulationClock.FIXED_STEP_SECONDS)
	_expect_int(
		controller.get_latest_snapshot().work.cleaned_waste_tray_count,
		1,
		"clean action is applied by the simulation on the next Tick"
	)
	_destroy_controller(controller)


func _test_supported_viewport_layouts() -> void:
	for viewport_size: Vector2 in [
		Vector2(1280, 720),
		Vector2(1920, 1080),
	]:
		for ui_scale: float in [1.0, 1.5]:
			var controller: Act1TestTubeController = _create_controller(
				viewport_size,
				ui_scale
			)
			(
				controller.get_node("%StartObservationButton") as Button
			).pressed.emit()
			var layout_button: Button = (
				controller.get_node("%LayoutButton") as Button
			)
			layout_button.button_pressed = true
			layout_button.pressed.emit()
			_settle_container_layout(controller)
			var viewport_rect := Rect2(Vector2.ZERO, viewport_size)
			for node_path: String in [
				"%StartObservationButton",
				"%CoverButton",
				"%JournalButton",
				"%LayoutButton",
				"%ResetCameraButton",
				"%ZoomInButton",
			]:
				var control: Control = controller.get_node(node_path) as Control
				_expect_true(
					viewport_rect.encloses(control.get_global_rect()),
					"%s remains inside %dx%d at %d%% UI scale (actual %s)"
						% [
							node_path,
							int(viewport_size.x),
							int(viewport_size.y),
							int(ui_scale * 100.0),
							str(control.get_global_rect()),
						]
				)
			_expect_true(
				not (
					controller.get_node("%LayoutButton") as Control
				).get_global_rect().intersects(
					(
						controller.get_node("%ZoomOutButton") as Control
					).get_global_rect()
				),
				"layout and camera controls do not overlap at %dx%d / %d%%"
					% [
						int(viewport_size.x),
						int(viewport_size.y),
						int(ui_scale * 100.0),
					]
			)
			_destroy_controller(controller)


func _test_layout_controls_after_chapter_two(
	controller: Act1TestTubeController
) -> void:
	var layout_button: Button = controller.get_node("%LayoutButton") as Button
	var place_button: Button = controller.get_node("%PlaceBoxButton") as Button
	var palette: OptionButton = controller.get_node(
		"%FacilityTypeOption"
	) as OptionButton
	var view: Act1TestTubeView = controller.get_node(
		"%Act1TestTubeView"
	) as Act1TestTubeView
	layout_button.button_pressed = true
	layout_button.pressed.emit()
	_expect_true(view.is_layout_mode(), "layout button opens the module view")
	_expect_true(
		place_button.visible and not place_button.disabled,
		"completed Act 1 exposes one placeable foraging box"
	)
	place_button.pressed.emit()
	var option: FacilityPlacementOptionSnapshot
	for candidate: FacilityPlacementOptionSnapshot in (
		controller.get_latest_snapshot().layout.placement_options
	):
		if candidate.type_id == CampaignState.FACILITY_SMALL_FORAGING_BOX:
			option = candidate
			break
	_expect_true(option != null, "layout snapshot provides a valid box slot")
	if option == null:
		return
	var layout_view: FacilityLayoutView = view.get_layout_view()
	var click: InputEventMouseButton = InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	click.position = layout_view._slot_rect(
		option.slot,
		Vector2i.ONE
	).get_center()
	var before_count: int = (
		controller.get_latest_snapshot().layout.facilities.size()
	)
	layout_view._gui_input(click)
	_expect_true(
		controller.get_latest_snapshot().layout.action_pending,
		"mouse placement queues a layout command"
	)
	_expect_int(
		controller.get_latest_snapshot().layout.facilities.size(),
		before_count,
		"mouse placement waits for the next fixed Tick"
	)
	controller._process(SimulationClock.FIXED_STEP_SECONDS)
	_expect_int(
		controller.get_latest_snapshot().layout.facilities.size(),
		before_count + 1,
		"mouse placement creates one facility on the next Tick"
	)

	var zoom_before: float = view.get_layout_camera_zoom()
	var wheel: InputEventMouseButton = InputEventMouseButton.new()
	wheel.button_index = MOUSE_BUTTON_WHEEL_UP
	wheel.pressed = true
	layout_view._gui_input(wheel)
	_expect_true(
		view.get_layout_camera_zoom() > zoom_before,
		"mouse wheel zoom changes only the layout camera"
	)
	var offset_before: Vector2 = view.get_layout_camera_offset()
	_send_key(controller, KEY_D)
	_expect_true(
		view.get_layout_camera_offset() != offset_before,
		"keyboard panning changes the layout camera"
	)
	_expect_int(
		controller.get_latest_snapshot().layout.facilities.size(),
		before_count + 1,
		"camera input cannot mutate simulation layout"
	)

	_send_key(controller, KEY_TAB)
	_expect_true(
		view.get_selected_facility_id() >= 3,
		"Tab selects the removable facility without a mouse"
	)
	_send_key(controller, KEY_DELETE)
	_expect_true(
		controller.get_latest_snapshot().layout.action_pending,
		"Delete queues removal through the keyboard path"
	)
	controller._process(SimulationClock.FIXED_STEP_SECONDS)
	_expect_int(
		controller.get_latest_snapshot().layout.facilities.size(),
		before_count,
		"keyboard removal applies on the next Tick"
	)

	var box_index: int = -1
	for index: int in palette.item_count:
		if (
			StringName(palette.get_item_metadata(index))
			== CampaignState.FACILITY_SMALL_FORAGING_BOX
		):
			box_index = index
			break
	_expect_true(
		box_index >= 0,
		"restored box supply returns to the facility palette"
	)
	if box_index < 0:
		return
	palette.select(box_index)
	palette.item_selected.emit(box_index)
	_send_key(controller, KEY_P)
	_expect_true(layout_view.is_placing(), "P starts keyboard placement")
	_send_key(controller, KEY_ENTER)
	_expect_true(
		controller.get_latest_snapshot().layout.action_pending,
		"Enter queues the selected valid placement"
	)
	controller._process(SimulationClock.FIXED_STEP_SECONDS)
	_expect_int(
		controller.get_latest_snapshot().layout.facilities.size(),
		before_count + 1,
		"keyboard placement completes through the same command boundary"
	)
	var box: FacilitySnapshot
	for facility: FacilitySnapshot in (
		controller.get_latest_snapshot().layout.facilities
	):
		if facility.type_id == CampaignState.FACILITY_SMALL_FORAGING_BOX:
			box = facility
			break
	_expect_true(box != null, "keyboard path leaves one foraging box")
	if box == null:
		return
	var protein_index: int = -1
	for index: int in palette.item_count:
		if (
			StringName(palette.get_item_metadata(index))
			== CampaignState.FACILITY_PROTEIN_DISH
		):
			protein_index = index
			break
	_expect_true(
		protein_index >= 0,
		"Chapter 3 facility palette exposes the protein dish"
	)
	if protein_index < 0:
		return
	palette.select(protein_index)
	palette.item_selected.emit(protein_index)
	place_button.pressed.emit()
	_expect_true(
		layout_view.is_placing(),
		"selected protein dish enters placement mode"
	)
	var protein_option: FacilityPlacementOptionSnapshot
	var box_rect := Rect2i(box.slot, box.footprint)
	for candidate: FacilityPlacementOptionSnapshot in (
		controller.get_latest_snapshot().layout.placement_options
	):
		if (
			candidate.type_id == CampaignState.FACILITY_PROTEIN_DISH
			and box_rect.has_point(candidate.slot)
		):
			protein_option = candidate
			break
	_expect_true(
		protein_option != null,
		"protein dish has a valid slot on the foraging box"
	)
	if protein_option == null:
		return
	click.position = layout_view._slot_rect(
		protein_option.slot,
		Vector2i.ONE
	).get_center()
	layout_view._gui_input(click)
	_expect_true(
		controller.get_latest_snapshot().layout.action_pending,
		"protein-dish click queues a layout command"
	)
	controller._process(SimulationClock.FIXED_STEP_SECONDS)
	var dish: FacilitySnapshot
	for facility: FacilitySnapshot in (
		controller.get_latest_snapshot().layout.facilities
	):
		if facility.type_id == CampaignState.FACILITY_PROTEIN_DISH:
			dish = facility
			break
	_expect_true(
		dish != null and dish.zone_id == box.zone_id,
		"real palette path installs the dish in the foraging zone"
	)
	if dish == null:
		return
	var protein_button: Button = controller.get_node(
		"%ProteinButton"
	) as Button
	_expect_true(
		protein_button.visible and not protein_button.disabled,
		"installed dish enables the high-level protein action"
	)
	var protein_before: int = (
		controller.get_latest_snapshot().nutrition
			.total_protein_portions_placed
	)
	protein_button.pressed.emit()
	_expect_true(
		controller.get_latest_snapshot().nutrition.protein_action_pending,
		"protein button queues the player action"
	)
	_expect_int(
		controller.get_latest_snapshot().nutrition
			.total_protein_portions_placed,
		protein_before,
		"protein action does not mutate the submission Tick"
	)
	controller._process(SimulationClock.FIXED_STEP_SECONDS)
	_expect_true(
		controller.get_latest_snapshot().nutrition
			.total_protein_portions_placed > protein_before,
		"protein appears on the next fixed Tick"
	)
	var source_in_box: bool = false
	for source: FoodSourceSnapshot in (
		controller.get_latest_snapshot().colony.food_sources
	):
		if (
			source.food_type == FoodSourceState.FoodType.PROTEIN
			and source.zone_id == box.zone_id
		):
			source_in_box = true
			break
	_expect_true(
		source_in_box,
		"dedicated dish routes the real protein action to the foraging box"
	)


func _send_key(controller: Act1TestTubeController, keycode: Key) -> void:
	var event: InputEventKey = InputEventKey.new()
	event.keycode = keycode
	event.pressed = true
	controller._unhandled_input(event)


func _find_inference_button(
	controller: Act1TestTubeController,
	inference_id: StringName
) -> Button:
	for button_path: String in [
		"%InferenceButton1",
		"%InferenceButton2",
		"%InferenceButton3",
	]:
		var button: Button = controller.get_node(button_path) as Button
		if StringName(button.get_meta(&"inference_id", &"")) == inference_id:
			return button
	return null


func _process_until(
	controller: Act1TestTubeController,
	predicate: Callable,
	maximum_ticks: int
) -> bool:
	if predicate.call(controller.get_latest_snapshot()):
		return true
	for unused_tick: int in maximum_ticks:
		controller._process(SimulationClock.FIXED_STEP_SECONDS)
		if predicate.call(controller.get_latest_snapshot()):
			return true
	return false


func _create_controller(
	viewport_size: Vector2,
	ui_scale: float = 1.0,
	scenario_data: HabitatScenarioData = null
) -> Act1TestTubeController:
	var controller: Act1TestTubeController = (
		ACT1_SCENE.instantiate() as Act1TestTubeController
	)
	controller.provided_settings_state = DemoSettingsState.new(
		"zh_CN",
		Vector2i(int(viewport_size.x), int(viewport_size.y)),
		false,
		ui_scale,
		false
	)
	controller.exit_application_on_request = false
	if scenario_data != null:
		controller.habitat_scenario_data_source = scenario_data
	_scene_root.add_child(controller)
	controller.set_anchors_preset(Control.PRESET_TOP_LEFT)
	controller.position = Vector2.ZERO
	controller.size = viewport_size
	_settle_container_layout(controller)
	return controller


func _destroy_controller(controller: Act1TestTubeController) -> void:
	_scene_root.remove_child(controller)
	controller.free()


func _force_container_layout(node: Node) -> void:
	for child: Node in node.get_children():
		_force_container_layout(child)
	if node is Container:
		node.notification(Container.NOTIFICATION_SORT_CHILDREN)


func _settle_container_layout(node: Node) -> void:
	for pass_index: int in 4:
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


func _expect_vector_near(
	actual: Vector2,
	expected: Vector2,
	tolerance: float,
	message: String
) -> void:
	_assertion_count += 1
	if actual.distance_to(expected) <= tolerance:
		return
	_record_failure(message, str(expected), str(actual))


func _record_failure(
	message: String,
	expected: String,
	actual: String
) -> void:
	_failure_count += 1
	printerr("  %s - expected %s, got %s" % [message, expected, actual])
