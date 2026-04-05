class_name PrototypeTransferArrivalService
extends RefCounted


## 逐个结算友军运兵到达，并在每个到达士兵后立刻触发一次持续调度。
##
## 调用场景：运兵行军抵达目标城且目标城仍为同阵营时。
## 主要逻辑：每 1 名到达士兵都视为一次“新增兵力事件”；若城市未满，则先并入驻军再尝试调度；
## 若城市已满，则把这名到达士兵作为一次临时可转运兵力，优先尝试继续沿持续路线外送，只有调度失败时才记为溢出损失。
func resolve_friendly_transfer_arrival(target, moving_soldiers: int, dispatch_one_callback: Callable) -> Dictionary:
	moving_soldiers = max(0, moving_soldiers)
	var soldiers_before: int = target.soldiers
	var forwarded_count: int = 0
	var overflow_count: int = 0

	for _index in range(moving_soldiers):
		target.soldiers += 1
		var dispatched: bool = false
		if dispatch_one_callback.is_valid():
			dispatched = bool(dispatch_one_callback.call())
		if dispatched:
			forwarded_count += 1
			if target.soldiers > target.max_soldiers:
				target.soldiers = target.max_soldiers
			continue
		if target.soldiers > target.max_soldiers:
			target.soldiers = target.max_soldiers
			overflow_count += 1

	var received_count: int = max(0, target.soldiers - soldiers_before)
	var message: String = "%s 接收了 %d 名援军。" % [target.name, received_count]
	if forwarded_count > 0 and overflow_count <= 0:
		message = "%s 接收了 %d 名援军，并立即继续派出 %d 名。" % [target.name, received_count, forwarded_count]
	elif forwarded_count > 0 and overflow_count > 0:
		message = "%s 接收了 %d 名援军，继续派出 %d 名，另有 %d 名因满员溢出。" % [target.name, received_count, forwarded_count, overflow_count]
	elif overflow_count > 0:
		message = "%s 接收了 %d 名援军，另有 %d 名因满员溢出。" % [target.name, received_count, overflow_count]

	return {
		"success": true,
		"captured_by_enemy": false,
		"retook_after_loss": false,
		"received_count": received_count,
		"forwarded_count": forwarded_count,
		"overflow_count": overflow_count,
		"message": message
	}
