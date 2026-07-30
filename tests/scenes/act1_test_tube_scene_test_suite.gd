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
	_test_component_and_theme_boundaries()
	_test_real_controls_complete_both_chapters()
	_test_chapter_five_real_layout_and_migration_path()
	_test_help_overlay_focus_and_pause()
	_test_pause_and_f3_boundaries()
	_test_colony_work_projection()
	_test_waste_tray_clean_button_boundary()
	_test_supported_viewport_layouts()


func get_assertion_count() -> int:
	return _assertion_count


func get_failure_count() -> int:
	return _failure_count


func _test_component_and_theme_boundaries() -> void:
	var controller: Act1TestTubeController = (
		ACT1_SCENE.instantiate() as Act1TestTubeController
	)
	_expect_true(
		controller.theme != null
		and controller.theme.resource_path
			== "res://themes/act1_observation_theme.tres",
		"observation scene uses the external frozen theme"
	)
	_expect_true(
		controller.get_node("%Header") is Act1TopBar,
		"header owns the top-bar interaction component"
	)
	_expect_true(
		controller.get_node("%SidePanel") is Act1ObservationSidebar,
		"side panel owns the observation-sidebar component"
	)
	_expect_true(
		controller.get_node("%ToolBar") is Act1ToolBar,
		"tool row owns the observation-toolbar component"
	)
	_expect_true(
		controller.get_node("%PreparationGate") is Act1PreparationGate,
		"preparation overlay owns its interaction component"
	)
	_expect_true(
		controller.get_node("%JournalPanel") is Act1JournalPanel,
		"journal overlay owns its interaction component"
	)
	_expect_true(
		controller.get_node("%HelpPanel") is Act1HelpPanel,
		"help overlay owns its interaction component"
	)
	_expect_true(
		controller.get_node("%CompletionPanel") is Act1CompletionPanel,
		"completion overlay owns its interaction component"
	)
	_expect_true(
		controller.get_node("%PauseMenu") is Act1PauseMenu,
		"pause overlay owns its interaction component"
	)
	var objective_card: PanelContainer = controller.get_node(
		"Main/Body/SidePanel/SideMargin/SideScroll/SideContent/ObjectiveCard"
	) as PanelContainer
	var evidence_card: PanelContainer = controller.get_node(
		"Main/Body/SidePanel/SideMargin/SideScroll/SideContent/EvidenceCard"
	) as PanelContainer
	var objective_style: StyleBox = objective_card.get_theme_stylebox(
		&"panel"
	)
	var evidence_style: StyleBox = evidence_card.get_theme_stylebox(
		&"panel"
	)
	_expect_true(
		objective_style == evidence_style
		and objective_style.resource_path
			== "res://themes/styles/observation_card.tres",
		"observation cards share one external style resource"
	)
	controller.free()


