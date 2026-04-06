extends SceneTree

const PrototypeCityOwnerRef = preload("res://scripts/domain/prototype_city_owner.gd")
const PrototypeCityStateRef = preload("res://scripts/domain/prototype_city_state.gd")
const PrototypeBattleServiceRef = preload("res://scripts/application/prototype_battle_service.gd")
const PrototypeEnemyAiServiceRef = preload("res://scripts/application/prototype_enemy_ai_service.gd")
const PrototypeOrderDispatchServiceRef = preload("res://scripts/application/prototype_order_dispatch_service.gd")
const PrototypeTransferArrivalServiceRef = preload("res://scripts/application/prototype_transfer_arrival_service.gd")
const PrototypeMapGeneratorRef = preload("res://scripts/application/prototype_map_generator.gd")
const PrototypePresetMapDefinitionRef = preload("res://scripts/application/prototype_preset_map_definition.gd")
const PrototypePresetMapLoaderRef = preload("res://scripts/application/prototype_preset_map_loader.gd")

var _friendly_transfer_dispatch_test_target
var _friendly_transfer_dispatch_test_count: int = 0


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
	_run_test("attack_arrival_occupied_empty_city_without_defense_block", Callable(self, "_test_attack_arrival_occupied_empty_city_without_defense_block"), failures)
	_run_test("attack_arrival_simultaneous_multi_owner_tie_keeps_defender", Callable(self, "_test_attack_arrival_simultaneous_multi_owner_tie_keeps_defender"), failures)
	_run_test("attack_arrival_simultaneous_with_defender_reinforcement", Callable(self, "_test_attack_arrival_simultaneous_with_defender_reinforcement"), failures)
	_run_test("friendly_transfer", Callable(self, "_test_friendly_transfer"), failures)
	_run_test("friendly_transfer_overflow", Callable(self, "_test_friendly_transfer_overflow"), failures)
	_run_test("friendly_transfer_dispatches_each_arrival", Callable(self, "_test_friendly_transfer_dispatches_each_arrival"), failures)
	_run_test("friendly_transfer_to_lost_city", Callable(self, "_test_friendly_transfer_to_lost_city"), failures)
	_run_test("production", Callable(self, "_test_production"), failures)
	_run_test("production_fractional_rate", Callable(self, "_test_production_fractional_rate"), failures)
	_run_test("production_capacity", Callable(self, "_test_production_capacity"), failures)
	_run_test("production_single_step_after_capacity_reopens", Callable(self, "_test_production_single_step_after_capacity_reopens"), failures)
	_run_test("production_ready_count_when_full", Callable(self, "_test_production_ready_count_when_full"), failures)
	_run_test("production_discard_ready_keeps_fraction", Callable(self, "_test_production_discard_ready_keeps_fraction"), failures)
	_run_test("upgrade_level_success", Callable(self, "_test_upgrade_level_success"), failures)
	_run_test("upgrade_defense_insufficient", Callable(self, "_test_upgrade_defense_insufficient"), failures)
	_run_test("upgrade_production_step", Callable(self, "_test_upgrade_production_step"), failures)
	_run_test("upgrade_production_cap", Callable(self, "_test_upgrade_production_cap"), failures)
	_run_test("marching_encounter", Callable(self, "_test_marching_encounter"), failures)
	_run_test("marching_encounter_draw", Callable(self, "_test_marching_encounter_draw"), failures)
	_run_test("winner", Callable(self, "_test_winner"), failures)
	_run_test("winner_multi_ai", Callable(self, "_test_winner_multi_ai"), failures)
	_run_test("enemy_ai", Callable(self, "_test_enemy_ai"), failures)
	_run_test("enemy_ai_profile", Callable(self, "_test_enemy_ai_profile"), failures)
	_run_test("enemy_ai_aggressive_not_player_only", Callable(self, "_test_enemy_ai_aggressive_not_player_only"), failures)
	_run_test("enemy_ai_upgrade", Callable(self, "_test_enemy_ai_upgrade"), failures)
	_run_test("continuous_order_dispatch_single_route", Callable(self, "_test_continuous_order_dispatch_single_route"), failures)
	_run_test("continuous_order_dispatch_round_robin", Callable(self, "_test_continuous_order_dispatch_round_robin"), failures)
	_run_test("continuous_order_target_owner_change_keeps_route", Callable(self, "_test_continuous_order_target_owner_change_keeps_route"), failures)
	_run_test("continuous_order_remove_by_source", Callable(self, "_test_continuous_order_remove_by_source"), failures)
	_run_test("continuous_order_full_city_can_dispatch_multiple_ready_production", Callable(self, "_test_continuous_order_full_city_can_dispatch_multiple_ready_production"), failures)
	_run_test("map_multi_ai_spawn", Callable(self, "_test_map_multi_ai_spawn"), failures)
	_run_test("map_connectivity", Callable(self, "_test_map_connectivity"), failures)
	_run_test("preset_map_loader_builds_cities", Callable(self, "_test_preset_map_loader_builds_cities"), failures)
	_run_test("preset_map_spawn_sets_cover_supported_faction_counts", Callable(self, "_test_preset_map_spawn_sets_cover_supported_faction_counts"), failures)
	_run_test("preset_map_is_connected", Callable(self, "_test_preset_map_is_connected"), failures)
	_run_test("preset_map_neighbors_are_symmetric_and_valid", Callable(self, "_test_preset_map_neighbors_are_symmetric_and_valid"), failures)
	_run_test("preset_map_positions_stay_in_world_bounds_and_do_not_overlap", Callable(self, "_test_preset_map_positions_stay_in_world_bounds_and_do_not_overlap"), failures)
	_run_test("preset_map_still_builds_on_smaller_world_size", Callable(self, "_test_preset_map_still_builds_on_smaller_world_size"), failures)
	_run_test("preset_map_loader_reports_validation_error", Callable(self, "_test_preset_map_loader_reports_validation_error"), failures)
	_run_test("preset_map_assigns_strategic_node_types", Callable(self, "_test_preset_map_assigns_strategic_node_types"), failures)
	_run_test("strategic_pass_increases_defense", Callable(self, "_test_strategic_pass_increases_defense"), failures)
	_run_test("strategic_hub_increases_production", Callable(self, "_test_strategic_hub_increases_production"), failures)
	_run_test("strategic_heartland_increases_initial_soldiers", Callable(self, "_test_strategic_heartland_increases_initial_soldiers"), failures)
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


