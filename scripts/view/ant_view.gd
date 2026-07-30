class_name AntView
extends Node2D

const BROOD_OUTLINE: Color = Color(0.38, 0.32, 0.23, 1.0)
const BROOD_LIGHT: Color = Color(0.94, 0.91, 0.75, 1.0)
const BROOD_MID: Color = Color(0.82, 0.78, 0.61, 1.0)
const BROOD_SHADE: Color = Color(0.61, 0.55, 0.40, 1.0)
const BROOD_SPECULAR: Color = Color(1.0, 0.98, 0.85, 0.82)
const WORKER_OUTLINE: Color = Color(0.055, 0.027, 0.018, 1.0)
const WORKER_BODY: Color = Color(0.14, 0.065, 0.035, 1.0)
const WORKER_MID: Color = Color(0.24, 0.12, 0.064, 1.0)
const WORKER_HIGHLIGHT: Color = Color(0.49, 0.27, 0.12, 1.0)
const LIMB_COLOR: Color = Color(0.29, 0.14, 0.067, 1.0)
const EYE_COLOR: Color = Color(0.95, 0.73, 0.32, 1.0)
const SHADOW_COLOR: Color = Color(0.0, 0.0, 0.0, 0.26)
const SELECTION_OUTLINE: Color = Color(0.88, 0.76, 0.46, 0.74)
const SUGAR_COLOR: Color = Color(0.95, 0.72, 0.28, 1.0)
const SUGAR_GLOW: Color = Color(1.0, 0.86, 0.48, 0.30)
const FOOD_SHARE_COLOR: Color = Color(0.96, 0.82, 0.46, 0.92)
const BROOD_CARE_COLOR: Color = Color(0.91, 0.78, 0.48, 0.84)
const WASTE_COLOR: Color = Color(0.48, 0.30, 0.14, 1.0)
const OBSERVE_COLOR: Color = Color(0.42, 0.76, 0.67, 0.78)
const TRANSITION_DURATION_SECONDS: float = 0.38
const WALK_CYCLE_TICKS: float = 8.0

enum BehaviorPose {
	IDLE,
	WALKING,
	COLLECTING_FOOD,
	CARRYING_FOOD,
	SHARING_FOOD,
	FEEDING_BROOD,
	HANDLING_BROOD,
	CARRYING_BROOD,
	CARRYING_WASTE,
	OBSERVING,
}

var entity_id: int = -1
var life_stage: AntModel.LifeStage = AntModel.LifeStage.EGG
var _transition_count: int = 0
var _transition_elapsed_seconds: float = TRANSITION_DURATION_SECONDS
var _visuals_paused: bool = false
var _slot_position: Vector2 = Vector2.ZERO
var _selected: bool = false
var _reduced_motion: bool = false
var _low_detail: bool = false
var _behavior_pose: BehaviorPose = BehaviorPose.IDLE
var _facing_sign: float = 1.0
var _animation_phase: float = 0.0


func configure(snapshot: AntSnapshot, slot_position: Vector2) -> bool:
	if snapshot == null or entity_id >= 0:
		return false
	entity_id = snapshot.entity_id
	life_stage = snapshot.life_stage
	_slot_position = slot_position
	position = _slot_position
	_start_transition_animation()
	queue_redraw()
	return true


func apply_snapshot(snapshot: AntSnapshot) -> bool:
	if snapshot == null or snapshot.entity_id != entity_id:
		return false
	if snapshot.life_stage == life_stage:
		return true

	life_stage = snapshot.life_stage
	if life_stage != AntModel.LifeStage.WORKER:
		_selected = false
	_transition_count += 1
	_start_transition_animation()
	queue_redraw()
	return true


func set_slot_position(new_position: Vector2) -> void:
	_slot_position = new_position
	position = _slot_position


func set_visuals_paused(value: bool) -> void:
	_visuals_paused = value


func set_selected(value: bool) -> void:
	var next_selected: bool = (
		value and life_stage == AntModel.LifeStage.WORKER
	)
	if _selected == next_selected:
		return
	_selected = next_selected
	queue_redraw()


func is_selected() -> bool:
	return _selected


func are_visuals_paused() -> bool:
	return _visuals_paused


