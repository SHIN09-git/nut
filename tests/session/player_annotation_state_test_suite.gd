class_name PlayerAnnotationStateTestSuite
extends RefCounted

var _assertion_count: int = 0
var _failure_count: int = 0


func run() -> void:
	_test_selection_uses_stable_worker_ids()
	_test_names_are_optional_and_bounded()
	_test_events_are_copied_filtered_and_deduplicated()
	_test_recent_history_is_bounded_per_worker()
	_test_event_gap_is_reported()
	_test_missing_workers_and_reset_clear_annotations()


func get_assertion_count() -> int:
	return _assertion_count


func get_failure_count() -> int:
	return _failure_count


func _test_selection_uses_stable_worker_ids() -> void:
	var state: PlayerAnnotationState = PlayerAnnotationState.new()
	var snapshot: ColonySnapshot = _create_snapshot([10, 20], [30])
	state.reconcile(snapshot)

	_expect_true(
		state.select_worker(20, snapshot),
		"a worker can be selected by stable entity ID"
	)
	_expect_int(
		state.get_selected_worker_id(),
		20,
		"selection stores the requested worker ID"
	)

	var next_snapshot: ColonySnapshot = _create_snapshot([10, 20], [30])
	next_snapshot.simulation_tick = 1
	state.reconcile(next_snapshot)
	_expect_int(
		state.get_selected_worker_id(),
		20,
		"selection remains stable across consecutive snapshots"
	)
	_expect_true(
		not state.select_worker(30, next_snapshot),
		"brood cannot replace the selected worker"
	)
	_expect_int(
		state.get_selected_worker_id(),
		20,
		"an invalid selection request preserves the current worker"
	)


func _test_names_are_optional_and_bounded() -> void:
	var state: PlayerAnnotationState = PlayerAnnotationState.new()
	var snapshot: ColonySnapshot = _create_snapshot([10], [])
	state.reconcile(snapshot)
	state.select_worker(10, snapshot)

	_expect_true(
		state.set_selected_worker_name("  小栗  "),
		"a selected worker accepts an optional name"
	)
	_expect_string(
		state.get_worker_name(10),
		"小栗",
		"worker names are trimmed before storage"
	)

	state.set_selected_worker_name("12345678901234567890")
	_expect_int(
		state.get_worker_name(10).length(),
		PlayerAnnotationState.MAX_WORKER_NAME_LENGTH,
		"worker names are bounded for the observation panel"
	)

	_expect_true(
		state.set_selected_worker_name(""),
		"an empty name is accepted as a clear action"
	)
	_expect_string(
		state.get_worker_name(10),
		"",
		"an empty name removes the annotation"
	)

	state.clear_selection()
	_expect_true(
		not state.set_selected_worker_name("悬空名称"),
		"naming is rejected when no worker is selected"
	)
	_expect_string(
		state.get_worker_name(10),
		"",
		"a rejected name does not recreate an annotation"
	)


func _test_events_are_copied_filtered_and_deduplicated() -> void:
	var state: PlayerAnnotationState = PlayerAnnotationState.new()
	var snapshot: ColonySnapshot = _create_snapshot([10, 20], [30])
	var first_event: ObservationEvent = _create_event(1, 10)
	snapshot.observation_events = [
		first_event,
		_create_event(2, 20),
		_create_event(3, 10),
		ObservationEvent.new(
			4,
			4,
			ObservationEvent.Type.BROOD_HUMIDITY_OBSERVATION_COMPLETED
		),
	]

	state.reconcile(snapshot)
	_expect_int(
		state.get_last_consumed_event_id(),
		4,
		"the global event cursor consumes worker and global events"
	)
	_expect_true(
		not state.has_event_gap(),
		"a contiguous first batch does not report an event gap"
	)

	var worker_ten_events: Array[ObservationEvent] = state.get_recent_events(10)
	var worker_twenty_events: Array[ObservationEvent] = state.get_recent_events(20)
	_expect_int(
		worker_ten_events.size(),
		2,
		"history keeps only events acted by worker 10"
	)
	_expect_int(
		worker_twenty_events.size(),
		1,
		"history keeps only events acted by worker 20"
	)
	_expect_int(
		worker_ten_events[0].event_id,
		1,
		"selected-worker history preserves event order"
	)
	_expect_int(
		worker_ten_events[1].event_id,
		3,
		"later events remain after actor filtering"
	)

	first_event.event_id = 99
	worker_ten_events[0].event_id = 88
	_expect_int(
		state.get_recent_events(10)[0].event_id,
		1,
		"both snapshot events and returned history are copy isolated"
	)

	first_event.event_id = 1
	state.reconcile(snapshot)
	_expect_int(
		state.get_recent_events(10).size(),
		2,
		"reapplying a snapshot does not duplicate consumed event IDs"
	)


