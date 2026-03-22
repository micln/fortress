class_name PrototypeBattleService
extends RefCounted

const PrototypeCityOwnerRef = preload("res://scripts/domain/prototype_city_owner.gd")


## 执行一次同阵营城市之间的运兵，并返回结果描述。
##
## 调用场景：玩家点击己方城市后，再点击任意己方城市时。
## 主要逻辑：仅扣除本次选择的出兵人数，不改变双方归属；若源城市没有兵，则返回失败提示。
func prepare_transfer(source, target, moving_soldiers: int) -> Dictionary:
	moving_soldiers = clamp(moving_soldiers, 0, source.soldiers)
	if moving_soldiers <= 0:
		return {
			"success": false,
			"message": "%s 没有士兵可以运往 %s。" % [source.name, target.name]
		}

	source.remove_soldiers(moving_soldiers)
	return {
		"success": true,
		"count": moving_soldiers,
		"owner": source.owner,
		"message": "%s 向 %s 运输了 %d 名士兵。" % [source.name, target.name, moving_soldiers]
	}


## 在运兵单位抵达后，把兵力实际并入目标城市。
##
## 调用场景：运兵行军单位到达终点时。
## 主要逻辑：如果目标城仍是原阵营，则视为正常增援；
## 如果目标城在途中已经失守，则这批迟到援军会立刻与当前守军交战，按正常攻城规则重新结算归属。
func resolve_transfer_arrival(target, transfer_owner: int, moving_soldiers: int) -> Dictionary:
	if target.owner != transfer_owner:
		var battle_result: Dictionary = resolve_attack_arrival(target, transfer_owner, moving_soldiers)
		battle_result["captured_by_enemy"] = false
		battle_result["retook_after_loss"] = true
		return battle_result

	target.add_soldiers(moving_soldiers)
	return {
		"success": true,
		"captured_by_enemy": false,
		"retook_after_loss": false,
		"message": "%s 接收了 %d 名援军。" % [target.name, moving_soldiers]
	}


## 执行一次从源城市到目标城市的进攻，并返回结果描述。
##
## 调用场景：玩家点击进攻、敌方 AI 发起进攻。
## 主要逻辑：按照“双方士兵数相减”的规则进行结算。
## 如果进攻方人数更多，则会把目标城在行军途中可能新增的守军也一并算入，
## 只派出“预测守军数量 + 1”的最低必要兵力占城，让源城市保留剩余守军；
## 如果进攻方人数不足或相等，则仍按原规则消耗对应兵力。
func prepare_attack(source, target, _travel_duration: float, attackers: int) -> Dictionary:
	attackers = clamp(attackers, 0, source.soldiers)

	if attackers <= 0:
		return {
			"success": false,
			"message": "%s 没有可出征的士兵。" % source.name
		}

	source.remove_soldiers(attackers)
	return {
		"success": true,
		"count": attackers,
		"owner": source.owner,
		"message": "%s 派出 %d 人前往 %s。" % [source.name, attackers, target.name]
	}


## 预测目标城市在行军持续时间内会新增的守军数量。
##
## 调用场景：出兵准备阶段决定最少派兵人数时。
## 主要逻辑：只有已占领城市才会产兵；按行军时长向下取整估算路上会完整触发多少次整秒产兵。
func _predict_target_growth(target, travel_duration: float) -> int:
	if not target.is_occupied():
		return 0
	return int(floor(travel_duration + 0.001))


## 计算一次进攻在当前行军时长下的推荐最少出兵人数。
##
## 调用场景：玩家打开出兵数量对话框、敌方 AI 自动下单时。
## 主要逻辑：把目标当前守军和路上预计新增守军相加，再加 1 作为推荐值；
## 若推荐人数超过出发城市现有兵力，则回退为全军出动。
func get_recommended_attack_count(source, target, travel_duration: float) -> int:
	var predicted_defenders: int = target.soldiers + _predict_target_growth(target, travel_duration)
	return min(source.soldiers, predicted_defenders + 1)


