class_name Act1ObservationSidebar
extends PanelContainer

signal journal_requested

@onready var objective_heading: Label = %ObjectiveHeading
@onready var objective_label: Label = %ObjectiveLabel
@onready var evidence_heading: Label = %EvidenceHeading
@onready var evidence_label: Label = %EvidenceLabel
@onready var guidance_label: Label = %GuidanceLabel
@onready var journal_button: Button = %JournalButton
@onready var inspect_panel: PanelContainer = %InspectPanel
@onready var inspect_label: Label = %InspectLabel


func _ready() -> void:
	journal_button.pressed.connect(journal_requested.emit)


func set_copy(
	objective_heading_text: String,
	evidence_heading_text: String,
	journal_button_text: String
) -> void:
	objective_heading.text = objective_heading_text
	evidence_heading.text = evidence_heading_text
	journal_button.text = journal_button_text


func set_observation_text(
	objective_text: String,
	evidence_text: String,
	guidance_text: String
) -> void:
	objective_label.text = objective_text
	evidence_label.text = evidence_text
	guidance_label.text = guidance_text


func set_guidance_text(value: String) -> void:
	guidance_label.text = value


func set_journal_disabled(value: bool) -> void:
	journal_button.disabled = value


func set_inspector_visible(value: bool) -> void:
	inspect_panel.visible = value


func set_inspector_text(value: String) -> void:
	inspect_label.text = value


func focus_journal_button() -> void:
	journal_button.grab_focus()
