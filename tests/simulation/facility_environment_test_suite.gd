class_name FacilityEnvironmentTestSuite
extends RefCounted

const SPECIES_A_DATA: SpeciesData = preload(
	"res://data/species/species_a.tres"
)
const ACT1_SCENARIO_DATA: HabitatScenarioData = preload(
	"res://data/habitats/act1_test_tube.tres"
)
const BOX_TYPE_ID: StringName = &"small_foraging_box"
const GATE_TYPE_ID: StringName = &"connector_gate"
const HYDRATION_TYPE_ID: StringName = &"hydration_module"
const WASTE_TYPE_ID: StringName = &"waste_tray"
const SUGAR_STATION_TYPE_ID: StringName = &"sugar_station"
const PROTEIN_DISH_TYPE_ID: StringName = &"protein_dish"

var _assertion_count: int = 0
var _failure_count: int = 0


func run() -> void:
	_test_frozen_typed_effects_and_dynamic_zone()
	_test_connector_gate_derives_stable_reachability()
	_test_hydration_light_pollution_and_waste_effects()
	_test_food_stations_route_resource_entry()
	_test_pollution_changes_brood_relocation_choice()
	_test_environment_snapshot_isolation_and_determinism()
	_test_r7_save_migrates_environment_defaults()
	_test_environment_soak_remains_finite()


func get_assertion_count() -> int:
	return _assertion_count


func get_failure_count() -> int:
	return _failure_count


func _test_frozen_typed_effects_and_dynamic_zone() -> void:
	var scenario: HabitatScenarioData = _scenario_with_test_unlocks()
	var simulation: ColonySimulation = ColonySimulation.new(
		SPECIES_A_DATA,
		scenario
	)
	_expect_true(simulation.is_ready(), "R8 typed facility fixture initializes")
	if not simulation.is_ready():
		return
	var frozen_box: FacilityConfig = (
		simulation._habitat_config.facility_catalog_config.get_type(
			BOX_TYPE_ID
		)
	)
	_expect_int(
		frozen_box.effect_config.kind,
		FacilityEffectConfig.Kind.HABITAT_ZONE,
		"foraging box freezes one habitat-zone effect"
	)
	var food_catalog: FacilityCatalogConfig = (
		simulation._habitat_config.facility_catalog_config
	)
	_expect_true(
		food_catalog.get_type(SUGAR_STATION_TYPE_ID)
			.effect_config.accepts_sugar,
		"sugar station freezes sugar acceptance"
	)
	_expect_true(
		food_catalog.get_type(PROTEIN_DISH_TYPE_ID)
			.effect_config.accepts_protein,
		"protein dish freezes protein acceptance"
	)

	var source_box: FacilityData = _find_source_type(
		scenario,
		BOX_TYPE_ID
	)
	var source_effect: HabitatZoneFacilityEffectData = (
		source_box.effect_data as HabitatZoneFacilityEffectData
	)
	source_effect.initial_humidity = 0.99
	scenario.environment_data.brood_pollution_comfort_max = 0.99
	var before: GameSnapshot = simulation.create_game_snapshot()
	_expect_true(
		simulation.submit_place_facility_action(
			BOX_TYPE_ID,
			Vector2i(5, 3),
			0
		),
		"box placement enters the next-Tick command queue"
	)
	_expect_int(
		simulation.create_game_snapshot().colony.zones.size(),
		before.colony.zones.size(),
		"submitting a box does not create its zone immediately"
	)
	_expect_true(simulation.advance_tick(1), "box placement Tick advances")
	var snapshot: GameSnapshot = simulation.create_game_snapshot()
	var box: FacilitySnapshot = snapshot.layout.get_facility(3)
	_expect_true(box != null, "placed box receives stable facility ID 3")
	if box == null:
		return
	_expect_string(
		String(box.zone_id),
		"small_foraging_box_003",
		"placed habitat facility receives a stable derived zone ID"
	)
	var box_zone: HabitatZoneSnapshot = snapshot.colony.find_zone(
		box.zone_id
	)
	_expect_true(box_zone != null, "box zone is published in the snapshot")
	if box_zone != null:
		_expect_true(
			box_zone.humidity < 0.50,
			"source Resource mutation cannot change frozen box humidity"
		)
	_expect_true(
		simulation._state.are_zones_directly_connected(
			&"micro_feeding_port",
			box.zone_id
		),
		"matching physical ports derive a logical zone connection"
	)


