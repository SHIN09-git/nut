class_name FacilityView
extends Control

const FACILITY_COLOR: Color = Color(0.18, 0.29, 0.25, 1.0)
const FACILITY_EDGE: Color = Color(0.58, 0.68, 0.52, 0.95)
const FIXED_FACILITY_COLOR: Color = Color(0.15, 0.21, 0.20, 1.0)
const SELECTED_COLOR: Color = Color(0.94, 0.72, 0.30, 1.0)
const TEXT_COLOR: Color = Color(0.82, 0.87, 0.79, 1.0)
const HUMIDITY_COLOR: Color = Color(0.20, 0.54, 0.72, 0.88)
const POLLUTION_COLOR: Color = Color(0.67, 0.47, 0.22, 0.9)
const SUGAR_COLOR: Color = Color(0.96, 0.73, 0.28, 0.95)
const PROTEIN_COLOR: Color = Color(0.78, 0.34, 0.24, 0.95)
const METAL_DARK: Color = Color(0.12, 0.13, 0.11, 1.0)
const METAL_MID: Color = Color(0.43, 0.40, 0.29, 1.0)
const METAL_LIGHT: Color = Color(0.74, 0.67, 0.43, 0.92)
const GLASS_DARK: Color = Color(0.055, 0.105, 0.105, 0.94)
const GLASS_LIGHT: Color = Color(0.58, 0.82, 0.76, 0.74)
const SUBSTRATE_COLOR: Color = Color(0.39, 0.27, 0.14, 0.96)
const FACILITY_SHADOW: Color = Color(0.0, 0.0, 0.0, 0.36)
const PRODUCTION_FACILITY_TYPES: Array[StringName] = [
	&"test_tube_nest",
	&"micro_feeding_port",
	&"small_foraging_box",
	&"connector_tube",
	&"connector_elbow",
	&"connector_gate",
	&"light_cover",
	&"hydration_module",
	&"sugar_station",
	&"protein_dish",
	&"waste_tray",
	&"dual_chamber_nest",
]

var _snapshot: FacilitySnapshot
var _camera_zoom: float = 1.0
var _selected: bool = false
var _editing_enabled: bool = false


static func supports_type(type_id: StringName) -> bool:
	return PRODUCTION_FACILITY_TYPES.has(type_id)


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func apply_snapshot(
	snapshot: FacilitySnapshot,
	projected_rect: Rect2,
	camera_zoom: float,
	selected: bool,
	editing_enabled: bool
) -> bool:
	if (
		snapshot == null
		or snapshot.facility_id < 0
		or not projected_rect.position.is_finite()
		or not projected_rect.size.is_finite()
		or projected_rect.size.x <= 0.0
		or projected_rect.size.y <= 0.0
		or not is_finite(camera_zoom)
		or camera_zoom <= 0.0
	):
		return false
	_snapshot = snapshot
	_camera_zoom = camera_zoom
	_selected = selected
	_editing_enabled = editing_enabled
	position = projected_rect.position
	size = projected_rect.size
	visible = snapshot.available
	z_index = int(snapshot.placement_layer)
	queue_redraw()
	return true


func get_facility_id() -> int:
	return _snapshot.facility_id if _snapshot != null else -1


func get_type_id() -> StringName:
	return _snapshot.type_id if _snapshot != null else &""


func is_selected() -> bool:
	return _selected


