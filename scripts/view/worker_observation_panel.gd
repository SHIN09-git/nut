class_name WorkerObservationPanel
extends PanelContainer

signal name_commit_requested(text: String)

const MAX_VISIBLE_HISTORY_EVENTS: int = 4

var _selected_worker_id: int = -1
var _applied_display_name: String = ""
var _visible_event_ids: Array[int] = []
var _visible_actor_ids: Array[int] = []
var _applied_worker_snapshot: AntSnapshot
var _applied_events: Array = []

@onready var _worker_observation_heading: Label = get_node_or_null(
	"%WorkerObservationHeading"
) as Label
@onready var _worker_prompt_label: Label = %WorkerPromptLabel
@onready var _selected_worker_content: Control = %SelectedWorkerContent
@onready var _worker_display_name_label: Label = %WorkerDisplayNameLabel
@onready var _worker_current_behavior_label: Label = %WorkerCurrentBehaviorLabel
@onready var _worker_name_edit: LineEdit = %WorkerNameEdit
@onready var _worker_name_button: Button = %WorkerNameButton
@onready var _history_heading: Label = get_node_or_null(
	"%HistoryHeading"
) as Label
@onready var _worker_history_label: Label = %WorkerHistoryLabel


func _ready() -> void:
	_worker_name_button.pressed.connect(_on_worker_name_button_pressed)
	_worker_name_edit.text_submitted.connect(_on_worker_name_text_submitted)
	_refresh_localized_static_copy()
	reset_panel()


func _notification(what: int) -> void:
	if what != NOTIFICATION_TRANSLATION_CHANGED or not is_node_ready():
		return
	_refresh_localized_static_copy()
	if _applied_worker_snapshot != null:
		_worker_display_name_label.text = (
			_applied_display_name
			if not _applied_display_name.is_empty()
			else tr("UI_WORKER_UNNAMED")
		)
		_worker_current_behavior_label.text = _describe_current_behavior(
			_applied_worker_snapshot
		)
		_apply_event_history(_applied_events)
	else:
		_worker_display_name_label.text = tr("UI_WORKER_UNNAMED")
		_worker_history_label.text = tr("UI_EMPTY_HISTORY")


func apply_selection(
	worker_snapshot: AntSnapshot,
	display_name: String,
	events: Array
) -> void:
	if (
		worker_snapshot == null
		or worker_snapshot.life_stage != AntModel.LifeStage.WORKER
	):
		reset_panel()
		return

	var normalized_display_name: String = display_name.strip_edges()
	var selection_changed: bool = (
		_selected_worker_id != worker_snapshot.entity_id
	)
	var name_changed: bool = _applied_display_name != normalized_display_name
	_selected_worker_id = worker_snapshot.entity_id
	_applied_display_name = normalized_display_name
	_applied_worker_snapshot = worker_snapshot
	_applied_events.assign(events)

	_worker_prompt_label.visible = false
	_selected_worker_content.visible = true
	_worker_name_button.disabled = false
	_worker_display_name_label.text = (
		normalized_display_name
		if not normalized_display_name.is_empty()
		else tr("UI_WORKER_UNNAMED")
	)
	_worker_current_behavior_label.text = _describe_current_behavior(
		worker_snapshot
	)
	if selection_changed or name_changed:
		_worker_name_edit.text = normalized_display_name

	_apply_event_history(events)


func reset_panel() -> void:
	_selected_worker_id = -1
	_applied_display_name = ""
	_applied_worker_snapshot = null
	_applied_events.clear()
	_visible_event_ids.clear()
	_visible_actor_ids.clear()

	_worker_prompt_label.visible = true
	_selected_worker_content.visible = false
	_worker_display_name_label.text = tr("UI_WORKER_UNNAMED")
	_worker_current_behavior_label.text = ""
	_worker_name_edit.text = ""
	_worker_name_edit.release_focus()
	_worker_name_button.disabled = true
	_worker_history_label.text = tr("UI_EMPTY_HISTORY")


func get_visible_event_ids() -> Array[int]:
	var result: Array[int] = []
	result.assign(_visible_event_ids)
	return result


func get_visible_actor_ids() -> Array[int]:
	var result: Array[int] = []
	result.assign(_visible_actor_ids)
	return result


func _apply_event_history(events: Array) -> void:
	var valid_events: Array[ObservationEvent] = []
	for event_value: Variant in events:
		var event: ObservationEvent = event_value as ObservationEvent
		if event != null:
			valid_events.append(event)

	var first_visible_index: int = maxi(
		valid_events.size() - MAX_VISIBLE_HISTORY_EVENTS,
		0
	)
	var history_lines: PackedStringArray = []
	_visible_event_ids.clear()
	_visible_actor_ids.clear()
	for event_index: int in range(first_visible_index, valid_events.size()):
		var event: ObservationEvent = valid_events[event_index]
		_visible_event_ids.append(event.event_id)
		_visible_actor_ids.append(event.actor_entity_id)
		history_lines.append("• %s" % _describe_event(event.event_type))

	_worker_history_label.text = (
		tr("UI_EMPTY_HISTORY")
		if history_lines.is_empty()
		else "\n".join(history_lines)
	)


