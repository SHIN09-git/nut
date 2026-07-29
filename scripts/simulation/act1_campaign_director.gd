class_name Act1CampaignDirector
extends RefCounted

const MAX_HINT_TIER: int = 3

var _habitat_config: HabitatScenarioConfig
var _brood_care_config: BroodCareConfig


func _init(
	habitat_config: HabitatScenarioConfig,
	brood_care_config: BroodCareConfig
) -> void:
	_habitat_config = habitat_config
	_brood_care_config = brood_care_config


func is_ready() -> bool:
	return (
		_habitat_config != null
		and _habitat_config.is_act1_test_tube()
		and _habitat_config.founding_care_config != null
		and _habitat_config.act1_progression_config != null
		and _brood_care_config != null
	)


func update_after_systems(state: ColonyState) -> void:
	if not is_ready() or state == null or state.campaign_state == null:
		return
	var campaign: CampaignState = state.campaign_state
	var care: FoundingCareConfig = _habitat_config.founding_care_config
	if state.unlocked_observation_card_ids.has(
		care.queen_care_observation_card_id
	):
		campaign.collect_evidence(CampaignState.EVIDENCE_QUEEN_CARE)
	if state.unlocked_observation_card_ids.has(
		care.pupa_observation_card_id
	):
		campaign.collect_evidence(CampaignState.EVIDENCE_FIRST_PUPA)
	if state.unlocked_observation_card_ids.has(
		care.first_worker_observation_card_id
	):
		campaign.collect_evidence(CampaignState.EVIDENCE_FIRST_WORKER)
	if state.unlocked_observation_card_ids.has(
		care.worker_care_observation_card_id
	):
		campaign.collect_evidence(
			CampaignState.EVIDENCE_FIRST_WORKER_CARE
		)
	if state.unlocked_observation_card_ids.has(
		_habitat_config.foraging_observation_card_id
	):
		campaign.collect_evidence(
			CampaignState.EVIDENCE_FIRST_NUTRIENT_EXCHANGE
		)
	if campaign.chapter == CampaignState.Chapter.ACT1_FORAGING_EXPANSION:
		_collect_foraging_expansion_evidence(state, campaign)
		state.act1_state.environment_stable_ticks = 0
	elif (
		campaign.chapter
		== CampaignState.Chapter.ACT1_ENVIRONMENT_MANAGEMENT
	):
		_collect_environment_evidence(state, campaign)
	else:
		state.act1_state.environment_stable_ticks = 0
	_refresh_status(campaign)


func is_inference_action_available(
	state: ColonyState,
	inference_id: StringName
) -> bool:
	if (
		state == null
		or state.campaign_state == null
		or state.campaign_state.status
			!= CampaignState.Status.AWAITING_INFERENCE
	):
		return false
	return get_available_inference_ids(state.campaign_state).has(
		inference_id
	)


