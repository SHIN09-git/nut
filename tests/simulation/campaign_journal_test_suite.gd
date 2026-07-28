class_name CampaignJournalTestSuite
extends RefCounted

const SPECIES_A_DATA: SpeciesData = preload(
	"res://data/species/species_a.tres"
)
const COMBINED_SCENARIO_DATA: HabitatScenarioData = preload(
	"res://data/habitats/combined_observation_slice.tres"
)

var _assertion_count: int = 0
var _failure_count: int = 0


func run() -> void:
	_test_evidence_inference_and_facility_unlocks()
	_test_snapshot_isolation_and_determinism()
	_test_pending_inference_save_and_previous_schema_migration()
	_test_invalid_campaign_authority_is_rejected()


func get_assertion_count() -> int:
	return _assertion_count


func get_failure_count() -> int:
	return _failure_count


func _test_evidence_inference_and_facility_unlocks() -> void:
	var simulation: ColonySimulation = _new_simulation()
	var initial: CampaignSnapshot = simulation.create_game_snapshot().campaign
	_expect_int(
		initial.chapter,
		CampaignState.Chapter.FOUNDING_OBSERVATION,
		"campaign starts in the explicit founding chapter"
	)
	_expect_int(
		initial.status,
		CampaignState.Status.ACTIVE,
		"campaign starts by collecting evidence"
	)
	_expect_true(
		initial.has_unlocked_facility(CampaignState.FACILITY_TEST_TUBE_NEST)
			and initial.has_unlocked_facility(
				CampaignState.FACILITY_LIGHT_COVER
			),
		"founding chapter starts with its fixed facility kit"
	)
	var identity: GameSnapshot = _advance_until_phase(
		simulation,
		ScenarioSequenceSnapshot.Phase.IDENTITY_OBSERVATION
	)
	_expect_true(identity != null, "campaign reaches first-worker evidence")
	if identity == null:
		return
	_expect_true(
		identity.campaign.has_evidence(
			CampaignState.EVIDENCE_FIRST_WORKER
		),
		"first-worker event becomes campaign evidence"
	)
	_expect_int(
		identity.campaign.status,
		CampaignState.Status.AWAITING_INFERENCE,
		"evidence opens an inference decision"
	)
	var identity_tick: int = identity.simulation_tick
	_expect_true(
		simulation.submit_campaign_inference_action(
			CampaignState.INFERENCE_FIRST_WORKER_RANDOM
		),
		"an explicit but incorrect inference is accepted as player intent"
	)
	var pending: CampaignSnapshot = simulation.create_game_snapshot().campaign
	_expect_true(
		pending.inference_action_pending,
		"inference is queued instead of mutating authority immediately"
	)
	_expect_int(
		pending.incorrect_inference_attempts,
		0,
		"queued inference does not change attempts before the next Tick"
	)
	_expect_true(
		simulation.advance_tick(identity_tick + 1),
		"next Tick evaluates the queued inference"
	)
	var rejected: CampaignSnapshot = simulation.create_game_snapshot().campaign
	_expect_int(
		rejected.incorrect_inference_attempts,
		1,
		"incorrect inference is recorded without losing progress"
	)
	_expect_int(rejected.hint_tier, 1, "incorrect inference reveals one hint tier")
	_expect_int(
		rejected.status,
		CampaignState.Status.AWAITING_INFERENCE,
		"incorrect inference keeps the decision recoverable"
	)
	_expect_true(
		simulation.submit_campaign_inference_action(
			CampaignState.INFERENCE_FIRST_WORKER
		),
		"correct first-worker inference can be submitted"
	)
	_expect_true(
		simulation.advance_tick(identity_tick + 2),
		"correct inference applies on the next Tick"
	)
	var chapter_two: CampaignSnapshot = (
		simulation.create_game_snapshot().campaign
	)
	_expect_int(
		chapter_two.chapter,
		CampaignState.Chapter.ENVIRONMENTAL_CARE,
		"correct inference advances to the environmental-care chapter"
	)
	_expect_int(
		chapter_two.completed_chapter_count,
		1,
		"first chapter completion is authoritative"
	)
	_expect_true(
		chapter_two.has_confirmed_inference(
			CampaignState.INFERENCE_FIRST_WORKER
		),
		"confirmed inference remains in the journal"
	)
	_expect_true(
		chapter_two.has_unlocked_facility(
			CampaignState.FACILITY_MICRO_FEEDING_PORT
		),
		"chapter completion unlocks its fixed facility kit"
	)

	_expect_true(
		simulation.submit_continue_observation_action(),
		"existing observation flow remains available after inference"
	)
	_expect_true(
		simulation.advance_tick(identity_tick + 3),
		"continue command applies after campaign inference"
	)
	var summary: GameSnapshot = _complete_observation_sequence(simulation)
	_expect_true(summary != null, "campaign fixture reaches the summary")
	if summary == null:
		return
	_expect_true(
		summary.campaign.has_evidence(
			CampaignState.EVIDENCE_HUMIDITY_RELOCATION
		),
		"humidity completion becomes chapter evidence"
	)
	_expect_true(
		summary.campaign.has_evidence(
			CampaignState.EVIDENCE_SUGAR_SHARING
		),
		"sugar sharing becomes chapter evidence"
	)
	_expect_int(
		summary.campaign.status,
		CampaignState.Status.AWAITING_INFERENCE,
		"second chapter waits for a final inference"
	)
	_expect_true(
		simulation.submit_campaign_inference_action(
			CampaignState.INFERENCE_ENVIRONMENT
		),
		"environment inference is submitted through the command boundary"
	)
	_expect_true(
		simulation.advance_tick(summary.simulation_tick + 1),
		"final inference applies on the next Tick"
	)
	var completed: CampaignSnapshot = simulation.create_game_snapshot().campaign
	_expect_true(completed.completed, "final inference completes the campaign")
	_expect_int(
		completed.completed_chapter_count,
		2,
		"campaign completion records both explicit chapters"
	)
	_expect_true(
		completed.has_unlocked_facility(
			CampaignState.FACILITY_SMALL_FORAGING_BOX
		),
		"campaign settlement unlocks the next fixed facility kit"
	)
	_expect_true(
		simulation.has_valid_habitat_ownership(),
		"campaign decisions preserve all habitat ownership invariants"
	)


