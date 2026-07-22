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
const ViewAdapterTestSuiteScript: Script = preload(
	"res://tests/view/view_adapter_test_suite.gd"
)
const LifecycleDebugSceneTestSuiteScript: Script = preload(
	"res://tests/scenes/lifecycle_debug_scene_test_suite.gd"
)
const HumidityMainSceneTestSuiteScript: Script = preload(
	"res://tests/scenes/humidity_main_scene_test_suite.gd"
)

var _assertion_count: int = 0
var _failure_count: int = 0


func _initialize() -> void:
	call_deferred("_run_all_tests")


func _run_all_tests() -> void:
	_run_simulation_clock_test_suite()
	_run_lifecycle_test_suite()
	_run_humidity_relocation_test_suite()
	_run_view_adapter_test_suite()
	_run_lifecycle_debug_scene_test_suite()
	_run_humidity_main_scene_test_suite()

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


func _run_view_adapter_test_suite() -> void:
	var suite: ViewAdapterTestSuite = ViewAdapterTestSuiteScript.new()
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


func _collect_suite_results(assertion_count: int, failure_count: int) -> void:
	_assertion_count += assertion_count
	_failure_count += failure_count
