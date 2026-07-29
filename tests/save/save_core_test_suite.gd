class_name SaveCoreTestSuite
extends RefCounted

const SPECIES_A_DATA: SpeciesData = preload(
	"res://data/species/species_a.tres"
)
const COMBINED_SCENARIO_DATA: HabitatScenarioData = preload(
	"res://data/habitats/combined_observation_slice.tres"
)
const LIFECYCLE_SIGNATURE: Script = preload(
	"res://tests/support/simulation_snapshot_signature.gd"
)
const TEST_TIMESTAMP: String = "2026-07-28T12:00:00Z"
const TEST_SLOT_ID: String = "r2_test_slot"
const TEST_SAVE_PATH: String = "user://r2_save_tests/slot.json"
const FAULT_SAVE_PATH: String = "user://r2_save_tests/fault.json"
const LEGACY_FIXTURE_PATH: String = (
	"res://tests/fixtures/save/r2_authority_v0_lifecycle.json"
)
const NO_ENTITY_ID: int = -1

var _assertion_count: int = 0
var _failure_count: int = 0


func run() -> void:
	_test_canonical_encoding()
	_test_legacy_numeric_encoding_migrates()
	_test_profile_playtime_envelope_metadata()
	_test_combined_round_trip_during_relocation()
	_test_pending_command_survives_boundary()
	_test_mid_tick_capture_is_deferred()
	_test_clock_state_round_trip()
	_test_speed_metadata_does_not_change_state()
	_test_lifecycle_round_trip()
	_test_frozen_configuration_is_authoritative()
	_test_tampering_and_future_versions_are_rejected()
	_test_legacy_schema_migration()
	_test_atomic_commit_and_backup_recovery()
	_test_fault_injection_preserves_a_valid_candidate()
	_test_loaded_state_is_isolated()
	_test_loaded_state_soak()
	_cleanup_save_path(TEST_SAVE_PATH)
	_cleanup_save_path(FAULT_SAVE_PATH)


func get_assertion_count() -> int:
	return _assertion_count


func get_failure_count() -> int:
	return _failure_count


func _test_canonical_encoding() -> void:
	var first: Dictionary = {
		"z": [3, true, "ant"],
		"a": {"right": 0.5, "left": 0.3},
	}
	var second: Dictionary = {
		"a": {"left": 0.3, "right": 0.5},
		"z": [3, true, "ant"],
	}
	_expect_string(
		CanonicalSaveJson.encode(first),
		CanonicalSaveJson.encode(second),
		"canonical save encoding ignores Dictionary insertion order"
	)
	_expect_string(
		CanonicalSaveJson.sha256(first),
		CanonicalSaveJson.sha256(second),
		"canonical save hashes are stable across insertion order"
	)
	_expect_string(
		CanonicalSaveJson.encode(NAN),
		"",
		"canonical save encoding rejects NaN"
	)
	var precision_fixture: Dictionary = {
		"waste_stored": 0.000916170838666018,
	}
	var encoded: String = CanonicalSaveJson.encode(precision_fixture)
	var parser := JSON.new()
	_expect_int(
		parser.parse(encoded),
		OK,
		"canonical high-precision float JSON parses"
	)
	_expect_string(
		CanonicalSaveJson.encode(parser.data),
		encoded,
		"canonical high-precision float encoding is JSON-round-trip stable"
	)


func _test_legacy_numeric_encoding_migrates() -> void:
	var simulation: ColonySimulation = _new_combined_simulation()
	_expect_true(
		_advance_ticks(simulation, 2),
		"legacy numeric fixture advances"
	)
	var service := SaveGameService.new()
	var legacy: Dictionary = service.create_envelope(
		simulation,
		_clock_at(2),
		TEST_SLOT_ID,
		TEST_TIMESTAMP
	)
	legacy["state_payload"]["zones"][0]["humidity"] = 0.6300000000000001
	legacy["frozen_config_hash"] = CanonicalSaveJson.sha256_legacy(
		legacy["frozen_config_bundle"]
	)
	legacy["save_checksum"] = ""
	var checksum_input: Dictionary = legacy.duplicate(true)
	checksum_input.erase("save_checksum")
	legacy["save_checksum"] = CanonicalSaveJson.sha256_legacy(
		checksum_input
	)
	var result: Dictionary = service.load_envelope(legacy)
	_expect_true(
		result.get("ok", false),
		"legacy numeric checksum remains loadable: %s"
			% result.get("error", "")
	)
	_expect_true(
		result.get("migrated", false),
		"legacy numeric encoding is explicitly resealed"
	)
	if result.get("ok", false):
		_expect_string(
			result["envelope"]["save_checksum"],
			service.seal_envelope(result["envelope"])["save_checksum"],
			"legacy numeric envelope is resealed with current encoding"
		)


