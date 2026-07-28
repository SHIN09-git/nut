class_name FoodStationFacilityEffectData
extends FacilityEffectData

@export var accepts_sugar: bool = true
@export var accepts_protein: bool = false
@export_range(1, 20, 1) var portion_capacity: int = 3
@export var host_zone_required: bool = false


func is_valid() -> bool:
	return (accepts_sugar or accepts_protein) and portion_capacity > 0
