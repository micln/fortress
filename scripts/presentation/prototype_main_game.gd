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
const UI_FONT: Font = preload("res://assets/fonts/NotoSansSC-Regular.otf")
const MAP_ZOOM_STEP: float = 0.1
const MARCH_SPEED: float = 180.0
const UNIT_RADIUS: float = 16.0
const SOLDIER_VISUAL_RADIUS: float = 9.0
const SOLDIER_VISUAL_SPACING: float = 24.0
const SOLDIER_VISUAL_LANE_OFFSET: float = 12.0
const MAX_VISUAL_SOLDIERS_PER_UNIT: int = 18
const MARCH_COLLISION_DISTANCE: float = 34.0
const DRAG_START_DISTANCE: float = 18.0
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
var _is_dragging_map: bool = false
var _drag_candidate_active: bool = false
var _drag_pointer_kind: String = ""
var _drag_pointer_index: int = -1
var _drag_press_position: Vector2 = Vector2.ZERO
var _drag_last_position: Vector2 = Vector2.ZERO
var _active_touch_points: Dictionary = {}
var _is_pinching_map: bool = false
var _pinch_last_distance: float = 0.0
var _skip_selection_cancel_guard_count: int = 0

@onready var cities_root: Node2D = $Cities
@onready var bgm_player: AudioStreamPlayer = $BgmPlayer
@onready var sfx_player: AudioStreamPlayer = $SfxPlayer
@onready var city_template = $CityTemplate
@onready var ui_layer: CanvasLayer = $UILayer
@onready var top_panel: PanelContainer = $UILayer/TopPanel
@onready var top_margin: MarginContainer = $UILayer/TopPanel/Margin
@onready var top_info_column: VBoxContainer = $UILayer/TopPanel/Margin/InfoColumn
@onready var bottom_panel: PanelContainer = $UILayer/BottomPanel
@onready var bottom_margin: MarginContainer = $UILayer/BottomPanel/BottomMargin
@onready var bottom_primary_row: HBoxContainer = $UILayer/BottomPanel/BottomMargin/BottomColumn/PrimaryRow
@onready var status_label: Label = $UILayer/TopPanel/Margin/InfoColumn/StatusLabel
@onready var hint_label: Label = $UILayer/TopPanel/Margin/InfoColumn/HintLabel
@onready var ai_config_label: Label = $UILayer/TopPanel/Margin/InfoColumn/AiConfigLabel
@onready var cancel_selection_button: Button = $UILayer/BottomPanel/BottomMargin/BottomColumn/PrimaryRow/CancelSelectionButton
@onready var floating_upgrade_panel: PanelContainer = $UILayer/FloatingUpgradePanel
@onready var upgrade_level_button: Button = $UILayer/FloatingUpgradePanel/FloatingUpgradeMargin/FloatingUpgradeRow/LevelButton
@onready var upgrade_defense_button: Button = $UILayer/FloatingUpgradePanel/FloatingUpgradeMargin/FloatingUpgradeRow/DefenseButton
@onready var upgrade_production_button: Button = $UILayer/FloatingUpgradePanel/FloatingUpgradeMargin/FloatingUpgradeRow/ProductionButton
@onready var pause_button: Button = $UILayer/BottomPanel/BottomMargin/BottomColumn/PrimaryRow/PauseButton
@onready var restart_button: Button = $UILayer/BottomPanel/BottomMargin/BottomColumn/PrimaryRow/RestartButton
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
func _ready() -> void:
	_random.randomize()
	ThemeDB.fallback_font = UI_FONT
	_apply_desktop_default_landscape()
	_apply_dynamic_resolution()
	_apply_responsive_hud_layout()
	_apply_responsive_bottom_panel_layout()
	_apply_responsive_overlay_layout()
	_apply_responsive_order_dialog_layout()
	get_window().size_changed.connect(_on_window_size_changed)
	_audio_manager.setup(bgm_player, sfx_player)
	# 音频延迟到用户首次交互后再初始化（Web 平台 autoplay 限制）
	if not OS.has_feature("web"):
		_audio_manager.initialize_audio()
	_audio_manager.bgm_finished.connect(_on_bgm_finished)
	_camera_controller.setup(
		Callable(self, "_get_viewport_size"),
		Callable(self, "_is_mobile_runtime"),
		Callable(self, "_is_desktop_runtime"),
		Callable(self, "_get_top_panel_bottom")
	)
	_setup_ai_controls()
	_setup_continuous_status_label()
	_apply_ai_profile()
	cancel_selection_button.pressed.connect(_on_cancel_selection_button_pressed)
	upgrade_level_button.pressed.connect(_on_upgrade_level_button_pressed)
	upgrade_defense_button.pressed.connect(_on_upgrade_defense_button_pressed)
	upgrade_production_button.pressed.connect(_on_upgrade_production_button_pressed)
	pause_button.pressed.connect(_on_pause_button_pressed)
	restart_button.pressed.connect(_on_restart_button_pressed)
	overlay_action_button.pressed.connect(_on_overlay_action_button_pressed)
	order_dialog_layer.visible = false
	_setup_map_selection()


## 初始化地图选择逻辑并显示地图选择面板。
##
## 调用场景：主场景 `_ready()` 末尾。
## 主要逻辑：连接地图选择信号，并显示地图选择界面。
func _setup_map_selection() -> void:
	# 隐藏开始游戏 overlay，确保只显示地图选择
	overlay_layer.visible = false
	map_selection_panel.map_selected.connect(_on_map_selected)
	map_selection_panel.selection_cancelled.connect(_on_map_selection_cancelled)
	map_selection_panel.show_panel()


## 处理地图选择完成后的回调。
##
## 调用场景：地图选择面板确认选择后。
## 主要逻辑：保存选中的地图 ID，根据地图支持的方数调整玩家数量，开始新对局并直接进入游戏。
func _on_map_selected(map_id: String) -> void:
	_current_map_id = map_id
	# 根据地图支持的方数调整玩家数量
	var registry: PrototypeMapRegistry = PrototypeMapRegistryRef.get_instance()
	var map_def = registry.get_map_definition(map_id)
	if map_def != null:
		var supported_counts: Array = map_def.get_metadata().get("supported_faction_counts", [2, 3, 4, 5])
		# 如果当前玩家数量不在支持范围内，改为最大值
		if not supported_counts.has(_player_count):
			_player_count = supported_counts[-1]  # 取最大的支持方数
	_apply_ai_profile()
	_start_new_match(map_id)
	_show_play_state()


## 处理地图选择取消的回调。
##
## 调用场景：地图选择面板点击取消后。
## 主要逻辑：使用默认地图，开始新对局并直接进入游戏。
func _on_map_selection_cancelled() -> void:
	var registry: PrototypeMapRegistry = PrototypeMapRegistryRef.get_instance()
	_current_map_id = registry.get_default_map_id()
	_start_new_match(_current_map_id)
	_show_play_state()


## 响应视口尺寸变化，重新钳制地图偏移，避免横竖尺寸变动后出现可视区露空。
##
## 调用场景：窗口尺寸变化、Web 画布尺寸变化时由引擎回调。
## 主要逻辑：保持当前地图偏移尽量不变，但会重新限制到新的合法范围内，并刷新战场显示。
func _notification(what: int) -> void:
	if what != NOTIFICATION_WM_SIZE_CHANGED or not is_node_ready():
		return
	_handle_window_size_changed()


## 统一处理窗口尺寸变化时的分辨率、布局与地图尺寸刷新，避免多入口重复执行。
##
## 调用场景：`size_changed` 信号、`NOTIFICATION_WM_SIZE_CHANGED` 通知。
## 主要逻辑：同一帧只执行一次刷新链路，避免桌面拖拽窗口时重复触发导致的抖动或额外开销。
func _handle_window_size_changed() -> void:
	var current_frame: int = Engine.get_process_frames()
	if _last_window_resize_frame == current_frame:
		return
	_last_window_resize_frame = current_frame
	_apply_dynamic_resolution()
	_apply_responsive_hud_layout()
	_apply_responsive_bottom_panel_layout()
	_apply_responsive_overlay_layout()
	_apply_responsive_order_dialog_layout()
	_resize_map_world_for_viewport()
	_camera_controller.set_offset(_camera_controller.map_offset)


## 桌面端启动时默认切到窗口最大化，保留系统窗口层级但尽量扩大可视区域。
##
## 调用场景：主场景 `_ready()` 的最早阶段。
## 主要逻辑：仅在桌面平台生效，直接把窗口模式切到最大化。
func _apply_desktop_default_landscape() -> void:
	if not _is_desktop_runtime():
		return
	var window: Window = get_window()
	window.mode = Window.MODE_MAXIMIZED


## 判断当前运行是否属于桌面环境，避免把移动端/Web 强制成横屏。
##
## 调用场景：桌面横屏默认策略判断时。
## 主要逻辑：过滤掉 Web、Android、iOS 平台，剩余视为桌面运行时。
func _is_desktop_runtime() -> bool:
	if OS.has_feature("web"):
		return false
	if OS.has_feature("android"):
		return false
	if OS.has_feature("ios"):
		return false
	if DisplayServer.get_name() == "headless":
		return false
	return true


## 获取当前视口尺寸，供 CameraController 使用。
##
## 调用场景：CameraController 需要视口尺寸时。
## 主要逻辑：返回当前视口的像素尺寸。
func _get_viewport_size() -> Vector2:
	return get_viewport_rect().size


## 获取顶部面板底边偏移，供 CameraController 计算开局镜头位置。
##
## 调用场景：CameraController 计算初始偏移时。
## 主要逻辑：返回顶部面板的 offset_bottom 值，用于计算安全区。
func _get_top_panel_bottom() -> float:
	return top_panel.offset_bottom


## 按当前窗口逻辑尺寸设置内容分辨率，避免高 DPI 设备把 UI 误缩小。
##
## 调用场景：主场景启动时、窗口尺寸变化时。
## 主要逻辑：先读取窗口像素尺寸；Web 平台会按屏幕缩放因子换算为逻辑尺寸，再写入 `content_scale_size`。
func _apply_dynamic_resolution() -> void:
	var window: Window = get_window()
	var target_size: Vector2i = window.size
	if target_size.x <= 0 or target_size.y <= 0:
		return
	window.content_scale_size = _to_logical_window_size(target_size)


## 将窗口像素尺寸转换为逻辑尺寸，优先修复移动端 Web 高 DPI 下字体过小问题。
##
## 调用场景：动态分辨率写入前由 `_apply_dynamic_resolution()` 调用。
## 主要逻辑：仅在“Web + 触屏设备”时读取屏幕缩放因子并反算逻辑分辨率，桌面端保持原始像素尺寸避免黑边。
func _to_logical_window_size(pixel_size: Vector2i) -> Vector2i:
	if not OS.has_feature("web"):
		return pixel_size
	if not DisplayServer.is_touchscreen_available():
		return pixel_size

	var window: Window = get_window()
	var screen_index: int = window.current_screen
	var screen_scale: float = DisplayServer.screen_get_scale(screen_index)
	if screen_scale <= 0.0:
		screen_scale = 1.0

	var logical_width: int = maxi(int(round(float(pixel_size.x) / screen_scale)), 1)
	var logical_height: int = maxi(int(round(float(pixel_size.y) / screen_scale)), 1)
	return Vector2i(logical_width, logical_height)


## 响应窗口尺寸变化，实时刷新动态分辨率配置。
##
## 调用场景：窗口拖拽、移动端旋转、Web 画布尺寸变化时由引擎信号触发。
## 主要逻辑：把最新窗口尺寸同步到内容分辨率，确保画面持续自适应。
func _on_window_size_changed() -> void:
	_handle_window_size_changed()


