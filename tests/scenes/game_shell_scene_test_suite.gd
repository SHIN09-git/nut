class_name GameShellSceneTestSuite
extends RefCounted

const SHELL_SCENE: PackedScene = preload(
	"res://scenes/app/game_shell.tscn"
)
const TEST_PROFILE_PATH: String = "user://r3_shell_tests/profile.json"
const TEST_SETTINGS_PATH: String = "user://r3_shell_tests/settings.json"
const SPECIES_A_DATA: SpeciesData = preload(
	"res://data/species/species_a.tres"
)
const LEGACY_SCENARIO_DATA: HabitatScenarioData = preload(
	"res://data/habitats/combined_observation_slice.tres"
)

var _assertion_count: int = 0
var _failure_count: int = 0
var _scene_root: Node
var _previous_locale: String
var _previous_scale: float = 1.0


func run(scene_root: Node) -> void:
	_scene_root = scene_root
	_previous_locale = TranslationServer.get_locale()
	_previous_scale = scene_root.get_window().content_scale_factor
	_cleanup()
	TranslationServer.set_locale("zh_CN")
	_test_title_new_save_return_and_continue_path()
	_test_legacy_profile_uses_legacy_scene()
	_test_profile_delete_requires_confirmation()
	_test_settings_persist_outside_the_profile()
	_test_game_settings_stay_synchronized_with_the_shell()
	_test_shortcut_rebinding_reaches_the_running_game()
	_test_exit_uses_an_explicit_application_boundary()
	_test_shell_pages_fit_supported_viewports()
	_cleanup()
	TranslationServer.set_locale(_previous_locale)
	scene_root.get_window().content_scale_factor = _previous_scale


func get_assertion_count() -> int:
	return _assertion_count


func get_failure_count() -> int:
	return _failure_count


func _test_title_new_save_return_and_continue_path() -> void:
	var shell: GameShellController = _create_shell(Vector2(1280, 720))
	_expect_string(
		String(shell.get_active_page_name()),
		"TitlePage",
		"application starts on the title page"
	)
	_expect_true(
		(shell.get_node("%ContinueButton") as Button).disabled,
		"Continue is disabled without a valid profile"
	)
	_expect_true(
		shell.get_viewport().gui_get_focus_owner()
			== shell.get_node("%NewGameButton"),
		"title page gives keyboard focus to New Game"
	)
	_expect_true(
		not (shell.get_node("%ShellLanguageOption") as OptionButton)
			.text.is_empty(),
		"the selected language is visible before the first settings change"
	)

	(shell.get_node("%NewGameButton") as Button).pressed.emit()
	var game: Act1TestTubeController = (
		shell.get_game_controller() as Act1TestTubeController
	)
	_expect_true(game != null, "New Game creates the observation session")
	_expect_true(
		not (shell.get_node("%ShellOverlay") as Control).visible,
		"New Game hides the title overlay"
	)
	(game.get_node("%StartObservationButton") as Button).pressed.emit()
	game._process(SimulationClock.FIXED_STEP_SECONDS * 4.0)
	(game.get_node("%PauseButton") as Button).pressed.emit()
	var saved_tick: int = game.get_simulation_tick()
	(game.get_node("%SaveGameButton") as Button).pressed.emit()
	var summary: Dictionary = ProfileStore.new(TEST_PROFILE_PATH).get_summary()
	_expect_true(
		summary.get("available", false),
		"pause-menu Save creates a playable profile"
	)
	_expect_int(
		int(summary.get("simulation_tick", -1)),
		saved_tick,
		"profile summary uses the exact successful Tick boundary"
	)

	(game.get_node("%ReturnToTitleButton") as Button).pressed.emit()
	_expect_true(
		shell.get_game_controller() == null,
		"Save and Return releases the running scene"
	)
	_expect_string(
		String(shell.get_active_page_name()),
		"TitlePage",
		"Save and Return reaches the title page"
	)
	_expect_true(
		not (shell.get_node("%ContinueButton") as Button).disabled,
		"Continue becomes available after a successful save"
	)
	(shell.get_node("%ContinueButton") as Button).pressed.emit()
	var restored_game: Act1TestTubeController = (
		shell.get_game_controller() as Act1TestTubeController
	)
	_expect_true(restored_game != null, "Continue restores a game controller")
	if restored_game != null:
		_expect_int(
			restored_game.get_simulation_tick(),
			saved_tick,
			"Continue restores the saved Tick"
		)
		_expect_true(
			restored_game.is_simulation_paused(),
			"paused save restores paused clock state"
		)
		_expect_true(
			restored_game.is_pause_menu_open(),
			"paused save restores to a visible pause menu"
		)
	_destroy_shell(shell)


