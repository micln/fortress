# Strategic Node Phase 2 Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 为首张预设地图引入 `关口 / 枢纽 / 腹地` 三类静态战略节点，并让这些节点通过轻量数值效果放大地图结构价值。

**Architecture:** 保持 `presentation -> application -> domain` 依赖方向不变。`domain` 新增节点类型字段与运行时承载；`application` 在预设地图定义与 loader 中装配节点类型并应用轻量属性修正；`presentation` 只负责显示最小提示，不持有规则判断。

**Tech Stack:** Godot 4.6、GDScript、`tests/test_runner.gd`、Markdown 文档

---

## File Structure

- Modify: `scripts/domain/prototype_city_state.gd`
  - 新增节点类型字段、默认值与必要的辅助常量
- Modify: `scripts/application/prototype_preset_map_definition.gd`
  - 为首张预设地图的关键城市补 `node_type`
- Modify: `scripts/application/prototype_preset_map_loader.gd`
  - 校验 `node_type`，应用节点效果并装配到运行时城市状态
- Modify: `scripts/presentation/prototype_main_game.gd`
  - 在不改主循环的前提下补最小节点类型提示
- Modify: `tests/test_runner.gd`
  - 增加节点类型装配与数值效果测试
- Modify: `docs/technical.md`
  - 同步节点类型与装配逻辑
- Optional Modify: `readme.md`
  - 若玩法说明需要，补节点类型说明

## Chunk 1: Domain Contract & Red Tests

### Task 1: 先为战略节点写失败测试

**Files:**
- Modify: `tests/test_runner.gd`
- Inspect: `scripts/domain/prototype_city_state.gd`
- Inspect: `scripts/application/prototype_preset_map_definition.gd`

- [ ] **Step 1: 新增战略节点测试入口**

注册这些测试：

- `preset_map_assigns_strategic_node_types`
- `strategic_pass_increases_defense`
- `strategic_hub_increases_production`
- `strategic_heartland_increases_initial_soldiers`

- [ ] **Step 2: 写 `preset_map_assigns_strategic_node_types` 失败测试**

断言：

- 首张预设图里至少存在一座 `pass`
- 至少存在一座 `hub`
- 至少存在一座 `heartland`

- [ ] **Step 3: 写 `strategic_pass_increases_defense` 失败测试**

断言：

- `pass` 节点的运行时防御高于其模板基础值

- [ ] **Step 4: 写 `strategic_hub_increases_production` 失败测试**

断言：

- `hub` 节点的运行时产能高于其模板基础值

- [ ] **Step 5: 写 `strategic_heartland_increases_initial_soldiers` 失败测试**

断言：

- `heartland` 节点的运行时初始兵力高于其模板基础值

- [ ] **Step 6: 运行完整测试集，确认 RED**

Run:

```bash
HOME=/tmp XDG_DATA_HOME=/tmp godot --headless --path . -s res://tests/test_runner.gd
```

Expected:

- 新增战略节点测试失败

## Chunk 2: Node Type Data & Loader Effects

### Task 2: 为领域状态增加节点类型

**Files:**
- Modify: `scripts/domain/prototype_city_state.gd`

- [ ] **Step 1: 增加节点类型常量**

至少包含：

- `NODE_TYPE_NORMAL`
- `NODE_TYPE_PASS`
- `NODE_TYPE_HUB`
- `NODE_TYPE_HEARTLAND`

- [ ] **Step 2: 在城市状态中增加 `node_type` 字段**

要求：

- 默认值为 `normal`
- 不破坏现有构造调用

- [ ] **Step 3: 为公开辅助函数补函数头注释**

### Task 3: 为首张预设图打上节点标签

**Files:**
- Modify: `scripts/application/prototype_preset_map_definition.gd`

- [ ] **Step 1: 为关键城市补 `node_type`**

建议首批：

- `长安` -> `pass`
- `汉中` -> `pass`
- `洛阳` -> `hub`
- `许昌` -> `hub`
- `成都` -> `heartland`
- `交州` -> `heartland`

- [ ] **Step 2: 未标注城市显式或隐式回落到 `normal`**

### Task 4: 在 loader 中应用节点效果

**Files:**
- Modify: `scripts/application/prototype_preset_map_loader.gd`

- [ ] **Step 1: 校验 `node_type` 合法性**

- [ ] **Step 2: 实现节点效果修正**

规则：

- `pass` -> `defense + 1`
- `hub` -> `production_rate + 0.2`
- `heartland` -> `initial_soldiers + 2`

- [ ] **Step 3: 把最终 `node_type` 写入 `PrototypeCityState`**

- [ ] **Step 4: 运行完整测试集，确认转绿**

## Chunk 3: Presentation & Docs

### Task 5: 补最小节点类型提示

**Files:**
- Modify: `scripts/presentation/prototype_main_game.gd`

- [ ] **Step 1: 为城市状态提示补节点类型文案**

要求：

- 不新增复杂图标系统
- 只做最小中文标签提示

- [ ] **Step 2: 保持 HUD、出兵、拖拽主流程不变**

### Task 6: 同步文档

**Files:**
- Modify: `docs/technical.md`
- Optional Modify: `readme.md`

- [ ] **Step 1: 更新 technical 文档中的战略节点说明**

- [ ] **Step 2: 如 README 玩法说明受影响，再补节点类型描述**

## Chunk 4: Final Verification

### Task 7: 最终验证

**Files:**
- Verify: `tests/test_runner.gd`
- Verify: `scripts/domain/prototype_city_state.gd`
- Verify: `scripts/application/prototype_preset_map_definition.gd`
- Verify: `scripts/application/prototype_preset_map_loader.gd`
- Verify: `scripts/presentation/prototype_main_game.gd`

- [ ] **Step 1: 运行仓库权威 headless 测试**

Run:

```bash
HOME=/tmp XDG_DATA_HOME=/tmp godot --headless --path . -s res://tests/test_runner.gd
```

Expected:

- `ALL TESTS PASSED`

- [ ] **Step 2: 手工验证首张图中的战略节点感知**

验证点：

- 玩家可识别 `关口 / 枢纽 / 腹地`
- `pass` 更值得防守
- `hub` 更值得争夺
- `heartland` 更适合作为补兵与回防中转

- [ ] **Step 3: 准备交付说明**

说明中至少包含：

- 新增节点类型及其效果
- 首张图中哪些城市被标为战略节点
- 测试命令与结果