func _draw() -> void:
	if _snapshot == null or not _snapshot.available:
		return
	var rect: Rect2 = Rect2(Vector2.ZERO, size)
	var is_overlay: bool = (
		_snapshot.placement_layer == FacilityData.PlacementLayer.OVERLAY
	)
	var inset: float = (10.0 if is_overlay else 4.0) * _camera_zoom
	rect = rect.grow(-inset)
	if rect.size.x <= 0.0 or rect.size.y <= 0.0:
		return
	draw_rect(
		Rect2(
			rect.position + Vector2(3.0, 4.0) * _camera_zoom,
			rect.size
		),
		FACILITY_SHADOW,
		true
	)
	var fill: Color = (
		FACILITY_COLOR
		if _snapshot.player_removable
		else FIXED_FACILITY_COLOR
	)
	if is_overlay:
		fill.a = 0.72
	if _snapshot.effect_kind == FacilityEffectConfig.Kind.HABITAT_ZONE:
		fill = _environment_fill_color(
			fill,
			_snapshot.zone_humidity,
			_snapshot.zone_light_exposure,
			_snapshot.zone_pollution
		)
	if (
		_snapshot.effect_kind
		== FacilityEffectConfig.Kind.DUAL_CHAMBER_ZONE
	):
		_draw_dual_chamber_fill(rect, fill)
	else:
		draw_rect(rect, fill, true)
	draw_rect(
		rect,
		SELECTED_COLOR if _selected else FACILITY_EDGE,
		false,
		3.0 if _selected else 2.0
	)
	draw_line(
		rect.position + Vector2(3.0, 3.0) * _camera_zoom,
		Vector2(
			rect.end.x - 3.0 * _camera_zoom,
			rect.position.y + 3.0 * _camera_zoom
		),
		Color(0.82, 0.90, 0.77, 0.18),
		maxf(1.0, _camera_zoom),
		true
	)
	_draw_type_body(rect)
	if (
		_editing_enabled
		and _snapshot.placement_layer
			!= FacilityData.PlacementLayer.OVERLAY
	):
		_draw_label(rect)


func _draw_type_body(rect: Rect2) -> void:
	var center: Vector2 = rect.get_center()
	match _snapshot.type_id:
		&"test_tube_nest":
			var tube_rect: Rect2 = Rect2(
				Vector2(
					rect.position.x + 8.0 * _camera_zoom,
					center.y - 9.0 * _camera_zoom
				),
				Vector2(
					rect.size.x - 16.0 * _camera_zoom,
					18.0 * _camera_zoom
				)
			)
			_draw_capsule(tube_rect, GLASS_DARK, GLASS_LIGHT)
			draw_circle(
				Vector2(
					tube_rect.position.x + tube_rect.size.y * 0.5,
					center.y
				),
				tube_rect.size.y * 0.34,
				HUMIDITY_COLOR
			)
			draw_circle(
				Vector2(
					tube_rect.end.x - tube_rect.size.y * 0.52,
					center.y
				),
				tube_rect.size.y * 0.31,
				Color(0.84, 0.82, 0.69, 0.96)
			)
		&"micro_feeding_port":
			draw_circle(
				center + Vector2(1.5, 2.0) * _camera_zoom,
				13.0 * _camera_zoom,
				FACILITY_SHADOW
			)
			draw_circle(center, 13.0 * _camera_zoom, METAL_MID)
			draw_circle(center, 9.0 * _camera_zoom, METAL_DARK)
			draw_circle(center, 5.0 * _camera_zoom, SUGAR_COLOR)
			draw_arc(
				center,
				10.5 * _camera_zoom,
				PI,
				PI * 1.75,
				12,
				METAL_LIGHT,
				1.5 * _camera_zoom,
				true
			)
		&"small_foraging_box":
			var tray: Rect2 = rect.grow(-9.0 * _camera_zoom)
			draw_rect(tray, METAL_DARK, true)
			draw_rect(tray.grow(-3.0 * _camera_zoom), SUBSTRATE_COLOR, true)
			draw_rect(tray, METAL_LIGHT, false, 2.0 * _camera_zoom)
			for index: int in 4:
				var pebble: Vector2 = tray.get_center() + Vector2(
					float(posmod(index * 17, 31) - 15),
					float(posmod(index * 11, 19) - 9)
				) * _camera_zoom
				draw_circle(
					pebble,
					2.2 * _camera_zoom,
					Color(0.65, 0.53, 0.33, 0.9)
				)
		&"dual_chamber_nest":
			_draw_dual_chamber_body(rect, center)
		&"connector_tube":
			_draw_connector_tube(rect, center)
		&"connector_gate":
			_draw_gate_icon(rect, center)
		&"connector_elbow":
			var elbow: PackedVector2Array = PackedVector2Array([
				Vector2(
					rect.position.x + 8.0 * _camera_zoom,
					center.y
				),
				center,
				Vector2(
					center.x,
					rect.position.y + 8.0 * _camera_zoom
				),
			])
			draw_polyline(
				elbow,
				METAL_DARK,
				10.0 * _camera_zoom,
				true
			)
			draw_polyline(
				elbow,
				GLASS_LIGHT,
				5.0 * _camera_zoom,
				true
			)
			draw_circle(center, 5.0 * _camera_zoom, METAL_LIGHT)
		&"light_cover":
			var cover: Rect2 = rect.grow(-7.0 * _camera_zoom)
			draw_rect(cover, Color(0.13, 0.085, 0.052, 0.98), true)
			draw_rect(cover, METAL_LIGHT, false, 2.0 * _camera_zoom)
			for index: int in 3:
				var rib_x: float = lerpf(
					cover.position.x,
					cover.end.x,
					float(index + 1) / 4.0
				)
				draw_line(
					Vector2(
						rib_x,
						cover.position.y + 4.0 * _camera_zoom
					),
					Vector2(
						rib_x,
						cover.end.y - 4.0 * _camera_zoom
					),
					Color(0.56, 0.39, 0.20, 0.8),
					2.0 * _camera_zoom
				)
		&"hydration_module":
			_draw_hydration_icon(center)
		&"sugar_station":
			_draw_dish_icon(center, SUGAR_COLOR, true)
		&"protein_dish":
			_draw_dish_icon(center, PROTEIN_COLOR, false)
		&"waste_tray":
			_draw_waste_tray(rect)
		_:
			draw_line(
				Vector2(rect.position.x + 8.0, center.y),
				Vector2(rect.end.x - 8.0, center.y),
				FACILITY_EDGE,
				5.0
			)