func _test_legacy_profile_uses_legacy_scene() -> void:
	_cleanup()
	var simulation: ColonySimulation = ColonySimulation.new(
		SPECIES_A_DATA,
		LEGACY_SCENARIO_DATA
	)
	var clock: SimulationClock = SimulationClock.new()
	var envelope: Dictionary = SaveGameService.new().create_envelope(
		simulation,
		clock,
		ProfileStore.MAIN_SLOT_ID,
		"2026-07-28T00:00:00Z"
	)
	_expect_true(
		not envelope.is_empty(),
		"legacy combined scenario creates a valid profile envelope"
	)
	var save_result: Dictionary = ProfileStore.new(
		TEST_PROFILE_PATH
	).save_envelope(envelope)
	_expect_true(
		save_result.get("ok", false),
		"legacy combined profile is written for shell routing"
	)
	var shell: GameShellController = _create_shell(Vector2(1280, 720))
	(shell.get_node("%ContinueButton") as Button).pressed.emit()
	_expect_true(
		shell.get_game_controller() is CombinedObservationController,
		"Continue routes an existing combined profile to its legacy scene"
	)
	_destroy_shell(shell)


func _test_profile_delete_requires_confirmation() -> void:
	var shell: GameShellController = _create_shell(Vector2(1280, 720))
	(shell.get_node("%ProfilesButton") as Button).pressed.emit()
	_expect_string(
		String(shell.get_active_page_name()),
		"ProfilesPage",
		"Profiles button opens the profile page"
	)
	(shell.get_node("%DeleteProfileButton") as Button).pressed.emit()
	var confirmation: Control = shell.get_node("%ConfirmPanel") as Control
	_expect_true(
		confirmation.visible,
		"profile is not deleted before confirmation"
	)
	(shell.get_node("%ConfirmCancelButton") as Button).pressed.emit()
	_expect_true(
		ProfileStore.new(TEST_PROFILE_PATH).has_any_candidate(),
		"cancelling deletion preserves the profile"
	)
	(shell.get_node("%DeleteProfileButton") as Button).pressed.emit()
	(shell.get_node("%ConfirmAcceptButton") as Button).pressed.emit()
	_expect_true(
		not ProfileStore.new(TEST_PROFILE_PATH).has_any_candidate(),
		"confirming deletion removes profile candidates"
	)
	_expect_true(
		(shell.get_node("%ProfileContinueButton") as Button).disabled,
		"profile Continue is disabled after deletion"
	)
	_destroy_shell(shell)


func _test_settings_persist_outside_the_profile() -> void:
	var shell: GameShellController = _create_shell(Vector2(1280, 720))
	(shell.get_node("%SettingsButton") as Button).pressed.emit()
	var scale_option: OptionButton = shell.get_node(
		"%ShellUIScaleOption"
	) as OptionButton
	scale_option.select(2)
	scale_option.item_selected.emit(2)
	var reduced_motion: CheckButton = shell.get_node(
		"%ShellReducedMotionCheck"
	) as CheckButton
	reduced_motion.set_pressed_no_signal(true)
	reduced_motion.toggled.emit(true)
	var volume: HSlider = shell.get_node(
		"%ShellMasterVolumeSlider"
	) as HSlider
	volume.set_value_no_signal(0.4)
	volume.value_changed.emit(0.4)
	var ambient_volume: HSlider = shell.get_node(
		"%ShellAmbientVolumeSlider"
	) as HSlider
	ambient_volume.set_value_no_signal(0.25)
	ambient_volume.value_changed.emit(0.25)
	var effects_volume: HSlider = shell.get_node(
		"%ShellEffectsVolumeSlider"
	) as HSlider
	effects_volume.set_value_no_signal(0.65)
	effects_volume.value_changed.emit(0.65)
	var language: OptionButton = shell.get_node(
		"%ShellLanguageOption"
	) as OptionButton
	language.select(1)
	language.item_selected.emit(1)

	var load_result: Dictionary = SettingsStore.new(
		TEST_SETTINGS_PATH
	).load_or_default()
	_expect_true(
		load_result.get("ok", false)
			and not load_result.get("used_defaults", true),
		"settings controls persist an independent settings file"
	)
	var restored: DemoSettingsState = load_result["settings"]
	_expect_float(
		restored.get_ui_scale_factor(),
		1.5,
		"150 percent UI scale persists"
	)
	_expect_true(
		restored.is_reduced_motion(),
		"reduced motion persists"
	)
	_expect_float(
		restored.get_master_volume(),
		0.4,
		"master volume persists"
	)
	_expect_float(
		restored.get_ambient_volume(),
		0.25,
		"ambient volume persists independently"
	)
	_expect_float(
		restored.get_effects_volume(),
		0.65,
		"effects volume persists independently"
	)
	_expect_string(restored.get_locale_code(), "en", "language persists")
	_expect_true(
		not ProfileStore.new(TEST_PROFILE_PATH).has_any_candidate(),
		"changing settings does not create a game profile"
	)
	var escape: InputEventKey = InputEventKey.new()
	escape.keycode = KEY_ESCAPE
	escape.pressed = true
	shell._unhandled_input(escape)
	_expect_string(
		String(shell.get_active_page_name()),
		"TitlePage",
		"Escape returns from settings to the title page"
	)
	_destroy_shell(shell)
	SettingsStore.new(TEST_SETTINGS_PATH).delete_for_tests()
	TranslationServer.set_locale("zh_CN")
	_scene_root.get_window().content_scale_factor = 1.0


