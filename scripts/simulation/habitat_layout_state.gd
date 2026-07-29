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


func assign_facility_zone(
	facility_id: int,
	zone_id: StringName
) -> bool:
	var facility: FacilityState = get_facility(facility_id)
	if facility == null or zone_id.is_empty() or not facility.zone_id.is_empty():
		return false
	facility.zone_id = zone_id
	_mark_changed()
	return true


func assign_facility_secondary_zone(
	facility_id: int,
	zone_id: StringName
) -> bool:
	var facility: FacilityState = get_facility(facility_id)
	if (
		facility == null
		or zone_id.is_empty()
		or not facility.secondary_zone_id.is_empty()
		or facility.zone_id == zone_id
	):
		return false
	facility.secondary_zone_id = zone_id
	_mark_changed()
	return true


func find_host_zone_id(
	catalog: FacilityCatalogConfig,
	type_id: StringName,
	slot: Vector2i,
	orientation: int
) -> StringName:
	if catalog == null:
		return &""
	var type_config: FacilityConfig = catalog.get_type(type_id)
	if (
		type_config == null
		or type_config.effect_config == null
		or not type_config.effect_config.requires_host_zone()
	):
		return &""
	var occupied: Array[Vector2i] = type_config.get_occupied_cells(
		slot,
		orientation
	)
	var host_zone_id: StringName = &""
	for existing: FacilityState in get_facilities_in_stable_order():
		if not existing.available or existing.zone_id.is_empty():
			continue
		var existing_type: FacilityConfig = catalog.get_type(
			existing.type_id
		)
		if (
			existing_type == null
			or existing_type.placement_layer
				!= FacilityData.PlacementLayer.BASE
		):
			continue
		var candidate_zone_id: StringName = &""
		for cell: Vector2i in existing_type.get_occupied_cells(
			existing.slot,
			existing.orientation
		):
			if occupied.has(cell):
				candidate_zone_id = _facility_zone_id_for_global_cell(
					existing,
					existing_type,
					cell
				)
				if candidate_zone_id.is_empty():
					return &""
				if (
					not host_zone_id.is_empty()
					and host_zone_id != candidate_zone_id
				):
					return &""
				host_zone_id = candidate_zone_id
		if candidate_zone_id.is_empty():
			continue
	return host_zone_id


