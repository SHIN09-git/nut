class_name ForagingTestSuite
extends RefCounted

const SPECIES_A_DATA: SpeciesData = preload("res://data/species/species_a.tres")
const FORAGING_SCENARIO_DATA: HabitatScenarioData = preload(
	"res://data/habitats/sugar_foraging_slice.tres"
)
const NEST_ZONE_ID: StringName = &"nest_chamber"
const ENTRANCE_ZONE_ID: StringName = &"entrance_tunnel"
const FORAGING_ZONE_ID: StringName = &"foraging_area"
const OBSERVATION_CARD_ID: StringName = &"sugar_return_and_share"
const FIRST_WORKER_ID: int = 1
const FIRST_FOOD_SOURCE_ID: int = (
	FORAGING_SCENARIO_DATA.initial_worker_count + 1
)
const NO_ENTITY_ID: int = -1
const SOAK_TICK_COUNT: int = 10_000

var _assertion_count: int = 0
var _failure_count: int = 0


func run() -> void:
	_test_place_command_waits_for_next_legal_tick()
	_test_configuration_is_frozen_across_restart()
	_test_stable_worker_and_source_selection()
	_test_paths_are_cached_until_endpoint_or_topology_changes()
	_test_food_source_amounts_are_finite_and_nonnegative()
	_test_resource_derived_state_boundaries()
	_test_unique_reservation_carry_and_conservation_each_tick()
	_test_removed_source_tombstone_cancels_and_can_be_restored()
	_test_return_pauses_for_invalid_path_and_nest_then_recovers()
	_test_game_snapshot_is_a_deep_copy()
	_test_speed_multipliers_match_at_the_same_tick()
	_test_structured_events_are_complete_unique_and_ordered()
	_test_restart_clears_foraging_session_state()
	_test_ten_thousand_tick_soak()


func get_assertion_count() -> int:
	return _assertion_count


func get_failure_count() -> int:
	return _failure_count


func _test_place_command_waits_for_next_legal_tick() -> void:
	var simulation: ColonySimulation = _create_simulation()
	var initial: GameSnapshot = simulation.create_game_snapshot()
	_expect_true(
		initial.scenario.place_action_available,
		"the configured sugar action starts available"
	)
	_expect_true(
		simulation.submit_place_sugar_action(),
		"the high-level sugar action is accepted"
	)

	var pending: GameSnapshot = simulation.create_game_snapshot()
	_expect_int(
		pending.simulation_tick,
		0,
		"submitting sugar does not advance simulation time"
	)
	_expect_true(
		pending.scenario.place_action_pending,
		"the accepted sugar action is exposed as pending"
	)
	_expect_int(
		pending.colony.food_sources.size(),
		0,
		"submitting sugar does not immediately create a food source"
	)
	_expect_true(
		not simulation.advance_tick(2),
		"a skipped Tick is rejected before consuming the queued action"
	)

	var after_rejection: GameSnapshot = simulation.create_game_snapshot()
	_expect_int(
		after_rejection.simulation_tick,
		0,
		"the rejected Tick leaves canonical time unchanged"
	)
	_expect_true(
		after_rejection.scenario.place_action_pending,
		"the rejected Tick preserves the queued sugar action"
	)
	_expect_int(
		after_rejection.colony.food_sources.size(),
		0,
		"the rejected Tick cannot partially apply the action"
	)

	_expect_true(
		simulation.advance_tick(1),
		"the next legal Tick applies the queued sugar action"
	)
	var applied: GameSnapshot = simulation.create_game_snapshot()
	_expect_int(
		applied.colony.food_sources.size(),
		1,
		"the next legal Tick creates exactly one food source"
	)
	_expect_true(
		not applied.scenario.place_action_pending,
		"the applied sugar action leaves no pending command"
	)
	_expect_int(
		applied.scenario.place_action_count,
		1,
		"the scenario records one applied placement action"
	)
	_expect_true(
		not simulation.submit_place_sugar_action(),
		"the single-placement scenario rejects a duplicate action"
	)


