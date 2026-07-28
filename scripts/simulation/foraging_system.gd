class_name ForagingSystem
extends RefCounted

var _config: ForagingConfig
var _scenario_config: HabitatScenarioConfig
var _nest_zone_id: StringName = &""
var _sugar_placement_zone_id: StringName = &""
var _sugar_portions: int = 0
var _observation_card_id: StringName = &""
var _route_cache: Dictionary[String, Array] = {}


func _init(
	config: ForagingConfig,
	scenario_config: HabitatScenarioConfig
) -> void:
	_config = config
	_scenario_config = scenario_config
	if scenario_config == null:
		return
	_nest_zone_id = scenario_config.nest_zone_id
	_sugar_placement_zone_id = scenario_config.sugar_placement_zone_id
	_sugar_portions = scenario_config.sugar_portions
	_observation_card_id = scenario_config.foraging_observation_card_id


func is_ready() -> bool:
	return (
		_config != null
		and _scenario_config != null
		and not _nest_zone_id.is_empty()
		and not _sugar_placement_zone_id.is_empty()
		and _sugar_portions > 0
		and not _observation_card_id.is_empty()
	)


func apply_configured_sugar_placement(state: ColonyState) -> FoodSourceState:
	if (
		state == null
		or not is_ready()
		or (
			state.nutrition_state == null
			and state.total_sugar_portions_placed > 0
		)
		or (
			state.nutrition_state != null
			and has_available_source_type(
				state,
				FoodSourceState.FoodType.SUGAR_WATER
			)
		)
	):
		return null
	var placement_zone: HabitatZoneState = state.get_zone(
		_sugar_placement_zone_id
	)
	if placement_zone == null or not placement_zone.available:
		return null

	var source: FoodSourceState = state.create_food_source(
		_sugar_placement_zone_id,
		_sugar_portions,
		FoodSourceState.FoodType.SUGAR_WATER
	)
	if source == null:
		return null
	state.total_sugar_portions_placed += _sugar_portions
	if state.nutrition_state != null:
		state.nutrition_state.total_sugar_portions_supplied += (
			_sugar_portions
		)
	return source


func apply_configured_protein_placement(
	state: ColonyState
) -> FoodSourceState:
	if (
		state == null
		or not is_ready()
		or state.nutrition_state == null
		or not _scenario_config.is_nutrition_growth()
		or has_available_source_type(
			state,
			FoodSourceState.FoodType.PROTEIN
		)
	):
		return null
	var placement_zone: HabitatZoneState = state.get_zone(
		_scenario_config.protein_placement_zone_id
	)
	if placement_zone == null or not placement_zone.available:
		return null
	var source: FoodSourceState = state.create_food_source(
		_scenario_config.protein_placement_zone_id,
		_scenario_config.protein_portions,
		FoodSourceState.FoodType.PROTEIN
	)
	if source == null:
		return null
	state.nutrition_state.total_protein_portions_placed += (
		_scenario_config.protein_portions
	)
	state.nutrition_state.total_protein_portions_supplied += (
		_scenario_config.protein_portions
	)
	return source


func has_available_source_type(
	state: ColonyState,
	food_type: FoodSourceState.FoodType
) -> bool:
	if state == null:
		return false
	for source: FoodSourceState in state.food_sources:
		if (
			source.food_type == food_type
			and source.has_available_portion()
		):
			return true
	return false


