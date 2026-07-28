class_name FacilityCatalogConfig
extends RefCounted

var grid_size: Vector2i
var types_by_id: Dictionary[StringName, FacilityConfig] = {}
var initial_facilities: Array[InitialFacilityConfig] = []
var initial_supply_counts: Dictionary[StringName, int] = {}


static func from_data(data: FacilityCatalogData) -> FacilityCatalogConfig:
	if data == null or not data.is_valid():
		return null
	var config: FacilityCatalogConfig = FacilityCatalogConfig.new()
	config.grid_size = data.grid_size
	for type_data: FacilityData in data.facility_types:
		var facility_type: FacilityConfig = FacilityConfig.from_data(type_data)
		if facility_type == null:
			return null
		config.types_by_id[facility_type.type_id] = facility_type
	for initial_data: InitialFacilityData in data.initial_facilities:
		var initial: InitialFacilityConfig = InitialFacilityConfig.from_data(
			initial_data
		)
		if initial == null:
			return null
		config.initial_facilities.append(initial)
	config.initial_facilities.sort_custom(
		func(first: InitialFacilityConfig, second: InitialFacilityConfig) -> bool:
			return first.facility_id < second.facility_id
	)
	for supply: FacilitySupplyData in data.initial_supplies:
		config.initial_supply_counts[supply.type_id] = supply.available_count
	return config


func get_type(type_id: StringName) -> FacilityConfig:
	return types_by_id.get(type_id)


func copy_type_ids() -> Array[StringName]:
	var result: Array[StringName] = []
	for type_id: StringName in types_by_id:
		result.append(type_id)
	result.sort_custom(
		func(first: StringName, second: StringName) -> bool:
			return String(first) < String(second)
	)
	return result
