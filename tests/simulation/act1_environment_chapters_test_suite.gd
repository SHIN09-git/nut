class_name Act1EnvironmentChaptersTestSuite
extends RefCounted

const SPECIES: SpeciesData = preload("res://data/species/species_a.tres")
const SCENARIO: HabitatScenarioData = preload(
	"res://data/habitats/act1_test_tube.tres"
)

var _assertion_count: int = 0
var _failure_count: int = 0


func run() -> void:
	_test_progression_config_is_frozen()
	_test_chapter_three_evidence_and_transition()
	_test_protein_station_uses_next_tick_command()
	_test_chapter_four_connected_module_and_gate()
	_test_environment_evidence_requires_stability()
	_test_r9_save_enters_r10_progression()


func get_assertion_count() -> int:
	return _assertion_count


func get_failure_count() -> int:
	return _failure_count


func _test_progression_config_is_frozen() -> void:
	var source: HabitatScenarioData = _scenario_copy()
	var expected_workers: int = (
		source.act1_progression_data.chapter_three_min_worker_count
	)
	var simulation := ColonySimulation.new(SPECIES, source)
	_expect_true(simulation.is_ready(), "R10 progression fixture initializes")
	if not simulation.is_ready():
		return
	source.act1_progression_data.chapter_three_min_worker_count = 1
	_expect_int(
		simulation._habitat_config.act1_progression_config
			.chapter_three_min_worker_count,
		expected_workers,
		"source Resource mutation cannot change frozen chapter pacing"
	)
	var snapshot: GameSnapshot = simulation.create_game_snapshot()
	snapshot.act1.environment_stable_ticks = 999
	_expect_int(
		simulation.create_game_snapshot().act1.environment_stable_ticks,
		0,
		"Act 1 progression snapshot cannot mutate authority"
	)


func _test_chapter_three_evidence_and_transition() -> void:
	var simulation: ColonySimulation = _chapter_three_simulation()
	if not _expect_ready(simulation, "Chapter 3 evidence fixture"):
		return
	var state: ColonyState = simulation._state
	for event_type: ObservationEvent.Type in [
		ObservationEvent.Type.ZONE_DISCOVERED,
		ObservationEvent.Type.SUGAR_SHARED,
		ObservationEvent.Type.BROOD_FED,
		ObservationEvent.Type.WASTE_TRAY_CLEANED,
	]:
		state.record_observation_event(event_type)
	_expect_true(
		simulation.advance_tick(state.simulation_tick + 1),
		"Chapter 3 evidence Tick advances"
	)
	var ready: CampaignSnapshot = simulation.create_game_snapshot().campaign
	_expect_int(
		ready.status,
		CampaignState.Status.AWAITING_INFERENCE,
		"five Chapter 3 observations open its inference"
	)
	for evidence_id: StringName in [
		CampaignState.EVIDENCE_FORAGING_ZONE_SCOUTED,
		CampaignState.EVIDENCE_FORAGING_SUGAR_CYCLE,
		CampaignState.EVIDENCE_PROTEIN_CARE,
		CampaignState.EVIDENCE_WASTE_TRAY_CLEANED,
		CampaignState.EVIDENCE_SMALL_COLONY_STABLE,
	]:
		_expect_true(
			ready.has_evidence(evidence_id),
			"Chapter 3 records evidence %s" % String(evidence_id)
		)
	_expect_true(
		simulation.submit_campaign_inference_action(
			CampaignState.INFERENCE_FORAGING_ROLES
		),
		"Chapter 3 inference enters the command queue"
	)
	_expect_int(
		simulation.create_game_snapshot().campaign.chapter,
		CampaignState.Chapter.ACT1_FORAGING_EXPANSION,
		"inference submission does not change the same Tick"
	)
	_expect_true(
		simulation.advance_tick(state.simulation_tick + 1),
		"Chapter 3 inference Tick advances"
	)
	var chapter_four: CampaignSnapshot = (
		simulation.create_game_snapshot().campaign
	)
	_expect_int(
		chapter_four.chapter,
		CampaignState.Chapter.ACT1_ENVIRONMENT_MANAGEMENT,
		"correct Chapter 3 inference enters environmental care"
	)
	for facility_id: StringName in [
		CampaignState.FACILITY_SPARE_TEST_TUBE,
		CampaignState.FACILITY_HYDRATION_MODULE,
		CampaignState.FACILITY_CONNECTOR_FAMILY,
	]:
		_expect_true(
			chapter_four.has_unlocked_facility(facility_id),
			"Chapter 4 unlocks %s" % String(facility_id)
		)


