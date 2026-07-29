class_name FacilityLayoutView
extends Control

signal placement_requested(
	type_id: StringName,
	slot: Vector2i,
	orientation: int
)
signal rotation_requested(facility_id: int, orientation: int)
signal removal_requested(facility_id: int)
signal selection_changed(facility_id: int)
signal camera_changed(zoom: float, offset: Vector2)
signal interaction_feedback(feedback: int)

enum PlacementCue {
	NONE,
	VALID,
	INVALID,
}

enum InteractionFeedback {
	PLACEMENT_UNAVAILABLE,
	PLACEMENT_INVALID,
	SELECTION_REQUIRED,
	ACTION_PENDING,
}

const CELL_SIZE: float = 64.0
const MIN_ZOOM: float = 0.65
const MAX_ZOOM: float = 1.75
const ZOOM_STEP: float = 0.15
const PAN_STEP: float = 42.0

const BACKGROUND_COLOR: Color = Color(0.035, 0.048, 0.046, 0.985)
const GRID_COLOR: Color = Color(0.24, 0.31, 0.28, 0.52)
const GRID_AXIS_COLOR: Color = Color(0.44, 0.53, 0.45, 0.72)
const FACILITY_COLOR: Color = Color(0.18, 0.29, 0.25, 1.0)
const FACILITY_EDGE: Color = Color(0.58, 0.68, 0.52, 0.95)
const FIXED_FACILITY_COLOR: Color = Color(0.15, 0.21, 0.20, 1.0)
const SELECTED_COLOR: Color = Color(0.94, 0.72, 0.30, 1.0)
const VALID_PREVIEW_COLOR: Color = Color(0.32, 0.72, 0.47, 0.48)
const INVALID_PREVIEW_COLOR: Color = Color(0.82, 0.29, 0.25, 0.46)
const TEXT_COLOR: Color = Color(0.82, 0.87, 0.79, 1.0)
const MUTED_TEXT_COLOR: Color = Color(0.56, 0.65, 0.60, 1.0)
const HUMIDITY_COLOR: Color = Color(0.20, 0.54, 0.72, 0.88)
const POLLUTION_COLOR: Color = Color(0.67, 0.47, 0.22, 0.9)
const SUGAR_COLOR: Color = Color(0.96, 0.73, 0.28, 0.95)
const PROTEIN_COLOR: Color = Color(0.78, 0.34, 0.24, 0.95)
const CONNECTION_COLOR: Color = Color(0.46, 0.65, 0.56, 0.8)
const CLOSED_CONNECTION_COLOR: Color = Color(0.75, 0.28, 0.24, 0.9)
const METAL_DARK: Color = Color(0.12, 0.13, 0.11, 1.0)
const METAL_MID: Color = Color(0.43, 0.40, 0.29, 1.0)
const METAL_LIGHT: Color = Color(0.74, 0.67, 0.43, 0.92)
const GLASS_DARK: Color = Color(0.055, 0.105, 0.105, 0.94)
const GLASS_LIGHT: Color = Color(0.58, 0.82, 0.76, 0.74)
const SUBSTRATE_COLOR: Color = Color(0.39, 0.27, 0.14, 0.96)
const FACILITY_SHADOW: Color = Color(0.0, 0.0, 0.0, 0.36)
const PRODUCTION_FACILITY_TYPES: Array[StringName] = [
	&"test_tube_nest",
	&"micro_feeding_port",
	&"small_foraging_box",
	&"connector_tube",
	&"connector_elbow",
	&"connector_gate",
	&"light_cover",
	&"hydration_module",
	&"sugar_station",
	&"protein_dish",
	&"waste_tray",
	&"dual_chamber_nest",
]

var _snapshot: HabitatLayoutSnapshot
var _camera_zoom: float = 1.0
var _camera_offset: Vector2 = Vector2.ZERO
var _selected_facility_id: int = -1
var _placement_type_id: StringName = &""
var _placement_slot: Vector2i = Vector2i.ZERO
var _placement_orientation: int = 0
var _dragging: bool = false
var _drag_anchor: Vector2 = Vector2.ZERO
var _facility_hit_rects: Dictionary[int, Rect2] = {}


func _ready() -> void:
	focus_mode = Control.FOCUS_ALL
	mouse_filter = Control.MOUSE_FILTER_STOP
	queue_redraw()


func has_production_style(type_id: StringName) -> bool:
	return PRODUCTION_FACILITY_TYPES.has(type_id)


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_clamp_camera_offset()
		queue_redraw()


func apply_snapshot(snapshot: HabitatLayoutSnapshot) -> bool:
	if snapshot == null or not snapshot.active:
		return false
	_snapshot = snapshot
	if _snapshot.get_facility(_selected_facility_id) == null:
		_set_selected_facility(-1)
	if (
		not _placement_type_id.is_empty()
		and not _has_placement_options(_placement_type_id)
	):
		cancel_placement()
	queue_redraw()
	return true