func validate_tasks(state: ColonyState) -> void:
	if state == null or not is_ready():
		return

	var claimed_source_ids: Dictionary[int, int] = {}
	for worker: AntModel in _get_workers_in_stable_order(state):
		var task: ForagingTaskModel = _get_foraging_task(worker)
		if task == null or task.state == ForagingTaskModel.State.IDLE:
			continue

		if claimed_source_ids.has(task.target_food_source_id):
			if task.is_pre_collection():
				var duplicate_source: FoodSourceState = _get_food_source(
					state,
					task.target_food_source_id
				)
				_cancel_pre_collection_task(
					state,
					worker,
					task,
					duplicate_source
				)
			continue
		claimed_source_ids[task.target_food_source_id] = worker.entity_id

		if task.is_pre_collection():
			var source: FoodSourceState = _get_food_source(
				state,
				task.target_food_source_id
			)
			if not _is_pre_collection_source_valid(state, source):
				_cancel_pre_collection_task(state, worker, task, source)
				continue
			if task.state == ForagingTaskModel.State.COLLECTING:
				if worker.zone_id != source.zone_id:
					_cancel_pre_collection_task(state, worker, task, source)
				continue

			var route: Array[StringName] = task.route_zone_ids
			if not _is_route_valid(
				state,
				route,
				worker.zone_id,
				source.zone_id
			):
				var route_cache_key: String = _make_route_cache_key(
					state,
					worker.zone_id,
					source.zone_id
				)
				if task.route_cache_key == route_cache_key:
					_cancel_pre_collection_task(
						state,
						worker,
						task,
						source
					)
					continue
				route = _find_stable_path(
					state,
					worker.zone_id,
					source.zone_id
				)
				task.route_cache_key = route_cache_key
				if route.is_empty():
					_cancel_pre_collection_task(state, worker, task, source)
					continue
				task.route_zone_ids.assign(route)
				task.origin_zone_id = worker.zone_id
				task.target_zone_id = source.zone_id
			else:
				task.route_cache_key = _make_route_cache_key(
					state,
					worker.zone_id,
					source.zone_id
				)
			continue

		if task.is_carrying():
			if (
				task.carried_portions != 1
				or state.get_zone(_nest_zone_id) == null
			):
				continue
			if task.state == ForagingTaskModel.State.SHARING:
				continue
			if _is_route_valid(
				state,
				task.route_zone_ids,
				worker.zone_id,
				_nest_zone_id
			):
				task.route_cache_key = _make_route_cache_key(
					state,
					worker.zone_id,
					_nest_zone_id
				)
				continue
			var return_route_cache_key: String = _make_route_cache_key(
				state,
				worker.zone_id,
				_nest_zone_id
			)
			if task.route_cache_key == return_route_cache_key:
				continue
			var return_route: Array[StringName] = _find_stable_path(
				state,
				worker.zone_id,
				_nest_zone_id
			)
			task.route_cache_key = return_route_cache_key
			if not return_route.is_empty():
				task.route_zone_ids.assign(return_route)
				task.origin_zone_id = worker.zone_id
				task.target_zone_id = _nest_zone_id


func advance_tasks(state: ColonyState) -> void:
	if state == null or not is_ready():
		return

	for worker: AntModel in _get_workers_in_stable_order(state):
		var task: ForagingTaskModel = _get_foraging_task(worker)
		if task == null or task.state == ForagingTaskModel.State.IDLE:
			continue
		if (
			task.state == ForagingTaskModel.State.RETURNING_TO_NEST
			and not _is_route_valid(
				state,
				task.route_zone_ids,
				worker.zone_id,
				_nest_zone_id
			)
		):
			continue
		if (
			task.state == ForagingTaskModel.State.SHARING
			and not _can_share_at_nest(state, worker)
		):
			continue

		task.elapsed_ticks += 1
		if task.elapsed_ticks < task.duration_ticks:
			continue

		match task.state:
			ForagingTaskModel.State.SEEKING_FOOD:
				_begin_food_travel(state, worker, task)
			ForagingTaskModel.State.MOVING_TO_FOOD:
				_begin_collection(state, worker, task)
			ForagingTaskModel.State.COLLECTING:
				_collect_and_begin_return(state, worker, task)
			ForagingTaskModel.State.RETURNING_TO_NEST:
				_begin_sharing(state, worker, task)
			ForagingTaskModel.State.SHARING:
				_complete_sharing(state, worker, task)


