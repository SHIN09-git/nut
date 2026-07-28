class_name FacilityLayoutTestSuite
extends RefCounted

const SPECIES_A_DATA: SpeciesData = preload(
	"res://data/species/species_a.tres"
)
const ACT1_SCENARIO_DATA: HabitatScenarioData = preload(
	"res://data/habitats/act1_test_tube.tres"
)
const BOX_TYPE_ID: StringName = &"small_foraging_box"
const GATE_TYPE_ID: StringName = &"connector_gate"

var _assertion_count: int = 0
var _failure_count: int = 0


func run() -> int:
	_test_initial_layout_preserves_authored_reachability()
	_test_overlap_bounds_interfaces_and_orientation_are_validated()
	_test_light_cover_uses_layout_authority()
	_test_place_rotate_and_remove_commands_use_next_tick_boundary()
	_test_gate_command_invalidates_cached_reachability()
	_test_layout_snapshot_isolated_from_authority()
	_test_r6_save_migrates_to_r7_layout_authority()
	return _failure_count


func get_assertion_count() -> int:
	return _assertion_count


func get_failure_count() -> int:
	return _failure_count


func _test_initial_layout_preserves_authored_reachability() -> void:
	var simulation: ColonySimulation = _new_layout_simulation()
	_expect_true(simulation.is_ready(), "R7 Act 1 layout fixture initializes")
	if not simulation.is_ready():
		return
	var snapshot: GameSnapshot = simulation.create_game_snapshot()
	_expect_true(
		snapshot.layout != null and snapshot.layout.active,
		"Act 1 publishes an active layout snapshot"
	)
	_expect_int(
		snapshot.layout.facilities.size(),
		2,
		"frozen layout starts with the tube and feeding port"
	)
	for zone: HabitatZoneData in ACT1_SCENARIO_DATA.zones:
		var expected: Array[StringName] = []
		expected.assign(zone.connected_zone_ids)
		expected.sort_custom(_sort_names)
		var actual: Array[StringName] = (
			simulation._state.get_connected_zone_ids(zone.zone_id)
		)
		_expect_names(
			actual,
			expected,
			"layout graph preserves authored neighbors for %s"
				% String(zone.zone_id)
		)
		var runtime_zone: HabitatZoneState = simulation._state.get_zone(
			zone.zone_id
		)
		_expect_true(
			runtime_zone.connected_zone_ids.is_empty(),
			"runtime environment zone no longer owns adjacency"
		)


func _test_overlap_bounds_interfaces_and_orientation_are_validated() -> void:
	var simulation: ColonySimulation = _new_layout_simulation()
	var layout: HabitatLayoutState = simulation._state.layout_state
	var catalog: FacilityCatalogConfig = (
		simulation._habitat_config.facility_catalog_config
	)
	var unlocked: Dictionary[StringName, bool] = (
		simulation._state.campaign_state.unlocked_facility_type_ids
	)
	_expect_true(
		not layout.can_place(catalog, BOX_TYPE_ID, Vector2i(1, 3), 0, unlocked),
		"overlap with the test tube is rejected"
	)
	_expect_true(
		not layout.can_place(catalog, BOX_TYPE_ID, Vector2i(11, 7), 0, unlocked),
		"footprints outside the logical grid are rejected"
	)
	_expect_true(
		not layout.can_place(catalog, BOX_TYPE_ID, Vector2i(8, 6), 0, unlocked),
		"a disconnected facility is rejected"
	)
	_expect_true(
		layout.can_place(catalog, BOX_TYPE_ID, Vector2i(5, 3), 0, unlocked),
		"matching opposite-facing interfaces permit placement"
	)
	_expect_true(
		not layout.can_place(catalog, BOX_TYPE_ID, Vector2i(5, 3), 1, unlocked),
		"a mismatched interface orientation is rejected"
	)


