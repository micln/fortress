extends Node2D

const PrototypeCityOwnerRef = preload("res://scripts/domain/prototype_city_owner.gd")
const PrototypePresetMapLoaderRef = preload("res://scripts/application/prototype_preset_map_loader.gd")
const PrototypeBattleServiceRef = preload("res://scripts/application/prototype_battle_service.gd")
const PrototypeEnemyAiServiceRef = preload("res://scripts/application/prototype_enemy_ai_service.gd")
const PrototypeOrderDispatchServiceRef = preload("res://scripts/application/prototype_order_dispatch_service.gd")
const PrototypeTransferArrivalServiceRef = preload("res://scripts/application/prototype_transfer_arrival_service.gd")
const PrototypeCityViewRef = preload("res://scripts/presentation/prototype_city_view.gd")
const AudioManagerRef = preload("res://scripts/presentation/audio_manager.gd")
const BackgroundRendererRef = preload("res://scripts/presentation/background_renderer.gd")
const CameraControllerRef = preload("res://scripts/presentation/camera_controller.gd")
const PrototypeMapRegistryRef = preload("res://scripts/application/prototype_map_registry.gd")
const GameStateManagerRef = preload("res://scripts/presentation/game_state_manager.gd")
const MarchControllerRef = preload("res://scripts/presentation/march_controller.gd")
const PrototypeMainInputHandlerRef = preload("res://scripts/presentation/prototype_main_input_handler.gd")
const UI_FONT: Font = preload("res://assets/fonts/NotoSansSC-Regular.otf")
const MARCH_SPEED: float = 180.0
const UNIT_RADIUS: float = 16.0
const SOLDIER_VISUAL_RADIUS: float = 16.0
const SOLDIER_VISUAL_SPACING: float = 42.0
const SOLDIER_VISUAL_LANE_OFFSET: float = 21.0
const MAX_VISUAL_SOLDIERS_PER_UNIT: int = 18
const MARCH_COLLISION_DISTANCE: float = 34.0
const NARROW_OVERLAY_BREAKPOINT: float = 520.0
const INPUT_DEBUG_LOG_ENABLED: bool = true
const GAME_DEBUG_LOG_ENABLED: bool = true
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
var _preset_map_loader = PrototypePresetMapLoaderRef.new()
var _battle_service = PrototypeBattleServiceRef.new()
var _enemy_ai_service = PrototypeEnemyAiServiceRef.new()
var _order_dispatch_service = PrototypeOrderDispatchServiceRef.new()
var _transfer_arrival_service = PrototypeTransferArrivalServiceRef.new()
var _audio_manager = AudioManagerRef.new()
var _background_renderer = BackgroundRendererRef.new()
var _camera_controller = CameraControllerRef.new()
var _game_state_manager = GameStateManagerRef.new()
var _march_controller = MarchControllerRef.new()
var _input_handler = PrototypeMainInputHandlerRef.new()
var _cities: Array = []
var _city_views: Dictionary = {}
var _marching_units: Array = []
var _selected_city_id: int = -1
var _pending_order: Dictionary = {}
var _pending_order_count: int = 0
var _pending_order_continuous_enabled: bool = false
var _continuous_dispatch_count_in_window: int = 0
var _continuous_dispatch_soldiers_in_window: int = 0
var _continuous_dispatch_window_elapsed: float = 0.0
var _continuous_dispatch_last_second_count: int = 0
var _continuous_dispatch_last_second_soldiers: int = 0
var _continuous_dispatch_counts_by_source_in_window: Dictionary = {}
var _continuous_dispatch_counts_by_source_last_second: Dictionary = {}
var _next_march_order: int = 0
var _production_elapsed: float = 0.0
var _enemy_elapsed: float = 0.0
var _game_over: bool = false
var _game_started: bool = false
var _manual_paused: bool = false
var _overlay_mode: String = "start"
var _last_winner: int = PrototypeCityOwnerRef.NEUTRAL
var _player_count: int = 5
var _ai_difficulty: String = PrototypeEnemyAiServiceRef.DIFFICULTY_EASY
var _ai_style: String = PrototypeEnemyAiServiceRef.STYLE_DEFENSIVE
var _current_map_id: String = ""
var _last_window_resize_frame: int = -1

