# AGENTS.md

本文件面向会在本仓库内工作的 agentic coding agents。

目标：让代理在**不猜测仓库规则**的前提下，快速理解项目、找到正确入口、使用正确验证方式，并聚焦当前唯一运行链。

---

## 核心规则

- 使用简体中文来回答
- 意识到错误后，要反思、总结并进行持久化记录。避免重复犯错
- 遇到不懂的问题，要主动去网上搜索办法
- 尽可能使用 sub agent 并行完成任务
- 生成代码前先明确修改范围与禁止修改范围；信息不足时先搜索、读代码、读文档，不要凭空猜测
- 输出结果应尽量可执行、可验证、可审阅，优先给出补丁、命令、测试与风险说明
- 高风险操作必须先确认；输出中应明确关键假设、风险点、依赖项和验证方案
- AI 生成的代码必须补齐测试、注释和必要文档，确保实现、测试、文档三者一致
- 对复杂任务采用"先测试或先定义验收标准，再实现，再回归验证"的工作流

---

## 先读哪些文件

开始任何实现前，按这个顺序建立上下文：

1. `AGENTS.md`（本文件）
2. `readme.md`
3. `claude.md`
4. `docs/technical.md`
5. `docs/architecture.md`
6. `docs/testing.md`
7. `docs/runbook.md`
8. `docs/agent_lessons.md`

如果改动涉及玩法或规则，再读：
- `docs/gameplay.md`
- `docs/product.md`
- `docs/overview.md`

---

## 每日自我改进

- `./.claude/self-improving/YYYY-MM-DD-xxx.md` 是每日错误复盘与新技能记录
- 错误记录至少包含：任务背景、错误现象、根因分析、正确做法、防再犯措施
- 新技能记录至少包含：来源、适用场景、关键做法、可复用示例
- 当天有则追加，无则新建；记录应简洁但可执行

---

## 架构与分层规则

必须遵循 clean architecture / DDD 倾向的分层：

| 层 | 职责 | 约束 |
|----|------|------|
| `scripts/domain/` | 规则、实体、状态、纯逻辑 | 不依赖场景树 |
| `scripts/application/` | 流程编排、地图生成、AI 决策、规则服务调用 | 不直接依赖场景节点 |
| `scripts/presentation/` | 输入、绘制、HUD、场景树交互、坐标换算 | 仅做状态展示与转发输入 |

依赖方向：`presentation -> application -> domain`

**不要把以下职责放错层**：
- 战斗规则、产兵规则、升级规则 → `domain` / `application`
- 地图拖拽、屏幕/世界坐标换算、HUD 布局 → `presentation`

---

## 代码注释规范

- 函数必须带**函数头注释**
- 注释应说明：功能、调用场景、主要逻辑
- 复杂计算、少见 Godot API、关键边界条件要写清楚

---

## 代码风格

### Imports
- 本仓库大量使用 `const XxxRef = preload("res://...")`
- 跟随现有风格，不要随意改动活跃文件的导入方式

### Types
- 使用 GDScript 类型标注：`int`、`float`、`bool`、`Array[int]`、`Dictionary`、`Vector2`
- 不要为了"更强静态类型"破坏当前装配稳定性

### Naming
- 类名：`PascalCase`（如 `PrototypeBattleService`）
- 文件名：`snake_case.gd`
- 函数/变量：`snake_case`
- 常量：`UPPER_SNAKE_CASE`
- 活跃实现统一采用 `Prototype*` / `prototype_*` 命名体系

---

## 当前有效入口与活跃文件

当前唯一运行链：

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

---

## Build / Run / Test Commands

### 9.1 本地运行

使用 Godot `4.6.x` 打开仓库根目录，运行主场景 `scenes/main/prototype_main.tscn`。

### 9.2 核心规则测试

```bash
HOME=/tmp XDG_DATA_HOME=/tmp godot --headless --path . -s res://tests/test_runner.gd
```

### 9.3 Web 冒烟检查

```bash
scripts/tools/web_smoke_check.sh
```

### 9.4 本地 HTTPS 联调

```bash
scripts/tools/serve_web_https.sh
```

默认端口 `18443`。手机/Web 联调必须走 HTTPS。

### 9.5 CI Web 导出流程

```bash
godot --headless --path . --import
mkdir -p build/web
godot --headless --path . --export-release "Web" build/web/index.html
cp build/web/index.html build/web/404.html
```

---

## 修改后最少验证要求

- **所有代码改动**：运行 headless 测试
- **主场景/表现层/装配逻辑**：在 Godot 中启动主场景手工验证
- **Web 导出/字体/前端资源**：执行 `scripts/tools/web_smoke_check.sh`
- **移动端/触控/布局**：追加手工 Web/手机抽检

---

## 手工验证重点

- 主场景是否能正常启动
- 竖屏布局是否可用
- 拖拽地图时不会误触选城
- 点击城市、打开出兵面板、暂停/继续是否正常
- 升级按钮状态是否正确
- 行军、遭遇战、攻城、运兵是否符合规则
- Web 下中文是否正常显示
- Web 下 HUD / Overlay / OrderDialog 是否越界
- 缩放后点击命中是否仍与视觉位置一致

---

## 重点已知风险区

- 触摸与兼容鼠标重复事件
- 动态分辨率与 `Window.content_scale_size`
- Web 高 DPI 逻辑尺寸换算
- 窄屏 HUD / Overlay / OrderDialog 自适应
- 选城与空白取消事件冲突

涉及以上问题时，优先使用已有结构化日志：
- `[input-debug]`
- `[city-input-debug]`

---

## 并行任务规范

- 多个 agent 并行工作时，先划清文件边界、接口边界和职责边界
- 避免同时修改热点文件
- 合并时按顺序集成，每一步执行自动化验证
- 长任务持续记录进度、已完成项、阻塞项和下一步计划

---

## 一句话工作守则

在这个仓库里，正确做法是：**优先改 `prototype_*` 活跃实现，保持分层，补函数头注释，同步文档，并用已证实的测试/冒烟方式验证后再交付。**
