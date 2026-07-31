class_name QueenView
extends Node2D

const BODY_OUTLINE: Color = Color(0.045, 0.022, 0.014, 1.0)
const BODY_COLOR: Color = Color(0.17, 0.078, 0.038, 1.0)
const BODY_MID: Color = Color(0.28, 0.14, 0.065, 1.0)
const BODY_HIGHLIGHT: Color = Color(0.51, 0.29, 0.13, 1.0)
const LIMB_COLOR: Color = Color(0.31, 0.15, 0.066, 1.0)
const EYE_COLOR: Color = Color(0.95, 0.74, 0.34, 1.0)
const SHADOW_COLOR: Color = Color(0.0, 0.0, 0.0, 0.30)
const CARE_COLOR: Color = Color(0.91, 0.78, 0.48, 0.88)
const CARE_GLOW: Color = Color(0.91, 0.78, 0.48, 0.22)
const IDLE_PERIOD_TICKS: int = 48
const WALK_CYCLE_TICKS: float = 10.0
const IDLE_BOB_PIXELS: float = 2.4

enum BehaviorPose {
	IDLE,
	MOVING,
	GATHERING_BROOD,
	CARING_FOR_BROOD,
	CARRIED,
}

var entity_id: int = -1
var _base_position: Vector2 = Vector2.ZERO
var _simulation_tick: int = 0
var _visuals_paused: bool = false
var _reduced_motion: bool = false
var _behavior_pose: BehaviorPose = BehaviorPose.IDLE
var _facing_sign: float = 1.0
var _animation_phase: float = 0.0
var _draw_transform: Transform2D = Transform2D.IDENTITY


func _ready() -> void:
	queue_redraw()


func set_entity_id(new_entity_id: int) -> void:
	entity_id = new_entity_id


func set_habitat_position(new_position: Vector2) -> void:
	_base_position = new_position
	_update_visual_position()


func set_simulation_tick(simulation_tick: int) -> void:
	_simulation_tick = maxi(simulation_tick, 0)
	_animation_phase = (
		0.0
		if _reduced_motion
		else fposmod(
			float(_simulation_tick) / float(IDLE_PERIOD_TICKS),
			1.0
		)
	)
	_update_visual_position()
	queue_redraw()


func set_visuals_paused(value: bool) -> void:
	_visuals_paused = value


func are_visuals_paused() -> bool:
	return _visuals_paused


func set_reduced_motion(value: bool) -> void:
	_reduced_motion = value
	if _reduced_motion:
		_animation_phase = 0.0
	_update_visual_position()
	queue_redraw()


func set_behavior_pose(
	pose: BehaviorPose,
	facing_direction: float,
	animation_phase: float
) -> void:
	var next_facing: float = _facing_sign
	if absf(facing_direction) > 0.001:
		next_facing = -1.0 if facing_direction < 0.0 else 1.0
	var next_phase: float = (
		0.0
		if _reduced_motion
		else fposmod(animation_phase, 1.0)
			if is_finite(animation_phase)
			else 0.0
	)
	if (
		_behavior_pose == pose
		and is_equal_approx(_facing_sign, next_facing)
		and is_equal_approx(_animation_phase, next_phase)
	):
		return
	_behavior_pose = pose
	_facing_sign = next_facing
	_animation_phase = next_phase
	_update_visual_position()
	queue_redraw()


func get_behavior_pose() -> BehaviorPose:
	return _behavior_pose


func get_facing_sign() -> float:
	return _facing_sign


func get_animation_phase() -> float:
	return _animation_phase


func _draw() -> void:
	var phase: float = _animation_phase * TAU
	var antenna_sway: float = sin(phase) * 2.0
	var pose_rotation: float = 0.0
	var pose_scale: Vector2 = Vector2.ONE
	var pose_offset: Vector2 = Vector2.ZERO
	match _behavior_pose:
		BehaviorPose.MOVING:
			pose_offset.y = sin(phase) * 1.2
		BehaviorPose.GATHERING_BROOD:
			pose_rotation = 0.045
			pose_offset = Vector2(2.0, 1.0)
		BehaviorPose.CARING_FOR_BROOD:
			pose_rotation = 0.075
			pose_offset = Vector2(3.0, 2.0)
		BehaviorPose.CARRIED:
			pose_rotation = -0.08
			pose_scale = Vector2(0.90, 0.86)
	_draw_transform = Transform2D(
		pose_rotation,
		Vector2(_facing_sign * pose_scale.x, pose_scale.y),
		0.0,
		pose_offset
	)
	draw_set_transform_matrix(_draw_transform)

	_draw_ellipse(Vector2(-13.0, 5.0), Vector2(33.0, 14.0), SHADOW_COLOR)
	_draw_legs(phase)
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
	_draw_behavior_cue()
	draw_set_transform_matrix(Transform2D.IDENTITY)