func _test_game_settings_stay_synchronized_with_the_shell() -> void:
	var shell: GameShellController = _create_shell(Vector2(1280, 720))
	(shell.get_node("%SettingsButton") as Button).pressed.emit()
	var shell_scale: OptionButton = shell.get_node(
		"%ShellUIScaleOption"
	) as OptionButton
	shell_scale.select(2)
	shell_scale.item_selected.emit(2)
	var reduced_motion: CheckButton = shell.get_node(
		"%ShellReducedMotionCheck"
	) as CheckButton
	reduced_motion.set_pressed_no_signal(true)
	reduced_motion.toggled.emit(true)
	var escape: InputEventKey = InputEventKey.new()
	escape.keycode = KEY_ESCAPE
	escape.pressed = true
	shell._unhandled_input(escape)
	(shell.get_node("%NewGameButton") as Button).pressed.emit()
	var game: Act1TestTubeController = (
		shell.get_game_controller() as Act1TestTubeController
	)
	_expect_true(game != null, "New Game exposes the shared settings state")
	if game == null:
		_destroy_shell(shell)
		return
	_expect_float(
		shell.get_settings_state().get_ui_scale_factor(),
		1.5,
		"shell-selected UI scale remains authoritative in game"
	)
	_expect_true(
		(game.get_node("%Act1TestTubeView") as Act1TestTubeView)
			.is_reduced_motion(),
		"new game receives the shell-owned reduced-motion setting"
	)
	(game.get_node("%StartObservationButton") as Button).pressed.emit()
	(game.get_node("%PauseButton") as Button).pressed.emit()
	(game.get_node("%ReturnToTitleButton") as Button).pressed.emit()
	(shell.get_node("%SettingsButton") as Button).pressed.emit()
	_expect_int(
		shell_scale.selected,
		2,
		"returning to title preserves the game-selected UI scale"
	)
	_destroy_shell(shell)
	SettingsStore.new(TEST_SETTINGS_PATH).delete_for_tests()


func _test_shortcut_rebinding_reaches_the_running_game() -> void:
	ProfileStore.new(TEST_PROFILE_PATH).delete_profile()
	var shell: GameShellController = _create_shell(Vector2(1280, 720))
	(shell.get_node("%SettingsButton") as Button).pressed.emit()
	(shell.get_node("%ControlsButton") as Button).pressed.emit()
	_expect_string(
		String(shell.get_active_page_name()),
		"ControlsPage",
		"keyboard settings open as a dedicated focused page"
	)
	var help_binding: Button = shell.get_node(
		"%HelpBindingButton"
	) as Button
	_expect_true(
		shell.get_viewport().gui_get_focus_owner() == help_binding,
		"shortcut page focuses its first binding"
	)
	help_binding.pressed.emit()
	var h_key: InputEventKey = InputEventKey.new()
	h_key.keycode = KEY_H
	h_key.pressed = true
	shell._unhandled_input(h_key)
	_expect_int(
		shell.get_settings_state().get_key_binding(
			DemoSettingsState.ACTION_HELP
		),
		KEY_H,
		"captured Help binding updates shell-owned settings"
	)
	var persisted: Dictionary = SettingsStore.new(
		TEST_SETTINGS_PATH
	).load_or_default()
	_expect_int(
		(persisted["settings"] as DemoSettingsState).get_key_binding(
			DemoSettingsState.ACTION_HELP
		),
		KEY_H,
		"captured Help binding persists independently"
	)

	var layout_binding: Button = shell.get_node(
		"%LayoutBindingButton"
	) as Button
	layout_binding.pressed.emit()
	shell._unhandled_input(h_key)
	_expect_int(
		shell.get_settings_state().get_key_binding(
			DemoSettingsState.ACTION_LAYOUT
		),
		KEY_L,
		"duplicate shortcut is rejected without mutating Layout"
	)
	var escape: InputEventKey = InputEventKey.new()
	escape.keycode = KEY_ESCAPE
	escape.pressed = true
	shell._unhandled_input(escape)
	shell._unhandled_input(escape)
	shell._unhandled_input(escape)
	_expect_string(
		String(shell.get_active_page_name()),
		"TitlePage",
		"Escape cancels capture, then returns through Settings to Title"
	)
	(shell.get_node("%NewGameButton") as Button).pressed.emit()
	var game: Act1TestTubeController = (
		shell.get_game_controller() as Act1TestTubeController
	)
	_expect_true(game != null, "rebound shortcut fixture starts Act 1")
	if game != null:
		(game.get_node("%StartObservationButton") as Button).pressed.emit()
		game._unhandled_input(h_key)
		_expect_true(
			(game.get_node("%HelpPanel") as Control).visible,
			"rebound Help key opens the in-game help panel"
		)
		_expect_true(
			game.is_simulation_paused(),
			"opening Help pauses the simulation"
		)
		game._unhandled_input(h_key)
		_expect_true(
			not (game.get_node("%HelpPanel") as Control).visible,
			"the same rebound key closes Help"
		)
		_expect_true(
			not game.is_simulation_paused(),
			"closing Help restores the prior running state"
		)
	_destroy_shell(shell)
	SettingsStore.new(TEST_SETTINGS_PATH).delete_for_tests()


