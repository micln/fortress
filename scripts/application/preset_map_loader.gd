class_name PresetMapLoader
extends RefCounted

const CityOwnerRef = preload("res://scripts/domain/city_owner.gd")
const CityStateRef = preload("res://scripts/domain/city_state.gd")
const PresetMapDefinitionRef = preload("res://scripts/application/preset_map_definition.gd")
const MapRegistryRef = preload("res://scripts/application/map_registry.gd")
const DESIGN_CANVAS_MIN_CITY_DISTANCE: float = 110.0
const PASS_DEFENSE_BONUS: int = 10
const HUB_PRODUCTION_BONUS: float = 2.0
const HEARTLAND_SOLDIER_BONUS: int = 20

var _last_error_message: String = ""
var _current_map_id: String = ""


## 按当前对局配置构建预设地图的运行时城市数组。
##
## 调用场景：主场景开局时替代随机地图生成器，或测试中验证预设地图结构。
## 主要逻辑：从注册表获取指定地图的定义，先做模板合法性校验，再把 design canvas 坐标映射到运行时世界尺寸，
## 最后按当前总方数套用出生配置并生成 `CityState` 数组。
func build_map(match_config: Dictionary, map_world_size: Vector2, _random: RandomNumberGenerator, map_id: String = "") -> Array:
	_last_error_message = ""
	var definition: RefCounted = null

	# 未指定 map_id 时，回退到内置中国预设图，保持测试与旧入口契约稳定。
	# 指定 map_id 时，才走地图注册表加载关卡地图。
	if map_id.is_empty():
		definition = PresetMapDefinitionRef.new()
		_current_map_id = String(definition.get_metadata().get("id", "china_central_plains_v1"))
	else:
		var registry = MapRegistryRef.get_instance()
		definition = registry.get_map_definition(map_id)
		_current_map_id = map_id
		if definition == null:
			_last_error_message = "未找到地图: %s" % map_id
			push_error(_last_error_message)
			return []

	var metadata: Dictionary = definition.get_metadata()
	var city_definitions: Array[Dictionary] = definition.get_city_definitions()
	var roads: Array[Vector2i] = definition.get_roads()
	var spawn_sets: Dictionary = definition.get_spawn_sets_by_faction_count()
	var player_count: int = int(match_config.get("player_count", 5))

	if not _validate_definition(metadata, city_definitions, roads, spawn_sets, player_count, map_world_size):
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
		var node_type: String = String(city_definition.get("node_type", CityStateRef.NODE_TYPE_NORMAL))
		var adjusted_stats: Dictionary = _apply_node_type_effects(city_definition, node_type)
		var neighbors: Array[int] = []
		for neighbor_id: int in adjacency.get(city_id, []):
			neighbors.append(neighbor_id)
		cities.append(
			CityStateRef.new(
				city_id,
				String(city_definition["name"]),
				_map_design_position_to_world(Vector2(city_definition["position"]), Vector2(metadata["design_canvas_size"]), map_world_size),
				int(spawn_owners.get(city_id, CityOwnerRef.NEUTRAL)),
				level,
				int(CityStateRef.LEVEL_CAPACITY[level]),
				int(adjusted_stats["initial_soldiers"]),
				neighbors,
				int(adjusted_stats["defense"]),
				float(adjusted_stats["production_rate"]),
				node_type
			)
		)
	return cities


## 返回上一次构建失败时记录的错误信息。
##
## 调用场景：主场景或测试在 loader 返回空数组后读取失败原因。
## 主要逻辑：暴露最近一次模板校验失败的中文消息，避免调用方只能看到空地图结果却不知道具体原因。
func get_last_error_message() -> String:
	return _last_error_message


## 返回上一次构建使用的地图 ID。
func get_current_map_id() -> String:
	return _current_map_id


