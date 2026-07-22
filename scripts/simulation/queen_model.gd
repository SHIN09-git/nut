class_name QueenModel
extends RefCounted

var entity_id: int
var laid_egg_count: int = 0


func _init(new_entity_id: int) -> void:
	entity_id = new_entity_id
