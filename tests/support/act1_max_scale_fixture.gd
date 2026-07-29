class_name Act1MaxScaleFixture
extends RefCounted

const TARGET_WORKER_COUNT: int = 80
const TARGET_BROOD_COUNT: int = 180
const TARGET_FACILITY_COUNT: int = 48
const TARGET_ZONE_COUNT: int = 36
const TARGET_CONNECTION_COUNT: int = 72
const TARGET_FOOD_SOURCE_COUNT: int = 20
const ACTIVE_TASK_DURATION_TICKS: int = 300_001
const STRESS_SOURCE_ZONE_ID: StringName = &"stress_zone_001"
const STRESS_TARGET_ZONE_ID: StringName = &"stress_zone_002"
const CONNECTOR_TYPE_ID: StringName = &"connector_tube"
const EXPANDED_GRID_SIZE: Vector2i = Vector2i(24, 12)


static func create_simulation() -> ColonySimulation:
	var simulation: ColonySimulation = Act1FinaleFixture.create_simulation()
	if simulation == null or not simulation.is_ready():
		return simulation
	if not _complete_campaign(simulation):
		push_error("R16 max-scale fixture could not complete the campaign")
		return simulation
	if not _expand_zones(simulation):
		push_error("R16 max-scale fixture could not expand zones")
		return null
	if not _expand_facilities(simulation):
		push_error("R16 max-scale fixture could not expand facilities")
		return null
	if not _expand_connections(simulation):
		push_error("R16 max-scale fixture could not expand connections")
		return null
	if not _expand_colony(simulation):
		push_error("R16 max-scale fixture could not expand the colony")
		return null
	if not _expand_food_sources(simulation):
		push_error("R16 max-scale fixture could not expand food sources")
		return null
	if not simulation.has_valid_habitat_ownership():
		push_error(
			(
				"R16 max-scale fixture authority is invalid "
				+ "brood=%s foraging=%s nutrition=%s founding=%s "
				+ "campaign=%s environment=%s work=%s layout=%s"
			)
			% [
				simulation._brood_relocation_system.has_valid_ownership(
					simulation._state
				),
				simulation._foraging_system.has_valid_ownership(
					simulation._state
				),
				simulation._nutrition_system.has_valid_state(
					simulation._state
				),
				simulation._founding_care_system.has_valid_state(
					simulation._state
				),
				simulation._act1_campaign_director.has_valid_state(
					simulation._state
				),
				simulation._environment_system.has_valid_state(
					simulation._state
				),
				simulation._colony_work_system.has_valid_state(
					simulation._state
				),
				simulation._has_valid_layout_state(simulation._state),
			]
		)
		return null
	return simulation


static func _complete_campaign(simulation: ColonySimulation) -> bool:
	var required: int = (
		simulation._habitat_config.act1_progression_config
			.finale_stable_ticks
	)
	for unused_tick: int in required + 1:
		if not simulation.advance_tick(simulation._state.simulation_tick + 1):
			return false
	if (
		not simulation.submit_campaign_inference_action(
			CampaignState.INFERENCE_LAYOUT_SHAPES_BEHAVIOR
		)
		or not simulation.advance_tick(
			simulation._state.simulation_tick + 1
		)
	):
		return false
	return simulation.create_game_snapshot().campaign.completed


static func _expand_zones(simulation: ColonySimulation) -> bool:
	var state: ColonyState = simulation._state
	var config: HabitatScenarioConfig = simulation._habitat_config
	var additions_needed: int = TARGET_ZONE_COUNT - state.zones.size()
	if additions_needed < 2:
		return false
	for index: int in additions_needed:
		var zone_id: StringName = StringName(
			"stress_zone_%03d" % (index + 1)
		)
		var humidity: float = 0.30 if index == 0 else 0.66
		var light: float = 0.24 + float(index % 4) * 0.08
		var pollution: float = float(index % 5) * 0.012
		var state_zone := HabitatZoneState.new(
			zone_id,
			humidity,
			[],
			true,
			light,
			pollution,
			true,
			0
		)
		state.zones.append(state_zone)
		config.zones.append(state_zone.duplicate_state())
		config.initial_zone_connections[zone_id] = []
	return state.zones.size() == TARGET_ZONE_COUNT


