class_name FacilityWorldInteractionTestSuite
extends RefCounted

var _assertion_count: int = 0
var _failure_count: int = 0


func run(scene_root: Node) -> void:
	var view: FacilityLayoutView = FacilityLayoutView.new()
	view.size = Vector2(800.0, 520.0)
	scene_root.add_child(view)
	var snapshot: HabitatLayoutSnapshot = HabitatLayoutSnapshot.new()
	snapshot.active = true
	snapshot.grid_size = Vector2i(6, 4)
	var base: FacilitySnapshot = FacilitySnapshot.new(
		5,
		&"base_fixture",
		Vector2i(1, 1),
		0,
		Vector2i(2, 2),
		FacilityData.PlacementLayer.BASE,
		&"base_zone",
		true,
		true
	)
	var overlay: FacilitySnapshot = FacilitySnapshot.new(
		9,
		&"overlay_fixture",
		Vector2i(1, 1),
		0,
		Vector2i(2, 2),
		FacilityData.PlacementLayer.OVERLAY,
		&"",
		true,
		true
	)
	snapshot.facilities.assign([overlay, base])
	_expect_true(view.apply_snapshot(snapshot), "world fixture applies")
	_expect_int(
		view.mouse_filter,
		Control.MOUSE_FILTER_IGNORE,
		"ordinary world remains owned by the observation parent"
	)

	var shared_center: Vector2 = view.project_facility_rect(
		base.facility_id
	).get_center()
	_expect_int(
		view.find_facility_at(shared_center),
		overlay.facility_id,
		"overlapping hit chooses placement layer then stable ID"
	)
	snapshot.facilities.reverse()
	_expect_true(
		view.apply_snapshot(snapshot),
		"reordered world fixture reapplies"
	)
	_expect_int(
		view.find_facility_at(shared_center),
		overlay.facility_id,
		"hit result ignores snapshot array order"
	)

	var selected_ids: Array[int] = []
	view.selection_changed.connect(func(facility_id: int) -> void:
		selected_ids.append(facility_id)
	)
	_expect_int(
		view.select_facility_at(shared_center),
		overlay.facility_id,
		"ordinary selection returns the stable facility ID"
	)
	_expect_int(
		selected_ids[-1],
		overlay.facility_id,
		"ordinary selection emits the stable facility ID"
	)

	view.set_camera_zoom(1.45)
	view.pan_by(Vector2(76.0, -42.0))
	var transformed_center: Vector2 = view.project_facility_rect(
		base.facility_id
	).get_center()
	_expect_int(
		view.find_facility_at(transformed_center),
		overlay.facility_id,
		"zoom and pan preserve deterministic hit ownership"
	)
	_expect_int(
		view.find_facility_at(Vector2(-1000.0, -1000.0)),
		-1,
		"coordinates outside the world do not fabricate a hit"
	)

	_expect_true(
		view.focus_facility(base.facility_id),
		"an existing facility can be focused"
	)
	_expect_vector_near(
		view.project_facility_rect(base.facility_id).get_center(),
		view.size * 0.5,
		0.001,
		"focus moves the selected facility to the viewport center"
	)
	_expect_true(
		view.get_camera_offset().is_finite()
			and is_finite(view.get_camera_zoom()),
		"focus keeps camera values finite"
	)
	_expect_true(
		view.set_selected_facility_id(-1),
		"selection can be cleared without editing authority"
	)
	_expect_int(
		selected_ids[-1],
		-1,
		"clearing selection emits the empty stable ID"
	)
	scene_root.remove_child(view)
	view.free()


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


func _expect_vector_near(
	actual: Vector2,
	expected: Vector2,
	tolerance: float,
	message: String
) -> void:
	_assertion_count += 1
	if actual.distance_to(expected) <= tolerance:
		return
	_record_failure(message, str(expected), str(actual))


func _record_failure(
	message: String,
	expected: String,
	actual: String
) -> void:
	_failure_count += 1
	printerr("  %s - expected %s, got %s" % [message, expected, actual])
