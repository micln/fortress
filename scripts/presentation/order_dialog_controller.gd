class_name OrderDialogController
extends CanvasLayer

signal order_confirmed(source_id: int, target_id: int, count: int, continuous: bool)
signal order_cancelled
signal continuous_toggle_changed(enabled: bool)

const NARROW_OVERLAY_BREAKPOINT: float = 520.0

var _source_id: int = -1
var _target_id: int = -1
var _is_transfer: bool = false
var _recommended_count: int = 0
var _current_count: int = 0
var _continuous_enabled: bool = true
var _max_count: int = 1

var _battle_service = null
var _cities = []

@onready var shade: ColorRect = $Shade
@onready var panel: PanelContainer = $Panel
@onready var margin: MarginContainer = $Panel/Margin
@onready var column: VBoxContainer = $Panel/Margin/Column
@onready var scroll: ScrollContainer = $Panel/Margin/Column/OrderScroll
@onready var content: VBoxContainer = $Panel/Margin/Column/OrderScroll/OrderContent
@onready var title_label: Label = $Panel/Margin/Column/OrderScroll/OrderContent/TitleLabel
@onready var context_label: Label = $Panel/Margin/Column/OrderScroll/OrderContent/ContextLabel
@onready var recommended_label: Label = $Panel/Margin/Column/OrderScroll/OrderContent/RecommendedLabel
@onready var forecast_label: Label = $Panel/Margin/Column/OrderScroll/OrderContent/ForecastLabel
@onready var outcome_label: Label = $Panel/Margin/Column/OrderScroll/OrderContent/OutcomeLabel
@onready var count_label: Label = $Panel/Margin/Column/OrderScroll/OrderContent/CountLabel
@onready var adjust_row: HBoxContainer = $Panel/Margin/Column/OrderScroll/OrderContent/AdjustRow
@onready var minus_10_button: Button = $Panel/Margin/Column/OrderScroll/OrderContent/AdjustRow/Minus10Button
@onready var minus_1_button: Button = $Panel/Margin/Column/OrderScroll/OrderContent/AdjustRow/Minus1Button
@onready var plus_1_button: Button = $Panel/Margin/Column/OrderScroll/OrderContent/AdjustRow/Plus1Button
@onready var plus_10_button: Button = $Panel/Margin/Column/OrderScroll/OrderContent/AdjustRow/Plus10Button
@onready var quick_grid: GridContainer = $Panel/Margin/Column/OrderScroll/OrderContent/QuickGrid
@onready var plus_20_button: Button = $Panel/Margin/Column/OrderScroll/OrderContent/QuickGrid/Plus20Button
@onready var plus_50_button: Button = $Panel/Margin/Column/OrderScroll/OrderContent/QuickGrid/Plus50Button
@onready var half_button: Button = $Panel/Margin/Column/OrderScroll/OrderContent/QuickGrid/HalfButton
@onready var full_button: Button = $Panel/Margin/Column/OrderScroll/OrderContent/QuickGrid/FullButton
@onready var recommend_button: Button = $Panel/Margin/Column/OrderScroll/OrderContent/QuickGrid/RecommendButton
@onready var keep_one_button: Button = $Panel/Margin/Column/OrderScroll/OrderContent/QuickGrid/MaxKeepOneButton
@onready var action_row: HBoxContainer = $Panel/Margin/Column/ActionRow
@onready var cancel_button: Button = $Panel/Margin/Column/ActionRow/CancelButton
@onready var confirm_button: Button = $Panel/Margin/Column/ActionRow/ConfirmButton

var _continuous_toggle: CheckButton = null


func _ready() -> void:
	visible = false
	_setup_buttons()
	_setup_continuous_toggle()
	get_window().size_changed.connect(_on_window_size_changed)


