class_name Act1WorldOverlay
extends Control

const SUGAR_COLOR: Color = Color(0.95, 0.72, 0.28, 0.96)
const SUGAR_GLOW: Color = Color(1.0, 0.86, 0.48, 0.30)
const CARE_GLOW: Color = Color(0.91, 0.78, 0.48, 0.22)
const WASTE_COLOR: Color = Color(0.48, 0.30, 0.14, 0.96)
const WASTE_GLOW: Color = Color(0.70, 0.48, 0.22, 0.26)
const SCOUT_GLOW: Color = Color(0.42, 0.76, 0.67, 0.30)
const MIGRATION_GLOW: Color = Color(0.93, 0.66, 0.30, 0.28)
const POLLUTION_COLOR: Color = Color(0.48, 0.34, 0.18, 0.66)

var _snapshot: GameSnapshot
var _layout_view: FacilityLayoutView
var _entity_positions: Dictionary[int, Vector2] = {}
var _queen_position: Vector2 = Vector2.ZERO


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	queue_redraw()


func configure(layout_view: FacilityLayoutView) -> bool:
	if layout_view == null:
		return false
	_layout_view = layout_view
	queue_redraw()
	return true


func apply_snapshot(snapshot: GameSnapshot) -> bool:
	if (
		snapshot == null
		or snapshot.colony == null
		or snapshot.act1 == null
	):
		return false
	_snapshot = snapshot
	queue_redraw()
	return true


func reset_projection() -> void:
	_snapshot = null
	_entity_positions.clear()
	_queen_position = Vector2.ZERO
	queue_redraw()


func set_display_positions(
	entity_positions: Dictionary[int, Vector2],
	queen_position: Vector2
) -> void:
	_entity_positions = entity_positions.duplicate()
	_queen_position = queen_position
	queue_redraw()


func _draw() -> void:
	if _snapshot == null or _layout_view == null:
		return
	_draw_pollution_clues()
	_draw_food_sources()
	_draw_worker_activity()
	if (
		_snapshot.act1.queen_care != null
		and _snapshot.act1.queen_care.care_state
			== Act1State.QueenCareState.BROOD_CARE
	):
		draw_circle(_queen_position, 46.0, CARE_GLOW)


func _draw_pollution_clues() -> void:
	for zone: HabitatZoneSnapshot in _snapshot.colony.zones:
		if (
			not zone.available
			or not zone.discovered
			or zone.pollution <= 0.015
		):
			continue
		var center: Vector2 = _layout_view.project_zone_position(
			zone.zone_id
		)
		var count: int = clampi(ceili(zone.pollution * 18.0), 1, 14)
		for index: int in count:
			var offset: Vector2 = Vector2(
				float(
					posmod(
						index * 17 + String(zone.zone_id).length(),
						37
					)
				) - 18.0,
				float(posmod(index * 11 + 5, 23)) - 11.0
			)
			draw_circle(
				center + offset,
				2.0 + float(posmod(index, 2)),
				POLLUTION_COLOR
			)


func _draw_food_sources() -> void:
	for source: FoodSourceSnapshot in _snapshot.colony.food_sources:
		if source.remaining_portions <= 0:
			continue
		var food_position: Vector2 = (
			_layout_view.project_zone_position(
				source.zone_id,
				source.food_source_id
			) + Vector2(10.0, 14.0)
		)
		draw_circle(food_position, 16.0, SUGAR_GLOW)
		draw_circle(food_position, 7.0, SUGAR_COLOR)


func _draw_worker_activity() -> void:
	for ant: AntSnapshot in _snapshot.colony.ants:
		if ant.life_stage != AntModel.LifeStage.WORKER:
			continue
		var worker_position: Vector2 = _entity_positions.get(
			ant.entity_id,
			_layout_view.project_zone_position(
				ant.zone_id,
				ant.entity_id
			)
		)
		if (
			ant.foraging_task != null
			and ant.foraging_task.carried_portions > 0
		):
			_draw_carried_cue(
				worker_position + Vector2(7.0, -13.0),
				SUGAR_GLOW,
				SUGAR_COLOR
			)
		if (
			ant.feeding_task != null
			and ant.feeding_task.state
				!= BroodFeedingTaskModel.State.IDLE
		):
			draw_arc(
				worker_position,
				18.0,
				0.0,
				TAU,
				24,
				CARE_GLOW,
				3.0,
				true
			)
		if (
			ant.waste_cleanup_task != null
			and ant.waste_cleanup_task.carried_amount > 0.0
		):
			_draw_carried_cue(
				worker_position + Vector2(8.0, -13.0),
				WASTE_GLOW,
				WASTE_COLOR
			)
		if (
			ant.scout_task != null
			and ant.scout_task.state
				== ScoutTaskModel.State.OBSERVING
		):
			_draw_activity_ring(worker_position, 27.0, SCOUT_GLOW)
		if (
			ant.migration_task != null
			and ant.migration_task.state
				!= MigrationTaskModel.State.IDLE
		):
			_draw_activity_ring(worker_position, 25.0, MIGRATION_GLOW)
			if ant.migration_task.carried_entity_id >= 0:
				var carried_position: Vector2 = (
					_queen_position
					if ant.migration_task.carried_entity_id
						== _snapshot.colony.queen_entity_id
					else _entity_positions.get(
						ant.migration_task.carried_entity_id,
						worker_position
					)
				)
				draw_line(
					worker_position,
					carried_position,
					Color(0.95, 0.72, 0.38, 0.72),
					2.0,
					true
				)


func _draw_carried_cue(
	position: Vector2,
	glow: Color,
	fill: Color
) -> void:
	draw_circle(position, 9.0, glow)
	draw_circle(position, 4.5, fill)


func _draw_activity_ring(
	position: Vector2,
	radius: float,
	color: Color
) -> void:
	draw_circle(position, radius, color)
	draw_arc(
		position,
		maxf(1.0, radius - 5.0),
		0.0,
		TAU,
		24,
		color,
		3.0,
		true
	)
