class_name NutritionGrowthTestSuite
extends RefCounted

const SPECIES_A_DATA: SpeciesData = preload(
	"res://data/species/species_a.tres"
)
const NUTRITION_SCENARIO_DATA: HabitatScenarioData = preload(
	"res://data/habitats/colony_growth_nutrition.tres"
)
const NEST_ZONE_ID: StringName = &"nursery_chamber"
const FORAGING_ZONE_ID: StringName = &"foraging_area"
const SOAK_TICK_COUNT: int = 10_000

var _assertion_count: int = 0
var _failure_count: int = 0


func run() -> void:
	_test_frozen_configuration_and_command_boundaries()
	_test_protein_shortage_stalls_and_feeding_restores_growth()
	_test_sugar_shortage_slows_but_does_not_deadlock_activity()
	_test_deterministic_snapshots_and_snapshot_isolation()
	_test_speed_multipliers_match_at_the_same_tick()
	_test_save_round_trip_preserves_pending_and_active_work()
	_test_ten_thousand_tick_conservation_soak()


func get_assertion_count() -> int:
	return _assertion_count


func get_failure_count() -> int:
	return _failure_count


func _test_frozen_configuration_and_command_boundaries() -> void:
	var scenario: HabitatScenarioData = _duplicate_scenario()
	var frozen_sugar_portions: int = scenario.sugar_portions
	var frozen_protein_portions: int = scenario.protein_portions
	var frozen_growth_ticks: int = (
		scenario.nutrition_data.protein_growth_ticks_per_portion
	)
	var simulation: ColonySimulation = ColonySimulation.new(
		SPECIES_A_DATA,
		scenario
	)
	_expect_true(simulation.is_ready(), "nutrition scenario initializes")
	var initial: GameSnapshot = simulation.create_game_snapshot()
	_expect_true(initial.nutrition != null, "nutrition snapshot is exposed")
	_expect_true(initial.colony.lifecycle_active, "habitat lifecycle is active")
	_expect_int(
		initial.colony.count_stage(AntModel.LifeStage.WORKER),
		NUTRITION_SCENARIO_DATA.initial_worker_count,
		"configured workers are created"
	)
	_expect_int(
		initial.colony.count_stage(AntModel.LifeStage.LARVA),
		NUTRITION_SCENARIO_DATA.initial_brood_count,
		"configured larvae are created"
	)
	_expect_true(
		initial.nutrition.sugar_action_available,
		"sugar placement starts available"
	)
	_expect_true(
		initial.nutrition.protein_action_available,
		"protein placement starts available"
	)
	_expect_true(
		simulation.submit_place_sugar_action(),
		"sugar high-level command is accepted"
	)
	_expect_true(
		simulation.submit_place_protein_action(),
		"protein high-level command is accepted"
	)
	var pending: GameSnapshot = simulation.create_game_snapshot()
	_expect_true(
		pending.nutrition.sugar_action_pending,
		"sugar command remains pending until the next Tick"
	)
	_expect_true(
		pending.nutrition.protein_action_pending,
		"protein command remains pending until the next Tick"
	)
	_expect_int(
		pending.colony.food_sources.size(),
		0,
		"submitting food commands cannot mutate authority immediately"
	)
	_expect_true(
		not simulation.advance_tick(2),
		"a skipped Tick does not consume nutrition commands"
	)

	scenario.sugar_portions = 1
	scenario.protein_portions = 1
	scenario.sugar_placement_zone_id = NEST_ZONE_ID
	scenario.protein_placement_zone_id = NEST_ZONE_ID
	scenario.nutrition_data.protein_growth_ticks_per_portion = 1
	scenario.nutrition_data.sugar_activity_ticks_per_portion = 1
	_expect_true(
		simulation.advance_tick(1),
		"the next legal Tick applies both queued commands"
	)
	var applied: GameSnapshot = simulation.create_game_snapshot()
	_expect_int(
		applied.colony.food_sources.size(),
		2,
		"two configured food sources are created exactly once"
	)
	var sugar_source: FoodSourceSnapshot = _find_source(
		applied,
		FoodSourceState.FoodType.SUGAR_WATER
	)
	var protein_source: FoodSourceSnapshot = _find_source(
		applied,
		FoodSourceState.FoodType.PROTEIN
	)
	_expect_true(sugar_source != null, "sugar source is distinguishable")
	_expect_true(protein_source != null, "protein source is distinguishable")
	if sugar_source != null:
		_expect_string_name(
			sugar_source.zone_id,
			FORAGING_ZONE_ID,
			"sugar placement uses the frozen target"
		)
		_expect_int(
			sugar_source.remaining_portions,
			frozen_sugar_portions,
			"sugar placement uses the frozen amount"
		)
	if protein_source != null:
		_expect_string_name(
			protein_source.zone_id,
			FORAGING_ZONE_ID,
			"protein placement uses the frozen target"
		)
		_expect_int(
			protein_source.remaining_portions,
			frozen_protein_portions,
			"protein placement uses the frozen amount"
		)
	_expect_int(
		simulation._habitat_config.nutrition_config
			.protein_growth_ticks_per_portion,
		frozen_growth_ticks,
		"running growth rules do not read the mutated Resource"
	)


