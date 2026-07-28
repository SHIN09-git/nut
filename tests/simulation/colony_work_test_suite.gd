class_name ColonyWorkTestSuite
extends RefCounted

const SPECIES_A_DATA: SpeciesData = preload(
	"res://data/species/species_a.tres"
)
const ACT1_SCENARIO_DATA: HabitatScenarioData = preload(
	"res://data/habitats/act1_test_tube.tres"
)
const BOX_TYPE_ID: StringName = &"small_foraging_box"
const WASTE_TYPE_ID: StringName = &"waste_tray"
const NEST_ZONE_ID: StringName = &"test_tube_nest"

var _assertion_count: int = 0
var _failure_count: int = 0


func run() -> void:
	_test_frozen_config_and_snapshot_isolation()
	_test_idle_work_task_residue_is_rejected()
	_test_scout_discovers_dynamic_zone()
	_test_waste_cleanup_and_clean_command_boundary()
	_test_migration_moves_brood_before_queen()
	_test_invalid_migration_target_returns_carried_brood()
	_test_active_work_save_restore_is_deterministic()


func get_assertion_count() -> int:
	return _assertion_count


func get_failure_count() -> int:
	return _failure_count


func _test_frozen_config_and_snapshot_isolation() -> void:
	var scenario: HabitatScenarioData = _work_scenario()
	var source_batch: float = scenario.colony_work_data.waste_batch_amount
	var simulation: ColonySimulation = ColonySimulation.new(
		SPECIES_A_DATA,
		scenario
	)
	_expect_true(simulation.is_ready(), "R9 frozen work fixture initializes")
	if not simulation.is_ready():
		return
	scenario.colony_work_data.waste_batch_amount = 0.31
	_expect_float(
		simulation._habitat_config.colony_work_config.waste_batch_amount,
		source_batch,
		"source Resource mutation cannot change frozen work pacing"
	)
	var mutable: ColonySnapshot = simulation.create_snapshot()
	mutable.work.completed_migration_count = 99
	mutable.zones[0].discovered = false
	var fresh: ColonySnapshot = simulation.create_snapshot()
	_expect_int(
		fresh.work.completed_migration_count,
		0,
		"work snapshot mutation cannot change authority"
	)
	_expect_true(
		fresh.zones[0].discovered,
		"discovery snapshot mutation cannot change authority"
	)


func _test_idle_work_task_residue_is_rejected() -> void:
	var simulation: ColonySimulation = _new_work_simulation()
	if not _expect_ready_worker(simulation, "idle task residue fixture"):
		return
	var worker: AntModel = null
	for ant: AntModel in simulation._state.ants:
		if ant.life_stage == AntModel.LifeStage.WORKER:
			worker = ant
			break
	_expect_true(worker != null, "idle task residue fixture resolves worker")
	if worker == null:
		return
	_expect_int(
		worker.waste_cleanup_task.state,
		WasteCleanupTaskModel.State.IDLE,
		"work invariant fixture starts with an idle cleanup task"
	)
	worker.waste_cleanup_task.target_zone_id = NEST_ZONE_ID
	_expect_true(
		not simulation.has_valid_habitat_ownership(),
		"idle cleanup task rejects stale authoritative target residue"
	)


