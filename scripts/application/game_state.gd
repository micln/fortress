class_name GameState
extends RefCounted

const FactionRef = preload("res://scripts/domain/faction.gd")
const BattleResolverRef = preload("res://scripts/domain/battle_resolver.gd")

var _cities: Dictionary = {}
var _roads: Array = []
var _adjacency: Dictionary = {}


## 使用城市与道路初始化整局游戏状态。
## 调用场景：新开局时由 `MainGame` 构造。
## 主要逻辑：缓存城市字典、道路数组与邻接表，供后续产兵、攻击和 AI 查询使用。
func _init(cities: Array, roads: Array) -> void:
	for city in cities:
		_cities[city.id] = city
		_adjacency[city.id] = []

	_roads = roads

	for road in roads:
		_adjacency[road.from_city_id].append(road.to_city_id)
		_adjacency[road.to_city_id].append(road.from_city_id)


## 推进一秒的经济生产，给已被占领城市各增加 1 名士兵。
## 调用场景：主循环每累计 1 秒后调用。
## 主要逻辑：遍历全部城市，仅为玩家和敌方占领城市加兵。
func tick_production() -> void:
	for city in _cities.values():
		if city.is_occupied():
			city.soldiers += 1


## 执行一次攻击，并在合法时返回结算结果。
## 调用场景：玩家点击相邻城市或敌方 AI 选定目标后调用。
## 主要逻辑：先校验归属、邻接与兵力，再用 `BattleResolver` 计算结果并回写城市状态。
func attack(attacker_city_id: int, defender_city_id: int, expected_owner: int) -> Dictionary:
	if not _cities.has(attacker_city_id) or not _cities.has(defender_city_id):
		return {"success": false, "reason": "invalid_city"}
	if not is_adjacent(attacker_city_id, defender_city_id):
		return {"success": false, "reason": "not_adjacent"}

	var attacker = _cities[attacker_city_id]
	var defender = _cities[defender_city_id]

	if attacker.owner != expected_owner:
		return {"success": false, "reason": "invalid_owner"}
	if attacker.owner == defender.owner:
		return {"success": false, "reason": "same_owner"}
	if attacker.soldiers <= 0:
		return {"success": false, "reason": "no_soldiers"}

	var resolution: Dictionary = BattleResolverRef.resolve_attack(attacker, defender)
	attacker.soldiers = resolution["attacker_remaining"]
	defender.owner = resolution["defender_owner"]
	defender.soldiers = resolution["defender_soldiers"]

	return {
		"success": true,
		"captured": resolution["captured"],
		"attacker_city_id": attacker_city_id,
		"defender_city_id": defender_city_id,
	}


## 获取指定城市的领域对象引用。
## 调用场景：表现层绘制、AI 决策、测试断言时调用。
## 主要逻辑：按城市编号从缓存字典中返回对象。
func get_city(city_id: int):
	return _cities[city_id]


## 获取全部城市的快照数组，供表现层安全读取。
## 调用场景：地图刷新、HUD 展示时调用。
## 主要逻辑：将字典值转换为数组并按编号排序，保证渲染顺序稳定。
func get_all_cities() -> Array:
	var cities: Array = []
	for city in _cities.values():
		cities.append(city)
	cities.sort_custom(func(left, right) -> bool:
		return left.id < right.id
	)
	return cities


## 获取全部道路定义。
## 调用场景：地图绘制道路时调用。
## 主要逻辑：直接返回当前道路数组引用，原型阶段不做动态改路。
func get_all_roads() -> Array:
	return _roads


## 判断两座城市是否直接由道路连接。
## 调用场景：攻击合法性校验与表现层高亮相邻节点时调用。
## 主要逻辑：查询初始化时构建好的邻接表。
func is_adjacent(city_a: int, city_b: int) -> bool:
	if not _adjacency.has(city_a):
		return false
	return city_b in _adjacency[city_a]


## 返回指定城市的所有相邻城市编号。
## 调用场景：敌方 AI 搜索候选目标、地图高亮可攻击节点时调用。
## 主要逻辑：从邻接表中读取对应数组，不存在时返回空数组。
func get_neighbor_ids(city_id: int) -> Array:
	if not _adjacency.has(city_id):
		return []
	return _adjacency[city_id].duplicate()


## 获取某一阵营当前拥有的全部城市。
## 调用场景：敌方 AI 选路、胜负判断、HUD 统计时调用。
## 主要逻辑：遍历全部城市，筛选归属匹配的条目。
func get_cities_owned_by(owner: int) -> Array:
	var results: Array = []
	for city in _cities.values():
		if city.owner == owner:
			results.append(city)
	return results


## 判断游戏是否已经出现胜利或失败结果。
## 调用场景：每次攻击后或每次产兵后由主场景检查。
## 主要逻辑：一方没有任何占领城市时，另一方立即获胜。
func get_winner() -> int:
	var player_count: int = get_cities_owned_by(FactionRef.Type.PLAYER).size()
	var enemy_count: int = get_cities_owned_by(FactionRef.Type.ENEMY).size()

	if player_count == 0 and enemy_count > 0:
		return FactionRef.Type.ENEMY
	if enemy_count == 0 and player_count > 0:
		return FactionRef.Type.PLAYER
	return FactionRef.Type.NEUTRAL
