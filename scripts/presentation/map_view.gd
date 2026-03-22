class_name MapView
extends Control

const FactionRef = preload("res://scripts/domain/faction.gd")

signal city_pressed(city_id: int)

const CITY_RADIUS: float = 38.0
const PLAYER_COLOR := Color("4caf50")
const ENEMY_COLOR := Color("e53935")
const NEUTRAL_COLOR := Color("78909c")
const SELECTED_COLOR := Color("fff176")
const NEIGHBOR_COLOR := Color("80cbc4")

var _game_state = null
var _selected_city_id: int = -1
var _highlighted_neighbors: Array[int] = []


## 注入当前游戏状态并刷新地图展示。
## 调用场景：主场景创建新对局或战斗结算后调用。
## 主要逻辑：缓存状态对象后请求重绘。
func set_game_state(game_state) -> void:
	_game_state = game_state
	queue_redraw()


## 设置当前选中城市与可攻击邻居，用于提供触控反馈。
## 调用场景：玩家点击己方城市或取消选择时调用。
## 主要逻辑：更新本地高亮状态并请求重绘。
func set_selection(selected_city_id: int, neighbor_ids: Array[int]) -> void:
	_selected_city_id = selected_city_id
	_highlighted_neighbors = neighbor_ids
	queue_redraw()


## 处理触控与鼠标点击，并将命中的城市编号向上抛出。
## 调用场景：玩家在地图上交互时由 Godot 输入系统调用。
## 主要逻辑：兼容触摸和鼠标左键，命中城市则发出信号，未命中发送 `-1` 表示空白区域。
func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch and event.pressed:
		city_pressed.emit(_pick_city(event.position))
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		city_pressed.emit(_pick_city(event.position))


## 按照当前状态绘制道路、城市圆点和士兵数量。
## 调用场景：状态变化或窗口重绘时由引擎调用。
## 主要逻辑：先画道路，再画城市底色、高亮环和数字文本，保持层次清晰。
func _draw() -> void:
	if _game_state == null:
		return

	for road in _game_state.get_all_roads():
		var from_city = _game_state.get_city(road.from_city_id)
		var to_city = _game_state.get_city(road.to_city_id)
		draw_line(from_city.position, to_city.position, Color("455a64"), 8.0, true)

	for city in _game_state.get_all_cities():
		var base_color: Color = _get_city_color(city.owner)
		draw_circle(city.position, CITY_RADIUS, base_color)

		if city.id == _selected_city_id:
			draw_arc(city.position, CITY_RADIUS + 10.0, 0.0, TAU, 48, SELECTED_COLOR, 6.0)
		elif city.id in _highlighted_neighbors:
			draw_arc(city.position, CITY_RADIUS + 8.0, 0.0, TAU, 48, NEIGHBOR_COLOR, 4.0)

		var font: Font = ThemeDB.fallback_font
		var font_size: int = 30
		var number_text: String = str(city.soldiers)
		var text_size: Vector2 = font.get_string_size(number_text, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size)
		draw_string(font, city.position - Vector2(text_size.x * 0.5, -10.0), number_text, HORIZONTAL_ALIGNMENT_CENTER, -1.0, font_size, Color.WHITE)


## 根据点击坐标寻找命中的城市编号。
## 调用场景：处理地图点击时调用。
## 主要逻辑：遍历所有城市，若点到城市半径范围内则返回对应编号。
func _pick_city(pointer_position: Vector2) -> int:
	if _game_state == null:
		return -1

	for city in _game_state.get_all_cities():
		if pointer_position.distance_to(city.position) <= CITY_RADIUS:
			return city.id
	return -1


## 为不同阵营返回统一颜色，以降低地图识别成本。
## 调用场景：绘制城市节点时调用。
## 主要逻辑：按归属映射颜色常量。
func _get_city_color(owner: int) -> Color:
	match owner:
		FactionRef.Type.PLAYER:
			return PLAYER_COLOR
		FactionRef.Type.ENEMY:
			return ENEMY_COLOR
		_:
			return NEUTRAL_COLOR
