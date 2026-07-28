class_name ReducedMotionTestSuite
extends RefCounted

var _assertion_count: int = 0
var _failure_count: int = 0
var _scene_root: Node


func run(scene_root: Node) -> void:
	_scene_root = scene_root
	_test_queen_idle_motion_can_be_disabled()
	_test_ant_transition_finishes_without_motion()


func get_assertion_count() -> int:
	return _assertion_count


func get_failure_count() -> int:
	return _failure_count


func _test_queen_idle_motion_can_be_disabled() -> void:
	var queen: QueenView = QueenView.new()
	_scene_root.add_child(queen)
	queen.set_habitat_position(Vector2(100.0, 100.0))
	queen.set_simulation_tick(QueenView.IDLE_PERIOD_TICKS / 4)
	_expect_true(
		not queen.position.is_equal_approx(Vector2(100.0, 100.0)),
		"default queen projection has deterministic idle motion"
	)
	queen.set_reduced_motion(true)
	_expect_vector2(
		queen.position,
		Vector2(100.0, 100.0),
		"reduced motion removes queen bobbing"
	)
	queen.set_simulation_tick(QueenView.IDLE_PERIOD_TICKS / 2)
	_expect_vector2(
		queen.position,
		Vector2(100.0, 100.0),
		"later Ticks remain still when reduced motion is active"
	)
	_scene_root.remove_child(queen)
	queen.free()


func _test_ant_transition_finishes_without_motion() -> void:
	var ant: AntView = AntView.new()
	_scene_root.add_child(ant)
	var snapshot: AntSnapshot = AntSnapshot.new(
		10,
		AntModel.LifeStage.LARVA,
		0,
		0,
		10,
		&"nursery"
	)
	_expect_true(
		ant.configure(snapshot, Vector2(20.0, 30.0)),
		"ant transition fixture configures"
	)
	_expect_true(
		ant.is_transition_active(),
		"default ant appearance uses a short visual transition"
	)
	ant.set_reduced_motion(true)
	_expect_true(
		not ant.is_transition_active(),
		"reduced motion finishes the ant transition immediately"
	)
	_expect_vector2(
		ant.scale,
		Vector2.ONE,
		"reduced-motion ant has a stable final scale"
	)
	_expect_float(
		ant.modulate.a,
		1.0,
		"reduced-motion ant has final opacity"
	)
	_scene_root.remove_child(ant)
	ant.free()


func _expect_true(actual: bool, message: String) -> void:
	_assertion_count += 1
	if actual:
		return
	_record_failure(message, "true", "false")


func _expect_vector2(actual: Vector2, expected: Vector2, message: String) -> void:
	_assertion_count += 1
	if actual.is_equal_approx(expected):
		return
	_record_failure(message, str(expected), str(actual))


func _expect_float(actual: float, expected: float, message: String) -> void:
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
