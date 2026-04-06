extends "res://scripts/presentation/prototype_main_game_layer_b.gd"

func _ready() -> void:
	_random.randomize()
	ThemeDB.fallback_font = UI_FONT
	_apply_desktop_default_landscape()
	_apply_dynamic_resolution()
	_apply_responsive_hud_layout()
	_apply_responsive_overlay_layout()
	_apply_responsive_order_dialog_layout()
	get_window().size_changed.connect(_on_window_size_changed)
	_audio_manager.setup(bgm_player, sfx_player)
	# 音频延迟到用户首次交互后再初始化（Web 平台 autoplay 限制）
	if not OS.has_feature("web"):
		_audio_manager.initialize_audio()
	_audio_manager.bgm_finished.connect(_on_bgm_finished)
	_camera_controller.setup(
		Callable(self, "_get_viewport_size"),
		Callable(self, "_is_mobile_runtime"),
		Callable(self, "_is_desktop_runtime"),
		Callable(self, "_get_top_panel_bottom")
	)
	_game_state_manager.setup(
		Callable(self, "_on_game_started"),
		Callable(self, "_on_game_over"),
		Callable(self, "_on_game_paused"),
		Callable(self, "_on_game_resumed")
	)
	_march_controller.setup(_battle_service, PrototypeCityOwnerRef)
	_input_handler.setup(
		Callable(self, "_input_is_game_over"),
		Callable(self, "_input_is_game_started"),
		Callable(self, "_input_is_manual_paused"),
		Callable(self, "_input_is_order_dialog_visible"),
		Callable(self, "_input_is_overlay_visible"),
		Callable(self, "_input_get_selected_city_id"),
		Callable(self, "_log_input_debug"),
		Callable(self, "_can_start_map_drag"),
		Callable(self, "_consume_input"),
		Callable(self, "_get_map_offset"),
		Callable(self, "_set_map_offset"),
		Callable(self, "_get_map_zoom"),
		Callable(self, "_set_map_zoom"),
		Callable(self, "_should_ignore_selection_cancel"),
		Callable(self, "_clear_selection_with_message")
	)
	_setup_ai_controls()
	_setup_continuous_status_label()
	_apply_ai_profile()
	upgrade_level_button.pressed.connect(_on_upgrade_level_button_pressed)
	upgrade_defense_button.pressed.connect(_on_upgrade_defense_button_pressed)
	upgrade_production_button.pressed.connect(_on_upgrade_production_button_pressed)
	pause_button.pressed.connect(_on_pause_button_pressed)
	restart_button.pressed.connect(_on_restart_button_pressed)
	home_button.pressed.connect(_on_home_button_pressed)
	overlay_action_button.pressed.connect(_on_overlay_action_button_pressed)
	order_dialog_layer.visible = false
	_setup_map_selection()


## 初始化地图选择逻辑并显示地图选择面板。
##
## 调用场景：主场景 `_ready()` 末尾。
## 主要逻辑：连接地图选择信号，并显示地图选择界面。
func _setup_map_selection() -> void:
	# 隐藏开始游戏 overlay，确保只显示地图选择
	overlay_layer.visible = false
	map_selection_panel.map_selected.connect(_on_map_selected)
	map_selection_panel.selection_cancelled.connect(_on_map_selection_cancelled)
	map_selection_panel.show_panel()


## 处理地图选择完成后的回调。
##
## 调用场景：地图选择面板确认选择后。
## 主要逻辑：保存选中的地图 ID，根据地图支持的方数调整玩家数量，开始新对局并直接进入游戏。
func _on_map_selected(map_id: String) -> void:
	_current_map_id = map_id
	# 根据地图支持的方数调整玩家数量
	var registry: PrototypeMapRegistry = PrototypeMapRegistryRef.get_instance()
	var map_def = registry.get_map_definition(map_id)
	if map_def != null:
		var supported_counts: Array = map_def.get_metadata().get("supported_faction_counts", [2, 3, 4, 5])
		# 如果当前玩家数量不在支持范围内，改为最大值
		if not supported_counts.has(_player_count):
			_player_count = supported_counts[-1]  # 取最大的支持方数
	_apply_ai_profile()
	_start_new_match(map_id)
	_show_play_state()


