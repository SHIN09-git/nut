class_name FoundingCareSystem
extends RefCounted

var _config: FoundingCareConfig
var _habitat_config: HabitatScenarioConfig
var _environment_system: EnvironmentSystem


func _init(
	config: FoundingCareConfig,
	habitat_config: HabitatScenarioConfig,
	environment_system: EnvironmentSystem = null
) -> void:
	_config = config
	_habitat_config = habitat_config
	_environment_system = environment_system


func is_ready() -> bool:
	return (
		_config != null
		and _habitat_config != null
		and _habitat_config.is_act1_test_tube()
		and not _habitat_config.nest_zone_id.is_empty()
	)


func apply_light_cover(state: ColonyState) -> bool:
	if (
		not is_ready()
		or state == null
		or state.act1_state == null
		or state.act1_state.light_cover_applied
	):
		return false
	state.act1_state.light_cover_applied = true
	state.act1_state.light_cover_action_count += 1
	state.record_observation_event(
		ObservationEvent.Type.LIGHT_COVER_APPLIED
	)
	return true


func apply_feeding_disturbance(
	state: ColonyState,
	source_zone_id: StringName
) -> bool:
	if (
		not is_ready()
		or state == null
		or state.act1_state == null
		or source_zone_id.is_empty()
	):
		return false
	_reset_care_cycle(state.act1_state)
	state.record_observation_event(
		ObservationEvent.Type.FEEDING_DISTURBANCE_OCCURRED,
		ColonyState.QUEEN_ENTITY_ID,
		ObservationEvent.NO_ENTITY_ID,
		source_zone_id,
		_habitat_config.nest_zone_id
	)
	return true


func advance(state: ColonyState) -> void:
	if not is_ready() or state == null or state.act1_state == null:
		return
	var act1: Act1State = state.act1_state
	_update_first_worker(state, act1)
	_update_first_worker_care(state, act1)
	if not _is_care_environment_ready(state):
		_reset_care_cycle(act1)
		return
	_update_pupa_observation(state, act1)
	_update_queen_care(state, act1)


func create_snapshot(
	state: ColonyState,
	cover_action_pending: bool
) -> Act1Snapshot:
	if not is_ready() or state == null or state.act1_state == null:
		return null
	var act1: Act1State = state.act1_state
	var care: QueenCareSnapshot = QueenCareSnapshot.new()
	care.active = true
	care.light_cover_applied = act1.light_cover_applied
	care.light_cover_action_pending = cover_action_pending
	care.light_cover_action_available = (
		not act1.light_cover_applied and not cover_action_pending
	)
	care.care_state = act1.queen_care_state
	care.elapsed_ticks = act1.queen_care_elapsed_ticks
	care.duration_ticks = _get_state_duration(act1.queen_care_state)
	care.target_brood_id = act1.queen_care_target_brood_id
	care.completed_care_count = act1.completed_queen_care_count
	care.pupa_stable_ticks = act1.pupa_stable_ticks
	var snapshot: Act1Snapshot = Act1Snapshot.new()
	snapshot.active = true
	snapshot.queen_care = care
	snapshot.first_worker_entity_id = act1.first_worker_entity_id
	snapshot.first_worker_emerged_tick = act1.first_worker_emerged_tick
	snapshot.first_worker_care_recorded = (
		act1.first_worker_care_recorded
	)
	return snapshot


func has_valid_state(state: ColonyState) -> bool:
	if not is_ready() or state == null or state.act1_state == null:
		return false
	var act1: Act1State = state.act1_state
	if (
		act1.light_cover_action_count < 0
		or act1.light_cover_action_count > 1
		or act1.light_cover_applied
			!= (act1.light_cover_action_count == 1)
		or act1.queen_care_state < Act1State.QueenCareState.RESTING
		or act1.queen_care_state > Act1State.QueenCareState.BROOD_CARE
		or act1.queen_care_elapsed_ticks < 0
		or act1.queen_care_elapsed_ticks
			>= _get_state_duration(act1.queen_care_state)
		or act1.completed_queen_care_count < 0
		or act1.pupa_stable_ticks < 0
		or act1.pupa_stable_ticks > _config.pupa_observation_ticks
	):
		return false
	var care_environment_ready: bool = _is_care_environment_ready(state)
	var has_brood: bool = _get_lowest_brood(state) != null
	if not care_environment_ready or not has_brood:
		if (
			act1.queen_care_state != Act1State.QueenCareState.RESTING
			or act1.queen_care_elapsed_ticks != 0
			or act1.queen_care_target_brood_id != -1
		):
			return false
	elif (
		act1.queen_care_target_brood_id < 0
		or state.get_ant(act1.queen_care_target_brood_id) == null
	):
		return false
	var first_worker: AntModel = state.get_ant(
		act1.first_worker_entity_id
	)
	if first_worker == null:
		return false
	if act1.first_worker_emerged_tick < 0:
		if first_worker.life_stage == AntModel.LifeStage.WORKER:
			return false
	elif (
		act1.first_worker_emerged_tick > state.simulation_tick
		or first_worker.life_stage != AntModel.LifeStage.WORKER
	):
		return false
	if (
		act1.first_worker_care_recorded
		and (
			state.nutrition_state == null
			or state.nutrition_state.completed_feeding_count <= 0
		)
	):
		return false
	return true


