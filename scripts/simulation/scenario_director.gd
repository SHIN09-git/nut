class_name ScenarioDirector
extends RefCounted

var _sequence_config: ScenarioSequenceConfig
var _lifecycle_config: LifecycleConfig
var _brood_care_config: BroodCareConfig
var _habitat_config: HabitatScenarioConfig


func _init(
	sequence_config: ScenarioSequenceConfig,
	lifecycle_config: LifecycleConfig,
	brood_care_config: BroodCareConfig,
	habitat_config: HabitatScenarioConfig
) -> void:
	_sequence_config = sequence_config
	_lifecycle_config = lifecycle_config
	_brood_care_config = brood_care_config
	_habitat_config = habitat_config


func is_ready() -> bool:
	return (
		_sequence_config != null
		and _lifecycle_config != null
		and _brood_care_config != null
		and _habitat_config != null
		and _habitat_config.is_combined_observation()
		and (
			_sequence_config.first_worker_initial_pupa_age_ticks
			< _lifecycle_config.pupa_duration_ticks
		)
	)


func has_valid_state(state: ColonyState) -> bool:
	if (
		state == null
		or state.scenario_progress == null
		or state.scenario_progress.phase_entered_tick < 0
		or state.scenario_progress.phase_entered_tick > state.simulation_tick
	):
		return false

	var progress: ScenarioProgressState = state.scenario_progress
	var first_worker: AntModel = state.get_ant(
		progress.first_worker_entity_id
	)
	if first_worker == null:
		return false

	var known_entity_ids: Dictionary[int, bool] = {
		state.queen.entity_id: true,
	}
	for ant: AntModel in state.ants:
		if known_entity_ids.has(ant.entity_id):
			return false
		known_entity_ids[ant.entity_id] = true
	for source: FoodSourceState in state.food_sources:
		if known_entity_ids.has(source.entity_id):
			return false
		known_entity_ids[source.entity_id] = true

	var first_card_unlocked: bool = (
		state.unlocked_observation_card_ids.has(
			_sequence_config.first_worker_observation_card_id
		)
	)
	var humidity_card_unlocked: bool = (
		state.unlocked_observation_card_ids.has(
			_sequence_config.brood_humidity_observation_card_id
		)
	)
	var sugar_card_unlocked: bool = (
		state.unlocked_observation_card_ids.has(
			_habitat_config.foraging_observation_card_id
		)
	)

	if progress.phase == ScenarioSequenceSnapshot.Phase.FOUNDING_PRELUDE:
		return (
			first_worker.life_stage == AntModel.LifeStage.PUPA
			and first_worker.worker_task == null
			and first_worker.foraging_task == null
			and progress.first_worker_emerged_tick == -1
			and progress.humidity_observation_completed_tick == -1
			and progress.sugar_observation_completed_tick == -1
			and not first_card_unlocked
			and not humidity_card_unlocked
			and not sugar_card_unlocked
			and state.total_sugar_portions_placed == 0
		)

	if (
		first_worker.life_stage != AntModel.LifeStage.WORKER
		or first_worker.worker_task == null
		or first_worker.foraging_task == null
		or progress.first_worker_emerged_tick < 0
		or progress.first_worker_emerged_tick > state.simulation_tick
		or not first_card_unlocked
	):
		return false

	match progress.phase:
		ScenarioSequenceSnapshot.Phase.IDENTITY_OBSERVATION:
			return (
				_is_worker_idle(first_worker)
				and progress.humidity_observation_completed_tick == -1
				and progress.sugar_observation_completed_tick == -1
				and not humidity_card_unlocked
				and not sugar_card_unlocked
				and state.total_sugar_portions_placed == 0
			)
		ScenarioSequenceSnapshot.Phase.HUMIDITY_OBSERVATION:
			return (
				first_worker.foraging_task.state
					== ForagingTaskModel.State.IDLE
				and progress.humidity_observation_completed_tick == -1
				and progress.sugar_observation_completed_tick == -1
				and not humidity_card_unlocked
				and not sugar_card_unlocked
				and state.total_sugar_portions_placed == 0
			)
		ScenarioSequenceSnapshot.Phase.SUGAR_FORAGING:
			return (
				first_worker.worker_task.state == WorkerTaskModel.State.IDLE
				and progress.humidity_observation_completed_tick >= 0
				and progress.humidity_observation_completed_tick
					<= state.simulation_tick
				and progress.sugar_observation_completed_tick == -1
				and humidity_card_unlocked
				and not sugar_card_unlocked
			)
		ScenarioSequenceSnapshot.Phase.OBSERVATION_SUMMARY:
			return (
				_is_worker_idle(first_worker)
				and progress.humidity_observation_completed_tick >= 0
				and progress.sugar_observation_completed_tick >= 0
				and progress.sugar_observation_completed_tick
					<= state.simulation_tick
				and humidity_card_unlocked
				and sugar_card_unlocked
				and state.brood_humidity_observation_unlocked
			)
		_:
			return false


