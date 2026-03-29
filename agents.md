# AGENTS.md

本文件面向会在本仓库内工作的 agentic coding agents。

目标：让代理在**不猜测仓库规则**的前提下，快速理解项目、找到正确入口、使用正确验证方式，并聚焦当前唯一运行链。

---

## 1. 仓库定位

- 项目名：`Fortress War`
- 引擎：Godot `4.6`
- 类型：手机竖屏轻策略攻防原型
- 目标平台：移动端优先，同时兼容桌面/Web
- 当前运行入口：`scenes/main/prototype_main.tscn`
- 当前有效实现：`prototype_*` 这一套
- 当前文档和说明仅以 `prototype_*` 这一套为准

## 2. 先读哪些文件

开始任何实现前，按这个顺序建立上下文：

1. `AGENTS.md`（本文件）
2. `readme.md`
3. `agents.md`
4. `claude.md`
5. `docs/technical.md`
6. `docs/architecture.md`
7. `docs/testing.md`
8. `docs/runbook.md`
9. `docs/agent_lessons.md`

如果改动涉及玩法或规则，再读：

- `docs/gameplay.md`
- `docs/product.md`
- `docs/overview.md`

## 3. 权威规则来源

本仓库当前真正存在、且应影响你的规则文件：

- `agents.md`
- `claude.md`

当前**未发现**以下规则来源：

- `.cursor/rules/`
- `.cursorrules`
- `.github/copilot-instructions.md`

因此，不要假设存在 Cursor 或 Copilot 的额外仓库规则。

## 4. 沟通与文档规则

- 默认使用**简体中文**沟通
- 代码注释使用英文并不适用于本仓库；当前仓库实际函数头注释为中文，**跟随现有风格即可**
- 修改代码时，必须保持**代码与文档一致**
- 涉及较大业务逻辑、玩法、架构、运行方式的变更时，必须同步更新 `docs/*.md`、`readme.md` 或相关说明文档
- 如果你犯了明确错误、踩到新坑，应该更新 `docs/agent_lessons.md` 做复盘沉淀

## 5. 架构与分层规则

必须遵循 clean architecture / DDD 倾向的分层：

- `scripts/domain/`：规则、实体、状态、纯逻辑
- `scripts/application/`：流程编排、地图生成、AI 决策、规则服务调用
- `scripts/presentation/`：输入、绘制、HUD、场景树交互、坐标换算

依赖方向必须保持：

- `presentation -> application -> domain`
- `domain` 不依赖具体场景树
- `application` 不直接依赖具体场景节点

不要把以下职责放错层：

- 战斗规则、产兵规则、升级规则：放 `domain` / `application`
- 地图拖拽、屏幕/世界坐标换算、HUD 布局：放 `presentation`
- 场景层不要直接写战斗规则

## 6. 当前有效入口与活跃文件

当前唯一运行链如下：

- `project.godot`
- `scenes/main/prototype_main.tscn`
- `scripts/presentation/prototype_main_game.gd`
- `scripts/presentation/prototype_city_view.gd`
- `scripts/application/prototype_map_generator.gd`
- `scripts/application/prototype_battle_service.gd`
- `scripts/application/prototype_enemy_ai_service.gd`
- `scripts/domain/prototype_city_owner.gd`
- `scripts/domain/prototype_city_state.gd`

默认只改以上链路中的对应文件，其他文件不在默认改动范围内。

## 7. 代码风格

### 7.1 Imports / 依赖组织

- 本仓库大量使用 `const XxxRef = preload("res://...")`
- 跟随现有风格，不要随意把活跃文件改成另一套导入方式
- 需要跨层引用时，优先沿用现有 `preload` 结构

### 7.2 Types / 类型

- 当前代码广泛使用 GDScript 类型标注：`int`、`float`、`bool`、`Array[int]`、`Dictionary`、`Vector2`
- 新增代码时应尽量补充清晰类型，尤其是公开函数、关键局部变量、返回值
- 但不要为了“更强静态类型”破坏当前装配稳定性
- 遵循仓库已有经验：原型阶段优先稳定、清晰、可验证

### 7.3 Naming / 命名

- 类名使用 `PascalCase`，例如 `PrototypeBattleService`
- 文件名使用 `snake_case.gd`
- 函数名、变量名使用 `snake_case`
- 常量使用 `UPPER_SNAKE_CASE`
- 当前活跃实现统一采用 `Prototype*` / `prototype_*` 命名体系；新增当前主线代码时应遵循该命名体系

### 7.4 Formatting / 格式

- 跟随现有 GDScript 风格，不要引入与仓库不一致的大规模格式化噪音
- 小步修改，优先保持局部 diff 清晰
- 不要顺手重排无关代码

### 7.5 Functions / 函数规范

