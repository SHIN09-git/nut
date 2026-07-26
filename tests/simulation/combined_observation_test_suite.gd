class_name CombinedObservationTestSuite
extends RefCounted

const SPECIES_A_DATA: SpeciesData = preload(
	"res://data/species/species_a.tres"
)
const COMBINED_SCENARIO_DATA: HabitatScenarioData = preload(
	"res://data/habitats/combined_observation_slice.tres"
)
const NO_ENTITY_ID: int = -1
const SOAK_TICK_COUNT: int = 10_000
const CLOCK_FRAME_DELTA_SECONDS: float = 0.2

var _assertion_count: int = 0
var _failure_count: int = 0


func run() -> void:
	_test_late_pupa_emerges_exactly_as_a_capable_worker()
	_test_commands_are_phase_gated_and_apply_on_the_next_legal_tick()
	_test_fixed_tick_phase_sequence_is_monotonic()
	_test_first_worker_id_and_three_cards_survive_every_phase()
	_test_matching_inputs_and_all_clock_speeds_are_deterministic()
	_test_combined_resource_rejects_projection_incompatible_layouts()
	_test_combined_configuration_is_frozen_across_restart()
	_test_relocation_and_foraging_ownership_remain_compatible()
	_test_restart_clears_every_combined_session_domain()
	_test_combined_game_snapshot_is_deeply_isolated()
	_test_completion_plus_ten_thousand_tick_soak()


func get_assertion_count() -> int:
	return _assertion_count


func get_failure_count() -> int:
	return _failure_count


func _test_late_pupa_emerges_exactly_as_a_capable_worker() -> void:
	var simulation: ColonySimulation = _create_simulation()
	var initial: GameSnapshot = simulation.create_game_snapshot()
	var first_worker_id: int = initial.sequence.first_worker_entity_id
	var initial_pupa: AntSnapshot = initial.colony.find_ant(first_worker_id)
	var emergence_tick: int = _get_first_worker_emergence_tick()
	var transitions: Array[Dictionary] = []
	simulation.life_stage_changed.connect(
		func(
			entity_id: int,
			previous_stage: AntModel.LifeStage,
			current_stage: AntModel.LifeStage,
			simulation_tick: int
		) -> void:
			transitions.append({
				"entity_id": entity_id,
				"previous_stage": previous_stage,
				"current_stage": current_stage,
				"tick": simulation_tick,
			})
	)

	_expect_true(initial.sequence != null, "combined snapshot exposes its sequence")
	if initial.sequence != null:
		_expect_string_name(
			initial.sequence.first_worker_observation_card_id,
			COMBINED_SCENARIO_DATA.sequence_data
				.first_worker_observation_card_id,
			"the snapshot exposes the frozen emergence-card ID"
		)
		_expect_string_name(
			initial.sequence.brood_humidity_observation_card_id,
			COMBINED_SCENARIO_DATA.sequence_data
				.brood_humidity_observation_card_id,
			"the snapshot exposes the frozen humidity-card ID"
		)
		_expect_string_name(
			initial.sequence.sugar_foraging_observation_card_id,
			COMBINED_SCENARIO_DATA.foraging_observation_card_id,
			"the snapshot exposes the frozen sugar-card ID"
		)
	_expect_int(
		initial.sequence.phase,
		ScenarioSequenceSnapshot.Phase.FOUNDING_PRELUDE,
		"the sequence begins in the founding prelude"
	)
	_expect_true(initial_pupa != null, "the configured first worker entity exists")
	if initial_pupa != null:
		_expect_int(
			initial_pupa.life_stage,
			AntModel.LifeStage.PUPA,
			"the first worker begins as a late pupa"
		)
		_expect_int(
			initial_pupa.stage_age_ticks,
			COMBINED_SCENARIO_DATA.sequence_data
				.first_worker_initial_pupa_age_ticks,
			"the late-pupa age comes from the sequence Resource"
		)
		_expect_string_name(
			initial_pupa.zone_id,
			COMBINED_SCENARIO_DATA.initial_brood_zone_id,
			"the late pupa initially belongs to the configured brood zone"
		)
		_expect_true(
			initial_pupa.foraging_task == null,
			"a pupa does not prematurely expose a foraging task"
		)

	_expect_true(
		_advance_to_tick(simulation, emergence_tick - 1),
		"the controlled lifecycle reaches the Tick before emergence"
	)
	var before_boundary: GameSnapshot = simulation.create_game_snapshot()
	var before_pupa: AntSnapshot = before_boundary.colony.find_ant(
		first_worker_id
	)
	_expect_true(before_pupa != null, "the same late pupa exists before the boundary")
	if before_pupa != null:
		_expect_int(
			before_pupa.life_stage,
			AntModel.LifeStage.PUPA,
			"the first worker remains a pupa before the exact boundary"
		)
		_expect_int(
			before_pupa.stage_age_ticks,
			SPECIES_A_DATA.pupa_duration_ticks - 1,
			"the pre-boundary pupa is exactly one Tick short of emergence"
		)
	_expect_int(
		before_boundary.sequence.phase,
		ScenarioSequenceSnapshot.Phase.FOUNDING_PRELUDE,
		"the prelude cannot advance before the lifecycle boundary"
	)
	_expect_true(
		not before_boundary.observations.has_card(
			COMBINED_SCENARIO_DATA.sequence_data
				.first_worker_observation_card_id
		),
		"the emergence card is locked before the boundary"
	)

	_expect_true(
		simulation.advance_tick(emergence_tick),
		"the exact emergence Tick is accepted"
	)
	var emerged: GameSnapshot = simulation.create_game_snapshot()
	var worker: AntSnapshot = emerged.colony.find_ant(first_worker_id)
	_expect_true(worker != null, "the same stable entity exists after emergence")
	if worker != null:
		_expect_int(
			worker.entity_id,
			first_worker_id,
			"pupa-to-worker conversion preserves the stable entity ID"
		)
		_expect_int(
			worker.life_stage,
			AntModel.LifeStage.WORKER,
			"the late pupa becomes a worker on the exact boundary"
		)
		_expect_int(
			worker.stage_age_ticks,
			0,
			"the worker stage age resets at emergence"
		)
		_expect_string_name(
			worker.zone_id,
			COMBINED_SCENARIO_DATA.initial_worker_zone_id,
			"the emerged worker receives the configured worker zone"
		)
		_expect_int(
			worker.worker_task_state,
			WorkerTaskModel.State.IDLE,
			"the emerged worker receives an idle relocation task"
		)
		_expect_int(
			worker.target_brood_id,
			NO_ENTITY_ID,
			"the emerged worker has no stale brood target"
		)
		_expect_true(
			worker.foraging_task != null,
			"the emerged worker receives a foraging task"
		)
		if worker.foraging_task != null:
			_expect_int(
				worker.foraging_task.state,
				ForagingTaskModel.State.IDLE,
				"the emerged worker's foraging task begins idle"
			)

	_expect_int(
		emerged.sequence.phase,
		ScenarioSequenceSnapshot.Phase.IDENTITY_OBSERVATION,
		"emergence advances to identity observation on the same fixed Tick"
	)
	_expect_int(
		emerged.sequence.phase_entered_tick,
		emergence_tick,
		"identity observation records the exact entry Tick"
	)
	_expect_int(
		emerged.sequence.first_worker_emerged_tick,
		emergence_tick,
		"the sequence records the exact emergence Tick"
	)
	_expect_true(
		emerged.sequence.continue_action_available,
		"the identity continue action becomes available after emergence"
	)
	_expect_true(
		emerged.observations.has_card(
			COMBINED_SCENARIO_DATA.sequence_data
				.first_worker_observation_card_id
		),
		"emergence unlocks its configured observation card"
	)
	_expect_int(
		_count_event_type(
			emerged.observations.events,
			ObservationEvent.Type.FIRST_WORKER_EMERGED
		),
		1,
		"the emergence event is emitted exactly once"
	)
	var emergence_event: ObservationEvent = _find_event(
		emerged.observations.events,
		ObservationEvent.Type.FIRST_WORKER_EMERGED
	)
	_expect_true(emergence_event != null, "the structured emergence event exists")
	if emergence_event != null:
		_expect_int(
			emergence_event.tick,
			emergence_tick,
			"the structured emergence event uses the lifecycle boundary Tick"
		)
		_expect_int(
			emergence_event.actor_entity_id,
			first_worker_id,
			"the emergence event identifies the stable first worker"
		)
		_expect_int(
			emergence_event.subject_entity_id,
			first_worker_id,
			"the emergence event keeps the same entity as its subject"
		)
	_expect_int(
		transitions.size(),
		1,
		"the controlled lifecycle emits exactly one stage-change signal"
	)
	if transitions.size() == 1:
		_expect_int(
			int(transitions[0]["entity_id"]),
			first_worker_id,
			"the stage-change signal identifies the stable first worker"
		)
		_expect_int(
			int(transitions[0]["previous_stage"]),
			AntModel.LifeStage.PUPA,
			"the stage-change signal starts at pupa"
		)
		_expect_int(
			int(transitions[0]["current_stage"]),
			AntModel.LifeStage.WORKER,
			"the stage-change signal ends at worker"
		)
		_expect_int(
			int(transitions[0]["tick"]),
			emergence_tick,
			"the stage-change signal uses the exact fixed Tick"
		)


