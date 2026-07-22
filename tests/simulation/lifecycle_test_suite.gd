class_name LifecycleTestSuite
extends RefCounted

const SpeciesAData: SpeciesData = preload("res://data/species/species_a.tres")

var _assertion_count: int = 0
var _failure_count: int = 0
var _captured_entity_ids: Array[int] = []
var _captured_stages: Array[AntModel.LifeStage] = []
var _captured_transition_ticks: Array[int] = []
var _captured_laid_entity_ids: Array[int] = []
var _captured_laying_ticks: Array[int] = []


func run() -> void:
	_test_exact_stage_boundaries_and_signals()
	_test_laying_limit_and_stable_ids()
	_test_same_tick_transitions_follow_stable_id_order()
	_test_species_a_worker_schedule()
	_test_non_sequential_tick_is_rejected()
	_test_matching_inputs_are_deterministic()
	_test_runtime_config_is_copied_from_resource()
	_test_snapshot_is_isolated_from_runtime_state()
	_test_speed_only_changes_wall_clock_pacing()
	_test_clock_backlog_matches_direct_ticks()
	_test_species_data_validation()
	_test_ten_thousand_tick_lifecycle_soak()


func get_assertion_count() -> int:
	return _assertion_count


func get_failure_count() -> int:
	return _failure_count


func _test_exact_stage_boundaries_and_signals() -> void:
	var species_data: SpeciesData = _make_species_data(1, 100, 2, 3, 4, 1)
	var simulation: ColonySimulation = ColonySimulation.new(species_data)
	_captured_entity_ids.clear()
	_captured_stages.clear()
	_captured_transition_ticks.clear()
	simulation.life_stage_changed.connect(_capture_stage_transition)

	_expect_true(simulation.advance_tick(1), "Tick 1 is accepted")
	var snapshot: ColonySnapshot = simulation.create_snapshot()
	_expect_int(snapshot.ants.size(), 1, "queen lays the first egg on the configured Tick")
	_expect_int(snapshot.ants[0].life_stage, AntModel.LifeStage.EGG, "new brood starts as an egg")
	_expect_int(snapshot.ants[0].stage_age_ticks, 0, "new egg starts with zero stage age")

	_expect_true(simulation.advance_tick(2), "Tick 2 is accepted")
	snapshot = simulation.create_snapshot()
	_expect_int(
		snapshot.ants[0].life_stage,
		AntModel.LifeStage.EGG,
		"egg remains an egg before duration"
	)
	_expect_int(snapshot.ants[0].stage_age_ticks, 1, "egg age advances by one Tick")

	_advance_to_tick(simulation, 3)
	snapshot = simulation.create_snapshot()
	_expect_int(
		snapshot.ants[0].life_stage,
		AntModel.LifeStage.LARVA,
		"egg becomes larva at exact boundary"
	)
	_expect_int(snapshot.ants[0].stage_age_ticks, 0, "larva stage age resets to zero")

	_advance_to_tick(simulation, 6)
	snapshot = simulation.create_snapshot()
	_expect_int(
		snapshot.ants[0].life_stage,
		AntModel.LifeStage.PUPA,
		"larva becomes pupa at exact boundary"
	)

	_advance_to_tick(simulation, 10)
	snapshot = simulation.create_snapshot()
	_expect_int(
		snapshot.ants[0].life_stage,
		AntModel.LifeStage.WORKER,
		"pupa becomes worker at exact boundary"
	)
	_expect_int(snapshot.ants[0].entity_id, 1, "entity ID survives all stage transitions")
	_expect_int(_captured_stages.size(), 3, "three transitions emit three signals")
	_expect_int(_captured_entity_ids[0], 1, "transition signal keeps entity ID")
	_expect_int(_captured_stages[0], AntModel.LifeStage.LARVA, "first signal reports larva")
	_expect_int(_captured_stages[1], AntModel.LifeStage.PUPA, "second signal reports pupa")
	_expect_int(_captured_stages[2], AntModel.LifeStage.WORKER, "third signal reports worker")
	_expect_int(_captured_transition_ticks[0], 3, "larva signal uses exact Tick")
	_expect_int(_captured_transition_ticks[1], 6, "pupa signal uses exact Tick")
	_expect_int(_captured_transition_ticks[2], 10, "worker signal uses exact Tick")


