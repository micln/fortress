extends "res://scripts/presentation/prototype_main_game_layer_c.gd"

func _is_desktop_runtime() -> bool:
	if OS.has_feature("web"):
		return false
	if OS.has_feature("android"):
		return false
	if OS.has_feature("ios"):
		return false
	if DisplayServer.get_name() == "headless":
		return false
	return true


## 获取当前视口尺寸，供 CameraController 使用。
##
## 调用场景：CameraController 需要视口尺寸时。
## 主要逻辑：返回当前视口的像素尺寸。
func _get_visual_lane_offset_for_launch(launch_order: int) -> float:
	var lane_pattern: Array[float] = [0.0, 1.0, -1.0, 2.0, -2.0]
	var lane_index: int = posmod(launch_order, lane_pattern.size())
	return float(lane_pattern[lane_index]) * SOLDIER_VISUAL_LANE_OFFSET


## 重置运行时状态并生成一局新地图。
##
## 调用场景：首次进入游戏、点击重新开始、胜负结束后再开一局时。
## 主要逻辑：清空旧城市节点、旧行军队列和旧持续任务状态，再通过当前地图来源构建新的城市数据和表现节点。
func _start_new_match(map_id: String = "") -> void:
	_game_over = false
	_game_started = false
	if not map_id.is_empty():
		_current_map_id = map_id
	_manual_paused = false
	_overlay_mode = "start"
	_last_winner = PrototypeCityOwnerRef.NEUTRAL
	_selected_city_id = -1
	_pending_order.clear()
	_pending_order_count = 0
	_pending_order_continuous_enabled = true
	_order_dispatch_service.clear()
	_continuous_dispatch_count_in_window = 0
	_continuous_dispatch_soldiers_in_window = 0
	_continuous_dispatch_window_elapsed = 0.0
	_continuous_dispatch_last_second_count = 0
	_continuous_dispatch_last_second_soldiers = 0
	_continuous_dispatch_counts_by_source_in_window.clear()
	_continuous_dispatch_counts_by_source_last_second.clear()
	_next_march_order = 0
	_production_elapsed = 0.0
	_enemy_elapsed = 0.0
	_clear_city_views()
	_marching_units.clear()
	order_dialog_layer.visible = false
	_apply_ai_profile()
	_input_handler.reset_gestures()
	var viewport_size: Vector2 = get_viewport_rect().size
	# 所有关卡都使用视口尺寸作为世界尺寸，城市直接填满屏幕
	var target_world_size: Vector2 = _camera_controller.get_target_map_world_size(viewport_size, true)
	_camera_controller.reset_for_new_match(target_world_size)
	_cities = _preset_map_loader.build_map({
		"player_count": _player_count,
		"ai_difficulty": _ai_difficulty,
		"ai_style": _ai_style
	}, _camera_controller.map_world_size, _random, _current_map_id)
	if _cities.is_empty():
		var error_message: String = _preset_map_loader.get_last_error_message()
		status_label.text = "地图装载失败，请检查预设地图配置。"
		hint_label.text = error_message if not error_message.is_empty() else "预设地图 loader 未返回可用城市数据。"
		push_error("预设地图装载失败：%s" % hint_label.text)
		_log_game_debug("map_load_failed", {"error_message": hint_label.text})
		_refresh_view()
		return
	# zoom=1.0，偏移为0，城市从屏幕左上角开始绘制
	_camera_controller.map_zoom = 1.0
	_camera_controller.set_offset(Vector2(0, 0))
	_spawn_city_views()
	_log_game_debug("match_started", {
		"player_count": _player_count,
		"ai_difficulty": _ai_difficulty,
		"ai_style": _ai_style,
		"city_count": _cities.size()
	})
	status_label.text = "阅读说明后点击“开始游戏”。"
	hint_label.text = "蓝色是你，其他颜色是电脑势力，灰色是中立城市不产兵；地图可拖拽浏览，桌面滚轮/手机双指可缩放。"
	_refresh_view()


## 删除旧战局遗留的城市表现节点。
##
## 调用场景：新开一局前。
## 主要逻辑：释放所有城市视图节点并清空索引字典，避免场景树中残留无效节点。
func _clear_city_views() -> void:
	for city_view in _city_views.values():
		city_view.queue_free()
	_city_views.clear()


## 为当前地图中的每座城市创建对应的表现节点。
##
## 调用场景：新地图生成后。
## 主要逻辑：复制隐藏模板节点，设置城市编号和名称，并把点击信号回接到主控制器。
func _spawn_city_views() -> void:
	for city in _cities:
		var city_view = city_template.duplicate()
		city_view.visible = true
		city_view.name = "City_%d" % city.city_id
		cities_root.add_child(city_view)
		city_view.setup(city.city_id, city.name)
		city_view.city_pressed.connect(_on_city_pressed)
		_city_views[city.city_id] = city_view
	_log_all_city_positions()


## 处理玩家点击城市后的选中、下单和取消逻辑。
##
## 调用场景：城市表现节点发出 `city_pressed` 信号时。
## 主要逻辑：第一次点击只能选中己方城市；第二次点击目标城市时，直接切换 `源 -> 目标` 持续任务；
## 若目标为敌方或中立城市则仍需道路相邻，若目标为己方城市则允许跨图运兵任务。
func _on_city_pressed(city_id: int) -> void:
	if _game_over or not _game_started or order_dialog_layer.visible:
		return

	_input_handler.arm_selection_cancel_guard(2)

	var clicked_city = _cities[city_id]
	_log_input_debug("city_pressed", {
		"city_id": city_id,
		"city_name": clicked_city.name,
		"owner": clicked_city.owner,
		"selected_before": _selected_city_id,
		"screen_position": _camera_controller.world_to_screen(clicked_city.position),
		"world_position": clicked_city.position
})

	if _selected_city_id == -1:
		if clicked_city.owner != PrototypeCityOwnerRef.PLAYER:
			status_label.text = "先点蓝色己方城市。"
			_audio_manager.play_sfx_by_id("error")
			return
		_selected_city_id = city_id
		_log_game_debug("city_selected", {
			"city_id": city_id,
			"city_name": clicked_city.name,
			"owner": clicked_city.owner,
			"soldiers": clicked_city.soldiers
		})
		status_label.text = "已选中 %s。现在点击一个目标城市，直接切换持续出兵任务。" % clicked_city.name
		hint_label.text = _build_selected_city_hint(clicked_city)
		_audio_manager.play_sfx_by_id("select")
		_refresh_view()
		return
	if _selected_city_id == city_id:
		_clear_selection_with_message("已取消选择。重新点一个蓝色城市即可。")
		return

	var source = _cities[_selected_city_id]
	if clicked_city.owner != source.owner and not source.is_neighbor(city_id):
		status_label.text = "%s 和 %s 没有道路连接，请点相邻城市。" % [source.name, clicked_city.name]
		_audio_manager.play_sfx_by_id("error")
		return

	_toggle_player_continuous_order(_selected_city_id, city_id)


## 根据城市节点类型生成一条简短的战略提示文案。
##
## 调用场景：玩家首次选中己方城市，需要在顶部提示里补充节点价值时。
## 主要逻辑：普通节点不额外提示；关口、枢纽、腹地分别返回对应的轻量策略说明，避免把规则判断写死在多个 UI 分支里。
func _get_city_node_type_hint(city) -> String:
	match String(city.node_type):
		"pass":
			return "该城是关口，防御更高，适合卡住要道。"
		"hub":
			return "该城是枢纽，产能更高，值得优先争夺。"
		"heartland":
			return "该城是腹地，初始兵力更高，适合作为后方中转。"
		_:
			return ""


