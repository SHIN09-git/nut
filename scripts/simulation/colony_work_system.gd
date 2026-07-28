class_name ColonyWorkSystem
extends RefCounted

const EPSILON: float = 0.000001

var _config: ColonyWorkConfig
var _habitat_config: HabitatScenarioConfig
var _brood_config: BroodCareConfig
var _environment_config: EnvironmentConfig
var _catalog: FacilityCatalogConfig


func _init(
	config: ColonyWorkConfig,
	habitat_config: HabitatScenarioConfig,
	brood_config: BroodCareConfig,
	environment_config: EnvironmentConfig,
	catalog: FacilityCatalogConfig
) -> void:
	_config = config
	_habitat_config = habitat_config
	_brood_config = brood_config
	_environment_config = environment_config
	_catalog = catalog


func is_ready() -> bool:
	return (
		_config != null
		and _habitat_config != null
		and _brood_config != null
		and _environment_config != null
		and _catalog != null
	)


func update_migration_candidate(state: ColonyState) -> void:
	if (
		not is_ready()
		or state == null
		or state.colony_work_state == null
		or state.queen.zone_id.is_empty()
	):
		return
	var work: ColonyWorkState = state.colony_work_state
	if not work.migration_target_zone_id.is_empty():
		if (
			_is_migration_complete(state, work.migration_target_zone_id)
			and not _has_active_migration_task(state)
		):
			var completed_zone_id: StringName = work.migration_target_zone_id
			work.completed_migration_count += 1
			work.migration_target_zone_id = &""
			work.migration_candidate_zone_id = &""
			work.migration_candidate_stable_ticks = 0
			state.record_observation_event(
				ObservationEvent.Type.MIGRATION_COMPLETED,
				ObservationEvent.NO_ENTITY_ID,
				state.queen.entity_id,
				&"",
				completed_zone_id
			)
			return
		if (
			not _is_migration_target_comfortable(
				state,
				work.migration_target_zone_id
			)
			and not _has_carried_migration_member(state)
		):
			work.migration_target_zone_id = &""
			work.migration_candidate_zone_id = &""
			work.migration_candidate_stable_ticks = 0
		return
	if (
		state.simulation_tick - state.queen.zone_entered_tick
		< _config.migration_minimum_zone_dwell_ticks
	):
		_reset_migration_candidate(work)
		return

	var source_zone: HabitatZoneState = state.get_zone(state.queen.zone_id)
	if source_zone == null:
		_reset_migration_candidate(work)
		return
	var source_penalty: float = _nest_penalty(source_zone)
	var best_zone: HabitatZoneState
	var best_improvement: float = -INF
	for zone: HabitatZoneState in _zones_in_stable_order(state):
		if (
			zone.zone_id == source_zone.zone_id
			or not zone.available
			or not zone.discovered
			or not _is_habitat_zone(state, zone.zone_id)
			or not _is_migration_target_comfortable(state, zone.zone_id)
			or state.find_stable_zone_path(
				source_zone.zone_id,
				zone.zone_id
			).is_empty()
		):
			continue
		var improvement: float = source_penalty - _nest_penalty(zone)
		if improvement + EPSILON < _config.migration_min_improvement:
			continue
		if (
			best_zone == null
			or improvement > best_improvement + EPSILON
			or (
				is_equal_approx(improvement, best_improvement)
				and String(zone.zone_id) < String(best_zone.zone_id)
			)
		):
			best_zone = zone
			best_improvement = improvement
	if best_zone == null:
		_reset_migration_candidate(work)
		return
	if work.migration_candidate_zone_id == best_zone.zone_id:
		work.migration_candidate_stable_ticks += 1
	else:
		work.migration_candidate_zone_id = best_zone.zone_id
		work.migration_candidate_stable_ticks = 1
	if (
		work.migration_candidate_stable_ticks
		>= _config.migration_target_stable_ticks
	):
		work.migration_target_zone_id = best_zone.zone_id


func validate_tasks(state: ColonyState) -> void:
	if not is_ready() or state == null:
		return
	for worker: AntModel in _workers_in_stable_order(state):
		var waste: WasteCleanupTaskModel = worker.waste_cleanup_task
		var scout: ScoutTaskModel = worker.scout_task
		var migration: MigrationTaskModel = worker.migration_task
		if waste != null and waste.state != WasteCleanupTaskModel.State.IDLE:
			if not _waste_task_has_live_references(state, waste):
				if waste.carried_amount <= EPSILON:
					waste.reset_to_idle(
						state.simulation_tick
						+ _config.waste_decision_interval_ticks
					)
		if scout != null and scout.state != ScoutTaskModel.State.IDLE:
			var target_zone: HabitatZoneState = state.get_zone(
				scout.target_zone_id
			)
			if target_zone == null or not target_zone.available:
				scout.reset_to_idle(
					state.simulation_tick
					+ _config.scout_decision_interval_ticks
				)
		if (
			migration != null
			and migration.state != MigrationTaskModel.State.IDLE
			and migration.carried_entity_id < 0
			and not _migration_member_is_at_origin(state, migration)
		):
			migration.reset_to_idle(
				state.simulation_tick
				+ _config.migration_decision_interval_ticks
			)


