class_name PrototypeMapGenerator
extends RefCounted

const PrototypeCityOwnerRef = preload("res://scripts/domain/prototype_city_owner.gd")
const PrototypeCityStateRef = preload("res://scripts/domain/prototype_city_state.gd")

const MAP_SIZE: Vector2 = Vector2(720.0, 1280.0)
const PADDING: Vector2 = Vector2(90.0, 220.0)
const MIN_CITY_DISTANCE: float = 170.0
const CITY_NAME_POOL: Array[String] = [
	"长安", "洛阳", "建康", "临安", "大梁", "邺城", "襄阳", "成都", "江陵", "会稽",
	"幽州", "并州", "凉州", "泉州", "扬州", "益州", "荆州", "寿春", "宛城", "汴州",
	"金陵", "广陵", "姑苏", "晋阳", "涿郡", "琅琊", "番禺", "交州", "武威", "敦煌"
]
const LEVEL_CAPACITY: Dictionary = {
	1: 20,
	2: 35,
	3: 55
}


## 生成一张连通的竖屏地图，并返回所有城市状态。
##
## 调用场景：开局初始化或后续重开战局。
## 主要逻辑：先随机生成满足最小间距的城市坐标，再基于纵向排序与最近邻补边构造连通道路，
## 最后按开局电脑数量为玩家和多个 AI 势力分配起始城市，其余城市保持中立。
func generate_map(city_count: int, random: RandomNumberGenerator, ai_count: int = 1) -> Array:
	var positions: Array[Vector2] = _generate_positions(city_count, random)
	var graph: Dictionary = _build_graph(positions)
	var city_names: Array[String] = _pick_city_names(city_count, random)
	var start_owners: Dictionary = _pick_start_owners(positions, ai_count)
	var cities: Array = []

	for index: int in range(city_count):
		var owner: int = int(start_owners.get(index, PrototypeCityOwnerRef.NEUTRAL))
		var level: int = random.randi_range(1, 3)
		var max_soldiers: int = int(LEVEL_CAPACITY[level])
		var soldiers: int = random.randi_range(3, min(7, max_soldiers))
		if owner == PrototypeCityOwnerRef.PLAYER:
			level = 2
			max_soldiers = int(LEVEL_CAPACITY[level])
			soldiers = 14
		elif PrototypeCityOwnerRef.is_ai(owner):
			level = 2
			max_soldiers = int(LEVEL_CAPACITY[level])
			soldiers = max(8, 11 - ai_count)

		var neighbors: Array[int] = []
		for neighbor_id: int in graph.get(index, []):
			neighbors.append(neighbor_id)

		cities.append(
			PrototypeCityStateRef.new(
				index,
				city_names[index],
				positions[index],
				owner,
				level,
				max_soldiers,
				soldiers,
				neighbors
			)
		)

	return cities


## 为玩家与多个 AI 势力挑选彼此分散的开局主城。
##
## 调用场景：地图生成流程内部。
## 主要逻辑：按城市纵向位置排序后等距抽样，让多个开局势力尽量铺开在整张地图上，减少贴脸出生。
func _pick_start_owners(positions: Array[Vector2], ai_count: int) -> Dictionary:
	var faction_count: int = clamp(ai_count + 1, 2, min(positions.size(), 5))
	var sorted_ids: Array[int] = []
	for index: int in range(positions.size()):
		sorted_ids.append(index)
	sorted_ids.sort_custom(func(a: int, b: int) -> bool: return positions[a].y < positions[b].y)

	var start_owners: Dictionary = {}
	for slot: int in range(faction_count):
		var ratio: float = float(slot) / float(max(1, faction_count - 1))
		var candidate_index: int = int(round(ratio * float(sorted_ids.size() - 1)))
		var city_id: int = sorted_ids[candidate_index]
		while start_owners.has(city_id):
			candidate_index = min(candidate_index + 1, sorted_ids.size() - 1)
			city_id = sorted_ids[candidate_index]

		if slot == 0:
			start_owners[city_id] = PrototypeCityOwnerRef.PLAYER
		else:
			start_owners[city_id] = PrototypeCityOwnerRef.AI_OWNER_START + slot - 1
	return start_owners


