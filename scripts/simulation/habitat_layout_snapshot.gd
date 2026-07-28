class_name HabitatLayoutSnapshot
extends RefCounted

var active: bool = false
var grid_size: Vector2i = Vector2i.ZERO
var revision: int = 0
var facilities: Array[FacilitySnapshot] = []
var connections: Array[HabitatConnectionSnapshot] = []
var supplies: Array[FacilitySupplySnapshot] = []
var placement_options: Array[FacilityPlacementOptionSnapshot] = []
var action_pending: bool = false


func get_facility(facility_id: int) -> FacilitySnapshot:
	for facility: FacilitySnapshot in facilities:
		if facility.facility_id == facility_id:
			return facility
	return null


func get_supply(type_id: StringName) -> FacilitySupplySnapshot:
	for item: FacilitySupplySnapshot in supplies:
		if item.type_id == type_id:
			return item
	return null


func can_place(
	type_id: StringName,
	slot: Vector2i,
	orientation: int
) -> bool:
	for option: FacilityPlacementOptionSnapshot in placement_options:
		if (
			option.type_id == type_id
			and option.slot == slot
			and option.orientation == orientation
		):
			return true
	return false
