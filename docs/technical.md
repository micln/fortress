# 技术文档

## 当前运行入口

- 主场景：`scenes/main/main.tscn`
- 主控制脚本入口壳：`scenes/main/main.gd`
- 主控制器拆分（presentation 内部分层）：
  - `scenes/main/main_bootstrap.gd`：装配/初始化（_ready 接线）
  - `scenes/main/main_flow.gd`：主流程与 UI 编排
  - `scenes/main/main_context.gd`：共享基础与工具
  - `scripts/presentation/main_input_handler.gd`：输入/手势与取消选城语义
- 当前运行入口集中在 `main.*` 主场景链路（场景同目录脚本）与 `scripts/` 可复用模块
- 当前第一阶段默认地图来源为预设地图 loader；随机地图生成器仍保留在仓库中，但不再作为默认开局路径

## 窗口与分辨率策略

- 项目不使用固定逻辑分辨率作为运行时前提。
- 桌面端（非 Web、非移动平台）启动时会优先切到窗口最大化，减少窗口尺寸对首屏可视区域的影响。
- `scenes/main/main.gd` 启动时会读取当前窗口尺寸，并写入 `Window.content_scale_size` 作为内容分辨率。
- Web 平台仅在触屏设备上才会用 `DisplayServer.screen_get_scale()` 把窗口像素尺寸换算成逻辑尺寸，避免高 DPI 手机上 UI 与字体被额外缩小；桌面端保持像素尺寸以避免黑边。
- 当窗口尺寸变化时（`size_changed` 与 `NOTIFICATION_WM_SIZE_CHANGED`），会再次同步 `content_scale_size`，实现动态分辨率。
- `scenes/main/main.gd` 会按当前运行环境使用不同地图尺度参数：移动端（触屏）默认把地图世界拉得更开，桌面端默认更紧凑；同时开局镜头会轻微偏向玩家出生城，把主城尽量落在顶部 HUD 下方的安全区里。
- 当窗口尺寸变化时，`scenes/main/main.gd` 会按当前视口重新计算目标地图世界尺寸，并以“只扩不缩”的方式扩展 `_map_world_size`，保证背景覆盖范围始终大于可视区，避免窗口变大后出现黑边。
- 项目保持 `canvas_items + expand + fractional` 的拉伸策略，保证不同窗口宽高变化时画面可连续自适应。
- `Overlay` 说明层使用锚点比例布局和最小尺寸约束，窗口变化时会同步调整位置与大小。
- 顶部状态栏与底部操作栏会在窄屏下切换为更激进的移动端 HUD：顶部几乎贴边，只保留核心状态与精简后的对局摘要；底部则压成三枚小按钮，优先把战场可视面积让给地图。
- 底部操作栏会在窄屏下切换为移动端布局：缩小左右边距与按钮最小宽度，并把“取消选择”“重新开始”缩成短文案，避免挡住主战场。
- 开局 `Overlay` 说明弹窗会在窄屏下切换为移动端布局：取消固定最小宽度、缩小内边距、把设置区域改成单列，并同步下调字号避免横向裁切。
- 开局 `Overlay` 的说明内容放入 `ScrollContainer`，底部“开始游戏”按钮固定在滚动区外，避免窄屏或矮屏设备上按钮被内容挤出可视区域。
- 右侧持续任务 HUD 在运行时动态挂到 `UILayer` 下，和顶部/底部 HUD 同层常驻，不进入 `Overlay` 这类暂停遮罩链。
- 战场点按与空白取消共用同一套输入流时，必须防止“城市点击”和“空白取消”在同一次触摸抬起上重复消费；当前实现会在城市选中后保留一个极短的取消保护窗口，吞掉紧随其后的抬起事件，避免手机首点立刻被清空。
- 城市节点在触屏设备上会直接忽略兼容鼠标事件，只保留 `ScreenTouch` 路径；这是因为部分移动端浏览器会在一次真实触摸后再补发一套 `mouse` 事件，导致同一城市被点两次。
- 选城后的取消保护窗口只覆盖同一次选城手势的后续 release；一旦用户开始下一次新的 touch/mouse 按下，就会立即清空保护窗口，避免空白区域还要再点第二次才能取消选择。

