extends SceneTree

const PrototypeCityOwnerRef = preload("res://scripts/domain/prototype_city_owner.gd")
const PrototypeCityStateRef = preload("res://scripts/domain/prototype_city_state.gd")
const PrototypeBattleServiceRef = preload("res://scripts/application/prototype_battle_service.gd")
const PrototypeEnemyAiServiceRef = preload("res://scripts/application/prototype_enemy_ai_service.gd")
const PrototypeMapGeneratorRef = preload("res://scripts/application/prototype_map_generator.gd")


## 运行项目内的最小自定义测试集，并在全部通过后正常退出。
##
## 调用场景：Godot headless 模式下作为主循环脚本执行。
## 主要逻辑：串行执行若干断言函数，任何断言失败都会 push_error 并以非零状态码退出。
func _initialize() -> void:
	var failures: Array[String] = []
	_run_test("attack_prepare_capture", Callable(self, "_test_attack_prepare_capture"), failures)
	_run_test("attack_prepare_with_predicted_growth", Callable(self, "_test_attack_prepare_with_predicted_growth"), failures)
	_run_test("attack_arrival_capture", Callable(self, "_test_attack_arrival_capture"), failures)
	_run_test("attack_arrival_equal_capture", Callable(self, "_test_attack_arrival_equal_capture"), failures)
	_run_test("attack_arrival_fail", Callable(self, "_test_attack_arrival_fail"), failures)
	_run_test("friendly_transfer", Callable(self, "_test_friendly_transfer"), failures)
	_run_test("friendly_transfer_to_lost_city", Callable(self, "_test_friendly_transfer_to_lost_city"), failures)
	_run_test("production", Callable(self, "_test_production"), failures)
	_run_test("production_capacity", Callable(self, "_test_production_capacity"), failures)
	_run_test("marching_encounter", Callable(self, "_test_marching_encounter"), failures)
	_run_test("marching_encounter_draw", Callable(self, "_test_marching_encounter_draw"), failures)
	_run_test("winner", Callable(self, "_test_winner"), failures)
	_run_test("winner_multi_ai", Callable(self, "_test_winner_multi_ai"), failures)
	_run_test("enemy_ai", Callable(self, "_test_enemy_ai"), failures)
	_run_test("enemy_ai_profile", Callable(self, "_test_enemy_ai_profile"), failures)
	_run_test("map_multi_ai_spawn", Callable(self, "_test_map_multi_ai_spawn"), failures)
	_run_test("map_connectivity", Callable(self, "_test_map_connectivity"), failures)

	if failures.is_empty():
		print("ALL TESTS PASSED")
		quit(0)
		return

	for failure: String in failures:
		push_error(failure)
	quit(1)


## 执行单个测试函数并记录失败信息。
##
## 调用场景：测试入口在初始化阶段逐个调用。
## 主要逻辑：用 Callable 执行测试函数，捕获 false 返回值并收集测试名，便于输出简洁结果。
func _run_test(test_name: String, callable: Callable, failures: Array[String]) -> void:
	var passed: bool = bool(callable.call())
	if not passed:
		failures.append("FAILED: %s" % test_name)


## 验证进攻方出兵前只会派出最低必要兵力，源城市会保留剩余守军。
##
## 调用场景：出兵准备阶段规则回归测试。
## 主要逻辑：构造 10 打 6 的样例，检查只派出 7 人，源城市保留 3 人等待后续局势发展。
func _test_attack_prepare_capture() -> bool:
	var battle_service = PrototypeBattleServiceRef.new()
	var source = PrototypeCityStateRef.new(0, "A", Vector2.ZERO, PrototypeCityOwnerRef.PLAYER, 2, 35, 10, [1])
	var target = PrototypeCityStateRef.new(1, "B", Vector2.RIGHT, PrototypeCityOwnerRef.AI_OWNER_START, 1, 20, 6, [0])
	var result: Dictionary = battle_service.prepare_attack(source, target, 0.4, 7)
	return result.get("count", 0) == 7 and source.soldiers == 3 and target.owner == PrototypeCityOwnerRef.AI_OWNER_START and target.soldiers == 6