static func _expand_facilities(simulation: ColonySimulation) -> bool:
	var state: ColonyState = simulation._state
	var layout: HabitatLayoutState = state.layout_state
	var catalog: FacilityCatalogConfig = (
		simulation._habitat_config.facility_catalog_config
	)
	var connector: FacilityConfig = catalog.get_type(CONNECTOR_TYPE_ID)
	if layout == null or connector == null:
		return false
	catalog.grid_size = EXPANDED_GRID_SIZE
	layout.grid_size = EXPANDED_GRID_SIZE
	var occupied: Dictionary[Vector2i, bool] = {}
	for facility: FacilityState in layout.get_facilities_in_stable_order():
		var type_config: FacilityConfig = catalog.get_type(facility.type_id)
		if type_config == null:
			return false
		for cell: Vector2i in type_config.get_occupied_cells(
			facility.slot,
			facility.orientation
		):
			occupied[cell] = true
	var added: int = 0
	for y: int in EXPANDED_GRID_SIZE.y:
		for x: int in EXPANDED_GRID_SIZE.x:
			if layout.facilities.size() >= TARGET_FACILITY_COUNT:
				break
			var slot := Vector2i(x, y)
			if occupied.has(slot):
				continue
			var facility_id: int = layout._next_facility_id
			layout._next_facility_id += 1
			layout.facilities[facility_id] = FacilityState.new(
				facility_id,
				CONNECTOR_TYPE_ID,
				slot,
				0
			)
			occupied[slot] = true
			added += 1
		if layout.facilities.size() >= TARGET_FACILITY_COUNT:
			break
	if layout.facilities.size() != TARGET_FACILITY_COUNT:
		return false
	for type_id: StringName in catalog.initial_supply_counts:
		var consumed_count: int = 0
		for facility: FacilityState in layout.facilities.values():
			if (
				facility.type_id == type_id
				and not _is_initial_facility(
					catalog,
					facility.facility_id
				)
			):
				consumed_count += 1
		catalog.initial_supply_counts[type_id] = consumed_count
		layout.supply.remaining_by_type[type_id] = 0
	if added > 0:
		layout.revision += 1
	return true


static func _is_initial_facility(
	catalog: FacilityCatalogConfig,
	facility_id: int
) -> bool:
	for initial: InitialFacilityConfig in catalog.initial_facilities:
		if initial.facility_id == facility_id:
			return true
	return false


static func _expand_connections(simulation: ColonySimulation) -> bool:
	var layout: HabitatLayoutState = simulation._state.layout_state
	var zone_ids: Array[StringName] = []
	for zone: HabitatZoneState in simulation._state.zones:
		zone_ids.append(zone.zone_id)
	zone_ids.sort_custom(
		func(first: StringName, second: StringName) -> bool:
			return String(first) < String(second)
	)
	var edge_keys: Dictionary[String, bool] = {}
	for connection: HabitatConnectionState in layout.connections.values():
		edge_keys[_edge_key(
			connection.first_zone_id,
			connection.second_zone_id
		)] = true
	_add_connection_if_missing(
		layout,
		STRESS_SOURCE_ZONE_ID,
		STRESS_TARGET_ZONE_ID,
		edge_keys
	)
	for first_index: int in zone_ids.size():
		for second_index: int in range(first_index + 1, zone_ids.size()):
			if layout.connections.size() >= TARGET_CONNECTION_COUNT:
				break
			_add_connection_if_missing(
				layout,
				zone_ids[first_index],
				zone_ids[second_index],
				edge_keys
			)
		if layout.connections.size() >= TARGET_CONNECTION_COUNT:
			break
	if layout.connections.size() != TARGET_CONNECTION_COUNT:
		return false
	layout.revision += 1
	return true


static func _add_connection_if_missing(
	layout: HabitatLayoutState,
	first_zone_id: StringName,
	second_zone_id: StringName,
	edge_keys: Dictionary[String, bool]
) -> void:
	var key: String = _edge_key(first_zone_id, second_zone_id)
	if edge_keys.has(key):
		return
	var low: StringName = (
		first_zone_id
		if String(first_zone_id) < String(second_zone_id)
		else second_zone_id
	)
	var high: StringName = (
		second_zone_id
		if low == first_zone_id
		else first_zone_id
	)
	var connection_id: int = layout._next_connection_id
	layout._next_connection_id += 1
	layout.connections[connection_id] = HabitatConnectionState.new(
		connection_id,
		low,
		high
	)
	edge_keys[key] = true


