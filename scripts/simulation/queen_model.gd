class_name QueenModel
extends RefCounted

var entity_id: int
var laid_egg_count: int = 0
var zone_id: StringName = &""
var zone_entered_tick: int = 0


func _init(new_entity_id: int) -> void:
	entity_id = new_entity_id


func assign_zone(new_zone_id: StringName, tick: int) -> void:
	zone_id = new_zone_id
	zone_entered_tick = tick