func _test_commands_are_phase_gated_and_apply_on_the_next_legal_tick() -> void:
	var simulation: ColonySimulation = _create_simulation()
	var initial: GameSnapshot = simulation.create_game_snapshot()
	_expect_true(
		not simulation.submit_continue_observation_action(),
		"continue is rejected before the identity phase"
	)
	_expect_true(
		not simulation.submit_water_action(),
		"water is rejected before the humidity phase"
	)
	_expect_true(
		not simulation.submit_place_sugar_action(),
		"sugar placement is rejected before the foraging phase"
	)

	_expect_true(
		_advance_to_tick(simulation, _get_first_worker_emergence_tick()),
		"the command fixture reaches identity observation"
	)
	var identity: GameSnapshot = simulation.create_game_snapshot()
	_expect_true(
		simulation.submit_continue_observation_action(),
		"identity accepts its high-level continue action"
	)
	_expect_true(
		not simulation.submit_continue_observation_action(),
		"identity accepts at most one pending continue action"
	)
	_expect_true(
		not simulation.submit_water_action(),
		"water remains gated while continue is pending"
	)
	_expect_true(
		not simulation.submit_place_sugar_action(),
		"sugar remains gated while continue is pending"
	)
	var pending_continue: GameSnapshot = simulation.create_game_snapshot()
	_expect_int(
		pending_continue.sequence.phase,
		ScenarioSequenceSnapshot.Phase.IDENTITY_OBSERVATION,
		"submitting continue does not immediately change phase"
	)
	_expect_true(
		pending_continue.sequence.continue_action_pending,
		"the pending continue action is exposed in the sequence snapshot"
	)
	_expect_true(
		not simulation.advance_tick(identity.simulation_tick + 2),
		"a non-sequential Tick is rejected with continue pending"
	)
	var rejected_continue: GameSnapshot = simulation.create_game_snapshot()
	_expect_int(
		rejected_continue.simulation_tick,
		identity.simulation_tick,
		"the rejected Tick does not advance canonical time"
	)
	_expect_true(
		rejected_continue.sequence.continue_action_pending,
		"the rejected Tick does not consume the continue action"
	)
	_expect_true(
		simulation.advance_tick(identity.simulation_tick + 1),
		"the next legal Tick applies continue"
	)
	var humidity_phase: GameSnapshot = simulation.create_game_snapshot()
	_expect_int(
		humidity_phase.sequence.phase,
		ScenarioSequenceSnapshot.Phase.HUMIDITY_OBSERVATION,
		"continue advances to humidity observation on the next Tick"
	)
	_expect_true(
		not humidity_phase.sequence.continue_action_pending,
		"the applied continue action leaves no pending command"
	)
	_expect_true(
		not simulation.submit_continue_observation_action(),
		"continue is rejected after identity observation"
	)
	_expect_true(
		not simulation.submit_place_sugar_action(),
		"sugar remains rejected during humidity observation"
	)

	var water_ready: GameSnapshot = _advance_until_water_available(simulation)
	_expect_true(
		water_ready.colony.water_action_available,
		"the first successful relocation unlocks water"
	)
	var water_zone_before: HabitatZoneSnapshot = water_ready.colony.find_zone(
		COMBINED_SCENARIO_DATA.humidity_adjustment_zone_id
	)
	_expect_true(water_zone_before != null, "the configured water target exists")
	var humidity_before: float = (
		water_zone_before.humidity if water_zone_before != null else -1.0
	)
	_expect_true(
		simulation.submit_water_action(),
		"the humidity phase accepts the high-level water action"
	)
	_expect_true(
		not simulation.submit_water_action(),
		"the humidity phase accepts at most one pending water action"
	)
	var pending_water: GameSnapshot = simulation.create_game_snapshot()
	_expect_true(
		pending_water.colony.water_action_pending,
		"the pending water action is exposed in the colony snapshot"
	)
	_expect_float(
		_zone_humidity(
			pending_water.colony,
			COMBINED_SCENARIO_DATA.humidity_adjustment_zone_id
		),
		humidity_before,
		"submitting water does not immediately change humidity"
	)
	_expect_true(
		not simulation.advance_tick(water_ready.simulation_tick + 2),
		"a non-sequential Tick is rejected with water pending"
	)
	var rejected_water: GameSnapshot = simulation.create_game_snapshot()
	_expect_true(
		rejected_water.colony.water_action_pending,
		"the rejected Tick does not consume the water action"
	)
	_expect_float(
		_zone_humidity(
			rejected_water.colony,
			COMBINED_SCENARIO_DATA.humidity_adjustment_zone_id
		),
		humidity_before,
		"the rejected Tick cannot partially apply water"
	)
	_expect_true(
		simulation.advance_tick(water_ready.simulation_tick + 1),
		"the next legal Tick applies water"
	)
	var water_applied: GameSnapshot = simulation.create_game_snapshot()
	_expect_true(
		not water_applied.colony.water_action_pending,
		"the applied water action leaves no pending command"
	)
	_expect_int(
		water_applied.colony.water_action_count,
		1,
		"the simulation counts one applied water action"
	)
	_expect_float(
		_zone_humidity(
			water_applied.colony,
			COMBINED_SCENARIO_DATA.humidity_adjustment_zone_id
		),
		clampf(
			humidity_before
				+ COMBINED_SCENARIO_DATA.humidity_adjustment_amount,
			0.0,
			1.0
		),
		"the next legal Tick applies the Resource-defined water amount"
	)

	var sugar_phase: GameSnapshot = _advance_automatically_to_phase(
		simulation,
		ScenarioSequenceSnapshot.Phase.SUGAR_FORAGING
	)
	_expect_int(
		sugar_phase.sequence.phase,
		ScenarioSequenceSnapshot.Phase.SUGAR_FORAGING,
		"the command fixture reaches sugar foraging"
	)
	_expect_true(
		not simulation.submit_continue_observation_action(),
		"continue is rejected during sugar foraging"
	)
	_expect_true(
		not simulation.submit_water_action(),
		"water is rejected after the humidity phase"
	)
	_expect_true(
		simulation.submit_place_sugar_action(),
		"the foraging phase accepts configured sugar placement"
	)
	_expect_true(
		not simulation.submit_place_sugar_action(),
		"the foraging phase accepts at most one pending sugar action"
	)
	var pending_sugar: GameSnapshot = simulation.create_game_snapshot()
	_expect_true(
		pending_sugar.scenario.place_action_pending,
		"the pending sugar action is exposed in the scenario snapshot"
	)
	_expect_int(
		pending_sugar.colony.food_sources.size(),
		0,
		"submitting sugar does not immediately create a food source"
	)
	_expect_true(
		not simulation.advance_tick(sugar_phase.simulation_tick + 2),
		"a non-sequential Tick is rejected with sugar pending"
	)
	var rejected_sugar: GameSnapshot = simulation.create_game_snapshot()
	_expect_true(
		rejected_sugar.scenario.place_action_pending,
		"the rejected Tick does not consume the sugar action"
	)
	_expect_int(
		rejected_sugar.colony.food_sources.size(),
		0,
		"the rejected Tick cannot partially create sugar"
	)
	_expect_true(
		simulation.advance_tick(sugar_phase.simulation_tick + 1),
		"the next legal Tick applies sugar placement"
	)
	var sugar_applied: GameSnapshot = simulation.create_game_snapshot()
	_expect_true(
		not sugar_applied.scenario.place_action_pending,
		"the applied sugar action leaves no pending command"
	)
	_expect_int(
		sugar_applied.scenario.place_action_count,
		1,
		"the scenario counts one applied sugar placement"
	)
	_expect_int(
		sugar_applied.colony.food_sources.size(),
		1,
		"the next legal Tick creates exactly one food source"
	)

	var completed: GameSnapshot = _complete_session(simulation)
	_expect_true(completed.sequence.completed, "the command fixture reaches summary")
	_expect_true(
		not simulation.submit_continue_observation_action(),
		"summary rejects continue"
	)
	_expect_true(not simulation.submit_water_action(), "summary rejects water")
	_expect_true(
		not simulation.submit_place_sugar_action(),
		"summary rejects sugar placement"
	)
	_expect_int(
		initial.simulation_tick,
		0,
		"the command fixture started from canonical Tick zero"
	)


func _test_fixed_tick_phase_sequence_is_monotonic() -> void:
	var simulation: ColonySimulation = _create_simulation()
	var snapshot: GameSnapshot = simulation.create_game_snapshot()
	var observed_phases: Array[int] = [snapshot.sequence.phase]
	var phase_entry_ticks: Array[int] = [snapshot.sequence.phase_entered_tick]
	var monotonic_failure: String = ""

	while (
		not snapshot.sequence.completed
		and snapshot.simulation_tick < _get_session_deadline_tick()
	):
		if not _submit_available_action(simulation):
			monotonic_failure = (
				"an available command was rejected at Tick %d"
				% snapshot.simulation_tick
			)
			break
		if not simulation.advance_tick(snapshot.simulation_tick + 1):
			monotonic_failure = (
				"simulation rejected sequential Tick %d"
				% (snapshot.simulation_tick + 1)
			)
			break
		var next_snapshot: GameSnapshot = simulation.create_game_snapshot()
		if next_snapshot.sequence.phase != snapshot.sequence.phase:
			if (
				int(next_snapshot.sequence.phase)
				!= int(snapshot.sequence.phase) + 1
			):
				monotonic_failure = (
					"phase changed from %d to %d at Tick %d"
					% [
						snapshot.sequence.phase,
						next_snapshot.sequence.phase,
						next_snapshot.simulation_tick,
					]
				)
				break
			if (
				next_snapshot.sequence.phase_entered_tick
				!= next_snapshot.simulation_tick
			):
				monotonic_failure = (
					"phase %d recorded entry Tick %d instead of %d"
					% [
						next_snapshot.sequence.phase,
						next_snapshot.sequence.phase_entered_tick,
						next_snapshot.simulation_tick,
					]
				)
				break
			observed_phases.append(next_snapshot.sequence.phase)
			phase_entry_ticks.append(
				next_snapshot.sequence.phase_entered_tick
			)
		snapshot = next_snapshot

	_expect_string(
		monotonic_failure,
		"",
		"fixed-Tick phase transitions never skip, repeat, or regress"
	)
	_expect_string(
		_int_array_signature(observed_phases),
		_int_array_signature([
			ScenarioSequenceSnapshot.Phase.FOUNDING_PRELUDE,
			ScenarioSequenceSnapshot.Phase.IDENTITY_OBSERVATION,
			ScenarioSequenceSnapshot.Phase.HUMIDITY_OBSERVATION,
			ScenarioSequenceSnapshot.Phase.SUGAR_FORAGING,
			ScenarioSequenceSnapshot.Phase.OBSERVATION_SUMMARY,
		]),
		"the sequence enters each of the five phases exactly once"
	)
	_expect_true(snapshot.sequence.completed, "the monotonic trace reaches summary")
	if phase_entry_ticks.size() == 5:
		_expect_int(
			phase_entry_ticks[
				ScenarioSequenceSnapshot.Phase.IDENTITY_OBSERVATION
			],
			snapshot.sequence.first_worker_emerged_tick,
			"identity begins on the worker-emergence Tick"
		)
		_expect_int(
			phase_entry_ticks[
				ScenarioSequenceSnapshot.Phase.SUGAR_FORAGING
			],
			snapshot.sequence.humidity_observation_completed_tick,
			"sugar foraging begins on the humidity completion Tick"
		)
		_expect_int(
			phase_entry_ticks[
				ScenarioSequenceSnapshot.Phase.OBSERVATION_SUMMARY
			],
			snapshot.sequence.sugar_observation_completed_tick,
			"summary begins on the sugar completion Tick"
		)

	var identity_event: ObservationEvent = _find_event(
		snapshot.observations.events,
		ObservationEvent.Type.IDENTITY_OBSERVATION_COMPLETED
	)
	var humidity_event: ObservationEvent = _find_event(
		snapshot.observations.events,
		ObservationEvent.Type.BROOD_HUMIDITY_OBSERVATION_COMPLETED
	)
	var sugar_event: ObservationEvent = _find_event(
		snapshot.observations.events,
		ObservationEvent.Type.SUGAR_OBSERVATION_COMPLETED
	)
	var completion_event: ObservationEvent = _find_event(
		snapshot.observations.events,
		ObservationEvent.Type.OBSERVATION_SESSION_COMPLETED
	)
	_expect_true(identity_event != null, "identity completion emits an event")
	_expect_true(humidity_event != null, "humidity completion emits an event")
	_expect_true(sugar_event != null, "sugar completion emits an event")
	_expect_true(completion_event != null, "session completion emits an event")
	if identity_event != null and phase_entry_ticks.size() == 5:
		_expect_int(
			identity_event.tick,
			phase_entry_ticks[
				ScenarioSequenceSnapshot.Phase.HUMIDITY_OBSERVATION
			],
			"identity completion causes the humidity phase on the same Tick"
		)
	if humidity_event != null:
		_expect_int(
			humidity_event.tick,
			snapshot.sequence.humidity_observation_completed_tick,
			"humidity completion state and event share one fixed Tick"
		)
	if sugar_event != null:
		_expect_int(
			sugar_event.tick,
			snapshot.sequence.sugar_observation_completed_tick,
			"sugar completion state and event share one fixed Tick"
		)
	if completion_event != null:
		_expect_int(
			completion_event.tick,
			snapshot.sequence.sugar_observation_completed_tick,
			"session completion is recorded on the summary transition Tick"
		)
	for event_type: int in [
		ObservationEvent.Type.FIRST_WORKER_EMERGED,
		ObservationEvent.Type.IDENTITY_OBSERVATION_COMPLETED,
		ObservationEvent.Type.BROOD_HUMIDITY_OBSERVATION_COMPLETED,
		ObservationEvent.Type.SUGAR_OBSERVATION_COMPLETED,
		ObservationEvent.Type.OBSERVATION_SESSION_COMPLETED,
	]:
		_expect_int(
			_count_event_type(snapshot.observations.events, event_type),
			1,
			"phase boundary event %d is emitted exactly once" % event_type
		)


