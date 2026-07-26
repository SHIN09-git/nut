class_name SugarForagingHabitatView
extends Control

signal worker_selection_requested(entity_id: int)
signal sugar_drop_requested
signal sugar_tool_cancel_requested

const ANT_VIEW_SCRIPT: Script = preload("res://scripts/view/ant_view.gd")

const VIEW_MINIMUM_SIZE: Vector2 = Vector2(720.0, 350.0)
const OUTER_MARGIN: float = 24.0
const WORKER_SELECTION_RADIUS: float = 28.0
const CARRIED_SUGAR_OFFSET: Vector2 = Vector2(0.0, -18.0)

const BACKGROUND_COLOR: Color = Color(0.038, 0.047, 0.044, 1.0)
const NEST_FILL_COLOR: Color = Color(0.25, 0.18, 0.105, 1.0)
const NEST_EDGE_COLOR: Color = Color(0.54, 0.46, 0.31, 0.96)
const TUNNEL_FILL_COLOR: Color = Color(0.10, 0.12, 0.105, 1.0)
const TUNNEL_EDGE_COLOR: Color = Color(0.42, 0.38, 0.28, 0.96)
const FORAGING_FILL_COLOR: Color = Color(0.13, 0.19, 0.16, 1.0)
const FORAGING_EDGE_COLOR: Color = Color(0.37, 0.49, 0.38, 0.96)
const SUBSTRATE_COLOR: Color = Color(0.39, 0.30, 0.17, 0.72)
const PLACEMENT_GLOW_COLOR: Color = Color(0.92, 0.77, 0.37, 0.82)
const SUGAR_COLOR: Color = Color(0.91, 0.69, 0.28, 1.0)
const SUGAR_HIGHLIGHT_COLOR: Color = Color(1.0, 0.94, 0.73, 0.92)
const SHARE_GLOW_COLOR: Color = Color(0.91, 0.69, 0.28, 0.62)
const UNAVAILABLE_OVERLAY_COLOR: Color = Color(0.025, 0.03, 0.028, 0.58)

const NEST_WORKER_SLOT_RATIOS: Array[Vector2] = [
	Vector2(0.42, 0.40),
	Vector2(0.61, 0.48),
	Vector2(0.74, 0.34),
	Vector2(0.52, 0.66),
]
const FORAGING_WORKER_SLOT_RATIOS: Array[Vector2] = [
	Vector2(0.30, 0.38),
	Vector2(0.50, 0.54),
	Vector2(0.72, 0.34),
	Vector2(0.62, 0.72),
]
const FOOD_SLOT_RATIOS: Array[Vector2] = [
	Vector2(0.67, 0.68),
	Vector2(0.48, 0.36),
	Vector2(0.76, 0.42),
]

var _ant_views: Dictionary[int, AntView] = {}
var _previous_snapshot: GameSnapshot
var _latest_snapshot: GameSnapshot
var _previous_entity_positions: Dictionary[int, Vector2] = {}
var _current_entity_positions: Dictionary[int, Vector2] = {}
var _interpolation_alpha: float = 1.0
var _nest_zone_id: StringName = &""
var _placement_zone_id: StringName = &""
var _entrance_zone_id: StringName = &""
var _zone_available: Dictionary[StringName, bool] = {}
var _visuals_paused: bool = false
var _selected_worker_id: int = -1
var _sugar_tool_armed: bool = false

@onready var _entity_layer: Node2D = %EntityLayer
@onready var _queen_view: QueenView = %QueenView
@onready var _nest_label: Label = %NestZoneLabel
@onready var _entrance_label: Label = %EntranceZoneLabel
@onready var _foraging_label: Label = %ForagingZoneLabel
@onready var _placement_hint: Label = %PlacementHint


func _ready() -> void:
	_queen_view.z_index = 3
	_queen_view.set_visuals_paused(_visuals_paused)
	_placement_hint.visible = false
	_layout_projection()
	queue_redraw()


