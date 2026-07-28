class_name ColonyWorkConfig
extends RefCounted

var waste_source_pollution_min: float
var waste_batch_amount: float
var waste_decision_interval_ticks: int
var waste_travel_ticks_per_connection: int
var waste_pickup_duration_ticks: int
var waste_drop_duration_ticks: int
var scout_decision_interval_ticks: int
var scout_travel_ticks_per_connection: int
var scout_observe_duration_ticks: int
var migration_min_improvement: float
var migration_pollution_max: float
var migration_target_stable_ticks: int
var migration_minimum_zone_dwell_ticks: int
var migration_decision_interval_ticks: int
var migration_travel_ticks_per_connection: int
var migration_pickup_duration_ticks: int
var migration_drop_duration_ticks: int


static func from_data(data: ColonyWorkData) -> ColonyWorkConfig:
	if data == null or not data.is_valid():
		return null
	var config := ColonyWorkConfig.new()
	config.waste_source_pollution_min = data.waste_source_pollution_min
	config.waste_batch_amount = data.waste_batch_amount
	config.waste_decision_interval_ticks = data.waste_decision_interval_ticks
	config.waste_travel_ticks_per_connection = (
		data.waste_travel_ticks_per_connection
	)
	config.waste_pickup_duration_ticks = data.waste_pickup_duration_ticks
	config.waste_drop_duration_ticks = data.waste_drop_duration_ticks
	config.scout_decision_interval_ticks = data.scout_decision_interval_ticks
	config.scout_travel_ticks_per_connection = (
		data.scout_travel_ticks_per_connection
	)
	config.scout_observe_duration_ticks = data.scout_observe_duration_ticks
	config.migration_min_improvement = data.migration_min_improvement
	config.migration_pollution_max = data.migration_pollution_max
	config.migration_target_stable_ticks = data.migration_target_stable_ticks
	config.migration_minimum_zone_dwell_ticks = (
		data.migration_minimum_zone_dwell_ticks
	)
	config.migration_decision_interval_ticks = (
		data.migration_decision_interval_ticks
	)
	config.migration_travel_ticks_per_connection = (
		data.migration_travel_ticks_per_connection
	)
	config.migration_pickup_duration_ticks = (
		data.migration_pickup_duration_ticks
	)
	config.migration_drop_duration_ticks = data.migration_drop_duration_ticks
	return config
