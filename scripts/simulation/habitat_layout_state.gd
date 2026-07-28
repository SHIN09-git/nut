class_name HabitatLayoutState
extends RefCounted

var grid_size: Vector2i = Vector2i(12, 8)
var facilities: Dictionary[int, FacilityState] = {}
var connections: Dictionary[int, HabitatConnectionState] = {}
var supply: FacilitySupplyState = FacilitySupplyState.new()
var revision: int = 0
var _next_facility_id: int = 1
var _next_connection_id: int = 1
var _cached_revision: int = -1
var _adjacency_cache: Dictionary[StringName, Array] = {}


static func create_initial(
	zone_connections: Dictionary[StringName, Array],
	catalog: FacilityCatalogConfig
) -> HabitatLayoutState:
	var state: HabitatLayoutState = HabitatLayoutState.new()
	if catalog != null:
		state.grid_size = catalog.grid_size
		state.supply = FacilitySupplyState.new(
			catalog.initial_supply_counts
		)
		for initial: InitialFacilityConfig in catalog.initial_facilities:
			var type_config: FacilityConfig = catalog.get_type(
				initial.type_id
			)
			if type_config == null:
				return null
			state.facilities[initial.facility_id] = FacilityState.new(
				initial.facility_id,
				initial.type_id,
				initial.slot,
				initial.orientation,
				initial.zone_id,
				initial.available,
				initial.player_removable
					and type_config.player_removable
			)
			state._next_facility_id = maxi(
				state._next_facility_id,
				initial.facility_id + 1
			)
	var edge_keys: Dictionary[String, bool] = {}
	var sorted_zone_ids: Array[StringName] = []
	for zone_id: StringName in zone_connections:
		sorted_zone_ids.append(zone_id)
	sorted_zone_ids.sort_custom(
		func(first: StringName, second: StringName) -> bool:
			return String(first) < String(second)
	)
	for first_zone_id: StringName in sorted_zone_ids:
		var neighbor_ids: Array = zone_connections[first_zone_id]
		var sorted_neighbors: Array[StringName] = []
		for neighbor_value: Variant in neighbor_ids:
			sorted_neighbors.append(StringName(neighbor_value))
		sorted_neighbors.sort_custom(
			func(first: StringName, second: StringName) -> bool:
				return String(first) < String(second)
		)
		for second_zone_id: StringName in sorted_neighbors:
			var first_text: String = String(first_zone_id)
			var second_text: String = String(second_zone_id)
			var low: StringName = (
				first_zone_id if first_text < second_text else second_zone_id
			)
			var high: StringName = (
				second_zone_id if first_text < second_text else first_zone_id
			)
			var edge_key: String = "%s|%s" % [String(low), String(high)]
			if edge_keys.has(edge_key):
				continue
			edge_keys[edge_key] = true
			var connection_id: int = state._next_connection_id
			state._next_connection_id += 1
			state.connections[connection_id] = HabitatConnectionState.new(
				connection_id,
				low,
				high
			)
	if not state._has_valid_facility_geometry(catalog):
		return null
	return state


func copy_state() -> HabitatLayoutState:
	var copied: HabitatLayoutState = HabitatLayoutState.new()
	copied.grid_size = grid_size
	for facility_id: int in facilities:
		copied.facilities[facility_id] = facilities[facility_id].copy_state()
	for connection_id: int in connections:
		copied.connections[connection_id] = (
			connections[connection_id].copy_state()
		)
	copied.supply = supply.copy_state()
	copied.revision = revision
	copied._next_facility_id = _next_facility_id
	copied._next_connection_id = _next_connection_id
	return copied


func get_facility(facility_id: int) -> FacilityState:
	return facilities.get(facility_id)


func get_connection(connection_id: int) -> HabitatConnectionState:
	return connections.get(connection_id)


func get_facilities_in_stable_order() -> Array[FacilityState]:
	var ids: Array[int] = []
	ids.assign(facilities.keys())
	ids.sort()
	var result: Array[FacilityState] = []
	for facility_id: int in ids:
		result.append(facilities[facility_id])
	return result


func get_connections_in_stable_order() -> Array[HabitatConnectionState]:
	var ids: Array[int] = []
	ids.assign(connections.keys())
	ids.sort()
	var result: Array[HabitatConnectionState] = []
	for connection_id: int in ids:
		result.append(connections[connection_id])
	return result