func _test_connector_gate_derives_stable_reachability() -> void:
	var simulation: ColonySimulation = _new_simulation()
	_expect_true(
		simulation.submit_place_facility_action(
			GATE_TYPE_ID,
			Vector2i(5, 3),
			0
		),
		"connector gate placement is accepted"
	)
	_expect_true(simulation.advance_tick(1), "gate placement Tick advances")
	_expect_true(
		simulation.submit_place_facility_action(
			BOX_TYPE_ID,
			Vector2i(6, 3),
			0
		),
		"box can attach through the placed gate"
	)
	_expect_true(simulation.advance_tick(2), "gated box Tick advances")
	var snapshot: GameSnapshot = simulation.create_game_snapshot()
	var box: FacilitySnapshot = snapshot.layout.get_facility(4)
	var derived: HabitatConnectionSnapshot
	for connection: HabitatConnectionSnapshot in snapshot.layout.connections:
		if (
			box != null
			and (
				connection.first_zone_id == box.zone_id
				or connection.second_zone_id == box.zone_id
			)
		):
			derived = connection
			break
	_expect_true(
		derived != null and derived.gated,
		"gate path produces one gated derived connection"
	)
	if derived == null:
		return
	_expect_int(
		derived.owner_facility_id,
		3,
		"derived connection is owned by the stable gate facility"
	)
	var connection_id: int = derived.connection_id
	_expect_true(
		simulation.submit_set_gate_open_action(connection_id, false),
		"gate close queues while no worker task is active"
	)
	_expect_true(
		simulation._state.are_zones_directly_connected(
			&"micro_feeding_port",
			box.zone_id
		),
		"queued close does not alter reachability in the same Tick"
	)
	_expect_true(simulation.advance_tick(3), "gate-close Tick advances")
	_expect_true(
		not simulation._state.are_zones_directly_connected(
			&"micro_feeding_port",
			box.zone_id
		),
		"closed derived gate removes reachability"
	)
	_expect_true(
		simulation.submit_set_gate_open_action(connection_id, true),
		"derived gate can be reopened"
	)
	_expect_true(simulation.advance_tick(4), "gate-open Tick advances")
	_expect_true(
		simulation._state.are_zones_directly_connected(
			&"micro_feeding_port",
			box.zone_id
		),
		"reopened derived gate restores reachability"
	)


