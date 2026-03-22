class_name BattleResolver
extends RefCounted


## 根据城市间的即时进攻规则计算战斗结果。
## 调用场景：`GameState.attack` 在执行合法攻击时调用。
## 主要逻辑：使用攻守双方士兵数相减；若差值大于 0 则攻方占领目标并保留差值，
## 否则目标城市保留原归属并剩余 `abs(diff)` 士兵；进攻城市在即时结算模型下归零。
static func resolve_attack(attacker, defender) -> Dictionary:
	var remaining_difference: int = attacker.soldiers - defender.soldiers
	var defender_owner: int = defender.owner

	if remaining_difference > 0:
		defender_owner = attacker.owner
		return {
			"attacker_remaining": 0,
			"defender_owner": defender_owner,
			"defender_soldiers": remaining_difference,
			"captured": true,
		}

	return {
		"attacker_remaining": 0,
		"defender_owner": defender_owner,
		"defender_soldiers": abs(remaining_difference),
		"captured": false,
	}