func begin_placement(type_id: StringName) -> bool:
	if _snapshot == null:
		interaction_feedback.emit(
			InteractionFeedback.PLACEMENT_UNAVAILABLE
		)
		return false
	if _snapshot.action_pending:
		interaction_feedback.emit(InteractionFeedback.ACTION_PENDING)
		return false
	for option: FacilityPlacementOptionSnapshot in (
		_snapshot.placement_options
	):
		if option.type_id != type_id:
			continue
		_placement_type_id = type_id
		_placement_slot = option.slot
		_placement_orientation = option.orientation
		_set_selected_facility(-1)
		grab_focus()
		queue_redraw()
		return true
	interaction_feedback.emit(InteractionFeedback.PLACEMENT_UNAVAILABLE)
	return false


func cancel_placement() -> void:
	_placement_type_id = &""
	queue_redraw()


func is_placing() -> bool:
	return not _placement_type_id.is_empty()


func get_placement_slot() -> Vector2i:
	return _placement_slot


func get_placement_orientation() -> int:
	return _placement_orientation


func get_placement_cue() -> PlacementCue:
	if not is_placing() or _snapshot == null:
		return PlacementCue.NONE
	return (
		PlacementCue.VALID
		if _snapshot.can_place(
			_placement_type_id,
			_placement_slot,
			_placement_orientation
		)
		else PlacementCue.INVALID
	)


func get_selected_facility_id() -> int:
	return _selected_facility_id


func get_camera_zoom() -> float:
	return _camera_zoom


func get_camera_offset() -> Vector2:
	return _camera_offset


func zoom_in() -> void:
	set_camera_zoom(_camera_zoom + ZOOM_STEP)


func zoom_out() -> void:
	set_camera_zoom(_camera_zoom - ZOOM_STEP)


func set_camera_zoom(value: float) -> void:
	if not is_finite(value):
		return
	var next_zoom: float = clampf(value, MIN_ZOOM, MAX_ZOOM)
	if is_equal_approx(next_zoom, _camera_zoom):
		return
	_camera_zoom = next_zoom
	_clamp_camera_offset()
	camera_changed.emit(_camera_zoom, _camera_offset)
	queue_redraw()


func reset_camera() -> void:
	_camera_zoom = 1.0
	_camera_offset = Vector2.ZERO
	camera_changed.emit(_camera_zoom, _camera_offset)
	queue_redraw()


func pan_by(delta: Vector2) -> void:
	if not delta.is_finite():
		return
	_camera_offset += delta
	_clamp_camera_offset()
	camera_changed.emit(_camera_zoom, _camera_offset)
	queue_redraw()


func handle_keyboard_action(keycode: Key) -> bool:
	if not visible or _snapshot == null:
		return false
	match keycode:
		KEY_P:
			return begin_placement(CampaignState.FACILITY_SMALL_FORAGING_BOX)
		KEY_ESCAPE:
			if is_placing():
				cancel_placement()
				return true
		KEY_ENTER, KEY_KP_ENTER:
			return _submit_current_placement()
		KEY_R:
			if is_placing():
				_placement_orientation = posmod(
					_placement_orientation + 1,
					4
				)
				queue_redraw()
				return true
			return request_rotate_selected()
		KEY_DELETE, KEY_BACKSPACE:
			return request_remove_selected()
		KEY_TAB:
			return select_next_facility()
		KEY_EQUAL, KEY_PLUS, KEY_KP_ADD:
			zoom_in()
			return true
		KEY_MINUS, KEY_KP_SUBTRACT:
			zoom_out()
			return true
		KEY_0, KEY_KP_0:
			reset_camera()
			return true
		KEY_W:
			pan_by(Vector2(0.0, PAN_STEP))
			return true
		KEY_A:
			pan_by(Vector2(PAN_STEP, 0.0))
			return true
		KEY_S:
			pan_by(Vector2(0.0, -PAN_STEP))
			return true
		KEY_D:
			pan_by(Vector2(-PAN_STEP, 0.0))
			return true
		KEY_UP:
			return _move_cursor_or_camera(Vector2i.UP)
		KEY_RIGHT:
			return _move_cursor_or_camera(Vector2i.RIGHT)
		KEY_DOWN:
			return _move_cursor_or_camera(Vector2i.DOWN)
		KEY_LEFT:
			return _move_cursor_or_camera(Vector2i.LEFT)
	return false


func request_rotate_selected() -> bool:
	if _snapshot == null:
		interaction_feedback.emit(InteractionFeedback.SELECTION_REQUIRED)
		return false
	if _snapshot.action_pending:
		interaction_feedback.emit(InteractionFeedback.ACTION_PENDING)
		return false
	var facility: FacilitySnapshot = _snapshot.get_facility(
		_selected_facility_id
	)
	if facility == null or not facility.player_removable:
		interaction_feedback.emit(InteractionFeedback.SELECTION_REQUIRED)
		return false
	rotation_requested.emit(
		facility.facility_id,
		posmod(facility.orientation + 1, 4)
	)
	return true


