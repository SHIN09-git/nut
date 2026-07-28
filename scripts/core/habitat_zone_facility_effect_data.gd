class_name HabitatZoneFacilityEffectData
extends FacilityEffectData

@export_range(0.0, 1.0, 0.01) var initial_humidity: float = 0.5
@export_range(0.0, 1.0, 0.01) var initial_light_exposure: float = 0.5
@export_range(0.0, 1.0, 0.01) var initial_pollution: float = 0.0
@export_range(0.0, 0.01, 0.00001) var pollution_per_tick: float = 0.0


func is_valid() -> bool:
	return (
		is_finite(initial_humidity)
		and initial_humidity >= 0.0
		and initial_humidity <= 1.0
		and is_finite(initial_light_exposure)
		and initial_light_exposure >= 0.0
		and initial_light_exposure <= 1.0
		and is_finite(initial_pollution)
		and initial_pollution >= 0.0
		and initial_pollution <= 1.0
		and is_finite(pollution_per_tick)
		and pollution_per_tick >= 0.0
	)
