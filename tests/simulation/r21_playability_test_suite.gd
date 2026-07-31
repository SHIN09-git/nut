class_name R21PlayabilityTestSuite
extends RefCounted

const SPECIES: SpeciesData = preload("res://data/species/species_a.tres")
const SCENARIO: HabitatScenarioData = preload(
	"res://data/habitats/act1_test_tube.tres"
)

var _assertion_count: int = 0
var _failure_count: int = 0


func run() -> void:
	_test_experiment_prediction_boundary()
	_test_placement_choices_use_frozen_config_and_next_tick()
	_test_near_placement_disturbs_care_but_far_placement_does_not()
	_test_choice_snapshot_is_isolated()


func get_assertion_count() -> int:
	return _assertion_count


func get_failure_count() -> int:
	return _failure_count


func _test_experiment_prediction_boundary() -> void:
	var simulation: ColonySimulation = _new_simulation()
	var opening: GameSnapshot = simulation.create_game_snapshot()
	var experiment: Act1ExperimentState = Act1ExperimentState.new()
	_expect_true(
		experiment.should_gate_intervention(
			CampaignState.Chapter.ACT1_FOUNDING,
			opening
		),
		"R21 gates the first intervention until a prediction is recorded"
	)
	_expect_true(
		experiment.record_prediction(
			CampaignState.Chapter.ACT1_FOUNDING,
			Act1ExperimentState.PREDICTION_CARE_INCREASES,
			opening
		),
		"R21 accepts a valid prediction before intervention"
	)
	_expect_true(
		not experiment.record_prediction(
			CampaignState.Chapter.ACT1_FOUNDING,
			Act1ExperimentState.PREDICTION_NO_VISIBLE_CHANGE,
			opening
		),
		"R21 keeps one immutable pre-intervention prediction per chapter"
	)
	_expect_int(
		experiment.get_baseline_care_count(
			CampaignState.Chapter.ACT1_FOUNDING
		),
		opening.act1.queen_care.completed_care_count,
		"R21 records the comparison baseline from a snapshot"
	)
	simulation.submit_apply_light_cover_action()
	var progressed_without_annotation: Act1ExperimentState = (
		Act1ExperimentState.new()
	)
	_expect_true(
		not progressed_without_annotation.should_gate_intervention(
			CampaignState.Chapter.ACT1_FOUNDING,
			simulation.create_game_snapshot()
		),
		"loading a progressed save does not regress behind session annotations"
	)


func _test_placement_choices_use_frozen_config_and_next_tick() -> void:
	var source: HabitatScenarioData = SCENARIO.duplicate(
		true
	) as HabitatScenarioData
	var simulation: ColonySimulation = ColonySimulation.new(SPECIES, source)
	var ready: GameSnapshot = _prepare_chapter_two(simulation)
	_expect_true(ready != null, "R21 reaches the first-worker intervention")
	if ready == null:
		return
	_expect_true(
		ready.scenario.available_placement_choice_ids.has(
			HabitatScenarioConfig.SUGAR_PLACEMENT_FEEDING_PORT
		)
			and ready.scenario.available_placement_choice_ids.has(
				HabitatScenarioConfig.SUGAR_PLACEMENT_NEAR_NEST
			),
		"R21 snapshot exposes exactly the configured high-level choices"
	)
	_expect_true(
		not simulation.submit_place_sugar_action(&"arbitrary_zone"),
		"R21 rejects UI-provided arbitrary placement IDs"
	)
	source.sugar_placement_zone_id = &"mutated_after_start"
	source.zones[1].zone_id = &"mutated_passage"
	_force_active_care(simulation)
	var before: GameSnapshot = simulation.create_game_snapshot()
	_expect_true(
		simulation.submit_place_sugar_action(
			HabitatScenarioConfig.SUGAR_PLACEMENT_NEAR_NEST
		),
		"R21 accepts the near-nest high-level choice"
	)
	var pending: GameSnapshot = simulation.create_game_snapshot()
	_expect_int(
		pending.nutrition.total_sugar_portions_supplied,
		before.nutrition.total_sugar_portions_supplied,
		"R21 placement submission does not mutate the same Tick"
	)
	_expect_true(
		pending.scenario.selected_placement_choice_id
			== HabitatScenarioConfig.SUGAR_PLACEMENT_NEAR_NEST,
		"R21 pending snapshot retains the selected choice"
	)
	var clock: SimulationClock = SimulationClock.new()
	clock.restore_save_boundary(
		pending.simulation_tick,
		SimulationClock.NORMAL_SPEED,
		true
	)
	var envelope: Dictionary = SaveGameService.new().create_envelope(
		simulation,
		clock,
		"r21-pending",
		"2026-07-31T00:00:00Z"
	)
	var loaded: Dictionary = SaveGameService.new().load_envelope(envelope)
	_expect_true(
		loaded.get("ok", false),
		"R21 pending placement choice survives strict save reconstruction"
	)
	_expect_true(
		simulation.advance_tick(before.simulation_tick + 1),
		"R21 placement applies on the next contiguous Tick"
	)
	var applied: GameSnapshot = simulation.create_game_snapshot()
	var source_snapshot: FoodSourceSnapshot = _find_sugar_source(applied)
	_expect_true(
		source_snapshot != null
			and source_snapshot.zone_id == &"tube_passage",
		"R21 resolves near-nest through the frozen habitat topology"
	)
	_expect_true(
		_has_event(
			applied,
			ObservationEvent.Type.FEEDING_DISTURBANCE_OCCURRED
		),
		"R21 records the configured near-nest disturbance"
	)