func _test_protein_station_uses_next_tick_command() -> void:
	var simulation: ColonySimulation = _chapter_three_simulation()
	if not _expect_ready(simulation, "protein station fixture"):
		return
	var box_id: int = _place_first_available(
		simulation,
		CampaignState.FACILITY_SMALL_FORAGING_BOX
	)
	_expect_true(box_id >= 0, "foraging box is placed from a valid option")
	if box_id < 0:
		return
	var dish_id: int = _place_first_available(
		simulation,
		CampaignState.FACILITY_PROTEIN_DISH,
		simulation.create_game_snapshot().layout.get_facility(box_id).zone_id
	)
	_expect_true(dish_id >= 0, "protein dish is placed in its host zone")
	if dish_id < 0:
		return
	var layout: HabitatLayoutSnapshot = (
		simulation.create_game_snapshot().layout
	)
	_expect_string(
		String(layout.get_facility(dish_id).zone_id),
		String(layout.get_facility(box_id).zone_id),
		"protein dish inherits the foraging-box zone"
	)
	_expect_true(
		simulation.submit_place_protein_action(),
		"protein refill uses the high-level player action"
	)
	var before: NutritionSnapshot = simulation.create_game_snapshot().nutrition
	_expect_true(before.protein_action_pending, "protein action is pending")
	_expect_int(
		before.total_protein_portions_placed,
		0,
		"protein does not appear in the submission Tick"
	)
	_expect_true(
		simulation.advance_tick(simulation._state.simulation_tick + 1),
		"protein refill Tick advances"
	)
	var after: NutritionSnapshot = simulation.create_game_snapshot().nutrition
	_expect_int(
		after.total_protein_portions_placed,
		SCENARIO.protein_portions,
		"next Tick uses the frozen protein portion count"
	)
	var dedicated_source_found: bool = false
	for source: FoodSourceSnapshot in (
		simulation.create_game_snapshot().colony.food_sources
	):
		if (
			source.food_type == FoodSourceState.FoodType.PROTEIN
			and source.zone_id == layout.get_facility(box_id).zone_id
		):
			dedicated_source_found = true
			break
	_expect_true(
		dedicated_source_found,
		"protein action prefers the installed dedicated dish"
	)