func _setup_buttons() -> void:
	minus_10_button.pressed.connect(_on_minus_10)
	minus_1_button.pressed.connect(_on_minus_1)
	plus_1_button.pressed.connect(_on_plus_1)
	plus_10_button.pressed.connect(_on_plus_10)
	plus_20_button.pressed.connect(_on_plus_20)
	plus_50_button.pressed.connect(_on_plus_50)
	half_button.pressed.connect(_on_half)
	full_button.pressed.connect(_on_full)
	recommend_button.pressed.connect(_on_recommend)
	keep_one_button.pressed.connect(_on_keep_one)
	cancel_button.pressed.connect(_on_cancel)
	confirm_button.pressed.connect(_on_confirm)


func _setup_continuous_toggle() -> void:
	_continuous_toggle = CheckButton.new()
	_continuous_toggle.text = "【开启自动出兵】源城每产 1 兵就自动派 1 人（忽略数量框）"
	_continuous_toggle.focus_mode = Control.FOCUS_NONE
	_continuous_toggle.add_theme_font_size_override("font_size", 20)
	_continuous_toggle.add_theme_color_override("font_color", Color("f6d365"))
	_continuous_toggle.toggled.connect(_on_continuous_toggle_toggled)
	content.add_child(_continuous_toggle)
	content.move_child(_continuous_toggle, content.get_child_count() - 1)


func setup(battle_service, cities) -> void:
	_battle_service = battle_service
	_cities = cities


func open(source_id: int, target_id: int, is_transfer: bool, recommended_count: int, max_count: int) -> void:
	_source_id = source_id
	_target_id = target_id
	_is_transfer = is_transfer
	_recommended_count = recommended_count
	_max_count = max_count
	_current_count = clamp(recommended_count, 1, max_count)
	_continuous_enabled = true

	if is_transfer:
		title_label.text = "运兵数量"
		recommended_label.text = "运兵可自由选择人数。`100%` 表示整队输送。"
	else:
		title_label.text = "进攻数量"
		recommended_label.text = "推荐 %d 人。已计入目标防御。" % recommended_count

	_refresh_context()
	_refresh_count()
	_refresh_buttons()
	_apply_layout()
	visible = true


func close() -> void:
	visible = false
	_source_id = -1
	_target_id = -1


func set_count(count: int) -> void:
	_current_count = clamp(count, 1, _max_count)
	_refresh_count()


func _refresh_context() -> void:
	if _source_id < 0 or _source_id >= _cities.size() or _target_id < 0 or _target_id >= _cities.size():
		return
	var source = _cities[_source_id]
	var target = _cities[_target_id]
	context_label.text = "%s -> %s，当前可派 %d 人。点空白可取消选城。" % [source.name, target.name, _max_count]


func _refresh_count() -> void:
	count_label.text = str(_current_count)
	_refresh_forecast()


func _refresh_buttons() -> void:
	minus_10_button.disabled = _current_count <= 1
	minus_1_button.disabled = _current_count <= 1
	plus_1_button.disabled = _current_count >= _max_count
	plus_10_button.disabled = _current_count >= _max_count
	plus_20_button.disabled = _current_count >= _max_count
	plus_50_button.disabled = _current_count >= _max_count
	confirm_button.disabled = _current_count <= 0
	if _continuous_toggle != null:
		_continuous_toggle.button_pressed = _continuous_enabled


