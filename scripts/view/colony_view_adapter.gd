class_name ColonyViewAdapter
extends Node2D

const ANT_VIEW_SCRIPT: Script = preload("res://scripts/view/ant_view.gd")
const BROOD_SLOT_X_RATIOS: Array[float] = [0.52, 0.62, 0.72]
const BROOD_SLOT_Y_OFFSETS: Array[float] = [-4.0, 2.0, -1.0]

var _ant_views: Dictionary[int, AntView] = {}
var _tube_rect: Rect2 = Rect2(34.0, 34.0, 892.0, 232.0)
var _activity_start_x: float = 324.0
var _floor_y: float = 201.0
var _visuals_paused: bool = false

@onready var _queen_view: QueenView = %QueenView


func _ready() -> void:
	_layout_queen()


func apply_snapshot(snapshot: ColonySnapshot) -> bool:
	if snapshot == null:
		return false

	var present_entity_ids: Dictionary[int, bool] = {}
	for ant_snapshot: AntSnapshot in snapshot.ants:
		if (
			ant_snapshot == null
			or present_entity_ids.has(ant_snapshot.entity_id)
		):
			return false
		present_entity_ids[ant_snapshot.entity_id] = true

	_queen_view.set_entity_id(snapshot.queen_entity_id)
	_queen_view.set_simulation_tick(snapshot.simulation_tick)
	for ant_snapshot: AntSnapshot in snapshot.ants:
		var ant_view: AntView = _ant_views.get(ant_snapshot.entity_id)
		if ant_view == null:
			ant_view = ANT_VIEW_SCRIPT.new() as AntView
			ant_view.name = "AntView_%03d" % ant_snapshot.entity_id
			add_child(ant_view)
			ant_view.configure(
				ant_snapshot,
				_get_slot_position(ant_snapshot.entity_id)
			)
			ant_view.set_visuals_paused(_visuals_paused)
			_ant_views[ant_snapshot.entity_id] = ant_view
		else:
			ant_view.apply_snapshot(ant_snapshot)
			ant_view.set_slot_position(_get_slot_position(ant_snapshot.entity_id))

	var removed_entity_ids: Array[int] = []
	for entity_id: int in _ant_views:
		if not present_entity_ids.has(entity_id):
			removed_entity_ids.append(entity_id)
	for entity_id: int in removed_entity_ids:
		var removed_view: AntView = _ant_views[entity_id]
		_ant_views.erase(entity_id)
		remove_child(removed_view)
		removed_view.queue_free()

	return true


func set_habitat_geometry(
	new_tube_rect: Rect2,
	new_activity_start_x: float,
	new_floor_y: float
) -> void:
	_tube_rect = new_tube_rect
	_activity_start_x = new_activity_start_x
	_floor_y = new_floor_y
	_layout_queen()
	for entity_id: int in _ant_views:
		_ant_views[entity_id].set_slot_position(_get_slot_position(entity_id))


func set_visuals_paused(value: bool) -> void:
	_visuals_paused = value
	_queen_view.set_visuals_paused(value)
	for ant_view: AntView in _ant_views.values():
		ant_view.set_visuals_paused(value)


func are_visuals_paused() -> bool:
	return _visuals_paused


func get_ant_view(entity_id: int) -> AntView:
	return _ant_views.get(entity_id)


func has_ant_view(entity_id: int) -> bool:
	return _ant_views.has(entity_id)


func get_ant_view_count() -> int:
	return _ant_views.size()


func get_queen_view() -> QueenView:
	return _queen_view


func _layout_queen() -> void:
	if not is_node_ready():
		return
	var activity_end_x: float = _get_activity_end_x()
	_queen_view.set_habitat_position(Vector2(
		lerpf(_activity_start_x, activity_end_x, 0.28),
		_floor_y - 26.0
	))


func _get_slot_position(entity_id: int) -> Vector2:
	var slot_index: int = posmod(entity_id - 1, BROOD_SLOT_X_RATIOS.size())
	return Vector2(
		lerpf(
			_activity_start_x,
			_get_activity_end_x(),
			BROOD_SLOT_X_RATIOS[slot_index]
		),
		_floor_y - 17.0 + BROOD_SLOT_Y_OFFSETS[slot_index]
	)


func _get_activity_end_x() -> float:
	return _tube_rect.end.x - _tube_rect.size.y * 0.18
