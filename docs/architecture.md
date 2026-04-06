# Architecture

## 当前生效实现

当前原型运行在 `prototype_*` 这一套实现上：

- 主场景：`scenes/main/prototype_main.tscn`
- 主控制器入口壳：`scripts/presentation/prototype_main_game.gd`（场景仍引用该脚本）
- 城市视图：`scripts/presentation/prototype_city_view.gd`

### 主控制器拆分（presentation 内部分层）

为控制单文件体积与职责清晰度，主控制器采用继承链拆分（过渡期方案，后续仍可继续模块化）：

- `prototype_main_game.gd`
  - 仅负责 `extends "res://scripts/presentation/prototype_main_game_layer_a.gd"`，保持场景引用路径稳定
- `prototype_main_game_layer_a.gd`
  - 主要负责 `_ready()` 装配：Camera/GameState/March/Input 等模块的 setup 与接线
- `prototype_main_game_layer_b.gd`
  - 主流程与 UI 编排：开局/暂停/结束、HUD 刷新、按钮回调、对局推进等
- `prototype_main_game_layer_c.gd`
  - 共享基础：常量、节点引用、工具函数、少量供模块注入的 getter/setter
- `prototype_main_input_handler.gd`
  - 输入子系统：拖拽/缩放手势状态机、`unhandled release -> 取消选城` 语义与 guard 去抖

## 分层

### `scripts/domain/`

- `prototype_city_owner.gd`
  - 阵营定义、阵营颜色、阵营名称
- `prototype_city_state.gd`
  - 城市运行时状态、邻接关系、防御、产能、人口上限、产兵条件、升级成本与升级应用

### `scripts/application/`

- `prototype_map_generator.gd`
  - 随机地图、道路连通性、开局总方数分配、城市命名
- `prototype_preset_map_definition.gd`
  - 第一张中国风预设地图的 design canvas、城市、道路与按方数划分的出生配置
- `prototype_preset_map_loader.gd`
  - 校验预设地图模板、映射设计坐标到运行时世界坐标，并生成 `PrototypeCityState` 数组
- `prototype_battle_service.gd`
  - 出兵准备、攻城结算、运兵结算、路上遭遇战、按产能产兵、防御参与攻城、城市升级、胜负判断
- `prototype_enemy_ai_service.gd`
  - 多电脑势力的目标选择、难度、风格和行动节奏

### `scripts/presentation/`

- `prototype_main_game.gd` + `prototype_main_game_layer_*.gd`
  - 主循环、HUD、说明面板、暂停、坐标转换、道路绘制、行军单位、升级按钮和状态提示等表现层编排
- `prototype_main_input_handler.gd`
  - 地图拖拽、缩放、输入 guard 与空白取消选城语义（通过 `Callable` 注入与主控制器解耦）
- `prototype_city_view.gd`
  - 城市图标绘制、标签布局、点击区域、点击与拖拽判定分离；城市 marker 默认短文本，emoji 仅在显式开关打开时启用

## 依赖方向

- `presentation -> application -> domain`
- `domain` 不依赖 Godot 场景树
- `application` 只依赖领域对象，不直接依赖具体场景节点
- 地图平移边界、世界坐标与屏幕坐标转换只允许留在 `presentation`

## 当前主场景结构

- `Cities`
  - 运行时挂载所有城市视图实例
- `UILayer`
  - 顶部状态条与底部操作栏
- `Overlay`
  - 开始与结束面板
- `OrderDialog`
  - 玩家出兵数量选择
- `Cities`
  - 运行时通过 `scenes/world/city.tscn` 直接实例化城池节点

## 关键设计取舍

- 核心规则尽量沉到服务层，方便 headless 测试
- 地图始终保证连通，避免不可达孤岛
- 当前第一阶段默认从预设地图 loader 开局，而不是直接走随机地图生成器；随机地图生成器保留，供后续并存扩展
- 多方混战采用统一阵营编号模型，而不是写死“玩家 vs 单敌军”
- 暂停和出兵面板只冻结时间推进，不重置战局状态
- 城市 UI 采用符号化绘制，避免依赖外部美术资源也能快速迭代
- 战场背景继续保持 canvas 直接绘制，不拆独立背景节点；背景装饰只做低对比的 deterministic 叠加，避免出现像可交互对象或障碍的封闭高对比图形