func can_place(
	catalog: FacilityCatalogConfig,
	type_id: StringName,
	slot: Vector2i,
	orientation: int,
	unlocked_type_ids: Dictionary[StringName, bool]
) -> bool:
	return _is_placement_valid(
		catalog,
		type_id,
		slot,
		orientation,
		unlocked_type_ids,
		-1,
		true
	)


func place(
	catalog: FacilityCatalogConfig,
	type_id: StringName,
	slot: Vector2i,
	orientation: int,
	unlocked_type_ids: Dictionary[StringName, bool]
) -> int:
	if not can_place(
		catalog,
		type_id,
		slot,
		orientation,
		unlocked_type_ids
	):
		return -1
	if not supply.consume(type_id):
		return -1
	var facility_id: int = _next_facility_id
	_next_facility_id += 1
	var type_config: FacilityConfig = catalog.get_type(type_id)
	facilities[facility_id] = FacilityState.new(
		facility_id,
		type_id,
		slot,
		orientation,
		&"",
		true,
		type_config.player_removable
	)
	_mark_changed()
	return facility_id


func can_rotate(
	catalog: FacilityCatalogConfig,
	facility_id: int,
	orientation: int,
	unlocked_type_ids: Dictionary[StringName, bool]
) -> bool:
	var facility: FacilityState = get_facility(facility_id)
	return (
		facility != null
		and facility.player_removable
		and _is_placement_valid(
			catalog,
			facility.type_id,
			facility.slot,
			orientation,
			unlocked_type_ids,
			facility_id,
			false
		)
	)


func rotate(
	catalog: FacilityCatalogConfig,
	facility_id: int,
	orientation: int,
	unlocked_type_ids: Dictionary[StringName, bool]
) -> bool:
	if not can_rotate(
		catalog,
		facility_id,
		orientation,
		unlocked_type_ids
	):
		return false
	facilities[facility_id].orientation = orientation
	_mark_changed()
	return true


func remove(
	facility_id: int,
	catalog: FacilityCatalogConfig
) -> bool:
	var facility: FacilityState = get_facility(facility_id)
	if (
		facility == null
		or not facility.player_removable
		or catalog == null
		or catalog.get_type(facility.type_id) == null
		or not supply.remaining_by_type.has(facility.type_id)
	):
		return false
	for connection: HabitatConnectionState in connections.values():
		if connection.owner_facility_id == facility_id:
			connections.erase(connection.connection_id)
	facilities.erase(facility_id)
	if not supply.restore(facility.type_id):
		return false
	_mark_changed()
	return true


func set_connection_open(connection_id: int, value: bool) -> bool:
	var connection: HabitatConnectionState = get_connection(connection_id)
	if connection == null or not connection.gated or connection.open == value:
		return false
	connection.open = value
	_mark_changed()
	return true


func get_connected_zone_ids(zone_id: StringName) -> Array[StringName]:
	_rebuild_adjacency_if_needed()
	var result: Array[StringName] = []
	var values: Array = _adjacency_cache.get(zone_id, [])
	for value: Variant in values:
		result.append(StringName(value))
	return result


func are_directly_connected(
	first_zone_id: StringName,
	second_zone_id: StringName
) -> bool:
	return (
		first_zone_id == second_zone_id
		or get_connected_zone_ids(first_zone_id).has(second_zone_id)
	)


