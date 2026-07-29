class_name QueenView
extends Node2D

const BODY_OUTLINE: Color = Color(0.045, 0.022, 0.014, 1.0)
const BODY_COLOR: Color = Color(0.17, 0.078, 0.038, 1.0)
const BODY_MID: Color = Color(0.28, 0.14, 0.065, 1.0)
const BODY_HIGHLIGHT: Color = Color(0.51, 0.29, 0.13, 1.0)
const LIMB_COLOR: Color = Color(0.31, 0.15, 0.066, 1.0)
const EYE_COLOR: Color = Color(0.95, 0.74, 0.34, 1.0)
const SHADOW_COLOR: Color = Color(0.0, 0.0, 0.0, 0.30)
const IDLE_PERIOD_TICKS: int = 48
const IDLE_BOB_PIXELS: float = 2.4

var entity_id: int = -1
var _base_position: Vector2 = Vector2.ZERO
var _simulation_tick: int = 0
var _visuals_paused: bool = false
var _reduced_motion: bool = false


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


func set_reduced_motion(value: bool) -> void:
	_reduced_motion = value
	_update_idle_pose()
	queue_redraw()


func _draw() -> void:
	var phase: float = _get_idle_phase()
	var antenna_sway: float = sin(phase) * 2.0

	_draw_ellipse(Vector2(-13.0, 5.0), Vector2(33.0, 14.0), SHADOW_COLOR)
	_draw_legs()
	draw_line(Vector2(-1.0, 0.0), Vector2(-4.0, 0.0), BODY_OUTLINE, 4.0)
	draw_line(Vector2(13.0, -0.5), Vector2(16.0, -0.8), BODY_OUTLINE, 3.4)
	_draw_ellipse(Vector2(-23.0, 0.0), Vector2(25.0, 17.0), BODY_OUTLINE)
	_draw_ellipse(Vector2(-23.5, -0.6), Vector2(23.0, 14.8), BODY_COLOR)
	_draw_ellipse(Vector2(2.0, 0.0), Vector2(14.0, 13.0), BODY_OUTLINE)
	_draw_ellipse(Vector2(1.6, -0.5), Vector2(12.0, 11.0), BODY_MID)
	_draw_ellipse(Vector2(21.0, -1.0), Vector2(12.0, 11.0), BODY_OUTLINE)
	_draw_ellipse(Vector2(20.8, -1.3), Vector2(10.0, 9.0), BODY_COLOR)
	_draw_ellipse(Vector2(-27.0, -5.0), Vector2(14.5, 6.0), BODY_HIGHLIGHT)
	_draw_ellipse(Vector2(-1.5, -4.0), Vector2(5.0, 3.0), BODY_HIGHLIGHT)
	_draw_ellipse(Vector2(18.0, -4.5), Vector2(4.0, 2.2), BODY_HIGHLIGHT)
	for x: float in [-34.0, -25.0, -16.0, -7.0]:
		draw_arc(
			Vector2(x, 0.5),
			8.0,
			-PI * 0.42,
			PI * 0.42,
			8,
			BODY_MID,
			1.15,
			true
		)

	var antennae: Array[PackedVector2Array] = [
		PackedVector2Array([
			Vector2(27.0, -7.0),
			Vector2(34.0, -12.0 + antenna_sway * 0.5),
			Vector2(39.0, -17.0 + antenna_sway),
		]),
		PackedVector2Array([
			Vector2(28.0, -3.0),
			Vector2(36.0, -4.0 - antenna_sway * 0.5),
			Vector2(42.0, -7.0 - antenna_sway),
		]),
	]
	for antenna: PackedVector2Array in antennae:
		draw_polyline(antenna, BODY_OUTLINE, 3.0, true)
		draw_polyline(antenna, LIMB_COLOR, 1.5, true)
	draw_circle(Vector2(24.0, -4.0), 2.0, BODY_OUTLINE)
	draw_circle(Vector2(24.3, -4.2), 1.1, EYE_COLOR)


func _update_idle_pose() -> void:
	position = _base_position + Vector2(
		0.0,
		sin(_get_idle_phase()) * IDLE_BOB_PIXELS
	)


func _get_idle_phase() -> float:
	if _reduced_motion:
		return 0.0
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
		draw_polyline(leg, BODY_OUTLINE, 4.0, true)
		draw_polyline(leg, LIMB_COLOR, 2.0, true)


func _draw_ellipse(center: Vector2, radii: Vector2, color: Color) -> void:
	draw_set_transform(center, 0.0, radii)
	draw_circle(Vector2.ZERO, 1.0, color)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