func apply_inference_action(
	state: ColonyState,
	inference_id: StringName
) -> bool:
	if not is_inference_action_available(state, inference_id):
		return false
	var campaign: CampaignState = state.campaign_state
	var correct_id: StringName = get_correct_inference_id(campaign.chapter)
	if inference_id != correct_id:
		campaign.incorrect_inference_attempts += 1
		campaign.hint_tier = mini(MAX_HINT_TIER, campaign.hint_tier + 1)
		state.record_observation_event(
			ObservationEvent.Type.CAMPAIGN_INFERENCE_REJECTED
		)
		return true

	campaign.confirm_inference(inference_id)
	state.record_observation_event(
		ObservationEvent.Type.CAMPAIGN_INFERENCE_CONFIRMED
	)
	if campaign.chapter == CampaignState.Chapter.ACT1_FOUNDING:
		campaign.completed_chapter_count = 1
		campaign.unlock_facility(
			CampaignState.FACILITY_MICRO_FEEDING_PORT
		)
		campaign.chapter = CampaignState.Chapter.ACT1_FIRST_WORKERS
		campaign.status = CampaignState.Status.ACTIVE
		campaign.chapter_entered_tick = state.simulation_tick
		campaign.hint_tier = 0
		state.record_observation_event(
			ObservationEvent.Type.CAMPAIGN_CHAPTER_COMPLETED
		)
		_refresh_status(campaign)
		return true
	if campaign.chapter == CampaignState.Chapter.ACT1_FIRST_WORKERS:
		campaign.completed_chapter_count = 2
		campaign.unlock_facility(
			CampaignState.FACILITY_SMALL_FORAGING_BOX
		)
		for facility_id: StringName in [
			CampaignState.FACILITY_SUGAR_STATION,
			CampaignState.FACILITY_PROTEIN_DISH,
			CampaignState.FACILITY_WASTE_TRAY,
		]:
			campaign.unlock_facility(facility_id)
		campaign.chapter = CampaignState.Chapter.ACT1_FORAGING_EXPANSION
		campaign.status = CampaignState.Status.ACTIVE
		campaign.chapter_entered_tick = state.simulation_tick
		campaign.hint_tier = 0
		state.record_observation_event(
			ObservationEvent.Type.CAMPAIGN_CHAPTER_COMPLETED
		)
		_refresh_status(campaign)
		return true
	if campaign.chapter == CampaignState.Chapter.ACT1_FORAGING_EXPANSION:
		campaign.completed_chapter_count = 3
		for facility_id: StringName in [
			CampaignState.FACILITY_SPARE_TEST_TUBE,
			CampaignState.FACILITY_HYDRATION_MODULE,
			CampaignState.FACILITY_CONNECTOR_FAMILY,
		]:
			campaign.unlock_facility(facility_id)
		campaign.chapter = (
			CampaignState.Chapter.ACT1_ENVIRONMENT_MANAGEMENT
		)
		campaign.status = CampaignState.Status.ACTIVE
		campaign.chapter_entered_tick = state.simulation_tick
		campaign.hint_tier = 0
		state.act1_state.environment_stable_ticks = 0
		state.record_observation_event(
			ObservationEvent.Type.CAMPAIGN_CHAPTER_COMPLETED
		)
		_refresh_status(campaign)
		return true

	campaign.completed_chapter_count = 4
	campaign.status = CampaignState.Status.COMPLETED
	campaign.campaign_completed_tick = state.simulation_tick
	campaign.hint_tier = 0
	state.record_observation_event(
		ObservationEvent.Type.CAMPAIGN_CHAPTER_COMPLETED
	)
	state.record_observation_event(
		ObservationEvent.Type.CAMPAIGN_SESSION_COMPLETED
	)
	return true


func create_snapshot(
	state: ColonyState,
	inference_action_pending: bool
) -> CampaignSnapshot:
	if state == null or state.campaign_state == null:
		return null
	var campaign: CampaignState = state.campaign_state
	return CampaignSnapshot.new(
		campaign.chapter,
		campaign.status,
		campaign.chapter_entered_tick,
		campaign.completed_chapter_count,
		campaign.incorrect_inference_attempts,
		campaign.hint_tier,
		campaign.campaign_completed_tick,
		campaign.status == CampaignState.Status.AWAITING_INFERENCE
			and not inference_action_pending,
		inference_action_pending,
		get_available_inference_ids(campaign),
		campaign.copy_evidence_ids(),
		campaign.copy_confirmed_inference_ids(),
		campaign.copy_unlocked_facility_type_ids()
	)