## 组装玩家选中己方城市后的顶部提示文案。
##
## 调用场景：首次选中己方城市时刷新 `hint_label`。
## 主要逻辑：先输出通用操作提示，再按节点类型决定是否拼接额外战略说明，避免普通节点出现多余空格或空句子。
func _build_selected_city_hint(city) -> String:
	var base_hint: String = "点己方城市可跨图运兵，点敌方或中立城市需要道路相邻；也可以直接在底部升级。"
	var node_hint: String = _get_city_node_type_hint(city)
	if node_hint.is_empty():
		return base_hint
	return "%s %s" % [base_hint, node_hint]


## 处理玩家对一条持续出兵路线的开关操作。
##
## 调用场景：玩家先选源城市，再点击任意合法目标城市时。
## 主要逻辑：不存在的路线会被注册，已存在的同路线会被关闭；注册后保留源城选中态，方便继续设置多条路线。
func _toggle_player_continuous_order(source_id: int, target_id: int) -> void:
	var source = _cities[source_id]
	var target = _cities[target_id]
	var result: Dictionary = _order_dispatch_service.toggle_continuous_order(source_id, target_id)
	var current_mode: String = "运兵" if source.owner == target.owner else "进攻"
	_log_game_debug("player_order_toggled", {
		"source_id": source_id,
		"source_name": source.name,
		"target_id": target_id,
		"target_name": target.name,
		"action": result.get("action", ""),
		"current_mode": current_mode
	})
	if String(result.get("action", "")) == "removed":
		status_label.text = "已停止持续出兵：%s -> %s。" % [source.name, target.name]
		hint_label.text = "同一路线再次点击即可重新开启；源城还能继续配置其他目标。"
	else:
		status_label.text = "已开启持续%s：%s -> %s。该城之后每产 1 兵就会自动派 1 人。" % [current_mode, source.name, target.name]
		hint_label.text = "同一路线再次点击可关闭；一个源城有多条任务时会轮流出兵。"
	_refresh_view()


## 预留一次性出兵接口，供后续扩展时接入独立 UI。
##
## 调用场景：当前版本不会进入该逻辑，只作为未来恢复一次性出兵功能的稳定扩展点。
## 主要逻辑：暂不做任何行为，避免再次把一次性出兵混进当前持续出兵主流程。
func _issue_single_shot_order(_source_id: int, _target_id: int, _troop_count: int) -> void:
	push_warning("一次性出兵暂未接入当前原型主流程。")


## 根据玩家确认的数量执行一次运兵下单。
##
## 调用场景：出兵数量对话框确认的是友军目标城市时。
## 主要逻辑：服务层先扣除源城市对应人数，再创建运兵行军单位，等到抵达时再并入目标城市。
func _execute_transfer(source_id: int, target_id: int, moving_count: int, keep_selection: bool = false, update_status_text: bool = true) -> void:
	var source = _cities[source_id]
	var target = _cities[target_id]
	var result: Dictionary = _battle_service.prepare_transfer(source, target, moving_count)
	_log_game_debug("transfer_execute", {
		"source_id": source_id,
		"source_name": source.name,
		"target_id": target_id,
		"target_name": target.name,
		"moving_count": moving_count,
		"success": result.get("success", false),
		"source_soldiers_after": source.soldiers
	})
	if not keep_selection:
		_selected_city_id = -1
	if update_status_text:
		status_label.text = result.get("message", "")
		hint_label.text = "运兵现在会实际行军，距离越远，到达越慢。"
	if result.get("success", false):
		_launch_marching_unit(source_id, target_id, int(result["owner"]), int(result["count"]), "transfer", true)
		if update_status_text:
			_audio_manager.play_sfx_by_id("transfer")
	else:
		if update_status_text:
			_audio_manager.play_sfx_by_id("error")
	_refresh_view()


## 根据玩家或敌军确认的数量执行一次进攻下单。
##
## 调用场景：玩家确认进攻数量、敌军 AI 自动选择进攻人数时。
## 主要逻辑：服务层扣除出发城市的兵力，并创建一条进攻行军；真正战斗在抵达目标城时结算。
func _execute_attack(source_id: int, target_id: int, troop_count: int, is_player_action: bool, keep_selection: bool = false, update_status_text: bool = true) -> void:
	var source = _cities[source_id]
	var target = _cities[target_id]
	var travel_duration: float = _calculate_march_duration(source_id, target_id)

	if troop_count <= 0 or source.soldiers <= 0:
		_log_game_debug("attack_execute_skipped", {
			"source_id": source_id,
			"source_name": source.name,
			"target_id": target_id,
			"target_name": target.name,
			"troop_count": troop_count,
			"source_soldiers": source.soldiers
		})
		if update_status_text:
			status_label.text = "%s 没有士兵可以出征。" % source.name
			_audio_manager.play_sfx_by_id("error")
			_clear_selection_with_message(status_label.text)
		return

	var result: Dictionary = _battle_service.prepare_attack(source, target, travel_duration, troop_count)
	_log_game_debug("attack_execute", {
		"source_id": source_id,
		"source_name": source.name,
		"target_id": target_id,
		"target_name": target.name,
		"troop_count": troop_count,
		"is_player_action": is_player_action,
		"success": result.get("success", false),
		"travel_duration": travel_duration,
		"source_soldiers_after": source.soldiers,
		"target_owner_before": target.owner
	})
	if not keep_selection:
		_selected_city_id = -1
	if update_status_text:
		status_label.text = result.get("message", "")
	if not result.get("success", false):
		if update_status_text:
			_audio_manager.play_sfx_by_id("error")
		_refresh_view()
		return

	_launch_marching_unit(source_id, target_id, int(result["owner"]), int(result["count"]), "attack", is_player_action)
	if update_status_text:
		if not is_player_action:
			status_label.text = "%s 行动：%s" % [PrototypeCityOwnerRef.get_owner_name(source.owner), status_label.text]
			hint_label.text = "有电脑势力已经出兵，注意观察道路上的行军单位。"
		else:
			hint_label.text = "部队已经出发。你可以继续选择其他城市。"
		_audio_manager.play_sfx_by_id("attack")
	_refresh_view()


## 驱动所有存活电脑 AI 势力依次选择一条攻击命令并下单。
##
## 调用场景：电脑行动定时器达到阈值时。
## 主要逻辑：扫描当前地图上仍持有城市的全部电脑势力，让每家电脑各自独立决策并注册一条持续出兵任务；
## 若暂时没有合适路线，则退回到城市升级。
func _run_enemy_turn() -> void:
	for owner_id: int in _get_active_ai_owners():
		var decision: Dictionary = _enemy_ai_service.choose_continuous_order(_cities, _battle_service, owner_id)
		if decision.is_empty():
			var upgrade_decision: Dictionary = _enemy_ai_service.choose_upgrade(_cities, _battle_service, owner_id)
			if upgrade_decision.is_empty():
				continue
			_execute_upgrade(int(upgrade_decision["city_id"]), String(upgrade_decision["upgrade_type"]), false)
			continue

		var source_id: int = int(decision["source_id"])
		var target_id: int = int(decision["target_id"])
		var ensure_result: Dictionary = _order_dispatch_service.ensure_continuous_order(source_id, target_id)
		_log_game_debug("ai_order_ensured", {
			"owner_id": owner_id,
			"owner_name": PrototypeCityOwnerRef.get_owner_name(owner_id),
			"source_id": source_id,
			"source_name": _cities[source_id].name,
			"target_id": target_id,
			"target_name": _cities[target_id].name,
			"action": ensure_result.get("action", "")
		})
		status_label.text = "%s 已部署持续路线：%s -> %s。" % [
			PrototypeCityOwnerRef.get_owner_name(owner_id),
			_cities[source_id].name,
			_cities[target_id].name
		]
		hint_label.text = "电脑势力现在和你共用同一套持续出兵规则。"
	_refresh_view()


