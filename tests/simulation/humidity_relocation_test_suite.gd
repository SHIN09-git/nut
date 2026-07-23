class_name HumidityRelocationTestSuite
extends RefCounted

const SPECIES_A_DATA: SpeciesData = preload("res://data/species/species_a.tres")
const HUMIDITY_SCENARIO_DATA: HabitatScenarioData = preload(
	"res://data/habitats/humidity_relocation_slice.tres"
)
const LEFT_ZONE_ID: StringName = &"left_chamber"
const RIGHT_ZONE_ID: StringName = &"right_chamber"
const NO_ENTITY_ID: int = -1
const SOAK_TICK_COUNT: int = 10_000
const NO_OSCILLATION_TICK_COUNT: int = 1_000
const MIN_CORE_LOOP_SECONDS: float = 60.0
const MAX_CORE_LOOP_SECONDS: float = 120.0

var _assertion_count: int = 0
var _failure_count: int = 0


func run() -> int:
	_test_invalid_behavior_configuration_is_rejected()
	_test_humidity_is_clamped_and_non_finite_commands_are_rejected()
	_test_water_action_gate_and_habitat_lifecycle_semantics()
	_test_command_is_applied_at_the_start_of_the_next_tick()
	_test_rejected_tick_preserves_pending_commands()
	_test_only_one_water_action_can_be_pending()
	_test_matching_inputs_and_commands_are_deterministic()
	_test_water_action_uses_frozen_configuration()
	_test_restart_clears_session_state_and_keeps_frozen_configuration()
	_test_unsuitable_brood_zone_creates_relocation_tasks()
	_test_no_meaningful_improvement_creates_no_task()
	_test_one_brood_cannot_be_reserved_by_two_workers()
	_test_pickup_removes_brood_from_its_zone()
	_test_carried_brood_has_exactly_one_carrier()
	_test_drop_assigns_target_zone_and_clears_task_ownership()
	_test_invalidated_target_clears_pre_pickup_reservations()
	_test_valid_carry_target_is_not_reconsidered_mid_route()
	_test_watering_causes_workers_to_reconsider_the_target_zone()
	_test_stable_environment_does_not_oscillate_for_one_thousand_ticks()
	_test_snapshot_mutation_cannot_change_internal_state()
	_test_observation_unlocks_after_configured_stability_window()
	_test_first_visible_carry_and_full_slice_pacing()
	_test_ten_thousand_tick_soak_preserves_finite_valid_ownership()
	return _failure_count


func get_assertion_count() -> int:
	return _assertion_count


func get_failure_count() -> int:
	return _failure_count


func _test_invalid_behavior_configuration_is_rejected() -> void:
	_expect_true(
		not SpeciesData.new().is_valid(),
		"a bare SpeciesData Resource has no implicit prototype pacing"
	)
	_expect_true(
		not HabitatScenarioData.new().is_valid(),
		"a bare habitat Resource has no implicit scenario state"
	)

	var zero_improvement_species: SpeciesData = (
		SPECIES_A_DATA.duplicate(true) as SpeciesData
	)
	zero_improvement_species.relocation_min_improvement = 0.0
	var invalid_simulation: ColonySimulation = ColonySimulation.new(
		zero_improvement_species,
		HUMIDITY_SCENARIO_DATA
	)
	_expect_true(
		not invalid_simulation.is_ready(),
		"a zero-improvement relocation configuration is rejected"
	)


func _test_humidity_is_clamped_and_non_finite_commands_are_rejected() -> void:
	var connections: Array[StringName] = []
	var zone: HabitatZoneState = HabitatZoneState.new(
		&"clamp_fixture",
		0.5,
		connections,
		true
	)

	_expect_true(
		zone.apply_humidity_adjustment(10.0),
		"a finite positive humidity command is accepted"
	)
	_expect_float(
		zone.humidity,
		1.0,
		"humidity is clamped to one"
	)

	_expect_true(
		zone.apply_humidity_adjustment(-10.0),
		"a finite negative humidity adjustment is accepted"
	)
	_expect_float(
		zone.humidity,
		0.0,
		"humidity is clamped to zero"
	)

	_expect_true(
		not zone.apply_humidity_adjustment(NAN),
		"a NaN humidity command is rejected"
	)
	_expect_true(
		not zone.apply_humidity_adjustment(INF),
		"an infinite humidity command is rejected"
	)
	_expect_float(
		zone.humidity,
		0.0,
		"rejected non-finite commands cannot change humidity"
	)
	_expect_true(
		zone.humidity >= 0.0 and zone.humidity <= 1.0,
		"the zone remains within the authoritative humidity bounds"
	)


func _test_water_action_gate_and_habitat_lifecycle_semantics() -> void:
	var simulation: ColonySimulation = _create_simulation()
	var initial_snapshot: ColonySnapshot = simulation.create_snapshot()
	_expect_true(
		not initial_snapshot.lifecycle_active,
		"the pre-populated humidity scenario marks lifecycle production as inactive"
	)
	_expect_int(
		initial_snapshot.queen_laid_egg_count,
		0,
		"scenario brood is not reported as queen-laid lifecycle brood"
	)
	_expect_int(
		initial_snapshot.max_first_generation_brood,
		0,
		"the habitat snapshot does not expose a lifecycle-only brood cap"
	)
	_expect_int(
		initial_snapshot.next_egg_tick,
		-1,
		"the habitat snapshot has no lifecycle egg schedule"
	)
	_expect_true(
		not initial_snapshot.water_action_unlocked
		and not initial_snapshot.water_action_available,
		"watering remains locked before the first successful brood drop"
	)
	_expect_true(
		not simulation.submit_water_action(),
		"the simulation rejects watering before the authoritative unlock"
	)

	var unlocked_snapshot: ColonySnapshot = _advance_until_water_action_available(
		simulation
	)
	_expect_true(
		unlocked_snapshot.water_action_unlocked,
		"the first successful brood drop unlocks watering"
	)
	_expect_true(
		unlocked_snapshot.water_action_available,
		"the snapshot exposes the unlocked and still-needed water action"
	)
	_expect_true(
		not unlocked_snapshot.water_action_pending,
		"unlocking does not implicitly enqueue an action"
	)
	_expect_int(
		unlocked_snapshot.water_action_count,
		0,
		"unlocking does not count as player intervention"
	)


