class_name Act1TestTubeView
extends Control

signal worker_selection_requested(entity_id: int)
signal facility_placement_requested(
	type_id: StringName,
	slot: Vector2i,
	orientation: int
)
signal facility_rotation_requested(facility_id: int, orientation: int)
signal facility_removal_requested(facility_id: int)
signal facility_selection_changed(facility_id: int)

const ANT_VIEW_SCRIPT: Script = preload("res://scripts/view/ant_view.gd")

const GLASS_FILL: Color = Color(0.075, 0.105, 0.108, 0.96)
const GLASS_EDGE: Color = Color(0.55, 0.68, 0.65, 0.78)
const GLASS_HIGHLIGHT: Color = Color(0.84, 0.94, 0.89, 0.25)
const WATER_COLOR: Color = Color(0.20, 0.48, 0.58, 0.52)
const COTTON_COLOR: Color = Color(0.78, 0.80, 0.72, 0.96)
const COTTON_SHADOW: Color = Color(0.38, 0.41, 0.36, 0.92)
const FLOOR_COLOR: Color = Color(0.34, 0.30, 0.23, 0.78)
const COVER_COLOR: Color = Color(0.11, 0.085, 0.07, 0.72)
const COVER_EDGE: Color = Color(0.68, 0.54, 0.31, 0.56)
const PORT_COLOR: Color = Color(0.36, 0.39, 0.34, 0.98)
const SUGAR_COLOR: Color = Color(0.95, 0.72, 0.28, 0.96)
const SUGAR_GLOW: Color = Color(1.0, 0.86, 0.48, 0.30)
const CARE_GLOW: Color = Color(0.91, 0.78, 0.48, 0.22)
const WORKER_SELECTION_RADIUS: float = 28.0

var _ant_views: Dictionary[int, AntView] = {}
var _previous_snapshot: GameSnapshot
var _latest_snapshot: GameSnapshot
var _previous_positions: Dictionary[int, Vector2] = {}
var _current_positions: Dictionary[int, Vector2] = {}
var _previous_queen_position: Vector2 = Vector2.ZERO
var _current_queen_position: Vector2 = Vector2.ZERO
var _interpolation_alpha: float = 1.0
var _visuals_paused: bool = false
var _reduced_motion: bool = false
var _selected_worker_id: int = -1

@onready var _entity_layer: Node2D = %EntityLayer
@onready var _queen_view: QueenView = %QueenView
@onready var _facility_layout_view: FacilityLayoutView = %FacilityLayoutView


func _ready() -> void:
	_queen_view.z_index = 5
	_queen_view.set_visuals_paused(_visuals_paused)
	_queen_view.set_reduced_motion(_reduced_motion)
	_facility_layout_view.placement_requested.connect(
		func(type_id: StringName, slot: Vector2i, orientation: int) -> void:
			facility_placement_requested.emit(type_id, slot, orientation)
	)
	_facility_layout_view.rotation_requested.connect(
		func(facility_id: int, orientation: int) -> void:
			facility_rotation_requested.emit(facility_id, orientation)
	)
	_facility_layout_view.removal_requested.connect(
		func(facility_id: int) -> void:
			facility_removal_requested.emit(facility_id)
	)
	_facility_layout_view.selection_changed.connect(
		func(facility_id: int) -> void:
			facility_selection_changed.emit(facility_id)
	)
	_layout_projection()
	queue_redraw()