func _test_hydration_light_pollution_and_waste_effects() -> void:
	var scenario: HabitatScenarioData = _scenario_with_test_unlocks()
	var simulation: ColonySimulation = ColonySimulation.new(
		SPECIES_A_DATA,
		scenario
	)
	var source_hydration: HydrationFacilityEffectData = (
		_find_source_type(scenario, HYDRATION_TYPE_ID).effect_data
		as HydrationFacilityEffectData
	)
	source_hydration.target_humidity = 0.05
	source_hydration.humidity_per_tick = 0.05
	var initial_light: float = (
		simulation.create_snapshot()
			.find_zone(&"test_tube_nest").light_exposure
	)
	_expect_true(
		simulation.submit_apply_light_cover_action(),
		"light cover high-level command is accepted"
	)
	_expect_true(simulation.advance_tick(1), "light-cover Tick advances")
	var covered_light: float = (
		simulation.create_snapshot()
			.find_zone(&"test_tube_nest").light_exposure
	)
	_expect_true(
		covered_light < initial_light,
		"installed cover deterministically reduces light exposure"
	)
	_expect_true(
		simulation.submit_place_facility_action(
			BOX_TYPE_ID,
			Vector2i(5, 3),
			0
		),
		"environment box placement is accepted"
	)
	_expect_true(simulation.advance_tick(2), "environment box Tick advances")
	var box_zone_id: StringName = (
		simulation.create_game_snapshot().layout.get_facility(4).zone_id
	)
	var humidity_before: float = (
		simulation.create_snapshot().find_zone(box_zone_id).humidity
	)
	_expect_true(
		simulation.submit_place_facility_action(
			HYDRATION_TYPE_ID,
			Vector2i(5, 3),
			0
		),
		"hydration module attaches to the box zone"
	)
	_expect_true(simulation.advance_tick(3), "hydration placement Tick advances")
	var hydrated: HabitatZoneSnapshot = (
		simulation.create_snapshot().find_zone(box_zone_id)
	)
	_expect_true(
		hydrated.humidity > humidity_before,
		"hydration moves frozen humidity %.4f -> %.4f"
			% [humidity_before, hydrated.humidity]
	)
	_expect_true(
		hydrated.humidity < 0.60,
		"source mutation leaves frozen hydration below 0.60 (%.4f)"
			% hydrated.humidity
	)

	var authoritative_zone: HabitatZoneState = simulation._state.get_zone(
		box_zone_id
	)
	authoritative_zone.set_pollution(0.50)
	_expect_true(
		simulation.submit_place_facility_action(
			WASTE_TYPE_ID,
			Vector2i(6, 3),
			0
		),
		"waste tray attaches to the box zone"
	)
	_expect_true(simulation.advance_tick(4), "waste-tray Tick advances")
	var waste: FacilitySnapshot = (
		simulation.create_game_snapshot().layout.get_facility(6)
	)
	_expect_true(
		waste != null and waste.waste_fill_ratio > 0.0,
		"waste tray visibly accumulates captured pollution"
	)
	_expect_true(
		simulation.create_snapshot().find_zone(box_zone_id).pollution < 0.50,
		"waste capture reduces host-zone pollution"
	)

	var diffusion_simulation: ColonySimulation = _new_simulation()
	_expect_true(
		diffusion_simulation.submit_place_facility_action(
			BOX_TYPE_ID,
			Vector2i(5, 3),
			0
		),
		"diffusion box placement is accepted"
	)
	_expect_true(
		diffusion_simulation.advance_tick(1),
		"diffusion box Tick advances"
	)
	var diffusion_box: FacilitySnapshot = (
		diffusion_simulation.create_game_snapshot().layout.get_facility(3)
	)
	var source_zone: HabitatZoneState = (
		diffusion_simulation._state.get_zone(diffusion_box.zone_id)
	)
	var target_zone: HabitatZoneState = (
		diffusion_simulation._state.get_zone(&"micro_feeding_port")
	)
	source_zone.set_pollution(0.8)
	target_zone.set_pollution(0.0)
	_expect_true(
		diffusion_simulation.advance_tick(2),
		"pollution diffusion Tick advances"
	)
	_expect_true(
		target_zone.pollution > 0.0 and source_zone.pollution < 0.8,
		"pollution diffuses deterministically across open connections"
	)


