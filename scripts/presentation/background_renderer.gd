class_name BackgroundRenderer
extends RefCounted

## 战场背景绘制器
##
## 职责：绘制四层战场背景（草地底层、土地色块、草纹、氛围块）
## 调用场景：主场景 _draw() 中，在道路/城市/行军之前绘制


## 绘制完整的战场背景多层结构。
##
## 调用场景：主场景每次重绘时。
## 主要逻辑：按顺序绘制水域、草地底层、土地色块、森林、山区、草纹、氛围块。
func draw_background(
	canvas: Node2D,
	map_world_size: Vector2,
	map_offset: Vector2,
	map_zoom: float,
	world_to_screen: Callable
) -> void:
	var world_rect: Rect2 = Rect2(Vector2.ZERO, map_world_size)
	var screen_rect: Rect2 = Rect2(map_offset, map_world_size * map_zoom)
	_draw_battlefield_water(canvas, world_rect, map_zoom, world_to_screen)
	_draw_battlefield_grass_base(canvas, screen_rect)
	_draw_battlefield_earth_patches(canvas, world_rect, map_zoom, world_to_screen)
	_draw_battlefield_forests(canvas, world_rect, map_zoom, world_to_screen)
	_draw_battlefield_mountains(canvas, world_rect, map_zoom, world_to_screen)
	_draw_battlefield_grass_stripes(canvas, world_rect, map_zoom, world_to_screen)
	_draw_battlefield_atmosphere_blocks(canvas, world_rect, map_zoom, world_to_screen)


## 绘制战场的水域和湖泊。
func _draw_battlefield_water(canvas: Node2D, world_rect: Rect2, map_zoom: float, world_to_screen: Callable) -> void:
	var lake_defs: Array[Dictionary] = [
		{"center_ratio": Vector2(0.12, 0.35), "radius": 120.0, "color": Color(0.25, 0.52, 0.76, 0.85)},
		{"center_ratio": Vector2(0.78, 0.15), "radius": 95.0, "color": Color(0.28, 0.55, 0.78, 0.82)},
		{"center_ratio": Vector2(0.88, 0.72), "radius": 140.0, "color": Color(0.24, 0.50, 0.74, 0.88)},
		{"center_ratio": Vector2(0.35, 0.82), "radius": 80.0, "color": Color(0.26, 0.53, 0.77, 0.80)}
	]
	for lake_def in lake_defs:
		var center_ratio: Vector2 = Vector2(lake_def["center_ratio"])
		var lake_center: Vector2 = world_rect.position + Vector2(world_rect.size.x * center_ratio.x, world_rect.size.y * center_ratio.y)
		var lake_radius: float = float(lake_def["radius"])
		var lake_color: Color = lake_def["color"]
		_draw_battlefield_lake(canvas, lake_center, lake_radius, lake_color, map_zoom, world_to_screen)


## 绘制单个湖泊的不规则形状。
func _draw_battlefield_lake(canvas: Node2D, world_center: Vector2, world_radius: float, color: Color, map_zoom: float, world_to_screen: Callable) -> void:
	var screen_center: Vector2 = world_to_screen.call(world_center)
	var screen_radius: float = world_radius * map_zoom
	# 绘制不规则的湖泊形状
	var points: PackedVector2Array = PackedVector2Array()
	for i in range(12):
		var angle: float = float(i) / 12.0 * TAU
		var radius_variation: float = 1.0 + sin(angle * 3.0) * 0.15 + cos(angle * 5.0) * 0.1
		var point: Vector2 = screen_center + Vector2(cos(angle), sin(angle)) * screen_radius * radius_variation
		points.append(point)
	canvas.draw_colored_polygon(points, color)
	# 添加水波纹效果（较浅色的椭圆）
	canvas.draw_circle(screen_center + Vector2(-screen_radius * 0.3, -screen_radius * 0.2), screen_radius * 0.4, color.lightened(0.15))