## 验证已占领但守军为 0 的空城，不会因为防御值导致“有兵到达却无法占领”。
##
## 调用场景：持续出兵高频小股进攻时的规则回归测试。
## 主要逻辑：构造一座归属敌方但守军为 0、防御为 3 的空城，检查 1 人到达即可占领。
func _test_attack_arrival_occupied_empty_city_without_defense_block() -> bool:
	var battle_service = PrototypeBattleServiceRef.new()
	var target = PrototypeCityStateRef.new(1, "B", Vector2.RIGHT, PrototypeCityOwnerRef.AI_OWNER_START, 1, 20, 0, [0], 3, 1.0)
	var result: Dictionary = battle_service.resolve_attack_arrival(target, PrototypeCityOwnerRef.PLAYER, 1)
	return result.get("captured", false) and target.owner == PrototypeCityOwnerRef.PLAYER and target.soldiers == 1


## 验证同一帧多方进攻同时抵达中立城时，会先做攻方互耗，避免先后顺序决定结果。
##
## 调用场景：多势力持续出兵同时冲向中立城的回归测试。
## 主要逻辑：构造双方各 6 人同帧到达 4 人中立城，检查攻方先同归于尽，中立城守军与归属保持不变。
func _test_attack_arrival_simultaneous_multi_owner_tie_keeps_defender() -> bool:
	var battle_service = PrototypeBattleServiceRef.new()
	var target = PrototypeCityStateRef.new(1, "B", Vector2.RIGHT, PrototypeCityOwnerRef.NEUTRAL, 1, 20, 4, [0], 1, 1.0)
	var result: Dictionary = battle_service.resolve_simultaneous_attack_arrivals(target, {
		PrototypeCityOwnerRef.PLAYER: 6,
		PrototypeCityOwnerRef.AI_OWNER_START: 6
	})
	return bool(result.get("attackers_cancelled", false)) \
		and target.owner == PrototypeCityOwnerRef.NEUTRAL \
		and target.soldiers == 4


