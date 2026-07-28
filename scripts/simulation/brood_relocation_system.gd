class_name BroodRelocationSystem
extends RefCounted

const IMPROVEMENT_EPSILON: float = 0.000001

var _config: BroodCareConfig
var _environment_system: EnvironmentSystem


func _init(
	config: BroodCareConfig,
	environment_system: EnvironmentSystem = null
) -> void:
	_config = config
	_environment_system = environment_system


func is_ready() -> bool:
	return _config != null


func validate_tasks(state: ColonyState) -> void:
	if state == null or not is_ready():
		return

	var claimed_brood_ids: Dictionary = {}
	for worker: AntModel in state.ants:
		if worker.worker_task == null:
			continue
		var task: WorkerTaskModel = worker.worker_task
		if task.state == WorkerTaskModel.State.IDLE:
			continue

		var brood: AntModel = state.get_ant(task.target_brood_id)
		if (
			brood == null
			or brood.life_stage == AntModel.LifeStage.WORKER
			or claimed_brood_ids.has(task.target_brood_id)
		):
			_cancel_or_rehome_task(state, worker)
			continue
		claimed_brood_ids[task.target_brood_id] = true

		if (
			task.state == WorkerTaskModel.State.MOVING_TO_BROOD
			or task.state == WorkerTaskModel.State.PICKING_UP
		):
			if not _is_pre_pickup_task_valid(state, brood, task):
				task.reset_to_idle(
					state.simulation_tick
					+ _config.decision_interval_ticks
				)
			continue

		if (
			task.state == WorkerTaskModel.State.CARRYING_TO_ZONE
			or task.state == WorkerTaskModel.State.DROPPING
		):
			_retarget_carried_brood_if_needed(state, worker, brood)


func advance_tasks(state: ColonyState) -> void:
	if state == null or not is_ready():
		return

	for worker: AntModel in state.ants:
		if worker.worker_task == null:
			continue
		var task: WorkerTaskModel = worker.worker_task
		if task.state == WorkerTaskModel.State.IDLE:
			continue

		task.elapsed_ticks += 1
		if task.elapsed_ticks < task.duration_ticks:
			continue

		var brood: AntModel = state.get_ant(task.target_brood_id)
		if brood == null:
			_cancel_or_rehome_task(state, worker)
			continue

		match task.state:
			WorkerTaskModel.State.MOVING_TO_BROOD:
				var pickup_zone_id: StringName = brood.zone_id
				var relocation_target_zone_id: StringName = (
					task.target_zone_id
				)
				worker.zone_id = brood.zone_id
				task.begin(
					WorkerTaskModel.State.PICKING_UP,
					pickup_zone_id,
					brood.entity_id,
					relocation_target_zone_id,
					_config.pickup_duration_ticks
				)
				state.record_observation_event(
					ObservationEvent.Type.BROOD_PICKUP_STARTED,
					worker.entity_id,
					brood.entity_id,
					pickup_zone_id,
					relocation_target_zone_id
				)
			WorkerTaskModel.State.PICKING_UP:
				var pickup_zone_id: StringName = brood.zone_id
				var relocation_target_zone_id: StringName = (
					task.target_zone_id
				)
				brood.zone_id = &""
				task.carried_brood_id = brood.entity_id
				task.begin(
					WorkerTaskModel.State.CARRYING_TO_ZONE,
					pickup_zone_id,
					brood.entity_id,
					relocation_target_zone_id,
					_config.travel_duration_ticks
				)
				state.record_observation_event(
					ObservationEvent.Type.BROOD_CARRY_STARTED,
					worker.entity_id,
					brood.entity_id,
					pickup_zone_id,
					relocation_target_zone_id
				)
			WorkerTaskModel.State.CARRYING_TO_ZONE:
				var relocation_source_zone_id: StringName = (
					task.origin_zone_id
				)
				var relocation_target_zone_id: StringName = (
					task.target_zone_id
				)
				worker.zone_id = relocation_target_zone_id
				task.begin(
					WorkerTaskModel.State.DROPPING,
					relocation_source_zone_id,
					brood.entity_id,
					relocation_target_zone_id,
					_config.drop_duration_ticks
				)
			WorkerTaskModel.State.DROPPING:
				var relocation_source_zone_id: StringName = (
					task.origin_zone_id
				)
				var relocation_target_zone_id: StringName = (
					task.target_zone_id
				)
				brood.zone_id = relocation_target_zone_id
				brood.zone_entered_tick = state.simulation_tick
				worker.zone_id = relocation_target_zone_id
				state.water_action_unlocked = true
				state.record_observation_event(
					ObservationEvent.Type.BROOD_DROPPED,
					worker.entity_id,
					brood.entity_id,
					relocation_source_zone_id,
					relocation_target_zone_id
				)
				task.reset_to_idle(
					state.simulation_tick
					+ _config.decision_interval_ticks
				)


