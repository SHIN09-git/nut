class_name FacilityLayoutAccessibilityTestSuite
extends RefCounted

var _assertion_count: int = 0
var _failure_count: int = 0


func run(scene_root: Node) -> void:
	var view: FacilityLayoutView = FacilityLayoutView.new()
	view.size = Vector2(800, 520)
	scene_root.add_child(view)
	var feedback: Array[int] = []
	view.interaction_feedback.connect(func(code: int) -> void:
		feedback.append(code)
	)

	var snapshot: HabitatLayoutSnapshot = HabitatLayoutSnapshot.new()
	snapshot.active = true
	snapshot.grid_size = Vector2i(4, 4)
	snapshot.placement_options.append(
		FacilityPlacementOptionSnapshot.new(
			CampaignState.FACILITY_SMALL_FORAGING_BOX,
			Vector2i(1, 1),
			0
		)
	)
	_expect_true(view.apply_snapshot(snapshot), "active layout snapshot applies")
	_expect_true(
		view.begin_placement(
			CampaignState.FACILITY_SMALL_FORAGING_BOX
		),
		"available facility begins placement"
	)
	var preview: FacilityPlacementPreviewView = (
		view.get_node_or_null("PlacementPreviewView")
		as FacilityPlacementPreviewView
	)
	_expect_true(
		preview != null and preview.visible,
		"placement uses a visible dedicated preview node"
	)
	_expect_int(
		view.get_placement_cue(),
		FacilityLayoutView.PlacementCue.VALID,
		"valid preview exposes a non-color semantic cue"
	)
	view.handle_keyboard_action(KEY_LEFT)
	_expect_true(
		view.get_node_or_null("PlacementPreviewView") == preview,
		"moving the placement cursor reuses the preview node"
	)
	_expect_int(
		view.get_placement_cue(),
		FacilityLayoutView.PlacementCue.INVALID,
		"invalid preview exposes a distinct non-color semantic cue"
	)
	view.handle_keyboard_action(KEY_ENTER)
	_expect_int(
		feedback[-1],
		FacilityLayoutView.InteractionFeedback.PLACEMENT_INVALID,
		"invalid keyboard confirmation emits a recoverable reason"
	)

	view.cancel_placement()
	_expect_true(
		not preview.visible,
		"canceling placement hides the preview node"
	)
	view.request_remove_selected()
	_expect_int(
		feedback[-1],
		FacilityLayoutView.InteractionFeedback.SELECTION_REQUIRED,
		"editing without selection emits an explicit reason"
	)
	snapshot.action_pending = true
	view.apply_snapshot(snapshot)
	view.request_rotate_selected()
	_expect_int(
		feedback[-1],
		FacilityLayoutView.InteractionFeedback.ACTION_PENDING,
		"pending command emits an explicit wait reason"
	)
	snapshot.action_pending = false
	view.apply_snapshot(snapshot)
	view.begin_placement(&"unavailable_fixture")
	_expect_int(
		feedback[-1],
		FacilityLayoutView.InteractionFeedback.PLACEMENT_UNAVAILABLE,
		"unavailable supply emits an explicit recovery reason"
	)
	view.queue_free()


func get_assertion_count() -> int:
	return _assertion_count


func get_failure_count() -> int:
	return _failure_count


func _expect_true(actual: bool, message: String) -> void:
	_assertion_count += 1
	if actual:
		return
	_record_failure(message, "true", "false")


func _expect_int(actual: int, expected: int, message: String) -> void:
	_assertion_count += 1
	if actual == expected:
		return
	_record_failure(message, str(expected), str(actual))


func _record_failure(
	message: String,
	expected: String,
	actual: String
) -> void:
	_failure_count += 1
	printerr("  %s - expected %s, got %s" % [message, expected, actual])
