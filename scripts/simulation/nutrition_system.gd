class_name NutritionSystem
extends RefCounted

var _config: NutritionConfig
var _scenario_config: HabitatScenarioConfig
var _nest_zone_id: StringName = &""


func _init(
	config: NutritionConfig,
	scenario_config: HabitatScenarioConfig
) -> void:
	_config = config
	_scenario_config = scenario_config
	if scenario_config != null:
		_nest_zone_id = scenario_config.nest_zone_id


func is_ready() -> bool:
	return (
		_config != null
		and _scenario_config != null
		and _scenario_config.supports_nutrition_growth()
		and not _nest_zone_id.is_empty()
	)


func should_advance_worker_tasks(state: ColonyState) -> bool:
	if state == null or not is_ready() or state.nutrition_state == null:
		return true
	if not _has_any_active_worker_task(state):
		return true

	var nutrition: ColonyNutritionState = state.nutrition_state
	if nutrition.sugar_activity_ticks_remaining > 0:
		nutrition.sugar_activity_ticks_remaining -= 1
		return true
	if nutrition.sugar_reserve_portions > 0:
		nutrition.sugar_reserve_portions -= 1
		nutrition.total_sugar_portions_consumed += 1
		nutrition.sugar_activity_ticks_remaining = (
			_config.sugar_activity_ticks_per_portion - 1
		)
		return true
	return (
		state.simulation_tick
		% _config.sugar_shortage_step_interval_ticks
		== 0
	)


func validate_tasks(state: ColonyState) -> void:
	if state == null or not is_ready() or state.nutrition_state == null:
		return

	var claimed_brood_ids: Dictionary[int, int] = {}
	for worker: AntModel in _get_workers_in_stable_order(state):
		var task: BroodFeedingTaskModel = worker.feeding_task
		if task == null or task.state == BroodFeedingTaskModel.State.IDLE:
			continue
		var brood: AntModel = state.get_ant(task.target_brood_id)
		if (
			claimed_brood_ids.has(task.target_brood_id)
			or not _is_valid_feeding_target(state, brood)
			or (
				worker.worker_task != null
				and worker.worker_task.state != WorkerTaskModel.State.IDLE
			)
			or (
				worker.foraging_task != null
				and worker.foraging_task.state
					!= ForagingTaskModel.State.IDLE
			)
			or _has_colony_work_task(worker)
		):
			task.reset_to_idle(
				state.simulation_tick
				+ _config.feeding_decision_interval_ticks
			)
			continue
		claimed_brood_ids[task.target_brood_id] = worker.entity_id
		if task.state == BroodFeedingTaskModel.State.MOVING_TO_BROOD:
			if not _is_route_valid(
				state,
				task.route_zone_ids,
				worker.zone_id,
				brood.zone_id
			):
				task.reset_to_idle(
					state.simulation_tick
					+ _config.feeding_decision_interval_ticks
				)
		elif (
			task.state == BroodFeedingTaskModel.State.FEEDING
			and (
				worker.zone_id != brood.zone_id
				or worker.zone_id != task.target_zone_id
			)
		):
			task.reset_to_idle(
				state.simulation_tick
				+ _config.feeding_decision_interval_ticks
			)


func advance_tasks(state: ColonyState) -> void:
	if state == null or not is_ready() or state.nutrition_state == null:
		return

	for worker: AntModel in _get_workers_in_stable_order(state):
		var task: BroodFeedingTaskModel = worker.feeding_task
		if task == null or task.state == BroodFeedingTaskModel.State.IDLE:
			continue
		task.elapsed_ticks += 1
		if task.elapsed_ticks < task.duration_ticks:
			continue

		var brood: AntModel = state.get_ant(task.target_brood_id)
		if not _is_valid_feeding_target(state, brood):
			task.reset_to_idle(
				state.simulation_tick
				+ _config.feeding_decision_interval_ticks
			)
			continue
		match task.state:
			BroodFeedingTaskModel.State.MOVING_TO_BROOD:
				worker.zone_id = brood.zone_id
				task.begin(
					BroodFeedingTaskModel.State.FEEDING,
					brood.entity_id,
					brood.zone_id,
					brood.zone_id,
					[brood.zone_id],
					_config.feeding_duration_ticks
				)
			BroodFeedingTaskModel.State.FEEDING:
				_complete_feeding(state, worker, brood, task)


