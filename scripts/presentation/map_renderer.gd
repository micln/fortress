class_name MapRenderer
extends Node

var _background_renderer = null


func setup(background_renderer) -> void:
	_background_renderer = background_renderer


func draw_background(canvas: Node2D, world_size: Vector2, map_offset: Vector2, map_zoom: float) -> void:
	if _background_renderer != null:
		_background_renderer.draw_background(
			canvas,
			world_size,
			map_offset,
			map_zoom,
			func(world_pos): return _world_to_screen_default(world_pos, map_offset, map_zoom)
		)


func _world_to_screen_default(world_pos: Vector2, map_offset: Vector2, map_zoom: float) -> Vector2:
	return world_pos * map_zoom + map_offset


func draw_roads(canvas: Node2D, camera, cities: Array, selected_city_id: int) -> void:
	for city in cities:
		for neighbor_id: int in city.neighbors:
			if neighbor_id < city.city_id:
				continue

			var target = cities[neighbor_id]
			var from_position: Vector2 = camera.world_to_screen(city.position)
			var target_position: Vector2 = camera.world_to_screen(target.position)
			var line_color := Color("48576a")
			var line_width: float = max(3.0, 6.0 * camera.map_zoom)
			if city.city_id == selected_city_id or target.city_id == selected_city_id:
				line_color = Color("f6d365")
				line_width = max(5.0, 10.0 * camera.map_zoom)

			canvas.draw_line(from_position, target_position, line_color, line_width, true)


func world_to_screen(world_pos: Vector2, camera) -> Vector2:
	return camera.world_to_screen(world_pos)
