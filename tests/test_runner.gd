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
const CampaignJournalTestSuiteScript: Script = preload(
	"res://tests/simulation/campaign_journal_test_suite.gd"
)
const NutritionGrowthTestSuiteScript: Script = preload(
	"res://tests/simulation/nutrition_growth_test_suite.gd"
)
const Act1TestTubeTestSuiteScript: Script = preload(
	"res://tests/simulation/act1_test_tube_test_suite.gd"
)
const FacilityLayoutTestSuiteScript: Script = preload(
	"res://tests/simulation/facility_layout_test_suite.gd"
)
const FacilityEnvironmentTestSuiteScript: Script = preload(
	"res://tests/simulation/facility_environment_test_suite.gd"
)
const ColonyWorkTestSuiteScript: Script = preload(
	"res://tests/simulation/colony_work_test_suite.gd"
)
const Act1EnvironmentChaptersTestSuiteScript: Script = preload(
	"res://tests/simulation/act1_environment_chapters_test_suite.gd"
)
const Act1ModularMigrationTestSuiteScript: Script = preload(
	"res://tests/simulation/act1_modular_migration_test_suite.gd"
)
const Act1FinaleTestSuiteScript: Script = preload(
	"res://tests/simulation/act1_finale_test_suite.gd"
)
const V1ReleaseReadinessTestSuiteScript: Script = preload(
	"res://tests/simulation/v1_release_readiness_test_suite.gd"
)
const ObservationEventTestSuiteScript: Script = preload(
	"res://tests/simulation/observation_event_test_suite.gd"
)
const SaveCoreTestSuiteScript: Script = preload(
	"res://tests/save/save_core_test_suite.gd"
)
const ProfilePlaytimeStateTestSuiteScript: Script = preload(
	"res://tests/save/profile_playtime_state_test_suite.gd"
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
const ProductionAssetsTestSuiteScript: Script = preload(
	"res://tests/production/production_assets_test_suite.gd"
)
const ProductionAudioTestSuiteScript: Script = preload(
	"res://tests/audio/production_audio_test_suite.gd"
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
const AntBehaviorAnimationTestSuiteScript: Script = preload(
	"res://tests/view/ant_behavior_animation_test_suite.gd"
)
const FacilityLayoutAccessibilityTestSuiteScript: Script = preload(
	"res://tests/view/facility_layout_accessibility_test_suite.gd"
)
const HabitatSpatialProjectionTestSuiteScript: Script = preload(
	"res://tests/view/habitat_spatial_projection_test_suite.gd"
)
const FacilityWorldInteractionTestSuiteScript: Script = preload(
	"res://tests/view/facility_world_interaction_test_suite.gd"
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
const CampaignJournalSceneTestSuiteScript: Script = preload(
	"res://tests/scenes/campaign_journal_scene_test_suite.gd"
)
const DemoShellSceneTestSuiteScript: Script = preload(
	"res://tests/scenes/demo_shell_scene_test_suite.gd"
)
const GameShellSceneTestSuiteScript: Script = preload(
	"res://tests/scenes/game_shell_scene_test_suite.gd"
)
const Act1TestTubeSceneTestSuiteScript: Script = preload(
	"res://tests/scenes/act1_test_tube_scene_test_suite.gd"
)

var _assertion_count: int = 0
var _failure_count: int = 0


func _initialize() -> void:
	call_deferred("_run_all_tests")


func _run_all_tests() -> void:
	TranslationServer.set_locale("zh_CN")
	if not _validate_suite_scripts():
		printerr(
			"FAIL: %d of %d project assertions failed"
			% [_failure_count, _assertion_count]
		)
		quit(1)
		return
	_run_simulation_clock_test_suite()
	_run_lifecycle_test_suite()
	_run_humidity_relocation_test_suite()
	_run_brood_relocation_equivalence_test_suite()
	_run_foraging_test_suite()
	_run_combined_observation_test_suite()
	_run_campaign_journal_test_suite()
	_run_nutrition_growth_test_suite()
	_run_act1_test_tube_test_suite()
	_run_facility_layout_test_suite()
	_run_facility_environment_test_suite()
	_run_colony_work_test_suite()
	_run_act1_environment_chapters_test_suite()
	_run_act1_modular_migration_test_suite()
	_run_act1_finale_test_suite()
	_run_v1_release_readiness_test_suite()
	_run_observation_event_test_suite()
	_run_save_core_test_suite()
	_run_profile_playtime_state_test_suite()
	_run_profile_store_test_suite()
	_run_player_annotation_state_test_suite()
	_run_demo_settings_state_test_suite()
	_run_settings_store_test_suite()
	_run_production_assets_test_suite()
	_run_production_audio_test_suite()
	_run_demo_localization_test_suite()
	_run_view_adapter_test_suite()
	_run_habitat_view_interpolation_test_suite()
	_run_reduced_motion_test_suite()
	_run_ant_behavior_animation_test_suite()
	_run_facility_layout_accessibility_test_suite()
	_run_habitat_spatial_projection_test_suite()
	_run_facility_world_interaction_test_suite()
	_run_worker_observation_panel_test_suite()
	_run_lifecycle_debug_scene_test_suite()
	_run_humidity_main_scene_test_suite()
	_run_worker_identity_scene_test_suite()
	_run_sugar_foraging_scene_test_suite()
	_run_combined_observation_scene_test_suite()
	_run_campaign_journal_scene_test_suite()
	_run_demo_shell_scene_test_suite()
	_run_game_shell_scene_test_suite()
	_run_act1_test_tube_scene_test_suite()

	if _failure_count == 0:
		print("PASS: %d project assertions" % _assertion_count)
		quit(0)
		return

	printerr(
		"FAIL: %d of %d project assertions failed"
		% [_failure_count, _assertion_count]
	)
	quit(1)


func _validate_suite_scripts() -> bool:
	var suite_scripts: Array[Script] = [
		SimulationClockTestSuiteScript,
		LifecycleTestSuiteScript,
		HumidityRelocationTestSuiteScript,
		BroodRelocationEquivalenceTestSuiteScript,
		ForagingTestSuiteScript,
		CombinedObservationTestSuiteScript,
		CampaignJournalTestSuiteScript,
		NutritionGrowthTestSuiteScript,
		Act1TestTubeTestSuiteScript,
		FacilityLayoutTestSuiteScript,
		FacilityEnvironmentTestSuiteScript,
		ColonyWorkTestSuiteScript,
		Act1EnvironmentChaptersTestSuiteScript,
		Act1ModularMigrationTestSuiteScript,
		Act1FinaleTestSuiteScript,
		V1ReleaseReadinessTestSuiteScript,
		ObservationEventTestSuiteScript,
		SaveCoreTestSuiteScript,
		ProfilePlaytimeStateTestSuiteScript,
		ProfileStoreTestSuiteScript,
		PlayerAnnotationStateTestSuiteScript,
		DemoSettingsStateTestSuiteScript,
		SettingsStoreTestSuiteScript,
		ProductionAssetsTestSuiteScript,
		ProductionAudioTestSuiteScript,
		DemoLocalizationTestSuiteScript,
		ViewAdapterTestSuiteScript,
		HabitatViewInterpolationTestSuiteScript,
		ReducedMotionTestSuiteScript,
		AntBehaviorAnimationTestSuiteScript,
		FacilityLayoutAccessibilityTestSuiteScript,
		HabitatSpatialProjectionTestSuiteScript,
		FacilityWorldInteractionTestSuiteScript,
		WorkerObservationPanelTestSuiteScript,
		LifecycleDebugSceneTestSuiteScript,
		HumidityMainSceneTestSuiteScript,
		WorkerIdentitySceneTestSuiteScript,
		SugarForagingSceneTestSuiteScript,
		CombinedObservationSceneTestSuiteScript,
		CampaignJournalSceneTestSuiteScript,
		DemoShellSceneTestSuiteScript,
		GameShellSceneTestSuiteScript,
		Act1TestTubeSceneTestSuiteScript,
	]
	var all_valid: bool = true
	for suite_script: Script in suite_scripts:
		_assertion_count += 1
		if suite_script == null or not suite_script.can_instantiate():
			_failure_count += 1
			all_valid = false
			printerr("  test suite script cannot instantiate")
	return all_valid


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


func _run_campaign_journal_test_suite() -> void:
	var suite: CampaignJournalTestSuite = CampaignJournalTestSuiteScript.new()
	suite.run()
	_collect_suite_results(suite.get_assertion_count(), suite.get_failure_count())


func _run_nutrition_growth_test_suite() -> void:
	var suite: NutritionGrowthTestSuite = NutritionGrowthTestSuiteScript.new()
	suite.run()
	_collect_suite_results(suite.get_assertion_count(), suite.get_failure_count())


func _run_act1_test_tube_test_suite() -> void:
	var suite: Act1TestTubeTestSuite = Act1TestTubeTestSuiteScript.new()
	suite.run()
	_collect_suite_results(suite.get_assertion_count(), suite.get_failure_count())


func _run_facility_layout_test_suite() -> void:
	var suite: FacilityLayoutTestSuite = FacilityLayoutTestSuiteScript.new()
	suite.run()
	_collect_suite_results(suite.get_assertion_count(), suite.get_failure_count())


func _run_facility_environment_test_suite() -> void:
	var suite: FacilityEnvironmentTestSuite = (
		FacilityEnvironmentTestSuiteScript.new()
	)
	suite.run()
	_collect_suite_results(suite.get_assertion_count(), suite.get_failure_count())


func _run_colony_work_test_suite() -> void:
	var suite: ColonyWorkTestSuite = ColonyWorkTestSuiteScript.new()
	suite.run()
	_collect_suite_results(suite.get_assertion_count(), suite.get_failure_count())


func _run_act1_environment_chapters_test_suite() -> void:
	var suite: Act1EnvironmentChaptersTestSuite = (
		Act1EnvironmentChaptersTestSuiteScript.new()
	)
	suite.run()
	_collect_suite_results(suite.get_assertion_count(), suite.get_failure_count())


func _run_act1_modular_migration_test_suite() -> void:
	var suite: Act1ModularMigrationTestSuite = (
		Act1ModularMigrationTestSuiteScript.new()
	)
	suite.run()
	_collect_suite_results(suite.get_assertion_count(), suite.get_failure_count())


func _run_act1_finale_test_suite() -> void:
	var suite: Act1FinaleTestSuite = Act1FinaleTestSuiteScript.new()
	suite.run()
	_collect_suite_results(suite.get_assertion_count(), suite.get_failure_count())


func _run_v1_release_readiness_test_suite() -> void:
	var suite: V1ReleaseReadinessTestSuite = (
		V1ReleaseReadinessTestSuiteScript.new()
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


func _run_profile_playtime_state_test_suite() -> void:
	var suite: ProfilePlaytimeStateTestSuite = (
		ProfilePlaytimeStateTestSuiteScript.new()
	)
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


func _run_production_assets_test_suite() -> void:
	var suite: ProductionAssetsTestSuite = (
		ProductionAssetsTestSuiteScript.new()
	)
	suite.run(root)
	_collect_suite_results(
		suite.get_assertion_count(),
		suite.get_failure_count()
	)


func _run_production_audio_test_suite() -> void:
	var suite: ProductionAudioTestSuite = (
		ProductionAudioTestSuiteScript.new()
	)
	suite.run(root)
	_collect_suite_results(
		suite.get_assertion_count(),
		suite.get_failure_count()
	)


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


func _run_ant_behavior_animation_test_suite() -> void:
	var suite: AntBehaviorAnimationTestSuite = (
		AntBehaviorAnimationTestSuiteScript.new()
	)
	suite.run(root)
	_collect_suite_results(suite.get_assertion_count(), suite.get_failure_count())


func _run_facility_layout_accessibility_test_suite() -> void:
	var suite: FacilityLayoutAccessibilityTestSuite = (
		FacilityLayoutAccessibilityTestSuiteScript.new()
	)
	suite.run(root)
	_collect_suite_results(suite.get_assertion_count(), suite.get_failure_count())


func _run_worker_observation_panel_test_suite() -> void:
	var suite: WorkerObservationPanelTestSuite = (
		WorkerObservationPanelTestSuiteScript.new()
	)
	suite.run(root)
	_collect_suite_results(suite.get_assertion_count(), suite.get_failure_count())


func _run_habitat_spatial_projection_test_suite() -> void:
	var suite: HabitatSpatialProjectionTestSuite = (
		HabitatSpatialProjectionTestSuiteScript.new()
	)
	suite.run()
	_collect_suite_results(suite.get_assertion_count(), suite.get_failure_count())


func _run_facility_world_interaction_test_suite() -> void:
	var suite: FacilityWorldInteractionTestSuite = (
		FacilityWorldInteractionTestSuiteScript.new()
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


func _run_campaign_journal_scene_test_suite() -> void:
	var suite: CampaignJournalSceneTestSuite = (
		CampaignJournalSceneTestSuiteScript.new()
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


func _run_act1_test_tube_scene_test_suite() -> void:
	var suite: Act1TestTubeSceneTestSuite = (
		Act1TestTubeSceneTestSuiteScript.new()
	)
	suite.run(root)
	_collect_suite_results(suite.get_assertion_count(), suite.get_failure_count())


func _collect_suite_results(assertion_count: int, failure_count: int) -> void:
	_assertion_count += assertion_count
	_failure_count += failure_count
