class_name DemoShellSceneTestSuite
extends RefCounted

const DEMO_SCENE: PackedScene = preload(
	"res://scenes/main/combined_observation.tscn"
)

var _assertion_count: int = 0
var _failure_count: int = 0
var _scene_root: Node


func run(scene_root: Node) -> void:
	_scene_root = scene_root
	var previous_locale: String = TranslationServer.get_locale()
	TranslationServer.set_locale("zh_CN")
	_test_pause_menu_freezes_and_resumes_the_session()
	_test_pause_restart_returns_to_the_preparation_gate()
	_test_display_and_language_controls_use_bounded_state()
	_test_exit_button_uses_an_explicit_application_boundary()
	_test_pause_layout_fits_both_supported_viewports()
	TranslationServer.set_locale(previous_locale)


func get_assertion_count() -> int:
	return _assertion_count


func get_failure_count() -> int:
	return _failure_count


func _test_pause_menu_freezes_and_resumes_the_session() -> void:
	var controller: CombinedObservationController = _create_controller(
		Vector2(1280.0, 720.0)
	)
	var start_button: Button = controller.get_node(
		"%StartObservationButton"
	) as Button
	var menu_button: Button = controller.get_node("%PauseButton") as Button
	var resume_button: Button = controller.get_node("%ResumeButton") as Button

	start_button.pressed.emit()
	controller._process(SimulationClock.FIXED_STEP_SECONDS * 2.0)
	menu_button.pressed.emit()
	var paused_tick: int = controller.get_simulation_tick()
	_expect_true(controller.is_pause_menu_open(), "menu button opens the pause menu")
	_expect_true(controller.is_simulation_paused(), "pause menu freezes the fixed clock")
	_expect_true(
		(controller.get_node("%CombinedHabitatView") as CombinedHabitatView)
			.are_visuals_paused(),
		"pause menu freezes presentation interpolation"
	)

	controller._process(2.0)
	_expect_int(
		controller.get_simulation_tick(),
		paused_tick,
		"processing while the menu is open cannot advance simulation"
	)
	resume_button.pressed.emit()
	_expect_true(
		not controller.is_pause_menu_open(),
		"resume button closes the pause menu"
	)
	_expect_true(
		not controller.is_simulation_paused(),
		"resume button releases the fixed clock"
	)
	controller._process(SimulationClock.FIXED_STEP_SECONDS)
	_expect_int(
		controller.get_simulation_tick(),
		paused_tick + 1,
		"simulation resumes on the next fixed step"
	)
	_destroy_controller(controller)


func _test_pause_restart_returns_to_the_preparation_gate() -> void:
	var controller: CombinedObservationController = _create_controller(
		Vector2(1280.0, 720.0)
	)
	(controller.get_node("%StartObservationButton") as Button).pressed.emit()
	controller._process(SimulationClock.FIXED_STEP_SECONDS * 3.0)
	(controller.get_node("%PauseButton") as Button).pressed.emit()
	(controller.get_node("%PauseRestartButton") as Button).pressed.emit()

	_expect_true(
		controller.is_preparation_gate_active(),
		"pause-menu restart returns to the preparation gate"
	)
	_expect_true(
		not controller.is_pause_menu_open(),
		"pause-menu restart closes the menu"
	)
	_expect_true(
		controller.is_simulation_paused(),
		"restarted preparation gate is frozen"
	)
	_expect_int(
		controller.get_simulation_tick(),
		0,
		"pause-menu restart creates a clean Tick-zero session"
	)
	_destroy_controller(controller)