static func _edge_key(
	first_zone_id: StringName,
	second_zone_id: StringName
) -> String:
	var first_text: String = String(first_zone_id)
	var second_text: String = String(second_zone_id)
	return (
		"%s|%s" % [first_text, second_text]
		if first_text < second_text
		else "%s|%s" % [second_text, first_text]
	)


static func _expand_colony(simulation: ColonySimulation) -> bool:
	var state: ColonyState = simulation._state
	var workers: Array[AntModel] = []
	var brood: Array[AntModel] = []
	for ant: AntModel in state.ants:
		if ant.life_stage == AntModel.LifeStage.WORKER:
			workers.append(ant)
		else:
			brood.append(ant)
	while workers.size() < TARGET_WORKER_COUNT:
		var worker := AntModel.new(
			state._next_entity_id,
			AntModel.LifeStage.WORKER
		)
		state._next_entity_id += 1
		worker.configure_nutrition_worker(
			STRESS_SOURCE_ZONE_ID,
			state.simulation_tick + ACTIVE_TASK_DURATION_TICKS + 1
		)
		_set_worker_decision_boundaries(
			worker,
			state.simulation_tick + ACTIVE_TASK_DURATION_TICKS + 1
		)
		state.ants.append(worker)
		workers.append(worker)
	while brood.size() < TARGET_BROOD_COUNT:
		var larva := AntModel.new(
			state._next_entity_id,
			AntModel.LifeStage.LARVA
		)
		state._next_entity_id += 1
		larva.configure_brood(
			STRESS_SOURCE_ZONE_ID,
			-state.simulation_tick
		)
		state.ants.append(larva)
		brood.append(larva)
	for index: int in brood.size():
		brood[index].configure_brood(
			(
				STRESS_SOURCE_ZONE_ID
				if index < TARGET_WORKER_COUNT
				else StringName(
					"stress_zone_%03d"
					% (3 + posmod(index, TARGET_ZONE_COUNT - 7))
				)
			),
			-state.simulation_tick
		)
	for index: int in workers.size():
		var worker: AntModel = workers[index]
		worker.configure_nutrition_worker(
			STRESS_SOURCE_ZONE_ID,
			state.simulation_tick + ACTIVE_TASK_DURATION_TICKS + 1
		)
		_set_worker_decision_boundaries(
			worker,
			state.simulation_tick + ACTIVE_TASK_DURATION_TICKS + 1
		)
		worker.worker_task.begin(
			WorkerTaskModel.State.MOVING_TO_BROOD,
			STRESS_SOURCE_ZONE_ID,
			brood[index].entity_id,
			STRESS_TARGET_ZONE_ID,
			ACTIVE_TASK_DURATION_TICKS
		)
	state.nutrition_state.sugar_reserve_portions = 0
	return (
		_count_workers(state) == TARGET_WORKER_COUNT
		and state.ants.size() - _count_workers(state)
			== TARGET_BROOD_COUNT
	)


static func _set_worker_decision_boundaries(
	worker: AntModel,
	next_tick: int
) -> void:
	worker.worker_task.next_decision_tick = next_tick
	worker.feeding_task.next_decision_tick = next_tick
	worker.waste_cleanup_task.next_decision_tick = next_tick
	worker.scout_task.next_decision_tick = next_tick
	worker.migration_task.next_decision_tick = next_tick


static func _expand_food_sources(simulation: ColonySimulation) -> bool:
	var state: ColonyState = simulation._state
	var added_portions: int = 0
	while state.food_sources.size() < TARGET_FOOD_SOURCE_COUNT:
		if state.create_food_source(
			&"micro_feeding_port",
			1,
			FoodSourceState.FoodType.SUGAR_WATER
		) == null:
			return false
		added_portions += 1
	state.total_sugar_portions_placed += added_portions
	state.nutrition_state.total_sugar_portions_supplied += added_portions
	return state.food_sources.size() == TARGET_FOOD_SOURCE_COUNT


static func _count_workers(state: ColonyState) -> int:
	var count: int = 0
	for ant: AntModel in state.ants:
		if ant.life_stage == AntModel.LifeStage.WORKER:
			count += 1
	return count
