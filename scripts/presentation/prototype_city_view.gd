class_name PrototypeCityView
extends Area2D

signal city_pressed(city_id: int)

const CITY_SIZE: Vector2 = Vector2(108.0, 78.0)
const TOWER_SIZE: Vector2 = Vector2(20.0, 34.0)
const TAP_MAX_DRAG_DISTANCE: float = 18.0
const TILE_ROOF_COLOR: Color = Color(0.34, 0.16, 0.12)
const WALL_LINE_COLOR: Color = Color(1.0, 0.96, 0.86, 0.92)
const PrototypeCityOwnerRef = preload("res://scripts/domain/prototype_city_owner.gd")

var city_id: int = -1
var city_name: String = ""
var city_owner: int = PrototypeCityOwnerRef.NEUTRAL
var city_level: int = 1
var city_defense: int = 1
var city_production_rate: float = 1.0
var soldiers: int = 0
var is_selected: bool = false
var _mouse_pressing: bool = false
var _mouse_press_position: Vector2 = Vector2.ZERO
var _touch_pressing: bool = false
var _touch_press_position: Vector2 = Vector2.ZERO
var _touch_index: int = -1

@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var name_label: Label = $NameLabel
@onready var soldier_label: Label = $SoldierLabel
@onready var attr_label: Label = $AttrLabel


## 初始化城市表现节点的固定数据与输入碰撞区域。
##
## 调用场景：主场景实例化城市节点后立即调用。
## 主要逻辑：写入城市编号和名称，并用矩形碰撞体统一覆盖触控与鼠标点击范围。
func setup(p_city_id: int, p_city_name: String) -> void:
	city_id = p_city_id
	city_name = p_city_name
	name_label.text = city_name
	var shape := RectangleShape2D.new()
	shape.size = CITY_SIZE
	collision_shape.shape = shape


## 根据城市实时状态刷新文字、颜色与选中高亮。
##
## 调用场景：每次地图重绘、进攻结算后、产兵后。
## 主要逻辑：同步内部显示数据，把名称、兵力和属性拆成三层文本展示，
## 让竖屏小地图上的信息层级更稳定、字体节奏更统一；屏幕位置由主场景统一换算后传入，
## 避免城市节点自己混用世界坐标与屏幕坐标。
func sync_from_state(city, selected: bool, screen_position: Vector2) -> void:
	city_owner = city.owner
	city_level = city.level
	city_defense = city.defense
	city_production_rate = city.production_rate
	soldiers = city.soldiers
	is_selected = selected
	position = screen_position
	name_label.text = city.name
	soldier_label.text = "%d/%d" % [city.soldiers, city.max_soldiers]
	attr_label.text = "Lv.%d  防%d  产%.1f" % [city.level, city.defense, city.production_rate]
	queue_redraw()


## 绘制更规整的中式城池图标：主体、城门、角楼与旗帜。
##
## 调用场景：Godot 需要重绘节点时自动调用。
## 主要逻辑：以中心主体矩形为核心，底部补一个城门矩形，两侧加竖向角楼，
## 再在角楼顶部插旗，形成清楚、稳定、易识别的城市符号。
func _draw() -> void:
	var base_color: Color = PrototypeCityOwnerRef.get_color(city_owner)
	var wall_color: Color = base_color.lerp(Color(0.92, 0.89, 0.8), 0.26 + 0.04 * float(city_level))
	var side_tower_color: Color = wall_color.darkened(0.07)
	var city_body_rect := Rect2(Vector2(-30.0, -18.0), Vector2(60.0, 40.0))
	var gate_rect := Rect2(Vector2(-10.0, 8.0), Vector2(20.0, 14.0))
	var tower_bottom_y: float = city_body_rect.end.y
	var left_tower := Rect2(Vector2(-46.0, tower_bottom_y - TOWER_SIZE.y), TOWER_SIZE)
	var right_tower := Rect2(Vector2(26.0, tower_bottom_y - TOWER_SIZE.y), TOWER_SIZE)

	draw_circle(Vector2(0.0, 28.0), 32.0, Color(0.0, 0.0, 0.0, 0.12))
	draw_rect(city_body_rect, wall_color)
	draw_rect(left_tower, side_tower_color)
	draw_rect(right_tower, side_tower_color)
	draw_rect(gate_rect, Color(0.34, 0.2, 0.13))
	_draw_simple_roof(city_body_rect, TILE_ROOF_COLOR)
	_draw_simple_roof(left_tower, TILE_ROOF_COLOR)
	_draw_simple_roof(right_tower, TILE_ROOF_COLOR)
	_draw_tower_flag(left_tower, base_color, false)
	_draw_tower_flag(right_tower, base_color, true)
	_draw_level_banner(city_body_rect, base_color)
	draw_rect(city_body_rect, WALL_LINE_COLOR, false, 3.0)
	draw_rect(left_tower, WALL_LINE_COLOR, false, 3.0)
	draw_rect(right_tower, WALL_LINE_COLOR, false, 3.0)
	draw_rect(gate_rect, Color(0.9, 0.86, 0.76), false, 2.0)

	if is_selected:
		var highlight_rect := Rect2(Vector2(-CITY_SIZE.x * 0.68, -CITY_SIZE.y * 0.68), Vector2(CITY_SIZE.x * 1.36, CITY_SIZE.y * 1.12))
		draw_rect(highlight_rect, Color(1.0, 0.93, 0.45), false, 6.0)
		draw_rect(highlight_rect.grow(8.0), Color(1.0, 0.93, 0.45, 0.22), false, 4.0)


