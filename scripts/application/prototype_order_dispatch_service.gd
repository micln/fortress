class_name PrototypeOrderDispatchService
extends RefCounted

const PrototypeCityOwnerRef = preload("res://scripts/domain/prototype_city_owner.gd")
const PrototypeMarchOrderRef = preload("res://scripts/domain/prototype_march_order.gd")

var _orders_by_source: Dictionary = {}
var _round_robin_indices: Dictionary = {}


## 清空全部持续出兵任务与轮转游标。
##
## 调用场景：新开一局、测试初始化、需要彻底重置调度器状态时。
## 主要逻辑：同时清空路线表和各源城轮转索引，避免旧战局残留影响新局。
func clear() -> void:
	_orders_by_source.clear()
	_round_robin_indices.clear()


## 切换指定路线的持续任务：不存在则创建，存在则关闭。
##
## 调用场景：玩家点击 A 再点 B、AI 下发同一路线任务时。
## 主要逻辑：每条 `source -> target` 路线保持唯一；若已存在则删除并返回关闭结果，否则创建并返回注册结果。
func toggle_continuous_order(source_id: int, target_id: int) -> Dictionary:
	if remove_order(source_id, target_id):
		return {
			"action": "removed",
			"source_id": source_id,
			"target_id": target_id
		}

	var orders: Array = _get_or_create_source_orders(source_id)
	orders.append(PrototypeMarchOrderRef.new(source_id, target_id))
	_set_source_orders(source_id, orders)
	return {
		"action": "registered",
		"source_id": source_id,
		"target_id": target_id
	}


## 用“存在则更新、不存在则创建”的方式确保一条持续任务处于启用状态。
##
## 调用场景：AI 周期性刷新战略目标时，需要幂等地下发持续任务。
## 主要逻辑：若同一路线已存在则直接报告已存在；否则追加到源城任务列表末尾，保留轮转顺序。
func ensure_continuous_order(source_id: int, target_id: int) -> Dictionary:
	var orders: Array = _get_or_create_source_orders(source_id)
	for order in orders:
		if order.matches_route(source_id, target_id):
			return {
				"action": "existing",
				"source_id": source_id,
				"target_id": target_id
			}

	orders.append(PrototypeMarchOrderRef.new(source_id, target_id))
	_set_source_orders(source_id, orders)
	return {
		"action": "registered",
		"source_id": source_id,
		"target_id": target_id
	}


## 删除一条指定路线的持续任务。
##
## 调用场景：玩家手动关闭路线、任务系统去重、来源城市失守后批量清理前的单项删除。
## 主要逻辑：只按 `source -> target` 精确匹配；删除后会修正该源城的轮转索引，避免越界。
func remove_order(source_id: int, target_id: int) -> bool:
	var orders: Array = _get_or_create_source_orders(source_id)
	var removed: bool = false
	for index: int in range(orders.size() - 1, -1, -1):
		var order = orders[index]
		if not order.matches_route(source_id, target_id):
			continue
		orders.remove_at(index)
		removed = true

	if not removed:
		return false

	_set_source_orders(source_id, orders)
	return true


## 删除某个源城发出的全部持续任务，并返回删除数量。
##
## 调用场景：源城失守时立即取消该城全部持续任务。
## 主要逻辑：直接清空该源城路线列表并移除轮转索引，确保失守后不会再参与后续任何调度。
func remove_orders_by_source(source_id: int) -> int:
	var orders: Array = _get_or_create_source_orders(source_id)
	var removed_count: int = orders.size()
	_orders_by_source.erase(source_id)
	_round_robin_indices.erase(source_id)
	return removed_count


## 返回当前所有持续任务的稳定快照。
##
## 调用场景：HUD 展示、调试日志、测试断言时。
## 主要逻辑：按源城分组遍历并平铺成数组，避免表现层直接依赖内部存储结构。
func get_all_orders() -> Array[Dictionary]:
	var snapshots: Array[Dictionary] = []
	var source_ids: Array = _orders_by_source.keys()
	source_ids.sort()
	for source_id_variant in source_ids:
		var source_id: int = int(source_id_variant)
		var orders: Array = _get_or_create_source_orders(source_id)
		for order in orders:
			snapshots.append(order.to_dictionary())
	return snapshots


## 针对某个源城执行一次“产出一个批次兵力后的持续出兵调度”。
##
## 调用场景：某城每累计到一个新增批次（默认 10 人）时。
## 主要逻辑：按该源城独立的轮转索引取出一条任务；若源城无效、无兵、无任务则返回跳过原因；
## 若命中有效任务，则返回执行描述，由表现层决定如何真正创建行军单位。
func dispatch_for_source(cities: Array, source_id: int) -> Dictionary:
	if source_id < 0 or source_id >= cities.size():
		return {"success": false, "reason": "invalid_source_id", "source_id": source_id}

	var orders: Array = _get_or_create_source_orders(source_id)
	if orders.is_empty():
		return {"success": false, "reason": "no_orders", "source_id": source_id}

	var source = cities[source_id]
	if PrototypeCityOwnerRef.is_neutral(source.owner):
		return {"success": false, "reason": "source_neutral", "source_id": source_id}
	if source.soldiers <= 0:
		return {"success": false, "reason": "source_no_soldiers", "source_id": source_id}

	var next_index: int = int(_round_robin_indices.get(source_id, 0))
	next_index = posmod(next_index, orders.size())
	var order = orders[next_index]
	_round_robin_indices[source_id] = posmod(next_index + 1, orders.size())

	if order.target_id < 0 or order.target_id >= cities.size():
		return {
			"success": false,
			"reason": "invalid_target_id",
			"source_id": source_id,
			"target_id": order.target_id
		}

	var target = cities[order.target_id]
	return {
		"success": true,
		"source_id": source_id,
		"target_id": order.target_id,
		"source_owner": source.owner,
		"target_owner": target.owner,
		"troop_count": 10,
		"is_transfer": source.owner == target.owner,
		"mode": order.mode
	}


## 返回某个源城当前持有的任务数量。
##
## 调用场景：测试断言、HUD 汇总、日志统计。
## 主要逻辑：若源城不存在任务列表则返回 0，避免外部到处判空。
func get_order_count_for_source(source_id: int) -> int:
	return _get_or_create_source_orders(source_id).size()


## 判断某个源城当前是否至少持有一条持续任务。
##
## 调用场景：表现层在决定“满兵城市是否要把本秒产能直接转成出兵触发”时。
## 主要逻辑：复用源城任务计数，避免表现层直接窥探内部任务表结构。
func has_orders_for_source(source_id: int) -> bool:
	return get_order_count_for_source(source_id) > 0


## 读取或创建一个源城对应的任务数组。
##
## 调用场景：所有任务增删查操作。
## 主要逻辑：统一把内部缺省值规范为空数组，减少外部重复判空。
func _get_or_create_source_orders(source_id: int) -> Array:
	return _orders_by_source.get(source_id, [])


## 回写某个源城的任务数组，并维护轮转索引合法性。
##
## 调用场景：任务列表发生增删变化后。
## 主要逻辑：空数组直接移除整项；非空则保存并把索引钳制到新的长度范围内。
func _set_source_orders(source_id: int, orders: Array) -> void:
	if orders.is_empty():
		_orders_by_source.erase(source_id)
		_round_robin_indices.erase(source_id)
		return

	_orders_by_source[source_id] = orders
	var next_index: int = int(_round_robin_indices.get(source_id, 0))
	_round_robin_indices[source_id] = posmod(next_index, orders.size())
