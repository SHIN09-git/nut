class_name Act1TestTubeTestSuite
extends RefCounted

const SPECIES: SpeciesData = preload("res://data/species/species_a.tres")
const SCENARIO: HabitatScenarioData = preload(
	"res://data/habitats/act1_test_tube.tres"
)

var _assertion_count: int = 0
var _failure_count: int = 0


func run() -> void:
	_test_frozen_opening_and_cover_command_boundary()
	_test_source_resource_mutation_does_not_change_session()
	_test_act1_snapshot_isolated_from_authority()
	_test_two_chapter_authoritative_path()
	_test_same_commands_are_deterministic()
	_test_clock_speeds_preserve_same_tick_result()
	_test_save_round_trip_preserves_act1_authority()
	_test_long_soak_preserves_ownership()


func get_assertion_count() -> int:
	return _assertion_count


func get_failure_count() -> int:
	return _failure_count


func _test_frozen_opening_and_cover_command_boundary() -> void:
	var simulation: ColonySimulation = _new_simulation()
	_expect_true(simulation.is_ready(), "Act 1 frozen scenario is valid")
	var opening: GameSnapshot = simulation.create_game_snapshot()
	_expect_true(opening != null, "Act 1 exposes a game snapshot")
	_expect_string_name(
		opening.colony.scenario_id,
		&"act1_test_tube",
		"Act 1 uses a stable scenario ID"
	)
	_expect_true(
		opening.act1 != null and opening.act1.active,
		"Act 1 snapshot exposes founding authority"
	)
	_expect_true(
		opening.act1.queen_care.light_cover_action_available,
		"light cover is initially available"
	)
	_expect_int(
		opening.colony.queen_laid_egg_count,
		SCENARIO.initial_brood_count + 1,
		"seeded founding brood use coherent queen lifecycle semantics"
	)
	_expect_int(
		opening.colony.ants.size(),
		SCENARIO.initial_brood_count + 1,
		"opening contains one pupa plus configured eggs"
	)
	_expect_true(
		simulation.submit_apply_light_cover_action(),
		"cover action crosses the high-level command boundary"
	)
	var submitted: GameSnapshot = simulation.create_game_snapshot()
	_expect_true(
		submitted.act1.queen_care.light_cover_action_pending,
		"submitted cover action is visible as pending"
	)
	_expect_true(
		not submitted.act1.queen_care.light_cover_applied,
		"cover does not mutate authority on submission"
	)
	_expect_true(
		simulation.advance_tick(1),
		"next contiguous Tick accepts the cover command"
	)
	var applied: GameSnapshot = simulation.create_game_snapshot()
	_expect_true(
		applied.act1.queen_care.light_cover_applied,
		"cover applies at the next Tick start"
	)
	_expect_true(
		not applied.act1.queen_care.light_cover_action_available,
		"one-time cover action closes after application"
	)


func _test_source_resource_mutation_does_not_change_session() -> void:
	var source: HabitatScenarioData = SCENARIO.duplicate(
		true
	) as HabitatScenarioData
	source.founding_care_data = SCENARIO.founding_care_data.duplicate(
		true
	) as FoundingCareData
	source.nutrition_data = SCENARIO.nutrition_data.duplicate(
		true
	) as NutritionData
	var frozen: ColonySimulation = ColonySimulation.new(SPECIES, source)
	var baseline: ColonySimulation = _new_simulation()
	_expect_true(
		frozen.is_ready() and baseline.is_ready(),
		"resource-freeze fixtures initialize before source mutation"
	)

	source.founding_care_data.rest_duration_ticks += 5000
	source.founding_care_data.queen_care_observation_card_id = (
		&"mutated_after_start"
	)
	source.founding_care_data.first_worker_initial_pupa_age_ticks = 1
	source.nutrition_data.initial_protein_reserve_portions = 0
	source.sugar_portions = 7
	_expect_true(
		frozen.submit_apply_light_cover_action()
			and baseline.submit_apply_light_cover_action(),
		"frozen fixtures accept the same cover command"
	)
	_expect_true(
		_advance_to_tick(frozen, 200)
			and _advance_to_tick(baseline, 200),
		"frozen fixtures advance after source mutation"
	)
	_expect_string(
		_signature(frozen.create_game_snapshot()),
		_signature(baseline.create_game_snapshot()),
		"running Act 1 uses copied care, lifecycle and nutrition values"
	)


