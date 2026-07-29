class_name ColonyState
extends RefCounted

const QUEEN_ENTITY_ID: int = 0
const MAX_RETAINED_OBSERVATION_EVENTS: int = 64

var simulation_tick: int = 0
var queen: QueenModel
var ants: Array[AntModel] = []
var zones: Array[HabitatZoneState] = []
var food_sources: Array[FoodSourceState] = []
var humidity_adjustment_count: int = 0
var water_action_unlocked: bool = false
var observation_stable_ticks: int = 0
var brood_humidity_observation_unlocked: bool = false
var shared_sugar_portions: int = 0
var total_sugar_portions_placed: int = 0
var unlocked_observation_card_ids: Dictionary[StringName, bool] = {}
var scenario_progress: ScenarioProgressState
var campaign_state: CampaignState
var nutrition_state: ColonyNutritionState
var act1_state: Act1State
var layout_state: HabitatLayoutState
var colony_work_state: ColonyWorkState
var _next_entity_id: int = 1
var _next_observation_event_id: int = 1
var _observation_events: Array[ObservationEvent] = []
var _ants_by_id: Dictionary[int, AntModel] = {}
var _ant_indexed_count: int = -1
var _zones_by_id: Dictionary[StringName, HabitatZoneState] = {}
var _zone_indexed_count: int = -1
var _workers_in_stable_order: Array[AntModel] = []
var _worker_indexed_ant_count: int = -1


func _init() -> void:
	queen = QueenModel.new(QUEEN_ENTITY_ID)


func create_egg(
	zone_id: StringName = &"",
	zone_entered_tick: int = 0
) -> AntModel:
	var egg: AntModel = AntModel.new(_next_entity_id, AntModel.LifeStage.EGG)
	_next_entity_id += 1
	if not zone_id.is_empty():
		egg.configure_brood(zone_id, zone_entered_tick)
	ants.append(egg)
	queen.laid_egg_count += 1
	return egg


func initialize_habitat(
	config: HabitatScenarioConfig,
	brood_care_config: BroodCareConfig,
	lifecycle_config: LifecycleConfig = null
) -> bool:
	if config == null or brood_care_config == null or not ants.is_empty():
		return false

	for zone: HabitatZoneState in config.zones:
		zones.append(zone.duplicate_environment_state())
	layout_state = HabitatLayoutState.create_initial(
		config.initial_zone_connections,
		config.facility_catalog_config
	)
	if layout_state == null:
		return false
	queen.assign_zone(config.nest_zone_id, 0)
	if config.colony_work_config != null:
		colony_work_state = ColonyWorkState.new()

	if config.supports_nutrition_growth():
		if config.nutrition_config == null or not config.lifecycle_active:
			return false
		nutrition_state = ColonyNutritionState.new(
			config.nutrition_config.initial_sugar_reserve_portions,
			config.nutrition_config.initial_protein_reserve_portions
		)

	if config.is_combined_observation() or config.is_act1_test_tube():
		var first_worker_initial_pupa_age_ticks: int = -1
		if config.is_combined_observation() and config.sequence_config != null:
			first_worker_initial_pupa_age_ticks = (
				config.sequence_config.first_worker_initial_pupa_age_ticks
			)
		elif config.is_act1_test_tube() and config.founding_care_config != null:
			first_worker_initial_pupa_age_ticks = (
				config.founding_care_config
					.first_worker_initial_pupa_age_ticks
			)
		if (
			lifecycle_config == null
			or first_worker_initial_pupa_age_ticks <= 0
			or first_worker_initial_pupa_age_ticks
				>= lifecycle_config.pupa_duration_ticks
		):
			return false
		var first_worker_pupa: AntModel = AntModel.new(
			_next_entity_id,
			AntModel.LifeStage.PUPA
		)
		_next_entity_id += 1
		first_worker_pupa.configure_brood(
			config.initial_brood_zone_id,
			-brood_care_config.minimum_zone_dwell_ticks
		)
		first_worker_pupa.stage_age_ticks = (
			first_worker_initial_pupa_age_ticks
		)
		first_worker_pupa.total_age_ticks = first_worker_pupa.stage_age_ticks
		ants.append(first_worker_pupa)
		if config.is_combined_observation():
			scenario_progress = ScenarioProgressState.new()
			scenario_progress.first_worker_entity_id = (
				first_worker_pupa.entity_id
			)
			campaign_state = CampaignState.new()
		else:
			act1_state = Act1State.new()
			act1_state.first_worker_entity_id = first_worker_pupa.entity_id
			campaign_state = CampaignState.new(
				CampaignState.Chapter.ACT1_FOUNDING
			)

	for worker_index: int in config.initial_worker_count:
		var worker: AntModel = AntModel.new(
			_next_entity_id,
			AntModel.LifeStage.WORKER
		)
		_next_entity_id += 1
		if config.supports_nutrition_growth():
			worker.configure_nutrition_worker(
				config.initial_worker_zone_id,
				config.nutrition_config.feeding_decision_interval_ticks
			)
			worker.worker_task.next_decision_tick = (
				brood_care_config.decision_interval_ticks
			)
		else:
			worker.configure_worker(
				config.initial_worker_zone_id,
				brood_care_config.decision_interval_ticks
			)
		ants.append(worker)

	for brood_index: int in config.initial_brood_count:
		var brood: AntModel = AntModel.new(
			_next_entity_id,
			config.initial_brood_stage
		)
		_next_entity_id += 1
		brood.configure_brood(
			config.initial_brood_zone_id,
			-brood_care_config.minimum_zone_dwell_ticks
		)
		ants.append(brood)

	if config.is_act1_test_tube():
		# The chapter opens after these brood were already laid. Counting them
		# prevents the lifecycle system from inventing a second founding batch.
		queen.laid_egg_count = ants.size()

	return true


