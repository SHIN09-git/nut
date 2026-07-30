class_name FacilityPortSnapshot
extends RefCounted

var global_cell: Vector2i
var direction: FacilityPortData.Direction
var connection_kind: StringName


func _init(
	new_global_cell: Vector2i,
	new_direction: FacilityPortData.Direction,
	new_connection_kind: StringName
) -> void:
	global_cell = new_global_cell
	direction = new_direction
	connection_kind = new_connection_kind