func _test_first_worker_id_and_three_cards_survive_every_phase() -> void:
	var simulation: ColonySimulation = _create_simulation()
	var snapshot: GameSnapshot = simulation.create_game_snapshot()
	var first_worker_id: int = snapshot.sequence.first_worker_entity_id
	var observed_phase_ids: Dictionary[int, bool] = {}
	var identity_failure: String = ""

	while (
		not snapshot.sequence.completed
		and snapshot.simulation_tick < _get_session_deadline_tick()
	):
		var first_worker: AntSnapshot = snapshot.colony.find_ant(
			first_worker_id
		)
		if first_worker == null:
			identity_failure = (
				"first worker %d disappeared in phase %d at Tick %d"
				% [
					first_worker_id,
					snapshot.sequence.phase,
					snapshot.simulation_tick,
				]
			)
			break
		if _count_entity_id(snapshot.colony, first_worker_id) != 1:
			identity_failure = (
				"first worker %d is duplicated at Tick %d"
				% [first_worker_id, snapshot.simulation_tick]
			)
			break
		if (
			snapshot.sequence.phase
			!= ScenarioSequenceSnapshot.Phase.FOUNDING_PRELUDE
			and first_worker.life_stage != AntModel.LifeStage.WORKER
		):
			identity_failure = (
				"first worker %d is not a worker in phase %d"
				% [first_worker_id, snapshot.sequence.phase]
			)
			break
		observed_phase_ids[snapshot.sequence.phase] = true
		if not _submit_available_action(simulation):
			identity_failure = (
				"an available command was rejected at Tick %d"
				% snapshot.simulation_tick
			)
			break
		if not simulation.advance_tick(snapshot.simulation_tick + 1):
			identity_failure = (
				"simulation rejected sequential Tick %d"
				% (snapshot.simulation_tick + 1)
			)
			break
		snapshot = simulation.create_game_snapshot()

	var final_worker: AntSnapshot = snapshot.colony.find_ant(first_worker_id)
	if final_worker != null:
		observed_phase_ids[snapshot.sequence.phase] = true
	_expect_string(
		identity_failure,
		"",
		"the first-worker entity remains unique and present across phases"
	)
	_expect_true(snapshot.sequence.completed, "the stable-ID trace reaches summary")
	_expect_int(
		observed_phase_ids.size(),
		5,
		"the same first-worker ID is observed in all five phases"
	)
	_expect_true(final_worker != null, "the first worker remains present in summary")
	if final_worker != null:
		_expect_int(
			final_worker.entity_id,
			first_worker_id,
			"summary retains the original late-pupa entity ID"
		)
		_expect_int(
			final_worker.life_stage,
			AntModel.LifeStage.WORKER,
			"summary retains the emerged worker stage"
		)

	var relocation_event: ObservationEvent = _find_event(
		snapshot.observations.events,
		ObservationEvent.Type.RELOCATION_STARTED
	)
	var sugar_shared_event: ObservationEvent = _find_event(
		snapshot.observations.events,
		ObservationEvent.Type.SUGAR_SHARED
	)
	_expect_true(
		relocation_event != null,
		"the combined session records first-worker brood care"
	)
	_expect_true(
		sugar_shared_event != null,
		"the combined session records first-worker sugar sharing"
	)
	if relocation_event != null:
		_expect_int(
			relocation_event.actor_entity_id,
			first_worker_id,
			"the stable first worker performs brood relocation"
		)
	if sugar_shared_event != null:
		_expect_int(
			sugar_shared_event.actor_entity_id,
			first_worker_id,
			"the stable first worker performs sugar sharing"
		)

	_expect_int(
		snapshot.observations.unlocked_card_ids.size(),
		3,
		"summary contains exactly the three configured observation cards"
	)
	for card_id: StringName in _get_expected_card_ids():
		_expect_true(
			snapshot.observations.has_card(card_id),
			"summary contains configured card %s" % String(card_id)
		)


func _test_matching_inputs_and_all_clock_speeds_are_deterministic() -> void:
	var baseline: Dictionary = _run_with_clock_speed(
		SimulationClock.NORMAL_SPEED
	)
	var repeated: Dictionary = _run_with_clock_speed(
		SimulationClock.NORMAL_SPEED
	)
	var fast: Dictionary = _run_with_clock_speed(
		SimulationClock.FAST_SPEED
	)
	var very_fast: Dictionary = _run_with_clock_speed(
		SimulationClock.VERY_FAST_SPEED
	)

	for result: Dictionary in [baseline, repeated, fast, very_fast]:
		_expect_true(
			bool(result["ready"]),
			"the clock fixture initializes a combined simulation"
		)
		_expect_true(
			bool(result["ticks_accepted"]),
			"the clock fixture accepts every emitted fixed Tick"
		)
		_expect_true(
			bool(result["commands_accepted"]),
			"the clock fixture accepts every phase-appropriate command"
		)
		_expect_true(
			bool(result["completed"]),
			"the clock fixture reaches observation summary"
		)

	_expect_int(
		int(repeated["tick"]),
		int(baseline["tick"]),
		"matching 1x runs complete on the same Tick"
	)
	_expect_string(
		String(repeated["signature"]),
		String(baseline["signature"]),
		"matching 1x runs produce the same final snapshot"
	)
	_expect_string(
		String(repeated["trace_digest"]),
		String(baseline["trace_digest"]),
		"matching 1x runs produce the same per-Tick trace"
	)
	for result: Dictionary in [fast, very_fast]:
		_expect_int(
			int(result["tick"]),
			int(baseline["tick"]),
			"%dx completes on the same fixed Tick as 1x"
			% int(result["speed"])
		)
		_expect_string(
			String(result["signature"]),
			String(baseline["signature"]),
			"%dx produces the same final combined snapshot"
			% int(result["speed"])
		)
		_expect_string(
			String(result["trace_digest"]),
			String(baseline["trace_digest"]),
			"%dx preserves every per-Tick transition and event"
			% int(result["speed"])
		)
	_expect_true(
		int(very_fast["maximum_backlog"]) > 0,
		"16x retains and drains a capped-frame Tick backlog"
	)