## 从古代中国城市候选集合中随机抽取并排序出本局使用的城市名。
##
## 调用场景：地图生成流程内部。
## 主要逻辑：先复制候选池并做 Fisher-Yates 洗牌，再截取所需数量；如果城市数量超过候选池，就附加序号避免重名。
func _pick_city_names(city_count: int, random: RandomNumberGenerator) -> Array[String]:
	var pool: Array[String] = CITY_NAME_POOL.duplicate()
	for index: int in range(pool.size() - 1, 0, -1):
		var swap_index: int = random.randi_range(0, index)
		var temp_name: String = pool[index]
		pool[index] = pool[swap_index]
		pool[swap_index] = temp_name

	var names: Array[String] = []
	for index: int in range(city_count):
		var base_name: String = pool[index % pool.size()]
		if index >= pool.size():
			var suffix: int = int(floor(float(index) / float(pool.size()))) + 1
			names.append("%s%d" % [base_name, suffix])
		else:
			names.append(base_name)
	return names


## 在竖屏区域内生成满足最小距离约束的城市坐标。
##
## 调用场景：地图生成流程内部。
## 主要逻辑：采用有限次随机尝试，若候选点与已有点的最小距离不足则丢弃；
## 若随机阶段未凑够数量，再使用兜底网格点补齐，避免生成失败。
func _generate_positions(city_count: int, random: RandomNumberGenerator) -> Array[Vector2]:
	var positions: Array[Vector2] = []
	var attempts: int = 0

	while positions.size() < city_count and attempts < 4000:
		attempts += 1
		var candidate := Vector2(
			random.randf_range(PADDING.x, MAP_SIZE.x - PADDING.x),
			random.randf_range(PADDING.y, MAP_SIZE.y - PADDING.y)
		)
		var valid: bool = true
		for existing: Vector2 in positions:
			if existing.distance_to(candidate) < MIN_CITY_DISTANCE:
				valid = false
				break
		if valid:
			positions.append(candidate)

	if positions.size() < city_count:
		for row: int in range(5):
			for col: int in range(3):
				if positions.size() >= city_count:
					break
				var fallback := Vector2(
					150.0 + float(col) * 210.0,
					260.0 + float(row) * 190.0
				)
				var fallback_valid: bool = true
				for existing: Vector2 in positions:
					if existing.distance_to(fallback) < MIN_CITY_DISTANCE * 0.75:
						fallback_valid = false
						break
				if fallback_valid:
					positions.append(fallback)

	return positions


## 为城市坐标构建一个无向连通图。
##
## 调用场景：地图生成流程内部。
## 主要逻辑：先按 y 坐标排序后串联相邻节点，确保从上到下至少形成一条主链；
## 再给每个城市补充若干最近邻边，提升战术选择和地图观感。
func _build_graph(positions: Array[Vector2]) -> Dictionary:
	var graph: Dictionary = {}
	for index: int in range(positions.size()):
		graph[index] = []

	var sorted_ids: Array[int] = []
	for index: int in range(positions.size()):
		sorted_ids.append(index)
	sorted_ids.sort_custom(func(a: int, b: int) -> bool: return positions[a].y < positions[b].y)

	for index: int in range(sorted_ids.size() - 1):
		_connect(graph, sorted_ids[index], sorted_ids[index + 1])

	for city_id: int in range(positions.size()):
		var distances: Array[Dictionary] = []
		for other_id: int in range(positions.size()):
			if city_id == other_id:
				continue
			distances.append({
				"id": other_id,
				"distance": positions[city_id].distance_to(positions[other_id])
			})
		distances.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["distance"] < b["distance"])

		for index: int in range(min(2, distances.size())):
			_connect(graph, city_id, int(distances[index]["id"]))

	return graph


## 在图结构中建立一条双向道路。
##
## 调用场景：构建主链和补充近邻边。
## 主要逻辑：分别向两个城市的邻接表写入对方编号，并避免重复边。
func _connect(graph: Dictionary, a: int, b: int) -> void:
	if not graph[a].has(b):
		graph[a].append(b)
	if not graph[b].has(a):
		graph[b].append(a)