## 绘制战场的主草地底层，作为背景的最底色。
func _draw_battlefield_grass_base(canvas: Node2D, screen_rect: Rect2) -> void:
	canvas.draw_rect(screen_rect, Color(0.42, 0.58, 0.31))


## 绘制不规则的土地色块，用来打破单一草地底色。
func _draw_battlefield_earth_patches(canvas: Node2D, world_rect: Rect2, map_zoom: float, world_to_screen: Callable) -> void:
	var patch_defs: Array[Dictionary] = [
		{"center_ratio": Vector2(0.16, 0.18), "size_ratio": Vector2(0.18, 0.10), "skew": Vector2(0.11, 0.03), "color": Color(0.56, 0.45, 0.26, 0.18)},
		{"center_ratio": Vector2(0.44, 0.14), "size_ratio": Vector2(0.22, 0.11), "skew": Vector2(0.08, -0.02), "color": Color(0.58, 0.48, 0.30, 0.16)},
		{"center_ratio": Vector2(0.73, 0.27), "size_ratio": Vector2(0.19, 0.09), "skew": Vector2(-0.10, 0.03), "color": Color(0.54, 0.43, 0.25, 0.17)},
		{"center_ratio": Vector2(0.28, 0.56), "size_ratio": Vector2(0.24, 0.12), "skew": Vector2(0.06, 0.04), "color": Color(0.59, 0.49, 0.31, 0.15)},
		{"center_ratio": Vector2(0.68, 0.74), "size_ratio": Vector2(0.18, 0.10), "skew": Vector2(-0.08, -0.03), "color": Color(0.55, 0.44, 0.27, 0.18)}
	]
	for patch_def in patch_defs:
		var center_ratio: Vector2 = Vector2(patch_def["center_ratio"])
		var size_ratio: Vector2 = Vector2(patch_def["size_ratio"])
		var patch_center: Vector2 = world_rect.position + Vector2(world_rect.size.x * center_ratio.x, world_rect.size.y * center_ratio.y)
		var patch_size: Vector2 = Vector2(world_rect.size.x * size_ratio.x, world_rect.size.y * size_ratio.y)
		var patch_skew: Vector2 = Vector2(patch_def["skew"])
		var patch_color: Color = patch_def["color"]
		_draw_battlefield_patch_blob(canvas, patch_center, patch_size, patch_skew, patch_color, world_to_screen)


## 绘制森林区域。
func _draw_battlefield_forests(canvas: Node2D, world_rect: Rect2, map_zoom: float, world_to_screen: Callable) -> void:
	var forest_defs: Array[Dictionary] = [
		{"center_ratio": Vector2(0.22, 0.38), "radius": 100.0, "tree_count": 18, "color": Color(0.18, 0.42, 0.18, 0.75)},
		{"center_ratio": Vector2(0.65, 0.22), "radius": 85.0, "tree_count": 14, "color": Color(0.16, 0.40, 0.16, 0.72)},
		{"center_ratio": Vector2(0.82, 0.58), "radius": 110.0, "tree_count": 22, "color": Color(0.19, 0.43, 0.19, 0.78)},
		{"center_ratio": Vector2(0.15, 0.75), "radius": 70.0, "tree_count": 10, "color": Color(0.17, 0.41, 0.17, 0.70)},
		{"center_ratio": Vector2(0.48, 0.68), "radius": 90.0, "tree_count": 16, "color": Color(0.18, 0.42, 0.18, 0.74)}
	]
	for forest_def in forest_defs:
		var center_ratio: Vector2 = Vector2(forest_def["center_ratio"])
		var forest_center: Vector2 = world_rect.position + Vector2(world_rect.size.x * center_ratio.x, world_rect.size.y * center_ratio.y)
		var forest_radius: float = float(forest_def["radius"])
		var tree_count: int = int(forest_def["tree_count"])
		var forest_color: Color = forest_def["color"]
		_draw_battlefield_forest_cluster(canvas, forest_center, forest_radius, tree_count, forest_color, map_zoom, world_to_screen)


