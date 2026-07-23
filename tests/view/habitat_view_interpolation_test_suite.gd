class_name HabitatViewInterpolationTestSuite
extends RefCounted

const HABITAT_SCENE: PackedScene = preload(
	"res://scenes/habitat/humidity_habitat.tscn"
)
const LEFT_ZONE_ID: StringName = &"left_chamber"
const RIGHT_ZONE_ID: StringName = &"right_chamber"
const WORKER_ID: int = 10
const BROOD_ID: int = 20

var _assertion_count: int = 0
var _failure_count: int = 0
var _scene_root: Node


func run(scene_root: Node) -> void:
	_scene_root = scene_root
	_test_interpolation_uses_adjacent_tick_endpoints()
	_test_pause_freezes_interpolation_and_snapshot_is_read_only()
	_test_new_and_missing_entities_follow_stable_mapping_rules()
	_test_task_state_position_endpoints_are_continuous()
	_test_carried_brood_stays_attached_during_interpolation()
	_test_projection_reset_starts_a_clean_tick_zero_session()


func get_assertion_count() -> int:
	return _assertion_count


func get_failure_count() -> int:
	return _failure_count


func _test_interpolation_uses_adjacent_tick_endpoints() -> void:
	var habitat: HabitatView = _create_habitat()
	var first_snapshot: ColonySnapshot = _make_snapshot(
		1,
		WorkerTaskModel.State.IDLE,
		0,
		0,
		LEFT_ZONE_ID,
		LEFT_ZONE_ID
	)
	_expect_true(habitat.apply_snapshot(first_snapshot), "initial Tick is accepted")
	var worker_view: AntView = habitat.get_ant_view(WORKER_ID)
	_expect_true(worker_view != null, "initial Tick creates the worker view")
	if worker_view == null:
		_destroy_habitat(habitat)
		return
	var first_position: Vector2 = worker_view.position

	var second_snapshot: ColonySnapshot = _make_snapshot(
		2,
		WorkerTaskModel.State.IDLE,
		0,
		0,
		RIGHT_ZONE_ID,
		LEFT_ZONE_ID
	)
	_expect_true(habitat.apply_snapshot(second_snapshot), "next Tick is accepted")
	habitat.set_interpolation_alpha(1.0)
	var second_position: Vector2 = worker_view.position
	_expect_true(
		not second_position.is_equal_approx(first_position),
		"fixture has distinct adjacent Tick endpoints"
	)

	habitat.set_interpolation_alpha(-2.0)
	_expect_vector2(worker_view.position, first_position, "alpha is clamped to zero")
	habitat.set_interpolation_alpha(0.5)
	_expect_vector2(
		worker_view.position,
		first_position.lerp(second_position, 0.5),
		"alpha 0.5 renders the midpoint"
	)
	habitat.set_interpolation_alpha(4.0)
	_expect_vector2(worker_view.position, second_position, "alpha is clamped to one")

	var original_view: AntView = worker_view
	_expect_true(
		habitat.apply_snapshot(second_snapshot),
		"reapplying the same Tick is accepted"
	)
	habitat.set_interpolation_alpha(0.0)
	_expect_vector2(
		worker_view.position,
		first_position,
		"the same Tick does not rotate the interpolation endpoints"
	)
	_expect_true(
		habitat.get_ant_view(WORKER_ID) == original_view,
		"the same Tick reuses the stable entity view"
	)
	_expect_int(habitat.get_ant_view_count(), 2, "the same Tick creates no duplicate nodes")

	habitat.set_interpolation_alpha(1.0)
	_expect_true(not habitat.apply_snapshot(first_snapshot), "an older Tick is rejected")
	_expect_vector2(
		worker_view.position,
		second_position,
		"rejecting an older Tick leaves the rendered position unchanged"
	)
	_expect_true(
		habitat.get_ant_view(WORKER_ID) == original_view,
		"rejecting an older Tick leaves the entity mapping unchanged"
	)

	_destroy_habitat(habitat)


