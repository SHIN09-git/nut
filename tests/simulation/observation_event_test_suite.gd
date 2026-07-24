class_name ObservationEventTestSuite
extends RefCounted

const SPECIES_A_DATA: SpeciesData = preload("res://data/species/species_a.tres")
const HUMIDITY_SCENARIO_DATA: HabitatScenarioData = preload(
	"res://data/habitats/humidity_relocation_slice.tres"
)
const LEFT_ZONE_ID: StringName = &"left_chamber"
const RIGHT_ZONE_ID: StringName = &"right_chamber"

var _assertion_count: int = 0
var _failure_count: int = 0


func run() -> void:
	_test_required_events_use_exact_transition_boundaries()
	_test_event_ids_are_monotonic_unique_and_stably_ordered()
	_test_rejected_tick_does_not_emit_or_consume_an_event_id()
	_test_event_snapshots_are_deep_copies()
	_test_event_history_is_bounded()
	_test_restart_clears_events_and_restarts_session_ids()
	_test_matching_inputs_produce_matching_event_signatures()
	_test_observation_completion_event_is_emitted_once()


func get_assertion_count() -> int:
	return _assertion_count


func get_failure_count() -> int:
	return _failure_count


func _test_required_events_use_exact_transition_boundaries() -> void:
	var simulation: ColonySimulation = _create_simulation()
	var assignment_tick: int = SPECIES_A_DATA.decision_interval_ticks
	var pickup_tick: int = (
		assignment_tick + SPECIES_A_DATA.travel_duration_ticks
	)
	var carry_tick: int = (
		pickup_tick + SPECIES_A_DATA.pickup_duration_ticks
	)
	var drop_tick: int = (
		carry_tick
		+ SPECIES_A_DATA.travel_duration_ticks
		+ SPECIES_A_DATA.drop_duration_ticks
	)
	_advance_to_tick(simulation, drop_tick)
	var events: Array[ObservationEvent] = (
		simulation.create_snapshot().observation_events
	)
	var first_worker_id: int = 1
	var first_brood_id: int = (
		HUMIDITY_SCENARIO_DATA.initial_worker_count + 1
	)

	_expect_int(
		events.size(),
		HUMIDITY_SCENARIO_DATA.initial_worker_count * 4,
		"the first relocation wave emits four required events per worker"
	)
	_expect_event(
		_find_event(
			events,
			ObservationEvent.Type.RELOCATION_STARTED,
			first_worker_id
		),
		1,
		assignment_tick,
		ObservationEvent.Type.RELOCATION_STARTED,
		first_worker_id,
		first_brood_id,
		LEFT_ZONE_ID,
		RIGHT_ZONE_ID,
		"relocation start"
	)
	_expect_event(
		_find_event(
			events,
			ObservationEvent.Type.BROOD_PICKUP_STARTED,
			first_worker_id
		),
		HUMIDITY_SCENARIO_DATA.initial_worker_count + 1,
		pickup_tick,
		ObservationEvent.Type.BROOD_PICKUP_STARTED,
		first_worker_id,
		first_brood_id,
		LEFT_ZONE_ID,
		RIGHT_ZONE_ID,
		"brood pickup start"
	)
	_expect_event(
		_find_event(
			events,
			ObservationEvent.Type.BROOD_CARRY_STARTED,
			first_worker_id
		),
		HUMIDITY_SCENARIO_DATA.initial_worker_count * 2 + 1,
		carry_tick,
		ObservationEvent.Type.BROOD_CARRY_STARTED,
		first_worker_id,
		first_brood_id,
		LEFT_ZONE_ID,
		RIGHT_ZONE_ID,
		"brood carry start"
	)
	_expect_event(
		_find_event(
			events,
			ObservationEvent.Type.BROOD_DROPPED,
			first_worker_id
		),
		HUMIDITY_SCENARIO_DATA.initial_worker_count * 3 + 1,
		drop_tick,
		ObservationEvent.Type.BROOD_DROPPED,
		first_worker_id,
		first_brood_id,
		LEFT_ZONE_ID,
		RIGHT_ZONE_ID,
		"brood drop"
	)


