class_name GameSnapshot
extends RefCounted

var simulation_tick: int = 0
var colony: ColonySnapshot
var scenario: ForagingScenarioSnapshot
var observations: ObservationJournalSnapshot
var sequence: ScenarioSequenceSnapshot


func _init(
	new_simulation_tick: int = 0,
	new_colony: ColonySnapshot = null,
	new_scenario: ForagingScenarioSnapshot = null,
	new_observations: ObservationJournalSnapshot = null,
	new_sequence: ScenarioSequenceSnapshot = null
) -> void:
	simulation_tick = new_simulation_tick
	colony = new_colony
	scenario = new_scenario
	observations = new_observations
	sequence = new_sequence
