class_name PrototypePresetMapDefinition
extends RefCounted

const DESIGN_CANVAS_SIZE: Vector2 = Vector2(1200.0, 2200.0)


## 返回第一张预设地图的基础元信息。
##
## 调用场景：预设地图 loader 构建运行时城市数组前读取静态配置。
## 主要逻辑：集中提供地图 ID、名称、设计画布尺寸和支持方数，避免 loader 写死这些元数据。
func get_metadata() -> Dictionary:
	return {
		"id": "china_central_plains_v1",
		"name": "中原风云",
		"design_canvas_size": DESIGN_CANVAS_SIZE,
		"supported_faction_counts": [2, 3, 4, 5]
	}


## 返回第一张预设地图的全部城市静态定义。
##
## 调用场景：预设地图 loader 在构建运行时城市状态前读取。
## 主要逻辑：为每座城市提供设计坐标、基础数值和展示名称；这些值以 design canvas 为坐标系，不直接依赖当前屏幕尺寸。
func get_city_definitions() -> Array[Dictionary]:
	return [
		{"id": 0, "name": "凉州", "position": Vector2(150.0, 250.0), "initial_soldiers": 12, "level": 2, "defense": 2, "production_rate": 1.0},
		{"id": 1, "name": "长安", "position": Vector2(330.0, 420.0), "initial_soldiers": 8, "level": 2, "defense": 2, "production_rate": 1.1},
		{"id": 2, "name": "洛阳", "position": Vector2(610.0, 560.0), "initial_soldiers": 7, "level": 2, "defense": 2, "production_rate": 1.2},
		{"id": 3, "name": "邺城", "position": Vector2(860.0, 470.0), "initial_soldiers": 6, "level": 2, "defense": 2, "production_rate": 1.1},
		{"id": 4, "name": "幽州", "position": Vector2(1020.0, 230.0), "initial_soldiers": 12, "level": 2, "defense": 2, "production_rate": 1.0},
		{"id": 5, "name": "汉中", "position": Vector2(300.0, 880.0), "initial_soldiers": 6, "level": 1, "defense": 2, "production_rate": 1.0},
		{"id": 6, "name": "宛城", "position": Vector2(540.0, 900.0), "initial_soldiers": 7, "level": 1, "defense": 1, "production_rate": 1.0},
		{"id": 7, "name": "许昌", "position": Vector2(720.0, 820.0), "initial_soldiers": 7, "level": 1, "defense": 1, "production_rate": 1.0},
		{"id": 8, "name": "汴州", "position": Vector2(900.0, 930.0), "initial_soldiers": 7, "level": 1, "defense": 1, "production_rate": 1.0},
		{"id": 9, "name": "成都", "position": Vector2(210.0, 1380.0), "initial_soldiers": 12, "level": 2, "defense": 2, "production_rate": 1.0},
		{"id": 10, "name": "江陵", "position": Vector2(460.0, 1310.0), "initial_soldiers": 7, "level": 1, "defense": 1, "production_rate": 1.1},
		{"id": 11, "name": "寿春", "position": Vector2(720.0, 1280.0), "initial_soldiers": 7, "level": 1, "defense": 1, "production_rate": 1.1},
		{"id": 12, "name": "建业", "position": Vector2(980.0, 1430.0), "initial_soldiers": 12, "level": 2, "defense": 2, "production_rate": 1.0},
		{"id": 13, "name": "交州", "position": Vector2(620.0, 1830.0), "initial_soldiers": 9, "level": 2, "defense": 2, "production_rate": 1.0}
	]


## 返回第一张预设地图的双向道路列表。
##
## 调用场景：预设地图 loader 在构建邻接关系时读取。
## 主要逻辑：每条边只定义一次，由 loader 负责展开为双向邻接；道路结构刻意包含中路、侧翼和瓶颈。
func get_roads() -> Array[Vector2i]:
	return [
		Vector2i(0, 1),
		Vector2i(1, 2),
		Vector2i(2, 3),
		Vector2i(3, 4),
		Vector2i(1, 5),
		Vector2i(5, 6),
		Vector2i(6, 2),
		Vector2i(6, 7),
		Vector2i(7, 2),
		Vector2i(7, 8),
		Vector2i(8, 3),
		Vector2i(5, 9),
		Vector2i(5, 10),
		Vector2i(6, 10),
		Vector2i(7, 11),
		Vector2i(8, 11),
		Vector2i(8, 12),
		Vector2i(9, 10),
		Vector2i(10, 11),
		Vector2i(11, 12),
		Vector2i(10, 13),
		Vector2i(11, 13)
	]


## 返回按总方数划分的出生配置。
##
## 调用场景：预设地图 loader 构建具体一局地图时按当前总方数选用。
## 主要逻辑：不同方数复用同一张战略图，但为每种总方数提供专门出生点，避免破坏当前开始面板的方数选择能力。
func get_spawn_sets_by_faction_count() -> Dictionary:
	return {
		2: {
			"player_city_id": 0,
			"ai_city_ids": [12]
		},
		3: {
			"player_city_id": 0,
			"ai_city_ids": [4, 13]
		},
		4: {
			"player_city_id": 0,
			"ai_city_ids": [4, 9, 12]
		},
		5: {
			"player_city_id": 0,
			"ai_city_ids": [4, 9, 12, 13]
		}
	}
