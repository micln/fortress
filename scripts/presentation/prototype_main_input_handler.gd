extends RefCounted

var _is_game_over: Callable
var _is_game_started: Callable
var _is_manual_paused: Callable
var _is_order_dialog_visible: Callable
var _is_overlay_visible: Callable
var _get_selected_city_id: Callable

var _log_input_debug: Callable
var _can_start_map_drag: Callable
var _consume_input: Callable
var _get_map_offset: Callable
var _set_map_offset: Callable
var _get_map_zoom: Callable
var _set_map_zoom: Callable
var _should_ignore_selection_cancel: Callable
var _clear_selection_with_message: Callable

const MAP_ZOOM_STEP: float = 0.1
const DRAG_START_DISTANCE: float = 18.0
const DEFAULT_SELECTION_CANCEL_GUARD_COUNT: int = 2

var _is_dragging_map: bool = false
var _drag_candidate_active: bool = false
var _drag_pointer_kind: String = ""
var _drag_pointer_index: int = -1
var _drag_press_position: Vector2 = Vector2.ZERO
var _drag_last_position: Vector2 = Vector2.ZERO
var _active_touch_points: Dictionary = {}
var _is_pinching_map: bool = false
var _pinch_last_distance: float = 0.0
var _selection_cancel_guard_count: int = 0


## 注入输入处理所需的状态读取与回调函数。
##
## 调用场景：主场景 `_ready()` 初始化阶段。
## 主要逻辑：把主场景输入相关依赖收敛为 Callables，避免通过字符串 `get/call` 反射访问主场景。
func setup(
	is_game_over: Callable,
	is_game_started: Callable,
	is_manual_paused: Callable,
	is_order_dialog_visible: Callable,
	is_overlay_visible: Callable,
	get_selected_city_id: Callable,
	log_input_debug: Callable,
	can_start_map_drag: Callable,
	consume_input: Callable,
	get_map_offset: Callable,
	set_map_offset: Callable,
	get_map_zoom: Callable,
	set_map_zoom: Callable,
	should_ignore_selection_cancel: Callable,
	clear_selection_with_message: Callable
) -> void:
	_is_game_over = is_game_over
	_is_game_started = is_game_started
	_is_manual_paused = is_manual_paused
	_is_order_dialog_visible = is_order_dialog_visible
	_is_overlay_visible = is_overlay_visible
	_get_selected_city_id = get_selected_city_id
	_log_input_debug = log_input_debug
	_can_start_map_drag = can_start_map_drag
	_consume_input = consume_input
	_get_map_offset = get_map_offset
	_set_map_offset = set_map_offset
	_get_map_zoom = get_map_zoom
	_set_map_zoom = set_map_zoom
	_should_ignore_selection_cancel = should_ignore_selection_cancel
	_clear_selection_with_message = clear_selection_with_message


## 清理拖拽与双指缩放的临时状态。
##
## 调用场景：重开一局、重置地图或进入不允许手势的状态前。
## 主要逻辑：重置拖拽候选、拖拽进行中与双指缩放的内部缓存，避免下一局沿用旧触点集合。
func reset_gestures() -> void:
	_is_dragging_map = false
	_drag_candidate_active = false
	_drag_pointer_kind = ""
	_drag_pointer_index = -1
	_drag_press_position = Vector2.ZERO
	_drag_last_position = Vector2.ZERO
	_active_touch_points.clear()
	_is_pinching_map = false
	_pinch_last_distance = 0.0
	_selection_cancel_guard_count = 0


## 武装一次“释放时不要立刻取消选城”的保护窗口。
##
## 调用场景：城市节点刚完成选中（或主脚本刚处理完 city_pressed）后。
## 主要逻辑：移动端/浏览器可能在同一轮输入中继续派发 release/unhandled release，这里用一个短计数吞掉后续取消选城逻辑。
func arm_selection_cancel_guard(count: int = DEFAULT_SELECTION_CANCEL_GUARD_COUNT) -> void:
	_selection_cancel_guard_count = max(0, count)
	if _log_input_debug.is_valid() and _get_selected_city_id.is_valid():
		_log_input_debug.call("cancel_guard_armed", {
			"count": _selection_cancel_guard_count,
			"selected_city_id": int(_get_selected_city_id.call())
		})


