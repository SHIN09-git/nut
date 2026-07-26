class_name FoodSourceSnapshot
extends RefCounted

var food_source_id: int
var zone_id: StringName
var food_type: FoodSourceState.FoodType
var remaining_portions: int
var available: bool
var reserved_by_worker_id: int
var carrier_worker_id: int


func _init(
	new_food_source_id: int = -1,
	new_zone_id: StringName = &"",
	new_food_type: FoodSourceState.FoodType = (
		FoodSourceState.FoodType.SUGAR_WATER
	),
	new_remaining_portions: int = 0,
	new_available: bool = false,
	new_reserved_by_worker_id: int = -1,
	new_carrier_worker_id: int = -1
) -> void:
	food_source_id = new_food_source_id
	zone_id = new_zone_id
	food_type = new_food_type
	remaining_portions = maxi(new_remaining_portions, 0)
	available = new_available
	reserved_by_worker_id = new_reserved_by_worker_id
	carrier_worker_id = new_carrier_worker_id