func _notification(what: int) -> void:
	if what != NOTIFICATION_RESIZED:
		return
	if is_node_ready():
		_recalculate_position_endpoints()
		_layout_projection()
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	var mouse_event: InputEventMouseButton = event as InputEventMouseButton
	if (
		mouse_event == null
		or not mouse_event.pressed
		or mouse_event.button_index != MOUSE_BUTTON_LEFT
	):
		return

	if _sugar_tool_armed:
		if _get_foraging_rect().has_point(mouse_event.position):
			sugar_drop_requested.emit()
		else:
			sugar_tool_cancel_requested.emit()
		accept_event()
		return

	var worker_id: int = _find_worker_at_position(mouse_event.position)
	if worker_id < 0:
		return
	worker_selection_requested.emit(worker_id)
	accept_event()


func apply_snapshot(snapshot: GameSnapshot) -> bool:
	if not is_node_ready() or not _validate_snapshot(snapshot):
		return false
	if (
		_latest_snapshot != null
		and snapshot.simulation_tick < _latest_snapshot.simulation_tick
	):
		return false

	_copy_scenario_projection(snapshot)
	_update_position_endpoints(snapshot)

	var present_entity_ids: Dictionary[int, bool] = {}
	for ant_snapshot: AntSnapshot in snapshot.colony.ants:
		present_entity_ids[ant_snapshot.entity_id] = true
		var ant_view: AntView = _ant_views.get(ant_snapshot.entity_id)
		if ant_view == null:
			ant_view = ANT_VIEW_SCRIPT.new() as AntView
			ant_view.name = "AntView_%03d" % ant_snapshot.entity_id
			_entity_layer.add_child(ant_view)
			if not ant_view.configure(
				ant_snapshot,
				_current_entity_positions.get(
					ant_snapshot.entity_id,
					Vector2.ZERO
				)
			):
				_entity_layer.remove_child(ant_view)
				ant_view.queue_free()
				return false
			ant_view.set_visuals_paused(_visuals_paused)
			_ant_views[ant_snapshot.entity_id] = ant_view
		elif not ant_view.apply_snapshot(ant_snapshot):
			return false

	var removed_entity_ids: Array[int] = []
	for entity_id: int in _ant_views:
		if not present_entity_ids.has(entity_id):
			removed_entity_ids.append(entity_id)
	for entity_id: int in removed_entity_ids:
		var removed_view: AntView = _ant_views[entity_id]
		_ant_views.erase(entity_id)
		_previous_entity_positions.erase(entity_id)
		_current_entity_positions.erase(entity_id)
		_entity_layer.remove_child(removed_view)
		removed_view.queue_free()

	_queen_view.set_entity_id(snapshot.colony.queen_entity_id)
	_queen_view.set_simulation_tick(snapshot.simulation_tick)
	_apply_selected_worker_projection()
	_layout_projection()
	queue_redraw()
	return true


func reset_projection() -> void:
	for ant_view: AntView in _ant_views.values():
		if ant_view.get_parent() != null:
			ant_view.get_parent().remove_child(ant_view)
		ant_view.queue_free()
	_ant_views.clear()

	_previous_snapshot = null
	_latest_snapshot = null
	_previous_entity_positions.clear()
	_current_entity_positions.clear()
	_interpolation_alpha = 1.0
	_nest_zone_id = &""
	_placement_zone_id = &""
	_entrance_zone_id = &""
	_zone_available.clear()
	_visuals_paused = false
	_selected_worker_id = -1
	_sugar_tool_armed = false

	if _queen_view != null:
		_queen_view.set_entity_id(-1)
		_queen_view.set_simulation_tick(0)
		_queen_view.set_visuals_paused(false)
	if _placement_hint != null:
		_placement_hint.visible = false
	_layout_projection()
	queue_redraw()


func set_visuals_paused(value: bool) -> void:
	_visuals_paused = value
	if _queen_view != null:
		_queen_view.set_visuals_paused(value)
	for ant_view: AntView in _ant_views.values():
		ant_view.set_visuals_paused(value)


func set_interpolation_alpha(value: float) -> void:
	if _visuals_paused:
		return
	_interpolation_alpha = (
		clampf(value, 0.0, 1.0) if is_finite(value) else 0.0
	)
	_layout_projection()
	queue_redraw()


func set_selected_worker_id(entity_id: int) -> bool:
	var selected_worker_id: int = -1
	if entity_id >= 0 and _is_selectable_worker(entity_id):
		selected_worker_id = entity_id
	_selected_worker_id = selected_worker_id
	_apply_selected_worker_projection()
	return selected_worker_id == entity_id


