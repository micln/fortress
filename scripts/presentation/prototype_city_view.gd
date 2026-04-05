class_name PrototypeCityView
extends Area2D

signal city_pressed(city_id: int)

const CITY_SIZE: Vector2 = Vector2(180.0, 130.0)
const TAP_MAX_DRAG_DISTANCE: float = 30.0
const TOUCH_MOUSE_DEDUP_WINDOW_MS: int = 450
const INPUT_DEBUG_LOG_ENABLED: bool = true
const MARKER_EMOJI_PROJECT_SETTING: StringName = &"fortress_war/ui/use_marker_emoji"
const MARKER_EMOJI_ENV_VAR: String = "FORTRESS_WAR_USE_MARKER_EMOJI"
const MARKER_TEXT_FALLBACK_PROJECT_SETTING: StringName = &"fortress_war/ui/force_marker_text_fallback"
const MARKER_TEXT_FALLBACK_ENV_VAR: String = "FORTRESS_WAR_FORCE_MARKER_TEXT_FALLBACK"
const CITY_BASE_CENTER: Vector2 = Vector2(0.0, 14.0)
const CITY_SHADOW_CENTER: Vector2 = Vector2(0.0, 35.0)
const CITY_BASE_OUTER_RADIUS: float = 60.0
const CITY_BASE_INNER_RADIUS: float = 46.0
const CITY_BASE_PLATE_RECT: Rect2 = Rect2(Vector2(-32.0, 42.0), Vector2(64.0, 19.0))
const CITY_PLATFORM_RECT: Rect2 = Rect2(Vector2(-53.0, 21.0), Vector2(106.0, 32.0))
const CITY_MOAT_RADIUS: float = 70.0
const PrototypeCityOwnerRef = preload("res://scripts/domain/prototype_city_owner.gd")

var city_id: int = -1
var city_owner: int = PrototypeCityOwnerRef.NEUTRAL
var city_level: int = 1
var city_node_type: String = "normal"
var is_selected: bool = false
var _mouse_pressing: bool = false
var _mouse_press_position: Vector2 = Vector2.ZERO
var _touch_pressing: bool = false
var _touch_press_position: Vector2 = Vector2.ZERO
var _touch_index: int = -1
var _last_touch_tap_time_ms: int = -1

@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var marker_label: Label = $MarkerLabel
@onready var name_label: Label = $NameLabel
@onready var soldier_label: Label = $SoldierLabel
@onready var attr_label: Label = $AttrLabel


## 初始化城市表现节点的固定数据与输入碰撞区域。
##
## 调用场景：主场景实例化城市节点后立即调用。
## 主要逻辑：写入城市编号和名称，并用矩形碰撞体统一覆盖触控与鼠标点击范围。
func setup(p_city_id: int, p_city_name: String) -> void:
	city_id = p_city_id
	name_label.text = p_city_name
	var shape := RectangleShape2D.new()
	shape.size = CITY_SIZE
	collision_shape.shape = shape


## 根据城市实时状态刷新文字、颜色与选中高亮。
##
## 调用场景：每次地图重绘、进攻结算后、产兵后。
## 主要逻辑：同步内部显示数据，把主体标识、名称、兵力和属性拆成固定层级展示，
## 让竖屏小地图上的信息层级更稳定、字体节奏更统一；屏幕位置由主场景统一换算后传入，
## 避免城市节点自己混用世界坐标与屏幕坐标。
func sync_from_state(city, selected: bool, screen_position: Vector2) -> void:
	city_owner = city.owner
	city_level = city.level
	city_node_type = String(city.node_type)
	is_selected = selected
	position = screen_position
	marker_label.text = ""
	name_label.text = city.name
	soldier_label.text = "%d/%d" % [city.soldiers, city.max_soldiers]
	attr_label.text = _build_attr_text(city)
	queue_redraw()