func request_remove_selected() -> bool:
	if _snapshot == null:
		interaction_feedback.emit(InteractionFeedback.SELECTION_REQUIRED)
		return false
	if _snapshot.action_pending:
		interaction_feedback.emit(InteractionFeedback.ACTION_PENDING)
		return false
	var facility: FacilitySnapshot = _snapshot.get_facility(
		_selected_facility_id
	)
	if facility == null or not facility.player_removable:
		interaction_feedback.emit(InteractionFeedback.SELECTION_REQUIRED)
		return false
	removal_requested.emit(facility.facility_id)
	return true


func select_next_facility() -> bool:
	if _snapshot == null or _snapshot.facilities.is_empty():
		interaction_feedback.emit(InteractionFeedback.SELECTION_REQUIRED)
		return false
	var candidate_ids: Array[int] = []
	for facility: FacilitySnapshot in _snapshot.facilities:
		if facility.player_removable:
			candidate_ids.append(facility.facility_id)
	if candidate_ids.is_empty():
		interaction_feedback.emit(InteractionFeedback.SELECTION_REQUIRED)
		return false
	candidate_ids.sort()
	var next_index: int = 0
	var current_index: int = candidate_ids.find(_selected_facility_id)
	if current_index >= 0:
		next_index = posmod(current_index + 1, candidate_ids.size())
	_set_selected_facility(candidate_ids[next_index])
	cancel_placement()
	return true


func _gui_input(event: InputEvent) -> void:
	var button: InputEventMouseButton = event as InputEventMouseButton
	if button != null:
		if button.button_index == MOUSE_BUTTON_WHEEL_UP and button.pressed:
			zoom_in()
			accept_event()
			return
		if button.button_index == MOUSE_BUTTON_WHEEL_DOWN and button.pressed:
			zoom_out()
			accept_event()
			return
		if button.button_index in [
			MOUSE_BUTTON_MIDDLE,
			MOUSE_BUTTON_RIGHT,
		]:
			_dragging = button.pressed
			_drag_anchor = button.position
			if button.pressed:
				grab_focus()
			accept_event()
			return
		if button.button_index == MOUSE_BUTTON_LEFT and button.pressed:
			_handle_primary_click(button.position)
			accept_event()
			return
	var motion: InputEventMouseMotion = event as InputEventMouseMotion
	if motion != null and _dragging:
		pan_by(motion.position - _drag_anchor)
		_drag_anchor = motion.position
		accept_event()
	elif motion != null and is_placing():
		_placement_slot = _view_to_slot(motion.position)
		queue_redraw()


func _handle_primary_click(local_position: Vector2) -> void:
	grab_focus()
	if is_placing():
		_placement_slot = _view_to_slot(local_position)
		_submit_current_placement()
		queue_redraw()
		return
	var selected_id: int = -1
	var stable_ids: Array[int] = []
	stable_ids.assign(_facility_hit_rects.keys())
	stable_ids.sort()
	stable_ids.reverse()
	for facility_id: int in stable_ids:
		if _facility_hit_rects[facility_id].has_point(local_position):
			selected_id = facility_id
			break
	_set_selected_facility(selected_id)
	queue_redraw()


func _move_cursor_or_camera(direction: Vector2i) -> bool:
	if is_placing():
		_placement_slot += direction
		_placement_slot.x = clampi(
			_placement_slot.x,
			0,
			maxi(0, _snapshot.grid_size.x - 1)
		)
		_placement_slot.y = clampi(
			_placement_slot.y,
			0,
			maxi(0, _snapshot.grid_size.y - 1)
		)
		queue_redraw()
		return true
	pan_by(-Vector2(direction) * PAN_STEP)
	return true


func _submit_current_placement() -> bool:
	if _snapshot == null or _placement_type_id.is_empty():
		interaction_feedback.emit(
			InteractionFeedback.PLACEMENT_UNAVAILABLE
		)
		return false
	if _snapshot.action_pending:
		interaction_feedback.emit(InteractionFeedback.ACTION_PENDING)
		return false
	if not _snapshot.can_place(
			_placement_type_id,
			_placement_slot,
			_placement_orientation
		):
		interaction_feedback.emit(InteractionFeedback.PLACEMENT_INVALID)
		return false
	placement_requested.emit(
		_placement_type_id,
		_placement_slot,
		_placement_orientation
	)
	return true


func _set_selected_facility(facility_id: int) -> void:
	if _selected_facility_id == facility_id:
		return
	_selected_facility_id = facility_id
	selection_changed.emit(facility_id)


func _has_placement_options(type_id: StringName) -> bool:
	if _snapshot == null:
		return false
	for option: FacilityPlacementOptionSnapshot in (
		_snapshot.placement_options
	):
		if option.type_id == type_id:
			return true
	return false


