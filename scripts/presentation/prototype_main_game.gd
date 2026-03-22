extends Node2D

const PrototypeCityOwnerRef = preload("res://scripts/domain/prototype_city_owner.gd")
const PrototypeMapGeneratorRef = preload("res://scripts/application/prototype_map_generator.gd")
const PrototypeBattleServiceRef = preload("res://scripts/application/prototype_battle_service.gd")
const PrototypeEnemyAiServiceRef = preload("res://scripts/application/prototype_enemy_ai_service.gd")
const MARCH_SPEED: float = 240.0
const UNIT_RADIUS: float = 16.0
const MARCH_COLLISION_DISTANCE: float = 34.0
const AI_DIFFICULTY_ITEMS: Array = [
	{"id": PrototypeEnemyAiServiceRef.DIFFICULTY_EASY, "name": "简单"},
	{"id": PrototypeEnemyAiServiceRef.DIFFICULTY_NORMAL, "name": "普通"},
	{"id": PrototypeEnemyAiServiceRef.DIFFICULTY_HARD, "name": "困难"}
]
const PLAYER_COUNT_ITEMS: Array = [
	{"id": 2, "name": "2 方"},
	{"id": 3, "name": "3 方"},
	{"id": 4, "name": "4 方"},
	{"id": 5, "name": "5 方"}
]
const AI_STYLE_ITEMS: Array = [
	{"id": PrototypeEnemyAiServiceRef.STYLE_AGGRESSIVE, "name": "进攻型"},
	{"id": PrototypeEnemyAiServiceRef.STYLE_DEFENSIVE, "name": "防御型"}
]

var _random: RandomNumberGenerator = RandomNumberGenerator.new()
var _map_generator = PrototypeMapGeneratorRef.new()
var _battle_service = PrototypeBattleServiceRef.new()
var _enemy_ai_service = PrototypeEnemyAiServiceRef.new()
var _cities: Array = []
var _city_views: Dictionary = {}
var _marching_units: Array = []
var _selected_city_id: int = -1
var _pending_order: Dictionary = {}
var _pending_order_count: int = 0
var _next_march_order: int = 0
var _production_elapsed: float = 0.0
var _enemy_elapsed: float = 0.0
var _game_over: bool = false
var _game_started: bool = false
var _manual_paused: bool = false
var _overlay_mode: String = "start"
var _last_winner: int = PrototypeCityOwnerRef.NEUTRAL
var _player_count: int = 4
var _ai_difficulty: String = PrototypeEnemyAiServiceRef.DIFFICULTY_NORMAL
var _ai_style: String = PrototypeEnemyAiServiceRef.STYLE_AGGRESSIVE
var _audio_ready: bool = false
var _music_stream: AudioStreamWAV
var _select_sfx_stream: AudioStreamWAV
var _transfer_sfx_stream: AudioStreamWAV
var _attack_sfx_stream: AudioStreamWAV
var _capture_sfx_stream: AudioStreamWAV
var _error_sfx_stream: AudioStreamWAV
var _victory_sfx_stream: AudioStreamWAV
var _defeat_sfx_stream: AudioStreamWAV

@onready var cities_root: Node2D = $Cities
@onready var bgm_player: AudioStreamPlayer = $BgmPlayer
@onready var sfx_player: AudioStreamPlayer = $SfxPlayer
@onready var city_template = $CityTemplate
@onready var status_label: Label = $UILayer/TopPanel/Margin/InfoColumn/StatusLabel
@onready var hint_label: Label = $UILayer/TopPanel/Margin/InfoColumn/HintLabel
@onready var ai_config_label: Label = $UILayer/TopPanel/Margin/InfoColumn/AiConfigLabel
@onready var cancel_selection_button: Button = $UILayer/BottomPanel/BottomMargin/BottomRow/CancelSelectionButton
@onready var pause_button: Button = $UILayer/BottomPanel/BottomMargin/BottomRow/PauseButton
@onready var restart_button: Button = $UILayer/BottomPanel/BottomMargin/BottomRow/RestartButton
@onready var overlay_layer: CanvasLayer = $Overlay
@onready var overlay_title_label: Label = $Overlay/OverlayPanel/OverlayMargin/OverlayColumn/OverlayTitleLabel
@onready var overlay_body_label: Label = $Overlay/OverlayPanel/OverlayMargin/OverlayColumn/OverlayBodyLabel
@onready var overlay_rule_label: Label = $Overlay/OverlayPanel/OverlayMargin/OverlayColumn/RuleLabel
@onready var overlay_rule_label_2: Label = $Overlay/OverlayPanel/OverlayMargin/OverlayColumn/RuleLabel2
@onready var overlay_rule_label_3: Label = $Overlay/OverlayPanel/OverlayMargin/OverlayColumn/RuleLabel3
@onready var overlay_settings_grid: GridContainer = $Overlay/OverlayPanel/OverlayMargin/OverlayColumn/SettingsGrid
@onready var overlay_ai_count_option: OptionButton = $Overlay/OverlayPanel/OverlayMargin/OverlayColumn/SettingsGrid/AiCountOption
@onready var overlay_difficulty_option: OptionButton = $Overlay/OverlayPanel/OverlayMargin/OverlayColumn/SettingsGrid/DifficultyOption
@onready var overlay_style_option: OptionButton = $Overlay/OverlayPanel/OverlayMargin/OverlayColumn/SettingsGrid/StyleOption
@onready var overlay_action_button: Button = $Overlay/OverlayPanel/OverlayMargin/OverlayColumn/OverlayActionButton
@onready var order_dialog_layer: CanvasLayer = $OrderDialog
@onready var order_dialog_title_label: Label = $OrderDialog/Panel/Margin/Column/TitleLabel
@onready var order_dialog_context_label: Label = $OrderDialog/Panel/Margin/Column/ContextLabel
@onready var order_dialog_recommended_label: Label = $OrderDialog/Panel/Margin/Column/RecommendedLabel
@onready var order_dialog_forecast_label: Label = $OrderDialog/Panel/Margin/Column/ForecastLabel
@onready var order_dialog_outcome_label: Label = $OrderDialog/Panel/Margin/Column/OutcomeLabel
@onready var order_dialog_count_label: Label = $OrderDialog/Panel/Margin/Column/CountLabel
@onready var order_dialog_minus_10_button: Button = $OrderDialog/Panel/Margin/Column/AdjustRow/Minus10Button
@onready var order_dialog_minus_1_button: Button = $OrderDialog/Panel/Margin/Column/AdjustRow/Minus1Button
@onready var order_dialog_plus_1_button: Button = $OrderDialog/Panel/Margin/Column/AdjustRow/Plus1Button
@onready var order_dialog_plus_10_button: Button = $OrderDialog/Panel/Margin/Column/AdjustRow/Plus10Button
@onready var order_dialog_plus_20_button: Button = $OrderDialog/Panel/Margin/Column/QuickGrid/Plus20Button
@onready var order_dialog_plus_50_button: Button = $OrderDialog/Panel/Margin/Column/QuickGrid/Plus50Button
@onready var order_dialog_half_button: Button = $OrderDialog/Panel/Margin/Column/QuickGrid/HalfButton
@onready var order_dialog_full_button: Button = $OrderDialog/Panel/Margin/Column/QuickGrid/FullButton
@onready var order_dialog_recommend_button: Button = $OrderDialog/Panel/Margin/Column/QuickGrid/RecommendButton
@onready var order_dialog_keep_one_button: Button = $OrderDialog/Panel/Margin/Column/QuickGrid/MaxKeepOneButton
@onready var order_dialog_cancel_button: Button = $OrderDialog/Panel/Margin/Column/ActionRow/CancelButton
@onready var order_dialog_confirm_button: Button = $OrderDialog/Panel/Margin/Column/ActionRow/ConfirmButton