func _test_pollution_changes_brood_relocation_choice() -> void:
	var environment_config: EnvironmentConfig = EnvironmentConfig.from_data(
		ACT1_SCENARIO_DATA.environment_data
	)
	var catalog: FacilityCatalogConfig = FacilityCatalogConfig.from_data(
		ACT1_SCENARIO_DATA.facility_catalog_data
	)
	var environment_system: EnvironmentSystem = EnvironmentSystem.new(
		environment_config,
		catalog
	)
	var relocation: BroodRelocationSystem = BroodRelocationSystem.new(
		BroodCareConfig.from_species_data(SPECIES_A_DATA),
		environment_system
	)
	var state: ColonyState = ColonyState.new()
	state.simulation_tick = 1
	state.zones = [
		HabitatZoneState.new(&"dirty", 0.66, [], true, 0.2, 0.8),
		HabitatZoneState.new(&"clean", 0.66, [], true, 0.2, 0.0),
	]
	state.layout_state = HabitatLayoutState.create_initial(
		{
			&"dirty": [&"clean"],
			&"clean": [&"dirty"],
		},
		null
	)
	_expect_true(
		state.are_zones_directly_connected(&"dirty", &"clean"),
		"pollution relocation fixture has a valid logical connection"
	)
	_expect_true(
		environment_system.get_brood_pollution_penalty(0.8) > 0.0,
		"pollution relocation fixture has a nonzero dirty-zone penalty"
	)
	var worker: AntModel = AntModel.new(1, AntModel.LifeStage.WORKER)
	worker.configure_worker(&"dirty", 1)
	worker.worker_task.next_decision_tick = 0
	var brood: AntModel = AntModel.new(2, AntModel.LifeStage.LARVA)
	brood.configure_brood(
		&"dirty",
		-SPECIES_A_DATA.minimum_zone_dwell_ticks
	)
	state.ants = [worker, brood]
	relocation.assign_idle_workers(state)
	_expect_int(
		worker.worker_task.target_brood_id,
		brood.entity_id,
		"pollution difference can trigger autonomous brood relocation"
	)
	_expect_string(
		String(worker.worker_task.target_zone_id),
		"clean",
		"worker chooses the cleaner equally humid zone"
	)


func _test_food_stations_route_resource_entry() -> void:
	var simulation: ColonySimulation = _new_simulation()
	_expect_true(
		simulation.submit_place_facility_action(
			BOX_TYPE_ID,
			Vector2i(5, 3),
			0
		),
		"food-station fixture places its host box"
	)
	_expect_true(simulation.advance_tick(1), "food host Tick advances")
	var box: FacilitySnapshot = (
		simulation.create_game_snapshot().layout.get_facility(3)
	)
	_expect_true(
		simulation.submit_place_facility_action(
			SUGAR_STATION_TYPE_ID,
			Vector2i(5, 3),
			0
		),
		"sugar station attaches to a stable host zone"
	)
	_expect_true(simulation.advance_tick(2), "sugar-station Tick advances")
	_expect_true(
		simulation.submit_place_facility_action(
			PROTEIN_DISH_TYPE_ID,
			Vector2i(6, 3),
			0
		),
		"protein dish attaches to the same host zone"
	)
	_expect_true(simulation.advance_tick(3), "protein-dish Tick advances")
	simulation._state.layout_state.get_facility(2).available = false
	_expect_string(
		String(simulation._find_food_station_zone_id(
			FoodSourceState.FoodType.SUGAR_WATER,
			&"micro_feeding_port"
		)),
		String(box.zone_id),
		"sugar entry falls back to the stable sugar-station host"
	)
	_expect_string(
		String(simulation._find_food_station_zone_id(
			FoodSourceState.FoodType.PROTEIN,
			&"micro_feeding_port"
		)),
		String(box.zone_id),
		"protein entry falls back to the stable protein-dish host"
	)
	var source: FoodSourceState = (
		simulation._foraging_system.apply_sugar_placement(
			simulation._state,
			box.zone_id,
			1
		)
	)
	_expect_true(
		source != null and source.zone_id == box.zone_id,
		"facility-selected resource entry creates food in its host zone"
	)
	_expect_true(
		not simulation.submit_remove_facility_action(4),
		"active food source prevents removal of its sugar station"
	)


