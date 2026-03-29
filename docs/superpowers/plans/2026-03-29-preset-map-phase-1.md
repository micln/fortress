# Preset Map Phase 1 Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 为当前 `prototype_*` 主链新增第一阶段预设地图装载能力，并让第一张中国风抽象战略图在保持现有主循环的前提下可用于 `2` 到 `5` 方开局。

**Architecture:** 保持 `presentation -> application -> domain` 依赖方向不变。`presentation` 仅决定本局使用预设地图来源；`application` 新增“预设地图定义 + loader”两件套，负责模板校验、坐标映射和运行时城市数组构建；`domain` 不新增场景树依赖。随机地图生成器保留，不与预设地图逻辑硬混写。

**Tech Stack:** Godot 4.6、GDScript、现有 `tests/test_runner.gd`、Markdown 文档

---

## File Structure

- Create: `scripts/application/prototype_preset_map_definition.gd`
  - 第一张预设地图的静态定义，包括 design canvas、城市定义、道路、按方数划分的出生配置
- Create: `scripts/application/prototype_preset_map_loader.gd`
  - 负责模板校验、坐标映射、出生配置应用，并输出 `PrototypeCityState` 数组
- Modify: `scripts/presentation/prototype_main_game.gd`
  - 开局时改为走统一地图来源入口，Phase 1 里写死使用第一张预设地图
- Modify: `tests/test_runner.gd`
  - 增加预设地图 loader、出生配置、入口链路相关测试
- Modify: `readme.md`
  - 同步说明“当前第一阶段使用预设地图开局，但仍保留总方数配置”
- Modify: `docs/technical.md`
  - 同步运行时数据流和地图来源说明
- Modify: `docs/architecture.md`
  - 同步新增的 application 层单元职责
- Optional Modify: `docs/gameplay.md`
  - 如果玩法说明涉及地图来源变化，则同步更新

## Chunk 1: Loader Contract & Red Tests

### Task 1: 为预设地图 loader 先写失败测试

**Files:**
- Modify: `tests/test_runner.gd`
- Inspect: `scripts/domain/prototype_city_state.gd`
- Inspect: `scripts/application/prototype_map_generator.gd`

- [ ] **Step 1: 新增预设地图 loader preload**

在 `tests/test_runner.gd` 顶部加入：

```gdscript
const PrototypePresetMapLoaderRef = preload("res://scripts/application/prototype_preset_map_loader.gd")
const PrototypePresetMapDefinitionRef = preload("res://scripts/application/prototype_preset_map_definition.gd")
```

- [ ] **Step 2: 注册新的失败测试入口**

新增并注册这些测试名：

- `preset_map_loader_builds_cities`
- `preset_map_spawn_sets_cover_supported_faction_counts`
- `preset_map_is_connected`
- `project_main_scene_still_prototype_main`

- [ ] **Step 3: 写 `preset_map_loader_builds_cities` 失败测试**

断言：

- loader 能返回非空城市数组
- 城市数落在 `12..18`
- 每个元素都是可用的运行时城市状态

- [ ] **Step 4: 写 `preset_map_spawn_sets_cover_supported_faction_counts` 失败测试**

断言：

- `2/3/4/5` 方都存在出生配置
- 每种配置都有 1 个玩家出生点
- AI 出生点数量等于 `总方数 - 1`
- 同一配置里没有重复城市

- [ ] **Step 5: 写 `preset_map_is_connected` 失败测试**

断言：

- loader 构建出的地图从任意起点能遍历到所有城市

- [ ] **Step 6: 写 `project_main_scene_still_prototype_main` 失败测试**

断言：

- `project.godot` 中的 `run/main_scene` 仍然是 `res://scenes/main/prototype_main.tscn`

- [ ] **Step 7: 运行完整测试集，确认出现 RED**

Run:

```bash
HOME=/tmp XDG_DATA_HOME=/tmp godot --headless --path . -s res://tests/test_runner.gd
```

Expected:

- 因 loader/definition 文件尚不存在而失败

## Chunk 2: Preset Map Definition & Loader

### Task 2: 实现第一张预设地图定义

**Files:**
- Create: `scripts/application/prototype_preset_map_definition.gd`

- [ ] **Step 1: 创建 design canvas 常量和地图元信息**

至少定义：

- 地图 ID
- 地图名称
- 设计画布尺寸
- 支持方数 `[2, 3, 4, 5]`

- [ ] **Step 2: 定义 12 到 18 座城市的静态数据**

每座城市至少包含：

- `id`
- `name`
- `position`
- `initial_soldiers`
- `level`
- `defense`
- `production_rate`

- [ ] **Step 3: 定义道路连线**

要求：

- 所有连线只引用已有城市
- 邻接关系可双向推导
- 整体地图结构满足“中路 + 两翼 + 瓶颈 + 后方”

- [ ] **Step 4: 定义 `spawn_sets_by_faction_count`**

至少包含：

- `2`
- `3`
- `4`
- `5`

每种配置明确：

- `player_city_id`
- `ai_city_ids`

- [ ] **Step 5: 为文件内公开函数补函数头注释**

说明：

- 功能
- 调用场景
- 主要逻辑

### Task 3: 实现预设地图 loader

**Files:**
- Create: `scripts/application/prototype_preset_map_loader.gd`
- Inspect: `scripts/domain/prototype_city_owner.gd`
- Inspect: `scripts/domain/prototype_city_state.gd`