func _draw_dual_chamber_body(rect: Rect2, center: Vector2) -> void:
	if posmod(_snapshot.orientation, 2) == 0:
		draw_line(
			Vector2(center.x, rect.position.y),
			Vector2(center.x, rect.end.y),
			FACILITY_EDGE,
			3.0
		)
	else:
		draw_line(
			Vector2(rect.position.x, center.y),
			Vector2(rect.end.x, center.y),
			FACILITY_EDGE,
			3.0
		)
	var chamber_axis: Vector2 = (
		Vector2(rect.size.x * 0.23, 0.0)
		if posmod(_snapshot.orientation, 2) == 0
		else Vector2(0.0, rect.size.y * 0.23)
	)
	for chamber_center: Vector2 in [
		center - chamber_axis,
		center + chamber_axis,
	]:
		draw_circle(
			chamber_center,
			minf(rect.size.x, rect.size.y) * 0.18,
			Color(0.06, 0.10, 0.085, 0.72)
		)
		draw_arc(
			chamber_center,
			minf(rect.size.x, rect.size.y) * 0.18,
			0.0,
			TAU,
			24,
			GLASS_LIGHT,
			1.5 * _camera_zoom,
			true
		)


func _draw_connector_tube(rect: Rect2, center: Vector2) -> void:
	var horizontal: bool = rect.size.x >= rect.size.y
	var tube_start: Vector2 = (
		Vector2(
			rect.position.x + 6.0 * _camera_zoom,
			center.y
		)
		if horizontal
		else Vector2(
			center.x,
			rect.position.y + 6.0 * _camera_zoom
		)
	)
	var tube_end: Vector2 = (
		Vector2(
			rect.end.x - 6.0 * _camera_zoom,
			center.y
		)
		if horizontal
		else Vector2(
			center.x,
			rect.end.y - 6.0 * _camera_zoom
		)
	)
	draw_line(
		tube_start,
		tube_end,
		METAL_DARK,
		11.0 * _camera_zoom,
		true
	)
	draw_line(
		tube_start,
		tube_end,
		GLASS_LIGHT,
		5.0 * _camera_zoom,
		true
	)
	for collar: Vector2 in [tube_start, tube_end]:
		draw_circle(collar, 5.0 * _camera_zoom, METAL_MID)
		draw_circle(collar, 2.5 * _camera_zoom, GLASS_DARK)


