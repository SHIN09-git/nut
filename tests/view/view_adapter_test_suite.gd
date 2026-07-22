class_name ViewAdapterTestSuite
extends RefCounted

const SPECIES_A_DATA: SpeciesData = preload("res://data/species/species_a.tres")
const HABITAT_SCENE: PackedScene = preload(
	"res://scenes/habitat/test_tube_habitat.tscn"
)

var _assertion_count: int = 0
var _failure_count: int = 0
var _scene_root: Node


func run(scene_root: Node) -> void:
	_scene_root = scene_root
	_test_species_a_lifecycle_reuses_one_view()
	_test_repeated_and_equivalent_snapshots_are_idempotent()
	_test_mapping_uses_entity_id_instead_of_snapshot_order()
	_test_absent_entities_are_removed_immediately()
	_test_paused_visuals_do_not_advance_transition_animation()


func get_assertion_count() -> int:
	return _assertion_count


func get_failure_count() -> int:
	return _failure_count


func _test_species_a_lifecycle_reuses_one_view() -> void:
	var habitat: TestTubeHabitat = _create_habitat()
	var adapter: ColonyViewAdapter = habitat.get_view_adapter()
	var simulation: ColonySimulation = ColonySimulation.new(SPECIES_A_DATA)
	var first_egg_tick: int = SPECIES_A_DATA.first_egg_delay_ticks
	var larva_tick: int = first_egg_tick + SPECIES_A_DATA.egg_duration_ticks
	var pupa_tick: int = larva_tick + SPECIES_A_DATA.larva_duration_ticks
	var worker_tick: int = pupa_tick + SPECIES_A_DATA.pupa_duration_ticks
	var last_laying_tick: int = (
		first_egg_tick
		+ (
			SPECIES_A_DATA.max_first_generation_brood - 1
		) * SPECIES_A_DATA.egg_laying_interval_ticks
	)

	_advance_to_tick(simulation, first_egg_tick - 1)
	var snapshot: ColonySnapshot = simulation.create_snapshot()
	_expect_int(
		snapshot.simulation_tick,
		first_egg_tick - 1,
		"lifecycle fixture reaches the Resource-derived pre-laying Tick"
	)
	_expect_true(adapter.apply_snapshot(snapshot), "adapter accepts the pre-laying snapshot")
	_expect_int(adapter.get_ant_view_count(), 0, "no AntView exists before the first egg")

	_advance_to_tick(simulation, first_egg_tick)
	snapshot = simulation.create_snapshot()
	_expect_int(snapshot.simulation_tick, first_egg_tick, "fixture reaches the configured laying Tick")
	_expect_true(adapter.apply_snapshot(snapshot), "adapter accepts the first-egg snapshot")
	var first_view: AntView = adapter.get_ant_view(1)
	_expect_true(first_view != null, "entity 1 receives an AntView on the configured laying Tick")
	if first_view == null:
		_destroy_habitat(habitat)
		return
	_expect_int(first_view.get_entity_id(), 1, "the first AntView copies stable entity ID 1")
	_expect_int(
		first_view.get_life_stage(),
		AntModel.LifeStage.EGG,
		"entity 1 is visibly an egg on its configured laying Tick"
	)
	var stable_slot_position: Vector2 = first_view.position

	_advance_to_tick(simulation, larva_tick)
	snapshot = simulation.create_snapshot()
	_expect_int(snapshot.simulation_tick, larva_tick, "fixture reaches the configured larva Tick")
	_expect_true(adapter.apply_snapshot(snapshot), "adapter accepts the larva snapshot")
	_expect_reused_stage(
		adapter,
		first_view,
		AntModel.LifeStage.LARVA,
		"the configured boundary updates entity 1 in place to larva"
	)

	_advance_to_tick(simulation, pupa_tick)
	snapshot = simulation.create_snapshot()
	_expect_int(snapshot.simulation_tick, pupa_tick, "fixture reaches the configured pupa Tick")
	_expect_true(adapter.apply_snapshot(snapshot), "adapter accepts the pupa snapshot")
	_expect_reused_stage(
		adapter,
		first_view,
		AntModel.LifeStage.PUPA,
		"the configured boundary updates entity 1 in place to pupa"
	)

	_advance_to_tick(simulation, worker_tick)
	snapshot = simulation.create_snapshot()
	_expect_int(snapshot.simulation_tick, worker_tick, "fixture reaches the configured worker Tick")
	_expect_true(adapter.apply_snapshot(snapshot), "adapter accepts the worker snapshot")
	_expect_reused_stage(
		adapter,
		first_view,
		AntModel.LifeStage.WORKER,
		"the configured boundary updates entity 1 in place to worker"
	)
	_expect_int(first_view.get_transition_count(), 3, "three stage changes animate the existing view")
	_expect_vector2(first_view.position, stable_slot_position, "entity 1 keeps its display slot")
	if worker_tick < last_laying_tick:
		_advance_to_tick(simulation, last_laying_tick)
		_expect_true(
			adapter.apply_snapshot(simulation.create_snapshot()),
			"adapter accepts the Resource-derived final laying snapshot"
		)
	_expect_int(
		adapter.get_ant_view_count(),
		SPECIES_A_DATA.max_first_generation_brood,
		"the lifecycle creates exactly the configured number of AntViews"
	)
	_expect_int(
		_count_ant_view_children(adapter),
		SPECIES_A_DATA.max_first_generation_brood,
		"the adapter has no duplicate AntView children"
	)

	_destroy_habitat(habitat)