## 校验预设地图模板是否满足第一阶段运行要求。
##
## 调用场景：构建运行时地图前。
## 主要逻辑：检查城市 ID、道路引用、出生配置覆盖、连通性，以及映射后的运行时坐标约束，尽早阻止非法模板进入主流程。
func _validate_definition(
	metadata: Dictionary,
	city_definitions: Array[Dictionary],
	roads: Array[Vector2i],
	spawn_sets: Dictionary,
	player_count: int,
	map_world_size: Vector2
) -> bool:
	var supported_counts: Array = metadata.get("supported_faction_counts", [])
	if not supported_counts.has(player_count):
		return _fail_validation("预设地图不支持 %d 方。" % player_count)
	if not spawn_sets.has(player_count):
		return _fail_validation("预设地图缺少 %d 方出生配置。" % player_count)

	var city_ids: Dictionary = {}
	for city_definition: Dictionary in city_definitions:
		var city_id: int = int(city_definition.get("id", -1))
		if city_id < 0 or city_ids.has(city_id):
			return _fail_validation("预设地图城市 ID 非法或重复：%d" % city_id)
		if not _is_valid_node_type(String(city_definition.get("node_type", CityStateRef.NODE_TYPE_NORMAL))):
			return _fail_validation("预设地图城市节点类型非法：%d" % city_id)
		city_ids[city_id] = true

	for road: Vector2i in roads:
		if not city_ids.has(road.x) or not city_ids.has(road.y):
			return _fail_validation("预设地图道路引用了不存在的城市：%s" % [road])
		if road.x == road.y:
			return _fail_validation("预设地图道路不能连接城市自身：%s" % [road])

	for faction_count_variant in spawn_sets.keys():
		var faction_count: int = int(faction_count_variant)
		var spawn_set: Dictionary = spawn_sets[faction_count]
		var used_ids: Dictionary = {}
		var player_city_id: int = int(spawn_set.get("player_city_id", -1))
		var ai_city_ids: Array = spawn_set.get("ai_city_ids", [])
		if not city_ids.has(player_city_id):
			return _fail_validation("预设地图玩家出生点不存在：%d" % player_city_id)
		if ai_city_ids.size() != faction_count - 1:
			return _fail_validation("预设地图 %d 方出生配置数量不正确。" % faction_count)
		used_ids[player_city_id] = true
		for ai_city_id_variant in ai_city_ids:
			var ai_city_id: int = int(ai_city_id_variant)
			if not city_ids.has(ai_city_id) or used_ids.has(ai_city_id):
				return _fail_validation("预设地图 AI 出生点非法或重复：%d" % ai_city_id)
			used_ids[ai_city_id] = true

	var adjacency: Dictionary = _build_adjacency(city_definitions, roads)
	if not _is_connected(city_definitions, adjacency):
		return _fail_validation("预设地图整体不连通。")
	return _validate_runtime_positions(city_definitions, metadata, map_world_size)


## 把设计画布坐标映射到当前运行时世界坐标。
##
## 调用场景：从模板数据生成运行时城市状态时。
## 主要逻辑：坐标支持两种模式——绝对坐标（>1）或百分比坐标（0-1）。
## 百分比坐标直接乘以世界尺寸，支持不同设备自适应。
func _map_design_position_to_world(design_position: Vector2, design_canvas_size: Vector2, map_world_size: Vector2) -> Vector2:
	# 如果坐标在 0-1 范围内，视为百分比，直接乘以世界尺寸
	if design_position.x <= 1.0 and design_position.y <= 1.0:
		return Vector2(
			design_position.x * map_world_size.x,
			design_position.y * map_world_size.y
		)
	# 否则视为绝对坐标，按设计画布比例映射
	if design_canvas_size.x <= 0.0 or design_canvas_size.y <= 0.0:
		return design_position
	return Vector2(
		design_position.x / design_canvas_size.x * map_world_size.x,
		design_position.y / design_canvas_size.y * map_world_size.y
	)