func _grid_origin() -> Vector2:
	if _snapshot == null:
		return size * 0.5
	var grid_size_pixels: Vector2 = Vector2(_snapshot.grid_size) * CELL_SIZE
	return (
		size * 0.5
		- grid_size_pixels * 0.5 * _camera_zoom
		+ _camera_offset
	)


func _world_to_view(world_position: Vector2) -> Vector2:
	return _grid_origin() + world_position * _camera_zoom


func _view_to_slot(view_position: Vector2) -> Vector2i:
	var world: Vector2 = (
		(view_position - _grid_origin()) / _camera_zoom
	)
	return Vector2i(
		floori(world.x / CELL_SIZE),
		floori(world.y / CELL_SIZE)
	)


func _slot_rect(slot: Vector2i, footprint: Vector2i) -> Rect2:
	return Rect2(
		_world_to_view(Vector2(slot) * CELL_SIZE),
		Vector2(footprint) * CELL_SIZE * _camera_zoom
	)


func _clamp_camera_offset() -> void:
	if _snapshot == null:
		return
	var grid_pixels: Vector2 = (
		Vector2(_snapshot.grid_size) * CELL_SIZE * _camera_zoom
	)
	var allowance: Vector2 = Vector2(
		maxf(size.x * 0.42, grid_pixels.x * 0.32),
		maxf(size.y * 0.42, grid_pixels.y * 0.32)
	)
	_camera_offset.x = clampf(
		_camera_offset.x,
		-allowance.x,
		allowance.x
	)
	_camera_offset.y = clampf(
		_camera_offset.y,
		-allowance.y,
		allowance.y
	)


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), BACKGROUND_COLOR)
	if _snapshot == null:
		return
	_facility_hit_rects.clear()
	_draw_grid()
	_draw_connections()
	for facility: FacilitySnapshot in _snapshot.facilities:
		if facility.available:
			_draw_facility(facility)
	for facility: FacilitySnapshot in _snapshot.facilities:
		if (
			facility.available
			and facility.placement_layer
				!= FacilityData.PlacementLayer.OVERLAY
		):
			_draw_facility_label(facility)
	if is_placing():
		_draw_placement_preview()
	_draw_hud()


func _draw_grid() -> void:
	var grid_size_pixels: Vector2 = Vector2(_snapshot.grid_size) * CELL_SIZE
	for x: int in range(_snapshot.grid_size.x + 1):
		var start: Vector2 = _world_to_view(
			Vector2(float(x) * CELL_SIZE, 0.0)
		)
		var end: Vector2 = _world_to_view(
			Vector2(float(x) * CELL_SIZE, grid_size_pixels.y)
		)
		draw_line(start, end, GRID_AXIS_COLOR if x == 0 else GRID_COLOR, 1.0)
	for y: int in range(_snapshot.grid_size.y + 1):
		var start: Vector2 = _world_to_view(
			Vector2(0.0, float(y) * CELL_SIZE)
		)
		var end: Vector2 = _world_to_view(
			Vector2(grid_size_pixels.x, float(y) * CELL_SIZE)
		)
		draw_line(start, end, GRID_AXIS_COLOR if y == 0 else GRID_COLOR, 1.0)


