class_name ObservationEvent
extends RefCounted

enum Type {
	RELOCATION_STARTED,
	BROOD_PICKUP_STARTED,
	BROOD_CARRY_STARTED,
	BROOD_DROPPED,
	BROOD_HUMIDITY_OBSERVATION_COMPLETED,
	FOOD_SEEK_STARTED,
	FOOD_TRAVEL_STARTED,
	SUGAR_COLLECTED,
	SUGAR_RETURN_STARTED,
	SUGAR_SHARED,
	SUGAR_OBSERVATION_COMPLETED,
	FORAGING_TASK_CANCELLED,
	FIRST_WORKER_EMERGED,
	IDENTITY_OBSERVATION_COMPLETED,
	OBSERVATION_SESSION_COMPLETED,
	CAMPAIGN_INFERENCE_REJECTED,
	CAMPAIGN_INFERENCE_CONFIRMED,
	CAMPAIGN_CHAPTER_COMPLETED,
	CAMPAIGN_SESSION_COMPLETED,
	PROTEIN_COLLECTED,
	PROTEIN_RETURN_STARTED,
	PROTEIN_DELIVERED,
	BROOD_FEEDING_STARTED,
	BROOD_FED,
	LIGHT_COVER_APPLIED,
	QUEEN_BROOD_CARE_COMPLETED,
	FIRST_PUPA_OBSERVED,
	WASTE_CLEANUP_STARTED,
	WASTE_PICKED_UP,
	WASTE_DELIVERED,
	WASTE_TRAY_CLEANED,
	SCOUT_STARTED,
	ZONE_DISCOVERED,
	SCOUT_RETURNED,
	MIGRATION_STARTED,
	MIGRATION_MEMBER_PICKED_UP,
	MIGRATION_MEMBER_DROPPED,
	MIGRATION_COMPLETED,
}

const NO_ENTITY_ID: int = -1

var event_id: int
var tick: int
var event_type: Type
var actor_entity_id: int
var subject_entity_id: int
var source_zone_id: StringName
var target_zone_id: StringName


func _init(
	new_event_id: int = 0,
	new_tick: int = 0,
	new_event_type: Type = Type.RELOCATION_STARTED,
	new_actor_entity_id: int = NO_ENTITY_ID,
	new_subject_entity_id: int = NO_ENTITY_ID,
	new_source_zone_id: StringName = &"",
	new_target_zone_id: StringName = &""
) -> void:
	event_id = new_event_id
	tick = new_tick
	event_type = new_event_type
	actor_entity_id = new_actor_entity_id
	subject_entity_id = new_subject_entity_id
	source_zone_id = new_source_zone_id
	target_zone_id = new_target_zone_id


func copy_event() -> ObservationEvent:
	return ObservationEvent.new(
		event_id,
		tick,
		event_type,
		actor_entity_id,
		subject_entity_id,
		source_zone_id,
		target_zone_id
	)
