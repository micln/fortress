class_name PrototypeMapSelectionPanel
extends Control

## 地图选择面板
##
## 展示地图列表供玩家选择。确认选择后触发 `map_selected` 信号，
## 取消选择后触发 `selection_cancelled` 信号。

signal map_selected(map_id: String)
signal selection_cancelled

const PrototypeMapRegistryRef = preload("res://scripts/application/prototype_map_registry.gd")
const UI_FONT: Font = preload("res://assets/fonts/NotoSansSC-Regular.otf")

var _selected_map_id: String = ""
var _map_item_buttons: Array[Button] = []

@onready var panel: PanelContainer = $MapSelectPanel
@onready var title_label: Label = $MapSelectPanel/MapSelectMargin/MapSelectColumn/MapSelectTitleLabel
@onready var map_list: VBoxContainer = $MapSelectPanel/MapSelectMargin/MapSelectColumn/MapListScroll/MapList
@onready var confirm_button: Button = $MapSelectPanel/MapSelectMargin/MapSelectColumn/ConfirmButton
@onready var cancel_button: Button = $MapSelectPanel/MapSelectMargin/MapSelectColumn/CancelButton


func _ready() -> void:
	confirm_button.pressed.connect(_on_confirm_button_pressed)
	cancel_button.pressed.connect(_on_cancel_button_pressed)
	_refresh_map_list()


## 显示地图选择面板。
func show_panel() -> void:
	visible = true
	_refresh_map_list()
	_select_default_map()


## 隐藏地图选择面板。
func hide_panel() -> void:
	visible = false


func _refresh_map_list() -> void:
	# 清除旧的地图按钮
	for btn: Button in _map_item_buttons:
		if is_instance_valid(btn):
			btn.queue_free()
	_map_item_buttons.clear()

	# 清空列表（保留标题和按钮区域）
	for child: Node in map_list.get_children():
		child.queue_free()

	var registry: PrototypeMapRegistry = PrototypeMapRegistryRef.get_instance()
	var summaries: Array[Dictionary] = registry.get_all_map_summaries()

	for summary: Dictionary in summaries:
		var map_id: String = summary["map_id"]
		var map_name: String = summary["name"]
		var city_count: int = summary["city_count"]
		var faction_counts_str: String = str(summary["supported_faction_counts"])

		var item_container: HBoxContainer = HBoxContainer.new()
		item_container.custom_minimum_size = Vector2(0, 80)
		item_container.alignment = HBoxContainer.ALIGNMENT_CENTER

		var select_btn: Button = Button.new()
		select_btn.custom_minimum_size = Vector2(400, 80)
		select_btn.add_theme_font_size_override("font_size", 32)
		select_btn.text = "  %s  (城市:%d 支持方数:%s)" % [map_name, city_count, faction_counts_str]
		select_btn.pressed.connect(_on_map_item_button_pressed.bind(map_id))
		item_container.add_child(select_btn)

		var status_label: Label = Label.new()
		status_label.text = ""
		status_label.name = "StatusLabel"
		item_container.add_child(status_label)

		map_list.add_child(item_container)
		_map_item_buttons.append(select_btn)


func _select_default_map() -> void:
	var registry: PrototypeMapRegistry = PrototypeMapRegistryRef.get_instance()
	var default_id: String = registry.get_default_map_id()
	_select_map(default_id)


func _select_map(map_id: String) -> void:
	_selected_map_id = map_id
	_update_selection_display()


func _update_selection_display() -> void:
	var registry: PrototypeMapRegistry = PrototypeMapRegistryRef.get_instance()
	var summaries: Array[Dictionary] = registry.get_all_map_summaries()

	# 遍历所有按钮，高亮选中项
	var idx: int = 0
	for summary: Dictionary in summaries:
		if idx < _map_item_buttons.size():
			var btn: Button = _map_item_buttons[idx]
			var is_selected: bool = summary["map_id"] == _selected_map_id
			if is_selected:
				# 选中时高亮按钮边框
				var style: StyleBoxFlat = StyleBoxFlat.new()
				style.bg_color = Color(0.1, 0.2, 0.4, 0.8)
				style.border_width_left = 3
				style.border_width_top = 3
				style.border_width_right = 3
				style.border_width_bottom = 3
				style.border_color = Color(0.5, 0.8, 1.0, 1.0)
				style.corner_radius_top_left = 8
				style.corner_radius_top_right = 8
				style.corner_radius_bottom_right = 8
				style.corner_radius_bottom_left = 8
				btn.add_theme_stylebox_override("normal", style)
			else:
				# 取消选中时清除自定义样式
				btn.remove_theme_stylebox_override("normal")
			btn.custom_minimum_size.y = 80 if is_selected else 70
		idx += 1


func _on_map_item_button_pressed(map_id: String) -> void:
	_select_map(map_id)


func _on_confirm_button_pressed() -> void:
	if _selected_map_id.is_empty():
		return
	map_selected.emit(_selected_map_id)
	hide_panel()


func _on_cancel_button_pressed() -> void:
	# 取消选择，保持当前地图（不改变）
	selection_cancelled.emit()
	hide_panel()