func _update_visual_position() -> void:
	var bob_pixels: float = 0.0
	if not _reduced_motion:
		match _behavior_pose:
			BehaviorPose.IDLE:
				bob_pixels = (
					sin(_animation_phase * TAU)
					* IDLE_BOB_PIXELS
				)
			BehaviorPose.MOVING:
				bob_pixels = sin(_animation_phase * TAU) * 0.8
	position = _base_position + Vector2(
		0.0,
		bob_pixels
	)


func _draw_legs(phase: float) -> void:
	var leg_pairs: Array[PackedVector2Array] = [
		PackedVector2Array([Vector2(-5.0, -7.0), Vector2(-14.0, -19.0), Vector2(-23.0, -22.0)]),
		PackedVector2Array([Vector2(3.0, -7.0), Vector2(2.0, -21.0), Vector2(9.0, -26.0)]),
		PackedVector2Array([Vector2(10.0, -5.0), Vector2(18.0, -18.0), Vector2(28.0, -20.0)]),
		PackedVector2Array([Vector2(-5.0, 7.0), Vector2(-14.0, 19.0), Vector2(-23.0, 22.0)]),
		PackedVector2Array([Vector2(3.0, 7.0), Vector2(2.0, 21.0), Vector2(9.0, 26.0)]),
		PackedVector2Array([Vector2(10.0, 5.0), Vector2(18.0, 18.0), Vector2(28.0, 20.0)]),
	]
	var stride: float = (
		sin(phase) * 3.0
		if _behavior_pose == BehaviorPose.MOVING and not _reduced_motion
		else 0.0
	)
	for index: int in leg_pairs.size():
		var leg: PackedVector2Array = leg_pairs[index].duplicate()
		if _behavior_pose == BehaviorPose.CARRIED:
			leg[1] = leg[1].lerp(leg[0], 0.42)
			leg[2] = leg[2].lerp(leg[0], 0.52)
		elif not is_zero_approx(stride):
			var direction: float = 1.0 if index % 2 == 0 else -1.0
			leg[1].x += stride * direction * 0.55
			leg[2].x += stride * direction
		draw_polyline(leg, BODY_OUTLINE, 4.0, true)
		draw_polyline(leg, LIMB_COLOR, 2.0, true)


func _draw_behavior_cue() -> void:
	match _behavior_pose:
		BehaviorPose.GATHERING_BROOD:
			_draw_mandibles(true)
			draw_arc(
				Vector2(28.0, 4.0),
				9.0,
				PI * 0.70,
				PI * 1.28,
				10,
				CARE_COLOR,
				2.0,
				true
			)
		BehaviorPose.CARING_FOR_BROOD:
			_draw_mandibles(false)
			draw_circle(Vector2(30.0, 5.0), 10.0, CARE_GLOW)
			draw_circle(Vector2(30.0, 5.0), 3.2, CARE_COLOR)
			draw_arc(
				Vector2(30.0, 5.0),
				8.0,
				PI * 0.72,
				PI * 1.30,
				10,
				CARE_COLOR,
				2.0,
				true
			)
		BehaviorPose.CARRIED:
			draw_line(
				Vector2(27.0, -5.0),
				Vector2(34.0, -8.0),
				CARE_COLOR,
				1.8,
				true
			)


func _draw_mandibles(open: bool) -> void:
	var spread: float = 5.5 if open else 3.0
	draw_line(
		Vector2(27.0, -1.0),
		Vector2(34.0, -1.0 - spread),
		BODY_OUTLINE,
		2.6,
		true
	)
	draw_line(
		Vector2(27.0, -1.0),
		Vector2(34.0, -1.0 + spread),
		BODY_OUTLINE,
		2.6,
		true
	)


func _draw_ellipse(center: Vector2, radii: Vector2, color: Color) -> void:
	draw_set_transform_matrix(
		_draw_transform
		* Transform2D(0.0, radii, 0.0, center)
	)
	draw_circle(Vector2.ZERO, 1.0, color)
	draw_set_transform_matrix(_draw_transform)
