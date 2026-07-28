class_name SimulationStateCodec
extends RefCounted

const CURRENT_SCHEMA_ID: String = "r9.authority.v7"
const R8_SCHEMA_ID: String = "r8.authority.v6"
const R7_SCHEMA_ID: String = "r7.authority.v5"
const R6_SCHEMA_ID: String = "r6.authority.v4"
const R5_SCHEMA_ID: String = "r5.authority.v3"
const R4_SCHEMA_ID: String = "r4.authority.v2"
const PREVIOUS_SCHEMA_ID: String = "r2.authority.v1"
const LEGACY_SCHEMA_ID: String = "r2.authority.v0"


static func encode_simulation(simulation: ColonySimulation) -> Dictionary:
	if simulation == null or not simulation.is_ready():
		return {}
	var next_facility_id: int = 1
	var next_connection_id: int = 1
	if simulation._state.layout_state != null:
		next_facility_id = simulation._state.layout_state._next_facility_id
		next_connection_id = (
			simulation._state.layout_state._next_connection_id
		)
	return {
		"frozen_config_bundle": _encode_frozen_config(simulation),
		"next_ids": {
			"entity_id": simulation._state._next_entity_id,
			"observation_event_id":
				simulation._state._next_observation_event_id,
			"pending_command_sequence_id":
				simulation._next_pending_command_sequence_id,
			"facility_id": next_facility_id,
			"connection_id": next_connection_id,
		},
		"pending_commands": _encode_pending_commands(
			simulation._pending_commands
		),
		"state_payload": _encode_state(simulation._state),
	}


static func restore_simulation(
	frozen_config_bundle: Dictionary,
	next_ids: Dictionary,
	pending_commands: Array,
	state_payload: Dictionary
) -> Dictionary:
	var resource_result: Dictionary = _decode_frozen_resources(
		frozen_config_bundle
	)
	if not resource_result.get("ok", false):
		return resource_result

	var state_result: Dictionary = _decode_state(state_payload, next_ids)
	if not state_result.get("ok", false):
		return state_result
	var pending_result: Dictionary = _decode_pending_commands(
		pending_commands,
		int(next_ids.get("pending_command_sequence_id", -1))
	)
	if not pending_result.get("ok", false):
		return pending_result

	var simulation: ColonySimulation = ColonySimulation.new(
		resource_result["species_data"],
		resource_result["habitat_data"]
	)
	if not simulation.is_ready():
		return _failure(
			"Frozen configuration was rejected: %s"
			% simulation.get_configuration_error()
		)
	simulation._state = state_result["state"]
	simulation._pending_commands.assign(pending_result["commands"])
	simulation._next_pending_command_sequence_id = int(
		next_ids["pending_command_sequence_id"]
	)
	if not _has_valid_core_state(simulation):
		return _failure("Restored authoritative state is invalid")
	if not _has_valid_pending_commands(simulation):
		return _failure("Restored pending command queue is invalid")
	return {
		"ok": true,
		"error": "",
		"simulation": simulation,
	}


static func _encode_frozen_config(
	simulation: ColonySimulation
) -> Dictionary:
	var lifecycle: LifecycleConfig = simulation._lifecycle_config
	var brood_care: BroodCareConfig = simulation._brood_care_config
	var habitat: HabitatScenarioConfig = simulation._habitat_config
	return {
		"lifecycle": {
			"first_egg_delay_ticks": lifecycle.first_egg_delay_ticks,
			"egg_laying_interval_ticks":
				lifecycle.egg_laying_interval_ticks,
			"egg_duration_ticks": lifecycle.egg_duration_ticks,
			"larva_duration_ticks": lifecycle.larva_duration_ticks,
			"pupa_duration_ticks": lifecycle.pupa_duration_ticks,
			"max_first_generation_brood":
				lifecycle.max_first_generation_brood,
		},
		"brood_care": (
			null
			if brood_care == null
			else {
				"brood_humidity_min": brood_care.brood_humidity_min,
				"brood_humidity_max": brood_care.brood_humidity_max,
				"relocation_min_improvement":
					brood_care.relocation_min_improvement,
				"decision_interval_ticks":
					brood_care.decision_interval_ticks,
				"pickup_duration_ticks":
					brood_care.pickup_duration_ticks,
				"travel_duration_ticks":
					brood_care.travel_duration_ticks,
				"drop_duration_ticks": brood_care.drop_duration_ticks,
				"minimum_zone_dwell_ticks":
					brood_care.minimum_zone_dwell_ticks,
			}
		),
		"habitat": null if habitat == null else _encode_habitat(habitat),
	}


static func _encode_habitat(config: HabitatScenarioConfig) -> Dictionary:
	var zones: Array[Dictionary] = []
	for zone: HabitatZoneState in config.zones:
		zones.append(_encode_config_zone(
			zone,
			config.initial_zone_connections.get(zone.zone_id, [])
		))
	return {
		"scenario_id": String(config.scenario_id),
		"scenario_kind": config.scenario_kind,
		"zones": zones,
		"initial_worker_count": config.initial_worker_count,
		"initial_brood_count": config.initial_brood_count,
		"initial_brood_stage": config.initial_brood_stage,
		"initial_worker_zone_id": String(config.initial_worker_zone_id),
		"initial_brood_zone_id": String(config.initial_brood_zone_id),
		"humidity_adjustment_zone_id":
			String(config.humidity_adjustment_zone_id),
		"humidity_adjustment_amount":
			config.humidity_adjustment_amount,
		"observation_stable_ticks": config.observation_stable_ticks,
		"foraging_config": (
			null
			if config.foraging_config == null
			else {
				"discovery_delay_ticks":
					config.foraging_config.discovery_delay_ticks,
				"outbound_travel_duration_ticks":
					config.foraging_config.outbound_travel_duration_ticks,
				"collection_duration_ticks":
					config.foraging_config.collection_duration_ticks,
				"return_travel_duration_ticks":
					config.foraging_config.return_travel_duration_ticks,
				"sharing_duration_ticks":
					config.foraging_config.sharing_duration_ticks,
			}
		),
		"nest_zone_id": String(config.nest_zone_id),
		"sugar_placement_zone_id": String(config.sugar_placement_zone_id),
		"sugar_portions": config.sugar_portions,
		"foraging_observation_card_id":
			String(config.foraging_observation_card_id),
		"sequence_config": (
			null
			if config.sequence_config == null
			else {
				"first_worker_initial_pupa_age_ticks":
					config.sequence_config
						.first_worker_initial_pupa_age_ticks,
				"first_worker_observation_card_id":
					String(
						config.sequence_config
							.first_worker_observation_card_id
					),
				"brood_humidity_observation_card_id":
					String(
						config.sequence_config
							.brood_humidity_observation_card_id
					),
			}
		),
		"lifecycle_active": config.lifecycle_active,
		"nutrition_config": (
			null
			if config.nutrition_config == null
			else _encode_nutrition_config(config.nutrition_config)
		),
		"protein_placement_zone_id":
			String(config.protein_placement_zone_id),
		"protein_portions": config.protein_portions,
		"founding_care_config": (
			null
			if config.founding_care_config == null
			else _encode_founding_care_config(
				config.founding_care_config
			)
		),
		"facility_catalog_config": _encode_facility_catalog_config(
			config.facility_catalog_config
		),
		"environment_config": _encode_environment_config(
			config.environment_config
		),
		"colony_work_config": _encode_colony_work_config(
			config.colony_work_config
		),
	}


static func _encode_state(state: ColonyState) -> Dictionary:
	var ants: Array[Dictionary] = []
	for ant: AntModel in state.ants:
		ants.append(_encode_ant(ant))
	var zones: Array[Dictionary] = []
	for zone: HabitatZoneState in state.zones:
		zones.append(_encode_state_zone(zone))
	var sources: Array[Dictionary] = []
	for source: FoodSourceState in state.food_sources:
		sources.append({
			"entity_id": source.entity_id,
			"zone_id": String(source.zone_id),
			"remaining_portions": source.remaining_portions,
			"food_type": source.food_type,
			"available": source.available,
		})
	var events: Array[Dictionary] = []
	for event: ObservationEvent in state._observation_events:
		events.append({
			"event_id": event.event_id,
			"tick": event.tick,
			"event_type": event.event_type,
			"actor_entity_id": event.actor_entity_id,
			"subject_entity_id": event.subject_entity_id,
			"source_zone_id": String(event.source_zone_id),
			"target_zone_id": String(event.target_zone_id),
		})
	var progress: Variant = null
	if state.scenario_progress != null:
		progress = {
			"phase": state.scenario_progress.phase,
			"phase_entered_tick":
				state.scenario_progress.phase_entered_tick,
			"first_worker_entity_id":
				state.scenario_progress.first_worker_entity_id,
			"first_worker_emerged_tick":
				state.scenario_progress.first_worker_emerged_tick,
			"humidity_observation_completed_tick":
				state.scenario_progress
					.humidity_observation_completed_tick,
			"sugar_observation_completed_tick":
				state.scenario_progress.sugar_observation_completed_tick,
		}
	var campaign: Variant = null
	if state.campaign_state != null:
		campaign = _encode_campaign(state.campaign_state)
	var nutrition: Variant = null
	if state.nutrition_state != null:
		nutrition = _encode_nutrition_state(state.nutrition_state)
	var act1: Variant = null
	if state.act1_state != null:
		act1 = _encode_act1_state(state.act1_state)
	var colony_work: Variant = null
	if state.colony_work_state != null:
		colony_work = _encode_colony_work_state(state.colony_work_state)
	return {
		"simulation_tick": state.simulation_tick,
		"queen": {
			"entity_id": state.queen.entity_id,
			"laid_egg_count": state.queen.laid_egg_count,
			"zone_id": String(state.queen.zone_id),
			"zone_entered_tick": state.queen.zone_entered_tick,
		},
		"ants": ants,
		"zones": zones,
		"food_sources": sources,
		"humidity_adjustment_count": state.humidity_adjustment_count,
		"water_action_unlocked": state.water_action_unlocked,
		"observation_stable_ticks": state.observation_stable_ticks,
		"brood_humidity_observation_unlocked":
			state.brood_humidity_observation_unlocked,
		"shared_sugar_portions": state.shared_sugar_portions,
		"total_sugar_portions_placed":
			state.total_sugar_portions_placed,
		"unlocked_observation_card_ids":
			_strings_from_names(
				state.copy_unlocked_observation_card_ids()
			),
		"scenario_progress": progress,
		"campaign": campaign,
		"nutrition": nutrition,
		"act1": act1,
		"layout": _encode_layout_state(state.layout_state),
		"colony_work": colony_work,
		"observation_events": events,
	}


static func _encode_campaign(campaign: CampaignState) -> Dictionary:
	return {
		"chapter": campaign.chapter,
		"status": campaign.status,
		"chapter_entered_tick": campaign.chapter_entered_tick,
		"completed_chapter_count": campaign.completed_chapter_count,
		"incorrect_inference_attempts":
			campaign.incorrect_inference_attempts,
		"hint_tier": campaign.hint_tier,
		"campaign_completed_tick": campaign.campaign_completed_tick,
		"collected_evidence_ids": _strings_from_names(
			campaign.copy_evidence_ids()
		),
		"confirmed_inference_ids": _strings_from_names(
			campaign.copy_confirmed_inference_ids()
		),
		"unlocked_facility_type_ids": _strings_from_names(
			campaign.copy_unlocked_facility_type_ids()
		),
	}


static func _encode_nutrition_config(
	config: NutritionConfig
) -> Dictionary:
	return {
		"initial_sugar_reserve_portions":
			config.initial_sugar_reserve_portions,
		"initial_protein_reserve_portions":
			config.initial_protein_reserve_portions,
		"sugar_activity_ticks_per_portion":
			config.sugar_activity_ticks_per_portion,
		"sugar_shortage_step_interval_ticks":
			config.sugar_shortage_step_interval_ticks,
		"protein_growth_ticks_per_portion":
			config.protein_growth_ticks_per_portion,
		"feeding_decision_interval_ticks":
			config.feeding_decision_interval_ticks,
		"feeding_travel_duration_ticks":
			config.feeding_travel_duration_ticks,
		"feeding_duration_ticks": config.feeding_duration_ticks,
	}


static func _encode_founding_care_config(
	config: FoundingCareConfig
) -> Dictionary:
	return {
		"rest_duration_ticks": config.rest_duration_ticks,
		"gathering_duration_ticks": config.gathering_duration_ticks,
		"brood_care_duration_ticks": config.brood_care_duration_ticks,
		"pupa_observation_ticks": config.pupa_observation_ticks,
		"first_worker_initial_pupa_age_ticks":
			config.first_worker_initial_pupa_age_ticks,
		"queen_care_observation_card_id":
			String(config.queen_care_observation_card_id),
		"pupa_observation_card_id":
			String(config.pupa_observation_card_id),
		"first_worker_observation_card_id":
			String(config.first_worker_observation_card_id),
		"worker_care_observation_card_id":
			String(config.worker_care_observation_card_id),
	}


static func _encode_facility_catalog_config(
	catalog: FacilityCatalogConfig
) -> Variant:
	if catalog == null:
		return null
	var types: Array[Dictionary] = []
	for type_id: StringName in catalog.copy_type_ids():
		var config: FacilityConfig = catalog.get_type(type_id)
		var ports: Array[Dictionary] = []
		for port: FacilityPortConfig in config.ports:
			ports.append({
				"local_cell": [port.local_cell.x, port.local_cell.y],
				"direction": port.direction,
				"connection_kind": String(port.connection_kind),
			})
		types.append({
			"type_id": String(config.type_id),
			"unlock_type_id": String(config.unlock_type_id),
			"footprint": [config.footprint.x, config.footprint.y],
			"allowed_orientations": config.allowed_orientations.duplicate(),
			"ports": ports,
			"placement_layer": config.placement_layer,
			"requires_connection": config.requires_connection,
			"player_removable": config.player_removable,
			"effect_config": _encode_facility_effect_config(
				config.effect_config
			),
		})
	var initial_facilities: Array[Dictionary] = []
	for initial: InitialFacilityConfig in catalog.initial_facilities:
		initial_facilities.append({
			"facility_id": initial.facility_id,
			"type_id": String(initial.type_id),
			"slot": [initial.slot.x, initial.slot.y],
			"orientation": initial.orientation,
			"zone_id": String(initial.zone_id),
			"available": initial.available,
			"player_removable": initial.player_removable,
		})
	var supplies: Array[Dictionary] = []
	for type_id: StringName in catalog.copy_type_ids():
		if not catalog.initial_supply_counts.has(type_id):
			continue
		supplies.append({
			"type_id": String(type_id),
			"available_count": catalog.initial_supply_counts[type_id],
		})
	return {
		"grid_size": [catalog.grid_size.x, catalog.grid_size.y],
		"facility_types": types,
		"initial_facilities": initial_facilities,
		"initial_supplies": supplies,
	}


static func _encode_environment_config(
	config: EnvironmentConfig
) -> Variant:
	if config == null:
		return null
	return {
		"pollution_diffusion_per_tick":
			config.pollution_diffusion_per_tick,
		"brood_pollution_comfort_max":
			config.brood_pollution_comfort_max,
		"brood_pollution_penalty_weight":
			config.brood_pollution_penalty_weight,
		"queen_care_light_max": config.queen_care_light_max,
	}


