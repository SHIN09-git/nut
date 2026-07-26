class_name ScenarioProgressState
extends RefCounted

var phase: ScenarioSequenceSnapshot.Phase = (
	ScenarioSequenceSnapshot.Phase.FOUNDING_PRELUDE
)
var phase_entered_tick: int = 0
var first_worker_entity_id: int = -1
var first_worker_emerged_tick: int = -1
var humidity_observation_completed_tick: int = -1
var sugar_observation_completed_tick: int = -1


func advance_to(
	next_phase: ScenarioSequenceSnapshot.Phase,
	simulation_tick: int
) -> bool:
	if int(next_phase) != int(phase) + 1 or simulation_tick < phase_entered_tick:
		return false
	phase = next_phase
	phase_entered_tick = simulation_tick
	return true