func _draw_waste_tray(rect: Rect2) -> void:
	var tray: Rect2 = rect.grow(-11.0 * _camera_zoom)
	draw_rect(tray, METAL_DARK, true)
	draw_rect(tray, METAL_LIGHT, false, 2.5 * _camera_zoom)
	var fill_height: float = tray.size.y * _snapshot.waste_fill_ratio
	draw_rect(
		Rect2(
			Vector2(tray.position.x, tray.end.y - fill_height),
			Vector2(tray.size.x, fill_height)
		),
		POLLUTION_COLOR,
		true
	)
	for index: int in 3:
		draw_circle(
			tray.position + Vector2(
				tray.size.x * (float(index + 1) / 4.0),
				tray.size.y * 0.35
			),
			2.2 * _camera_zoom,
			Color(0.82, 0.65, 0.34, 0.9)
		)


func _draw_capsule(rect: Rect2, fill: Color, edge: Color) -> void:
	var radius: float = rect.size.y * 0.5
	draw_rect(
		Rect2(
			rect.position + Vector2(radius, 0.0),
			Vector2(
				maxf(0.0, rect.size.x - radius * 2.0),
				rect.size.y
			)
		),
		fill,
		true
	)
	draw_circle(
		rect.position + Vector2(radius, radius),
		radius,
		fill
	)
	draw_circle(rect.end - Vector2(radius, radius), radius, fill)
	draw_line(
		rect.position + Vector2(radius, 1.5 * _camera_zoom),
		rect.end - Vector2(radius, -1.5 * _camera_zoom),
		edge,
		1.5 * _camera_zoom,
		true
	)


func _draw_gate_icon(rect: Rect2, center: Vector2) -> void:
	var vertical: bool = rect.size.y >= rect.size.x
	var start: Vector2 = (
		Vector2(
			center.x,
			rect.position.y + 7.0 * _camera_zoom
		)
		if vertical
		else Vector2(
			rect.position.x + 7.0 * _camera_zoom,
			center.y
		)
	)
	var end: Vector2 = (
		Vector2(
			center.x,
			rect.end.y - 7.0 * _camera_zoom
		)
		if vertical
		else Vector2(
			rect.end.x - 7.0 * _camera_zoom,
			center.y
		)
	)
	draw_line(
		start,
		end,
		METAL_DARK,
		11.0 * _camera_zoom,
		true
	)
	draw_line(
		start,
		end,
		GLASS_LIGHT,
		5.0 * _camera_zoom,
		true
	)
	var gate_axis: Vector2 = (
		Vector2(8.0, 0.0)
		if vertical else Vector2(0.0, 8.0)
	) * _camera_zoom
	draw_line(
		center - gate_axis,
		center + gate_axis,
		SELECTED_COLOR,
		3.0 * _camera_zoom,
		true
	)
	draw_circle(center, 4.0 * _camera_zoom, METAL_LIGHT)


func _draw_hydration_icon(center: Vector2) -> void:
	var drop: PackedVector2Array = PackedVector2Array([
		center + Vector2(0.0, -15.0) * _camera_zoom,
		center + Vector2(10.0, 1.0) * _camera_zoom,
		center + Vector2(7.0, 10.0) * _camera_zoom,
		center + Vector2(0.0, 14.0) * _camera_zoom,
		center + Vector2(-7.0, 10.0) * _camera_zoom,
		center + Vector2(-10.0, 1.0) * _camera_zoom,
	])
	draw_colored_polygon(drop, GLASS_DARK)
	draw_polyline(drop, GLASS_LIGHT, 2.0 * _camera_zoom, true)
	draw_line(
		center + Vector2(-3.0, -4.0) * _camera_zoom,
		center + Vector2(-5.0, 5.0) * _camera_zoom,
		Color(0.78, 0.96, 1.0, 0.86),
		2.0 * _camera_zoom,
		true
	)


