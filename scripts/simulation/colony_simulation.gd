class_name ColonySimulation
extends RefCounted

signal egg_laid(entity_id: int, simulation_tick: int)
signal life_stage_changed(
	entity_id: int,
	previous_stage: AntModel.LifeStage,
	current_stage: AntModel.LifeStage,
	simulation_tick: int
)

const IMPROVEMENT_EPSILON: float = 0.000001

var _lifecycle_config: LifecycleConfig
var _brood_care_config: BroodCareConfig
var _habitat_config: HabitatScenarioConfig
var _state: ColonyState
var _pending_humidity_commands: Array[HumidityAdjustmentCommand] = []
var _configuration_error: String = ""


func _init(
	species_data: SpeciesData,
	habitat_scenario_data: HabitatScenarioData = null
) -> void:
	_state = ColonyState.new()
	_lifecycle_config = LifecycleConfig.from_species_data(species_data)
	if _lifecycle_config == null:
		_configuration_error = "ColonySimulation requires valid SpeciesData"
		return

	if habitat_scenario_data == null:
		return

	_brood_care_config = BroodCareConfig.from_species_data(species_data)
	if _brood_care_config == null:
		_configuration_error = "ColonySimulation requires valid brood-care data"
		return

	_habitat_config = HabitatScenarioConfig.from_data(habitat_scenario_data)
	if _habitat_config == null:
		_configuration_error = "ColonySimulation requires valid HabitatScenarioData"
		return
	if not _state.initialize_habitat(_habitat_config, _brood_care_config):
		_configuration_error = "ColonySimulation could not initialize habitat state"
		return
	if not has_valid_habitat_ownership():
		_configuration_error = "Initial habitat ownership is invalid"


func is_ready() -> bool:
	return _configuration_error.is_empty()


func has_habitat() -> bool:
	return _habitat_config != null


func get_configuration_error() -> String:
	return _configuration_error


func submit_water_action() -> bool:
	if not _is_water_action_available():
		return false
	_pending_humidity_commands.append(
		HumidityAdjustmentCommand.new(
			_habitat_config.humidity_adjustment_zone_id,
			_habitat_config.humidity_adjustment_amount
		)
	)
	return true


func restart_session() -> bool:
	if not is_ready():
		return false

	var initial_state: ColonyState = ColonyState.new()
	if has_habitat():
		if not initial_state.initialize_habitat(
			_habitat_config,
			_brood_care_config
		):
			return false
		if not _has_valid_habitat_ownership(initial_state):
			return false

	_state = initial_state
	_pending_humidity_commands.clear()
	return true


func advance_tick(tick_index: int) -> bool:
	if not is_ready() or tick_index != _state.simulation_tick + 1:
		return false

	_state.simulation_tick = tick_index
	if not has_habitat():
		_update_existing_ants()
		_try_lay_egg()
		return true

	_apply_pending_humidity_commands()
	_validate_active_worker_tasks()
	_advance_worker_tasks()
	_assign_idle_workers()
	_update_observation_record()
	if not has_valid_habitat_ownership():
		_configuration_error = (
			"Habitat ownership invariant failed at Tick %d"
			% _state.simulation_tick
		)
		return false
	return true