## Web 导出与发布

- Web 发布使用 `export_presets.cfg` 中的 `Web` preset，导出目标为 `build/web/index.html`。
- 仓库在 `master` 分支推送后，会通过 `.github/workflows/deploy-web.yml` 执行 headless 导出，并将产物部署到 GitHub Pages。
- CI 需要先执行资源导入，再执行 Web 导出，避免新字体资源在无缓存环境中缺失导入数据。

## 关键模块

### 领域层

- `scripts/domain/city_owner.gd`
  - 阵营编号、颜色映射、阵营名称
- `scripts/domain/city_state.gd`
  - 城市状态、防御、产能、人口上限、产兵判断、升级成本与升级应用；当前产能升级步长为 `+4.0`，上限为 `30.0/秒`

### 应用层

- `scripts/application/map_generator.gd`
  - 地图生成、道路连通、开局势力分配、城市命名
- `scripts/application/preset_map_definition.gd`
  - 第一张中国风抽象战略图的 design canvas、城市静态数据、道路与 `2` 至 `5` 方出生配置
- `scripts/application/preset_map_loader.gd`
  - 校验预设地图定义、按 design canvas 映射运行时坐标、应用当前方数出生配置并输出城市数组
- `scripts/application/battle_service.gd`
  - 出兵准备、到城结算、运兵失守重战、路上遭遇战、按产能产兵、城市升级、胜负判断
- `scripts/application/enemy_ai_service.gd`
  - 电脑势力的难度/风格配置、回合间隔、持续路线目标选择和升级兜底
- `scripts/application/order_dispatch_service.gd`
  - 持续出兵任务注册/切换、按源城轮转调度、来源失守清理、HUD 快照输出

## 电脑 AI 参数表

`enemy_ai_service.gd` 当前采用一套统一的候选目标评分框架，再叠加“难度”和“风格”参数，形成不同电脑势力的行为差异。

| 难度维度 | 简单 | 普通 | 困难 |
| --- | --- | --- | --- |
| 行动间隔基础值 | 5.0 秒 | 4.0 秒 | 3.0 秒 |
| 允许进攻的最小优势 | 比守军多 40 人 | 比守军多 20 人 | 比守军多 10 人 |
| 推荐兵力附加值 | +0 | +1 | +3 |
| 评分难度修正 | -0.4 | +0.0 | +0.6 |

| 风格维度 | 进攻型 | 防御型 |
| --- | --- | --- |
| 行动间隔风格修正 | -0.4 秒 | +0.4 秒 |
| 源城最少留守兵力 | 1 | 3 |
| 推荐兵力附加值 | +1 | +0 |
| 路程惩罚系数 | 0.3 | 0.8 |
| 目标是玩家城时加分 | +1.2 | +0.5 |
| 目标是非己方的其他城市时加分 | +0.9 | +1.2 |

补充说明：

- 进攻型会更快出手、更愿意压兵，也会略微偏好攻击玩家城市，但不会在多人局里固定只围攻玩家。
- 防御型更强调近距离扩张和后方留守，因此更容易先吃下附近的中立城或其他电脑势力城市。
- 实际是否出兵，还会同时受 `BattleService.get_recommended_attack_count()`、目标防御值、目标产兵速度和行军距离共同影响。

### 表现层

- `scenes/main/main.gd`
  - 主循环、输入路由、HUD、地图拖拽、世界/屏幕坐标转换、暂停、空白点击取消、城市升级按钮、行军单位、持续出兵调度、背景绘制、说明/结束面板
- `scripts/presentation/city_view.gd`
  - 城市图标绘制、城市标签、点击区域、点击与拖拽手势区分

背景与 marker 的当前实现约束：

