class_name CombinedHabitatView
extends Control

signal worker_selection_requested(entity_id: int)
signal sugar_drop_requested
signal sugar_tool_cancel_requested

const ANT_VIEW_SCRIPT: Script = preload("res://scripts/view/ant_view.gd")

const VIEW_MINIMUM_SIZE: Vector2 = Vector2(720.0, 350.0)
const OUTER_MARGIN: float = 24.0
const WORKER_SELECTION_RADIUS: float = 28.0
const CHAMBER_CORNER_RADIUS: int = 26
const CHAMBER_BORDER_WIDTH: int = 3
const WORKER_BROOD_APPROACH_OFFSET: Vector2 = Vector2(12.0, -7.0)
const CARRIED_BROOD_OFFSET: Vector2 = Vector2(-2.0, -17.0)
const CARRIED_SUGAR_OFFSET: Vector2 = Vector2(0.0, -18.0)

const BACKGROUND_COLOR: Color = Color(0.038, 0.047, 0.044, 1.0)
const CHAMBER_DRY_COLOR: Color = Color(0.29, 0.22, 0.14, 1.0)
const CHAMBER_DAMP_COLOR: Color = Color(0.10, 0.25, 0.24, 1.0)
const CHAMBER_EDGE_COLOR: Color = Color(0.50, 0.46, 0.35, 0.92)
const SUBSTRATE_DRY_COLOR: Color = Color(0.43, 0.31, 0.18, 0.92)
const SUBSTRATE_DAMP_COLOR: Color = Color(0.16, 0.31, 0.27, 0.96)
const CONNECTOR_EDGE_COLOR: Color = Color(0.42, 0.40, 0.32, 1.0)
const CONNECTOR_FILL_COLOR: Color = Color(0.13, 0.15, 0.13, 1.0)
const CONDENSATION_COLOR: Color = Color(0.55, 0.82, 0.78, 0.48)
const FORAGING_FILL_COLOR: Color = Color(0.13, 0.19, 0.16, 1.0)
const FORAGING_EDGE_COLOR: Color = Color(0.37, 0.49, 0.38, 0.96)
const PLACEMENT_GLOW_COLOR: Color = Color(0.92, 0.77, 0.37, 0.82)
const SUGAR_COLOR: Color = Color(0.91, 0.69, 0.28, 1.0)
const SUGAR_HIGHLIGHT_COLOR: Color = Color(1.0, 0.94, 0.73, 0.92)
const SHARE_GLOW_COLOR: Color = Color(0.91, 0.69, 0.28, 0.62)
const UNAVAILABLE_OVERLAY_COLOR: Color = Color(0.025, 0.03, 0.028, 0.64)

const BROOD_SLOT_RATIOS: Array[Vector2] = [
	Vector2(0.49, 0.67),
	Vector2(0.61, 0.65),
	Vector2(0.73, 0.68),
	Vector2(0.54, 0.78),
	Vector2(0.67, 0.80),
	Vector2(0.79, 0.77),
	Vector2(0.43, 0.82),
	Vector2(0.84, 0.61),
]
const WORKER_SLOT_RATIOS: Array[Vector2] = [
	Vector2(0.34, 0.42),
	Vector2(0.48, 0.51),
	Vector2(0.61, 0.40),
	Vector2(0.71, 0.53),
]
const FORAGING_WORKER_SLOT_RATIOS: Array[Vector2] = [
	Vector2(0.30, 0.66),
	Vector2(0.48, 0.73),
	Vector2(0.66, 0.63),
	Vector2(0.77, 0.77),
]
const FOOD_SLOT_RATIOS: Array[Vector2] = [
	Vector2(0.62, 0.48),
	Vector2(0.73, 0.61),
	Vector2(0.50, 0.68),
]
const CONDENSATION_RATIOS: Array[Vector2] = [
	Vector2(0.20, 0.21),
	Vector2(0.34, 0.15),
	Vector2(0.52, 0.23),
	Vector2(0.68, 0.17),
	Vector2(0.81, 0.27),
]

