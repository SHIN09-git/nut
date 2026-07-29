extends SceneTree

const SOAK_TICKS: int = 144_000
const CHECKPOINT_INTERVAL: int = 1_000
const INTERVENTION_INTERVAL: int = 5_000

var _failed: bool = false
var _failure_message: String = ""


func _initialize() -> void:
	call_deferred(&"_run")


func _run() -> void:
	var simulation: ColonySimulation = _create_completed_profile()
	if simulation == null or not simulation.is_ready():
		_fail("completed profile fixture did not initialize")
		_finish()
		return
	var starting_tick: int = simulation._state.simulation_tick
	var tick_durations_us: PackedInt64Array = []
	tick_durations_us.resize(SOAK_TICKS)
	var run_started_us: int = Time.get_ticks_usec()
	var maximum_static_memory: int = OS.get_static_memory_usage()
	var midpoint_save_bytes: int = 0

	for index: int in SOAK_TICKS:
		if (
			index > 0
			and index % INTERVENTION_INTERVAL == 0
			and index < SOAK_TICKS - 2
		):
			_submit_available_interventions(simulation)
		var tick_started_us: int = Time.get_ticks_usec()
		if not simulation.advance_tick(
			simulation._state.simulation_tick + 1
		):
			_fail("fixed Tick rejected at soak index %d" % index)
			break
		tick_durations_us[index] = Time.get_ticks_usec() - tick_started_us

		if (
			(index + 1) % CHECKPOINT_INTERVAL == 0
			and not _checkpoint_is_valid(simulation)
		):
			_fail("invalid authority at soak index %d" % (index + 1))
			break
		if index + 1 == SOAK_TICKS / 2:
			var round_trip: Dictionary = _round_trip(simulation)
			if not round_trip.get("ok", false):
				_fail(
					"midpoint save/load failed: %s"
					% round_trip.get("error", "")
				)
				break
			midpoint_save_bytes = int(round_trip["save_bytes"])
			simulation = round_trip["simulation"]
		maximum_static_memory = maxi(
			maximum_static_memory,
			OS.get_static_memory_usage()
		)

	if not _failed:
		if simulation._state.simulation_tick != starting_tick + SOAK_TICKS:
			_fail("soak ended at the wrong fixed Tick")
		elif not _checkpoint_is_valid(simulation):
			_fail("final authority checkpoint is invalid")

	if not _failed:
		var sorted_durations: Array[int] = []
		var duration_total_us: int = 0
		var duration_max_us: int = 0
		for duration_us: int in tick_durations_us:
			sorted_durations.append(duration_us)
			duration_total_us += duration_us
			duration_max_us = maxi(duration_max_us, duration_us)
		sorted_durations.sort()
		var p95_index: int = clampi(
			int(ceil(float(sorted_durations.size()) * 0.95)) - 1,
			0,
			sorted_durations.size() - 1
		)
		var elapsed_seconds: float = (
			float(Time.get_ticks_usec() - run_started_us) / 1_000_000.0
		)
		var final_snapshot: GameSnapshot = simulation.create_game_snapshot()
		print(
			(
				"R12_SOAK_PASS ticks=%d start_tick=%d end_tick=%d "
				+ "avg_tick_us=%.2f p95_tick_us=%d max_tick_us=%d "
				+ "elapsed_s=%.3f static_memory_bytes=%d save_bytes=%d "
				+ "signature=%s"
			)
			% [
				SOAK_TICKS,
				starting_tick,
				simulation._state.simulation_tick,
				float(duration_total_us) / float(SOAK_TICKS),
				sorted_durations[p95_index],
				duration_max_us,
				elapsed_seconds,
				maximum_static_memory,
				midpoint_save_bytes,
				SimulationSnapshotSignature.game_snapshot_digest(
					final_snapshot
				),
			]
		)
	_finish()


func _create_completed_profile() -> ColonySimulation:
	var simulation: ColonySimulation = Act1FinaleFixture.create_simulation()
	if simulation == null or not simulation.is_ready():
		return simulation
	var required: int = (
		simulation._habitat_config.act1_progression_config
			.finale_stable_ticks
	)
	for unused_tick: int in required + 1:
		if not simulation.advance_tick(simulation._state.simulation_tick + 1):
			return simulation
	if not simulation.submit_campaign_inference_action(
		CampaignState.INFERENCE_LAYOUT_SHAPES_BEHAVIOR
	):
		return simulation
	simulation.advance_tick(simulation._state.simulation_tick + 1)
	return simulation


func _submit_available_interventions(
	simulation: ColonySimulation
) -> void:
	var snapshot: GameSnapshot = simulation.create_game_snapshot()
	if snapshot.nutrition.sugar_action_available:
		simulation.submit_place_sugar_action()
	if snapshot.nutrition.protein_action_available:
		simulation.submit_place_protein_action()
	if not snapshot.work.cleanable_tray_facility_ids.is_empty():
		simulation.submit_clean_waste_tray_action(
			snapshot.work.cleanable_tray_facility_ids[0]
		)


func _checkpoint_is_valid(simulation: ColonySimulation) -> bool:
	if (
		simulation == null
		or not simulation.is_ready()
		or not simulation.has_valid_habitat_ownership()
	):
		return false
	var snapshot: GameSnapshot = simulation.create_game_snapshot()
	if (
		snapshot == null
		or not snapshot.campaign.completed
		or not snapshot.act1.final_report_available
	):
		return false
	for zone: HabitatZoneSnapshot in snapshot.colony.zones:
		if (
			not is_finite(zone.humidity)
			or zone.humidity < 0.0
			or zone.humidity > 1.0
			or not is_finite(zone.light_exposure)
			or zone.light_exposure < 0.0
			or zone.light_exposure > 1.0
			or not is_finite(zone.pollution)
			or zone.pollution < 0.0
			or zone.pollution > 1.0
		):
			return false
	return (
		snapshot.nutrition.sugar_reserve_portions >= 0
		and snapshot.nutrition.protein_reserve_portions >= 0
		and snapshot.work.active_migration_task_count >= 0
	)


func _round_trip(simulation: ColonySimulation) -> Dictionary:
	var clock := SimulationClock.new()
	clock.restore_save_boundary(
		simulation._state.simulation_tick,
		SimulationClock.VERY_FAST_SPEED,
		false
	)
	var service := SaveGameService.new()
	var envelope: Dictionary = service.create_envelope(
		simulation,
		clock,
		"r12_soak"
	)
	var encoded: String = service.encode_envelope(envelope)
	var before_signature: String = (
		SimulationSnapshotSignature.canonical_game_snapshot(
			simulation.create_game_snapshot()
		)
	)
	var result: Dictionary = service.load_envelope(envelope)
	if not result.get("ok", false):
		return result
	var restored: ColonySimulation = result["simulation"]
	if (
		SimulationSnapshotSignature.canonical_game_snapshot(
			restored.create_game_snapshot()
		)
		!= before_signature
	):
		return {
			"ok": false,
			"error": "midpoint snapshot signature changed",
		}
	return {
		"ok": true,
		"error": "",
		"simulation": restored,
		"save_bytes": encoded.to_utf8_buffer().size(),
	}


func _fail(message: String) -> void:
	_failed = true
	_failure_message = message
	printerr("R12_SOAK_FAIL %s" % message)


func _finish() -> void:
	quit(1 if _failed else 0)
