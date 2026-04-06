class_name CityState
extends RefCounted

const CityOwnerRef = preload("res://scripts/domain/city_owner.gd")
const NODE_TYPE_NORMAL: String = "normal"
const NODE_TYPE_PASS: String = "pass"
const NODE_TYPE_HUB: String = "hub"
const NODE_TYPE_HEARTLAND: String = "heartland"
const LEVEL_CAPACITY: Dictionary = {
	1: 200,
	2: 350,
	3: 550,
	4: 800,
	5: 1100
}
const LEVEL_UPGRADE_COST: Dictionary = {
	1: 80,
	2: 140,
	3: 220,
	4: 320
}
const DEFENSE_UPGRADE_COST: Dictionary = {
	10: 60,
	20: 100,
	30: 150,
	40: 210,
	50: 280
}
const PRODUCTION_UPGRADE_STEP: float = 4.0
const PRODUCTION_UPGRADE_MAX: float = 30.0
const PRODUCTION_UPGRADE_COST_BASE: int = 70

var city_id: int
var name: String
var position: Vector2
var owner: int
var level: int
var defense: int
var production_rate: float
var max_soldiers: int
var soldiers: int
var neighbors: Array[int]
var node_type: String = NODE_TYPE_NORMAL
var _production_progress: float = 0.0


## 初始化一个城市的运行时状态。
##
## 调用场景：地图生成后创建城市数据对象。
## 主要逻辑：写入城市标识、坐标、归属、防御、产能、等级、士兵数与邻接表，
## 邻接表会复制一份避免外部共享引用；产能进度从 0 开始累计，供每秒产兵结算复用。
func _init(
	p_city_id: int,
	p_name: String,
	p_position: Vector2,
	p_owner: int,
	p_level: int,
	p_max_soldiers: int,
	p_soldiers: int,
	p_neighbors: Array[int],
	p_defense: int = 10,
	p_production_rate: float = 10.0,
	p_node_type: String = NODE_TYPE_NORMAL
) -> void:
	city_id = p_city_id
	name = p_name
	position = p_position
	owner = p_owner
	level = p_level
	defense = p_defense
	production_rate = p_production_rate
	max_soldiers = p_max_soldiers
	soldiers = p_soldiers
	neighbors = p_neighbors.duplicate()
	node_type = p_node_type
	_production_progress = 0.0


## 返回当前城市节点类型对应的中文展示名。
##
## 调用场景：表现层需要显示战略节点标签时。
## 主要逻辑：把运行时使用的英文节点类型常量统一映射成中文短标签，未知值回落为“普通”。
func get_node_type_display_name() -> String:
	match node_type:
		NODE_TYPE_PASS:
			return "关口"
		NODE_TYPE_HUB:
			return "枢纽"
		NODE_TYPE_HEARTLAND:
			return "腹地"
		_:
			return "普通"


## 判断当前城市是否已被某一阵营占领。
##
## 调用场景：产兵循环、AI 选点、胜负判断。
## 主要逻辑：非中立阵营即视为被占领状态。
func is_occupied() -> bool:
	return owner != CityOwnerRef.NEUTRAL


## 判断当前城市是否与指定城市相连。
##
## 调用场景：发起进攻前的合法性校验。
## 主要逻辑：在邻接列表中查找目标城市编号。
func is_neighbor(target_city_id: int) -> bool:
	return neighbors.has(target_city_id)


## 为城市增加指定数量士兵，并自动受人口上限约束。
##
## 调用场景：产兵、援军抵达、友军增援、失守援军被收编。
## 主要逻辑：把新增士兵累加到当前人数后，再按城市人口上限截断，避免超上限膨胀。
func add_soldiers(amount: int) -> void:
	soldiers = min(max_soldiers, soldiers + amount)


## 扣除指定数量士兵，并保证结果不会小于 0。
##
## 调用场景：玩家确认出兵、敌军下单、战斗失败结算。
## 主要逻辑：从当前兵力中减去指定值，再做下界保护，避免出现负兵力。
func remove_soldiers(amount: int) -> void:
	soldiers = max(0, soldiers - amount)


## 判断当前城市是否还能继续产兵。
##
## 调用场景：每秒产兵、UI 提示、后续升级设计。
## 主要逻辑：只有占领中的城市且当前兵力未达到上限时，才允许继续产兵。
func can_produce() -> bool:
	return is_occupied() and soldiers < max_soldiers