## 处理地图选择取消的回调。
##
## 调用场景：地图选择面板点击取消后。
## 主要逻辑：使用默认地图，开始新对局并直接进入游戏。
func _on_map_selection_cancelled() -> void:
	var registry: PrototypeMapRegistry = PrototypeMapRegistryRef.get_instance()
	_current_map_id = registry.get_default_map_id()
	_start_new_match(_current_map_id)
	_show_play_state()


## 响应视口尺寸变化，重新钳制地图偏移，避免横竖尺寸变动后出现可视区露空。
##
## 调用场景：窗口尺寸变化、Web 画布尺寸变化时由引擎回调。
## 主要逻辑：保持当前地图偏移尽量不变，但会重新限制到新的合法范围内，并刷新战场显示。
func _notification(what: int) -> void:
	if what != NOTIFICATION_WM_SIZE_CHANGED or not is_node_ready():
		return
	_handle_window_size_changed()


## 统一处理窗口尺寸变化时的分辨率、布局与地图尺寸刷新，避免多入口重复执行。
##
## 调用场景：`size_changed` 信号、`NOTIFICATION_WM_SIZE_CHANGED` 通知。
## 主要逻辑：同一帧只执行一次刷新链路，避免桌面拖拽窗口时重复触发导致的抖动或额外开销。
func _handle_window_size_changed() -> void:
	var current_frame: int = Engine.get_process_frames()
	if _last_window_resize_frame == current_frame:
		return
	_last_window_resize_frame = current_frame
	_apply_dynamic_resolution()
	_apply_responsive_hud_layout()
	_apply_responsive_overlay_layout()
	_apply_responsive_order_dialog_layout()
	_resize_map_world_for_viewport()
	_camera_controller.set_offset(_camera_controller.map_offset)


## 桌面端启动时默认切到窗口最大化，保留系统窗口层级但尽量扩大可视区域。
##
## 调用场景：主场景 `_ready()` 的最早阶段。
## 主要逻辑：仅在桌面平台生效，直接把窗口模式切到最大化。
func _apply_desktop_default_landscape() -> void:
	if not _is_desktop_runtime():
		return
	var window: Window = get_window()
	window.mode = Window.MODE_MAXIMIZED


## 判断当前运行是否属于桌面环境，避免把移动端/Web 强制成横屏。
##
## 调用场景：桌面横屏默认策略判断时。
## 主要逻辑：过滤掉 Web、Android、iOS 平台，剩余视为桌面运行时。
func _get_viewport_size() -> Vector2:
	return get_viewport_rect().size


## 获取顶部面板底边偏移，供 CameraController 计算开局镜头位置。
##
## 调用场景：CameraController 计算初始偏移时。
## 主要逻辑：返回顶部面板的 offset_bottom 值，用于计算安全区。
func _get_top_panel_bottom() -> float:
	return top_panel.offset_bottom


## 按当前窗口逻辑尺寸设置内容分辨率，避免高 DPI 设备把 UI 误缩小。
##
## 调用场景：主场景启动时、窗口尺寸变化时。
## 主要逻辑：Web 平台使用屏幕缩放因子换算为逻辑尺寸；其他平台保持设计尺寸，让引擎自动 upscale 到全屏。
func _apply_dynamic_resolution() -> void:
	var window: Window = get_window()
	var target_size: Vector2i = window.size
	if target_size.x <= 0 or target_size.y <= 0:
		return
	print("[DEBUG] window.size=", target_size, " content_scale_size=", window.content_scale_size)
	# Android 等平台：content_scale_size 保持设计尺寸（viewport_width/height），
	# 引擎自动 upscale 到 window.size，使画面正确放大
	if OS.has_feature("web"):
		window.content_scale_size = _to_logical_window_size(target_size)
	# else: 保持默认的 content_scale_size（= viewport_width/height）