static func _encode_colony_work_config(
	config: ColonyWorkConfig
) -> Variant:
	if config == null:
		return null
	return {
		"waste_source_pollution_min":
			config.waste_source_pollution_min,
		"waste_batch_amount": config.waste_batch_amount,
		"waste_decision_interval_ticks":
			config.waste_decision_interval_ticks,
		"waste_travel_ticks_per_connection":
			config.waste_travel_ticks_per_connection,
		"waste_pickup_duration_ticks":
			config.waste_pickup_duration_ticks,
		"waste_drop_duration_ticks":
			config.waste_drop_duration_ticks,
		"scout_decision_interval_ticks":
			config.scout_decision_interval_ticks,
		"scout_travel_ticks_per_connection":
			config.scout_travel_ticks_per_connection,
		"scout_observe_duration_ticks":
			config.scout_observe_duration_ticks,
		"migration_min_improvement":
			config.migration_min_improvement,
		"migration_pollution_max": config.migration_pollution_max,
		"migration_target_stable_ticks":
			config.migration_target_stable_ticks,
		"migration_minimum_zone_dwell_ticks":
			config.migration_minimum_zone_dwell_ticks,
		"migration_decision_interval_ticks":
			config.migration_decision_interval_ticks,
		"migration_travel_ticks_per_connection":
			config.migration_travel_ticks_per_connection,
		"migration_pickup_duration_ticks":
			config.migration_pickup_duration_ticks,
		"migration_drop_duration_ticks":
			config.migration_drop_duration_ticks,
	}


static func _encode_colony_work_state(
	work: ColonyWorkState
) -> Dictionary:
	return {
		"migration_candidate_zone_id":
			String(work.migration_candidate_zone_id),
		"migration_candidate_stable_ticks":
			work.migration_candidate_stable_ticks,
		"migration_target_zone_id":
			String(work.migration_target_zone_id),
		"completed_migration_count": work.completed_migration_count,
		"scouted_zone_count": work.scouted_zone_count,
		"delivered_waste_batch_count":
			work.delivered_waste_batch_count,
		"cleaned_waste_tray_count": work.cleaned_waste_tray_count,
	}


static func _encode_facility_effect_config(
	config: FacilityEffectConfig
) -> Dictionary:
	var result: Dictionary = {"kind": config.kind}
	match config.kind:
		FacilityEffectConfig.Kind.HABITAT_ZONE:
			result["initial_humidity"] = config.initial_humidity
			result["initial_light_exposure"] = (
				config.initial_light_exposure
			)
			result["initial_pollution"] = config.initial_pollution
			result["pollution_per_tick"] = config.pollution_per_tick
		FacilityEffectConfig.Kind.HYDRATION:
			result["target_humidity"] = config.target_humidity
			result["humidity_per_tick"] = config.humidity_per_tick
		FacilityEffectConfig.Kind.FOOD_STATION:
			result["accepts_sugar"] = config.accepts_sugar
			result["accepts_protein"] = config.accepts_protein
			result["portion_capacity"] = config.portion_capacity
			result["host_zone_required"] = config.host_zone_required
		FacilityEffectConfig.Kind.WASTE_TRAY:
			result["capacity"] = config.waste_capacity
			result["capture_per_tick"] = config.waste_capture_per_tick
		FacilityEffectConfig.Kind.CONNECTOR:
			result["gated"] = config.connector_gated
		FacilityEffectConfig.Kind.LIGHT_COVER:
			result["target_light_exposure"] = (
				config.target_light_exposure
			)
			result["transition_per_tick"] = (
				config.light_transition_per_tick
			)
	return result


static func _encode_nutrition_state(
	nutrition: ColonyNutritionState
) -> Dictionary:
	return {
		"sugar_reserve_portions": nutrition.sugar_reserve_portions,
		"protein_reserve_portions": nutrition.protein_reserve_portions,
		"sugar_activity_ticks_remaining":
			nutrition.sugar_activity_ticks_remaining,
		"total_sugar_portions_supplied":
			nutrition.total_sugar_portions_supplied,
		"total_protein_portions_supplied":
			nutrition.total_protein_portions_supplied,
		"total_sugar_portions_consumed":
			nutrition.total_sugar_portions_consumed,
		"total_protein_portions_consumed":
			nutrition.total_protein_portions_consumed,
		"total_protein_portions_placed":
			nutrition.total_protein_portions_placed,
		"delivered_protein_portions":
			nutrition.delivered_protein_portions,
		"completed_feeding_count": nutrition.completed_feeding_count,
	}


static func _encode_act1_state(act1: Act1State) -> Dictionary:
	return {
		"light_cover_applied": act1.light_cover_applied,
		"light_cover_action_count": act1.light_cover_action_count,
		"queen_care_state": act1.queen_care_state,
		"queen_care_elapsed_ticks": act1.queen_care_elapsed_ticks,
		"queen_care_target_brood_id":
			act1.queen_care_target_brood_id,
		"completed_queen_care_count":
			act1.completed_queen_care_count,
		"pupa_stable_ticks": act1.pupa_stable_ticks,
		"first_worker_entity_id": act1.first_worker_entity_id,
		"first_worker_emerged_tick": act1.first_worker_emerged_tick,
		"first_worker_care_recorded":
			act1.first_worker_care_recorded,
	}


static func _encode_ant(ant: AntModel) -> Dictionary:
	var worker_task: Variant = null
	if ant.worker_task != null:
		worker_task = {
			"state": ant.worker_task.state,
			"origin_zone_id": String(ant.worker_task.origin_zone_id),
			"target_brood_id": ant.worker_task.target_brood_id,
			"target_zone_id": String(ant.worker_task.target_zone_id),
			"carried_brood_id": ant.worker_task.carried_brood_id,
			"elapsed_ticks": ant.worker_task.elapsed_ticks,
			"duration_ticks": ant.worker_task.duration_ticks,
			"next_decision_tick": ant.worker_task.next_decision_tick,
		}
	var foraging_task: Variant = null
	if ant.foraging_task != null:
		foraging_task = {
			"state": ant.foraging_task.state,
			"target_food_source_id":
				ant.foraging_task.target_food_source_id,
			"origin_zone_id": String(ant.foraging_task.origin_zone_id),
			"target_zone_id": String(ant.foraging_task.target_zone_id),
			"nest_zone_id": String(ant.foraging_task.nest_zone_id),
			"route_zone_ids":
				_strings_from_names(ant.foraging_task.route_zone_ids),
			"route_cache_key": ant.foraging_task.route_cache_key,
			"carried_portions": ant.foraging_task.carried_portions,
			"elapsed_ticks": ant.foraging_task.elapsed_ticks,
			"duration_ticks": ant.foraging_task.duration_ticks,
		}
	var feeding_task: Variant = null
	if ant.feeding_task != null:
		feeding_task = {
			"state": ant.feeding_task.state,
			"target_brood_id": ant.feeding_task.target_brood_id,
			"origin_zone_id": String(ant.feeding_task.origin_zone_id),
			"target_zone_id": String(ant.feeding_task.target_zone_id),
			"route_zone_ids":
				_strings_from_names(ant.feeding_task.route_zone_ids),
			"elapsed_ticks": ant.feeding_task.elapsed_ticks,
			"duration_ticks": ant.feeding_task.duration_ticks,
			"next_decision_tick": ant.feeding_task.next_decision_tick,
		}
	var waste_cleanup_task: Variant = null
	if ant.waste_cleanup_task != null:
		waste_cleanup_task = _encode_waste_cleanup_task(
			ant.waste_cleanup_task
		)
	var scout_task: Variant = null
	if ant.scout_task != null:
		scout_task = _encode_scout_task(ant.scout_task)
	var migration_task: Variant = null
	if ant.migration_task != null:
		migration_task = _encode_migration_task(ant.migration_task)
	return {
		"entity_id": ant.entity_id,
		"life_stage": ant.life_stage,
		"total_age_ticks": ant.total_age_ticks,
		"stage_age_ticks": ant.stage_age_ticks,
		"zone_id": String(ant.zone_id),
		"zone_entered_tick": ant.zone_entered_tick,
		"protein_supported_growth_ticks":
			ant.protein_supported_growth_ticks,
		"worker_task": worker_task,
		"foraging_task": foraging_task,
		"feeding_task": feeding_task,
		"waste_cleanup_task": waste_cleanup_task,
		"scout_task": scout_task,
		"migration_task": migration_task,
	}


static func _encode_waste_cleanup_task(
	task: WasteCleanupTaskModel
) -> Dictionary:
	return {
		"state": task.state,
		"origin_zone_id": String(task.origin_zone_id),
		"source_zone_id": String(task.source_zone_id),
		"target_tray_facility_id": task.target_tray_facility_id,
		"target_zone_id": String(task.target_zone_id),
		"route_zone_ids": _strings_from_names(task.route_zone_ids),
		"reserved_amount": task.reserved_amount,
		"carried_amount": task.carried_amount,
		"elapsed_ticks": task.elapsed_ticks,
		"duration_ticks": task.duration_ticks,
		"next_decision_tick": task.next_decision_tick,
	}


static func _encode_scout_task(task: ScoutTaskModel) -> Dictionary:
	return {
		"state": task.state,
		"origin_zone_id": String(task.origin_zone_id),
		"target_zone_id": String(task.target_zone_id),
		"route_zone_ids": _strings_from_names(task.route_zone_ids),
		"elapsed_ticks": task.elapsed_ticks,
		"duration_ticks": task.duration_ticks,
		"next_decision_tick": task.next_decision_tick,
	}


static func _encode_migration_task(
	task: MigrationTaskModel
) -> Dictionary:
	return {
		"state": task.state,
		"origin_zone_id": String(task.origin_zone_id),
		"member_origin_zone_id": String(task.member_origin_zone_id),
		"target_entity_id": task.target_entity_id,
		"target_zone_id": String(task.target_zone_id),
		"carried_entity_id": task.carried_entity_id,
		"route_zone_ids": _strings_from_names(task.route_zone_ids),
		"returning_to_origin": task.returning_to_origin,
		"elapsed_ticks": task.elapsed_ticks,
		"duration_ticks": task.duration_ticks,
		"next_decision_tick": task.next_decision_tick,
	}


static func _encode_config_zone(
	zone: HabitatZoneState,
	connected_zone_ids: Array
) -> Dictionary:
	return {
		"zone_id": String(zone.zone_id),
		"humidity": zone.humidity,
		"light_exposure": zone.light_exposure,
		"pollution": zone.pollution,
		"connected_zone_ids":
			_strings_from_names(connected_zone_ids),
		"available": zone.available,
		"initially_discovered": zone.discovered,
	}


static func _encode_state_zone(zone: HabitatZoneState) -> Dictionary:
	return {
		"zone_id": String(zone.zone_id),
		"humidity": zone.humidity,
		"light_exposure": zone.light_exposure,
		"pollution": zone.pollution,
		"available": zone.available,
		"discovered": zone.discovered,
		"discovered_tick": zone.discovered_tick,
	}


static func _encode_layout_state(layout: HabitatLayoutState) -> Variant:
	if layout == null:
		return null
	var facilities: Array[Dictionary] = []
	for facility: FacilityState in layout.get_facilities_in_stable_order():
		facilities.append({
			"facility_id": facility.facility_id,
			"type_id": String(facility.type_id),
			"slot": [facility.slot.x, facility.slot.y],
			"orientation": facility.orientation,
			"zone_id": String(facility.zone_id),
			"available": facility.available,
			"player_removable": facility.player_removable,
			"waste_stored": facility.waste_stored,
		})
	var connections: Array[Dictionary] = []
	for connection: HabitatConnectionState in (
		layout.get_connections_in_stable_order()
	):
		connections.append({
			"connection_id": connection.connection_id,
			"first_zone_id": String(connection.first_zone_id),
			"second_zone_id": String(connection.second_zone_id),
			"gated": connection.gated,
			"open": connection.open,
			"owner_facility_id": connection.owner_facility_id,
		})
	var supplies: Array[Dictionary] = []
	var supply_ids: Array[StringName] = []
	for type_id: StringName in layout.supply.remaining_by_type:
		supply_ids.append(type_id)
	supply_ids.sort_custom(
		func(first: StringName, second: StringName) -> bool:
			return String(first) < String(second)
	)
	for type_id: StringName in supply_ids:
		supplies.append({
			"type_id": String(type_id),
			"remaining_count": layout.supply.get_remaining(type_id),
		})
	return {
		"grid_size": [layout.grid_size.x, layout.grid_size.y],
		"revision": layout.revision,
		"facilities": facilities,
		"connections": connections,
		"supplies": supplies,
	}


static func _encode_pending_commands(
	commands: Array[PendingSimulationCommand]
) -> Array[Dictionary]:
	var encoded: Array[Dictionary] = []
	for command: PendingSimulationCommand in commands:
		encoded.append({
			"sequence_id": command.sequence_id,
			"command_type": command.command_type,
			"argument_id": String(command.argument_id),
			"argument_entity_id": command.argument_entity_id,
			"argument_slot": [
				command.argument_slot.x,
				command.argument_slot.y,
			],
			"argument_orientation": command.argument_orientation,
			"argument_flag": command.argument_flag,
		})
	return encoded


static func _decode_frozen_resources(bundle: Dictionary) -> Dictionary:
	if not _has_exact_keys(
		bundle,
		["lifecycle", "brood_care", "habitat"]
	):
		return _failure("Frozen configuration has unexpected fields")
	var lifecycle: Variant = bundle["lifecycle"]
	if not _is_dictionary_with_keys(
		lifecycle,
		[
			"first_egg_delay_ticks",
			"egg_laying_interval_ticks",
			"egg_duration_ticks",
			"larva_duration_ticks",
			"pupa_duration_ticks",
			"max_first_generation_brood",
		]
	):
		return _failure("Lifecycle configuration is invalid")
	for key: String in lifecycle:
		if not _is_integral_number(lifecycle[key]):
			return _failure("Lifecycle configuration contains a non-integer")

	var species: SpeciesData = SpeciesData.new()
	species.species_id = &"saved_species"
	species.data_status = &"prototype_pacing_fixture"
	species.scientifically_validated = false
	species.first_egg_delay_ticks = int(lifecycle["first_egg_delay_ticks"])
	species.egg_laying_interval_ticks = int(
		lifecycle["egg_laying_interval_ticks"]
	)
	species.egg_duration_ticks = int(lifecycle["egg_duration_ticks"])
	species.larva_duration_ticks = int(lifecycle["larva_duration_ticks"])
	species.pupa_duration_ticks = int(lifecycle["pupa_duration_ticks"])
	species.max_first_generation_brood = int(
		lifecycle["max_first_generation_brood"]
	)
	var brood_care: Variant = bundle["brood_care"]
	if brood_care != null:
		var brood_result: Dictionary = _apply_brood_config(
			species,
			brood_care
		)
		if not brood_result.get("ok", false):
			return brood_result
	if not species.is_lifecycle_valid():
		return _failure("Frozen lifecycle configuration is not valid")

	var habitat_data: HabitatScenarioData
	if bundle["habitat"] != null:
		if brood_care == null or not species.is_brood_care_valid():
			return _failure("Habitat save requires brood-care configuration")
		var habitat_result: Dictionary = _decode_habitat_data(
			bundle["habitat"]
		)
		if not habitat_result.get("ok", false):
			return habitat_result
		habitat_data = habitat_result["habitat_data"]
	return {
		"ok": true,
		"error": "",
		"species_data": species,
		"habitat_data": habitat_data,
	}


static func _apply_brood_config(
	species: SpeciesData,
	value: Variant
) -> Dictionary:
	var keys: Array[String] = [
		"brood_humidity_min",
		"brood_humidity_max",
		"relocation_min_improvement",
		"decision_interval_ticks",
		"pickup_duration_ticks",
		"travel_duration_ticks",
		"drop_duration_ticks",
		"minimum_zone_dwell_ticks",
	]
	if not _is_dictionary_with_keys(value, keys):
		return _failure("Brood-care configuration is invalid")
	for float_key: String in [
		"brood_humidity_min",
		"brood_humidity_max",
		"relocation_min_improvement",
	]:
		if not _is_finite_number(value[float_key]):
			return _failure("Brood-care configuration contains non-finite data")
	for int_key: String in [
		"decision_interval_ticks",
		"pickup_duration_ticks",
		"travel_duration_ticks",
		"drop_duration_ticks",
		"minimum_zone_dwell_ticks",
	]:
		if not _is_integral_number(value[int_key]):
			return _failure("Brood-care configuration contains a non-integer")
	species.brood_humidity_min = float(value["brood_humidity_min"])
	species.brood_humidity_max = float(value["brood_humidity_max"])
	species.relocation_min_improvement = float(
		value["relocation_min_improvement"]
	)
	species.decision_interval_ticks = int(value["decision_interval_ticks"])
	species.pickup_duration_ticks = int(value["pickup_duration_ticks"])
	species.travel_duration_ticks = int(value["travel_duration_ticks"])
	species.drop_duration_ticks = int(value["drop_duration_ticks"])
	species.minimum_zone_dwell_ticks = int(
		value["minimum_zone_dwell_ticks"]
	)
	if not species.is_brood_care_valid():
		return _failure("Frozen brood-care configuration is not valid")
	return {"ok": true, "error": ""}