- 战场背景只在 `scenes/main/main.gd` 的 `_draw()` 中直接绘制，不新增独立背景节点；渲染顺序固定为主草地底层、不规则土地色块、分段草纹、极轻氛围块，始终压在道路、城市和行军单位之下。
- 背景装饰层的单层 alpha 不超过 `0.22`，并且 patch/stripe 数据全部基于世界坐标和确定性常量，禁止在 `_draw()` 内随机生成或每帧抖动。
- 背景不能使用高对比的封闭图形，避免被误认成可交互节点或障碍。
- 城市 marker 默认使用短文本（`城/关/枢/腹`），emoji 只在显式开关打开时启用；这是为了规避当前字体链路下默认 emoji 的缺字风险。
- emoji 显式开关支持 `ProjectSettings` 键 `fortress_war/ui/use_marker_emoji`，或环境变量 `FORTRESS_WAR_USE_MARKER_EMOJI=1`。

## 运行时数据流

1. `scenes/main/main.gd` 在开局时调用 `preset_map_loader.gd` 生成城市数组
2. 城市数组被复制成若干 `CityView` 节点，负责显示和点击
3. 玩家或电脑下令后，主场景创建行军单位字典并逐帧推进
4. 路上若发生不同势力接触，调用 `BattleService.resolve_marching_encounter()`
5. 到达目标城市后，调用 `resolve_attack_arrival()` 或 `resolve_transfer_arrival()`
6. 每秒按各城市产能推进占领城市产兵，并在源城新增士兵时按“每产 1 兵调度 1 次、每次派出 10 人”触发持续任务
7. 每轮推进后通过 `get_winner()` 判断是否只剩一个非中立势力
8. 玩家点 `A -> B` 或 AI 决策出一条 `A -> B` 时，会把路线注册到 `OrderDispatchService`
9. 当源城新增士兵时，主循环会立刻按当前目标归属动态选择进攻或运兵并自动派 10 人；这里的新增既包括本地产兵，也包括友军运兵抵达
10. 若同一源城持有多条路线，调度器会按轮转顺序逐条触发
11. 若源城失守，主场景会清空该源城发出的全部持续任务；目标换手不会删除路线，只会改变本次派兵类型
12. 友军运兵到达同阵营城市时，`transfer_arrival_service.gd` 会按“逐兵到达 -> 逐兵触发调度”的顺序处理；若城市已满员，则把该名到达士兵先当作一次临时可转运兵力，只有调度失败时才记为溢出

## 预设地图与坐标映射

- 第一阶段预设地图使用固定 design canvas 坐标，而不是直接把最终世界坐标写死在模板里。
- `preset_map_loader.gd` 会按当前 `_map_world_size` 把 design canvas 坐标映射到运行时世界坐标，保证同一张地图模板可适配当前大地图尺寸。
- loader 在真正生成 `CityState` 之前，会校验映射后的城市坐标是否越界，以及城市之间是否低于最小安全间距；该间距阈值会随 design canvas 到运行时世界尺寸的缩放比例同步换算，避免小地图尺寸下误判严重重叠。
- 第一张预设地图定义了 `2` 至 `5` 方的出生配置，主场景继续复用当前开始面板中的总方数选择。
- 未被当前方数使用的出生城会在该局中回落为中立城市，避免第一阶段为了预设地图破坏现有开局 UI。
- 若模板校验失败，loader 会记录最近一次错误信息；主场景不会静默继续空地图，而是直接显示装载失败提示。
- 预设地图城市现已支持 `node_type` 字段，第一版包含 `normal / pass / hub / heartland` 四类；loader 会在装配 `CityState` 时保留该字段。
- 第一版静态战略节点效果为：`pass -> defense +1`、`hub -> production_rate +0.2`、`heartland -> initial_soldiers +2`。
- 表现层只负责展示最小节点提示：城市属性行会追加“关口 / 枢纽 / 腹地”标签，玩家首次选中己方战略节点时，顶部提示会补充一条简短策略说明。

