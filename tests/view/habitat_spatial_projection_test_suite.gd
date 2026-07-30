class_name HabitatSpatialProjectionTestSuite
extends RefCounted

const SPECIES_A_DATA: SpeciesData = preload(
	"res://data/species/species_a.tres"
)
const ACT1_SCENARIO_DATA: HabitatScenarioData = preload(
	"res://data/habitats/act1_test_tube.tres"
)

var _assertion_count: int = 0
var _failure_count: int = 0


func run() -> void:
	_test_projection_fits_and_inverts_grid()
	_test_port_coordinates_are_exact_cell_interfaces()
	_test_snapshot_copies_rotated_port_geometry()
	_test_dual_chamber_zone_anchors_follow_orientation()
	_test_logical_passage_uses_connected_facility_anchors()
	_test_connection_and_hit_results_ignore_array_order()


func get_assertion_count() -> int:
	return _assertion_count


func get_failure_count() -> int:
	return _failure_count


func _test_projection_fits_and_inverts_grid() -> void:
	var projection: HabitatSpatialProjection = HabitatSpatialProjection.new()
	_expect_true(
		not projection.configure(
			Vector2i.ZERO,
			Rect2(0.0, 0.0, 400.0, 300.0)
		),
		"zero-sized logical grid is rejected"
	)
	_expect_true(
		not projection.configure(
			Vector2i(4, 2),
			Rect2(0.0, 0.0, 20.0, 20.0),
			12.0
		),
		"padding cannot consume the projection bounds"
	)
	_expect_true(
		projection.configure(
			Vector2i(4, 2),
			Rect2(100.0, 50.0, 400.0, 300.0),
			20.0
		),
		"valid logical grid configures"
	)
	_expect_float(
		projection.get_cell_size(),
		90.0,
		"cell size fits the limiting axis"
	)
	_expect_rect(
		projection.get_grid_rect(),
		Rect2(120.0, 110.0, 360.0, 180.0),
		"fitted grid remains centered inside padded bounds"
	)
	_expect_rect(
		projection.slot_rect(Vector2i(1, 0), Vector2i(2, 1)),
		Rect2(210.0, 110.0, 180.0, 90.0),
		"facility footprint maps to one canonical world rectangle"
	)
	_expect_vector2i(
		projection.world_to_slot(Vector2(299.0, 199.0)),
		Vector2i(1, 0),
		"world coordinate maps back to its stable logical slot"
	)
	_expect_vector2i(
		projection.world_to_slot(Vector2(119.0, 110.0)),
		Vector2i(-1, 0),
		"coordinate outside the grid is not silently clamped"
	)


func _test_port_coordinates_are_exact_cell_interfaces() -> void:
	var projection: HabitatSpatialProjection = HabitatSpatialProjection.new()
	_expect_true(
		projection.configure(
			Vector2i(4, 2),
			Rect2(0.0, 0.0, 400.0, 200.0),
			0.0
		),
		"port fixture projection configures"
	)
	var ports: Array[FacilityPortSnapshot] = [
		FacilityPortSnapshot.new(
			Vector2i(1, 1),
			FacilityPortData.Direction.NORTH,
			&"habitat"
		),
		FacilityPortSnapshot.new(
			Vector2i(1, 1),
			FacilityPortData.Direction.EAST,
			&"habitat"
		),
		FacilityPortSnapshot.new(
			Vector2i(1, 1),
			FacilityPortData.Direction.SOUTH,
			&"habitat"
		),
		FacilityPortSnapshot.new(
			Vector2i(1, 1),
			FacilityPortData.Direction.WEST,
			&"habitat"
		),
	]
	_expect_vector(
		projection.port_position(ports[0]),
		Vector2(150.0, 100.0),
		"north interface sits on the cell top edge"
	)
	_expect_vector(
		projection.port_position(ports[1]),
		Vector2(200.0, 150.0),
		"east interface sits on the cell right edge"
	)
	_expect_vector(
		projection.port_position(ports[2]),
		Vector2(150.0, 200.0),
		"south interface sits on the cell bottom edge"
	)
	_expect_vector(
		projection.port_position(ports[3]),
		Vector2(100.0, 150.0),
		"west interface sits on the cell left edge"
	)
	var facility: FacilitySnapshot = _facility(
		8,
		Vector2i(1, 1),
		Vector2i.ONE,
		FacilityData.PlacementLayer.BASE,
		&"port_fixture"
	)
	facility.ports.assign(ports)
	var positions: PackedVector2Array = (
		projection.facility_port_positions(facility)
	)
	_expect_int(positions.size(), 4, "all interface positions are projected")
	_expect_vector(
		positions[0],
		Vector2(150.0, 100.0),
		"interface order remains stable"
	)