func _test_laying_limit_and_stable_ids() -> void:
	var species_data: SpeciesData = _make_species_data(1, 2, 100, 100, 100, 3)
	var simulation: ColonySimulation = ColonySimulation.new(species_data)
	_captured_laid_entity_ids.clear()
	_captured_laying_ticks.clear()
	simulation.egg_laid.connect(_capture_egg_laid)
	_advance_to_tick(simulation, 20)
	var snapshot: ColonySnapshot = simulation.create_snapshot()

	_expect_int(snapshot.queen_laid_egg_count, 3, "queen stops at the first-generation limit")
	_expect_int(snapshot.ants.size(), 3, "colony contains exactly three first-generation brood")
	_expect_int(snapshot.ants[0].entity_id, 1, "first brood has stable ID 1")
	_expect_int(snapshot.ants[1].entity_id, 2, "second brood has stable ID 2")
	_expect_int(snapshot.ants[2].entity_id, 3, "third brood has stable ID 3")
	_expect_int(snapshot.next_egg_tick, -1, "no further egg is scheduled after the limit")
	_expect_int(_captured_laid_entity_ids.size(), 3, "each laid egg emits one signal")
	_expect_int(_captured_laid_entity_ids[0], 1, "first egg signal reports stable ID 1")
	_expect_int(_captured_laid_entity_ids[1], 2, "second egg signal reports stable ID 2")
	_expect_int(_captured_laid_entity_ids[2], 3, "third egg signal reports stable ID 3")
	_expect_int(_captured_laying_ticks[0], 1, "first egg signal reports the configured Tick")
	_expect_int(_captured_laying_ticks[1], 3, "second egg signal keeps the fixed interval")
	_expect_int(_captured_laying_ticks[2], 5, "third egg signal keeps the fixed interval")


func _test_same_tick_transitions_follow_stable_id_order() -> void:
	var simulation: ColonySimulation = ColonySimulation.new(_make_species_data(
		1, 1, 2, 1, 100, 2
	))
	_captured_entity_ids.clear()
	_captured_stages.clear()
	_captured_transition_ticks.clear()
	simulation.life_stage_changed.connect(_capture_stage_transition)
	_advance_to_tick(simulation, 4)

	_expect_int(_captured_transition_ticks.size(), 3, "fixture emits three transitions by Tick 4")
	_expect_int(_captured_transition_ticks[1], 4, "first simultaneous transition occurs at Tick 4")
	_expect_int(_captured_transition_ticks[2], 4, "second simultaneous transition occurs at Tick 4")
	_expect_int(_captured_entity_ids[1], 1, "lower stable ID transitions first on the same Tick")
	_expect_int(_captured_entity_ids[2], 2, "higher stable ID transitions second on the same Tick")


func _test_species_a_worker_schedule() -> void:
	var simulation: ColonySimulation = ColonySimulation.new(SpeciesAData)
	_advance_to_tick(simulation, 1199)
	_expect_int(simulation.create_snapshot().ants.size(), 0, "Species_A has no egg before Tick 1200")
	_advance_to_tick(simulation, 1200)
	_expect_int(
		simulation.create_snapshot().ants.size(),
		1,
		"Species_A lays its first egg at Tick 1200"
	)
	_advance_to_tick(simulation, 3999)
	_expect_int(
		simulation.create_snapshot().count_stage(AntModel.LifeStage.WORKER),
		0,
		"Species_A has no worker before Tick 4000"
	)

	_advance_to_tick(simulation, 4000)
	_expect_int(
		simulation.create_snapshot().count_stage(AntModel.LifeStage.WORKER),
		1,
		"first worker emerges at Tick 4000"
	)
	_advance_to_tick(simulation, 4300)
	_expect_int(
		simulation.create_snapshot().count_stage(AntModel.LifeStage.WORKER),
		2,
		"second worker emerges at Tick 4300"
	)
	_advance_to_tick(simulation, 4600)
	_expect_int(
		simulation.create_snapshot().count_stage(AntModel.LifeStage.WORKER),
		3,
		"third worker emerges at Tick 4600"
	)


