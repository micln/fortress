class_name MapJingxiang
extends RefCounted

## 荆襄要地地图
##
## 中等大小地图，聚焦于荆州和襄阳之间的争夺。

const DESIGN_CANVAS_SIZE: Vector2 = Vector2(1200.0, 2200.0)


func get_metadata() -> Dictionary:
	return {
		"id": "jingxiang_v1",
		"name": "荆襄风云",
		"design_canvas_size": DESIGN_CANVAS_SIZE,
		"supported_faction_counts": [2, 3, 4, 5]
	}


func get_city_definitions() -> Array[Dictionary]:
	return [
		{"id": 0, "name": "襄阳", "position": Vector2(550.0, 200.0), "initial_soldiers": 120, "level": 2, "defense": 20, "production_rate": 10.0, "node_type": "heartland"},
		{"id": 1, "name": "南阳", "position": Vector2(280.0, 380.0), "initial_soldiers": 60, "level": 1, "defense": 10, "production_rate": 10.0, "node_type": "normal"},
		{"id": 2, "name": "新野", "position": Vector2(820.0, 380.0), "initial_soldiers": 60, "level": 1, "defense": 10, "production_rate": 10.0, "node_type": "normal"},
		{"id": 3, "name": "荆州", "position": Vector2(550.0, 700.0), "initial_soldiers": 80, "level": 2, "defense": 20, "production_rate": 11.0, "node_type": "hub"},
		{"id": 4, "name": "江陵", "position": Vector2(280.0, 950.0), "initial_soldiers": 60, "level": 1, "defense": 10, "production_rate": 10.0, "node_type": "normal"},
		{"id": 5, "name": "江夏", "position": Vector2(820.0, 950.0), "initial_soldiers": 60, "level": 1, "defense": 10, "production_rate": 10.0, "node_type": "normal"},
		{"id": 6, "name": "长沙", "position": Vector2(280.0, 1250.0), "initial_soldiers": 60, "level": 1, "defense": 10, "production_rate": 11.0, "node_type": "normal"},
		{"id": 7, "name": "桂阳", "position": Vector2(550.0, 1400.0), "initial_soldiers": 50, "level": 1, "defense": 10, "production_rate": 10.0, "node_type": "pass"},
		{"id": 8, "name": "江州", "position": Vector2(820.0, 1250.0), "initial_soldiers": 60, "level": 1, "defense": 10, "production_rate": 11.0, "node_type": "normal"}
	]


func get_roads() -> Array[Vector2i]:
	return [
		Vector2i(0, 1),
		Vector2i(0, 2),
		Vector2i(1, 3),
		Vector2i(2, 3),
		Vector2i(1, 4),
		Vector2i(3, 4),
		Vector2i(3, 5),
		Vector2i(2, 5),
		Vector2i(4, 6),
		Vector2i(4, 7),
		Vector2i(5, 7),
		Vector2i(5, 8),
		Vector2i(6, 7),
		Vector2i(7, 8)
	]


func get_spawn_sets_by_faction_count() -> Dictionary:
	return {
		2: {
			"player_city_id": 0,
			"ai_city_ids": [6]
		},
		3: {
			"player_city_id": 0,
			"ai_city_ids": [6, 8]
		},
		4: {
			"player_city_id": 0,
			"ai_city_ids": [4, 6, 8]
		},
		5: {
			"player_city_id": 0,
			"ai_city_ids": [4, 6, 8, 2]
		}
	}