## 为主体或角楼绘制简洁的中式屋顶。
##
## 调用场景：城市节点重绘主体和角楼时。
## 主要逻辑：使用梯形屋面和微微上扬的两端，让矩形体量更像中式建筑。
func _draw_simple_roof(roof_base_rect: Rect2, roof_color: Color) -> void:
	var roof_points := PackedVector2Array([
		roof_base_rect.position + Vector2(-5.0, 2.0),
		roof_base_rect.position + Vector2(roof_base_rect.size.x * 0.2, -8.0),
		roof_base_rect.position + Vector2(roof_base_rect.size.x * 0.8, -8.0),
		roof_base_rect.position + Vector2(roof_base_rect.size.x + 5.0, 2.0)
	])
	draw_colored_polygon(roof_points, roof_color)
	draw_polyline(roof_points, Color(0.95, 0.86, 0.73), 2.0, true)


## 在角楼顶部插一面旗子，增强城市识别度和阵营感。
##
## 调用场景：城市节点重绘左右角楼时。
## 主要逻辑：旗杆竖直放在角楼顶上，旗面朝外展开；左右两侧用不同方向避免完全对称死板。
func _draw_tower_flag(tower_rect: Rect2, flag_color: Color, facing_right: bool) -> void:
	var pole_x: float = tower_rect.position.x + tower_rect.size.x * 0.5
	var pole_top: Vector2 = Vector2(pole_x, tower_rect.position.y - 16.0)
	var pole_bottom: Vector2 = Vector2(pole_x, tower_rect.position.y - 2.0)
	draw_line(pole_bottom, pole_top, Color(0.96, 0.92, 0.82), 2.0, true)
	var horizontal: float = 12.0 if facing_right else -12.0
	var flag_points := PackedVector2Array([
		pole_top,
		pole_top + Vector2(horizontal, 4.0),
		pole_top + Vector2(0.0, 8.0)
	])
	draw_colored_polygon(flag_points, flag_color.lightened(0.08))


## 在门楼顶部绘制一面简洁旗幡，用来表达等级与阵营感。
##
## 调用场景：城市节点重绘门楼时。
## 主要逻辑：只保留一根旗杆和一面宽旗，长度随等级增长，保证轮廓大而清楚。
func _draw_level_banner(gatehouse_rect: Rect2, banner_color: Color) -> void:
	var pole_start := Vector2(0.0, gatehouse_rect.position.y + 2.0)
	var pole_end := pole_start + Vector2(0.0, -16.0)
	draw_line(pole_start, pole_end, Color(0.96, 0.92, 0.82), 2.0, true)
	var flag_length: float = 14.0 + float(city_level) * 3.0
	var flag_points := PackedVector2Array([
		pole_end,
		pole_end + Vector2(flag_length, 5.0),
		pole_end + Vector2(0.0, 10.0)
	])
	draw_colored_polygon(flag_points, banner_color.lightened(0.08))


## 处理城市节点上的触控和鼠标输入，并向主场景抛出点击事件。
##
## 调用场景：玩家点击或触摸城市时由 Godot 输入系统回调。
## 主要逻辑：按下时先记录初始位置；抬起时若位移仍在点击阈值内，才视为真正点击，
## 这样在城市上起手拖拽地图时，不会误触发选城。
func _input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_mouse_pressing = true
			_mouse_press_position = event.position
			return
		if not _mouse_pressing:
			return
		_mouse_pressing = false
		if event.position.distance_to(_mouse_press_position) <= TAP_MAX_DRAG_DISTANCE:
			_viewport.set_input_as_handled()
			city_pressed.emit(city_id)
		return

	if event is InputEventScreenTouch:
		if event.pressed:
			_touch_pressing = true
			_touch_press_position = event.position
			_touch_index = event.index
			return
		if not _touch_pressing or event.index != _touch_index:
			return
		_touch_pressing = false
		_touch_index = -1
		if event.position.distance_to(_touch_press_position) <= TAP_MAX_DRAG_DISTANCE:
			_viewport.set_input_as_handled()
			city_pressed.emit(city_id)