## 验证守方同帧增援会先并入守军，再和同帧进攻一起一次性结算。
##
## 调用场景：守城方先升级/调兵后，敌军多路同帧到达的回归测试。
## 主要逻辑：构造守方 14 人、防御 2、同帧先收到 8 人增援再被 20 人进攻，检查城市不被攻下且只剩 2 人。
func _test_attack_arrival_simultaneous_with_defender_reinforcement() -> bool:
	var battle_service = PrototypeBattleServiceRef.new()
	var target = PrototypeCityStateRef.new(1, "B", Vector2.RIGHT, PrototypeCityOwnerRef.PLAYER, 3, 55, 14, [0], 2, 1.0)
	var result: Dictionary = battle_service.resolve_simultaneous_attack_arrivals(target, {
		PrototypeCityOwnerRef.PLAYER: 8,
		PrototypeCityOwnerRef.AI_OWNER_START: 20
	})
	return not bool(result.get("captured", false)) \
		and target.owner == PrototypeCityOwnerRef.PLAYER \
		and target.soldiers == 2


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


## 验证友军运兵到满员城市时，会返回溢出人数用于后续持续任务接力，而不是静默吞兵。
##
## 调用场景：中继城市满员但仍挂有对外持续任务时的规则回归测试。
## 主要逻辑：构造目标城只剩 1 格容量却到达 3 人援军，检查实际接收 1 人、溢出 2 人并保留在返回结果中。
func _test_friendly_transfer_overflow() -> bool:
	var battle_service = PrototypeBattleServiceRef.new()
	var target = PrototypeCityStateRef.new(1, "B", Vector2.RIGHT, PrototypeCityOwnerRef.PLAYER, 1, 20, 19, [0])
	var arrival_result: Dictionary = battle_service.resolve_transfer_arrival(target, PrototypeCityOwnerRef.PLAYER, 3)
	return bool(arrival_result.get("success", false)) \
		and int(arrival_result.get("received_count", -1)) == 1 \
		and int(arrival_result.get("overflow_count", -1)) == 2 \
		and target.soldiers == 20


## 验证友军运兵到达会把每一名新增士兵都视为一次调度触发，而不是只在最终溢出时补派。
##
## 调用场景：`a -> b -> c` 中继链里，目标城既可能已满也可能持续收到外部援军时。
## 主要逻辑：构造一座已满员的中继城，对它连续运入 2 人，并在每次到达后都立刻把 1 人继续派出；
## 最终应保持中继城仍满员，同时统计到 2 次继续派发、0 次溢出损失。
func _test_friendly_transfer_dispatches_each_arrival() -> bool:
	var transfer_arrival_service = PrototypeTransferArrivalServiceRef.new()
	var target = PrototypeCityStateRef.new(1, "B", Vector2.RIGHT, PrototypeCityOwnerRef.PLAYER, 1, 20, 20, [0, 2])
	_friendly_transfer_dispatch_test_target = target
	_friendly_transfer_dispatch_test_count = 0
	var arrival_result: Dictionary = transfer_arrival_service.resolve_friendly_transfer_arrival(
		target,
		2,
		Callable(self, "_dispatch_friendly_transfer_test_soldier")
	)
	_friendly_transfer_dispatch_test_target = null
	return bool(arrival_result.get("success", false)) \
		and int(arrival_result.get("received_count", -1)) == 0 \
		and int(arrival_result.get("forwarded_count", -1)) == 2 \
		and int(arrival_result.get("overflow_count", -1)) == 0 \
		and _friendly_transfer_dispatch_test_count == 2 \
		and target.soldiers == 20


## 为友军运兵逐兵调度测试提供一个可重复调用的显式回调。
##
## 调用场景：`_test_friendly_transfer_dispatches_each_arrival()` 把它传给运兵到达服务，模拟“到 1 人就继续派出 1 人”。
## 主要逻辑：若测试目标城当前还有兵，就移除 1 人并累计一次派发次数；否则返回失败，模拟无法继续下发。
func _dispatch_friendly_transfer_test_soldier() -> bool:
	if _friendly_transfer_dispatch_test_target == null:
		return false
	if _friendly_transfer_dispatch_test_target.soldiers <= 0:
		return false
	_friendly_transfer_dispatch_test_target.remove_soldiers(1)
	_friendly_transfer_dispatch_test_count += 1
	return true


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