func _notification(what: int) -> void:
	if what != NOTIFICATION_RESIZED:
		return
	if is_node_ready():
		_recalculate_endpoints()
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
	var worker_id: int = _find_worker_at(mouse_event.position)
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
	if not _facility_layout_view.apply_snapshot(snapshot.layout):
		return false
	_update_endpoints(snapshot)
	var present_ids: Dictionary[int, bool] = {}
	for ant: AntSnapshot in snapshot.colony.ants:
		present_ids[ant.entity_id] = true
		var view: AntView = _ant_views.get(ant.entity_id)
		if view == null:
			view = ANT_VIEW_SCRIPT.new() as AntView
			view.name = "AntView_%03d" % ant.entity_id
			_entity_layer.add_child(view)
			if not view.configure(
				ant,
				_current_positions.get(ant.entity_id, Vector2.ZERO)
			):
				view.queue_free()
				return false
			view.set_visuals_paused(_visuals_paused)
			view.set_reduced_motion(_reduced_motion)
			_ant_views[ant.entity_id] = view
		elif not view.apply_snapshot(ant):
			return false
	var removed_ids: Array[int] = []
	for entity_id: int in _ant_views:
		if not present_ids.has(entity_id):
			removed_ids.append(entity_id)
	for entity_id: int in removed_ids:
		var removed: AntView = _ant_views[entity_id]
		_ant_views.erase(entity_id)
		_previous_positions.erase(entity_id)
		_current_positions.erase(entity_id)
		removed.queue_free()
	_queen_view.set_entity_id(snapshot.colony.queen_entity_id)
	_queen_view.set_simulation_tick(snapshot.simulation_tick)
	_apply_selection()
	_layout_projection()
	queue_redraw()
	return true


func reset_projection() -> void:
	for view: AntView in _ant_views.values():
		view.queue_free()
	_ant_views.clear()
	_previous_snapshot = null
	_latest_snapshot = null
	_previous_positions.clear()
	_current_positions.clear()
	_previous_queen_position = Vector2.ZERO
	_current_queen_position = Vector2.ZERO
	_interpolation_alpha = 1.0
	_selected_worker_id = -1
	_layout_projection()
	queue_redraw()


func set_interpolation_alpha(value: float) -> void:
	if _visuals_paused:
		return
	_interpolation_alpha = (
		1.0
		if _reduced_motion
		else clampf(value, 0.0, 1.0) if is_finite(value) else 0.0
	)
	_layout_projection()
	queue_redraw()


func set_visuals_paused(value: bool) -> void:
	_visuals_paused = value
	_queen_view.set_visuals_paused(value)
	for view: AntView in _ant_views.values():
		view.set_visuals_paused(value)


func are_visuals_paused() -> bool:
	return _visuals_paused


func set_reduced_motion(value: bool) -> void:
	_reduced_motion = value
	_queen_view.set_reduced_motion(value)
	for view: AntView in _ant_views.values():
		view.set_reduced_motion(value)
	if value:
		_interpolation_alpha = 1.0
		_layout_projection()


func is_reduced_motion() -> bool:
	return _reduced_motion


func set_selected_worker_id(entity_id: int) -> bool:
	_selected_worker_id = entity_id if _is_selectable_worker(entity_id) else -1
	_apply_selection()
	return _selected_worker_id == entity_id


func get_selected_worker_id() -> int:
	return _selected_worker_id


func get_ant_view(entity_id: int) -> AntView:
	return _ant_views.get(entity_id)


func get_ant_view_count() -> int:
	return _ant_views.size()


func get_queen_view() -> QueenView:
	return _queen_view


func set_layout_mode(value: bool) -> void:
	_facility_layout_view.visible = value
	if value:
		_facility_layout_view.grab_focus()


func is_layout_mode() -> bool:
	return _facility_layout_view.visible


func begin_facility_placement(type_id: StringName) -> bool:
	if not is_layout_mode():
		set_layout_mode(true)
	return _facility_layout_view.begin_placement(type_id)


func cancel_facility_placement() -> void:
	_facility_layout_view.cancel_placement()


func handle_layout_keyboard_action(keycode: Key) -> bool:
	return _facility_layout_view.handle_keyboard_action(keycode)


func get_selected_facility_id() -> int:
	return _facility_layout_view.get_selected_facility_id()


func request_rotate_selected_facility() -> bool:
	return _facility_layout_view.request_rotate_selected()


func request_remove_selected_facility() -> bool:
	return _facility_layout_view.request_remove_selected()


func zoom_layout_in() -> void:
	_facility_layout_view.zoom_in()


func zoom_layout_out() -> void:
	_facility_layout_view.zoom_out()


func reset_layout_camera() -> void:
	_facility_layout_view.reset_camera()


func get_layout_camera_zoom() -> float:
	return _facility_layout_view.get_camera_zoom()


func get_layout_camera_offset() -> Vector2:
	return _facility_layout_view.get_camera_offset()


