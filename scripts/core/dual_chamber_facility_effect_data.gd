class_name DualChamberFacilityEffectData
extends FacilityEffectData

@export_range(0.0, 1.0, 0.01) var brood_initial_humidity: float = 0.48
@export_range(0.0, 1.0, 0.01) var brood_initial_light_exposure: float = 0.24
@export_range(0.0, 1.0, 0.01) var brood_initial_pollution: float = 0.0
@export_range(0.0, 0.01, 0.00001) var brood_pollution_per_tick: float = 0.0
@export_range(0.0, 1.0, 0.01) var utility_initial_humidity: float = 0.42
@export_range(0.0, 1.0, 0.01) var utility_initial_light_exposure: float = 0.38
@export_range(0.0, 1.0, 0.01) var utility_initial_pollution: float = 0.0
@export_range(0.0, 0.01, 0.00001) var utility_pollution_per_tick: float = 0.0


func is_valid() -> bool:
	for value: float in [
		brood_initial_humidity,
		brood_initial_light_exposure,
		brood_initial_pollution,
		utility_initial_humidity,
		utility_initial_light_exposure,
		utility_initial_pollution,
	]:
		if not is_finite(value) or value < 0.0 or value > 1.0:
			return false
	return (
		is_finite(brood_pollution_per_tick)
		and brood_pollution_per_tick >= 0.0
		and is_finite(utility_pollution_per_tick)
		and utility_pollution_per_tick >= 0.0
	)