func assign_idle_workers(state: ColonyState) -> void:
	if state == null or not is_ready():
		return

	var reserved_brood_ids: Dictionary = {}
	for worker: AntModel in state.ants:
		if (
			worker.worker_task != null
			and worker.worker_task.state != WorkerTaskModel.State.IDLE
		):
			reserved_brood_ids[worker.worker_task.target_brood_id] = true
		if (
			worker.migration_task != null
			and worker.migration_task.state
				!= MigrationTaskModel.State.IDLE
			and worker.migration_task.target_entity_id >= 0
		):
			reserved_brood_ids[
				worker.migration_task.target_entity_id
			] = true

	for worker: AntModel in state.ants:
		if (
			worker.worker_task == null
			or worker.worker_task.state != WorkerTaskModel.State.IDLE
			or (
				worker.foraging_task != null
				and worker.foraging_task.state
					!= ForagingTaskModel.State.IDLE
			)
			or (
				worker.feeding_task != null
				and worker.feeding_task.state
					!= BroodFeedingTaskModel.State.IDLE
			)
			or _has_colony_work_task(worker)
			or state.simulation_tick < worker.worker_task.next_decision_tick
		):
			continue
		worker.worker_task.next_decision_tick = (
			state.simulation_tick
			+ _config.decision_interval_ticks
		)
		var assignment: Dictionary = _find_assignment(
			state,
			reserved_brood_ids
		)
		if assignment.is_empty():
			continue

		var brood: AntModel = assignment["brood"] as AntModel
		var target_zone: HabitatZoneState = (
			assignment["target_zone"] as HabitatZoneState
		)
		worker.worker_task.begin(
			WorkerTaskModel.State.MOVING_TO_BROOD,
			worker.zone_id,
			brood.entity_id,
			target_zone.zone_id,
			_config.travel_duration_ticks
		)
		state.record_observation_event(
			ObservationEvent.Type.RELOCATION_STARTED,
			worker.entity_id,
			brood.entity_id,
			brood.zone_id,
			target_zone.zone_id
		)
		reserved_brood_ids[brood.entity_id] = true