## 根据当前视口尺寸扩展地图世界尺寸，避免桌面拉大窗口后露出黑边。
##
## 调用场景：窗口尺寸变化时。
## 主要逻辑：按当前视口计算目标地图尺寸，只做"扩张不收缩"，保证已有城市坐标始终有效且不被裁切。
func _resize_map_world_for_viewport() -> void:
	if _cities.is_empty():
		return
	_camera_controller.apply_viewport_change()


## 按当前视口宽度调整顶部和底部 HUD，减少移动端对主战场可视空间的占用。
##
## 调用场景：主场景初始化、窗口尺寸变化、移动端旋转后。
## 主要逻辑：精简顶部栏，使用更小的尺寸和透明背景，最大化战场可视区域。
func _apply_responsive_hud_layout() -> void:
	var viewport_size: Vector2 = get_viewport_rect().size
	var is_narrow_layout: bool = viewport_size.x <= NARROW_OVERLAY_BREAKPOINT

	if is_narrow_layout:
		# 移动端：更紧凑的顶部栏
		top_panel.offset_left = 2.0
		top_panel.offset_top = 2.0
		top_panel.offset_right = -2.0
		top_panel.offset_bottom = 44.0
		top_margin.add_theme_constant_override("margin_left", 6)
		top_margin.add_theme_constant_override("margin_top", 3)
		top_margin.add_theme_constant_override("margin_right", 6)
		top_margin.add_theme_constant_override("margin_bottom", 3)
		top_info_column.add_theme_constant_override("separation", 0)
		status_label.add_theme_font_size_override("font_size", 13)
		status_label.visible = false  # 窄屏下隐藏状态标签，只保留配置信息
		hint_label.visible = false
		ai_config_label.add_theme_font_size_override("font_size", 12)
		if _continuous_status_label != null:
			_continuous_status_label.visible = false
		return

	# 桌面端：保持较小尺寸
	top_panel.offset_left = 8.0
	top_panel.offset_top = 8.0
	top_panel.offset_right = -8.0
	top_panel.offset_bottom = 72.0
	top_margin.add_theme_constant_override("margin_left", 10)
	top_margin.add_theme_constant_override("margin_top", 6)
	top_margin.add_theme_constant_override("margin_right", 10)
	top_margin.add_theme_constant_override("margin_bottom", 6)
	top_info_column.add_theme_constant_override("separation", 2)
	status_label.add_theme_font_size_override("font_size", 16)
	status_label.visible = false  # 默认隐藏状态标签
	hint_label.visible = false
	ai_config_label.add_theme_font_size_override("font_size", 14)
	if _continuous_status_label != null:
		_continuous_status_label.visible = false


## 按当前视口宽度调整底部操作栏，使用更紧凑的布局。
##
## 调用场景：主场景初始化、窗口尺寸变化、移动端旋转后。
## 主要逻辑：精简底部按钮，使用图标或小尺寸文字按钮，最大化战场可视区域。
func _apply_responsive_bottom_panel_layout() -> void:
	var viewport_size: Vector2 = get_viewport_rect().size
	var is_narrow_layout: bool = viewport_size.x <= NARROW_OVERLAY_BREAKPOINT

	if is_narrow_layout:
		# 移动端：极简底部栏
		bottom_panel.offset_left = 2.0
		bottom_panel.offset_top = -40.0
		bottom_panel.offset_right = -2.0
		bottom_panel.offset_bottom = -2.0
		bottom_margin.add_theme_constant_override("margin_left", 4)
		bottom_margin.add_theme_constant_override("margin_top", 3)
		bottom_margin.add_theme_constant_override("margin_right", 4)
		bottom_margin.add_theme_constant_override("margin_bottom", 3)
		bottom_primary_row.add_theme_constant_override("separation", 4)
		cancel_selection_button.text = "✕"
		cancel_selection_button.custom_minimum_size = Vector2(36.0, 32.0)
		cancel_selection_button.add_theme_font_size_override("font_size", 18)
		pause_button.text = "▸"
		pause_button.custom_minimum_size = Vector2(36.0, 32.0)
		pause_button.add_theme_font_size_override("font_size", 18)
		restart_button.text = "↻"
		restart_button.custom_minimum_size = Vector2(36.0, 32.0)
		restart_button.add_theme_font_size_override("font_size", 18)
		return

	# 桌面端：紧凑布局
	bottom_panel.offset_left = 8.0
	bottom_panel.offset_top = -56.0
	bottom_panel.offset_right = -8.0
	bottom_panel.offset_bottom = -8.0
	bottom_margin.add_theme_constant_override("margin_left", 8)
	bottom_margin.add_theme_constant_override("margin_top", 6)
	bottom_margin.add_theme_constant_override("margin_right", 8)
	bottom_margin.add_theme_constant_override("margin_bottom", 6)
	bottom_primary_row.add_theme_constant_override("separation", 8)
	cancel_selection_button.text = "✕"
	cancel_selection_button.custom_minimum_size = Vector2(48.0, 38.0)
	cancel_selection_button.add_theme_font_size_override("font_size", 20)
	pause_button.text = "▸"
	pause_button.custom_minimum_size = Vector2(48.0, 38.0)
	pause_button.add_theme_font_size_override("font_size", 20)
	restart_button.text = "↻"
	restart_button.custom_minimum_size = Vector2(48.0, 38.0)
	restart_button.add_theme_font_size_override("font_size", 20)


## 按当前视口宽度调整开局弹窗布局，避免手机上被最小宽度和双列表单挤出屏幕。
##
## 调用场景：主场景初始化、窗口尺寸变化、移动端旋转后。
## 主要逻辑：窄屏下取消固定最小宽度、缩小内边距并把设置表单切成单列；同时把说明区放进滚动容器，保证底部按钮始终可见。
func _apply_responsive_overlay_layout() -> void:
	var viewport_size: Vector2 = get_viewport_rect().size
	var is_narrow_layout: bool = viewport_size.x <= NARROW_OVERLAY_BREAKPOINT

	if is_narrow_layout:
		overlay_panel.anchor_left = 0.03
		overlay_panel.anchor_right = 0.97
		overlay_panel.anchor_top = 0.08
		overlay_panel.anchor_bottom = 0.96
		overlay_panel.custom_minimum_size = Vector2(0.0, 0.0)
		overlay_margin.add_theme_constant_override("margin_left", 16)
		overlay_margin.add_theme_constant_override("margin_top", 18)
		overlay_margin.add_theme_constant_override("margin_right", 16)
		overlay_margin.add_theme_constant_override("margin_bottom", 18)
		overlay_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
		overlay_settings_grid.columns = 1
		overlay_title_label.add_theme_font_size_override("font_size", 32)
		overlay_body_label.add_theme_font_size_override("font_size", 16)
		overlay_rule_label.add_theme_font_size_override("font_size", 15)
		overlay_rule_label_2.add_theme_font_size_override("font_size", 15)
		overlay_rule_label_3.add_theme_font_size_override("font_size", 15)
		overlay_ai_count_option.add_theme_font_size_override("font_size", 18)
		overlay_difficulty_option.add_theme_font_size_override("font_size", 18)
		overlay_style_option.add_theme_font_size_override("font_size", 18)
		overlay_action_button.add_theme_font_size_override("font_size", 22)
		return

	overlay_panel.anchor_left = 0.08
	overlay_panel.anchor_right = 0.92
	overlay_panel.anchor_top = 0.12
	overlay_panel.anchor_bottom = 0.9
	overlay_panel.custom_minimum_size = Vector2(520.0, 640.0)
	overlay_margin.add_theme_constant_override("margin_left", 28)
	overlay_margin.add_theme_constant_override("margin_top", 28)
	overlay_margin.add_theme_constant_override("margin_right", 28)
	overlay_margin.add_theme_constant_override("margin_bottom", 28)
	overlay_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	overlay_settings_grid.columns = 2
	overlay_title_label.add_theme_font_size_override("font_size", 46)
	overlay_body_label.add_theme_font_size_override("font_size", 26)
	overlay_rule_label.add_theme_font_size_override("font_size", 23)
	overlay_rule_label_2.add_theme_font_size_override("font_size", 23)
	overlay_rule_label_3.add_theme_font_size_override("font_size", 23)
	overlay_ai_count_option.add_theme_font_size_override("font_size", 24)
	overlay_difficulty_option.add_theme_font_size_override("font_size", 24)
	overlay_style_option.add_theme_font_size_override("font_size", 24)
	overlay_action_button.add_theme_font_size_override("font_size", 28)


## 按当前视口宽度调整出兵弹窗布局，避免移动端横向与纵向同时超出屏幕。
##
## 调用场景：主场景初始化、窗口尺寸变化、移动端旋转后。
## 主要逻辑：窄屏下取消固定最小宽度、收紧边距和字号，把正文区放进滚动容器，并压缩加减按钮、快捷按钮与底部操作按钮尺寸。
func _apply_responsive_order_dialog_layout() -> void:
	var viewport_size: Vector2 = get_viewport_rect().size
	var is_narrow_layout: bool = viewport_size.x <= NARROW_OVERLAY_BREAKPOINT
	var quick_buttons: Array[Button] = [
		order_dialog_plus_20_button,
		order_dialog_plus_50_button,
		order_dialog_half_button,
		order_dialog_full_button,
		order_dialog_recommend_button,
		order_dialog_keep_one_button
	]
	var adjust_buttons: Array[Button] = [
		order_dialog_minus_10_button,
		order_dialog_minus_1_button,
		order_dialog_plus_1_button,
		order_dialog_plus_10_button
	]

	if is_narrow_layout:
		order_dialog_panel.anchor_left = 0.03
		order_dialog_panel.anchor_top = 0.08
		order_dialog_panel.anchor_right = 0.97
		order_dialog_panel.anchor_bottom = 0.92
		order_dialog_panel.custom_minimum_size = Vector2(0.0, 0.0)
		order_dialog_margin.add_theme_constant_override("margin_left", 14)
		order_dialog_margin.add_theme_constant_override("margin_top", 14)
		order_dialog_margin.add_theme_constant_override("margin_right", 14)
		order_dialog_margin.add_theme_constant_override("margin_bottom", 14)
		order_dialog_column.add_theme_constant_override("separation", 12)
		order_dialog_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
		order_dialog_title_label.add_theme_font_size_override("font_size", 28)
		order_dialog_context_label.add_theme_font_size_override("font_size", 16)
		order_dialog_recommended_label.add_theme_font_size_override("font_size", 14)
		order_dialog_forecast_label.add_theme_font_size_override("font_size", 14)
		order_dialog_outcome_label.add_theme_font_size_override("font_size", 16)
		order_dialog_count_label.add_theme_font_size_override("font_size", 28)
		order_dialog_adjust_row.add_theme_constant_override("separation", 8)
		order_dialog_quick_grid.columns = 2
		order_dialog_quick_grid.add_theme_constant_override("h_separation", 10)
		order_dialog_quick_grid.add_theme_constant_override("v_separation", 10)
		order_dialog_action_row.add_theme_constant_override("separation", 6)
		for button in adjust_buttons:
			button.add_theme_font_size_override("font_size", 18)
			button.custom_minimum_size = Vector2(0.0, 42.0)
		for button in quick_buttons:
			button.add_theme_font_size_override("font_size", 18)
			button.custom_minimum_size = Vector2(0.0, 42.0)
		order_dialog_cancel_button.text = "取消"
		order_dialog_cancel_button.add_theme_font_size_override("font_size", 14)
		order_dialog_cancel_button.custom_minimum_size = Vector2(64.0, 36.0)
		order_dialog_confirm_button.text = "出兵"
		order_dialog_confirm_button.add_theme_font_size_override("font_size", 14)
		order_dialog_confirm_button.custom_minimum_size = Vector2(68.0, 36.0)
		if _order_dialog_continuous_toggle != null:
			_order_dialog_continuous_toggle.add_theme_font_size_override("font_size", 14)
		return

	order_dialog_panel.anchor_left = 0.1
	order_dialog_panel.anchor_top = 0.18
	order_dialog_panel.anchor_right = 0.9
	order_dialog_panel.anchor_bottom = 0.84
	order_dialog_panel.custom_minimum_size = Vector2(500.0, 520.0)
	order_dialog_margin.add_theme_constant_override("margin_left", 24)
	order_dialog_margin.add_theme_constant_override("margin_top", 24)
	order_dialog_margin.add_theme_constant_override("margin_right", 24)
	order_dialog_margin.add_theme_constant_override("margin_bottom", 24)
	order_dialog_column.add_theme_constant_override("separation", 16)
	order_dialog_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	order_dialog_title_label.add_theme_font_size_override("font_size", 46)
	order_dialog_context_label.add_theme_font_size_override("font_size", 26)
	order_dialog_recommended_label.add_theme_font_size_override("font_size", 17)
	order_dialog_forecast_label.add_theme_font_size_override("font_size", 17)
	order_dialog_outcome_label.add_theme_font_size_override("font_size", 26)
	order_dialog_count_label.add_theme_font_size_override("font_size", 46)
	order_dialog_adjust_row.add_theme_constant_override("separation", 14)
	order_dialog_quick_grid.columns = 3
	order_dialog_quick_grid.add_theme_constant_override("h_separation", 14)
	order_dialog_quick_grid.add_theme_constant_override("v_separation", 14)
	order_dialog_action_row.add_theme_constant_override("separation", 16)
	for button in adjust_buttons:
		button.add_theme_font_size_override("font_size", 24)
		button.custom_minimum_size = Vector2(0.0, 52.0)
	order_dialog_minus_10_button.custom_minimum_size = Vector2(110.0, 52.0)
	order_dialog_minus_1_button.custom_minimum_size = Vector2(100.0, 52.0)
	order_dialog_plus_1_button.custom_minimum_size = Vector2(100.0, 52.0)
	order_dialog_plus_10_button.custom_minimum_size = Vector2(110.0, 52.0)
	for button in quick_buttons:
		button.add_theme_font_size_override("font_size", 24)
		button.custom_minimum_size = Vector2(0.0, 52.0)
	order_dialog_cancel_button.text = "取消"
	order_dialog_cancel_button.add_theme_font_size_override("font_size", 26)
	order_dialog_cancel_button.custom_minimum_size = Vector2(180.0, 58.0)
	order_dialog_confirm_button.text = "确认出兵"
	order_dialog_confirm_button.add_theme_font_size_override("font_size", 26)
	order_dialog_confirm_button.custom_minimum_size = Vector2(220.0, 58.0)
	if _order_dialog_continuous_toggle != null:
		_order_dialog_continuous_toggle.add_theme_font_size_override("font_size", 20)


