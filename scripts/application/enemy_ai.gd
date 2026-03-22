class_name EnemyAI
extends RefCounted

const FactionRef = preload("res://scripts/domain/faction.gd")


## 为敌方挑选一条当前最合适的攻击指令。
## 调用场景：`MainGame` 的敌方行动周期触发时调用。
## 主要逻辑：遍历所有敌方城市及其相邻目标，优先选择“可直接占领且收益最大”的攻击，
## 若没有必胜攻击，则退化为兵力差最优的消耗战方案；兵力不足 2 时不出击。
func choose_attack(game_state) -> Dictionary:
	var best_command: Dictionary = {}
	var best_score: float = -INF

	for city in game_state.get_cities_owned_by(FactionRef.Type.ENEMY):
		if city.soldiers < 2:
			continue
		for neighbor_id: int in game_state.get_neighbor_ids(city.id):
			var target = game_state.get_city(neighbor_id)
			if target.owner == FactionRef.Type.ENEMY:
				continue

			var can_capture: bool = city.soldiers > target.soldiers
			var score: float = float(city.soldiers - target.soldiers)
			if can_capture:
				score += 1000.0
			if target.owner == FactionRef.Type.PLAYER:
				score += 25.0

			if score > best_score:
				best_score = score
				best_command = {
					"from_city_id": city.id,
					"to_city_id": neighbor_id,
				}

	return best_command