func _test_profile_playtime_envelope_metadata() -> void:
	var simulation: ColonySimulation = _new_combined_simulation()
	var service := SaveGameService.new()
	var playtime := ProfilePlaytimeState.new()
	playtime.advance_seconds(
		125.5,
		CampaignState.Chapter.FOUNDING_OBSERVATION,
		false
	)
	var envelope: Dictionary = service.create_envelope(
		simulation,
		_clock_at(0),
		TEST_SLOT_ID,
		TEST_TIMESTAMP,
		playtime.create_save_data()
	)
	_expect_int(
		int(envelope.get("format_version", -1)),
		SaveGameService.CURRENT_FORMAT_VERSION,
		"new saves use the current envelope format"
	)
	_expect_true(
		ProfilePlaytimeState.is_valid_save_data(
			envelope.get("profile_playtime", {})
		),
		"new saves contain validated profile playtime metadata"
	)
	var load_result: Dictionary = service.load_envelope(envelope)
	_expect_true(
		load_result.get("ok", false),
		"playtime-bearing envelope loads"
	)
	if load_result.get("ok", false):
		var restored := ProfilePlaytimeState.new()
		_expect_true(
			restored.restore(
				load_result["envelope"]["profile_playtime"]
			),
			"loaded playtime metadata restores"
		)
		_expect_float(
			restored.get_active_seconds(),
			125.5,
			"active profile time survives envelope round trip"
		)

	var tampered: Dictionary = envelope.duplicate(true)
	tampered["profile_playtime"]["active_microseconds"] += 1
	_expect_true(
		not service.load_envelope(tampered).get("ok", false),
		"checksum protects profile playtime metadata"
	)
	var invalid_playtime: Dictionary = playtime.create_save_data()
	invalid_playtime["active_microseconds"] = -1
	_expect_true(
		service.create_envelope(
			simulation,
			_clock_at(0),
			TEST_SLOT_ID,
			TEST_TIMESTAMP,
			invalid_playtime
		).is_empty(),
		"invalid playtime metadata cannot be saved"
	)

	var legacy: Dictionary = envelope.duplicate(true)
	legacy.erase("profile_playtime")
	legacy["format_version"] = SaveGameService.LEGACY_FORMAT_VERSION
	legacy["game_version"] = "0.3.0"
	legacy = service.seal_envelope(legacy)
	var legacy_result: Dictionary = service.load_envelope(legacy)
	_expect_true(
		legacy_result.get("ok", false),
		"legacy format without playtime metadata migrates"
	)
	_expect_true(
		legacy_result.get("migrated", false),
		"legacy envelope reports metadata migration"
	)
	if legacy_result.get("ok", false):
		var migrated_playtime := ProfilePlaytimeState.new()
		_expect_true(
			migrated_playtime.restore(
				legacy_result["envelope"]["profile_playtime"]
			),
			"migrated envelope contains valid playtime metadata"
		)
		_expect_true(
			migrated_playtime.has_legacy_gap(),
			"legacy profile exposes its incomplete timing history"
		)
		_expect_float(
			migrated_playtime.get_active_seconds(),
			0.0,
			"migration does not invent historical playtime"
		)


func _test_combined_round_trip_during_relocation() -> void:
	var original: ColonySimulation = _new_combined_simulation()
	var snapshot: GameSnapshot = _advance_to_active_relocation(original)
	_expect_true(
		_has_active_relocation(snapshot),
		"round-trip fixture reaches an active brood relocation"
	)
	var clock: SimulationClock = _clock_at(
		snapshot.simulation_tick,
		SimulationClock.FAST_SPEED,
		false
	)
	var service: SaveGameService = SaveGameService.new()
	var envelope: Dictionary = service.create_envelope(
		original,
		clock,
		TEST_SLOT_ID,
		TEST_TIMESTAMP
	)
	_expect_true(not envelope.is_empty(), "active relocation can be captured")
	_expect_true(
		not CanonicalSaveJson.encode(envelope).contains("AntView"),
		"save data contains no view-node state"
	)
	var load_result: Dictionary = service.load_envelope(envelope)
	_expect_true(
		load_result.get("ok", false),
		"active relocation save loads successfully"
	)
	if not load_result.get("ok", false):
		return
	var restored: ColonySimulation = load_result["simulation"]
	_expect_string(
		_signature(restored.create_game_snapshot()),
		_signature(snapshot),
		"active relocation is snapshot-equivalent after load"
	)
	for step: int in 400:
		_submit_available_action(original)
		_submit_available_action(restored)
		var next_tick: int = snapshot.simulation_tick + step + 1
		_expect_true(
			original.advance_tick(next_tick),
			"uninterrupted simulation accepts post-save Tick %d" % next_tick
		)
		_expect_true(
			restored.advance_tick(next_tick),
			"restored simulation accepts post-save Tick %d" % next_tick
		)
		_expect_string(
			_signature(restored.create_game_snapshot()),
			_signature(original.create_game_snapshot()),
			"loaded and uninterrupted states match at Tick %d" % next_tick
		)