func has_valid_state(state: ColonyState) -> bool:
	if (
		not is_ready()
		or state == null
		or state.campaign_state == null
		or state.act1_state == null
	):
		return false
	var campaign: CampaignState = state.campaign_state
	if (
		campaign.chapter < CampaignState.Chapter.ACT1_FOUNDING
		or campaign.chapter
			> CampaignState.Chapter.ACT1_ENVIRONMENT_MANAGEMENT
		or campaign.status < CampaignState.Status.ACTIVE
		or campaign.status > CampaignState.Status.COMPLETED
		or campaign.chapter_entered_tick < 0
		or campaign.chapter_entered_tick > state.simulation_tick
		or campaign.completed_chapter_count < 0
		or campaign.completed_chapter_count > 4
		or campaign.incorrect_inference_attempts < 0
		or campaign.hint_tier < 0
		or campaign.hint_tier > MAX_HINT_TIER
		or campaign.incorrect_inference_attempts < campaign.hint_tier
		or state.act1_state.environment_stable_ticks < 0
		or state.act1_state.environment_stable_ticks
			> _habitat_config.act1_progression_config
				.environment_stable_ticks
	):
		return false
	var allowed_evidence: Array[StringName] = [
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
	]
	for evidence_id: StringName in campaign.collected_evidence_ids:
		if not allowed_evidence.has(evidence_id):
			return false
	var allowed_inferences: Array[StringName] = [
		CampaignState.INFERENCE_QUEEN_CARE,
		CampaignState.INFERENCE_WORKER_NUTRITION,
		CampaignState.INFERENCE_FORAGING_ROLES,
		CampaignState.INFERENCE_ENVIRONMENT_GRADIENT,
	]
	for inference_id: StringName in campaign.confirmed_inference_ids:
		if not allowed_inferences.has(inference_id):
			return false
	var allowed_facilities: Array[StringName] = [
		CampaignState.FACILITY_TEST_TUBE_NEST,
		CampaignState.FACILITY_LIGHT_COVER,
		CampaignState.FACILITY_MAGNIFIER,
		CampaignState.FACILITY_MICRO_FEEDING_PORT,
		CampaignState.FACILITY_SMALL_FORAGING_BOX,
		CampaignState.FACILITY_SUGAR_STATION,
		CampaignState.FACILITY_PROTEIN_DISH,
		CampaignState.FACILITY_WASTE_TRAY,
		CampaignState.FACILITY_SPARE_TEST_TUBE,
		CampaignState.FACILITY_HYDRATION_MODULE,
		CampaignState.FACILITY_CONNECTOR_FAMILY,
	]
	for facility_id: StringName in campaign.unlocked_facility_type_ids:
		if not allowed_facilities.has(facility_id):
			return false
	if not _evidence_matches_observation_cards(state, campaign):
		return false
	if not _chapter_unlocks_are_valid(campaign):
		return false
	match campaign.completed_chapter_count:
		0:
			return (
				campaign.chapter == CampaignState.Chapter.ACT1_FOUNDING
				and campaign.status == _expected_status(campaign)
				and campaign.campaign_completed_tick == -1
				and campaign.confirmed_inference_ids.is_empty()
				and campaign.unlocked_facility_type_ids.size() == 3
			)
		1:
			return (
				campaign.chapter
					== CampaignState.Chapter.ACT1_FIRST_WORKERS
				and campaign.status == _expected_status(campaign)
				and campaign.campaign_completed_tick == -1
				and campaign.confirmed_inference_ids.size() == 1
				and campaign.confirmed_inference_ids.has(
					CampaignState.INFERENCE_QUEEN_CARE
				)
				and campaign.unlocked_facility_type_ids.has(
					CampaignState.FACILITY_MICRO_FEEDING_PORT
				)
			)
		2:
			return (
				campaign.chapter
					== CampaignState.Chapter.ACT1_FORAGING_EXPANSION
				and campaign.status == _expected_status(campaign)
				and campaign.campaign_completed_tick == -1
				and campaign.confirmed_inference_ids.size() == 2
				and campaign.confirmed_inference_ids.has(
					CampaignState.INFERENCE_QUEEN_CARE
				)
				and campaign.confirmed_inference_ids.has(
					CampaignState.INFERENCE_WORKER_NUTRITION
				)
				and campaign.unlocked_facility_type_ids.has(
					CampaignState.FACILITY_SMALL_FORAGING_BOX
				)
			)
		3:
			return (
				campaign.chapter
					== CampaignState.Chapter.ACT1_ENVIRONMENT_MANAGEMENT
				and campaign.status == _expected_status(campaign)
				and campaign.campaign_completed_tick == -1
				and campaign.confirmed_inference_ids.size() == 3
				and campaign.confirmed_inference_ids.has(
					CampaignState.INFERENCE_FORAGING_ROLES
				)
			)
		4:
			return (
				campaign.chapter
					== CampaignState.Chapter.ACT1_ENVIRONMENT_MANAGEMENT
				and campaign.status == CampaignState.Status.COMPLETED
				and campaign.campaign_completed_tick >= 0
				and campaign.campaign_completed_tick
					<= state.simulation_tick
				and campaign.confirmed_inference_ids.size() == 4
				and campaign.confirmed_inference_ids.has(
					CampaignState.INFERENCE_ENVIRONMENT_GRADIENT
				)
			)
	return false