func _test_configuration_is_frozen_across_restart() -> void:
	var scenario: HabitatScenarioData = _duplicate_foraging_scenario()
	var original_discovery_ticks: int = (
		scenario.foraging_data.discovery_delay_ticks
	)
	var original_outbound_ticks: int = (
		scenario.foraging_data.outbound_travel_duration_ticks
	)
	var original_portions: int = scenario.sugar_portions
	var original_placement_zone_id: StringName = (
		scenario.sugar_placement_zone_id
	)
	var original_card_id: StringName = scenario.foraging_observation_card_id
	var simulation: ColonySimulation = ColonySimulation.new(
		SPECIES_A_DATA,
		scenario
	)
	_expect_true(
		simulation.is_ready(),
		"the mutable configuration fixture initializes successfully"
	)

	scenario.foraging_data.discovery_delay_ticks = (
		original_discovery_ticks + 997
	)
	scenario.foraging_data.outbound_travel_duration_ticks += 991
	scenario.sugar_portions = 3
	scenario.sugar_placement_zone_id = NEST_ZONE_ID
	scenario.foraging_observation_card_id = &"mutated_card"
	var source_zone_data: HabitatZoneData = _find_zone_data(
		scenario,
		original_placement_zone_id
	)
	source_zone_data.available = false
	source_zone_data.connected_zone_ids.clear()

	_place_sugar_on_tick_one(simulation)
	var first_run: GameSnapshot = simulation.create_game_snapshot()
	var first_source: FoodSourceSnapshot = first_run.colony.food_sources[0]
	var first_worker: AntSnapshot = _find_worker(
		first_run,
		FIRST_WORKER_ID
	)
	_expect_string_name(
		first_source.zone_id,
		original_placement_zone_id,
		"the running simulation keeps its frozen placement zone"
	)
	_expect_int(
		first_source.remaining_portions,
		original_portions,
		"the running simulation keeps its frozen source amount"
	)
	_expect_int(
		first_worker.foraging_task.duration_ticks,
		original_discovery_ticks,
		"the running simulation keeps its frozen discovery duration"
	)
	_advance_to_tick(simulation, 1 + original_discovery_ticks)
	var first_outbound: GameSnapshot = simulation.create_game_snapshot()
	_expect_int(
		_find_worker(first_outbound, FIRST_WORKER_ID)
			.foraging_task.duration_ticks,
		original_outbound_ticks,
		"the running simulation keeps its frozen outbound duration"
	)
	_advance_until_card(simulation, _completion_tick() + 1)
	var first_completed: GameSnapshot = simulation.create_game_snapshot()
	_expect_true(
		first_completed.observations.has_card(original_card_id),
		"the running simulation unlocks the frozen observation card"
	)
	_expect_true(
		not first_completed.observations.has_card(&"mutated_card"),
		"the running simulation ignores the mutated observation card ID"
	)

	_expect_true(
		simulation.restart_session(),
		"restart succeeds after the source Resources are mutated"
	)
	var restarted: GameSnapshot = simulation.create_game_snapshot()
	_expect_true(
		restarted.scenario.place_action_available,
		"restart derives tool availability from frozen configuration"
	)
	_expect_string_name(
		restarted.scenario.placement_zone_id,
		original_placement_zone_id,
		"restart keeps the frozen placement target"
	)
	_place_sugar_on_tick_one(simulation)
	var second_run: GameSnapshot = simulation.create_game_snapshot()
	_expect_string_name(
		second_run.colony.food_sources[0].zone_id,
		original_placement_zone_id,
		"the restarted simulation still places in the frozen zone"
	)
	_expect_int(
		second_run.colony.food_sources[0].remaining_portions,
		original_portions,
		"the restarted simulation still uses the frozen amount"
	)
	_expect_int(
		_find_worker(second_run, FIRST_WORKER_ID)
			.foraging_task.duration_ticks,
		original_discovery_ticks,
		"the restarted task still uses the frozen pacing"
	)
	_advance_to_tick(simulation, 1 + original_discovery_ticks)
	var second_outbound: GameSnapshot = simulation.create_game_snapshot()
	_expect_int(
		_find_worker(second_outbound, FIRST_WORKER_ID)
			.foraging_task.duration_ticks,
		original_outbound_ticks,
		"the restarted task keeps the frozen outbound duration"
	)
	_advance_until_card(simulation, _completion_tick() + 1)
	var second_completed: GameSnapshot = simulation.create_game_snapshot()
	_expect_true(
		second_completed.observations.has_card(original_card_id),
		"restart keeps the frozen observation-card identity"
	)
	_expect_true(
		not second_completed.observations.has_card(&"mutated_card"),
		"restart cannot adopt the mutated observation-card identity"
	)


func _test_stable_worker_and_source_selection() -> void:
	var simulation: ColonySimulation = _create_simulation()
	var state: ColonyState = simulation.get("_state") as ColonyState
	var first_source: FoodSourceState = state.create_food_source(
		FORAGING_ZONE_ID,
		1,
		FoodSourceState.FoodType.SUGAR_WATER
	)
	var second_source: FoodSourceState = state.create_food_source(
		FORAGING_ZONE_ID,
		1,
		FoodSourceState.FoodType.SUGAR_WATER
	)
	state.total_sugar_portions_placed = 2
	state.food_sources.reverse()
	state.ants.reverse()

	_expect_true(
		simulation.advance_tick(1),
		"the deterministic assignment fixture accepts its first Tick"
	)
	var snapshot: GameSnapshot = simulation.create_game_snapshot()
	_expect_int(
		_find_worker(snapshot, 1).foraging_task.target_food_source_id,
		first_source.entity_id,
		"the lowest stable worker ID claims the lowest stable source ID"
	)
	_expect_int(
		_find_worker(snapshot, 2).foraging_task.target_food_source_id,
		second_source.entity_id,
		"the next stable worker ID claims the next stable source ID"
	)
	_expect_int(
		_find_worker(snapshot, 3).foraging_task.state,
		ForagingTaskModel.State.IDLE,
		"an excess worker remains idle without duplicating a claim"
	)
	_expect_int(
		snapshot.observations.events[0].actor_entity_id,
		1,
		"same-Tick assignment events follow stable worker order"
	)
	_expect_int(
		snapshot.observations.events[0].subject_entity_id,
		first_source.entity_id,
		"same-Tick assignment events expose the stable source choice"
	)