## 组装城市属性行文本，并在有战略节点时补充简短标签。
##
## 调用场景：城市节点每次根据运行时状态刷新文字时。
## 主要逻辑：先保留等级、防御、产能三项核心信息，再在非普通节点后面追加中文节点标签，避免挤占太多竖屏空间。
func _build_attr_text(city) -> String:
	var attr_text: String = "Lv.%d  防%d  产%.1f" % [city.level, city.defense, city.production_rate]
	if String(city.node_type) == "normal":
		return attr_text
	return "%s  %s" % [attr_text, city.get_node_type_display_name()]


## 根据节点类型返回城市主体标识文本，并在需要时走短文本降级。
##
## 调用场景：城市状态同步时刷新标识层文本，或在项目配置里显式切换 emoji 模式时。
## 主要逻辑：默认返回可读的单字中文标识，避免缺字方框；只有在显式开启 emoji 开关后才改为 emoji。
func _get_city_marker_text(node_type: String, use_emoji: bool = false) -> String:
	if not use_emoji:
		match node_type:
			"pass":
				return "关"
			"hub":
				return "枢"
			"heartland":
				return "腹"
			_:
				return "城"
	match node_type:
		"pass":
			return "🏰"
		"hub":
			return "⛩️"
		_:
			return "🏯"


## 判断当前是否需要把城市标识切换为 emoji 模式。
##
## 调用场景：城市节点刷新 `MarkerLabel` 文本时。
## 主要逻辑：先查 `ProjectSettings` 中的 emoji 显式开关，再查环境变量；两者都未开启时保持短文本模式，避免默认行为出现方框。
## 可操作入口：`ProjectSettings` 键 `fortress_war/ui/use_marker_emoji`，或环境变量 `FORTRESS_WAR_USE_MARKER_EMOJI=1`。
## 兼容入口：旧的 `force_marker_text_fallback` 仍保留为短文本别名，但默认已经是短文本。
func _should_use_marker_emoji() -> bool:
	if _read_marker_text_fallback_flag():
		return false
	return _read_marker_emoji_flag()


## 读取环境变量或项目设置中的短文本兼容开关。
##
## 调用场景：`_should_use_marker_emoji()` 在判断是否应该保留短文本时调用。
## 主要逻辑：短文本是默认值，但如果项目配置或环境变量显式要求短文本，就直接返回 true。
func _read_marker_text_fallback_flag() -> bool:
	if ProjectSettings.has_setting(MARKER_TEXT_FALLBACK_PROJECT_SETTING):
		return _read_marker_bool_setting(ProjectSettings.get_setting(MARKER_TEXT_FALLBACK_PROJECT_SETTING, false))
	var raw_value: String = OS.get_environment(MARKER_TEXT_FALLBACK_ENV_VAR).strip_edges().to_lower()
	if raw_value.is_empty():
		return false
	return raw_value in ["1", "true", "yes", "on"]


## 读取环境变量或项目设置中的 emoji 显式开关。
##
## 调用场景：`_should_use_marker_emoji()` 在需要判断是否切到 emoji 时调用。
## 主要逻辑：只有显式开关打开时才返回 true；这样默认继续使用可读文本，不会让 emoji 成为默认风险路径。
func _read_marker_emoji_flag() -> bool:
	if ProjectSettings.has_setting(MARKER_EMOJI_PROJECT_SETTING):
		return _read_marker_bool_setting(ProjectSettings.get_setting(MARKER_EMOJI_PROJECT_SETTING, false))
	var raw_value: String = OS.get_environment(MARKER_EMOJI_ENV_VAR).strip_edges().to_lower()
	if raw_value.is_empty():
		return false
	return raw_value in ["1", "true", "yes", "on"]


## 统一解析项目设置里的布尔值，避免字符串或数字配置时出现误判。
##
## 调用场景：读取 marker 文本模式相关的 ProjectSettings 时。
## 主要逻辑：优先按 bool 直接解析，其次兼容常见字符串形式，最后回退到默认值。
func _read_marker_bool_setting(value, default_value: bool = false) -> bool:
	if value is bool:
		return value
	if value is String:
		var normalized: String = String(value).strip_edges().to_lower()
		if normalized.is_empty():
			return default_value
		return normalized in ["1", "true", "yes", "on", "emoji"]
	if value is int:
		return int(value) != 0
	return default_value


