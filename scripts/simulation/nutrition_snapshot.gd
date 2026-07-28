class_name NutritionSnapshot
extends RefCounted

var active: bool = false
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
var active_feeding_count: int = 0
var sugar_shortage: bool = false
var protein_shortage: bool = false
var sugar_action_available: bool = false
var sugar_action_pending: bool = false
var protein_action_available: bool = false
var protein_action_pending: bool = false
