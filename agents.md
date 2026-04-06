# AGENTS.md

本文件面向在本仓库内工作的 agentic coding agents。

目标：让 agent 在不猜测仓库规则的前提下，快速理解项目、找到正确入口、明确修改边界，并使用正确的验证方式交付结果。

---

## 一句话工作守则

在这个仓库里，正确做法是：**优先改当前 `main` 主场景活跃链路，保持 `presentation -> application -> domain` 分层，补函数头注释，同步文档，并用已证实的测试 / 冒烟方式验证后再交付。**

---

## 核心规则

- 使用简体中文回答。
- 意识到错误后，要先反思、总结，再进行持久化记录，避免重复犯错。
- 遇到不懂的问题，要主动搜索资料，不要凭空猜测。
- 尽可能使用 sub agent 并行完成任务，但要先划清文件边界、接口边界和职责边界。
- 生成代码前先明确修改范围与禁止修改范围；信息不足时，优先读代码、读文档、读测试。
- 输出结果应尽量可执行、可验证、可审阅，优先给出补丁、命令、测试与风险说明。
- 高风险操作必须先确认；输出中应明确关键假设、风险点、依赖项和验证方案。
- AI 生成的代码必须补齐测试、注释和必要文档，确保实现、测试、文档三者一致。
- 对复杂任务采用“先测试或先定义验收标准，再实现，再回归验证”的工作流。
- 长任务要持续记录进度、已完成项、阻塞项和下一步计划，避免上下文压缩后丢失状态。

---

## 建立上下文的阅读顺序

按以下顺序建立上下文；若文件不存在则跳过，不要主动创建补充文档。

1. `AGENTS.md`
2. `readme.md`
3. `claude.md`
4. `docs/technical.md`
5. `docs/architecture.md`
6. `docs/testing.md`
7. `docs/runbook.md`

若任务涉及玩法、产品边界、历史坑点，再继续读：

8. `docs/gameplay.md`
9. `docs/product.md`
10. `docs/overview.md`
11. `docs/agent_lessons.md`

---

## 文档索引与用途

- `readme.md`
  - 项目概览、当前能力、运行方式与目录入口的快速说明。
- `claude.md`
  - `AGENTS.md` 的补充说明，主要补充代码组织、交互约定和实现约束。
- `docs/technical.md`
  - 当前生效实现与运行细节的权威说明，包括入口链路、分辨率策略、关键模块、运行时数据流与平台约束。
- `docs/architecture.md`
  - 分层边界与依赖方向的架构基线，以及后续渐进式演进路线。
- `docs/testing.md`
  - 测试范围、执行方式、Web 冒烟与手工验收口径的统一清单。
- `docs/runbook.md`
  - 本地运行、Web HTTPS 联调、调试日志与发布排障的操作手册。
- `docs/gameplay.md`
  - 当前玩法规则与交互语义的真值文档，包括持续出兵、结算顺序与操作边界。
- `docs/product.md`
  - 产品定位、目标用户与高层体验目标，主要回答“为什么做”。
- `docs/overview.md`
  - 原型阶段目标、非目标与范围边界的简版概览。
- `docs/agent_lessons.md`
  - 历史踩坑与修复经验沉淀，用于避免重复犯错。

---

## 文档真值优先级

不同文档的更新频率不同。出现描述冲突时，按以下优先级判断“当前实现真值”：

1. 代码与测试
2. `docs/technical.md` / `docs/gameplay.md`
3. `docs/testing.md` / `docs/runbook.md`
4. `readme.md` / `docs/architecture.md`
5. `docs/product.md` / `docs/overview.md`
6. `docs/agent_lessons.md`

补充说明：

- `docs/product.md` 和 `docs/overview.md` 偶尔会保留阶段性旧描述；若与当前实现冲突，以 `technical` / `gameplay` 和实际代码为准。
- `docs/agent_lessons.md` 记录的是经验与防坑规则，不直接覆盖当前实现行为。

---

## 每日自我改进

统一使用：`./self-improving/YYYY-MM-DD-xxx.md`

规则如下：

- 错误记录至少包含：任务背景、错误现象、根因分析、正确做法、防再犯措施。
- 新技能记录至少包含：来源、适用场景、关键做法、可复用示例。
- 当天有则追加，没有则新建；同一天只维护一个文件。
- 若发现可沉淀为稳定规则，应同步更新 `AGENTS.md` 或相关文档。

说明：

- `./.claude/self-improving/` 视为历史路径；后续新增记录统一写入 `./self-improving/`。

---

## 架构与分层规则

遵循 clean architecture / DDD 倾向的分层：

| 层 | 职责 | 约束 |
| --- | --- | --- |
| `scripts/domain/` | 规则、实体、状态、纯逻辑 | 不依赖场景树 |
| `scripts/application/` | 流程编排、地图生成、AI 决策、规则服务调用 | 不直接依赖场景节点 |
| `scripts/presentation/` | 输入、绘制、HUD、场景树交互、坐标换算 | 仅做状态展示与输入转发 |

依赖方向：`presentation -> application -> domain`

不要把以下职责放错层：

- 战斗规则、产兵规则、升级规则：放在 `domain` / `application`
- 地图拖拽、屏幕 / 世界坐标换算、HUD 布局：放在 `presentation`