func advance_controlled_lifecycle(state: ColonyState) -> Dictionary:
	if (
		state == null
		or not is_ready()
		or state.scenario_progress == null
		or state.scenario_progress.phase
			!= ScenarioSequenceSnapshot.Phase.FOUNDING_PRELUDE
	):
		return {}

	var first_worker: AntModel = state.get_ant(
		state.scenario_progress.first_worker_entity_id
	)
	if (
		first_worker == null
		or first_worker.life_stage != AntModel.LifeStage.PUPA
	):
		return {}

	first_worker.total_age_ticks += 1
	first_worker.stage_age_ticks += 1
	if first_worker.stage_age_ticks < _lifecycle_config.pupa_duration_ticks:
		return {}

	var previous_stage: AntModel.LifeStage = first_worker.life_stage
	first_worker.transition_to(AntModel.LifeStage.WORKER)
	first_worker.configure_worker(
		_habitat_config.initial_worker_zone_id,
		state.simulation_tick
	)
	state.scenario_progress.first_worker_emerged_tick = state.simulation_tick
	state.unlocked_observation_card_ids[
		_sequence_config.first_worker_observation_card_id
	] = true
	state.record_observation_event(
		ObservationEvent.Type.FIRST_WORKER_EMERGED,
		first_worker.entity_id,
		first_worker.entity_id,
		_habitat_config.initial_brood_zone_id,
		_habitat_config.initial_worker_zone_id
	)
	state.scenario_progress.advance_to(
		ScenarioSequenceSnapshot.Phase.IDENTITY_OBSERVATION,
		state.simulation_tick
	)
	return {
		"entity_id": first_worker.entity_id,
		"previous_stage": previous_stage,
		"current_stage": first_worker.life_stage,
	}


func apply_identity_continue_action(state: ColonyState) -> bool:
	if not is_identity_continue_available(state):
		return false
	var first_worker_id: int = state.scenario_progress.first_worker_entity_id
	state.record_observation_event(
		ObservationEvent.Type.IDENTITY_OBSERVATION_COMPLETED,
		first_worker_id,
		first_worker_id
	)
	return state.scenario_progress.advance_to(
		ScenarioSequenceSnapshot.Phase.HUMIDITY_OBSERVATION,
		state.simulation_tick
	)


func update_after_systems(state: ColonyState) -> bool:
	if state == null or state.scenario_progress == null:
		return false

	match state.scenario_progress.phase:
		ScenarioSequenceSnapshot.Phase.HUMIDITY_OBSERVATION:
			if not state.brood_humidity_observation_unlocked:
				return false
			state.unlocked_observation_card_ids[
				_sequence_config.brood_humidity_observation_card_id
			] = true
			state.scenario_progress.humidity_observation_completed_tick = (
				state.simulation_tick
			)
			return state.scenario_progress.advance_to(
				ScenarioSequenceSnapshot.Phase.SUGAR_FORAGING,
				state.simulation_tick
			)
		ScenarioSequenceSnapshot.Phase.SUGAR_FORAGING:
			if not state.unlocked_observation_card_ids.has(
				_habitat_config.foraging_observation_card_id
			):
				return false
			state.scenario_progress.sugar_observation_completed_tick = (
				state.simulation_tick
			)
			state.record_observation_event(
				ObservationEvent.Type.OBSERVATION_SESSION_COMPLETED,
				state.scenario_progress.first_worker_entity_id
			)
			return state.scenario_progress.advance_to(
				ScenarioSequenceSnapshot.Phase.OBSERVATION_SUMMARY,
				state.simulation_tick
			)
		_:
			return false


func is_identity_continue_available(state: ColonyState) -> bool:
	return (
		state != null
		and state.scenario_progress != null
		and state.scenario_progress.phase
			== ScenarioSequenceSnapshot.Phase.IDENTITY_OBSERVATION
		and state.get_ant(state.scenario_progress.first_worker_entity_id)
			!= null
	)


func is_humidity_phase_active(state: ColonyState) -> bool:
	return (
		state != null
		and state.scenario_progress != null
		and state.scenario_progress.phase
			== ScenarioSequenceSnapshot.Phase.HUMIDITY_OBSERVATION
	)


func is_foraging_phase_active(state: ColonyState) -> bool:
	return (
		state != null
		and state.scenario_progress != null
		and state.scenario_progress.phase
			== ScenarioSequenceSnapshot.Phase.SUGAR_FORAGING
	)


func create_snapshot(
	state: ColonyState,
	continue_action_pending: bool
) -> ScenarioSequenceSnapshot:
	if state == null or state.scenario_progress == null:
		return null
	var progress: ScenarioProgressState = state.scenario_progress
	return ScenarioSequenceSnapshot.new(
		_habitat_config.scenario_id,
		progress.phase,
		progress.phase_entered_tick,
		progress.first_worker_entity_id,
		progress.first_worker_emerged_tick,
		progress.humidity_observation_completed_tick,
		progress.sugar_observation_completed_tick,
		_sequence_config.first_worker_observation_card_id,
		_sequence_config.brood_humidity_observation_card_id,
		_habitat_config.foraging_observation_card_id,
		is_identity_continue_available(state)
			and not continue_action_pending,
		continue_action_pending
	)


func _is_worker_idle(worker: AntModel) -> bool:
	return (
		worker != null
		and worker.worker_task != null
		and worker.worker_task.state == WorkerTaskModel.State.IDLE
		and worker.foraging_task != null
		and worker.foraging_task.state == ForagingTaskModel.State.IDLE
	)