func _test_command_is_applied_at_the_start_of_the_next_tick() -> void:
	var simulation: ColonySimulation = _create_simulation()
	var before_submission: ColonySnapshot = _advance_until_water_action_available(
		simulation
	)
	var initial_humidity: float = _zone_humidity(before_submission, LEFT_ZONE_ID)
	var amount: float = HUMIDITY_SCENARIO_DATA.humidity_adjustment_amount

	_expect_true(
		simulation.submit_water_action(),
		"the scenario watering command is submitted"
	)
	var after_submission: ColonySnapshot = simulation.create_snapshot()
	_expect_float(
		_zone_humidity(after_submission, LEFT_ZONE_ID),
		initial_humidity,
		"submitting a command does not immediately mutate humidity"
	)
	_expect_int(
		after_submission.water_action_count,
		0,
		"a queued command is not counted before a Tick applies it"
	)
	_expect_true(
		after_submission.water_action_pending,
		"a submitted command is immediately visible as pending in the snapshot"
	)
	_expect_true(
		not after_submission.water_action_available,
		"the player cannot queue another action while one is pending"
	)

	_expect_true(
		simulation.advance_tick(before_submission.simulation_tick + 1),
		"the first humidity command Tick advances"
	)
	var after_tick: ColonySnapshot = simulation.create_snapshot()
	_expect_float(
		_zone_humidity(after_tick, LEFT_ZONE_ID),
		clampf(initial_humidity + amount, 0.0, 1.0),
		"the queued command applies at the start of the next Tick"
	)
	_expect_int(
		after_tick.water_action_count,
		1,
		"the applied command is counted once"
	)
	_expect_true(
		not after_tick.water_action_pending,
		"the pending flag clears after the next fixed Tick applies the command"
	)
	_expect_int(
		after_tick.humidity_adjustment_count,
		after_tick.water_action_count,
		"the legacy diagnostic count mirrors the authoritative water action count"
	)


func _test_rejected_tick_preserves_pending_commands() -> void:
	var simulation: ColonySimulation = _create_simulation()
	var initial_snapshot: ColonySnapshot = _advance_until_water_action_available(
		simulation
	)
	var initial_humidity: float = _zone_humidity(initial_snapshot, LEFT_ZONE_ID)
	var amount: float = HUMIDITY_SCENARIO_DATA.humidity_adjustment_amount

	_expect_true(
		simulation.submit_water_action(),
		"the command-preservation fixture queues one humidity adjustment"
	)
	_expect_true(
		not simulation.advance_tick(initial_snapshot.simulation_tick + 2),
		"a non-sequential Tick is rejected before consuming commands"
	)
	var after_rejection: ColonySnapshot = simulation.create_snapshot()
	_expect_int(
		after_rejection.simulation_tick,
		initial_snapshot.simulation_tick,
		"a rejected Tick leaves simulation time unchanged"
	)
	_expect_float(
		_zone_humidity(after_rejection, LEFT_ZONE_ID),
		initial_humidity,
		"a rejected Tick leaves queued humidity unapplied"
	)
	_expect_int(
		after_rejection.water_action_count,
		0,
		"a rejected Tick does not count the queued adjustment"
	)
	_expect_true(
		after_rejection.water_action_pending,
		"a rejected Tick preserves the pending water action"
	)

	_expect_true(
		simulation.advance_tick(initial_snapshot.simulation_tick + 1),
		"the next valid Tick still accepts the preserved command"
	)
	var after_valid_tick: ColonySnapshot = simulation.create_snapshot()
	_expect_float(
		_zone_humidity(after_valid_tick, LEFT_ZONE_ID),
		clampf(initial_humidity + amount, 0.0, 1.0),
		"the preserved command applies on the next valid Tick"
	)
	_expect_int(
		after_valid_tick.water_action_count,
		1,
		"the preserved command is applied exactly once"
	)


func _test_only_one_water_action_can_be_pending() -> void:
	var simulation: ColonySimulation = _create_simulation()
	var available_snapshot: ColonySnapshot = _advance_until_water_action_available(
		simulation
	)

	_expect_true(
		simulation.submit_water_action(),
		"the available high-level action can be queued"
	)
	_expect_true(
		not simulation.submit_water_action(),
		"a second high-level action is rejected while the first is pending"
	)
	_expect_true(
		simulation.advance_tick(available_snapshot.simulation_tick + 1),
		"the single pending action applies on the next fixed Tick"
	)
	var snapshot: ColonySnapshot = simulation.create_snapshot()
	_expect_int(
		snapshot.water_action_count,
		1,
		"the rejected duplicate never becomes an applied action"
	)


func _test_matching_inputs_and_commands_are_deterministic() -> void:
	var first_simulation: ColonySimulation = _create_simulation()
	var second_simulation: ColonySimulation = _create_simulation()
	var target_tick: int = 2_500
	var submitted_action_count: int = 0

	var tick: int = 1
	while tick <= target_tick:
		if (
			submitted_action_count < _get_watering_action_count_to_reach_comfort()
			and first_simulation.create_snapshot().water_action_available
		):
			_expect_true(
				first_simulation.submit_water_action(),
				"the first deterministic command sequence is accepted"
			)
			_expect_true(
				second_simulation.submit_water_action(),
				"the second deterministic command sequence is accepted"
			)
			submitted_action_count += 1
		if not first_simulation.advance_tick(tick):
			_record_failure(
				"the first deterministic simulation advances",
				"true",
				"false at Tick %d" % tick
			)
			return
		if not second_simulation.advance_tick(tick):
			_record_failure(
				"the second deterministic simulation advances",
				"true",
				"false at Tick %d" % tick
			)
			return
		tick += 1

	_expect_string(
		_create_snapshot_signature(first_simulation.create_snapshot()),
		_create_snapshot_signature(second_simulation.create_snapshot()),
		"matching initial state and humidity command sequence produce the same snapshot"
	)


func _test_water_action_uses_frozen_configuration() -> void:
	var species: SpeciesData = SPECIES_A_DATA.duplicate(true) as SpeciesData
	var scenario: HabitatScenarioData = _duplicate_scenario()
	var simulation: ColonySimulation = ColonySimulation.new(species, scenario)
	var available_snapshot: ColonySnapshot = _advance_until_water_action_available(
		simulation
	)
	var original_left_humidity: float = _zone_humidity(
		available_snapshot,
		LEFT_ZONE_ID
	)
	var original_right_humidity: float = _zone_humidity(
		available_snapshot,
		RIGHT_ZONE_ID
	)
	var frozen_amount: float = scenario.humidity_adjustment_amount

	scenario.humidity_adjustment_zone_id = RIGHT_ZONE_ID
	scenario.humidity_adjustment_amount = 0.4
	species.brood_humidity_min = 0.95
	species.brood_humidity_max = 1.0

	var after_source_mutation: ColonySnapshot = simulation.create_snapshot()
	_expect_true(
		after_source_mutation.water_action_available,
		"mutating source Resources does not change the frozen UI availability state"
	)
	_expect_true(
		not after_source_mutation.water_target_comfortable,
		"the comfort decision continues using the frozen species range"
	)
	_expect_true(
		simulation.submit_water_action(),
		"the frozen high-level water action remains available"
	)
	_expect_true(
		simulation.advance_tick(after_source_mutation.simulation_tick + 1),
		"the frozen water action applies on the next Tick"
	)
	var after_first_action: ColonySnapshot = simulation.create_snapshot()
	_expect_float(
		_zone_humidity(after_first_action, LEFT_ZONE_ID),
		clampf(original_left_humidity + frozen_amount, 0.0, 1.0),
		"the frozen target and amount change the original left chamber"
	)
	_expect_float(
		_zone_humidity(after_first_action, RIGHT_ZONE_ID),
		original_right_humidity,
		"mutating the source target cannot redirect the queued action"
	)

	var required_action_count: int = _get_watering_action_count_to_reach_comfort()
	while simulation.create_snapshot().water_action_count < required_action_count:
		_expect_true(
			simulation.submit_water_action(),
			"the frozen fixture accepts the next configured water action"
		)
		var before_tick: ColonySnapshot = simulation.create_snapshot()
		_expect_true(
			simulation.advance_tick(before_tick.simulation_tick + 1),
			"the next frozen water action Tick advances"
		)
	var comfortable_snapshot: ColonySnapshot = simulation.create_snapshot()
	_expect_true(
		comfortable_snapshot.water_target_comfortable,
		"the target becomes comfortable according to the frozen comfort range"
	)
	_expect_true(
		not comfortable_snapshot.water_action_available,
		"the frozen comfort result disables further water actions"
	)


