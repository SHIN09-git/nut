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
const SELECTED_COLOR: Color = Color(0.94, 0.72, 0.30, 1.0)
const TEXT_COLOR: Color = Color(0.82, 0.87, 0.79, 1.0)
const MUTED_TEXT_COLOR: Color = Color(0.56, 0.65, 0.60, 1.0)
const CONNECTION_COLOR: Color = Color(0.46, 0.65, 0.56, 0.8)
const CLOSED_CONNECTION_COLOR: Color = Color(0.75, 0.28, 0.24, 0.9)

var _snapshot: HabitatLayoutSnapshot
var _zone_snapshots: Array[HabitatZoneSnapshot] = []
var _spatial_projection: HabitatSpatialProjection = (
	HabitatSpatialProjection.new()
)
var _zone_anchor_cache: Dictionary[StringName, Vector2] = {}
var _zone_anchor_cache_revision: int = -1
var _zone_anchor_cache_grid_size: Vector2i = Vector2i.ZERO
var _zone_anchor_cache_ready: bool = false
var _camera_zoom: float = 1.0
var _camera_offset: Vector2 = Vector2.ZERO
var _editing_enabled: bool = false
var _selected_facility_id: int = -1
var _placement_type_id: StringName = &""
var _placement_slot: Vector2i = Vector2i.ZERO
var _placement_orientation: int = 0
var _dragging: bool = false
var _drag_anchor: Vector2 = Vector2.ZERO
var _facility_views: Dictionary[int, FacilityView] = {}
var _facility_node_layer: Control
var _placement_preview_view: FacilityPlacementPreviewView


func _ready() -> void:
	focus_mode = Control.FOCUS_ALL
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_refresh_visual_projection()


func has_production_style(type_id: StringName) -> bool:
	return FacilityView.supports_type(type_id)


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_clamp_camera_offset()
		_refresh_visual_projection()


func apply_snapshot(snapshot: HabitatLayoutSnapshot) -> bool:
	if snapshot == null or not snapshot.active:
		return false
	var layout_projection_changed: bool = (
		not _zone_anchor_cache_ready
		or snapshot.revision != _zone_anchor_cache_revision
		or snapshot.grid_size != _zone_anchor_cache_grid_size
	)
	if not _spatial_projection.configure(
		snapshot.grid_size,
		Rect2(
			Vector2.ZERO,
			Vector2(snapshot.grid_size) * CELL_SIZE
		),
		0.0
	):
		return false
	_snapshot = snapshot
	if layout_projection_changed:
		_invalidate_zone_anchor_cache()
	if _snapshot.get_facility(_selected_facility_id) == null:
		_set_selected_facility(-1)
	if (
		not _placement_type_id.is_empty()
		and not _has_placement_options(_placement_type_id)
	):
		cancel_placement()
	_refresh_visual_projection()
	return true


func apply_zone_topology(zones: Array[HabitatZoneSnapshot]) -> void:
	_zone_snapshots.assign(zones)
	if not _zone_anchor_cache_ready:
		_rebuild_zone_anchor_cache()
	_refresh_visual_projection()


func invalidate_projection_cache() -> void:
	_invalidate_zone_anchor_cache()
	_refresh_visual_projection()


func set_editing_enabled(value: bool) -> void:
	if _editing_enabled == value:
		return
	_editing_enabled = value
	mouse_filter = (
		Control.MOUSE_FILTER_STOP
		if _editing_enabled
		else Control.MOUSE_FILTER_IGNORE
	)
	if _editing_enabled:
		grab_focus()
	else:
		cancel_placement()
	_refresh_visual_projection()


func is_editing_enabled() -> bool:
	return _editing_enabled


func begin_placement(type_id: StringName) -> bool:
	if _snapshot == null:
		interaction_feedback.emit(
			InteractionFeedback.PLACEMENT_UNAVAILABLE
		)
		return false
	if not _editing_enabled:
		set_editing_enabled(true)
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
		_refresh_visual_projection()
		return true
	interaction_feedback.emit(InteractionFeedback.PLACEMENT_UNAVAILABLE)
	return false


func cancel_placement() -> void:
	_placement_type_id = &""
	_refresh_visual_projection()


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


func set_selected_facility_id(facility_id: int) -> bool:
	if facility_id >= 0 and (
		_snapshot == null
		or _snapshot.get_facility(facility_id) == null
	):
		return false
	_set_selected_facility(facility_id)
	_refresh_visual_projection()
	return _selected_facility_id == facility_id