var _ant_views: Dictionary[int, AntView] = {}
var _previous_snapshot: GameSnapshot
var _latest_snapshot: GameSnapshot
var _previous_entity_positions: Dictionary[int, Vector2] = {}
var _current_entity_positions: Dictionary[int, Vector2] = {}
var _interpolation_alpha: float = 1.0
var _zone_humidity: Dictionary[StringName, float] = {}
var _zone_available: Dictionary[StringName, bool] = {}
var _nursery_zone_id: StringName = &""
var _resting_zone_id: StringName = &""
var _nest_zone_id: StringName = &""
var _placement_zone_id: StringName = &""
var _sequence_phase: int = (
	ScenarioSequenceSnapshot.Phase.FOUNDING_PRELUDE
)
var _visuals_paused: bool = false
var _selected_worker_id: int = -1
var _sugar_tool_armed: bool = false

@onready var _entity_layer: Node2D = %EntityLayer
@onready var _queen_view: QueenView = %QueenView
@onready var _nursery_label: Label = %NurseryZoneLabel
@onready var _resting_label: Label = %RestingZoneLabel
@onready var _foraging_label: Label = %ForagingZoneLabel
@onready var _placement_hint: Label = %PlacementHint


func _ready() -> void:
	_queen_view.z_index = 3
	_queen_view.set_visuals_paused(_visuals_paused)
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
		if (
			_can_accept_sugar_placement()
			and _get_foraging_rect().has_point(mouse_event.position)
		):
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

	_copy_projection_state(snapshot)
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
		if removed_view.get_parent() != null:
			removed_view.get_parent().remove_child(removed_view)
		removed_view.queue_free()

	_queen_view.set_entity_id(snapshot.colony.queen_entity_id)
	_queen_view.set_simulation_tick(snapshot.simulation_tick)
	if _sugar_tool_armed and not _can_accept_sugar_placement():
		_sugar_tool_armed = false
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
	_zone_humidity.clear()
	_zone_available.clear()
	_nursery_zone_id = &""
	_resting_zone_id = &""
	_nest_zone_id = &""
	_placement_zone_id = &""
	_sequence_phase = ScenarioSequenceSnapshot.Phase.FOUNDING_PRELUDE
	_interpolation_alpha = 1.0
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


func are_visuals_paused() -> bool:
	return _visuals_paused


func get_interpolation_alpha() -> float:
	return _interpolation_alpha


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
	_sugar_tool_armed = value and _can_accept_sugar_placement()
	if _placement_hint != null:
		_placement_hint.visible = _sugar_tool_armed
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
		or snapshot.sequence == null
		or snapshot.scenario.nest_zone_id.is_empty()
		or snapshot.scenario.placement_zone_id.is_empty()
		or snapshot.scenario.nest_zone_id
			== snapshot.scenario.placement_zone_id
		or snapshot.colony.zones.size() != 3
	):
		return false

	var seen_zone_ids: Dictionary[StringName, bool] = {}
	for zone: HabitatZoneSnapshot in snapshot.colony.zones:
		if (
			zone == null
			or zone.zone_id.is_empty()
			or seen_zone_ids.has(zone.zone_id)
			or not is_finite(zone.humidity)
		):
			return false
		seen_zone_ids[zone.zone_id] = true
	if (
		not seen_zone_ids.has(snapshot.scenario.nest_zone_id)
		or not seen_zone_ids.has(snapshot.scenario.placement_zone_id)
	):
		return false

	var intermediate_zone_count: int = 0
	for zone_id: StringName in seen_zone_ids:
		if (
			zone_id != snapshot.scenario.nest_zone_id
			and zone_id != snapshot.scenario.placement_zone_id
		):
			intermediate_zone_count += 1
	if intermediate_zone_count != 1:
		return false

	var ant_snapshots_by_id: Dictionary[int, AntSnapshot] = {}
	for ant_snapshot: AntSnapshot in snapshot.colony.ants:
		if (
			ant_snapshot == null
			or ant_snapshot.entity_id < 0
			or ant_snapshots_by_id.has(ant_snapshot.entity_id)
		):
			return false
		var has_valid_zone := seen_zone_ids.has(ant_snapshot.zone_id)
		if ant_snapshot.life_stage == AntModel.LifeStage.WORKER:
			if not has_valid_zone or ant_snapshot.carrier_ant_id >= 0:
				return false
		elif has_valid_zone:
			if ant_snapshot.carrier_ant_id >= 0:
				return false
		elif (
			not ant_snapshot.zone_id.is_empty()
			or ant_snapshot.carrier_ant_id < 0
		):
			return false
		ant_snapshots_by_id[ant_snapshot.entity_id] = ant_snapshot

	for ant_snapshot: AntSnapshot in snapshot.colony.ants:
		if ant_snapshot.carrier_ant_id < 0:
			continue
		var carrier: AntSnapshot = ant_snapshots_by_id.get(
			ant_snapshot.carrier_ant_id
		)
		if (
			carrier == null
			or carrier.life_stage != AntModel.LifeStage.WORKER
			or carrier.carried_brood_id != ant_snapshot.entity_id
		):
			return false

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


