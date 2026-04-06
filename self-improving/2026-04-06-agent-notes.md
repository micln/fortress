# 2026-04-06 Agent Notes

## 错误复盘 1：主场景拆分后引入解析错误

- 任务背景：将 `scripts/presentation/prototype_main_game.gd` 从 2700+ 行拆分到多个文件，目标是单文件不超过 1500 行。
- 错误现象：用户本地启动 Godot 后出现 `Could not preload resource script`、`Parse Error`、`Function not found` 等错误，主场景脚本无法加载。
- 根因分析：
  1. 采用“按行号剪切 + 代理转发”的方式拆分，未做语义级校验，导致新文件出现函数截断、重复/缺失函数。
  2. 新控制器中直接引用原脚本常量/成员，未完整处理作用域，导致解析阶段失败。
  3. 拆分后未先做最小可运行验证（至少保证脚本可被 Godot 成功解析）就交付。
- 正确做法：
  1. 先保证“可解析”再追求“职责拆分”：优先采用继承层拆分（按函数边界），避免跨文件变量代理。
  2. 每次拆分后立即运行 `Godot --headless` 做语法/加载验证，再继续下一步。
  3. 对切分点采用“函数边界 + 自动检查重复/缺失函数”策略，不按裸行号盲切。
- 防再犯措施：
  1. 以后对大文件重构固定三步：`边界设计 -> 机械拆分 -> 立即运行解析验证`。
  2. 拆分后执行 `rg '^func ' ... | sort | uniq -d` 检查重复定义，并人工检查关键入口函数是否都存在。
  3. 如果首次拆分出现解析级错误，先回滚到可运行基线，再采用更保守方案继续。

## 新技能 1：Godot 大脚本安全降行方案（继承分层）

- 来源：本次重构失败后的修复实践。
- 适用场景：GDScript 单文件过大，且短期不适合做高风险跨对象重构时。
- 关键做法：
  1. 保留原脚本完整内容为基线。
  2. 按函数边界拆成多层：`main -> layer1 -> layer2 -> layer3`。
  3. 仅改 `extends` 链路，不改函数逻辑与变量作用域。
  4. 确保每个层文件都低于行数阈值。
- 可复用示例：
  - `prototype_main_game.gd` 只保留：`extends "res://scripts/presentation/prototype_main_game_layer1.gd"`
  - `prototype_main_game_layer1.gd`：`extends "...layer2.gd"` + 后半段函数
  - `prototype_main_game_layer2.gd`：`extends "...layer3.gd"` + 中段函数
  - `prototype_main_game_layer3.gd`：`extends Node2D` + 常量/成员/前半段函数

## 错误复盘 2：继承分层方向设计错误导致类解析失败

- 任务背景：为快速止损，尝试使用 `layer1 -> layer2 -> layer3` 继承链压缩单文件行数。
- 错误现象：点击开始游戏报 `Could not resolve class "...layer1.gd"`。
- 根因分析：上层脚本调用了只在子层定义的方法，GDScript 在解析期要求方法可在当前类或基类解析，导致继承链加载失败。
- 正确做法：
  1. 继承分层必须先做依赖拓扑，保证“调用方向只向基类”。
  2. 若无法满足依赖方向，不能硬切继承链，应改为小步函数外提并逐步验证。
- 防再犯措施：
  1. 拆分前先跑“方法依赖扫描”，确认每段调用只依赖同段或基段。
  2. 每次改完先用 `Godot --headless --path . <scene>` 做场景解析验证，再进入下一步。

## 新技能 2：用 InputHandler 逐步外提输入逻辑（避免解析期未声明标识符）

- 来源：本次对 `prototype_main_game` 的第二阶段重构。
- 适用场景：需要把 `_input/_unhandled_input` 从巨大主脚本里外提，但又不想一次性搬迁大量状态字段。
- 关键做法：
  - 新增 `RefCounted` 的输入处理器，内部只保存 `_host`。
  - 输入处理器使用 `_host.get("...")` 读取状态、`_host.call("...")` 调用主脚本已有函数。
  - 先把 `_input/_unhandled_input` 变成薄委托，确认 headless 场景加载成功后，再逐步迁移 helper 函数与状态字段。
- 可复用示例：
  - `scripts/presentation/prototype_main_input_handler.gd`：`handle_input/handle_unhandled_input`。
  - 主脚本中 `_input(event)` 仅保留：`_input_handler.handle_input(event)`。

## 新技能 3：用 Callables 注入替代 host.get/call 反射

- 来源：按 `godot-best-practices` 对输入模块重构的改进。
- 适用场景：想把逻辑外提到 `RefCounted`/Service，但又需要访问主场景状态与回调。
- 关键做法：
  - 在模块 `setup(...)` 里注入：状态读取（例如 `is_game_started`）与行为回调（例如 `handle_touch_drag_input`）的 `Callable`。
  - 模块内部只依赖这些 Callables；主场景重命名函数时会在接线处暴露问题，避免运行时静默失败。
  - 对必须暴露的状态，优先提供“小 getter 函数”（如 `_input_is_game_started()`），不要直接暴露内部变量名。

## 错误复盘 3：沙箱环境缺少 Godot 可执行文件导致无法运行 headless 测试

- 任务背景：在抽离日志与统计（Telemetry）后，按仓库要求执行 headless 测试回归。
- 错误现象：执行 `godot --headless ...` 返回 `command not found: godot`。
- 根因分析：当前自动化沙箱环境未预装 Godot，可执行文件不在 PATH；这不是代码逻辑问题，但会阻塞“自动验证”步骤。
- 正确做法：
  1. 先在环境中执行 `which godot` 或 `godot --version` 快速确认可用性，再把“已运行测试”作为交付结论。
  2. 若环境确实缺少 Godot，则在交付说明中明确写出“无法在此环境跑测试”，并给出用户本地可执行的验证命令。
- 防再犯措施：
  1. 计划步骤里将“验证命令”与“验证可用性检查”绑定（例如先检查 `godot` 是否存在）。
  2. 任何无法完成的验证必须显式标注为“待用户本地执行”，避免误报已验证。