func _test_near_placement_disturbs_care_but_far_placement_does_not() -> void:
	var near_simulation: ColonySimulation = _new_simulation()
	var far_simulation: ColonySimulation = _new_simulation()
	var near_ready: GameSnapshot = _prepare_chapter_two(near_simulation)
	var far_ready: GameSnapshot = _prepare_chapter_two(far_simulation)
	_expect_true(
		near_ready != null and far_ready != null,
		"R21 trade-off fixtures reach the same chapter boundary"
	)
	if near_ready == null or far_ready == null:
		return
	_force_active_care(near_simulation)
	_force_active_care(far_simulation)
	var near_tick: int = near_simulation.create_game_snapshot().simulation_tick
	var far_tick: int = far_simulation.create_game_snapshot().simulation_tick
	near_simulation.submit_place_sugar_action(
		HabitatScenarioConfig.SUGAR_PLACEMENT_NEAR_NEST
	)
	far_simulation.submit_place_sugar_action(
		HabitatScenarioConfig.SUGAR_PLACEMENT_FEEDING_PORT
	)
	_expect_true(
		near_simulation.advance_tick(near_tick + 1)
			and far_simulation.advance_tick(far_tick + 1),
		"R21 trade-off choices advance deterministically"
	)
	var near: GameSnapshot = near_simulation.create_game_snapshot()
	var far: GameSnapshot = far_simulation.create_game_snapshot()
	_expect_int(
		near.act1.queen_care.care_state,
		Act1State.QueenCareState.RESTING,
		"near-nest placement resets the active care state"
	)
	_expect_int(
		near.act1.queen_care.elapsed_ticks,
		1,
		"near-nest care restarts from the next simulation step"
	)
	_expect_int(
		far.act1.queen_care.care_state,
		Act1State.QueenCareState.GATHERING,
		"far placement leaves the active care state intact"
	)
	_expect_int(
		far.act1.queen_care.elapsed_ticks,
		8,
		"far placement advances the existing care cycle normally"
	)
	var far_source: FoodSourceSnapshot = _find_sugar_source(far)
	_expect_true(
		far_source != null
			and far_source.zone_id == &"micro_feeding_port",
		"far choice uses the frozen feeding-port location"
	)
	_expect_true(
		not _has_event(
			far,
			ObservationEvent.Type.FEEDING_DISTURBANCE_OCCURRED
		),
		"far placement does not invent a disturbance"
	)


func _test_choice_snapshot_is_isolated() -> void:
	var simulation: ColonySimulation = _new_simulation()
	var ready: GameSnapshot = _prepare_chapter_two(simulation)
	_expect_true(ready != null, "R21 snapshot fixture reaches Chapter 2")
	if ready == null:
		return
	ready.scenario.available_placement_choice_ids.clear()
	ready.scenario.selected_placement_choice_id = &"forged"
	var fresh: GameSnapshot = simulation.create_game_snapshot()
	_expect_int(
		fresh.scenario.available_placement_choice_ids.size(),
		2,
		"mutating placement choices cannot change simulation output"
	)
	_expect_true(
		fresh.scenario.selected_placement_choice_id.is_empty(),
		"mutating selected placement cannot write back into authority"
	)


func _prepare_chapter_two(
	simulation: ColonySimulation
) -> GameSnapshot:
	if (
		simulation == null
		or not simulation.is_ready()
		or not simulation.submit_apply_light_cover_action()
		or not simulation.advance_tick(1)
	):
		return null
	var founding_ready: GameSnapshot = _advance_until(
		simulation,
		func(snapshot: GameSnapshot) -> bool:
			return (
				snapshot.campaign.status
				== CampaignState.Status.AWAITING_INFERENCE
			),
		300
	)
	if (
		founding_ready == null
		or not simulation.submit_campaign_inference_action(
			CampaignState.INFERENCE_QUEEN_CARE
		)
		or not simulation.advance_tick(founding_ready.simulation_tick + 1)
	):
		return null
	return _advance_until(
		simulation,
		func(snapshot: GameSnapshot) -> bool:
			return (
				snapshot.campaign.chapter
					== CampaignState.Chapter.ACT1_FIRST_WORKERS
				and snapshot.act1.first_worker_emerged_tick >= 0
				and snapshot.nutrition.sugar_action_available
			),
		SPECIES.pupa_duration_ticks + 100
	)


func _force_active_care(simulation: ColonySimulation) -> void:
	var target_id: int = -1
	for ant: AntModel in simulation._state.ants:
		if ant.life_stage != AntModel.LifeStage.WORKER:
			target_id = ant.entity_id
			break
	simulation._state.act1_state.queen_care_state = (
		Act1State.QueenCareState.GATHERING
	)
	simulation._state.act1_state.queen_care_elapsed_ticks = 7
	simulation._state.act1_state.queen_care_target_brood_id = target_id


func _find_sugar_source(snapshot: GameSnapshot) -> FoodSourceSnapshot:
	for source: FoodSourceSnapshot in snapshot.colony.food_sources:
		if source.food_type == FoodSourceState.FoodType.SUGAR_WATER:
			return source
	return null


func _has_event(
	snapshot: GameSnapshot,
	event_type: ObservationEvent.Type
) -> bool:
	for event: ObservationEvent in snapshot.observations.events:
		if event.event_type == event_type:
			return true
	return false


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


func _new_simulation() -> ColonySimulation:
	return ColonySimulation.new(SPECIES, SCENARIO)


func _expect_true(actual: bool, message: String) -> void:
	_assertion_count += 1
	if actual:
		return
	_failure_count += 1
	printerr("  %s - expected true, got false" % message)


func _expect_int(actual: int, expected: int, message: String) -> void:
	_assertion_count += 1
	if actual == expected:
		return
	_failure_count += 1
	printerr(
		"  %s - expected %d, got %d" % [message, expected, actual]
	)
