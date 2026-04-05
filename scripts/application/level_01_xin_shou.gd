class_name Level01XinShou
extends RefCounted

## 第1关：新手演练
##
## 最简单的地图，只有一个简单线性结构，适合新手熟悉游戏。

const DESIGN_CANVAS_SIZE: Vector2 = Vector2(600.0, 900.0)


func get_metadata() -> Dictionary:
	return {
		"id": "level_01_xin_shou",
		"name": "新手演练",
		"design_canvas_size": DESIGN_CANVAS_SIZE,
		"supported_faction_counts": [2]
	}


func get_city_definitions() -> Array[Dictionary]:
	return [
		{"id": 0, "name": "北城", "position": Vector2(0.5, 0.15), "initial_soldiers": 10, "level": 2, "defense": 2, "production_rate": 1.0, "node_type": "heartland"},
		{"id": 1, "name": "中继", "position": Vector2(0.5, 0.5), "initial_soldiers": 4, "level": 1, "defense": 1, "production_rate": 1.0, "node_type": "normal"},
		{"id": 2, "name": "南城", "position": Vector2(0.5, 0.85), "initial_soldiers": 10, "level": 2, "defense": 2, "production_rate": 1.0, "node_type": "heartland"}
	]


func get_roads() -> Array[Vector2i]:
	return [
		Vector2i(0, 1),
		Vector2i(1, 2)
	]


func get_spawn_sets_by_faction_count() -> Dictionary:
	return {
		2: {
			"player_city_id": 0,
			"ai_city_ids": [2]
		}
	}