func _test_paths_are_cached_until_endpoint_or_topology_changes() -> void:
	var config: HabitatScenarioConfig = HabitatScenarioConfig.from_data(
		FORAGING_SCENARIO_DATA
	)
	var brood_config: BroodCareConfig = BroodCareConfig.from_species_data(
		SPECIES_A_DATA
	)
	var state: ColonyState = ColonyState.new()
	_expect_true(
		config != null
			and brood_config != null
			and state.initialize_habitat(config, brood_config),
		"route-cache fixture initializes the configured habitat"
	)
	if config == null or brood_config == null:
		return
	var system: ForagingSystem = ForagingSystem.new(
		config.foraging_config,
		config
	)
	_expect_true(system.is_ready(), "route-cache fixture initializes foraging")

	var first_route: Array = system.call(
		"_find_stable_path",
		state,
		NEST_ZONE_ID,
		FORAGING_ZONE_ID
	)
	_expect_int(first_route.size(), 3, "the initial topology yields a three-zone route")
	var route_cache: Dictionary = system.get("_route_cache")
	_expect_int(route_cache.size(), 1, "the first endpoint pair creates one cache entry")
	for repeated_search: int in range(5):
		var repeated_route: Array = system.call(
			"_find_stable_path",
			state,
			NEST_ZONE_ID,
			FORAGING_ZONE_ID
		)
		_expect_int(
			repeated_route.size(),
			first_route.size(),
			"unchanged topology reuses the cached route on search %d"
			% repeated_search
		)
	_expect_int(
		route_cache.size(),
		1,
		"unchanged endpoints and topology do not add route-cache entries"
	)

	state.get_zone(ENTRANCE_ZONE_ID).available = false
	var unavailable_route: Array = system.call(
		"_find_stable_path",
		state,
		NEST_ZONE_ID,
		FORAGING_ZONE_ID
	)
	_expect_true(
		unavailable_route.is_empty(),
		"a topology change caches the currently unreachable result"
	)
	_expect_int(
		route_cache.size(),
		2,
		"the unavailable topology creates exactly one new cache entry"
	)
	for repeated_search: int in range(5):
		var repeated_unavailable_route: Array = system.call(
			"_find_stable_path",
			state,
			NEST_ZONE_ID,
			FORAGING_ZONE_ID
		)
		_expect_true(
			repeated_unavailable_route.is_empty(),
			"unchanged unreachable topology reuses its negative cache entry"
		)
	_expect_int(
		route_cache.size(),
		2,
		"repeated unreachable searches do not expand the cache"
	)

	state.get_zone(ENTRANCE_ZONE_ID).available = true
	var restored_route: Array = system.call(
		"_find_stable_path",
		state,
		NEST_ZONE_ID,
		FORAGING_ZONE_ID
	)
	_expect_int(
		restored_route.size(),
		first_route.size(),
		"restoring a known topology reuses its original cached route"
	)
	_expect_int(
		route_cache.size(),
		2,
		"restoring a known topology does not calculate a duplicate route"
	)

	var changed_endpoint_route: Array = system.call(
		"_find_stable_path",
		state,
		NEST_ZONE_ID,
		ENTRANCE_ZONE_ID
	)
	_expect_int(
		changed_endpoint_route.size(),
		2,
		"changing the target endpoint calculates the required shorter route"
	)
	_expect_int(
		route_cache.size(),
		3,
		"a changed endpoint creates one distinct cache entry"
	)


func _test_food_source_amounts_are_finite_and_nonnegative() -> void:
	var clamped_source: FoodSourceState = FoodSourceState.new(
		99,
		FORAGING_ZONE_ID,
		-10
	)
	_expect_int(
		clamped_source.remaining_portions,
		0,
		"a negative construction amount is clamped to zero"
	)
	_expect_true(
		not clamped_source.take_portion(),
		"an empty source cannot underflow through collection"
	)
	_expect_int(
		clamped_source.remaining_portions,
		0,
		"a rejected collection leaves the amount at zero"
	)
	_expect_true(
		not is_nan(float(clamped_source.remaining_portions))
		and not is_inf(float(clamped_source.remaining_portions)),
		"food portions remain finite"
	)

	var simulation: ColonySimulation = _create_simulation()
	_place_sugar_on_tick_one(simulation)
	_advance_to_tick(simulation, _completion_tick())
	var completed: GameSnapshot = simulation.create_game_snapshot()
	var source: FoodSourceSnapshot = completed.colony.food_sources[0]
	_expect_int(
		source.remaining_portions,
		0,
		"the complete cycle consumes exactly the configured portion"
	)
	_expect_true(
		source.remaining_portions >= 0,
		"the complete cycle never produces a negative source amount"
	)


func _test_resource_derived_state_boundaries() -> void:
	var data: ForagingData = FORAGING_SCENARIO_DATA.foraging_data
	var moving_tick: int = 1 + data.discovery_delay_ticks
	var collecting_tick: int = (
		moving_tick + data.outbound_travel_duration_ticks
	)
	var returning_tick: int = (
		collecting_tick + data.collection_duration_ticks
	)
	var sharing_tick: int = (
		returning_tick + data.return_travel_duration_ticks
	)
	var completion_tick: int = (
		sharing_tick + data.sharing_duration_ticks
	)
	var simulation: ColonySimulation = _create_simulation()
	_place_sugar_on_tick_one(simulation)

	_expect_task(
		_find_worker(simulation.create_game_snapshot(), FIRST_WORKER_ID),
		ForagingTaskModel.State.SEEKING_FOOD,
		0,
		data.discovery_delay_ticks,
		"placement boundary"
	)
	_advance_to_tick(simulation, moving_tick - 1)
	_expect_task(
		_find_worker(simulation.create_game_snapshot(), FIRST_WORKER_ID),
		ForagingTaskModel.State.SEEKING_FOOD,
		data.discovery_delay_ticks - 1,
		data.discovery_delay_ticks,
		"last seeking Tick"
	)
	_advance_to_tick(simulation, moving_tick)
	_expect_task(
		_find_worker(simulation.create_game_snapshot(), FIRST_WORKER_ID),
		ForagingTaskModel.State.MOVING_TO_FOOD,
		0,
		data.outbound_travel_duration_ticks,
		"moving boundary"
	)

	_advance_to_tick(simulation, collecting_tick - 1)
	_expect_task(
		_find_worker(simulation.create_game_snapshot(), FIRST_WORKER_ID),
		ForagingTaskModel.State.MOVING_TO_FOOD,
		data.outbound_travel_duration_ticks - 1,
		data.outbound_travel_duration_ticks,
		"last outbound Tick"
	)
	_advance_to_tick(simulation, collecting_tick)
	var collecting: GameSnapshot = simulation.create_game_snapshot()
	_expect_task(
		_find_worker(collecting, FIRST_WORKER_ID),
		ForagingTaskModel.State.COLLECTING,
		0,
		data.collection_duration_ticks,
		"collection boundary"
	)
	_expect_string_name(
		_find_worker(collecting, FIRST_WORKER_ID).zone_id,
		FORAGING_ZONE_ID,
		"the worker arrives in the source zone at collection"
	)

	_advance_to_tick(simulation, returning_tick - 1)
	_expect_task(
		_find_worker(simulation.create_game_snapshot(), FIRST_WORKER_ID),
		ForagingTaskModel.State.COLLECTING,
		data.collection_duration_ticks - 1,
		data.collection_duration_ticks,
		"last collection Tick"
	)
	_advance_to_tick(simulation, returning_tick)
	var returning: GameSnapshot = simulation.create_game_snapshot()
	_expect_task(
		_find_worker(returning, FIRST_WORKER_ID),
		ForagingTaskModel.State.RETURNING_TO_NEST,
		0,
		data.return_travel_duration_ticks,
		"return boundary"
	)
	_expect_int(
		_find_worker(returning, FIRST_WORKER_ID)
			.foraging_task.carried_portions,
		1,
		"collection transfers exactly one portion to the worker"
	)
	_expect_int(
		returning.colony.food_sources[0].remaining_portions,
		0,
		"collection removes exactly one portion from the source"
	)

	_advance_to_tick(simulation, sharing_tick - 1)
	_expect_task(
		_find_worker(simulation.create_game_snapshot(), FIRST_WORKER_ID),
		ForagingTaskModel.State.RETURNING_TO_NEST,
		data.return_travel_duration_ticks - 1,
		data.return_travel_duration_ticks,
		"last return Tick"
	)
	_advance_to_tick(simulation, sharing_tick)
	var sharing: GameSnapshot = simulation.create_game_snapshot()
	_expect_task(
		_find_worker(sharing, FIRST_WORKER_ID),
		ForagingTaskModel.State.SHARING,
		0,
		data.sharing_duration_ticks,
		"sharing boundary"
	)
	_expect_string_name(
		_find_worker(sharing, FIRST_WORKER_ID).zone_id,
		NEST_ZONE_ID,
		"the worker reaches the nest before sharing"
	)

	_advance_to_tick(simulation, completion_tick - 1)
	_expect_task(
		_find_worker(simulation.create_game_snapshot(), FIRST_WORKER_ID),
		ForagingTaskModel.State.SHARING,
		data.sharing_duration_ticks - 1,
		data.sharing_duration_ticks,
		"last sharing Tick"
	)
	_advance_to_tick(simulation, completion_tick)
	var completed: GameSnapshot = simulation.create_game_snapshot()
	_expect_task(
		_find_worker(completed, FIRST_WORKER_ID),
		ForagingTaskModel.State.IDLE,
		0,
		0,
		"completion boundary"
	)
	_expect_true(
		completed.observations.has_card(OBSERVATION_CARD_ID),
		"sharing completion unlocks the configured observation card"
	)
	_expect_int(
		completed.scenario.phase,
		ForagingScenarioSnapshot.Phase.COMPLETED,
		"the scenario completes on the sharing boundary"
	)