## 大地图与输入实现

- `map_generator.gd` 生成的是地图世界坐标，不再假设坐标一定落在单屏视口内。
- `preset_map_loader.gd` 输出的预设地图坐标也会落在同一套地图世界坐标系内，因此后续拖拽、点击命中和道路绘制逻辑无需重写。
- 当前地图变换（offset/zoom）由 `CameraController` 维护，主控制器通过 `world_to_screen/screen_to_world` 统一换算。
- 拖拽/缩放手势状态机由 `MainInputHandler` 维护，通过 `Callable` 注入调用 `get_map_offset/set_map_offset/get_map_zoom/set_map_zoom`，避免输入模块直接依赖具体 UI 或节点树结构。
- 城市节点、道路、行军单位、浮动升级条都必须经过同一套偏移换算，避免拖拽后表现错位。
- HUD、说明遮罩和右侧任务面板仍固定在 `CanvasLayer`，不随地图拖动。
- 鼠标左键拖拽与单指拖动共用同一套阈值判定：按下先记录，移动超过阈值才视为拖拽；否则保留点击语义。
- 桌面端滚轮可按鼠标位置缩放地图；触屏端双指缩放以双指中心为锚点，缩放时会自动打断单指拖拽候选，避免手势冲突。
 - 空白释放取消选城逻辑在 `MainInputHandler.handle_unhandled_input()` 中统一处理：先用 guard 去抖吞掉“选城后紧随其后的 release”，再按 `should_ignore_selection_cancel()` 做 hit-test，最后才触发 `clear_selection_with_message()`。

## 重要实现约束

- 核心规则尽量放在可测试的纯逻辑服务和状态对象中
- 表现层负责显示、输入与场景编排，不直接写战斗规则
- 地图浏览、边界钳制、坐标换算属于表现层职责，不进入 `application` 与 `domain`
- 出兵预判和真实到达结算允许不一致，因为路上可能发生产兵、增援和遭遇战
- 城市防御和产能属于领域属性，必须由 `city_state.gd` 持有，并由服务层消费
- 暂停不应改变地图状态，只停止时间推进与电脑行动
- 文档变更必须和当前生效实现同步
- Web 平台不能依赖宿主系统一定提供中文字体，项目必须显式携带覆盖中文字符集的字体资源
- `scenes/main/main.gd` 与场景 `LabelSettings` 统一使用 `assets/fonts/NotoSansSC-Regular.otf`，避免 Web 版中文缺字

## 关键规则现状

- 总方数配置 = `1` 个玩家 + `N-1` 个电脑势力
- 玩家运兵允许跨图；进攻必须相邻
- 当前主流程默认只支持持续出兵；一次性出兵仅保留占位接口，尚未接入运行链
- 路上不同势力部队相遇会先战斗
- 失守后的迟到援军会重新与守军作战，而不是直接被收编
- 当地图上只剩一个非中立势力时结束对局
- 进攻型 AI 会主动压迫玩家，但多人局里仍会争夺其他电脑势力和中立城市，不会只盯着玩家打
- AI 与玩家现在共用同一套持续出兵任务调度规则

## 测试入口

- `tests/test_runner.gd`
- 推荐命令：

```bash
HOME=/tmp XDG_DATA_HOME=/tmp godot --headless --path . -s res://tests/test_runner.gd
```
- Web 冒烟检查命令：

```bash
scripts/tools/web_smoke_check.sh
```

手工验收重点：

- 背景四层是否仍然位于道路、城市和行军单位之下
- 装饰层是否保持低对比，并且单层 alpha 不超过 `0.22`
- 是否存在会被误认成可交互节点或障碍的高对比封闭图形
- 城市 marker 是否默认短文本、emoji 是否只在显式开关下开启
- 若要抽检 emoji 路径，是否已开启 `fortress_war/ui/use_marker_emoji` 或 `FORTRESS_WAR_USE_MARKER_EMOJI=1`