## 绘制单个森林簇。
func _draw_battlefield_forest_cluster(canvas: Node2D, world_center: Vector2, world_radius: float, tree_count: int, color: Color, map_zoom: float, world_to_screen: Callable) -> void:
	var screen_center: Vector2 = world_to_screen.call(world_center)
	var screen_radius: float = world_radius * map_zoom
	var tree_size: float = max(6.0, 32.0 * map_zoom)

	# 绘制树木（简单的三角形表示松树）
	for i in range(tree_count):
		var angle: float = float(i) / tree_count * TAU + (float(i) * 0.7)
		var distance: float = screen_radius * (0.3 + 0.7 * (float(i % 5) / 5.0))
		var tree_pos: Vector2 = screen_center + Vector2(cos(angle), sin(angle)) * distance
		_draw_simple_tree(canvas, tree_pos, tree_size, color)


## 绘制简单的树木形状（三角形）。
func _draw_simple_tree(canvas: Node2D, position: Vector2, size: float, color: Color) -> void:
	var points: PackedVector2Array = PackedVector2Array([
		position + Vector2(0, -size),
		position + Vector2(-size * 0.5, size * 0.3),
		position + Vector2(size * 0.5, size * 0.3)
	])
	canvas.draw_colored_polygon(points, color)
	# 树干
	canvas.draw_rect(Rect2(position.x - size * 0.12, position.y + size * 0.3, size * 0.24, size * 0.4), Color(0.35, 0.24, 0.15, 0.8))


## 绘制山区。
func _draw_battlefield_mountains(canvas: Node2D, world_rect: Rect2, map_zoom: float, world_to_screen: Callable) -> void:
	var mountain_defs: Array[Dictionary] = [
		{"center_ratio": Vector2(0.08, 0.15), "radius": 130.0, "peak_count": 5, "color": Color(0.45, 0.42, 0.38, 0.80)},
		{"center_ratio": Vector2(0.92, 0.28), "radius": 110.0, "peak_count": 4, "color": Color(0.43, 0.40, 0.36, 0.78)},
		{"center_ratio": Vector2(0.25, 0.88), "radius": 95.0, "peak_count": 3, "color": Color(0.46, 0.43, 0.39, 0.82)},
		{"center_ratio": Vector2(0.75, 0.85), "radius": 105.0, "peak_count": 4, "color": Color(0.44, 0.41, 0.37, 0.79)}
	]
	for mountain_def in mountain_defs:
		var center_ratio: Vector2 = Vector2(mountain_def["center_ratio"])
		var mountain_center: Vector2 = world_rect.position + Vector2(world_rect.size.x * center_ratio.x, world_rect.size.y * center_ratio.y)
		var mountain_radius: float = float(mountain_def["radius"])
		var peak_count: int = int(mountain_def["peak_count"])
		var mountain_color: Color = mountain_def["color"]
		_draw_battlefield_mountain_range(canvas, mountain_center, mountain_radius, peak_count, mountain_color, map_zoom, world_to_screen)


## 绘制单个山脉。
func _draw_battlefield_mountain_range(canvas: Node2D, world_center: Vector2, world_radius: float, peak_count: int, color: Color, map_zoom: float, world_to_screen: Callable) -> void:
	var screen_center: Vector2 = world_to_screen.call(world_center)
	var screen_radius: float = world_radius * map_zoom
	var peak_size: float = max(20.0, 50.0 * map_zoom)

	# 绘制山峰
	for i in range(peak_count):
		var angle: float = float(i) / peak_count * PI + (float(i) * 0.3)
		var distance: float = screen_radius * 0.4
		var peak_pos: Vector2 = screen_center + Vector2(cos(angle), sin(angle) * 0.6) * distance
		var peak_height: float = peak_size * (0.7 + 0.3 * (float(i % 3) / 3.0))
		_draw_mountain_peak(canvas, peak_pos, peak_height, color)


