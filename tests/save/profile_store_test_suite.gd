class_name ProfileStoreTestSuite
extends RefCounted

const SPECIES_A_DATA: SpeciesData = preload(
	"res://data/species/species_a.tres"
)
const COMBINED_SCENARIO_DATA: HabitatScenarioData = preload(
	"res://data/habitats/combined_observation_slice.tres"
)
const TEST_PROFILE_PATH: String = "user://r3_tests/profile.json"

var _assertion_count: int = 0
var _failure_count: int = 0


func run() -> void:
	var store: ProfileStore = ProfileStore.new(TEST_PROFILE_PATH)
	store.delete_profile()
	_test_empty_profile_summary(store)
	_test_primary_backup_recovery_and_delete(store)
	_test_unsafe_profile_path_is_rejected()
	store.delete_profile()


func get_assertion_count() -> int:
	return _assertion_count


func get_failure_count() -> int:
	return _failure_count


func _test_empty_profile_summary(store: ProfileStore) -> void:
	var summary: Dictionary = store.get_summary()
	_expect_true(
		not summary.get("available", true),
		"empty profile has no playable summary"
	)
	_expect_true(
		not store.has_any_candidate(),
		"empty profile has no disk candidate"
	)


func _test_primary_backup_recovery_and_delete(store: ProfileStore) -> void:
	var simulation: ColonySimulation = ColonySimulation.new(
		SPECIES_A_DATA,
		COMBINED_SCENARIO_DATA
	)
	_expect_true(simulation.is_ready(), "profile fixture simulation is ready")
	var service: SaveGameService = SaveGameService.new()
	_expect_true(_advance_to(simulation, 5), "profile fixture reaches Tick 5")
	var first: Dictionary = service.create_envelope(
		simulation,
		_clock_at(5),
		ProfileStore.MAIN_SLOT_ID,
		"2026-07-28T08:00:00Z"
	)
	_expect_true(not first.is_empty(), "first profile envelope is valid")
	_expect_true(
		store.save_envelope(first).get("ok", false),
		"first profile save commits"
	)
	var first_summary: Dictionary = store.get_summary()
	_expect_true(
		first_summary.get("available", false),
		"committed profile exposes a summary"
	)
	_expect_int(
		int(first_summary.get("simulation_tick", -1)),
		5,
		"summary reports the saved Tick"
	)

	_expect_true(_advance_to(simulation, 6), "profile fixture reaches Tick 6")
	var second: Dictionary = service.create_envelope(
		simulation,
		_clock_at(6),
		ProfileStore.MAIN_SLOT_ID,
		"2026-07-28T08:01:00Z"
	)
	var second_result: Dictionary = store.save_envelope(second)
	_expect_true(second_result.get("ok", false), "second profile save commits")
	_expect_true(
		second_result.get("backup_available", false),
		"second profile save rotates one backup"
	)
	var backup_result: Dictionary = store.load_backup()
	_expect_true(backup_result.get("ok", false), "rotated backup loads")
	if backup_result.get("ok", false):
		_expect_int(
			backup_result["simulation"].create_snapshot().simulation_tick,
			5,
			"rotated backup retains the previous Tick"
		)

	_corrupt_primary()
	var recovered: Dictionary = store.load_best()
	_expect_true(
		recovered.get("ok", false),
		"corrupt primary falls back to the complete backup"
	)
	if recovered.get("ok", false):
		_expect_string(
			String(recovered.get("recovered_from", "")),
			"backup",
			"fallback source is visible to the profile UI"
		)
		_expect_int(
			recovered["simulation"].create_snapshot().simulation_tick,
			5,
			"fallback restores the previous Tick"
		)
	var restore_result: Dictionary = store.restore_backup()
	_expect_true(
		restore_result.get("ok", false),
		"explicit backup restore promotes a valid main profile"
	)
	_expect_true(
		store.delete_profile().get("ok", false),
		"profile delete removes all candidates"
	)
	_expect_true(
		not store.has_any_candidate(),
		"profile delete leaves no primary, backup, or temporary file"
	)


func _test_unsafe_profile_path_is_rejected() -> void:
	var store: ProfileStore = ProfileStore.new("user://../profile.json")
	_expect_true(
		not store.delete_profile().get("ok", false),
		"profile path traversal is rejected"
	)
	_expect_true(
		not store.load_best().get("ok", false),
		"unsafe profile source cannot be loaded"
	)


func _advance_to(simulation: ColonySimulation, target_tick: int) -> bool:
	var current_tick: int = simulation.create_snapshot().simulation_tick
	for tick: int in range(current_tick + 1, target_tick + 1):
		if not simulation.advance_tick(tick):
			return false
	return true


func _clock_at(tick: int) -> SimulationClock:
	var clock: SimulationClock = SimulationClock.new()
	clock.restore_save_boundary(
		tick,
		SimulationClock.NORMAL_SPEED,
		true
	)
	return clock


func _corrupt_primary() -> void:
	var path: String = ProjectSettings.globalize_path(TEST_PROFILE_PATH)
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return
	file.store_string("{corrupt")
	file.close()


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


func _record_failure(
	message: String,
	expected: String,
	actual: String
) -> void:
	_failure_count += 1
	printerr("  %s - expected %s, got %s" % [message, expected, actual])