func get_selected_worker_id() -> int:
	return _selected_worker_id


func set_sugar_tool_armed(value: bool) -> void:
	_sugar_tool_armed = value
	if _placement_hint != null:
		_placement_hint.visible = value
	queue_redraw()


func is_sugar_tool_armed() -> bool:
	return _sugar_tool_armed


func get_placement_zone_center() -> Vector2:
	return _get_foraging_rect().get_center()


func get_ant_view(entity_id: int) -> AntView:
	return _ant_views.get(entity_id)


func get_ant_view_count() -> int:
	return _ant_views.size()


func get_queen_view() -> QueenView:
	return _queen_view


func _validate_snapshot(snapshot: GameSnapshot) -> bool:
	if (
		snapshot == null
		or snapshot.colony == null
		or snapshot.scenario == null
		or snapshot.observations == null
		or snapshot.scenario.nest_zone_id.is_empty()
		or snapshot.scenario.placement_zone_id.is_empty()
		or snapshot.scenario.nest_zone_id
			== snapshot.scenario.placement_zone_id
		or snapshot.colony.zones.size() < 3
	):
		return false

	var seen_zone_ids: Dictionary[StringName, bool] = {}
	for zone: HabitatZoneSnapshot in snapshot.colony.zones:
		if (
			zone == null
			or zone.zone_id.is_empty()
			or seen_zone_ids.has(zone.zone_id)
		):
			return false
		seen_zone_ids[zone.zone_id] = true
	if (
		not seen_zone_ids.has(snapshot.scenario.nest_zone_id)
		or not seen_zone_ids.has(snapshot.scenario.placement_zone_id)
	):
		return false

	var seen_entity_ids: Dictionary[int, bool] = {}
	for ant_snapshot: AntSnapshot in snapshot.colony.ants:
		if (
			ant_snapshot == null
			or ant_snapshot.entity_id < 0
			or seen_entity_ids.has(ant_snapshot.entity_id)
		):
			return false
		seen_entity_ids[ant_snapshot.entity_id] = true

	var seen_food_source_ids: Dictionary[int, bool] = {}
	for food_source: FoodSourceSnapshot in snapshot.colony.food_sources:
		if (
			food_source == null
			or food_source.food_source_id < 0
			or food_source.remaining_portions < 0
			or seen_food_source_ids.has(food_source.food_source_id)
			or not seen_zone_ids.has(food_source.zone_id)
		):
			return false
		seen_food_source_ids[food_source.food_source_id] = true
	return true


func _copy_scenario_projection(snapshot: GameSnapshot) -> void:
	_nest_zone_id = snapshot.scenario.nest_zone_id
	_placement_zone_id = snapshot.scenario.placement_zone_id
	_entrance_zone_id = &""
	_zone_available.clear()
	for zone: HabitatZoneSnapshot in snapshot.colony.zones:
		_zone_available[zone.zone_id] = zone.available
		if (
			zone.zone_id != _nest_zone_id
			and zone.zone_id != _placement_zone_id
			and (
				_entrance_zone_id.is_empty()
				or String(zone.zone_id) < String(_entrance_zone_id)
			)
		):
			_entrance_zone_id = zone.zone_id


func _update_position_endpoints(snapshot: GameSnapshot) -> void:
	if _latest_snapshot == null:
		_previous_snapshot = snapshot
		_latest_snapshot = snapshot
		_current_entity_positions = _calculate_entity_positions(snapshot)
		_previous_entity_positions = _current_entity_positions.duplicate()
		return

	if snapshot.simulation_tick > _latest_snapshot.simulation_tick:
		_previous_snapshot = _latest_snapshot
		_latest_snapshot = snapshot
		_previous_entity_positions = _calculate_entity_positions(
			_previous_snapshot
		)
		_current_entity_positions = _calculate_entity_positions(
			_latest_snapshot
		)
		for entity_id: int in _current_entity_positions:
			if not _previous_entity_positions.has(entity_id):
				_previous_entity_positions[entity_id] = (
					_current_entity_positions[entity_id]
				)
		return

	_latest_snapshot = snapshot
	_current_entity_positions = _calculate_entity_positions(snapshot)
	for entity_id: int in _current_entity_positions:
		if not _previous_entity_positions.has(entity_id):
			_previous_entity_positions[entity_id] = (
				_current_entity_positions[entity_id]
			)