func _test_pending_command_survives_boundary() -> void:
	var simulation: ColonySimulation = _new_combined_simulation()
	var snapshot: GameSnapshot = _advance_to_phase(
		simulation,
		ScenarioSequenceSnapshot.Phase.IDENTITY_OBSERVATION
	)
	_expect_true(
		simulation.submit_continue_observation_action(),
		"identity command can be queued before saving"
	)
	snapshot = simulation.create_game_snapshot()
	_expect_true(
		snapshot.sequence.continue_action_pending,
		"queued command is visible before save"
	)
	var service: SaveGameService = SaveGameService.new()
	var envelope: Dictionary = service.create_envelope(
		simulation,
		_clock_at(snapshot.simulation_tick),
		TEST_SLOT_ID,
		TEST_TIMESTAMP
	)
	var records: Array = envelope.get("pending_commands", [])
	_expect_int(records.size(), 1, "save contains one pending command")
	if not records.is_empty():
		_expect_int(
			int(records[0]["sequence_id"]),
			1,
			"first pending command has a stable sequence ID"
		)
	var load_result: Dictionary = service.load_envelope(envelope)
	_expect_true(
		load_result.get("ok", false),
		"save with pending command loads successfully"
	)
	if not load_result.get("ok", false):
		return
	var restored: ColonySimulation = load_result["simulation"]
	var restored_snapshot: GameSnapshot = restored.create_game_snapshot()
	_expect_true(
		restored_snapshot.sequence.continue_action_pending,
		"pending command remains pending after load"
	)
	_expect_int(
		restored_snapshot.sequence.phase,
		ScenarioSequenceSnapshot.Phase.IDENTITY_OBSERVATION,
		"loading does not apply or advance a pending command"
	)
	_expect_true(
		restored.advance_tick(restored_snapshot.simulation_tick + 1),
		"first legal Tick after load applies the pending command"
	)
	restored_snapshot = restored.create_game_snapshot()
	_expect_int(
		restored_snapshot.sequence.phase,
		ScenarioSequenceSnapshot.Phase.HUMIDITY_OBSERVATION,
		"pending identity command applies exactly at the next Tick"
	)
	_expect_true(
		not restored_snapshot.sequence.continue_action_pending,
		"applied command is removed from the restored queue"
	)


func _test_clock_state_round_trip() -> void:
	var simulation: ColonySimulation = _new_combined_simulation()
	_expect_true(
		_advance_ticks(simulation, 25),
		"clock fixture advances simulation to Tick 25"
	)
	var clock: SimulationClock = _clock_at(
		25,
		SimulationClock.VERY_FAST_SPEED,
		true
	)
	var service: SaveGameService = SaveGameService.new()
	var envelope: Dictionary = service.create_envelope(
		simulation,
		clock,
		TEST_SLOT_ID,
		TEST_TIMESTAMP
	)
	var load_result: Dictionary = service.load_envelope(envelope)
	_expect_true(load_result.get("ok", false), "clock state loads")
	if not load_result.get("ok", false):
		return
	var restored_clock: SimulationClock = load_result["clock"]
	_expect_int(
		restored_clock.get_tick_index(),
		25,
		"clock Tick is restored"
	)
	_expect_int(
		restored_clock.get_speed_multiplier(),
		SimulationClock.VERY_FAST_SPEED,
		"clock speed is restored"
	)
	_expect_true(restored_clock.is_paused(), "clock pause is restored")
	_expect_float(
		restored_clock.get_interpolation_alpha(),
		0.0,
		"load resumes from an exact fixed-Tick boundary"
	)
	_expect_int(
		restored_clock.advance(1.0),
		0,
		"restored paused clock does not advance"
	)
	var mismatched_clock: SimulationClock = _clock_at(24)
	_expect_true(
		service.create_envelope(
			simulation,
			mismatched_clock,
			TEST_SLOT_ID,
			TEST_TIMESTAMP
		).is_empty(),
		"save capture rejects a clock/state Tick mismatch"
	)


func _test_mid_tick_capture_is_deferred() -> void:
	var simulation: ColonySimulation = ColonySimulation.new(SPECIES_A_DATA)
	var target_tick: int = SPECIES_A_DATA.first_egg_delay_ticks
	_expect_true(
		_advance_ticks(simulation, target_tick - 1),
		"mid-Tick fixture reaches the Tick before egg laying"
	)
	var service: SaveGameService = SaveGameService.new()
	var clock: SimulationClock = _clock_at(target_tick)
	var captured_during_tick: Dictionary = {"empty": false, "called": false}
	var callback: Callable = (
		func(_entity_id: int, _simulation_tick: int) -> void:
			captured_during_tick["called"] = true
			captured_during_tick["empty"] = service.create_envelope(
				simulation,
				clock,
				TEST_SLOT_ID,
				TEST_TIMESTAMP
			).is_empty()
	)
	simulation.egg_laid.connect(callback)
	_expect_true(
		simulation.advance_tick(target_tick),
		"mid-Tick fixture applies the egg-laying Tick"
	)
	simulation.egg_laid.disconnect(callback)
	_expect_true(
		captured_during_tick["called"],
		"mid-Tick fixture observes the lifecycle signal"
	)
	_expect_true(
		captured_during_tick["empty"],
		"save capture is refused until the fixed Tick is complete"
	)
	_expect_true(
		not service.create_envelope(
			simulation,
			clock,
			TEST_SLOT_ID,
			TEST_TIMESTAMP
		).is_empty(),
		"same state can be captured immediately after the Tick succeeds"
	)


