class_name Act1FinaleTestSuite
extends RefCounted

const FINAL_DISK_SAVE_PATH: String = (
	"user://r12_finale_tests/completed.json"
)

var _assertion_count: int = 0
var _failure_count: int = 0


func run() -> void:
	_test_finale_configuration_is_frozen()
	_test_finale_evidence_and_report_command_boundary()
	_test_unstable_layout_cannot_generate_report()
	_test_final_report_snapshot_is_isolated()
	_test_finale_save_round_trips()
	_test_r11_completion_enters_finale()
	_test_finale_speed_equivalence()
	_cleanup_save_path(FINAL_DISK_SAVE_PATH)


func get_assertion_count() -> int:
	return _assertion_count


func get_failure_count() -> int:
	return _failure_count


func _test_finale_configuration_is_frozen() -> void:
	var source: HabitatScenarioData = (
		Act1FinaleFixture.SCENARIO.duplicate(true)
	)
	source.act1_progression_data = (
		source.act1_progression_data.duplicate(true)
	)
	var original_ticks: int = (
		source.act1_progression_data.finale_stable_ticks
	)
	var original_card_id: StringName = (
		source.act1_progression_data.final_report_observation_card_id
	)
	var simulation := ColonySimulation.new(
		Act1FinaleFixture.SPECIES,
		source
	)
	if not _expect_ready(simulation, "finale frozen-config fixture"):
		return
	source.act1_progression_data.finale_stable_ticks = (
		original_ticks + 999
	)
	source.act1_progression_data.final_report_observation_card_id = (
		&"mutated_report"
	)
	_expect_int(
		simulation._habitat_config.act1_progression_config
			.finale_stable_ticks,
		original_ticks,
		"running simulation keeps the frozen finale window"
	)
	_expect_string(
		String(
			simulation._habitat_config.act1_progression_config
				.final_report_observation_card_id
		),
		String(original_card_id),
		"running simulation keeps the frozen report card ID"
	)


func _test_finale_evidence_and_report_command_boundary() -> void:
	var simulation: ColonySimulation = Act1FinaleFixture.create_simulation()
	if not _expect_ready(simulation, "finale report fixture"):
		return
	var required: int = (
		simulation._habitat_config.act1_progression_config
			.finale_stable_ticks
	)
	_expect_true(
		_advance_ticks(simulation, required + 1),
		"finale stable window advances"
	)
	var ready: GameSnapshot = simulation.create_game_snapshot()
	for evidence_id: StringName in [
		CampaignState.EVIDENCE_FIRST_WORKER_HISTORY,
		CampaignState.EVIDENCE_KEY_INTERVENTIONS,
		CampaignState.EVIDENCE_FINAL_LAYOUT_STABLE,
		CampaignState.EVIDENCE_LONG_TERM_PATTERN,
	]:
		_expect_true(
			ready.campaign.has_evidence(evidence_id),
			"finale records evidence %s" % evidence_id
		)
	_expect_int(
		ready.campaign.status,
		CampaignState.Status.AWAITING_INFERENCE,
		"four finale observations open the report conclusion"
	)
	_expect_true(
		not ready.act1.final_report_available,
		"stable evidence alone does not generate the report"
	)
	var before_tick: int = ready.simulation_tick
	_expect_true(
		simulation.submit_campaign_inference_action(
			CampaignState.INFERENCE_LAYOUT_SHAPES_BEHAVIOR
		),
		"correct finale conclusion enters the command queue"
	)
	var submitted: GameSnapshot = simulation.create_game_snapshot()
	_expect_true(
		submitted.campaign.inference_action_pending,
		"report conclusion is visibly pending"
	)
	_expect_true(
		not submitted.campaign.completed
			and not submitted.act1.final_report_available,
		"report command does not mutate the submission Tick"
	)
	_expect_true(
		simulation.advance_tick(before_tick + 1),
		"report command applies at the next fixed Tick"
	)
	var completed: GameSnapshot = simulation.create_game_snapshot()
	_expect_true(completed.campaign.completed, "final report completes Act I")
	_expect_int(
		completed.campaign.completed_chapter_count,
		6,
		"completed profile records all six chapters"
	)
	_expect_true(
		completed.act1.final_report_available,
		"completed profile exposes the copied final report state"
	)
	_expect_int(
		completed.act1.final_report_generated_tick,
		before_tick + 1,
		"report generation Tick matches command application"
	)
	_expect_true(
		completed.observations.unlocked_card_ids.has(
			&"glass_observation_report"
		),
		"final report unlocks one persistent observation card"
	)
	var report_event_found: bool = false
	for event: ObservationEvent in completed.observations.events:
		if event.event_type == ObservationEvent.Type.FINAL_REPORT_GENERATED:
			report_event_found = true
			_expect_int(
				event.subject_entity_id,
				completed.act1.first_worker_entity_id,
				"report event references the stable first-worker history"
			)
	_expect_true(report_event_found, "report generation emits a structured event")
	_expect_true(
		completed.nutrition.sugar_action_available
			and completed.nutrition.protein_action_available,
		"completed profile keeps environmental interventions available"
	)