## 预测某次进攻在到达时的大致结果，供出兵弹窗实时展示。
##
## 调用场景：玩家调整出兵数量时。
## 主要逻辑：基于当前守军、预计路上产兵和玩家选择的出兵数，给出“能否占领”和大致剩余兵力。
func preview_attack_outcome(source, target, travel_duration: float, attackers: int) -> Dictionary:
	var predicted_growth: int = _predict_target_growth(target, travel_duration)
	var predicted_defenders: int = target.soldiers + predicted_growth
	var predicted_capture: bool = attackers >= predicted_defenders
	var predicted_remaining: int = max(1, attackers - predicted_defenders) if predicted_capture else predicted_defenders - attackers
	return {
		"predicted_growth": predicted_growth,
		"predicted_defenders": predicted_defenders,
		"predicted_capture": predicted_capture,
		"predicted_remaining": predicted_remaining,
		"travel_duration": travel_duration,
		"source_soldiers_after_departure": source.soldiers - attackers
	}


## 在进攻单位抵达后，对目标城市执行实际战斗结算。
##
## 调用场景：进攻行军单位到达终点时。
## 主要逻辑：若目标城此时已变为同阵营，则直接并入驻军；否则按到达时的双方兵力做结算。
func resolve_attack_arrival(target, attacker_owner: int, attackers: int) -> Dictionary:
	if target.owner == attacker_owner:
		target.add_soldiers(attackers)
		return {
			"success": true,
			"captured": false,
			"reinforced": true,
			"message": "%s 接收了 %d 名友军增援。" % [target.name, attackers]
		}

	if attackers >= target.soldiers:
		var remaining_soldiers: int = max(1, attackers - target.soldiers)
		target.owner = attacker_owner
		target.soldiers = min(target.max_soldiers, remaining_soldiers)
		return {
			"success": true,
			"captured": true,
			"reinforced": false,
			"message": "%s 被攻下，城内留下 %d 人驻守。" % [target.name, remaining_soldiers]
		}

	target.remove_soldiers(attackers)
	return {
		"success": true,
		"captured": false,
		"reinforced": false,
		"message": "%s 顶住了进攻，城内还剩 %d 士兵。" % [target.name, target.soldiers]
	}


## 结算两支不同势力行军部队在道路上的遭遇战。
##
## 调用场景：主场景检测到两支行军单位在道路上相遇时。
## 主要逻辑：双方人数直接相减；较大兵团会吞掉较小兵团并保留差值继续前进，
## 若双方人数相同则同归于尽。
func resolve_marching_encounter(left_owner: int, left_count: int, right_owner: int, right_count: int) -> Dictionary:
	if left_owner == right_owner:
		return {
			"same_owner": true,
			"both_destroyed": false,
			"winner_owner": left_owner,
			"remaining_count": left_count + right_count
		}

	if left_count == right_count:
		return {
			"same_owner": false,
			"both_destroyed": true,
			"winner_owner": PrototypeCityOwnerRef.NEUTRAL,
			"remaining_count": 0
		}

	var winner_owner: int = left_owner
	var remaining_count: int = left_count - right_count
	if right_count > left_count:
		winner_owner = right_owner
		remaining_count = right_count - left_count

	return {
		"same_owner": false,
		"both_destroyed": false,
		"winner_owner": winner_owner,
		"remaining_count": remaining_count
	}


## 为所有已占领城市执行一次产兵。
##
## 调用场景：每秒一次的战局 Tick。
## 主要逻辑：遍历城市列表，仅对非中立城市增加 1 名士兵。
func produce_soldiers(cities: Array) -> void:
	for city in cities:
		if city.can_produce():
			city.add_soldiers(1)


## 检查是否已经产生单方完全占领的胜负结果。
##
## 调用场景：每次进攻后、每轮 AI 行动后。
## 主要逻辑：统计当前仍持有城市的全部非中立阵营；若只剩一个阵营，则该阵营直接获胜。
func get_winner(cities: Array) -> int:
	var remaining_owners: Dictionary = {}

	for city in cities:
		if PrototypeCityOwnerRef.is_neutral(city.owner):
			continue
		remaining_owners[city.owner] = true

	if remaining_owners.size() == 1:
		return int(remaining_owners.keys()[0])
	return PrototypeCityOwnerRef.NEUTRAL
