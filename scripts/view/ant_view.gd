class_name AntView
extends Node2D

const BROOD_OUTLINE: Color = Color(0.49, 0.44, 0.34, 1.0)
const BROOD_LIGHT: Color = Color(0.91, 0.88, 0.72, 1.0)
const BROOD_SHADE: Color = Color(0.70, 0.66, 0.51, 1.0)
const WORKER_BODY: Color = Color(0.16, 0.09, 0.055, 1.0)
const WORKER_HIGHLIGHT: Color = Color(0.36, 0.21, 0.12, 1.0)
const SELECTION_OUTLINE: Color = Color(0.88, 0.76, 0.46, 0.74)
const TRANSITION_DURATION_SECONDS: float = 0.38

var entity_id: int = -1
var life_stage: AntModel.LifeStage = AntModel.LifeStage.EGG
var _transition_count: int = 0
var _transition_elapsed_seconds: float = TRANSITION_DURATION_SECONDS
var _visuals_paused: bool = false
var _slot_position: Vector2 = Vector2.ZERO
var _selected: bool = false


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


func get_entity_id() -> int:
	return entity_id


func get_life_stage() -> AntModel.LifeStage:
	return life_stage


func get_transition_count() -> int:
	return _transition_count


func is_transition_active() -> bool:
	return _transition_elapsed_seconds < TRANSITION_DURATION_SECONDS


func _process(delta: float) -> void:
	if _visuals_paused or not is_transition_active():
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
	match life_stage:
		AntModel.LifeStage.EGG:
			_draw_egg()
		AntModel.LifeStage.LARVA:
			_draw_larva()
		AntModel.LifeStage.PUPA:
			_draw_pupa()
		AntModel.LifeStage.WORKER:
			if _selected:
				_draw_selection_outline()
			_draw_worker()


func _start_transition_animation() -> void:
	_transition_elapsed_seconds = 0.0
	scale = Vector2.ONE * 0.72
	modulate.a = 0.42


func _draw_egg() -> void:
	_draw_ellipse(Vector2.ZERO, Vector2(8.0, 5.0), BROOD_OUTLINE)
	_draw_ellipse(Vector2(-0.5, -0.6), Vector2(6.4, 3.6), BROOD_LIGHT)


func _draw_larva() -> void:
	var body_points: PackedVector2Array = PackedVector2Array([
		Vector2(-10.0, 2.5),
		Vector2(-5.0, -1.5),
		Vector2(0.0, -2.5),
		Vector2(5.0, 0.0),
		Vector2(10.0, 3.0),
	])
	draw_polyline(body_points, BROOD_OUTLINE, 9.0, true)
	draw_polyline(body_points, BROOD_LIGHT, 6.0, true)
	for joint: Vector2 in body_points:
		draw_circle(joint, 3.1, BROOD_LIGHT)
	draw_circle(Vector2(9.5, 2.7), 2.0, BROOD_SHADE)


func _draw_pupa() -> void:
	_draw_ellipse(Vector2.ZERO, Vector2(11.0, 7.0), BROOD_OUTLINE)
	_draw_ellipse(Vector2(-0.8, -0.5), Vector2(9.0, 5.2), BROOD_SHADE)
	draw_circle(Vector2(6.0, -1.0), 3.1, BROOD_LIGHT)
	draw_line(Vector2(-6.0, -4.0), Vector2(-3.0, 4.0), BROOD_LIGHT, 1.6, true)
	draw_line(Vector2(-1.0, -5.0), Vector2(2.0, 4.5), BROOD_LIGHT, 1.6, true)


func _draw_worker() -> void:
	var limb_color: Color = WORKER_HIGHLIGHT
	var leg_pairs: Array[PackedVector2Array] = [
		PackedVector2Array([Vector2(-1.0, -4.0), Vector2(-6.0, -11.0), Vector2(-12.0, -12.0)]),
		PackedVector2Array([Vector2(3.0, -4.0), Vector2(3.0, -12.0), Vector2(8.0, -15.0)]),
		PackedVector2Array([Vector2(6.0, -2.0), Vector2(12.0, -9.0), Vector2(17.0, -9.0)]),
		PackedVector2Array([Vector2(-1.0, 4.0), Vector2(-6.0, 11.0), Vector2(-12.0, 12.0)]),
		PackedVector2Array([Vector2(3.0, 4.0), Vector2(3.0, 12.0), Vector2(8.0, 15.0)]),
		PackedVector2Array([Vector2(6.0, 2.0), Vector2(12.0, 9.0), Vector2(17.0, 9.0)]),
	]
	for leg: PackedVector2Array in leg_pairs:
		draw_polyline(leg, limb_color, 1.8, true)

	_draw_ellipse(Vector2(-8.0, 0.0), Vector2(8.0, 6.0), WORKER_BODY)
	_draw_ellipse(Vector2(2.0, 0.0), Vector2(5.0, 5.0), WORKER_BODY)
	_draw_ellipse(Vector2(10.0, -0.5), Vector2(5.5, 5.0), WORKER_BODY)
	draw_line(Vector2(13.0, -4.0), Vector2(19.0, -9.0), limb_color, 1.5, true)
	draw_line(Vector2(14.0, -1.0), Vector2(21.0, -3.0), limb_color, 1.5, true)
	draw_circle(Vector2(12.0, -2.2), 1.0, Color(0.82, 0.63, 0.30, 1.0))


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