func assign_idle_workers(state: ColonyState) -> void:
	if state == null or not is_ready():
		return

	var claimed_source_ids: Dictionary[int, int] = (
		_get_claimed_source_ids(state)
	)
	for worker: AntModel in _get_workers_in_stable_order(state):
		var task: ForagingTaskModel = _get_or_create_foraging_task(worker)
		if task == null or not _is_worker_available(worker, task):
			continue
		var assignment: Dictionary = _find_assignment(
			state,
			worker,
			claimed_source_ids
		)
		if assignment.is_empty():
			continue

		var source: FoodSourceState = (
			assignment["source"] as FoodSourceState
		)
		var route: Array[StringName] = []
		route.assign(assignment["route"] as Array)
		task.begin(
			ForagingTaskModel.State.SEEKING_FOOD,
			source.entity_id,
			worker.zone_id,
			source.zone_id,
			_nest_zone_id,
			route,
			_config.discovery_delay_ticks
		)
		task.route_cache_key = _make_route_cache_key(
			state,
			worker.zone_id,
			source.zone_id
		)
		_record_event(
			state,
			ObservationEvent.Type.FOOD_SEEK_STARTED,
			worker.entity_id,
			source.entity_id,
			worker.zone_id,
			source.zone_id
		)
		claimed_source_ids[source.entity_id] = worker.entity_id


func has_valid_ownership(state: ColonyState) -> bool:
	if state == null or not is_ready():
		return false

	var sources_by_id: Dictionary[int, FoodSourceState] = {}
	var remaining_portions: int = 0
	for source: FoodSourceState in _get_food_sources(state):
		if (
			source.entity_id < 0
			or sources_by_id.has(source.entity_id)
			or source.zone_id.is_empty()
			or state.get_zone(source.zone_id) == null
			or source.remaining_portions < 0
		):
			return false
		sources_by_id[source.entity_id] = source
		remaining_portions += source.remaining_portions

	var claimed_source_ids: Dictionary[int, int] = {}
	var carried_portions: int = 0
	for worker: AntModel in _get_workers_in_stable_order(state):
		if state.get_zone(worker.zone_id) == null:
			return false
		var task: ForagingTaskModel = _get_foraging_task(worker)
		if task == null:
			return false
		var relocation_active: bool = (
			worker.worker_task != null
			and worker.worker_task.state != WorkerTaskModel.State.IDLE
		)
		if relocation_active and task.state != ForagingTaskModel.State.IDLE:
			return false
		var feeding_active: bool = (
			worker.feeding_task != null
			and worker.feeding_task.state
				!= BroodFeedingTaskModel.State.IDLE
		)
		if feeding_active and task.state != ForagingTaskModel.State.IDLE:
			return false

		if task.state == ForagingTaskModel.State.IDLE:
			if not _is_idle_task_clean(task):
				return false
			continue

		if claimed_source_ids.has(task.target_food_source_id):
			return false
		claimed_source_ids[task.target_food_source_id] = worker.entity_id

		if task.is_pre_collection():
			var source: FoodSourceState = sources_by_id.get(
				task.target_food_source_id
			)
			if (
				source == null
				or not source.available
				or task.carried_portions != 0
				or task.nest_zone_id != _nest_zone_id
				or task.duration_ticks <= 0
			):
				return false
			if source.remaining_portions <= 0:
				return false
			if (
				task.state == ForagingTaskModel.State.COLLECTING
				and worker.zone_id != source.zone_id
			):
				return false
			continue

		if task.is_carrying():
			if (
				task.carried_portions != 1
				or task.nest_zone_id != _nest_zone_id
				or state.get_zone(task.nest_zone_id) == null
				or task.duration_ticks <= 0
			):
				return false
			if (
				task.state == ForagingTaskModel.State.SHARING
				and worker.zone_id != _nest_zone_id
			):
				return false
			carried_portions += 1
			continue
		return false

	if state.nutrition_state != null:
		return _has_valid_nutrition_conservation(
			state,
			sources_by_id
		)
	var shared_portions: int = state.shared_sugar_portions
	var total_placed: int = state.total_sugar_portions_placed
	if shared_portions < 0 or total_placed < 0:
		return false
	return (
		remaining_portions + carried_portions + shared_portions
		== total_placed
	)