## 初始化战局、音频和所有 UI 信号。
##
## 调用场景：主场景进入场景树后自动执行。
## 主要逻辑：初始化随机数与程序音频，创建一局新地图，连接常驻按钮和出兵弹窗按钮事件。
func _ready() -> void:
	_random.randomize()
	_setup_audio()
	_setup_ai_controls()
	_apply_ai_profile()
	_start_new_match()
	cancel_selection_button.pressed.connect(_on_cancel_selection_button_pressed)
	pause_button.pressed.connect(_on_pause_button_pressed)
	restart_button.pressed.connect(_on_restart_button_pressed)
	overlay_action_button.pressed.connect(_on_overlay_action_button_pressed)
	bgm_player.finished.connect(_on_bgm_finished)
	order_dialog_minus_10_button.pressed.connect(func() -> void: _adjust_order_count(-10))
	order_dialog_minus_1_button.pressed.connect(func() -> void: _adjust_order_count(-1))
	order_dialog_plus_1_button.pressed.connect(func() -> void: _adjust_order_count(1))
	order_dialog_plus_10_button.pressed.connect(func() -> void: _adjust_order_count(10))
	order_dialog_plus_20_button.pressed.connect(func() -> void: _adjust_order_count(20))
	order_dialog_plus_50_button.pressed.connect(func() -> void: _adjust_order_count(50))
	order_dialog_half_button.pressed.connect(_on_order_half_button_pressed)
	order_dialog_full_button.pressed.connect(_on_order_full_button_pressed)
	order_dialog_recommend_button.pressed.connect(_on_order_recommend_button_pressed)
	order_dialog_keep_one_button.pressed.connect(_on_order_keep_one_button_pressed)
	order_dialog_cancel_button.pressed.connect(_on_order_cancel_button_pressed)
	order_dialog_confirm_button.pressed.connect(_on_order_confirm_button_pressed)
	_show_start_overlay()


## 推进战局主循环，包括行军、产兵和敌军 AI 下单。
##
## 调用场景：每帧自动执行。
## 主要逻辑：逐帧推进所有行军单位；每秒为占领城市产兵；当玩家没有选中城市且未打开出兵弹窗时，敌军会按周期出兵。
func _process(delta: float) -> void:
	if _game_over or not _game_started:
		return
	if _is_gameplay_paused():
		return

	_update_marching_units(delta)
	_production_elapsed += delta
	_enemy_elapsed += delta

	if _production_elapsed >= 1.0:
		_production_elapsed -= 1.0
		_battle_service.produce_soldiers(_cities)
		if order_dialog_layer.visible:
			_refresh_order_dialog()
		_refresh_view()

	if _selected_city_id != -1:
		return

	var enemy_turn_interval: float = _enemy_ai_service.get_turn_interval()
	if _enemy_elapsed >= enemy_turn_interval:
		_enemy_elapsed -= enemy_turn_interval
		_run_enemy_turn()


