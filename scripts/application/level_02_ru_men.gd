class_name Level02RuMen
extends RefCounted

## 第2关：入门之战
##
## 简单的T字形地图，引入分支选择。

const DESIGN_CANVAS_SIZE: Vector2 = Vector2(600.0, 900.0)


func get_metadata() -> Dictionary:
	return {
		"id": "level_02_ru_men",
		"name": "入门之战",
		"design_canvas_size": DESIGN_CANVAS_SIZE,
		"supported_faction_counts": [2]
	}


func get_city_definitions() -> Array[Dictionary]:
	return [
		{"id": 0, "name": "西京", "position": Vector2(0.5, 0.15), "initial_soldiers": 100, "level": 2, "defense": 20, "production_rate": 10.0, "node_type": "heartland"},
		{"id": 1, "name": "左路", "position": Vector2(0.25, 0.5), "initial_soldiers": 50, "level": 1, "defense": 10, "production_rate": 10.0, "node_type": "normal"},
		{"id": 2, "name": "中路", "position": Vector2(0.5, 0.5), "initial_soldiers": 50, "level": 1, "defense": 10, "production_rate": 10.0, "node_type": "normal"},
		{"id": 3, "name": "右路", "position": Vector2(0.75, 0.5), "initial_soldiers": 50, "level": 1, "defense": 10, "production_rate": 10.0, "node_type": "normal"},
		{"id": 4, "name": "东京", "position": Vector2(0.5, 0.85), "initial_soldiers": 100, "level": 2, "defense": 20, "production_rate": 10.0, "node_type": "heartland"}
	]


func get_roads() -> Array[Vector2i]:
	return [
		Vector2i(0, 1),
		Vector2i(0, 2),
		Vector2i(0, 3),
		Vector2i(1, 4),
		Vector2i(2, 4),
		Vector2i(3, 4)
	]


func get_spawn_sets_by_faction_count() -> Dictionary:
	return {
		2: {
			"player_city_id": 0,
			"ai_city_ids": [4]
		}
	}
