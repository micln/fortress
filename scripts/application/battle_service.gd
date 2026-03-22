class_name BattleService
extends RefCounted

const CityOwnerRef = preload("res://scripts/domain/city_owner.gd")


## 执行一次从源城市到目标城市的进攻，并返回结果描述。
##
## 调用场景：玩家点击进攻、敌方 AI 发起进攻。
## 主要逻辑：按照“双方士兵数相减”的规则进行结算。
## 如果进攻方人数更多，则目标城市易主并保留差值兵力；否则目标城市保留原归属并扣除对应兵力。
func resolve_attack(source, target) -> Dictionary:
	var attack_power: int = source.soldiers
	var defend_power: int = target.soldiers

	if attack_power <= 0:
		return {
			"success": false,
			"captured": false,
			"message": "%s 没有可出征的士兵。" % source.name
		}

	source.soldiers = 0

	if attack_power > defend_power:
		target.owner = source.owner
		target.soldiers = attack_power - defend_power
		return {
			"success": true,
			"captured": true,
			"message": "%s 攻下了 %s，剩余 %d 士兵。" % [source.name, target.name, target.soldiers]
		}

	target.soldiers = defend_power - attack_power
	return {
		"success": true,
		"captured": false,
		"message": "%s 的进攻被挡住，%s 还剩 %d 士兵。" % [source.name, target.name, target.soldiers]
	}


## 为所有已占领城市执行一次产兵。
##
## 调用场景：每秒一次的战局 Tick。
## 主要逻辑：遍历城市列表，仅对非中立城市增加 1 名士兵。
func produce_soldiers(cities: Array) -> void:
	for city in cities:
		if city.is_occupied():
			city.soldiers += 1


## 检查是否已经产生单方完全占领的胜负结果。
##
## 调用场景：每次进攻后、每轮 AI 行动后。
## 主要逻辑：统计玩家与敌军是否仍保有城市，若一方城市数归零则另一方获胜。
func get_winner(cities: Array) -> int:
	var player_city_count: int = 0
	var enemy_city_count: int = 0

	for city in cities:
		if city.owner == CityOwnerRef.PLAYER:
			player_city_count += 1
		elif city.owner == CityOwnerRef.ENEMY:
			enemy_city_count += 1

	if player_city_count == 0 and enemy_city_count > 0:
		return CityOwnerRef.ENEMY
	if enemy_city_count == 0 and player_city_count > 0:
		return CityOwnerRef.PLAYER
	return CityOwnerRef.NEUTRAL
