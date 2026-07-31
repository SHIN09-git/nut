class_name Act1JournalPanel
extends Control

signal close_requested
signal inference_requested(inference_id: StringName)
signal prediction_requested(prediction_id: StringName)
signal first_worker_name_requested(text: String)

@onready var heading_label: Label = %JournalHeading
@onready var chapter_label: Label = %JournalChapterLabel
@onready var chapter_art: ChapterArtView = %JournalChapterArt
@onready var status_label: Label = %JournalStatusLabel
@onready var scroll: ScrollContainer = %Scroll
@onready var experiment_section: Control = %ExperimentSection
@onready var question_heading: Label = %QuestionHeading
@onready var question_label: Label = %JournalQuestionLabel
@onready var prediction_heading: Label = %PredictionHeading
@onready var prediction_status_label: Label = %JournalPredictionStatusLabel
@onready var comparison_heading: Label = %ComparisonHeading
@onready var comparison_label: Label = %JournalComparisonLabel
@onready var timeline_heading: Label = %TimelineHeading
@onready var timeline_label: Label = %JournalTimelineLabel
@onready var objective_label: Label = %JournalObjectiveLabel
@onready var evidence_label: Label = %JournalEvidenceLabel
@onready var hint_label: Label = %JournalHintLabel
@onready var close_button: Button = %JournalCloseButton
@onready var inference_buttons: Array[Button] = [
	%InferenceButton1,
	%InferenceButton2,
	%InferenceButton3,
]
@onready var prediction_buttons: Array[Button] = [
	%PredictionButton1,
	%PredictionButton2,
	%PredictionButton3,
]
@onready var worker_observation_panel: WorkerObservationPanel = (
	%JournalWorkerObservationPanel
)

var _last_chapter: int = -1
var _scroll_to_top_on_open: bool = false


func _ready() -> void:
	close_button.pressed.connect(close_requested.emit)
	for index: int in inference_buttons.size():
		inference_buttons[index].pressed.connect(
			_emit_inference.bind(index)
		)
	for index: int in prediction_buttons.size():
		prediction_buttons[index].pressed.connect(
			_emit_prediction.bind(index)
		)
	worker_observation_panel.name_commit_requested.connect(
		first_worker_name_requested.emit
	)


func set_copy(heading_text: String, close_text: String) -> void:
	heading_label.text = heading_text
	close_button.text = close_text


func set_experiment_copy(
	question_heading_text: String,
	prediction_heading_text: String,
	comparison_heading_text: String,
	timeline_heading_text: String
) -> void:
	question_heading.text = question_heading_text
	prediction_heading.text = prediction_heading_text
	comparison_heading.text = comparison_heading_text
	timeline_heading.text = timeline_heading_text


func set_content(
	chapter_text: String,
	chapter: int,
	status_text: String,
	objective_text: String,
	evidence_text: String,
	hint_text: String,
	inference_ids: Array[StringName],
	inference_labels: Array[String],
	action_available: bool,
	action_pending: bool
) -> void:
	if chapter != _last_chapter:
		_last_chapter = chapter
		_scroll_to_top_on_open = true
	chapter_label.text = chapter_text
	chapter_art.set_chapter(chapter)
	status_label.text = status_text
	objective_label.text = objective_text
	evidence_label.text = evidence_text
	hint_label.text = hint_text
	for index: int in inference_buttons.size():
		var button: Button = inference_buttons[index]
		var item_visible: bool = index < inference_ids.size()
		button.visible = item_visible
		button.disabled = (
			not item_visible
			or not action_available
			or action_pending
		)
		if not item_visible:
			button.remove_meta(&"inference_id")
			continue
		button.set_meta(&"inference_id", inference_ids[index])
		button.text = inference_labels[index]


func set_experiment_content(
	active: bool,
	question_text: String,
	prediction_ids: Array[StringName],
	prediction_labels: Array[String],
	recorded_prediction_id: StringName,
	recorded_prediction_text: String,
	comparison_text: String,
	timeline_text: String,
	first_worker: AntSnapshot,
	first_worker_name: String,
	first_worker_events: Array[ObservationEvent]
) -> void:
	experiment_section.visible = active
	if not active:
		return
	question_label.text = question_text
	prediction_status_label.text = recorded_prediction_text
	comparison_label.text = comparison_text
	timeline_label.text = timeline_text
	for index: int in prediction_buttons.size():
		var button: Button = prediction_buttons[index]
		var item_visible: bool = (
			recorded_prediction_id.is_empty()
			and index < prediction_ids.size()
			and index < prediction_labels.size()
		)
		button.visible = item_visible
		button.disabled = not item_visible
		if not item_visible:
			button.remove_meta(&"prediction_id")
			continue
		button.set_meta(&"prediction_id", prediction_ids[index])
		button.text = prediction_labels[index]
	worker_observation_panel.visible = first_worker != null
	if first_worker == null:
		worker_observation_panel.reset_panel()
	else:
		worker_observation_panel.apply_selection(
			first_worker,
			first_worker_name,
			first_worker_events
		)


func open_and_focus() -> void:
	visible = true
	var focus_target: Control = close_button
	var prediction_available: bool = false
	for button: Button in prediction_buttons:
		if button.visible and not button.disabled:
			focus_target = button
			prediction_available = true
			break
	for button: Button in inference_buttons:
		if (
			focus_target == close_button
			and button.visible
			and not button.disabled
		):
			focus_target = button
			break
	focus_target.grab_focus()
	if _scroll_to_top_on_open or prediction_available:
		_scroll_to_top_on_open = false
		scroll.scroll_vertical = 0
		scroll.set_deferred("scroll_vertical", 0)


func close() -> void:
	visible = false


func show_submitted_status(message: String) -> void:
	status_label.text = message


func _emit_inference(index: int) -> void:
	if index < 0 or index >= inference_buttons.size():
		return
	var inference_id: StringName = StringName(
		inference_buttons[index].get_meta(&"inference_id", &"")
	)
	if not inference_id.is_empty():
		inference_requested.emit(inference_id)


func _emit_prediction(index: int) -> void:
	if index < 0 or index >= prediction_buttons.size():
		return
	var prediction_id: StringName = StringName(
		prediction_buttons[index].get_meta(&"prediction_id", &"")
	)
	if not prediction_id.is_empty():
		prediction_requested.emit(prediction_id)
