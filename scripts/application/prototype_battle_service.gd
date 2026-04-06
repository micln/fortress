class_name PrototypeBattleService
extends RefCounted

const PrototypeCityOwnerRef = preload("res://scripts/domain/prototype_city_owner.gd")
const UPGRADE_LEVEL: String = "level"
const UPGRADE_DEFENSE: String = "defense"
const UPGRADE_PRODUCTION: String = "production"


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
		battle_result["received_count"] = 0
		battle_result["overflow_count"] = 0
		return battle_result

	var soldiers_before: int = target.soldiers
	target.add_soldiers(moving_soldiers)
	var received_count: int = max(0, target.soldiers - soldiers_before)
	var overflow_count: int = max(0, moving_soldiers - received_count)
	var message: String = "%s 接收了 %d 名援军。" % [target.name, received_count]
	if overflow_count > 0:
		message = "%s 接收了 %d 名援军，%d 名因满员溢出。" % [target.name, received_count, overflow_count]
	return {
		"success": true,
		"captured_by_enemy": false,
		"retook_after_loss": false,
		"received_count": received_count,
		"overflow_count": overflow_count,
		"message": message
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
## 主要逻辑：只有已占领城市才会产兵；按行军时长和目标城产能估算路上会累计产出多少整兵，
## 以便推荐出兵数和到达预估都能反映城市产能差异。
func _predict_target_growth(target, travel_duration: float) -> int:
	if not target.is_occupied():
		return 0
	return int(floor(target.production_rate * travel_duration + 0.001))


## 计算一次进攻在当前行军时长下的推荐最少出兵人数。
##
## 调用场景：玩家打开出兵数量对话框、敌方 AI 自动下单时。
## 主要逻辑：把目标当前守军、固定防御值和路上预计新增守军相加，再加 1 作为推荐值；
## 若推荐人数超过出发城市现有兵力，则回退为全军出动。
func get_recommended_attack_count(source, target, travel_duration: float) -> int:
	var predicted_growth: int = _predict_target_growth(target, travel_duration)
	var effective_defenders: int = target.get_effective_defense(predicted_growth)
	return min(source.soldiers, effective_defenders + 1)


## 预测某次进攻在到达时的大致结果，供出兵弹窗实时展示。
##
## 调用场景：玩家调整出兵数量时。
## 主要逻辑：基于当前守军、防御值、预计路上产兵和玩家选择的出兵数，
## 给出“能否占领”和大致剩余兵力。
func preview_attack_outcome(source, target, travel_duration: float, attackers: int) -> Dictionary:
	var predicted_growth: int = _predict_target_growth(target, travel_duration)
	var predicted_defenders: int = target.soldiers + predicted_growth
	var effective_defenders: int = target.get_effective_defense(predicted_growth)
	var predicted_capture: bool = attackers >= effective_defenders
	var predicted_remaining: int = max(1, attackers - effective_defenders) if predicted_capture else effective_defenders - attackers
	return {
		"predicted_growth": predicted_growth,
		"predicted_defenders": predicted_defenders,
		"predicted_effective_defenders": effective_defenders,
		"predicted_defense_bonus": target.defense,
		"predicted_capture": predicted_capture,
		"predicted_remaining": predicted_remaining,
		"travel_duration": travel_duration,
		"source_soldiers_after_departure": source.soldiers - attackers
	}


## 在进攻单位抵达后，对目标城市执行实际战斗结算。
##
## 调用场景：进攻行军单位到达终点时。
## 主要逻辑：若目标城此时已变为同阵营，则直接并入驻军；否则按到达时的守军与固定防御值做结算，
## 使高防御城市需要额外兵力才能被真正攻下。
func resolve_attack_arrival(target, attacker_owner: int, attackers: int) -> Dictionary:
	if target.owner == attacker_owner:
		target.add_soldiers(attackers)
		return {
			"success": true,
			"captured": false,
			"reinforced": true,
			"message": "%s 接收了 %d 名友军增援。" % [target.name, attackers]
		}

	var effective_defenders: int = target.get_effective_defense()
	if attackers >= effective_defenders:
		var remaining_soldiers: int = max(1, attackers - effective_defenders)
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


## 结算同一帧内多支进攻部队同时到达同一座城市的战斗结果。
##
## 调用场景：表现层在一帧内收集到同目标城市的多支 `attack` 行军后。
## 主要逻辑：先把守方同阵营到达部队并入守军，再把其余攻方按阵营聚合成“同帧攻城总兵力”；
## 若多个攻方同时到达，则先进行同帧互耗（最大兵团减去其余总兵力，无法压制则同归于尽），
## 最后只让幸存攻方与守城方进行一次攻城结算，避免“先到先得”造成的顺序偏差。
func resolve_simultaneous_attack_arrivals(target, arrivals_by_owner: Dictionary) -> Dictionary:
	var defender_owner: int = target.owner
	var defender_soldiers_before: int = target.soldiers
	var defender_reinforcement: int = max(0, int(arrivals_by_owner.get(defender_owner, 0)))
	var defender_soldiers_after_reinforcement: int = min(target.max_soldiers, defender_soldiers_before + defender_reinforcement)
	target.soldiers = defender_soldiers_after_reinforcement

	var attacking_totals: Dictionary = {}
	for key in arrivals_by_owner.keys():
		var owner: int = int(key)
		if owner == defender_owner:
			continue
		var count: int = max(0, int(arrivals_by_owner[key]))
		if count <= 0:
			continue
		attacking_totals[owner] = count

	if attacking_totals.is_empty():
		return {
			"success": true,
			"captured": false,
			"reinforced": defender_reinforcement > 0,
			"contested": false,
			"winner_owner": defender_owner,
			"winner_count": 0,
			"defender_reinforcement": defender_reinforcement,
			"message": "%s 接收了 %d 名友军增援。" % [target.name, defender_reinforcement]
		}

	var winner_owner: int = PrototypeCityOwnerRef.NEUTRAL
	var winner_count: int = 0
	var total_attackers: int = 0
	for owner in attacking_totals.keys():
		var count: int = int(attacking_totals[owner])
		total_attackers += count
		if count > winner_count:
			winner_count = count
			winner_owner = int(owner)

	var attackers_cancelled: bool = false
	if attacking_totals.size() > 1:
		var others_total: int = total_attackers - winner_count
		if winner_count <= others_total:
			attackers_cancelled = true
			winner_owner = PrototypeCityOwnerRef.NEUTRAL
			winner_count = 0
		else:
			winner_count -= others_total

	if winner_count <= 0:
		return {
			"success": true,
			"captured": false,
			"reinforced": defender_reinforcement > 0,
			"contested": true,
			"attackers_cancelled": true,
			"winner_owner": PrototypeCityOwnerRef.NEUTRAL,
			"winner_count": 0,
			"defender_reinforcement": defender_reinforcement,
			"message": "%s 附近多方部队同帧混战后同归于尽，守军稳住了城池。" % target.name
		}

	var arrival_result: Dictionary = resolve_attack_arrival(target, winner_owner, winner_count)
	arrival_result["contested"] = attacking_totals.size() > 1
	arrival_result["attackers_cancelled"] = attackers_cancelled
	arrival_result["winner_owner"] = winner_owner
	arrival_result["winner_count"] = winner_count
	arrival_result["defender_reinforcement"] = defender_reinforcement
	return arrival_result


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
## 主要逻辑：遍历城市列表，根据每座城市自己的产能累计产兵；
## 产能支持小数进度累计，且始终受城市容量上限约束。
func produce_soldiers(cities: Array) -> void:
	for city in cities:
		city.advance_production(1.0)


## 返回指定城市当前三种升级选项的成本、上限与可用性。
##
## 调用场景：底部升级按钮文案刷新、AI 升级决策。
## 主要逻辑：统一汇总等级、防御、产能三类升级的当前成本和可行性，避免表现层重复写判断。
func get_city_upgrade_options(city) -> Dictionary:
	return {
		UPGRADE_LEVEL: {
			"available": city.can_upgrade_level(),
			"cost": city.get_level_upgrade_cost(),
			"label": "升级"
		},
		UPGRADE_DEFENSE: {
			"available": city.can_upgrade_defense(),
			"cost": city.get_defense_upgrade_cost(),
			"label": "升防"
		},
		UPGRADE_PRODUCTION: {
			"available": city.can_upgrade_production(),
			"cost": city.get_production_upgrade_cost(),
			"label": "升产"
		}
	}


## 对指定城市执行一次属性升级。
##
## 调用场景：玩家点击升级按钮、AI 决定优先养城时。
## 主要逻辑：先校验城市归属、升级类型、是否到达上限和士兵是否足够，再调用领域对象真正应用升级并返回提示文案。
func upgrade_city(city, upgrade_type: String) -> Dictionary:
	if not city.is_occupied():
		return {
			"success": false,
			"message": "%s 还没有归属，不能升级。" % city.name
		}

	match upgrade_type:
		UPGRADE_LEVEL:
			if not city.can_upgrade_level():
				return {
					"success": false,
					"message": "%s 已达到最高等级。" % city.name
				}
			var level_cost: int = city.get_level_upgrade_cost()
			if not city.has_enough_soldiers_for_upgrade(level_cost):
				return {
					"success": false,
					"message": "%s 需要 %d 人才能升级等级。" % [city.name, level_cost]
				}
			city.apply_level_upgrade()
			return {
				"success": true,
				"message": "%s 升到 Lv.%d，容量提升到 %d，上限更高了。" % [city.name, city.level, city.max_soldiers]
			}
		UPGRADE_DEFENSE:
			if not city.can_upgrade_defense():
				return {
					"success": false,
					"message": "%s 的防御已经到顶。" % city.name
				}
			var defense_cost: int = city.get_defense_upgrade_cost()
			if not city.has_enough_soldiers_for_upgrade(defense_cost):
				return {
					"success": false,
					"message": "%s 需要 %d 人才能升级防御。" % [city.name, defense_cost]
				}
			city.apply_defense_upgrade()
			return {
				"success": true,
				"message": "%s 防御升到 %d，攻城方需要更多兵力了。" % [city.name, city.defense]
			}
		UPGRADE_PRODUCTION:
			if not city.can_upgrade_production():
				return {
					"success": false,
					"message": "%s 的产能已经到顶。" % city.name
				}
			var production_cost: int = city.get_production_upgrade_cost()
			if not city.has_enough_soldiers_for_upgrade(production_cost):
				return {
					"success": false,
					"message": "%s 需要 %d 人才能升级产能。" % [city.name, production_cost]
				}
			city.apply_production_upgrade()
			return {
				"success": true,
				"message": "%s 产能升到 %.1f/秒，之后会更快产兵。" % [city.name, city.production_rate]
			}
		_:
			return {
				"success": false,
				"message": "未知升级类型：%s" % upgrade_type
			}


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