## 推进战局主循环，包括行军、产兵和敌军 AI 下单。
##
## 调用场景：每帧自动执行。
## 主要逻辑：逐帧推进所有行军单位；每秒为占领城市产兵并在每次产出时驱动持续任务；敌军按周期只注册持续任务。
func _process(delta: float) -> void:
	if _game_over or not _game_started:
		return
	if _is_gameplay_paused():
		return

	_update_marching_units(delta)
	_production_elapsed += delta
	_enemy_elapsed += delta
	_continuous_dispatch_window_elapsed += delta
	if _continuous_dispatch_window_elapsed >= 1.0:
		_continuous_dispatch_window_elapsed -= 1.0
		_continuous_dispatch_last_second_count = _continuous_dispatch_count_in_window
		_continuous_dispatch_last_second_soldiers = _continuous_dispatch_soldiers_in_window
		_continuous_dispatch_counts_by_source_last_second = _continuous_dispatch_counts_by_source_in_window.duplicate(true)
		_continuous_dispatch_count_in_window = 0
		_continuous_dispatch_soldiers_in_window = 0
		_continuous_dispatch_counts_by_source_in_window.clear()
		_refresh_continuous_status_label()

	if _production_elapsed >= 1.0:
		_production_elapsed -= 1.0
		_produce_soldiers_and_dispatch_continuous_orders()
		_refresh_view()

	var enemy_turn_interval: float = _enemy_ai_service.get_turn_interval()
	if _enemy_elapsed >= enemy_turn_interval:
		_enemy_elapsed -= enemy_turn_interval
		_run_enemy_turn()


## 绘制道路高亮和所有行军单位。
##
## 调用场景：Godot 需要重绘主场景时自动调用。
## 主要逻辑：先绘制城市间道路，再把每条行军单位渲染成一串沿路线排开的士兵；
## 规则层仍按整组人数结算，但表现层不再使用单个带数字的圆点。
func _draw() -> void:
	_background_renderer.draw_background(
		self,
		_camera_controller.map_world_size,
		_camera_controller.map_offset,
		_camera_controller.map_zoom,
		func(world_pos): return _camera_controller.world_to_screen(world_pos)
	)

	for city in _cities:
		for neighbor_id: int in city.neighbors:
			if neighbor_id < city.city_id:
				continue

			var target = _cities[neighbor_id]
			var from_position: Vector2 = _camera_controller.world_to_screen(city.position)
			var target_position: Vector2 = _camera_controller.world_to_screen(target.position)
			var line_color := Color("48576a")
			var line_width: float = max(3.0, 6.0 * _camera_controller.map_zoom)
			if city.city_id == _selected_city_id or target.city_id == _selected_city_id:
				line_color = Color("f6d365")
				line_width = max(5.0, 10.0 * _camera_controller.map_zoom)

			draw_line(from_position, target_position, line_color, line_width, true)

	# 在道路上方绘制持续出兵任务的箭头
	_draw_continuous_order_arrows()

	for unit in _marching_units:
		_draw_marching_unit_as_soldiers(unit)


## 把一条行军单位渲染成沿路径排开的多个士兵图元。
##
## 调用场景：主场景 `_draw()` 绘制行军表现时。
## 主要逻辑：每支小队的队头直接取自它当前的真实世界坐标，再按自身路线方向把同队士兵向后排开；
## 不再依赖其他小队的相对名次来反推位置，避免出现回退、穿帮或跑到源城背面的渲染错误。
func _draw_marching_unit_as_soldiers(unit: Dictionary) -> void:
	var march_direction: Vector2 = Vector2(unit.get("march_direction", Vector2.RIGHT))
	if march_direction.length_squared() <= 0.0001:
		march_direction = Vector2.RIGHT
	var lane_direction: Vector2 = Vector2(-march_direction.y, march_direction.x)
	var soldier_radius: float = max(5.0,SOLDIER_VISUAL_RADIUS * _camera_controller.map_zoom)
	var soldier_spacing: float = max(10.0,SOLDIER_VISUAL_SPACING * _camera_controller.map_zoom)
	var visible_count: int = min(int(unit["count"]), MAX_VISUAL_SOLDIERS_PER_UNIT)
	var lane_offset: float = float(unit.get("visual_lane_offset", 0.0)) * _camera_controller.map_zoom
	var front_position: Vector2 = _camera_controller.world_to_screen(_get_marching_unit_position(unit)) + lane_direction * lane_offset
	var unit_color: Color = PrototypeCityOwnerRef.get_color(int(unit["owner"]))
	var outline_width: float = max(1.0, 2.0 * _camera_controller.map_zoom)
	for soldier_index: int in range(visible_count):
		var soldier_position: Vector2 = front_position - march_direction * soldier_spacing * float(soldier_index)
		draw_circle(soldier_position, soldier_radius, unit_color)
		draw_circle(soldier_position, soldier_radius, Color.WHITE, false, outline_width)


## 返回一支新小队应使用的固定横向渲染偏移。
##
## 调用场景：创建新的行军单位时。
## 主要逻辑：按发射顺序循环分配少量左右 lane，让同路线多支小队能分开看，但每支队伍的偏移一旦创建就固定，不再依赖其他小队状态。
func _get_visual_lane_offset_for_launch(launch_order: int) -> float:
	var lane_pattern: Array[float] = [0.0, 1.0, -1.0, 2.0, -2.0]
	var lane_index: int = posmod(launch_order, lane_pattern.size())
	return float(lane_pattern[lane_index]) * SOLDIER_VISUAL_LANE_OFFSET


## 重置运行时状态并生成一局新地图。
##
## 调用场景：首次进入游戏、点击重新开始、胜负结束后再开一局时。
## 主要逻辑：清空旧城市节点、旧行军队列和旧持续任务状态，再通过当前地图来源构建新的城市数据和表现节点。
func _start_new_match(map_id: String = "") -> void:
	_game_over = false
	_game_started = false
	if not map_id.is_empty():
		_current_map_id = map_id
	_manual_paused = false
	_overlay_mode = "start"
	_last_winner = PrototypeCityOwnerRef.NEUTRAL
	_selected_city_id = -1
	_pending_order.clear()
	_pending_order_count = 0
	_pending_order_continuous_enabled = true
	_order_dispatch_service.clear()
	_continuous_dispatch_count_in_window = 0
	_continuous_dispatch_soldiers_in_window = 0
	_continuous_dispatch_window_elapsed = 0.0
	_continuous_dispatch_last_second_count = 0
	_continuous_dispatch_last_second_soldiers = 0
	_continuous_dispatch_counts_by_source_in_window.clear()
	_continuous_dispatch_counts_by_source_last_second.clear()
	_next_march_order = 0
	_production_elapsed = 0.0
	_enemy_elapsed = 0.0
	_clear_city_views()
	_marching_units.clear()
	order_dialog_layer.visible = false
	_apply_ai_profile()
	_active_touch_points.clear()
	_end_pinch_zoom()
	_cancel_map_drag_state()
	var viewport_size: Vector2 = get_viewport_rect().size
	var target_world_size: Vector2 = _camera_controller.get_target_map_world_size(viewport_size)
	_camera_controller.reset_for_new_match(target_world_size)
	_cities = _preset_map_loader.build_map({
		"player_count": _player_count,
		"ai_difficulty": _ai_difficulty,
		"ai_style": _ai_style
	}, _camera_controller.map_world_size, _random, _current_map_id)
	if _cities.is_empty():
		var error_message: String = _preset_map_loader.get_last_error_message()
		status_label.text = "地图装载失败，请检查预设地图配置。"
		hint_label.text = error_message if not error_message.is_empty() else "预设地图 loader 未返回可用城市数据。"
		push_error("预设地图装载失败：%s" % hint_label.text)
		_log_game_debug("map_load_failed", {"error_message": hint_label.text})
		_refresh_view()
		return
	_camera_controller.center_map(Callable(self, "_get_first_player_city"))
	_spawn_city_views()
	_log_game_debug("match_started", {
		"player_count": _player_count,
		"ai_difficulty": _ai_difficulty,
		"ai_style": _ai_style,
		"city_count": _cities.size()
	})
	status_label.text = "阅读说明后点击“开始游戏”。"
	hint_label.text = "蓝色是你，其他颜色是电脑势力，灰色是中立城市不产兵；地图可拖拽浏览，桌面滚轮/手机双指可缩放。"
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
	_log_all_city_positions()