func _test_restart_clears_session_state_and_keeps_frozen_configuration() -> void:
	var species: SpeciesData = SPECIES_A_DATA.duplicate(true) as SpeciesData
	var scenario: HabitatScenarioData = _duplicate_scenario()
	var simulation: ColonySimulation = ColonySimulation.new(species, scenario)
	var initial_snapshot: ColonySnapshot = simulation.create_snapshot()
	var initial_left_humidity: float = _zone_humidity(initial_snapshot, LEFT_ZONE_ID)
	var initial_right_humidity: float = _zone_humidity(initial_snapshot, RIGHT_ZONE_ID)
	var frozen_amount: float = scenario.humidity_adjustment_amount
	var expected_ant_count: int = (
		scenario.initial_worker_count + scenario.initial_brood_count
	)

	_advance_until_water_action_available(simulation)
	_expect_true(
		simulation.submit_water_action(),
		"restart fixture queues one unapplied high-level water action"
	)
	_expect_true(
		simulation.create_snapshot().water_action_pending,
		"restart fixture contains pending input before reset"
	)

	scenario.left_zone.initial_humidity = 0.90
	scenario.right_zone.initial_humidity = 0.10
	scenario.initial_worker_count = 1
	scenario.initial_brood_count = 1
	scenario.initial_worker_zone_id = RIGHT_ZONE_ID
	scenario.initial_brood_zone_id = RIGHT_ZONE_ID
	scenario.humidity_adjustment_zone_id = RIGHT_ZONE_ID
	scenario.humidity_adjustment_amount = 0.40
	scenario.observation_stable_ticks = 1
	species.brood_humidity_min = 0.90
	species.brood_humidity_max = 0.95
	species.decision_interval_ticks = 1

	_expect_true(
		simulation.restart_session(),
		"humidity simulation restarts from its internally frozen configuration"
	)
	var restarted_snapshot: ColonySnapshot = simulation.create_snapshot()
	_expect_int(restarted_snapshot.simulation_tick, 0, "humidity restart returns to Tick zero")
	_expect_int(
		restarted_snapshot.ants.size(),
		expected_ant_count,
		"humidity restart restores the frozen initial entity count"
	)
	_expect_float(
		_zone_humidity(restarted_snapshot, LEFT_ZONE_ID),
		initial_left_humidity,
		"humidity restart restores the frozen left chamber"
	)
	_expect_float(
		_zone_humidity(restarted_snapshot, RIGHT_ZONE_ID),
		initial_right_humidity,
		"humidity restart restores the frozen right chamber"
	)
	_expect_true(
		not restarted_snapshot.water_action_unlocked,
		"humidity restart closes the first-drop gate"
	)
	_expect_true(
		not restarted_snapshot.water_action_pending,
		"humidity restart discards pending commands from the old session"
	)
	_expect_int(
		restarted_snapshot.water_action_count,
		0,
		"humidity restart clears the applied water count"
	)
	_expect_int(
		restarted_snapshot.observation_stable_ticks,
		0,
		"humidity restart clears observation stability progress"
	)
	_expect_true(
		not restarted_snapshot.brood_humidity_observation_unlocked,
		"humidity restart clears the completed observation"
	)
	_expect_true(
		simulation.has_valid_habitat_ownership(),
		"humidity restart preserves initial ownership invariants"
	)

	_expect_true(
		simulation.advance_tick(1),
		"the restarted simulation accepts its first sequential Tick"
	)
	var after_first_tick: ColonySnapshot = simulation.create_snapshot()
	_expect_float(
		_zone_humidity(after_first_tick, LEFT_ZONE_ID),
		initial_left_humidity,
		"the old pending water action does not leak into the restarted session"
	)
	_expect_int(
		after_first_tick.water_action_count,
		0,
		"the restarted first Tick applies no stale command"
	)

	var available_again: ColonySnapshot = _advance_until_water_action_available(
		simulation
	)
	_expect_true(
		simulation.submit_water_action(),
		"the restarted session unlocks the same frozen high-level action"
	)
	_expect_true(
		simulation.advance_tick(available_again.simulation_tick + 1),
		"the restarted water action applies on its next Tick"
	)
	var restarted_action_snapshot: ColonySnapshot = simulation.create_snapshot()
	_expect_float(
		_zone_humidity(restarted_action_snapshot, LEFT_ZONE_ID),
		clampf(initial_left_humidity + frozen_amount, 0.0, 1.0),
		"restart keeps the frozen water target and amount"
	)
	_expect_float(
		_zone_humidity(restarted_action_snapshot, RIGHT_ZONE_ID),
		initial_right_humidity,
		"restart ignores the mutated source water target"
	)
	_expect_true(
		not restarted_action_snapshot.water_target_comfortable,
		"restart keeps the frozen brood comfort range"
	)


func _test_unsuitable_brood_zone_creates_relocation_tasks() -> void:
	var simulation: ColonySimulation = _create_simulation()
	var first_active_snapshot: ColonySnapshot = _advance_until(
		simulation,
		func(snapshot: ColonySnapshot) -> bool:
			return snapshot.count_active_relocations() > 0,
		SPECIES_A_DATA.decision_interval_ticks * 2,
		"an unsuitable brood zone creates a relocation task"
	)

	_expect_true(
		first_active_snapshot.count_active_relocations() > 0,
		"at least one worker starts a relocation"
	)
	for ant: AntSnapshot in first_active_snapshot.ants:
		if ant.worker_task_state == WorkerTaskModel.State.IDLE:
			continue
		_expect_true(
			ant.target_brood_id >= 0,
			"an active worker has a target brood ID"
		)
		_expect_string_name(
			ant.target_zone_id,
			RIGHT_ZONE_ID,
			"the initially drier brood is targeted toward the more suitable right chamber"
		)


func _test_no_meaningful_improvement_creates_no_task() -> void:
	var scenario: HabitatScenarioData = _duplicate_scenario()
	scenario.left_zone.initial_humidity = 0.50
	scenario.right_zone.initial_humidity = 0.55
	var simulation: ColonySimulation = ColonySimulation.new(SPECIES_A_DATA, scenario)
	_advance_to_tick(simulation, SPECIES_A_DATA.decision_interval_ticks * 3)
	var snapshot: ColonySnapshot = simulation.create_snapshot()

	_expect_int(
		snapshot.count_active_relocations(),
		0,
		"workers do not relocate brood when improvement is below the configured threshold"
	)
	_expect_true(
		_all_brood_unreserved_and_uncarried(snapshot),
		"a rejected relocation leaves no reservations"
	)