func _recalculate_position_endpoints() -> void:
	if _latest_snapshot == null:
		return
	_current_entity_positions = _calculate_entity_positions(_latest_snapshot)
	_previous_entity_positions = _calculate_entity_positions(
		_previous_snapshot if _previous_snapshot != null else _latest_snapshot
	)
	for entity_id: int in _current_entity_positions:
		if not _previous_entity_positions.has(entity_id):
			_previous_entity_positions[entity_id] = (
				_current_entity_positions[entity_id]
			)


func _calculate_entity_positions(
	snapshot: GameSnapshot
) -> Dictionary[int, Vector2]:
	var positions: Dictionary[int, Vector2] = {}
	for ant_snapshot: AntSnapshot in snapshot.colony.ants:
		positions[ant_snapshot.entity_id] = _get_ant_position(
			ant_snapshot,
			snapshot
		)
	return positions


func _get_ant_position(
	ant_snapshot: AntSnapshot,
	snapshot: GameSnapshot
) -> Vector2:
	if ant_snapshot.life_stage != AntModel.LifeStage.WORKER:
		return _get_nest_brood_position(ant_snapshot.entity_id)

	var task: ForagingTaskSnapshot = ant_snapshot.foraging_task
	if task == null or task.state == ForagingTaskSnapshot.State.IDLE:
		return _get_worker_idle_position(
			_get_valid_zone_id(ant_snapshot.zone_id),
			ant_snapshot.entity_id
		)

	var progress: float = task.get_progress()
	var origin_zone_id: StringName = _get_valid_zone_id(
		task.origin_zone_id
		if not task.origin_zone_id.is_empty()
		else ant_snapshot.zone_id
	)
	var target_zone_id: StringName = _get_valid_zone_id(task.target_zone_id)
	var food_position: Vector2 = _get_food_source_position_by_id(
		snapshot,
		task.target_food_source_id
	)

	match task.state:
		ForagingTaskSnapshot.State.SEEKING_FOOD:
			return _get_worker_idle_position(
				origin_zone_id,
				ant_snapshot.entity_id
			)
		ForagingTaskSnapshot.State.MOVING_TO_FOOD:
			return _get_route_position(
				_get_worker_idle_position(
					origin_zone_id,
					ant_snapshot.entity_id
				),
				food_position + Vector2(-18.0, 12.0),
				task.route_zone_ids,
				progress
			)
		ForagingTaskSnapshot.State.COLLECTING:
			return food_position + Vector2(-18.0, 12.0)
		ForagingTaskSnapshot.State.RETURNING_TO_NEST:
			return _get_route_position(
				food_position + Vector2(-18.0, 12.0),
				_get_share_position(ant_snapshot.entity_id),
				task.route_zone_ids,
				progress
			)
		ForagingTaskSnapshot.State.SHARING:
			return _get_share_position(ant_snapshot.entity_id).lerp(
				_get_worker_idle_position(
					target_zone_id,
					ant_snapshot.entity_id
				),
				progress
			)
		_:
			return _get_worker_idle_position(
				_get_valid_zone_id(ant_snapshot.zone_id),
				ant_snapshot.entity_id
			)


func _get_route_position(
	start_position: Vector2,
	end_position: Vector2,
	route_zone_ids: Array[StringName],
	progress: float
) -> Vector2:
	var points: Array[Vector2] = [start_position]
	for zone_id: StringName in route_zone_ids:
		var route_anchor: Vector2 = _get_route_anchor(
			_get_valid_zone_id(zone_id)
		)
		if points[-1].distance_squared_to(route_anchor) > 1.0:
			points.append(route_anchor)
	if points[-1].distance_squared_to(end_position) > 1.0:
		points.append(end_position)
	return _sample_polyline(points, clampf(progress, 0.0, 1.0))