## 处理玩家点击城市后的选中、下单和取消逻辑。
##
## 调用场景：城市表现节点发出 `city_pressed` 信号时。
## 主要逻辑：第一次点击只能选中己方城市；第二次点击目标城市时，直接切换 `源 -> 目标` 持续任务；
## 若目标为敌方或中立城市则仍需道路相邻，若目标为己方城市则允许跨图运兵任务。
func _on_city_pressed(city_id: int) -> void:
	if _game_over or not _game_started or order_dialog_layer.visible:
		return

	_skip_selection_cancel_guard_count = 2

	var clicked_city = _cities[city_id]
	_log_input_debug("city_pressed", {
		"city_id": city_id,
		"city_name": clicked_city.name,
		"owner": clicked_city.owner,
		"selected_before": _selected_city_id,
		"screen_position": _camera_controller.world_to_screen(clicked_city.position),
		"world_position": clicked_city.position
})

	if _selected_city_id == -1:
		if clicked_city.owner != PrototypeCityOwnerRef.PLAYER:
			status_label.text = "先点蓝色己方城市。"
			_audio_manager.play_sfx_by_id("error")
			return
		_selected_city_id = city_id
		_log_game_debug("city_selected", {
			"city_id": city_id,
			"city_name": clicked_city.name,
			"owner": clicked_city.owner,
			"soldiers": clicked_city.soldiers
		})
		status_label.text = "已选中 %s。现在点击一个目标城市，直接切换持续出兵任务。" % clicked_city.name
		hint_label.text = _build_selected_city_hint(clicked_city)
		_audio_manager.play_sfx_by_id("select")
		_refresh_view()
		return
	if _selected_city_id == city_id:
		_clear_selection_with_message("已取消选择。重新点一个蓝色城市即可。")
		return

	var source = _cities[_selected_city_id]
	if clicked_city.owner != source.owner and not source.is_neighbor(city_id):
		status_label.text = "%s 和 %s 没有道路连接，请点相邻城市。" % [source.name, clicked_city.name]
		_audio_manager.play_sfx_by_id("error")
		return

	_toggle_player_continuous_order(_selected_city_id, city_id)


## 根据城市节点类型生成一条简短的战略提示文案。
##
## 调用场景：玩家首次选中己方城市，需要在顶部提示里补充节点价值时。
## 主要逻辑：普通节点不额外提示；关口、枢纽、腹地分别返回对应的轻量策略说明，避免把规则判断写死在多个 UI 分支里。
func _get_city_node_type_hint(city) -> String:
	match String(city.node_type):
		"pass":
			return "该城是关口，防御更高，适合卡住要道。"
		"hub":
			return "该城是枢纽，产能更高，值得优先争夺。"
		"heartland":
			return "该城是腹地，初始兵力更高，适合作为后方中转。"
		_:
			return ""


## 组装玩家选中己方城市后的顶部提示文案。
##
## 调用场景：首次选中己方城市时刷新 `hint_label`。
## 主要逻辑：先输出通用操作提示，再按节点类型决定是否拼接额外战略说明，避免普通节点出现多余空格或空句子。
func _build_selected_city_hint(city) -> String:
	var base_hint: String = "点己方城市可跨图运兵，点敌方或中立城市需要道路相邻；也可以直接在底部升级。"
	var node_hint: String = _get_city_node_type_hint(city)
	if node_hint.is_empty():
		return base_hint
	return "%s %s" % [base_hint, node_hint]


## 处理玩家对一条持续出兵路线的开关操作。
##
## 调用场景：玩家先选源城市，再点击任意合法目标城市时。
## 主要逻辑：不存在的路线会被注册，已存在的同路线会被关闭；注册后保留源城选中态，方便继续设置多条路线。
func _toggle_player_continuous_order(source_id: int, target_id: int) -> void:
	var source = _cities[source_id]
	var target = _cities[target_id]
	var result: Dictionary = _order_dispatch_service.toggle_continuous_order(source_id, target_id)
	var current_mode: String = "运兵" if source.owner == target.owner else "进攻"
	_log_game_debug("player_order_toggled", {
		"source_id": source_id,
		"source_name": source.name,
		"target_id": target_id,
		"target_name": target.name,
		"action": result.get("action", ""),
		"current_mode": current_mode
	})
	if String(result.get("action", "")) == "removed":
		status_label.text = "已停止持续出兵：%s -> %s。" % [source.name, target.name]
		hint_label.text = "同一路线再次点击即可重新开启；源城还能继续配置其他目标。"
	else:
		status_label.text = "已开启持续%s：%s -> %s。该城之后每产 1 兵就会自动派 1 人。" % [current_mode, source.name, target.name]
		hint_label.text = "同一路线再次点击可关闭；一个源城有多条任务时会轮流出兵。"
	_refresh_view()


## 预留一次性出兵接口，供后续扩展时接入独立 UI。
##
## 调用场景：当前版本不会进入该逻辑，只作为未来恢复一次性出兵功能的稳定扩展点。
## 主要逻辑：暂不做任何行为，避免再次把一次性出兵混进当前持续出兵主流程。
func _issue_single_shot_order(_source_id: int, _target_id: int, _troop_count: int) -> void:
	push_warning("一次性出兵暂未接入当前原型主流程。")


## 根据玩家确认的数量执行一次运兵下单。
##
## 调用场景：出兵数量对话框确认的是友军目标城市时。
## 主要逻辑：服务层先扣除源城市对应人数，再创建运兵行军单位，等到抵达时再并入目标城市。
func _execute_transfer(source_id: int, target_id: int, moving_count: int, keep_selection: bool = false, update_status_text: bool = true) -> void:
	var source = _cities[source_id]
	var target = _cities[target_id]
	var result: Dictionary = _battle_service.prepare_transfer(source, target, moving_count)
	_log_game_debug("transfer_execute", {
		"source_id": source_id,
		"source_name": source.name,
		"target_id": target_id,
		"target_name": target.name,
		"moving_count": moving_count,
		"success": result.get("success", false),
		"source_soldiers_after": source.soldiers
	})
	if not keep_selection:
		_selected_city_id = -1
	if update_status_text:
		status_label.text = result.get("message", "")
		hint_label.text = "运兵现在会实际行军，距离越远，到达越慢。"
	if result.get("success", false):
		_launch_marching_unit(source_id, target_id, int(result["owner"]), int(result["count"]), "transfer", true)
		if update_status_text:
			_audio_manager.play_sfx_by_id("transfer")
	else:
		if update_status_text:
			_audio_manager.play_sfx_by_id("error")
	_refresh_view()


## 根据玩家或敌军确认的数量执行一次进攻下单。
##
## 调用场景：玩家确认进攻数量、敌军 AI 自动选择进攻人数时。
## 主要逻辑：服务层扣除出发城市的兵力，并创建一条进攻行军；真正战斗在抵达目标城时结算。
func _execute_attack(source_id: int, target_id: int, troop_count: int, is_player_action: bool, keep_selection: bool = false, update_status_text: bool = true) -> void:
	var source = _cities[source_id]
	var target = _cities[target_id]
	var travel_duration: float = _calculate_march_duration(source_id, target_id)

	if troop_count <= 0 or source.soldiers <= 0:
		_log_game_debug("attack_execute_skipped", {
			"source_id": source_id,
			"source_name": source.name,
			"target_id": target_id,
			"target_name": target.name,
			"troop_count": troop_count,
			"source_soldiers": source.soldiers
		})
		if update_status_text:
			status_label.text = "%s 没有士兵可以出征。" % source.name
			_audio_manager.play_sfx_by_id("error")
			_clear_selection_with_message(status_label.text)
		return

	var result: Dictionary = _battle_service.prepare_attack(source, target, travel_duration, troop_count)
	_log_game_debug("attack_execute", {
		"source_id": source_id,
		"source_name": source.name,
		"target_id": target_id,
		"target_name": target.name,
		"troop_count": troop_count,
		"is_player_action": is_player_action,
		"success": result.get("success", false),
		"travel_duration": travel_duration,
		"source_soldiers_after": source.soldiers,
		"target_owner_before": target.owner
	})
	if not keep_selection:
		_selected_city_id = -1
	if update_status_text:
		status_label.text = result.get("message", "")
	if not result.get("success", false):
		if update_status_text:
			_audio_manager.play_sfx_by_id("error")
		_refresh_view()
		return

	_launch_marching_unit(source_id, target_id, int(result["owner"]), int(result["count"]), "attack", is_player_action)
	if update_status_text:
		if not is_player_action:
			status_label.text = "%s 行动：%s" % [PrototypeCityOwnerRef.get_owner_name(source.owner), status_label.text]
			hint_label.text = "有电脑势力已经出兵，注意观察道路上的行军单位。"
		else:
			hint_label.text = "部队已经出发。你可以继续选择其他城市。"
		_audio_manager.play_sfx_by_id("attack")
	_refresh_view()


## 驱动所有存活电脑 AI 势力依次选择一条攻击命令并下单。
##
## 调用场景：电脑行动定时器达到阈值时。
## 主要逻辑：扫描当前地图上仍持有城市的全部电脑势力，让每家电脑各自独立决策并注册一条持续出兵任务；
## 若暂时没有合适路线，则退回到城市升级。
func _run_enemy_turn() -> void:
	for owner_id: int in _get_active_ai_owners():
		var decision: Dictionary = _enemy_ai_service.choose_continuous_order(_cities, _battle_service, owner_id)
		if decision.is_empty():
			var upgrade_decision: Dictionary = _enemy_ai_service.choose_upgrade(_cities, _battle_service, owner_id)
			if upgrade_decision.is_empty():
				continue
			_execute_upgrade(int(upgrade_decision["city_id"]), String(upgrade_decision["upgrade_type"]), false)
			continue

		var source_id: int = int(decision["source_id"])
		var target_id: int = int(decision["target_id"])
		var ensure_result: Dictionary = _order_dispatch_service.ensure_continuous_order(source_id, target_id)
		_log_game_debug("ai_order_ensured", {
			"owner_id": owner_id,
			"owner_name": PrototypeCityOwnerRef.get_owner_name(owner_id),
			"source_id": source_id,
			"source_name": _cities[source_id].name,
			"target_id": target_id,
			"target_name": _cities[target_id].name,
			"action": ensure_result.get("action", "")
		})
		status_label.text = "%s 已部署持续路线：%s -> %s。" % [
			PrototypeCityOwnerRef.get_owner_name(owner_id),
			_cities[source_id].name,
			_cities[target_id].name
		]
		hint_label.text = "电脑势力现在和你共用同一套持续出兵规则。"
	_refresh_view()


## 把当前城市状态和按钮状态同步到界面。
##
## 调用场景：产兵后、出兵后、行军到达后、选择变化后。
## 主要逻辑：刷新所有城市显示、高亮状态，并同步底部按钮和升级按钮是否可点击。
func _refresh_view() -> void:
	for city in _cities:
		var city_view = _city_views.get(city.city_id)
		if city_view != null:
			city_view.sync_from_state(city, city.city_id == _selected_city_id, _camera_controller.world_to_screen(city.position))
	var pause_suffix: String = " | 已暂停" if _manual_paused else ""
	if get_viewport_rect().size.x <= NARROW_OVERLAY_BREAKPOINT:
		ai_config_label.text = "%d方 | %s | %s%s" % [_player_count, _get_ai_difficulty_name(_ai_difficulty), _get_ai_style_name(_ai_style), pause_suffix]
	else:
		ai_config_label.text = "对局：%d 方 | %s | %s%s" % [_player_count, _get_ai_difficulty_name(_ai_difficulty), _get_ai_style_name(_ai_style), pause_suffix]
	cancel_selection_button.disabled = _selected_city_id == -1 or _game_over or not _game_started or _manual_paused
	pause_button.disabled = _game_over or not _game_started
	pause_button.text = "继续" if _manual_paused else "暂停"
	_refresh_upgrade_buttons()
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
	_log_game_debug("game_over", {
		"winner": winner,
		"winner_name": PrototypeCityOwnerRef.get_owner_name(winner)
	})
	status_label.text = "%s 获胜。" % PrototypeCityOwnerRef.get_owner_name(winner)
	hint_label.text = "点击下方“重新开始”，或在面板里直接再开一局。"
	if winner == PrototypeCityOwnerRef.PLAYER:
		_audio_manager.play_sfx_by_id("victory")
	else:
		_audio_manager.play_sfx_by_id("defeat")
	_show_game_over_overlay(winner)