func _test_one_brood_cannot_be_reserved_by_two_workers() -> void:
	var simulation: ColonySimulation = _create_simulation()
	var snapshot: ColonySnapshot = _advance_until(
		simulation,
		func(candidate: ColonySnapshot) -> bool:
			return candidate.count_active_relocations() > 1,
		SPECIES_A_DATA.decision_interval_ticks * 2,
		"multiple workers receive deterministic relocation work"
	)
	var reservation_counts: Dictionary[int, int] = {}

	for worker: AntSnapshot in snapshot.ants:
		if worker.worker_task_state == WorkerTaskModel.State.IDLE:
			continue
		var brood_id: int = worker.target_brood_id
		reservation_counts[brood_id] = reservation_counts.get(brood_id, 0) + 1
		var brood: AntSnapshot = snapshot.find_ant(brood_id)
		_expect_true(brood != null, "a reserved brood ID resolves in the snapshot")
		if brood != null:
			_expect_int(
				brood.reserved_by_ant_id,
				worker.entity_id,
				"the brood reservation points back to its worker"
			)

	for brood_id: int in reservation_counts:
		_expect_int(
			reservation_counts[brood_id],
			1,
			"one brood is reserved by at most one worker"
		)


func _test_pickup_removes_brood_from_its_zone() -> void:
	var simulation: ColonySimulation = _create_simulation()
	var carrying_snapshot: ColonySnapshot = _advance_until_first_carried_brood(
		simulation,
		_get_first_carry_deadline_tick()
	)
	var worker: AntSnapshot = _find_first_carrying_worker(carrying_snapshot)

	_expect_true(worker != null, "a worker reaches the carrying phase")
	if worker == null:
		return
	var brood: AntSnapshot = carrying_snapshot.find_ant(worker.carried_brood_id)
	_expect_true(brood != null, "the carried brood remains a stable snapshot entity")
	if brood == null:
		return
	_expect_true(
		brood.zone_id.is_empty(),
		"picked-up brood no longer belongs to a habitat zone"
	)
	_expect_int(
		brood.carrier_ant_id,
		worker.entity_id,
		"picked-up brood identifies its carrying worker"
	)


func _test_carried_brood_has_exactly_one_carrier() -> void:
	var simulation: ColonySimulation = _create_simulation()
	var snapshot: ColonySnapshot = _advance_until_first_carried_brood(
		simulation,
		_get_first_carry_deadline_tick()
	)

	for brood: AntSnapshot in snapshot.ants:
		if brood.life_stage == AntModel.LifeStage.WORKER:
			continue
		var carrier_count: int = 0
		for worker: AntSnapshot in snapshot.ants:
			if worker.carried_brood_id == brood.entity_id:
				carrier_count += 1
		if brood.carrier_ant_id >= 0:
			_expect_int(
				carrier_count,
				1,
				"carried brood belongs to exactly one worker"
			)
		else:
			_expect_int(
				carrier_count,
				0,
				"uncarried brood is not referenced as worker cargo"
			)


func _test_drop_assigns_target_zone_and_clears_task_ownership() -> void:
	var simulation: ColonySimulation = _create_simulation()
	var carrying_snapshot: ColonySnapshot = _advance_until_first_carried_brood(
		simulation,
		_get_first_carry_deadline_tick()
	)
	var carrying_worker: AntSnapshot = _find_first_carrying_worker(carrying_snapshot)
	_expect_true(carrying_worker != null, "the drop fixture reaches a carrying worker")
	if carrying_worker == null:
		return

	var worker_id: int = carrying_worker.entity_id
	var brood_id: int = carrying_worker.carried_brood_id
	var target_zone_id: StringName = carrying_worker.target_zone_id
	var maximum_tick: int = (
		carrying_snapshot.simulation_tick
		+ SPECIES_A_DATA.travel_duration_ticks
		+ SPECIES_A_DATA.drop_duration_ticks
		+ 4
	)
	var dropped_snapshot: ColonySnapshot = _advance_until(
		simulation,
		func(snapshot: ColonySnapshot) -> bool:
			var brood: AntSnapshot = snapshot.find_ant(brood_id)
			return (
				brood != null
				and brood.zone_id == target_zone_id
				and brood.carrier_ant_id == NO_ENTITY_ID
			),
		maximum_tick,
		"carried brood is dropped in its target zone"
	)
	var dropped_brood: AntSnapshot = dropped_snapshot.find_ant(brood_id)
	var dropped_worker: AntSnapshot = dropped_snapshot.find_ant(worker_id)

	_expect_true(dropped_brood != null, "the dropped brood keeps its stable entity ID")
	_expect_true(dropped_worker != null, "the worker keeps its stable entity ID after dropping")
	if dropped_brood == null or dropped_worker == null:
		return
	_expect_string_name(
		dropped_brood.zone_id,
		target_zone_id,
		"dropped brood belongs to the relocation target zone"
	)
	_expect_int(
		dropped_brood.reserved_by_ant_id,
		NO_ENTITY_ID,
		"dropping clears the brood reservation"
	)
	_expect_int(
		dropped_brood.carrier_ant_id,
		NO_ENTITY_ID,
		"dropping clears the brood carrier"
	)
	_expect_int(
		dropped_worker.worker_task_state,
		WorkerTaskModel.State.IDLE,
		"dropping returns the worker to idle"
	)
	_expect_int(dropped_worker.target_brood_id, NO_ENTITY_ID, "dropping clears the task target")
	_expect_int(dropped_worker.carried_brood_id, NO_ENTITY_ID, "dropping clears worker cargo")
	_expect_true(dropped_worker.target_zone_id.is_empty(), "dropping clears the task zone")


func _test_invalidated_target_clears_pre_pickup_reservations() -> void:
	var scenario: HabitatScenarioData = _duplicate_scenario()
	scenario.humidity_adjustment_amount = 0.30
	var simulation: ColonySimulation = ColonySimulation.new(SPECIES_A_DATA, scenario)
	var unlocked_snapshot: ColonySnapshot = _advance_until_water_action_available(
		simulation
	)
	var reserved_snapshot: ColonySnapshot = _advance_until(
		simulation,
		func(snapshot: ColonySnapshot) -> bool:
			return (
				snapshot.water_action_available
				and snapshot.count_active_relocations() > 0
				and _has_active_target_zone(snapshot, RIGHT_ZONE_ID)
			),
		unlocked_snapshot.simulation_tick
		+ SPECIES_A_DATA.decision_interval_ticks * 2,
		"workers reserve the next brood wave before target invalidation"
	)
	_expect_true(
		reserved_snapshot.count_active_relocations() > 0,
		"the invalidation fixture starts with active reservations"
	)

	_expect_true(
		simulation.submit_water_action(),
		"watering can make the current brood zone comfortable"
	)
	_expect_true(
		simulation.advance_tick(reserved_snapshot.simulation_tick + 1),
		"the target-invalidating command Tick advances"
	)
	var cancelled_snapshot: ColonySnapshot = simulation.create_snapshot()
	_expect_int(
		cancelled_snapshot.count_active_relocations(),
		0,
		"pre-pickup tasks are cancelled when their target is no longer an improvement"
	)
	_expect_true(
		_all_brood_unreserved_and_uncarried(cancelled_snapshot),
		"cancelled tasks leave no permanent brood reservations"
	)


