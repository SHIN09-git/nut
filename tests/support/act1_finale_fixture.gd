class_name Act1FinaleFixture
extends RefCounted

const SPECIES: SpeciesData = preload("res://data/species/species_a.tres")
const SCENARIO: HabitatScenarioData = preload(
	"res://data/habitats/act1_test_tube.tres"
)


static func create_simulation() -> ColonySimulation:
	var simulation := ColonySimulation.new(SPECIES, SCENARIO.duplicate(true))
	if not simulation.is_ready():
		return simulation
	var state: ColonyState = simulation._state
	var first_worker: AntModel = state.get_ant(
		state.act1_state.first_worker_entity_id
	)
	if first_worker == null:
		return simulation
	first_worker.configure_nutrition_worker(
		&"test_tube_nest",
		state.simulation_tick + 100_000
	)
	for ant: AntModel in state.ants:
		if ant.entity_id == first_worker.entity_id:
			continue
		ant.configure_brood(&"test_tube_nest", state.simulation_tick)
	state.invalidate_worker_order()
	state.act1_state.first_worker_emerged_tick = state.simulation_tick
	state.act1_state.first_worker_care_recorded = true
	state.nutrition_state.protein_reserve_portions = 1
	state.nutrition_state.total_protein_portions_consumed = 1
	state.nutrition_state.completed_feeding_count = 1

	_prepare_campaign_history(state)
	var dual_id: int = _place_exact(
		simulation,
		CampaignState.FACILITY_DUAL_CHAMBER_NEST,
		Vector2i(6, 3),
		0,
		true
	)
	if dual_id < 0:
		return simulation
	var dual: FacilitySnapshot = (
		simulation.create_game_snapshot().layout.get_facility(dual_id)
	)
	if (
		dual == null
		or _place_for_zone(
			simulation,
			CampaignState.FACILITY_HYDRATION_MODULE,
			dual.zone_id
		) < 0
		or _place_for_zone(
			simulation,
			CampaignState.FACILITY_WASTE_TRAY,
			&"micro_feeding_port"
		) < 0
	):
		return simulation

	state = simulation._state
	var brood_zone: HabitatZoneState = state.get_zone(dual.zone_id)
	var utility_zone: HabitatZoneState = state.get_zone(
		dual.secondary_zone_id
	)
	if brood_zone == null or utility_zone == null:
		return simulation
	brood_zone.set_humidity(0.66)
	brood_zone.set_light_exposure(0.18)
	brood_zone.set_pollution(0.0)
	brood_zone.mark_discovered(state.simulation_tick)
	utility_zone.set_pollution(0.0)
	utility_zone.mark_discovered(state.simulation_tick)
	state.queen.assign_zone(dual.zone_id, state.simulation_tick)
	for ant: AntModel in state.ants:
		if ant.life_stage == AntModel.LifeStage.WORKER:
			ant.configure_nutrition_worker(
				dual.secondary_zone_id,
				state.simulation_tick + 100_000
			)
			ant.worker_task.next_decision_tick = (
				state.simulation_tick + 100_000
			)
			ant.feeding_task.next_decision_tick = (
				state.simulation_tick + 100_000
			)
			ant.waste_cleanup_task.next_decision_tick = (
				state.simulation_tick + 100_000
			)
			ant.scout_task.next_decision_tick = (
				state.simulation_tick + 100_000
			)
			ant.migration_task.next_decision_tick = (
				state.simulation_tick + 100_000
			)
		else:
			ant.configure_brood(dual.zone_id, state.simulation_tick)
	state.invalidate_worker_order()
	state.colony_work_state.completed_migration_count = maxi(
		state.colony_work_state.completed_migration_count,
		1
	)
	state.colony_work_state.scouted_zone_count = maxi(
		state.colony_work_state.scouted_zone_count,
		2
	)
	state.colony_work_state.cleaned_waste_tray_count = maxi(
		state.colony_work_state.cleaned_waste_tray_count,
		1
	)
	_enter_finale(state)
	return simulation


static func _prepare_campaign_history(state: ColonyState) -> void:
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
		CampaignState.EVIDENCE_FORAGING_ZONE_SCOUTED,
		CampaignState.EVIDENCE_FORAGING_SUGAR_CYCLE,
		CampaignState.EVIDENCE_PROTEIN_CARE,
		CampaignState.EVIDENCE_WASTE_TRAY_CLEANED,
		CampaignState.EVIDENCE_SMALL_COLONY_STABLE,
		CampaignState.EVIDENCE_HYDRATION_RESPONSE,
		CampaignState.EVIDENCE_POLLUTION_AVOIDANCE,
		CampaignState.EVIDENCE_PARTIAL_MIGRATION,
		CampaignState.EVIDENCE_ENVIRONMENT_STABLE,
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


static func _enter_finale(state: ColonyState) -> void:
	var campaign: CampaignState = state.campaign_state
	for evidence_id: StringName in [
		CampaignState.EVIDENCE_DUAL_NEST_CONNECTED,
		CampaignState.EVIDENCE_DUAL_NEST_SCOUTED,
		CampaignState.EVIDENCE_CORE_BROOD_MIGRATED,
		CampaignState.EVIDENCE_QUEEN_MIGRATED,
		CampaignState.EVIDENCE_FUNCTIONAL_ZONING,
	]:
		campaign.collect_evidence(evidence_id)
	campaign.confirm_inference(
		CampaignState.INFERENCE_MIGRATION_CONDITIONS
	)
	campaign.chapter = CampaignState.Chapter.ACT1_STABLE_COLONY_SUMMARY
	campaign.status = CampaignState.Status.ACTIVE
	campaign.chapter_entered_tick = state.simulation_tick
	campaign.completed_chapter_count = 5
	campaign.campaign_completed_tick = -1
	state.act1_state.environment_stable_ticks = 0
	state.act1_state.finale_stable_ticks = 0
	state.act1_state.final_report_generated_tick = -1


static func _place_exact(
	simulation: ColonySimulation,
	type_id: StringName,
	slot: Vector2i,
	orientation: int,
	place_bridge_first: bool = false
) -> int:
	if place_bridge_first:
		var bridge_id: int = _place_exact(
			simulation,
			&"connector_gate",
			Vector2i(5, 3),
			0
		)
		if bridge_id < 0:
			return -1
	var before_ids: Array[int] = []
	for facility: FacilitySnapshot in (
		simulation.create_game_snapshot().layout.facilities
	):
		before_ids.append(facility.facility_id)
	if (
		not simulation.submit_place_facility_action(
			type_id,
			slot,
			orientation
		)
		or not simulation.advance_tick(
			simulation._state.simulation_tick + 1
		)
	):
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


static func _place_for_zone(
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