func _test_unique_reservation_carry_and_conservation_each_tick() -> void:
	var simulation: ColonySimulation = _create_simulation()
	_place_sugar_on_tick_one(simulation)
	var first_failure: String = ""
	var tick_index: int = 1
	while tick_index <= _completion_tick():
		var snapshot: GameSnapshot = simulation.create_game_snapshot()
		var invariant_failure: String = _get_foraging_invariant_failure(
			snapshot,
			FORAGING_SCENARIO_DATA.sugar_portions
		)
		if first_failure.is_empty() and not invariant_failure.is_empty():
			first_failure = "Tick %d: %s" % [
				snapshot.simulation_tick,
				invariant_failure,
			]
		if tick_index < _completion_tick():
			if not simulation.advance_tick(tick_index + 1):
				first_failure = (
					"Tick %d was rejected during conservation trace"
					% (tick_index + 1)
				)
				break
		tick_index += 1

	_expect_string(
		first_failure,
		"",
		"every Tick preserves unique reservation, carry, and sugar conservation"
	)
	_expect_true(
		simulation.has_valid_habitat_ownership(),
		"the simulation reports valid ownership after the complete cycle"
	)


func _test_removed_source_tombstone_cancels_and_can_be_restored() -> void:
	var simulation: ColonySimulation = _create_simulation()
	_place_sugar_on_tick_one(simulation)
	var state: ColonyState = simulation.get("_state") as ColonyState
	var source: FoodSourceState = state.food_sources[0]
	_expect_true(
		state.remove_food_source(source.entity_id),
		"removing a source creates an authoritative conservation tombstone"
	)

	_expect_true(
		simulation.advance_tick(2),
		"removing a pre-collection source is handled on the next Tick"
	)
	var cancelled: GameSnapshot = simulation.create_game_snapshot()
	var worker: AntSnapshot = _find_worker(cancelled, FIRST_WORKER_ID)
	_expect_int(
		cancelled.colony.food_sources.size(),
		1,
		"source removal retains exactly one conservation tombstone"
	)
	_expect_true(
		not cancelled.colony.food_sources[0].available,
		"the removed source is unavailable to simulation and view"
	)
	_expect_int(
		worker.foraging_task.state,
		ForagingTaskModel.State.IDLE,
		"source removal cancels the pre-collection task"
	)
	_expect_int(
		cancelled.colony.food_sources[0].reserved_by_worker_id,
		NO_ENTITY_ID,
		"source removal clears the source reservation"
	)
	_expect_int(
		cancelled.colony.food_sources[0].carrier_worker_id,
		NO_ENTITY_ID,
		"source removal leaves no carried ownership"
	)
	_expect_true(
		simulation.has_valid_habitat_ownership(),
		"source removal preserves the ownership invariant"
	)
	_expect_int(
		_count_events(
			cancelled.observations.events,
			ObservationEvent.Type.FORAGING_TASK_CANCELLED
		),
		1,
		"source removal emits one structured cancellation event"
	)

	source.available = true
	_expect_true(
		simulation.advance_tick(3),
		"restoring the source allows deterministic reassignment"
	)
	var reassigned: GameSnapshot = simulation.create_game_snapshot()
	worker = _find_worker(reassigned, FIRST_WORKER_ID)
	_expect_int(
		worker.foraging_task.state,
		ForagingTaskModel.State.SEEKING_FOOD,
		"the restored source is assigned again"
	)
	_expect_int(
		worker.foraging_task.target_food_source_id,
		source.entity_id,
		"reassignment keeps the stable source identity"
	)
	_expect_int(
		reassigned.colony.food_sources[0].reserved_by_worker_id,
		FIRST_WORKER_ID,
		"reassignment establishes exactly one reservation"
	)