func advance_tasks(state: ColonyState) -> void:
	if not is_ready() or state == null:
		return
	for worker: AntModel in _workers_in_stable_order(state):
		if (
			worker.waste_cleanup_task != null
			and worker.waste_cleanup_task.state
				!= WasteCleanupTaskModel.State.IDLE
		):
			_advance_waste_task(state, worker)
		elif (
			worker.scout_task != null
			and worker.scout_task.state != ScoutTaskModel.State.IDLE
		):
			_advance_scout_task(state, worker)
		elif (
			worker.migration_task != null
			and worker.migration_task.state
				!= MigrationTaskModel.State.IDLE
		):
			_advance_migration_task(state, worker)


func assign_idle_workers(state: ColonyState) -> void:
	if not is_ready() or state == null or state.colony_work_state == null:
		return
	var reserved_waste_zones: Dictionary[StringName, bool] = {}
	var reserved_trays: Dictionary[int, bool] = {}
	var reserved_scout_zones: Dictionary[StringName, bool] = {}
	var reserved_members: Dictionary[int, bool] = {}
	for worker: AntModel in _workers_in_stable_order(state):
		if (
			worker.waste_cleanup_task != null
			and worker.waste_cleanup_task.state
				!= WasteCleanupTaskModel.State.IDLE
		):
			reserved_waste_zones[
				worker.waste_cleanup_task.source_zone_id
			] = true
			reserved_trays[
				worker.waste_cleanup_task.target_tray_facility_id
			] = true
		if (
			worker.scout_task != null
			and worker.scout_task.state != ScoutTaskModel.State.IDLE
		):
			reserved_scout_zones[worker.scout_task.target_zone_id] = true
		if (
			worker.migration_task != null
			and worker.migration_task.state
				!= MigrationTaskModel.State.IDLE
		):
			reserved_members[worker.migration_task.target_entity_id] = true
	for worker: AntModel in _workers_in_stable_order(state):
		if not is_worker_available(worker):
			continue
		if (
			state.simulation_tick
			>= worker.waste_cleanup_task.next_decision_tick
		):
			if _try_assign_waste_task(
				state,
				worker,
				reserved_waste_zones,
				reserved_trays
			):
				reserved_waste_zones[
					worker.waste_cleanup_task.source_zone_id
				] = true
				reserved_trays[
					worker.waste_cleanup_task.target_tray_facility_id
				] = true
				continue
			worker.waste_cleanup_task.next_decision_tick = (
				state.simulation_tick
				+ _config.waste_decision_interval_ticks
			)
		if (
			state.simulation_tick
			>= worker.scout_task.next_decision_tick
		):
			if _try_assign_scout_task(
				state,
				worker,
				reserved_scout_zones
			):
				reserved_scout_zones[
					worker.scout_task.target_zone_id
				] = true
				continue
			worker.scout_task.next_decision_tick = (
				state.simulation_tick
				+ _config.scout_decision_interval_ticks
			)
		if (
			state.simulation_tick
			>= worker.migration_task.next_decision_tick
		):
			if _try_assign_migration_task(
				state,
				worker,
				reserved_members
			):
				reserved_members[
					worker.migration_task.target_entity_id
				] = true
				continue
			worker.migration_task.next_decision_tick = (
				state.simulation_tick
				+ _config.migration_decision_interval_ticks
			)


func has_valid_state(state: ColonyState) -> bool:
	if (
		not is_ready()
		or state == null
		or state.colony_work_state == null
		or state.queen == null
	):
		return false
	var work: ColonyWorkState = state.colony_work_state
	if (
		work.migration_candidate_stable_ticks < 0
		or work.completed_migration_count < 0
		or work.scouted_zone_count < 0
		or work.delivered_waste_batch_count < 0
		or work.cleaned_waste_tray_count < 0
	):
		return false
	for zone: HabitatZoneState in state.zones:
		if (
			zone == null
			or zone.discovered_tick < -1
			or (zone.discovered and zone.discovered_tick < 0)
			or (not zone.discovered and zone.discovered_tick != -1)
		):
			return false
	var carried_members: Dictionary[int, int] = {}
	var reserved_waste_sources: Dictionary[StringName, bool] = {}
	var reserved_waste_trays: Dictionary[int, bool] = {}
	var reserved_scout_zones: Dictionary[StringName, bool] = {}
	var reserved_migration_members: Dictionary[int, bool] = {}
	for worker: AntModel in _workers_in_stable_order(state):
		if (
			worker.waste_cleanup_task == null
			or worker.scout_task == null
			or worker.migration_task == null
		):
			return false
		if _active_task_count(worker) > 1:
			return false
		var waste: WasteCleanupTaskModel = worker.waste_cleanup_task
		if not _waste_task_has_valid_shape(waste):
			return false
		if waste.state != WasteCleanupTaskModel.State.IDLE:
			if (
				reserved_waste_sources.has(waste.source_zone_id)
				or reserved_waste_trays.has(waste.target_tray_facility_id)
				or not _waste_task_has_live_references(state, waste)
			):
				return false
			reserved_waste_sources[waste.source_zone_id] = true
			reserved_waste_trays[waste.target_tray_facility_id] = true
		var scout: ScoutTaskModel = worker.scout_task
		if not _scout_task_has_valid_shape(scout):
			return false
		if scout.state != ScoutTaskModel.State.IDLE:
			var scout_target: HabitatZoneState = state.get_zone(
				scout.target_zone_id
			)
			if (
				reserved_scout_zones.has(scout.target_zone_id)
				or scout_target == null
				or not scout_target.available
			):
				return false
			reserved_scout_zones[scout.target_zone_id] = true
		var migration: MigrationTaskModel = worker.migration_task
		if not _migration_task_has_valid_shape(migration):
			return false
		if migration.state != MigrationTaskModel.State.IDLE:
			if reserved_migration_members.has(migration.target_entity_id):
				return false
			reserved_migration_members[migration.target_entity_id] = true
			if (
				migration.target_entity_id != state.queen.entity_id
				and state.get_ant(migration.target_entity_id) == null
			):
				return false
		if migration.carried_entity_id >= 0:
			if carried_members.has(migration.carried_entity_id):
				return false
			carried_members[migration.carried_entity_id] = worker.entity_id
	for ant: AntModel in state.ants:
		if ant.life_stage == AntModel.LifeStage.WORKER:
			continue
		if ant.zone_id.is_empty() != carried_members.has(ant.entity_id):
			return false
	if state.queen.zone_id.is_empty() != carried_members.has(
		state.queen.entity_id
	):
		return false
	return true


