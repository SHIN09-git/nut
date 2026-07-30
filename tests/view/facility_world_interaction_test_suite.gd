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
		view.get_facility_view_count(),
		2,
		"available facilities create one stable node each"
	)
	var base_view: FacilityView = view.get_facility_view(
		base.facility_id
	)
	var overlay_view: FacilityView = view.get_facility_view(
		overlay.facility_id
	)
	_expect_true(
		base_view != null and overlay_view != null,
		"stable facility IDs resolve to facility views"
	)
	_expect_true(
		base_view.mouse_filter == Control.MOUSE_FILTER_IGNORE
			and overlay_view.mouse_filter
				== Control.MOUSE_FILTER_IGNORE,
		"facility nodes do not take interaction authority from the layout"
	)
	var zones: Array[HabitatZoneSnapshot] = [
		HabitatZoneSnapshot.new(
			&"base_zone",
			0.5,
			[],
			true
		),
	]
	view.apply_zone_topology(zones)
	var zone_before: Vector2 = view.project_zone_position(&"base_zone")
	zones[0].humidity = 0.8
	view.apply_zone_topology(zones)
	_expect_vector_near(
		view.project_zone_position(&"base_zone"),
		zone_before,
		0.001,
		"environment-only snapshots reuse stable layout anchors"
	)
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
	_expect_true(
		view.get_facility_view(base.facility_id) == base_view
			and view.get_facility_view(overlay.facility_id)
				== overlay_view,
		"snapshot array order does not replace stable facility nodes"
	)
	_expect_int(
		view.get_facility_view_count(),
		2,
		"reapplying a snapshot does not duplicate facility nodes"
	)
	_expect_int(
		view.find_facility_at(shared_center),
		overlay.facility_id,
		"hit result ignores snapshot array order"
	)
	base.slot = Vector2i(2, 1)
	overlay.slot = base.slot
	snapshot.revision += 1
	_expect_true(
		view.apply_snapshot(snapshot),
		"layout revision change reapplies"
	)
	view.apply_zone_topology(zones)
	_expect_true(
		not view.project_zone_position(&"base_zone").is_equal_approx(
			zone_before
		),
		"layout revision invalidates the cached zone anchor"
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
	_expect_true(
		overlay_view.is_selected() and not base_view.is_selected(),
		"selection updates the existing facility view"
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
	var focused_base_rect: Rect2 = view.project_facility_rect(
		base.facility_id
	)
	_expect_vector_near(
		base_view.position,
		focused_base_rect.position,
		0.001,
		"camera changes reposition the existing facility node"
	)
	_expect_vector_near(
		base_view.size,
		focused_base_rect.size,
		0.001,
		"camera changes resize the existing facility node"
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
	overlay.available = false
	snapshot.revision += 1
	_expect_true(
		view.apply_snapshot(snapshot),
		"snapshot with an unavailable facility reapplies"
	)
	_expect_int(
		view.get_facility_view_count(),
		1,
		"unavailable facilities leave no mapped visual node"
	)
	_expect_true(
		view.get_facility_view(overlay.facility_id) == null,
		"removed facility ID no longer resolves to a view"
	)
	_expect_true(
		view.get_facility_view(base.facility_id) == base_view,
		"removing another facility preserves the surviving node"
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
