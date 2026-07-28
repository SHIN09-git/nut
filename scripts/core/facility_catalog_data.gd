class_name FacilityCatalogData
extends Resource

@export var data_status: StringName = &"prototype_pacing_fixture"
@export var scientifically_validated: bool = false
@export var grid_size: Vector2i = Vector2i(12, 8)
@export var facility_types: Array[FacilityData] = []
@export var initial_facilities: Array[InitialFacilityData] = []
@export var initial_supplies: Array[FacilitySupplyData] = []


func is_valid() -> bool:
	if (
		data_status.is_empty()
		or grid_size.x < 4
		or grid_size.y < 4
		or grid_size.x > 64
		or grid_size.y > 64
		or facility_types.is_empty()
	):
		return false
	var types_by_id: Dictionary[StringName, FacilityData] = {}
	for facility_type: FacilityData in facility_types:
		if (
			facility_type == null
			or not facility_type.is_valid()
			or types_by_id.has(facility_type.type_id)
		):
			return false
		types_by_id[facility_type.type_id] = facility_type
	var seen_facility_ids: Dictionary[int, bool] = {}
	for initial: InitialFacilityData in initial_facilities:
		if (
			initial == null
			or not initial.is_valid()
			or seen_facility_ids.has(initial.facility_id)
			or not types_by_id.has(initial.type_id)
			or not types_by_id[initial.type_id]
				.allowed_orientations.has(initial.orientation)
		):
			return false
		seen_facility_ids[initial.facility_id] = true
	var seen_supply_ids: Dictionary[StringName, bool] = {}
	for supply: FacilitySupplyData in initial_supplies:
		if (
			supply == null
			or not supply.is_valid()
			or seen_supply_ids.has(supply.type_id)
			or not types_by_id.has(supply.type_id)
		):
			return false
		seen_supply_ids[supply.type_id] = true
	return true
