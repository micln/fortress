class_name PrototypePresetMapLoader
extends RefCounted

const PrototypeCityOwnerRef = preload("res://scripts/domain/prototype_city_owner.gd")
const PrototypeCityStateRef = preload("res://scripts/domain/prototype_city_state.gd")
const PrototypePresetMapDefinitionRef = preload("res://scripts/application/prototype_preset_map_definition.gd")


## 按当前对局配置构建第一阶段预设地图的运行时城市数组。
##
## 调用场景：主场景开局时替代随机地图生成器，或测试中验证预设地图结构。
## 主要逻辑：读取预设地图定义，先做模板合法性校验，再把 design canvas 坐标映射到运行时世界尺寸，
## 最后按当前总方数套用出生配置并生成 `PrototypeCityState` 数组。
func build_map(match_config: Dictionary, map_world_size: Vector2, _random: RandomNumberGenerator) -> Array:
	var definition = PrototypePresetMapDefinitionRef.new()
	var metadata: Dictionary = definition.get_metadata()
	var city_definitions: Array[Dictionary] = definition.get_city_definitions()
	var roads: Array[Vector2i] = definition.get_roads()
	var spawn_sets: Dictionary = definition.get_spawn_sets_by_faction_count()
	var player_count: int = int(match_config.get("player_count", 5))

	if not _validate_definition(metadata, city_definitions, roads, spawn_sets, player_count):
		return []

	var city_map: Dictionary = {}
	for city_definition: Dictionary in city_definitions:
		city_map[int(city_definition["id"])] = city_definition

	var adjacency: Dictionary = _build_adjacency(city_definitions, roads)
	var spawn_set: Dictionary = spawn_sets[player_count]
	var spawn_owners: Dictionary = _build_spawn_owners(spawn_set)
	var cities: Array = []
	for city_definition: Dictionary in city_definitions:
		var city_id: int = int(city_definition["id"])
		var level: int = int(city_definition["level"])
		var neighbors: Array[int] = []
		for neighbor_id: int in adjacency.get(city_id, []):
			neighbors.append(neighbor_id)
		cities.append(
			PrototypeCityStateRef.new(
				city_id,
				String(city_definition["name"]),
				_map_design_position_to_world(Vector2(city_definition["position"]), Vector2(metadata["design_canvas_size"]), map_world_size),
				int(spawn_owners.get(city_id, PrototypeCityOwnerRef.NEUTRAL)),
				level,
				int(PrototypeCityStateRef.LEVEL_CAPACITY[level]),
				int(city_definition["initial_soldiers"]),
				neighbors,
				int(city_definition["defense"]),
				float(city_definition["production_rate"])
			)
		)
	return cities


## 校验预设地图模板是否满足第一阶段运行要求。
##
## 调用场景：构建运行时地图前。
## 主要逻辑：检查城市 ID、道路引用、出生配置覆盖和连通性，尽早阻止非法模板进入主流程。
func _validate_definition(metadata: Dictionary, city_definitions: Array[Dictionary], roads: Array[Vector2i], spawn_sets: Dictionary, player_count: int) -> bool:
	var supported_counts: Array = metadata.get("supported_faction_counts", [])
	if not supported_counts.has(player_count):
		push_error("预设地图不支持 %d 方。" % player_count)
		return false
	if not spawn_sets.has(player_count):
		push_error("预设地图缺少 %d 方出生配置。" % player_count)
		return false

	var city_ids: Dictionary = {}
	for city_definition: Dictionary in city_definitions:
		var city_id: int = int(city_definition.get("id", -1))
		if city_id < 0 or city_ids.has(city_id):
			push_error("预设地图城市 ID 非法或重复：%d" % city_id)
			return false
		city_ids[city_id] = true

	for road: Vector2i in roads:
		if not city_ids.has(road.x) or not city_ids.has(road.y):
			push_error("预设地图道路引用了不存在的城市：%s" % [road])
			return false

	for faction_count_variant in spawn_sets.keys():
		var faction_count: int = int(faction_count_variant)
		var spawn_set: Dictionary = spawn_sets[faction_count]
		var used_ids: Dictionary = {}
		var player_city_id: int = int(spawn_set.get("player_city_id", -1))
		var ai_city_ids: Array = spawn_set.get("ai_city_ids", [])
		if not city_ids.has(player_city_id):
			push_error("预设地图玩家出生点不存在：%d" % player_city_id)
			return false
		if ai_city_ids.size() != faction_count - 1:
			push_error("预设地图 %d 方出生配置数量不正确。" % faction_count)
			return false
		used_ids[player_city_id] = true
		for ai_city_id_variant in ai_city_ids:
			var ai_city_id: int = int(ai_city_id_variant)
			if not city_ids.has(ai_city_id) or used_ids.has(ai_city_id):
				push_error("预设地图 AI 出生点非法或重复：%d" % ai_city_id)
				return false
			used_ids[ai_city_id] = true

	var adjacency: Dictionary = _build_adjacency(city_definitions, roads)
	return _is_connected(city_definitions, adjacency)