func get_layout_view() -> FacilityLayoutView:
	return _facility_layout_view


func _validate_snapshot(snapshot: GameSnapshot) -> bool:
	if (
		snapshot == null
		or snapshot.colony == null
		or snapshot.scenario == null
		or snapshot.nutrition == null
		or snapshot.act1 == null
		or snapshot.layout == null
		or snapshot.act1.queen_care == null
		or snapshot.colony.scenario_id != &"act1_test_tube"
		or snapshot.colony.zones.size() < 3
	):
		return false
	var seen_ids: Dictionary[int, bool] = {}
	for ant: AntSnapshot in snapshot.colony.ants:
		if ant == null or seen_ids.has(ant.entity_id):
			return false
		seen_ids[ant.entity_id] = true
	return true


func _update_endpoints(snapshot: GameSnapshot) -> void:
	if _latest_snapshot == null:
		_previous_snapshot = snapshot
		_latest_snapshot = snapshot
		_current_positions = _calculate_positions(snapshot)
		_previous_positions = _current_positions.duplicate()
		_current_queen_position = _calculate_queen_position(
			snapshot,
			_current_positions
		)
		_previous_queen_position = _current_queen_position
		return
	if snapshot.simulation_tick > _latest_snapshot.simulation_tick:
		_previous_snapshot = _latest_snapshot
		_latest_snapshot = snapshot
		_previous_positions = _calculate_positions(_previous_snapshot)
		_current_positions = _calculate_positions(_latest_snapshot)
		_previous_queen_position = _calculate_queen_position(
			_previous_snapshot,
			_previous_positions
		)
		_current_queen_position = _calculate_queen_position(
			_latest_snapshot,
			_current_positions
		)
		for entity_id: int in _current_positions:
			if not _previous_positions.has(entity_id):
				_previous_positions[entity_id] = _current_positions[entity_id]
		return
	_latest_snapshot = snapshot
	_current_positions = _calculate_positions(snapshot)
	_current_queen_position = _calculate_queen_position(
		snapshot,
		_current_positions
	)


func _recalculate_endpoints() -> void:
	if _latest_snapshot == null:
		return
	_current_positions = _calculate_positions(_latest_snapshot)
	_previous_positions = _calculate_positions(
		_previous_snapshot if _previous_snapshot != null else _latest_snapshot
	)
	_current_queen_position = _calculate_queen_position(
		_latest_snapshot,
		_current_positions
	)
	_previous_queen_position = _calculate_queen_position(
		_previous_snapshot if _previous_snapshot != null else _latest_snapshot,
		_previous_positions
	)


func _calculate_positions(
	snapshot: GameSnapshot
) -> Dictionary[int, Vector2]:
	var positions: Dictionary[int, Vector2] = {}
	for ant: AntSnapshot in snapshot.colony.ants:
		if ant.life_stage == AntModel.LifeStage.WORKER:
			positions[ant.entity_id] = _get_worker_position(ant, snapshot)
	for ant: AntSnapshot in snapshot.colony.ants:
		if ant.life_stage == AntModel.LifeStage.WORKER:
			continue
		positions[ant.entity_id] = _get_brood_position(ant.entity_id)
	return positions


func _get_worker_position(
	worker: AntSnapshot,
	snapshot: GameSnapshot
) -> Vector2:
	if (
		worker.feeding_task != null
		and worker.feeding_task.state != BroodFeedingTaskModel.State.IDLE
	):
		var brood_position: Vector2 = _get_brood_position(
			worker.feeding_task.target_brood_id
		)
		if (
			worker.feeding_task.state
			== BroodFeedingTaskModel.State.MOVING_TO_BROOD
		):
			return _get_zone_position(
				worker.feeding_task.origin_zone_id,
				worker.entity_id
			).lerp(
				brood_position + Vector2(-18.0, -6.0),
				worker.feeding_task.get_progress()
			)
		return brood_position + Vector2(-18.0, -6.0)
	if (
		worker.foraging_task != null
		and worker.foraging_task.state != ForagingTaskSnapshot.State.IDLE
	):
		var task: ForagingTaskSnapshot = worker.foraging_task
		var nest_position: Vector2 = _get_zone_position(
			task.nest_zone_id,
			worker.entity_id
		)
		var food_position: Vector2 = _get_food_position(
			task.target_food_source_id
		)
		match task.state:
			ForagingTaskSnapshot.State.SEEKING_FOOD:
				return nest_position
			ForagingTaskSnapshot.State.MOVING_TO_FOOD:
				return nest_position.lerp(food_position, task.get_progress())
			ForagingTaskSnapshot.State.COLLECTING:
				return food_position
			ForagingTaskSnapshot.State.RETURNING_TO_NEST:
				return food_position.lerp(nest_position, task.get_progress())
			ForagingTaskSnapshot.State.SHARING:
				return nest_position + Vector2(8.0, -8.0)
	return _get_zone_position(worker.zone_id, worker.entity_id)