func _test_return_pauses_for_invalid_path_and_nest_then_recovers() -> void:
	var simulation: ColonySimulation = _create_simulation()
	_place_sugar_on_tick_one(simulation)
	_advance_to_tick(simulation, _returning_tick())
	var state: ColonyState = simulation.get("_state") as ColonyState
	var worker_before: AntSnapshot = _find_worker(
		simulation.create_game_snapshot(),
		FIRST_WORKER_ID
	)
	_expect_int(
		worker_before.foraging_task.carried_portions,
		1,
		"the invalid-route fixture begins with one carried portion"
	)

	state.get_zone(ENTRANCE_ZONE_ID).available = false
	var frozen_elapsed: int = worker_before.foraging_task.elapsed_ticks
	for pause_tick: int in range(
		_returning_tick() + 1,
		_returning_tick() + 6
	):
		_expect_true(
			simulation.advance_tick(pause_tick),
			"an unavailable route does not reject the fixed Tick"
		)
		var paused: GameSnapshot = simulation.create_game_snapshot()
		var paused_worker: AntSnapshot = _find_worker(
			paused,
			FIRST_WORKER_ID
		)
		_expect_int(
			paused_worker.foraging_task.elapsed_ticks,
			frozen_elapsed,
			"return elapsed time freezes while no valid path exists"
		)
		_expect_int(
			paused_worker.foraging_task.carried_portions,
			1,
			"the worker retains unique carried ownership while pathfinding waits"
		)
		_expect_string(
			_get_foraging_invariant_failure(
				paused,
				FORAGING_SCENARIO_DATA.sugar_portions
			),
			"",
			"the paused route preserves public ownership and conservation"
		)

	state.get_zone(ENTRANCE_ZONE_ID).available = true
	var resume_tick: int = _returning_tick() + 6
	_expect_true(
		simulation.advance_tick(resume_tick),
		"restoring the route resumes the return task"
	)
	var resumed: GameSnapshot = simulation.create_game_snapshot()
	_expect_int(
		_find_worker(resumed, FIRST_WORKER_ID)
			.foraging_task.elapsed_ticks,
		frozen_elapsed + 1,
		"return elapsed time advances exactly once after route restoration"
	)

	state.get_zone(NEST_ZONE_ID).available = false
	_expect_true(
		simulation.advance_tick(resume_tick + 1),
		"an unavailable nest does not reject the fixed Tick"
	)
	var nest_paused: GameSnapshot = simulation.create_game_snapshot()
	_expect_int(
		_find_worker(nest_paused, FIRST_WORKER_ID)
			.foraging_task.elapsed_ticks,
		frozen_elapsed + 1,
		"return elapsed time freezes while the nest is unavailable"
	)
	_expect_int(
		_find_worker(nest_paused, FIRST_WORKER_ID)
			.foraging_task.carried_portions,
		1,
		"nest unavailability cannot discard the carried portion"
	)
	_expect_true(
		simulation.has_valid_habitat_ownership(),
		"nest unavailability preserves authoritative ownership"
	)

	state.get_zone(NEST_ZONE_ID).available = true
	_advance_until_card(simulation, resume_tick + 500)
	var completed: GameSnapshot = simulation.create_game_snapshot()
	_expect_true(
		completed.observations.has_card(OBSERVATION_CARD_ID),
		"restoring the nest lets the carried portion finish sharing"
	)
	_expect_string(
		_get_foraging_invariant_failure(
			completed,
			FORAGING_SCENARIO_DATA.sugar_portions
		),
		"",
		"recovery completes without leaking ownership"
	)


func _test_game_snapshot_is_a_deep_copy() -> void:
	var simulation: ColonySimulation = _create_simulation()
	_place_sugar_on_tick_one(simulation)
	_advance_to_tick(
		simulation,
		1 + FORAGING_SCENARIO_DATA.foraging_data.discovery_delay_ticks
	)
	var original: GameSnapshot = simulation.create_game_snapshot()
	var canonical_before: String = (
		SimulationSnapshotSignature.canonical_game_snapshot(original)
	)

	original.simulation_tick = 99_999
	original.scenario.phase = ForagingScenarioSnapshot.Phase.COMPLETED
	original.scenario.place_action_available = true
	original.scenario.placement_zone_id = NEST_ZONE_ID
	original.colony.food_sources[0].remaining_portions = 999
	original.colony.food_sources[0].available = false
	original.colony.food_sources[0].reserved_by_worker_id = 999
	var worker: AntSnapshot = _find_worker(original, FIRST_WORKER_ID)
	worker.zone_id = FORAGING_ZONE_ID
	worker.foraging_task.state = ForagingTaskModel.State.SHARING
	worker.foraging_task.carried_portions = 999
	worker.foraging_task.route_zone_ids.clear()
	original.colony.zones[0].available = false
	original.colony.zones[0].connected_zone_ids.clear()
	original.observations.events[0].event_id = 999
	original.observations.events[0].actor_entity_id = 999
	original.observations.unlocked_card_ids.append(&"fake_card")

	var fresh: GameSnapshot = simulation.create_game_snapshot()
	_expect_string(
		SimulationSnapshotSignature.canonical_game_snapshot(fresh),
		canonical_before,
		"mutating every nested snapshot domain cannot change simulation state"
	)
	_expect_int(
		fresh.colony.food_sources[0].remaining_portions,
		FORAGING_SCENARIO_DATA.sugar_portions,
		"snapshot source mutation does not change the authoritative amount"
	)
	_expect_int(
		_find_worker(fresh, FIRST_WORKER_ID).foraging_task.carried_portions,
		0,
		"snapshot task mutation does not create authoritative carried sugar"
	)
	_expect_true(
		not fresh.observations.has_card(&"fake_card"),
		"snapshot journal mutation cannot unlock an authoritative card"
	)


