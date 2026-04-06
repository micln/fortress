class_name Level05CaoMang
extends RefCounted

## 第5关：草莽崛起
##
## 中等难度地图，2-4势力可玩，9座城市。

const DESIGN_CANVAS_SIZE: Vector2 = Vector2(600.0, 900.0)


func get_metadata() -> Dictionary:
	return {
		"id": "level_05_cao_mang",
		"name": "草莽崛起",
		"design_canvas_size": DESIGN_CANVAS_SIZE,
		"supported_faction_counts": [2, 3, 4]
	}


func get_city_definitions() -> Array[Dictionary]:
	return [
		{"id": 0, "name": "建业", "position": Vector2(0.5, 0.15), "initial_soldiers": 100, "level": 2, "defense": 20, "production_rate": 10.0, "node_type": "heartland"},
		{"id": 1, "name": "吴郡", "position": Vector2(0.25, 0.32), "initial_soldiers": 60, "level": 1, "defense": 10, "production_rate": 10.0, "node_type": "normal"},
		{"id": 2, "name": "会稽", "position": Vector2(0.75, 0.32), "initial_soldiers": 60, "level": 1, "defense": 10, "production_rate": 10.0, "node_type": "normal"},
		{"id": 3, "name": "丹阳", "position": Vector2(0.5, 0.43), "initial_soldiers": 50, "level": 1, "defense": 10, "production_rate": 10.0, "node_type": "hub"},
		{"id": 4, "name": "庐江", "position": Vector2(0.3, 0.6), "initial_soldiers": 50, "level": 1, "defense": 10, "production_rate": 10.0, "node_type": "normal"},
		{"id": 5, "name": "皖县", "position": Vector2(0.7, 0.6), "initial_soldiers": 50, "level": 1, "defense": 10, "production_rate": 10.0, "node_type": "normal"},
		{"id": 6, "name": "寿春", "position": Vector2(0.5, 0.78), "initial_soldiers": 100, "level": 2, "defense": 20, "production_rate": 10.0, "node_type": "heartland"},
		{"id": 7, "name": "彭城", "position": Vector2(0.25, 0.92), "initial_soldiers": 50, "level": 1, "defense": 10, "production_rate": 11.0, "node_type": "pass"},
		{"id": 8, "name": "下邳", "position": Vector2(0.75, 0.92), "initial_soldiers": 50, "level": 1, "defense": 10, "production_rate": 11.0, "node_type": "pass"}
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
		Vector2i(5, 6),
		Vector2i(4, 7),
		Vector2i(6, 7),
		Vector2i(5, 8),
		Vector2i(6, 8)
	]


func get_spawn_sets_by_faction_count() -> Dictionary:
	return {
		2: {
			"player_city_id": 0,
			"ai_city_ids": [6]
		},
		3: {
			"player_city_id": 0,
			"ai_city_ids": [6, 2]
		},
		4: {
			"player_city_id": 0,
			"ai_city_ids": [6, 2, 8]
		}
	}
