extends SceneTree

const PrototypeCityOwnerRef = preload("res://scripts/domain/prototype_city_owner.gd")
const PrototypeCityStateRef = preload("res://scripts/domain/prototype_city_state.gd")
const PrototypeBattleServiceRef = preload("res://scripts/application/prototype_battle_service.gd")
const PrototypeEnemyAiServiceRef = preload("res://scripts/application/prototype_enemy_ai_service.gd")
const PrototypeMapGeneratorRef = preload("res://scripts/application/prototype_map_generator.gd")
const PrototypePresetMapDefinitionRef = preload("res://scripts/application/prototype_preset_map_definition.gd")
const PrototypePresetMapLoaderRef = preload("res://scripts/application/prototype_preset_map_loader.gd")


## 运行项目内的最小自定义测试集，并在全部通过后正常退出。
##
## 调用场景：Godot headless 模式下作为主循环脚本执行。
## 主要逻辑：串行执行若干断言函数，任何断言失败都会 push_error 并以非零状态码退出。
func _initialize() -> void:
	var failures: Array[String] = []
	_run_test("attack_prepare_capture", Callable(self, "_test_attack_prepare_capture"), failures)
	_run_test("attack_prepare_with_predicted_growth", Callable(self, "_test_attack_prepare_with_predicted_growth"), failures)
	_run_test("attack_prepare_with_defense", Callable(self, "_test_attack_prepare_with_defense"), failures)
	_run_test("attack_arrival_capture", Callable(self, "_test_attack_arrival_capture"), failures)
	_run_test("attack_arrival_equal_capture", Callable(self, "_test_attack_arrival_equal_capture"), failures)
	_run_test("attack_arrival_fail", Callable(self, "_test_attack_arrival_fail"), failures)
	_run_test("attack_arrival_neutral_empty_city", Callable(self, "_test_attack_arrival_neutral_empty_city"), failures)
	_run_test("friendly_transfer", Callable(self, "_test_friendly_transfer"), failures)
	_run_test("friendly_transfer_to_lost_city", Callable(self, "_test_friendly_transfer_to_lost_city"), failures)
	_run_test("production", Callable(self, "_test_production"), failures)
	_run_test("production_fractional_rate", Callable(self, "_test_production_fractional_rate"), failures)
	_run_test("production_capacity", Callable(self, "_test_production_capacity"), failures)
	_run_test("upgrade_level_success", Callable(self, "_test_upgrade_level_success"), failures)
	_run_test("upgrade_defense_insufficient", Callable(self, "_test_upgrade_defense_insufficient"), failures)
	_run_test("upgrade_production_cap", Callable(self, "_test_upgrade_production_cap"), failures)
	_run_test("marching_encounter", Callable(self, "_test_marching_encounter"), failures)
	_run_test("marching_encounter_draw", Callable(self, "_test_marching_encounter_draw"), failures)
	_run_test("winner", Callable(self, "_test_winner"), failures)
	_run_test("winner_multi_ai", Callable(self, "_test_winner_multi_ai"), failures)
	_run_test("enemy_ai", Callable(self, "_test_enemy_ai"), failures)
	_run_test("enemy_ai_profile", Callable(self, "_test_enemy_ai_profile"), failures)
	_run_test("enemy_ai_aggressive_not_player_only", Callable(self, "_test_enemy_ai_aggressive_not_player_only"), failures)
	_run_test("enemy_ai_upgrade", Callable(self, "_test_enemy_ai_upgrade"), failures)
	_run_test("map_multi_ai_spawn", Callable(self, "_test_map_multi_ai_spawn"), failures)
	_run_test("map_connectivity", Callable(self, "_test_map_connectivity"), failures)
	_run_test("preset_map_loader_builds_cities", Callable(self, "_test_preset_map_loader_builds_cities"), failures)
	_run_test("preset_map_spawn_sets_cover_supported_faction_counts", Callable(self, "_test_preset_map_spawn_sets_cover_supported_faction_counts"), failures)
	_run_test("preset_map_is_connected", Callable(self, "_test_preset_map_is_connected"), failures)
	_run_test("project_main_scene_still_prototype_main", Callable(self, "_test_project_main_scene_still_prototype_main"), failures)
	_run_test("legacy_main_chain_removed", Callable(self, "_test_legacy_main_chain_removed"), failures)

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
## 主要逻辑：构造目标城当前 10 人、防御 1、预计路上会再长 1 人的样例，
## 检查会派出 13 人而不是只看表面守军的 11 人。
func _test_attack_prepare_with_predicted_growth() -> bool:
	var battle_service = PrototypeBattleServiceRef.new()
	var source = PrototypeCityStateRef.new(0, "A", Vector2.ZERO, PrototypeCityOwnerRef.PLAYER, 3, 55, 20, [1])
	var target = PrototypeCityStateRef.new(1, "B", Vector2.RIGHT, PrototypeCityOwnerRef.AI_OWNER_START, 2, 35, 10, [0], 1, 1.0)
	var recommended_count: int = battle_service.get_recommended_attack_count(source, target, 1.2)
	var result: Dictionary = battle_service.prepare_attack(source, target, 1.2, recommended_count)
	return recommended_count == 13 and result.get("count", 0) == 13 and source.soldiers == 7


