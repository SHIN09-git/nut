class_name V1ReleaseReadinessTestSuite
extends RefCounted

var _assertion_count: int = 0
var _failure_count: int = 0


func run() -> void:
	_test_max_scale_fixture_shape_and_authority()
	_test_state_indexes_follow_append_and_replacement()
	_test_release_documents_and_notices()


func get_assertion_count() -> int:
	return _assertion_count


func get_failure_count() -> int:
	return _failure_count


func _test_max_scale_fixture_shape_and_authority() -> void:
	var simulation: ColonySimulation = Act1MaxScaleFixture.create_simulation()
	_expect_true(
		simulation != null and simulation.is_ready(),
		"R16 max-scale fixture initializes"
	)
	if simulation == null or not simulation.is_ready():
		return
	var snapshot: GameSnapshot = simulation.create_game_snapshot()
	var worker_count: int = 0
	var brood_count: int = 0
	var active_task_count: int = 0
	for ant: AntSnapshot in snapshot.colony.ants:
		if ant.life_stage == AntModel.LifeStage.WORKER:
			worker_count += 1
			if ant.worker_task_state != WorkerTaskModel.State.IDLE:
				active_task_count += 1
		else:
			brood_count += 1
	_expect_int(
		worker_count,
		Act1MaxScaleFixture.TARGET_WORKER_COUNT,
		"max-scale fixture has the worker pressure ceiling"
	)
	_expect_int(
		brood_count,
		Act1MaxScaleFixture.TARGET_BROOD_COUNT,
		"max-scale fixture has the brood pressure ceiling"
	)
	_expect_int(
		snapshot.layout.facilities.size(),
		Act1MaxScaleFixture.TARGET_FACILITY_COUNT,
		"max-scale fixture has the facility pressure ceiling"
	)
	_expect_int(
		snapshot.colony.zones.size(),
		Act1MaxScaleFixture.TARGET_ZONE_COUNT,
		"max-scale fixture has the zone pressure ceiling"
	)
	_expect_int(
		snapshot.layout.connections.size(),
		Act1MaxScaleFixture.TARGET_CONNECTION_COUNT,
		"max-scale fixture has the connection pressure ceiling"
	)
	_expect_int(
		snapshot.colony.food_sources.size(),
		Act1MaxScaleFixture.TARGET_FOOD_SOURCE_COUNT,
		"max-scale fixture has the food-source pressure ceiling"
	)
	_expect_int(
		active_task_count,
		Act1MaxScaleFixture.TARGET_WORKER_COUNT,
		"every max-scale worker keeps one valid active task"
	)
	var projection: Act1TestTubeView = Act1TestTubeView.new()
	var selected: Array[AntSnapshot] = (
		projection._select_visible_ant_snapshots(snapshot.colony.ants)
	)
	var selected_worker_count: int = 0
	for ant: AntSnapshot in selected:
		if ant.life_stage == AntModel.LifeStage.WORKER:
			selected_worker_count += 1
	_expect_int(
		selected.size(),
		Act1TestTubeView.MAX_VISIBLE_ANT_VIEWS,
		"max-scale projection enforces the visible entity ceiling"
	)
	_expect_int(
		selected_worker_count,
		Act1MaxScaleFixture.TARGET_WORKER_COUNT,
		"max-scale projection keeps every active worker visible"
	)
	projection.free()
	_expect_true(
		simulation.advance_tick(simulation._state.simulation_tick + 1),
		"max-scale fixture advances one fixed Tick"
	)
	_expect_true(
		simulation.has_valid_habitat_ownership(),
		"max-scale fixture preserves authority after advancing"
	)


func _test_state_indexes_follow_append_and_replacement() -> void:
	var state := ColonyState.new()
	var first := AntModel.new(1, AntModel.LifeStage.EGG)
	state.ants.append(first)
	_expect_true(
		state.get_ant(1) == first,
		"entity index resolves the appended model"
	)
	var replacement := AntModel.new(1, AntModel.LifeStage.LARVA)
	state.ants[0] = replacement
	state._invalidate_lookup_indexes()
	_expect_true(
		state.get_ant(1) == replacement,
		"entity index rebuilds after same-size replacement"
	)
	var first_zone := HabitatZoneState.new(
		&"a",
		0.5,
		[],
		true
	)
	state.zones.append(first_zone)
	_expect_true(
		state.get_zone(&"a") == first_zone,
		"zone index resolves the appended zone"
	)
	var replacement_zone := HabitatZoneState.new(
		&"a",
		0.6,
		[],
		true
	)
	state.zones[0] = replacement_zone
	state._invalidate_lookup_indexes()
	_expect_true(
		state.get_zone(&"a") == replacement_zone,
		"zone index rebuilds after same-size replacement"
	)


func _test_release_documents_and_notices() -> void:
	_expect_true(
		SaveGameService.CURRENT_GAME_VERSION == "1.0.0-beta",
		"new save envelopes carry the beta candidate version"
	)
	for path: String in [
		"res://CREDITS.md",
		"res://PRIVACY.md",
		"res://RELEASE_NOTES_V1_0_BETA.md",
		"res://docs/release/V1_0_BETA_DISTRIBUTION_CHECKLIST.md",
		"res://docs/production/GODOT_COPYRIGHT.txt",
	]:
		_expect_true(
			FileAccess.file_exists(path),
			"release document exists: %s" % path
		)
	var notices: String = _read_text(
		"res://docs/production/GODOT_COPYRIGHT.txt"
	)
	_expect_true(
		notices.contains("Engine version: 4.7.1-stable (official)")
			and notices.contains(
				"Copyright (c) 2014-present Godot Engine contributors"
			)
			and notices.contains("FULL LICENSE TEXTS"),
		"notices come from the exact engine and include full license texts"
	)
	var privacy: String = _read_text("res://PRIVACY.md")
	_expect_true(
		privacy.contains("offline single-player")
			and privacy.contains("user accounts")
			and privacy.contains("analytics or telemetry")
			and privacy.contains(
				"%APPDATA%\\Godot\\app_userdata\\Colony Under Glass\\"
			),
		"privacy notice states the offline boundary and local data path"
	)
	var export_preset: String = _read_text("res://export_presets.cfg")
	_expect_true(
		export_preset.contains(
			"builds/windows/ColonyUnderGlass_v1.0_beta.exe"
		)
			and export_preset.contains("sucai/**,tests/**,tools/**,docs/**")
			and export_preset.contains("debug/export_console_wrapper=0"),
		"release preset uses the beta path and strips internal content"
	)


func _read_text(path: String) -> String:
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return ""
	return file.get_as_text()


func _expect_true(value: bool, message: String) -> void:
	_assertion_count += 1
	if value:
		return
	_failure_count += 1
	printerr("  %s" % message)


func _expect_int(actual: int, expected: int, message: String) -> void:
	_expect_true(
		actual == expected,
		"%s (expected %d, got %d)" % [message, expected, actual]
	)
