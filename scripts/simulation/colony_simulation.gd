class_name ColonySimulation
extends RefCounted

const HUMIDITY_EPSILON: float = 0.000001

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
	CONTINUE_OBSERVATION_ACTION,
	SELECT_CAMPAIGN_INFERENCE_ACTION,
	PLACE_PROTEIN_ACTION,
}

var _lifecycle_config: LifecycleConfig
var _brood_care_config: BroodCareConfig
var _habitat_config: HabitatScenarioConfig
var _brood_relocation_system: BroodRelocationSystem
var _foraging_system: ForagingSystem
var _nutrition_system: NutritionSystem
var _scenario_director: ScenarioDirector
var _campaign_director: CampaignDirector
var _state: ColonyState
var _pending_commands: Array[PendingSimulationCommand] = []
var _next_pending_command_sequence_id: int = 1
var _configuration_error: String = ""
var _tick_in_progress: bool = false


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
	if (
		_habitat_config.is_combined_observation()
		and not _has_viable_combined_humidity_loop()
	):
		_configuration_error = (
			"Combined observation humidity loop is not completable"
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

	if _habitat_config.supports_sugar_foraging():
		_foraging_system = ForagingSystem.new(
			_habitat_config.foraging_config,
			_habitat_config
		)
		if not _foraging_system.is_ready():
			_configuration_error = (
				"ColonySimulation could not initialize foraging"
			)
			return
	if _habitat_config.is_nutrition_growth():
		_nutrition_system = NutritionSystem.new(
			_habitat_config.nutrition_config,
			_habitat_config
		)
		if not _nutrition_system.is_ready():
			_configuration_error = (
				"ColonySimulation could not initialize nutrition"
			)
			return

	if not _state.initialize_habitat(
		_habitat_config,
		_brood_care_config,
		_lifecycle_config
	):
		_configuration_error = (
			"ColonySimulation could not initialize habitat state"
		)
		return
	if _habitat_config.is_combined_observation():
		_scenario_director = ScenarioDirector.new(
			_habitat_config.sequence_config,
			_lifecycle_config,
			_brood_care_config,
			_habitat_config
		)
		if not _scenario_director.is_ready():
			_configuration_error = (
				"ColonySimulation could not initialize scenario director"
			)
			return
		_campaign_director = CampaignDirector.new(
			_habitat_config.sequence_config,
			_habitat_config
		)
		if not _campaign_director.is_ready():
			_configuration_error = (
				"ColonySimulation could not initialize campaign director"
			)
			return
		_campaign_director.update_after_systems(_state)
	if not has_valid_habitat_ownership():
		_configuration_error = "Initial habitat ownership is invalid"


func is_ready() -> bool:
	return _configuration_error.is_empty()


func has_habitat() -> bool:
	return _habitat_config != null


func get_configuration_error() -> String:
	return _configuration_error


func can_capture_save_boundary() -> bool:
	return is_ready() and not _tick_in_progress


func submit_water_action() -> bool:
	if not _is_water_action_available():
		return false
	_queue_pending_command(PendingCommandType.WATER_ACTION)
	return true


func submit_place_sugar_action() -> bool:
	if not _is_place_sugar_action_available():
		return false
	_queue_pending_command(PendingCommandType.PLACE_SUGAR_ACTION)
	return true


func submit_place_protein_action() -> bool:
	if not _is_place_protein_action_available():
		return false
	_queue_pending_command(PendingCommandType.PLACE_PROTEIN_ACTION)
	return true


func submit_continue_observation_action() -> bool:
	if not _is_continue_observation_action_available():
		return false
	_queue_pending_command(PendingCommandType.CONTINUE_OBSERVATION_ACTION)
	return true


func submit_campaign_inference_action(inference_id: StringName) -> bool:
	if not _is_campaign_inference_action_available(inference_id):
		return false
	_queue_pending_command(
		PendingCommandType.SELECT_CAMPAIGN_INFERENCE_ACTION,
		inference_id
	)
	return true


func restart_session() -> bool:
	if not is_ready():
		return false

	var initial_state: ColonyState = ColonyState.new()
	if has_habitat():
		if not initial_state.initialize_habitat(
			_habitat_config,
			_brood_care_config,
			_lifecycle_config
		):
			return false
		if not _has_valid_habitat_ownership(initial_state):
			return false

	_state = initial_state
	_pending_commands.clear()
	_next_pending_command_sequence_id = 1
	return true


func advance_tick(tick_index: int) -> bool:
	if (
		not is_ready()
		or _tick_in_progress
		or tick_index != _state.simulation_tick + 1
	):
		return false

	_tick_in_progress = true
	_state.simulation_tick = tick_index
	if not has_habitat():
		_update_existing_ants()
		_try_lay_egg()
		_tick_in_progress = false
		return true

	_apply_pending_commands()
	if _is_lifecycle_active():
		_update_existing_ants()
		_try_lay_egg()
	elif _scenario_director != null:
		var lifecycle_change: Dictionary = (
			_scenario_director.advance_controlled_lifecycle(_state)
		)
		if not lifecycle_change.is_empty():
			life_stage_changed.emit(
				int(lifecycle_change["entity_id"]),
				int(lifecycle_change["previous_stage"]),
				int(lifecycle_change["current_stage"]),
				_state.simulation_tick
			)

	_brood_relocation_system.validate_tasks(_state)
	if _foraging_system != null:
		_foraging_system.validate_tasks(_state)
	if _nutrition_system != null:
		_nutrition_system.validate_tasks(_state)
	var worker_tasks_advance: bool = (
		_nutrition_system == null
		or _nutrition_system.should_advance_worker_tasks(_state)
	)
	if worker_tasks_advance:
		_brood_relocation_system.advance_tasks(_state)
		if _foraging_system != null:
			_foraging_system.advance_tasks(_state)
		if _nutrition_system != null:
			_nutrition_system.advance_tasks(_state)
	if _should_assign_brood_relocation():
		_brood_relocation_system.assign_idle_workers(_state)
	if _should_assign_brood_feeding():
		_nutrition_system.assign_idle_workers(_state)
	if _should_assign_foraging():
		_foraging_system.assign_idle_workers(_state)
	if _should_update_humidity_observation():
		_update_observation_record()
	if _scenario_director != null:
		_scenario_director.update_after_systems(_state)
	if _campaign_director != null:
		_campaign_director.update_after_systems(_state)
	if not has_valid_habitat_ownership():
		_configuration_error = (
			"Habitat ownership invariant failed at Tick %d"
			% _state.simulation_tick
		)
		_tick_in_progress = false
		return false
	_tick_in_progress = false
	return true


func create_snapshot() -> ColonySnapshot:
	var snapshot: ColonySnapshot = ColonySnapshot.new()
	snapshot.simulation_tick = _state.simulation_tick
	snapshot.lifecycle_active = _is_lifecycle_active()
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
		if _supports_humidity_relocation()
		else false
	)
	snapshot.water_action_pending = _has_pending_command(
		PendingCommandType.WATER_ACTION
	)
	snapshot.water_action_count = (
		_state.humidity_adjustment_count
		if _supports_humidity_relocation()
		else 0
	)
	snapshot.water_target_comfortable = _is_water_target_comfortable()
	snapshot.water_action_available = _is_water_action_available()
	snapshot.observation_stable_ticks = (
		_state.observation_stable_ticks
		if _supports_humidity_relocation()
		else 0
	)
	snapshot.brood_humidity_observation_unlocked = (
		_state.brood_humidity_observation_unlocked
		if _supports_humidity_relocation()
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
		var feeding_task_snapshot: BroodFeedingTaskSnapshot
		if ant.feeding_task != null:
			feeding_task_snapshot = ant.feeding_task.create_snapshot()
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
			foraging_task_snapshot,
			ant.protein_supported_growth_ticks,
			feeding_task_snapshot
		))

	return snapshot