func _test_combined_configuration_is_frozen_across_restart() -> void:
	var source_species: SpeciesData = (
		SPECIES_A_DATA.duplicate(true) as SpeciesData
	)
	var source_scenario: HabitatScenarioData = (
		_deep_duplicate_combined_scenario()
	)
	var source_sequence: ScenarioSequenceData = source_scenario.sequence_data
	var source_foraging: ForagingData = source_scenario.foraging_data
	var expected: Dictionary = {
		"pupa_duration_ticks": source_species.pupa_duration_ticks,
		"initial_pupa_age_ticks": (
			source_sequence.first_worker_initial_pupa_age_ticks
		),
		"emergence_tick": (
			source_species.pupa_duration_ticks
			- source_sequence.first_worker_initial_pupa_age_ticks
		),
		"first_card_id": source_sequence.first_worker_observation_card_id,
		"humidity_card_id": source_sequence.brood_humidity_observation_card_id,
		"sugar_card_id": source_scenario.foraging_observation_card_id,
		"water_zone_id": source_scenario.humidity_adjustment_zone_id,
		"water_amount": source_scenario.humidity_adjustment_amount,
		"placement_zone_id": source_scenario.sugar_placement_zone_id,
		"foraging_cycle_ticks": (
			source_foraging.discovery_delay_ticks
			+ source_foraging.outbound_travel_duration_ticks
			+ source_foraging.collection_duration_ticks
			+ source_foraging.return_travel_duration_ticks
			+ source_foraging.sharing_duration_ticks
		),
	}
	var simulation: ColonySimulation = ColonySimulation.new(
		source_species,
		source_scenario
	)
	_expect_true(
		simulation.is_ready(),
		"deep-copied combined Resources initialize the freeze fixture"
	)

	var mutated_water_zone_id: StringName = _find_alternate_zone_id(
		source_scenario,
		[StringName(expected["water_zone_id"])]
	)
	var mutated_placement_zone_id: StringName = _find_alternate_zone_id(
		source_scenario,
		[
			StringName(expected["placement_zone_id"]),
			source_scenario.nest_zone_id,
		]
	)
	_expect_true(
		not mutated_water_zone_id.is_empty(),
		"the freeze fixture has an alternate water target"
	)
	_expect_true(
		not mutated_placement_zone_id.is_empty(),
		"the freeze fixture has an alternate sugar placement zone"
	)

	var mutated_first_card_id: StringName = &"mutated_first_worker_card"
	var mutated_humidity_card_id: StringName = &"mutated_humidity_card"
	var mutated_sugar_card_id: StringName = &"mutated_sugar_card"
	source_species.pupa_duration_ticks += 137
	source_sequence.first_worker_initial_pupa_age_ticks = maxi(
		1,
		int(expected["initial_pupa_age_ticks"]) - 113
	)
	source_sequence.first_worker_observation_card_id = (
		mutated_first_card_id
	)
	source_sequence.brood_humidity_observation_card_id = (
		mutated_humidity_card_id
	)
	source_scenario.foraging_observation_card_id = mutated_sugar_card_id
	source_scenario.humidity_adjustment_zone_id = mutated_water_zone_id
	source_scenario.humidity_adjustment_amount = minf(
		float(expected["water_amount"]) + 0.07,
		1.0
	)
	source_scenario.sugar_placement_zone_id = (
		mutated_placement_zone_id
	)
	source_foraging.discovery_delay_ticks += 17
	source_foraging.outbound_travel_duration_ticks += 11
	expected["mutated_water_zone_id"] = mutated_water_zone_id
	expected["mutated_placement_zone_id"] = mutated_placement_zone_id
	expected["mutated_first_card_id"] = mutated_first_card_id
	expected["mutated_humidity_card_id"] = mutated_humidity_card_id
	expected["mutated_sugar_card_id"] = mutated_sugar_card_id

	_expect_true(
		source_species.is_valid(),
		"mutated source SpeciesData remains independently valid"
	)
	_expect_true(
		not source_scenario.is_valid(),
		"post-construction source mutation may violate the frozen layout"
	)
	_expect_true(
		int(expected["emergence_tick"])
			!= (
				source_species.pupa_duration_ticks
				- source_sequence.first_worker_initial_pupa_age_ticks
			),
		"the mutated source would produce a different emergence boundary"
	)
	_expect_true(
		float(expected["water_amount"])
			!= source_scenario.humidity_adjustment_amount,
		"the mutated source exposes a different water amount"
	)
	_expect_true(
		int(expected["foraging_cycle_ticks"])
			!= (
				source_foraging.discovery_delay_ticks
				+ source_foraging.outbound_travel_duration_ticks
				+ source_foraging.collection_duration_ticks
				+ source_foraging.return_travel_duration_ticks
				+ source_foraging.sharing_duration_ticks
			),
		"the mutated source exposes a different foraging duration"
	)

	var first_session: Dictionary = _exercise_frozen_configuration_session(
		simulation,
		expected,
		"current session"
	)
	_expect_true(
		simulation.restart_session(),
		"the frozen combined simulation restarts after source mutation"
	)
	var restarted_session: Dictionary = (
		_exercise_frozen_configuration_session(
			simulation,
			expected,
			"restarted session"
		)
	)
	_expect_int(
		int(restarted_session["first_worker_id"]),
		int(first_session["first_worker_id"]),
		"restart restores the same frozen first-worker ID"
	)
	_expect_int(
		int(restarted_session["emergence_tick"]),
		int(first_session["emergence_tick"]),
		"restart preserves the frozen emergence boundary"
	)
	_expect_int(
		int(restarted_session["completion_tick"]),
		int(first_session["completion_tick"]),
		"restart preserves the frozen combined pacing"
	)
	_expect_string(
		String(restarted_session["signature"]),
		String(first_session["signature"]),
		"restart reproduces the full frozen combined snapshot"
	)


func _test_combined_resource_rejects_projection_incompatible_layouts() -> void:
	_expect_true(
		COMBINED_SCENARIO_DATA.is_valid(),
		"the canonical combined linear habitat is valid"
	)

	var wrong_water_target: HabitatScenarioData = (
		_deep_duplicate_combined_scenario()
	)
	wrong_water_target.humidity_adjustment_zone_id = (
		wrong_water_target.sugar_placement_zone_id
	)
	_expect_true(
		not wrong_water_target.is_valid(),
		"combined watering must target the projected nursery and nest"
	)

	var wrong_nest: HabitatScenarioData = _deep_duplicate_combined_scenario()
	wrong_nest.nest_zone_id = _get_combined_intermediate_zone_id(wrong_nest)
	_expect_true(
		not wrong_nest.is_valid(),
		"combined brood and first-worker ownership must begin in the nest"
	)

	var missing_nest_return: HabitatScenarioData = (
		_deep_duplicate_combined_scenario()
	)
	var intermediate_zone_id: StringName = (
		_get_combined_intermediate_zone_id(missing_nest_return)
	)
	var intermediate_zone: HabitatZoneData = _find_zone_data(
		missing_nest_return,
		intermediate_zone_id
	)
	if intermediate_zone != null:
		intermediate_zone.connected_zone_ids.erase(
			missing_nest_return.nest_zone_id
		)
	_expect_true(
		not missing_nest_return.is_valid(),
		"combined brood relocation requires a direct return to the nursery"
	)

	var missing_foraging_return: HabitatScenarioData = (
		_deep_duplicate_combined_scenario()
	)
	var placement_zone: HabitatZoneData = _find_zone_data(
		missing_foraging_return,
		missing_foraging_return.sugar_placement_zone_id
	)
	if placement_zone != null:
		placement_zone.connected_zone_ids.erase(
			_get_combined_intermediate_zone_id(missing_foraging_return)
		)
	_expect_true(
		not missing_foraging_return.is_valid(),
		"combined foraging requires a direct return through the middle zone"
	)

	var extra_shortcut: HabitatScenarioData = (
		_deep_duplicate_combined_scenario()
	)
	var shortcut_nest: HabitatZoneData = _find_zone_data(
		extra_shortcut,
		extra_shortcut.nest_zone_id
	)
	if shortcut_nest != null:
		shortcut_nest.connected_zone_ids.append(
			extra_shortcut.sugar_placement_zone_id
		)
	_expect_true(
		not extra_shortcut.is_valid(),
		"combined layout rejects shortcuts that bypass the middle chamber"
	)

	var unavailable_middle: HabitatScenarioData = (
		_deep_duplicate_combined_scenario()
	)
	var unavailable_zone: HabitatZoneData = _find_zone_data(
		unavailable_middle,
		_get_combined_intermediate_zone_id(unavailable_middle)
	)
	if unavailable_zone != null:
		unavailable_zone.available = false
	_expect_true(
		not unavailable_middle.is_valid(),
		"every projected combined zone must be available at session start"
	)

	var no_first_relocation: HabitatScenarioData = (
		_deep_duplicate_combined_scenario()
	)
	var no_improvement_zone: HabitatZoneData = _find_zone_data(
		no_first_relocation,
		_get_combined_intermediate_zone_id(no_first_relocation)
	)
	var initial_brood_zone: HabitatZoneData = _find_zone_data(
		no_first_relocation,
		no_first_relocation.initial_brood_zone_id
	)
	if no_improvement_zone != null and initial_brood_zone != null:
		no_improvement_zone.initial_humidity = (
			initial_brood_zone.initial_humidity
		)
	_expect_true(
		no_first_relocation.is_valid(),
		"matching humidity remains structurally valid Resource data"
	)
	var no_first_relocation_simulation: ColonySimulation = (
		ColonySimulation.new(SPECIES_A_DATA, no_first_relocation)
	)
	_expect_true(
		not no_first_relocation_simulation.is_ready(),
		"combined construction rejects a loop with no first relocation"
	)

	var overshooting_water: HabitatScenarioData = (
		_deep_duplicate_combined_scenario()
	)
	overshooting_water.humidity_adjustment_amount = 0.8
	_expect_true(
		overshooting_water.is_valid(),
		"overshooting water remains structurally valid Resource data"
	)
	var overshooting_simulation: ColonySimulation = ColonySimulation.new(
		SPECIES_A_DATA,
		overshooting_water
	)
	_expect_true(
		not overshooting_simulation.is_ready(),
		"combined construction rejects water that can never reach comfort"
	)


func _test_relocation_and_foraging_ownership_remain_compatible() -> void:
	var simulation: ColonySimulation = _create_simulation()
	var snapshot: GameSnapshot = simulation.create_game_snapshot()
	var first_failure: String = ""
	var saw_relocation: bool = false
	var saw_foraging: bool = false

	while (
		not snapshot.sequence.completed
		and snapshot.simulation_tick < _get_session_deadline_tick()
	):
		if not simulation.has_valid_habitat_ownership():
			first_failure = (
				"authoritative ownership failed at Tick %d"
				% snapshot.simulation_tick
			)
			break
		var invariant_failure: String = _get_combined_invariant_failure(
			snapshot
		)
		if not invariant_failure.is_empty():
			first_failure = (
				"Tick %d: %s"
				% [snapshot.simulation_tick, invariant_failure]
			)
			break
		for ant: AntSnapshot in snapshot.colony.ants:
			if ant.life_stage != AntModel.LifeStage.WORKER:
				continue
			if ant.worker_task_state != WorkerTaskModel.State.IDLE:
				saw_relocation = true
			if (
				ant.foraging_task != null
				and ant.foraging_task.state
					!= ForagingTaskModel.State.IDLE
			):
				saw_foraging = true
		if not _submit_available_action(simulation):
			first_failure = (
				"an available command was rejected at Tick %d"
				% snapshot.simulation_tick
			)
			break
		if not simulation.advance_tick(snapshot.simulation_tick + 1):
			first_failure = (
				"simulation rejected sequential Tick %d"
				% (snapshot.simulation_tick + 1)
			)
			break
		snapshot = simulation.create_game_snapshot()

	if first_failure.is_empty():
		var final_failure: String = _get_combined_invariant_failure(snapshot)
		if not final_failure.is_empty():
			first_failure = (
				"Tick %d: %s"
				% [snapshot.simulation_tick, final_failure]
			)
	_expect_string(
		first_failure,
		"",
		"combined relocation and foraging preserve all ownership relations"
	)
	_expect_true(saw_relocation, "the ownership trace exercises brood relocation")
	_expect_true(saw_foraging, "the ownership trace exercises sugar foraging")
	_expect_true(snapshot.sequence.completed, "the ownership trace reaches summary")
	_expect_int(
		snapshot.colony.count_active_relocations(),
		0,
		"summary leaves no active brood relocation"
	)
	var final_worker: AntSnapshot = snapshot.colony.find_ant(
		snapshot.sequence.first_worker_entity_id
	)
	_expect_true(final_worker != null, "summary retains the ownership worker")
	if final_worker != null and final_worker.foraging_task != null:
		_expect_int(
			final_worker.foraging_task.state,
			ForagingTaskModel.State.IDLE,
			"summary leaves no active foraging task"
		)
		_expect_int(
			final_worker.foraging_task.carried_portions,
			0,
			"summary leaves no sugar carried by the worker"
		)


