class_name Level06JingXiang
extends RefCounted

## 第6关：荆襄风云
##
## 6座城市，中等难度。

const DESIGN_CANVAS_SIZE: Vector2 = Vector2(600.0, 900.0)


func get_metadata() -> Dictionary:
	return {
		"id": "level_06_jing_xiang",
		"name": "荆襄风云",
		"design_canvas_size": DESIGN_CANVAS_SIZE,
		"supported_faction_counts": [2, 3, 4]
	}


func get_city_definitions() -> Array[Dictionary]:
	return [
		{"id": 0, "name": "襄阳", "position": Vector2(0.5, 0.15), "initial_soldiers": 10, "level": 2, "defense": 2, "production_rate": 1.0, "node_type": "heartland"},
		{"id": 1, "name": "南阳", "position": Vector2(0.25, 0.35), "initial_soldiers": 5, "level": 1, "defense": 1, "production_rate": 1.0, "node_type": "normal"},
		{"id": 2, "name": "新野", "position": Vector2(0.75, 0.35), "initial_soldiers": 5, "level": 1, "defense": 1, "production_rate": 1.0, "node_type": "normal"},
		{"id": 3, "name": "荆州", "position": Vector2(0.5, 0.55), "initial_soldiers": 6, "level": 1, "defense": 2, "production_rate": 1.1, "node_type": "hub"},
		{"id": 4, "name": "江陵", "position": Vector2(0.25, 0.8), "initial_soldiers": 10, "level": 2, "defense": 2, "production_rate": 1.0, "node_type": "heartland"},
		{"id": 5, "name": "江夏", "position": Vector2(0.75, 0.8), "initial_soldiers": 10, "level": 2, "defense": 2, "production_rate": 1.0, "node_type": "heartland"}
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
		Vector2i(4, 5)
	]


func get_spawn_sets_by_faction_count() -> Dictionary:
	return {
		2: {
			"player_city_id": 0,
			"ai_city_ids": [4]
		},
		3: {
			"player_city_id": 0,
			"ai_city_ids": [4, 2]
		},
		4: {
			"player_city_id": 0,
			"ai_city_ids": [4, 2, 5]
		}
	}
