# 持续出兵系统重写设计

## 背景

当前 `prototype_main_game.gd` 中的出兵逻辑已经被多轮补丁叠加，导致以下问题持续出现：

- 一次性出兵、持续出兵、进攻/运兵、UI 弹窗、音效、日志耦合在同一条执行链上
- 持续任务在目标归属变化、多路线并发、玩家重复操作时容易失效或行为不一致
- 玩家与 AI 分别走不同逻辑，难以统一验证
- 现有系统不适合继续增量修补

因此本次采用“整体重写”，保留当前地图、行军、战斗结算与城市产兵规则，重写“出兵任务的创建、调度与展示”。

## 目标

- 默认交互改为“持续出兵”
- 玩家和 AI 统一使用持续出兵任务模型
- 某城每产出 1 个士兵，就触发一次持续出兵调度
- 一个源城同时有多个目标任务时，按轮转顺序出兵
- 一次性出兵本轮不实现，但预留扩展接口
- 不再为每次出兵播放音效，只保留占城/失城等关键状态音效
- 提供稳定的任务 HUD 和结构化日志，方便排查

## 非目标

- 本轮不实现一次性出兵 UI 和执行链
- 本轮不改地图生成、道路、战斗结算主体规则
- 本轮不新增复杂兵种、路径规划或队列优先级策略

## 关键规则

### 1. 任务模型

持续出兵任务只表达一条路线：

- `source_id`
- `target_id`
- `enabled`
- `mode`

其中：

- `mode` 先只支持 `continuous`
- 不记录人数
- 不预先记录 `attack` / `transfer`
- 任务执行时再根据目标当前归属动态决定这次是进攻还是运兵

### 2. 玩家交互

- 默认模式为持续出兵
- 玩家先点 A，再点 B，即创建或更新一条 `A -> B` 持续任务
- 若 `A -> B` 任务已存在，再次执行同一路线操作则关闭该任务
- 本轮不通过数量弹窗参与主流程
- 一次性出兵接口只保留方法占位，不接 UI

### 3. AI 交互

- AI 不再直接“立即进攻”
- AI 只负责创建、更新或取消持续出兵任务
- 初期可以限制每个 AI 同时活跃任务数量，避免刷屏

### 4. 产兵触发

- 某源城每产出 1 个士兵，就触发一次调度
- 若该城没有任务，则本次不派兵
- 若该城有多个任务，则按轮转指针选择当前任务发出 1 人
- 发出后轮转指针前移

### 5. 任务终止规则

仅允许以下情况删除任务：

- 玩家手动关闭该任务
- 源城失守

明确约束：

- 源城失守后，立即取消该源城发出的所有持续任务
- 源城后续重新夺回后，不恢复旧任务
- 目标城市换手不会删除任务
- 目标城市从敌方变己方或从己方变敌方时，后续调度自动切换为运兵或进攻
- 源城暂时无兵不会删除任务，只跳过本次触发

## 架构设计

### 领域层

新增：

- `scripts/domain/prototype_march_order.gd`

职责：

- 表达单条持续出兵任务的纯数据对象
- 提供最小字段访问和辅助方法

建议字段：

- `source_id: int`
- `target_id: int`
- `enabled: bool`
- `mode: String`

### 应用层

新增：

- `scripts/application/prototype_order_dispatch_service.gd`

职责：

- 维护所有持续出兵任务
- 按源城组织任务列表
- 维护每个源城的轮转指针
- 在产兵事件发生时决定是否发兵
- 根据目标当前归属动态决定本次是进攻还是运兵

建议公开接口：

- `register_continuous_order(source_id, target_id)`
- `remove_continuous_order(source_id, target_id)`
- `remove_orders_by_source(source_id)`
- `has_order(source_id, target_id)`
- `get_orders_for_source(source_id)`
- `dispatch_for_produced_soldier(cities, source_id) -> Dictionary`
- `get_all_orders() -> Array`

返回的调度结果建议包含：

- `success`
- `reason`
- `source_id`
- `target_id`
- `is_transfer`
- `troop_count`