func _test_snapshot_isolation_and_determinism() -> void:
	var first: ColonySimulation = _new_simulation()
	var second: ColonySimulation = _new_simulation()
	var first_identity: GameSnapshot = _advance_until_phase(
		first,
		ScenarioSequenceSnapshot.Phase.IDENTITY_OBSERVATION
	)
	var second_identity: GameSnapshot = _advance_until_phase(
		second,
		ScenarioSequenceSnapshot.Phase.IDENTITY_OBSERVATION
	)
	_expect_true(
		first_identity != null and second_identity != null,
		"determinism fixtures reach the same evidence boundary"
	)
	if first_identity == null or second_identity == null:
		return
	for simulation: ColonySimulation in [first, second]:
		simulation.submit_campaign_inference_action(
			CampaignState.INFERENCE_FIRST_WORKER
		)
		simulation.advance_tick(
			simulation.create_game_snapshot().simulation_tick + 1
		)
	_expect_string(
		SimulationSnapshotSignature.canonical_game_snapshot(
			first.create_game_snapshot()
		),
		SimulationSnapshotSignature.canonical_game_snapshot(
			second.create_game_snapshot()
		),
		"same evidence and inference sequence produces the same snapshot"
	)
	var mutable: CampaignSnapshot = first.create_game_snapshot().campaign
	mutable.collected_evidence_ids.clear()
	mutable.confirmed_inference_ids.clear()
	mutable.unlocked_facility_type_ids.clear()
	var isolated: CampaignSnapshot = first.create_game_snapshot().campaign
	_expect_true(
		isolated.has_evidence(CampaignState.EVIDENCE_FIRST_WORKER),
		"mutating campaign snapshot evidence cannot change authority"
	)
	_expect_true(
		isolated.has_confirmed_inference(
			CampaignState.INFERENCE_FIRST_WORKER
		),
		"mutating campaign snapshot inferences cannot change authority"
	)
	_expect_true(
		isolated.has_unlocked_facility(
			CampaignState.FACILITY_MICRO_FEEDING_PORT
		),
		"mutating campaign snapshot facilities cannot change authority"
	)


