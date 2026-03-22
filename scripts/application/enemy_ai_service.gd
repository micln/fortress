class_name EnemyAiService
extends RefCounted

const CityOwnerRef = preload("res://scripts/domain/city_owner.gd")


## 选择敌军本轮的最佳进攻指令。
##
## 调用场景：敌方 AI 回合或定时决策。
## 主要逻辑：从所有敌军城市中筛选可行动城市，优先选择兵力最多的来源城市，
## 再在其相邻城市中挑选守军最少且不属于敌军的目标，以形成稳定且可解释的基础 AI。
func choose_attack(cities: Array) -> Dictionary:
	var best_source = null
	var best_target = null
	var best_score: float = -INF

	for source in cities:
		if source.owner != CityOwnerRef.ENEMY or source.soldiers <= 1:
			continue

		for target_id: int in source.neighbors:
			var target = cities[target_id]
			if target.owner == CityOwnerRef.ENEMY:
				continue

			var score: float = float(source.soldiers) - float(target.soldiers) * 1.2
			if target.owner == CityOwnerRef.PLAYER:
				score += 2.5
			if score > best_score:
				best_score = score
				best_source = source
				best_target = target

	if best_source == null or best_target == null:
		return {}

	return {
		"source_id": best_source.city_id,
		"target_id": best_target.city_id
	}
