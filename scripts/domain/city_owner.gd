class_name CityOwner
extends RefCounted

const NEUTRAL: int = 0
const PLAYER: int = 1
const ENEMY: int = 2


## 返回阵营对应的展示颜色，供表现层统一渲染城市和道路。
##
## 调用场景：城市节点刷新外观、道路绘制、UI 高亮提示。
## 主要逻辑：根据阵营常量返回固定颜色，未识别值回退为中立灰色。
static func get_color(owner: int) -> Color:
	match owner:
		PLAYER:
			return Color("4d9fff")
		ENEMY:
			return Color("ff6b6b")
		_:
			return Color("8b95a5")


## 返回阵营对应的人类可读名称，供 UI 状态提示使用。
##
## 调用场景：顶部状态栏、调试信息、后续结算界面。
## 主要逻辑：根据阵营常量映射中文名称，未识别值回退为“中立”。
static func get_owner_name(owner: int) -> String:
	match owner:
		PLAYER:
			return "玩家"
		ENEMY:
			return "敌军"
		_:
			return "中立"