---

## 当前有效入口与活跃链路

当前唯一运行链：

- `project.godot`
- `scenes/main/main.tscn`
- `scenes/main/main.gd`：入口壳，继续保持场景引用路径稳定
- `scenes/main/main_bootstrap.gd`：装配 / 初始化
- `scenes/main/main_flow.gd`：主流程与 UI 编排
- `scenes/main/main_context.gd`：共享基础与工具
- `scripts/presentation/main_input_handler.gd`：输入 / 手势与取消选城语义
- `scripts/presentation/city_view.gd`
- `scripts/application/map_generator.gd`
- `scripts/application/preset_map_definition.gd`
- `scripts/application/preset_map_loader.gd`
- `scripts/application/battle_service.gd`
- `scripts/application/enemy_ai_service.gd`
- `scripts/application/order_dispatch_service.gd`
- `scripts/domain/city_owner.gd`
- `scripts/domain/city_state.gd`

默认优先改以上链路中的对应文件。若任务需要改动其他文件，应先确认是否真的必要，并说明原因与影响面。

---

## 默认修改范围与禁止项

默认允许改动：

- 当前活跃链路中的代码文件
- 相关测试
- 与本次实现直接相关的文档

默认不要主动改动：

- 非当前运行链的旧原型脚本
- 与当前任务无关的导出配置、CI、资源文件
- 公共接口与场景路径稳定性依赖项，除非已有充分证据表明必须调整

若必须超出默认范围，先补充以下说明再动手：

- 为什么现有活跃链路无法完成需求
- 需要扩大的文件范围
- 风险点与验证方案

---

## 代码风格与实现约束

### Imports

- 使用 `const XxxRef = preload("res://...")` 预加载资源。
- 跟随现有风格，不要随意改动活跃文件的导入方式。

### Types

- 使用 GDScript 类型标注：`int`、`float`、`bool`、`Array[int]`、`Dictionary`、`Vector2`。
- 不要为了“更强静态类型”破坏当前装配稳定性。

### Naming

- 类名：`PascalCase`
- 文件名：`snake_case.gd`
- 函数 / 变量：`snake_case`
- 常量：`UPPER_SNAKE_CASE`
- 新增主链代码默认不加 `prototype_` 前缀；历史模块按现状逐步迁移。

### 格式

- 使用 Godot 默认格式化（Tab 缩进）。
- 单行代码不超过 120 字符。
- 大括号风格与现有文件保持一致。

### 注释

- 每个函数必须带函数头注释。
- 注释需说明：功能、调用场景、主要逻辑。
- 复杂计算、少见 Godot API、关键边界条件要写清楚。

### 错误处理

- 使用 `push_error()` 报告测试失败。
- 使用 `push_warning()` 报告警告。
- 使用 `assert()` 做开发期断言检查。

---

## Build / Run / Test Commands

### 本地运行

使用 Godot `4.6.x` 打开仓库根目录，运行主场景 `scenes/main/main.tscn`。

### 运行所有测试

```bash
HOME=/tmp XDG_DATA_HOME=/tmp godot --headless --path . -s res://tests/test_runner.gd
```

### 运行单个测试

测试函数命名为 `_test_xxx`；可临时修改 `tests/test_runner.gd` 的 `_initialize()` 测试列表来缩小执行范围。

### Web 冒烟检查

```bash
scripts/tools/web_smoke_check.sh
```

### CI Web 导出流程

```bash
godot --headless --path . --import
mkdir -p build/web
godot --headless --path . --export-release "Web" build/web/index.html
cp build/web/index.html build/web/404.html
```

---

## 修改后的最少验证要求

- 所有代码改动：运行 headless 测试。
- 主场景 / 表现层 / 装配逻辑：在 Godot 中启动主场景做手工验证。
- Web 导出 / 字体 / 前端资源：执行 `scripts/tools/web_smoke_check.sh`。
- 移动端 / 触控 / 布局：追加手工 Web / 手机抽检。

---

## 手工验证重点

- 主场景是否能正常启动。
- 竖屏布局是否可用。
- 拖拽地图时不会误触选城。
- 点击城市、打开出兵面板、暂停 / 继续是否正常。
- 升级按钮状态是否正确。
- 行军、遭遇战、攻城、运兵是否符合规则。
- Web 下中文是否正常显示。
- Web 下 HUD / Overlay / OrderDialog 是否越界。
- 缩放后点击命中是否仍与视觉位置一致。

---

## 重点已知风险区

- 触摸与兼容鼠标重复事件。
- 动态分辨率与 `Window.content_scale_size`。
- Web 高 DPI 逻辑尺寸换算。
- 窄屏 HUD / Overlay / OrderDialog 自适应。
- 选城与空白取消事件冲突。

涉及以上问题时，优先使用已有结构化日志：

- `[input-debug]`
- `[city-input-debug]`
- `[game-debug]`

---

## 并行任务规范

- 多个 agent 并行工作时，先划清文件边界、接口边界和职责边界。
- 避免同时修改热点文件。
- 合并时按顺序集成，每一步执行自动化验证。
- 长任务持续记录进度、已完成项、阻塞项和下一步计划。
