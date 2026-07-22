class_name ColonyState
extends RefCounted

const QUEEN_ENTITY_ID: int = 0

var simulation_tick: int = 0
var queen: QueenModel
var ants: Array[AntModel] = []
var zones: Array[HabitatZoneState] = []
var humidity_adjustment_count: int = 0
var observation_stable_ticks: int = 0
var brood_humidity_observation_unlocked: bool = false
var _next_entity_id: int = 1


func _init() -> void:
	queen = QueenModel.new(QUEEN_ENTITY_ID)


func create_egg() -> AntModel:
	var egg: AntModel = AntModel.new(_next_entity_id, AntModel.LifeStage.EGG)
	_next_entity_id += 1
	ants.append(egg)
	queen.laid_egg_count += 1
	return egg


func initialize_habitat(
	config: HabitatScenarioConfig,
	brood_care_config: BroodCareConfig
) -> bool:
	if config == null or brood_care_config == null or not ants.is_empty():
		return false

	for zone: HabitatZoneState in config.zones:
		zones.append(zone.duplicate_state())

	for worker_index: int in config.initial_worker_count:
		var worker: AntModel = AntModel.new(
			_next_entity_id,
			AntModel.LifeStage.WORKER
		)
		_next_entity_id += 1
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

	queen.laid_egg_count = config.initial_brood_count
	return true


func get_ant(entity_id: int) -> AntModel:
	for ant: AntModel in ants:
		if ant.entity_id == entity_id:
			return ant
	return null


func get_zone(zone_id: StringName) -> HabitatZoneState:
	for zone: HabitatZoneState in zones:
		if zone.zone_id == zone_id:
			return zone
	return null