func get_available_inference_ids(
	campaign: CampaignState
) -> Array[StringName]:
	if campaign == null or campaign.status != CampaignState.Status.AWAITING_INFERENCE:
		return []
	if campaign.chapter == CampaignState.Chapter.ACT1_FOUNDING:
		return [
			CampaignState.INFERENCE_QUEEN_CARE,
			CampaignState.INFERENCE_QUEEN_CARE_RANDOM,
			CampaignState.INFERENCE_QUEEN_CARE_DIRECTED,
		]
	if campaign.chapter == CampaignState.Chapter.ACT1_FIRST_WORKERS:
		return [
			CampaignState.INFERENCE_WORKER_NUTRITION,
			CampaignState.INFERENCE_WORKER_NUTRITION_RANDOM,
			CampaignState.INFERENCE_WORKER_NUTRITION_DIRECTED,
		]
	if campaign.chapter == CampaignState.Chapter.ACT1_FORAGING_EXPANSION:
		return [
			CampaignState.INFERENCE_FORAGING_ROLES,
			CampaignState.INFERENCE_FORAGING_RANDOM,
			CampaignState.INFERENCE_FORAGING_DIRECTED,
		]
	return [
		CampaignState.INFERENCE_ENVIRONMENT_GRADIENT,
		CampaignState.INFERENCE_ENVIRONMENT_MAXIMUM,
		CampaignState.INFERENCE_GRADIENT_DIRECTED,
	]


func get_correct_inference_id(
	chapter: CampaignState.Chapter
) -> StringName:
	match chapter:
		CampaignState.Chapter.ACT1_FOUNDING:
			return CampaignState.INFERENCE_QUEEN_CARE
		CampaignState.Chapter.ACT1_FIRST_WORKERS:
			return CampaignState.INFERENCE_WORKER_NUTRITION
		CampaignState.Chapter.ACT1_FORAGING_EXPANSION:
			return CampaignState.INFERENCE_FORAGING_ROLES
	return CampaignState.INFERENCE_ENVIRONMENT_GRADIENT


func is_sugar_action_active(state: ColonyState) -> bool:
	return (
		state != null
		and state.campaign_state != null
		and state.campaign_state.chapter
			>= CampaignState.Chapter.ACT1_FIRST_WORKERS
		and state.campaign_state.unlocked_facility_type_ids.has(
			CampaignState.FACILITY_MICRO_FEEDING_PORT
		)
		and state.campaign_state.status != CampaignState.Status.COMPLETED
	)


func is_protein_action_active(state: ColonyState) -> bool:
	return (
		state != null
		and state.campaign_state != null
		and state.campaign_state.chapter
			>= CampaignState.Chapter.ACT1_FORAGING_EXPANSION
		and state.campaign_state.unlocked_facility_type_ids.has(
			CampaignState.FACILITY_PROTEIN_DISH
		)
		and state.campaign_state.status != CampaignState.Status.COMPLETED
	)


func _refresh_status(campaign: CampaignState) -> void:
	if campaign.status == CampaignState.Status.COMPLETED:
		return
	campaign.status = _expected_status(campaign)


func _expected_status(campaign: CampaignState) -> CampaignState.Status:
	if campaign.chapter == CampaignState.Chapter.ACT1_FOUNDING:
		return (
			CampaignState.Status.AWAITING_INFERENCE
			if (
				campaign.collected_evidence_ids.has(
					CampaignState.EVIDENCE_QUEEN_CARE
				)
				and campaign.collected_evidence_ids.has(
					CampaignState.EVIDENCE_FIRST_PUPA
				)
			)
			else CampaignState.Status.ACTIVE
		)
	var required: Array[StringName]
	match campaign.chapter:
		CampaignState.Chapter.ACT1_FIRST_WORKERS:
			required = [
				CampaignState.EVIDENCE_FIRST_WORKER,
				CampaignState.EVIDENCE_FIRST_WORKER_CARE,
				CampaignState.EVIDENCE_FIRST_NUTRIENT_EXCHANGE,
			]
		CampaignState.Chapter.ACT1_FORAGING_EXPANSION:
			required = [
				CampaignState.EVIDENCE_FORAGING_ZONE_SCOUTED,
				CampaignState.EVIDENCE_FORAGING_SUGAR_CYCLE,
				CampaignState.EVIDENCE_PROTEIN_CARE,
				CampaignState.EVIDENCE_WASTE_TRAY_CLEANED,
				CampaignState.EVIDENCE_SMALL_COLONY_STABLE,
			]
		_:
			required = [
				CampaignState.EVIDENCE_HYDRATION_RESPONSE,
				CampaignState.EVIDENCE_POLLUTION_AVOIDANCE,
				CampaignState.EVIDENCE_PARTIAL_MIGRATION,
				CampaignState.EVIDENCE_ENVIRONMENT_STABLE,
			]
	for evidence_id: StringName in required:
		if not campaign.collected_evidence_ids.has(evidence_id):
			return CampaignState.Status.ACTIVE
	return CampaignState.Status.AWAITING_INFERENCE


