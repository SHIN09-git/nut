class_name BroodCareConfig
extends RefCounted

var brood_humidity_min: float
var brood_humidity_max: float
var relocation_min_improvement: float
var decision_interval_ticks: int
var pickup_duration_ticks: int
var travel_duration_ticks: int
var drop_duration_ticks: int
var minimum_zone_dwell_ticks: int


static func from_species_data(species_data: SpeciesData) -> BroodCareConfig:
	if species_data == null or not species_data.is_brood_care_valid():
		return null

	var config: BroodCareConfig = BroodCareConfig.new()
	config.brood_humidity_min = species_data.brood_humidity_min
	config.brood_humidity_max = species_data.brood_humidity_max
	config.relocation_min_improvement = species_data.relocation_min_improvement
	config.decision_interval_ticks = species_data.decision_interval_ticks
	config.pickup_duration_ticks = species_data.pickup_duration_ticks
	config.travel_duration_ticks = species_data.travel_duration_ticks
	config.drop_duration_ticks = species_data.drop_duration_ticks
	config.minimum_zone_dwell_ticks = species_data.minimum_zone_dwell_ticks
	return config
