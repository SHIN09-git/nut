class_name NutritionData
extends Resource

@export var data_status: StringName = &"prototype_pacing_fixture"
@export var scientifically_validated: bool = false
@export_range(0, 100, 1) var initial_sugar_reserve_portions: int = 0
@export_range(0, 100, 1) var initial_protein_reserve_portions: int = 0
@export_range(1, 10_000, 1) var sugar_activity_ticks_per_portion: int = 0
@export_range(1, 100, 1) var sugar_shortage_step_interval_ticks: int = 0
@export_range(1, 10_000, 1) var protein_growth_ticks_per_portion: int = 0
@export_range(1, 100_000, 1) var feeding_decision_interval_ticks: int = 0
@export_range(1, 100_000, 1) var feeding_travel_duration_ticks: int = 0
@export_range(1, 100_000, 1) var feeding_duration_ticks: int = 0


func is_valid() -> bool:
	return (
		not data_status.is_empty()
		and initial_sugar_reserve_portions >= 0
		and initial_protein_reserve_portions >= 0
		and sugar_activity_ticks_per_portion > 0
		and sugar_shortage_step_interval_ticks > 0
		and protein_growth_ticks_per_portion > 0
		and feeding_decision_interval_ticks > 0
		and feeding_travel_duration_ticks > 0
		and feeding_duration_ticks > 0
	)
