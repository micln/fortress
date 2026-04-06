class_name MarchOrder
extends RefCounted

const MODE_CONTINUOUS: String = "continuous"

var source_id: int
var target_id: int
var enabled: bool
var mode: String


## 初始化一条持续出兵任务。
##
## 调用场景：玩家或 AI 新建一条 `source -> target` 的持续任务时。
## 主要逻辑：只保存路线和模式，不携带人数或进攻/运兵类型；具体行为在调度时依据目标实时归属动态决定。
func _init(p_source_id: int, p_target_id: int, p_enabled: bool = true, p_mode: String = MODE_CONTINUOUS) -> void:
	source_id = p_source_id
	target_id = p_target_id
	enabled = p_enabled
	mode = p_mode


## 判断当前任务是否与另一条路线完全相同。
##
## 调用场景：注册任务前查重、切换关闭同一路线任务时。
## 主要逻辑：只比较源城和目标城，确保同一路线在系统内始终只有一个任务实例。
func matches_route(p_source_id: int, p_target_id: int) -> bool:
	return source_id == p_source_id and target_id == p_target_id


## 把任务转换成调试与 HUD 友好的字典快照。
##
## 调用场景：日志打印、右侧任务面板刷新、测试断言时。
## 主要逻辑：返回稳定字段集合，避免表现层直接依赖对象实例内部结构。
func to_dictionary() -> Dictionary:
	return {
		"source_id": source_id,
		"target_id": target_id,
		"enabled": enabled,
		"mode": mode
	}
