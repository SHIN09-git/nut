class_name ForagingScenarioSnapshot
extends RefCounted

enum Phase {
	AWAITING_PLACEMENT,
	ACTIVE,
	COMPLETED,
}

var phase: Phase = Phase.AWAITING_PLACEMENT
var scenario_id: StringName = &""
var nest_zone_id: StringName = &""
var placement_zone_id: StringName = &""
var place_action_available: bool = false
var place_action_pending: bool = false
var place_action_count: int = 0


func _init(
	new_scenario_id: StringName = &"",
	new_nest_zone_id: StringName = &"",
	new_placement_zone_id: StringName = &"",
	new_phase: Phase = Phase.AWAITING_PLACEMENT,
	new_place_action_available: bool = false,
	new_place_action_pending: bool = false,
	new_place_action_count: int = 0
) -> void:
	scenario_id = new_scenario_id
	nest_zone_id = new_nest_zone_id
	placement_zone_id = new_placement_zone_id
	phase = new_phase
	place_action_available = new_place_action_available
	place_action_pending = new_place_action_pending
	place_action_count = new_place_action_count