func _test_event_ids_are_monotonic_unique_and_stably_ordered() -> void:
	var simulation: ColonySimulation = _create_simulation()
	var second_wave_drop_tick: int = (
		SPECIES_A_DATA.decision_interval_ticks * 2
		+ SPECIES_A_DATA.travel_duration_ticks * 4
		+ SPECIES_A_DATA.pickup_duration_ticks * 2
		+ SPECIES_A_DATA.drop_duration_ticks * 2
	)
	_advance_to_tick(simulation, second_wave_drop_tick)
	var events: Array[ObservationEvent] = (
		simulation.create_snapshot().observation_events
	)
	var seen_ids: Dictionary[int, bool] = {}
	var previous_tick: int = -1
	for event_index: int in events.size():
		var event: ObservationEvent = events[event_index]
		_expect_int(
			event.event_id,
			event_index + 1,
			"event IDs are gap-free within the retained session history"
		)
		_expect_true(
			not seen_ids.has(event.event_id),
			"event IDs are unique"
		)
		seen_ids[event.event_id] = true
		_expect_true(
			event.tick >= previous_tick,
			"events remain ordered by non-decreasing fixed Tick"
		)
		previous_tick = event.tick

	for worker_index: int in HUMIDITY_SCENARIO_DATA.initial_worker_count:
		_expect_int(
			events[worker_index].actor_entity_id,
			worker_index + 1,
			"same-Tick relocation events follow stable worker ID order"
		)
		_expect_int(
			events[worker_index].subject_entity_id,
			HUMIDITY_SCENARIO_DATA.initial_worker_count
			+ worker_index
			+ 1,
			"same-Tick assignments follow stable brood ID order"
		)


func _test_rejected_tick_does_not_emit_or_consume_an_event_id() -> void:
	var simulation: ColonySimulation = _create_simulation()
	_expect_true(simulation.advance_tick(1), "the event rejection fixture accepts Tick 1")
	_expect_true(
		not simulation.advance_tick(3),
		"a skipped Tick is rejected before event generation"
	)
	_expect_int(
		simulation.create_snapshot().observation_events.size(),
		0,
		"a rejected Tick cannot append an event"
	)
	_advance_to_tick(simulation, SPECIES_A_DATA.decision_interval_ticks)
	var events: Array[ObservationEvent] = (
		simulation.create_snapshot().observation_events
	)
	_expect_true(not events.is_empty(), "the next valid event boundary is reached")
	if not events.is_empty():
		_expect_int(
			events[0].event_id,
			1,
			"a rejected Tick does not consume an event ID"
		)


func _test_event_snapshots_are_deep_copies() -> void:
	var simulation: ColonySimulation = _create_simulation()
	_advance_to_tick(simulation, SPECIES_A_DATA.decision_interval_ticks)
	var mutable_snapshot: ColonySnapshot = simulation.create_snapshot()
	_expect_true(
		not mutable_snapshot.observation_events.is_empty(),
		"snapshot isolation fixture contains an event"
	)
	if mutable_snapshot.observation_events.is_empty():
		return
	var original_signature: String = _event_signature(
		mutable_snapshot.observation_events
	)
	var mutable_event: ObservationEvent = mutable_snapshot.observation_events[0]
	mutable_event.event_id = 999
	mutable_event.tick = 999
	mutable_event.event_type = (
		ObservationEvent.Type.BROOD_HUMIDITY_OBSERVATION_COMPLETED
	)
	mutable_event.actor_entity_id = 999
	mutable_event.subject_entity_id = 999
	mutable_event.source_zone_id = &"mutated_source"
	mutable_event.target_zone_id = &"mutated_target"
	mutable_snapshot.observation_events.clear()

	var fresh_snapshot: ColonySnapshot = simulation.create_snapshot()
	_expect_string(
		_event_signature(fresh_snapshot.observation_events),
		original_signature,
		"mutating event fields and the snapshot array cannot change simulation history"
	)


func _test_event_history_is_bounded() -> void:
	var state: ColonyState = ColonyState.new()
	var event_count: int = ColonyState.MAX_RETAINED_OBSERVATION_EVENTS + 1
	for event_index: int in event_count:
		state.simulation_tick = event_index + 1
		state.record_observation_event(
			ObservationEvent.Type.RELOCATION_STARTED,
			event_index + 1,
			event_index + 101,
			LEFT_ZONE_ID,
			RIGHT_ZONE_ID
		)
	var events: Array[ObservationEvent] = state.copy_observation_events()

	_expect_int(
		events.size(),
		ColonyState.MAX_RETAINED_OBSERVATION_EVENTS,
		"event history retains only its explicit capacity"
	)
	_expect_int(events[0].event_id, 2, "history evicts the oldest event first")
	_expect_int(
		events[events.size() - 1].event_id,
		event_count,
		"history retains the newest event"
	)