func set_reduced_motion(value: bool) -> void:
	_reduced_motion = value
	if _reduced_motion:
		_finish_transition_animation()
		_animation_phase = 0.0
	queue_redraw()


func set_low_detail(value: bool) -> void:
	if _low_detail == value:
		return
	_low_detail = value
	queue_redraw()


func is_low_detail() -> bool:
	return _low_detail


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
	queue_redraw()


func get_behavior_pose() -> BehaviorPose:
	return _behavior_pose


func get_facing_sign() -> float:
	return _facing_sign


func get_animation_phase() -> float:
	return _animation_phase


func get_entity_id() -> int:
	return entity_id


func get_life_stage() -> AntModel.LifeStage:
	return life_stage


func get_transition_count() -> int:
	return _transition_count


func is_transition_active() -> bool:
	return _transition_elapsed_seconds < TRANSITION_DURATION_SECONDS


func _process(delta: float) -> void:
	if _visuals_paused or _reduced_motion or not is_transition_active():
		return

	_transition_elapsed_seconds = minf(
		_transition_elapsed_seconds + delta,
		TRANSITION_DURATION_SECONDS
	)
	var progress: float = (
		_transition_elapsed_seconds / TRANSITION_DURATION_SECONDS
	)
	var eased_progress: float = 1.0 - pow(1.0 - progress, 3.0)
	var pulse: float = sin(progress * PI) * 0.12
	scale = Vector2.ONE * (lerpf(0.72, 1.0, eased_progress) + pulse)
	modulate.a = lerpf(0.42, 1.0, eased_progress)
	if not is_transition_active():
		scale = Vector2.ONE
		modulate.a = 1.0


func _draw() -> void:
	if life_stage == AntModel.LifeStage.WORKER:
		if _selected:
			_draw_selection_outline()
		var bob: float = (
			sin(_animation_phase * TAU) * 1.35
			if _is_locomotion_pose() and not _reduced_motion
			else 0.0
		)
		draw_set_transform(
			Vector2(0.0, bob),
			0.0,
			Vector2(_facing_sign, 1.0)
		)
		if _low_detail:
			_draw_low_detail()
		else:
			_draw_worker()
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		return
	if _low_detail:
		_draw_low_detail()
		return
	match life_stage:
		AntModel.LifeStage.EGG:
			_draw_egg()
		AntModel.LifeStage.LARVA:
			_draw_larva()
		AntModel.LifeStage.PUPA:
			_draw_pupa()


func _draw_low_detail() -> void:
	match life_stage:
		AntModel.LifeStage.EGG:
			_draw_ellipse(Vector2.ZERO, Vector2(8.8, 5.5), BROOD_OUTLINE)
			_draw_ellipse(
				Vector2(-0.5, -0.5),
				Vector2(7.1, 4.0),
				BROOD_LIGHT
			)
		AntModel.LifeStage.LARVA:
			var body: PackedVector2Array = PackedVector2Array([
				Vector2(-9.0, 2.0),
				Vector2(-4.0, -1.4),
				Vector2(1.0, -2.0),
				Vector2(6.0, 0.2),
				Vector2(10.0, 2.8),
			])
			draw_polyline(body, BROOD_OUTLINE, 8.5, true)
			draw_polyline(body, BROOD_MID, 5.7, true)
		AntModel.LifeStage.PUPA:
			_draw_ellipse(
				Vector2.ZERO,
				Vector2(11.5, 7.2),
				BROOD_OUTLINE
			)
			_draw_ellipse(
				Vector2(-0.8, -0.6),
				Vector2(9.6, 5.6),
				BROOD_MID
			)
			draw_circle(Vector2(6.2, -1.0), 2.8, BROOD_LIGHT)
		AntModel.LifeStage.WORKER:
			var stride: float = _get_stride()
			for leg_end: Vector2 in [
				Vector2(-10.0, -10.0),
				Vector2(1.0, -13.0),
				Vector2(15.0, -8.0),
				Vector2(-10.0, 10.0),
				Vector2(1.0, 13.0),
				Vector2(15.0, 8.0),
			]:
				draw_line(
					Vector2(2.0, 0.0),
					leg_end + Vector2(stride, 0.0),
					LIMB_COLOR,
					1.6,
					true
				)
			_draw_ellipse(
				Vector2(-7.5, 0.0),
				Vector2(7.8, 5.8),
				WORKER_BODY
			)
			_draw_ellipse(
				Vector2(2.0, 0.0),
				Vector2(5.0, 4.8),
				WORKER_MID
			)
			_draw_ellipse(
				Vector2(9.5, -0.4),
				Vector2(5.4, 5.0),
				WORKER_BODY
			)
			draw_line(
				Vector2(12.0, -3.0),
				Vector2(20.0, -8.0),
				LIMB_COLOR,
				1.4,
				true
			)
			draw_line(
				Vector2(13.0, -1.0),
				Vector2(21.0, -2.0),
				LIMB_COLOR,
				1.4,
				true
			)
			_draw_behavior_cue()


