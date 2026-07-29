class_name SimulationSnapshotSignature
extends RefCounted


static func canonical_snapshot(snapshot: ColonySnapshot) -> String:
	if snapshot == null:
		return "<null-snapshot>"

	var lines: PackedStringArray = [
		(
			"snapshot|tick=%d|lifecycle=%s|queen=%d|laid=%d|max_brood=%d"
			+ "|next_egg=%d|scenario=%s|humidity_actions=%d"
			+ "|water_unlocked=%s|water_available=%s|water_pending=%s"
			+ "|water_count=%d|water_comfortable=%s|stable_ticks=%d"
			+ "|brood_observation=%s"
		)
		% [
			snapshot.simulation_tick,
			str(snapshot.lifecycle_active),
			snapshot.queen_entity_id,
			snapshot.queen_laid_egg_count,
			snapshot.max_first_generation_brood,
			snapshot.next_egg_tick,
			String(snapshot.scenario_id),
			snapshot.humidity_adjustment_count,
			str(snapshot.water_action_unlocked),
			str(snapshot.water_action_available),
			str(snapshot.water_action_pending),
			snapshot.water_action_count,
			str(snapshot.water_target_comfortable),
			snapshot.observation_stable_ticks,
			str(snapshot.brood_humidity_observation_unlocked),
		],
	]

	var zones: Array[HabitatZoneSnapshot] = []
	zones.assign(snapshot.zones)
	zones.sort_custom(
		func(first: HabitatZoneSnapshot, second: HabitatZoneSnapshot) -> bool:
			return String(first.zone_id) < String(second.zone_id)
	)
	for zone: HabitatZoneSnapshot in zones:
		var connected_zone_ids: PackedStringArray = []
		for connected_zone_id: StringName in zone.connected_zone_ids:
			connected_zone_ids.append(String(connected_zone_id))
		connected_zone_ids.sort()
		lines.append(
			"zone|id=%s|humidity=%s|available=%s|connections=%s"
			% [
				String(zone.zone_id),
				_format_float(zone.humidity),
				str(zone.available),
				",".join(connected_zone_ids),
			]
		)

	var ants: Array[AntSnapshot] = []
	ants.assign(snapshot.ants)
	ants.sort_custom(
		func(first: AntSnapshot, second: AntSnapshot) -> bool:
			return first.entity_id < second.entity_id
	)
	for ant: AntSnapshot in ants:
		lines.append(
			(
				"ant|id=%d|stage=%d|total_age=%d|stage_age=%d"
				+ "|stage_duration=%d|zone=%s|zone_entered=%d"
				+ "|reserved_by=%d|carrier=%d|task=%d|origin=%s"
				+ "|target_brood=%d|target_zone=%s|carried_brood=%d"
				+ "|task_elapsed=%d|task_duration=%d"
			)
			% [
				ant.entity_id,
				ant.life_stage,
				ant.total_age_ticks,
				ant.stage_age_ticks,
				ant.stage_duration_ticks,
				String(ant.zone_id),
				ant.zone_entered_tick,
				ant.reserved_by_ant_id,
				ant.carrier_ant_id,
				ant.worker_task_state,
				String(ant.task_origin_zone_id),
				ant.target_brood_id,
				String(ant.target_zone_id),
				ant.carried_brood_id,
				ant.task_elapsed_ticks,
				ant.task_duration_ticks,
			]
		)

	var event_history: String = canonical_event_history(
		snapshot.observation_events
	)
	if not event_history.is_empty():
		lines.append(event_history)
	return "\n".join(lines)


static func canonical_event_history(
	events: Array[ObservationEvent]
) -> String:
	var lines: PackedStringArray = []
	for event: ObservationEvent in events:
		if event == null:
			lines.append("event|null")
			continue
		lines.append(
			"event|id=%d|tick=%d|type=%d|actor=%d|subject=%d|source=%s|target=%s"
			% [
				event.event_id,
				event.tick,
				event.event_type,
				event.actor_entity_id,
				event.subject_entity_id,
				String(event.source_zone_id),
				String(event.target_zone_id),
			]
		)
	return "\n".join(lines)


static func snapshot_digest(snapshot: ColonySnapshot) -> String:
	return canonical_snapshot(snapshot).sha256_text()


static func event_history_digest(
	events: Array[ObservationEvent]
) -> String:
	return canonical_event_history(events).sha256_text()


