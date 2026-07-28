class_name EnvironmentConfig
extends RefCounted

var pollution_diffusion_per_tick: float
var brood_pollution_comfort_max: float
var brood_pollution_penalty_weight: float
var queen_care_light_max: float


static func from_data(data: EnvironmentData) -> EnvironmentConfig:
	if data == null or not data.is_valid():
		return null
	var config: EnvironmentConfig = EnvironmentConfig.new()
	config.pollution_diffusion_per_tick = data.pollution_diffusion_per_tick
	config.brood_pollution_comfort_max = data.brood_pollution_comfort_max
	config.brood_pollution_penalty_weight = (
		data.brood_pollution_penalty_weight
	)
	config.queen_care_light_max = data.queen_care_light_max
	return config