func _copy_projection_state(snapshot: GameSnapshot) -> void:
	_nest_zone_id = snapshot.scenario.nest_zone_id
	_nursery_zone_id = _nest_zone_id
	_placement_zone_id = snapshot.scenario.placement_zone_id
	_resting_zone_id = &""
	_sequence_phase = snapshot.sequence.phase
	_zone_humidity.clear()
	_zone_available.clear()

	for zone: HabitatZoneSnapshot in snapshot.colony.zones:
		_zone_humidity[zone.zone_id] = clampf(zone.humidity, 0.0, 1.0)
		_zone_available[zone.zone_id] = zone.available
		if (
			zone.zone_id != _nursery_zone_id
			and zone.zone_id != _placement_zone_id
			and (
				_resting_zone_id.is_empty()
				or String(zone.zone_id) < String(_resting_zone_id)
			)
		):
			_resting_zone_id = zone.zone_id


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
		if ant_snapshot.life_stage != AntModel.LifeStage.WORKER:
			continue
		positions[ant_snapshot.entity_id] = _get_worker_position(
			ant_snapshot,
			snapshot
		)

	for ant_snapshot: AntSnapshot in snapshot.colony.ants:
		if ant_snapshot.life_stage == AntModel.LifeStage.WORKER:
			continue

		var brood_position: Vector2
		var carrier_snapshot: AntSnapshot = snapshot.colony.find_ant(
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
			var reserving_worker: AntSnapshot = snapshot.colony.find_ant(
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


func _get_worker_position(
	worker: AntSnapshot,
	snapshot: GameSnapshot
) -> Vector2:
	if worker.worker_task_state != WorkerTaskModel.State.IDLE:
		return _get_relocation_worker_position(worker, snapshot.colony)
	if (
		worker.foraging_task != null
		and worker.foraging_task.state != ForagingTaskSnapshot.State.IDLE
	):
		return _get_foraging_worker_position(worker, snapshot)
	return _get_worker_idle_position(
		_get_valid_zone_id(worker.zone_id),
		worker.entity_id
	)


func _get_relocation_worker_position(
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
			return _get_humidity_route_position(
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
			return _get_humidity_route_position(
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


func _get_foraging_worker_position(
	worker: AntSnapshot,
	snapshot: GameSnapshot
) -> Vector2:
	var task: ForagingTaskSnapshot = worker.foraging_task
	if task == null:
		return _get_worker_idle_position(
			_get_valid_zone_id(worker.zone_id),
			worker.entity_id
		)

	var progress: float = task.get_progress()
	var origin_zone_id: StringName = _get_valid_zone_id(
		task.origin_zone_id
		if not task.origin_zone_id.is_empty()
		else worker.zone_id
	)
	var target_zone_id: StringName = _get_valid_zone_id(
		task.target_zone_id
	)
	var food_position: Vector2 = _get_food_source_position_by_id(
		snapshot,
		task.target_food_source_id
	)

	match task.state:
		ForagingTaskSnapshot.State.SEEKING_FOOD:
			return _get_worker_idle_position(
				origin_zone_id,
				worker.entity_id
			)
		ForagingTaskSnapshot.State.MOVING_TO_FOOD:
			return _get_foraging_route_position(
				_get_worker_idle_position(
					origin_zone_id,
					worker.entity_id
				),
				food_position + Vector2(-16.0, 12.0),
				task.route_zone_ids,
				progress
			)
		ForagingTaskSnapshot.State.COLLECTING:
			return food_position + Vector2(-16.0, 12.0)
		ForagingTaskSnapshot.State.RETURNING_TO_NEST:
			return _get_foraging_route_position(
				food_position + Vector2(-16.0, 12.0),
				_get_share_position(worker.entity_id),
				task.route_zone_ids,
				progress
			)
		ForagingTaskSnapshot.State.SHARING:
			return _get_share_position(worker.entity_id).lerp(
				_get_worker_idle_position(
					target_zone_id,
					worker.entity_id
				),
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


func _get_humidity_route_position(
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
	route_points.append(
		_get_chamber_door_position(start_zone_id, end_zone_id)
	)
	route_points.append(
		_get_chamber_door_position(end_zone_id, start_zone_id)
	)
	route_points.append(end_position)
	return _sample_polyline(route_points, bounded_progress)


func _get_foraging_route_position(
	start_position: Vector2,
	end_position: Vector2,
	route_zone_ids: Array[StringName],
	progress: float
) -> Vector2:
	var route_points: Array[Vector2] = [start_position]
	for zone_id: StringName in route_zone_ids:
		var route_anchor: Vector2 = _get_route_anchor(
			_get_valid_zone_id(zone_id)
		)
		if route_points[-1].distance_squared_to(route_anchor) > 1.0:
			route_points.append(route_anchor)
	if route_points[-1].distance_squared_to(end_position) > 1.0:
		route_points.append(end_position)
	return _sample_polyline(
		route_points,
		clampf(progress, 0.0, 1.0)
	)


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
		total_length += points[point_index - 1].distance_to(
			points[point_index]
		)
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
			previous_position.lerp(
				current_position,
				_interpolation_alpha
			)
		)
		if (
			ant_snapshot.life_stage == AntModel.LifeStage.WORKER
			and _worker_carries_sugar(ant_snapshot)
		):
			ant_view.z_index = 7
		elif ant_snapshot.life_stage == AntModel.LifeStage.WORKER:
			ant_view.z_index = 5
		elif ant_snapshot.carrier_ant_id >= 0:
			ant_view.z_index = 6
		elif (
			ant_snapshot.reserved_by_ant_id >= 0
			and _is_brood_being_picked_up(ant_snapshot)
		):
			ant_view.z_index = 6
		else:
			ant_view.z_index = 4


func _layout_queen() -> void:
	if _queen_view == null:
		return
	var nursery_rect: Rect2 = _get_nursery_rect()
	_queen_view.set_habitat_position(
		nursery_rect.position
		+ nursery_rect.size * Vector2(0.22, 0.28)
	)


func _layout_zone_labels() -> void:
	if (
		_nursery_label == null
		or _resting_label == null
		or _foraging_label == null
		or _placement_hint == null
	):
		return
	var nursery_rect: Rect2 = _get_nursery_rect()
	var resting_rect: Rect2 = _get_resting_rect()
	var foraging_rect: Rect2 = _get_foraging_rect()
	_nursery_label.position = nursery_rect.position + Vector2(12.0, 9.0)
	_resting_label.position = resting_rect.position + Vector2(12.0, 9.0)
	_foraging_label.position = foraging_rect.position + Vector2(12.0, 9.0)
	_foraging_label.visible = _is_foraging_area_revealed()
	_placement_hint.position = Vector2(
		foraging_rect.get_center().x - 82.0,
		foraging_rect.position.y + 39.0
	)
	_placement_hint.visible = _sugar_tool_armed


func _find_worker_at_position(local_position: Vector2) -> int:
	if _latest_snapshot == null:
		return -1

	var selection_radius_squared: float = (
		WORKER_SELECTION_RADIUS * WORKER_SELECTION_RADIUS
	)
	var closest_distance_squared: float = selection_radius_squared
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
				is_equal_approx(
					distance_squared,
					closest_distance_squared
				)
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


func _is_brood_being_picked_up(brood: AntSnapshot) -> bool:
	if _latest_snapshot == null:
		return false
	var worker: AntSnapshot = _latest_snapshot.colony.find_ant(
		brood.reserved_by_ant_id
	)
	return (
		worker != null
		and worker.worker_task_state == WorkerTaskModel.State.PICKING_UP
	)


func _worker_carries_sugar(worker: AntSnapshot) -> bool:
	return (
		worker != null
		and worker.life_stage == AntModel.LifeStage.WORKER
		and worker.foraging_task != null
		and worker.foraging_task.carried_portions > 0
	)


func _can_accept_sugar_placement() -> bool:
	return (
		_latest_snapshot != null
		and _latest_snapshot.scenario != null
		and _sequence_phase
			== ScenarioSequenceSnapshot.Phase.SUGAR_FORAGING
		and _latest_snapshot.scenario.place_action_available
		and not _latest_snapshot.scenario.place_action_pending
	)


func _is_foraging_area_revealed() -> bool:
	return (
		_sequence_phase == ScenarioSequenceSnapshot.Phase.SUGAR_FORAGING
		or _sequence_phase
			== ScenarioSequenceSnapshot.Phase.OBSERVATION_SUMMARY
	)


func _get_worker_idle_position(
	zone_id: StringName,
	entity_id: int
) -> Vector2:
	var zone_rect: Rect2 = _get_zone_rect(zone_id)
	var slot_ratios: Array[Vector2] = WORKER_SLOT_RATIOS
	if zone_id == _placement_zone_id:
		slot_ratios = FORAGING_WORKER_SLOT_RATIOS
	var slot_index: int = posmod(entity_id - 1, slot_ratios.size())
	return zone_rect.position + zone_rect.size * slot_ratios[slot_index]


func _get_brood_slot_position(
	zone_id: StringName,
	entity_id: int
) -> Vector2:
	var chamber_rect: Rect2 = _get_zone_rect(zone_id)
	var slot_index: int = posmod(entity_id - 1, BROOD_SLOT_RATIOS.size())
	return (
		chamber_rect.position
		+ chamber_rect.size * BROOD_SLOT_RATIOS[slot_index]
	)


func _get_brood_approach_position(
	zone_id: StringName,
	brood_entity_id: int
) -> Vector2:
	return (
		_get_brood_slot_position(zone_id, brood_entity_id)
		+ WORKER_BROOD_APPROACH_OFFSET
	)


func _get_share_position(entity_id: int) -> Vector2:
	var nursery_rect: Rect2 = _get_nursery_rect()
	var offset_index: int = posmod(entity_id - 1, 3)
	return (
		nursery_rect.position
		+ nursery_rect.size * Vector2(0.38, 0.46)
		+ Vector2(float(offset_index) * 8.0, float(offset_index - 1) * 5.0)
	)


func _get_food_source_position_by_id(
	snapshot: GameSnapshot,
	food_source_id: int
) -> Vector2:
	for food_source: FoodSourceSnapshot in snapshot.colony.food_sources:
		if food_source.food_source_id == food_source_id:
			return _get_food_source_position(food_source)
	return _get_food_slot_position(food_source_id)


func _get_food_source_position(
	food_source: FoodSourceSnapshot
) -> Vector2:
	if food_source == null:
		return _get_foraging_rect().get_center()
	return _get_food_slot_position(food_source.food_source_id)


func _get_food_slot_position(food_source_id: int) -> Vector2:
	var foraging_rect: Rect2 = _get_foraging_rect()
	var slot_index: int = posmod(
		maxi(food_source_id - 1, 0),
		FOOD_SLOT_RATIOS.size()
	)
	return (
		foraging_rect.position
		+ foraging_rect.size * FOOD_SLOT_RATIOS[slot_index]
	)


func _get_chamber_door_position(
	zone_id: StringName,
	other_zone_id: StringName
) -> Vector2:
	var chamber_rect: Rect2 = _get_zone_rect(zone_id)
	var center_y: float = chamber_rect.position.y + chamber_rect.size.y * 0.53
	if (
		zone_id == _nursery_zone_id
		or other_zone_id == _placement_zone_id
	):
		return Vector2(chamber_rect.end.x, center_y)
	return Vector2(chamber_rect.position.x, center_y)


func _get_route_anchor(zone_id: StringName) -> Vector2:
	if zone_id == _nursery_zone_id:
		return _get_chamber_door_position(
			_nursery_zone_id,
			_resting_zone_id
		)
	if zone_id == _resting_zone_id:
		return _get_resting_rect().get_center()
	if zone_id == _placement_zone_id:
		var foraging_rect: Rect2 = _get_foraging_rect()
		return Vector2(
			foraging_rect.position.x + 10.0,
			foraging_rect.get_center().y
		)
	return _get_zone_rect(zone_id).get_center()


func _get_valid_zone_id(zone_id: StringName) -> StringName:
	if _zone_humidity.has(zone_id):
		return zone_id
	if not _nursery_zone_id.is_empty():
		return _nursery_zone_id
	return &""


func _get_zone_rect(zone_id: StringName) -> Rect2:
	if zone_id == _resting_zone_id:
		return _get_resting_rect()
	if zone_id == _placement_zone_id:
		return _get_foraging_rect()
	return _get_nursery_rect()


func _get_effective_size() -> Vector2:
	return Vector2(
		maxf(size.x, VIEW_MINIMUM_SIZE.x),
		maxf(size.y, VIEW_MINIMUM_SIZE.y)
	)


func _get_nursery_rect() -> Rect2:
	var effective_size: Vector2 = _get_effective_size()
	var content_size: Vector2 = (
		effective_size - Vector2.ONE * OUTER_MARGIN * 2.0
	)
	return Rect2(
		Vector2(OUTER_MARGIN, OUTER_MARGIN + 18.0),
		Vector2(content_size.x * 0.29, content_size.y - 36.0)
	)


func _get_resting_rect() -> Rect2:
	var effective_size: Vector2 = _get_effective_size()
	var content_size: Vector2 = (
		effective_size - Vector2.ONE * OUTER_MARGIN * 2.0
	)
	return Rect2(
		Vector2(
			OUTER_MARGIN + content_size.x * 0.35,
			OUTER_MARGIN + 18.0
		),
		Vector2(content_size.x * 0.29, content_size.y - 36.0)
	)


func _get_foraging_rect() -> Rect2:
	var effective_size: Vector2 = _get_effective_size()
	var content_size: Vector2 = (
		effective_size - Vector2.ONE * OUTER_MARGIN * 2.0
	)
	return Rect2(
		Vector2(
			OUTER_MARGIN + content_size.x * 0.72,
			OUTER_MARGIN
		),
		Vector2(content_size.x * 0.28, content_size.y)
	)


func _get_chamber_connector_rect() -> Rect2:
	var nursery_rect: Rect2 = _get_nursery_rect()
	var resting_rect: Rect2 = _get_resting_rect()
	var connector_height: float = minf(72.0, nursery_rect.size.y * 0.24)
	return Rect2(
		Vector2(
			nursery_rect.end.x - 4.0,
			nursery_rect.position.y
				+ nursery_rect.size.y * 0.53
				- connector_height * 0.5
		),
		Vector2(
			resting_rect.position.x - nursery_rect.end.x + 8.0,
			connector_height
		)
	)


func _get_exit_tunnel_rect() -> Rect2:
	var resting_rect: Rect2 = _get_resting_rect()
	var foraging_rect: Rect2 = _get_foraging_rect()
	var tunnel_height: float = minf(78.0, resting_rect.size.y * 0.26)
	return Rect2(
		Vector2(
			resting_rect.end.x - 4.0,
			resting_rect.position.y
				+ resting_rect.size.y * 0.53
				- tunnel_height * 0.5
		),
		Vector2(
			foraging_rect.position.x - resting_rect.end.x + 8.0,
			tunnel_height
		)
	)


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), BACKGROUND_COLOR)
	var nursery_rect: Rect2 = _get_nursery_rect()
	var resting_rect: Rect2 = _get_resting_rect()
	var foraging_rect: Rect2 = _get_foraging_rect()

	_draw_tunnel(_get_chamber_connector_rect(), true)
	_draw_tunnel(
		_get_exit_tunnel_rect(),
		_is_foraging_area_revealed()
	)
	_draw_chamber(
		nursery_rect,
		_get_zone_humidity(_nursery_zone_id),
		_is_zone_available(_nursery_zone_id),
		0
	)
	_draw_chamber(
		resting_rect,
		_get_zone_humidity(_resting_zone_id),
		_is_zone_available(_resting_zone_id),
		2
	)
	_draw_foraging_area(
		foraging_rect,
		_is_foraging_area_revealed()
			and _is_zone_available(_placement_zone_id)
	)

	if _sugar_tool_armed:
		_draw_placement_target(foraging_rect)
	if _latest_snapshot != null:
		_draw_food_sources(_latest_snapshot)
		_draw_task_effects(_latest_snapshot)


func _draw_chamber(
	chamber_rect: Rect2,
	humidity: float,
	available: bool,
	condensation_offset: int
) -> void:
	var chamber_style: StyleBoxFlat = StyleBoxFlat.new()
	chamber_style.bg_color = CHAMBER_DRY_COLOR.lerp(
		CHAMBER_DAMP_COLOR,
		humidity
	)
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
			chamber_rect.position.x + 9.0,
			chamber_rect.position.y + chamber_rect.size.y * 0.59
		),
		Vector2(
			chamber_rect.size.x - 18.0,
			chamber_rect.size.y * 0.34 - 7.0
		)
	)
	draw_rect(
		substrate_rect,
		SUBSTRATE_DRY_COLOR.lerp(SUBSTRATE_DAMP_COLOR, humidity)
	)
	for line_index: int in range(3):
		var line_y: float = (
			substrate_rect.position.y
			+ float(line_index + 1) * substrate_rect.size.y / 4.0
		)
		draw_line(
			Vector2(substrate_rect.position.x + 7.0, line_y),
			Vector2(substrate_rect.end.x - 7.0, line_y + 2.0),
			Color(0.68, 0.59, 0.40, 0.18),
			2.0,
			true
		)
	_draw_condensation(chamber_rect, humidity, condensation_offset)
	if not available:
		draw_rect(chamber_rect.grow(-5.0), UNAVAILABLE_OVERLAY_COLOR)


func _draw_condensation(
	chamber_rect: Rect2,
	humidity: float,
	offset: int
) -> void:
	var visibility: float = clampf((humidity - 0.25) / 0.55, 0.0, 1.0)
	if visibility <= 0.01:
		return
	var drop_color: Color = CONDENSATION_COLOR
	drop_color.a *= visibility
	for drop_index: int in range(CONDENSATION_RATIOS.size()):
		var ratio_index: int = posmod(
			drop_index + offset,
			CONDENSATION_RATIOS.size()
		)
		var center: Vector2 = (
			chamber_rect.position
			+ chamber_rect.size * CONDENSATION_RATIOS[ratio_index]
		)
		draw_circle(
			center,
			2.0 + float(drop_index % 2),
			drop_color
		)


func _draw_tunnel(rect: Rect2, active: bool) -> void:
	draw_rect(rect, CONNECTOR_EDGE_COLOR)
	draw_rect(rect.grow(-4.0), CONNECTOR_FILL_COLOR)
	draw_line(
		Vector2(rect.position.x + 8.0, rect.get_center().y),
		Vector2(rect.end.x - 8.0, rect.get_center().y),
		Color(0.62, 0.57, 0.43, 0.30),
		2.0,
		true
	)
	if not active:
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
	var center: Vector2 = _get_food_slot_position(1)
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


func _get_zone_humidity(zone_id: StringName) -> float:
	return _zone_humidity.get(zone_id, 0.5)


func _is_zone_available(zone_id: StringName) -> bool:
	if zone_id.is_empty():
		return true
	return _zone_available.get(zone_id, true)