func _calculate_queen_position(
	snapshot: GameSnapshot,
	positions: Dictionary[int, Vector2]
) -> Vector2:
	var base: Vector2 = _get_nest_rect().position + (
		_get_nest_rect().size * Vector2(0.28, 0.42)
	)
	var care: QueenCareSnapshot = snapshot.act1.queen_care
	if not care.light_cover_applied or care.target_brood_id < 0:
		return base
	var target: Vector2 = positions.get(
		care.target_brood_id,
		_get_brood_position(care.target_brood_id)
	) + Vector2(-34.0, -24.0)
	match care.care_state:
		Act1State.QueenCareState.RESTING:
			return base
		Act1State.QueenCareState.GATHERING:
			return base.lerp(target, care.get_progress())
		Act1State.QueenCareState.BROOD_CARE:
			return target + Vector2(
				sin(care.get_progress() * TAU) * 4.0,
				-cos(care.get_progress() * TAU) * 3.0
			)
	return base


func _layout_projection() -> void:
	if _queen_view != null:
		_queen_view.set_habitat_position(
			_previous_queen_position.lerp(
				_current_queen_position,
				_interpolation_alpha
			)
		)
	for entity_id: int in _ant_views:
		var view: AntView = _ant_views[entity_id]
		var current: Vector2 = _current_positions.get(
			entity_id,
			Vector2.ZERO
		)
		var previous: Vector2 = _previous_positions.get(entity_id, current)
		view.set_slot_position(
			previous.lerp(current, _interpolation_alpha)
		)
		view.z_index = (
			6
			if view.life_stage == AntModel.LifeStage.WORKER
			else 4
		)


func _get_brood_position(entity_id: int) -> Vector2:
	var nest: Rect2 = _get_nest_rect()
	var slots: Array[Vector2] = [
		Vector2(0.54, 0.70),
		Vector2(0.67, 0.74),
		Vector2(0.79, 0.68),
		Vector2(0.60, 0.83),
		Vector2(0.75, 0.84),
	]
	var slot: Vector2 = slots[posmod(entity_id - 1, slots.size())]
	return nest.position + nest.size * slot


func _get_zone_position(zone_id: StringName, entity_id: int) -> Vector2:
	var tube: Rect2 = _get_tube_rect()
	var ratio: float = 0.42
	if zone_id == &"tube_passage":
		ratio = 0.68
	elif zone_id == &"micro_feeding_port":
		ratio = 0.88
	return Vector2(
		lerpf(tube.position.x, tube.end.x, ratio),
		tube.position.y + tube.size.y * (
			0.58 + float(posmod(entity_id, 3) - 1) * 0.07
		)
	)


func _get_food_position(food_source_id: int) -> Vector2:
	var tube: Rect2 = _get_tube_rect()
	return Vector2(
		tube.end.x - tube.size.y * 0.26,
		tube.position.y + tube.size.y * (
			0.66 + float(posmod(food_source_id, 2)) * 0.06
		)
	)


func _get_tube_rect() -> Rect2:
	var margin: float = 28.0
	var tube_height: float = minf(size.y - margin * 2.0, 280.0)
	return Rect2(
		Vector2(margin, (size.y - tube_height) * 0.5),
		Vector2(maxf(200.0, size.x - margin * 2.0), tube_height)
	)