## 验证出兵时会把目标城在行军途中可能新增的守军数量预估进去。
##
## 调用场景：行军制下的出兵准备阶段回归测试。
## 主要逻辑：构造目标城当前 10 人、预计路上会再长 1 人的样例，检查会派出 12 人而不是 11 人。
func _test_attack_prepare_with_predicted_growth() -> bool:
	var battle_service = PrototypeBattleServiceRef.new()
	var source = PrototypeCityStateRef.new(0, "A", Vector2.ZERO, PrototypeCityOwnerRef.PLAYER, 3, 55, 20, [1])
	var target = PrototypeCityStateRef.new(1, "B", Vector2.RIGHT, PrototypeCityOwnerRef.AI_OWNER_START, 2, 35, 10, [0])
	var recommended_count: int = battle_service.get_recommended_attack_count(source, target, 1.2)
	var result: Dictionary = battle_service.prepare_attack(source, target, 1.2, recommended_count)
	return recommended_count == 12 and result.get("count", 0) == 12 and source.soldiers == 8


## 验证进攻行军到达时会按抵达瞬间的兵力占领目标城市。
##
## 调用场景：进攻到达阶段规则回归测试。
## 主要逻辑：构造 7 人到达 6 守军城市的样例，检查目标被占领且留下 1 人驻守。
func _test_attack_arrival_capture() -> bool:
	var battle_service = PrototypeBattleServiceRef.new()
	var target = PrototypeCityStateRef.new(1, "B", Vector2.RIGHT, PrototypeCityOwnerRef.AI_OWNER_START, 1, 20, 6, [0])
	var result: Dictionary = battle_service.resolve_attack_arrival(target, PrototypeCityOwnerRef.PLAYER, 7)
	return result.get("captured", false) and target.owner == PrototypeCityOwnerRef.PLAYER and target.soldiers == 1


## 验证攻守人数相等时也会占领目标城市，避免出现 0 人未占领的违和状态。
##
## 调用场景：进攻到达阶段规则回归测试。
## 主要逻辑：构造 6 人到达 6 守军城市的样例，检查目标会被占领且至少留下 1 人驻守。
func _test_attack_arrival_equal_capture() -> bool:
	var battle_service = PrototypeBattleServiceRef.new()
	var target = PrototypeCityStateRef.new(1, "B", Vector2.RIGHT, PrototypeCityOwnerRef.AI_OWNER_START, 1, 20, 6, [0])
	var result: Dictionary = battle_service.resolve_attack_arrival(target, PrototypeCityOwnerRef.PLAYER, 6)
	return result.get("captured", false) and target.owner == PrototypeCityOwnerRef.PLAYER and target.soldiers == 1


## 验证进攻行军到达时若兵力不足，只会消耗守军，不会改变归属。
##
## 调用场景：进攻到达阶段规则回归测试。
## 主要逻辑：构造 4 人到达 9 守军城市的样例，检查目标仍归原阵营且守军减少为 5。
func _test_attack_arrival_fail() -> bool:
	var battle_service = PrototypeBattleServiceRef.new()
	var target = PrototypeCityStateRef.new(1, "B", Vector2.RIGHT, PrototypeCityOwnerRef.AI_OWNER_START, 2, 35, 9, [0])
	battle_service.resolve_attack_arrival(target, PrototypeCityOwnerRef.PLAYER, 4)
	return target.owner == PrototypeCityOwnerRef.AI_OWNER_START and target.soldiers == 5