func _test_valid_carry_target_is_not_reconsidered_mid_route() -> void:
	var simulation: ColonySimulation = _create_simulation()
	var unlocked_snapshot: ColonySnapshot = _advance_until_water_action_available(
		simulation
	)
	var carrying_snapshot: ColonySnapshot = _advance_until(
		simulation,
		func(snapshot: ColonySnapshot) -> bool:
			return _find_carrying_worker_targeting(snapshot, RIGHT_ZONE_ID) != null,
		unlocked_snapshot.simulation_tick
		+ SPECIES_A_DATA.decision_interval_ticks
		+ SPECIES_A_DATA.travel_duration_ticks
		+ SPECIES_A_DATA.pickup_duration_ticks
		+ 4,
		"a second-wave worker carries brood toward the still-valid right chamber"
	)
	var carrying_worker: AntSnapshot = _find_carrying_worker_targeting(
		carrying_snapshot,
		RIGHT_ZONE_ID
	)
	_expect_true(
		carrying_worker != null,
		"the delayed-watering fixture reaches a right-bound carrying task"
	)
	if carrying_worker == null:
		return

	var worker_id: int = carrying_worker.entity_id
	var brood_id: int = carrying_worker.carried_brood_id
	var action_count: int = _get_watering_action_count_to_reach_comfort()
	for action_index: int in action_count:
		_expect_true(
			simulation.submit_water_action(),
			"delayed watering action %d is submitted through the high-level command"
			% (action_index + 1)
		)
		var before_tick: ColonySnapshot = simulation.create_snapshot()
		_expect_true(
			simulation.advance_tick(before_tick.simulation_tick + 1),
			"delayed watering action %d applies on the next Tick"
			% (action_index + 1)
		)
		var after_tick: ColonySnapshot = simulation.create_snapshot()
		var worker_after_water: AntSnapshot = after_tick.find_ant(worker_id)
		var brood_after_water: AntSnapshot = after_tick.find_ant(brood_id)
		_expect_true(
			worker_after_water != null,
			"the carrying worker keeps its stable ID after delayed watering"
		)
		_expect_true(
			brood_after_water != null,
			"the carried brood keeps its stable ID after delayed watering"
		)
		if worker_after_water == null or brood_after_water == null:
			return
		_expect_int(
			worker_after_water.worker_task_state,
			WorkerTaskModel.State.CARRYING_TO_ZONE,
			"watering does not restart or reverse an already valid carrying task"
		)
		_expect_string_name(
			worker_after_water.target_zone_id,
			RIGHT_ZONE_ID,
			"watering preserves the valid carrying destination"
		)
		_expect_int(
			worker_after_water.carried_brood_id,
			brood_id,
			"watering preserves the worker's current cargo"
		)
		_expect_int(
			brood_after_water.carrier_ant_id,
			worker_id,
			"watering preserves the carried brood's single owner"
		)

	var dropped_snapshot: ColonySnapshot = _advance_until(
		simulation,
		func(snapshot: ColonySnapshot) -> bool:
			var brood: AntSnapshot = snapshot.find_ant(brood_id)
			return (
				brood != null
				and brood.zone_id == RIGHT_ZONE_ID
				and brood.carrier_ant_id == NO_ENTITY_ID
			),
		carrying_snapshot.simulation_tick
		+ SPECIES_A_DATA.travel_duration_ticks
		+ SPECIES_A_DATA.drop_duration_ticks
		+ action_count
		+ 4,
		"the valid carrying task finishes at its original destination"
	)
	var dropped_brood: AntSnapshot = dropped_snapshot.find_ant(brood_id)
	_expect_true(
		dropped_brood != null
		and dropped_brood.zone_id == RIGHT_ZONE_ID
		and dropped_brood.carrier_ant_id == NO_ENTITY_ID,
		"delayed watering only affects a later idle decision"
	)


func _test_watering_causes_workers_to_reconsider_the_target_zone() -> void:
	var simulation: ColonySimulation = _create_simulation()
	var all_right_snapshot: ColonySnapshot = _advance_until(
		simulation,
		func(snapshot: ColonySnapshot) -> bool:
			return (
				_all_brood_in_zone(snapshot, RIGHT_ZONE_ID)
				and snapshot.count_active_relocations() == 0
			),
		_get_initial_relocation_deadline_tick(),
		"all brood first settle in the initially better right chamber"
	)
	_expect_true(
		_all_brood_in_zone(all_right_snapshot, RIGHT_ZONE_ID),
		"the re-evaluation fixture starts with brood in the right chamber"
	)

	_apply_scenario_watering_actions(
		simulation,
		_get_watering_action_count_to_reach_comfort()
	)
	var target_left_snapshot: ColonySnapshot = _advance_until(
		simulation,
		func(snapshot: ColonySnapshot) -> bool:
			return _has_active_target_zone(snapshot, LEFT_ZONE_ID),
		_get_return_relocation_deadline_tick(all_right_snapshot.simulation_tick),
		"workers reconsider brood placement after the player waters the left chamber"
	)
	_expect_true(
		_has_active_target_zone(target_left_snapshot, LEFT_ZONE_ID),
		"at least one worker changes its relocation target to the watered chamber"
	)


func _test_stable_environment_does_not_oscillate_for_one_thousand_ticks() -> void:
	var simulation: ColonySimulation = _create_simulation()
	var stable_snapshot: ColonySnapshot = _reach_comfortable_stable_state(simulation)
	var brood_zone_signature: String = _create_brood_zone_signature(stable_snapshot)
	var target_tick: int = stable_snapshot.simulation_tick + NO_OSCILLATION_TICK_COUNT
	_advance_to_tick(simulation, target_tick)
	var after_soak: ColonySnapshot = simulation.create_snapshot()

	_expect_int(
		after_soak.count_active_relocations(),
		0,
		"a stable environment creates no relocation during the 1,000 Tick window"
	)
	_expect_string(
		_create_brood_zone_signature(after_soak),
		brood_zone_signature,
		"brood do not oscillate between chambers during 1,000 stable Ticks"
	)