func _begin_food_travel(
	state: ColonyState,
	worker: AntModel,
	task: ForagingTaskModel
) -> void:
	var source: FoodSourceState = _get_food_source(
		state,
		task.target_food_source_id
	)
	if not _is_pre_collection_source_valid(state, source):
		_cancel_pre_collection_task(state, worker, task, source)
		return
	var route: Array[StringName] = task.route_zone_ids
	if not _is_route_valid(
		state,
		route,
		worker.zone_id,
		source.zone_id
	):
		route = _find_stable_path(
			state,
			worker.zone_id,
			source.zone_id
		)
	if route.is_empty():
		_cancel_pre_collection_task(state, worker, task, source)
		return
	task.begin(
		ForagingTaskModel.State.MOVING_TO_FOOD,
		source.entity_id,
		worker.zone_id,
		source.zone_id,
		_nest_zone_id,
		route,
		_config.outbound_travel_duration_ticks
	)
	task.route_cache_key = _make_route_cache_key(
		state,
		worker.zone_id,
		source.zone_id
	)
	_record_event(
		state,
		ObservationEvent.Type.FOOD_TRAVEL_STARTED,
		worker.entity_id,
		source.entity_id,
		worker.zone_id,
		source.zone_id
	)


func _begin_collection(
	state: ColonyState,
	worker: AntModel,
	task: ForagingTaskModel
) -> void:
	var source: FoodSourceState = _get_food_source(
		state,
		task.target_food_source_id
	)
	if not _is_pre_collection_source_valid(state, source):
		_cancel_pre_collection_task(state, worker, task, source)
		return
	worker.zone_id = source.zone_id
	task.begin(
		ForagingTaskModel.State.COLLECTING,
		source.entity_id,
		source.zone_id,
		source.zone_id,
		_nest_zone_id,
		[source.zone_id],
		_config.collection_duration_ticks
	)
	task.route_cache_key = _make_route_cache_key(
		state,
		source.zone_id,
		source.zone_id
	)


func _collect_and_begin_return(
	state: ColonyState,
	worker: AntModel,
	task: ForagingTaskModel
) -> void:
	var source: FoodSourceState = _get_food_source(
		state,
		task.target_food_source_id
	)
	if source == null or not source.take_portion():
		_cancel_pre_collection_task(state, worker, task, source)
		return

	var source_id: int = source.entity_id
	var source_zone_id: StringName = source.zone_id
	task.carried_portions = 1
	_record_event(
		state,
		(
			ObservationEvent.Type.PROTEIN_COLLECTED
			if source.food_type == FoodSourceState.FoodType.PROTEIN
			else ObservationEvent.Type.SUGAR_COLLECTED
		),
		worker.entity_id,
		source_id,
		source_zone_id,
		_nest_zone_id
	)
	var return_route: Array[StringName] = _find_stable_path(
		state,
		worker.zone_id,
		_nest_zone_id
	)
	task.begin(
		ForagingTaskModel.State.RETURNING_TO_NEST,
		source_id,
		worker.zone_id,
		_nest_zone_id,
		_nest_zone_id,
		return_route,
		_config.return_travel_duration_ticks
	)
	task.route_cache_key = _make_route_cache_key(
		state,
		worker.zone_id,
		_nest_zone_id
	)
	_record_event(
		state,
		(
			ObservationEvent.Type.PROTEIN_RETURN_STARTED
			if source.food_type == FoodSourceState.FoodType.PROTEIN
			else ObservationEvent.Type.SUGAR_RETURN_STARTED
		),
		worker.entity_id,
		source_id,
		source_zone_id,
		_nest_zone_id
	)


func _begin_sharing(
	state: ColonyState,
	worker: AntModel,
	task: ForagingTaskModel
) -> void:
	var source_id: int = task.target_food_source_id
	var origin_zone_id: StringName = task.origin_zone_id
	worker.zone_id = _nest_zone_id
	task.begin(
		ForagingTaskModel.State.SHARING,
		source_id,
		origin_zone_id,
		_nest_zone_id,
		_nest_zone_id,
		[_nest_zone_id],
		_config.sharing_duration_ticks
	)
	task.route_cache_key = _make_route_cache_key(
		state,
		_nest_zone_id,
		_nest_zone_id
	)


