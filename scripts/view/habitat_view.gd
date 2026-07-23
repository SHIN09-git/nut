class_name HabitatView
extends Control

const ANT_VIEW_SCRIPT: Script = preload("res://scripts/view/ant_view.gd")

const VIEW_MINIMUM_SIZE: Vector2 = Vector2(720.0, 360.0)
const OUTER_MARGIN_RATIO: float = 0.045
const MIN_OUTER_MARGIN: float = 20.0
const MAX_OUTER_MARGIN: float = 34.0
const CONNECTOR_WIDTH_RATIO: float = 0.12
const MIN_CONNECTOR_WIDTH: float = 68.0
const MAX_CONNECTOR_WIDTH: float = 118.0
const CHAMBER_CORNER_RADIUS: int = 28
const CHAMBER_BORDER_WIDTH: int = 3

const BACKGROUND_COLOR: Color = Color(0.045, 0.055, 0.052, 1.0)
const CHAMBER_DRY_COLOR: Color = Color(0.29, 0.22, 0.14, 1.0)
const CHAMBER_DAMP_COLOR: Color = Color(0.10, 0.25, 0.24, 1.0)
const CHAMBER_EDGE_COLOR: Color = Color(0.50, 0.46, 0.35, 0.92)
const SUBSTRATE_DRY_COLOR: Color = Color(0.43, 0.31, 0.18, 0.92)
const SUBSTRATE_DAMP_COLOR: Color = Color(0.16, 0.31, 0.27, 0.96)
const CONNECTOR_EDGE_COLOR: Color = Color(0.42, 0.40, 0.32, 1.0)
const CONNECTOR_FILL_COLOR: Color = Color(0.13, 0.15, 0.13, 1.0)
const CONDENSATION_COLOR: Color = Color(0.55, 0.82, 0.78, 0.48)
const UNAVAILABLE_OVERLAY_COLOR: Color = Color(0.05, 0.055, 0.05, 0.56)
const WORKER_BROOD_APPROACH_OFFSET: Vector2 = Vector2(13.0, -7.0)
const CARRIED_BROOD_OFFSET: Vector2 = Vector2(-2.0, -17.0)

const BROOD_SLOT_RATIOS: Array[Vector2] = [
	Vector2(0.25, 0.66),
	Vector2(0.47, 0.64),
	Vector2(0.69, 0.67),
	Vector2(0.30, 0.80),
	Vector2(0.52, 0.78),
	Vector2(0.74, 0.81),
]
const WORKER_SLOT_RATIOS: Array[Vector2] = [
	Vector2(0.44, 0.40),
	Vector2(0.62, 0.45),
	Vector2(0.78, 0.38),
]
const CONDENSATION_RATIOS: Array[Vector2] = [
	Vector2(0.20, 0.20),
	Vector2(0.38, 0.16),
	Vector2(0.58, 0.22),
	Vector2(0.76, 0.17),
	Vector2(0.30, 0.31),
	Vector2(0.68, 0.32),
]

var _ant_views: Dictionary[int, AntView] = {}
var _previous_snapshot: ColonySnapshot
var _latest_snapshot: ColonySnapshot
var _previous_entity_positions: Dictionary[int, Vector2] = {}
var _current_entity_positions: Dictionary[int, Vector2] = {}
var _interpolation_alpha: float = 1.0
var _zone_ids: Array[StringName] = []
var _zone_humidity: Dictionary[StringName, float] = {}
var _zone_available: Dictionary[StringName, bool] = {}
var _visuals_paused: bool = false

@onready var _entity_layer: Node2D = %EntityLayer
@onready var _queen_view: QueenView = %QueenView


func _ready() -> void:
	_queen_view.z_index = 3
	_queen_view.set_visuals_paused(_visuals_paused)
	queue_redraw()
	_layout_latest_snapshot()


func _notification(what: int) -> void:
	if what != NOTIFICATION_RESIZED:
		return
	queue_redraw()
	if is_node_ready():
		_recalculate_position_endpoints()
		_layout_latest_snapshot()