## 验证高防御城市会抬高推荐出兵人数。
##
## 调用场景：出兵准备阶段引入城市防御属性后的回归测试。
## 主要逻辑：构造表面守军不高但防御值偏高的目标城，检查系统推荐人数会把防御门槛算进去。
func _test_attack_prepare_with_defense() -> bool:
	var battle_service = PrototypeBattleServiceRef.new()
	var source = PrototypeCityStateRef.new(0, "A", Vector2.ZERO, PrototypeCityOwnerRef.PLAYER, 2, 35, 15, [1])
	var target = PrototypeCityStateRef.new(1, "B", Vector2.RIGHT, PrototypeCityOwnerRef.AI_OWNER_START, 1, 20, 5, [0], 3, 0.8)
	return battle_service.get_recommended_attack_count(source, target, 0.5) == 9


## 验证进攻行军到达时会按抵达瞬间的兵力占领目标城市。
##
## 调用场景：进攻到达阶段规则回归测试。
## 主要逻辑：构造 8 人到达 6 守军、防御 2 的城市样例，检查目标被占领且留下 1 人驻守。
func _test_attack_arrival_capture() -> bool:
	var battle_service = PrototypeBattleServiceRef.new()
	var target = PrototypeCityStateRef.new(1, "B", Vector2.RIGHT, PrototypeCityOwnerRef.AI_OWNER_START, 1, 20, 6, [0], 2, 1.0)
	var result: Dictionary = battle_service.resolve_attack_arrival(target, PrototypeCityOwnerRef.PLAYER, 8)
	return result.get("captured", false) and target.owner == PrototypeCityOwnerRef.PLAYER and target.soldiers == 1


## 验证攻守人数相等时也会占领目标城市，避免出现 0 人未占领的违和状态。
##
## 调用场景：进攻到达阶段规则回归测试。
## 主要逻辑：构造 8 人到达“6 守军 + 2 防御”的城市样例，检查目标会被占领且至少留下 1 人驻守。
func _test_attack_arrival_equal_capture() -> bool:
	var battle_service = PrototypeBattleServiceRef.new()
	var target = PrototypeCityStateRef.new(1, "B", Vector2.RIGHT, PrototypeCityOwnerRef.AI_OWNER_START, 1, 20, 6, [0], 2, 1.0)
	var result: Dictionary = battle_service.resolve_attack_arrival(target, PrototypeCityOwnerRef.PLAYER, 8)
	return result.get("captured", false) and target.owner == PrototypeCityOwnerRef.PLAYER and target.soldiers == 1


## 验证进攻行军到达时若兵力不足，只会消耗守军，不会改变归属。
##
## 调用场景：进攻到达阶段规则回归测试。
## 主要逻辑：构造 4 人到达 9 守军、防御 2 的城市样例，检查目标仍归原阵营且守军减少为 5。
func _test_attack_arrival_fail() -> bool:
	var battle_service = PrototypeBattleServiceRef.new()
	var target = PrototypeCityStateRef.new(1, "B", Vector2.RIGHT, PrototypeCityOwnerRef.AI_OWNER_START, 2, 35, 9, [0], 2, 1.0)
	battle_service.resolve_attack_arrival(target, PrototypeCityOwnerRef.PLAYER, 4)
	return target.owner == PrototypeCityOwnerRef.AI_OWNER_START and target.soldiers == 5