func _test_non_sequential_tick_is_rejected() -> void:
	var simulation: ColonySimulation = ColonySimulation.new(_make_species_data(
		10, 10, 10, 10, 10, 1
	))
	_expect_true(simulation.advance_tick(1), "first sequential Tick is accepted")
	_expect_true(not simulation.advance_tick(3), "skipped Tick is rejected")
	_expect_int(simulation.create_snapshot().simulation_tick, 1, "rejected Tick does not mutate state")
	_expect_true(simulation.advance_tick(2), "correct next Tick remains accepted")


func _test_matching_inputs_are_deterministic() -> void:
	var first_simulation: ColonySimulation = ColonySimulation.new(SpeciesAData)
	var second_simulation: ColonySimulation = ColonySimulation.new(SpeciesAData)
	_advance_to_tick(first_simulation, 5000)
	_advance_to_tick(second_simulation, 5000)

	_expect_string(
		_create_signature(first_simulation.create_snapshot()),
		_create_signature(second_simulation.create_snapshot()),
		"matching lifecycle inputs produce matching snapshots"
	)


func _test_runtime_config_is_copied_from_resource() -> void:
	var source_data: SpeciesData = _make_species_data(1, 2, 2, 3, 4, 1)
	var simulation: ColonySimulation = ColonySimulation.new(source_data)
	source_data.first_egg_delay_ticks = 100
	source_data.egg_duration_ticks = 100
	source_data.larva_duration_ticks = 100
	source_data.pupa_duration_ticks = 100
	source_data.max_first_generation_brood = 10
	_advance_to_tick(simulation, 10)
	var snapshot: ColonySnapshot = simulation.create_snapshot()

	_expect_int(snapshot.ants.size(), 1, "runtime config keeps the original brood limit")
	_expect_int(
		snapshot.count_stage(AntModel.LifeStage.WORKER),
		1,
		"editing the source Resource cannot change active stage boundaries"
	)


func _test_snapshot_is_isolated_from_runtime_state() -> void:
	var simulation: ColonySimulation = ColonySimulation.new(_make_species_data(
		1, 100, 10, 10, 10, 1
	))
	_expect_true(simulation.advance_tick(1), "snapshot isolation fixture reaches its first egg")
	var mutable_snapshot: ColonySnapshot = simulation.create_snapshot()
	mutable_snapshot.simulation_tick = 999
	mutable_snapshot.queen_laid_egg_count = 999
	mutable_snapshot.ants[0].entity_id = 999
	mutable_snapshot.ants[0].life_stage = AntModel.LifeStage.WORKER
	mutable_snapshot.ants.clear()

	var fresh_snapshot: ColonySnapshot = simulation.create_snapshot()
	_expect_int(fresh_snapshot.simulation_tick, 1, "editing a snapshot cannot change the runtime Tick")
	_expect_int(
		fresh_snapshot.queen_laid_egg_count,
		1,
		"editing a snapshot cannot change queen state"
	)
	_expect_int(fresh_snapshot.ants.size(), 1, "snapshot arrays do not share runtime storage")
	_expect_int(fresh_snapshot.ants[0].entity_id, 1, "snapshot ants do not share runtime objects")
	_expect_int(
		fresh_snapshot.ants[0].life_stage,
		AntModel.LifeStage.EGG,
		"snapshot stage edits cannot change the runtime model"
	)