## 验证城市在同一秒内若因持续出兵腾出容量，可以继续把剩余产能兑换成更多士兵。
##
## 调用场景：高产能城市持续运兵/进攻时的时序回归测试。
## 主要逻辑：先累计 2.1 的产能，再单步产 1 人、移走 1 人、继续尝试产兵，检查这一秒内总共能产出 2 人而不是只产 1 人。
func _test_production_single_step_after_capacity_reopens() -> bool:
	var city = PrototypeCityStateRef.new(0, "长安", Vector2.ZERO, PrototypeCityOwnerRef.PLAYER, 2, 35, 34, [1], 3, 2.1)
	city.accumulate_production_progress(1.0)
	var first_produced: bool = city.try_produce_one_soldier()
	city.remove_soldiers(1)
	var second_produced: bool = city.try_produce_one_soldier()
	return first_produced and second_produced and city.soldiers == 35


## 验证城市即使已满员，也会保留并暴露本秒已累计完成的产兵次数，供持续出兵系统消费。
##
## 调用场景：满兵城市挂持续任务时的规则回归测试。
## 主要逻辑：构造一座满员且产能为 3.0 的城市，累计 1 秒产能后检查可消费次数为 3；
## 再手动消费 1 次，检查剩余可消费次数会同步减少。
func _test_production_ready_count_when_full() -> bool:
	var city = PrototypeCityStateRef.new(0, "长安", Vector2.ZERO, PrototypeCityOwnerRef.PLAYER, 2, 35, 35, [1], 3, 3.0)
	city.accumulate_production_progress(1.0)
	var ready_before_consume: int = city.get_ready_production_count()
	var consumed: bool = city.consume_one_ready_production()
	var ready_after_consume: int = city.get_ready_production_count()
	return ready_before_consume == 3 and consumed and ready_after_consume == 2


## 验证丢弃整数产能积压时会保留小数进度，避免后续容量恢复后一次性爆发。
##
## 调用场景：满员且无持续任务时的积压清理回归测试。
## 主要逻辑：先累计 3.2 的产能进度，再丢弃整数部分并补 1 秒产能，检查只会产生 1 次就绪产兵而不是 4 次。
func _test_production_discard_ready_keeps_fraction() -> bool:
	var city = PrototypeCityStateRef.new(0, "长安", Vector2.ZERO, PrototypeCityOwnerRef.PLAYER, 2, 35, 35, [1], 2, 1.0)
	city.accumulate_production_progress(3.2)
	var dropped_count: int = city.discard_ready_production()
	city.accumulate_production_progress(1.0)
	var ready_after_next_second: int = city.get_ready_production_count()
	return dropped_count == 3 and ready_after_next_second == 1


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


## 验证每次产能升级都会带来明显的产兵速度提升。
##
## 调用场景：城市升级系统回归测试。
## 主要逻辑：构造一座可升产的城市，检查一次升级后产能会从 1.0 提升到 1.4，而不是只有很小的 0.1/0.2 增幅。
func _test_upgrade_production_step() -> bool:
	var battle_service = PrototypeBattleServiceRef.new()
	var city = PrototypeCityStateRef.new(0, "A", Vector2.ZERO, PrototypeCityOwnerRef.PLAYER, 2, 35, 20, [1], 2, 1.0)
	var result: Dictionary = battle_service.upgrade_city(city, PrototypeBattleServiceRef.UPGRADE_PRODUCTION)
	return bool(result.get("success", false)) and is_equal_approx(city.production_rate, 1.4)


## 验证产能达到上限后不能继续升级。
##
## 调用场景：城市升级系统回归测试。
## 主要逻辑：构造一座产能已满的城市，检查升级失败且产能保持不变。
func _test_upgrade_production_cap() -> bool:
	var battle_service = PrototypeBattleServiceRef.new()
	var city = PrototypeCityStateRef.new(0, "A", Vector2.ZERO, PrototypeCityOwnerRef.PLAYER, 3, 55, 40, [1], 2, 3.0)
	var result: Dictionary = battle_service.upgrade_city(city, PrototypeBattleServiceRef.UPGRADE_PRODUCTION)
	return not bool(result.get("success", true)) and is_equal_approx(city.production_rate, 3.0)


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


