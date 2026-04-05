class_name Level04SiFang
extends RefCounted

## 第4关：四方争雄
##
## 4方势力对抗，经典四边形布局。

const DESIGN_CANVAS_SIZE: Vector2 = Vector2(600.0, 900.0)


func get_metadata() -> Dictionary:
	return {
		"id": "level_04_si_fang",
		"name": "四方争雄",
		"design_canvas_size": DESIGN_CANVAS_SIZE,
		"supported_faction_counts": [4]
	}


func get_city_definitions() -> Array[Dictionary]:
	return [
		{"id": 0, "name": "北都", "position": Vector2(0.5, 0.15), "initial_soldiers": 10, "level": 2, "defense": 2, "production_rate": 1.0, "node_type": "heartland"},
		{"id": 1, "name": "东都", "position": Vector2(0.17, 0.56), "initial_soldiers": 10, "level": 2, "defense": 2, "production_rate": 1.0, "node_type": "heartland"},
		{"id": 2, "name": "南都", "position": Vector2(0.5, 0.85), "initial_soldiers": 10, "level": 2, "defense": 2, "production_rate": 1.0, "node_type": "heartland"},
		{"id": 3, "name": "西都", "position": Vector2(0.83, 0.56), "initial_soldiers": 10, "level": 2, "defense": 2, "production_rate": 1.0, "node_type": "heartland"},
		{"id": 4, "name": "中枢", "position": Vector2(0.5, 0.5), "initial_soldiers": 6, "level": 1, "defense": 1, "production_rate": 1.2, "node_type": "hub"},
		{"id": 5, "name": "北关", "position": Vector2(0.5, 0.3), "initial_soldiers": 4, "level": 1, "defense": 2, "production_rate": 1.0, "node_type": "pass"},
		{"id": 6, "name": "南关", "position": Vector2(0.5, 0.7), "initial_soldiers": 4, "level": 1, "defense": 2, "production_rate": 1.0, "node_type": "pass"}
	]


func get_roads() -> Array[Vector2i]:
	return [
		Vector2i(0, 5),
		Vector2i(5, 4),
		Vector2i(4, 6),
		Vector2i(6, 2),
		Vector2i(1, 4),
		Vector2i(3, 4)
	]


func get_spawn_sets_by_faction_count() -> Dictionary:
	return {
		4: {
			"player_city_id": 0,
			"ai_city_ids": [1, 2, 3]
		}
	}