func _start_transition_animation() -> void:
	if _reduced_motion:
		_finish_transition_animation()
		return
	_transition_elapsed_seconds = 0.0
	scale = Vector2.ONE * 0.72
	modulate.a = 0.42


func _finish_transition_animation() -> void:
	_transition_elapsed_seconds = TRANSITION_DURATION_SECONDS
	scale = Vector2.ONE
	modulate.a = 1.0


func _draw_egg() -> void:
	_draw_ellipse(Vector2(1.4, 2.1), Vector2(8.7, 5.4), SHADOW_COLOR)
	_draw_ellipse(Vector2.ZERO, Vector2(8.8, 5.5), BROOD_OUTLINE)
	_draw_ellipse(Vector2(-0.5, -0.5), Vector2(7.2, 4.1), BROOD_LIGHT)
	_draw_ellipse(Vector2(-2.5, -1.7), Vector2(2.4, 1.1), BROOD_SPECULAR)
	draw_arc(
		Vector2.ZERO,
		6.0,
		PI * 0.72,
		PI * 1.38,
		10,
		BROOD_MID,
		1.0,
		true
	)


func _draw_larva() -> void:
	var shadow_points: PackedVector2Array = PackedVector2Array([
		Vector2(-9.0, 5.0),
		Vector2(-4.0, 1.5),
		Vector2(1.0, 0.6),
		Vector2(6.0, 2.2),
		Vector2(10.5, 5.2),
	])
	draw_polyline(shadow_points, SHADOW_COLOR, 10.5, true)
	var body_points: PackedVector2Array = PackedVector2Array([
		Vector2(-10.0, 2.5),
		Vector2(-5.0, -1.5),
		Vector2(0.0, -2.5),
		Vector2(5.0, 0.0),
		Vector2(10.0, 3.0),
	])
	draw_polyline(body_points, BROOD_OUTLINE, 9.0, true)
	draw_polyline(body_points, BROOD_MID, 6.7, true)
	for index: int in body_points.size():
		var joint: Vector2 = body_points[index]
		draw_circle(joint, 3.4, BROOD_MID)
		draw_circle(
			joint + Vector2(-0.8, -1.0),
			1.6,
			BROOD_LIGHT
		)
		if index > 0 and index < body_points.size() - 1:
			draw_line(
				joint + Vector2(-0.6, -3.0),
				joint + Vector2(0.6, 3.0),
				BROOD_SHADE,
				0.9,
				true
			)
	draw_circle(Vector2(9.8, 2.6), 2.2, BROOD_SHADE)
	draw_circle(Vector2(10.5, 1.8), 0.7, BROOD_SPECULAR)


func _draw_pupa() -> void:
	_draw_ellipse(Vector2(1.2, 2.4), Vector2(11.7, 7.5), SHADOW_COLOR)
	_draw_ellipse(Vector2.ZERO, Vector2(11.8, 7.5), BROOD_OUTLINE)
	_draw_ellipse(Vector2(-0.8, -0.7), Vector2(10.0, 6.0), BROOD_MID)
	_draw_ellipse(Vector2(-2.6, -2.2), Vector2(5.1, 2.0), BROOD_LIGHT)
	draw_circle(Vector2(6.0, -1.0), 3.3, BROOD_LIGHT)
	draw_circle(Vector2(7.0, -1.8), 0.8, BROOD_SHADE)
	for x: float in [-6.0, -1.8, 2.4]:
		draw_line(
			Vector2(x - 1.6, -4.5),
			Vector2(x + 1.0, 4.8),
			BROOD_LIGHT,
			1.25,
			true
		)
	draw_arc(
		Vector2(-0.4, 0.0),
		8.6,
		PI * 0.18,
		PI * 0.82,
		14,
		BROOD_SHADE,
		1.0,
		true
	)