- 函数必须带**函数头注释**
- 注释应说明：
  - 功能是什么
  - 调用场景是什么
  - 主要逻辑是什么
- 复杂计算、少见 Godot API、关键边界条件要写清楚

### 7.6 File size / 文件职责

- 优先保持职责清晰，不要把大段无关逻辑堆进一个文件
- 如果某一层逻辑膨胀，优先考虑按职责拆分，而不是继续塞进主控脚本
- 但也不要做与当前任务无关的大重构

## 8. 错误处理与实现约束

- 不要靠猜测修 bug，先读现有实现与文档
- 修 bug 时优先最小修复，不要顺手重构整个模块
- 不要无依据地改动历史逻辑
- 涉及输入、移动端 Web、分辨率适配时，优先先看 `docs/agent_lessons.md`
- 如果出现输入事件异常，优先使用已有结构化日志：
  - `[input-debug]`
  - `[city-input-debug]`

重点已知风险区：

- 触摸与兼容鼠标重复事件
- 动态分辨率与 `Window.content_scale_size`
- Web 高 DPI 逻辑尺寸换算
- 窄屏 HUD / Overlay / OrderDialog 自适应
- 选城与空白取消事件冲突

## 9. Build / Run / Test Commands

以下只写**仓库已证实存在**的命令。

### 9.1 本地运行

没有文档化的一键 shell 启动命令。

官方方式是：

- 使用 Godot `4.6.x` 打开仓库根目录
- 运行主场景：`scenes/main/prototype_main.tscn`

### 9.2 核心规则测试

运行全部 headless 测试：

```bash
HOME=/tmp XDG_DATA_HOME=/tmp godot --headless --path . -s res://tests/test_runner.gd
```

这是当前仓库最核心、最权威的自动化验证命令。

### 9.3 单个测试

当前仓库**没有官方支持的单测命令**。

原因：

- `tests/test_runner.gd` 在 `_initialize()` 中硬编码串行执行全部测试
- 未发现按测试名筛选的参数处理逻辑
- 文档中也没有提供“运行单个测试”的命令

因此，`single test` 一栏应理解为：

- **不支持官方单测执行**
- 当前仅支持运行整个 `tests/test_runner.gd` 测试集

### 9.4 Web 冒烟检查

本地 Web 自动检查：

```bash
scripts/tools/web_smoke_check.sh
```

该脚本会：

- 导出 Web 构建
- 校验 `index.html/index.js/index.wasm/index.pck`
- 执行 `node --check build/web/index.js`
- 检查 HTML 中的 `Engine` 启动片段

### 9.5 本地 HTTPS 联调

```bash
scripts/tools/serve_web_https.sh
```

默认端口 `18443`。

如果是手机/Web 联调，必须走 HTTPS，不要改回纯 HTTP。

### 9.6 CI 中已证实的 Web 导出流程

CI 工作流里存在以下命令链：

```bash
godot --headless --path . --import
mkdir -p build/web
godot --headless --path . --export-release "Web" build/web/index.html
cp build/web/index.html build/web/404.html
```

### 9.7 Lint

当前仓库**没有文档化的 lint 命令**，也没有找到对应 lint 脚本或 lint CI。

不要编造 `lint` 命令写进说明或提交信息里。

## 10. 修改后最少验证要求

修改代码后，至少按改动类型执行以下验证：

- 所有代码改动：运行 headless 测试
- 改动主场景、表现层、装配逻辑：在 Godot 中启动主场景手工验证
- 改动 Web 导出、字体、前端资源或浏览器交互：执行 `scripts/tools/web_smoke_check.sh`
- 改动移动端/触控/布局：追加手工 Web/手机抽检

不要交付未经测试的代码。

## 11. 手工验证重点

手工验证时重点检查：

- 主场景是否能正常启动
- 竖屏布局是否可用
- 拖拽地图时不会误触选城
- 点击城市、打开出兵面板、暂停/继续是否正常
- 升级按钮状态是否正确
- 行军、遭遇战、攻城、运兵是否符合规则
- Web 下中文是否正常显示
- Web 下 HUD / Overlay / OrderDialog 是否越界
- 缩放后点击命中是否仍与视觉位置一致

## 12. 代理工作方式建议

- 先确认要改的是不是 `prototype_*` 活跃链路
- 先读规则文档，再开始改代码
- 任何不确定的命令、路径、入口，都要回到仓库证据核实
- 不要假设仓库有 lint、单测过滤、Cursor rules、Copilot instructions
- 保持修改聚焦、分层清晰、验证充分

## 13. 一句话工作守则

在这个仓库里，正确做法是：**优先改 `prototype_*` 活跃实现，保持分层，补函数头注释，同步文档，并用已证实的测试/冒烟方式验证后再交付。**