func _get_nest_rect() -> Rect2:
	var tube: Rect2 = _get_tube_rect()
	return Rect2(
		tube.position + Vector2(tube.size.y * 0.42, 10.0),
		Vector2(tube.size.x * 0.58, tube.size.y - 20.0)
	)


func _draw() -> void:
	if size.x < 280.0 or size.y < 180.0:
		return
	var tube: Rect2 = _get_tube_rect()
	_draw_capsule(tube, GLASS_FILL)
	var radius: float = tube.size.y * 0.5
	var left_center: Vector2 = tube.position + Vector2(radius, radius)
	var water_color: Color = WATER_COLOR
	if _latest_snapshot != null:
		var nest_environment: HabitatZoneSnapshot = (
			_latest_snapshot.colony.find_zone(&"test_tube_nest")
		)
		if nest_environment != null:
			water_color = WATER_COLOR.lerp(
				Color(0.16, 0.62, 0.72, 0.68),
				clampf(nest_environment.humidity, 0.0, 1.0) * 0.45
			)
	draw_circle(left_center, radius - 12.0, water_color)
	var cotton_x: float = tube.position.x + tube.size.y * 0.80
	for index: int in 7:
		var progress: float = float(index) / 6.0
		var center: Vector2 = Vector2(
			cotton_x + float(index % 2) * 4.0,
			lerpf(tube.position.y + 44.0, tube.end.y - 44.0, progress)
		)
		draw_circle(center + Vector2(2.0, 2.0), 25.0, COTTON_SHADOW)
		draw_circle(center, 22.0, COTTON_COLOR)
	var floor_y: float = tube.position.y + tube.size.y * 0.72
	draw_line(
		Vector2(cotton_x + 34.0, floor_y),
		Vector2(tube.end.x - radius * 0.35, floor_y),
		FLOOR_COLOR,
		5.0,
		true
	)
	_draw_environment_clues(tube)
	if (
		_latest_snapshot != null
		and _latest_snapshot.act1.queen_care.light_cover_applied
	):
		var nest: Rect2 = _get_nest_rect()
		var cover_rect: Rect2 = Rect2(
			Vector2(nest.position.x - 8.0, tube.position.y - 7.0),
			Vector2(nest.size.x * 0.76, tube.size.y * 0.56)
		)
		draw_style_box(
			_make_panel_style(COVER_COLOR, COVER_EDGE, 14.0, 2),
			cover_rect
		)
	var port_center: Vector2 = Vector2(
		tube.end.x - radius * 0.28,
		floor_y - 3.0
	)
	draw_circle(port_center, 19.0, PORT_COLOR)
	draw_circle(port_center, 10.0, Color(0.08, 0.10, 0.09, 1.0))
	if _latest_snapshot != null:
		for source: FoodSourceSnapshot in _latest_snapshot.colony.food_sources:
			if source.remaining_portions <= 0:
				continue
			var food: Vector2 = _get_food_position(source.food_source_id)
			draw_circle(food, 16.0, SUGAR_GLOW)
			draw_circle(food, 7.0, SUGAR_COLOR)
		for ant: AntSnapshot in _latest_snapshot.colony.ants:
			if ant.life_stage != AntModel.LifeStage.WORKER:
				continue
			var worker_position: Vector2 = _get_display_position(
				ant.entity_id
			)
			if (
				ant.foraging_task != null
				and ant.foraging_task.carried_portions > 0
			):
				var carried_position: Vector2 = (
					worker_position + Vector2(7.0, -13.0)
				)
				draw_circle(carried_position, 9.0, SUGAR_GLOW)
				draw_circle(carried_position, 4.5, SUGAR_COLOR)
			if (
				ant.feeding_task != null
				and ant.feeding_task.state
					!= BroodFeedingTaskModel.State.IDLE
			):
				draw_arc(
					worker_position,
					18.0,
					0.0,
					TAU,
					24,
					CARE_GLOW,
					3.0,
					true
				)
		if (
			_latest_snapshot.act1.queen_care.care_state
			== Act1State.QueenCareState.BROOD_CARE
		):
			draw_circle(
				_previous_queen_position.lerp(
					_current_queen_position,
					_interpolation_alpha
				),
				46.0,
				CARE_GLOW
			)
	draw_line(
		Vector2(cotton_x + 24.0, tube.position.y + 18.0),
		Vector2(tube.end.x - radius * 0.42, tube.position.y + 18.0),
		GLASS_HIGHLIGHT,
		3.0,
		true
	)
	_draw_tube_outline(tube)