static func _decode_habitat_data(value: Variant) -> Dictionary:
	var keys: Array[String] = [
		"scenario_id",
		"scenario_kind",
		"zones",
		"initial_worker_count",
		"initial_brood_count",
		"initial_brood_stage",
		"initial_worker_zone_id",
		"initial_brood_zone_id",
		"humidity_adjustment_zone_id",
		"humidity_adjustment_amount",
		"observation_stable_ticks",
		"foraging_config",
		"nest_zone_id",
		"sugar_placement_zone_id",
		"sugar_portions",
		"foraging_observation_card_id",
		"sequence_config",
		"lifecycle_active",
		"nutrition_config",
		"protein_placement_zone_id",
		"protein_portions",
		"founding_care_config",
		"facility_catalog_config",
		"environment_config",
		"colony_work_config",
	]
	if not _is_dictionary_with_keys(value, keys):
		return _failure("Habitat configuration is invalid")
	for key: String in [
		"scenario_id",
		"initial_worker_zone_id",
		"initial_brood_zone_id",
		"humidity_adjustment_zone_id",
		"nest_zone_id",
		"sugar_placement_zone_id",
		"foraging_observation_card_id",
		"protein_placement_zone_id",
	]:
		if typeof(value[key]) != TYPE_STRING:
			return _failure("Habitat configuration contains a non-string ID")
	for key: String in [
		"scenario_kind",
		"initial_worker_count",
		"initial_brood_count",
		"initial_brood_stage",
		"observation_stable_ticks",
		"sugar_portions",
		"protein_portions",
	]:
		if not _is_integral_number(value[key]):
			return _failure("Habitat configuration contains a non-integer")
	if (
		not _is_finite_number(value["humidity_adjustment_amount"])
		or typeof(value["zones"]) != TYPE_ARRAY
		or typeof(value["lifecycle_active"]) != TYPE_BOOL
	):
		return _failure("Habitat configuration contains invalid numeric data")

	var habitat: HabitatScenarioData = HabitatScenarioData.new()
	habitat.scenario_id = StringName(value["scenario_id"])
	habitat.scenario_kind = int(value["scenario_kind"])
	habitat.data_status = &"prototype_pacing_fixture"
	habitat.scientifically_validated = false
	habitat.initial_worker_count = int(value["initial_worker_count"])
	habitat.initial_brood_count = int(value["initial_brood_count"])
	habitat.initial_brood_stage = int(value["initial_brood_stage"])
	habitat.initial_worker_zone_id = StringName(
		value["initial_worker_zone_id"]
	)
	habitat.initial_brood_zone_id = StringName(
		value["initial_brood_zone_id"]
	)
	habitat.humidity_adjustment_zone_id = StringName(
		value["humidity_adjustment_zone_id"]
	)
	habitat.humidity_adjustment_amount = float(
		value["humidity_adjustment_amount"]
	)
	habitat.observation_stable_ticks = int(
		value["observation_stable_ticks"]
	)
	habitat.nest_zone_id = StringName(value["nest_zone_id"])
	habitat.sugar_placement_zone_id = StringName(
		value["sugar_placement_zone_id"]
	)
	habitat.sugar_portions = int(value["sugar_portions"])
	habitat.foraging_observation_card_id = StringName(
		value["foraging_observation_card_id"]
	)
	habitat.lifecycle_active = bool(value["lifecycle_active"])
	habitat.protein_placement_zone_id = StringName(
		value["protein_placement_zone_id"]
	)
	habitat.protein_portions = int(value["protein_portions"])
	for zone_value: Variant in value["zones"]:
		var zone_result: Dictionary = _decode_zone_data(zone_value)
		if not zone_result.get("ok", false):
			return zone_result
		habitat.zones.append(zone_result["zone_data"])
	var foraging_result: Dictionary = _decode_foraging_data(
		value["foraging_config"]
	)
	if not foraging_result.get("ok", false):
		return foraging_result
	habitat.foraging_data = foraging_result["foraging_data"]
	var sequence_result: Dictionary = _decode_sequence_data(
		value["sequence_config"]
	)
	if not sequence_result.get("ok", false):
		return sequence_result
	habitat.sequence_data = sequence_result["sequence_data"]
	var nutrition_result: Dictionary = _decode_nutrition_data(
		value["nutrition_config"]
	)
	if not nutrition_result.get("ok", false):
		return nutrition_result
	habitat.nutrition_data = nutrition_result["nutrition_data"]
	var founding_result: Dictionary = _decode_founding_care_data(
		value["founding_care_config"]
	)
	if not founding_result.get("ok", false):
		return founding_result
	habitat.founding_care_data = founding_result["founding_care_data"]
	var catalog_result: Dictionary = _decode_facility_catalog_data(
		value["facility_catalog_config"]
	)
	if not catalog_result.get("ok", false):
		return catalog_result
	habitat.facility_catalog_data = catalog_result["catalog_data"]
	var environment_result: Dictionary = _decode_environment_data(
		value["environment_config"]
	)
	if not environment_result.get("ok", false):
		return environment_result
	habitat.environment_data = environment_result["environment_data"]
	var work_result: Dictionary = _decode_colony_work_data(
		value["colony_work_config"]
	)
	if not work_result.get("ok", false):
		return work_result
	habitat.colony_work_data = work_result["colony_work_data"]
	if not habitat.is_valid():
		return _failure("Frozen habitat configuration is not valid")
	return {"ok": true, "error": "", "habitat_data": habitat}


static func _decode_zone_data(value: Variant) -> Dictionary:
	if not _is_dictionary_with_keys(
		value,
		[
			"zone_id",
			"humidity",
			"light_exposure",
			"pollution",
			"connected_zone_ids",
			"available",
			"initially_discovered",
		]
	):
		return _failure("Zone configuration is invalid")
	if (
		typeof(value["zone_id"]) != TYPE_STRING
		or not _is_finite_number(value["humidity"])
		or not _is_finite_number(value["light_exposure"])
		or not _is_finite_number(value["pollution"])
		or typeof(value["connected_zone_ids"]) != TYPE_ARRAY
		or typeof(value["available"]) != TYPE_BOOL
		or typeof(value["initially_discovered"]) != TYPE_BOOL
	):
		return _failure("Zone configuration has an invalid value")
	var connections_result: Dictionary = _decode_string_names(
		value["connected_zone_ids"]
	)
	if not connections_result.get("ok", false):
		return connections_result
	var zone: HabitatZoneData = HabitatZoneData.new()
	zone.zone_id = StringName(value["zone_id"])
	zone.initial_humidity = float(value["humidity"])
	zone.initial_light_exposure = float(value["light_exposure"])
	zone.initial_pollution = float(value["pollution"])
	zone.connected_zone_ids.assign(connections_result["values"])
	zone.available = bool(value["available"])
	zone.initially_discovered = bool(value["initially_discovered"])
	if not zone.is_valid():
		return _failure("Frozen zone configuration is not valid")
	return {"ok": true, "error": "", "zone_data": zone}


static func _decode_environment_data(value: Variant) -> Dictionary:
	if value == null:
		return {"ok": true, "error": "", "environment_data": null}
	var keys: Array[String] = [
		"pollution_diffusion_per_tick",
		"brood_pollution_comfort_max",
		"brood_pollution_penalty_weight",
		"queen_care_light_max",
	]
	if not _is_dictionary_with_keys(value, keys):
		return _failure("Environment configuration is invalid")
	for key: String in keys:
		if not _is_finite_number(value[key]):
			return _failure("Environment configuration is non-finite")
	var data: EnvironmentData = EnvironmentData.new()
	data.data_status = &"prototype_pacing_fixture"
	data.scientifically_validated = false
	data.pollution_diffusion_per_tick = float(
		value["pollution_diffusion_per_tick"]
	)
	data.brood_pollution_comfort_max = float(
		value["brood_pollution_comfort_max"]
	)
	data.brood_pollution_penalty_weight = float(
		value["brood_pollution_penalty_weight"]
	)
	data.queen_care_light_max = float(value["queen_care_light_max"])
	if not data.is_valid():
		return _failure("Frozen environment configuration is not valid")
	return {"ok": true, "error": "", "environment_data": data}


static func _decode_colony_work_data(value: Variant) -> Dictionary:
	if value == null:
		return {
			"ok": true,
			"error": "",
			"colony_work_data": null,
		}
	var float_keys: Array[String] = [
		"waste_source_pollution_min",
		"waste_batch_amount",
		"migration_min_improvement",
		"migration_pollution_max",
	]
	var int_keys: Array[String] = [
		"waste_decision_interval_ticks",
		"waste_travel_ticks_per_connection",
		"waste_pickup_duration_ticks",
		"waste_drop_duration_ticks",
		"scout_decision_interval_ticks",
		"scout_travel_ticks_per_connection",
		"scout_observe_duration_ticks",
		"migration_target_stable_ticks",
		"migration_minimum_zone_dwell_ticks",
		"migration_decision_interval_ticks",
		"migration_travel_ticks_per_connection",
		"migration_pickup_duration_ticks",
		"migration_drop_duration_ticks",
	]
	var keys: Array[String] = []
	keys.append_array(float_keys)
	keys.append_array(int_keys)
	if not _is_dictionary_with_keys(value, keys):
		return _failure("Colony-work configuration is invalid")
	for key: String in float_keys:
		if not _is_finite_number(value[key]):
			return _failure("Colony-work configuration is non-finite")
	for key: String in int_keys:
		if not _is_integral_number(value[key]):
			return _failure(
				"Colony-work configuration contains a non-integer"
			)
	var data: ColonyWorkData = ColonyWorkData.new()
	data.data_status = &"prototype_pacing_fixture"
	data.scientifically_validated = false
	for key: String in float_keys:
		data.set(key, float(value[key]))
	for key: String in int_keys:
		data.set(key, int(value[key]))
	if not data.is_valid():
		return _failure("Frozen colony-work configuration is not valid")
	return {
		"ok": true,
		"error": "",
		"colony_work_data": data,
	}


static func _decode_foraging_data(value: Variant) -> Dictionary:
	if value == null:
		return {"ok": true, "error": "", "foraging_data": null}
	var keys: Array[String] = [
		"discovery_delay_ticks",
		"outbound_travel_duration_ticks",
		"collection_duration_ticks",
		"return_travel_duration_ticks",
		"sharing_duration_ticks",
	]
	if not _is_dictionary_with_keys(value, keys):
		return _failure("Foraging configuration is invalid")
	var data: ForagingData = ForagingData.new()
	data.data_status = &"prototype_pacing_fixture"
	data.scientifically_validated = false
	for key: String in keys:
		if not _is_integral_number(value[key]):
			return _failure("Foraging configuration contains a non-integer")
	data.discovery_delay_ticks = int(value["discovery_delay_ticks"])
	data.outbound_travel_duration_ticks = int(
		value["outbound_travel_duration_ticks"]
	)
	data.collection_duration_ticks = int(
		value["collection_duration_ticks"]
	)
	data.return_travel_duration_ticks = int(
		value["return_travel_duration_ticks"]
	)
	data.sharing_duration_ticks = int(value["sharing_duration_ticks"])
	if not data.is_valid():
		return _failure("Frozen foraging configuration is not valid")
	return {"ok": true, "error": "", "foraging_data": data}


static func _decode_sequence_data(value: Variant) -> Dictionary:
	if value == null:
		return {"ok": true, "error": "", "sequence_data": null}
	if not _is_dictionary_with_keys(
		value,
		[
			"first_worker_initial_pupa_age_ticks",
			"first_worker_observation_card_id",
			"brood_humidity_observation_card_id",
		]
	):
		return _failure("Sequence configuration is invalid")
	if (
		not _is_integral_number(
			value["first_worker_initial_pupa_age_ticks"]
		)
		or typeof(value["first_worker_observation_card_id"])
			!= TYPE_STRING
		or typeof(value["brood_humidity_observation_card_id"])
			!= TYPE_STRING
	):
		return _failure("Sequence configuration has an invalid value")
	var data: ScenarioSequenceData = ScenarioSequenceData.new()
	data.data_status = &"prototype_pacing_fixture"
	data.scientifically_validated = false
	data.first_worker_initial_pupa_age_ticks = int(
		value["first_worker_initial_pupa_age_ticks"]
	)
	data.first_worker_observation_card_id = StringName(
		value["first_worker_observation_card_id"]
	)
	data.brood_humidity_observation_card_id = StringName(
		value["brood_humidity_observation_card_id"]
	)
	if not data.is_valid():
		return _failure("Frozen sequence configuration is not valid")
	return {"ok": true, "error": "", "sequence_data": data}


static func _decode_nutrition_data(value: Variant) -> Dictionary:
	if value == null:
		return {"ok": true, "error": "", "nutrition_data": null}
	var keys: Array[String] = [
		"initial_sugar_reserve_portions",
		"initial_protein_reserve_portions",
		"sugar_activity_ticks_per_portion",
		"sugar_shortage_step_interval_ticks",
		"protein_growth_ticks_per_portion",
		"feeding_decision_interval_ticks",
		"feeding_travel_duration_ticks",
		"feeding_duration_ticks",
	]
	if not _is_dictionary_with_keys(value, keys):
		return _failure("Nutrition configuration is invalid")
	for key: String in keys:
		if not _is_integral_number(value[key]):
			return _failure("Nutrition configuration contains a non-integer")
	var data: NutritionData = NutritionData.new()
	data.data_status = &"prototype_pacing_fixture"
	data.scientifically_validated = false
	data.initial_sugar_reserve_portions = int(
		value["initial_sugar_reserve_portions"]
	)
	data.initial_protein_reserve_portions = int(
		value["initial_protein_reserve_portions"]
	)
	data.sugar_activity_ticks_per_portion = int(
		value["sugar_activity_ticks_per_portion"]
	)
	data.sugar_shortage_step_interval_ticks = int(
		value["sugar_shortage_step_interval_ticks"]
	)
	data.protein_growth_ticks_per_portion = int(
		value["protein_growth_ticks_per_portion"]
	)
	data.feeding_decision_interval_ticks = int(
		value["feeding_decision_interval_ticks"]
	)
	data.feeding_travel_duration_ticks = int(
		value["feeding_travel_duration_ticks"]
	)
	data.feeding_duration_ticks = int(value["feeding_duration_ticks"])
	if not data.is_valid():
		return _failure("Frozen nutrition configuration is not valid")
	return {"ok": true, "error": "", "nutrition_data": data}