func _test_speed_metadata_does_not_change_state() -> void:
	var simulation: ColonySimulation = _new_combined_simulation()
	_expect_true(
		_advance_ticks(simulation, 40),
		"speed metadata fixture reaches a shared Tick"
	)
	var service: SaveGameService = SaveGameService.new()
	var expected_signature: String = _signature(
		simulation.create_game_snapshot()
	)
	for speed: int in [
		SimulationClock.NORMAL_SPEED,
		SimulationClock.FAST_SPEED,
		SimulationClock.VERY_FAST_SPEED,
	]:
		var envelope: Dictionary = service.create_envelope(
			simulation,
			_clock_at(40, speed, false),
			TEST_SLOT_ID,
			TEST_TIMESTAMP
		)
		var load_result: Dictionary = service.load_envelope(envelope)
		_expect_true(
			load_result.get("ok", false),
			"speed %d save loads" % speed
		)
		if not load_result.get("ok", false):
			continue
		_expect_int(
			load_result["clock"].get_speed_multiplier(),
			speed,
			"speed %d metadata is restored" % speed
		)
		_expect_string(
			_signature(load_result["simulation"].create_game_snapshot()),
			expected_signature,
			"speed %d does not change same-Tick authority" % speed
		)


func _test_lifecycle_round_trip() -> void:
	var simulation: ColonySimulation = ColonySimulation.new(SPECIES_A_DATA)
	var target_tick: int = (
		SPECIES_A_DATA.first_egg_delay_ticks
		+ SPECIES_A_DATA.egg_duration_ticks
		+ 3
	)
	_expect_true(
		_advance_ticks(simulation, target_tick),
		"lifecycle-only fixture advances to a non-initial state"
	)
	var service: SaveGameService = SaveGameService.new()
	var envelope: Dictionary = service.create_envelope(
		simulation,
		_clock_at(target_tick),
		"lifecycle_slot",
		TEST_TIMESTAMP
	)
	var load_result: Dictionary = service.load_envelope(envelope)
	_expect_true(
		load_result.get("ok", false),
		"lifecycle-only state loads without habitat data"
	)
	if not load_result.get("ok", false):
		return
	var restored: ColonySimulation = load_result["simulation"]
	_expect_string(
		LIFECYCLE_SIGNATURE.canonical_snapshot(
			restored.create_snapshot()
		),
		LIFECYCLE_SIGNATURE.canonical_snapshot(
			simulation.create_snapshot()
		),
		"lifecycle-only state is equivalent after load"
	)


func _test_frozen_configuration_is_authoritative() -> void:
	var species_copy: SpeciesData = SPECIES_A_DATA.duplicate(true) as SpeciesData
	var scenario_copy: HabitatScenarioData = (
		COMBINED_SCENARIO_DATA.duplicate(true) as HabitatScenarioData
	)
	var original_water_amount: float = (
		scenario_copy.humidity_adjustment_amount
	)
	var simulation: ColonySimulation = ColonySimulation.new(
		species_copy,
		scenario_copy
	)
	var snapshot: GameSnapshot = _advance_until_water_available(simulation)
	_expect_true(
		snapshot.colony.water_action_available,
		"frozen-config fixture reaches the water action"
	)
	var service: SaveGameService = SaveGameService.new()
	var envelope: Dictionary = service.create_envelope(
		simulation,
		_clock_at(snapshot.simulation_tick),
		TEST_SLOT_ID,
		TEST_TIMESTAMP
	)
	scenario_copy.humidity_adjustment_amount = 0.001
	species_copy.brood_humidity_min = 0.99
	var load_result: Dictionary = service.load_envelope(envelope)
	_expect_true(
		load_result.get("ok", false),
		"save loads after source Resources are mutated"
	)
	if not load_result.get("ok", false):
		return
	var restored: ColonySimulation = load_result["simulation"]
	var before: GameSnapshot = restored.create_game_snapshot()
	var before_humidity: float = (
		before.colony.find_zone(
			COMBINED_SCENARIO_DATA.humidity_adjustment_zone_id
		).humidity
	)
	_expect_true(
		restored.submit_water_action(),
		"restored simulation accepts its frozen water action"
	)
	_expect_true(
		restored.advance_tick(before.simulation_tick + 1),
		"restored water action applies at the next Tick"
	)
	var after_humidity: float = (
		restored.create_game_snapshot().colony.find_zone(
			COMBINED_SCENARIO_DATA.humidity_adjustment_zone_id
		).humidity
	)
	_expect_float(
		after_humidity - before_humidity,
		original_water_amount,
		"loaded water amount comes from the frozen save bundle"
	)