## 把当前城市状态和按钮状态同步到界面。
##
## 调用场景：产兵后、出兵后、行军到达后、选择变化后。
## 主要逻辑：刷新所有城市显示、高亮状态，并同步底部按钮和升级按钮是否可点击。
func _refresh_view() -> void:
	for city in _cities:
		var city_view = _city_views.get(city.city_id)
		if city_view != null:
			city_view.sync_from_state(city, city.city_id == _selected_city_id, _camera_controller.world_to_screen(city.position))
	var pause_suffix: String = " | 已暂停" if _manual_paused else ""
	if get_viewport_rect().size.x <= NARROW_OVERLAY_BREAKPOINT:
		ai_config_label.text = "%d方 | %s | %s%s" % [_player_count, _get_ai_difficulty_name(_ai_difficulty), _get_ai_style_name(_ai_style), pause_suffix]
	else:
		ai_config_label.text = "对局：%d 方 | %s | %s%s" % [_player_count, _get_ai_difficulty_name(_ai_difficulty), _get_ai_style_name(_ai_style), pause_suffix]
	pause_button.disabled = _game_over or not _game_started
	_refresh_upgrade_buttons()
	queue_redraw()


## 检查当前是否已经分出胜负。
##
## 调用场景：每次行军到达并改变城市归属后。
## 主要逻辑：读取服务层的胜负判断，若有赢家则锁定战局并显示结束面板。
func _check_game_over() -> void:
	var winner: int = _battle_service.get_winner(_cities)
	if winner == PrototypeCityOwnerRef.NEUTRAL:
		return

	_game_over = true
	_last_winner = winner
	_log_game_debug("game_over", {
		"winner": winner,
		"winner_name": PrototypeCityOwnerRef.get_owner_name(winner)
	})
	status_label.text = "%s 获胜。" % PrototypeCityOwnerRef.get_owner_name(winner)
	hint_label.text = "点击下方“重新开始”，或在面板里直接再开一局。"
	if winner == PrototypeCityOwnerRef.PLAYER:
		_audio_manager.play_sfx_by_id("victory")
	else:
		_audio_manager.play_sfx_by_id("defeat")
	_show_game_over_overlay(winner)


## 在城市归属发生变化时处理持续任务清理与日志记录。
##
## 调用场景：任意行军到达并导致城市换手后。
## 主要逻辑：来源城市一旦失守，就立刻取消它发出的全部持续任务；夺回后不会自动恢复旧任务。
func _handle_city_owner_changed(city_id: int, previous_owner: int, new_owner: int) -> void:
	var city = _cities[city_id]
	var removed_count: int = _order_dispatch_service.remove_orders_by_source(city_id)
	if _selected_city_id == city_id and city.owner != PrototypeCityOwnerRef.PLAYER:
		_selected_city_id = -1
	_log_game_debug("city_owner_changed", {
		"city_id": city_id,
		"city_name": city.name,
		"previous_owner": previous_owner,
		"new_owner": new_owner,
		"removed_order_count": removed_count
	})
	if removed_count <= 0:
		return
	_log_game_debug("orders_removed_by_source_loss", {
		"city_id": city_id,
		"city_name": city.name,
		"previous_owner": previous_owner,
		"new_owner": new_owner,
		"removed_order_count": removed_count
	})


## 清除当前源城市选择并恢复普通提示。
##
## 调用场景：玩家主动取消选择、下单完成后恢复空闲态时。
## 主要逻辑：清空选中城市并刷新道路高亮。
func _clear_selection_with_message(message: String) -> void:
	_selected_city_id = -1
	status_label.text = message
	hint_label.text = "先点蓝色城市，再点目标城市；进攻要相邻，运兵可跨图。"
	_refresh_view()


## 刷新浮动升级条的状态、成本文案和屏幕位置。
##
## 调用场景：选中变化、城市升级后、开局与重开后。
## 主要逻辑：只有选中己方城市时才在城边显示升级入口；按钮文案直接展示升级成本，
## 并把整个面板钳制在屏幕内，避免贴边城市导致按钮飞出可视区域。
func _refresh_upgrade_buttons() -> void:
	if _selected_city_id == -1 or _game_over or not _game_started or order_dialog_layer.visible or _manual_paused:
		floating_upgrade_panel.visible = false
		upgrade_level_button.disabled = true
		upgrade_defense_button.disabled = true
		upgrade_production_button.disabled = true
		upgrade_level_button.text = "升级"
		upgrade_defense_button.text = "升防"
		upgrade_production_button.text = "升产"
		return

	var city = _cities[_selected_city_id]
	if city.owner != PrototypeCityOwnerRef.PLAYER:
		floating_upgrade_panel.visible = false
		upgrade_level_button.disabled = true
		upgrade_defense_button.disabled = true
		upgrade_production_button.disabled = true
		return

	var options: Dictionary = _battle_service.get_city_upgrade_options(city)
	_apply_upgrade_button_state(upgrade_level_button, city, options[PrototypeBattleServiceRef.UPGRADE_LEVEL], "升级")
	_apply_upgrade_button_state(upgrade_defense_button, city, options[PrototypeBattleServiceRef.UPGRADE_DEFENSE], "升防")
	_apply_upgrade_button_state(upgrade_production_button, city, options[PrototypeBattleServiceRef.UPGRADE_PRODUCTION], "升产")
	_position_floating_upgrade_panel(_camera_controller.world_to_screen(city.position))
	floating_upgrade_panel.visible = true


## 根据被选城市的位置摆放浮动升级条。
##
## 调用场景：刷新升级按钮时。
## 主要逻辑：把面板放在城市右侧，使用更紧凑的尺寸。
func _position_floating_upgrade_panel(city_position: Vector2) -> void:
	var panel_size: Vector2 = floating_upgrade_panel.size
	if panel_size == Vector2.ZERO:
		panel_size = Vector2(180.0, 42.0)
	var viewport_size: Vector2 = get_viewport_rect().size
	var visible_rect := Rect2(Vector2.ZERO, viewport_size)
	if not visible_rect.grow(60.0).has_point(city_position):
		floating_upgrade_panel.visible = false
		return
	var desired_position := city_position + Vector2(45.0, -22.0)
	var clamped_x: float = clamp(desired_position.x, 10.0, viewport_size.x - panel_size.x - 10.0)
	var clamped_y: float = clamp(desired_position.y, 80.0, viewport_size.y - panel_size.y - 50.0)
	floating_upgrade_panel.position = Vector2(clamped_x, clamped_y)


## 按一条升级选项配置刷新单个按钮状态。
##
## 调用场景：升级按钮整体刷新时。
## 主要逻辑：可升级时展示“名称-成本”，已满时展示“已满”；士兵不足时保留成本但禁用按钮。
func _apply_upgrade_button_state(button: Button, city, option: Dictionary, fallback_label: String) -> void:
	var available: bool = bool(option.get("available", false))
	var cost: int = int(option.get("cost", 0))
	button.text = "%s-%d" % [fallback_label, cost] if available else "%s已满" % fallback_label
	button.disabled = not available or city.soldiers < cost


## 执行一次城市升级，并更新提示与视图。
##
## 调用场景：玩家点击底部升级按钮、AI 决定优先养城时。
## 主要逻辑：升级结算交给应用层；表现层只负责展示结果、保留当前选中和刷新 UI。
func _execute_upgrade(city_id: int, upgrade_type: String, is_player_action: bool) -> void:
	var city = _cities[city_id]
	var result: Dictionary = _battle_service.upgrade_city(city, upgrade_type)
	_log_game_debug("upgrade_execute", {
		"city_id": city_id,
		"city_name": city.name,
		"upgrade_type": upgrade_type,
		"is_player_action": is_player_action,
		"success": result.get("success", false),
		"soldiers_after": city.soldiers
	})
	status_label.text = result.get("message", "")
	if bool(result.get("success", false)):
		if is_player_action:
			hint_label.text = "升级已完成。你可以继续升城，或点目标城市发起行动。"
		else:
			hint_label.text = "%s 正在经营后方城市，准备下一轮行动。" % PrototypeCityOwnerRef.get_owner_name(city.owner)
		_audio_manager.play_sfx_by_id("capture")
	else:
		if is_player_action:
			hint_label.text = "升级会直接消耗城内士兵，升完后本城会暂时更空。"
		_audio_manager.play_sfx_by_id("error")
	_refresh_view()