func has_valid_state(
	catalog: FacilityCatalogConfig,
	valid_zone_ids: Dictionary[StringName, bool]
) -> bool:
	if (
		grid_size.x < 4
		or grid_size.y < 4
		or revision < 0
		or _next_facility_id <= 0
		or _next_connection_id <= 0
		or supply == null
	):
		return false
	if catalog == null:
		if not facilities.is_empty() or not supply.remaining_by_type.is_empty():
			return false
	var initial_facility_ids: Dictionary[int, bool] = {}
	if catalog != null:
		for initial: InitialFacilityConfig in catalog.initial_facilities:
			initial_facility_ids[initial.facility_id] = true
			if not initial.player_removable:
				var fixed: FacilityState = get_facility(initial.facility_id)
				if (
					fixed == null
					or fixed.type_id != initial.type_id
					or fixed.slot != initial.slot
					or fixed.orientation != initial.orientation
					or fixed.zone_id != initial.zone_id
					or fixed.player_removable
				):
					return false
	var max_facility_id: int = 0
	var consumed_supply_by_type: Dictionary[StringName, int] = {}
	for facility: FacilityState in facilities.values():
		if facility == null:
			return false
		var type_config: FacilityConfig = (
			catalog.get_type(facility.type_id)
			if catalog != null
			else null
		)
		if (
			facility.facility_id <= 0
			or facility.type_id.is_empty()
			or facility.orientation < 0
			or facility.orientation > 3
			or (
				not facility.zone_id.is_empty()
				and not valid_zone_ids.has(facility.zone_id)
			)
			or type_config == null
			or facility.player_removable
				and not type_config.player_removable
		):
			return false
		if not initial_facility_ids.has(facility.facility_id):
			consumed_supply_by_type[facility.type_id] = (
				consumed_supply_by_type.get(facility.type_id, 0) + 1
			)
		max_facility_id = maxi(max_facility_id, facility.facility_id)
	if _next_facility_id <= max_facility_id:
		return false
	var max_connection_id: int = 0
	var edge_keys: Dictionary[String, bool] = {}
	for connection: HabitatConnectionState in connections.values():
		if (
			connection == null
			or connection.connection_id <= 0
			or connection.first_zone_id.is_empty()
			or connection.second_zone_id.is_empty()
			or connection.first_zone_id == connection.second_zone_id
			or not valid_zone_ids.has(connection.first_zone_id)
			or not valid_zone_ids.has(connection.second_zone_id)
			or not connection.gated and not connection.open
			or (
				connection.owner_facility_id >= 0
				and not facilities.has(connection.owner_facility_id)
			)
		):
			return false
		var edge_key: String = _edge_key(
			connection.first_zone_id,
			connection.second_zone_id
		)
		if edge_keys.has(edge_key):
			return false
		edge_keys[edge_key] = true
		max_connection_id = maxi(
			max_connection_id,
			connection.connection_id
		)
	if _next_connection_id <= max_connection_id:
		return false
	if catalog != null:
		if (
			supply.remaining_by_type.size()
			!= catalog.initial_supply_counts.size()
		):
			return false
		for type_id: StringName in catalog.initial_supply_counts:
			if (
				not supply.remaining_by_type.has(type_id)
				or catalog.get_type(type_id) == null
				or supply.get_remaining(type_id) < 0
				or supply.get_remaining(type_id)
					+ consumed_supply_by_type.get(type_id, 0)
					!= catalog.initial_supply_counts[type_id]
			):
				return false
		for type_id: StringName in consumed_supply_by_type:
			if not catalog.initial_supply_counts.has(type_id):
				return false
	return _has_valid_facility_geometry(catalog)


func _is_placement_valid(
	catalog: FacilityCatalogConfig,
	type_id: StringName,
	slot: Vector2i,
	orientation: int,
	unlocked_type_ids: Dictionary[StringName, bool],
	ignored_facility_id: int,
	require_supply: bool
) -> bool:
	if catalog == null:
		return false
	var type_config: FacilityConfig = catalog.get_type(type_id)
	if (
		type_config == null
		or not type_config.allowed_orientations.has(orientation)
		or not unlocked_type_ids.has(type_config.unlock_type_id)
		or require_supply and supply.get_remaining(type_id) <= 0
	):
		return false
	var occupied: Array[Vector2i] = type_config.get_occupied_cells(
		slot,
		orientation
	)
	for cell: Vector2i in occupied:
		if (
			cell.x < 0
			or cell.y < 0
			or cell.x >= grid_size.x
			or cell.y >= grid_size.y
		):
			return false
	for existing: FacilityState in facilities.values():
		if (
			existing.facility_id == ignored_facility_id
			or not existing.available
		):
			continue
		var existing_type: FacilityConfig = catalog.get_type(
			existing.type_id
		)
		if (
			existing_type == null
			or existing_type.placement_layer
				!= type_config.placement_layer
		):
			continue
		var existing_cells: Array[Vector2i] = (
			existing_type.get_occupied_cells(
				existing.slot,
				existing.orientation
			)
		)
		for cell: Vector2i in occupied:
			if existing_cells.has(cell):
				return false
	if not type_config.requires_connection:
		return true
	return _has_matching_port(
		catalog,
		type_config,
		slot,
		orientation,
		ignored_facility_id
	)


