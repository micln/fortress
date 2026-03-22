class_name CityView
extends Area2D

signal city_pressed(city_id: int)

const CITY_RADIUS: float = 42.0
const CityOwnerRef = preload("res://scripts/domain/city_owner.gd")

var city_id: int = -1
var city_name: String = ""
var city_owner: int = CityOwnerRef.NEUTRAL
var soldiers: int = 0
var is_selected: bool = false

@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var name_label: Label = $NameLabel
@onready var soldier_label: Label = $SoldierLabel


## 初始化城市表现节点的固定数据与输入碰撞区域。
##
## 调用场景：主场景实例化城市节点后立即调用。
## 主要逻辑：写入城市编号和名称，并用圆形碰撞体统一覆盖触控与鼠标点击范围。
func setup(p_city_id: int, p_city_name: String) -> void:
	city_id = p_city_id
	city_name = p_city_name
	name_label.text = city_name
	var shape := CircleShape2D.new()
	shape.radius = CITY_RADIUS
	collision_shape.shape = shape


## 根据城市实时状态刷新文字、颜色与选中高亮。
##
## 调用场景：每次地图重绘、进攻结算后、产兵后。
## 主要逻辑：同步内部显示数据，文本展示城市名称与当前士兵数，颜色由阵营和选中态共同决定。
func sync_from_state(city, selected: bool) -> void:
	city_owner = city.owner
	soldiers = city.soldiers
	is_selected = selected
	position = city.position
	name_label.text = city_name
	soldier_label.text = str(city.soldiers)
	queue_redraw()


## 绘制城市圆盘、边框和选中外环。
##
## 调用场景：Godot 需要重绘节点时自动调用。
## 主要逻辑：先绘制阵营主色圆盘，再叠加边框；若当前被选中，则额外绘制一层更大的高亮外环。
func _draw() -> void:
	var base_color: Color = CityOwnerRef.get_color(city_owner)
	draw_circle(Vector2.ZERO, CITY_RADIUS, base_color)
	draw_circle(Vector2.ZERO, CITY_RADIUS, Color.WHITE, false, 4.0)

	if is_selected:
		draw_circle(Vector2.ZERO, CITY_RADIUS + 10.0, Color(1.0, 0.93, 0.45), false, 6.0)


## 处理城市节点上的触控和鼠标输入，并向主场景抛出点击事件。
##
## 调用场景：玩家点击或触摸城市时由 Godot 输入系统回调。
## 主要逻辑：识别鼠标左键与单点触控按下事件，统一转换为 city_pressed 信号。
func _input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		city_pressed.emit(city_id)
	elif event is InputEventScreenTouch and event.pressed:
		city_pressed.emit(city_id)