## 打开玩家出兵数量对话框。
##
## 调用场景：玩家先选源城市，再点一个目标城市之后。
## 主要逻辑：根据目标归属决定当前是在运兵还是进攻，并显示推荐兵力、目标防御/产能信息、快捷按钮和确认入口。
func _refresh_order_dialog() -> void:
	if _pending_order.is_empty():
		return
	var max_count: int = _get_current_order_max_count()
	_pending_order_count = clamp(_pending_order_count, 1, max_count)
	var source = _cities[int(_pending_order["source_id"])]
	var target = _cities[int(_pending_order["target_id"])]
	order_dialog_context_label.text = "%s -> %s，当前可派 %d 人。点空白可取消选城。" % [source.name, target.name, max_count]
	order_dialog_count_label.text = str(_pending_order_count)
	order_dialog_minus_10_button.disabled = _pending_order_count <= 1
	order_dialog_minus_1_button.disabled = _pending_order_count <= 1
	order_dialog_plus_1_button.disabled = _pending_order_count >= max_count
	order_dialog_plus_10_button.disabled = _pending_order_count >= max_count
	order_dialog_plus_20_button.disabled = _pending_order_count >= max_count
	order_dialog_plus_50_button.disabled = _pending_order_count >= max_count
	order_dialog_confirm_button.disabled = _pending_order_count <= 0
	if _order_dialog_continuous_toggle != null:
		_order_dialog_continuous_toggle.button_pressed = _pending_order_continuous_enabled
		_order_dialog_continuous_toggle.text = "【开启自动出兵】源城每产 1 兵就自动派 1 人（忽略数量框）"
	_refresh_order_forecast()


## 读取当前待确认订单的实时最大可派兵力。
##
## 调用场景：出兵弹窗显示期间每次刷新、点击快捷按钮、最终确认下单前。
## 主要逻辑：直接读取源城市当前兵力，而不是沿用打开弹窗时的旧值，避免产兵期间数据过期。
func _get_current_order_max_count() -> int:
	if _pending_order.is_empty():
		return 1
	var source = _cities[int(_pending_order["source_id"])]
	return max(1, source.soldiers)


## 根据当前数量选择刷新出兵弹窗中的到达预估信息。
##
## 调用场景：打开对话框后、点击任意数量快捷按钮后。
## 主要逻辑：区分运兵和进攻两种模式，分别展示预计行军时间、目标防御/产能、预计到达守军、是否占领和出发后本城剩余兵力。
func _refresh_order_forecast() -> void:
	if _pending_order.is_empty():
		return

	var source = _cities[int(_pending_order["source_id"])]
	var target = _cities[int(_pending_order["target_id"])]
	var travel_duration: float = _calculate_march_duration(source.city_id, target.city_id)
	if bool(_pending_order["is_transfer"]):
		order_dialog_forecast_label.text = "预计 %.1f 秒后到达。出发后 %s 还剩 %d 人。" % [travel_duration, source.name, source.soldiers - _pending_order_count]
		order_dialog_outcome_label.text = "预计结果：%s 会接收 %d 名援军。若途中失守，这批援军会在到达时立刻与当前守军重新交战。" % [target.name, _pending_order_count]
		return

	var preview: Dictionary = _battle_service.preview_attack_outcome(source, target, travel_duration, _pending_order_count)
	order_dialog_forecast_label.text = "%s 预计 %.1f 秒后到达；目标防御 %d，产能 %.1f/秒，路上大约再产 %d 人，到达时等效防守约 %d。" % [
		target.name,
		travel_duration,
		int(preview["predicted_defense_bonus"]),
		target.production_rate,
		int(preview["predicted_growth"]),
		int(preview["predicted_effective_defenders"])
	]

	if bool(preview["predicted_capture"]):
		order_dialog_outcome_label.text = "预计结果：可以占领 %s，城内预计留守 %d 人；%s 出发后还剩 %d 人。" % [
			target.name,
			int(preview["predicted_remaining"]),
			source.name,
			int(preview["source_soldiers_after_departure"])
		]
	else:
		order_dialog_outcome_label.text = "预计结果：无法占领 %s，对方大约还剩 %d 人；%s 出发后还剩 %d 人。" % [
			target.name,
			int(preview["predicted_remaining"]),
			source.name,
			int(preview["source_soldiers_after_departure"])
		]


## 对当前出兵数量做增减调整。
##
## 调用场景：点击 `-10`、`+1`、`+50` 等快捷按钮时。
## 主要逻辑：把数量限定在 1 到最大可派兵力之间，再刷新弹窗显示。
func _adjust_order_count(delta: int) -> void:
	if _pending_order.is_empty():
		return
	var max_count: int = _get_current_order_max_count()
	_pending_order_count = clamp(_pending_order_count + delta, 1, max_count)
	_refresh_order_dialog()
	_audio_manager.play_sfx_by_id("select")


## 把当前出兵数量设置为总兵力的一半。
##
## 调用场景：点击 `50%` 按钮时。
## 主要逻辑：按最大可派兵力的一半向上取整，保证至少出 1 人。
func _on_order_half_button_pressed() -> void:
	if _pending_order.is_empty():
		return
	var max_count: int = _get_current_order_max_count()
	_pending_order_count = max(1, int(ceil(float(max_count) * 0.5)))
	_refresh_order_dialog()
	_audio_manager.play_sfx_by_id("select")


## 把当前出兵数量设置为全部可派兵力。
##
## 调用场景：点击 `100%` 按钮时。
## 主要逻辑：直接采用最大可派兵力，适合全军压上或整队运兵。
func _on_order_full_button_pressed() -> void:
	if _pending_order.is_empty():
		return
	_pending_order_count = _get_current_order_max_count()
	_refresh_order_dialog()
	_audio_manager.play_sfx_by_id("select")


## 把当前出兵数量设置为系统推荐值。
##
## 调用场景：点击 `推荐` 按钮时。
## 主要逻辑：恢复到打开弹窗时计算出的推荐兵力，方便快速下单。
func _on_order_recommend_button_pressed() -> void:
	if _pending_order.is_empty():
		return
	_pending_order_count = int(_pending_order["recommended_count"])
	_refresh_order_dialog()
	_audio_manager.play_sfx_by_id("select")


## 把当前出兵数量设置为“尽量多出，但源城市留 1 人”。
##
## 调用场景：点击 `留1人` 按钮时。
## 主要逻辑：如果源城兵力大于 1，则设为 `最大值 - 1`，否则仍保持最小合法值 1。
func _on_order_keep_one_button_pressed() -> void:
	if _pending_order.is_empty():
		return
	var max_count: int = _get_current_order_max_count()
	_pending_order_count = max(1, max_count - 1)
	_refresh_order_dialog()
	_audio_manager.play_sfx_by_id("select")