### 表现层

保留：

- `prototype_main_game.gd` 负责输入、HUD、行军可视化、日志

调整职责：

- 点击城市时不再进入旧的数量弹窗主流程
- 玩家点 A 再点 B 后，直接注册或取消持续任务
- 每秒产兵时调用调度服务，而不是自己维护一堆持续任务状态
- 调度成功后再复用现有 `_execute_attack()` / `_execute_transfer()` 的“发兵 + 行军创建”能力

### 右侧 HUD

新增一个右侧任务面板，风格参考“红警式列表”：

- 标题：`出兵任务`
- 每行显示：
  - `源城 -> 目标城`
  - 当前动作：`进攻` / `运兵`
  - 状态：`运行中` / `无兵` / `已取消`

最小要求：

- 先做文本列表
- 玩家与 AI 的任务都展示
- 实时刷新

## 执行流程

### 玩家创建任务

1. 玩家点击 A
2. 玩家点击 B
3. 表现层调用 `register_continuous_order(A, B)`
4. 若任务已存在，则执行关闭
5. HUD 和日志刷新

### 城市产兵触发

1. 城市 A 在产兵 tick 中新增 1 个士兵
2. 主场景通知调度服务：`dispatch_for_produced_soldier(A)`
3. 调度服务按 A 的轮转指针选中一个目标任务
4. 根据目标当前归属决定：
   - 目标是玩家：运兵
   - 目标不是玩家：进攻
5. 返回调度结果
6. 主场景调用 `_execute_transfer()` 或 `_execute_attack()`
7. 轮转指针前移

### 源城失守

1. 某城市归属变化
2. 若该城不是玩家了
3. 调度服务删除该源城发出的全部任务
4. HUD 立即刷新
5. 记录日志

## 音效策略

保留：

- 占领城市
- 丢失城市
- 胜利 / 失败
- 基础 UI 点击音效

移除：

- 每次出兵音效

原因：

- 持续出兵是高频事件，出兵音效会造成明显噪音污染

## 日志设计

继续使用 `[game-debug]` 结构化日志，新增或重构以下事件：

- `order_registered`
- `order_removed`
- `orders_removed_by_source_loss`
- `order_dispatch_attempt`
- `order_dispatch_success`
- `order_dispatch_skipped`
- `production_tick`
- `march_launched`
- `march_arrival_attack`
- `march_arrival_transfer`
- `city_captured`
- `city_lost`

日志必须带：

- `source_id`
- `source_name`
- `target_id`
- `target_name`
- `reason`
- `source_owner`
- `target_owner`
- `source_soldiers`

## 测试方案

### 自动化测试

至少新增以下测试：

1. 单任务源城每产 1 兵就派 1 人
2. 一个源城多个任务时轮流出兵
3. 目标换手后任务仍保留，并动态切换进攻/运兵
4. 源城失守时删除该源城全部任务
5. 源城重新夺回后旧任务不会恢复
6. 重复注册同一路线时变为关闭

### 手工验证

- 玩家点击 A -> B 后是否立刻建立任务
- 同一源城多个任务是否轮转
- 目标换手后路线是否继续工作
- 源城失守后任务是否从 HUD 消失
- AI 任务是否显示在右侧面板
- 出兵过程是否不再播放高频音效

## 实施顺序

1. 新增 `PrototypeMarchOrder`
2. 新增 `PrototypeOrderDispatchService`
3. 接管主场景产兵调度入口
4. 改写玩家点城逻辑为“直接注册/取消任务”
5. 改写 AI 下单逻辑为“任务式”
6. 增加右侧任务 HUD
7. 删除旧持续出兵补丁链路
8. 补测试和日志

## 风险

- `prototype_main_game.gd` 当前历史补丁较多，直接修改时容易遗留旧入口
- 数量弹窗相关旧代码若不彻底降级，可能继续偷偷参与流程
- AI 从“立即攻击”切换到“任务式”后，节奏会变化，需要重新观察对局表现

## 决策

采用本方案进行整体重写，放弃继续在当前出兵补丁链路上修补。
