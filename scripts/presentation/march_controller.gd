class_name MarchController
extends RefCounted

const MARCH_SPEED: float = 180.0
const UNIT_RADIUS: float = 16.0
const SOLDIER_VISUAL_RADIUS: float = 16.0
const SOLDIER_VISUAL_SPACING: float = 42.0
const SOLDIER_VISUAL_LANE_OFFSET: float = 21.0
const MAX_VISUAL_SOLDIERS_PER_UNIT: int = 18
const MARCH_COLLISION_DISTANCE: float = 34.0

var _marching_units: Array = []
var _next_march_order: int = 0

var _battle_service = null
var _PrototypeCityOwnerRef = null


func setup(battle_service, city_owner_ref) -> void:
	_battle_service = battle_service
	_PrototypeCityOwnerRef = city_owner_ref


func launch_march(source_id: int, target_id: int, unit_owner: int, count: int, march_type: String, source_position: Vector2, target_position: Vector2) -> Dictionary:
	var travel_vector: Vector2 = target_position - source_position
	var travel_distance: float = max(0.001, travel_vector.length())
	var duration: float = max(0.45, travel_distance / MARCH_SPEED)
	var march_direction: Vector2 = travel_vector / travel_distance
	var visual_lane_offset: float = _get_visual_lane_offset_for_launch(_next_march_order)

	var unit = {
		"source_id": source_id,
		"target_id": target_id,
		"owner": unit_owner,
		"count": count,
		"type": march_type,
		"is_player_action": true,
		"launch_order": _next_march_order,
		"current_position": source_position,
		"march_direction": march_direction,
		"travel_distance": travel_distance,
		"traveled_distance": 0.0,
		"visual_lane_offset": visual_lane_offset,
		"progress": 0.0,
		"duration": duration
	}
	_marching_units.append(unit)
	_next_march_order += 1
	return unit


func update(delta: float, cities: Array) -> Array[Dictionary]:
	if _marching_units.is_empty():
		return []

	# Update positions
	for unit in _marching_units:
		var next_traveled_distance: float = min(
			float(unit["travel_distance"]),
			float(unit["traveled_distance"]) + MARCH_SPEED * delta
		)
		unit["traveled_distance"] = next_traveled_distance
		unit["progress"] = next_traveled_distance / float(unit["travel_distance"])
		unit["current_position"] = cities[int(unit["source_id"])].position + Vector2(unit["march_direction"]) * next_traveled_distance

	# Resolve collisions
	_resolve_marching_collisions(cities)

	# Find arrived units
	var arrived_units: Array = []
	for unit in _marching_units:
		if float(unit["traveled_distance"]) >= float(unit["travel_distance"]) - 0.001:
			arrived_units.append(unit)

	arrived_units.sort_custom(_sort_arrived_units)

	# Remove arrived units from marching list
	for arrived_unit in arrived_units:
		_marching_units.erase(arrived_unit)

	return arrived_units


func get_marching_units() -> Array:
	return _marching_units


func clear() -> void:
	_marching_units.clear()
	_next_march_order = 0


func _resolve_marching_collisions(cities: Array) -> void:
	var collision_found: bool = true
	while collision_found:
		collision_found = false
		for left_index: int in range(_marching_units.size()):
			for right_index: int in range(left_index + 1, _marching_units.size()):
				var left_unit: Dictionary = _marching_units[left_index]
				var right_unit: Dictionary = _marching_units[right_index]
				if int(left_unit["owner"]) == int(right_unit["owner"]):
					continue
				if _get_unit_position(left_unit).distance_to(_get_unit_position(right_unit)) > MARCH_COLLISION_DISTANCE:
					continue
				_resolve_single_collision(left_index, right_index, cities)
				collision_found = true
				break
			if collision_found:
				break


func _resolve_single_collision(left_index: int, right_index: int, cities: Array) -> void:
	var left_unit: Dictionary = _marching_units[left_index]
	var right_unit: Dictionary = _marching_units[right_index]

	if _battle_service == null:
		return

	var result: Dictionary = _battle_service.resolve_marching_encounter(
		int(left_unit["owner"]),
		int(left_unit["count"]),
		int(right_unit["owner"]),
		int(right_unit["count"])
	)

	if result.get("both_destroyed", false):
		_marching_units.remove_at(right_index)
		_marching_units.remove_at(left_index)
		return

	var winner_owner: int = int(result["winner_owner"])
	var remaining_count: int = int(result["remaining_count"])
	var surviving_unit: Dictionary = left_unit if int(left_unit["owner"]) == winner_owner else right_unit
	var surviving_index: int = left_index if int(left_unit["owner"]) == winner_owner else right_index
	surviving_unit["count"] = remaining_count
	_marching_units[surviving_index] = surviving_unit
	_marching_units.remove_at(right_index if surviving_index == left_index else left_index)