func _test_restart_clears_every_combined_session_domain() -> void:
	var simulation: ColonySimulation = _create_simulation()

	_expect_true(
		_advance_to_tick(simulation, _get_first_worker_emergence_tick()),
		"the restart fixture reaches identity observation"
	)
	_expect_true(
		simulation.submit_continue_observation_action(),
		"the restart fixture queues continue"
	)
	_expect_true(
		simulation.create_game_snapshot().sequence.continue_action_pending,
		"continue is pending before restart"
	)
	_expect_true(
		simulation.restart_session(),
		"restart clears a pending continue action"
	)
	_expect_initial_combined_snapshot(
		simulation.create_game_snapshot(),
		"restart after pending continue"
	)

	_expect_true(
		_advance_to_tick(simulation, _get_first_worker_emergence_tick()),
		"the restarted fixture reaches identity again"
	)
	_expect_true(
		simulation.submit_continue_observation_action(),
		"the restarted fixture queues continue again"
	)
	var identity: GameSnapshot = simulation.create_game_snapshot()
	_expect_true(
		simulation.advance_tick(identity.simulation_tick + 1),
		"the restarted fixture enters humidity observation"
	)
	var water_ready: GameSnapshot = _advance_until_water_available(simulation)
	_expect_true(
		simulation.submit_water_action(),
		"the restart fixture queues water"
	)
	_expect_true(
		simulation.create_game_snapshot().colony.water_action_pending,
		"water is pending before restart"
	)
	_expect_true(
		simulation.restart_session(),
		"restart clears a pending water action"
	)
	_expect_initial_combined_snapshot(
		simulation.create_game_snapshot(),
		"restart after pending water"
	)
	_expect_true(
		water_ready.simulation_tick > _get_first_worker_emergence_tick(),
		"the pending-water restart occurred after visible relocation"
	)

	var sugar_phase: GameSnapshot = _advance_automatically_to_phase(
		simulation,
		ScenarioSequenceSnapshot.Phase.SUGAR_FORAGING
	)
	_expect_true(
		simulation.submit_place_sugar_action(),
		"the restart fixture queues sugar"
	)
	_expect_true(
		simulation.create_game_snapshot().scenario.place_action_pending,
		"sugar is pending before restart"
	)
	_expect_true(
		simulation.restart_session(),
		"restart clears a pending sugar action"
	)
	_expect_initial_combined_snapshot(
		simulation.create_game_snapshot(),
		"restart after pending sugar"
	)
	_expect_true(
		sugar_phase.sequence.phase
			== ScenarioSequenceSnapshot.Phase.SUGAR_FORAGING,
		"the pending-sugar restart occurred in the foraging phase"
	)

	var completed: GameSnapshot = _complete_session(simulation)
	_expect_true(completed.sequence.completed, "the restart fixture reaches summary")
	_expect_true(
		not completed.colony.food_sources.is_empty(),
		"the completed fixture contains a session food source"
	)
	_expect_int(
		completed.observations.unlocked_card_ids.size(),
		3,
		"the completed fixture contains all session cards"
	)
	_expect_true(
		not completed.observations.events.is_empty(),
		"the completed fixture contains session events"
	)
	_expect_true(
		simulation.restart_session(),
		"restart clears a completed combined session"
	)
	_expect_initial_combined_snapshot(
		simulation.create_game_snapshot(),
		"restart after completion"
	)
	_expect_true(
		simulation.restart_session(),
		"a second consecutive restart is accepted"
	)
	_expect_initial_combined_snapshot(
		simulation.create_game_snapshot(),
		"second consecutive restart"
	)


func _test_combined_game_snapshot_is_deeply_isolated() -> void:
	var simulation: ColonySimulation = _create_simulation()
	var mutable_snapshot: GameSnapshot = _complete_session(simulation)
	var original_signature: String = _combined_signature(mutable_snapshot)
	_expect_true(
		mutable_snapshot.sequence != null,
		"snapshot isolation fixture contains sequence state"
	)
	_expect_true(
		not mutable_snapshot.colony.zones.is_empty(),
		"snapshot isolation fixture contains zones"
	)
	_expect_true(
		not mutable_snapshot.colony.food_sources.is_empty(),
		"snapshot isolation fixture contains a food source"
	)
	_expect_true(
		not mutable_snapshot.observations.events.is_empty(),
		"snapshot isolation fixture contains events"
	)

	mutable_snapshot.simulation_tick = 999_999
	mutable_snapshot.sequence.phase = (
		ScenarioSequenceSnapshot.Phase.FOUNDING_PRELUDE
	)
	mutable_snapshot.sequence.phase_entered_tick = 999_999
	mutable_snapshot.sequence.first_worker_entity_id = 999_999
	mutable_snapshot.sequence.first_worker_emerged_tick = 999_999
	mutable_snapshot.sequence.humidity_observation_completed_tick = 999_999
	mutable_snapshot.sequence.sugar_observation_completed_tick = 999_999
	mutable_snapshot.sequence.first_worker_observation_card_id = (
		&"mutated_first_card"
	)
	mutable_snapshot.sequence.brood_humidity_observation_card_id = (
		&"mutated_humidity_card"
	)
	mutable_snapshot.sequence.sugar_foraging_observation_card_id = (
		&"mutated_sugar_card"
	)
	mutable_snapshot.sequence.continue_action_available = true
	mutable_snapshot.sequence.continue_action_pending = true
	mutable_snapshot.sequence.completed = false
	mutable_snapshot.scenario.phase = (
		ForagingScenarioSnapshot.Phase.AWAITING_PLACEMENT
	)
	mutable_snapshot.scenario.place_action_available = true
	mutable_snapshot.scenario.place_action_pending = true
	mutable_snapshot.scenario.place_action_count = 999
	mutable_snapshot.colony.simulation_tick = 999_999
	mutable_snapshot.colony.humidity_adjustment_count = 999
	mutable_snapshot.colony.water_action_count = 999
	mutable_snapshot.colony.zones[0].humidity = 0.999
	mutable_snapshot.colony.zones[0].connected_zone_ids.append(
		&"mutated_zone"
	)
	mutable_snapshot.colony.food_sources[0].remaining_portions = 999
	mutable_snapshot.colony.food_sources[0].reserved_by_worker_id = 999
	var mutable_worker: AntSnapshot = mutable_snapshot.colony.find_ant(
		simulation.create_game_snapshot().sequence.first_worker_entity_id
	)
	_expect_true(
		mutable_worker != null,
		"snapshot isolation fixture contains the first worker"
	)
	if mutable_worker != null:
		mutable_worker.entity_id = 999_999
		mutable_worker.zone_id = &"mutated_zone"
		mutable_worker.worker_task_state = (
			WorkerTaskModel.State.CARRYING_TO_ZONE
		)
		mutable_worker.target_brood_id = 999_999
		if mutable_worker.foraging_task != null:
			mutable_worker.foraging_task.state = (
				ForagingTaskModel.State.RETURNING_TO_NEST
			)
			mutable_worker.foraging_task.target_food_source_id = 999_999
			mutable_worker.foraging_task.route_zone_ids.append(
				&"mutated_zone"
			)
			mutable_worker.foraging_task.carried_portions = 999
	if not mutable_snapshot.colony.observation_events.is_empty():
		mutable_snapshot.colony.observation_events[0].event_id = 999_999
		mutable_snapshot.colony.observation_events.clear()
	if not mutable_snapshot.observations.events.is_empty():
		mutable_snapshot.observations.events[0].event_id = 999_999
		mutable_snapshot.observations.events.clear()
	mutable_snapshot.observations.unlocked_card_ids.clear()
	mutable_snapshot.colony.ants.clear()
	mutable_snapshot.colony.zones.clear()
	mutable_snapshot.colony.food_sources.clear()

	var fresh_snapshot: GameSnapshot = simulation.create_game_snapshot()
	_expect_string(
		_combined_signature(fresh_snapshot),
		original_signature,
		"mutating every combined snapshot domain cannot change simulation state"
	)
	_expect_true(
		simulation.has_valid_habitat_ownership(),
		"snapshot mutation cannot corrupt authoritative ownership"
	)


func _test_completion_plus_ten_thousand_tick_soak() -> void:
	var simulation: ColonySimulation = _create_simulation()
	var completed: GameSnapshot = _complete_session(simulation)
	var completion_tick: int = completed.simulation_tick
	var completion_events: String = (
		SimulationSnapshotSignature.canonical_event_history(
			completed.observations.events
		)
	)
	var completion_cards: String = _card_signature(
		completed.observations.unlocked_card_ids
	)
	var first_failure: String = ""
	var target_tick: int = completion_tick + SOAK_TICK_COUNT

	for tick_index: int in range(completion_tick + 1, target_tick + 1):
		if not simulation.advance_tick(tick_index):
			first_failure = (
				"simulation rejected Tick %d: %s"
				% [tick_index, simulation.get_configuration_error()]
			)
			break
		if not simulation.has_valid_habitat_ownership():
			first_failure = (
				"authoritative ownership failed at Tick %d" % tick_index
			)
			break
		var invariant_failure: String = _get_combined_invariant_failure(
			simulation.create_game_snapshot()
		)
		if not invariant_failure.is_empty():
			first_failure = (
				"Tick %d: %s" % [tick_index, invariant_failure]
			)
			break

	_expect_string(
		first_failure,
		"",
		"10,000 post-completion Ticks preserve combined invariants"
	)
	var final_snapshot: GameSnapshot = simulation.create_game_snapshot()
	_expect_int(
		final_snapshot.simulation_tick,
		target_tick,
		"the post-completion soak reaches exactly 10,000 additional Ticks"
	)
	_expect_int(
		final_snapshot.sequence.phase,
		ScenarioSequenceSnapshot.Phase.OBSERVATION_SUMMARY,
		"the completed sequence remains in summary during the soak"
	)
	_expect_true(
		final_snapshot.sequence.completed,
		"the completion flag remains stable during the soak"
	)
	_expect_string(
		SimulationSnapshotSignature.canonical_event_history(
			final_snapshot.observations.events
		),
		completion_events,
		"the completed session emits no duplicate post-summary events"
	)
	_expect_string(
		_card_signature(final_snapshot.observations.unlocked_card_ids),
		completion_cards,
		"the completed session unlocks no duplicate or extra cards"
	)
	_expect_int(
		final_snapshot.observations.unlocked_card_ids.size(),
		3,
		"the soak retains exactly the three combined observation cards"
	)