func _test_chapter_four_connected_module_and_gate() -> void:
	var simulation: ColonySimulation = _chapter_four_simulation()
	if not _expect_ready(simulation, "connected spare-tube fixture"):
		return
	var gate_id: int = _place_exact(
		simulation,
		&"connector_gate",
		Vector2i(5, 3),
		0
	)
	_expect_true(gate_id >= 0, "Chapter 4 places a gate beside the feed port")
	if gate_id < 0:
		return
	var spare_id: int = _place_exact(
		simulation,
		CampaignState.FACILITY_TEST_TUBE_NEST,
		Vector2i(6, 3),
		2
	)
	_expect_true(
		spare_id >= 0,
		"rotated spare tube connects to the gate"
	)
	if spare_id < 0:
		return
	var layout: HabitatLayoutSnapshot = (
		simulation.create_game_snapshot().layout
	)
	var spare: FacilitySnapshot = layout.get_facility(spare_id)
	var gated_connection: HabitatConnectionSnapshot
	for connection: HabitatConnectionSnapshot in layout.connections:
		if connection.owner_facility_id == gate_id and connection.gated:
			gated_connection = connection
			break
	_expect_true(
		spare != null and not spare.zone_id.is_empty(),
		"spare tube creates one authoritative habitat zone"
	)
	_expect_true(
		gated_connection != null and gated_connection.open,
		"gate owns the derived open connection"
	)
	if spare == null or gated_connection == null:
		return
	var hydration_id: int = _place_first_available(
		simulation,
		CampaignState.FACILITY_HYDRATION_MODULE,
		spare.zone_id
	)
	_expect_true(
		hydration_id >= 0,
		"hydration module can target the connected spare tube"
	)
	if hydration_id < 0:
		return
	_expect_string(
		String(
			simulation.create_game_snapshot().layout
				.get_facility(hydration_id).zone_id
		),
		String(spare.zone_id),
		"hydration module inherits the spare-tube zone"
	)
	_expect_true(
		simulation.submit_set_gate_open_action(
			gated_connection.connection_id,
			false
		),
		"gate close enters the command queue"
	)
	_expect_true(
		simulation.create_game_snapshot().layout.action_pending,
		"gate remains open in the submission Tick"
	)
	_expect_true(
		simulation.advance_tick(simulation._state.simulation_tick + 1),
		"gate close Tick advances"
	)
	var closed: HabitatConnectionSnapshot
	for connection: HabitatConnectionSnapshot in (
		simulation.create_game_snapshot().layout.connections
	):
		if connection.connection_id == gated_connection.connection_id:
			closed = connection
			break
	_expect_true(
		closed != null and not closed.open,
		"gate closes only on the next fixed Tick"
	)


func _test_environment_evidence_requires_stability() -> void:
	var simulation: ColonySimulation = _chapter_four_simulation()
	if not _expect_ready(simulation, "environment evidence fixture"):
		return
	var gate_id: int = _place_exact(
		simulation,
		&"connector_gate",
		Vector2i(5, 3),
		0
	)
	_expect_true(gate_id >= 0, "environment fixture connects a gate")
	if gate_id < 0:
		return
	var spare_id: int = _place_exact(
		simulation,
		CampaignState.FACILITY_TEST_TUBE_NEST,
		Vector2i(6, 3),
		2
	)
	_expect_true(spare_id >= 0, "environment fixture connects a spare tube")
	if spare_id < 0:
		return
	var spare: FacilitySnapshot = (
		simulation.create_game_snapshot().layout.get_facility(spare_id)
	)
	_expect_true(
		spare != null and not spare.zone_id.is_empty(),
		"spare tube exposes its authoritative zone"
	)
	if spare == null or spare.zone_id.is_empty():
		return
	var hydration_id: int = _place_first_available(
		simulation,
		CampaignState.FACILITY_HYDRATION_MODULE,
		spare.zone_id
	)
	_expect_true(
		hydration_id >= 0,
		"Chapter 4 hydrates the connected spare tube"
	)
	if hydration_id < 0:
		return
	var state: ColonyState = simulation._state
	var nest: HabitatZoneState = state.get_zone(&"test_tube_nest")
	var target: HabitatZoneState = state.get_zone(spare.zone_id)
	nest.set_pollution(0.35)
	target.set_pollution(0.0)
	target.set_humidity(0.66)
	for ant: AntModel in state.ants:
		if ant.life_stage != AntModel.LifeStage.WORKER:
			ant.zone_id = target.zone_id
			ant.zone_entered_tick = state.simulation_tick
		else:
			ant.waste_cleanup_task.next_decision_tick = 100_000
			ant.scout_task.next_decision_tick = 100_000
			ant.migration_task.next_decision_tick = 100_000
	state.record_observation_event(
		ObservationEvent.Type.MIGRATION_MEMBER_DROPPED,
		state.ants[0].entity_id,
		state.ants[-1].entity_id,
		nest.zone_id,
		target.zone_id
	)
	_expect_true(
		simulation.advance_tick(state.simulation_tick + 1),
		"environment evidence Tick advances"
	)
	var first: GameSnapshot = simulation.create_game_snapshot()
	_expect_true(
		first.campaign.has_evidence(
			CampaignState.EVIDENCE_HYDRATION_RESPONSE
		),
		"comfortable hydrated zone becomes evidence"
	)
	_expect_true(
		first.campaign.has_evidence(
			CampaignState.EVIDENCE_POLLUTION_AVOIDANCE
		),
		"cleaner migration target becomes pollution evidence"
	)
	_expect_true(
		first.campaign.has_evidence(
			CampaignState.EVIDENCE_PARTIAL_MIGRATION
		),
		"one autonomous drop becomes partial-migration evidence"
	)
	_expect_true(
		not first.campaign.has_evidence(
			CampaignState.EVIDENCE_ENVIRONMENT_STABLE
		),
		"one Tick cannot satisfy the stability window"
	)
	var required_ticks: int = (
		simulation._habitat_config.act1_progression_config
			.environment_stable_ticks
	)
	for tick: int in range(
		state.simulation_tick + 1,
		state.simulation_tick + required_ticks + 2
	):
		_expect_true(
			simulation.advance_tick(tick),
			"environment stability Tick %d advances" % tick
		)
	var stable: CampaignSnapshot = simulation.create_game_snapshot().campaign
	_expect_true(
		stable.has_evidence(CampaignState.EVIDENCE_ENVIRONMENT_STABLE),
		"continuous stable state becomes chapter evidence"
	)
	_expect_int(
		stable.status,
		CampaignState.Status.AWAITING_INFERENCE,
		"all environmental evidence opens the final inference"
	)


