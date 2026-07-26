class_name ColonySimulation
extends RefCounted

signal egg_laid(entity_id: int, simulation_tick: int)
signal life_stage_changed(
	entity_id: int,
	previous_stage: AntModel.LifeStage,
	current_stage: AntModel.LifeStage,
	simulation_tick: int
)

enum PendingCommandType {
	WATER_ACTION,
	PLACE_SUGAR_ACTION,
}

var _lifecycle_config: LifecycleConfig
var _brood_care_config: BroodCareConfig
var _habitat_config: HabitatScenarioConfig
var _brood_relocation_system: BroodRelocationSystem
var _foraging_system: ForagingSystem
var _state: ColonyState
var _pending_commands: Array[int] = []
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
		_configuration_error = (
			"ColonySimulation requires valid HabitatScenarioData"
		)
		return

	_brood_relocation_system = BroodRelocationSystem.new(
		_brood_care_config
	)
	if not _brood_relocation_system.is_ready():
		_configuration_error = (
			"ColonySimulation could not initialize brood relocation"
		)
		return

	if _habitat_config.is_sugar_foraging():
		_foraging_system = ForagingSystem.new(
			_habitat_config.foraging_config,
			_habitat_config
		)
		if not _foraging_system.is_ready():
			_configuration_error = (
				"ColonySimulation could not initialize foraging"
			)
			return

	if not _state.initialize_habitat(
		_habitat_config,
		_brood_care_config
	):
		_configuration_error = (
			"ColonySimulation could not initialize habitat state"
		)
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
	_pending_commands.append(PendingCommandType.WATER_ACTION)
	return true


func submit_place_sugar_action() -> bool:
	if not _is_place_sugar_action_available():
		return false
	_pending_commands.append(PendingCommandType.PLACE_SUGAR_ACTION)
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
	_pending_commands.clear()
	return true


func advance_tick(tick_index: int) -> bool:
	if not is_ready() or tick_index != _state.simulation_tick + 1:
		return false

	_state.simulation_tick = tick_index
	if not has_habitat():
		_update_existing_ants()
		_try_lay_egg()
		return true

	_apply_pending_commands()
	_brood_relocation_system.validate_tasks(_state)
	if _foraging_system != null:
		_foraging_system.validate_tasks(_state)
	_brood_relocation_system.advance_tasks(_state)
	if _foraging_system != null:
		_foraging_system.advance_tasks(_state)
	_brood_relocation_system.assign_idle_workers(_state)
	if _foraging_system != null:
		_foraging_system.assign_idle_workers(_state)
	if _habitat_config.is_humidity_relocation():
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
	snapshot.water_action_unlocked = (
		_state.water_action_unlocked
		if _is_humidity_relocation_scenario()
		else false
	)
	snapshot.water_action_pending = _has_pending_command(
		PendingCommandType.WATER_ACTION
	)
	snapshot.water_action_count = (
		_state.humidity_adjustment_count
		if _is_humidity_relocation_scenario()
		else 0
	)
	snapshot.water_target_comfortable = _is_water_target_comfortable()
	snapshot.water_action_available = _is_water_action_available()
	snapshot.observation_stable_ticks = (
		_state.observation_stable_ticks
		if _is_humidity_relocation_scenario()
		else 0
	)
	snapshot.brood_humidity_observation_unlocked = (
		_state.brood_humidity_observation_unlocked
		if _is_humidity_relocation_scenario()
		else false
	)
	snapshot.observation_events = _state.copy_observation_events()

	for zone: HabitatZoneState in _state.zones:
		snapshot.zones.append(HabitatZoneSnapshot.new(
			zone.zone_id,
			zone.humidity,
			zone.connected_zone_ids,
			zone.available
		))

	var brood_reserved_by_worker_id: Dictionary[int, int] = {}
	var brood_carrier_worker_id: Dictionary[int, int] = {}
	var food_reserved_by_worker_id: Dictionary[int, int] = {}
	var food_carrier_worker_id: Dictionary[int, int] = {}
	for ant: AntModel in _state.ants:
		if ant.worker_task != null:
			if ant.worker_task.target_brood_id >= 0:
				brood_reserved_by_worker_id[
					ant.worker_task.target_brood_id
				] = ant.entity_id
			if ant.worker_task.carried_brood_id >= 0:
				brood_carrier_worker_id[
					ant.worker_task.carried_brood_id
				] = ant.entity_id
		if (
			ant.foraging_task != null
			and ant.foraging_task.state != ForagingTaskModel.State.IDLE
		):
			food_reserved_by_worker_id[
				ant.foraging_task.target_food_source_id
			] = ant.entity_id
			if ant.foraging_task.carried_portions > 0:
				food_carrier_worker_id[
					ant.foraging_task.target_food_source_id
				] = ant.entity_id

	for source: FoodSourceState in _state.food_sources:
		snapshot.food_sources.append(FoodSourceSnapshot.new(
			source.entity_id,
			source.zone_id,
			source.food_type,
			source.remaining_portions,
			source.available,
			food_reserved_by_worker_id.get(source.entity_id, -1),
			food_carrier_worker_id.get(source.entity_id, -1)
		))

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

		var foraging_task_snapshot: ForagingTaskSnapshot
		if ant.foraging_task != null:
			foraging_task_snapshot = ant.foraging_task.create_snapshot()
		snapshot.ants.append(AntSnapshot.new(
			ant.entity_id,
			ant.life_stage,
			ant.total_age_ticks,
			ant.stage_age_ticks,
			get_stage_duration_ticks(ant.life_stage),
			ant.zone_id,
			ant.zone_entered_tick,
			brood_reserved_by_worker_id.get(ant.entity_id, -1),
			brood_carrier_worker_id.get(ant.entity_id, -1),
			task_state,
			task_origin_zone_id,
			target_brood_id,
			target_zone_id,
			carried_brood_id,
			task_elapsed_ticks,
			task_duration_ticks,
			foraging_task_snapshot
		))

	return snapshot


