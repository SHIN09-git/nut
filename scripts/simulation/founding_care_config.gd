class_name FoundingCareConfig
extends RefCounted

var rest_duration_ticks: int
var gathering_duration_ticks: int
var brood_care_duration_ticks: int
var pupa_observation_ticks: int
var first_worker_initial_pupa_age_ticks: int
var queen_care_observation_card_id: StringName
var pupa_observation_card_id: StringName
var first_worker_observation_card_id: StringName
var worker_care_observation_card_id: StringName


static func from_data(data: FoundingCareData) -> FoundingCareConfig:
	if data == null or not data.is_valid():
		return null
	var config: FoundingCareConfig = FoundingCareConfig.new()
	config.rest_duration_ticks = data.rest_duration_ticks
	config.gathering_duration_ticks = data.gathering_duration_ticks
	config.brood_care_duration_ticks = data.brood_care_duration_ticks
	config.pupa_observation_ticks = data.pupa_observation_ticks
	config.first_worker_initial_pupa_age_ticks = (
		data.first_worker_initial_pupa_age_ticks
	)
	config.queen_care_observation_card_id = (
		data.queen_care_observation_card_id
	)
	config.pupa_observation_card_id = data.pupa_observation_card_id
	config.first_worker_observation_card_id = (
		data.first_worker_observation_card_id
	)
	config.worker_care_observation_card_id = (
		data.worker_care_observation_card_id
	)
	return config