static func _decode_founding_care_data(value: Variant) -> Dictionary:
	if value == null:
		return {
			"ok": true,
			"error": "",
			"founding_care_data": null,
		}
	var int_keys: Array[String] = [
		"rest_duration_ticks",
		"gathering_duration_ticks",
		"brood_care_duration_ticks",
		"pupa_observation_ticks",
		"first_worker_initial_pupa_age_ticks",
	]
	var id_keys: Array[String] = [
		"queen_care_observation_card_id",
		"pupa_observation_card_id",
		"first_worker_observation_card_id",
		"worker_care_observation_card_id",
	]
	var keys: Array[String] = []
	keys.append_array(int_keys)
	keys.append_array(id_keys)
	if not _is_dictionary_with_keys(value, keys):
		return _failure("Founding-care configuration is invalid")
	for key: String in int_keys:
		if not _is_integral_number(value[key]):
			return _failure(
				"Founding-care configuration contains a non-integer"
			)
	for key: String in id_keys:
		if typeof(value[key]) != TYPE_STRING:
			return _failure(
				"Founding-care configuration contains a non-string ID"
			)
	var data: FoundingCareData = FoundingCareData.new()
	data.data_status = &"prototype_pacing_fixture"
	data.scientifically_validated = false
	data.rest_duration_ticks = int(value["rest_duration_ticks"])
	data.gathering_duration_ticks = int(value["gathering_duration_ticks"])
	data.brood_care_duration_ticks = int(
		value["brood_care_duration_ticks"]
	)
	data.pupa_observation_ticks = int(value["pupa_observation_ticks"])
	data.first_worker_initial_pupa_age_ticks = int(
		value["first_worker_initial_pupa_age_ticks"]
	)
	data.queen_care_observation_card_id = StringName(
		value["queen_care_observation_card_id"]
	)
	data.pupa_observation_card_id = StringName(
		value["pupa_observation_card_id"]
	)
	data.first_worker_observation_card_id = StringName(
		value["first_worker_observation_card_id"]
	)
	data.worker_care_observation_card_id = StringName(
		value["worker_care_observation_card_id"]
	)
	if not data.is_valid():
		return _failure("Frozen founding-care configuration is not valid")
	return {
		"ok": true,
		"error": "",
		"founding_care_data": data,
	}


static func _decode_facility_catalog_data(value: Variant) -> Dictionary:
	if value == null:
		return {"ok": true, "error": "", "catalog_data": null}
	if not _is_dictionary_with_keys(
		value,
		[
			"grid_size",
			"facility_types",
			"initial_facilities",
			"initial_supplies",
		]
	):
		return _failure("Facility catalog configuration is invalid")
	var grid_result: Dictionary = _decode_vector2i(value["grid_size"])
	if (
		not grid_result.get("ok", false)
		or typeof(value["facility_types"]) != TYPE_ARRAY
		or typeof(value["initial_facilities"]) != TYPE_ARRAY
		or typeof(value["initial_supplies"]) != TYPE_ARRAY
	):
		return _failure("Facility catalog contains invalid collections")
	var catalog: FacilityCatalogData = FacilityCatalogData.new()
	catalog.data_status = &"prototype_pacing_fixture"
	catalog.scientifically_validated = false
	catalog.grid_size = grid_result["value"]
	for type_value: Variant in value["facility_types"]:
		var type_result: Dictionary = _decode_facility_data(type_value)
		if not type_result.get("ok", false):
			return type_result
		catalog.facility_types.append(type_result["facility_data"])
	for initial_value: Variant in value["initial_facilities"]:
		var initial_result: Dictionary = _decode_initial_facility_data(
			initial_value
		)
		if not initial_result.get("ok", false):
			return initial_result
		catalog.initial_facilities.append(initial_result["initial_data"])
	for supply_value: Variant in value["initial_supplies"]:
		if not _is_dictionary_with_keys(
			supply_value,
			["type_id", "available_count"]
		):
			return _failure("Facility supply configuration is invalid")
		if (
			typeof(supply_value["type_id"]) != TYPE_STRING
			or not _is_nonnegative_int(supply_value["available_count"])
		):
			return _failure("Facility supply contains invalid data")
		var supply: FacilitySupplyData = FacilitySupplyData.new()
		supply.type_id = StringName(supply_value["type_id"])
		supply.available_count = int(supply_value["available_count"])
		catalog.initial_supplies.append(supply)
	if not catalog.is_valid():
		return _failure("Frozen facility catalog is not valid")
	return {"ok": true, "error": "", "catalog_data": catalog}


static func _decode_facility_data(value: Variant) -> Dictionary:
	if not _is_dictionary_with_keys(
		value,
		[
			"type_id",
			"unlock_type_id",
			"footprint",
			"allowed_orientations",
			"ports",
			"placement_layer",
			"requires_connection",
			"player_removable",
			"effect_config",
		]
	):
		return _failure("Facility type configuration is invalid")
	var footprint_result: Dictionary = _decode_vector2i(value["footprint"])
	if (
		not footprint_result.get("ok", false)
		or typeof(value["type_id"]) != TYPE_STRING
		or typeof(value["unlock_type_id"]) != TYPE_STRING
		or typeof(value["allowed_orientations"]) != TYPE_ARRAY
		or typeof(value["ports"]) != TYPE_ARRAY
		or not _is_integral_number(value["placement_layer"])
		or typeof(value["requires_connection"]) != TYPE_BOOL
		or typeof(value["player_removable"]) != TYPE_BOOL
	):
		return _failure("Facility type contains invalid data")
	var data: FacilityData = FacilityData.new()
	data.type_id = StringName(value["type_id"])
	data.unlock_type_id = StringName(value["unlock_type_id"])
	data.data_status = &"prototype_pacing_fixture"
	data.footprint = footprint_result["value"]
	data.allowed_orientations.clear()
	for orientation_value: Variant in value["allowed_orientations"]:
		if not _is_integral_number(orientation_value):
			return _failure("Facility orientation is not an integer")
		data.allowed_orientations.append(int(orientation_value))
	for port_value: Variant in value["ports"]:
		if not _is_dictionary_with_keys(
			port_value,
			["local_cell", "direction", "connection_kind"]
		):
			return _failure("Facility port configuration is invalid")
		var cell_result: Dictionary = _decode_vector2i(
			port_value["local_cell"]
		)
		if (
			not cell_result.get("ok", false)
			or not _is_integral_number(port_value["direction"])
			or typeof(port_value["connection_kind"]) != TYPE_STRING
		):
			return _failure("Facility port contains invalid data")
		var port: FacilityPortData = FacilityPortData.new()
		port.local_cell = cell_result["value"]
		port.direction = int(port_value["direction"])
		port.connection_kind = StringName(port_value["connection_kind"])
		data.ports.append(port)
	data.placement_layer = int(value["placement_layer"])
	data.requires_connection = bool(value["requires_connection"])
	data.player_removable = bool(value["player_removable"])
	var effect_result: Dictionary = _decode_facility_effect_data(
		value["effect_config"]
	)
	if not effect_result.get("ok", false):
		return effect_result
	data.effect_data = effect_result["effect_data"]
	if not data.is_valid():
		return _failure("Frozen facility type is not valid")
	return {"ok": true, "error": "", "facility_data": data}


static func _decode_facility_effect_data(value: Variant) -> Dictionary:
	if typeof(value) != TYPE_DICTIONARY or not value.has("kind"):
		return _failure("Facility effect configuration is invalid")
	if not _is_integral_number(value["kind"]):
		return _failure("Facility effect kind is invalid")
	var kind: int = int(value["kind"])
	var data: FacilityEffectData
	match kind:
		FacilityEffectConfig.Kind.HABITAT_ZONE:
			if not _is_dictionary_with_keys(value, [
				"kind",
				"initial_humidity",
				"initial_light_exposure",
				"initial_pollution",
				"pollution_per_tick",
			]):
				return _failure("Habitat-zone facility effect is invalid")
			for key: String in [
				"initial_humidity",
				"initial_light_exposure",
				"initial_pollution",
				"pollution_per_tick",
			]:
				if not _is_finite_number(value[key]):
					return _failure(
						"Habitat-zone facility effect is non-finite"
					)
			var zone_data: HabitatZoneFacilityEffectData = (
				HabitatZoneFacilityEffectData.new()
			)
			zone_data.initial_humidity = float(value["initial_humidity"])
			zone_data.initial_light_exposure = float(
				value["initial_light_exposure"]
			)
			zone_data.initial_pollution = float(value["initial_pollution"])
			zone_data.pollution_per_tick = float(
				value["pollution_per_tick"]
			)
			data = zone_data
		FacilityEffectConfig.Kind.HYDRATION:
			if not _is_dictionary_with_keys(value, [
				"kind",
				"target_humidity",
				"humidity_per_tick",
			]):
				return _failure("Hydration facility effect is invalid")
			if (
				not _is_finite_number(value["target_humidity"])
				or not _is_finite_number(value["humidity_per_tick"])
			):
				return _failure("Hydration facility effect is non-finite")
			var hydration_data: HydrationFacilityEffectData = (
				HydrationFacilityEffectData.new()
			)
			hydration_data.target_humidity = float(
				value["target_humidity"]
			)
			hydration_data.humidity_per_tick = float(
				value["humidity_per_tick"]
			)
			data = hydration_data
		FacilityEffectConfig.Kind.FOOD_STATION:
			if not _is_dictionary_with_keys(value, [
				"kind",
				"accepts_sugar",
				"accepts_protein",
				"portion_capacity",
				"host_zone_required",
			]):
				return _failure("Food-station facility effect is invalid")
			if (
				typeof(value["accepts_sugar"]) != TYPE_BOOL
				or typeof(value["accepts_protein"]) != TYPE_BOOL
				or not _is_positive_int(value["portion_capacity"])
				or typeof(value["host_zone_required"]) != TYPE_BOOL
			):
				return _failure("Food-station facility effect has bad data")
			var food_data: FoodStationFacilityEffectData = (
				FoodStationFacilityEffectData.new()
			)
			food_data.accepts_sugar = bool(value["accepts_sugar"])
			food_data.accepts_protein = bool(value["accepts_protein"])
			food_data.portion_capacity = int(value["portion_capacity"])
			food_data.host_zone_required = bool(
				value["host_zone_required"]
			)
			data = food_data
		FacilityEffectConfig.Kind.WASTE_TRAY:
			if not _is_dictionary_with_keys(value, [
				"kind",
				"capacity",
				"capture_per_tick",
			]):
				return _failure("Waste-tray facility effect is invalid")
			if (
				not _is_finite_number(value["capacity"])
				or not _is_finite_number(value["capture_per_tick"])
			):
				return _failure("Waste-tray facility effect is non-finite")
			var waste_data: WasteTrayFacilityEffectData = (
				WasteTrayFacilityEffectData.new()
			)
			waste_data.capacity = float(value["capacity"])
			waste_data.capture_per_tick = float(value["capture_per_tick"])
			data = waste_data
		FacilityEffectConfig.Kind.CONNECTOR:
			if not _is_dictionary_with_keys(value, ["kind", "gated"]):
				return _failure("Connector facility effect is invalid")
			if typeof(value["gated"]) != TYPE_BOOL:
				return _failure("Connector facility effect has bad data")
			var connector_data: ConnectorFacilityEffectData = (
				ConnectorFacilityEffectData.new()
			)
			connector_data.gated = bool(value["gated"])
			data = connector_data
		FacilityEffectConfig.Kind.LIGHT_COVER:
			if not _is_dictionary_with_keys(value, [
				"kind",
				"target_light_exposure",
				"transition_per_tick",
			]):
				return _failure("Light-cover facility effect is invalid")
			if (
				not _is_finite_number(value["target_light_exposure"])
				or not _is_finite_number(value["transition_per_tick"])
			):
				return _failure("Light-cover facility effect is non-finite")
			var cover_data: LightCoverFacilityEffectData = (
				LightCoverFacilityEffectData.new()
			)
			cover_data.target_light_exposure = float(
				value["target_light_exposure"]
			)
			cover_data.transition_per_tick = float(
				value["transition_per_tick"]
			)
			data = cover_data
		_:
			return _failure("Facility effect kind is unsupported")
	if data == null or not data.is_valid():
		return _failure("Frozen facility effect is not valid")
	return {"ok": true, "error": "", "effect_data": data}


static func _decode_initial_facility_data(value: Variant) -> Dictionary:
	if not _is_dictionary_with_keys(
		value,
		[
			"facility_id",
			"type_id",
			"slot",
			"orientation",
			"zone_id",
			"available",
			"player_removable",
		]
	):
		return _failure("Initial facility configuration is invalid")
	var slot_result: Dictionary = _decode_vector2i(value["slot"])
	if (
		not slot_result.get("ok", false)
		or not _is_positive_int(value["facility_id"])
		or typeof(value["type_id"]) != TYPE_STRING
		or not _is_integral_number(value["orientation"])
		or typeof(value["zone_id"]) != TYPE_STRING
		or typeof(value["available"]) != TYPE_BOOL
		or typeof(value["player_removable"]) != TYPE_BOOL
	):
		return _failure("Initial facility contains invalid data")
	var data: InitialFacilityData = InitialFacilityData.new()
	data.facility_id = int(value["facility_id"])
	data.type_id = StringName(value["type_id"])
	data.slot = slot_result["value"]
	data.orientation = int(value["orientation"])
	data.zone_id = StringName(value["zone_id"])
	data.available = bool(value["available"])
	data.player_removable = bool(value["player_removable"])
	if not data.is_valid():
		return _failure("Frozen initial facility is not valid")
	return {"ok": true, "error": "", "initial_data": data}