func find_facility_at(local_position: Vector2) -> int:
	if (
		_snapshot == null
		or not local_position.is_finite()
		or not is_finite(_camera_zoom)
		or _camera_zoom <= 0.0
	):
		return -1
	var world_position: Vector2 = (
		(local_position - _grid_origin()) / _camera_zoom
	)
	return _spatial_projection.find_top_facility_at(
		_snapshot,
		world_position
	)


func select_facility_at(local_position: Vector2) -> int:
	var facility_id: int = find_facility_at(local_position)
	set_selected_facility_id(facility_id)
	return facility_id


func focus_view_position(local_position: Vector2) -> bool:
	if not local_position.is_finite():
		return false
	pan_by(size * 0.5 - local_position)
	return true


func focus_facility(facility_id: int) -> bool:
	var facility_rect: Rect2 = project_facility_rect(facility_id)
	if facility_rect.size.x <= 0.0 or facility_rect.size.y <= 0.0:
		return false
	return focus_view_position(facility_rect.get_center())


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
	_refresh_visual_projection()


func reset_camera() -> void:
	_camera_zoom = 1.0
	_camera_offset = Vector2.ZERO
	camera_changed.emit(_camera_zoom, _camera_offset)
	_refresh_visual_projection()


func pan_by(delta: Vector2) -> void:
	if not delta.is_finite():
		return
	if delta.is_zero_approx():
		return
	_camera_offset += delta
	_clamp_camera_offset()
	camera_changed.emit(_camera_zoom, _camera_offset)
	_refresh_visual_projection()


func handle_keyboard_action(keycode: Key) -> bool:
	if not visible or not _editing_enabled or _snapshot == null:
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
				_refresh_visual_projection()
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
	if not _editing_enabled:
		return
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
		_refresh_visual_projection()


func _handle_primary_click(local_position: Vector2) -> void:
	grab_focus()
	if is_placing():
		_placement_slot = _view_to_slot(local_position)
		_submit_current_placement()
		_refresh_visual_projection()
		return
	select_facility_at(local_position)


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
		_refresh_visual_projection()
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
	return _spatial_projection.world_to_slot(world)


func _slot_rect(slot: Vector2i, footprint: Vector2i) -> Rect2:
	var world_rect: Rect2 = _spatial_projection.slot_rect(
		slot,
		footprint
	)
	return Rect2(
		_world_to_view(world_rect.position),
		world_rect.size * _camera_zoom
	)


func project_zone_position(
	zone_id: StringName,
	entity_id: int = 0
) -> Vector2:
	if _snapshot == null:
		return size * 0.5
	if not _zone_anchor_cache_ready:
		_rebuild_zone_anchor_cache()
	if not _zone_anchor_cache.has(zone_id):
		return size * 0.5
	var offset: Vector2 = Vector2.ZERO
	if entity_id > 0:
		offset = Vector2(
			float(posmod(entity_id, 3) - 1) * 15.0,
			float(
				posmod(
					floori(float(entity_id) / 3.0),
					3
				) - 1
			) * 10.0
		)
	return _world_to_view(_zone_anchor_cache[zone_id]) + offset


func _invalidate_zone_anchor_cache() -> void:
	_zone_anchor_cache.clear()
	_zone_anchor_cache_revision = -1
	_zone_anchor_cache_grid_size = Vector2i.ZERO
	_zone_anchor_cache_ready = false


func _rebuild_zone_anchor_cache() -> void:
	if _snapshot == null:
		return
	_zone_anchor_cache = (
		_spatial_projection.build_logical_zone_anchor_index(
			_snapshot,
			_zone_snapshots
		)
	)
	_zone_anchor_cache_revision = _snapshot.revision
	_zone_anchor_cache_grid_size = _snapshot.grid_size
	_zone_anchor_cache_ready = true


func project_facility_rect(facility_id: int) -> Rect2:
	if _snapshot == null:
		return Rect2()
	var facility: FacilitySnapshot = _snapshot.get_facility(facility_id)
	if facility == null:
		return Rect2()
	return _slot_rect(facility.slot, facility.footprint)


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


func get_facility_view(facility_id: int) -> FacilityView:
	return _facility_views.get(facility_id)


func get_facility_view_count() -> int:
	return _facility_views.size()


func _refresh_visual_projection() -> void:
	_ensure_visual_layers()
	_sync_facility_views()
	_sync_placement_preview()
	queue_redraw()


func _ensure_visual_layers() -> void:
	if _facility_node_layer == null:
		_facility_node_layer = Control.new()
		_facility_node_layer.name = "FacilityNodeLayer"
		_facility_node_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(_facility_node_layer)
		_facility_node_layer.set_anchors_and_offsets_preset(
			Control.PRESET_FULL_RECT
		)
	if _placement_preview_view == null:
		_placement_preview_view = FacilityPlacementPreviewView.new()
		_placement_preview_view.name = "PlacementPreviewView"
		_placement_preview_view.z_index = 100
		_placement_preview_view.visible = false
		add_child(_placement_preview_view)


