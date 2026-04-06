class_name MatchTelemetry
extends RefCounted

## 对局观测与统计收敛器（日志 + 窗口统计）。
##
## 调用场景：主场景与输入模块需要记录结构化日志、以及“持续出兵最近 1 秒统计”时。
## 主要逻辑：把日志开关与统计窗口状态从主控制器里抽出来，避免表现层上帝对象继续膨胀；
## 该类不依赖场景树，便于在 headless 测试或纯逻辑回归时复用。

const INPUT_DEBUG_LOG_ENABLED: bool = true
const GAME_DEBUG_LOG_ENABLED: bool = true

var _continuous_dispatch_count_in_window: int = 0
var _continuous_dispatch_soldiers_in_window: int = 0
var _continuous_dispatch_window_elapsed: float = 0.0
var _continuous_dispatch_last_second_count: int = 0
var _continuous_dispatch_last_second_soldiers: int = 0
var _continuous_dispatch_counts_by_source_in_window: Dictionary = {}
var _continuous_dispatch_counts_by_source_last_second: Dictionary = {}


## 返回输入调试日志开关是否启用。
func is_input_debug_enabled() -> bool:
	return INPUT_DEBUG_LOG_ENABLED


## 返回关键玩法流程日志开关是否启用。
func is_game_debug_enabled() -> bool:
	return GAME_DEBUG_LOG_ENABLED


## 统一输出输入调试日志，避免点击链路排查时日志格式混乱。
##
## 调用场景：输入事件、选城事件、取消事件以及命中测试排查时。
## 主要逻辑：把来源标签和上下文字典格式化为单行日志，方便在浏览器 Console 中按关键字搜索与对照。
func log_input_debug(tag: String, payload: Dictionary = {}) -> void:
	if not INPUT_DEBUG_LOG_ENABLED:
		return
	print("[input-debug] ", tag, " | ", JSON.stringify(payload))


## 统一输出关键玩法流程日志，便于排查出兵、持续任务和战斗结算问题。
##
## 调用场景：关键动作发生时，例如选城、开单、注册持续任务、产兵、发兵、到达、占城和胜负结算。
## 主要逻辑：使用稳定的单行 JSON 结构打印，方便后续按标签过滤和复盘事件顺序。
func log_game_debug(tag: String, payload: Dictionary = {}) -> void:
	if not GAME_DEBUG_LOG_ENABLED:
		return
	print("[game-debug] ", tag, " | ", JSON.stringify(payload))


## 重置“持续出兵最近 1 秒统计窗口”状态。
##
## 调用场景：新开一局、重新开始、或需要清空上一局统计数据时。
## 主要逻辑：清空当前窗口累计与上一秒快照，避免旧局数据污染新局 HUD 展示。
func reset_continuous_dispatch_window() -> void:
	_continuous_dispatch_count_in_window = 0
	_continuous_dispatch_soldiers_in_window = 0
	_continuous_dispatch_window_elapsed = 0.0
	_continuous_dispatch_last_second_count = 0
	_continuous_dispatch_last_second_soldiers = 0
	_continuous_dispatch_counts_by_source_in_window.clear()
	_continuous_dispatch_counts_by_source_last_second.clear()


## 推进持续出兵统计窗口，并在跨过 1 秒边界时滚动快照。
##
## 调用场景：主场景 `_process(delta)` 每帧推进时。
## 主要逻辑：累计经过时间；达到 1 秒后把窗口累计写入“最近 1 秒”快照，然后清空窗口累计并返回 true。
func advance_continuous_dispatch_window(delta: float) -> bool:
	_continuous_dispatch_window_elapsed += delta
	if _continuous_dispatch_window_elapsed < 1.0:
		return false

	_continuous_dispatch_window_elapsed -= 1.0
	_continuous_dispatch_last_second_count = _continuous_dispatch_count_in_window
	_continuous_dispatch_last_second_soldiers = _continuous_dispatch_soldiers_in_window
	_continuous_dispatch_counts_by_source_last_second = _continuous_dispatch_counts_by_source_in_window.duplicate(true)
	_continuous_dispatch_count_in_window = 0
	_continuous_dispatch_soldiers_in_window = 0
	_continuous_dispatch_counts_by_source_in_window.clear()
	return true


## 记录一次持续出兵真实下发事件，计入当前 1 秒窗口。
##
## 调用场景：持续任务触发并实际创建行军单位时。
## 主要逻辑：累计次数、兵力总量，并按源城维度统计触发次数，供 HUD 或调试用途复用。
func record_continuous_dispatch(source_id: int, troop_count: int) -> void:
	_continuous_dispatch_count_in_window += 1
	_continuous_dispatch_soldiers_in_window += troop_count
	_continuous_dispatch_counts_by_source_in_window[source_id] = int(_continuous_dispatch_counts_by_source_in_window.get(source_id, 0)) + 1


## 返回最近 1 秒持续出兵触发次数。
func get_last_second_dispatch_count() -> int:
	return _continuous_dispatch_last_second_count


## 返回最近 1 秒持续出兵触发的总兵量。
func get_last_second_dispatch_soldiers() -> int:
	return _continuous_dispatch_last_second_soldiers


## 返回最近 1 秒“按源城统计”的触发次数快照。
func get_last_second_dispatch_counts_by_source() -> Dictionary:
	return _continuous_dispatch_counts_by_source_last_second
