class_name Act1ProgressionData
extends Resource

@export var data_status: StringName = &"prototype_pacing_fixture"
@export var scientifically_validated: bool = false
@export_range(1, 20, 1) var chapter_three_min_worker_count: int = 3
@export_range(0.0, 1.0, 0.01) var pollution_avoidance_min_contrast: float = 0.08
@export_range(1, 10_000, 1) var environment_stable_ticks: int = 30
@export_range(1, 10_000, 1) var core_migration_stable_ticks: int = 40
@export_range(1, 10_000, 1) var finale_stable_ticks: int = 40
@export var final_report_observation_card_id: StringName = (
	&"glass_observation_report"
)


func is_valid() -> bool:
	return (
		data_status == &"prototype_pacing_fixture"
		and not scientifically_validated
		and chapter_three_min_worker_count > 0
		and is_finite(pollution_avoidance_min_contrast)
		and pollution_avoidance_min_contrast > 0.0
		and pollution_avoidance_min_contrast <= 1.0
		and environment_stable_ticks > 0
		and core_migration_stable_ticks > 0
		and finale_stable_ticks > 0
		and not final_report_observation_card_id.is_empty()
	)