func _draw_facility(facility: FacilitySnapshot) -> void:
	var rect: Rect2 = _slot_rect(facility.slot, facility.footprint)
	var is_overlay: bool = (
		facility.placement_layer == FacilityData.PlacementLayer.OVERLAY
	)
	var inset: float = (10.0 if is_overlay else 4.0) * _camera_zoom
	rect = rect.grow(-inset)
	_facility_hit_rects[facility.facility_id] = rect
	var selected: bool = facility.facility_id == _selected_facility_id
	draw_rect(
		Rect2(
			rect.position + Vector2(3.0, 4.0) * _camera_zoom,
			rect.size
		),
		FACILITY_SHADOW,
		true
	)
	var fill: Color = (
		FACILITY_COLOR if facility.player_removable else FIXED_FACILITY_COLOR
	)
	if is_overlay:
		fill.a = 0.72
	if facility.effect_kind == FacilityEffectConfig.Kind.HABITAT_ZONE:
		fill = fill.lerp(
			HUMIDITY_COLOR,
			clampf(facility.zone_humidity, 0.0, 1.0) * 0.28
		)
		fill = fill.lerp(
			POLLUTION_COLOR,
			clampf(facility.zone_pollution, 0.0, 1.0) * 0.42
		)
		fill = fill.lightened(
			clampf(facility.zone_light_exposure, 0.0, 1.0) * 0.08
		)
	if (
		facility.effect_kind
		== FacilityEffectConfig.Kind.DUAL_CHAMBER_ZONE
	):
		_draw_dual_chamber_fill(facility, rect, fill)
	else:
		draw_rect(rect, fill, true)
	draw_rect(
		rect,
		SELECTED_COLOR if selected else FACILITY_EDGE,
		false,
		3.0 if selected else 2.0
	)
	draw_line(
		rect.position + Vector2(3.0, 3.0) * _camera_zoom,
		Vector2(rect.end.x - 3.0 * _camera_zoom, rect.position.y + 3.0 * _camera_zoom),
		Color(0.82, 0.90, 0.77, 0.18),
		maxf(1.0, _camera_zoom),
		true
	)
	var center: Vector2 = rect.get_center()
	match facility.type_id:
		&"test_tube_nest":
			var tube_rect: Rect2 = Rect2(
				Vector2(rect.position.x + 8.0 * _camera_zoom, center.y - 9.0 * _camera_zoom),
				Vector2(rect.size.x - 16.0 * _camera_zoom, 18.0 * _camera_zoom)
			)
			_draw_facility_capsule(tube_rect, GLASS_DARK, GLASS_LIGHT)
			draw_circle(
				Vector2(tube_rect.position.x + tube_rect.size.y * 0.5, center.y),
				tube_rect.size.y * 0.34,
				HUMIDITY_COLOR
			)
			draw_circle(
				Vector2(tube_rect.end.x - tube_rect.size.y * 0.52, center.y),
				tube_rect.size.y * 0.31,
				Color(0.84, 0.82, 0.69, 0.96)
			)
		&"micro_feeding_port":
			draw_circle(center + Vector2(1.5, 2.0) * _camera_zoom, 13.0 * _camera_zoom, FACILITY_SHADOW)
			draw_circle(center, 13.0 * _camera_zoom, METAL_MID)
			draw_circle(center, 9.0 * _camera_zoom, METAL_DARK)
			draw_circle(center, 5.0 * _camera_zoom, SUGAR_COLOR)
			draw_arc(center, 10.5 * _camera_zoom, PI, PI * 1.75, 12, METAL_LIGHT, 1.5 * _camera_zoom, true)
		&"small_foraging_box":
			var tray: Rect2 = rect.grow(-9.0 * _camera_zoom)
			draw_rect(tray, METAL_DARK, true)
			draw_rect(tray.grow(-3.0 * _camera_zoom), SUBSTRATE_COLOR, true)
			draw_rect(tray, METAL_LIGHT, false, 2.0 * _camera_zoom)
			for index: int in 4:
				var pebble: Vector2 = tray.get_center() + Vector2(
					float(posmod(index * 17, 31) - 15),
					float(posmod(index * 11, 19) - 9)
				) * _camera_zoom
				draw_circle(pebble, 2.2 * _camera_zoom, Color(0.65, 0.53, 0.33, 0.9))
		&"dual_chamber_nest":
			if posmod(facility.orientation, 2) == 0:
				draw_line(
					Vector2(center.x, rect.position.y),
					Vector2(center.x, rect.end.y),
					FACILITY_EDGE,
					3.0
				)
			else:
				draw_line(
					Vector2(rect.position.x, center.y),
					Vector2(rect.end.x, center.y),
					FACILITY_EDGE,
					3.0
				)
			var chamber_axis: Vector2 = (
				Vector2(rect.size.x * 0.23, 0.0)
				if posmod(facility.orientation, 2) == 0
				else Vector2(0.0, rect.size.y * 0.23)
			)
			for chamber_center: Vector2 in [
				center - chamber_axis,
				center + chamber_axis,
			]:
				draw_circle(
					chamber_center,
					minf(rect.size.x, rect.size.y) * 0.18,
					Color(0.06, 0.10, 0.085, 0.72)
				)
				draw_arc(
					chamber_center,
					minf(rect.size.x, rect.size.y) * 0.18,
					0.0,
					TAU,
					24,
					GLASS_LIGHT,
					1.5 * _camera_zoom,
					true
				)
		&"connector_tube":
			var horizontal: bool = rect.size.x >= rect.size.y
			var tube_start: Vector2 = (
				Vector2(rect.position.x + 6.0 * _camera_zoom, center.y)
				if horizontal
				else Vector2(center.x, rect.position.y + 6.0 * _camera_zoom)
			)
			var tube_end: Vector2 = (
				Vector2(rect.end.x - 6.0 * _camera_zoom, center.y)
				if horizontal
				else Vector2(center.x, rect.end.y - 6.0 * _camera_zoom)
			)
			draw_line(tube_start, tube_end, METAL_DARK, 11.0 * _camera_zoom, true)
			draw_line(tube_start, tube_end, GLASS_LIGHT, 5.0 * _camera_zoom, true)
			for collar: Vector2 in [tube_start, tube_end]:
				draw_circle(collar, 5.0 * _camera_zoom, METAL_MID)
				draw_circle(collar, 2.5 * _camera_zoom, GLASS_DARK)
		&"connector_gate":
			_draw_gate_icon(rect, center)
		&"connector_elbow":
			var elbow: PackedVector2Array = PackedVector2Array([
				Vector2(rect.position.x + 8.0 * _camera_zoom, center.y),
				center,
				Vector2(center.x, rect.position.y + 8.0 * _camera_zoom),
			])
			draw_polyline(elbow, METAL_DARK, 10.0 * _camera_zoom, true)
			draw_polyline(elbow, GLASS_LIGHT, 5.0 * _camera_zoom, true)
			draw_circle(center, 5.0 * _camera_zoom, METAL_LIGHT)
		&"light_cover":
			var cover: Rect2 = rect.grow(-7.0 * _camera_zoom)
			draw_rect(cover, Color(0.13, 0.085, 0.052, 0.98), true)
			draw_rect(cover, METAL_LIGHT, false, 2.0 * _camera_zoom)
			for index: int in 3:
				var rib_x: float = lerpf(
					cover.position.x,
					cover.end.x,
					float(index + 1) / 4.0
				)
				draw_line(
					Vector2(rib_x, cover.position.y + 4.0 * _camera_zoom),
					Vector2(rib_x, cover.end.y - 4.0 * _camera_zoom),
					Color(0.56, 0.39, 0.20, 0.8),
					2.0 * _camera_zoom
				)
		&"hydration_module":
			_draw_hydration_icon(center)
		&"sugar_station":
			_draw_dish_icon(center, SUGAR_COLOR, true)
		&"protein_dish":
			_draw_dish_icon(center, PROTEIN_COLOR, false)
		&"waste_tray":
			var tray: Rect2 = rect.grow(-11.0 * _camera_zoom)
			draw_rect(tray, METAL_DARK, true)
			draw_rect(tray, METAL_LIGHT, false, 2.5 * _camera_zoom)
			var fill_height: float = tray.size.y * facility.waste_fill_ratio
			draw_rect(
				Rect2(
					Vector2(tray.position.x, tray.end.y - fill_height),
					Vector2(tray.size.x, fill_height)
				),
				POLLUTION_COLOR,
				true
			)
			for index: int in 3:
				draw_circle(
					tray.position + Vector2(
						tray.size.x * (float(index + 1) / 4.0),
						tray.size.y * 0.35
					),
					2.2 * _camera_zoom,
					Color(0.82, 0.65, 0.34, 0.9)
				)
		_:
			draw_line(
				Vector2(rect.position.x + 8.0, center.y),
				Vector2(rect.end.x - 8.0, center.y),
				FACILITY_EDGE,
				5.0
			)