func _refresh_forecast() -> void:
	if _source_id < 0 or _source_id >= _cities.size() or _target_id < 0 or _target_id >= _cities.size():
		return
	var source = _cities[_source_id]
	var target = _cities[_target_id]
	var travel_duration: float = _calculate_march_duration(_source_id, _target_id)

	if _is_transfer:
		forecast_label.text = "预计 %.1f 秒后到达。出发后 %s 还剩 %d 人。" % [
			travel_duration, source.name, source.soldiers - _current_count
		]
		outcome_label.text = "预计结果：%s 会接收 %d 名援军。" % [target.name, _current_count]
		return

	# Attack forecast
	if _battle_service != null:
		var preview: Dictionary = _battle_service.preview_attack_outcome(source, target, travel_duration, _current_count)
		forecast_label.text = "%s 预计 %.1f 秒后到达；目标防御 %d，产能 %.1f/秒，路上大约再产 %d 人，到达时等效防守约 %d。" % [
			target.name,
			travel_duration,
			int(preview["predicted_defense_bonus"]),
			target.production_rate,
			int(preview["predicted_growth"]),
			int(preview["predicted_effective_defenders"])
		]
		if bool(preview["predicted_capture"]):
			outcome_label.text = "预计结果：可以占领 %s，城内预计留守 %d 人；%s 出发后还剩 %d 人。" % [
				target.name,
				int(preview["predicted_remaining"]),
				source.name,
				int(preview["source_soldiers_after_departure"])
			]
		else:
			outcome_label.text = "预计结果：无法占领 %s，对方大约还剩 %d 人；%s 出发后还剩 %d 人。" % [
				target.name,
				int(preview["predicted_remaining"]),
				source.name,
				int(preview["source_soldiers_after_departure"])
			]


func _calculate_march_duration(source_id: int, target_id: int) -> float:
	const MARCH_SPEED: float = 180.0
	var source = _cities[source_id]
	var target = _cities[target_id]
	var distance: float = source.position.distance_to(target.position)
	return max(0.45, distance / MARCH_SPEED)


func _adjust_count(delta: int) -> void:
	_current_count = clamp(_current_count + delta, 1, _max_count)
	_refresh_count()
	_refresh_buttons()


func _on_minus_10() -> void:
	_adjust_count(-10)


func _on_minus_1() -> void:
	_adjust_count(-1)


func _on_plus_1() -> void:
	_adjust_count(1)


func _on_plus_10() -> void:
	_adjust_count(10)


func _on_plus_20() -> void:
	_adjust_count(20)


func _on_plus_50() -> void:
	_adjust_count(50)


func _on_half() -> void:
	_current_count = max(1, int(floor(float(_max_count) * 0.5)))
	_refresh_count()
	_refresh_buttons()


func _on_full() -> void:
	_current_count = _max_count
	_refresh_count()
	_refresh_buttons()


func _on_recommend() -> void:
	_current_count = _recommended_count
	_refresh_count()
	_refresh_buttons()


func _on_keep_one() -> void:
	_current_count = max(1, _max_count - 1)
	_refresh_count()
	_refresh_buttons()


func _on_cancel() -> void:
	close()
	order_cancelled.emit()


func _on_confirm() -> void:
	var source_id = _source_id
	var target_id = _target_id
	var count = _current_count
	var continuous = _continuous_enabled
	close()
	order_confirmed.emit(source_id, target_id, count, continuous)


func _on_continuous_toggle_toggled(enabled: bool) -> void:
	_continuous_enabled = enabled
	continuous_toggle_changed.emit(enabled)


func _on_window_size_changed() -> void:
	_apply_layout()


## 对外暴露的响应式布局刷新入口。
##
## 调用场景：主场景统一处理窗口尺寸变化时（可选），或需要强制刷新布局时。
## 主要逻辑：转调内部 `_apply_layout()`，保持 controller 内部成为唯一布局收敛点。
func apply_responsive_layout() -> void:
	_apply_layout()