func get_ant(entity_id: int) -> AntModel:
	_ensure_ant_index()
	return _ants_by_id.get(entity_id)


func get_zone(zone_id: StringName) -> HabitatZoneState:
	_ensure_zone_index()
	return _zones_by_id.get(zone_id)


func _invalidate_lookup_indexes() -> void:
	_ant_indexed_count = -1
	_zone_indexed_count = -1
	_worker_indexed_ant_count = -1


func get_workers_in_stable_order() -> Array[AntModel]:
	if _worker_indexed_ant_count != ants.size():
		_workers_in_stable_order.clear()
		for ant: AntModel in ants:
			if (
				ant != null
				and ant.life_stage == AntModel.LifeStage.WORKER
			):
				_workers_in_stable_order.append(ant)
		_workers_in_stable_order.sort_custom(
			func(first: AntModel, second: AntModel) -> bool:
				return first.entity_id < second.entity_id
		)
		_worker_indexed_ant_count = ants.size()
	return _workers_in_stable_order


func invalidate_worker_order() -> void:
	_worker_indexed_ant_count = -1


func _ensure_ant_index() -> void:
	if _ant_indexed_count == ants.size():
		return
	_ants_by_id.clear()
	for ant: AntModel in ants:
		if ant != null:
			_ants_by_id[ant.entity_id] = ant
	_ant_indexed_count = ants.size()


func _ensure_zone_index() -> void:
	if _zone_indexed_count == zones.size():
		return
	_zones_by_id.clear()
	for zone: HabitatZoneState in zones:
		if zone != null:
			_zones_by_id[zone.zone_id] = zone
	_zone_indexed_count = zones.size()


func get_connected_zone_ids(zone_id: StringName) -> Array[StringName]:
	if layout_state == null:
		return []
	return layout_state.get_connected_zone_ids(zone_id)


func are_zones_directly_connected(
	first_zone_id: StringName,
	second_zone_id: StringName
) -> bool:
	if layout_state == null:
		return false
	return layout_state.are_directly_connected(
		first_zone_id,
		second_zone_id
	)