func create_game_snapshot() -> GameSnapshot:
	if not is_ready() or not _supports_sugar_foraging():
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
	var sequence_snapshot: ScenarioSequenceSnapshot
	if _scenario_director != null:
		sequence_snapshot = _scenario_director.create_snapshot(
			_state,
			_has_pending_command(
				PendingCommandType.CONTINUE_OBSERVATION_ACTION
			)
		)
	var campaign_snapshot: CampaignSnapshot
	if _campaign_director != null:
		campaign_snapshot = _campaign_director.create_snapshot(
			_state,
			_has_pending_command(
				PendingCommandType.SELECT_CAMPAIGN_INFERENCE_ACTION
			)
			)
	var nutrition_snapshot: NutritionSnapshot
	if _nutrition_system != null and _state.nutrition_state != null:
		var nutrition: ColonyNutritionState = _state.nutrition_state
		nutrition_snapshot = NutritionSnapshot.new()
		nutrition_snapshot.active = true
		nutrition_snapshot.sugar_reserve_portions = (
			nutrition.sugar_reserve_portions
		)
		nutrition_snapshot.protein_reserve_portions = (
			nutrition.protein_reserve_portions
		)
		nutrition_snapshot.sugar_activity_ticks_remaining = (
			nutrition.sugar_activity_ticks_remaining
		)
		nutrition_snapshot.total_sugar_portions_supplied = (
			nutrition.total_sugar_portions_supplied
		)
		nutrition_snapshot.total_protein_portions_supplied = (
			nutrition.total_protein_portions_supplied
		)
		nutrition_snapshot.total_sugar_portions_consumed = (
			nutrition.total_sugar_portions_consumed
		)
		nutrition_snapshot.total_protein_portions_consumed = (
			nutrition.total_protein_portions_consumed
		)
		nutrition_snapshot.total_protein_portions_placed = (
			nutrition.total_protein_portions_placed
		)
		nutrition_snapshot.delivered_protein_portions = (
			nutrition.delivered_protein_portions
		)
		nutrition_snapshot.completed_feeding_count = (
			nutrition.completed_feeding_count
		)
		nutrition_snapshot.active_feeding_count = (
			_nutrition_system.get_active_feeding_count(_state)
		)
		nutrition_snapshot.sugar_shortage = (
			nutrition.sugar_reserve_portions == 0
			and nutrition.sugar_activity_ticks_remaining == 0
		)
		nutrition_snapshot.protein_shortage = (
			nutrition.protein_reserve_portions
			<= nutrition_snapshot.active_feeding_count
		)
		nutrition_snapshot.sugar_action_pending = (
			_has_pending_command(PendingCommandType.PLACE_SUGAR_ACTION)
		)
		nutrition_snapshot.protein_action_pending = (
			_has_pending_command(PendingCommandType.PLACE_PROTEIN_ACTION)
		)
		nutrition_snapshot.sugar_action_available = (
			_is_place_sugar_action_available()
		)
		nutrition_snapshot.protein_action_available = (
			_is_place_protein_action_available()
		)
	return GameSnapshot.new(
		_state.simulation_tick,
		create_snapshot(),
		scenario_snapshot,
		observation_snapshot,
		sequence_snapshot,
		campaign_snapshot,
		nutrition_snapshot
	)