func _draw_environment_clues(tube: Rect2) -> void:
	if _latest_snapshot == null:
		return
	for zone: HabitatZoneSnapshot in _latest_snapshot.colony.zones:
		if (
			zone.zone_id not in [
				&"test_tube_nest",
				&"tube_passage",
				&"micro_feeding_port",
			]
			or zone.pollution <= 0.015
		):
			continue
		var center: Vector2 = _get_zone_position(zone.zone_id, 0)
		var count: int = clampi(ceili(zone.pollution * 18.0), 1, 14)
		for index: int in count:
			var offset: Vector2 = Vector2(
				float(posmod(index * 17 + String(zone.zone_id).length(), 37))
					- 18.0,
				float(posmod(index * 11 + 5, 23)) - 11.0
			)
			var point: Vector2 = center + offset
			if tube.has_point(point):
				draw_circle(
					point,
					2.0 + float(posmod(index, 2)),
					Color(0.48, 0.34, 0.18, 0.66)
				)


func _get_display_position(entity_id: int) -> Vector2:
	var current: Vector2 = _current_positions.get(
		entity_id,
		Vector2.ZERO
	)
	var previous: Vector2 = _previous_positions.get(entity_id, current)
	return previous.lerp(current, _interpolation_alpha)


func _draw_capsule(rect: Rect2, color: Color) -> void:
	var radius: float = rect.size.y * 0.5
	draw_rect(
		Rect2(
			rect.position + Vector2(radius, 0.0),
			Vector2(rect.size.x - radius * 2.0, rect.size.y)
		),
		color
	)
	draw_circle(rect.position + Vector2(radius, radius), radius, color)
	draw_circle(rect.end - Vector2(radius, radius), radius, color)


func _draw_tube_outline(rect: Rect2) -> void:
	var radius: float = rect.size.y * 0.5
	var left: Vector2 = rect.position + Vector2(radius, radius)
	var right: Vector2 = rect.end - Vector2(radius, radius)
	draw_line(left - Vector2(0.0, radius), right - Vector2(0.0, radius), GLASS_EDGE, 3.0, true)
	draw_line(left + Vector2(0.0, radius), right + Vector2(0.0, radius), GLASS_EDGE, 3.0, true)
	draw_arc(left, radius, PI * 0.5, PI * 1.5, 40, GLASS_EDGE, 3.0, true)
	draw_arc(right, radius, -PI * 0.5, PI * 0.5, 40, GLASS_EDGE, 3.0, true)


func _make_panel_style(
	fill: Color,
	border: Color,
	radius: float,
	border_width: int
) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(int(radius))
	return style


func _find_worker_at(local_position: Vector2) -> int:
	if _latest_snapshot == null:
		return -1
	var closest_id: int = -1
	var closest_distance: float = (
		WORKER_SELECTION_RADIUS * WORKER_SELECTION_RADIUS
	)
	for ant: AntSnapshot in _latest_snapshot.colony.ants:
		if ant.life_stage != AntModel.LifeStage.WORKER:
			continue
		var view: AntView = _ant_views.get(ant.entity_id)
		if view == null:
			continue
		var distance: float = view.position.distance_squared_to(
			local_position
		)
		if distance < closest_distance:
			closest_distance = distance
			closest_id = ant.entity_id
	return closest_id


func _is_selectable_worker(entity_id: int) -> bool:
	if _latest_snapshot == null:
		return false
	var ant: AntSnapshot = _latest_snapshot.colony.find_ant(entity_id)
	return (
		ant != null
		and ant.life_stage == AntModel.LifeStage.WORKER
		and _ant_views.has(entity_id)
	)


func _apply_selection() -> void:
	if _selected_worker_id >= 0 and not _is_selectable_worker(
		_selected_worker_id
	):
		_selected_worker_id = -1
	for entity_id: int in _ant_views:
		_ant_views[entity_id].set_selected(
			entity_id == _selected_worker_id
		)
