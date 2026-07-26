class_name ScenarioSequenceData
extends Resource

@export var data_status: StringName = &"prototype_pacing_fixture"
@export var scientifically_validated: bool = false
@export_range(0, 100_000, 1) var first_worker_initial_pupa_age_ticks: int = 0
@export var first_worker_observation_card_id: StringName = &""
@export var brood_humidity_observation_card_id: StringName = &""


func is_valid() -> bool:
	return (
		not data_status.is_empty()
		and first_worker_initial_pupa_age_ticks > 0
		and not first_worker_observation_card_id.is_empty()
		and not brood_humidity_observation_card_id.is_empty()
		and first_worker_observation_card_id
			!= brood_humidity_observation_card_id
	)