func _test_environment_snapshot_isolation_and_determinism() -> void:
	var first: ColonySimulation = _new_simulation()
	var second: ColonySimulation = _new_simulation()
	for simulation: ColonySimulation in [first, second]:
		_expect_true(
			simulation.submit_place_facility_action(
				BOX_TYPE_ID,
				Vector2i(5, 3),
				0
			),
			"determinism fixture queues the same box command"
		)
		_expect_true(
			simulation.advance_tick(1),
			"determinism fixture applies the same box command"
		)
		_expect_true(
			simulation.submit_place_facility_action(
				HYDRATION_TYPE_ID,
				Vector2i(5, 3),
				0
			),
			"determinism fixture queues the same hydration command"
		)
		for tick: int in range(2, 202):
			_expect_true(
				simulation.advance_tick(tick),
				"determinism fixture advances Tick %d" % tick
			)
	_expect_string(
		_environment_signature(first.create_game_snapshot()),
		_environment_signature(second.create_game_snapshot()),
		"same facility commands produce the same environment snapshot"
	)
	var mutable: GameSnapshot = first.create_game_snapshot()
	mutable.colony.zones[-1].humidity = 1.0
	mutable.colony.zones[-1].pollution = 1.0
	mutable.layout.facilities[-1].waste_fill_ratio = 1.0
	var fresh: GameSnapshot = first.create_game_snapshot()
	_expect_true(
		fresh.colony.zones[-1].humidity < 1.0,
		"mutating environment snapshot humidity cannot change authority"
	)
	_expect_true(
		fresh.colony.zones[-1].pollution < 1.0,
		"mutating environment snapshot pollution cannot change authority"
	)
	_expect_true(
		fresh.layout.facilities[-1].waste_fill_ratio < 1.0,
		"mutating facility effect snapshot cannot change authority"
	)


func _test_r7_save_migrates_environment_defaults() -> void:
	var simulation: ColonySimulation = _new_simulation()
	var service: SaveGameService = SaveGameService.new()
	var clock: SimulationClock = SimulationClock.new()
	var previous: Dictionary = service.create_envelope(
		simulation,
		clock,
		"r8-r7-migration",
		"2026-07-28T00:00:00Z"
	)
	previous["state_schema_id"] = SimulationStateCodec.R7_SCHEMA_ID
	previous["game_version"] = "0.7.0-dev"
	var habitat: Dictionary = previous["frozen_config_bundle"]["habitat"]
	habitat.erase("environment_config")
	for zone: Dictionary in habitat["zones"]:
		zone.erase("light_exposure")
		zone.erase("pollution")
	var r7_type_ids: Array[String] = [
		"connector_gate",
		"connector_tube",
		"light_cover",
		"micro_feeding_port",
		"small_foraging_box",
		"test_tube_nest",
	]
	var r7_types: Array[Dictionary] = []
	for facility_type: Dictionary in (
		habitat["facility_catalog_config"]["facility_types"]
	):
		if r7_type_ids.has(String(facility_type["type_id"])):
			facility_type.erase("effect_config")
			r7_types.append(facility_type)
	habitat["facility_catalog_config"]["facility_types"] = r7_types
	var r7_supplies: Array[Dictionary] = []
	for supply: Dictionary in (
		habitat["facility_catalog_config"]["initial_supplies"]
	):
		if r7_type_ids.has(String(supply["type_id"])):
			r7_supplies.append(supply)
	habitat["facility_catalog_config"]["initial_supplies"] = r7_supplies
	for zone: Dictionary in previous["state_payload"]["zones"]:
		zone.erase("light_exposure")
		zone.erase("pollution")
	for facility: Dictionary in previous["state_payload"]["layout"]["facilities"]:
		facility.erase("waste_stored")
	var r7_state_supplies: Array[Dictionary] = []
	for supply: Dictionary in previous["state_payload"]["layout"]["supplies"]:
		if r7_type_ids.has(String(supply["type_id"])):
			r7_state_supplies.append(supply)
	previous["state_payload"]["layout"]["supplies"] = r7_state_supplies
	previous["frozen_config_hash"] = CanonicalSaveJson.sha256(
		previous["frozen_config_bundle"]
	)
	previous = service.seal_envelope(previous)
	var result: Dictionary = service.load_envelope(previous)
	_expect_true(
		result.get("ok", false),
		"R7 save migrates environment defaults: %s"
			% result.get("error", "")
	)
	if not result.get("ok", false):
		return
	_expect_string(
		String(result["envelope"]["state_schema_id"]),
		SimulationStateCodec.CURRENT_SCHEMA_ID,
		"R7 migration produces the R8 schema"
	)
	var migrated_zone: HabitatZoneSnapshot = (
		result["simulation"].create_snapshot().find_zone(
			&"test_tube_nest"
		)
	)
	_expect_true(
		migrated_zone.light_exposure > 0.0
			and migrated_zone.pollution >= 0.0,
		"R7 migration installs finite environment defaults"
	)