## 计算当前城市在攻城结算时的总防守需求。
##
## 调用场景：进攻推荐兵力、攻城预估、实际到城结算。
## 主要逻辑：把当前守军、预计路上新增守军和固定防御值相加，得到攻方至少需要匹配的总门槛；
## 但没有驻军的空城（含中立空城与已占领空城）不额外享受防御加成，避免“0 人守城却需要先破防”的违和体验。
func get_effective_defense(predicted_growth: int = 0) -> int:
	var has_garrison: bool = soldiers + max(0, predicted_growth) > 0
	var defense_bonus: int = max(0, defense) if is_occupied() and has_garrison else 0
	return soldiers + max(0, predicted_growth) + defense_bonus


## 为城市推进一次产能累计，并返回本次实际新产出的士兵数。
##
## 调用场景：每秒产兵 Tick。
## 主要逻辑：先把城市产能按秒累加到内部进度，再把其中的整数部分转成士兵；
## 若城市已满员或未被占领，则直接返回 0；若接近上限，则只产到容量上限并保留剩余小数进度。
func advance_production(delta_seconds: float = 1.0) -> int:
	if not can_produce():
		return 0

	_production_progress += max(0.0, production_rate * delta_seconds)
	var produced: int = int(floor(_production_progress))
	if produced <= 0:
		return 0

	var available_capacity: int = max_soldiers - soldiers
	var actual_produced: int = min(available_capacity, produced)
	soldiers += actual_produced
	_production_progress -= float(actual_produced)
	return actual_produced


## 仅累计一段时间内的产能进度，不直接把进度兑换成士兵。
##
## 调用场景：表现层需要把“产 1 人”和“发 1 人”交错执行时。
## 主要逻辑：无论当前是否满员，都先把这一段时间对应的产能累计到内部进度里；后续是否真的产出士兵由 `try_produce_one_soldier()` 单步决定。
func accumulate_production_progress(delta_seconds: float = 1.0) -> void:
	if not is_occupied():
		return
	_production_progress += max(0.0, production_rate * delta_seconds)


## 尝试把当前累计产能兑换成 1 名士兵。
##
## 调用场景：持续出兵系统需要“每产 1 人就立刻调度 1 次”时。
## 主要逻辑：只有当城市未满员且内部累计进度至少达到 1.0 时，才真正增加 1 名士兵并扣除 1.0 进度；
## 这样表现层就能在每次单步产兵后立刻执行一次持续任务，再继续判断这一秒内是否还能再产。
func try_produce_one_soldier() -> bool:
	if not can_produce():
		return false
	if _production_progress < 0.999:
		return false
	soldiers += 1
	_production_progress -= 1.0
	return true


## 返回当前累计产能最多还能立刻兑换出多少个“单步产兵事件”。
##
## 调用场景：持续出兵系统需要按“每产 1 人触发 1 次调度”循环消费产能时。
## 主要逻辑：只读取内部累计进度的整数部分，不关心城市当前是否满员；这样表现层可以在“满兵但有持续任务”的情况下先派兵，再继续消费同一秒的剩余产能。
func get_ready_production_count() -> int:
	return int(floor(_production_progress))


## 直接消费 1 次已经累计完成的产兵进度，不修改当前驻军人数。
##
## 调用场景：城市已满员但仍有持续任务时，需要把“本应产出的兵”直接转成一次出兵触发。
## 主要逻辑：仅当内部累计进度至少达到 1.0 时才扣减 1.0；是否真的派出士兵由表现层在同一轮里继续检查源城兵力与任务有效性。
func consume_one_ready_production() -> bool:
	if _production_progress < 0.999:
		return false
	_production_progress -= 1.0
	return true


## 丢弃当前已累计完成的整数产能次数，并保留小数部分。
##
## 调用场景：表现层确认“城市已满员且没有持续任务”时，避免把历史积压产能在后续容量恢复后瞬间全部兑换。
## 主要逻辑：返回被丢弃的整数次数，并把内部进度裁剪到 `[0, 1)` 区间，仅保留下一次产兵所需的小数进度。
func discard_ready_production() -> int:
	var dropped_count: int = int(floor(_production_progress))
	if dropped_count <= 0:
		return 0
	_production_progress -= float(dropped_count)
	return dropped_count