func _test_unstable_layout_cannot_generate_report() -> void:
	var simulation: ColonySimulation = Act1FinaleFixture.create_simulation()
	if not _expect_ready(simulation, "unstable finale fixture"):
		return
	var state: ColonyState = simulation._state
	var dual: FacilityState
	for facility: FacilityState in (
		state.layout_state.get_facilities_in_stable_order()
	):
		if facility.type_id == CampaignState.FACILITY_DUAL_CHAMBER_NEST:
			dual = facility
			break
	if dual == null:
		_expect_true(false, "unstable fixture contains its final nest")
		return
	state.queen.assign_zone(&"test_tube_nest", state.simulation_tick)
	_expect_true(
		_advance_ticks(
			simulation,
			simulation._habitat_config.act1_progression_config
				.finale_stable_ticks + 5
		),
		"unstable finale still advances safely"
	)
	var snapshot: GameSnapshot = simulation.create_game_snapshot()
	_expect_true(
		not snapshot.campaign.has_evidence(
			CampaignState.EVIDENCE_FINAL_LAYOUT_STABLE
		)
			and not snapshot.campaign.has_evidence(
				CampaignState.EVIDENCE_LONG_TERM_PATTERN
			),
		"queen outside the final nest blocks layout and pattern evidence"
	)
	_expect_true(
		not snapshot.campaign.inference_action_available,
		"an incomplete final layout cannot submit the report conclusion"
	)


func _test_final_report_snapshot_is_isolated() -> void:
	var simulation: ColonySimulation = _completed_simulation()
	if not _expect_ready(simulation, "report snapshot fixture"):
		return
	var mutable: GameSnapshot = simulation.create_game_snapshot()
	mutable.act1.final_report_generated_tick = 999_999
	mutable.act1.final_report_available = false
	mutable.campaign.confirmed_inference_ids.clear()
	mutable.observations.unlocked_card_ids.clear()
	var fresh: GameSnapshot = simulation.create_game_snapshot()
	_expect_true(
		fresh.act1.final_report_available,
		"mutating report snapshot cannot clear authority"
	)
	_expect_true(
		fresh.act1.final_report_generated_tick != 999_999,
		"mutating report Tick cannot change authority"
	)
	_expect_true(
		fresh.campaign.has_confirmed_inference(
			CampaignState.INFERENCE_LAYOUT_SHAPES_BEHAVIOR
		)
			and fresh.observations.unlocked_card_ids.has(
				&"glass_observation_report"
			),
		"campaign and journal collections remain copied"
	)