func _test_r9_save_enters_r10_progression() -> void:
	var simulation := ColonySimulation.new(SPECIES, SCENARIO)
	if not _expect_ready(simulation, "R9 migration fixture"):
		return
	var state: ColonyState = simulation._state
	_enter_chapter_three(state)
	_configure_small_colony(state, simulation)
	var clock := SimulationClock.new()
	clock.restore_save_boundary(
		state.simulation_tick,
		SimulationClock.NORMAL_SPEED,
		false
	)
	var service := SaveGameService.new()
	var envelope: Dictionary = service.create_envelope(
		simulation,
		clock,
		"r9-to-r10",
		"2026-07-29T00:00:00Z"
	)
	_expect_true(not envelope.is_empty(), "R10 save fixture is captured")
	if envelope.is_empty():
		return
	SaveFixtureDowngrade.strip_r10_fields(envelope)
	envelope["state_schema_id"] = SimulationStateCodec.R9_SCHEMA_ID
	var old_campaign: Dictionary = envelope["state_payload"]["campaign"]
	old_campaign["chapter"] = CampaignState.Chapter.ACT1_FIRST_WORKERS
	old_campaign["status"] = CampaignState.Status.COMPLETED
	old_campaign["completed_chapter_count"] = 2
	old_campaign["campaign_completed_tick"] = state.simulation_tick
	for id: String in [
		"sugar_station",
		"protein_dish",
		"waste_tray",
	]:
		old_campaign["unlocked_facility_type_ids"].erase(id)
	envelope["frozen_config_hash"] = CanonicalSaveJson.sha256(
		envelope["frozen_config_bundle"]
	)
	envelope = service.seal_envelope(envelope)
	var result: Dictionary = service.load_envelope(envelope)
	_expect_true(
		result.get("ok", false),
		"R9 save migrates into R10: %s" % result.get("error", "")
	)
	if not result.get("ok", false):
		return
	_expect_true(result.get("migrated", false), "R9 migration is explicit")
	var restored: ColonySimulation = result["simulation"]
	var snapshot: GameSnapshot = restored.create_game_snapshot()
	_expect_int(
		snapshot.campaign.chapter,
		CampaignState.Chapter.ACT1_FORAGING_EXPANSION,
		"old two-chapter completion resumes at Chapter 3"
	)
	_expect_true(
		snapshot.campaign.has_unlocked_facility(
			CampaignState.FACILITY_PROTEIN_DISH
		),
		"migration grants the Chapter 3 toolset"
	)
	_expect_int(
		restored._habitat_config.act1_progression_config
			.environment_stable_ticks,
		30,
		"migration freezes the R10 pacing fixture"
	)