## 输入模块状态读取：当前是否已结束对局。
func _input_is_game_over() -> bool:
	return _game_over

## 输入模块状态读取：当前是否已开始对局。
func _input_is_game_started() -> bool:
	return _game_started

## 输入模块状态读取：当前是否处于手动暂停。
func _input_is_manual_paused() -> bool:
	return _manual_paused

## 输入模块状态读取：出兵弹窗是否可见。
func _input_is_order_dialog_visible() -> bool:
	return order_dialog_layer.visible

## 输入模块状态读取：Overlay 是否可见。
func _input_is_overlay_visible() -> bool:
	return overlay_layer.visible

## 输入模块状态读取：当前选中城市 id。
func _input_get_selected_city_id() -> int:
	return _selected_city_id


## 返回当前地图偏移，供输入处理模块计算拖拽增量。
##
## 调用场景：PrototypeMainInputHandler 需要读取当前 map_offset 时。
## 主要逻辑：直接返回 CameraController 当前维护的 map_offset。
func _get_map_offset() -> Vector2:
	return _camera_controller.map_offset


## 返回当前地图缩放倍率，供输入处理模块计算滚轮或双指缩放。
##
## 调用场景：PrototypeMainInputHandler 需要读取当前 map_zoom 时。
## 主要逻辑：直接返回 CameraController 当前维护的 map_zoom。
func _get_map_zoom() -> float:
	return _camera_controller.map_zoom


## 消费当前输入事件，避免同一轮事件继续触发其他节点逻辑。
##
## 调用场景：PrototypeMainInputHandler 识别到拖拽/缩放并希望阻止后续点击语义时。
## 主要逻辑：调用 viewport 的 `set_input_as_handled()` 标记事件已处理。
func _consume_input() -> void:
	get_viewport().set_input_as_handled()