func _test_snapshot_mutation_cannot_change_internal_state() -> void:
	var simulation: ColonySimulation = _create_simulation()
	_advance_to_tick(simulation, SPECIES_A_DATA.decision_interval_ticks)
	var mutable_snapshot: ColonySnapshot = simulation.create_snapshot()
	var original_signature: String = _create_snapshot_signature(mutable_snapshot)
	var mutable_zone: HabitatZoneSnapshot = mutable_snapshot.find_zone(LEFT_ZONE_ID)
	var mutable_ant: AntSnapshot = mutable_snapshot.ants[0] if not mutable_snapshot.ants.is_empty() else null

	_expect_true(mutable_zone != null, "the snapshot isolation fixture exposes a copied zone")
	_expect_true(mutable_ant != null, "the snapshot isolation fixture exposes copied ants")
	if mutable_zone == null or mutable_ant == null:
		return
	mutable_zone.humidity = 0.99
	mutable_zone.available = false
	mutable_zone.connected_zone_ids.clear()
	mutable_ant.zone_id = &"mutated_zone"
	mutable_ant.reserved_by_ant_id = 999
	mutable_ant.carrier_ant_id = 999
	mutable_ant.worker_task_state = WorkerTaskModel.State.DROPPING
	mutable_ant.task_origin_zone_id = &"mutated_origin"
	mutable_ant.target_brood_id = 999
	mutable_ant.target_zone_id = &"mutated_target"
	mutable_ant.carried_brood_id = 999
	mutable_ant.task_elapsed_ticks = 999
	mutable_ant.task_duration_ticks = 999
	mutable_snapshot.humidity_adjustment_count = 999
	mutable_snapshot.lifecycle_active = true
	mutable_snapshot.water_action_unlocked = false
	mutable_snapshot.water_action_available = false
	mutable_snapshot.water_action_pending = true
	mutable_snapshot.water_action_count = 999
	mutable_snapshot.water_target_comfortable = true
	mutable_snapshot.observation_stable_ticks = 999
	mutable_snapshot.brood_humidity_observation_unlocked = true
	mutable_snapshot.zones.clear()
	mutable_snapshot.ants.clear()

	var fresh_snapshot: ColonySnapshot = simulation.create_snapshot()
	_expect_string(
		_create_snapshot_signature(fresh_snapshot),
		original_signature,
		"mutating snapshot zones, tasks, brood ownership and arrays cannot change simulation state"
	)


func _test_observation_unlocks_after_configured_stability_window() -> void:
	var simulation: ColonySimulation = _create_simulation()
	var watering_action_count: int = _get_watering_action_count_to_reach_comfort()
	var first_stable_snapshot: ColonySnapshot = _reach_comfortable_stable_state(simulation)
	_expect_true(
		_all_brood_comfortable(first_stable_snapshot),
		"all brood occupy comfortable humidity before observation unlock"
	)
	_expect_int(
		first_stable_snapshot.count_active_relocations(),
		0,
		"no relocation remains active in the stable observation state"
	)
	_expect_int(
		first_stable_snapshot.humidity_adjustment_count,
		watering_action_count,
		"the player has applied the Resource-derived watering action count"
	)

	if first_stable_snapshot.observation_stable_ticks < HUMIDITY_SCENARIO_DATA.observation_stable_ticks:
		var before_unlock_tick: int = (
			first_stable_snapshot.simulation_tick
			+ HUMIDITY_SCENARIO_DATA.observation_stable_ticks
			- first_stable_snapshot.observation_stable_ticks
			- 1
		)
		_advance_to_tick(simulation, before_unlock_tick)
		var before_unlock: ColonySnapshot = simulation.create_snapshot()
		_expect_true(
			not before_unlock.brood_humidity_observation_unlocked,
			"the observation remains locked one Tick before the stability requirement"
		)
		_expect_int(
			before_unlock.observation_stable_ticks,
			HUMIDITY_SCENARIO_DATA.observation_stable_ticks - 1,
			"the stable counter reaches the pre-unlock boundary"
		)
		_expect_true(
			simulation.advance_tick(before_unlock.simulation_tick + 1),
			"the observation-unlock Tick advances"
		)

	var unlocked_snapshot: ColonySnapshot = simulation.create_snapshot()
	_expect_true(
		unlocked_snapshot.brood_humidity_observation_unlocked,
		"the observation unlocks after the configured stable Tick count"
	)
	_expect_true(
		unlocked_snapshot.observation_stable_ticks
		>= HUMIDITY_SCENARIO_DATA.observation_stable_ticks,
		"the simulation owns the completed observation stability state"
	)


func _test_first_visible_carry_and_full_slice_pacing() -> void:
	var simulation: ColonySimulation = _create_simulation()
	var watering_action_count: int = _get_watering_action_count_to_reach_comfort()
	_expect_true(
		watering_action_count >= 1 and watering_action_count <= 4,
		"the current Resource fixture requires between one and four watering actions"
	)
	var first_carry_snapshot: ColonySnapshot = _advance_until_first_carried_brood(
		simulation,
		200
	)
	_expect_true(
		first_carry_snapshot.simulation_tick >= 100
		and first_carry_snapshot.simulation_tick <= 200,
		"the first visible carried brood occurs between 10 and 20 simulated seconds"
	)

	var all_right_snapshot: ColonySnapshot = _advance_until(
		simulation,
		func(snapshot: ColonySnapshot) -> bool:
			return (
				_all_brood_in_zone(snapshot, RIGHT_ZONE_ID)
				and snapshot.count_active_relocations() == 0
			),
		_get_initial_relocation_deadline_tick(),
		"the pacing fixture completes the initial relocation"
	)
	_apply_scenario_watering_actions(simulation, watering_action_count)
	var maximum_core_loop_tick: int = ceili(
		MAX_CORE_LOOP_SECONDS / SimulationClock.FIXED_STEP_SECONDS
	)
	var unlocked_snapshot: ColonySnapshot = _advance_until(
		simulation,
		func(snapshot: ColonySnapshot) -> bool:
			return snapshot.brood_humidity_observation_unlocked,
		maximum_core_loop_tick,
		"the humidity relocation slice unlocks within the playable prototype window"
	)
	var minimum_core_loop_tick: int = ceili(
		MIN_CORE_LOOP_SECONDS / SimulationClock.FIXED_STEP_SECONDS
	)
	_expect_true(
		unlocked_snapshot.simulation_tick >= minimum_core_loop_tick
		and unlocked_snapshot.simulation_tick <= maximum_core_loop_tick,
		"the configured slice completes in approximately sixty to one hundred twenty seconds"
	)


func _test_ten_thousand_tick_soak_preserves_finite_valid_ownership() -> void:
	var simulation: ColonySimulation = _create_simulation()
	var valid_soak: bool = true
	var failure_detail: String = ""
	var tick: int = 1
	while tick <= SOAK_TICK_COUNT:
		if not simulation.advance_tick(tick):
			valid_soak = false
			failure_detail = "advance_tick rejected Tick %d" % tick
			break
		var snapshot: ColonySnapshot = simulation.create_snapshot()
		failure_detail = _get_snapshot_invariant_failure(snapshot)
		if not failure_detail.is_empty():
			valid_soak = false
			failure_detail = "Tick %d: %s" % [tick, failure_detail]
			break
		tick += 1

	_expect_true_with_detail(
		valid_soak,
		"10,000 sequential Ticks preserve finite humidity and legal brood ownership",
		failure_detail
	)
	var final_snapshot: ColonySnapshot = simulation.create_snapshot()
	_expect_int(
		final_snapshot.simulation_tick,
		SOAK_TICK_COUNT,
		"the humidity relocation soak reaches Tick 10,000"
	)
	_expect_int(
		final_snapshot.count_active_relocations(),
		0,
		"the soak leaves no permanently stuck relocation task"
	)


func _create_simulation() -> ColonySimulation:
	return ColonySimulation.new(SPECIES_A_DATA, HUMIDITY_SCENARIO_DATA)


func _duplicate_scenario() -> HabitatScenarioData:
	var scenario: HabitatScenarioData = HUMIDITY_SCENARIO_DATA.duplicate(true) as HabitatScenarioData
	if scenario.left_zone == HUMIDITY_SCENARIO_DATA.left_zone:
		scenario.left_zone = HUMIDITY_SCENARIO_DATA.left_zone.duplicate(true) as HabitatZoneData
	if scenario.right_zone == HUMIDITY_SCENARIO_DATA.right_zone:
		scenario.right_zone = HUMIDITY_SCENARIO_DATA.right_zone.duplicate(true) as HabitatZoneData
	return scenario


