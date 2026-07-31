class_name AntBehaviorAnimationTestSuite
extends RefCounted

var _assertion_count: int = 0
var _failure_count: int = 0
var _scene_root: Node


func run(scene_root: Node) -> void:
	_scene_root = scene_root
	_test_pose_facing_and_phase_are_view_only()
	_test_reduced_motion_keeps_static_pose_semantics()
	_test_brood_motion_is_tick_and_identity_driven()
	_test_brood_handling_pose_is_view_only()
	_test_idle_antennae_follow_view_phase()
	_test_worker_emergence_unfolds_on_the_stable_view()
	_test_worker_emergence_respects_reduced_motion()


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


func _test_brood_motion_is_tick_and_identity_driven() -> void:
	var first: AntView = _create_brood_view(11)
	var second: AntView = _create_brood_view(12)
	first.set_simulation_tick(25)
	second.set_simulation_tick(25)
	var first_phase: float = first.get_brood_animation_phase()
	_expect_true(
		not is_equal_approx(
			first_phase,
			second.get_brood_animation_phase()
		),
		"stable entity ID offsets brood motion without randomness"
	)
	first.set_simulation_tick(25)
	_expect_float(
		first.get_brood_animation_phase(),
		first_phase,
		"reapplying the same Tick keeps brood motion deterministic"
	)
	first.set_simulation_tick(26)
	_expect_true(
		not is_equal_approx(
			first.get_brood_animation_phase(),
			first_phase
		),
		"advancing the fixed Tick advances the brood pose"
	)
	first.set_reduced_motion(true)
	_expect_float(
		first.get_brood_animation_phase(),
		0.0,
		"reduced motion freezes brood at its neutral pose"
	)
	_expect_int(
		first.get_life_stage(),
		AntModel.LifeStage.LARVA,
		"brood presentation never changes lifecycle authority"
	)
	_destroy_ant(first)
	_destroy_ant(second)


func _test_brood_handling_pose_is_view_only() -> void:
	var brood: AntView = _create_brood_view(13)
	brood.set_brood_pose(AntView.BroodPose.PICKING_UP, 0.35)
	_expect_int(
		brood.get_brood_pose(),
		AntView.BroodPose.PICKING_UP,
		"brood handling pose is stored only on the view"
	)
	_expect_float(
		brood.get_brood_task_progress(),
		0.35,
		"brood handling pose retains snapshot task progress"
	)
	brood.set_brood_pose(AntView.BroodPose.DROPPING, 2.0)
	_expect_float(
		brood.get_brood_task_progress(),
		1.0,
		"brood handling progress is bounded for drawing"
	)
	_expect_int(
		brood.get_entity_id(),
		13,
		"brood handling poses preserve the stable entity ID"
	)
	_expect_int(
		brood.get_life_stage(),
		AntModel.LifeStage.LARVA,
		"brood handling poses do not alter lifecycle state"
	)
	brood.set_reduced_motion(true)
	_expect_int(
		brood.get_brood_pose(),
		AntView.BroodPose.DROPPING,
		"reduced motion retains the snapshot-derived brood pose"
	)
	_destroy_ant(brood)


func _test_idle_antennae_follow_view_phase() -> void:
	var ant: AntView = _create_worker_view(43)
	ant.set_behavior_pose(AntView.BehaviorPose.IDLE, 1.0, 0.25)
	_expect_true(
		ant.get_antenna_probe_amount() > 2.0,
		"idle antennae use the deterministic view phase"
	)
	ant.set_behavior_pose(AntView.BehaviorPose.WALKING, 1.0, 0.25)
	_expect_float(
		ant.get_antenna_probe_amount(),
		0.0,
		"locomotion poses do not add idle antenna motion"
	)
	ant.set_reduced_motion(true)
	ant.set_behavior_pose(AntView.BehaviorPose.OBSERVING, 1.0, 0.25)
	_expect_float(
		ant.get_antenna_probe_amount(),
		0.0,
		"reduced motion freezes idle antenna motion"
	)
	_destroy_ant(ant)