@onready var cities_root: Node2D = $Cities
@onready var bgm_player: AudioStreamPlayer = $BgmPlayer
@onready var sfx_player: AudioStreamPlayer = $SfxPlayer
@onready var city_template = $CityTemplate
@onready var ui_layer: CanvasLayer = $UILayer
@onready var top_panel: PanelContainer = $UILayer/TopPanel
@onready var top_margin: MarginContainer = $UILayer/TopPanel/Margin
@onready var top_info_column: VBoxContainer = $UILayer/TopPanel/Margin/InfoColumn
@onready var status_label: Label = $UILayer/TopPanel/Margin/InfoColumn/StatusLabel
@onready var hint_label: Label = $UILayer/TopPanel/Margin/InfoColumn/HintLabel
@onready var ai_config_label: Label = $UILayer/TopPanel/Margin/InfoColumn/AiConfigLabel
@onready var floating_upgrade_panel: PanelContainer = $UILayer/FloatingUpgradePanel
@onready var upgrade_level_button: Button = $UILayer/FloatingUpgradePanel/FloatingUpgradeMargin/FloatingUpgradeRow/LevelButton
@onready var upgrade_defense_button: Button = $UILayer/FloatingUpgradePanel/FloatingUpgradeMargin/FloatingUpgradeRow/DefenseButton
@onready var upgrade_production_button: Button = $UILayer/FloatingUpgradePanel/FloatingUpgradeMargin/FloatingUpgradeRow/ProductionButton
@onready var left_bottom_buttons: HBoxContainer = $UILayer/LeftBottomButtons
@onready var pause_button: Button = $UILayer/LeftBottomButtons/PauseButton
@onready var restart_button: Button = $UILayer/LeftBottomButtons/RestartButton
@onready var home_button: Button = $UILayer/LeftBottomButtons/HomeButton
@onready var overlay_layer: CanvasLayer = $Overlay
@onready var overlay_panel: PanelContainer = $Overlay/OverlayPanel
@onready var overlay_margin: MarginContainer = $Overlay/OverlayPanel/OverlayMargin
@onready var overlay_scroll: ScrollContainer = $Overlay/OverlayPanel/OverlayMargin/OverlayColumn/OverlayScroll
@onready var overlay_title_label: Label = $Overlay/OverlayPanel/OverlayMargin/OverlayColumn/OverlayScroll/OverlayContent/OverlayTitleLabel
@onready var overlay_body_label: Label = $Overlay/OverlayPanel/OverlayMargin/OverlayColumn/OverlayScroll/OverlayContent/OverlayBodyLabel
@onready var overlay_rule_label: Label = $Overlay/OverlayPanel/OverlayMargin/OverlayColumn/OverlayScroll/OverlayContent/RuleLabel
@onready var overlay_rule_label_2: Label = $Overlay/OverlayPanel/OverlayMargin/OverlayColumn/OverlayScroll/OverlayContent/RuleLabel2
@onready var overlay_rule_label_3: Label = $Overlay/OverlayPanel/OverlayMargin/OverlayColumn/OverlayScroll/OverlayContent/RuleLabel3
@onready var overlay_settings_grid: GridContainer = $Overlay/OverlayPanel/OverlayMargin/OverlayColumn/OverlayScroll/OverlayContent/SettingsGrid
@onready var overlay_ai_count_option: OptionButton = $Overlay/OverlayPanel/OverlayMargin/OverlayColumn/OverlayScroll/OverlayContent/SettingsGrid/AiCountOption
@onready var overlay_difficulty_option: OptionButton = $Overlay/OverlayPanel/OverlayMargin/OverlayColumn/OverlayScroll/OverlayContent/SettingsGrid/DifficultyOption
@onready var overlay_style_option: OptionButton = $Overlay/OverlayPanel/OverlayMargin/OverlayColumn/OverlayScroll/OverlayContent/SettingsGrid/StyleOption
@onready var overlay_action_button: Button = $Overlay/OverlayPanel/OverlayMargin/OverlayColumn/OverlayActionButton
@onready var map_selection_layer: CanvasLayer = $MapSelection
@onready var map_selection_panel = $MapSelection/MapSelectionPanel
@onready var order_dialog_layer: CanvasLayer = $OrderDialog
@onready var order_dialog_panel: PanelContainer = $OrderDialog/Panel
@onready var order_dialog_margin: MarginContainer = $OrderDialog/Panel/Margin
@onready var order_dialog_column: VBoxContainer = $OrderDialog/Panel/Margin/Column
@onready var order_dialog_scroll: ScrollContainer = $OrderDialog/Panel/Margin/Column/OrderScroll
@onready var order_dialog_title_label: Label = $OrderDialog/Panel/Margin/Column/OrderScroll/OrderContent/TitleLabel
@onready var order_dialog_context_label: Label = $OrderDialog/Panel/Margin/Column/OrderScroll/OrderContent/ContextLabel
@onready var order_dialog_recommended_label: Label = $OrderDialog/Panel/Margin/Column/OrderScroll/OrderContent/RecommendedLabel
@onready var order_dialog_forecast_label: Label = $OrderDialog/Panel/Margin/Column/OrderScroll/OrderContent/ForecastLabel
@onready var order_dialog_outcome_label: Label = $OrderDialog/Panel/Margin/Column/OrderScroll/OrderContent/OutcomeLabel
@onready var order_dialog_count_label: Label = $OrderDialog/Panel/Margin/Column/OrderScroll/OrderContent/CountLabel
@onready var order_dialog_content: VBoxContainer = $OrderDialog/Panel/Margin/Column/OrderScroll/OrderContent
@onready var order_dialog_adjust_row: HBoxContainer = $OrderDialog/Panel/Margin/Column/OrderScroll/OrderContent/AdjustRow
@onready var order_dialog_minus_10_button: Button = $OrderDialog/Panel/Margin/Column/OrderScroll/OrderContent/AdjustRow/Minus10Button
@onready var order_dialog_minus_1_button: Button = $OrderDialog/Panel/Margin/Column/OrderScroll/OrderContent/AdjustRow/Minus1Button
@onready var order_dialog_plus_1_button: Button = $OrderDialog/Panel/Margin/Column/OrderScroll/OrderContent/AdjustRow/Plus1Button
@onready var order_dialog_plus_10_button: Button = $OrderDialog/Panel/Margin/Column/OrderScroll/OrderContent/AdjustRow/Plus10Button
@onready var order_dialog_quick_grid: GridContainer = $OrderDialog/Panel/Margin/Column/OrderScroll/OrderContent/QuickGrid
@onready var order_dialog_plus_20_button: Button = $OrderDialog/Panel/Margin/Column/OrderScroll/OrderContent/QuickGrid/Plus20Button
@onready var order_dialog_plus_50_button: Button = $OrderDialog/Panel/Margin/Column/OrderScroll/OrderContent/QuickGrid/Plus50Button
@onready var order_dialog_half_button: Button = $OrderDialog/Panel/Margin/Column/OrderScroll/OrderContent/QuickGrid/HalfButton
@onready var order_dialog_full_button: Button = $OrderDialog/Panel/Margin/Column/OrderScroll/OrderContent/QuickGrid/FullButton
@onready var order_dialog_recommend_button: Button = $OrderDialog/Panel/Margin/Column/OrderScroll/OrderContent/QuickGrid/RecommendButton
@onready var order_dialog_keep_one_button: Button = $OrderDialog/Panel/Margin/Column/OrderScroll/OrderContent/QuickGrid/MaxKeepOneButton
@onready var order_dialog_action_row: HBoxContainer = $OrderDialog/Panel/Margin/Column/ActionRow
@onready var order_dialog_cancel_button: Button = $OrderDialog/Panel/Margin/Column/ActionRow/CancelButton
@onready var order_dialog_confirm_button: Button = $OrderDialog/Panel/Margin/Column/ActionRow/ConfirmButton
var _order_dialog_continuous_toggle: CheckButton
var _continuous_status_label: Label