func _exercise_frozen_configuration_session(
	simulation: ColonySimulation,
	expected: Dictionary,
	context: String
) -> Dictionary:
	var initial: GameSnapshot = simulation.create_game_snapshot()
	var first_worker_id: int = initial.sequence.first_worker_entity_id
	var emergence_tick: int = int(expected["emergence_tick"])
	var original_first_card_id: StringName = StringName(
		expected["first_card_id"]
	)
	var original_humidity_card_id: StringName = StringName(
		expected["humidity_card_id"]
	)
	var original_sugar_card_id: StringName = StringName(
		expected["sugar_card_id"]
	)
	var mutated_first_card_id: StringName = StringName(
		expected["mutated_first_card_id"]
	)
	var mutated_humidity_card_id: StringName = StringName(
		expected["mutated_humidity_card_id"]
	)
	var mutated_sugar_card_id: StringName = StringName(
		expected["mutated_sugar_card_id"]
	)
	var original_water_zone_id: StringName = StringName(
		expected["water_zone_id"]
	)
	var mutated_water_zone_id: StringName = StringName(
		expected["mutated_water_zone_id"]
	)
	var original_placement_zone_id: StringName = StringName(
		expected["placement_zone_id"]
	)
	var mutated_placement_zone_id: StringName = StringName(
		expected["mutated_placement_zone_id"]
	)

	_expect_int(
		simulation.get_stage_duration_ticks(AntModel.LifeStage.PUPA),
		int(expected["pupa_duration_ticks"]),
		"%s uses the frozen pupa duration" % context
	)
	_expect_true(
		_advance_to_tick(simulation, emergence_tick - 1),
		"%s reaches the frozen pre-emergence boundary" % context
	)
	var before_emergence: GameSnapshot = simulation.create_game_snapshot()
	var pupa: AntSnapshot = before_emergence.colony.find_ant(
		first_worker_id
	)
	_expect_true(
		pupa != null,
		"%s retains the configured first-worker pupa" % context
	)
	if pupa != null:
		_expect_int(
			pupa.life_stage,
			AntModel.LifeStage.PUPA,
			"%s remains a pupa before the frozen boundary" % context
		)
		_expect_int(
			pupa.stage_age_ticks,
			int(expected["pupa_duration_ticks"]) - 1,
			"%s reaches the frozen final pupa age" % context
		)
	_expect_int(
		before_emergence.sequence.phase,
		ScenarioSequenceSnapshot.Phase.FOUNDING_PRELUDE,
		"%s remains in prelude before the frozen boundary" % context
	)
	_expect_true(
		not before_emergence.observations.has_card(
			original_first_card_id
		),
		"%s keeps the original emergence card locked before its Tick"
		% context
	)

	_expect_true(
		simulation.advance_tick(emergence_tick),
		"%s accepts the frozen emergence Tick" % context
	)
	var emerged: GameSnapshot = simulation.create_game_snapshot()
	var first_worker: AntSnapshot = emerged.colony.find_ant(first_worker_id)
	_expect_true(
		first_worker != null,
		"%s preserves the first-worker entity at emergence" % context
	)
	if first_worker != null:
		_expect_int(
			first_worker.life_stage,
			AntModel.LifeStage.WORKER,
			"%s emerges on the original frozen boundary" % context
		)
	_expect_int(
		emerged.sequence.first_worker_emerged_tick,
		emergence_tick,
		"%s records the original frozen emergence Tick" % context
	)
	_expect_true(
		emerged.observations.has_card(original_first_card_id),
		"%s unlocks the original frozen emergence card" % context
	)
	_expect_true(
		not emerged.observations.has_card(mutated_first_card_id),
		"%s ignores the mutated source emergence card" % context
	)

	_expect_true(
		simulation.submit_continue_observation_action(),
		"%s submits the frozen continue command" % context
	)
	_expect_true(
		simulation.advance_tick(emergence_tick + 1),
		"%s applies continue on the next fixed Tick" % context
	)
	_expect_int(
		simulation.create_game_snapshot().sequence.phase,
		ScenarioSequenceSnapshot.Phase.HUMIDITY_OBSERVATION,
		"%s enters humidity after frozen emergence" % context
	)

	var water_ready: GameSnapshot = _advance_until_water_available(
		simulation
	)
	var original_water_before: float = _zone_humidity(
		water_ready.colony,
		original_water_zone_id
	)
	var mutated_water_before: float = _zone_humidity(
		water_ready.colony,
		mutated_water_zone_id
	)
	_expect_true(
		simulation.submit_water_action(),
		"%s submits water through the frozen command gate" % context
	)
	var pending_water: GameSnapshot = simulation.create_game_snapshot()
	_expect_float(
		_zone_humidity(
			pending_water.colony,
			original_water_zone_id
		),
		original_water_before,
		"%s does not apply frozen water on the submission Tick" % context
	)
	_expect_true(
		simulation.advance_tick(pending_water.simulation_tick + 1),
		"%s applies frozen water on the next Tick" % context
	)
	var water_applied: GameSnapshot = simulation.create_game_snapshot()
	_expect_float(
		_zone_humidity(water_applied.colony, original_water_zone_id),
		clampf(
			original_water_before + float(expected["water_amount"]),
			0.0,
			1.0
		),
		"%s uses the original frozen water target and amount" % context
	)
	_expect_float(
		_zone_humidity(water_applied.colony, mutated_water_zone_id),
		mutated_water_before,
		"%s ignores the mutated source water target" % context
	)

	var sugar_phase: GameSnapshot = _advance_automatically_to_phase(
		simulation,
		ScenarioSequenceSnapshot.Phase.SUGAR_FORAGING
	)
	_expect_true(
		sugar_phase.observations.has_card(original_humidity_card_id),
		"%s unlocks the original frozen humidity card" % context
	)
	_expect_true(
		not sugar_phase.observations.has_card(mutated_humidity_card_id),
		"%s ignores the mutated source humidity card" % context
	)
	_expect_string_name(
		sugar_phase.scenario.placement_zone_id,
		original_placement_zone_id,
		"%s exposes the original frozen sugar placement zone" % context
	)
	_expect_true(
		sugar_phase.scenario.placement_zone_id
			!= mutated_placement_zone_id,
		"%s ignores the mutated source sugar placement zone" % context
	)
	_expect_true(
		simulation.submit_place_sugar_action(),
		"%s submits sugar through the frozen phase gate" % context
	)
	var pending_sugar: GameSnapshot = simulation.create_game_snapshot()
	_expect_int(
		pending_sugar.colony.food_sources.size(),
		0,
		"%s does not place sugar on the submission Tick" % context
	)
	_expect_true(
		simulation.advance_tick(pending_sugar.simulation_tick + 1),
		"%s places sugar on the next fixed Tick" % context
	)
	var sugar_applied: GameSnapshot = simulation.create_game_snapshot()
	_expect_int(
		sugar_applied.colony.food_sources.size(),
		1,
		"%s creates one frozen sugar source" % context
	)
	if not sugar_applied.colony.food_sources.is_empty():
		_expect_string_name(
			sugar_applied.colony.food_sources[0].zone_id,
			original_placement_zone_id,
			"%s places sugar at the original frozen zone" % context
		)
		_expect_true(
			sugar_applied.colony.food_sources[0].zone_id
				!= mutated_placement_zone_id,
			"%s does not place sugar at the mutated source zone" % context
		)

	var expected_completion_tick: int = (
		sugar_applied.simulation_tick
		+ int(expected["foraging_cycle_ticks"])
	)
	_expect_true(
		_advance_to_tick(simulation, expected_completion_tick - 1),
		"%s reaches the Tick before frozen foraging completion" % context
	)
	var before_completion: GameSnapshot = simulation.create_game_snapshot()
	_expect_int(
		before_completion.sequence.phase,
		ScenarioSequenceSnapshot.Phase.SUGAR_FORAGING,
		"%s remains in foraging before the frozen duration boundary"
		% context
	)
	_expect_true(
		not before_completion.observations.has_card(original_sugar_card_id),
		"%s keeps the original sugar card locked before completion"
		% context
	)
	_expect_true(
		simulation.advance_tick(expected_completion_tick),
		"%s accepts the frozen foraging completion Tick" % context
	)
	var completed: GameSnapshot = simulation.create_game_snapshot()
	_expect_int(
		completed.sequence.phase,
		ScenarioSequenceSnapshot.Phase.OBSERVATION_SUMMARY,
		"%s reaches summary on the original frozen foraging boundary"
		% context
	)
	_expect_int(
		completed.sequence.sugar_observation_completed_tick,
		expected_completion_tick,
		"%s records the original frozen sugar completion Tick" % context
	)
	for card_id: StringName in [
		original_first_card_id,
		original_humidity_card_id,
		original_sugar_card_id,
	]:
		_expect_true(
			completed.observations.has_card(card_id),
			"%s contains original frozen card %s"
			% [context, String(card_id)]
		)
	for card_id: StringName in [
		mutated_first_card_id,
		mutated_humidity_card_id,
		mutated_sugar_card_id,
	]:
		_expect_true(
			not completed.observations.has_card(card_id),
			"%s excludes mutated source card %s"
			% [context, String(card_id)]
		)
	_expect_int(
		completed.observations.unlocked_card_ids.size(),
		3,
		"%s retains exactly the three frozen cards" % context
	)
	return {
		"first_worker_id": first_worker_id,
		"emergence_tick": emerged.sequence.first_worker_emerged_tick,
		"completion_tick": completed.simulation_tick,
		"signature": _combined_signature(completed),
	}


func _deep_duplicate_combined_scenario() -> HabitatScenarioData:
	var duplicate: HabitatScenarioData = (
		COMBINED_SCENARIO_DATA.duplicate(true) as HabitatScenarioData
	)
	var duplicated_zones: Array[HabitatZoneData] = []
	for source_zone: HabitatZoneData in COMBINED_SCENARIO_DATA.zones:
		duplicated_zones.append(
			source_zone.duplicate(true) as HabitatZoneData
		)
	duplicate.zones = duplicated_zones
	duplicate.sequence_data = (
		COMBINED_SCENARIO_DATA.sequence_data.duplicate(true)
		as ScenarioSequenceData
	)
	duplicate.foraging_data = (
		COMBINED_SCENARIO_DATA.foraging_data.duplicate(true)
		as ForagingData
	)
	return duplicate