## 验证己方城市点到己方城市时会执行运兵而不是攻击。
##
## 调用场景：友军操作规则回归测试。
## 主要逻辑：构造两座相邻己方城市，检查源城市只扣除本次运兵数量，目标城市增加兵力，且归属不发生变化。
func _test_friendly_transfer() -> bool:
	var battle_service = PrototypeBattleServiceRef.new()
	var source = PrototypeCityStateRef.new(0, "A", Vector2.ZERO, PrototypeCityOwnerRef.PLAYER, 2, 35, 7, [1])
	var target = PrototypeCityStateRef.new(1, "B", Vector2.RIGHT, PrototypeCityOwnerRef.PLAYER, 2, 35, 5, [0])
	var prepare_result: Dictionary = battle_service.prepare_transfer(source, target, 4)
	var arrival_result: Dictionary = battle_service.resolve_transfer_arrival(target, PrototypeCityOwnerRef.PLAYER, int(prepare_result.get("count", 0)))
	return bool(prepare_result.get("success", false)) and bool(arrival_result.get("success", false)) and source.soldiers == 3 and target.owner == PrototypeCityOwnerRef.PLAYER and target.soldiers == 9


## 验证若运兵目标在途中失守，迟到援军会与当前守军重新交战。
##
## 调用场景：并发行军场景回归测试。
## 主要逻辑：构造一座已被电脑势力夺取的目标城，检查迟到援军会按正常战斗结算重新夺城，而不是直接变成对方兵力。
func _test_friendly_transfer_to_lost_city() -> bool:
	var battle_service = PrototypeBattleServiceRef.new()
	var source = PrototypeCityStateRef.new(0, "A", Vector2.ZERO, PrototypeCityOwnerRef.PLAYER, 3, 120, 20, [1])
	var target = PrototypeCityStateRef.new(1, "B", Vector2.RIGHT, PrototypeCityOwnerRef.AI_OWNER_START, 3, 120, 5, [0])
	var prepare_result: Dictionary = battle_service.prepare_transfer(source, target, 20)
	var arrival_result: Dictionary = battle_service.resolve_transfer_arrival(target, PrototypeCityOwnerRef.PLAYER, int(prepare_result.get("count", 0)))
	return bool(arrival_result.get("retook_after_loss", false)) and target.owner == PrototypeCityOwnerRef.PLAYER and target.soldiers == 15


## 验证只有已占领城市会产兵，中立城市不会增长。
##
## 调用场景：产兵 Tick 回归测试。
## 主要逻辑：对玩家、电脑势力、中立三类城市执行一次产兵，检查增长结果是否符合规则。
func _test_production() -> bool:
	var battle_service = PrototypeBattleServiceRef.new()
	var cities: Array = [
		PrototypeCityStateRef.new(0, "A", Vector2.ZERO, PrototypeCityOwnerRef.PLAYER, 1, 20, 3, [1]),
		PrototypeCityStateRef.new(1, "B", Vector2.RIGHT, PrototypeCityOwnerRef.AI_OWNER_START, 1, 20, 4, [0, 2]),
		PrototypeCityStateRef.new(2, "C", Vector2.DOWN, PrototypeCityOwnerRef.NEUTRAL, 1, 20, 5, [1])
	]
	battle_service.produce_soldiers(cities)
	return cities[0].soldiers == 4 and cities[1].soldiers == 5 and cities[2].soldiers == 5


## 验证城市达到人口上限后不会继续产兵。
##
## 调用场景：等级和上限系统回归测试。
## 主要逻辑：构造一座兵力已满的己方城市，执行一次产兵后检查人数保持不变。
func _test_production_capacity() -> bool:
	var battle_service = PrototypeBattleServiceRef.new()
	var cities: Array = [
		PrototypeCityStateRef.new(0, "A", Vector2.ZERO, PrototypeCityOwnerRef.PLAYER, 1, 20, 20, [1])
	]
	battle_service.produce_soldiers(cities)
	return cities[0].soldiers == 20