## 初始化战局、音频和所有 UI 信号。
##
## 调用场景：主场景进入场景树后自动执行。
## 主要逻辑：初始化随机数与程序音频，创建一局新地图，连接常驻按钮事件，并动态挂载持续出兵 HUD。
func _set_map_zoom(next_zoom: float, anchor_screen_position: Vector2) -> void:
	_camera_controller.set_zoom(next_zoom, anchor_screen_position)


## 根据输入位置判断当前是否允许开始拖拽地图。
##
## 调用场景：鼠标按下或触摸开始时。
## 主要逻辑：覆盖层、出兵弹窗和 HUD 区域不允许触发拖拽，只在战场区记录拖拽候选。
func _can_start_map_drag(pointer_position: Vector2) -> bool:
	if _game_over or not _game_started or order_dialog_layer.visible or overlay_layer.visible:
		return false
	if left_bottom_buttons.get_global_rect().has_point(pointer_position):
		return false
	if floating_upgrade_panel.visible and floating_upgrade_panel.get_global_rect().has_point(pointer_position):
		return false
	return true


## 记录一次地图拖拽候选，等待后续移动距离判断是否真正开始拖拽。
##
## 调用场景：鼠标左键按下或单指触摸开始时。
## 主要逻辑：缓存指针种类、编号和起点，后续只有同一指针移动超过阈值才会进入拖拽态。
## 该类手势处理逻辑已迁移到 PrototypeMainInputHandler，保留文档位避免重复实现。


## 消耗一次“选城后短时间内不要立刻取消”的保护计数。
##
## 调用场景：鼠标或触摸抬起、准备执行空白取消选城前。
## 主要逻辑：城市节点完成选中后，浏览器或引擎可能继续派发同一轮触摸对应的抬起事件；
## 这里保留一个极短的保护窗口，吞掉随后的取消请求，避免移动端首点城市后立即被清空。
## 已迁移到 PrototypeMainInputHandler（_consume_selection_cancel_guard）。这里不再保留旧实现，避免重复状态。