func _complete_sharing(
	state: ColonyState,
	worker: AntModel,
	task: ForagingTaskModel
) -> void:
	if task.carried_portions != 1:
		return
	var source_id: int = task.target_food_source_id
	var source_zone_id: StringName = task.origin_zone_id
	var source: FoodSourceState = state.get_food_source(source_id)
	if source == null:
		return
	task.carried_portions = 0
	if source.food_type == FoodSourceState.FoodType.PROTEIN:
		if state.nutrition_state == null:
			return
		state.nutrition_state.protein_reserve_portions += 1
		state.nutrition_state.delivered_protein_portions += 1
		_record_event(
			state,
			ObservationEvent.Type.PROTEIN_DELIVERED,
			worker.entity_id,
			source_id,
			source_zone_id,
			_nest_zone_id
		)
	else:
		state.shared_sugar_portions += 1
		if state.nutrition_state != null:
			state.nutrition_state.sugar_reserve_portions += 1
		_record_event(
			state,
			ObservationEvent.Type.SUGAR_SHARED,
			worker.entity_id,
			source_id,
			source_zone_id,
			_nest_zone_id
		)
	task.reset_to_idle()
	if source.food_type == FoodSourceState.FoodType.SUGAR_WATER:
		_unlock_observation_if_complete(state)


func _unlock_observation_if_complete(state: ColonyState) -> void:
	var total_placed: int = state.total_sugar_portions_placed
	if (
		total_placed <= 0
		or state.shared_sugar_portions < total_placed
		or _is_observation_card_unlocked(state)
	):
		return
	if not _unlock_observation_card(state):
		return
	_record_event(
		state,
		ObservationEvent.Type.SUGAR_OBSERVATION_COMPLETED,
		ObservationEvent.NO_ENTITY_ID,
		ObservationEvent.NO_ENTITY_ID,
		_sugar_placement_zone_id,
		_nest_zone_id
	)


func _cancel_pre_collection_task(
	state: ColonyState,
	worker: AntModel,
	task: ForagingTaskModel,
	source: FoodSourceState
) -> void:
	var source_zone_id: StringName = (
		source.zone_id if source != null else task.target_zone_id
	)
	_record_event(
		state,
		ObservationEvent.Type.FORAGING_TASK_CANCELLED,
		worker.entity_id,
		task.target_food_source_id,
		worker.zone_id,
		source_zone_id
	)
	task.reset_to_idle()


func _find_assignment(
	state: ColonyState,
	worker: AntModel,
	claimed_source_ids: Dictionary[int, int]
) -> Dictionary:
	for source: FoodSourceState in _get_food_sources_in_stable_order(state):
		if (
			not source.has_available_portion()
			or claimed_source_ids.has(source.entity_id)
		):
			continue
		var route: Array[StringName] = _find_stable_path(
			state,
			worker.zone_id,
			source.zone_id
		)
		if not route.is_empty():
			return {"source": source, "route": route}
	return {}


func _find_stable_path(
	state: ColonyState,
	start_zone_id: StringName,
	target_zone_id: StringName
) -> Array[StringName]:
	var empty_path: Array[StringName] = []
	if state == null:
		return empty_path
	var cache_key: String = _make_route_cache_key(
		state,
		start_zone_id,
		target_zone_id
	)
	if _route_cache.has(cache_key):
		var cached_path: Array[StringName] = []
		cached_path.assign(_route_cache[cache_key] as Array)
		return cached_path

	var calculated_path: Array[StringName] = _calculate_stable_path(
		state,
		start_zone_id,
		target_zone_id
	)
	_route_cache[cache_key] = calculated_path.duplicate()
	return calculated_path


func _calculate_stable_path(
	state: ColonyState,
	start_zone_id: StringName,
	target_zone_id: StringName
) -> Array[StringName]:
	var empty_path: Array[StringName] = []
	var start_zone: HabitatZoneState = state.get_zone(start_zone_id)
	var target_zone: HabitatZoneState = state.get_zone(target_zone_id)
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
	var previous_zone_id: Dictionary[StringName, StringName] = {}
	var queue_index: int = 0
	while queue_index < queue.size():
		var current_zone_id: StringName = queue[queue_index]
		queue_index += 1
		var current_zone: HabitatZoneState = state.get_zone(current_zone_id)
		if current_zone == null or not current_zone.available:
			continue

		var neighbor_ids: Array[StringName] = []
		neighbor_ids.assign(current_zone.connected_zone_ids)
		neighbor_ids.sort_custom(
			func(first: StringName, second: StringName) -> bool:
				return String(first) < String(second)
		)
		for neighbor_id: StringName in neighbor_ids:
			if visited.has(neighbor_id):
				continue
			var neighbor: HabitatZoneState = state.get_zone(neighbor_id)
			if neighbor == null or not neighbor.available:
				continue
			visited[neighbor_id] = true
			previous_zone_id[neighbor_id] = current_zone_id
			if neighbor_id == target_zone_id:
				return _reconstruct_path(
					start_zone_id,
					target_zone_id,
					previous_zone_id
				)
			queue.append(neighbor_id)
	return empty_path