func create_game_snapshot() -> GameSnapshot:
	if not is_ready() or not _is_sugar_foraging_scenario():
		return null

	var place_action_pending: bool = _has_pending_command(
		PendingCommandType.PLACE_SUGAR_ACTION
	)
	var phase: ForagingScenarioSnapshot.Phase = (
		ForagingScenarioSnapshot.Phase.AWAITING_PLACEMENT
	)
	if _state.unlocked_observation_card_ids.has(
		_habitat_config.foraging_observation_card_id
	):
		phase = ForagingScenarioSnapshot.Phase.COMPLETED
	elif _state.total_sugar_portions_placed > 0 or place_action_pending:
		phase = ForagingScenarioSnapshot.Phase.ACTIVE

	var scenario_snapshot: ForagingScenarioSnapshot = (
		ForagingScenarioSnapshot.new(
			_habitat_config.scenario_id,
			_habitat_config.nest_zone_id,
			_habitat_config.sugar_placement_zone_id,
			phase,
			_is_place_sugar_action_available(),
			place_action_pending,
			1 if _state.total_sugar_portions_placed > 0 else 0
		)
	)
	var observation_snapshot: ObservationJournalSnapshot = (
		ObservationJournalSnapshot.new(
			_state.copy_observation_events(),
			_state.copy_unlocked_observation_card_ids()
		)
	)
	return GameSnapshot.new(
		_state.simulation_tick,
		create_snapshot(),
		scenario_snapshot,
		observation_snapshot
	)


func get_next_egg_tick() -> int:
	if not is_ready():
		return -1
	if has_habitat():
		return -1
	if (
		_state.queen.laid_egg_count
		>= _lifecycle_config.max_first_generation_brood
	):
		return -1
	return (
		_lifecycle_config.first_egg_delay_ticks
		+ _state.queen.laid_egg_count
		* _lifecycle_config.egg_laying_interval_ticks
	)