func _test_restart_clears_events_and_restarts_session_ids() -> void:
	var simulation: ColonySimulation = _create_simulation()
	for restart_index: int in range(2):
		_advance_to_tick(simulation, SPECIES_A_DATA.decision_interval_ticks)
		var populated_events: Array[ObservationEvent] = (
			simulation.create_snapshot().observation_events
		)
		_expect_true(
			not populated_events.is_empty(),
			"session %d emits events before restart" % (restart_index + 1)
		)
		if not populated_events.is_empty():
			_expect_int(
				populated_events[0].event_id,
				1,
				"session %d begins event IDs at one" % (restart_index + 1)
			)
		_expect_true(
			simulation.restart_session(),
			"session %d restarts from frozen configuration"
			% (restart_index + 1)
		)
		var reset_snapshot: ColonySnapshot = simulation.create_snapshot()
		_expect_int(
			reset_snapshot.simulation_tick,
			0,
			"restart returns event time to Tick zero"
		)
		_expect_int(
			reset_snapshot.observation_events.size(),
			0,
			"restart removes all old-session events"
		)


func _test_matching_inputs_produce_matching_event_signatures() -> void:
	var first_simulation: ColonySimulation = _create_simulation()
	var second_simulation: ColonySimulation = _create_simulation()
	var target_tick: int = (
		SPECIES_A_DATA.decision_interval_ticks * 5
	)
	_advance_to_tick(first_simulation, target_tick)
	_advance_to_tick(second_simulation, target_tick)

	_expect_string(
		_event_signature(first_simulation.create_snapshot().observation_events),
		_event_signature(second_simulation.create_snapshot().observation_events),
		"matching fixed-Tick inputs produce identical structured event history"
	)


func _test_observation_completion_event_is_emitted_once() -> void:
	var simulation: ColonySimulation = _create_simulation()
	var first_drop_tick: int = (
		SPECIES_A_DATA.decision_interval_ticks
		+ SPECIES_A_DATA.travel_duration_ticks * 2
		+ SPECIES_A_DATA.pickup_duration_ticks
		+ SPECIES_A_DATA.drop_duration_ticks
	)
	_advance_to_tick(simulation, first_drop_tick)
	var water_action_count: int = _get_water_action_count_to_reach_comfort()
	for action_index: int in water_action_count:
		_expect_true(
			simulation.submit_water_action(),
			"configured water action %d is accepted" % (action_index + 1)
		)
		var before_tick: int = simulation.create_snapshot().simulation_tick
		_expect_true(
			simulation.advance_tick(before_tick + 1),
			"configured water action applies at the next fixed Tick"
		)

	var completion_deadline: int = (
		simulation.create_snapshot().simulation_tick
		+ SPECIES_A_DATA.minimum_zone_dwell_ticks
		+ SPECIES_A_DATA.decision_interval_ticks * 2
		+ SPECIES_A_DATA.travel_duration_ticks * 2
		+ SPECIES_A_DATA.pickup_duration_ticks
		+ SPECIES_A_DATA.drop_duration_ticks
		+ HUMIDITY_SCENARIO_DATA.observation_stable_ticks
		+ 100
	)
	var snapshot: ColonySnapshot = simulation.create_snapshot()
	while (
		not snapshot.brood_humidity_observation_unlocked
		and snapshot.simulation_tick < completion_deadline
	):
		if not simulation.advance_tick(snapshot.simulation_tick + 1):
			_record_failure(
				"observation completion fixture advances",
				"true",
				"false at Tick %d" % (snapshot.simulation_tick + 1)
			)
			return
		snapshot = simulation.create_snapshot()

	_expect_true(
		snapshot.brood_humidity_observation_unlocked,
		"the player path reaches observation completion"
	)
	var completion_event: ObservationEvent = _find_event(
		snapshot.observation_events,
		ObservationEvent.Type.BROOD_HUMIDITY_OBSERVATION_COMPLETED,
		ObservationEvent.NO_ENTITY_ID
	)
	_expect_true(completion_event != null, "completion emits its structured event")
	if completion_event != null:
		_expect_int(
			completion_event.tick,
			snapshot.simulation_tick,
			"completion event uses the exact unlock Tick"
		)
		_expect_int(
			completion_event.subject_entity_id,
			ObservationEvent.NO_ENTITY_ID,
			"global completion event has no biological subject"
		)
		_expect_true(
			completion_event.source_zone_id.is_empty()
			and completion_event.target_zone_id.is_empty(),
			"global completion event has no fabricated zone endpoints"
		)
	_expect_int(
		_count_event_type(
			snapshot.observation_events,
			ObservationEvent.Type.BROOD_HUMIDITY_OBSERVATION_COMPLETED
		),
		1,
		"completion event is emitted exactly once at unlock"
	)

	_advance_to_tick(simulation, snapshot.simulation_tick + 1_000)
	_expect_int(
		_count_event_type(
			simulation.create_snapshot().observation_events,
			ObservationEvent.Type.BROOD_HUMIDITY_OBSERVATION_COMPLETED
		),
		1,
		"completed observation does not emit again on later Ticks"
	)