func _test_speed_multipliers_match_at_the_same_tick() -> void:
	var target_tick: int = _completion_tick()
	var normal: Dictionary = _run_with_clock_speed(
		SimulationClock.NORMAL_SPEED,
		target_tick
	)
	var fast: Dictionary = _run_with_clock_speed(
		SimulationClock.FAST_SPEED,
		target_tick
	)
	var very_fast: Dictionary = _run_with_clock_speed(
		SimulationClock.VERY_FAST_SPEED,
		target_tick
	)

	_expect_int(
		int(normal["tick"]),
		target_tick,
		"1x reaches the requested fixed Tick"
	)
	_expect_int(
		int(fast["tick"]),
		target_tick,
		"4x reaches the same requested fixed Tick"
	)
	_expect_int(
		int(very_fast["tick"]),
		target_tick,
		"16x reaches the same requested fixed Tick"
	)
	_expect_string(
		String(fast["signature"]),
		String(normal["signature"]),
		"4x produces the same game snapshot as 1x at the same Tick"
	)
	_expect_string(
		String(very_fast["signature"]),
		String(normal["signature"]),
		"16x produces the same game snapshot as 1x at the same Tick"
	)


func _test_structured_events_are_complete_unique_and_ordered() -> void:
	var simulation: ColonySimulation = _create_simulation()
	_place_sugar_on_tick_one(simulation)
	_advance_to_tick(simulation, _completion_tick())
	var events: Array[ObservationEvent] = (
		simulation.create_game_snapshot().observations.events
	)
	var expected_types: Array[int] = [
		ObservationEvent.Type.FOOD_SEEK_STARTED,
		ObservationEvent.Type.FOOD_TRAVEL_STARTED,
		ObservationEvent.Type.SUGAR_COLLECTED,
		ObservationEvent.Type.SUGAR_RETURN_STARTED,
		ObservationEvent.Type.SUGAR_SHARED,
		ObservationEvent.Type.SUGAR_OBSERVATION_COMPLETED,
	]
	var expected_ticks: Array[int] = [
		1,
		1 + FORAGING_SCENARIO_DATA.foraging_data.discovery_delay_ticks,
		_returning_tick(),
		_returning_tick(),
		_completion_tick(),
		_completion_tick(),
	]
	_expect_int(
		events.size(),
		expected_types.size(),
		"the complete cycle retains every required structured event"
	)

	var seen_ids: Dictionary[int, bool] = {}
	for event_index: int in expected_types.size():
		var event: ObservationEvent = events[event_index]
		_expect_int(
			event.event_id,
			event_index + 1,
			"foraging event IDs are gap-free and monotonic"
		)
		_expect_true(
			not seen_ids.has(event.event_id),
			"foraging event IDs are unique"
		)
		seen_ids[event.event_id] = true
		_expect_int(
			event.event_type,
			expected_types[event_index],
			"foraging event types preserve transition order"
		)
		_expect_int(
			event.tick,
			expected_ticks[event_index],
			"foraging events use exact Resource-derived Tick boundaries"
		)
		if (
			event.event_type
			!= ObservationEvent.Type.SUGAR_OBSERVATION_COMPLETED
		):
			_expect_int(
				event.actor_entity_id,
				FIRST_WORKER_ID,
				"worker events preserve the deterministic actor ID"
			)
			_expect_int(
				event.subject_entity_id,
				FIRST_FOOD_SOURCE_ID,
				"worker events preserve the stable food-source ID"
			)

	var event_signature: String = (
		SimulationSnapshotSignature.canonical_event_history(events)
	)
	_advance_to_tick(simulation, _completion_tick() + 100)
	_expect_string(
		SimulationSnapshotSignature.canonical_event_history(
			simulation.create_game_snapshot().observations.events
		),
		event_signature,
		"post-completion Ticks neither duplicate nor lose foraging events"
	)


func _test_restart_clears_foraging_session_state() -> void:
	var simulation: ColonySimulation = _create_simulation()
	_place_sugar_on_tick_one(simulation)
	_advance_to_tick(simulation, _completion_tick())
	_expect_true(
		simulation.restart_session(),
		"restart succeeds after one complete foraging cycle"
	)
	var first_restart: GameSnapshot = simulation.create_game_snapshot()
	_expect_restart_snapshot(first_restart, "first restart")

	_place_sugar_on_tick_one(simulation)
	_expect_int(
		simulation.create_game_snapshot().colony.food_sources[0]
			.food_source_id,
		FIRST_FOOD_SOURCE_ID,
		"restart resets the stable source ID allocator for a new session"
	)
	_expect_true(
		simulation.restart_session(),
		"a second consecutive restart also succeeds"
	)
	_expect_restart_snapshot(
		simulation.create_game_snapshot(),
		"second restart"
	)


func _test_ten_thousand_tick_soak() -> void:
	var simulation: ColonySimulation = _create_simulation()
	_expect_true(
		simulation.submit_place_sugar_action(),
		"the soak submits one configured sugar action"
	)
	var first_failure: String = ""
	for tick_index: int in range(1, SOAK_TICK_COUNT + 1):
		if not simulation.advance_tick(tick_index):
			first_failure = (
				"simulation rejected Tick %d: %s"
				% [tick_index, simulation.get_configuration_error()]
			)
			break
		if not simulation.has_valid_habitat_ownership():
			first_failure = "authoritative ownership failed at Tick %d" % tick_index
			break
		var invariant_failure: String = _get_foraging_invariant_failure(
			simulation.create_game_snapshot(),
			FORAGING_SCENARIO_DATA.sugar_portions
		)
		if not invariant_failure.is_empty():
			first_failure = "Tick %d: %s" % [
				tick_index,
				invariant_failure,
			]
			break

	_expect_string(
		first_failure,
		"",
		"10,000 fixed Ticks complete without invalid ownership or amounts"
	)
	var final_snapshot: GameSnapshot = simulation.create_game_snapshot()
	_expect_int(
		final_snapshot.simulation_tick,
		SOAK_TICK_COUNT,
		"the soak reaches exactly 10,000 fixed Ticks"
	)
	_expect_true(
		final_snapshot.observations.has_card(OBSERVATION_CARD_ID),
		"the soak does not leave the finite foraging task stuck"
	)
	_expect_int(
		_count_events(
			final_snapshot.observations.events,
			ObservationEvent.Type.SUGAR_SHARED
		),
		FORAGING_SCENARIO_DATA.sugar_portions,
		"the soak shares each configured portion exactly once"
	)