func _test_place_rotate_and_remove_commands_use_next_tick_boundary() -> void:
	var simulation: ColonySimulation = _new_layout_simulation()
	var before: GameSnapshot = simulation.create_game_snapshot()
	var gate_option: FacilityPlacementOptionSnapshot = (
		_find_option(before.layout, GATE_TYPE_ID, Vector2i(5, 3), 0)
	)
	_expect_true(gate_option != null, "connector gate has a valid interface slot")
	if gate_option == null:
		return
	_expect_true(
		simulation.submit_place_facility_action(
			gate_option.type_id,
			gate_option.slot,
			gate_option.orientation
		),
		"high-level place command is accepted"
	)
	var submitted: GameSnapshot = simulation.create_game_snapshot()
	_expect_true(
		submitted.layout.action_pending,
		"same-Tick snapshot exposes pending layout work"
	)
	_expect_int(
		submitted.layout.facilities.size(),
		before.layout.facilities.size(),
		"submission does not mutate layout in the same Tick"
	)
	_expect_true(
		not simulation.submit_place_facility_action(
			GATE_TYPE_ID,
			Vector2i(5, 3),
			0
		),
		"only one layout command may be pending"
	)
	_expect_true(simulation.advance_tick(1), "placement Tick advances")
	var placed: GameSnapshot = simulation.create_game_snapshot()
	_expect_int(
		placed.layout.facilities.size(),
		before.layout.facilities.size() + 1,
		"next Tick creates exactly one facility"
	)
	var gate: FacilitySnapshot = placed.layout.get_facility(3)
	_expect_true(gate != null, "placed facility receives the next stable ID")
	if gate == null:
		return
	_expect_int(gate.orientation, 0, "placed facility keeps submitted orientation")
	_expect_true(
		simulation.submit_rotate_facility_action(gate.facility_id, 2),
		"rotate command accepts a still-connected orientation"
	)
	_expect_int(
		simulation.create_game_snapshot().layout.get_facility(3).orientation,
		0,
		"rotation waits for the next Tick"
	)
	_expect_true(simulation.advance_tick(2), "rotation Tick advances")
	var rotated: FacilitySnapshot = (
		simulation.create_game_snapshot().layout.get_facility(3)
	)
	_expect_int(rotated.facility_id, 3, "rotation preserves stable facility ID")
	_expect_int(rotated.orientation, 2, "rotation applies on the next Tick")
	_expect_true(
		simulation.submit_remove_facility_action(rotated.facility_id),
		"removal command accepts an unreferenced removable facility"
	)
	_expect_true(
		simulation.create_game_snapshot().layout.get_facility(3) != null,
		"removal also waits for the next Tick"
	)
	_expect_true(simulation.advance_tick(3), "removal Tick advances")
	var removed: GameSnapshot = simulation.create_game_snapshot()
	_expect_true(
		removed.layout.get_facility(3) == null,
		"facility is absent after authoritative removal"
	)
	_expect_int(
		removed.layout.get_supply(GATE_TYPE_ID).remaining_count,
		2,
		"atomic removal restores the consumed supply"
	)


func _test_light_cover_uses_layout_authority() -> void:
	var simulation: ColonySimulation = _new_layout_simulation()
	_expect_true(
		not simulation.submit_place_facility_action(
			CampaignState.FACILITY_LIGHT_COVER,
			ColonySimulation.ACT1_LIGHT_COVER_SLOT,
			0
		),
		"generic placement cannot bypass the light-cover action"
	)
	_expect_true(
		simulation.submit_apply_light_cover_action(),
		"high-level light-cover action is accepted"
	)
	_expect_int(
		simulation.create_game_snapshot().layout.facilities.size(),
		2,
		"cover action does not place a facility in the submission Tick"
	)
	_expect_true(simulation.advance_tick(1), "light-cover Tick advances")
	var snapshot: GameSnapshot = simulation.create_game_snapshot()
	var cover: FacilitySnapshot = snapshot.layout.get_facility(3)
	_expect_true(
		cover != null
			and cover.type_id == CampaignState.FACILITY_LIGHT_COVER,
		"light-cover behavior and layout share one stable facility"
	)
	_expect_int(
		snapshot.layout.get_supply(
			CampaignState.FACILITY_LIGHT_COVER
		).remaining_count,
		0,
		"installed cover consumes the frozen layout supply"
	)
	_expect_true(
		snapshot.act1.queen_care.light_cover_applied,
		"the same Tick activates founding-care behavior"
	)