func create_snapshot() -> ColonySnapshot:
	var snapshot: ColonySnapshot = ColonySnapshot.new()
	snapshot.simulation_tick = _state.simulation_tick
	snapshot.lifecycle_active = not has_habitat()
	snapshot.queen_entity_id = _state.queen.entity_id
	snapshot.queen_laid_egg_count = (
		_state.queen.laid_egg_count if snapshot.lifecycle_active else 0
	)
	snapshot.max_first_generation_brood = (
		_lifecycle_config.max_first_generation_brood
		if is_ready() and snapshot.lifecycle_active
		else 0
	)
	snapshot.next_egg_tick = get_next_egg_tick()
	snapshot.scenario_id = (
		_habitat_config.scenario_id if has_habitat() else &""
	)
	snapshot.humidity_adjustment_count = _state.humidity_adjustment_count
	snapshot.water_action_unlocked = _state.water_action_unlocked
	snapshot.water_action_pending = not _pending_humidity_commands.is_empty()
	snapshot.water_action_count = _state.humidity_adjustment_count
	snapshot.water_target_comfortable = _is_water_target_comfortable()
	snapshot.water_action_available = _is_water_action_available()
	snapshot.observation_stable_ticks = _state.observation_stable_ticks
	snapshot.brood_humidity_observation_unlocked = (
		_state.brood_humidity_observation_unlocked
	)
	snapshot.observation_events = _state.copy_observation_events()

	for zone: HabitatZoneState in _state.zones:
		snapshot.zones.append(HabitatZoneSnapshot.new(
			zone.zone_id,
			zone.humidity,
			zone.connected_zone_ids,
			zone.available
		))

	var reserved_by_ant_id: Dictionary = {}
	var carrier_ant_id: Dictionary = {}
	for ant: AntModel in _state.ants:
		if ant.worker_task == null:
			continue
		if ant.worker_task.target_brood_id >= 0:
			reserved_by_ant_id[ant.worker_task.target_brood_id] = ant.entity_id
		if ant.worker_task.carried_brood_id >= 0:
			carrier_ant_id[ant.worker_task.carried_brood_id] = ant.entity_id

	for ant: AntModel in _state.ants:
		var task_state: int = WorkerTaskModel.State.IDLE
		var task_origin_zone_id: StringName = &""
		var target_brood_id: int = -1
		var target_zone_id: StringName = &""
		var carried_brood_id: int = -1
		var task_elapsed_ticks: int = 0
		var task_duration_ticks: int = 0
		if ant.worker_task != null:
			task_state = ant.worker_task.state
			task_origin_zone_id = ant.worker_task.origin_zone_id
			target_brood_id = ant.worker_task.target_brood_id
			target_zone_id = ant.worker_task.target_zone_id
			carried_brood_id = ant.worker_task.carried_brood_id
			task_elapsed_ticks = ant.worker_task.elapsed_ticks
			task_duration_ticks = ant.worker_task.duration_ticks

		snapshot.ants.append(AntSnapshot.new(
			ant.entity_id,
			ant.life_stage,
			ant.total_age_ticks,
			ant.stage_age_ticks,
			get_stage_duration_ticks(ant.life_stage),
			ant.zone_id,
			ant.zone_entered_tick,
			reserved_by_ant_id.get(ant.entity_id, -1),
			carrier_ant_id.get(ant.entity_id, -1),
			task_state,
			task_origin_zone_id,
			target_brood_id,
			target_zone_id,
			carried_brood_id,
			task_elapsed_ticks,
			task_duration_ticks
		))

	return snapshot


func get_next_egg_tick() -> int:
	if not is_ready():
		return -1
	if has_habitat():
		return -1
	if _state.queen.laid_egg_count >= _lifecycle_config.max_first_generation_brood:
		return -1
	return (
		_lifecycle_config.first_egg_delay_ticks
		+ _state.queen.laid_egg_count
		* _lifecycle_config.egg_laying_interval_ticks
	)


func get_stage_duration_ticks(stage: AntModel.LifeStage) -> int:
	match stage:
		AntModel.LifeStage.EGG:
			return _lifecycle_config.egg_duration_ticks if is_ready() else 0
		AntModel.LifeStage.LARVA:
			return _lifecycle_config.larva_duration_ticks if is_ready() else 0
		AntModel.LifeStage.PUPA:
			return _lifecycle_config.pupa_duration_ticks if is_ready() else 0
		AntModel.LifeStage.WORKER:
			return 0
		_:
			return 0


func has_valid_habitat_ownership() -> bool:
	if not has_habitat():
		return true
	return _has_valid_habitat_ownership(_state)


func _has_valid_habitat_ownership(state: ColonyState) -> bool:
	if state == null:
		return false

	var reservation_counts: Dictionary = {}
	var carrier_counts: Dictionary = {}
	for ant: AntModel in state.ants:
		if ant.life_stage != AntModel.LifeStage.WORKER:
			continue
		if ant.worker_task == null or state.get_zone(ant.zone_id) == null:
			return false

		var task: WorkerTaskModel = ant.worker_task
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


func _apply_pending_humidity_commands() -> void:
	var commands_to_apply: Array[HumidityAdjustmentCommand] = (
		_pending_humidity_commands
	)
	_pending_humidity_commands = []
	for command: HumidityAdjustmentCommand in commands_to_apply:
		var zone: HabitatZoneState = _state.get_zone(command.zone_id)
		if zone != null and zone.apply_humidity_adjustment(command.amount):
			_state.humidity_adjustment_count += 1


