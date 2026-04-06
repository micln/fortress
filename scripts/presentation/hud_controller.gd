class_name HudController
extends PanelContainer

## 顶部 HUD 控制器（TopPanel）。
##
## 调用场景：主场景启动后，负责顶部状态条的文本、布局与“自动出兵状态条”的展示。
## 主要逻辑：对外暴露稳定 API（update_status/update_hint/update_ai_config/update_continuous_status），
## 内部自行处理窄屏布局，避免主控制器通过深路径访问 Label/Container。

signal continuous_dispatch_stats_updated(stats: Dictionary)

var _continuous_status_label: Label = null

@onready var margin: MarginContainer = $Margin
@onready var info_column: VBoxContainer = $Margin/InfoColumn
@onready var status_label: Label = $Margin/InfoColumn/StatusLabel
@onready var hint_label: Label = $Margin/InfoColumn/HintLabel
@onready var ai_config_label: Label = $Margin/InfoColumn/AiConfigLabel


func _ready() -> void:
	_setup_continuous_status_label()
	get_window().size_changed.connect(_on_window_size_changed)
	_apply_responsive_layout()


func _setup_continuous_status_label() -> void:
	if _continuous_status_label != null:
		return
	_continuous_status_label = Label.new()
	_continuous_status_label.name = "ContinuousStatusLabel"
	_continuous_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_continuous_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_continuous_status_label.add_theme_font_size_override("font_size", 14)
	_continuous_status_label.add_theme_color_override("font_color", Color("f6d365"))
	info_column.add_child(_continuous_status_label)
	_refresh_continuous_status_label(0, 0, 0)


func update_status(text: String) -> void:
	status_label.text = text


func update_hint(text: String) -> void:
	hint_label.text = text


func update_ai_config(player_count: int, difficulty: String, style: String, manual_paused: bool = false) -> void:
	var pause_suffix: String = " | 已暂停" if manual_paused else ""
	var viewport_width: float = get_viewport_rect().size.x
	if viewport_width <= 520.0:
		ai_config_label.text = "%d方 | %s | %s%s" % [player_count, difficulty, style, pause_suffix]
	else:
		ai_config_label.text = "对局：%d 方 | %s | %s%s" % [player_count, difficulty, style, pause_suffix]


func update_continuous_status(active_order_count: int, last_second_count: int, last_second_soldiers: int) -> void:
	_refresh_continuous_status_label(active_order_count, last_second_count, last_second_soldiers)


func _refresh_continuous_status_label(active_order_count: int, last_second_count: int, last_second_soldiers: int) -> void:
	if _continuous_status_label == null:
		return
	if active_order_count <= 0:
		_continuous_status_label.text = "自动出兵：关闭"
		return
	_continuous_status_label.text = "自动出兵：%d 条路线 | 最近1秒 %d 次，共 %d 人" % [
		active_order_count,
		last_second_count,
		last_second_soldiers
	]


## 返回顶部面板的底边偏移（用于相机安全区计算）。
##
## 调用场景：CameraController 计算开局镜头偏移时。
## 主要逻辑：直接返回当前 PanelContainer 的 offset_bottom。
func get_panel_bottom() -> float:
	return offset_bottom


func _on_window_size_changed() -> void:
	_apply_responsive_layout()


## 对外暴露的响应式布局刷新入口。
##
## 调用场景：主场景统一处理窗口尺寸变化时（可选），或需要强制刷新 HUD 布局时。
## 主要逻辑：转调内部 `_apply_responsive_layout()`，保持 HUD 布局只在 controller 内实现。
func apply_responsive_layout() -> void:
	_apply_responsive_layout()


## 按当前窗口宽度应用顶部 HUD 的响应式布局。
##
## 调用场景：启动时、窗口尺寸变化时。
## 主要逻辑：窄屏时尽量贴边并隐藏次要文案；桌面端保留更舒展的边距与字号。
func _apply_responsive_layout() -> void:
	var viewport_size: Vector2 = get_viewport_rect().size
	var is_narrow_layout: bool = viewport_size.x <= 520.0

	if is_narrow_layout:
		offset_left = 2.0
		offset_top = 2.0
		offset_right = -2.0
		offset_bottom = 44.0
		margin.add_theme_constant_override("margin_left", 6)
		margin.add_theme_constant_override("margin_top", 3)
		margin.add_theme_constant_override("margin_right", 6)
		margin.add_theme_constant_override("margin_bottom", 3)
		info_column.add_theme_constant_override("separation", 0)
		status_label.add_theme_font_size_override("font_size", 13)
		hint_label.add_theme_font_size_override("font_size", 12)
		ai_config_label.add_theme_font_size_override("font_size", 12)
		status_label.visible = false
		hint_label.visible = false
		if _continuous_status_label != null:
			_continuous_status_label.visible = false
		return

	offset_left = 8.0
	offset_top = 8.0
	offset_right = -8.0
	offset_bottom = 72.0
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_top", 6)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_bottom", 6)
	info_column.add_theme_constant_override("separation", 2)
	status_label.add_theme_font_size_override("font_size", 16)
	hint_label.add_theme_font_size_override("font_size", 14)
	ai_config_label.add_theme_font_size_override("font_size", 14)
	status_label.visible = true
	hint_label.visible = false
	if _continuous_status_label != null:
		_continuous_status_label.visible = true