func _test_gate_command_invalidates_cached_reachability() -> void:
	var simulation: ColonySimulation = _new_layout_simulation()
	var layout: HabitatLayoutState = simulation._state.layout_state
	var connection: HabitatConnectionState = layout.get_connection(1)
	_expect_true(connection != null, "initial graph exposes a stable connection")
	if connection == null:
		return
	connection.gated = true
	layout._mark_changed()
	var first_zone: StringName = connection.first_zone_id
	var second_zone: StringName = connection.second_zone_id
	_expect_true(
		simulation._state.are_zones_directly_connected(
			first_zone,
			second_zone
		),
		"open gate appears in cached reachability"
	)
	_expect_true(
		simulation.submit_set_gate_open_action(
			connection.connection_id,
			false
		),
		"gate-close command is accepted while workers are inactive"
	)
	_expect_true(
		simulation._state.are_zones_directly_connected(
			first_zone,
			second_zone
		),
		"gate remains open during its submission Tick"
	)
	_expect_true(simulation.advance_tick(1), "gate-close Tick advances")
	_expect_true(
		not simulation._state.are_zones_directly_connected(
			first_zone,
			second_zone
		),
		"closed gate invalidates and rebuilds adjacency"
	)
	_expect_true(
		simulation.submit_set_gate_open_action(
			connection.connection_id,
			true
		),
		"gate-open command is accepted"
	)
	_expect_true(simulation.advance_tick(2), "gate-open Tick advances")
	_expect_true(
		simulation._state.are_zones_directly_connected(
			first_zone,
			second_zone
		),
		"reopened gate restores reachability"
	)


func _test_layout_snapshot_isolated_from_authority() -> void:
	var simulation: ColonySimulation = _new_layout_simulation()
	var snapshot: GameSnapshot = simulation.create_game_snapshot()
	snapshot.layout.facilities[0].slot = Vector2i(9, 7)
	snapshot.layout.supplies[0].remaining_count = 999
	snapshot.layout.connections[0].open = false
	var fresh: GameSnapshot = simulation.create_game_snapshot()
	_expect_true(
		fresh.layout.facilities[0].slot != Vector2i(9, 7),
		"mutating a facility snapshot cannot move authority"
	)
	_expect_true(
		fresh.layout.supplies[0].remaining_count != 999,
		"mutating supply snapshot cannot change authority"
	)
	_expect_true(
		fresh.layout.connections[0].open,
		"mutating connection snapshot cannot close authority"
	)


