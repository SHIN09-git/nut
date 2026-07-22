class_name SpeciesData
extends Resource

const MIN_MEANINGFUL_IMPROVEMENT: float = 0.000001

@export var species_id: StringName = &""
@export var display_name: String = ""
@export var data_status: StringName = &"prototype_pacing_fixture"
@export var scientifically_validated: bool = false
@export_range(1, 100_000, 1) var first_egg_delay_ticks: int = 0
@export_range(1, 100_000, 1) var egg_laying_interval_ticks: int = 0
@export_range(1, 100_000, 1) var egg_duration_ticks: int = 0
@export_range(1, 100_000, 1) var larva_duration_ticks: int = 0
@export_range(1, 100_000, 1) var pupa_duration_ticks: int = 0
@export_range(1, 100, 1) var max_first_generation_brood: int = 0
@export_range(0.0, 1.0, 0.01) var brood_humidity_min: float = 0.0
@export_range(0.0, 1.0, 0.01) var brood_humidity_max: float = 0.0
@export_range(0.001, 1.0, 0.001) var relocation_min_improvement: float = 0.0
@export_range(1, 100_000, 1) var decision_interval_ticks: int = 0
@export_range(1, 100_000, 1) var pickup_duration_ticks: int = 0
@export_range(1, 100_000, 1) var travel_duration_ticks: int = 0
@export_range(1, 100_000, 1) var drop_duration_ticks: int = 0
@export_range(0, 100_000, 1) var minimum_zone_dwell_ticks: int = 0


func is_valid() -> bool:
	return is_lifecycle_valid() and is_brood_care_valid()


func is_lifecycle_valid() -> bool:
	return (
		not species_id.is_empty()
		and first_egg_delay_ticks > 0
		and egg_laying_interval_ticks > 0
		and egg_duration_ticks > 0
		and larva_duration_ticks > 0
		and pupa_duration_ticks > 0
		and max_first_generation_brood > 0
	)


func is_brood_care_valid() -> bool:
	return (
		not is_nan(brood_humidity_min)
		and not is_inf(brood_humidity_min)
		and not is_nan(brood_humidity_max)
		and not is_inf(brood_humidity_max)
		and brood_humidity_min >= 0.0
		and brood_humidity_min <= brood_humidity_max
		and brood_humidity_max <= 1.0
		and not is_nan(relocation_min_improvement)
		and not is_inf(relocation_min_improvement)
		and relocation_min_improvement > MIN_MEANINGFUL_IMPROVEMENT
		and decision_interval_ticks > 0
		and pickup_duration_ticks > 0
		and travel_duration_ticks > 0
		and drop_duration_ticks > 0
		and minimum_zone_dwell_ticks >= 0
	)