## 将窗口像素尺寸转换为逻辑尺寸，优先修复移动端 Web 高 DPI 下字体过小问题。
##
## 调用场景：动态分辨率写入前由 `_apply_dynamic_resolution()` 调用。
## 主要逻辑：仅在“Web + 触屏设备”时读取屏幕缩放因子并反算逻辑分辨率，桌面端保持原始像素尺寸避免黑边。
func _to_logical_window_size(pixel_size: Vector2i) -> Vector2i:
	if not OS.has_feature("web"):
		return pixel_size
	if not DisplayServer.is_touchscreen_available():
		return pixel_size

	var window: Window = get_window()
	var screen_index: int = window.current_screen
	var screen_scale: float = DisplayServer.screen_get_scale(screen_index)
	if screen_scale <= 0.0:
		screen_scale = 1.0

	var logical_width: int = maxi(int(round(float(pixel_size.x) / screen_scale)), 1)
	var logical_height: int = maxi(int(round(float(pixel_size.y) / screen_scale)), 1)
	return Vector2i(logical_width, logical_height)


## 响应窗口尺寸变化，实时刷新动态分辨率配置。
##
## 调用场景：窗口拖拽、移动端旋转、Web 画布尺寸变化时由引擎信号触发。
## 主要逻辑：把最新窗口尺寸同步到内容分辨率，确保画面持续自适应。
func _on_window_size_changed() -> void:
	_handle_window_size_changed()


## 根据当前视口尺寸扩展地图世界尺寸，避免桌面拉大窗口后露出黑边。
##
## 调用场景：窗口尺寸变化时。
## 主要逻辑：按当前视口计算目标地图尺寸，只做"扩张不收缩"，保证已有城市坐标始终有效且不被裁切。
func _resize_map_world_for_viewport() -> void:
	if _cities.is_empty():
		return
	_camera_controller.apply_viewport_change()


## 按当前视口宽度调整顶部和底部 HUD，减少移动端对主战场可视空间的占用。
##
## 调用场景：主场景初始化、窗口尺寸变化、移动端旋转后。
## 主要逻辑：精简顶部栏，使用更小的尺寸和透明背景，最大化战场可视区域。
func _apply_responsive_hud_layout() -> void:
	var viewport_size: Vector2 = get_viewport_rect().size
	var is_narrow_layout: bool = viewport_size.x <= NARROW_OVERLAY_BREAKPOINT

	if is_narrow_layout:
		# 移动端：更紧凑的顶部栏
		top_panel.offset_left = 2.0
		top_panel.offset_top = 2.0
		top_panel.offset_right = -2.0
		top_panel.offset_bottom = 44.0
		top_margin.add_theme_constant_override("margin_left", 6)
		top_margin.add_theme_constant_override("margin_top", 3)
		top_margin.add_theme_constant_override("margin_right", 6)
		top_margin.add_theme_constant_override("margin_bottom", 3)
		top_info_column.add_theme_constant_override("separation", 0)
		status_label.add_theme_font_size_override("font_size", 13)
		status_label.visible = false  # 窄屏下隐藏状态标签，只保留配置信息
		hint_label.visible = false
		ai_config_label.add_theme_font_size_override("font_size", 12)
		if _continuous_status_label != null:
			_continuous_status_label.visible = false
		return

	# 桌面端：保持较小尺寸
	top_panel.offset_left = 8.0
	top_panel.offset_top = 8.0
	top_panel.offset_right = -8.0
	top_panel.offset_bottom = 72.0
	top_margin.add_theme_constant_override("margin_left", 10)
	top_margin.add_theme_constant_override("margin_top", 6)
	top_margin.add_theme_constant_override("margin_right", 10)
	top_margin.add_theme_constant_override("margin_bottom", 6)
	top_info_column.add_theme_constant_override("separation", 2)
	status_label.add_theme_font_size_override("font_size", 16)
	status_label.visible = false  # 默认隐藏状态标签
	hint_label.visible = false
	ai_config_label.add_theme_font_size_override("font_size", 14)
	if _continuous_status_label != null:
		_continuous_status_label.visible = false


