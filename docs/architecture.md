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
- `CityTemplate`
  - 城市节点模板，由主场景复制

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