## 打印当前全部城市的世界坐标与屏幕坐标，便于排查移动端点击命中问题。
##
## 调用场景：新地图生成并实例化城市表现节点后。
## 主要逻辑：遍历所有城市，统一输出城市编号、名字、阵营、世界坐标和当前屏幕坐标，便于与手机点击日志对照。
func _log_all_city_positions() -> void:
	if not INPUT_DEBUG_LOG_ENABLED:
		return
	for city in _cities:
		_log_input_debug("city_position", {
			"city_id": city.city_id,
			"city_name": city.name,
			"owner": city.owner,
			"world_position": city.position,
			"screen_position": _camera_controller.world_to_screen(city.position)
		})


## 统一输出输入调试日志，避免点击链路排查时日志格式混乱。
##
## 调用场景：输入事件、选城事件、取消事件以及命中测试排查时。
## 主要逻辑：把来源标签和上下文字典格式化为单行日志，方便在浏览器 Console 中按关键字搜索与对照。
func _log_input_debug(tag: String, payload: Dictionary = {}) -> void:
	if not INPUT_DEBUG_LOG_ENABLED:
		return
	print("[input-debug] ", tag, " | ", JSON.stringify(payload))


## 统一输出关键玩法流程日志，便于排查出兵、持续任务和战斗结算问题。
##
## 调用场景：关键动作发生时，例如选城、开单、注册持续任务、产兵、发兵、到达、占城和胜负结算。
## 主要逻辑：使用稳定的单行 JSON 结构打印，方便后续按标签过滤和复盘事件顺序。
func _log_game_debug(tag: String, payload: Dictionary = {}) -> void:
	if not GAME_DEBUG_LOG_ENABLED:
		return
	print("[game-debug] ", tag, " | ", JSON.stringify(payload))


## 展示开局说明面板，并暂停战局推进。
##
## 调用场景：首次进入场景、点击重新开始后新开一局时。
## 主要逻辑：显示玩法说明和开始按钮，避免玩家在没读懂规则时就被敌军推进。
func _on_home_button_pressed() -> void:
	_game_started = false
	_manual_paused = false
	overlay_layer.visible = false
	map_selection_panel.show_panel()


## 切换到正式对局状态并关闭说明遮罩。
##
## 调用场景：玩家看完说明准备开始，或结束后一键再开一局时。
## 主要逻辑：隐藏说明层、更新顶部提示、启动背景音乐并恢复战局推进。
func _setup_order_dialog_continuous_toggle() -> void:
	_order_dialog_continuous_toggle = CheckButton.new()
	_order_dialog_continuous_toggle.text = "【开启自动出兵】源城每产 1 兵就自动派 1 人（忽略数量框）"
	_order_dialog_continuous_toggle.focus_mode = Control.FOCUS_NONE
	_order_dialog_continuous_toggle.add_theme_font_size_override("font_size", 20)
	_order_dialog_continuous_toggle.add_theme_color_override("font_color", Color("f6d365"))
	_order_dialog_continuous_toggle.toggled.connect(_on_order_continuous_toggle_toggled)
	order_dialog_content.add_child(_order_dialog_continuous_toggle)
	order_dialog_content.move_child(_order_dialog_continuous_toggle, order_dialog_content.get_child_count() - 1)


## 初始化顶部“自动出兵状态条”，用于持续显示当前持续出兵是否在工作。
##
## 调用场景：主场景 `_ready()` 初始化 HUD 时。
## 主要逻辑：动态添加独立状态标签，避免被普通提示文案覆盖，持续展示路线数量与最近 1 秒的自动出兵统计。
func _setup_continuous_status_label() -> void:
	_continuous_status_label = Label.new()
	_continuous_status_label.name = "ContinuousStatusLabel"
	_continuous_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_continuous_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_continuous_status_label.add_theme_font_size_override("font_size", 14)
	_continuous_status_label.add_theme_color_override("font_color", Color("f6d365"))
	top_info_column.add_child(_continuous_status_label)
	_refresh_continuous_status_label()


