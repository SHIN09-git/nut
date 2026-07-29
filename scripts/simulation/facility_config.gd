class_name FacilityConfig
extends RefCounted

var type_id: StringName
var unlock_type_id: StringName
var footprint: Vector2i
var allowed_orientations: Array[int] = []
var ports: Array[FacilityPortConfig] = []
var placement_layer: FacilityData.PlacementLayer
var requires_connection: bool
var player_removable: bool
var effect_config: FacilityEffectConfig


static func from_data(data: FacilityData) -> FacilityConfig:
	if data == null or not data.is_valid():
		return null
	var config: FacilityConfig = FacilityConfig.new()
	config.type_id = data.type_id
	config.unlock_type_id = data.unlock_type_id
	config.footprint = data.footprint
	config.allowed_orientations.assign(data.allowed_orientations)
	for port_data: FacilityPortData in data.ports:
		var port: FacilityPortConfig = FacilityPortConfig.from_data(port_data)
		if port == null:
			return null
		config.ports.append(port)
	config.placement_layer = data.placement_layer
	config.requires_connection = data.requires_connection
	config.player_removable = data.player_removable
	config.effect_config = FacilityEffectConfig.from_data(data.effect_data)
	if config.effect_config == null:
		return null
	if (
		config.effect_config.provides_secondary_zone()
		and config.footprint != Vector2i(2, 2)
	):
		return null
	return config


func get_oriented_footprint(orientation: int) -> Vector2i:
	if posmod(orientation, 2) == 1:
		return Vector2i(footprint.y, footprint.x)
	return footprint


func get_occupied_cells(
	origin: Vector2i,
	orientation: int
) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	var size: Vector2i = get_oriented_footprint(orientation)
	for y: int in size.y:
		for x: int in size.x:
			result.append(origin + Vector2i(x, y))
	return result


func rotated_cell(
	local_cell: Vector2i,
	orientation: int
) -> Vector2i:
	match posmod(orientation, 4):
		0:
			return local_cell
		1:
			return Vector2i(
				footprint.y - 1 - local_cell.y,
				local_cell.x
			)
		2:
			return Vector2i(
				footprint.x - 1 - local_cell.x,
				footprint.y - 1 - local_cell.y
			)
		3:
			return Vector2i(
				local_cell.y,
				footprint.x - 1 - local_cell.x
			)
	return local_cell


func is_secondary_chamber_cell(local_cell: Vector2i) -> bool:
	return (
		effect_config != null
		and effect_config.provides_secondary_zone()
		and local_cell.x >= footprint.x / 2
	)