## 校验映射后的城市坐标是否仍满足运行时世界边界与最小间距要求。
##
## 调用场景：模板校验末尾，在真正生成城市状态前执行。
## 主要逻辑：先把 design canvas 坐标映射到当前世界尺寸，再检查是否越界，以及任意两城是否过近，
## 以减少标签重叠、点击冲突和拖拽视图中的异常重叠。
func _validate_runtime_positions(city_definitions: Array[Dictionary], metadata: Dictionary, map_world_size: Vector2) -> bool:
	var design_canvas_size: Vector2 = Vector2(metadata.get("design_canvas_size", Vector2.ZERO))
	var min_city_distance: float = _get_runtime_min_city_distance(design_canvas_size, map_world_size)
	var mapped_positions: Array[Vector2] = []
	for city_definition: Dictionary in city_definitions:
		var city_name: String = String(city_definition.get("name", ""))
		var mapped_position: Vector2 = _map_design_position_to_world(
			Vector2(city_definition["position"]),
			design_canvas_size,
			map_world_size
		)
		if mapped_position.x < 0.0 or mapped_position.y < 0.0:
			return _fail_validation("预设地图城市坐标越界：%s" % city_name)
		if mapped_position.x > map_world_size.x or mapped_position.y > map_world_size.y:
			return _fail_validation("预设地图城市坐标越界：%s" % city_name)
		for other_position: Vector2 in mapped_positions:
			if mapped_position.distance_to(other_position) < min_city_distance:
				return _fail_validation("预设地图城市重叠过近，低于最小间距 %.1f。" % min_city_distance)
		mapped_positions.append(mapped_position)
	return true


## 根据设计画布与当前运行时世界尺寸，换算实际使用的最小城市间距阈值。
##
## 调用场景：预设地图运行时坐标校验阶段。
## 主要逻辑：把 design canvas 上定义的安全距离按当前最小缩放比例映射到运行时世界，避免小地图尺寸下误把合法模板判成重叠。
func _get_runtime_min_city_distance(design_canvas_size: Vector2, map_world_size: Vector2) -> float:
	if design_canvas_size.x <= 0.0 or design_canvas_size.y <= 0.0:
		return DESIGN_CANVAS_MIN_CITY_DISTANCE
	var scale_x: float = map_world_size.x / design_canvas_size.x
	var scale_y: float = map_world_size.y / design_canvas_size.y
	return DESIGN_CANVAS_MIN_CITY_DISTANCE * min(scale_x, scale_y)


## 判断模板里的节点类型是否属于当前支持的静态战略节点集合。
##
## 调用场景：预设地图模板校验阶段。
## 主要逻辑：把未显式填写的类型按 normal 处理，其余值必须落在当前支持的四种节点类型中。
func _is_valid_node_type(node_type: String) -> bool:
	return node_type in [
		CityStateRef.NODE_TYPE_NORMAL,
		CityStateRef.NODE_TYPE_PASS,
		CityStateRef.NODE_TYPE_HUB,
		CityStateRef.NODE_TYPE_HEARTLAND
	]


## 按节点类型对模板基础数值应用第一版战略加成。
##
## 调用场景：运行时城市装配阶段，在真正创建城市状态前执行。
## 主要逻辑：读取模板基础防御、产能与初始兵力，按关口/枢纽/腹地的约定做轻量修正，并返回最终装配值。
func _apply_node_type_effects(city_definition: Dictionary, node_type: String) -> Dictionary:
	var adjusted_stats: Dictionary = {
		"defense": int(city_definition.get("defense", 10)),
		"production_rate": float(city_definition.get("production_rate", 10.0)),
		"initial_soldiers": int(city_definition.get("initial_soldiers", 0))
	}
	match node_type:
		CityStateRef.NODE_TYPE_PASS:
			adjusted_stats["defense"] = int(adjusted_stats["defense"]) + PASS_DEFENSE_BONUS
		CityStateRef.NODE_TYPE_HUB:
			adjusted_stats["production_rate"] = float(adjusted_stats["production_rate"]) + HUB_PRODUCTION_BONUS
		CityStateRef.NODE_TYPE_HEARTLAND:
			adjusted_stats["initial_soldiers"] = int(adjusted_stats["initial_soldiers"]) + HEARTLAND_SOLDIER_BONUS
	return adjusted_stats


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
		int(spawn_set["player_city_id"]): CityOwnerRef.PLAYER
	}
	var ai_city_ids: Array = spawn_set.get("ai_city_ids", [])
	for index: int in range(ai_city_ids.size()):
		owners[int(ai_city_ids[index])] = CityOwnerRef.AI_OWNER_START + index
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


## 统一记录并抛出模板校验失败信息。
##
## 调用场景：任何校验步骤发现非法数据时。
## 主要逻辑：把错误消息保存到 loader 内部状态，同时通过 `push_error` 输出到 Godot 错误通道，最后返回 `false` 供调用方短路退出。
func _fail_validation(message: String) -> bool:
	_last_error_message = message
	push_error(message)
	return false
