class_name Level09TianXia
extends RefCounted

## 第9关：天下大乱
##
## 10座城市，最高难度。

const DESIGN_CANVAS_SIZE: Vector2 = Vector2(600.0, 900.0)


func get_metadata() -> Dictionary:
	return {
		"id": "level_09_tian_xia",
		"name": "天下大乱",
		"design_canvas_size": DESIGN_CANVAS_SIZE,
		"supported_faction_counts": [4, 5]
	}


func get_city_definitions() -> Array[Dictionary]:
	return [
		{"id": 0, "name": "北疆", "position": Vector2(0.5, 0.06), "initial_soldiers": 100, "level": 2, "defense": 20, "production_rate": 10.0, "node_type": "heartland"},
		{"id": 1, "name": "辽东", "position": Vector2(0.15, 0.18), "initial_soldiers": 60, "level": 1, "defense": 20, "production_rate": 10.0, "node_type": "normal"},
		{"id": 2, "name": "幽州", "position": Vector2(0.4, 0.2), "initial_soldiers": 60, "level": 1, "defense": 20, "production_rate": 11.0, "node_type": "normal"},
		{"id": 3, "name": "山东", "position": Vector2(0.65, 0.2), "initial_soldiers": 60, "level": 1, "defense": 20, "production_rate": 11.0, "node_type": "normal"},
		{"id": 4, "name": "江东", "position": Vector2(0.85, 0.18), "initial_soldiers": 60, "level": 1, "defense": 20, "production_rate": 10.0, "node_type": "normal"},
		{"id": 5, "name": "洛阳", "position": Vector2(0.5, 0.42), "initial_soldiers": 100, "level": 2, "defense": 20, "production_rate": 13.0, "node_type": "hub"},
		{"id": 6, "name": "长安", "position": Vector2(0.25, 0.55), "initial_soldiers": 60, "level": 1, "defense": 20, "production_rate": 11.0, "node_type": "pass"},
		{"id": 7, "name": "开封", "position": Vector2(0.75, 0.55), "initial_soldiers": 60, "level": 1, "defense": 10, "production_rate": 11.0, "node_type": "normal"},
		{"id": 8, "name": "江陵", "position": Vector2(0.4, 0.75), "initial_soldiers": 80, "level": 2, "defense": 20, "production_rate": 11.0, "node_type": "normal"},
		{"id": 9, "name": "建业", "position": Vector2(0.6, 0.88), "initial_soldiers": 120, "level": 2, "defense": 20, "production_rate": 10.0, "node_type": "heartland"}
	]


func get_roads() -> Array[Vector2i]:
	return [
		Vector2i(0, 2),
		Vector2i(1, 2),
		Vector2i(2, 3),
		Vector2i(3, 4),
		Vector2i(2, 5),
		Vector2i(3, 5),
		Vector2i(5, 6),
		Vector2i(5, 7),
		Vector2i(6, 8),
		Vector2i(7, 8),
		Vector2i(6, 9),
		Vector2i(8, 9)
	]


func get_spawn_sets_by_faction_count() -> Dictionary:
	return {
		4: {
			"player_city_id": 5,
			"ai_city_ids": [1, 4, 9]
		},
		5: {
			"player_city_id": 5,
			"ai_city_ids": [1, 4, 9, 0]
		}
	}
