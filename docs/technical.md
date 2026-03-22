# 技术文档

## 当前运行入口

- 主场景：`scenes/main/prototype_main.tscn`
- 主控制脚本：`scripts/presentation/prototype_main_game.gd`
- 当前生效的是 `prototype_*` 这一套实现，旧的非 `prototype_` 文件不作为当前原型入口

## 关键模块

### 领域层

- `scripts/domain/prototype_city_owner.gd`
  - 阵营编号、颜色映射、阵营名称
- `scripts/domain/prototype_city_state.gd`
  - 城市状态、人口上限、产兵判断、邻接关系

### 应用层

- `scripts/application/prototype_map_generator.gd`
  - 地图生成、道路连通、开局势力分配、城市命名
- `scripts/application/prototype_battle_service.gd`
  - 出兵准备、到城结算、运兵失守重战、路上遭遇战、产兵、胜负判断
- `scripts/application/prototype_enemy_ai_service.gd`
  - 电脑势力的难度/风格配置、回合间隔、目标选择和出兵建议

### 表现层

- `scripts/presentation/prototype_main_game.gd`
  - 主循环、输入路由、HUD、暂停、行军单位、背景绘制、说明/结束面板
- `scripts/presentation/prototype_city_view.gd`
  - 城市图标绘制、城市标签、点击区域

## 运行时数据流

1. `prototype_main_game.gd` 在开局时调用 `prototype_map_generator.gd` 生成城市数组
2. 城市数组被复制成若干 `PrototypeCityView` 节点，负责显示和点击
3. 玩家或电脑下令后，主场景创建行军单位字典并逐帧推进
4. 路上若发生不同势力接触，调用 `PrototypeBattleService.resolve_marching_encounter()`
5. 到达目标城市后，调用 `resolve_attack_arrival()` 或 `resolve_transfer_arrival()`
6. 每秒通过 `produce_soldiers()` 推进占领城市产兵
7. 每轮推进后通过 `get_winner()` 判断是否只剩一个非中立势力

## 重要实现约束

- 核心规则尽量放在可测试的纯逻辑服务和状态对象中
- 表现层负责显示、输入与场景编排，不直接写战斗规则
- 出兵预判和真实到达结算允许不一致，因为路上可能发生产兵、增援和遭遇战
- 暂停不应改变地图状态，只停止时间推进与电脑行动
- 文档变更必须和当前生效实现同步

## 关键规则现状

- 总方数配置 = `1` 个玩家 + `N-1` 个电脑势力
- 玩家运兵允许跨图；进攻必须相邻
- 路上不同势力部队相遇会先战斗
- 失守后的迟到援军会重新与守军作战，而不是直接被收编
- 当地图上只剩一个非中立势力时结束对局

## 测试入口

- `tests/test_runner.gd`
- 推荐命令：

```bash
HOME=/tmp XDG_DATA_HOME=/tmp godot --headless --path . -s res://tests/test_runner.gd
```