func _test_display_and_language_controls_use_bounded_state() -> void:
	var controller: CombinedObservationController = _create_controller(
		Vector2(1280.0, 720.0)
	)
	var resolution_option: OptionButton = controller.get_node(
		"%ResolutionOption"
	) as OptionButton
	var fullscreen_check: CheckButton = controller.get_node(
		"%FullscreenCheck"
	) as CheckButton
	var language_option: OptionButton = controller.get_node(
		"%LanguageOption"
	) as OptionButton
	var title_label: Label = controller.get_node("%Title") as Label

	(controller.get_node("%PauseButton") as Button).pressed.emit()
	resolution_option.select(1)
	resolution_option.item_selected.emit(1)
	_expect_vector2i(
		controller.get_requested_window_resolution(),
		Vector2i(1920, 1080),
		"resolution option selects the supported 1920x1080 mode"
	)
	fullscreen_check.set_pressed_no_signal(true)
	fullscreen_check.toggled.emit(true)
	_expect_true(
		controller.is_fullscreen_requested(),
		"fullscreen control updates bounded display state"
	)
	fullscreen_check.set_pressed_no_signal(false)
	fullscreen_check.toggled.emit(false)
	_expect_true(
		not controller.is_fullscreen_requested(),
		"fullscreen control can return to windowed state"
	)

	language_option.select(1)
	language_option.item_selected.emit(1)
	_expect_string(
		controller.get_selected_locale(),
		"en",
		"language control selects temporary English"
	)
	_expect_true(
		title_label.text.contains("Continuous Observation"),
		"English selection refreshes visible player copy"
	)
	language_option.select(0)
	language_option.item_selected.emit(0)
	_expect_string(
		controller.get_selected_locale(),
		"zh_CN",
		"language control returns to Simplified Chinese"
	)
	_expect_true(
		title_label.text != "UI_TITLE"
			and not title_label.text.contains("Continuous Observation"),
		"Chinese selection resolves the translation key"
	)
	_expect_int(
		controller.get_simulation_tick(),
		0,
		"display and language settings cannot mutate simulation"
	)
	_destroy_controller(controller)


func _test_exit_button_uses_an_explicit_application_boundary() -> void:
	var controller: CombinedObservationController = _create_controller(
		Vector2(1280.0, 720.0)
	)
	var exit_request_count: Array[int] = [0]
	controller.application_exit_requested.connect(func() -> void:
		exit_request_count[0] += 1
	)
	(controller.get_node("%PauseButton") as Button).pressed.emit()
	(controller.get_node("%ExitButton") as Button).pressed.emit()
	_expect_int(
		exit_request_count[0],
		1,
		"exit button emits one explicit application-exit request"
	)
	_destroy_controller(controller)


func _test_pause_layout_fits_both_supported_viewports() -> void:
	for viewport_size: Vector2 in [
		Vector2(1280.0, 720.0),
		Vector2(1920.0, 1080.0),
	]:
		var controller: CombinedObservationController = _create_controller(
			viewport_size
		)
		(controller.get_node("%PauseButton") as Button).pressed.emit()
		_settle_container_layout(controller)
		var panel: Control = controller.get_node(
			"PauseMenu/Center/Panel"
		) as Control
		var panel_rect: Rect2 = panel.get_global_rect()
		_expect_true(
			panel_rect.position.x >= 0.0
				and panel_rect.position.y >= 0.0
				and panel_rect.end.x <= viewport_size.x
				and panel_rect.end.y <= viewport_size.y,
			"pause menu fits inside %dx%d"
			% [int(viewport_size.x), int(viewport_size.y)]
		)
		_destroy_controller(controller)


func _create_controller(viewport_size: Vector2) -> CombinedObservationController:
	var controller: CombinedObservationController = (
		DEMO_SCENE.instantiate() as CombinedObservationController
	)
	controller.exit_application_on_request = false
	_scene_root.add_child(controller)
	controller.set_anchors_preset(Control.PRESET_TOP_LEFT)
	controller.position = Vector2.ZERO
	controller.size = viewport_size
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


func _expect_string(actual: String, expected: String, message: String) -> void:
	_assertion_count += 1
	if actual == expected:
		return
	_record_failure(message, expected, actual)


func _expect_vector2i(
	actual: Vector2i,
	expected: Vector2i,
	message: String
) -> void:
	_assertion_count += 1
	if actual == expected:
		return
	_record_failure(message, str(expected), str(actual))


func _record_failure(
	message: String,
	expected: String,
	actual: String
) -> void:
	_failure_count += 1
	printerr("  %s - expected %s, got %s" % [message, expected, actual])
