class_name MainGame
extends Node2D

const FactionRef = preload("res://scripts/domain/faction.gd")
const MapGeneratorRef = preload("res://scripts/application/map_generator.gd")
const GameStateRef = preload("res://scripts/application/game_state.gd")
const EnemyAIRef = preload("res://scripts/application/enemy_ai.gd")

const CITY_COUNT: int = 9
const PRODUCTION_INTERVAL: float = 1.0
const ENEMY_ACTION_INTERVAL: float = 1.6

@onready var _cities_layer: Node2D = $Cities
@onready var _status_label: Label = $UILayer/TopPanel/Margin/InfoColumn/StatusLabel
@onready var _hint_label: Label = $UILayer/TopPanel/Margin/InfoColumn/HintLabel
@onready var _city_template: Area2D = $CityTemplate

var _game_state = null
var _map_generator = MapGeneratorRef.new()
var _enemy_ai = EnemyAIRef.new()
var _city_views: Dictionary = {}
var _selected_city_id: int = -1
var _production_elapsed: float = 0.0
var _enemy_elapsed: float = 0.0
var _is_game_over: bool = false


## 初始化地图节点、复制城市模板并建立首局游戏状态。
## 调用场景：主场景进入树后自动调用。
## 主要逻辑：生成随机地图、创建 `GameState`、实例化城市视图并刷新文字与道路。
func _ready() -> void:
	_city_template.visible = false
	_start_new_game()


## 推进产兵与敌方行动定时器，驱动整局游戏演进。
## 调用场景：每帧由 Godot 调用。
## 主要逻辑：累计时间并在达到阈值时分别触发产兵和敌方 AI 行动。
func _process(delta: float) -> void:
	if _is_game_over:
		return

	_production_elapsed += delta
	_enemy_elapsed += delta

	if _production_elapsed >= PRODUCTION_INTERVAL:
		_production_elapsed -= PRODUCTION_INTERVAL
		_game_state.tick_production()
		_refresh_view()
		_check_winner()

	if _enemy_elapsed >= ENEMY_ACTION_INTERVAL:
		_enemy_elapsed -= ENEMY_ACTION_INTERVAL
		_execute_enemy_turn()


## 处理地图空白区域上的触控和鼠标点击，用于取消选中。
## 调用场景：未被城市节点消费的输入事件会传到这里。
## 主要逻辑：若点击位置没有命中任何城市，则清空当前选中状态。
func _unhandled_input(event: InputEvent) -> void:
	if _is_game_over or _selected_city_id == -1:
		return

	var pointer_position := Vector2.ZERO
	var is_press: bool = false
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		pointer_position = event.position
		is_press = true
	elif event is InputEventScreenTouch and event.pressed:
		pointer_position = event.position
		is_press = true

	if is_press and _pick_city_at_position(pointer_position) == -1:
		_clear_selection()


## 绘制所有道路，形成清晰的城市连接关系。
## 调用场景：状态刷新或窗口重绘时由引擎调用。
## 主要逻辑：遍历道路数组并根据两端城市位置绘制线段。
func _draw() -> void:
	if _game_state == null:
		return

	for road in _game_state.get_all_roads():
		var from_city = _game_state.get_city(road.from_city_id)
		var to_city = _game_state.get_city(road.to_city_id)
		draw_line(from_city.position, to_city.position, Color("5c6773"), 8.0, true)


## 创建一局新的随机对战并重置运行时状态。
## 调用场景：首次启动或未来支持重新开局时调用。
## 主要逻辑：基于地图生成器结果构造 `GameState`，重建城市视图并清空选择与计时器。
func _start_new_game() -> void:
	var map_definition: Dictionary = _map_generator.generate(CITY_COUNT, get_viewport_rect().size)
	_game_state = GameStateRef.new(map_definition["cities"], map_definition["roads"])
	_selected_city_id = -1
	_production_elapsed = 0.0
	_enemy_elapsed = 0.0
	_is_game_over = false
	_rebuild_city_views()
	_refresh_view()


## 复制模板并为每座城市创建一个独立的表现节点。
## 调用场景：新开局或未来重建地图时调用。
## 主要逻辑：清理旧节点后复制 `CityTemplate`，连接点击信号并缓存到字典。
func _rebuild_city_views() -> void:
	for child in _cities_layer.get_children():
		child.queue_free()

	_city_views.clear()

	for city in _game_state.get_all_cities():
		var city_view = _city_template.duplicate()
		city_view.visible = true
		_cities_layer.add_child(city_view)
		city_view.setup(city.id, "城市 %d" % (city.id + 1))
		city_view.city_pressed.connect(_on_city_pressed)
		_city_views[city.id] = city_view