func _test_protein_shortage_stalls_and_feeding_restores_growth() -> void:
	var simulation: ColonySimulation = _create_simulation()
	_expect_true(
		_advance_to_tick(simulation, 200),
		"protein-shortage fixture advances"
	)
	var starved: GameSnapshot = simulation.create_game_snapshot()
	for ant: AntSnapshot in starved.colony.ants:
		if ant.life_stage == AntModel.LifeStage.LARVA:
			_expect_int(
				ant.stage_age_ticks,
				0,
				"larval stage progress stalls without protein"
			)
			_expect_int(
				ant.total_age_ticks,
				200,
				"elapsed age still records protein-shortage time"
			)
	_expect_true(
		simulation.submit_place_protein_action(),
		"protein can be supplied after a shortage"
	)
	_expect_true(
		_advance_until(
			simulation,
			func(snapshot: GameSnapshot) -> bool:
				return (
					snapshot.nutrition.completed_feeding_count >= 2
				),
			1800
		),
		"workers collect protein and feed both larvae"
	)
	var fed: GameSnapshot = simulation.create_game_snapshot()
	_expect_true(
		fed.nutrition.completed_feeding_count >= 2,
		"feeding completion is authoritative snapshot state"
	)
	for ant: AntSnapshot in fed.colony.ants:
		if ant.life_stage == AntModel.LifeStage.LARVA:
			_expect_true(
				ant.protein_supported_growth_ticks > 0
					or ant.stage_age_ticks > 0,
				"each fed larva receives deterministic growth support"
			)
	_expect_true(
		_advance_until(
			simulation,
			func(snapshot: GameSnapshot) -> bool:
				return (
					snapshot.colony.count_stage(
						AntModel.LifeStage.PUPA
					) >= 2
				),
			3600
		),
		"the configured protein supply lets both initial larvae pupate"
	)
	var pupated: GameSnapshot = simulation.create_game_snapshot()
	_expect_int(
		pupated.nutrition.total_protein_portions_consumed,
		NUTRITION_SCENARIO_DATA.protein_portions,
		"two larvae consume the resource-derived protein requirement"
	)
	_expect_true(
		simulation.has_valid_habitat_ownership(),
		"feeding and lifecycle transitions preserve ownership"
	)


func _test_sugar_shortage_slows_but_does_not_deadlock_activity() -> void:
	var fueled_data: HabitatScenarioData = _duplicate_scenario()
	fueled_data.nutrition_data.initial_sugar_reserve_portions = 1
	var fueled: ColonySimulation = ColonySimulation.new(
		SPECIES_A_DATA,
		fueled_data
	)
	var shortage: ColonySimulation = _create_simulation()
	_expect_true(
		fueled.submit_place_protein_action(),
		"fueled fixture accepts protein"
	)
	_expect_true(
		shortage.submit_place_protein_action(),
		"shortage fixture accepts protein"
	)
	_expect_true(_advance_to_tick(fueled, 260), "fueled fixture advances")
	_expect_true(
		_advance_to_tick(shortage, 260),
		"shortage fixture still advances"
	)
	var fueled_snapshot: GameSnapshot = fueled.create_game_snapshot()
	var shortage_snapshot: GameSnapshot = shortage.create_game_snapshot()
	_expect_true(
		fueled_snapshot.nutrition.completed_feeding_count
			> shortage_snapshot.nutrition.completed_feeding_count,
		"sugar reserve measurably accelerates worker activity"
	)
	_expect_true(
		shortage_snapshot.simulation_tick == 260,
		"sugar shortage never stops fixed-Tick time"
	)
	_expect_true(
		_advance_until(
			shortage,
			func(snapshot: GameSnapshot) -> bool:
				return snapshot.nutrition.completed_feeding_count > 0,
			1400
		),
		"shortage pacing remains recoverable without colony death"
	)