func _test_pause_freezes_interpolation_and_snapshot_is_read_only() -> void:
	var habitat: HabitatView = _create_habitat()
	var first_snapshot: ColonySnapshot = _make_snapshot(
		1,
		WorkerTaskModel.State.IDLE,
		0,
		0,
		LEFT_ZONE_ID,
		LEFT_ZONE_ID
	)
	var second_snapshot: ColonySnapshot = _make_snapshot(
		2,
		WorkerTaskModel.State.IDLE,
		0,
		0,
		RIGHT_ZONE_ID,
		LEFT_ZONE_ID
	)
	var signature_before: String = _snapshot_signature(second_snapshot)
	_expect_true(habitat.apply_snapshot(first_snapshot), "pause fixture accepts the first Tick")
	_expect_true(habitat.apply_snapshot(second_snapshot), "pause fixture accepts the second Tick")
	var worker_view: AntView = habitat.get_ant_view(WORKER_ID)
	if worker_view == null:
		_record_failure("pause fixture creates a worker view", "AntView", "null")
		_destroy_habitat(habitat)
		return

	habitat.set_interpolation_alpha(0.25)
	var paused_position: Vector2 = worker_view.position
	habitat.set_visuals_paused(true)
	habitat.set_interpolation_alpha(0.9)
	_expect_vector2(
		worker_view.position,
		paused_position,
		"paused visuals ignore interpolation advancement"
	)
	habitat.set_visuals_paused(false)
	habitat.set_interpolation_alpha(0.9)
	_expect_true(
		not worker_view.position.is_equal_approx(paused_position),
		"resumed visuals accept interpolation advancement"
	)
	_expect_string(
		_snapshot_signature(second_snapshot),
		signature_before,
		"interpolation never mutates the source snapshot"
	)

	_destroy_habitat(habitat)


func _test_new_and_missing_entities_follow_stable_mapping_rules() -> void:
	var habitat: HabitatView = _create_habitat()
	var first_snapshot: ColonySnapshot = _make_snapshot(
		1,
		WorkerTaskModel.State.IDLE,
		0,
		0,
		LEFT_ZONE_ID,
		LEFT_ZONE_ID
	)
	_expect_true(habitat.apply_snapshot(first_snapshot), "mapping fixture accepts the first Tick")
	var worker_view: AntView = habitat.get_ant_view(WORKER_ID)

	var added_snapshot: ColonySnapshot = _make_snapshot(
		2,
		WorkerTaskModel.State.IDLE,
		0,
		0,
		LEFT_ZONE_ID,
		LEFT_ZONE_ID,
		true
	)
	_expect_true(habitat.apply_snapshot(added_snapshot), "a Tick with a new entity is accepted")
	var new_view: AntView = habitat.get_ant_view(30)
	_expect_true(new_view != null, "a new stable ID creates one view")
	if new_view != null:
		habitat.set_interpolation_alpha(0.0)
		var new_entity_start: Vector2 = new_view.position
		habitat.set_interpolation_alpha(1.0)
		_expect_vector2(
			new_view.position,
			new_entity_start,
			"a new entity has equal endpoints and does not jump in from another slot"
		)
	_expect_true(
		habitat.get_ant_view(WORKER_ID) == worker_view,
		"adding an entity preserves the existing stable view"
	)
	_expect_int(habitat.get_ant_view_count(), 3, "adding one entity creates exactly one view")

	var removed_snapshot: ColonySnapshot = _make_snapshot(
		3,
		WorkerTaskModel.State.IDLE,
		0,
		0,
		LEFT_ZONE_ID,
		LEFT_ZONE_ID,
		false,
		false
	)
	_expect_true(habitat.apply_snapshot(removed_snapshot), "a Tick missing brood is accepted")
	_expect_true(habitat.get_ant_view(BROOD_ID) == null, "missing entities are removed immediately")
	_expect_true(habitat.get_ant_view(30) == null, "all omitted entity IDs are removed")
	_expect_int(habitat.get_ant_view_count(), 1, "only the present entity remains mapped")

	_destroy_habitat(habitat)