static func canonical_game_snapshot(snapshot: GameSnapshot) -> String:
	if snapshot == null:
		return "<null-game-snapshot>"

	var lines: PackedStringArray = [
		"game|tick=%d" % snapshot.simulation_tick,
		"colony-begin",
		canonical_snapshot(snapshot.colony),
		"colony-end",
	]

	if snapshot.scenario == null:
		lines.append("scenario|null")
	else:
		lines.append(
			(
				"scenario|id=%s|phase=%d|nest=%s|placement=%s"
				+ "|action_available=%s|action_pending=%s|action_count=%d"
			)
			% [
				String(snapshot.scenario.scenario_id),
				snapshot.scenario.phase,
				String(snapshot.scenario.nest_zone_id),
				String(snapshot.scenario.placement_zone_id),
				str(snapshot.scenario.place_action_available),
				str(snapshot.scenario.place_action_pending),
				snapshot.scenario.place_action_count,
			]
		)

	if snapshot.sequence != null:
		lines.append(
			(
				"sequence|id=%s|phase=%d|entered=%d|first_worker=%d"
				+ "|emerged=%d|humidity_done=%d|sugar_done=%d"
				+ "|first_card=%s|humidity_card=%s|sugar_card=%s"
				+ "|continue_available=%s|continue_pending=%s"
				+ "|completed=%s"
			)
			% [
				String(snapshot.sequence.scenario_id),
				snapshot.sequence.phase,
				snapshot.sequence.phase_entered_tick,
				snapshot.sequence.first_worker_entity_id,
				snapshot.sequence.first_worker_emerged_tick,
				snapshot.sequence.humidity_observation_completed_tick,
				snapshot.sequence.sugar_observation_completed_tick,
				String(
					snapshot.sequence.first_worker_observation_card_id
				),
				String(
					snapshot.sequence.brood_humidity_observation_card_id
				),
				String(
					snapshot.sequence.sugar_foraging_observation_card_id
				),
				str(snapshot.sequence.continue_action_available),
				str(snapshot.sequence.continue_action_pending),
				str(snapshot.sequence.completed),
			]
		)

	if snapshot.campaign == null:
		lines.append("campaign|null")
	else:
		lines.append(
			(
				"campaign|chapter=%d|status=%d|entered=%d|completed_count=%d"
				+ "|incorrect=%d|hint=%d|completed_tick=%d"
				+ "|action_available=%s|action_pending=%s|completed=%s"
				+ "|choices=%s|evidence=%s|inferences=%s|facilities=%s"
			)
			% [
				snapshot.campaign.chapter,
				snapshot.campaign.status,
				snapshot.campaign.chapter_entered_tick,
				snapshot.campaign.completed_chapter_count,
				snapshot.campaign.incorrect_inference_attempts,
				snapshot.campaign.hint_tier,
				snapshot.campaign.campaign_completed_tick,
				str(snapshot.campaign.inference_action_available),
				str(snapshot.campaign.inference_action_pending),
				str(snapshot.campaign.completed),
				_names_signature(
					snapshot.campaign.available_inference_ids
				),
				_names_signature(
					snapshot.campaign.collected_evidence_ids
				),
				_names_signature(
					snapshot.campaign.confirmed_inference_ids
				),
				_names_signature(
					snapshot.campaign.unlocked_facility_type_ids
				),
			]
		)

	if snapshot.act1 == null:
		lines.append("act1|null")
	else:
		lines.append(
			(
				"act1|first_worker=%d|emerged=%d|care=%s"
				+ "|environment_stable=%d/%d|finale_stable=%d/%d"
				+ "|report_tick=%d|report_available=%s"
			)
			% [
				snapshot.act1.first_worker_entity_id,
				snapshot.act1.first_worker_emerged_tick,
				str(snapshot.act1.first_worker_care_recorded),
				snapshot.act1.environment_stable_ticks,
				snapshot.act1.environment_stable_required_ticks,
				snapshot.act1.finale_stable_ticks,
				snapshot.act1.finale_stable_required_ticks,
				snapshot.act1.final_report_generated_tick,
				str(snapshot.act1.final_report_available),
			]
		)

	if snapshot.colony != null:
		var sources: Array[FoodSourceSnapshot] = []
		sources.assign(snapshot.colony.food_sources)
		sources.sort_custom(
			func(first: FoodSourceSnapshot, second: FoodSourceSnapshot) -> bool:
				return first.food_source_id < second.food_source_id
		)
		for source: FoodSourceSnapshot in sources:
			if source == null:
				lines.append("food|null")
				continue
			lines.append(
				(
					"food|id=%d|zone=%s|type=%d|remaining=%d"
					+ "|available=%s|reserved_by=%d|carrier=%d"
				)
				% [
					source.food_source_id,
					String(source.zone_id),
					source.food_type,
					source.remaining_portions,
					str(source.available),
					source.reserved_by_worker_id,
					source.carrier_worker_id,
				]
			)

		var ants: Array[AntSnapshot] = []
		ants.assign(snapshot.colony.ants)
		ants.sort_custom(
			func(first: AntSnapshot, second: AntSnapshot) -> bool:
				return first.entity_id < second.entity_id
		)
		for ant: AntSnapshot in ants:
			if ant == null:
				lines.append("foraging-task|null-ant")
				continue
			var task: ForagingTaskSnapshot = ant.foraging_task
			if task == null:
				lines.append(
					"foraging-task|worker=%d|null" % ant.entity_id
				)
				continue
			var route_zone_ids: PackedStringArray = []
			for route_zone_id: StringName in task.route_zone_ids:
				route_zone_ids.append(String(route_zone_id))
			lines.append(
				(
					"foraging-task|worker=%d|state=%d|source=%d"
					+ "|origin=%s|target=%s|nest=%s|route=%s"
					+ "|carried=%d|elapsed=%d|duration=%d"
				)
				% [
					ant.entity_id,
					task.state,
					task.target_food_source_id,
					String(task.origin_zone_id),
					String(task.target_zone_id),
					String(task.nest_zone_id),
					",".join(route_zone_ids),
					task.carried_portions,
					task.elapsed_ticks,
					task.duration_ticks,
				]
			)

	if snapshot.observations == null:
		lines.append("observations|null")
	else:
		var card_ids: PackedStringArray = []
		for card_id: StringName in snapshot.observations.unlocked_card_ids:
			card_ids.append(String(card_id))
		card_ids.sort()
		lines.append("cards|%s" % ",".join(card_ids))
		lines.append("journal-events-begin")
		lines.append(canonical_event_history(snapshot.observations.events))
		lines.append("journal-events-end")

	return "\n".join(lines)


static func game_snapshot_digest(snapshot: GameSnapshot) -> String:
	return canonical_game_snapshot(snapshot).sha256_text()


static func roll_digest(previous_digest: String, record: String) -> String:
	return ("%s\n%s" % [previous_digest, record]).sha256_text()


static func _names_signature(values: Array[StringName]) -> String:
	var strings: PackedStringArray = []
	for value: StringName in values:
		strings.append(String(value))
	strings.sort()
	return ",".join(strings)


static func _format_float(value: float) -> String:
	return "%.9f" % value