func _test_speed_only_changes_wall_clock_pacing() -> void:
	const TARGET_TICK: int = 100
	var signatures: PackedStringArray = []
	for speed_multiplier: int in [
		SimulationClock.NORMAL_SPEED,
		SimulationClock.FAST_SPEED,
		SimulationClock.VERY_FAST_SPEED,
	]:
		var simulation: ColonySimulation = ColonySimulation.new(_make_species_data(
			1, 2, 10, 10, 10, 3
		))
		var clock: SimulationClock = SimulationClock.new(TARGET_TICK)
		clock.set_speed_multiplier(speed_multiplier)
		clock.tick_requested.connect(func(
			tick_index: int,
			_tick_seconds: float
		) -> void:
			simulation.advance_tick(tick_index)
		)
		var wall_clock_seconds: float = (
			float(TARGET_TICK) * SimulationClock.FIXED_STEP_SECONDS
			/ float(speed_multiplier)
		)
		clock.advance(wall_clock_seconds)
		_expect_int(
			clock.get_tick_index(),
			TARGET_TICK,
			"%dx clock reaches the target Tick" % speed_multiplier
		)
		var snapshot: ColonySnapshot = simulation.create_snapshot()
		_expect_int(
			snapshot.simulation_tick,
			TARGET_TICK,
			"%dx clock delivers every sequential lifecycle Tick" % speed_multiplier
		)
		signatures.append(_create_signature(snapshot))

	_expect_string(signatures[1], signatures[0], "4x produces the same lifecycle snapshot as 1x")
	_expect_string(signatures[2], signatures[0], "16x produces the same lifecycle snapshot as 1x")


func _test_clock_backlog_matches_direct_ticks() -> void:
	const TARGET_TICK: int = 10
	var direct_simulation: ColonySimulation = ColonySimulation.new(_make_species_data(
		1, 2, 3, 3, 3, 3
	))
	_advance_to_tick(direct_simulation, TARGET_TICK)

	var backlog_simulation: ColonySimulation = ColonySimulation.new(_make_species_data(
		1, 2, 3, 3, 3, 3
	))
	var capped_clock: SimulationClock = SimulationClock.new(3)
	capped_clock.tick_requested.connect(func(
		tick_index: int,
		_tick_seconds: float
	) -> void:
		backlog_simulation.advance_tick(tick_index)
	)
	capped_clock.advance(1.0)
	var drain_iteration: int = 0
	while capped_clock.get_backlog_tick_count() > 0 and drain_iteration < 10:
		var previous_backlog: int = capped_clock.get_backlog_tick_count()
		capped_clock.advance(0.0)
		_expect_true(
			capped_clock.get_backlog_tick_count() < previous_backlog,
			"each lifecycle backlog drain iteration makes progress"
		)
		drain_iteration += 1

	_expect_int(capped_clock.get_tick_index(), TARGET_TICK, "capped clock drains every retained Tick")
	_expect_int(
		backlog_simulation.create_snapshot().simulation_tick,
		TARGET_TICK,
		"backlog delivers every retained lifecycle Tick"
	)
	_expect_string(
		_create_signature(backlog_simulation.create_snapshot()),
		_create_signature(direct_simulation.create_snapshot()),
		"drained backlog matches direct sequential lifecycle updates"
	)


func _test_species_data_validation() -> void:
	var species_data: SpeciesData = _make_species_data(1, 1, 1, 1, 1, 1)
	_expect_true(species_data.is_valid(), "positive lifecycle Tick values are accepted")
	species_data.pupa_duration_ticks = 0
	_expect_true(not species_data.is_valid(), "zero-duration lifecycle stages are rejected")
	var invalid_simulation: ColonySimulation = ColonySimulation.new(species_data)
	_expect_true(
		not invalid_simulation.is_ready(),
		"invalid SpeciesData creates an explicit error state"
	)
	_expect_true(not invalid_simulation.advance_tick(1), "invalid configuration cannot advance a Tick")
	_expect_int(
		invalid_simulation.create_snapshot().simulation_tick,
		0,
		"rejected invalid configuration leaves simulation state unchanged"
	)
	var missing_config_simulation: ColonySimulation = ColonySimulation.new(null)
	_expect_true(
		not missing_config_simulation.is_ready(),
		"missing SpeciesData creates an error state"
	)
	_expect_true(not missing_config_simulation.advance_tick(1), "missing SpeciesData cannot advance")