func _test_task_state_position_endpoints_are_continuous() -> void:
	var habitat: HabitatView = _create_habitat()
	var moving_end: Dictionary[int, Vector2] = _apply_and_capture(
		habitat,
		_make_snapshot(1, WorkerTaskModel.State.MOVING_TO_BROOD, 10, 10)
	)
	var pickup_start: Dictionary[int, Vector2] = _apply_and_capture(
		habitat,
		_make_snapshot(2, WorkerTaskModel.State.PICKING_UP, 0, 10)
	)
	_expect_endpoints_equal(moving_end, pickup_start, "moving to pickup")

	var pickup_end: Dictionary[int, Vector2] = _apply_and_capture(
		habitat,
		_make_snapshot(3, WorkerTaskModel.State.PICKING_UP, 10, 10)
	)
	var carrying_start: Dictionary[int, Vector2] = _apply_and_capture(
		habitat,
		_make_snapshot(4, WorkerTaskModel.State.CARRYING_TO_ZONE, 0, 10)
	)
	_expect_endpoints_equal(pickup_end, carrying_start, "pickup to carrying")

	var carrying_end: Dictionary[int, Vector2] = _apply_and_capture(
		habitat,
		_make_snapshot(5, WorkerTaskModel.State.CARRYING_TO_ZONE, 10, 10)
	)
	var dropping_start: Dictionary[int, Vector2] = _apply_and_capture(
		habitat,
		_make_snapshot(6, WorkerTaskModel.State.DROPPING, 0, 10)
	)
	_expect_endpoints_equal(carrying_end, dropping_start, "carrying to dropping")

	var dropping_end: Dictionary[int, Vector2] = _apply_and_capture(
		habitat,
		_make_snapshot(7, WorkerTaskModel.State.DROPPING, 10, 10)
	)
	var idle_start: Dictionary[int, Vector2] = _apply_and_capture(
		habitat,
		_make_snapshot(
			8,
			WorkerTaskModel.State.IDLE,
			0,
			0,
			RIGHT_ZONE_ID,
			RIGHT_ZONE_ID
		)
	)
	_expect_endpoints_equal(dropping_end, idle_start, "dropping to idle")

	_destroy_habitat(habitat)


func _test_carried_brood_stays_attached_during_interpolation() -> void:
	var habitat: HabitatView = _create_habitat()
	_expect_true(
		habitat.apply_snapshot(
			_make_snapshot(1, WorkerTaskModel.State.CARRYING_TO_ZONE, 2, 10)
		),
		"carrying fixture accepts its first Tick"
	)
	_expect_true(
		habitat.apply_snapshot(
			_make_snapshot(2, WorkerTaskModel.State.CARRYING_TO_ZONE, 7, 10)
		),
		"carrying fixture accepts its second Tick"
	)
	var worker_view: AntView = habitat.get_ant_view(WORKER_ID)
	var brood_view: AntView = habitat.get_ant_view(BROOD_ID)
	if worker_view == null or brood_view == null:
		_record_failure("carrying fixture creates both views", "two AntViews", "missing")
		_destroy_habitat(habitat)
		return

	var expected_offset: Vector2
	for alpha: float in [0.0, 0.5, 1.0]:
		habitat.set_interpolation_alpha(alpha)
		var offset: Vector2 = brood_view.position - worker_view.position
		if alpha == 0.0:
			expected_offset = offset
		_expect_vector2(
			offset,
			expected_offset,
			"carried brood remains attached at alpha %.1f" % alpha
		)

	_destroy_habitat(habitat)