## 绘制单个山峰。
func _draw_mountain_peak(canvas: Node2D, position: Vector2, height: float, color: Color) -> void:
	var width: float = height * 1.2
	var points: PackedVector2Array = PackedVector2Array([
		position + Vector2(0, -height),
		position + Vector2(-width * 0.5, 0),
		position + Vector2(width * 0.5, 0)
	])
	canvas.draw_colored_polygon(points, color)
	# 山顶积雪
	var snow_points: PackedVector2Array = PackedVector2Array([
		position + Vector2(0, -height),
		position + Vector2(-width * 0.15, -height * 0.5),
		position + Vector2(width * 0.15, -height * 0.5)
	])
	canvas.draw_colored_polygon(snow_points, Color(0.95, 0.95, 0.95, 0.7))


## 绘制单个土地色块的软边多边形。
func _draw_battlefield_patch_blob(canvas: Node2D, world_center: Vector2, world_size: Vector2, skew: Vector2, color: Color, world_to_screen: Callable) -> void:
	var half_size: Vector2 = world_size * 0.5
	var world_points := PackedVector2Array([
		world_center + Vector2(-half_size.x * 1.05, -half_size.y * 0.20),
		world_center + Vector2(-half_size.x * 0.30, -half_size.y * 0.82) + skew * 0.15,
		world_center + Vector2(half_size.x * 0.58, -half_size.y * 0.52) + skew,
		world_center + Vector2(half_size.x * 0.86, half_size.y * 0.14) + skew * 0.55,
		world_center + Vector2(half_size.x * 0.20, half_size.y * 0.84) - skew * 0.05,
		world_center + Vector2(-half_size.x * 0.42, half_size.y * 0.62) - skew * 0.28
	])
	var screen_points := PackedVector2Array()
	for point: Vector2 in world_points:
		screen_points.append(world_to_screen.call(point))
	canvas.draw_colored_polygon(screen_points, color)


## 绘制更自然的分段草纹。
func _draw_battlefield_grass_stripes(canvas: Node2D, world_rect: Rect2, map_zoom: float, world_to_screen: Callable) -> void:
	var stripe_defs: Array[Dictionary] = [
		{"y_ratio": 0.12, "amplitude": 18.0, "phase": 0.0, "segment_length": 88.0, "gap_length": 54.0, "thickness": 12.0, "offset": -60.0, "color": Color(0.54, 0.67, 0.37, 0.18)},
		{"y_ratio": 0.28, "amplitude": 14.0, "phase": 96.0, "segment_length": 76.0, "gap_length": 48.0, "thickness": 10.0, "offset": 24.0, "color": Color(0.57, 0.69, 0.40, 0.16)},
		{"y_ratio": 0.48, "amplitude": 20.0, "phase": 188.0, "segment_length": 84.0, "gap_length": 62.0, "thickness": 11.0, "offset": -20.0, "color": Color(0.50, 0.64, 0.34, 0.15)},
		{"y_ratio": 0.70, "amplitude": 16.0, "phase": 310.0, "segment_length": 80.0, "gap_length": 58.0, "thickness": 9.0, "offset": 48.0, "color": Color(0.58, 0.71, 0.42, 0.14)}
	]
	for stripe_def in stripe_defs:
		_draw_battlefield_grass_stripe(canvas, world_rect, stripe_def, map_zoom, world_to_screen)