func _has_matching_port(
	catalog: FacilityCatalogConfig,
	type_config: FacilityConfig,
	slot: Vector2i,
	orientation: int,
	ignored_facility_id: int
) -> bool:
	for port: FacilityPortConfig in type_config.ports:
		var port_cell: Vector2i = (
			slot + port.rotated_cell(type_config.footprint, orientation)
		)
		var direction: int = port.rotated_direction(orientation)
		var adjacent_cell: Vector2i = (
			port_cell + _direction_vector(direction)
		)
		for existing: FacilityState in facilities.values():
			if (
				existing.facility_id == ignored_facility_id
				or not existing.available
			):
				continue
			var existing_type: FacilityConfig = catalog.get_type(
				existing.type_id
			)
			if existing_type == null:
				continue
			for existing_port: FacilityPortConfig in existing_type.ports:
				if (
					existing_port.connection_kind != port.connection_kind
					or existing_port.rotated_direction(
						existing.orientation
					) != posmod(direction + 2, 4)
				):
					continue
				var existing_cell: Vector2i = (
					existing.slot
					+ existing_port.rotated_cell(
						existing_type.footprint,
						existing.orientation
					)
				)
				if existing_cell == adjacent_cell:
					return true
	return false


func _has_valid_facility_geometry(
	catalog: FacilityCatalogConfig
) -> bool:
	if facilities.is_empty():
		return true
	if catalog == null:
		return false
	var occupied_by_layer: Dictionary[int, Dictionary] = {}
	for facility: FacilityState in get_facilities_in_stable_order():
		var type_config: FacilityConfig = catalog.get_type(facility.type_id)
		if (
			type_config == null
			or not type_config.allowed_orientations.has(
				facility.orientation
			)
		):
			return false
		var layer_cells: Dictionary = occupied_by_layer.get(
			type_config.placement_layer,
			{}
		)
		for cell: Vector2i in type_config.get_occupied_cells(
			facility.slot,
			facility.orientation
		):
			if (
				cell.x < 0
				or cell.y < 0
				or cell.x >= grid_size.x
				or cell.y >= grid_size.y
				or layer_cells.has(cell)
			):
				return false
			layer_cells[cell] = facility.facility_id
		occupied_by_layer[type_config.placement_layer] = layer_cells
	return true


func _mark_changed() -> void:
	revision += 1
	_cached_revision = -1


func _rebuild_adjacency_if_needed() -> void:
	if _cached_revision == revision:
		return
	_adjacency_cache.clear()
	for connection: HabitatConnectionState in get_connections_in_stable_order():
		if not connection.open:
			continue
		if not _adjacency_cache.has(connection.first_zone_id):
			_adjacency_cache[connection.first_zone_id] = []
		if not _adjacency_cache.has(connection.second_zone_id):
			_adjacency_cache[connection.second_zone_id] = []
		_adjacency_cache[connection.first_zone_id].append(
			connection.second_zone_id
		)
		_adjacency_cache[connection.second_zone_id].append(
			connection.first_zone_id
		)
	for zone_id: StringName in _adjacency_cache:
		_adjacency_cache[zone_id].sort_custom(
			func(first: StringName, second: StringName) -> bool:
				return String(first) < String(second)
		)
	_cached_revision = revision


func _direction_vector(direction: int) -> Vector2i:
	match direction:
		FacilityPortData.Direction.NORTH:
			return Vector2i.UP
		FacilityPortData.Direction.EAST:
			return Vector2i.RIGHT
		FacilityPortData.Direction.SOUTH:
			return Vector2i.DOWN
		FacilityPortData.Direction.WEST:
			return Vector2i.LEFT
	return Vector2i.ZERO


func _edge_key(first_zone_id: StringName, second_zone_id: StringName) -> String:
	var first: String = String(first_zone_id)
	var second: String = String(second_zone_id)
	return "%s|%s" % (
		[first, second] if first < second else [second, first]
	)