func rebuild_derived_connections(catalog: FacilityCatalogConfig) -> bool:
	if catalog == null:
		return false
	var previous_by_edge: Dictionary[String, HabitatConnectionState] = {}
	var removed_ids: Array[int] = []
	for connection: HabitatConnectionState in connections.values():
		if connection.owner_facility_id < 0:
			continue
		previous_by_edge[_edge_key(
			connection.first_zone_id,
			connection.second_zone_id
		)] = connection.copy_state()
		removed_ids.append(connection.connection_id)
	for connection_id: int in removed_ids:
		connections.erase(connection_id)

	var created_edges: Dictionary[String, bool] = {}
	for facility: FacilityState in get_facilities_in_stable_order():
		if (
			not facility.available
			or facility.zone_id.is_empty()
			or facility.secondary_zone_id.is_empty()
		):
			continue
		_add_derived_connection(
			catalog,
			facility.zone_id,
			facility.secondary_zone_id,
			[],
			previous_by_edge,
			created_edges,
			facility.facility_id
		)
	var adjacency: Dictionary[int, Array] = (
		_build_facility_port_adjacency(catalog)
	)
	for source: FacilityState in get_facilities_in_stable_order():
		if not source.available or source.zone_id.is_empty():
			continue
		for starting_value: Variant in adjacency.get(
			source.facility_id,
			[]
		):
			var starting: Dictionary = starting_value
			var source_zone_id: StringName = StringName(
				starting.get("source_zone_id", "")
			)
			if source_zone_id.is_empty():
				continue
			var queue: Array[Dictionary] = [{
				"facility_id": int(starting["neighbor_id"]),
				"zone_id": String(starting.get("neighbor_zone_id", "")),
				"path": [],
			}]
			var visited: Dictionary[int, bool] = {
				source.facility_id: true
			}
			var queue_index: int = 0
			while queue_index < queue.size():
				var entry: Dictionary = queue[queue_index]
				queue_index += 1
				var current_id: int = int(entry["facility_id"])
				if visited.has(current_id):
					continue
				visited[current_id] = true
				var current: FacilityState = get_facility(current_id)
				if current == null or not current.available:
					continue
				var current_zone_id: StringName = StringName(
					entry.get("zone_id", "")
				)
				var connector_path: Array = entry["path"].duplicate()
				if not current_zone_id.is_empty():
					if (
						current.facility_id != source.facility_id
						and String(source_zone_id)
							< String(current_zone_id)
						and (
							not _is_initial_facility(
								catalog,
								source.facility_id
							)
							or not _is_initial_facility(
								catalog,
								current.facility_id
							)
						)
					):
						_add_derived_connection(
							catalog,
							source_zone_id,
							current_zone_id,
							connector_path,
							previous_by_edge,
							created_edges,
							maxi(
								source.facility_id,
								current.facility_id
							)
						)
					continue
				connector_path.append(current.facility_id)
				for next_value: Variant in adjacency.get(current_id, []):
					var next_edge: Dictionary = next_value
					var next_id: int = int(next_edge["neighbor_id"])
					if visited.has(next_id):
						continue
					queue.append({
						"facility_id": next_id,
						"zone_id": String(
							next_edge.get("neighbor_zone_id", "")
						),
						"path": connector_path.duplicate(),
					})
	_mark_changed()
	return true


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
			or (
				not facility.secondary_zone_id.is_empty()
				and not valid_zone_ids.has(facility.secondary_zone_id)
			)
			or (
				not facility.secondary_zone_id.is_empty()
				and facility.secondary_zone_id == facility.zone_id
			)
			or type_config == null
			or (
				type_config.effect_config.provides_secondary_zone()
				!= not facility.secondary_zone_id.is_empty()
			)
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
		return (
			not type_config.effect_config.requires_host_zone()
			or not find_host_zone_id(
				catalog,
				type_id,
				slot,
				orientation
			).is_empty()
		)
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


func _build_facility_port_adjacency(
	catalog: FacilityCatalogConfig
) -> Dictionary[int, Array]:
	var result: Dictionary[int, Array] = {}
	var stable: Array[FacilityState] = get_facilities_in_stable_order()
	for facility: FacilityState in stable:
		result[facility.facility_id] = []
	for first_index: int in stable.size():
		var first: FacilityState = stable[first_index]
		if not first.available:
			continue
		for second_index: int in range(first_index + 1, stable.size()):
			var second: FacilityState = stable[second_index]
			if not second.available:
				continue
			for edge: Dictionary in _matching_port_edges(
				catalog,
				first,
				second
			):
				result[first.facility_id].append({
					"neighbor_id": second.facility_id,
					"source_zone_id": edge["first_zone_id"],
					"neighbor_zone_id": edge["second_zone_id"],
				})
				result[second.facility_id].append({
					"neighbor_id": first.facility_id,
					"source_zone_id": edge["second_zone_id"],
					"neighbor_zone_id": edge["first_zone_id"],
				})
	for facility_id: int in result:
		result[facility_id].sort_custom(
			func(first: Dictionary, second: Dictionary) -> bool:
				if first["neighbor_id"] != second["neighbor_id"]:
					return first["neighbor_id"] < second["neighbor_id"]
				return String(first["neighbor_zone_id"]) < (
					String(second["neighbor_zone_id"])
				)
		)
	return result


func _matching_port_edges(
	catalog: FacilityCatalogConfig,
	first: FacilityState,
	second: FacilityState
) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var first_type: FacilityConfig = catalog.get_type(first.type_id)
	var second_type: FacilityConfig = catalog.get_type(second.type_id)
	if first_type == null or second_type == null:
		return result
	for first_port: FacilityPortConfig in first_type.ports:
		var first_cell: Vector2i = (
			first.slot
			+ first_port.rotated_cell(
				first_type.footprint,
				first.orientation
			)
		)
		var first_direction: int = first_port.rotated_direction(
			first.orientation
		)
		var adjacent_cell: Vector2i = (
			first_cell + _direction_vector(first_direction)
		)
		for second_port: FacilityPortConfig in second_type.ports:
			if (
				first_port.connection_kind != second_port.connection_kind
				or second_port.rotated_direction(second.orientation)
					!= posmod(first_direction + 2, 4)
			):
				continue
			var second_cell: Vector2i = (
				second.slot
				+ second_port.rotated_cell(
					second_type.footprint,
					second.orientation
				)
			)
			if adjacent_cell == second_cell:
				result.append({
					"first_zone_id": _facility_zone_id_for_port(
						first,
						first_type,
						first_port
					),
					"second_zone_id": _facility_zone_id_for_port(
						second,
						second_type,
						second_port
					),
				})
	return result