func _sample_polyline(
	points: Array[Vector2],
	progress: float
) -> Vector2:
	if points.is_empty():
		return Vector2.ZERO
	if points.size() == 1:
		return points[0]

	var total_length: float = 0.0
	for point_index: int in range(1, points.size()):
		total_length += points[point_index - 1].distance_to(points[point_index])
	if total_length <= 0.001:
		return points[-1]

	var remaining_distance: float = total_length * progress
	for point_index: int in range(1, points.size()):
		var segment_start: Vector2 = points[point_index - 1]
		var segment_end: Vector2 = points[point_index]
		var segment_length: float = segment_start.distance_to(segment_end)
		if remaining_distance <= segment_length:
			return segment_start.lerp(
				segment_end,
				remaining_distance / maxf(segment_length, 0.001)
			)
		remaining_distance -= segment_length
	return points[-1]


func _layout_projection() -> void:
	_layout_zone_labels()
	_layout_queen()
	if _latest_snapshot == null:
		return

	for ant_snapshot: AntSnapshot in _latest_snapshot.colony.ants:
		var ant_view: AntView = _ant_views.get(ant_snapshot.entity_id)
		if (
			ant_view == null
			or not _current_entity_positions.has(ant_snapshot.entity_id)
		):
			continue
		var current_position: Vector2 = _current_entity_positions[
			ant_snapshot.entity_id
		]
		var previous_position: Vector2 = _previous_entity_positions.get(
			ant_snapshot.entity_id,
			current_position
		)
		ant_view.set_slot_position(
			previous_position.lerp(current_position, _interpolation_alpha)
		)
		ant_view.z_index = (
			6 if _worker_carries_sugar(ant_snapshot) else 5
		)


func _layout_queen() -> void:
	if _queen_view == null:
		return
	var nest_rect: Rect2 = _get_nest_rect()
	_queen_view.set_habitat_position(
		nest_rect.position + nest_rect.size * Vector2(0.25, 0.27)
	)


func _layout_zone_labels() -> void:
	if (
		_nest_label == null
		or _entrance_label == null
		or _foraging_label == null
		or _placement_hint == null
	):
		return
	var nest_rect: Rect2 = _get_nest_rect()
	var entrance_rect: Rect2 = _get_entrance_rect()
	var foraging_rect: Rect2 = _get_foraging_rect()
	_nest_label.position = nest_rect.position + Vector2(14.0, 10.0)
	_entrance_label.position = Vector2(
		entrance_rect.get_center().x - 34.0,
		entrance_rect.position.y + 8.0
	)
	_foraging_label.position = foraging_rect.position + Vector2(14.0, 10.0)
	_placement_hint.position = Vector2(
		foraging_rect.get_center().x - 86.0,
		foraging_rect.position.y + 42.0
	)


func _find_worker_at_position(local_position: Vector2) -> int:
	if _latest_snapshot == null:
		return -1

	var closest_distance_squared: float = (
		WORKER_SELECTION_RADIUS * WORKER_SELECTION_RADIUS
	)
	var closest_entity_id: int = -1
	for ant: AntSnapshot in _latest_snapshot.colony.ants:
		if ant.life_stage != AntModel.LifeStage.WORKER:
			continue
		var ant_view: AntView = _ant_views.get(ant.entity_id)
		if ant_view == null:
			continue
		var distance_squared: float = ant_view.position.distance_squared_to(
			local_position
		)
		if (
			distance_squared < closest_distance_squared
			or (
				is_equal_approx(distance_squared, closest_distance_squared)
				and (
					closest_entity_id < 0
					or ant.entity_id < closest_entity_id
				)
			)
		):
			closest_distance_squared = distance_squared
			closest_entity_id = ant.entity_id
	return closest_entity_id


func _is_selectable_worker(entity_id: int) -> bool:
	if _latest_snapshot == null or not _ant_views.has(entity_id):
		return false
	var ant: AntSnapshot = _latest_snapshot.colony.find_ant(entity_id)
	return ant != null and ant.life_stage == AntModel.LifeStage.WORKER


func _apply_selected_worker_projection() -> void:
	if (
		_selected_worker_id >= 0
		and not _is_selectable_worker(_selected_worker_id)
	):
		_selected_worker_id = -1
	for entity_id: int in _ant_views:
		_ant_views[entity_id].set_selected(
			entity_id == _selected_worker_id
		)