func _test_repeated_and_equivalent_snapshots_are_idempotent() -> void:
	var habitat: TestTubeHabitat = _create_habitat()
	var adapter: ColonyViewAdapter = habitat.get_view_adapter()
	var simulation: ColonySimulation = ColonySimulation.new(SPECIES_A_DATA)
	var last_laying_tick: int = (
		SPECIES_A_DATA.first_egg_delay_ticks
		+ (
			SPECIES_A_DATA.max_first_generation_brood - 1
		) * SPECIES_A_DATA.egg_laying_interval_ticks
	)
	_advance_to_tick(simulation, last_laying_tick)
	var snapshot: ColonySnapshot = simulation.create_snapshot()

	_expect_true(adapter.apply_snapshot(snapshot), "adapter accepts the fully laid snapshot")
	var original_views: Dictionary[int, AntView] = {}
	for entity_id: int in range(1, SPECIES_A_DATA.max_first_generation_brood + 1):
		var ant_view: AntView = adapter.get_ant_view(entity_id)
		_expect_true(ant_view != null, "entity %d has one AntView" % entity_id)
		if ant_view != null:
			original_views[entity_id] = ant_view

	_expect_true(adapter.apply_snapshot(snapshot), "adapter accepts the identical snapshot twice")
	_expect_int(
		adapter.get_ant_view_count(),
		SPECIES_A_DATA.max_first_generation_brood,
		"an identical snapshot does not grow the mapping"
	)
	_expect_int(
		_count_ant_view_children(adapter),
		SPECIES_A_DATA.max_first_generation_brood,
		"an identical snapshot creates no child nodes"
	)

	var equivalent_snapshot: ColonySnapshot = simulation.create_snapshot()
	_expect_true(
		adapter.apply_snapshot(equivalent_snapshot),
		"adapter accepts an equivalent snapshot made of fresh snapshot objects"
	)
	_expect_int(
		adapter.get_ant_view_count(),
		SPECIES_A_DATA.max_first_generation_brood,
		"an equivalent snapshot keeps the configured number of mapped views"
	)
	_expect_int(
		_count_ant_view_children(adapter),
		SPECIES_A_DATA.max_first_generation_brood,
		"an equivalent snapshot creates no child nodes"
	)
	for entity_id: int in range(1, SPECIES_A_DATA.max_first_generation_brood + 1):
		if not original_views.has(entity_id):
			continue
		var current_view: AntView = adapter.get_ant_view(entity_id)
		_expect_true(
			current_view == original_views[entity_id],
			"entity %d keeps the same view across repeated snapshots" % entity_id
		)
		_expect_int(
			current_view.get_transition_count(),
			0,
			"an unchanged stage does not replay entity %d's transition" % entity_id
		)

	_destroy_habitat(habitat)


