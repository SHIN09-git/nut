class_name ChapterArtView
extends Control

const CHAPTER_COUNT: int = 6
const LINE_COLOR: Color = Color(0.34, 0.42, 0.35, 0.9)
const COMPLETE_COLOR: Color = Color(0.47, 0.67, 0.52, 1.0)
const ACTIVE_COLOR: Color = Color(0.95, 0.74, 0.33, 1.0)
const FUTURE_COLOR: Color = Color(0.22, 0.28, 0.25, 1.0)
const INK_COLOR: Color = Color(0.88, 0.90, 0.80, 1.0)

var _active_index: int = 0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	queue_redraw()


func set_chapter(chapter: int) -> void:
	var next_index: int = clampi(
		chapter - CampaignState.Chapter.ACT1_FOUNDING,
		0,
		CHAPTER_COUNT - 1
	)
	if next_index == _active_index:
		return
	_active_index = next_index
	queue_redraw()


func get_active_index() -> int:
	return _active_index


func _draw() -> void:
	if size.x < 240.0 or size.y < 52.0:
		return
	var margin: float = 42.0
	var center_y: float = size.y * 0.52
	var spacing: float = (size.x - margin * 2.0) / float(CHAPTER_COUNT - 1)
	draw_line(
		Vector2(margin, center_y),
		Vector2(size.x - margin, center_y),
		LINE_COLOR,
		3.0,
		true
	)
	for index: int in CHAPTER_COUNT:
		var center: Vector2 = Vector2(
			margin + spacing * float(index),
			center_y
		)
		var fill: Color = (
			COMPLETE_COLOR
			if index < _active_index
			else ACTIVE_COLOR if index == _active_index
			else FUTURE_COLOR
		)
		draw_circle(center + Vector2(1.5, 2.5), 17.0, Color(0.0, 0.0, 0.0, 0.34))
		draw_circle(center, 16.0, fill)
		draw_circle(center, 12.0, Color(0.045, 0.065, 0.058, 0.96))
		_draw_chapter_symbol(index, center)
		if index == _active_index:
			draw_arc(
				center,
				20.0,
				0.0,
				TAU,
				28,
				ACTIVE_COLOR,
				2.0,
				true
			)


func _draw_chapter_symbol(index: int, center: Vector2) -> void:
	match index:
		0:
			_draw_ellipse(center + Vector2(-3.5, 2.0), Vector2(5.5, 3.8), INK_COLOR)
			draw_circle(center + Vector2(5.0, -3.0), 3.5, INK_COLOR)
		1:
			draw_circle(center + Vector2(-5.0, 0.0), 4.0, INK_COLOR)
			draw_circle(center + Vector2(1.0, 0.0), 3.2, INK_COLOR)
			draw_circle(center + Vector2(6.0, 0.0), 2.8, INK_COLOR)
			draw_circle(center + Vector2(7.0, -7.0), 2.0, ACTIVE_COLOR)
		2:
			draw_rect(
				Rect2(center - Vector2(8.0, 6.0), Vector2(16.0, 12.0)),
				INK_COLOR,
				false,
				2.0
			)
			draw_circle(center, 3.0, ACTIVE_COLOR)
		3:
			var drop: PackedVector2Array = PackedVector2Array([
				center + Vector2(0.0, -9.0),
				center + Vector2(7.0, 3.0),
				center + Vector2(0.0, 9.0),
				center + Vector2(-7.0, 3.0),
			])
			draw_colored_polygon(drop, INK_COLOR)
		4:
			draw_circle(center + Vector2(-6.0, 0.0), 6.0, INK_COLOR)
			draw_circle(center + Vector2(6.0, 0.0), 6.0, INK_COLOR)
			draw_line(
				center + Vector2(-1.0, 0.0),
				center + Vector2(1.0, 0.0),
				ACTIVE_COLOR,
				3.0,
				true
			)
		5:
			draw_rect(
				Rect2(center - Vector2(7.0, 9.0), Vector2(14.0, 18.0)),
				INK_COLOR,
				false,
				2.0
			)
			for offset_y: float in [-4.0, 0.0, 4.0]:
				draw_line(
					center + Vector2(-4.0, offset_y),
					center + Vector2(4.0, offset_y),
					INK_COLOR,
					1.2,
					true
				)


func _draw_ellipse(
	center: Vector2,
	radii: Vector2,
	color: Color
) -> void:
	draw_set_transform(center, 0.0, radii)
	draw_circle(Vector2.ZERO, 1.0, color)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