## 绘制城市的程序化底座、主体标识与选中态高亮。
##
## 调用场景：Godot 需要重绘节点时自动调用。
## 主要逻辑：先绘制层叠圆形底座与底部台座，再按节点类型追加腹地徽记或其他选中高亮，
## 让城市在不依赖额外美术资源的情况下仍能保持稳定识别度。
func _draw() -> void:
	var base_color: Color = PrototypeCityOwnerRef.get_color(city_owner)
	_draw_city_base(base_color)
	_draw_city_keep(base_color)
	if city_node_type == "heartland":
		_draw_heartland_core_marker(base_color)
	if is_selected:
		_draw_city_selection_highlight()


## 绘制城市石砌台基，配合中式城堡整体风格。
##
## 调用场景：城市节点重绘时由 `_draw()` 统一调用。
func _draw_city_base(base_color: Color) -> void:
	var stone_color: Color = Color(0.76, 0.72, 0.65)
	var stone_dark: Color = stone_color.darkened(0.20)
	var stone_light: Color = stone_color.lightened(0.06)
	var line_color: Color = Color(0.08, 0.07, 0.05, 0.60)

	# 底层宽台
	var base_rect := Rect2(Vector2(-36.0, 16.0), Vector2(72.0, 14.0))
	draw_rect(base_rect, stone_dark)
	draw_rect(base_rect.grow(-2.0), stone_color, false, 1.0)

	# 上层窄台
	var top_rect := Rect2(Vector2(-28.0, 10.0), Vector2(56.0, 8.0))
	draw_rect(top_rect, stone_color)
	draw_rect(top_rect.grow(-2.0), stone_light, false, 1.0)

	# 石缝
	draw_line(Vector2(-35.0, 21.0), Vector2(35.0, 21.0), stone_dark, 0.8, true)
	draw_line(Vector2(-35.0, 25.0), Vector2(35.0, 25.0), stone_dark, 0.8, true)


const CITY_BODY_RECT: Rect2 = Rect2(Vector2(-35.0, 0.0), Vector2(70.0, 42.0))
const CITY_ROOF_W: float = 91.0
const CITY_ROOF_H: float = 25.0

func _draw_city_keep(base_color: Color) -> void:
	# 墙色随 owner 变化（蓝=玩家/灰=中立/其他=敌方）
	var wall_color: Color = base_color.lerp(Color(0.92, 0.90, 0.86), 0.42)
	var roof_color: Color = Color(0.22, 0.26, 0.30)
	var line_color: Color = Color(0.06, 0.05, 0.04, 0.70)

	# 墙壁
	draw_rect(CITY_BODY_RECT, wall_color)

	# 城门（深褐）
	var gate_rect := Rect2(Vector2(-7.0, CITY_BODY_RECT.end.y - 12.0), Vector2(14.0, 12.0))
	draw_rect(gate_rect, Color(0.10, 0.06, 0.02))

	# 重檐歇山顶：上下两层，上层明显更窄更暗
	_draw_double_roof(
		Vector2(-CITY_ROOF_W * 0.5, CITY_BODY_RECT.position.y - CITY_ROOF_H),
		CITY_ROOF_W, CITY_ROOF_H, roof_color, line_color
	)

	# 墙体轮廓
	draw_rect(CITY_BODY_RECT, line_color, false, 1.5)
	draw_rect(gate_rect, line_color, false, 1.0)