func _waste_task_has_valid_shape(task: WasteCleanupTaskModel) -> bool:
	if (
		task == null
		or task.state < WasteCleanupTaskModel.State.IDLE
		or task.state > WasteCleanupTaskModel.State.DROPPING
		or not is_finite(task.reserved_amount)
		or not is_finite(task.carried_amount)
		or task.reserved_amount < 0.0
		or task.carried_amount < 0.0
		or task.carried_amount > task.reserved_amount + EPSILON
		or task.elapsed_ticks < 0
		or task.duration_ticks < 0
		or task.next_decision_tick < 0
	):
		return false
	if task.state == WasteCleanupTaskModel.State.IDLE:
		return (
			task.origin_zone_id.is_empty()
			and task.source_zone_id.is_empty()
			and task.target_tray_facility_id == -1
			and task.target_zone_id.is_empty()
			and task.route_zone_ids.is_empty()
			and task.reserved_amount <= EPSILON
			and task.carried_amount <= EPSILON
			and task.elapsed_ticks == 0
			and task.duration_ticks == 0
		)
	if (
		task.origin_zone_id.is_empty()
		or task.source_zone_id.is_empty()
		or task.target_tray_facility_id < 0
		or task.target_zone_id.is_empty()
		or task.route_zone_ids.is_empty()
		or task.reserved_amount <= EPSILON
		or task.duration_ticks <= 0
		or task.elapsed_ticks >= task.duration_ticks
	):
		return false
	var should_carry: bool = task.state in [
		WasteCleanupTaskModel.State.CARRYING_TO_TRAY,
		WasteCleanupTaskModel.State.DROPPING,
	]
	return (
		task.carried_amount > EPSILON
		and is_equal_approx(task.carried_amount, task.reserved_amount)
		if should_carry
		else task.carried_amount <= EPSILON
	)


func _scout_task_has_valid_shape(task: ScoutTaskModel) -> bool:
	if (
		task == null
		or task.state < ScoutTaskModel.State.IDLE
		or task.state > ScoutTaskModel.State.RETURNING
		or task.elapsed_ticks < 0
		or task.duration_ticks < 0
		or task.next_decision_tick < 0
	):
		return false
	if task.state == ScoutTaskModel.State.IDLE:
		return (
			task.origin_zone_id.is_empty()
			and task.target_zone_id.is_empty()
			and task.route_zone_ids.is_empty()
			and task.elapsed_ticks == 0
			and task.duration_ticks == 0
		)
	return (
		not task.origin_zone_id.is_empty()
		and not task.target_zone_id.is_empty()
		and task.duration_ticks > 0
		and task.elapsed_ticks < task.duration_ticks
		and (
			not task.route_zone_ids.is_empty()
			or task.state == ScoutTaskModel.State.RETURNING
		)
	)


func _migration_task_has_valid_shape(task: MigrationTaskModel) -> bool:
	if (
		task == null
		or task.state < MigrationTaskModel.State.IDLE
		or task.state > MigrationTaskModel.State.DROPPING
		or task.elapsed_ticks < 0
		or task.duration_ticks < 0
		or task.next_decision_tick < 0
	):
		return false
	if task.state == MigrationTaskModel.State.IDLE:
		return (
			task.origin_zone_id.is_empty()
			and task.member_origin_zone_id.is_empty()
			and task.target_entity_id == -1
			and task.target_zone_id.is_empty()
			and task.carried_entity_id == -1
			and task.route_zone_ids.is_empty()
			and not task.returning_to_origin
			and task.elapsed_ticks == 0
			and task.duration_ticks == 0
		)
	if (
		task.origin_zone_id.is_empty()
		or task.member_origin_zone_id.is_empty()
		or task.target_entity_id < 0
		or task.target_zone_id.is_empty()
		or task.route_zone_ids.is_empty()
		or task.duration_ticks <= 0
		or task.elapsed_ticks >= task.duration_ticks
	):
		return false
	var should_carry: bool = task.state in [
		MigrationTaskModel.State.CARRYING_TO_ZONE,
		MigrationTaskModel.State.DROPPING,
	]
	return (
		task.carried_entity_id == task.target_entity_id
		and (not task.returning_to_origin or should_carry)
		if should_carry
		else task.carried_entity_id == -1
			and not task.returning_to_origin
	)


func is_worker_available(worker: AntModel) -> bool:
	return (
		worker != null
		and worker.life_stage == AntModel.LifeStage.WORKER
		and not worker.zone_id.is_empty()
		and worker.worker_task != null
		and worker.worker_task.state == WorkerTaskModel.State.IDLE
		and worker.foraging_task != null
		and worker.foraging_task.state == ForagingTaskModel.State.IDLE
		and (
			worker.feeding_task == null
			or worker.feeding_task.state
				== BroodFeedingTaskModel.State.IDLE
		)
		and worker.waste_cleanup_task != null
		and worker.waste_cleanup_task.state
			== WasteCleanupTaskModel.State.IDLE
		and worker.scout_task != null
		and worker.scout_task.state == ScoutTaskModel.State.IDLE
		and worker.migration_task != null
		and worker.migration_task.state == MigrationTaskModel.State.IDLE
	)


