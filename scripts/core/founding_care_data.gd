class_name FoundingCareData
extends Resource

@export var data_status: StringName = &"prototype_pacing_fixture"
@export var scientifically_validated: bool = false
@export_range(1, 10_000, 1) var rest_duration_ticks: int = 0
@export_range(1, 10_000, 1) var gathering_duration_ticks: int = 0
@export_range(1, 10_000, 1) var brood_care_duration_ticks: int = 0
@export_range(1, 10_000, 1) var pupa_observation_ticks: int = 0
@export_range(1, 100_000, 1) var first_worker_initial_pupa_age_ticks: int = 0
@export var queen_care_observation_card_id: StringName = &""
@export var pupa_observation_card_id: StringName = &""
@export var first_worker_observation_card_id: StringName = &""
@export var worker_care_observation_card_id: StringName = &""


func is_valid() -> bool:
	return (
		not data_status.is_empty()
		and rest_duration_ticks > 0
		and gathering_duration_ticks > 0
		and brood_care_duration_ticks > 0
		and pupa_observation_ticks > 0
		and first_worker_initial_pupa_age_ticks > 0
		and not queen_care_observation_card_id.is_empty()
		and not pupa_observation_card_id.is_empty()
		and not first_worker_observation_card_id.is_empty()
		and not worker_care_observation_card_id.is_empty()
		and queen_care_observation_card_id != pupa_observation_card_id
		and queen_care_observation_card_id
			!= first_worker_observation_card_id
		and queen_care_observation_card_id
			!= worker_care_observation_card_id
		and pupa_observation_card_id
			!= first_worker_observation_card_id
		and pupa_observation_card_id != worker_care_observation_card_id
		and first_worker_observation_card_id
			!= worker_care_observation_card_id
	)