## 按当前视口宽度调整底部操作栏，使用更紧凑的布局。
## 按当前视口宽度调整开局弹窗布局，避免手机上被最小宽度和双列表单挤出屏幕。
##
## 调用场景：主场景初始化、窗口尺寸变化、移动端旋转后。
## 主要逻辑：窄屏下取消固定最小宽度、缩小内边距并把设置表单切成单列；同时把说明区放进滚动容器，保证底部按钮始终可见。
func _apply_responsive_overlay_layout() -> void:
	var viewport_size: Vector2 = get_viewport_rect().size
	var is_narrow_layout: bool = viewport_size.x <= NARROW_OVERLAY_BREAKPOINT

	if is_narrow_layout:
		overlay_panel.anchor_left = 0.03
		overlay_panel.anchor_right = 0.97
		overlay_panel.anchor_top = 0.08
		overlay_panel.anchor_bottom = 0.96
		overlay_panel.custom_minimum_size = Vector2(0.0, 0.0)
		overlay_margin.add_theme_constant_override("margin_left", 16)
		overlay_margin.add_theme_constant_override("margin_top", 18)
		overlay_margin.add_theme_constant_override("margin_right", 16)
		overlay_margin.add_theme_constant_override("margin_bottom", 18)
		overlay_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
		overlay_settings_grid.columns = 1
		overlay_title_label.add_theme_font_size_override("font_size", 32)
		overlay_body_label.add_theme_font_size_override("font_size", 16)
		overlay_rule_label.add_theme_font_size_override("font_size", 15)
		overlay_rule_label_2.add_theme_font_size_override("font_size", 15)
		overlay_rule_label_3.add_theme_font_size_override("font_size", 15)
		overlay_ai_count_option.add_theme_font_size_override("font_size", 18)
		overlay_difficulty_option.add_theme_font_size_override("font_size", 18)
		overlay_style_option.add_theme_font_size_override("font_size", 18)
		overlay_action_button.add_theme_font_size_override("font_size", 22)
		return

	overlay_panel.anchor_left = 0.08
	overlay_panel.anchor_right = 0.92
	overlay_panel.anchor_top = 0.12
	overlay_panel.anchor_bottom = 0.9
	overlay_panel.custom_minimum_size = Vector2(520.0, 640.0)
	overlay_margin.add_theme_constant_override("margin_left", 28)
	overlay_margin.add_theme_constant_override("margin_top", 28)
	overlay_margin.add_theme_constant_override("margin_right", 28)
	overlay_margin.add_theme_constant_override("margin_bottom", 28)
	overlay_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	overlay_settings_grid.columns = 2
	overlay_title_label.add_theme_font_size_override("font_size", 46)
	overlay_body_label.add_theme_font_size_override("font_size", 26)
	overlay_rule_label.add_theme_font_size_override("font_size", 23)
	overlay_rule_label_2.add_theme_font_size_override("font_size", 23)
	overlay_rule_label_3.add_theme_font_size_override("font_size", 23)
	overlay_ai_count_option.add_theme_font_size_override("font_size", 24)
	overlay_difficulty_option.add_theme_font_size_override("font_size", 24)
	overlay_style_option.add_theme_font_size_override("font_size", 24)
	overlay_action_button.add_theme_font_size_override("font_size", 28)