func _create_simulation() -> ColonySimulation:
	return ColonySimulation.new(SPECIES_A_DATA, HUMIDITY_SCENARIO_DATA)


func _advance_to_tick(
	simulation: ColonySimulation,
	target_tick: int
) -> bool:
	var next_tick: int = simulation.create_snapshot().simulation_tick + 1
	while next_tick <= target_tick:
		if not simulation.advance_tick(next_tick):
			_record_failure(
				"sequential event fixture Tick is accepted",
				"true",
				"false at Tick %d" % next_tick
			)
			return false
		next_tick += 1
	return true


func _find_event(
	events: Array[ObservationEvent],
	event_type: ObservationEvent.Type,
	actor_entity_id: int
) -> ObservationEvent:
	for event: ObservationEvent in events:
		if (
			event.event_type == event_type
			and event.actor_entity_id == actor_entity_id
		):
			return event
	return null


func _count_event_type(
	events: Array[ObservationEvent],
	event_type: ObservationEvent.Type
) -> int:
	var count: int = 0
	for event: ObservationEvent in events:
		if event.event_type == event_type:
			count += 1
	return count


func _get_water_action_count_to_reach_comfort() -> int:
	var target_zone: HabitatZoneData = (
		HUMIDITY_SCENARIO_DATA.left_zone
		if HUMIDITY_SCENARIO_DATA.left_zone.zone_id
			== HUMIDITY_SCENARIO_DATA.humidity_adjustment_zone_id
		else HUMIDITY_SCENARIO_DATA.right_zone
	)
	var humidity_gap: float = maxf(
		SPECIES_A_DATA.brood_humidity_min - target_zone.initial_humidity,
		0.0
	)
	if humidity_gap <= 0.0:
		return 0
	return ceili(
		(humidity_gap - 0.000001)
		/ HUMIDITY_SCENARIO_DATA.humidity_adjustment_amount
	)


func _event_signature(events: Array[ObservationEvent]) -> String:
	var parts: PackedStringArray = []
	for event: ObservationEvent in events:
		parts.append(
			"%d:%d:%d:%d:%d:%s:%s"
			% [
				event.event_id,
				event.tick,
				event.event_type,
				event.actor_entity_id,
				event.subject_entity_id,
				String(event.source_zone_id),
				String(event.target_zone_id),
			]
		)
	return "|".join(parts)


func _expect_event(
	event: ObservationEvent,
	expected_event_id: int,
	expected_tick: int,
	expected_type: ObservationEvent.Type,
	expected_actor_id: int,
	expected_subject_id: int,
	expected_source_zone_id: StringName,
	expected_target_zone_id: StringName,
	message: String
) -> void:
	_expect_true(event != null, "%s event exists" % message)
	if event == null:
		return
	_expect_int(event.event_id, expected_event_id, "%s has the expected event ID" % message)
	_expect_int(event.tick, expected_tick, "%s uses the exact fixed Tick" % message)
	_expect_int(event.event_type, expected_type, "%s has the expected type" % message)
	_expect_int(event.actor_entity_id, expected_actor_id, "%s identifies its worker" % message)
	_expect_int(event.subject_entity_id, expected_subject_id, "%s identifies its brood" % message)
	_expect_string_name(
		event.source_zone_id,
		expected_source_zone_id,
		"%s identifies its source zone" % message
	)
	_expect_string_name(
		event.target_zone_id,
		expected_target_zone_id,
		"%s identifies its target zone" % message
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
	printerr("  %s - expected %s, got %s" % [message, expected, actual])