func _test_scout_discovers_dynamic_zone() -> void:
	var simulation: ColonySimulation = _new_work_simulation()
	if not _expect_ready_worker(simulation, "scout fixture"):
		return
	var box_zone_id: StringName = _place_box(simulation)
	if box_zone_id.is_empty():
		return
	var placed: ColonySnapshot = simulation.create_snapshot()
	_expect_true(
		not placed.find_zone(box_zone_id).discovered,
		"new habitat zone starts undiscovered"
	)
	_expect_true(
		_advance_until_active_scout(
			simulation,
			simulation._state.simulation_tick + 30
		),
		"stable worker selection starts one scout task"
	)
	var discovered: bool = _advance_until_zone_discovered(
		simulation,
		box_zone_id,
		simulation._state.simulation_tick + 250
	)
	_expect_true(discovered, "scout discovers the connected habitat zone")
	if not discovered:
		return
	var snapshot: ColonySnapshot = simulation.create_snapshot()
	_expect_true(
		snapshot.find_zone(box_zone_id).discovered_tick > 0,
		"discovery publishes the authoritative discovery Tick"
	)
	_expect_int(
		snapshot.work.scouted_zone_count,
		1,
		"discovery increments the stable work counter once"
	)
	for tick: int in range(
		simulation._state.simulation_tick + 1,
		simulation._state.simulation_tick + 80
	):
		_expect_true(
			simulation.advance_tick(tick),
			"post-scout Tick %d advances" % tick
		)
	_expect_int(
		simulation.create_snapshot().work.scouted_zone_count,
		1,
		"known zone is not rediscovered"
	)


func _test_waste_cleanup_and_clean_command_boundary() -> void:
	var simulation: ColonySimulation = _new_work_simulation()
	if not _expect_ready_worker(simulation, "waste fixture"):
		return
	simulation._state.get_zone(NEST_ZONE_ID).set_pollution(0.50)
	var next_tick: int = simulation._state.simulation_tick + 1
	_expect_true(
		simulation.submit_place_facility_action(
			WASTE_TYPE_ID,
			Vector2i(1, 3),
			0
		),
		"waste tray placement enters the command queue"
	)
	_expect_true(
		simulation.advance_tick(next_tick),
		"waste tray placement Tick advances"
	)
	var tray_id: int = 3
	_expect_true(
		_advance_until_active_waste(
			simulation,
			simulation._state.simulation_tick + 30
		),
		"pollution starts one deterministic cleanup task"
	)
	var delivered: bool = _advance_until_waste_delivered(
		simulation,
		simulation._state.simulation_tick + 120
	)
	_expect_true(delivered, "worker delivers a finite pollution batch")
	if not delivered:
		return
	var tray: FacilityState = simulation._state.layout_state.get_facility(
		tray_id
	)
	_expect_true(
		tray.waste_stored > 0.0,
		"delivered waste belongs to the tray"
	)
	_expect_true(
		simulation.create_snapshot().work
			.cleanable_tray_facility_ids.has(tray_id),
		"idle filled tray publishes a clean action"
	)
	simulation._state.get_zone(NEST_ZONE_ID).set_pollution(0.0)
	var stored_before: float = tray.waste_stored
	_expect_true(
		simulation.submit_clean_waste_tray_action(tray_id),
		"high-level clean action is accepted"
	)
	_expect_float(
		tray.waste_stored,
		stored_before,
		"submitting clean does not mutate authority immediately"
	)
	var pending: ColonyWorkSnapshot = simulation.create_snapshot().work
	_expect_int(
		pending.clean_action_pending_facility_id,
		tray_id,
		"snapshot exposes the pending tray ID"
	)
	_expect_true(
		simulation.advance_tick(simulation._state.simulation_tick + 1),
		"clean action applies on the next Tick"
	)
	_expect_true(
		tray.waste_stored < 0.001,
		"next-Tick clean removes prior waste before environment advances"
	)
	_expect_int(
		simulation.create_snapshot().work.cleaned_waste_tray_count,
		1,
		"clean action increments its authoritative counter"
	)