## 验证中立空城不会因为防御值而阻止首次占领。
##
## 调用场景：AI 或玩家进攻无驻军中立城时。
## 主要逻辑：构造一座守军为 0、带有防御属性的中立城市，检查只要有 1 人到达就能成功占领。
func _test_attack_arrival_neutral_empty_city() -> bool:
	var battle_service = PrototypeBattleServiceRef.new()
	var target = PrototypeCityStateRef.new(1, "B", Vector2.RIGHT, PrototypeCityOwnerRef.NEUTRAL, 1, 20, 0, [0], 3, 1.0)
	var result: Dictionary = battle_service.resolve_attack_arrival(target, PrototypeCityOwnerRef.AI_OWNER_START, 1)
	return result.get("captured", false) and target.owner == PrototypeCityOwnerRef.AI_OWNER_START and target.soldiers == 1


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
## 主要逻辑：构造一座已被电脑势力夺取的目标城，检查迟到援军会按正常战斗结算重新夺城；
## 引入城市防御后，夺回成功后的留守人数应扣除该防御门槛，而不是直接沿用旧结果。
func _test_friendly_transfer_to_lost_city() -> bool:
	var battle_service = PrototypeBattleServiceRef.new()
	var source = PrototypeCityStateRef.new(0, "A", Vector2.ZERO, PrototypeCityOwnerRef.PLAYER, 3, 120, 20, [1])
	var target = PrototypeCityStateRef.new(1, "B", Vector2.RIGHT, PrototypeCityOwnerRef.AI_OWNER_START, 3, 120, 5, [0])
	var prepare_result: Dictionary = battle_service.prepare_transfer(source, target, 20)
	var arrival_result: Dictionary = battle_service.resolve_transfer_arrival(target, PrototypeCityOwnerRef.PLAYER, int(prepare_result.get("count", 0)))
	return bool(arrival_result.get("retook_after_loss", false)) and target.owner == PrototypeCityOwnerRef.PLAYER and target.soldiers == 14


## 验证只有已占领城市会产兵，中立城市不会增长。
##
## 调用场景：产兵 Tick 回归测试。
## 主要逻辑：对玩家、电脑势力、中立三类城市执行一次产兵，检查增长结果是否符合规则；
## 其中高产能城市应一次多产 1 人。
func _test_production() -> bool:
	var battle_service = PrototypeBattleServiceRef.new()
	var cities: Array = [
		PrototypeCityStateRef.new(0, "A", Vector2.ZERO, PrototypeCityOwnerRef.PLAYER, 1, 20, 3, [1], 1, 1.0),
		PrototypeCityStateRef.new(1, "B", Vector2.RIGHT, PrototypeCityOwnerRef.AI_OWNER_START, 1, 20, 4, [0, 2], 1, 1.6),
		PrototypeCityStateRef.new(2, "C", Vector2.DOWN, PrototypeCityOwnerRef.NEUTRAL, 1, 20, 5, [1], 1, 1.0)
	]
	battle_service.produce_soldiers(cities)
	return cities[0].soldiers == 4 and cities[1].soldiers == 5 and cities[2].soldiers == 5


## 验证小数产能会跨 Tick 累积，而不是被直接舍弃。
##
## 调用场景：城市产能支持非整数速度后的回归测试。
## 主要逻辑：构造 1.5 产能城市，连续执行两次产兵，检查结果为总共新增 3 人。
func _test_production_fractional_rate() -> bool:
	var battle_service = PrototypeBattleServiceRef.new()
	var cities: Array = [
		PrototypeCityStateRef.new(0, "A", Vector2.ZERO, PrototypeCityOwnerRef.PLAYER, 2, 35, 10, [1], 1, 1.5)
	]
	battle_service.produce_soldiers(cities)
	battle_service.produce_soldiers(cities)
	return cities[0].soldiers == 13


## 验证城市达到人口上限后不会继续产兵。
##
## 调用场景：等级和上限系统回归测试。
## 主要逻辑：构造一座兵力已满的己方城市，执行一次产兵后检查人数保持不变。
func _test_production_capacity() -> bool:
	var battle_service = PrototypeBattleServiceRef.new()
	var cities: Array = [
		PrototypeCityStateRef.new(0, "A", Vector2.ZERO, PrototypeCityOwnerRef.PLAYER, 1, 20, 20, [1], 1, 2.0)
	]
	battle_service.produce_soldiers(cities)
	return cities[0].soldiers == 20


