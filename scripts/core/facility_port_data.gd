class_name FacilityPortData
extends Resource

enum Direction {
	NORTH,
	EAST,
	SOUTH,
	WEST,
}

@export var local_cell: Vector2i = Vector2i.ZERO
@export_enum("North", "East", "South", "West") var direction: int = (
	Direction.EAST
)
@export var connection_kind: StringName = &"habitat"


func is_valid_for_footprint(footprint: Vector2i) -> bool:
	return (
		local_cell.x >= 0
		and local_cell.y >= 0
		and local_cell.x < footprint.x
		and local_cell.y < footprint.y
		and direction >= Direction.NORTH
		and direction <= Direction.WEST
		and not connection_kind.is_empty()
	)
