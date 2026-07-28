class_name FoodSourceState
extends RefCounted

enum FoodType {
	SUGAR_WATER,
	PROTEIN,
}

var entity_id: int
var zone_id: StringName
var remaining_portions: int
var food_type: FoodType
var available: bool


func _init(
	new_entity_id: int,
	new_zone_id: StringName,
	new_remaining_portions: int,
	new_food_type: FoodType = FoodType.SUGAR_WATER,
	new_available: bool = true
) -> void:
	entity_id = new_entity_id
	zone_id = new_zone_id
	remaining_portions = maxi(new_remaining_portions, 0)
	food_type = new_food_type
	available = new_available


func has_available_portion() -> bool:
	return available and remaining_portions > 0


func take_portion() -> bool:
	if not has_available_portion():
		return false
	remaining_portions -= 1
	return true
