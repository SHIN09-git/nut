class_name Act1ProgressionConfig
extends RefCounted

var chapter_three_min_worker_count: int
var pollution_avoidance_min_contrast: float
var environment_stable_ticks: int
var core_migration_stable_ticks: int


static func from_data(data: Act1ProgressionData) -> Act1ProgressionConfig:
	if data == null or not data.is_valid():
		return null
	var config := Act1ProgressionConfig.new()
	config.chapter_three_min_worker_count = (
		data.chapter_three_min_worker_count
	)
	config.pollution_avoidance_min_contrast = (
		data.pollution_avoidance_min_contrast
	)
	config.environment_stable_ticks = data.environment_stable_ticks
	config.core_migration_stable_ticks = data.core_migration_stable_ticks
	return config