func _test_act1_snapshot_isolated_from_authority() -> void:
	var simulation: ColonySimulation = _new_simulation()
	var editable: GameSnapshot = simulation.create_game_snapshot()
	editable.act1.active = false
	editable.act1.queen_care.light_cover_applied = true
	editable.act1.queen_care.completed_care_count = 999
	editable.campaign.collected_evidence_ids.append(&"forged_evidence")
	editable.nutrition.protein_reserve_portions = 999
	var fresh: GameSnapshot = simulation.create_game_snapshot()
	_expect_true(
		fresh.act1.active
			and not fresh.act1.queen_care.light_cover_applied,
		"mutating Act 1 snapshot flags cannot change authority"
	)
	_expect_int(
		fresh.act1.queen_care.completed_care_count,
		0,
		"mutating the care snapshot cannot change authority"
	)
	_expect_true(
		not fresh.campaign.collected_evidence_ids.has(&"forged_evidence"),
		"mutating campaign evidence cannot change authority"
	)
	_expect_int(
		fresh.nutrition.protein_reserve_portions,
		SCENARIO.nutrition_data.initial_protein_reserve_portions,
		"mutating nutrition snapshot cannot change authority"
	)


func _test_two_chapter_authoritative_path() -> void:
	var simulation: ColonySimulation = _new_simulation()
	_expect_true(
		simulation.submit_apply_light_cover_action(),
		"full path submits the cover action"
	)
	_expect_true(_advance_to_tick(simulation, 1), "cover Tick advances")
	var founding_ready: GameSnapshot = _advance_until(
		simulation,
		func(snapshot: GameSnapshot) -> bool:
			return (
				snapshot.campaign.status
				== CampaignState.Status.AWAITING_INFERENCE
			),
		250
	)
	_expect_true(
		founding_ready != null,
		"queen care and stable pupa open the founding inference"
	)
	if founding_ready == null:
		return
	_expect_true(
		founding_ready.campaign.has_evidence(
			CampaignState.EVIDENCE_QUEEN_CARE
		),
		"queen care becomes chapter evidence"
	)
	_expect_true(
		founding_ready.campaign.has_evidence(
			CampaignState.EVIDENCE_FIRST_PUPA
		),
		"stable pupa becomes chapter evidence"
	)
	_expect_true(
		simulation.submit_campaign_inference_action(
			CampaignState.INFERENCE_QUEEN_CARE
		),
		"founding inference uses a queued authority command"
	)
	var inference_tick: int = founding_ready.simulation_tick + 1
	_expect_true(
		simulation.advance_tick(inference_tick),
		"founding inference applies on the next Tick"
	)
	var chapter_two: GameSnapshot = simulation.create_game_snapshot()
	_expect_int(
		chapter_two.campaign.chapter,
		CampaignState.Chapter.ACT1_FIRST_WORKERS,
		"correct founding inference enters the first-worker chapter"
	)
	_expect_true(
		chapter_two.campaign.has_unlocked_facility(
			CampaignState.FACILITY_MICRO_FEEDING_PORT
		),
		"founding conclusion unlocks the micro feeding port"
	)

	var worker_ready: GameSnapshot = _advance_until(
		simulation,
		func(snapshot: GameSnapshot) -> bool:
			return (
				snapshot.act1.first_worker_emerged_tick >= 0
				and snapshot.nutrition.sugar_action_available
			),
		SPECIES.pupa_duration_ticks + 20
	)
	_expect_true(
		worker_ready != null,
		"first worker emerges and makes the sugar tool available"
	)
	if worker_ready == null:
		return
	_expect_true(
		simulation.submit_place_sugar_action(),
		"sugar is placed through the configured high-level action"
	)
	var sugar_submission_tick: int = worker_ready.simulation_tick
	var pending: GameSnapshot = simulation.create_game_snapshot()
	_expect_true(
		pending.nutrition.sugar_action_pending,
		"sugar placement is pending before the next Tick"
	)
	_expect_int(
		pending.nutrition.total_sugar_portions_supplied,
		0,
		"sugar supply is unchanged at submission"
	)
	_expect_true(
		simulation.advance_tick(sugar_submission_tick + 1),
		"sugar placement Tick advances"
	)
	var placed: GameSnapshot = simulation.create_game_snapshot()
	_expect_int(
		placed.nutrition.total_sugar_portions_supplied,
		SCENARIO.sugar_portions,
		"next Tick applies the frozen sugar portion count"
	)

	var completion_ready: GameSnapshot = _advance_until(
		simulation,
		func(snapshot: GameSnapshot) -> bool:
			return (
				snapshot.campaign.status
				== CampaignState.Status.AWAITING_INFERENCE
				and snapshot.campaign.chapter
					== CampaignState.Chapter.ACT1_FIRST_WORKERS
			),
		1600
	)
	_expect_true(
		completion_ready != null,
		"worker care and nutrient exchange open the final inference"
	)
	if completion_ready == null:
		return
	for evidence_id: StringName in [
		CampaignState.EVIDENCE_FIRST_WORKER,
		CampaignState.EVIDENCE_FIRST_WORKER_CARE,
		CampaignState.EVIDENCE_FIRST_NUTRIENT_EXCHANGE,
	]:
		_expect_true(
			completion_ready.campaign.has_evidence(evidence_id),
			"first-worker chapter records evidence %s"
				% String(evidence_id)
		)
	_expect_true(
		simulation.submit_campaign_inference_action(
			CampaignState.INFERENCE_WORKER_NUTRITION
		),
		"final inference uses the command queue"
	)
	_expect_true(
		simulation.advance_tick(completion_ready.simulation_tick + 1),
		"final inference applies on the next Tick"
	)
	var expanded: GameSnapshot = simulation.create_game_snapshot()
	_expect_true(
		not expanded.campaign.completed,
		"two authoritative chapters continue into the foraging chapter"
	)
	_expect_int(
		expanded.campaign.chapter,
		CampaignState.Chapter.ACT1_FORAGING_EXPANSION,
		"Chapter 2 conclusion enters the small-foraging chapter"
	)
	_expect_true(
		expanded.campaign.has_unlocked_facility(
			CampaignState.FACILITY_SMALL_FORAGING_BOX
		),
		"Chapter 2 conclusion unlocks the foraging box"
	)
	_expect_true(
		expanded.campaign.has_unlocked_facility(
			CampaignState.FACILITY_PROTEIN_DISH
		),
		"Chapter 2 conclusion unlocks the protein toolset"
	)


