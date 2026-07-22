class_name LifecycleConfig
extends RefCounted

var first_egg_delay_ticks: int
var egg_laying_interval_ticks: int
var egg_duration_ticks: int
var larva_duration_ticks: int
var pupa_duration_ticks: int
var max_first_generation_brood: int


static func from_species_data(species_data: SpeciesData) -> LifecycleConfig:
	if species_data == null or not species_data.is_valid():
		return null

	var config: LifecycleConfig = LifecycleConfig.new()
	config.first_egg_delay_ticks = species_data.first_egg_delay_ticks
	config.egg_laying_interval_ticks = species_data.egg_laying_interval_ticks
	config.egg_duration_ticks = species_data.egg_duration_ticks
	config.larva_duration_ticks = species_data.larva_duration_ticks
	config.pupa_duration_ticks = species_data.pupa_duration_ticks
	config.max_first_generation_brood = species_data.max_first_generation_brood
	return config