## 取消当前出兵数量弹窗。
##
## 调用场景：点击出兵弹窗中的取消按钮时。
## 主要逻辑：关闭弹窗但保留源城市选中，让玩家可以重新点别的目标或再次打开弹窗。
func _on_order_confirm_button_pressed() -> void:
	if _pending_order.is_empty():
		return
	var source_id: int = int(_pending_order["source_id"])
	var target_id: int = int(_pending_order["target_id"])
	var is_transfer: bool = bool(_pending_order["is_transfer"])
	var troop_count: int = _pending_order_count
	var enable_continuous_order: bool = _pending_order_continuous_enabled
	order_dialog_layer.visible = false
	_pending_order.clear()
	_pending_order_continuous_enabled = false
	_log_game_debug("order_dialog_confirmed", {
		"source_id": source_id,
		"source_name": _cities[source_id].name,
		"target_id": target_id,
		"target_name": _cities[target_id].name,
		"is_transfer": is_transfer,
		"troop_count": troop_count,
		"enable_continuous_order": enable_continuous_order
	})
	if enable_continuous_order:
		_register_continuous_order(source_id, target_id)
		status_label.text = "已注册持续出兵任务，后续仅按产兵触发自动派 1 人。"
		hint_label.text = "数量框只影响一次性出兵；持续出兵不会读取该数值。"
		_refresh_view()
	else:
		_remove_continuous_order(source_id, target_id)
		if is_transfer:
			_execute_transfer(source_id, target_id, troop_count)
		else:
			_execute_attack(source_id, target_id, troop_count, true)


## 创建一条可视化行军单位并记录其发射顺序。
##
## 调用场景：玩家或敌军正式确认一条运兵/进攻命令后。
## 主要逻辑：根据源城和目标城计算这支小队自己的方向向量、总路程与当前位置；
## 小队从源城市坐标出发，后续只沿自己的方向前进，位置不再依赖别的队伍。
func _launch_marching_unit(source_id: int, target_id: int, unit_owner: int, count: int, march_type: String, is_player_action: bool) -> void:
	var source = _cities[source_id]
	var target = _cities[target_id]
	var travel_vector: Vector2 = target.position - source.position
	var travel_distance: float = max(0.001, travel_vector.length())
	var duration: float = max(0.45, travel_distance / MARCH_SPEED)
	var march_direction: Vector2 = travel_vector / travel_distance
	var visual_lane_offset: float = _get_visual_lane_offset_for_launch(_next_march_order)

	_log_game_debug("march_launched", {
		"source_id": source_id,
		"target_id": target_id,
		"unit_owner": unit_owner,
		"count": count,
		"march_type": march_type,
		"is_player_action": is_player_action,
		"duration": duration,
		"travel_distance": travel_distance,
		"march_direction": march_direction,
		"visual_lane_offset": visual_lane_offset
	})
	_marching_units.append({
		"source_id": source_id,
		"target_id": target_id,
		"owner": unit_owner,
		"count": count,
		"type": march_type,
		"is_player_action": is_player_action,
		"launch_order": _next_march_order,
		"current_position": source.position,
		"march_direction": march_direction,
		"travel_distance": travel_distance,
		"traveled_distance": 0.0,
		"visual_lane_offset": visual_lane_offset,
		"progress": 0.0,
		"duration": duration
	})
	_next_march_order += 1


## 根据两座城市之间的距离计算一次行军持续时间。
##
## 调用场景：创建运兵或进攻行军单位前。
## 主要逻辑：使用欧式距离除以行军速度，并设置最短时长避免视觉上像瞬移。
func _calculate_march_duration(source_id: int, target_id: int) -> float:
	var source = _cities[source_id]
	var target = _cities[target_id]
	var distance: float = source.position.distance_to(target.position)
	return max(0.45, distance / MARCH_SPEED)


## 推进所有行军单位，并处理路上遭遇战与最终到达结算。
##
## 调用场景：每帧 `_process` 中。
## 主要逻辑：先根据各自方向向量更新所有行军单位的真实位置，再处理道路上不同势力部队的遭遇战，
## 最后把已到达单位按“进攻优先、发射顺序稳定”排序后逐条处理。
func _update_marching_units(delta: float) -> void:
	if _marching_units.is_empty():
		return

	for unit in _marching_units:
		var next_traveled_distance: float = min(
			float(unit["travel_distance"]),
			float(unit["traveled_distance"]) + MARCH_SPEED * delta
		)
		unit["traveled_distance"] = next_traveled_distance
		unit["progress"] = next_traveled_distance / float(unit["travel_distance"])
		unit["current_position"] = _cities[int(unit["source_id"])].position + Vector2(unit["march_direction"]) * next_traveled_distance

	_resolve_marching_collisions()

	var arrived_units: Array = []
	for unit in _marching_units:
		if float(unit["traveled_distance"]) >= float(unit["travel_distance"]) - 0.001:
			arrived_units.append(unit)

	arrived_units.sort_custom(_sort_arrived_units)

	for arrived_unit in arrived_units:
		_marching_units.erase(arrived_unit)
		_resolve_marching_unit_arrival(arrived_unit)

	queue_redraw()


## 处理道路上彼此接触的不同势力行军单位。
##
## 调用场景：每帧行军推进后、最终到达结算前。
## 主要逻辑：扫描所有不同阵营的行军单位，只要当前位置足够接近就立刻互相抵消；
## 较大兵团会减去对方人数后继续前进，若双方同归于尽则同时移除。
func _resolve_marching_collisions() -> void:
	var collision_found: bool = true
	while collision_found:
		collision_found = false
		for left_index: int in range(_marching_units.size()):
			for right_index: int in range(left_index + 1, _marching_units.size()):
				var left_unit: Dictionary = _marching_units[left_index]
				var right_unit: Dictionary = _marching_units[right_index]
				if int(left_unit["owner"]) == int(right_unit["owner"]):
					continue
				if _get_marching_unit_position(left_unit).distance_to(_get_marching_unit_position(right_unit)) > MARCH_COLLISION_DISTANCE:
					continue
				_resolve_single_marching_collision(left_index, right_index)
				collision_found = true
				break
			if collision_found:
				break


## 结算两支在道路上相遇的不同势力部队。
##
## 调用场景：检测到两支行军单位距离足够近时。
## 主要逻辑：较大兵团吞掉较小兵团并扣除相应兵力；若双方人数相同则同归于尽。
func _resolve_single_marching_collision(left_index: int, right_index: int) -> void:
	var left_unit: Dictionary = _marching_units[left_index]
	var right_unit: Dictionary = _marching_units[right_index]
	var result: Dictionary = _battle_service.resolve_marching_encounter(
		int(left_unit["owner"]),
		int(left_unit["count"]),
		int(right_unit["owner"]),
		int(right_unit["count"])
	)
	var left_owner_name: String = PrototypeCityOwnerRef.get_owner_name(int(left_unit["owner"]))
	var right_owner_name: String = PrototypeCityOwnerRef.get_owner_name(int(right_unit["owner"]))

	if result.get("both_destroyed", false):
		_log_game_debug("march_collision", {
			"left_owner": int(left_unit["owner"]),
			"right_owner": int(right_unit["owner"]),
			"left_count": int(left_unit["count"]),
			"right_count": int(right_unit["count"]),
			"both_destroyed": true
		})
		status_label.text = "%s 与 %s 在路上遭遇，双方 %d 人同归于尽。" % [left_owner_name, right_owner_name, int(left_unit["count"])]
		hint_label.text = "道路上的敌对部队会先互相抵消，剩余兵力才会继续前进。"
		_marching_units.remove_at(right_index)
		_marching_units.remove_at(left_index)
		_audio_manager.play_sfx_by_id("attack")
		return

	var winner_owner: int = int(result["winner_owner"])
	var remaining_count: int = int(result["remaining_count"])
	var surviving_unit: Dictionary = left_unit if int(left_unit["owner"]) == winner_owner else right_unit
	var surviving_index: int = left_index if int(left_unit["owner"]) == winner_owner else right_index
	surviving_unit["count"] = remaining_count
	_marching_units[surviving_index] = surviving_unit
	_log_game_debug("march_collision", {
		"left_owner": int(left_unit["owner"]),
		"right_owner": int(right_unit["owner"]),
		"left_count": int(left_unit["count"]),
		"right_count": int(right_unit["count"]),
		"both_destroyed": false,
		"winner_owner": winner_owner,
		"remaining_count": remaining_count
	})
	status_label.text = "%s 与 %s 在路上交战，%s 剩 %d 人继续前进。" % [
		left_owner_name,
		right_owner_name,
		PrototypeCityOwnerRef.get_owner_name(winner_owner),
		remaining_count
	]
	hint_label.text = "道路上的敌对部队会先互相抵消，剩余兵力才会继续前进。"
	_marching_units.remove_at(right_index if surviving_index == left_index else left_index)
	_audio_manager.play_sfx_by_id("attack")