func apply_snapshot(snapshot: ColonySnapshot) -> bool:
	if not is_node_ready() or not _validate_snapshot(snapshot):
		return false
	if (
		_latest_snapshot != null
		and snapshot.simulation_tick < _latest_snapshot.simulation_tick
	):
		return false

	_copy_zone_display_state(snapshot)
	_update_position_endpoints(snapshot)
	var present_entity_ids: Dictionary[int, bool] = {}
	for ant_snapshot: AntSnapshot in snapshot.ants:
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

	_queen_view.set_entity_id(snapshot.queen_entity_id)
	_queen_view.set_simulation_tick(snapshot.simulation_tick)
	_layout_latest_snapshot()
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
	_zone_ids.clear()
	_zone_humidity.clear()
	_zone_available.clear()
	_visuals_paused = false

	if _queen_view != null:
		_queen_view.set_entity_id(-1)
		_queen_view.set_simulation_tick(0)
		_queen_view.set_visuals_paused(false)
		_layout_queen()
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
	_layout_latest_snapshot()


func get_ant_view(entity_id: int) -> AntView:
	return _ant_views.get(entity_id)


func get_ant_view_count() -> int:
	return _ant_views.size()


func get_queen_view() -> QueenView:
	return _queen_view


func _update_position_endpoints(snapshot: ColonySnapshot) -> void:
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

	# A repeated snapshot may refresh presentation data, but it must not rotate
	# the two authoritative Tick endpoints and accidentally interpolate toward
	# the same position twice.
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
	snapshot: ColonySnapshot
) -> Dictionary[int, Vector2]:
	var positions: Dictionary[int, Vector2] = {}
	for ant_snapshot: AntSnapshot in snapshot.ants:
		if ant_snapshot.life_stage != AntModel.LifeStage.WORKER:
			continue
		positions[ant_snapshot.entity_id] = _get_worker_position(
			ant_snapshot,
			snapshot
		)

	for ant_snapshot: AntSnapshot in snapshot.ants:
		if ant_snapshot.life_stage == AntModel.LifeStage.WORKER:
			continue

		var brood_position: Vector2
		var carrier_snapshot: AntSnapshot = snapshot.find_ant(
			ant_snapshot.carrier_ant_id
		)
		if (
			carrier_snapshot != null
			and positions.has(carrier_snapshot.entity_id)
		):
			brood_position = _get_carried_brood_position(
				ant_snapshot,
				carrier_snapshot,
				positions[carrier_snapshot.entity_id]
			)
		else:
			var reserving_worker: AntSnapshot = snapshot.find_ant(
				ant_snapshot.reserved_by_ant_id
			)
			if (
				reserving_worker != null
				and reserving_worker.worker_task_state
				== WorkerTaskModel.State.PICKING_UP
				and positions.has(reserving_worker.entity_id)
			):
				brood_position = _get_picked_up_brood_position(
					ant_snapshot,
					reserving_worker,
					positions[reserving_worker.entity_id]
				)
			else:
				brood_position = _get_brood_slot_position(
					_get_valid_zone_id(ant_snapshot.zone_id),
					ant_snapshot.entity_id
				)
		positions[ant_snapshot.entity_id] = brood_position
	return positions


func _validate_snapshot(snapshot: ColonySnapshot) -> bool:
	if snapshot == null or snapshot.zones.size() != 2:
		return false

	var seen_zone_ids: Dictionary[StringName, bool] = {}
	for zone: HabitatZoneSnapshot in snapshot.zones:
		if (
			zone == null
			or zone.zone_id.is_empty()
			or seen_zone_ids.has(zone.zone_id)
			or not is_finite(zone.humidity)
		):
			return false
		seen_zone_ids[zone.zone_id] = true

	var seen_entity_ids: Dictionary[int, bool] = {}
	for ant_snapshot: AntSnapshot in snapshot.ants:
		if (
			ant_snapshot == null
			or ant_snapshot.entity_id < 0
			or seen_entity_ids.has(ant_snapshot.entity_id)
		):
			return false
		seen_entity_ids[ant_snapshot.entity_id] = true
	return true


func _copy_zone_display_state(snapshot: ColonySnapshot) -> void:
	var first_zone_id: StringName = snapshot.zones[0].zone_id
	var second_zone_id: StringName = snapshot.zones[1].zone_id
	if String(second_zone_id) < String(first_zone_id):
		var swapped_zone_id: StringName = first_zone_id
		first_zone_id = second_zone_id
		second_zone_id = swapped_zone_id

	_zone_ids.clear()
	_zone_ids.append(first_zone_id)
	_zone_ids.append(second_zone_id)
	_zone_humidity.clear()
	_zone_available.clear()
	for zone: HabitatZoneSnapshot in snapshot.zones:
		_zone_humidity[zone.zone_id] = clampf(zone.humidity, 0.0, 1.0)
		_zone_available[zone.zone_id] = zone.available