func has_active_task(worker: AntModel) -> bool:
	return (
		worker != null
		and (
			worker.waste_cleanup_task != null
			and worker.waste_cleanup_task.state
				!= WasteCleanupTaskModel.State.IDLE
			or worker.scout_task != null
			and worker.scout_task.state != ScoutTaskModel.State.IDLE
			or worker.migration_task != null
			and worker.migration_task.state
				!= MigrationTaskModel.State.IDLE
		)
	)


func get_reserved_waste_for_tray(
	state: ColonyState,
	facility_id: int
) -> float:
	var reserved: float = 0.0
	if state == null:
		return reserved
	for worker: AntModel in _workers_in_stable_order(state):
		var task: WasteCleanupTaskModel = worker.waste_cleanup_task
		if (
			task != null
			and task.state != WasteCleanupTaskModel.State.IDLE
			and task.target_tray_facility_id == facility_id
		):
			reserved += task.reserved_amount
	return reserved


func is_clean_action_available(
	state: ColonyState,
	facility_id: int
) -> bool:
	if not is_ready() or state == null or state.layout_state == null:
		return false
	var facility: FacilityState = state.layout_state.get_facility(facility_id)
	if (
		facility == null
		or not facility.available
		or facility.waste_stored <= EPSILON
	):
		return false
	var type_config: FacilityConfig = _catalog.get_type(facility.type_id)
	if (
		type_config == null
		or type_config.effect_config == null
		or type_config.effect_config.kind
			!= FacilityEffectConfig.Kind.WASTE_TRAY
	):
		return false
	for worker: AntModel in _workers_in_stable_order(state):
		var task: WasteCleanupTaskModel = worker.waste_cleanup_task
		if (
			task != null
			and task.state != WasteCleanupTaskModel.State.IDLE
			and task.target_tray_facility_id == facility_id
		):
			return false
	return true


func apply_clean_action(state: ColonyState, facility_id: int) -> bool:
	if not is_clean_action_available(state, facility_id):
		return false
	var facility: FacilityState = state.layout_state.get_facility(facility_id)
	facility.waste_stored = 0.0
	state.colony_work_state.cleaned_waste_tray_count += 1
	state.record_observation_event(
		ObservationEvent.Type.WASTE_TRAY_CLEANED,
		ObservationEvent.NO_ENTITY_ID,
		facility_id,
		facility.zone_id,
		facility.zone_id
	)
	return true


func _try_assign_waste_task(
	state: ColonyState,
	worker: AntModel,
	reserved_waste_zones: Dictionary[StringName, bool],
	reserved_trays: Dictionary[int, bool]
) -> bool:
	var source_candidates: Array[HabitatZoneState] = []
	for zone: HabitatZoneState in _zones_in_stable_order(state):
		if (
			zone.available
			and zone.discovered
			and zone.pollution + EPSILON
				>= _config.waste_source_pollution_min
			and not reserved_waste_zones.has(zone.zone_id)
		):
			source_candidates.append(zone)
	source_candidates.sort_custom(
		func(first: HabitatZoneState, second: HabitatZoneState) -> bool:
			if not is_equal_approx(first.pollution, second.pollution):
				return first.pollution > second.pollution
			return String(first.zone_id) < String(second.zone_id)
	)
	for source: HabitatZoneState in source_candidates:
		var outbound_route: Array[StringName] = state.find_stable_zone_path(
			worker.zone_id,
			source.zone_id
		)
		if (
			outbound_route.is_empty()
			or not _route_is_discovered(state, outbound_route)
		):
			continue
		for tray: FacilityState in state.layout_state.get_facilities_in_stable_order():
			if (
				not tray.available
				or reserved_trays.has(tray.facility_id)
				or tray.zone_id.is_empty()
			):
				continue
			var tray_type: FacilityConfig = _catalog.get_type(tray.type_id)
			var tray_zone: HabitatZoneState = state.get_zone(tray.zone_id)
			if (
				tray_type == null
				or tray_type.effect_config.kind
					!= FacilityEffectConfig.Kind.WASTE_TRAY
				or tray_zone == null
				or not tray_zone.available
				or not tray_zone.discovered
			):
				continue
			var remaining: float = (
				tray_type.effect_config.waste_capacity
				- tray.waste_stored
				- get_reserved_waste_for_tray(state, tray.facility_id)
			)
			if remaining <= EPSILON:
				continue
			var carry_route: Array[StringName] = state.find_stable_zone_path(
				source.zone_id,
				tray.zone_id
			)
			if (
				carry_route.is_empty()
				or not _route_is_discovered(state, carry_route)
			):
				continue
			var reserved_amount: float = minf(
				_config.waste_batch_amount,
				minf(source.pollution, remaining)
			)
			if reserved_amount <= EPSILON:
				continue
			worker.waste_cleanup_task.begin(
				WasteCleanupTaskModel.State.MOVING_TO_WASTE,
				worker.zone_id,
				source.zone_id,
				tray.facility_id,
				tray.zone_id,
				outbound_route,
				reserved_amount,
				_travel_duration(
					outbound_route,
					_config.waste_travel_ticks_per_connection
				)
			)
			state.record_observation_event(
				ObservationEvent.Type.WASTE_CLEANUP_STARTED,
				worker.entity_id,
				tray.facility_id,
				source.zone_id,
				tray.zone_id
			)
			return true
	return false