func _test_pending_inference_save_and_previous_schema_migration() -> void:
	var simulation: ColonySimulation = _new_simulation()
	var identity: GameSnapshot = _advance_until_phase(
		simulation,
		ScenarioSequenceSnapshot.Phase.IDENTITY_OBSERVATION
	)
	_expect_true(identity != null, "save fixture reaches inference boundary")
	if identity == null:
		return
	_expect_true(
		simulation.submit_campaign_inference_action(
			CampaignState.INFERENCE_FIRST_WORKER
		),
		"save fixture queues inference"
	)
	var service: SaveGameService = SaveGameService.new()
	var clock: SimulationClock = SimulationClock.new()
	clock.restore_save_boundary(
		identity.simulation_tick,
		SimulationClock.NORMAL_SPEED,
		true
	)
	var envelope: Dictionary = service.create_envelope(
		simulation,
		clock,
		"campaign_test",
		"2026-07-28T12:00:00Z"
	)
	var restored_result: Dictionary = service.load_envelope(envelope)
	_expect_true(
		restored_result.get("ok", false),
		"pending campaign inference survives save and load"
	)
	if restored_result.get("ok", false):
		var restored: ColonySimulation = restored_result["simulation"]
		_expect_true(
			restored.create_game_snapshot().campaign.inference_action_pending,
			"restored snapshot exposes the pending inference"
		)
		_expect_true(
			restored.advance_tick(identity.simulation_tick + 1),
			"restored inference applies once on the next Tick"
		)
		_expect_int(
			restored.create_game_snapshot().campaign.completed_chapter_count,
			1,
			"restored inference preserves its StringName argument"
		)

	var previous_simulation: ColonySimulation = _new_simulation()
	var previous_identity: GameSnapshot = _advance_until_phase(
		previous_simulation,
		ScenarioSequenceSnapshot.Phase.IDENTITY_OBSERVATION
	)
	_expect_true(
		previous_identity != null,
		"previous-schema fixture reaches its evidence boundary"
	)
	if previous_identity == null:
		return
	var previous_clock: SimulationClock = SimulationClock.new()
	previous_clock.restore_save_boundary(
		previous_identity.simulation_tick,
		SimulationClock.NORMAL_SPEED,
		true
	)
	var previous: Dictionary = service.create_envelope(
		previous_simulation,
		previous_clock,
		"campaign_previous_schema",
		"2026-07-28T12:01:00Z"
	)
	previous["state_schema_id"] = SimulationStateCodec.PREVIOUS_SCHEMA_ID
	previous["state_payload"].erase("campaign")
	previous["state_payload"].erase("nutrition")
	previous["state_payload"].erase("act1")
	for ant: Dictionary in previous["state_payload"]["ants"]:
		ant.erase("protein_supported_growth_ticks")
		ant.erase("feeding_task")
	var previous_habitat: Dictionary = (
		previous["frozen_config_bundle"]["habitat"]
	)
	previous_habitat.erase("lifecycle_active")
	previous_habitat.erase("nutrition_config")
	previous_habitat.erase("protein_placement_zone_id")
	previous_habitat.erase("protein_portions")
	previous_habitat.erase("founding_care_config")
	previous["frozen_config_hash"] = CanonicalSaveJson.sha256(
		previous["frozen_config_bundle"]
	)
	for command: Dictionary in previous["pending_commands"]:
		command.erase("argument_id")
	previous = service.seal_envelope(previous)
	var migration_result: Dictionary = service.load_envelope(previous)
	_expect_true(
		migration_result.get("ok", false),
		"r2.authority.v1 migrates through the explicit R4 schema step"
	)
	if migration_result.get("ok", false):
		_expect_true(
			migration_result.get("migrated", false),
			"previous schema reports migration"
		)
		_expect_int(
			migration_result["simulation"]
				.create_game_snapshot().campaign.chapter,
			CampaignState.Chapter.FOUNDING_OBSERVATION,
			"migration derives the compatible founding chapter"
		)


func _test_invalid_campaign_authority_is_rejected() -> void:
	var simulation: ColonySimulation = _new_simulation()
	var service: SaveGameService = SaveGameService.new()
	var envelope: Dictionary = service.create_envelope(
		simulation,
		_clock_at_tick(0),
		"campaign_invalid",
		"2026-07-28T12:02:00Z"
	)
	_expect_true(not envelope.is_empty(), "campaign corruption fixture saves")
	envelope["state_payload"]["campaign"][
		"unlocked_facility_type_ids"
	].append(String(CampaignState.FACILITY_SMALL_FORAGING_BOX))
	envelope = service.seal_envelope(envelope)
	_expect_true(
		not service.load_envelope(envelope).get("ok", false),
		"facility unlock without chapter completion is rejected"
	)


func _new_simulation() -> ColonySimulation:
	var simulation: ColonySimulation = ColonySimulation.new(
		SPECIES_A_DATA,
		COMBINED_SCENARIO_DATA
	)
	_expect_true(simulation.is_ready(), "campaign simulation is ready")
	return simulation


func _clock_at_tick(tick: int) -> SimulationClock:
	var clock: SimulationClock = SimulationClock.new()
	clock.restore_save_boundary(
		tick,
		SimulationClock.NORMAL_SPEED,
		true
	)
	return clock


func _advance_until_phase(
	simulation: ColonySimulation,
	target_phase: ScenarioSequenceSnapshot.Phase,
	maximum_ticks: int = 4000
) -> GameSnapshot:
	for step: int in maximum_ticks + 1:
		var snapshot: GameSnapshot = simulation.create_game_snapshot()
		if snapshot.sequence.phase == target_phase:
			return snapshot
		if not simulation.advance_tick(snapshot.simulation_tick + 1):
			return null
	return null


func _complete_observation_sequence(
	simulation: ColonySimulation
) -> GameSnapshot:
	for step: int in 5000:
		var snapshot: GameSnapshot = simulation.create_game_snapshot()
		if snapshot.sequence.completed:
			return snapshot
		if (
			snapshot.sequence.phase
				== ScenarioSequenceSnapshot.Phase.HUMIDITY_OBSERVATION
			and snapshot.colony.water_action_available
		):
			simulation.submit_water_action()
		elif (
			snapshot.sequence.phase
				== ScenarioSequenceSnapshot.Phase.SUGAR_FORAGING
			and snapshot.scenario.place_action_available
		):
			simulation.submit_place_sugar_action()
		if not simulation.advance_tick(snapshot.simulation_tick + 1):
			return null
	return null


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