## 验证道路上两支不同势力行军部队相遇时，大兵团会吞掉小兵团并保留差值。
##
## 调用场景：路上遭遇战规则回归测试。
## 主要逻辑：构造 12 人与 5 人的遭遇战，检查胜方保留 7 人继续前进。
func _test_marching_encounter() -> bool:
	var battle_service = PrototypeBattleServiceRef.new()
	var result: Dictionary = battle_service.resolve_marching_encounter(
		PrototypeCityOwnerRef.PLAYER,
		12,
		PrototypeCityOwnerRef.AI_OWNER_START,
		5
	)
	return not bool(result.get("both_destroyed", true)) \
		and int(result.get("winner_owner", -1)) == PrototypeCityOwnerRef.PLAYER \
		and int(result.get("remaining_count", -1)) == 7


## 验证道路上两支不同势力行军部队人数相同时会同归于尽。
##
## 调用场景：路上遭遇战规则回归测试。
## 主要逻辑：构造 8 人对 8 人的遭遇战，检查双方都被消灭。
func _test_marching_encounter_draw() -> bool:
	var battle_service = PrototypeBattleServiceRef.new()
	var result: Dictionary = battle_service.resolve_marching_encounter(
		PrototypeCityOwnerRef.PLAYER,
		8,
		PrototypeCityOwnerRef.AI_OWNER_START,
		8
	)
	return bool(result.get("both_destroyed", false)) and int(result.get("remaining_count", -1)) == 0


## 验证单方失去全部城市时能正确判定获胜方。
##
## 调用场景：胜负规则回归测试。
## 主要逻辑：构造只剩玩家城市的局面，检查赢家是否为玩家。
func _test_winner() -> bool:
	var battle_service = PrototypeBattleServiceRef.new()
	var cities: Array = [
		PrototypeCityStateRef.new(0, "A", Vector2.ZERO, PrototypeCityOwnerRef.PLAYER, 1, 20, 3, [1]),
		PrototypeCityStateRef.new(1, "B", Vector2.RIGHT, PrototypeCityOwnerRef.PLAYER, 1, 20, 4, [0])
	]
	return battle_service.get_winner(cities) == PrototypeCityOwnerRef.PLAYER


## 验证多电脑势力混战时，只剩最后一个阵营后也能正确判定获胜方。
##
## 调用场景：多势力胜负规则回归测试。
## 主要逻辑：构造玩家已灭亡、只剩一支电脑势力占城的局面，检查赢家为对应电脑阵营编号。
func _test_winner_multi_ai() -> bool:
	var battle_service = PrototypeBattleServiceRef.new()
	var cities: Array = [
		PrototypeCityStateRef.new(0, "A", Vector2.ZERO, PrototypeCityOwnerRef.AI_OWNER_START + 1, 2, 35, 8, [1]),
		PrototypeCityStateRef.new(1, "B", Vector2.RIGHT, PrototypeCityOwnerRef.AI_OWNER_START + 1, 1, 20, 5, [0])
	]
	return battle_service.get_winner(cities) == PrototypeCityOwnerRef.AI_OWNER_START + 1


## 验证敌军 AI 会优先选择具备优势的可攻击目标。
##
## 调用场景：AI 决策回归测试。
## 主要逻辑：构造一个敌军强城相邻玩家弱城的局面，检查 AI 是否返回该攻击组合。
func _test_enemy_ai() -> bool:
	var ai_service = PrototypeEnemyAiServiceRef.new()
	ai_service.configure(PrototypeEnemyAiServiceRef.DIFFICULTY_NORMAL, PrototypeEnemyAiServiceRef.STYLE_AGGRESSIVE)
	var cities: Array = [
		PrototypeCityStateRef.new(0, "A", Vector2.ZERO, PrototypeCityOwnerRef.AI_OWNER_START, 2, 35, 8, [1]),
		PrototypeCityStateRef.new(1, "B", Vector2.RIGHT, PrototypeCityOwnerRef.PLAYER, 1, 20, 3, [0, 2]),
		PrototypeCityStateRef.new(2, "C", Vector2.DOWN, PrototypeCityOwnerRef.AI_OWNER_START, 1, 20, 2, [1])
	]
	var battle_service = PrototypeBattleServiceRef.new()
	var decision: Dictionary = ai_service.choose_attack(cities, battle_service, PrototypeCityOwnerRef.AI_OWNER_START)
	return int(decision.get("source_id", -1)) == 0 and int(decision.get("target_id", -1)) == 1 and int(decision.get("troop_count", 0)) >= 5