func _reconstruct_path(
	start_zone_id: StringName,
	target_zone_id: StringName,
	previous_zone_id: Dictionary[StringName, StringName]
) -> Array[StringName]:
	var reversed_path: Array[StringName] = [target_zone_id]
	var current_zone_id: StringName = target_zone_id
	while current_zone_id != start_zone_id:
		if not previous_zone_id.has(current_zone_id):
			return []
		current_zone_id = previous_zone_id[current_zone_id]
		reversed_path.append(current_zone_id)
	reversed_path.reverse()
	return reversed_path


func _is_route_valid(
	state: ColonyState,
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
	for zone_index: int in route_zone_ids.size():
		var zone: HabitatZoneState = state.get_zone(
			route_zone_ids[zone_index]
		)
		if zone == null or not zone.available:
			return false
		if zone_index == 0:
			continue
		var previous_zone: HabitatZoneState = state.get_zone(
			route_zone_ids[zone_index - 1]
		)
		if (
			previous_zone == null
			or not previous_zone.connected_zone_ids.has(zone.zone_id)
		):
			return false
	return true


func _is_pre_collection_source_valid(
	state: ColonyState,
	source: FoodSourceState
) -> bool:
	if source == null or not source.has_available_portion():
		return false
	var zone: HabitatZoneState = state.get_zone(source.zone_id)
	return zone != null and zone.available


func _is_worker_available(
	worker: AntModel,
	task: ForagingTaskModel
) -> bool:
	return (
		worker.life_stage == AntModel.LifeStage.WORKER
		and worker.worker_task != null
		and worker.worker_task.state == WorkerTaskModel.State.IDLE
		and task.state == ForagingTaskModel.State.IDLE
		and (
			worker.feeding_task == null
			or worker.feeding_task.state
				== BroodFeedingTaskModel.State.IDLE
		)
	)


func _has_valid_nutrition_conservation(
	state: ColonyState,
	sources_by_id: Dictionary[int, FoodSourceState]
) -> bool:
	var remaining_sugar: int = 0
	var remaining_protein: int = 0
	for source: FoodSourceState in sources_by_id.values():
		if source.food_type == FoodSourceState.FoodType.PROTEIN:
			remaining_protein += source.remaining_portions
		elif source.food_type == FoodSourceState.FoodType.SUGAR_WATER:
			remaining_sugar += source.remaining_portions
		else:
			return false
	var carried_sugar: int = 0
	var carried_protein: int = 0
	for worker: AntModel in _get_workers_in_stable_order(state):
		var task: ForagingTaskModel = worker.foraging_task
		if task == null or not task.is_carrying():
			continue
		var source: FoodSourceState = sources_by_id.get(
			task.target_food_source_id
		)
		if source == null:
			return false
		if source.food_type == FoodSourceState.FoodType.PROTEIN:
			carried_protein += task.carried_portions
		else:
			carried_sugar += task.carried_portions
	var nutrition: ColonyNutritionState = state.nutrition_state
	return (
		state.shared_sugar_portions >= 0
		and state.total_sugar_portions_placed >= 0
		and state.shared_sugar_portions
			<= state.total_sugar_portions_placed
		and state.total_sugar_portions_placed
			<= nutrition.total_sugar_portions_supplied
		and remaining_sugar
			+ carried_sugar
			+ nutrition.sugar_reserve_portions
			+ nutrition.total_sugar_portions_consumed
			== nutrition.total_sugar_portions_supplied
		and remaining_protein
			+ carried_protein
			+ nutrition.protein_reserve_portions
			+ nutrition.total_protein_portions_consumed
			== nutrition.total_protein_portions_supplied
	)


func _is_idle_task_clean(task: ForagingTaskModel) -> bool:
	return (
		task.target_food_source_id == -1
		and task.origin_zone_id.is_empty()
		and task.target_zone_id.is_empty()
		and task.nest_zone_id.is_empty()
		and task.route_zone_ids.is_empty()
		and task.route_cache_key.is_empty()
		and task.carried_portions == 0
		and task.elapsed_ticks == 0
		and task.duration_ticks == 0
	)


func _get_claimed_source_ids(
	state: ColonyState
) -> Dictionary[int, int]:
	var claimed_source_ids: Dictionary[int, int] = {}
	for worker: AntModel in _get_workers_in_stable_order(state):
		var task: ForagingTaskModel = _get_foraging_task(worker)
		if task != null and task.state != ForagingTaskModel.State.IDLE:
			claimed_source_ids[task.target_food_source_id] = worker.entity_id
	return claimed_source_ids


func _get_workers_in_stable_order(state: ColonyState) -> Array[AntModel]:
	var workers: Array[AntModel] = []
	for ant: AntModel in state.ants:
		if ant.life_stage == AntModel.LifeStage.WORKER:
			workers.append(ant)
	workers.sort_custom(
		func(first: AntModel, second: AntModel) -> bool:
			return first.entity_id < second.entity_id
	)
	return workers


func _get_food_sources(state: ColonyState) -> Array[FoodSourceState]:
	var sources: Array[FoodSourceState] = []
	for source: FoodSourceState in state.food_sources:
		if source != null:
			sources.append(source)
	return sources


func _get_food_sources_in_stable_order(
	state: ColonyState
) -> Array[FoodSourceState]:
	var sources: Array[FoodSourceState] = _get_food_sources(state)
	sources.sort_custom(
		func(first: FoodSourceState, second: FoodSourceState) -> bool:
			return first.entity_id < second.entity_id
	)
	return sources


func _get_food_source(
	state: ColonyState,
	entity_id: int
) -> FoodSourceState:
	return state.get_food_source(entity_id)


func _get_foraging_task(worker: AntModel) -> ForagingTaskModel:
	return worker.foraging_task


func _get_or_create_foraging_task(
	worker: AntModel
) -> ForagingTaskModel:
	var task: ForagingTaskModel = _get_foraging_task(worker)
	if task != null:
		return task
	task = ForagingTaskModel.new()
	worker.foraging_task = task
	return task


func _is_observation_card_unlocked(state: ColonyState) -> bool:
	return state.unlocked_observation_card_ids.has(_observation_card_id)


func _unlock_observation_card(state: ColonyState) -> bool:
	if state.unlocked_observation_card_ids.has(_observation_card_id):
		return false
	state.unlocked_observation_card_ids[_observation_card_id] = true
	return true


func _record_event(
	state: ColonyState,
	event_type: ObservationEvent.Type,
	actor_entity_id: int,
	subject_entity_id: int,
	source_zone_id: StringName,
	target_zone_id: StringName
) -> void:
	state.record_observation_event(
		event_type,
		actor_entity_id,
		subject_entity_id,
		source_zone_id,
		target_zone_id
	)


func _can_share_at_nest(
	state: ColonyState,
	worker: AntModel
) -> bool:
	var nest_zone: HabitatZoneState = state.get_zone(_nest_zone_id)
	return (
		nest_zone != null
		and nest_zone.available
		and worker.zone_id == _nest_zone_id
	)


func _make_route_cache_key(
	state: ColonyState,
	start_zone_id: StringName,
	target_zone_id: StringName
) -> String:
	var zones: Array[HabitatZoneState] = []
	zones.assign(state.zones)
	zones.sort_custom(
		func(first: HabitatZoneState, second: HabitatZoneState) -> bool:
			return String(first.zone_id) < String(second.zone_id)
	)
	var topology_parts: PackedStringArray = [
		String(start_zone_id),
		String(target_zone_id),
	]
	for zone: HabitatZoneState in zones:
		var connected_zone_ids: PackedStringArray = []
		for connected_zone_id: StringName in zone.connected_zone_ids:
			connected_zone_ids.append(String(connected_zone_id))
		connected_zone_ids.sort()
		topology_parts.append(
			"%s:%s:%s"
			% [
				zone.zone_id,
				str(zone.available),
				",".join(connected_zone_ids),
			]
		)
	return "|".join(topology_parts)