func _test_finale_save_round_trips() -> void:
	var simulation: ColonySimulation = Act1FinaleFixture.create_simulation()
	if not _expect_ready(simulation, "finale save fixture"):
		return
	_expect_true(
		_advance_ticks(simulation, 7),
		"mid-finale save fixture advances"
	)
	var mid_result: Dictionary = _round_trip(simulation, "r12_mid")
	_expect_true(
		mid_result.get("ok", false),
		"mid-finale save restores: %s" % mid_result.get("error", "")
	)
	if mid_result.get("ok", false):
		var restored_mid: GameSnapshot = (
			mid_result["simulation"].create_game_snapshot()
		)
		_expect_int(
			restored_mid.act1.finale_stable_ticks,
			simulation.create_game_snapshot().act1.finale_stable_ticks,
			"mid-finale stability progress round-trips"
		)
		_expect_true(
			not restored_mid.act1.final_report_available,
			"mid-finale save does not invent a report"
		)

	var completed: ColonySimulation = _completed_simulation()
	var final_result: Dictionary = _round_trip(completed, "r12_final")
	_expect_true(
		final_result.get("ok", false),
		"completed report save restores: %s"
			% final_result.get("error", "")
	)
	if final_result.get("ok", false):
		var restored_final: GameSnapshot = (
			final_result["simulation"].create_game_snapshot()
		)
		_expect_true(
			restored_final.campaign.completed
				and restored_final.act1.final_report_available,
			"completed report authority survives save/load"
		)
	var final_clock := SimulationClock.new()
	_expect_true(
		final_clock.restore_save_boundary(
			completed._state.simulation_tick,
			SimulationClock.VERY_FAST_SPEED,
			true
		),
		"completed report disk clock restores"
	)
	var service := SaveGameService.new()
	var final_envelope: Dictionary = service.create_envelope(
		completed,
		final_clock,
		"r12_final_disk",
		"2026-07-29T10:30:00Z"
	)
	var disk_result: Dictionary = service.save_to_path(
		FINAL_DISK_SAVE_PATH,
		final_envelope
	)
	_expect_true(
		disk_result.get("ok", false),
		"completed report commits to disk: %s"
			% disk_result.get("error", "")
	)
	var disk_load_result: Dictionary = service.load_from_path(
		FINAL_DISK_SAVE_PATH
	)
	_expect_true(
		disk_load_result.get("ok", false),
		"completed report reloads from disk: %s"
			% disk_load_result.get("error", "")
	)
	if disk_load_result.get("ok", false):
		var disk_snapshot: GameSnapshot = (
			disk_load_result["simulation"].create_game_snapshot()
		)
		_expect_true(
			disk_snapshot.campaign.completed
				and disk_snapshot.act1.final_report_available,
			"completed report survives disk JSON precision"
		)
	_cleanup_save_path(FINAL_DISK_SAVE_PATH)


func _test_r11_completion_enters_finale() -> void:
	var completed: ColonySimulation = _completed_simulation()
	if not _expect_ready(completed, "R11 migration fixture"):
		return
	var clock := SimulationClock.new()
	clock.restore_save_boundary(
		completed._state.simulation_tick,
		SimulationClock.NORMAL_SPEED,
		false
	)
	var service := SaveGameService.new()
	var envelope: Dictionary = service.create_envelope(
		completed,
		clock,
		"r11_to_r12"
	)
	SaveFixtureDowngrade.strip_r12_fields(envelope)
	envelope["state_schema_id"] = SimulationStateCodec.R11_SCHEMA_ID
	envelope["game_version"] = "0.11.0-dev"
	envelope["frozen_config_hash"] = CanonicalSaveJson.sha256(
		envelope["frozen_config_bundle"]
	)
	envelope = service.seal_envelope(envelope)
	var result: Dictionary = service.load_envelope(envelope)
	_expect_true(
		result.get("ok", false),
		"R11 completion migrates into R12: %s"
			% result.get("error", "")
	)
	if not result.get("ok", false):
		return
	_expect_true(result.get("migrated", false), "R11 migration is explicit")
	var simulation: ColonySimulation = result["simulation"]
	var snapshot: GameSnapshot = simulation.create_game_snapshot()
	_expect_int(
		snapshot.campaign.chapter,
		CampaignState.Chapter.ACT1_STABLE_COLONY_SUMMARY,
		"old five-chapter completion resumes at Chapter 6"
	)
	_expect_int(
		snapshot.campaign.completed_chapter_count,
		5,
		"migration preserves five completed chapters"
	)
	_expect_true(
		not snapshot.campaign.completed
			and not snapshot.act1.final_report_available,
		"migration does not fabricate the final report"
	)
	_expect_int(
		simulation._habitat_config.act1_progression_config
			.finale_stable_ticks,
		40,
		"migration freezes the R12 finale window"
	)


