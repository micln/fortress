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
const MAP_ZOOM_MIN: float = 0.75
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
func reset_for_new_match(target_world_size: Vector2) -> void:
	map_world_size = target_world_size
	map_zoom = 1.0


## 计算目标地图世界尺寸（公开方法）。
##
## 调用场景：主场景新开一局时需要传入尺寸给地图装载器。
## 主要逻辑：根据视口和平台计算目标地图尺寸。
func get_target_map_world_size(viewport_size: Vector2) -> Vector2:
	return _get_target_map_world_size(viewport_size)


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
	var clamped_zoom: float = clamp(next_zoom, MAP_ZOOM_MIN, MAP_ZOOM_MAX)
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


## 边界钳制地图偏移。
func clamp_map_offset(offset: Vector2) -> Vector2:
	var viewport_size: Vector2 = _get_viewport_size()
	var scaled_map_size: Vector2 = _get_scaled_map_world_size()
	var min_offset_x: float = min(0.0, viewport_size.x - scaled_map_size.x)
	var min_offset_y: float = min(0.0, viewport_size.y - scaled_map_size.y)
	return Vector2(
		clamp(offset.x, min_offset_x, 0.0),
		clamp(offset.y, min_offset_y, 0.0)
	)


## 获取缩放后的地图世界尺寸。
func _get_scaled_map_world_size() -> Vector2:
	return map_world_size * map_zoom


## 获取目标地图世界尺寸。
func _get_target_map_world_size(viewport_size: Vector2) -> Vector2:
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