class_name FacilitySupplyData
extends Resource

@export var type_id: StringName = &""
@export_range(0, 48, 1) var available_count: int = 0


func is_valid() -> bool:
	return not type_id.is_empty() and available_count >= 0