func _add_derived_connection(
	catalog: FacilityCatalogConfig,
	first_zone_id: StringName,
	second_zone_id: StringName,
	connector_path: Array,
	previous_by_edge: Dictionary[String, HabitatConnectionState],
	created_edges: Dictionary[String, bool],
	fallback_owner_facility_id: int
) -> void:
	var edge_key: String = _edge_key(first_zone_id, second_zone_id)
	if created_edges.has(edge_key) or _has_legacy_edge(edge_key):
		return
	created_edges[edge_key] = true
	var gate_ids: Array[int] = []
	var connector_ids: Array[int] = []
	for connector_value: Variant in connector_path:
		var connector_id: int = int(connector_value)
		var connector: FacilityState = get_facility(connector_id)
		if connector == null:
			continue
		var type_config: FacilityConfig = catalog.get_type(connector.type_id)
		if (
			type_config == null
			or type_config.effect_config.kind
				!= FacilityEffectConfig.Kind.CONNECTOR
		):
			continue
		connector_ids.append(connector_id)
		if type_config.effect_config.connector_gated:
			gate_ids.append(connector_id)
	gate_ids.sort()
	connector_ids.sort()
	var owner_facility_id: int = (
		gate_ids[0]
		if not gate_ids.is_empty()
		else connector_ids[0]
		if not connector_ids.is_empty()
		else fallback_owner_facility_id
	)
	var gated: bool = not gate_ids.is_empty()
	var previous: HabitatConnectionState = previous_by_edge.get(edge_key)
	var connection_id: int = (
		previous.connection_id if previous != null else _next_connection_id
	)
	if previous == null:
		_next_connection_id += 1
	var low: StringName = (
		first_zone_id
		if String(first_zone_id) < String(second_zone_id)
		else second_zone_id
	)
	var high: StringName = (
		second_zone_id if low == first_zone_id else first_zone_id
	)
	connections[connection_id] = HabitatConnectionState.new(
		connection_id,
		low,
		high,
		gated,
		previous.open if previous != null and gated else true,
		owner_facility_id
	)


func _facility_zone_id_for_port(
	facility: FacilityState,
	type_config: FacilityConfig,
	port: FacilityPortConfig
) -> StringName:
	if (
		type_config.effect_config.provides_secondary_zone()
		and type_config.is_secondary_chamber_cell(port.local_cell)
	):
		return facility.secondary_zone_id
	return facility.zone_id


func _facility_zone_id_for_global_cell(
	facility: FacilityState,
	type_config: FacilityConfig,
	global_cell: Vector2i
) -> StringName:
	var oriented_local: Vector2i = global_cell - facility.slot
	for y: int in type_config.footprint.y:
		for x: int in type_config.footprint.x:
			var local_cell: Vector2i = Vector2i(x, y)
			if (
				type_config.rotated_cell(
					local_cell,
					facility.orientation
				) != oriented_local
			):
				continue
			if type_config.is_secondary_chamber_cell(local_cell):
				return facility.secondary_zone_id
			return facility.zone_id
	return &""


func _has_legacy_edge(edge_key: String) -> bool:
	for connection: HabitatConnectionState in connections.values():
		if (
			connection.owner_facility_id < 0
			and _edge_key(
				connection.first_zone_id,
				connection.second_zone_id
			) == edge_key
		):
			return true
	return false


func _is_initial_facility(
	catalog: FacilityCatalogConfig,
	facility_id: int
) -> bool:
	for initial: InitialFacilityConfig in catalog.initial_facilities:
		if initial.facility_id == facility_id:
			return true
	return false


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
