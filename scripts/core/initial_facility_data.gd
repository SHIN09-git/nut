class_name InitialFacilityData
extends Resource

@export_range(1, 10_000, 1) var facility_id: int = 0
@export var type_id: StringName = &""
@export var slot: Vector2i = Vector2i.ZERO
@export_range(0, 3, 1) var orientation: int = 0
@export var zone_id: StringName = &""
@export var available: bool = true
@export var player_removable: bool = false


func is_valid() -> bool:
	return (
		facility_id > 0
		and not type_id.is_empty()
		and slot.x >= 0
		and slot.y >= 0
		and orientation >= 0
		and orientation <= 3
	)