func _consume_selection_cancel_guard() -> bool:
	if _selection_cancel_guard_count <= 0:
		return false
	_selection_cancel_guard_count -= 1
	if _log_input_debug.is_valid() and _get_selected_city_id.is_valid():
		_log_input_debug.call("cancel_guard_consumed", {
			"remaining": _selection_cancel_guard_count,
			"selected_city_id": int(_get_selected_city_id.call())
		})
	return true


## 处理主输入事件（优先级高于未处理输入）。
##
## 调用场景：主场景 `_input(event)`。
## 主要逻辑：分发鼠标滚轮、鼠标拖拽、触摸拖拽与屏幕拖动；并打印结构化输入日志。
func handle_input(event: InputEvent) -> void:
	if not _is_game_started.is_valid() or not _is_game_over.is_valid():
		return
	if bool(_is_game_over.call()) or not bool(_is_game_started.call()):
		return
	if _is_manual_paused.is_valid() and bool(_is_manual_paused.call()):
		return
	if _is_order_dialog_visible.is_valid() and bool(_is_order_dialog_visible.call()):
		return
	if _is_overlay_visible.is_valid() and bool(_is_overlay_visible.call()):
		return

	if event is InputEventMouseButton:
		if _handle_mouse_wheel_zoom(event):
			return
		if int(event.button_index) != MOUSE_BUTTON_LEFT:
			return
		if bool(event.pressed) and _selection_cancel_guard_count > 0:
			if _log_input_debug.is_valid() and _get_selected_city_id.is_valid():
				_log_input_debug.call("clear_cancel_guard_on_mouse_press", {
					"selected_city_id": int(_get_selected_city_id.call()),
					"remaining": _selection_cancel_guard_count,
					"position": event.position
				})
			_selection_cancel_guard_count = 0
		if _log_input_debug.is_valid() and _get_selected_city_id.is_valid():
			_log_input_debug.call("mouse_button", {
				"pressed": bool(event.pressed),
				"position": event.position,
				"selected_city_id": int(_get_selected_city_id.call())
			})
		_handle_mouse_drag_input(event)
		return

	if event is InputEventMouseMotion:
		_handle_mouse_motion_input(event)
		return

	if event is InputEventScreenTouch:
		if bool(event.pressed) and _selection_cancel_guard_count > 0:
			if _log_input_debug.is_valid() and _get_selected_city_id.is_valid():
				_log_input_debug.call("clear_cancel_guard_on_touch_press", {
					"selected_city_id": int(_get_selected_city_id.call()),
					"remaining": _selection_cancel_guard_count,
					"index": int(event.index),
					"position": event.position
				})
			_selection_cancel_guard_count = 0
		if _log_input_debug.is_valid() and _get_selected_city_id.is_valid():
			_log_input_debug.call("screen_touch", {
				"pressed": bool(event.pressed),
				"index": int(event.index),
				"position": event.position,
				"selected_city_id": int(_get_selected_city_id.call())
			})
		_handle_touch_drag_input(event)
		return

	if event is InputEventScreenDrag:
		if _log_input_debug.is_valid() and _get_selected_city_id.is_valid():
			_log_input_debug.call("screen_drag", {
				"index": int(event.index),
				"position": event.position,
				"selected_city_id": int(_get_selected_city_id.call())
			})
		_handle_screen_drag_input(event)
		return