func get_next_egg_tick() -> int:
	if not is_ready():
		return -1
	if has_habitat() and not _is_lifecycle_active():
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
	if (
		_nutrition_system != null
		and not _nutrition_system.has_valid_state(state)
	):
		return false
	if (
		_scenario_director != null
		and not _scenario_director.has_valid_state(state)
	):
		return false
	if (
		_campaign_director != null
		and not _campaign_director.has_valid_state(state)
	):
		return false
	return true


func _apply_pending_commands() -> void:
	var commands_to_apply: Array[PendingSimulationCommand] = _pending_commands
	_pending_commands = []
	for command: PendingSimulationCommand in commands_to_apply:
		match command.command_type:
			PendingCommandType.WATER_ACTION:
				_apply_water_action()
			PendingCommandType.PLACE_SUGAR_ACTION:
				if _foraging_system != null:
					_foraging_system.apply_configured_sugar_placement(
						_state
					)
			PendingCommandType.PLACE_PROTEIN_ACTION:
				if _foraging_system != null:
					_foraging_system.apply_configured_protein_placement(
						_state
					)
			PendingCommandType.CONTINUE_OBSERVATION_ACTION:
				if _scenario_director != null:
					_scenario_director.apply_identity_continue_action(
						_state
					)
			PendingCommandType.SELECT_CAMPAIGN_INFERENCE_ACTION:
				if _campaign_director != null:
					_campaign_director.apply_inference_action(
						_state,
						command.argument_id
					)