## 对同一帧到达的行军单位做确定性排序。
##
## 调用场景：多支队伍在同一帧抵达时。
## 主要逻辑：优先处理进攻，再处理运兵；同类型时按发射顺序处理，避免结果依赖数组偶然顺序。
func _sort_arrived_units(left: Dictionary, right: Dictionary) -> bool:
	var left_attack: bool = left["type"] == "attack"
	var right_attack: bool = right["type"] == "attack"
	if left_attack != right_attack:
		return left_attack and not right_attack
	return int(left["launch_order"]) < int(right["launch_order"])


## 处理单条行军单位抵达终点后的实际结算。
##
## 调用场景：某支行军单位进度达到 100% 时。
## 主要逻辑：运兵会检查目标城是否已经失守；进攻会按抵达瞬间真实守军结算，并更新顶部提示。
func _resolve_marching_unit_arrival(unit: Dictionary) -> void:
	var target = _cities[int(unit["target_id"])]
	var owner_before_arrival: int = target.owner
	var result: Dictionary = {}

	if unit["type"] == "transfer":
		if target.owner == int(unit["owner"]):
			result = _transfer_arrival_service.resolve_friendly_transfer_arrival(
				target,
				int(unit["count"]),
				Callable(self, "_dispatch_continuous_order_for_arrival_source").bind(target.city_id)
			)
		else:
			result = _battle_service.resolve_transfer_arrival(target, int(unit["owner"]), int(unit["count"]))
		_log_game_debug("march_arrival_transfer", {
			"target_id": int(unit["target_id"]),
			"target_name": target.name,
			"owner": int(unit["owner"]),
			"count": int(unit["count"]),
			"captured": result.get("captured", false),
			"retook_after_loss": result.get("retook_after_loss", false),
			"received_count": result.get("received_count", 0),
			"forwarded_count": result.get("forwarded_count", 0),
			"overflow_count": result.get("overflow_count", 0),
			"target_owner_after": target.owner,
			"target_soldiers_after": target.soldiers
		})
		status_label.text = result.get("message", "")
		if result.get("retook_after_loss", false):
			hint_label.text = "目标城曾在途中失守，但迟到援军到达后已经按实时兵力重新交战。"
			if result.get("captured", false):
				_audio_manager.play_sfx_by_id("capture")
			else:
				_audio_manager.play_sfx_by_id("attack")
		else:
			hint_label.text = "援军已经到达。继续观察道路上的行军，或再次下达命令。"
			_audio_manager.play_sfx_by_id("transfer")
	else:
		result = _battle_service.resolve_attack_arrival(target, int(unit["owner"]), int(unit["count"]))
		_log_game_debug("march_arrival_attack", {
			"target_id": int(unit["target_id"]),
			"target_name": target.name,
			"owner": int(unit["owner"]),
			"count": int(unit["count"]),
			"captured": result.get("captured", false),
			"reinforced": result.get("reinforced", false),
			"target_owner_after": target.owner,
			"target_soldiers_after": target.soldiers
		})
		if bool(unit["is_player_action"]):
			status_label.text = result.get("message", "")
		else:
			status_label.text = "%s 到达：%s" % [PrototypeCityOwnerRef.get_owner_name(int(unit["owner"])), result.get("message", "")]

		if result.get("captured", false):
			_audio_manager.play_sfx_by_id("capture")
		elif result.get("reinforced", false):
			_audio_manager.play_sfx_by_id("transfer")
		else:
			_audio_manager.play_sfx_by_id("attack")

		if bool(unit["is_player_action"]):
			hint_label.text = "行军抵达后才会真正结算战斗。"
		else:
			hint_label.text = "有电脑势力行军已经抵达，注意下一波道路动向。"

	if owner_before_arrival != target.owner:
		_handle_city_owner_changed(target.city_id, owner_before_arrival, target.owner)
	_refresh_view()
	_check_game_over()


## 把“到达 1 名友军援兵”转换成一次指定源城的持续调度尝试。
##
## 调用场景：友军运兵逐兵到达结算时，交给 `PrototypeTransferArrivalService` 回调触发。
## 主要逻辑：复用现有持续出兵调度链，但把触发来源显式绑定到当前接收援军的城市，避免闭包捕获带来不稳定行为。
func _dispatch_continuous_order_for_arrival_source(source_id: int) -> bool:
	return _dispatch_continuous_orders_for_source(source_id)


## 绘制所有持续出兵任务道路上的流动箭头。
##
## 调用场景：主场景 `_draw()` 绘制道路后。
## 主要逻辑：在有持续出兵任务的道路上绘制指向目标城市的流动箭头，箭头颜色对应源城阵营。
func _draw_continuous_order_arrows() -> void:
	var orders: Array[Dictionary] = _order_dispatch_service.get_all_orders()
	if orders.is_empty():
		return

	var time_based_offset: float = float(Time.get_ticks_msec() % 5000) / 5000.0

	for order in orders:
		var source_id: int = int(order["source_id"])
		var target_id: int = int(order["target_id"])
		if source_id < 0 or source_id >= _cities.size() or target_id < 0 or target_id >= _cities.size():
			continue

		var source = _cities[source_id]
		var target = _cities[target_id]
		var from_position: Vector2 = _camera_controller.world_to_screen(source.position)
		var to_position: Vector2 = _camera_controller.world_to_screen(target.position)
		var direction: Vector2 = (to_position - from_position).normalized()
		var distance: float = from_position.distance_to(to_position)

		# 根据距离计算箭头数量
		var arrow_spacing: float = 80.0 * _camera_controller.map_zoom
		var arrow_count: int = max(1, int(distance / arrow_spacing))

		var owner_color: Color = PrototypeCityOwnerRef.get_color(source.owner)
		var arrow_size: float = max(6.0, 10.0 * _camera_controller.map_zoom)

		for i in range(arrow_count):
			# 流动效果：基于时间的偏移
			var t: float = (float(i) / arrow_count + time_based_offset)
			if t > 1.0:
				t -= 1.0

			var arrow_center: Vector2 = from_position + direction * distance * t
			_draw_arrow(arrow_center, direction, arrow_size, owner_color)


## 在指定位置绘制一个指向特定方向的箭头。
##
## 调用场景：`_draw_continuous_order_arrows()` 需要绘制单个箭头时。
## 主要逻辑：根据中心位置、方向和大小绘制三角形箭头。
func _draw_arrow(center: Vector2, direction: Vector2, size: float, color: Color) -> void:
	var perpendicular: Vector2 = Vector2(-direction.y, direction.x)
	var points: PackedVector2Array = PackedVector2Array([
		center + direction * size,
		center - direction * size * 0.5 + perpendicular * size * 0.5,
		center - direction * size * 0.5 - perpendicular * size * 0.5
	])
	draw_colored_polygon(points, color)