func _test_migration_moves_brood_before_queen() -> void:
	var simulation: ColonySimulation = _new_work_simulation()
	if not _expect_ready_worker(simulation, "migration fixture"):
		return
	var box_zone_id: StringName = _place_and_discover_box(simulation)
	if box_zone_id.is_empty():
		return
	_prepare_migration_environment(simulation, box_zone_id)
	var completed: bool = _advance_until_migration_completed(
		simulation,
		simulation._state.simulation_tick + 500
	)
	_expect_true(completed, "stable better habitat completes migration")
	if not completed:
		return
	var snapshot: ColonySnapshot = simulation.create_snapshot()
	_expect_string(
		String(snapshot.queen_zone_id),
		String(box_zone_id),
		"queen finishes in the selected habitat"
	)
	for ant: AntSnapshot in snapshot.ants:
		if ant.life_stage != AntModel.LifeStage.WORKER:
			_expect_string(
				String(ant.zone_id),
				String(box_zone_id),
				"brood %d finishes in the selected habitat"
					% ant.entity_id
			)
	var dropped_ids: Array[int] = []
	for event: ObservationEvent in snapshot.observation_events:
		if (
			event.event_type
			== ObservationEvent.Type.MIGRATION_MEMBER_DROPPED
		):
			dropped_ids.append(event.subject_entity_id)
	_expect_true(
		dropped_ids.size() >= 3,
		"migration records brood and queen drops"
	)
	if not dropped_ids.is_empty():
		_expect_int(
			dropped_ids[-1],
			snapshot.queen_entity_id,
			"queen is the last migrated colony member"
		)
		for entity_id: int in dropped_ids.slice(
			0,
			dropped_ids.size() - 1
		):
			_expect_true(
				entity_id != snapshot.queen_entity_id,
				"all pre-queen migration drops are brood"
			)


func _test_invalid_migration_target_returns_carried_brood() -> void:
	var simulation: ColonySimulation = _new_work_simulation()
	if not _expect_ready_worker(simulation, "migration recovery fixture"):
		return
	var box_zone_id: StringName = _place_and_discover_box(simulation)
	if box_zone_id.is_empty():
		return
	_prepare_migration_environment(simulation, box_zone_id)
	var carried_id: int = _advance_until_migration_carry(
		simulation,
		simulation._state.simulation_tick + 250
	)
	_expect_true(
		carried_id > 0,
		"migration recovery fixture reaches carried ownership"
	)
	if carried_id <= 0:
		return
	simulation._state.get_zone(box_zone_id).set_light_exposure(1.0)
	var restored: bool = false
	for tick: int in range(
		simulation._state.simulation_tick + 1,
		simulation._state.simulation_tick + 120
	):
		if not simulation.advance_tick(tick):
			break
		var brood: AntModel = simulation._state.get_ant(carried_id)
		if brood != null and brood.zone_id == NEST_ZONE_ID:
			restored = true
			break
	_expect_true(
		restored,
		"environmental invalidation returns carried brood to origin"
	)
	_expect_true(
		simulation.has_valid_habitat_ownership(),
		"recovery preserves single ownership"
	)


func _test_active_work_save_restore_is_deterministic() -> void:
	var simulation: ColonySimulation = _new_work_simulation()
	if not _expect_ready_worker(simulation, "save fixture"):
		return
	var box_zone_id: StringName = _place_box(simulation)
	if box_zone_id.is_empty():
		return
	_expect_true(
		_advance_until_active_scout(
			simulation,
			simulation._state.simulation_tick + 30
		),
		"save fixture captures an active scout task"
	)
	var clock: SimulationClock = SimulationClock.new()
	clock.restore_save_boundary(
		simulation._state.simulation_tick,
		SimulationClock.NORMAL_SPEED,
		false
	)
	var service: SaveGameService = SaveGameService.new()
	var envelope: Dictionary = service.create_envelope(
		simulation,
		clock,
		"r9-active-work",
		"2026-07-28T00:00:00Z"
	)
	_expect_true(not envelope.is_empty(), "active work save is captured")
	if envelope.is_empty():
		return
	var result: Dictionary = service.load_envelope(envelope)
	_expect_true(
		result.get("ok", false),
		"active work save restores: %s" % result.get("error", "")
	)
	if not result.get("ok", false):
		return
	var restored: ColonySimulation = result["simulation"]
	_expect_string(
		SimulationSnapshotSignature.canonical_snapshot(
			restored.create_snapshot()
		),
		SimulationSnapshotSignature.canonical_snapshot(
			simulation.create_snapshot()
		),
		"restored work snapshot matches the exact save boundary"
	)
	for tick: int in range(
		simulation._state.simulation_tick + 1,
		simulation._state.simulation_tick + 150
	):
		var first_advanced: bool = simulation.advance_tick(tick)
		var second_advanced: bool = restored.advance_tick(tick)
		if not first_advanced or not second_advanced:
			_expect_true(false, "restored work Tick %d advances" % tick)
			return
	_expect_string(
		SimulationSnapshotSignature.canonical_snapshot(
			restored.create_snapshot()
		),
		SimulationSnapshotSignature.canonical_snapshot(
			simulation.create_snapshot()
		),
		"restored active work remains deterministic"
	)


