class_name Act1ModularMigrationTestSuite
extends RefCounted

const SPECIES: SpeciesData = preload("res://data/species/species_a.tres")
const SCENARIO: HabitatScenarioData = preload(
	"res://data/habitats/act1_test_tube.tres"
)

var _assertion_count: int = 0
var _failure_count: int = 0


func run() -> void:
	_test_dual_chamber_creates_two_connected_zones()
	_test_hydration_targets_the_brood_chamber()
	_test_workers_autonomously_migrate_the_colony_core()
	_test_chapter_five_evidence_requires_core_migration()
	_test_dual_chamber_save_round_trip()
	_test_r10_save_enters_chapter_five()


func get_assertion_count() -> int:
	return _assertion_count


func get_failure_count() -> int:
	return _failure_count


func _test_dual_chamber_creates_two_connected_zones() -> void:
	var simulation: ColonySimulation = _chapter_five_simulation()
	if not _expect_ready(simulation, "dual-chamber fixture"):
		return
	var dual_id: int = _place_connected_dual_chamber(simulation)
	_expect_true(dual_id >= 0, "dual chamber connects to the existing network")
	if dual_id < 0:
		return
	var snapshot: GameSnapshot = simulation.create_game_snapshot()
	var dual: FacilitySnapshot = snapshot.layout.get_facility(dual_id)
	_expect_true(
		dual != null
			and not dual.zone_id.is_empty()
			and not dual.secondary_zone_id.is_empty()
			and dual.zone_id != dual.secondary_zone_id,
		"one facility owns two distinct stable zone IDs"
	)
	if dual == null:
		return
	_expect_true(
		snapshot.colony.find_zone(dual.zone_id) != null
			and snapshot.colony.find_zone(dual.secondary_zone_id) != null,
		"both dual-chamber zones cross the snapshot boundary"
	)
	var internal_found: bool = false
	var external_found: bool = false
	for connection: HabitatConnectionSnapshot in snapshot.layout.connections:
		var endpoints: Array[StringName] = [
			connection.first_zone_id,
			connection.second_zone_id,
		]
		if (
			endpoints.has(dual.zone_id)
			and endpoints.has(dual.secondary_zone_id)
			and connection.owner_facility_id == dual_id
		):
			internal_found = true
		elif (
			endpoints.has(dual.zone_id)
			or endpoints.has(dual.secondary_zone_id)
		):
			external_found = true
	_expect_true(internal_found, "dual chamber owns one internal connection")
	_expect_true(
		external_found,
		"one chamber port connects to the external habitat graph"
	)
	dual.secondary_zone_humidity = 0.99
	_expect_true(
		not is_equal_approx(
			simulation.create_game_snapshot().layout
				.get_facility(dual_id).secondary_zone_humidity,
			0.99
		),
		"secondary chamber snapshot cannot mutate authority"
	)


func _test_hydration_targets_the_brood_chamber() -> void:
	var simulation: ColonySimulation = _chapter_five_simulation()
	if not _expect_ready(simulation, "dual hydration fixture"):
		return
	var dual_id: int = _place_connected_dual_chamber(simulation)
	if dual_id < 0:
		_expect_true(false, "dual hydration fixture places its nest")
		return
	var dual: FacilitySnapshot = (
		simulation.create_game_snapshot().layout.get_facility(dual_id)
	)
	var hydration_id: int = _place_for_zone(
		simulation,
		CampaignState.FACILITY_HYDRATION_MODULE,
		dual.zone_id
	)
	_expect_true(
		hydration_id >= 0,
		"hydration overlay can target the brood chamber cell"
	)
	if hydration_id < 0:
		return
	var hydration: FacilitySnapshot = (
		simulation.create_game_snapshot().layout
			.get_facility(hydration_id)
	)
	_expect_string(
		String(hydration.zone_id),
		String(dual.zone_id),
		"overlay host mapping selects the intended chamber"
	)
	_expect_true(
		hydration.zone_id != dual.secondary_zone_id,
		"hydration does not silently affect both chambers"
	)
	_expect_true(
		not simulation.submit_rotate_facility_action(dual_id, 2),
		"a hosted hydration module prevents chamber remapping"
	)
	_expect_int(
		simulation.create_game_snapshot().layout
			.get_facility(dual_id).orientation,
		0,
		"rejected dual-chamber rotation preserves its orientation"
	)