func _layout_latest_snapshot() -> void:
	if _latest_snapshot == null or _zone_ids.size() != 2:
		_layout_queen()
		return

	_layout_queen()
	for ant_snapshot: AntSnapshot in _latest_snapshot.ants:
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
		if ant_snapshot.life_stage == AntModel.LifeStage.WORKER:
			ant_view.z_index = 5
		elif (
			ant_snapshot.carrier_ant_id >= 0
			or (
				ant_snapshot.reserved_by_ant_id >= 0
				and _is_brood_being_picked_up(ant_snapshot)
			)
		):
			ant_view.z_index = 6
		else:
			ant_view.z_index = 4


func _is_brood_being_picked_up(brood: AntSnapshot) -> bool:
	if _latest_snapshot == null:
		return false
	var worker: AntSnapshot = _latest_snapshot.find_ant(
		brood.reserved_by_ant_id
	)
	return (
		worker != null
		and worker.worker_task_state == WorkerTaskModel.State.PICKING_UP
	)


func _layout_queen() -> void:
	if _queen_view == null:
		return
	var left_rect: Rect2 = _get_chamber_rect(true)
	_queen_view.set_habitat_position(
		left_rect.position + left_rect.size * Vector2(0.24, 0.29)
	)


func _get_worker_position(
	worker: AntSnapshot,
	snapshot: ColonySnapshot
) -> Vector2:
	var progress: float = worker.get_task_progress()
	var origin_zone_id: StringName = _get_valid_zone_id(
		worker.task_origin_zone_id
		if not worker.task_origin_zone_id.is_empty()
		else worker.zone_id
	)
	match worker.worker_task_state:
		WorkerTaskModel.State.MOVING_TO_BROOD:
			var target_brood: AntSnapshot = snapshot.find_ant(
				worker.target_brood_id
			)
			var brood_zone_id: StringName = origin_zone_id
			if target_brood != null and not target_brood.zone_id.is_empty():
				brood_zone_id = _get_valid_zone_id(target_brood.zone_id)
			return _get_route_position(
				_get_worker_idle_position(origin_zone_id, worker.entity_id),
				_get_brood_approach_position(
					brood_zone_id,
					worker.target_brood_id
				),
				origin_zone_id,
				brood_zone_id,
				progress
			)
		WorkerTaskModel.State.PICKING_UP:
			return _get_brood_approach_position(
				origin_zone_id,
				worker.target_brood_id
			)
		WorkerTaskModel.State.CARRYING_TO_ZONE:
			var target_zone_id: StringName = _get_valid_zone_id(
				worker.target_zone_id
			)
			return _get_route_position(
				_get_brood_approach_position(
					origin_zone_id,
					worker.target_brood_id
				),
				_get_brood_approach_position(
					target_zone_id,
					worker.target_brood_id
				),
				origin_zone_id,
				target_zone_id,
				progress
			)
		WorkerTaskModel.State.DROPPING:
			var drop_zone_id: StringName = _get_valid_zone_id(
				worker.target_zone_id
			)
			return _get_brood_approach_position(
				drop_zone_id,
				worker.target_brood_id
			).lerp(
				_get_worker_idle_position(drop_zone_id, worker.entity_id),
				progress
			)
		_:
			return _get_worker_idle_position(
				_get_valid_zone_id(worker.zone_id),
				worker.entity_id
			)


func _get_carried_brood_position(
	brood: AntSnapshot,
	carrier: AntSnapshot,
	carrier_position: Vector2
) -> Vector2:
	if carrier == null:
		return carrier_position + CARRIED_BROOD_OFFSET
	if carrier.worker_task_state == WorkerTaskModel.State.DROPPING:
		var destination: Vector2 = _get_brood_slot_position(
			_get_valid_zone_id(carrier.target_zone_id),
			brood.entity_id
		)
		var attached_position: Vector2 = (
			_get_brood_approach_position(
				_get_valid_zone_id(carrier.target_zone_id),
				brood.entity_id
			)
			+ CARRIED_BROOD_OFFSET
		)
		return attached_position.lerp(
			destination,
			carrier.get_task_progress()
		)
	return carrier_position + CARRIED_BROOD_OFFSET


func _get_picked_up_brood_position(
	brood: AntSnapshot,
	worker: AntSnapshot,
	worker_position: Vector2
) -> Vector2:
	var slot_position: Vector2 = _get_brood_slot_position(
		_get_valid_zone_id(brood.zone_id),
		brood.entity_id
	)
	return slot_position.lerp(
		worker_position + CARRIED_BROOD_OFFSET,
		worker.get_task_progress()
	)


