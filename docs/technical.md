# 技术文档

## 当前运行入口

- 主场景：`scenes/main/prototype_main.tscn`
- 主控制脚本：`scripts/presentation/prototype_main_game.gd`
- 当前生效的是 `prototype_*` 这一套实现，旧的非 `prototype_` 文件不作为当前原型入口

## Web 导出与发布

- Web 发布使用 `export_presets.cfg` 中的 `Web` preset，导出目标为 `build/web/index.html`。
- 仓库在 `master` 分支推送后，会通过 `.github/workflows/deploy-web.yml` 执行 headless 导出，并将产物部署到 GitHub Pages。
- CI 需要先执行资源导入，再执行 Web 导出，避免新字体资源在无缓存环境中缺失导入数据。

## 关键模块

### 领域层

- `scripts/domain/prototype_city_owner.gd`
  - 阵营编号、颜色映射、阵营名称
- `scripts/domain/prototype_city_state.gd`
  - 城市状态、防御、产能、人口上限、产兵判断、升级成本与升级应用

### 应用层

- `scripts/application/prototype_map_generator.gd`
  - 地图生成、道路连通、开局势力分配、城市命名
- `scripts/application/prototype_battle_service.gd`
  - 出兵准备、到城结算、运兵失守重战、路上遭遇战、按产能产兵、城市升级、胜负判断
- `scripts/application/prototype_enemy_ai_service.gd`
  - 电脑势力的难度/风格配置、回合间隔、目标选择和出兵建议

## 电脑 AI 参数表

`prototype_enemy_ai_service.gd` 当前采用一套统一的候选目标评分框架，再叠加“难度”和“风格”参数，形成不同电脑势力的行为差异。

| 难度维度 | 简单 | 普通 | 困难 |
| --- | --- | --- | --- |
| 行动间隔基础值 | 5.0 秒 | 4.0 秒 | 3.0 秒 |
| 允许进攻的最小优势 | 比守军多 4 人 | 比守军多 2 人 | 比守军多 1 人 |
| 推荐兵力附加值 | +0 | +1 | +3 |
| 评分难度修正 | -0.4 | +0.0 | +0.6 |

| 风格维度 | 进攻型 | 防御型 |
| --- | --- | --- |
| 行动间隔风格修正 | -0.4 秒 | +0.4 秒 |
| 源城最少留守兵力 | 1 | 3 |
| 推荐兵力附加值 | +1 | +0 |
| 路程惩罚系数 | 0.3 | 0.8 |
| 目标是玩家城时加分 | +1.2 | +0.5 |
| 目标是非己方的其他城市时加分 | +0.9 | +1.2 |

补充说明：

- 进攻型会更快出手、更愿意压兵，也会略微偏好攻击玩家城市，但不会在多人局里固定只围攻玩家。
- 防御型更强调近距离扩张和后方留守，因此更容易先吃下附近的中立城或其他电脑势力城市。
- 实际是否出兵，还会同时受 `PrototypeBattleService.get_recommended_attack_count()`、目标防御值、目标产兵速度和行军距离共同影响。

### 表现层

- `scripts/presentation/prototype_main_game.gd`
  - 主循环、输入路由、HUD、暂停、空白点击取消、城市升级按钮、行军单位、背景绘制、说明/结束面板
- `scripts/presentation/prototype_city_view.gd`
  - 城市图标绘制、城市标签、点击区域

## 运行时数据流

1. `prototype_main_game.gd` 在开局时调用 `prototype_map_generator.gd` 生成城市数组
2. 城市数组被复制成若干 `PrototypeCityView` 节点，负责显示和点击
3. 玩家或电脑下令后，主场景创建行军单位字典并逐帧推进
4. 路上若发生不同势力接触，调用 `PrototypeBattleService.resolve_marching_encounter()`
5. 到达目标城市后，调用 `resolve_attack_arrival()` 或 `resolve_transfer_arrival()`
6. 每秒通过 `produce_soldiers()` 按各城市产能推进占领城市产兵
7. 每轮推进后通过 `get_winner()` 判断是否只剩一个非中立势力

## 重要实现约束

- 核心规则尽量放在可测试的纯逻辑服务和状态对象中
- 表现层负责显示、输入与场景编排，不直接写战斗规则
- 出兵预判和真实到达结算允许不一致，因为路上可能发生产兵、增援和遭遇战
- 城市防御和产能属于领域属性，必须由 `prototype_city_state.gd` 持有，并由服务层消费
- 暂停不应改变地图状态，只停止时间推进与电脑行动
- 文档变更必须和当前生效实现同步
- Web 平台不能依赖宿主系统一定提供中文字体，项目必须显式携带覆盖中文字符集的字体资源
- `prototype_main_game.gd` 与场景 `LabelSettings` 统一使用 `assets/fonts/NotoSansSC-Regular.otf`，避免 Web 版中文缺字

## 关键规则现状

- 总方数配置 = `1` 个玩家 + `N-1` 个电脑势力
- 玩家运兵允许跨图；进攻必须相邻
- 路上不同势力部队相遇会先战斗
- 失守后的迟到援军会重新与守军作战，而不是直接被收编
- 当地图上只剩一个非中立势力时结束对局
- 进攻型 AI 会主动压迫玩家，但多人局里仍会争夺其他电脑势力和中立城市，不会只盯着玩家打

## 测试入口

- `tests/test_runner.gd`
- 推荐命令：

```bash
HOME=/tmp XDG_DATA_HOME=/tmp godot --headless --path . -s res://tests/test_runner.gd
```
