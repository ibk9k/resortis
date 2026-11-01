class_name IsometricGrid
extends RefCounted
## One logical grid shared by rendering, footprints, picking, and navigation.

const TILE := Vector2(64.0, 32.0)
const HALF := TILE * 0.5

static func project(cell: Vector2) -> Vector2:
	return Vector2((cell.x - cell.y) * HALF.x, (cell.x + cell.y) * HALF.y)

static func unproject(point: Vector2) -> Vector2:
	return Vector2(point.x / TILE.x + point.y / TILE.y, point.y / TILE.y - point.x / TILE.x)

static func cell_at(point: Vector2) -> Vector2i:
	return Vector2i((unproject(point) + Vector2(0.5, 0.5)).floor())

static func footprint_polygon(origin: Vector2, size: Vector2i) -> PackedVector2Array:
	var corner := origin - Vector2(0.5, 0.5)
	return PackedVector2Array([
		project(corner), project(corner + Vector2(size.x, 0)),
		project(corner + Vector2(size)), project(corner + Vector2(0, size.y))
	])

static func front_anchor(origin: Vector2, size: Vector2i) -> Vector2:
	return project(origin + Vector2(size) - Vector2(0.5, 0.5))