## 在城市归属发生变化时处理持续任务清理与日志记录。
##
## 调用场景：任意行军到达并导致城市换手后。
## 主要逻辑：来源城市一旦失守，就立刻取消它发出的全部持续任务；夺回后不会自动恢复旧任务。
func _handle_city_owner_changed(city_id: int, previous_owner: int, new_owner: int) -> void:
	var city = _cities[city_id]
	var removed_count: int = _order_dispatch_service.remove_orders_by_source(city_id)
	if _selected_city_id == city_id and city.owner != PrototypeCityOwnerRef.PLAYER:
		_selected_city_id = -1
	_log_game_debug("city_owner_changed", {
		"city_id": city_id,
		"city_name": city.name,
		"previous_owner": previous_owner,
		"new_owner": new_owner,
		"removed_order_count": removed_count
	})
	if removed_count <= 0:
		return
	_log_game_debug("orders_removed_by_source_loss", {
		"city_id": city_id,
		"city_name": city.name,
		"previous_owner": previous_owner,
		"new_owner": new_owner,
		"removed_order_count": removed_count
	})


## 清除当前源城市选择并恢复普通提示。
##
## 调用场景：玩家主动取消选择、下单完成后恢复空闲态时。
## 主要逻辑：清空选中城市并刷新道路高亮。
func _clear_selection_with_message(message: String) -> void:
	_selected_city_id = -1
	status_label.text = message
	hint_label.text = "先点蓝色城市，再点目标城市；进攻要相邻，运兵可跨图。"
	_refresh_view()


## 刷新浮动升级条的状态、成本文案和屏幕位置。
##
## 调用场景：选中变化、城市升级后、开局与重开后。
## 主要逻辑：只有选中己方城市时才在城边显示升级入口；按钮文案直接展示升级成本，
## 并把整个面板钳制在屏幕内，避免贴边城市导致按钮飞出可视区域。
func _refresh_upgrade_buttons() -> void:
	if _selected_city_id == -1 or _game_over or not _game_started or order_dialog_layer.visible or _manual_paused:
		floating_upgrade_panel.visible = false
		upgrade_level_button.disabled = true
		upgrade_defense_button.disabled = true
		upgrade_production_button.disabled = true
		upgrade_level_button.text = "升级"
		upgrade_defense_button.text = "升防"
		upgrade_production_button.text = "升产"
		return

	var city = _cities[_selected_city_id]
	if city.owner != PrototypeCityOwnerRef.PLAYER:
		floating_upgrade_panel.visible = false
		upgrade_level_button.disabled = true
		upgrade_defense_button.disabled = true
		upgrade_production_button.disabled = true
		return

	var options: Dictionary = _battle_service.get_city_upgrade_options(city)
	_apply_upgrade_button_state(upgrade_level_button, city, options[PrototypeBattleServiceRef.UPGRADE_LEVEL], "升级")
	_apply_upgrade_button_state(upgrade_defense_button, city, options[PrototypeBattleServiceRef.UPGRADE_DEFENSE], "升防")
	_apply_upgrade_button_state(upgrade_production_button, city, options[PrototypeBattleServiceRef.UPGRADE_PRODUCTION], "升产")
	_position_floating_upgrade_panel(_camera_controller.world_to_screen(city.position))
	floating_upgrade_panel.visible = true


## 根据被选城市的位置摆放浮动升级条。
##
## 调用场景：刷新升级按钮时。
## 主要逻辑：把面板放在城市右侧，使用更紧凑的尺寸。
func _position_floating_upgrade_panel(city_position: Vector2) -> void:
	var panel_size: Vector2 = floating_upgrade_panel.size
	if panel_size == Vector2.ZERO:
		panel_size = Vector2(180.0, 42.0)
	var viewport_size: Vector2 = get_viewport_rect().size
	var visible_rect := Rect2(Vector2.ZERO, viewport_size)
	if not visible_rect.grow(60.0).has_point(city_position):
		floating_upgrade_panel.visible = false
		return
	var desired_position := city_position + Vector2(45.0, -22.0)
	var clamped_x: float = clamp(desired_position.x, 10.0, viewport_size.x - panel_size.x - 10.0)
	var clamped_y: float = clamp(desired_position.y, 80.0, viewport_size.y - panel_size.y - 50.0)
	floating_upgrade_panel.position = Vector2(clamped_x, clamped_y)


## 按一条升级选项配置刷新单个按钮状态。
##
## 调用场景：升级按钮整体刷新时。
## 主要逻辑：可升级时展示“名称-成本”，已满时展示“已满”；士兵不足时保留成本但禁用按钮。
func _apply_upgrade_button_state(button: Button, city, option: Dictionary, fallback_label: String) -> void:
	var available: bool = bool(option.get("available", false))
	var cost: int = int(option.get("cost", 0))
	button.text = "%s-%d" % [fallback_label, cost] if available else "%s已满" % fallback_label
	button.disabled = not available or city.soldiers < cost


## 执行一次城市升级，并更新提示与视图。
##
## 调用场景：玩家点击底部升级按钮、AI 决定优先养城时。
## 主要逻辑：升级结算交给应用层；表现层只负责展示结果、保留当前选中和刷新 UI。
func _execute_upgrade(city_id: int, upgrade_type: String, is_player_action: bool) -> void:
	var city = _cities[city_id]
	var result: Dictionary = _battle_service.upgrade_city(city, upgrade_type)
	_log_game_debug("upgrade_execute", {
		"city_id": city_id,
		"city_name": city.name,
		"upgrade_type": upgrade_type,
		"is_player_action": is_player_action,
		"success": result.get("success", false),
		"soldiers_after": city.soldiers
	})
	status_label.text = result.get("message", "")
	if bool(result.get("success", false)):
		if is_player_action:
			hint_label.text = "升级已完成。你可以继续升城，或点目标城市发起行动。"
		else:
			hint_label.text = "%s 正在经营后方城市，准备下一轮行动。" % PrototypeCityOwnerRef.get_owner_name(city.owner)
		_audio_manager.play_sfx_by_id("capture")
	else:
		if is_player_action:
			hint_label.text = "升级会直接消耗城内士兵，升完后本城会暂时更空。"
		_audio_manager.play_sfx_by_id("error")
	_refresh_view()