func _test_workers_autonomously_migrate_the_colony_core() -> void:
	var simulation: ColonySimulation = _chapter_five_simulation()
	if not _expect_ready(simulation, "autonomous migration fixture"):
		return
	var state: ColonyState = simulation._state
	var worker: AntModel = state.ants[0]
	worker.configure_nutrition_worker(
		&"test_tube_nest",
		state.simulation_tick
	)
	for ant_index: int in range(1, state.ants.size()):
		state.ants[ant_index].configure_brood(
			&"test_tube_nest",
			state.simulation_tick
		)
	var source: HabitatZoneState = state.get_zone(&"test_tube_nest")
	source.set_humidity(0.30)
	source.set_light_exposure(0.88)
	source.set_pollution(0.0)

	var dual_id: int = _place_connected_dual_chamber(simulation)
	_expect_true(dual_id >= 0, "autonomous fixture connects the new nest")
	if dual_id < 0:
		return
	var dual: FacilitySnapshot = (
		simulation.create_game_snapshot().layout.get_facility(dual_id)
	)
	var hydration_id: int = _place_for_zone(
		simulation,
		CampaignState.FACILITY_HYDRATION_MODULE,
		dual.zone_id
	)
	_expect_true(
		hydration_id >= 0,
		"autonomous fixture hydrates the brood chamber"
	)
	if hydration_id < 0:
		return

	var discovered_both: bool = false
	var carried_member_seen: bool = false
	var completed: bool = false
	var maximum_tick: int = state.simulation_tick + 1_500
	while state.simulation_tick < maximum_tick:
		var brood_zone: HabitatZoneState = state.get_zone(dual.zone_id)
		var utility_zone: HabitatZoneState = state.get_zone(
			dual.secondary_zone_id
		)
		discovered_both = (
			brood_zone != null
			and utility_zone != null
			and brood_zone.discovered
			and utility_zone.discovered
		)
		for ant: AntModel in state.ants:
			if (
				ant.migration_task != null
				and ant.migration_task.carried_entity_id >= 0
			):
				carried_member_seen = true
		var all_brood_migrated: bool = true
		for ant: AntModel in state.ants:
			if (
				ant.life_stage != AntModel.LifeStage.WORKER
				and ant.zone_id != dual.zone_id
			):
				all_brood_migrated = false
				break
		if (
			all_brood_migrated
			and state.queen.zone_id == dual.zone_id
			and state.colony_work_state.completed_migration_count > 0
		):
			completed = true
			break
		if not simulation.advance_tick(state.simulation_tick + 1):
			break

	_expect_true(discovered_both, "workers scout both new chambers")
	_expect_true(
		carried_member_seen,
		"an authoritative migration task visibly carries a colony member"
	)
	_expect_true(completed, "workers autonomously finish the core migration")
	_expect_true(
		simulation.has_valid_habitat_ownership(),
		"autonomous migration preserves single ownership"
	)
	if not completed:
		return
	var completed_snapshot: GameSnapshot = simulation.create_game_snapshot()
	_expect_string(
		String(completed_snapshot.colony.queen_zone_id),
		String(dual.zone_id),
		"queen enters the configured brood chamber last"
	)
	for ant: AntSnapshot in completed_snapshot.colony.ants:
		if ant.life_stage == AntModel.LifeStage.WORKER:
			continue
		_expect_string(
			String(ant.zone_id),
			String(dual.zone_id),
			"brood %d ends in the configured brood chamber" % ant.entity_id
		)