func _test_snapshot_copies_rotated_port_geometry() -> void:
	var simulation: ColonySimulation = ColonySimulation.new(
		SPECIES_A_DATA,
		ACT1_SCENARIO_DATA
	)
	_expect_true(simulation.is_ready(), "Act 1 port fixture initializes")
	var snapshot: GameSnapshot = simulation.create_game_snapshot()
	var test_tube: FacilitySnapshot = snapshot.layout.get_facility(1)
	_expect_true(test_tube != null, "initial test tube is in the layout")
	if test_tube == null:
		return
	_expect_int(test_tube.ports.size(), 1, "test tube exposes one interface")
	if test_tube.ports.is_empty():
		return
	_expect_vector2i(
		test_tube.ports[0].global_cell,
		Vector2i(3, 3),
		"snapshot interface contains the rotated global cell"
	)
	_expect_int(
		test_tube.ports[0].direction,
		FacilityPortData.Direction.EAST,
		"snapshot interface contains the rotated direction"
	)
	_expect_true(
		test_tube.ports[0].connection_kind == &"habitat",
		"snapshot interface keeps its stable connection kind"
	)
	var projection: HabitatSpatialProjection = HabitatSpatialProjection.new()
	_expect_true(
		projection.configure(
			snapshot.layout.grid_size,
			Rect2(0.0, 0.0, 1200.0, 800.0),
			0.0
		),
		"Act 1 grid projects at an exact 100-pixel cell fixture"
	)
	_expect_vector(
		projection.port_position(test_tube.ports[0]),
		Vector2(400.0, 350.0),
		"initial test tube interface resolves to its exact world edge"
	)
	test_tube.ports[0].global_cell = Vector2i(9, 7)
	test_tube.ports[0].direction = FacilityPortData.Direction.WEST
	var fresh: GameSnapshot = simulation.create_game_snapshot()
	var fresh_test_tube: FacilitySnapshot = fresh.layout.get_facility(1)
	_expect_vector2i(
		fresh_test_tube.ports[0].global_cell,
		Vector2i(3, 3),
		"mutating interface snapshot geometry cannot move authority"
	)
	_expect_int(
		fresh_test_tube.ports[0].direction,
		FacilityPortData.Direction.EAST,
		"mutating interface snapshot direction cannot change authority"
	)


