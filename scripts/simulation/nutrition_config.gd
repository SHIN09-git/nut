class_name NutritionConfig
extends RefCounted

var initial_sugar_reserve_portions: int
var initial_protein_reserve_portions: int
var sugar_activity_ticks_per_portion: int
var sugar_shortage_step_interval_ticks: int
var protein_growth_ticks_per_portion: int
var feeding_decision_interval_ticks: int
var feeding_travel_duration_ticks: int
var feeding_duration_ticks: int


static func from_data(data: NutritionData) -> NutritionConfig:
	if data == null or not data.is_valid():
		return null

	var config: NutritionConfig = NutritionConfig.new()
	config.initial_sugar_reserve_portions = (
		data.initial_sugar_reserve_portions
	)
	config.initial_protein_reserve_portions = (
		data.initial_protein_reserve_portions
	)
	config.sugar_activity_ticks_per_portion = (
		data.sugar_activity_ticks_per_portion
	)
	config.sugar_shortage_step_interval_ticks = (
		data.sugar_shortage_step_interval_ticks
	)
	config.protein_growth_ticks_per_portion = (
		data.protein_growth_ticks_per_portion
	)
	config.feeding_decision_interval_ticks = (
		data.feeding_decision_interval_ticks
	)
	config.feeding_travel_duration_ticks = (
		data.feeding_travel_duration_ticks
	)
	config.feeding_duration_ticks = data.feeding_duration_ticks
	return config
