class_name Act1JournalPanel
extends Control

signal close_requested
signal inference_requested(inference_id: StringName)

@onready var heading_label: Label = %JournalHeading
@onready var chapter_label: Label = %JournalChapterLabel
@onready var chapter_art: ChapterArtView = %JournalChapterArt
@onready var status_label: Label = %JournalStatusLabel
@onready var objective_label: Label = %JournalObjectiveLabel
@onready var evidence_label: Label = %JournalEvidenceLabel
@onready var hint_label: Label = %JournalHintLabel
@onready var close_button: Button = %JournalCloseButton
@onready var inference_buttons: Array[Button] = [
	%InferenceButton1,
	%InferenceButton2,
	%InferenceButton3,
]


func _ready() -> void:
	close_button.pressed.connect(close_requested.emit)
	for index: int in inference_buttons.size():
		inference_buttons[index].pressed.connect(
			_emit_inference.bind(index)
		)


func set_copy(heading_text: String, close_text: String) -> void:
	heading_label.text = heading_text
	close_button.text = close_text


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


func open_and_focus() -> void:
	visible = true
	var focus_target: Control = close_button
	for button: Button in inference_buttons:
		if button.visible and not button.disabled:
			focus_target = button
			break
	focus_target.grab_focus()


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