func _draw_worker() -> void:
	_draw_ellipse(Vector2(-6.0, 3.5), Vector2(9.0, 5.6), SHADOW_COLOR)
	_draw_ellipse(Vector2(4.0, 3.2), Vector2(10.0, 4.8), SHADOW_COLOR)
	var stride: float = _get_stride()
	var leg_pairs: Array[PackedVector2Array] = [
		PackedVector2Array([Vector2(-1.0, -4.0), Vector2(-6.0, -11.0), Vector2(-12.0, -12.0)]),
		PackedVector2Array([Vector2(3.0, -4.0), Vector2(3.0, -12.0), Vector2(8.0, -15.0)]),
		PackedVector2Array([Vector2(6.0, -2.0), Vector2(12.0, -9.0), Vector2(17.0, -9.0)]),
		PackedVector2Array([Vector2(-1.0, 4.0), Vector2(-6.0, 11.0), Vector2(-12.0, 12.0)]),
		PackedVector2Array([Vector2(3.0, 4.0), Vector2(3.0, 12.0), Vector2(8.0, 15.0)]),
		PackedVector2Array([Vector2(6.0, 2.0), Vector2(12.0, 9.0), Vector2(17.0, 9.0)]),
	]
	for index: int in leg_pairs.size():
		var leg: PackedVector2Array = leg_pairs[index].duplicate()
		var direction: float = 1.0 if index % 2 == 0 else -1.0
		leg[1].x += stride * direction * 0.55
		leg[2].x += stride * direction
		draw_polyline(leg, WORKER_OUTLINE, 3.0, true)
		draw_polyline(leg, LIMB_COLOR, 1.55, true)

	draw_line(Vector2(-1.0, 0.0), Vector2(-4.0, 0.0), WORKER_OUTLINE, 3.2)
	draw_line(Vector2(6.0, -0.2), Vector2(8.0, -0.4), WORKER_OUTLINE, 3.0)
	_draw_ellipse(Vector2(-8.0, 0.0), Vector2(8.8, 6.6), WORKER_OUTLINE)
	_draw_ellipse(Vector2(-8.5, -0.5), Vector2(7.4, 5.2), WORKER_BODY)
	_draw_ellipse(Vector2(2.0, 0.0), Vector2(5.8, 5.7), WORKER_OUTLINE)
	_draw_ellipse(Vector2(1.8, -0.4), Vector2(4.5, 4.4), WORKER_MID)
	_draw_ellipse(Vector2(10.2, -0.5), Vector2(6.2, 5.8), WORKER_OUTLINE)
	_draw_ellipse(Vector2(10.0, -0.9), Vector2(5.0, 4.6), WORKER_BODY)
	_draw_ellipse(Vector2(-10.2, -2.1), Vector2(4.4, 2.0), WORKER_HIGHLIGHT)
	_draw_ellipse(Vector2(0.7, -2.0), Vector2(2.0, 1.2), WORKER_HIGHLIGHT)
	_draw_ellipse(Vector2(8.7, -2.4), Vector2(2.2, 1.2), WORKER_HIGHLIGHT)
	var antennae: Array[PackedVector2Array] = [
		PackedVector2Array([
			Vector2(13.0, -4.0),
			Vector2(18.0, -8.0),
			Vector2(22.0, -10.0),
		]),
		PackedVector2Array([
			Vector2(14.0, -1.0),
			Vector2(20.0, -3.0),
			Vector2(23.0, -1.0),
		]),
	]
	for antenna: PackedVector2Array in antennae:
		draw_polyline(antenna, WORKER_OUTLINE, 2.4, true)
		draw_polyline(antenna, LIMB_COLOR, 1.2, true)
	draw_circle(Vector2(12.0, -2.4), 1.4, WORKER_OUTLINE)
	draw_circle(Vector2(12.2, -2.6), 0.75, EYE_COLOR)
	_draw_behavior_cue()


