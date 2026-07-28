class_name WasteTrayFacilityEffectData
extends FacilityEffectData

@export_range(0.01, 10.0, 0.01) var capacity: float = 1.0
@export_range(0.00001, 0.1, 0.00001) var capture_per_tick: float = 0.001


func is_valid() -> bool:
	return (
		is_finite(capacity)
		and capacity > 0.0
		and is_finite(capture_per_tick)
		and capture_per_tick > 0.0
	)