func _find_alternate_zone_id(
	scenario_data: HabitatScenarioData,
	excluded_zone_ids: Array[StringName]
) -> StringName:
	for zone_data: HabitatZoneData in scenario_data.zones:
		if (
			zone_data != null
			and not excluded_zone_ids.has(zone_data.zone_id)
		):
			return zone_data.zone_id
	return &""


func _create_simulation() -> ColonySimulation:
	var simulation: ColonySimulation = ColonySimulation.new(
		SPECIES_A_DATA,
		COMBINED_SCENARIO_DATA
	)
	_expect_true(
		simulation.is_ready(),
		"the canonical combined Resources initialize the simulation"
	)
	return simulation


func _get_first_worker_emergence_tick() -> int:
	return (
		SPECIES_A_DATA.pupa_duration_ticks
		- COMBINED_SCENARIO_DATA.sequence_data
			.first_worker_initial_pupa_age_ticks
	)


func _get_session_deadline_tick() -> int:
	var relocation_cycle_ticks: int = (
		SPECIES_A_DATA.travel_duration_ticks * 2
		+ SPECIES_A_DATA.pickup_duration_ticks
		+ SPECIES_A_DATA.drop_duration_ticks
		+ SPECIES_A_DATA.decision_interval_ticks
	)
	var foraging_data: ForagingData = COMBINED_SCENARIO_DATA.foraging_data
	var foraging_cycle_ticks: int = (
		foraging_data.discovery_delay_ticks
		+ foraging_data.outbound_travel_duration_ticks
		+ foraging_data.collection_duration_ticks
		+ foraging_data.return_travel_duration_ticks
		+ foraging_data.sharing_duration_ticks
	)
	return (
		_get_first_worker_emergence_tick()
		+ (
			COMBINED_SCENARIO_DATA.initial_brood_count + 1
		) * relocation_cycle_ticks
		+ COMBINED_SCENARIO_DATA.observation_stable_ticks
		+ foraging_cycle_ticks
		+ SPECIES_A_DATA.decision_interval_ticks
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
				"sequential combined simulation Tick is accepted",
				"true",
				"false at Tick %d" % next_tick
			)
			return false
		next_tick += 1
	return true


func _advance_until_water_available(
	simulation: ColonySimulation
) -> GameSnapshot:
	var snapshot: GameSnapshot = simulation.create_game_snapshot()
	while (
		not snapshot.colony.water_action_available
		and snapshot.simulation_tick < _get_session_deadline_tick()
	):
		if not simulation.advance_tick(snapshot.simulation_tick + 1):
			_record_failure(
				"combined relocation reaches the water gate",
				"a sequential Tick",
				"rejected Tick %d" % (snapshot.simulation_tick + 1)
			)
			return simulation.create_game_snapshot()
		snapshot = simulation.create_game_snapshot()
	if not snapshot.colony.water_action_available:
		_record_failure(
			"combined relocation reaches the water gate",
			"available by Tick %d" % _get_session_deadline_tick(),
			"still unavailable"
		)
	return snapshot


func _advance_automatically_to_phase(
	simulation: ColonySimulation,
	target_phase: ScenarioSequenceSnapshot.Phase
) -> GameSnapshot:
	var snapshot: GameSnapshot = simulation.create_game_snapshot()
	while (
		snapshot.sequence.phase != target_phase
		and snapshot.simulation_tick < _get_session_deadline_tick()
	):
		if not _submit_available_action(simulation):
			_record_failure(
				"combined automatic command is accepted",
				"true",
				"false at Tick %d" % snapshot.simulation_tick
			)
			return simulation.create_game_snapshot()
		if not simulation.advance_tick(snapshot.simulation_tick + 1):
			_record_failure(
				"combined automatic phase advance accepts its Tick",
				"true",
				"false at Tick %d" % (snapshot.simulation_tick + 1)
			)
			return simulation.create_game_snapshot()
		snapshot = simulation.create_game_snapshot()
	if snapshot.sequence.phase != target_phase:
		_record_failure(
			"combined sequence reaches requested phase",
			str(target_phase),
			str(snapshot.sequence.phase)
		)
	return snapshot


func _complete_session(simulation: ColonySimulation) -> GameSnapshot:
	var snapshot: GameSnapshot = simulation.create_game_snapshot()
	while (
		not snapshot.sequence.completed
		and snapshot.simulation_tick < _get_session_deadline_tick()
	):
		if not _submit_available_action(simulation):
			_record_failure(
				"combined automatic command is accepted",
				"true",
				"false at Tick %d" % snapshot.simulation_tick
			)
			return simulation.create_game_snapshot()
		if not simulation.advance_tick(snapshot.simulation_tick + 1):
			_record_failure(
				"combined session accepts every sequential Tick",
				"true",
				"false at Tick %d" % (snapshot.simulation_tick + 1)
			)
			return simulation.create_game_snapshot()
		snapshot = simulation.create_game_snapshot()
	if not snapshot.sequence.completed:
		_record_failure(
			"combined session reaches observation summary",
			"completed by Tick %d" % _get_session_deadline_tick(),
			"phase %d at Tick %d"
			% [snapshot.sequence.phase, snapshot.simulation_tick]
		)
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


func _run_with_clock_speed(speed_multiplier: int) -> Dictionary:
	var simulation: ColonySimulation = ColonySimulation.new(
		SPECIES_A_DATA,
		COMBINED_SCENARIO_DATA
	)
	var clock: SimulationClock = SimulationClock.new()
	var status: Dictionary = {
		"ticks_accepted": true,
		"commands_accepted": true,
	}
	var trace: PackedStringArray = [
		_combined_signature(simulation.create_game_snapshot()),
	]
	var tick_callback: Callable = (
		func(tick_index: int, _tick_seconds: float) -> void:
			if not simulation.advance_tick(tick_index):
				status["ticks_accepted"] = false
				clock.set_paused(true)
				return
			var snapshot: GameSnapshot = simulation.create_game_snapshot()
			trace.append(_combined_signature(snapshot))
			if snapshot.sequence.completed:
				clock.set_paused(true)
				return
			if not _submit_available_action(simulation):
				status["commands_accepted"] = false
				clock.set_paused(true)
	)
	clock.tick_requested.connect(tick_callback)
	var speed_accepted: bool = clock.set_speed_multiplier(speed_multiplier)
	var maximum_backlog: int = 0
	var frame_count: int = 0
	var maximum_frame_count: int = _get_session_deadline_tick()
	while (
		not clock.is_paused()
		and frame_count < maximum_frame_count
	):
		clock.advance(CLOCK_FRAME_DELTA_SECONDS)
		maximum_backlog = maxi(
			maximum_backlog,
			clock.get_backlog_tick_count()
		)
		while (
			not clock.is_paused()
			and clock.get_backlog_tick_count() > 0
		):
			clock.advance(0.0)
		frame_count += 1

	var final_snapshot: GameSnapshot = simulation.create_game_snapshot()
	# The callback deliberately captures its signal owner so that it can pause the
	# clock. Disconnect it before these local RefCounted objects leave scope;
	# otherwise Godot cannot collect the resulting reference cycle at test exit.
	clock.tick_requested.disconnect(tick_callback)
	return {
		"ready": simulation.is_ready() and speed_accepted,
		"ticks_accepted": bool(status["ticks_accepted"]),
		"commands_accepted": bool(status["commands_accepted"]),
		"completed": (
			final_snapshot.sequence != null
			and final_snapshot.sequence.completed
		),
		"speed": speed_multiplier,
		"tick": final_snapshot.simulation_tick,
		"signature": _combined_signature(final_snapshot),
		"trace_digest": "\n--tick--\n".join(trace).sha256_text(),
		"maximum_backlog": maximum_backlog,
	}


func _expect_initial_combined_snapshot(
	snapshot: GameSnapshot,
	context: String
) -> void:
	_expect_true(snapshot != null, "%s exposes a game snapshot" % context)
	if snapshot == null:
		return
	_expect_int(snapshot.simulation_tick, 0, "%s resets fixed time" % context)
	_expect_true(snapshot.sequence != null, "%s restores sequence state" % context)
	if snapshot.sequence == null:
		return
	_expect_int(
		snapshot.sequence.phase,
		ScenarioSequenceSnapshot.Phase.FOUNDING_PRELUDE,
		"%s restores the founding prelude" % context
	)
	_expect_int(
		snapshot.sequence.phase_entered_tick,
		0,
		"%s resets the phase entry Tick" % context
	)
	_expect_int(
		snapshot.sequence.first_worker_emerged_tick,
		-1,
		"%s clears the prior emergence Tick" % context
	)
	_expect_int(
		snapshot.sequence.humidity_observation_completed_tick,
		-1,
		"%s clears the prior humidity completion Tick" % context
	)
	_expect_int(
		snapshot.sequence.sugar_observation_completed_tick,
		-1,
		"%s clears the prior sugar completion Tick" % context
	)
	_expect_true(
		not snapshot.sequence.continue_action_available,
		"%s locks continue before emergence" % context
	)
	_expect_true(
		not snapshot.sequence.continue_action_pending,
		"%s clears pending continue" % context
	)
	_expect_true(not snapshot.sequence.completed, "%s clears completion" % context)
	_expect_int(
		snapshot.colony.food_sources.size(),
		0,
		"%s removes prior food sources" % context
	)
	_expect_int(
		snapshot.colony.humidity_adjustment_count,
		0,
		"%s restores initial humidity action count" % context
	)
	_expect_true(
		not snapshot.colony.water_action_unlocked,
		"%s restores the initial water gate" % context
	)
	_expect_true(
		not snapshot.colony.water_action_pending,
		"%s clears pending water" % context
	)
	_expect_true(
		not snapshot.scenario.place_action_pending,
		"%s clears pending sugar" % context
	)
	_expect_int(
		snapshot.scenario.place_action_count,
		0,
		"%s clears applied sugar count" % context
	)
	_expect_int(
		snapshot.observations.events.size(),
		0,
		"%s clears the event journal" % context
	)
	_expect_int(
		snapshot.observations.unlocked_card_ids.size(),
		0,
		"%s clears observation cards" % context
	)
	var first_worker: AntSnapshot = snapshot.colony.find_ant(
		snapshot.sequence.first_worker_entity_id
	)
	_expect_true(
		first_worker != null,
		"%s restores the first-worker entity" % context
	)
	if first_worker != null:
		_expect_int(
			first_worker.life_stage,
			AntModel.LifeStage.PUPA,
			"%s restores the first worker as a pupa" % context
		)
		_expect_int(
			first_worker.stage_age_ticks,
			COMBINED_SCENARIO_DATA.sequence_data
				.first_worker_initial_pupa_age_ticks,
			"%s restores the frozen initial pupa age" % context
		)