func _validate_active_worker_tasks() -> void:
	var claimed_brood_ids: Dictionary = {}
	for worker: AntModel in _state.ants:
		if worker.worker_task == null:
			continue
		var task: WorkerTaskModel = worker.worker_task
		if task.state == WorkerTaskModel.State.IDLE:
			continue

		var brood: AntModel = _state.get_ant(task.target_brood_id)
		if (
			brood == null
			or brood.life_stage == AntModel.LifeStage.WORKER
			or claimed_brood_ids.has(task.target_brood_id)
		):
			_cancel_or_rehome_task(worker)
			continue
		claimed_brood_ids[task.target_brood_id] = true

		if (
			task.state == WorkerTaskModel.State.MOVING_TO_BROOD
			or task.state == WorkerTaskModel.State.PICKING_UP
		):
			if not _is_pre_pickup_task_valid(brood, task):
				task.reset_to_idle(
					_state.simulation_tick
					+ _brood_care_config.decision_interval_ticks
				)
			continue

		if (
			task.state == WorkerTaskModel.State.CARRYING_TO_ZONE
			or task.state == WorkerTaskModel.State.DROPPING
		):
			_retarget_carried_brood_if_needed(worker, brood)


func _advance_worker_tasks() -> void:
	for worker: AntModel in _state.ants:
		if worker.worker_task == null:
			continue
		var task: WorkerTaskModel = worker.worker_task
		if task.state == WorkerTaskModel.State.IDLE:
			continue

		task.elapsed_ticks += 1
		if task.elapsed_ticks < task.duration_ticks:
			continue

		var brood: AntModel = _state.get_ant(task.target_brood_id)
		if brood == null:
			_cancel_or_rehome_task(worker)
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
					_brood_care_config.pickup_duration_ticks
				)
				_state.record_observation_event(
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
					_brood_care_config.travel_duration_ticks
				)
				_state.record_observation_event(
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
					_brood_care_config.drop_duration_ticks
				)
			WorkerTaskModel.State.DROPPING:
				var relocation_source_zone_id: StringName = (
					task.origin_zone_id
				)
				var relocation_target_zone_id: StringName = (
					task.target_zone_id
				)
				brood.zone_id = relocation_target_zone_id
				brood.zone_entered_tick = _state.simulation_tick
				worker.zone_id = relocation_target_zone_id
				_state.water_action_unlocked = true
				_state.record_observation_event(
					ObservationEvent.Type.BROOD_DROPPED,
					worker.entity_id,
					brood.entity_id,
					relocation_source_zone_id,
					relocation_target_zone_id
				)
				task.reset_to_idle(
					_state.simulation_tick
					+ _brood_care_config.decision_interval_ticks
				)


func _assign_idle_workers() -> void:
	var reserved_brood_ids: Dictionary = {}
	for worker: AntModel in _state.ants:
		if (
			worker.worker_task != null
			and worker.worker_task.state != WorkerTaskModel.State.IDLE
		):
			reserved_brood_ids[worker.worker_task.target_brood_id] = true

	for worker: AntModel in _state.ants:
		if (
			worker.worker_task == null
			or worker.worker_task.state != WorkerTaskModel.State.IDLE
			or _state.simulation_tick < worker.worker_task.next_decision_tick
		):
			continue
		worker.worker_task.next_decision_tick = (
			_state.simulation_tick
			+ _brood_care_config.decision_interval_ticks
		)
		var assignment: Dictionary = _find_assignment(reserved_brood_ids)
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
			_brood_care_config.travel_duration_ticks
		)
		_state.record_observation_event(
			ObservationEvent.Type.RELOCATION_STARTED,
			worker.entity_id,
			brood.entity_id,
			brood.zone_id,
			target_zone.zone_id
		)
		reserved_brood_ids[brood.entity_id] = true


func _find_assignment(reserved_brood_ids: Dictionary) -> Dictionary:
	for brood: AntModel in _state.ants:
		if (
			brood.life_stage == AntModel.LifeStage.WORKER
			or brood.zone_id.is_empty()
			or reserved_brood_ids.has(brood.entity_id)
			or (
				_state.simulation_tick - brood.zone_entered_tick
				< _brood_care_config.minimum_zone_dwell_ticks
			)
		):
			continue
		var target_zone: HabitatZoneState = _find_best_relocation_zone(
			brood.zone_id
		)
		if target_zone != null:
			return {"brood": brood, "target_zone": target_zone}
	return {}