static func _decode_state(
	payload: Dictionary,
	next_ids: Dictionary
) -> Dictionary:
	if not _has_exact_keys(
		payload,
		[
			"simulation_tick",
			"queen",
			"ants",
			"zones",
			"food_sources",
			"humidity_adjustment_count",
			"water_action_unlocked",
			"observation_stable_ticks",
			"brood_humidity_observation_unlocked",
			"shared_sugar_portions",
			"total_sugar_portions_placed",
			"unlocked_observation_card_ids",
			"scenario_progress",
			"campaign",
			"nutrition",
			"act1",
			"layout",
			"colony_work",
			"observation_events",
		]
	):
		return _failure("State payload has unexpected fields")
	if not _has_exact_keys(
		next_ids,
		[
			"entity_id",
			"observation_event_id",
			"pending_command_sequence_id",
			"facility_id",
			"connection_id",
		]
	):
		return _failure("Next-ID payload has unexpected fields")
	for key: String in [
		"simulation_tick",
		"humidity_adjustment_count",
		"observation_stable_ticks",
		"shared_sugar_portions",
		"total_sugar_portions_placed",
	]:
		if not _is_nonnegative_int(payload[key]):
			return _failure("State payload contains an invalid counter")
	for key: String in next_ids:
		if not _is_positive_int(next_ids[key]):
			return _failure("Next-ID payload contains an invalid counter")
	if (
		typeof(payload["water_action_unlocked"]) != TYPE_BOOL
		or typeof(payload["brood_humidity_observation_unlocked"])
			!= TYPE_BOOL
		or typeof(payload["ants"]) != TYPE_ARRAY
		or typeof(payload["zones"]) != TYPE_ARRAY
		or typeof(payload["food_sources"]) != TYPE_ARRAY
		or typeof(payload["unlocked_observation_card_ids"])
			!= TYPE_ARRAY
		or typeof(payload["observation_events"]) != TYPE_ARRAY
	):
		return _failure("State payload contains an invalid collection")
	if not _is_dictionary_with_keys(
		payload["queen"],
		[
			"entity_id",
			"laid_egg_count",
			"zone_id",
			"zone_entered_tick",
		]
	):
		return _failure("Queen state is invalid")
	if (
		not _is_nonnegative_int(payload["queen"]["entity_id"])
		or not _is_nonnegative_int(payload["queen"]["laid_egg_count"])
		or typeof(payload["queen"]["zone_id"]) != TYPE_STRING
		or not _is_integral_number(
			payload["queen"]["zone_entered_tick"]
		)
	):
		return _failure("Queen state contains an invalid counter")

	var state: ColonyState = ColonyState.new()
	state.simulation_tick = int(payload["simulation_tick"])
	state.queen = QueenModel.new(int(payload["queen"]["entity_id"]))
	state.queen.laid_egg_count = int(payload["queen"]["laid_egg_count"])
	state.queen.zone_id = StringName(payload["queen"]["zone_id"])
	state.queen.zone_entered_tick = int(
		payload["queen"]["zone_entered_tick"]
	)
	state.ants.clear()
	for ant_value: Variant in payload["ants"]:
		var ant_result: Dictionary = _decode_ant(ant_value)
		if not ant_result.get("ok", false):
			return ant_result
		state.ants.append(ant_result["ant"])
	state.zones.clear()
	for zone_value: Variant in payload["zones"]:
		var zone_result: Dictionary = _decode_zone_state(zone_value)
		if not zone_result.get("ok", false):
			return zone_result
		state.zones.append(zone_result["zone"])
	state.food_sources.clear()
	for source_value: Variant in payload["food_sources"]:
		var source_result: Dictionary = _decode_food_source(source_value)
		if not source_result.get("ok", false):
			return source_result
		state.food_sources.append(source_result["source"])
	state.humidity_adjustment_count = int(
		payload["humidity_adjustment_count"]
	)
	state.water_action_unlocked = bool(payload["water_action_unlocked"])
	state.observation_stable_ticks = int(
		payload["observation_stable_ticks"]
	)
	state.brood_humidity_observation_unlocked = bool(
		payload["brood_humidity_observation_unlocked"]
	)
	state.shared_sugar_portions = int(payload["shared_sugar_portions"])
	state.total_sugar_portions_placed = int(
		payload["total_sugar_portions_placed"]
	)
	state.unlocked_observation_card_ids.clear()
	var cards_result: Dictionary = _decode_string_names(
		payload["unlocked_observation_card_ids"],
		true
	)
	if not cards_result.get("ok", false):
		return cards_result
	for card_id: StringName in cards_result["values"]:
		state.unlocked_observation_card_ids[card_id] = true
	var progress_result: Dictionary = _decode_progress(
		payload["scenario_progress"]
	)
	if not progress_result.get("ok", false):
		return progress_result
	state.scenario_progress = progress_result["progress"]
	var campaign_result: Dictionary = _decode_campaign(payload["campaign"])
	if not campaign_result.get("ok", false):
		return campaign_result
	state.campaign_state = campaign_result["campaign"]
	var nutrition_result: Dictionary = _decode_nutrition_state(
		payload["nutrition"]
	)
	if not nutrition_result.get("ok", false):
		return nutrition_result
	state.nutrition_state = nutrition_result["nutrition"]
	var act1_result: Dictionary = _decode_act1_state(payload["act1"])
	if not act1_result.get("ok", false):
		return act1_result
	state.act1_state = act1_result["act1"]
	var layout_result: Dictionary = _decode_layout_state(
		payload["layout"],
		int(next_ids["facility_id"]),
		int(next_ids["connection_id"])
	)
	if not layout_result.get("ok", false):
		return layout_result
	state.layout_state = layout_result["layout"]
	var colony_work_result: Dictionary = _decode_colony_work_state(
		payload["colony_work"]
	)
	if not colony_work_result.get("ok", false):
		return colony_work_result
	state.colony_work_state = colony_work_result["colony_work"]
	state._observation_events.clear()
	for event_value: Variant in payload["observation_events"]:
		var event_result: Dictionary = _decode_event(event_value)
		if not event_result.get("ok", false):
			return event_result
		state._observation_events.append(event_result["event"])
	state._next_entity_id = int(next_ids["entity_id"])
	state._next_observation_event_id = int(
		next_ids["observation_event_id"]
	)
	return {"ok": true, "error": "", "state": state}


static func _decode_colony_work_state(value: Variant) -> Dictionary:
	if value == null:
		return {"ok": true, "error": "", "colony_work": null}
	var id_keys: Array[String] = [
		"migration_candidate_zone_id",
		"migration_target_zone_id",
	]
	var int_keys: Array[String] = [
		"migration_candidate_stable_ticks",
		"completed_migration_count",
		"scouted_zone_count",
		"delivered_waste_batch_count",
		"cleaned_waste_tray_count",
	]
	var keys: Array[String] = []
	keys.append_array(id_keys)
	keys.append_array(int_keys)
	if not _is_dictionary_with_keys(value, keys):
		return _failure("Colony-work state is invalid")
	for key: String in id_keys:
		if typeof(value[key]) != TYPE_STRING:
			return _failure("Colony-work state has a non-string ID")
	for key: String in int_keys:
		if not _is_nonnegative_int(value[key]):
			return _failure("Colony-work state has an invalid counter")
	var work: ColonyWorkState = ColonyWorkState.new()
	work.migration_candidate_zone_id = StringName(
		value["migration_candidate_zone_id"]
	)
	work.migration_candidate_stable_ticks = int(
		value["migration_candidate_stable_ticks"]
	)
	work.migration_target_zone_id = StringName(
		value["migration_target_zone_id"]
	)
	work.completed_migration_count = int(
		value["completed_migration_count"]
	)
	work.scouted_zone_count = int(value["scouted_zone_count"])
	work.delivered_waste_batch_count = int(
		value["delivered_waste_batch_count"]
	)
	work.cleaned_waste_tray_count = int(
		value["cleaned_waste_tray_count"]
	)
	return {"ok": true, "error": "", "colony_work": work}


static func _decode_act1_state(value: Variant) -> Dictionary:
	if value == null:
		return {"ok": true, "error": "", "act1": null}
	var keys: Array[String] = [
		"light_cover_applied",
		"light_cover_action_count",
		"queen_care_state",
		"queen_care_elapsed_ticks",
		"queen_care_target_brood_id",
		"completed_queen_care_count",
		"pupa_stable_ticks",
		"first_worker_entity_id",
		"first_worker_emerged_tick",
		"first_worker_care_recorded",
	]
	if not _is_dictionary_with_keys(value, keys):
		return _failure("Act 1 state is invalid")
	for key: String in [
		"light_cover_action_count",
		"queen_care_state",
		"queen_care_elapsed_ticks",
		"queen_care_target_brood_id",
		"completed_queen_care_count",
		"pupa_stable_ticks",
		"first_worker_entity_id",
		"first_worker_emerged_tick",
	]:
		if not _is_integral_number(value[key]):
			return _failure("Act 1 state contains a non-integer")
	if (
		typeof(value["light_cover_applied"]) != TYPE_BOOL
		or typeof(value["first_worker_care_recorded"]) != TYPE_BOOL
	):
		return _failure("Act 1 state contains an invalid flag")
	var act1: Act1State = Act1State.new()
	act1.light_cover_applied = bool(value["light_cover_applied"])
	act1.light_cover_action_count = int(value["light_cover_action_count"])
	act1.queen_care_state = int(value["queen_care_state"])
	act1.queen_care_elapsed_ticks = int(
		value["queen_care_elapsed_ticks"]
	)
	act1.queen_care_target_brood_id = int(
		value["queen_care_target_brood_id"]
	)
	act1.completed_queen_care_count = int(
		value["completed_queen_care_count"]
	)
	act1.pupa_stable_ticks = int(value["pupa_stable_ticks"])
	act1.first_worker_entity_id = int(value["first_worker_entity_id"])
	act1.first_worker_emerged_tick = int(
		value["first_worker_emerged_tick"]
	)
	act1.first_worker_care_recorded = bool(
		value["first_worker_care_recorded"]
	)
	return {"ok": true, "error": "", "act1": act1}


static func _decode_nutrition_state(value: Variant) -> Dictionary:
	if value == null:
		return {"ok": true, "error": "", "nutrition": null}
	var keys: Array[String] = [
		"sugar_reserve_portions",
		"protein_reserve_portions",
		"sugar_activity_ticks_remaining",
		"total_sugar_portions_supplied",
		"total_protein_portions_supplied",
		"total_sugar_portions_consumed",
		"total_protein_portions_consumed",
		"total_protein_portions_placed",
		"delivered_protein_portions",
		"completed_feeding_count",
	]
	if not _is_dictionary_with_keys(value, keys):
		return _failure("Nutrition state is invalid")
	for key: String in keys:
		if not _is_nonnegative_int(value[key]):
			return _failure("Nutrition state contains an invalid counter")
	var nutrition: ColonyNutritionState = ColonyNutritionState.new()
	nutrition.sugar_reserve_portions = int(value["sugar_reserve_portions"])
	nutrition.protein_reserve_portions = int(
		value["protein_reserve_portions"]
	)
	nutrition.sugar_activity_ticks_remaining = int(
		value["sugar_activity_ticks_remaining"]
	)
	nutrition.total_sugar_portions_supplied = int(
		value["total_sugar_portions_supplied"]
	)
	nutrition.total_protein_portions_supplied = int(
		value["total_protein_portions_supplied"]
	)
	nutrition.total_sugar_portions_consumed = int(
		value["total_sugar_portions_consumed"]
	)
	nutrition.total_protein_portions_consumed = int(
		value["total_protein_portions_consumed"]
	)
	nutrition.total_protein_portions_placed = int(
		value["total_protein_portions_placed"]
	)
	nutrition.delivered_protein_portions = int(
		value["delivered_protein_portions"]
	)
	nutrition.completed_feeding_count = int(
		value["completed_feeding_count"]
	)
	return {"ok": true, "error": "", "nutrition": nutrition}


static func _decode_campaign(value: Variant) -> Dictionary:
	if value == null:
		return {"ok": true, "error": "", "campaign": null}
	var keys: Array[String] = [
		"chapter",
		"status",
		"chapter_entered_tick",
		"completed_chapter_count",
		"incorrect_inference_attempts",
		"hint_tier",
		"campaign_completed_tick",
		"collected_evidence_ids",
		"confirmed_inference_ids",
		"unlocked_facility_type_ids",
	]
	if not _is_dictionary_with_keys(value, keys):
		return _failure("Campaign state is invalid")
	for key: String in [
		"chapter",
		"status",
		"chapter_entered_tick",
		"completed_chapter_count",
		"incorrect_inference_attempts",
		"hint_tier",
		"campaign_completed_tick",
	]:
		if not _is_integral_number(value[key]):
			return _failure("Campaign state contains a non-integer")
	for key: String in [
		"collected_evidence_ids",
		"confirmed_inference_ids",
		"unlocked_facility_type_ids",
	]:
		if typeof(value[key]) != TYPE_ARRAY:
			return _failure("Campaign state contains an invalid collection")
	var campaign: CampaignState = CampaignState.new()
	campaign.chapter = int(value["chapter"])
	campaign.status = int(value["status"])
	campaign.chapter_entered_tick = int(value["chapter_entered_tick"])
	campaign.completed_chapter_count = int(
		value["completed_chapter_count"]
	)
	campaign.incorrect_inference_attempts = int(
		value["incorrect_inference_attempts"]
	)
	campaign.hint_tier = int(value["hint_tier"])
	campaign.campaign_completed_tick = int(
		value["campaign_completed_tick"]
	)
	var evidence_result: Dictionary = _decode_string_names(
		value["collected_evidence_ids"],
		true
	)
	if not evidence_result.get("ok", false):
		return evidence_result
	campaign.collected_evidence_ids.clear()
	for evidence_id: StringName in evidence_result["values"]:
		campaign.collected_evidence_ids[evidence_id] = true
	var inference_result: Dictionary = _decode_string_names(
		value["confirmed_inference_ids"],
		true
	)
	if not inference_result.get("ok", false):
		return inference_result
	campaign.confirmed_inference_ids.clear()
	for inference_id: StringName in inference_result["values"]:
		campaign.confirmed_inference_ids[inference_id] = true
	var facility_result: Dictionary = _decode_string_names(
		value["unlocked_facility_type_ids"],
		true
	)
	if not facility_result.get("ok", false):
		return facility_result
	campaign.unlocked_facility_type_ids.clear()
	for facility_id: StringName in facility_result["values"]:
		campaign.unlocked_facility_type_ids[facility_id] = true
	return {"ok": true, "error": "", "campaign": campaign}


static func _decode_ant(value: Variant) -> Dictionary:
	if not _is_dictionary_with_keys(
		value,
		[
			"entity_id",
			"life_stage",
			"total_age_ticks",
			"stage_age_ticks",
			"zone_id",
			"zone_entered_tick",
			"protein_supported_growth_ticks",
			"worker_task",
			"foraging_task",
			"feeding_task",
			"waste_cleanup_task",
			"scout_task",
			"migration_task",
		]
	):
		return _failure("Ant state is invalid")
	for key: String in [
		"entity_id",
		"life_stage",
		"total_age_ticks",
		"stage_age_ticks",
		"protein_supported_growth_ticks",
	]:
		if not _is_nonnegative_int(value[key]):
			return _failure("Ant state contains an invalid counter")
	if (
		not _is_integral_number(value["zone_entered_tick"])
		or typeof(value["zone_id"]) != TYPE_STRING
		or int(value["life_stage"]) > AntModel.LifeStage.WORKER
	):
		return _failure("Ant state contains an invalid value")
	var ant: AntModel = AntModel.new(
		int(value["entity_id"]),
		int(value["life_stage"])
	)
	ant.total_age_ticks = int(value["total_age_ticks"])
	ant.stage_age_ticks = int(value["stage_age_ticks"])
	ant.zone_id = StringName(value["zone_id"])
	ant.zone_entered_tick = int(value["zone_entered_tick"])
	ant.protein_supported_growth_ticks = int(
		value["protein_supported_growth_ticks"]
	)
	var worker_result: Dictionary = _decode_worker_task(value["worker_task"])
	if not worker_result.get("ok", false):
		return worker_result
	ant.worker_task = worker_result["task"]
	var foraging_result: Dictionary = _decode_foraging_task(
		value["foraging_task"]
	)
	if not foraging_result.get("ok", false):
		return foraging_result
	ant.foraging_task = foraging_result["task"]
	var feeding_result: Dictionary = _decode_feeding_task(
		value["feeding_task"]
	)
	if not feeding_result.get("ok", false):
		return feeding_result
	ant.feeding_task = feeding_result["task"]
	var waste_result: Dictionary = _decode_waste_cleanup_task(
		value["waste_cleanup_task"]
	)
	if not waste_result.get("ok", false):
		return waste_result
	ant.waste_cleanup_task = waste_result["task"]
	var scout_result: Dictionary = _decode_scout_task(
		value["scout_task"]
	)
	if not scout_result.get("ok", false):
		return scout_result
	ant.scout_task = scout_result["task"]
	var migration_result: Dictionary = _decode_migration_task(
		value["migration_task"]
	)
	if not migration_result.get("ok", false):
		return migration_result
	ant.migration_task = migration_result["task"]
	return {"ok": true, "error": "", "ant": ant}


static func _decode_worker_task(value: Variant) -> Dictionary:
	if value == null:
		return {"ok": true, "error": "", "task": null}
	if not _is_dictionary_with_keys(
		value,
		[
			"state",
			"origin_zone_id",
			"target_brood_id",
			"target_zone_id",
			"carried_brood_id",
			"elapsed_ticks",
			"duration_ticks",
			"next_decision_tick",
		]
	):
		return _failure("Worker task is invalid")
	for key: String in [
		"state",
		"target_brood_id",
		"carried_brood_id",
		"elapsed_ticks",
		"duration_ticks",
		"next_decision_tick",
	]:
		if not _is_integral_number(value[key]):
			return _failure("Worker task contains a non-integer")
	if (
		int(value["state"]) < WorkerTaskModel.State.IDLE
		or int(value["state"]) > WorkerTaskModel.State.DROPPING
		or int(value["elapsed_ticks"]) < 0
		or int(value["duration_ticks"]) < 0
		or int(value["next_decision_tick"]) < 0
		or typeof(value["origin_zone_id"]) != TYPE_STRING
		or typeof(value["target_zone_id"]) != TYPE_STRING
	):
		return _failure("Worker task contains an invalid value")
	var task: WorkerTaskModel = WorkerTaskModel.new()
	task.state = int(value["state"])
	task.origin_zone_id = StringName(value["origin_zone_id"])
	task.target_brood_id = int(value["target_brood_id"])
	task.target_zone_id = StringName(value["target_zone_id"])
	task.carried_brood_id = int(value["carried_brood_id"])
	task.elapsed_ticks = int(value["elapsed_ticks"])
	task.duration_ticks = int(value["duration_ticks"])
	task.next_decision_tick = int(value["next_decision_tick"])
	return {"ok": true, "error": "", "task": task}