func _test_tampering_and_future_versions_are_rejected() -> void:
	var simulation: ColonySimulation = _new_combined_simulation()
	_expect_true(_advance_ticks(simulation, 10), "tamper fixture advances")
	var service: SaveGameService = SaveGameService.new()
	var envelope: Dictionary = service.create_envelope(
		simulation,
		_clock_at(10),
		TEST_SLOT_ID,
		TEST_TIMESTAMP
	)
	var tampered_state: Dictionary = envelope.duplicate(true)
	tampered_state["state_payload"]["simulation_tick"] = 11
	var original_signature: String = _signature(
		simulation.create_game_snapshot()
	)
	_expect_true(
		not service.load_envelope(tampered_state).get("ok", false),
		"checksum rejects state tampering"
	)
	_expect_string(
		_signature(simulation.create_game_snapshot()),
		original_signature,
		"failed load cannot mutate the active simulation"
	)
	var tampered_config: Dictionary = envelope.duplicate(true)
	tampered_config["frozen_config_bundle"]["lifecycle"][
		"pupa_duration_ticks"
	] += 1
	tampered_config = service.seal_envelope(tampered_config)
	_expect_true(
		not service.load_envelope(tampered_config).get("ok", false),
		"frozen-config hash rejects resealed configuration tampering"
	)
	var wrong_manifest: Dictionary = envelope.duplicate(true)
	wrong_manifest["content_manifest_id"] = "future-content"
	wrong_manifest = service.seal_envelope(wrong_manifest)
	_expect_true(
		not service.load_envelope(wrong_manifest).get("ok", false),
		"unknown content manifest is rejected"
	)
	var future_schema: Dictionary = envelope.duplicate(true)
	future_schema["state_schema_id"] = "r2.authority.v999"
	future_schema = service.seal_envelope(future_schema)
	_expect_true(
		not service.load_envelope(future_schema).get("ok", false),
		"unknown future state schema is rejected"
	)
	var unknown_command: Dictionary = envelope.duplicate(true)
	unknown_command["pending_commands"] = [{
		"sequence_id": 1,
		"command_type": 999,
	}]
	unknown_command["next_ids"]["pending_command_sequence_id"] = 2
	unknown_command = service.seal_envelope(unknown_command)
	_expect_true(
		not service.load_envelope(unknown_command).get("ok", false),
		"pending command whitelist rejects unknown intent"
	)
	var invalid_humidity: Dictionary = envelope.duplicate(true)
	invalid_humidity["state_payload"]["zones"][0]["humidity"] = 1.5
	invalid_humidity = service.seal_envelope(invalid_humidity)
	_expect_true(
		not service.load_envelope(invalid_humidity).get("ok", false),
		"out-of-range environmental values are rejected"
	)
	var invalid_slot: Dictionary = envelope.duplicate(true)
	invalid_slot["slot_id"] = "../escape"
	invalid_slot = service.seal_envelope(invalid_slot)
	_expect_true(
		not service.load_envelope(invalid_slot).get("ok", false),
		"slot validation rejects path-like identifiers"
	)
	_expect_true(
		not service.decode_envelope_text("{truncated").get("ok", false),
		"truncated JSON is rejected"
	)
	_expect_true(
		not service.save_to_path(
			"user://../escape.json",
			envelope
		).get("ok", false),
		"user save path validation rejects parent traversal"
	)


func _test_legacy_schema_migration() -> void:
	var service: SaveGameService = SaveGameService.new()
	var fixture_text: String = FileAccess.get_file_as_string(
		LEGACY_FIXTURE_PATH
	)
	var fixture_result: Dictionary = service.decode_envelope_text(
		fixture_text
	)
	_expect_true(
		fixture_result.get("ok", false),
		"checked-in r2.authority.v0 fixture migrates"
	)
	if fixture_result.get("ok", false):
		_expect_true(
			fixture_result["migrated"],
			"checked-in legacy fixture reports migration"
		)
		var fixture_load: Dictionary = service.load_envelope(
			fixture_result["envelope"]
		)
		_expect_true(
			fixture_load.get("ok", false),
			"checked-in legacy fixture rebuilds authority"
		)
		if fixture_load.get("ok", false):
			_expect_int(
				fixture_load["simulation"].create_snapshot().simulation_tick,
				0,
				"checked-in legacy fixture preserves its Tick"
			)

	var simulation: ColonySimulation = _new_combined_simulation()
	var snapshot: GameSnapshot = _advance_to_phase(
		simulation,
		ScenarioSequenceSnapshot.Phase.IDENTITY_OBSERVATION
	)
	_expect_true(
		simulation.submit_continue_observation_action(),
		"legacy fixture queues one command"
	)
	var legacy: Dictionary = service.create_envelope(
		simulation,
		_clock_at(snapshot.simulation_tick),
		TEST_SLOT_ID,
		TEST_TIMESTAMP
	)
	legacy["state_schema_id"] = SimulationStateCodec.LEGACY_SCHEMA_ID
	SaveFixtureDowngrade.strip_r9_fields(legacy)
	legacy["pending_commands"] = [
		ColonySimulation.PendingCommandType.CONTINUE_OBSERVATION_ACTION,
	]
	legacy["next_ids"].erase("pending_command_sequence_id")
	legacy["next_ids"].erase("facility_id")
	legacy["next_ids"].erase("connection_id")
	legacy["state_payload"].erase("campaign")
	legacy["state_payload"].erase("nutrition")
	legacy["state_payload"].erase("act1")
	legacy["state_payload"].erase("layout")
	_restore_legacy_zone_connections(legacy)
	for ant: Dictionary in legacy["state_payload"]["ants"]:
		ant.erase("protein_supported_growth_ticks")
		ant.erase("feeding_task")
	var legacy_habitat: Dictionary = (
		legacy["frozen_config_bundle"]["habitat"]
	)
	legacy_habitat.erase("lifecycle_active")
	legacy_habitat.erase("nutrition_config")
	legacy_habitat.erase("protein_placement_zone_id")
	legacy_habitat.erase("protein_portions")
	legacy_habitat.erase("founding_care_config")
	legacy_habitat.erase("facility_catalog_config")
	_strip_r8_environment_fields(legacy)
	legacy["frozen_config_hash"] = CanonicalSaveJson.sha256(
		legacy["frozen_config_bundle"]
	)
	legacy = service.seal_envelope(legacy)
	var load_result: Dictionary = service.load_envelope(legacy)
	_expect_true(
		load_result.get("ok", false),
		"legacy v0 state migrates through the explicit chain: %s"
			% load_result.get("error", "")
	)
	if not load_result.get("ok", false):
		return
	_expect_true(load_result["migrated"], "legacy load reports migration")
	var current: Dictionary = load_result["envelope"]
	_expect_string(
		current["state_schema_id"],
		SimulationStateCodec.CURRENT_SCHEMA_ID,
		"migration produces the current schema"
	)
	_expect_int(
		int(current["pending_commands"][0]["sequence_id"]),
		1,
		"migration assigns stable command sequence IDs"
	)
	var restored: ColonySimulation = load_result["simulation"]
	_expect_true(
		restored.advance_tick(snapshot.simulation_tick + 1),
		"migrated command applies on the next legal Tick"
	)
	_expect_int(
		restored.create_game_snapshot().sequence.phase,
		ScenarioSequenceSnapshot.Phase.HUMIDITY_OBSERVATION,
		"migrated command preserves player intent"
	)
	_expect_string(
		legacy["state_schema_id"],
		SimulationStateCodec.LEGACY_SCHEMA_ID,
		"migration does not mutate the source save"
	)