func assign_idle_workers(state: ColonyState) -> void:
	if state == null or not is_ready() or state.nutrition_state == null:
		return
	var reserved_protein_portions: int = get_active_feeding_count(state)
	var available_protein: int = (
		state.nutrition_state.protein_reserve_portions
		- reserved_protein_portions
	)
	if available_protein <= 0:
		return

	var claimed_brood_ids: Dictionary[int, bool] = {}
	for worker: AntModel in _get_workers_in_stable_order(state):
		if (
			worker.feeding_task != null
			and worker.feeding_task.state
				!= BroodFeedingTaskModel.State.IDLE
		):
			claimed_brood_ids[
				worker.feeding_task.target_brood_id
			] = true

	for worker: AntModel in _get_workers_in_stable_order(state):
		if available_protein <= 0 or not _is_worker_available(state, worker):
			continue
		var task: BroodFeedingTaskModel = worker.feeding_task
		if state.simulation_tick < task.next_decision_tick:
			continue
		var assignment: Dictionary = _find_brood_assignment(
			state,
			worker,
			claimed_brood_ids
		)
		if assignment.is_empty():
			task.next_decision_tick = (
				state.simulation_tick
				+ _config.feeding_decision_interval_ticks
			)
			continue
		var brood: AntModel = assignment["brood"]
		var route: Array[StringName] = []
		route.assign(assignment["route"] as Array)
		task.begin(
			BroodFeedingTaskModel.State.MOVING_TO_BROOD,
			brood.entity_id,
			worker.zone_id,
			brood.zone_id,
			route,
			_config.feeding_travel_duration_ticks
		)
		state.record_observation_event(
			ObservationEvent.Type.BROOD_FEEDING_STARTED,
			worker.entity_id,
			brood.entity_id,
			worker.zone_id,
			brood.zone_id
		)
		claimed_brood_ids[brood.entity_id] = true
		available_protein -= 1


func get_active_feeding_count(state: ColonyState) -> int:
	if state == null:
		return 0
	var count: int = 0
	for worker: AntModel in state.ants:
		if (
			worker.life_stage == AntModel.LifeStage.WORKER
			and worker.feeding_task != null
			and worker.feeding_task.state
				!= BroodFeedingTaskModel.State.IDLE
		):
			count += 1
	return count


func has_valid_state(state: ColonyState) -> bool:
	if (
		state == null
		or not is_ready()
		or state.nutrition_state == null
	):
		return false
	var nutrition: ColonyNutritionState = state.nutrition_state
	for value: int in [
		nutrition.sugar_reserve_portions,
		nutrition.protein_reserve_portions,
		nutrition.sugar_activity_ticks_remaining,
		nutrition.total_sugar_portions_supplied,
		nutrition.total_protein_portions_supplied,
		nutrition.total_sugar_portions_consumed,
		nutrition.total_protein_portions_consumed,
		nutrition.total_protein_portions_placed,
		nutrition.delivered_protein_portions,
		nutrition.completed_feeding_count,
	]:
		if value < 0:
			return false
	if (
		nutrition.sugar_activity_ticks_remaining
			>= _config.sugar_activity_ticks_per_portion
		or nutrition.total_sugar_portions_consumed
			> nutrition.total_sugar_portions_supplied
		or nutrition.total_protein_portions_consumed
			> nutrition.total_protein_portions_supplied
		or nutrition.delivered_protein_portions
			> nutrition.total_protein_portions_placed
		or nutrition.total_protein_portions_placed
			> nutrition.total_protein_portions_supplied
		or nutrition.completed_feeding_count
			!= nutrition.total_protein_portions_consumed
	):
		return false

	var claimed_brood_ids: Dictionary[int, int] = {}
	var active_feeding_count: int = 0
	for ant: AntModel in state.ants:
		if ant.life_stage != AntModel.LifeStage.LARVA:
			if ant.protein_supported_growth_ticks != 0:
				return false
		elif (
			ant.protein_supported_growth_ticks < 0
			or ant.protein_supported_growth_ticks
				> _config.protein_growth_ticks_per_portion
		):
			return false
		if ant.life_stage != AntModel.LifeStage.WORKER:
			if ant.feeding_task != null:
				return false
			continue
		if ant.feeding_task == null:
			return false
		var task: BroodFeedingTaskModel = ant.feeding_task
		if task.state == BroodFeedingTaskModel.State.IDLE:
			if not _is_idle_task_clean(task):
				return false
			continue
		active_feeding_count += 1
		if (
			claimed_brood_ids.has(task.target_brood_id)
			or task.duration_ticks <= 0
			or task.elapsed_ticks < 0
			or task.elapsed_ticks >= task.duration_ticks
			or not _is_valid_feeding_target(
				state,
				state.get_ant(task.target_brood_id)
			)
			or state.get_ant(task.target_brood_id)
				.protein_supported_growth_ticks != 0
			or (
				task.state
					== BroodFeedingTaskModel.State.MOVING_TO_BROOD
				and not _is_route_valid(
					state,
					task.route_zone_ids,
					ant.zone_id,
					task.target_zone_id
				)
			)
			or (
				task.state == BroodFeedingTaskModel.State.FEEDING
				and (
					ant.zone_id != task.target_zone_id
					or task.route_zone_ids != [task.target_zone_id]
				)
			)
			or (
				ant.worker_task != null
				and ant.worker_task.state != WorkerTaskModel.State.IDLE
			)
			or (
				ant.foraging_task != null
				and ant.foraging_task.state != ForagingTaskModel.State.IDLE
			)
			or _has_colony_work_task(ant)
		):
			return false
		claimed_brood_ids[task.target_brood_id] = ant.entity_id
	if active_feeding_count > nutrition.protein_reserve_portions:
		return false
	return true