## 初始化右侧持续出兵 HUD，展示当前所有进行中的任务。
##
## 调用场景：主场景 `_ready()` 初始化 HUD 时。
## 主要逻辑：在 `UILayer` 下动态创建右侧常驻面板，避免把任务列表混进临时遮罩或弹窗层。



## 刷新顶部“自动出兵状态条”文案，让玩家看见每秒是否真的在自动出兵。
##
## 调用场景：界面刷新、持续出兵注册/移除、每秒调度统计窗口滚动时。
## 主要逻辑：持续任务为空时显示关闭状态；不为空时显示路线数、最近 1 秒自动出兵次数与总兵量。
func _refresh_continuous_status_label() -> void:
	if _continuous_status_label == null:
		return
	var active_order_count: int = _order_dispatch_service.get_all_orders().size()
	if active_order_count <= 0:
		_continuous_status_label.text = "自动出兵：关闭"
		return
	_continuous_status_label.text = "自动出兵：%d 条路线 | 最近1秒 %d 次，共 %d 人" % [
		active_order_count,
		_continuous_dispatch_last_second_count,
		_continuous_dispatch_last_second_soldiers
	]


## 统计某条路线当前仍在路上的行军单位数量。
##
## 调用场景：右侧任务 HUD 刷新时。
## 主要逻辑：扫描当前全部行军单位，只统计来源和目标都完全匹配的路线，避免 HUD 把“存在任务”误写成“已经在路上”。
func _get_route_marching_unit_count(source_id: int, target_id: int) -> int:
	var count: int = 0
	for unit in _marching_units:
		if int(unit["source_id"]) != source_id:
			continue
		if int(unit["target_id"]) != target_id:
			continue
		count += 1
	return count


## 记录当前弹窗里“持续出兵”开关状态。
##
## 调用场景：玩家在出兵弹窗中手动勾选或取消勾选时。
## 主要逻辑：只更新待确认订单状态，不立即下发命令；真正生效在点击“确认出兵”之后。
func _on_order_continuous_toggle_toggled(enabled: bool) -> void:
	_pending_order_continuous_enabled = enabled


## 注册一条持续出兵任务，按“源城+目标路线”唯一键替换旧任务。
##
## 调用场景：玩家确认出兵并勾选“持续出兵”时。
## 主要逻辑：只记录路线信息；后续每次触发固定自动派 1 人，并按目标当前归属动态决定是进攻还是运兵。
func _remove_continuous_order(source_id: int, target_id: int) -> void:
	var removed: bool = _order_dispatch_service.remove_order(source_id, target_id)
	if removed:
		_log_game_debug("continuous_order_removed", {
			"source_id": source_id,
			"source_name": _cities[source_id].name if source_id >= 0 and source_id < _cities.size() else "",
			"target_id": target_id,
			"target_name": _cities[target_id].name if target_id >= 0 and target_id < _cities.size() else "",
			"removed_count": 1
		})
	_refresh_continuous_status_label()


## 每秒产兵后按“每产出 1 兵触发一次检查”规则推进持续出兵任务。
##
## 调用场景：主循环产兵 Tick（每秒一次）。
## 主要逻辑：先累计这一秒的全部产能，再按“消费 1 次产兵进度 -> 立刻尝试派 1 人”的顺序循环；
## 即使城市起手已满员，只要挂着持续任务，也会把这一秒积累出来的产能直接转成真实出兵。
func _is_gameplay_paused() -> bool:
	return _manual_paused or overlay_layer.visible


