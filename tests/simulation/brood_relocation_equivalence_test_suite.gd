class_name BroodRelocationEquivalenceTestSuite
extends RefCounted

const SPECIES_A_DATA: SpeciesData = preload("res://data/species/species_a.tres")
const HUMIDITY_SCENARIO_DATA: HabitatScenarioData = preload(
	"res://data/habitats/humidity_relocation_slice.tres"
)
const ROLLING_SEED: String = "brood-relocation-m2-golden-v1"
const POST_COMPLETION_TICKS: int = 100

const EXPECTED_FIRST_DROP_SNAPSHOT_DIGEST: String = (
	"161fc75a7e38a4cbc17380ebde878b231e93e948fe53d883cc8f9916ee3f613e"
)
const EXPECTED_ROLLING_DIGEST: String = (
	"16d5b9feaff775d9882dc9553aa5a6c12b368cac3febd35ef8a4fdff679a6f8f"
)
const EXPECTED_FINAL_SNAPSHOT_DIGEST: String = (
	"77c218aa2cce3fb4dfc100346ba57a4f6b9b4d2b1a2929a7b0cd54d0dec4b0f7"
)
const EXPECTED_FINAL_EVENT_DIGEST: String = (
	"f8bc73151aee5ede9deb8961d51f22229807b2bf04e07304c78af1c17273ca79"
)
const EXPECTED_RESTART_SNAPSHOT_DIGEST: String = (
	"9f702b9953a103373f150a16f2212bb2ae9ac69d3d5bf7fb333f3c3a3b87f744"
)

var _assertion_count: int = 0
var _failure_count: int = 0


func run() -> void:
	_test_pre_extraction_real_water_trace_matches_golden()


func get_assertion_count() -> int:
	return _assertion_count


func get_failure_count() -> int:
	return _failure_count


func _test_pre_extraction_real_water_trace_matches_golden() -> void:
	var trace: Dictionary = _capture_real_water_trace()

	_expect_string(
		String(trace.get("error", "")),
		"",
		"the canonical M2 water trace completes without a simulation error"
	)
	if not String(trace.get("error", "")).is_empty():
		return

	_expect_true(
		bool(trace.get("observation_unlocked", false)),
		"the real high-level water-command path unlocks its observation"
	)
	_expect_true(
		bool(trace.get("ownership_valid", false)),
		"the full golden trace preserves habitat ownership"
	)
	_expect_int(
		int(trace.get("water_action_count", -1)),
		_expected_water_action_count(),
		"the canonical path derives its water action count from Resources"
	)
	_expect_string(
		String(trace.get("completion_event_digest", "")),
		String(trace.get("final_event_digest", "")),
		"the post-completion stability window emits no duplicate event"
	)
	_expect_int(
		int(trace.get("first_drop_tick", -1)),
		_first_drop_tick(),
		"the golden reaches first drop on its Resource-derived boundary"
	)
	_expect_int(
		int(trace.get("final_tick", -1)),
		int(trace.get("completion_tick", -2)) + POST_COMPLETION_TICKS,
		"the bounded golden advances exactly 100 Ticks after completion"
	)
	_expect_int(
		int(trace.get("record_count", -1)),
		int(trace.get("final_tick", -2))
		+ int(trace.get("water_action_count", -2))
		+ 1,
		"the rolling digest covers every public command and Tick record"
	)
	_expect_string(
		String(trace.get("first_drop_snapshot_digest", "")),
		EXPECTED_FIRST_DROP_SNAPSHOT_DIGEST,
		"the first-drop public snapshot matches the pre-extraction golden"
	)
	_expect_string(
		String(trace.get("rolling_digest", "")),
		EXPECTED_ROLLING_DIGEST,
		"every public snapshot and command result matches the pre-extraction trace"
	)
	_expect_string(
		String(trace.get("final_snapshot_digest", "")),
		EXPECTED_FINAL_SNAPSHOT_DIGEST,
		"the final public snapshot matches the pre-extraction golden"
	)
	_expect_string(
		String(trace.get("final_event_digest", "")),
		EXPECTED_FINAL_EVENT_DIGEST,
		"the final structured event stream matches the pre-extraction golden"
	)
	_expect_string(
		String(trace.get("restart_snapshot_digest", "")),
		EXPECTED_RESTART_SNAPSHOT_DIGEST,
		"restart returns to the pre-extraction Tick-zero public snapshot"
	)