## 验证等级升级会扣除驻军并提升容量上限。
##
## 调用场景：城市升级系统回归测试。
## 主要逻辑：构造一座有足够驻军的己方城市，检查升级后等级、容量和剩余兵力都符合预期。
func _test_upgrade_level_success() -> bool:
	var battle_service = PrototypeBattleServiceRef.new()
	var city = PrototypeCityStateRef.new(0, "A", Vector2.ZERO, PrototypeCityOwnerRef.PLAYER, 2, 35, 20, [1], 2, 1.1)
	var result: Dictionary = battle_service.upgrade_city(city, PrototypeBattleServiceRef.UPGRADE_LEVEL)
	return bool(result.get("success", false)) and city.level == 3 and city.max_soldiers == 55 and city.soldiers == 6


## 验证兵力不足时不能执行防御升级。
##
## 调用场景：城市升级系统回归测试。
## 主要逻辑：构造一座兵力不足的城市，检查升级失败且属性与兵力都保持不变。
func _test_upgrade_defense_insufficient() -> bool:
	var battle_service = PrototypeBattleServiceRef.new()
	var city = PrototypeCityStateRef.new(0, "A", Vector2.ZERO, PrototypeCityOwnerRef.PLAYER, 1, 20, 5, [1], 2, 1.0)
	var result: Dictionary = battle_service.upgrade_city(city, PrototypeBattleServiceRef.UPGRADE_DEFENSE)
	return not bool(result.get("success", true)) and city.defense == 2 and city.soldiers == 5


## 验证产能达到上限后不能继续升级。
##
## 调用场景：城市升级系统回归测试。
## 主要逻辑：构造一座产能已满的城市，检查升级失败且产能保持不变。
func _test_upgrade_production_cap() -> bool:
	var battle_service = PrototypeBattleServiceRef.new()
	var city = PrototypeCityStateRef.new(0, "A", Vector2.ZERO, PrototypeCityOwnerRef.PLAYER, 3, 55, 40, [1], 2, 2.4)
	var result: Dictionary = battle_service.upgrade_city(city, PrototypeBattleServiceRef.UPGRADE_PRODUCTION)
	return not bool(result.get("success", true)) and is_equal_approx(city.production_rate, 2.4)


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
## 主要逻辑：构造一个敌军强城相邻玩家弱城的局面，检查 AI 是否返回该攻击组合；
## 目标城的防御与产能属性也应被纳入推荐兵力与评分。
func _test_enemy_ai() -> bool:
	var ai_service = PrototypeEnemyAiServiceRef.new()
	ai_service.configure(PrototypeEnemyAiServiceRef.DIFFICULTY_NORMAL, PrototypeEnemyAiServiceRef.STYLE_AGGRESSIVE)
	var cities: Array = [
		PrototypeCityStateRef.new(0, "A", Vector2.ZERO, PrototypeCityOwnerRef.AI_OWNER_START, 2, 35, 8, [1]),
		PrototypeCityStateRef.new(1, "B", Vector2.RIGHT, PrototypeCityOwnerRef.PLAYER, 1, 20, 3, [0, 2], 1, 1.3),
		PrototypeCityStateRef.new(2, "C", Vector2.DOWN, PrototypeCityOwnerRef.AI_OWNER_START, 1, 20, 2, [1], 1, 1.0)
	]
	var battle_service = PrototypeBattleServiceRef.new()
	var decision: Dictionary = ai_service.choose_attack(cities, battle_service, PrototypeCityOwnerRef.AI_OWNER_START)
	return int(decision.get("source_id", -1)) == 0 and int(decision.get("target_id", -1)) == 1 and int(decision.get("troop_count", 0)) >= 5


