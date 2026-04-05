class_name CameraController
extends RefCounted

## 相机控制器
##
## 职责：地图世界尺寸、偏移、缩放、边界钳制、坐标转换
## 调用场景：主场景需要地图浏览和坐标换算时

signal offset_changed(new_offset: Vector2)
signal zoom_changed(new_zoom: float)

const MOBILE_MAP_WORLD_SCALE: Vector2 = Vector2(2.15, 2.0)
const MOBILE_MAP_WORLD_PADDING: Vector2 = Vector2(460.0, 680.0)
const DESKTOP_MAP_WORLD_SCALE: Vector2 = Vector2(1.12, 1.16)
const DESKTOP_MAP_WORLD_PADDING: Vector2 = Vector2(100.0, 160.0)
const MAP_WORLD_MIN_SIZE: Vector2 = Vector2(1200.0, 2200.0)
const MAP_ZOOM_MIN: float = 0.3
const MAP_ZOOM_MAX: float = 1.8

var map_world_size: Vector2 = Vector2.ZERO
var map_offset: Vector2 = Vector2.ZERO
var map_zoom: float = 1.0

var _viewport_getter: Callable
var _is_mobile_runtime_getter: Callable
var _is_desktop_runtime_getter: Callable
var _top_panel_bottom_getter: Callable


## 初始化相机控制器，传入视口获取函数和平台判断函数。
##
## 调用场景：主场景 _ready() 时。
func setup(
	viewport_getter: Callable,
	is_mobile_runtime_getter: Callable,
	is_desktop_runtime_getter: Callable,
	top_panel_bottom_getter: Callable
) -> void:
	_viewport_getter = viewport_getter
	_is_mobile_runtime_getter = is_mobile_runtime_getter
	_is_desktop_runtime_getter = is_desktop_runtime_getter
	_top_panel_bottom_getter = top_panel_bottom_getter


## 重置地图尺寸和偏移，用于新开局。
##
## 调用场景：新开一局时。
func reset_for_new_match(target_world_size: Vector2, city_bounds: Rect2 = Rect2()) -> void:
	map_world_size = target_world_size
	map_zoom = _calculate_fit_zoom(city_bounds)


## 计算让地图完整显示在视口中的缩放值。
func _calculate_fit_zoom(city_bounds: Rect2 = Rect2()) -> float:
	var viewport_size: Vector2 = _get_viewport_size()
	var target_size: Vector2
	# 如果有城市边界信息，基于城市边界计算缩放
	if city_bounds.size.x > 0.0 and city_bounds.size.y > 0.0:
		# 给城市边界增加一点padding
		var padding: float = 80.0
		target_size = Vector2(city_bounds.size.x + padding * 2.0, city_bounds.size.y + padding * 2.0)
	else:
		target_size = map_world_size
	var fit_zoom_x: float = viewport_size.x / target_size.x
	var fit_zoom_y: float = viewport_size.y / target_size.y
	var fit_zoom: float = min(fit_zoom_x, fit_zoom_y)
	return clamp(fit_zoom, MAP_ZOOM_MIN, MAP_ZOOM_MAX)


## 根据城市位置计算边界框。
func calculate_city_bounds(cities: Array) -> Rect2:
	if cities.is_empty():
		return Rect2()
	var min_pos: Vector2 = cities[0].position
	var max_pos: Vector2 = cities[0].position
	for city in cities:
		min_pos.x = min(min_pos.x, city.position.x)
		min_pos.y = min(min_pos.y, city.position.y)
		max_pos.x = max(max_pos.x, city.position.x)
		max_pos.y = max(max_pos.y, city.position.y)
	return Rect2(min_pos, max_pos - min_pos)


## 调整缩放以让指定城市边界完整显示在视口中。
func fit_to_city_bounds(city_bounds: Rect2) -> void:
	map_zoom = _calculate_fit_zoom(city_bounds)


## 计算目标地图世界尺寸（公开方法）。
##
## 调用场景：主场景新开一局时需要传入尺寸给地图装载器。
## 主要逻辑：根据视口和平台计算目标地图尺寸。
func get_target_map_world_size(viewport_size: Vector2, use_viewport_size: bool = false) -> Vector2:
	return _get_target_map_world_size(viewport_size, use_viewport_size)


## 应用视口变化，扩展地图世界尺寸。
##
## 调用场景：窗口尺寸变化时。
func apply_viewport_change() -> void:
	var viewport_size: Vector2 = _get_viewport_size()
	var target_size: Vector2 = _get_target_map_world_size(viewport_size)
	map_world_size = Vector2(
		max(map_world_size.x, target_size.x),
		max(map_world_size.y, target_size.y)
	)


## 居中地图偏移。
##
## 调用场景：新开一局生成地图之后。
func center_map(get_first_player_city: Callable) -> void:
	var viewport_size: Vector2 = _get_viewport_size()
	map_offset = (viewport_size - _get_scaled_map_world_size()) * 0.5
	map_offset = _bias_initial_offset_towards_player_city(map_offset, viewport_size, get_first_player_city)
	map_offset = clamp_map_offset(map_offset)