## 按当前视口宽度调整出兵弹窗布局，避免移动端横向与纵向同时超出屏幕。
##
## 调用场景：主场景初始化、窗口尺寸变化、移动端旋转后。
## 主要逻辑：窄屏下取消固定最小宽度、收紧边距和字号，把正文区放进滚动容器，并压缩加减按钮、快捷按钮与底部操作按钮尺寸。
func _apply_responsive_order_dialog_layout() -> void:
	var viewport_size: Vector2 = get_viewport_rect().size
	var is_narrow_layout: bool = viewport_size.x <= NARROW_OVERLAY_BREAKPOINT
	var quick_buttons: Array[Button] = [
		order_dialog_plus_20_button,
		order_dialog_plus_50_button,
		order_dialog_half_button,
		order_dialog_full_button,
		order_dialog_recommend_button,
		order_dialog_keep_one_button
	]
	var adjust_buttons: Array[Button] = [
		order_dialog_minus_10_button,
		order_dialog_minus_1_button,
		order_dialog_plus_1_button,
		order_dialog_plus_10_button
	]

	if is_narrow_layout:
		order_dialog_panel.anchor_left = 0.03
		order_dialog_panel.anchor_top = 0.08
		order_dialog_panel.anchor_right = 0.97
		order_dialog_panel.anchor_bottom = 0.92
		order_dialog_panel.custom_minimum_size = Vector2(0.0, 0.0)
		order_dialog_margin.add_theme_constant_override("margin_left", 14)
		order_dialog_margin.add_theme_constant_override("margin_top", 14)
		order_dialog_margin.add_theme_constant_override("margin_right", 14)
		order_dialog_margin.add_theme_constant_override("margin_bottom", 14)
		order_dialog_column.add_theme_constant_override("separation", 12)
		order_dialog_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
		order_dialog_title_label.add_theme_font_size_override("font_size", 28)
		order_dialog_context_label.add_theme_font_size_override("font_size", 16)
		order_dialog_recommended_label.add_theme_font_size_override("font_size", 14)
		order_dialog_forecast_label.add_theme_font_size_override("font_size", 14)
		order_dialog_outcome_label.add_theme_font_size_override("font_size", 16)
		order_dialog_count_label.add_theme_font_size_override("font_size", 28)
		order_dialog_adjust_row.add_theme_constant_override("separation", 8)
		order_dialog_quick_grid.columns = 2
		order_dialog_quick_grid.add_theme_constant_override("h_separation", 10)
		order_dialog_quick_grid.add_theme_constant_override("v_separation", 10)
		order_dialog_action_row.add_theme_constant_override("separation", 6)
		for button in adjust_buttons:
			button.add_theme_font_size_override("font_size", 18)
			button.custom_minimum_size = Vector2(0.0, 42.0)
		for button in quick_buttons:
			button.add_theme_font_size_override("font_size", 18)
			button.custom_minimum_size = Vector2(0.0, 42.0)
		order_dialog_cancel_button.text = "取消"
		order_dialog_cancel_button.add_theme_font_size_override("font_size", 14)
		order_dialog_cancel_button.custom_minimum_size = Vector2(64.0, 36.0)
		order_dialog_confirm_button.text = "出兵"
		order_dialog_confirm_button.add_theme_font_size_override("font_size", 14)
		order_dialog_confirm_button.custom_minimum_size = Vector2(68.0, 36.0)
		if _order_dialog_continuous_toggle != null:
			_order_dialog_continuous_toggle.add_theme_font_size_override("font_size", 14)
		return

	order_dialog_panel.anchor_left = 0.1
	order_dialog_panel.anchor_top = 0.18
	order_dialog_panel.anchor_right = 0.9
	order_dialog_panel.anchor_bottom = 0.84
	order_dialog_panel.custom_minimum_size = Vector2(500.0, 520.0)
	order_dialog_margin.add_theme_constant_override("margin_left", 24)
	order_dialog_margin.add_theme_constant_override("margin_top", 24)
	order_dialog_margin.add_theme_constant_override("margin_right", 24)
	order_dialog_margin.add_theme_constant_override("margin_bottom", 24)
	order_dialog_column.add_theme_constant_override("separation", 16)
	order_dialog_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	order_dialog_title_label.add_theme_font_size_override("font_size", 46)
	order_dialog_context_label.add_theme_font_size_override("font_size", 26)
	order_dialog_recommended_label.add_theme_font_size_override("font_size", 17)
	order_dialog_forecast_label.add_theme_font_size_override("font_size", 17)
	order_dialog_outcome_label.add_theme_font_size_override("font_size", 26)
	order_dialog_count_label.add_theme_font_size_override("font_size", 46)
	order_dialog_adjust_row.add_theme_constant_override("separation", 14)
	order_dialog_quick_grid.columns = 3
	order_dialog_quick_grid.add_theme_constant_override("h_separation", 14)
	order_dialog_quick_grid.add_theme_constant_override("v_separation", 14)
	order_dialog_action_row.add_theme_constant_override("separation", 16)
	for button in adjust_buttons:
		button.add_theme_font_size_override("font_size", 24)
		button.custom_minimum_size = Vector2(0.0, 52.0)
	order_dialog_minus_10_button.custom_minimum_size = Vector2(110.0, 52.0)
	order_dialog_minus_1_button.custom_minimum_size = Vector2(100.0, 52.0)
	order_dialog_plus_1_button.custom_minimum_size = Vector2(100.0, 52.0)
	order_dialog_plus_10_button.custom_minimum_size = Vector2(110.0, 52.0)
	for button in quick_buttons:
		button.add_theme_font_size_override("font_size", 24)
		button.custom_minimum_size = Vector2(0.0, 52.0)
	order_dialog_cancel_button.text = "取消"
	order_dialog_cancel_button.add_theme_font_size_override("font_size", 26)
	order_dialog_cancel_button.custom_minimum_size = Vector2(180.0, 58.0)
	order_dialog_confirm_button.text = "确认出兵"
	order_dialog_confirm_button.add_theme_font_size_override("font_size", 26)
	order_dialog_confirm_button.custom_minimum_size = Vector2(220.0, 58.0)
	if _order_dialog_continuous_toggle != null:
		_order_dialog_continuous_toggle.add_theme_font_size_override("font_size", 20)