func _capture_real_water_trace() -> Dictionary:
	var simulation: ColonySimulation = ColonySimulation.new(
		SPECIES_A_DATA,
		HUMIDITY_SCENARIO_DATA
	)
	if not simulation.is_ready():
		return {
			"error": "simulation rejected the canonical Resources: %s"
			% simulation.get_configuration_error(),
		}

	var snapshot: ColonySnapshot = simulation.create_snapshot()
	var rolling_digest: String = ROLLING_SEED.sha256_text()
	rolling_digest = SimulationSnapshotSignature.roll_digest(
		rolling_digest,
		"initial|%s"
		% SimulationSnapshotSignature.canonical_snapshot(snapshot)
	)
	var record_count: int = 1
	var ownership_valid: bool = simulation.has_valid_habitat_ownership()
	var deadline_tick: int = _resource_derived_deadline_tick()
	var first_drop_snapshot_digest: String = ""

	while not snapshot.brood_humidity_observation_unlocked:
		if snapshot.simulation_tick >= deadline_tick:
			return {
				"error": "trace exceeded its Resource-derived deadline at Tick %d"
				% snapshot.simulation_tick,
			}

		if (
			snapshot.water_action_available
			and not snapshot.water_target_comfortable
		):
			var submit_accepted: bool = simulation.submit_water_action()
			if not submit_accepted:
				return {
					"error": "high-level water action was rejected at Tick %d"
						% snapshot.simulation_tick,
				}
			snapshot = simulation.create_snapshot()
			rolling_digest = SimulationSnapshotSignature.roll_digest(
				rolling_digest,
				"submit_water@%d|accepted=true|%s"
				% [
					snapshot.simulation_tick,
					SimulationSnapshotSignature.canonical_snapshot(snapshot),
				]
			)
			record_count += 1

		var next_tick: int = snapshot.simulation_tick + 1
		if not simulation.advance_tick(next_tick):
			return {
				"error": "simulation rejected sequential Tick %d" % next_tick,
			}
		snapshot = simulation.create_snapshot()
		ownership_valid = (
			ownership_valid
			and simulation.has_valid_habitat_ownership()
		)
		if next_tick == _first_drop_tick():
			first_drop_snapshot_digest = (
				SimulationSnapshotSignature.snapshot_digest(snapshot)
			)
		rolling_digest = SimulationSnapshotSignature.roll_digest(
			rolling_digest,
			"tick@%d|accepted=true|%s"
			% [
				next_tick,
				SimulationSnapshotSignature.canonical_snapshot(snapshot),
			]
		)
		record_count += 1

	var completion_tick: int = snapshot.simulation_tick
	var completion_event_digest: String = (
		SimulationSnapshotSignature.event_history_digest(
			snapshot.observation_events
		)
	)
	for _stability_tick: int in POST_COMPLETION_TICKS:
		var next_tick: int = snapshot.simulation_tick + 1
		if not simulation.advance_tick(next_tick):
			return {
				"error": "post-completion trace rejected Tick %d" % next_tick,
			}
		snapshot = simulation.create_snapshot()
		ownership_valid = (
			ownership_valid
			and simulation.has_valid_habitat_ownership()
		)
		rolling_digest = SimulationSnapshotSignature.roll_digest(
			rolling_digest,
			"tick@%d|accepted=true|%s"
			% [
				next_tick,
				SimulationSnapshotSignature.canonical_snapshot(snapshot),
			]
		)
		record_count += 1

	var final_snapshot_digest: String = (
		SimulationSnapshotSignature.snapshot_digest(snapshot)
	)
	var final_event_digest: String = (
		SimulationSnapshotSignature.event_history_digest(
			snapshot.observation_events
		)
	)
	if not simulation.restart_session():
		return {
			"error": "simulation rejected restart after the golden trace",
		}
	var restart_snapshot: ColonySnapshot = simulation.create_snapshot()
	return {
		"error": "",
		"first_drop_tick": _first_drop_tick(),
		"first_drop_snapshot_digest": first_drop_snapshot_digest,
		"completion_tick": completion_tick,
		"final_tick": snapshot.simulation_tick,
		"record_count": record_count,
		"water_action_count": snapshot.water_action_count,
		"rolling_digest": rolling_digest,
		"final_snapshot_digest": final_snapshot_digest,
		"completion_event_digest": completion_event_digest,
		"final_event_digest": final_event_digest,
		"restart_snapshot_digest": (
			SimulationSnapshotSignature.snapshot_digest(restart_snapshot)
		),
		"observation_unlocked": (
			snapshot.brood_humidity_observation_unlocked
		),
		"ownership_valid": ownership_valid,
	}


func _resource_derived_deadline_tick() -> int:
	var relocation_cycle_ticks: int = (
		SPECIES_A_DATA.decision_interval_ticks
		+ SPECIES_A_DATA.travel_duration_ticks * 2
		+ SPECIES_A_DATA.pickup_duration_ticks
		+ SPECIES_A_DATA.drop_duration_ticks
		+ SPECIES_A_DATA.minimum_zone_dwell_ticks
	)
	return (
		relocation_cycle_ticks
		* HUMIDITY_SCENARIO_DATA.initial_brood_count
		+ HUMIDITY_SCENARIO_DATA.observation_stable_ticks * 2
		+ _expected_water_action_count()
	)


func _first_drop_tick() -> int:
	return (
		SPECIES_A_DATA.decision_interval_ticks
		+ SPECIES_A_DATA.travel_duration_ticks
		+ SPECIES_A_DATA.pickup_duration_ticks
		+ SPECIES_A_DATA.travel_duration_ticks
		+ SPECIES_A_DATA.drop_duration_ticks
	)


func _expected_water_action_count() -> int:
	var target_zone: HabitatZoneData = _find_water_target_zone()
	if target_zone == null:
		return 0
	var humidity_gap: float = maxf(
		SPECIES_A_DATA.brood_humidity_min - target_zone.initial_humidity,
		0.0
	)
	if humidity_gap <= 0.0:
		return 0
	return ceili(
		(humidity_gap - SpeciesData.MIN_MEANINGFUL_IMPROVEMENT)
		/ HUMIDITY_SCENARIO_DATA.humidity_adjustment_amount
	)


func _find_water_target_zone() -> HabitatZoneData:
	for zone: HabitatZoneData in [
		HUMIDITY_SCENARIO_DATA.left_zone,
		HUMIDITY_SCENARIO_DATA.right_zone,
	]:
		if (
			zone != null
			and zone.zone_id
				== HUMIDITY_SCENARIO_DATA.humidity_adjustment_zone_id
		):
			return zone
	return null


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
	printerr("  %s - expected %s, got %s" % [message, expected, actual])