func _combined_signature(snapshot: GameSnapshot) -> String:
	if snapshot == null:
		return "<null-combined-snapshot>"
	var sequence_signature: String = "sequence|null"
	if snapshot.sequence != null:
		sequence_signature = (
			(
				"sequence|id=%s|phase=%d|entered=%d|first=%d"
				+ "|emerged=%d|humidity=%d|sugar=%d"
				+ "|first_card=%s|humidity_card=%s|sugar_card=%s"
				+ "|continue_available=%s|continue_pending=%s"
				+ "|completed=%s"
			)
			% [
				String(snapshot.sequence.scenario_id),
				snapshot.sequence.phase,
				snapshot.sequence.phase_entered_tick,
				snapshot.sequence.first_worker_entity_id,
				snapshot.sequence.first_worker_emerged_tick,
				snapshot.sequence.humidity_observation_completed_tick,
				snapshot.sequence.sugar_observation_completed_tick,
				String(
					snapshot.sequence.first_worker_observation_card_id
				),
				String(
					snapshot.sequence.brood_humidity_observation_card_id
				),
				String(
					snapshot.sequence.sugar_foraging_observation_card_id
				),
				str(snapshot.sequence.continue_action_available),
				str(snapshot.sequence.continue_action_pending),
				str(snapshot.sequence.completed),
			]
		)
	return (
		SimulationSnapshotSignature.canonical_game_snapshot(snapshot)
		+ "\n"
		+ sequence_signature
	)


func _get_combined_invariant_failure(snapshot: GameSnapshot) -> String:
	if (
		snapshot == null
		or snapshot.colony == null
		or snapshot.scenario == null
		or snapshot.observations == null
		or snapshot.sequence == null
	):
		return "combined snapshot is missing a required domain"

	var known_zone_ids: Dictionary[StringName, bool] = {}
	for zone: HabitatZoneSnapshot in snapshot.colony.zones:
		if known_zone_ids.has(zone.zone_id):
			return "zone %s appears more than once" % String(zone.zone_id)
		if is_nan(zone.humidity) or is_inf(zone.humidity):
			return "zone %s has non-finite humidity" % String(zone.zone_id)
		if zone.humidity < 0.0 or zone.humidity > 1.0:
			return "zone %s humidity is outside 0..1" % String(zone.zone_id)
		known_zone_ids[zone.zone_id] = true

	var brood_reservation_counts: Dictionary[int, int] = {}
	var brood_carrier_counts: Dictionary[int, int] = {}
	var active_workers_by_source: Dictionary[int, int] = {}
	var carrying_workers_by_source: Dictionary[int, int] = {}
	var carried_sugar_portions: int = 0
	for worker: AntSnapshot in snapshot.colony.ants:
		if worker.life_stage != AntModel.LifeStage.WORKER:
			continue
		if not known_zone_ids.has(worker.zone_id):
			return "worker %d has no valid zone" % worker.entity_id
		if worker.foraging_task == null:
			return "worker %d has no foraging task" % worker.entity_id
		var relocation_active: bool = (
			worker.worker_task_state != WorkerTaskModel.State.IDLE
		)
		var foraging_active: bool = (
			worker.foraging_task.state != ForagingTaskModel.State.IDLE
		)
		if relocation_active and foraging_active:
			return "worker %d owns both active task types" % worker.entity_id

		if not relocation_active:
			if (
				worker.target_brood_id != NO_ENTITY_ID
				or worker.carried_brood_id != NO_ENTITY_ID
				or not worker.target_zone_id.is_empty()
				or not worker.task_origin_zone_id.is_empty()
			):
				return "idle relocation worker %d retains task state" % (
					worker.entity_id
				)
		else:
			if worker.target_brood_id < 0:
				return "active worker %d has no target brood" % worker.entity_id
			brood_reservation_counts[worker.target_brood_id] = (
				brood_reservation_counts.get(worker.target_brood_id, 0) + 1
			)
			if worker.carried_brood_id >= 0:
				brood_carrier_counts[worker.carried_brood_id] = (
					brood_carrier_counts.get(worker.carried_brood_id, 0) + 1
				)

		var foraging_task: ForagingTaskSnapshot = worker.foraging_task
		if not foraging_active:
			if (
				foraging_task.target_food_source_id != NO_ENTITY_ID
				or foraging_task.carried_portions != 0
				or foraging_task.elapsed_ticks != 0
				or foraging_task.duration_ticks != 0
				or not foraging_task.route_zone_ids.is_empty()
			):
				return "idle foraging worker %d retains task state" % (
					worker.entity_id
				)
		else:
			if (
				active_workers_by_source.has(
					foraging_task.target_food_source_id
				)
			):
				return "food source %d has multiple active workers" % (
					foraging_task.target_food_source_id
				)
			active_workers_by_source[
				foraging_task.target_food_source_id
			] = worker.entity_id
			if (
				foraging_task.carried_portions < 0
				or foraging_task.carried_portions > 1
			):
				return "worker %d has an invalid carried sugar amount" % (
					worker.entity_id
				)
			if foraging_task.carried_portions == 1:
				if (
					carrying_workers_by_source.has(
						foraging_task.target_food_source_id
					)
				):
					return "food source %d has multiple carriers" % (
						foraging_task.target_food_source_id
					)
				carrying_workers_by_source[
					foraging_task.target_food_source_id
				] = worker.entity_id
				carried_sugar_portions += 1

	for brood: AntSnapshot in snapshot.colony.ants:
		if brood.life_stage == AntModel.LifeStage.WORKER:
			continue
		var reservation_count: int = brood_reservation_counts.get(
			brood.entity_id,
			0
		)
		var carrier_count: int = brood_carrier_counts.get(
			brood.entity_id,
			0
		)
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
				return "uncarried brood %d has no valid zone" % brood.entity_id
			if brood.carrier_ant_id != NO_ENTITY_ID:
				return "uncarried brood %d retains a carrier" % brood.entity_id
		if reservation_count == 0 and brood.reserved_by_ant_id != NO_ENTITY_ID:
			return "brood %d retains an orphan reservation" % brood.entity_id
		if (
			reservation_count == 1
			and brood.reserved_by_ant_id == NO_ENTITY_ID
		):
			return "brood %d is targeted without a reservation" % brood.entity_id

	var remaining_sugar_portions: int = 0
	var known_source_ids: Dictionary[int, bool] = {}
	for source: FoodSourceSnapshot in snapshot.colony.food_sources:
		if known_source_ids.has(source.food_source_id):
			return "food source %d appears more than once" % source.food_source_id
		known_source_ids[source.food_source_id] = true
		if source.remaining_portions < 0:
			return "food source %d has a negative amount" % source.food_source_id
		remaining_sugar_portions += source.remaining_portions
		var expected_reserver: int = active_workers_by_source.get(
			source.food_source_id,
			NO_ENTITY_ID
		)
		if source.reserved_by_worker_id != expected_reserver:
			return "food source %d reservation disagrees with its task" % (
				source.food_source_id
			)
		var expected_carrier: int = carrying_workers_by_source.get(
			source.food_source_id,
			NO_ENTITY_ID
		)
		if source.carrier_worker_id != expected_carrier:
			return "food source %d carrier disagrees with its task" % (
				source.food_source_id
			)
	for source_id: int in active_workers_by_source:
		if not known_source_ids.has(source_id):
			return "foraging task targets missing source %d" % source_id

	var shared_sugar_portions: int = _count_event_type(
		snapshot.observations.events,
		ObservationEvent.Type.SUGAR_SHARED
	)
	var expected_sugar_portions: int = (
		snapshot.scenario.place_action_count
		* COMBINED_SCENARIO_DATA.sugar_portions
	)
	if (
		remaining_sugar_portions
		+ carried_sugar_portions
		+ shared_sugar_portions
		!= expected_sugar_portions
	):
		return (
			"sugar conservation is %d remaining + %d carried + %d shared != %d"
			% [
				remaining_sugar_portions,
				carried_sugar_portions,
				shared_sugar_portions,
				expected_sugar_portions,
			]
		)
	return ""


func _get_expected_card_ids() -> Array[StringName]:
	var card_ids: Array[StringName] = [
		COMBINED_SCENARIO_DATA.sequence_data
			.first_worker_observation_card_id,
		COMBINED_SCENARIO_DATA.sequence_data
			.brood_humidity_observation_card_id,
		COMBINED_SCENARIO_DATA.foraging_observation_card_id,
	]
	card_ids.sort_custom(
		func(first: StringName, second: StringName) -> bool:
			return String(first) < String(second)
	)
	return card_ids


func _get_combined_intermediate_zone_id(
	scenario: HabitatScenarioData
) -> StringName:
	if scenario == null:
		return &""
	for zone: HabitatZoneData in scenario.zones:
		if (
			zone != null
			and zone.zone_id != scenario.nest_zone_id
			and zone.zone_id != scenario.sugar_placement_zone_id
		):
			return zone.zone_id
	return &""


func _find_zone_data(
	scenario: HabitatScenarioData,
	zone_id: StringName
) -> HabitatZoneData:
	if scenario == null:
		return null
	for zone: HabitatZoneData in scenario.zones:
		if zone != null and zone.zone_id == zone_id:
			return zone
	return null


func _find_event(
	events: Array[ObservationEvent],
	event_type: int
) -> ObservationEvent:
	for event: ObservationEvent in events:
		if event != null and event.event_type == event_type:
			return event
	return null


func _count_event_type(
	events: Array[ObservationEvent],
	event_type: int
) -> int:
	var count: int = 0
	for event: ObservationEvent in events:
		if event != null and event.event_type == event_type:
			count += 1
	return count


func _count_entity_id(snapshot: ColonySnapshot, entity_id: int) -> int:
	var count: int = 0
	for ant: AntSnapshot in snapshot.ants:
		if ant.entity_id == entity_id:
			count += 1
	return count


func _zone_humidity(
	snapshot: ColonySnapshot,
	zone_id: StringName
) -> float:
	var zone: HabitatZoneSnapshot = snapshot.find_zone(zone_id)
	if zone == null:
		return -1.0
	return zone.humidity


func _card_signature(card_ids: Array[StringName]) -> String:
	var card_names: PackedStringArray = []
	for card_id: StringName in card_ids:
		card_names.append(String(card_id))
	card_names.sort()
	return ",".join(card_names)


func _int_array_signature(values: Array) -> String:
	var parts: PackedStringArray = []
	for value: Variant in values:
		parts.append(str(int(value)))
	return ",".join(parts)


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