## 计算某支行军单位当前应当绘制在道路上的位置。
##
## 调用场景：主场景重绘所有行军单位时。
## 主要逻辑：直接返回这支小队当前维护的真实世界坐标；若旧数据缺失，则回退到源城坐标，避免绘制阶段崩溃。
func _get_marching_unit_position(unit: Dictionary) -> Vector2:
	if unit.has("current_position"):
		return Vector2(unit["current_position"])
	return _cities[int(unit["source_id"])].position


## 返回当前战局中的第一座玩家城市，供开局镜头定位使用。
##
## 调用场景：计算初始地图偏移、后续如需把镜头聚焦到玩家主城时。
## 主要逻辑：遍历城市数组并返回第一座归属于玩家的城市；若玩家已灭亡或地图未初始化，则返回空。
func _get_first_player_city():
	for city in _cities:
		if city.owner == PrototypeCityOwnerRef.PLAYER:
			return city
	return null


## 判断当前是否应采用移动端地图尺度策略。
##
## 调用场景：计算地图目标世界尺寸时区分移动端和桌面端参数。
## 主要逻辑：触屏且非桌面运行时视为移动端，避免在桌面触屏设备上误用手机尺度。
func _is_mobile_touch_runtime() -> bool:
	if not DisplayServer.is_touchscreen_available():
		return false
	return not _is_desktop_runtime()


## 更新地图偏移并同步所有依赖屏幕坐标的表现节点。
##
## 调用场景：地图拖拽、开局居中、窗口尺寸变化后的重新钳制。
## 主要逻辑：统一刷新城市视图、升级面板和战场重绘，避免平移后出现道路/城市/按钮错位。
func _set_map_offset(offset: Vector2) -> void:
	_camera_controller.set_offset(offset)
	if is_node_ready():
		_refresh_view()


## 按指定锚点调整地图缩放倍率，并保持锚点下的世界坐标不跳动。
##
## 调用场景：桌面滚轮缩放、移动端双指缩放。
## 主要逻辑：先记录锚点对应的旧世界坐标，再更新缩放倍率并反算偏移，最后统一走边界钳制。
func _show_start_overlay() -> void:
	_game_started = false
	_manual_paused = false
	_overlay_mode = "start"
	overlay_layer.visible = true
	_refresh_overlay_content()
	_refresh_view()


## 展示游戏结束面板。
##
## 调用场景：任一阵营达成胜利条件时。
## 主要逻辑：根据胜者切换文案和按钮文字，并保持遮罩可见防止玩家误以为对局还在继续。
func _show_game_over_overlay(winner: int) -> void:
	_overlay_mode = "game_over"
	overlay_layer.visible = true
	_manual_paused = false
	_refresh_overlay_content(winner)
	_refresh_view()


## 处理开始/重开面板主按钮。
##
## 调用场景：点击开始游戏或重新开始按钮时。
## 主要逻辑：若当前已结束则先重建地图，再关闭遮罩并恢复正常战局推进。
func _on_overlay_action_button_pressed() -> void:
	if _overlay_mode == "game_over":
		_start_new_match()
		_show_play_state()
		return
	if _overlay_mode == "pause":
		_resume_gameplay()
		return
	_show_play_state()


## 处理底部等级升级按钮。
##
## 调用场景：玩家选中己方城市后点击 `升级` 按钮时。
## 主要逻辑：把当前选中城市交给应用层做等级升级结算，表现层只负责转发。
func _on_upgrade_level_button_pressed() -> void:
	if _selected_city_id == -1:
		return
	_execute_upgrade(_selected_city_id, PrototypeBattleServiceRef.UPGRADE_LEVEL, true)


## 处理底部防御升级按钮。
##
## 调用场景：玩家选中己方城市后点击 `升防` 按钮时。
## 主要逻辑：把当前选中城市交给应用层做防御升级结算，表现层只负责转发。
func _on_upgrade_defense_button_pressed() -> void:
	if _selected_city_id == -1:
		return
	_execute_upgrade(_selected_city_id, PrototypeBattleServiceRef.UPGRADE_DEFENSE, true)


## 处理底部产能升级按钮。
##
## 调用场景：玩家选中己方城市后点击 `升产` 按钮时。
## 主要逻辑：把当前选中城市交给应用层做产能升级结算，表现层只负责转发。
func _on_upgrade_production_button_pressed() -> void:
	if _selected_city_id == -1:
		return
	_execute_upgrade(_selected_city_id, PrototypeBattleServiceRef.UPGRADE_PRODUCTION, true)


## 处理底部重新开始按钮。
##
## 调用场景：玩家在对局中途或结束后主动要求重新开局时。
## 主要逻辑：重建战局并直接进入游戏，让玩家清楚地知道已进入新的一局。
func _show_play_state() -> void:
	_game_started = true
	_manual_paused = false
	_overlay_mode = "play"
	overlay_layer.visible = false
	_log_game_debug("play_state_entered", {})
	status_label.text = "先点蓝色城市，再点目标城市，直接创建持续出兵路线。"
	hint_label.text = "同一路线再次点击可关闭；一个源城有多条路线时会轮流出兵。"
	# Web 平台在用户首次交互后初始化音频（绕过 autoplay 限制）
	_audio_manager.initialize_audio()
	_audio_manager.play_sfx_by_id("select")
	_audio_manager.play_bgm_if_needed()
	_refresh_view()


## 初始化开始/暂停面板里的 AI 难度和风格选项。
##
## 调用场景：主场景首次进入树时。
## 主要逻辑：填充难度与风格下拉项，建立与内部配置状态的双向同步。
func _setup_ai_controls() -> void:
	overlay_ai_count_option.clear()
	for item in PLAYER_COUNT_ITEMS:
		overlay_ai_count_option.add_item(String(item["name"]))
	overlay_difficulty_option.clear()
	for item in AI_DIFFICULTY_ITEMS:
		overlay_difficulty_option.add_item(String(item["name"]))
	overlay_style_option.clear()
	for item in AI_STYLE_ITEMS:
		overlay_style_option.add_item(String(item["name"]))
	overlay_ai_count_option.item_selected.connect(_on_overlay_ai_count_selected)
	overlay_difficulty_option.item_selected.connect(_on_overlay_difficulty_selected)
	overlay_style_option.item_selected.connect(_on_overlay_style_selected)
	_select_ai_option_buttons()


## 初始化出兵弹窗中的“持续出兵”开关，便于玩家在后期减少重复点击。
##
## 调用场景：主场景 `_ready()` 绑定完弹窗按钮后。
## 主要逻辑：动态创建一个 `CheckButton` 放到出兵弹窗正文区，并把状态同步到当前待确认订单。
func _register_continuous_order(source_id: int, target_id: int) -> void:
	var ensure_result: Dictionary = _order_dispatch_service.ensure_continuous_order(source_id, target_id)
	_log_game_debug("continuous_order_registered", {
		"source_id": source_id,
		"source_name": _cities[source_id].name,
		"target_id": target_id,
		"target_name": _cities[target_id].name,
		"action": ensure_result.get("action", "")
	})
	status_label.text = "已开启持续出兵：%s -> %s，源城每产 1 兵就自动派 1 人。" % [_cities[source_id].name, _cities[target_id].name]
	hint_label.text = "持续出兵不使用数量框；数量框只影响本次一次性出兵。"
	_refresh_continuous_status_label()
	_refresh_view()