func _draw_facility_capsule(
	rect: Rect2,
	fill: Color,
	edge: Color
) -> void:
	var radius: float = rect.size.y * 0.5
	draw_rect(
		Rect2(
			rect.position + Vector2(radius, 0.0),
			Vector2(maxf(0.0, rect.size.x - radius * 2.0), rect.size.y)
		),
		fill,
		true
	)
	draw_circle(rect.position + Vector2(radius, radius), radius, fill)
	draw_circle(rect.end - Vector2(radius, radius), radius, fill)
	draw_line(
		rect.position + Vector2(radius, 1.5 * _camera_zoom),
		rect.end - Vector2(radius, -1.5 * _camera_zoom),
		edge,
		1.5 * _camera_zoom,
		true
	)


func _draw_gate_icon(rect: Rect2, center: Vector2) -> void:
	var vertical: bool = rect.size.y >= rect.size.x
	var start: Vector2 = (
		Vector2(center.x, rect.position.y + 7.0 * _camera_zoom)
		if vertical
		else Vector2(rect.position.x + 7.0 * _camera_zoom, center.y)
	)
	var end: Vector2 = (
		Vector2(center.x, rect.end.y - 7.0 * _camera_zoom)
		if vertical
		else Vector2(rect.end.x - 7.0 * _camera_zoom, center.y)
	)
	draw_line(start, end, METAL_DARK, 11.0 * _camera_zoom, true)
	draw_line(start, end, GLASS_LIGHT, 5.0 * _camera_zoom, true)
	var gate_axis: Vector2 = (
		Vector2(8.0, 0.0)
		if vertical else Vector2(0.0, 8.0)
	) * _camera_zoom
	draw_line(
		center - gate_axis,
		center + gate_axis,
		SELECTED_COLOR,
		3.0 * _camera_zoom,
		true
	)
	draw_circle(center, 4.0 * _camera_zoom, METAL_LIGHT)


func _draw_hydration_icon(center: Vector2) -> void:
	var drop: PackedVector2Array = PackedVector2Array([
		center + Vector2(0.0, -15.0) * _camera_zoom,
		center + Vector2(10.0, 1.0) * _camera_zoom,
		center + Vector2(7.0, 10.0) * _camera_zoom,
		center + Vector2(0.0, 14.0) * _camera_zoom,
		center + Vector2(-7.0, 10.0) * _camera_zoom,
		center + Vector2(-10.0, 1.0) * _camera_zoom,
	])
	draw_colored_polygon(drop, GLASS_DARK)
	draw_polyline(drop, GLASS_LIGHT, 2.0 * _camera_zoom, true)
	draw_line(
		center + Vector2(-3.0, -4.0) * _camera_zoom,
		center + Vector2(-5.0, 5.0) * _camera_zoom,
		Color(0.78, 0.96, 1.0, 0.86),
		2.0 * _camera_zoom,
		true
	)


