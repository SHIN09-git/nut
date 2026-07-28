class_name ColonyNutritionState
extends RefCounted

var sugar_reserve_portions: int = 0
var protein_reserve_portions: int = 0
var sugar_activity_ticks_remaining: int = 0
var total_sugar_portions_supplied: int = 0
var total_protein_portions_supplied: int = 0
var total_sugar_portions_consumed: int = 0
var total_protein_portions_consumed: int = 0
var total_protein_portions_placed: int = 0
var delivered_protein_portions: int = 0
var completed_feeding_count: int = 0


func _init(
	initial_sugar_reserve: int = 0,
	initial_protein_reserve: int = 0
) -> void:
	sugar_reserve_portions = maxi(initial_sugar_reserve, 0)
	protein_reserve_portions = maxi(initial_protein_reserve, 0)
	total_sugar_portions_supplied = sugar_reserve_portions
	total_protein_portions_supplied = protein_reserve_portions