func _test_chapter_five_evidence_requires_core_migration() -> void:
	var simulation: ColonySimulation = _chapter_five_simulation()
	if not _expect_ready(simulation, "Chapter 5 evidence fixture"):
		return
	var dual_id: int = _place_connected_dual_chamber(simulation)
	if dual_id < 0:
		_expect_true(false, "Chapter 5 evidence fixture places its nest")
		return
	var dual: FacilitySnapshot = (
		simulation.create_game_snapshot().layout.get_facility(dual_id)
	)
	var hydration_id: int = _place_for_zone(
		simulation,
		CampaignState.FACILITY_HYDRATION_MODULE,
		dual.zone_id
	)
	var tray_id: int = _place_for_zone(
		simulation,
		CampaignState.FACILITY_WASTE_TRAY,
		&"micro_feeding_port"
	)
	_expect_true(
		hydration_id >= 0 and tray_id >= 0,
		"Chapter 5 prepares hydration and a reachable waste path"
	)
	if hydration_id < 0 or tray_id < 0:
		return
	var state: ColonyState = simulation._state
	var brood_zone: HabitatZoneState = state.get_zone(dual.zone_id)
	var utility_zone: HabitatZoneState = state.get_zone(
		dual.secondary_zone_id
	)
	brood_zone.set_humidity(0.66)
	brood_zone.set_pollution(0.0)
	brood_zone.mark_discovered(state.simulation_tick)
	utility_zone.set_pollution(0.0)
	utility_zone.mark_discovered(state.simulation_tick)
	_expect_true(
		simulation.advance_tick(state.simulation_tick + 1),
		"prepared dual chamber advances one evidence Tick"
	)
	var before: CampaignSnapshot = (
		simulation.create_game_snapshot().campaign
	)
	_expect_true(
		before.has_evidence(CampaignState.EVIDENCE_DUAL_NEST_CONNECTED)
			and before.has_evidence(
				CampaignState.EVIDENCE_DUAL_NEST_SCOUTED
			),
		"connection and scouting evidence can be observed first"
	)
	_expect_true(
		not before.has_evidence(
			CampaignState.EVIDENCE_CORE_BROOD_MIGRATED
		),
		"prepared rooms alone do not fake core migration"
	)
	state.queen.zone_id = dual.zone_id
	state.queen.zone_entered_tick = state.simulation_tick
	for ant: AntModel in state.ants:
		if ant.life_stage != AntModel.LifeStage.WORKER:
			ant.zone_id = dual.zone_id
			ant.zone_entered_tick = state.simulation_tick
	var required: int = (
		simulation._habitat_config.act1_progression_config
			.core_migration_stable_ticks
	)
	for tick: int in range(
		state.simulation_tick + 1,
		state.simulation_tick + required + 2
	):
		_expect_true(
			simulation.advance_tick(tick),
			"Chapter 5 stability Tick %d advances" % tick
		)
	var completed: CampaignSnapshot = (
		simulation.create_game_snapshot().campaign
	)
	for evidence_id: StringName in [
		CampaignState.EVIDENCE_CORE_BROOD_MIGRATED,
		CampaignState.EVIDENCE_QUEEN_MIGRATED,
		CampaignState.EVIDENCE_FUNCTIONAL_ZONING,
	]:
		_expect_true(
			completed.has_evidence(evidence_id),
			"core migration evidence %s is collected" % evidence_id
		)
	_expect_int(
		completed.status,
		CampaignState.Status.AWAITING_INFERENCE,
		"five Chapter 5 observations open the inference"
	)