func _test_r6_save_migrates_to_r7_layout_authority() -> void:
	var simulation: ColonySimulation = _new_layout_simulation()
	_expect_true(
		simulation.submit_apply_light_cover_action(),
		"R6 migration fixture submits its historical cover action"
	)
	_expect_true(
		simulation.advance_tick(1),
		"R6 migration fixture applies its historical cover action"
	)
	var clock: SimulationClock = SimulationClock.new()
	clock.restore_save_boundary(
		1,
		SimulationClock.NORMAL_SPEED,
		false
	)
	var service: SaveGameService = SaveGameService.new()
	var previous: Dictionary = service.create_envelope(
		simulation,
		clock,
		"r6-layout-migration",
		"2026-07-28T00:00:00Z"
	)
	previous["state_schema_id"] = SimulationStateCodec.R6_SCHEMA_ID
	previous["game_version"] = "0.6.0-dev"
	previous["frozen_config_bundle"]["habitat"].erase(
		"facility_catalog_config"
	)
	previous["state_payload"].erase("layout")
	_restore_r6_zone_connections(previous)
	previous["next_ids"].erase("facility_id")
	previous["next_ids"].erase("connection_id")
	for command: Dictionary in previous["pending_commands"]:
		command.erase("argument_entity_id")
		command.erase("argument_slot")
		command.erase("argument_orientation")
		command.erase("argument_flag")
	previous["frozen_config_hash"] = CanonicalSaveJson.sha256(
		previous["frozen_config_bundle"]
	)
	previous = service.seal_envelope(previous)
	var result: Dictionary = service.load_envelope(previous)
	_expect_true(
		result.get("ok", false),
		"R6 save migrates through the explicit R7 layout step"
	)
	if not result.get("ok", false):
		return
	_expect_true(result["migrated"], "R6 migration is reported")
	var migrated: GameSnapshot = (
		(result["simulation"] as ColonySimulation).create_game_snapshot()
	)
	_expect_true(
		migrated.layout != null and migrated.layout.active,
		"migration creates active layout authority"
	)
	_expect_int(
		migrated.layout.facilities.size(),
		3,
		"migration recreates initial facilities and the installed cover"
	)
	_expect_int(
		migrated.layout.get_supply(
			CampaignState.FACILITY_LIGHT_COVER
		).remaining_count,
		0,
		"migration consumes cover supply when R6 behavior was active"
	)
	_expect_int(
		migrated.layout.connections.size(),
		2,
		"migration converts the old adjacency graph into stable edges"
	)
	_expect_string(
		result["envelope"]["state_schema_id"],
		SimulationStateCodec.CURRENT_SCHEMA_ID,
		"migration seals the current R7 schema"
	)


func _new_layout_simulation() -> ColonySimulation:
	var scenario: HabitatScenarioData = (
		ACT1_SCENARIO_DATA.duplicate(true) as HabitatScenarioData
	)
	var catalog: FacilityCatalogData = (
		ACT1_SCENARIO_DATA.facility_catalog_data.duplicate(true)
		as FacilityCatalogData
	)
	scenario.facility_catalog_data = catalog
	for facility_type: FacilityData in catalog.facility_types:
		if facility_type.type_id in [BOX_TYPE_ID, GATE_TYPE_ID]:
			facility_type.unlock_type_id = CampaignState.FACILITY_MAGNIFIER
	return ColonySimulation.new(SPECIES_A_DATA, scenario)


func _find_option(
	layout: HabitatLayoutSnapshot,
	type_id: StringName,
	slot: Vector2i,
	orientation: int
) -> FacilityPlacementOptionSnapshot:
	for option: FacilityPlacementOptionSnapshot in layout.placement_options:
		if (
			option.type_id == type_id
			and option.slot == slot
			and option.orientation == orientation
		):
			return option
	return null


func _restore_r6_zone_connections(envelope: Dictionary) -> void:
	var config_by_zone: Dictionary[String, Array] = {}
	for zone: Dictionary in envelope["frozen_config_bundle"]["habitat"]["zones"]:
		config_by_zone[String(zone["zone_id"])] = (
			zone["connected_zone_ids"] as Array
		).duplicate()
	for zone: Dictionary in envelope["state_payload"]["zones"]:
		zone["connected_zone_ids"] = config_by_zone.get(
			String(zone["zone_id"]),
			[]
		)


func _sort_names(first: StringName, second: StringName) -> bool:
	return String(first) < String(second)


func _expect_names(
	actual: Array[StringName],
	expected: Array[StringName],
	message: String
) -> void:
	_assertion_count += 1
	if actual == expected:
		return
	_record_failure(message, str(expected), str(actual))


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


func _expect_string(actual: String, expected: String, message: String) -> void:
	_assertion_count += 1
	if actual == expected:
		return
	_record_failure(message, expected, actual)


func _record_failure(
	message: String,
	expected: String,
	actual: String
) -> void:
	_failure_count += 1
	printerr("  %s - expected %s, got %s" % [message, expected, actual])
