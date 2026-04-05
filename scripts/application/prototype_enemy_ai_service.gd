class_name PrototypeEnemyAiService
extends RefCounted

const PrototypeCityOwnerRef = preload("res://scripts/domain/prototype_city_owner.gd")
const MARCH_SPEED: float = 180.0
const DIFFICULTY_EASY: String = "easy"
const DIFFICULTY_NORMAL: String = "normal"
const DIFFICULTY_HARD: String = "hard"
const STYLE_AGGRESSIVE: String = "aggressive"
const STYLE_DEFENSIVE: String = "defensive"

var _difficulty: String = DIFFICULTY_NORMAL
var _style: String = STYLE_AGGRESSIVE


## 配置敌军 AI 的难度与风格。
##
## 调用场景：开始新对局前、玩家在开始/暂停面板中切换设置后。
## 主要逻辑：把外部传入的难度与风格收敛到支持的枚举值，保证后续决策逻辑稳定可控。
func configure(difficulty: String, style: String) -> void:
	_difficulty = difficulty if difficulty in [DIFFICULTY_EASY, DIFFICULTY_NORMAL, DIFFICULTY_HARD] else DIFFICULTY_NORMAL
	_style = style if style in [STYLE_AGGRESSIVE, STYLE_DEFENSIVE] else STYLE_AGGRESSIVE


## 返回当前 AI 难度对应的行动间隔。
##
## 调用场景：主循环判断敌军是否该行动时。
## 主要逻辑：高难度缩短思考间隔，进攻型再略微加快，防御型则略微放慢。
func get_turn_interval() -> float:
	var interval: float = 4.0
	match _difficulty:
		DIFFICULTY_EASY:
			interval = 5.0
		DIFFICULTY_NORMAL:
			interval = 4.0
		DIFFICULTY_HARD:
			interval = 3.0

	if _style == STYLE_AGGRESSIVE:
		interval -= 0.4
	else:
		interval += 0.4
	return clamp(interval, 2.4, 5.8)


## 根据当前难度和风格为指定 AI 势力选择本轮的最佳进攻指令。
##
## 调用场景：敌军行动定时器达到阈值时。
## 主要逻辑：遍历所有敌军城市，结合路程、目标归属、推荐兵力、目标防御、产能、保留守军要求和风格权重进行打分，
## 返回最值得发起的一次攻击以及建议派出的兵力。
func choose_attack(cities: Array, battle_service, owner_id: int) -> Dictionary:
	var best_source = null
	var best_target = null
	var best_troop_count: int = 0
	var best_score: float = -INF

	for source in cities:
		if source.owner != owner_id:
			continue

		for target_id: int in source.neighbors:
			var target = cities[target_id]
			if target.owner == owner_id:
				continue

			var travel_duration: float = _calculate_travel_duration(source, target)
			var recommended_count: int = battle_service.get_recommended_attack_count(source, target, travel_duration)
			var troop_count: int = _get_attack_troop_count(source.soldiers, recommended_count)
			var reserve_after_attack: int = source.soldiers - troop_count
			var minimum_advantage: int = _get_required_advantage(target)
			if troop_count <= 0:
				continue
			if reserve_after_attack < _get_reserve_requirement():
				continue
			if source.soldiers < target.get_effective_defense() + minimum_advantage:
				continue

			var score: float = _score_target(source, target, troop_count, recommended_count, travel_duration)
			if score > best_score:
				best_score = score
				best_source = source
				best_target = target
				best_troop_count = troop_count

	if best_source == null or best_target == null:
		return {}

	return {
		"source_id": best_source.city_id,
		"target_id": best_target.city_id,
		"troop_count": best_troop_count,
		"owner_id": owner_id
	}


## 根据当前局势为指定 AI 势力选择一条最值得维持的持续出兵路线。
##
## 调用场景：主循环驱动 AI 下发持续出兵任务时。
## 主要逻辑：复用现有进攻择优逻辑挑出最优源城和目标城，但不再关心一次性派兵人数；
## 返回的只是“应该建立哪条持续路线”，真正每次派出的数量固定由持续调度器决定。
func choose_continuous_order(cities: Array, battle_service, owner_id: int) -> Dictionary:
	var attack_decision: Dictionary = choose_attack(cities, battle_service, owner_id)
	if attack_decision.is_empty():
		return {}

	return {
		"source_id": int(attack_decision["source_id"]),
		"target_id": int(attack_decision["target_id"]),
		"owner_id": owner_id
	}


## 根据当前局势为指定 AI 势力选择一次更值得的城市升级。
##
## 调用场景：本轮没有合适进攻时，AI 退而求其次选择养城。
## 主要逻辑：遍历己方城市，结合当前风格、兵力冗余和三种升级收益打分，返回最值得投资的一次升级动作。
func choose_upgrade(cities: Array, battle_service, owner_id: int) -> Dictionary:
	var best_city = null
	var best_upgrade_type: String = ""
	var best_score: float = -INF

	for city in cities:
		if city.owner != owner_id:
			continue

		var options: Dictionary = battle_service.get_city_upgrade_options(city)
		for upgrade_type_variant in options.keys():
			var upgrade_type: String = String(upgrade_type_variant)
			var option: Dictionary = options[upgrade_type]
			if not bool(option.get("available", false)):
				continue
			var cost: int = int(option.get("cost", 0))
			var reserve_after_upgrade: int = city.soldiers - cost
			if reserve_after_upgrade < _get_reserve_requirement() + 2:
				continue

			var score: float = _score_upgrade(city, upgrade_type, cost)
			if score > best_score:
				best_score = score
				best_city = city
				best_upgrade_type = upgrade_type

	if best_city == null:
		return {}

	return {
		"city_id": best_city.city_id,
		"upgrade_type": best_upgrade_type,
		"owner_id": owner_id
	}