func _test_exit_uses_an_explicit_application_boundary() -> void:
	var shell: GameShellController = _create_shell(Vector2(1280, 720))
	var exit_count: Array[int] = [0]
	shell.application_exit_requested.connect(func() -> void:
		exit_count[0] += 1
	)
	(shell.get_node("%ShellExitButton") as Button).pressed.emit()
	_expect_int(exit_count[0], 1, "title Exit emits one application request")
	_destroy_shell(shell)


func _test_shell_pages_fit_supported_viewports() -> void:
	for viewport_size: Vector2 in [
		Vector2(1280, 720),
		Vector2(1920, 1080),
	]:
		for ui_scale_index: int in [0, 2]:
			var shell: GameShellController = _create_shell(viewport_size)
			shell.get_settings_state().select_ui_scale(ui_scale_index)
			shell._apply_settings(false)
			for button_name: String in [
				"%ProfilesButton",
				"%SettingsButton",
			]:
				(shell.get_node(button_name) as Button).pressed.emit()
				_settle_container_layout(shell)
				var page: Control = (
					shell.get_node("%ProfilesPage")
						if button_name == "%ProfilesButton"
						else shell.get_node("%SettingsPage")
				) as Control
				var rect: Rect2 = page.get_global_rect()
				_expect_true(
					rect.position.x >= 0.0
						and rect.position.y >= 0.0
						and rect.end.x <= viewport_size.x
						and rect.end.y <= viewport_size.y,
					"%s fits inside %dx%d at %d%% (actual %s)"
					% [
						page.name,
						int(viewport_size.x),
						int(viewport_size.y),
						int(
							DemoSettingsState.UI_SCALE_FACTORS[
								ui_scale_index
							] * 100.0
						),
						str(rect),
					]
				)
				(
					shell.get_node("%ProfileBackButton") as Button
				).pressed.emit()
			_destroy_shell(shell)


func _create_shell(viewport_size: Vector2) -> GameShellController:
	var shell: GameShellController = SHELL_SCENE.instantiate()
	shell.profile_path_override = TEST_PROFILE_PATH
	shell.settings_path_override = TEST_SETTINGS_PATH
	shell.exit_application_on_request = false
	_scene_root.add_child(shell)
	shell.set_anchors_preset(Control.PRESET_TOP_LEFT)
	shell.position = Vector2.ZERO
	shell.size = viewport_size
	_settle_container_layout(shell)
	return shell


func _destroy_shell(shell: GameShellController) -> void:
	_scene_root.remove_child(shell)
	shell.free()


func _cleanup() -> void:
	ProfileStore.new(TEST_PROFILE_PATH).delete_profile()
	SettingsStore.new(TEST_SETTINGS_PATH).delete_for_tests()


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


func _expect_float(actual: float, expected: float, message: String) -> void:
	_assertion_count += 1
	if is_equal_approx(actual, expected):
		return
	_record_failure(message, str(expected), str(actual))


func _record_failure(
	message: String,
	expected: String,
	actual: String
) -> void:
	_failure_count += 1
	printerr("  %s - expected %s, got %s" % [message, expected, actual])
