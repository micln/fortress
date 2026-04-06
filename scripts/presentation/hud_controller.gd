class_name HudController
extends PanelContainer

## HUD Controller - Manages top panel text content.
## This script should be attached to a PanelContainer node with this structure:
##   PanelContainer
##   ├── Margin (MarginContainer)
##   │   └── InfoColumn (VBoxContainer)
##   │       ├── StatusLabel (Label)
##   │       ├── HintLabel (Label)
##   │       └── AiConfigLabel (Label)

signal continuous_dispatch_stats_updated(stats: Dictionary)

var _continuous_status_label: Label = null

@onready var margin: MarginContainer = $Margin
@onready var info_column: VBoxContainer = $Margin/InfoColumn
@onready var status_label: Label = $Margin/InfoColumn/StatusLabel
@onready var hint_label: Label = $Margin/InfoColumn/HintLabel
@onready var ai_config_label: Label = $Margin/InfoColumn/AiConfigLabel


func _ready() -> void:
	_setup_continuous_status_label()


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