static func _decode_foraging_task(value: Variant) -> Dictionary:
	if value == null:
		return {"ok": true, "error": "", "task": null}
	if not _is_dictionary_with_keys(
		value,
		[
			"state",
			"target_food_source_id",
			"origin_zone_id",
			"target_zone_id",
			"nest_zone_id",
			"route_zone_ids",
			"route_cache_key",
			"carried_portions",
			"elapsed_ticks",
			"duration_ticks",
		]
	):
		return _failure("Foraging task is invalid")
	for key: String in [
		"state",
		"target_food_source_id",
		"carried_portions",
		"elapsed_ticks",
		"duration_ticks",
	]:
		if not _is_integral_number(value[key]):
			return _failure("Foraging task contains a non-integer")
	if (
		int(value["state"]) < ForagingTaskModel.State.IDLE
		or int(value["state"]) > ForagingTaskModel.State.SHARING
		or int(value["carried_portions"]) < 0
		or int(value["elapsed_ticks"]) < 0
		or int(value["duration_ticks"]) < 0
		or typeof(value["origin_zone_id"]) != TYPE_STRING
		or typeof(value["target_zone_id"]) != TYPE_STRING
		or typeof(value["nest_zone_id"]) != TYPE_STRING
		or typeof(value["route_cache_key"]) != TYPE_STRING
	):
		return _failure("Foraging task contains an invalid value")
	var route_result: Dictionary = _decode_string_names(
		value["route_zone_ids"]
	)
	if not route_result.get("ok", false):
		return route_result
	var task: ForagingTaskModel = ForagingTaskModel.new()
	task.state = int(value["state"])
	task.target_food_source_id = int(value["target_food_source_id"])
	task.origin_zone_id = StringName(value["origin_zone_id"])
	task.target_zone_id = StringName(value["target_zone_id"])
	task.nest_zone_id = StringName(value["nest_zone_id"])
	task.route_zone_ids.assign(route_result["values"])
	task.route_cache_key = String(value["route_cache_key"])
	task.carried_portions = int(value["carried_portions"])
	task.elapsed_ticks = int(value["elapsed_ticks"])
	task.duration_ticks = int(value["duration_ticks"])
	return {"ok": true, "error": "", "task": task}


static func _decode_feeding_task(value: Variant) -> Dictionary:
	if value == null:
		return {"ok": true, "error": "", "task": null}
	var keys: Array[String] = [
		"state",
		"target_brood_id",
		"origin_zone_id",
		"target_zone_id",
		"route_zone_ids",
		"elapsed_ticks",
		"duration_ticks",
		"next_decision_tick",
	]
	if not _is_dictionary_with_keys(value, keys):
		return _failure("Brood-feeding task is invalid")
	for key: String in [
		"state",
		"target_brood_id",
		"elapsed_ticks",
		"duration_ticks",
		"next_decision_tick",
	]:
		if not _is_integral_number(value[key]):
			return _failure("Brood-feeding task contains a non-integer")
	if (
		int(value["state"]) < BroodFeedingTaskModel.State.IDLE
		or int(value["state"]) > BroodFeedingTaskModel.State.FEEDING
		or int(value["elapsed_ticks"]) < 0
		or int(value["duration_ticks"]) < 0
		or int(value["next_decision_tick"]) < 0
		or typeof(value["origin_zone_id"]) != TYPE_STRING
		or typeof(value["target_zone_id"]) != TYPE_STRING
	):
		return _failure("Brood-feeding task contains an invalid value")
	var route_result: Dictionary = _decode_string_names(
		value["route_zone_ids"]
	)
	if not route_result.get("ok", false):
		return route_result
	var task: BroodFeedingTaskModel = BroodFeedingTaskModel.new()
	task.state = int(value["state"])
	task.target_brood_id = int(value["target_brood_id"])
	task.origin_zone_id = StringName(value["origin_zone_id"])
	task.target_zone_id = StringName(value["target_zone_id"])
	task.route_zone_ids.assign(route_result["values"])
	task.elapsed_ticks = int(value["elapsed_ticks"])
	task.duration_ticks = int(value["duration_ticks"])
	task.next_decision_tick = int(value["next_decision_tick"])
	return {"ok": true, "error": "", "task": task}


static func _decode_waste_cleanup_task(value: Variant) -> Dictionary:
	if value == null:
		return {"ok": true, "error": "", "task": null}
	var id_keys: Array[String] = [
		"origin_zone_id",
		"source_zone_id",
		"target_zone_id",
	]
	var int_keys: Array[String] = [
		"state",
		"target_tray_facility_id",
		"elapsed_ticks",
		"duration_ticks",
		"next_decision_tick",
	]
	var keys: Array[String] = []
	keys.append_array(id_keys)
	keys.append_array(int_keys)
	keys.append_array([
		"route_zone_ids",
		"reserved_amount",
		"carried_amount",
	])
	if not _is_dictionary_with_keys(value, keys):
		return _failure("Waste-cleanup task is invalid")
	for key: String in id_keys:
		if typeof(value[key]) != TYPE_STRING:
			return _failure("Waste-cleanup task has a non-string ID")
	for key: String in int_keys:
		if not _is_integral_number(value[key]):
			return _failure("Waste-cleanup task has a non-integer")
	if (
		int(value["state"]) < WasteCleanupTaskModel.State.IDLE
		or int(value["state"]) > WasteCleanupTaskModel.State.DROPPING
		or int(value["elapsed_ticks"]) < 0
		or int(value["duration_ticks"]) < 0
		or int(value["next_decision_tick"]) < 0
		or not _is_finite_number(value["reserved_amount"])
		or not _is_finite_number(value["carried_amount"])
		or float(value["reserved_amount"]) < 0.0
		or float(value["carried_amount"]) < 0.0
	):
		return _failure("Waste-cleanup task has invalid data")
	var route_result: Dictionary = _decode_string_names(
		value["route_zone_ids"]
	)
	if not route_result.get("ok", false):
		return route_result
	var task: WasteCleanupTaskModel = WasteCleanupTaskModel.new()
	task.state = int(value["state"])
	task.origin_zone_id = StringName(value["origin_zone_id"])
	task.source_zone_id = StringName(value["source_zone_id"])
	task.target_tray_facility_id = int(
		value["target_tray_facility_id"]
	)
	task.target_zone_id = StringName(value["target_zone_id"])
	task.route_zone_ids.assign(route_result["values"])
	task.reserved_amount = float(value["reserved_amount"])
	task.carried_amount = float(value["carried_amount"])
	task.elapsed_ticks = int(value["elapsed_ticks"])
	task.duration_ticks = int(value["duration_ticks"])
	task.next_decision_tick = int(value["next_decision_tick"])
	return {"ok": true, "error": "", "task": task}


static func _decode_scout_task(value: Variant) -> Dictionary:
	if value == null:
		return {"ok": true, "error": "", "task": null}
	var keys: Array[String] = [
		"state",
		"origin_zone_id",
		"target_zone_id",
		"route_zone_ids",
		"elapsed_ticks",
		"duration_ticks",
		"next_decision_tick",
	]
	if not _is_dictionary_with_keys(value, keys):
		return _failure("Scout task is invalid")
	for key: String in [
		"state",
		"elapsed_ticks",
		"duration_ticks",
		"next_decision_tick",
	]:
		if not _is_integral_number(value[key]):
			return _failure("Scout task has a non-integer")
	if (
		int(value["state"]) < ScoutTaskModel.State.IDLE
		or int(value["state"]) > ScoutTaskModel.State.RETURNING
		or int(value["elapsed_ticks"]) < 0
		or int(value["duration_ticks"]) < 0
		or int(value["next_decision_tick"]) < 0
		or typeof(value["origin_zone_id"]) != TYPE_STRING
		or typeof(value["target_zone_id"]) != TYPE_STRING
	):
		return _failure("Scout task has invalid data")
	var route_result: Dictionary = _decode_string_names(
		value["route_zone_ids"]
	)
	if not route_result.get("ok", false):
		return route_result
	var task: ScoutTaskModel = ScoutTaskModel.new()
	task.state = int(value["state"])
	task.origin_zone_id = StringName(value["origin_zone_id"])
	task.target_zone_id = StringName(value["target_zone_id"])
	task.route_zone_ids.assign(route_result["values"])
	task.elapsed_ticks = int(value["elapsed_ticks"])
	task.duration_ticks = int(value["duration_ticks"])
	task.next_decision_tick = int(value["next_decision_tick"])
	return {"ok": true, "error": "", "task": task}


static func _decode_migration_task(value: Variant) -> Dictionary:
	if value == null:
		return {"ok": true, "error": "", "task": null}
	var keys: Array[String] = [
		"state",
		"origin_zone_id",
		"member_origin_zone_id",
		"target_entity_id",
		"target_zone_id",
		"carried_entity_id",
		"route_zone_ids",
		"returning_to_origin",
		"elapsed_ticks",
		"duration_ticks",
		"next_decision_tick",
	]
	if not _is_dictionary_with_keys(value, keys):
		return _failure("Migration task is invalid")
	for key: String in [
		"state",
		"target_entity_id",
		"carried_entity_id",
		"elapsed_ticks",
		"duration_ticks",
		"next_decision_tick",
	]:
		if not _is_integral_number(value[key]):
			return _failure("Migration task has a non-integer")
	if (
		int(value["state"]) < MigrationTaskModel.State.IDLE
		or int(value["state"]) > MigrationTaskModel.State.DROPPING
		or int(value["elapsed_ticks"]) < 0
		or int(value["duration_ticks"]) < 0
		or int(value["next_decision_tick"]) < 0
		or typeof(value["origin_zone_id"]) != TYPE_STRING
		or typeof(value["member_origin_zone_id"]) != TYPE_STRING
		or typeof(value["target_zone_id"]) != TYPE_STRING
		or typeof(value["returning_to_origin"]) != TYPE_BOOL
	):
		return _failure("Migration task has invalid data")
	var route_result: Dictionary = _decode_string_names(
		value["route_zone_ids"]
	)
	if not route_result.get("ok", false):
		return route_result
	var task: MigrationTaskModel = MigrationTaskModel.new()
	task.state = int(value["state"])
	task.origin_zone_id = StringName(value["origin_zone_id"])
	task.member_origin_zone_id = StringName(
		value["member_origin_zone_id"]
	)
	task.target_entity_id = int(value["target_entity_id"])
	task.target_zone_id = StringName(value["target_zone_id"])
	task.carried_entity_id = int(value["carried_entity_id"])
	task.route_zone_ids.assign(route_result["values"])
	task.returning_to_origin = bool(value["returning_to_origin"])
	task.elapsed_ticks = int(value["elapsed_ticks"])
	task.duration_ticks = int(value["duration_ticks"])
	task.next_decision_tick = int(value["next_decision_tick"])
	return {"ok": true, "error": "", "task": task}


static func _decode_zone_state(value: Variant) -> Dictionary:
	if not _is_dictionary_with_keys(
		value,
		[
			"zone_id",
			"humidity",
			"light_exposure",
			"pollution",
			"available",
			"discovered",
			"discovered_tick",
		]
	):
		return _failure("Zone state is invalid")
	if (
		typeof(value["zone_id"]) != TYPE_STRING
		or not _is_finite_number(value["humidity"])
		or float(value["humidity"]) < 0.0
		or float(value["humidity"]) > 1.0
		or not _is_finite_number(value["light_exposure"])
		or float(value["light_exposure"]) < 0.0
		or float(value["light_exposure"]) > 1.0
		or not _is_finite_number(value["pollution"])
		or float(value["pollution"]) < 0.0
		or float(value["pollution"]) > 1.0
		or typeof(value["available"]) != TYPE_BOOL
		or typeof(value["discovered"]) != TYPE_BOOL
		or not _is_integral_number(value["discovered_tick"])
		or int(value["discovered_tick"]) < -1
		or (
			bool(value["discovered"])
			and int(value["discovered_tick"]) < 0
		)
		or (
			not bool(value["discovered"])
			and int(value["discovered_tick"]) != -1
		)
	):
		return _failure("Zone state contains invalid data")
	return {
		"ok": true,
		"error": "",
		"zone": HabitatZoneState.new(
			StringName(value["zone_id"]),
			float(value["humidity"]),
			[],
			bool(value["available"]),
			float(value["light_exposure"]),
			float(value["pollution"]),
			bool(value["discovered"]),
			int(value["discovered_tick"])
		),
	}


static func _decode_layout_state(
	value: Variant,
	next_facility_id: int,
	next_connection_id: int
) -> Dictionary:
	if value == null:
		return {"ok": true, "error": "", "layout": null}
	if not _is_dictionary_with_keys(
		value,
		[
			"grid_size",
			"revision",
			"facilities",
			"connections",
			"supplies",
		]
	):
		return _failure("Habitat layout state is invalid")
	var grid_result: Dictionary = _decode_vector2i(value["grid_size"])
	if (
		not grid_result.get("ok", false)
		or not _is_nonnegative_int(value["revision"])
		or typeof(value["facilities"]) != TYPE_ARRAY
		or typeof(value["connections"]) != TYPE_ARRAY
		or typeof(value["supplies"]) != TYPE_ARRAY
		or next_facility_id <= 0
		or next_connection_id <= 0
	):
		return _failure("Habitat layout contains invalid data")
	var layout: HabitatLayoutState = HabitatLayoutState.new()
	layout.grid_size = grid_result["value"]
	layout.revision = int(value["revision"])
	layout._next_facility_id = next_facility_id
	layout._next_connection_id = next_connection_id
	for facility_value: Variant in value["facilities"]:
		var facility_result: Dictionary = _decode_facility_state(
			facility_value
		)
		if not facility_result.get("ok", false):
			return facility_result
		var facility: FacilityState = facility_result["facility"]
		if layout.facilities.has(facility.facility_id):
			return _failure("Habitat layout contains duplicate facilities")
		layout.facilities[facility.facility_id] = facility
	for connection_value: Variant in value["connections"]:
		var connection_result: Dictionary = _decode_connection_state(
			connection_value
		)
		if not connection_result.get("ok", false):
			return connection_result
		var connection: HabitatConnectionState = connection_result[
			"connection"
		]
		if layout.connections.has(connection.connection_id):
			return _failure("Habitat layout contains duplicate connections")
		layout.connections[connection.connection_id] = connection
	var counts: Dictionary[StringName, int] = {}
	for supply_value: Variant in value["supplies"]:
		if not _is_dictionary_with_keys(
			supply_value,
			["type_id", "remaining_count"]
		):
			return _failure("Facility supply state is invalid")
		if (
			typeof(supply_value["type_id"]) != TYPE_STRING
			or not _is_nonnegative_int(supply_value["remaining_count"])
		):
			return _failure("Facility supply state contains invalid data")
		var type_id: StringName = StringName(supply_value["type_id"])
		if type_id.is_empty() or counts.has(type_id):
			return _failure("Facility supply state contains duplicate IDs")
		counts[type_id] = int(supply_value["remaining_count"])
	layout.supply = FacilitySupplyState.new(counts)
	return {"ok": true, "error": "", "layout": layout}