func _is_care_environment_ready(state: ColonyState) -> bool:
	if state == null or state.act1_state == null:
		return false
	if not state.act1_state.light_cover_applied:
		return false
	if _environment_system == null:
		return true
	var nest_zone: HabitatZoneState = state.get_zone(
		_habitat_config.nest_zone_id
	)
	return (
		nest_zone != null
		and _environment_system.is_queen_care_light_comfortable(
			nest_zone.light_exposure
		)
	)


func _update_queen_care(state: ColonyState, act1: Act1State) -> void:
	var brood: AntModel = _get_lowest_brood(state)
	if brood == null:
		_reset_care_cycle(act1)
		return
	if act1.queen_care_target_brood_id < 0:
		act1.queen_care_target_brood_id = brood.entity_id
	act1.queen_care_elapsed_ticks += 1
	if (
		act1.queen_care_elapsed_ticks
		< _get_state_duration(act1.queen_care_state)
	):
		return
	act1.queen_care_elapsed_ticks = 0
	match act1.queen_care_state:
		Act1State.QueenCareState.RESTING:
			act1.queen_care_state = Act1State.QueenCareState.GATHERING
		Act1State.QueenCareState.GATHERING:
			act1.queen_care_state = Act1State.QueenCareState.BROOD_CARE
		Act1State.QueenCareState.BROOD_CARE:
			act1.completed_queen_care_count += 1
			state.unlocked_observation_card_ids[
				_config.queen_care_observation_card_id
			] = true
			state.record_observation_event(
				ObservationEvent.Type.QUEEN_BROOD_CARE_COMPLETED,
				ColonyState.QUEEN_ENTITY_ID,
				act1.queen_care_target_brood_id,
				_habitat_config.nest_zone_id,
				_habitat_config.nest_zone_id
			)
			act1.queen_care_state = Act1State.QueenCareState.RESTING
			act1.queen_care_target_brood_id = (
				_get_next_brood_id(state, act1.queen_care_target_brood_id)
			)


func _update_pupa_observation(
	state: ColonyState,
	act1: Act1State
) -> void:
	if state.unlocked_observation_card_ids.has(
		_config.pupa_observation_card_id
	):
		act1.pupa_stable_ticks = _config.pupa_observation_ticks
		return
	var first_worker: AntModel = state.get_ant(
		act1.first_worker_entity_id
	)
	if first_worker == null or first_worker.life_stage != AntModel.LifeStage.PUPA:
		act1.pupa_stable_ticks = 0
		return
	act1.pupa_stable_ticks = mini(
		_config.pupa_observation_ticks,
		act1.pupa_stable_ticks + 1
	)
	if act1.pupa_stable_ticks < _config.pupa_observation_ticks:
		return
	state.unlocked_observation_card_ids[
		_config.pupa_observation_card_id
	] = true
	state.record_observation_event(
		ObservationEvent.Type.FIRST_PUPA_OBSERVED,
		ColonyState.QUEEN_ENTITY_ID,
		first_worker.entity_id,
		_habitat_config.nest_zone_id,
		_habitat_config.nest_zone_id
	)


func _update_first_worker(state: ColonyState, act1: Act1State) -> void:
	if act1.first_worker_emerged_tick >= 0:
		return
	var first_worker: AntModel = state.get_ant(
		act1.first_worker_entity_id
	)
	if first_worker == null or first_worker.life_stage != AntModel.LifeStage.WORKER:
		return
	act1.first_worker_emerged_tick = state.simulation_tick
	state.unlocked_observation_card_ids[
		_config.first_worker_observation_card_id
	] = true
	state.record_observation_event(
		ObservationEvent.Type.FIRST_WORKER_EMERGED,
		first_worker.entity_id,
		first_worker.entity_id,
		_habitat_config.nest_zone_id,
		_habitat_config.nest_zone_id
	)


func _update_first_worker_care(
	state: ColonyState,
	act1: Act1State
) -> void:
	if (
		act1.first_worker_care_recorded
		or state.nutrition_state == null
		or state.nutrition_state.completed_feeding_count <= 0
	):
		return
	act1.first_worker_care_recorded = true
	state.unlocked_observation_card_ids[
		_config.worker_care_observation_card_id
	] = true


func _get_lowest_brood(state: ColonyState) -> AntModel:
	var result: AntModel
	for ant: AntModel in state.ants:
		if ant.life_stage == AntModel.LifeStage.WORKER:
			continue
		if result == null or ant.entity_id < result.entity_id:
			result = ant
	return result


func _get_next_brood_id(state: ColonyState, current_id: int) -> int:
	var ids: Array[int] = []
	for ant: AntModel in state.ants:
		if ant.life_stage != AntModel.LifeStage.WORKER:
			ids.append(ant.entity_id)
	ids.sort()
	if ids.is_empty():
		return -1
	for entity_id: int in ids:
		if entity_id > current_id:
			return entity_id
	return ids[0]


func _get_state_duration(state: Act1State.QueenCareState) -> int:
	match state:
		Act1State.QueenCareState.RESTING:
			return _config.rest_duration_ticks
		Act1State.QueenCareState.GATHERING:
			return _config.gathering_duration_ticks
		Act1State.QueenCareState.BROOD_CARE:
			return _config.brood_care_duration_ticks
	return 1


func _reset_care_cycle(act1: Act1State) -> void:
	act1.queen_care_state = Act1State.QueenCareState.RESTING
	act1.queen_care_elapsed_ticks = 0
	act1.queen_care_target_brood_id = -1
