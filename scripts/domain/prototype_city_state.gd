class_name PrototypeCityState
extends RefCounted

const PrototypeCityOwnerRef = preload("res://scripts/domain/prototype_city_owner.gd")

var city_id: int
var name: String
var position: Vector2
var owner: int
var level: int
var max_soldiers: int
var soldiers: int
var neighbors: Array[int]


## 初始化一个城市的运行时状态。
##
## 调用场景：地图生成后创建城市数据对象。
## 主要逻辑：写入城市标识、坐标、归属、士兵数与邻接表，邻接表会复制一份避免外部共享引用。
func _init(
	p_city_id: int,
	p_name: String,
	p_position: Vector2,
	p_owner: int,
	p_level: int,
	p_max_soldiers: int,
	p_soldiers: int,
	p_neighbors: Array[int]
) -> void:
	city_id = p_city_id
	name = p_name
	position = p_position
	owner = p_owner
	level = p_level
	max_soldiers = p_max_soldiers
	soldiers = p_soldiers
	neighbors = p_neighbors.duplicate()


## 判断当前城市是否已被某一阵营占领。
##
## 调用场景：产兵循环、AI 选点、胜负判断。
## 主要逻辑：非中立阵营即视为被占领状态。
func is_occupied() -> bool:
	return owner != PrototypeCityOwnerRef.NEUTRAL


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