func _test_environment_soak_remains_finite() -> void:
	var simulation: ColonySimulation = _new_simulation()
	_expect_true(
		simulation.submit_place_facility_action(
			BOX_TYPE_ID,
			Vector2i(5, 3),
			0
		),
		"soak fixture places its environment zone"
	)
	var accepted: bool = true
	for tick: int in range(1, 10_001):
		if not simulation.advance_tick(tick):
			accepted = false
			break
	_expect_true(accepted, "environment survives 10,000 sequential Ticks")
	_expect_true(
		simulation.has_valid_habitat_ownership(),
		"environment soak preserves all authority invariants"
	)
	for zone: HabitatZoneSnapshot in simulation.create_snapshot().zones:
		_expect_true(
			is_finite(zone.humidity)
				and is_finite(zone.light_exposure)
				and is_finite(zone.pollution),
			"environment soak keeps %s finite" % String(zone.zone_id)
		)


func _scenario_with_test_unlocks() -> HabitatScenarioData:
	var scenario: HabitatScenarioData = (
		ACT1_SCENARIO_DATA.duplicate(true) as HabitatScenarioData
	)
	scenario.facility_catalog_data = (
		ACT1_SCENARIO_DATA.facility_catalog_data.duplicate(true)
		as FacilityCatalogData
	)
	scenario.environment_data = (
		ACT1_SCENARIO_DATA.environment_data.duplicate(true)
		as EnvironmentData
	)
	var catalog: FacilityCatalogData = scenario.facility_catalog_data
	for facility_type: FacilityData in catalog.facility_types:
		if facility_type.type_id in [
			BOX_TYPE_ID,
			GATE_TYPE_ID,
			HYDRATION_TYPE_ID,
			WASTE_TYPE_ID,
			SUGAR_STATION_TYPE_ID,
			PROTEIN_DISH_TYPE_ID,
		]:
			facility_type.unlock_type_id = CampaignState.FACILITY_MAGNIFIER
	return scenario


func _new_simulation() -> ColonySimulation:
	var simulation: ColonySimulation = ColonySimulation.new(
		SPECIES_A_DATA,
		_scenario_with_test_unlocks()
	)
	_expect_true(simulation.is_ready(), "R8 simulation fixture is ready")
	return simulation


func _find_source_type(
	scenario: HabitatScenarioData,
	type_id: StringName
) -> FacilityData:
	for facility_type: FacilityData in (
		scenario.facility_catalog_data.facility_types
	):
		if facility_type.type_id == type_id:
			return facility_type
	return null


func _environment_signature(snapshot: GameSnapshot) -> String:
	var values: PackedStringArray = [
		str(snapshot.simulation_tick),
		str(snapshot.layout.revision),
	]
	for zone: HabitatZoneSnapshot in snapshot.colony.zones:
		values.append(
			"%s:%.6f:%.6f:%.6f"
			% [
				String(zone.zone_id),
				zone.humidity,
				zone.light_exposure,
				zone.pollution,
			]
		)
	for facility: FacilitySnapshot in snapshot.layout.facilities:
		values.append(
			"%d:%s:%s:%.6f"
			% [
				facility.facility_id,
				String(facility.type_id),
				String(facility.zone_id),
				facility.waste_fill_ratio,
			]
		)
	for connection: HabitatConnectionSnapshot in snapshot.layout.connections:
		values.append(
			"%d:%s:%s:%s"
			% [
				connection.connection_id,
				String(connection.first_zone_id),
				String(connection.second_zone_id),
				str(connection.open),
			]
		)
	return "|".join(values)


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
	printerr(
		"  %s - expected %s, got %s"
		% [message, expected, actual]
	)