func _test_deterministic_snapshots_and_snapshot_isolation() -> void:
	var first: ColonySimulation = _create_simulation()
	var second: ColonySimulation = _create_simulation()
	for simulation: ColonySimulation in [first, second]:
		_expect_true(
			simulation.submit_place_sugar_action(),
			"determinism fixture queues sugar"
		)
		_expect_true(
			simulation.submit_place_protein_action(),
			"determinism fixture queues protein"
		)
	_expect_true(_advance_to_tick(first, 700), "first fixture advances")
	_expect_true(_advance_to_tick(second, 700), "second fixture advances")
	_expect_string(
		_state_signature(first),
		_state_signature(second),
		"same configuration and commands produce identical authority"
	)

	var exposed: GameSnapshot = first.create_game_snapshot()
	var original_signature: String = _state_signature(first)
	exposed.nutrition.sugar_reserve_portions = 999
	exposed.nutrition.protein_reserve_portions = 999
	if not exposed.colony.ants.is_empty():
		exposed.colony.ants[0].protein_supported_growth_ticks = 999
		if exposed.colony.ants[0].feeding_task != null:
			exposed.colony.ants[0].feeding_task.route_zone_ids.clear()
	if not exposed.colony.food_sources.is_empty():
		exposed.colony.food_sources[0].remaining_portions = 999
	_expect_string(
		_state_signature(first),
		original_signature,
		"mutating nutrition snapshots cannot change authority"
	)


func _test_speed_multipliers_match_at_the_same_tick() -> void:
	var signatures: Dictionary[int, String] = {}
	for speed: int in [
		SimulationClock.NORMAL_SPEED,
		SimulationClock.FAST_SPEED,
		SimulationClock.VERY_FAST_SPEED,
	]:
		var simulation: ColonySimulation = _create_simulation()
		simulation.submit_place_sugar_action()
		simulation.submit_place_protein_action()
		var clock: SimulationClock = SimulationClock.new(16)
		clock.set_speed_multiplier(speed)
		clock.tick_requested.connect(
			func(tick_index: int, _tick_seconds: float) -> void:
				simulation.advance_tick(tick_index)
		)
		while clock.get_tick_index() < 640:
			clock.advance(SimulationClock.FIXED_STEP_SECONDS)
		signatures[speed] = _state_signature(simulation)
	_expect_string(
		signatures[SimulationClock.NORMAL_SPEED],
		signatures[SimulationClock.FAST_SPEED],
		"1x and 4x match at the same nutrition Tick"
	)
	_expect_string(
		signatures[SimulationClock.NORMAL_SPEED],
		signatures[SimulationClock.VERY_FAST_SPEED],
		"1x and 16x match at the same nutrition Tick"
	)


func _test_save_round_trip_preserves_pending_and_active_work() -> void:
	var service: SaveGameService = SaveGameService.new()
	var pending_simulation: ColonySimulation = _create_simulation()
	_expect_true(
		pending_simulation.submit_place_protein_action(),
		"pending-save fixture queues protein"
	)
	var pending_clock: SimulationClock = _clock_at(0)
	var pending_envelope: Dictionary = service.create_envelope(
		pending_simulation,
		pending_clock,
		"nutrition_pending",
		"2026-07-28T15:00:00Z"
	)
	var pending_load: Dictionary = service.load_envelope(pending_envelope)
	_expect_true(
		pending_load.get("ok", false),
		"pending protein command survives save and load"
	)
	if pending_load.get("ok", false):
		var restored_pending: ColonySimulation = pending_load["simulation"]
		_expect_true(
			restored_pending.create_game_snapshot()
				.nutrition.protein_action_pending,
			"restored snapshot exposes pending protein"
		)
		_expect_true(
			restored_pending.advance_tick(1),
			"restored protein command applies on the next Tick"
		)
		_expect_true(
			_find_source(
				restored_pending.create_game_snapshot(),
				FoodSourceState.FoodType.PROTEIN
			) != null,
			"restored command creates the configured protein source"
		)

	var active: ColonySimulation = _create_simulation()
	active.submit_place_sugar_action()
	active.submit_place_protein_action()
	_advance_to_tick(active, 300)
	var active_envelope: Dictionary = service.create_envelope(
		active,
		_clock_at(300),
		"nutrition_active",
		"2026-07-28T15:01:00Z"
	)
	var active_load: Dictionary = service.load_envelope(active_envelope)
	_expect_true(
		active_load.get("ok", false),
		"active nutrition tasks survive strict reconstruction"
	)
	if not active_load.get("ok", false):
		return
	var restored: ColonySimulation = active_load["simulation"]
	_expect_string(
		_state_signature(restored),
		_state_signature(active),
		"save round trip preserves exact nutrition authority"
	)
	_advance_to_tick(active, 650)
	_advance_to_tick(restored, 650)
	_expect_string(
		_state_signature(restored),
		_state_signature(active),
		"restored nutrition simulation remains deterministic"
	)


