class_name CampaignState
extends RefCounted

enum Chapter {
	FOUNDING_OBSERVATION,
	ENVIRONMENTAL_CARE,
}

enum Status {
	ACTIVE,
	AWAITING_INFERENCE,
	COMPLETED,
}

const EVIDENCE_FIRST_WORKER: StringName = &"first_worker_emerged"
const EVIDENCE_HUMIDITY_RELOCATION: StringName = (
	&"brood_humidity_relocation"
)
const EVIDENCE_SUGAR_SHARING: StringName = &"sugar_foraging_complete"

const INFERENCE_FIRST_WORKER: StringName = &"brood_develops_into_workers"
const INFERENCE_FIRST_WORKER_RANDOM: StringName = &"worker_change_is_random"
const INFERENCE_FIRST_WORKER_DIRECTED: StringName = (
	&"player_directs_worker_development"
)
const INFERENCE_ENVIRONMENT: StringName = (
	&"workers_respond_to_environment"
)
const INFERENCE_ENVIRONMENT_IGNORED: StringName = (
	&"workers_ignore_environment"
)
const INFERENCE_ENVIRONMENT_DIRECTED: StringName = (
	&"player_directs_each_worker"
)

const FACILITY_TEST_TUBE_NEST: StringName = &"test_tube_nest"
const FACILITY_LIGHT_COVER: StringName = &"light_cover"
const FACILITY_MICRO_FEEDING_PORT: StringName = &"micro_feeding_port"
const FACILITY_SMALL_FORAGING_BOX: StringName = &"small_foraging_box"

var chapter: Chapter = Chapter.FOUNDING_OBSERVATION
var status: Status = Status.ACTIVE
var chapter_entered_tick: int = 0
var completed_chapter_count: int = 0
var incorrect_inference_attempts: int = 0
var hint_tier: int = 0
var campaign_completed_tick: int = -1
var collected_evidence_ids: Dictionary[StringName, bool] = {}
var confirmed_inference_ids: Dictionary[StringName, bool] = {}
var unlocked_facility_type_ids: Dictionary[StringName, bool] = {
	FACILITY_TEST_TUBE_NEST: true,
	FACILITY_LIGHT_COVER: true,
}


func collect_evidence(evidence_id: StringName) -> bool:
	if evidence_id.is_empty() or collected_evidence_ids.has(evidence_id):
		return false
	collected_evidence_ids[evidence_id] = true
	return true


func confirm_inference(inference_id: StringName) -> bool:
	if inference_id.is_empty() or confirmed_inference_ids.has(inference_id):
		return false
	confirmed_inference_ids[inference_id] = true
	return true


func unlock_facility(type_id: StringName) -> bool:
	if type_id.is_empty() or unlocked_facility_type_ids.has(type_id):
		return false
	unlocked_facility_type_ids[type_id] = true
	return true


func copy_evidence_ids() -> Array[StringName]:
	return _copy_sorted_ids(collected_evidence_ids)


func copy_confirmed_inference_ids() -> Array[StringName]:
	return _copy_sorted_ids(confirmed_inference_ids)


func copy_unlocked_facility_type_ids() -> Array[StringName]:
	return _copy_sorted_ids(unlocked_facility_type_ids)


func _copy_sorted_ids(source: Dictionary[StringName, bool]) -> Array[StringName]:
	var result: Array[StringName] = []
	for id: StringName in source:
		result.append(id)
	result.sort_custom(
		func(first: StringName, second: StringName) -> bool:
			return String(first) < String(second)
	)
	return result