func _chapter_three_simulation() -> ColonySimulation:
	var simulation := ColonySimulation.new(SPECIES, _scenario_copy())
	if not simulation.is_ready():
		return simulation
	_enter_chapter_three(simulation._state)
	_configure_small_colony(simulation._state, simulation)
	return simulation


func _chapter_four_simulation() -> ColonySimulation:
	var simulation: ColonySimulation = _chapter_three_simulation()
	if not simulation.is_ready():
		return simulation
	var state: ColonyState = simulation._state
	var campaign: CampaignState = state.campaign_state
	campaign.chapter = CampaignState.Chapter.ACT1_ENVIRONMENT_MANAGEMENT
	campaign.completed_chapter_count = 3
	campaign.status = CampaignState.Status.ACTIVE
	campaign.chapter_entered_tick = state.simulation_tick
	campaign.confirm_inference(CampaignState.INFERENCE_FORAGING_ROLES)
	for facility_id: StringName in [
		CampaignState.FACILITY_SPARE_TEST_TUBE,
		CampaignState.FACILITY_HYDRATION_MODULE,
		CampaignState.FACILITY_CONNECTOR_FAMILY,
	]:
		campaign.unlock_facility(facility_id)
	var brood: AntModel = state.ants[-1]
	brood.life_stage = AntModel.LifeStage.LARVA
	brood.stage_age_ticks = 0
	brood.total_age_ticks = 0
	brood.configure_brood(
		&"test_tube_nest",
		-state.simulation_tick
	)
	return simulation


