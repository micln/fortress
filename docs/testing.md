# Testing

## 目标

- 核心规则模块覆盖率达到可接受水平，优先覆盖结算、产兵、地图连通与 AI 选择

## 范围

- `battle_resolver.gd`：兵力结算
- `game_state.gd`：产兵推进、合法攻击、邻接查询、胜负判断
- `enemy_ai.gd`：基础攻击决策
- `map_generator.gd`：地图连通性
- `main_game.gd`：通过项目启动验证确保场景装配无语法错误

## 执行

- 通过 `tests/test_runner.gd` 运行最小自定义测试集
- 对较大改动执行 Godot 项目启动验证，确保无语法错误
- 在沙箱环境下运行 headless 测试时，建议设置 `HOME=/tmp XDG_DATA_HOME=/tmp`，避免 Godot 写入 `user://logs` 时崩溃
