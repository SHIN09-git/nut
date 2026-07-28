class_name SimulationStateCodec
extends RefCounted

const CURRENT_SCHEMA_ID: String = "r4.authority.v2"
const PREVIOUS_SCHEMA_ID: String = "r2.authority.v1"
const LEGACY_SCHEMA_ID: String = "r2.authority.v0"


static func encode_simulation(simulation: ColonySimulation) -> Dictionary:
	if simulation == null or not simulation.is_ready():
		return {}
	return {
		"frozen_config_bundle": _encode_frozen_config(simulation),
		"next_ids": {
			"entity_id": simulation._state._next_entity_id,
			"observation_event_id":
				simulation._state._next_observation_event_id,
			"pending_command_sequence_id":
				simulation._next_pending_command_sequence_id,
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
		zones.append(_encode_zone(zone))
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
	}


static func _encode_state(state: ColonyState) -> Dictionary:
	var ants: Array[Dictionary] = []
	for ant: AntModel in state.ants:
		ants.append(_encode_ant(ant))
	var zones: Array[Dictionary] = []
	for zone: HabitatZoneState in state.zones:
		zones.append(_encode_zone(zone))
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
	return {
		"simulation_tick": state.simulation_tick,
		"queen": {
			"entity_id": state.queen.entity_id,
			"laid_egg_count": state.queen.laid_egg_count,
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
	return {
		"entity_id": ant.entity_id,
		"life_stage": ant.life_stage,
		"total_age_ticks": ant.total_age_ticks,
		"stage_age_ticks": ant.stage_age_ticks,
		"zone_id": String(ant.zone_id),
		"zone_entered_tick": ant.zone_entered_tick,
		"worker_task": worker_task,
		"foraging_task": foraging_task,
	}


static func _encode_zone(zone: HabitatZoneState) -> Dictionary:
	return {
		"zone_id": String(zone.zone_id),
		"humidity": zone.humidity,
		"connected_zone_ids":
			_strings_from_names(zone.connected_zone_ids),
		"available": zone.available,
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
	]:
		if not _is_integral_number(value[key]):
			return _failure("Habitat configuration contains a non-integer")
	if (
		not _is_finite_number(value["humidity_adjustment_amount"])
		or typeof(value["zones"]) != TYPE_ARRAY
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
	if not habitat.is_valid():
		return _failure("Frozen habitat configuration is not valid")
	return {"ok": true, "error": "", "habitat_data": habitat}


static func _decode_zone_data(value: Variant) -> Dictionary:
	if not _is_dictionary_with_keys(
		value,
		["zone_id", "humidity", "connected_zone_ids", "available"]
	):
		return _failure("Zone configuration is invalid")
	if (
		typeof(value["zone_id"]) != TYPE_STRING
		or not _is_finite_number(value["humidity"])
		or typeof(value["connected_zone_ids"]) != TYPE_ARRAY
		or typeof(value["available"]) != TYPE_BOOL
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
	zone.connected_zone_ids.assign(connections_result["values"])
	zone.available = bool(value["available"])
	if not zone.is_valid():
		return _failure("Frozen zone configuration is not valid")
	return {"ok": true, "error": "", "zone_data": zone}


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
		["entity_id", "laid_egg_count"]
	):
		return _failure("Queen state is invalid")
	if (
		not _is_nonnegative_int(payload["queen"]["entity_id"])
		or not _is_nonnegative_int(payload["queen"]["laid_egg_count"])
	):
		return _failure("Queen state contains an invalid counter")

	var state: ColonyState = ColonyState.new()
	state.simulation_tick = int(payload["simulation_tick"])
	state.queen = QueenModel.new(int(payload["queen"]["entity_id"]))
	state.queen.laid_egg_count = int(payload["queen"]["laid_egg_count"])
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
			"worker_task",
			"foraging_task",
		]
	):
		return _failure("Ant state is invalid")
	for key: String in [
		"entity_id",
		"life_stage",
		"total_age_ticks",
		"stage_age_ticks",
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


static func _decode_zone_state(value: Variant) -> Dictionary:
	var data_result: Dictionary = _decode_zone_data(value)
	if not data_result.get("ok", false):
		return data_result
	var data: HabitatZoneData = data_result["zone_data"]
	return {
		"ok": true,
		"error": "",
		"zone": HabitatZoneState.new(
			data.zone_id,
			data.initial_humidity,
			data.connected_zone_ids,
			data.available
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
		or int(value["food_type"]) != FoodSourceState.FoodType.SUGAR_WATER
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
			> ObservationEvent.Type.OBSERVATION_SESSION_COMPLETED
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
			["sequence_id", "command_type", "argument_id"]
		):
			return _failure("Pending command record is invalid")
		if (
			not _is_positive_int(value["sequence_id"])
			or not _is_integral_number(value["command_type"])
			or typeof(value["argument_id"]) != TYPE_STRING
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
					.SELECT_CAMPAIGN_INFERENCE_ACTION
		):
			return _failure("Pending command ordering or type is invalid")
		commands.append(PendingSimulationCommand.new(
			sequence_id,
			command_type,
			argument_id
		))
		previous_sequence_id = sequence_id
	return {"ok": true, "error": "", "commands": commands}


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
		):
			return false
		zone_ids[zone.zone_id] = true
	for zone: HabitatZoneState in state.zones:
		for connected_zone_id: StringName in zone.connected_zone_ids:
			if not zone_ids.has(connected_zone_id):
				return false
	for source: FoodSourceState in state.food_sources:
		if not zone_ids.has(source.zone_id):
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
				and not entity_ids.has(event.subject_entity_id)
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
			and state.scenario_progress == null
			and state.campaign_state == null
			and state.humidity_adjustment_count == 0
			and state.observation_stable_ticks == 0
			and state.shared_sugar_portions == 0
			and state.total_sugar_portions_placed == 0
			and state.unlocked_observation_card_ids.is_empty()
		)
	return (
		state.queen.laid_egg_count == 0
		and _state_graph_matches_frozen_config(simulation)
		and simulation.has_valid_habitat_ownership()
	)


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
		if ant.worker_task != null or ant.foraging_task != null:
			return false
		var stage_duration: int = simulation.get_stage_duration_ticks(
			ant.life_stage
		)
		if stage_duration <= 0 or ant.stage_age_ticks >= stage_duration:
			return false
	elif simulation.has_habitat():
		if ant.worker_task == null or ant.foraging_task == null:
			return false
	else:
		if ant.worker_task != null or ant.foraging_task != null:
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
	return true


static func _state_graph_matches_frozen_config(
	simulation: ColonySimulation
) -> bool:
	var state: ColonyState = simulation._state
	var config: HabitatScenarioConfig = simulation._habitat_config
	if (
		config == null
		or state.zones.size() != config.zones.size()
		or (
			config.is_combined_observation()
			!= (state.scenario_progress != null)
		)
		or (
			config.is_combined_observation()
			!= (state.campaign_state != null)
		)
	):
		return false
	for zone_index: int in state.zones.size():
		var state_zone: HabitatZoneState = state.zones[zone_index]
		var config_zone: HabitatZoneState = config.zones[zone_index]
		if (
			state_zone.zone_id != config_zone.zone_id
			or state_zone.connected_zone_ids
				!= config_zone.connected_zone_ids
		):
			return false
	return true


static func _has_valid_pending_commands(
	simulation: ColonySimulation
) -> bool:
	var seen_types: Dictionary[int, bool] = {}
	for command: PendingSimulationCommand in simulation._pending_commands:
		if command == null or seen_types.has(command.command_type):
			return false
		seen_types[command.command_type] = true
		match command.command_type:
			ColonySimulation.PendingCommandType.WATER_ACTION:
				if (
					not command.argument_id.is_empty()
					or not _can_restore_water_command(simulation)
				):
					return false
			ColonySimulation.PendingCommandType.PLACE_SUGAR_ACTION:
				if (
					not command.argument_id.is_empty()
					or not _can_restore_sugar_command(simulation)
				):
					return false
			ColonySimulation.PendingCommandType.CONTINUE_OBSERVATION_ACTION:
				if (
					not command.argument_id.is_empty()
					or simulation._scenario_director == null
					or not simulation._scenario_director
						.is_identity_continue_available(simulation._state)
				):
					return false
			ColonySimulation.PendingCommandType.SELECT_CAMPAIGN_INFERENCE_ACTION:
				if (
					command.argument_id.is_empty()
					or simulation._campaign_director == null
					or not simulation._campaign_director
						.is_inference_action_available(
							simulation._state,
							command.argument_id
						)
				):
					return false
			_:
				return false
	return true


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
		or simulation._state.total_sugar_portions_placed > 0
		or simulation._state.unlocked_observation_card_ids.has(
			simulation._habitat_config.foraging_observation_card_id
		)
		or (
			simulation._scenario_director != null
			and not simulation._scenario_director
				.is_foraging_phase_active(simulation._state)
		)
	):
		return false
	var zone: HabitatZoneState = simulation._state.get_zone(
		simulation._habitat_config.sugar_placement_zone_id
	)
	return zone != null and zone.available


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


static func _strings_from_names(values: Array[StringName]) -> Array[String]:
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
