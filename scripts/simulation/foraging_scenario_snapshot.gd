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
var available_placement_choice_ids: Array[StringName] = []
var selected_placement_choice_id: StringName = &""


func _init(
	new_scenario_id: StringName = &"",
	new_nest_zone_id: StringName = &"",
	new_placement_zone_id: StringName = &"",
	new_phase: Phase = Phase.AWAITING_PLACEMENT,
	new_place_action_available: bool = false,
	new_place_action_pending: bool = false,
	new_place_action_count: int = 0,
	new_available_placement_choice_ids: Array[StringName] = [],
	new_selected_placement_choice_id: StringName = &""
) -> void:
	scenario_id = new_scenario_id
	nest_zone_id = new_nest_zone_id
	placement_zone_id = new_placement_zone_id
	phase = new_phase
	place_action_available = new_place_action_available
	place_action_pending = new_place_action_pending
	place_action_count = new_place_action_count
	available_placement_choice_ids.assign(
		new_available_placement_choice_ids
	)
	selected_placement_choice_id = new_selected_placement_choice_id