func _draw_dish_icon(
	center: Vector2,
	contents: Color,
	is_liquid: bool
) -> void:
	draw_circle(center + Vector2(1.0, 2.0) * _camera_zoom, 14.0 * _camera_zoom, FACILITY_SHADOW)
	draw_circle(center, 14.0 * _camera_zoom, METAL_MID)
	draw_circle(center, 10.0 * _camera_zoom, METAL_DARK)
	if is_liquid:
		draw_circle(center, 7.0 * _camera_zoom, contents)
		draw_circle(
			center + Vector2(-2.5, -2.5) * _camera_zoom,
			2.0 * _camera_zoom,
			Color(1.0, 0.92, 0.62, 0.9)
		)
	else:
		for offset: Vector2 in [
			Vector2(-4.0, 2.0),
			Vector2(1.0, -3.0),
			Vector2(4.0, 4.0),
		]:
			draw_circle(
				center + offset * _camera_zoom,
				3.0 * _camera_zoom,
				contents
			)


func _draw_facility_label(facility: FacilitySnapshot) -> void:
	var rect: Rect2 = _slot_rect(facility.slot, facility.footprint)
	rect = rect.grow(-4.0 * _camera_zoom)
	var font: Font = ThemeDB.fallback_font
	var label: String = _facility_label(facility.type_id)
	draw_string(
		font,
		Vector2(rect.position.x + 8.0, rect.end.y - 8.0),
		label,
		HORIZONTAL_ALIGNMENT_LEFT,
		maxf(20.0, rect.size.x - 16.0),
		clampi(int(12.0 * _camera_zoom), 10, 18),
		TEXT_COLOR
	)


func _draw_connections() -> void:
	if _snapshot == null:
		return
	for connection: HabitatConnectionSnapshot in _snapshot.connections:
		var first: FacilitySnapshot = _find_zone_facility(
			connection.first_zone_id
		)
		var second: FacilitySnapshot = _find_zone_facility(
			connection.second_zone_id
		)
		if first == null or second == null:
			continue
		var first_center: Vector2 = _slot_rect(
			first.slot,
			first.footprint
		).get_center()
		var second_center: Vector2 = _slot_rect(
			second.slot,
			second.footprint
		).get_center()
		draw_line(
			first_center,
			second_center,
			CONNECTION_COLOR if connection.open else CLOSED_CONNECTION_COLOR,
			5.0 if connection.gated else 3.0,
			true
		)
		if connection.gated:
			var middle: Vector2 = first_center.lerp(second_center, 0.5)
			var cue_size: float = maxf(5.0, 8.0 * _camera_zoom)
			draw_circle(
				middle,
				maxf(4.0, 7.0 * _camera_zoom),
				SELECTED_COLOR if connection.open else CLOSED_CONNECTION_COLOR
			)
			if connection.open:
				draw_line(
					middle + Vector2(-cue_size, -cue_size * 0.35),
					middle + Vector2(cue_size, -cue_size * 0.35),
					TEXT_COLOR,
					2.0
				)
				draw_line(
					middle + Vector2(-cue_size, cue_size * 0.35),
					middle + Vector2(cue_size, cue_size * 0.35),
					TEXT_COLOR,
					2.0
				)
			else:
				draw_line(
					middle + Vector2(-cue_size, -cue_size),
					middle + Vector2(cue_size, cue_size),
					TEXT_COLOR,
					2.5
				)
				draw_line(
					middle + Vector2(-cue_size, cue_size),
					middle + Vector2(cue_size, -cue_size),
					TEXT_COLOR,
					2.5
				)


func _find_zone_facility(zone_id: StringName) -> FacilitySnapshot:
	var fallback: FacilitySnapshot
	for facility: FacilitySnapshot in _snapshot.facilities:
		if facility.zone_id != zone_id:
			continue
		if facility.placement_layer == FacilityData.PlacementLayer.BASE:
			return facility
		if fallback == null:
			fallback = facility
	return fallback


func _draw_placement_preview() -> void:
	var footprint: Vector2i = Vector2i.ONE
	if _placement_type_id == CampaignState.FACILITY_SMALL_FORAGING_BOX:
		footprint = (
			Vector2i(2, 2)
			if posmod(_placement_orientation, 2) == 0
			else Vector2i(2, 2)
		)
	var rect: Rect2 = _slot_rect(_placement_slot, footprint).grow(
		-4.0 * _camera_zoom
	)
	var valid: bool = _snapshot.can_place(
		_placement_type_id,
		_placement_slot,
		_placement_orientation
	)
	draw_rect(
		rect,
		VALID_PREVIEW_COLOR if valid else INVALID_PREVIEW_COLOR,
		true
	)
	draw_rect(rect, SELECTED_COLOR, false, 3.0)
	var center: Vector2 = rect.get_center()
	var cue_size: float = maxf(8.0, 14.0 * _camera_zoom)
	if valid:
		draw_line(
			center + Vector2(-cue_size, 0.0),
			center + Vector2(-cue_size * 0.25, cue_size * 0.7),
			TEXT_COLOR,
			4.0,
			true
		)
		draw_line(
			center + Vector2(-cue_size * 0.25, cue_size * 0.7),
			center + Vector2(cue_size, -cue_size * 0.75),
			TEXT_COLOR,
			4.0,
			true
		)
	else:
		draw_line(
			center + Vector2(-cue_size, -cue_size),
			center + Vector2(cue_size, cue_size),
			TEXT_COLOR,
			4.0,
			true
		)
		draw_line(
			center + Vector2(-cue_size, cue_size),
			center + Vector2(cue_size, -cue_size),
			TEXT_COLOR,
			4.0,
			true
		)