## 工程交付

- GitHub Actions 负责调用 Godot 的 Web 导出流程，并将静态产物发布到 GitHub Pages。
- 这套自动化只属于仓库交付层，不改变运行时的 `presentation -> application -> domain` 依赖方向。
- 中文字体文件 `assets/fonts/NotoSansSC-Regular.otf` 属于表现层支撑资源；`export_presets.cfg` 和 `.github/workflows/deploy-web.yml` 属于工程配置。

## 演进计划（以可维护性为核心）

本仓库后续会扩展更多功能（城市升级外观、地形影响行军、更多 UI 与交互）。为降低主控制器复杂度、减少场景路径脆弱性，并提升可并行迭代能力，采用如下“渐进式场景化 + 规则服务化”的演进路线。

### 总原则

- 规则仍保持 `domain/application` 的 `RefCounted` 纯逻辑（可 headless 测试），不要把结算与规则塞进 Node/场景。
- 场景化主要作用于 `presentation`：UI 组件、可视实体、地形表现与交互对象。
- 从“组合（composition）”逐步替代“继承分层（layer_a/b/c）”的职责扩张：主控制器逐步变薄，只做装配与编排。
- 每一步改动都必须维持当前唯一运行链：`scenes/main/prototype_main.tscn` 仍引用 `scripts/presentation/prototype_main_game.gd`。
- 每次改动后至少运行核心规则 headless 测试，并对主场景做最小手工验收。

### 阶段 1：UI 子场景化（优先级最高）

目标：减少 `$OrderDialog/Panel/...` 这类深路径引用，使 UI 可独立迭代与重构。

- 拆分 `OrderDialog` 为独立子场景（推荐形态：`scenes/ui/order_dialog.tscn`）
  - 子场景对外提供明确 API（例如 `open(context)`）并发出信号（例如 `confirmed/cancelled`）
  - 主控制器只负责订阅信号、调用 application 服务、刷新状态
- 拆分顶部状态条（推荐形态：`scenes/ui/status_bar.tscn`）
  - 状态条只负责展示（当前提示、AI 配置摘要、观测数据等），不持有规则

验收与验证：

- 运行：在 Godot 中启动 `scenes/main/prototype_main.tscn`
- 测试：`HOME=/tmp XDG_DATA_HOME=/tmp godot --headless --path . -s res://tests/test_runner.gd`

### 阶段 2：城市表现彻底场景化（为“升级改变外观”做准备）

目标：让城市外观与交互可独立迭代，不影响主控制器与规则层。

- 将城市视图演进为独立场景（推荐形态：`scenes/world/city_view.tscn`）
  - `PrototypeCityState`（domain）仍是唯一城市规则数据源
  - `CityView`（presentation）只根据 `city.owner/level/node_type` 等渲染外观与输入
- 城市升级的“属性变化”仍由 `application/domain` 驱动；城市升级的“外观变化”由 `CityView` 响应刷新。

### 阶段 3：地形系统（先数据可测，后表现可视）

目标：支持森林/山区等地形影响行军速度，且不让规则依赖节点树。

- 先引入地形数据与查询接口（建议使用 `Resource` 或纯数据对象）
  - 规则侧：行军时间/速度系数计算放在 `scripts/application/`（例如 TravelTime/March 相关服务）
- 再引入地形表现层子场景（例如 `scenes/world/terrain_layer.tscn`）
  - presentation 负责显示与交互（如 debug 可视化），不承载结算

### 阶段 4：行军单位（当需要更复杂表现时再场景化）

当前行军表现使用主场景 `_draw()` 直绘，轻量且性能友好；当出现以下需求时再考虑场景化：

- 需要动画/特效/命中反馈/点击选择
- 需要不同兵种或地形穿越效果（例如进森林减速、进山区更慢）

推荐形态：`scenes/world/march_unit.tscn`（presentation），其速度/路径由 application 的计算结果驱动。

### 备注：右侧“持续任务 HUD”

若右侧持续任务 HUD 在后续设计中确认不再使用，可在 UI 子场景化完成后再进行清理；清理前建议先保持隐藏/不创建，避免与重构交织导致回归成本上升。