func _draw_double_roof(pos: Vector2, w: float, h: float, roof_color: Color, line_color: Color) -> void:
	# 重檐歇山顶：下层宽、上层明显更窄，两层之间有深色分隔带
	# 下层：宽出檐 + 宽瓦面
	# 上层：窄收分 + 略亮，形成视觉层次
	var inner_l1: float = pos.x + w * 0.13
	var inner_r1: float = pos.x + w * 0.87
	var inner_l2: float = pos.x + w * 0.25
	var inner_r2: float = pos.x + w * 0.75
	var top_y: float = pos.y + h * 0.30
	var mid_y: float = pos.y + h * 0.55
	var bot_y: float = pos.y + h

	# 下层屋顶（深色）
	var lower := PackedVector2Array([
		Vector2(inner_l1, mid_y), Vector2(inner_l1, bot_y),
		Vector2(inner_r1, bot_y), Vector2(inner_r1, mid_y)
	])
	draw_colored_polygon(lower, roof_color.darkened(0.10))

	# 上层屋顶（明显更亮，与下层拉开差距）
	var upper := PackedVector2Array([
		Vector2(inner_l2, top_y), Vector2(inner_l2, mid_y),
		Vector2(inner_r2, mid_y), Vector2(inner_r2, top_y)
	])
	draw_colored_polygon(upper, roof_color.lightened(0.12))

	# 两层之间的分隔带（深色横条，让重檐分界更锐利）
	draw_rect(Rect2(Vector2(inner_l1, mid_y - 2.0), Vector2(inner_r1 - inner_l1, 4.0)), roof_color.darkened(0.22))

	# 下层出檐
	draw_rect(Rect2(Vector2(pos.x - 8.0, bot_y - 3.0), Vector2(14.0, 3.0)), roof_color.darkened(0.15))
	draw_rect(Rect2(Vector2(pos.x + w - 6.0, bot_y - 3.0), Vector2(14.0, 3.0)), roof_color.darkened(0.15))
	# 上层出檐
	draw_rect(Rect2(Vector2(inner_l2 - 6.0, mid_y - 2.5), Vector2(12.0, 2.5)), roof_color.darkened(0.10))
	draw_rect(Rect2(Vector2(inner_r2 - 6.0, mid_y - 2.5), Vector2(12.0, 2.5)), roof_color.darkened(0.10))

	# 横向瓦纹（上下各两条）
	for i in range(2):
		var y1: float = mid_y + h * 0.08 + float(i) * (bot_y - mid_y) * 0.40
		draw_line(Vector2(inner_l1 - 2.0, y1), Vector2(inner_r1 + 2.0, y1), roof_color.darkened(0.18), 0.8, true)
	for i in range(2):
		var y2: float = top_y + h * 0.08 + float(i) * (mid_y - top_y) * 0.45
		draw_line(Vector2(inner_l2 - 2.0, y2), Vector2(inner_r2 + 2.0, y2), roof_color.darkened(0.12), 0.8, true)

	# 檐口压线
	draw_line(Vector2(pos.x - 8.0, bot_y), Vector2(pos.x + w + 8.0, bot_y), line_color, 1.5, true)
	draw_line(Vector2(inner_l2 - 6.0, mid_y), Vector2(inner_r2 + 6.0, mid_y), line_color, 1.0, true)


## 为 `heartland` 额外绘制固定的核心外圈和底部徽记。
##
## 调用场景：城市节点重绘时，仅在腹地节点上调用。
## 主要逻辑：用外圈强调"核心据点"的概念，再用底部菱形徽记做稳定识别，不把差异只放在文字或颜色上。
func _draw_heartland_core_marker(base_color: Color) -> void:
	var ring_color: Color = base_color.lightened(0.48)
	var badge_color: Color = Color(0.975, 0.845, 0.41)
	var badge_outline: Color = Color(0.32, 0.22, 0.08, 0.88)
	var badge_points := PackedVector2Array([
		Vector2(0.0, 22.0),
		Vector2(8.0, 30.0),
		Vector2(0.0, 38.0),
		Vector2(-8.0, 30.0)
	])

	draw_arc(Vector2(0.0, 4.0), 30.0, 0.0, TAU, 64, ring_color, 4.0, true)
	draw_colored_polygon(badge_points, badge_color)
	draw_polyline(badge_points, badge_outline, 2.0, true)


