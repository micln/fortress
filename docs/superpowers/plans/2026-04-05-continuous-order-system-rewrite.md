# 持续出兵系统重写执行计划（2026-04-05）

## 背景

现有 `prototype_main_game.gd` 中的一次性出兵、持续出兵、出兵弹窗、AI 直接进攻、音效、副作用清理等逻辑长期叠加，已经导致以下问题：

- 持续出兵任务在目标归属变化、来源城市状态变化时出现不可预期中断
- UI 选中态、出兵行为、日志、副作用之间高度耦合，修一处容易破坏另一处
- 玩家与 AI 走的是不同链路，无法共享稳定规则
- “每产 1 兵触发 1 次持续出兵”的核心体验并没有被架构层明确表达

因此不再继续修补旧链路，而是按已确认方案整体重写“出兵系统”。

## 目标

- 主流程只支持持续出兵
- 一次性出兵仅预留扩展接口，不接入当前运行链
- 玩家与 AI 共用同一套持续任务模型
- 城市每产出 1 个士兵时，按轮转规则执行一次持续任务
- 目标当前归属动态决定本次是进攻还是运兵
- 来源城市失守时，取消该来源城市的全部持续任务，夺回后不恢复
- 右侧新增持续出兵 HUD，展示当前进行中的任务
- 每次持续出兵不播放出兵音效，只保留占领/失守等关键音效

## 影响文件

### 新增

- `scripts/domain/prototype_march_order.gd`
- `scripts/application/prototype_order_dispatch_service.gd`

### 修改

- `scripts/presentation/prototype_main_game.gd`
- `scripts/application/prototype_enemy_ai_service.gd`
- `scenes/main/prototype_main.tscn`
- `tests/test_runner.gd`
- `readme.md`
- `docs/gameplay.md`
- `docs/technical.md`
- `docs/testing.md`
- `docs/runbook.md`
- `docs/agent_lessons.md`

## 分阶段实施

### 1. 建立任务模型与调度服务

- 新建 `PrototypeMarchOrder`，只承载 `source_id`、`target_id`、`enabled`、`mode`
- 新建 `PrototypeOrderDispatchService`
- 服务负责：
  - 注册/切换任务
  - 删除某来源城市的全部任务
  - 对某来源城市执行轮转调度
  - 输出 HUD 友好的任务快照
  - 输出结构化日志所需的上下文字段

### 2. 重写玩家主流程

- 先点 A 再点 B，直接创建或关闭 `A -> B` 持续任务
- 旧出兵弹窗退出主流程，不再参与当前默认操作
- 保留未来一次性出兵的接口占位，但不接 UI
- 城市每产出 1 个兵时，立即调用调度服务尝试发兵

### 3. 改写 AI

- AI 不再直接执行 `_execute_attack`
- AI 改为定期创建/更新持续出兵任务
- 仍保留“无合适任务时升级城市”的现有策略兜底

### 4. 增加右侧 HUD

- 在 `UILayer` 下新增右侧面板
- 面板展示所有有效持续任务
- 每条任务显示：
  - 来源城市 -> 目标城市
  - 当前动态类型：进攻 / 运兵
  - 当前状态：运行中 / 来源失效 / 暂无可派兵

### 5. 测试与文档

- 为调度服务补充独立测试
- 为 AI 任务化行为补回归测试
- 同步玩法、技术、测试、排障文档
- 把这次“停止在旧链上打补丁”的教训记录到 `docs/agent_lessons.md`

## 验证计划

### 自动验证

- 运行：
  - `HOME=/tmp XDG_DATA_HOME=/tmp godot --headless --path . -s res://tests/test_runner.gd`

### 手工验证

- 玩家点 A 再点 B 后，立即创建持续任务
- A 有多个目标时，产兵后轮流出兵
- 目标换手后，任务仍保留，并按当前归属动态切换进攻/运兵
- 来源城市失守后，来源的全部任务被取消
- 夺回来源城市后，旧任务不会恢复
- 右侧 HUD 会实时刷新任务列表
- 持续出兵不再播放出兵音效

## 风险与控制

- `prototype_main_game.gd` 当前体积较大，替换时容易漏掉旧状态变量
  - 控制方式：先删除主流程依赖，再引入新服务，不做混用
- Scene 结构已有大量 UI，新增 HUD 需要注意窄屏布局
  - 控制方式：先用纯文本 PanelContainer 实现，避免过度美术化
- 当前环境无法保证本地存在 `godot` 可执行文件
  - 控制方式：尽可能补充 headless 测试；若命令不可用，明确说明未完成自动验证