func _get_route_position(
	start_position: Vector2,
	end_position: Vector2,
	start_zone_id: StringName,
	end_zone_id: StringName,
	progress: float
) -> Vector2:
	var bounded_progress: float = clampf(progress, 0.0, 1.0)
	if start_zone_id == end_zone_id:
		return start_position.lerp(end_position, bounded_progress)

	var route_points: Array[Vector2] = [start_position]
	route_points.append(_get_door_position(start_zone_id))
	route_points.append(_get_door_position(end_zone_id))
	route_points.append(end_position)
	return _sample_polyline(route_points, bounded_progress)


func _sample_polyline(points: Array[Vector2], progress: float) -> Vector2:
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
			var segment_progress: float = (
				remaining_distance / segment_length
				if segment_length > 0.001
				else 1.0
			)
			return segment_start.lerp(segment_end, segment_progress)
		remaining_distance -= segment_length
	return points[-1]


func _get_worker_idle_position(zone_id: StringName, entity_id: int) -> Vector2:
	var chamber_rect: Rect2 = _get_zone_rect(zone_id)
	var slot_index: int = posmod(entity_id - 1, WORKER_SLOT_RATIOS.size())
	return chamber_rect.position + chamber_rect.size * WORKER_SLOT_RATIOS[slot_index]


func _get_brood_slot_position(zone_id: StringName, entity_id: int) -> Vector2:
	var chamber_rect: Rect2 = _get_zone_rect(zone_id)
	var slot_index: int = posmod(entity_id - 1, BROOD_SLOT_RATIOS.size())
	return chamber_rect.position + chamber_rect.size * BROOD_SLOT_RATIOS[slot_index]


func _get_brood_approach_position(
	zone_id: StringName,
	brood_entity_id: int
) -> Vector2:
	return (
		_get_brood_slot_position(zone_id, brood_entity_id)
		+ WORKER_BROOD_APPROACH_OFFSET
	)


func _get_door_position(zone_id: StringName) -> Vector2:
	var chamber_rect: Rect2 = _get_zone_rect(zone_id)
	var center_y: float = chamber_rect.position.y + chamber_rect.size.y * 0.52
	if _zone_ids.size() == 2 and zone_id == _zone_ids[0]:
		return Vector2(chamber_rect.end.x, center_y)
	return Vector2(chamber_rect.position.x, center_y)


func _get_valid_zone_id(zone_id: StringName) -> StringName:
	if _zone_ids.has(zone_id):
		return zone_id
	return _zone_ids[0] if not _zone_ids.is_empty() else &""


func _get_zone_rect(zone_id: StringName) -> Rect2:
	var use_left_rect: bool = (
		_zone_ids.is_empty()
		or zone_id == _zone_ids[0]
	)
	return _get_chamber_rect(use_left_rect)


func _get_chamber_rect(use_left_rect: bool) -> Rect2:
	var effective_size: Vector2 = Vector2(
		maxf(size.x, VIEW_MINIMUM_SIZE.x),
		maxf(size.y, VIEW_MINIMUM_SIZE.y)
	)
	var outer_margin: float = clampf(
		minf(effective_size.x, effective_size.y) * OUTER_MARGIN_RATIO,
		MIN_OUTER_MARGIN,
		MAX_OUTER_MARGIN
	)
	var content_size: Vector2 = effective_size - Vector2.ONE * outer_margin * 2.0
	var connector_width: float = clampf(
		content_size.x * CONNECTOR_WIDTH_RATIO,
		MIN_CONNECTOR_WIDTH,
		MAX_CONNECTOR_WIDTH
	)
	var chamber_width: float = (content_size.x - connector_width) * 0.5
	var chamber_position: Vector2 = Vector2(outer_margin, outer_margin)
	if not use_left_rect:
		chamber_position.x += chamber_width + connector_width
	return Rect2(
		chamber_position,
		Vector2(chamber_width, content_size.y)
	)


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), BACKGROUND_COLOR)
	var left_rect: Rect2 = _get_chamber_rect(true)
	var right_rect: Rect2 = _get_chamber_rect(false)
	_draw_connector(left_rect, right_rect)
	_draw_chamber(
		left_rect,
		_get_zone_humidity(0),
		_get_zone_availability(0),
		0
	)
	_draw_chamber(
		right_rect,
		_get_zone_humidity(1),
		_get_zone_availability(1),
		2
	)