func _describe_current_behavior(worker_snapshot: AntSnapshot) -> String:
	if (
		worker_snapshot.foraging_task != null
		and worker_snapshot.foraging_task.state
			!= ForagingTaskSnapshot.State.IDLE
	):
		match worker_snapshot.foraging_task.state:
			ForagingTaskSnapshot.State.SEEKING_FOOD:
				return tr("BEHAVIOR_SEEKING_FOOD")
			ForagingTaskSnapshot.State.MOVING_TO_FOOD:
				return tr("BEHAVIOR_MOVING_TO_FOOD")
			ForagingTaskSnapshot.State.COLLECTING:
				return tr("BEHAVIOR_COLLECTING")
			ForagingTaskSnapshot.State.RETURNING_TO_NEST:
				return tr("BEHAVIOR_RETURNING")
			ForagingTaskSnapshot.State.SHARING:
				return tr("BEHAVIOR_SHARING")

	match worker_snapshot.worker_task_state:
		WorkerTaskModel.State.IDLE:
			return tr("BEHAVIOR_IDLE")
		WorkerTaskModel.State.MOVING_TO_BROOD:
			return tr("BEHAVIOR_MOVING_TO_BROOD")
		WorkerTaskModel.State.PICKING_UP:
			return tr("BEHAVIOR_PICKING_UP")
		WorkerTaskModel.State.CARRYING_TO_ZONE:
			return tr("BEHAVIOR_CARRYING_BROOD")
		WorkerTaskModel.State.DROPPING:
			return tr("BEHAVIOR_DROPPING_BROOD")
		_:
			return tr("BEHAVIOR_FALLBACK")


func _describe_event(event_type: ObservationEvent.Type) -> String:
	match event_type:
		ObservationEvent.Type.RELOCATION_STARTED:
			return tr("EVENT_RELOCATION_STARTED")
		ObservationEvent.Type.BROOD_PICKUP_STARTED:
			return tr("EVENT_PICKUP_STARTED")
		ObservationEvent.Type.BROOD_CARRY_STARTED:
			return tr("EVENT_CARRY_STARTED")
		ObservationEvent.Type.BROOD_DROPPED:
			return tr("EVENT_BROOD_DROPPED")
		ObservationEvent.Type.BROOD_HUMIDITY_OBSERVATION_COMPLETED:
			return tr("EVENT_HUMIDITY_COMPLETE")
		ObservationEvent.Type.FOOD_SEEK_STARTED:
			return tr("EVENT_FOOD_SEEK")
		ObservationEvent.Type.FOOD_TRAVEL_STARTED:
			return tr("EVENT_FOOD_TRAVEL")
		ObservationEvent.Type.SUGAR_COLLECTED:
			return tr("EVENT_SUGAR_COLLECTED")
		ObservationEvent.Type.SUGAR_RETURN_STARTED:
			return tr("EVENT_SUGAR_RETURN")
		ObservationEvent.Type.SUGAR_SHARED:
			return tr("EVENT_SUGAR_SHARED")
		ObservationEvent.Type.SUGAR_OBSERVATION_COMPLETED:
			return tr("EVENT_SUGAR_COMPLETE")
		ObservationEvent.Type.FORAGING_TASK_CANCELLED:
			return tr("EVENT_FORAGING_CANCELLED")
		ObservationEvent.Type.FIRST_WORKER_EMERGED:
			return tr("EVENT_FIRST_WORKER")
		ObservationEvent.Type.IDENTITY_OBSERVATION_COMPLETED:
			return tr("EVENT_IDENTITY_COMPLETE")
		ObservationEvent.Type.OBSERVATION_SESSION_COMPLETED:
			return tr("EVENT_SESSION_COMPLETE")
		_:
			return tr("EVENT_FALLBACK")


func _on_worker_name_button_pressed() -> void:
	_emit_name_commit(_worker_name_edit.text)


func _on_worker_name_text_submitted(text: String) -> void:
	_emit_name_commit(text)


func _emit_name_commit(text: String) -> void:
	if _selected_worker_id < 0:
		return
	var normalized_text: String = text.strip_edges()
	_worker_name_edit.text = normalized_text
	name_commit_requested.emit(normalized_text)


func _refresh_localized_static_copy() -> void:
	if _worker_observation_heading != null:
		_worker_observation_heading.text = tr("UI_WORKER_OBSERVATION")
	_worker_prompt_label.text = tr("UI_WORKER_PROMPT")
	_worker_name_edit.placeholder_text = tr("UI_WORKER_NAME_PLACEHOLDER")
	_worker_name_button.text = tr("UI_SAVE_NAME")
	if _history_heading != null:
		_history_heading.text = tr("UI_RECENT_ACTIONS")
