class_name FacilityEffectConfig
extends RefCounted

enum Kind {
	HABITAT_ZONE,
	HYDRATION,
	FOOD_STATION,
	WASTE_TRAY,
	CONNECTOR,
	LIGHT_COVER,
}

var kind: Kind
var initial_humidity: float = 0.5
var initial_light_exposure: float = 0.5
var initial_pollution: float = 0.0
var pollution_per_tick: float = 0.0
var target_humidity: float = 0.5
var humidity_per_tick: float = 0.0
var accepts_sugar: bool = false
var accepts_protein: bool = false
var portion_capacity: int = 0
var host_zone_required: bool = false
var waste_capacity: float = 0.0
var waste_capture_per_tick: float = 0.0
var connector_gated: bool = false
var target_light_exposure: float = 0.5
var light_transition_per_tick: float = 0.0


static func from_data(data: FacilityEffectData) -> FacilityEffectConfig:
	if data == null or not data.is_valid():
		return null
	var config: FacilityEffectConfig = FacilityEffectConfig.new()
	if data is HabitatZoneFacilityEffectData:
		var zone_data: HabitatZoneFacilityEffectData = data
		config.kind = Kind.HABITAT_ZONE
		config.initial_humidity = zone_data.initial_humidity
		config.initial_light_exposure = zone_data.initial_light_exposure
		config.initial_pollution = zone_data.initial_pollution
		config.pollution_per_tick = zone_data.pollution_per_tick
	elif data is HydrationFacilityEffectData:
		var hydration_data: HydrationFacilityEffectData = data
		config.kind = Kind.HYDRATION
		config.target_humidity = hydration_data.target_humidity
		config.humidity_per_tick = hydration_data.humidity_per_tick
		config.host_zone_required = true
	elif data is FoodStationFacilityEffectData:
		var food_data: FoodStationFacilityEffectData = data
		config.kind = Kind.FOOD_STATION
		config.accepts_sugar = food_data.accepts_sugar
		config.accepts_protein = food_data.accepts_protein
		config.portion_capacity = food_data.portion_capacity
		config.host_zone_required = food_data.host_zone_required
	elif data is WasteTrayFacilityEffectData:
		var waste_data: WasteTrayFacilityEffectData = data
		config.kind = Kind.WASTE_TRAY
		config.waste_capacity = waste_data.capacity
		config.waste_capture_per_tick = waste_data.capture_per_tick
		config.host_zone_required = true
	elif data is ConnectorFacilityEffectData:
		var connector_data: ConnectorFacilityEffectData = data
		config.kind = Kind.CONNECTOR
		config.connector_gated = connector_data.gated
	elif data is LightCoverFacilityEffectData:
		var cover_data: LightCoverFacilityEffectData = data
		config.kind = Kind.LIGHT_COVER
		config.target_light_exposure = cover_data.target_light_exposure
		config.light_transition_per_tick = cover_data.transition_per_tick
		config.host_zone_required = true
	else:
		return null
	return config


func provides_zone() -> bool:
	return kind == Kind.HABITAT_ZONE


func requires_host_zone() -> bool:
	return host_zone_required
