class_name PlayerAnnotationState
extends RefCounted

const MAX_WORKER_NAME_LENGTH: int = 16
const MAX_RECENT_EVENTS_PER_WORKER: int = 5

var _selected_worker_entity_id: int = -1
var _worker_names: Dictionary[int, String] = {}
var _recent_events_by_worker: Dictionary[int, Array] = {}
var _last_consumed_event_id: int = 0
var _has_event_gap: bool = false
var _present_worker_ids: Dictionary[int, bool] = {}


func reset_session() -> void:
	_selected_worker_entity_id = -1
	_worker_names.clear()
	_recent_events_by_worker.clear()
	_last_consumed_event_id = 0
	_has_event_gap = false
	_present_worker_ids.clear()


func reconcile(snapshot: ColonySnapshot) -> void:
	if snapshot == null:
		return

	reconcile_entities(snapshot)
	consume_events(snapshot.observation_events)


func reconcile_entities(snapshot: ColonySnapshot) -> void:
	if snapshot == null:
		return

	_present_worker_ids.clear()
	for ant: AntSnapshot in snapshot.ants:
		if ant != null and ant.life_stage == AntModel.LifeStage.WORKER:
			_present_worker_ids[ant.entity_id] = true

	if not _present_worker_ids.has(_selected_worker_entity_id):
		_selected_worker_entity_id = -1

	_remove_missing_worker_annotations(_present_worker_ids)


func consume_events(events: Array[ObservationEvent]) -> void:
	_consume_observation_events(events, _present_worker_ids)


func select_worker(entity_id: int, snapshot: ColonySnapshot) -> bool:
	if snapshot == null:
		return false
	var ant: AntSnapshot = snapshot.find_ant(entity_id)
	if ant == null or ant.life_stage != AntModel.LifeStage.WORKER:
		return false
	_selected_worker_entity_id = entity_id
	return true


func clear_selection() -> void:
	_selected_worker_entity_id = -1


func set_selected_worker_name(raw_name: String) -> bool:
	if _selected_worker_entity_id < 0:
		return false

	var normalized_name: String = raw_name.strip_edges()
	if normalized_name.length() > MAX_WORKER_NAME_LENGTH:
		normalized_name = normalized_name.substr(0, MAX_WORKER_NAME_LENGTH)
	if normalized_name.is_empty():
		_worker_names.erase(_selected_worker_entity_id)
	else:
		_worker_names[_selected_worker_entity_id] = normalized_name
	return true


func get_selected_worker_id() -> int:
	return _selected_worker_entity_id


func get_worker_name(entity_id: int) -> String:
	return _worker_names.get(entity_id, "")


func get_recent_events(entity_id: int) -> Array[ObservationEvent]:
	var event_copies: Array[ObservationEvent] = []
	var stored_events: Array = _recent_events_by_worker.get(entity_id, [])
	for stored_event: ObservationEvent in stored_events:
		event_copies.append(stored_event.copy_event())
	return event_copies


func get_last_consumed_event_id() -> int:
	return _last_consumed_event_id


func has_event_gap() -> bool:
	return _has_event_gap


func _remove_missing_worker_annotations(
	present_worker_ids: Dictionary[int, bool]
) -> void:
	var missing_name_ids: Array[int] = []
	for entity_id: int in _worker_names:
		if not present_worker_ids.has(entity_id):
			missing_name_ids.append(entity_id)
	for entity_id: int in missing_name_ids:
		_worker_names.erase(entity_id)

	var missing_history_ids: Array[int] = []
	for entity_id: int in _recent_events_by_worker:
		if not present_worker_ids.has(entity_id):
			missing_history_ids.append(entity_id)
	for entity_id: int in missing_history_ids:
		_recent_events_by_worker.erase(entity_id)


func _consume_observation_events(
	events: Array[ObservationEvent],
	present_worker_ids: Dictionary[int, bool]
) -> void:
	var ordered_events: Array[ObservationEvent] = []
	for event: ObservationEvent in events:
		if event != null and event.event_id > 0:
			ordered_events.append(event.copy_event())
	ordered_events.sort_custom(
		func(first: ObservationEvent, second: ObservationEvent) -> bool:
			return first.event_id < second.event_id
	)

	for event: ObservationEvent in ordered_events:
		if event.event_id <= _last_consumed_event_id:
			continue
		if event.event_id > _last_consumed_event_id + 1:
			_has_event_gap = true
		_last_consumed_event_id = event.event_id

		if not present_worker_ids.has(event.actor_entity_id):
			continue
		var worker_events: Array = _recent_events_by_worker.get(
			event.actor_entity_id,
			[]
		)
		worker_events.append(event.copy_event())
		while worker_events.size() > MAX_RECENT_EVENTS_PER_WORKER:
			worker_events.pop_front()
		_recent_events_by_worker[event.actor_entity_id] = worker_events
