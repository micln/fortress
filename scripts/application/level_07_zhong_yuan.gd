class_name Level07ZhongYuan
extends RefCounted

## 第7关：逐鹿中原
##
## 8座城市，高难度。

const DESIGN_CANVAS_SIZE: Vector2 = Vector2(600.0, 900.0)


func get_metadata() -> Dictionary:
	return {
		"id": "level_07_zhong_yuan",
		"name": "逐鹿中原",
		"design_canvas_size": DESIGN_CANVAS_SIZE,
		"supported_faction_counts": [2, 3, 4, 5]
	}


func get_city_definitions() -> Array[Dictionary]:
	return [
		{"id": 0, "name": "凉州", "position": Vector2(0.15, 0.15), "initial_soldiers": 8, "level": 2, "defense": 2, "production_rate": 1.0, "node_type": "normal"},
		{"id": 1, "name": "长安", "position": Vector2(0.35, 0.25), "initial_soldiers": 6, "level": 1, "defense": 2, "production_rate": 1.1, "node_type": "pass"},
		{"id": 2, "name": "洛阳", "position": Vector2(0.55, 0.35), "initial_soldiers": 8, "level": 2, "defense": 2, "production_rate": 1.2, "node_type": "hub"},
		{"id": 3, "name": "邺城", "position": Vector2(0.8, 0.25), "initial_soldiers": 6, "level": 1, "defense": 2, "production_rate": 1.1, "node_type": "normal"},
		{"id": 4, "name": "幽州", "position": Vector2(0.9, 0.1), "initial_soldiers": 8, "level": 2, "defense": 2, "production_rate": 1.0, "node_type": "normal"},
		{"id": 5, "name": "宛城", "position": Vector2(0.45, 0.55), "initial_soldiers": 5, "level": 1, "defense": 1, "production_rate": 1.0, "node_type": "normal"},
		{"id": 6, "name": "寿春", "position": Vector2(0.7, 0.65), "initial_soldiers": 6, "level": 1, "defense": 1, "production_rate": 1.1, "node_type": "normal"},
		{"id": 7, "name": "建业", "position": Vector2(0.85, 0.85), "initial_soldiers": 10, "level": 2, "defense": 2, "production_rate": 1.0, "node_type": "heartland"}
	]


func get_roads() -> Array[Vector2i]:
	return [
		Vector2i(0, 1),
		Vector2i(1, 2),
		Vector2i(2, 3),
		Vector2i(3, 4),
		Vector2i(1, 5),
		Vector2i(2, 5),
		Vector2i(2, 6),
		Vector2i(3, 6),
		Vector2i(5, 6),
		Vector2i(6, 7)
	]


func get_spawn_sets_by_faction_count() -> Dictionary:
	return {
		2: {
			"player_city_id": 0,
			"ai_city_ids": [7]
		},
		3: {
			"player_city_id": 0,
			"ai_city_ids": [4, 7]
		},
		4: {
			"player_city_id": 0,
			"ai_city_ids": [4, 7, 3]
		},
		5: {
			"player_city_id": 0,
			"ai_city_ids": [4, 7, 3, 6]
		}
	}