func _draw_behavior_cue() -> void:
	match _behavior_pose:
		BehaviorPose.COLLECTING_FOOD:
			_draw_mandibles(Vector2(18.0, 1.0), true)
			draw_circle(Vector2(23.0, 7.0), 8.0, SUGAR_GLOW)
			draw_circle(Vector2(23.0, 7.0), 4.5, SUGAR_COLOR)
		BehaviorPose.CARRYING_FOOD:
			_draw_mandibles(Vector2(18.0, -1.0), false)
			draw_circle(Vector2(22.0, -6.0), 9.0, SUGAR_GLOW)
			draw_circle(Vector2(22.0, -6.0), 5.0, SUGAR_COLOR)
			draw_circle(Vector2(20.5, -7.5), 1.4, Color.WHITE)
		BehaviorPose.SHARING_FOOD:
			_draw_mandibles(Vector2(18.0, 0.0), false)
			draw_circle(Vector2(22.0, 0.0), 5.0, SUGAR_COLOR)
			draw_circle(Vector2(29.0, 0.0), 3.4, FOOD_SHARE_COLOR)
			draw_line(
				Vector2(23.0, 0.0),
				Vector2(30.0, 0.0),
				FOOD_SHARE_COLOR,
				2.0,
				true
			)
		BehaviorPose.FEEDING_BROOD:
			_draw_mandibles(Vector2(18.0, 2.0), false)
			draw_circle(Vector2(22.0, 5.0), 4.0, BROOD_CARE_COLOR)
			draw_arc(
				Vector2(24.0, 5.0),
				8.0,
				PI * 0.76,
				PI * 1.28,
				10,
				BROOD_CARE_COLOR,
				2.0,
				true
			)
		BehaviorPose.HANDLING_BROOD:
			_draw_mandibles(Vector2(18.0, -1.0), true)
			draw_arc(
				Vector2(20.0, -6.0),
				8.0,
				PI * 0.12,
				PI * 0.88,
				10,
				BROOD_CARE_COLOR,
				2.2,
				true
			)
		BehaviorPose.CARRYING_BROOD:
			_draw_mandibles(Vector2(18.0, -2.0), false)
			draw_line(
				Vector2(18.0, -5.0),
				Vector2(14.0, -11.0),
				BROOD_CARE_COLOR,
				2.2,
				true
			)
		BehaviorPose.CARRYING_WASTE:
			_draw_mandibles(Vector2(18.0, -1.0), false)
			draw_circle(Vector2(22.0, -5.0), 7.5, Color(0.70, 0.48, 0.22, 0.24))
			draw_circle(Vector2(22.0, -5.0), 4.6, WASTE_COLOR)
		BehaviorPose.OBSERVING:
			draw_arc(
				Vector2(18.0, -4.0),
				11.0,
				-PI * 0.60,
				PI * 0.12,
				12,
				OBSERVE_COLOR,
				2.0,
				true
			)


func _draw_mandibles(anchor: Vector2, open: bool) -> void:
	var spread: float = 5.5 if open else 3.0
	draw_line(
		anchor,
		anchor + Vector2(6.0, -spread),
		WORKER_OUTLINE,
		2.6,
		true
	)
	draw_line(
		anchor,
		anchor + Vector2(6.0, spread),
		WORKER_OUTLINE,
		2.6,
		true
	)
	draw_line(
		anchor,
		anchor + Vector2(5.5, -spread),
		LIMB_COLOR,
		1.2,
		true
	)
	draw_line(
		anchor,
		anchor + Vector2(5.5, spread),
		LIMB_COLOR,
		1.2,
		true
	)


func _get_stride() -> float:
	if _reduced_motion or not _is_locomotion_pose():
		return 0.0
	return sin(_animation_phase * TAU) * 4.0


func _is_locomotion_pose() -> bool:
	return _behavior_pose in [
		BehaviorPose.WALKING,
		BehaviorPose.CARRYING_FOOD,
		BehaviorPose.CARRYING_BROOD,
		BehaviorPose.CARRYING_WASTE,
	]


func _draw_selection_outline() -> void:
	draw_arc(
		Vector2(2.0, 0.0),
		24.0,
		0.0,
		TAU,
		40,
		SELECTION_OUTLINE,
		2.0,
		true
	)


func _draw_ellipse(center: Vector2, radii: Vector2, color: Color) -> void:
	draw_set_transform(center, 0.0, radii)
	draw_circle(Vector2.ZERO, 1.0, color)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