func _try_assign_scout_task(
	state: ColonyState,
	worker: AntModel,
	reserved_scout_zones: Dictionary[StringName, bool]
) -> bool:
	var best_zone: HabitatZoneState
	var best_route: Array[StringName] = []
	for zone: HabitatZoneState in _zones_in_stable_order(state):
		if (
			not zone.available
			or zone.discovered
			or reserved_scout_zones.has(zone.zone_id)
		):
			continue
		var route: Array[StringName] = state.find_stable_zone_path(
			worker.zone_id,
			zone.zone_id
		)
		if route.is_empty() or not _route_reaches_first_unknown(state, route):
			continue
		if (
			best_zone == null
			or route.size() < best_route.size()
			or (
				route.size() == best_route.size()
				and String(zone.zone_id) < String(best_zone.zone_id)
			)
		):
			best_zone = zone
			best_route = route
	if best_zone == null:
		return false
	worker.scout_task.begin(
		ScoutTaskModel.State.MOVING_TO_ZONE,
		worker.zone_id,
		best_zone.zone_id,
		best_route,
		_travel_duration(
			best_route,
			_config.scout_travel_ticks_per_connection
		)
	)
	state.record_observation_event(
		ObservationEvent.Type.SCOUT_STARTED,
		worker.entity_id,
		ObservationEvent.NO_ENTITY_ID,
		worker.zone_id,
		best_zone.zone_id
	)
	return true


func _try_assign_migration_task(
	state: ColonyState,
	worker: AntModel,
	reserved_members: Dictionary[int, bool]
) -> bool:
	var work: ColonyWorkState = state.colony_work_state
	if (
		work.migration_target_zone_id.is_empty()
		or not _is_migration_target_comfortable(
			state,
			work.migration_target_zone_id
		)
	):
		return false
	var member_id: int = -1
	var member_zone_id: StringName = &""
	for ant: AntModel in state.ants:
		if (
			ant.life_stage == AntModel.LifeStage.WORKER
			or ant.zone_id.is_empty()
			or ant.zone_id == work.migration_target_zone_id
			or reserved_members.has(ant.entity_id)
			or _is_reserved_by_brood_relocation(state, ant.entity_id)
		):
			continue
		if state.find_stable_zone_path(
			ant.zone_id,
			work.migration_target_zone_id
		).is_empty():
			continue
		member_id = ant.entity_id
		member_zone_id = ant.zone_id
		break
	if member_id < 0:
		if (
			state.queen.zone_id.is_empty()
			or state.queen.zone_id == work.migration_target_zone_id
			or reserved_members.has(state.queen.entity_id)
			or not _all_brood_in_zone(
				state,
				work.migration_target_zone_id
			)
		):
			return false
		member_id = state.queen.entity_id
		member_zone_id = state.queen.zone_id
	var outbound_route: Array[StringName] = state.find_stable_zone_path(
		worker.zone_id,
		member_zone_id
	)
	if outbound_route.is_empty() or not _route_is_discovered(
		state,
		outbound_route
	):
		return false
	worker.migration_task.begin(
		MigrationTaskModel.State.MOVING_TO_MEMBER,
		worker.zone_id,
		member_zone_id,
		member_id,
		work.migration_target_zone_id,
		outbound_route,
		_travel_duration(
			outbound_route,
			_config.migration_travel_ticks_per_connection
		)
	)
	state.record_observation_event(
		ObservationEvent.Type.MIGRATION_STARTED,
		worker.entity_id,
		member_id,
		member_zone_id,
		work.migration_target_zone_id
	)
	return true