func _draw_hud() -> void:
	var font: Font = ThemeDB.fallback_font
	var title: String = tr("R7_LAYOUT_VIEW_TITLE")
	var hint: String = (
		tr("R7_LAYOUT_PLACEMENT_HINT")
		if is_placing()
		else tr("R7_LAYOUT_NAVIGATION_HINT")
	)
	if is_placing():
		hint = "%s · %s" % [
			(
				"✓ " + tr("R13_LAYOUT_PREVIEW_VALID")
				if get_placement_cue() == PlacementCue.VALID
				else "✕ " + tr("R13_LAYOUT_PREVIEW_INVALID")
			),
			hint,
		]
	draw_string(
		font,
		Vector2(18.0, 28.0),
		title,
		HORIZONTAL_ALIGNMENT_LEFT,
		size.x - 36.0,
		18,
		TEXT_COLOR
	)
	draw_string(
		font,
		Vector2(18.0, size.y - 18.0),
		hint,
		HORIZONTAL_ALIGNMENT_LEFT,
		size.x - 36.0,
		13,
		MUTED_TEXT_COLOR
	)


func _facility_label(type_id: StringName) -> String:
	match type_id:
		&"test_tube_nest":
			return tr("FACILITY_TEST_TUBE_NEST")
		&"micro_feeding_port":
			return tr("FACILITY_MICRO_FEEDING_PORT")
		&"small_foraging_box":
			return tr("FACILITY_SMALL_FORAGING_BOX")
		&"connector_tube":
			return tr("R7_FACILITY_CONNECTOR_TUBE")
		&"connector_elbow":
			return tr("R10_FACILITY_ELBOW")
		&"connector_gate":
			return tr("R7_FACILITY_CONNECTOR_GATE")
		&"light_cover":
			return tr("FACILITY_LIGHT_COVER")
		&"hydration_module":
			return tr("R8_FACILITY_HYDRATION")
		&"sugar_station":
			return tr("R8_FACILITY_SUGAR_STATION")
		&"protein_dish":
			return tr("R8_FACILITY_PROTEIN_DISH")
		&"waste_tray":
			return tr("R8_FACILITY_WASTE_TRAY")
		&"dual_chamber_nest":
			return tr("R11_FACILITY_DUAL_CHAMBER")
	return tr("FACILITY_UNKNOWN")


func _draw_dual_chamber_fill(
	facility: FacilitySnapshot,
	rect: Rect2,
	fallback: Color
) -> void:
	var brood_color: Color = _environment_fill_color(
		fallback,
		facility.zone_humidity,
		facility.zone_light_exposure,
		facility.zone_pollution
	)
	var utility_color: Color = _environment_fill_color(
		fallback,
		facility.secondary_zone_humidity,
		facility.secondary_zone_light_exposure,
		facility.secondary_zone_pollution
	)
	var first: Rect2
	var second: Rect2
	if posmod(facility.orientation, 2) == 0:
		first = Rect2(rect.position, Vector2(rect.size.x * 0.5, rect.size.y))
		second = Rect2(
			Vector2(rect.position.x + rect.size.x * 0.5, rect.position.y),
			Vector2(rect.size.x * 0.5, rect.size.y)
		)
	else:
		first = Rect2(rect.position, Vector2(rect.size.x, rect.size.y * 0.5))
		second = Rect2(
			Vector2(rect.position.x, rect.position.y + rect.size.y * 0.5),
			Vector2(rect.size.x, rect.size.y * 0.5)
		)
	if facility.orientation in [2, 3]:
		var swap: Rect2 = first
		first = second
		second = swap
	draw_rect(first, brood_color, true)
	draw_rect(second, utility_color, true)


func _environment_fill_color(
	base: Color,
	humidity: float,
	light_exposure: float,
	pollution: float
) -> Color:
	var result: Color = base.lerp(
		HUMIDITY_COLOR,
		clampf(humidity, 0.0, 1.0) * 0.28
	)
	result = result.lerp(
		POLLUTION_COLOR,
		clampf(pollution, 0.0, 1.0) * 0.42
	)
	return result.lightened(
		clampf(light_exposure, 0.0, 1.0) * 0.08
	)