func _get_worker_idle_position(
	zone_id: StringName,
	entity_id: int
) -> Vector2:
	var zone_rect: Rect2 = _get_zone_rect(zone_id)
	var ratios: Array[Vector2] = (
		FORAGING_WORKER_SLOT_RATIOS
		if zone_id == _placement_zone_id
		else NEST_WORKER_SLOT_RATIOS
	)
	var slot_index: int = posmod(entity_id - 1, ratios.size())
	return zone_rect.position + zone_rect.size * ratios[slot_index]


func _get_nest_brood_position(entity_id: int) -> Vector2:
	var nest_rect: Rect2 = _get_nest_rect()
	var slot_index: int = posmod(entity_id - 1, 4)
	var ratio: Vector2 = Vector2(
		0.42 + float(slot_index % 2) * 0.15,
		0.72 + float(slot_index / 2) * 0.10
	)
	return nest_rect.position + nest_rect.size * ratio


func _get_share_position(entity_id: int) -> Vector2:
	var nest_rect: Rect2 = _get_nest_rect()
	var vertical_offset: float = float(posmod(entity_id - 1, 3) - 1) * 18.0
	return (
		nest_rect.position
		+ nest_rect.size * Vector2(0.57, 0.55)
		+ Vector2(0.0, vertical_offset)
	)


func _get_food_source_position_by_id(
	snapshot: GameSnapshot,
	food_source_id: int
) -> Vector2:
	for food_source: FoodSourceSnapshot in snapshot.colony.food_sources:
		if food_source.food_source_id == food_source_id:
			return _get_food_source_position(food_source)
	return _get_food_slot_position(_placement_zone_id, food_source_id)


func _get_food_source_position(
	food_source: FoodSourceSnapshot
) -> Vector2:
	return _get_food_slot_position(
		food_source.zone_id,
		food_source.food_source_id
	)


func _get_food_slot_position(
	zone_id: StringName,
	food_source_id: int
) -> Vector2:
	var zone_rect: Rect2 = _get_zone_rect(zone_id)
	var slot_index: int = posmod(
		food_source_id - 1,
		FOOD_SLOT_RATIOS.size()
	)
	return zone_rect.position + zone_rect.size * FOOD_SLOT_RATIOS[slot_index]


func _get_route_anchor(zone_id: StringName) -> Vector2:
	if zone_id == _nest_zone_id:
		var nest_rect: Rect2 = _get_nest_rect()
		return Vector2(
			nest_rect.end.x - 20.0,
			nest_rect.get_center().y
		)
	if zone_id == _placement_zone_id:
		var foraging_rect: Rect2 = _get_foraging_rect()
		return Vector2(
			foraging_rect.position.x + 20.0,
			foraging_rect.get_center().y
		)
	return _get_entrance_rect().get_center()


func _get_valid_zone_id(zone_id: StringName) -> StringName:
	if (
		zone_id == _nest_zone_id
		or zone_id == _placement_zone_id
		or zone_id == _entrance_zone_id
	):
		return zone_id
	return _nest_zone_id


func _get_zone_rect(zone_id: StringName) -> Rect2:
	if zone_id == _placement_zone_id:
		return _get_foraging_rect()
	if zone_id == _entrance_zone_id:
		return _get_entrance_rect()
	return _get_nest_rect()


func _get_effective_size() -> Vector2:
	return Vector2(
		maxf(size.x, VIEW_MINIMUM_SIZE.x),
		maxf(size.y, VIEW_MINIMUM_SIZE.y)
	)


func _get_nest_rect() -> Rect2:
	var effective_size: Vector2 = _get_effective_size()
	var content_size: Vector2 = effective_size - Vector2.ONE * OUTER_MARGIN * 2.0
	return Rect2(
		Vector2(OUTER_MARGIN, OUTER_MARGIN + 20.0),
		Vector2(content_size.x * 0.35, content_size.y - 40.0)
	)


func _get_entrance_rect() -> Rect2:
	var nest_rect: Rect2 = _get_nest_rect()
	var foraging_rect: Rect2 = _get_foraging_rect()
	var height: float = minf(86.0, nest_rect.size.y * 0.28)
	return Rect2(
		Vector2(
			nest_rect.end.x - 4.0,
			nest_rect.get_center().y - height * 0.5
		),
		Vector2(
			foraging_rect.position.x - nest_rect.end.x + 8.0,
			height
		)
	)