func _enter_chapter_three(state: ColonyState) -> void:
	var campaign: CampaignState = state.campaign_state
	campaign.chapter = CampaignState.Chapter.ACT1_FORAGING_EXPANSION
	campaign.status = CampaignState.Status.ACTIVE
	campaign.chapter_entered_tick = state.simulation_tick
	campaign.completed_chapter_count = 2
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
	]:
		campaign.confirm_inference(inference_id)
	for facility_id: StringName in [
		CampaignState.FACILITY_MICRO_FEEDING_PORT,
		CampaignState.FACILITY_SMALL_FORAGING_BOX,
		CampaignState.FACILITY_SUGAR_STATION,
		CampaignState.FACILITY_PROTEIN_DISH,
		CampaignState.FACILITY_WASTE_TRAY,
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
	state.act1_state.first_worker_emerged_tick = state.simulation_tick
	state.act1_state.first_worker_care_recorded = true
	state.nutrition_state.protein_reserve_portions = 1
	state.nutrition_state.total_protein_portions_consumed = 1
	state.nutrition_state.completed_feeding_count = 1


func _configure_small_colony(
	state: ColonyState,
	simulation: ColonySimulation
) -> void:
	for ant: AntModel in state.ants:
		ant.configure_nutrition_worker(
			&"test_tube_nest",
			state.simulation_tick + 100_000
		)
	for ant: AntModel in state.ants:
		if ant.life_stage != AntModel.LifeStage.WORKER:
			continue
		ant.worker_task.next_decision_tick = state.simulation_tick + 100_000
		ant.feeding_task.next_decision_tick = state.simulation_tick + 100_000
		ant.waste_cleanup_task.next_decision_tick = (
			state.simulation_tick + 100_000
		)
		ant.scout_task.next_decision_tick = state.simulation_tick + 100_000
		ant.migration_task.next_decision_tick = (
			state.simulation_tick + 100_000
		)


func _place_first_available(
	simulation: ColonySimulation,
	type_id: StringName,
	preferred_host_zone_id: StringName = &""
) -> int:
	var before_ids: Array[int] = []
	for facility: FacilitySnapshot in (
		simulation.create_game_snapshot().layout.facilities
	):
		before_ids.append(facility.facility_id)
	var option: FacilityPlacementOptionSnapshot
	for candidate: FacilityPlacementOptionSnapshot in (
		simulation.create_game_snapshot().layout.placement_options
	):
		if candidate.type_id != type_id:
			continue
		if not preferred_host_zone_id.is_empty():
			var host_zone_id: StringName = (
				simulation._state.layout_state.find_host_zone_id(
					simulation._habitat_config.facility_catalog_config,
					type_id,
					candidate.slot,
					candidate.orientation
				)
			)
			if host_zone_id != preferred_host_zone_id:
				continue
		option = candidate
		break
	if option == null:
		return -1
	if not simulation.submit_place_facility_action(
		type_id,
		option.slot,
		option.orientation
	):
		return -1
	if not simulation.advance_tick(simulation._state.simulation_tick + 1):
		return -1
	for facility: FacilitySnapshot in (
		simulation.create_game_snapshot().layout.facilities
	):
		if (
			facility.type_id == type_id
			and not before_ids.has(facility.facility_id)
		):
			return facility.facility_id
	return -1


func _place_exact(
	simulation: ColonySimulation,
	type_id: StringName,
	slot: Vector2i,
	orientation: int
) -> int:
	var option_found: bool = false
	for option: FacilityPlacementOptionSnapshot in (
		simulation.create_game_snapshot().layout.placement_options
	):
		if (
			option.type_id == type_id
			and option.slot == slot
			and option.orientation == orientation
		):
			option_found = true
			break
	if (
		not option_found
		or not simulation.submit_place_facility_action(
			type_id,
			slot,
			orientation
		)
	):
		return -1
	var before_ids: Array[int] = []
	for facility: FacilitySnapshot in (
		simulation.create_game_snapshot().layout.facilities
	):
		before_ids.append(facility.facility_id)
	if not simulation.advance_tick(simulation._state.simulation_tick + 1):
		return -1
	for facility: FacilitySnapshot in (
		simulation.create_game_snapshot().layout.facilities
	):
		if facility.type_id == type_id and not before_ids.has(
			facility.facility_id
		):
			return facility.facility_id
	return -1


func _scenario_copy() -> HabitatScenarioData:
	var scenario: HabitatScenarioData = (
		SCENARIO.duplicate(true) as HabitatScenarioData
	)
	scenario.act1_progression_data = (
		SCENARIO.act1_progression_data.duplicate(true)
		as Act1ProgressionData
	)
	return scenario


func _expect_ready(
	simulation: ColonySimulation,
	label: String
) -> bool:
	var ready: bool = simulation != null and simulation.is_ready()
	_expect_true(
		ready,
		"%s is ready: %s"
		% [
			label,
			(
				simulation.get_configuration_error()
				if simulation != null
				else "null"
			),
		]
	)
	return ready


func _expect_true(actual: bool, message: String) -> void:
	_assertion_count += 1
	if not actual:
		_record_failure("%s - expected true, got false" % message)


func _expect_int(actual: int, expected: int, message: String) -> void:
	_assertion_count += 1
	if actual != expected:
		_record_failure(
			"%s - expected %d, got %d" % [message, expected, actual]
		)


func _expect_string(
	actual: String,
	expected: String,
	message: String
) -> void:
	_assertion_count += 1
	if actual != expected:
		_record_failure(
			"%s - expected %s, got %s" % [message, expected, actual]
		)


func _record_failure(message: String) -> void:
	_failure_count += 1
	printerr("  " + message)
