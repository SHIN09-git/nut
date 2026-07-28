class_name HydrationFacilityEffectData
extends FacilityEffectData

@export_range(0.0, 1.0, 0.01) var target_humidity: float = 0.66
@export_range(0.00001, 0.1, 0.00001) var humidity_per_tick: float = 0.001


func is_valid() -> bool:
	return (
		is_finite(target_humidity)
		and target_humidity >= 0.0
		and target_humidity <= 1.0
		and is_finite(humidity_per_tick)
		and humidity_per_tick > 0.0
	)