func _restore_legacy_zone_connections(envelope: Dictionary) -> void:
	var config_by_zone: Dictionary[String, Array] = {}
	for zone: Dictionary in envelope["frozen_config_bundle"]["habitat"]["zones"]:
		config_by_zone[String(zone["zone_id"])] = (
			zone["connected_zone_ids"] as Array
		).duplicate()
	for zone: Dictionary in envelope["state_payload"]["zones"]:
		zone["connected_zone_ids"] = config_by_zone.get(
			String(zone["zone_id"]),
			[]
		)


func _strip_r8_environment_fields(envelope: Dictionary) -> void:
	var habitat: Dictionary = envelope["frozen_config_bundle"]["habitat"]
	habitat.erase("environment_config")
	for zone: Dictionary in habitat["zones"]:
		zone.erase("light_exposure")
		zone.erase("pollution")
	for zone: Dictionary in envelope["state_payload"]["zones"]:
		zone.erase("light_exposure")
		zone.erase("pollution")


func _test_atomic_commit_and_backup_recovery() -> void:
	_cleanup_save_path(TEST_SAVE_PATH)
	var simulation: ColonySimulation = _new_combined_simulation()
	var service: SaveGameService = SaveGameService.new()
	_expect_true(_advance_ticks(simulation, 10), "first disk fixture advances")
	var first: Dictionary = service.create_envelope(
		simulation,
		_clock_at(10),
		TEST_SLOT_ID,
		TEST_TIMESTAMP
	)
	var save_result: Dictionary = service.save_to_path(
		TEST_SAVE_PATH,
		first
	)
	_expect_true(save_result.get("ok", false), "first atomic save commits")
	_expect_true(
		_advance_ticks(simulation, 11),
		"second disk fixture advances one Tick"
	)
	var second: Dictionary = service.create_envelope(
		simulation,
		_clock_at(11),
		TEST_SLOT_ID,
		TEST_TIMESTAMP
	)
	save_result = service.save_to_path(TEST_SAVE_PATH, second)
	_expect_true(save_result.get("ok", false), "second atomic save commits")
	_expect_true(
		save_result.get("backup_available", false),
		"second commit retains the previous valid save as backup"
	)
	var load_result: Dictionary = service.load_from_path(TEST_SAVE_PATH)
	_expect_true(load_result.get("ok", false), "primary disk save loads")
	if load_result.get("ok", false):
		_expect_string(
			load_result["recovered_from"],
			"primary",
			"normal load prefers the primary save"
		)
		_expect_int(
			load_result["simulation"].create_snapshot().simulation_tick,
			11,
			"primary contains the newest committed Tick"
		)
	_corrupt_primary(TEST_SAVE_PATH)
	load_result = service.load_from_path(TEST_SAVE_PATH)
	_expect_true(
		load_result.get("ok", false),
		"corrupted primary falls back to a valid backup"
	)
	if load_result.get("ok", false):
		_expect_string(
			load_result["recovered_from"],
			"backup",
			"recovery identifies the backup source"
		)
		_expect_int(
			load_result["simulation"].create_snapshot().simulation_tick,
			10,
			"backup retains the previous committed Tick"
		)