## 处理玩家在主场景上的原始输入，用于地图拖拽与基础指针跟踪。
##
## 调用场景：鼠标左键或单点触控按下时。
## 主要逻辑：这里只处理拖拽相关的按下、移动和释放；选城取消交给 `_unhandled_input()`，
## 这样城市节点一旦消费了点击，空白取消逻辑就不会再重复执行。
## 地图拖拽/缩放相关输入逻辑已迁移到 `PrototypeMainInputHandler`。
## 这里不再保留旧实现，避免出现两套手势状态机导致行为分歧。


## 处理一次释放事件对应的“空白取消选城”逻辑。
##
## 调用场景：`_unhandled_input()` 收到鼠标或触摸抬起事件时。
## 主要逻辑：先吞掉紧跟在选城后的兼容事件，再检查是否真的点在纯战场空白处；只有满足条件时才取消当前选中城市。
func _pick_city_at_position(pointer_position: Vector2) -> int:
	for city_id in _city_views.keys():
		var city_view: PrototypeCityView = _city_views[city_id]
		var hitbox_position: Vector2 = city_view.global_position + Vector2(-70.0, -44.0)
		var hitbox_size: Vector2 = Vector2(140.0, 170.0)
		var city_rect := Rect2(hitbox_position, hitbox_size)
		if city_rect.has_point(pointer_position):
			return int(city_id)
	return -1


## 判断一次点击是否应当跳过“空白取消选城”逻辑。
##
## 调用场景：主场景输入处理时。
## 主要逻辑：命中城市、浮动升级条或底部 HUD 时都不取消；只有落在纯战场空白处才视为取消选择。
func _should_ignore_selection_cancel(pointer_position: Vector2) -> bool:
	if _pick_city_at_position(pointer_position) != -1:
		return true
	if floating_upgrade_panel.visible and floating_upgrade_panel.get_global_rect().has_point(pointer_position):
		return true
	if left_bottom_buttons.get_global_rect().has_point(pointer_position):
		return true
	return false


## 显示暂停面板并冻结战局。
##
## 调用场景：玩家点击底部暂停按钮时。
## 主要逻辑：保留当前战场状态，只打开覆盖层显示继续按钮和当前电脑设置。
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
			overlay_settings_grid.visible = false
			if winner == PrototypeCityOwnerRef.PLAYER:
				overlay_title_label.text = "你赢了"
				overlay_body_label.text = "你已经拿下全部敌方城市。"
			else:
				overlay_title_label.text = "%s 获胜" % PrototypeCityOwnerRef.get_owner_name(winner)
				overlay_body_label.text = "%s 成为了地图上最后的统治者。" % PrototypeCityOwnerRef.get_owner_name(winner)
			overlay_rule_label.text = "点击下方按钮重新开始，可更换地图再战。"
			overlay_rule_label_2.text = ""
			overlay_rule_label_3.text = ""
			overlay_action_button.text = "重新开始"
		_:
			overlay_settings_grid.visible = true
			overlay_title_label.text = "开始游戏"
			overlay_body_label.text = "这是一个竖屏城堡攻防原型。蓝色是你，其他颜色分别代表不同电脑势力，灰色是中立城市。"
			overlay_rule_label.text = "第一步：点击你的蓝色城市。第二步：点目标城市。打别的势力要相邻，运兵可跨图；点空白可取消选城。"
			overlay_rule_label_2.text = "第三步：选中己方城市后，可直接在底部用驻军升级等级、防御或产能。"
			overlay_rule_label_3.text = "城市有防御、产能和等级：防御越高越难攻下，产能越高产兵越快，等级越高容量越大。"
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
## 主要逻辑：先铺一层草地底色，再叠加不规则土地色块、分段草纹和极轻氛围块；全部使用确定性世界坐标，
## 不创建独立背景节点，也不在每帧随机生成，确保背景稳定地压在道路、城市和行军单位之下。



## 处理底部暂停按钮。
##
## 调用场景：玩家在对局中点击暂停时。
## 主要逻辑：若当前未暂停则打开暂停面板；若已经暂停则直接恢复。
func _on_bgm_finished() -> void:
	if not _game_started or _game_over:
		return
	_audio_manager.play_bgm_if_needed()