## 计算当前难度下 AI 进攻时至少要比守军多出的兵力冗余。
##
## 调用场景：筛选可攻击目标时。
## 主要逻辑：低难度更保守，需要更大优势才肯出击；高难度则会接受更险的进攻窗口。
func _get_minimum_advantage() -> int:
	match _difficulty:
		DIFFICULTY_EASY:
			return 4
		DIFFICULTY_NORMAL:
			return 2
		_:
			return 1


## 计算面对当前目标时 AI 需要保留的额外优势兵力。
##
## 调用场景：筛选候选攻击目标时。
## 主要逻辑：对中立空城或低兵力中立城适当放宽门槛，避免 AI 因为通用保守阈值而放弃明显划算的扩张机会。
func _get_required_advantage(target) -> int:
	var minimum_advantage: int = _get_minimum_advantage()
	if PrototypeCityOwnerRef.is_neutral(target.owner):
		return max(0, minimum_advantage - 2)
	return minimum_advantage


## 计算当前风格下每次出兵后源城至少应保留的兵力。
##
## 调用场景：AI 计算本轮可否进攻以及最多可派多少兵时。
## 主要逻辑：进攻型偏向压上兵力，防御型会在后方保留更多守军。
func _get_reserve_requirement() -> int:
	if _style == STYLE_DEFENSIVE:
		return 3
	return 1


## 结合推荐人数和难度加成，计算 AI 本次计划真实派出的兵力。
##
## 调用场景：AI 决策阶段。
## 主要逻辑：高难度和进攻型会在推荐人数基础上额外多派几人，防御型则更贴近最低必要值。
func _get_attack_troop_count(source_soldiers: int, recommended_count: int) -> int:
	var attack_bonus: int = 0
	match _difficulty:
		DIFFICULTY_NORMAL:
			attack_bonus = 1
		DIFFICULTY_HARD:
			attack_bonus = 3

	if _style == STYLE_AGGRESSIVE:
		attack_bonus += 1

	var max_allowed: int = max(0, source_soldiers - _get_reserve_requirement())
	return min(max_allowed, recommended_count + attack_bonus)


## 给一个候选目标计算综合得分。
##
## 调用场景：AI 在多个可攻击目标之间择优时。
## 主要逻辑：综合考虑目标归属、路程远近、预计盈余兵力、目标防御与产能威胁和当前风格偏好，
## 得到一个可比较的浮点评分；进攻型会更主动压迫玩家，但不会在多人局里无脑忽略更优的非玩家目标。
func _score_target(source, target, troop_count: int, recommended_count: int, travel_duration: float) -> float:
	var score: float = float(troop_count - recommended_count)
	score += float(source.level) * 0.2
	score -= float(target.defense) * 0.45
	score += target.production_rate * 0.7
	score -= travel_duration * (0.3 if _style == STYLE_AGGRESSIVE else 0.8)

	if target.owner == PrototypeCityOwnerRef.PLAYER:
		score += 2.2 if _style == STYLE_AGGRESSIVE else 0.5
	else:
		score += 0.5 if _style == STYLE_AGGRESSIVE else 1.2

	if _difficulty == DIFFICULTY_HARD:
		score += 0.6
	elif _difficulty == DIFFICULTY_EASY:
		score -= 0.4

	return score


## 给一个候选升级动作计算综合得分。
##
## 调用场景：AI 在“升防、升产、升级”之间择优时。
## 主要逻辑：结合当前风格、城市兵力富余、现有属性短板和升级成本，给出一个可比较分值。
func _score_upgrade(city, upgrade_type: String, cost: int) -> float:
	var reserve_after_upgrade: int = city.soldiers - cost
	var score: float = float(reserve_after_upgrade) * 0.08 - float(cost) * 0.05

	match upgrade_type:
		"level":
			score += 2.3 + float(city.level) * 0.45
		"defense":
			score += 1.6 + (1.1 if _style == STYLE_DEFENSIVE else 0.2) - float(city.defense) * 0.12
		"production":
			score += 1.8 + (0.9 if _style == STYLE_AGGRESSIVE else 0.4) - city.production_rate * 0.2

	if _difficulty == DIFFICULTY_HARD:
		score += 0.25
	elif _difficulty == DIFFICULTY_EASY:
		score -= 0.15

	return score


## 根据两座城市的坐标估算部队的行军时间。
##
## 调用场景：AI 预判推荐出兵人数与目标评分时。
## 主要逻辑：复用主战局的距离换时间规则，避免 AI 的兵力预判与玩家规则不一致。
func _calculate_travel_duration(source, target) -> float:
	var distance: float = source.position.distance_to(target.position)
	return max(0.45, distance / MARCH_SPEED)