## 返回指定等级对应的人口上限。
##
## 调用场景：地图生成、等级升级、UI 展示未来升级收益时。
## 主要逻辑：优先读取配置表；若传入等级越界，则钳制到当前支持的最大等级范围内。
func get_capacity_for_level(target_level: int) -> int:
	var clamped_level: int = clamp(target_level, 1, get_max_level())
	return int(LEVEL_CAPACITY.get(clamped_level, LEVEL_CAPACITY[1]))


## 返回当前系统支持的最高城市等级。
##
## 调用场景：升级可行性判断、UI 按钮禁用状态。
## 主要逻辑：直接读取等级容量表的键数量，避免在多个文件里手写最大等级常量。
func get_max_level() -> int:
	return LEVEL_CAPACITY.size()


## 判断当前城市是否还能继续提升等级。
##
## 调用场景：升级按钮状态刷新、AI 决策。
## 主要逻辑：只有未达等级上限时才允许继续升级等级。
func can_upgrade_level() -> bool:
	return level < get_max_level()


## 返回当前城市升级等级所需的士兵数。
##
## 调用场景：升级按钮文案、升级结算、AI 估算成本。
## 主要逻辑：按“当前等级 -> 下一等级”的成本表读取，满级时返回 0。
func get_level_upgrade_cost() -> int:
	if not can_upgrade_level():
		return 0
	return int(LEVEL_UPGRADE_COST.get(level, 0))


## 判断当前城市是否还能继续提升防御。
##
## 调用场景：升级按钮状态刷新、AI 决策。
## 主要逻辑：防御采用 10 为步长的离散档位，达到 50 后停止继续提升，避免单城过度难攻。
func can_upgrade_defense() -> bool:
	return defense < 50


## 返回当前城市升级防御所需的士兵数。
##
## 调用场景：升级按钮文案、升级结算、AI 估算成本。
## 主要逻辑：防御越高，再往上堆的投入越大，以抑制纯龟缩策略。
func get_defense_upgrade_cost() -> int:
	if not can_upgrade_defense():
		return 0
	return int(DEFENSE_UPGRADE_COST.get(defense, 340))


## 判断当前城市是否还能继续提升产能。
##
## 调用场景：升级按钮状态刷新、AI 决策。
## 主要逻辑：产能按 4.0 一档提升，达到 30.0/秒 后停止，让每次升级都能明显改变持续出兵强度，同时避免后期爆兵失控。
func can_upgrade_production() -> bool:
	return production_rate < PRODUCTION_UPGRADE_MAX - 0.001


## 返回当前城市升级产能所需的士兵数。
##
## 调用场景：升级按钮文案、升级结算、AI 估算成本。
## 主要逻辑：当前产能越高，继续提升的成本越高，避免前期无脑只点产能最优。
func get_production_upgrade_cost() -> int:
	if not can_upgrade_production():
		return 0
	return int(round(PRODUCTION_UPGRADE_COST_BASE + production_rate * 6.0))


## 判断当前城市是否有足够兵力支付某次升级成本。
##
## 调用场景：升级按钮状态刷新、应用层升级校验。
## 主要逻辑：升级消耗直接来自城市驻军，因此必须保证当前兵力不少于成本。
func has_enough_soldiers_for_upgrade(cost: int) -> bool:
	return soldiers >= max(0, cost)


## 应用一次等级升级。
##
## 调用场景：应用层已完成合法性校验后。
## 主要逻辑：扣除升级成本、提升等级，并把容量更新到新等级对应上限。
func apply_level_upgrade() -> void:
	var cost: int = get_level_upgrade_cost()
	remove_soldiers(cost)
	level += 1
	max_soldiers = get_capacity_for_level(level)


## 应用一次防御升级。
##
## 调用场景：应用层已完成合法性校验后。
## 主要逻辑：扣除升级成本，并把固定防御值提高 1 档。
func apply_defense_upgrade() -> void:
	var cost: int = get_defense_upgrade_cost()
	remove_soldiers(cost)
	defense += 10


## 应用一次产能升级。
##
## 调用场景：应用层已完成合法性校验后。
## 主要逻辑：扣除升级成本，并按固定步长提升产能，保留一位小数避免浮点漂移。
func apply_production_upgrade() -> void:
	var cost: int = get_production_upgrade_cost()
	remove_soldiers(cost)
	production_rate = snappedf(min(PRODUCTION_UPGRADE_MAX, production_rate + PRODUCTION_UPGRADE_STEP), 0.1)