func _sync_facility_views() -> void:
	if _facility_node_layer == null:
		return
	var ordered_facilities: Array[FacilitySnapshot] = []
	if _snapshot != null:
		for facility: FacilitySnapshot in _snapshot.facilities:
			if facility != null and facility.available:
				ordered_facilities.append(facility)
	ordered_facilities.sort_custom(
		func(
			first: FacilitySnapshot,
			second: FacilitySnapshot
		) -> bool:
			if first.placement_layer != second.placement_layer:
				return first.placement_layer < second.placement_layer
			return first.facility_id < second.facility_id
	)
	var present_ids: Dictionary[int, bool] = {}
	for index: int in ordered_facilities.size():
		var facility: FacilitySnapshot = ordered_facilities[index]
		present_ids[facility.facility_id] = true
		var facility_view: FacilityView = _facility_views.get(
			facility.facility_id
		)
		if facility_view == null:
			facility_view = FacilityView.new()
			facility_view.name = (
				"FacilityView_%03d" % facility.facility_id
			)
			_facility_node_layer.add_child(facility_view)
			_facility_views[facility.facility_id] = facility_view
		facility_view.apply_snapshot(
			facility,
			_slot_rect(facility.slot, facility.footprint),
			_camera_zoom,
			facility.facility_id == _selected_facility_id,
			_editing_enabled
		)
		_facility_node_layer.move_child(
			facility_view,
			index
		)
	var removed_ids: Array[int] = []
	for facility_id: int in _facility_views:
		if not present_ids.has(facility_id):
			removed_ids.append(facility_id)
	removed_ids.sort()
	for facility_id: int in removed_ids:
		var removed_view: FacilityView = _facility_views[facility_id]
		_facility_views.erase(facility_id)
		removed_view.queue_free()


func _sync_placement_preview() -> void:
	if _placement_preview_view == null:
		return
	if (
		_snapshot == null
		or not _editing_enabled
		or not is_placing()
	):
		_placement_preview_view.clear_preview()
		return
	var footprint: Vector2i = Vector2i.ONE
	if _placement_type_id == CampaignState.FACILITY_SMALL_FORAGING_BOX:
		footprint = Vector2i(2, 2)
	var rect: Rect2 = _slot_rect(
		_placement_slot,
		footprint
	).grow(-4.0 * _camera_zoom)
	_placement_preview_view.apply_preview(
		rect,
		_snapshot.can_place(
			_placement_type_id,
			_placement_slot,
			_placement_orientation
		),
		_camera_zoom
	)


func _draw() -> void:
	if _snapshot == null:
		return
	if _editing_enabled:
		draw_rect(
			Rect2(Vector2.ZERO, size),
			BACKGROUND_COLOR.lerp(Color.TRANSPARENT, 0.22)
		)
		_draw_grid()
	_draw_connections()
	if _editing_enabled:
		_draw_hud()


func _draw_grid() -> void:
	var grid_rect: Rect2 = _spatial_projection.get_grid_rect()
	for x: int in range(_snapshot.grid_size.x + 1):
		var start: Vector2 = _world_to_view(
			Vector2(
				grid_rect.position.x + float(x) * CELL_SIZE,
				grid_rect.position.y
			)
		)
		var end: Vector2 = _world_to_view(
			Vector2(
				grid_rect.position.x + float(x) * CELL_SIZE,
				grid_rect.end.y
			)
		)
		draw_line(start, end, GRID_AXIS_COLOR if x == 0 else GRID_COLOR, 1.0)
	for y: int in range(_snapshot.grid_size.y + 1):
		var start: Vector2 = _world_to_view(
			Vector2(
				grid_rect.position.x,
				grid_rect.position.y + float(y) * CELL_SIZE
			)
		)
		var end: Vector2 = _world_to_view(
			Vector2(
				grid_rect.end.x,
				grid_rect.position.y + float(y) * CELL_SIZE
			)
		)
		draw_line(start, end, GRID_AXIS_COLOR if y == 0 else GRID_COLOR, 1.0)


func _draw_connections() -> void:
	if _snapshot == null:
		return
	for connection: HabitatConnectionSnapshot in _snapshot.connections:
		var world_endpoints: PackedVector2Array = (
			_spatial_projection.connection_endpoints(
				_snapshot,
				connection
			)
		)
		if world_endpoints.size() != 2:
			continue
		var first_center: Vector2 = _world_to_view(world_endpoints[0])
		var second_center: Vector2 = _world_to_view(world_endpoints[1])
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