## 推进战局主循环，包括行军、产兵和敌军 AI 下单。
##
## 调用场景：每帧自动执行。
## 主要逻辑：逐帧推进所有行军单位；每秒为占领城市产兵并在每次产出时驱动持续任务；敌军按周期只注册持续任务。
func _process(delta: float) -> void:
	if _game_over or not _game_started:
		return
	if _is_gameplay_paused():
		return

	_update_marching_units(delta)
	_production_elapsed += delta
	_enemy_elapsed += delta
	_continuous_dispatch_window_elapsed += delta
	if _continuous_dispatch_window_elapsed >= 1.0:
		_continuous_dispatch_window_elapsed -= 1.0
		_continuous_dispatch_last_second_count = _continuous_dispatch_count_in_window
		_continuous_dispatch_last_second_soldiers = _continuous_dispatch_soldiers_in_window
		_continuous_dispatch_counts_by_source_last_second = _continuous_dispatch_counts_by_source_in_window.duplicate(true)
		_continuous_dispatch_count_in_window = 0
		_continuous_dispatch_soldiers_in_window = 0
		_continuous_dispatch_counts_by_source_in_window.clear()
		_refresh_continuous_status_label()

	if _production_elapsed >= 1.0:
		_production_elapsed -= 1.0
		_produce_soldiers_and_dispatch_continuous_orders()
		_refresh_view()

	var enemy_turn_interval: float = _enemy_ai_service.get_turn_interval()
	if _enemy_elapsed >= enemy_turn_interval:
		_enemy_elapsed -= enemy_turn_interval
		_run_enemy_turn()


## 绘制道路高亮和所有行军单位。
##
## 调用场景：Godot 需要重绘主场景时自动调用。
## 主要逻辑：先绘制城市间道路，再把每条行军单位渲染成一串沿路线排开的士兵；
## 规则层仍按整组人数结算，但表现层不再使用单个带数字的圆点。
func _draw() -> void:
	_background_renderer.draw_background(
		self,
		_camera_controller.map_world_size,
		_camera_controller.map_offset,
		_camera_controller.map_zoom,
		func(world_pos): return _camera_controller.world_to_screen(world_pos)
	)

	for city in _cities:
		for neighbor_id: int in city.neighbors:
			if neighbor_id < city.city_id:
				continue

			var target = _cities[neighbor_id]
			var from_position: Vector2 = _camera_controller.world_to_screen(city.position)
			var target_position: Vector2 = _camera_controller.world_to_screen(target.position)
			var line_color := Color("48576a")
			var line_width: float = max(3.0, 6.0 * _camera_controller.map_zoom)
			if city.city_id == _selected_city_id or target.city_id == _selected_city_id:
				line_color = Color("f6d365")
				line_width = max(5.0, 10.0 * _camera_controller.map_zoom)

			draw_line(from_position, target_position, line_color, line_width, true)

	# 在道路上方绘制持续出兵任务的箭头
	_draw_continuous_order_arrows()

	for unit in _marching_units:
		_draw_marching_unit_as_soldiers(unit)


