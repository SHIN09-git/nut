class_name ColonyState
extends RefCounted

const QUEEN_ENTITY_ID: int = 0
const MAX_RETAINED_OBSERVATION_EVENTS: int = 64

var simulation_tick: int = 0
var queen: QueenModel
var ants: Array[AntModel] = []
var zones: Array[HabitatZoneState] = []
var food_sources: Array[FoodSourceState] = []
var humidity_adjustment_count: int = 0
var water_action_unlocked: bool = false
var observation_stable_ticks: int = 0
var brood_humidity_observation_unlocked: bool = false
var shared_sugar_portions: int = 0
var total_sugar_portions_placed: int = 0
var unlocked_observation_card_ids: Dictionary[StringName, bool] = {}
var scenario_progress: ScenarioProgressState
var campaign_state: CampaignState
var _next_entity_id: int = 1
var _next_observation_event_id: int = 1
var _observation_events: Array[ObservationEvent] = []


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
	brood_care_config: BroodCareConfig,
	lifecycle_config: LifecycleConfig = null
) -> bool:
	if config == null or brood_care_config == null or not ants.is_empty():
		return false

	for zone: HabitatZoneState in config.zones:
		zones.append(zone.duplicate_state())

	if config.is_combined_observation():
		if (
			lifecycle_config == null
			or config.sequence_config == null
			or (
				config.sequence_config.first_worker_initial_pupa_age_ticks
				>= lifecycle_config.pupa_duration_ticks
			)
		):
			return false
		var first_worker_pupa: AntModel = AntModel.new(
			_next_entity_id,
			AntModel.LifeStage.PUPA
		)
		_next_entity_id += 1
		first_worker_pupa.configure_brood(
			config.initial_brood_zone_id,
			-brood_care_config.minimum_zone_dwell_ticks
		)
		first_worker_pupa.stage_age_ticks = (
			config.sequence_config.first_worker_initial_pupa_age_ticks
		)
		first_worker_pupa.total_age_ticks = first_worker_pupa.stage_age_ticks
		ants.append(first_worker_pupa)
		scenario_progress = ScenarioProgressState.new()
		scenario_progress.first_worker_entity_id = (
			first_worker_pupa.entity_id
		)
		campaign_state = CampaignState.new()

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


func create_food_source(
	zone_id: StringName,
	portion_count: int,
	food_type: FoodSourceState.FoodType
) -> FoodSourceState:
	if get_zone(zone_id) == null or portion_count <= 0:
		return null
	var source: FoodSourceState = FoodSourceState.new(
		_next_entity_id,
		zone_id,
		portion_count,
		food_type
	)
	_next_entity_id += 1
	food_sources.append(source)
	return source


func get_food_source(food_source_id: int) -> FoodSourceState:
	for source: FoodSourceState in food_sources:
		if source.entity_id == food_source_id:
			return source
	return null


func remove_food_source(food_source_id: int) -> bool:
	var source: FoodSourceState = get_food_source(food_source_id)
	if source == null or not source.available:
		return false
	# Keep a tombstone so removal cannot silently erase conserved portions.
	source.available = false
	return true


func copy_unlocked_observation_card_ids() -> Array[StringName]:
	var card_ids: Array[StringName] = []
	for card_id: StringName in unlocked_observation_card_ids:
		card_ids.append(card_id)
	card_ids.sort_custom(
		func(first: StringName, second: StringName) -> bool:
			return String(first) < String(second)
	)
	return card_ids


func record_observation_event(
	event_type: ObservationEvent.Type,
	actor_entity_id: int = ObservationEvent.NO_ENTITY_ID,
	subject_entity_id: int = ObservationEvent.NO_ENTITY_ID,
	source_zone_id: StringName = &"",
	target_zone_id: StringName = &""
) -> void:
	var event: ObservationEvent = ObservationEvent.new(
		_next_observation_event_id,
		simulation_tick,
		event_type,
		actor_entity_id,
		subject_entity_id,
		source_zone_id,
		target_zone_id
	)
	_next_observation_event_id += 1
	_observation_events.append(event)
	if _observation_events.size() > MAX_RETAINED_OBSERVATION_EVENTS:
		_observation_events.pop_front()


func copy_observation_events() -> Array[ObservationEvent]:
	var copied_events: Array[ObservationEvent] = []
	for event: ObservationEvent in _observation_events:
		copied_events.append(event.copy_event())
	return copied_events