func _advance_waste_task(state: ColonyState, worker: AntModel) -> void:
	var task: WasteCleanupTaskModel = worker.waste_cleanup_task
	match task.state:
		WasteCleanupTaskModel.State.MOVING_TO_WASTE:
			if not state.is_zone_route_valid(
				task.route_zone_ids,
				task.origin_zone_id,
				task.source_zone_id
			):
				task.reset_to_idle(
					state.simulation_tick
					+ _config.waste_decision_interval_ticks
				)
				return
			if not _advance_phase(task):
				return
			worker.zone_id = task.source_zone_id
			task.begin(
				WasteCleanupTaskModel.State.PICKING_UP,
				task.origin_zone_id,
				task.source_zone_id,
				task.target_tray_facility_id,
				task.target_zone_id,
				[task.source_zone_id],
				task.reserved_amount,
				_config.waste_pickup_duration_ticks
			)
		WasteCleanupTaskModel.State.PICKING_UP:
			if not _waste_task_has_live_references(state, task):
				task.reset_to_idle(
					state.simulation_tick
					+ _config.waste_decision_interval_ticks
				)
				return
			if not _advance_phase(task):
				return
			var source: HabitatZoneState = state.get_zone(task.source_zone_id)
			var tray: FacilityState = state.layout_state.get_facility(
				task.target_tray_facility_id
			)
			var tray_type: FacilityConfig = _catalog.get_type(tray.type_id)
			var remaining: float = maxf(
				0.0,
				tray_type.effect_config.waste_capacity - tray.waste_stored
			)
			task.carried_amount = minf(
				task.reserved_amount,
				minf(source.pollution, remaining)
			)
			if task.carried_amount <= EPSILON:
				task.reset_to_idle(
					state.simulation_tick
					+ _config.waste_decision_interval_ticks
				)
				return
			source.set_pollution(source.pollution - task.carried_amount)
			task.reserved_amount = task.carried_amount
			var carry_route: Array[StringName] = state.find_stable_zone_path(
				task.source_zone_id,
				task.target_zone_id
			)
			task.begin(
				WasteCleanupTaskModel.State.CARRYING_TO_TRAY,
				task.origin_zone_id,
				task.source_zone_id,
				task.target_tray_facility_id,
				task.target_zone_id,
				carry_route,
				task.carried_amount,
				_travel_duration(
					carry_route,
					_config.waste_travel_ticks_per_connection
				)
			)
			state.record_observation_event(
				ObservationEvent.Type.WASTE_PICKED_UP,
				worker.entity_id,
				task.target_tray_facility_id,
				task.source_zone_id,
				task.target_zone_id
			)
		WasteCleanupTaskModel.State.CARRYING_TO_TRAY:
			if not state.is_zone_route_valid(
				task.route_zone_ids,
				task.source_zone_id,
				task.target_zone_id
			):
				var restored_route: Array[StringName] = (
					state.find_stable_zone_path(
						task.source_zone_id,
						task.target_zone_id
					)
				)
				if restored_route.is_empty():
					return
				task.route_zone_ids.assign(restored_route)
				task.duration_ticks = _travel_duration(
					restored_route,
					_config.waste_travel_ticks_per_connection
				)
				task.elapsed_ticks = 0
			if not _advance_phase(task):
				return
			worker.zone_id = task.target_zone_id
			task.begin(
				WasteCleanupTaskModel.State.DROPPING,
				task.origin_zone_id,
				task.source_zone_id,
				task.target_tray_facility_id,
				task.target_zone_id,
				[task.target_zone_id],
				task.carried_amount,
				_config.waste_drop_duration_ticks
			)
		WasteCleanupTaskModel.State.DROPPING:
			var tray: FacilityState = state.layout_state.get_facility(
				task.target_tray_facility_id
			)
			if tray == null:
				return
			var tray_type: FacilityConfig = _catalog.get_type(tray.type_id)
			var remaining: float = (
				tray_type.effect_config.waste_capacity - tray.waste_stored
			)
			if remaining + EPSILON < task.carried_amount:
				return
			if not _advance_phase(task):
				return
			tray.waste_stored += task.carried_amount
			state.colony_work_state.delivered_waste_batch_count += 1
			state.record_observation_event(
				ObservationEvent.Type.WASTE_DELIVERED,
				worker.entity_id,
				tray.facility_id,
				task.source_zone_id,
				task.target_zone_id
			)
			task.reset_to_idle(
				state.simulation_tick
				+ _config.waste_decision_interval_ticks
			)


func _advance_scout_task(state: ColonyState, worker: AntModel) -> void:
	var task: ScoutTaskModel = worker.scout_task
	match task.state:
		ScoutTaskModel.State.MOVING_TO_ZONE:
			if not state.is_zone_route_valid(
				task.route_zone_ids,
				task.origin_zone_id,
				task.target_zone_id
			):
				task.reset_to_idle(
					state.simulation_tick
					+ _config.scout_decision_interval_ticks
				)
				return
			if not _advance_phase(task):
				return
			worker.zone_id = task.target_zone_id
			task.begin(
				ScoutTaskModel.State.OBSERVING,
				task.origin_zone_id,
				task.target_zone_id,
				[task.target_zone_id],
				_config.scout_observe_duration_ticks
			)
		ScoutTaskModel.State.OBSERVING:
			if not _advance_phase(task):
				return
			var zone: HabitatZoneState = state.get_zone(task.target_zone_id)
			if zone != null and zone.mark_discovered(state.simulation_tick):
				state.colony_work_state.scouted_zone_count += 1
				state.record_observation_event(
					ObservationEvent.Type.ZONE_DISCOVERED,
					worker.entity_id,
					ObservationEvent.NO_ENTITY_ID,
					task.origin_zone_id,
					task.target_zone_id
				)
			task.begin(
				ScoutTaskModel.State.RETURNING,
				task.origin_zone_id,
				task.target_zone_id,
				[],
				1
			)
		ScoutTaskModel.State.RETURNING:
			var return_route: Array[StringName] = task.route_zone_ids
			if not state.is_zone_route_valid(
				return_route,
				task.target_zone_id,
				task.origin_zone_id
			):
				return_route = state.find_stable_zone_path(
					task.target_zone_id,
					task.origin_zone_id
				)
				if return_route.is_empty():
					return
				task.route_zone_ids.assign(return_route)
				task.duration_ticks = _travel_duration(
					return_route,
					_config.scout_travel_ticks_per_connection
				)
				task.elapsed_ticks = 0
			if not _advance_phase(task):
				return
			worker.zone_id = task.origin_zone_id
			state.record_observation_event(
				ObservationEvent.Type.SCOUT_RETURNED,
				worker.entity_id,
				ObservationEvent.NO_ENTITY_ID,
				task.target_zone_id,
				task.origin_zone_id
			)
			task.reset_to_idle(
				state.simulation_tick
				+ _config.scout_decision_interval_ticks
			)