## 验证不同难度和风格会影响敌军行动节奏与目标偏好。
##
## 调用场景：AI 配置系统回归测试。
## 主要逻辑：检查困难进攻型比简单防御型行动更快，并在同一局面下更偏向直接攻击玩家城市。
func _test_enemy_ai_profile() -> bool:
	var battle_service = PrototypeBattleServiceRef.new()
	var cities: Array = [
		PrototypeCityStateRef.new(0, "A", Vector2.ZERO, PrototypeCityOwnerRef.AI_OWNER_START, 3, 55, 12, [1, 2]),
		PrototypeCityStateRef.new(1, "B", Vector2(120, 0), PrototypeCityOwnerRef.PLAYER, 2, 35, 7, [0]),
		PrototypeCityStateRef.new(2, "C", Vector2(90, 70), PrototypeCityOwnerRef.NEUTRAL, 1, 20, 4, [0])
	]
	var aggressive_ai = PrototypeEnemyAiServiceRef.new()
	aggressive_ai.configure(PrototypeEnemyAiServiceRef.DIFFICULTY_HARD, PrototypeEnemyAiServiceRef.STYLE_AGGRESSIVE)
	var defensive_ai = PrototypeEnemyAiServiceRef.new()
	defensive_ai.configure(PrototypeEnemyAiServiceRef.DIFFICULTY_EASY, PrototypeEnemyAiServiceRef.STYLE_DEFENSIVE)
	var aggressive_decision: Dictionary = aggressive_ai.choose_attack(cities, battle_service, PrototypeCityOwnerRef.AI_OWNER_START)
	var defensive_decision: Dictionary = defensive_ai.choose_attack(cities, battle_service, PrototypeCityOwnerRef.AI_OWNER_START)
	return aggressive_ai.get_turn_interval() < defensive_ai.get_turn_interval() \
		and int(aggressive_decision.get("target_id", -1)) == 1 \
		and int(defensive_decision.get("target_id", -1)) == 2


## 验证地图生成时可以按指定数量生成多个独立电脑主城。
##
## 调用场景：多势力开局生成回归测试。
## 主要逻辑：请求 3 家电脑开局，检查地图里恰好有 1 个玩家主城和 3 个不同编号的电脑主城。
func _test_map_multi_ai_spawn() -> bool:
	var generator = PrototypeMapGeneratorRef.new()
	var random: RandomNumberGenerator = RandomNumberGenerator.new()
	random.seed = 7
	var cities: Array = generator.generate_map(9, random, 3)
	var player_count: int = 0
	var ai_owners: Dictionary = {}
	for city in cities:
		if city.owner == PrototypeCityOwnerRef.PLAYER:
			player_count += 1
		elif PrototypeCityOwnerRef.is_ai(city.owner):
			ai_owners[city.owner] = true
	return player_count == 1 and ai_owners.size() == 3


## 验证地图生成器生成的道路图至少保持整体连通。
##
## 调用场景：地图生成回归测试。
## 主要逻辑：从第一个城市做广度优先遍历，只要能访问到全部城市，即说明连通主链成立。
func _test_map_connectivity() -> bool:
	var generator = PrototypeMapGeneratorRef.new()
	var random: RandomNumberGenerator = RandomNumberGenerator.new()
	random.seed = 42
	var cities: Array = generator.generate_map(9, random)
	var queue: Array[int] = [0]
	var visited: Dictionary = {0: true}

	while not queue.is_empty():
		var current_id: int = int(queue.pop_front())
		for neighbor_id: int in cities[current_id].neighbors:
			if visited.has(neighbor_id):
				continue
			visited[neighbor_id] = true
			queue.append(neighbor_id)

	return visited.size() == cities.size()