## 处理玩家点击城市后的交互逻辑。
## 调用场景：任意城市节点发出 `city_pressed` 信号时调用。
## 主要逻辑：点击己方城市时更新选中；若已选中且点击相邻非己方城市，则发起进攻。
func _on_city_pressed(city_id: int) -> void:
	if _is_game_over:
		return

	var clicked_city = _game_state.get_city(city_id)
	if clicked_city.owner == FactionRef.Type.PLAYER:
		_select_city(city_id)
		return

	if _selected_city_id != -1 and _game_state.is_adjacent(_selected_city_id, city_id):
		var result: Dictionary = _game_state.attack(_selected_city_id, city_id, FactionRef.Type.PLAYER)
		if result.get("success", false):
			_clear_selection()
			_refresh_view()
			_check_winner()


## 选中一个己方城市，并让对应城市视图显示高亮。
## 调用场景：玩家点击己方城市时调用。
## 主要逻辑：记录选中编号后刷新全部城市视图和状态提示。
func _select_city(city_id: int) -> void:
	_selected_city_id = city_id
	_refresh_view()


## 清除当前选中状态。
## 调用场景：点击空白区域、攻击结算完成后调用。
## 主要逻辑：重置选中编号并刷新展示。
func _clear_selection() -> void:
	_selected_city_id = -1
	_refresh_view()


## 执行一次敌方 AI 回合。
## 调用场景：敌方行动计时器达到阈值时调用。
## 主要逻辑：请求 AI 选择一条攻击命令，若存在则提交给 `GameState` 结算。
func _execute_enemy_turn() -> void:
	var command: Dictionary = _enemy_ai.choose_attack(_game_state)
	if command.is_empty():
		return

	var result: Dictionary = _game_state.attack(command["from_city_id"], command["to_city_id"], FactionRef.Type.ENEMY)
	if result.get("success", false):
		_refresh_view()
		_check_winner()


## 同步所有城市视图、道路与顶部文字提示。
## 调用场景：开局、产兵、攻击和选择变化后调用。
## 主要逻辑：遍历城市并把状态推送给 `CityView`，随后重绘道路与文案。
func _refresh_view() -> void:
	if _game_state == null:
		return

	for city in _game_state.get_all_cities():
		if not _city_views.has(city.id):
			continue
		_city_views[city.id].sync_from_state(city, city.id == _selected_city_id)

	queue_redraw()
	_refresh_hud()


## 根据当前局势和选中状态更新顶部状态与提示文案。
## 调用场景：任何状态变化后调用。
## 主要逻辑：汇总玩家/敌方城市数与兵力，并按是否选中城市显示不同说明。
func _refresh_hud() -> void:
	var player_cities: Array = _game_state.get_cities_owned_by(FactionRef.Type.PLAYER)
	var enemy_cities: Array = _game_state.get_cities_owned_by(FactionRef.Type.ENEMY)
	_status_label.text = "玩家城池 %d | 敌人城池 %d" % [player_cities.size(), enemy_cities.size()]

	if _selected_city_id == -1:
		_hint_label.text = "点击你的城市进行选中，再点击相邻目标城市进攻。"
		return

	var selected_city = _game_state.get_city(_selected_city_id)
	_hint_label.text = "已选中 %d 号城 | 归属：%s | 士兵：%d" % [
		selected_city.id,
		FactionRef.to_text(selected_city.owner),
		selected_city.soldiers,
	]


## 检查是否产生胜负结果，并在结束时锁定游戏状态。
## 调用场景：每次产兵和攻击后调用。
## 主要逻辑：读取 `GameState` 胜负判断，若有结果则更新文案并阻止后续操作。
func _check_winner() -> void:
	var winner: int = _game_state.get_winner()
	if winner == FactionRef.Type.NEUTRAL:
		return

	_is_game_over = true
	_selected_city_id = -1
	_refresh_view()
	if winner == FactionRef.Type.PLAYER:
		_status_label.text = "你赢了"
	else:
		_status_label.text = "敌人获胜"
	_hint_label.text = "对局结束，重新运行场景可开始新的一局。"


## 根据点击位置判断是否命中了某个城市。
## 调用场景：空白点击取消选择前的命中测试。
## 主要逻辑：遍历全部城市节点，用圆形半径检测点击坐标与城市中心的距离。
func _pick_city_at_position(pointer_position: Vector2) -> int:
	for city in _game_state.get_all_cities():
		if pointer_position.distance_to(city.position) <= 42.0:
			return city.id
	return -1
