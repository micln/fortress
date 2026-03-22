class_name City
extends RefCounted

const FactionRef = preload("res://scripts/domain/faction.gd")

var id: int
var position: Vector2
var owner: int
var soldiers: int


## 初始化城市实体，封装地图节点的基础状态。
## 调用场景：地图生成完成后由 `GameState` 或 `MapGenerator` 创建。
## 主要逻辑：记录城市编号、坐标、归属和当前士兵数量。
func _init(city_id: int, city_position: Vector2, city_owner: int, initial_soldiers: int) -> void:
	id = city_id
	position = city_position
	owner = city_owner
	soldiers = initial_soldiers


## 生成一个城市副本，避免展示层直接修改领域对象引用。
## 调用场景：向表现层发送快照或测试中比对状态时调用。
## 主要逻辑：按原值构造一个新的 `City` 实例。
func duplicate_city():
	return get_script().new(id, position, owner, soldiers)


## 判断当前城市是否由可产兵阵营占领。
## 调用场景：应用层推进每秒产兵时调用。
## 主要逻辑：委托 `Faction.is_occupied` 判断阵营归属。
func is_occupied() -> bool:
	return FactionRef.is_occupied(owner)