func _test_ten_thousand_tick_lifecycle_soak() -> void:
	var simulation: ColonySimulation = ColonySimulation.new(SpeciesAData)
	_advance_to_tick(simulation, 10_000)
	var snapshot: ColonySnapshot = simulation.create_snapshot()

	_expect_int(snapshot.simulation_tick, 10_000, "lifecycle soak reaches Tick 10,000")
	_expect_int(snapshot.ants.size(), 3, "lifecycle soak does not create extra brood")
	_expect_int(
		snapshot.count_stage(AntModel.LifeStage.WORKER),
		3,
		"all first-generation brood remain workers"
	)
	_expect_true(snapshot.ants[0].total_age_ticks > 0, "worker total age continues after emergence")


func _make_species_data(
	first_egg_delay_ticks: int,
	egg_laying_interval_ticks: int,
	egg_duration_ticks: int,
	larva_duration_ticks: int,
	pupa_duration_ticks: int,
	max_first_generation_brood: int
) -> SpeciesData:
	var species_data: SpeciesData = SpeciesData.new()
	species_data.species_id = &"test_species"
	species_data.display_name = "Test Species"
	species_data.first_egg_delay_ticks = first_egg_delay_ticks
	species_data.egg_laying_interval_ticks = egg_laying_interval_ticks
	species_data.egg_duration_ticks = egg_duration_ticks
	species_data.larva_duration_ticks = larva_duration_ticks
	species_data.pupa_duration_ticks = pupa_duration_ticks
	species_data.max_first_generation_brood = max_first_generation_brood
	return species_data


func _advance_to_tick(simulation: ColonySimulation, target_tick: int) -> void:
	var next_tick: int = simulation.create_snapshot().simulation_tick + 1
	while next_tick <= target_tick:
		if not simulation.advance_tick(next_tick):
			_record_failure(
				"sequential lifecycle Tick is accepted",
				"true",
				"false at Tick %d" % next_tick
			)
			return
		next_tick += 1


func _create_signature(snapshot: ColonySnapshot) -> String:
	var parts: PackedStringArray = [
		str(snapshot.simulation_tick),
		str(snapshot.queen_laid_egg_count),
	]
	for ant: AntSnapshot in snapshot.ants:
		parts.append(
			"%d:%d:%d:%d"
			% [
				ant.entity_id,
				ant.life_stage,
				ant.total_age_ticks,
				ant.stage_age_ticks,
			]
		)
	return "|".join(parts)


func _capture_stage_transition(
	entity_id: int,
	_previous_stage: AntModel.LifeStage,
	current_stage: AntModel.LifeStage,
	simulation_tick: int
) -> void:
	_captured_entity_ids.append(entity_id)
	_captured_stages.append(current_stage)
	_captured_transition_ticks.append(simulation_tick)


func _capture_egg_laid(entity_id: int, simulation_tick: int) -> void:
	_captured_laid_entity_ids.append(entity_id)
	_captured_laying_ticks.append(simulation_tick)


func _expect_int(actual: int, expected: int, message: String) -> void:
	_assertion_count += 1
	if actual == expected:
		return
	_record_failure(message, str(expected), str(actual))


func _expect_true(actual: bool, message: String) -> void:
	_assertion_count += 1
	if actual:
		return
	_record_failure(message, "true", "false")


func _expect_string(actual: String, expected: String, message: String) -> void:
	_assertion_count += 1
	if actual == expected:
		return
	_record_failure(message, expected, actual)


func _record_failure(message: String, expected: String, actual: String) -> void:
	_failure_count += 1
	printerr("  %s — expected %s, got %s" % [message, expected, actual])