func _test_mapping_uses_entity_id_instead_of_snapshot_order() -> void:
	var habitat: TestTubeHabitat = _create_habitat()
	var adapter: ColonyViewAdapter = habitat.get_view_adapter()
	var first_snapshot: ColonySnapshot = ColonySnapshot.new()
	first_snapshot.queen_entity_id = 0
	first_snapshot.ants.append(_make_ant_snapshot(1, AntModel.LifeStage.EGG))
	first_snapshot.ants.append(_make_ant_snapshot(2, AntModel.LifeStage.LARVA))
	_expect_true(adapter.apply_snapshot(first_snapshot), "adapter accepts the initial ordered snapshot")

	var entity_1_view: AntView = adapter.get_ant_view(1)
	var entity_2_view: AntView = adapter.get_ant_view(2)
	_expect_true(entity_1_view != null, "ordered snapshot creates entity 1's view")
	_expect_true(entity_2_view != null, "ordered snapshot creates entity 2's view")
	if entity_1_view == null or entity_2_view == null:
		_destroy_habitat(habitat)
		return
	var entity_1_position: Vector2 = entity_1_view.position
	var entity_2_position: Vector2 = entity_2_view.position
	_expect_true(
		not entity_1_position.is_equal_approx(entity_2_position),
		"stable IDs receive distinct display slots"
	)

	var reordered_snapshot: ColonySnapshot = ColonySnapshot.new()
	reordered_snapshot.queen_entity_id = 0
	reordered_snapshot.ants.append(_make_ant_snapshot(2, AntModel.LifeStage.PUPA))
	reordered_snapshot.ants.append(_make_ant_snapshot(1, AntModel.LifeStage.LARVA))
	_expect_true(adapter.apply_snapshot(reordered_snapshot), "adapter accepts a reordered snapshot")
	_expect_true(adapter.get_ant_view(1) == entity_1_view, "entity 1 remains mapped by ID")
	_expect_true(adapter.get_ant_view(2) == entity_2_view, "entity 2 remains mapped by ID")
	_expect_int(entity_1_view.get_life_stage(), AntModel.LifeStage.LARVA, "entity 1 updates its own stage")
	_expect_int(entity_2_view.get_life_stage(), AntModel.LifeStage.PUPA, "entity 2 updates its own stage")
	_expect_vector2(entity_1_view.position, entity_1_position, "entity 1 keeps its ID-derived slot")
	_expect_vector2(entity_2_view.position, entity_2_position, "entity 2 keeps its ID-derived slot")
	_expect_int(adapter.get_ant_view_count(), 2, "reordering does not change the mapped view count")
	_expect_int(_count_ant_view_children(adapter), 2, "reordering leaves no duplicate child views")

	_destroy_habitat(habitat)


func _test_absent_entities_are_removed_immediately() -> void:
	var habitat: TestTubeHabitat = _create_habitat()
	var adapter: ColonyViewAdapter = habitat.get_view_adapter()
	var initial_snapshot: ColonySnapshot = ColonySnapshot.new()
	initial_snapshot.queen_entity_id = 0
	initial_snapshot.ants.append(_make_ant_snapshot(1, AntModel.LifeStage.EGG))
	initial_snapshot.ants.append(_make_ant_snapshot(2, AntModel.LifeStage.EGG))
	_expect_true(adapter.apply_snapshot(initial_snapshot), "adapter accepts the removal fixture")
	var removed_view: AntView = adapter.get_ant_view(1)
	var retained_view: AntView = adapter.get_ant_view(2)
	_expect_true(removed_view != null, "removal fixture creates entity 1")
	_expect_true(retained_view != null, "removal fixture creates entity 2")
	if removed_view == null or retained_view == null:
		_destroy_habitat(habitat)
		return

	var reduced_snapshot: ColonySnapshot = ColonySnapshot.new()
	reduced_snapshot.queen_entity_id = 0
	reduced_snapshot.ants.append(_make_ant_snapshot(2, AntModel.LifeStage.EGG))
	_expect_true(adapter.apply_snapshot(reduced_snapshot), "adapter accepts a snapshot missing entity 1")
	_expect_true(not adapter.has_ant_view(1), "an absent entity is removed from the ID mapping")
	_expect_true(adapter.get_ant_view(1) == null, "removed entity 1 is no longer addressable")
	_expect_true(removed_view.get_parent() == null, "the absent entity is detached immediately")
	_expect_true(removed_view.is_queued_for_deletion(), "the detached absent view is scheduled for deletion")
	_expect_true(adapter.get_ant_view(2) == retained_view, "the present entity keeps its existing view")
	_expect_int(adapter.get_ant_view_count(), 1, "only the present entity remains mapped")
	_expect_int(_count_ant_view_children(adapter), 1, "only the present entity remains in the view tree")

	_expect_true(adapter.apply_snapshot(reduced_snapshot), "the reduced snapshot is idempotent")
	_expect_true(adapter.get_ant_view(2) == retained_view, "reapplying removal keeps the retained view")
	_expect_int(adapter.get_ant_view_count(), 1, "reapplying removal creates no replacement nodes")

	_destroy_habitat(habitat)