- [ ] **Step 1: 定义最小公开接口**

实现统一入口：

```gdscript
func build_map(match_config: Dictionary, map_world_size: Vector2, random: RandomNumberGenerator) -> Array:
```

- [ ] **Step 2: 实现 design canvas 到 `map_world_size` 的坐标映射**

要求：

- 输入模板设计坐标
- 输出当前运行时世界坐标
- 保持映射逻辑可测试

- [ ] **Step 3: 实现模板校验**

至少校验：

- 城市 ID 唯一
- 连线引用合法
- 出生配置覆盖 `2..5`
- 出生城市不重复
- 地图连通

- [ ] **Step 4: 实现按总方数应用出生配置**

规则：

- 玩家出生城归玩家
- `ai_city_ids` 依序归不同 AI 阵营
- 其余城市归中立

- [ ] **Step 5: 把模板数据转换成 `PrototypeCityState` 数组**

要求：

- 邻接关系完整
- 属性直接复用现有城市状态模型
- 不引入场景树依赖

- [ ] **Step 6: 为所有公开函数补函数头注释**

### Task 4: 运行测试转绿

**Files:**
- Verify: `tests/test_runner.gd`
- Verify: `scripts/application/prototype_preset_map_definition.gd`
- Verify: `scripts/application/prototype_preset_map_loader.gd`

- [ ] **Step 1: 运行完整测试集**

Run:

```bash
HOME=/tmp XDG_DATA_HOME=/tmp godot --headless --path . -s res://tests/test_runner.gd
```

Expected:

- 预设地图相关测试转绿
- 原有规则测试继续通过

## Chunk 3: Main Flow Integration

### Task 5: 把主场景切到第一阶段预设地图来源

**Files:**
- Modify: `scripts/presentation/prototype_main_game.gd`
- Inspect: `scripts/application/prototype_map_generator.gd`

- [ ] **Step 1: 引入 loader preload**

在 `prototype_main_game.gd` 中新增：

```gdscript
const PrototypePresetMapLoaderRef = preload("res://scripts/application/prototype_preset_map_loader.gd")
```

- [ ] **Step 2: 新增 loader 实例字段**

保持与现有 service 风格一致。

- [ ] **Step 3: 把 `_start_new_match()` 中的地图构建逻辑改成统一入口**

Phase 1 行为：

- 当前局写死使用第一张预设图
- 仍消费 `_player_count`
- 不改开始面板 UI

- [ ] **Step 4: 保持 `_map_world_size`、拖拽、HUD、城市视图装配流程不变**

要求：

- 后续 `_spawn_city_views()`、`_center_map_offset()`、行军单位逻辑继续复用

- [ ] **Step 5: 补必要的状态文案或注释**

仅在有必要让后续维护者理解地图来源变化时添加。

### Task 6: 运行完整测试并做主场景启动验证

**Files:**
- Verify: `scripts/presentation/prototype_main_game.gd`
- Verify: `scenes/main/prototype_main.tscn`

- [ ] **Step 1: 运行完整 headless 测试**

Run:

```bash
HOME=/tmp XDG_DATA_HOME=/tmp godot --headless --path . -s res://tests/test_runner.gd
```

Expected:

- `ALL TESTS PASSED`

- [ ] **Step 2: 启动主场景做最小运行验证**

验证点：

- 能进入第一张预设图
- `2/3/4/5` 方切换后出生点发生变化
- 城市、道路、HUD、拖拽、出兵面板可正常工作

## Chunk 4: Docs Sync & Final Verification

### Task 7: 同步文档

**Files:**
- Modify: `readme.md`
- Modify: `docs/technical.md`
- Modify: `docs/architecture.md`
- Optional Modify: `docs/gameplay.md`

- [ ] **Step 1: 更新 README 的运行与玩法说明**

补充：

- 第一阶段预设地图已接入
- 总方数选择仍保留
- 当前第一张图是中国风抽象战略图

- [ ] **Step 2: 更新 technical 文档**

补充：

- 预设地图 loader
- design canvas 坐标映射
- 当前主流程的数据来源变化

- [ ] **Step 3: 更新 architecture 文档**

补充：

- `prototype_preset_map_definition.gd`
- `prototype_preset_map_loader.gd`

- [ ] **Step 4: 如玩法描述受影响，再更新 gameplay 文档**

仅在文档已经涉及地图来源或开局结构时修改，避免噪音。

### Task 8: 最终验证与交付

**Files:**
- Verify: `tests/test_runner.gd`
- Verify: `project.godot`
- Verify: `scripts/application/prototype_preset_map_definition.gd`
- Verify: `scripts/application/prototype_preset_map_loader.gd`
- Verify: `scripts/presentation/prototype_main_game.gd`

- [ ] **Step 1: 再跑一次仓库权威测试命令**

Run:

```bash
HOME=/tmp XDG_DATA_HOME=/tmp godot --headless --path . -s res://tests/test_runner.gd
```

Expected:

- `ALL TESTS PASSED`

- [ ] **Step 2: 手工核对 Phase 1 验收约束**

检查：

- 默认 `5` 方局是否较早形成中路接触
- 城市标签是否在常见竖屏视口下严重重叠
- AI 是否能按现有节奏完成首次扩张

- [ ] **Step 3: 准备交付说明**

说明中至少包含：

- 新增的两个 application 文件
- 预设地图接入方式
- 保留的现有能力（总方数选择、主循环规则）
- 测试命令与结果