func _draw_connector(left_rect: Rect2, right_rect: Rect2) -> void:
	var connector_height: float = minf(76.0, left_rect.size.y * 0.20)
	var connector_rect: Rect2 = Rect2(
		Vector2(
			left_rect.end.x - 4.0,
			left_rect.position.y + left_rect.size.y * 0.52
			- connector_height * 0.5
		),
		Vector2(right_rect.position.x - left_rect.end.x + 8.0, connector_height)
	)
	draw_rect(connector_rect, CONNECTOR_EDGE_COLOR)
	draw_rect(connector_rect.grow(-4.0), CONNECTOR_FILL_COLOR)
	draw_line(
		connector_rect.position + Vector2(8.0, connector_height * 0.50),
		connector_rect.end - Vector2(8.0, connector_height * 0.50),
		Color(0.62, 0.57, 0.43, 0.34),
		2.0,
		true
	)


func _draw_chamber(
	chamber_rect: Rect2,
	humidity: float,
	available: bool,
	condensation_offset: int
) -> void:
	var chamber_fill: Color = CHAMBER_DRY_COLOR.lerp(
		CHAMBER_DAMP_COLOR,
		humidity
	)
	var chamber_style: StyleBoxFlat = StyleBoxFlat.new()
	chamber_style.bg_color = chamber_fill
	chamber_style.border_color = CHAMBER_EDGE_COLOR
	chamber_style.border_width_left = CHAMBER_BORDER_WIDTH
	chamber_style.border_width_top = CHAMBER_BORDER_WIDTH
	chamber_style.border_width_right = CHAMBER_BORDER_WIDTH
	chamber_style.border_width_bottom = CHAMBER_BORDER_WIDTH
	chamber_style.corner_radius_top_left = CHAMBER_CORNER_RADIUS
	chamber_style.corner_radius_top_right = CHAMBER_CORNER_RADIUS
	chamber_style.corner_radius_bottom_left = CHAMBER_CORNER_RADIUS
	chamber_style.corner_radius_bottom_right = CHAMBER_CORNER_RADIUS
	draw_style_box(chamber_style, chamber_rect)

	var substrate_rect: Rect2 = Rect2(
		Vector2(
			chamber_rect.position.x + 10.0,
			chamber_rect.position.y + chamber_rect.size.y * 0.58
		),
		Vector2(
			chamber_rect.size.x - 20.0,
			chamber_rect.size.y * 0.36 - 8.0
		)
	)
	draw_rect(
		substrate_rect,
		SUBSTRATE_DRY_COLOR.lerp(SUBSTRATE_DAMP_COLOR, humidity)
	)
	for line_index: int in range(3):
		var line_y: float = substrate_rect.position.y + (
			float(line_index + 1) * substrate_rect.size.y / 4.0
		)
		draw_line(
			Vector2(substrate_rect.position.x + 8.0, line_y),
			Vector2(substrate_rect.end.x - 8.0, line_y + 2.0),
			Color(0.68, 0.59, 0.40, 0.18),
			2.0,
			true
		)

	_draw_condensation(chamber_rect, humidity, condensation_offset)
	if not available:
		draw_rect(chamber_rect.grow(-5.0), UNAVAILABLE_OVERLAY_COLOR)
		draw_line(
			chamber_rect.position + Vector2(24.0, 24.0),
			chamber_rect.end - Vector2(24.0, 24.0),
			CHAMBER_EDGE_COLOR,
			5.0,
			true
		)


func _draw_condensation(
	chamber_rect: Rect2,
	humidity: float,
	pattern_offset: int
) -> void:
	var droplet_count: int = clampi(
		roundi(humidity * float(CONDENSATION_RATIOS.size())),
		0,
		CONDENSATION_RATIOS.size()
	)
	var droplet_color: Color = CONDENSATION_COLOR
	droplet_color.a = lerpf(0.16, CONDENSATION_COLOR.a, humidity)
	for droplet_index: int in range(droplet_count):
		var ratio_index: int = posmod(
			droplet_index + pattern_offset,
			CONDENSATION_RATIOS.size()
		)
		var center: Vector2 = (
			chamber_rect.position
			+ chamber_rect.size * CONDENSATION_RATIOS[ratio_index]
		)
		draw_circle(
			center,
			2.5 + float(droplet_index % 2),
			droplet_color
		)


func _get_zone_humidity(zone_index: int) -> float:
	if zone_index < 0 or zone_index >= _zone_ids.size():
		return 0.0
	return _zone_humidity.get(_zone_ids[zone_index], 0.0)


func _get_zone_availability(zone_index: int) -> bool:
	if zone_index < 0 or zone_index >= _zone_ids.size():
		return true
	return _zone_available.get(_zone_ids[zone_index], true)
