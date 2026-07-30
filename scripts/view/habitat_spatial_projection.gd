class_name HabitatSpatialProjection
extends RefCounted

const DEFAULT_PADDING: float = 24.0

var _grid_size: Vector2i = Vector2i.ZERO
var _content_rect: Rect2 = Rect2()
var _grid_rect: Rect2 = Rect2()
var _cell_size: float = 0.0


func configure(
	grid_size: Vector2i,
	content_rect: Rect2,
	padding: float = DEFAULT_PADDING
) -> bool:
	if (
		grid_size.x <= 0
		or grid_size.y <= 0
		or not content_rect.position.is_finite()
		or not content_rect.size.is_finite()
		or content_rect.size.x <= 0.0
		or content_rect.size.y <= 0.0
		or not is_finite(padding)
		or padding < 0.0
	):
		return false
	var inner: Rect2 = content_rect.grow(-padding)
	if inner.size.x <= 0.0 or inner.size.y <= 0.0:
		return false
	var next_cell_size: float = minf(
		inner.size.x / float(grid_size.x),
		inner.size.y / float(grid_size.y)
	)
	if not is_finite(next_cell_size) or next_cell_size <= 0.0:
		return false
	var grid_extent: Vector2 = Vector2(grid_size) * next_cell_size
	_grid_size = grid_size
	_content_rect = content_rect
	_cell_size = next_cell_size
	_grid_rect = Rect2(
		inner.get_center() - grid_extent * 0.5,
		grid_extent
	)
	return true


func is_ready() -> bool:
	return _grid_size.x > 0 and _grid_size.y > 0 and _cell_size > 0.0


func get_grid_size() -> Vector2i:
	return _grid_size


func get_content_rect() -> Rect2:
	return _content_rect


func get_grid_rect() -> Rect2:
	return _grid_rect


func get_cell_size() -> float:
	return _cell_size


func is_slot_inside(slot: Vector2i) -> bool:
	return (
		is_ready()
		and slot.x >= 0
		and slot.y >= 0
		and slot.x < _grid_size.x
		and slot.y < _grid_size.y
	)


func slot_rect(slot: Vector2i, footprint: Vector2i) -> Rect2:
	if (
		not is_ready()
		or footprint.x <= 0
		or footprint.y <= 0
	):
		return Rect2()
	return Rect2(
		_grid_rect.position + Vector2(slot) * _cell_size,
		Vector2(footprint) * _cell_size
	)


func facility_rect(facility: FacilitySnapshot) -> Rect2:
	if facility == null:
		return Rect2()
	return slot_rect(facility.slot, facility.footprint)


func facility_center(facility: FacilitySnapshot) -> Vector2:
	return facility_rect(facility).get_center()


func world_to_slot(world_position: Vector2) -> Vector2i:
	if not is_ready() or not world_position.is_finite():
		return Vector2i(-1, -1)
	var local: Vector2 = world_position - _grid_rect.position
	return Vector2i(
		floori(local.x / _cell_size),
		floori(local.y / _cell_size)
	)


func port_position(port: FacilityPortSnapshot) -> Vector2:
	if (
		port == null
		or not is_ready()
		or port.direction < FacilityPortData.Direction.NORTH
		or port.direction > FacilityPortData.Direction.WEST
	):
		return Vector2.ZERO
	var rect: Rect2 = slot_rect(port.global_cell, Vector2i.ONE)
	return (
		rect.get_center()
		+ _direction_vector(port.direction) * (_cell_size * 0.5)
	)


func facility_port_positions(
	facility: FacilitySnapshot
) -> PackedVector2Array:
	var result: PackedVector2Array = PackedVector2Array()
	if facility == null:
		return result
	for port: FacilityPortSnapshot in facility.ports:
		result.append(port_position(port))
	return result


func find_zone_anchor(
	layout: HabitatLayoutSnapshot,
	zone_id: StringName
) -> Variant:
	var facility: FacilitySnapshot = _find_zone_facility(layout, zone_id)
	if facility == null:
		return null
	return _facility_zone_anchor(facility, zone_id)


func build_logical_zone_anchor_index(
	layout: HabitatLayoutSnapshot,
	zones: Array[HabitatZoneSnapshot]
) -> Dictionary[StringName, Vector2]:
	var anchors: Dictionary[StringName, Vector2] = {}
	if layout == null or not is_ready():
		return anchors
	var selected_layers: Dictionary[StringName, int] = {}
	var ordered_facilities: Array[FacilitySnapshot] = []
	ordered_facilities.assign(layout.facilities)
	ordered_facilities.sort_custom(
		func(
			first: FacilitySnapshot,
			second: FacilitySnapshot
		) -> bool:
			if first.placement_layer != second.placement_layer:
				return first.placement_layer < second.placement_layer
			return first.facility_id < second.facility_id
	)
	for facility: FacilitySnapshot in ordered_facilities:
		if facility == null or not facility.available:
			continue
		for zone_id: StringName in [
			facility.zone_id,
			facility.secondary_zone_id,
		]:
			if zone_id.is_empty():
				continue
			var existing_layer: int = selected_layers.get(
				zone_id,
				-1
			)
			if (
				existing_layer == FacilityData.PlacementLayer.BASE
				or (
					existing_layer >= 0
					and facility.placement_layer
						!= FacilityData.PlacementLayer.BASE
				)
			):
				continue
			anchors[zone_id] = _facility_zone_anchor(
				facility,
				zone_id
			)
			selected_layers[zone_id] = facility.placement_layer
	var ordered_zones: Array[HabitatZoneSnapshot] = []
	ordered_zones.assign(zones)
	ordered_zones.sort_custom(
		func(
			first: HabitatZoneSnapshot,
			second: HabitatZoneSnapshot
		) -> bool:
			if first == null:
				return second != null
			if second == null:
				return false
			return String(first.zone_id) < String(second.zone_id)
	)
	for zone: HabitatZoneSnapshot in ordered_zones:
		if (
			zone == null
			or zone.zone_id.is_empty()
			or anchors.has(zone.zone_id)
		):
			continue
		var connected_ids: Array[StringName] = []
		connected_ids.assign(zone.connected_zone_ids)
		connected_ids.sort()
		var combined: Vector2 = Vector2.ZERO
		var anchor_count: int = 0
		for connected_zone_id: StringName in connected_ids:
			if not anchors.has(connected_zone_id):
				continue
			combined += anchors[connected_zone_id]
			anchor_count += 1
		if anchor_count > 0:
			anchors[zone.zone_id] = combined / float(anchor_count)
	return anchors


