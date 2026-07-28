class_name FacilityData
extends Resource

enum PlacementLayer {
	BASE,
	OVERLAY,
}

@export var type_id: StringName = &""
@export var unlock_type_id: StringName = &""
@export var data_status: StringName = &"prototype_pacing_fixture"
@export var footprint: Vector2i = Vector2i.ONE
@export var allowed_orientations: Array[int] = [0]
@export var ports: Array[FacilityPortData] = []
@export_enum("Base", "Overlay") var placement_layer: int = (
	PlacementLayer.BASE
)
@export var requires_connection: bool = true
@export var player_removable: bool = true


func is_valid() -> bool:
	if (
		type_id.is_empty()
		or unlock_type_id.is_empty()
		or data_status.is_empty()
		or footprint.x <= 0
		or footprint.y <= 0
		or footprint.x > 4
		or footprint.y > 4
		or allowed_orientations.is_empty()
		or placement_layer < PlacementLayer.BASE
		or placement_layer > PlacementLayer.OVERLAY
	):
		return false
	var seen_orientations: Dictionary[int, bool] = {}
	for orientation: int in allowed_orientations:
		if (
			orientation < 0
			or orientation > 3
			or seen_orientations.has(orientation)
		):
			return false
		seen_orientations[orientation] = true
	var seen_ports: Dictionary[String, bool] = {}
	for port: FacilityPortData in ports:
		if port == null or not port.is_valid_for_footprint(footprint):
			return false
		var key: String = "%d:%d:%d:%s" % [
			port.local_cell.x,
			port.local_cell.y,
			port.direction,
			String(port.connection_kind),
		]
		if seen_ports.has(key):
			return false
		seen_ports[key] = true
	return not requires_connection or not ports.is_empty()
