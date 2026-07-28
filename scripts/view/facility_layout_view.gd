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
	if _snapshot == null or _snapshot.action_pending:
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
	if _snapshot == null or _snapshot.action_pending:
		return false
	var facility: FacilitySnapshot = _snapshot.get_facility(
		_selected_facility_id
	)
	if facility == null or not facility.player_removable:
		return false
	rotation_requested.emit(
		facility.facility_id,
		posmod(facility.orientation + 1, 4)
	)
	return true


func request_remove_selected() -> bool:
	if _snapshot == null or _snapshot.action_pending:
		return false
	var facility: FacilitySnapshot = _snapshot.get_facility(
		_selected_facility_id
	)
	if facility == null or not facility.player_removable:
		return false
	removal_requested.emit(facility.facility_id)
	return true


func select_next_facility() -> bool:
	if _snapshot == null or _snapshot.facilities.is_empty():
		return false
	var candidate_ids: Array[int] = []
	for facility: FacilitySnapshot in _snapshot.facilities:
		if facility.player_removable:
			candidate_ids.append(facility.facility_id)
	if candidate_ids.is_empty():
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
	if (
		_snapshot == null
		or _snapshot.action_pending
		or _placement_type_id.is_empty()
		or not _snapshot.can_place(
			_placement_type_id,
			_placement_slot,
			_placement_orientation
		)
	):
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
	for facility: FacilitySnapshot in _snapshot.facilities:
		if facility.available:
			_draw_facility(facility)
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
	var inset: float = 4.0 * _camera_zoom
	rect = rect.grow(-inset)
	_facility_hit_rects[facility.facility_id] = rect
	var selected: bool = facility.facility_id == _selected_facility_id
	var fill: Color = (
		FACILITY_COLOR if facility.player_removable else FIXED_FACILITY_COLOR
	)
	draw_rect(rect, fill, true)
	draw_rect(
		rect,
		SELECTED_COLOR if selected else FACILITY_EDGE,
		false,
		3.0 if selected else 2.0
	)
	var center: Vector2 = rect.get_center()
	match facility.type_id:
		&"test_tube_nest":
			draw_line(
				Vector2(rect.position.x + 12.0, center.y),
				Vector2(rect.end.x - 12.0, center.y),
				FACILITY_EDGE,
				8.0,
				true
			)
		&"micro_feeding_port":
			draw_circle(center, maxf(5.0, 10.0 * _camera_zoom), FACILITY_EDGE)
		&"small_foraging_box":
			draw_rect(rect.grow(-10.0 * _camera_zoom), FACILITY_EDGE, false, 3.0)
		&"connector_gate":
			draw_line(
				Vector2(center.x, rect.position.y + 8.0),
				Vector2(center.x, rect.end.y - 8.0),
				SELECTED_COLOR,
				5.0
			)
		_:
			draw_line(
				Vector2(rect.position.x + 8.0, center.y),
				Vector2(rect.end.x - 8.0, center.y),
				FACILITY_EDGE,
				5.0
			)
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


func _draw_hud() -> void:
	var font: Font = ThemeDB.fallback_font
	var title: String = tr("R7_LAYOUT_VIEW_TITLE")
	var hint: String = (
		tr("R7_LAYOUT_PLACEMENT_HINT")
		if is_placing()
		else tr("R7_LAYOUT_NAVIGATION_HINT")
	)
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
		&"connector_gate":
			return tr("R7_FACILITY_CONNECTOR_GATE")
		&"light_cover":
			return tr("FACILITY_LIGHT_COVER")
	return tr("FACILITY_UNKNOWN")
