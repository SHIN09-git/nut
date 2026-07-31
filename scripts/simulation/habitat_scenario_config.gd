class_name HabitatScenarioConfig
extends RefCounted

const SUGAR_PLACEMENT_FEEDING_PORT: StringName = &"feeding_port"
const SUGAR_PLACEMENT_NEAR_NEST: StringName = &"near_nest"

var scenario_id: StringName
var scenario_kind: HabitatScenarioData.ScenarioKind
var zones: Array[HabitatZoneState] = []
var initial_worker_count: int
var initial_brood_count: int
var initial_brood_stage: AntModel.LifeStage
var initial_worker_zone_id: StringName
var initial_brood_zone_id: StringName
var humidity_adjustment_zone_id: StringName
var humidity_adjustment_amount: float
var observation_stable_ticks: int
var foraging_config: ForagingConfig
var nest_zone_id: StringName
var sugar_placement_zone_id: StringName
var sugar_portions: int
var foraging_observation_card_id: StringName
var sequence_config: ScenarioSequenceConfig
var lifecycle_active: bool
var nutrition_config: NutritionConfig
var protein_placement_zone_id: StringName
var protein_portions: int
var founding_care_config: FoundingCareConfig
var facility_catalog_config: FacilityCatalogConfig
var environment_config: EnvironmentConfig
var colony_work_config: ColonyWorkConfig
var act1_progression_config: Act1ProgressionConfig
var initial_zone_connections: Dictionary[StringName, Array] = {}


static func from_data(
	scenario_data: HabitatScenarioData
) -> HabitatScenarioConfig:
	if scenario_data == null or not scenario_data.is_valid():
		return null

	var config: HabitatScenarioConfig = HabitatScenarioConfig.new()
	config.scenario_id = scenario_data.scenario_id
	config.scenario_kind = scenario_data.scenario_kind
	for zone_data: HabitatZoneData in scenario_data.zones:
		var zone_state: HabitatZoneState = HabitatZoneState.from_data(zone_data)
		if zone_state == null:
			return null
		config.zones.append(zone_state)
		var connections: Array[StringName] = []
		connections.assign(zone_data.connected_zone_ids)
		config.initial_zone_connections[zone_data.zone_id] = connections
	config.initial_worker_count = scenario_data.initial_worker_count
	config.initial_brood_count = scenario_data.initial_brood_count
	config.initial_brood_stage = scenario_data.initial_brood_stage
	config.initial_worker_zone_id = scenario_data.initial_worker_zone_id
	config.initial_brood_zone_id = scenario_data.initial_brood_zone_id
	config.humidity_adjustment_zone_id = scenario_data.humidity_adjustment_zone_id
	config.humidity_adjustment_amount = scenario_data.humidity_adjustment_amount
	config.observation_stable_ticks = scenario_data.observation_stable_ticks
	if scenario_data.foraging_data != null:
		config.foraging_config = ForagingConfig.from_data(
			scenario_data.foraging_data
		)
		if config.foraging_config == null:
			return null
	config.nest_zone_id = scenario_data.nest_zone_id
	config.sugar_placement_zone_id = scenario_data.sugar_placement_zone_id
	config.sugar_portions = scenario_data.sugar_portions
	config.foraging_observation_card_id = (
		scenario_data.foraging_observation_card_id
	)
	if scenario_data.sequence_data != null:
		config.sequence_config = ScenarioSequenceConfig.from_data(
			scenario_data.sequence_data
		)
		if config.sequence_config == null:
			return null
	config.lifecycle_active = scenario_data.lifecycle_active
	if scenario_data.nutrition_data != null:
		config.nutrition_config = NutritionConfig.from_data(
			scenario_data.nutrition_data
		)
		if config.nutrition_config == null:
			return null
	config.protein_placement_zone_id = (
		scenario_data.protein_placement_zone_id
	)
	config.protein_portions = scenario_data.protein_portions
	if scenario_data.founding_care_data != null:
		config.founding_care_config = FoundingCareConfig.from_data(
			scenario_data.founding_care_data
		)
		if config.founding_care_config == null:
			return null
	if scenario_data.facility_catalog_data != null:
		config.facility_catalog_config = FacilityCatalogConfig.from_data(
			scenario_data.facility_catalog_data
		)
		if config.facility_catalog_config == null:
			return null
	if scenario_data.environment_data != null:
		config.environment_config = EnvironmentConfig.from_data(
			scenario_data.environment_data
		)
		if config.environment_config == null:
			return null
	if scenario_data.colony_work_data != null:
		config.colony_work_config = ColonyWorkConfig.from_data(
			scenario_data.colony_work_data
		)
		if config.colony_work_config == null:
			return null
	if scenario_data.act1_progression_data != null:
		config.act1_progression_config = Act1ProgressionConfig.from_data(
			scenario_data.act1_progression_data
		)
		if config.act1_progression_config == null:
			return null
	return config


func is_humidity_relocation() -> bool:
	return (
		scenario_kind
		== HabitatScenarioData.ScenarioKind.HUMIDITY_RELOCATION
	)


func is_sugar_foraging() -> bool:
	return (
		scenario_kind
		== HabitatScenarioData.ScenarioKind.SUGAR_FORAGING
	)


func is_combined_observation() -> bool:
	return (
		scenario_kind
		== HabitatScenarioData.ScenarioKind.COMBINED_OBSERVATION
	)


func is_nutrition_growth() -> bool:
	return (
		scenario_kind
		== HabitatScenarioData.ScenarioKind.NUTRITION_GROWTH
	)


func is_act1_test_tube() -> bool:
	return (
		scenario_kind
		== HabitatScenarioData.ScenarioKind.ACT1_TEST_TUBE
	)


func supports_nutrition_growth() -> bool:
	return is_nutrition_growth() or is_act1_test_tube()


func supports_humidity_relocation() -> bool:
	return is_humidity_relocation() or is_combined_observation()


func supports_sugar_foraging() -> bool:
	return (
		is_sugar_foraging()
		or is_combined_observation()
		or is_nutrition_growth()
		or is_act1_test_tube()
	)


func get_sugar_placement_choice_ids() -> Array[StringName]:
	if is_act1_test_tube():
		return [
			SUGAR_PLACEMENT_FEEDING_PORT,
			SUGAR_PLACEMENT_NEAR_NEST,
		]
	return [SUGAR_PLACEMENT_FEEDING_PORT]


func resolve_sugar_placement_zone_id(
	choice_id: StringName
) -> StringName:
	if (
		choice_id.is_empty()
		or choice_id == SUGAR_PLACEMENT_FEEDING_PORT
	):
		return sugar_placement_zone_id
	if (
		is_act1_test_tube()
		and choice_id == SUGAR_PLACEMENT_NEAR_NEST
	):
		return _get_act1_intermediate_zone_id()
	return &""


func get_sugar_placement_choice_id_for_zone(
	zone_id: StringName
) -> StringName:
	if (
		is_act1_test_tube()
		and zone_id == _get_act1_intermediate_zone_id()
	):
		return SUGAR_PLACEMENT_NEAR_NEST
	if zone_id == sugar_placement_zone_id:
		return SUGAR_PLACEMENT_FEEDING_PORT
	return &""


func _get_act1_intermediate_zone_id() -> StringName:
	if not is_act1_test_tube():
		return &""
	for zone: HabitatZoneState in zones:
		if (
			zone.zone_id != nest_zone_id
			and zone.zone_id != sugar_placement_zone_id
		):
			return zone.zone_id
	return &""