func _test_ten_thousand_tick_conservation_soak() -> void:
	var simulation: ColonySimulation = _create_simulation()
	var sugar_supply_limit: int = 12
	var protein_supply_limit: int = 16
	for tick: int in range(1, SOAK_TICK_COUNT + 1):
		var before: GameSnapshot = simulation.create_game_snapshot()
		if (
			before.nutrition.sugar_action_available
			and before.nutrition.total_sugar_portions_supplied
				< sugar_supply_limit
		):
			simulation.submit_place_sugar_action()
		if (
			before.nutrition.protein_action_available
			and before.nutrition.total_protein_portions_supplied
				< protein_supply_limit
		):
			simulation.submit_place_protein_action()
		_expect_true(
			simulation.advance_tick(tick),
			"nutrition soak accepts Tick %d" % tick
		)
		_expect_true(
			simulation.has_valid_habitat_ownership(),
			"nutrition conservation holds at Tick %d" % tick
		)
	var final_snapshot: GameSnapshot = simulation.create_game_snapshot()
	_expect_int(
		final_snapshot.simulation_tick,
		SOAK_TICK_COUNT,
		"nutrition soak reaches its final Tick"
	)
	_expect_true(
		final_snapshot.colony.queen_laid_egg_count
			<= SPECIES_A_DATA.max_first_generation_brood,
		"resource-constrained habitat growth respects the lifecycle cap"
	)
	_expect_true(
		simulation.is_ready(),
		"nutrition soak leaves the simulation healthy"
	)


func _create_simulation() -> ColonySimulation:
	return ColonySimulation.new(SPECIES_A_DATA, NUTRITION_SCENARIO_DATA)


func _duplicate_scenario() -> HabitatScenarioData:
	var duplicate: HabitatScenarioData = (
		NUTRITION_SCENARIO_DATA.duplicate(true) as HabitatScenarioData
	)
	var zones: Array[HabitatZoneData] = []
	for zone: HabitatZoneData in NUTRITION_SCENARIO_DATA.zones:
		zones.append(zone.duplicate(true) as HabitatZoneData)
	duplicate.zones = zones
	duplicate.foraging_data = (
		NUTRITION_SCENARIO_DATA.foraging_data.duplicate(true) as ForagingData
	)
	duplicate.nutrition_data = (
		NUTRITION_SCENARIO_DATA.nutrition_data.duplicate(true)
		as NutritionData
	)
	return duplicate


func _find_source(
	snapshot: GameSnapshot,
	food_type: FoodSourceState.FoodType
) -> FoodSourceSnapshot:
	for source: FoodSourceSnapshot in snapshot.colony.food_sources:
		if source.food_type == food_type:
			return source
	return null


func _advance_to_tick(
	simulation: ColonySimulation,
	target_tick: int
) -> bool:
	var current_tick: int = simulation.create_snapshot().simulation_tick
	for tick: int in range(current_tick + 1, target_tick + 1):
		if not simulation.advance_tick(tick):
			return false
	return true


func _advance_until(
	simulation: ColonySimulation,
	predicate: Callable,
	maximum_tick: int
) -> bool:
	if predicate.call(simulation.create_game_snapshot()):
		return true
	var current_tick: int = simulation.create_snapshot().simulation_tick
	for tick: int in range(current_tick + 1, maximum_tick + 1):
		if not simulation.advance_tick(tick):
			return false
		if predicate.call(simulation.create_game_snapshot()):
			return true
	return false


func _clock_at(tick: int) -> SimulationClock:
	var clock: SimulationClock = SimulationClock.new()
	clock.restore_save_boundary(
		tick,
		SimulationClock.NORMAL_SPEED,
		true
	)
	return clock


func _state_signature(simulation: ColonySimulation) -> String:
	var encoded: Dictionary = SimulationStateCodec.encode_simulation(
		simulation
	)
	return CanonicalSaveJson.sha256(encoded["state_payload"])


func _expect_int(actual: int, expected: int, message: String) -> void:
	_assertion_count += 1
	if actual != expected:
		_record_failure(message, str(expected), str(actual))


func _expect_true(actual: bool, message: String) -> void:
	_assertion_count += 1
	if not actual:
		_record_failure(message, "true", "false")


func _expect_string(
	actual: String,
	expected: String,
	message: String
) -> void:
	_assertion_count += 1
	if actual != expected:
		_record_failure(message, expected, actual)


func _expect_string_name(
	actual: StringName,
	expected: StringName,
	message: String
) -> void:
	_assertion_count += 1
	if actual != expected:
		_record_failure(message, String(expected), String(actual))


func _record_failure(
	message: String,
	expected: String,
	actual: String
) -> void:
	_failure_count += 1
	printerr("  %s — expected %s, got %s" % [message, expected, actual])