## 验证单条持续出兵路线在源城每次产兵后都会稳定返回一次派兵描述。
##
## 调用场景：持续出兵调度服务回归测试。
## 主要逻辑：创建一条 `A -> B` 路线，检查调度结果会固定派出 1 人，并根据目标归属返回进攻模式。
func _test_continuous_order_dispatch_single_route() -> bool:
	var service = PrototypeOrderDispatchServiceRef.new()
	var cities: Array = [
		PrototypeCityStateRef.new(0, "A", Vector2.ZERO, PrototypeCityOwnerRef.PLAYER, 2, 35, 5, [1]),
		PrototypeCityStateRef.new(1, "B", Vector2.RIGHT, PrototypeCityOwnerRef.AI_OWNER_START, 1, 20, 3, [0])
	]
	service.ensure_continuous_order(0, 1)
	var result: Dictionary = service.dispatch_for_source(cities, 0)
	return bool(result.get("success", false)) \
		and int(result.get("source_id", -1)) == 0 \
		and int(result.get("target_id", -1)) == 1 \
		and int(result.get("troop_count", 0)) == 1 \
		and not bool(result.get("is_transfer", true))


## 验证同一源城存在多条持续路线时，会按轮转顺序交替触发。
##
## 调用场景：持续出兵调度服务回归测试。
## 主要逻辑：给同一源城注册两个目标，连续调度两次，检查目标编号会轮流切换而不是总打第一条。
func _test_continuous_order_dispatch_round_robin() -> bool:
	var service = PrototypeOrderDispatchServiceRef.new()
	var cities: Array = [
		PrototypeCityStateRef.new(0, "A", Vector2.ZERO, PrototypeCityOwnerRef.PLAYER, 2, 35, 6, [1, 2]),
		PrototypeCityStateRef.new(1, "B", Vector2.RIGHT, PrototypeCityOwnerRef.AI_OWNER_START, 1, 20, 3, [0]),
		PrototypeCityStateRef.new(2, "C", Vector2.DOWN, PrototypeCityOwnerRef.PLAYER, 1, 20, 2, [0])
	]
	service.ensure_continuous_order(0, 1)
	service.ensure_continuous_order(0, 2)
	var first_result: Dictionary = service.dispatch_for_source(cities, 0)
	var second_result: Dictionary = service.dispatch_for_source(cities, 0)
	return bool(first_result.get("success", false)) \
		and bool(second_result.get("success", false)) \
		and int(first_result.get("target_id", -1)) == 1 \
		and int(second_result.get("target_id", -1)) == 2


## 验证目标城市归属变化后，持续路线不会丢失，只会动态切换运兵/进攻模式。
##
## 调用场景：持续出兵调度服务回归测试。
## 主要逻辑：先让目标是敌城，再改成己方城，检查同一条路线仍然存在，且调度结果从进攻切成运兵。
func _test_continuous_order_target_owner_change_keeps_route() -> bool:
	var service = PrototypeOrderDispatchServiceRef.new()
	var cities: Array = [
		PrototypeCityStateRef.new(0, "A", Vector2.ZERO, PrototypeCityOwnerRef.PLAYER, 2, 35, 6, [1]),
		PrototypeCityStateRef.new(1, "B", Vector2.RIGHT, PrototypeCityOwnerRef.AI_OWNER_START, 1, 20, 3, [0])
	]
	service.ensure_continuous_order(0, 1)
	var first_result: Dictionary = service.dispatch_for_source(cities, 0)
	cities[1].owner = PrototypeCityOwnerRef.PLAYER
	var second_result: Dictionary = service.dispatch_for_source(cities, 0)
	return service.get_order_count_for_source(0) == 1 \
		and not bool(first_result.get("is_transfer", true)) \
		and bool(second_result.get("is_transfer", false))


## 验证源城失守时可以一次性删除该源城发出的全部持续任务。
##
## 调用场景：城市换手后的持续任务清理回归测试。
## 主要逻辑：给同一源城注册多条路线，模拟失守后调用按源城删除，检查任务数清零且返回删除数量正确。
func _test_continuous_order_remove_by_source() -> bool:
	var service = PrototypeOrderDispatchServiceRef.new()
	service.ensure_continuous_order(0, 1)
	service.ensure_continuous_order(0, 2)
	service.ensure_continuous_order(1, 0)
	var removed_count: int = service.remove_orders_by_source(0)
	return removed_count == 2 \
		and service.get_order_count_for_source(0) == 0 \
		and service.get_order_count_for_source(1) == 1


