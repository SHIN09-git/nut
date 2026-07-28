class_name FacilityPortConfig
extends RefCounted

var local_cell: Vector2i
var direction: FacilityPortData.Direction
var connection_kind: StringName


static func from_data(data: FacilityPortData) -> FacilityPortConfig:
	if data == null:
		return null
	var config: FacilityPortConfig = FacilityPortConfig.new()
	config.local_cell = data.local_cell
	config.direction = data.direction
	config.connection_kind = data.connection_kind
	return config


func rotated_cell(
	footprint: Vector2i,
	orientation: int
) -> Vector2i:
	match posmod(orientation, 4):
		0:
			return local_cell
		1:
			return Vector2i(footprint.y - 1 - local_cell.y, local_cell.x)
		2:
			return Vector2i(
				footprint.x - 1 - local_cell.x,
				footprint.y - 1 - local_cell.y
			)
		3:
			return Vector2i(local_cell.y, footprint.x - 1 - local_cell.x)
	return local_cell


func rotated_direction(orientation: int) -> int:
	return posmod(direction + orientation, 4)