func _create_simulation() -> ColonySimulation:
	var simulation: ColonySimulation = ColonySimulation.new(
		SPECIES_A_DATA,
		FORAGING_SCENARIO_DATA
	)
	_expect_true(
		simulation.is_ready(),
		"the canonical foraging Resources initialize the simulation"
	)
	return simulation


func _duplicate_foraging_scenario() -> HabitatScenarioData:
	var duplicate: HabitatScenarioData = (
		FORAGING_SCENARIO_DATA.duplicate(true) as HabitatScenarioData
	)
	var duplicated_zones: Array[HabitatZoneData] = []
	for source_zone: HabitatZoneData in FORAGING_SCENARIO_DATA.zones:
		duplicated_zones.append(
			source_zone.duplicate(true) as HabitatZoneData
		)
	duplicate.zones = duplicated_zones
	duplicate.foraging_data = (
		FORAGING_SCENARIO_DATA.foraging_data.duplicate(true) as ForagingData
	)
	return duplicate


func _find_zone_data(
	scenario: HabitatScenarioData,
	zone_id: StringName
) -> HabitatZoneData:
	for zone_data: HabitatZoneData in scenario.zones:
		if zone_data != null and zone_data.zone_id == zone_id:
			return zone_data
	return null


func _place_sugar_on_tick_one(simulation: ColonySimulation) -> void:
	_expect_true(
		simulation.submit_place_sugar_action(),
		"the configured sugar action is accepted at Tick zero"
	)
	_expect_true(
		simulation.advance_tick(1),
		"the configured sugar action applies at Tick one"
	)


func _advance_to_tick(
	simulation: ColonySimulation,
	target_tick: int
) -> bool:
	var next_tick: int = (
		simulation.create_game_snapshot().simulation_tick + 1
	)
	while next_tick <= target_tick:
		if not simulation.advance_tick(next_tick):
			_record_failure(
				"sequential foraging Tick is accepted",
				"true",
				"false at Tick %d: %s"
				% [next_tick, simulation.get_configuration_error()]
			)
			return false
		next_tick += 1
	return true


func _advance_until_card(
	simulation: ColonySimulation,
	maximum_tick: int
) -> bool:
	var snapshot: GameSnapshot = simulation.create_game_snapshot()
	while (
		not snapshot.observations.has_card(OBSERVATION_CARD_ID)
		and snapshot.simulation_tick < maximum_tick
	):
		if not simulation.advance_tick(snapshot.simulation_tick + 1):
			_record_failure(
				"foraging recovery reaches the observation card",
				"a sequential Tick",
				"rejected Tick %d"
				% (snapshot.simulation_tick + 1)
			)
			return false
		snapshot = simulation.create_game_snapshot()
	if snapshot.observations.has_card(OBSERVATION_CARD_ID):
		return true
	_record_failure(
		"foraging recovery reaches the observation card",
		"unlocked by Tick %d" % maximum_tick,
		"still locked"
	)
	return false


func _find_worker(
	snapshot: GameSnapshot,
	worker_id: int
) -> AntSnapshot:
	if snapshot == null or snapshot.colony == null:
		return null
	for ant: AntSnapshot in snapshot.colony.ants:
		if (
			ant.entity_id == worker_id
			and ant.life_stage == AntModel.LifeStage.WORKER
		):
			return ant
	return null


func _expect_task(
	worker: AntSnapshot,
	expected_state: int,
	expected_elapsed: int,
	expected_duration: int,
	boundary_name: String
) -> void:
	_expect_true(
		worker != null and worker.foraging_task != null,
		"%s exposes a worker foraging task" % boundary_name
	)
	if worker == null or worker.foraging_task == null:
		return
	_expect_int(
		worker.foraging_task.state,
		expected_state,
		"%s uses the expected task state" % boundary_name
	)
	_expect_int(
		worker.foraging_task.elapsed_ticks,
		expected_elapsed,
		"%s uses the exact elapsed Tick" % boundary_name
	)
	_expect_int(
		worker.foraging_task.duration_ticks,
		expected_duration,
		"%s uses the Resource-derived duration" % boundary_name
	)


func _returning_tick() -> int:
	var data: ForagingData = FORAGING_SCENARIO_DATA.foraging_data
	return (
		1
		+ data.discovery_delay_ticks
		+ data.outbound_travel_duration_ticks
		+ data.collection_duration_ticks
	)


func _completion_tick() -> int:
	var data: ForagingData = FORAGING_SCENARIO_DATA.foraging_data
	return (
		_returning_tick()
		+ data.return_travel_duration_ticks
		+ data.sharing_duration_ticks
	)