func _test_fault_injection_preserves_a_valid_candidate() -> void:
	_cleanup_save_path(FAULT_SAVE_PATH)
	var simulation: ColonySimulation = _new_combined_simulation()
	var service: SaveGameService = SaveGameService.new()
	_expect_true(_advance_ticks(simulation, 5), "fault fixture advances")
	var first: Dictionary = service.create_envelope(
		simulation,
		_clock_at(5),
		TEST_SLOT_ID,
		TEST_TIMESTAMP
	)
	_expect_true(
		service.save_to_path(FAULT_SAVE_PATH, first).get("ok", false),
		"fault fixture creates an initial primary"
	)
	_expect_true(_advance_ticks(simulation, 6), "fault fixture advances again")
	var second: Dictionary = service.create_envelope(
		simulation,
		_clock_at(6),
		TEST_SLOT_ID,
		TEST_TIMESTAMP
	)
	var fault_result: Dictionary = service.save_to_path(
		FAULT_SAVE_PATH,
		second,
		SaveGameService.FaultInjection.AFTER_TEMP_WRITE
	)
	_expect_true(
		not fault_result.get("ok", false),
		"failure injection interrupts after temporary write"
	)
	var load_result: Dictionary = service.load_from_path(FAULT_SAVE_PATH)
	_expect_true(
		load_result.get("ok", false),
		"old primary remains valid after temporary-write failure"
	)
	if load_result.get("ok", false):
		_expect_int(
			load_result["simulation"].create_snapshot().simulation_tick,
			5,
			"temporary-write failure does not expose an uncommitted save"
		)
	fault_result = service.save_to_path(
		FAULT_SAVE_PATH,
		second,
		SaveGameService.FaultInjection.AFTER_BACKUP_ROTATION
	)
	_expect_true(
		not fault_result.get("ok", false),
		"failure injection interrupts after backup rotation"
	)
	load_result = service.load_from_path(FAULT_SAVE_PATH)
	_expect_true(
		load_result.get("ok", false),
		"backup rotation failure leaves a valid recovery candidate"
	)
	if load_result.get("ok", false):
		_expect_int(
			load_result["simulation"].create_snapshot().simulation_tick,
			5,
			"backup recovery returns the last committed state"
		)


func _test_loaded_state_is_isolated() -> void:
	var simulation: ColonySimulation = _new_combined_simulation()
	_expect_true(_advance_ticks(simulation, 12), "isolation fixture advances")
	var service: SaveGameService = SaveGameService.new()
	var envelope: Dictionary = service.create_envelope(
		simulation,
		_clock_at(12),
		TEST_SLOT_ID,
		TEST_TIMESTAMP
	)
	var first_result: Dictionary = service.load_envelope(envelope)
	var second_result: Dictionary = service.load_envelope(envelope)
	_expect_true(
		first_result.get("ok", false) and second_result.get("ok", false),
		"one envelope can create independent loaded sessions"
	)
	if (
		not first_result.get("ok", false)
		or not second_result.get("ok", false)
	):
		return
	envelope["state_payload"]["simulation_tick"] = 999
	first_result["envelope"]["state_payload"]["simulation_tick"] = 888
	var first_simulation: ColonySimulation = first_result["simulation"]
	var second_simulation: ColonySimulation = second_result["simulation"]
	_expect_int(
		first_simulation.create_snapshot().simulation_tick,
		12,
		"mutating returned save data cannot alter restored authority"
	)
	_expect_int(
		second_simulation.create_snapshot().simulation_tick,
		12,
		"loaded sessions do not share mutable state"
	)
	_expect_true(
		first_simulation.advance_tick(13),
		"first loaded session advances independently"
	)
	_expect_int(
		second_simulation.create_snapshot().simulation_tick,
		12,
		"advancing one loaded session does not advance another"
	)


func _test_loaded_state_soak() -> void:
	var simulation: ColonySimulation = _new_combined_simulation()
	var snapshot: GameSnapshot = _complete_session(simulation)
	_expect_true(snapshot.sequence.completed, "soak fixture completes the session")
	var service: SaveGameService = SaveGameService.new()
	var envelope: Dictionary = service.create_envelope(
		simulation,
		_clock_at(snapshot.simulation_tick),
		TEST_SLOT_ID,
		TEST_TIMESTAMP
	)
	var load_result: Dictionary = service.load_envelope(envelope)
	_expect_true(load_result.get("ok", false), "completed save loads for soak")
	if not load_result.get("ok", false):
		return
	var restored: ColonySimulation = load_result["simulation"]
	var start_tick: int = restored.create_snapshot().simulation_tick
	var accepted: bool = true
	for tick: int in range(start_tick + 1, start_tick + 10_001):
		if not restored.advance_tick(tick):
			accepted = false
			break
	_expect_true(accepted, "loaded state survives 10,000 sequential Ticks")
	_expect_true(
		restored.has_valid_habitat_ownership(),
		"loaded state preserves ownership after the soak"
	)
	var final_snapshot: GameSnapshot = restored.create_game_snapshot()
	for zone: HabitatZoneSnapshot in final_snapshot.colony.zones:
		_expect_true(
			not is_nan(zone.humidity) and not is_inf(zone.humidity),
			"loaded soak leaves zone %s finite" % String(zone.zone_id)
		)