func _apply_water_action() -> void:
	if not _supports_humidity_relocation():
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


func _supports_humidity_relocation() -> bool:
	return (
		is_ready()
		and has_habitat()
		and _habitat_config.supports_humidity_relocation()
	)


func _supports_sugar_foraging() -> bool:
	return (
		is_ready()
		and has_habitat()
		and _habitat_config.supports_sugar_foraging()
	)


func _supports_nutrition_growth() -> bool:
	return (
		is_ready()
		and has_habitat()
		and _habitat_config.is_nutrition_growth()
		and _nutrition_system != null
	)


func _is_lifecycle_active() -> bool:
	return (
		is_ready()
		and (
			not has_habitat()
			or _habitat_config.lifecycle_active
		)
	)


func _should_assign_brood_relocation() -> bool:
	if _is_humidity_relocation_scenario():
		return true
	return (
		_scenario_director != null
		and _scenario_director.is_humidity_phase_active(_state)
	)


func _should_assign_foraging() -> bool:
	if _is_sugar_foraging_scenario():
		return _foraging_system != null
	if _supports_nutrition_growth():
		return _foraging_system != null
	return (
		_foraging_system != null
		and _scenario_director != null
		and _scenario_director.is_foraging_phase_active(_state)
	)


func _should_assign_brood_feeding() -> bool:
	return _supports_nutrition_growth()


func _should_update_humidity_observation() -> bool:
	return _should_assign_brood_relocation()


func _is_water_target_comfortable() -> bool:
	if not _supports_humidity_relocation():
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
		not _supports_humidity_relocation()
		or (
			_scenario_director != null
			and not _scenario_director.is_humidity_phase_active(_state)
		)
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
		not _supports_sugar_foraging()
		or _foraging_system == null
		or (
			_scenario_director != null
			and not _scenario_director.is_foraging_phase_active(_state)
		)
		or _has_pending_command(PendingCommandType.PLACE_SUGAR_ACTION)
		or (
			not _supports_nutrition_growth()
			and (
				_state.total_sugar_portions_placed > 0
				or _state.unlocked_observation_card_ids.has(
					_habitat_config.foraging_observation_card_id
				)
			)
		)
		or (
			_supports_nutrition_growth()
			and _foraging_system.has_available_source_type(
				_state,
				FoodSourceState.FoodType.SUGAR_WATER
			)
		)
	):
		return false
	var placement_zone: HabitatZoneState = _state.get_zone(
		_habitat_config.sugar_placement_zone_id
	)
	return placement_zone != null and placement_zone.available


func _is_place_protein_action_available() -> bool:
	if (
		not _supports_nutrition_growth()
		or _foraging_system == null
		or _has_pending_command(PendingCommandType.PLACE_PROTEIN_ACTION)
		or _foraging_system.has_available_source_type(
			_state,
			FoodSourceState.FoodType.PROTEIN
		)
	):
		return false
	var placement_zone: HabitatZoneState = _state.get_zone(
		_habitat_config.protein_placement_zone_id
	)
	return placement_zone != null and placement_zone.available


func _is_continue_observation_action_available() -> bool:
	return (
		is_ready()
		and _scenario_director != null
		and not _has_pending_command(
			PendingCommandType.CONTINUE_OBSERVATION_ACTION
		)
		and _scenario_director.is_identity_continue_available(_state)
	)


func _is_campaign_inference_action_available(
	inference_id: StringName
) -> bool:
	return (
		is_ready()
		and _campaign_director != null
		and not _has_pending_command(
			PendingCommandType.SELECT_CAMPAIGN_INFERENCE_ACTION
		)
		and _campaign_director.is_inference_action_available(
			_state,
			inference_id
		)
	)