func _sort_arrived_units(left: Dictionary, right: Dictionary) -> bool:
	var left_attack: bool = left["type"] == "attack"
	var right_attack: bool = right["type"] == "attack"
	if left_attack != right_attack:
		return left_attack and not right_attack
	return int(left["launch_order"]) < int(right["launch_order"])


func _get_unit_position(unit: Dictionary) -> Vector2:
	if unit.has("current_position"):
		return Vector2(unit["current_position"])
	return Vector2.ZERO


func _get_visual_lane_offset_for_launch(launch_order: int) -> float:
	var lane_pattern: Array[float] = [0.0, 1.0, -1.0, 2.0, -2.0]
	var lane_index: int = posmod(launch_order, lane_pattern.size())
	return float(lane_pattern[lane_index]) * SOLDIER_VISUAL_LANE_OFFSET


func draw_arrows(canvas: Node2D, camera, cities: Array, order_dispatch_service) -> void:
	if order_dispatch_service == null:
		return
	var orders: Array[Dictionary] = order_dispatch_service.get_all_orders()
	if orders.is_empty():
		return

	var time_based_offset: float = float(Time.get_ticks_msec() % 5000) / 5000.0

	for order in orders:
		var source_id: int = int(order["source_id"])
		var target_id: int = int(order["target_id"])
		if source_id < 0 or source_id >= cities.size() or target_id < 0 or target_id >= cities.size():
			continue

		var source = cities[source_id]
		var target = cities[target_id]
		var from_position: Vector2 = camera.world_to_screen(source.position)
		var to_position: Vector2 = camera.world_to_screen(target.position)
		var direction: Vector2 = (to_position - from_position).normalized()
		var distance: float = from_position.distance_to(to_position)

		var arrow_spacing: float = 80.0 * camera.map_zoom
		var arrow_count: int = max(1, int(distance / arrow_spacing))
		var owner_color: Color = _PrototypeCityOwnerRef.get_color(source.owner) if _PrototypeCityOwnerRef else Color.WHITE
		var arrow_size: float = max(6.0, 10.0 * camera.map_zoom)

		for i in range(arrow_count):
			var t: float = (float(i) / arrow_count + time_based_offset)
			if t > 1.0:
				t -= 1.0

			var arrow_center: Vector2 = from_position + direction * distance * t
			_draw_arrow(canvas, arrow_center, direction, arrow_size, owner_color)


func _draw_arrow(canvas: Node2D, center: Vector2, direction: Vector2, size: float, color: Color) -> void:
	var perpendicular: Vector2 = Vector2(-direction.y, direction.x)
	var points: PackedVector2Array = PackedVector2Array([
		center + direction * size,
		center - direction * size * 0.5 + perpendicular * size * 0.5,
		center - direction * size * 0.5 - perpendicular * size * 0.5
	])
	canvas.draw_colored_polygon(points, color)


func draw_marching_units(canvas: Node2D, camera) -> void:
	for unit in _marching_units:
		_draw_unit_as_soldiers(canvas, unit, camera)


func _draw_unit_as_soldiers(canvas: Node2D, unit: Dictionary, camera) -> void:
	var march_direction: Vector2 = Vector2(unit.get("march_direction", Vector2.RIGHT))
	if march_direction.length_squared() <= 0.0001:
		march_direction = Vector2.RIGHT
	var lane_direction: Vector2 = Vector2(-march_direction.y, march_direction.x)
	var soldier_radius: float = max(5.0, SOLDIER_VISUAL_RADIUS * camera.map_zoom)
	var soldier_spacing: float = max(10.0, SOLDIER_VISUAL_SPACING * camera.map_zoom)
	var visible_count: int = min(int(unit["count"]), MAX_VISUAL_SOLDIERS_PER_UNIT)
	var lane_offset: float = float(unit.get("visual_lane_offset", 0.0)) * camera.map_zoom
	var front_position: Vector2 = camera.world_to_screen(_get_unit_position(unit)) + lane_direction * lane_offset
	var unit_color: Color = _PrototypeCityOwnerRef.get_color(int(unit["owner"])) if _PrototypeCityOwnerRef else Color.WHITE
	var outline_width: float = max(1.0, 2.0 * camera.map_zoom)

	for soldier_index: int in range(visible_count):
		var soldier_position: Vector2 = front_position - march_direction * soldier_spacing * float(soldier_index)
		canvas.draw_circle(soldier_position, soldier_radius, unit_color)
		canvas.draw_circle(soldier_position, soldier_radius, Color.WHITE, false, outline_width)
