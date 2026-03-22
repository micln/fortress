class_name MapGenerator
extends RefCounted

const FactionRef = preload("res://scripts/domain/faction.gd")
const CityRef = preload("res://scripts/domain/city.gd")
const RoadRef = preload("res://scripts/domain/road.gd")

const CITY_MARGIN_X: float = 90.0
const CITY_MARGIN_TOP: float = 180.0
const CITY_MARGIN_BOTTOM: float = 170.0
const MIN_CITY_DISTANCE: float = 140.0


## 生成一个适合竖屏操作的随机地图定义。
## 调用场景：新开局时由 `MainGame` 创建 `GameState` 前调用。
## 主要逻辑：先随机采样城市坐标并保证最小间距，再串联成基础连通图，
## 最后补充少量额外道路，使地图既可达又保留一定分支。
func generate(city_count: int, viewport_size: Vector2) -> Dictionary:
	var cities: Array = []
	var roads: Array = []
	var rng := RandomNumberGenerator.new()
	rng.randomize()

	for city_index: int in range(city_count):
		var position: Vector2 = _pick_city_position(rng, cities, viewport_size)
		var owner: int = FactionRef.Type.NEUTRAL
		var soldiers: int = rng.randi_range(2, 8)

		if city_index == 0:
			owner = FactionRef.Type.PLAYER
			soldiers = 10
		elif city_index == city_count - 1:
			owner = FactionRef.Type.ENEMY
			soldiers = 10

		cities.append(CityRef.new(city_index, position, owner, soldiers))

	for city_index: int in range(1, cities.size()):
		var nearest_id: int = _find_nearest_previous_city(city_index, cities)
		roads.append(RoadRef.new(city_index, nearest_id))

	for city_index: int in range(cities.size()):
		var closest_candidates: Array[int] = _find_closest_city_ids(city_index, cities, 2)
		for candidate_id: int in closest_candidates:
			if city_index == candidate_id:
				continue
			if _has_road(roads, city_index, candidate_id):
				continue
			if rng.randf() <= 0.45:
				roads.append(RoadRef.new(city_index, candidate_id))

	return {
		"cities": cities,
		"roads": roads,
	}


## 在视口可用区域内挑选一个不与已有城市过近的位置。
## 调用场景：地图生成时逐个放置城市调用。
## 主要逻辑：有限次数随机采样；若始终找不到完美点位，则返回距离约束下的最佳候选。
func _pick_city_position(rng: RandomNumberGenerator, existing_cities: Array, viewport_size: Vector2) -> Vector2:
	var best_position: Vector2 = Vector2(viewport_size.x * 0.5, viewport_size.y * 0.5)
	var best_distance_score: float = -1.0

	for _attempt: int in range(64):
		var candidate := Vector2(
			rng.randf_range(CITY_MARGIN_X, viewport_size.x - CITY_MARGIN_X),
			rng.randf_range(CITY_MARGIN_TOP, viewport_size.y - CITY_MARGIN_BOTTOM)
		)
		var min_distance: float = _calculate_min_distance(candidate, existing_cities)
		if min_distance >= MIN_CITY_DISTANCE:
			return candidate
		if min_distance > best_distance_score:
			best_distance_score = min_distance
			best_position = candidate

	return best_position


## 计算候选坐标到所有已有城市的最短距离。
## 调用场景：位置采样时用于筛选高质量点位。
## 主要逻辑：遍历已有城市，持续更新最小欧式距离。
func _calculate_min_distance(candidate: Vector2, existing_cities: Array) -> float:
	if existing_cities.is_empty():
		return INF

	var min_distance: float = INF
	for city in existing_cities:
		min_distance = min(min_distance, candidate.distance_to(city.position))
	return min_distance


## 找到当前城市在之前已生成城市中的最近邻，用于保证整张图连通。
## 调用场景：为每个新城市补一条基础道路时调用。
## 主要逻辑：只在前序城市中搜索，避免出现重复连接与孤立节点。
func _find_nearest_previous_city(city_index: int, cities: Array) -> int:
	var nearest_id: int = 0
	var nearest_distance: float = INF

	for previous_index: int in range(city_index):
		var distance_between: float = cities[city_index].position.distance_to(cities[previous_index].position)
		if distance_between < nearest_distance:
			nearest_distance = distance_between
			nearest_id = previous_index

	return nearest_id


## 为指定城市查找若干个最近邻城市编号，用于补充支线道路。
## 调用场景：基础连通图完成后生成额外道路时调用。
## 主要逻辑：先收集距离表，再按距离升序排序并截取前 `limit` 个。
func _find_closest_city_ids(city_index: int, cities: Array, limit: int) -> Array[int]:
	var sortable_distances: Array[Dictionary] = []

	for other_index: int in range(cities.size()):
		if other_index == city_index:
			continue
		sortable_distances.append({
			"id": other_index,
			"distance": cities[city_index].position.distance_to(cities[other_index].position),
		})

	sortable_distances.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
		return left["distance"] < right["distance"]
	)

	var results: Array[int] = []
	for entry: Dictionary in sortable_distances.slice(0, min(limit, sortable_distances.size())):
		results.append(entry["id"])
	return results


## 判断某两座城市之间是否已经存在道路。
## 调用场景：补充额外道路前做去重校验。
## 主要逻辑：遍历现有道路并执行无向连接判断。
func _has_road(roads: Array, city_a: int, city_b: int) -> bool:
	for road in roads:
		if road.connects(city_a, city_b):
			return true
	return false