func _test_recent_history_is_bounded_per_worker() -> void:
	var state: PlayerAnnotationState = PlayerAnnotationState.new()
	var snapshot: ColonySnapshot = _create_snapshot([10, 20], [])
	for event_id: int in range(1, 8):
		snapshot.observation_events.append(_create_event(event_id, 10))
	for event_id: int in range(8, 10):
		snapshot.observation_events.append(_create_event(event_id, 20))

	state.reconcile(snapshot)
	var worker_ten_events: Array[ObservationEvent] = state.get_recent_events(10)
	_expect_int(
		worker_ten_events.size(),
		PlayerAnnotationState.MAX_RECENT_EVENTS_PER_WORKER,
		"each worker retains at most five recent events"
	)
	_expect_int(
		worker_ten_events[0].event_id,
		3,
		"bounded history removes the oldest worker event first"
	)
	_expect_int(
		worker_ten_events[-1].event_id,
		7,
		"bounded history retains the newest worker event"
	)
	_expect_int(
		state.get_recent_events(20).size(),
		2,
		"history bounds are maintained independently per worker"
	)


func _test_event_gap_is_reported() -> void:
	var state: PlayerAnnotationState = PlayerAnnotationState.new()
	var snapshot: ColonySnapshot = _create_snapshot([10], [])
	snapshot.observation_events = [
		_create_event(4, 10),
		_create_event(3, 10),
		_create_event(4, 10),
	]

	state.reconcile(snapshot)
	var recent_events: Array[ObservationEvent] = state.get_recent_events(10)
	_expect_true(
		state.has_event_gap(),
		"a retained batch beginning after event 1 reports a gap"
	)
	_expect_int(
		state.get_last_consumed_event_id(),
		4,
		"an out-of-order batch advances to its largest event ID"
	)
	_expect_int(
		recent_events.size(),
		2,
		"duplicate IDs in the same batch are consumed only once"
	)
	_expect_int(
		recent_events[0].event_id,
		3,
		"out-of-order events are normalized into event ID order"
	)


func _test_missing_workers_and_reset_clear_annotations() -> void:
	var state: PlayerAnnotationState = PlayerAnnotationState.new()
	var first_snapshot: ColonySnapshot = _create_snapshot([10, 20], [])
	first_snapshot.observation_events = [_create_event(1, 10)]
	state.reconcile(first_snapshot)
	state.select_worker(10, first_snapshot)
	state.set_selected_worker_name("小栗")

	var removed_snapshot: ColonySnapshot = _create_snapshot([20], [])
	removed_snapshot.simulation_tick = 1
	removed_snapshot.observation_events = first_snapshot.observation_events
	state.reconcile(removed_snapshot)
	_expect_int(
		state.get_selected_worker_id(),
		-1,
		"a removed worker cannot leave a dangling selection"
	)
	_expect_string(
		state.get_worker_name(10),
		"",
		"a removed worker cannot leave a dangling name"
	)
	_expect_int(
		state.get_recent_events(10).size(),
		0,
		"a removed worker cannot leave dangling history"
	)

	state.select_worker(20, removed_snapshot)
	state.set_selected_worker_name("第二只")
	state.reset_session()
	_expect_int(
		state.get_selected_worker_id(),
		-1,
		"session reset clears the selected worker"
	)
	_expect_string(
		state.get_worker_name(20),
		"",
		"session reset clears all worker names"
	)
	_expect_int(
		state.get_last_consumed_event_id(),
		0,
		"session reset restores the event cursor"
	)
	_expect_true(
		not state.has_event_gap(),
		"session reset clears an event-gap diagnostic"
	)


func _create_snapshot(
	worker_ids: Array[int],
	brood_ids: Array[int]
) -> ColonySnapshot:
	var snapshot: ColonySnapshot = ColonySnapshot.new()
	for worker_id: int in worker_ids:
		snapshot.ants.append(
			AntSnapshot.new(
				worker_id,
				AntModel.LifeStage.WORKER,
				0,
				0,
				0,
				&"left"
			)
		)
	for brood_id: int in brood_ids:
		snapshot.ants.append(
			AntSnapshot.new(
				brood_id,
				AntModel.LifeStage.LARVA,
				0,
				0,
				0,
				&"left"
			)
		)
	return snapshot


func _create_event(event_id: int, actor_entity_id: int) -> ObservationEvent:
	return ObservationEvent.new(
		event_id,
		event_id,
		ObservationEvent.Type.RELOCATION_STARTED,
		actor_entity_id,
		30,
		&"left",
		&"right"
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


func _record_failure(message: String, expected: String, actual: String) -> void:
	_failure_count += 1
	printerr("  %s - expected %s, got %s" % [message, expected, actual])