## 移除一条指定路线的持续出兵任务。
##
## 调用场景：玩家对同一路线改为一次性出兵、或重新注册同一路线前去重时。
## 主要逻辑：按源城和目标路线匹配，避免目标归属变化后出现同一路线无法覆盖或关闭的问题。
func _produce_soldiers_and_dispatch_continuous_orders() -> void:
	for city in _cities:
		city.accumulate_production_progress(1.0)
		var produced_count: int = 0
		var dispatched_from_full_count: int = 0
		while city.get_ready_production_count() > 0:
			if city.can_produce():
				if not city.try_produce_one_soldier():
					break
				produced_count += 1
				_dispatch_continuous_orders_for_source(city.city_id)
				continue

			if not _order_dispatch_service.has_orders_for_source(city.city_id):
				break
			if not city.consume_one_ready_production():
				break
			dispatched_from_full_count += 1
			_dispatch_continuous_orders_for_source(city.city_id)
		if produced_count <= 0:
			if dispatched_from_full_count <= 0:
				continue
		_log_game_debug("production_tick", {
			"city_id": city.city_id,
			"city_name": city.name,
			"produced_count": produced_count,
			"dispatched_from_full_count": dispatched_from_full_count,
			"ready_production_remaining": city.get_ready_production_count(),
			"soldiers_after": city.soldiers,
			"owner": city.owner
		})


## 针对某个源城触发一次持续出兵检查。
##
## 调用场景：该源城每产生 1 个新士兵后。
## 主要逻辑：把源城交给调度服务做一次轮转选择；成功时复用现有行军执行链，失败时只记录原因。
func _dispatch_continuous_orders_for_source(source_id: int) -> bool:
	var dispatch_result: Dictionary = _order_dispatch_service.dispatch_for_source(_cities, source_id)
	if not bool(dispatch_result.get("success", false)):
		if String(dispatch_result.get("reason", "")) != "no_orders":
			var source_name: String = _cities[source_id].name if source_id >= 0 and source_id < _cities.size() else ""
			_log_game_debug("continuous_order_skipped", {
				"source_id": source_id,
				"source_name": source_name,
				"reason": dispatch_result.get("reason", ""),
				"source_soldiers": _cities[source_id].soldiers if source_id >= 0 and source_id < _cities.size() else -1,
				"has_orders": _order_dispatch_service.has_orders_for_source(source_id)
			})
		return false
	return _try_execute_continuous_order(dispatch_result)


## 尝试执行一条持续出兵任务。
##
## 调用场景：某个源城产兵后触发持续任务检查时。
## 主要逻辑：调度结果只携带“该派哪条路线”的抽象信息；这里统一转成运兵或进攻，并关闭每次出兵音效。
func _try_execute_continuous_order(dispatch_result: Dictionary) -> bool:
	var source_id: int = int(dispatch_result["source_id"])
	var target_id: int = int(dispatch_result["target_id"])
	var source = _cities[source_id]
	var target = _cities[target_id]
	var troop_count: int = int(dispatch_result.get("troop_count", 1))
	var is_transfer: bool = bool(dispatch_result.get("is_transfer", false))
	_log_game_debug("continuous_order_triggered", {
		"source_id": source_id,
		"source_name": source.name,
		"target_id": target_id,
		"target_name": target.name,
		"is_transfer": is_transfer,
		"troop_count": troop_count,
		"source_owner": source.owner,
		"target_owner": target.owner
	})
	_continuous_dispatch_count_in_window += 1
	_continuous_dispatch_soldiers_in_window += troop_count
	_continuous_dispatch_counts_by_source_in_window[source_id] = int(_continuous_dispatch_counts_by_source_in_window.get(source_id, 0)) + 1
	if is_transfer:
		_execute_transfer(source_id, target_id, troop_count, true, false)
	else:
		_execute_attack(source_id, target_id, troop_count, source.owner == PrototypeCityOwnerRef.PLAYER, true, false)
	return true


## 把当前选择的 AI 难度和风格应用到服务层。
##
## 调用场景：初始化、玩家调整选项、重新开局时。
## 主要逻辑：同步服务层配置并刷新 HUD 和面板上的文字，保证显示与实际规则一致。
func _apply_ai_profile() -> void:
	_enemy_ai_service.configure(_ai_difficulty, _ai_style)
	_select_ai_option_buttons()
	_refresh_overlay_content()
	if is_node_ready():
		_refresh_view()


## 根据当前游戏状态判断战局是否处于暂停中。
##
## 调用场景：主循环推进前。
## 主要逻辑：只要是手动暂停、出兵对话框打开或其他遮罩挡住战场，就停止行军、产兵和电脑 AI。
func _input(event: InputEvent) -> void:
	_input_handler.handle_input(event)


## 处理未被城市节点或 HUD 消费的输入事件，用于把真正的空白点击转换成取消选城。
##
## 调用场景：Godot 在 `_input()` 和节点 `_input_event()` 之后，把仍未处理的释放事件分发到这里。
## 主要逻辑：只有未被消费、且没有发生拖拽的释放事件才会进入取消逻辑；因此城市点击不会再与空白取消重复消费。
func _unhandled_input(event: InputEvent) -> void:
	_input_handler.handle_unhandled_input(event)


## 处理桌面端鼠标按下/抬起，以区分地图拖拽和普通点击。
##
## 调用场景：主场景收到鼠标左键事件时。
## 主要逻辑：按下时记录拖拽候选；抬起时若发生过拖拽则直接结束并消费，未拖拽则交给 `_unhandled_input()` 判定是否取消选城。
## 判断当前屏幕点击是否命中了任意城市。
##
## 调用场景：空白点击取消选择前的命中判定。
## 主要逻辑：直接基于城市表现节点的当前屏幕位置做命中测试，而不是回退到世界坐标手算，
## 这样地图平移、移动端缩放和文字区域扩展后，判定范围仍与玩家看到的图标位置保持一致。
func _pause_gameplay() -> void:
	if _game_over or not _game_started:
		return
	_manual_paused = true
	status_label.text = "游戏已暂停。"
	hint_label.text = "点击继续即可恢复战局。"
	_refresh_view()


## 关闭暂停面板并恢复战局推进。
##
## 调用场景：点击继续按钮时。
## 主要逻辑：隐藏遮罩并恢复主循环，让行军、产兵和 AI 从当前状态继续。
func _resume_gameplay() -> void:
	_manual_paused = false
	status_label.text = "战局已恢复。"
	hint_label.text = "继续下达命令，或再次点击暂停查看局势。"
	_refresh_view()


## 根据覆盖层模式刷新开始、暂停和结束面板的文案。
##
## 调用场景：开始新局、手动暂停、胜负结束、切换 AI 配置后。
## 主要逻辑：统一管理覆盖层的标题、正文和按钮文字，避免不同状态散落在多个函数里。
func _on_overlay_ai_count_selected(index: int) -> void:
	_player_count = int(PLAYER_COUNT_ITEMS[index]["id"])
	_apply_ai_profile()


## 处理开始/暂停面板中的难度选择变更。
##
## 调用场景：玩家切换 AI 难度下拉框时。
## 主要逻辑：记录新的难度枚举并重新应用配置，让后续敌军决策立即使用新参数。
func _on_overlay_difficulty_selected(index: int) -> void:
	_ai_difficulty = String(AI_DIFFICULTY_ITEMS[index]["id"])
	_apply_ai_profile()


## 处理开始/暂停面板中的风格选择变更。
##
## 调用场景：玩家切换 AI 风格下拉框时。
## 主要逻辑：记录新的风格枚举并重新应用配置，让敌军偏好即时切换。
func _on_overlay_style_selected(index: int) -> void:
	_ai_style = String(AI_STYLE_ITEMS[index]["id"])
	_apply_ai_profile()


## 返回当前 AI 难度的中文展示名。
##
## 调用场景：刷新 HUD 与面板说明时。
## 主要逻辑：把内部枚举映射成玩家可理解的中文名，避免界面直接暴露英文标识。
func _on_pause_button_pressed() -> void:
	if _manual_paused:
		_resume_gameplay()
		return
	_pause_gameplay()


## 背景音乐播放结束后自动续播。
##
## 调用场景：AudioStreamPlayer.finished 信号触发时。
## 主要逻辑：仅在对局处于进行状态时重播，避免菜单遮罩阶段持续响个不停。