func has_valid_ownership(state: ColonyState) -> bool:
	if state == null or not is_ready():
		return false

	var reservation_counts: Dictionary = {}
	var carrier_counts: Dictionary = {}
	for ant: AntModel in state.ants:
		if ant.life_stage != AntModel.LifeStage.WORKER:
			continue
		if ant.worker_task == null or state.get_zone(ant.zone_id) == null:
			return false

		var task: WorkerTaskModel = ant.worker_task
		if (
			task.state != WorkerTaskModel.State.IDLE
			and ant.feeding_task != null
			and ant.feeding_task.state
				!= BroodFeedingTaskModel.State.IDLE
		):
			return false
		if (
			task.state != WorkerTaskModel.State.IDLE
			and _has_colony_work_task(ant)
		):
			return false
		if (
			ant.migration_task != null
			and ant.migration_task.state
				!= MigrationTaskModel.State.IDLE
			and ant.migration_task.target_entity_id >= 0
		):
			reservation_counts[
				ant.migration_task.target_entity_id
			] = (
				int(reservation_counts.get(
					ant.migration_task.target_entity_id,
					0
				))
				+ 1
			)
			if ant.migration_task.carried_entity_id >= 0:
				carrier_counts[
					ant.migration_task.carried_entity_id
				] = (
					int(carrier_counts.get(
						ant.migration_task.carried_entity_id,
						0
					))
					+ 1
				)
		if task.state == WorkerTaskModel.State.IDLE:
			if (
				task.target_brood_id != -1
				or task.carried_brood_id != -1
				or not task.target_zone_id.is_empty()
				or not task.origin_zone_id.is_empty()
			):
				return false
			continue

		if (
			task.target_brood_id < 0
			or task.target_zone_id.is_empty()
			or state.get_zone(task.target_zone_id) == null
		):
			return false
		var target_brood: AntModel = state.get_ant(task.target_brood_id)
		if (
			target_brood == null
			or target_brood.life_stage == AntModel.LifeStage.WORKER
		):
			return false

		reservation_counts[task.target_brood_id] = (
			int(reservation_counts.get(task.target_brood_id, 0)) + 1
		)
		if reservation_counts[task.target_brood_id] > 1:
			return false

		if (
			task.state == WorkerTaskModel.State.MOVING_TO_BROOD
			or task.state == WorkerTaskModel.State.PICKING_UP
		):
			if task.carried_brood_id != -1 or target_brood.zone_id.is_empty():
				return false
		elif (
			task.state == WorkerTaskModel.State.CARRYING_TO_ZONE
			or task.state == WorkerTaskModel.State.DROPPING
		):
			if (
				task.carried_brood_id != task.target_brood_id
				or not target_brood.zone_id.is_empty()
			):
				return false
			carrier_counts[task.carried_brood_id] = (
				int(carrier_counts.get(task.carried_brood_id, 0)) + 1
			)
			if carrier_counts[task.carried_brood_id] > 1:
				return false
		else:
			return false

	for ant: AntModel in state.ants:
		if ant.life_stage == AntModel.LifeStage.WORKER:
			continue
		var belongs_to_zone: bool = (
			not ant.zone_id.is_empty()
			and state.get_zone(ant.zone_id) != null
		)
		var carrier_count: int = int(carrier_counts.get(ant.entity_id, 0))
		if belongs_to_zone == (carrier_count == 1):
			return false
		if int(reservation_counts.get(ant.entity_id, 0)) > 1:
			return false
	return true


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


func is_humidity_comfortable(humidity: float) -> bool:
	if not is_ready():
		return false
	return (
		humidity + IMPROVEMENT_EPSILON
		>= _config.brood_humidity_min
		and humidity - IMPROVEMENT_EPSILON
		<= _config.brood_humidity_max
	)


func _find_assignment(
	state: ColonyState,
	reserved_brood_ids: Dictionary
) -> Dictionary:
	for brood: AntModel in state.ants:
		if (
			brood.life_stage == AntModel.LifeStage.WORKER
			or brood.zone_id.is_empty()
			or reserved_brood_ids.has(brood.entity_id)
			or (
				state.simulation_tick - brood.zone_entered_tick
				< _config.minimum_zone_dwell_ticks
			)
		):
			continue
		var target_zone: HabitatZoneState = _find_best_relocation_zone(
			state,
			brood.zone_id
		)
		if target_zone != null:
			return {"brood": brood, "target_zone": target_zone}
	return {}


func _find_best_relocation_zone(
	state: ColonyState,
	source_zone_id: StringName
) -> HabitatZoneState:
	var source_zone: HabitatZoneState = state.get_zone(source_zone_id)
	if source_zone == null or not source_zone.available:
		return null

	var source_penalty: float = _get_zone_penalty(source_zone)
	var best_zone: HabitatZoneState
	var best_penalty: float = source_penalty
	for candidate: HabitatZoneState in state.zones:
		if (
			not candidate.available
			or not candidate.discovered
			or candidate.zone_id == source_zone_id
			or not state.are_zones_directly_connected(
				source_zone_id,
				candidate.zone_id
			)
		):
			continue
		var candidate_penalty: float = _get_zone_penalty(candidate)
		var improvement: float = source_penalty - candidate_penalty
		if (
			improvement + IMPROVEMENT_EPSILON
			< _config.relocation_min_improvement
		):
			continue
		if (
			best_zone == null
			or candidate_penalty < best_penalty - IMPROVEMENT_EPSILON
			or (
				is_equal_approx(candidate_penalty, best_penalty)
				and String(candidate.zone_id) < String(best_zone.zone_id)
			)
		):
			best_zone = candidate
			best_penalty = candidate_penalty
	return best_zone