## 打开玩家出兵数量对话框。
##
## 调用场景：玩家先选源城市，再点一个目标城市之后。
## 主要逻辑：根据目标归属决定当前是在运兵还是进攻，并显示推荐兵力、目标防御/产能信息、快捷按钮和确认入口。
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
		order_dialog_recommended_label.text = "推荐 %d 人。已计入目标防御 %d 和路上可能新增的产兵。" % [recommended_count, target.defense]

	_pending_order = {
		"source_id": source_id,
		"target_id": target_id,
		"is_transfer": is_transfer,
		"recommended_count": recommended_count
	}
	_pending_order_continuous_enabled = true
	_log_game_debug("order_dialog_opened", {
		"source_id": source_id,
		"source_name": source.name,
		"target_id": target_id,
		"target_name": target.name,
		"is_transfer": is_transfer,
		"recommended_count": recommended_count,
		"source_soldiers": source.soldiers
	})
	_pending_order_count = clamp(recommended_count, 1, max_count)
	order_dialog_context_label.text = "%s -> %s，当前可派 %d 人。点空白可取消选城。" % [source.name, target.name, max_count]
	order_dialog_layer.visible = true
	status_label.text = "出兵面板已打开，战局已暂停。确认或取消后会继续。"
	hint_label.text = "你可以慢慢调整人数，行军、产兵和电脑 AI 会暂时停止。"
	_refresh_order_dialog()
	_refresh_view()
	_audio_manager.play_sfx_by_id("select")


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
	order_dialog_context_label.text = "%s -> %s，当前可派 %d 人。点空白可取消选城。" % [source.name, target.name, max_count]
	order_dialog_count_label.text = str(_pending_order_count)
	order_dialog_minus_10_button.disabled = _pending_order_count <= 1
	order_dialog_minus_1_button.disabled = _pending_order_count <= 1
	order_dialog_plus_1_button.disabled = _pending_order_count >= max_count
	order_dialog_plus_10_button.disabled = _pending_order_count >= max_count
	order_dialog_plus_20_button.disabled = _pending_order_count >= max_count
	order_dialog_plus_50_button.disabled = _pending_order_count >= max_count
	order_dialog_confirm_button.disabled = _pending_order_count <= 0
	if _order_dialog_continuous_toggle != null:
		_order_dialog_continuous_toggle.button_pressed = _pending_order_continuous_enabled
		_order_dialog_continuous_toggle.text = "【开启自动出兵】源城每产 1 兵就自动派 1 人（忽略数量框）"
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
## 主要逻辑：区分运兵和进攻两种模式，分别展示预计行军时间、目标防御/产能、预计到达守军、是否占领和出发后本城剩余兵力。
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
	order_dialog_forecast_label.text = "%s 预计 %.1f 秒后到达；目标防御 %d，产能 %.1f/秒，路上大约再产 %d 人，到达时等效防守约 %d。" % [
		target.name,
		travel_duration,
		int(preview["predicted_defense_bonus"]),
		target.production_rate,
		int(preview["predicted_growth"]),
		int(preview["predicted_effective_defenders"])
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
	_audio_manager.play_sfx_by_id("select")


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
	_audio_manager.play_sfx_by_id("select")


## 把当前出兵数量设置为全部可派兵力。
##
## 调用场景：点击 `100%` 按钮时。
## 主要逻辑：直接采用最大可派兵力，适合全军压上或整队运兵。
func _on_order_full_button_pressed() -> void:
	if _pending_order.is_empty():
		return
	_pending_order_count = _get_current_order_max_count()
	_refresh_order_dialog()
	_audio_manager.play_sfx_by_id("select")


## 把当前出兵数量设置为系统推荐值。
##
## 调用场景：点击 `推荐` 按钮时。
## 主要逻辑：恢复到打开弹窗时计算出的推荐兵力，方便快速下单。
func _on_order_recommend_button_pressed() -> void:
	if _pending_order.is_empty():
		return
	_pending_order_count = int(_pending_order["recommended_count"])
	_refresh_order_dialog()
	_audio_manager.play_sfx_by_id("select")


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
	_audio_manager.play_sfx_by_id("select")


## 取消当前出兵数量弹窗。
##
## 调用场景：点击出兵弹窗中的取消按钮时。
## 主要逻辑：关闭弹窗但保留源城市选中，让玩家可以重新点别的目标或再次打开弹窗。
func _on_order_cancel_button_pressed() -> void:
	order_dialog_layer.visible = false
	_pending_order.clear()
	_pending_order_continuous_enabled = false
	_log_game_debug("order_dialog_cancelled", {})
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
	var enable_continuous_order: bool = _pending_order_continuous_enabled
	order_dialog_layer.visible = false
	_pending_order.clear()
	_pending_order_continuous_enabled = false
	_log_game_debug("order_dialog_confirmed", {
		"source_id": source_id,
		"source_name": _cities[source_id].name,
		"target_id": target_id,
		"target_name": _cities[target_id].name,
		"is_transfer": is_transfer,
		"troop_count": troop_count,
		"enable_continuous_order": enable_continuous_order
	})
	if enable_continuous_order:
		_register_continuous_order(source_id, target_id)
		status_label.text = "已注册持续出兵任务，后续仅按产兵触发自动派 1 人。"
		hint_label.text = "数量框只影响一次性出兵；持续出兵不会读取该数值。"
		_refresh_view()
	else:
		_remove_continuous_order(source_id, target_id)
		if is_transfer:
			_execute_transfer(source_id, target_id, troop_count)
		else:
			_execute_attack(source_id, target_id, troop_count, true)


## 创建一条可视化行军单位并记录其发射顺序。
##
## 调用场景：玩家或敌军正式确认一条运兵/进攻命令后。
## 主要逻辑：根据源城和目标城计算这支小队自己的方向向量、总路程与当前位置；
## 小队从源城市坐标出发，后续只沿自己的方向前进，位置不再依赖别的队伍。
func _launch_marching_unit(source_id: int, target_id: int, unit_owner: int, count: int, march_type: String, is_player_action: bool) -> void:
	var source = _cities[source_id]
	var target = _cities[target_id]
	var travel_vector: Vector2 = target.position - source.position
	var travel_distance: float = max(0.001, travel_vector.length())
	var duration: float = max(0.45, travel_distance / MARCH_SPEED)
	var march_direction: Vector2 = travel_vector / travel_distance
	var visual_lane_offset: float = _get_visual_lane_offset_for_launch(_next_march_order)

	_log_game_debug("march_launched", {
		"source_id": source_id,
		"target_id": target_id,
		"unit_owner": unit_owner,
		"count": count,
		"march_type": march_type,
		"is_player_action": is_player_action,
		"duration": duration,
		"travel_distance": travel_distance,
		"march_direction": march_direction,
		"visual_lane_offset": visual_lane_offset
	})
	_marching_units.append({
		"source_id": source_id,
		"target_id": target_id,
		"owner": unit_owner,
		"count": count,
		"type": march_type,
		"is_player_action": is_player_action,
		"launch_order": _next_march_order,
		"current_position": source.position,
		"march_direction": march_direction,
		"travel_distance": travel_distance,
		"traveled_distance": 0.0,
		"visual_lane_offset": visual_lane_offset,
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
## 主要逻辑：先根据各自方向向量更新所有行军单位的真实位置，再处理道路上不同势力部队的遭遇战，
## 最后把已到达单位按“进攻优先、发射顺序稳定”排序后逐条处理。
func _update_marching_units(delta: float) -> void:
	if _marching_units.is_empty():
		return

	for unit in _marching_units:
		var next_traveled_distance: float = min(
			float(unit["travel_distance"]),
			float(unit["traveled_distance"]) + MARCH_SPEED * delta
		)
		unit["traveled_distance"] = next_traveled_distance
		unit["progress"] = next_traveled_distance / float(unit["travel_distance"])
		unit["current_position"] = _cities[int(unit["source_id"])].position + Vector2(unit["march_direction"]) * next_traveled_distance

	_resolve_marching_collisions()

	var arrived_units: Array = []
	for unit in _marching_units:
		if float(unit["traveled_distance"]) >= float(unit["travel_distance"]) - 0.001:
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
		_log_game_debug("march_collision", {
			"left_owner": int(left_unit["owner"]),
			"right_owner": int(right_unit["owner"]),
			"left_count": int(left_unit["count"]),
			"right_count": int(right_unit["count"]),
			"both_destroyed": true
		})
		status_label.text = "%s 与 %s 在路上遭遇，双方 %d 人同归于尽。" % [left_owner_name, right_owner_name, int(left_unit["count"])]
		hint_label.text = "道路上的敌对部队会先互相抵消，剩余兵力才会继续前进。"
		_marching_units.remove_at(right_index)
		_marching_units.remove_at(left_index)
		_audio_manager.play_sfx_by_id("attack")
		return

	var winner_owner: int = int(result["winner_owner"])
	var remaining_count: int = int(result["remaining_count"])
	var surviving_unit: Dictionary = left_unit if int(left_unit["owner"]) == winner_owner else right_unit
	var surviving_index: int = left_index if int(left_unit["owner"]) == winner_owner else right_index
	surviving_unit["count"] = remaining_count
	_marching_units[surviving_index] = surviving_unit
	_log_game_debug("march_collision", {
		"left_owner": int(left_unit["owner"]),
		"right_owner": int(right_unit["owner"]),
		"left_count": int(left_unit["count"]),
		"right_count": int(right_unit["count"]),
		"both_destroyed": false,
		"winner_owner": winner_owner,
		"remaining_count": remaining_count
	})
	status_label.text = "%s 与 %s 在路上交战，%s 剩 %d 人继续前进。" % [
		left_owner_name,
		right_owner_name,
		PrototypeCityOwnerRef.get_owner_name(winner_owner),
		remaining_count
	]
	hint_label.text = "道路上的敌对部队会先互相抵消，剩余兵力才会继续前进。"
	_marching_units.remove_at(right_index if surviving_index == left_index else left_index)
	_audio_manager.play_sfx_by_id("attack")


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
	var owner_before_arrival: int = target.owner
	var result: Dictionary = {}

	if unit["type"] == "transfer":
		if target.owner == int(unit["owner"]):
			result = _transfer_arrival_service.resolve_friendly_transfer_arrival(
				target,
				int(unit["count"]),
				Callable(self, "_dispatch_continuous_order_for_arrival_source").bind(target.city_id)
			)
		else:
			result = _battle_service.resolve_transfer_arrival(target, int(unit["owner"]), int(unit["count"]))
		_log_game_debug("march_arrival_transfer", {
			"target_id": int(unit["target_id"]),
			"target_name": target.name,
			"owner": int(unit["owner"]),
			"count": int(unit["count"]),
			"captured": result.get("captured", false),
			"retook_after_loss": result.get("retook_after_loss", false),
			"received_count": result.get("received_count", 0),
			"forwarded_count": result.get("forwarded_count", 0),
			"overflow_count": result.get("overflow_count", 0),
			"target_owner_after": target.owner,
			"target_soldiers_after": target.soldiers
		})
		status_label.text = result.get("message", "")
		if result.get("retook_after_loss", false):
			hint_label.text = "目标城曾在途中失守，但迟到援军到达后已经按实时兵力重新交战。"
			if result.get("captured", false):
				_audio_manager.play_sfx_by_id("capture")
			else:
				_audio_manager.play_sfx_by_id("attack")
		else:
			hint_label.text = "援军已经到达。继续观察道路上的行军，或再次下达命令。"
			_audio_manager.play_sfx_by_id("transfer")
	else:
		result = _battle_service.resolve_attack_arrival(target, int(unit["owner"]), int(unit["count"]))
		_log_game_debug("march_arrival_attack", {
			"target_id": int(unit["target_id"]),
			"target_name": target.name,
			"owner": int(unit["owner"]),
			"count": int(unit["count"]),
			"captured": result.get("captured", false),
			"reinforced": result.get("reinforced", false),
			"target_owner_after": target.owner,
			"target_soldiers_after": target.soldiers
		})
		if bool(unit["is_player_action"]):
			status_label.text = result.get("message", "")
		else:
			status_label.text = "%s 到达：%s" % [PrototypeCityOwnerRef.get_owner_name(int(unit["owner"])), result.get("message", "")]

		if result.get("captured", false):
			_audio_manager.play_sfx_by_id("capture")
		elif result.get("reinforced", false):
			_audio_manager.play_sfx_by_id("transfer")
		else:
			_audio_manager.play_sfx_by_id("attack")

		if bool(unit["is_player_action"]):
			hint_label.text = "行军抵达后才会真正结算战斗。"
		else:
			hint_label.text = "有电脑势力行军已经抵达，注意下一波道路动向。"

	if owner_before_arrival != target.owner:
		_handle_city_owner_changed(target.city_id, owner_before_arrival, target.owner)
	_refresh_view()
	_check_game_over()


## 把“到达 1 名友军援兵”转换成一次指定源城的持续调度尝试。
##
## 调用场景：友军运兵逐兵到达结算时，交给 `PrototypeTransferArrivalService` 回调触发。
## 主要逻辑：复用现有持续出兵调度链，但把触发来源显式绑定到当前接收援军的城市，避免闭包捕获带来不稳定行为。
func _dispatch_continuous_order_for_arrival_source(source_id: int) -> bool:
	return _dispatch_continuous_orders_for_source(source_id)


## 绘制所有持续出兵任务道路上的流动箭头。
##
## 调用场景：主场景 `_draw()` 绘制道路后。
## 主要逻辑：在有持续出兵任务的道路上绘制指向目标城市的流动箭头，箭头颜色对应源城阵营。
func _draw_continuous_order_arrows() -> void:
	var orders: Array[Dictionary] = _order_dispatch_service.get_all_orders()
	if orders.is_empty():
		return

	var time_based_offset: float = float(Time.get_ticks_msec() % 5000) / 5000.0

	for order in orders:
		var source_id: int = int(order["source_id"])
		var target_id: int = int(order["target_id"])
		if source_id < 0 or source_id >= _cities.size() or target_id < 0 or target_id >= _cities.size():
			continue

		var source = _cities[source_id]
		var target = _cities[target_id]
		var from_position: Vector2 = _camera_controller.world_to_screen(source.position)
		var to_position: Vector2 = _camera_controller.world_to_screen(target.position)
		var direction: Vector2 = (to_position - from_position).normalized()
		var distance: float = from_position.distance_to(to_position)

		# 根据距离计算箭头数量
		var arrow_spacing: float = 80.0 * _camera_controller.map_zoom
		var arrow_count: int = max(1, int(distance / arrow_spacing))

		var owner_color: Color = PrototypeCityOwnerRef.get_color(source.owner)
		var arrow_size: float = max(6.0, 10.0 * _camera_controller.map_zoom)

		for i in range(arrow_count):
			# 流动效果：基于时间的偏移
			var t: float = (float(i) / arrow_count + time_based_offset)
			if t > 1.0:
				t -= 1.0

			var arrow_center: Vector2 = from_position + direction * distance * t
			_draw_arrow(arrow_center, direction, arrow_size, owner_color)


## 在指定位置绘制一个指向特定方向的箭头。
##
## 调用场景：`_draw_continuous_order_arrows()` 需要绘制单个箭头时。
## 主要逻辑：根据中心位置、方向和大小绘制三角形箭头。
func _draw_arrow(center: Vector2, direction: Vector2, size: float, color: Color) -> void:
	var perpendicular: Vector2 = Vector2(-direction.y, direction.x)
	var points: PackedVector2Array = PackedVector2Array([
		center + direction * size,
		center - direction * size * 0.5 + perpendicular * size * 0.5,
		center - direction * size * 0.5 - perpendicular * size * 0.5
	])
	draw_colored_polygon(points, color)


## 计算某支行军单位当前应当绘制在道路上的位置。
##
## 调用场景：主场景重绘所有行军单位时。
## 主要逻辑：直接返回这支小队当前维护的真实世界坐标；若旧数据缺失，则回退到源城坐标，避免绘制阶段崩溃。
func _get_marching_unit_position(unit: Dictionary) -> Vector2:
	if unit.has("current_position"):
		return Vector2(unit["current_position"])
	return _cities[int(unit["source_id"])].position


## 返回当前战局中的第一座玩家城市，供开局镜头定位使用。
##
## 调用场景：计算初始地图偏移、后续如需把镜头聚焦到玩家主城时。
## 主要逻辑：遍历城市数组并返回第一座归属于玩家的城市；若玩家已灭亡或地图未初始化，则返回空。
func _get_first_player_city():
	for city in _cities:
		if city.owner == PrototypeCityOwnerRef.PLAYER:
			return city
	return null


## 判断当前是否应采用移动端地图尺度策略。
##
## 调用场景：计算地图目标世界尺寸时区分移动端和桌面端参数。
## 主要逻辑：触屏且非桌面运行时视为移动端，避免在桌面触屏设备上误用手机尺度。
func _is_mobile_touch_runtime() -> bool:
	if not DisplayServer.is_touchscreen_available():
		return false
	return not _is_desktop_runtime()


## 更新地图偏移并同步所有依赖屏幕坐标的表现节点。
##
## 调用场景：地图拖拽、开局居中、窗口尺寸变化后的重新钳制。
## 主要逻辑：统一刷新城市视图、升级面板和战场重绘，避免平移后出现道路/城市/按钮错位。
func _set_map_offset(offset: Vector2) -> void:
	_camera_controller.set_offset(offset)
	if is_node_ready():
		_refresh_view()


## 按指定锚点调整地图缩放倍率，并保持锚点下的世界坐标不跳动。
##
## 调用场景：桌面滚轮缩放、移动端双指缩放。
## 主要逻辑：先记录锚点对应的旧世界坐标，再更新缩放倍率并反算偏移，最后统一走边界钳制。
func _set_map_zoom(next_zoom: float, anchor_screen_position: Vector2) -> void:
	_camera_controller.set_zoom(next_zoom, anchor_screen_position)


## 根据输入位置判断当前是否允许开始拖拽地图。
##
## 调用场景：鼠标按下或触摸开始时。
## 主要逻辑：覆盖层、出兵弹窗和 HUD 区域不允许触发拖拽，只在战场区记录拖拽候选。
func _can_start_map_drag(pointer_position: Vector2) -> bool:
	if _game_over or not _game_started or order_dialog_layer.visible or overlay_layer.visible:
		return false
	if bottom_panel.get_global_rect().has_point(pointer_position):
		return false
	if floating_upgrade_panel.visible and floating_upgrade_panel.get_global_rect().has_point(pointer_position):
		return false
	return true


## 记录一次地图拖拽候选，等待后续移动距离判断是否真正开始拖拽。
##
## 调用场景：鼠标左键按下或单指触摸开始时。
## 主要逻辑：缓存指针种类、编号和起点，后续只有同一指针移动超过阈值才会进入拖拽态。
func _begin_map_drag_candidate(pointer_position: Vector2, pointer_kind: String, pointer_index: int = -1) -> void:
	_drag_candidate_active = true
	_drag_pointer_kind = pointer_kind
	_drag_pointer_index = pointer_index
	_drag_press_position = pointer_position
	_drag_last_position = pointer_position
	_is_dragging_map = false


## 在拖拽候选阶段根据移动距离决定是否切换为真正的地图拖拽。
##
## 调用场景：鼠标移动或触控拖动事件到来时。
## 主要逻辑：未过阈值时保持候选态；超过阈值后进入拖拽态，并在每次移动时增量更新地图偏移。
func _update_map_drag(pointer_position: Vector2) -> bool:
	if not _drag_candidate_active:
		return false
	if not _is_dragging_map and pointer_position.distance_to(_drag_press_position) < DRAG_START_DISTANCE:
		return false

	_is_dragging_map = true
	var delta: Vector2 = pointer_position - _drag_last_position
	_drag_last_position = pointer_position
	_set_map_offset(_camera_controller.map_offset + delta)
	return true


## 结束当前地图拖拽或拖拽候选状态。
##
## 调用场景：鼠标左键抬起或触控结束时。
## 主要逻辑：返回本次是否真的发生过拖拽，供点击/取消选城逻辑决定是否忽略这次释放。
func _finish_map_drag(pointer_kind: String, pointer_index: int = -1) -> bool:
	if not _drag_candidate_active:
		return false
	if _drag_pointer_kind != pointer_kind:
		return false
	if pointer_kind == "touch" and _drag_pointer_index != pointer_index:
		return false

	var was_dragging: bool = _is_dragging_map
	_drag_candidate_active = false
	_drag_pointer_kind = ""
	_drag_pointer_index = -1
	_is_dragging_map = false
	return was_dragging


## 消耗一次“选城后短时间内不要立刻取消”的保护计数。
##
## 调用场景：鼠标或触摸抬起、准备执行空白取消选城前。
## 主要逻辑：城市节点完成选中后，浏览器或引擎可能继续派发同一轮触摸对应的抬起事件；
## 这里保留一个极短的保护窗口，吞掉随后的取消请求，避免移动端首点城市后立即被清空。
func _consume_selection_cancel_guard() -> bool:
	if _skip_selection_cancel_guard_count <= 0:
		return false
	_skip_selection_cancel_guard_count -= 1
	_log_input_debug("cancel_guard_consumed", {
		"remaining": _skip_selection_cancel_guard_count,
		"selected_city_id": _selected_city_id
	})
	return true


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


## 处理底部等级升级按钮。
##
## 调用场景：玩家选中己方城市后点击 `升级` 按钮时。
## 主要逻辑：把当前选中城市交给应用层做等级升级结算，表现层只负责转发。
func _on_upgrade_level_button_pressed() -> void:
	if _selected_city_id == -1:
		return
	_execute_upgrade(_selected_city_id, PrototypeBattleServiceRef.UPGRADE_LEVEL, true)


## 处理底部防御升级按钮。
##
## 调用场景：玩家选中己方城市后点击 `升防` 按钮时。
## 主要逻辑：把当前选中城市交给应用层做防御升级结算，表现层只负责转发。
func _on_upgrade_defense_button_pressed() -> void:
	if _selected_city_id == -1:
		return
	_execute_upgrade(_selected_city_id, PrototypeBattleServiceRef.UPGRADE_DEFENSE, true)


## 处理底部产能升级按钮。
##
## 调用场景：玩家选中己方城市后点击 `升产` 按钮时。
## 主要逻辑：把当前选中城市交给应用层做产能升级结算，表现层只负责转发。
func _on_upgrade_production_button_pressed() -> void:
	if _selected_city_id == -1:
		return
	_execute_upgrade(_selected_city_id, PrototypeBattleServiceRef.UPGRADE_PRODUCTION, true)


## 处理底部重新开始按钮。
##
## 调用场景：玩家在对局中途或结束后主动要求重新开局时。
## 主要逻辑：重建战局并直接进入游戏，让玩家清楚地知道已进入新的一局。
func _on_restart_button_pressed() -> void:
	_start_new_match(_current_map_id)
	_show_play_state()


## 切换到正式对局状态并关闭说明遮罩。
##
## 调用场景：玩家看完说明准备开始，或结束后一键再开一局时。
## 主要逻辑：隐藏说明层、更新顶部提示、启动背景音乐并恢复战局推进。
func _show_play_state() -> void:
	_game_started = true
	_manual_paused = false
	_overlay_mode = "play"
	overlay_layer.visible = false
	_log_game_debug("play_state_entered", {})
	status_label.text = "先点蓝色城市，再点目标城市，直接创建持续出兵路线。"
	hint_label.text = "同一路线再次点击可关闭；一个源城有多条路线时会轮流出兵。"
	# Web 平台在用户首次交互后初始化音频（绕过 autoplay 限制）
	_audio_manager.initialize_audio()
	_audio_manager.play_sfx_by_id("select")
	_audio_manager.play_bgm_if_needed()
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


## 初始化出兵弹窗中的“持续出兵”开关，便于玩家在后期减少重复点击。
##
## 调用场景：主场景 `_ready()` 绑定完弹窗按钮后。
## 主要逻辑：动态创建一个 `CheckButton` 放到出兵弹窗正文区，并把状态同步到当前待确认订单。
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
func _register_continuous_order(source_id: int, target_id: int) -> void:
	var ensure_result: Dictionary = _order_dispatch_service.ensure_continuous_order(source_id, target_id)
	_log_game_debug("continuous_order_registered", {
		"source_id": source_id,
		"source_name": _cities[source_id].name,
		"target_id": target_id,
		"target_name": _cities[target_id].name,
		"action": ensure_result.get("action", "")
	})
	status_label.text = "已开启持续出兵：%s -> %s，源城每产 1 兵就自动派 1 人。" % [_cities[source_id].name, _cities[target_id].name]
	hint_label.text = "持续出兵不使用数量框；数量框只影响本次一次性出兵。"
	_refresh_continuous_status_label()
	_refresh_view()


## 移除一条指定路线的持续出兵任务。
##
## 调用场景：玩家对同一路线改为一次性出兵、或重新注册同一路线前去重时。
## 主要逻辑：按源城和目标路线匹配，避免目标归属变化后出现同一路线无法覆盖或关闭的问题。
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
func _produce_soldiers_and_dispatch_continuous_orders() -> void:
	for city in _cities:
		city.accumulate_production_progress(1.0)
		var produced_count: int = 0
		var dispatched_from_full_count: int = 0
		while city.get_ready_production_count() > 0:
			if city.can_produce():
				if not city.try_produce_one_soldier():
					break
				produced_count += 1
				_dispatch_continuous_orders_for_source(city.city_id)
				continue

			if not _order_dispatch_service.has_orders_for_source(city.city_id):
				break
			if not city.consume_one_ready_production():
				break
			dispatched_from_full_count += 1
			_dispatch_continuous_orders_for_source(city.city_id)
		if produced_count <= 0:
			if dispatched_from_full_count <= 0:
				continue
		_log_game_debug("production_tick", {
			"city_id": city.city_id,
			"city_name": city.name,
			"produced_count": produced_count,
			"dispatched_from_full_count": dispatched_from_full_count,
			"ready_production_remaining": city.get_ready_production_count(),
			"soldiers_after": city.soldiers,
			"owner": city.owner
		})


## 针对某个源城触发一次持续出兵检查。
##
## 调用场景：该源城每产生 1 个新士兵后。
## 主要逻辑：把源城交给调度服务做一次轮转选择；成功时复用现有行军执行链，失败时只记录原因。
func _dispatch_continuous_orders_for_source(source_id: int) -> bool:
	var dispatch_result: Dictionary = _order_dispatch_service.dispatch_for_source(_cities, source_id)
	if not bool(dispatch_result.get("success", false)):
		if String(dispatch_result.get("reason", "")) != "no_orders":
			var source_name: String = _cities[source_id].name if source_id >= 0 and source_id < _cities.size() else ""
			_log_game_debug("continuous_order_skipped", {
				"source_id": source_id,
				"source_name": source_name,
				"reason": dispatch_result.get("reason", ""),
				"source_soldiers": _cities[source_id].soldiers if source_id >= 0 and source_id < _cities.size() else -1,
				"has_orders": _order_dispatch_service.has_orders_for_source(source_id)
			})
		return false
	return _try_execute_continuous_order(dispatch_result)


## 尝试执行一条持续出兵任务。
##
## 调用场景：某个源城产兵后触发持续任务检查时。
## 主要逻辑：调度结果只携带“该派哪条路线”的抽象信息；这里统一转成运兵或进攻，并关闭每次出兵音效。
func _try_execute_continuous_order(dispatch_result: Dictionary) -> bool:
	var source_id: int = int(dispatch_result["source_id"])
	var target_id: int = int(dispatch_result["target_id"])
	var source = _cities[source_id]
	var target = _cities[target_id]
	var troop_count: int = int(dispatch_result.get("troop_count", 1))
	var is_transfer: bool = bool(dispatch_result.get("is_transfer", false))
	_log_game_debug("continuous_order_triggered", {
		"source_id": source_id,
		"source_name": source.name,
		"target_id": target_id,
		"target_name": target.name,
		"is_transfer": is_transfer,
		"troop_count": troop_count,
		"source_owner": source.owner,
		"target_owner": target.owner
	})
	_continuous_dispatch_count_in_window += 1
	_continuous_dispatch_soldiers_in_window += troop_count
	_continuous_dispatch_counts_by_source_in_window[source_id] = int(_continuous_dispatch_counts_by_source_in_window.get(source_id, 0)) + 1
	if is_transfer:
		_execute_transfer(source_id, target_id, troop_count, true, false)
	else:
		_execute_attack(source_id, target_id, troop_count, source.owner == PrototypeCityOwnerRef.PLAYER, true, false)
	return true


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
	return _manual_paused or overlay_layer.visible


## 处理玩家在主场景上的原始输入，用于地图拖拽与基础指针跟踪。
##
## 调用场景：鼠标左键或单点触控按下时。
## 主要逻辑：这里只处理拖拽相关的按下、移动和释放；选城取消交给 `_unhandled_input()`，
## 这样城市节点一旦消费了点击，空白取消逻辑就不会再重复执行。
func _input(event: InputEvent) -> void:
	if _game_over or not _game_started or order_dialog_layer.visible or overlay_layer.visible:
		return
	if event is InputEventMouseButton:
		if _handle_mouse_wheel_zoom(event):
			return
		if event.button_index != MOUSE_BUTTON_LEFT:
			return
		_log_input_debug("mouse_button", {
			"pressed": event.pressed,
			"position": event.position,
			"selected_city_id": _selected_city_id
		})
		_handle_mouse_drag_input(event)
	elif event is InputEventMouseMotion:
		_handle_mouse_motion_input(event)
	elif event is InputEventScreenTouch:
		_log_input_debug("screen_touch", {
			"pressed": event.pressed,
			"index": event.index,
			"position": event.position,
			"selected_city_id": _selected_city_id
		})
		_handle_touch_drag_input(event)
	elif event is InputEventScreenDrag:
		_log_input_debug("screen_drag", {
			"index": event.index,
			"position": event.position,
			"selected_city_id": _selected_city_id
		})
		_handle_screen_drag_input(event)


## 处理未被城市节点或 HUD 消费的输入事件，用于把真正的空白点击转换成取消选城。
##
## 调用场景：Godot 在 `_input()` 和节点 `_input_event()` 之后，把仍未处理的释放事件分发到这里。
## 主要逻辑：只有未被消费、且没有发生拖拽的释放事件才会进入取消逻辑；因此城市点击不会再与空白取消重复消费。
func _unhandled_input(event: InputEvent) -> void:
	if _game_over or not _game_started or order_dialog_layer.visible or overlay_layer.visible or _manual_paused:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		_log_input_debug("unhandled_mouse_release", {
			"position": event.position,
			"selected_city_id": _selected_city_id
		})
		_handle_selection_cancel_release(event.position)
	elif event is InputEventScreenTouch and not event.pressed:
		_log_input_debug("unhandled_touch_release", {
			"index": event.index,
			"position": event.position,
			"selected_city_id": _selected_city_id
		})
		_handle_selection_cancel_release(event.position)


## 处理桌面端鼠标按下/抬起，以区分地图拖拽和普通点击。
##
## 调用场景：主场景收到鼠标左键事件时。
## 主要逻辑：按下时记录拖拽候选；抬起时若发生过拖拽则直接结束并消费，未拖拽则交给 `_unhandled_input()` 判定是否取消选城。
func _handle_mouse_drag_input(event: InputEventMouseButton) -> void:
	if event.pressed:
		if _skip_selection_cancel_guard_count > 0:
			_log_input_debug("clear_cancel_guard_on_mouse_press", {
				"selected_city_id": _selected_city_id,
				"remaining": _skip_selection_cancel_guard_count,
				"position": event.position
			})
			_skip_selection_cancel_guard_count = 0
		if _manual_paused or not _can_start_map_drag(event.position):
			return
		_begin_map_drag_candidate(event.position, "mouse")
		return

	var was_dragging: bool = _finish_map_drag("mouse")
	if was_dragging:
		get_viewport().set_input_as_handled()
	return


## 处理桌面端鼠标移动，用于实时平移大地图。
##
## 调用场景：主场景收到鼠标移动事件时。
## 主要逻辑：只有存在拖拽候选或拖拽进行中时才处理；移动超过阈值后开始平移地图。
func _handle_mouse_motion_input(event: InputEventMouseMotion) -> void:
	if _manual_paused:
		return
	if _update_map_drag(event.position):
		get_viewport().set_input_as_handled()


## 处理移动端/Web 的触摸开始与结束事件。
##
## 调用场景：主场景收到单点触控事件时。
## 主要逻辑：触摸开始时记录拖拽候选；触摸结束时若本次已经拖拽过则忽略，
## 未拖拽则把点击语义留给城市节点或 `_unhandled_input()` 的空白取消逻辑。
func _handle_touch_drag_input(event: InputEventScreenTouch) -> void:
	_update_active_touch_point(event.index, event.position, event.pressed)
	if _active_touch_points.size() >= 2:
		if event.pressed:
			_begin_pinch_zoom()
		if _finish_map_drag("touch", event.index):
			get_viewport().set_input_as_handled()
		return
	if _is_pinching_map and _active_touch_points.size() < 2:
		_end_pinch_zoom()
		get_viewport().set_input_as_handled()
		return

	if event.pressed:
		if _skip_selection_cancel_guard_count > 0:
			_log_input_debug("clear_cancel_guard_on_touch_press", {
				"selected_city_id": _selected_city_id,
				"remaining": _skip_selection_cancel_guard_count,
				"index": event.index,
				"position": event.position
			})
			_skip_selection_cancel_guard_count = 0
		if _manual_paused or not _can_start_map_drag(event.position):
			return
		_begin_map_drag_candidate(event.position, "touch", event.index)
		return

	var was_dragging: bool = _finish_map_drag("touch", event.index)
	if was_dragging:
		get_viewport().set_input_as_handled()
	return


## 处理移动端/Web 的单指拖动事件。
##
## 调用场景：主场景收到 `InputEventScreenDrag` 时。
## 主要逻辑：只接受当前激活手指的拖动；一旦超过阈值就持续更新地图偏移。
func _handle_screen_drag_input(event: InputEventScreenDrag) -> void:
	if _manual_paused:
		return
	if _active_touch_points.has(event.index):
		_active_touch_points[event.index] = event.position
	if _active_touch_points.size() >= 2 and _update_pinch_zoom():
		get_viewport().set_input_as_handled()
		return
	if _drag_pointer_kind != "touch" or _drag_pointer_index != event.index:
		return
	if _update_map_drag(event.position):
		get_viewport().set_input_as_handled()


## 处理桌面端滚轮缩放，便于快速拉近或拉远战场。
##
## 调用场景：`_input()` 收到鼠标按键事件时优先调用。
## 主要逻辑：只消费滚轮上/下事件；以鼠标当前位置为缩放锚点，确保观察焦点不跳动。
func _handle_mouse_wheel_zoom(event: InputEventMouseButton) -> bool:
	if _manual_paused or not event.pressed:
		return false
	if event.button_index == MOUSE_BUTTON_WHEEL_UP:
		_set_map_zoom(_camera_controller.map_zoom + MAP_ZOOM_STEP, event.position)
		get_viewport().set_input_as_handled()
		return true
	if event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
		_set_map_zoom(_camera_controller.map_zoom - MAP_ZOOM_STEP, event.position)
		get_viewport().set_input_as_handled()
		return true
	return false


## 记录或清理当前手指坐标，供双指缩放手势识别使用。
##
## 调用场景：触摸按下/抬起事件进入 `_handle_touch_drag_input()` 时。
## 主要逻辑：按下时写入手指位置，抬起时从活动手指表删除，始终保留最新有效触点集合。
func _update_active_touch_point(touch_index: int, position: Vector2, pressed: bool) -> void:
	if pressed:
		_active_touch_points[touch_index] = position
		return
	_active_touch_points.erase(touch_index)


## 启动一次双指缩放手势跟踪。
##
## 调用场景：检测到第二根手指按下且活动触点数量达到 2 时。
## 主要逻辑：记录当前双指距离作为后续增量缩放基准，并打断单指拖拽状态避免手势冲突。
func _begin_pinch_zoom() -> void:
	if _active_touch_points.size() < 2:
		return
	var touch_pair: Array[Vector2] = _get_first_two_touch_positions()
	_pinch_last_distance = touch_pair[0].distance_to(touch_pair[1])
	_is_pinching_map = _pinch_last_distance > 0.0
	if _is_pinching_map:
		_cancel_map_drag_state()


## 在双指手势过程中持续更新地图缩放倍率。
##
## 调用场景：`_handle_screen_drag_input()` 收到活动手指移动事件时。
## 主要逻辑：使用"当前双指距离 / 上一帧双指距离"作为增量倍率，并以双指中心点作为缩放锚点。
func _update_pinch_zoom() -> bool:
	if not _is_pinching_map or _active_touch_points.size() < 2:
		return false
	var touch_pair: Array[Vector2] = _get_first_two_touch_positions()
	var current_distance: float = touch_pair[0].distance_to(touch_pair[1])
	if current_distance <= 0.0 or _pinch_last_distance <= 0.0:
		_pinch_last_distance = current_distance
		return false
	var ratio: float = current_distance / _pinch_last_distance
	_pinch_last_distance = current_distance
	var center: Vector2 = (touch_pair[0] + touch_pair[1]) * 0.5
	_set_map_zoom(_camera_controller.map_zoom * ratio, center)
	return true


## 结束当前双指缩放手势，重置临时状态。
##
## 调用场景：活动触点数量从 2 降到 1 或 0 时。
## 主要逻辑：清空缩放过程中的距离缓存与状态位，避免下一次双指手势沿用旧值。
func _end_pinch_zoom() -> void:
	_is_pinching_map = false
	_pinch_last_distance = 0.0


## 从活动触点集合中取前两根手指坐标，供双指缩放计算使用。
##
## 调用场景：开始或更新双指缩放手势时。
## 主要逻辑：稳定返回两个触点位置；若触点不足则返回空数组。
func _get_first_two_touch_positions() -> Array[Vector2]:
	var keys: Array = _active_touch_points.keys()
	keys.sort()
	if keys.size() < 2:
		return []
	return [Vector2(_active_touch_points[keys[0]]), Vector2(_active_touch_points[keys[1]])]


## 清理地图拖拽候选与拖拽进行中的全部临时状态。
##
## 调用场景：切换到双指缩放手势时。
## 主要逻辑：统一关闭拖拽态，避免双指缩放期间残留的单指拖拽状态继续生效。
func _cancel_map_drag_state() -> void:
	_is_dragging_map = false
	_drag_candidate_active = false
	_drag_pointer_kind = ""
	_drag_pointer_index = -1


## 处理一次释放事件对应的“空白取消选城”逻辑。
##
## 调用场景：`_unhandled_input()` 收到鼠标或触摸抬起事件时。
## 主要逻辑：先吞掉紧跟在选城后的兼容事件，再检查是否真的点在纯战场空白处；只有满足条件时才取消当前选中城市。
func _handle_selection_cancel_release(pointer_position: Vector2) -> void:
	if _consume_selection_cancel_guard():
		return
	if _selected_city_id == -1:
		return
	_log_input_debug("selection_cancel_check", {
		"pointer_position": pointer_position,
		"picked_city_id": _pick_city_at_position(pointer_position),
		"selected_city_id": _selected_city_id,
		"bottom_hit": bottom_panel.get_global_rect().has_point(pointer_position),
		"upgrade_hit": floating_upgrade_panel.visible and floating_upgrade_panel.get_global_rect().has_point(pointer_position)
	})
	if _should_ignore_selection_cancel(pointer_position):
		return
	_clear_selection_with_message("已取消选择。重新点一个蓝色城市即可。")
	get_viewport().set_input_as_handled()


## 判断当前屏幕点击是否命中了任意城市。
##
## 调用场景：空白点击取消选择前的命中判定。
## 主要逻辑：直接基于城市表现节点的当前屏幕位置做命中测试，而不是回退到世界坐标手算，
## 这样地图平移、移动端缩放和文字区域扩展后，判定范围仍与玩家看到的图标位置保持一致。
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
	if bottom_panel.get_global_rect().has_point(pointer_position):
		return true
	return false


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
## 主要逻辑：先铺一层草地底色，再叠加不规则土地色块、分段草纹和极轻氛围块；全部使用确定性世界坐标，
## 不创建独立背景节点，也不在每帧随机生成，确保背景稳定地压在道路、城市和行军单位之下。



## 处理底部暂停按钮。
##
## 调用场景：玩家在对局中点击暂停时。
## 主要逻辑：若当前未暂停则打开暂停面板；若已经暂停则直接恢复。
func _on_pause_button_pressed() -> void:
	if _manual_paused:
		_resume_gameplay()
		return
	_pause_gameplay()


## 背景音乐播放结束后自动续播。
##
## 调用场景：AudioStreamPlayer.finished 信号触发时。
## 主要逻辑：仅在对局处于进行状态时重播，避免菜单遮罩阶段持续响个不停。
func _on_bgm_finished() -> void:
	if not _game_started or _game_over:
		return
	_audio_manager.play_bgm_if_needed()