func _get_foraging_rect() -> Rect2:
	var effective_size: Vector2 = _get_effective_size()
	var content_size: Vector2 = effective_size - Vector2.ONE * OUTER_MARGIN * 2.0
	return Rect2(
		Vector2(
			OUTER_MARGIN + content_size.x * 0.59,
			OUTER_MARGIN
		),
		Vector2(content_size.x * 0.41, content_size.y)
	)


func _worker_carries_sugar(worker: AntSnapshot) -> bool:
	if (
		worker == null
		or worker.life_stage != AntModel.LifeStage.WORKER
		or worker.foraging_task == null
	):
		return false
	return worker.foraging_task.carried_portions > 0


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), BACKGROUND_COLOR)
	var nest_rect: Rect2 = _get_nest_rect()
	var entrance_rect: Rect2 = _get_entrance_rect()
	var foraging_rect: Rect2 = _get_foraging_rect()
	_draw_tunnel(entrance_rect)
	_draw_chamber(
		nest_rect,
		NEST_FILL_COLOR,
		NEST_EDGE_COLOR,
		_is_zone_available(_nest_zone_id)
	)
	_draw_foraging_area(
		foraging_rect,
		_is_zone_available(_placement_zone_id)
	)
	if _sugar_tool_armed:
		_draw_placement_target(foraging_rect)
	if _latest_snapshot != null:
		_draw_food_sources(_latest_snapshot)
		_draw_task_effects(_latest_snapshot)


func _draw_chamber(
	rect: Rect2,
	fill_color: Color,
	edge_color: Color,
	available: bool
) -> void:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = fill_color
	style.border_color = edge_color
	style.border_width_left = 3
	style.border_width_top = 3
	style.border_width_right = 3
	style.border_width_bottom = 3
	style.corner_radius_top_left = 28
	style.corner_radius_top_right = 28
	style.corner_radius_bottom_right = 28
	style.corner_radius_bottom_left = 28
	draw_style_box(style, rect)

	var substrate_rect: Rect2 = Rect2(
		rect.position + Vector2(10.0, rect.size.y * 0.64),
		Vector2(rect.size.x - 20.0, rect.size.y * 0.28)
	)
	draw_rect(substrate_rect, SUBSTRATE_COLOR)
	for line_index: int in range(3):
		var y: float = substrate_rect.position.y + (
			float(line_index + 1) * substrate_rect.size.y / 4.0
		)
		draw_line(
			Vector2(substrate_rect.position.x + 8.0, y),
			Vector2(substrate_rect.end.x - 8.0, y + 2.0),
			Color(0.72, 0.60, 0.37, 0.18),
			2.0,
			true
		)
	if not available:
		draw_rect(rect.grow(-5.0), UNAVAILABLE_OVERLAY_COLOR)


func _draw_tunnel(rect: Rect2) -> void:
	draw_rect(rect, TUNNEL_EDGE_COLOR)
	draw_rect(rect.grow(-4.0), TUNNEL_FILL_COLOR)
	draw_line(
		Vector2(rect.position.x + 10.0, rect.get_center().y),
		Vector2(rect.end.x - 10.0, rect.get_center().y),
		Color(0.69, 0.60, 0.38, 0.24),
		2.0,
		true
	)
	if not _is_zone_available(_entrance_zone_id):
		draw_rect(rect.grow(-4.0), UNAVAILABLE_OVERLAY_COLOR)


func _draw_foraging_area(rect: Rect2, available: bool) -> void:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = FORAGING_FILL_COLOR
	style.border_color = FORAGING_EDGE_COLOR
	style.border_width_left = 3
	style.border_width_top = 3
	style.border_width_right = 3
	style.border_width_bottom = 3
	style.corner_radius_top_left = 18
	style.corner_radius_top_right = 18
	style.corner_radius_bottom_right = 18
	style.corner_radius_bottom_left = 18
	draw_style_box(style, rect)

	for stone_index: int in range(7):
		var ratio: Vector2 = Vector2(
			0.18 + float((stone_index * 37) % 67) / 100.0,
			0.22 + float((stone_index * 23) % 61) / 100.0
		)
		draw_circle(
			rect.position + rect.size * ratio,
			3.0 + float(stone_index % 3),
			Color(0.42, 0.50, 0.40, 0.20)
		)
	if not available:
		draw_rect(rect.grow(-5.0), UNAVAILABLE_OVERLAY_COLOR)