func _collect_foraging_expansion_evidence(
	state: ColonyState,
	campaign: CampaignState
) -> void:
	if _has_event_since(
		state,
		ObservationEvent.Type.ZONE_DISCOVERED,
		campaign.chapter_entered_tick
	):
		campaign.collect_evidence(
			CampaignState.EVIDENCE_FORAGING_ZONE_SCOUTED
		)
	if _has_event_since(
		state,
		ObservationEvent.Type.SUGAR_SHARED,
		campaign.chapter_entered_tick
	):
		campaign.collect_evidence(
			CampaignState.EVIDENCE_FORAGING_SUGAR_CYCLE
		)
	if _has_event_since(
		state,
		ObservationEvent.Type.BROOD_FED,
		campaign.chapter_entered_tick
	):
		campaign.collect_evidence(CampaignState.EVIDENCE_PROTEIN_CARE)
	if _has_event_since(
		state,
		ObservationEvent.Type.WASTE_TRAY_CLEANED,
		campaign.chapter_entered_tick
	):
		campaign.collect_evidence(
			CampaignState.EVIDENCE_WASTE_TRAY_CLEANED
		)
	var worker_count: int = 0
	for ant: AntModel in state.ants:
		if ant.life_stage == AntModel.LifeStage.WORKER:
			worker_count += 1
	if (
		worker_count
		>= _habitat_config.act1_progression_config
			.chapter_three_min_worker_count
	):
		campaign.collect_evidence(
			CampaignState.EVIDENCE_SMALL_COLONY_STABLE
		)


func _collect_environment_evidence(
	state: ColonyState,
	campaign: CampaignState
) -> void:
	if _has_comfortable_hydrated_zone(state):
		campaign.collect_evidence(
			CampaignState.EVIDENCE_HYDRATION_RESPONSE
		)
	for event: ObservationEvent in state._observation_events:
		if (
			event.tick < campaign.chapter_entered_tick
			or event.event_type
				!= ObservationEvent.Type.MIGRATION_MEMBER_DROPPED
		):
			continue
		campaign.collect_evidence(
			CampaignState.EVIDENCE_PARTIAL_MIGRATION
		)
		var source: HabitatZoneState = state.get_zone(
			event.source_zone_id
		)
		var target: HabitatZoneState = state.get_zone(
			event.target_zone_id
		)
		if (
			source != null
			and target != null
			and source.pollution - target.pollution
				>= _habitat_config.act1_progression_config
					.pollution_avoidance_min_contrast
		):
			campaign.collect_evidence(
				CampaignState.EVIDENCE_POLLUTION_AVOIDANCE
			)
	if (
		campaign.collected_evidence_ids.has(
			CampaignState.EVIDENCE_HYDRATION_RESPONSE
		)
		and campaign.collected_evidence_ids.has(
			CampaignState.EVIDENCE_POLLUTION_AVOIDANCE
		)
		and campaign.collected_evidence_ids.has(
			CampaignState.EVIDENCE_PARTIAL_MIGRATION
		)
		and _environment_is_stable(state)
	):
		state.act1_state.environment_stable_ticks = mini(
			_habitat_config.act1_progression_config
				.environment_stable_ticks,
			state.act1_state.environment_stable_ticks + 1
		)
	else:
		state.act1_state.environment_stable_ticks = 0
	if (
		state.act1_state.environment_stable_ticks
		>= _habitat_config.act1_progression_config
			.environment_stable_ticks
	):
		campaign.collect_evidence(
			CampaignState.EVIDENCE_ENVIRONMENT_STABLE
		)