func _get_foraging_invariant_failure(
	snapshot: GameSnapshot,
	expected_total_portions: int
) -> String:
	if snapshot == null or snapshot.colony == null:
		return "game snapshot is missing its colony domain"

	var active_workers_by_source: Dictionary[int, int] = {}
	var carrying_workers_by_source: Dictionary[int, int] = {}
	var carried_portions: int = 0
	for ant: AntSnapshot in snapshot.colony.ants:
		if ant.life_stage != AntModel.LifeStage.WORKER:
			continue
		var task: ForagingTaskSnapshot = ant.foraging_task
		if task == null:
			return "worker %d has no foraging task snapshot" % ant.entity_id
		if task.state == ForagingTaskModel.State.IDLE:
			if (
				task.target_food_source_id != NO_ENTITY_ID
				or task.carried_portions != 0
				or task.elapsed_ticks != 0
				or task.duration_ticks != 0
				or not task.route_zone_ids.is_empty()
			):
				return "idle worker %d retains task state" % ant.entity_id
			continue
		if active_workers_by_source.has(task.target_food_source_id):
			return "source %d has multiple active workers" % (
				task.target_food_source_id
			)
		active_workers_by_source[task.target_food_source_id] = ant.entity_id
		if task.carried_portions < 0 or task.carried_portions > 1:
			return "worker %d has an invalid carried amount" % ant.entity_id
		if task.carried_portions == 1:
			if carrying_workers_by_source.has(task.target_food_source_id):
				return "source %d has multiple carrying workers" % (
					task.target_food_source_id
				)
			carrying_workers_by_source[
				task.target_food_source_id
			] = ant.entity_id
			carried_portions += 1

	var remaining_portions: int = 0
	var known_source_ids: Dictionary[int, bool] = {}
	for source: FoodSourceSnapshot in snapshot.colony.food_sources:
		if known_source_ids.has(source.food_source_id):
			return "source %d appears more than once" % source.food_source_id
		known_source_ids[source.food_source_id] = true
		if (
			source.remaining_portions < 0
			or is_nan(float(source.remaining_portions))
			or is_inf(float(source.remaining_portions))
		):
			return "source %d has an invalid amount" % source.food_source_id
		remaining_portions += source.remaining_portions
		var expected_reserver: int = active_workers_by_source.get(
			source.food_source_id,
			NO_ENTITY_ID
		)
		if source.reserved_by_worker_id != expected_reserver:
			return "source %d reservation disagrees with worker task" % (
				source.food_source_id
			)
		var expected_carrier: int = carrying_workers_by_source.get(
			source.food_source_id,
			NO_ENTITY_ID
		)
		if source.carrier_worker_id != expected_carrier:
			return "source %d carrier disagrees with worker task" % (
				source.food_source_id
			)
	for claimed_source_id: int in active_workers_by_source:
		if not known_source_ids.has(claimed_source_id):
			return "worker task targets missing source %d" % claimed_source_id

	var shared_portions: int = _count_events(
		snapshot.observations.events,
		ObservationEvent.Type.SUGAR_SHARED
	)
	if (
		remaining_portions + carried_portions + shared_portions
		!= expected_total_portions
	):
		return (
			"sugar conservation is %d remaining + %d carried + %d shared != %d"
			% [
				remaining_portions,
				carried_portions,
				shared_portions,
				expected_total_portions,
			]
		)
	return ""


func _count_events(
	events: Array[ObservationEvent],
	event_type: int
) -> int:
	var count: int = 0
	for event: ObservationEvent in events:
		if event != null and event.event_type == event_type:
			count += 1
	return count


func _run_with_clock_speed(
	speed_multiplier: int,
	target_tick: int
) -> Dictionary:
	var simulation: ColonySimulation = ColonySimulation.new(
		SPECIES_A_DATA,
		FORAGING_SCENARIO_DATA
	)
	var clock: SimulationClock = SimulationClock.new()
	clock.tick_requested.connect(
		func(tick_index: int, _tick_seconds: float) -> void:
			simulation.advance_tick(tick_index)
	)
	simulation.submit_place_sugar_action()
	clock.set_speed_multiplier(speed_multiplier)
	var real_seconds: float = (
		float(target_tick)
		* SimulationClock.FIXED_STEP_SECONDS
		/ float(speed_multiplier)
	)
	clock.advance(real_seconds)
	while clock.get_backlog_tick_count() > 0:
		clock.advance(0.0)
	var snapshot: GameSnapshot = simulation.create_game_snapshot()
	return {
		"tick": snapshot.simulation_tick,
		"signature": (
			SimulationSnapshotSignature.canonical_game_snapshot(snapshot)
		),
	}


func _expect_restart_snapshot(
	snapshot: GameSnapshot,
	context: String
) -> void:
	_expect_int(
		snapshot.simulation_tick,
		0,
		"%s resets the fixed Tick" % context
	)
	_expect_int(
		snapshot.colony.food_sources.size(),
		0,
		"%s removes the prior food source" % context
	)
	_expect_int(
		snapshot.observations.events.size(),
		0,
		"%s clears the prior event journal" % context
	)
	_expect_int(
		snapshot.observations.unlocked_card_ids.size(),
		0,
		"%s clears the prior observation cards" % context
	)
	_expect_true(
		snapshot.scenario.place_action_available,
		"%s restores placement availability" % context
	)
	_expect_true(
		not snapshot.scenario.place_action_pending,
		"%s clears queued placement commands" % context
	)
	_expect_int(
		snapshot.scenario.phase,
		ForagingScenarioSnapshot.Phase.AWAITING_PLACEMENT,
		"%s restores the initial scenario phase" % context
	)
	for ant: AntSnapshot in snapshot.colony.ants:
		_expect_int(
			ant.foraging_task.state,
			ForagingTaskModel.State.IDLE,
			"%s restores every worker to an idle foraging task" % context
		)


func _expect_int(actual: int, expected: int, message: String) -> void:
	_assertion_count += 1
	if actual == expected:
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


func _expect_string_name(
	actual: StringName,
	expected: StringName,
	message: String
) -> void:
	_assertion_count += 1
	if actual == expected:
		return
	_record_failure(message, String(expected), String(actual))


func _record_failure(
	message: String,
	expected: String,
	actual: String
) -> void:
	_failure_count += 1
	printerr("  %s — expected %s, got %s" % [message, expected, actual])