func _work_scenario() -> HabitatScenarioData:
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
	scenario.colony_work_data = (
		ACT1_SCENARIO_DATA.colony_work_data.duplicate(true)
		as ColonyWorkData
	)
	scenario.founding_care_data = (
		ACT1_SCENARIO_DATA.founding_care_data.duplicate(true)
		as FoundingCareData
	)
	scenario.founding_care_data.first_worker_initial_pupa_age_ticks = (
		SPECIES_A_DATA.pupa_duration_ticks - 1
	)
	scenario.nutrition_data = (
		ACT1_SCENARIO_DATA.nutrition_data.duplicate(true)
		as NutritionData
	)
	scenario.nutrition_data.sugar_activity_ticks_per_portion = 10_000
	for facility_type: FacilityData in (
		scenario.facility_catalog_data.facility_types
	):
		if facility_type.type_id in [BOX_TYPE_ID, WASTE_TYPE_ID]:
			facility_type.unlock_type_id = CampaignState.FACILITY_MAGNIFIER
	return scenario


func _new_work_simulation() -> ColonySimulation:
	var simulation: ColonySimulation = ColonySimulation.new(
		SPECIES_A_DATA,
		_work_scenario()
	)
	if not simulation.is_ready():
		return simulation
	simulation._state.nutrition_state.sugar_activity_ticks_remaining = 9_999
	if not simulation.advance_tick(1):
		return simulation
	for ant: AntModel in simulation._state.ants:
		if ant.life_stage != AntModel.LifeStage.WORKER:
			ant.life_stage = AntModel.LifeStage.EGG
			ant.stage_age_ticks = 0
			ant.total_age_ticks = 0
	return simulation


func _expect_ready_worker(
	simulation: ColonySimulation,
	label: String
) -> bool:
	var ready: bool = simulation != null and simulation.is_ready()
	_expect_true(
		ready,
		"%s simulation is ready: %s"
		% [
			label,
			(
				simulation.get_configuration_error()
				if simulation != null
				else "null"
			),
		]
	)
	if not ready:
		return false
	var worker_found: bool = false
	for ant: AntSnapshot in simulation.create_snapshot().ants:
		if ant.life_stage == AntModel.LifeStage.WORKER:
			worker_found = true
			break
	_expect_true(worker_found, "%s has its first worker" % label)
	return worker_found


func _place_box(simulation: ColonySimulation) -> StringName:
	var next_tick: int = simulation._state.simulation_tick + 1
	_expect_true(
		simulation.submit_place_facility_action(
			BOX_TYPE_ID,
			Vector2i(5, 3),
			0
		),
		"box placement is accepted"
	)
	_expect_true(
		simulation.advance_tick(next_tick),
		"box placement Tick advances"
	)
	var facility: FacilitySnapshot = (
		simulation.create_game_snapshot().layout.get_facility(3)
	)
	_expect_true(facility != null, "placed box has stable facility ID 3")
	return facility.zone_id if facility != null else &""