func _test_same_commands_are_deterministic() -> void:
	var first: ColonySimulation = _new_simulation()
	var second: ColonySimulation = _new_simulation()
	_expect_true(
		first.submit_apply_light_cover_action()
			and second.submit_apply_light_cover_action(),
		"determinism fixture submits identical cover commands"
	)
	for tick_index: int in range(1, 1001):
		if tick_index == 100:
			var first_snapshot: GameSnapshot = first.create_game_snapshot()
			var second_snapshot: GameSnapshot = second.create_game_snapshot()
			if first_snapshot.campaign.inference_action_available:
				first.submit_campaign_inference_action(
					CampaignState.INFERENCE_QUEEN_CARE
				)
				second.submit_campaign_inference_action(
					CampaignState.INFERENCE_QUEEN_CARE
				)
		if tick_index == 310:
			if first.create_game_snapshot().nutrition.sugar_action_available:
				first.submit_place_sugar_action()
				second.submit_place_sugar_action()
		_expect_true(
			first.advance_tick(tick_index)
				and second.advance_tick(tick_index),
			"determinism fixture advances Tick %d" % tick_index
		)
	_expect_string(
		_signature(first.create_game_snapshot()),
		_signature(second.create_game_snapshot()),
		"same initial state and command sequence produce one snapshot"
	)


func _test_clock_speeds_preserve_same_tick_result() -> void:
	var signatures: Array[String] = []
	for speed: int in [
		SimulationClock.NORMAL_SPEED,
		SimulationClock.FAST_SPEED,
		SimulationClock.VERY_FAST_SPEED,
	]:
		var simulation: ColonySimulation = _new_simulation()
		var clock: SimulationClock = SimulationClock.new()
		var accepted: Array[bool] = [true]
		clock.tick_requested.connect(
			func(tick_index: int, _tick_seconds: float) -> void:
				accepted[0] = (
					accepted[0]
					and simulation.advance_tick(tick_index)
				)
		)
		_expect_true(
			simulation.submit_apply_light_cover_action()
				and clock.set_speed_multiplier(speed),
			"speed fixture accepts cover and %dx" % speed
		)
		while clock.get_tick_index() < 160:
			clock.advance(SimulationClock.FIXED_STEP_SECONDS)
		_expect_true(
			accepted[0] and clock.get_tick_index() == 160,
			"%dx reaches the exact comparison Tick" % speed
		)
		signatures.append(_signature(simulation.create_game_snapshot()))
	_expect_string(
		signatures[1],
		signatures[0],
		"4x matches 1x at the same authoritative Tick"
	)
	_expect_string(
		signatures[2],
		signatures[0],
		"16x matches 1x at the same authoritative Tick"
	)


