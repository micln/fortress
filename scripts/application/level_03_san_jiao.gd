class_name Level03SanJiao
extends RefCounted

## 第3关：三角纷争
##
## 引入3方势力，简单三角形布局。

const DESIGN_CANVAS_SIZE: Vector2 = Vector2(600.0, 900.0)


func get_metadata() -> Dictionary:
	return {
		"id": "level_03_san_jiao",
		"name": "三角纷争",
		"design_canvas_size": DESIGN_CANVAS_SIZE,
		"supported_faction_counts": [3]
	}


func get_city_definitions() -> Array[Dictionary]:
	return [
		{"id": 0, "name": "北境", "position": Vector2(0.5, 0.15), "initial_soldiers": 10, "level": 2, "defense": 2, "production_rate": 1.0, "node_type": "heartland"},
		{"id": 1, "name": "东郡", "position": Vector2(0.17, 0.78), "initial_soldiers": 10, "level": 2, "defense": 2, "production_rate": 1.0, "node_type": "heartland"},
		{"id": 2, "name": "西郡", "position": Vector2(0.83, 0.78), "initial_soldiers": 10, "level": 2, "defense": 2, "production_rate": 1.0, "node_type": "heartland"},
		{"id": 3, "name": "中原", "position": Vector2(0.5, 0.56), "initial_soldiers": 5, "level": 1, "defense": 1, "production_rate": 1.1, "node_type": "hub"}
	]


func get_roads() -> Array[Vector2i]:
	return [
		Vector2i(0, 3),
		Vector2i(1, 3),
		Vector2i(2, 3)
	]


func get_spawn_sets_by_faction_count() -> Dictionary:
	return {
		3: {
			"player_city_id": 0,
			"ai_city_ids": [1, 2]
		}
	}