func _find_best_relocation_zone(
	source_zone_id: StringName
) -> HabitatZoneState:
	var source_zone: HabitatZoneState = _state.get_zone(source_zone_id)
	if source_zone == null or not source_zone.available:
		return null

	var source_penalty: float = _get_humidity_penalty(source_zone.humidity)
	var best_zone: HabitatZoneState
	var best_penalty: float = source_penalty
	for candidate: HabitatZoneState in _state.zones:
		if (
			not candidate.available
			or candidate.zone_id == source_zone_id
			or not source_zone.can_reach(candidate.zone_id)
		):
			continue
		var candidate_penalty: float = _get_humidity_penalty(
			candidate.humidity
		)
		var improvement: float = source_penalty - candidate_penalty
		if (
			improvement + IMPROVEMENT_EPSILON
			< _brood_care_config.relocation_min_improvement
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
	from_zone_id: StringName
) -> HabitatZoneState:
	var from_zone: HabitatZoneState = _state.get_zone(from_zone_id)
	if from_zone == null:
		return null
	var best_zone: HabitatZoneState
	var best_penalty: float = INF
	for candidate: HabitatZoneState in _state.zones:
		if (
			not candidate.available
			or not from_zone.can_reach(candidate.zone_id)
		):
			continue
		var penalty: float = _get_humidity_penalty(candidate.humidity)
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
	brood: AntModel,
	task: WorkerTaskModel
) -> bool:
	if brood.zone_id.is_empty():
		return false
	var source_zone: HabitatZoneState = _state.get_zone(brood.zone_id)
	var target_zone: HabitatZoneState = _state.get_zone(task.target_zone_id)
	if (
		source_zone == null
		or target_zone == null
		or not target_zone.available
		or not source_zone.can_reach(target_zone.zone_id)
	):
		return false
	return (
		_get_humidity_penalty(source_zone.humidity)
		- _get_humidity_penalty(target_zone.humidity)
		+ IMPROVEMENT_EPSILON
		>= _brood_care_config.relocation_min_improvement
	)


func _retarget_carried_brood_if_needed(
	worker: AntModel,
	brood: AntModel
) -> void:
	var task: WorkerTaskModel = worker.worker_task
	if task.carried_brood_id != brood.entity_id:
		_cancel_or_rehome_task(worker)
		return

	var current_target: HabitatZoneState = _state.get_zone(task.target_zone_id)
	var worker_zone: HabitatZoneState = _state.get_zone(worker.zone_id)
	if (
		current_target != null
		and current_target.available
		and worker_zone != null
		and worker_zone.can_reach(current_target.zone_id)
	):
		return

	var best_zone: HabitatZoneState = _find_best_available_zone(worker.zone_id)
	if best_zone == null:
		return

	if best_zone.zone_id == worker.zone_id:
		task.begin(
			WorkerTaskModel.State.DROPPING,
			worker.zone_id,
			brood.entity_id,
			best_zone.zone_id,
			_brood_care_config.drop_duration_ticks
		)
	else:
		task.begin(
			WorkerTaskModel.State.CARRYING_TO_ZONE,
			worker.zone_id,
			brood.entity_id,
			best_zone.zone_id,
			_brood_care_config.travel_duration_ticks
		)


func _cancel_or_rehome_task(worker: AntModel) -> void:
	var task: WorkerTaskModel = worker.worker_task
	if task.carried_brood_id < 0:
		task.reset_to_idle(
			_state.simulation_tick
			+ _brood_care_config.decision_interval_ticks
		)
		return

	var brood: AntModel = _state.get_ant(task.carried_brood_id)
	var fallback_zone: HabitatZoneState = _find_best_available_zone(worker.zone_id)
	if brood == null or fallback_zone == null:
		return
	if fallback_zone.zone_id == worker.zone_id:
		task.begin(
			WorkerTaskModel.State.DROPPING,
			worker.zone_id,
			brood.entity_id,
			fallback_zone.zone_id,
			_brood_care_config.drop_duration_ticks
		)
	else:
		task.begin(
			WorkerTaskModel.State.CARRYING_TO_ZONE,
			worker.zone_id,
			brood.entity_id,
			fallback_zone.zone_id,
			_brood_care_config.travel_duration_ticks
		)