func _advance_migration_task(state: ColonyState, worker: AntModel) -> void:
	var task: MigrationTaskModel = worker.migration_task
	match task.state:
		MigrationTaskModel.State.MOVING_TO_MEMBER:
			if (
				not _migration_member_is_at_origin(state, task)
				or not _is_migration_target_comfortable(
					state,
					task.target_zone_id
				)
				or not state.is_zone_route_valid(
					task.route_zone_ids,
					task.origin_zone_id,
					task.member_origin_zone_id
				)
			):
				task.reset_to_idle(
					state.simulation_tick
					+ _config.migration_decision_interval_ticks
				)
				return
			if not _advance_phase(task):
				return
			worker.zone_id = task.member_origin_zone_id
			task.begin(
				MigrationTaskModel.State.PICKING_UP,
				task.origin_zone_id,
				task.member_origin_zone_id,
				task.target_entity_id,
				task.target_zone_id,
				[task.member_origin_zone_id],
				_config.migration_pickup_duration_ticks
			)
		MigrationTaskModel.State.PICKING_UP:
			if (
				not _migration_member_is_at_origin(state, task)
				or not _is_migration_target_comfortable(
					state,
					task.target_zone_id
				)
			):
				task.reset_to_idle(
					state.simulation_tick
					+ _config.migration_decision_interval_ticks
				)
				return
			if not _advance_phase(task):
				return
			_set_member_zone(state, task.target_entity_id, &"")
			task.carried_entity_id = task.target_entity_id
			var carry_route: Array[StringName] = state.find_stable_zone_path(
				task.member_origin_zone_id,
				task.target_zone_id
			)
			task.begin(
				MigrationTaskModel.State.CARRYING_TO_ZONE,
				task.origin_zone_id,
				task.member_origin_zone_id,
				task.target_entity_id,
				task.target_zone_id,
				carry_route,
				_travel_duration(
					carry_route,
					_config.migration_travel_ticks_per_connection
				)
			)
			state.record_observation_event(
				ObservationEvent.Type.MIGRATION_MEMBER_PICKED_UP,
				worker.entity_id,
				task.target_entity_id,
				task.member_origin_zone_id,
				task.target_zone_id
			)
		MigrationTaskModel.State.CARRYING_TO_ZONE:
			if (
				not task.returning_to_origin
				and (
					state.colony_work_state.migration_target_zone_id
						!= task.target_zone_id
					or not _is_migration_target_comfortable(
						state,
						task.target_zone_id
					)
				)
			):
				task.returning_to_origin = true
				task.target_zone_id = task.member_origin_zone_id
				task.route_zone_ids = [task.member_origin_zone_id]
				task.elapsed_ticks = 0
				task.duration_ticks = 1
			if not state.is_zone_route_valid(
				task.route_zone_ids,
				task.member_origin_zone_id,
				task.target_zone_id
			):
				var restored_route: Array[StringName] = (
					state.find_stable_zone_path(
						task.member_origin_zone_id,
						task.target_zone_id
					)
				)
				if restored_route.is_empty():
					return
				task.route_zone_ids.assign(restored_route)
				task.duration_ticks = _travel_duration(
					restored_route,
					_config.migration_travel_ticks_per_connection
				)
				task.elapsed_ticks = 0
			if not _advance_phase(task):
				return
			worker.zone_id = task.target_zone_id
			task.begin(
				MigrationTaskModel.State.DROPPING,
				task.origin_zone_id,
				task.member_origin_zone_id,
				task.target_entity_id,
				task.target_zone_id,
				[task.target_zone_id],
				_config.migration_drop_duration_ticks
			)
		MigrationTaskModel.State.DROPPING:
			var target_zone: HabitatZoneState = state.get_zone(
				task.target_zone_id
			)
			if target_zone == null or not target_zone.available:
				return
			if not _advance_phase(task):
				return
			_set_member_zone(
				state,
				task.carried_entity_id,
				task.target_zone_id
			)
			state.record_observation_event(
				ObservationEvent.Type.MIGRATION_MEMBER_DROPPED,
				worker.entity_id,
				task.carried_entity_id,
				task.member_origin_zone_id,
				task.target_zone_id
			)
			task.reset_to_idle(
				state.simulation_tick
				+ _config.migration_decision_interval_ticks
			)


func _waste_task_has_live_references(
	state: ColonyState,
	task: WasteCleanupTaskModel
) -> bool:
	var source: HabitatZoneState = state.get_zone(task.source_zone_id)
	var target: HabitatZoneState = state.get_zone(task.target_zone_id)
	var tray: FacilityState = state.layout_state.get_facility(
		task.target_tray_facility_id
	)
	if (
		target == null
		or not target.available
		or tray == null
		or not tray.available
	):
		return false
	if task.carried_amount > EPSILON:
		return true
	return source != null and source.available


func _migration_member_is_at_origin(
	state: ColonyState,
	task: MigrationTaskModel
) -> bool:
	if task.target_entity_id == state.queen.entity_id:
		return state.queen.zone_id == task.member_origin_zone_id
	var ant: AntModel = state.get_ant(task.target_entity_id)
	return ant != null and ant.zone_id == task.member_origin_zone_id


func _set_member_zone(
	state: ColonyState,
	entity_id: int,
	zone_id: StringName
) -> void:
	if entity_id == state.queen.entity_id:
		state.queen.assign_zone(zone_id, state.simulation_tick)
		return
	var ant: AntModel = state.get_ant(entity_id)
	if ant != null:
		ant.zone_id = zone_id
		ant.zone_entered_tick = state.simulation_tick