## 验证满兵城市在同一秒内累积出的多次产兵机会，可以被持续任务完整转成多次出兵触发。
##
## 调用场景：高产能满兵城市持续运兵/进攻时的主流程回归测试。
## 主要逻辑：构造一座满员且产能为 3.0 的城市，累计 1 秒产能后，模拟“消费 1 次产兵机会 -> 调度 1 次 -> 源城扣 1 人”三次，
## 检查能够连续触发 3 次，而不是只触发 1 次后把剩余机会丢掉。
func _test_continuous_order_full_city_can_dispatch_multiple_ready_production() -> bool:
	var service = PrototypeOrderDispatchServiceRef.new()
	var cities: Array = [
		PrototypeCityStateRef.new(0, "长安", Vector2.ZERO, PrototypeCityOwnerRef.PLAYER, 2, 35, 35, [1], 3, 3.0),
		PrototypeCityStateRef.new(1, "洛阳", Vector2.RIGHT, PrototypeCityOwnerRef.PLAYER, 2, 35, 10, [0], 2, 1.0)
	]
	service.ensure_continuous_order(0, 1)
	cities[0].accumulate_production_progress(1.0)
	var dispatch_count: int = 0
	while cities[0].get_ready_production_count() > 0:
		if not cities[0].consume_one_ready_production():
			return false
		var dispatch_result: Dictionary = service.dispatch_for_source(cities, 0)
		if not bool(dispatch_result.get("success", false)):
			return false
		dispatch_count += 1
		cities[0].remove_soldiers(1)
	return dispatch_count == 3 and cities[0].soldiers == 32


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


## 验证预设地图生成出的邻接关系既合法又保持双向对称。
##
## 调用场景：预设地图结构完整性回归测试。
## 主要逻辑：读取运行时城市数组后，检查每条邻接边都指向存在城市，且 A 连到 B 时 B 也必须连回 A。
func _test_preset_map_neighbors_are_symmetric_and_valid() -> bool:
	var loader = PrototypePresetMapLoaderRef.new()
	var random := RandomNumberGenerator.new()
	random.seed = 7
	var cities: Array = loader.build_map({
		"player_count": 5
	}, Vector2(1400.0, 2400.0), random)
	if cities.is_empty():
		return false

	var city_ids: Dictionary = {}
	for city in cities:
		city_ids[city.city_id] = city

	for city in cities:
		for neighbor_id: int in city.neighbors:
			if not city_ids.has(neighbor_id):
				return false
			var neighbor = city_ids[neighbor_id]
			if not neighbor.neighbors.has(city.city_id):
				return false
	return true


## 验证 design canvas 映射后的城市坐标不会越界，也不会出现严重重叠。
##
## 调用场景：预设地图坐标契约回归测试。
## 主要逻辑：在常见运行时世界尺寸下构建地图，检查所有城市都落在世界边界内，
## 且任意两城的直线距离都高于最小阈值，避免标签和点击区域大面积重叠。
func _test_preset_map_positions_stay_in_world_bounds_and_do_not_overlap() -> bool:
	var loader = PrototypePresetMapLoaderRef.new()
	var random := RandomNumberGenerator.new()
	random.seed = 11
	var world_size := Vector2(1400.0, 2400.0)
	var cities: Array = loader.build_map({
		"player_count": 5
	}, world_size, random)
	if cities.is_empty():
		return false

	for city in cities:
		if city.position.x < 0.0 or city.position.y < 0.0:
			return false
		if city.position.x > world_size.x or city.position.y > world_size.y:
			return false

	for index: int in range(cities.size()):
		for other_index: int in range(index + 1, cities.size()):
			if cities[index].position.distance_to(cities[other_index].position) < 110.0:
				return false
	return true


## 验证同一张预设图在较小运行时世界尺寸下仍能成功装载。
##
## 调用场景：预设地图缩放兼容性回归测试。
## 主要逻辑：把地图装配到明显小于默认值的世界尺寸，确认 loader 不会因为写死绝对距离阈值而误判模板非法。
func _test_preset_map_still_builds_on_smaller_world_size() -> bool:
	var loader = PrototypePresetMapLoaderRef.new()
	var random := RandomNumberGenerator.new()
	random.seed = 19
	var cities: Array = loader.build_map({
		"player_count": 5
	}, Vector2(500.0, 900.0), random)
	return not cities.is_empty()


## 验证预设地图 loader 在配置非法时会显式暴露错误，而不是只返回空数组。
##
## 调用场景：预设地图错误处理回归测试。
## 主要逻辑：传入不受支持的总方数，检查构建失败后除了返回空数组，还能读取明确错误信息。
func _test_preset_map_loader_reports_validation_error() -> bool:
	var loader = PrototypePresetMapLoaderRef.new()
	var random := RandomNumberGenerator.new()
	random.seed = 23
	var cities: Array = loader.build_map({
		"player_count": 6
	}, Vector2(1400.0, 2400.0), random)
	return cities.is_empty() and not String(loader.get_last_error_message()).is_empty()