func _test_save_round_trip_preserves_act1_authority() -> void:
	var simulation: ColonySimulation = _new_simulation()
	simulation.submit_apply_light_cover_action()
	_expect_true(_advance_to_tick(simulation, 175), "save fixture advances")
	var clock: SimulationClock = SimulationClock.new()
	_expect_true(
		clock.restore_save_boundary(175, SimulationClock.FAST_SPEED, true),
		"save fixture restores a matching clock boundary"
	)
	var service: SaveGameService = SaveGameService.new()
	var envelope: Dictionary = service.create_envelope(
		simulation,
		clock,
		"act1-test",
		"2026-07-28T00:00:00Z"
	)
	_expect_true(not envelope.is_empty(), "Act 1 creates a v4 envelope")
	_expect_string(
		String(envelope.get("state_schema_id", "")),
		SimulationStateCodec.CURRENT_SCHEMA_ID,
		"Act 1 save uses the current authority schema"
	)
	var load_result: Dictionary = service.load_envelope(envelope)
	_expect_true(
		load_result.get("ok", false),
		"Act 1 envelope restores through strict validation (%s)"
			% String(load_result.get("error", "no error"))
	)
	if not load_result.get("ok", false):
		return
	_expect_string(
		_signature(
			(load_result["simulation"] as ColonySimulation)
				.create_game_snapshot()
		),
		_signature(simulation.create_game_snapshot()),
		"Act 1 save/load preserves the authoritative snapshot"
	)


func _test_long_soak_preserves_ownership() -> void:
	var simulation: ColonySimulation = _new_simulation()
	simulation.submit_apply_light_cover_action()
	for tick_index: int in range(1, 10_001):
		_expect_true(
			simulation.advance_tick(tick_index),
			"Act 1 soak advances Tick %d" % tick_index
		)
	_expect_true(
		simulation.has_valid_habitat_ownership(),
		"10,000-Tick Act 1 soak preserves ownership"
	)
	var snapshot: GameSnapshot = simulation.create_game_snapshot()
	for zone: HabitatZoneSnapshot in snapshot.colony.zones:
		_expect_true(
			is_finite(zone.humidity),
			"Act 1 soak keeps zone humidity finite"
		)


func _new_simulation() -> ColonySimulation:
	return ColonySimulation.new(SPECIES, SCENARIO)


func _advance_to_tick(
	simulation: ColonySimulation,
	target_tick: int
) -> bool:
	var current_tick: int = simulation.create_snapshot().simulation_tick
	for tick_index: int in range(current_tick + 1, target_tick + 1):
		if not simulation.advance_tick(tick_index):
			return false
	return true


func _advance_until(
	simulation: ColonySimulation,
	predicate: Callable,
	maximum_additional_ticks: int
) -> GameSnapshot:
	var snapshot: GameSnapshot = simulation.create_game_snapshot()
	if predicate.call(snapshot):
		return snapshot
	for unused_tick: int in maximum_additional_ticks:
		if not simulation.advance_tick(snapshot.simulation_tick + 1):
			return null
		snapshot = simulation.create_game_snapshot()
		if predicate.call(snapshot):
			return snapshot
	return null


func _signature(snapshot: GameSnapshot) -> String:
	var values: Array[String] = [
		str(snapshot.simulation_tick),
		str(snapshot.campaign.chapter),
		str(snapshot.campaign.status),
		str(snapshot.campaign.collected_evidence_ids),
		str(snapshot.campaign.confirmed_inference_ids),
		str(snapshot.campaign.unlocked_facility_type_ids),
		str(snapshot.act1.queen_care.light_cover_applied),
		str(snapshot.act1.queen_care.care_state),
		str(snapshot.act1.queen_care.elapsed_ticks),
		str(snapshot.act1.queen_care.target_brood_id),
		str(snapshot.act1.queen_care.completed_care_count),
		str(snapshot.act1.first_worker_emerged_tick),
		str(snapshot.nutrition.sugar_reserve_portions),
		str(snapshot.nutrition.protein_reserve_portions),
		str(snapshot.nutrition.completed_feeding_count),
	]
	for ant: AntSnapshot in snapshot.colony.ants:
		values.append(
			"%d:%d:%d:%s:%d:%d"
			% [
				ant.entity_id,
				ant.life_stage,
				ant.stage_age_ticks,
				String(ant.zone_id),
				ant.foraging_task.state
					if ant.foraging_task != null else -1,
				ant.feeding_task.state
					if ant.feeding_task != null else -1,
			]
		)
	return "|".join(values)


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


func _expect_string(
	actual: String,
	expected: String,
	message: String
) -> void:
	_assertion_count += 1
	if actual == expected:
		return
	_record_failure(message, expected, actual)


func _expect_string_name(
	actual: StringName,
	expected: StringName,
	message: String
) -> void:
	_expect_string(String(actual), String(expected), message)


func _record_failure(
	message: String,
	expected: String,
	actual: String
) -> void:
	_failure_count += 1
	printerr("  %s - expected %s, got %s" % [message, expected, actual])