## 设置地图偏移。
##
## 调用场景：拖拽更新位置时。
func set_offset(offset: Vector2) -> void:
	map_offset = clamp_map_offset(offset)


## 设置地图缩放，保持锚点在世界坐标不变。
##
## 调用场景：桌面滚轮缩放、移动端双指缩放。
func set_zoom(next_zoom: float, anchor_screen_position: Vector2) -> void:
	var effective_min_zoom: float = _calculate_min_zoom()
	var clamped_zoom: float = clamp(next_zoom, effective_min_zoom, MAP_ZOOM_MAX)
	if is_equal_approx(clamped_zoom, map_zoom):
		return
	var world_anchor_before_zoom: Vector2 = screen_to_world(anchor_screen_position)
	map_zoom = clamped_zoom
	var next_offset: Vector2 = anchor_screen_position - world_delta_to_screen(world_anchor_before_zoom)
	set_offset(next_offset)


## 世界坐标转屏幕坐标。
func world_to_screen(world_position: Vector2) -> Vector2:
	return world_delta_to_screen(world_position) + map_offset


## 屏幕坐标转世界坐标。
func screen_to_world(screen_position: Vector2) -> Vector2:
	return (screen_position - map_offset) / map_zoom


## 世界距离转屏幕距离。
func world_delta_to_screen(world_delta: Vector2) -> Vector2:
	return world_delta * map_zoom


## 边界钳制地图偏移，确保地图边缘不会露出视口。
##
## 调用场景：设置地图偏移、拖拽地图时。
## 主要逻辑：当地图比视口大时，限制偏移让地图边缘始终贴合视口边缘；
## 当地图比视口小时，居中显示。
func clamp_map_offset(offset: Vector2) -> Vector2:
	var viewport_size: Vector2 = _get_viewport_size()
	var scaled_map_size: Vector2 = _get_scaled_map_world_size()

	# 计算偏移的边界限制
	# 当地图比视口大时：offset 应该为负数，范围是 [viewport - map_size, 0]
	# 当地图比视口小时：offset 应该为正数，居中显示
	var min_offset_x: float = viewport_size.x - scaled_map_size.x
	var max_offset_x: float = 0.0
	var min_offset_y: float = viewport_size.y - scaled_map_size.y
	var max_offset_y: float = 0.0

	return Vector2(
		clamp(offset.x, min_offset_x, max_offset_x),
		clamp(offset.y, min_offset_y, max_offset_y)
	)


## 计算最小缩放值，确保缩放后地图恰好填满视口（不会比视口小）。
func _calculate_min_zoom() -> float:
	var viewport_size: Vector2 = _get_viewport_size()
	var min_zoom_x: float = viewport_size.x / map_world_size.x
	var min_zoom_y: float = viewport_size.y / map_world_size.y
	return max(min(min_zoom_x, min_zoom_y), MAP_ZOOM_MIN)


## 获取缩放后的地图世界尺寸。
func _get_scaled_map_world_size() -> Vector2:
	return map_world_size * map_zoom


## 获取目标地图世界尺寸。
func _get_target_map_world_size(viewport_size: Vector2, use_viewport_size: bool = false) -> Vector2:
	if use_viewport_size:
		# 适配模式：地图尺寸填满当前视口
		return viewport_size
	var world_scale: Vector2 = DESKTOP_MAP_WORLD_SCALE
	var world_padding: Vector2 = DESKTOP_MAP_WORLD_PADDING
	if _is_mobile_runtime():
		world_scale = MOBILE_MAP_WORLD_SCALE
		world_padding = MOBILE_MAP_WORLD_PADDING
	return Vector2(
		max(MAP_WORLD_MIN_SIZE.x, max(viewport_size.x + world_padding.x, viewport_size.x * world_scale.x)),
		max(MAP_WORLD_MIN_SIZE.y, max(viewport_size.y + world_padding.y, viewport_size.y * world_scale.y))
	)


## 判断是否为移动端运行时。
func _is_mobile_runtime() -> bool:
	if not DisplayServer.is_touchscreen_available():
		return false
	return not _is_desktop_runtime_getter.call()


## 获取视口尺寸。
func _get_viewport_size() -> Vector2:
	return _viewport_getter.call()


## 让开局镜头轻微偏向玩家出生城。
func _bias_initial_offset_towards_player_city(base_offset: Vector2, viewport_size: Vector2, get_first_player_city: Callable) -> Vector2:
	var player_city = get_first_player_city.call()
	if player_city == null:
		return base_offset
	var safe_anchor: Vector2 = Vector2(
		min(viewport_size.x * 0.28, 260.0),
		max(190.0, _top_panel_bottom_getter.call() + 70.0)
	)
	return safe_anchor - world_delta_to_screen(player_city.position)