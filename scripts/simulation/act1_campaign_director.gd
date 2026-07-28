class_name Act1CampaignDirector
extends RefCounted

const MAX_HINT_TIER: int = 3

var _habitat_config: HabitatScenarioConfig


func _init(habitat_config: HabitatScenarioConfig) -> void:
	_habitat_config = habitat_config


func is_ready() -> bool:
	return (
		_habitat_config != null
		and _habitat_config.is_act1_test_tube()
		and _habitat_config.founding_care_config != null
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

	campaign.completed_chapter_count = 2
	campaign.unlock_facility(CampaignState.FACILITY_SMALL_FORAGING_BOX)
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
		or campaign.chapter > CampaignState.Chapter.ACT1_FIRST_WORKERS
		or campaign.status < CampaignState.Status.ACTIVE
		or campaign.status > CampaignState.Status.COMPLETED
		or campaign.chapter_entered_tick < 0
		or campaign.chapter_entered_tick > state.simulation_tick
		or campaign.completed_chapter_count < 0
		or campaign.completed_chapter_count > 2
		or campaign.incorrect_inference_attempts < 0
		or campaign.hint_tier < 0
		or campaign.hint_tier > MAX_HINT_TIER
		or campaign.incorrect_inference_attempts < campaign.hint_tier
	):
		return false
	var allowed_evidence: Array[StringName] = [
		CampaignState.EVIDENCE_QUEEN_CARE,
		CampaignState.EVIDENCE_FIRST_PUPA,
		CampaignState.EVIDENCE_FIRST_WORKER,
		CampaignState.EVIDENCE_FIRST_WORKER_CARE,
		CampaignState.EVIDENCE_FIRST_NUTRIENT_EXCHANGE,
	]
	for evidence_id: StringName in campaign.collected_evidence_ids:
		if not allowed_evidence.has(evidence_id):
			return false
	var allowed_inferences: Array[StringName] = [
		CampaignState.INFERENCE_QUEEN_CARE,
		CampaignState.INFERENCE_WORKER_NUTRITION,
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
	]
	for facility_id: StringName in campaign.unlocked_facility_type_ids:
		if not allowed_facilities.has(facility_id):
			return false
	if not _evidence_matches_observation_cards(state, campaign):
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
					== CampaignState.Chapter.ACT1_FIRST_WORKERS
				and campaign.status == CampaignState.Status.COMPLETED
				and campaign.campaign_completed_tick >= 0
				and campaign.campaign_completed_tick
					<= state.simulation_tick
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
	return [
		CampaignState.INFERENCE_WORKER_NUTRITION,
		CampaignState.INFERENCE_WORKER_NUTRITION_RANDOM,
		CampaignState.INFERENCE_WORKER_NUTRITION_DIRECTED,
	]


func get_correct_inference_id(
	chapter: CampaignState.Chapter
) -> StringName:
	return (
		CampaignState.INFERENCE_QUEEN_CARE
		if chapter == CampaignState.Chapter.ACT1_FOUNDING
		else CampaignState.INFERENCE_WORKER_NUTRITION
	)


func is_sugar_action_active(state: ColonyState) -> bool:
	return (
		state != null
		and state.campaign_state != null
		and state.campaign_state.chapter
			== CampaignState.Chapter.ACT1_FIRST_WORKERS
		and state.campaign_state.unlocked_facility_type_ids.has(
			CampaignState.FACILITY_MICRO_FEEDING_PORT
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
	return (
		CampaignState.Status.AWAITING_INFERENCE
		if (
			campaign.collected_evidence_ids.has(
				CampaignState.EVIDENCE_FIRST_WORKER
			)
			and campaign.collected_evidence_ids.has(
				CampaignState.EVIDENCE_FIRST_WORKER_CARE
			)
			and campaign.collected_evidence_ids.has(
				CampaignState.EVIDENCE_FIRST_NUTRIENT_EXCHANGE
			)
		)
		else CampaignState.Status.ACTIVE
	)


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