func _test_finale_speed_equivalence() -> void:
	var signatures: PackedStringArray = []
	for speed: int in [
		SimulationClock.NORMAL_SPEED,
		SimulationClock.FAST_SPEED,
		SimulationClock.VERY_FAST_SPEED,
	]:
		var simulation: ColonySimulation = Act1FinaleFixture.create_simulation()
		if not _expect_ready(simulation, "speed %d finale fixture" % speed):
			return
		var clock := SimulationClock.new()
		clock.restore_save_boundary(
			simulation._state.simulation_tick,
			speed,
			false
		)
		clock.tick_requested.connect(
			func(tick_index: int, _tick_seconds: float) -> void:
				simulation.advance_tick(tick_index)
		)
		var target_tick: int = (
			simulation._state.simulation_tick
			+ simulation._habitat_config.act1_progression_config
				.finale_stable_ticks + 1
		)
		while clock.get_tick_index() < target_tick:
			clock.advance(
				SimulationClock.FIXED_STEP_SECONDS / float(speed)
			)
		signatures.append(
			SimulationSnapshotSignature.canonical_game_snapshot(
				simulation.create_game_snapshot()
			)
		)
	_expect_string(
		signatures[1],
		signatures[0],
		"4x reaches the same finale snapshot at the same Tick"
	)
	_expect_string(
		signatures[2],
		signatures[0],
		"16x reaches the same finale snapshot at the same Tick"
	)


func _completed_simulation() -> ColonySimulation:
	var simulation: ColonySimulation = Act1FinaleFixture.create_simulation()
	if not simulation.is_ready():
		return simulation
	var required: int = (
		simulation._habitat_config.act1_progression_config
			.finale_stable_ticks
	)
	if not _advance_ticks(simulation, required + 1):
		return simulation
	if not simulation.submit_campaign_inference_action(
		CampaignState.INFERENCE_LAYOUT_SHAPES_BEHAVIOR
	):
		return simulation
	simulation.advance_tick(simulation._state.simulation_tick + 1)
	return simulation


func _round_trip(
	simulation: ColonySimulation,
	slot_id: String
) -> Dictionary:
	var clock := SimulationClock.new()
	clock.restore_save_boundary(
		simulation._state.simulation_tick,
		SimulationClock.NORMAL_SPEED,
		false
	)
	var service := SaveGameService.new()
	return service.load_envelope(
		service.create_envelope(simulation, clock, slot_id)
	)


func _advance_ticks(simulation: ColonySimulation, count: int) -> bool:
	for unused_tick: int in count:
		if not simulation.advance_tick(simulation._state.simulation_tick + 1):
			return false
	return true


func _cleanup_save_path(path: String) -> void:
	var absolute_path: String = ProjectSettings.globalize_path(path)
	for candidate: String in [
		absolute_path,
		absolute_path + ".bak",
		absolute_path + ".tmp",
	]:
		if FileAccess.file_exists(candidate):
			DirAccess.remove_absolute(candidate)


func _expect_ready(
	simulation: ColonySimulation,
	label: String
) -> bool:
	var ready: bool = simulation != null and simulation.is_ready()
	_expect_true(
		ready,
		"%s initializes: %s"
			% [
				label,
				(
					simulation.get_configuration_error()
					if simulation != null
					else "missing simulation"
				),
			]
	)
	return ready


func _expect_true(actual: bool, label: String) -> void:
	_assertion_count += 1
	if actual:
		return
	_failure_count += 1
	printerr("  %s - expected true, got false" % label)


func _expect_int(actual: int, expected: int, label: String) -> void:
	_assertion_count += 1
	if actual == expected:
		return
	_failure_count += 1
	printerr("  %s - expected %d, got %d" % [label, expected, actual])


func _expect_string(actual: String, expected: String, label: String) -> void:
	_assertion_count += 1
	if actual == expected:
		return
	_failure_count += 1
	printerr("  %s - expected %s, got %s" % [label, expected, actual])