func _has_pending_command(command_type: int) -> bool:
	for command: PendingSimulationCommand in _pending_commands:
		if command.command_type == command_type:
			return true
	return false


func _queue_pending_command(
	command_type: PendingCommandType,
	argument_id: StringName = &""
) -> void:
	_pending_commands.append(PendingSimulationCommand.new(
		_next_pending_command_sequence_id,
		command_type,
		argument_id
	))
	_next_pending_command_sequence_id += 1


func _has_viable_combined_humidity_loop() -> bool:
	if _habitat_config == null or _brood_care_config == null:
		return false
	var source_zone: HabitatZoneState
	for zone: HabitatZoneState in _habitat_config.zones:
		if zone.zone_id == _habitat_config.initial_brood_zone_id:
			source_zone = zone
			break
	if source_zone == null or not source_zone.available:
		return false

	var source_penalty: float = _get_brood_humidity_penalty(
		source_zone.humidity
	)
	var best_destination: HabitatZoneState
	var best_penalty: float = INF
	for candidate: HabitatZoneState in _habitat_config.zones:
		if (
			not candidate.available
			or candidate.zone_id == source_zone.zone_id
			or not source_zone.can_reach(candidate.zone_id)
		):
			continue
		var candidate_penalty: float = _get_brood_humidity_penalty(
			candidate.humidity
		)
		if (
			source_penalty - candidate_penalty
			+ HUMIDITY_EPSILON
			< _brood_care_config.relocation_min_improvement
		):
			continue
		if (
			best_destination == null
			or candidate_penalty < best_penalty
			or (
				is_equal_approx(candidate_penalty, best_penalty)
				and String(candidate.zone_id)
					< String(best_destination.zone_id)
			)
		):
			best_destination = candidate
			best_penalty = candidate_penalty
	if best_destination == null:
		return false

	var watered_humidity: float = source_zone.humidity
	var water_action_count: int = 0
	while (
		water_action_count < 4
		and not _is_brood_humidity_comfortable(watered_humidity)
	):
		watered_humidity = clampf(
			watered_humidity + _habitat_config.humidity_adjustment_amount,
			0.0,
			1.0
		)
		water_action_count += 1
	if not _is_brood_humidity_comfortable(watered_humidity):
		return false

	return (
		best_penalty
		+ HUMIDITY_EPSILON
		>= _brood_care_config.relocation_min_improvement
	)


func _get_brood_humidity_penalty(humidity: float) -> float:
	if humidity < _brood_care_config.brood_humidity_min:
		return _brood_care_config.brood_humidity_min - humidity
	if humidity > _brood_care_config.brood_humidity_max:
		return humidity - _brood_care_config.brood_humidity_max
	return 0.0


func _is_brood_humidity_comfortable(humidity: float) -> bool:
	return (
		humidity + HUMIDITY_EPSILON
			>= _brood_care_config.brood_humidity_min
		and humidity - HUMIDITY_EPSILON
			<= _brood_care_config.brood_humidity_max
	)


func _update_existing_ants() -> void:
	for ant: AntModel in _state.ants:
		ant.total_age_ticks += 1
		if (
			_supports_nutrition_growth()
			and ant.life_stage == AntModel.LifeStage.LARVA
		):
			if ant.protein_supported_growth_ticks <= 0:
				continue
			ant.protein_supported_growth_ticks -= 1
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
		ant.protein_supported_growth_ticks = 0
		if (
			_supports_nutrition_growth()
			and ant.life_stage == AntModel.LifeStage.WORKER
		):
			ant.configure_nutrition_worker(
				(
					ant.zone_id
					if not ant.zone_id.is_empty()
					else _habitat_config.nest_zone_id
				),
				_state.simulation_tick
			)
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

	var egg: AntModel
	if _supports_nutrition_growth():
		egg = _state.create_egg(
			_habitat_config.nest_zone_id,
			_state.simulation_tick
		)
	else:
		egg = _state.create_egg()
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