func _test_projection_reset_starts_a_clean_tick_zero_session() -> void:
	var habitat: HabitatView = _create_habitat()
	var old_session_snapshot: ColonySnapshot = _make_snapshot(
		90,
		WorkerTaskModel.State.IDLE,
		0,
		0,
		RIGHT_ZONE_ID,
		RIGHT_ZONE_ID,
		true
	)
	_expect_true(
		habitat.apply_snapshot(old_session_snapshot),
		"reset fixture accepts the old session snapshot"
	)
	var old_worker_view: AntView = habitat.get_ant_view(WORKER_ID)
	var old_brood_view: AntView = habitat.get_ant_view(BROOD_ID)
	habitat.set_interpolation_alpha(0.25)
	habitat.set_visuals_paused(true)

	habitat.reset_projection()
	habitat.reset_projection()
	_expect_int(
		habitat.get_ant_view_count(),
		0,
		"two consecutive resets leave no mapped entity views"
	)
	_expect_true(
		habitat.get_ant_view(WORKER_ID) == null,
		"reset clears stable entity lookup"
	)
	_expect_true(
		old_worker_view != null and old_worker_view.get_parent() == null,
		"reset detaches the old worker node from the projection tree"
	)
	_expect_true(
		old_brood_view != null and old_brood_view.get_parent() == null,
		"reset detaches the old brood node from the projection tree"
	)
	_expect_int(
		habitat.get_queen_view().entity_id,
		-1,
		"reset restores the queen projection to an unbound entity"
	)
	_expect_true(
		not habitat.get_queen_view().are_visuals_paused(),
		"reset clears the paused presentation state"
	)

	var new_session_snapshot: ColonySnapshot = _make_snapshot(
		0,
		WorkerTaskModel.State.IDLE,
		0,
		0,
		LEFT_ZONE_ID,
		LEFT_ZONE_ID
	)
	_expect_true(
		habitat.apply_snapshot(new_session_snapshot),
		"reset allows the new session to begin at Tick zero"
	)
	var new_worker_view: AntView = habitat.get_ant_view(WORKER_ID)
	var new_brood_view: AntView = habitat.get_ant_view(BROOD_ID)
	_expect_true(
		new_worker_view != null and new_worker_view != old_worker_view,
		"the new session creates a fresh worker view"
	)
	_expect_true(
		new_brood_view != null and new_brood_view != old_brood_view,
		"the new session creates a fresh brood view"
	)
	_expect_int(
		habitat.get_ant_view_count(),
		2,
		"the new session contains exactly its two snapshot entities"
	)
	if new_worker_view != null:
		var tick_zero_position: Vector2 = new_worker_view.position
		habitat.set_interpolation_alpha(0.0)
		_expect_vector2(
			new_worker_view.position,
			tick_zero_position,
			"reset clears old interpolation endpoints"
		)
	_expect_true(
		habitat.apply_snapshot(new_session_snapshot),
		"reapplying the new Tick zero snapshot is accepted"
	)
	_expect_int(
		habitat.get_ant_view_count(),
		2,
		"reapplying Tick zero after reset creates no duplicate views"
	)
	_expect_true(
		habitat.get_ant_view(WORKER_ID) == new_worker_view,
		"the new session reuses its own stable worker mapping"
	)

	_destroy_habitat(habitat)


func _apply_and_capture(
	habitat: HabitatView,
	snapshot: ColonySnapshot
) -> Dictionary[int, Vector2]:
	_expect_true(habitat.apply_snapshot(snapshot), "state boundary snapshot is accepted")
	habitat.set_interpolation_alpha(1.0)
	var positions: Dictionary[int, Vector2] = {}
	for entity_id: int in [WORKER_ID, BROOD_ID]:
		var ant_view: AntView = habitat.get_ant_view(entity_id)
		if ant_view != null:
			positions[entity_id] = ant_view.position
	return positions


func _expect_endpoints_equal(
	first: Dictionary[int, Vector2],
	second: Dictionary[int, Vector2],
	boundary_name: String
) -> void:
	for entity_id: int in [WORKER_ID, BROOD_ID]:
		_expect_true(
			first.has(entity_id) and second.has(entity_id),
			"%s boundary contains entity %d" % [boundary_name, entity_id]
		)
		if first.has(entity_id) and second.has(entity_id):
			_expect_vector2(
				second[entity_id],
				first[entity_id],
				"%s boundary is continuous for entity %d"
				% [boundary_name, entity_id]
			)


