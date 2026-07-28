class_name PendingSimulationCommand
extends RefCounted

var sequence_id: int
var command_type: int
var argument_id: StringName


func _init(
	new_sequence_id: int,
	new_command_type: int,
	new_argument_id: StringName = &""
) -> void:
	sequence_id = new_sequence_id
	command_type = new_command_type
	argument_id = new_argument_id