func get_stage_duration_ticks(stage: AntModel.LifeStage) -> int:
	match stage:
		AntModel.LifeStage.EGG:
			return (
				_lifecycle_config.egg_duration_ticks if is_ready() else 0
			)
		AntModel.LifeStage.LARVA:
			return (
				_lifecycle_config.larva_duration_ticks if is_ready() else 0
			)
		AntModel.LifeStage.PUPA:
			return (
				_lifecycle_config.pupa_duration_ticks if is_ready() else 0
			)
		AntModel.LifeStage.WORKER:
			return 0
		_:
			return 0


func has_valid_habitat_ownership() -> bool:
	if not has_habitat():
		return true
	return _has_valid_habitat_ownership(_state)


func _has_valid_habitat_ownership(state: ColonyState) -> bool:
	if (
		state == null
		or _brood_relocation_system == null
		or not _brood_relocation_system.has_valid_ownership(state)
	):
		return false
	if (
		_foraging_system != null
		and not _foraging_system.has_valid_ownership(state)
	):
		return false
	return true


func _apply_pending_commands() -> void:
	var commands_to_apply: Array[int] = _pending_commands
	_pending_commands = []
	for command_type: int in commands_to_apply:
		match command_type:
			PendingCommandType.WATER_ACTION:
				_apply_water_action()
			PendingCommandType.PLACE_SUGAR_ACTION:
				if _foraging_system != null:
					_foraging_system.apply_configured_sugar_placement(
						_state
					)


func _apply_water_action() -> void:
	if not _is_humidity_relocation_scenario():
		return
	var zone: HabitatZoneState = _state.get_zone(
		_habitat_config.humidity_adjustment_zone_id
	)
	if (
		zone != null
		and zone.apply_humidity_adjustment(
			_habitat_config.humidity_adjustment_amount
		)
	):
		_state.humidity_adjustment_count += 1


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
		if (
			zone == null
			or not _brood_relocation_system.is_humidity_comfortable(
				zone.humidity
			)
		):
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


func _is_humidity_relocation_scenario() -> bool:
	return (
		is_ready()
		and has_habitat()
		and _habitat_config.is_humidity_relocation()
	)


func _is_sugar_foraging_scenario() -> bool:
	return (
		is_ready()
		and has_habitat()
		and _habitat_config.is_sugar_foraging()
	)


func _is_water_target_comfortable() -> bool:
	if not _is_humidity_relocation_scenario():
		return false
	var target_zone: HabitatZoneState = _state.get_zone(
		_habitat_config.humidity_adjustment_zone_id
	)
	return (
		target_zone != null
		and _brood_relocation_system.is_humidity_comfortable(
			target_zone.humidity
		)
	)


func _is_water_action_available() -> bool:
	if (
		not _is_humidity_relocation_scenario()
		or not _state.water_action_unlocked
		or _has_pending_command(PendingCommandType.WATER_ACTION)
		or _state.brood_humidity_observation_unlocked
		or _is_water_target_comfortable()
	):
		return false
	var target_zone: HabitatZoneState = _state.get_zone(
		_habitat_config.humidity_adjustment_zone_id
	)
	return target_zone != null and target_zone.available


func _is_place_sugar_action_available() -> bool:
	if (
		not _is_sugar_foraging_scenario()
		or _foraging_system == null
		or _has_pending_command(PendingCommandType.PLACE_SUGAR_ACTION)
		or _state.total_sugar_portions_placed > 0
		or _state.unlocked_observation_card_ids.has(
			_habitat_config.foraging_observation_card_id
		)
	):
		return false
	var placement_zone: HabitatZoneState = _state.get_zone(
		_habitat_config.sugar_placement_zone_id
	)
	return placement_zone != null and placement_zone.available


func _has_pending_command(command_type: int) -> bool:
	return _pending_commands.has(command_type)


func _update_existing_ants() -> void:
	for ant: AntModel in _state.ants:
		ant.total_age_ticks += 1
		ant.stage_age_ticks += 1
		if ant.life_stage == AntModel.LifeStage.WORKER:
			continue

		var stage_duration_ticks: int = get_stage_duration_ticks(
			ant.life_stage
		)
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


func _get_next_life_stage(
	stage: AntModel.LifeStage
) -> AntModel.LifeStage:
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