func _place_and_discover_box(
	simulation: ColonySimulation
) -> StringName:
	var box_zone_id: StringName = _place_box(simulation)
	if box_zone_id.is_empty():
		return &""
	if not _advance_until_zone_discovered(
		simulation,
		box_zone_id,
		simulation._state.simulation_tick + 250
	):
		_expect_true(false, "box discovery completes")
		return &""
	for tick: int in range(
		simulation._state.simulation_tick + 1,
		simulation._state.simulation_tick + 120
	):
		var work: ColonyWorkSnapshot = simulation.create_snapshot().work
		if work.active_scout_task_count == 0:
			break
		if not simulation.advance_tick(tick):
			return &""
	return box_zone_id


func _advance_until_zone_discovered(
	simulation: ColonySimulation,
	zone_id: StringName,
	max_tick: int
) -> bool:
	while simulation._state.simulation_tick < max_tick:
		var zone: HabitatZoneSnapshot = (
			simulation.create_snapshot().find_zone(zone_id)
		)
		if zone != null and zone.discovered:
			return true
		if not simulation.advance_tick(
			simulation._state.simulation_tick + 1
		):
			return false
	return false


func _advance_until_active_scout(
	simulation: ColonySimulation,
	max_tick: int
) -> bool:
	while simulation._state.simulation_tick < max_tick:
		if simulation.create_snapshot().work.active_scout_task_count == 1:
			return true
		if not simulation.advance_tick(
			simulation._state.simulation_tick + 1
		):
			return false
	return false


func _advance_until_active_waste(
	simulation: ColonySimulation,
	max_tick: int
) -> bool:
	while simulation._state.simulation_tick < max_tick:
		if simulation.create_snapshot().work.active_waste_task_count == 1:
			return true
		if not simulation.advance_tick(
			simulation._state.simulation_tick + 1
		):
			return false
	return false


func _advance_until_waste_delivered(
	simulation: ColonySimulation,
	max_tick: int
) -> bool:
	while simulation._state.simulation_tick < max_tick:
		if (
			simulation.create_snapshot().work
				.delivered_waste_batch_count > 0
		):
			return true
		if not simulation.advance_tick(
			simulation._state.simulation_tick + 1
		):
			return false
	return false


func _prepare_migration_environment(
	simulation: ColonySimulation,
	target_zone_id: StringName
) -> void:
	var nest: HabitatZoneState = simulation._state.get_zone(NEST_ZONE_ID)
	nest.set_humidity(0.30)
	nest.set_light_exposure(0.80)
	nest.set_pollution(0.02)
	var target: HabitatZoneState = simulation._state.get_zone(
		target_zone_id
	)
	target.set_humidity(0.66)
	target.set_light_exposure(0.10)
	target.set_pollution(0.0)


func _advance_until_migration_completed(
	simulation: ColonySimulation,
	max_tick: int
) -> bool:
	while simulation._state.simulation_tick < max_tick:
		if simulation.create_snapshot().work.completed_migration_count > 0:
			return true
		if not simulation.advance_tick(
			simulation._state.simulation_tick + 1
		):
			return false
	return false


func _advance_until_migration_carry(
	simulation: ColonySimulation,
	max_tick: int
) -> int:
	while simulation._state.simulation_tick < max_tick:
		for ant: AntSnapshot in simulation.create_snapshot().ants:
			if (
				ant.migration_task != null
				and ant.migration_task.carried_entity_id > 0
			):
				return ant.migration_task.carried_entity_id
		if not simulation.advance_tick(
			simulation._state.simulation_tick + 1
		):
			return -1
	return -1


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


func _expect_string(
	actual: String,
	expected: String,
	message: String
) -> void:
	_assertion_count += 1
	if actual == expected:
		return
	_record_failure(message, expected, actual)


func _expect_float(
	actual: float,
	expected: float,
	message: String
) -> void:
	_assertion_count += 1
	if is_equal_approx(actual, expected):
		return
	_record_failure(message, str(expected), str(actual))


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