func _test_paused_visuals_do_not_advance_transition_animation() -> void:
	var habitat: TestTubeHabitat = _create_habitat()
	var adapter: ColonyViewAdapter = habitat.get_view_adapter()
	var snapshot: ColonySnapshot = ColonySnapshot.new()
	snapshot.queen_entity_id = 0
	snapshot.ants.append(_make_ant_snapshot(1, AntModel.LifeStage.EGG))
	_expect_true(adapter.apply_snapshot(snapshot), "adapter accepts the visual pause fixture")
	var ant_view: AntView = adapter.get_ant_view(1)
	_expect_true(ant_view != null, "visual pause fixture creates one AntView")
	if ant_view == null:
		_destroy_habitat(habitat)
		return

	ant_view._process(0.1)
	adapter.set_visuals_paused(true)
	var paused_scale: Vector2 = ant_view.scale
	var paused_alpha: float = ant_view.modulate.a
	ant_view._process(0.2)
	_expect_true(adapter.are_visuals_paused(), "adapter records the paused visual state")
	_expect_true(ant_view.are_visuals_paused(), "the AntView receives the paused visual state")
	_expect_true(adapter.get_queen_view().are_visuals_paused(), "the QueenView receives the paused visual state")
	_expect_vector2(ant_view.scale, paused_scale, "paused transition scale does not advance")
	_expect_float(ant_view.modulate.a, paused_alpha, "paused transition opacity does not advance")

	adapter.set_visuals_paused(false)
	ant_view._process(0.2)
	_expect_true(not ant_view.are_visuals_paused(), "resuming clears the AntView pause state")
	_expect_true(
		not ant_view.scale.is_equal_approx(paused_scale),
		"resumed transition animation advances again"
	)

	_destroy_habitat(habitat)


func _create_habitat() -> TestTubeHabitat:
	var habitat: TestTubeHabitat = HABITAT_SCENE.instantiate() as TestTubeHabitat
	habitat.custom_minimum_size = Vector2(960.0, 300.0)
	_scene_root.add_child(habitat)
	return habitat


func _destroy_habitat(habitat: TestTubeHabitat) -> void:
	_scene_root.remove_child(habitat)
	habitat.free()


func _make_ant_snapshot(
	entity_id: int,
	life_stage: AntModel.LifeStage
) -> AntSnapshot:
	return AntSnapshot.new(entity_id, life_stage, 0, 0, 1)


func _advance_to_tick(simulation: ColonySimulation, target_tick: int) -> void:
	var next_tick: int = simulation.create_snapshot().simulation_tick + 1
	while next_tick <= target_tick:
		if not simulation.advance_tick(next_tick):
			_record_failure(
				"sequential view fixture Tick is accepted",
				"true",
				"false at Tick %d" % next_tick
			)
			return
		next_tick += 1


func _expect_reused_stage(
	adapter: ColonyViewAdapter,
	expected_view: AntView,
	expected_stage: AntModel.LifeStage,
	message: String
) -> void:
	var current_view: AntView = adapter.get_ant_view(expected_view.get_entity_id())
	_expect_true(current_view != null, "%s creates an addressable view" % message)
	if current_view == null:
		return
	_expect_true(current_view == expected_view, "%s keeps the same Node instance" % message)
	_expect_int(current_view.get_life_stage(), expected_stage, message)


func _count_ant_view_children(adapter: ColonyViewAdapter) -> int:
	var count: int = 0
	for child: Node in adapter.get_children():
		if child is AntView:
			count += 1
	return count


func _expect_int(actual: int, expected: int, message: String) -> void:
	_assertion_count += 1
	if actual == expected:
		return
	_record_failure(message, str(expected), str(actual))


func _expect_float(actual: float, expected: float, message: String) -> void:
	_assertion_count += 1
	if is_equal_approx(actual, expected):
		return
	_record_failure(message, str(expected), str(actual))


func _expect_vector2(actual: Vector2, expected: Vector2, message: String) -> void:
	_assertion_count += 1
	if actual.is_equal_approx(expected):
		return
	_record_failure(message, str(expected), str(actual))


func _expect_true(actual: bool, message: String) -> void:
	_assertion_count += 1
	if actual:
		return
	_record_failure(message, "true", "false")


func _record_failure(message: String, expected: String, actual: String) -> void:
	_failure_count += 1
	printerr("  %s - expected %s, got %s" % [message, expected, actual])
