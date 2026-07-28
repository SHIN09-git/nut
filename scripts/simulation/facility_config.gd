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