func find_stable_zone_path(
	start_zone_id: StringName,
	target_zone_id: StringName
) -> Array[StringName]:
	var empty_path: Array[StringName] = []
	var start_zone: HabitatZoneState = get_zone(start_zone_id)
	var target_zone: HabitatZoneState = get_zone(target_zone_id)
	if (
		start_zone == null
		or target_zone == null
		or not start_zone.available
		or not target_zone.available
	):
		return empty_path
	if start_zone_id == target_zone_id:
		return [start_zone_id]
	var queue: Array[StringName] = [start_zone_id]
	var visited: Dictionary[StringName, bool] = {start_zone_id: true}
	var previous: Dictionary[StringName, StringName] = {}
	var queue_index: int = 0
	while queue_index < queue.size():
		var current_id: StringName = queue[queue_index]
		queue_index += 1
		for neighbor_id: StringName in get_connected_zone_ids(current_id):
			if visited.has(neighbor_id):
				continue
			var neighbor: HabitatZoneState = get_zone(neighbor_id)
			if neighbor == null or not neighbor.available:
				continue
			visited[neighbor_id] = true
			previous[neighbor_id] = current_id
			if neighbor_id == target_zone_id:
				return _reconstruct_zone_path(
					start_zone_id,
					target_zone_id,
					previous
				)
			queue.append(neighbor_id)
	return empty_path


func is_zone_route_valid(
	route_zone_ids: Array[StringName],
	start_zone_id: StringName,
	target_zone_id: StringName
) -> bool:
	if (
		route_zone_ids.is_empty()
		or route_zone_ids[0] != start_zone_id
		or route_zone_ids[-1] != target_zone_id
	):
		return false
	for index: int in route_zone_ids.size():
		var zone: HabitatZoneState = get_zone(route_zone_ids[index])
		if zone == null or not zone.available:
			return false
		if (
			index > 0
			and not are_zones_directly_connected(
				route_zone_ids[index - 1],
				zone.zone_id
			)
		):
			return false
	return true


func _reconstruct_zone_path(
	start_zone_id: StringName,
	target_zone_id: StringName,
	previous: Dictionary[StringName, StringName]
) -> Array[StringName]:
	var reversed_path: Array[StringName] = [target_zone_id]
	var current_id: StringName = target_zone_id
	while current_id != start_zone_id:
		if not previous.has(current_id):
			return []
		current_id = previous[current_id]
		reversed_path.append(current_id)
	reversed_path.reverse()
	return reversed_path


func create_food_source(
	zone_id: StringName,
	portion_count: int,
	food_type: FoodSourceState.FoodType
) -> FoodSourceState:
	if get_zone(zone_id) == null or portion_count <= 0:
		return null
	var source: FoodSourceState = FoodSourceState.new(
		_next_entity_id,
		zone_id,
		portion_count,
		food_type
	)
	_next_entity_id += 1
	food_sources.append(source)
	return source


func get_food_source(food_source_id: int) -> FoodSourceState:
	for source: FoodSourceState in food_sources:
		if source.entity_id == food_source_id:
			return source
	return null


func remove_food_source(food_source_id: int) -> bool:
	var source: FoodSourceState = get_food_source(food_source_id)
	if source == null or not source.available:
		return false
	# Keep a tombstone so removal cannot silently erase conserved portions.
	source.available = false
	return true


func copy_unlocked_observation_card_ids() -> Array[StringName]:
	var card_ids: Array[StringName] = []
	for card_id: StringName in unlocked_observation_card_ids:
		card_ids.append(card_id)
	card_ids.sort_custom(
		func(first: StringName, second: StringName) -> bool:
			return String(first) < String(second)
	)
	return card_ids


func record_observation_event(
	event_type: ObservationEvent.Type,
	actor_entity_id: int = ObservationEvent.NO_ENTITY_ID,
	subject_entity_id: int = ObservationEvent.NO_ENTITY_ID,
	source_zone_id: StringName = &"",
	target_zone_id: StringName = &""
) -> void:
	var event: ObservationEvent = ObservationEvent.new(
		_next_observation_event_id,
		simulation_tick,
		event_type,
		actor_entity_id,
		subject_entity_id,
		source_zone_id,
		target_zone_id
	)
	_next_observation_event_id += 1
	_observation_events.append(event)
	if _observation_events.size() > MAX_RETAINED_OBSERVATION_EVENTS:
		_observation_events.pop_front()


func copy_observation_events() -> Array[ObservationEvent]:
	var copied_events: Array[ObservationEvent] = []
	copied_events.resize(_observation_events.size())
	for index: int in _observation_events.size():
		copied_events[index] = _observation_events[index].copy_event()
	return copied_events