func _test_dual_chamber_zone_anchors_follow_orientation() -> void:
	var projection: HabitatSpatialProjection = HabitatSpatialProjection.new()
	_expect_true(
		projection.configure(
			Vector2i(4, 2),
			Rect2(0.0, 0.0, 400.0, 200.0),
			0.0
		),
		"dual-chamber fixture projection configures"
	)
	var layout: HabitatLayoutSnapshot = HabitatLayoutSnapshot.new()
	layout.active = true
	layout.grid_size = Vector2i(4, 2)
	var dual: FacilitySnapshot = _facility(
		10,
		Vector2i(1, 0),
		Vector2i(2, 2),
		FacilityData.PlacementLayer.BASE,
		&"brood_room"
	)
	dual.secondary_zone_id = &"utility_room"
	layout.facilities.append(dual)
	var expected_primary: Array[Vector2] = [
		Vector2(150.0, 100.0),
		Vector2(200.0, 50.0),
		Vector2(250.0, 100.0),
		Vector2(200.0, 150.0),
	]
	var expected_secondary: Array[Vector2] = [
		Vector2(250.0, 100.0),
		Vector2(200.0, 150.0),
		Vector2(150.0, 100.0),
		Vector2(200.0, 50.0),
	]
	for orientation: int in 4:
		dual.orientation = orientation
		_expect_vector(
			projection.find_zone_anchor(
				layout,
				&"brood_room"
			) as Vector2,
			expected_primary[orientation],
			"primary chamber anchor follows orientation %d" % orientation
		)
		_expect_vector(
			projection.find_zone_anchor(
				layout,
				&"utility_room"
			) as Vector2,
			expected_secondary[orientation],
			"secondary chamber anchor follows orientation %d" % orientation
		)
	var connection: HabitatConnectionSnapshot = (
		HabitatConnectionSnapshot.new(
			1,
			&"brood_room",
			&"utility_room",
			false,
			true,
			10
		)
	)
	dual.orientation = 0
	var endpoints: PackedVector2Array = projection.connection_endpoints(
		layout,
		connection
	)
	_expect_int(endpoints.size(), 2, "internal connection has two anchors")
	_expect_vector(
		endpoints[0],
		Vector2(150.0, 100.0),
		"connection starts at the primary chamber"
	)
	_expect_vector(
		endpoints[1],
		Vector2(250.0, 100.0),
		"connection ends at the secondary chamber"
	)


func _test_logical_passage_uses_connected_facility_anchors() -> void:
	var projection: HabitatSpatialProjection = HabitatSpatialProjection.new()
	_expect_true(
		projection.configure(
			Vector2i(6, 2),
			Rect2(0.0, 0.0, 600.0, 200.0),
			0.0
		),
		"logical-passage fixture projection configures"
	)
	var layout: HabitatLayoutSnapshot = HabitatLayoutSnapshot.new()
	layout.active = true
	layout.grid_size = Vector2i(6, 2)
	var nest: FacilitySnapshot = _facility(
		1,
		Vector2i(1, 0),
		Vector2i(2, 1),
		FacilityData.PlacementLayer.BASE,
		&"nest"
	)
	var feeding_port: FacilitySnapshot = _facility(
		2,
		Vector2i(4, 0),
		Vector2i.ONE,
		FacilityData.PlacementLayer.BASE,
		&"feeding_port"
	)
	layout.facilities.assign([nest, feeding_port])
	var zones: Array[HabitatZoneSnapshot] = [
		HabitatZoneSnapshot.new(
			&"nest",
			0.5,
			[&"passage"],
			true
		),
		HabitatZoneSnapshot.new(
			&"passage",
			0.5,
			[&"feeding_port", &"nest"],
			true
		),
		HabitatZoneSnapshot.new(
			&"feeding_port",
			0.5,
			[&"passage"],
			true
		),
	]
	_expect_vector(
		projection.find_logical_zone_anchor(
			layout,
			zones,
			&"passage"
		) as Vector2,
		Vector2(325.0, 50.0),
		"unrepresented passage projects to its connected facilities"
	)
	var anchor_index: Dictionary[StringName, Vector2] = (
		projection.build_logical_zone_anchor_index(layout, zones)
	)
	_expect_true(
		anchor_index.has(&"passage"),
		"bulk anchor index includes unrepresented logical passages"
	)
	if anchor_index.has(&"passage"):
		_expect_vector(
			anchor_index[&"passage"],
			Vector2(325.0, 50.0),
			"bulk anchor index matches direct passage projection"
		)
	zones[1].connected_zone_ids.reverse()
	layout.facilities.reverse()
	zones.reverse()
	anchor_index = projection.build_logical_zone_anchor_index(
		layout,
		zones
	)
	_expect_vector(
		projection.find_logical_zone_anchor(
			layout,
			zones,
			&"passage"
		) as Vector2,
		Vector2(325.0, 50.0),
		"passage projection ignores topology array order"
	)
	_expect_true(
		anchor_index.has(&"passage"),
		"reordered bulk anchor index keeps the passage"
	)
	if anchor_index.has(&"passage"):
		_expect_vector(
			anchor_index[&"passage"],
			Vector2(325.0, 50.0),
			"bulk anchor index ignores facility and topology order"
		)
	_expect_true(
		projection.find_logical_zone_anchor(
			layout,
			zones,
			&"missing_zone"
		) == null,
		"unknown logical zones do not receive fabricated coordinates"
	)