func _draw_placement_target(rect: Rect2) -> void:
	var center: Vector2 = rect.position + rect.size * FOOD_SLOT_RATIOS[0]
	draw_circle(center, 30.0, Color(0.91, 0.69, 0.28, 0.08))
	draw_arc(
		center,
		23.0,
		0.0,
		TAU,
		36,
		PLACEMENT_GLOW_COLOR,
		2.0,
		true
	)
	draw_line(
		center - Vector2(9.0, 0.0),
		center + Vector2(9.0, 0.0),
		PLACEMENT_GLOW_COLOR,
		2.0,
		true
	)
	draw_line(
		center - Vector2(0.0, 9.0),
		center + Vector2(0.0, 9.0),
		PLACEMENT_GLOW_COLOR,
		2.0,
		true
	)


func _draw_food_sources(snapshot: GameSnapshot) -> void:
	for food_source: FoodSourceSnapshot in snapshot.colony.food_sources:
		if not food_source.available or food_source.remaining_portions <= 0:
			continue
		var center: Vector2 = _get_food_source_position(food_source)
		var portion_count: int = mini(food_source.remaining_portions, 3)
		for portion_index: int in range(portion_count):
			var offset: Vector2 = Vector2(
				(
					float(portion_index)
					- float(portion_count - 1) * 0.5
				) * 11.0,
				-float(portion_index % 2) * 4.0
			)
			_draw_sugar_drop(center + offset, 1.0)


func _draw_task_effects(snapshot: GameSnapshot) -> void:
	for ant: AntSnapshot in snapshot.colony.ants:
		if (
			ant.life_stage != AntModel.LifeStage.WORKER
			or ant.foraging_task == null
		):
			continue
		var task: ForagingTaskSnapshot = ant.foraging_task
		var ant_view: AntView = _ant_views.get(ant.entity_id)
		if ant_view == null:
			continue
		if task.carried_portions > 0:
			_draw_sugar_drop(
				ant_view.position + CARRIED_SUGAR_OFFSET,
				0.72
			)
		if task.state == ForagingTaskSnapshot.State.COLLECTING:
			var source_position: Vector2 = _get_food_source_position_by_id(
				snapshot,
				task.target_food_source_id
			)
			draw_arc(
				source_position,
				18.0 + task.get_progress() * 6.0,
				0.0,
				TAU,
				28,
				PLACEMENT_GLOW_COLOR,
				2.0,
				true
			)
		elif task.state == ForagingTaskSnapshot.State.SHARING:
			var sharing_progress: float = task.get_progress()
			var glow_color: Color = SHARE_GLOW_COLOR
			glow_color.a *= 1.0 - sharing_progress * 0.55
			draw_arc(
				ant_view.position,
				15.0 + sharing_progress * 28.0,
				0.0,
				TAU,
				32,
				glow_color,
				3.0,
				true
			)


func _draw_sugar_drop(center: Vector2, scale_factor: float) -> void:
	var points: PackedVector2Array = PackedVector2Array([
		center + Vector2(0.0, -10.0) * scale_factor,
		center + Vector2(7.0, -1.0) * scale_factor,
		center + Vector2(6.0, 6.0) * scale_factor,
		center + Vector2(0.0, 9.0) * scale_factor,
		center + Vector2(-6.0, 6.0) * scale_factor,
		center + Vector2(-7.0, -1.0) * scale_factor,
	])
	draw_colored_polygon(points, SUGAR_COLOR)
	draw_circle(
		center + Vector2(-2.0, -2.5) * scale_factor,
		2.1 * scale_factor,
		SUGAR_HIGHLIGHT_COLOR
	)


func _is_zone_available(zone_id: StringName) -> bool:
	if zone_id.is_empty():
		return true
	return _zone_available.get(zone_id, true)