func _has_comfortable_hydrated_zone(state: ColonyState) -> bool:
	if state.layout_state == null:
		return false
	var catalog: FacilityCatalogConfig = (
		_habitat_config.facility_catalog_config
	)
	var brood: BroodCareConfig = _brood_care_config
	for facility: FacilityState in (
		state.layout_state.get_facilities_in_stable_order()
	):
		var type_config: FacilityConfig = catalog.get_type(facility.type_id)
		if (
			not facility.available
			or type_config == null
			or type_config.effect_config == null
			or type_config.effect_config.kind
				!= FacilityEffectConfig.Kind.HYDRATION
		):
			continue
		var zone: HabitatZoneState = state.get_zone(facility.zone_id)
		if (
			zone != null
			and _zone_is_player_spare_tube(state, facility.zone_id)
			and zone.humidity >= brood.brood_humidity_min
			and zone.humidity <= brood.brood_humidity_max
		):
			return true
	return false


func _zone_is_player_spare_tube(
	state: ColonyState,
	zone_id: StringName
) -> bool:
	for facility: FacilityState in (
		state.layout_state.get_facilities_in_stable_order()
	):
		if (
			facility.type_id == CampaignState.FACILITY_TEST_TUBE_NEST
			and facility.player_removable
			and facility.available
			and facility.zone_id == zone_id
		):
			return true
	return false


func _environment_is_stable(state: ColonyState) -> bool:
	var brood: BroodCareConfig = _brood_care_config
	var environment: EnvironmentConfig = _habitat_config.environment_config
	for ant: AntModel in state.ants:
		if ant.life_stage == AntModel.LifeStage.WORKER:
			if (
				ant.waste_cleanup_task == null
				or ant.scout_task == null
				or ant.migration_task == null
				or ant.waste_cleanup_task.state
					!= WasteCleanupTaskModel.State.IDLE
				or ant.scout_task.state != ScoutTaskModel.State.IDLE
				or ant.migration_task.state
					!= MigrationTaskModel.State.IDLE
			):
				return false
			continue
		var zone: HabitatZoneState = state.get_zone(ant.zone_id)
		if (
			zone == null
			or zone.humidity < brood.brood_humidity_min
			or zone.humidity > brood.brood_humidity_max
			or zone.pollution > environment.brood_pollution_comfort_max
		):
			return false
	return true


func _has_event_since(
	state: ColonyState,
	event_type: ObservationEvent.Type,
	minimum_tick: int
) -> bool:
	for event: ObservationEvent in state._observation_events:
		if event.tick >= minimum_tick and event.event_type == event_type:
			return true
	return false


func _chapter_unlocks_are_valid(campaign: CampaignState) -> bool:
	var unlock_thresholds: Dictionary[StringName, int] = {
		CampaignState.FACILITY_MICRO_FEEDING_PORT: 1,
		CampaignState.FACILITY_SMALL_FORAGING_BOX: 2,
		CampaignState.FACILITY_SUGAR_STATION: 2,
		CampaignState.FACILITY_PROTEIN_DISH: 2,
		CampaignState.FACILITY_WASTE_TRAY: 2,
		CampaignState.FACILITY_SPARE_TEST_TUBE: 3,
		CampaignState.FACILITY_HYDRATION_MODULE: 3,
		CampaignState.FACILITY_CONNECTOR_FAMILY: 3,
	}
	for facility_id: StringName in unlock_thresholds:
		var should_be_unlocked: bool = (
			campaign.completed_chapter_count
			>= unlock_thresholds[facility_id]
		)
		if (
			campaign.unlocked_facility_type_ids.has(facility_id)
			!= should_be_unlocked
		):
			return false
	return true


func _evidence_matches_observation_cards(
	state: ColonyState,
	campaign: CampaignState
) -> bool:
	var care: FoundingCareConfig = _habitat_config.founding_care_config
	var pairs: Array[Array] = [
		[
			CampaignState.EVIDENCE_QUEEN_CARE,
			care.queen_care_observation_card_id,
		],
		[
			CampaignState.EVIDENCE_FIRST_PUPA,
			care.pupa_observation_card_id,
		],
		[
			CampaignState.EVIDENCE_FIRST_WORKER,
			care.first_worker_observation_card_id,
		],
		[
			CampaignState.EVIDENCE_FIRST_WORKER_CARE,
			care.worker_care_observation_card_id,
		],
		[
			CampaignState.EVIDENCE_FIRST_NUTRIENT_EXCHANGE,
			_habitat_config.foraging_observation_card_id,
		],
	]
	for pair: Array in pairs:
		if (
			campaign.collected_evidence_ids.has(pair[0])
			!= state.unlocked_observation_card_ids.has(pair[1])
		):
			return false
	return true