## 处理未被消费的释放事件，用于“空白取消选城”。
##
## 调用场景：主场景 `_unhandled_input(event)`。
## 主要逻辑：仅在对局进行、非暂停且无弹窗遮罩时处理 release；避免与城市点击重复消费。
func handle_unhandled_input(event: InputEvent) -> void:
	if not _is_game_started.is_valid() or not _is_game_over.is_valid() or not _is_manual_paused.is_valid():
		return
	if bool(_is_game_over.call()) or not bool(_is_game_started.call()) or bool(_is_manual_paused.call()):
		return
	if _is_order_dialog_visible.is_valid() and bool(_is_order_dialog_visible.call()):
		return
	if _is_overlay_visible.is_valid() and bool(_is_overlay_visible.call()):
		return

	if event is InputEventMouseButton and int(event.button_index) == MOUSE_BUTTON_LEFT and not bool(event.pressed):
		if _consume_selection_cancel_guard():
			_consume_if_possible()
			return
		if _log_input_debug.is_valid() and _get_selected_city_id.is_valid():
			_log_input_debug.call("unhandled_mouse_release", {
				"position": event.position,
				"selected_city_id": int(_get_selected_city_id.call())
			})
		_try_cancel_selection(event.position)
		return

	if event is InputEventScreenTouch and not bool(event.pressed):
		if _consume_selection_cancel_guard():
			_consume_if_possible()
			return
		if _log_input_debug.is_valid() and _get_selected_city_id.is_valid():
			_log_input_debug.call("unhandled_touch_release", {
				"index": int(event.index),
				"position": event.position,
				"selected_city_id": int(_get_selected_city_id.call())
			})
		_try_cancel_selection(event.position)
		return


## 尝试把一次空白释放转换为“取消选城”。
##
## 调用场景：`handle_unhandled_input()` 收到鼠标或触摸抬起事件时。
## 主要逻辑：若当前无选中城市则直接返回；命中 UI/城市时跳过；否则触发清空选中并消费输入，避免同轮事件继续冒泡。
func _try_cancel_selection(pointer_position: Vector2) -> void:
	if not _get_selected_city_id.is_valid():
		return
	if int(_get_selected_city_id.call()) == -1:
		return
	if _should_ignore_selection_cancel.is_valid() and bool(_should_ignore_selection_cancel.call(pointer_position)):
		return
	if _clear_selection_with_message.is_valid():
		_clear_selection_with_message.call("已取消选择。重新点一个蓝色城市即可。")
	_consume_if_possible()


## 处理桌面滚轮缩放，消费事件并保持锚点稳定。
##
## 调用场景：`handle_input()` 收到 `InputEventMouseButton` 时优先调用。
## 主要逻辑：只识别滚轮上/下；以鼠标位置为锚点调用注入的 `set_map_zoom()`，并通过 `consume_input()` 标记已处理。
func _handle_mouse_wheel_zoom(event: InputEventMouseButton) -> bool:
	if not _get_map_zoom.is_valid() or not _set_map_zoom.is_valid():
		return false
	if int(event.button_index) == MOUSE_BUTTON_WHEEL_UP:
		_set_map_zoom.call(float(_get_map_zoom.call()) + MAP_ZOOM_STEP, event.position)
		_consume_if_possible()
		return true
	if int(event.button_index) == MOUSE_BUTTON_WHEEL_DOWN:
		_set_map_zoom.call(float(_get_map_zoom.call()) - MAP_ZOOM_STEP, event.position)
		_consume_if_possible()
		return true
	return false


## 处理鼠标左键按下/抬起，用于区分拖拽与点击。
##
## 调用场景：`handle_input()` 收到 `InputEventMouseButton` 且是左键时。
## 主要逻辑：按下时若允许拖拽则进入候选态；抬起时结束候选，若发生过拖拽则消费输入避免触发取消选城。
func _handle_mouse_drag_input(event: InputEventMouseButton) -> void:
	if bool(event.pressed):
		if _can_start_map_drag.is_valid() and bool(_can_start_map_drag.call(event.position)):
			_begin_map_drag_candidate(event.position, "mouse")
		return

	if _finish_map_drag("mouse"):
		_consume_if_possible()


## 处理鼠标移动事件，用于更新地图拖拽。
##
## 调用场景：`handle_input()` 收到 `InputEventMouseMotion`。
## 主要逻辑：若当前处于拖拽候选或拖拽态，则增量更新地图 offset 并消费输入。
func _handle_mouse_motion_input(event: InputEventMouseMotion) -> void:
	if _update_map_drag(event.position):
		_consume_if_possible()