func _facility_zone_anchor(
	facility: FacilitySnapshot,
	zone_id: StringName
) -> Vector2:
	var rect: Rect2 = facility_rect(facility)
	if (
		facility.secondary_zone_id.is_empty()
		or (
			zone_id != facility.zone_id
			and zone_id != facility.secondary_zone_id
		)
	):
		return rect.get_center()
	var primary_axis: Vector2 = _primary_chamber_axis(
		facility.orientation
	)
	var extent: float = (
		rect.size.x * 0.25
		if not is_zero_approx(primary_axis.x)
		else rect.size.y * 0.25
	)
	var primary_anchor: Vector2 = (
		rect.get_center() + primary_axis * extent
	)
	if zone_id == facility.zone_id:
		return primary_anchor
	return rect.get_center() - primary_axis * extent


func find_logical_zone_anchor(
	layout: HabitatLayoutSnapshot,
	zones: Array[HabitatZoneSnapshot],
	zone_id: StringName
) -> Variant:
	var facility_anchor: Variant = find_zone_anchor(layout, zone_id)
	if facility_anchor is Vector2:
		return facility_anchor
	var zone: HabitatZoneSnapshot
	for candidate: HabitatZoneSnapshot in zones:
		if candidate != null and candidate.zone_id == zone_id:
			zone = candidate
			break
	if zone == null:
		return null
	var connected_ids: Array[StringName] = []
	connected_ids.assign(zone.connected_zone_ids)
	connected_ids.sort()
	var connected_anchors: Array[Vector2] = []
	for connected_zone_id: StringName in connected_ids:
		var connected_anchor: Variant = find_zone_anchor(
			layout,
			connected_zone_id
		)
		if connected_anchor is Vector2:
			connected_anchors.append(connected_anchor as Vector2)
	if connected_anchors.is_empty():
		return null
	var combined: Vector2 = Vector2.ZERO
	for connected_anchor: Vector2 in connected_anchors:
		combined += connected_anchor
	return combined / float(connected_anchors.size())


func connection_endpoints(
	layout: HabitatLayoutSnapshot,
	connection: HabitatConnectionSnapshot
) -> PackedVector2Array:
	var result: PackedVector2Array = PackedVector2Array()
	if layout == null or connection == null:
		return result
	var first: Variant = find_zone_anchor(
		layout,
		connection.first_zone_id
	)
	var second: Variant = find_zone_anchor(
		layout,
		connection.second_zone_id
	)
	if not first is Vector2 or not second is Vector2:
		return result
	result.append(first as Vector2)
	result.append(second as Vector2)
	return result


func find_top_facility_at(
	layout: HabitatLayoutSnapshot,
	world_position: Vector2
) -> int:
	if (
		layout == null
		or not is_ready()
		or not world_position.is_finite()
	):
		return -1
	var candidates: Array[FacilitySnapshot] = []
	for facility: FacilitySnapshot in layout.facilities:
		if (
			facility.available
			and facility_rect(facility).has_point(world_position)
		):
			candidates.append(facility)
	candidates.sort_custom(
		func(
			first: FacilitySnapshot,
			second: FacilitySnapshot
		) -> bool:
			if first.placement_layer != second.placement_layer:
				return first.placement_layer < second.placement_layer
			return first.facility_id < second.facility_id
	)
	return candidates[-1].facility_id if not candidates.is_empty() else -1


func _find_zone_facility(
	layout: HabitatLayoutSnapshot,
	zone_id: StringName
) -> FacilitySnapshot:
	if layout == null or zone_id.is_empty():
		return null
	var candidates: Array[FacilitySnapshot] = []
	for facility: FacilitySnapshot in layout.facilities:
		if (
			facility.available
			and (
				facility.zone_id == zone_id
				or facility.secondary_zone_id == zone_id
			)
		):
			candidates.append(facility)
	candidates.sort_custom(
		func(
			first: FacilitySnapshot,
			second: FacilitySnapshot
		) -> bool:
			if first.placement_layer != second.placement_layer:
				return first.placement_layer < second.placement_layer
			return first.facility_id < second.facility_id
	)
	for facility: FacilitySnapshot in candidates:
		if facility.placement_layer == FacilityData.PlacementLayer.BASE:
			return facility
	return candidates[0] if not candidates.is_empty() else null


func _direction_vector(direction: int) -> Vector2:
	match direction:
		FacilityPortData.Direction.NORTH:
			return Vector2.UP
		FacilityPortData.Direction.EAST:
			return Vector2.RIGHT
		FacilityPortData.Direction.SOUTH:
			return Vector2.DOWN
		FacilityPortData.Direction.WEST:
			return Vector2.LEFT
	return Vector2.ZERO


func _primary_chamber_axis(orientation: int) -> Vector2:
	match posmod(orientation, 4):
		0:
			return Vector2.LEFT
		1:
			return Vector2.UP
		2:
			return Vector2.RIGHT
		3:
			return Vector2.DOWN
	return Vector2.LEFT
