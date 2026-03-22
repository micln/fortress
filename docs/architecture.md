# Architecture

## 当前生效实现

当前原型运行在 `prototype_*` 这一套实现上：

- 主场景：`scenes/main/prototype_main.tscn`
- 主控制器：`scripts/presentation/prototype_main_game.gd`
- 城市视图：`scripts/presentation/prototype_city_view.gd`

旧的非 `prototype_` 文件保留在仓库中，但不是当前原型入口。

## 分层

### `scripts/domain/`

- `prototype_city_owner.gd`
  - 阵营定义、阵营颜色、阵营名称
- `prototype_city_state.gd`
  - 城市运行时状态、邻接关系、人口上限、产兵条件

### `scripts/application/`

- `prototype_map_generator.gd`
  - 随机地图、道路连通性、开局总方数分配、城市命名
- `prototype_battle_service.gd`
  - 出兵准备、攻城结算、运兵结算、路上遭遇战、产兵推进、胜负判断
- `prototype_enemy_ai_service.gd`
  - 多电脑势力的目标选择、难度、风格和行动节奏

### `scripts/presentation/`

- `prototype_main_game.gd`
  - 主循环、HUD、说明面板、暂停、道路绘制、行军单位、输入和状态提示
- `prototype_city_view.gd`
  - 城市图标绘制、标签布局、点击区域

## 依赖方向

- `presentation -> application -> domain`
- `domain` 不依赖 Godot 场景树
- `application` 只依赖领域对象，不直接依赖具体场景节点

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
- 多方混战采用统一阵营编号模型，而不是写死“玩家 vs 单敌军”
- 暂停和出兵面板只冻结时间推进，不重置战局状态
- 城市 UI 采用符号化绘制，避免依赖外部美术资源也能快速迭代
