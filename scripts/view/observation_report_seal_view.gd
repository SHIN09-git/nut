class_name ObservationReportSealView
extends Control

const BRASS: Color = Color(0.91, 0.70, 0.31, 1.0)
const GLASS: Color = Color(0.18, 0.39, 0.37, 0.86)
const INK: Color = Color(0.86, 0.88, 0.76, 1.0)
const SHADOW: Color = Color(0.0, 0.0, 0.0, 0.34)


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	queue_redraw()


func _draw() -> void:
	if size.x < 64.0 or size.y < 54.0:
		return
	var center: Vector2 = size * Vector2(0.5, 0.48)
	var radius: float = minf(size.x, size.y) * 0.34
	draw_circle(center + Vector2(2.0, 3.0), radius + 5.0, SHADOW)
	draw_circle(center, radius + 5.0, BRASS)
	draw_circle(center, radius + 1.5, Color(0.05, 0.075, 0.066, 1.0))
	draw_circle(center, radius - 2.0, GLASS)
	draw_arc(
		center,
		radius - 5.0,
		PI * 1.05,
		PI * 1.78,
		20,
		Color(0.78, 0.98, 0.92, 0.56),
		2.2,
		true
	)
	var ant_center: Vector2 = center + Vector2(2.0, 1.0)
	draw_circle(ant_center + Vector2(-8.0, 0.0), 5.0, INK)
	draw_circle(ant_center, 3.8, INK)
	draw_circle(ant_center + Vector2(7.0, -0.4), 3.3, INK)
	for side: float in [-1.0, 1.0]:
		for index: int in 3:
			var root_point: Vector2 = ant_center + Vector2(
				float(index - 1) * 4.0,
				side * 2.5
			)
			draw_line(
				root_point,
				root_point + Vector2(float(index - 1) * 3.0, side * 8.0),
				INK,
				1.4,
				true
			)
	for index: int in 6:
		var angle: float = TAU * float(index) / 6.0
		var dot: Vector2 = center + Vector2(cos(angle), sin(angle)) * (radius + 11.0)
		draw_circle(dot, 2.4, BRASS)
