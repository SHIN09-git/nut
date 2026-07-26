class_name ForagingData
extends Resource

@export var data_status: StringName = &"prototype_pacing_fixture"
@export var scientifically_validated: bool = false
@export_range(1, 100_000, 1) var discovery_delay_ticks: int = 0
@export_range(1, 100_000, 1) var outbound_travel_duration_ticks: int = 0
@export_range(1, 100_000, 1) var collection_duration_ticks: int = 0
@export_range(1, 100_000, 1) var return_travel_duration_ticks: int = 0
@export_range(1, 100_000, 1) var sharing_duration_ticks: int = 0


func is_valid() -> bool:
	return (
		not data_status.is_empty()
		and discovery_delay_ticks > 0
		and outbound_travel_duration_ticks > 0
		and collection_duration_ticks > 0
		and return_travel_duration_ticks > 0
		and sharing_duration_ticks > 0
	)