static func _decode_facility_state(value: Variant) -> Dictionary:
	if not _is_dictionary_with_keys(
		value,
		[
			"facility_id",
			"type_id",
			"slot",
			"orientation",
			"zone_id",
			"available",
			"player_removable",
			"waste_stored",
		]
	):
		return _failure("Facility state is invalid")
	var slot_result: Dictionary = _decode_vector2i(value["slot"])
	if (
		not slot_result.get("ok", false)
		or not _is_positive_int(value["facility_id"])
		or typeof(value["type_id"]) != TYPE_STRING
		or not _is_integral_number(value["orientation"])
		or typeof(value["zone_id"]) != TYPE_STRING
		or typeof(value["available"]) != TYPE_BOOL
		or typeof(value["player_removable"]) != TYPE_BOOL
		or not _is_finite_number(value["waste_stored"])
		or float(value["waste_stored"]) < 0.0
	):
		return _failure("Facility state contains invalid data")
	return {
		"ok": true,
		"error": "",
		"facility": FacilityState.new(
			int(value["facility_id"]),
			StringName(value["type_id"]),
			slot_result["value"],
			int(value["orientation"]),
			StringName(value["zone_id"]),
			bool(value["available"]),
			bool(value["player_removable"]),
			float(value["waste_stored"])
		),
	}


static func _decode_connection_state(value: Variant) -> Dictionary:
	if not _is_dictionary_with_keys(
		value,
		[
			"connection_id",
			"first_zone_id",
			"second_zone_id",
			"gated",
			"open",
			"owner_facility_id",
		]
	):
		return _failure("Habitat connection state is invalid")
	if (
		not _is_positive_int(value["connection_id"])
		or typeof(value["first_zone_id"]) != TYPE_STRING
		or typeof(value["second_zone_id"]) != TYPE_STRING
		or typeof(value["gated"]) != TYPE_BOOL
		or typeof(value["open"]) != TYPE_BOOL
		or not _is_integral_number(value["owner_facility_id"])
	):
		return _failure("Habitat connection contains invalid data")
	return {
		"ok": true,
		"error": "",
		"connection": HabitatConnectionState.new(
			int(value["connection_id"]),
			StringName(value["first_zone_id"]),
			StringName(value["second_zone_id"]),
			bool(value["gated"]),
			bool(value["open"]),
			int(value["owner_facility_id"])
		),
	}


static func _decode_food_source(value: Variant) -> Dictionary:
	if not _is_dictionary_with_keys(
		value,
		[
			"entity_id",
			"zone_id",
			"remaining_portions",
			"food_type",
			"available",
		]
	):
		return _failure("Food source state is invalid")
	if (
		not _is_nonnegative_int(value["entity_id"])
		or not _is_nonnegative_int(value["remaining_portions"])
		or not _is_integral_number(value["food_type"])
		or int(value["food_type"]) < FoodSourceState.FoodType.SUGAR_WATER
		or int(value["food_type"]) > FoodSourceState.FoodType.PROTEIN
		or typeof(value["zone_id"]) != TYPE_STRING
		or typeof(value["available"]) != TYPE_BOOL
	):
		return _failure("Food source state contains an invalid value")
	return {
		"ok": true,
		"error": "",
		"source": FoodSourceState.new(
			int(value["entity_id"]),
			StringName(value["zone_id"]),
			int(value["remaining_portions"]),
			int(value["food_type"]),
			bool(value["available"])
		),
	}


static func _decode_progress(value: Variant) -> Dictionary:
	if value == null:
		return {"ok": true, "error": "", "progress": null}
	var keys: Array[String] = [
		"phase",
		"phase_entered_tick",
		"first_worker_entity_id",
		"first_worker_emerged_tick",
		"humidity_observation_completed_tick",
		"sugar_observation_completed_tick",
	]
	if not _is_dictionary_with_keys(value, keys):
		return _failure("Scenario progress state is invalid")
	for key: String in keys:
		if not _is_integral_number(value[key]):
			return _failure("Scenario progress contains a non-integer")
	if (
		int(value["phase"]) < ScenarioSequenceSnapshot.Phase.FOUNDING_PRELUDE
		or int(value["phase"])
			> ScenarioSequenceSnapshot.Phase.OBSERVATION_SUMMARY
	):
		return _failure("Scenario progress contains an invalid phase")
	var progress: ScenarioProgressState = ScenarioProgressState.new()
	progress.phase = int(value["phase"])
	progress.phase_entered_tick = int(value["phase_entered_tick"])
	progress.first_worker_entity_id = int(value["first_worker_entity_id"])
	progress.first_worker_emerged_tick = int(
		value["first_worker_emerged_tick"]
	)
	progress.humidity_observation_completed_tick = int(
		value["humidity_observation_completed_tick"]
	)
	progress.sugar_observation_completed_tick = int(
		value["sugar_observation_completed_tick"]
	)
	return {"ok": true, "error": "", "progress": progress}


static func _decode_event(value: Variant) -> Dictionary:
	var keys: Array[String] = [
		"event_id",
		"tick",
		"event_type",
		"actor_entity_id",
		"subject_entity_id",
		"source_zone_id",
		"target_zone_id",
	]
	if not _is_dictionary_with_keys(value, keys):
		return _failure("Observation event is invalid")
	for key: String in [
		"event_id",
		"tick",
		"event_type",
		"actor_entity_id",
		"subject_entity_id",
	]:
		if not _is_integral_number(value[key]):
			return _failure("Observation event contains a non-integer")
	if (
		int(value["event_id"]) <= 0
		or int(value["tick"]) < 0
		or int(value["event_type"]) < ObservationEvent.Type.RELOCATION_STARTED
		or int(value["event_type"])
			> ObservationEvent.Type.MIGRATION_COMPLETED
		or typeof(value["source_zone_id"]) != TYPE_STRING
		or typeof(value["target_zone_id"]) != TYPE_STRING
	):
		return _failure("Observation event contains an invalid value")
	return {
		"ok": true,
		"error": "",
		"event": ObservationEvent.new(
			int(value["event_id"]),
			int(value["tick"]),
			int(value["event_type"]),
			int(value["actor_entity_id"]),
			int(value["subject_entity_id"]),
			StringName(value["source_zone_id"]),
			StringName(value["target_zone_id"])
		),
	}


static func _decode_pending_commands(
	values: Array,
	next_sequence_id: int
) -> Dictionary:
	if next_sequence_id <= 0:
		return _failure("Pending command sequence is invalid")
	var commands: Array[PendingSimulationCommand] = []
	var previous_sequence_id: int = 0
	for value: Variant in values:
		if not _is_dictionary_with_keys(
			value,
			[
				"sequence_id",
				"command_type",
				"argument_id",
				"argument_entity_id",
				"argument_slot",
				"argument_orientation",
				"argument_flag",
			]
		):
			return _failure("Pending command record is invalid")
		var slot_result: Dictionary = _decode_vector2i(
			value["argument_slot"]
		)
		if (
			not slot_result.get("ok", false)
			or not _is_positive_int(value["sequence_id"])
			or not _is_integral_number(value["command_type"])
			or typeof(value["argument_id"]) != TYPE_STRING
			or not _is_integral_number(value["argument_entity_id"])
			or not _is_integral_number(value["argument_orientation"])
			or typeof(value["argument_flag"]) != TYPE_BOOL
		):
			return _failure("Pending command record contains invalid data")
		var sequence_id: int = int(value["sequence_id"])
		var command_type: int = int(value["command_type"])
		var argument_id: StringName = StringName(value["argument_id"])
		if (
			sequence_id <= previous_sequence_id
			or sequence_id >= next_sequence_id
			or command_type < ColonySimulation.PendingCommandType.WATER_ACTION
			or command_type
				> ColonySimulation.PendingCommandType
					.CLEAN_WASTE_TRAY_ACTION
		):
			return _failure("Pending command ordering or type is invalid")
		commands.append(PendingSimulationCommand.new(
			sequence_id,
			command_type,
			argument_id,
			int(value["argument_entity_id"]),
			slot_result["value"],
			int(value["argument_orientation"]),
			bool(value["argument_flag"])
		))
		previous_sequence_id = sequence_id
	return {"ok": true, "error": "", "commands": commands}


static func _event_subject_is_valid(
	event: ObservationEvent,
	entity_ids: Dictionary[int, bool],
	state: ColonyState
) -> bool:
	if entity_ids.has(event.subject_entity_id):
		return true
	if event.event_type in [
		ObservationEvent.Type.WASTE_CLEANUP_STARTED,
		ObservationEvent.Type.WASTE_PICKED_UP,
		ObservationEvent.Type.WASTE_DELIVERED,
		ObservationEvent.Type.WASTE_TRAY_CLEANED,
	]:
		return (
			state.layout_state != null
			and state.layout_state.get_facility(
				event.subject_entity_id
			) != null
		)
	return false


static func _has_valid_core_state(simulation: ColonySimulation) -> bool:
	var state: ColonyState = simulation._state
	if (
		state == null
		or state.queen == null
		or state.queen.entity_id != ColonyState.QUEEN_ENTITY_ID
		or state.simulation_tick < 0
		or state._next_entity_id <= 0
		or state._next_observation_event_id <= 0
		or state._observation_events.size()
			> ColonyState.MAX_RETAINED_OBSERVATION_EVENTS
	):
		return false
	var entity_ids: Dictionary[int, bool] = {
		state.queen.entity_id: true,
	}
	var maximum_entity_id: int = state.queen.entity_id
	var previous_ant_id: int = 0
	for ant: AntModel in state.ants:
		if (
			ant == null
			or ant.entity_id <= 0
			or ant.entity_id <= previous_ant_id
			or entity_ids.has(ant.entity_id)
			or ant.total_age_ticks < 0
			or ant.stage_age_ticks < 0
			or ant.stage_age_ticks > ant.total_age_ticks
			or not _has_valid_ant_state(ant, simulation)
		):
			return false
		entity_ids[ant.entity_id] = true
		maximum_entity_id = maxi(maximum_entity_id, ant.entity_id)
		previous_ant_id = ant.entity_id
	var previous_source_id: int = 0
	for source: FoodSourceState in state.food_sources:
		if (
			source == null
			or source.entity_id <= 0
			or source.entity_id <= previous_source_id
			or entity_ids.has(source.entity_id)
		):
			return false
		entity_ids[source.entity_id] = true
		maximum_entity_id = maxi(maximum_entity_id, source.entity_id)
		previous_source_id = source.entity_id
	if state._next_entity_id <= maximum_entity_id:
		return false

	var zone_ids: Dictionary[StringName, bool] = {}
	for zone: HabitatZoneState in state.zones:
		if (
			zone == null
			or zone.zone_id.is_empty()
			or zone_ids.has(zone.zone_id)
			or not _is_finite_number(zone.humidity)
			or zone.humidity < 0.0
			or zone.humidity > 1.0
			or not _is_finite_number(zone.light_exposure)
			or zone.light_exposure < 0.0
			or zone.light_exposure > 1.0
			or not _is_finite_number(zone.pollution)
			or zone.pollution < 0.0
			or zone.pollution > 1.0
			or zone.discovered_tick < -1
			or (zone.discovered and zone.discovered_tick < 0)
			or (not zone.discovered and zone.discovered_tick != -1)
		):
			return false
		zone_ids[zone.zone_id] = true
	for zone: HabitatZoneState in state.zones:
		for connected_zone_id: StringName in zone.connected_zone_ids:
			if not zone_ids.has(connected_zone_id):
				return false
	for source: FoodSourceState in state.food_sources:
		if (
			not zone_ids.has(source.zone_id)
			or (
				source.food_type == FoodSourceState.FoodType.PROTEIN
				and simulation._nutrition_system == null
			)
		):
			return false

	var previous_event_id: int = 0
	for event: ObservationEvent in state._observation_events:
		if (
			event == null
			or event.event_id <= previous_event_id
			or event.event_id >= state._next_observation_event_id
			or event.tick < 0
			or event.tick > state.simulation_tick
			or (
				event.actor_entity_id != ObservationEvent.NO_ENTITY_ID
				and not entity_ids.has(event.actor_entity_id)
			)
			or (
				event.subject_entity_id != ObservationEvent.NO_ENTITY_ID
				and not _event_subject_is_valid(
					event,
					entity_ids,
					state
				)
			)
			or (
				not event.source_zone_id.is_empty()
				and not zone_ids.has(event.source_zone_id)
			)
			or (
				not event.target_zone_id.is_empty()
				and not zone_ids.has(event.target_zone_id)
			)
		):
			return false
		previous_event_id = event.event_id

	if not simulation.has_habitat():
		return (
			state.queen.laid_egg_count == state.ants.size()
			and state.zones.is_empty()
			and state.food_sources.is_empty()
			and state.layout_state == null
			and state.scenario_progress == null
			and state.campaign_state == null
			and state.nutrition_state == null
			and state.act1_state == null
			and state.colony_work_state == null
			and state.queen.zone_id.is_empty()
			and state.humidity_adjustment_count == 0
			and state.observation_stable_ticks == 0
			and state.shared_sugar_portions == 0
			and state.total_sugar_portions_placed == 0
			and state.unlocked_observation_card_ids.is_empty()
		)
	if (
		state.layout_state == null
		or not _state_graph_matches_frozen_config(simulation)
	):
		return false
	if simulation._supports_nutrition_growth():
		if simulation._habitat_config.is_act1_test_tube():
			var initial_act1_brood_count: int = (
				simulation._habitat_config.initial_brood_count + 1
			)
			if (
				state.queen.laid_egg_count != initial_act1_brood_count
				or state.ants.size() != initial_act1_brood_count
			):
				return false
		elif (
			state.queen.laid_egg_count < 0
			or state.queen.laid_egg_count
				> simulation._lifecycle_config.max_first_generation_brood
			or state.ants.size()
				!= simulation._habitat_config.initial_worker_count
					+ simulation._habitat_config.initial_brood_count
					+ state.queen.laid_egg_count
		):
			return false
	elif (
		state.queen.laid_egg_count != 0
		or state.nutrition_state != null
		or state.act1_state != null
	):
		return false
	return simulation.has_valid_habitat_ownership()


static func _has_valid_ant_state(
	ant: AntModel,
	simulation: ColonySimulation
) -> bool:
	if (
		ant.life_stage < AntModel.LifeStage.EGG
		or ant.life_stage > AntModel.LifeStage.WORKER
	):
		return false
	if ant.life_stage != AntModel.LifeStage.WORKER:
		if (
			ant.worker_task != null
			or ant.foraging_task != null
			or ant.feeding_task != null
			or ant.waste_cleanup_task != null
			or ant.scout_task != null
			or ant.migration_task != null
		):
			return false
		var stage_duration: int = simulation.get_stage_duration_ticks(
			ant.life_stage
		)
		if stage_duration <= 0 or ant.stage_age_ticks >= stage_duration:
			return false
	elif simulation.has_habitat():
		if (
			ant.worker_task == null
			or ant.foraging_task == null
			or ant.waste_cleanup_task == null
			or ant.scout_task == null
			or ant.migration_task == null
		):
			return false
		if (
			simulation._supports_nutrition_growth()
			!= (ant.feeding_task != null)
		):
			return false
	else:
		if (
			ant.worker_task != null
			or ant.foraging_task != null
			or ant.feeding_task != null
			or ant.waste_cleanup_task != null
			or ant.scout_task != null
			or ant.migration_task != null
		):
			return false

	if (
		ant.protein_supported_growth_ticks < 0
		or (
			not simulation._supports_nutrition_growth()
			and ant.protein_supported_growth_ticks != 0
		)
		or (
			ant.life_stage != AntModel.LifeStage.LARVA
			and ant.protein_supported_growth_ticks != 0
		)
	):
		return false

	if not simulation.has_habitat():
		return ant.zone_id.is_empty()
	if ant.life_stage == AntModel.LifeStage.WORKER:
		if (
			ant.zone_id.is_empty()
			or simulation._state.get_zone(ant.zone_id) == null
		):
			return false
	if ant.worker_task != null:
		var worker_task: WorkerTaskModel = ant.worker_task
		if (
			worker_task.state == WorkerTaskModel.State.IDLE
			and (
				worker_task.elapsed_ticks != 0
				or worker_task.duration_ticks != 0
			)
		):
			return false
		if (
			worker_task.state != WorkerTaskModel.State.IDLE
			and (
				worker_task.duration_ticks <= 0
				or worker_task.elapsed_ticks < 0
				or worker_task.elapsed_ticks >= worker_task.duration_ticks
				or simulation._state.get_zone(
					worker_task.origin_zone_id
				) == null
				or simulation._state.get_zone(
					worker_task.target_zone_id
				) == null
			)
		):
			return false
	if ant.foraging_task != null:
		var foraging_task: ForagingTaskModel = ant.foraging_task
		if (
			foraging_task.state == ForagingTaskModel.State.IDLE
			and (
				foraging_task.elapsed_ticks != 0
				or foraging_task.duration_ticks != 0
			)
		):
			return false
		if (
			foraging_task.state != ForagingTaskModel.State.IDLE
			and (
				foraging_task.duration_ticks <= 0
				or foraging_task.elapsed_ticks < 0
				or foraging_task.elapsed_ticks
					>= foraging_task.duration_ticks
				or foraging_task.route_zone_ids.is_empty()
				or simulation._state.get_zone(
					foraging_task.origin_zone_id
				) == null
				or simulation._state.get_zone(
					foraging_task.target_zone_id
				) == null
				or simulation._state.get_zone(
					foraging_task.nest_zone_id
				) == null
			)
		):
			return false
		for route_zone_id: StringName in foraging_task.route_zone_ids:
			if simulation._state.get_zone(route_zone_id) == null:
				return false
	if not _has_valid_colony_work_task_state(ant, simulation):
		return false
	return true