func _test_dual_chamber_save_round_trip() -> void:
	var simulation: ColonySimulation = _chapter_five_simulation()
	if not _expect_ready(simulation, "dual save fixture"):
		return
	var dual_id: int = _place_connected_dual_chamber(simulation)
	if dual_id < 0:
		_expect_true(false, "dual save fixture places its nest")
		return
	var clock := SimulationClock.new()
	clock.restore_save_boundary(
		simulation._state.simulation_tick,
		SimulationClock.NORMAL_SPEED,
		false
	)
	var service := SaveGameService.new()
	var envelope: Dictionary = service.create_envelope(
		simulation,
		clock,
		"r11_dual"
	)
	var result: Dictionary = service.load_envelope(envelope)
	_expect_true(
		result.get("ok", false),
		"dual-chamber save restores: %s" % result.get("error", "")
	)
	if not result.get("ok", false):
		return
	var before: FacilitySnapshot = (
		simulation.create_game_snapshot().layout.get_facility(dual_id)
	)
	var after: FacilitySnapshot = (
		result["simulation"].create_game_snapshot().layout
			.get_facility(dual_id)
	)
	_expect_string(
		String(after.zone_id),
		String(before.zone_id),
		"primary chamber stable ID survives save/load"
	)
	_expect_string(
		String(after.secondary_zone_id),
		String(before.secondary_zone_id),
		"secondary chamber stable ID survives save/load"
	)


func _test_r10_save_enters_chapter_five() -> void:
	var simulation: ColonySimulation = _chapter_five_simulation()
	if not _expect_ready(simulation, "R10 migration fixture"):
		return
	var service := SaveGameService.new()
	var envelope: Dictionary = service.create_envelope(
		simulation,
		SimulationClock.new(),
		"r10_to_r11"
	)
	SaveFixtureDowngrade.strip_r11_fields(envelope)
	envelope["state_schema_id"] = SimulationStateCodec.R10_SCHEMA_ID
	envelope["game_version"] = "0.10.0-dev"
	envelope["frozen_config_hash"] = CanonicalSaveJson.sha256(
		envelope["frozen_config_bundle"]
	)
	envelope = service.seal_envelope(envelope)
	var result: Dictionary = service.load_envelope(envelope)
	_expect_true(
		result.get("ok", false),
		"R10 completion migrates into R11: %s" % result.get("error", "")
	)
	if not result.get("ok", false):
		return
	_expect_true(result.get("migrated", false), "R10 migration is explicit")
	var restored: GameSnapshot = (
		result["simulation"].create_game_snapshot()
	)
	_expect_int(
		restored.campaign.chapter,
		CampaignState.Chapter.ACT1_MODULAR_MIGRATION,
		"old four-chapter completion resumes at Chapter 5"
	)
	_expect_true(
		restored.campaign.has_unlocked_facility(
			CampaignState.FACILITY_DUAL_CHAMBER_NEST
		),
		"migration grants the dual-chamber tool"
	)


func _chapter_five_simulation() -> ColonySimulation:
	var simulation := ColonySimulation.new(SPECIES, SCENARIO.duplicate(true))
	if not simulation.is_ready():
		return simulation
	var state: ColonyState = simulation._state
	var campaign: CampaignState = state.campaign_state
	campaign.chapter = CampaignState.Chapter.ACT1_MODULAR_MIGRATION
	campaign.status = CampaignState.Status.ACTIVE
	campaign.chapter_entered_tick = state.simulation_tick
	campaign.completed_chapter_count = 4
	campaign.campaign_completed_tick = -1
	for evidence_id: StringName in [
		CampaignState.EVIDENCE_QUEEN_CARE,
		CampaignState.EVIDENCE_FIRST_PUPA,
		CampaignState.EVIDENCE_FIRST_WORKER,
		CampaignState.EVIDENCE_FIRST_WORKER_CARE,
		CampaignState.EVIDENCE_FIRST_NUTRIENT_EXCHANGE,
	]:
		campaign.collect_evidence(evidence_id)
	for inference_id: StringName in [
		CampaignState.INFERENCE_QUEEN_CARE,
		CampaignState.INFERENCE_WORKER_NUTRITION,
		CampaignState.INFERENCE_FORAGING_ROLES,
		CampaignState.INFERENCE_ENVIRONMENT_GRADIENT,
	]:
		campaign.confirm_inference(inference_id)
	for facility_id: StringName in [
		CampaignState.FACILITY_MICRO_FEEDING_PORT,
		CampaignState.FACILITY_SMALL_FORAGING_BOX,
		CampaignState.FACILITY_SUGAR_STATION,
		CampaignState.FACILITY_PROTEIN_DISH,
		CampaignState.FACILITY_WASTE_TRAY,
		CampaignState.FACILITY_SPARE_TEST_TUBE,
		CampaignState.FACILITY_HYDRATION_MODULE,
		CampaignState.FACILITY_CONNECTOR_FAMILY,
		CampaignState.FACILITY_DUAL_CHAMBER_NEST,
	]:
		campaign.unlock_facility(facility_id)
	var care: FoundingCareData = SCENARIO.founding_care_data
	for card_id: StringName in [
		care.queen_care_observation_card_id,
		care.pupa_observation_card_id,
		care.first_worker_observation_card_id,
		care.worker_care_observation_card_id,
		SCENARIO.foraging_observation_card_id,
	]:
		state.unlocked_observation_card_ids[card_id] = true
	return simulation


