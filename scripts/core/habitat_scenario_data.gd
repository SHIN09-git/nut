class_name HabitatScenarioData
extends Resource

@export var scenario_id: StringName = &""
@export var data_status: StringName = &"prototype_pacing_fixture"
@export var scientifically_validated: bool = false
@export var left_zone: HabitatZoneData
@export var right_zone: HabitatZoneData
@export_range(1, 20, 1) var initial_worker_count: int = 0
@export_range(1, 50, 1) var initial_brood_count: int = 0
@export_enum("Egg", "Larva", "Pupa") var initial_brood_stage: int = 0
@export var initial_worker_zone_id: StringName = &""
@export var initial_brood_zone_id: StringName = &""
@export var humidity_adjustment_zone_id: StringName = &""
@export_range(0.01, 1.0, 0.01) var humidity_adjustment_amount: float = 0.0
@export_range(1, 10_000, 1) var observation_stable_ticks: int = 0


func is_valid() -> bool:
	if (
		scenario_id.is_empty()
		or data_status.is_empty()
		or left_zone == null
		or right_zone == null
		or not left_zone.is_valid()
		or not right_zone.is_valid()
		or left_zone.zone_id == right_zone.zone_id
		or initial_worker_count <= 0
		or initial_brood_count <= 0
		or initial_brood_stage < 0
		or initial_brood_stage > 2
		or is_nan(humidity_adjustment_amount)
		or is_inf(humidity_adjustment_amount)
		or humidity_adjustment_amount <= 0.0
		or observation_stable_ticks <= 0
	):
		return false

	var known_zone_ids: Dictionary[StringName, bool] = {
		left_zone.zone_id: true,
		right_zone.zone_id: true,
	}
	if (
		not known_zone_ids.has(initial_worker_zone_id)
		or not known_zone_ids.has(initial_brood_zone_id)
		or not known_zone_ids.has(humidity_adjustment_zone_id)
	):
		return false

	for zone_data: HabitatZoneData in [left_zone, right_zone]:
		for connected_zone_id: StringName in zone_data.connected_zone_ids:
			if not known_zone_ids.has(connected_zone_id):
				return false
	return true