func _apply_layout() -> void:
	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	var is_narrow_layout: bool = viewport_size.x <= NARROW_OVERLAY_BREAKPOINT
	var quick_buttons: Array[Button] = [plus_20_button, plus_50_button, half_button, full_button, recommend_button, keep_one_button]
	var adjust_buttons: Array[Button] = [minus_10_button, minus_1_button, plus_1_button, plus_10_button]

	if is_narrow_layout:
		panel.anchor_left = 0.03
		panel.anchor_top = 0.08
		panel.anchor_right = 0.97
		panel.anchor_bottom = 0.92
		panel.custom_minimum_size = Vector2(0.0, 0.0)
		margin.add_theme_constant_override("margin_left", 14)
		margin.add_theme_constant_override("margin_top", 14)
		margin.add_theme_constant_override("margin_right", 14)
		margin.add_theme_constant_override("margin_bottom", 14)
		column.add_theme_constant_override("separation", 12)
		scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
		title_label.add_theme_font_size_override("font_size", 28)
		context_label.add_theme_font_size_override("font_size", 16)
		recommended_label.add_theme_font_size_override("font_size", 14)
		forecast_label.add_theme_font_size_override("font_size", 14)
		outcome_label.add_theme_font_size_override("font_size", 16)
		count_label.add_theme_font_size_override("font_size", 28)
		adjust_row.add_theme_constant_override("separation", 8)
		quick_grid.columns = 2
		quick_grid.add_theme_constant_override("h_separation", 10)
		quick_grid.add_theme_constant_override("v_separation", 10)
		action_row.add_theme_constant_override("separation", 6)
		for button in adjust_buttons:
			button.add_theme_font_size_override("font_size", 18)
			button.custom_minimum_size = Vector2(0.0, 42.0)
		for button in quick_buttons:
			button.add_theme_font_size_override("font_size", 18)
			button.custom_minimum_size = Vector2(0.0, 42.0)
		cancel_button.text = "取消"
		cancel_button.add_theme_font_size_override("font_size", 14)
		cancel_button.custom_minimum_size = Vector2(64.0, 36.0)
		confirm_button.text = "出兵"
		confirm_button.add_theme_font_size_override("font_size", 14)
		confirm_button.custom_minimum_size = Vector2(68.0, 36.0)
		if _continuous_toggle != null:
			_continuous_toggle.add_theme_font_size_override("font_size", 14)
		return

	panel.anchor_left = 0.1
	panel.anchor_top = 0.18
	panel.anchor_right = 0.9
	panel.anchor_bottom = 0.84
	panel.custom_minimum_size = Vector2(500.0, 520.0)
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_top", 24)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_bottom", 24)
	column.add_theme_constant_override("separation", 16)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	title_label.add_theme_font_size_override("font_size", 46)
	context_label.add_theme_font_size_override("font_size", 26)
	recommended_label.add_theme_font_size_override("font_size", 17)
	forecast_label.add_theme_font_size_override("font_size", 17)
	outcome_label.add_theme_font_size_override("font_size", 26)
	count_label.add_theme_font_size_override("font_size", 46)
	adjust_row.add_theme_constant_override("separation", 14)
	quick_grid.columns = 3
	quick_grid.add_theme_constant_override("h_separation", 14)
	quick_grid.add_theme_constant_override("v_separation", 14)
	action_row.add_theme_constant_override("separation", 16)
	for button in adjust_buttons:
		button.add_theme_font_size_override("font_size", 24)
		button.custom_minimum_size = Vector2(0.0, 52.0)
	minus_10_button.custom_minimum_size = Vector2(110.0, 52.0)
	minus_1_button.custom_minimum_size = Vector2(100.0, 52.0)
	plus_1_button.custom_minimum_size = Vector2(100.0, 52.0)
	plus_10_button.custom_minimum_size = Vector2(110.0, 52.0)
	for button in quick_buttons:
		button.add_theme_font_size_override("font_size", 24)
		button.custom_minimum_size = Vector2(0.0, 52.0)
	cancel_button.text = "取消"
	cancel_button.add_theme_font_size_override("font_size", 26)
	cancel_button.custom_minimum_size = Vector2(180.0, 58.0)
	confirm_button.text = "确认出兵"
	confirm_button.add_theme_font_size_override("font_size", 26)
	confirm_button.custom_minimum_size = Vector2(220.0, 58.0)
	if _continuous_toggle != null:
		_continuous_toggle.add_theme_font_size_override("font_size", 20)