## 绘制城市被选中时的柔和高亮，避免直接改动点击范围。
##
## 调用场景：城市节点在当前被选中后重绘。
## 主要逻辑：使用外圈晕染和描边环表达选中态，保留主体内部空间给标识层和文字层。
func _draw_city_selection_highlight() -> void:
	var highlight_color: Color = Color(1.0, 0.93, 0.45, 0.12)
	var ring_color: Color = Color(1.0, 0.93, 0.45, 0.9)
	draw_circle(CITY_BASE_CENTER, CITY_BASE_OUTER_RADIUS + 13.0, highlight_color)
	draw_arc(CITY_BASE_CENTER, CITY_BASE_OUTER_RADIUS + 11.0, 0.0, TAU, 64, ring_color, 4.0, true)


## 处理城市节点上的触控和鼠标输入，并向主场景抛出点击事件。
##
## 调用场景：玩家点击或触摸城市时由 Godot 输入系统回调。
## 主要逻辑：按下时先记录初始位置；抬起时若位移仍在点击阈值内，才视为真正点击，
## 这样在城市上起手拖拽地图时，不会误触发选城；在触屏设备上直接忽略兼容鼠标事件，避免移动端一次轻触触发两次选城。
func _input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if DisplayServer.is_touchscreen_available():
			_log_city_input_debug("ignore_mouse_on_touchscreen", {
				"city_id": city_id,
				"position": event.position,
				"pressed": event.pressed
			})
			return
		_log_city_input_debug("mouse_button", {
			"city_id": city_id,
			"pressed": event.pressed,
			"position": event.position
		})
		if _should_ignore_compat_mouse_tap():
			_log_city_input_debug("ignore_compat_mouse_tap", {
				"city_id": city_id,
				"position": event.position
			})
			return
		if event.pressed:
			_mouse_pressing = true
			_mouse_press_position = event.position
			return
		if not _mouse_pressing:
			return
		_mouse_pressing = false
		if event.position.distance_to(_mouse_press_position) <= TAP_MAX_DRAG_DISTANCE:
			_viewport.set_input_as_handled()
			city_pressed.emit(city_id)
		return

	if event is InputEventScreenTouch:
		_log_city_input_debug("screen_touch", {
			"city_id": city_id,
			"pressed": event.pressed,
			"index": event.index,
			"position": event.position
		})
		if event.pressed:
			_touch_pressing = true
			_touch_press_position = event.position
			_touch_index = event.index
			return
		if not _touch_pressing or event.index != _touch_index:
			return
		_touch_pressing = false
		_touch_index = -1
		if event.position.distance_to(_touch_press_position) <= TAP_MAX_DRAG_DISTANCE:
			_last_touch_tap_time_ms = Time.get_ticks_msec()
			_viewport.set_input_as_handled()
			city_pressed.emit(city_id)


## 判断当前鼠标点击是否只是触摸事件之后浏览器补发的兼容事件。
##
## 调用场景：城市节点收到 `InputEventMouseButton` 时。
## 主要逻辑：桌面环境下保留时间窗口去重，避免混合输入设备把一次点击重复派发为触摸和鼠标。
func _should_ignore_compat_mouse_tap() -> bool:
	if _last_touch_tap_time_ms < 0:
		return false
	return Time.get_ticks_msec() - _last_touch_tap_time_ms <= TOUCH_MOUSE_DEDUP_WINDOW_MS


## 输出城市节点自身收到的输入日志，帮助排查移动端一次轻触是否触发了 touch 与 mouse 两套事件。
##
## 调用场景：城市节点收到触摸、鼠标和去重判定事件时。
## 主要逻辑：统一格式化日志，输出城市编号和局部点击坐标，便于与主场景的全局坐标日志对照。
func _log_city_input_debug(tag: String, payload: Dictionary = {}) -> void:
	if not INPUT_DEBUG_LOG_ENABLED:
		return
	print("[city-input-debug] ", tag, " | ", JSON.stringify(payload))
