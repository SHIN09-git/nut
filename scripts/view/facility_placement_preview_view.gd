class_name FacilityPlacementPreviewView
extends Control

const VALID_PREVIEW_COLOR: Color = Color(0.32, 0.72, 0.47, 0.48)
const INVALID_PREVIEW_COLOR: Color = Color(0.82, 0.29, 0.25, 0.46)
const SELECTED_COLOR: Color = Color(0.94, 0.72, 0.30, 1.0)
const TEXT_COLOR: Color = Color(0.82, 0.87, 0.79, 1.0)

var _valid: bool = false
var _camera_zoom: float = 1.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func apply_preview(
	projected_rect: Rect2,
	valid: bool,
	camera_zoom: float
) -> bool:
	if (
		not projected_rect.position.is_finite()
		or not projected_rect.size.is_finite()
		or projected_rect.size.x <= 0.0
		or projected_rect.size.y <= 0.0
		or not is_finite(camera_zoom)
		or camera_zoom <= 0.0
	):
		visible = false
		return false
	position = projected_rect.position
	size = projected_rect.size
	_valid = valid
	_camera_zoom = camera_zoom
	visible = true
	queue_redraw()
	return true


func clear_preview() -> void:
	visible = false


func _draw() -> void:
	var rect: Rect2 = Rect2(Vector2.ZERO, size)
	draw_rect(
		rect,
		VALID_PREVIEW_COLOR if _valid else INVALID_PREVIEW_COLOR,
		true
	)
	draw_rect(rect, SELECTED_COLOR, false, 3.0)
	var center: Vector2 = rect.get_center()
	var cue_size: float = maxf(8.0, 14.0 * _camera_zoom)
	if _valid:
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
