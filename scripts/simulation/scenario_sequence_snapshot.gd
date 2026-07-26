class_name ScenarioSequenceSnapshot
extends RefCounted

enum Phase {
	FOUNDING_PRELUDE,
	IDENTITY_OBSERVATION,
	HUMIDITY_OBSERVATION,
	SUGAR_FORAGING,
	OBSERVATION_SUMMARY,
}

var scenario_id: StringName = &""
var phase: Phase = Phase.FOUNDING_PRELUDE
var phase_entered_tick: int = 0
var first_worker_entity_id: int = -1
var first_worker_emerged_tick: int = -1
var humidity_observation_completed_tick: int = -1
var sugar_observation_completed_tick: int = -1
var first_worker_observation_card_id: StringName = &""
var brood_humidity_observation_card_id: StringName = &""
var sugar_foraging_observation_card_id: StringName = &""
var continue_action_available: bool = false
var continue_action_pending: bool = false
var completed: bool = false


func _init(
	new_scenario_id: StringName = &"",
	new_phase: Phase = Phase.FOUNDING_PRELUDE,
	new_phase_entered_tick: int = 0,
	new_first_worker_entity_id: int = -1,
	new_first_worker_emerged_tick: int = -1,
	new_humidity_observation_completed_tick: int = -1,
	new_sugar_observation_completed_tick: int = -1,
	new_first_worker_observation_card_id: StringName = &"",
	new_brood_humidity_observation_card_id: StringName = &"",
	new_sugar_foraging_observation_card_id: StringName = &"",
	new_continue_action_available: bool = false,
	new_continue_action_pending: bool = false
) -> void:
	scenario_id = new_scenario_id
	phase = new_phase
	phase_entered_tick = new_phase_entered_tick
	first_worker_entity_id = new_first_worker_entity_id
	first_worker_emerged_tick = new_first_worker_emerged_tick
	humidity_observation_completed_tick = (
		new_humidity_observation_completed_tick
	)
	sugar_observation_completed_tick = new_sugar_observation_completed_tick
	first_worker_observation_card_id = new_first_worker_observation_card_id
	brood_humidity_observation_card_id = (
		new_brood_humidity_observation_card_id
	)
	sugar_foraging_observation_card_id = (
		new_sugar_foraging_observation_card_id
	)
	continue_action_available = new_continue_action_available
	continue_action_pending = new_continue_action_pending
	completed = phase == Phase.OBSERVATION_SUMMARY
