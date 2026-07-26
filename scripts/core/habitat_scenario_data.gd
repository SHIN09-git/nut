class_name HabitatScenarioData
extends Resource

enum ScenarioKind {
	HUMIDITY_RELOCATION,
	SUGAR_FORAGING,
	COMBINED_OBSERVATION,
}

@export var scenario_id: StringName = &""
@export var scenario_kind: ScenarioKind = ScenarioKind.HUMIDITY_RELOCATION
@export var data_status: StringName = &"prototype_pacing_fixture"
@export var scientifically_validated: bool = false
@export var zones: Array[HabitatZoneData] = []
@export_range(0, 20, 1) var initial_worker_count: int = 0
@export_range(0, 50, 1) var initial_brood_count: int = 0
@export_enum("Egg", "Larva", "Pupa") var initial_brood_stage: int = 0
@export var initial_worker_zone_id: StringName = &""
@export var initial_brood_zone_id: StringName = &""
@export var humidity_adjustment_zone_id: StringName = &""
@export_range(0.0, 1.0, 0.01) var humidity_adjustment_amount: float = 0.0
@export_range(0, 10_000, 1) var observation_stable_ticks: int = 0
@export var foraging_data: ForagingData
@export var nest_zone_id: StringName = &""
@export var sugar_placement_zone_id: StringName = &""
@export_range(0, 3, 1) var sugar_portions: int = 0
@export var foraging_observation_card_id: StringName = &""
@export var sequence_data: ScenarioSequenceData


func is_valid() -> bool:
	if (
		scenario_id.is_empty()
		or data_status.is_empty()
		or zones.size() < 2
		or zones.size() > 3
		or initial_worker_count < 0
		or initial_brood_count < 0
		or initial_brood_stage < 0
		or initial_brood_stage > 2
		or is_nan(humidity_adjustment_amount)
		or is_inf(humidity_adjustment_amount)
	):
		return false

	var known_zone_ids: Dictionary[StringName, bool] = {}
	for zone_data: HabitatZoneData in zones:
		if (
			zone_data == null
			or not zone_data.is_valid()
			or known_zone_ids.has(zone_data.zone_id)
		):
			return false
		known_zone_ids[zone_data.zone_id] = true
	if (
		not known_zone_ids.has(initial_worker_zone_id)
		or (
			initial_brood_count > 0
			and not known_zone_ids.has(initial_brood_zone_id)
		)
	):
		return false

	for zone_data: HabitatZoneData in zones:
		for connected_zone_id: StringName in zone_data.connected_zone_ids:
			if not known_zone_ids.has(connected_zone_id):
				return false

	match scenario_kind:
		ScenarioKind.HUMIDITY_RELOCATION:
			return (
				zones.size() == 2
				and initial_worker_count > 0
				and initial_brood_count > 0
				and known_zone_ids.has(humidity_adjustment_zone_id)
				and humidity_adjustment_amount > 0.0
				and observation_stable_ticks > 0
				and foraging_data == null
				and nest_zone_id.is_empty()
				and sugar_placement_zone_id.is_empty()
				and sugar_portions == 0
				and foraging_observation_card_id.is_empty()
				and sequence_data == null
			)
		ScenarioKind.SUGAR_FORAGING:
			return (
				zones.size() == 3
				and initial_worker_count > 0
				and initial_brood_count == 0
				and foraging_data != null
				and foraging_data.is_valid()
				and known_zone_ids.has(nest_zone_id)
				and known_zone_ids.has(sugar_placement_zone_id)
				and nest_zone_id != sugar_placement_zone_id
				and sugar_portions >= 1
				and sugar_portions <= 3
				and not foraging_observation_card_id.is_empty()
				and humidity_adjustment_zone_id.is_empty()
				and is_zero_approx(humidity_adjustment_amount)
				and observation_stable_ticks == 0
				and sequence_data == null
				and _has_available_path(
					nest_zone_id,
					sugar_placement_zone_id
				)
				and _has_available_path(
					sugar_placement_zone_id,
					nest_zone_id
				)
			)
		ScenarioKind.COMBINED_OBSERVATION:
			return (
				zones.size() == 3
				and initial_worker_count == 0
				and initial_brood_count > 0
				and initial_brood_stage == AntModel.LifeStage.LARVA
				and initial_worker_zone_id == initial_brood_zone_id
				and initial_worker_zone_id == nest_zone_id
				and humidity_adjustment_zone_id == nest_zone_id
				and humidity_adjustment_amount > 0.0
				and observation_stable_ticks > 0
				and foraging_data != null
				and foraging_data.is_valid()
				and known_zone_ids.has(nest_zone_id)
				and known_zone_ids.has(sugar_placement_zone_id)
				and nest_zone_id != sugar_placement_zone_id
				and sugar_portions >= 1
				and sugar_portions <= 3
				and not foraging_observation_card_id.is_empty()
				and sequence_data != null
				and sequence_data.is_valid()
				and foraging_observation_card_id
					!= sequence_data.first_worker_observation_card_id
				and foraging_observation_card_id
					!= sequence_data.brood_humidity_observation_card_id
				and _has_valid_combined_layout()
				and _has_available_path(
					nest_zone_id,
					sugar_placement_zone_id
				)
				and _has_available_path(
					sugar_placement_zone_id,
					nest_zone_id
				)
			)
		_:
			return false


