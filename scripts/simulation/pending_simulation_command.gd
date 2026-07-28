class_name PendingSimulationCommand
extends RefCounted

var sequence_id: int
var command_type: int
var argument_id: StringName
var argument_entity_id: int
var argument_slot: Vector2i
var argument_orientation: int
var argument_flag: bool


func _init(
	new_sequence_id: int,
	new_command_type: int,
	new_argument_id: StringName = &"",
	new_argument_entity_id: int = -1,
	new_argument_slot: Vector2i = Vector2i.ZERO,
	new_argument_orientation: int = 0,
	new_argument_flag: bool = false
) -> void:
	sequence_id = new_sequence_id
	command_type = new_command_type
	argument_id = new_argument_id
	argument_entity_id = new_argument_entity_id
	argument_slot = new_argument_slot
	argument_orientation = new_argument_orientation
	argument_flag = new_argument_flag
