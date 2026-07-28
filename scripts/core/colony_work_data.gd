class_name ColonyWorkData
extends Resource

@export var data_status: StringName = &"prototype_pacing_fixture"
@export var scientifically_validated: bool = false

@export_group("Waste cleanup")
@export_range(0.001, 1.0, 0.001) var waste_source_pollution_min: float = 0.08
@export_range(0.001, 1.0, 0.001) var waste_batch_amount: float = 0.04
@export_range(1, 10_000, 1) var waste_decision_interval_ticks: int = 20
@export_range(1, 10_000, 1) var waste_travel_ticks_per_connection: int = 12
@export_range(1, 10_000, 1) var waste_pickup_duration_ticks: int = 8
@export_range(1, 10_000, 1) var waste_drop_duration_ticks: int = 8

@export_group("Scouting")
@export_range(1, 10_000, 1) var scout_decision_interval_ticks: int = 20
@export_range(1, 10_000, 1) var scout_travel_ticks_per_connection: int = 14
@export_range(1, 10_000, 1) var scout_observe_duration_ticks: int = 20

@export_group("Migration")
@export_range(0.001, 3.0, 0.001) var migration_min_improvement: float = 0.18
@export_range(0.0, 1.0, 0.01) var migration_pollution_max: float = 0.20
@export_range(1, 10_000, 1) var migration_target_stable_ticks: int = 30
@export_range(1, 100_000, 1) var migration_minimum_zone_dwell_ticks: int = 60
@export_range(1, 10_000, 1) var migration_decision_interval_ticks: int = 20
@export_range(1, 10_000, 1) var migration_travel_ticks_per_connection: int = 16
@export_range(1, 10_000, 1) var migration_pickup_duration_ticks: int = 8
@export_range(1, 10_000, 1) var migration_drop_duration_ticks: int = 8


func is_valid() -> bool:
	return (
		not data_status.is_empty()
		and is_finite(waste_source_pollution_min)
		and waste_source_pollution_min > 0.0
		and waste_source_pollution_min <= 1.0
		and is_finite(waste_batch_amount)
		and waste_batch_amount > 0.0
		and waste_batch_amount <= 1.0
		and waste_decision_interval_ticks > 0
		and waste_travel_ticks_per_connection > 0
		and waste_pickup_duration_ticks > 0
		and waste_drop_duration_ticks > 0
		and scout_decision_interval_ticks > 0
		and scout_travel_ticks_per_connection > 0
		and scout_observe_duration_ticks > 0
		and is_finite(migration_min_improvement)
		and migration_min_improvement > 0.0
		and is_finite(migration_pollution_max)
		and migration_pollution_max >= 0.0
		and migration_pollution_max <= 1.0
		and migration_target_stable_ticks > 0
		and migration_minimum_zone_dwell_ticks > 0
		and migration_decision_interval_ticks > 0
		and migration_travel_ticks_per_connection > 0
		and migration_pickup_duration_ticks > 0
		and migration_drop_duration_ticks > 0
	)
