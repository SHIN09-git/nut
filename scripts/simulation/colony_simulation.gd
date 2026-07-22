class_name ColonySimulation
extends RefCounted

signal egg_laid(entity_id: int, simulation_tick: int)
signal life_stage_changed(
	entity_id: int,
	previous_stage: AntModel.LifeStage,
	current_stage: AntModel.LifeStage,
	simulation_tick: int
)

var _lifecycle_config: LifecycleConfig
var _state: ColonyState
var _configuration_error: String = ""


func _init(species_data: SpeciesData) -> void:
	_state = ColonyState.new()
	_lifecycle_config = LifecycleConfig.from_species_data(species_data)
	if _lifecycle_config == null:
		_configuration_error = (
			"ColonySimulation requires valid, positive lifecycle SpeciesData"
		)


func is_ready() -> bool:
	return _configuration_error.is_empty()


func get_configuration_error() -> String:
	return _configuration_error


func advance_tick(tick_index: int) -> bool:
	if not is_ready() or tick_index != _state.simulation_tick + 1:
		return false

	_state.simulation_tick = tick_index
	_update_existing_ants()
	_try_lay_egg()
	return true


func create_snapshot() -> ColonySnapshot:
	var snapshot: ColonySnapshot = ColonySnapshot.new()
	snapshot.simulation_tick = _state.simulation_tick
	snapshot.queen_entity_id = _state.queen.entity_id
	snapshot.queen_laid_egg_count = _state.queen.laid_egg_count
	snapshot.max_first_generation_brood = (
		_lifecycle_config.max_first_generation_brood
		if is_ready()
		else 0
	)
	snapshot.next_egg_tick = get_next_egg_tick()

	for ant: AntModel in _state.ants:
		snapshot.ants.append(AntSnapshot.new(
			ant.entity_id,
			ant.life_stage,
			ant.total_age_ticks,
			ant.stage_age_ticks,
			get_stage_duration_ticks(ant.life_stage)
		))

	return snapshot


func get_next_egg_tick() -> int:
	if not is_ready():
		return -1
	if _state.queen.laid_egg_count >= _lifecycle_config.max_first_generation_brood:
		return -1
	return (
		_lifecycle_config.first_egg_delay_ticks
		+ _state.queen.laid_egg_count * _lifecycle_config.egg_laying_interval_ticks
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