func _make_snapshot(
	tick: int,
	worker_state: int,
	elapsed_ticks: int,
	duration_ticks: int,
	worker_zone_id: StringName = LEFT_ZONE_ID,
	brood_zone_id: StringName = LEFT_ZONE_ID,
	include_extra_brood: bool = false,
	include_primary_brood: bool = true
) -> ColonySnapshot:
	var snapshot: ColonySnapshot = ColonySnapshot.new()
	snapshot.simulation_tick = tick
	snapshot.queen_entity_id = 0
	snapshot.zones.append(HabitatZoneSnapshot.new(
		LEFT_ZONE_ID,
		0.3,
		[RIGHT_ZONE_ID],
		true
	))
	snapshot.zones.append(HabitatZoneSnapshot.new(
		RIGHT_ZONE_ID,
		0.6,
		[LEFT_ZONE_ID],
		true
	))

	var is_active: bool = worker_state != WorkerTaskModel.State.IDLE
	var is_carrying: bool = (
		worker_state == WorkerTaskModel.State.CARRYING_TO_ZONE
		or worker_state == WorkerTaskModel.State.DROPPING
	)
	var task_origin_zone_id: StringName = LEFT_ZONE_ID if is_active else &""
	var target_brood_id: int = BROOD_ID if is_active else -1
	var target_zone_id: StringName = RIGHT_ZONE_ID if is_active else &""
	var carried_brood_id: int = BROOD_ID if is_carrying else -1
	snapshot.ants.append(AntSnapshot.new(
		WORKER_ID,
		AntModel.LifeStage.WORKER,
		0,
		0,
		0,
		worker_zone_id,
		0,
		-1,
		-1,
		worker_state,
		task_origin_zone_id,
		target_brood_id,
		target_zone_id,
		carried_brood_id,
		elapsed_ticks,
		duration_ticks
	))
	if include_primary_brood:
		snapshot.ants.append(AntSnapshot.new(
			BROOD_ID,
			AntModel.LifeStage.LARVA,
			0,
			0,
			1,
			&"" if is_carrying else brood_zone_id,
			0,
			WORKER_ID if is_active else -1,
			WORKER_ID if is_carrying else -1
		))
	if include_extra_brood:
		snapshot.ants.append(AntSnapshot.new(
			30,
			AntModel.LifeStage.PUPA,
			0,
			0,
			1,
			LEFT_ZONE_ID
		))
	return snapshot


func _snapshot_signature(snapshot: ColonySnapshot) -> String:
	var parts: PackedStringArray = [str(snapshot.simulation_tick)]
	for zone: HabitatZoneSnapshot in snapshot.zones:
		parts.append("%s:%.3f:%s" % [zone.zone_id, zone.humidity, zone.available])
	for ant: AntSnapshot in snapshot.ants:
		parts.append("%d:%d:%s:%d:%d:%d" % [
			ant.entity_id,
			ant.life_stage,
			ant.zone_id,
			ant.worker_task_state,
			ant.task_elapsed_ticks,
			ant.carrier_ant_id,
		])
	return "|".join(parts)


func _create_habitat() -> HabitatView:
	var habitat: HabitatView = HABITAT_SCENE.instantiate() as HabitatView
	habitat.custom_minimum_size = Vector2(960.0, 360.0)
	_scene_root.add_child(habitat)
	return habitat


func _destroy_habitat(habitat: HabitatView) -> void:
	_scene_root.remove_child(habitat)
	habitat.free()


func _expect_int(actual: int, expected: int, message: String) -> void:
	_assertion_count += 1
	if actual == expected:
		return
	_record_failure(message, str(expected), str(actual))


func _expect_string(actual: String, expected: String, message: String) -> void:
	_assertion_count += 1
	if actual == expected:
		return
	_record_failure(message, expected, actual)


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
