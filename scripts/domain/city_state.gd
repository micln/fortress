class_name CityState
extends RefCounted

const CityOwnerRef = preload("res://scripts/domain/city_owner.gd")

var city_id: int
var name: String
var position: Vector2
var owner: int
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
	p_soldiers: int,
	p_neighbors: Array[int]
) -> void:
	city_id = p_city_id
	name = p_name
	position = p_position
	owner = p_owner
	soldiers = p_soldiers
	neighbors = p_neighbors.duplicate()


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