## 把设计画布坐标映射到当前运行时世界坐标。
##
## 调用场景：从模板数据生成运行时城市状态时。
## 主要逻辑：使用 design canvas 与当前 `map_world_size` 的比例进行线性缩放，保证预设图兼容当前大地图尺寸。
func _map_design_position_to_world(design_position: Vector2, design_canvas_size: Vector2, map_world_size: Vector2) -> Vector2:
	if design_canvas_size.x <= 0.0 or design_canvas_size.y <= 0.0:
		return design_position
	return Vector2(
		design_position.x / design_canvas_size.x * map_world_size.x,
		design_position.y / design_canvas_size.y * map_world_size.y
	)


## 根据道路列表构建城市邻接表。
##
## 调用场景：模板校验和运行时城市构建。
## 主要逻辑：为每个城市准备双向邻接数组，避免在多个阶段重复计算道路展开逻辑。
func _build_adjacency(city_definitions: Array[Dictionary], roads: Array[Vector2i]) -> Dictionary:
	var adjacency: Dictionary = {}
	for city_definition: Dictionary in city_definitions:
		adjacency[int(city_definition["id"])] = []
	for road: Vector2i in roads:
		if not adjacency[road.x].has(road.y):
			adjacency[road.x].append(road.y)
		if not adjacency[road.y].has(road.x):
			adjacency[road.y].append(road.x)
	return adjacency


## 把当前方数对应的出生配置转换成归属映射表。
##
## 调用场景：运行时城市构建阶段。
## 主要逻辑：玩家固定使用 `PLAYER`，AI 依次从 `AI_OWNER_START` 编号，未出现在出生配置中的城市保持中立。
func _build_spawn_owners(spawn_set: Dictionary) -> Dictionary:
	var owners: Dictionary = {
		int(spawn_set["player_city_id"]): PrototypeCityOwnerRef.PLAYER
	}
	var ai_city_ids: Array = spawn_set.get("ai_city_ids", [])
	for index: int in range(ai_city_ids.size()):
		owners[int(ai_city_ids[index])] = PrototypeCityOwnerRef.AI_OWNER_START + index
	return owners


## 判断当前模板道路结构是否整体连通。
##
## 调用场景：模板校验阶段。
## 主要逻辑：从第一座城市开始做 BFS，只要所有城市都可达，就认为该模板可用于第一阶段。
func _is_connected(city_definitions: Array[Dictionary], adjacency: Dictionary) -> bool:
	if city_definitions.is_empty():
		return false
	var start_id: int = int(city_definitions[0]["id"])
	var visited: Dictionary = {start_id: true}
	var queue: Array[int] = [start_id]
	while not queue.is_empty():
		var current_id: int = queue.pop_front()
		for neighbor_id: int in adjacency.get(current_id, []):
			if visited.has(neighbor_id):
				continue
			visited[neighbor_id] = true
			queue.append(neighbor_id)
	return visited.size() == city_definitions.size()