func _test_connection_and_hit_results_ignore_array_order() -> void:
	var projection: HabitatSpatialProjection = HabitatSpatialProjection.new()
	_expect_true(
		projection.configure(
			Vector2i(4, 2),
			Rect2(0.0, 0.0, 400.0, 200.0),
			0.0
		),
		"stable-order fixture projection configures"
	)
	var layout: HabitatLayoutSnapshot = HabitatLayoutSnapshot.new()
	layout.active = true
	layout.grid_size = Vector2i(4, 2)
	var overlay: FacilitySnapshot = _facility(
		9,
		Vector2i.ZERO,
		Vector2i.ONE,
		FacilityData.PlacementLayer.OVERLAY,
		&"shared_zone"
	)
	var higher_overlay: FacilitySnapshot = _facility(
		12,
		Vector2i.ZERO,
		Vector2i.ONE,
		FacilityData.PlacementLayer.OVERLAY,
		&""
	)
	var base: FacilitySnapshot = _facility(
		5,
		Vector2i(2, 0),
		Vector2i.ONE,
		FacilityData.PlacementLayer.BASE,
		&"shared_zone"
	)
	layout.facilities.assign([overlay, base, higher_overlay])
	_expect_vector(
		projection.find_zone_anchor(
			layout,
			&"shared_zone"
		) as Vector2,
		Vector2(250.0, 50.0),
		"zone anchor prefers the base facility over array order"
	)
	_expect_int(
		projection.find_top_facility_at(
			layout,
			Vector2(50.0, 50.0)
		),
		12,
		"topmost hit uses layer then stable facility ID"
	)
	layout.facilities.reverse()
	_expect_vector(
		projection.find_zone_anchor(
			layout,
			&"shared_zone"
		) as Vector2,
		Vector2(250.0, 50.0),
		"reversing snapshot array does not move a zone anchor"
	)
	_expect_int(
		projection.find_top_facility_at(
			layout,
			Vector2(50.0, 50.0)
		),
		12,
		"reversing snapshot array does not change hit ownership"
	)


func _facility(
	facility_id: int,
	slot: Vector2i,
	footprint: Vector2i,
	placement_layer: FacilityData.PlacementLayer,
	zone_id: StringName
) -> FacilitySnapshot:
	return FacilitySnapshot.new(
		facility_id,
		&"projection_fixture",
		slot,
		0,
		footprint,
		placement_layer,
		zone_id,
		true,
		true
	)


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


func _expect_float(
	actual: float,
	expected: float,
	message: String
) -> void:
	_assertion_count += 1
	if is_equal_approx(actual, expected):
		return
	_record_failure(message, str(expected), str(actual))


func _expect_vector(
	actual: Vector2,
	expected: Vector2,
	message: String
) -> void:
	_assertion_count += 1
	if actual.is_equal_approx(expected):
		return
	_record_failure(message, str(expected), str(actual))


func _expect_vector2i(
	actual: Vector2i,
	expected: Vector2i,
	message: String
) -> void:
	_assertion_count += 1
	if actual == expected:
		return
	_record_failure(message, str(expected), str(actual))


func _expect_rect(
	actual: Rect2,
	expected: Rect2,
	message: String
) -> void:
	_assertion_count += 1
	if (
		actual.position.is_equal_approx(expected.position)
		and actual.size.is_equal_approx(expected.size)
	):
		return
	_record_failure(message, str(expected), str(actual))


func _record_failure(
	message: String,
	expected: String,
	actual: String
) -> void:
	_failure_count += 1
	printerr("  %s - expected %s, got %s" % [message, expected, actual])