func _draw_dish_icon(
	center: Vector2,
	contents: Color,
	is_liquid: bool
) -> void:
	draw_circle(
		center + Vector2(1.0, 2.0) * _camera_zoom,
		14.0 * _camera_zoom,
		FACILITY_SHADOW
	)
	draw_circle(center, 14.0 * _camera_zoom, METAL_MID)
	draw_circle(center, 10.0 * _camera_zoom, METAL_DARK)
	if is_liquid:
		draw_circle(center, 7.0 * _camera_zoom, contents)
		draw_circle(
			center + Vector2(-2.5, -2.5) * _camera_zoom,
			2.0 * _camera_zoom,
			Color(1.0, 0.92, 0.62, 0.9)
		)
	else:
		for offset: Vector2 in [
			Vector2(-4.0, 2.0),
			Vector2(1.0, -3.0),
			Vector2(4.0, 4.0),
		]:
			draw_circle(
				center + offset * _camera_zoom,
				3.0 * _camera_zoom,
				contents
			)


func _draw_label(rect: Rect2) -> void:
	var font: Font = ThemeDB.fallback_font
	draw_string(
		font,
		Vector2(rect.position.x + 8.0, rect.end.y - 8.0),
		_facility_label(_snapshot.type_id),
		HORIZONTAL_ALIGNMENT_LEFT,
		maxf(20.0, rect.size.x - 16.0),
		clampi(int(12.0 * _camera_zoom), 10, 18),
		TEXT_COLOR
	)


func _draw_dual_chamber_fill(
	rect: Rect2,
	fallback: Color
) -> void:
	var brood_color: Color = _environment_fill_color(
		fallback,
		_snapshot.zone_humidity,
		_snapshot.zone_light_exposure,
		_snapshot.zone_pollution
	)
	var utility_color: Color = _environment_fill_color(
		fallback,
		_snapshot.secondary_zone_humidity,
		_snapshot.secondary_zone_light_exposure,
		_snapshot.secondary_zone_pollution
	)
	var first: Rect2
	var second: Rect2
	if posmod(_snapshot.orientation, 2) == 0:
		first = Rect2(
			rect.position,
			Vector2(rect.size.x * 0.5, rect.size.y)
		)
		second = Rect2(
			Vector2(
				rect.position.x + rect.size.x * 0.5,
				rect.position.y
			),
			Vector2(rect.size.x * 0.5, rect.size.y)
		)
	else:
		first = Rect2(
			rect.position,
			Vector2(rect.size.x, rect.size.y * 0.5)
		)
		second = Rect2(
			Vector2(
				rect.position.x,
				rect.position.y + rect.size.y * 0.5
			),
			Vector2(rect.size.x, rect.size.y * 0.5)
		)
	if _snapshot.orientation in [2, 3]:
		var swap: Rect2 = first
		first = second
		second = swap
	draw_rect(first, brood_color, true)
	draw_rect(second, utility_color, true)


func _environment_fill_color(
	base: Color,
	humidity: float,
	light_exposure: float,
	pollution: float
) -> Color:
	var result: Color = base.lerp(
		HUMIDITY_COLOR,
		clampf(humidity, 0.0, 1.0) * 0.28
	)
	result = result.lerp(
		POLLUTION_COLOR,
		clampf(pollution, 0.0, 1.0) * 0.42
	)
	return result.lightened(
		clampf(light_exposure, 0.0, 1.0) * 0.08
	)


func _facility_label(type_id: StringName) -> String:
	match type_id:
		&"test_tube_nest":
			return tr("FACILITY_TEST_TUBE_NEST")
		&"micro_feeding_port":
			return tr("FACILITY_MICRO_FEEDING_PORT")
		&"small_foraging_box":
			return tr("FACILITY_SMALL_FORAGING_BOX")
		&"connector_tube":
			return tr("R7_FACILITY_CONNECTOR_TUBE")
		&"connector_elbow":
			return tr("R10_FACILITY_ELBOW")
		&"connector_gate":
			return tr("R7_FACILITY_CONNECTOR_GATE")
		&"light_cover":
			return tr("FACILITY_LIGHT_COVER")
		&"hydration_module":
			return tr("R8_FACILITY_HYDRATION")
		&"sugar_station":
			return tr("R8_FACILITY_SUGAR_STATION")
		&"protein_dish":
			return tr("R8_FACILITY_PROTEIN_DISH")
		&"waste_tray":
			return tr("R8_FACILITY_WASTE_TRAY")
		&"dual_chamber_nest":
			return tr("R11_FACILITY_DUAL_CHAMBER")
	return tr("FACILITY_UNKNOWN")
