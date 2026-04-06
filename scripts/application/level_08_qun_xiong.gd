class_name Level08QunXiong
extends RefCounted

## 第8关：群雄并起
##
## 9座城市，极高难度。

const DESIGN_CANVAS_SIZE: Vector2 = Vector2(600.0, 900.0)


func get_metadata() -> Dictionary:
	return {
		"id": "level_08_qun_xiong",
		"name": "群雄并起",
		"design_canvas_size": DESIGN_CANVAS_SIZE,
		"supported_faction_counts": [3, 4, 5]
	}


func get_city_definitions() -> Array[Dictionary]:
	return [
		{"id": 0, "name": "北平", "position": Vector2(0.5, 0.08), "initial_soldiers": 100, "level": 2, "defense": 20, "production_rate": 10.0, "node_type": "heartland"},
		{"id": 1, "name": "辽东", "position": Vector2(0.2, 0.2), "initial_soldiers": 60, "level": 1, "defense": 20, "production_rate": 10.0, "node_type": "normal"},
		{"id": 2, "name": "渤海", "position": Vector2(0.5, 0.22), "initial_soldiers": 50, "level": 1, "defense": 10, "production_rate": 11.0, "node_type": "hub"},
		{"id": 3, "name": "山东", "position": Vector2(0.8, 0.2), "initial_soldiers": 60, "level": 1, "defense": 20, "production_rate": 10.0, "node_type": "normal"},
		{"id": 4, "name": "洛阳", "position": Vector2(0.5, 0.45), "initial_soldiers": 80, "level": 2, "defense": 20, "production_rate": 12.0, "node_type": "hub"},
		{"id": 5, "name": "南阳", "position": Vector2(0.3, 0.6), "initial_soldiers": 50, "level": 1, "defense": 10, "production_rate": 10.0, "node_type": "normal"},
		{"id": 6, "name": "襄阳", "position": Vector2(0.7, 0.6), "initial_soldiers": 50, "level": 1, "defense": 10, "production_rate": 10.0, "node_type": "normal"},
		{"id": 7, "name": "江陵", "position": Vector2(0.4, 0.8), "initial_soldiers": 80, "level": 2, "defense": 20, "production_rate": 11.0, "node_type": "normal"},
		{"id": 8, "name": "建业", "position": Vector2(0.6, 0.85), "initial_soldiers": 100, "level": 2, "defense": 20, "production_rate": 10.0, "node_type": "heartland"}
	]


func get_roads() -> Array[Vector2i]:
	return [
		Vector2i(0, 2),
		Vector2i(1, 2),
		Vector2i(2, 3),
		Vector2i(2, 4),
		Vector2i(4, 5),
		Vector2i(4, 6),
		Vector2i(5, 7),
		Vector2i(6, 7),
		Vector2i(5, 8),
		Vector2i(6, 8),
		Vector2i(7, 8)
	]


func get_spawn_sets_by_faction_count() -> Dictionary:
	return {
		3: {
			"player_city_id": 0,
			"ai_city_ids": [3, 8]
		},
		4: {
			"player_city_id": 0,
			"ai_city_ids": [3, 8, 1]
		},
		5: {
			"player_city_id": 0,
			"ai_city_ids": [3, 8, 1, 6]
		}
	}