func _advance_to_tick(simulation: ColonySimulation, target_tick: int) -> bool:
	var next_tick: int = simulation.create_snapshot().simulation_tick + 1
	while next_tick <= target_tick:
		if not simulation.advance_tick(next_tick):
			_record_failure(
				"sequential humidity simulation Tick is accepted",
				"true",
				"false at Tick %d" % next_tick
			)
			return false
		next_tick += 1
	return true


func _advance_until(
	simulation: ColonySimulation,
	predicate: Callable,
	maximum_tick: int,
	failure_message: String
) -> ColonySnapshot:
	var snapshot: ColonySnapshot = simulation.create_snapshot()
	if bool(predicate.call(snapshot)):
		return snapshot
	while snapshot.simulation_tick < maximum_tick:
		if not simulation.advance_tick(snapshot.simulation_tick + 1):
			_record_failure(
				failure_message,
				"a matching snapshot by Tick %d" % maximum_tick,
				"advance_tick rejected Tick %d" % (snapshot.simulation_tick + 1)
			)
			return simulation.create_snapshot()
		snapshot = simulation.create_snapshot()
		if bool(predicate.call(snapshot)):
			return snapshot

	_record_failure(
		failure_message,
		"a matching snapshot by Tick %d" % maximum_tick,
		"none found"
	)
	return snapshot


func _advance_until_first_carried_brood(
	simulation: ColonySimulation,
	maximum_tick: int
) -> ColonySnapshot:
	return _advance_until(
		simulation,
		func(snapshot: ColonySnapshot) -> bool:
			return _find_first_carrying_worker(snapshot) != null,
		maximum_tick,
		"a worker visibly carries brood before the pacing deadline"
	)


func _advance_until_water_action_available(
	simulation: ColonySimulation
) -> ColonySnapshot:
	return _advance_until(
		simulation,
		func(snapshot: ColonySnapshot) -> bool:
			return snapshot.water_action_available,
		_get_initial_relocation_deadline_tick(),
		"the first successful brood drop unlocks the water action"
	)


func _reach_comfortable_stable_state(
	simulation: ColonySimulation
) -> ColonySnapshot:
	var all_right_snapshot: ColonySnapshot = _advance_until(
		simulation,
		func(snapshot: ColonySnapshot) -> bool:
			return (
				_all_brood_in_zone(snapshot, RIGHT_ZONE_ID)
				and snapshot.count_active_relocations() == 0
			),
		_get_initial_relocation_deadline_tick(),
		"all brood settle in the initially better chamber"
	)
	_apply_scenario_watering_actions(
		simulation,
		_get_watering_action_count_to_reach_comfort()
	)
	return _advance_until(
		simulation,
		func(snapshot: ColonySnapshot) -> bool:
			return (
				_all_brood_comfortable(snapshot)
				and snapshot.count_active_relocations() == 0
			),
		_get_return_relocation_deadline_tick(all_right_snapshot.simulation_tick),
		"watering eventually produces a comfortable stable brood placement"
	)


func _apply_scenario_watering_actions(
	simulation: ColonySimulation,
	action_count: int
) -> void:
	var action_index: int = 0
	while action_index < action_count:
		_expect_true(
			simulation.submit_water_action(),
			"a configured player watering action is submitted"
		)
		var pending_snapshot: ColonySnapshot = simulation.create_snapshot()
		_expect_true(
			simulation.advance_tick(pending_snapshot.simulation_tick + 1),
			"a configured player watering action applies on the next Tick"
		)
		action_index += 1


func _get_watering_action_count_to_reach_comfort() -> int:
	var adjustment_zone: HabitatZoneData
	for zone: HabitatZoneData in [
		HUMIDITY_SCENARIO_DATA.left_zone,
		HUMIDITY_SCENARIO_DATA.right_zone,
	]:
		if zone.zone_id == HUMIDITY_SCENARIO_DATA.humidity_adjustment_zone_id:
			adjustment_zone = zone
			break
	if adjustment_zone == null:
		return 0

	var humidity_gap: float = maxf(
		SPECIES_A_DATA.brood_humidity_min - adjustment_zone.initial_humidity,
		0.0
	)
	if humidity_gap <= 0.0:
		return 0
	return ceili(
		(humidity_gap - 0.000001)
		/ HUMIDITY_SCENARIO_DATA.humidity_adjustment_amount
	)


func _get_first_carry_deadline_tick() -> int:
	return (
		SPECIES_A_DATA.decision_interval_ticks
		+ SPECIES_A_DATA.travel_duration_ticks
		+ SPECIES_A_DATA.pickup_duration_ticks
		+ 4
	)


func _get_initial_relocation_deadline_tick() -> int:
	var relocation_wave_ticks: int = (
		SPECIES_A_DATA.travel_duration_ticks * 2
		+ SPECIES_A_DATA.pickup_duration_ticks
		+ SPECIES_A_DATA.drop_duration_ticks
		+ SPECIES_A_DATA.decision_interval_ticks
		+ 8
	)
	var wave_count: int = ceili(
		float(HUMIDITY_SCENARIO_DATA.initial_brood_count)
		/ float(HUMIDITY_SCENARIO_DATA.initial_worker_count)
	)
	return relocation_wave_ticks * wave_count + SPECIES_A_DATA.decision_interval_ticks


func _get_return_relocation_deadline_tick(start_tick: int) -> int:
	return (
		start_tick
		+ SPECIES_A_DATA.minimum_zone_dwell_ticks
		+ _get_initial_relocation_deadline_tick()
		+ HUMIDITY_SCENARIO_DATA.observation_stable_ticks
	)


func _find_first_carrying_worker(snapshot: ColonySnapshot) -> AntSnapshot:
	for ant: AntSnapshot in snapshot.ants:
		if (
			ant.worker_task_state == WorkerTaskModel.State.CARRYING_TO_ZONE
			or ant.worker_task_state == WorkerTaskModel.State.DROPPING
		):
			return ant
	return null


func _find_carrying_worker_targeting(
	snapshot: ColonySnapshot,
	target_zone_id: StringName
) -> AntSnapshot:
	for ant: AntSnapshot in snapshot.ants:
		if (
			ant.worker_task_state == WorkerTaskModel.State.CARRYING_TO_ZONE
			and ant.target_zone_id == target_zone_id
		):
			return ant
	return null


func _all_brood_in_zone(snapshot: ColonySnapshot, zone_id: StringName) -> bool:
	var brood_count: int = 0
	for ant: AntSnapshot in snapshot.ants:
		if ant.life_stage == AntModel.LifeStage.WORKER:
			continue
		brood_count += 1
		if ant.zone_id != zone_id or ant.carrier_ant_id != NO_ENTITY_ID:
			return false
	return brood_count > 0