## 绘制单条分段草纹。
func _draw_battlefield_grass_stripe(canvas: Node2D, world_rect: Rect2, stripe_def: Dictionary, map_zoom: float, world_to_screen: Callable) -> void:
	var base_y: float = world_rect.position.y + world_rect.size.y * float(stripe_def["y_ratio"])
	var amplitude: float = float(stripe_def["amplitude"])
	var phase: float = float(stripe_def["phase"])
	var segment_length: float = float(stripe_def["segment_length"])
	var gap_length: float = float(stripe_def["gap_length"])
	var thickness: float = max(4.0, float(stripe_def["thickness"]) * map_zoom)
	var offset_x: float = float(stripe_def["offset"])
	var color: Color = stripe_def["color"]
	var x: float = world_rect.position.x + offset_x
	var end_x: float = world_rect.position.x + world_rect.size.x + segment_length
	var segment_index: int = 0
	while x < end_x:
		var segment_end_x: float = min(x + segment_length, end_x)
		if (segment_index + int(round(float(stripe_def["y_ratio"]) * 10.0))) % 3 != 1:
			var start_point: Vector2 = _get_battlefield_grass_stripe_point(x, base_y, amplitude, phase)
			var mid_x: float = (x + segment_end_x) * 0.5
			var mid_point: Vector2 = _get_battlefield_grass_stripe_point(mid_x, base_y, amplitude, phase)
			var end_point: Vector2 = _get_battlefield_grass_stripe_point(segment_end_x, base_y, amplitude, phase)
			canvas.draw_line(world_to_screen.call(start_point), world_to_screen.call(mid_point), color, thickness, true)
			canvas.draw_line(world_to_screen.call(mid_point), world_to_screen.call(end_point), color, thickness, true)
		x += segment_length + gap_length
		segment_index += 1


## 计算单条草纹上的曲线采样点。
func _get_battlefield_grass_stripe_point(x_position: float, base_y: float, amplitude: float, phase: float) -> Vector2:
	var wave_y: float = base_y
	wave_y += sin((x_position + phase) / 175.0) * amplitude
	wave_y += cos((x_position + phase) / 121.0) * amplitude * 0.25
	return Vector2(x_position, wave_y)


## 绘制极轻的氛围块。
func _draw_battlefield_atmosphere_blocks(canvas: Node2D, world_rect: Rect2, map_zoom: float, world_to_screen: Callable) -> void:
	var block_defs: Array[Dictionary] = [
		{"center_ratio": Vector2(0.10, 0.20), "radius": 88.0, "skew": Vector2(38.0, -14.0), "color": Color(0.74, 0.80, 0.56, 0.09)},
		{"center_ratio": Vector2(0.38, 0.84), "radius": 72.0, "skew": Vector2(-26.0, 18.0), "color": Color(0.67, 0.75, 0.48, 0.08)},
		{"center_ratio": Vector2(0.62, 0.12), "radius": 64.0, "skew": Vector2(20.0, 18.0), "color": Color(0.72, 0.77, 0.54, 0.07)},
		{"center_ratio": Vector2(0.84, 0.56), "radius": 78.0, "skew": Vector2(-34.0, -16.0), "color": Color(0.63, 0.73, 0.46, 0.08)}
	]
	for block_def in block_defs:
		var center_ratio: Vector2 = Vector2(block_def["center_ratio"])
		var world_center: Vector2 = world_rect.position + Vector2(world_rect.size.x * center_ratio.x, world_rect.size.y * center_ratio.y)
		var radius: float = float(block_def["radius"])
		var skew: Vector2 = Vector2(block_def["skew"])
		var color: Color = block_def["color"]
		_draw_battlefield_soft_block(canvas, world_center, radius, skew, color, map_zoom, world_to_screen)


## 绘制单个极轻氛围块。
func _draw_battlefield_soft_block(canvas: Node2D, world_center: Vector2, world_radius: float, skew: Vector2, color: Color, map_zoom: float, world_to_screen: Callable) -> void:
	canvas.draw_circle(world_to_screen.call(world_center), world_radius * map_zoom, color)
	canvas.draw_circle(world_to_screen.call(world_center + skew), world_radius * 0.72 * map_zoom, color.lerp(Color.WHITE, 0.06))