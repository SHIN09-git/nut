class_name CampaignSnapshot
extends RefCounted

var chapter: CampaignState.Chapter = CampaignState.Chapter.FOUNDING_OBSERVATION
var status: CampaignState.Status = CampaignState.Status.ACTIVE
var chapter_entered_tick: int = 0
var completed_chapter_count: int = 0
var incorrect_inference_attempts: int = 0
var hint_tier: int = 0
var campaign_completed_tick: int = -1
var inference_action_available: bool = false
var inference_action_pending: bool = false
var available_inference_ids: Array[StringName] = []
var collected_evidence_ids: Array[StringName] = []
var confirmed_inference_ids: Array[StringName] = []
var unlocked_facility_type_ids: Array[StringName] = []
var completed: bool = false


func _init(
	new_chapter: CampaignState.Chapter = (
		CampaignState.Chapter.FOUNDING_OBSERVATION
	),
	new_status: CampaignState.Status = CampaignState.Status.ACTIVE,
	new_chapter_entered_tick: int = 0,
	new_completed_chapter_count: int = 0,
	new_incorrect_inference_attempts: int = 0,
	new_hint_tier: int = 0,
	new_campaign_completed_tick: int = -1,
	new_inference_action_available: bool = false,
	new_inference_action_pending: bool = false,
	new_available_inference_ids: Array[StringName] = [],
	new_collected_evidence_ids: Array[StringName] = [],
	new_confirmed_inference_ids: Array[StringName] = [],
	new_unlocked_facility_type_ids: Array[StringName] = []
) -> void:
	chapter = new_chapter
	status = new_status
	chapter_entered_tick = new_chapter_entered_tick
	completed_chapter_count = new_completed_chapter_count
	incorrect_inference_attempts = new_incorrect_inference_attempts
	hint_tier = new_hint_tier
	campaign_completed_tick = new_campaign_completed_tick
	inference_action_available = new_inference_action_available
	inference_action_pending = new_inference_action_pending
	available_inference_ids.assign(new_available_inference_ids)
	collected_evidence_ids.assign(new_collected_evidence_ids)
	confirmed_inference_ids.assign(new_confirmed_inference_ids)
	unlocked_facility_type_ids.assign(new_unlocked_facility_type_ids)
	completed = status == CampaignState.Status.COMPLETED


func has_evidence(evidence_id: StringName) -> bool:
	return collected_evidence_ids.has(evidence_id)


func has_confirmed_inference(inference_id: StringName) -> bool:
	return confirmed_inference_ids.has(inference_id)


func has_unlocked_facility(type_id: StringName) -> bool:
	return unlocked_facility_type_ids.has(type_id)