static func _has_valid_colony_work_task_state(
	ant: AntModel,
	simulation: ColonySimulation
) -> bool:
	if ant.waste_cleanup_task != null:
		var waste: WasteCleanupTaskModel = ant.waste_cleanup_task
		if (
			waste.next_decision_tick < 0
			or not _is_finite_number(waste.reserved_amount)
			or not _is_finite_number(waste.carried_amount)
			or waste.reserved_amount < 0.0
			or waste.carried_amount < 0.0
		):
			return false
		if waste.state == WasteCleanupTaskModel.State.IDLE:
			if (
				not waste.origin_zone_id.is_empty()
				or not waste.source_zone_id.is_empty()
				or waste.target_tray_facility_id != -1
				or not waste.target_zone_id.is_empty()
				or not waste.route_zone_ids.is_empty()
				or not is_zero_approx(waste.reserved_amount)
				or not is_zero_approx(waste.carried_amount)
				or waste.elapsed_ticks != 0
				or waste.duration_ticks != 0
			):
				return false
		elif (
			waste.duration_ticks <= 0
			or waste.elapsed_ticks < 0
			or waste.elapsed_ticks >= waste.duration_ticks
			or simulation._state.get_zone(waste.origin_zone_id) == null
			or simulation._state.get_zone(waste.source_zone_id) == null
			or simulation._state.get_zone(waste.target_zone_id) == null
			or simulation._state.layout_state.get_facility(
				waste.target_tray_facility_id
			) == null
		):
			return false
	if ant.scout_task != null:
		var scout: ScoutTaskModel = ant.scout_task
		if scout.next_decision_tick < 0:
			return false
		if scout.state == ScoutTaskModel.State.IDLE:
			if (
				not scout.origin_zone_id.is_empty()
				or not scout.target_zone_id.is_empty()
				or not scout.route_zone_ids.is_empty()
				or scout.elapsed_ticks != 0
				or scout.duration_ticks != 0
			):
				return false
		elif (
			scout.duration_ticks <= 0
			or scout.elapsed_ticks < 0
			or scout.elapsed_ticks >= scout.duration_ticks
			or simulation._state.get_zone(scout.origin_zone_id) == null
			or simulation._state.get_zone(scout.target_zone_id) == null
		):
			return false
	if ant.migration_task != null:
		var migration: MigrationTaskModel = ant.migration_task
		if migration.next_decision_tick < 0:
			return false
		if migration.state == MigrationTaskModel.State.IDLE:
			if (
				not migration.origin_zone_id.is_empty()
				or not migration.member_origin_zone_id.is_empty()
				or migration.target_entity_id != -1
				or not migration.target_zone_id.is_empty()
				or migration.carried_entity_id != -1
				or not migration.route_zone_ids.is_empty()
				or migration.returning_to_origin
				or migration.elapsed_ticks != 0
				or migration.duration_ticks != 0
			):
				return false
		elif (
			migration.duration_ticks <= 0
			or migration.elapsed_ticks < 0
			or migration.elapsed_ticks >= migration.duration_ticks
			or simulation._state.get_zone(
				migration.member_origin_zone_id
			) == null
			or simulation._state.get_zone(
				migration.target_zone_id
			) == null
			or (
				migration.target_entity_id
					!= simulation._state.queen.entity_id
				and simulation._state.get_ant(
					migration.target_entity_id
				) == null
			)
		):
			return false
	return true


static func _state_graph_matches_frozen_config(
	simulation: ColonySimulation
) -> bool:
	var state: ColonyState = simulation._state
	var config: HabitatScenarioConfig = simulation._habitat_config
	if (
		config == null
		or (
			config.is_combined_observation()
			!= (state.scenario_progress != null)
		)
		or (
			(config.is_combined_observation() or config.is_act1_test_tube())
			!= (state.campaign_state != null)
		)
		or (
			config.supports_nutrition_growth()
			!= (state.nutrition_state != null)
		)
		or (
			config.is_act1_test_tube()
			!= (state.act1_state != null)
		)
		or (
			(config.colony_work_config != null)
			!= (state.colony_work_state != null)
		)
	):
		return false
	if state.zones.size() < config.zones.size():
		return false
	for zone_index: int in config.zones.size():
		var state_zone: HabitatZoneState = state.zones[zone_index]
		var config_zone: HabitatZoneState = config.zones[zone_index]
		if state_zone.zone_id != config_zone.zone_id:
			return false
	return simulation._has_valid_layout_state(state)


static func _has_valid_pending_commands(
	simulation: ColonySimulation
) -> bool:
	var seen_types: Dictionary[int, bool] = {}
	var has_layout_command: bool = false
	for command: PendingSimulationCommand in simulation._pending_commands:
		if command == null or seen_types.has(command.command_type):
			return false
		seen_types[command.command_type] = true
		match command.command_type:
			ColonySimulation.PendingCommandType.WATER_ACTION:
				if (
					not command.argument_id.is_empty()
					or not _has_neutral_extended_arguments(command)
					or not _can_restore_water_command(simulation)
				):
					return false
			ColonySimulation.PendingCommandType.PLACE_SUGAR_ACTION:
				if (
					not command.argument_id.is_empty()
					or not _has_neutral_extended_arguments(command)
					or not _can_restore_sugar_command(simulation)
				):
					return false
			ColonySimulation.PendingCommandType.CONTINUE_OBSERVATION_ACTION:
				if (
					not command.argument_id.is_empty()
					or not _has_neutral_extended_arguments(command)
					or simulation._scenario_director == null
					or not simulation._scenario_director
						.is_identity_continue_available(simulation._state)
				):
					return false
			ColonySimulation.PendingCommandType.SELECT_CAMPAIGN_INFERENCE_ACTION:
				if (
					command.argument_id.is_empty()
					or not _has_neutral_extended_arguments(command)
					or (
						simulation._campaign_director == null
						and simulation._act1_campaign_director == null
					)
					or not (
						simulation._campaign_director != null
						and simulation._campaign_director
							.is_inference_action_available(
								simulation._state,
								command.argument_id
							)
						or simulation._act1_campaign_director != null
						and simulation._act1_campaign_director
							.is_inference_action_available(
								simulation._state,
								command.argument_id
							)
					)
				):
					return false
			ColonySimulation.PendingCommandType.PLACE_PROTEIN_ACTION:
				if (
					not command.argument_id.is_empty()
					or not _has_neutral_extended_arguments(command)
					or not _can_restore_protein_command(simulation)
				):
					return false
			ColonySimulation.PendingCommandType.APPLY_LIGHT_COVER_ACTION:
				if (
					not command.argument_id.is_empty()
					or not _has_neutral_extended_arguments(command)
					or not simulation._can_apply_light_cover_now()
					or simulation._has_pending_layout_command()
				):
					return false
			ColonySimulation.PendingCommandType.PLACE_FACILITY_ACTION:
				if (
					has_layout_command
					or command.argument_id.is_empty()
					or command.argument_id
						== CampaignState.FACILITY_LIGHT_COVER
					or command.argument_entity_id != -1
					or command.argument_flag
					or not simulation._has_layout_authority()
					or not simulation._state.layout_state.can_place(
						simulation._habitat_config
							.facility_catalog_config,
						command.argument_id,
						command.argument_slot,
						command.argument_orientation,
						simulation._state.campaign_state
							.unlocked_facility_type_ids
					)
				):
					return false
				has_layout_command = true
			ColonySimulation.PendingCommandType.ROTATE_FACILITY_ACTION:
				if (
					has_layout_command
					or not command.argument_id.is_empty()
					or command.argument_entity_id <= 0
					or command.argument_slot != Vector2i.ZERO
					or command.argument_flag
					or not simulation._has_layout_authority()
					or not simulation._state.layout_state.can_rotate(
						simulation._habitat_config
							.facility_catalog_config,
						command.argument_entity_id,
						command.argument_orientation,
						simulation._state.campaign_state
							.unlocked_facility_type_ids
					)
				):
					return false
				has_layout_command = true
			ColonySimulation.PendingCommandType.REMOVE_FACILITY_ACTION:
				if (
					has_layout_command
					or not command.argument_id.is_empty()
					or command.argument_entity_id <= 0
					or command.argument_slot != Vector2i.ZERO
					or command.argument_orientation != 0
					or command.argument_flag
					or not simulation._can_remove_facility_now(
						command.argument_entity_id
					)
				):
					return false
				has_layout_command = true
			ColonySimulation.PendingCommandType.SET_GATE_OPEN_ACTION:
				if (
					has_layout_command
					or not command.argument_id.is_empty()
					or command.argument_entity_id <= 0
					or command.argument_slot != Vector2i.ZERO
					or command.argument_orientation != 0
					or not _can_restore_gate_command(
						simulation,
						command.argument_entity_id,
						command.argument_flag
					)
				):
					return false
				has_layout_command = true
			ColonySimulation.PendingCommandType.CLEAN_WASTE_TRAY_ACTION:
				if (
					not command.argument_id.is_empty()
					or command.argument_entity_id <= 0
					or command.argument_slot != Vector2i.ZERO
					or command.argument_orientation != 0
					or command.argument_flag
					or simulation._colony_work_system == null
					or not simulation._colony_work_system
						.is_clean_action_available(
							simulation._state,
							command.argument_entity_id
						)
				):
					return false
			_:
				return false
	return true


static func _has_neutral_extended_arguments(
	command: PendingSimulationCommand
) -> bool:
	return (
		command.argument_entity_id == -1
		and command.argument_slot == Vector2i.ZERO
		and command.argument_orientation == 0
		and not command.argument_flag
	)


static func _can_restore_gate_command(
	simulation: ColonySimulation,
	connection_id: int,
	open: bool
) -> bool:
	if not simulation._has_layout_authority():
		return false
	var connection: HabitatConnectionState = (
		simulation._state.layout_state.get_connection(connection_id)
	)
	return (
		connection != null
		and connection.gated
		and connection.open != open
		and (open or not simulation._has_any_active_worker_task())
	)


static func _can_restore_water_command(
	simulation: ColonySimulation
) -> bool:
	if (
		not simulation._supports_humidity_relocation()
		or not simulation._state.water_action_unlocked
		or simulation._state.brood_humidity_observation_unlocked
		or simulation._is_water_target_comfortable()
		or (
			simulation._scenario_director != null
			and not simulation._scenario_director
				.is_humidity_phase_active(simulation._state)
		)
	):
		return false
	var zone: HabitatZoneState = simulation._state.get_zone(
		simulation._habitat_config.humidity_adjustment_zone_id
	)
	return zone != null and zone.available


static func _can_restore_sugar_command(
	simulation: ColonySimulation
) -> bool:
	if (
		not simulation._supports_sugar_foraging()
		or (
			simulation._habitat_config.is_act1_test_tube()
			and (
				simulation._act1_campaign_director == null
				or not simulation._act1_campaign_director
					.is_sugar_action_active(simulation._state)
			)
		)
		or (
			simulation._scenario_director != null
			and not simulation._scenario_director
				.is_foraging_phase_active(simulation._state)
		)
	):
		return false
	if simulation._supports_nutrition_growth():
		if simulation._foraging_system.has_available_source_type(
			simulation._state,
			FoodSourceState.FoodType.SUGAR_WATER
		):
			return false
	elif (
		simulation._state.total_sugar_portions_placed > 0
		or simulation._state.unlocked_observation_card_ids.has(
			simulation._habitat_config.foraging_observation_card_id
		)
	):
		return false
	var zone: HabitatZoneState = simulation._state.get_zone(
		simulation._find_food_station_zone_id(
			FoodSourceState.FoodType.SUGAR_WATER,
			simulation._habitat_config.sugar_placement_zone_id
		)
	)
	return zone != null and zone.available


static func _can_restore_protein_command(
	simulation: ColonySimulation
) -> bool:
	if (
		not simulation._supports_nutrition_growth()
		or simulation._habitat_config.is_act1_test_tube()
	):
		return false
	var zone: HabitatZoneState = simulation._state.get_zone(
		simulation._find_food_station_zone_id(
			FoodSourceState.FoodType.PROTEIN,
			simulation._habitat_config.protein_placement_zone_id
		)
	)
	return (
		zone != null
		and zone.available
		and not simulation._foraging_system.has_available_source_type(
			simulation._state,
			FoodSourceState.FoodType.PROTEIN
		)
	)


static func _decode_string_names(
	value: Variant,
	require_unique: bool = false
) -> Dictionary:
	if typeof(value) != TYPE_ARRAY:
		return _failure("Expected an array of strings")
	var values: Array[StringName] = []
	var seen: Dictionary[StringName, bool] = {}
	for item: Variant in value:
		if typeof(item) != TYPE_STRING:
			return _failure("Expected an array of strings")
		var name: StringName = StringName(item)
		if require_unique and (name.is_empty() or seen.has(name)):
			return _failure("String ID collection is invalid")
		seen[name] = true
		values.append(name)
	return {"ok": true, "error": "", "values": values}


static func _decode_vector2i(value: Variant) -> Dictionary:
	if (
		typeof(value) != TYPE_ARRAY
		or value.size() != 2
		or not _is_integral_number(value[0])
		or not _is_integral_number(value[1])
	):
		return _failure("Vector2i payload is invalid")
	return {
		"ok": true,
		"error": "",
		"value": Vector2i(int(value[0]), int(value[1])),
	}


static func _strings_from_names(values: Array) -> Array[String]:
	var result: Array[String] = []
	for value: StringName in values:
		result.append(String(value))
	return result


static func _is_dictionary_with_keys(
	value: Variant,
	keys: Array[String]
) -> bool:
	return typeof(value) == TYPE_DICTIONARY and _has_exact_keys(value, keys)


static func _has_exact_keys(
	value: Dictionary,
	keys: Array[String]
) -> bool:
	if value.size() != keys.size():
		return false
	for key: String in keys:
		if not value.has(key):
			return false
	return true


static func _is_finite_number(value: Variant) -> bool:
	if typeof(value) != TYPE_INT and typeof(value) != TYPE_FLOAT:
		return false
	var number: float = float(value)
	return not is_nan(number) and not is_inf(number)


static func _is_integral_number(value: Variant) -> bool:
	return (
		_is_finite_number(value)
		and float(value) == floorf(float(value))
	)


static func _is_nonnegative_int(value: Variant) -> bool:
	return _is_integral_number(value) and int(value) >= 0


static func _is_positive_int(value: Variant) -> bool:
	return _is_integral_number(value) and int(value) > 0


static func _failure(message: String) -> Dictionary:
	return {"ok": false, "error": message}
