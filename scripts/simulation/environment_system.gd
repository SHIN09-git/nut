class_name EnvironmentSystem
extends RefCounted

var _config: EnvironmentConfig
var _catalog: FacilityCatalogConfig


func _init(
	config: EnvironmentConfig,
	catalog: FacilityCatalogConfig
) -> void:
	_config = config
	_catalog = catalog


func is_ready() -> bool:
	return _config != null and _catalog != null


func advance(state: ColonyState) -> void:
	if not is_ready() or state == null or state.layout_state == null:
		return

	for facility: FacilityState in (
		state.layout_state.get_facilities_in_stable_order()
	):
		if not facility.available:
			continue
		var type_config: FacilityConfig = _catalog.get_type(
			facility.type_id
		)
		if type_config == null or type_config.effect_config == null:
			continue
		var effect: FacilityEffectConfig = type_config.effect_config
		var zone: HabitatZoneState = state.get_zone(facility.zone_id)
		match effect.kind:
			FacilityEffectConfig.Kind.HABITAT_ZONE:
				if zone != null:
					zone.set_pollution(
						zone.pollution + effect.pollution_per_tick
					)
			FacilityEffectConfig.Kind.HYDRATION:
				if zone != null:
					zone.set_humidity(_approach(
						zone.humidity,
						effect.target_humidity,
						effect.humidity_per_tick
					))
			FacilityEffectConfig.Kind.WASTE_TRAY:
				if zone != null:
					var remaining_capacity: float = maxf(
						0.0,
						effect.waste_capacity - facility.waste_stored
					)
					var captured: float = minf(
						zone.pollution,
						minf(
							effect.waste_capture_per_tick,
							remaining_capacity
						)
					)
					zone.set_pollution(zone.pollution - captured)
					facility.waste_stored += captured
			FacilityEffectConfig.Kind.LIGHT_COVER:
				if zone != null:
					zone.set_light_exposure(_approach(
						zone.light_exposure,
						effect.target_light_exposure,
						effect.light_transition_per_tick
					))

	_diffuse_pollution(state)


func has_valid_state(state: ColonyState) -> bool:
	if not is_ready() or state == null or state.layout_state == null:
		return false
	for zone: HabitatZoneState in state.zones:
		if (
			zone == null
			or not is_finite(zone.humidity)
			or not is_finite(zone.light_exposure)
			or not is_finite(zone.pollution)
			or zone.humidity < 0.0
			or zone.humidity > 1.0
			or zone.light_exposure < 0.0
			or zone.light_exposure > 1.0
			or zone.pollution < 0.0
			or zone.pollution > 1.0
		):
			return false
	for facility: FacilityState in state.layout_state.facilities.values():
		if not is_finite(facility.waste_stored) or facility.waste_stored < 0.0:
			return false
		var type_config: FacilityConfig = _catalog.get_type(
			facility.type_id
		)
		if (
			type_config != null
			and type_config.effect_config.kind
				== FacilityEffectConfig.Kind.WASTE_TRAY
			and facility.waste_stored
				> type_config.effect_config.waste_capacity + 0.000001
		):
			return false
	return true


func get_brood_pollution_penalty(pollution: float) -> float:
	if not is_ready() or not is_finite(pollution):
		return INF
	return (
		maxf(0.0, pollution - _config.brood_pollution_comfort_max)
		* _config.brood_pollution_penalty_weight
	)


func is_queen_care_light_comfortable(light_exposure: float) -> bool:
	return (
		is_ready()
		and is_finite(light_exposure)
		and light_exposure <= _config.queen_care_light_max + 0.000001
	)


func _diffuse_pollution(state: ColonyState) -> void:
	if _config.pollution_diffusion_per_tick <= 0.0:
		return
	var deltas: Dictionary[StringName, float] = {}
	for connection: HabitatConnectionState in (
		state.layout_state.get_connections_in_stable_order()
	):
		if not connection.open:
			continue
		var first: HabitatZoneState = state.get_zone(
			connection.first_zone_id
		)
		var second: HabitatZoneState = state.get_zone(
			connection.second_zone_id
		)
		if (
			first == null
			or second == null
			or not first.available
			or not second.available
		):
			continue
		var transfer: float = (
			(first.pollution - second.pollution)
			* _config.pollution_diffusion_per_tick
		)
		deltas[first.zone_id] = deltas.get(first.zone_id, 0.0) - transfer
		deltas[second.zone_id] = deltas.get(second.zone_id, 0.0) + transfer
	var zone_ids: Array[StringName] = []
	zone_ids.assign(deltas.keys())
	zone_ids.sort_custom(
		func(first: StringName, second: StringName) -> bool:
			return String(first) < String(second)
	)
	for zone_id: StringName in zone_ids:
		var zone: HabitatZoneState = state.get_zone(zone_id)
		if zone != null:
			zone.set_pollution(zone.pollution + deltas[zone_id])


func _approach(current: float, target: float, amount: float) -> float:
	if current < target:
		return minf(target, current + amount)
	return maxf(target, current - amount)