func _new_combined_simulation() -> ColonySimulation:
	var simulation: ColonySimulation = ColonySimulation.new(
		SPECIES_A_DATA,
		COMBINED_SCENARIO_DATA
	)
	_expect_true(simulation.is_ready(), "combined save fixture is ready")
	return simulation


func _advance_to_active_relocation(
	simulation: ColonySimulation
) -> GameSnapshot:
	var snapshot: GameSnapshot = _advance_to_phase(
		simulation,
		ScenarioSequenceSnapshot.Phase.HUMIDITY_OBSERVATION
	)
	while (
		not _has_active_relocation(snapshot)
		and snapshot.simulation_tick < 2000
	):
		if not simulation.advance_tick(snapshot.simulation_tick + 1):
			break
		snapshot = simulation.create_game_snapshot()
	return snapshot


func _advance_until_water_available(
	simulation: ColonySimulation
) -> GameSnapshot:
	var snapshot: GameSnapshot = _advance_to_phase(
		simulation,
		ScenarioSequenceSnapshot.Phase.HUMIDITY_OBSERVATION
	)
	while (
		not snapshot.colony.water_action_available
		and snapshot.simulation_tick < 3000
	):
		if not simulation.advance_tick(snapshot.simulation_tick + 1):
			break
		snapshot = simulation.create_game_snapshot()
	return snapshot


func _advance_to_phase(
	simulation: ColonySimulation,
	target_phase: ScenarioSequenceSnapshot.Phase
) -> GameSnapshot:
	var snapshot: GameSnapshot = simulation.create_game_snapshot()
	while (
		snapshot.sequence.phase != target_phase
		and snapshot.simulation_tick < 3000
	):
		_submit_available_action(simulation)
		if not simulation.advance_tick(snapshot.simulation_tick + 1):
			break
		snapshot = simulation.create_game_snapshot()
	return snapshot


func _complete_session(simulation: ColonySimulation) -> GameSnapshot:
	var snapshot: GameSnapshot = simulation.create_game_snapshot()
	while not snapshot.sequence.completed and snapshot.simulation_tick < 5000:
		_submit_available_action(simulation)
		if not simulation.advance_tick(snapshot.simulation_tick + 1):
			break
		snapshot = simulation.create_game_snapshot()
	return snapshot


func _submit_available_action(simulation: ColonySimulation) -> bool:
	var snapshot: GameSnapshot = simulation.create_game_snapshot()
	if snapshot.sequence.continue_action_available:
		return simulation.submit_continue_observation_action()
	if snapshot.colony.water_action_available:
		return simulation.submit_water_action()
	if snapshot.scenario.place_action_available:
		return simulation.submit_place_sugar_action()
	return true


func _has_active_relocation(snapshot: GameSnapshot) -> bool:
	if snapshot == null or snapshot.colony == null:
		return false
	for ant: AntSnapshot in snapshot.colony.ants:
		if ant.worker_task_state != WorkerTaskModel.State.IDLE:
			return true
	return false


func _advance_ticks(
	simulation: ColonySimulation,
	target_tick: int
) -> bool:
	var next_tick: int = simulation.create_snapshot().simulation_tick + 1
	while next_tick <= target_tick:
		if not simulation.advance_tick(next_tick):
			return false
		next_tick += 1
	return true


func _clock_at(
	tick: int,
	speed: int = SimulationClock.NORMAL_SPEED,
	paused: bool = false
) -> SimulationClock:
	var clock: SimulationClock = SimulationClock.new()
	_expect_true(
		clock.restore_save_boundary(tick, speed, paused),
		"test clock accepts a valid save boundary"
	)
	return clock


func _signature(snapshot: GameSnapshot) -> String:
	return LIFECYCLE_SIGNATURE.canonical_game_snapshot(snapshot)


func _corrupt_primary(path: String) -> void:
	var absolute_path: String = ProjectSettings.globalize_path(path)
	var file: FileAccess = FileAccess.open(absolute_path, FileAccess.WRITE)
	if file == null:
		_record_failure(
			"test can corrupt the primary save",
			"open file",
			"null"
		)
		return
	file.store_string("{\"corrupted\":true}")
	file.close()


func _cleanup_save_path(path: String) -> void:
	var absolute_path: String = ProjectSettings.globalize_path(path)
	for candidate: String in [
		absolute_path,
		absolute_path + ".bak",
		absolute_path + ".tmp",
	]:
		if FileAccess.file_exists(candidate):
			DirAccess.remove_absolute(candidate)


func _expect_int(actual: int, expected: int, message: String) -> void:
	_assertion_count += 1
	if actual == expected:
		return
	_record_failure(message, str(expected), str(actual))


func _expect_float(actual: float, expected: float, message: String) -> void:
	_assertion_count += 1
	if is_equal_approx(actual, expected):
		return
	_record_failure(message, str(expected), str(actual))


func _expect_true(actual: bool, message: String) -> void:
	_assertion_count += 1
	if actual:
		return
	_record_failure(message, "true", "false")


func _expect_string(
	actual: String,
	expected: String,
	message: String
) -> void:
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
	printerr("  %s — expected %s, got %s" % [message, expected, actual])
