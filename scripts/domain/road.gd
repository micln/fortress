class_name Road
extends RefCounted

var from_city_id: int
var to_city_id: int


## 初始化一条双向道路的数据实体。
## 调用场景：地图生成器构造城市连线关系时调用。
## 主要逻辑：仅保存两端城市编号，双向关系由 `GameState` 统一解释。
func _init(start_city_id: int, end_city_id: int) -> void:
	from_city_id = start_city_id
	to_city_id = end_city_id


## 判断道路是否连接指定的两个城市，不区分方向。
## 调用场景：校验攻击合法性、绘制地图连线时调用。
## 主要逻辑：比较两端城市编号集合是否一致。
func connects(city_a: int, city_b: int) -> bool:
	return (from_city_id == city_a and to_city_id == city_b) or (from_city_id == city_b and to_city_id == city_a)