func _place_connected_dual_chamber(
	simulation: ColonySimulation
) -> int:
	var gate_id: int = _place_exact(
		simulation,
		&"connector_gate",
		Vector2i(5, 3),
		0
	)
	if gate_id < 0:
		return -1
	return _place_exact(
		simulation,
		CampaignState.FACILITY_DUAL_CHAMBER_NEST,
		Vector2i(6, 3),
		0
	)


func _place_exact(
	simulation: ColonySimulation,
	type_id: StringName,
	slot: Vector2i,
	orientation: int
) -> int:
	var before: Array[int] = []
	for facility: FacilitySnapshot in (
		simulation.create_game_snapshot().layout.facilities
	):
		before.append(facility.facility_id)
	if not simulation.submit_place_facility_action(
		type_id,
		slot,
		orientation
	):
		return -1
	if not simulation.advance_tick(simulation._state.simulation_tick + 1):
		return -1
	for facility: FacilitySnapshot in (
		simulation.create_game_snapshot().layout.facilities
	):
		if facility.type_id == type_id and not before.has(facility.facility_id):
			return facility.facility_id
	return -1


func _place_for_zone(
	simulation: ColonySimulation,
	type_id: StringName,
	zone_id: StringName
) -> int:
	for option: FacilityPlacementOptionSnapshot in (
		simulation.create_game_snapshot().layout.placement_options
	):
		if option.type_id != type_id:
			continue
		var host_zone_id: StringName = (
			simulation._state.layout_state.find_host_zone_id(
				simulation._habitat_config.facility_catalog_config,
				type_id,
				option.slot,
				option.orientation
			)
		)
		if host_zone_id == zone_id:
			return _place_exact(
				simulation,
				type_id,
				option.slot,
				option.orientation
			)
	return -1


func _expect_ready(
	simulation: ColonySimulation,
	label: String
) -> bool:
	var ready: bool = simulation != null and simulation.is_ready()
	_expect_true(
		ready,
		"%s initializes: %s"
			% [
				label,
				(
					simulation.get_configuration_error()
					if simulation != null
					else "missing simulation"
				),
			]
	)
	return ready


func _expect_true(actual: bool, label: String) -> void:
	_assertion_count += 1
	if actual:
		return
	_failure_count += 1
	printerr("  %s - expected true, got false" % label)


func _expect_int(actual: int, expected: int, label: String) -> void:
	_assertion_count += 1
	if actual == expected:
		return
	_failure_count += 1
	printerr("  %s - expected %d, got %d" % [label, expected, actual])


func _expect_string(actual: String, expected: String, label: String) -> void:
	_assertion_count += 1
	if actual == expected:
		return
	_failure_count += 1
	printerr("  %s - expected %s, got %s" % [label, expected, actual])