func _update_observation_record() -> void:
	if _state.brood_humidity_observation_unlocked:
		return
	var brood_count: int = 0
	var all_brood_comfortable: bool = true
	var no_active_tasks: bool = true
	for ant: AntModel in _state.ants:
		if ant.life_stage == AntModel.LifeStage.WORKER:
			if (
				ant.worker_task != null
				and ant.worker_task.state != WorkerTaskModel.State.IDLE
			):
				no_active_tasks = false
			continue
		brood_count += 1
		var zone: HabitatZoneState = _state.get_zone(ant.zone_id)
		if zone == null or not _is_humidity_comfortable(zone.humidity):
			all_brood_comfortable = false

	if (
		_state.humidity_adjustment_count > 0
		and brood_count > 0
		and all_brood_comfortable
		and no_active_tasks
	):
		_state.observation_stable_ticks += 1
	else:
		_state.observation_stable_ticks = 0
	if (
		_state.observation_stable_ticks
		>= _habitat_config.observation_stable_ticks
	):
		_state.brood_humidity_observation_unlocked = true
		_state.record_observation_event(
			ObservationEvent.Type.BROOD_HUMIDITY_OBSERVATION_COMPLETED
		)


func _get_humidity_penalty(humidity: float) -> float:
	if humidity < _brood_care_config.brood_humidity_min:
		return _brood_care_config.brood_humidity_min - humidity
	if humidity > _brood_care_config.brood_humidity_max:
		return humidity - _brood_care_config.brood_humidity_max
	return 0.0


func _is_humidity_comfortable(humidity: float) -> bool:
	return (
		humidity + IMPROVEMENT_EPSILON
		>= _brood_care_config.brood_humidity_min
		and humidity - IMPROVEMENT_EPSILON
		<= _brood_care_config.brood_humidity_max
	)


func _is_water_target_comfortable() -> bool:
	if not is_ready() or not has_habitat():
		return false
	var target_zone: HabitatZoneState = _state.get_zone(
		_habitat_config.humidity_adjustment_zone_id
	)
	return target_zone != null and _is_humidity_comfortable(target_zone.humidity)


func _is_water_action_available() -> bool:
	if (
		not is_ready()
		or not has_habitat()
		or not _state.water_action_unlocked
		or not _pending_humidity_commands.is_empty()
		or _state.brood_humidity_observation_unlocked
		or _is_water_target_comfortable()
	):
		return false
	var target_zone: HabitatZoneState = _state.get_zone(
		_habitat_config.humidity_adjustment_zone_id
	)
	return target_zone != null and target_zone.available


func _update_existing_ants() -> void:
	for ant: AntModel in _state.ants:
		ant.total_age_ticks += 1
		ant.stage_age_ticks += 1
		if ant.life_stage == AntModel.LifeStage.WORKER:
			continue

		var stage_duration_ticks: int = get_stage_duration_ticks(ant.life_stage)
		if ant.stage_age_ticks < stage_duration_ticks:
			continue

		var previous_stage: AntModel.LifeStage = ant.life_stage
		ant.transition_to(_get_next_life_stage(previous_stage))
		life_stage_changed.emit(
			ant.entity_id,
			previous_stage,
			ant.life_stage,
			_state.simulation_tick
		)


func _try_lay_egg() -> void:
	var next_egg_tick: int = get_next_egg_tick()
	if next_egg_tick < 0 or _state.simulation_tick < next_egg_tick:
		return

	var egg: AntModel = _state.create_egg()
	egg_laid.emit(egg.entity_id, _state.simulation_tick)


func _get_next_life_stage(stage: AntModel.LifeStage) -> AntModel.LifeStage:
	match stage:
		AntModel.LifeStage.EGG:
			return AntModel.LifeStage.LARVA
		AntModel.LifeStage.LARVA:
			return AntModel.LifeStage.PUPA
		AntModel.LifeStage.PUPA:
			return AntModel.LifeStage.WORKER
		_:
			push_error("Invalid ant life stage: %d" % stage)
			return stage
