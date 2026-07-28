extends SceneTree

const SimulationClockTestSuiteScript: Script = preload(
	"res://tests/core/simulation_clock_test_suite.gd"
)
const LifecycleTestSuiteScript: Script = preload(
	"res://tests/simulation/lifecycle_test_suite.gd"
)
const HumidityRelocationTestSuiteScript: Script = preload(
	"res://tests/simulation/humidity_relocation_test_suite.gd"
)
const BroodRelocationEquivalenceTestSuiteScript: Script = preload(
	"res://tests/simulation/brood_relocation_equivalence_test_suite.gd"
)
const ForagingTestSuiteScript: Script = preload(
	"res://tests/simulation/foraging_test_suite.gd"
)
const CombinedObservationTestSuiteScript: Script = preload(
	"res://tests/simulation/combined_observation_test_suite.gd"
)
const ObservationEventTestSuiteScript: Script = preload(
	"res://tests/simulation/observation_event_test_suite.gd"
)
const SaveCoreTestSuiteScript: Script = preload(
	"res://tests/save/save_core_test_suite.gd"
)
const ProfileStoreTestSuiteScript: Script = preload(
	"res://tests/save/profile_store_test_suite.gd"
)
const PlayerAnnotationStateTestSuiteScript: Script = preload(
	"res://tests/session/player_annotation_state_test_suite.gd"
)
const DemoSettingsStateTestSuiteScript: Script = preload(
	"res://tests/ui/demo_settings_state_test_suite.gd"
)
const SettingsStoreTestSuiteScript: Script = preload(
	"res://tests/ui/settings_store_test_suite.gd"
)
const DemoLocalizationTestSuiteScript: Script = preload(
	"res://tests/ui/demo_localization_test_suite.gd"
)
const ViewAdapterTestSuiteScript: Script = preload(
	"res://tests/view/view_adapter_test_suite.gd"
)
const HabitatViewInterpolationTestSuiteScript: Script = preload(
	"res://tests/view/habitat_view_interpolation_test_suite.gd"
)
const ReducedMotionTestSuiteScript: Script = preload(
	"res://tests/view/reduced_motion_test_suite.gd"
)
const WorkerObservationPanelTestSuiteScript: Script = preload(
	"res://tests/view/worker_observation_panel_test_suite.gd"
)
const LifecycleDebugSceneTestSuiteScript: Script = preload(
	"res://tests/scenes/lifecycle_debug_scene_test_suite.gd"
)
const HumidityMainSceneTestSuiteScript: Script = preload(
	"res://tests/scenes/humidity_main_scene_test_suite.gd"
)
const WorkerIdentitySceneTestSuiteScript: Script = preload(
	"res://tests/scenes/worker_identity_scene_test_suite.gd"
)
const SugarForagingSceneTestSuiteScript: Script = preload(
	"res://tests/scenes/sugar_foraging_scene_test_suite.gd"
)
const CombinedObservationSceneTestSuiteScript: Script = preload(
	"res://tests/scenes/combined_observation_scene_test_suite.gd"
)
const DemoShellSceneTestSuiteScript: Script = preload(
	"res://tests/scenes/demo_shell_scene_test_suite.gd"
)
const GameShellSceneTestSuiteScript: Script = preload(
	"res://tests/scenes/game_shell_scene_test_suite.gd"
)

var _assertion_count: int = 0
var _failure_count: int = 0


func _initialize() -> void:
	call_deferred("_run_all_tests")


func _run_all_tests() -> void:
	TranslationServer.set_locale("zh_CN")
	_run_simulation_clock_test_suite()
	_run_lifecycle_test_suite()
	_run_humidity_relocation_test_suite()
	_run_brood_relocation_equivalence_test_suite()
	_run_foraging_test_suite()
	_run_combined_observation_test_suite()
	_run_observation_event_test_suite()
	_run_save_core_test_suite()
	_run_profile_store_test_suite()
	_run_player_annotation_state_test_suite()
	_run_demo_settings_state_test_suite()
	_run_settings_store_test_suite()
	_run_demo_localization_test_suite()
	_run_view_adapter_test_suite()
	_run_habitat_view_interpolation_test_suite()
	_run_reduced_motion_test_suite()
	_run_worker_observation_panel_test_suite()
	_run_lifecycle_debug_scene_test_suite()
	_run_humidity_main_scene_test_suite()
	_run_worker_identity_scene_test_suite()
	_run_sugar_foraging_scene_test_suite()
	_run_combined_observation_scene_test_suite()
	_run_demo_shell_scene_test_suite()
	_run_game_shell_scene_test_suite()

	if _failure_count == 0:
		print("PASS: %d project assertions" % _assertion_count)
		quit(0)
		return

	printerr(
		"FAIL: %d of %d project assertions failed"
		% [_failure_count, _assertion_count]
	)
	quit(1)


func _run_simulation_clock_test_suite() -> void:
	var suite: SimulationClockTestSuite = SimulationClockTestSuiteScript.new()
	suite.run()
	_collect_suite_results(suite.get_assertion_count(), suite.get_failure_count())


func _run_lifecycle_test_suite() -> void:
	var suite: LifecycleTestSuite = LifecycleTestSuiteScript.new()
	suite.run()
	_collect_suite_results(suite.get_assertion_count(), suite.get_failure_count())


func _run_humidity_relocation_test_suite() -> void:
	var suite: HumidityRelocationTestSuite = (
		HumidityRelocationTestSuiteScript.new()
	)
	suite.run()
	_collect_suite_results(suite.get_assertion_count(), suite.get_failure_count())