## 绘制道路高亮和所有行军单位。
##
## 调用场景：Godot 需要重绘主场景时自动调用。
## 主要逻辑：先绘制城市间道路，再绘制道路上的行军单位和其携带兵力数字。
func _draw() -> void:
	_draw_battlefield_background()

	for city in _cities:
		for neighbor_id: int in city.neighbors:
			if neighbor_id < city.city_id:
				continue

			var target = _cities[neighbor_id]
			var line_color := Color("48576a")
			var line_width: float = 6.0
			if city.city_id == _selected_city_id or target.city_id == _selected_city_id:
				line_color = Color("f6d365")
				line_width = 10.0

			draw_line(city.position, target.position, line_color, line_width, true)

	for unit in _marching_units:
		var unit_position: Vector2 = _get_marching_unit_position(unit)
		var unit_color: Color = PrototypeCityOwnerRef.get_color(int(unit["owner"]))
		draw_circle(unit_position, UNIT_RADIUS, unit_color)
		draw_circle(unit_position, UNIT_RADIUS, Color.WHITE, false, 3.0)
		var font_size: int = 18
		var text: String = str(int(unit["count"]))
		var font := ThemeDB.fallback_font
		var text_size: Vector2 = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
		draw_string(font, unit_position + Vector2(-text_size.x * 0.5, 6.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color.WHITE)


## 重置运行时状态并生成一局新地图。
##
## 调用场景：首次进入游戏、点击重新开始、胜负结束后再开一局时。
## 主要逻辑：清空旧城市节点、旧行军队列和旧待确认订单，再生成新的城市数据和表现节点。
func _start_new_match() -> void:
	_game_over = false
	_game_started = false
	_manual_paused = false
	_overlay_mode = "start"
	_last_winner = PrototypeCityOwnerRef.NEUTRAL
	_selected_city_id = -1
	_pending_order.clear()
	_pending_order_count = 0
	_next_march_order = 0
	_production_elapsed = 0.0
	_enemy_elapsed = 0.0
	_clear_city_views()
	_marching_units.clear()
	order_dialog_layer.visible = false
	_apply_ai_profile()
	_cities = _map_generator.generate_map(9, _random, _player_count - 1)
	_spawn_city_views()
	status_label.text = "阅读说明后点击“开始游戏”。"
	hint_label.text = "蓝色是你，其他颜色是电脑势力，灰色是中立城市不产兵。"
	_refresh_view()


## 删除旧战局遗留的城市表现节点。
##
## 调用场景：新开一局前。
## 主要逻辑：释放所有城市视图节点并清空索引字典，避免场景树中残留无效节点。
func _clear_city_views() -> void:
	for city_view in _city_views.values():
		city_view.queue_free()
	_city_views.clear()


## 为当前地图中的每座城市创建对应的表现节点。
##
## 调用场景：新地图生成后。
## 主要逻辑：复制隐藏模板节点，设置城市编号和名称，并把点击信号回接到主控制器。
func _spawn_city_views() -> void:
	for city in _cities:
		var city_view = city_template.duplicate()
		city_view.visible = true
		city_view.name = "City_%d" % city.city_id
		cities_root.add_child(city_view)
		city_view.setup(city.city_id, city.name)
		city_view.city_pressed.connect(_on_city_pressed)
		_city_views[city.city_id] = city_view


## 处理玩家点击城市后的选中、下单和取消逻辑。
##
## 调用场景：城市表现节点发出 `city_pressed` 信号时。
## 主要逻辑：第一次点击只能选中己方城市；若第二次点击的是己方城市，则无论是否相邻都可打开运兵面板；
## 若点击的是敌方或中立城市，则仍然必须满足道路相邻才能进攻。
func _on_city_pressed(city_id: int) -> void:
	if _game_over or not _game_started or order_dialog_layer.visible:
		return

	var clicked_city = _cities[city_id]
	if _selected_city_id == -1:
		if clicked_city.owner != PrototypeCityOwnerRef.PLAYER:
			status_label.text = "先点蓝色己方城市。"
			_play_sfx(_error_sfx_stream)
			return
		_selected_city_id = city_id
		status_label.text = "已选中 %s。现在点击目标城市，进入出兵数量选择。" % clicked_city.name
		hint_label.text = "点己方城市可跨图运兵，点敌方或中立城市需要道路相邻。"
		_play_sfx(_select_sfx_stream)
		_refresh_view()
		return

	if _selected_city_id == city_id:
		_clear_selection_with_message("已取消选择。重新点一个蓝色城市即可。")
		return

	var source = _cities[_selected_city_id]
	if clicked_city.owner == source.owner:
		_open_order_dialog(_selected_city_id, city_id, true)
		return

	if not source.is_neighbor(city_id):
		status_label.text = "%s 和 %s 没有道路连接，请点相邻城市。" % [source.name, clicked_city.name]
		_play_sfx(_error_sfx_stream)
		return

	_open_order_dialog(_selected_city_id, city_id, false)


## 根据玩家确认的数量执行一次运兵下单。
##
## 调用场景：出兵数量对话框确认的是友军目标城市时。
## 主要逻辑：服务层先扣除源城市对应人数，再创建运兵行军单位，等到抵达时再并入目标城市。
func _execute_transfer(source_id: int, target_id: int, moving_count: int) -> void:
	var source = _cities[source_id]
	var target = _cities[target_id]
	var result: Dictionary = _battle_service.prepare_transfer(source, target, moving_count)
	_selected_city_id = -1
	status_label.text = result.get("message", "")
	hint_label.text = "运兵现在会实际行军，距离越远，到达越慢。"
	if result.get("success", false):
		_launch_marching_unit(source_id, target_id, int(result["owner"]), int(result["count"]), "transfer", true)
		_play_sfx(_transfer_sfx_stream)
	else:
		_play_sfx(_error_sfx_stream)
	_refresh_view()


## 根据玩家或敌军确认的数量执行一次进攻下单。
##
## 调用场景：玩家确认进攻数量、敌军 AI 自动选择进攻人数时。
## 主要逻辑：服务层扣除出发城市的兵力，并创建一条进攻行军；真正战斗在抵达目标城时结算。
func _execute_attack(source_id: int, target_id: int, troop_count: int, is_player_action: bool) -> void:
	var source = _cities[source_id]
	var target = _cities[target_id]
	var travel_duration: float = _calculate_march_duration(source_id, target_id)

	if troop_count <= 0 or source.soldiers <= 0:
		status_label.text = "%s 没有士兵可以出征。" % source.name
		_play_sfx(_error_sfx_stream)
		_clear_selection_with_message(status_label.text)
		return

	var result: Dictionary = _battle_service.prepare_attack(source, target, travel_duration, troop_count)
	_selected_city_id = -1
	status_label.text = result.get("message", "")
	if not result.get("success", false):
		_play_sfx(_error_sfx_stream)
		_refresh_view()
		return

	_launch_marching_unit(source_id, target_id, int(result["owner"]), int(result["count"]), "attack", is_player_action)
	if not is_player_action:
		status_label.text = "%s 行动：%s" % [PrototypeCityOwnerRef.get_owner_name(source.owner), status_label.text]
		hint_label.text = "有电脑势力已经出兵，注意观察道路上的行军单位。"
	else:
		hint_label.text = "部队已经出发。你可以继续选择其他城市。"
	_play_sfx(_attack_sfx_stream)
	_refresh_view()


## 驱动所有存活电脑 AI 势力依次选择一条攻击命令并下单。
##
## 调用场景：电脑行动定时器达到阈值时。
## 主要逻辑：扫描当前地图上仍持有城市的全部电脑势力，让每家电脑各自独立决策并执行一次进攻。
func _run_enemy_turn() -> void:
	for owner_id: int in _get_active_ai_owners():
		var decision: Dictionary = _enemy_ai_service.choose_attack(_cities, _battle_service, owner_id)
		if decision.is_empty():
			continue

		var source_id: int = int(decision["source_id"])
		var target_id: int = int(decision["target_id"])
		var troop_count: int = int(decision["troop_count"])
		_execute_attack(source_id, target_id, troop_count, false)


## 把当前城市状态和按钮状态同步到界面。
##
## 调用场景：产兵后、出兵后、行军到达后、选择变化后。
## 主要逻辑：刷新所有城市显示、高亮状态，并同步底部按钮是否可点击。
func _refresh_view() -> void:
	for city in _cities:
		var city_view = _city_views.get(city.city_id)
		if city_view != null:
			city_view.sync_from_state(city, city.city_id == _selected_city_id)
	var pause_suffix: String = " | 已暂停" if _manual_paused else ""
	ai_config_label.text = "对局：%d 方 | %s | %s%s" % [_player_count, _get_ai_difficulty_name(_ai_difficulty), _get_ai_style_name(_ai_style), pause_suffix]
	cancel_selection_button.disabled = _selected_city_id == -1 or _game_over or not _game_started or order_dialog_layer.visible or _manual_paused
	pause_button.disabled = _game_over or not _game_started
	pause_button.text = "继续" if _manual_paused else "暂停"
	queue_redraw()


## 检查当前是否已经分出胜负。
##
## 调用场景：每次行军到达并改变城市归属后。
## 主要逻辑：读取服务层的胜负判断，若有赢家则锁定战局并显示结束面板。
func _check_game_over() -> void:
	var winner: int = _battle_service.get_winner(_cities)
	if winner == PrototypeCityOwnerRef.NEUTRAL:
		return

	_game_over = true
	_last_winner = winner
	status_label.text = "%s 获胜。" % PrototypeCityOwnerRef.get_owner_name(winner)
	hint_label.text = "点击下方“重新开始”，或在面板里直接再开一局。"
	if winner == PrototypeCityOwnerRef.PLAYER:
		_play_sfx(_victory_sfx_stream)
	else:
		_play_sfx(_defeat_sfx_stream)
	_show_game_over_overlay(winner)


## 清除当前源城市选择并恢复普通提示。
##
## 调用场景：玩家主动取消选择、下单完成后恢复空闲态时。
## 主要逻辑：清空选中城市并刷新道路高亮。
func _clear_selection_with_message(message: String) -> void:
	_selected_city_id = -1
	status_label.text = message
	hint_label.text = "先点蓝色城市，再点目标城市；进攻要相邻，运兵可跨图。"
	_refresh_view()


## 打开玩家出兵数量对话框。
##
## 调用场景：玩家先选源城市，再点一个目标城市之后。
## 主要逻辑：根据目标归属决定当前是在运兵还是进攻，并显示推荐兵力、快捷按钮和确认入口。
func _open_order_dialog(source_id: int, target_id: int, is_transfer: bool) -> void:
	var source = _cities[source_id]
	var target = _cities[target_id]
	var travel_duration: float = _calculate_march_duration(source_id, target_id)
	var max_count: int = source.soldiers
	var recommended_count: int = max_count

	if is_transfer:
		order_dialog_title_label.text = "运兵数量"
		order_dialog_recommended_label.text = "运兵可自由选择人数。`100%` 表示整队输送。"
	else:
		order_dialog_title_label.text = "进攻数量"
		recommended_count = _battle_service.get_recommended_attack_count(source, target, travel_duration)
		order_dialog_recommended_label.text = "推荐 %d 人。这个数已经考虑了路上目标城可能新增的产兵。" % recommended_count

	_pending_order = {
		"source_id": source_id,
		"target_id": target_id,
		"is_transfer": is_transfer,
		"recommended_count": recommended_count
	}
	_pending_order_count = clamp(recommended_count, 1, max_count)
	order_dialog_context_label.text = "%s -> %s，当前可派 %d 人。" % [source.name, target.name, max_count]
	order_dialog_layer.visible = true
	status_label.text = "出兵面板已打开，战局已暂停。确认或取消后会继续。"
	hint_label.text = "你可以慢慢调整人数，行军、产兵和电脑 AI 会暂时停止。"
	_refresh_order_dialog()
	_refresh_view()
	_play_sfx(_select_sfx_stream)


## 刷新出兵数量对话框里的数字和按钮状态。
##
## 调用场景：打开对话框后、点击各种快捷按钮后。
## 主要逻辑：更新中央数量显示，并根据上下限禁用不合法的加减操作。
func _refresh_order_dialog() -> void:
	if _pending_order.is_empty():
		return
	var max_count: int = _get_current_order_max_count()
	_pending_order_count = clamp(_pending_order_count, 1, max_count)
	var source = _cities[int(_pending_order["source_id"])]
	var target = _cities[int(_pending_order["target_id"])]
	order_dialog_context_label.text = "%s -> %s，当前可派 %d 人。" % [source.name, target.name, max_count]
	order_dialog_count_label.text = str(_pending_order_count)
	order_dialog_minus_10_button.disabled = _pending_order_count <= 1
	order_dialog_minus_1_button.disabled = _pending_order_count <= 1
	order_dialog_plus_1_button.disabled = _pending_order_count >= max_count
	order_dialog_plus_10_button.disabled = _pending_order_count >= max_count
	order_dialog_plus_20_button.disabled = _pending_order_count >= max_count
	order_dialog_plus_50_button.disabled = _pending_order_count >= max_count
	order_dialog_confirm_button.disabled = _pending_order_count <= 0
	_refresh_order_forecast()


## 读取当前待确认订单的实时最大可派兵力。
##
## 调用场景：出兵弹窗显示期间每次刷新、点击快捷按钮、最终确认下单前。
## 主要逻辑：直接读取源城市当前兵力，而不是沿用打开弹窗时的旧值，避免产兵期间数据过期。
func _get_current_order_max_count() -> int:
	if _pending_order.is_empty():
		return 1
	var source = _cities[int(_pending_order["source_id"])]
	return max(1, source.soldiers)


## 根据当前数量选择刷新出兵弹窗中的到达预估信息。
##
## 调用场景：打开对话框后、点击任意数量快捷按钮后。
## 主要逻辑：区分运兵和进攻两种模式，分别展示预计行军时间、预计到达守军、是否占领和出发后本城剩余兵力。
func _refresh_order_forecast() -> void:
	if _pending_order.is_empty():
		return

	var source = _cities[int(_pending_order["source_id"])]
	var target = _cities[int(_pending_order["target_id"])]
	var travel_duration: float = _calculate_march_duration(source.city_id, target.city_id)
	if bool(_pending_order["is_transfer"]):
		order_dialog_forecast_label.text = "预计 %.1f 秒后到达。出发后 %s 还剩 %d 人。" % [travel_duration, source.name, source.soldiers - _pending_order_count]
		order_dialog_outcome_label.text = "预计结果：%s 会接收 %d 名援军。若途中失守，这批援军会在到达时立刻与当前守军重新交战。" % [target.name, _pending_order_count]
		return

	var preview: Dictionary = _battle_service.preview_attack_outcome(source, target, travel_duration, _pending_order_count)
	order_dialog_forecast_label.text = "%s 预计 %.1f 秒后到达；路上目标城大约会再产 %d 人，到达时预计有 %d 守军。" % [
		target.name,
		travel_duration,
		int(preview["predicted_growth"]),
		int(preview["predicted_defenders"])
	]

	if bool(preview["predicted_capture"]):
		order_dialog_outcome_label.text = "预计结果：可以占领 %s，城内预计留守 %d 人；%s 出发后还剩 %d 人。" % [
			target.name,
			int(preview["predicted_remaining"]),
			source.name,
			int(preview["source_soldiers_after_departure"])
		]
	else:
		order_dialog_outcome_label.text = "预计结果：无法占领 %s，对方大约还剩 %d 人；%s 出发后还剩 %d 人。" % [
			target.name,
			int(preview["predicted_remaining"]),
			source.name,
			int(preview["source_soldiers_after_departure"])
		]


## 对当前出兵数量做增减调整。
##
## 调用场景：点击 `-10`、`+1`、`+50` 等快捷按钮时。
## 主要逻辑：把数量限定在 1 到最大可派兵力之间，再刷新弹窗显示。
func _adjust_order_count(delta: int) -> void:
	if _pending_order.is_empty():
		return
	var max_count: int = _get_current_order_max_count()
	_pending_order_count = clamp(_pending_order_count + delta, 1, max_count)
	_refresh_order_dialog()
	_play_sfx(_select_sfx_stream)


## 把当前出兵数量设置为总兵力的一半。
##
## 调用场景：点击 `50%` 按钮时。
## 主要逻辑：按最大可派兵力的一半向上取整，保证至少出 1 人。
func _on_order_half_button_pressed() -> void:
	if _pending_order.is_empty():
		return
	var max_count: int = _get_current_order_max_count()
	_pending_order_count = max(1, int(ceil(float(max_count) * 0.5)))
	_refresh_order_dialog()
	_play_sfx(_select_sfx_stream)


## 把当前出兵数量设置为全部可派兵力。
##
## 调用场景：点击 `100%` 按钮时。
## 主要逻辑：直接采用最大可派兵力，适合全军压上或整队运兵。
func _on_order_full_button_pressed() -> void:
	if _pending_order.is_empty():
		return
	_pending_order_count = _get_current_order_max_count()
	_refresh_order_dialog()
	_play_sfx(_select_sfx_stream)


## 把当前出兵数量设置为系统推荐值。
##
## 调用场景：点击 `推荐` 按钮时。
## 主要逻辑：恢复到打开弹窗时计算出的推荐兵力，方便快速下单。
func _on_order_recommend_button_pressed() -> void:
	if _pending_order.is_empty():
		return
	_pending_order_count = int(_pending_order["recommended_count"])
	_refresh_order_dialog()
	_play_sfx(_select_sfx_stream)


## 把当前出兵数量设置为“尽量多出，但源城市留 1 人”。
##
## 调用场景：点击 `留1人` 按钮时。
## 主要逻辑：如果源城兵力大于 1，则设为 `最大值 - 1`，否则仍保持最小合法值 1。
func _on_order_keep_one_button_pressed() -> void:
	if _pending_order.is_empty():
		return
	var max_count: int = _get_current_order_max_count()
	_pending_order_count = max(1, max_count - 1)
	_refresh_order_dialog()
	_play_sfx(_select_sfx_stream)


## 取消当前出兵数量弹窗。
##
## 调用场景：点击出兵弹窗中的取消按钮时。
## 主要逻辑：关闭弹窗但保留源城市选中，让玩家可以重新点别的目标或再次打开弹窗。
func _on_order_cancel_button_pressed() -> void:
	order_dialog_layer.visible = false
	_pending_order.clear()
	status_label.text = "已取消本次出兵确认。你仍可以重新选择一个目标城市。"
	hint_label.text = "点己方城市可跨图运兵，点敌方或中立城市需要道路相邻。"
	_refresh_view()


## 确认当前出兵数量并正式创建行军单位。
##
## 调用场景：点击出兵弹窗中的确认按钮时。
## 主要逻辑：根据订单类型分别走运兵或进攻的下单流程，然后关闭弹窗并清空待处理订单。
func _on_order_confirm_button_pressed() -> void:
	if _pending_order.is_empty():
		return
	var source_id: int = int(_pending_order["source_id"])
	var target_id: int = int(_pending_order["target_id"])
	var is_transfer: bool = bool(_pending_order["is_transfer"])
	var troop_count: int = _pending_order_count
	order_dialog_layer.visible = false
	_pending_order.clear()
	if is_transfer:
		_execute_transfer(source_id, target_id, troop_count)
	else:
		_execute_attack(source_id, target_id, troop_count, true)


## 创建一条可视化行军单位并记录其发射顺序。
##
## 调用场景：玩家或敌军正式确认一条运兵/进攻命令后。
## 主要逻辑：根据城市距离计算行军时长，并记录 `launch_order` 作为同帧到达时的稳定排序依据。
func _launch_marching_unit(source_id: int, target_id: int, unit_owner: int, count: int, march_type: String, is_player_action: bool) -> void:
	var duration: float = _calculate_march_duration(source_id, target_id)
	_marching_units.append({
		"source_id": source_id,
		"target_id": target_id,
		"owner": unit_owner,
		"count": count,
		"type": march_type,
		"is_player_action": is_player_action,
		"launch_order": _next_march_order,
		"progress": 0.0,
		"duration": duration
	})
	_next_march_order += 1


## 根据两座城市之间的距离计算一次行军持续时间。
##
## 调用场景：创建运兵或进攻行军单位前。
## 主要逻辑：使用欧式距离除以行军速度，并设置最短时长避免视觉上像瞬移。
func _calculate_march_duration(source_id: int, target_id: int) -> float:
	var source = _cities[source_id]
	var target = _cities[target_id]
	var distance: float = source.position.distance_to(target.position)
	return max(0.45, distance / MARCH_SPEED)


## 推进所有行军单位，并处理路上遭遇战与最终到达结算。
##
## 调用场景：每帧 `_process` 中。
## 主要逻辑：先更新所有行军进度，再处理道路上不同势力部队的遭遇战，
## 最后把已到达单位按“进攻优先、发射顺序稳定”排序后逐条处理。
func _update_marching_units(delta: float) -> void:
	if _marching_units.is_empty():
		return

	for unit in _marching_units:
		unit["progress"] = min(1.0, float(unit["progress"]) + delta / float(unit["duration"]))

	_resolve_marching_collisions()

	var arrived_units: Array = []
	for unit in _marching_units:
		if float(unit["progress"]) >= 1.0:
			arrived_units.append(unit)

	arrived_units.sort_custom(_sort_arrived_units)

	for arrived_unit in arrived_units:
		_marching_units.erase(arrived_unit)
		_resolve_marching_unit_arrival(arrived_unit)

	queue_redraw()


## 处理道路上彼此接触的不同势力行军单位。
##
## 调用场景：每帧行军推进后、最终到达结算前。
## 主要逻辑：扫描所有不同阵营的行军单位，只要当前位置足够接近就立刻互相抵消；
## 较大兵团会减去对方人数后继续前进，若双方同归于尽则同时移除。
func _resolve_marching_collisions() -> void:
	var collision_found: bool = true
	while collision_found:
		collision_found = false
		for left_index: int in range(_marching_units.size()):
			for right_index: int in range(left_index + 1, _marching_units.size()):
				var left_unit: Dictionary = _marching_units[left_index]
				var right_unit: Dictionary = _marching_units[right_index]
				if int(left_unit["owner"]) == int(right_unit["owner"]):
					continue
				if _get_marching_unit_position(left_unit).distance_to(_get_marching_unit_position(right_unit)) > MARCH_COLLISION_DISTANCE:
					continue
				_resolve_single_marching_collision(left_index, right_index)
				collision_found = true
				break
			if collision_found:
				break


## 结算两支在道路上相遇的不同势力部队。
##
## 调用场景：检测到两支行军单位距离足够近时。
## 主要逻辑：较大兵团吞掉较小兵团并扣除相应兵力；若双方人数相同则同归于尽。
func _resolve_single_marching_collision(left_index: int, right_index: int) -> void:
	var left_unit: Dictionary = _marching_units[left_index]
	var right_unit: Dictionary = _marching_units[right_index]
	var result: Dictionary = _battle_service.resolve_marching_encounter(
		int(left_unit["owner"]),
		int(left_unit["count"]),
		int(right_unit["owner"]),
		int(right_unit["count"])
	)
	var left_owner_name: String = PrototypeCityOwnerRef.get_owner_name(int(left_unit["owner"]))
	var right_owner_name: String = PrototypeCityOwnerRef.get_owner_name(int(right_unit["owner"]))

	if result.get("both_destroyed", false):
		status_label.text = "%s 与 %s 在路上遭遇，双方 %d 人同归于尽。" % [left_owner_name, right_owner_name, int(left_unit["count"])]
		hint_label.text = "道路上的敌对部队会先互相抵消，剩余兵力才会继续前进。"
		_marching_units.remove_at(right_index)
		_marching_units.remove_at(left_index)
		_play_sfx(_attack_sfx_stream)
		return

	var winner_owner: int = int(result["winner_owner"])
	var remaining_count: int = int(result["remaining_count"])
	var surviving_unit: Dictionary = left_unit if int(left_unit["owner"]) == winner_owner else right_unit
	var surviving_index: int = left_index if int(left_unit["owner"]) == winner_owner else right_index
	surviving_unit["count"] = remaining_count
	_marching_units[surviving_index] = surviving_unit
	status_label.text = "%s 与 %s 在路上交战，%s 剩 %d 人继续前进。" % [
		left_owner_name,
		right_owner_name,
		PrototypeCityOwnerRef.get_owner_name(winner_owner),
		remaining_count
	]
	hint_label.text = "道路上的敌对部队会先互相抵消，剩余兵力才会继续前进。"
	_marching_units.remove_at(right_index if surviving_index == left_index else left_index)
	_play_sfx(_attack_sfx_stream)


## 对同一帧到达的行军单位做确定性排序。
##
## 调用场景：多支队伍在同一帧抵达时。
## 主要逻辑：优先处理进攻，再处理运兵；同类型时按发射顺序处理，避免结果依赖数组偶然顺序。
func _sort_arrived_units(left: Dictionary, right: Dictionary) -> bool:
	var left_attack: bool = left["type"] == "attack"
	var right_attack: bool = right["type"] == "attack"
	if left_attack != right_attack:
		return left_attack and not right_attack
	return int(left["launch_order"]) < int(right["launch_order"])


## 处理单条行军单位抵达终点后的实际结算。
##
## 调用场景：某支行军单位进度达到 100% 时。
## 主要逻辑：运兵会检查目标城是否已经失守；进攻会按抵达瞬间真实守军结算，并更新顶部提示。
func _resolve_marching_unit_arrival(unit: Dictionary) -> void:
	var target = _cities[int(unit["target_id"])]
	var result: Dictionary = {}

	if unit["type"] == "transfer":
		result = _battle_service.resolve_transfer_arrival(target, int(unit["owner"]), int(unit["count"]))
		status_label.text = result.get("message", "")
		if result.get("retook_after_loss", false):
			hint_label.text = "目标城曾在途中失守，但迟到援军到达后已经按实时兵力重新交战。"
			if result.get("captured", false):
				_play_sfx(_capture_sfx_stream)
			else:
				_play_sfx(_attack_sfx_stream)
		else:
			hint_label.text = "援军已经到达。继续观察道路上的行军，或再次下达命令。"
			_play_sfx(_transfer_sfx_stream)
	else:
		result = _battle_service.resolve_attack_arrival(target, int(unit["owner"]), int(unit["count"]))
		if bool(unit["is_player_action"]):
			status_label.text = result.get("message", "")
		else:
			status_label.text = "%s 到达：%s" % [PrototypeCityOwnerRef.get_owner_name(int(unit["owner"])), result.get("message", "")]

		if result.get("captured", false):
			_play_sfx(_capture_sfx_stream)
		elif result.get("reinforced", false):
			_play_sfx(_transfer_sfx_stream)
		else:
			_play_sfx(_attack_sfx_stream)

		if bool(unit["is_player_action"]):
			hint_label.text = "行军抵达后才会真正结算战斗。"
		else:
				hint_label.text = "有电脑势力行军已经抵达，注意下一波道路动向。"

	_refresh_view()
	_check_game_over()


## 计算某支行军单位当前应当绘制在道路上的位置。
##
## 调用场景：主场景重绘所有行军单位时。
## 主要逻辑：在起点和终点之间做线性插值，得到平滑移动的位置。
func _get_marching_unit_position(unit: Dictionary) -> Vector2:
	var source = _cities[int(unit["source_id"])]
	var target = _cities[int(unit["target_id"])]
	return source.position.lerp(target.position, float(unit["progress"]))


## 展示开局说明面板，并暂停战局推进。
##
## 调用场景：首次进入场景、点击重新开始后新开一局时。
## 主要逻辑：显示玩法说明和开始按钮，避免玩家在没读懂规则时就被敌军推进。
func _show_start_overlay() -> void:
	_game_started = false
	_manual_paused = false
	_overlay_mode = "start"
	overlay_layer.visible = true
	_refresh_overlay_content()
	_refresh_view()


## 展示游戏结束面板。
##
## 调用场景：任一阵营达成胜利条件时。
## 主要逻辑：根据胜者切换文案和按钮文字，并保持遮罩可见防止玩家误以为对局还在继续。
func _show_game_over_overlay(winner: int) -> void:
	_overlay_mode = "game_over"
	overlay_layer.visible = true
	_manual_paused = false
	_refresh_overlay_content(winner)
	_refresh_view()


## 处理开始/重开面板主按钮。
##
## 调用场景：点击开始游戏或重新开始按钮时。
## 主要逻辑：若当前已结束则先重建地图，再关闭遮罩并恢复正常战局推进。
func _on_overlay_action_button_pressed() -> void:
	if _overlay_mode == "game_over":
		_start_new_match()
		_show_play_state()
		return
	if _overlay_mode == "pause":
		_resume_gameplay()
		return
	_show_play_state()


## 处理底部取消选择按钮。
##
## 调用场景：玩家只想放弃当前源城市选择时。
## 主要逻辑：如果当前没有打开出兵弹窗，则直接清空源城市选择。
func _on_cancel_selection_button_pressed() -> void:
	if order_dialog_layer.visible:
		_on_order_cancel_button_pressed()
		return
	if _selected_city_id == -1:
		return
	_clear_selection_with_message("已取消选择。重新点一个蓝色城市即可。")


## 处理底部重新开始按钮。
##
## 调用场景：玩家在对局中途或结束后主动要求重新开局时。
## 主要逻辑：重建战局并重新展示说明面板，让玩家清楚地知道已进入新的一局。
func _on_restart_button_pressed() -> void:
	_start_new_match()
	_show_start_overlay()


## 切换到正式对局状态并关闭说明遮罩。
##
## 调用场景：玩家看完说明准备开始，或结束后一键再开一局时。
## 主要逻辑：隐藏说明层、更新顶部提示、启动背景音乐并恢复战局推进。
func _show_play_state() -> void:
	_game_started = true
	_manual_paused = false
	_overlay_mode = "play"
	overlay_layer.visible = false
	status_label.text = "先点蓝色城市，再点目标城市，然后在弹窗里确认出兵人数。"
	hint_label.text = "下方有“取消选择”“暂停”和“重新开始”按钮。"
	_play_sfx(_select_sfx_stream)
	_play_bgm_if_needed()
	_refresh_view()


## 初始化开始/暂停面板里的 AI 难度和风格选项。
##
## 调用场景：主场景首次进入树时。
## 主要逻辑：填充难度与风格下拉项，建立与内部配置状态的双向同步。
func _setup_ai_controls() -> void:
	overlay_ai_count_option.clear()
	for item in PLAYER_COUNT_ITEMS:
		overlay_ai_count_option.add_item(String(item["name"]))
	overlay_difficulty_option.clear()
	for item in AI_DIFFICULTY_ITEMS:
		overlay_difficulty_option.add_item(String(item["name"]))
	overlay_style_option.clear()
	for item in AI_STYLE_ITEMS:
		overlay_style_option.add_item(String(item["name"]))
	overlay_ai_count_option.item_selected.connect(_on_overlay_ai_count_selected)
	overlay_difficulty_option.item_selected.connect(_on_overlay_difficulty_selected)
	overlay_style_option.item_selected.connect(_on_overlay_style_selected)
	_select_ai_option_buttons()


## 把当前选择的 AI 难度和风格应用到服务层。
##
## 调用场景：初始化、玩家调整选项、重新开局时。
## 主要逻辑：同步服务层配置并刷新 HUD 和面板上的文字，保证显示与实际规则一致。
func _apply_ai_profile() -> void:
	_enemy_ai_service.configure(_ai_difficulty, _ai_style)
	_select_ai_option_buttons()
	_refresh_overlay_content()
	if is_node_ready():
		_refresh_view()


## 根据当前游戏状态判断战局是否处于暂停中。
##
## 调用场景：主循环推进前。
## 主要逻辑：只要是手动暂停、出兵对话框打开或其他遮罩挡住战场，就停止行军、产兵和电脑 AI。
func _is_gameplay_paused() -> bool:
	return _manual_paused or order_dialog_layer.visible or overlay_layer.visible


## 显示暂停面板并冻结战局。
##
## 调用场景：玩家点击底部暂停按钮时。
## 主要逻辑：保留当前战场状态，只打开覆盖层显示继续按钮和当前电脑设置。
func _pause_gameplay() -> void:
	if _game_over or not _game_started:
		return
	_manual_paused = true
	status_label.text = "游戏已暂停。"
	hint_label.text = "点击继续即可恢复战局。"
	_refresh_view()


## 关闭暂停面板并恢复战局推进。
##
## 调用场景：点击继续按钮时。
## 主要逻辑：隐藏遮罩并恢复主循环，让行军、产兵和 AI 从当前状态继续。
func _resume_gameplay() -> void:
	_manual_paused = false
	status_label.text = "战局已恢复。"
	hint_label.text = "继续下达命令，或再次点击暂停查看局势。"
	_refresh_view()


## 根据覆盖层模式刷新开始、暂停和结束面板的文案。
##
## 调用场景：开始新局、手动暂停、胜负结束、切换 AI 配置后。
## 主要逻辑：统一管理覆盖层的标题、正文和按钮文字，避免不同状态散落在多个函数里。
func _refresh_overlay_content(winner: int = PrototypeCityOwnerRef.NEUTRAL) -> void:
	if not is_node_ready():
		return
	if winner == PrototypeCityOwnerRef.NEUTRAL and _overlay_mode == "game_over":
		winner = _last_winner

	match _overlay_mode:
		"pause":
			overlay_settings_grid.visible = false
			overlay_title_label.text = "暂停"
			overlay_body_label.text = "战局已冻结。"
			overlay_rule_label.text = "点击下方按钮继续游戏。"
			overlay_rule_label_2.text = ""
			overlay_rule_label_3.text = ""
			overlay_action_button.text = "继续游戏"
		"game_over":
			overlay_settings_grid.visible = true
			if winner == PrototypeCityOwnerRef.PLAYER:
				overlay_title_label.text = "你赢了"
				overlay_body_label.text = "你已经拿下全部敌方城市。"
			else:
				overlay_title_label.text = "%s 获胜" % PrototypeCityOwnerRef.get_owner_name(winner)
				overlay_body_label.text = "%s 成为了地图上最后的统治者。" % PrototypeCityOwnerRef.get_owner_name(winner)
			overlay_rule_label.text = "下一局开始前，你可以切换电脑数量、难度和风格，体验不同的压迫感。"
			overlay_rule_label_2.text = "难度越高，敌军越快出手、越敢多派兵。"
			overlay_rule_label_3.text = "进攻型偏爱压制玩家，防御型会保留更多守军；多家电脑也会互相厮杀。"
			overlay_action_button.text = "重新开始"
		_:
			overlay_settings_grid.visible = true
			overlay_title_label.text = "开始游戏"
			overlay_body_label.text = "这是一个竖屏城堡攻防原型。蓝色是你，其他颜色分别代表不同电脑势力，灰色是中立城市。"
			overlay_rule_label.text = "第一步：点击你的蓝色城市。第二步：点目标城市。打别的势力要相邻，运兵可跨图。"
			overlay_rule_label_2.text = "第三步：在弹出的出兵面板里明确选择要派多少人。出兵面板打开时，战局会自动暂停。"
			overlay_rule_label_3.text = "开始前可以先选总方数、难度和风格。多个电脑势力会互相攻伐。"
			overlay_action_button.text = "开始游戏"


## 把当前 AI 选择同步到覆盖层下拉框。
##
## 调用场景：初始化 UI、读取或修改 AI 配置后。
## 主要逻辑：根据当前内部配置查找对应索引并选中，避免下拉框显示过期。
func _select_ai_option_buttons() -> void:
	if not is_node_ready():
		return
	for index in range(PLAYER_COUNT_ITEMS.size()):
		if int(PLAYER_COUNT_ITEMS[index]["id"]) == _player_count:
			overlay_ai_count_option.select(index)
			break
	for index in range(AI_DIFFICULTY_ITEMS.size()):
		if String(AI_DIFFICULTY_ITEMS[index]["id"]) == _ai_difficulty:
			overlay_difficulty_option.select(index)
			break
	for index in range(AI_STYLE_ITEMS.size()):
		if String(AI_STYLE_ITEMS[index]["id"]) == _ai_style:
			overlay_style_option.select(index)
			break


## 处理开始面板中的总方数选择变更。
##
## 调用场景：玩家切换总方数下拉框时。
## 主要逻辑：记录新的总参战方数设置；其中 1 方是玩家，其余为电脑势力。
func _on_overlay_ai_count_selected(index: int) -> void:
	_player_count = int(PLAYER_COUNT_ITEMS[index]["id"])
	_apply_ai_profile()


## 处理开始/暂停面板中的难度选择变更。
##
## 调用场景：玩家切换 AI 难度下拉框时。
## 主要逻辑：记录新的难度枚举并重新应用配置，让后续敌军决策立即使用新参数。
func _on_overlay_difficulty_selected(index: int) -> void:
	_ai_difficulty = String(AI_DIFFICULTY_ITEMS[index]["id"])
	_apply_ai_profile()


## 处理开始/暂停面板中的风格选择变更。
##
## 调用场景：玩家切换 AI 风格下拉框时。
## 主要逻辑：记录新的风格枚举并重新应用配置，让敌军偏好即时切换。
func _on_overlay_style_selected(index: int) -> void:
	_ai_style = String(AI_STYLE_ITEMS[index]["id"])
	_apply_ai_profile()


## 返回当前 AI 难度的中文展示名。
##
## 调用场景：刷新 HUD 与面板说明时。
## 主要逻辑：把内部枚举映射成玩家可理解的中文名，避免界面直接暴露英文标识。
func _get_ai_difficulty_name(difficulty: String) -> String:
	for item in AI_DIFFICULTY_ITEMS:
		if String(item["id"]) == difficulty:
			return String(item["name"])
	return "普通"


## 返回当前 AI 风格的中文展示名。
##
## 调用场景：刷新 HUD 与面板说明时。
## 主要逻辑：把内部风格枚举转换成中文展示文本。
func _get_ai_style_name(style: String) -> String:
	for item in AI_STYLE_ITEMS:
		if String(item["id"]) == style:
			return String(item["name"])
	return "进攻型"


## 返回当前地图上仍然存活的全部电脑势力编号。
##
## 调用场景：电脑行动轮询、后续统计信息展示。
## 主要逻辑：遍历所有城市，把仍持有至少一座城市的电脑阵营编号收集为稳定数组。
func _get_active_ai_owners() -> Array[int]:
	var owners: Dictionary = {}
	for city in _cities:
		if PrototypeCityOwnerRef.is_ai(city.owner):
			owners[city.owner] = true
	var owner_ids: Array[int] = []
	for owner_id in owners.keys():
		owner_ids.append(int(owner_id))
	owner_ids.sort()
	return owner_ids


## 绘制整张战场的草地与土地背景，避免地图落在默认灰底上。
##
## 调用场景：主场景每次重绘时最先执行。
## 主要逻辑：先铺一层草地底色，再绘制几块半透明土地色斑和草纹线条，让战场更像户外地表。
func _draw_battlefield_background() -> void:
	draw_rect(Rect2(Vector2.ZERO, Vector2(720.0, 1280.0)), Color(0.42, 0.58, 0.31))
	var dirt_patches: Array[Rect2] = [
		Rect2(Vector2(36.0, 180.0), Vector2(240.0, 160.0)),
		Rect2(Vector2(420.0, 250.0), Vector2(220.0, 150.0)),
		Rect2(Vector2(120.0, 640.0), Vector2(300.0, 180.0)),
		Rect2(Vector2(430.0, 910.0), Vector2(210.0, 170.0))
	]
	for patch in dirt_patches:
		draw_rect(patch, Color(0.55, 0.46, 0.28, 0.32))
	for band_index: int in range(10):
		var y: float = 90.0 + float(band_index) * 110.0
		draw_line(Vector2(0.0, y), Vector2(720.0, y + 18.0), Color(0.5, 0.66, 0.36, 0.18), 24.0, true)


## 处理底部暂停按钮。
##
## 调用场景：玩家在对局中点击暂停时。
## 主要逻辑：若当前未暂停则打开暂停面板；若已经暂停则直接恢复。
func _on_pause_button_pressed() -> void:
	if _manual_paused:
		_resume_gameplay()
		return
	_pause_gameplay()


## 初始化背景音乐和操作音效资源。
##
## 调用场景：主场景首次进入树时。
## 主要逻辑：使用代码生成短音效与简短循环旋律，避免依赖外部音频素材文件。
func _setup_audio() -> void:
	_music_stream = _create_melody_stream([262.0, 330.0, 392.0, 330.0, 440.0, 392.0, 330.0, 294.0], 0.22, 0.16)
	_select_sfx_stream = _create_tone_stream(784.0, 0.09, 0.22)
	_transfer_sfx_stream = _create_two_tone_stream(523.0, 659.0, 0.08, 0.18)
	_attack_sfx_stream = _create_two_tone_stream(392.0, 294.0, 0.07, 0.2)
	_capture_sfx_stream = _create_two_tone_stream(659.0, 988.0, 0.09, 0.22)
	_error_sfx_stream = _create_tone_stream(220.0, 0.11, 0.18)
	_victory_sfx_stream = _create_melody_stream([523.0, 659.0, 784.0, 1046.0], 0.12, 0.24)
	_defeat_sfx_stream = _create_melody_stream([392.0, 330.0, 262.0], 0.18, 0.2)
	_audio_ready = true


## 在背景音乐未播放时启动循环旋律。
##
## 调用场景：开始游戏、重开后重新进入对局。
## 主要逻辑：避免重复调用 `play()` 打断正在播放的音乐。
func _play_bgm_if_needed() -> void:
	if not _audio_ready or bgm_player.playing:
		return
	bgm_player.stream = _music_stream
	bgm_player.play()


## 背景音乐播放结束后自动续播。
##
## 调用场景：`AudioStreamPlayer.finished` 信号触发时。
## 主要逻辑：仅在对局处于进行状态时重播，避免菜单遮罩阶段持续响个不停。
func _on_bgm_finished() -> void:
	if not _game_started or _game_over:
		return
	_play_bgm_if_needed()


## 播放一段短音效流。
##
## 调用场景：所有用户操作与关键战斗反馈。
## 主要逻辑：把生成好的 WAV 流挂到 SFX 播放器上并立即播放；若音频未初始化则直接跳过。
func _play_sfx(stream: AudioStreamWAV) -> void:
	if not _audio_ready or stream == null:
		return
	sfx_player.stream = stream
	sfx_player.play()


## 生成单音短音效流。
##
## 调用场景：选择、错误等简单提示音创建时。
## 主要逻辑：把给定频率、时长和音量包装成一个只有单个音高的 WAV。
func _create_tone_stream(frequency: float, duration: float, volume: float) -> AudioStreamWAV:
	return _create_melody_stream([frequency], duration, volume)


## 生成包含两个音高的短音效流。
##
## 调用场景：运兵、进攻、占城等需要更强识别度的提示音创建时。
## 主要逻辑：按顺序拼接两个音高，形成更明显的听觉差异。
func _create_two_tone_stream(first_frequency: float, second_frequency: float, duration: float, volume: float) -> AudioStreamWAV:
	return _create_melody_stream([first_frequency, second_frequency], duration, volume)


## 根据一组音高序列生成可播放的 WAV 音频流。
##
## 调用场景：背景音乐和各类音效初始化时。
## 主要逻辑：按音符序列采样正弦波，并对每个音符做淡入淡出，避免爆音和断点杂音。
func _create_melody_stream(frequencies: Array[float], note_duration: float, volume: float) -> AudioStreamWAV:
	var sample_rate: int = 22050
	var pcm_data: PackedByteArray = PackedByteArray()

	for frequency: float in frequencies:
		var note_bytes: PackedByteArray = _append_note_bytes(frequency, note_duration, volume, sample_rate)
		pcm_data.append_array(note_bytes)

	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = sample_rate
	stream.stereo = false
	stream.data = pcm_data
	return stream


## 为单个音符生成一段 16 位 PCM 字节数据。
##
## 调用场景：旋律流构建时逐个音符调用。
## 主要逻辑：按采样率逐点生成正弦波，并在首尾加包络衰减，让短音频听感更柔和。
func _append_note_bytes(frequency: float, duration: float, volume: float, sample_rate: int) -> PackedByteArray:
	var total_samples: int = max(1, int(duration * sample_rate))
	var fade_samples: int = max(1, min(int(floor(float(total_samples) / 4.0)), int(sample_rate * 0.02)))
	var bytes: PackedByteArray = PackedByteArray()

	for sample_index: int in range(total_samples):
		var envelope: float = 1.0
		if sample_index < fade_samples:
			envelope = float(sample_index) / float(fade_samples)
		elif sample_index > total_samples - fade_samples:
			envelope = float(total_samples - sample_index) / float(fade_samples)

		var phase: float = TAU * frequency * float(sample_index) / float(sample_rate)
		var sample_value: float = sin(phase) * volume * clamp(envelope, 0.0, 1.0)
		var sample_int: int = int(clamp(sample_value, -1.0, 1.0) * 32767.0)
		var packed_sample: int = sample_int & 0xffff
		bytes.append(packed_sample & 0xff)
		bytes.append((packed_sample >> 8) & 0xff)

	return bytes