func _test_worker_emergence_unfolds_on_the_stable_view() -> void:
	var ant: AntView = _create_brood_view(
		44,
		AntModel.LifeStage.PUPA
	)
	var worker_snapshot: AntSnapshot = AntSnapshot.new(
		44,
		AntModel.LifeStage.WORKER,
		0,
		0,
		0,
		&"test_tube_nest"
	)
	_expect_true(
		ant.apply_snapshot(worker_snapshot),
		"pupa-to-worker snapshot applies to the existing view"
	)
	_expect_true(
		ant.is_worker_emergence_active(),
		"pupa-to-worker transition starts the emergence pose"
	)
	_expect_float(
		ant.get_worker_emergence_progress(),
		0.0,
		"emergence begins folded"
	)
	_expect_float(
		ant.get_worker_emergence_limb_ratio(),
		0.0,
		"legs and antennae begin folded"
	)
	_expect_true(
		ant.apply_snapshot(worker_snapshot),
		"same-Tick worker replay remains idempotent"
	)
	_expect_true(
		ant.is_worker_emergence_active(),
		"same-stage replay does not skip the emergence pose"
	)
	ant.set_visuals_paused(true)
	ant._process(AntView.TRANSITION_DURATION_SECONDS)
	_expect_float(
		ant.get_worker_emergence_progress(),
		0.0,
		"pause freezes emergence progress"
	)
	ant.set_visuals_paused(false)
	ant._process(AntView.TRANSITION_DURATION_SECONDS * 0.5)
	var half_progress: float = ant.get_worker_emergence_progress()
	_expect_true(
		half_progress > 0.49 and half_progress < 0.51,
		"resuming advances the emergence display time"
	)
	_expect_true(
		ant.get_worker_emergence_limb_ratio() > half_progress,
		"limbs unfold before the recovery portion"
	)
	ant._process(AntView.TRANSITION_DURATION_SECONDS)
	_expect_true(
		not ant.is_worker_emergence_active(),
		"emergence settles into the normal worker pose"
	)
	_expect_float(
		ant.get_worker_emergence_progress(),
		1.0,
		"settled emergence reports complete progress"
	)
	_expect_float(
		ant.get_worker_emergence_limb_ratio(),
		1.0,
		"settled worker has fully extended limbs"
	)
	_expect_int(
		ant.get_entity_id(),
		44,
		"emergence preserves the stable entity ID"
	)
	_expect_int(
		ant.get_transition_count(),
		1,
		"same-stage replay does not restart emergence"
	)
	_destroy_ant(ant)


func _test_worker_emergence_respects_reduced_motion() -> void:
	var ant: AntView = _create_brood_view(
		45,
		AntModel.LifeStage.PUPA
	)
	ant.set_reduced_motion(true)
	var worker_snapshot: AntSnapshot = AntSnapshot.new(
		45,
		AntModel.LifeStage.WORKER,
		0,
		0,
		0,
		&"test_tube_nest"
	)
	_expect_true(
		ant.apply_snapshot(worker_snapshot),
		"reduced-motion worker snapshot applies"
	)
	_expect_true(
		not ant.is_worker_emergence_active(),
		"reduced motion skips the display-time unfold"
	)
	_expect_float(
		ant.get_worker_emergence_progress(),
		1.0,
		"reduced motion uses the settled worker pose"
	)
	_expect_float(
		ant.get_worker_emergence_limb_ratio(),
		1.0,
		"reduced motion keeps limbs fully legible"
	)
	_expect_int(
		ant.get_life_stage(),
		AntModel.LifeStage.WORKER,
		"reduced motion does not suppress lifecycle authority"
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


func _create_brood_view(
	entity_id: int,
	stage: AntModel.LifeStage = AntModel.LifeStage.LARVA
) -> AntView:
	var ant: AntView = AntView.new()
	_scene_root.add_child(ant)
	var snapshot: AntSnapshot = AntSnapshot.new(
		entity_id,
		stage,
		0,
		0,
		0,
		&"test_tube_nest"
	)
	if not ant.configure(snapshot, Vector2(40.0, 40.0)):
		_record_failure("brood animation fixture configures", "true", "false")
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


func _expect_true(actual: bool, message: String) -> void:
	_assertion_count += 1
	if actual:
		return
	_record_failure(message, "true", "false")


func _record_failure(
	message: String,
	expected: String,
	actual: String
) -> void:
	_failure_count += 1
	printerr("  %s - expected %s, got %s" % [message, expected, actual])
