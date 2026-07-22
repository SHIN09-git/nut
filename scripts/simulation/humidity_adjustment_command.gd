class_name HumidityAdjustmentCommand
extends RefCounted

var zone_id: StringName
var amount: float


func _init(new_zone_id: StringName, new_amount: float) -> void:
	zone_id = new_zone_id
	amount = new_amount
