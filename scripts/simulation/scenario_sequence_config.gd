class_name ScenarioSequenceConfig
extends RefCounted

var first_worker_initial_pupa_age_ticks: int
var first_worker_observation_card_id: StringName
var brood_humidity_observation_card_id: StringName


static func from_data(
	sequence_data: ScenarioSequenceData
) -> ScenarioSequenceConfig:
	if sequence_data == null or not sequence_data.is_valid():
		return null

	var config: ScenarioSequenceConfig = ScenarioSequenceConfig.new()
	config.first_worker_initial_pupa_age_ticks = (
		sequence_data.first_worker_initial_pupa_age_ticks
	)
	config.first_worker_observation_card_id = (
		sequence_data.first_worker_observation_card_id
	)
	config.brood_humidity_observation_card_id = (
		sequence_data.brood_humidity_observation_card_id
	)
	return config
