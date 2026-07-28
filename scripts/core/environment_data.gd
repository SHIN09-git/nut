class_name EnvironmentData
extends Resource

@export var data_status: StringName = &"prototype_pacing_fixture"
@export var scientifically_validated: bool = false
@export_range(0.0, 0.1, 0.00001) var pollution_diffusion_per_tick: float = 0.002
@export_range(0.0, 1.0, 0.01) var brood_pollution_comfort_max: float = 0.30
@export_range(0.0, 10.0, 0.01) var brood_pollution_penalty_weight: float = 1.0
@export_range(0.0, 1.0, 0.01) var queen_care_light_max: float = 0.25


func is_valid() -> bool:
	return (
		not data_status.is_empty()
		and is_finite(pollution_diffusion_per_tick)
		and pollution_diffusion_per_tick >= 0.0
		and pollution_diffusion_per_tick <= 0.1
		and is_finite(brood_pollution_comfort_max)
		and brood_pollution_comfort_max >= 0.0
		and brood_pollution_comfort_max <= 1.0
		and is_finite(brood_pollution_penalty_weight)
		and brood_pollution_penalty_weight >= 0.0
		and is_finite(queen_care_light_max)
		and queen_care_light_max >= 0.0
		and queen_care_light_max <= 1.0
	)
