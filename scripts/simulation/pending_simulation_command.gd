class_name PendingSimulationCommand
extends RefCounted

var sequence_id: int
var command_type: int


func _init(new_sequence_id: int, new_command_type: int) -> void:
	sequence_id = new_sequence_id
	command_type = new_command_type