func _find_best_available_zone(
	state: ColonyState,
	from_zone_id: StringName
) -> HabitatZoneState:
	var from_zone: HabitatZoneState = state.get_zone(from_zone_id)
	if from_zone == null:
		return null
	var best_zone: HabitatZoneState
	var best_penalty: float = INF
	for candidate: HabitatZoneState in state.zones:
		if (
			not candidate.available
			or not state.are_zones_directly_connected(
				from_zone_id,
				candidate.zone_id
			)
		):
			continue
		var penalty: float = _get_zone_penalty(candidate)
		if (
			best_zone == null
			or penalty < best_penalty - IMPROVEMENT_EPSILON
			or (
				is_equal_approx(penalty, best_penalty)
				and String(candidate.zone_id) < String(best_zone.zone_id)
			)
		):
			best_zone = candidate
			best_penalty = penalty
	return best_zone


func _is_pre_pickup_task_valid(
	state: ColonyState,
	brood: AntModel,
	task: WorkerTaskModel
) -> bool:
	if brood.zone_id.is_empty():
		return false
	var source_zone: HabitatZoneState = state.get_zone(brood.zone_id)
	var target_zone: HabitatZoneState = state.get_zone(task.target_zone_id)
	if (
		source_zone == null
		or target_zone == null
		or not target_zone.available
		or not state.are_zones_directly_connected(
			source_zone.zone_id,
			target_zone.zone_id
		)
	):
		return false
	return (
		_get_zone_penalty(source_zone)
		- _get_zone_penalty(target_zone)
		+ IMPROVEMENT_EPSILON
		>= _config.relocation_min_improvement
	)


func _retarget_carried_brood_if_needed(
	state: ColonyState,
	worker: AntModel,
	brood: AntModel
) -> void:
	var task: WorkerTaskModel = worker.worker_task
	if task.carried_brood_id != brood.entity_id:
		_cancel_or_rehome_task(state, worker)
		return

	var current_target: HabitatZoneState = state.get_zone(task.target_zone_id)
	var worker_zone: HabitatZoneState = state.get_zone(worker.zone_id)
	if (
		current_target != null
		and current_target.available
		and worker_zone != null
		and state.are_zones_directly_connected(
			worker_zone.zone_id,
			current_target.zone_id
		)
	):
		return

	var best_zone: HabitatZoneState = _find_best_available_zone(
		state,
		worker.zone_id
	)
	if best_zone == null:
		return

	if best_zone.zone_id == worker.zone_id:
		task.begin(
			WorkerTaskModel.State.DROPPING,
			worker.zone_id,
			brood.entity_id,
			best_zone.zone_id,
			_config.drop_duration_ticks
		)
	else:
		task.begin(
			WorkerTaskModel.State.CARRYING_TO_ZONE,
			worker.zone_id,
			brood.entity_id,
			best_zone.zone_id,
			_config.travel_duration_ticks
		)


func _cancel_or_rehome_task(
	state: ColonyState,
	worker: AntModel
) -> void:
	var task: WorkerTaskModel = worker.worker_task
	if task.carried_brood_id < 0:
		task.reset_to_idle(
			state.simulation_tick
			+ _config.decision_interval_ticks
		)
		return

	var brood: AntModel = state.get_ant(task.carried_brood_id)
	var fallback_zone: HabitatZoneState = _find_best_available_zone(
		state,
		worker.zone_id
	)
	if brood == null or fallback_zone == null:
		return
	if fallback_zone.zone_id == worker.zone_id:
		task.begin(
			WorkerTaskModel.State.DROPPING,
			worker.zone_id,
			brood.entity_id,
			fallback_zone.zone_id,
			_config.drop_duration_ticks
		)
	else:
		task.begin(
			WorkerTaskModel.State.CARRYING_TO_ZONE,
			worker.zone_id,
			brood.entity_id,
			fallback_zone.zone_id,
			_config.travel_duration_ticks
		)


func _get_humidity_penalty(humidity: float) -> float:
	if humidity < _config.brood_humidity_min:
		return _config.brood_humidity_min - humidity
	if humidity > _config.brood_humidity_max:
		return humidity - _config.brood_humidity_max
	return 0.0


func _get_zone_penalty(zone: HabitatZoneState) -> float:
	if zone == null:
		return INF
	var penalty: float = _get_humidity_penalty(zone.humidity)
	if _environment_system != null:
		penalty += _environment_system.get_brood_pollution_penalty(
			zone.pollution
		)
	return penalty