func _run_brood_relocation_equivalence_test_suite() -> void:
	var suite: BroodRelocationEquivalenceTestSuite = (
		BroodRelocationEquivalenceTestSuiteScript.new()
	)
	suite.run()
	_collect_suite_results(suite.get_assertion_count(), suite.get_failure_count())


func _run_foraging_test_suite() -> void:
	var suite: ForagingTestSuite = ForagingTestSuiteScript.new()
	suite.run()
	_collect_suite_results(suite.get_assertion_count(), suite.get_failure_count())


func _run_combined_observation_test_suite() -> void:
	var suite: CombinedObservationTestSuite = (
		CombinedObservationTestSuiteScript.new()
	)
	suite.run()
	_collect_suite_results(suite.get_assertion_count(), suite.get_failure_count())


func _run_observation_event_test_suite() -> void:
	var suite: ObservationEventTestSuite = ObservationEventTestSuiteScript.new()
	suite.run()
	_collect_suite_results(suite.get_assertion_count(), suite.get_failure_count())


func _run_save_core_test_suite() -> void:
	var suite: SaveCoreTestSuite = SaveCoreTestSuiteScript.new()
	suite.run()
	_collect_suite_results(suite.get_assertion_count(), suite.get_failure_count())


func _run_profile_store_test_suite() -> void:
	var suite: ProfileStoreTestSuite = ProfileStoreTestSuiteScript.new()
	suite.run()
	_collect_suite_results(suite.get_assertion_count(), suite.get_failure_count())


func _run_player_annotation_state_test_suite() -> void:
	var suite: PlayerAnnotationStateTestSuite = (
		PlayerAnnotationStateTestSuiteScript.new()
	)
	suite.run()
	_collect_suite_results(suite.get_assertion_count(), suite.get_failure_count())


func _run_demo_settings_state_test_suite() -> void:
	var suite: DemoSettingsStateTestSuite = (
		DemoSettingsStateTestSuiteScript.new()
	)
	suite.run()
	_collect_suite_results(suite.get_assertion_count(), suite.get_failure_count())


func _run_settings_store_test_suite() -> void:
	var suite: SettingsStoreTestSuite = SettingsStoreTestSuiteScript.new()
	suite.run()
	_collect_suite_results(suite.get_assertion_count(), suite.get_failure_count())


func _run_demo_localization_test_suite() -> void:
	var suite: DemoLocalizationTestSuite = DemoLocalizationTestSuiteScript.new()
	suite.run()
	_collect_suite_results(suite.get_assertion_count(), suite.get_failure_count())


func _run_view_adapter_test_suite() -> void:
	var suite: ViewAdapterTestSuite = ViewAdapterTestSuiteScript.new()
	suite.run(root)
	_collect_suite_results(suite.get_assertion_count(), suite.get_failure_count())


func _run_habitat_view_interpolation_test_suite() -> void:
	var suite: HabitatViewInterpolationTestSuite = (
		HabitatViewInterpolationTestSuiteScript.new()
	)
	suite.run(root)
	_collect_suite_results(suite.get_assertion_count(), suite.get_failure_count())


func _run_reduced_motion_test_suite() -> void:
	var suite: ReducedMotionTestSuite = ReducedMotionTestSuiteScript.new()
	suite.run(root)
	_collect_suite_results(suite.get_assertion_count(), suite.get_failure_count())


func _run_worker_observation_panel_test_suite() -> void:
	var suite: WorkerObservationPanelTestSuite = (
		WorkerObservationPanelTestSuiteScript.new()
	)
	suite.run(root)
	_collect_suite_results(suite.get_assertion_count(), suite.get_failure_count())


func _run_lifecycle_debug_scene_test_suite() -> void:
	var suite: LifecycleDebugSceneTestSuite = (
		LifecycleDebugSceneTestSuiteScript.new()
	)
	suite.run(root)
	_collect_suite_results(suite.get_assertion_count(), suite.get_failure_count())


func _run_humidity_main_scene_test_suite() -> void:
	var suite: HumidityMainSceneTestSuite = HumidityMainSceneTestSuiteScript.new()
	suite.run(root)
	_collect_suite_results(suite.get_assertion_count(), suite.get_failure_count())


func _run_worker_identity_scene_test_suite() -> void:
	var suite: WorkerIdentitySceneTestSuite = (
		WorkerIdentitySceneTestSuiteScript.new()
	)
	suite.run(root)
	_collect_suite_results(suite.get_assertion_count(), suite.get_failure_count())


func _run_sugar_foraging_scene_test_suite() -> void:
	var suite: SugarForagingSceneTestSuite = (
		SugarForagingSceneTestSuiteScript.new()
	)
	suite.run(root)
	_collect_suite_results(suite.get_assertion_count(), suite.get_failure_count())


func _run_combined_observation_scene_test_suite() -> void:
	var suite: CombinedObservationSceneTestSuite = (
		CombinedObservationSceneTestSuiteScript.new()
	)
	suite.run(root)
	_collect_suite_results(suite.get_assertion_count(), suite.get_failure_count())


func _run_demo_shell_scene_test_suite() -> void:
	var suite: DemoShellSceneTestSuite = DemoShellSceneTestSuiteScript.new()
	suite.run(root)
	_collect_suite_results(suite.get_assertion_count(), suite.get_failure_count())


func _run_game_shell_scene_test_suite() -> void:
	var suite: GameShellSceneTestSuite = GameShellSceneTestSuiteScript.new()
	suite.run(root)
	_collect_suite_results(suite.get_assertion_count(), suite.get_failure_count())


func _collect_suite_results(assertion_count: int, failure_count: int) -> void:
	_assertion_count += assertion_count
	_failure_count += failure_count
