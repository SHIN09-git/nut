class_name WorkerObservationPanel
extends PanelContainer

signal name_commit_requested(text: String)

const MAX_VISIBLE_HISTORY_EVENTS: int = 4
const UNNAMED_WORKER_TEXT: String = "未命名工蚁"
const EMPTY_HISTORY_TEXT: String = "暂时还没有可记录的行为。"

var _selected_worker_id: int = -1
var _applied_display_name: String = ""
var _visible_event_ids: Array[int] = []
var _visible_actor_ids: Array[int] = []

@onready var _worker_prompt_label: Label = %WorkerPromptLabel
@onready var _selected_worker_content: Control = %SelectedWorkerContent
@onready var _worker_display_name_label: Label = %WorkerDisplayNameLabel
@onready var _worker_current_behavior_label: Label = %WorkerCurrentBehaviorLabel
@onready var _worker_name_edit: LineEdit = %WorkerNameEdit
@onready var _worker_name_button: Button = %WorkerNameButton
@onready var _worker_history_label: Label = %WorkerHistoryLabel


func _ready() -> void:
	_worker_name_button.pressed.connect(_on_worker_name_button_pressed)
	_worker_name_edit.text_submitted.connect(_on_worker_name_text_submitted)
	reset_panel()


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

	_worker_prompt_label.visible = false
	_selected_worker_content.visible = true
	_worker_name_button.disabled = false
	_worker_display_name_label.text = (
		normalized_display_name
		if not normalized_display_name.is_empty()
		else UNNAMED_WORKER_TEXT
	)
	_worker_current_behavior_label.text = _describe_current_behavior(
		worker_snapshot.worker_task_state
	)
	if selection_changed or name_changed:
		_worker_name_edit.text = normalized_display_name

	_apply_event_history(events)


func reset_panel() -> void:
	_selected_worker_id = -1
	_applied_display_name = ""
	_visible_event_ids.clear()
	_visible_actor_ids.clear()

	_worker_prompt_label.visible = true
	_selected_worker_content.visible = false
	_worker_display_name_label.text = UNNAMED_WORKER_TEXT
	_worker_current_behavior_label.text = ""
	_worker_name_edit.text = ""
	_worker_name_edit.release_focus()
	_worker_name_button.disabled = true
	_worker_history_label.text = EMPTY_HISTORY_TEXT


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
		EMPTY_HISTORY_TEXT
		if history_lines.is_empty()
		else "\n".join(history_lines)
	)


func _describe_current_behavior(state: int) -> String:
	match state:
		WorkerTaskModel.State.IDLE:
			return "这只工蚁正在巢室里休整。"
		WorkerTaskModel.State.MOVING_TO_BROOD:
			return "这只工蚁正在靠近一只幼体。"
		WorkerTaskModel.State.PICKING_UP:
			return "这只工蚁正在拾起一只幼体。"
		WorkerTaskModel.State.CARRYING_TO_ZONE:
			return "这只工蚁正在携带幼体前往新的位置。"
		WorkerTaskModel.State.DROPPING:
			return "这只工蚁正在安置刚刚搬来的幼体。"
		_:
			return "这只工蚁正在观察周围。"


func _describe_event(event_type: ObservationEvent.Type) -> String:
	match event_type:
		ObservationEvent.Type.RELOCATION_STARTED:
			return "出发前往幼体所在的位置。"
		ObservationEvent.Type.BROOD_PICKUP_STARTED:
			return "开始拾起一只幼体。"
		ObservationEvent.Type.BROOD_CARRY_STARTED:
			return "开始携带一只幼体前往新的位置。"
		ObservationEvent.Type.BROOD_DROPPED:
			return "把一只幼体安置在新的位置。"
		ObservationEvent.Type.BROOD_HUMIDITY_OBSERVATION_COMPLETED:
			return "群落的湿度观察已经完成。"
		_:
			return "发生了一次新的行为。"


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