## 处理移动端/Web 的触摸开始与结束事件。
##
## 调用场景：`handle_input()` 收到 `InputEventScreenTouch`。
## 主要逻辑：维护活动触点；第二指按下时启动 pinch 并取消单指拖拽；单指按下时记录拖拽候选；抬起时若发生过拖拽则消费输入。
func _handle_touch_drag_input(event: InputEventScreenTouch) -> void:
	_update_active_touch_point(int(event.index), event.position, bool(event.pressed))

	if _active_touch_points.size() >= 2:
		if bool(event.pressed) and not _is_pinching_map:
			_begin_pinch_zoom()
		return

	if _is_pinching_map and _active_touch_points.size() < 2:
		_end_pinch_zoom()

	if bool(event.pressed):
		if _can_start_map_drag.is_valid() and bool(_can_start_map_drag.call(event.position)):
			_begin_map_drag_candidate(event.position, "touch", int(event.index))
		return

	if _finish_map_drag("touch", int(event.index)):
		_consume_if_possible()


## 处理活动触摸移动事件，用于单指拖拽或双指缩放。
##
## 调用场景：`handle_input()` 收到 `InputEventScreenDrag`。
## 主要逻辑：先更新触点坐标；双指时优先 pinch；单指时仅在当前指针匹配拖拽候选时更新 offset。
func _handle_screen_drag_input(event: InputEventScreenDrag) -> void:
	if _active_touch_points.has(int(event.index)):
		_active_touch_points[int(event.index)] = event.position

	if _active_touch_points.size() >= 2 and _update_pinch_zoom():
		_consume_if_possible()
		return

	if _drag_pointer_kind != "touch" or _drag_pointer_index != int(event.index):
		return

	if _update_map_drag(event.position):
		_consume_if_possible()


## 更新地图拖拽（候选态与拖拽态统一入口）。
##
## 调用场景：鼠标移动、触摸拖动、屏幕拖拽时。
## 主要逻辑：超过阈值后进入拖拽态，并用指针增量更新 map_offset。
func _update_map_drag(pointer_position: Vector2) -> bool:
	if not _drag_candidate_active:
		return false
	if not _is_dragging_map and pointer_position.distance_to(_drag_press_position) < DRAG_START_DISTANCE:
		return false
	if not _get_map_offset.is_valid() or not _set_map_offset.is_valid():
		return false

	_is_dragging_map = true
	var delta: Vector2 = pointer_position - _drag_last_position
	_drag_last_position = pointer_position
	_set_map_offset.call(Vector2(_get_map_offset.call()) + delta)
	return true


## 记录一次地图拖拽候选。
##
## 调用场景：鼠标按下或触摸开始时。
## 主要逻辑：缓存指针种类、编号和起点；后续只有同一指针移动超过阈值才会进入拖拽态。
func _begin_map_drag_candidate(pointer_position: Vector2, pointer_kind: String, pointer_index: int = -1) -> void:
	_drag_candidate_active = true
	_drag_pointer_kind = pointer_kind
	_drag_pointer_index = pointer_index
	_drag_press_position = pointer_position
	_drag_last_position = pointer_position
	_is_dragging_map = false


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
	if touch_pair.size() < 2:
		return
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
	if not _get_map_zoom.is_valid() or not _set_map_zoom.is_valid():
		return false
	var touch_pair: Array[Vector2] = _get_first_two_touch_positions()
	if touch_pair.size() < 2:
		return false
	var current_distance: float = touch_pair[0].distance_to(touch_pair[1])
	if current_distance <= 0.0 or _pinch_last_distance <= 0.0:
		_pinch_last_distance = current_distance
		return false
	var ratio: float = current_distance / _pinch_last_distance
	_pinch_last_distance = current_distance
	var center: Vector2 = (touch_pair[0] + touch_pair[1]) * 0.5
	_set_map_zoom.call(float(_get_map_zoom.call()) * ratio, center)
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


func _consume_if_possible() -> void:
	if _consume_input.is_valid():
		_consume_input.call()