func _is_migration_target_comfortable(
	state: ColonyState,
	zone_id: StringName
) -> bool:
	var zone: HabitatZoneState = state.get_zone(zone_id)
	return (
		zone != null
		and zone.available
		and zone.discovered
		and _is_habitat_zone(state, zone_id)
		and zone.humidity + EPSILON >= _brood_config.brood_humidity_min
		and zone.humidity <= _brood_config.brood_humidity_max + EPSILON
		and zone.pollution <= _config.migration_pollution_max + EPSILON
		and zone.light_exposure
			<= _environment_config.queen_care_light_max + EPSILON
	)


func _nest_penalty(zone: HabitatZoneState) -> float:
	var humidity_penalty: float = 0.0
	if zone.humidity < _brood_config.brood_humidity_min:
		humidity_penalty = _brood_config.brood_humidity_min - zone.humidity
	elif zone.humidity > _brood_config.brood_humidity_max:
		humidity_penalty = zone.humidity - _brood_config.brood_humidity_max
	var pollution_penalty: float = maxf(
		0.0,
		zone.pollution - _config.migration_pollution_max
	)
	var light_penalty: float = maxf(
		0.0,
		zone.light_exposure - _environment_config.queen_care_light_max
	)
	return humidity_penalty + pollution_penalty + light_penalty


func _is_habitat_zone(state: ColonyState, zone_id: StringName) -> bool:
	for facility: FacilityState in state.layout_state.get_facilities_in_stable_order():
		if not facility.available or facility.zone_id != zone_id:
			continue
		var type_config: FacilityConfig = _catalog.get_type(facility.type_id)
		if (
			type_config != null
			and type_config.effect_config != null
			and type_config.effect_config.provides_zone()
		):
			return true
	return false


func _is_migration_complete(
	state: ColonyState,
	target_zone_id: StringName
) -> bool:
	return (
		state.queen.zone_id == target_zone_id
		and _all_brood_in_zone(state, target_zone_id)
	)


func _all_brood_in_zone(
	state: ColonyState,
	target_zone_id: StringName
) -> bool:
	for ant: AntModel in state.ants:
		if (
			ant.life_stage != AntModel.LifeStage.WORKER
			and ant.zone_id != target_zone_id
		):
			return false
	return true


func _is_reserved_by_brood_relocation(
	state: ColonyState,
	entity_id: int
) -> bool:
	for worker: AntModel in _workers_in_stable_order(state):
		if (
			worker.worker_task != null
			and worker.worker_task.state != WorkerTaskModel.State.IDLE
			and (
				worker.worker_task.target_brood_id == entity_id
				or worker.worker_task.carried_brood_id == entity_id
			)
		):
			return true
	return false


func _has_active_migration_task(state: ColonyState) -> bool:
	for worker: AntModel in _workers_in_stable_order(state):
		if (
			worker.migration_task != null
			and worker.migration_task.state != MigrationTaskModel.State.IDLE
		):
			return true
	return false


func _has_carried_migration_member(state: ColonyState) -> bool:
	for worker: AntModel in _workers_in_stable_order(state):
		if (
			worker.migration_task != null
			and worker.migration_task.carried_entity_id >= 0
		):
			return true
	return false


func _active_task_count(worker: AntModel) -> int:
	var count: int = 0
	if worker.worker_task.state != WorkerTaskModel.State.IDLE:
		count += 1
	if worker.foraging_task.state != ForagingTaskModel.State.IDLE:
		count += 1
	if (
		worker.feeding_task != null
		and worker.feeding_task.state != BroodFeedingTaskModel.State.IDLE
	):
		count += 1
	if (
		worker.waste_cleanup_task.state
		!= WasteCleanupTaskModel.State.IDLE
	):
		count += 1
	if worker.scout_task.state != ScoutTaskModel.State.IDLE:
		count += 1
	if worker.migration_task.state != MigrationTaskModel.State.IDLE:
		count += 1
	return count


func _route_is_discovered(
	state: ColonyState,
	route: Array[StringName]
) -> bool:
	for zone_id: StringName in route:
		var zone: HabitatZoneState = state.get_zone(zone_id)
		if zone == null or not zone.discovered:
			return false
	return true


func _route_reaches_first_unknown(
	state: ColonyState,
	route: Array[StringName]
) -> bool:
	if route.size() < 2:
		return false
	for index: int in route.size():
		var zone: HabitatZoneState = state.get_zone(route[index])
		if zone == null:
			return false
		if index == route.size() - 1:
			return not zone.discovered
		if not zone.discovered:
			return false
	return false


func _travel_duration(
	route: Array[StringName],
	ticks_per_connection: int
) -> int:
	return maxi(1, maxi(0, route.size() - 1) * ticks_per_connection)


func _advance_phase(task: Variant) -> bool:
	task.elapsed_ticks += 1
	return task.elapsed_ticks >= task.duration_ticks


func _reset_migration_candidate(work: ColonyWorkState) -> void:
	work.migration_candidate_zone_id = &""
	work.migration_candidate_stable_ticks = 0


func _workers_in_stable_order(state: ColonyState) -> Array[AntModel]:
	var workers: Array[AntModel] = []
	for ant: AntModel in state.ants:
		if ant.life_stage == AntModel.LifeStage.WORKER:
			workers.append(ant)
	workers.sort_custom(
		func(first: AntModel, second: AntModel) -> bool:
			return first.entity_id < second.entity_id
	)
	return workers


func _zones_in_stable_order(state: ColonyState) -> Array[HabitatZoneState]:
	var ordered: Array[HabitatZoneState] = []
	ordered.assign(state.zones)
	ordered.sort_custom(
		func(first: HabitatZoneState, second: HabitatZoneState) -> bool:
			return String(first.zone_id) < String(second.zone_id)
	)
	return ordered