func _test_help_overlay_focus_and_pause() -> void:
	var controller: Act1TestTubeController = _create_controller(
		Vector2(1280, 720)
	)
	(controller.get_node("%StartObservationButton") as Button).pressed.emit()
	controller._process(SimulationClock.FIXED_STEP_SECONDS)
	var journal: Button = controller.get_node("%JournalButton") as Button
	var help: Button = controller.get_node("%HelpButton") as Button
	var close: Button = controller.get_node("%HelpCloseButton") as Button
	journal.grab_focus()
	var tick_before: int = controller.get_simulation_tick()
	help.pressed.emit()
	_expect_true(
		(controller.get_node("%HelpPanel") as Control).visible,
		"Help button opens the ordinary controls panel"
	)
	_expect_true(
		controller.is_simulation_paused(),
		"Help pauses fixed-Tick simulation"
	)
	_expect_true(
		controller.get_viewport().gui_get_focus_owner() == close,
		"Help gives keyboard focus to its close action"
	)
	controller._process(SimulationClock.FIXED_STEP_SECONDS * 10.0)
	_expect_int(
		controller.get_simulation_tick(),
		tick_before,
		"Help prevents simulation progress while being read"
	)
	close.pressed.emit()
	_expect_true(
		not (controller.get_node("%HelpPanel") as Control).visible,
		"Help close action hides the panel"
	)
	_expect_true(
		not controller.is_simulation_paused(),
		"closing Help restores the prior running state"
	)
	_expect_true(
		controller.get_viewport().gui_get_focus_owner() == journal,
		"closing Help restores focus to its opener context"
	)
	_destroy_controller(controller)


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
				ui_scale,
				null,
				"en"
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
				"%HelpButton",
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
			for node_path: String in [
				"%SugarButton",
				"%ProteinButton",
				"%CleanWasteButton",
				"%FacilityTypeOption",
				"%PlaceBoxButton",
				"%ToggleGateButton",
			]:
				(controller.get_node(node_path) as Control).visible = true
			_settle_container_layout(controller)
			for node_path: String in [
				"%Title",
				"%HelpButton",
				"%JournalButton",
				"Main/Body/SidePanel",
				"Main/ToolBar",
				"Main/ToolBar/ToolMargin/ToolContent/ToolRowScroll",
				"Main/ToolBar/ToolMargin/ToolContent/LayoutRowScroll",
			]:
				var control: Control = controller.get_node(node_path) as Control
				_expect_true(
					viewport_rect.encloses(control.get_global_rect()),
					(
						"%s remains inside the maximum-tool layout "
						+ "at %dx%d / %d%% (actual %s)"
					)
						% [
							node_path,
							int(viewport_size.x),
							int(viewport_size.y),
							int(ui_scale * 100.0),
							str(control.get_global_rect()),
						]
				)
			(controller.get_node("%HelpButton") as Button).pressed.emit()
			_settle_container_layout(controller)
			var help_panel: Control = controller.get_node(
				"%HelpPanel/Center/Panel"
			) as Control
			_expect_true(
				viewport_rect.encloses(help_panel.get_global_rect()),
				"Help panel fits inside %dx%d at %d%% UI scale (actual %s)"
					% [
						int(viewport_size.x),
						int(viewport_size.y),
						int(ui_scale * 100.0),
						str(help_panel.get_global_rect()),
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


func _test_chapter_five_real_layout_and_migration_path() -> void:
	var controller: Act1TestTubeController = _create_controller(
		Vector2(1280, 720)
	)
	(controller.get_node("%StartObservationButton") as Button).pressed.emit()
	_prepare_chapter_five_controller(controller)
	var layout_button: Button = controller.get_node("%LayoutButton") as Button
	layout_button.button_pressed = true
	layout_button.pressed.emit()
	var view: Act1TestTubeView = controller.get_node(
		"%Act1TestTubeView"
	) as Act1TestTubeView
	_expect_true(view.is_layout_mode(), "Chapter 5 opens the real layout view")

	var gate_option: FacilityPlacementOptionSnapshot = _find_exact_option(
		controller.get_latest_snapshot(),
		&"connector_gate",
		Vector2i(5, 3),
		0
	)
	_expect_true(gate_option != null, "Chapter 5 exposes the bridge gate slot")
	if gate_option == null:
		_destroy_controller(controller)
		return
	var gate_id: int = _place_facility_through_ui(controller, gate_option)
	_expect_true(gate_id >= 0, "real UI places the bridge gate")
	if gate_id < 0:
		_destroy_controller(controller)
		return

	var dual_option: FacilityPlacementOptionSnapshot = _find_exact_option(
		controller.get_latest_snapshot(),
		CampaignState.FACILITY_DUAL_CHAMBER_NEST,
		Vector2i(6, 3),
		0
	)
	_expect_true(
		dual_option != null,
		"connected gate exposes the dual-chamber nest slot"
	)
	if dual_option == null:
		_destroy_controller(controller)
		return
	var dual_id: int = _place_facility_through_ui(controller, dual_option)
	_expect_true(dual_id >= 0, "real UI places one dual-chamber nest")
	if dual_id < 0:
		_destroy_controller(controller)
		return
	var dual: FacilitySnapshot = (
		controller.get_latest_snapshot().layout.get_facility(dual_id)
	)
	_expect_true(
		dual != null
			and not dual.zone_id.is_empty()
			and not dual.secondary_zone_id.is_empty(),
		"real placement publishes two authoritative rooms"
	)
	if dual == null:
		_destroy_controller(controller)
		return

	var hydration_option: FacilityPlacementOptionSnapshot = (
		_find_option_for_zone(
			controller,
			CampaignState.FACILITY_HYDRATION_MODULE,
			dual.zone_id
		)
	)
	_expect_true(
		hydration_option != null,
		"layout offers hydration on the brood chamber"
	)
	if hydration_option == null:
		_destroy_controller(controller)
		return
	var hydration_id: int = _place_facility_through_ui(
		controller,
		hydration_option
	)
	_expect_true(hydration_id >= 0, "real UI hydrates the brood chamber")
	if hydration_id < 0:
		_destroy_controller(controller)
		return
	var hydration: FacilitySnapshot = (
		controller.get_latest_snapshot().layout.get_facility(hydration_id)
	)
	_expect_true(
		hydration != null
			and hydration.zone_id == dual.zone_id
			and hydration.zone_id != dual.secondary_zone_id,
		"hydration click resolves to one chamber only"
	)

	_expect_true(
		_advance_authority_until(
			controller,
			func(simulation: ColonySimulation) -> bool:
				var state: ColonyState = simulation._state
				if state.queen.zone_id != dual.zone_id:
					return false
				for ant: AntModel in state.ants:
					if (
						ant.life_stage != AntModel.LifeStage.WORKER
						and ant.zone_id != dual.zone_id
					):
						return false
				return (
					state.colony_work_state.completed_migration_count > 0
				),
			1_500
		),
		"real layout path leads to autonomous brood-then-queen migration"
	)
	_expect_true(
		controller._colony_simulation.has_valid_habitat_ownership(),
		"real UI migration preserves single ownership"
	)

	var waste_option: FacilityPlacementOptionSnapshot = _find_option_for_zone(
		controller,
		CampaignState.FACILITY_WASTE_TRAY,
		&"micro_feeding_port"
	)
	_expect_true(
		waste_option != null,
		"layout offers a waste path on the feeding-port zone"
	)
	if waste_option == null:
		_destroy_controller(controller)
		return
	var waste_id: int = _place_facility_through_ui(
		controller,
		waste_option
	)
	_expect_true(waste_id >= 0, "real UI installs the waste path")
	if waste_id < 0:
		_destroy_controller(controller)
		return

	_expect_true(
		_advance_authority_until(
			controller,
			func(simulation: ColonySimulation) -> bool:
				var campaign_state: CampaignState = (
					simulation._state.campaign_state
				)
				return (
					campaign_state.chapter
					== CampaignState.Chapter.ACT1_MODULAR_MIGRATION
					and campaign_state.status
						== CampaignState.Status.AWAITING_INFERENCE
				),
			250
		),
		"real player path collects the five migration observations"
	)
	var campaign: CampaignSnapshot = controller.get_latest_snapshot().campaign
	for evidence_id: StringName in [
		CampaignState.EVIDENCE_DUAL_NEST_CONNECTED,
		CampaignState.EVIDENCE_DUAL_NEST_SCOUTED,
		CampaignState.EVIDENCE_CORE_BROOD_MIGRATED,
		CampaignState.EVIDENCE_QUEEN_MIGRATED,
		CampaignState.EVIDENCE_FUNCTIONAL_ZONING,
	]:
		_expect_true(
			campaign.has_evidence(evidence_id),
			"real Chapter 5 path records evidence %s" % evidence_id
		)

	(controller.get_node("%JournalButton") as Button).pressed.emit()
	var inference_button: Button = _find_inference_button(
		controller,
		CampaignState.INFERENCE_MIGRATION_CONDITIONS
	)
	_expect_true(
		inference_button != null and not inference_button.disabled,
		"journal exposes the evidence-backed migration inference"
	)
	if inference_button != null:
		inference_button.pressed.emit()
		(
			controller.get_node("%JournalCloseButton") as Button
		).pressed.emit()
		controller._process(SimulationClock.FIXED_STEP_SECONDS)
	_expect_true(
		not controller.get_latest_snapshot().campaign.completed,
		"real Chapter 5 inference leaves the profile active"
	)
	_expect_int(
		controller.get_latest_snapshot().campaign.chapter,
		CampaignState.Chapter.ACT1_STABLE_COLONY_SUMMARY,
		"real Chapter 5 inference enters the stable-colony summary"
	)
	_expect_true(
		_advance_authority_until(
			controller,
			func(simulation: ColonySimulation) -> bool:
				return (
					simulation._state.campaign_state.status
					== CampaignState.Status.AWAITING_INFERENCE
				),
			250
		),
		"real final layout reaches the evidence-backed report conclusion"
	)
	(controller.get_node("%JournalButton") as Button).pressed.emit()
	var final_inference_button: Button = _find_inference_button(
		controller,
		CampaignState.INFERENCE_LAYOUT_SHAPES_BEHAVIOR
	)
	_expect_true(
		final_inference_button != null
			and not final_inference_button.disabled,
		"journal exposes the long-term layout conclusion"
	)
	if final_inference_button != null:
		final_inference_button.pressed.emit()
		(
			controller.get_node("%JournalCloseButton") as Button
		).pressed.emit()
		controller._process(SimulationClock.FIXED_STEP_SECONDS)
	var final_snapshot: GameSnapshot = controller.get_latest_snapshot()
	_expect_true(
		final_snapshot.campaign.completed
			and final_snapshot.act1.final_report_available,
		"real journal path generates the final observation report"
	)
	_expect_true(
		(controller.get_node("%CompletionPanel") as Control).visible,
		"generated report opens the ending panel"
	)
	_expect_true(
		not (controller.get_node("%CompletionBody") as Label).text.is_empty(),
		"ending panel renders a profile-specific report"
	)
	var return_requested: Array[bool] = [false]
	controller.return_to_title_requested.connect(
		func() -> void:
			return_requested[0] = true
	)
	(
		controller.get_node("%CompletionReturnTitleButton") as Button
	).pressed.emit()
	_expect_true(
		return_requested[0],
		"ending panel offers the save-and-return profile path"
	)
	(controller.get_node("%ContinueFreeplayButton") as Button).pressed.emit()
	_expect_true(
		not (controller.get_node("%CompletionPanel") as Control).visible,
		"continue button returns to free observation"
	)
	_destroy_controller(controller)


func _prepare_chapter_five_controller(
	controller: Act1TestTubeController
) -> void:
	var simulation: ColonySimulation = controller._colony_simulation
	var state: ColonyState = simulation._state
	var campaign: CampaignState = state.campaign_state
	campaign.chapter = CampaignState.Chapter.ACT1_MODULAR_MIGRATION
	campaign.status = CampaignState.Status.ACTIVE
	campaign.chapter_entered_tick = state.simulation_tick
	campaign.completed_chapter_count = 4
	campaign.campaign_completed_tick = -1
	for evidence_id: StringName in [
		CampaignState.EVIDENCE_QUEEN_CARE,
		CampaignState.EVIDENCE_FIRST_PUPA,
		CampaignState.EVIDENCE_FIRST_WORKER,
		CampaignState.EVIDENCE_FIRST_WORKER_CARE,
		CampaignState.EVIDENCE_FIRST_NUTRIENT_EXCHANGE,
		CampaignState.EVIDENCE_FORAGING_ZONE_SCOUTED,
		CampaignState.EVIDENCE_FORAGING_SUGAR_CYCLE,
		CampaignState.EVIDENCE_PROTEIN_CARE,
		CampaignState.EVIDENCE_WASTE_TRAY_CLEANED,
		CampaignState.EVIDENCE_SMALL_COLONY_STABLE,
		CampaignState.EVIDENCE_HYDRATION_RESPONSE,
		CampaignState.EVIDENCE_POLLUTION_AVOIDANCE,
		CampaignState.EVIDENCE_PARTIAL_MIGRATION,
		CampaignState.EVIDENCE_ENVIRONMENT_STABLE,
	]:
		campaign.collect_evidence(evidence_id)
	for inference_id: StringName in [
		CampaignState.INFERENCE_QUEEN_CARE,
		CampaignState.INFERENCE_WORKER_NUTRITION,
		CampaignState.INFERENCE_FORAGING_ROLES,
		CampaignState.INFERENCE_ENVIRONMENT_GRADIENT,
	]:
		campaign.confirm_inference(inference_id)
	for facility_id: StringName in [
		CampaignState.FACILITY_MICRO_FEEDING_PORT,
		CampaignState.FACILITY_SMALL_FORAGING_BOX,
		CampaignState.FACILITY_SUGAR_STATION,
		CampaignState.FACILITY_PROTEIN_DISH,
		CampaignState.FACILITY_WASTE_TRAY,
		CampaignState.FACILITY_SPARE_TEST_TUBE,
		CampaignState.FACILITY_HYDRATION_MODULE,
		CampaignState.FACILITY_CONNECTOR_FAMILY,
		CampaignState.FACILITY_DUAL_CHAMBER_NEST,
	]:
		campaign.unlock_facility(facility_id)
	var care: FoundingCareData = ACT1_SCENARIO_DATA.founding_care_data
	for card_id: StringName in [
		care.queen_care_observation_card_id,
		care.pupa_observation_card_id,
		care.first_worker_observation_card_id,
		care.worker_care_observation_card_id,
		ACT1_SCENARIO_DATA.foraging_observation_card_id,
	]:
		state.unlocked_observation_card_ids[card_id] = true

	state.ants[0].configure_nutrition_worker(
		&"test_tube_nest",
		state.simulation_tick
	)
	for ant_index: int in range(1, state.ants.size()):
		state.ants[ant_index].configure_brood(
			&"test_tube_nest",
			state.simulation_tick
		)
	state.invalidate_worker_order()
	var source: HabitatZoneState = state.get_zone(&"test_tube_nest")
	source.set_humidity(0.30)
	source.set_light_exposure(0.88)
	source.set_pollution(0.0)
	var activity_ticks: int = (
		simulation._habitat_config.nutrition_config
			.sugar_activity_ticks_per_portion
	)
	state.nutrition_state.sugar_activity_ticks_remaining = (
		activity_ticks - 1
	)
	state.nutrition_state.sugar_reserve_portions = 20
	state.nutrition_state.total_sugar_portions_supplied = 20
	state.act1_state.first_worker_emerged_tick = state.simulation_tick
	state.act1_state.first_worker_care_recorded = true
	state.nutrition_state.protein_reserve_portions = 1
	state.nutrition_state.total_protein_portions_consumed = 1
	state.nutrition_state.completed_feeding_count = 1
	controller._apply_snapshot()


func _place_facility_through_ui(
	controller: Act1TestTubeController,
	option: FacilityPlacementOptionSnapshot
) -> int:
	var palette: OptionButton = controller.get_node(
		"%FacilityTypeOption"
	) as OptionButton
	var palette_index: int = -1
	for index: int in palette.item_count:
		if StringName(palette.get_item_metadata(index)) == option.type_id:
			palette_index = index
			break
	_expect_true(
		palette_index >= 0,
		"facility palette exposes %s" % option.type_id
	)
	if palette_index < 0:
		return -1
	palette.select(palette_index)
	palette.item_selected.emit(palette_index)
	(controller.get_node("%PlaceBoxButton") as Button).pressed.emit()
	var view: Act1TestTubeView = controller.get_node(
		"%Act1TestTubeView"
	) as Act1TestTubeView
	var layout_view: FacilityLayoutView = view.get_layout_view()
	_expect_true(
		layout_view.is_placing(),
		"place button enters placement mode for %s" % option.type_id
	)
	if not layout_view.is_placing():
		return -1
	for unused_rotation: int in 4:
		if layout_view.get_placement_orientation() == option.orientation:
			break
		_send_key(controller, KEY_R)
	_expect_int(
		layout_view.get_placement_orientation(),
		option.orientation,
		"placement preview reaches the requested orientation"
	)
	var prior_ids: Array[int] = []
	for facility: FacilitySnapshot in (
		controller.get_latest_snapshot().layout.facilities
	):
		prior_ids.append(facility.facility_id)
	var click: InputEventMouseButton = InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	click.position = layout_view._slot_rect(
		option.slot,
		Vector2i.ONE
	).get_center()
	layout_view._gui_input(click)
	_expect_true(
		controller.get_latest_snapshot().layout.action_pending,
		"mouse click queues %s" % option.type_id
	)
	if not controller.get_latest_snapshot().layout.action_pending:
		return -1
	controller._process(SimulationClock.FIXED_STEP_SECONDS)
	for facility: FacilitySnapshot in (
		controller.get_latest_snapshot().layout.facilities
	):
		if (
			facility.type_id == option.type_id
			and not prior_ids.has(facility.facility_id)
		):
			return facility.facility_id
	return -1


func _find_exact_option(
	snapshot: GameSnapshot,
	type_id: StringName,
	slot: Vector2i,
	orientation: int
) -> FacilityPlacementOptionSnapshot:
	for option: FacilityPlacementOptionSnapshot in (
		snapshot.layout.placement_options
	):
		if (
			option.type_id == type_id
			and option.slot == slot
			and option.orientation == orientation
		):
			return option
	return null


func _find_option_for_zone(
	controller: Act1TestTubeController,
	type_id: StringName,
	zone_id: StringName
) -> FacilityPlacementOptionSnapshot:
	var simulation: ColonySimulation = controller._colony_simulation
	for option: FacilityPlacementOptionSnapshot in (
		controller.get_latest_snapshot().layout.placement_options
	):
		if (
			option.type_id == type_id
			and simulation._state.layout_state.find_host_zone_id(
				simulation._habitat_config.facility_catalog_config,
				type_id,
				option.slot,
				option.orientation
			) == zone_id
		):
			return option
	return null


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


func _advance_authority_until(
	controller: Act1TestTubeController,
	predicate: Callable,
	maximum_ticks: int
) -> bool:
	var simulation: ColonySimulation = controller._colony_simulation
	if predicate.call(simulation):
		_synchronize_controller_after_direct_advance(controller)
		controller._apply_snapshot()
		return true
	for unused_tick: int in maximum_ticks:
		if not simulation.advance_tick(simulation._state.simulation_tick + 1):
			_synchronize_controller_after_direct_advance(controller)
			controller._apply_snapshot()
			return false
		if predicate.call(simulation):
			_synchronize_controller_after_direct_advance(controller)
			controller._apply_snapshot()
			return true
	_synchronize_controller_after_direct_advance(controller)
	controller._apply_snapshot()
	return false


func _synchronize_controller_after_direct_advance(
	controller: Act1TestTubeController
) -> void:
	controller._simulation_clock.restore_save_boundary(
		controller._colony_simulation._state.simulation_tick,
		controller._simulation_clock.get_speed_multiplier(),
		controller._simulation_clock.is_paused()
	)


func _create_controller(
	viewport_size: Vector2,
	ui_scale: float = 1.0,
	scenario_data: HabitatScenarioData = null,
	locale: String = "zh_CN"
) -> Act1TestTubeController:
	var controller: Act1TestTubeController = (
		ACT1_SCENE.instantiate() as Act1TestTubeController
	)
	controller.provided_settings_state = DemoSettingsState.new(
		locale,
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