func _has_valid_combined_layout() -> bool:
	var intermediate_zone_ids: Array[StringName] = []
	for zone_data: HabitatZoneData in zones:
		if zone_data == null or not zone_data.available:
			return false
		if (
			zone_data.zone_id != nest_zone_id
			and zone_data.zone_id != sugar_placement_zone_id
		):
			intermediate_zone_ids.append(zone_data.zone_id)
	if intermediate_zone_ids.size() != 1:
		return false

	var intermediate_zone_id: StringName = intermediate_zone_ids[0]
	var nest_connections: Array[StringName] = [intermediate_zone_id]
	var intermediate_connections: Array[StringName] = [
		nest_zone_id,
		sugar_placement_zone_id,
	]
	var placement_connections: Array[StringName] = [intermediate_zone_id]
	return (
		_has_exact_connections(nest_zone_id, nest_connections)
		and _has_exact_connections(
			intermediate_zone_id,
			intermediate_connections
		)
		and _has_exact_connections(
			sugar_placement_zone_id,
			placement_connections
		)
	)


func _has_exact_connections(
	zone_id: StringName,
	expected_connection_ids: Array[StringName]
) -> bool:
	for zone_data: HabitatZoneData in zones:
		if zone_data.zone_id != zone_id:
			continue
		if (
			not zone_data.available
			or zone_data.connected_zone_ids.size()
				!= expected_connection_ids.size()
		):
			return false
		for expected_connection_id: StringName in expected_connection_ids:
			if not zone_data.connected_zone_ids.has(
				expected_connection_id
			):
				return false
		return true
	return false


func _has_available_path(
	start_zone_id: StringName,
	target_zone_id: StringName
) -> bool:
	var zones_by_id: Dictionary[StringName, HabitatZoneData] = {}
	for zone_data: HabitatZoneData in zones:
		zones_by_id[zone_data.zone_id] = zone_data
	var start_zone: HabitatZoneData = zones_by_id.get(start_zone_id)
	var target_zone: HabitatZoneData = zones_by_id.get(target_zone_id)
	if (
		start_zone == null
		or target_zone == null
		or not start_zone.available
		or not target_zone.available
	):
		return false

	var pending_zone_ids: Array[StringName] = [start_zone_id]
	var visited_zone_ids: Dictionary[StringName, bool] = {
		start_zone_id: true,
	}
	var pending_index: int = 0
	while pending_index < pending_zone_ids.size():
		var zone_id: StringName = pending_zone_ids[pending_index]
		pending_index += 1
		if zone_id == target_zone_id:
			return true
		var zone_data: HabitatZoneData = zones_by_id.get(zone_id)
		if zone_data == null or not zone_data.available:
			continue
		for connected_zone_id: StringName in zone_data.connected_zone_ids:
			if visited_zone_ids.has(connected_zone_id):
				continue
			var connected_zone: HabitatZoneData = zones_by_id.get(
				connected_zone_id
			)
			if connected_zone == null or not connected_zone.available:
				continue
			visited_zone_ids[connected_zone_id] = true
			pending_zone_ids.append(connected_zone_id)
	return false
