class_name QueenView
extends Node2D

const BODY_COLOR: Color = Color(0.19, 0.105, 0.065, 1.0)
const BODY_HIGHLIGHT: Color = Color(0.40, 0.24, 0.13, 1.0)
const LIMB_COLOR: Color = Color(0.27, 0.15, 0.09, 1.0)
const IDLE_PERIOD_TICKS: int = 48
const IDLE_BOB_PIXELS: float = 2.4

var entity_id: int = -1
var _base_position: Vector2 = Vector2.ZERO
var _simulation_tick: int = 0
var _visuals_paused: bool = false


func _ready() -> void:
	queue_redraw()


func set_entity_id(new_entity_id: int) -> void:
	entity_id = new_entity_id


func set_habitat_position(new_position: Vector2) -> void:
	_base_position = new_position
	_update_idle_pose()


func set_simulation_tick(simulation_tick: int) -> void:
	_simulation_tick = maxi(simulation_tick, 0)
	_update_idle_pose()
	queue_redraw()


func set_visuals_paused(value: bool) -> void:
	_visuals_paused = value


func are_visuals_paused() -> bool:
	return _visuals_paused


func _draw() -> void:
	var phase: float = _get_idle_phase()
	var antenna_sway: float = sin(phase) * 2.0

	_draw_legs()
	_draw_ellipse(Vector2(-23.0, 0.0), Vector2(24.0, 16.0), BODY_COLOR)
	_draw_ellipse(Vector2(-23.0, -3.0), Vector2(15.0, 7.0), BODY_HIGHLIGHT)
	_draw_ellipse(Vector2(2.0, 0.0), Vector2(13.0, 12.0), BODY_COLOR)
	_draw_ellipse(Vector2(21.0, -1.0), Vector2(11.0, 10.0), BODY_COLOR)

	draw_line(
		Vector2(27.0, -7.0),
		Vector2(38.0, -16.0 + antenna_sway),
		LIMB_COLOR,
		2.0,
		true
	)
	draw_line(
		Vector2(28.0, -3.0),
		Vector2(41.0, -7.0 - antenna_sway),
		LIMB_COLOR,
		2.0,
		true
	)
	draw_circle(Vector2(24.0, -4.0), 1.6, Color(0.82, 0.65, 0.34, 1.0))


func _update_idle_pose() -> void:
	position = _base_position + Vector2(
		0.0,
		sin(_get_idle_phase()) * IDLE_BOB_PIXELS
	)


func _get_idle_phase() -> float:
	return (
		float(_simulation_tick % IDLE_PERIOD_TICKS)
		/ float(IDLE_PERIOD_TICKS)
		* TAU
	)


func _draw_legs() -> void:
	var leg_pairs: Array[PackedVector2Array] = [
		PackedVector2Array([Vector2(-5.0, -7.0), Vector2(-14.0, -19.0), Vector2(-23.0, -22.0)]),
		PackedVector2Array([Vector2(3.0, -7.0), Vector2(2.0, -21.0), Vector2(9.0, -26.0)]),
		PackedVector2Array([Vector2(10.0, -5.0), Vector2(18.0, -18.0), Vector2(28.0, -20.0)]),
		PackedVector2Array([Vector2(-5.0, 7.0), Vector2(-14.0, 19.0), Vector2(-23.0, 22.0)]),
		PackedVector2Array([Vector2(3.0, 7.0), Vector2(2.0, 21.0), Vector2(9.0, 26.0)]),
		PackedVector2Array([Vector2(10.0, 5.0), Vector2(18.0, 18.0), Vector2(28.0, 20.0)]),
	]
	for leg: PackedVector2Array in leg_pairs:
		draw_polyline(leg, LIMB_COLOR, 2.4, true)


func _draw_ellipse(center: Vector2, radii: Vector2, color: Color) -> void:
	draw_set_transform(center, 0.0, radii)
	draw_circle(Vector2.ZERO, 1.0, color)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
