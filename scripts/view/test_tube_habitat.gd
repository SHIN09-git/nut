class_name TestTubeHabitat
extends Control

const GLASS_FILL: Color = Color(0.12, 0.16, 0.17, 0.88)
const GLASS_EDGE: Color = Color(0.58, 0.70, 0.68, 0.72)
const GLASS_HIGHLIGHT: Color = Color(0.86, 0.94, 0.90, 0.32)
const WATER_COLOR: Color = Color(0.25, 0.52, 0.63, 0.48)
const COTTON_COLOR: Color = Color(0.78, 0.80, 0.73, 0.96)
const COTTON_SHADOW: Color = Color(0.44, 0.47, 0.42, 0.88)
const FLOOR_COLOR: Color = Color(0.31, 0.29, 0.24, 0.72)
const TUBE_SIDE_MARGIN: float = 34.0
const MAX_TUBE_HEIGHT: float = 300.0
const COTTON_SEGMENT_COUNT: int = 7

@onready var _view_adapter: ColonyViewAdapter = %ColonyViewAdapter


func _ready() -> void:
	_layout_views()
	queue_redraw()


func _notification(what: int) -> void:
	if what != NOTIFICATION_RESIZED:
		return
	queue_redraw()
	if is_node_ready():
		_layout_views()


func get_view_adapter() -> ColonyViewAdapter:
	return _view_adapter


func _layout_views() -> void:
	var tube_rect: Rect2 = _get_tube_rect()
	if tube_rect.size.x <= 0.0 or tube_rect.size.y <= 0.0:
		return
	var cotton_radius: float = _get_cotton_radius(tube_rect)
	var cotton_x: float = tube_rect.position.x + tube_rect.size.y
	var activity_start_x: float = cotton_x + cotton_radius + 12.0
	var floor_y: float = tube_rect.position.y + tube_rect.size.y * 0.72
	_view_adapter.set_habitat_geometry(
		tube_rect,
		activity_start_x,
		floor_y
	)


func _draw() -> void:
	if size.x < 180.0 or size.y < 120.0:
		return

	var tube_rect: Rect2 = _get_tube_rect()
	_draw_capsule(tube_rect, GLASS_FILL)

	var radius: float = tube_rect.size.y * 0.5
	var left_center: Vector2 = tube_rect.position + Vector2(radius, radius)
	var water_radius: float = radius - 12.0
	draw_circle(left_center, water_radius, WATER_COLOR)
	draw_arc(
		left_center,
		water_radius * 0.78,
		PI * 0.62,
		PI * 1.38,
		24,
		Color(0.52, 0.76, 0.81, 0.58),
		2.0,
		true
	)

	var cotton_x: float = tube_rect.position.x + tube_rect.size.y
	var cotton_radius: float = _get_cotton_radius(tube_rect)
	var cotton_top: float = tube_rect.position.y + cotton_radius + 4.0
	var cotton_bottom: float = tube_rect.end.y - cotton_radius - 4.0
	for index: int in range(COTTON_SEGMENT_COUNT):
		var progress: float = float(index) / float(COTTON_SEGMENT_COUNT - 1)
		var cotton_center: Vector2 = Vector2(
			cotton_x + float(index % 3) * 3.0,
			lerpf(cotton_top, cotton_bottom, progress)
		)
		draw_circle(
			cotton_center + Vector2(2.0, 2.0),
			cotton_radius,
			COTTON_SHADOW
		)
		draw_circle(cotton_center, cotton_radius - 2.0, COTTON_COLOR)

	var floor_y: float = tube_rect.position.y + tube_rect.size.y * 0.72
	var activity_start_x: float = cotton_x + cotton_radius + 12.0
	draw_line(
		Vector2(activity_start_x, floor_y),
		Vector2(tube_rect.end.x - radius * 0.45, floor_y),
		FLOOR_COLOR,
		5.0,
		true
	)
	draw_line(
		Vector2(activity_start_x, tube_rect.position.y + 18.0),
		Vector2(tube_rect.end.x - radius * 0.50, tube_rect.position.y + 18.0),
		GLASS_HIGHLIGHT,
		3.0,
		true
	)
	_draw_tube_outline(tube_rect)


func _get_tube_rect() -> Rect2:
	var tube_height: float = minf(
		minf(
			size.y - TUBE_SIDE_MARGIN * 2.0,
			size.x - TUBE_SIDE_MARGIN * 2.0
		),
		MAX_TUBE_HEIGHT
	)
	return Rect2(
		Vector2(
			TUBE_SIDE_MARGIN,
			(size.y - tube_height) * 0.5
		),
		Vector2(size.x - TUBE_SIDE_MARGIN * 2.0, tube_height)
	)


func _get_cotton_radius(tube_rect: Rect2) -> float:
	return minf(31.0, tube_rect.size.y * 0.105)


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
	var left_center: Vector2 = rect.position + Vector2(radius, radius)
	var right_center: Vector2 = rect.end - Vector2(radius, radius)
	draw_line(
		left_center + Vector2(0.0, -radius),
		right_center + Vector2(0.0, -radius),
		GLASS_EDGE,
		3.0,
		true
	)
	draw_line(
		left_center + Vector2(0.0, radius),
		right_center + Vector2(0.0, radius),
		GLASS_EDGE,
		3.0,
		true
	)
	draw_arc(left_center, radius, PI * 0.5, PI * 1.5, 32, GLASS_EDGE, 3.0, true)
	draw_arc(right_center, radius, -PI * 0.5, PI * 0.5, 32, GLASS_EDGE, 3.0, true)