## 验证首张预设图已经给关键城市打上战略节点类型。
##
## 调用场景：Strategic Node Phase 2 结构回归测试。
## 主要逻辑：直接读取预设图静态定义，确认至少存在一座关口、枢纽和腹地节点，避免标签设计只写在文档里未真正落地到数据层。
func _test_preset_map_assigns_strategic_node_types() -> bool:
	var definition = PrototypePresetMapDefinitionRef.new()
	var city_definitions: Array[Dictionary] = definition.get_city_definitions()
	var node_types: Dictionary = {}
	for city_definition: Dictionary in city_definitions:
		var node_type: String = String(city_definition.get("node_type", ""))
		if not node_type.is_empty():
			node_types[node_type] = true
	return node_types.has("pass") and node_types.has("hub") and node_types.has("heartland")


## 验证关口节点在运行时会获得额外防御加成。
##
## 调用场景：Strategic Node Phase 2 数值效果回归测试。
## 主要逻辑：对比模板定义与 loader 产出的同名城市，确认标记为关口的城市运行时防御值高于模板基础值。
func _test_strategic_pass_increases_defense() -> bool:
	var definition = PrototypePresetMapDefinitionRef.new()
	var city_definition: Dictionary = _find_city_definition_by_name(definition.get_city_definitions(), "长安")
	if String(city_definition.get("node_type", "")) != "pass":
		return false
	var city = _build_city_by_name("长安")
	return city != null and city.defense > int(city_definition.get("defense", 0))


## 验证枢纽节点在运行时会获得额外产能加成。
##
## 调用场景：Strategic Node Phase 2 数值效果回归测试。
## 主要逻辑：对比模板定义与 loader 产出的同名城市，确认标记为枢纽的城市运行时产能高于模板基础值。
func _test_strategic_hub_increases_production() -> bool:
	var definition = PrototypePresetMapDefinitionRef.new()
	var city_definition: Dictionary = _find_city_definition_by_name(definition.get_city_definitions(), "洛阳")
	if String(city_definition.get("node_type", "")) != "hub":
		return false
	var city = _build_city_by_name("洛阳")
	return city != null and city.production_rate > float(city_definition.get("production_rate", 0.0))


## 验证腹地节点在运行时会获得额外初始兵力加成。
##
## 调用场景：Strategic Node Phase 2 数值效果回归测试。
## 主要逻辑：对比模板定义与 loader 产出的同名城市，确认标记为腹地的城市运行时初始兵力高于模板基础值。
func _test_strategic_heartland_increases_initial_soldiers() -> bool:
	var definition = PrototypePresetMapDefinitionRef.new()
	var city_definition: Dictionary = _find_city_definition_by_name(definition.get_city_definitions(), "成都")
	if String(city_definition.get("node_type", "")) != "heartland":
		return false
	var city = _build_city_by_name("成都")
	return city != null and city.soldiers > int(city_definition.get("initial_soldiers", 0))


## 按城市名在静态定义列表里查找对应定义。
##
## 调用场景：预设地图相关测试需要读取模板基础数值时。
## 主要逻辑：线性遍历城市定义，找到名称匹配的那一项后返回；若未找到则返回空字典供调用方判空。
func _find_city_definition_by_name(city_definitions: Array[Dictionary], city_name: String) -> Dictionary:
	for city_definition: Dictionary in city_definitions:
		if String(city_definition.get("name", "")) == city_name:
			return city_definition
	return {}


## 构建一局默认预设地图并返回指定名称的运行时城市状态。
##
## 调用场景：战略节点测试需要对比静态模板与运行时装配结果时。
## 主要逻辑：调用真实 loader 生成城市数组，再按城市名定位目标，避免测试直接依赖私有装配细节。
func _build_city_by_name(city_name: String) -> Variant:
	var loader = PrototypePresetMapLoaderRef.new()
	var random := RandomNumberGenerator.new()
	random.seed = 31
	var cities: Array = loader.build_map({
		"player_count": 5
	}, Vector2(1400.0, 2400.0), random)
	for city in cities:
		if city.name == city_name:
			return city
	return null


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