func _complete_feeding(
	state: ColonyState,
	worker: AntModel,
	brood: AntModel,
	task: BroodFeedingTaskModel
) -> void:
	var nutrition: ColonyNutritionState = state.nutrition_state
	if nutrition.protein_reserve_portions <= 0:
		task.reset_to_idle(
			state.simulation_tick + _config.feeding_decision_interval_ticks
		)
		return
	nutrition.protein_reserve_portions -= 1
	nutrition.total_protein_portions_consumed += 1
	nutrition.completed_feeding_count += 1
	brood.protein_supported_growth_ticks = (
		_config.protein_growth_ticks_per_portion
	)
	state.record_observation_event(
		ObservationEvent.Type.BROOD_FED,
		worker.entity_id,
		brood.entity_id,
		worker.zone_id,
		brood.zone_id
	)
	task.reset_to_idle(
		state.simulation_tick + _config.feeding_decision_interval_ticks
	)


func _find_brood_assignment(
	state: ColonyState,
	worker: AntModel,
	claimed_brood_ids: Dictionary[int, bool]
) -> Dictionary:
	var brood_in_stable_order: Array[AntModel] = []
	for ant: AntModel in state.ants:
		if (
			ant.life_stage == AntModel.LifeStage.LARVA
			and ant.protein_supported_growth_ticks == 0
		):
			brood_in_stable_order.append(ant)
	brood_in_stable_order.sort_custom(
		func(first: AntModel, second: AntModel) -> bool:
			return first.entity_id < second.entity_id
	)
	for brood: AntModel in brood_in_stable_order:
		if claimed_brood_ids.has(brood.entity_id):
			continue
		var route: Array[StringName] = _find_stable_path(
			state,
			worker.zone_id,
			brood.zone_id
		)
		if not route.is_empty():
			return {"brood": brood, "route": route}
	return {}


func _is_worker_available(state: ColonyState, worker: AntModel) -> bool:
	return (
		worker.life_stage == AntModel.LifeStage.WORKER
		and state.get_zone(worker.zone_id) != null
		and worker.worker_task != null
		and worker.worker_task.state == WorkerTaskModel.State.IDLE
		and worker.foraging_task != null
		and worker.foraging_task.state == ForagingTaskModel.State.IDLE
		and worker.feeding_task != null
		and worker.feeding_task.state == BroodFeedingTaskModel.State.IDLE
		and not _has_colony_work_task(worker)
	)


func _is_valid_feeding_target(
	state: ColonyState,
	brood: AntModel
) -> bool:
	return (
		brood != null
		and brood.life_stage == AntModel.LifeStage.LARVA
		and not brood.zone_id.is_empty()
		and state.get_zone(brood.zone_id) != null
	)


func _is_idle_task_clean(task: BroodFeedingTaskModel) -> bool:
	return (
		task.target_brood_id == -1
		and task.origin_zone_id.is_empty()
		and task.target_zone_id.is_empty()
		and task.route_zone_ids.is_empty()
		and task.elapsed_ticks == 0
		and task.duration_ticks == 0
		and task.next_decision_tick >= 0
	)


func _has_any_active_worker_task(state: ColonyState) -> bool:
	for ant: AntModel in state.ants:
		if ant.life_stage != AntModel.LifeStage.WORKER:
			continue
		if (
			ant.worker_task != null
			and ant.worker_task.state != WorkerTaskModel.State.IDLE
		):
			return true
		if (
			ant.foraging_task != null
			and ant.foraging_task.state != ForagingTaskModel.State.IDLE
		):
			return true
		if (
			ant.feeding_task != null
			and ant.feeding_task.state
				!= BroodFeedingTaskModel.State.IDLE
		):
			return true
		if _has_colony_work_task(ant):
			return true
	return false


func _has_colony_work_task(worker: AntModel) -> bool:
	return (
		worker.waste_cleanup_task != null
		and worker.waste_cleanup_task.state
			!= WasteCleanupTaskModel.State.IDLE
		or worker.scout_task != null
		and worker.scout_task.state != ScoutTaskModel.State.IDLE
		or worker.migration_task != null
		and worker.migration_task.state
			!= MigrationTaskModel.State.IDLE
	)


func _get_workers_in_stable_order(state: ColonyState) -> Array[AntModel]:
	return state.get_workers_in_stable_order()


func _find_stable_path(
	state: ColonyState,
	start_zone_id: StringName,
	target_zone_id: StringName
) -> Array[StringName]:
	if state == null:
		return []
	return state.find_stable_zone_path(start_zone_id, target_zone_id)


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
	return (
		state != null
		and state.is_zone_route_valid(
			route_zone_ids,
			start_zone_id,
			target_zone_id
		)
	)