## 验证不同难度和风格会影响敌军行动节奏与目标偏好。
##
## 调用场景：AI 配置系统回归测试。
## 主要逻辑：检查困难进攻型比简单防御型行动更快，并在同一局面下更愿意压上兵力直接攻击玩家城市；
## 同时验证目标防御/产能也会影响评分。
func _test_enemy_ai_profile() -> bool:
	var battle_service = PrototypeBattleServiceRef.new()
	var cities: Array = [
		PrototypeCityStateRef.new(0, "A", Vector2.ZERO, PrototypeCityOwnerRef.AI_OWNER_START, 3, 55, 12, [1, 2], 2, 1.2),
		PrototypeCityStateRef.new(1, "B", Vector2(120, 0), PrototypeCityOwnerRef.PLAYER, 2, 35, 7, [0], 1, 1.5),
		PrototypeCityStateRef.new(2, "C", Vector2(90, 70), PrototypeCityOwnerRef.NEUTRAL, 1, 20, 4, [0], 3, 0.8)
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


## 验证进攻型 AI 在多人局中不会因为玩家存在就无脑忽略更优的非玩家目标。
##
## 调用场景：多人势力目标选择回归测试。
## 主要逻辑：构造一个玩家城市更远且更难打、另一家电脑城市更近且更脆弱的局面，
## 检查进攻型 AI 会优先拿下更高性价比的非玩家目标，而不是固定只追着玩家打。
func _test_enemy_ai_aggressive_not_player_only() -> bool:
	var battle_service = PrototypeBattleServiceRef.new()
	var cities: Array = [
		PrototypeCityStateRef.new(0, "A", Vector2.ZERO, PrototypeCityOwnerRef.AI_OWNER_START, 3, 55, 12, [1, 2], 2, 1.0),
		PrototypeCityStateRef.new(1, "B", Vector2(220, 0), PrototypeCityOwnerRef.PLAYER, 2, 35, 8, [0], 3, 1.4),
		PrototypeCityStateRef.new(2, "C", Vector2(90, 20), PrototypeCityOwnerRef.AI_OWNER_START + 1, 1, 20, 4, [0], 1, 1.0)
	]
	var aggressive_ai = PrototypeEnemyAiServiceRef.new()
	aggressive_ai.configure(PrototypeEnemyAiServiceRef.DIFFICULTY_HARD, PrototypeEnemyAiServiceRef.STYLE_AGGRESSIVE)
	var decision: Dictionary = aggressive_ai.choose_attack(cities, battle_service, PrototypeCityOwnerRef.AI_OWNER_START)
	return int(decision.get("source_id", -1)) == 0 \
		and int(decision.get("target_id", -1)) == 2 \
		and int(decision.get("troop_count", 0)) >= 6


## 验证当没有合适攻击目标时，AI 会退而选择养城升级。
##
## 调用场景：AI 城市经营回归测试。
## 主要逻辑：构造一座高兵力但周边都不适合进攻的城市，检查 AI 至少会返回一条合法升级决策。
func _test_enemy_ai_upgrade() -> bool:
	var battle_service = PrototypeBattleServiceRef.new()
	var ai_service = PrototypeEnemyAiServiceRef.new()
	ai_service.configure(PrototypeEnemyAiServiceRef.DIFFICULTY_NORMAL, PrototypeEnemyAiServiceRef.STYLE_DEFENSIVE)
	var cities: Array = [
		PrototypeCityStateRef.new(0, "A", Vector2.ZERO, PrototypeCityOwnerRef.AI_OWNER_START, 2, 35, 26, [1], 2, 1.0),
		PrototypeCityStateRef.new(1, "B", Vector2.RIGHT, PrototypeCityOwnerRef.PLAYER, 3, 55, 22, [0], 4, 1.6)
	]
	var decision: Dictionary = ai_service.choose_upgrade(cities, battle_service, PrototypeCityOwnerRef.AI_OWNER_START)
	return not decision.is_empty() \
		and int(decision.get("city_id", -1)) == 0 \
		and String(decision.get("upgrade_type", "")) in [PrototypeBattleServiceRef.UPGRADE_LEVEL, PrototypeBattleServiceRef.UPGRADE_DEFENSE, PrototypeBattleServiceRef.UPGRADE_PRODUCTION]


## 验证地图生成时可以按指定数量生成多个独立电脑主城。
##
## 调用场景：多势力开局生成回归测试。
## 主要逻辑：请求 3 家电脑开局，检查地图里恰好有 1 个玩家主城和 3 个不同编号的电脑主城，
## 且城市都会带上有效的防御和产能属性。
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
		if city.defense < 1 or city.production_rate <= 0.0:
			return false
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


## 验证预设地图 loader 能构建出第一阶段所需规模的运行时城市数组。
##
## 调用场景：预设地图系统第一阶段回归测试。
## 主要逻辑：从第一张预设图定义构建一局默认 5 方地图，检查返回数组非空、城市数落在设计范围内，且元素为可用城市状态。
func _test_preset_map_loader_builds_cities() -> bool:
	var loader = PrototypePresetMapLoaderRef.new()
	var definition = PrototypePresetMapDefinitionRef.new()
	var random := RandomNumberGenerator.new()
	random.seed = 42
	var cities: Array = loader.build_map({
		"player_count": 5
	}, Vector2(1400.0, 2400.0), random)
	if cities.is_empty():
		return false
	if cities.size() < 12 or cities.size() > 18:
		return false
	return cities[0] is PrototypeCityStateRef


## 验证第一张预设图为 2 至 5 方都提供了合法出生配置。
##
## 调用场景：预设地图定义完整性回归测试。
## 主要逻辑：读取定义中的 `spawn_sets_by_faction_count`，确认每种方数都有玩家出生点、正确数量的 AI 出生点，且同一配置无重复城市。
func _test_preset_map_spawn_sets_cover_supported_faction_counts() -> bool:
	var definition = PrototypePresetMapDefinitionRef.new()
	var spawn_sets: Dictionary = definition.get_spawn_sets_by_faction_count()
	for faction_count: int in [2, 3, 4, 5]:
		if not spawn_sets.has(faction_count):
			return false
		var spawn_set: Dictionary = spawn_sets[faction_count]
		var player_city_id: int = int(spawn_set.get("player_city_id", -1))
		var ai_city_ids: Array = spawn_set.get("ai_city_ids", [])
		if player_city_id < 0:
			return false
		if ai_city_ids.size() != faction_count - 1:
			return false
		var used_ids: Dictionary = {player_city_id: true}
		for ai_city_id_variant in ai_city_ids:
			var ai_city_id: int = int(ai_city_id_variant)
			if used_ids.has(ai_city_id):
				return false
			used_ids[ai_city_id] = true
	return true


## 验证第一张预设图构建后的道路网络整体连通。
##
## 调用场景：预设地图结构回归测试。
## 主要逻辑：使用 loader 构建一局默认地图，再通过 BFS 验证任意城市都可达，避免出现孤岛。
func _test_preset_map_is_connected() -> bool:
	var loader = PrototypePresetMapLoaderRef.new()
	var definition = PrototypePresetMapDefinitionRef.new()
	var random := RandomNumberGenerator.new()
	random.seed = 99
	var cities: Array = loader.build_map({
		"player_count": 5
	}, Vector2(1400.0, 2400.0), random)
	if cities.is_empty():
		return false
	var visited: Dictionary = {0: true}
	var queue: Array[int] = [0]
	while not queue.is_empty():
		var current_id: int = queue.pop_front()
		var city = cities[current_id]
		for neighbor_id: int in city.neighbors:
			if visited.has(neighbor_id):
				continue
			visited[neighbor_id] = true
			queue.append(neighbor_id)
	return visited.size() == cities.size()


## 验证项目运行入口仍然指向 prototype 主场景。
##
## 调用场景：运行链路守护测试。
## 主要逻辑：读取 `project.godot` 文本，确认 `run/main_scene` 没有被错误改离当前唯一生效入口。
func _test_project_main_scene_still_prototype_main() -> bool:
	var file := FileAccess.open("res://project.godot", FileAccess.READ)
	if file == null:
		return false
	var contents: String = file.get_as_text()
	return contents.contains('run/main_scene="res://scenes/main/prototype_main.tscn"')


## 验证已确认淘汰的 legacy main chain 文件已全部移除。
##
## 调用场景：代码清理回归测试。
## 主要逻辑：逐个检查已确认废弃的场景和脚本路径，只要还有任意遗留文件存在就返回失败，防止旧主链再次混入仓库。
func _test_legacy_main_chain_removed() -> bool:
	var forbidden_paths: Array[String] = [
		"res://scenes/main/main.tscn",
		"res://scripts/presentation/main_game.gd",
		"res://scripts/presentation/city_view.gd",
		"res://scripts/presentation/map_view.gd",
		"res://scripts/presentation/hud.gd",
		"res://scripts/application/game_state.gd",
		"res://scripts/application/battle_service.gd",
		"res://scripts/application/enemy_ai.gd",
		"res://scripts/application/enemy_ai_service.gd",
		"res://scripts/application/map_generator.gd",
		"res://scripts/domain/city.gd",
		"res://scripts/domain/city_state.gd",
		"res://scripts/domain/city_owner.gd",
		"res://scripts/domain/faction.gd",
		"res://scripts/domain/road.gd",
		"res://scripts/domain/battle_resolver.gd"
	]
	for forbidden_path: String in forbidden_paths:
		if ResourceLoader.exists(forbidden_path):
			return false
	return true