func _all_brood_comfortable(snapshot: ColonySnapshot) -> bool:
	var brood_count: int = 0
	for ant: AntSnapshot in snapshot.ants:
		if ant.life_stage == AntModel.LifeStage.WORKER:
			continue
		brood_count += 1
		if ant.zone_id.is_empty() or ant.carrier_ant_id != NO_ENTITY_ID:
			return false
		var zone: HabitatZoneSnapshot = snapshot.find_zone(ant.zone_id)
		if (
			zone == null
			or zone.humidity < SPECIES_A_DATA.brood_humidity_min
			or zone.humidity > SPECIES_A_DATA.brood_humidity_max
		):
			return false
	return brood_count > 0


func _all_brood_unreserved_and_uncarried(snapshot: ColonySnapshot) -> bool:
	for ant: AntSnapshot in snapshot.ants:
		if ant.life_stage == AntModel.LifeStage.WORKER:
			continue
		if (
			ant.reserved_by_ant_id != NO_ENTITY_ID
			or ant.carrier_ant_id != NO_ENTITY_ID
		):
			return false
	return true


func _has_active_target_zone(
	snapshot: ColonySnapshot,
	target_zone_id: StringName
) -> bool:
	for ant: AntSnapshot in snapshot.ants:
		if (
			ant.worker_task_state != WorkerTaskModel.State.IDLE
			and ant.target_zone_id == target_zone_id
		):
			return true
	return false


func _zone_humidity(snapshot: ColonySnapshot, zone_id: StringName) -> float:
	var zone: HabitatZoneSnapshot = snapshot.find_zone(zone_id)
	if zone == null:
		_record_failure("snapshot contains the requested habitat zone", str(zone_id), "missing")
		return -1.0
	return zone.humidity


func _create_snapshot_signature(snapshot: ColonySnapshot) -> String:
	var parts: PackedStringArray = [
		str(snapshot.simulation_tick),
		str(snapshot.lifecycle_active),
		str(snapshot.queen_laid_egg_count),
		str(snapshot.max_first_generation_brood),
		str(snapshot.next_egg_tick),
		str(snapshot.humidity_adjustment_count),
		str(snapshot.water_action_unlocked),
		str(snapshot.water_action_available),
		str(snapshot.water_action_pending),
		str(snapshot.water_action_count),
		str(snapshot.water_target_comfortable),
		str(snapshot.observation_stable_ticks),
		str(snapshot.brood_humidity_observation_unlocked),
	]
	for zone: HabitatZoneSnapshot in snapshot.zones:
		var connection_names: PackedStringArray = []
		for connected_zone_id: StringName in zone.connected_zone_ids:
			connection_names.append(String(connected_zone_id))
		parts.append(
			"zone:%s:%.9f:%s:%s"
			% [
				String(zone.zone_id),
				zone.humidity,
				str(zone.available),
				",".join(connection_names),
			]
		)
	for ant: AntSnapshot in snapshot.ants:
		parts.append(
			"ant:%d:%d:%d:%d:%s:%d:%d:%d:%s:%d:%s:%d:%d:%d"
			% [
				ant.entity_id,
				ant.life_stage,
				ant.total_age_ticks,
				ant.stage_age_ticks,
				String(ant.zone_id),
				ant.reserved_by_ant_id,
				ant.carrier_ant_id,
				ant.worker_task_state,
				String(ant.task_origin_zone_id),
				ant.target_brood_id,
				String(ant.target_zone_id),
				ant.carried_brood_id,
				ant.task_elapsed_ticks,
				ant.task_duration_ticks,
			]
		)
	return "|".join(parts)


func _create_brood_zone_signature(snapshot: ColonySnapshot) -> String:
	var parts: PackedStringArray = []
	for ant: AntSnapshot in snapshot.ants:
		if ant.life_stage != AntModel.LifeStage.WORKER:
			parts.append("%d:%s" % [ant.entity_id, String(ant.zone_id)])
	return "|".join(parts)


func _get_snapshot_invariant_failure(snapshot: ColonySnapshot) -> String:
	var known_zone_ids: Dictionary[StringName, bool] = {}
	for zone: HabitatZoneSnapshot in snapshot.zones:
		if is_nan(zone.humidity) or is_inf(zone.humidity):
			return "zone %s has non-finite humidity" % String(zone.zone_id)
		if zone.humidity < 0.0 or zone.humidity > 1.0:
			return "zone %s humidity is outside 0..1" % String(zone.zone_id)
		known_zone_ids[zone.zone_id] = true

	var reservation_counts: Dictionary[int, int] = {}
	var carrier_counts: Dictionary[int, int] = {}
	for worker: AntSnapshot in snapshot.ants:
		if worker.life_stage != AntModel.LifeStage.WORKER:
			continue
		if not known_zone_ids.has(worker.zone_id):
			return "worker %d has no valid zone" % worker.entity_id
		if worker.worker_task_state == WorkerTaskModel.State.IDLE:
			if (
				worker.target_brood_id != NO_ENTITY_ID
				or worker.carried_brood_id != NO_ENTITY_ID
				or not worker.target_zone_id.is_empty()
			):
				return "idle worker %d retains task ownership" % worker.entity_id
			continue
		if worker.target_brood_id < 0:
			return "active worker %d has no target brood" % worker.entity_id
		reservation_counts[worker.target_brood_id] = (
			reservation_counts.get(worker.target_brood_id, 0) + 1
		)
		if worker.carried_brood_id >= 0:
			carrier_counts[worker.carried_brood_id] = (
				carrier_counts.get(worker.carried_brood_id, 0) + 1
			)

	for brood: AntSnapshot in snapshot.ants:
		if brood.life_stage == AntModel.LifeStage.WORKER:
			continue
		var reservation_count: int = reservation_counts.get(brood.entity_id, 0)
		var carrier_count: int = carrier_counts.get(brood.entity_id, 0)
		if reservation_count > 1:
			return "brood %d has multiple reservations" % brood.entity_id
		if carrier_count > 1:
			return "brood %d has multiple carriers" % brood.entity_id
		if carrier_count == 1:
			if not brood.zone_id.is_empty():
				return "carried brood %d still belongs to a zone" % brood.entity_id
			if brood.carrier_ant_id < 0:
				return "carried brood %d has no carrier relation" % brood.entity_id
		else:
			if brood.zone_id.is_empty() or not known_zone_ids.has(brood.zone_id):
				return "uncarried brood %d does not belong to one zone" % brood.entity_id
			if brood.carrier_ant_id != NO_ENTITY_ID:
				return "uncarried brood %d retains a carrier relation" % brood.entity_id
		if reservation_count == 0 and brood.reserved_by_ant_id != NO_ENTITY_ID:
			return "brood %d retains an orphan reservation" % brood.entity_id
		if (
			reservation_count == 1
			and carrier_count == 0
			and brood.reserved_by_ant_id == NO_ENTITY_ID
		):
			return "brood %d is targeted without a reservation relation" % brood.entity_id
	return ""


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


func _expect_true_with_detail(
	actual: bool,
	message: String,
	detail: String
) -> void:
	_assertion_count += 1
	if actual:
		return
	_record_failure(message, "true", detail if not detail.is_empty() else "false")


func _expect_string(actual: String, expected: String, message: String) -> void:
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


func _record_failure(message: String, expected: String, actual: String) -> void:
	_failure_count += 1
	printerr("  %s — expected %s, got %s" % [message, expected, actual])
