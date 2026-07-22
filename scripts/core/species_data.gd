class_name SpeciesData
extends Resource

@export var species_id: StringName = &"species_a"
@export var display_name: String = "Species A"
@export var data_status: StringName = &"prototype_pacing_fixture"
@export var scientifically_validated: bool = false
@export_range(1, 100_000, 1) var first_egg_delay_ticks: int = 1200
@export_range(1, 100_000, 1) var egg_laying_interval_ticks: int = 300
@export_range(1, 100_000, 1) var egg_duration_ticks: int = 800
@export_range(1, 100_000, 1) var larva_duration_ticks: int = 1000
@export_range(1, 100_000, 1) var pupa_duration_ticks: int = 1000
@export_range(1, 100, 1) var max_first_generation_brood: int = 3


func is_valid() -> bool:
	return (
		not species_id.is_empty()
		and first_egg_delay_ticks > 0
		and egg_laying_interval_ticks > 0
		and egg_duration_ticks > 0
		and larva_duration_ticks > 0
		and pupa_duration_ticks > 0
		and max_first_generation_brood > 0
	)
