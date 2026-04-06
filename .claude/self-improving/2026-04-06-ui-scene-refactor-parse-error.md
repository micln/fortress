# 2026-04-06 复盘：UI 场景化改造引入 GDScript 语法错误

## 任务背景
在把 `TopPanel` / `OrderDialog` 改为子场景实例化后，主场景启动报错：
`Could not resolve super class inheritance from res://scripts/presentation/prototype_main_game_layer_a.gd`。

## 错误现象
- 主入口 `prototype_main_game.gd` 无法加载父类链。
- 根因在 `prototype_main_game_layer_b.gd` 存在缩进错位与局部代码块损坏，导致父类脚本解析失败，最终表现为“无法解析父类继承”。

## 根因分析
- 大文件手工重构后没有立刻做“逐步解析验证”（只看主入口错误，未第一时间单独校验 layer 文件）。
- 在批量替换 HUD/Dialog 路径时，出现了错误缩进（例如 `if` 块多一层缩进）与段落结构错位。

## 正确做法
1. 先最小化复现：用 Godot MCP `run_project + get_debug_output` 确认首个报错。
2. 单脚本校验：对可疑层脚本先做独立解析校验，再恢复入口继承链。
3. 修复后再次用主场景回归启动，确认无 parser break。

## 防再犯措施
- 对 `prototype_main_game_layer_*.gd` 这类大文件改造，采用“每完成一个函数块就跑一次解析检查”的节奏。
- 重构时优先“少量、分段、可回滚”的补丁，避免一次性大面积改写。
- 提交前必须执行：
  - 主场景启动检查（Godot MCP）
  - 最小 headless 校验（至少验证脚本可加载）

## 可复用示例
- 复现命令（主场景）：
  - `run_project(projectPath, scene=res://scenes/main/prototype_main.tscn)`
  - `get_debug_output()`
- 独立解析校验（CLI）：
  - `HOME=/tmp XDG_DATA_HOME=/tmp /Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s res://scripts/presentation/prototype_main_game_layer_b.gd`
