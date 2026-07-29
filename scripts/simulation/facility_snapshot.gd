class_name FacilitySnapshot
extends RefCounted

var facility_id: int
var type_id: StringName
var slot: Vector2i
var orientation: int
var footprint: Vector2i
var placement_layer: FacilityData.PlacementLayer
var zone_id: StringName
var secondary_zone_id: StringName
var available: bool
var player_removable: bool
var effect_kind: int
var zone_humidity: float
var zone_light_exposure: float
var zone_pollution: float
var secondary_zone_humidity: float
var secondary_zone_light_exposure: float
var secondary_zone_pollution: float
var waste_fill_ratio: float


func _init(
	new_facility_id: int,
	new_type_id: StringName,
	new_slot: Vector2i,
	new_orientation: int,
	new_footprint: Vector2i,
	new_placement_layer: FacilityData.PlacementLayer,
	new_zone_id: StringName,
	new_available: bool,
	new_player_removable: bool,
	new_effect_kind: int = -1,
	new_zone_humidity: float = 0.0,
	new_zone_light_exposure: float = 0.0,
	new_zone_pollution: float = 0.0,
	new_waste_fill_ratio: float = 0.0,
	new_secondary_zone_id: StringName = &"",
	new_secondary_zone_humidity: float = 0.0,
	new_secondary_zone_light_exposure: float = 0.0,
	new_secondary_zone_pollution: float = 0.0
) -> void:
	facility_id = new_facility_id
	type_id = new_type_id
	slot = new_slot
	orientation = new_orientation
	footprint = new_footprint
	placement_layer = new_placement_layer
	zone_id = new_zone_id
	secondary_zone_id = new_secondary_zone_id
	available = new_available
	player_removable = new_player_removable
	effect_kind = new_effect_kind
	zone_humidity = new_zone_humidity
	zone_light_exposure = new_zone_light_exposure
	zone_pollution = new_zone_pollution
	secondary_zone_humidity = new_secondary_zone_humidity
	secondary_zone_light_exposure = new_secondary_zone_light_exposure
	secondary_zone_pollution = new_secondary_zone_pollution
	waste_fill_ratio = new_waste_fill_ratio