## 把一条行军单位渲染成沿路径排开的多个士兵图元。
##
## 调用场景：主场景 `_draw()` 绘制行军表现时。
## 主要逻辑：每支小队的队头直接取自它当前的真实世界坐标，再按自身路线方向把同队士兵向后排开；
## 不再依赖其他小队的相对名次来反推位置，避免出现回退、穿帮或跑到源城背面的渲染错误。
func _draw_marching_unit_as_soldiers(unit: Dictionary) -> void:
	var march_direction: Vector2 = Vector2(unit.get("march_direction", Vector2.RIGHT))
	if march_direction.length_squared() <= 0.0001:
		march_direction = Vector2.RIGHT
	var lane_direction: Vector2 = Vector2(-march_direction.y, march_direction.x)
	var soldier_radius: float = max(5.0,SOLDIER_VISUAL_RADIUS * _camera_controller.map_zoom)
	var soldier_spacing: float = max(10.0,SOLDIER_VISUAL_SPACING * _camera_controller.map_zoom)
	var visible_count: int = min(int(unit["count"]), MAX_VISUAL_SOLDIERS_PER_UNIT)
	var lane_offset: float = float(unit.get("visual_lane_offset", 0.0)) * _camera_controller.map_zoom
	var front_position: Vector2 = _camera_controller.world_to_screen(_get_marching_unit_position(unit)) + lane_direction * lane_offset
	var unit_color: Color = PrototypeCityOwnerRef.get_color(int(unit["owner"]))
	var outline_width: float = max(1.0, 2.0 * _camera_controller.map_zoom)
	for soldier_index: int in range(visible_count):
		var soldier_position: Vector2 = front_position - march_direction * soldier_spacing * float(soldier_index)
		draw_circle(soldier_position, soldier_radius, unit_color)
		draw_circle(soldier_position, soldier_radius, Color.WHITE, false, outline_width)


## 返回一支新小队应使用的固定横向渲染偏移。
##
## 调用场景：创建新的行军单位时。
## 主要逻辑：按发射顺序循环分配少量左右 lane，让同路线多支小队能分开看，但每支队伍的偏移一旦创建就固定，不再依赖其他小队状态。
func _open_order_dialog(source_id: int, target_id: int, is_transfer: bool) -> void:
	var source = _cities[source_id]
	var target = _cities[target_id]
	var travel_duration: float = _calculate_march_duration(source_id, target_id)
	var max_count: int = source.soldiers
	var recommended_count: int = max_count

	if is_transfer:
		order_dialog_title_label.text = "运兵数量"
		order_dialog_recommended_label.text = "运兵可自由选择人数。`100%` 表示整队输送。"
	else:
		order_dialog_title_label.text = "进攻数量"
		recommended_count = _battle_service.get_recommended_attack_count(source, target, travel_duration)
		order_dialog_recommended_label.text = "推荐 %d 人。已计入目标防御 %d 和路上可能新增的产兵。" % [recommended_count, target.defense]

	_pending_order = {
		"source_id": source_id,
		"target_id": target_id,
		"is_transfer": is_transfer,
		"recommended_count": recommended_count
	}
	_pending_order_continuous_enabled = true
	_log_game_debug("order_dialog_opened", {
		"source_id": source_id,
		"source_name": source.name,
		"target_id": target_id,
		"target_name": target.name,
		"is_transfer": is_transfer,
		"recommended_count": recommended_count,
		"source_soldiers": source.soldiers
	})
	_pending_order_count = clamp(recommended_count, 1, max_count)
	order_dialog_context_label.text = "%s -> %s，当前可派 %d 人。点空白可取消选城。" % [source.name, target.name, max_count]
	order_dialog_layer.visible = true
	status_label.text = "出兵面板已打开，战局已暂停。确认或取消后会继续。"
	hint_label.text = "你可以慢慢调整人数，行军、产兵和电脑 AI 会暂时停止。"
	_refresh_order_dialog()
	_refresh_view()
	_audio_manager.play_sfx_by_id("select")


## 刷新出兵数量对话框里的数字和按钮状态。
##
## 调用场景：打开对话框后、点击各种快捷按钮后。
## 主要逻辑：更新中央数量显示，并根据上下限禁用不合法的加减操作。
func _on_order_cancel_button_pressed() -> void:
	order_dialog_layer.visible = false
	_pending_order.clear()
	_pending_order_continuous_enabled = false
	_log_game_debug("order_dialog_cancelled", {})
	status_label.text = "已取消本次出兵确认。你仍可以重新选择一个目标城市。"
	hint_label.text = "点己方城市可跨图运兵，点敌方或中立城市需要道路相邻。"
	_refresh_view()


## 确认当前出兵数量并正式创建行军单位。
##
## 调用场景：点击出兵弹窗中的确认按钮时。
## 主要逻辑：根据订单类型分别走运兵或进攻的下单流程，然后关闭弹窗并清空待处理订单。
func _on_restart_button_pressed() -> void:
	_start_new_match(_current_map_id)
	_show_play_state()


## 处理返回主页按钮。
##
## 调用场景：玩家点击返回主页按钮时。
## 主要逻辑：返回地图选择界面。
