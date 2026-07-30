class_name AntBehaviorAnimationTestSuite
extends RefCounted

var _assertion_count: int = 0
var _failure_count: int = 0
var _scene_root: Node


func run(scene_root: Node) -> void:
	_scene_root = scene_root
	_test_pose_facing_and_phase_are_view_only()
	_test_reduced_motion_keeps_static_pose_semantics()


func get_assertion_count() -> int:
	return _assertion_count


func get_failure_count() -> int:
	return _failure_count


func _test_pose_facing_and_phase_are_view_only() -> void:
	var ant: AntView = _create_worker_view(41)
	ant.set_behavior_pose(
		AntView.BehaviorPose.WALKING,
		-12.0,
		0.25
	)
	_expect_int(
		ant.get_behavior_pose(),
		AntView.BehaviorPose.WALKING,
		"walking pose is stored only on the worker view"
	)
	_expect_float(
		ant.get_facing_sign(),
		-1.0,
		"negative route direction faces the worker left"
	)
	_expect_float(
		ant.get_animation_phase(),
		0.25,
		"walking phase is explicit and bounded"
	)
	_expect_int(
		ant.get_entity_id(),
		41,
		"pose changes preserve the stable entity ID"
	)
	_expect_int(
		ant.get_life_stage(),
		AntModel.LifeStage.WORKER,
		"pose changes do not alter lifecycle state"
	)
	_destroy_ant(ant)


func _test_reduced_motion_keeps_static_pose_semantics() -> void:
	var ant: AntView = _create_worker_view(42)
	ant.set_reduced_motion(true)
	ant.set_behavior_pose(
		AntView.BehaviorPose.CARRYING_FOOD,
		9.0,
		0.75
	)
	_expect_int(
		ant.get_behavior_pose(),
		AntView.BehaviorPose.CARRYING_FOOD,
		"reduced motion retains the authoritative carry pose"
	)
	_expect_float(
		ant.get_facing_sign(),
		1.0,
		"reduced motion retains route-facing direction"
	)
	_expect_float(
		ant.get_animation_phase(),
		0.0,
		"reduced motion freezes the walk cycle at a stable pose"
	)
	_destroy_ant(ant)


func _create_worker_view(entity_id: int) -> AntView:
	var ant: AntView = AntView.new()
	_scene_root.add_child(ant)
	var snapshot: AntSnapshot = AntSnapshot.new(
		entity_id,
		AntModel.LifeStage.WORKER,
		0,
		0,
		0,
		&"test_tube_nest"
	)
	if not ant.configure(snapshot, Vector2(40.0, 40.0)):
		_record_failure("worker animation fixture configures", "true", "false")
	return ant


func _destroy_ant(ant: AntView) -> void:
	_scene_root.remove_child(ant)
	ant.free()


func _expect_int(actual: int, expected: int, message: String) -> void:
	_assertion_count += 1
	if actual == expected:
		return
	_record_failure(message, str(expected), str(actual))


func _expect_float(
	actual: float,
	expected: float,
	message: String
) -> void:
	_assertion_count += 1
	if is_equal_approx(actual, expected):
		return
	_record_failure(message, str(expected), str(actual))


func _record_failure(
	message: String,
	expected: String,
	actual: String
) -> void:
	_failure_count += 1
	printerr("  %s - expected %s, got %s" % [message, expected, actual])
