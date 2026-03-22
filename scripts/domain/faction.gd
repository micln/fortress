class_name Faction
extends RefCounted

## 返回阵营枚举值，供城市归属、胜负判断和 HUD 文案使用。
## 调用场景：领域层、应用层、表现层都需要共享统一阵营定义时。
## 主要逻辑：通过枚举常量约束阵营取值范围。
enum Type {
	NEUTRAL,
	PLAYER,
	ENEMY,
}


## 判断指定阵营是否属于可产兵的占领方。
## 调用场景：`GameState` 在推进产兵时调用。
## 主要逻辑：仅玩家和敌方城市可持续产兵，中立城市不产兵。
static func is_occupied(owner: int) -> bool:
	return owner == Type.PLAYER or owner == Type.ENEMY


## 将阵营枚举转换为用于 HUD 和调试的可读文本。
## 调用场景：界面显示城市归属、输出状态文案时调用。
## 主要逻辑：根据枚举分支返回固定字符串。
static func to_text(owner: int) -> String:
	match owner:
		Type.PLAYER:
			return "玩家"
		Type.ENEMY:
			return "敌人"
		_:
			return "中立"
