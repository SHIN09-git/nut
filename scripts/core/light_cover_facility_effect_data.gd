class_name LightCoverFacilityEffectData
extends FacilityEffectData

@export_range(0.0, 1.0, 0.01) var target_light_exposure: float = 0.12
@export_range(0.00001, 1.0, 0.00001) var transition_per_tick: float = 0.2


func is_valid() -> bool:
	return (
		is_finite(target_light_exposure)
		and target_light_exposure >= 0.0
		and target_light_exposure <= 1.0
		and is_finite(transition_per_tick)
		and transition_per_tick > 0.0
	)
